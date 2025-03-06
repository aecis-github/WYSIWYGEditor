//
//  UIFont+Styles.swift
//  Simple Notes
//
//  Created by Khoai Nguyen on 1/30/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import UIKit

extension UIFont {
    func byTogglingSymbolicTraits(_ symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        UIFont(
            descriptor: fontDescriptor.byTogglingSymbolicTraits(symbolicTraits),
            size: pointSize
        )
    }

    var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }

    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
}

extension UIFontDescriptor {
    func byTogglingSymbolicTraits(_ traints: UIFontDescriptor.SymbolicTraits) -> UIFontDescriptor {
        if !symbolicTraits.contains(traints) {
            return withSymbolicTraits(symbolicTraits.union(traints))!
        }
        return self
    }
}
