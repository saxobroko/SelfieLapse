import Foundation
import UIKit

class StorageManager {
    static let shared = StorageManager()
    private let fileManager = FileManager.default
    
    private init() {}
    
    func saveImage(_ image: UIImage, withName name: String) throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.compressionFailed
        }
        
        let documentsDirectory = try getDocumentsDirectory()
        let filename = documentsDirectory.appendingPathComponent("\(name).jpg")
        
        try data.write(to: filename)
    }
    
    func loadImage(named name: String) throws -> UIImage {
        let documentsDirectory = try getDocumentsDirectory()
        let filename = documentsDirectory.appendingPathComponent("\(name).jpg")
        
        guard let image = UIImage(contentsOfFile: filename.path) else {
            throw StorageError.loadFailed
        }
        
        return image
    }
    
    private func getDocumentsDirectory() throws -> URL {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory,
                                                      in: .userDomainMask).first else {
            throw StorageError.directoryNotFound
        }
        return documentsDirectory
    }
    
    enum StorageError: Error {
        case compressionFailed
        case loadFailed
        case directoryNotFound
    }
}