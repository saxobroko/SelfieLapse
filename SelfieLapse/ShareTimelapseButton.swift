// Created by saxobroko
// Last updated: 2025-02-18 00:38:51 UTC

import SwiftUI

struct ShareTimelapseButton: View {
    let url: URL
    @Binding var showingProgress: Bool
    @Binding var errorMessage: String
    @Binding var showErrorAlert: Bool
    
    var body: some View {
        Button {
            showingProgress = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                
                do {
                    try? FileManager.default.removeItem(at: tempURL)
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let rootViewController = windowScene.windows.first?.rootViewController else {
                        return
                    }
                    
                    let activityVC = UIActivityViewController(
                        activityItems: [tempURL],
                        applicationActivities: nil
                    )
                    
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        if let window = windowScene.windows.first {
                            activityVC.popoverPresentationController?.sourceView = window
                            activityVC.popoverPresentationController?.sourceRect = CGRect(
                                x: window.bounds.midX,
                                y: window.bounds.midY,
                                width: 0,
                                height: 0
                            )
                            activityVC.popoverPresentationController?.permittedArrowDirections = []
                        }
                    }
                    
                    activityVC.completionWithItemsHandler = { _, _, _, _ in
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                    
                    rootViewController.present(activityVC, animated: true)
                } catch {
                    errorMessage = "Error preparing file for sharing: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        } label: {
            Label("Share Timelapse", systemImage: "square.and.arrow.up")
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
}