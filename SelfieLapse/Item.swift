//
//  Item.swift
//  SelfieLapse
//
//  Created by Saxon on 18/2/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
