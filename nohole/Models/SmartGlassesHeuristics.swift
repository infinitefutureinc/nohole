import Foundation

enum SmartGlassesHeuristics {
    // Bluetooth SIG assigned company IDs
    static let metaCompanyIDs: Set<UInt16> = [0x01AB, 0x058E]      // Meta Platforms, Inc. / Meta Platforms Technologies, LLC
    static let essilorCompanyIDs: Set<UInt16> = [0x0D53]            // EssilorLuxottica (manufactures Meta Ray-Bans, Oakley)
    static let snapCompanyIDs: Set<UInt16> = [0x03C2]              // Snap, Inc. (Spectacles)

    static let allKnownCompanyIDs: Set<UInt16> =
        metaCompanyIDs.union(essilorCompanyIDs).union(snapCompanyIDs)

    // BLE advertised name patterns (case-insensitive)
    static let knownNamePatterns = ["rayban", "ray-ban", "ray ban"]

    static let defaultRSSIThreshold: Int = -75
    static let defaultCooldownInterval: TimeInterval = 10.0

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
