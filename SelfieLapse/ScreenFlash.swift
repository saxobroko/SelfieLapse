import SwiftUI

struct ScreenFlash: View {
    @Binding var isFlashing: Bool
    
    var body: some View {
        Rectangle()
            .fill(.white)
            .ignoresSafeArea()
            .opacity(isFlashing ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: isFlashing)
    }
}