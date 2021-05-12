//
//  DBAccess.swift
//  Analytics Query
//
//  Created by Dennis Birch on 3/25/21.
//

import Foundation

struct Items {
    static let table = "items"
    static let description = "description"
    static let details = "details"
    static let timestamp = "timestamp"
}

struct Counters {
    static let table = "counters"
    static let description = "description"
    static let count = "count"
}

struct Common {
    static let appName = "app_name"
    static let deviceID = "device_id"
    static let platform = "platform"
}

struct DBAccess {
    static var selectAll = "*"
    
    static func query(what: String,
                      from: String,
                      whereClause: String = "",
                      isDistinct: Bool = false,
                      sorting: String = "") -> String {
        var sql = "SELECT "
        if isDistinct == true {
            sql.append("DISTINCT (\(what)) ")
        } else {
            sql.append("\(what) ")
        }
        
        if from.isEmpty == false {
            sql.append("FROM \(from) ")
        }
        
        if whereClause.isEmpty == false {
            let fromWhere = "WHERE (\(whereClause)) "
            sql.append(fromWhere)
        }
        
        if sorting.isEmpty == false {
            sql.append("ORDER BY \(sorting)")
        }
        
        return sql
    }
    
    static func limitQuery(what: String,
                           from: String,
                           whereClause: String = "",
                           lastID: Int,
                           limit: Int,
                           sorting: String = "") -> String {
        var sql = "SELECT \(what) FROM \(from) WHERE (id > \(lastID)"
        
        if whereClause.isEmpty == false {
            let fromWhere = " AND \(whereClause)) "
            sql.append(fromWhere)
        } else {
            sql.append(") ")
        }
        
        if sorting.isEmpty == false {
            sql.append("ORDER BY \(sorting) ")
        }
        
        sql.append("LIMIT \(limit) ")
        
        return sql
    }
}
