//
//  NSAttributedString+HTML.swift
//  Simple Notes
//
//  Created by Khoai Nguyen on 2/21/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import SwiftSoup
import UIKit

extension String {
    mutating func replacing(pattern: String, with: String = "") -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
            let range = NSRange(startIndex..., in: self)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: with)
        } catch { }
        return self
    }
}

struct ParsableListItem {
    var item: ListItem? = nil
    var lines: [String] = []

    private func canAddItem(_ newItem: ListItem?) -> Bool {
        guard let newItem = newItem else { return false }
        return (item != nil && item!.beginGroupTag == newItem.beginGroupTag)
    }

    @discardableResult
    mutating func addLine(_ line: String, forItem item: ListItem? = nil) -> Bool {
        if canAddItem(item) {
            lines.append(line)
            return true
        }
        return false
    }

    fileprivate func toHTMLString(brTagAdded: Bool = true) -> String {
        var content = lines.joined()
        content = content.replacing(pattern: "\\n(?=(<.+?>)*$)", with: "")
        content = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "<br>")

        if item != nil {
            return "\(item!.beginGroupTag)\(content)\(item!.endGroupTag)"
        }

        if brTagAdded {
            return "\(content)<br>"
        }
        return content
    }

    fileprivate func toAttributedString() -> NSAttributedString {
        return .init(string: "")
    }
}

extension Array where Element == ParsableListItem {
    fileprivate func toHTMLString() -> String {
        var result = ""
        let length = count
        for i in 0 ..< length {
            if i == length - 1 {
                result += self[i].toHTMLString(brTagAdded: false)
            } else {
                result += self[i].toHTMLString()
            }
        }
        return result
    }

    @discardableResult
    fileprivate mutating func addLine(_ line: String, forItem item: ListItem? = nil) -> Bool {
        var lastItem = last

        /// try to add last item, otherwise add new group
        if lastItem == nil || !lastItem!.addLine(line, forItem: item) {
            append(ParsableListItem(item: item, lines: [line]))
            return false
        } else {
            self[count - 1] = lastItem!
            return true
        }
    }
}

extension NSParagraphStyle {
    fileprivate func getListItem() -> ListItem? {
        var result: ListItem?

        if let list = textLists.first {
            var level: Int = 0
            if let tab = tabStops.first {
                level = Int(tab.location / defaultTabInterval) + 1
            }

            /// bullet
            switch list.markerFormat {
            case .disc: result = ListItem.bullet(level: level)
            case .decimal: result = ListItem.bullet(level: level)
            default: break
            }
        }

        return result
    }
}

extension NSAttributedString {
    private func getListItem(inRange: NSRange) -> (ListItem?, NSRange) {
        var listItem: ListItem?

        var lastRange: NSRange = .init()
        enumerateAttribute(.list, in: inRange) { item, range, stop in
            guard lastRange != range else { return }
            lastRange = range

            let value = item as? String ?? ""
            listItem = ListItem(rawValue: value)

            if listItem != nil {
                stop.pointee = ObjCBool(true)
            }
        }

        return (listItem, lastRange)
    }

    public func getStyleAtSelectedRange(_ range: NSRange, font: UIFont) -> TextFormat? {
        var textFormatTypes: [TextFormatItemType] = []
        var listFormatTypes: [ListFormatItemType] = []
        var paragraphFormatTypes: [ParagraphFormatItemType] = []

        enumerateAttributes(in: range) { attrs, _, _ in
            if let _font = attrs[.font] as? UIFont {
                if _font.isBold {
                    textFormatTypes.append(.bold)
                }

                if _font.isItalic {
                    textFormatTypes.append(.italic)
                }
            }

            /// underline
            if let _ = attrs[.underlineStyle] {
                textFormatTypes.append(.underline)
            }

            /// strikethrough
            if let _ = attrs[.strikethroughStyle] {
                textFormatTypes.append(.strikethrough)
            }
        }

        let lineRange = lineRange(for: range.location)
        let (style, _) = getListItem(inRange: lineRange)
        if let style = style {
            switch style {
            case .bullet: listFormatTypes.append(.bullet)
            case .ordered: listFormatTypes.append(.order)
            default: break
            }
        }

        var result = TextFormat(
            styles: textFormatTypes,
            listStyles: listFormatTypes,
            paragraphStyles: paragraphFormatTypes
        )
        result.font = font

        return result
    }

