//
//  MainViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 3/24/21.
//

import Cocoa

class ListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet private weak var appTable: NSTableView!
    @IBOutlet private weak var platformTable: NSTableView!
    @IBOutlet private weak var detailsTable: NSTableView!
    @IBOutlet private weak var activityIndicator: NSProgressIndicator!
    @IBOutlet private weak var refreshButton: NSButton!
    @IBOutlet private weak var actionsTableContainer: NSView!
    @IBOutlet private weak var countersTableContainer: NSView!
    
    private var actionsViewController: DeviceCountDisplayViewController?
    private var countersViewController: DeviceCountDisplayViewController?

    private var applications = [String]()
    private var platforms = [String]()
    private var details = [[String : String]]()
    //dummy data stores for bookkeeping purposes
    private var actions = [String]()
    private var counters = [String]()
    private let noDetails = "----"
    
    private let windowFrameKey = "main.window.frame"
    private let detailsTimestampColumnKey = "mainView.details.timestampColumn"
    private let detailsDetailColumnKey = "mainView.details.detail"
    private let detailsDeviceColumnKey = "mainView.details.device"

    private enum TableStorageResetStrategy: Int {
        case apps
        case platforms
        case actions
        case counters
        case details
    }
    
    private enum DetailTableIdentifier: String {
        case timestamp
        case details
        case device
    }
    
    // MARK: - ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        detailsTable.autosaveName = "listView.detailsTable"
        detailsTable.autosaveTableColumns = true
        
        platformTable.tableColumns[0].width = platformTable.bounds.width
        addDeviceCounterViews()
        
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
        
    private func addDeviceCounterViews() {
        guard let actionsVC = DeviceCountDisplayViewController.viewController(for: .actions) else {
            return
        }
        self.actionsViewController = actionsVC
        actionsVC.delegate = self
        addChild(actionsVC)
        let actionView = actionsVC.view
        actionsTableContainer.addSubview(actionView)
        actionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([actionView.leadingAnchor.constraint(equalTo: actionsTableContainer.leadingAnchor),
                                     actionView.topAnchor.constraint(equalTo: actionsTableContainer.topAnchor),
                                     actionView.trailingAnchor.constraint(equalTo: actionsTableContainer.trailingAnchor),
                                     actionView.bottomAnchor.constraint(equalTo: actionsTableContainer.bottomAnchor)])
        
        guard let countersVC = DeviceCountDisplayViewController.viewController(for: .counters) else {
            return
        }
        self.countersViewController = countersVC
        countersVC.delegate = self
        addChild(countersVC)
        let countersView = countersVC.view
        countersTableContainer.addSubview(countersView)
        countersView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([countersView.leadingAnchor.constraint(equalTo: countersTableContainer.leadingAnchor),
                                     countersView.topAnchor.constraint(equalTo: countersTableContainer.topAnchor),
                                     countersView.trailingAnchor.constraint(equalTo: countersTableContainer.trailingAnchor),
                                     countersView.bottomAnchor.constraint(equalTo: countersTableContainer.bottomAnchor)])
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
        resetDataStorage(strategy: .apps)

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
        resetDataStorage(strategy: .platforms)
        
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
        
        requestCounters(app: app, platform: platform)
        
        resetDataStorage(strategy: .actions)
        
        let whereClause = "(app_name = \(app.sqlify()) AND platform = \(platform.sqlify()))"
        let query = "SELECT description, COUNT(description) AS 'count' FROM items WHERE \(whereClause) GROUP BY description"

        let itemSubmitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                return
            }
            
            self?.actionsViewController?.configureWithFetchedResult(result, tableType: .actions, whereClause: whereClause)
            self?.showActivityIndicator(false)
        }

        itemSubmitter.submit()
    }

    private func requestCounters(app: String, platform: String) {
        showActivityIndicator(true)        
        resetDataStorage(strategy: .counters)
        
        let whereClause = "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)'"
        let query = DBAccess.query(what: "\(Counters.description), \(Counters.count)", from: Counters.table, whereClause: whereClause)
        let itemSubmitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                self?.showActivityIndicator(false)
                return
            }
            
            self?.showActivityIndicator(false)
            self?.countersViewController?.configureWithFetchedResult(result, tableType: .counters, whereClause: whereClause)
        }

        itemSubmitter.submit()
    }
    
    private func requestDetails(app: String, platform: String, action: String) {
        showActivityIndicator(true)
        let whereClause = "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)' AND \(Items.description) = '\(action)'"
        let query = DBAccess.query(what: "\(Items.details), \(Items.timestamp), \(Common.deviceID)",
                                   from: Items.table,
                                   whereClause: whereClause,
                                   sorting: "\(Common.deviceID), \(Items.timestamp)")
        let submitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                self?.showActivityIndicator(false)
                return
            }
            
            self?.details = result
                        
            self?.detailsTable.reloadData()
            self?.showActivityIndicator(false)
        }

        submitter.submit()
    }
    
    private func resetDataStorage(strategy: TableStorageResetStrategy) {
        let dataStores: [AnyHashable] = [applications, platforms, actions, counters, details]

        let tableIndex = strategy.rawValue
        let resetIndices = dataStores[tableIndex..<dataStores.count]
        
        if resetIndices.contains(applications) {
            applications.removeAll()
            appTable.reloadData()
        }
        if resetIndices.contains(platforms) {
            platforms.removeAll()
            platformTable.reloadData()
        }
        if resetIndices.contains(actions) {
            actionsViewController?.resetTableView()
        }
        if resetIndices.contains(counters) {
            countersViewController?.resetTableView()
        }
        
        if resetIndices.contains(details) {
            details.removeAll()
            detailsTable.reloadData()
        }
    }

    // MARK: - TableView DataSource & Delegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        
        if tableView == self.appTable {
            let application = applications[row]
            let field = NSTextField(labelWithString: application)
            return field

        } else if tableView == self.detailsTable {
            let item = details[row]
            if tableColumn.identifier.rawValue == DetailTableIdentifier.details.rawValue {
                var detail = item["details"] ?? noDetails
                if detail.isEmpty {
                    detail = noDetails
                }
                return NSTextField(labelWithString: detail)
            } else if tableColumn.identifier.rawValue == DetailTableIdentifier.timestamp.rawValue,
                      let timestamp = item["timestamp"] {
                if let date = timestamp.dateFromISOString() {
                    return NSTextField(labelWithString: DateFormatter.shortDateTimeFormatter.string(from: date))
                } else {
                    return NSTextField(labelWithString: timestamp)
                }
            } else if tableColumn.identifier.rawValue == DetailTableIdentifier.device.rawValue {
                let device = item["device_id"] ?? noDetails
                return NSTextField(labelWithString: String("...\(device.suffix(8))"))
            }

        } else if tableView == self.platformTable {
            let platform = platforms[row]
            let field = NSTextField(labelWithString: platform)
            return field
        }
        
        return nil
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.appTable {
            return applications.count
        } else if tableView == self.detailsTable {
            return details.count
        } else if tableView == self.platformTable {
            return platforms.count
        } else {
            return 0
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let table = notification.object as? NSTableView {
            let appRow = appTable.selectedRow
            let platformRow = platformTable.selectedRow
            if table == appTable {
                requestPlatforms(appName: applications[appRow])
            } else if table == platformTable {
                if appRow < 0 || platformRow < 0 { return }
                requestAppActivity(app: applications[appRow], platform: platforms[platformRow])
            }
        }
    }
}

extension ListViewController: DeviceCountTableViewDelegate {
    func selectedTableViewRow(_ row: Int, tableType: DeviceCountTableType, selectedItem: String) {
        showActivityIndicator(true)
        
        if tableType == .actions {
            let appRow = appTable.selectedRow
            let platformRow = platformTable.selectedRow
            if appRow < 0 || platformRow < 0 || row < 0 { return }
            requestDetails(app: applications[appRow], platform: platforms[platformRow], action: selectedItem)
        }
    }
    
    func deviceCountDataFetchEnded() {
        showActivityIndicator(false)
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
