import SwiftUI
import SwiftData

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let photo: Photo
    
    var body: some View {
        NavigationStack {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .navigationTitle(photo.captureDate.formatted(date: .abbreviated, time: .shortened))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button(role: .destructive) {
                                    deletePhoto()
                                } label: {
                                    Label("Delete Photo", systemImage: "trash")
                                }
                                
                                ShareLink(item: image)
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
            }
        }
    }
    
    private func deletePhoto() {
        // Delete file from disk
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent(photo.imageFileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Remove from album
        if let albumIndex = photo.album?.photos.firstIndex(where: { $0.id == photo.id }) {
            photo.album?.photos.remove(at: albumIndex)
        }
        
        // Delete from SwiftData
        modelContext.delete(photo)
        dismiss()
    }
}