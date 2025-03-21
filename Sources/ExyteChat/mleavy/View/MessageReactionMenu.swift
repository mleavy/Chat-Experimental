//
//  MessageReactionMenu.swift
//  Chat
//
//  Created by Mike Leavy on 1/13/25.
//

import UIKit
import SwiftUI
import FloatingButton
import enum FloatingButton.Alignment

extension Notification.Name {
    public static let reactionTappedNotification = Notification.Name("com.mosey.vent.reactionTappedNotification")
    public static let reactionAddedNotification = Notification.Name("com.mosey.vent.reactionAddedNotification")
    public static let reactionRemovedNotification = Notification.Name("com.mosey.vent.reactionRemovedNotification")
}

public protocol MessageMenuAction: Equatable, CaseIterable {
    func title() -> String
    func icon() -> Image
}

public enum DefaultMessageMenuAction: MessageMenuAction {

    case reply
    case edit(saveClosure: (String)->Void)
    //mleavy
    case copy
    case reaction(String)

    public func title() -> String {
        switch self {
        case .reply:
            "Reply"
        case .edit:
            "Edit"
        case .copy:
            "Copy"
        case .reaction(_):
            ""
        }
    }

    public func icon() -> Image {
        switch self {
        case .reply:
            Image(.reply)
        case .edit:
            Image(.edit)
        case .copy:
            Image(systemName: "document.on.document")
        case .reaction(_):
            Image(.reply)
        }
    }

    public static func == (lhs: DefaultMessageMenuAction, rhs: DefaultMessageMenuAction) -> Bool {
        if case .reply = lhs, case .reply = rhs {
            return true
        }
        if case .edit(_) = lhs, case .edit(_) = rhs {
            return true
        }
        return false
    }

    public static var allCases: [DefaultMessageMenuAction] = [
        //mleavy
        //.reply, .edit(saveClosure: {_ in})
        .copy
    ]
}

struct MessageMenu<MainButton: View, ActionEnum: MessageMenuAction>: View {

    @Environment(\.chatTheme) private var theme

    @Binding var isShowingMenu: Bool
    @Binding var menuButtonsSize: CGSize
    var alignment: Alignment
    var isReactable: Bool
    var existingReaction: String?
    var leadingPadding: CGFloat
    var trailingPadding: CGFloat
    var onAction: (ActionEnum) -> ()
    var mainButton: () -> MainButton
    
    @State var reaction: String = ""
    
    // animation
    @State var lineWidth: CGFloat = 2
    @State var scale: CGFloat = 1
            
    var body: some View {
        if !isReactable {
            FloatingButton(
                mainButtonView: mainButton().allowsHitTesting(false),
                buttons: ActionEnum.allCases.map {
                    menuButton(title: $0.title(), icon: $0.icon(), action: $0)
                },
                isOpen: $isShowingMenu
            )
            .straight()
            //.mainZStackAlignment(.top)
            .initialOpacity(0)
            .direction(.top)
            .alignment(alignment)
            .spacing(2)
            .animation(.linear(duration: 0.2))
            .menuButtonsSize($menuButtonsSize)
        }
        else {
            FloatingButton(
                mainButtonView: mainButton().allowsHitTesting(false),
                buttons: [reactionButton(reactions: ["❤️", "👍", "💯", "😂", "‼️"],
                                         action: ActionEnum.allCases.first!)],
                
                isOpen: $isShowingMenu
            )
            .straight()
            //.mainZStackAlignment(.top)
            .initialOpacity(0)
            .direction(.top)
            .alignment(alignment)
            .spacing(2)
            .animation(.linear(duration: 0.2))
            .menuButtonsSize($menuButtonsSize)
        }
        
    }
        
    func menuButton(title: String, icon: Image, action: ActionEnum) -> some View {
        HStack(spacing: 0) {
            if alignment == .left {
                Color.clear.viewSize(leadingPadding)
            }

            ZStack {
                theme.colors.friendMessage
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .opacity(0.5)
                    .cornerRadius(12)
                HStack {
                    Text(title)
                        .foregroundColor(theme.colors.textLightContext)
                    Spacer()
                    icon
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
            }
            .frame(width: 208)
            .fixedSize()
            .onTapGesture {
                onAction(action)
            }

            if alignment == .right {
                Color.clear.viewSize(trailingPadding)
            }
        }
    }
    
    func reactionButton(reactions: [String],
                        action: ActionEnum) -> some View {
        HStack(spacing: 0) {
            if alignment == .left {
                Color.clear.viewSize(leadingPadding)
            }

            ZStack {
                    
                // Note: we have 2 of these HStacks so that we can apply corner radius
                // and drop shadow to the background without clipping
                // the animation that occurs when a reaction is selected
                HStack(spacing: 8) {
                    ForEach(reactions, id: \.self) { reaction in
                        
                        ReactionButon(reaction: reaction, existingReaction: existingReaction, onTap: {
                            //
                        })
                        .opacity(0)
                    }
                    
                    Button {
                        //
                    } label: {
                        action.icon()
                    }
                    .frame(width: 32, height: 32)
                    .scaleEffect(scale)
                    .animation(.easeIn, value: scale)
                    .opacity(0)
                    
                    
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(theme.extensions.reactionsBackgroundColor)
                .cornerRadius(56/2)
                .shadow(color: .black.opacity(0.1), radius: 7, x: 0, y: 0)
                .overlay(
                        RoundedRectangle(cornerRadius: 56/2)
                            .stroke(theme.extensions.reactionsBorderColor, lineWidth: 1))
                
                HStack(spacing: 8) {
                    ForEach(reactions, id: \.self) { reaction in
                        
                        ReactionButon(reaction: reaction, existingReaction: existingReaction, onTap: {
                            self.reaction = reaction

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                onAction(DefaultMessageMenuAction.reaction(reaction) as! ActionEnum)
                            }

                            withAnimation {
                                lineWidth = 0
                            }
                            scale = 0
                        })
                    }
                    
                    Button {
                        onAction(action)
                    } label: {
                        action.icon()
                    }
                    .frame(width: 32, height: 32)
                    .scaleEffect(scale)
                    .animation(.easeIn, value: scale)
                    
                    
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(.clear)
            }
            .frame(width: CGFloat((reactions.count * 32) + (reactions.count * 8)) + 32 + 8,
                   height: 56)
            .fixedSize()
            .onTapGesture {
                onAction(action)
            }

            if alignment == .right {
                Color.clear.viewSize(trailingPadding)
            }
        }
    }
}
 

