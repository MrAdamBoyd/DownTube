//
//  DownTubePlayerViewController.swift
//  DownTube
//
//  Created by Adam on 10/3/17.
//  Copyright © 2017 Adam. All rights reserved.
//

import Foundation
import UIKit
import AVKit

protocol DownTubePlayerViewControllerDelegate: class {
    func viewControllerChangedVideoStatus(for video: Watchable?)
}

// Yes I know AVPlayerViewController isn't meant to be subclassed, but no methods are overridden here, just the preview action items for 3d touch
class DownTubePlayerViewController: AVPlayerViewController {
    var currentlyPlaying: Watchable?
    weak var actionItemsDelegate: DownTubePlayerViewControllerDelegate?
    
    //These are the items that are actions for the peek 3d touch
    override var previewActionItems: [UIPreviewActionItem] {
        guard var video = self.currentlyPlaying else { return [] }
        
        var actions: [UIPreviewAction] = []
        
        //If the user progress isn't nil, that means that the video is unwatched or partially watched
        if video.watchProgress != .watched {
            actions.append(UIPreviewAction(title: "Mark as Watched", style: .default) { [unowned self] _, _ in
                video.watchProgress = .watched
                CoreDataController.sharedController.saveContext()
                self.actionItemsDelegate?.viewControllerChangedVideoStatus(for: video)
            })
        }
        
        //If the user progress isn't 0, the video is either partially watched or done
        if video.watchProgress != .unwatched {
            actions.append(UIPreviewAction(title: "Mark as Unwatched", style: .default) { [unowned self] _, _ in
                video.watchProgress = .unwatched
                CoreDataController.sharedController.saveContext()
                self.actionItemsDelegate?.viewControllerChangedVideoStatus(for: video)
            })
        }
        return actions
    }
}
