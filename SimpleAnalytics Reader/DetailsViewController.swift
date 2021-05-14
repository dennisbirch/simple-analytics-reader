//
//  DetailsViewController.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/13/21.
//

import Cocoa

class DetailsViewController: NSViewController {
    static let viewControllerIdentifier = "DetailsViewController"
    
    @IBOutlet private weak var detailsTable: NSTableView!
    private var details = [[String : String]]()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
