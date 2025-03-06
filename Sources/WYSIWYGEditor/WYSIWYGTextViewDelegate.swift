//
//  File.swift
//
//
//  Created by Khoai Nguyen on 3/14/24.
//

import UIKit

// MARK: - WYSIWYGTextViewDelegate

public protocol WYSIWYGTextViewDelegate: AnyObject {
    func WYSIWYGTextViewDidBeginEditing(_ textView: UITextView)
    func WYSIWYGTextViewDidEndEditing(_ textView: UITextView)
    func WYSIWYGTextViewDidChange(_ textView: UITextView)
}

// MARK: - WYSIWYGMentionDelegate

public protocol WYSIWYGMentionDelegate: AnyObject {
    func WYSIWYGTextViewWillMention(_ textView: UITextView)
    func WYSIWYGTextViewWillHashTag(_ textView: UITextView)
    func WYSIWYGTextView(_ textView: UITextView, searchForText text: String)
    func WYSIWYGTextView(_ textView: UITextView, didRemoveMentionItem item: IMentionableItem)
    func WYSIWYGTextView(_ textView: UITextView, didRemoveSymbolCharacter character: String)
}

// MARK: - WYSIWYGFormatDelegate

public protocol WYSIWYGFormatDelegate: AnyObject {
    func WYSIWYGTextView(_ textView: UITextView, textStyleDidChange style: TextFormat)
    func WYSIWYGTextView(_ textView: UITextView, listStyleDidChange style: TextFormat)
}

// MARK: - IWYSIWYGTextViewAdapter

public protocol IWYSIWYGTextViewAdapter: UITextViewDelegate {
    var textDelegate: WYSIWYGTextViewDelegate? { get }
    var formatDelegate: WYSIWYGFormatDelegate? { get }
    var mentionDelegate: WYSIWYGMentionDelegate? { get }
}

// MARK: - WYSIWYGTextViewAdapter

public final class WYSIWYGTextViewAdapter: NSObject, IWYSIWYGTextViewAdapter {
    public weak var textDelegate: WYSIWYGTextViewDelegate?
    public weak var formatDelegate: WYSIWYGFormatDelegate?
    public weak var mentionDelegate: WYSIWYGMentionDelegate?

    public weak var textView: UITextView!
    private var storage: WYSIWYGTextStorage {
        precondition(textView.textStorage is WYSIWYGTextStorage, "TextStorage must be WYSIWYGTextStorage")
        return textView.textStorage as! WYSIWYGTextStorage
    }

    private var editingStyle: [NSAttributedString.Key: Any] {
        get { storage.editingStyle }
        set {
            storage.editingStyle = newValue
            selectedStyle = nil
            previousText = storage.string
        }
    }

    private var selectedStyle: TextFormat!
    private var previousText: String = ""
}

extension WYSIWYGTextViewAdapter {
    /// Fixes weird animation glitch on paste action.
    /// More info: https://stackoverflow.com/a/51771555/819340
    public func textPasteConfigurationSupporting(
        _ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting,
        shouldAnimatePasteOf attributedString: NSAttributedString,
        to textRange: UITextRange) -> Bool {
        return false
    }

    // MARK: - Editing Flow

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        precondition(self.textView == textView, "It's not correct object.")

        // ShouldChangeText
        var shouldChangeText = true

