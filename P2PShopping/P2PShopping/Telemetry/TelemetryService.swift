import Foundation

/// Serviciu pentru trimiterea datelor de telemetrie către backend.
/// Task #34 - Send telemetry ping to backend
class TelemetryService {
    static let shared = TelemetryService()
    
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
    
    private init() {}
    
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

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        // Construim payload-ul conform specificațiilor (Task #34)
        var payload: [String: Any] = [
            "storeId": storeId,
            "itemId": itemId,
            "triggerType": triggerType,
            "timestamp": timestamp,
            "accuracy": accuracy ?? 0.0
        ]
        
        // Adăugăm coordonatele doar dacă sunt disponibile (GDPR compliant)
        if let lat = latitude, let lng = longitude {
            payload["lat"] = lat
            payload["lng"] = lng
        } else {
            payload["lat"] = NSNull()
            payload["lng"] = NSNull()
        }
        
        // Privacy: Logăm doar că trimitem ping-ul, nu și valorile exacte
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
        
        // Executăm cererea HTTP
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("TelemetryService: Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                // Serverul ar trebui să întoarcă 202 Accepted
                if httpResponse.statusCode == 202 {
                    print("TelemetryService: Success! Server returned 202 Accepted")
                } else {
                    print("TelemetryService: Server returned status code \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}
