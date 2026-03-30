import Foundation
import Vision
import CoreML
import UIKit
import CoreImage
import ImageIO

struct DetectedFace: Identifiable {
    let id = UUID()
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let confidence: Float
    var isBlurred: Bool = true  // For selective blur feature
}

struct FaceDetectionService {
    
    /// Detect faces in a UIImage, returns normalized bounding boxes
    nonisolated static func detectFaces(in image: UIImage) async throws -> [DetectedFace] {
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        if let cgImage = image.cgImage {
            let fallbackImage = CIImage(cgImage: cgImage)
            
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let faces = try performDetection(
                            makeHandler: {
                                VNImageRequestHandler(
                                    cgImage: cgImage,
                                    orientation: orientation,
                                    options: [:]
                                )
                            },
                            fallbackImage: fallbackImage,
                            orientation: orientation
                        )
                        continuation.resume(returning: faces)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        if let ciImage = image.ciImage {
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let faces = try detectFaces(in: ciImage, orientation: orientation)
                        continuation.resume(returning: faces)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        return []
    }
    
    /// Detect faces in a CVPixelBuffer (for video frames)
    nonisolated static func detectFaces(in pixelBuffer: CVPixelBuffer) throws -> [DetectedFace] {
        let fallbackImage = CIImage(cvPixelBuffer: pixelBuffer)
        return try performDetection(
            makeHandler: {
                VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            },
            fallbackImage: fallbackImage,
            orientation: .up
        )
    }

    /// Detect faces in a CVPixelBuffer, returning raw VNFaceObservation for tracking initialization
    nonisolated static func detectFaceObservations(in pixelBuffer: CVPixelBuffer) throws -> [VNFaceObservation] {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequest.defaultRevision

        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            try handler.perform([request])
            return request.results ?? []
        } catch {
            if isInferenceContextCreationFailure(error) {
                let cpuRequest = VNDetectFaceRectanglesRequest()
                configureCPUComputeDevice(for: cpuRequest)
                let cpuHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
                try cpuHandler.perform([cpuRequest])
                return cpuRequest.results ?? []
            }
            throw error
        }
    }
    
    /// Detect faces in a CIImage
    nonisolated static func detectFaces(in ciImage: CIImage) throws -> [DetectedFace] {
        return try detectFaces(in: ciImage, orientation: .up)
    }

    nonisolated private static func detectFaces(
        in ciImage: CIImage,
        orientation: CGImagePropertyOrientation
    ) throws -> [DetectedFace] {
        try performDetection(
            makeHandler: {
                VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
            },
            fallbackImage: ciImage,
            orientation: orientation
        )
    }

    nonisolated private static func performDetection(
        makeHandler: () -> VNImageRequestHandler,
        fallbackImage: CIImage,
        orientation: CGImagePropertyOrientation
    ) throws -> [DetectedFace] {
        do {
            return try performVisionDetection(with: makeHandler(), usesCPUOnly: false)
        } catch {
            var lastError = error
            
            if isInferenceContextCreationFailure(error) {
                do {
                    return try performVisionDetection(with: makeHandler(), usesCPUOnly: true)
                } catch {
                    lastError = error
                }
            }

            return try performCoreImageFallbackDetection(
                in: fallbackImage,
                orientation: orientation,
                preferredError: lastError
            )
        }
    }

    nonisolated private static func performVisionDetection(
        with handler: VNImageRequestHandler,
        usesCPUOnly: Bool
    ) throws -> [DetectedFace] {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequest.defaultRevision
        
        if usesCPUOnly {
            configureCPUComputeDevice(for: request)
        }

        try handler.perform([request])

        let results = request.results ?? []
        return results.map { observation in
            DetectedFace(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence
            )
        }
    }

    nonisolated private static func configureCPUComputeDevice(for request: VNRequest) {
        if #available(iOS 17.0, *) {
            request.setComputeDevice(cpuComputeDevice, for: .main)
        }
    }

    @available(iOS 17.0, *)
    nonisolated private static var cpuComputeDevice: MLComputeDevice? {
        MLComputeDevice.allComputeDevices.first { device in
            if case .cpu = device {
                return true
            }
            return false
        }
    }

    nonisolated private static func performCoreImageFallbackDetection(
        in image: CIImage,
        orientation: CGImagePropertyOrientation,
        preferredError: Error
    ) throws -> [DetectedFace] {
        let detectorOptions: [String: Any] = [
            CIDetectorAccuracy: CIDetectorAccuracyHigh
        ]
        
        guard let detector = CIDetector(
            ofType: CIDetectorTypeFace,
            context: nil,
            options: detectorOptions
        ) else {
            throw preferredError
        }
        
        let features = detector.features(
            in: image,
            options: [CIDetectorImageOrientation: NSNumber(value: orientation.rawValue)]
        )
        .compactMap { $0 as? CIFaceFeature }
        
        return features.map { feature in
            DetectedFace(
                boundingBox: normalizedBoundingBox(for: feature.bounds, in: image.extent),
                confidence: 1.0
            )
        }
    }

    nonisolated private static func normalizedBoundingBox(for bounds: CGRect, in extent: CGRect) -> CGRect {
        guard extent.width > 0, extent.height > 0 else {
            return .zero
        }
        
        let normalized = CGRect(
            x: (bounds.minX - extent.minX) / extent.width,
            y: (bounds.minY - extent.minY) / extent.height,
            width: bounds.width / extent.width,
            height: bounds.height / extent.height
        )
        let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let clamped = normalized.intersection(unitRect)
        
        return clamped.isNull ? .zero : clamped
    }

    nonisolated private static func isInferenceContextCreationFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        return (nsError.domain == "com.apple.Vision" && nsError.code == 9) ||
            nsError.localizedDescription.localizedCaseInsensitiveContains("inference context")
    }
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
