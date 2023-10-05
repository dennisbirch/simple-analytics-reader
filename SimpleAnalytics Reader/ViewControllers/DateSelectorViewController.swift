//
//  DateSelectorViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 10/2/23.
//

import Cocoa
import os.log

class DateSelectorViewController: NSViewController {
    static let viewControllerIdentifier = "DateSelectorViewController"
    @IBOutlet private weak var dateRangePopup: NSPopUpButton!
    @IBOutlet private weak var dateSelector: NSDatePicker!
    @IBOutlet private weak var containerView: NSStackView!
    
    var restrictDates: Bool = false
    var dateRange = ""
    var date: Date? = nil
    private(set) var delay: Int = 1000
    
    override func viewDidLoad() {
        super.viewDidLoad()

        dateRangePopup.removeAllItems()
        dateRangePopup.addItems(withTitles: [
            LocalizedQueryString.before,
            LocalizedQueryString.beforeOrEqual,
            LocalizedQueryString.equals,
            LocalizedQueryString.afterEquals,
            LocalizedQueryString.after
        ])

        dateSelector.dateValue = Date()
    }

    static func create() -> DateSelectorViewController? {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let viewController = storyboard.instantiateController(withIdentifier: viewControllerIdentifier) as? DateSelectorViewController else {
            return nil
        }
        
        return viewController
    }
    
    var whereClause: String? {
        if restrictDates == false { return nil }
        
        guard let date = date else {
            os_log("Date is nil. Unable to provide a where clause")
            return nil
        }
        
        let comparison = DateComparison.fromString(dateRange)
        let queryItem = QueryItem(queryType: .datetime, dateComparison: comparison as! DateComparison, value: date)
        return queryItem.sqlWhereString()
    }
    
    @IBAction private func selectedDateRange(_ sender: NSButton) {
        dateRange = sender.selectedCell()?.title ?? ""        
        // allow a one-second delay for other changes before taking further action
        updateDelayAndNotifyChange(delay: 1000)
    }
    
    @IBAction private func changedDate(_ sender: NSDatePicker) {
        date = sender.dateValue
        // allow a half-second delay for other changes before taking further action
        updateDelayAndNotifyChange(delay: 500)
    }
    
    @IBAction private func restrictDatesToggled(_ sender: NSButton) {
        restrictDates = (sender.state == .on)
        dateSelector.isEnabled = restrictDates
        dateRangePopup.isEnabled = restrictDates
        if restrictDates == true {
            dateRange = dateRangePopup.itemTitle(at: dateRangePopup.indexOfSelectedItem)
            date = dateSelector.dateValue
        }
        
        // allow 1 second before notifying of a change for other actions after turning on, or one-tenth-second if turning off
        updateDelayAndNotifyChange(delay: (restrictDates == true) ? 1000 : 100)
    }
    
    private func updateDelayAndNotifyChange(delay: Int) {
        self.delay = delay
        NotificationCenter.default.post(name: queryDateChangeNotification, object: nil)
    }
}

let notificationNameString = "DateSelectorChangeNotification"
let queryDateChangeNotification = Notification.Name(rawValue: notificationNameString)
