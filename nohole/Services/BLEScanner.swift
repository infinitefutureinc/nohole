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
    private var cooldownTimestamps: [String: Date] = [:]
    private var nearbyDeviceIndex: [String: Int] = [:]  // id -> index in nearbyDevices
    private var wantsToScan: Bool = false

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
        guard shouldAlertForDevice(identifier) else { return }

        let event = DetectionEvent(
            id: UUID(),
            timestamp: Date(),
            deviceName: name,
            companyID: companyID,
            rssi: rssi,
            glassesType: type
        )

        detections.insert(event, at: 0)
        latestDetection = event
        cooldownTimestamps[identifier] = Date()
    }

    private func extractCompanyID(from data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        return data.withUnsafeBytes { buffer in
            buffer.load(as: UInt16.self) // Little-endian per BT spec
        }
    }

    private func shouldAlertForDevice(_ identifier: String) -> Bool {
        guard let lastAlert = cooldownTimestamps[identifier] else { return true }
        return Date().timeIntervalSince(lastAlert) >= SmartGlassesHeuristics.defaultCooldownInterval
    }
}
