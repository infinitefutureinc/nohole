import Foundation
import CoreBluetooth

@Observable
final class BLEScanner: NSObject, CBCentralManagerDelegate {
    var isScanning: Bool = false
    var bluetoothState: CBManagerState = .unknown
    var detections: [DetectionEvent] = []
    var latestDetection: DetectionEvent?
    var rssiThreshold: Int = SmartGlassesHeuristics.defaultRSSIThreshold

    private var centralManager: CBCentralManager?
    private var cooldownTimestamps: [String: Date] = [:]
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
        guard rssi >= rssiThreshold else { return }

        var glassesType: DetectionEvent.GlassesType?

        // Check company ID from manufacturer data
        if let data = manufacturerData, let companyID = extractCompanyID(from: data) {
            if SmartGlassesHeuristics.allKnownCompanyIDs.contains(companyID) {
                glassesType = SmartGlassesHeuristics.classifyCompanyID(companyID)
            }
        }

        // Check device name
        if glassesType == nil, let name = name, SmartGlassesHeuristics.matchesKnownName(name) {
            glassesType = .metaRayBan
        }

        guard let type = glassesType else { return }
        guard shouldAlertForDevice(identifier) else { return }

        let event = DetectionEvent(
            id: UUID(),
            timestamp: Date(),
            deviceName: name,
            companyID: manufacturerData.flatMap { extractCompanyID(from: $0) },
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
