//
//  DetailView.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/8/21.
//

import Cocoa

class DetailView: NSView {
    @IBOutlet private weak var textView: NSTextView!
    private var detailText: String = ""
    private var styledText: NSAttributedString {
        let attributes = [NSAttributedString.Key.font : NSFont.systemFont(ofSize: 12)]
        let styledText = NSAttributedString(string: detailText,
                                            attributes: attributes)
        return styledText
    }
    private let bgColor = NSColor.purple.withAlphaComponent(0.2)
        
    static func create(with text: String, width: CGFloat) -> DetailView? {
        guard let newNib = NSNib(nibNamed: "DetailView", bundle: nil) else {
            return nil
        }
        var newViewPointer: NSArray?
        newNib.instantiate(withOwner: self, topLevelObjects: &newViewPointer)
        guard let newView = newViewPointer?.first(where: { $0 is DetailView }) as? DetailView else {
            return nil
        }
        newView.detailText = text
        newView.textView.string = text
        newView.wantsLayer = true
        
        let rect = newView.calculateFrame(width: width, text: text)
        newView.frame = rect
        newView.textView.backgroundColor = newView.bgColor
        
        return newView
    }
    
    private func calculateFrame(width: CGFloat, text: String) -> CGRect {
        let maxSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        var rect = styledText.boundingRect(with: maxSize, options: .usesLineFragmentOrigin)
        // add some bottom padding
        rect.size.height += 6
        // ensure width is at least 80
        rect.size.width = max(width, 80)
        return rect
    }
    
    override func draw(_ dirtyRect: NSRect) {
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.secondaryLabelColor.cgColor
        // make it opaque
        layer?.backgroundColor = NSColor.white.cgColor
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        textView?.string = ""
    }
}
