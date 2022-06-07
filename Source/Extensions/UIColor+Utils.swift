//
//  UIColor+Utils.swift
//  ChromaColorPicker
//
//  Created by Jonathan Cardasis on 11/8/19.
//  Copyright © 2019 Jonathan Cardasis. All rights reserved.
//

import UIKit

public extension UIColor {
    
    /// The value of lightness a color has. Value between [0.0, 1.0]
    /// Based on YIQ color space for constrast (https://www.w3.org/WAI/ER/WD-AERT/#color-contrast)
    var lightness: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: nil)

        return ((red * 299) + (green * 587) + (blue * 114)) / 1000
    }
    
    /// Whether or not the color is considered 'light' in terms of contrast.
    var isLight: Bool {
        return lightness >= 0.5
    }
    
    internal class func hexStringToUIColor(hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}
