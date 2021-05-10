//
//  ViewController.swift
//  Analytics Query
//
//  Created by Dennis Birch on 3/23/21.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet private weak var queryText: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func run(_ sender: Any) {
        let query = queryText.stringValue
        if query.isEmpty == true {
            return
        }
        
        let submitter = QuerySubmitter(query: query, mode: .array) { _ in }        
        submitter.submit()
    }

}

