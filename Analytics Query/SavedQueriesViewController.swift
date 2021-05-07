//
//  SavedQueriesViewController.swift
//  Analytics Query
//
//  Created by Dennis Birch on 5/5/21.
//

import Cocoa
import os.log

class SavedQueriesViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    static let viewControllerIdentifier = "SavedQueriesViewController"
    var isLoading = true
    var files = [URL]()
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var deleteButton: NSButton!
    @IBOutlet private weak var loadButton: NSButton!
    @IBOutlet private weak var cancelButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        loadButton.isHidden = (isLoading == false)
        deleteButton.isHidden = (isLoading == true)
        cancelButton.title = (isLoading == true) ? "Cancel" : "Done"
    }
    
    @IBAction func deleteItem(_ sender: NSButton) {
        let row = tableView.selectedRow
        if row < 0 || row >= files.count {
            NSSound.beep()
            return
        }
        
        let url = files[row]
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
                files.remove(at: row)
                tableView.reloadData()
            } catch {
                os_log("Error removing file: %@: %@", url.path, error.localizedDescription)
                dismiss(self)
                let title = NSLocalizedString("error-removing-query-file-title", comment: "Title for error alert")
                let message = NSLocalizedString("error-removing-query-file-message", comment: "Message for error alert when query file can't be deleted")
                let alert = NSAlert.okAlertWithTitle(title, message: message)
                alert.runModal()
            }
        }
    }
    
    @IBAction func loadItem(_ sender: NSButton) {
        
    }

    @IBAction func cancel(_ sender: NSButton) {
        dismiss(self)
    }
    
    // MARK: - NSTableViewDelegate/DataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let file = files[row]
        let path = file.path.replacingOccurrences(of: ".\(savedQueryFileExtension)", with: "").replacingOccurrences(of: "\(FileManager.queryFileFolder.path)/", with: "")
        let label = NSTextField(labelWithString: path)
        return label
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if isLoading == true {
            loadButton.isEnabled = tableView.selectedRow >= 0
        } else {
            deleteButton.isEnabled = tableView.selectedRow >= 0
        }
    }

}
