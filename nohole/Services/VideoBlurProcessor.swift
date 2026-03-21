import Foundation
import AVFoundation
import CoreImage
import UIKit

@Observable
final class VideoBlurProcessor {
    var progress: Double = 0
    var isProcessing: Bool = false
    var error: String?
    
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    func processVideo(
        asset: AVAsset,
        style: BlurStyle,
        intensity: Double,
        maskScale: Double,
        excludedFaceIDs: Set<UUID> = []
    ) async throws -> URL {
        isProcessing = true
        progress = 0
        error = nil
        
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Remove any existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Get video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        let totalFrames = Double(nominalFrameRate) * duration.seconds
        
        // Determine actual video dimensions after transform
        let transformedSize = naturalSize.applying(preferredTransform)
        let videoSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
        
        // Set up reader
        let reader = try AVAssetReader(asset: asset)
        let readerSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerSettings)
        reader.add(readerOutput)
        
        // Set up writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        let writerSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = preferredTransform
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: naturalSize.width,
                kCVPixelBufferHeightKey as String: naturalSize.height
            ]
        )
        
        writer.add(writerInput)
        
        // Copy audio track if present
        var audioWriterInput: AVAssetWriterInput?
        var audioReaderOutput: AVAssetReaderTrackOutput?
        
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let audioReader = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2
                ]
            )
            reader.add(audioReader)
            audioReaderOutput = audioReader
            
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ])
            audioInput.expectsMediaDataInRealTime = false
            writer.add(audioInput)
            audioWriterInput = audioInput
        }
        
        // Create watermark overlay once
        let watermarkOverlay = WatermarkRenderer.createWatermarkOverlay(for: naturalSize)
        
        // Start reading/writing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Process video frames
        var frameCount: Double = 0
        
        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            guard reader.status == .reading else { break }
            
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            
            // Convert to CIImage
            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // Detect faces in this frame
            if let faces = try? FaceDetectionService.detectFaces(in: ciImage) {
                var processedFaces = faces
                // Apply selective blur exclusions
                for i in processedFaces.indices {
                    if excludedFaceIDs.contains(processedFaces[i].id) {
                        processedFaces[i].isBlurred = false
                    }
                }
                
                if let blurred = ImageBlurProcessor.blurFaces(
                    in: ciImage,
                    faces: processedFaces,
                    style: style,
                    intensity: intensity,
                    maskScale: maskScale
                ) {
                    ciImage = blurred
                }
            }
            
            // Add watermark
            if let watermark = watermarkOverlay {
                ciImage = watermark.composited(over: ciImage)
            }
            
            // Write processed frame
            guard let outputPixelBuffer = createPixelBuffer(from: ciImage, size: naturalSize) else {
                continue
            }
            
            pixelBufferAdaptor.append(outputPixelBuffer, withPresentationTime: presentationTime)
            
            frameCount += 1
            let currentProgress = min(frameCount / totalFrames, 1.0)
            await MainActor.run {
                self.progress = currentProgress
            }
        }
        
        // Write audio samples
        if let audioOutput = audioReaderOutput, let audioInput = audioWriterInput {
            while let audioBuffer = audioOutput.copyNextSampleBuffer() {
                while !audioInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 10_000_000)
                }
                audioInput.append(audioBuffer)
            }
            audioInput.markAsFinished()
        }
        
        writerInput.markAsFinished()
        
        await writer.finishWriting()
        
        if writer.status == .failed {
            throw writer.error ?? VideoProcessingError.writeFailed
        }
        
        await MainActor.run {
            self.progress = 1.0
        }
        
        return outputURL
    }
    
    private func createPixelBuffer(from ciImage: CIImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        ciContext.render(ciImage, to: buffer)
        return buffer
    }
}

enum VideoProcessingError: LocalizedError {
    case noVideoTrack
    case writeFailed
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "No video track found"
        case .writeFailed: return "Failed to write video"
        case .cancelled: return "Processing was cancelled"
        }
    }
}
