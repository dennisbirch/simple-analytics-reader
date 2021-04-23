//
//  SearchQueriesViewController.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/17/21.
//

import Cocoa
import os.log

enum WhatItems: String {
    case items
    case counters
    case both
}

enum MatchCondition: String {
    case any
    case all
}

enum TableType {
    case items
    case counters
}

protocol QuerySearchDelegate {
    func searchCompleted(results: [AnalyticsItem])
}

class SearchQueriesViewController: NSViewController, QueriesTableDelegate, NSComboBoxDelegate {
    static let viewControllerIdentifier = "SearchQueriesViewController"
    
    var searchDelegate: QuerySearchDelegate?
    
    @IBOutlet private weak var queriesTableView: QueriesTable!
    @IBOutlet private weak var removeQueryButton: NSButton!
    @IBOutlet private weak var removeAllQueriesButton: NSButton!
    
    // Radio buttons
    @IBOutlet private weak var allRadio: NSButton!
    @IBOutlet private weak var anyRadio: NSButton!
    @IBOutlet private weak var itemsRadio: NSButton!
    @IBOutlet private weak var countersRadio: NSButton!
    @IBOutlet private weak var bothRadio: NSButton!
    
    // Search limit
    @IBOutlet private weak var limitComboBox: NSComboBox!
    @IBOutlet private weak var limitInfoLabel: NSTextField!
    @IBOutlet private weak var limitHeightCheckbox: NSButton!
    @IBOutlet private weak var limitHeightConstraint: NSLayoutConstraint!

    private var selectedQueryRow = -1
    private var whatItems: WhatItems = .items
    private var searchLimits: SearchLimit = SearchLimit(itemsTotal: 0, countersTotal: 0, lastItemsIndex: 0, lastCountersIndex: 0)
    
    private var matchCondition: MatchCondition = .all
    private let expandedLimitViewHeight: CGFloat = 57
    private let collapsedLimitViewHeight: CGFloat = 4
    
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
             
