//
//  ChromaColorPicker.swift
//  ChromaColorPicker
//
//  Created by Jon Cardasis on 3/10/19.
//  Copyright © 2019 Jonathan Cardasis. All rights reserved.
//

import UIKit

public protocol ChromaColorPickerDelegate: class {
    /// When a handle's value has changed.
    func colorPickerHandleDidChange(_ colorPicker: ChromaColorPicker, handle: ChromaColorHandle, to color: UIColor)
}


@IBDesignable
public class ChromaColorPicker: UIControl, ChromaControlStylable {
    
    public weak var delegate: ChromaColorPickerDelegate?
    
    @IBInspectable public var borderWidth: CGFloat = 6.0 {
        didSet { layoutNow() }
    }
    
    @IBInspectable public var borderColor: UIColor = .white {
        didSet { layoutNow() }
    }
    
    @IBInspectable public var showsShadow: Bool = true {
        didSet { layoutNow() }
    }
    
    public var mode: ColorWheelMode = .RGB {
        didSet {
            if mode != colorWheelView.mode {
                colorWheelView.mode = mode
            }
        }
    }
    
    /// A brightness slider attached via the `connect(_:)` method.
    private(set) public weak var brightnessSlider: ChromaBrightnessSlider? {
        didSet {
            oldValue?.removeTarget(self, action: nil, for: .valueChanged)
        }
    }
    
    /// The size handles should be displayed at.
    public var handleSize: CGSize = defaultHandleSize {
        didSet { setNeedsLayout() }
    }
    
    /// An extension to handles' hitboxes in the +Y direction.
    /// Allows for handles to be grabbed more easily.
    public var handleHitboxExtensionY: CGFloat = 10.0
    
    /// Handles added to the color picker.
    private(set) public var handles: [ChromaColorHandle] = []
    
    /// The last active handle.
    private(set) public var currentHandle: ChromaColorHandle?
    
    //MARK: - Initialization
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowIfNeeded()
        updateBorderIfNeeded()
        
