//
//  MessageView.swift
//  Chat
//
//  Created by Alex.M on 23.05.2022.
//

import SwiftUI

struct MessageView: View {

    @Environment(\.chatTheme) private var theme

    @ObservedObject var viewModel: ChatViewModel

    //mleavy - we will observe typing changes
    @StateObject var message: Message
    let positionInUserGroup: PositionInUserGroup
    let chatType: ChatType
    let avatarSize: CGFloat
    let tapAvatarClosure: ChatView.TapAvatarClosure?
    let tapReactionClosure: ReactionTappedClosure?
    let messageUseMarkdown: Bool
    let isDisplayingMessageMenu: Bool
    let showMessageTimeView: Bool

    @State var avatarViewSize: CGSize = .zero
    @State var statusSize: CGSize = .zero
    @State var timeSize: CGSize = .zero
    
    @State var reactionScale: CGFloat = 0.0

    static let widthWithMedia: CGFloat = 204
    
    //mleavy: this fucking padding is some magic number bullshit;
    // I hate this POS library
    static let horizontalNoAvatarPadding: CGFloat = -4
    static let horizontalAvatarPadding: CGFloat = 10
    
    static let horizontalTextPadding: CGFloat = 12
    static let horizontalAttachmentPadding: CGFloat = 1 // for multiple attachments
    static let statusViewSize: CGFloat = 14
    static let horizontalStatusPadding: CGFloat = 8
    static let horizontalBubblePadding: CGFloat = 70

    var font: UIFont

    enum DateArrangement {
        case hstack, vstack, overlay
    }

    var additionalMediaInset: CGFloat {
        message.attachments.count > 1 ? MessageView.horizontalAttachmentPadding * 2 : 0
    }

    var dateArrangement: DateArrangement {
        let timeWidth = timeSize.width + 10
        let textPaddings = MessageView.horizontalTextPadding * 2
        let widthWithoutMedia = UIScreen.main.bounds.width
        - (message.user.isCurrentUser ? MessageView.horizontalNoAvatarPadding : avatarViewSize.width)
        - statusSize.width
        - MessageView.horizontalBubblePadding
        - textPaddings

        let maxWidth = message.attachments.isEmpty ? widthWithoutMedia : MessageView.widthWithMedia - textPaddings
        let finalWidth = message.text.width(withConstrainedWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)
        let lastLineWidth = message.text.lastLineWidth(labelWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)
        let numberOfLines = message.text.numberOfLines(labelWidth: maxWidth, font: font, messageUseMarkdown: messageUseMarkdown)

        if numberOfLines == 1, finalWidth + CGFloat(timeWidth) < maxWidth {
            return .hstack
        }
        if lastLineWidth + CGFloat(timeWidth) < finalWidth {
            return .overlay
        }
        return .vstack
    }

    var showAvatar: Bool {
        positionInUserGroup == .single
        || (chatType == .conversation && positionInUserGroup == .last)
        || (chatType == .comments && positionInUserGroup == .first)
    }

    var topPadding: CGFloat {
        if chatType == .comments { return 0 }
        return positionInUserGroup == .single || positionInUserGroup == .first ? 8 : 4
    }

    var bottomPadding: CGFloat {
        if chatType == .conversation { return 0 }
        return positionInUserGroup == .single || positionInUserGroup == .first ? 8 : 4
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !message.user.isCurrentUser {
                avatarView
            }

            VStack(alignment: message.user.isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isDisplayingMessageMenu, let reply = message.replyMessage?.toMessage() {
                    replyBubbleView(reply)
                        .opacity(0.5)
                        .padding(message.user.isCurrentUser ? .trailing : .leading, 10)
                        .overlay(alignment: message.user.isCurrentUser ? .trailing : .leading) {
                            Capsule()
                                .foregroundColor(theme.colors.buttonBackground)
                                .frame(width: 2)
                        }
                }
                bubbleView(message)
            }

            if message.user.isCurrentUser, let status = message.status {
                MessageStatusView(status: status) {
                    if case let .error(draft) = status {
                        viewModel.sendMessage(draft)
                    }
                }
                .sizeGetter($statusSize)
            }
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .padding(.trailing, message.user.isCurrentUser ? MessageView.horizontalNoAvatarPadding : 0)
        .padding(message.user.isCurrentUser ? .leading : .trailing, MessageView.horizontalBubblePadding)
        .frame(maxWidth: UIScreen.main.bounds.width, alignment: message.user.isCurrentUser ? .trailing : .leading)
    }

