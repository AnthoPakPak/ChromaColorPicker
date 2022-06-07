//
//  ColorWheelView.swift
//  ChromaColorPicker
//
//  Created by Jon Cardasis on 4/11/19.
//  Copyright © 2019 Jonathan Cardasis. All rights reserved.
//

import UIKit

/// This value is used to expand the imageView's bounds and then mask back to its normal size
/// such that any displayed image may have perfectly rounded corners.
private let defaultImageViewCurveInset: CGFloat = 1.0

public enum ColorWheelMode {
    case RGB
    case Temperature
}

public class ColorWheelView: UIView {
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.masksToBounds = false
        layer.cornerRadius = radius
        
        let screenScale: CGFloat = UIScreen.main.scale
        
        if mode == .RGB {
            if let colorWheelImage: CIImage = makeColorWheelImage(radius: radius * screenScale) {
                imageView.image = UIImage(ciImage: colorWheelImage, scale: screenScale, orientation: .up)
            }
        } else if mode == .Temperature {
            //Create a Temperature circle with gradient
            imageView.layer.addSublayer(makeTemperatureWheelLayer())
        }
        
        // Mask imageview so the generated colorwheel has smooth edges.
        // We mask the imageview instead of image so we get the benefits of using the CIImage
        // rendering directly on the GPU.
        imageViewMask.frame = imageView.bounds.insetBy(dx: defaultImageViewCurveInset, dy: defaultImageViewCurveInset)
        imageViewMask.layer.cornerRadius = imageViewMask.bounds.width / 2.0
        imageView.mask = imageViewMask
    }

    public var radius: CGFloat {
        return max(bounds.width, bounds.height) / 2.0
    }
    
    public var middlePoint: CGPoint {
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    public var mode: ColorWheelMode = .RGB {
        didSet {
            imageView.image = nil
            imageView.layer.sublayers?.removeAll()
            layoutNow()
        }
    }

    /**
     Returns the (x,y) location of the color provided within the ColorWheelView.
     Disregards color's brightness component.
    */
    public func location(of color: UIColor) -> CGPoint {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: nil, alpha: nil)
        
        let radianAngle = hue * (2 * .pi)
        let distance = saturation * radius
        let colorTranslation = CGPoint(x: distance * cos(radianAngle), y: -distance * sin(radianAngle))
        let colorPoint = CGPoint(x: bounds.midX + colorTranslation.x, y: bounds.midY + colorTranslation.y)
        
        return colorPoint
    }
    
    /**
     Returns the color on the wheel on a given point relative to the view. nil is returned if
     the point does not exist within the bounds of the color wheel.
    */
    // TODO: replace this function with a mathmatically based one in ChromaColorPicker
    public func pixelColor(at point: CGPoint) -> UIColor? {
        guard pointIsInColorWheel(point) else { return nil }
        
        // Values on the edge of the circle should be calculated instead of obtained
        // from the rendered view layer. This ensures we obtain correct values where
        // image smoothing may have taken place.
        if mode != .Temperature {
            guard !pointIsOnColorWheelEdge(point) else {
                let angleToCenter = atan2(point.x - middlePoint.x, point.y - middlePoint.y)
                return edgeColor(for: angleToCenter)
            }
        }
        
        let pixel = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.translateBy(x: -point.x, y: -point.y)
        imageView.layer.render(in: context)
        let color = UIColor(
            red: CGFloat(pixel[0]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue: CGFloat(pixel[2]) / 255.0,
            alpha: 1.0
        )
        
        pixel.deallocate()
        return color
    }
    
    /**
     Returns whether or not the point is in the circular area of the color wheel.
    */
    public func pointIsInColorWheel(_ point: CGPoint) -> Bool {
        guard bounds.insetBy(dx: -1, dy: -1).contains(point) else { return false }
        
        let distanceFromCenter: CGFloat = hypot(middlePoint.x - point.x, middlePoint.y - point.y)
        let pointExistsInRadius: Bool = distanceFromCenter <= (radius - layer.borderWidth)
        return pointExistsInRadius
    }
    
    public func pointIsInColorCircle(_ point: CGPoint) -> Bool {
        guard bounds.insetBy(dx: -1, dy: -1).contains(point) else { return false }
        
        let distanceFromCenter: CGFloat = hypot(middlePoint.x - point.x, middlePoint.y - point.y)
        let pointExistsInCircle: Bool = distanceFromCenter <= (radius - layer.borderWidth) && distanceFromCenter >= (radius - defaultTemperatureWheelSize)
        return pointExistsInCircle
    }
    
    public func pointIsOnColorWheelEdge(_ point: CGPoint) -> Bool {
        let distanceToCenter = hypot(middlePoint.x - point.x, middlePoint.y - point.y)
        let isPointOnEdge = distanceToCenter >= radius - 1.0
        return isPointOnEdge
    }
    
    // MARK: - Private
    internal let imageView = UIImageView()
    internal let imageViewMask = UIView()
    
    internal func commonInit() {
        backgroundColor = .clear
        setupImageView()
    }
    
    internal func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageViewMask.backgroundColor = .black
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: widthAnchor, constant: defaultImageViewCurveInset * 2),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, constant: defaultImageViewCurveInset * 2),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    /**
     Generates a color wheel image from a given radius.
     - Parameters:
        - radius: The radius of the wheel in points. A radius of 100 would generate an
                  image of 200x200 points (400x400 pixels on a device with 2x scaling.)
    */
    internal func makeColorWheelImage(radius: CGFloat) -> CIImage? {
        let filter = CIFilter(name: "CIHueSaturationValueGradient", parameters: [
            "inputColorSpace": CGColorSpaceCreateDeviceRGB(),
            "inputDither": 0,
            "inputRadius": radius,
            "inputSoftness": 0,
            "inputValue": 1
        ])
        return filter?.outputImage
    }
    
    //inspired by https://stackoverflow.com/a/21121954/4894980
    internal func makeTemperatureWheelLayer() -> CAGradientLayer {
        let faucetShape = CAShapeLayer()
        faucetShape.lineWidth = defaultTemperatureWheelSize
        faucetShape.frame = CGRect(x: faucetShape.lineWidth/4, y: faucetShape.lineWidth/4, width: imageView.frame.width - faucetShape.lineWidth, height: imageView.frame.height - faucetShape.lineWidth)
        faucetShape.strokeColor = UIColor.black.cgColor
        faucetShape.fillColor = nil
        let path = CGMutablePath()
        path.addEllipse(in: faucetShape.frame)
        faucetShape.path = path
        
        let faucet = CAGradientLayer()
        faucet.frame = imageView.frame
        faucet.mask = faucetShape
//        faucet.colors = [UIColor.hexStringToUIColor(hex: "FE9C3E").cgColor, UIColor.hexStringToUIColor(hex: "FFFFFF").cgColor, UIColor.hexStringToUIColor(hex: "CADBFE").cgColor]
        faucet.colors = [UIColor(temperature: 2001).cgColor, UIColor(temperature: 5500).cgColor, UIColor(temperature: 9000).cgColor]

        return faucet
    }
    
    /**
     Returns a color for a provided radian angle on the color wheel.
     - Note: Adjusts angle for the local color space and returns a color of
             max saturation and brightness with variable hue.
    */
    internal func edgeColor(for angle: CGFloat) -> UIColor {
        var normalizedAngle = angle + .pi // normalize to [0, 2pi]
        normalizedAngle += (.pi / 2) // rotate pi/2 for color wheel
        var hue = normalizedAngle / (2 * .pi)
        if hue > 1 { hue -= 1 }
        return UIColor(hue: hue, saturation: 1, brightness: 1.0, alpha: 1.0)
    }
}

internal let defaultTemperatureWheelSize: CGFloat = 50
