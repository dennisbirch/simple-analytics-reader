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

enum NetworkError: Error {
    case badURL
    case badResponseCode(code: Int)
    case nilResponse
    case jsonDecodingError(rawData: String)
    
    var message: String {
        switch self {
            case .badURL:
                return "Bad URL"
            case .badResponseCode(let code):
                return "The server returned a bad response code: \(code)"
            case .nilResponse:
                return "No data was returned from the server"
            case .jsonDecodingError(let rawData):
                return "There was an error decoding the JSON response: \(rawData)"
        }
    }
}

struct QuerySubmitter {
    let query: String
    let mode: QueryMode
    let completion: (Result<Any, NetworkError>) -> Void
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
                self.completion(.failure(.badURL))
            }
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        let safeQuery = query.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? query
        let bodyString = ("\(queryKey)=\(safeQuery)&\(queryModeKey)=\(mode.modeString)")
#if DEBUG
        if let logString = bodyString.removingPercentEncoding {
            os_log("Query string: %{public}@", logString)
        }
#endif
        
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
                            self.completion(.failure(.badResponseCode(code: code)))
                            return
                        }
                    }
                }
                
                if let data = data {
                    var message: Any = []
                    if data.count == 0 {
                        DispatchQueue.main.async {
                            self.completion(.success([]))
                            return
                        }
                    } else {
                        if mode == .array {
                            let response = handleArrayResult(data)
                            switch response {
                                case .success(let values):
                                    return completion(.success(values))
                                case .failure(let error):
                                    return completion(.failure(error))
                            }
                        } else if mode == .dictionary {
                            let response = handleDictionaryResult(data)
                            switch response {
                                case .success(let values):
                                    return completion(.success(values))
                                case .failure(let error):
                                    return completion(.failure(error))
                            }
                        } else if mode == .items {
                            let response = handleItemsResult(data)
                            switch response {
                                case .success(let values):
                                    return completion(.success(values))
                                case .failure(let error):
                                    return completion(.failure(error))
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.completion(.success(message))
                    }
                } else {
                    os_log("Error: data is nil")
                    DispatchQueue.main.async {
                        self.completion(.failure(.nilResponse))
                    }
                }
            }
        }
        
        task.resume()
    }
    
    private func handleArrayResult(_ result: Data) -> Result<[[String]], NetworkError> {
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode([[String]].self, from: result)
            return .success(decoded)
        } catch {
            printDebugDecodingError(error, rawData: result)
            return .failure(NetworkError.jsonDecodingError(rawData: String(data: result, encoding: .utf8) ?? "Nil"))
        }
    }
    
    private func handleDictionaryResult(_ result: Data) -> Result<[[String : String?]], NetworkError> {
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
            return .success(decoded)
        } catch {
            printDebugDecodingError(error, rawData: result)
            return .failure(NetworkError.jsonDecodingError(rawData: String(data: result, encoding: .utf8) ?? "Nil"))
        }
    }
    
    private func handleItemsResult(_ result: Data) -> Result<[AnalyticsItem], NetworkError> {
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode([AnalyticsItem].self, from: result)
            return .success(decoded)
        } catch {
            printDebugDecodingError(error, rawData: result)
            return .failure(NetworkError.jsonDecodingError(rawData: String(data: result, encoding: .utf8) ?? "Nil"))
        }
    }

    private func printDebugDecodingError(_ error: Error, rawData: Data) {
        #if DEBUG
        // printing the error description
        os_log("Error decoding result: %{public}@", String(describing: error))
        os_log("Raw data:\n%{public}@", String(data: rawData, encoding: .utf8) ?? "Nil")
        #endif
    }

}
