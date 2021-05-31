//
//  SaveSQLViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/12/21.
//

import Cocoa

protocol SQLSnippetPersistenceDelegate {
    func saveSnippet(_ snippet: String, with fileName: String)
    func runSQLSnippet(_ snippet: String)
}

class ExecuteAndSaveSQLViewController: NSViewController, NSTextViewDelegate, NSTextFieldDelegate {
    static let viewControllerIdentifier = "ExecuteAndSaveSQLViewController"
    
    @IBOutlet private weak var namePromptLabel: NSTextField!
    @IBOutlet private weak var sqlPromptLabel: NSTextField!
    @IBOutlet private weak var nameInputField: NSTextField!
    @IBOutlet private weak var sqlTextView: NSTextView!
    @IBOutlet private weak var nameInputStackView: NSStackView!
    @IBOutlet private weak var sqlInputStackView: NSStackView!
    @IBOutlet private weak var mainStackView: NSStackView!
    @IBOutlet private weak var okButton: NSButton!
    @IBOutlet private weak var trySQLButton: NSButton!

    private var isSaving = false
    private var sql = ""
    
    var delegate: SQLSnippetPersistenceDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sqlTextView.isFieldEditor = true
        sqlTextView.delegate = self
        nameInputField.delegate = self
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()

        if isSaving == true {
            namePromptLabel.stringValue = "Name for snippet"
            sqlPromptLabel.stringValue = "Enter SQL statements to save"
            okButton.title = NSLocalizedString("save-button-title", comment: "Title for button to save snippet")
        } else {
            mainStackView.removeArrangedSubview(nameInputStackView)
            nameInputStackView.removeFromSuperview()
            sqlPromptLabel.stringValue = "Enter SQL statements to execute"
            okButton.title = NSLocalizedString("execute-button-title", comment: "Title for button to test snippet execution")
        }

        sqlTextView.string = sql
        trySQLButton.isHidden = (isSaving == false)
        enableButtons()
    }
    
    func configureForSaving(sql: String = "") {
        isSaving = true
        self.sql = sql
    }
    
    func configureForExecuting(sql: String) {
        isSaving = false
        self.sql = sql
    }
    
    @IBAction func performAction(_ sender: Any) {
        let snippet = sqlTextView.string
        if isSaving == true {
            let name = nameInputField.stringValue
            delegate?.saveSnippet(snippet, with: name)
        } else { // execute
            delegate?.runSQLSnippet(snippet)
        }
        
        if let _ = presentingViewController {
            dismiss(self)
        } else {
            closeWindow(self)
        }
    }
    
    @IBAction func testSQL(_ sender: Any) {
        let sql = sqlTextView.string
        delegate?.runSQLSnippet(sql)
    }
    
    @IBAction func closeWindow(_ sender: Any) {
        view.window?.close()
    }
    
    func textDidChange(_ notification: Notification) {
        enableButtons()
    }
    
    func controlTextDidChange(_ obj: Notification) {
        enableButtons()
    }
    
    private func enableButtons() {
        var enableOK = sqlTextView.string.isEmpty == false
        trySQLButton.isEnabled = enableOK
        
        if isSaving == true {
            enableOK = enableOK && nameInputField.stringValue.isEmpty == false
        }
        
        okButton.isEnabled = enableOK
    }
}
