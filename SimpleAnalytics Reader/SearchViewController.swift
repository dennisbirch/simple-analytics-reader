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
    private var detailView: DetailView?
    
    private var items = [AnalyticsItem]()
    var searchQueriesViewController: SearchQueriesViewController?
    private var cellTrackingArea: NSTrackingArea?
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
        
        updateTrackingAreas()
        searchQueriesViewController = queriesVC
        
        NotificationCenter.default.addObserver(self, selector: #selector(tableViewScrolled(_:)), name: NSScrollView.didLiveScrollNotification, object: nil)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        dismissDetailView()
    }
    
    func updateTrackingAreas() {
        if cellTrackingArea == nil {
            cellTrackingArea = NSTrackingArea(rect: NSRect.zero,
                                              options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                              owner: self, userInfo: nil)
        }
        
        if let area = cellTrackingArea,
           resultsTableView.trackingAreas.contains(area) == false {
            resultsTableView.addTrackingArea(area)
        }
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
        dismissDetailView()
        if let tabViewController = parent as? NSTabViewController {
            tabViewController.selectedTabViewItemIndex = 0
        }
    }
    
    func dismissDetailView() {
        detailView?.removeFromSuperview()
        detailView = nil
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
            return NSTextField(labelWithString: item.timestamp ?? "N/A")
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

    override func mouseMoved(with event: NSEvent) {
        let winLocation = event.locationInWindow
        let tableLoc = view.convert(winLocation, to: resultsTableView)
        let column = resultsTableView.column(at: tableLoc)
        let row = resultsTableView.row(at: tableLoc)
        if column < 0 { return }
        if row < 0 {
            lastRow = row
            return
        }
        
        if column != lastColumn || row != lastRow {
            lastColumn = column
            lastRow = row
            
            let tableColumn = resultsTableView.tableColumns[column]
            if tableColumn.title == ColumnHeadings.details {
                showDetailsContent(row: row, column: column)
            } else {
                dismissDetailView()
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super .mouseExited(with: event)
        dismissDetailView()
    }
    
    @objc func tableViewScrolled(_ notification: Notification) {
        if notification.object as? NSScrollView != resultsTableView.enclosingScrollView { return }
        dismissDetailView()
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
                let alert = NSAlert.okAlertWithTitle(title, message: message)
                alert.runModal()
            }
        }
    }
}

extension SearchViewController {
    private func showDetailsContent(row: Int, column: Int) {
        dismissDetailView()
        
        if let view = resultsTableView.view(atColumn: column, row: row, makeIfNecessary: false) {
            if let label = view as? NSTextField {
                let text = label.stringValue.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
                if text.isEmpty == true {
                    return
                }
                let detail = text.replacingOccurrences(of: ", ", with: "\n")
                showDetailString(detail, column: column, row: row, cellView: view)
            }
        }
    }
        
    private func showDetailString(_ text: String, column: Int, row: Int, cellView: NSView) {
        let columnWidth: CGFloat = 240
        guard let detailView = DetailView.create(with: text, width: columnWidth) else {
            os_log("Couldn't create a detail view")
            return
        }
        
        self.detailView = detailView
        setDetailViewLocation(for: column, row: row, cellView: cellView)
        resultsTableView.addSubview(detailView)
    }
    
    private func setDetailViewLocation(for column: Int, row: Int, cellView: NSView) {
        guard let detailView = self.detailView else {
            return
        }
        
        let detailFrame = detailView.frame
        var cellFrame = cellView.frame
        var originX = cellFrame.origin.x + cellFrame.width
        let convertedTableFrame = resultsTableView.convert(resultsTableView.frame, to: view)
        let availableWidth = view.frame.width - convertedTableFrame.origin.x
        if originX + detailFrame.width > availableWidth {
            originX = cellFrame.origin.x - detailFrame.width
        }
        
        cellFrame = cellView.convert(cellView.frame, to: view)
        let cellYDelta = cellFrame.origin.y + (cellFrame.height * 2) + 20
        let scrollY = resultsTableView.visibleRect.origin.y
        let viewHeight = view.frame.height
        var originY = viewHeight - cellYDelta + scrollY
        let availableSpace = viewHeight - detailFrame.height - originY + scrollY
        if availableSpace < detailFrame.height {
            originY = viewHeight - cellFrame.origin.y - (detailFrame.height * 2)
        }
        
        let newLocation = CGPoint(x: originX, y: originY)
        self.detailView?.frame.origin = newLocation
    }
}
