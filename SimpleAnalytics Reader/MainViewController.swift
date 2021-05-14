//
//  MainViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 3/24/21.
//

import Cocoa

class MainViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet private weak var appTable: NSTableView!
    @IBOutlet private weak var platformTable: NSTableView!
    @IBOutlet private weak var actionsTable: NSTableView!
    @IBOutlet private weak var countersTable: NSTableView!
    @IBOutlet private weak var detailsTable: NSTableView!
    @IBOutlet private weak var activityIndicator: NSProgressIndicator!
    @IBOutlet private weak var refreshButton: NSButton!
    
    private var applications = [String]()
    private var platforms = [String]()
    private var actions = [String : String]()
    private var actionsArray = [String]()
    private var counters = [String : String]()
    private var countsArray = [String]()
    private var details = [[String : String]]()
    
    private let windowFrameKey = "main.window.frame"
    private let noDetails = "----"
    
    // MARK: - ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        platformTable.tableColumns[0].width = platformTable.bounds.width
        
        requestApplicationNames()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.setFrameUsingName(windowFrameKey)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        view.window?.saveFrame(usingName: windowFrameKey)
    }
    
    // MARK: - Actions
    
    @IBAction func refreshTapped(_ sender: Any) {
        requestApplicationNames()
    }
    
    @IBAction func showSearchUI(_ sender: Any) {
        if let tabViewController = parent as? NSTabViewController {
            tabViewController.selectedTabViewItemIndex = 1
        }
    }
    
    // MARK: - Private Methods
    
    private func showActivityIndicator(_ shouldShow: Bool) {
        DispatchQueue.main.async { [weak self] in
            if shouldShow == true {
                self?.activityIndicator.isHidden = false
                self?.activityIndicator.startAnimation(nil)
            } else {
                self?.activityIndicator.stopAnimation(nil)
            }
            
            self?.refreshButton.isHidden = shouldShow
        }
    }
    
    private func requestApplicationNames() {
        let itemsQuery = DBAccess.query(what: Common.appName, from: Items.table, isDistinct: true)
        let countersQuery = DBAccess.query(what: Common.appName, from: Counters.table, isDistinct: true)
        
        showActivityIndicator(true)
        resetDataStorage(startingTable: appTable)

        let itemSubmitter = QuerySubmitter(query: itemsQuery, mode: .array) { (result) in
            guard let result = result as? [[String]] else {
                return
            }
            var apps = result.compactMap{ $0.first }
            let countsSubmitter = QuerySubmitter(query: countersQuery, mode: .array) { [weak self] result in
                guard let result = result as? [[String]] else {
                    return
                }
                let countApps = result.compactMap{ $0.first }
                for item in countApps {
                    let countApp = item
                    if apps.contains(countApp) == false {
                        apps.append(countApp)
                    }
                }
                
                self?.applications = apps.sorted()
                self?.showActivityIndicator(false)
                self?.appTable.reloadData()
            }
            
            countsSubmitter.submit()
        }
        
        itemSubmitter.submit()
    }
    
    private func requestPlatforms(appName: String) {
        let itemQuery = DBAccess.query(what: Common.platform, from: Items.table, whereClause: "\(Common.appName) = '\(appName)'", isDistinct: true)
        let countersQuery = DBAccess.query(what: Common.platform, from: Counters.table, whereClause: "\(Common.appName) = '\(appName)'", isDistinct: true)
        
        showActivityIndicator(true)
        resetDataStorage(startingTable: platformTable)
        
        let itemSubmitter = QuerySubmitter(query: itemQuery, mode: .array) { [weak self] result in
            guard let result = result as? [[String]] else {
                return
            }
            var platforms = result.compactMap{ $0.first }
            
            let countSubmitter = QuerySubmitter(query: countersQuery, mode: .array) { result in
                guard let result = result as? [[String]] else {
                    return
                }
                let countPlatforms = result.compactMap{ $0.first }
                for platform in countPlatforms {
                    if platforms.contains(platform) == false {
                        platforms.append(platform)
                    }
                }
                
                self?.platforms = platforms.sorted()
                
                self?.showActivityIndicator(false)
                self?.platformTable.reloadData()
                if let count = self?.platforms.count,
                   count > 0 {
                    self?.platformTable.selectRowIndexes(IndexSet(0...0), byExtendingSelection: false)
                }
            }
            
            countSubmitter.submit()
        }
        
        itemSubmitter.submit()
    }
    
    private func requestAppActivity(app: String, platform: String) {
        showActivityIndicator(true)
        
        resetDataStorage(startingTable: actionsTable)
        
        let query = "SELECT description, COUNT(description) AS 'count' FROM items WHERE (app_name = \(app.sqlify()) AND platform = \(platform.sqlify())) GROUP BY description"

        let itemSubmitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                return
            }
            
            var actions = [String : String]()
            var actionsArray = [String]()
            for item in result {
                if let name = item["description"],
                   let count = item["count"] {
                    actions[name] = count
                    actionsArray.append(name)
                }
            }
                            
            self?.actions = actions
            self?.actionsArray = actionsArray.sorted()

            self?.actionsTable.reloadData()
            self?.showActivityIndicator(false)
            
            self?.requestCounters(app: app, platform: platform)
        }

        itemSubmitter.submit()
    }

    private func requestCounters(app: String, platform: String) {
        showActivityIndicator(true)        
        resetDataStorage(startingTable: countersTable)
        
        let query = DBAccess.query(what: "\(Counters.description), \(Counters.count)", from: Counters.table, whereClause: "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)'")
        var countsArray = [String]()
        let itemSubmitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                self?.showActivityIndicator(false)
                return
            }
            
            for item in result {
                if let name = item["description"],
                   let count = item["count"] {
                    countsArray.append(name)
                    self?.counters[name] = count
                }
            }
            
            self?.countsArray = countsArray.sorted()
            self?.showActivityIndicator(false)
            self?.countersTable.reloadData()
        }

        itemSubmitter.submit()
    }
    
    private func requestDetails(app: String, platform: String, action: String) {
        showActivityIndicator(true)
        resetDataStorage(startingTable: detailsTable)
        let whereClause = "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)' AND \(Items.description) = '\(action)'"
        let query = DBAccess.query(what: "\(Items.details), \(Items.timestamp), \(Common.deviceID)",
                                   from: Items.table,
                                   whereClause: whereClause,
                                   sorting: "\(Common.deviceID), \(Items.timestamp)")
        let userCountQuery = "SELECT COUNT(DISTINCT device_id) AS userCount FROM items WHERE (\(whereClause))"
        
        let submitter = QuerySubmitter(query: "\(query);\(userCountQuery)", mode: .dictionary) { [weak self] result in
            guard var result = result as? [[String : String]] else {
                self?.showActivityIndicator(false)
                return
            }
            
            if let userCountPair = result.first(where: { $0.first?.key == "userCount" }),
               let index = result.firstIndex(of: userCountPair),
               let userCount = userCountPair.first?.value {
                    print("User count: \(userCount)")
                result.remove(at: index)
            }
            
            self?.details = result
            self?.showActivityIndicator(false)
            self?.detailsTable.reloadData()
        }

        submitter.submit()
    }
    
    private func resetDataStorage(startingTable: NSTableView) {
        let tables = [appTable, platformTable, actionsTable, countersTable, detailsTable]
        guard let tableIndex = tables.firstIndex(of: startingTable) else {
            return
        }
        
        let resetTables = tables[tableIndex..<tables.count]
        
        if resetTables.contains(appTable) {
            applications.removeAll()
        }
        if resetTables.contains(platformTable) {
            platforms.removeAll()
        }
        if resetTables.contains(actionsTable) {
            actions.removeAll()
            actionsArray.removeAll()
        }
        if resetTables.contains(countersTable) {
            counters.removeAll()
            countsArray.removeAll()
        }
        if resetTables.contains(detailsTable) {
            details.removeAll()
        }
        
        for table in resetTables {
            table?.reloadData()
        }
    }

    // MARK: - TableView DataSource & Delegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == self.appTable {
            let application = applications[row]
            let field = NSTextField(labelWithString: application)
            return field
        } else if tableView == self.actionsTable {
            let action = actionsArray[row]
            
            let field: NSTextField
            if tableColumn == actionsTable.tableColumns[0] {
                field = NSTextField(labelWithString: action)
            } else {
                let count = actions[action] ?? ""
                field = NSTextField(labelWithString: count)
                field.alignment = .right
            }
            return field
        } else if tableView == self.countersTable {
            let counter = countsArray[row]
            guard let amount = counters[counter] else {
                return nil
            }
            if tableColumn == tableView.tableColumns[0] {
                return NSTextField(labelWithString: counter)
            } else if tableColumn == tableView.tableColumns[1] {
                let field = NSTextField(labelWithString: String(amount))
                field.alignment = .right
                return field
            }
        } else if tableView == self.platformTable {
            let platform = platforms[row]
            let field = NSTextField(labelWithString: platform)
            return field
        } else if tableView == self.detailsTable {
            let item = details[row]
            if tableColumn == tableView.tableColumns[1] {
               var detail = item["details"] ?? noDetails
                if detail.isEmpty {
                    detail = noDetails
                }
                return NSTextField(labelWithString: detail)
                
            } else if tableColumn == tableView.tableColumns[0],
                      let timestamp = item["timestamp"] {
                if let date = timestamp.dateFromISOString() {
                    return NSTextField(labelWithString: DateFormatter.shortDateTimeFormatter.string(from: date))
                } else {
                    return NSTextField(labelWithString: timestamp)
                }
            } else if tableColumn == tableView.tableColumns[2] {
                let device = item["device_id"] ?? noDetails
                return NSTextField(labelWithString: String("...\(device.suffix(8))"))
            }
        }
        
        return nil
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.appTable {
            return applications.count
        } else if tableView == self.actionsTable {
            return actions.count
        } else if tableView == self.countersTable {
            return countsArray.count
        } else if tableView == self.platformTable {
            return platforms.count
        } else if tableView == self.detailsTable {
            return details.count
        } else {
            return 0
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let table = notification.object as? NSTableView {
            let appRow = appTable.selectedRow
            let platformRow = platformTable.selectedRow
            let actionRow = actionsTable.selectedRow
            
            if table == appTable {
                requestPlatforms(appName: applications[appRow])
            } else if table == platformTable {
                if appRow < 0 || platformRow < 0 { return }
                requestAppActivity(app: applications[appRow], platform: platforms[platformRow])
            } else if table == actionsTable {
                if appRow < 0 || platformRow < 0 || actionRow < 0 { return }
                requestDetails(app: applications[appRow], platform: platforms[platformRow], action: actionsArray[actionRow])
            }
        }
    }
}

extension DateFormatter {
    static var shortDateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

extension String {
    func dateFromISOString() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: self)
    }
}
