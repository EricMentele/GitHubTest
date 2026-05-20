import Foundation
import Network
import Observation
import HealthSyncShared

@Observable
final class PhoneConnection {
    enum State: CustomStringConvertible {
        case idle, connecting, ready, failed(String)
        var description: String {
            switch self {
            case .idle: return "idle"
            case .connecting: return "connecting"
            case .ready: return "ready"
            case .failed(let reason): return "failed (\(reason))"
            }
        }
    }

    private(set) var state: State = .idle
    private(set) var pairedEndpoint: PairedEndpoint?
    private(set) var lastError: String?

    var snapshotHandler: ((SyncEnvelope) async -> Void)?

    private var connection: NWConnection?
    private let framing = LengthPrefixedFraming()
    private let queue = DispatchQueue(label: "tv-phone-connection")
    private let defaults = UserDefaults.standard
    private let savedEndpointKey = "HealthSync.PairedEndpointName"

    init() {
        if let saved = defaults.string(forKey: savedEndpointKey) {
            pairedEndpoint = PairedEndpoint(displayName: saved, raw: .applicationService(name: saved))
        }
    }

    func pair(with endpoint: NWEndpoint) {
        let displayName: String
        if case .applicationService(let name) = endpoint {
            displayName = name
        } else {
            displayName = endpoint.debugDescription
        }
        pairedEndpoint = PairedEndpoint(displayName: displayName, raw: endpoint)
        defaults.set(displayName, forKey: savedEndpointKey)
        Task { await requestSnapshot() }
    }

    func unpair() {
        connection?.cancel()
        connection = nil
        pairedEndpoint = nil
        state = .idle
        defaults.removeObject(forKey: savedEndpointKey)
    }

    @discardableResult
    func requestSnapshot() async -> Bool {
        guard let endpoint = pairedEndpoint?.raw else { return false }
        do {
            let connection = try ensureConnection(endpoint: endpoint)
            try await waitForReady(connection)
            let request = SnapshotRequest()
            let data = try framing.encode(request)
            try await send(data, on: connection)
            return true
        } catch {
            await MainActor.run {
                self.state = .failed(error.localizedDescription)
                self.lastError = error.localizedDescription
            }
            return false
        }
    }

    private func ensureConnection(endpoint: NWEndpoint) throws -> NWConnection {
        if let existing = connection, case .ready = existing.state { return existing }
        connection?.cancel()
        state = .connecting
        let connection = NWConnection(to: endpoint, using: .applicationService)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.handleState(state) }
        }
        connection.start(queue: queue)
        self.connection = connection
        beginReceive(on: connection)
        return connection
    }

    @MainActor
    private func handleState(_ state: NWConnection.State) {
        switch state {
        case .ready: self.state = .ready
        case .failed(let error):
            self.state = .failed(error.localizedDescription)
            lastError = error.localizedDescription
        case .cancelled: self.state = .idle
        case .preparing, .setup, .waiting: self.state = .connecting
        @unknown default: break
        }
    }

    private func waitForReady(_ connection: NWConnection, timeout: TimeInterval = 10) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if case .ready = connection.state { return }
            if case .failed(let error) = connection.state { throw error }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw URLError(.timedOut)
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }

    private func beginReceive(on connection: NWConnection) {
        let reader = FrameReader()
        Task { await receiveLoop(connection: connection, reader: reader) }
    }

    private func receiveLoop(connection: NWConnection, reader: FrameReader) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
                Task {
                    if let data, !data.isEmpty {
                        await reader.append(data)
                        do {
                            let envelopes = try await reader.decodeAll(SyncEnvelope.self)
                            for envelope in envelopes {
                                await self?.snapshotHandler?(envelope)
                            }
                        } catch {
                            await MainActor.run { self?.lastError = "Decode: \(error.localizedDescription)" }
                        }
                    }
                    if let error {
                        await MainActor.run {
                            self?.state = .failed(error.localizedDescription)
                            self?.lastError = error.localizedDescription
                        }
                    } else if !isComplete {
                        await self?.receiveLoop(connection: connection, reader: reader)
                    }
                    continuation.resume()
                }
            }
        }
    }
}

struct PairedEndpoint: Equatable {
    var displayName: String
    var raw: NWEndpoint

    static func == (lhs: PairedEndpoint, rhs: PairedEndpoint) -> Bool {
        lhs.displayName == rhs.displayName
    }
}

struct SnapshotRequest: Codable, Sendable {
    var requestId: UUID = UUID()
    var requestedAt: Date = .now
}
