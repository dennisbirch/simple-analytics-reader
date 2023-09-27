//
//  SearchQueriesViewController.swift
//  SimpleAnalytics Reader
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
    func searchCompleted(results: [AnalyticsItem], lastRowNumber: Int)
    func searchBegan()
}

class SearchQueriesViewController: NSViewController, QueriesTableDelegate, NSComboBoxDelegate {
    static let viewControllerIdentifier = "SearchQueriesViewController"
    
    var searchDelegate: QuerySearchDelegate?
    
    @IBOutlet weak var queriesTableView: QueriesTable!
    @IBOutlet private weak var removeQueryButton: NSButton!
    @IBOutlet private weak var removeAllQueriesButton: NSButton!
    @IBOutlet private weak var performSearchButton: NSButton!
    @IBOutlet private weak var sqlTextView: NSTextView!
    @IBOutlet private weak var queryControlsHeightConstraint: NSLayoutConstraint!

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
    private(set) var searchLimits: SearchLimit = SearchLimit(pageLimit: 100)
    
    var matchCondition: MatchCondition = .all
    private let queryControlsHeight: CGFloat = 214
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
        
        updateWhatToSelectRadioButtons()
        updateMatchConditionsRadioButtons()
             
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
        enableRemoveQueryButtons()
    }
    
    // MARK: - Public & Internal Methods
    
    func displayQuerySQL(_ sql: String) {
        sqlTextView.string = sql
    }
    
    // MARK: - Private Helpers
    
    private func displaySearchLimitControls(_ shouldDisplay: Bool) {
        let newLimitHeight: CGFloat
        let queryContainerHeight: CGFloat
        if shouldDisplay == true {
            newLimitHeight = expandedLimitViewHeight
            queryContainerHeight = queryControlsHeight
            setSearchLimitTotals()
        } else {
            newLimitHeight = collapsedLimitViewHeight
            queryContainerHeight = queryControlsHeight - expandedLimitViewHeight
            performSearchButton.isEnabled = true
        }
        
        searchLimits.lastItemsID = 0
        searchLimits.lastCountersID = 0
        
        limitInfoLabel.stringValue = ""

        limitHeightConstraint.constant = newLimitHeight
        queryControlsHeightConstraint.constant = queryContainerHeight
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
            switch results {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")

                case .success(let response):
                    if let response = response as? [[String]] {
                        var total = 0
                        if self?.whatItems == .items || self?.whatItems == .both {
                            if var items = response.first, let itemsTotal = items.first, let itemCount = Int(itemsTotal) {
                                self?.searchLimits.itemsTotal = itemCount
                                total += itemCount
                                items.remove(at: 0)
                            }
                        }
                        if self?.whatItems == .counters || self?.whatItems == .both {
                            if let counters = response.last, let counterTotal = counters.first, let countersCount = Int(counterTotal) {
                                self?.searchLimits.countersTotal = countersCount
                                total += countersCount
                            }
                        }
                        
                        if total > 0 {
                            self?.showLimitedSearchTotal(total)
                        }
                        
                        self?.limitSearchTotal = total
                        
                        if let searchLimits = self?.searchLimits {
                            self?.performSearchButton.isEnabled = searchLimits.currentFetchCount < searchLimits.totalCount
                        }
            }
            }
        }
        
        submitter.submit()
    }
    
    private func showLimitedSearchTotal(_ total: Int) {
        let format = NSLocalizedString("total-count-label %d", comment: "Total records that match query")
        self.limitInfoLabel.stringValue = String.localizedStringWithFormat(format, total)
    }
    
    private func whereStatements(for type: TableType) -> String {
        let queryItems = queriesTableView.queryItems.filter{ $0.value.isEmpty == false }
        let sqlArray = queryItems.map{ $0.sqlWhereString() }
        let how = (matchCondition == .all) ? " AND " : " OR "
        return sqlArray.joined(separator: how)
    }
    
    private func limitedSearchSQL() -> String {
        var itemsLimit = 0
        if (whatItems == .items || whatItems == .both) {
            itemsLimit = searchLimits.limitForTable(.items, whatItems: whatItems, currentLimit: 0)
        }
        var countersLimit: Int = 0
        if itemsLimit < searchLimits.pageLimit {
            countersLimit = searchLimits.limitForTable(.counters, whatItems: whatItems, currentLimit: itemsLimit)
        }
        
        var statements = [String]()
        if itemsLimit > 0 && (whatItems == .items || whatItems == .both) {
            let whereClause = whereStatements(for: .items)
            if whereClause.isEmpty == false {
                let itemsSQL = DBAccess.limitQuery(what: DBAccess.selectAll,
                                                   from: Items.table,
                                                   whereClause: whereClause,
                                                   lastID: searchLimits.lastItemsID,
                                                   limit: itemsLimit)
                statements.append(itemsSQL)
            }
        }
        if countersLimit > 0 && (whatItems == .counters || whatItems == .both) {
            let whereClause = whereStatements(for: .counters)
            if whereClause.isEmpty == false {
                let countersSQL = DBAccess.limitQuery(what: DBAccess.selectAll,
                                                      from: Counters.table,
                                                      whereClause: whereClause,
                                                      lastID: searchLimits.lastCountersID,
                                                      limit: countersLimit)
                statements.append(countersSQL)
            }
        }
        return statements.joined(separator: ";")
    }
    
    private func fullSearchSQL() -> String {
        var statements = [String]()

        if whatItems == .items || whatItems == .both {
            let itemsWhereStatement = whereStatements(for: .items)
            if itemsWhereStatement.isEmpty == false {
                let itemsSQL = DBAccess.query(what: DBAccess.selectAll, from: Items.table, whereClause: itemsWhereStatement)
                statements.append(itemsSQL)
            }
        }
        
        if whatItems == .counters || whatItems == .both {
            let countersWhereStatement = whereStatements(for: .counters)
            if countersWhereStatement.isEmpty == false {
                let countersSQL = DBAccess.query(what: DBAccess.selectAll, from: Counters.table, whereClause: countersWhereStatement)
                statements.append(countersSQL)
            }
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
        
        sqlTextView.string = sql
        
        if sql.isEmpty == true {
            sqlTextView.string = ""
            let title = NSLocalizedString("invalid-search-query-alert-title", comment: "Title for alert when there are no valid queries")
            let message = NSLocalizedString("invalid-search-query-alert-message", comment: "Message for alert when there are no valid queries")
            let alert = NSAlert.okAlertWithTitle(title, message: message)
            NSSound.beep()
            alert.runModal()
            return
        }
        
        searchDelegate?.searchBegan()
        let isLimitedSearch = isLimitedSearch
        executeSQL(sql, isLimitedSearch: isLimitedSearch)
    }
    
    func executeSQL(_ sql: String, isLimitedSearch: Bool) {
        let nextRow = searchLimits.currentFetchCount
        let submitter = QuerySubmitter(query: sql, mode: .items) { [weak self] result in
            switch result {
                case .failure(let error):
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    if let result = response as? [AnalyticsItem] {
                        if isLimitedSearch == true {
                            let items = result.filter{ $0.table == .items }.sorted { (item1, item2) -> Bool in
                                return item1.id < item2.id
                            }
                            let counters = result.filter{ $0.table == .counters }.sorted { (item1, item2) -> Bool in
                                return item1.id < item2.id
                            }
                            
                            var lastItemID = 0
                            var lastCounterID = 0
                            if let lastItem = items.last {
                                lastItemID = lastItem.id
                            }
                            if let lastCounter = counters.last {
                                lastCounterID = lastCounter.id
                            }
                            self?.searchLimits.updateForNextLimitedSeek(itemsID: lastItemID, countersID: lastCounterID, itemsCount: items.count, countersCount: counters.count)
                            self?.updateSearchLimitInfo(results: result)
                        }
                        self?.searchDelegate?.searchCompleted(results: result, lastRowNumber: nextRow)
                    } else {
                        os_log("Search query failed")
                        return
                        
                    }
            }
        }
        
        submitter.submit()
    }
        
    private func updateSearchLimitInfo(results: [AnalyticsItem]) {
        searchLimits.currentFetchCount += results.count
        if searchLimits.currentFetchCount > searchLimits.totalCount {
            showLimitedSearchTotal(searchLimits.totalCount)
            searchLimits = SearchLimit(pageLimit: Int(limitComboBox.intValue))
        } else {
            let format = NSLocalizedString("record range label with total %d %d %d", comment: "First record to last record fetched, plus total available to show")
            limitInfoLabel.stringValue = String.localizedStringWithFormat(format, searchLimits.lastFetchCount + 1, searchLimits.currentFetchCount, searchLimits.totalCount)
        }
        performSearchButton.isEnabled = searchLimits.currentFetchCount < searchLimits.totalCount
    }
    
    private func updateWhatToSelectRadioButtons() {
        switch self.whatItems {
        case .items:
            itemsRadio.state = .on
        case .counters:
            countersRadio.state = .on
        default:
            bothRadio.state = .on
        }
    }
    
    private func updateMatchConditionsRadioButtons() {
        switch matchCondition {
        case .any:
            anyRadio.state = .on
        default:
            allRadio.state = .on
        }
    }
    
    // MARK: - Actions
        
    @IBAction func toggledShowSearchLimit(_ sender: NSButton) {
        searchLimits = SearchLimit(pageLimit: Int(limitComboBox.intValue))
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
        searchQueriesChanged()
    }
    
    @IBAction func selectedMatchRadioButton(_ sender: NSButton) {
        // selected from ALL/ANY radio group
        let match = MatchCondition(rawValue: sender.title)
        self.matchCondition = match ?? .all
        UserDefaults.standard.set(sender.title, forKey: searchWhatKey)
        searchQueriesChanged()
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
    
    func loadSavedQueries(_ model: QueryModel) {
        sqlTextView.string = ""
        
        queriesTableView.loadQueries(model.queryItems)
        self.matchCondition = model.matchType
        self.whatItems = model.whatItems
        
        updateWhatToSelectRadioButtons()
        updateMatchConditionsRadioButtons()

        self.isLimitedSearch = model.isLimitedSearch
        if model.pageLimit > 0 {
            self.searchLimits.pageLimit = model.pageLimit
            limitComboBox.intValue = Int32(model.pageLimit)
        }
        displaySearchLimitControls(isLimitedSearch)
        UserDefaults.standard.set(isLimitedSearch, forKey: limitSearchKey)
        self.limitSearchCheckbox.state = (isLimitedSearch) ? .on : .off
        enableRemoveQueryButtons()
    }
        
    // MARK: - QueriesTableDelegate
    
    func searchQueriesChanged() {
        searchLimits = SearchLimit(pageLimit: Int(limitComboBox.intValue))
        performSearchButton.isEnabled = true
        setSearchLimitTotals()
    }
    
    func queriesTableSelectionChanged(selectedRow: Int) {
        selectedQueryRow = selectedRow
        enableRemoveQueryButtons()
    }
    
    private func enableRemoveQueryButtons() {
        removeQueryButton.isEnabled = selectedQueryRow >= 0
        removeAllQueriesButton.isEnabled = queriesTableView.queryItems.isEmpty == false
    }

    // MARK: - NSComboBoxDelegate
    
    func controlTextDidChange(_ obj: Notification) {
        guard let combo = obj.object as? NSComboBox,
              combo == self.limitComboBox else {
            return
        }
        let value = Int(combo.stringValue) ?? 100
        searchLimits = SearchLimit(pageLimit: value)
        searchLimits.pageLimit = value
        searchQueriesChanged()
        UserDefaults.standard.set(combo.stringValue, forKey: limitPageSizeKey)
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let combo = notification.object as? NSComboBox,
              combo == self.limitComboBox else {
            return
        }
        
        guard let items = combo.objectValues as? [String] else {
            return
        }

        let value = items[combo.indexOfSelectedItem]
        let intValue = Int(value) ?? 100
        combo.intValue = Int32(intValue)
        searchLimits = SearchLimit(pageLimit: intValue)
        searchQueriesChanged()
        UserDefaults.standard.set(value, forKey: limitPageSizeKey)
    }
}
