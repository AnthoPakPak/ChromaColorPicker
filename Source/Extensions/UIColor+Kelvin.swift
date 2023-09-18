//
//  KelvinColor.swift
//  KelvinColor
//
//  Created by Sihao Lu on 8/24/17.
//  Copyright © 2017 Sihao. All rights reserved.
//

// ChatGPT-generated https://chat.openai.com/share/25367a22-c537-488d-9d07-1d33933ca808
// I was previously using an extension from https://github.com/DJBen/KelvinColor ported from https://raw.githubusercontent.com/neilbartlett/color-temperature/master/index.js, but it had some issues (jumping from 1000 to 2000 for example). The ChatGPT version seem more reliable (even though it also jumps from 1600 to 2000; there might be something wrong with the algo for those values).

import UIKit

public extension UIColor {
    /// Initialize color based on the Kelvin temperature
    ///
    /// - Parameter kelvin: color temperature in degrees Kelvin
    convenience init(temperature kelvin: Double) {
        let temperature = kelvin / 100.0
        var red, green, blue: Double
        
        // Red
        if temperature <= 66 {
            red = 255.0
        } else {
            red = temperature - 60.0
            red = 329.698727446 * pow(red, -0.1332047592)
            red = max(0, min(255, red))
        }
        
        // Green
        if temperature <= 66 {
            green = temperature
            green = 99.4708025861 * log(green) - 161.1195681661
        } else {
            green = temperature - 60.0
            green = 288.1221695283 * pow(green, -0.0755148492)
        }
        green = max(0, min(255, green))
        
        // Blue
        if temperature >= 66 {
            blue = 255.0
        } else if temperature <= 19 {
            blue = 0.0
        } else {
            blue = temperature - 10.0
            blue = 138.5177312231 * log(blue) - 305.0447927307
            blue = max(0, min(255, blue))
        }
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    var temperature: Double {
        let minKelvin: Double = 1000
        let maxKelvin: Double = 40000
        let step: Double = 100
        
        var closestColor: UIColor = UIColor(temperature: minKelvin)
        var minDifference: Double = colorDifference(color1: self, color2: closestColor)
        var closestKelvin: Double = minKelvin
        
        var currentKelvin = minKelvin + step
        
        while currentKelvin <= maxKelvin {
            let currentColor = UIColor(temperature: currentKelvin)
            let currentDifference = colorDifference(color1: self, color2: currentColor)
            
            if currentDifference < minDifference {
                minDifference = currentDifference
                closestColor = currentColor
                closestKelvin = currentKelvin
            }
            
            currentKelvin += step
        }
        
        return closestKelvin
    }

    private func colorDifference(color1: UIColor, color2: UIColor) -> Double {
        guard let rgb1 = color1.cgColor.components, let rgb2 = color2.cgColor.components else {
            return Double.infinity
        }
        
        let rDiff = Double(rgb1[0] - rgb2[0])
        let gDiff = Double(rgb1[1] - rgb2[1])
        let bDiff = Double(rgb1[2] - rgb2[2])
        
        return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
    }
}
