//
//  SearchViewController.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/9/21.
//

import Cocoa

class SearchViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, QuerySearchDelegate {
    @IBOutlet private weak var resultsTableView: NSTableView!
    @IBOutlet private weak var queriesContainerView: NSView!
    
    private var items = [AnalyticsItem]()
    

    private struct ColumnHeadings {
        static let timeStamp = "Date/Time"
        static let description = "Description"
        static let details = "Details"
        static let count = "Count"
        static let appName = "App name"
        static let appVersion = "App version"
        static let platform = "Platform"
        static let systemVersion = "OS version"
        static let deviceID = "Device ID"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        queriesContainerView.wantsLayer = true
        queriesContainerView.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        
        guard let queriesVC = storyboard?.instantiateController(withIdentifier: SearchQueriesViewController.viewControllerIdentifier) as? SearchQueriesViewController else {
            return
        }
        let queriesView = queriesVC.view
        addChild(queriesVC)
        queriesContainerView.addSubview(queriesView)
        queriesVC.searchDelegate = self
        queriesView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([queriesView.leadingAnchor.constraint(equalTo: queriesContainerView.leadingAnchor),
                                     queriesView.trailingAnchor.constraint(equalTo: queriesContainerView.trailingAnchor),
                                     queriesView.topAnchor.constraint(equalTo: queriesContainerView.topAnchor),
                                     queriesView.bottomAnchor.constraint(equalTo: queriesContainerView.bottomAnchor)])
    }
    
    // MARK: - Results TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        
        if tableColumn?.title == ColumnHeadings.timeStamp {
            return NSTextField(labelWithString: item.timestamp)
        } else if tableColumn?.title == ColumnHeadings.description {
            return NSTextField(labelWithString: item.description)
        } else if tableColumn?.title == ColumnHeadings.details {
            return NSTextField(labelWithString: item.details)
        } else if tableColumn?.title == ColumnHeadings.count {
            let countLabel = NSTextField(labelWithString: item.count)
            countLabel.alignment = .right
            return countLabel
        } else if tableColumn?.title == ColumnHeadings.appName {
            return NSTextField(labelWithString: item.appName)
        } else if tableColumn?.title == ColumnHeadings.appVersion {
            return NSTextField(labelWithString: item.appVersion)
        } else if tableColumn?.title == ColumnHeadings.platform {
            return NSTextField(labelWithString: item.platform)
        } else if tableColumn?.title == ColumnHeadings.systemVersion {
            return NSTextField(labelWithString: item.systemVersion)
        } else if tableColumn?.title == ColumnHeadings.deviceID {
            return NSTextField(labelWithString: item.deviceID)
        }

        return nil
    }
    

    // MARK: - QuerySearchDelegate
    
    func searchCompleted(results: [AnalyticsItem]) {
        items = results
        resultsTableView.reloadData()
    }
}
