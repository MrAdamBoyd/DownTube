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
    case Unwatched, PartiallyWatched(NSNumber), Watched
}

func == (lhs: WatchState, rhs: WatchState) -> Bool {
    switch lhs {
    case .Watched:
        switch rhs {
        case .Watched:                          return true
        default:                                return false
        }
        
    case.Unwatched:
        switch rhs {
        case .Unwatched:                        return true
        default:                                return false
        }
        
    case .PartiallyWatched(let lhsNumber):
        switch rhs {
        case .PartiallyWatched(let rhsNumber):  return lhsNumber == rhsNumber
        default:                                return false
        }
    }
}

class Video: NSManagedObject {
    
    //Returns the watched state for the video
    var watchProgress: WatchState {
        
        get {
            if self.userProgress == nil {
                return .Watched
            } else if self.userProgress == 0 {
                return .Unwatched
            } else {
                return .PartiallyWatched(self.userProgress!)
            }
        }
        
        set {
            switch newValue {
            case .Unwatched:                        self.userProgress = 0
            case .Watched:                          self.userProgress = nil
            case .PartiallyWatched(let number):     self.userProgress = number
            }
        }
        
    }
}


extension Video {

    @NSManaged var created: NSDate?
    @NSManaged var quality: NSNumber?
    @NSManaged var streamUrl: String?
    @NSManaged var title: String?
    @NSManaged var uploader: String?
    @NSManaged var youtubeUrl: String?
    @NSManaged var displayOrder: NSNumber?
    @NSManaged private var userProgress: NSNumber? //nil for done, 0 for unplayed, other for progress

}
