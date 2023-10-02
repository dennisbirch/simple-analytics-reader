//
//  QueryItemCell.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 4/9/21.
//

import Cocoa
import Combine
import os.log

struct LocalizedQueryString {
    static let title = NSLocalizedString("description-item", comment: "Selector for a description query")
    static let appName = NSLocalizedString("app-name-item", comment: "Selector for an application name query")
    static let appVersion = NSLocalizedString("app-version-item", comment: "Selector for an application version query")
    static let platform = NSLocalizedString("platform-item", comment: "Selector for a platform query")
    static let systemVersion = NSLocalizedString("system-version-item", comment: "Selector for a system version query")
    static let deviceID = NSLocalizedString("device-id-item", comment: "Selector for a device-id query")
    static let timestamp = NSLocalizedString("date-time-item", comment: "Selector for a timestamp query")
    static let equals = NSLocalizedString("compare-equals", comment: "Comparison option for 'Equals'")
    static let contains = NSLocalizedString("string-compare-contains", comment: "String comparison option for 'Contains'")
    static let beginsWith = NSLocalizedString("string-compare-begins", comment: "String comparison option for 'Begins with'")
    static let endsWith = NSLocalizedString("string-compare-ends", comment: "String comparison option for 'Ends with'")
    static let beforeOrEqual = NSLocalizedString("date-compare-before-equal", comment: "Date comparison option for 'Before or equals'")
    static let before = NSLocalizedString("date-compare-before", comment: "Date comparsion option for 'Before'")
    static let same = NSLocalizedString("date-compare-same", comment: "Date comparison option for 'Same'")
    static let after = NSLocalizedString("date-compare-after", comment: "Date comparison option for 'After'")
    static let afterEquals = NSLocalizedString("date-compare-after-equals", comment: "Date comparison option for 'After or equals'")
    static let lessEquals = NSLocalizedString("numeric-compare-less-equals", comment: "Numeric comparison option for 'Less than or equal'")
    static let less = NSLocalizedString("numeric-compare-less", comment: "Numeric comparison option for 'Less than'")
    static let greater = NSLocalizedString("numeric-compare-greater", comment: "Numeric comparison option for 'Greater than")
    static let greaterEquals = NSLocalizedString("numeric-compare-greater-equals", comment: "Numeric comparison option for 'Greater than or equal'")
}

class QueryItemCell: NSTableCellView, NSTextFieldDelegate, NSTextViewDelegate {
    @IBOutlet private weak var queryButton: NSPopUpButton!
    @IBOutlet private weak var equalityButton: NSPopUpButton!
    @IBOutlet private weak var searchTermText: NSTextField!
    @IBOutlet private weak var dateTimeControl: NSDatePicker!
    
    private var queryItem: QueryItem?
    private var insertHandler: ((QueryItem) -> Void)?
    private var searchTextObserver: AnyCancellable?
    
    
    func configure(with item: QueryItem, insertHandler: @escaping (QueryItem) -> Void) {
        self.queryItem = item
        self.insertHandler = insertHandler
        dateTimeControl.isHidden = true
        searchTermText.delegate = self
        
        configureTypePopup(with: item.queryType.rawValue)
        configureEqualityPopup(with: item)
        searchTermText.stringValue = item.value
        if item.queryType == .datetime,
           let date = queryItem?.dateValue() {
            dateTimeControl.dateValue = date
        }
        
        queryButton.target = self
        queryButton.action = #selector(selectedTypePopupItem(_:))
        equalityButton.target = self
        equalityButton.action = #selector(selectedEqualityPopupItem(_:))
        
        setupSearchTextObserver()
    }
    
    private func setupSearchTextObserver() {
        let sub = NotificationCenter.default
            .publisher(for: NSControl.textDidChangeNotification, object: searchTermText)
            .map( { ($0.object as! NSTextField).stringValue } )
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink(receiveValue: { [weak self] in
                guard let item = self?.queryItem else {
                    return
                }
                
                let type = item.queryType
                if type == .appVersion || type == .systemVersion {
                    let newItem = item.queryItemWithNewNumeric($0)
                    self?.queryItem = newItem
                } else if type != .datetime {
                    let newItem = item.queryItemWithNewString($0)
                    self?.queryItem = newItem
                }
                if let handler = self?.insertHandler,
                   let newItem = self?.queryItem {
                    handler(newItem)
                }
            })
        
        searchTextObserver = sub
    }
    
    private func configureTypePopup(with selectedOption: String?) {
        queryButton.removeAllItems()
        let items = [LocalizedQueryString.title, LocalizedQueryString.appName, LocalizedQueryString.appVersion, LocalizedQueryString.platform, LocalizedQueryString.systemVersion, LocalizedQueryString.deviceID, LocalizedQueryString.timestamp]
        queryButton.addItems(withTitles: items)
        let selected = items.map{ $0.reducedEnumElement() }.firstIndex(of: selectedOption?.lowercased()) ?? 0
        
        queryButton.selectItem(at: selected)
    }
    
