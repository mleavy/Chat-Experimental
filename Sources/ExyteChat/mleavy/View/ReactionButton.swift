//
//  ReactionButton.swift
//  Chat
//
//  Created by Mike Leavy on 2/13/25.
//

import SwiftUI
import Pow

struct ReactionButon: View {
    
    @Environment(\.chatTheme) private var theme
    
    var reaction: String
    var existingReaction: String?
    var onTap: () -> Void
    
    @State private var reacted: Bool = false
    @State private var scale: CGFloat = 1
    @State private var opacity: CGFloat = 1
    
    var body: some View {
        Button {
            
            if existingReaction != reaction {
                reacted = true
                scale = 1.5
            }
            else {
                scale = 0
            }
                        
            withAnimation(Animation.linear.delay(0.5)){
                opacity = 0
            }
            
            NotificationCenter.default.post(name: .reactionTappedNotification, object: reaction)
            onTap()
            
        } label: {
            Text(reaction)
                .font(.system(size: 20))
                .foregroundColor(theme.colors.textLightContext)
        }
        .frame(width: 32, height: 32)
        .opacity(opacity)
        .scaleEffect(scale)
        .animation(.easeIn, value: scale)
        .changeEffect(
            .spray(origin: UnitPoint(x: 0.25, y: 0.5)) {
                reactionImage(reaction)
            }, value: self.reacted)
        
        .onReceive(NotificationCenter.default.publisher(for: .reactionTappedNotification, object: nil)) { notification in
            if notification.object as? String != reaction {
                scale = 0
            }
        }
    }
    
    private func reactionImage(_ reaction: String) -> Image {
        if let uiImage = reaction.emojiToImage() {
            return Image(uiImage: uiImage)
        }
        else {
            return Image(systemName: "heart.fill")
        }
    }
}

extension String {
    fileprivate func emojiToImage() -> UIImage? {
        let nsString = (self as NSString)
        let font = UIFont.systemFont(ofSize: 24) // you can change your font size here
        let stringAttributes = [NSAttributedString.Key.font: font]
        let imageSize = nsString.size(withAttributes: stringAttributes)
 
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0) //  begin image context
        UIColor.clear.set() // clear background
        UIRectFill(CGRect(origin: CGPoint(), size: imageSize)) // set rect size
        nsString.draw(at: CGPoint.zero, withAttributes: stringAttributes) // draw text within rect
        let image = UIGraphicsGetImageFromCurrentImageContext() // create image from context
        UIGraphicsEndImageContext() //  end image context
 
        return image
    }
}
