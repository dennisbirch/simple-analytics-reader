//
//  AnalyticsItem.swift
//  App Analytics
//
//  Created by Dennis Birch on 3/20/21.
//

import Foundation

struct AnalyticsItem: Hashable, Decodable {
    public static func == (lhs: AnalyticsItem, rhs: AnalyticsItem) -> Bool {
        return lhs.description == rhs.description &&
            lhs.timestamp == rhs.timestamp
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(description.hashValue & timestamp.hashValue)
    }
    
    let timestamp: String
    let description: String
    let details: String
    let count: String
    let deviceID: String
    let appName: String
    let appVersion: String
    let systemVersion: String
    let platform: String
    let id: Int
    let table: TableType
    
    enum CodingKeys: String, CodingKey {
        case description
        case count
        case timestamp
        case details
        case deviceID = "device_id"
        case appName = "app_name"
        case appVersion = "app_version"
        case systemVersion = "system_version"
        case platform
        case id
    }
        
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        description = try values.decodeIfPresent(String.self, forKey: .description) ?? "N/A"
        count = try values.decodeIfPresent(String.self, forKey: .count) ?? "N/A"
        let dateString = try values.decodeIfPresent(String.self, forKey: .timestamp)
        if let time = dateString {
            timestamp = time.dateFromISOString()?.shortDateString() ?? "N/A"
        } else {
            timestamp = "N/A"
        }
        details = try values.decodeIfPresent(String.self, forKey: .details) ?? ""
        deviceID = try values.decodeIfPresent(String.self, forKey: .deviceID) ?? "N/A"
        appName = try values.decodeIfPresent(String.self, forKey: .appName) ?? "N/A"
        appVersion = try values.decodeIfPresent(String.self, forKey: .appVersion) ?? "N/A"
        systemVersion = try values.decodeIfPresent(String.self, forKey: .systemVersion) ?? "N/A"
        platform = try values.decodeIfPresent(String.self, forKey: .platform) ?? "N/A"
        let idString = try values.decode(String.self, forKey: .id)
        id = Int(idString) ?? 0
     
        if values.contains(.details) {
            table = .items
        } else {
            table = .counters
        }
    }
}

extension DateFormatter {
    static var shortFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone.current
        return dateFormatter
    }
}

extension Date {
    func shortDateString() -> String {
        return DateFormatter.shortFormatter.string(from: self)
    }
}