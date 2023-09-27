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
        if ListViewController.sharedApps.isEmpty {
            let msg = "The application has no application data to include in a summary. Please make sure the app has successfully loaded application names from your analytics database before continuing."
            NSAlert.presentAlert(title: "No Applications", message: msg)
            return
        }
        
        guard let summaryWC = OSSummaryViewController.createWindowController() else {
            return
        }
        
        summaryWC.showWindow(self)
    }
    

}

