// AlbumContentView.swift
// Created by saxobroko
// Last updated: 2025-02-18 03:14:15 UTC

import SwiftUI
import PhotosUI
import AVKit
import Photos

// MARK: - Supporting Types
struct AlbumContentBindings {
    var showingTimelapseSettings: Binding<Bool>
    var timelapseSettings: Binding<TimelapseSettings>
    var showingTimelapseProgress: Binding<Bool>
    var exportURL: Binding<URL?>
    var showingPhotosPicker: Binding<Bool>
    var showingAlbumPicker: Binding<Bool>
    var selectedPhotos: Binding<[PhotosPickerItem]>
    var showingCamera: Binding<Bool>
    var gridColumnCount: Binding<Int>
    var selectedPhotoForDetail: Binding<Photo?>
    var player: Binding<AVPlayer?>
    var showErrorAlert: Binding<Bool>
    var errorMessage: Binding<String>
    var status: Binding<String>
}

struct AlbumContentHandlers {
    var onSavePhoto: (UIImage, Date) -> Void
    var onDeletePhoto: (Photo) -> Void
}

protocol AlbumSelectionHandler {
    func handleSelectedAlbum(_ collection: PHAssetCollection)
}

// MARK: - Preview Helpers
extension Album {
    static var preview: Album {
        Album(name: "Preview Album")
    }
}

extension TimelapseSettings {
    static var `default`: TimelapseSettings {
        TimelapseSettings()
    }
}

struct AlbumContentView: View {
    @StateObject private var viewModel: AlbumContentViewModel
    
    init(
        album: Album,
        timelapseGenerator: TimelapseGenerator,
        cameraManager: CameraManager,
        bindings: AlbumContentBindings,
        handlers: AlbumContentHandlers
    ) {
        _viewModel = StateObject(wrappedValue: AlbumContentViewModel(
            album: album,
            timelapseGenerator: timelapseGenerator,
            cameraManager: cameraManager,
            showingTimelapseSettings: bindings.showingTimelapseSettings,
            timelapseSettings: bindings.timelapseSettings,
            showingTimelapseProgress: bindings.showingTimelapseProgress,
            exportURL: bindings.exportURL,
            showingPhotosPicker: bindings.showingPhotosPicker,
            showingAlbumPicker: bindings.showingAlbumPicker,
            selectedPhotos: bindings.selectedPhotos,
            showingCamera: bindings.showingCamera,
            gridColumnCount: bindings.gridColumnCount,
            selectedPhotoForDetail: bindings.selectedPhotoForDetail,
            player: bindings.player,
            showErrorAlert: bindings.showErrorAlert,
            errorMessage: bindings.errorMessage,
            status: bindings.status,
            onSavePhoto: handlers.onSavePhoto,
            onDeletePhoto: handlers.onDeletePhoto
        ))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                photoGrid
                controls
            }
            
            overlays
        }
        .onAppear { viewModel.updateSortedPhotos() }
        .navigationTitle(viewModel.album.name)
        .navigationBarTitleDisplayMode(.inline)
        .withPhotosPicker(viewModel: viewModel)
        .withSheets(viewModel: viewModel)
        .withAlerts(viewModel: viewModel)
        .withToolbar(viewModel: viewModel)
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - View Components
    private var photoGrid: some View {
        PhotoGridView(
            photos: viewModel.sortedPhotos,
            gridColumns: viewModel.gridColumns,
            onPhotoSelected: { photo in
                viewModel.selectedPhotoForDetail = photo
            }
        )
        .animation(.spring(duration: 0.3), value: viewModel.sortedPhotos)
    }
    
    private var controls: some View {
        ControlsView(
            album: viewModel.album,
            gridColumnCount: Binding(
                get: { self.viewModel.gridColumnCount },
                set: { self.viewModel.gridColumnCount = $0 }
            ),
            showingPhotosPicker: Binding(
                get: { self.viewModel.showingPhotosPicker },
                set: { self.viewModel.showingPhotosPicker = $0 }
            ),
            showingAlbumPicker: Binding(
                get: { self.viewModel.showingAlbumPicker },
                set: { self.viewModel.showingAlbumPicker = $0 }
            ),
            showingCamera: Binding(
                get: { self.viewModel.showingCamera },
                set: { self.viewModel.showingCamera = $0 }
            ),
            showingTimelapseSettings: Binding(
                get: { self.viewModel.showingTimelapseSettings },
                set: { self.viewModel.showingTimelapseSettings = $0 }
            )
        )
    }
    
    private var overlays: some View {
        ZStack {
            if !viewModel.status.isEmpty {
                LoadingOverlay(message: viewModel.status)
            }
            
            if viewModel.isUpgradingPhotos {
                upgradeProgressView
            }
        }
    }
    
    private var upgradeProgressView: some View {
        VStack {
            ProgressView(value: viewModel.upgradingProgress) {
                Text("Upgrading photo quality...")
            }
            .progressViewStyle(.linear)
            .padding()
            .background(.ultraThinMaterial)
        }
        .transition(.move(edge: .bottom))
    }
}

