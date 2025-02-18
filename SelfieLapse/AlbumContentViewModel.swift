// AlbumContentViewModel.swift
// Created by saxobroko
// Last updated: 2025-02-18 02:44:15 UTC

import SwiftUI
import PhotosUI
import AVKit
import Photos
import Darwin

@MainActor
class AlbumContentViewModel: ObservableObject {
    let album: Album
    let timelapseGenerator: TimelapseGenerator
    let cameraManager: CameraManager
    let onSavePhoto: (UIImage, Date) -> Void
    let onDeletePhoto: (Photo) -> Void
    
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
    
    var importTask: Task<Void, Error>?
    var upgradeTask: Task<Void, Error>?
    private var memoryMonitorTask: Task<Void, Error>?
    
    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 1), count: gridColumnCount)
    }
    
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
        
        startMemoryMonitoring()
    }
    
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
    
    func handleSelectedAlbum(_ collection: PHAssetCollection) {
        importTask?.cancel()
        upgradeTask?.cancel()
        
        importTask = Task {
            do {
                status = "Preparing to import album..."
                
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                
                let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                let totalPhotos = assets.count
                var importedCount = 0
                let batchSize = 5
                
                while importedCount < totalPhotos {
                    try Task.checkCancellation()
                    
                    let currentBatchSize = min(batchSize, totalPhotos - importedCount)
                    var currentBatch: [PHAsset] = []
                    
                    for i in 0..<currentBatchSize {
                        let index = importedCount + i
                        guard index < totalPhotos else { break }
                        let asset = assets[index]
                        if asset.mediaType == .image {
                            currentBatch.append(asset)
                        }
                    }
                    
                    if !currentBatch.isEmpty {
                        for (index, asset) in currentBatch.enumerated() {
                            try Task.checkCancellation()
                            try await processAsset(asset, at: importedCount + index, totalPhotos: totalPhotos)
                            
                            autoreleasepool { }
                            try await addDelayBasedOnMemory()
                        }
                    }
                    
                    importedCount += currentBatchSize
                    autoreleasepool { }
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
                
                status = ""
                updateSortedPhotos()
                startQualityUpgrade()
            } catch is CancellationError {
                status = "Import cancelled"
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                status = ""
            } catch {
                errorMessage = "Failed to import album: \(error.localizedDescription)"
                showErrorAlert = true
                status = ""
            }
        }
    }
    
    private func processAsset(_ asset: PHAsset, at index: Int, totalPhotos: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .fast
            
            let targetWidth: CGFloat = 256
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
                    continuation.resume(throwing: error)
                    return
                }
                
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                
                if let image = image {
                    Task { @MainActor in
                        self.onSavePhoto(image, asset.creationDate ?? .now)
                        self.status = "Importing photos... \(index + 1)/\(totalPhotos)"
                        self.updateSortedPhotos()
                        continuation.resume()
                    }
                } else {
                    continuation.resume(throwing: PhotoImportError.loadFailed)
                }
            }
        }
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
                    
                    let targetWidth: CGFloat = 4032
                    try await processHighQualityUpgrade(for: photo, targetWidth: targetWidth)
                    
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
            if usedMB > 500 {
                return .critical
            } else if usedMB > 300 {
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
    
    func cleanup() {
        importTask?.cancel()
        upgradeTask?.cancel()
        memoryMonitorTask?.cancel()
        player?.pause()
        player = nil
    }
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
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Image import timed out"
        case .cancelled:
            return "Image import was cancelled"
        case .loadFailed:
            return "Failed to load image"
        }
    }
}