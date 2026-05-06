import Foundation
import AVFoundation
import CoreImage
import OSLog

@Observable
final class VideoBlurProcessor {
    var progress: Double = 0
    var isProcessing: Bool = false
    var error: String?

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "xyz.infinitefuture.nohole",
        category: "VideoBlurProcessor"
    )
    private var isCancelled = false
    private var activeExportSession: AVAssetExportSession?
    private var progressTask: Task<Void, Never>?

    deinit {
        progressTask?.cancel()
    }

    func cancel() {
        isCancelled = true
        activeExportSession?.cancelExport()
        progressTask?.cancel()
    }

    func processVideo(
        asset: AVAsset,
        style: BlurStyle,
        intensity: Double,
        maskScale: Double,
        excludedFaceIDs: Set<UUID> = []
    ) async throws -> URL {
        _ = excludedFaceIDs

        isProcessing = true
        isCancelled = false
        progress = 0
        error = nil

        defer {
            progressTask?.cancel()
            progressTask = nil
            activeExportSession = nil
            Task { @MainActor in
                self.isProcessing = false
            }
        }

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let renderSize = resolvedRenderSize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )

        logger.info(
            "Starting composition-based video blur. duration=\(duration.seconds, privacy: .public)s renderSize=\(Int(renderSize.width), privacy: .public)x\(Int(renderSize.height), privacy: .public)"
        )

        let videoComposition = makeVideoComposition(
            asset: asset,
            renderSize: renderSize,
            style: style,
            intensity: intensity,
            maskScale: maskScale
        )

        let mp4OutputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: mp4OutputURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoProcessingError.exportFailed
        }

        let outputFileType: AVFileType = exportSession.supportedFileTypes.contains(.mp4) ? .mp4 : .mov
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = false

        let finalOutputURL: URL
        if outputFileType == .mov {
            finalOutputURL = mp4OutputURL.deletingPathExtension().appendingPathExtension("mov")
            try? FileManager.default.removeItem(at: finalOutputURL)
        } else {
            finalOutputURL = mp4OutputURL
        }

        activeExportSession = exportSession

        startProgressUpdates(for: exportSession)

        do {
            try await exportSession.export(to: finalOutputURL, as: outputFileType)
            try throwIfCancelled(cleanupURL: finalOutputURL)
            await MainActor.run {
                self.progress = 1.0
            }
            return finalOutputURL
        } catch {
            try? FileManager.default.removeItem(at: finalOutputURL)
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    private func makeVideoComposition(
        asset: AVAsset,
        renderSize: CGSize,
        style: BlurStyle,
        intensity: Double,
        maskScale: Double
    ) -> AVVideoComposition {
        let faceStabilizer = TemporalFaceStabilizer()

        return AVVideoComposition(asset: asset) { [self] request in
            if self.isCancelled {
                request.finish(with: VideoProcessingError.cancelled)
                return
            }

            let sourceImage = request.sourceImage

            do {
                let detectedFaces = try FaceDetectionService.detectFaces(in: sourceImage)
                let faces = faceStabilizer.stabilizedFaces(
                    from: detectedFaces,
                    at: request.compositionTime
                )
                var processedImage = ImageBlurProcessor.blurFaces(
                    in: sourceImage,
                    faces: faces,
                    style: style,
                    intensity: intensity,
                    maskScale: maskScale
                ) ?? sourceImage

                if let watermark = WatermarkRenderer.createWatermarkOverlay(for: sourceImage.extent.size) {
                    let positioned = watermark.transformed(
                        by: CGAffineTransform(
                            translationX: sourceImage.extent.origin.x,
                            y: sourceImage.extent.origin.y
                        )
                    )
                    processedImage = positioned.composited(over: processedImage)
                }

                request.finish(with: processedImage.cropped(to: sourceImage.extent), context: self.ciContext)
            } catch {
                self.logger.error(
                    "Failed to process frame at \(request.compositionTime.seconds, privacy: .public)s: \(error.localizedDescription, privacy: .public)"
                )
                request.finish(with: error)
            }
        }
    }

    private func startProgressUpdates(for exportSession: AVAssetExportSession) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let currentProgress = Double(exportSession.progress)
                await MainActor.run {
                    self.progress = max(self.progress, currentProgress)
                }

                switch exportSession.status {
                case .completed, .failed, .cancelled:
                    return
                default:
                    break
                }

                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    private func throwIfCancelled(cleanupURL: URL?) throws {
        guard isCancelled else { return }
        if let cleanupURL {
            try? FileManager.default.removeItem(at: cleanupURL)
        }
        throw VideoProcessingError.cancelled
    }

    private func resolvedRenderSize(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> CGSize {
        let transformedSize = naturalSize.applying(preferredTransform)
        return CGSize(
            width: abs(transformedSize.width.rounded(.awayFromZero)),
            height: abs(transformedSize.height.rounded(.awayFromZero))
        )
    }
}

private final class TemporalFaceStabilizer {
    private struct Track {
        var boundingBox: CGRect
        var confidence: Float
        var lastSeenTime: Double
        var missedFrameCount: Int
    }

    private let lock = NSLock()
    private var tracks: [Track] = []
    private var latestTimestamp: Double = -.infinity

    private let maximumGapDuration: Double = 0.18
    private let maximumMissedFrames = 4
    private let minimumIOUForMatch: CGFloat = 0.12
    private let maximumNormalizedCenterDistance: CGFloat = 0.55
    private let smoothingFactor: CGFloat = 0.35
    private let fallbackExpansionPerMiss: CGFloat = 0.05

    func stabilizedFaces(from detections: [DetectedFace], at compositionTime: CMTime) -> [DetectedFace] {
        let timestamp = compositionTime.seconds
        guard timestamp.isFinite else {
            return detections
        }

        lock.lock()
        defer { lock.unlock() }

        // Ignore out-of-order callbacks instead of corrupting temporal state.
        if timestamp + 0.0001 < latestTimestamp {
            return detections
        }
        latestTimestamp = timestamp

        var unmatchedDetections = detections.filter { !$0.boundingBox.isEmpty }
        var nextTracks: [Track] = []
        nextTracks.reserveCapacity(max(tracks.count, unmatchedDetections.count))

        for track in tracks {
            if let matchIndex = bestMatchIndex(for: track.boundingBox, in: unmatchedDetections) {
                let match = unmatchedDetections.remove(at: matchIndex)
                nextTracks.append(
                    Track(
                        boundingBox: track.boundingBox
                            .interpolated(toward: match.boundingBox, factor: smoothingFactor)
                            .clampedToUnitRect(),
                        confidence: max(track.confidence, match.confidence),
                        lastSeenTime: timestamp,
                        missedFrameCount: 0
                    )
                )
            } else if shouldPersist(track: track, at: timestamp) {
                let missCount = track.missedFrameCount + 1
                nextTracks.append(
                    Track(
                        boundingBox: track.boundingBox
                            .expanded(scale: 1 + (CGFloat(missCount) * fallbackExpansionPerMiss))
                            .clampedToUnitRect(),
                        confidence: track.confidence,
                        lastSeenTime: track.lastSeenTime,
                        missedFrameCount: missCount
                    )
                )
            }
        }

        for detection in unmatchedDetections {
            nextTracks.append(
                Track(
                    boundingBox: detection.boundingBox.clampedToUnitRect(),
                    confidence: detection.confidence,
                    lastSeenTime: timestamp,
                    missedFrameCount: 0
                )
            )
        }

        tracks = nextTracks.filter { track in
            track.boundingBox.width > 0 &&
            track.boundingBox.height > 0 &&
            (timestamp - track.lastSeenTime <= maximumGapDuration || track.missedFrameCount == 0)
        }

        return tracks.map { track in
            DetectedFace(
                boundingBox: track.boundingBox,
                confidence: track.confidence
            )
        }
    }

    private func shouldPersist(track: Track, at timestamp: Double) -> Bool {
        track.missedFrameCount < maximumMissedFrames &&
        (timestamp - track.lastSeenTime) <= maximumGapDuration
    }

    private func bestMatchIndex(for trackRect: CGRect, in detections: [DetectedFace]) -> Int? {
        var bestIndex: Int?
        var bestScore: CGFloat = -.infinity

        for (index, detection) in detections.enumerated() {
            let candidateRect = detection.boundingBox
            let iou = trackRect.intersectionOverUnion(with: candidateRect)
            let centerDistance = trackRect.normalizedCenterDistance(to: candidateRect)

            guard iou >= minimumIOUForMatch || centerDistance <= maximumNormalizedCenterDistance else {
                continue
            }

            let score = iou - (centerDistance * 0.25)
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex
    }
}

private extension CGRect {
    static let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    func clampedToUnitRect() -> CGRect {
        let clamped = intersection(Self.unitRect)
        return clamped.isNull ? .zero : clamped
    }

    func expanded(scale: CGFloat) -> CGRect {
        insetBy(
            dx: -width * (scale - 1) / 2,
            dy: -height * (scale - 1) / 2
        )
    }

    func interpolated(toward other: CGRect, factor: CGFloat) -> CGRect {
        CGRect(
            x: minX + ((other.minX - minX) * factor),
            y: minY + ((other.minY - minY) * factor),
            width: width + ((other.width - width) * factor),
            height: height + ((other.height - height) * factor)
        )
    }

    func intersectionOverUnion(with other: CGRect) -> CGFloat {
        let overlap = intersection(other)
        guard !overlap.isNull else {
            return 0
        }

        let overlapArea = overlap.width * overlap.height
        let unionArea = (width * height) + (other.width * other.height) - overlapArea
        guard unionArea > 0 else {
            return 0
        }

        return overlapArea / unionArea
    }

    func normalizedCenterDistance(to other: CGRect) -> CGFloat {
        let deltaX = midX - other.midX
        let deltaY = midY - other.midY
        let distance = sqrt((deltaX * deltaX) + (deltaY * deltaY))
        let normalizer = max(max(width, height), max(other.width, max(other.height, 0.0001)))
        return distance / normalizer
    }
}

enum VideoProcessingError: LocalizedError {
    case noVideoTrack
    case exportFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No video track found"
        case .exportFailed:
            return "Failed to export video"
        case .cancelled:
            return "Processing was cancelled"
        }
    }
}
