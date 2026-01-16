//
//  Item.swift
//  Acta
//
//  Created by Cameron Shemilt on 16.01.26.
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
