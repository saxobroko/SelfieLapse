//
//  ControlsView.swift
//  SelfieLapse
//
//  Created by Saxon on 18/2/2025.
//


import SwiftUI

struct ControlsView: View {
    let album: Album
    @Binding var gridColumnCount: Int
    @Binding var showingPhotosPicker: Bool
    @Binding var showingAlbumPicker: Bool
    @Binding var showingCamera: Bool
    @Binding var showingTimelapseSettings: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Grid Size", selection: $gridColumnCount) {
                Image(systemName: "square.grid.2x2").tag(2)
                Image(systemName: "square.grid.3x3").tag(3)
                Image(systemName: "rectangle.grid.3x2").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                Menu {
                    Button {
                        showingPhotosPicker = true
                    } label: {
                        Label("Select Photos", systemImage: "photo.on.rectangle")
                    }
                    
                    Button {
                        showingAlbumPicker = true
                    } label: {
                        Label("Import Album", systemImage: "rectangle.stack")
                    }
                } label: {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                        Text("Import")
                            .font(.caption)
                    }
                }
                
                Button {
                    showingCamera = true
                } label: {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                        Text("Capture")
                            .font(.caption)
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            
            if !album.photos.isEmpty {
                Button {
                    showingTimelapseSettings = true
                } label: {
                    Label("Create Timelapse", systemImage: "play.circle.fill")
                        .font(.title3)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 16)
        .background(Color.black)
    }
}