import SwiftUI

@main
struct HealthSyncTVApp: App {
    @State private var store = HealthSnapshotStore()
    @State private var connection = PhoneConnection()

    var body: some Scene {
        WindowGroup {
            RootView(connection: connection, store: store)
                .task {
                    connection.snapshotHandler = { envelope in
                        await store.ingest(envelope)
                    }
                }
        }
    }
}
