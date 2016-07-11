//
//  WebViewController.swift
//  DownTube
//
//  Created by Simon Meusel on 11/07/16.
//  Copyright © 2016 Adam. All rights reserved.
//

import UIKit

class WebViewController: UIViewController, UIWebViewDelegate {
    
    var masterViewController: MasterViewController!
    
    @IBOutlet weak var webView: UIWebView!
    
    @IBOutlet weak var addressBar: UITextField!
    
    @IBOutlet weak var downloadButton: UIBarButtonItem!
    
    /**
     Called when the view loaded
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView!.delegate = self
        
        addressBar.text = "https://youtube.com"
        let request = NSURLRequest(URL: NSURL(string: addressBar.text!)!)
        webView!.loadRequest(request)
        
    }
    
    /**
     Called when finished loading a page
     
     - parameter webView: webView Web view that finished loading a page
    */
    func webViewDidFinishLoad(webView: UIWebView) {
        addressBar.text = self.webView.request?.URL?.absoluteString
    }
    
    /**
     Called when the go to url button was pressed
     
     - parameter sender: button that was pressed
     */
    @IBAction func goToURL(sender: UIButton) {
        let request = NSURLRequest(URL: NSURL(string: addressBar.text!)!)
        webView!.loadRequest(request)
    }
    
    /**
     Called when the go back button was pressed
     
     - parameter sender: button that was pressed
     */
    @IBAction func goBack(sender: UIButton) {
        webView.goBack()
    }
    
    /**
     Called when the go forward button was pressed
     
     - parameter sender: button that was pressed
     */
    @IBAction func goForward(sender: UIButton) {
        webView.goForward()
    }
    
    /**
     Called when the download button was pressed
     
     - parameter sender: button that was pressed
     */
    @IBAction func download(sender: UIBarButtonItem) {
        downloadButton.enabled = false
        // koya.onEvent(); reloads the page with the video's url. Else the url is always m.youtube.com (Tested on IOS Simulator IPhone 6+)
        print(webView.stringByEvaluatingJavaScriptFromString("koya.onEvent();"))
        let _ = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: #selector(self.downloadVideo(_:)), userInfo: nil, repeats: false)
    }
    
    /**
     Called when a download should happen
     
     - parameter sender: sender of the download request
     */
    func downloadVideo(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
        masterViewController.startDownloadOfVideoInfoFor((webView.request!.URL?.absoluteString)!)
        self.navigationController?.popViewControllerAnimated(true);
    }

    /**
     Called when the download button was pressed
     
     - parameter sender: text field of that the value changed
     */
    @IBAction func urlChanged(sender: AnyObject) {
        let url = addressBar.text;
        if (url?.characters.count)! > 10 && (url?.containsString("youtube.com"))! && (url?.containsString("youtu.be"))! {
            downloadButton.enabled = true
        } else {
            downloadButton.enabled = false
        }
    }
    
}
