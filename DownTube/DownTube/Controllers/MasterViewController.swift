//
//  MasterViewController.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-05-30.
//  Copyright © 2016 Adam. All rights reserved.
//

import UIKit
import CoreData
import AVKit
import AVFoundation
import XCDYouTubeKit
import MMWormhole

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    //For the downloads
    let defaultSession = Foundation.URLSession(configuration: URLSessionConfiguration.default)
    var dataTask: URLSessionDataTask?
    var activeDownloads: [String: Download] = [:]
    
    //Commented out because of app group
//    let wormhole = MMWormhole(applicationGroupIdentifier: "group.adam.DownTube", optionalDirectory: nil)
    
    lazy var downloadsSession: Foundation.URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "bgSessionConfiguration")
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem

        let infoButton = UIBarButtonItem(title: "About", style: .plain, target: self, action: #selector(self.showAppInfo(_:)))
        self.navigationItem.rightBarButtonItem = infoButton
        
        CoreDataController.sharedController.fetchedResultsController.delegate = self
        
        //Need to specifically init this because self has to be used in the argument, which isn't formed until here
        _ = self.downloadsSession
        
        self.setUpSharedVideoListIfNeeded()
        
        self.addVideosFromSharedArray()
        
        //Wormhole between extension and app
        self.wormhole.listenForMessage(withIdentifier: "youTubeUrl") { messageObject in
            self.messageWasReceivedFromExtension(messageObject)
        }
    }
    
    /**
     Shows the "About this App" view controller
     
     - parameter sender: button that sent the action
     */
    func showAppInfo(_ sender: AnyObject) {
        self.performSegue(withIdentifier: "ShowAppInfo", sender: self)
    }

    /**
     Presents a UIAlertController that gets youtube video URL from user
     
     - parameter sender: button
     */
    @IBAction func askUserForURL(_ sender: AnyObject) {
        
        let alertController = UIAlertController(title: "Download YouTube Video", message: "Video will be downloaded in 720p or the highest available quality", preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Ok", style: .default) { action in
            let textField = alertController.textFields![0]
            
            if let text = textField.text {
                if text.characters.count > 10 {
                    self.startDownloadOfVideoInfoFor(text)
                } else {
                    self.showErrorAlertControllerWithMessage("URL too short to be valid")
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addTextField() { textField in
            textField.placeholder = "Enter YouTube video URL"
            textField.keyboardType = .URL
        }
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    /**
     Creates the entity and cell from provided URL, starts download
     
     - parameter url: stream URL for video
     */
    func startDownloadOfVideoInfoFor(_ url: String) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        //Gets the video id, which is the last 11 characters of the string
        XCDYouTubeClient.default().getVideoWithIdentifier(String(url.characters.suffix(11))) { video, error in
            self.videoObject(video, downloadedForVideoAt: url, error: error as NSError?)
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return CoreDataController.sharedController.fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = CoreDataController.sharedController.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoTableViewCell", for: indexPath) as! VideoTableViewCell
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath) as! Video
        self.configureCell(cell, withVideo: video)
        
        cell.delegate = self
        
        let holdGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongTouchWithGestureRecognizer(_:)))
        holdGestureRecognizer.minimumPressDuration = 1
        cell.addGestureRecognizer(holdGestureRecognizer)
        
        cell.setWatchIndicatorState(video.watchProgress)
        
        //Only show the download controls if video is currently downloading
        var showDownloadControls = false
        if let streamUrl = video.streamUrl, let download = self.activeDownloads[streamUrl] {
            showDownloadControls = true
            cell.progressView.progress = download.progress
            cell.progressLabel.text = (download.isDownloading) ? "Downloading..." : "Paused"
            let title = (download.isDownloading) ? "Pause" : "Resume"
            cell.pauseButton.setTitle(title, for: UIControlState())
        }
        cell.progressView.isHidden = !showDownloadControls
        cell.progressLabel.isHidden = !showDownloadControls
        
        //Hiding or showing the download button
        let downloaded = self.localFileExistsFor(video)
        cell.selectionStyle = downloaded ? .gray : .none
        
        //Hiding or showing the cancel and pause buttons
        cell.pauseButton.isHidden = !showDownloadControls
        cell.cancelButton.isHidden = !showDownloadControls
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath) as! Video
        if self.localFileExistsFor(video) {
            self.playDownload(video, atIndexPath: indexPath)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 62
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.deleteDownloadedVideoAt(indexPath)
            
            self.deleteVideoObjectAt(indexPath)
        }
    }

    func configureCell(_ cell: VideoTableViewCell, withVideo video: Video) {
        let components = (Calendar.current as NSCalendar).components([.day, .month, .year], from: video.created! as Date)
        
        cell.videoNameLabel.text = video.title
        cell.uploaderLabel.text = "Downloaded on \(components.year)/\(components.month)/\(components.day)"
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
            case .insert:
                self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
            case .delete:
                self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
            default:
                return
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
            case .insert:
                tableView.insertRows(at: [newIndexPath!], with: .fade)
            case .delete:
                tableView.deleteRows(at: [indexPath!], with: .fade)
            case .update:
                self.configureCell((tableView.cellForRow(at: indexPath!)! as! VideoTableViewCell), withVideo: anObject as! Video)
            case .move:
                tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
    
    //MARK: - Extension helper methods
    
    /**
     Initializes an empty of video URLs to add when the app opens in NSUserDefaults
     */
    func setUpSharedVideoListIfNeeded() {
        
        //If the array already exists, don't do anything
        if Constants.sharedDefaults.object(forKey: Constants.videosToAdd) != nil {
            return
        }
        
        let emptyArray: [String] = []
        Constants.sharedDefaults.set(emptyArray, forKey: Constants.videosToAdd)
        Constants.sharedDefaults.synchronize()
    }
    
    /**
     Starts the video info download for all videos stored in the shared array of youtube URLs. Clears the list when done
     */
    func addVideosFromSharedArray() {
        
        if let array = Constants.sharedDefaults.object(forKey: Constants.videosToAdd) as? [String] {
            for youTubeUrl in array {
                self.startDownloadOfVideoInfoFor(youTubeUrl)
            }
        }
        
        //Deleting all videos
        let emptyArray: [String] = []
        Constants.sharedDefaults.set(emptyArray, forKey: Constants.videosToAdd)
        Constants.sharedDefaults.synchronize()
    }
    
    /**
     Called when a message was received from the app extension. Should contain YouTube URL
     
     - parameter message: message sent from the share extension
     */
    func messageWasReceivedFromExtension(_ message: AnyObject?) {
        if let message = message as? String {
            
            //Remove the item at the end of the list from the list of items to add when the app opens
            var existingItems = Constants.sharedDefaults.object(forKey: Constants.videosToAdd) as! [String]
            existingItems.removeLast()
            Constants.sharedDefaults.set(existingItems, forKey: Constants.videosToAdd)
            Constants.sharedDefaults.synchronize()
            
            self.startDownloadOfVideoInfoFor(message)
        }
    }
    
    //MARK: - Downloading methods
    
    /**
     Starts download for video, called when track is added
     
     - parameter video: Video object
     */
    func startDownload(_ video: Video) {
        print("Starting download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, let url = URL(string: urlString), let index = self.videoIndexForStreamUrl(urlString) {
            let download = Download(url: urlString)
            download.downloadTask = self.downloadsSession.downloadTask(with: url)
            download.downloadTask?.resume()
            download.isDownloading = true
            self.activeDownloads[download.url] = download
            
            self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
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
                download.downloadTask = downloadsSession.downloadTask(withResumeData: resumeData)
                download.downloadTask?.resume()
                download.isDownloading = true
            } else if let url = URL(string: download.url) {
                download.downloadTask = downloadsSession.downloadTask(with: url)
                download.downloadTask?.resume()
                download.isDownloading = true
            }
        }
    }
    
    //MARK: - Helper methods
    
    /**
     Called when the video info for a video is downloaded
     
     - parameter video:      optional video object that was downloaded, contains stream info, title, etc.
     - parameter youTubeUrl: youtube URL of the video
     - parameter error:      optional error
     */
    func videoObject(_ video: XCDYouTubeVideo?, downloadedForVideoAt youTubeUrl: String, error: NSError?) {
        if let videoTitle = video?.title {
            print("\(videoTitle)")
            
            var streamUrl: String?
            
            if let highQualityStream = video?.streamURLs[XCDYouTubeVideoQuality.HD720.rawValue]?.absoluteString {
                
                //If 720p video exists
                streamUrl = highQualityStream
            
            } else if let mediumQualityStream = video?.streamURLs[XCDYouTubeVideoQuality.medium360.rawValue]?.absoluteString {
            
                //If 360p video exists
                streamUrl = mediumQualityStream
            
            } else if let lowQualityStream = video?.streamURLs[XCDYouTubeVideoQuality.small240.rawValue]?.absoluteString {
                
                //If 240p video exists
                streamUrl = lowQualityStream
            }
            
            
            if let video = video, let streamUrl = streamUrl {
                self.createObjectInCoreDataAndStartDownloadFor(video, withStreamUrl: streamUrl, andYouTubeUrl: youTubeUrl)
                
                return
            }
            
        }
        
        //Show error to user and remove all errored out videos
        self.showErrorAndRemoveErroredVideos(error)
    }
    
    
    /**
     Creates new video object in core data, saves the information for that video, and starts the download of the video stream
     
     - parameter video:      video object
     - parameter streamUrl:  streaming URL for the video
     - parameter youTubeUrl: youtube URL for the video (youtube.com/watch?=v...)
     */
    func createObjectInCoreDataAndStartDownloadFor(_ video: XCDYouTubeVideo?, withStreamUrl streamUrl: String, andYouTubeUrl youTubeUrl: String) {
        
        //Make sure the stream URL doesn't exist already
        guard self.videoIndexForYouTubeUrl(youTubeUrl) == nil else {
            self.showErrorAlertControllerWithMessage("Video already downloaded")
            return
        }
        
        let context = CoreDataController.sharedController.fetchedResultsController.managedObjectContext
        let entity = CoreDataController.sharedController.fetchedResultsController.fetchRequest.entity!
        let newVideo = NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: context) as! Video
        
        newVideo.created = Date()
        newVideo.youtubeUrl = youTubeUrl
        newVideo.title = video?.title
        newVideo.streamUrl = streamUrl
        newVideo.watchProgress = .unwatched
        
        do {
            try context.save()
        } catch {
            abort()
        }
        
        //Starts the download of the video
        self.startDownload(newVideo)
    }
    
    
    /**
     Shows error to user in UIAlertController and then removes all errored out videos from core data
     
     - parameter error: error from getting the video info
     */
    func showErrorAndRemoveErroredVideos(_ error: NSError?) {
        //Show error to user, remove all unused cells from list
        DispatchQueue.main.async {
            print("Couldn't get video: \(error)")
            
            let message = error?.userInfo["error"] as? String
            self.showErrorAlertControllerWithMessage(message)
        }
        
        //Getting all blank videos with no downloaded data
        var objectsToRemove: [IndexPath] = []
        for (index, object) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerated() {
            let video = object as! Video
            
            if video.streamUrl == nil {
                objectsToRemove.append(IndexPath(row: index, section: 0))
            }
        }
        
        //Deleting them
        for indexPath in objectsToRemove {
            self.deleteDownloadedVideoAt(indexPath)
            self.deleteVideoObjectAt(indexPath)
        }

    }
    
    /**
     Presents UIAlertController error message to user with ok button
     
     - parameter message: message to show
     */
    func showErrorAlertControllerWithMessage(_ message: String?) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    /**
     Gets the index of the video for the current download in the fetched results controller
     
     - parameter url: youtube url for the video
     
     - returns: optional index
     */
    func videoIndexForYouTubeUrl(_ url: String) -> Int? {
        for (index, object) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerated() {
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
    func videoIndexForStreamUrl(_ url: String) -> Int? {
        for (index, object) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerated() {
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
    func videoIndexForDownloadTask(_ downloadTask: URLSessionDownloadTask) -> Int? {
        if let url = downloadTask.originalRequest?.url?.absoluteString {
            return self.videoIndexForStreamUrl(url)
        }
        
        return nil
    }
    
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
                let videoID = query.substring(with: <#T##String.CharacterView corresponding to your index##String.CharacterView#>.index(match.lowerBound, offsetBy: 4)...<#T##String.CharacterView corresponding to your index##String.CharacterView#>.index(match.lowerBound, offsetBy: 20))
                
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
            if let path = localUrl.path {
                return FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            }
        }
        
        return false
    }
    
    /**
     Deletes the file for the video at the index path
     
     - parameter indexPath: index path of the cell that represents the video
     */
    func deleteDownloadedVideoAt(_ indexPath: IndexPath) {
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath) as! Video
        self.cancelDownload(video)
        
        if let urlString = video.streamUrl, let fileUrl = self.localFilePathForUrl(urlString) {
            //Removing the file at the path if one exists
            do {
                try FileManager.default.removeItem(at: fileUrl)
                print("Successfully removed file")
            } catch {
                print("No file to remove. Proceeding...")
            }
        }
    }
    
    
    /**
     Deletes video object from core data
     
     - parameter indexPath: location of the video
     */
    func deleteVideoObjectAt(_ indexPath: IndexPath) {
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath) as! NSManagedObject
        
        let context = CoreDataController.sharedController.fetchedResultsController.managedObjectContext
        context.delete(video)
        
        do {
            try context.save()
        } catch {
            abort()
        }
    }
    
    /**
     Plays video in fullscreen player
     
     - parameter video:     video that is going to be played
     - parameter indexPath: index path of the video
     */
    func playDownload(_ video: Video, atIndexPath indexPath: IndexPath) {
        if let urlString = video.streamUrl, let url = self.localFilePathForUrl(urlString) {
            let player = AVPlayer(url: url)
            
            //Seek to time if the time is saved
            switch video.watchProgress {
            case let .partiallyWatched(seconds):
                player.seek(to: CMTime(seconds: seconds.doubleValue, preferredTimescale: 1))
            default:    break
            }
            
            let playerViewController = AVPlayerViewController()
            player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 10, preferredTimescale: 1), queue: DispatchQueue.main) { [weak self] time in
                
                //Every 5 seconds, update the progress of the video in core data
                let intTime = Int(CMTimeGetSeconds(time))
                let totalVideoTime = CMTimeGetSeconds(player.currentItem!.duration)
                let progressPercent = Double(intTime) / totalVideoTime
                
                print("User progress on video in seconds: \(intTime)")
                
                //If user is 95% done with the video, mark it as done
                if progressPercent > 0.95 {
                    video.watchProgress = .watched
                } else {
                    video.watchProgress = .partiallyWatched(NSNumber(value: intTime as Int))
                }
                
                CoreDataController.sharedController.saveContext()
                self?.tableView.reloadRows(at: [indexPath], with: .none)
                
            }
            playerViewController.player = player
            self.present(playerViewController, animated: true) {
                playerViewController.player!.play()
            }
        }
    }
    
    /**
     Handles long touching on a cell. Can mark cell as watched or unwatched
     
     - parameter gestureRecognizer: gesture recognizer
     */
    func handleLongTouchWithGestureRecognizer(_ gestureRecognizer: UILongPressGestureRecognizer) {
        
        if gestureRecognizer.state == .ended {
            
            let point = gestureRecognizer.location(in: self.tableView)
            guard let indexPath = self.tableView.indexPathForRow(at: point) else {
                return
            }
            
            let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath) as! Video
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            for action in self.buildActionsForLongPressOn(video: video, at: indexPath) {
                alertController.addAction(action)
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            self.present(alertController, animated: true, completion: nil)
        }
        
    }
    
    /**
     Builds the alert actions for when a user long presses on a cell
     
     - parameter video:     video to build the actions for
     - parameter indexPath: location of the cell
     
     - returns: array of actions
     */
    func buildActionsForLongPressOn(video: Video, at indexPath: IndexPath) -> [UIAlertAction] {
        var actions: [UIAlertAction] = []
        
        //If the user progress isn't nil, that means that the video is unwatched or partially watched
        if video.watchProgress != .watched {
            actions.append(UIAlertAction(title: "Mark as Watched", style: .default) { [weak self] _ in
                video.watchProgress = .watched
                CoreDataController.sharedController.saveContext()
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            })
        }
        
        //If the user progress isn't 0, the video is either partially watched or done
        if video.watchProgress != .unwatched {
            actions.append(UIAlertAction(title: "Mark as Unwatched", style: .default) { [weak self] _ in
                video.watchProgress = .unwatched
                CoreDataController.sharedController.saveContext()
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            })
        }
        
        //Sharing the video
        if let streamUrl = video.streamUrl, let localUrl = self.localFilePathForUrl(streamUrl) {
            actions.append(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
                let activityViewController = UIActivityViewController(activityItems: [localUrl], applicationActivities: nil)
                self?.present(activityViewController, animated: true, completion: nil)
            })
        }
        
        return actions
        
    }

}

