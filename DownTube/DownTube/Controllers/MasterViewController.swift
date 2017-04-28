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
import SafariServices

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    //Commented out because of app group
//    let wormhole = MMWormhole(applicationGroupIdentifier: "group.adam.DownTube", optionalDirectory: nil)
    
    var videoManager: VideoManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem

        let infoButton = UIBarButtonItem(title: "About", style: .plain, target: self, action: #selector(self.showAppInfo(_:)))
        self.navigationItem.rightBarButtonItem = infoButton
        
        CoreDataController.sharedController.fetchedResultsController.delegate = self
        
        self.videoManager = VideoManager(delegate: self)
        
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
    func showAppInfo(_ sender: AnyObject) {
        self.performSegue(withIdentifier: "ShowAppInfo", sender: self)
    }

    /**
     Presents a UIAlertController that gets youtube video URL from user then downloads the video
     
     - parameter sender: button
     */
    @IBAction func enterLinkForVideoAction(_ sender: AnyObject) {
        self.buildAndShowUrlGettingAlertController("Download") { [weak self] text in
            self?.startDownloadOfVideoInfoFor(text)
        }
    }
    
    @IBAction func browseForVideoAction(_ sender: AnyObject) {
        if UserDefaults.standard.bool(forKey: Constants.shownSafariDialog) {
            
            //User has been shown dialog, just show it
            self.showSafariVC()
            
        } else {
            
            //Tell user how to use the safari view controller and then proceed
            UserDefaults.standard.set(true, forKey: Constants.shownSafariDialog)
            let alertVC = UIAlertController(title: "How to Use", message: "Once you've found a video you want to add, hit the share button and select the \"Add to DownTube\" action on the top row.", preferredStyle: .alert)
            alertVC.addAction(UIAlertAction(title: "Got it", style: .default) { [unowned self] _ in
                self.showSafariVC()
            })
            self.present(alertVC, animated: true, completion: nil)
            
        }
    }
    
    /// Shows an SFSafariViewController with youtube loaded
    func showSafariVC() {
        let vc = SFSafariViewController(url: URL(string: "https://youtube.com")!)
        self.present(vc, animated: true, completion: nil)
    }
    
    /**
     Presents a UIAlertController that gets youtube video URL from user then streams the video
     
     - parameter sender: button
     */
    @IBAction func streamVideoAction(_ sender: AnyObject) {
        self.buildAndShowUrlGettingAlertController("Stream") { [weak self] text in
            self?.startStreamOfVideoInfoFor(text)
        }
    }
    
    /**
     Presents a UIAlertController that gets youtube video URL from user, calls completion if successful. Shows error otherwise.
     
     - parameter actionName: title of the AlertController. "<actionName> YouTube Video". Either "Download" or "Stream"
     - parameter completion: code that is called once the user hits "OK." Closure parameter is the text gotten from user
     */
    func buildAndShowUrlGettingAlertController(_ actionName: String, completion: @escaping (String) -> Void) {
        let alertController = UIAlertController(title: "\(actionName) YouTube Video", message: "Video will be shown in 720p or the highest available quality", preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Ok", style: .default) { action in
            let textField = alertController.textFields![0]
            
            if let text = textField.text {
                if text.characters.count > 10 {
                    completion(text)
                } else {
                    self.showErrorAlertControllerWithMessage("URL too short to be valid")
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addTextField() { textField in
            textField.placeholder = "Enter YouTube video URL"
            textField.keyboardType = .URL
            textField.becomeFirstResponder()
            textField.inputAccessoryView = self.buildAccessoryButton()
        }
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    /**
     Builds the button that is the input accessory view that is above the keyboard
     
     - returns:  button for accessory keyboard view
    */
    func buildAccessoryButton() -> UIView {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40))
        button.setTitle("Paste from clipboard", for: UIControlState())
        button.backgroundColor = UIColor(colorLiteralRed: 150/256, green: 150/256, blue: 150/256, alpha: 1)
        button.setTitleColor(UIColor(colorLiteralRed: 75/256, green: 75/256, blue: 75/256, alpha: 1), for: .highlighted)
        button.addTarget(self, action: #selector(self.pasteFromClipboard), for: .touchUpInside)
        
        return button
    }
    
    /**
     Pastes the text from the clipboard in the showing alert vc, if it exists
    */
    func pasteFromClipboard() {
        if let alertVC = self.presentedViewController as? UIAlertController {
            alertVC.textFields![0].text = UIPasteboard.general.string
        }
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
    
    func startStreamOfVideoInfoFor(_ url: String) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        //Gets the video id, which is the last 11 characters of the string
        XCDYouTubeClient.default().getVideoWithIdentifier(String(url.characters.suffix(11))) { video, error in
            
            if let error = error {
                self.showErrorAlertControllerWithMessage(error.localizedDescription)
                return
            }
            
            if let streamUrl = self.highestQualityStreamUrlFor(video) {
                let player = AVPlayer(url: URL(string: streamUrl)!)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                self.present(playerViewController, animated: true) {
                    playerViewController.player!.play()
                }
            }
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
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
        self.configureCell(cell, withVideo: video)
        
        cell.delegate = self
        
        let holdGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongTouchWithGestureRecognizer(_:)))
        holdGestureRecognizer.minimumPressDuration = 1
        cell.addGestureRecognizer(holdGestureRecognizer)
        
        cell.setWatchIndicatorState(video.watchProgress)
        
        //Only show the download controls if video is currently downloading
        var showDownloadControls = false
        if let streamUrl = video.streamUrl, let download = self.videoManager.activeDownloads[streamUrl] {
            showDownloadControls = true
            cell.progressView.progress = download.progress
            cell.progressLabel.text = (download.isDownloading) ? "Downloading..." : "Paused"
            let title = (download.isDownloading) ? "Pause" : "Resume"
            cell.pauseButton.setTitle(title, for: UIControlState())
        }
        cell.progressView.isHidden = !showDownloadControls
        cell.progressLabel.isHidden = !showDownloadControls
        
        //Hiding or showing the download button
        let downloaded = self.videoManager.localFileExistsFor(video)
        cell.selectionStyle = downloaded ? .gray : .none
        
        //Hiding or showing the cancel and pause buttons
        cell.pauseButton.isHidden = !showDownloadControls
        cell.cancelButton.isHidden = !showDownloadControls
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
        if self.videoManager.localFileExistsFor(video) {
            self.playDownload(video, atIndexPath: indexPath)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.isCellAtIndexPathDownloading(indexPath) ? 92 : 57
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
        
        var labelText = "Downloaded"
        if let year = components.year, let month = components.month, let day = components.day {
            labelText += " on \(year)/\(month)/\(day)"
        }
        cell.dateLabel.text = labelText
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
    
    func isCellAtIndexPathDownloading(_ indexPath: IndexPath) -> Bool {
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
        if let streamUrl = video.streamUrl {
            return self.videoManager.activeDownloads[streamUrl] != nil
        }
        
        return false
    }
    
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
    func messageWasReceivedFromExtension(_ message: Any?) {
        if let message = message as? String {
            
            //Remove the item at the end of the list from the list of items to add when the app opens
            var existingItems = Constants.sharedDefaults.object(forKey: Constants.videosToAdd) as! [String]
            existingItems.removeLast()
            Constants.sharedDefaults.set(existingItems, forKey: Constants.videosToAdd)
            Constants.sharedDefaults.synchronize()
            
            self.startDownloadOfVideoInfoFor(message)
        }
    }
    
    //MARK: - Helper methods
    
    /**
     Gets the highest quality video stream Url
     
     - parameter video:      optional video object that was downloaded, contains stream info, title, etc.

     - returns:              optional string containing the highest quality video stream
     */
    func highestQualityStreamUrlFor(_ video: XCDYouTubeVideo?) -> String? {
        var streamUrl: String?
        guard let video = video else { return nil }
        let streamURLs = NSDictionary(dictionary: video.streamURLs)
        
        if let highQualityStream = streamURLs[XCDYouTubeVideoQuality.HD720.rawValue] as? URL {
            
            //If 720p video exists
            streamUrl = highQualityStream.absoluteString
            
        } else if let mediumQualityStream = streamURLs[XCDYouTubeVideoQuality.medium360.rawValue] as? URL {
            
            //If 360p video exists
            streamUrl = mediumQualityStream.absoluteString
            
        } else if let lowQualityStream = streamURLs[XCDYouTubeVideoQuality.small240.rawValue] as? URL {
            
            //If 240p video exists
            streamUrl = lowQualityStream.absoluteString
        }
        
        return streamUrl
    }
    
    /**
     Called when the video info for a video is downloaded
     
     - parameter video:      optional video object that was downloaded, contains stream info, title, etc.
     - parameter youTubeUrl: youtube URL of the video
     - parameter error:      optional error
     */
    func videoObject(_ video: XCDYouTubeVideo?, downloadedForVideoAt youTubeUrl: String, error: NSError?) {
        if let videoTitle = video?.title {
            print("\(videoTitle)")
            
            if let video = video, let streamUrl = self.highestQualityStreamUrlFor(video) {
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
        guard self.videoManager.videoIndexForYouTubeUrl(youTubeUrl) == nil else {
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
        self.videoManager.startDownload(newVideo) { index in
            self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
    }
    
    /**
     Shows error to user in UIAlertController and then removes all errored out videos from core data
     
     - parameter error: error from getting the video info
     */
    func showErrorAndRemoveErroredVideos(_ error: NSError?) {
        //Show error to user, remove all unused cells from list
        DispatchQueue.main.async {
            if let error = error {
                print("Couldn't get video: \(error.localizedDescription)")
            } else {
                print("Couldn't get video: unknown error")
            }
            
            let message = error?.localizedDescription
            self.showErrorAlertControllerWithMessage(message)
        }
        
        //Getting all blank videos with no downloaded data
        var objectsToRemove: [IndexPath] = []
        for (index, video) in CoreDataController.sharedController.fetchedResultsController.fetchedObjects!.enumerated() {
            
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
        
        if let safariVC = self.presentedViewController as? SFSafariViewController {
            //Safari VC is presented, show it there
            safariVC.present(alertController, animated: true, completion: nil)
        } else {
            //Show on this VC
            self.present(alertController, animated: true, completion: nil)
        }
        
    }
    
    /**
     Deletes the file for the video at the index path
     
     - parameter indexPath: index path of the cell that represents the video
     */
    func deleteDownloadedVideoAt(_ indexPath: IndexPath) {
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
        self.videoManager.cancelDownload(video)
        
        if let urlString = video.streamUrl, let fileUrl = self.videoManager.localFilePathForUrl(urlString) {
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
        let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
        
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
        if let urlString = video.streamUrl, let url = self.videoManager.localFilePathForUrl(urlString) {
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
        if gestureRecognizer.state == .changed || gestureRecognizer.state == .ended {
            
            let point = gestureRecognizer.location(in: self.tableView)
            guard let indexPath = self.tableView.indexPathForRow(at: point) else {
                return
            }
            
            let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
            
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
            actions.append(UIAlertAction(title: "Mark as Watched", style: .default) { [unowned self] _ in
                video.watchProgress = .watched
                CoreDataController.sharedController.saveContext()
                self.tableView.reloadRows(at: [indexPath], with: .none)
            })
        }
        
        //If the user progress isn't 0, the video is either partially watched or done
        if video.watchProgress != .unwatched {
            actions.append(UIAlertAction(title: "Mark as Unwatched", style: .default) { [unowned self] _ in
                video.watchProgress = .unwatched
                CoreDataController.sharedController.saveContext()
                self.tableView.reloadRows(at: [indexPath], with: .none)
            })
        }
        
        //Sharing the video
        if let streamUrl = video.streamUrl, let localUrl = self.videoManager.localFilePathForUrl(streamUrl) {
            
            if let localPath = self.videoManager.localFileLocationForUrl(streamUrl) {
                actions.append(UIAlertAction(title: "Edit Video", style: .default) { [unowned self] _ in
                    let editor = UIVideoEditorController()
                    editor.delegate = self
                    editor.videoPath = localPath
                    editor.videoMaximumDuration = 0
                    editor.videoQuality = .typeIFrame1280x720
                    
                    self.videoManager.currentlyEditingVideo = video
                    
                    self.present(editor, animated: true, completion: nil)
                })
            }
            
            actions.append(UIAlertAction(title: "Share", style: .default) { [unowned self] _ in
                let activityViewController = UIActivityViewController(activityItems: [localUrl], applicationActivities: nil)
                self.present(activityViewController, animated: true, completion: nil)
            })
        }
        
        return actions
        
    }

}

// MARK: VideoTableViewCellDelegate

extension MasterViewController: VideoTableViewCellDelegate {
    func pauseTapped(_ cell: VideoTableViewCell) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
            self.videoManager.pauseDownload(video)
            self.tableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
        }
    }
    
    func resumeTapped(_ cell: VideoTableViewCell) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
            self.videoManager.resumeDownload(video)
            self.tableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
        }
    }
    
    func cancelTapped(_ cell: VideoTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            let video = CoreDataController.sharedController.fetchedResultsController.object(at: indexPath)
            self.videoManager.cancelDownload(video)
            tableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
            self.deleteVideoObjectAt(indexPath)
        }
    }
}

// MARK: - VideoManagerDelegate

extension MasterViewController: VideoManagerDelegate {
    func reloadRows(_ rows: [IndexPath]) {
        DispatchQueue.main.async() {
            self.tableView.reloadRows(at: rows, with: .none)
        }
    }
    
    func updateDownloadProgress(_ download: Download, at index: Int, with totalSize: String) {
        DispatchQueue.main.async() {
            if let videoTableViewCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? VideoTableViewCell {
            
                let done = (download.progress == 1)
                
                videoTableViewCell.progressView.isHidden = done
                videoTableViewCell.progressLabel.isHidden = done
                videoTableViewCell.progressView.progress = download.progress
                videoTableViewCell.progressLabel.text = String(format: "%.1f%% of %@", download.progress * 100, totalSize)
                if done {
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                }
            }
        }
    }
}

extension MasterViewController: UINavigationControllerDelegate, UIVideoEditorControllerDelegate {
    func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        self.videoManager.saveCurrentlyEditedVideo(editedVideoPath)
        
        self.tableView.reloadData()
        editor.dismiss(animated: true, completion: nil)
    }
    
    func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
        print("Error: " + error.localizedDescription)
        self.videoManager.currentlyEditingVideo = nil
        editor.dismiss(animated: true, completion: nil)
    }
    
    func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        print("User cancelled edit of video")
        self.videoManager.currentlyEditingVideo = nil
        editor.dismiss(animated: true, completion: nil)
    }
}
