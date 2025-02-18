import SwiftUI
import AVFoundation

struct CameraView: View {
    let cameraManager: CameraManager
    let onPhotoTaken: (UIImage?) -> Void
    
    @StateObject private var preferences = UserPreferences.shared
    @State private var isFlashing = false
    @State private var showingGuidelines = true
    @State private var showingCountdown = false
    @State private var countdown = 3
    @State private var timer: Timer?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var brightnessManager = ScreenBrightnessManager()
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Flash overlay
            ScreenFlash(isFlashing: $isFlashing)
            
            // Guidelines overlay
            if showingGuidelines {
                GuidelineOverlay()
                    .allowsHitTesting(false)
            }
            
            // Countdown overlay
            if showingCountdown {
                Text("\(countdown)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            
            // Camera controls
            VStack {
                // Top toolbar
                HStack {
                    // Dismiss button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Guidelines toggle
                    Button {
                        withAnimation {
                            showingGuidelines.toggle()
                        }
                    } label: {
                        Image(systemName: showingGuidelines ? "grid" : "grid.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    // Flash toggle
                    Button {
                        preferences.isFlashEnabled.toggle()
                    } label: {
                        Image(systemName: preferences.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundColor(preferences.isFlashEnabled ? .yellow : .white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                // Bottom controls
                HStack {
                    // Timer button
                    Button {
                        startCountdown()
                    } label: {
                        Image(systemName: "timer")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    // Shutter button
                    Button(action: {
                        if !showingCountdown {
                            takePhoto()
                        }
                    }) {
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 70, height: 70)
                            }
                    }
                    .disabled(showingCountdown)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Circle()
                        .fill(.clear)
                        .frame(width: 44, height: 44)
                        .padding(.trailing)
                }
                .padding(.bottom, 30)
            }
        }
        .onDisappear {
            brightnessManager.restoreBrightness()
            timer?.invalidate()
        }
    }
    
    private func startCountdown() {
        showingCountdown = true
        countdown = 3
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer.invalidate()
                showingCountdown = false
                takePhoto()
            }
        }
    }
    
    private func takePhoto() {
        if preferences.isFlashEnabled {
            // 1. Maximize brightness
            brightnessManager.maximizeBrightness()
            
            // 2. Show flash overlay
            withAnimation(.easeIn(duration: 0.05)) {
                isFlashing = true
            }
            
            // 3. Wait for flash to be fully visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 4. Take photo
                cameraManager.capturePhoto { image in
                    // 5. Start fading out flash
                    withAnimation(.easeOut(duration: 0.2)) {
                        isFlashing = false
                    }
                    
                    // 6. Restore brightness
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        brightnessManager.restoreBrightness()
                    }
                    
                    // 7. Handle captured image
                    onPhotoTaken(image)
                }
            }
        } else {
            cameraManager.capturePhoto { image in
                onPhotoTaken(image)
            }
        }
    }
}

// Guidelines overlay
struct GuidelineOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Vertical lines
                HStack {
                    ForEach(1..<3) { _ in
                        Spacer()
                        Rectangle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 0.5)
                        Spacer()
                    }
                }
                
                // Horizontal lines
                VStack {
                    ForEach(1..<3) { _ in
                        Spacer()
                        Rectangle()
                            .fill(.white.opacity(0.3))
                            .frame(height: 0.5)
                        Spacer()
                    }
                }
                
                // Face outline guide
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
                    .frame(width: min(geometry.size.width, geometry.size.height) * 0.5)
            }
        }
    }
}

#Preview {
    CameraView(cameraManager: CameraManager()) { _ in }
}
