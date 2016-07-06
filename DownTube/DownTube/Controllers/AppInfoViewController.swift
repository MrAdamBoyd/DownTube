//
//  AppInfoViewController.swift
//  DownTube
//
//  Created by Adam Boyd on 2016-07-05.
//  Copyright © 2016 Adam. All rights reserved.
//

import Foundation
import UIKit
import SafariServices

class AppInfoViewController: UIViewController {
    
    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: #selector(self.dismissInfoViewController(_:)))
        
        let versionString = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"] as! String
        self.versionLabel.text = "Version \(versionString)"
    }
    
    /**
     Dismisses this view controller and its navigation controller
     
     - parameter sender: button that sent action
     */
    func dismissInfoViewController(sender: AnyObject) {
        self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    /**
     Goes to the github page for this project
     
     - parameter sender: button that sent action
     */
    @IBAction func goToGitHub(sender: AnyObject) {
        let vc = SFSafariViewController(URL: NSURL(string: "https://github.com/MrAdamBoyd/DownTube")!, entersReaderIfAvailable: false)
        self.presentViewController(vc, animated: true, completion: nil)
    }
}
