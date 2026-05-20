import SwiftUI

@main
struct HealthSyncPhoneApp: App {
    @State private var sync = PhoneSyncService()
    @State private var reader = HealthKitReader()

    var body: some Scene {
        WindowGroup {
            RootView(sync: sync, reader: reader)
                .task { await bootstrap() }
        }
    }

    private func bootstrap() async {
        do {
            try await reader.requestAuthorization()
        } catch {
            sync.lastError = "HealthKit authorization failed: \(error.localizedDescription)"
        }
        sync.snapshotProvider = { [reader] in
            try await reader.makeSnapshot()
        }
        sync.start()
    }
}
