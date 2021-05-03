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
