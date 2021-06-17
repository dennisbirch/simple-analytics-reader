//
//  Extensions.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/2/21.
//

import Cocoa

extension NSAlert {
    static func okAlertWithTitle(_ title: String, message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        return alert

    }
}


extension FileManager {
    static var simpleAnalyticsSupportFolder: URL {
        do {
            let fileMgr = FileManager.default
            let appSupportFolder = try fileMgr.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let queryFolder = appSupportFolder.appendingPathComponent("SimpleAnalytics Reader", isDirectory: true)
            if fileMgr.fileExists(atPath: queryFolder.path) == false {
                do {
                    try fileMgr.createDirectory(at: queryFolder, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    fatalError("Error creating queries folder: \(error)")
                }
            }

            return queryFolder
        } catch {
            fatalError("Can't access the Application Support folder: \(error)")
        }
    }
}

extension NSWindow {
    func stripTitleChrome() {
        self.titleVisibility = .hidden
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

extension DateFormatter {
    static var shortDateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }
    
    static var databaseTimestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }
}

extension Date {
    func shortDateString() -> String {
        return DateFormatter.shortDateTimeFormatter.string(from: self)
    }
    
    func databaseFormatString() -> String {
        return DateFormatter.databaseTimestampFormatter.string(from: self)
    }
}

extension Array where Element : Hashable {
    func uniqueValues(_ otherArray: Array) -> Array {
        let theSet = Set(self)
        let newSet = theSet.union(otherArray)
        let newArray = Array(newSet)
        return newArray
    }
}

extension String {
    func dateFromISOString() -> Date? {
        let formatter = DateFormatter.databaseTimestampFormatter
        return formatter.date(from: self)
    }

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
