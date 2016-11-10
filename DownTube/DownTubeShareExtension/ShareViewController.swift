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
                            itemProvider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (content, error) -> Void in
                                
                                DispatchQueue.main.async {
                                    if let url = content as? URL {
                                        if url.absoluteString.contains("youtube.com") || url.absoluteString.contains("youtu.be") {
                                            self.setTitleOfTextView("Video Added to Download Queue")
                                            
                                            //Just in case the app isn't running in the background, write the URL to the shared NSUserDefaults
                                            var existingItems = Constants.sharedDefaults.value(forKey: Constants.videosToAdd) as! [String]
                                            existingItems.append(url.absoluteString)
                                            Constants.sharedDefaults.set(existingItems, forKey: Constants.videosToAdd)
                                            Constants.sharedDefaults.synchronize()
                                            
                                            //Passing YouTube URL
                                            self.wormhole.passMessageObject(url.absoluteString as NSCoding?, identifier: "youTubeUrl")
                                            
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 1
        }) 
    }
    
    func setTitleOfTextView(_ text: String) {
        self.mainLabel.text = text
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(3 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            UIView.animate(withDuration: 0.25, animations: {
                self.view.alpha = 0
            }, completion: { completed in
                self.extensionContext?.completeRequest(returningItems: nil) { completed in
                    self.dismiss(animated: true, completion: nil)
                }
            })
        }
    }
    
    func closeExtension() {
        self.dismiss(animated: true) { () -> Void in
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