    @ViewBuilder
    func bubbleView(_ message: Message) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                //mleavy: support for "typing" indicator sort of thing
                if message.status == .sending && !message.user.isCurrentUser {
                    replyWaitingView()
                }
                else {
                    if !message.attachments.isEmpty {
                        attachmentsView(message)
                    }
                    
                    if !message.text.isEmpty {
                        textWithTimeView(message)
                            .font(Font(font))
                    }
                    
                    if let recording = message.recording {
                        VStack(alignment: .trailing, spacing: 8) {
                            recordingView(recording)
                            messageTimeView()
                                .padding(.bottom, 8)
                                .padding(.trailing, 12)
                        }
                    }
                }
            }
            .bubbleBackground(message, theme: theme)
            
            VStack {
                Spacer()
                Button(action: {
                    tapReactionClosure?(message, message.reaction)
                }) {
                    Text(message.reaction ?? "")
                        .font(.system(size: 13))
                        .frame(width: 24, height: 24)
                        .background(.white)
                        .foregroundColor(.black)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(theme.extensions.reactionsBorderColor, lineWidth: 2)
                        )
                }
                .offset(x: -12, y: 0)
                .scaleEffect(reactionScale)
                .onReceive(NotificationCenter.default.publisher(for: .reactionRemovedNotification, object: nil)) { notification in
                    guard let notificationMessage = notification.object as? Message, notificationMessage.id == message.id else { return }
                    withAnimation(.easeOut(duration: 0.5)) {
                        reactionScale = 0
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .reactionAddedNotification, object: nil)) { notification in
                    guard let notificationMessage = notification.object as? Message, notificationMessage.id == message.id else { return }
                    withAnimation(.easeOut(duration: 0.5)) {
                        reactionScale = 1.0
                    }
                }
            }
        }
    }

    @ViewBuilder
    func replyBubbleView(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(message.user.name)
                .fontWeight(.semibold)
                .padding(.horizontal, MessageView.horizontalTextPadding)

            if !message.attachments.isEmpty {
                attachmentsView(message)
                    .padding(.top, 4)
                    .padding(.bottom, message.text.isEmpty ? 0 : 4)
            }

            if !message.text.isEmpty {
                MessageTextView(text: message.text, messageUseMarkdown: messageUseMarkdown)
                    .padding(.horizontal, MessageView.horizontalTextPadding)
            }

            if let recording = message.recording {
                recordingView(recording)
            }
        }
        .font(.caption2)
        .padding(.vertical, 8)
        .frame(width: message.attachments.isEmpty ? nil : MessageView.widthWithMedia + additionalMediaInset)
        .bubbleBackground(message, theme: theme, isReply: true)
    }

    @ViewBuilder
    var avatarView: some View {
        Group {
            if showAvatar {
                AvatarView(url: message.user.avatarURL, avatarSize: avatarSize)
                    .contentShape(Circle())
                    .onTapGesture {
                        tapAvatarClosure?(message.user, message.id)
                    }
            } else {
                Color.clear.viewSize(avatarSize)
            }
        }
        .padding(.horizontal, MessageView.horizontalAvatarPadding)
        .sizeGetter($avatarViewSize)
    }

    @ViewBuilder
    func attachmentsView(_ message: Message) -> some View {
        AttachmentsGrid(attachments: message.attachments) {
            viewModel.presentAttachmentFullScreen($0)
        }
        .applyIf(message.attachments.count > 1) {
            $0
                .padding(.top, MessageView.horizontalAttachmentPadding)
                .padding(.horizontal, MessageView.horizontalAttachmentPadding)
        }
        .overlay(alignment: .bottomTrailing) {
            if message.text.isEmpty {
                messageTimeView(needsCapsule: true)
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    func textWithTimeView(_ message: Message) -> some View {
        let messageView = MessageTextView(text: message.text, messageUseMarkdown: messageUseMarkdown)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MessageView.horizontalTextPadding)
        
        //mleavy - and points below
        let typingMessageView = MessageTextView(text: message.typingText, messageUseMarkdown: messageUseMarkdown)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MessageView.horizontalTextPadding)
        
        let currentMessageView = message.isTyping ? typingMessageView : messageView

        let timeView = messageTimeView()
            .padding(.trailing, 12)

        ZStack {
            Group {
                //mleavy - typing
                switch dateArrangement {
                case .hstack:
                    HStack(alignment: .lastTextBaseline, spacing: 12) {
                        currentMessageView
                        if !message.attachments.isEmpty {
                            Spacer()
                        }
                        timeView
                    }
                    .padding(.vertical, 8)
                case .vstack:
                    VStack(alignment: .leading, spacing: 4) {
                        currentMessageView
                        HStack(spacing: 0) {
                            Spacer()
                            timeView
                        }
                    }
                    .padding(.vertical, 8)
                case .overlay:
                    currentMessageView
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottomTrailing) {
                            timeView
                                .padding(.vertical, 8)
                        }
                }
            }
            
            if message.isTyping {
                MessageActivityView()
            }
            
        }
    }

    @ViewBuilder
    func recordingView(_ recording: Recording) -> some View {
        RecordWaveformWithButtons(
            recording: recording,
            colorButton: message.user.isCurrentUser ? theme.colors.myMessage : .white,
            colorButtonBg: message.user.isCurrentUser ? .white : theme.colors.myMessage,
            colorWaveform: message.user.isCurrentUser ? theme.colors.textDarkContext : theme.colors.textLightContext
        )
        .padding(.horizontal, MessageView.horizontalTextPadding)
        .padding(.top, 8)
    }

    func messageTimeView(needsCapsule: Bool = false) -> some View {
        Group {
            if showMessageTimeView {
                if needsCapsule {
                    MessageTimeWithCapsuleView(text: message.time, isCurrentUser: message.user.isCurrentUser, chatTheme: theme)
                } else {
                    MessageTimeView(text: message.time, isCurrentUser: message.user.isCurrentUser, chatTheme: theme)
                }
            }
        }
        .sizeGetter($timeSize)
    }
}

