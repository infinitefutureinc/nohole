import Foundation
import CoreBluetooth

enum SmartGlassesHeuristics {
    // Bluetooth SIG assigned company IDs
    static let metaCompanyIDs: Set<UInt16> = [
        0x01AB,  // Meta Platforms, Inc.
        0x058E,  // Meta Platforms Technologies, LLC
        0x0397,  // Facebook Technologies, LLC (older Ray-Ban Stories)
    ]
    static let essilorCompanyIDs: Set<UInt16> = [
        0x0D53,  // EssilorLuxottica SA
        0x02E5,  // Luxottica Group S.p.A.
    ]
    static let snapCompanyIDs: Set<UInt16> = [0x03C2]              // Snap, Inc. (Spectacles)

    static let allKnownCompanyIDs: Set<UInt16> =
        metaCompanyIDs.union(essilorCompanyIDs).union(snapCompanyIDs)

    // BLE 16-bit service UUIDs advertised by smart glasses.
    // Required for CoreBluetooth background scanning — iOS ignores
    // scanForPeripherals(withServices: nil) when the app is backgrounded.
    static let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FD5F"),  // Oculus VR / Meta (Ray-Ban Meta glasses)
        CBUUID(string: "FEB7"),  // Meta Platforms, Inc.
        CBUUID(string: "FEB8"),  // Meta Platforms, Inc.
    ]

    // BLE advertised name patterns (case-insensitive)
    static let knownNamePatterns = [
        "rayban", "ray-ban", "ray ban",
        "meta ray", "stories", "wayfarer",
        "headliner", "skyler", "clover",
        "spectacles"
    ]

    static let defaultRSSIThreshold: Int = -75

    static func classifyCompanyID(_ id: UInt16) -> DetectionEvent.GlassesType {
        if metaCompanyIDs.contains(id) { return .metaRayBan }
        if essilorCompanyIDs.contains(id) { return .essilorLuxottica }
        if snapCompanyIDs.contains(id) { return .snapSpectacles }
        return .unknown
    }

    static func matchesKnownName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return knownNamePatterns.contains { lowered.contains($0) }
    }
}
