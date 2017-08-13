//
//  Watchable.swift
//  DownTube
//
//  Created by Adam Boyd on 2017/7/4.
//  Copyright © 2017 Adam. All rights reserved.
//

import Foundation
import MediaPlayer

// MARK: - WatchState

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

// MARK: - Watchable

protocol Watchable {
    var userProgress: NSNumber? { get set }
    var title: String? { get set }
    var youtubeUrl: String? { get set }
}

extension Watchable {
    //Returns the watched state for the video
    var watchProgress: WatchState {
        get {
            guard let progress = self.userProgress else { return .watched }
            
            switch progress {
            case 0:     return .unwatched
            default:    return .partiallyWatched(progress)
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
    
    var nowPlayingInfo: [String: Any] {
        return [
            MPMediaItemPropertyTitle: self.title ?? "Unknown Title",
            MPMediaItemPropertyArtist: self.youtubeUrl ?? "Unknown URL",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: self.userProgress ?? NSNumber(value: 0)
        ]
    }
}
