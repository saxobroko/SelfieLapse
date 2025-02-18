import SwiftUI
import SwiftData

@Model
final class Photo {
    var captureDate: Date
    var imageFileName: String
    var album: Album?
    
    init(captureDate: Date = .now, imageFileName: String) {
        self.captureDate = captureDate
        self.imageFileName = imageFileName
    }
    
    var image: UIImage? {
        get {
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            let fileURL = documentsDirectory.appendingPathComponent(imageFileName)
            return UIImage(contentsOfFile: fileURL.path)
        }
    }
    
    func saveImage(_ image: UIImage) throws {
        guard let data = image.jpegData(compressionQuality: 1.0),
              let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw PhotoError.saveFailed
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(imageFileName)
        try data.write(to: fileURL)
    }
    
    enum PhotoError: Error {
        case saveFailed
    }
}

@Model
final class Album {
    var name: String
    var createdDate: Date
    @Relationship(deleteRule: .cascade) var photos: [Photo]
    
    init(name: String, createdDate: Date = .now) {
        self.name = name
        self.createdDate = createdDate
        self.photos = []
    }
}
