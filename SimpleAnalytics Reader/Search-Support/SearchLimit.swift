//
//  SearchLimit.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/11/21.
//

import Foundation
import os.log

struct SearchLimit {
    var itemsTotal: Int
    var countersTotal: Int
    var itemsFetched: Int = 0
    var countersFetched: Int = 0
    var lastItemsID: Int
    var lastCountersID: Int
    var pageLimit: Int
    var currentFetchCount: Int = 0 {
        didSet {
            lastFetchCount = oldValue
        }
    }
    var lastFetchCount: Int = 0
    var totalCount: Int {
        return itemsTotal + countersTotal
    }
    
    init(pageLimit: Int) {
        itemsTotal = 0
        countersTotal = 0
        lastItemsID = 0
        lastCountersID = 0
        self.pageLimit = pageLimit
    }
        
    mutating func updateForNextLimitedSeek(itemsID: Int, countersID: Int, itemsCount: Int, countersCount: Int) {
        lastItemsID = itemsID
        lastCountersID = countersID
        itemsFetched += itemsCount
        countersFetched += countersCount
    }
    
    func limitForTable(_ table: TableType, whatItems: WhatItems, currentLimit: Int) -> Int {
        switch whatItems {
        case .both:
            let itemsAvailable = itemsTotal - itemsFetched
            let countersAvailable = countersTotal - countersFetched
            let totalAvailable = itemsAvailable + countersAvailable
            
            if totalAvailable <= 0 {
                return pageLimit
            }
            
            if table == .items {
                if itemsAvailable >= pageLimit {
                    return pageLimit
                } else {
                    return itemsAvailable
                }
            } else { // counters
                if countersAvailable >= pageLimit {
                    return pageLimit - currentLimit
                } else {
                    return countersAvailable
                }
            }
        case .items, .counters:
            return pageLimit
        }
    }
}

