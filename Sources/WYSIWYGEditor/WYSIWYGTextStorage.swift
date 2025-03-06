//
//  NoteTextStorage.swift
//  Simple Notes
//
//  Created by Paulo Mattos on 12/03/19.
//  Copyright © 2019 Paulo Mattos. All rights reserved.
//

import UIKit

/// Stores a given note text with rich formatting.
/// This implements the core text formatting engine.
public final class WYSIWYGTextStorage: NSTextStorage {
    fileprivate let backingStore = NSMutableAttributedString()
    fileprivate var backingString: NSString { return backingStore.string as NSString }

    /// isInMentionProcess
    public var isInMentionProcess: Bool = false

    /// Search String
    public var searchString: String! = ""

    /// Selected Symbol
    public var selectedSymbol: String! = ""

    /// Selected Symbol Location
    public var selectedSymbolLocation: Int!

    // MARK: - Storage Initialization

    override public init() {
        super.init()
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        wordsFormatter.storage = self
        listsFormatter.storage = self
        editingStyle = [.font: bodyFont]
    }

    // MARK: - NSTextStorage Subclassing Requirements

    /// The character contents of the storage as an `NSString` object.
    override public var string: String {
        return backingStore.string
    }

    /// Returns the attributes for the character at a given index.
    override public func attributes(
        at location: Int,
        effectiveRange range: NSRangePointer?)
        -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    /// Replaces the characters in the given range
    /// with the characters of the specified string.
    override public func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(
            .editedCharacters,
            range: range,
            changeInLength: str.utf16.count - range.length
        )
        endEditing()
    }

    /// Sets the attributes for the characters in
    /// the specified range to the specified attributes.
    override public func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    public func updateAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange) {
        guard !attrs.isEmpty else { return }

        let ignoredKeys: [NSAttributedString.Key] = [
            .underline,
            .underlineStyle,
            .underlineColor,
            .strikethrough,
            .strikethroughColor,
            .strikethroughStyle,
        ]

        enumerateAttributes(in: range) { [weak self] partAttrs, partRange, _ in
            var updateAttrs: [NSAttributedString.Key: Any] = [:]
            if !partAttrs.keys.contains(.list) {
                for key in partAttrs.keys {
                    if !ignoredKeys.contains(key) {
                        updateAttrs[key] = partAttrs[key]
                    }
                }

                attrs.keys.forEach {
                    updateAttrs[$0] = attrs[$0]
                }
            } else {
                updateAttrs = partAttrs
            }
            self?.setAttributes(updateAttrs, range: partRange)
        }
    }

    // MARK: - Rich Text Formatting

    public var bodyFont = UIFont.systemFont(ofSize: 18)
    public var editingStyle: [NSAttributedString.Key: Any] = [:]

    private let wordsFormatter = WordsFormatter()
    private let listsFormatter = ListsFormatter()

    private func performRichFormatting(
        in editedRange: NSRange,
        with editedMask: EditActions
    ) -> FormattedText? {
        let lineRange = backingStore.lineRange(for: editedRange.location)
        let editedLineRange = NSUnionRange(editedRange, lineRange)
        let editedString = backingString.substring(with: editedRange)

        /*
         let maxLineRange = backingString.lineRange(
             for: NSMakeRange(editedRange.upperBound, 0))
         editedLineRange = NSUnionRange(editedRange, maxLineRange)
         */

        let changedText = ChangedText(
            contents: editedString,
            mask: editedMask,
            range: editedRange,
            lineRange: editedLineRange,
            listItem: listsFormatter.listItem(at: editedLineRange)
        )

        let formatters = [listsFormatter.formatLists, wordsFormatter.formatWords]
        for format in formatters {
            if let formattedText = format(changedText) {
                return formattedText
            }
        }
        setAttributes(editingStyle, range: changedText.range)
        return nil
    }

    private var lastEditedRange: NSRange?
    private var lastEditedMask: NSTextStorage.EditActions?

    func processRichFormatting() -> FormattedText? {
        if let lastEditedRange = lastEditedRange,
           let lastEditedMask = lastEditedMask {
            return performRichFormatting(in: lastEditedRange, with: lastEditedMask)
        }
        return nil
    }

    @discardableResult
    func handleBeforeTextChanged(selectedRange: NSRange, isBack: Bool) -> FormattedText? {
        guard isBack else { return nil }

        var listRange = NSMakeRange(0, 0)
        if let item = listsFormatter.listItem(at: selectedRange, effectiveRange: &listRange) {
            let lineRange = lineRange(for: selectedRange.location)
            let editLocation = selectedRange.location

            let startOfItemLocation = lineRange.location
            let endOfItemLocation = lineRange.location + item.itemMarker.count

            if editLocation >= startOfItemLocation && editLocation <= endOfItemLocation {
                return listsFormatter.formatEmptyListItem(
                    for: .init(
                        contents: "",
                        mask: .editedCharacters,
                        range: selectedRange,
                        lineRange: lineRange,
                        listItem: item
                    )
                )
            }
        }
        return nil
    }

    override public func processEditing() {
        lastEditedRange = editedRange
        lastEditedMask = editedMask
        super.processEditing()
    }

    // MARK: - Checkmarks Support

    func insertCheckmark(at index: Int, withValue value: Bool = false) {
        listsFormatter.insertListItem(.checkmark(value), at: index)
    }

    func setCheckmark(atLine lineRange: NSRange, to value: Bool) {
        listsFormatter.updateListItem(.checkmark(value), atLine: lineRange)
    }

    // MARK: - Note IO

    /// Loads the specified Markdown-ish formatted note.
    func load(note: String) {
        var noteString = NSAttributedString(string: note, attributes: editingStyle)

        let formatters = [wordsFormatter.format, listsFormatter.format]
        for format in formatters {
            noteString = format(noteString)
        }
        setAttributedString(noteString)
    }

    func getLineString(at range: NSRange) -> String {
        let lineRange = lineRange(for: range.location)
        return string.string(inRange: lineRange)
    }

    /// Returns a Markdown-ish formatted note with this text contents.
    func deformatted() -> String {
        var markdownString = NSAttributedString(attributedString: self)

        let deformatters = [wordsFormatter.deformat, listsFormatter.deformat]
        for deformat in deformatters {
            markdownString = deformat(markdownString)
        }
        return markdownString.string
    }
}

