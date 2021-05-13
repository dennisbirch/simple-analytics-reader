//
//  QueryItem.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 4/11/21.
//

import Foundation

struct QueryItem: Codable {
    let queryType: QueryType
    let comparison: Comparison?
    let value: String
    var id: UUID
        
    enum CodingKeys: String, CodingKey {
        case queryType
        case comparison
        case value
        case id
    }
    
    init() {
        queryType = .title
        comparison = StringComparison.equals
        value = ""
        id = UUID()
    }
    
    init(queryType: QueryType, dateComparison: DateComparison, value: Date) {
        self.queryType = queryType
        self.comparison = dateComparison
        self.value = ISO8601DateFormatter.queryFormatter.string(from: value)
        id = UUID()
    }
    
    init(queryType: QueryType, comparison: Comparison, value: String) {
        self.queryType = queryType
        self.comparison = comparison
        self.value = value
        id = UUID()
    }
        
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try values.decode(String.self, forKey: .queryType)
        if let qType = QueryType(rawValue: typeValue) {
            queryType = qType
        } else {
            queryType = QueryType.title
        }
        
        let query = self.queryType
        
        let comparisonString = try values.decode(String.self, forKey: .comparison)
        var comparison: Comparison?
        if query == .systemVersion || query == .appVersion {
            if let cType = NumericComparison(rawValue: comparisonString) {
                comparison = cType
            }
        } else {
            if let cType = StringComparison(rawValue: comparisonString) {
                comparison = cType
            } else if let cType = DateComparison(rawValue: comparisonString) {
                comparison = cType
            }
        }
        self.comparison = comparison
        
        value = try values.decode(String.self, forKey: .value)
        let identifier = try values.decode(String.self, forKey: .id)
        id = UUID(uuidString: identifier) ?? UUID()
    }
        
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(queryType.rawValue, forKey: .queryType)
        if let comp = comparison {
            try container.encode(comp.toString(), forKey: .comparison)
        }
        try container.encode(value, forKey: .value)
        try container.encode(id.uuidString, forKey: .id)
    }
}

extension QueryItem {
    func queryItemWithNewString(_ newString: String) -> QueryItem {
        let comparison = self.comparison as? StringComparison ?? StringComparison.equals
        var item = QueryItem(queryType: self.queryType, comparison: comparison, value: newString)
        item.id = self.id
        return item
    }
    
    func queryItemWithNewNumeric(_ numericString: String) -> QueryItem {
        let comparison = self.comparison as? NumericComparison ?? NumericComparison.equals
        var item = QueryItem(queryType: self.queryType, comparison: comparison, value: numericString)
        item.id = self.id
        return item
    }
    
    func queryItemWithNewDate(_ newDate: Date) -> QueryItem {
        let comparison = self.comparison as? DateComparison ?? DateComparison.same
        var item = QueryItem(queryType: .datetime, dateComparison: comparison, value: newDate)
        item.id = self.id
        return item
    }
}

extension QueryItem {
    func dateValue() -> Date? {
        return ISO8601DateFormatter.queryFormatter.date(from: self.value)
    }
    
    func sqlWhereString() -> String {
        var sql = ""
        switch queryType {
        case .title, .appName, .platform, .deviceID:
            switch comparison as! StringComparison {
            case StringComparison.beginsWith:
                let likeValue = "\(value)%".sqlify()
                sql = "\(queryType.dbColumnName) LIKE \(likeValue)"
            case StringComparison.equals:
                sql = "\(queryType.dbColumnName) = \(value.sqlify())"
            case .contains:
                let likeValue = "%\(value)%".sqlify()
                sql = "\(queryType.dbColumnName) LIKE \(likeValue)"
            case .endsWith:
                let likeValue = "%\(value)".sqlify()
                sql = "\(queryType.dbColumnName) LIKE \(likeValue)"
            }

        case .datetime:
            let likeValue = "\(value)%".sqlify()
            switch comparison as! DateComparison {
            case DateComparison.beforeOrEquals:
                sql = "(\(queryType.dbColumnName) < \(likeValue) OR \(queryType.dbColumnName) LIKE \(likeValue))"
            case DateComparison.before:
                sql = "\(queryType.dbColumnName) < \(likeValue)"
            case DateComparison.same:
                sql = "\(queryType.dbColumnName) LIKE \(likeValue)"
            case DateComparison.after:
                sql = "\(queryType.dbColumnName) > \(likeValue)"
            case DateComparison.afterOrEquals:
                sql = "(\(queryType.dbColumnName) LIKE \(likeValue) OR \(queryType.dbColumnName) > \(likeValue))"
            }

        case .systemVersion, .appVersion:
            switch comparison as! NumericComparison {
            case NumericComparison.lessThan:
                sql = "\(queryType.dbColumnName) < \(value.sqlify())"
            case NumericComparison.lessThanOrEquals:
                sql = "\(queryType.dbColumnName) <= \(value.sqlify())"
            case NumericComparison.equals:
                sql = "\(queryType.dbColumnName) = \(value.sqlify())"
            case NumericComparison.greaterThan:
                sql = "\(queryType.dbColumnName) > \(value.sqlify())%"
            case NumericComparison.greaterThanOrEquals:
                sql = "\(queryType.dbColumnName) >= \(value.sqlify())"
            }
        }
        
        return sql
    }
}


extension String {
    func reducedEnumElement() -> String {
        return self.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "/", with: "").lowercased()
    }
    
    func sqlify() -> String {
        let sqlified = self.replacingOccurrences(of: "'", with: "''")
        return "'\(sqlified)'"
    }
    
    func versionNumber() -> Double {
        let numberString = self.lowercased().trimmingCharacters(in: CharacterSet.lowercaseLetters).replacingOccurrences(of: ",", with: ".")
        guard let majorRange = numberString.range(of: ".") else {
            return Double(numberString) ?? 0
        }
        let replaceRange = numberString.startIndex..<majorRange.lowerBound
        let major = numberString[replaceRange] + "."
        let remainder = numberString.replacingCharacters(in: replaceRange, with: "").replacingOccurrences(of: ".", with: "")
        let composite = major + remainder
        return Double(composite) ?? 0
    }
}

extension ISO8601DateFormatter {
    static var queryFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone.current
        return formatter
    }
}
