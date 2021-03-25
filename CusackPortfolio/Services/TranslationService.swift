//
//  TranslationService.swift
//  Cusack Portfolio
//
//  Created by Jason Cusack on 03/24/21.
//  Copyright © 2021 CuSoft, LLC. All rights reserved.
//

import Foundation
import Combine

struct TranslationService {
    private let apiKey = ""
    
    func publisher(for message: Message, to languageCode: String) -> AnyPublisher<Data, URLError> {
        URLSession.shared.dataTaskPublisher(for: url(for: message, languageCode: languageCode))
            .map(\.data)
            .eraseToAnyPublisher()
    }
    
    private func url(for message: Message, languageCode: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "translate.google.com"
        components.path = ""//api key
        components.setQueryItems(with: ["key": apiKey, "text": message.value, "lang": languageCode])
        return components.url!
    }
}

extension URLComponents {
    mutating func setQueryItems(with parameters: [String: String]) {
        self.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
}
