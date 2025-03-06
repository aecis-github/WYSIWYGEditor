//
//  UIImage+SFSymbols.swift
//  Simple Notes
//
//  Created by Khoai Nguyen on 1/30/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import UIKit

public enum GeneralItemType: Int, CustomStringConvertible {
    case textFormat
    case hideKeyboard

    public var description: String {
        switch self {
        case .textFormat: return "textformat"
        case .hideKeyboard: return "keyboard.chevron.compact.down"
        }
    }
}

public enum TextFormatItemType: Int, CustomStringConvertible {
    case bold
    case italic
    case underline
    case strikethrough
    
    case mention
    case hasTag

    public var description: String {
        switch self {
        case .bold: return "bold"
        case .italic: return "italic"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .mention: return "mention"
        case .hasTag: return "hastag"
        }
    }
}

public enum ListFormatItemType: Int, CustomStringConvertible {
    case dash
    case bullet
    case order

    public var description: String {
        switch self {
        case .dash: return "list.dash"
        case .bullet: return "list.bullet"
        case .order: return "list.number"
        }
    }
}

public enum ParagraphFormatItemType: Int, CustomStringConvertible {
    case increase
    case descrease

    public var description: String {
        switch self {
        case .increase: return "increase.indent"
        case .descrease: return "decrease.indent"
        }
    }
}

extension String {
    func systemSymbolImage(
        pointSize: CGFloat,
        weight: UIImage.SymbolWeight
    ) -> UIImage? {
        let config = UIImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: weight,
            scale: .default
        )
        return UIImage(systemName: self, withConfiguration: config)
    }
}

extension TextFormatItemType {
    public func toImage(pointSize: CGFloat = 28, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        description.systemSymbolImage(pointSize: pointSize, weight: weight)
    }
}

extension ListFormatItemType {
    public func toImage(pointSize: CGFloat = 28, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        description.systemSymbolImage(pointSize: pointSize, weight: weight)
    }
}

extension ParagraphFormatItemType {
    public func toImage(pointSize: CGFloat = 28, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        description.systemSymbolImage(pointSize: pointSize, weight: weight)
    }
}

extension GeneralItemType {
    public func toImage(pointSize: CGFloat = 28, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        description.systemSymbolImage(pointSize: pointSize, weight: weight)
    }
}
