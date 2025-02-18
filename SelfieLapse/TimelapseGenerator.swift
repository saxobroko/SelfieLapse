// Created by saxobroko
// Last updated: 2025-02-17 23:46:37 UTC

import AVFoundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import MobileCoreServices

@MainActor
class TimelapseGenerator: ObservableObject {
    @Published var progress: Double = 0
    @Published var status: String = ""
    private let context = CIContext()
    private var isCancelled = false
    
    // Constants for memory optimization
    private let maxImageDimension: CGFloat = 1280.0
    private let maxMorphSteps = 8
    private let compressionQuality: CGFloat = 0.8
    
    enum TimelapseError: Error, LocalizedError {
        case setupFailed
        case renderFailed
        case cancelled
        case noPhotos
        case exportFailed
        case memoryError
        
        var errorDescription: String? {
            switch self {
            case .setupFailed: return "Failed to setup video export"
            case .renderFailed: return "Failed to render timelapse"
            case .cancelled: return "Timelapse generation cancelled"
            case .noPhotos: return "No photos available for timelapse"
            case .exportFailed: return "Failed to export timelapse"
            case .memoryError: return "Not enough memory to process images"
            }
        }
    }
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func cancel() {
        isCancelled = true
    }
    
    private func scaleImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func optimizedImageSize(for image: UIImage) -> CGSize {
        let scale = min(maxImageDimension / image.size.width, maxImageDimension / image.size.height, 1.0)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
    
    func generateTimelapse(from photos: [Photo], settings: TimelapseSettings) async throws -> URL {
        guard !photos.isEmpty else { throw TimelapseError.noPhotos }
        
        isCancelled = false
        status = "Preparing export..."
        
        // Get directory for saving
        let timelapseDirectory = documentsDirectory.appendingPathComponent("Timelapses", isDirectory: true)
        try? FileManager.default.createDirectory(at: timelapseDirectory, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: .now)
        let outputURL = timelapseDirectory.appendingPathComponent("timelapse-\(timestamp).mp4")
        
        // Delete any existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Get dimensions from first image
        guard let firstImage = photos.first?.image else {
            throw TimelapseError.setupFailed
        }
        
        // Calculate optimal size
        let optimalSize = optimizedImageSize(for: firstImage)
        
        // Setup video writer
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(optimalSize.width),
            AVVideoHeightKey: Int(optimalSize.height),
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                AVVideoExpectedSourceFrameRateKey: settings.fps,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoAllowFrameReorderingKey: false
            ]
        ]
        
        guard let writer = try? AVAssetWriter(url: outputURL, fileType: .mp4) else {
            throw TimelapseError.setupFailed
        }
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(optimalSize.width),
                kCVPixelBufferHeightKey as String: Int(optimalSize.height),
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
        )
        
        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        var frameCount = 0
        let totalFrames = photos.count
        
        if settings.timelapseType == .traditional {
            // Traditional timelapse
            status = "Creating traditional timelapse..."
            
            for (index, photo) in photos.enumerated() {
                if isCancelled { throw TimelapseError.cancelled }
                
                guard let originalImage = photo.image,
                      let scaledImage = scaleImage(originalImage, to: optimalSize),
                      let buffer = createPixelBuffer(from: scaledImage) else { continue }
                
                while !videoInput.isReadyForMoreMediaData {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                
                let frameTime = CMTime(value: CMTimeValue(frameCount),
                                     timescale: CMTimeScale(settings.fps))
                
                adaptor.append(buffer, withPresentationTime: frameTime)
                frameCount += 1
                
                progress = Double(index) / Double(totalFrames)
            }
            
        } else {
            // Morph timelapse
            status = "Creating morph timelapse..."
            
            for i in 0..<(photos.count - 1) {
                if isCancelled { throw TimelapseError.cancelled }
                
                // Load and scale images
                guard let fromOriginal = photos[i].image,
                      let toOriginal = photos[i + 1].image,
                      let fromImage = scaleImage(fromOriginal, to: optimalSize),
                      let toImage = scaleImage(toOriginal, to: optimalSize) else { continue }
                
                let morphSteps = min(Int(settings.fps / 2), maxMorphSteps)
                
                for step in 0...morphSteps {
                    if isCancelled { throw TimelapseError.cancelled }
                    
                    // Process single frame
                    let progress = Double(step) / Double(morphSteps)
                    
                    // Create morphed image
                    let morphedImage: UIImage? = autoreleasepool {
                        do {
                            return try createMorphedImage(from: fromImage,
                                                        to: toImage,
                                                        progress: progress)
                        } catch {
                            return nil
                        }
                    }
                    
                    guard let morphedImage = morphedImage,
                          let buffer = createPixelBuffer(from: morphedImage) else { continue }
                    
                    while !videoInput.isReadyForMoreMediaData {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    
                    let frameTime = CMTime(value: CMTimeValue(frameCount),
                                         timescale: CMTimeScale(settings.fps))
                    
                    adaptor.append(buffer, withPresentationTime: frameTime)
                    frameCount += 1
                }
                
                // Clean up memory
                autoreleasepool {
                    NSCache<NSString, UIImage>().removeAllObjects()
                }
                
                progress = Double(i) / Double(totalFrames - 1)
            }
        }
        
        status = "Finalizing..."
        
        videoInput.markAsFinished()
        await writer.finishWriting()
        
        if writer.status == .failed {
            throw TimelapseError.exportFailed
        }
        
        try? FileManager.default.setAttributes([
            FileAttributeKey.posixPermissions: 0o644,
            FileAttributeKey.protectionKey: FileProtectionType.none
        ], ofItemAtPath: outputURL.path)
        
        // Set UTI type
        try (outputURL as NSURL).setResourceValue(
            UTType.mpeg4Movie.identifier,
            forKey: .typeIdentifierKey
        )
        
        status = "Complete!"
        progress = 1.0
        return outputURL
    }
    
    private func createPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(image.size.width),
                                       Int(image.size.height),
                                       kCVPixelFormatType_32BGRA,
                                       attrs,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: pixelData,
                                    width: Int(image.size.width),
                                    height: Int(image.size.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                    space: rgbColorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }
        
        // Flip the context
        context.translateBy(x: image.size.width, y: image.size.height)
        context.rotate(by: .pi)
        
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        UIGraphicsPopContext()
        
        return pixelBuffer
    }
    
    private func createMorphedImage(from: UIImage, to: UIImage, progress: Double) throws -> UIImage {
        guard let fromCI = CIImage(image: from),
              let toCI = CIImage(image: to) else {
            throw TimelapseError.renderFailed
        }
        
        let transition = CIFilter.dissolveTransition()
        transition.inputImage = fromCI
        transition.targetImage = toCI
        transition.time = Float(progress)
        
        guard let output = transition.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            throw TimelapseError.renderFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
}
