//
//  DownTubeUITests.swift
//  DownTubeUITests
//
//  Created by Adam Boyd on 2016-05-30.
//  Copyright © 2016 Adam. All rights reserved.
//

import XCTest

class DownTubeUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testValidURL() {
        
        let app = XCUIApplication()
        
        app.navigationBars["DownTube"].buttons["Add"].tap()
        
        let collectionViewsQuery = app.alerts["Download YouTube Video"].collectionViews
        collectionViewsQuery.textFields["Enter YouTube video URL"].typeText("https://www.youtube.com/watch?v=tPEE9ZwTmy0")
        collectionViewsQuery.buttons["Ok"].tap()
        
        //Wait for video to be downloaded
        sleep(5)
        
        let downtubeNavigationBar = app.navigationBars["DownTube"]
        downtubeNavigationBar.buttons["Edit"].tap()
        
        let tablesQuery = app.tables
        tablesQuery.buttons["Delete Shortest Video on Youtube, Downloaded on 2016/6/6"].tap()
        tablesQuery.buttons["Delete"].tap()
        downtubeNavigationBar.buttons["Done"].tap()
        
    }
    
    func testNonValidURL() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let app = XCUIApplication()

        app.navigationBars["DownTube"].buttons["Add"].tap()
        
        let collectionViewsQuery = app.alerts["Download YouTube Video"].collectionViews
        collectionViewsQuery.textFields["Enter YouTube video URL"].typeText("not a valid URL")
        collectionViewsQuery.buttons["Ok"].tap()
        
        //Wait for the URL to be processed
        sleep(5)
        app.alerts["Error"].collectionViews.buttons["Ok"].tap()
    }
}