/// List + helpers

extension WYSIWYGTextStorage {
    func reformatFollowingOrderedItems(at: Int, reversed: Bool = false) {
        guard at > 0 && at < range.max else { return }

        let lineRange = lineRange(for: at)
        var item = listsFormatter.listItem(at: lineRange)

        if reversed {
            item = nil
        } else {
            if case .ordered = item {}
            else { item = nil }
        }

        if item != nil || reversed {
            listsFormatter.reformatFollowingOrderedItems(
                item,
                at: lineRange.location
            )
        }
    }

    private func _addOrReplaceLisItem(_ item: ListItem, range: NSRange) -> NSRange? {
        var result: NSRange?
        if let removedListItemRange = listsFormatter.replaceListItem(item, atLine: range) {
            var newPos = range.location - removedListItemRange.length
            if newPos < 0 { newPos = 0 }
            result = NSMakeRange(newPos, range.length)
        } else {
            let insertedListItemRange = listsFormatter.insertListItem(item, at: range.location)
            result = NSMakeRange(range.location + insertedListItemRange.length, range.length)
        }
        return result
    }

    public func addOrReplaceListItem(_ item: ListItem, selectedRange: NSRange) -> NSRange? {
        var result: NSRange?

        /// update previous list format
        var newItem: ListItem
        if case let .ordered = item {
            let previousItem = listsFormatter.getPreviousOrderListItem(at: selectedRange.location)
            newItem = previousItem?.nextItem ?? item
        } else {
            newItem = item
        }

        /// calculate number of lines
        var numberOfLines: Int = 0

        if selectedRange.length > 0 {
            enumerateLines(inRange: selectedRange, { _, _ in
                numberOfLines += 1
            })
        } else {
            numberOfLines = 1
        }

        debugPrint("numberOfLines >>> \(numberOfLines)")

        var nextRange: NSRange? = selectedRange
        for i in 0 ..< numberOfLines {
            if nextRange != nil, let partRange = _addOrReplaceLisItem(newItem, range: nextRange!) {
                debugPrint("Inscreased Length >>> \(partRange)")
                let nextIndex = lineRange(for: partRange.location).max

                if nextIndex < string.length {
                    nextRange = NSMakeRange(nextIndex, 0)
                    newItem = newItem.nextItem
                } else {
                    nextRange = nil
                }

                if result == nil {
                    result = partRange
                }
            } else {
                nextRange = nil
            }
        }
        debugPrint("Selected Range >>> \(selectedRange)")
        return result
    }

