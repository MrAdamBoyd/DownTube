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
    func playerViewController(_ playerViewController: DownTubePlayerViewController, requestsToOpenVideoUrlInYouTube urlString: String)
    func viewControllerChangedVideoStatus(for video: Watchable?)
}

/// Custom AVPlayerViewController. Has custom 3d touch actions hides the home indicator on iPhone X
class DownTubePlayerViewController: AVPlayerViewController {
    var currentlyPlaying: Watchable?
    weak var actionItemsDelegate: DownTubePlayerViewControllerDelegate?
    
    //These are the items that are actions for the peek 3d touch
    override var previewActionItems: [UIPreviewActionItem] {
        guard var video = self.currentlyPlaying else { return [] }
        
        var actions: [UIPreviewAction] = []
        
        if let youtubeUrl = video.youtubeUrl {
            actions.append(UIPreviewAction(title: "Open in YouTube", style: .default) { [unowned self] _, _ in
                self.actionItemsDelegate?.playerViewController(self, requestsToOpenVideoUrlInYouTube: youtubeUrl)
            })
        }
        
        //If the user progress isn't nil, that means that the video is unwatched or partially watched
        if video.watchProgress != .watched {
            actions.append(UIPreviewAction(title: "Mark as Watched", style: .default) { [unowned self] _, _ in
                video.watchProgress = .watched
                PersistentVideoStore.shared.save()
                self.actionItemsDelegate?.viewControllerChangedVideoStatus(for: video)
            })
        }
        
        //If the user progress isn't 0, the video is either partially watched or done
        if video.watchProgress != .unwatched {
            actions.append(UIPreviewAction(title: "Mark as Unwatched", style: .default) { [unowned self] _, _ in
                video.watchProgress = .unwatched
                PersistentVideoStore.shared.save()
                self.actionItemsDelegate?.viewControllerChangedVideoStatus(for: video)
            })
        }
        
        return actions
    }
    
    /// If true, the home indicator is automatically hidden a few seconds after the user last touches the screen
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return true
    }
}
