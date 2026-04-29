import Foundation

/// Protocol pentru a permite injectarea URLSession în teste.
protocol URLSessionProtocol {
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
}

extension URLSession: URLSessionProtocol {}

/// Serviciu pentru trimiterea datelor de telemetrie către backend.
/// Task #34 - Send telemetry ping to backend
class TelemetryService {
    static let shared = TelemetryService()
    
    private let session: URLSessionProtocol
    
    private var endpointURL: URL? {
        let key = "TelemetryEndpoint"
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        
        if let urlString = value, !urlString.isEmpty {
            return URL(string: urlString)
        }
        
        #if targetEnvironment(simulator)
        // Fallback la localhost doar pe simulator dacă lipsește cheia în plist
        return URL(string: "http://localhost:8080/api/telemetry/ping")
        #else
        return nil
        #endif
    }
    
    private var batchEndpointURL: URL? {
        let key = "TelemetryBatchEndpoint"
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        
        if let urlString = value, !urlString.isEmpty {
            return URL(string: urlString)
        }
        
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:8080/api/v1/telemetry/batch")
        #else
        // Fallback or use environment variables
        return URL(string: "https://your-production-url.com/api/v1/telemetry/batch")
        #endif
    }
    
    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }
    
    /// Construiește payload-ul JSON. Task #34 & CodeRabbit fix
    func makePayload(
        storeId: String,
        itemId: String,
        triggerType: String,
        latitude: Double?,
        longitude: Double?,
        accuracy: Double?
    ) -> [String: Any] {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        var payload: [String: Any] = [
            "storeId": storeId,
            "itemId": itemId,
            "triggerType": triggerType,
            "timestamp": timestamp
        ]
        
        payload["accuracy"] = accuracy ?? NSNull()
        
        if let lat = latitude, let lng = longitude {
            payload["lat"] = lat
            payload["lng"] = lng
        } else {
            payload["lat"] = NSNull()
            payload["lng"] = NSNull()
        }
        
        return payload
    }
    
    /// Trimite un ping de telemetrie către server.
    func sendLocationPing(
        storeId: String,
        itemId: String,
        triggerType: String,
        latitude: Double?,
        longitude: Double?,
        accuracy: Double?
    ) {
        guard let url = endpointURL else {
            print("TelemetryService: Error - Invalid or missing endpoint URL")
            return
        }

        let payload = makePayload(
            storeId: storeId, 
            itemId: itemId, 
            triggerType: triggerType, 
            latitude: latitude, 
            longitude: longitude, 
            accuracy: accuracy
        )
        
        print("TelemetryService: Sending ping to backend... [storeId: \(storeId), triggerType: \(triggerType)]")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("TelemetryService: Error serializing JSON: \(error)")
            return
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("TelemetryService: Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 202 {
                    print("TelemetryService: Success! Server returned 202 Accepted")
                } else {
                    print("TelemetryService: Server returned status code \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    /// Sends a batch of pings to the server. Matches Android's ApiService.sendBatchPings.
    func sendBatch(_ batch: TelemetryBatch) async -> Bool {
        guard let url = batchEndpointURL else {
            print("TelemetryService: Error - Invalid or missing batch endpoint URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(batch)
        } catch {
            print("TelemetryService: Error serializing batch JSON: \(error)")
            return false
        }
        
        return await withCheckedContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("TelemetryService: Batch network error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    // Same strict deletion policy as Android: Only 2xx means success
                    let isSuccess = (200...299).contains(httpResponse.statusCode)
                    continuation.resume(returning: isSuccess)
                } else {
                    continuation.resume(returning: false)
                }
            }.resume()
        }
    }
}
