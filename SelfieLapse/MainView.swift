import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var albums: [Album]
    @State private var showingNewAlbumSheet = false
    @State private var newAlbumName = ""
    
    var body: some View {
        NavigationStack {
            List {
                if albums.isEmpty {
                    ContentUnavailableView("No Albums", 
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Create your first album to start capturing memories"))
                } else {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumView(album: album)) {
                            AlbumRow(album: album)
                        }
                    }
                    .onDelete(perform: deleteAlbums)
                }
            }
            .navigationTitle("My Timelapses")
            .toolbar {
                Button(action: { showingNewAlbumSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingNewAlbumSheet) {
                NavigationStack {
                    Form {
                        TextField("Album Name", text: $newAlbumName)
                    }
                    .navigationTitle("New Album")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingNewAlbumSheet = false
                                newAlbumName = ""
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                createAlbum()
                            }
                            .disabled(newAlbumName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.height(200)])
            }
        }
    }
    
    private func createAlbum() {
        let album = Album(name: newAlbumName)
        modelContext.insert(album)
        showingNewAlbumSheet = false
        newAlbumName = ""
    }
    
    private func deleteAlbums(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(albums[index])
        }
    }
}

struct AlbumRow: View {
    let album: Album
    
    var body: some View {
        HStack {
            if let lastPhoto = album.photos.last?.image {
                Image(uiImage: lastPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
            }
            
            VStack(alignment: .leading) {
                Text(album.name)
                    .font(.headline)
                Text("\(album.photos.count) photos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}