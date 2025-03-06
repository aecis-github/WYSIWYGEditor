//
//  FormatViewController.swift
//  Simple Notes
//
//  Created by Khoai Nguyen on 1/29/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import MultiSelectSegmentedControl
import UIKit

public enum TextFormatChangeType {
    case style
    case list
    case paragraph
}

public struct TextFormat {
    public var font: UIFont = UIFont.systemFont(ofSize: 18)
    public let color: UIColor = .black
    public let styles: [TextFormatItemType]
    public let listStyles: [ListFormatItemType]
    public let paragraphStyles: [ParagraphFormatItemType]

    public func toAttributes() -> [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [
            .font: font,
        ]

        for style in styles {
            let font = result[.font] as? UIFont
            if style == .bold {
                result[.bold] = true
                result[.font] = font?.byTogglingSymbolicTraits(.traitBold)
            } else if style == .italic {
                result[.italic] = true
                result[.font] = font?.byTogglingSymbolicTraits(.traitItalic)
            } else if style == .underline {
                result[.underline] = true
                result[.underlineStyle] = NSUnderlineStyle.single.rawValue
                result[.underlineColor] = color
            } else if style == .strikethrough {
                result[.strikethrough] = true
                result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                result[.strikethroughColor] = color
            }
        }

        return result
    }
}

public protocol FormatViewControllerDelegate: AnyObject {
    func format(
        _ formatter: FormatViewController,
        didChangeType type: TextFormatChangeType,
        textFormat format: TextFormat
    )

    func didHideKeyboard(_ formatter: FormatViewController)
}

public class FormatViewController: UIViewController, WYSIWYGFormatDelegate {
    private var scrollView: UIScrollView!
    private var contentStackView: UIStackView!
    private var moreStackView: UIStackView!
    private var hideKeyboardButton: UIButton!

    private var styleSegementControl: MultiSelectSegmentedControl!
    private var styleSegementItems: [TextFormatItemType] = [.bold, .italic, .underline]

    private var listStyleSegmentControl: MultiSelectSegmentedControl!
    private var listStyleSegementItems: [ListFormatItemType] = [.bullet, .order]

    private var paragraphStyleSegmentControl: MultiSelectSegmentedControl!
    private var paragraphStyleSegementItems: [ParagraphFormatItemType] = []

    public weak var delegate: FormatViewControllerDelegate?
    private var selectedListItemIndex: Int = -1
    private var selectedParagraphItemIndex: Int = -1

    public let padding: CGFloat
    public let iconPointSize: CGFloat

