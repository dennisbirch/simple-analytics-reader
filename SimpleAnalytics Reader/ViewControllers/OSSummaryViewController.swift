//
//  OSSummaryViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 6/14/21.
//

import Cocoa
import Combine
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
        get {
            if let tabStyle = _tabStyle {
                return tabStyle
            } else {
                return NSParagraphStyle()
            }
        }
        set {
            _tabStyle = newValue
        }
    }
    private var _tabStyle: NSParagraphStyle?

    private var searchTextObserver: AnyCancellable?

    private let sourceTables = ["Items", "Counters"]
    private let platforms = ["iOS", "macOS"]
    private let allDates = "All"
    private let bothSources = "Both"
    private let dateSuggestions = ["1", "7", "30", "90"]
    private let frameIdentifier = "osSummaryWindowFrame"
    private let lastSourceSelectionKey = "summaryLastSourceSelection"
    private let lastPlatformSelectionKey = "summaryLastPlatformSelection"
    private let lastAppSelectionKey = "summaryLastAppSelection"
    private let lastDateSelectionKey = "summaryLastDateSelection"
    private let uniqueDeviceCountKey = "device_count"
    private let versionKey = "version"
    private let countKey = "count"
    private let totalCountKey = "totalCount"
    
    private let showResultsHeightConstant: CGFloat = 180
    private let hideResultsHeightConstant: CGFloat = 0
    
    typealias VersionInfoDef = (version: String, count: String)
    
    // MARK: - ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        applicationsPopup.removeAllItems()
        applicationsPopup.addItems(withTitles: ListViewController.sharedApps)
        
        tablePopup.removeAllItems()
        tablePopup.addItems(withTitles: sourceTables)
        tablePopup.addItem(withTitle: bothSources)
        
        platformPopup.removeAllItems()
        platformPopup.addItems(withTitles: platforms)
        
        ageCombobox.removeAllItems()
        ageCombobox.addItems(withObjectValues: dateSuggestions)
        ageCombobox.addItem(withObjectValue: allDates)
        ageCombobox.selectItem(at: 0)
        
        ageCombobox.delegate = self
        
        heightConstraint.constant = hideResultsHeightConstant
        
        setInputSelections()
        
        adjustTabStyle()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        restoreDefaultState()
        
        guard let window = view.window else {
            return
        }
        
        window.delegate = self
        
        window.setFrameUsingName(frameIdentifier)
        
        window.stripTitleChrome()
        
        setupSearchTextObserver()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        view.window?.saveFrame(usingName: frameIdentifier)
        UserDefaults.standard.set(applicationsPopup.titleOfSelectedItem ?? "", forKey: lastAppSelectionKey)
        UserDefaults.standard.set(platformPopup.indexOfSelectedItem, forKey: lastPlatformSelectionKey)
        UserDefaults.standard.set(tablePopup.indexOfSelectedItem, forKey: lastSourceSelectionKey)
        UserDefaults.standard.set(ageCombobox.stringValue, forKey: lastDateSelectionKey)
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
        
        // if text other than "All" is entered, the age value will be 0, so assure a value of at least 1
        // and populate the combobox with that
        if ageCombobox.stringValue.lowercased() != allDates.lowercased() {
            let days = max(1, ageCombobox.intValue)
            ageCombobox.intValue = days
        }
        
        resultsTextView.string = ""
        fetchButton.isEnabled = false
        fetchSpinnner.startAnimation(true)
        fetchSpinnner.isHidden = false
        
        var timestampClause = ""
        if ageCombobox.stringValue.lowercased() != allDates.lowercased() {
            let now = Date()
            let daysAgo = ageCombobox.intValue
            let searchDate = now.addingTimeInterval(Double(-daysAgo) * (60.0 * 60.0 * 24.0))
            let searchDateString = searchDate.databaseFormatString()
            timestampClause = " AND timestamp >= \(searchDateString.sqlify()) "
        }
        
        let sql = summarySQLString(table: tableName, appName: appName, platform: platform, timestampClause: timestampClause)
        
        Task {
            let submitter = QuerySubmitter(query: sql, mode: .dictionary)
            let result = await submitter.submit()
            switch result {
                case .failure(let error):
                    restoreDefaultState()
                    NSAlert.presentAlert(title: "Error", message: "The query failed with the error: \(String(describing: error))")
                    
                case .success(let response):
                    guard let response = response as? [[String : String]] else {
                        displayErrorMessage("There was an error fetching system version information from the database.")
                        return
                    }
                                        
                    restoreDefaultState()
                    displayResults(response)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func restoreDefaultState() {
        fetchSpinnner.stopAnimation(self)
        fetchSpinnner.isHidden = true
        fetchButton.isEnabled = true
    }
    
    private func summarySQLString(table: String, appName: String, platform: String, timestampClause: String) -> String {
        // Creates a query that gets the count of devices using each system version in the database table(s) specified, for the app and platform specified, within the date range entered. Also gets the unique device ID count for the same specs.
        let tables: [String]
        if table == bothSources.lowercased() {
            tables = sourceTables
        } else {
            tables = [table]
        }
        
        var sql = [String]()
        let whereClause = "\(Common.appName) = \(appName.sqlify()) AND \(Common.platform) LIKE \("\(platform)%".sqlify()) \(timestampClause)"
        for tableName in tables {
            let statement =
    """
    SELECT COUNT(\(Common.deviceID)) AS '\(countKey)', \(Common.systemVersion) AS '\(versionKey)' FROM \(tableName.lowercased()) WHERE \(Common.systemVersion) IN (SELECT DISTINCT(\(Common.systemVersion)) FROM \(tableName.lowercased()) WHERE \(whereClause)) GROUP BY \(Common.systemVersion) ORDER BY \(Common.systemVersion);
    SELECT COUNT(DISTINCT(\(Common.deviceID))) AS \(uniqueDeviceCountKey) FROM \(tableName.lowercased()) WHERE \(whereClause)
    """
            sql.append(statement)
        }
        
        return sql.joined(separator: ";\n")
    }
    
    private func displayResults(_ results: [[String : String]]) {
        if heightConstraint.constant != showResultsHeightConstant {
            heightConstraint.constant = showResultsHeightConstant
        }
        
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
            // merge results of "both" query if necessary
            var versionInfo = mergeFetchResults(results)
            
            guard let deviceCountIndex = versionInfo.firstIndex(where: { $0.version == uniqueDeviceCountKey }) else {
                os_log("Failed to fetch the total device count from the server")
                NSAlert.presentAlert(title: "Error", message: "The server did not return a total device count.")
                return
            }
            
            let deviceCount = versionInfo[deviceCountIndex].count
            versionInfo.remove(at: deviceCountIndex)

            guard let totalIndex = versionInfo.firstIndex(where: { $0.version == totalCountKey }) else {
                os_log("Failed to parse a total reading count from the merge function.")
                NSAlert.presentAlert(title: "Error", message: "There was a problem parsing the data received from the server.")
                return
            }
            
            let totalString = versionInfo[totalIndex].count
            versionInfo.remove(at: totalIndex)
            guard let totalReadings = Int(totalString) else {
                os_log("Error converting total string to Int")
                NSAlert.presentAlert(title: "Error", message: "There was an internal error converting data.")
                return
            }
            
            let attrVersionsString = attributedVersionsList(versionInfo, total: totalReadings)
            attributedStr = "System Versions\n".applyH2()
            attributedStr.append("Version\t# Readings\t%\n".applyH4().applyUnderline())
            attributedStr.append(attrVersionsString)
            
            if deviceCount.isEmpty == false {
                let deviceCntStr = String(deviceCount.formatted())
                attributedStr.append(NSAttributedString(string: "\n"))
                attributedStr.append("Total readings: ".applyBoldBody())
                attributedStr.append(totalString.formatted().applyBody())
                attributedStr.append(NSAttributedString(string: "\n"))
                attributedStr.append("Total devices: ".applyBoldBody())
                attributedStr.append(deviceCntStr.applyBody())
            }
        }

        let range = NSMakeRange(0, attributedStr.string.count)
        attributedStr.addAttribute(.paragraphStyle, value: tabStyle, range: range)
        
        resultsTextView.textStorage?.insert(attributedStr, at: 0)
    }
    
    private func mergeFetchResults(_ array: [[String : String]]) -> [VersionInfoDef] {
        var totalDeviceCount = 0
        var merged = [VersionInfoDef]()
        var total = 0
        for item in array {
            let itemVersion = item[versionKey]
            // first look for version matches already in the 'merged' array and add the count value to the existing count value for that item
            if let match = merged.first(where: { $0.version == itemVersion }) {
                let versionStr = match.version
                let count = match.count
                if versionStr.isEmpty == false,
                   let startCount = Int(count),
                   let itemCount = item[countKey], let addCount = Int(itemCount) {
                    let newCount = startCount + addCount
                    let newVersion = (versionStr, "\(newCount)")
                    total += addCount
                    if let idx = merged.firstIndex(where: { $0.version == versionStr }) {
                        merged[idx] = newVersion
                    }
                }
            } else if let versionStr = itemVersion,
                      versionStr.isEmpty == false,
                      let countStr = item[countKey],
                      let count = Int(countStr) {
                // no version match, so just add it to the array
                merged.append((versionStr, countStr))
                total += count
            } else if let deviceCountStr = item[uniqueDeviceCountKey],
                      let deviceCount = Int(deviceCountStr) {
                // this item is a device count result, so add its value to the deviceCount var
                totalDeviceCount += deviceCount
            }
        }
        
        merged.insert((uniqueDeviceCountKey, String(totalDeviceCount)), at: 0)
        merged.insert((totalCountKey, String(total)), at: 1)
        
        return merged
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
                    mutableAttrItem.append("\(version.version):".applyBoldBody())
                    let values = "\t\(version.count.formatted())\t\(pctString)"
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
    
    private func setInputSelections() {
        if let lastSelectedApp = UserDefaults.standard.string(forKey: lastAppSelectionKey) {
            if let index = applicationsPopup.itemTitles.firstIndex(of: lastSelectedApp) {
                applicationsPopup.selectItem(at: index)
            }
        }
        if let lastSelectedDateRangeValue = UserDefaults.standard.string(forKey: lastDateSelectionKey) {
            ageCombobox.stringValue = lastSelectedDateRangeValue
        }
        let lastSourceSelection = UserDefaults.standard.integer(forKey: lastSourceSelectionKey)
        tablePopup.selectItem(at: lastSourceSelection)
        let lastPlatformSelection = UserDefaults.standard.integer(forKey: lastPlatformSelectionKey)
        platformPopup.selectItem(at: lastPlatformSelection)
    }

    private func setupSearchTextObserver() {
        let sub = NotificationCenter.default
            .publisher(for: NSControl.textDidChangeNotification, object: ageCombobox)
            .map( { ($0.object as! NSTextField).stringValue } )
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink(receiveValue: { [weak self] in
                self?.daysAgoField.isHidden = (!$0.isNumeric())
            })
        
        searchTextObserver = sub
    }

    private func adjustTabStyle() {
        let pStyle = NSMutableParagraphStyle()
        let font = NSFont.systemFont(ofSize: bodyFontSize)
        let advanceWidth = font.maximumAdvancement.width
        let tabInterval = advanceWidth * 3
        pStyle.defaultTabInterval = tabInterval
        pStyle.lineSpacing = 2
        let scroll = resultsTextView.superview?.superview as? NSScrollView
        let width = scroll?.contentSize.width ?? resultsTextView.bounds.width
        let scrollBuffer: CGFloat = 16
        let tabStops = [NSTextTab(textAlignment: .right, location: tabInterval * 2.75, options: [:]),
                        NSTextTab(textAlignment: .right, location: width - scrollBuffer, options: [:])]
        pStyle.tabStops = tabStops
        self.tabStyle = pStyle
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
    
    fileprivate func isNumeric() -> Bool {
        return self.allSatisfy{ $0.isNumber }
    }
}

// MARK: -
extension NSMutableAttributedString {
    fileprivate func applyUnderline() -> NSMutableAttributedString {
        addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.byWord.rawValue, range: NSMakeRange(0, string.count))
        return self
    }
}
