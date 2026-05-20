import Foundation

public enum HealthSyncService {
    public static let identifier = "com.healthsync.local"
    public static let protocolVersion: UInt16 = 1
    public static let maxMessageBytes = 4 * 1024 * 1024
}
