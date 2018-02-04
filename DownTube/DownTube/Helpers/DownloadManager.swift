//
//  DownloadManager.swift
//  DownTube
//
//  Created by Adam on 10/4/17.
//  Copyright © 2017 Adam. All rights reserved.
//

import Foundation
import UIKit

let maxNumberOfActiveDownloads = 3

protocol DownloadManagerDelegate: class {
    func videoIndexForYouTubeUrl(_ url: String) -> Int?
    func videoIndexForStreamUrl(_ url: String) -> Int?
    func localFilePathForUrl(_ streamUrl: String) -> URL?
}

class DownloadManager: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    let defaultSession = URLSession(configuration: URLSessionConfiguration.default)
    var dataTask: URLSessionDataTask?
    private(set) var activeDownloads: [Download] = [] //Only allows 3
    private(set) var enqueuedDownloads: [Download] = []
    
    private lazy var downloadsSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "bgSessionConfiguration")
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    weak var delegate: DownloadManagerDelegate?
    weak var videoManagerDelegate: VideoManagerDelegate?
    var fileManager: FileManager = .default
    
    // Path where the video files are stored
    var documentsPath: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    init(delegate: DownloadManagerDelegate?, videoManagerDelegate: VideoManagerDelegate?, fileManager: FileManager) {
        
        super.init()
        
        self.delegate = delegate
        self.videoManagerDelegate = videoManagerDelegate
        self.fileManager = fileManager
        
        //Need to specifically init this because self has to be used in the argument, which isn't formed until here
        _ = self.downloadsSession
    }
    
    // MARK: - Dealing with downloads queue
    
    /// Adds download either to active list or enqueued download list. Starts downloading the item
    ///
    /// - Parameter download: download to add
    private func addDownload(_ download: Download) {
        if self.activeDownloads.count < maxNumberOfActiveDownloads {
            download.downloadTask?.resume()
            download.state = .downloading
            self.activeDownloads.append(download)
        } else {
            self.enqueuedDownloads.append(download)
        }
    }
    
    /// Gets the download object from either the active downloads list or the enqueued downloads list
    ///
    /// - Parameter streamUrl: stream url to search for
    /// - Returns: download object if exists
    func getDownloadWith(streamUrl: String) -> Download? {
        if let video = self.activeDownloads.first(where: { $0.url == streamUrl }) {
            return video
        } else if let video = self.enqueuedDownloads.first(where: { $0.url == streamUrl }) {
            return video
        }
        
        return nil
    }
    
    /// Removes the download with the specified stream url. If removing an active download, moves an enqueued download into the active downloads list and starts the download
    ///
    /// - Parameter streamUrl: stream url to search for
    /// - Parameter cancelDownload: if true, cancels the download as well
    /// - Returns: true if download was successfully removed, false otherwise
    @discardableResult
    private func removeDownloadWith(streamUrl: String, cancelDownload: Bool) -> Bool {
        if let index = self.activeDownloads.index(where: { $0.url == streamUrl }) {
            let download = self.activeDownloads.remove(at: index)
            if cancelDownload { download.downloadTask?.cancel() }
            
            guard self.activeDownloads.count < maxNumberOfActiveDownloads else { return true }
            
            //Gets the first enqueued download that isn't paused
            let firstEnqueuedDownload = self.enqueuedDownloads.first(where: {
                switch $0.state {
                case .paused:           return false
                default:                return true
                }
            })
            if let firstEnqueuedDownload = firstEnqueuedDownload {
                self.resumeDownload(firstEnqueuedDownload)
            }
            
            return true
        } else if let index = self.enqueuedDownloads.index(where: { $0.url == streamUrl }) {
            let download = self.enqueuedDownloads.remove(at: index)
            if cancelDownload { download.downloadTask?.cancel() }
            return true
        }
        
        return false
    }
    
    // MARK: - Getting index for videos
    
    /**
     Gets the index of the video for the current download in the fetched results controller
     
     - parameter downloadTask: video that is currently downloading
     
     - returns: optional index
     */
    func videoIndexForDownloadTask(_ downloadTask: URLSessionDownloadTask) -> Int? {
        if let url = downloadTask.originalRequest?.url?.absoluteString {
            return self.delegate?.videoIndexForStreamUrl(url)
        }
        
        return nil
    }
    
    // MARK: - Downloading
    
    /**
     Starts download for video, called when track is added
     
     - parameter video:     Video object
     - parameter onSuccess: closure that is called immediately if the video is valid
     - Returns: index of video in list
     */
    func startDownload(_ video: Video) -> Int? {
        print("Starting download of video \(video.title ?? "unknown video")")
        if let urlString = video.streamUrl, let url = URL(string: urlString), let index = self.delegate?.videoIndexForStreamUrl(urlString) {
            let download = Download(url: urlString)
            download.downloadTask = self.downloadsSession.downloadTask(with: url)
            self.addDownload(download)
            
            return index
        }
        
        return nil
    }
    
    /**
     Called when pause button for video is tapped
     
     - parameter video: Video object
     */
    func pauseDownload(_ video: Video) {
        print("Pausing download")
        if let urlString = video.streamUrl, let download = self.getDownloadWith(streamUrl: urlString) {
            if download.state == .downloading {
                download.downloadTask?.cancel() { data in
                    download.resumeData = data
                }
                download.state = .paused
            }
            
            //In this case, we let the user have more than 3 simultaneous downloads
            self.removeDownloadWith(streamUrl: urlString, cancelDownload: false)
            self.enqueuedDownloads.append(download)
        }
    }
    
    /**
     Called when the cancel button for a video is tapped
     
     - parameter video: Video object
     */
    func cancelDownload(_ video: Video) {
        print("Cancelling download of video \(video.title ?? "unknown video")")
        if let urlString = video.streamUrl {
            self.removeDownloadWith(streamUrl: urlString, cancelDownload: true)
        }
        
    }
    
    /**
     Called when the resume button for a video is tapped
     
     - parameter video: Video object
     */
    func resumeVideoDownload(_ video: Video) {
        print("Resuming download of video \(video.title ?? "unknown video")")
        if let urlString = video.streamUrl, let download = self.getDownloadWith(streamUrl: urlString) {
            self.resumeDownload(download)
        }
    }
    
    /// Resumes the download, with resume data, if available
    ///
    /// - Parameter download: download to resume
    func resumeDownload(_ download: Download) {
        guard !self.activeDownloads.contains(download) else { return }
        
        if let resumeData = download.resumeData {
            download.downloadTask = self.downloadsSession.downloadTask(withResumeData: resumeData)
            download.downloadTask?.resume()
            download.state = .downloading
        } else if let url = URL(string: download.url) {
            download.downloadTask = self.downloadsSession.downloadTask(with: url)
            download.downloadTask?.resume()
            download.state = .downloading
        }
        
        //In this case, we let the user have more than 3 simultaneous downloads
        self.removeDownloadWith(streamUrl: download.url, cancelDownload: false)
        self.activeDownloads.append(download)
    }
    
    /// If the download is done, saves the video's done progress to core data
    ///
    /// - Parameters:
    ///   - download: download for video
    ///   - index: index of the video in core data
    private func markDownloadAsDoneIfNeeded(_ download: Download, at index: Int) {
        if download.isDone {
            let video = PersistentVideoStore.shared.fetchedVideosController.object(at: IndexPath(item: index, section: 0))
            video.isDoneDownloading = NSNumber(value: true)
            PersistentVideoStore.shared.save()
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    //Download finished
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let originalURL = downloadTask.originalRequest?.url?.absoluteString {
            
            if let destinationURL = self.delegate?.localFilePathForUrl(originalURL) {
                print("Destination URL: \(destinationURL)")
                
                let fileManager = self.fileManager
                
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
                    self.removeDownloadWith(streamUrl: url, cancelDownload: true)
                    
                    if let videoIndex = self.videoIndexForDownloadTask(downloadTask) {
                        self.videoManagerDelegate?.reloadRows([IndexPath(row: videoIndex, section: 0)])
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let downloadUrl = downloadTask.originalRequest?.url?.absoluteString, let download =  self.getDownloadWith(streamUrl: downloadUrl) {
            download.progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)
            let totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: ByteCountFormatter.CountStyle.binary)
            
            if let trackIndex = self.videoIndexForDownloadTask(downloadTask) {
                self.markDownloadAsDoneIfNeeded(download, at: trackIndex)
                    
                //Updating VC
                self.videoManagerDelegate?.updateDownloadProgress(download, at: trackIndex, with: totalSize)
            }
        }
    }
    
    // MARK: - URLSessionDelegate
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("URLSession did finish background download events")
        DispatchQueue.main.async {
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
}
