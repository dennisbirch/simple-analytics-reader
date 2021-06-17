//
//  OSSummaryViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 6/14/21.
//

import Cocoa
import os.log

class OSSummaryViewController: NSViewController {
    static let viewControllerIdentifier = "OSSummaryViewController"
    
    @IBOutlet private weak var applicationsPopup: NSPopUpButton!
    @IBOutlet private weak var tablePopup: NSPopUpButton!
    @IBOutlet private weak var ageControl: NSComboBox!
    @IBOutlet private weak var resultsTextView: NSTextView!
    @IBOutlet private weak var daysAgoField: NSTextField!
    @IBOutlet private weak var heightConstraint: NSLayoutConstraint!
    
    private let sourceTables = ["Items", "Counters"]
    private let allDates = "All"
    private let dateSuggestions = ["All", "7", "30", "90"]
    
    private let showResultsHeightConstant: CGFloat = 220
    private let hideResultsHeightConstant: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        applicationsPopup.removeAllItems()
        applicationsPopup.addItems(withTitles: ListViewController.sharedApps)
        
        tablePopup.removeAllItems()
        tablePopup.addItems(withTitles: sourceTables)
        
        ageControl.removeAllItems()
        ageControl.addItems(withObjectValues: dateSuggestions)
        ageControl.selectItem(at: 1)
        
        ageControl.delegate = self
        
//        heightConstraint.constant = hideResultsHeightConstant
    }
    
    static func createViewController() -> OSSummaryViewController? {
        let storyboard = NSStoryboard(name: "OSSummary", bundle: nil)
        guard let summaryVC = storyboard.instantiateInitialController() as? OSSummaryViewController else {
            os_log("Can't instantiate OSSummary View Controller")
            return nil
        }
        
        return summaryVC
    }
    
    @IBAction func summarize(_ sender: NSButton) {
        guard let tableName = tablePopup.selectedItem?.title.lowercased() else {
            os_log("Table name item is nil")
            return
        }
        
        guard let appName = applicationsPopup.selectedItem?.title else {
            os_log("Application name item is nil")
            return
        }
        
        var timestampClause = ""
        if ageControl.stringValue != allDates {
            let now = Date()
            let daysAgo = ageControl.intValue
            let searchDate = now.addingTimeInterval(Double(-daysAgo) * (60.0 * 60.0 * 24.0))
            let searchDateString = searchDate.databaseFormatString()
            timestampClause = " AND timestamp >= \(searchDateString.sqlify()) "
        }
        
        let sql = "SELECT COUNT(system_version) AS 'count', system_version AS 'system' FROM \(tableName) WHERE device_id IN (SELECT DISTINCT(device_id) FROM \(tableName)) AND app_name = \(appName.sqlify()) \(timestampClause) GROUP BY system_version"
        
        let submitter = QuerySubmitter(query: sql, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                // TODO: Display error in text view
                return
            }
            
            self?.resultsTextView.string = String(describing: result)
        }
        
        submitter.submit()
    }
    
}

extension OSSummaryViewController: NSComboBoxDelegate {
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let combo = notification.object as? NSComboBox else {
            os_log("Didn't get combobox in notification")
            return
        }
        
        let value = combo.stringValue
        daysAgoField.isHidden = value != allDates
    }
}
