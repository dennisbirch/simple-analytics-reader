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

protocol QuerySearchDelegate {
    func searchCompleted(results: [AnalyticsItem])
}

class SearchQueriesViewController: NSViewController, QueriesTableDelegate {
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
             
        queriesTableView.dataSource = queriesTableView
        queriesTableView.delegate = queriesTableView
        queriesTableView.queriesTableDelegate = self
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
        
        let items = queriesTableView.queryItems
        let sqlArray = items.map{ $0.sqlWhereString() }
        let how = (matchCondition == .all) ? " AND " : " OR "
        
        if whatItems == .items || whatItems == .both {
            let itemsWhereStatement = sqlArray.joined(separator: how)
            let itemsSQL = DBAccess.query(what: DBAccess.selectAll, from: Items.table, whereClause: itemsWhereStatement)
            statements.append(itemsSQL)
        }
        
        if whatItems == .counters || whatItems == .both {
            let countersWhereStatement = sqlArray.joined(separator: how)
            let countersSQL = DBAccess.query(what: DBAccess.selectAll, from: Counters.table, whereClause: countersWhereStatement)
            statements.append(countersSQL)
        }
        
        // execute SQL statement
        let sql = statements.joined(separator: "; ")
        let submitter = QuerySubmitter(query: sql, mode: .items) { result in
            if let result = result as? [AnalyticsItem] {
                self.searchDelegate?.searchCompleted(results: result)
            } else {
                os_log("Search query failed")
                return
            }
        }
        
        submitter.submit()
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
