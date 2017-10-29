//
//  CoreDataController.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-05-30.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation
import CoreData
import XCDYouTubeKit

class CoreDataController {
    static let sharedController = CoreDataController()

    // MARK: - Core Data Stack
    
    //Fetched videos
    var fetchedVideosController: NSFetchedResultsController<Video> {
        if let controller = _fetchedVideosController {
            return controller
        }
        _fetchedVideosController = self.createControllerWithFetchRequest(Video.fetchRequest(), search: nil, isDownloaded: nil)
        return _fetchedVideosController!
    }
    private var _fetchedVideosController: NSFetchedResultsController<Video>?
    
    //Fetched streamed videos
    var fetchedStreamingVideosController: NSFetchedResultsController<StreamingVideo> {
        if let controller = _fetchedStreamingVideosController {
            return controller
        }
        _fetchedStreamingVideosController = self.createControllerWithFetchRequest(StreamingVideo.fetchRequest(), search: nil, isDownloaded: nil)
        return _fetchedStreamingVideosController!
    }
    private var _fetchedStreamingVideosController: NSFetchedResultsController<StreamingVideo>?
    
    /// Creates a fetched results controller for the entity type
    ///
    /// - Parameter fetchRequest: request type that contains the entity
    /// - Returns: fetched results controller
    func createControllerWithFetchRequest<T>(_ fetchRequest: NSFetchRequest<T>, search: String?, isDownloaded: Bool?) -> NSFetchedResultsController<T> {
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        //Sort by name
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = self.predicatesWithSearch(search, isDownloaded: isDownloaded)
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try aFetchedResultsController.performFetch()
        } catch {
            print("Could not save to Core Data")
        }
        
        return aFetchedResultsController
    }

    /// Creates a new fetch result controller with the search provided. If no search, returns all
    ///
    /// - Parameter search: search to use as an NSPredicate
    func createVideosFetchedResultsControllerWithSearch(_ search: String?, isDownloaded: Bool?) -> NSFetchedResultsController<Video> {
        return self.createControllerWithFetchRequest(Video.fetchRequest(), search: search, isDownloaded: isDownloaded)
    }
    
    private func predicatesWithSearch(_ search: String?, isDownloaded: Bool?) -> NSCompoundPredicate {
        var predicates: [NSPredicate] = []
        if let search = search, search != "" {
            //Searching the title
            let predicate = NSPredicate(format: "title CONTAINS[cd] %@", search)
            predicates.append(predicate)
        }
        
        if let isDownloadedPredicate = isDownloaded {
            //Searching if item is downloaded
            let predicate = NSPredicate(format: "isDoneDownloading == %@", NSNumber(value: isDownloadedPredicate))
            predicates.append(predicate)
        }
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates) //Doesn't matter if empty
    }
    
    /// Sets the predicate for the fetched videos controller and performs the fetch
    ///
    /// - Parameters:
    ///   - search: search, optional
    ///   - isDownloaded: if true, only looks for downloaded video
    func setSearchForDownloadedVideos(_ search: String?, isDownloaded: Bool?) {
        self.fetchedVideosController.fetchRequest.predicate = self.predicatesWithSearch(search, isDownloaded: isDownloaded)
        
        do {
            try self.fetchedVideosController.performFetch()
        } catch let error {
            print("Could not search for videos: \(error)")
        }
    }
    
    
    //Rest of the core data stack
    
    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.adam.Downtube" in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "DownTube", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
        } catch {
            // Report any error we got.
            var dict = [String: Any]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9_999, userInfo: dict)
            
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort() //Abort here if something goes really wrong
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    // MARK: - Creating items
    
    func createNewVideo(youTubeUrl: String, streamUrl: String, videoObject: XCDYouTubeVideo?) -> Video {
        var newVideo = NSEntityDescription.insertNewObject(forEntityName: Video.entityName, into: self.managedObjectContext) as! Video
        
        newVideo.created = Date()
        newVideo.isDoneDownloading = NSNumber(value: false)
        newVideo.youtubeUrl = youTubeUrl
        newVideo.title = videoObject?.title
        newVideo.streamUrl = streamUrl
        newVideo.watchProgress = .unwatched
        
        self.saveContext()
        
        return newVideo
    }
    
    func createNewStreamingVideo(youTubeUrl: String, streamUrl: String, videoObject: XCDYouTubeVideo?) -> StreamingVideo {
        var newVideo = NSEntityDescription.insertNewObject(forEntityName: StreamingVideo.entityName, into: self.managedObjectContext) as! StreamingVideo
        
        newVideo.youtubeUrl = youTubeUrl
        newVideo.title = videoObject?.title
        newVideo.streamUrl = streamUrl
        newVideo.watchProgress = .unwatched
        
        self.saveContext()
        
        return newVideo
    }
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch let error as NSError {
                print("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}
