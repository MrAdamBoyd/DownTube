//
//  VideoEditingDelegate.swift
//  DownTube
//
//  Created by Adam on 8/9/17.
//  Copyright © 2017 Adam. All rights reserved.
//

import Foundation
import UIKit

protocol VideoEditingHandlerDelegate: class {
    var tableView: UITableView! { get set }
    var videoManager: VideoManager! { get set }
}

class VideoEditingHandler: NSObject, UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
    weak var delegate: VideoEditingHandlerDelegate!
    
    func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        self.delegate.videoManager.saveCurrentlyEditedVideo(editedVideoPath)
        
        self.delegate.tableView.reloadData()
        editor.dismiss(animated: true, completion: nil)
    }
    
    func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
        print("Error: " + error.localizedDescription)
        self.delegate.videoManager.currentlyEditingVideo = nil
        editor.dismiss(animated: true, completion: nil)
    }
    
    func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        print("User cancelled edit of video")
        self.delegate.videoManager.currentlyEditingVideo = nil
        editor.dismiss(animated: true, completion: nil)
    }
}
