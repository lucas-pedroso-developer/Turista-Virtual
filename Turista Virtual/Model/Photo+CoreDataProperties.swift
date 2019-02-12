//
//  Photo+CoreDataProperties.swift
//  Turista Virtual
//
//  Created by Lucas Daniel on 29/01/19.
//  Copyright © 2019 Lucas Daniel. All rights reserved.
//

import Foundation
import CoreData

extension Photo {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }
    
    @NSManaged public var image: NSData?
    @NSManaged public var title: String?
    @NSManaged public var url_m: String?
    @NSManaged public var pin: Pin?
    
}

