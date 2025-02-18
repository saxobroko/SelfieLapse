import UIKit

class ScreenBrightnessManager {
    private var previousBrightness: CGFloat
    
    init() {
        previousBrightness = UIScreen.main.brightness
    }
    
    func maximizeBrightness() {
        previousBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
    }
    
    func restoreBrightness() {
        UIScreen.main.brightness = previousBrightness
    }
}