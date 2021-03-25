//
//  TranslationResponse.swift
//  Cusack Portfolio
//
//  Created by Jason Cusack on 03/24/21.
//  Copyright © 2021 CuSoft, LLC. All rights reserved.
//

import Foundation

struct TranslationResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case languageCode = "lang", translations = "text"
    }
    
    let languageCode: String
    let translations: [String]
}
