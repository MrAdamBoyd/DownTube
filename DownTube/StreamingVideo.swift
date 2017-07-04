//
//  StreamingVideo.swift
//  
//
//  Created by Adam Boyd on 2017/7/4.
//
//

import Foundation
import CoreData

class StreamingVideo: NSManagedObject, Watchable {
    @nonobjc class func fetchRequest() -> NSFetchRequest<StreamingVideo> {
        return NSFetchRequest<StreamingVideo>(entityName: "StreamingVideo")
    }
    
    @NSManaged var streamUrl: String?
    @NSManaged var title: String?
    @NSManaged internal var userProgress: NSNumber?
    @NSManaged var youtubeUrl: String?
}
