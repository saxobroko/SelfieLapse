import AVFoundation
import UIKit

class CameraManager: ObservableObject {
    private let session = AVCaptureSession()
    private var camera: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    @Published var isReady = false
    @Published var error: Error?
    
    init() {
        setupCamera()
    }
    
    func setupCamera() {
        session.sessionPreset = .photo
        
        camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                       for: .video,
                                       position: .front)
        
        guard let camera = camera,
              let input = try? AVCaptureDeviceInput(device: camera) else {
            error = CameraError.setupFailed
            return
        }
        
        photoOutput = AVCapturePhotoOutput()
        
        if session.canAddInput(input) && 
           session.canAddOutput(photoOutput!) {
            session.addInput(input)
            session.addOutput(photoOutput!)
            isReady = true
        } else {
            error = CameraError.setupFailed
        }
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        session.startRunning()
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
    
    @MainActor
    func capturePhoto(completion: @escaping (UIImage?) -> Void) async {
        guard let photoOutput = photoOutput else {
            completion(nil)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings) { photoData, error in
            if let error = error {
                self.error = error
                completion(nil)
                return
            }
            
            guard let data = photoData,
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            
            completion(image)
        }
    }
    
    enum CameraError: Error {
        case setupFailed
        case captureError
    }
}