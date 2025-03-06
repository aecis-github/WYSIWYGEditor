//
//  File.swift
//
//
//  Created by Khoai Nguyen on 3/17/24.
//

import Foundation

public extension IMentionableItem {
    public func toHTMLSpanString() -> String {
        "<span data-id=\"\(mentionableId)\" class=\"mention\">\(pickableText)</span>"
    }
}
