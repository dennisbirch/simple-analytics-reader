//
//  QueryModel.swift
//  Analytics Query
//
//  Created by Dennis Birch on 5/4/21.
//

import Cocoa
import os.log

struct QueryModel: Codable {
    var queryItems: [QueryItem]
    var isLimitedSearch: Bool
    var pageLimit: Int
    var whatItems: WhatItems
    var matchType: MatchCondition
}

let savedQueryFileExtension: String = "aqsavedquery"

extension SearchViewController: NSOpenSavePanelDelegate {
    @IBAction func saveSearch(_ sender: Any) {
        guard let searchQueriesVC = searchQueriesViewController else {
            os_log("Search view controller is nil")
            return
        }

        let queryItems = searchQueriesVC.queriesTableView.queryItems.filter{ $0.value.isEmpty == false }
        if queryItems.isEmpty {
            let title = NSLocalizedString("no-queries-to-save-alert-title", comment: "Title for alert when there are no valid queries to save")
            let message = NSLocalizedString("no-queries-to-save-alert-message", comment: "Message for alert when there are no valid queries to save")
            let alert = NSAlert.okAlertWithTitle(title, message: message)
            alert.runModal()
            return
        }
        
        let pageLimit = (searchQueriesVC.isLimitedSearch == true) ? searchQueriesVC.searchLimits.pageLimit : 0
        let model = QueryModel(queryItems: queryItems, isLimitedSearch: searchQueriesVC.isLimitedSearch, pageLimit: pageLimit, whatItems: searchQueriesVC.whatItems, matchType: searchQueriesVC.matchCondition)
        
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(model)
            promptForQuerySaveName(for: data)
        } catch {
            handleSaveOpenFileError(error: error, problem: "saving the query to disk")
        }
    }
    
    private func promptForQuerySaveName(for data: Data) {
        let queryDialog = TextEntryAlertWindowController(prompt: "Enter a unique name for the Query", handler: { name in
            if name.isEmpty { return }
            self.saveSearchData(data, to: name)
        },
        filterCharacters: "./:")
        guard let window = view.window else {
            os_log("Window for presenting query name dialog is nil")
            return
        }
        queryDialog.runSheetOnWindow(window)
    }
    
    private func saveSearchData(_ data: Data, to fileName: String) {
        let url = FileManager.queryFileFolder.appendingPathComponent("\(fileName).\(savedQueryFileExtension)")
        if FileManager.default.fileExists(atPath: url.path) {
            // show an error alert
            let title = NSLocalizedString("duplicate-query-name-alert-title", comment: "Title for duplicate query name alert")
            let format = NSLocalizedString("duplicate-query-name-alert-message %@", comment: "Message for duplicate query name alert")
            let message = String(format: format, fileName)
            let alert = NSAlert.okAlertWithTitle(title, message: message)
            alert.runModal()
            // and rerun name alert
            promptForQuerySaveName(for: data)
            return
        }
        
        // save data to url
        do {
            try data.write(to: url)
        } catch {
            os_log("Error saving query to disk: %@", error.localizedDescription)
        }
    }
    
    @IBAction func loadSavedSearch(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.delegate = self
        openPanel.directoryURL = FileManager.queryFileFolder
        openPanel.allowedFileTypes = [savedQueryFileExtension]
        openPanel.canCreateDirectories = false
        openPanel.allowsOtherFileTypes = false
        openPanel.isExtensionHidden = true
        openPanel.message = "Query to load..."
        let result = openPanel.runModal()
        if result == .OK {
            guard let url = openPanel.url else {
                let alert = NSAlert.okAlertWithTitle("Error", message: "There was an error opening the file")
                alert.runModal()
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                do {
                    let model = try decoder.decode(QueryModel.self, from: data)
                    loadSavedQueries(model)
                } catch {
                    handleSaveOpenFileError(error: error, problem: "opening query file")
                }
            } catch {
                handleSaveOpenFileError(error: error, problem: "opening query file")
            }
        }
    }
    
    @IBAction func showSavedQueries(_ sender: Any) {
        guard let savedQueriesVC = storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(SavedQueriesViewController.viewControllerIdentifier)) as? SavedQueriesViewController else {
            os_log("Can't instantiate saved queries view controller")
            return
        }
        
        savedQueriesVC.files = savedQueryFiles()
        savedQueriesVC.isLoading = false

        presentAsSheet(savedQueriesVC)
    }
    
    private func savedQueryFiles() -> [URL] {
        var files = [URL]()
        guard let fileEnumerator = FileManager.default.enumerator(at: FileManager.queryFileFolder, includingPropertiesForKeys: nil) else {
            os_log("Can't instantiate a file enumerator")
            return files
        }
        for case let fileURL as URL in fileEnumerator {
            if fileURL.pathExtension == savedQueryFileExtension {
                files.append(fileURL)
            }
        }
        
        return files.sorted { url1, url2 in
            return url1.path.lowercased() < url2.path.lowercased()
        }
    }

    private func loadSavedQueries(_ model: QueryModel) {
       searchQueriesViewController?.loadSavedQueries(model)
    }
    
    private func handleSaveOpenFileError(error: Error, problem: String) {
        os_log("Error %@: %@", problem, error.localizedDescription)
        let alert = NSAlert.okAlertWithTitle("Error", message: "There was a problem .")
        alert.runModal()
    }
    
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        if url.path.contains(FileManager.queryFileFolder.path) {
            return true
        } else {
            return false
        }
    }
}
