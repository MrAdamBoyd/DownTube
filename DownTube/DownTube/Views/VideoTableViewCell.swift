//
//  VideoTableViewCell.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-06-05.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation
import UIKit

protocol VideoTableViewCellDelegate {
    func pauseTapped(cell: VideoTableViewCell)
    func resumeTapped(cell: VideoTableViewCell)
    func cancelTapped(cell: VideoTableViewCell)
}

class VideoTableViewCell: UITableViewCell {
    
    var delegate: VideoTableViewCellDelegate?
    
    @IBOutlet weak var videoNameLabel: UILabel!
    @IBOutlet weak var uploaderLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var watchedIndicator: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.watchedIndicator.layer.cornerRadius = 8
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.setWatchIndicatorState(.Unwatched)
    }
    
    /**
     Sets the watched indicator state
     
     - parameter state: state of the video
     */
    func setWatchIndicatorState(state: WatchState) {
        let maskLayer = CALayer()
        maskLayer.backgroundColor = UIColor.blackColor().CGColor
        switch state {
        case .Unwatched:
            maskLayer.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        case .PartiallyWatched:
            maskLayer.frame = CGRect(x: 0, y: 0, width: 8, height: 16)
        case .Watched:
            maskLayer.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        
        self.watchedIndicator.layer.mask = maskLayer
    }
    
    @IBAction func pauseOrResumeTapped(sender: AnyObject) {
        if self.pauseButton.titleLabel!.text == "Pause" {
            self.delegate?.pauseTapped(self)
        } else {
            self.delegate?.resumeTapped(self)
        }
    }

    @IBAction func cancelTapped(sender: AnyObject) {
        self.delegate?.cancelTapped(self)
    }
}