// MARK: VideoTableViewCellDelegate

extension MasterViewController: VideoTableViewCellDelegate {
    func pauseTapped(_ cell: VideoTableViewCell) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath) as! Video
            self.pauseDownload(video)
            self.tableView.reloadRows(at: [IndexPath(row: (indexPath as NSIndexPath).row, section: 0)], with: .none)
        }
    }
    
    func resumeTapped(_ cell: VideoTableViewCell) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath) as! Video
            self.resumeDownload(video)
            self.tableView.reloadRows(at: [IndexPath(row: (indexPath as NSIndexPath).row, section: 0)], with: .none)
        }
    }
    
    func cancelTapped(_ cell: VideoTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath) as! Video
            self.cancelDownload(video)
            tableView.reloadRows(at: [IndexPath(row: (indexPath as NSIndexPath).row, section: 0)], with: .none)
            self.deleteVideoObjectAt(indexPath)
        }
    }
}

//MARK: - NSURLSessionDownloadDelegate

extension MasterViewController: URLSessionDownloadDelegate {
    
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
                        DispatchQueue.main.async(execute: {
                            self.tableView.reloadRows(at: [IndexPath(row: videoIndex, section: 0)], with: .none)
                        })
                    }
                }
            }
        }
    }
    
    //Updating download status
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let downloadUrl = downloadTask.originalRequest?.url?.absoluteString, let download = self.activeDownloads[downloadUrl] {
            download.progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)
            let totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: ByteCountFormatter.CountStyle.binary)
            if let trackIndex = self.videoIndexForDownloadTask(downloadTask), let VideoTableViewCell = tableView.cellForRow(at: IndexPath(row: trackIndex, section: 0)) as? VideoTableViewCell {
                DispatchQueue.main.async(execute: {
                    
                    let done = (download.progress == 1)
                    
                    VideoTableViewCell.progressView.isHidden = done
                    VideoTableViewCell.progressLabel.isHidden = done
                    VideoTableViewCell.progressView.progress = download.progress
                    VideoTableViewCell.progressLabel.text =  String(format: "%.1f%% of %@",  download.progress * 100, totalSize)
                })
            }
        }
    }
}

//MARK: - NSURLSessionDelegate

extension MasterViewController: URLSessionDelegate {
    
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
