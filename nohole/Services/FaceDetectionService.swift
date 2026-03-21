import Foundation
import Vision
import UIKit
import CoreImage

struct DetectedFace: Identifiable {
    let id = UUID()
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let confidence: Float
    var isBlurred: Bool = true  // For selective blur feature
}

struct FaceDetectionService {
    
    /// Detect faces in a UIImage, returns normalized bounding boxes
    static func detectFaces(in image: UIImage) async throws -> [DetectedFace] {
        guard let cgImage = image.cgImage else {
            return []
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let faces = results.map { observation in
                    DetectedFace(
                        boundingBox: observation.boundingBox,
                        confidence: observation.confidence
                    )
                }
                
                continuation.resume(returning: faces)
            }
            
            request.revision = VNDetectFaceRectanglesRequestRevision3
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Detect faces in a CVPixelBuffer (for video frames)
    static func detectFaces(in pixelBuffer: CVPixelBuffer) throws -> [DetectedFace] {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try handler.perform([request])
        
        guard let results = request.results else {
            return []
        }
        
        return results.map { observation in
            DetectedFace(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence
            )
        }
    }
    
    /// Detect faces in a CIImage
    static func detectFaces(in ciImage: CIImage) throws -> [DetectedFace] {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up, options: [:])
        try handler.perform([request])
        
        guard let results = request.results else {
            return []
        }
        
        return results.map { observation in
            DetectedFace(
                boundingBox: observation.boundingBox,
                confidence: observation.confidence
            )
        }
    }
}
