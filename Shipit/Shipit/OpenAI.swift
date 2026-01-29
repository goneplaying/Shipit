//
//  OpenAI.swift
//  Shipit
//
//  Created by Christopher Wirkus on 07.01.2026.
//

import SwiftUI
import OpenAISwift
import Network

final class OpenAI: ObservableObject {
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init () {
        
    }
    
    private var client: OpenAISwift?
    
    func setup() {
        let apiConfig = OpenAISwift.Config.makeDefaultOpenAI(apiKey: OpenAIConfig.apiKey)
        client = OpenAISwift(config: apiConfig)
    }
    
    private func checkNetworkConnection(completion: @escaping (Bool, String?) -> Void) {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                completion(true, nil)
            } else {
                completion(false, "No internet connection available. Please check your network settings.")
            }
        }
        monitor.start(queue: queue)
        
        // Check immediately
        let currentPath = monitor.currentPath
        if currentPath.status == .satisfied {
            completion(true, nil)
        } else {
            completion(false, "No internet connection available. Please check your network settings.")
        }
    }
    
    func send(text: String, completion: @escaping (String) -> Void) {
        guard client != nil else {
            DispatchQueue.main.async {
                completion("Error: OpenAI client not initialized. Please ensure setup() is called.")
            }
            return
        }
        
        // Check network connection first
        checkNetworkConnection { isConnected, errorMessage in
            guard isConnected else {
                DispatchQueue.main.async {
                    completion("Network Error: \(errorMessage ?? "Unable to connect to the internet. Please check your network connection and try again.")")
                }
                return
            }
            
            print("Sending request to OpenAI with text length: \(text.count)")
            
            // Use direct HTTP API call for more reliable response handling
            self.sendDirectAPIRequest(text: text) { responseText in
                DispatchQueue.main.async {
                    completion(responseText)
                }
            }
        }
    }
    
    // Direct API call to OpenAI for better control
    private func sendDirectAPIRequest(text: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/completions") else {
            completion("Error: Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo-instruct",
            "prompt": text,
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion("Error: Failed to encode request body")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion("Network Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                completion("Error: No data received from API")
                return
            }
            
            // Parse JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("API Response JSON: \(json)")
                    
                    // Extract text from response
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let text = firstChoice["text"] as? String {
                        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("Successfully extracted text: \(trimmedText.prefix(100))...")
                        completion(trimmedText)
                    } else if let error = json["error"] as? [String: Any],
                              let errorMessage = error["message"] as? String {
                        completion("API Error: \(errorMessage)")
                    } else {
                        completion("Error: Unexpected response format. Check console for details.")
                    }
                } else {
                    completion("Error: Invalid JSON response")
                }
            } catch {
                print("JSON parsing error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                completion("Error: Failed to parse response - \(error.localizedDescription)")
            }
        }.resume()
    }
}
