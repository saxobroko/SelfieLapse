//
//  LoadingOverlay.swift
//  SelfieLapse
//
//  Created by Saxon on 18/2/2025.
//


import SwiftUI

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                if let progress = extractProgress(from: message) {
                    ProgressView(message, value: Double(progress.current), total: Double(progress.total))
                        .progressViewStyle(.linear)
                        .tint(.white)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
                Text(message)
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(24)
            .frame(maxWidth: 300)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private func extractProgress(from message: String) -> (current: Int, total: Int)? {
        let pattern = #"(\d+)/(\d+)"#
        if let match = message.range(of: pattern, options: .regularExpression) {
            let numbers = message[match].split(separator: "/")
            if numbers.count == 2,
               let current = Int(numbers[0]),
               let total = Int(numbers[1]) {
                return (current, total)
            }
        }
        return nil
    }
}