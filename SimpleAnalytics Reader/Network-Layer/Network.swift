//
//  Network.swift
//  SimpleAnalytics Reader
//
//  Created by Dennis Birch on 3/23/21.
//

import Foundation
import os.log

enum QueryMode {
    case array
    case dictionary
    case items
    
    var modeString: String {
        switch self {
        case .array:
            return "array"
        case .dictionary, .items:
            return "dictionary"
        }
    }
}

struct QuerySubmitter {
    let query: String
    let mode: QueryMode
    let completion: (Any) -> Void
    private let queryModeKey = "queryMode"
    private let queryKey = "query"
    
    func submit() {
        let endpointString = Endpoint.shared.urlString
        guard endpointString.isEmpty == false else {
            fatalError("The endpoint string is empty. Please make sure your \"Endpoint.txt\" file contains a URL string for your web app.")
        }
        guard let url = URL(string: endpointString) else {
            os_log("URL is nil")
            DispatchQueue.main.async {
                self.completion([[]])
            }
            return
        }
  
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        let safeQuery = query.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? query
        let bodyString = ("\(queryKey)=\(safeQuery)&\(queryModeKey)=\(mode.modeString)")
        os_log("Query string: %@", bodyString)
        
        let body = bodyString.data(using: .utf8)
        urlRequest.httpBody = body
                
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
 
        let task = URLSession(configuration: config).dataTask(with: urlRequest) { (data, response, error) in
            if let taskError = error {
                os_log("Error posting analytics request: %@", taskError.localizedDescription)
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    let code = httpResponse.statusCode
                    if (200...299).contains(code) == false {
                        // response code not in accepted range
                        os_log("Bad response code: %d", code)
                        if let data = data {
                            os_log("%@", String(describing: String(data: data, encoding: .utf8)))
                        }
                        DispatchQueue.main.async {
                            self.completion([])
                            return
                        }
                    }
                }
                
                if let data = data {
                    var message: Any = []
                    if data.count == 0 {
                        DispatchQueue.main.async {
                            self.completion(message)
                            return
                        }
                    } else {
                        if mode == .array {
                            message = handleArrayResult(data)
                        } else if mode == .dictionary {
                            message = handleDictionaryResult(data)
                        } else if mode == .items {
                            message = handleItemsResult(data)
                        }
                        DispatchQueue.main.async {
                            self.completion(message)
                        }
                    }
                } else {
                    os_log("Error: data is nil")
                    DispatchQueue.main.async {
                        self.completion([])
                    }
                }
            }
        }

        task.resume()
    }
    
    private func handleArrayResult(_ result: Data) -> [[String]] {
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode([[String]].self, from: result)
            return decoded
        } catch {
            printDebugDecodingError(error, rawData: result)
        }
        
        return []
    }
    
    private func handleDictionaryResult(_ result: Data) -> [[String : String?]] {
        let decoder = JSONDecoder()
        do {
            var decoded = try decoder.decode([[String : String?]].self, from: result)
            // TODO: Remove this hack to sanitize incoming data
            // Note: Included because early versions of SimpleAnalytics could have populated
            // the database with nil values for some columns.
            #if DEBUG
            for idx in 0..<decoded.count {
                var item = decoded[idx]
                for key in item.keys {
                    if item[key]! == nil {
                        item[key] = "N/A"
                    }
                }
                decoded[idx] = item
            }
            #endif
            return decoded
        } catch {
            printDebugDecodingError(error, rawData: result)
        }
        
        return []
    }
    
    private func handleItemsResult(_ result: Data) -> [AnalyticsItem] {
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode([AnalyticsItem].self, from: result)
            return decoded
        } catch {
            printDebugDecodingError(error, rawData: result)
        }
        
        return []
    }

    private func printDebugDecodingError(_ error: Error, rawData: Data) {
        #if DEBUG
        // printing the error description
//        print("Error decoding result: \(error)")
        os_log("Error decoding result: %@", String(describing: error))
        os_log("Raw data:\n%@", String(data: rawData, encoding: .utf8) ?? "Nil")
        #endif
    }

}
