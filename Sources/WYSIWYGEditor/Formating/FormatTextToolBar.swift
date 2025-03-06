//
//  FormatTextToolBar.swift
//  Simple Notes
//
//  Created by Khoai Nguyen on 1/30/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import UIKit

public protocol FormatTextToolBarDelegate: AnyObject {
    func toolbar(_ toolbar: FormatTextToolBar, didTouchItem item: GeneralItemType)
}

public final class FormatTextToolBar: UIView {
    weak var delegate: FormatTextToolBarDelegate?
    private var stackView: UIStackView!
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setUpViews() {
        backgroundColor = .yellow
        
        /// item by item
        let textFormatItem = UIButton(type: .custom)
        textFormatItem.setImage(GeneralItemType.textFormat.toImage(), for: .normal)
        textFormatItem.addTarget(self, action: #selector(onFormatText(_:)), for: .touchUpInside)

        let hideKeyboardItem = UIButton(type: .custom)
        hideKeyboardItem.setImage(GeneralItemType.hideKeyboard.toImage(), for: .normal)
        hideKeyboardItem.addTarget(self, action: #selector(onHideKeyboard(_:)), for: .touchUpInside)
        
        /// stack
        stackView = UIStackView(arrangedSubviews: [textFormatItem, UILabel(), hideKeyboardItem])
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.safeAreaLayoutGuide.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func onFormatText(_ sender: Any) {
        delegate?.toolbar(self, didTouchItem: GeneralItemType.textFormat)
    }

    @objc private func onHideKeyboard(_ sender: Any) {
        delegate?.toolbar(self, didTouchItem: GeneralItemType.hideKeyboard)
    }
}
