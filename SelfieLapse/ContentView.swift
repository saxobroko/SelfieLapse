import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    
    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                CameraPreview(cameraManager: cameraManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Button(action: {
                cameraManager.capturePhoto { image in
                    self.capturedImage = image
                }
            }) {
                Image(systemName: "camera.circle.fill")
                    .font(.largeTitle)
                    .padding()
            }
        }
    }
}
