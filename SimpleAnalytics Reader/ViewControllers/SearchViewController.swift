//
//  SearchViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 4/9/21.
//

import Cocoa
import os.log

class SearchViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, QuerySearchDelegate {
    @IBOutlet private weak var resultsTableView: NSTableView!
    @IBOutlet private weak var queriesContainerView: NSView!
    @IBOutlet private weak var networkActivityIndicator: NSProgressIndicator!
    
    private var items = [AnalyticsItem]()
    var searchQueriesViewController: SearchQueriesViewController?
    private var lastColumn = -1
    private var lastRow = -1

    private struct ColumnHeadings {
        static let number = "#"
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
        
        searchQueriesViewController = queriesVC
        
        view.window?.delegate = self
    }
    
    func updateSearchQueriesViewController() {
        searchQueriesViewController?.searchQueriesChanged()
    }
    
    private func showActivity(_ shouldShow: Bool) {
        networkActivityIndicator.isHidden = (shouldShow == false)
        if shouldShow == true {
            networkActivityIndicator.startAnimation(nil)
        } else {
            networkActivityIndicator.stopAnimation(nil)
        }
    }
    
    @IBAction func showListUI(_ sender: Any) {
        if let tabViewController = parent as? NSTabViewController {
            tabViewController.selectedTabViewItemIndex = 0
        }
    }
    
    private func resetTableView() {
        let sortedItems = items.sorted { item1, item2 in
            return item1.rowNumber < item2.rowNumber
        }
        guard let lastItem = sortedItems.last else {
            os_log("Last sorted item is nil")
            return
        }
        let countString = String(lastItem.rowNumber)
        let width = CGFloat(countString.count * 12)
        guard let countColumn = resultsTableView.tableColumns.first(where: { $0.title == ColumnHeadings.number }) else {
            os_log("Count column is nil")
            return
        }
        countColumn.width = width
    }
    
    // MARK: - Results TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        
        if tableColumn?.title == ColumnHeadings.number {
            let label = NSTextField(labelWithString: "\(item.rowNumber)")
            label.alignment = .right
            return label
        } else if tableColumn?.title == ColumnHeadings.timeStamp {
            return NSTextField(labelWithString: item.timestamp?.shortDateString() ?? "N/A")
        } else if tableColumn?.title == ColumnHeadings.description {
            return NSTextField(labelWithString: item.description)
        } else if tableColumn?.title == ColumnHeadings.details {
            let label = NSTextField(labelWithString: item.details)
            let detail = item.details.formattedForExtendedTooltip()
            if detail.isEmpty == false {
                label.toolTip = detail
                label.allowsExpansionToolTips = true
            }
            return label
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
        
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
          if let sorter = tableColumn.sortDescriptorPrototype,
           let reversed = sorter.reversedSortDescriptor as? NSSortDescriptor {
            if sortItems(with: reversed) == true {
                resetTableView()
                tableView.reloadData()
                tableColumn.sortDescriptorPrototype = reversed
            }
        }
    }
    
    private func sortItems(with sorter: NSSortDescriptor) -> Bool {
        var itemsSorted = true
        switch sorter.key {
        case "number":
            items.sort { (item1, item2) in
                return (item1.rowNumber < item2.rowNumber) == (sorter.ascending == true)
            }
        case "timestamp":
            items.sort { (item1, item2) in
                if let timeStamp1 = item1.timestamp, let timeStamp2 = item2.timestamp {
                    return (timeStamp1 > timeStamp2) == (sorter.ascending == true)
                } else {
                    return true
                }
            }
        case "details":
            items.sort { (item1, item2) in
                return (item1.details > item2.details) == (sorter.ascending == true)
            }
        case "description":
            items.sort { (item1, item2) in
                return (item1.description > item2.description) == (sorter.ascending == true)
            }
        case "count":
            items.sort { (item1, item2) in
                return (item1.count > item2.count) == (sorter.ascending == true)
            }
        case "appName":
            items.sort { (item1, item2) in
                return (item1.appName > item2.appName) == (sorter.ascending == true)
            }
        case "appVersion":
            items.sort { (item1, item2) in
                return (item1.appVersion > item2.appVersion) == (sorter.ascending == true)
            }
        case "platform":
            items.sort { (item1, item2) in
                return (item1.platform > item2.platform) == (sorter.ascending == true)
            }
        case "systemVersion":
            items.sort { (item1, item2) in
                return (item1.systemVersion > item2.systemVersion) == (sorter.ascending == true)
            }
        case "deviceID":
            items.sort { (item1, item2) in
                return (item1.deviceID > item2.deviceID) == (sorter.ascending == true)
            }
        default:
            itemsSorted = false
            break
        }
        
        return itemsSorted
    }
    
    // MARK: - QuerySearchDelegate
    
    func searchBegan() {
        showActivity(true)
    }
    
    func searchCompleted(results: [AnalyticsItem], lastRowNumber: Int) {
        showActivity(false)
        var rowNum = lastRowNumber
        items = results.map{
            rowNum += 1
            return $0.newItemWithRowNumber(rowNum)
        }
        resetTableView()
        resultsTableView.reloadData()
        
        if items.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let title = NSLocalizedString("no-search-results-alert-title", comment: "Title for alert when a query returns no results")
                let message = NSLocalizedString("no-search-results-alert-message", comment: "Explanatory message for alert when a query returns no results")
                NSAlert.presentAlert(title: title, message: message)
            }
        }
    }
}

extension SearchViewController: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        view.updateConstraints()
    }
}
