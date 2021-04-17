//
//  QueriesTable.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/11/21.
//

import Cocoa

protocol QueriesTableDelegate {
    func queriesTableSelectionChanged(selectedRow: Int)
}

class QueriesTable: NSTableView, NSTableViewDelegate, NSTableViewDataSource {
    private(set) var queryItems = [QueryItem()]
    private let queryCellIdentifier = "QueryCell"
    
    var queriesTableDelegate: QueriesTableDelegate?
    
    override func awakeFromNib() {
        selectionHighlightStyle = .regular
        rowHeight = 96
        scrollRowToVisible(0)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return queryItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(queryCellIdentifier), owner: self)
        guard let cellView = view as? QueryItemCell else {
            return view
        }

        let items = self.queryItems
        cellView.configure(with: queryItems[row], insertHandler: { [weak self] (queryItem) in
            guard let index = items.firstIndex(where: { $0.id == queryItem.id }) else { return }
            if index >= 0, let items = self?.queryItems, index < items.count {
                self?.queryItems[index] = queryItem
//                print("Item \(index) text: \(queryItem)")
            }
        })
        
        return cellView
    }
        
    func addQuery() {
        let item = QueryItem()
        queryItems.append(item)
        reloadData()
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = notification.object as? NSTableView {
            queriesTableDelegate?.queriesTableSelectionChanged(selectedRow: tableView.selectedRow)
        }
    }
}
