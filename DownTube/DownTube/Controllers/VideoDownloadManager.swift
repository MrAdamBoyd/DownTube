//
//  VideoDownloadManager.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-11-02.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation

class VideoDownloadManager {
    let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    var dataTask: NSURLSessionDataTask?
    var activeDownloads: [String: Download] = [:]
    
    lazy var downloadsSession: NSURLSession = {
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("bgSessionConfiguration")
        let session = NSURLSession(configuration: configuration, delegate: self.delegate, delegateQueue: nil)
        return session
    }()
    
    var delegate: NSURLSessionDelegate?
    
    init(delegate: NSURLSessionDelegate?) {
        self.delegate = delegate
        
        //Need to specifically init this because self has to be used in the argument, which isn't formed until here
        _ = self.downloadsSession
    }
    
    /**
     Starts download for video, called when track is added
     
     - parameter video:     Video object
     - parameter onSuccess: closure that is called immediately if the video is valid
     */
    func startDownload(video: Video, @noescape onSuccess completion: (Int) -> Void) {
        print("Starting download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, url = NSURL(string: urlString), index = self.videoIndexForStreamUrl(urlString) {
            let download = Download(url: urlString)
            download.downloadTask = self.downloadsSession.downloadTaskWithURL(url)
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
    func pauseDownload(video: Video) {
        print("Startind download")
        if let urlString = video.streamUrl, download = self.activeDownloads[urlString] {
            if download.isDownloading {
                download.downloadTask?.cancelByProducingResumeData() { data in
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
    func cancelDownload(video: Video) {
        print("Canceling download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, download = self.activeDownloads[urlString] {
            download.downloadTask?.cancel()
            self.activeDownloads[urlString] = nil
        }
        
        
    }
    
    /**
     Called when the resume button for a video is tapped
     
     - parameter video: Video object
     */
    func resumeDownload(video: Video) {
        print("Resuming download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, download = self.activeDownloads[urlString] {
            if let resumeData = download.resumeData {
                download.downloadTask = self.downloadsSession.downloadTaskWithResumeData(resumeData)
                download.downloadTask?.resume()
                download.isDownloading = true
            } else if let url = NSURL(string: download.url) {
                download.downloadTask = self.downloadsSession.downloadTaskWithURL(url)
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
    func videoIndexForYouTubeUrl(url: String) -> Int? {
        for (index, object) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerate() {
            if let video = object as? Video {
                if url == video.youtubeUrl {
                    return index
                }
            }
        }
        
        return nil
    }
    
    /**
     Gets the index of the video for the current download in the fetched results controller
     
     - parameter url: streaming URL for the video
     
     - returns: optional index
     */
    func videoIndexForStreamUrl(url: String) -> Int? {
        for (index, object) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerate() {
            if let video = object as? Video {
                if url == video.streamUrl {
                    return index
                }
            }
        }
        
        return nil
    }
    
    /**
     Gets the index of the video for the current download in the fetched results controller
     
     - parameter downloadTask: video that is currently downloading
     
     - returns: optional index
     */
    func videoIndexForDownloadTask(downloadTask: NSURLSessionDownloadTask) -> Int? {
        if let url = downloadTask.originalRequest?.URL?.absoluteString {
            return self.videoIndexForStreamUrl(url)
        }
        
        return nil
    }
}
