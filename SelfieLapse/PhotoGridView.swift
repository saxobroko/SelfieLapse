import SwiftUI

struct PhotoGridView: View {
    let photos: [Photo]
    let gridColumns: [GridItem]
    let onPhotoSelected: (Photo) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 1) {
                ForEach(photos) { photo in
                    if let image = photo.image {
                        Button {
                            onPhotoSelected(photo)
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }
}