extension View {

    @ViewBuilder
    func bubbleBackground(_ message: Message, theme: ChatTheme, isReply: Bool = false) -> some View {
        //mleavy
        //let radius: CGFloat = !message.attachments.isEmpty ? 12 : 20
        let cornerRadii = message.attachments.isEmpty ?
            (message.user.isCurrentUser ?
             theme.extensions.myMessageCornerRadii : theme.extensions.friendMessageCornerRadii) :
            (message.user.isCurrentUser ?
             theme.extensions.myAttachmentMessageCornerRadii : theme.extensions.friendAttachmentMessageCornerRadii)
        
        
        
        let additionalMediaInset: CGFloat = message.attachments.count > 1 ? 2 : 0
        self
            .frame(width: message.attachments.isEmpty ? nil : MessageView.widthWithMedia + additionalMediaInset)
            .foregroundColor(message.user.isCurrentUser ? theme.colors.textDarkContext : theme.colors.textLightContext)
            .background {
                if isReply || !message.text.isEmpty || message.recording != nil {
                    //mleavy
                    //RoundedRectangle(cornerRadius: radius)
                    UnevenRoundedRectangle(cornerRadii: cornerRadii)
                        .foregroundColor(message.user.isCurrentUser ? theme.colors.myMessage : theme.colors.friendMessage)
                        .opacity(isReply ? 0.5 : 1)
                }
            }
            //mleavy
            //.cornerRadius(radius)
            .clipShape(
                .rect(
                    topLeadingRadius: cornerRadii.topLeading,
                    bottomLeadingRadius: cornerRadii.bottomLeading,
                    bottomTrailingRadius: cornerRadii.bottomTrailing,
                    topTrailingRadius: cornerRadii.topTrailing
                )
            )
    }
}

#if DEBUG
struct MessageView_Preview: PreviewProvider {
    static let stan = User(id: "stan", name: "Stan", avatarURL: nil, isCurrentUser: false)
    static let john = User(id: "john", name: "John", avatarURL: nil, isCurrentUser: true)

    static private var shortMessage = "Hi, buddy!"
    static private var longMessage = "Hello hello hello hello hello hello hello hello hello hello hello hello hello\n hello hello hello hello d d d d d d d d"

    static private var replyedMessage = Message(
        id: UUID().uuidString,
        user: stan,
        status: .read,
        text: longMessage,
        attachments: [
            Attachment.randomImage(),
            Attachment.randomImage(),
            Attachment.randomImage(),
            Attachment.randomImage(),
            Attachment.randomImage(),
        ]
    )

    static private var message = Message(
        id: UUID().uuidString,
        user: stan,
        status: .read,
        text: shortMessage,
        replyMessage: replyedMessage.toReplyMessage()
    )

    static var previews: some View {
        ZStack {
            Color.yellow.ignoresSafeArea()

            MessageView(
                viewModel: ChatViewModel(),
                message: replyedMessage,
                positionInUserGroup: .single,
                chatType: .conversation,
                avatarSize: 32,
                tapAvatarClosure: nil,
                tapReactionClosure: nil,
                messageUseMarkdown: false,
                isDisplayingMessageMenu: false,
                showMessageTimeView: true,
                font: UIFontMetrics.default.scaledFont(for: UIFont.systemFont(ofSize: 15))
            )
        }
    }
}
#endif
