import SwiftUI
import WebKit
import CoreLocation

struct P2PWebView: UIViewRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        
        // Task #217: JS Bridge - DeviceId & Platform
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios-device"
        let bridgeScriptSource = """
        window.P2PBridge = {
            getDeviceId: function() { return '\(deviceId)'; },
            getPlatform: function() { return 'ios'; },
            saveToken: function(token) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.authBridge) {
                    window.webkit.messageHandlers.authBridge.postMessage({action: "saveToken", token: token});
                }
            },
            clearToken: function() {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.authBridge) {
                    window.webkit.messageHandlers.authBridge.postMessage({action: "clearToken"});
                }
            }
        };
        """
        let bridgeScript = WKUserScript(source: bridgeScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(bridgeScript)
        
        // Bridge for Location (Issue #27)
        let locationHandler = LocationBridgeHandler(permissionManager: LocationPermissionManager())
        config.userContentController.add(locationHandler, name: "locationBridge")

        // Bridge for Auth (Task #218)
        let authHandler = AuthBridgeHandler()
        config.userContentController.add(authHandler, name: "authBridge")
        
        // Inițializăm cu frame .zero, SwiftUI va ajusta dimensiunea corespunzător
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .clear
        
        print("P2PWebView: Încercăm încărcarea URL: \(url.absoluteString)")
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Nu facem nimic aici pentru a evita reîncărcarea infinită
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: P2PWebView
        
        init(_ parent: P2PWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("P2PWebView: A început navigarea...")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("P2PWebView: EROARE LA ÎNCĂRCARE: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("P2PWebView: EROARE NAVIGARE: \(error.localizedDescription)")
        }
        
        // Task #218: JWT Token Injection into WebView
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("P2PWebView: Pagina s-a încărcat cu succes!")
            let defaults = UserDefaults.standard
            if let token = defaults.string(forKey: "jwt_token"), !token.isEmpty {
                let script = """
                (function() {
                    try {
                        localStorage.setItem('authToken', '\(token)');
                        window.dispatchEvent(
                            new CustomEvent('p2p:tokenReady', { detail: { token: '\(token)' } })
                        );
                    } catch(e) {
                        console.error('[P2P iOS] Token injection failed:', e);
                    }
                })();
                """
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
        
        // Task #216: External Links Handler
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            let host = url.host ?? ""
            print("P2PWebView: Verificăm navigare către: \(url.absoluteString)")
            
            // Allow everything on localhost or 127.0.0.1
            if host.contains("localhost") || host.contains("127.0.0.1") {
                decisionHandler(.allow)
                return
            }
            
            // Allow same origin
            if let parentHost = parent.url.host, host == parentHost {
                decisionHandler(.allow)
                return
            }
            
            // Redirect other http/https to system browser
            if ["http", "https"].contains(url.scheme) {
                print("P2PWebView: Redirectăm către browser extern: \(url.absoluteString)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}
