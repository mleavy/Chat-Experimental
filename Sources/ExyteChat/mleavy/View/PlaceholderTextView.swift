//
//  PlaceholderTextView.swift
//  Chat
//
//  Created by Mike Leavy on 10/5/24.
//

import UIKit

class PlaceholderTextView: UITextView {
    
    let placeholderColor: UIColor
    
    /// Resize the placeholder when the UITextView bounds change
    override open var bounds: CGRect {
        didSet {
            self.resizePlaceholder()
        }
    }
    
    override open var font: UIFont? {
        didSet {
            if let placeholderLabel = self.viewWithTag(100) as! UILabel? {
                placeholderLabel.font = font
                resizePlaceholder()
            }
        }
    }
    
    /// The UITextView placeholder text
    public var placeholder: String? {
        get {
            var placeholderText: String?
            
            if let placeholderLabel = self.viewWithTag(100) as? UILabel {
                placeholderText = placeholderLabel.text
            }
            
            return placeholderText
        }
        set {
            if let placeholderLabel = self.viewWithTag(100) as! UILabel? {
                placeholderLabel.text = newValue
                placeholderLabel.sizeToFit()
            } else {
                self.addPlaceholder(newValue!)
            }
        }
    }
    
    init(frame: CGRect, theme: ChatTheme) {
        self.placeholderColor = UIColor(theme.extensions.inputViewPlaceholderTextColor)
        super.init(frame: frame, textContainer: nil)
        
        placeholder = theme.extensions.inputViewPlaceholderText
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textChanged),
                                               name: UITextView.textDidChangeNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// When the UITextView did change, show or hide the label based on if the UITextView is empty or not
    ///
    /// - Parameter textView: The UITextView that got updated
    @objc func textChanged() {
        if let placeholderLabel = self.viewWithTag(100) as? UILabel {
            placeholderLabel.isHidden = !self.text.isEmpty
        }
    }
    
    /// Resize the placeholder UILabel to make sure it's in the same position as the UITextView text
    private func resizePlaceholder() {
        if let placeholderLabel = self.viewWithTag(100) as! UILabel? {
            placeholderLabel.sizeToFit()
            let labelX = self.textContainer.lineFragmentPadding
            let labelY = self.textContainerInset.top + self.contentInset.top
            let labelWidth = self.frame.width - (labelX * 2)
            let labelHeight = placeholderLabel.frame.height

            placeholderLabel.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
        }
    }
    
    /// Adds a placeholder UILabel to this UITextView
    private func addPlaceholder(_ placeholderText: String) {
        let placeholderLabel = UILabel()
        
        placeholderLabel.text = placeholderText
        placeholderLabel.sizeToFit()
        
        placeholderLabel.font = self.font
        placeholderLabel.textColor = placeholderColor
        placeholderLabel.tag = 100
        
        placeholderLabel.isHidden = !self.text.isEmpty
        
        self.addSubview(placeholderLabel)
        self.resizePlaceholder()
    }
    
}
