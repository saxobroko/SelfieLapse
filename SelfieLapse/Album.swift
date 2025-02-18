import SwiftData
import SwiftUI

@Model
class Album {
    var name: String
    var createdDate: Date
    var photos: [Photo]
    
    init(name: String, createdDate: Date = .now) {
        self.name = name
        self.createdDate = createdDate
        self.photos = []
    }
}

@Model
class Photo {
    var captureDate: Date
    var imageFileName: String
    var album: Album?
    
    var image: UIImage? {
        get {
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            let fileURL = documentsDirectory.appendingPathComponent(imageFileName)
            return UIImage(contentsOfFile: fileURL.path)
        }
    }
    
    init(captureDate: Date = .now, imageFileName: String) {
        self.captureDate = captureDate
        self.imageFileName = imageFileName
    }
}