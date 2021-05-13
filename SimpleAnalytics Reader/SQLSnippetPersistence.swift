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
        guard let savedSnippetsVC = savedSnippetsViewController() else {
            return
        }

        savedSnippetsVC.configureForExecutingSQL(files: savedSnippetFiles()) { [weak self] (url) in
            self?.executeSnippetWithURL(url)
        }
        
        presentAsSheet(savedSnippetsVC)
    }
    
    @IBAction func showSQLSnippets(_ sender: Any) {
        guard let savedSnippetsVC = savedSnippetsViewController() else {
            return
        }

        savedSnippetsVC.configureForDeleting(files: savedSnippetFiles())
        presentAsSheet(savedSnippetsVC)
    }
    
    private func savedSnippetsViewController() -> SavedQueriesViewController? {
        guard let savedSnippetsVC = storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(SavedQueriesViewController.viewControllerIdentifier)) as? SavedQueriesViewController else {
            os_log("Can't instantiate saved queries view controller")
            return nil
        }
        
        return savedSnippetsVC
    }
    
    private func showModelessWindow(from viewController: NSViewController) {
        let nonModalWindow = NSWindow(contentViewController: viewController)
        nonModalWindow.stripTitleChrome()
        let windowController = NSWindowController(window: nonModalWindow)
        windowController.showWindow(self)
    }
    
    private func executeSnippetWithURL(_ url: URL) {
        do {
            let snippet = try String(contentsOf: url, encoding: .utf8)
            runSQLSnippet(snippet)
        } catch {
            os_log("Error getting contents of snippet file: %@", error.localizedDescription)
        }
    }

    private func savedSnippetFiles() -> [URL] {
        var files = [URL]()
        guard let fileEnumerator = FileManager.default.enumerator(at: FileManager.simpleAnalyticsSupportFolder, includingPropertiesForKeys: nil) else {
            os_log("Can't instantiate a file enumerator")
            return files
        }
        for case let fileURL as URL in fileEnumerator {
            if fileURL.pathExtension == savedSnippetFileExtension {
                files.append(fileURL)
            }
        }
        
        return files.sorted { url1, url2 in
            return url1.path.lowercased() < url2.path.lowercased()
        }
    }

    private func promptForSnippetSQLAndName(_ sqlSnippet: String = "") {
        guard let saveVC = storyboard?.instantiateController(withIdentifier: ExecuteAndSaveSQLViewController.viewControllerIdentifier) as? ExecuteAndSaveSQLViewController else {
            os_log("Can't instantiate view controller to save snippet")
            return
        }
        
        saveVC.delegate = self
        saveVC.configureForSaving(sql: sqlSnippet)
        showModelessWindow(from: saveVC)
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
