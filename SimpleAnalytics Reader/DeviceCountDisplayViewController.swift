//
//  DetailsViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/13/21.
//

import Cocoa
import os.log

enum DeviceCountTableType {
    case actions
    case counters
    
    var tableName: String {
        switch self {
        case .actions:
            return "items"
        case .counters:
            return "counters"
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
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var deviceCountContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var deviceCountLabel: NSTextField!
    @IBOutlet private weak var deviceCountContainer: NSView!

    private var tableType: DeviceCountTableType
    private var dataDictionary = [String : String]()
    private var sortedKeys = [String]()
    private var baseWhereClause = ""
    
    private let collapsedUserCountHeight: CGFloat = 0
    private let expandedUserCountHeight: CGFloat = 60
    private let deviceCountKey = "deviceCount"

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
        
        setupTableView()
    }
    
    func setupTableView() {
        let firstColumn = tableView.tableColumns[0]

        switch self.tableType {
        case .actions:
            firstColumn.title = "User interactions"
        case .counters:
            firstColumn.title = "Counters"
        }
        
        tableView.tableColumns[1].title = "Count"
    }
    
    func resetTableView() {
        dataDictionary.removeAll()
        sortedKeys.removeAll()
        tableView.reloadData()
    }
    
    func configureWithFetchedResult(_ result: [[String : String]], tableType: DeviceCountTableType, whereClause: String) {
        self.tableType = tableType
        displayDeviceCountContent(false, deviceCount: "")
        baseWhereClause = whereClause
        var sortedArray = [String]()
        var dataDict = [String : String]()
        for item in result {
            if let name = item["description"],
               let count = item["count"] {
                dataDict[name] = count
                sortedArray.append(name)
            }
        }
        
        self.sortedKeys = sortedArray.sorted()
        self.dataDictionary = dataDict

        tableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = sortedKeys[row]
        
        switch tableType {
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
        if row < 0 {
            displayDeviceCountContent(false, deviceCount: "")
            return
        }
        
        let itemName = sortedKeys[row]
        
        let fromTable = tableType.tableName
        let userCountQuery = "SELECT COUNT(DISTINCT device_id) AS \(deviceCountKey) FROM \(fromTable) WHERE (\(baseWhereClause) AND \(Items.description) = \(itemName.sqlify()))"
        
        let counterKey = deviceCountKey
        let submitter = QuerySubmitter(query: userCountQuery, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                self?.delegate?.deviceCountDataFetchEnded()
                return
            }
            
            self?.delegate?.deviceCountDataFetchEnded()
            if let countDef = result.first, let countStr = countDef[counterKey] {
                self?.displayDeviceCountContent(true, deviceCount: countStr)
            }
        }
        
        submitter.submit()
        delegate?.selectedTableViewRow(row, tableType: tableType, selectedItem: sortedKeys[row])
    }

    
    private func displayDeviceCountContent(_ isVisible: Bool, deviceCount: String) {
        if isVisible == true {
            let formatStr = NSLocalizedString("unique-devices-label %@", comment: "String for 'Unique devices count' label")
            deviceCountLabel.stringValue = String(format: formatStr, deviceCount)
            deviceCountContainerHeightConstraint?.constant = expandedUserCountHeight
        } else {
            deviceCountContainerHeightConstraint?.constant = collapsedUserCountHeight
        }

        NSAnimationContext.runAnimationGroup { [weak self] (context) in
            context.duration = 0.25
            self?.deviceCountContainer.layoutSubtreeIfNeeded()
        }
    }
}
