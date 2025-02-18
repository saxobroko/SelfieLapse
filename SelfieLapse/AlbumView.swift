import SwiftUI
import SwiftData

struct AlbumView: View {
    @Environment(\.modelContext) private var modelContext
    let album: Album
    @StateObject private var cameraManager = CameraManager()
    @State private var showingCamera = false
    @State private var selectedPhoto: Photo?
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 2)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(album.photos) { photo in
                    if let image = photo.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                    }
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(action: { showingCamera = true }) {
                Image(systemName: "camera")
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(cameraManager: cameraManager) { image in
                if let image = image {
                    savePhoto(image)
                }
                showingCamera = false
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
    }
    
    private func savePhoto(_ image: UIImage) {
        let fileName = "\(UUID().uuidString).jpg"
        if let data = image.jpegData(compressionQuality: 0.8) {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            try? data.write(to: fileURL)
            
            let photo = Photo(imageFileName: fileName)
            album.photos.append(photo)
        }
    }
}