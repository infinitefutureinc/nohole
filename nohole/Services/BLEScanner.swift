import Foundation
import CoreBluetooth

struct NearbyDevice: Identifiable {
    let id: String  // peripheral UUID
    var name: String?
    var companyID: UInt16?
    var rssi: Int
    var matched: Bool
    var reason: String
    var lastSeen: Date
}

@Observable
final class BLEScanner: NSObject, CBCentralManagerDelegate {
    var isScanning: Bool = false
    var bluetoothState: CBManagerState = .unknown
    var detections: [DetectionEvent] = []
    var latestDetection: DetectionEvent?
    var rssiThreshold: Int = SmartGlassesHeuristics.defaultRSSIThreshold
    var nearbyDevices: [NearbyDevice] = []

    private var centralManager: CBCentralManager?
    private var nearbyDeviceIndex: [String: Int] = [:]  // id -> index in nearbyDevices
    private var wantsToScan: Bool = false

    // Drop nearby devices not re-advertised within this window. BLE devices using
    // resolvable private addresses rotate their identity periodically; without this
    // the list grows unbounded as one physical device cycles through addresses.
    private static let staleInterval: TimeInterval = 15.0

    // MARK: - Public

    func startScanning() {
        wantsToScan = true
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        } else if bluetoothState == .poweredOn {
            beginScan()
        }
    }

    func stopScanning() {
        wantsToScan = false
        centralManager?.stopScan()
        isScanning = false
        nearbyDevices.removeAll()
        nearbyDeviceIndex.removeAll()
    }

    func clearDetections() {
        detections.removeAll()
        latestDetection = nil
    }

    // MARK: - CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state
            if central.state == .poweredOn && self.wantsToScan {
                self.beginScan()
            } else if central.state != .poweredOn {
                self.isScanning = false
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssi = RSSI.intValue
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let identifier = peripheral.identifier.uuidString

        Task { @MainActor in
            self.processDiscovery(
                identifier: identifier,
                name: name,
                manufacturerData: manufacturerData,
                rssi: rssi
            )
        }
    }

    // MARK: - Private

    private func beginScan() {
        guard bluetoothState == .poweredOn else { return }
        centralManager?.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
    }

    private func processDiscovery(
        identifier: String,
        name: String?,
        manufacturerData: Data?,
        rssi: Int
    ) {
        pruneStaleDevices()

        let companyID = manufacturerData.flatMap { extractCompanyID(from: $0) }

        // Classify this device
        let matched: Bool
        let reason: String

        if let cid = companyID, SmartGlassesHeuristics.allKnownCompanyIDs.contains(cid) {
            matched = true
            reason = SmartGlassesHeuristics.classifyCompanyID(cid).rawValue
        } else if let n = name, SmartGlassesHeuristics.matchesKnownName(n) {
            matched = true
            reason = "Name match"
        } else {
            matched = false
            reason = ""
        }

        // Update nearby devices list (one entry per peripheral, deduplicated)
        if name != nil || companyID != nil {
            if let idx = nearbyDeviceIndex[identifier] {
                nearbyDevices[idx].rssi = rssi
                nearbyDevices[idx].lastSeen = Date()
                nearbyDevices[idx].matched = matched
                nearbyDevices[idx].reason = reason
                if let name { nearbyDevices[idx].name = name }
                if let companyID { nearbyDevices[idx].companyID = companyID }
            } else {
                let device = NearbyDevice(
                    id: identifier,
                    name: name,
                    companyID: companyID,
                    rssi: rssi,
                    matched: matched,
                    reason: reason,
                    lastSeen: Date()
                )
                nearbyDevices.append(device)
                nearbyDeviceIndex[identifier] = nearbyDevices.count - 1
            }
        }

        // Detection logic
        guard rssi >= rssiThreshold else { return }
        guard matched else { return }

        var glassesType: DetectionEvent.GlassesType?

        if let cid = companyID, SmartGlassesHeuristics.allKnownCompanyIDs.contains(cid) {
            glassesType = SmartGlassesHeuristics.classifyCompanyID(cid)
        }

        if glassesType == nil, let name = name, SmartGlassesHeuristics.matchesKnownName(name) {
            glassesType = .metaRayBan
        }

        guard let type = glassesType else { return }
        guard let fingerprint = detectionFingerprint(companyID: companyID, name: name) else { return }

        // One physical pair of glasses rotates its BLE address, so dedup on the
        // fingerprint (stable company ID / name) rather than the peripheral UUID.
        if let idx = detections.firstIndex(where: { $0.fingerprint == fingerprint }) {
            detections[idx].rssi = rssi
            detections[idx].timestamp = Date()
            return
        }

        let event = DetectionEvent(
            id: UUID(),
            fingerprint: fingerprint,
            timestamp: Date(),
            deviceName: name,
            companyID: companyID,
            rssi: rssi,
            glassesType: type
        )

        detections.insert(event, at: 0)
        latestDetection = event
    }

    // Stable identity for a matched device across BLE address rotations.
    // Company IDs are Bluetooth-SIG-assigned and do not rotate; fall back to the
    // advertised name. Note: two different people wearing the same brand with no
    // distinguishing name will share a fingerprint and count as one.
    private func detectionFingerprint(companyID: UInt16?, name: String?) -> String? {
        if let cid = companyID, SmartGlassesHeuristics.allKnownCompanyIDs.contains(cid) {
            return "cid:\(cid)"
        }
        if let name, SmartGlassesHeuristics.matchesKnownName(name) {
            return "name:\(name.lowercased())"
        }
        return nil
    }

    private func pruneStaleDevices() {
        let cutoff = Date().addingTimeInterval(-Self.staleInterval)
        let countBefore = nearbyDevices.count
        nearbyDevices.removeAll { $0.lastSeen < cutoff }
        guard nearbyDevices.count != countBefore else { return }
        nearbyDeviceIndex.removeAll()
        for (i, device) in nearbyDevices.enumerated() {
            nearbyDeviceIndex[device.id] = i
        }
    }

    private func extractCompanyID(from data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        // Little-endian per BT spec. Read byte-wise to avoid alignment traps on
        // unaligned Data slices.
        return UInt16(data[data.startIndex]) | (UInt16(data[data.startIndex + 1]) << 8)
    }
}
