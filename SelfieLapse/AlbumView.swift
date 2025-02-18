// AlbumView.swift
// Created by saxobroko
// Last updated: 2025-02-18 03:22:18 UTC

import SwiftUI
import PhotosUI
import AVKit

struct AlbumView: View {
    let album: Album
    @StateObject private var timelapseGenerator = TimelapseGenerator()
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingTimelapseSettings = false
    @State private var timelapseSettings = TimelapseSettings()
    @State private var showingTimelapseProgress = false
    @State private var exportURL: URL?
    @State private var showingPhotosPicker = false
    @State private var showingAlbumPicker = false
    @State private var selectedPhotos = [PhotosPickerItem]()
    @State private var showingCamera = false
    @State private var gridColumnCount = 3
    @State private var selectedPhotoForDetail: Photo?
    @State private var player: AVPlayer?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var status = ""
    
    var body: some View {
        AlbumContentView(
            album: album,
            timelapseGenerator: timelapseGenerator,
            cameraManager: cameraManager,
            bindings: AlbumContentBindings(
                showingTimelapseSettings: $showingTimelapseSettings,
                timelapseSettings: $timelapseSettings,
                showingTimelapseProgress: $showingTimelapseProgress,
                exportURL: $exportURL,
                showingPhotosPicker: $showingPhotosPicker,
                showingAlbumPicker: $showingAlbumPicker,
                selectedPhotos: $selectedPhotos,
                showingCamera: $showingCamera,
                gridColumnCount: $gridColumnCount,
                selectedPhotoForDetail: $selectedPhotoForDetail,
                player: $player,
                showErrorAlert: $showErrorAlert,
                errorMessage: $errorMessage,
                status: $status
            ),
            handlers: AlbumContentHandlers(
                onSavePhoto: { image, date in
                    do {
                        let data = image.jpegData(compressionQuality: 1.0) ?? Data()
                        let fileName = UUID().uuidString + ".jpg"
                        let photo = Photo(data: data, fileName: fileName)
                        album.photos.append(photo)
                        modelContext.insert(photo)
                        try modelContext.save()
                    } catch {
                        errorMessage = "Failed to save photo: \(error.localizedDescription)"
                        showErrorAlert = true
                    }
                },
                onDeletePhoto: { photo in
                    do {
                        if let index = album.photos.firstIndex(where: { $0.id == photo.id }) {
                            album.photos.remove(at: index)
                        }
                        modelContext.delete(photo)
                        try modelContext.save()
                    } catch {
                        errorMessage = "Failed to delete photo: \(error.localizedDescription)"
                        showErrorAlert = true
                    }
                }
            )
        )
    }
}

#Preview {
    AlbumView(album: Album(name: "Preview Album"))
        .modelContainer(for: [Album.self, Photo.self])
}
