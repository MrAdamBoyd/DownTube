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
    let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    var dataTask: NSURLSessionDataTask?
    var activeDownloads: [String: Download] = [:]
    
    //Commented out because of app group
//    let wormhole = MMWormhole(applicationGroupIdentifier: "group.adam.DownTube", optionalDirectory: nil)
    
    lazy var downloadsSession: NSURLSession = {
        let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("bgSessionConfiguration")
        let session = NSURLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem()

        let infoButton = UIBarButtonItem(title: "About", style: .Plain, target: self, action: #selector(self.showAppInfo(_:)))
        self.navigationItem.rightBarButtonItem = infoButton
        
        CoreDataController.sharedController.fetchedResultsController.delegate = self
        
        //Need to specifically init this because self has to be used in the argument, which isn't formed until here
        _ = self.downloadsSession
        
        self.setUpSharedVideoListIfNeeded()
        
        self.addVideosFromSharedArray()
        
        //Wormhole between extension and app
//        self.wormhole.listenForMessageWithIdentifier("youTubeUrl") { messageObject in
//            self.messageWasReceivedFromExtension(messageObject)
//        }
    }
    
    /**
     Shows the "About this App" view controller
     
     - parameter sender: button that sent the action
     */
    func showAppInfo(sender: AnyObject) {
        self.performSegueWithIdentifier("ShowAppInfo", sender: self)
    }

    /**
     Presents a UIAlertController that gets youtube video URL from user
     
     - parameter sender: button
     */
    @IBAction func askUserForURL(sender: AnyObject) {
        
        let alertController = UIAlertController(title: "Download YouTube Video", message: "Video will be downloaded in 720p or the highest available quality", preferredStyle: .Alert)
        
        let saveAction = UIAlertAction(title: "Ok", style: .Default) { action in
            let textField = alertController.textFields![0]
            
            if let text = textField.text {
                if text.characters.count > 10 {
                    self.startDownloadOfVideoInfoFor(text)
                } else {
                    self.showErrorAlertControllerWithMessage("URL too short to be valid")
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addTextFieldWithConfigurationHandler() { textField in
            textField.placeholder = "Enter YouTube video URL"
            textField.keyboardType = .URL
        }
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    /**
     Creates the entity and cell from provided URL, starts download
     
     - parameter url: stream URL for video
     */
    func startDownloadOfVideoInfoFor(url: String) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        //Gets the video id, which is the last 11 characters of the string
        XCDYouTubeClient.defaultClient().getVideoWithIdentifier(String(url.characters.suffix(11))) { video, error in
            self.videoObject(video, downloadedForVideoAt: url, error: error)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            
        }
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return CoreDataController.sharedController.fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = CoreDataController.sharedController.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("VideoTableViewCell", forIndexPath: indexPath) as! VideoTableViewCell
        let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
        self.configureCell(cell, withVideo: video)
        
        cell.delegate = self
        
        let holdGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongTouchWithGestureRecognizer(_:)))
        holdGestureRecognizer.minimumPressDuration = 1
        cell.addGestureRecognizer(holdGestureRecognizer)
        
        cell.setWatchIndicatorState(video.watchProgress)
        
        //Only show the download controls if video is currently downloading
        var showDownloadControls = false
        if let streamUrl = video.streamUrl, download = self.activeDownloads[streamUrl] {
            showDownloadControls = true
            cell.progressView.progress = download.progress
            cell.progressLabel.text = (download.isDownloading) ? "Downloading..." : "Paused"
            let title = (download.isDownloading) ? "Pause" : "Resume"
            cell.pauseButton.setTitle(title, forState: UIControlState.Normal)
        }
        cell.progressView.hidden = !showDownloadControls
        cell.progressLabel.hidden = !showDownloadControls
        
        //Hiding or showing the download button
        let downloaded = self.localFileExistsFor(video)
        cell.selectionStyle = downloaded ? .Gray : .None
        
        //Hiding or showing the cancel and pause buttons
        cell.pauseButton.hidden = !showDownloadControls
        cell.cancelButton.hidden = !showDownloadControls
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
        if self.localFileExistsFor(video) {
            self.playDownload(video, atIndexPath: indexPath)
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 62
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            self.deleteDownloadedVideoAt(indexPath)
            
            self.deleteVideoObjectAt(indexPath)
        }
    }

    func configureCell(cell: VideoTableViewCell, withVideo video: Video) {
        let components = NSCalendar.currentCalendar().components([.Day, .Month, .Year], fromDate: video.created!)
        
        cell.videoNameLabel.text = video.title
        cell.uploaderLabel.text = "Downloaded on \(components.year)/\(components.month)/\(components.day)"
    }

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }

    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            case .Insert:
                self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            case .Delete:
                self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            default:
                return
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            case .Insert:
                tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
            case .Delete:
                tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            case .Update:
                self.configureCell((tableView.cellForRowAtIndexPath(indexPath!)! as! VideoTableViewCell), withVideo: anObject as! Video)
            case .Move:
                tableView.moveRowAtIndexPath(indexPath!, toIndexPath: newIndexPath!)
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
    //MARK: - Extension helper methods
    
    /**
     Initializes an empty of video URLs to add when the app opens in NSUserDefaults
     */
    func setUpSharedVideoListIfNeeded() {
        
        //If the array already exists, don't do anything
        if Constants.sharedDefaults.objectForKey(Constants.videosToAdd) != nil {
            return
        }
        
        let emptyArray: [String] = []
        Constants.sharedDefaults.setObject(emptyArray, forKey: Constants.videosToAdd)
        Constants.sharedDefaults.synchronize()
    }
    
    /**
     Starts the video info download for all videos stored in the shared array of youtube URLs. Clears the list when done
     */
    func addVideosFromSharedArray() {
        
        if let array = Constants.sharedDefaults.objectForKey(Constants.videosToAdd) as? [String] {
            for youTubeUrl in array {
                self.startDownloadOfVideoInfoFor(youTubeUrl)
            }
        }
        
        //Deleting all videos
        let emptyArray: [String] = []
        Constants.sharedDefaults.setObject(emptyArray, forKey: Constants.videosToAdd)
        Constants.sharedDefaults.synchronize()
    }
    
    /**
     Called when a message was received from the app extension. Should contain YouTube URL
     
     - parameter message: message sent from the share extension
     */
    func messageWasReceivedFromExtension(message: AnyObject?) {
        if let message = message as? String {
            
            //Remove the item at the end of the list from the list of items to add when the app opens
            var existingItems = Constants.sharedDefaults.objectForKey(Constants.videosToAdd) as! [String]
            existingItems.removeLast()
            Constants.sharedDefaults.setObject(existingItems, forKey: Constants.videosToAdd)
            Constants.sharedDefaults.synchronize()
            
            self.startDownloadOfVideoInfoFor(message)
        }
    }
    
    //MARK: - Downloading methods
    
    /**
     Starts download for video, called when track is added
     
     - parameter video: Video object
     */
    func startDownload(video: Video) {
        print("Starting download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, url = NSURL(string: urlString), index = self.videoIndexForStreamUrl(urlString) {
            let download = Download(url: urlString)
            download.downloadTask = self.downloadsSession.downloadTaskWithURL(url)
            download.downloadTask?.resume()
            download.isDownloading = true
            self.activeDownloads[download.url] = download
            
            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .None)
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
                download.downloadTask = downloadsSession.downloadTaskWithResumeData(resumeData)
                download.downloadTask?.resume()
                download.isDownloading = true
            } else if let url = NSURL(string: download.url) {
                download.downloadTask = downloadsSession.downloadTaskWithURL(url)
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
    func videoObject(video: XCDYouTubeVideo?, downloadedForVideoAt youTubeUrl: String, error: NSError?) {
        if let videoTitle = video?.title {
            print("\(videoTitle)")
            
            var streamUrl: String?
            
            if let highQualityStream = video?.streamURLs[XCDYouTubeVideoQuality.HD720.rawValue]?.absoluteString {
                
                //If 720p video exists
                streamUrl = highQualityStream
            
            } else if let mediumQualityStream = video?.streamURLs[XCDYouTubeVideoQuality.Medium360.rawValue]?.absoluteString {
            
                //If 360p video exists
                streamUrl = mediumQualityStream
            
            } else if let lowQualityStream = video?.streamURLs[XCDYouTubeVideoQuality.Small240.rawValue]?.absoluteString {
                
                //If 240p video exists
                streamUrl = lowQualityStream
            }
            
            
            if let video = video, streamUrl = streamUrl {
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
    func createObjectInCoreDataAndStartDownloadFor(video: XCDYouTubeVideo?, withStreamUrl streamUrl: String, andYouTubeUrl youTubeUrl: String) {
        
        //Make sure the stream URL doesn't exist already
        guard self.videoIndexForYouTubeUrl(youTubeUrl) == nil else {
            self.showErrorAlertControllerWithMessage("Video already downloaded")
            return
        }
        
        let context = CoreDataController.sharedController.fetchedResultsController.managedObjectContext
        let entity = CoreDataController.sharedController.fetchedResultsController.fetchRequest.entity!
        let newVideo = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! Video
        
        newVideo.created = NSDate()
        newVideo.youtubeUrl = youTubeUrl
        newVideo.title = video?.title
        newVideo.streamUrl = streamUrl
        newVideo.watchProgress = .Unwatched
        
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
    func showErrorAndRemoveErroredVideos(error: NSError?) {
        //Show error to user, remove all unused cells from list
        dispatch_async(dispatch_get_main_queue()) {
            print("Couldn't get video: \(error)")
            
            let message = error?.userInfo["error"] as? String
            self.showErrorAlertControllerWithMessage(message)
        }
        
        //Getting all blank videos with no downloaded data
        var objectsToRemove: [NSIndexPath] = []
        for (index, object) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerate() {
            let video = object as! Video
            
            if video.streamUrl == nil {
                objectsToRemove.append(NSIndexPath(forRow: index, inSection: 0))
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
    func showErrorAlertControllerWithMessage(message: String?) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
        let cancelAction = UIAlertAction(title: "Ok", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
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
    
    /**
     Generates a permanent local file path to save a track to by appending the lastPathComponent of the URL to the path of the app's documents directory
     
     - parameter previewUrl: URL of the video
     
     - returns: URL to the file
     */
    func localFilePathForUrl(previewUrl: String) -> NSURL? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        if let url = NSURL(string: previewUrl), query = url.query {
            //Getting the video ID using regex
            
            if let match = query.rangeOfString("&id=.*", options: .RegularExpressionSearch) {
                //Trimming the values
                let videoID = query.substringWithRange(match.startIndex.advancedBy(4)...match.startIndex.advancedBy(20))
                
                let fullPath = documentsPath.stringByAppendingPathComponent(videoID)
                return NSURL(fileURLWithPath: fullPath + ".mp4")
            }
        }
        return nil
    }
    
    /**
     Determines whether or not a file exists for the video
     
     - parameter video: Video object
     
     - returns: true if object exists at path, false otherwise
     */
    func localFileExistsFor(video: Video) -> Bool {
        if let urlString = video.streamUrl, localUrl = self.localFilePathForUrl(urlString) {
            var isDir: ObjCBool = false
            if let path = localUrl.path {
                return NSFileManager.defaultManager().fileExistsAtPath(path, isDirectory: &isDir)
            }
        }
        
        return false
    }
    
    /**
     Deletes the file for the video at the index path
     
     - parameter indexPath: index path of the cell that represents the video
     */
    func deleteDownloadedVideoAt(indexPath: NSIndexPath) {
        let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
        self.cancelDownload(video)
        
        if let urlString = video.streamUrl, fileUrl = self.localFilePathForUrl(urlString) {
            //Removing the file at the path if one exists
            do {
                try NSFileManager.defaultManager().removeItemAtURL(fileUrl)
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
    func deleteVideoObjectAt(indexPath: NSIndexPath) {
        let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
        
        let context = CoreDataController.sharedController.fetchedResultsController.managedObjectContext
        context.deleteObject(video)
        
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
    func playDownload(video: Video, atIndexPath indexPath: NSIndexPath) {
        if let urlString = video.streamUrl, url = self.localFilePathForUrl(urlString) {
            let player = AVPlayer(URL: url)
            
            //Seek to time if the time is saved
            switch video.watchProgress {
            case let .PartiallyWatched(seconds):
                player.seekToTime(CMTime(seconds: seconds.doubleValue, preferredTimescale: 1))
            default:    break
            }
            
            let playerViewController = AVPlayerViewController()
            player.addPeriodicTimeObserverForInterval(CMTime(seconds: 10, preferredTimescale: 1), queue: dispatch_get_main_queue()) { [weak self] time in
                
                //Every 5 seconds, update the progress of the video in core data
                let intTime = Int(CMTimeGetSeconds(time))
                let totalVideoTime = CMTimeGetSeconds(player.currentItem!.duration)
                let progressPercent = Double(intTime) / totalVideoTime
                
                print("User progress on video in seconds: \(intTime)")
                
                //If user is 95% done with the video, mark it as done
                if progressPercent > 0.95 {
                    video.watchProgress = .Watched
                } else {
                    video.watchProgress = .PartiallyWatched(NSNumber(integer: intTime))
                }
                
                CoreDataController.sharedController.saveContext()
                self?.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                
            }
            playerViewController.player = player
            self.presentViewController(playerViewController, animated: true) {
                playerViewController.player!.play()
            }
        }
    }
    
    /**
     Handles long touching on a cell. Can mark cell as watched or unwatched
     
     - parameter gestureRecognizer: gesture recognizer
     */
    func handleLongTouchWithGestureRecognizer(gestureRecognizer: UILongPressGestureRecognizer) {
        
        if gestureRecognizer.state == .Ended {
            
            let point = gestureRecognizer.locationInView(self.tableView)
            guard let indexPath = self.tableView.indexPathForRowAtPoint(point) else {
                return
            }
            
            let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            
            for action in self.buildActionsForLongPressOn(video: video, at: indexPath) {
                alertController.addAction(action)
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        
    }
    
    /**
     Builds the alert actions for when a user long presses on a cell
     
     - parameter video:     video to build the actions for
     - parameter indexPath: location of the cell
     
     - returns: array of actions
     */
    func buildActionsForLongPressOn(video video: Video, at indexPath: NSIndexPath) -> [UIAlertAction] {
        var actions: [UIAlertAction] = []
        
        //If the user progress isn't nil, that means that the video is unwatched or partially watched
        if video.watchProgress != .Watched {
            actions.append(UIAlertAction(title: "Mark as Watched", style: .Default) { [weak self] _ in
                video.watchProgress = .Watched
                CoreDataController.sharedController.saveContext()
                self?.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            })
        }
        
        //If the user progress isn't 0, the video is either partially watched or done
        if video.watchProgress != .Unwatched {
            actions.append(UIAlertAction(title: "Mark as Unwatched", style: .Default) { [weak self] _ in
                video.watchProgress = .Unwatched
                CoreDataController.sharedController.saveContext()
                self?.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            })
        }
        
        //Sharing the video
        if let streamUrl = video.streamUrl, localUrl = self.localFilePathForUrl(streamUrl) {
            actions.append(UIAlertAction(title: "Share", style: .Default) { [weak self] _ in
                let activityViewController = UIActivityViewController(activityItems: [localUrl], applicationActivities: nil)
                self?.presentViewController(activityViewController, animated: true, completion: nil)
            })
        }
        
        return actions
        
    }

}

// MARK: VideoTableViewCellDelegate

extension MasterViewController: VideoTableViewCellDelegate {
    func pauseTapped(cell: VideoTableViewCell) {
        if let indexPath = self.tableView.indexPathForCell(cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
            self.pauseDownload(video)
            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
        }
    }
    
    func resumeTapped(cell: VideoTableViewCell) {
        if let indexPath = self.tableView.indexPathForCell(cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
            self.resumeDownload(video)
            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
        }
    }
    
    func cancelTapped(cell: VideoTableViewCell) {
        if let indexPath = tableView.indexPathForCell(cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
            self.cancelDownload(video)
            tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
            self.deleteVideoObjectAt(indexPath)
        }
    }
}

//MARK: - NSURLSessionDownloadDelegate

extension MasterViewController: NSURLSessionDownloadDelegate {
    
    //Download finished
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        if let originalURL = downloadTask.originalRequest?.URL?.absoluteString {
            
            if let destinationURL = self.localFilePathForUrl(originalURL) {
                print("Destination URL: \(destinationURL)")
                
                let fileManager = NSFileManager.defaultManager()
                
                //Removing the file at the path, just in case one exists
                do {
                    try fileManager.removeItemAtURL(destinationURL)
                } catch {
                    print("No file to remove. Proceeding...")
                }
                
                //Moving the downloaded file to the new location
                do {
                    try fileManager.copyItemAtURL(location, toURL: destinationURL)
                } catch let error as NSError {
                    print("Could not copy file: \(error.localizedDescription)")
                }
                
                //Updating the cell
                if let url = downloadTask.originalRequest?.URL?.absoluteString {
                    self.activeDownloads[url] = nil
                    
                    if let videoIndex = self.videoIndexForDownloadTask(downloadTask) {
                        dispatch_async(dispatch_get_main_queue(), {
                            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: videoIndex, inSection: 0)], withRowAnimation: .None)
                        })
                    }
                }
            }
        }
    }
    
    //Updating download status
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let downloadUrl = downloadTask.originalRequest?.URL?.absoluteString, download = self.activeDownloads[downloadUrl] {
            download.progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)
            let totalSize = NSByteCountFormatter.stringFromByteCount(totalBytesExpectedToWrite, countStyle: NSByteCountFormatterCountStyle.Binary)
            if let trackIndex = self.videoIndexForDownloadTask(downloadTask), let VideoTableViewCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: trackIndex, inSection: 0)) as? VideoTableViewCell {
                dispatch_async(dispatch_get_main_queue(), {
                    
                    let done = (download.progress == 1)
                    
                    VideoTableViewCell.progressView.hidden = done
                    VideoTableViewCell.progressLabel.hidden = done
                    VideoTableViewCell.progressView.progress = download.progress
                    VideoTableViewCell.progressLabel.text =  String(format: "%.1f%% of %@",  download.progress * 100, totalSize)
                })
            }
        }
    }
}

//MARK: - NSURLSessionDelegate

extension MasterViewController: NSURLSessionDelegate {
    
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
            if let completionHandler = appDelegate.backgroundSessionCompletionHandler {
                appDelegate.backgroundSessionCompletionHandler = nil
                dispatch_async(dispatch_get_main_queue(), {
                    completionHandler()
                })
            }
        }
    }
}
