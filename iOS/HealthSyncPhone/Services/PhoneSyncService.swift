import Foundation
import Network
import Observation
import HealthSyncShared

@Observable
final class PhoneSyncService {
    enum State: CustomStringConvertible {
        case idle, starting, ready, failed(String)
        var description: String {
            switch self {
            case .idle: return "idle"
            case .starting: return "starting"
            case .ready: return "ready"
            case .failed(let reason): return "failed (\(reason))"
            }
        }
    }

    var listenerState: State = .idle
    var connectionState: State = .idle
    var connectedPeerName: String?
    var lastSyncedAt: Date?
    var lastError: String?

    var snapshotProvider: (() async throws -> HealthSnapshot)?

    private var listener: NWListener?
    private var connection: NWConnection?
    private let framing = LengthPrefixedFraming()
    private let queue = DispatchQueue(label: "phone-sync.listener")

    func start() {
        guard listener == nil else { return }
        listenerState = .starting
        do {
            let parameters = NWParameters.applicationService
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(applicationService: HealthSyncService.identifier)
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in self?.handleListenerState(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection: connection) }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            listenerState = .failed(error.localizedDescription)
            lastError = "Listener: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready: listenerState = .ready
        case .failed(let error):
            listenerState = .failed(error.localizedDescription)
            lastError = "Listener: \(error.localizedDescription)"
        case .cancelled: listenerState = .idle
        case .setup, .waiting: listenerState = .starting
        @unknown default: break
        }
    }

    @MainActor
    private func accept(connection: NWConnection) {
        self.connection?.cancel()
        self.connection = connection
        connectionState = .starting
        connectedPeerName = connection.endpoint.peerDisplayName

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.handleConnectionState(state) }
        }
        connection.start(queue: queue)
        receive(on: connection)
    }

    @MainActor
    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready: connectionState = .ready
        case .failed(let error):
            connectionState = .failed(error.localizedDescription)
            lastError = "Connection: \(error.localizedDescription)"
        case .cancelled:
            connectionState = .idle
            connectedPeerName = nil
        case .preparing, .setup, .waiting: connectionState = .starting
        @unknown default: break
        }
    }

    private func receive(on connection: NWConnection) {
        let reader = FrameReader()
        Task { await self.readLoop(connection: connection, reader: reader) }
    }

    private func readLoop(connection: NWConnection, reader: FrameReader) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
                Task {
                    if let data, !data.isEmpty {
                        await reader.append(data)
                        do {
                            let requests = try await reader.decodeAll(SnapshotRequest.self)
                            for request in requests {
                                await self?.handleRequest(request, on: connection)
                            }
                        } catch {
                            await MainActor.run { self?.lastError = "Decode: \(error.localizedDescription)" }
                        }
                    }
                    if error == nil && !isComplete {
                        await self?.readLoop(connection: connection, reader: reader)
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func handleRequest(_ request: SnapshotRequest, on connection: NWConnection) async {
        guard let provider = snapshotProvider else { return }
        do {
            let snapshot = try await provider()
            let envelope = SyncEnvelope(payload: snapshot)
            let data = try framing.encode(envelope)
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                Task { @MainActor in
                    if let error {
                        self?.lastError = "Send: \(error.localizedDescription)"
                    } else {
                        self?.lastSyncedAt = .now
                    }
                }
            })
        } catch {
            await MainActor.run { self.lastError = "Snapshot: \(error.localizedDescription)" }
        }
    }
}

struct SnapshotRequest: Codable, Sendable {
    var requestId: UUID = UUID()
    var requestedAt: Date = .now
}

private extension NWEndpoint {
    var peerDisplayName: String {
        switch self {
        case .applicationService(let name): return name
        default: return debugDescription
        }
    }
}
