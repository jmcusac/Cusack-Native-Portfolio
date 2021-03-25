//
//  MessageView.swift
//  Cusack Portfolio
//
//  Created by Jason Cusack on 03/24/21.
//  Copyright © 2021 CuSoft, LLC. All rights reserved.
//

import SwiftUI

struct MessageView: View {
    let message: Message
    @Binding var isTranslating: Bool
    
    var body: some View {
        VStack {
            Text(self.caption(for: message))
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundColor(.gray)
                .onTapGesture {
                    if self.isTranslating,
                        self.message.isTranslated {
                        let url = URL(string: "https://translate.google.com")!
                        UIApplication.shared.open(url)
                    }
            }
            
            HStack {
                if message.isFromLocalUser {
                    Spacer()
                }
                
                Text(self.text(for: message))
                    .foregroundColor(.white)
                    .font(.body)
                    .padding()
                    .background(message.isFromLocalUser ? Color.blue : Color.gray)
                    .cornerRadius(20)
                    .padding(.leading, message.isFromLocalUser ? 20 : 8)
                    .padding(.trailing, message.isFromLocalUser ? 8 : 20)
                    .padding(.vertical, 5)
                
                if message.isFromLocalUser == false {
                    Spacer()
                }
            }
        }
    }
    
    private func text(for message: Message) -> String {
        isTranslating && message.translatedValue.isEmpty == false ? message.translatedValue : message.value
    }
    
    private func caption(for message: Message) -> String {
        var caption = ""
        
        switch (message.isFromLocalUser, isTranslating) {
        case (true, _):
            caption = message.timestamp
        case (_, true) where message.isTranslated:
            caption = "\nTranslation by Google"
            fallthrough
        default:
            caption = "\(message.username) — \(message.timestamp)" + caption
        }
        
        return caption
    }
}
