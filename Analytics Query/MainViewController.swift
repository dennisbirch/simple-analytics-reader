//
//  MainViewController.swift
//  Analytics Query
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
    private var actions = [String]()
    private var counters = [String : String]()
    private var countsArray = [String]()
    private var details = [[String : String]]()
    
    private let windowFrameKey = "main.window.frame"
    
    // MARK: - ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        platformTable.tableColumns[0].width = platformTable.bounds.width
        actionsTable.tableColumns[0].width = actionsTable.bounds.width
        
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
                DispatchQueue.main.async {
                    self?.showActivityIndicator(false)
                    self?.appTable.reloadData()
                }
            }
            
            countsSubmitter.submit()
        }
        
        itemSubmitter.submit()
    }
    
    private func requestPlatforms(appName: String) {
        platforms.removeAll()
        platformTable.reloadData()
        
        actions.removeAll()
        actionsTable.reloadData()
        
        counters.removeAll()
        countersTable.reloadData()
        
        let itemQuery = DBAccess.query(what: Common.platform, from: Items.table, whereClause: "\(Common.appName) = '\(appName)'")
        let countersQuery = DBAccess.query(what: Common.platform, from: Counters.table, whereClause: "\(Common.appName) = '\(appName)'")
        
        showActivityIndicator(true)
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
                
                DispatchQueue.main.async {
                    self?.showActivityIndicator(false)
                    self?.platformTable.reloadData()
                    if let count = self?.platforms.count,
                       count > 0 {
                        self?.platformTable.selectRowIndexes(IndexSet(0...0), byExtendingSelection: false)
                    }
                }
            }
            
            countSubmitter.submit()
        }
        
        itemSubmitter.submit()
    }
    
    private func requestAppActivity(app: String, platform: String) {
        showActivityIndicator(true)

        actions.removeAll()
        actionsTable.reloadData()
        
        counters.removeAll()
        countersTable.reloadData()
        
        let query = DBAccess.query(what: Items.description, from: Items.table, whereClause: "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)'")
        let itemSubmitter = QuerySubmitter(query: query, mode: .array) { [weak self] result in
            guard let result = result as? [[String]] else {
                return
            }
            let actions = result.compactMap{ $0.first }
            self?.actions = actions.sorted()
            
            DispatchQueue.main.async {
                self?.actionsTable.reloadData()
                self?.showActivityIndicator(false)
            }
            
            self?.requestCounters(app: app, platform: platform)
        }
        itemSubmitter.submit()
    }

    private func requestCounters(app: String, platform: String) {
        showActivityIndicator(true)

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
            DispatchQueue.main.async {
                self?.countersTable.reloadData()
            }
        }
        itemSubmitter.submit()
    }
    
    private func requestDetails(app: String, platform: String, action: String) {
        showActivityIndicator(true)
        
        let query = DBAccess.query(what: "\(Items.details), \(Items.timestamp), \(Common.deviceID)",
                                   from: Items.table,
                                   whereClause: "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)' AND \(Items.description) = '\(action)'",
                                   sorting: "\(Common.deviceID), \(Items.timestamp)")
        let submitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                self?.showActivityIndicator(false)
                return
            }

            self?.details = result
            self?.showActivityIndicator(false)
            DispatchQueue.main.async {
                self?.detailsTable.reloadData()
            }
        }

        submitter.submit()
    }

    // MARK: - TableView DataSource & Delegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == self.appTable {
            let application = applications[row]
            let field = NSTextField(labelWithString: application)
            return field
        } else if tableView == self.actionsTable {
            let action = actions[row]
            let field = NSTextField(labelWithString: action)
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
               var detail = item["details"] ?? "----"
                if detail.isEmpty {
                    detail = "----"
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
                let device = item["device_id"] ?? "--------"
                return NSTextField(labelWithString: String(device.suffix(8)))
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
                requestDetails(app: applications[appRow], platform: platforms[platformRow], action: actions[actionRow])
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
