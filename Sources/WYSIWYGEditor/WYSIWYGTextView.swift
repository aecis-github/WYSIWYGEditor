//
//  WYSIWYGTextView.swift
//  Created by Khoai Nguyen on 2/21/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers

// MARK: -

/// Custom `UITextView` subclass for showing & editing a given `Note` object.
open class WYSIWYGTextView: UITextView, UITextViewDelegate, UITextPasteDelegate {
    public var editingStyle: [NSAttributedString.Key: Any] {
        get { wyswygStorage.editingStyle }
        set {
            wyswygStorage.editingStyle = newValue
            selectedStyle = nil
            previousText = wyswygStorage.string
        }
    }

    private var selectedStyle: TextFormat!
    private var previousText: String = ""
    private var isPasting: Bool = false

    /// storage
    public var wyswygStorage: WYSIWYGTextStorage! {
        return textStorage as? WYSIWYGTextStorage
    }

    override public var text: String! {
        didSet {
            postTextViewDidChangeNotification()
        }
    }

    override public var attributedText: NSAttributedString! {
        didSet {
            postTextViewDidChangeNotification()
        }
    }

    /// A UILabel that holds the InputTextView's placeholder text
    public let placeholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .lightGray
        label.text = "Aa"
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// The placeholder text that appears when there is no text
    public var placeholder: String? = "Aa" {
        didSet {
            placeholderLabel.text = placeholder
        }
    }

    /// The placeholderLabel's textColor
    public var placeholderTextColor: UIColor? = .lightGray {
        didSet {
            placeholderLabel.textColor = placeholderTextColor
        }
    }

