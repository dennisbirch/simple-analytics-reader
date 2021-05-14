//
//  DetailsViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/13/21.
//

import Cocoa

enum DeviceCountTableType {
    case detail
    case platform
    case actions
}

class DeviceCountViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    static let viewControllerIdentifier = "DetailsViewController"
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var deviceCountContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var deviceCountLabel: NSTextField!
    @IBOutlet private weak var deviceCountContainer: NSView!

    private var details = [[String : String]]()
    private var deviceCount = ""
    private let noDetails = "----"
    
    private let collapsedUserCountHeight: CGFloat = 0
    private let expandedUserCountHeight: CGFloat = 60

    override func viewDidLoad() {
        super.viewDidLoad()
        
        displayDeviceCountContent(deviceCount.isEmpty == false)
    }
    
    func configureWithResult(_ result: [[String : String]], deviceCount: String) {
        details = result
        self.deviceCount = deviceCount
        
        tableView.reloadData()
        displayDeviceCountContent(deviceCount.isEmpty == false)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = details[row]
        if tableColumn == tableView.tableColumns[1] {
            var detail = item["details"] ?? noDetails
            if detail.isEmpty {
                detail = noDetails
            }
            return NSTextField(labelWithString: detail)
            
        } else if tableColumn == tableView.tableColumns[0],
                  let timestamp = item["timestamp"] {
            if let date = timestamp.dateFromISOString() {
                return NSTextField(labelWithString: DateFormatter.shortDateTimeFormatter.string(from: date))
            } else {
                return NSTextField(labelWithString: timestamp)
            }
        } else if tableColumn == tableView.tableColumns[2] {
            let device = item["device_id"] ?? noDetails
            return NSTextField(labelWithString: String("...\(device.suffix(8))"))
        }
        
        return nil
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return details.count
    }
    
    private func displayDeviceCountContent(_ isVisible: Bool) {
        if isVisible == true {
            let formatStr = NSLocalizedString("unique-devices-label %@", comment: "String for 'Unique devices count' label")
            deviceCountLabel.stringValue = String(format: formatStr, deviceCount)
            deviceCountContainerHeightConstraint.constant = expandedUserCountHeight
        } else {
            deviceCountContainerHeightConstraint.constant = collapsedUserCountHeight
        }

        NSAnimationContext.runAnimationGroup { [weak self] (context) in
            context.duration = 0.25
            self?.deviceCountContainer.layoutSubtreeIfNeeded()
        }
    }
}
