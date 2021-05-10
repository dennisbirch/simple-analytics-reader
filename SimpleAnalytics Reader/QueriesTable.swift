//
//  QueriesTable.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/11/21.
//

import Cocoa

protocol QueriesTableDelegate {
    func queriesTableSelectionChanged(selectedRow: Int)
    func searchQueriesChanged()
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

        cellView.configure(with: queryItems[row], insertHandler: queryItemsHandler())
        return cellView
    }
    
    private func queryItemsHandler() -> ((QueryItem) -> Void) {
        return { [weak self] (queryItem) in
            guard let index = self?.queryItems.firstIndex(where: { $0.id == queryItem.id }) else { return }
            if index >= 0, let items = self?.queryItems, index < items.count {
                self?.queryItems[index] = queryItem
            }
            
            self?.queriesTableDelegate?.searchQueriesChanged()
        }
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return QueriesTableRow()
    }
    
    override func didAdd(_ rowView: NSTableRowView, forRow row: Int) {
        rowView.backgroundColor = QueriesTableRow.baseColor
    }
    
    func loadQueries(_ queries: [QueryItem]) {
        self.queryItems = queries
        reloadData()
    }
        
    func addQuery() {
        let item = QueryItem()
        queryItems.append(item)
        reloadData()
    }
    
    func removeRow(_ row: Int) {
        queryItems.remove(at: row)
        if queryItems.isEmpty {
            queryItems.append(QueryItem())
        }

        reloadData()
    }
    
    func removeAll() {
        queryItems.removeAll()
        queryItems.append(QueryItem())
        reloadData()
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = notification.object as? NSTableView {
            let row = tableView.selectedRow
            queriesTableDelegate?.queriesTableSelectionChanged(selectedRow: row)
            tableView.enumerateAvailableRowViews { (rowView, _) in
                if rowView.isSelected {
                    rowView.backgroundColor = NSColor.tertiaryLabelColor
                } else {
                    rowView.backgroundColor = QueriesTableRow.baseColor
                }
                rowView.displayIfNeeded()
            }
        }
    }
    
    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        if type(of: responder) == NSTextField.self {
            self.selectRowIndexes([], byExtendingSelection: false)
        }
        return true
    }    
}

class QueriesTableRow: NSTableRowView {
    static let baseColor = NSColor.yellow.withAlphaComponent(0.4)
    private var cellTrackingArea: NSTrackingArea?
    private var mouseIsInside = false
    
    override func drawSelection(in dirtyRect: NSRect) {
        // TODO: Implement hover effect based on mouseIsInside status?
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if cellTrackingArea == nil {
            cellTrackingArea = NSTrackingArea(rect: NSRect.zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        }
        
        if let area = cellTrackingArea,
           trackingAreas.contains(area) == false {
            addTrackingArea(area)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        mouseIsInside = true
        setNeedsDisplay(bounds)
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseIsInside = false
        setNeedsDisplay(bounds)
    }
    
}
