import Foundation
import SwiftUI

struct DetectionEvent: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let deviceName: String?
    let companyID: UInt16?
    let rssi: Int
    let glassesType: GlassesType

    enum GlassesType: String, CaseIterable {
        case metaRayBan = "Meta Ray-Ban"
        case snapSpectacles = "Snap Spectacles"
        case essilorLuxottica = "EssilorLuxottica"
        case unknown = "Smart Glasses"

        var iconName: String {
            switch self {
            case .metaRayBan:        return "eyeglasses"
            case .snapSpectacles:    return "camera.circle"
            case .essilorLuxottica:  return "eyeglasses"
            case .unknown:           return "questionmark.circle"
            }
        }
    }

    var relativeTimestamp: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 5 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
}
