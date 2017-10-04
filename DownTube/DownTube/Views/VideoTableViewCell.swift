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
        self.delegate = nil
    }
    
    ///Properly sets up the cell
    func setUp(with video: Video, download: Download?, isDownloaded: Bool, delegate: VideoTableViewCellDelegate?) {
        
        //Setting up date and name labels
        let components = (Calendar.current as NSCalendar).components([.day, .month, .year], from: video.created! as Date)
        
        self.videoNameLabel.text = video.title
        
        var labelText = "Downloaded"
        if let year = components.year, let month = components.month, let day = components.day {
            labelText += " on \(year)/\(month)/\(day)"
        }
        self.dateLabel.text = labelText
        
        //Setting up showing the cell if downloading or not
        self.setWatchIndicatorState(video.watchProgress)
        
        //Only show the download controls if video is currently downloading
        var showDownloadControls = false
        if let download = download {
            showDownloadControls = true
            self.progressView.progress = download.progress
            self.progressLabel.text = (download.isDownloading) ? "Downloading..." : "Paused"
            let title = (download.isDownloading) ? "Pause" : "Resume"
            self.pauseButton.setTitle(title, for: UIControlState())
        }
        self.progressView.isHidden = !showDownloadControls
        self.progressLabel.isHidden = !showDownloadControls
        
        //Hiding or showing the download button
        self.selectionStyle = isDownloaded ? .gray : .none
        
        //Hiding or showing the cancel and pause buttons
        self.pauseButton.isHidden = !showDownloadControls
        self.cancelButton.isHidden = !showDownloadControls
    }
    
    /// Updates the download progress, hides and shows the controls
    func updateProgress(for download: Download, totalSize: String) {
        self.progressView.isHidden = download.isDone
        self.progressLabel.isHidden = download.isDone
        self.progressView.progress = download.progress
        self.progressLabel.text = String(format: "%.1f%% of %@", download.progress * 100, totalSize)
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
