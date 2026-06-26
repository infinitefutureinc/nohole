import ActivityKit
import Foundation

struct RadarActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var detectedGlassesCount: Int
        var lastDetectionAt: Date?
        var nearbyDeviceCount: Int
    }
}
