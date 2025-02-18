import SwiftUI

struct TimelapseSettings {
    var fps: Double = 30
    var timelapseType: TimelapseType = .traditional
    var includeAudio: Bool = false
    var exportQuality: VideoQuality = .high
    
    enum TimelapseType {
        case traditional
        case morph
    }
    
    enum VideoQuality {
        case low
        case medium
        case high
        
        var preset: String {
            switch self {
            case .low: return AVAssetExportPresetMediumQuality
            case .medium: return AVAssetExportPresetHighestQuality
            case .high: return AVAssetExportPresetHEVCHighestQuality
            }
        }
    }
}