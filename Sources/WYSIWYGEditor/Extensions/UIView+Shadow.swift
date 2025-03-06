//
//  UIView+Shadow.swift
//  Simple Notes
//
//  Created by Khoai Nguyen on 1/30/24.
//  Copyright © 2024 Paulo Mattos. All rights reserved.
//

import UIKit

extension UIView {
    func addTopShadow(shadowColor: UIColor = UIColor.black.withAlphaComponent(0.5), shadowHeight height: CGFloat = 2) {
        let shadowPath = UIBezierPath()
        shadowPath.move(to: CGPoint(x: 0, y: 0))
        shadowPath.addLine(to: CGPoint(x: bounds.width, y: 0))
        shadowPath.addLine(to: CGPoint(x: bounds.width - 20, y: bounds.height))
        shadowPath.addLine(to: CGPoint(x: bounds.width - 20, y: bounds.height))
        shadowPath.close()

        layer.shadowColor = shadowColor.cgColor
        layer.shadowOpacity = 0.5
        layer.masksToBounds = false
        layer.shadowPath = shadowPath.cgPath
        layer.shadowRadius = 2
    }
}
