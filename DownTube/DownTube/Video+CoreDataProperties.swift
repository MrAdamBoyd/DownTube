//
//  Video+CoreDataProperties.swift
//  
//
//  Created by Adam Boyd on 2016-05-30.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Video {

    @NSManaged var title: String?
    @NSManaged var quality: NSNumber?
    @NSManaged var uploader: String?
    @NSManaged var created: NSDate?
    @NSManaged var streamUrl: String?
    @NSManaged var youtubeUrl: String?

}
