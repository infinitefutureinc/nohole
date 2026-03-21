import Foundation
import SwiftUI

@Observable
final class AppSettings {
    var blurIntensity: Double {
        didSet { UserDefaults.standard.set(blurIntensity, forKey: "blurIntensity") }
    }
    var blurStyle: BlurStyle {
        didSet { UserDefaults.standard.set(blurStyle.rawValue, forKey: "blurStyle") }
    }
    var selectiveBlurEnabled: Bool {
        didSet { UserDefaults.standard.set(selectiveBlurEnabled, forKey: "selectiveBlurEnabled") }
    }
    var maskScale: Double {
        didSet { UserDefaults.standard.set(maskScale, forKey: "maskScale") }
    }
    
    init() {
        let defaults = UserDefaults.standard
        self.blurIntensity = defaults.object(forKey: "blurIntensity") as? Double ?? 30.0
        self.blurStyle = BlurStyle(rawValue: defaults.string(forKey: "blurStyle") ?? "") ?? .gaussian
        self.selectiveBlurEnabled = defaults.bool(forKey: "selectiveBlurEnabled")
        self.maskScale = defaults.object(forKey: "maskScale") as? Double ?? 1.3
    }
}