        handles.forEach { handle in
            let location = colorWheelView.location(of: handle.color)
            handle.frame.size = handleSize
            positionHandle(handle, forColorLocation: location)
        }
    }
    
    // MARK: - Public
    
    @discardableResult
    public func addHandle(at color: UIColor? = nil) -> ChromaColorHandle {
        let handle = ChromaColorHandle()
        handle.color = color ?? defaultHandleColorPosition
        addHandle(handle)
        return handle
    }
    
    public func addHandle(_ handle: ChromaColorHandle) {
        handles.append(handle)
        colorWheelView.addSubview(handle)
        brightnessSlider?.trackColor = handle.color
        
        if currentHandle == nil {
            currentHandle = handle
        }
    }
    
    public func removeHandle(_ handle: ChromaColorHandle) {
        if let index = handles.firstIndex(of: handle) {
            handles.remove(at: index)
        }
        handle.removeFromSuperview()
        
        if currentHandle == handle {
            brightnessSlider?.trackColor = .white
            currentHandle = nil
        }
    }
    
    public func connect(_ slider: ChromaBrightnessSlider) {
        slider.addTarget(self, action: #selector(brightnessSliderDidValueChange(_:)), for: .valueChanged)
        brightnessSlider = slider
    }
    
    // MARK: - Control
    
    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: colorWheelView)
        
        //Create handle at tapped location if there's none
        if currentHandle == nil {
            if (mode == .RGB && colorWheelView.pointIsInColorWheel(location))
                || (mode == .Temperature && colorWheelView.pointIsInColorCircle(location)){ //only if tap is in wheel
                if let pixelColor = colorWheelView.pixelColor(at: location) {
                    let newHandle = addHandle(at: pixelColor)
                    layoutSubviews()
                    informDelegateOfColorChange(on: newHandle)
                }
            }
        }
        
        for handle in handles {
            if extendedHitFrame(for: handle).contains(location) {
                colorWheelView.bringSubviewToFront(handle)
                animateHandleScale(handle, shouldGrow: true)
                
                if let slider = brightnessSlider {
                    slider.trackColor = handle.color.withBrightness(1)
                    slider.currentValue = slider.value(brightness: handle.color.brightness)
                }
                
                currentHandle = handle
                return true
            } else { // handle tap to select color (not that it only works when using one handle only)
                if (mode == .RGB && colorWheelView.pointIsInColorWheel(location))
                    || (mode == .Temperature && colorWheelView.pointIsInColorCircle(location)){ //only if tap is in wheel
                    if let pixelColor = colorWheelView.pixelColor(at: location) {
                        let previousBrightness = handle.color.brightness
                        handle.color = pixelColor.withBrightness(previousBrightness)

                        positionHandle(handle, forColorLocation: location)
                        informDelegateOfColorChange(on: handle)
                    }
                    return self.beginTracking(touch, with: event)
                }
            }
        }
        return false
    }
    
    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        var location = touch.location(in: colorWheelView)
        guard let handle = currentHandle else { return false }
        
        if !colorWheelView.pointIsInColorWheel(location) {
            // Touch is outside color wheel and should map to outermost edge.
            let center = colorWheelView.middlePoint
            let radius = colorWheelView.radius - 2 //substract small value to handle edges (since edgeColor:forAngle: isn't supported on Temperature mode)
            let angleToCenter = atan2(location.x - center.x, location.y - center.y)
            let positionOnColorWheelEdge = CGPoint(x: center.x + radius * sin(angleToCenter),
                                                   y: center.y + radius * cos(angleToCenter))
            location = positionOnColorWheelEdge
        } else {
            //Point is in color wheel. If mode is Temperature, also check point is in circle
            if mode == .Temperature {
                if !colorWheelView.pointIsInColorCircle(location) {
                    // Touch is outside color circle and should map to innermost edge.
                    let center = colorWheelView.middlePoint
                    let radius = colorWheelView.radius - (defaultTemperatureWheelSize - 2) //substract small value to handle edges
                    let angleToCenter = atan2(location.x - center.x, location.y - center.y)
                    let positionOnColorWheelEdge = CGPoint(x: center.x + radius * sin(angleToCenter),
                                                           y: center.y + radius * cos(angleToCenter))
                    location = positionOnColorWheelEdge
                }
            }
        }
        
        if let pixelColor = colorWheelView.pixelColor(at: location) {
            let previousBrightness = handle.color.brightness
            handle.color = pixelColor.withBrightness(previousBrightness)
            positionHandle(handle, forColorLocation: location)
            
            if let slider = brightnessSlider {
                slider.trackColor = pixelColor
                slider.currentValue = slider.value(brightness: previousBrightness)
            }
            
            informDelegateOfColorChange(on: handle)
            sendActions(for: .valueChanged)
        }
        
        return true
    }
    
    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if let handle = currentHandle {
            animateHandleScale(handle, shouldGrow: false)
        }
        sendActions(for: .touchUpInside)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Self should handle all touch events, forwarding if needed.
        let touchableBounds = bounds.insetBy(dx: -handleSize.width, dy: -handleSize.height)
        return touchableBounds.contains(point) ? self : super.hitTest(point, with: event)
    }

    // MARK: - Private
    
    internal let colorWheelView = ColorWheelView()
    internal var colorWheelViewWidthConstraint: NSLayoutConstraint!
    
    internal func commonInit() {
        self.backgroundColor = UIColor.clear
        setupColorWheelView()
    }
    
    internal func setupColorWheelView() {
        colorWheelView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(colorWheelView)
        colorWheelViewWidthConstraint = colorWheelView.widthAnchor.constraint(equalTo: self.widthAnchor)
        
        NSLayoutConstraint.activate([
            colorWheelView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            colorWheelView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            colorWheelViewWidthConstraint,
            colorWheelView.heightAnchor.constraint(equalTo: colorWheelView.widthAnchor),
        ])
    }
    
    func updateShadowIfNeeded() {
        if showsShadow {
            applyDropShadow(shadowProperties(forHeight: bounds.height))
        } else {
            removeDropShadow()
        }
    }
    
    internal func updateBorderIfNeeded() {
        // Use view's background as a border so colorWheel subviews (handles)
        // may appear above the border.
        backgroundColor = borderWidth > 0 ? borderColor : .clear
        layer.cornerRadius = bounds.height / 2.0
        layer.masksToBounds = false
        colorWheelViewWidthConstraint.constant = -borderWidth * 2.0
    }
    
    // MARK: Actions

    @objc
    internal func brightnessSliderDidValueChange(_ slider: ChromaBrightnessSlider) {
        guard let currentHandle = currentHandle else { return }
        
        currentHandle.color = slider.currentColor
        informDelegateOfColorChange(on: currentHandle)
    }
    
    internal func informDelegateOfColorChange(on handle: ChromaColorHandle) { // TEMP:
        if mode == .Temperature {
            //Ensure our color is a kelvin temperature color by converting it back and forth
            handle.color = UIColor(temperature: handle.color.temperature)
        }
        
        delegate?.colorPickerHandleDidChange(self, handle: handle, to: handle.color)
    }
    
    // MARK: - Helpers
    
    internal func extendedHitFrame(for handle: ChromaColorHandle) -> CGRect {
        var frame = handle.frame
        frame.size.height += handleHitboxExtensionY
        return frame
    }
    
    internal func positionHandle(_ handle: ChromaColorHandle, forColorLocation location: CGPoint) {
        handle.center = location.applying(CGAffineTransform.identity.translatedBy(x: 0, y: -handle.bounds.height / 2))
    }
    
    internal func animateHandleScale(_ handle: ChromaColorHandle, shouldGrow: Bool) {
        if shouldGrow && handle.transform.d > 1 { return } // Already grown
        let scalar: CGFloat = 1.25
        
        var transform: CGAffineTransform = .identity
        if shouldGrow {
            let translateY = -handle.bounds.height * (scalar - 1) / 2
            transform = CGAffineTransform(scaleX: scalar, y: scalar).translatedBy(x: 0, y: translateY)
        }
        
        UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.6, options: .curveEaseInOut, animations: {
            handle.transform = transform
        }, completion: nil)
    }
}

internal let defaultHandleColorPosition: UIColor = .white
internal let defaultHandleSize: CGSize = CGSize(width: 42, height: 52)
