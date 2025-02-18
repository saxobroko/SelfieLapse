import SwiftUI

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: Photo
    let onDelete: (Photo) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingDeleteAlert = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if let image = photo.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = scale * delta
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            if scale < 1.0 {
                                                withAnimation {
                                                    scale = 1.0
                                                }
                                            }
                                            if scale > 5.0 {
                                                withAnimation {
                                                    scale = 5.0
                                                }
                                            }
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            let delta = CGSize(
                                                width: value.translation.width - lastOffset.width,
                                                height: value.translation.height - lastOffset.height
                                            )
                                            lastOffset = value.translation
                                            offset = CGSize(
                                                width: offset.width + delta.width,
                                                height: offset.height + delta.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = .zero
                                            // Reset position if scale is 1
                                            if scale <= 1.0 {
                                                withAnimation {
                                                    offset = .zero
                                                }
                                            }
                                        }
                                )
                            )
                            .gesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        withAnimation {
                                            if scale > 1.0 {
                                                scale = 1.0
                                                offset = .zero
                                            } else {
                                                scale = 2.0
                                            }
                                        }
                                    }
                            )
                    }
                    
                    // Photo info overlay
                    VStack {
                        Spacer()
                        Text(dateFormatter.string(from: photo.captureDate ?? .now))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .alert("Delete Photo", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete(photo)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this photo? This action cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    let previewPhoto = Photo(imageFileName: "preview")
    previewPhoto.captureDate = .now
    
    return PhotoDetailView(
        photo: previewPhoto,
        onDelete: { _ in }
    )
}
