//
//  AnalyticsCount.swift
//  
//
//  Created by Dennis Birch on 3/22/21.
//

import Foundation

enum CodingKeys: String, CodingKey {
    case description
    case count
    case deviceID = "device_id"
    case appName = "app_name"
    case appVersion = "app_version"
    case systemVersion = "system_version"
    case platform
}

struct AnalyticsCount: Decodable, Hashable {
    let description: String
    let count: Int
    let deviceID: String
    let appName: String
    let appVersion: String
    let systemVersion: String
    let platform: String
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        description = try values.decode(String.self, forKey: .description)
        count = try values.decode(Int.self, forKey: .count)
        deviceID = try values.decodeIfPresent(String.self, forKey: .deviceID) ?? "N/A"
        appName = try values.decode(String.self, forKey: .appName)
        appVersion = try values.decodeIfPresent(String.self, forKey: .appVersion) ?? "N/A"
        systemVersion = try values.decodeIfPresent(String.self, forKey: .systemVersion) ?? "N/A"
        platform = try values.decodeIfPresent(String.self, forKey: .platform) ?? "N/A"
    }

}