    /// The UIEdgeInsets the placeholderLabel has within the InputTextView
    public var placeholderLabelInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4) {
        didSet {
            updateConstraintsForPlaceholderLabel()
        }
    }

    /// The font of the InputTextView. When set the placeholderLabel's font is also updated
    override public var font: UIFont! {
        didSet {
            placeholderLabel.font = font
            wyswygStorage?.bodyFont = font
            wyswygStorage?.editingStyle[.font] = font
        }
    }

    /// The textAlignment of the InputTextView. When set the placeholderLabel's textAlignment is also updated
    override public var textAlignment: NSTextAlignment {
        didSet {
            placeholderLabel.textAlignment = textAlignment
        }
    }

    /// The textContainerInset of the InputTextView. When set the placeholderLabelInsets is also updated
    override public var textContainerInset: UIEdgeInsets {
        didSet {
            placeholderLabelInsets = textContainerInset
        }
    }

    /// Adds a notification for .UITextViewTextDidChange to detect when the placeholderLabel
    /// should be hidden or shown
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WYSIWYGTextView.onTextChanged(_:)),
            name: UITextView.textDidChangeNotification, object: nil
        )
    }

    override public var scrollIndicatorInsets: UIEdgeInsets {
        didSet {
            // When .zero a rendering issue can occur
            if scrollIndicatorInsets == .zero {
                scrollIndicatorInsets = UIEdgeInsets(
                    top: .leastNonzeroMagnitude,
                    left: .leastNonzeroMagnitude,
                    bottom: .leastNonzeroMagnitude,
                    right: .leastNonzeroMagnitude
                )
            }
        }
    }

    /// The constraints of the placeholderLabel
    private var placeholderLabelConstraintSet: NSLayoutConstraintSet?

    /// Adds the placeholderLabel to the view and sets up its initial constraints
    private func setupPlaceholderLabel() {
        addSubview(placeholderLabel)
        placeholderLabelConstraintSet = NSLayoutConstraintSet(
            top: placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: placeholderLabelInsets.top),
            bottom: placeholderLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -placeholderLabelInsets.bottom),
            left: placeholderLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: placeholderLabelInsets.left),
            right: placeholderLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -placeholderLabelInsets.right),
            centerX: placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerY: placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        )
        placeholderLabelConstraintSet?.centerX?.priority = .defaultLow
        placeholderLabelConstraintSet?.centerY?.priority = .defaultLow
        placeholderLabelConstraintSet?.activate()
    }

    /// Updates the placeholderLabels constraint constants to match the placeholderLabelInsets
    private func updateConstraintsForPlaceholderLabel() {
        placeholderLabelConstraintSet?.top?.constant = placeholderLabelInsets.top
        placeholderLabelConstraintSet?.bottom?.constant = -placeholderLabelInsets.bottom
        placeholderLabelConstraintSet?.left?.constant = placeholderLabelInsets.left
        placeholderLabelConstraintSet?.right?.constant = -placeholderLabelInsets.right
    }

    // MARK: - Notifications

    private func postTextViewDidChangeNotification() {
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: self)
    }

    @objc
    private func onTextChanged(_ sender: Any) {
        let isPlaceholderHidden = !text.isEmpty
        placeholderLabel.isHidden = isPlaceholderHidden
        // Adjust constraints to prevent unambiguous content size
        if isPlaceholderHidden {
            placeholderLabelConstraintSet?.deactivate()
        } else {
            placeholderLabelConstraintSet?.activate()
        }
    }

    // MARK: - View Initializers

    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override public func paste(_ sender: Any?) {
        isPasting = true
        super.paste(sender)
    }

    private func setup() {
        setUpTextView()

        scrollIndicatorInsets = UIEdgeInsets(
            top: .leastNonzeroMagnitude,
            left: .leastNonzeroMagnitude,
            bottom: .leastNonzeroMagnitude,
            right: .leastNonzeroMagnitude
        )
        setupPlaceholderLabel()
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setUpTextView() {
        delegate = self
        pasteDelegate = self
        spellCheckingType = .no
        autocorrectionType = .no
        autocapitalizationType = .sentences
        dataDetectorTypes = [.link, .phoneNumber]
        font = wyswygStorage?.bodyFont ?? .systemFont(ofSize: 14)
        isSelectable = true
    }

    // MARK: - Delegate

    public weak var editingDelegate: WYSIWYGTextViewDelegate?
    public weak var mentionDelegate: WYSIWYGMentionDelegate?
    public weak var formatDelegate: WYSIWYGFormatDelegate?

    // MARK: - User Interaction

    private var initialTouchY: CGFloat = 0

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        initialTouchY = touches.first!.location(in: self).y
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let swipeDistance = abs(touch.location(in: self).y - initialTouchY)
        if swipeDistance <= 10 {
            if !didTapNoteView(touch) {
                super.touchesEnded(touches, with: event)
            }
        }
    }

    @objc private func didTapNoteView(_ touch: UITouch) -> Bool {
        // Location of tap in noteView coordinates and taking the inset into account.
        var location = touch.location(in: self)
        location.x -= textContainerInset.left
        location.y -= textContainerInset.top

        // Character index at tap location.
        var unitInsertionPoint: CGFloat = 0
        let charIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &unitInsertionPoint
        )
        assert(unitInsertionPoint >= 0.0 && unitInsertionPoint <= 1.0)

        if !detectTappableText(at: charIndex, with: unitInsertionPoint) {
            startEditing(at: charIndex, with: unitInsertionPoint)
            return true
        } else {
            return false
        }
    }

    private func detectTappableText(
        at charIndex: Int,
        with unitInsertionPoint: CGFloat
    ) -> Bool {
        guard charIndex < textStorage.length else {
            return false
        }

        let noteText = attributedText!
        let tappableAttribs: [NSAttributedString.Key] = [.link, .list]
        for attrib in tappableAttribs {
            var attribRange = NSRange(location: 0, length: 0)
            let attribValue = noteText.attribute(
                attrib, at: charIndex,
                effectiveRange: &attribRange
            )
            guard let _ = attribValue else {
                continue
            }
            guard !(charIndex == attribRange.max - 1 && unitInsertionPoint == 1.0) else {
                continue // Tapped after the link end.
            }
            return true
        }
        return false
    }

    // MARK: - Fixes Copy & Paste Bug

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
        if isPasting {
            isPasting = false

            /// parse html
            let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pastedAttributedText: NSAttributedString
            if let data = UIPasteboard.general.data(forPasteboardType: "public.html") {
                pastedAttributedText = String(data: data, encoding: .utf8)?
                    .toWYSIWYGAttributedString(
                        font: wyswygStorage.bodyFont,
                        mentionableItems: { _ in [] }
                    ) ?? .init(string: text)
            } else {
                pastedAttributedText = .init(
                    string: text,
                    attributes: [
                        .font: wyswygStorage.bodyFont,
                    ]
                )
            }
            wyswygStorage.insert(pastedAttributedText, at: range.location)

            /// notify
            onTextChanged(self)
            notifyChanges()

            return false
        }

        // ShouldChangeText
        var shouldChangeText = true

        // In Filter Process
        if wyswygStorage.isInMentionProcess {
            // delete text
            if text.isEmpty {
                // delete the special symbol string
                if range.location == wyswygStorage.selectedSymbolLocation {
                    // end mention process
                    wyswygStorage.endMentionProcess()

                    // trigger event
                    mentionDelegate?.WYSIWYGTextView(textView, didRemoveSymbolCharacter: wyswygStorage.selectedSymbol)
                } else {
                    // deleted indehx
                    let deletedIndex = range.location - wyswygStorage.selectedSymbolLocation - 1

                    // deleted index greter than -1
                    guard deletedIndex > -1 && deletedIndex < wyswygStorage.searchString.count
                    else {
                        wyswygStorage.endMentionProcess()
                        return true
                    }

                    let index = wyswygStorage.searchString.index(
                        wyswygStorage.searchString.startIndex,
                        offsetBy: deletedIndex
                    )
                    wyswygStorage.searchString.remove(at: index)

                    // Retrieve Picker Data
                    mentionDelegate?.WYSIWYGTextView(self, searchForText: wyswygStorage.searchString)
                }

            } else {
                wyswygStorage.searchString += text

                // Retrieve Picker Data
                mentionDelegate?.WYSIWYGTextView(self, searchForText: wyswygStorage.searchString)
            }

        } else {
            /// mentionDeletionProcess
            var mentionDeletionProcess = false

            // check if delete already mentioned item
            if let selectedRange = selectedTextRange {
                // cursor position
                let cursorPosition = offset(from: beginningOfDocument, to: selectedRange.start)
                guard cursorPosition > 0 else { return true }

                // iterate through all range
                attributedText.enumerateAttributes(in: NSRange(0 ..< textStorage.length), options: []) { attributes, rangeAttributes, _ in

                    // get value for IMentionableItem
                    if let mentionedItem = attributes[.mention] as? IMentionableItem,
                       text == "" && cursorPosition > rangeAttributes.location && cursorPosition <= rangeAttributes.max {
                        // replace the mentioned item with (symbol with mentioned title)@
                        let removableRange = rangeAttributes

                        /// update normal attributed
                        self.textStorage.replaceCharacters(
                            in: removableRange,
                            with: NSAttributedString(string: "", attributes: wyswygStorage.editingStyle)
                        )

                        // move cursor to the end of replacement string
                        self.moveCursor(to: removableRange.location)

                        // set selected symbol information
                        self.wyswygStorage.selectedSymbol = mentionedItem.symbol
                        self.wyswygStorage.selectedSymbolLocation = removableRange.location

                        // skip this change in text
                        shouldChangeText = false

                        // set mention deletion process true
                        mentionDeletionProcess = true

                        // delegate picked item
                        mentionDelegate?.WYSIWYGTextView(self, didRemoveMentionItem: mentionedItem)
                    }
                }

                // check to start mention process for special characters
                if text.isEmpty && !mentionDeletionProcess {
                } else {
                    // set normal attributes
                }
            }
        }

        if let formattedText = wyswygStorage.handleBeforeTextChanged(
            selectedRange: selectedRange,
            isBack: text == ""
        ) {
            if let caretRange = formattedText.caretRange {
                selectedRange = NSRange(location: caretRange.location, length: 0)
            }

            /// notify
            notifyChanges()
            return false
        }

        return shouldChangeText
    }

    public func textViewDidBeginEditing(_ textView: UITextView) {
        editingDelegate?.WYSIWYGTextViewDidBeginEditing(self)
    }

    public func textViewDidEndEditing(_ noteView: UITextView) {
        editingDelegate?.WYSIWYGTextViewDidEndEditing(self)
    }

    public func textViewDidChange(_ noteView: UITextView) {
        /// check for mention
        let tagChar = characterBeforeCursor(noteView)
        if tagChar == FormatStyle.shared.mentionFormat.enclosingChars {
            wyswygStorage.selectedSymbol = tagChar ?? ""
            wyswygStorage.selectedSymbolLocation = noteView.nsRangeBeforeCursor?.location ?? -1

            mentionDelegate?.WYSIWYGTextViewWillMention(self)
        } else if tagChar == FormatStyle.shared.hashTagFormat.enclosingChars {
            mentionDelegate?.WYSIWYGTextViewWillHashTag(self)
        } else {
            /// formatted
            if let style = selectedStyle {
                wyswygStorage.editingStyle = style.toAttributes()
                selectedStyle = nil
            }

            let formattedText = wyswygStorage.processRichFormatting()
            if let caretRange = formattedText?.caretRange {
                selectedRange = NSRange(location: caretRange.location, length: 0)
            }
        }

        /// notify
        notifyChanges()
    }

    /// Dirty hack to ignore ZERO WIDTH SPACE characters.
    /// https://www.fileformat.info/info/unicode/char/200b
    public func textViewDidChangeSelection(_ textView: UITextView) {
        updateSelectedStyle(range: nsRangeBeforeCursor)
    }

    // MARK: private methods

    public func notifyChanges(withoutUpdatingStyle: Bool = false) {
        /// text did change
        editingDelegate?.WYSIWYGTextViewDidChange(self)

        /// update
        if !withoutUpdatingStyle {
            updateSelectedStyle(range: selectedRange)
        }

        /// update previous text
        previousText = attributedText.string
    }

    private func updateSelectedStyle(range: NSRange?) {
        guard let checkingRange = range else { return }

        let shouldUpdate = (previousText == attributedText.string)
        if checkingRange.location >= 0 && checkingRange.location <= wyswygStorage.range.length {
            let selectedStyle = attributedText.getStyleAtSelectedRange(
                checkingRange,
                font: wyswygStorage.bodyFont
            )

            if let styles = selectedStyle {
                formatDelegate?.WYSIWYGTextView(self, listStyleDidChange: styles)

                if shouldUpdate {
                    formatDelegate?.WYSIWYGTextView(self, textStyleDidChange: styles)
                    self.selectedStyle = selectedStyle
                }
            }
        }
    }

    private func character(at charIndex: Int) -> String? {
        return attributedText!.character(at: charIndex)
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

    private func startEditing(at charIndex: Int, with unitInsertionPoint: CGFloat) {
        isEditable = true
        becomeFirstResponder()
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

    // MARK: public methods

    public func loadNote(_ note: String) {
        wyswygStorage.load(note: "")
    }

    public func endEditing() {
        endEditing(false)
        resignFirstResponder()
    }

    public func moveCursor(to location: Int, completion: (() -> Void)? = nil) {
        // get cursor position
        if let newPosition = position(from: beginningOfDocument, offset: location) {
            DispatchQueue.main.async {
                self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
                completion?()
            }
        }
    }
}

extension WYSIWYGTextView {
    @discardableResult
    public func addOrReplaceListItem(_ item: ListItem) -> NSRange? {
        let newRange = wyswygStorage.addOrReplaceListItem(item, selectedRange: selectedRange)
        if let newRange = newRange {
            /// update selected range
            selectedRange = newRange

            /// update next items
            let nextLineRange = wyswygStorage.lineRange(for: selectedRange.max)
            wyswygStorage.reformatFollowingOrderedItems(at: nextLineRange.max - 1)
        }

        /// update change
        onTextChanged(self)

        /// notify
        notifyChanges(withoutUpdatingStyle: true)

        /// return
        return newRange
    }

    public func removeListItem() {
        /// remove list item
        let newRange = wyswygStorage.removeListItem(selectedRange: selectedRange)

        if let newRange = newRange {
            /// update new range
            selectedRange = newRange

            /// update next items
            let nextLineRange = wyswygStorage.lineRange(for: selectedRange.max)
            wyswygStorage.reformatFollowingOrderedItems(at: nextLineRange.max - 1, reversed: true)
        }

        /// notify
        notifyChanges()
    }

    @discardableResult
    public func addMention(_ item: IMentionableItem, forced: Bool = false) {
        if forced {
            selectedRange = wyswygStorage.appendMention(item, at: selectedRange)
        } else {
            selectedRange = wyswygStorage.addMention(item, at: selectedRange)
        }

        /// update text
        previousText = wyswygStorage.string
    }
}