        // In Filter Process
        if storage.isInMentionProcess {
            // delete text
            if text.isEmpty {
                // delete the special symbol string
                if range.location == storage.selectedSymbolLocation {
                    // end mention process
                    storage.endMentionProcess()

                    // remove symbol string
                    mentionDelegate?.WYSIWYGTextView(textView, didRemoveSymbolCharacter: storage.selectedSymbol)
                } else {
                    // deleted indehx
                    let deletedIndex = range.location - storage.selectedSymbolLocation - 1

                    // deleted index greter than -1
                    guard deletedIndex > -1 && deletedIndex < storage.searchString.count
                    else {
                        storage.endMentionProcess()
                        return true
                    }

                    let index = storage.searchString.index(
                        storage.searchString.startIndex,
                        offsetBy: deletedIndex
                    )
                    storage.searchString.remove(at: index)

                    // Retrieve Picker Data
                    mentionDelegate?.WYSIWYGTextView(textView, searchForText: storage.searchString)
                }

            } else {
                storage.searchString += text

                // Retrieve Picker Data
                mentionDelegate?.WYSIWYGTextView(textView, searchForText: storage.searchString)
            }

        } else {
            /// mentionDeletionProcess
            var mentionDeletionProcess = false

            // check if delete already mentioned item
            if let selectedRange = textView.selectedTextRange {
                // cursor position
                let cursorPosition = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
                guard cursorPosition > 0 else { return true }

                // iterate through all range
                textView.attributedText.enumerateAttributes(in: NSRange(0 ..< textView.textStorage.length), options: []) { attributes, rangeAttributes, _ in

                    // get value for IMentionableItem
                    if let mentionedItem = attributes[.mention] as? IMentionableItem,
                       cursorPosition > rangeAttributes.location && (text.isEmpty ? cursorPosition - 1 : cursorPosition) <= rangeAttributes.location + rangeAttributes.length {
                        // replace the mentioned item with (symbol with mentioned title)@
                        let removableRange = rangeAttributes

                        /// update normal attributed
                        textView.textStorage.replaceCharacters(
                            in: removableRange,
                            with: NSAttributedString(string: "", attributes: storage.editingStyle)
                        )

                        // move cursor to the end of replacement string
                        self.moveCursor(to: removableRange.location)

                        // set selected symbol information
                        self.storage.selectedSymbol = mentionedItem.symbol
                        self.storage.selectedSymbolLocation = removableRange.location

                        // skip this change in text
                        shouldChangeText = false

                        // set mention deletion process true
                        mentionDeletionProcess = true

                        // delegate picked item
                        mentionDelegate?.WYSIWYGTextView(textView, didRemoveMentionItem: mentionedItem)
                    }
                }

                // check to start mention process for special characters
                if text.isEmpty && !mentionDeletionProcess {
                } else {
                    // set normal attributes
                }
            }
        }
        return shouldChangeText
    }

    public func textViewDidBeginEditing(_ textView: UITextView) {
        textDelegate?.WYSIWYGTextViewDidBeginEditing(textView)
    }

    public func textViewDidEndEditing(_ noteView: UITextView) {
        textDelegate?.WYSIWYGTextViewDidEndEditing(textView)
    }

    public func textViewDidChange(_ textView: UITextView) {
        /// check for mention
        let tagChar = characterBeforeCursor(textView)
        if tagChar == FormatStyle.shared.mentionFormat.enclosingChars {
            storage.selectedSymbol = tagChar ?? ""
            storage.selectedSymbolLocation = textView.nsRangeBeforeCursor?.location ?? -1
            mentionDelegate?.WYSIWYGTextViewWillMention(textView)
        } else if tagChar == FormatStyle.shared.hashTagFormat.enclosingChars {
            mentionDelegate?.WYSIWYGTextViewWillHashTag(textView)
        } else {
            /// formatted
            if let style = selectedStyle {
                storage.editingStyle = style.toAttributes()
                selectedStyle = nil
            }

            let formattedText = storage.processRichFormatting()
            if let caretRange = formattedText?.caretRange {
                fixCaretPosition(in: caretRange)
            }
        }

        /// text did change
        textDelegate?.WYSIWYGTextViewDidChange(textView)

        /// update
        updateSelectedStyle(range: textView.selectedRange)

        /// update previous text
        previousText = textView.attributedText.string
    }

    /// Dirty hack to ignore ZERO WIDTH SPACE characters.
    /// https://www.fileformat.info/info/unicode/char/200b
    public func textViewDidChangeSelection(_ textView: UITextView) {
        updateSelectedStyle(range: textView.nsRangeBeforeCursor)
    }

    // MARK: private methods

    private func updateSelectedStyle(range: NSRange?) {
        guard let checkingRange = range else { return }

        let shouldUpdate = (previousText == textView.attributedText.string)
        if checkingRange.location >= 0 && checkingRange.location <= storage.range.length {
            let selectedStyle = textView.attributedText.getStyleAtSelectedRange(
                checkingRange,
                font: storage.bodyFont
            )

            if let styles = selectedStyle {
                formatDelegate?.WYSIWYGTextView(textView, listStyleDidChange: styles)

                if shouldUpdate {
                    formatDelegate?.WYSIWYGTextView(textView, textStyleDidChange: styles)
                    self.selectedStyle = selectedStyle
                }
            }
        }
    }

    private func fixCaretPosition(in caretRange: NSRange) {
        let caretRange = storage.lineRange(for: caretRange.location)
        guard let caret = storage.attribute(.caret, in: caretRange).first else {
            return
        }
        setCaretPosition(to: caret.range.max)
    }

    private func setCaretPosition(to caret: Int) {
        textView.selectedRange = NSRange(location: caret, length: 0)
    }

    private func character(at charIndex: Int) -> String? {
        return textView.attributedText!.character(at: charIndex)
    }

    private func characterBeforeCursor(_ textView: UITextView) -> String? {
        // get the cursor position
        if let cursorRange = textView.selectedTextRange {
            // get the position one character before the cursor start position
            if let newPosition = textView.position(from: cursorRange.start, offset: -1) {
                let range = textView.textRange(from: newPosition, to: cursorRange.start)
                return textView.text(in: range!)
            }
        }
        return nil
    }

    // MARK: - Debugging Helpers

    fileprivate func printChar(at charIndex: Int) {
        let char = character(at: charIndex)!
        let charName: String

        switch char {
        case " ":
            charName = "<space>"
        case "\n":
            charName = "<newline>"
        default:
            charName = "\"\(char)\""
        }
        print("Character: \(charName)")
    }

    public func moveCursor(to location: Int, completion: (() -> Void)? = nil) {
        // get cursor position
        if let newPosition = textView.position(from: textView.beginningOfDocument, offset: location) {
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.textView.selectedTextRange = self.textView.textRange(from: newPosition, to: newPosition)
                completion?()
            }
        }
    }
}
