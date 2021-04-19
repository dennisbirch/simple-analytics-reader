//
//  QueryItemCell.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/9/21.
//

import Cocoa

class QueryItemCell: NSTableCellView, NSTextFieldDelegate, NSTextViewDelegate {
    @IBOutlet private weak var queryButton: NSPopUpButton!
    @IBOutlet private weak var equalityButton: NSPopUpButton!
    @IBOutlet private weak var searchTermText: NSTextField!
    @IBOutlet private weak var dateTimeControl: NSDatePicker!
    private var queryItem: QueryItem?
    private var insertHandler: ((QueryItem) -> Void)?
            
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
    }
    
    private func configureTypePopup(with selectedOption: String?) {
        queryButton.removeAllItems()
        let items = ["Title", "App name", "App version", "Platform", "System version", "Device ID", "Date/Time"]
        queryButton.addItems(withTitles: items)
        let selected = items.map{ $0.reducedEnumElement() }.firstIndex(of: selectedOption?.lowercased()) ?? 0
        
        queryButton.selectItem(at: selected)
    }
    
    private func configureEqualityPopup(with query: QueryItem) {
        equalityButton.removeAllItems()
        var items = ["Equals", "Contains", "Begins With", "Ends With"]
        if query.queryType == .datetime {
            items = ["Before or equals", "Before", "Equals", "After", "After or equals"]
        } else if query.queryType == .systemVersion || query.queryType == .appVersion {
            items = ["Less than or equals", "Less than", "Equals", "Greater than", "Greater than or equals"]
        }
        
        equalityButton.addItems(withTitles: items)
        
        let equalIndex = items.firstIndex(of: "Equals") ?? 0
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
        let newItem = queryItem?.queryItemWithNewDate(sender.dateValue)
        queryItem = newItem
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
                comparison = DateComparison.equals
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
    
    func controlTextDidChange(_ obj: Notification) {
        if let item = queryItem {
            let type = item.queryType
            if type == .datetime { return }
            let fieldEditor = obj.object
            if let textField = fieldEditor as? NSTextField, textField == searchTermText {
                if let item = queryItem {
                    if type == .appVersion || type == .systemVersion {
                        let newItem = item.queryItemWithNewNumeric(textField.stringValue)
                        queryItem = newItem
                    } else if type != .datetime {
                        let newItem = item.queryItemWithNewString(textField.stringValue)
                        queryItem = newItem
                        
                        if let handler = self.insertHandler {
                            handler(newItem)
                        }
                    }
                    if let handler = self.insertHandler, let query = self.queryItem {
                        handler(query)
                    }
                }
            }
        }
    }

}

