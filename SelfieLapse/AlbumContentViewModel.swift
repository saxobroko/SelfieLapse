// AlbumContentViewModel.swift
// Created by saxobroko
// Last updated: 2025-02-18 02:51:51 UTC

import SwiftUI
import PhotosUI
import AVKit
import Photos
import Darwin

private struct QualityConfig {
    var initialWidth: CGFloat = 256
    var upgradeWidth: CGFloat = 4032
    var compressionQuality: CGFloat = 0.8
    var retryAttempts: Int = 3
    var retryDelay: UInt64 = 2_000_000_000 // 2 seconds
}

private struct MemoryConfig {
    var criticalThresholdMB: Double = 500
    var warningThresholdMB: Double = 300
    var maxBatchSize: Int = 5
    var minBatchSize: Int = 2
    var maxConcurrentOperations: Int = 3
}

enum MemoryWarningLevel: String {
    case none = "Normal"
    case warning = "High Memory Usage"
    case critical = "Critical Memory Usage"
    
    var color: Color {
        switch self {
        case .none: return .clear
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

enum PhotoImportError: LocalizedError {
    case timeout
    case cancelled
    case loadFailed
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Image import timed out"
        case .cancelled:
            return "Image import was cancelled"
        case .loadFailed:
            return "Failed to load image"
        case .notImplemented:
            return "This feature is not yet implemented"
        }
    }
}

@MainActor
class AlbumContentViewModel: ObservableObject {
    // MARK: - Properties
    let album: Album
    let timelapseGenerator: TimelapseGenerator
    let cameraManager: CameraManager
    let onSavePhoto: (UIImage, Date) -> Void
    let onDeletePhoto: (Photo) -> Void
    
    private let qualityConfig = QualityConfig()
    private let memoryConfig = MemoryConfig()
    private var failedImports: [(PHAsset, Int)] = [] // (asset, retryCount)
    private var operationQueue = OperationQueue()
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    @Binding var showingTimelapseSettings: Bool
    @Binding var timelapseSettings: TimelapseSettings
    @Binding var showingTimelapseProgress: Bool
    @Binding var exportURL: URL?
    @Binding var showingPhotosPicker: Bool
    @Binding var showingAlbumPicker: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var showingCamera: Bool
    @Binding var gridColumnCount: Int
    @Binding var selectedPhotoForDetail: Photo?
    @Binding var player: AVPlayer?
    @Binding var showErrorAlert: Bool
    @Binding var errorMessage: String
    @Binding var status: String
    
    @Published var sortedPhotos: [Photo] = []
    @Published var isUpgradingPhotos: Bool = false
    @Published var upgradingProgress: Double = 0
    @Published var memoryWarningLevel: MemoryWarningLevel = .none
    @Published var showMemoryWarning: Bool = false
    @Published var currentBatchSize: Int
    @Published var isRetrying: Bool = false
    
