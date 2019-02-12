//
//  Photo.swift
//  Turista Virtual
//
//  Created by Lucas Daniel on 29/01/19.
//  Copyright © 2019 Lucas Daniel. All rights reserved.
//

import Foundation
import CoreData

@objc(Photo)
public class Photo: NSManagedObject {
    
    static let name = "Photo"
    
    convenience init(title: String, url_m: String, forPin: Pin, context: NSManagedObjectContext) {
        if let ent = NSEntityDescription.entity(forEntityName: Photo.name, in: context) {
            self.init(entity: ent, insertInto: context)
            self.title = title
            self.image = nil
            self.url_m = url_m
            self.pin = forPin
        } else {
            fatalError("Unable to find Entity name!")
        }
    }
    
}