    public func getMentionableItems() -> [IMentionableItem] {
        var result: [IMentionableItem] = []
        enumerateAttribute(.mention, in: range) { item, _, _ in
            if let item = item as? IMentionableItem {
                result.append(item)
            }
        }
        return result
    }

    public var standadizedHTML: String {
        var parsableItems: [ParsableListItem] = []

        var currentLine: String = ""
        var currentListItem: ListItem?

        var partsForRange: [NSRange: String] = [:]
        var lastRange: NSRange = .init()

        enumerateAttributes(in: range, options: .init(rawValue: 0)) { [weak self] attrs, range, _ in
            guard let `self` = self else { return }

            var stringInRange = partsForRange[range] ?? ""
            if stringInRange.isEmpty {
                stringInRange = self.string.string(inRange: range)
            }

            /// text style
            if let font = attrs[.font] as? UIFont {
                /// bold
                if font.isBold {
                    stringInRange = "<b>\(stringInRange)</b>"
                }

                /// italic
                if font.isItalic {
                    stringInRange = "<i>\(stringInRange)</i>"
                }
            }

            /// underline
            if let _ = attrs[.underlineStyle] {
                stringInRange = "<u>\(stringInRange)</u>"
            }

            /// strikethrough
            if let _ = attrs[.strikethroughStyle] {
                stringInRange = "<del>\(stringInRange)</del>"
            }

            if lastRange != range {
                lastRange = range

                /// mention
                if let item = attrs[.mention] as? IMentionableItem {
                    stringInRange = "<span data-id=\"\(item.mentionableId)\" class=\"mention\">\(stringInRange)</span>"
                }

                /// get list item
                /// convert list item
                let (listItem, listItemRange) = self.getListItem(inRange: range)

                /// add begin
                if listItem != nil {
                    let removableSymbol = self.string.string(inRange: listItemRange)
                    stringInRange = stringInRange.replacingOccurrences(of: "\(removableSymbol)", with: "")
                    if !currentLine.contains("<li>") {
                        currentListItem = listItem
                        stringInRange = "<li>\(stringInRange)"
                    }
                }

                if stringInRange.contains("\n") {
                    /// check end of line
                    if currentLine.contains("<li>") {
                        stringInRange = stringInRange.replacingOccurrences(of: "\n", with: "")

                        /// if it's bullet / number, then add end li tag
                        stringInRange = "\(stringInRange)</li>"
                    }

                    currentLine += stringInRange
                    parsableItems.addLine(currentLine, forItem: currentListItem)

                    currentListItem = nil
                    currentLine = ""
                } else {
                    currentLine += stringInRange
                }
            }

            partsForRange[range] = stringInRange
        }

        if !currentLine.isEmpty {
            if currentLine.hasPrefix("<li>") && !currentLine.hasSuffix("</li>") {
                currentLine = "\(currentLine)</li>"
            }
            parsableItems.addLine(currentLine, forItem: currentListItem)
        }

        return parsableItems.toHTMLString()
    }

