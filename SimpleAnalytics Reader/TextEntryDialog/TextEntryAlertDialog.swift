//
//  TextEntryAlertViewController.swift
//
//  Created by Dennis Birch on 5/5/21.
//

import Cocoa
import os.log

protocol TextEntryAlertViewControllerDelegate {
    func alertWasDismissed(text: String)
}

class TextEntryAlertWindowController : NSWindowController, NSTextFieldDelegate {
    @IBOutlet private weak var textField: NSTextField!
    @IBOutlet private weak var promptLabel: NSTextField!
    @IBOutlet private weak var okButton: NSButton!
    
    private var prompt: String = ""
    private var filterCharacters: String? = nil
    private var hostWindow: NSWindow?
    private var handler: (String) -> Void = { _ in }

    convenience init(prompt: String, handler: @escaping (String) -> Void, filterCharacters: String? = nil) {
        self.init(windowNibName: NSNib.Name("TextEntryDialog"))
        self.prompt = prompt
        self.handler = handler
        self.filterCharacters = filterCharacters
    }
        
    override func windowDidLoad() {
        super.windowDidLoad()
        textField.delegate = self
        self.promptLabel.stringValue = prompt
        window?.makeFirstResponder(textField)
        
        if let filter = filterCharacters, filter.isEmpty == false {
            let formatter = CustomTextFormatter(filter: filterCharacters ?? "")
            textField.formatter = formatter
        }
    }

    func runSheetOnWindow(_ w: NSWindow) {
        hostWindow = w
        hostWindow?.beginSheet(window!)
    }

    @IBAction func acceptText(_ sender: Any) {
        alertWasDismissed(text: textField.stringValue, code: .OK)
    }

    @IBAction func close(_ sender: Any) {
        alertWasDismissed(text: "", code: .cancel)
    }

    func alertWasDismissed(text: String, code: NSApplication.ModalResponse) {
        hostWindow!.endSheet(window!, returnCode: code)
        handler(text)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let text = obj.object as? NSTextField, text == self.textField else {
            os_log("Not the dialog's text field")
            return
        }
        
        okButton.isEnabled = text.stringValue.isEmpty == false
    }
    
}

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
