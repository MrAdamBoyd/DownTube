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
