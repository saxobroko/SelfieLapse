import UIKit

class ScreenBrightnessManager: ObservableObject {
    private var previousBrightness: CGFloat
    private let maxBrightness: CGFloat = 1.0
    
    init() {
        previousBrightness = UIScreen.main.brightness
    }
    
    func maximizeBrightness() {
        previousBrightness = UIScreen.main.brightness
        
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async {
            // Use a faster animation for flash effect
            UIView.animate(withDuration: 0.05) {
                UIScreen.main.brightness = self.maxBrightness
            }
        }
    }
    
    func restoreBrightness() {
        // Use a slower animation when restoring
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.2) {
                UIScreen.main.brightness = self.previousBrightness
            }
        }
    }
}
