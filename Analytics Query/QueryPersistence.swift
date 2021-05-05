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

extension SearchQueriesViewController: NSOpenSavePanelDelegate {
    private var savedQueryFileExtension: String {
        return "aqsavedquery"
    }

    @IBAction func saveSearch(_ sender: Any) {
        let queryItems = queriesTableView.queryItems.filter{ $0.value.isEmpty == false }
        if queryItems.isEmpty {
            let title = NSLocalizedString("no-queries-to-save-alert-title", comment: "Title for alert when there are no valid queries to save")
            let message = NSLocalizedString("no-queries-to-save-alert-message", comment: "Message for alert when there are no valid queries to save")
            let alert = NSAlert.okAlertWithTitle(title, message: message)
            alert.runModal()
            return
        }
        
        let pageLimit = (isLimitedSearch == true) ? searchLimits.pageLimit : 0
        let model = QueryModel(queryItems: queryItems, isLimitedSearch: isLimitedSearch, pageLimit: pageLimit, whatItems: whatItems, matchType: matchCondition)
        let savePanel = NSSavePanel()
        savePanel.delegate = self
        savePanel.allowedFileTypes = [savedQueryFileExtension]
        savePanel.canCreateDirectories = false
        savePanel.allowsOtherFileTypes = false
        savePanel.isExtensionHidden = true
        savePanel.message = "Save Query as..."
        savePanel.directoryURL = queryFileFolder
        let result = savePanel.runModal()
        if result == .OK {
            guard let url = savePanel.url else {
                let alert = NSAlert.okAlertWithTitle("Error", message: "There was a problem saving the query to disk.")
                alert.runModal()
                return
            }
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(model)
                do {
                    try data.write(to: url)
                } catch {
                    handleSaveOpenFileError(error: error, problem: "saving the query to disk")
                }
            } catch {
                handleSaveOpenFileError(error: error, problem: "saving the query to disk")
            }
        }
    }
    
    @IBAction func loadSavedSearch(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.delegate = self
        openPanel.directoryURL = queryFileFolder
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
                    // TODO: Load UI from saved model
                    print("Model opened: \(model)")
                } catch {
                    handleSaveOpenFileError(error: error, problem: "opening query file")
                }
            } catch {
                handleSaveOpenFileError(error: error, problem: "opening query file")
            }
        }
    }

    private func handleSaveOpenFileError(error: Error, problem: String) {
        os_log("Error %@: %@", problem, error.localizedDescription)
        let alert = NSAlert.okAlertWithTitle("Error", message: "There was a problem .")
        alert.runModal()
    }
    
    private var queryFileFolder: URL {
        do {
            let fileMgr = FileManager.default
            let appSupportFolder = try fileMgr.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let queryFolder = appSupportFolder.appendingPathComponent("Analytics Query", isDirectory: true)
            if fileMgr.fileExists(atPath: queryFolder.path) == false {
                do {
                    try fileMgr.createDirectory(at: queryFolder, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    fatalError("Error creating queries folder: \(error)")
                }
            }

            return queryFolder
        } catch {
            fatalError("Can't access the Application Support folder: \(error)")
        }
    }
    
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        if url.path.contains(queryFileFolder.path) {
            return true
        } else {
            return false
        }
    }
}
