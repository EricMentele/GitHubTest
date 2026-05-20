import SwiftUI
import HealthSyncShared

struct WorkoutsDashboard: View {
    let snapshot: HealthSnapshot?

    var body: some View {
        DashboardScaffold(title: "Workouts") {
            if let workouts = snapshot?.workouts, !workouts.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 480), spacing: 36)], spacing: 36) {
                        ForEach(workouts) { workout in
                            WorkoutCard(workout: workout)
                        }
                    }
                }
            } else {
                EmptyDashboardMessage()
            }
        }
    }
}

private struct WorkoutCard: View {
    let workout: WorkoutSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: iconName).font(.system(size: 48))
                Text(workout.activityName).font(.title.bold())
                Spacer()
            }
            Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                .font(.title3).foregroundStyle(.secondary)
            Divider()
            HStack(spacing: 28) {
                Metric(label: "Duration", value: durationString(workout.durationSeconds))
                if let kcal = workout.totalEnergyKilocalories {
                    Metric(label: "Calories", value: "\(Int(kcal)) kcal")
                }
                if let meters = workout.totalDistanceMeters {
                    Metric(label: "Distance", value: String(format: "%.2f km", meters / 1000))
                }
                if let hr = workout.averageHeartRate {
                    Metric(label: "Avg HR", value: "\(Int(hr)) bpm")
                }
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.18), in: .rect(cornerRadius: 32))
    }

    private var iconName: String {
        switch workout.activityName.lowercased() {
        case let s where s.contains("run"): return "figure.run"
        case let s where s.contains("cycl"): return "figure.outdoor.cycle"
        case let s where s.contains("walk"): return "figure.walk"
        case let s where s.contains("yoga"): return "figure.mind.and.body"
        case let s where s.contains("swim"): return "figure.pool.swim"
        case let s where s.contains("strength"): return "figure.strengthtraining.traditional"
        case let s where s.contains("hike"): return "figure.hiking"
        default: return "flame.fill"
        }
    }

    private func durationString(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }
}

private struct Metric: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.callout).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
    }
}
