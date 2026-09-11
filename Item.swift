//
//  Item.swift
//  wingmark
//
//  Created by Bilgesu Çakır on 12.09.2026.
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