        queriesTableView.dataSource = queriesTableView
        queriesTableView.delegate = queriesTableView
        queriesTableView.queriesTableDelegate = self
        limitComboBox.delegate = self
        displaySearchLimitControls(false)
    }
    
    private func displaySearchLimitControls(_ shouldDisplay: Bool) {
        let newHeight: CGFloat
        if shouldDisplay == true {
            newHeight = expandedLimitViewHeight
            setSearchLimitTotals()
        } else {
            newHeight = collapsedLimitViewHeight
        }
        
        searchLimits.lastItemsIndex = 0
        searchLimits.lastCountersIndex = 0
        
        limitInfoLabel.stringValue = ""

        limitHeightConstraint.constant = newHeight
        NSAnimationContext.runAnimationGroup { [weak self] (context) in
            context.allowsImplicitAnimation = true
            context.duration = 0.25
            self?.view.layoutSubtreeIfNeeded()
        }
    }
    
    private func setSearchLimitTotals() {
        if limitHeightCheckbox.state == .off { return }
        
        var queries = [String]()
        let baseSQL = "SELECT COUNT(*) FROM "
        if whatItems == .items || whatItems == .both {
            let whereClause = whereStatements(for: .items)
            let sql = baseSQL + "items WHERE \(whereClause)"
            queries.append(sql)
        }
        if whatItems == .counters || whatItems == .both {
            let whereClause = whereStatements(for: .counters)
            let sql = baseSQL + "counters WHERE \(whereClause)"
            queries.append(sql)
        }
        let submitter = QuerySubmitter(query: queries.joined(separator: ";"), mode: .array) { [weak self] (results) in
            if let results = results as? [[String]] {
                var total = 0
                if let items = results.first, let itemsTotal = items.first, let itemCount = Int(itemsTotal) {
                    self?.searchLimits.itemsTotal = itemCount
                    total += itemCount
                }
                if let counters = results.last, let counterTotal = counters.first, let countersCount = Int(counterTotal) {
                    self?.searchLimits.countersTotal = countersCount
                    total += countersCount
                }
                
                if total > 0 {
                    self?.limitInfoLabel.stringValue = "Total: \(total)"
                }
            }
        }
        
        submitter.submit()
    }
    
    @IBAction func toggledShowSearchLimit(_ sender: NSButton) {
        let show = sender.state == .on
        displaySearchLimitControls(show)
    }
    
    @IBAction func addQueryItem(_ sender: Any) {
        queriesTableView.addQuery()
    }
    
    @IBAction func selectedWhatRadioButton(_ sender: NSButton) {
        // selected from ITEMS/COUNTERS/BOTH radio group
        let what = WhatItems(rawValue: sender.title.lowercased())
        self.whatItems = what ?? .items
        UserDefaults.standard.set(sender.title, forKey: searchWhatKey)
    }
    
    @IBAction func selectedMatchRadioButton(_ sender: NSButton) {
        // selected from ALL/ANY radio group
        let match = MatchCondition(rawValue: sender.title)
        self.matchCondition = match ?? .all
        UserDefaults.standard.set(sender.title, forKey: searchWhatKey)
    }
    
    @IBAction func removeQuery(_ sender: NSButton) {
        defer {
            selectedQueryRow = -1
            enableRemoveQueryButtons()
        }

        guard selectedQueryRow >= 0 else { return }
        queriesTableView.removeRow(selectedQueryRow)
    }
    
    @IBAction func removeAllQueries(_ sender: Any) {
        queriesTableView.removeAll()
        selectedQueryRow = -1
        enableRemoveQueryButtons()
    }
        
    @IBAction func performSearch(_ sender: Any) {
        var statements = [String]()
        if whatItems == .items || whatItems == .both {
            let itemsWhereStatement = whereStatements(for: .items)
            let itemsSQL = DBAccess.query(what: DBAccess.selectAll, from: Items.table, whereClause: itemsWhereStatement)
            statements.append(itemsSQL)
        }
        
        if whatItems == .counters || whatItems == .both {
            let countersWhereStatement = whereStatements(for: .counters)
            let countersSQL = DBAccess.query(what: DBAccess.selectAll, from: Counters.table, whereClause: countersWhereStatement)
            statements.append(countersSQL)
        }
        
        // execute SQL statement
        let sql = statements.joined(separator: "; ")
        let submitter = QuerySubmitter(query: sql, mode: .items) { result in
            if let result = result as? [AnalyticsItem] {
                DispatchQueue.main.async { [weak self] in
                    self?.searchDelegate?.searchCompleted(results: result)
                }
            } else {
                os_log("Search query failed")
                return
            }
        }
        
        submitter.submit()
    }
    
    private func whereStatements(for type: TableType) -> String {
        let items = queriesTableView.queryItems
        let sqlArray = items.map{ $0.sqlWhereString() }
        let how = (matchCondition == .all) ? " AND " : " OR "
        
        switch type {
        case .items:
            return sqlArray.joined(separator: how)
        case .counters:
            let counterItems = items.filter{ $0.queryType != .datetime }
            if counterItems.isEmpty == false {
                let counterSQLArray = counterItems.map{ $0.sqlWhereString() }
                return counterSQLArray.joined(separator: how)
            } else {
                return ""
            }
        }
    }
 

    // MARK: - QueriesTableDelegate
    
    func searchQueriesChanged() {
        setSearchLimitTotals()
    }
    
    func queriesTableSelectionChanged(selectedRow: Int) {
        selectedQueryRow = selectedRow
        enableRemoveQueryButtons()
    }
    
    private func enableRemoveQueryButtons() {
        removeQueryButton.isEnabled = selectedQueryRow >= 0
        removeAllQueriesButton.isEnabled = selectedQueryRow >= 0
    }

    // MARK: - NSComboBoxDelegate
    
    func controlTextDidChange(_ obj: Notification) {
        guard let combo = obj.object as? NSComboBox else {
            return
        }
        let value = Int(combo.stringValue) ?? 100
        searchLimits.pageLimit = value
        searchLimits.lastItemsIndex = 0
        searchLimits.lastCountersIndex = 0
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let combo = notification.object as? NSComboBox else {
            return
        }
        
        guard let value = combo.objectValueOfSelectedItem as? String else {
            return
        }
        let intValue = Int(value) ?? 100
        searchLimits.pageLimit = intValue
        searchLimits.lastItemsIndex = 0
        searchLimits.lastCountersIndex = 0
    }
}

struct SearchLimit {
    var itemsTotal: Int
    var countersTotal: Int
    var lastItemsIndex: Int
    var lastCountersIndex: Int
    var pageLimit: Int = 100
}
