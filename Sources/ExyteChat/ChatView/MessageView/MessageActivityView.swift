//
//  MessageActivityView.swift
//  Chat
//
//  Created by Mike Leavy on 9/21/24.
//

import SwiftUI
import ActivityIndicatorView

struct MessageActivityView: View {
    @State private var showActivity = true
    
    var body: some View {
        activityView()
    }

    @ViewBuilder
    private func activityView() -> some View {
        ActivityIndicatorView(isVisible: $showActivity, type: .opacityDots(count: 3, inset: 4))
            .frame(width: 40, height: 30, alignment: .center)
    }
}

@ViewBuilder
func replyWaitingView() -> some View {
    let messageView = MessageActivityView()
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, MessageView.horizontalTextPadding)

    messageView
}
