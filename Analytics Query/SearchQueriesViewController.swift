//
//  SearchQueriesViewController.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/17/21.
//

import Cocoa
import os.log

enum WhatItems: String, Codable {
    case items
    case counters
    case both
}

enum MatchCondition: String, Codable {
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
    
    @IBOutlet weak var queriesTableView: QueriesTable!
    @IBOutlet private weak var removeQueryButton: NSButton!
    @IBOutlet private weak var removeAllQueriesButton: NSButton!
    @IBOutlet private weak var performSearchButton: NSButton!
    
    // Radio buttons
    @IBOutlet weak var allRadio: NSButton!
    @IBOutlet private weak var anyRadio: NSButton!
    @IBOutlet private weak var itemsRadio: NSButton!
    @IBOutlet private weak var countersRadio: NSButton!
    @IBOutlet private weak var bothRadio: NSButton!
    
    // Search limit
    @IBOutlet private weak var limitComboBox: NSComboBox!
    @IBOutlet private weak var limitInfoLabel: NSTextField!
    @IBOutlet private weak var limitSearchCheckbox: NSButton!
    @IBOutlet private weak var limitHeightConstraint: NSLayoutConstraint!

    private var selectedQueryRow = -1
    var whatItems: WhatItems = .items
    private(set) var searchLimits: SearchLimit = SearchLimit(itemsTotal: 0, countersTotal: 0, lastItemsIndex: 0, lastCountersIndex: 0)
    
    var matchCondition: MatchCondition = .all
    private let expandedLimitViewHeight: CGFloat = 64
    private let collapsedLimitViewHeight: CGFloat = 4
    var isLimitedSearch = false
    var limitSearchTotal = 0
    
    private let searchWhatKey = "searchWhat"
    private let conditionMatchKey = "conditionMatchesOn"
    private let limitSearchKey = "limitSearch"
    private let limitPageSizeKey = "limitPageSize"

    // MARK: - ViewController Lifecycle
    
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
             
        if let limitPageSize = UserDefaults.standard.string(forKey: limitPageSizeKey) {
            if let index = limitComboBox.objectValues.firstIndex(where: { $0 as? String == limitPageSize }) {
                limitComboBox.selectItem(at: index)
            } else {
                limitComboBox.stringValue = limitPageSize
            }
        }
        
        limitComboBox.delegate = self
        let shouldLimitSearch = UserDefaults.standard.bool(forKey: limitSearchKey)
        if shouldLimitSearch == true {
            isLimitedSearch = true
            limitSearchCheckbox.state = .on
        }
        displaySearchLimitControls(isLimitedSearch)

