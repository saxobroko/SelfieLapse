// Created by saxobroko
// Last updated: 2025-02-18 01:48:37 UTC

import SwiftUI
import Photos

struct AlbumListView: View {
    let onSelect: (PHAssetCollection) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var albums: [PHAssetCollection] = []
    
    var body: some View {
        NavigationView {
            List(albums, id: \.localIdentifier) { album in
                Button {
                    onSelect(album)
                    dismiss()
                } label: {
                    HStack {
                        Text(album.localizedTitle ?? "Untitled Album")
                        Spacer()
                        if let count = getPhotoCount(for: album) {
                            Text("\(count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAlbums()
        }
    }
    
    private func loadAlbums() {
        // Fetch user albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        
        // Fetch smart albums (like Camera Roll, Favorites, etc.)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        
        var allAlbums: [PHAssetCollection] = []
        
        // Process smart albums
        smartAlbums.enumerateObjects { album, _, _ in
            // Only add albums that contain photos
            if getPhotoCount(for: album) ?? 0 > 0 {
                allAlbums.append(album)
            }
        }
        
        // Process user albums
        userAlbums.enumerateObjects { album, _, _ in
            // Only add albums that contain photos
            if getPhotoCount(for: album) ?? 0 > 0 {
                allAlbums.append(album)
            }
        }
        
        albums = allAlbums
    }
    
    private func getPhotoCount(for collection: PHAssetCollection) -> Int? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        return result.count
    }
}