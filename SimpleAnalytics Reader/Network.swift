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
        guard let url = URL(string: Endpoint.shared.urlString) else {
            os_log("URL is nil")
            DispatchQueue.main.async {
                self.completion([[]])
            }
            return
        }
  
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        let bodyString = ("\(queryKey)=\(query)&\(queryModeKey)=\(mode.modeString)")
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
                    }
                    
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
            printDebugDecodingError(error)
            os_log("Raw data:\n%@", String(data: result, encoding: .utf8) ?? "Nil")
        }
        
        return []
    }
    
    private func handleDictionaryResult(_ result: Data) -> [[String : String?]] {
        let decoder = JSONDecoder()
        do {
            var decoded = try decoder.decode([[String : String?]].self, from: result)
            // TODO: Remove this hack to sanitize incoming data
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
            printDebugDecodingError(error)
            os_log("Raw data:\n%@", String(data: result, encoding: .utf8) ?? "Nil")
        }
        
        return []
    }
    
    private func handleItemsResult(_ result: Data) -> [AnalyticsItem] {
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode([AnalyticsItem].self, from: result)
            return decoded
        } catch {
            printDebugDecodingError(error)
            os_log("Raw data:\n%@", String(data: result, encoding: .utf8) ?? "Nil")
        }
        
        return []
    }

    private func printDebugDecodingError(_ error: Error) {
        #if DEBUG
        print("Error decoding result: \(error)")
        #endif
    }

}
