import Foundation
import HealthKit
import HealthSyncShared

enum SleepNightAssembler {
    static func assemble(samples: [HKCategorySample], calendar: Calendar) -> [SleepNight] {
        guard !samples.isEmpty else { return [] }
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var groups: [[HKCategorySample]] = []
        var current: [HKCategorySample] = []
        var gapAllowance: TimeInterval = 60 * 60
        var lastEnd: Date?

        for sample in sorted {
            if let lastEnd, sample.startDate.timeIntervalSince(lastEnd) > gapAllowance {
                if !current.isEmpty { groups.append(current); current = [] }
            }
            current.append(sample)
            lastEnd = max(lastEnd ?? sample.endDate, sample.endDate)
        }
        if !current.isEmpty { groups.append(current) }
        _ = gapAllowance

        return groups.compactMap { group in
            guard let bedtime = group.map(\.startDate).min(),
                  let wake = group.map(\.endDate).max() else { return nil }
            var asleep: TimeInterval = 0
            var inBed: TimeInterval = 0
            var rem: TimeInterval = 0
            var core: TimeInterval = 0
            var deep: TimeInterval = 0
            var awake: TimeInterval = 0
            for sample in group {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                case .inBed: inBed += duration
                case .asleepREM: asleep += duration; rem += duration
                case .asleepCore: asleep += duration; core += duration
                case .asleepDeep: asleep += duration; deep += duration
                case .asleepUnspecified, .asleep: asleep += duration
                case .awake: awake += duration
                default: break
                }
            }
            if inBed == 0 { inBed = asleep + awake }
            return SleepNight(
                bedtime: bedtime,
                wakeTime: wake,
                asleepSeconds: asleep,
                inBedSeconds: inBed,
                remSeconds: rem,
                coreSeconds: core,
                deepSeconds: deep,
                awakeSeconds: awake
            )
        }
    }
}
