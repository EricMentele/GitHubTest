import Foundation

public struct SyncEnvelope: Codable, Sendable {
    public var version: UInt16
    public var generatedAt: Date
    public var payload: HealthSnapshot

    public init(version: UInt16 = HealthSyncService.protocolVersion,
                generatedAt: Date = .now,
                payload: HealthSnapshot) {
        self.version = version
        self.generatedAt = generatedAt
        self.payload = payload
    }
}

public struct HealthSnapshot: Codable, Sendable {
    public var activity: ActivitySummary
    public var heart: HeartSummary
    public var sleep: SleepSummary
    public var workouts: [WorkoutSummary]

    public init(activity: ActivitySummary, heart: HeartSummary, sleep: SleepSummary, workouts: [WorkoutSummary]) {
        self.activity = activity
        self.heart = heart
        self.sleep = sleep
        self.workouts = workouts
    }
}

public struct ActivitySummary: Codable, Sendable {
    public var date: Date
    public var moveKilocalories: Double
    public var moveGoalKilocalories: Double
    public var exerciseMinutes: Double
    public var exerciseGoalMinutes: Double
    public var standHours: Double
    public var standGoalHours: Double
    public var steps: Int
    public var distanceMeters: Double
    public var stepsLast14Days: [DailyValue]

    public init(date: Date, moveKilocalories: Double, moveGoalKilocalories: Double,
                exerciseMinutes: Double, exerciseGoalMinutes: Double,
                standHours: Double, standGoalHours: Double,
                steps: Int, distanceMeters: Double, stepsLast14Days: [DailyValue]) {
        self.date = date
        self.moveKilocalories = moveKilocalories
        self.moveGoalKilocalories = moveGoalKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.exerciseGoalMinutes = exerciseGoalMinutes
        self.standHours = standHours
        self.standGoalHours = standGoalHours
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.stepsLast14Days = stepsLast14Days
    }
}

public struct HeartSummary: Codable, Sendable {
    public var restingBeatsPerMinute: Double?
    public var latestBeatsPerMinute: Double?
    public var latestSampleAt: Date?
    public var hrvMilliseconds: Double?
    public var dailyRestingLast14Days: [DailyValue]

    public init(restingBeatsPerMinute: Double?, latestBeatsPerMinute: Double?,
                latestSampleAt: Date?, hrvMilliseconds: Double?,
                dailyRestingLast14Days: [DailyValue]) {
        self.restingBeatsPerMinute = restingBeatsPerMinute
        self.latestBeatsPerMinute = latestBeatsPerMinute
        self.latestSampleAt = latestSampleAt
        self.hrvMilliseconds = hrvMilliseconds
        self.dailyRestingLast14Days = dailyRestingLast14Days
    }
}

public struct SleepSummary: Codable, Sendable {
    public var lastNight: SleepNight?
    public var trailingNights: [SleepNight]

    public init(lastNight: SleepNight?, trailingNights: [SleepNight]) {
        self.lastNight = lastNight
        self.trailingNights = trailingNights
    }
}

public struct SleepNight: Codable, Sendable, Identifiable {
    public var id: UUID
    public var bedtime: Date
    public var wakeTime: Date
    public var asleepSeconds: TimeInterval
    public var inBedSeconds: TimeInterval
    public var remSeconds: TimeInterval
    public var coreSeconds: TimeInterval
    public var deepSeconds: TimeInterval
    public var awakeSeconds: TimeInterval

    public init(id: UUID = UUID(), bedtime: Date, wakeTime: Date,
                asleepSeconds: TimeInterval, inBedSeconds: TimeInterval,
                remSeconds: TimeInterval, coreSeconds: TimeInterval,
                deepSeconds: TimeInterval, awakeSeconds: TimeInterval) {
        self.id = id
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.asleepSeconds = asleepSeconds
        self.inBedSeconds = inBedSeconds
        self.remSeconds = remSeconds
        self.coreSeconds = coreSeconds
        self.deepSeconds = deepSeconds
        self.awakeSeconds = awakeSeconds
    }
}

public struct WorkoutSummary: Codable, Sendable, Identifiable {
    public var id: UUID
    public var activityRawValue: UInt
    public var activityName: String
    public var start: Date
    public var end: Date
    public var durationSeconds: TimeInterval
    public var totalEnergyKilocalories: Double?
    public var totalDistanceMeters: Double?
    public var averageHeartRate: Double?

    public init(id: UUID = UUID(), activityRawValue: UInt, activityName: String,
                start: Date, end: Date, durationSeconds: TimeInterval,
                totalEnergyKilocalories: Double?, totalDistanceMeters: Double?,
                averageHeartRate: Double?) {
        self.id = id
        self.activityRawValue = activityRawValue
        self.activityName = activityName
        self.start = start
        self.end = end
        self.durationSeconds = durationSeconds
        self.totalEnergyKilocalories = totalEnergyKilocalories
        self.totalDistanceMeters = totalDistanceMeters
        self.averageHeartRate = averageHeartRate
    }
}

public struct DailyValue: Codable, Sendable, Identifiable {
    public var id: Date { day }
    public var day: Date
    public var value: Double

    public init(day: Date, value: Double) {
        self.day = day
        self.value = value
    }
}
