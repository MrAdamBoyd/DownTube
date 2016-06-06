//
//  MasterViewController.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-05-30.
//  Copyright © 2016 Adam. All rights reserved.
//

import UIKit
import CoreData
import YoutubeSourceParserKit
import MediaPlayer

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    //For the downloads
    let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    var dataTask: NSURLSessionDataTask?
    var activeDownloads: [String: Download] = [:]
    
    lazy var downloadsSession: NSURLSession = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem()

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(self.askUserForURL(_:)))
        self.navigationItem.rightBarButtonItem = addButton
        
        CoreDataController.sharedController.fetchedResultsController.delegate = self
    }

    /**
     Presents a UIAlertController that gets youtube video URL from user
     
     - parameter sender: button
     */
    func askUserForURL(sender: AnyObject) {
        
        let alertController = UIAlertController(title: "Download YouTube Video", message: "Video will be downloaded in 720p", preferredStyle: .Alert)
        
        let saveAction = UIAlertAction(title: "Ok", style: .Default) { action in
            let textField = alertController.textFields![0]
            
            if let text = textField.text {
                self.createEntityFromVideoUrl(text)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addTextFieldWithConfigurationHandler() { textField in
            textField.placeholder = "Enter YouTube video URL"
        }
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    /**
     Creates the entity and cell from provided URL, starts download
     
     - parameter URL: stream URL for video
     */
    func createEntityFromVideoUrl(url: String) {
        let context = CoreDataController.sharedController.fetchedResultsController.managedObjectContext
        let entity = CoreDataController.sharedController.fetchedResultsController.fetchRequest.entity!
        let newManagedObject = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! Video
        
        // If appropriate, configure the new managed object.
        // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
        newManagedObject.created = NSDate()
        newManagedObject.youtubeUrl = url
        
        if let youtubeUrl = NSURL(string: url) {
            Youtube.h264videosWithYoutubeURL(youtubeUrl) { videoInfo, error in
                self.videoInfo(videoInfo, downloadedForVideoAt: url)
            }
        }
        
        // Save the context.
        do {
            try context.save()
        } catch {
            abort()
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
        let cell = tableView.dequeueReusableCellWithIdentifier("VideoCell", forIndexPath: indexPath) as! VideoCell
        let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
        self.configureCell(cell, withVideo: video)
        
        cell.delegate = self
        
        //Only show the download controls if video is currently downloading
        var showDownloadControls = false
        if let streamUrl = video.streamUrl, download = self.activeDownloads[streamUrl] {
            showDownloadControls = true
            cell.progressView.progress = download.progress
            cell.progressLabel.text = (download.isDownloading) ? "Downloading..." : "Paused"
            let title = (download.isDownloading) ? "Pause" : "Resume"
            cell.pauseButton.setTitle(title, forState: UIControlState.Normal)
        }
//        cell.progressView.hidden = !showDownloadControls
//        cell.progressLabel.hidden = !showDownloadControls
        
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
            self.playDownload(video)
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
            
            let context = CoreDataController.sharedController.fetchedResultsController.managedObjectContext
            context.deleteObject(CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject)
                
            do {
                try context.save()
            } catch {
                abort()
            }
        }
    }

    func configureCell(cell: VideoCell, withVideo video: Video) {
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
                self.configureCell((tableView.cellForRowAtIndexPath(indexPath!)! as! VideoCell), withVideo: anObject as! Video)
            case .Move:
                tableView.moveRowAtIndexPath(indexPath!, toIndexPath: newIndexPath!)
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
    //MARK: - Downloading methods
    
    /**
     Starts download for video, called when track is added
     
     - parameter video: Video object
     */
    func startDownload(video: Video) {
        print("Starting download of video \(video.title) by \(video.uploader)")
        if let urlString = video.streamUrl, url = NSURL(string: urlString) {
            let download = Download(url: urlString)
            download.downloadTask = self.downloadsSession.downloadTaskWithURL(url)
            download.downloadTask?.resume()
            download.isDownloading = true
            self.activeDownloads[download.url] = download
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
        if let urlString = video.streamUrl , download = self.activeDownloads[urlString] {
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
     
     - parameter youTubeUrl: youtube url for the video
     */
    func videoInfo(videoInfo: [String: AnyObject]?, downloadedForVideoAt youTubeUrl: String) {
        if let streamUrlString = videoInfo?["url"] as? String,
            videoTitle = videoInfo?["title"] as? String {
            print("\(videoTitle)")
            print("\(streamUrlString)")
            
            if let index = self.videoIndexForYouTubeUrl(youTubeUrl) {
                let indexPath = NSIndexPath(forRow: index, inSection: 0)
                
                let context = CoreDataController.sharedController.fetchedResultsController.managedObjectContext
                let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
                
                video.title = videoTitle
                video.streamUrl = streamUrlString
                
                self.startDownload(video)
                
                do {
                    try context.save()
                } catch {
                    abort()
                }
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
    
    /**
     Generates a permanent local file path to save a track to by appending the lastPathComponent of the URL to the path of the app's documents directory
     
     - parameter previewUrl: URL of the video
     
     - returns: URL to the file
     */
    func localFilePathForUrl(previewUrl: String) -> NSURL? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        if let url = NSURL(string: previewUrl), lastPathComponent = url.lastPathComponent {
            let fullPath = documentsPath.stringByAppendingPathComponent(lastPathComponent)
            return NSURL(fileURLWithPath:fullPath)
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
        
        if let fileUrl = self.localFilePathForUrl(video.streamUrl!) {
            //Removing the file at the path if one exists
            do {
                try NSFileManager.defaultManager().removeItemAtURL(fileUrl)
            } catch {
                print("No file to remove. Proceeding...")
            }
        }
    }
    
    /**
     Plays video in fullscreen player
     
     - parameter video: video that is going to be played
     */
    func playDownload(video: Video) {
        if let urlString = video.streamUrl, url = self.localFilePathForUrl(urlString) {
            let moviePlayer:MPMoviePlayerViewController! = MPMoviePlayerViewController(contentURL: url)
            self.presentMoviePlayerViewControllerAnimated(moviePlayer)
        }
    }

}

// MARK: VideoCellDelegate

extension MasterViewController: VideoCellDelegate {
    func pauseTapped(cell: VideoCell) {
        if let indexPath = tableView.indexPathForCell(cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
            self.pauseDownload(video)
            tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
        }
    }
    
    func resumeTapped(cell: VideoCell) {
        if let indexPath = tableView.indexPathForCell(cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
            self.resumeDownload(video)
            tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
        }
    }
    
    func cancelTapped(cell: VideoCell) {
        if let indexPath = tableView.indexPathForCell(cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.objectAtIndexPath(indexPath) as! Video
            self.cancelDownload(video)
            tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: indexPath.row, inSection: 0)], withRowAnimation: .None)
        }
    }
}

//MARK: - NSURLSessionDownloadDelegate

extension MasterViewController: NSURLSessionDownloadDelegate {
    
    //Download finished
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        if let originalURL = downloadTask.originalRequest?.URL?.absoluteString, destinationURL = self.localFilePathForUrl(originalURL) {
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
    
    //Updating download status
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let downloadUrl = downloadTask.originalRequest?.URL?.absoluteString, download = self.activeDownloads[downloadUrl] {
            download.progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)
            let totalSize = NSByteCountFormatter.stringFromByteCount(totalBytesExpectedToWrite, countStyle: NSByteCountFormatterCountStyle.Binary)
            if let trackIndex = self.videoIndexForDownloadTask(downloadTask), let videoCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: trackIndex, inSection: 0)) as? VideoCell {
                dispatch_async(dispatch_get_main_queue(), {
                    videoCell.progressView.hidden = false
                    videoCell.progressLabel.hidden = false
                    videoCell.progressView.progress = download.progress
                    videoCell.progressLabel.text =  String(format: "%.1f%% of %@",  download.progress * 100, totalSize)
                })
            }
        }
    }
}

