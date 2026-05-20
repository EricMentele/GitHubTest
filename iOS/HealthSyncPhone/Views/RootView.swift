import SwiftUI

struct RootView: View {
    @Bindable var sync: PhoneSyncService
    let reader: HealthKitReader

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("Listener", value: sync.listenerState.description)
                    LabeledContent("Connection", value: sync.connectionState.description)
                    if let peer = sync.connectedPeerName {
                        LabeledContent("Paired with", value: peer)
                    }
                    if let last = sync.lastSyncedAt {
                        LabeledContent("Last push", value: last.formatted(date: .omitted, time: .standard))
                    }
                }

                Section("Permissions") {
                    LabeledContent("HealthKit", value: reader.authorizationSummary)
                    Button("Re-request HealthKit access") {
                        Task { try? await reader.requestAuthorization() }
                    }
                }

                if let error = sync.lastError {
                    Section("Error") {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section {
                    Text("Open the Health Sync app on Apple TV and pick this iPhone. Data only leaves this device when a paired Apple TV requests it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Health Sync")
        }
    }
}
