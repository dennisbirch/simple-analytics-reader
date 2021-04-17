//
//  SearchViewController.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/9/21.
//

import Cocoa

enum WhatItems: String {
    case items
    case counters
    case both
}

enum MatchCondition: String {
    case any
    case all
}

class SearchViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, QueriesTableDelegate {
    @IBOutlet private weak var resultsTableView: NSTableView!
    @IBOutlet private weak var queriesContainerView: NSView!
    @IBOutlet private weak var queriesTableView: QueriesTable!
    @IBOutlet private weak var containerSeparatorView: NSView!
    @IBOutlet private weak var removeQueryButton: NSButton!
    @IBOutlet private weak var removeAllQueriesButton: NSButton!
    
    // Radio buttons
    @IBOutlet private weak var allRadio: NSButton!
    @IBOutlet private weak var anyRadio: NSButton!
    @IBOutlet private weak var itemsRadio: NSButton!
    @IBOutlet private weak var countersRadio: NSButton!
    @IBOutlet private weak var bothRadio: NSButton!
    
    private var items = [AnalyticsItem]()
    private var selectedQueryRow = -1
    private var whatItems: WhatItems = .items
    private var matchCondition: MatchCondition = .all
    
    private let searchWhatKey = "searchWhat"
    private let conditionMatchKey = "conditionMatchesOn"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let what = UserDefaults.standard.string(forKey: searchWhatKey) {
            if let whatItems = WhatItems(rawValue: what.lowercased()) {
                self.whatItems = whatItems
            }
        }
        
        if let match = UserDefaults.standard.string(forKey: conditionMatchKey) {
            if let conditions = MatchCondition(rawValue: match.lowercased()) {
                self.matchCondition = conditions
            }
        }
        
        switch self.whatItems {
        case .items:
            itemsRadio.state = .on
        case .counters:
            countersRadio.state = .on
        default:
            bothRadio.state = .on
        }
        
        switch matchCondition {
        case .any:
            anyRadio.state = .on
        default:
            allRadio.state = .on
        }
        
        queriesContainerView.wantsLayer = true
        queriesContainerView.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        containerSeparatorView.wantsLayer = true
        containerSeparatorView.layer?.backgroundColor = NSColor.secondaryLabelColor.cgColor
        
        queriesTableView.dataSource = queriesTableView
        queriesTableView.delegate = queriesTableView
    }
    
    
    @IBAction func addQueryItem(_ sender: Any) {
        queriesTableView.addQuery()
    }
    
    @IBAction func performSearch(_ sender: Any) {
        var statements = [String]()
        
        let items = queriesTableView.queryItems
        let sqlArray = items.map{ $0.sqlWhereString() }
        let how = (matchCondition == .all) ? " AND " : " OR "
        
        if whatItems == .items || whatItems == .both {
            let itemsWhereStatement = sqlArray.joined(separator: how)
            let itemsSQL = "SELECT * FROM items WHERE (\(itemsWhereStatement))"
            statements.append(itemsSQL)
        }
        
        if whatItems == .counters || whatItems == .both {
            // counters have no timestamp
            let counterItems = items.filter{ $0.queryType != .datetime }
            if counterItems.isEmpty == false {
                let counterSQLArray = counterItems.map{ $0.sqlWhereString() }
                let countersWhereStatement = counterSQLArray.joined(separator: how)
                let countersSQL = "SELECT * FROM counters WHERE (\(countersWhereStatement))"
                statements.append(countersSQL)
            }
        }
        
        // execute SQL statement
        let sql = statements.joined(separator: ";")
        
        let submitter = QuerySubmitter(query: sql, mode: .items) { [weak self] result in
            guard let result = result as? [AnalyticsItem] else {
                print("Search query failed")
                return
            }
            
            self?.items = result
            self?.resultsTableView.reloadData()
        }
        
        submitter.submit()
    }
    
    @IBAction func selectedWhatRadioButton(_ sender: NSButton) {
        // selected from ITEMS/COUNTERS/BOTH radio group
        let what = WhatItems(rawValue: sender.title.lowercased())
        self.whatItems = what ?? .items
        UserDefaults.standard.set(sender.title, forKey: searchWhatKey)
    }
    
    @IBAction func selectedWhichRadioButton(_ sender: NSButton) {
        // selected from ALL/ANY radio group
        let match = MatchCondition(rawValue: sender.title)
        self.matchCondition = match ?? .all
        UserDefaults.standard.set(sender.title, forKey: searchWhatKey)
    }
    
    @IBAction func removeQuery(_ sender: NSButton) {
//        defer {
//            selectedQueryRow = -1
//            enableRemoveQueryButtons()
//        }
//        
//        guard selectedQueryRow >= 0 else { return }
//        items.remove(at: selectedQueryRow)
//        if items.isEmpty {
//            quer
//        }
//        
//        queriesTableView.reloadData()
    }
    
    @IBAction func removeAllQueries(_ sender: Any) {
        
        selectedQueryRow = -1
        enableRemoveQueryButtons()
    }
    
    // MARK: - Results TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // TODO: Implement!!!
        return nil
    }
    
    // MARK: - QueriesTableDelegate
    
    func queriesTableSelectionChanged(selectedRow: Int) {
        selectedQueryRow = selectedRow
        enableRemoveQueryButtons()
    }
    
    private func enableRemoveQueryButtons() {
        removeQueryButton.isEnabled = selectedQueryRow >= 0
        removeAllQueriesButton.isEnabled = selectedQueryRow >= 0
    }
}
