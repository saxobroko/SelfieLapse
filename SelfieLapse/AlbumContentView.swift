// Created by saxobroko
// Last updated: 2025-02-18 00:29:55 UTC

import SwiftUI
import PhotosUI
import AVKit
import Photos

struct AlbumContentView: View {
    let album: Album
    let timelapseGenerator: TimelapseGenerator
    let cameraManager: CameraManager
    @Binding var showingTimelapseSettings: Bool
    @Binding var timelapseSettings: TimelapseSettings
    @Binding var showingTimelapseProgress: Bool
    @Binding var exportURL: URL?
    @Binding var showingPhotosPicker: Bool
    @Binding var showingAlbumPicker: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var selectedAssetCollection: PHAssetCollection?
    @Binding var showingCamera: Bool
    @Binding var gridColumnCount: Int
    @Binding var selectedPhotoForDetail: Photo?
    @Binding var player: AVPlayer?
    @Binding var showErrorAlert: Bool
    @Binding var errorMessage: String
    @Binding var status: String
    let onSavePhoto: (UIImage, Date) -> Void
    let onDeletePhoto: (Photo) -> Void
    
    @State private var sortedPhotos: [Photo] = []
    
    private func updateSortedPhotos() {
        sortedPhotos = album.photos.sorted { $0.captureDate > $1.captureDate }
    }
    
    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 1), count: gridColumnCount)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                PhotoGridView(
                    photos: sortedPhotos,
                    gridColumns: gridColumns,
                    onPhotoSelected: { photo in
                        selectedPhotoForDetail = photo
                    }
                )
                .animation(.spring(duration: 0.3), value: sortedPhotos)
                
                ControlsView(
                    album: album,
                    gridColumnCount: $gridColumnCount,
                    showingPhotosPicker: $showingPhotosPicker,
                    showingAlbumPicker: $showingAlbumPicker,
                    showingCamera: $showingCamera,
                    showingTimelapseSettings: $showingTimelapseSettings
                )
            }
            
            if !status.isEmpty {
                LoadingOverlay(message: status)
            }
        }
        .onAppear {
            updateSortedPhotos()
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(
            isPresented: $showingPhotosPicker,
            selection: $selectedPhotos,
            matching: .images,
            preferredItemEncoding: .current
        )
        .photosPicker(
            isPresented: $showingAlbumPicker,
            selection: $selectedAssetCollection,
            matching: [.albums, .smartAlbums],
            preferredItemEncoding: .current
        )
        .onChange(of: selectedPhotos) { oldValue, newValue in
            guard !newValue.isEmpty else { return }
            
            Task {
                status = "Preparing to import photos..."
                let totalPhotos = selectedPhotos.count
                var importedCount = 0
                var currentBatch = [PhotosPickerItem]()
                
                for item in selectedPhotos {
                    currentBatch.append(item)
                    
                    if currentBatch.count >= 50 {
                        await processBatch(currentBatch, totalPhotos: totalPhotos, startingCount: importedCount)
                        importedCount += currentBatch.count
                        currentBatch.removeAll()
                    }
                }
                
                if !currentBatch.isEmpty {
                    await processBatch(currentBatch, totalPhotos: totalPhotos, startingCount: importedCount)
                }
                
                await MainActor.run {
                    selectedPhotos.removeAll()
                    status = ""
                    updateSortedPhotos()
                }
            }
        }
        .onChange(of: selectedAssetCollection) { oldValue, newValue in
            guard let collection = selectedAssetCollection else { return }
            
            Task {
                status = "Preparing to import album..."
                
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                
                let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                let totalPhotos = assets.count
                var importedCount = 0
                var currentBatch = [PHAsset]()
                
                for i in 0..<totalPhotos {
                    let asset = assets[i]
                    if asset.mediaType == .image {
                        currentBatch.append(asset)
                        
                        if currentBatch.count >= 50 {
                            await processAssetBatch(currentBatch, totalPhotos: totalPhotos, startingCount: importedCount)
                            importedCount += currentBatch.count
                            currentBatch.removeAll()
                        }
                    }
                }
                
                if !currentBatch.isEmpty {
                    await processAssetBatch(currentBatch, totalPhotos: totalPhotos, startingCount: importedCount)
                }
                
                await MainActor.run {
                    selectedAssetCollection = nil
                    status = ""
                    updateSortedPhotos()
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(cameraManager: cameraManager) { image in
                if let image = image {
                    onSavePhoto(image, .now)
                }
            }
        }
        .sheet(item: $selectedPhotoForDetail) { photo in
            PhotoDetailView(photo: photo) { photo in
                onDeletePhoto(photo)
            }
        }
        .sheet(isPresented: $showingTimelapseSettings) {
            TimelapseSettingsView(settings: $timelapseSettings) {
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
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTimelapseProgress) {
            TimelapseProgressView(
                progress: timelapseGenerator.progress,
                status: timelapseGenerator.status,
                exportURL: exportURL,
                player: $player,
                showingProgress: $showingTimelapseProgress,
                errorMessage: $errorMessage,
                showErrorAlert: $showErrorAlert
            )
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func processBatch(_ batch: [PhotosPickerItem], totalPhotos: Int, startingCount: Int) async {
        await withTaskGroup(of: Void.self) { group in
            for item in batch {
                group.addTask {
                    do {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            var captureDate = Date()
                            if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
                               let exif = properties["{Exif}"] as? [String: Any],
                               let dateTimeOriginal = exif["DateTimeOriginal"] as? String {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                                if let date = formatter.date(from: dateTimeOriginal) {
                                    captureDate = date
                                }
                            }
                            
                            await MainActor.run {
                                onSavePhoto(image, captureDate)
                                status = "Importing photos... \(startingCount + batch.firstIndex(of: item)! + 1)/\(totalPhotos)"
                                updateSortedPhotos()
                            }
                        }
                    } catch {
                        print("Error processing photo: \(error)")
                    }
                }
            }
        }
    }
    
    private func processAssetBatch(_ batch: [PHAsset], totalPhotos: Int, startingCount: Int) async {
        await withTaskGroup(of: Void.self) { group in
            for asset in batch {
                group.addTask {
                    let options = PHImageRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    options.isSynchronous = false
                    
                    await withCheckedContinuation { continuation in
                        PHImageManager.default().requestImage(
                            for: asset,
                            targetSize: PHImageManagerMaximumSize,
                            contentMode: .default,
                            options: options
                        ) { image, info in
                            if let image = image {
                                Task { @MainActor in
                                    onSavePhoto(image, asset.creationDate ?? .now)
                                    status = "Importing photos... \(startingCount + batch.firstIndex(of: asset)! + 1)/\(totalPhotos)"
                                    updateSortedPhotos()
                                }
                            }
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }
}