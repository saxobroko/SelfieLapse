import SwiftUI

struct TimelapseSettingsView: View {
    @Binding var settings: TimelapseSettings
    @Environment(\.dismiss) private var dismiss
    var onStart: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Timelapse Type") {
                    Picker("Type", selection: $settings.timelapseType) {
                        Text("Traditional").tag(TimelapseSettings.TimelapseType.traditional)
                        Text("Morph").tag(TimelapseSettings.TimelapseType.morph)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Frame Rate") {
                    Slider(value: $settings.fps, in: 1...60, step: 1) {
                        Text("FPS: \(Int(settings.fps))")
                    } minimumValueLabel: {
                        Text("1")
                    } maximumValueLabel: {
                        Text("60")
                    }
                }
                
                Section("Quality") {
                    Picker("Export Quality", selection: $settings.exportQuality) {
                        Text("Low").tag(TimelapseSettings.VideoQuality.low)
                        Text("Medium").tag(TimelapseSettings.VideoQuality.medium)
                        Text("High").tag(TimelapseSettings.VideoQuality.high)
                    }
                    .pickerStyle(.segmented)
                }
                
                Toggle("Include Audio", isOn: $settings.includeAudio)
            }
            .navigationTitle("Timelapse Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        dismiss()
                        onStart()
                    }
                }
            }
        }
    }
}