        queriesTableView.dataSource = queriesTableView
        queriesTableView.delegate = queriesTableView
        queriesTableView.queriesTableDelegate = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
    }
    
    // MARK: - Private Helpers
    
    private func displaySearchLimitControls(_ shouldDisplay: Bool) {
        let newHeight: CGFloat
        if shouldDisplay == true {
            newHeight = expandedLimitViewHeight
            setSearchLimitTotals()
        } else {
            newHeight = collapsedLimitViewHeight
            performSearchButton.isEnabled = true
        }
        
        searchLimits.lastItemsIndex = 0
        searchLimits.lastCountersIndex = 0
        
        limitInfoLabel.stringValue = ""

        limitHeightConstraint.constant = newHeight
        NSAnimationContext.runAnimationGroup { [weak self] (context) in
            context.allowsImplicitAnimation = true
            context.duration = 0.25
            self?.view.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
            self?.limitInfoLabel.isHidden = !shouldDisplay
            self?.limitComboBox.isHidden = !shouldDisplay
        }
    }
    
    private func setSearchLimitTotals() {
        if isLimitedSearch == false { return }
        
        var queries = [String]()
        let baseSQL = "SELECT COUNT(*) FROM "
        if whatItems == .items || whatItems == .both {
            let whereClause = whereStatements(for: .items)
            if whereClause.isEmpty == false {
                let sql = baseSQL + "items WHERE \(whereClause)"
                queries.append(sql)
            }
        }
        if whatItems == .counters || whatItems == .both {
            let whereClause = whereStatements(for: .counters)
            if whereClause.isEmpty == false {
                let sql = baseSQL + "counters WHERE \(whereClause)"
                queries.append(sql)
            }
        }
        
        if queries.isEmpty == true {
            limitInfoLabel.stringValue = ""
            return
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
                    let format = NSLocalizedString("total-count-label %d", comment: "Total records that match query")
                    self?.limitInfoLabel.stringValue = String.localizedStringWithFormat(format, total)
                }
                
                self?.limitSearchTotal = total
                
                if let searchLimits = self?.searchLimits {
                    self?.performSearchButton.isEnabled = searchLimits.currentFetchCount < searchLimits.totalCount
                }
            }
        }
        
        submitter.submit()
    }
    
    private func whereStatements(for type: TableType) -> String {
        let queryItems = queriesTableView.queryItems.filter{ $0.value.isEmpty == false }
        let sqlArray = queryItems.map{ $0.sqlWhereString() }
        let how = (matchCondition == .all) ? " AND " : " OR "
        return sqlArray.joined(separator: how)
    }
    
    private func limitedSearchSQL() -> String {
        var itemsLimit = searchLimits.limitForTable(.items, whatItems: whatItems)
        var countersLimit = searchLimits.limitForTable(.counters, whatItems: whatItems)
        // correct for minor miscalculation of proportional limits
        while itemsLimit + countersLimit < searchLimits.pageLimit {
            if itemsLimit < searchLimits.itemsTotal {
                itemsLimit += 1
            } else {
                countersLimit += 1
            }
        }
        
        var statements = [String]()
        if whatItems == .items || whatItems == .both {
            let whereClause = whereStatements(for: .items)
            let itemsSQL = DBAccess.limitQuery(what: DBAccess.selectAll, from: Items.table, whereClause: whereClause, lastID: searchLimits.lastItemsIndex, limit: itemsLimit)
            if itemsSQL.isEmpty == false {
                statements.append(itemsSQL)
            }
        }
        if whatItems == .counters || whatItems == .both {
            let whereClause = whereStatements(for: .counters)
            let countersSQL = DBAccess.limitQuery(what: DBAccess.selectAll, from: Counters.table, whereClause: whereClause, lastID: searchLimits.lastCountersIndex, limit: countersLimit)
            if countersSQL.isEmpty == false {
                statements.append(countersSQL)
            }
        }
        return statements.joined(separator: ";")
    }
    
    private func fullSearchSQL() -> String {
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

        return statements.joined(separator: ";")
    }
    
    private func searchDB() {
        let sql: String
        if isLimitedSearch == true {
            sql = limitedSearchSQL()
        } else {
            sql = fullSearchSQL()
        }
        
        let submitter = QuerySubmitter(query: sql, mode: .items) { result in
            if let result = result as? [AnalyticsItem] {
                if self.isLimitedSearch == true {
                    self.updateSearchLimitInfo(results: result)
                }
                self.searchDelegate?.searchCompleted(results: result)
            } else {
                os_log("Search query failed")
                return
            }
        }
        
        submitter.submit()
    }
        
    private func updateSearchLimitInfo(results: [AnalyticsItem]) {
        searchLimits.currentFetchCount += results.count
        let items = results.filter{ $0.table == .items }.sorted { (item1, item2) -> Bool in
            return item1.id < item2.id
        }
        let counters = results.filter{ $0.table == .counters }.sorted { (item1, item2) -> Bool in
            return item1.id < item2.id
        }
        
        if let lastItem = items.last {
            searchLimits.lastItemsIndex = lastItem.id
        }
        if let lastCounter = counters.last {
            searchLimits.lastCountersIndex = lastCounter.id
        }

        let format = NSLocalizedString("record range label with total %d %d %d", comment: "First record to last record fetched, plus total available to show")
        limitInfoLabel.stringValue = String.localizedStringWithFormat(format, searchLimits.lastFetchCount, searchLimits.currentFetchCount, searchLimits.totalCount)
        
        performSearchButton.isEnabled = searchLimits.currentFetchCount < searchLimits.totalCount
    }
    
    // MARK: - Actions
    
    func loadSavedQueries(_ model: QueryModel) {
        queriesTableView.loadQueries(model.queryItems)
        self.matchCondition = model.matchType
        self.whatItems = model.whatItems

        self.isLimitedSearch = model.isLimitedSearch
        self.searchLimits.pageLimit = model.pageLimit
        limitComboBox.intValue = Int32(model.pageLimit)
        displaySearchLimitControls(isLimitedSearch)
        UserDefaults.standard.set(isLimitedSearch, forKey: limitSearchKey)
        self.limitSearchCheckbox.state = (isLimitedSearch) ? .on : .off
    }
    
    @IBAction func toggledShowSearchLimit(_ sender: NSButton) {
        isLimitedSearch = sender.state == .on
        displaySearchLimitControls(isLimitedSearch)
        UserDefaults.standard.set(isLimitedSearch, forKey: limitSearchKey)
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
        searchDB()
    }
    
    // MARK: - QueriesTableDelegate
    
    func searchQueriesChanged() {
        searchLimits = SearchLimit(itemsTotal: 0, countersTotal: 0, lastItemsIndex: 0, lastCountersIndex: 0)
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
        guard let combo = obj.object as? NSComboBox,
              combo == self.limitComboBox else {
            return
        }
        let value = Int(combo.stringValue) ?? 100
        searchLimits.pageLimit = value
        searchLimits.lastItemsIndex = 0
        searchLimits.lastCountersIndex = 0
        UserDefaults.standard.set(combo.stringValue, forKey: limitPageSizeKey)
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let combo = notification.object as? NSComboBox,
              combo == self.limitComboBox else {
            return
        }
        
        guard let value = combo.objectValueOfSelectedItem as? String else {
            return
        }
        let intValue = Int(value) ?? 100
        searchLimits.pageLimit = intValue
        searchLimits.lastItemsIndex = 0
        searchLimits.lastCountersIndex = 0
        UserDefaults.standard.set(value, forKey: limitPageSizeKey)
    }
}