    private func updateIconSize(_ control: MultiSelectSegmentedControl!) {
        guard let control = control else { return }
        control.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.white,
                .font: UIFont.boldSystemFont(ofSize: iconPointSize),
            ],
            for: .selected
        )
        control.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.black,
                .font: UIFont.systemFont(ofSize: iconPointSize),
            ],
            for: .normal
        )
    }

    private func createSegmentControl(_ items: [Any], action: Selector) -> MultiSelectSegmentedControl {
        let result = MultiSelectSegmentedControl(items: items)
        result.tintColor = .black
        result.backgroundColor = UIColor(red: 242 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1)
        result.selectedBackgroundColor = UIColor(red: 228 / 255, green: 175 / 255, blue: 8 / 255, alpha: 1)
        result.setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.boldSystemFont(ofSize: iconPointSize)],
            for: .selected
        )
        result.setTitleTextAttributes(
            [.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: iconPointSize)],
            for: .normal
        )
        result.segments.forEach { $0.imageView?.contentMode = .scaleAspectFit }
        result.allowsMultipleSelection = true
        result.borderWidth = 0
        result.addTarget(self, action: action, for: .valueChanged)
        return result
    }

    public init(iconSize: CGFloat = 24, edgePadding: CGFloat = 8) {
        iconPointSize = iconSize
        padding = edgePadding
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        iconPointSize = 24
        padding = 8
        super.init(coder: coder)
    }

    override public func loadView() {
        super.loadView()

        /// scrollView
        scrollView = UIScrollView(frame: .zero)
        view.addSubview(scrollView)

        /// content view
        let containerView = UIView(frame: .zero)
        scrollView.addSubview(containerView)

        /// stack view
        contentStackView = UIStackView(frame: .zero)
        contentStackView.spacing = 8
        contentStackView.distribution = .fill
        contentStackView.axis = .horizontal
        containerView.addSubview(contentStackView)

        moreStackView = UIStackView(frame: .zero)
        moreStackView.spacing = 8
        moreStackView.distribution = .fill
        moreStackView.axis = .horizontal

        contentStackView.addArrangedSubview(moreStackView)

        /// hide keyboard
        hideKeyboardButton = UIButton(frame: .zero)
        view.addSubview(hideKeyboardButton)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.layer.shadowOffset = CGSize(width: 0, height: -3)
        view.layer.shadowRadius = 3
        view.layer.shadowOpacity = 0.5
        view.layer.shadowColor = UIColor(red: 245 / 255, green: 245 / 255, blue: 245 / 255, alpha: 1.0).cgColor
        view.layer.masksToBounds = false

        scrollView.contentInset = .init(top: 0, left: 0, bottom: 0, right: 60)
        
        hideKeyboardButton.backgroundColor = .white
        hideKeyboardButton.tintColor = .black
        hideKeyboardButton.setTitle("", for: .normal)
        hideKeyboardButton.imageView?.contentMode = .scaleAspectFit
        hideKeyboardButton.setImage(GeneralItemType.hideKeyboard.toImage(pointSize: iconPointSize), for: .normal)
        hideKeyboardButton.addTarget(self, action: #selector(onHideKeyboard(_:)), for: .touchUpInside)

        // styleSegementControl
        styleSegementControl = createSegmentControl(
            styleSegementItems.compactMap {
                if $0 == .bold {
                    return $0.toImage(pointSize: iconPointSize, weight: .bold)
                }
                return $0.toImage(pointSize: iconPointSize)
            },
            action: #selector(onChangedStyle(_:))
        )
        styleSegementControl.isHidden = styleSegementItems.isEmpty

        // listStyleSegmentControl
        listStyleSegmentControl = createSegmentControl(
            listStyleSegementItems.compactMap { $0.toImage(pointSize: iconPointSize) },
            action: #selector(onChangedListStyle(_:))
        )
        listStyleSegmentControl.isHidden = listStyleSegementItems.isEmpty

        // paragraphStyleSegmentControl
        paragraphStyleSegmentControl = createSegmentControl(
            paragraphStyleSegementItems.compactMap { $0.toImage(pointSize: iconPointSize) },
            action: #selector(onChangedParagraphStyle(_:))
        )
        paragraphStyleSegmentControl.isHidden = paragraphStyleSegementItems.isEmpty

        /// add stack
        contentStackView.insertArrangedSubview(styleSegementControl, at: 1)
        moreStackView.addArrangedSubview(listStyleSegmentControl)
        moreStackView.addArrangedSubview(paragraphStyleSegmentControl)

        /// layout
        styleSegementControl.translatesAutoresizingMaskIntoConstraints = false
        moreStackView.translatesAutoresizingMaskIntoConstraints = false
        paragraphStyleSegmentControl.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            paragraphStyleSegmentControl.layoutMarginsGuide.widthAnchor.constraint(equalToConstant: 80),
        ])

        layoutIfNeeded()
    }

    fileprivate func layoutIfNeeded() {
        guard let containerView = scrollView.subviews.first else { return }

        /// layout
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        moreStackView.translatesAutoresizingMaskIntoConstraints = false
        hideKeyboardButton.translatesAutoresizingMaskIntoConstraints = false

        let scrGuide = scrollView.safeAreaLayoutGuide
        let containerViewGuide = containerView.safeAreaLayoutGuide
        let hideKeyboardGuide = hideKeyboardButton.safeAreaLayoutGuide
        let contentStackGuide = contentStackView.safeAreaLayoutGuide

        let scrWidthConstraint = scrGuide.widthAnchor.constraint(equalTo: view.widthAnchor)
        scrWidthConstraint.priority = .defaultLow

        let scrHeightConstraint = scrGuide.heightAnchor.constraint(equalTo: view.heightAnchor)
        scrHeightConstraint.priority = .defaultLow

        if padding > 0 {
            NSLayoutConstraint.activate([
                contentStackGuide.leadingAnchor.constraint(equalTo: containerViewGuide.leadingAnchor, constant: padding),
                contentStackGuide.trailingAnchor.constraint(equalTo: containerViewGuide.trailingAnchor, constant: -padding),
                contentStackGuide.topAnchor.constraint(equalTo: containerViewGuide.topAnchor, constant: padding),
                contentStackGuide.bottomAnchor.constraint(equalTo: containerViewGuide.bottomAnchor, constant: -padding),
            ])
        } else {
            NSLayoutConstraint.activate([
                contentStackGuide.leadingAnchor.constraint(equalTo: containerViewGuide.leadingAnchor),
                contentStackGuide.trailingAnchor.constraint(equalTo: containerViewGuide.trailingAnchor),
                contentStackGuide.topAnchor.constraint(equalTo: containerViewGuide.topAnchor),
                contentStackGuide.bottomAnchor.constraint(equalTo: containerViewGuide.bottomAnchor),
            ])
        }

        NSLayoutConstraint.activate([
            scrGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrGuide.topAnchor.constraint(equalTo: view.topAnchor),
            scrWidthConstraint,
            scrHeightConstraint,

            hideKeyboardGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hideKeyboardGuide.topAnchor.constraint(equalTo: view.topAnchor),
            hideKeyboardGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hideKeyboardGuide.widthAnchor.constraint(equalToConstant: 44),

            containerViewGuide.leadingAnchor.constraint(equalTo: scrGuide.leadingAnchor),
            containerViewGuide.trailingAnchor.constraint(equalTo: scrGuide.trailingAnchor),
            containerViewGuide.topAnchor.constraint(equalTo: scrGuide.topAnchor),
            containerViewGuide.bottomAnchor.constraint(equalTo: scrGuide.bottomAnchor),
        ])
    }

    private func getIndexes<T: Hashable>(ds: [T], items: [T]) -> IndexSet {
        var idxes = IndexSet()
        for item in items {
            if let idx = ds.firstIndex(of: item) {
                idxes.insert(idx)
            }
        }
        return idxes
    }

    public func setHideKeyboardButtonHidden(_ hidden: Bool) {
        hideKeyboardButton.isHidden = hidden
    }

    public func WYSIWYGTextView(_ textView: UITextView, textStyleDidChange style: TextFormat) {
        styleSegementControl.selectedSegmentIndexes = getIndexes(
            ds: styleSegementItems,
            items: style.styles
        )
    }

    public func WYSIWYGTextView(_ textView: UITextView, listStyleDidChange style: TextFormat) {
        listStyleSegmentControl.selectedSegmentIndexes = getIndexes(
            ds: listStyleSegementItems,
            items: style.listStyles
        )

        selectedListItemIndex = listStyleSegmentControl.selectedSegmentIndex
    }
}

