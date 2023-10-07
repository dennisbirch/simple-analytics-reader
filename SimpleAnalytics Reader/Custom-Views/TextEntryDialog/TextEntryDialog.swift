//
//  TextEntryDialog.swift
//
//

import Cocoa

class TextEntryDialog: NSWindow {
    private var handler: (String) -> Void = {(String) in }

    private var textField: NSTextField
    private var promptLabel: NSTextField
    private var okButton: NSButton
    
    override var canBecomeKey: Bool {
        return true
    }
    
    init(prompt: String, filter: String?, handler: @escaping (String) -> Void) {
        textField = NSTextField()
        promptLabel = NSTextField(labelWithString: "")
        okButton = NSButton()
        super.init(contentRect: CGRect.zero, styleMask: .docModalWindow, backing: .buffered, defer: true)
        setupUI()
        textField.delegate = self
        promptLabel.stringValue = prompt
        self.handler = handler
        if let filter = filter, filter.isEmpty == false {
            let formatter = CustomTextFormatter(filter: filter)
            textField.formatter = formatter
        }
    }
    
    private func setupUI() {
        guard let view = self.contentView else { return }
        view.addSubview(promptLabel)
        view.addSubview(textField)
        view.addSubview(okButton)
        okButton.keyEquivalent = "\r"
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        okButton.translatesAutoresizingMaskIntoConstraints = false
        
        promptLabel.stringValue = "Prompt goes here"
        okButton.title = "OK"
        okButton.action = #selector(acceptText)
        okButton.isEnabled = false
        
        let cancelButton = NSButton()
        view.addSubview(cancelButton)
        cancelButton.title = "Cancel"
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.action = #selector(dismiss)
        
        let dialogWidth: CGFloat = 320
        let dialogHeight: CGFloat = 150
        let buttonWidth: CGFloat = 80
        
        NSLayoutConstraint.activate([
            promptLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: view.leadingAnchor, multiplier: 1),
            promptLabel.topAnchor.constraint(equalToSystemSpacingBelow: view.topAnchor, multiplier: 1),
            promptLabel.trailingAnchor.constraint(equalToSystemSpacingAfter: view.trailingAnchor, multiplier: -1),
            promptLabel.widthAnchor.constraint(equalToConstant: dialogWidth),
            textField.leadingAnchor.constraint(equalTo: promptLabel.leadingAnchor),
            textField.topAnchor.constraint(equalToSystemSpacingBelow: promptLabel.bottomAnchor, multiplier: 1),
            textField.trailingAnchor.constraint(equalTo: promptLabel.trailingAnchor),
            okButton.trailingAnchor.constraint(equalTo: promptLabel.trailingAnchor),
            okButton.bottomAnchor.constraint(equalToSystemSpacingBelow: view.bottomAnchor, multiplier: -1),
            okButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            cancelButton.trailingAnchor.constraint(equalToSystemSpacingAfter: okButton.leadingAnchor, multiplier: -1),
            cancelButton.widthAnchor.constraint(equalTo: okButton.widthAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
            view.heightAnchor.constraint(equalToConstant: dialogHeight)
        ])
    }
    
    @objc func acceptText() {
        let text = textField.stringValue
        handler(text)        
        dismissAlert()
    }
    
    @objc func dismiss() {
        dismissAlert()
    }
    
    private func dismissAlert() {
        orderOut(self)
    }
}


extension TextEntryDialog: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            okButton.isEnabled = (field.stringValue.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty == false)
        }
        
    }
}

// MARK: -

class CustomTextFormatter: Formatter {
    private var filterString: String = ""
    
    init(filter: String) {
        self.filterString = filter
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Init with coder is not supported")
    }
    
    override func string(for obj: Any?) -> String? {
        return obj as? String ?? ""
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        // filter out any unwanted characters before setting object
        var newString = string
        for char in filterString {
            if newString.contains(char) {
                newString = newString.replacingOccurrences(of: String(char), with: "")
            }
        }
        obj?.pointee = newString as NSString
        return true
    }
}
