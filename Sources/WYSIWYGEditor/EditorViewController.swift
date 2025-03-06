//
//  NoteEditorViewController.swift
//  Simple Notes
//
//  Created by Paulo Mattos on 09/03/19.
//  Copyright © 2019 Paulo Mattos. All rights reserved.
//

import UIKit

final class MentionUser: IMentionableItem {
    var text: String
    var mentionableId: Int

    init(text: String, id: Int) {
        self.text = text
        self.mentionableId = id
    }
}

/// Shows and edits a given note.
final class EditorViewController: UIViewController, WYSIWYGTextViewDelegate, WYSIWYGMentionDelegate {
    private var formatViewController: FormatViewController!

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setUpNoteView()
        setUpFormatView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavigationBar()
        registerForKeyboardNotifications()
        textView.loadNote("")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        deregisterFromKeyboardNotifications()
    }

    private func setUpNavigationBar() {
        navigationController!.navigationBar.setTransparentBackground(true)
        let toHTML = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(onExport(_:)))
        navigationItem.rightBarButtonItems = [toHTML]
    }

    @objc func onExport(_ sender: Any?) {
        let html1 = textView.textStorage.standadizedHTML
        debugPrint(html1)

        let html = """
        <ul><li><b>Xin chào</b> <span contenteditable=\"false\" data-id=\"123\" class=\"mention fr-deletable\">@Nguyen Minh Khoai</span>, xin chúc mừng anh đã trở thành người may mắn nhận được một chiếc oto <b>Mercedes-Maybach GLS 600</b> </li><li><span contenteditable=\"false\" data-id=\"123\" class=\"mention fr-deletable\">Mời @Nguyen Minh Khoai</span> <i>sắp xếp thời gian sớm để tới nhận thưởng sớm.</i></li></ul><ol><li>Anh sẽ nhận được tiền thưởng vào ngày <b>20/08/2024</b></li><li>Xin cảm ơn <span contenteditable=\"false\" data-id=\"123\" class=\"mention fr-deletable\">@Nguyen Minh Khoai</span> </li></ol>

        <b>Top Fruits in the world</b>
        <ol>
          <li>Countries that grow Tomatoes
            <ul>
              <li>China</li>
              <li>India</li>
              <li>Turkey</li>
            </ul>
          </li>
          <li>Countries that grow Bananas
            <ul>
              <li>Indonesia</li>
              <li>Brazil</li>
              <li>Angola</li>
            </ul>
          </li>
        </ol>
        """

        textView.attributedText = html.toWYSIWYGAttributedString(
            font: UIFont.systemFont(ofSize: 18),
            mentionableItems: { _ in [MentionUser(text: "Nguyen Minh Khoai", id: 123)] }
        )
    }

    // MARK: - Note Bar Action

    private func setUpFormatView() {
        let noteBar = FormatViewController()
        noteBar.delegate = self
        noteBar.view.frame = .init(origin: .zero, size: .init(width: view.frame.width, height: 62))

        /// add & layout
        textView.inputAccessoryView = noteBar.view
        noteBar.view.translatesAutoresizingMaskIntoConstraints = false

        // move to parent
        addChild(noteBar)
        noteBar.didMove(toParent: self)

        formatViewController = noteBar
    }

    // MARK: - Note Model

    func loadNote(_ note: String) {
        loadViewIfNeeded()
        textView.loadNote(note)
        endEditing(updateNote: false)
    }

    // MARK: - Note Text View

    @IBOutlet private var noteViewContainer: UIView!
    private var textView: WYSIWYGTextView!

    private func setUpNoteView() {
        precondition(isViewLoaded)
        precondition(textView == nil)

        // Note storage layer.
        let textStorage = WYSIWYGTextStorage()

        // We use a single NSTextContainer (for the UITextView).
        let textContainerSize = CGSize(
            width: view.bounds.width,
            height: .greatestFiniteMagnitude
        )
        let textContainer = NSTextContainer(size: textContainerSize)
        textContainer.widthTracksTextView = true

        // Defines a standard NSLayoutManager.
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        // Finally, add the UITextView to this view controller.
        textView = WYSIWYGEditor.WYSIWYGTextView(frame: view.bounds, textContainer: textContainer)
        textView.editingDelegate = self
        textView.mentionDelegate = self
        layoutTextView()
    }

    private func layoutTextView() {
        noteViewContainer.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: noteViewContainer.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: noteViewContainer.trailingAnchor),
            textView.topAnchor.constraint(equalTo: noteViewContainer.topAnchor),
            textView.bottomAnchor.constraint(equalTo: noteViewContainer.bottomAnchor),
        ])
    }

    // MARK: - Editing Flow

    func WYSIWYGTextViewDidChange(_ textView: UITextView) {
    }

    func WYSIWYGTextViewDidBeginEditing(_ textView: UITextView) {
    }

    func WYSIWYGTextViewDidEndEditing(_ textView: UITextView) {
        endEditing(updateNote: true)
    }

    func WYSIWYGTextViewWillMention(_ textView: UITextView) {
        debugPrint("noteTextViewWillMention")
//        if let range = textView.nsRangeBeforeCursor {
//            textView.selectedRange = textView.wyswygStorage.addMention(
//                MentionUser(text: "Nguyen Minh Khoai", id: 123),
//                at: range
//            )
//        }
    }

    func WYSIWYGTextView(_ textView: UITextView, styleAtSelectedRange style: TextFormat) {
    }

    func WYSIWYGTextView(_ textView: UITextView, didRemoveMentionItem item: IMentionableItem) {
    }

    func WYSIWYGTextView(_ textView: UITextView, didRemoveSymbolCharacter character: String) {
    }

    func WYSIWYGTextView(_ textView: UITextView, searchForText text: String) {
        debugPrint("searchForText")
    }

    func WYSIWYGTextViewWillHashTag(_ textView: UITextView) {
        debugPrint("noteTextViewWillHashTag")
    }

    private func endEditing(updateNote: Bool) {
        textView.endEditing()
    }

    // MARK: - Keyboard Management

    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWasShown(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillBeHidden(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func deregisterFromKeyboardNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private var oldContentInsets: UIEdgeInsets?
    private var oldScrollIndicatorInsets: UIEdgeInsets?

    /// Need to calculate keyboard exact size due to Apple suggestions
    @objc private func keyboardWasShown(notification: NSNotification) {
        let info = notification.userInfo!
        let keyboardSize = (info[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.size
        let contentInsets: UIEdgeInsets = UIEdgeInsets(
            top: 0.0, left: 0.0,
            bottom: keyboardSize!.height, right: 0.0
        )

        oldContentInsets = textView.contentInset
        oldScrollIndicatorInsets = textView.verticalScrollIndicatorInsets

        textView.contentInset = contentInsets
        textView.scrollIndicatorInsets = contentInsets

        var visibleRect: CGRect = view.frame
        visibleRect.size.height -= keyboardSize!.height

        let caret = textView.caretRect(for: textView.selectedTextRange!.start)
        if !visibleRect.contains(caret.origin) {
            textView.scrollRectToVisible(caret, animated: true)
        }
    }

    /// Once keyboard disappears, restore original positions
    @objc func keyboardWillBeHidden(notification: NSNotification) {
        if let oldContentInsets = oldContentInsets,
           let oldScrollIndicatorInsets = oldScrollIndicatorInsets {
            textView.contentInset = oldContentInsets
            textView.scrollIndicatorInsets = oldScrollIndicatorInsets
        }
    }
}

extension EditorViewController: FormatViewControllerDelegate {
    func format(_ formatter: FormatViewController, didChangeType type: TextFormatChangeType, textFormat format: TextFormat) {
        let storage = textView.wyswygStorage
        if type == .style {
            let attrs = format.toAttributes()
            storage?.editingStyle = attrs
            storage?.setAttributes(attrs, range: textView.selectedRange)
        } else if type == .list {
            /// If current sentence contains selected format, jsut ignored
            /// Otherwise, replace or add new
            switch format.listStyles.first {
            case .dash:
                storage?.addOrReplaceListItem(
                    .dashed(),
                    selectedRange: textView.selectedRange
                )

            case .bullet:
                storage?.addOrReplaceListItem(
                    .bullet(),
                    selectedRange: textView.selectedRange
                )

            case .order:
                storage?.addOrReplaceListItem(
                    .ordered(1),
                    selectedRange: textView.selectedRange
                )

            default: break
            }
        }
    }

    func didHideKeyboard(_ formatter: FormatViewController) {
        textView.resignFirstResponder()
    }
}
