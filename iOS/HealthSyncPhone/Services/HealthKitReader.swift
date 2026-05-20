import Foundation
import HealthKit
import Observation
import HealthSyncShared

@Observable
final class HealthKitReader {
    private let store = HKHealthStore()
    private(set) var authorizationSummary: String = "unknown"

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.appleStandTime),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType()
        ]
        if let standHourType = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            types.insert(standHourType)
        }
        return types
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationSummary = "unavailable on this device"
            throw HealthSyncError.healthKitUnavailable
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        authorizationSummary = "granted"
    }

    func makeSnapshot() async throws -> HealthSnapshot {
        async let activity = activitySummary()
        async let heart = heartSummary()
        async let sleep = sleepSummary()
        async let workouts = recentWorkouts()
        return HealthSnapshot(
            activity: try await activity,
            heart: try await heart,
            sleep: try await sleep,
            workouts: try await workouts
        )
    }

    private func activitySummary() async throws -> ActivitySummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let stepsToday = try await sumQuantity(.stepCount, unit: .count(), since: today)
        let distanceToday = try await sumQuantity(.distanceWalkingRunning, unit: .meter(), since: today)

        let summary = try await fetchActivitySummary(for: today)
        let moveKcal = summary?.activeEnergyBurned.doubleValue(for: .kilocalorie()) ?? 0
        let moveGoal = summary?.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()) ?? 0
        let exMin = summary?.appleExerciseTime.doubleValue(for: .minute()) ?? 0
        let exGoal = summary?.exerciseTimeGoal?.doubleValue(for: .minute()) ?? 30
        let standHours = summary?.appleStandHours.doubleValue(for: .count()) ?? 0
        let standGoal = summary?.standHoursGoal?.doubleValue(for: .count()) ?? 12

        let last14 = try await dailyTotals(.stepCount, unit: .count(), days: 14)
        return ActivitySummary(
            date: today,
            moveKilocalories: moveKcal,
            moveGoalKilocalories: moveGoal,
            exerciseMinutes: exMin,
            exerciseGoalMinutes: exGoal,
            standHours: standHours,
            standGoalHours: standGoal,
            steps: Int(stepsToday),
            distanceMeters: distanceToday,
            stepsLast14Days: last14
        )
    }

    private func heartSummary() async throws -> HeartSummary {
        let resting = try? await mostRecentQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        let hrv = try? await mostRecentQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
        let latest = try? await mostRecentSample(.heartRate)
        let restingDaily = try await dailyAverages(.restingHeartRate,
                                                    unit: HKUnit.count().unitDivided(by: .minute()),
                                                    days: 14)
        return HeartSummary(
            restingBeatsPerMinute: resting?.value,
            latestBeatsPerMinute: latest.flatMap { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) },
            latestSampleAt: latest?.endDate,
            hrvMilliseconds: hrv?.value,
            dailyRestingLast14Days: restingDaily
        )
    }

    private func sleepSummary() async throws -> SleepSummary {
        let calendar = Calendar.current
        let now = Date.now
        guard let weekAgo = calendar.date(byAdding: .day, value: -10, to: now) else {
            return SleepSummary(lastNight: nil, trailingNights: [])
        }
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: [])
        let samples = try await categorySamples(.sleepAnalysis, predicate: predicate)

        let nights = SleepNightAssembler.assemble(samples: samples, calendar: calendar)
        return SleepSummary(lastNight: nights.last, trailingNights: nights)
    }

    private func recentWorkouts() async throws -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -30, to: .now),
                                                     end: .now,
                                                     options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 20
        )
        let workouts = try await descriptor.result(for: store)
        return workouts.map { workout in
            WorkoutSummary(
                activityRawValue: UInt(workout.workoutActivityType.rawValue),
                activityName: workout.workoutActivityType.localizedName,
                start: workout.startDate,
                end: workout.endDate,
                durationSeconds: workout.duration,
                totalEnergyKilocalories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                totalDistanceMeters: workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()),
                averageHeartRate: workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            )
        }
    }

    private func sumQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async throws -> Double {
        let type = HKQuantityType(id)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: .now, options: [])
        let descriptor = HKStatisticsQueryDescriptor(predicate: HKSamplePredicate.quantitySample(type: type, predicate: predicate),
                                                     options: .cumulativeSum)
        let stats = try await descriptor.result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    private func mostRecentQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> (value: Double, date: Date)? {
        let type = HKQuantityType(id)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try await descriptor.result(for: store).first else { return nil }
        return (sample.quantity.doubleValue(for: unit), sample.endDate)
    }

    private func mostRecentSample(_ id: HKQuantityTypeIdentifier) async throws -> HKQuantitySample? {
        let type = HKQuantityType(id)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try await descriptor.result(for: store).first
    }

    private func dailyTotals(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async throws -> [DailyValue] {
        try await dailyStatistics(id, unit: unit, days: days, options: .cumulativeSum) { $0.sumQuantity()?.doubleValue(for: unit) ?? 0 }
    }

    private func dailyAverages(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async throws -> [DailyValue] {
        try await dailyStatistics(id, unit: unit, days: days, options: .discreteAverage) { $0.averageQuantity()?.doubleValue(for: unit) ?? 0 }
    }

    private func dailyStatistics(_ id: HKQuantityTypeIdentifier,
                                  unit: HKUnit,
                                  days: Int,
                                  options: HKStatisticsOptions,
                                  extract: (HKStatistics) -> Double) async throws -> [DailyValue] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -days + 1, to: end) else { return [] }
        let type = HKQuantityType(id)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: calendar.date(byAdding: .day, value: 1, to: end), options: [])
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: type, predicate: predicate),
            options: options,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var out: [DailyValue] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            out.append(DailyValue(day: stats.startDate, value: extract(stats)))
        }
        return out
    }

    private func categorySamples(_ id: HKCategoryTypeIdentifier, predicate: NSPredicate) async throws -> [HKCategorySample] {
        let type = HKCategoryType(id)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await descriptor.result(for: store)
    }

    private func fetchActivitySummary(for day: Date) async throws -> HKActivitySummary? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.calendar = calendar
        let predicate = HKQuery.predicateForActivitySummary(with: components)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: summaries?.first)
            }
            store.execute(query)
        }
    }
}

enum HealthSyncError: Error {
    case healthKitUnavailable
}

extension HKWorkoutActivityType {
    var localizedName: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .yoga: return "Yoga"
        case .hiking: return "Hiking"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairs, .stairClimbing: return "Stairs"
        case .highIntensityIntervalTraining: return "HIIT"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        default: return "Workout"
        }
    }
}
