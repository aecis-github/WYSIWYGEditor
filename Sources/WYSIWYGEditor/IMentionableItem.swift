//
//  NoteMentionItem.swift
//  Simple Notes
//
//  Created by Khoai Nguyen on 2/21/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import Foundation

public protocol IMentionableItem: AnyObject {
    var text: String { get }
    var symbol: String { get }
    var mentionableId: Int { get }
    var pickableText: String { get }
}

extension IMentionableItem {
    var symbol: String { "@" }
    var pickableText: String { "\(symbol)\(text)" }
}
