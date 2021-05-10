//
//  Extensions.swift
//  Analytics Query
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
    static var queryFileFolder: URL {
        do {
            let fileMgr = FileManager.default
            let appSupportFolder = try fileMgr.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let queryFolder = appSupportFolder.appendingPathComponent("Analytics Query", isDirectory: true)
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
