//
//  ChatScrollView.swift
//  Cusack Portfolio
//
//  Created by Jason Cusack on 03/24/21.
//  Copyright © 2021 CuSoft, LLC. All rights reserved.
//

import SwiftUI

struct ChatScrollView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(viewModel.messages) {
                    MessageView(message: $0, isTranslating: self.$viewModel.isTranslating)
                }
            }
        }
    }
}

struct ChatScrollView_Previews: PreviewProvider {
    static var previews: some View {
        ChatScrollView()
            .environmentObject(ChatViewModel())
    }
}
