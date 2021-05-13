//
//  SQLSnippetPersistence.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/12/21.
//

import Cocoa
import os.log

let savedSnippetFileExtension: String = "sarsavedsnippet"

extension SearchViewController: SQLSnippetPersistenceDelegate {
    @IBAction func saveSQLSnippet(_ sender: Any) {
        promptForSnippetSQLAndName()
    }
    
    @IBAction func loadSQLSnippet(_ sender: Any) {
        
    }
    
    @IBAction func showSQLSnippets(_ sender: Any) {
        
    }

    @IBAction func executeSQLSnippet(_ sender: Any) {
        
    }

    private func promptForSnippetSQLAndName(_ sqlSnippet: String = "") {
        guard let saveVC = storyboard?.instantiateController(withIdentifier: ExecuteAndSaveSQLViewController.viewControllerIdentifier) as? ExecuteAndSaveSQLViewController else {
            os_log("Can't instantiate view controller to save snippet")
            return
        }
        
        saveVC.delegate = self
        saveVC.configureForSaving(sql: sqlSnippet)
                
        let nonModalWindow = NSWindow(contentViewController: saveVC)
        nonModalWindow.titleVisibility = .hidden
        nonModalWindow.standardWindowButton(.closeButton)?.isHidden = true
        nonModalWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        nonModalWindow.standardWindowButton(.zoomButton)?.isHidden = true
        let windowController = NSWindowController(window: nonModalWindow)
        windowController.showWindow(self)
    }

    func saveSnippet(_ snippet: String, with fileName: String) {
        let fileURL = FileManager.simpleAnalyticsSupportFolder.appendingPathComponent(fileName).appendingPathExtension(savedSnippetFileExtension)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let title = NSLocalizedString("duplicate-snippet-name-alert-title", comment: "Title for duplicate snippet name alert")
            let format = NSLocalizedString("duplicate-snippet-name-alert-message %@", comment: "Message for duplicate snippet name alert")
            let message = String(format: format, fileName)
            let alert = NSAlert.okAlertWithTitle(title, message: message)
            alert.runModal()
            promptForSnippetSQLAndName(snippet)
            return
        }
        
        do {
            try snippet.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            os_log("Error saving snippet: %@", error.localizedDescription)
        }
    }
    
    func runSQLSnippet(_ snippet: String) {
        searchQueriesViewController?.executeSQL(snippet, isLimitedSearch: false)
    }
}
