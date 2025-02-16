//
//  Message.swift
//  Chat
//
//  Created by Alisa Mylnikova on 20.04.2022.
//

import SwiftUI

//mleavy = made this a class, observable
public class Message: Identifiable, ObservableObject {

    public enum Status: Equatable, Hashable {
        case sending
        case sent
        case read
        case error(DraftMessage)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .sending:
                return hasher.combine("sending")
            case .sent:
                return hasher.combine("sent")
            case .read:
                return hasher.combine("read")
            case .error:
                return hasher.combine("error")
            }
        }

        public static func == (lhs: Message.Status, rhs: Message.Status) -> Bool {
            switch (lhs, rhs) {
            case (.sending, .sending):
                return true
            case (.sent, .sent):
                return true
            case (.read, .read):
                return true
            case ( .error(_), .error(_)):
                return true
            default:
                return false
            }
        }
    }

    public var id: String
    public var user: User
    public var status: Status?
    public var createdAt: Date
    //mleavy: conditionally use messageBuilder
    public var usesMessageBuilder: Bool
    //mleavy: message appearance requires animation
    public var isAnimated: Bool

    public var text: String
    public var attachments: [Attachment]
    public var recording: Recording?
    public var replyMessage: ReplyMessage?

    public var triggerRedraw: UUID?
    
    //mleavy
    @Published public var reaction: String?
    public var isReactable: Bool = false
    
    //mleavy
    @Published public var isTyping: Bool {
        didSet {
            if !isTyping {
                print("stop typing")
            }
            else {
                print("start typing")
            }
        }
    }
    public var typingText: String = "        "
    
    public func startTyping() {
        self.isTyping = true
    }
    
    public func stopTyping(with responseMessage: Message) {
        self.createdAt = responseMessage.createdAt
        self.isTyping = false
        self.id = responseMessage.id
        self.isReactable = responseMessage.isReactable
        
        self.text = responseMessage.text
    }

    public init(id: String,
                user: User,
                status: Status? = nil,
                createdAt: Date = Date(),
                usesMessageBuilder: Bool = true, //mleavy: conditionally use messageBuilder
                text: String = "",
                reaction: String? = nil,
                attachments: [Attachment] = [],
                recording: Recording? = nil,
                replyMessage: ReplyMessage? = nil,
                isTyping: Bool = false,
                isAnimated: Bool = false,
                isReactionAnimated: Bool = false) {

        self.id = id
        self.user = user
        self.status = status
        self.createdAt = createdAt
        self.usesMessageBuilder = usesMessageBuilder //mleavy: conditionally use messageBuilder
        self.text = text
        self.reaction = reaction
        self.attachments = attachments
        self.recording = recording
        self.replyMessage = replyMessage
        self.isTyping = isTyping
        self.isAnimated = isAnimated
    }

    public static func makeMessage(
        id: String,
        user: User,
        status: Status? = nil,
        draft: DraftMessage) async -> Message {
            let attachments = await draft.medias.asyncCompactMap { media -> Attachment? in
                guard let thumbnailURL = await media.getThumbnailURL() else {
                    return nil
                }

                switch media.type {
                case .image:
                    return Attachment(id: UUID().uuidString, url: thumbnailURL, type: .image)
                case .video:
                    guard let fullURL = await media.getURL() else {
                        return nil
                    }
                    return Attachment(id: UUID().uuidString, thumbnail: thumbnailURL, full: fullURL, type: .video)
                }
            }

            return Message(id: id, user: user, status: status, createdAt: draft.createdAt, text: draft.text, attachments: attachments, recording: draft.recording, replyMessage: draft.replyMessage)
        }
}

extension Message {
    var time: String {
        DateFormatter.timeFormatter.string(from: createdAt)
    }
}

extension Message: Equatable {
    public static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id &&
        lhs.user == rhs.user &&
        lhs.status == rhs.status &&
        lhs.createdAt == rhs.createdAt &&
        lhs.text == rhs.text &&
        lhs.attachments == rhs.attachments &&
        lhs.recording == rhs.recording &&
        lhs.replyMessage == rhs.replyMessage
    }
}

//mleavy - no longer auto-hashable
extension Message: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct Recording: Codable, Hashable {
    public var duration: Double
    public var waveformSamples: [CGFloat]
    public var url: URL?

    public init(duration: Double = 0.0, waveformSamples: [CGFloat] = [], url: URL? = nil) {
        self.duration = duration
        self.waveformSamples = waveformSamples
        self.url = url
    }
}

public struct ReplyMessage: Codable, Identifiable, Hashable {
    public static func == (lhs: ReplyMessage, rhs: ReplyMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.user == rhs.user &&
        lhs.createdAt == rhs.createdAt &&
        lhs.text == rhs.text &&
        lhs.attachments == rhs.attachments &&
        lhs.recording == rhs.recording
    }

    public var id: String
    public var user: User
    public var createdAt: Date

    public var text: String
    public var attachments: [Attachment]
    public var recording: Recording?

    public init(id: String,
                user: User,
                createdAt: Date,
                text: String = "",
                attachments: [Attachment] = [],
                recording: Recording? = nil) {

        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.text = text
        self.attachments = attachments
        self.recording = recording
    }

    func toMessage() -> Message {
        Message(id: id, user: user, createdAt: createdAt, text: text, attachments: attachments, recording: recording)
    }
}

public extension Message {

    func toReplyMessage() -> ReplyMessage {
        ReplyMessage(id: id, user: user, createdAt: createdAt, text: text, attachments: attachments, recording: recording)
    }
}

extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
