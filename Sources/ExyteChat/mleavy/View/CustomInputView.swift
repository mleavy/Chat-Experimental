//
//  CustomInputView.swift
//  Chat
//
//  Created by Mike Leavy on 10/3/24.
//

import UIKit
import SwiftUI

class CustomInputView: UIView {
    
    var containerView: UIView!
    var textView: UITextView!
    var leadingButton: UIButton!
    var sendButton: UIButton!
    
    init(frame: CGRect,
         font: UIFont,
         theme: ChatTheme) {
        super.init(frame: frame)
        setup(theme, font: font)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(_ theme: ChatTheme, font: UIFont) {
        
        containerView = UIView(frame: .zero)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            containerView.topAnchor.constraint(equalTo: self.topAnchor)
        ])
        
        
        leadingButton = UIButton(frame: .zero)
        leadingButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(leadingButton)
        
        let buttonBottomConstraint = -(floor((theme.extensions.inputViewDefaultHeight / 2) - (theme.extensions.buttonSize.height / 2)))
        
        NSLayoutConstraint.activate([
            leadingButton.heightAnchor.constraint(equalToConstant: theme.extensions.buttonSize.height),
            leadingButton.widthAnchor.constraint(equalToConstant: .init(theme.extensions.buttonSize.width)),
            leadingButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: theme.extensions.buttonToFramePadding),
            leadingButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: buttonBottomConstraint)
        ])
        
        
        sendButton = UIButton(frame: .zero)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sendButton)
        
        NSLayoutConstraint.activate([
            sendButton.heightAnchor.constraint(equalToConstant: theme.extensions.buttonSize.height),
            sendButton.widthAnchor.constraint(equalToConstant: .init(theme.extensions.buttonSize.width)),
            sendButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -theme.extensions.buttonToFramePadding),
            sendButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: buttonBottomConstraint)
        ])
        
        
        textView = PlaceholderTextView(frame: .zero, theme: theme)
        textView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingButton.trailingAnchor, constant: theme.extensions.buttonToTextViewPadding),
            textView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -theme.extensions.buttonToTextViewPadding),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            textView.topAnchor.constraint(equalTo: containerView.topAnchor)
        ])
        
        textView.font = font
        textView.backgroundColor = UIColor(theme.colors.inputLightContextBackground)
        
        let sendImage: UIImage? = theme.images.inputView.arrowSend.render(scale: UIScreen.main.scale)
        let leadingImage: UIImage? = theme.extensions.leadingButtonImage.render(scale: UIScreen.main.scale)
        
        leadingButton.setImage(leadingImage, for: .normal)
        sendButton.setImage(sendImage, for: .normal)
        
        containerView.backgroundColor = UIColor(theme.colors.inputLightContextBackground)
        containerView.layer.cornerRadius = theme.extensions.inputViewDefaultHeight / 2
    }
}

class CustomInputManager: NSObject, UITextViewDelegate {
    
    @ObservedObject var inputViewModel: InputViewModel
    let inputView: CustomInputView
    
    private static var shared: CustomInputManager?
    
    private var defaultInputHeight: CGFloat = .zero
    
    static func get(inputViewModel: InputViewModel,
                    font: UIFont,
                    theme: ChatTheme) -> CustomInputManager {
        if let shared { return shared }
        shared = CustomInputManager(inputViewModel: inputViewModel,
                                    font: font,
                                    theme: theme)
        return shared!
    }
    
    private init(inputViewModel: InputViewModel,
                 font: UIFont,
                 theme: ChatTheme) {
        self.inputViewModel = inputViewModel
        self.inputView = CustomInputView(frame: .zero, font: font, theme: theme)
        super.init()
        self.inputView.textView.delegate = self
        bind()
        updateSendButtonState()
    }
    
    private func bind() {
        inputView.sendButton.addTarget(self, action: #selector(self.sendButtonTapped), for: .touchUpInside)
        inputView.leadingButton.addTarget(self, action: #selector(self.leadingButtonTapped), for: .touchUpInside)
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
