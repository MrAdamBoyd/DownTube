//
//  VideoDownloadManager.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-11-02.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation
import UIKit

protocol VideoManagerDelegate: class {
    func reloadRows(_ rows: [IndexPath])
    func updateDownloadProgress(_ download: Download, at index: Int, with totalSize: String)
}

class VideoManager: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    let defaultSession = URLSession(configuration: URLSessionConfiguration.default)
    var dataTask: URLSessionDataTask?
    var activeDownloads: [String: Download] = [:]
    
    lazy var downloadsSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "bgSessionConfiguration")
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    var delegate: VideoManagerDelegate?
    
    init(delegate: VideoManagerDelegate?) {
        
        super.init()
        
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
        print("Starting download of video \(video.title ?? "unknown video")")
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
        print("Canceling download of video \(video.title ?? "unknown video")")
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
        print("Resuming download of video \(video.title ?? "unknown video")")
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
    
    // MARK: - Locations of downloads
    
    /**
     Generates a permanent local file path to save a track to by appending the lastPathComponent of the URL to the path of the app's documents directory
     
     - parameter previewUrl: URL of the video
     
     - returns: URL to the file
     */
    func localFilePathForUrl(_ previewUrl: String) -> URL? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        if let url = URL(string: previewUrl), let query = url.query {
            //Getting the video ID using regex
            
            if let match = query.range(of: "&id=.*", options: .regularExpression) {
                //Trimming the values
                let low = query.index(match.lowerBound, offsetBy: 4)
                let high = query.index(match.lowerBound, offsetBy: 21)
                let videoID = query.substring(with: low..<high)
                let fullPath = documentsPath.appendingPathComponent(videoID)
                return URL(fileURLWithPath: fullPath + ".mp4")
            }
        }
        return nil
    }
    
    /**
     Determines whether or not a file exists for the video
     
     - parameter video: Video object
     
     - returns: true if object exists at path, false otherwise
     */
    func localFileExistsFor(_ video: Video) -> Bool {
        if let urlString = video.streamUrl, let localUrl = self.localFilePathForUrl(urlString) {
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: localUrl.path, isDirectory: &isDir)
        }
        
        return false
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    //Download finished
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let originalURL = downloadTask.originalRequest?.url?.absoluteString {
            
            if let destinationURL = self.localFilePathForUrl(originalURL) {
                print("Destination URL: \(destinationURL)")
                
                let fileManager = FileManager.default
                
                //Removing the file at the path, just in case one exists
                do {
                    try fileManager.removeItem(at: destinationURL)
                } catch {
                    print("No file to remove. Proceeding...")
                }
                
                //Moving the downloaded file to the new location
                do {
                    try fileManager.copyItem(at: location, to: destinationURL)
                } catch let error as NSError {
                    print("Could not copy file: \(error.localizedDescription)")
                }
                
                //Updating the cell
                if let url = downloadTask.originalRequest?.url?.absoluteString {
                    self.activeDownloads[url] = nil
                    
                    if let videoIndex = self.videoIndexForDownloadTask(downloadTask) {
                        self.delegate?.reloadRows([IndexPath(row: videoIndex, section: 0)])
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let downloadUrl = downloadTask.originalRequest?.url?.absoluteString, let download = self.activeDownloads[downloadUrl] {
            download.progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)
            let totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: ByteCountFormatter.CountStyle.binary)
            if let trackIndex = self.videoIndexForDownloadTask(downloadTask) {
                self.delegate?.updateDownloadProgress(download, at: trackIndex, with: totalSize)
            }
        }
    }
    
    // MARK: - URLSessionDelegate
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            if let completionHandler = appDelegate.backgroundSessionCompletionHandler {
                appDelegate.backgroundSessionCompletionHandler = nil
                DispatchQueue.main.async(execute: {
                    completionHandler()
                })
            }
        }
    }
}
