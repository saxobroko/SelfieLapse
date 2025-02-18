//
//  PhotoEntry.swift
//  SelfieLapse
//
//  Created by Saxon on 18/2/2025.
//


import SwiftData
import UIKit

@Model
class PhotoEntry {
    var captureDate: Date
    var imageFileName: String
    var tags: [String]
    var notes: String?
    
    // Computed property to load the actual image
    var image: UIImage? {
        get {
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            let fileURL = documentsDirectory.appendingPathComponent(imageFileName)
            return UIImage(contentsOfFile: fileURL.path)
        }
    }
    
    init(captureDate: Date = .now, imageFileName: String, tags: [String] = [], notes: String? = nil) {
        self.captureDate = captureDate
        self.imageFileName = imageFileName
        self.tags = tags
        self.notes = notes
    }
}