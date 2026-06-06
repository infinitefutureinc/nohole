import Foundation
import UIKit
import CoreImage

struct WatermarkRenderer {

    private static let text = "noglasshole.com"
    private static let accentColor = UIColor(red: 184.0/255.0, green: 255.0/255.0, blue: 0.0, alpha: 1.0) // brand green #b8ff00

    static func addWatermark(to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { _ in
            image.draw(at: .zero)
            draw(size: image.size)
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
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(size: size)
        }

        guard let cgImage = watermarkImage.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }

    /// Draws the branded watermark pill into the bottom-right corner of the given size.
    private static func draw(size: CGSize) {
        let fontSize = max(size.width * 0.025, 14)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.95)
        ]
        let textSize = text.size(withAttributes: textAttributes)

        // Brand logo glyph sits to the left of the text.
        let logoSize = fontSize * 1.5
        let logoSpacing = fontSize * 0.45

        // Pill geometry.
        let horizontalPadding = fontSize * 0.7
        let verticalPadding = fontSize * 0.45
        let contentWidth = logoSize + logoSpacing + textSize.width
        let pillWidth = contentWidth + horizontalPadding * 2
        let pillHeight = max(textSize.height, logoSize) + verticalPadding * 2
        let margin = fontSize * 0.8

        let pillRect = CGRect(
            x: size.width - pillWidth - margin,
            y: size.height - pillHeight - margin,
            width: pillWidth,
            height: pillHeight
        )

        // Rounded pill background for contrast against any footage.
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillHeight / 2)
        UIColor.black.withAlphaComponent(0.7).setFill()
        pillPath.fill()

        // Logo.
        let logoRect = CGRect(
            x: pillRect.minX + horizontalPadding,
            y: pillRect.midY - logoSize / 2,
            width: logoSize,
            height: logoSize
        )
        drawLogo(in: logoRect, color: accentColor)

        // Text.
        let textPoint = CGPoint(
            x: logoRect.maxX + logoSpacing,
            y: pillRect.midY - textSize.height / 2
        )
        text.draw(at: textPoint, withAttributes: textAttributes)
    }

    /// Reproduces the noglasshole.com mark (glasses with a "no" slash inside a ring)
    /// from its 32x32 source viewBox, scaled into the given rect.
    private static func drawLogo(in rect: CGRect, color: UIColor) {
        color.setStroke()

        let scale = rect.width / 32.0
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, width: CGFloat) {
            let path = UIBezierPath(
                arcCenter: point(cx, cy),
                radius: r * scale,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            path.lineWidth = width * scale
            path.stroke()
        }
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, width: CGFloat, round: Bool = false) {
            let path = UIBezierPath()
            path.move(to: point(x1, y1))
            path.addLine(to: point(x2, y2))
            path.lineWidth = width * scale
            if round { path.lineCapStyle = .round }
            path.stroke()
        }

        circle(16, 16, 14, width: 1.5)        // outer ring
        circle(11, 16, 4, width: 1.5)         // left lens
        circle(21, 16, 4, width: 1.5)         // right lens
        line(15, 16, 17, 16, width: 1.5)      // bridge
        line(5, 26, 27, 6, width: 2, round: true) // "no" slash
    }
}
