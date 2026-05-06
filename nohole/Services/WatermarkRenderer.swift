import Foundation
import UIKit
import CoreImage

struct WatermarkRenderer {
    
    static func addWatermark(to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            image.draw(at: .zero)
            
            let text = "NoGlasshole"
            let fontSize = max(image.size.width * 0.025, 14)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let padding = fontSize * 0.8
            let point = CGPoint(
                x: image.size.width - textSize.width - padding,
                y: image.size.height - textSize.height - padding
            )
            
            // Draw subtle shadow for readability
            let shadowAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.black.withAlphaComponent(0.3)
            ]
            text.draw(at: CGPoint(x: point.x + 1, y: point.y + 1), withAttributes: shadowAttributes)
            text.draw(at: point, withAttributes: attributes)
        }
    }
    
    /// Create a watermark CIImage overlay for video frames
    static func createWatermarkOverlay(for size: CGSize) -> CIImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let watermarkImage = renderer.image { context in
            // Transparent background
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let text = "NoGlasshole"
            let fontSize = max(size.width * 0.025, 14)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let padding = fontSize * 0.8
            let point = CGPoint(
                x: size.width - textSize.width - padding,
                y: size.height - textSize.height - padding
            )
            
            let shadowAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.black.withAlphaComponent(0.3)
            ]
            text.draw(at: CGPoint(x: point.x + 1, y: point.y + 1), withAttributes: shadowAttributes)
            text.draw(at: point, withAttributes: attributes)
        }
        
        guard let cgImage = watermarkImage.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }
}
