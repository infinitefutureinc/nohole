import ActivityKit
import Foundation
import os

@Observable @MainActor
final class RadarController {
    static let shared = RadarController(scanner: .shared)

    private static let log = Logger(subsystem: "xyz.infinitefuture.nohole", category: "Radar")

    private(set) var isActive = false

    let scanner: BLEScanner
    private var activity: Activity<RadarActivityAttributes>?
    private var detectionObserver: Task<Void, Never>?

    init(scanner: BLEScanner) {
        self.scanner = scanner
        self.activity = Activity<RadarActivityAttributes>.activities.first
    }

    func start() async {
        guard !isActive else { return }
        isActive = true

        // Start the Live Activity first — this grants background BLE privileges
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            startActivity()
        }

        // Wire up the BLE-queue callback so detections push to the LA immediately,
        // without waiting for the main actor (which is throttled in background).
        // This closure runs on the BLE serial queue — no main actor hop needed.
        let activityRef = activity
        scanner.onDetectionChanged = { [weak self] count, lastAt in
            guard let activityRef else { return }
            Self.log.info("BLE queue detection callback: count=\(count) lastAt=\(String(describing: lastAt))")
            let state = RadarActivityAttributes.ContentState(
                detectedGlassesCount: count,
                lastDetectionAt: lastAt,
                nearbyDeviceCount: 0  // approximate; nearby count is cosmetic
            )
            let content = ActivityContent(state: state,
                                          staleDate: Date().addingTimeInterval(300))
            // Activity.update is sendable and safe to call from any queue.
            Task { await activityRef.update(content) }
        }

        // Start continuous scanning
        scanner.beginScanWindow()
        startDetectionObserver()
        await pushUpdate()
    }

    func stop() async {
        detectionObserver?.cancel(); detectionObserver = nil
        scanner.onDetectionChanged = nil
        scanner.endScanWindow()
        await endActivity()
        isActive = false
    }

    // MARK: - Detection Observer

    /// Polls for detection changes every 2s and pushes LA updates from main actor.
    /// This is the foreground path — ensures the LA stays in sync with the full
    /// @Observable state when the main actor is responsive.
    private func startDetectionObserver() {
        detectionObserver?.cancel()
        detectionObserver = Task { [weak self] in
            var lastCount = 0
            var lastDate: Date?
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                let currentCount = self.scanner.detections.count
                let currentDate = self.scanner.lastDetectionAt
                if currentCount != lastCount || currentDate != lastDate {
                    lastCount = currentCount
                    lastDate = currentDate
                    await self.pushUpdate()
                }
            }
        }
    }

    // MARK: - Live Activity

    private func startActivity() {
        let content = ActivityContent(state: makeState(),
                                      staleDate: Date().addingTimeInterval(300))
        activity = try? Activity.request(
            attributes: RadarActivityAttributes(),
            content: content,
            pushType: nil)
        Self.log.info("Live Activity started: \(self.activity?.id ?? "nil")")
    }

    private func pushUpdate() async {
        guard let activity else { return }
        await activity.update(ActivityContent(state: makeState(),
                                              staleDate: Date().addingTimeInterval(300)))
    }

    private func endActivity() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }

    private func makeState() -> RadarActivityAttributes.ContentState {
        .init(detectedGlassesCount: scanner.detections.count,
              lastDetectionAt: scanner.lastDetectionAt,
              nearbyDeviceCount: scanner.nearbyDevices.count)
    }
}
