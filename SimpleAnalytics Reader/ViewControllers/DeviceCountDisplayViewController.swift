//
//  DeviceCountDisplayViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/13/21.
//

import Cocoa
import os.log

enum DeviceCountTableType {
    case applications
    case platforms
    case actions
    case counters
    
    var tableName: String {
        switch self {
        case .applications, .platforms:
            return "both"
        case .actions:
            return "items"
        case .counters:
            return "counters"
        }
    }
    
    var tableResetStrategy: ListViewController.TableStorageResetStrategy {
        switch self {
        case .applications:
            return .platforms
        case .platforms:
            return .actions
        case .actions:
            return .details
        case .counters:
            return .details
        }
    }
}

protocol DeviceCountTableViewDelegate {
    func selectedTableViewRow(_ row: Int, tableType: DeviceCountTableType, selectedItem: String)
    func deviceCountDataFetchEnded()
}

class DeviceCountDisplayViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    static let viewControllerIdentifier = "DetailsViewController"
    
    var delegate: DeviceCountTableViewDelegate?
    var selectedRow: Int {
        return tableView.selectedRow
    }
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var deviceCountContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var deviceCountLabel: NSTextField!
    @IBOutlet private weak var deviceCountContainer: NSView!

    private var tableType: DeviceCountTableType
    private var dataDictionary = [String : String]()
    private var sortedKeys = [String]()
    private var baseWhereClause = ""
    
    private let collapsedDeviceCountHeight: CGFloat = 0
    private let expandedDeviceCountHeight: CGFloat = 60

    // Column width Defaults keys
    private let actionsNameColumnKey = "actionsTableNameColumn"
    private let actionsCountColumnKey = "actionsTableCountColumn"
    private let countersNameColumnKey = "countersTableNameColumn"
    private let countersCountColumnKey = "countersTableCountColumn"
    
    required init?(coder: NSCoder) {
        self.tableType = .actions
        super.init(coder: coder)
    }
    
    static func viewController(for tableType: DeviceCountTableType) -> DeviceCountDisplayViewController? {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateController(withIdentifier: "DeviceCountDisplayViewController") as? DeviceCountDisplayViewController else {
            os_log("Can't instantiate DeviceCountDisplayViewController")
            return nil
        }
        vc.tableType = tableType
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        displayDeviceCountContent(false, deviceCount: "")
        setupTableView()
    }
        
    func setupTableView() {
        let firstColumn = tableView.tableColumns[0]
        let secondColumn = tableView.tableColumns[1]
        var showsSecondColumn = false
        
        switch self.tableType {
        case .applications:
            firstColumn.title = "Applications"
            tableView.removeTableColumn(secondColumn)
            firstColumn.width = tableView.frame.width
        case .platforms:
            firstColumn.title = "Platforms"
            tableView.removeTableColumn(secondColumn)
            firstColumn.width = tableView.frame.width
        case .actions:
            firstColumn.title = "User interactions"
            tableView.autosaveName = "listview.useractionsTable"
            showsSecondColumn = true
        case .counters:
            firstColumn.title = "Counters"
            tableView.autosaveName = "listView.countersTable"
            showsSecondColumn = true
        }

        if showsSecondColumn == true {
            tableView.tableColumns[1].title = "Count"
            tableView.autosaveTableColumns = true
        }
    }
    
    func resetTableView() {
        dataDictionary.removeAll()
        sortedKeys.removeAll()
        tableView.reloadData()
        displayDeviceCountContent(false, deviceCount: "")
    }
    
    func configureWithDictionary(_ result: [[String : String]], tableType: DeviceCountTableType, whereClause: String) {
        self.tableType = tableType
        displayDeviceCountContent(false, deviceCount: "")
        baseWhereClause = whereClause
        var sortedArray = [String]()
        var dataDict = [String : String]()
        for item in result {
            if let name = item["description"],
               let count = item["count"] {
                dataDict[name] = count.formatted()
                sortedArray.append(name)
            }
        }
        
        self.sortedKeys = sortedArray.sorted()
        self.dataDictionary = dataDict
        tableView.reloadData()
    }
        
    func configureWithArray(_ array: [String], tableType: DeviceCountTableType, whereClause: String) {
        self.tableType = tableType
        displayDeviceCountContent(false, deviceCount: "")
        baseWhereClause = whereClause
        sortedKeys = array.sorted()
        tableView.reloadData()
    }
    
    func updateWhereClause(_ whereClause: String) {
        baseWhereClause = whereClause
    }
    
    func restoreSelection(row: Int) async {
        if row < sortedKeys.count,
           let tableView = self.tableView {
            tableView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
        }

        await fetchCountForRow(row)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = sortedKeys[row]
        
        switch tableType {
        case .applications, .platforms:
            let item = sortedKeys[row]
            return NSTextField(labelWithString: item)
        case .actions:
            let action = sortedKeys[row]
            let field: NSTextField
            if tableColumn == tableView.tableColumns[0] {
                field = NSTextField(labelWithString: action)
            } else {
                let count = dataDictionary[item] ?? ""
                field = NSTextField(labelWithString: count)
                field.alignment = .right
            }
            return field
        case .counters:
            let counter = sortedKeys[row]
            guard let amount = dataDictionary[counter] else {
                return nil
            }
            if tableColumn == tableView.tableColumns[0] {
                return NSTextField(labelWithString: counter)
            } else if tableColumn == tableView.tableColumns[1] {
                let field = NSTextField(labelWithString: String(amount))
                field.alignment = .right
                return field
            }
        }
        
        return nil
    }
    

    func numberOfRows(in tableView: NSTableView) -> Int {
        return sortedKeys.count
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        var selectedItem = ""
        if row >= 0 {
            selectedItem = sortedKeys[row]
        }
        delegate?.selectedTableViewRow(row, tableType: tableType, selectedItem: selectedItem)
        Task {
            await fetchCountForRow(row)
        }
    }

    private func fetchCountForRow(_ row: Int) async {
        if tableType == .applications || tableType == .platforms {
            await getAppsAndPlatformsCounts(row: row)
        } else {
            if row < 0 {
                displayDeviceCountContent(false, deviceCount: "")
                return
            }
            
            let itemName = sortedKeys[row]
            
            let fromTable = tableType.tableName
            let deviceCountQuery = "SELECT COUNT(DISTINCT device_id) FROM \(fromTable) WHERE (\(baseWhereClause) AND \(Items.description) = \(itemName.sqlify()))"
            
            let submitter = QuerySubmitter(query: deviceCountQuery, mode: .array)
            let result = await submitter.submit()
            
            switch result {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    guard let response = response as? [[String]] else {
                        delegate?.deviceCountDataFetchEnded()
                        return
                    }
                    
                    delegate?.deviceCountDataFetchEnded()
                    if let countDef = response.first, let countStr = countDef.first {
                        displayDeviceCountContent(true, deviceCount: countStr)
                    }
            }
        }
    }
    
    
    private func getAppsAndPlatformsCounts(row: Int) async {
        if row < 0 {
            displayDeviceCountContent(false, deviceCount: "")
            return
        }
        
        let itemName = sortedKeys[row]
        let whereClause = baseWhereClause + itemName.sqlify()
        let itemsQuery = "SELECT DISTINCT (\(Common.deviceID)) FROM \(Items.table) WHERE \(whereClause)"
        let countersQuery = "SELECT DISTINCT (\(Common.deviceID)) FROM \(Counters.table) WHERE \(whereClause)"
        
        let itemsSubmitter = QuerySubmitter(query: itemsQuery, mode: .array)
        
        var items: [[String]] = []
        var counters: [[String]] = []
        
        let itemsCount = await itemsSubmitter.submit()
        switch itemsCount {
            case .failure(let error):
                NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                
            case .success(let fetchedItems):
                guard let fetchedItems = fetchedItems as? [[String]] else {
                    delegate?.deviceCountDataFetchEnded()
                    return
                }
                items = fetchedItems
        }
        
        let countersSubmitter = QuerySubmitter(query: countersQuery, mode: .array)
        let countersCount = await countersSubmitter.submit()
        
        switch countersCount {
            case .failure(let error):
                NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                
                
            case .success(let fetchedCounters):
                guard let fetchedCounters = fetchedCounters as? [[String]] else {
                    delegate?.deviceCountDataFetchEnded()
                    return
                }
                counters = fetchedCounters
        }
        
        delegate?.deviceCountDataFetchEnded()
        let itemsFirstsArray = items.compactMap{ $0.first }
        let countersFirstArray = counters.compactMap{ $0.first }
        let uniqueIDs = itemsFirstsArray.uniqueValues(countersFirstArray)
        displayDeviceCountContent(true, deviceCount: String(uniqueIDs.count))
    }
            
    private func displayDeviceCountContent(_ isVisible: Bool, deviceCount: String) {
        let expanded = self.expandedDeviceCountHeight
        let collapsed = self.collapsedDeviceCountHeight
        if isVisible == true {
            let formatStr = NSLocalizedString("unique-devices-label %@", comment: "String for 'Unique devices count' label")
            deviceCountLabel.stringValue = String(format: formatStr, deviceCount)
            deviceCountContainerHeightConstraint?.constant = expanded
        } else {
            deviceCountContainerHeightConstraint?.constant = collapsed
        }
        NSAnimationContext.runAnimationGroup { (context) in
            context.duration = 0.25
            deviceCountContainer.layoutSubtreeIfNeeded()
        }
    }
}
