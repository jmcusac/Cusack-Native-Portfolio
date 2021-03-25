//
//  User.swift
//  Cusack Portfolio
//
//  Created by Jason Cusack on 03/24/21.
//  Copyright © 2021 CuSoft, LLC. All rights reserved.
//

import UIKit

class User {
    static let local = User()
    
    let id = UUID()
    var name: String {
        UIDevice.current.name
    }
    
    private init() {
        
    }
}
