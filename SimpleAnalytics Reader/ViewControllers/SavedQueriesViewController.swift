//
//  SavedQueriesViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/5/21.
//

import Cocoa
import os.log

class SavedQueriesViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    static let viewControllerIdentifier = "SavedQueriesViewController"
    private var isLoading = false
    private var isExecutingSQL = false
    private var files = [URL]()
    private var loadingHandler: ((URL) -> Void)?
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var deleteButton: NSButton!
    @IBOutlet private weak var loadButton: NSButton! // doubles as "Execute" button
    @IBOutlet private weak var cancelButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadButton.isHidden = (isLoading == false && isExecutingSQL == false)
        deleteButton.isHidden = (isLoading == true)
        tableView.doubleAction = #selector(handleTableDoubleClick)
        cancelButton.title = (isLoading == true) ? "Cancel" : "Done"
        if files.isEmpty == false {
            tableView.selectRowIndexes(IndexSet([0]), byExtendingSelection: false)
        }
        
        if isExecutingSQL == true {
            loadButton.title = NSLocalizedString("execute-button-title", comment: "Title for button to execute SQL snippet")
        }
    }
    
    func configureForLoading(files: [URL], handler: @escaping(URL) -> Void) {
        self.isLoading = true
        self.files = files
        loadingHandler = handler
    }
    
    func configureForExecutingSQL(files: [URL], handler: @escaping(URL) -> Void) {
        self.isExecutingSQL = true
        self.files = files
        loadingHandler = handler
    }
    
    func configureForDeleting(files: [URL]) {
        self.files = files
        self.isLoading = false
    }
    
    func configureForDisplaying(files: [URL]) {
        self.files = files
        self.isLoading = false
    }
    
    @objc private func handleTableDoubleClick() {
        if isLoading == true {
            loadItem(self)
        } else if isExecutingSQL == true {
            loadItem(self)
        }
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
                NSAlert.presentAlert(title: title, message: message)        
            }
        }
    }
    
    @IBAction func loadItem(_ sender: Any) {
        let row = tableView.selectedRow
        if row < 0 || row >= files.count {
            NSSound.beep()
            return
        }
        
        let url = files[row]
        if FileManager.default.fileExists(atPath: url.path) {
            if let handler = loadingHandler {
                handler(url)
                dismiss(self)
            }
        }
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
        let fileName = file.path.replacingOccurrences(of: ".\(savedQueryFileExtension)", with: "").replacingOccurrences(of: ".\(savedSnippetFileExtension)", with: "").replacingOccurrences(of: "\(FileManager.simpleAnalyticsSupportFolder.path)/", with: "")
        let label = NSTextField(labelWithString: fileName)
        return label
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if isLoading == true || isExecutingSQL == true {
            loadButton.isEnabled = tableView.selectedRow >= 0
        } else {
            deleteButton.isEnabled = tableView.selectedRow >= 0
        }
    }

}
