//
//  UITextView+Positions.swift
//  Simple Notes
//
//  Created by Khoai Nguyen on 2/20/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import UIKit

extension UITextView {
    var rangeBeforeCursor: UITextRange? {
        if let cursorRange = selectedTextRange {
            // get the position one character before the cursor start position
            if let newPosition = position(from: cursorRange.start, offset: -1) {
                return textRange(from: newPosition, to: cursorRange.start)
            }
        }
        return nil
    }

    var nsRangeBeforeCursor: NSRange? {
        guard let range = rangeBeforeCursor else { return nil }
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = offset(from: range.start, to: range.end)
        return NSRange(location: location, length: length)
    }
}
