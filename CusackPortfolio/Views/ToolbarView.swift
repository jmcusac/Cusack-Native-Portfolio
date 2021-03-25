//
//  ToolbarView.swift
//  Cusack Portfolio
//
//  Created by Jason Cusack on 03/24/21.
//  Copyright © 2021 CuSoft, LLC. All rights reserved.
//

import SwiftUI

struct ToolbarView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    @Binding var showActionSheet: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                self.showActionSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
            }
            .padding(.horizontal, 8)
            
            TextField(viewModel.appState.notConnected ? "\(viewModel.appState.rawValue)" : "Add message",
                      text: $viewModel.newMessageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(viewModel.appState.notConnected)
            
            Button(action: {
                self.viewModel.clear()
            }) {
                Image(systemName: "xmark.circle")
            }
            .disabled(viewModel.newMessageTextIsEmpty)
            
            Button(action: {
                self.viewModel.send()
            }) {
                Image(systemName: "paperplane")
            }
            .disabled(viewModel.newMessageTextIsEmpty)
                .padding(.horizontal, 8)
        }
    }
}

struct ToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        ToolbarView(showActionSheet: .constant(false))
            .environmentObject(ChatViewModel())
            .previewLayout(.sizeThatFits)
    }
}
