//
//  OSSummaryViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 6/14/21.
//

import Cocoa
import SwiftyMarkdown
import os.log

class OSSummaryViewController: NSViewController {
    static let viewControllerIdentifier = "OSSummaryViewController"
    
    @IBOutlet private weak var applicationsPopup: NSPopUpButton!
    @IBOutlet private weak var tablePopup: NSPopUpButton!
    @IBOutlet private weak var platformPopup: NSPopUpButton!
    @IBOutlet private weak var ageControl: NSComboBox!
    @IBOutlet private weak var resultsTextView: NSTextView!
    @IBOutlet private weak var daysAgoField: NSTextField!
    @IBOutlet private weak var heightConstraint: NSLayoutConstraint!
    
    private var percentFormatter: NumberFormatter {
        let numFormatter = NumberFormatter()
        numFormatter.numberStyle = .percent
        numFormatter.localizesFormat = true
        numFormatter.locale = Locale.current
        numFormatter.maximumFractionDigits = 1
        return numFormatter
    }
    
    private let sourceTables = ["Items", "Counters"]
    private let platforms = ["iOS", "macOS"]
    private let allDates = "All"
    private let dateSuggestions = ["All", "7", "30", "90"]
    private let frameIdentifier = "osSummaryWindowFrame"
    
    private let showResultsHeightConstant: CGFloat = 120
    private let hideResultsHeightConstant: CGFloat = 0
    
    typealias VersionInfoDef = (version: String, count: String)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        applicationsPopup.removeAllItems()
        applicationsPopup.addItems(withTitles: ListViewController.sharedApps)
        
        tablePopup.removeAllItems()
        tablePopup.addItems(withTitles: sourceTables)
        
        platformPopup.removeAllItems()
        platformPopup.addItems(withTitles: platforms)
        
        ageControl.removeAllItems()
        ageControl.addItems(withObjectValues: dateSuggestions)
        ageControl.selectItem(at: 1)
        
        ageControl.delegate = self
        resultsTextView.isRichText = true
        
        heightConstraint.constant = hideResultsHeightConstant
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        guard let window = view.window else {
            return
        }
        
        window.delegate = self
        
        window.setFrameUsingName(frameIdentifier)
        
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        view.window?.saveFrame(usingName: frameIdentifier)
    }
    
    static func createWindowController() -> NSWindowController? {
        let storyboard = NSStoryboard(name: "OSSummary", bundle: nil)
        guard let summaryWC = storyboard.instantiateInitialController() as? NSWindowController else {
            os_log("Can't instantiate OSSummary View Controller")
            return nil
        }
        
        return summaryWC
    }
    
    @IBAction func dismissWindow(_ sender: NSButton) {
        if heightConstraint.constant == showResultsHeightConstant,
           let window = view.window {
            // prepare window for saving frame at minimized size
            let heightDelta: CGFloat = window.maxSize.height - window.minSize.height
            heightConstraint.constant = hideResultsHeightConstant
            var newOrigin = window.frame.origin
            newOrigin.y += heightDelta
            window.setFrameOrigin(newOrigin)
        }
        
        view.window?.close()
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
        
        guard let platform = platformPopup.selectedItem?.title else {
            os_log("Platform selection is nil")
            return
        }
        
        resultsTextView.string = ""
        
        var timestampClause = ""
        if ageControl.stringValue != allDates {
            let now = Date()
            let daysAgo = ageControl.intValue
            let searchDate = now.addingTimeInterval(Double(-daysAgo) * (60.0 * 60.0 * 24.0))
            let searchDateString = searchDate.databaseFormatString()
            timestampClause = " AND timestamp >= \(searchDateString.sqlify()) "
        }
        
        // creates a query that gets the count of devices using each system version in the database for the app and platform specified, within the date range entered
        let whereClause = "\(Common.appName) = \(appName.sqlify()) AND \(Common.platform) LIKE \("\(platform)%".sqlify()) \(timestampClause)"
        let sql =
"""
SELECT COUNT(\(Common.deviceID)) AS 'count', \(Common.systemVersion) AS 'version' FROM \(tableName) WHERE \(Common.systemVersion) IN (SELECT DISTINCT(\(Common.systemVersion)) FROM \(tableName) WHERE \(whereClause)) GROUP BY \(Common.systemVersion);
SELECT DISTINCT(\(Common.deviceID)) FROM \(tableName) WHERE \(whereClause)
"""
                
        let submitter = QuerySubmitter(query: sql, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                self?.displayErrorMessage("There was an error fetching system version information from the database.")
                return
            }
            
            self?.displayResults(result)
        }
        
        submitter.submit()
    }
    
    private func displayResults(_ results: [[String : String]]) {
        heightConstraint.constant = showResultsHeightConstant
        
        NSAnimationContext.runAnimationGroup { [weak self] (context) in
            context.duration = 0.25
            self?.view.layoutSubtreeIfNeeded()
        }
        
        var mdString = ""

        if results.isEmpty {
            mdString = "## Nothing found\n### Your search query returned no results\nTry changing your search criteria and performing a new fetch."
        } else {
            // parse the results into an array of VersionInfoDef's
            var versionInfo = [VersionInfoDef]()
            var total = 0
            var deviceCount = 0
            for item in results {
                if let version = item["version"],
                   version.isEmpty == false,
                   let count = item["count"],
                   let number = Int(count),
                   number > 0 {
                    let newVersionDef = ("__Version \(version)__", count)
                    versionInfo.append(newVersionDef)
                    total += number
                } else if let _ = item[Common.deviceID] {
                    deviceCount += 1
                }
            }
            // calculate percentages and generate version strings for display
            var versionsString = [String]()
            for version in versionInfo {
                if let number = Int(version.count) {
                    let percent = Double(number)/Double(total)
                    if let pctString = percentFormatter.string(from: NSNumber(value: percent)) {
                        versionsString.append("\(version.version):  \t\(version.count)  \t(\(pctString))")
                    }
                }
            }
            mdString =
                """
                ### System Versions
                \(versionsString.joined(separator: "\n"))
                """
            if deviceCount > 0 {
                mdString.append("\nTotal devices: \(deviceCount)")
            }
        }

        // Use the SwiftyMarkdown module to convert the raw markdown string to an NSAttributedString
        let md = SwiftyMarkdown(string: mdString)
        md.applyDefaultStyles()
        let attrStr = md.attributedString()
        resultsTextView.textStorage?.append(attrStr)
    }
    
    private func displayErrorMessage(_ message: String) {
        let mdString = "### \(message)"
        let md = SwiftyMarkdown(string: mdString)
        md.applyDefaultStyles()
        let attrStr = md.attributedString()
        resultsTextView.textStorage?.append(attrStr)
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        if heightConstraint.constant == hideResultsHeightConstant,
           let window = view.window,
           window.frame.size.height == window.maxSize.height {
            var newFrame = window.frame
            newFrame.size.height = window.minSize.height
            view.window?.setFrame(newFrame, display: false)
        }
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

extension OSSummaryViewController: NSWindowDelegate {
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        var newSize = frameSize
        newSize.height = max(newSize.height, sender.minSize.height)
        return newSize
    }
}

extension SwiftyMarkdown {
    func applyDefaultStyles() {
        h1.fontSize = 24
        h1.fontStyle = .bold
        h2.fontSize = 20
        h2.fontStyle = .bold
        h3.fontSize = 16
        h4.fontSize = 14
    }
}
