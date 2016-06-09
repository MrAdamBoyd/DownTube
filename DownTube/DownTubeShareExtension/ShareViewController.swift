//
//  ShareViewController.swift
//  DownTubeShareExtension
//
//  Created by Adam Boyd on 2016-06-08.
//  Copyright © 2016 Adam. All rights reserved.
//

import UIKit
import Social
import MobileCoreServices
import MMWormhole

class ShareViewController: UIViewController {
    
    @IBOutlet weak var textContainer: UIView!
    @IBOutlet weak var mainLabel: UILabel!
    
    let wormhole = MMWormhole(applicationGroupIdentifier: "group.adam.DownTube", optionalDirectory: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Getting the URL of the item
        for item in self.extensionContext!.inputItems {
            if let item = item as? NSExtensionItem {
                for itemProvider in item.attachments! {
                    //Going through each item in each input item
                    if let itemProvider = itemProvider as? NSItemProvider {
                        if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                            //If the item contains a URL
                            itemProvider.loadItemForTypeIdentifier(kUTTypeURL as String, options: nil, completionHandler: { (content, error) -> Void in
                                
                                dispatch_async(dispatch_get_main_queue()) {
                                    if let url = content as? NSURL {
                                        if url.absoluteString.containsString("youtube.com") || url.absoluteString.containsString("youtu.be") {
                                            self.setTitleOfTextView("Video Added to Download Queue")
                                            
                                            //Passing YouTube URL
                                            self.wormhole.passMessageObject(url.absoluteString, identifier: "youTubeUrl")
                                            
                                        return
                                        }
                                    }
                                    
                                    self.setTitleOfTextView("Invalid URL. DownTube only works with YouTube.")
                                }
                            })
                        }
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.alpha = 0
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animateWithDuration(0.25) {
            self.view.alpha = 1
        }
    }
    
    func setTitleOfTextView(text: String) {
        self.mainLabel.text = text
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(3 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            UIView.animateWithDuration(0.25, animations: {
                self.view.alpha = 0
            }, completion: { completed in
                self.extensionContext?.completeRequestReturningItems(nil) { completed in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
            })
        }
    }
    
    func closeExtension() {
        self.dismissViewControllerAnimated(true) { () -> Void in
            self.extensionContext?.completeRequestReturningItems(nil, completionHandler: nil)
        }
    }
}
