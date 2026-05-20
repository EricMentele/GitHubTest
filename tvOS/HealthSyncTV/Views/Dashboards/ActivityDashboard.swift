import SwiftUI
import Charts
import HealthSyncShared

struct ActivityDashboard: View {
    let snapshot: HealthSnapshot?

    var body: some View {
        DashboardScaffold(title: "Activity") {
            if let activity = snapshot?.activity {
                VStack(spacing: 60) {
                    HStack(spacing: 60) {
                        RingTile(title: "Move", units: "kcal",
                                 value: activity.moveKilocalories,
                                 goal: activity.moveGoalKilocalories,
                                 color: .red)
                        RingTile(title: "Exercise", units: "min",
                                 value: activity.exerciseMinutes,
                                 goal: activity.exerciseGoalMinutes,
                                 color: .green)
                        RingTile(title: "Stand", units: "hrs",
                                 value: activity.standHours,
                                 goal: activity.standGoalHours,
                                 color: .cyan)
                    }
                    HStack(spacing: 60) {
                        StatTile(title: "Steps today", value: activity.steps.formatted())
                        StatTile(title: "Distance", value: distanceString(activity.distanceMeters))
                    }
                    StepsTrendChart(samples: activity.stepsLast14Days)
                        .frame(height: 320)
                }
            } else {
                EmptyDashboardMessage()
            }
        }
    }

    private func distanceString(_ meters: Double) -> String {
        let kilometers = meters / 1000
        return String(format: "%.2f km", kilometers)
    }
}

private struct StepsTrendChart: View {
    let samples: [DailyValue]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps · last 14 days").font(.title3).foregroundStyle(.secondary)
            Chart(samples) { sample in
                BarMark(
                    x: .value("Day", sample.day, unit: .day),
                    y: .value("Steps", sample.value)
                )
                .foregroundStyle(.orange.gradient)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) }
        }
    }
}

private struct RingTile: View {
    let title: String
    let units: String
    let value: Double
    let goal: Double
    let color: Color

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.5)
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 22)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack {
                    Text(value, format: .number.precision(.fractionLength(0)))
                        .font(.system(size: 64, weight: .bold))
                    Text(units).font(.title3).foregroundStyle(.secondary)
                }
            }
            .frame(width: 260, height: 260)
            Text(title).font(.title2.bold())
            Text("Goal \(Int(goal)) \(units)").font(.callout).foregroundStyle(.secondary)
        }
    }
}
