//
//  VideoTableViewCell.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-06-05.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation
import UIKit

protocol VideoTableViewCellDelegate: class {
    func pauseTapped(_ cell: VideoTableViewCell)
    func resumeTapped(_ cell: VideoTableViewCell)
    func cancelTapped(_ cell: VideoTableViewCell)
}

class VideoTableViewCell: UITableViewCell {
    
    weak var delegate: VideoTableViewCellDelegate?
    
    @IBOutlet weak var videoNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
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
        
        self.setWatchIndicatorState(.unwatched)
    }
    
    /**
     Sets the watched indicator state
     
     - parameter state: state of the video
     */
    func setWatchIndicatorState(_ state: WatchState) {
        let maskLayer = CALayer()
        maskLayer.backgroundColor = UIColor.black.cgColor
        switch state {
        case .unwatched:
            maskLayer.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        case .partiallyWatched:
            maskLayer.frame = CGRect(x: 0, y: 0, width: 8, height: 16)
        case .watched:
            maskLayer.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        
        self.watchedIndicator.layer.mask = maskLayer
    }
    
    @IBAction func pauseOrResumeTapped(_ sender: AnyObject) {
        if self.pauseButton.titleLabel!.text == "Pause" {
            self.delegate?.pauseTapped(self)
        } else {
            self.delegate?.resumeTapped(self)
        }
    }

    @IBAction func cancelTapped(_ sender: AnyObject) {
        self.delegate?.cancelTapped(self)
    }
}
