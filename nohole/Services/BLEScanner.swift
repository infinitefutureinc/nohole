import Foundation
import CoreBluetooth
import os

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
    static let shared = BLEScanner()

    private static let log = Logger(subsystem: "xyz.infinitefuture.nohole", category: "BLE")

    var isScanning: Bool = false
    var bluetoothState: CBManagerState = .unknown
    var detections: [DetectionEvent] = []
    var latestDetection: DetectionEvent?
    var rssiThreshold: Int = SmartGlassesHeuristics.defaultRSSIThreshold
    var nearbyDevices: [NearbyDevice] = []

    var lastDetectionAt: Date? { latestDetection?.timestamp }

    /// How long since last BLE advertisement before a detection is considered stale.
    static let detectionStaleInterval: TimeInterval = 30.0

    /// Glasses actively nearby (seen within the stale interval).
    var nearbyGlassesCount: Int {
        let cutoff = Date().addingTimeInterval(-Self.detectionStaleInterval)
        return detections.count(where: { $0.timestamp > cutoff })
    }

    /// Called from the BLE queue when a detection is confirmed.
    /// Parameters: (nearbyCount, totalEncountered, lastDetectionAt)
    nonisolated(unsafe) var onDetectionChanged: ((_ nearby: Int, _ total: Int, _ lastAt: Date?) -> Void)?

    private var centralManager: CBCentralManager?
    private var nearbyDeviceIndex: [String: Int] = [:]  // id -> index in nearbyDevices
    private var wantsToScan: Bool = false

    /// When true, scan uses known service UUIDs so CoreBluetooth delivers
    /// callbacks even when the app is in the background. When false, scans
    /// with nil (all devices) for the nearby-devices list in foreground.
    private var useBackgroundSafeFilter: Bool = false

    /// Dedicated serial queue for CoreBluetooth delegate callbacks.
    private let bleQueue = DispatchQueue(label: "xyz.infinitefuture.nohole.ble", qos: .userInitiated)

    /// Shadow detection tracking on the BLE queue so we can compute accurate
    /// counts for Live Activity updates without waiting for the main actor.
    private struct BgDetection {
        let fingerprint: String
        var timestamp: Date
    }
    private var bgDetections: [BgDetection] = []  // accessed only on bleQueue

    // Drop nearby devices not re-advertised within this window.
    private static let staleInterval: TimeInterval = 15.0

    // MARK: - Public

    func startScanning() {
        useBackgroundSafeFilter = false
        wantsToScan = true
        ensureCentralManager()
        if bluetoothState == .poweredOn {
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

    // MARK: - Window API (used by RadarController)

    /// Begins scanning for the radar session. Starts with a wildcard scan (foreground)
    /// so nearbyDevices populates. Call `setBackgroundSafeFilter(true)` when the app
    /// moves to background to switch to the service-UUID-filtered scan that iOS allows.
    func beginScanWindow() {
        useBackgroundSafeFilter = false
        wantsToScan = true
        ensureCentralManager()
        if bluetoothState == .poweredOn {
            beginScan()
        }
    }

    func endScanWindow() {
        wantsToScan = false
        centralManager?.stopScan()
        isScanning = false
    }

    /// Switches between wildcard scan (foreground) and service-UUID-filtered scan (background).
    /// Restarts the scan if one is already active.
    func setBackgroundSafeFilter(_ enabled: Bool) {
        guard useBackgroundSafeFilter != enabled else { return }
        useBackgroundSafeFilter = enabled
        if wantsToScan && bluetoothState == .poweredOn {
            beginScan()
        }
    }

    func flushInWindowCache() {
        nearbyDevices.removeAll()
        nearbyDeviceIndex.removeAll()
    }

    private func ensureCentralManager() {
        if centralManager == nil {
            centralManager = CBCentralManager(
                delegate: self,
                queue: bleQueue,
                options: [CBCentralManagerOptionRestoreIdentifierKey: "xyz.infinitefuture.nohole.central"]
            )
        }
    }

    func clearDetections() {
        detections.removeAll()
        latestDetection = nil
        bleQueue.async { [weak self] in
            self?.bgDetections.removeAll()
        }
    }

    // MARK: - CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Self.log.info("BT state changed: \(state.rawValue)")
        Task { @MainActor in
            self.bluetoothState = state
            if state == .poweredOn && self.wantsToScan {
                self.beginScan()
            } else if state != .poweredOn {
                self.isScanning = false
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        Self.log.info("State restoration triggered")
        if dict[CBCentralManagerRestoredStateScanServicesKey] != nil {
            Task { @MainActor in
                self.wantsToScan = true
                self.useBackgroundSafeFilter = true
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // This fires on bleQueue.
        let rssi = RSSI.intValue
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let identifier = peripheral.identifier.uuidString

        let companyID = manufacturerData.flatMap { self.extractCompanyID(from: $0) }

        // Check if this device matches known smart glasses (pure function, no actor needed)
        let matched: Bool
        let reason: String
        if let cid = companyID, SmartGlassesHeuristics.allKnownCompanyIDs.contains(cid) {
            matched = true
            reason = SmartGlassesHeuristics.classifyCompanyID(cid).rawValue
        } else if let n = name, SmartGlassesHeuristics.matchesKnownName(n) {
            matched = true
            reason = "Name match"
        } else {
            // When scanning with service UUID filter, a callback means the device
            // advertises one of our known service UUIDs — treat it as a match even
            // without manufacturer data (background mode strips some AD fields).
            let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
            let hasKnownService = serviceUUIDs.contains { SmartGlassesHeuristics.knownServiceUUIDs.contains($0) }
            if hasKnownService {
                matched = true
                reason = "Service UUID"
            } else {
                matched = false
                reason = ""
            }
        }

        // Build detection event if matched + strong enough signal
        let detection: DetectionEvent?
        if matched && rssi >= SmartGlassesHeuristics.defaultRSSIThreshold {
            var glassesType: DetectionEvent.GlassesType?
            if let cid = companyID, SmartGlassesHeuristics.allKnownCompanyIDs.contains(cid) {
                glassesType = SmartGlassesHeuristics.classifyCompanyID(cid)
            }
            if glassesType == nil, let name = name, SmartGlassesHeuristics.matchesKnownName(name) {
                glassesType = .metaRayBan
            }
            // Devices matched only by service UUID default to Meta (0xFD5F is Oculus/Meta)
            if glassesType == nil { glassesType = .metaRayBan }

            if let type = glassesType,
               let fingerprint = detectionFingerprint(companyID: companyID, name: name, serviceUUIDs: advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) {
                detection = DetectionEvent(
                    id: UUID(), fingerprint: fingerprint, timestamp: Date(),
                    deviceName: name, companyID: companyID, rssi: rssi, glassesType: type
                )
            } else {
                detection = nil
            }
        } else {
            detection = nil
        }

        // Update BLE-queue shadow state and notify callback immediately.
        // This fires before the main actor dispatch so Live Activity updates
        // work even when the app is backgrounded and the main actor is throttled.
        if let detection {
            if let idx = bgDetections.firstIndex(where: { $0.fingerprint == detection.fingerprint }) {
                bgDetections[idx].timestamp = detection.timestamp
            } else {
                bgDetections.append(BgDetection(fingerprint: detection.fingerprint, timestamp: detection.timestamp))
            }
            let total = bgDetections.count
            let cutoff = Date().addingTimeInterval(-Self.detectionStaleInterval)
            let nearby = bgDetections.count(where: { $0.timestamp > cutoff })
            Self.log.info("Detection: \(detection.fingerprint) nearby=\(nearby) total=\(total)")
            onDetectionChanged?(nearby, total, detection.timestamp)
        }

        // Update @Observable state on main actor for UI
        Task { @MainActor in
            self.applyDiscovery(
                identifier: identifier, name: name, companyID: companyID,
                rssi: rssi, matched: matched, reason: reason, detection: detection
            )
        }
    }

    // MARK: - Main Actor State Updates

    private func applyDiscovery(
        identifier: String, name: String?, companyID: UInt16?,
        rssi: Int, matched: Bool, reason: String,
        detection: DetectionEvent?
    ) {
        pruneStaleDevices()

        // Update nearby devices list
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
                    id: identifier, name: name, companyID: companyID,
                    rssi: rssi, matched: matched, reason: reason, lastSeen: Date()
                )
                nearbyDevices.append(device)
                nearbyDeviceIndex[identifier] = nearbyDevices.count - 1
            }
        }

        guard let detection else { return }

        if let idx = detections.firstIndex(where: { $0.fingerprint == detection.fingerprint }) {
            detections[idx].rssi = detection.rssi
            detections[idx].timestamp = detection.timestamp
        } else {
            detections.insert(detection, at: 0)
            latestDetection = detection
        }
    }

    // MARK: - Private

    private func beginScan() {
        guard bluetoothState == .poweredOn else { return }

        // Stop any existing scan before starting a new one
        centralManager?.stopScan()

        if useBackgroundSafeFilter {
            // Scan for known smart glasses service UUIDs — works in background.
            // allowDuplicates is ignored by iOS in background but useful in foreground
            // for live RSSI updates.
            Self.log.info("Starting background-safe scan with \(SmartGlassesHeuristics.knownServiceUUIDs.count) service UUIDs")
            centralManager?.scanForPeripherals(
                withServices: SmartGlassesHeuristics.knownServiceUUIDs,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        } else {
            // Wildcard scan — foreground only, populates nearby devices list
            Self.log.info("Starting foreground wildcard scan")
            centralManager?.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
        isScanning = true
    }

    /// Builds a stable fingerprint for deduplication across BLE address rotations.
    nonisolated private func detectionFingerprint(companyID: UInt16?, name: String?, serviceUUIDs: [CBUUID]?) -> String? {
        if let cid = companyID, SmartGlassesHeuristics.allKnownCompanyIDs.contains(cid) {
            return "cid:\(cid)"
        }
        if let name, SmartGlassesHeuristics.matchesKnownName(name) {
            return "name:\(name.lowercased())"
        }
        // Fallback for service-UUID-only matches (background mode may not include manufacturer data)
        if let uuids = serviceUUIDs, !uuids.isEmpty {
            let knownMatch = uuids.first { SmartGlassesHeuristics.knownServiceUUIDs.contains($0) }
            if let uuid = knownMatch {
                return "svc:\(uuid.uuidString)"
            }
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

    nonisolated private func extractCompanyID(from data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        return UInt16(data[data.startIndex]) | (UInt16(data[data.startIndex + 1]) << 8)
    }
}
