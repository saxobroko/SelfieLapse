import SwiftUI

struct CameraView: View {
    let cameraManager: CameraManager
    let onPhotoTaken: (UIImage?) -> Void
    
    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Button(action: {
                    cameraManager.capturePhoto { image in
                        onPhotoTaken(image)
                    }
                }) {
                    Circle()
                        .fill(.white)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Circle()
                                .stroke(.black.opacity(0.2), lineWidth: 2)
                                .frame(width: 70, height: 70)
                        }
                }
                .padding(.bottom, 30)
            }
        }
    }
}