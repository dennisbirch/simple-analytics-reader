//
//  SearchViewController.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/9/21.
//

import Cocoa

class SearchViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, QuerySearchDelegate {
    @IBOutlet private weak var resultsTableView: NSTableView!
    @IBOutlet private weak var queriesContainerView: NSView!
    
    private var items = [AnalyticsItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        queriesContainerView.wantsLayer = true
        queriesContainerView.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        
        guard let queriesVC = storyboard?.instantiateController(withIdentifier: SearchQueriesViewController.viewControllerIdentifier) as? SearchQueriesViewController else {
            return
        }
        let queriesView = queriesVC.view
        addChild(queriesVC)
        queriesContainerView.addSubview(queriesView)
        queriesVC.searchDelegate = self
        queriesView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([queriesView.leadingAnchor.constraint(equalTo: queriesContainerView.leadingAnchor),
                                     queriesView.trailingAnchor.constraint(equalTo: queriesContainerView.trailingAnchor),
                                     queriesView.topAnchor.constraint(equalTo: queriesContainerView.topAnchor),
                                     queriesView.bottomAnchor.constraint(equalTo: queriesContainerView.bottomAnchor)])
    }
    
    // MARK: - Results TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // TODO: Implement!!!
        return nil
    }
    

    // MARK: - QuerySearchDelegate
    
    func searchCompleted(results: [AnalyticsItem]) {
        items = results
        resultsTableView.reloadData()
    }
}