    public func removeListItem(selectedRange: NSRange) -> NSRange? {
        let range = selectedRange
        let caretRange = lineRange(for: range.location)
        let hasCaret = (attribute(.caret, in: caretRange).first != nil)
        if hasCaret {
            let (_, range) = listsFormatter.removeListItem(atLine: caretRange)
            if let range = range {
                return NSMakeRange(selectedRange.location - range.length, selectedRange.length)
            }
        }
        return nil
    }
}

/// Mention + helpers

extension WYSIWYGTextStorage {
    @discardableResult
    public func addMention(_ item: IMentionableItem, at range: NSRange) -> NSRange {
        guard selectedSymbolLocation != nil && selectedSymbolLocation < range.location else { return range }
        let removableRange = NSMakeRange(selectedSymbolLocation, range.location - selectedSymbolLocation)

        /// add new mention
        let finalText = "\(item.pickableText) "
        replaceCharacters(in: removableRange, with: finalText)

        /// styling
        var style = FormatStyle.shared.mentionFormat.style
        style[.mention] = item
        style[.font] = editingStyle[.font]

        let newRange = NSMakeRange(removableRange.location, finalText.count - 1)
        let lastRange = NSMakeRange(newRange.max, 1)
        setAttributes(style, range: newRange)
        setAttributes([.font: bodyFont], range: lastRange)

        return NSMakeRange(lastRange.max, 0)
    }

    public func appendMention(_ item: IMentionableItem, at range: NSRange) -> NSRange {
        /// add new mention
        let finalText = "\(item.pickableText) "
        replaceCharacters(in: range, with: finalText)

        /// styling
        var style = FormatStyle.shared.mentionFormat.style
        style[.mention] = item
        style[.font] = editingStyle[.font]

        let newRange = NSMakeRange(range.location, finalText.count - 1)
        let lastRange = NSMakeRange(newRange.max, 1)
        setAttributes(style, range: newRange)
        setAttributes([.font: bodyFont], range: lastRange)

        return NSMakeRange(lastRange.max, 0)
    }

    public func endMentionProcess() {
        searchString = ""
        selectedSymbol = ""
        selectedSymbolLocation = 0
        isInMentionProcess = false
    }
}

// MARK: - Formatting Metadata

/// Metadata about the interactive changes, in the text, made by the user.
fileprivate struct ChangedText: CustomStringConvertible {
    var contents: String
    var mask: NSTextStorage.EditActions
    var range: NSRange
    var lineRange: NSRange
    var listItem: ListItem?

    var isNewLine: Bool {
        return contents == "\n" && mask.contains(.editedCharacters)
    }

    var canDeleting: Bool {
        return (contents == "\n" || contents == "") && mask.contains(.editedCharacters)
    }

    var description: String {
        let change: String
        switch contents {
        case " ":
            change = "<space>"
        case "\n":
            change = "<newline>" // + (isNewLine ? "+" : "?")
        default:
            change = "\"\(contents)\""
        }

        var extras: [String] = []
        extras.append("line \(lineRange)")
        if let listStyle = listItem {
            extras.append("\(listStyle)")
        }
        let extrasDescription = extras.joined(separator: ", ")

        return "ChangedText: \(change) at \(range) (\(extrasDescription))"
    }
}

/// Metadata about the resulting formatted text, if any.
struct FormattedText {
    var caretRange: NSRange?

    init(caretRange: NSRange? = nil) {
        self.caretRange = caretRange
    }
}

fileprivate class Formatter {
    fileprivate weak var storage: WYSIWYGTextStorage!
    fileprivate var backingStore: NSMutableAttributedString { return storage.backingStore }

    var bodyStyle: [NSAttributedString.Key: Any] { return storage.editingStyle }

    func formattedText(caretAtLine index: Int) -> FormattedText {
        let lineRange = storage.lineRange(for: index)
        return FormattedText(caretRange: lineRange)
    }
}

extension NSAttributedString.Key {
    /// Indicates the last character *before* the fixed/corrected caret location.
    static let caret = NSAttributedString.Key("markdown.caret")
}

// MARK: - Words Formatting

extension NSAttributedString.Key {
    static let italic = NSAttributedString.Key("markdown.italic")
    static let bold = NSAttributedString.Key("markdown.bold")
    static let italic_bold = NSAttributedString.Key("markdown.italic_bold")
    static let strikethrough = NSAttributedString.Key("markdown.strikethrough")
    static let underline = NSAttributedString.Key("markdown.underline")

    // mention
    static let mention = NSAttributedString.Key("markdown.mention")

    // hastag
    static let hash_tag = NSAttributedString.Key("markdown.hash_tag")
}

