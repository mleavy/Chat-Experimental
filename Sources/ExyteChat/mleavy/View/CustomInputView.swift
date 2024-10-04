//
//  CustomInputView.swift
//  Chat
//
//  Created by Mike Leavy on 10/3/24.
//

import UIKit
import SwiftUI

class CustomInputView: UIView {

    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var leadingButton: UIButton!
    
    @IBOutlet weak var sendButton: UIButton!
    
    
    static func get() -> CustomInputView {
        let nib = UINib(nibName: "CustomInputView", bundle: Bundle.module)
        let view = nib.instantiate(withOwner: self).first as! CustomInputView
        return view
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        containerView.layer.cornerRadius = 22
    }
}

class CustomInputManager: NSObject, UITextViewDelegate {
    
    @ObservedObject var inputViewModel: InputViewModel
    let inputView: CustomInputView
    
    private static var shared: CustomInputManager?
    
    private var defaultInputHeight: CGFloat = .zero
    
    static func get(inputViewModel: InputViewModel, theme: ChatTheme) -> CustomInputManager {
        if let shared { return shared }
        shared = CustomInputManager(inputViewModel: inputViewModel, theme: theme)
        return shared!
    }
    
    private init(inputViewModel: InputViewModel, theme: ChatTheme) {
        self.inputViewModel = inputViewModel
        self.inputView = CustomInputView.get()
        super.init()
        self.inputView.textView.delegate = self
        bind()
        apply(theme)
        updateSendButtonState()
    }
    
    private func bind() {
        inputView.sendButton.addTarget(self, action: #selector(self.sendButtonTapped), for: .touchUpInside)
        inputView.leadingButton.addTarget(self, action: #selector(self.leadingButtonTapped), for: .touchUpInside)
    }
    
    private func apply(_ theme: ChatTheme) {
        self.inputView.containerView.backgroundColor = UIColor(theme.colors.inputLightContextBackground)
        
        let image: UIImage? = theme.images.inputView.arrowSend.render(scale: UIScreen.main.scale)
        self.inputView.leadingButton.setImage(image, for: .normal)
        self.inputView.sendButton.setImage(image, for: .normal)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        updateSendButtonState()
        
        if defaultInputHeight == .zero {
            textView.superview!.superview!.constraints.forEach { (constraint) in
                if constraint.firstAttribute == .height {
                    defaultInputHeight = constraint.constant
                }
            }
        }
        
        let size = CGSize(width: textView.frame.size.width, height: .infinity)
        let estimatedSize = textView.sizeThatFits(size)
        let newHeight = max(estimatedSize.height, defaultInputHeight)
        
        guard textView.contentSize.height < 100.0 else {
            textView.isScrollEnabled = true
            return
        }
        
        textView.isScrollEnabled = false
        
        textView.superview!.superview!.constraints.forEach { (constraint) in
            if constraint.firstAttribute == .height {
                constraint.constant = newHeight
            }
        }
    }
    
    private func updateSendButtonState() {
        inputView.sendButton.isEnabled = inputView.textView.text.count > 0
    }
        
    @objc private func sendButtonTapped() {
        guard inputView.textView.text != "" else { return }
        inputViewModel.text = inputView.textView.text
        inputViewModel.send()
        inputView.textView.text = ""
        textViewDidChange(inputView.textView)
    }
    
    @objc private func leadingButtonTapped() {
        inputViewModel.leadingButtonTapped()
    }
}

extension View {
    /// Usually you would pass  `@Environment(\.displayScale) var displayScale`
    @MainActor func render(scale displayScale: CGFloat = 1.0) -> UIImage? {
        let renderer = ImageRenderer(content: self)

        renderer.scale = displayScale
        
        return renderer.uiImage
    }
    
}
