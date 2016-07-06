//
//  Video.swift
//  
//
//  Created by Adam Boyd on 2016-05-30.
//
//

import Foundation
import CoreData

enum WatchState {
    case Unwatched, PartiallyWatched, Watched
}

class Video: NSManagedObject {
    
    //Returns the watched state for the video
    var stateForVideoProgress: WatchState {
        
        if self.userProgress == nil {
            return .Watched
        } else if self.userProgress == 0 {
            return .Unwatched
        } else {
            return .PartiallyWatched
        }
        
    }
    
}
