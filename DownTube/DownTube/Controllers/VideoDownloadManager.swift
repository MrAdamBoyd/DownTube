//
//  VideoDownloadManager.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-11-02.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation

class VideoDownloadManager {
    let defaultSession = URLSession(configuration: URLSessionConfiguration.default)
    var dataTask: URLSessionDataTask?
    var activeDownloads: [String: Download] = [:]
    
    lazy var downloadsSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "bgSessionConfiguration")
        let session = URLSession(configuration: configuration, delegate: self.delegate, delegateQueue: nil)
        return session
    }()
    
    var delegate: URLSessionDelegate?
    
    init(delegate: URLSessionDelegate?) {
        self.delegate = delegate
        
        //Need to specifically init this because self has to be used in the argument, which isn't formed until here
        _ = self.downloadsSession
    }
    
    /**
     Starts download for video, called when track is added
     
     - parameter video:     Video object
     - parameter onSuccess: closure that is called immediately if the video is valid
     */
    func startDownload(_ video: Video, onSuccess completion: (Int) -> Void) {
        print("Starting download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, let url = URL(string: urlString), let index = self.videoIndexForStreamUrl(urlString) {
            let download = Download(url: urlString)
            download.downloadTask = self.downloadsSession.downloadTask(with: url)
            download.downloadTask?.resume()
            download.isDownloading = true
            self.activeDownloads[download.url] = download
            
            completion(index)
        }
    }
    
    /**
     Called when pause button for video is tapped
     
     - parameter video: Video object
     */
    func pauseDownload(_ video: Video) {
        print("Startind download")
        if let urlString = video.streamUrl, let download = self.activeDownloads[urlString] {
            if download.isDownloading {
                download.downloadTask?.cancel() { data in
                    if data != nil {
                        download.resumeData = data
                    }
                }
                download.isDownloading = false
            }
        }
    }
    
    /**
     Called when the cancel button for a video is tapped
     
     - parameter video: Video object
     */
    func cancelDownload(_ video: Video) {
        print("Canceling download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, let download = self.activeDownloads[urlString] {
            download.downloadTask?.cancel()
            self.activeDownloads[urlString] = nil
        }
        
    }
    
    /**
     Called when the resume button for a video is tapped
     
     - parameter video: Video object
     */
    func resumeDownload(_ video: Video) {
        print("Resuming download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, let download = self.activeDownloads[urlString] {
            if let resumeData = download.resumeData {
                download.downloadTask = self.downloadsSession.downloadTask(withResumeData: resumeData)
                download.downloadTask?.resume()
                download.isDownloading = true
            } else if let url = URL(string: download.url) {
                download.downloadTask = self.downloadsSession.downloadTask(with: url)
                download.downloadTask?.resume()
                download.isDownloading = true
            }
        }
    }
    
    /**
     Gets the index of the video for the current download in the fetched results controller
     
     - parameter url: youtube url for the video
     
     - returns: optional index
     */
    func videoIndexForYouTubeUrl(_ url: String) -> Int? {
        for (index, video) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerated() {
            if url == video.youtubeUrl {
                return index
            }
        }
        
        return nil
    }
    
    /**
     Gets the index of the video for the current download in the fetched results controller
     
     - parameter url: streaming URL for the video
     
     - returns: optional index
     */
    func videoIndexForStreamUrl(_ url: String) -> Int? {
        for (index, video) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerated() {
            if url == video.streamUrl {
                return index
            }
        }
        
        return nil
    }
    
    /**
     Gets the index of the video for the current download in the fetched results controller
     
     - parameter downloadTask: video that is currently downloading
     
     - returns: optional index
     */
    func videoIndexForDownloadTask(_ downloadTask: URLSessionDownloadTask) -> Int? {
        if let url = downloadTask.originalRequest?.url?.absoluteString {
            return self.videoIndexForStreamUrl(url)
        }
        
        return nil
    }
}
