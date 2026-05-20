import SwiftUI
import Charts
import HealthSyncShared

struct HeartDashboard: View {
    let snapshot: HealthSnapshot?

    var body: some View {
        DashboardScaffold(title: "Heart") {
            if let heart = snapshot?.heart {
                VStack(spacing: 60) {
                    HStack(spacing: 60) {
                        StatTile(title: "Latest",
                                 value: heart.latestBeatsPerMinute.map { "\(Int($0)) bpm" } ?? "—",
                                 subtitle: heart.latestSampleAt?.formatted(date: .omitted, time: .shortened))
                        StatTile(title: "Resting",
                                 value: heart.restingBeatsPerMinute.map { "\(Int($0)) bpm" } ?? "—")
                        StatTile(title: "HRV",
                                 value: heart.hrvMilliseconds.map { String(format: "%.0f ms", $0) } ?? "—")
                    }
                    RestingTrendChart(samples: heart.dailyRestingLast14Days)
                        .frame(height: 360)
                }
            } else {
                EmptyDashboardMessage()
            }
        }
    }
}

private struct RestingTrendChart: View {
    let samples: [DailyValue]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resting heart rate · last 14 days").font(.title3).foregroundStyle(.secondary)
            Chart(samples.filter { $0.value > 0 }) { sample in
                LineMark(
                    x: .value("Day", sample.day, unit: .day),
                    y: .value("bpm", sample.value)
                )
                .foregroundStyle(.pink)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Day", sample.day, unit: .day),
                    y: .value("bpm", sample.value)
                )
                .foregroundStyle(.pink)
            }
        }
    }
}
