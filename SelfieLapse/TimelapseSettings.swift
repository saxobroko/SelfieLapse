import SwiftUI
import AVFoundation

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
            case .low:
                return AVAssetExportPreset960x540
            case .medium:
                return AVAssetExportPreset1920x1080
            case .high:
                return AVAssetExportPreset3840x2160
            }
        }
        
        var description: String {
            switch self {
            case .low: return "540p"
            case .medium: return "1080p"
            case .high: return "4K"
            }
        }
    }
}
