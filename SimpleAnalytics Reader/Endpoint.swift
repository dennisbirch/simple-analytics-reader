//
//  Endpoint.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 5/17/21.
//

import Foundation

struct Endpoint {
    static var shared: Endpoint = Endpoint()
    private static let addEndpointErrorMsg = "You need to add an \"Endpoint.txt\" file to your project and set its contents to the URL string for your endpoint. See the README file for more details."

    var urlString: String = {
        guard let endPointFile = Bundle.main.url(forResource: "Endpoint", withExtension: "txt") else {
            fatalError(addEndpointErrorMsg)
        }
        do {
            let endPointString = try String(contentsOf: endPointFile).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return endPointString
        } catch {
            fatalError(addEndpointErrorMsg)
        }
    }()

}
