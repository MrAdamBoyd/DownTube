//
//  Download.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-06-05.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation

enum DownloadState {
    case downloading, paused, enqueued
    
    var titleForCell: String {
        switch self {
        case .downloading:      return "Downloading..."
        case .paused:           return "Paused"
        case .enqueued:         return "Waiting"
        }
    }
    
    var pauseButtonTitle: String {
        switch self {
        case .downloading:      return "Pause"
        case .paused:           return "Resume"
        case .enqueued:         return ""
        }
    }
}

class Download: NSObject {
    var url: String
    var state: DownloadState = .enqueued
    var progress: Float = 0.0
    
    var downloadTask: URLSessionDownloadTask?
    var resumeData: Data?
    
    init(url: String) {
        self.url = url
    }
    
    var isDone: Bool {
        return self.progress >= 1
    }
}