public final class FormatStyle {
    public static let shared = FormatStyle()

    public struct WordFormat {
        var key: NSAttributedString.Key
        var regex: NSRegularExpression
        var onlyPrefix: Bool = false
        public var style: [NSAttributedString.Key: Any]
        public var enclosingChars: String

        func markdown(for text: String) -> String {
            if onlyPrefix {
                return "\(enclosingChars)\(text)"
            }
            return "\(enclosingChars)\(text)\(enclosingChars)"
        }
    }

    public var mentionFormat = WordFormat(
        key: .mention,
        regex: regex("^@([^\\r\\n]+).*?"),
        style: [
            .mention: true,
            .foregroundColor: UIColor.blue,
        ],
        enclosingChars: "@"
    )

    public var hashTagFormat = WordFormat(
        key: .hash_tag,
        regex: regex("^#([^\\r\\n]+).*?"),
        style: [
            .mention: true,
            .foregroundColor: UIColor.blue,
        ],
        enclosingChars: "#"
    )

    public var italicFormat = WordFormat(
        key: .italic,
        regex: regex("(?<=^|[^*])[*_]{1}(?<text>\\w+(\\s+\\w+)*)[*_]{1}"),
        style: [.italic: true],
        enclosingChars: "*"
    )

    public var boldFormat = WordFormat(
        key: .bold,
        regex: regex("[*_]{2}(?<text>\\w+(\\s+\\w+)*)[*_]{2}"),
        style: [.bold: true],
        enclosingChars: "**"
    )

    public var strikethroughFormat = WordFormat(
        key: .strikethrough,
        regex: regex("(?<=^|[^*])[~_]{1}(?<text>\\w+(\\s+\\w+)*)[~_]{1}"),
        style: [
            .strikethrough: true,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: UIColor.black,
        ],
        enclosingChars: "~"
    )

    public var underlineFormat = WordFormat(
        key: .underline,
        regex: regex("(?<=^|[^*])[-_]{1}(?<text>\\w+(\\s+\\w+)*)[-_]{1}"),
        style: [
            .underline: true,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.black,
        ],
        enclosingChars: "_"
    )
}

fileprivate final class WordsFormatter: Formatter {
    private static let allFormats: [FormatStyle.WordFormat] = []

    func formatWords(in change: ChangedText) -> FormattedText? {
        for wordsFormat in Self.allFormats {
            if let formattedText = formatWords(in: change, using: wordsFormat) {
                return formattedText
            }
        }
        return nil
    }

    private func formatWords(
        in change: ChangedText,
        using format: FormatStyle.WordFormat
    ) -> FormattedText? {
        let match = format.regex.firstMatch(in: backingStore.string, range: change.lineRange)

        if let match = match {
            var style = format.style
            style[.font] = bodyStyle[.font]

            // text range
            let textRange = match.range(withName: "text")

            // Captures the target text.
            let text: String
            let foundText = (textRange.location < storage.backingString.length)
            if foundText {
                text = storage.backingString.substring(with: textRange)
            } else {
                text = storage.backingStore.string.string(inRange: match.range)
            }

            let attribText = NSMutableAttributedString(
                string: text,
                attributes: style
            )

            if foundText {
                // Adds trailing whitespace if needed.
                let nextChar = storage.character(at: match.range.max)
                if nextChar == nil || nextChar != " " {
                    attribText.append(NSAttributedString(string: " ", attributes: bodyStyle))
                }

                // Fixes caret position and applies words formatting.
                attribText.addAttribute(
                    .caret, value: true,
                    range: NSMakeRange(attribText.length - 1, 1)
                )
                storage.replaceCharacters(in: match.range, with: attribText)
                return formattedText(caretAtLine: match.range.location)
            } else {
                storage.replaceCharacters(in: match.range, with: attribText)
            }
            return nil
        } else {
            return nil
        }
    }

    func format(_ markdownString: NSAttributedString) -> NSAttributedString {
        var markdownString = markdownString
        for wordsFormat in Self.allFormats {
            markdownString = format(markdownString, using: wordsFormat)
        }
        return markdownString
    }

    private func format(
        _ markdownString: NSAttributedString,
        using format: FormatStyle.WordFormat
    ) -> NSAttributedString {
        return markdownString.mapLines {
            attribLine in
            let line = attribLine.string
            let lineRange = attribLine.range

            let mutableLine = NSMutableAttributedString(attributedString: attribLine)
            let matches = format.regex.matches(in: line, range: lineRange)

            for match in matches.reversed() {
                let text = (line as NSString).substring(with: match.range(withName: "text"))
                let formattedText = NSAttributedString(string: text, attributes: format.style)
                mutableLine.replaceCharacters(in: match.range, with: formattedText)
            }
            return mutableLine
        }
    }

    func deformat(_ formattedString: NSAttributedString) -> NSAttributedString {
        var markdownString = formattedString
        for wordsFormat in Self.allFormats {
            markdownString = deformat(markdownString, using: wordsFormat)
        }
        return markdownString
    }

    fileprivate func deformat(
        _ attribString: NSAttributedString,
        using format: FormatStyle.WordFormat
    ) -> NSAttributedString {
        return attribString.mapLines {
            attribLine in
            let line = attribLine.string as NSString
            let mutableLine = NSMutableAttributedString(attributedString: attribLine)
            let attribs = attribLine.attribute(format.key, in: attribLine.range)

            for attrib in attribs.reversed() {
                let text = line.substring(with: attrib.range)
                let markdownText = format.markdown(for: text)
                mutableLine.removeAttribute(format.key, range: attrib.range)
                mutableLine.replaceCharacters(in: attrib.range, with: markdownText)
            }
            return mutableLine
        }
    }
}

