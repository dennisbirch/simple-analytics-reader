//
//  AppDelegate.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 3/23/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func showOSVersionSummary(_ sender: Any) {
        guard let summaryWC = OSSummaryViewController.createWindowController() else {
            return
        }
        
        summaryWC.showWindow(self)
    }
    

}

