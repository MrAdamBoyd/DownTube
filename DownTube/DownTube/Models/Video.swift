//
//  Video.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-07-05.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation
import CoreData

enum WatchState: Equatable {
    case unwatched, partiallyWatched(NSNumber), watched
}

func == (lhs: WatchState, rhs: WatchState) -> Bool {
    switch lhs {
    case .watched:
        switch rhs {
        case .watched:                          return true
        default:                                return false
        }
        
    case.unwatched:
        switch rhs {
        case .unwatched:                        return true
        default:                                return false
        }
        
    case .partiallyWatched(let lhsNumber):
        switch rhs {
        case .partiallyWatched(let rhsNumber):  return lhsNumber == rhsNumber
        default:                                return false
        }
    }
}

class Video: NSManagedObject {
    
    //Returns the watched state for the video
    var watchProgress: WatchState {
        
        get {
            if self.userProgress == nil {
                return .watched
            } else if self.userProgress == 0 {
                return .unwatched
            } else {
                return .partiallyWatched(self.userProgress!)
            }
        }
        
        set {
            switch newValue {
            case .unwatched:                        self.userProgress = 0
            case .watched:                          self.userProgress = nil
            case .partiallyWatched(let number):     self.userProgress = number
            }
        }
        
    }
}


extension Video {

    @NSManaged var created: Date?
    @NSManaged var quality: NSNumber?
    @NSManaged var streamUrl: String?
    @NSManaged var title: String?
    @NSManaged var uploader: String?
    @NSManaged var youtubeUrl: String?
    @NSManaged var displayOrder: NSNumber?
    @NSManaged fileprivate var userProgress: NSNumber? //nil for done, 0 for unplayed, other for progress

}
