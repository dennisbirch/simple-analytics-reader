//
//  QueryTypeQueryComparison.swift
//  Analytics Query
//
//  Created by Dennis Birch on 4/16/21.
//

import Foundation

enum QueryType: String, CaseIterable {
    case title
    case datetime
    case deviceID
    case platform
    case appName
    case appVersion
    case systemVersion
    
    
    static func fromString(_ baseString: String) -> QueryType {
        let allCases = QueryType.allCases
        let match = allCases.first(where: { $0.rawValue.lowercased() == baseString.reducedEnumElement() })
        return match ?? QueryType.title
    }
    
    var dbColumnName: String {
        switch self {
        case .title:
            return "description"
        case .datetime:
            return "timestamp"
        case .deviceID:
            return "device_id"
        case .platform:
            return "platform"
        case .appName:
            return "app_name"
        case .appVersion:
            return "app_version"
        case .systemVersion:
            return "system_version"
        }
    }
}

enum DateComparison: String, Comparison, CaseIterable {
    case beforeOrEquals
    case before
    case equals
    case after
    case afterOrEquals
    
    func toString() -> String {
        self.rawValue
    }

    static func fromString(_ baseString: String) -> Comparison {
        let allCases = DateComparison.allCases
        let match = allCases.first(where: { $0.rawValue.lowercased() == baseString.reducedEnumElement() })
        return match ?? DateComparison.equals
    }
}

enum NumericComparison: String, Comparison, CaseIterable {
    case lessThanOrEquals
    case lessThan
    case equals
    case greaterThan
    case greaterThanOrEquals
    
    func toString() -> String {
        self.rawValue
    }

    static func fromString(_ baseString: String) -> Comparison {
        let allCases = NumericComparison.allCases
        let match = allCases.first(where: { $0.rawValue.lowercased() == baseString.reducedEnumElement() })
        return match ?? NumericComparison.equals
    }
}

enum StringComparison: String, Comparison, CaseIterable {
    case equals
    case contains
    case beginsWith
    case endsWith
    
    func toString() -> String {
        self.rawValue
    }
    
    static func fromString(_ baseString: String) -> Comparison {
        let allCases = StringComparison.allCases
        let match = allCases.first(where: { $0.rawValue.lowercased() == baseString.reducedEnumElement() })
        return match ?? StringComparison.equals
    }
}

protocol Comparison {
    func toString() -> String
    static func fromString(_ baseString: String) -> Comparison
}

