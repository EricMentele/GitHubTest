import SwiftUI
import Charts
import HealthSyncShared

struct SleepDashboard: View {
    let snapshot: HealthSnapshot?

    var body: some View {
        DashboardScaffold(title: "Sleep") {
            if let sleep = snapshot?.sleep, let last = sleep.lastNight {
                VStack(spacing: 60) {
                    HStack(alignment: .top, spacing: 60) {
                        LastNightCard(night: last)
                        SleepStageBreakdown(night: last)
                    }
                    SleepDurationTrend(nights: sleep.trailingNights)
                        .frame(height: 320)
                }
            } else {
                EmptyDashboardMessage()
            }
        }
    }
}

private struct LastNightCard: View {
    let night: SleepNight
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last night").font(.title3).foregroundStyle(.secondary)
            Text(formatHM(night.asleepSeconds)).font(.system(size: 96, weight: .bold))
            Text("\(night.bedtime.formatted(date: .omitted, time: .shortened)) → \(night.wakeTime.formatted(date: .omitted, time: .shortened))")
                .font(.title3).foregroundStyle(.secondary)
        }
        .padding(48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.indigo.opacity(0.25), in: .rect(cornerRadius: 36))
    }
}

private struct SleepStageBreakdown: View {
    let night: SleepNight
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stages").font(.title3).foregroundStyle(.secondary)
            StageRow(title: "REM", seconds: night.remSeconds, color: .pink)
            StageRow(title: "Core", seconds: night.coreSeconds, color: .blue)
            StageRow(title: "Deep", seconds: night.deepSeconds, color: .indigo)
            StageRow(title: "Awake", seconds: night.awakeSeconds, color: .orange)
        }
        .padding(48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.indigo.opacity(0.15), in: .rect(cornerRadius: 36))
    }
}

private struct StageRow: View {
    let title: String
    let seconds: TimeInterval
    let color: Color
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 18, height: 18)
            Text(title).font(.title3)
            Spacer()
            Text(formatHM(seconds)).font(.title3.monospacedDigit())
        }
    }
}

private struct SleepDurationTrend: View {
    let nights: [SleepNight]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Asleep · last \(nights.count) nights").font(.title3).foregroundStyle(.secondary)
            Chart(nights) { night in
                BarMark(
                    x: .value("Night", night.bedtime, unit: .day),
                    y: .value("Hours", night.asleepSeconds / 3600)
                )
                .foregroundStyle(.indigo.gradient)
            }
        }
    }
}

private func formatHM(_ seconds: TimeInterval) -> String {
    let h = Int(seconds) / 3600
    let m = (Int(seconds) % 3600) / 60
    return "\(h)h \(m)m"
}
