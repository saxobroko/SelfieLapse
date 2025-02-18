import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var completionHandler: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        // Use high quality capture session preset
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return
        }
        
        do {
            // Configure camera for highest quality
            try device.lockForConfiguration()
            
            // Enable auto focus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Enable auto exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // Enable auto white balance
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Only enable low light boost if supported
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            
            device.unlockForConfiguration()
            
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // Configure photo output for highest quality
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                
                // Get the maximum supported dimensions
                let dimensions = photoOutput.maxPhotoDimensions
                print("Maximum photo dimensions: \(dimensions.width) x \(dimensions.height)")
                
                // Enable depth data delivery if supported
                photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            }
            
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        completionHandler = completion
        
        // Configure photo settings for maximum quality
        let settings = AVCapturePhotoSettings()
        
        // Configure for maximum quality
        settings.flashMode = .off // We're using screen flash instead
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        
        // Start with balanced priority and adjust if needed
        settings.photoQualityPrioritization = .balanced
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completionHandler?(nil)
            return
        }
        completionHandler?(image)
    }
}