// MARK: - View Modifiers
private extension View {
    func withPhotosPicker(viewModel: AlbumContentViewModel) -> some View {
        photosPicker(
            isPresented: Binding(
                get: { viewModel.showingPhotosPicker },
                set: { viewModel.showingPhotosPicker = $0 }
            ),
            selection: Binding(
                get: { viewModel.selectedPhotos },
                set: { viewModel.selectedPhotos = $0 }
            ),
            matching: .images,
            preferredItemEncoding: .current
        )
    }
    
    func withSheets(viewModel: AlbumContentViewModel) -> some View {
        self
            .sheet(isPresented: Binding(
                get: { viewModel.showingAlbumPicker },
                set: { viewModel.showingAlbumPicker = $0 }
            )) {
                AlbumListView { collection in
                    viewModel.handleSelectedAlbum(collection)
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showingCamera },
                set: { viewModel.showingCamera = $0 }
            )) {
                CameraView(cameraManager: viewModel.cameraManager) { image in
                    if let image = image {
                        viewModel.onSavePhoto(image, .now)
                    }
                }
            }
            .sheet(item: Binding(
                get: { viewModel.selectedPhotoForDetail },
                set: { viewModel.selectedPhotoForDetail = $0 }
            )) { photo in
                PhotoDetailView(photo: photo) { photo in
                    viewModel.onDeletePhoto(photo)
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showingTimelapseSettings },
                set: { viewModel.showingTimelapseSettings = $0 }
            )) {
                TimelapseSettingsView(settings: Binding(
                    get: { viewModel.timelapseSettings },
                    set: { viewModel.timelapseSettings = $0 }
                )) {
                    viewModel.handleTimelapseGeneration()
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showingTimelapseProgress },
                set: { viewModel.showingTimelapseProgress = $0 }
            )) {
                TimelapseProgressView(
                    progress: viewModel.timelapseGenerator.progress,
                    status: viewModel.timelapseGenerator.status,
                    exportURL: viewModel.exportURL,
                    player: Binding(
                        get: { viewModel.player },
                        set: { viewModel.player = $0 }
                    ),
                    showingProgress: Binding(
                        get: { viewModel.showingTimelapseProgress },
                        set: { viewModel.showingTimelapseProgress = $0 }
                    ),
                    errorMessage: Binding(
                        get: { viewModel.errorMessage },
                        set: { viewModel.errorMessage = $0 }
                    ),
                    showErrorAlert: Binding(
                        get: { viewModel.showErrorAlert },
                        set: { viewModel.showErrorAlert = $0 }
                    )
                )
            }
    }
    
    func withAlerts(viewModel: AlbumContentViewModel) -> some View {
        self
            .alert("Error", isPresented: Binding(
                get: { viewModel.showErrorAlert },
                set: { viewModel.showErrorAlert = $0 }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Memory Warning", isPresented: Binding(
                get: { viewModel.showMemoryWarning },
                set: { viewModel.showMemoryWarning = $0 }
            )) {
                Button("OK", role: .cancel) {
                    viewModel.showMemoryWarning = false
                }
            } message: {
                Text("The app is using \(viewModel.memoryWarningLevel.rawValue) memory. Consider closing other apps or restarting the app if performance degrades.")
            }
    }
    
    func withToolbar(viewModel: AlbumContentViewModel) -> some View {
        toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isUpgradingPhotos {
                    Button("Cancel") {
                        viewModel.upgradeTask?.cancel()
                    }
                }
            }
        }
    }
}

// MARK: - Preview Provider
#Preview {
    NavigationStack {
        AlbumContentView(
            album: .preview,
            timelapseGenerator: TimelapseGenerator(),
            cameraManager: CameraManager(),
            bindings: AlbumContentBindings(
                showingTimelapseSettings: .constant(false),
                timelapseSettings: .constant(.default),
                showingTimelapseProgress: .constant(false),
                exportURL: .constant(nil),
                showingPhotosPicker: .constant(false),
                showingAlbumPicker: .constant(false),
                selectedPhotos: .constant([]),
                showingCamera: .constant(false),
                gridColumnCount: .constant(3),
                selectedPhotoForDetail: .constant(nil),
                player: .constant(nil),
                showErrorAlert: .constant(false),
                errorMessage: .constant(""),
                status: .constant("")
            ),
            handlers: AlbumContentHandlers(
                onSavePhoto: { _, _ in },
                onDeletePhoto: { _ in }
            )
        )
    }
}

// MARK: - ViewModel Extensions
extension AlbumContentViewModel: AlbumSelectionHandler {
    func handleSelectedAlbum(_ collection: PHAssetCollection) {
        Task {
            do {
                status = "Importing photos..."
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                
                for i in 0..<assets.count {
                    let asset = assets[i]
                    if asset.mediaType == .image {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        options.isNetworkAccessAllowed = true
                        options.isSynchronous = false
                        
                        PHImageManager.default().requestImage(
                            for: asset,
                            targetSize: PHImageManagerMaximumSize,
                            contentMode: .aspectFit,
                            options: options
                        ) { [weak self] image, _ in
                            if let image = image {
                                self?.onSavePhoto(image, asset.creationDate ?? .now)
                            }
                        }
                    }
                    status = "Importing photos... \(i + 1)/\(assets.count)"
                }
                status = ""
                updateSortedPhotos()
            } catch {
                errorMessage = "Failed to import photos: \(error.localizedDescription)"
                showErrorAlert = true
                status = ""
            }
        }
    }
}