// MARK: - Lists Formatting

extension NSAttributedString.Key {
    static let list = NSAttributedString.Key("markdown.list")
}

let zeroWidthSpace = "\u{200B}"

/// Identifies a given list item (or list kind).
/// This is used as the *value* for the `NSAttributedString.Key.list` custom attribute.
public enum ListItem: CaseIterable, CustomStringConvertible {
    case bullet(level: Int = 1)
    case dashed(level: Int = 1)
    case ordered(Int?)
    case checkmark(Bool?)

    public static let allCases = [bullet(), dashed(), ordered(nil), checkmark(nil)]

    public var description: String {
        return "\(rawValue) list"
    }

    public var itemMarker: String {
        switch self {
        case .bullet:
            return "•"
        case .dashed:
            return "–"
        case let .ordered(number):
            return "\(number!)."
        case .checkmark:
            return zeroWidthSpace
        }
    }

    public var nextItem: ListItem {
        switch self {
        case .bullet:
            return self
        case .dashed:
            return self
        case let .ordered(number):
            return .ordered(number! + 1)
        case .checkmark:
            return .checkmark(false)
        }
    }

    public var previousItem: ListItem {
        switch self {
        case .bullet:
            return self
        case .dashed:
            return self
        case let .ordered(number):
            return .ordered(number! - 1)
        case .checkmark:
            return .checkmark(false)
        }
    }

    private static let bulletItemRegex = regex("^([*]\\h).*")
    private static let dashedItemRegex = regex("^([-]\\h).*")
    private static let orderedItemRegex = regex("^((?<number>[0-9]+)[.]\\h).*")
    private static let checkmarkItemRegex = regex("^(\\[(?<bool>_|x)\\]\\h).*")

    public var itemRegex: NSRegularExpression {
        switch self {
        case .bullet:
            return ListItem.bulletItemRegex
        case .dashed:
            return ListItem.dashedItemRegex
        case .ordered:
            return ListItem.orderedItemRegex
        case .checkmark:
            return ListItem.checkmarkItemRegex
        }
    }

    func firstMatch(in string: String, range: NSRange) -> (kind: ListItem, range: NSRange)? {
        guard let match = itemRegex.firstMatch(in: string, range: range) else {
            return nil
        }
        switch self {
        case .bullet, .dashed:
            return (self, match.range(at: 1))
        case .ordered:
            let numberRange = match.range(withName: "number")
            let number = (string as NSString).substring(with: numberRange)
            return (.ordered(Int(number)), match.range(at: 1))
        case .checkmark:
            let boolRange = match.range(withName: "bool")
            let boolFlag = (string as NSString).substring(with: boolRange)
            let bool: Bool
            switch boolFlag {
            case "_":
                bool = false
            case "x":
                bool = true
            default:
                preconditionFailure("Unknown bool flag: \(boolFlag)")
            }
            return (.checkmark(bool), match.range(at: 1))
        }
    }

    var paragraphStyle: NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 10
        paragraphStyle.headIndent = 10
        paragraphStyle.paragraphSpacingBefore = 2.5