// MARK: - - Private

extension FormatViewController {
    private func getTextFormat() -> TextFormat {
        let styles = styleSegementControl.selectedSegmentIndexes.compactMap {
            styleSegementItems[$0]
        }

        let listStyles = listStyleSegmentControl.selectedSegmentIndexes.compactMap {
            listStyleSegementItems[$0]
        }

        let paragraphStyles = paragraphStyleSegmentControl.selectedSegmentIndexes.compactMap { paragraphStyleSegementItems[$0]
        }
        return TextFormat(styles: styles, listStyles: listStyles, paragraphStyles: paragraphStyles)
    }

    @objc private func onChangedStyle(_ sender: MultiSelectSegmentedControl) {
        delegate?.format(self, didChangeType: .style, textFormat: getTextFormat())
    }

    @objc private func onChangedListStyle(_ sender: MultiSelectSegmentedControl) {
        if selectedListItemIndex >= 0 {
            sender.selectedSegmentIndexes = IndexSet(sender.selectedSegmentIndexes.filter({ $0 != selectedListItemIndex }))
        }
        delegate?.format(self, didChangeType: .list, textFormat: getTextFormat())
        selectedListItemIndex = sender.selectedSegmentIndex
    }

    @objc private func onChangedParagraphStyle(_ sender: MultiSelectSegmentedControl) {
        if selectedParagraphItemIndex >= 0 {
            sender.selectedSegmentIndexes = IndexSet(sender.selectedSegmentIndexes.filter({ $0 != selectedParagraphItemIndex }))
        }
        delegate?.format(self, didChangeType: .paragraph, textFormat: getTextFormat())
        selectedParagraphItemIndex = sender.selectedSegmentIndex
    }

    @objc private func onHideKeyboard(_ sender: Any) {
        delegate?.didHideKeyboard(self)
    }
}
