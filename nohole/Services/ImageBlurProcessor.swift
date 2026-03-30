import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImageBlurProcessor {
    
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    private static let videoGaussianDownsampleFactor: CGFloat = 0.35
    
    /// Apply face blur to a UIImage with given settings
    static func blurFaces(
        in image: UIImage,
        faces: [DetectedFace],
        style: BlurStyle,
        intensity: Double,
        maskScale: Double
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = ciImage.extent.size
        
        guard let result = applyBlur(
            to: ciImage,
            faces: faces,
            style: style,
            intensity: intensity,
            maskScale: maskScale,
            imageSize: imageSize
        ) else { return nil }
        
        guard let outputCG = context.createCGImage(result, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// Apply face blur to a CIImage (used for video frames)
    static func blurFaces(
        in ciImage: CIImage,
        faces: [DetectedFace],
        style: BlurStyle,
        intensity: Double,
        maskScale: Double
    ) -> CIImage? {
        let imageSize = ciImage.extent.size
        return applyBlur(
            to: ciImage,
            faces: faces,
            style: style,
            intensity: intensity,
            maskScale: maskScale,
            imageSize: imageSize,
            prefersFastGaussian: true
        )
    }
    
    private static func applyBlur(
        to ciImage: CIImage,
        faces: [DetectedFace],
        style: BlurStyle,
        intensity: Double,
        maskScale: Double,
        imageSize: CGSize,
        prefersFastGaussian: Bool = false
    ) -> CIImage? {
        let activeFaces = faces.filter { $0.isBlurred }
        guard !activeFaces.isEmpty else { return ciImage }

        let scaledRects = activeFaces.map { face in
            // Convert normalized Vision coordinates to image coordinates.
            // Vision uses bottom-left origin, same as Core Image.
            let faceRect = CGRect(
                x: face.boundingBox.origin.x * imageSize.width,
                y: face.boundingBox.origin.y * imageSize.height,
                width: face.boundingBox.width * imageSize.width,
                height: face.boundingBox.height * imageSize.height
            )

            // Scale the mask to ensure full coverage (hair, ears).
            return faceRect.insetBy(
                dx: -faceRect.width * (maskScale - 1.0) / 2.0,
                dy: -faceRect.height * (maskScale - 1.0) / 2.0
            )
        }

        switch style {
        case .gaussian:
            return applyGaussianBlur(
                to: ciImage,
                in: scaledRects,
                intensity: intensity,
                downsampleFactor: prefersFastGaussian ? videoGaussianDownsampleFactor : 1.0
            )
        case .pixelate:
            var result = ciImage
            for scaledRect in scaledRects {
                result = applyPixelate(to: result, in: scaledRect, intensity: intensity)
            }
            return result
        case .solidBlack:
            return applySolidBlack(to: ciImage, in: scaledRects)
        }
    }
    
    private static func applyGaussianBlur(
        to image: CIImage,
        in rects: [CGRect],
        intensity: Double,
        downsampleFactor: CGFloat
    ) -> CIImage {
        // Blur the frame once, then reuse it for each face mask.
        let blurred: CIImage
        if downsampleFactor < 1.0 {
            let downsampled = image.transformed(
                by: CGAffineTransform(scaleX: downsampleFactor, y: downsampleFactor)
            )
            let downsampledExtent = downsampled.extent.integral
            let adjustedSigma = max(intensity * downsampleFactor, 1.0)

            let blurredDownsampled = downsampled
                .clampedToExtent()
                .applyingGaussianBlur(sigma: adjustedSigma)
                .cropped(to: downsampledExtent)

            blurred = blurredDownsampled
                .transformed(by: CGAffineTransform(scaleX: 1.0 / downsampleFactor, y: 1.0 / downsampleFactor))
                .cropped(to: image.extent)
        } else {
            blurred = image
                .clampedToExtent()
                .applyingGaussianBlur(sigma: intensity)
                .cropped(to: image.extent)
        }

        var result = image
        for rect in rects {
            let mask = createEllipticalMask(in: rect, imageExtent: image.extent)

            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = blurred
            blendFilter.backgroundImage = result
            blendFilter.maskImage = mask

            result = blendFilter.outputImage ?? result
        }

        return result
    }
    
    private static func applyPixelate(to image: CIImage, in rect: CGRect, intensity: Double) -> CIImage {
        let scale = max(1, intensity / 2.0)
        
        let pixelateFilter = CIFilter.pixellate()
        pixelateFilter.inputImage = image
        pixelateFilter.scale = Float(scale)
        pixelateFilter.center = CGPoint(x: rect.midX, y: rect.midY)
        
        guard let pixelated = pixelateFilter.outputImage?.cropped(to: image.extent) else { return image }
        
        let mask = createEllipticalMask(in: rect, imageExtent: image.extent)
        
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = pixelated
        blendFilter.backgroundImage = image
        blendFilter.maskImage = mask
        
        return blendFilter.outputImage ?? image
    }
    
    private static func applySolidBlack(to image: CIImage, in rects: [CGRect]) -> CIImage {
        let blackImage = CIImage(color: CIColor.black).cropped(to: image.extent)

        var result = image
        for rect in rects {
            let mask = createEllipticalMask(in: rect, imageExtent: image.extent)

            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = blackImage
            blendFilter.backgroundImage = result
            blendFilter.maskImage = mask

            result = blendFilter.outputImage ?? result
        }

        return result
    }
    
    private static func createEllipticalMask(in rect: CGRect, imageExtent: CGRect) -> CIImage {
        // Create a radial gradient that forms an ellipse matching the face rect
        let centerX = rect.midX
        let centerY = rect.midY
        let radiusX = rect.width / 2.0
        let radiusY = rect.height / 2.0
        let radius = max(radiusX, radiusY)
        
        let gradient = CIFilter.radialGradient()
        gradient.center = CGPoint(x: centerX, y: centerY)
        gradient.radius0 = Float(radius * 0.7)
        gradient.radius1 = Float(radius * 1.1)
        gradient.color0 = CIColor.white
        gradient.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let gradientImage = gradient.outputImage else {
            return CIImage(color: .clear).cropped(to: imageExtent)
        }
        
        // Scale to make elliptical if face rect is not square
        if abs(radiusX - radiusY) > 1 {
            let scaleX = radiusX / radius
            let scaleY = radiusY / radius
            let transform = CGAffineTransform(translationX: centerX, y: centerY)
                .scaledBy(x: scaleX, y: scaleY)
                .translatedBy(x: -centerX, y: -centerY)
            return gradientImage.transformed(by: transform).cropped(to: imageExtent)
        }
        
        return gradientImage.cropped(to: imageExtent)
    }
}
