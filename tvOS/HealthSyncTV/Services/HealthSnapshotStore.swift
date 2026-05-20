import Foundation
import Observation
import HealthSyncShared

@Observable
final class HealthSnapshotStore {
    private(set) var snapshot: HealthSnapshot?
    private(set) var lastUpdatedAt: Date?

    private let cacheURL: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appending(path: "health-snapshot.json")
    }()

    init() {
        load()
    }

    func ingest(_ envelope: SyncEnvelope) async {
        await MainActor.run {
            self.snapshot = envelope.payload
            self.lastUpdatedAt = envelope.generatedAt
        }
        persist(envelope)
    }

    private func persist(_ envelope: SyncEnvelope) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(envelope).write(to: cacheURL, options: .atomic)
        } catch {
            // Apple TV may purge the cache directory; the next sync request restores state.
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(SyncEnvelope.self, from: data) else { return }
        snapshot = envelope.payload
        lastUpdatedAt = envelope.generatedAt
    }
}
