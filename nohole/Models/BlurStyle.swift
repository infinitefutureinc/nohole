import Foundation

enum BlurStyle: String, CaseIterable, Identifiable {
    case gaussian = "Gaussian Blur"
    case pixelate = "Pixelate"
    case solidBlack = "Solid Black"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .gaussian: return "aqi.medium"
        case .pixelate: return "squareshape.split.3x3"
        case .solidBlack: return "rectangle.fill"
        }
    }
}
