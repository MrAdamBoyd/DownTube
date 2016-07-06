//
//  Video+CoreDataProperties.swift
//  
//
//  Created by Adam Boyd on 2016-07-05.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Video {

    @NSManaged var created: NSDate?
    @NSManaged var quality: NSNumber?
    @NSManaged var streamUrl: String?
    @NSManaged var title: String?
    @NSManaged var uploader: String?
    @NSManaged var youtubeUrl: String?
    @NSManaged var displayOrder: NSNumber?
    @NSManaged var userProgress: NSNumber? //nil for done, 0 for unplayed, other for progress

}
