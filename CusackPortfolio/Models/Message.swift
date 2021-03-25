//
//  Message.swift
//  Cusack Portfolio
//
//  Created by Jason Cusack on 03/24/21.
//  Copyright © 2021 CuSoft, LLC. All rights reserved.
//

import Foundation

struct Message: Codable, Identifiable {
    let id = UUID()
    let username: String
    let value: String
    let timestamp: String
    let languageCode: String
    let translationLanguageCode: String
    let translatedValue: String
    
    var isFromLocalUser: Bool {
        username == User.local.name
    }
    var isTranslated: Bool {
        translatedValue.isEmpty == false
    }
}
