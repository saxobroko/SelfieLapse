//
//  TimelapseProgressView.swift
//  SelfieLapse
//
//  Created by Saxon on 18/2/2025.
//


import SwiftUI
import AVKit

struct TimelapseProgressView: View {
    let progress: Double
    let status: String
    let exportURL: URL?
    @Binding var player: AVPlayer?
    @Binding var showingProgress: Bool
    @Binding var errorMessage: String
    @Binding var showErrorAlert: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if progress < 1.0 {
                    ProgressView(status, value: progress, total: 1.0)
                        .padding()
                } else if let url = exportURL {
                    VStack(spacing: 16) {
                        VideoPlayer(player: player)
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .cornerRadius(12)
                            .padding()
                            .onAppear {
                                player?.play()
                            }
                            .onDisappear {
                                player?.pause()
                            }
                        
                        Button {
                            player?.seek(to: .zero)
                            player?.play()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title2)
                        }
                        .foregroundColor(.white)
                        .padding(.bottom)
                        
                        ShareTimelapseButton(
                            url: url,
                            showingProgress: $showingProgress,
                            errorMessage: $errorMessage,
                            showErrorAlert: $showErrorAlert
                        )
                    }
                }
            }
            .navigationTitle("Timelapse Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        player?.pause()
                        player = nil
                        showingProgress = false
                    }
                }
            }
        }
    }
}