    fileprivate func convertToWYSIWYGAttributedString(
        font: UIFont,
        mentionableItems: [IMentionableItem]
    ) -> NSAttributedString? {
        var partsForRange: [NSRange: NSMutableAttributedString] = [:]
        var lastRange: NSRange = .init()

        enumerateAttributes(in: range, options: .init(rawValue: 0)) { [weak self] attrs, range, _ in
            guard let `self` = self else { return }

            var attributedString = partsForRange[range]
            if attributedString == nil {
                let value = self.string.string(inRange: range)
                attributedString = NSMutableAttributedString(string: value)
            }

            let partRange = NSMakeRange(0, attributedString?.length ?? 0)
            var (textFont, _) = (attributedString?.attribute(.font, in: partRange).first as? (UIFont, NSRange)) ?? (font, partRange)

            /// text style
            if let _font = attrs[.font] as? UIFont {
                textFont = textFont.withSize(font.pointSize)

                /// bold
                if _font.isBold {
                    textFont = textFont.byTogglingSymbolicTraits(.traitBold)
                    attributedString?.updateAttribute(.bold, value: true, range: partRange)
                }

                /// italic
                if _font.isItalic {
                    textFont = textFont.byTogglingSymbolicTraits(.traitItalic)
                    attributedString?.updateAttribute(.italic, value: true, range: partRange)
                }
            }

            /// underline
            if let _ = attrs[.underlineStyle] {
                attributedString?.updateAttribute(.underline, value: true, range: partRange)
                attributedString?.updateAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: partRange)
                attributedString?.updateAttribute(.underlineColor, value: UIColor.black, range: partRange)
            }

            /// strikethrough
            if let _ = attrs[.strikethroughStyle] {
                attributedString?.updateAttribute(.strikethrough, value: true, range: partRange)
                attributedString?.updateAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                attributedString?.updateAttribute(.strikethroughColor, value: UIColor.black, range: partRange)
            }

            /// background & foreground
            if let backgroundColor = attrs[.backgroundColor] {
                attributedString?.updateAttribute(.backgroundColor, value: backgroundColor, range: partRange)
            }

            if let foregroundColor = attrs[.foregroundColor] {
                attributedString?.updateAttribute(.foregroundColor, value: foregroundColor, range: partRange)
            }

            if lastRange != partRange {
                lastRange = partRange
            }

            attributedString?.updateAttribute(.font, value: textFont, range: partRange)
            partsForRange[range] = attributedString
        }

        /// concat all attributed strings
        let result = NSMutableAttributedString()
        let keys = partsForRange.keys.sorted(by: { $0.location < $1.location })
        for key in keys {
            if let value = partsForRange[key] {
                result.append(value)
            }
        }

        /// highlighted mention
        if !mentionableItems.isEmpty {
            let pattern = "(\(mentionableItems.compactMap { $0.pickableText }.joined(separator: "|")))"
            let matches = result.string.regex(pattern: pattern)

            var attrs = FormatStyle.shared.mentionFormat.style
            attrs[.font] = font

            for i in 0 ..< matches.count {
                let match = matches[i]
                attrs[.mention] = mentionableItems[0]
                result.setAttributes(attrs, range: match.range)
            }
        }
        return result
    }
}

extension NSAttributedString {
    var html: String? {
        do {
            let htmlData = try data(
                from: NSRange(location: 0, length: length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            )
            return String(data: htmlData, encoding: String.Encoding.utf8)
        } catch {
            debugPrint("error:", error)
            return nil
        }
    }
}

extension String {
    private var attributedString: NSAttributedString? {
        guard let data = data(using: .utf16, allowLossyConversion: false) else { return nil }
        guard let html = try? NSMutableAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil) else { return nil }
        return html
    }

    fileprivate func parseMentionableIDs() -> [Int] {
        /// <span contenteditable=\"false\" data-id=\"3139\" class=\"mention fr-deletable\">
        var result: [Int] = []
        do {
            let doc: Document = try SwiftSoup.parse(self)
            let elements: Elements = try doc.select("span")
            for element in elements {
                let id = try element.attr("data-id")
                if let value = Int(id) {
                    result.append(value)
                }
            }
        } catch let Exception.Error(_, message) {
            debugPrint(message)
        } catch {
            debugPrint("error")
        }
        return result
    }

    public func toWYSIWYGAttributedString(
        font: UIFont,
        mentionableItems: (Array<Int>) -> [IMentionableItem]
    ) -> NSAttributedString? {
        /// replace \n to <br>
        var trimmedString = replacingOccurrences(of: "\n", with: "<br>")

        /// convert html to attributed string
        let ids = parseMentionableIDs()
        return trimmedString.attributedString?.convertToWYSIWYGAttributedString(
            font: font,
            mentionableItems: mentionableItems(ids)
        )
    }
}
