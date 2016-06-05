//
//  VideoCell.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-06-05.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation
import UIKit

protocol VideoCellDelegate {
    func pauseTapped(cell: VideoCell)
    func resumeTapped(cell: VideoCell)
    func cancelTapped(cell: VideoCell)
}

class VideoCell: UITableViewCell {
    
    var delegate: VideoCellDelegate?
    
    @IBOutlet weak var videoNameLabel: UILabel!
    @IBOutlet weak var uploaderLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    @IBAction func pauseOrResumeTapped(sender: AnyObject) {
        if(self.pauseButton.titleLabel!.text == "Pause") {
            self.delegate?.pauseTapped(self)
        } else {
            self.delegate?.resumeTapped(self)
        }
    }
    
    @IBAction func cancelTapped(sender: AnyObject) {
        self.delegate?.cancelTapped(self)
    }
}
