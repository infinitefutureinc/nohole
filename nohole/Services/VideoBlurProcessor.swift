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
        _ = style
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
        intensity: Double,
        maskScale: Double
    ) -> AVVideoComposition {
        let watermarkOverlay = WatermarkRenderer.createWatermarkOverlay(for: renderSize)

        return AVVideoComposition(asset: asset) { [self] request in
            if self.isCancelled {
                request.finish(with: VideoProcessingError.cancelled)
                return
            }

            let sourceImage = request.sourceImage

            do {
                let faces = try FaceDetectionService.detectFaces(in: sourceImage)
                var processedImage = ImageBlurProcessor.blurFaces(
                    in: sourceImage,
                    faces: faces,
                    style: .gaussian,
                    intensity: intensity,
                    maskScale: maskScale
                ) ?? sourceImage

                if let watermarkOverlay {
                    processedImage = watermarkOverlay.composited(over: processedImage)
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