        switch self {
        case .bullet, .dashed, .ordered:
            break

        case .checkmark:
            paragraphStyle.firstLineHeadIndent = 26
            paragraphStyle.headIndent = 26
            paragraphStyle.paragraphSpacing = 10
        }
        return paragraphStyle
    }

    var kern: NSNumber {
        switch self {
        case .bullet, .dashed:
            return NSNumber(value: 6.5)
        case .ordered:
            return NSNumber(value: 3.5)
        case .checkmark:
            return NSNumber(value: 0.0)
        }
    }

    var markdownPrefix: String {
        switch self {
        case .bullet:
            return "* "
        case .dashed:
            return "- "
        case let .ordered(number):
            return "\(number!). "
        case let .checkmark(bool):
            if bool! {
                return "[x] "
            } else {
                return "[_] "
            }
        }
    }

    var beginGroupTag: String {
        switch self {
        case .bullet: return "<ul>"
        case .ordered: return "<ol>"
        default: return ""
        }
    }

    var endGroupTag: String {
        switch self {
        case .bullet: return "</ul>"
        case .ordered: return "</ol>"
        default: return ""
        }
    }
}

/// Support for encoding as an attribute value.
extension ListItem: RawRepresentable {
    private static let orderedRegex = regex("ordered[(](?<number>[0-9]+)[)]")
    private static let checkmarkRegex = regex("checkmark[(](?<bool>true|false)[)]")

    public init?(rawValue: String) {
        switch rawValue {
        case "bullet":
            self = .bullet()
        case "dashed":
            self = .dashed()
        case "ordered":
            self = .ordered(nil)
        case "checkmark":
            self = .checkmark(nil)
        default:
            if let orderedMatch = ListItem.orderedRegex.firstMatch(in: rawValue) {
                let numberRange = orderedMatch.range(withName: "number")
                let number = (rawValue as NSString).substring(with: numberRange)
                self = .ordered(Int(number))
            } else if let checkmarkMatch = ListItem.checkmarkRegex.firstMatch(in: rawValue) {
                let boolRange = checkmarkMatch.range(withName: "bool")
                let bool = (rawValue as NSString).substring(with: boolRange)
                self = .checkmark(Bool(bool)!)
            } else {
                return nil
            }
        }
    }

    public var rawValue: String {
        switch self {
        case .bullet:
            return "bullet"
        case .dashed:
            return "dashed"
        case let .ordered(number):
            if let number = number {
                return "ordered(\(number))"
            } else {
                return "ordered"
            }
        case let .checkmark(bool):
            if let bool = bool {
                return "checkmark(\(bool))"
            } else {
                return "checkmark"
            }
        }
    }
}