    var importTask: Task<Void, Error>?
    var upgradeTask: Task<Void, Error>?
    private var memoryMonitorTask: Task<Void, Error>?
    
    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 1), count: gridColumnCount)
    }
    // MARK: - Initialization
        init(album: Album,
             timelapseGenerator: TimelapseGenerator,
             cameraManager: CameraManager,
             showingTimelapseSettings: Binding<Bool>,
             timelapseSettings: Binding<TimelapseSettings>,
             showingTimelapseProgress: Binding<Bool>,
             exportURL: Binding<URL?>,
             showingPhotosPicker: Binding<Bool>,
             showingAlbumPicker: Binding<Bool>,
             selectedPhotos: Binding<[PhotosPickerItem]>,
             showingCamera: Binding<Bool>,
             gridColumnCount: Binding<Int>,
             selectedPhotoForDetail: Binding<Photo?>,
             player: Binding<AVPlayer?>,
             showErrorAlert: Binding<Bool>,
             errorMessage: Binding<String>,
             status: Binding<String>,
             onSavePhoto: @escaping (UIImage, Date) -> Void,
             onDeletePhoto: @escaping (Photo) -> Void) {
            self.album = album
            self.timelapseGenerator = timelapseGenerator
            self.cameraManager = cameraManager
            self.onSavePhoto = onSavePhoto
            self.onDeletePhoto = onDeletePhoto
            
            self._showingTimelapseSettings = showingTimelapseSettings
            self._timelapseSettings = timelapseSettings
            self._showingTimelapseProgress = showingTimelapseProgress
            self._exportURL = exportURL
            self._showingPhotosPicker = showingPhotosPicker
            self._showingAlbumPicker = showingAlbumPicker
            self._selectedPhotos = selectedPhotos
            self._showingCamera = showingCamera
            self._gridColumnCount = gridColumnCount
            self._selectedPhotoForDetail = selectedPhotoForDetail
            self._player = player
            self._showErrorAlert = showErrorAlert
            self._errorMessage = errorMessage
            self._status = status
            
            self.currentBatchSize = memoryConfig.maxBatchSize
            
            operationQueue.maxConcurrentOperationCount = memoryConfig.maxConcurrentOperations
            setupMemoryPressureHandling()
            startMemoryMonitoring()
        }

        // MARK: - Public Methods
        func updateSortedPhotos() {
            sortedPhotos = album.photos.sorted { $0.captureDate > $1.captureDate }
        }
        
        func handleTimelapseGeneration() {
            showingTimelapseProgress = true
            Task {
                do {
                    let url = try await timelapseGenerator.generateTimelapse(
                        from: sortedPhotos.reversed(),
                        settings: timelapseSettings
                    )
                    await MainActor.run {
                        exportURL = url
                        player = AVPlayer(url: url)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
        
        func cleanup() {
            importTask?.cancel()
            upgradeTask?.cancel()
            memoryMonitorTask?.cancel()
            memoryPressureSource?.cancel()
            operationQueue.cancelAllOperations()
            player?.pause()
            player = nil
            cleanupMemory()
        }
        
        // MARK: - Private Methods
        private func setupMemoryPressureHandling() {
            memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical])
            memoryPressureSource?.setEventHandler { [weak self] in
                guard let self = self else { return }
                
                Task { @MainActor in
                    switch self.memoryPressureSource?.data {
                    case .some(.warning):
                        self.handleMemoryPressure(.warning)
                    case .some(.critical):
                        self.handleMemoryPressure(.critical)
                    default:
                        break
                    }
                }
            }
            memoryPressureSource?.resume()
        }
        
        private func handleMemoryPressure(_ level: MemoryWarningLevel) {
            switch level {
            case .warning:
                currentBatchSize = max(memoryConfig.minBatchSize, currentBatchSize - 1)
                operationQueue.maxConcurrentOperationCount = max(1, memoryConfig.maxConcurrentOperations - 1)
            case .critical:
                currentBatchSize = memoryConfig.minBatchSize
                operationQueue.maxConcurrentOperationCount = 1
                importTask?.cancel()
                upgradeTask?.cancel()
                cleanupMemory()
            case .none:
                currentBatchSize = memoryConfig.maxBatchSize
                operationQueue.maxConcurrentOperationCount = memoryConfig.maxConcurrentOperations
            }
        }
        
        private func cleanupMemory() {
            autoreleasepool {
                URLCache.shared.removeAllCachedResponses()
            }
        }
        
        private func checkMemoryUsage() -> MemoryWarningLevel {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
            
            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_,
                             task_flavor_t(MACH_TASK_BASIC_INFO),
                             $0,
                             &count)
                }
            }
            
            if kerr == KERN_SUCCESS {
                let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
                if usedMB > memoryConfig.criticalThresholdMB {
                    return .critical
                } else if usedMB > memoryConfig.warningThresholdMB {
                    return .warning
                }
            }
            return .none
        }
        
        private func startMemoryMonitoring() {
            memoryMonitorTask?.cancel()
            memoryMonitorTask = Task {
                while !Task.isCancelled {
                    let newLevel = checkMemoryUsage()
                    if newLevel != .none && newLevel != memoryWarningLevel {
                        memoryWarningLevel = newLevel
                        showMemoryWarning = true
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        
        private func addDelayBasedOnMemory(isUpgrade: Bool = false) async throws {
            let delay = switch memoryWarningLevel {
            case .critical:
                isUpgrade ? UInt64(2_000_000_000) : UInt64(1_000_000_000)
            case .warning:
                isUpgrade ? UInt64(1_000_000_000) : UInt64(500_000_000)
            case .none:
                isUpgrade ? UInt64(500_000_000) : UInt64(100_000_000)
            }
            try await Task.sleep(nanoseconds: delay)
        }
        
        private func retryFailedImports() async throws {
            guard !failedImports.isEmpty else { return }
            
            isRetrying = true
            let currentFailed = failedImports
            failedImports.removeAll()
            
            for (asset, retryCount) in currentFailed {
                guard retryCount < qualityConfig.retryAttempts else {
                    continue
                }
                
                do {
                    try await Task.sleep(nanoseconds: qualityConfig.retryDelay)
                    try await processAsset(asset, at: 0, totalPhotos: 1, retryCount: retryCount + 1)
                } catch {
                    failedImports.append((asset, retryCount + 1))
                }
            }
            
            isRetrying = false
            
            if !failedImports.isEmpty {
                errorMessage = "Some imports failed after multiple retries. You can try importing them again later."
                showErrorAlert = true
            }
        }
        
        private func processHighQualityUpgrade(for photo: Photo, targetWidth: CGFloat) async throws {
            // Implementation depends on your Photo model structure
            throw PhotoImportError.notImplemented
        }
        
        private func startQualityUpgrade() {
            upgradeTask?.cancel()
            
            upgradeTask = Task {
                do {
                    isUpgradingPhotos = true
                    let photos = sortedPhotos
                    let totalPhotos = photos.count
                    
                    for (index, photo) in photos.enumerated() {
                        try Task.checkCancellation()
                        
                        status = "Upgrading photo quality... \(index + 1)/\(totalPhotos)"
                        upgradingProgress = Double(index + 1) / Double(totalPhotos)
                        
                        try await processHighQualityUpgrade(for: photo, targetWidth: qualityConfig.upgradeWidth)
                        
                        autoreleasepool { }
                        try await addDelayBasedOnMemory(isUpgrade: true)
                    }
                    
                    isUpgradingPhotos = false
                    status = ""
                    upgradingProgress = 0
                    updateSortedPhotos()
                } catch is CancellationError {
                    isUpgradingPhotos = false
                    status = "Quality upgrade cancelled"
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    status = ""
                } catch {
                    print("Failed to upgrade photo quality: \(error.localizedDescription)")
                    isUpgradingPhotos = false
                    status = ""
                }
            }
        }
    private func processAsset(_ asset: PHAsset, at index: Int, totalPhotos: Int, retryCount: Int = 0) async throws {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let options = PHImageRequestOptions()
                options.deliveryMode = retryCount > 0 ? .highQualityFormat : .fastFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false
                options.resizeMode = .exact
                
                let targetWidth = retryCount > 0 ? qualityConfig.upgradeWidth : qualityConfig.initialWidth
                let aspectRatio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
                let targetHeight = targetWidth / aspectRatio
                let targetSize = CGSize(width: targetWidth, height: targetHeight)
                
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options
                ) { [weak self] image, info in
                    guard let self = self else {
                        continuation.resume(throwing: PhotoImportError.cancelled)
                        return
                    }
                    
                    if let error = info?[PHImageErrorKey] as? Error {
                        if retryCount < self.qualityConfig.retryAttempts {
                            self.failedImports.append((asset, retryCount))
                        }
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    
                    if let image = image {
                        Task { @MainActor in
                            if let compressedData = image.jpegData(compressionQuality: self.qualityConfig.compressionQuality),
                               let compressedImage = UIImage(data: compressedData) {
                                self.onSavePhoto(compressedImage, asset.creationDate ?? .now)
                            } else {
                                self.onSavePhoto(image, asset.creationDate ?? .now)
                            }
                            
                            self.status = "Importing photos... \(index + 1)/\(totalPhotos)"
                            self.updateSortedPhotos()
                            continuation.resume()
                        }
                    } else {
                        if retryCount < self.qualityConfig.retryAttempts {
                            self.failedImports.append((asset, retryCount))
                        }
                        continuation.resume(throwing: PhotoImportError.loadFailed)
                    }
                }
            }
        }
    }
