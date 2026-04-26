import Foundation
import UIKit
import CoreLocation

/// Protocol pentru a permite injectarea URLSession în teste.
protocol URLSessionProtocol {
    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
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
        return URL(string: "http://localhost:8080/api/v1/telemetry/ping")
        #else
        return nil
        #endif
    }
    
    private var batchEndpointURL: URL? {
        // Înlocuim /ping cu /batch pentru endpoint-ul de sincronizare
        guard let url = endpointURL?.absoluteString else { return nil }
        return URL(string: url.replacingOccurrences(of: "/ping", with: "/batch"))
    }
    
    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }
    
    /// Construiește payload-ul JSON. Task #34 & #183
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
            "deviceId": UIDevice.uniqueId, // Adăugat conform noului model
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
    
    /// Trimite un calup de date (batch) și returnează true dacă a fost acceptat de server (HTTP 202). Task #184
    func sendBatchPings(payload: [[String: Any]]) async -> Bool {
        guard let url = batchEndpointURL else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("TelemetryService: Eroare serializare batch JSON: \(error)")
            return false
        }
        
        return await withCheckedContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let _ = error {
                    continuation.resume(returning: false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 202 {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }.resume()
        }
    }
}
