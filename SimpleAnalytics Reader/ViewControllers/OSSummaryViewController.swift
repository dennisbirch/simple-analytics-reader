//
//  OSSummaryViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 6/14/21.
//

import Cocoa
import os.log

fileprivate let bodyFontSize: CGFloat = 13

class OSSummaryViewController: NSViewController {
    static let viewControllerIdentifier = "OSSummaryViewController"
    
    @IBOutlet private weak var applicationsPopup: NSPopUpButton!
    @IBOutlet private weak var tablePopup: NSPopUpButton!
    @IBOutlet private weak var platformPopup: NSPopUpButton!
    @IBOutlet private weak var ageCombobox: NSComboBox!
    @IBOutlet private weak var resultsTextView: NSTextView!
    @IBOutlet private weak var daysAgoField: NSTextField!
    @IBOutlet private weak var heightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var fetchSpinnner: NSProgressIndicator!
    @IBOutlet private weak var fetchButton: NSButton!
    
    private var percentFormatter: NumberFormatter {
        let numFormatter = NumberFormatter()
        numFormatter.numberStyle = .percent
        numFormatter.localizesFormat = true
        numFormatter.locale = Locale.current
        numFormatter.maximumFractionDigits = 1
        return numFormatter
    }

    private var tabStyle: NSParagraphStyle {
        let pStyle = NSMutableParagraphStyle()
        let font = NSFont.systemFont(ofSize: bodyFontSize)
        let charWidth = font.screenFont(with: .defaultRenderingMode).advancement(forGlyph: 32).width
        pStyle.defaultTabInterval = charWidth * 4
        pStyle.lineSpacing = 2
        let tabStops = [NSTextTab(textAlignment: .right, location: 30, options: [:]),
                        NSTextTab(textAlignment: .right, location: 40, options: [.columnTerminators : "."])]
        pStyle.tabStops = tabStops
        return pStyle
    }

    private let sourceTables = ["Items", "Counters"]
    private let platforms = ["iOS", "macOS"]
    private let allDates = "All"
    private let dateSuggestions = ["All", "7", "30", "90"]
    private let frameIdentifier = "osSummaryWindowFrame"
    private let uniqueDeviceCountKey = "device_count"
    private let versionKey = "version"
    private let countKey = "count"
    
    private let showResultsHeightConstant: CGFloat = 120
    private let hideResultsHeightConstant: CGFloat = 0
    
    typealias VersionInfoDef = (version: String, count: String)
    
    // MARK: - ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        applicationsPopup.removeAllItems()
        applicationsPopup.addItems(withTitles: ListViewController.sharedApps)
        
        tablePopup.removeAllItems()
        tablePopup.addItems(withTitles: sourceTables)
        
        platformPopup.removeAllItems()
        platformPopup.addItems(withTitles: platforms)
        
        ageCombobox.removeAllItems()
        ageCombobox.addItems(withObjectValues: dateSuggestions)
        ageCombobox.selectItem(at: 1)
        
        ageCombobox.delegate = self
        
        heightConstraint.constant = hideResultsHeightConstant
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        fetchSpinnner.isHidden = true
        fetchSpinnner.stopAnimation(self)
        
        guard let window = view.window else {
            return
        }
        
        window.delegate = self
        
        window.setFrameUsingName(frameIdentifier)
        
        window.stripTitleChrome()
        
        setupTextViewTabbing()
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
    
    // MARK: - Actions

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
        fetchButton.isEnabled = false
        fetchSpinnner.startAnimation(true)
        fetchSpinnner.isHidden = false
        
        var timestampClause = ""
        if ageCombobox.stringValue != allDates {
            let now = Date()
            let daysAgo = ageCombobox.intValue
            let searchDate = now.addingTimeInterval(Double(-daysAgo) * (60.0 * 60.0 * 24.0))
            let searchDateString = searchDate.databaseFormatString()
            timestampClause = " AND timestamp >= \(searchDateString.sqlify()) "
        }
        
        // Creates a query that gets the count of devices using each system version in the database table specified, for the app and platform specified, within the date range entered. Also gets the unique device IDs for the same specs.
        let whereClause = "\(Common.appName) = \(appName.sqlify()) AND \(Common.platform) LIKE \("\(platform)%".sqlify()) \(timestampClause)"
        let sql =
"""
SELECT COUNT(\(Common.deviceID)) AS '\(countKey)', \(Common.systemVersion) AS '\(versionKey)' FROM \(tableName) WHERE \(Common.systemVersion) IN (SELECT DISTINCT(\(Common.systemVersion)) FROM \(tableName) WHERE \(whereClause)) GROUP BY \(Common.systemVersion);
SELECT COUNT(DISTINCT(\(Common.deviceID))) AS \(uniqueDeviceCountKey) FROM \(tableName) WHERE \(whereClause)
"""
                
        let submitter = QuerySubmitter(query: sql, mode: .dictionary) { [weak self] result in
            guard let result = result as? [[String : String]] else {
                self?.displayErrorMessage("There was an error fetching system version information from the database.")
                return
            }
            
            self?.fetchSpinnner.stopAnimation(self)
            self?.fetchSpinnner.isHidden = true
            self?.fetchButton.isEnabled = true
            self?.displayResults(result)
        }
        
