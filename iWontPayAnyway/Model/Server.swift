//
//  Server.swift
//  iWontPayAnyway
//
//  Created by Max Tharr on 21.01.20.
//  Copyright © 2020 Mayflower GmbH. All rights reserved.
//

import Foundation

class Server: Codable {
    let name: String
    let url: String
    var projects: [Project]
    
    init(name: String, url: String, projects: [Project]) {
        self.name = name
        self.url = url
        self.projects = projects
    }
}
