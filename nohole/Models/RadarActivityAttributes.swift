import ActivityKit
import Foundation

struct RadarActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Glasses actively nearby right now (seen within the last ~30s)
        var nearbyGlassesCount: Int
        /// Total unique glasses encountered this session
        var totalEncountered: Int
        var lastDetectionAt: Date?
    }
}