        submitter.submit()
    }
    
    // MARK: - Private Methods
    
    private func displayResults(_ results: [[String : String]]) {
        heightConstraint.constant = showResultsHeightConstant
        
        NSAnimationContext.runAnimationGroup { [weak self] (context) in
            context.duration = 0.25
            self?.view.layoutSubtreeIfNeeded()
        }
        
        var attributedStr = NSMutableAttributedString()

        if results.isEmpty {
            attributedStr = "Nothing found".applyH2()
            attributedStr.append(NSAttributedString(string: "\n"))
            attributedStr.append("Your search query returned no results\nTry changing your search criteria and performing a new fetch.".applyH3())
        } else {
            // parse the results into an array of VersionInfoDef's
            var total = 0

            let deviceCount = results.filter{ $0[uniqueDeviceCountKey] != nil }.first?.values.first
            
            let versionInfo: [VersionInfoDef] = results.map{
                if let version = $0[versionKey],
                   let count = $0[countKey],
                   let number = Int(count),
                   number > 0 {
                    total += number
                    return VersionInfoDef(version, count)
                }
                // if-let conditions not met
                return VersionInfoDef("", "")
            }

            let attrVersionsString = attributedVersionsList(versionInfo, total: total)
            attributedStr = "System Versions\n".applyH2()
            attributedStr.append(attrVersionsString)
            
            if let deviceCount = deviceCount,
               deviceCount.isEmpty == false {
                let deviceCntStr = String(deviceCount)
                attributedStr.append(NSAttributedString(string: "\n\n"))
                attributedStr.append("Total devices: ".applyBoldBody())
                attributedStr.append(deviceCntStr.applyBody())
            }
        }

        let range = NSMakeRange(0, attributedStr.string.count)
        attributedStr.addAttribute(.paragraphStyle, value: tabStyle, range: range)
        
        resultsTextView.textStorage?.insert(attributedStr, at: 0)
    }
    
    private func attributedVersionsList(_ list: [VersionInfoDef], total: Int) -> NSAttributedString {
        // convert an array of VersionInfoDefs into a Tab and Return delimited NSAttributedString with percentages applied
        let attrList = NSMutableAttributedString()
        for version in list {
            let mutableAttrItem = NSMutableAttributedString()
            if let number = Int(version.count),
               total > 0 {
                let percent = Double(number)/Double(total)
                if let pctString = percentFormatter.string(from: NSNumber(value: percent)) {
                    mutableAttrItem.append("Version ".applyBoldBody())
                    let values = "\(version.version):\t\(version.count)\t(\(pctString))"
                    mutableAttrItem.append(values.applyBody())
                }
                mutableAttrItem.append(NSAttributedString(string: "\n"))
                
                attrList.append(mutableAttrItem)
            }
        }
        
        return NSAttributedString(attributedString: attrList)
    }
    
    private func displayErrorMessage(_ message: String) {
        let attrStr = message.applyH3()
        resultsTextView.textStorage?.insert(attrStr, at: 0)
    }
    
    private func setupTextViewTabbing() {
        var textViewAttributes = resultsTextView.typingAttributes
        textViewAttributes[NSAttributedString.Key.paragraphStyle] = tabStyle
        textViewAttributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: bodyFontSize)
        resultsTextView.typingAttributes = textViewAttributes
        
        if let defaultGraphStyle = resultsTextView.defaultParagraphStyle {
            let mutableDefaultStyle = defaultGraphStyle.mutableCopy() as! NSMutableParagraphStyle
            mutableDefaultStyle.tabStops = tabStyle.tabStops
            resultsTextView.defaultParagraphStyle = mutableDefaultStyle
        } else {
            let mutableDefaultStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            mutableDefaultStyle.tabStops = tabStyle.tabStops
            resultsTextView.defaultParagraphStyle = mutableDefaultStyle
        }
        
        resultsTextView.defaultParagraphStyle = tabStyle
    }
    

}

// MARK: - NSComboBoxDelegate

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

// MARK: - NSWindowDelegate

extension OSSummaryViewController: NSWindowDelegate {
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        var newSize = frameSize
        newSize.height = max(newSize.height, sender.minSize.height)
        return newSize
    }
}

// MARK: -

extension String {
    fileprivate func applyH1() -> NSMutableAttributedString {
        return self.applyFontSized(24, bold: true)
    }
    
    fileprivate func applyH2() -> NSMutableAttributedString {
        return applyFontSized(20, bold: true)
    }
    
    fileprivate func applyH3() -> NSMutableAttributedString {
        return applyFontSized(16)
    }
    
    fileprivate func applyH4() -> NSMutableAttributedString {
        return applyFontSized(14)
    }
    
    fileprivate func applyBody() -> NSMutableAttributedString {
        return applyFontSized(bodyFontSize)
    }
    
    fileprivate func applyBoldBody() -> NSMutableAttributedString {
        return applyFontSized(bodyFontSize, bold: true)
    }
    
    fileprivate func applyFontSized(_ size: CGFloat, bold: Bool = false) -> NSMutableAttributedString {
        let font: NSFont
        if bold == true {
            font = NSFont.boldSystemFont(ofSize: size)
        } else {
            font = NSFont.systemFont(ofSize: size)
        }
        
        return NSMutableAttributedString(attributedString: NSAttributedString(string: self, attributes: [.font : font]))
    }
}
