import SwiftUI

struct ScreenFlash: View {
    @Binding var isFlashing: Bool
    
    var body: some View {
        Rectangle()
            .fill(.white)
            .ignoresSafeArea()
            .opacity(isFlashing ? 1 : 0)
            // Remove default animation to use controlled animations in CameraView
            .allowsHitTesting(false)
    }
}
