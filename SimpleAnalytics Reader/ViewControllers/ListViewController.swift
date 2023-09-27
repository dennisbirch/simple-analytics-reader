//
//  MainViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 3/24/21.
//

import Cocoa

class ListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet private weak var detailsTable: NSTableView!
    @IBOutlet private weak var activityIndicator: NSProgressIndicator!
    @IBOutlet private weak var refreshButton: NSButton!
    @IBOutlet private weak var applicationsTableContainer: NSView!
    @IBOutlet private weak var platformsTableContainer: NSView!
    @IBOutlet private weak var actionsTableContainer: NSView!
    @IBOutlet private weak var countersTableContainer: NSView!
    
    private var applicationsViewController: DeviceCountDisplayViewController?
    private var platformsViewController: DeviceCountDisplayViewController?
    private var actionsViewController: DeviceCountDisplayViewController?
    private var countersViewController: DeviceCountDisplayViewController?
    
    private var applications = [String]() {
        didSet {
            ListViewController.sharedApps = applications
        }
    }
    private var platforms = [String]()
    private var details = [[String : String]]()
    private var lastDetailsRequestSource: DetailsRequestSource = .items
    private var refreshUpdater: ListViewRefreshRestoration?
    static var sharedApps = [String]()
    
    //dummy data stores for bookkeeping purposes
    private var actions = [String]()
    private var counters = [String]()
    private let noDetails = "----"
    
    private let windowFrameKey = "main.window.frame"
    
    enum TableStorageResetStrategy: Int {
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
    
    private enum DetailsRequestSource {
        case items
        case counters
    }
    
    // MARK: - ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        detailsTable.autosaveName = "listView.detailsTable"
        detailsTable.autosaveTableColumns = true
        
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
        addCountViewController(actionView, to: actionsTableContainer)
        
        guard let appsVC = DeviceCountDisplayViewController.viewController(for: .applications) else {
            return
        }
        self.applicationsViewController = appsVC
        appsVC.delegate = self
        addChild(appsVC)
        let appView = appsVC.view
        addCountViewController(appView, to: applicationsTableContainer)
        
        guard let platformsVC = DeviceCountDisplayViewController.viewController(for: .platforms) else {
            return
        }
        self.platformsViewController = platformsVC
        platformsVC.delegate = self
        addChild(platformsVC)
        addCountViewController(platformsVC.view, to: platformsTableContainer)
        
        guard let countersVC = DeviceCountDisplayViewController.viewController(for: .counters) else {
            return
        }
        self.countersViewController = countersVC
        countersVC.delegate = self
        addChild(countersVC)
        addCountViewController(countersVC.view, to: countersTableContainer)
    }
    
    private func addCountViewController(_ countTableView: NSView, to container: NSView) {
        container.addSubview(countTableView)
        countTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([countTableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                                     countTableView.topAnchor.constraint(equalTo: container.topAnchor),
                                     countTableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                                     countTableView.bottomAnchor.constraint(equalTo: container.bottomAnchor)])
    }
    
    // MARK: - Actions
    
    @IBAction func refreshTapped(_ sender: Any) {
        let applicationsRow = applicationsViewController?.selectedRow ?? -1
        let platformsRow = platformsViewController?.selectedRow ?? -1
        let actionsRow = actionsViewController?.selectedRow ?? -1
        let countersRow = countersViewController?.selectedRow ?? -1
        actionsViewController?.resetTableView()
        actionsViewController?.resetTableView()
        refreshUpdater = ListViewRefreshRestoration(appsTableSelection: applicationsRow,
                                                    platformsTableSelection: platformsRow,
                                                    actionsTableSelection: actionsRow,
                                                    countersTableSelection: countersRow)
        refreshUpdater?.activeControl = view.window?.firstResponder
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
        
        let itemSubmitter = QuerySubmitter(query: itemsQuery, mode: .array) { (itemsResult) in
            switch itemsResult {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    guard let response = response as? [[String]] else {
                        return
                    }
                    var apps = response.compactMap{ $0.first }
                    let countsSubmitter = QuerySubmitter(query: countersQuery, mode: .array) { [weak self] countersResult in
                        switch countersResult {
                            case .failure(let error):
                                NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                                
                            case .success(let response):
                                guard let response = response as? [[String]] else {
                                    return
                                }
                                let countApps = response.compactMap{ $0.first }
                                apps = apps.uniqueValues(countApps).sorted()
                                
                                self?.applications = apps
                                self?.showActivityIndicator(false)
                                
                                self?.applicationsViewController?.configureWithArray(apps, tableType: .applications, whereClause: "\(Common.appName) = ")
                                
                                if let restoration = self?.refreshUpdater {
                                    self?.applicationsViewController?.restoreSelection(row: restoration.appsTableSelection)
                                }
                        }
                        
                    }
                    
                    countsSubmitter.submit()
            }
        }
        
        itemSubmitter.submit()
    }
    
    private func requestPlatforms(appName: String) {
        let baseWhereClause = "\(Common.appName) = '\(appName)'"
        let itemQuery = DBAccess.query(what: Common.platform, from: Items.table, whereClause: baseWhereClause, isDistinct: true)
        let countersQuery = DBAccess.query(what: Common.platform, from: Counters.table, whereClause: "\(Common.appName) = '\(appName)'", isDistinct: true)
        
        showActivityIndicator(true)
        resetDataStorage(strategy: .platforms)
        
        let itemSubmitter = QuerySubmitter(query: itemQuery, mode: .array) { [weak self] result in
            switch result {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    guard let response = response as? [[String]] else {
                        return
                    }
                    var platforms = response.compactMap{ $0.first }
                    
                    let countSubmitter = QuerySubmitter(query: countersQuery, mode: .array) { result in
                        switch result {
                            case .failure(let error):
                                NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                                
                            case .success(let response):
                                guard let response = response as? [[String]] else {
                                    return
                                }
                                let countPlatforms = response.compactMap{ $0.first }
                                platforms = platforms.uniqueValues(countPlatforms)
                                
                                self?.platforms = platforms.sorted()
                                let whereClause = "\(baseWhereClause) AND \(Common.platform) = "
                                
                                self?.showActivityIndicator(false)
                                self?.platformsViewController?.configureWithArray(platforms, tableType: .platforms, whereClause: whereClause)
                                
                                if let restoration = self?.refreshUpdater, platforms.count > restoration.platformsTableSelection {
                                    self?.platformsViewController?.configureWithArray(platforms, tableType: .platforms, whereClause: whereClause)
                                    self?.platformsViewController?.restoreSelection(row: restoration.platformsTableSelection)
                                } else {
                                    if let count = self?.platforms.count, count > 0 {
                                        self?.platformsViewController?.restoreSelection(row: 0)
                                    }
                                }
                        }
                    }
                    
                    countSubmitter.submit()
            }
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
            switch result {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    guard let response = response as? [[String : String]] else {
                        return
                    }
                    
                    self?.actionsViewController?.configureWithDictionary(response, tableType: .actions, whereClause: whereClause)
                    self?.showActivityIndicator(false)
                    if let restoration = self?.refreshUpdater {
                        self?.actionsViewController?.restoreSelection(row: restoration.actionsTableSelection)
                    }
            }
        }
        
        itemSubmitter.submit()
    }
    
    private func requestCounters(app: String, platform: String) {
        showActivityIndicator(true)
        resetDataStorage(strategy: .counters)
        
        let whereClause = "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)'"
        let query = "SELECT \(Counters.description), SUM(\(Counters.count)) AS count FROM \(Counters.table) WHERE (\(Common.appName) = \(app.sqlify()) AND \(Common.platform) = \(platform.sqlify())) GROUP BY \(Counters.description)"
        let itemSubmitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            switch result {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    guard let response = response as? [[String : String]] else {
                        self?.showActivityIndicator(false)
                        self?.refreshUpdater = nil
                        return
                    }
                    
                    self?.showActivityIndicator(false)
                    self?.countersViewController?.configureWithDictionary(response, tableType: .counters, whereClause: whereClause)
                    if let restoration = self?.refreshUpdater {
                        self?.countersViewController?.restoreSelection(row: restoration.countersTableSelection)
                        if let activeControl = restoration.activeControl {
                            self?.view.window?.makeFirstResponder(activeControl)
                        }
                    }
                    self?.refreshUpdater = nil
            }
        }
        
        itemSubmitter.submit()
    }
    
    private func requestItemDetails(app: String, platform: String, action: String) {
        showActivityIndicator(true)
        let whereClause = "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)' AND \(Items.description) = '\(action)'"
        let query = DBAccess.query(what: "\(Items.details), \(Common.timestamp), \(Common.deviceID)",
                                   from: Items.table,
                                   whereClause: whereClause,
                                   sorting: "\(Common.deviceID), \(Common.timestamp)")
        let submitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            switch result {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    guard let response = response as? [[String : String]] else {
                        self?.showActivityIndicator(false)
                        return
                    }
                    
                    self?.details = response
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.detailsTable.reloadData()
                        self?.showActivityIndicator(false)
                    }
            }
        }
        
        lastDetailsRequestSource = .items
        submitter.submit()
    }
    
    private func requestCounterDetails(app: String, platform: String, action: String) {
        showActivityIndicator(true)
        let whereClause = "\(Common.appName) = '\(app)' AND \(Common.platform) = '\(platform)' AND \(Counters.description) = '\(action)'"
        let query = DBAccess.query(what: "\(Counters.count), \(Common.timestamp), \(Common.deviceID)",
                                   from: Counters.table,
                                   whereClause: whereClause,
                                   sorting: "\(Common.deviceID), \(Common.timestamp)")
        let submitter = QuerySubmitter(query: query, mode: .dictionary) { [weak self] result in
            switch result {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    guard let response = response as? [[String : String]] else {
                        self?.showActivityIndicator(false)
                        return
                    }
                    
                    self?.details = response
                    
                    self?.detailsTable.reloadData()
                    self?.showActivityIndicator(false)
            }
        }
        
        lastDetailsRequestSource = .counters
        submitter.submit()
    }
    
    private func resetDataStorage(strategy: TableStorageResetStrategy) {
        let dataStores: [AnyHashable] = [applications, platforms, actions, counters, details]
        
        let tableIndex = strategy.rawValue
        let resetIndices = dataStores[tableIndex..<dataStores.count]
        
        if resetIndices.contains(applications) {
            applications.removeAll()
            applicationsViewController?.resetTableView()
        }
        if resetIndices.contains(platforms) {
            platforms.removeAll()
            platformsViewController?.resetTableView()
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
        if tableView == self.detailsTable {
            let item = details[row]
            if tableColumn.identifier.rawValue == DetailTableIdentifier.details.rawValue {
                var detail: String
                if lastDetailsRequestSource == .items {
                    detail = item["details"] ?? noDetails
                } else {
                    detail = item["count"] ?? noDetails
                }
                if detail.isEmpty {
                    detail = noDetails
                }
                let tip = detail.formattedForExtendedTooltip()
                let label = NSTextField(labelWithString: detail)
                if tip.isEmpty == false {
                    label.toolTip = tip
                    label.allowsExpansionToolTips = true
                }
                return label
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
        }
        return nil
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.detailsTable {
            return details.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        if let sorter = tableColumn.sortDescriptorPrototype,
           let reversed = sorter.reversedSortDescriptor as? NSSortDescriptor {
            if sortItems(with: reversed) == true {
                tableView.reloadData()
                tableColumn.sortDescriptorPrototype = reversed
            }
        }
    }
    
    private func sortItems(with sorter: NSSortDescriptor) -> Bool {
        var itemsSorted = true
        switch sorter.key {
            case "timestamp":
                details.sort { (item1, item2) in
                    if let timeStamp1 = item1["timestamp"], let timeStamp2 = item2["timestamp"] {
                        return (timeStamp1 > timeStamp2) == (sorter.ascending == true)
                    } else {
                        return true
                    }
                }
            case "device":
                details.sort{(item1, item2) in
                    if let device1 = item1["device"], let device2 = item2["device"] {
                        return (device1 > device2) == (sorter.ascending == true)
                    } else {
                        return true
                    }
                }
            default:
                itemsSorted = false
        }
        
        return itemsSorted
    }
}

extension ListViewController: DeviceCountTableViewDelegate {
    func selectedTableViewRow(_ row: Int, tableType: DeviceCountTableType, selectedItem: String) {
        showActivityIndicator(true)
        
        let appRow = applicationsViewController?.selectedRow ?? -1
        let platformRow = platformsViewController?.selectedRow ?? -1
        if row < 0 {
            let resetStrategy = tableType.tableResetStrategy
            resetDataStorage(strategy: resetStrategy)
            return
        }
        
        if tableType == .applications {
            requestPlatforms(appName: applications[row])
            return
        }
        
        if appRow < 0 || platformRow < 0 || row < 0 { return }
        
        var detailColumnTitle: String = "Details"
        if tableType == .platforms {
            requestAppActivity(app: applications[appRow], platform: platforms[platformRow])
            platformsViewController?.updateWhereClause("\(Common.appName) = '\(applications[appRow])' AND \(Common.platform) = ")
        } else if tableType == .actions {
            requestItemDetails(app: applications[appRow], platform: platforms[platformRow], action: selectedItem)
            detailColumnTitle = "Details"
        } else {
            requestCounterDetails(app: applications[appRow], platform: platforms[platformRow], action: selectedItem)
            detailColumnTitle = "Count"
        }
        
        if let detailsColumn = detailsTable.tableColumns.first(where: { $0.identifier.rawValue == DetailTableIdentifier.details.rawValue }) {
            detailsColumn.title = detailColumnTitle
        }
    }
    
    func deviceCountDataFetchEnded() {
        showActivityIndicator(false)
    }

}

struct ListViewRefreshRestoration {
    var appsTableSelection: Int
    var platformsTableSelection: Int
    var actionsTableSelection: Int
    var countersTableSelection: Int
    var activeControl: NSResponder? = nil
}
