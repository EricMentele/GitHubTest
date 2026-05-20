import SwiftUI

struct RootView: View {
    @Bindable var connection: PhoneConnection
    @Bindable var store: HealthSnapshotStore

    var body: some View {
        if connection.pairedEndpoint == nil {
            PairingView(connection: connection)
        } else {
            DashboardShell(connection: connection, store: store)
        }
    }
}

struct DashboardShell: View {
    @Bindable var connection: PhoneConnection
    @Bindable var store: HealthSnapshotStore

    var body: some View {
        TabView {
            ActivityDashboard(snapshot: store.snapshot)
                .tabItem { Label("Activity", systemImage: "figure.walk.motion") }
            HeartDashboard(snapshot: store.snapshot)
                .tabItem { Label("Heart", systemImage: "heart.fill") }
            SleepDashboard(snapshot: store.snapshot)
                .tabItem { Label("Sleep", systemImage: "bed.double.fill") }
            WorkoutsDashboard(snapshot: store.snapshot)
                .tabItem { Label("Workouts", systemImage: "flame.fill") }
            StatusView(connection: connection, store: store)
                .tabItem { Label("Status", systemImage: "antenna.radiowaves.left.and.right") }
        }
        .task { await connection.requestSnapshot() }
    }
}

struct StatusView: View {
    @Bindable var connection: PhoneConnection
    @Bindable var store: HealthSnapshotStore

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Health Sync").font(.largeTitle).bold()
            Group {
                LabeledContent("Paired phone", value: connection.pairedEndpoint?.displayName ?? "—")
                LabeledContent("Connection", value: connection.state.description)
                LabeledContent("Last refresh", value: store.lastUpdatedAt?.formatted(date: .abbreviated, time: .standard) ?? "never")
                if let error = connection.lastError {
                    LabeledContent("Last error", value: error).foregroundStyle(.red)
                }
            }
            .font(.title3)
            HStack(spacing: 24) {
                Button("Refresh now") { Task { await connection.requestSnapshot() } }
                Button("Unpair", role: .destructive) { connection.unpair() }
            }
            Spacer()
        }
        .padding(80)
    }
}
