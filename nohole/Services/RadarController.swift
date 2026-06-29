import ActivityKit
import Foundation
import SwiftUI
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
        scanner.onDetectionChanged = { [weak self] nearby, total, lastAt in
            guard let activityRef else { return }
            Self.log.info("BLE queue detection callback: nearby=\(nearby) total=\(total)")
            let state = RadarActivityAttributes.ContentState(
                nearbyGlassesCount: nearby,
                totalEncountered: total,
                lastDetectionAt: lastAt
            )
            let content = ActivityContent(state: state,
                                          staleDate: Date().addingTimeInterval(300))
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

    /// Call when the app enters/leaves foreground so the scan filter switches
    /// between wildcard (all devices visible) and service-UUID-only (background-safe).
    func scenePhaseChanged(to phase: ScenePhase) {
        guard isActive else { return }
        switch phase {
        case .active:
            scanner.setBackgroundSafeFilter(false)
        case .inactive, .background:
            scanner.setBackgroundSafeFilter(true)
        @unknown default:
            break
        }
    }

    // MARK: - Detection Observer

    /// Polls for detection changes every 2s and pushes LA updates from main actor.
    /// This is the foreground path — ensures the LA stays in sync with the full
    /// @Observable state when the main actor is responsive. Also handles updating
    /// the nearby count as detections go stale.
    private func startDetectionObserver() {
        detectionObserver?.cancel()
        detectionObserver = Task { [weak self] in
            var lastNearby = 0
            var lastTotal = 0
            var lastDate: Date?
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                let currentNearby = self.scanner.nearbyGlassesCount
                let currentTotal = self.scanner.detections.count
                let currentDate = self.scanner.lastDetectionAt
                if currentNearby != lastNearby || currentTotal != lastTotal || currentDate != lastDate {
                    lastNearby = currentNearby
                    lastTotal = currentTotal
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
        .init(nearbyGlassesCount: scanner.nearbyGlassesCount,
              totalEncountered: scanner.detections.count,
              lastDetectionAt: scanner.lastDetectionAt)
    }
}