fileprivate final class ListsFormatter: Formatter {
    func itemStyle(for listItem: ListItem) -> [NSAttributedString.Key: Any] {
        var itemStyle: [NSAttributedString.Key: Any] = [.font: storage.bodyFont]
        itemStyle[.list] = listItem.rawValue
        itemStyle[.paragraphStyle] = listItem.paragraphStyle

        return itemStyle
    }

    private func itemMarker(for listItem: ListItem) -> NSAttributedString {
        let itemMarker = NSMutableAttributedString(
            string: listItem.itemMarker,
            attributes: itemStyle(for: listItem)
        )

        let attributeRange = NSMakeRange(itemMarker.length - 1, 1)

        itemMarker.addAttribute(
            .kern,
            value: listItem.kern,
            range: attributeRange
        )
        itemMarker.addAttribute(
            .caret, value: true,
            range: attributeRange
        )
        return itemMarker
    }

    func listItem(at lineRange: NSRange, effectiveRange: NSRangePointer? = nil) -> ListItem? {
        let lineRange = storage.lineRange(for: lineRange.location)
        let lineStart = lineRange.location
        guard lineStart < backingStore.length else {
            return nil
        }
        let rawListKind = backingStore.attribute(
            .list,
            at: lineStart,
            longestEffectiveRange: effectiveRange,
            in: lineRange
        )
        if let rawListKind = rawListKind as? String {
            return ListItem(rawValue: rawListKind)!
        } else {
            return nil
        }
    }

    func getPreviousOrderListItem(at index: Int) -> ListItem? {
        let text = storage.string

        /// get current line range
        let lineRange = storage.lineRange(for: index)

        /// get previous line range
        if lineRange.location > 0 {
            /// check previous is \n
            let newLine = text.string(inRange: NSMakeRange(lineRange.location - 1, 1))
            if newLine == "\n" && lineRange.location > 1 {
                /// find previous line range
                let previousLineRange = storage.lineRange(for: lineRange.location - 2)

                /// checking list item is ordered type
                if let listItem = listItem(at: previousLineRange), case let .ordered = listItem {
                    return listItem
                }
            }
        }
        return nil
    }

    @discardableResult
    func insertListItem(_ listItem: ListItem, at index: Int) -> NSRange {
        let lineRange = storage.lineRange(for: index)
        let itemMarker = self.itemMarker(for: listItem)
        storage.replaceCharacters(in: NSMakeRange(lineRange.location, 0), with: itemMarker)
        return itemMarker.range
    }

    @discardableResult
    func removeListItem(atLine lineRange: NSRange) -> (ListItem?, NSRange?) {
        var listItemRange = NSMakeRange(0, 0)
        guard let oldListItem = listItem(at: lineRange, effectiveRange: &listItemRange) else {
            return (nil, nil) // List item not found.
        }

        /// remove old one
        storage.removeAttribute(.list, range: listItemRange)
        storage.removeAttribute(.paragraphStyle, range: listItemRange)
        storage.removeAttribute(.caret, range: listItemRange)
        storage.removeAttribute(.kern, range: listItemRange)
        storage.replaceCharacters(in: listItemRange, with: "")
        return (oldListItem, listItemRange)
    }

    @discardableResult
    func replaceListItem(_ newListItem: ListItem, atLine lineRange: NSRange) -> NSRange? {
        /// remove old one
        let (oldListItem, range) = removeListItem(atLine: lineRange)
        if let oldListItem = oldListItem, let range = range {
            /// insert new one
            if oldListItem != newListItem {
                let result = insertListItem(newListItem, at: range.location)
                return NSMakeRange(lineRange.location, range.length - result.length)
            }
        }
        return nil
    }

    @discardableResult
    func updateListItem(_ newListItem: ListItem, atLine lineRange: NSRange) -> NSRange? {
        var listItemRange = NSMakeRange(0, 0)
        guard let oldListItem = listItem(at: lineRange, effectiveRange: &listItemRange) else {
            return nil // List item not found.
        }
        switch (oldListItem, newListItem) {
        case (.bullet, .bullet), (.dashed, .dashed),
             (.ordered, .ordered), (.checkmark, .checkmark):

            /// remove old one
            storage.removeAttribute(.list, range: listItemRange)
            storage.removeAttribute(.paragraphStyle, range: listItemRange)
            storage.removeAttribute(.caret, range: listItemRange)
            storage.removeAttribute(.kern, range: listItemRange)
            storage.replaceCharacters(in: listItemRange, with: "")

            /// insert new one
            return insertListItem(newListItem, at: lineRange.location)
        default:
            debugPrint("List not compatible at \(lineRange)")
        }
        return nil
    }

    func formatLists(for change: ChangedText) -> FormattedText? {
        for listItem in ListItem.allCases {
            // User entered an empty list item (i.e., we should end the list)?
            if let textFormatted = formatEmptyListItem(for: change) {
                return textFormatted
            }

            // User entered a new list item?
            if let textFormatted = formatNewListItem(for: change) {
                return textFormatted
            }

            // User started a new list?
            if let textFormatted = formatNewList(listItem, for: change) {
                return textFormatted
            }
        }
        return nil
    }

    private func correctCaretPosition(in caretRange: NSRange) -> Int? {
        let caretRange = storage.lineRange(for: caretRange.location)
        guard let caret = storage.attribute(.caret, in: caretRange).first else {
            return nil
        }
        return caret.range.max
    }

    private func formatNewList(
        _ listItem: ListItem,
        for change: ChangedText
    ) -> FormattedText? {
        let itemMatch = listItem.firstMatch(
            in: backingStore.string,
            range: change.lineRange
        )
        if let itemMatch = itemMatch {
            let itemMarker = self.itemMarker(for: itemMatch.kind)
            storage.replaceCharacters(in: itemMatch.range, with: itemMarker)
            return formattedText(caretAtLine: itemMatch.range.location)
        } else {
            return nil
        }
    }

    private func formatNewListItem(for change: ChangedText) -> FormattedText? {
        guard let listItem = change.listItem, change.isNewLine else {
            return nil
        }
        let nextItem = listItem.nextItem
        let itemMarker = self.itemMarker(for: nextItem)
        let lineStart = NSMakeRange(change.range.max, 0)

        storage.replaceCharacters(in: lineStart, with: itemMarker)
        switch nextItem {
        case .ordered:
            reformatFollowingOrderedItems(nextItem, at: lineStart.location)
        case .bullet, .dashed, .checkmark:
            break
        }

        if let newCarectLocation = correctCaretPosition(in: lineStart) {
            return FormattedText(caretRange: NSMakeRange(newCarectLocation, 0))
        }
        return FormattedText(caretRange: NSMakeRange(lineStart.max, 0))
    }

    func reformatFollowingOrderedItems(_ item: ListItem? = nil, at lineStart: Int) {
        var nextItem: ListItem! = item
        var lineStart = lineStart

        while true {
            let nextLine = storage.lineRange(for: lineStart).max
            guard nextLine < storage.length else { break }

            nextItem = nextItem?.nextItem ?? .ordered(1)
            if updateListItem(nextItem, atLine: NSMakeRange(nextLine, 0)) == nil { break }
            lineStart = nextLine
        }
    }

    func formatEmptyListItem(for change: ChangedText) -> FormattedText? {
        func deleteCharacters(inRange range: NSRange) {
            storage.setAttributes(bodyStyle, range: range)
            storage.replaceCharacters(in: range, with: "")
        }

        guard let listItem = change.listItem, change.canDeleting else {
            return nil
        }

        /// move cursor to previous line
        var cursorLocation = change.lineRange.location
        let editLocation = change.range.location
        let maxLineLocation = change.lineRange.max

        let startOfItemLocation = change.lineRange.location
        let endOfItemLocation = change.lineRange.location + listItem.itemMarker.count

        // handle for enter on empty line
        if change.isNewLine && change.lineRange.length <= listItem.itemMarker.count + 1 {
            deleteCharacters(inRange: change.lineRange)

            /// move to first location of line
            return FormattedText(caretRange: NSMakeRange(cursorLocation, 0))
        }
        /// handle delete in range of list item
        else if editLocation >= startOfItemLocation && editLocation <= endOfItemLocation {
            /// move to previous line
            if cursorLocation > 1 && cursorLocation <= storage.range.max {
                cursorLocation = cursorLocation - 1
            }

            /// delete
            if maxLineLocation <= endOfItemLocation {
                deleteCharacters(inRange: change.lineRange)
            } else {
                let removableRange = NSMakeRange(cursorLocation, endOfItemLocation - cursorLocation)
                deleteCharacters(inRange: removableRange)
            }

            /// update next ordered list items
            let nextItem = listItem.previousItem
            switch nextItem {
            case .ordered:
                reformatFollowingOrderedItems(nextItem, at: cursorLocation)
            case .bullet, .dashed, .checkmark:
                break
            }

            return FormattedText(caretRange: NSMakeRange(cursorLocation, 0))
        }
        return nil
    }

    func format(in markdownString: NSAttributedString) -> NSAttributedString {
        var markdownString = markdownString
        for listItem in ListItem.allCases {
            markdownString = formatList(listItem, in: markdownString)
        }
        return markdownString
    }

    /// Formats a Markdown-ish string as an attributed string.
    func formatList(
        _ listItem: ListItem,
        in markdownString: NSAttributedString
    ) -> NSAttributedString {
        return markdownString.mapLines {
            attribLine in
            let line = attribLine.string
            let lineRange = attribLine.range

            if let itemMatch = listItem.firstMatch(in: line, range: lineRange) {
                let mutableLine = NSMutableAttributedString(attributedString: attribLine)
                let itemMarker = self.itemMarker(for: itemMatch.kind)
                mutableLine.replaceCharacters(in: itemMatch.range, with: itemMarker)
                return mutableLine
            } else {
                return attribLine
            }
        }
    }

    /// Deformats an attributed string to a Markdown-ish string.
    func deformat(_ attribString: NSAttributedString) -> NSAttributedString {
        return attribString.mapLines {
            attribLine in
            let mutableLine = NSMutableAttributedString(attributedString: attribLine)
            let attribs = attribLine.attribute(.list, in: attribLine.range)

            if let attrib = attribs.first {
                let listItem = ListItem(rawValue: attrib.value as! String)!
                mutableLine.removeAttribute(.list, range: attrib.range)
                mutableLine.replaceCharacters(in: attrib.range, with: listItem.markdownPrefix)
            }

            trimeZeroWidthWhitespaces(from: mutableLine.mutableString)
            return mutableLine
        }
    }

    private let zeroWidthSpaceRegex = regex(zeroWidthSpace)

    private func trimeZeroWidthWhitespaces(from str: NSMutableString) {
        zeroWidthSpaceRegex.replaceMatches(in: str, range: str.range, withTemplate: "")
    }
}

// MARK: - Helpers

extension NSRange {
    /// Returns the sum of the location and length of the range.
    var max: Int {
        return location + length
    }
}