    private func configureEqualityPopup(with query: QueryItem) {
        equalityButton.removeAllItems()
        var items = [LocalizedQueryString.equals, LocalizedQueryString.contains, LocalizedQueryString.beginsWith, LocalizedQueryString.endsWith]
        if query.queryType == .datetime {
            items = [LocalizedQueryString.beforeOrEqual, LocalizedQueryString.before, LocalizedQueryString.same, LocalizedQueryString.after, LocalizedQueryString.afterEquals]
        } else if query.queryType == .systemVersion || query.queryType == .appVersion {
            items = [LocalizedQueryString.lessEquals, LocalizedQueryString.less, LocalizedQueryString.equals, LocalizedQueryString.greater, LocalizedQueryString.greaterEquals]
        }
        
        equalityButton.addItems(withTitles: items)
        
        let equalIndex = items.firstIndex(of: LocalizedQueryString.equals) ?? 0
        let selected = items.map{ $0.reducedEnumElement() }.firstIndex(of: query.comparison?.toString().lowercased()) ?? equalIndex
        equalityButton.selectItem(at: selected)
    }
    
    @objc func selectedTypePopupItem(_ sender: NSPopUpButton) {
        let typeString = sender.title
        if let item = self.queryItem {
            handleTypeChange(typeString, itemID: item.id)
        }
    }
    
    @objc func selectedEqualityPopupItem(_ sender: NSPopUpButton) {
        let compareString = sender.title
        handleComparisonChange(compareString)
    }
    
    @IBAction func dateValueChanged(_ sender: NSDatePicker) {
        if let newItem = queryItem?.queryItemWithNewDate(sender.dateValue) {
            queryItem = newItem
            if let handler = self.insertHandler {
                handler(newItem)
            }
        } else {
            os_log("Failed to generate new query item")
        }
    }
    
    private func handleComparisonChange(_ compareString: String) {
        var currentType = QueryType.title
        var id = UUID()
        if let item = self.queryItem {
            currentType = QueryType.fromString(item.queryType.rawValue)
            id = item.id
        }
        
        var comparison: Comparison
        var newQueryItem: QueryItem
        if currentType == .datetime {
            comparison = DateComparison.fromString(compareString)
            let date = dateTimeControl.dateValue
            newQueryItem = QueryItem(queryType: .datetime, dateComparison: comparison as! DateComparison, value: date)
        } else if currentType == .systemVersion || currentType == .appVersion {
            comparison = NumericComparison.fromString(compareString)
            let version = searchTermText.stringValue
            newQueryItem = QueryItem(queryType: currentType, comparison: comparison, value: version)
        } else {
            comparison = StringComparison.fromString(compareString)
            newQueryItem = QueryItem(queryType: currentType, comparison: comparison as! StringComparison, value: searchTermText.stringValue)
        }
        
        newQueryItem.id = id
        queryItem = newQueryItem
        if let handler = self.insertHandler {
            handler(newQueryItem)
        }
    }
    
    private func handleTypeChange(_ typeString: String, itemID: UUID) {
        let queryType = QueryType.fromString(typeString)
        var comparison = queryItem?.comparison
        let date = dateTimeControl.dateValue
        
        switch queryType {
        case .datetime:
            if comparison is DateComparison,
               let item = queryItem {
                comparison = item.comparison
            } else {
                comparison = DateComparison.same
            }
        case .appVersion, .systemVersion:
            if comparison is NumericComparison,
               let item = queryItem {
                comparison = item.comparison
            } else {
                comparison = NumericComparison.equals
            }
        default: // string comparison
            if let item = queryItem,
               comparison is StringComparison {
                comparison = item.comparison
            } else {
                comparison = StringComparison.equals
            }
        }
        
        var newQueryItem: QueryItem
        if queryType == .datetime, let dateComparison = comparison as? DateComparison {
            newQueryItem = QueryItem(queryType: queryType, dateComparison: dateComparison, value: date)
        } else if let stringComparison = comparison as? StringComparison {
            newQueryItem = QueryItem(queryType: queryType, comparison: stringComparison, value: searchTermText.stringValue)
        } else {
            let comparison = comparison as? NumericComparison ?? NumericComparison.equals
            newQueryItem = QueryItem(queryType: queryType, comparison: comparison, value: searchTermText.stringValue)
        }
        
        dateTimeControl.isHidden = queryType != .datetime
        searchTermText.isHidden = queryType == .datetime
        if dateTimeControl.isHidden == false {
            dateTimeControl.frame = searchTermText.frame
        }
        
        newQueryItem.id = itemID
        queryItem = newQueryItem
        configureEqualityPopup(with: newQueryItem)
        if let handler = self.insertHandler {
            handler(newQueryItem)
        }
    }
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if control == searchTermText {
            if let item = queryItem {
                let type = item.queryType
                if type == .appVersion || type == .systemVersion {
                    let newItem = item.queryItemWithNewNumeric(fieldEditor.string)
                    queryItem = newItem
                } else if type != .datetime {
                    let newItem = item.queryItemWithNewString(fieldEditor.string)
                    queryItem = newItem
                    
                    if let handler = self.insertHandler {
                        handler(newItem)
                    }
                }
            }
        }
        
        return true
    }
}

