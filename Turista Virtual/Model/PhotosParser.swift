//
//  PhotosParser.swift
//  Turista Virtual
//
//  Created by Lucas Daniel on 29/01/19.
//  Copyright © 2019 Lucas Daniel. All rights reserved.
//

import Foundation

struct PhotosParser: Codable {
    let photos: Photos
}

struct Photos: Codable {
    let pages: Int
    let photo: [PhotoParser]
}

struct PhotoParser: Codable {
    
    let url: String?
    let title: String
    
    enum CodingKeys: String, CodingKey {
        //case url = "url_n"
        case url = "url_m"
        case title
    }
}
