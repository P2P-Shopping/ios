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
            },
            openNativeCamera: function(callbackId) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cameraBridge) {
                    window.webkit.messageHandlers.cameraBridge.postMessage({action: "openNativeCamera", callbackId: callbackId});
                }
            },
            postTelemetry: function(storeId, itemId, triggerType) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.telemetryBridge) {
                    window.webkit.messageHandlers.telemetryBridge.postMessage({action: "postTelemetry", storeId: storeId, itemId: itemId, triggerType: triggerType});
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
        
        // Initializăm cu frame .zero, SwiftUI va ajusta dimensiunea corespunzător
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // Bridge for Camera (Task #222)
        let cameraHandler = CameraBridgeHandler(webView: webView)
        config.userContentController.add(cameraHandler, name: "cameraBridge")

        // Bridge for Telemetry (Task #217 parity)
        let telemetryHandler = TelemetryBridgeHandler()
        config.userContentController.add(telemetryHandler, name: "telemetryBridge")
        
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
            
            // 1. Inject Token
            injectToken(webView)
            
            // 2. Inject Auto-Ping Script (Checkbox Listener - Task #217 parity)
            injectAutoPingScript(webView)
        }
        
        private func injectToken(_ webView: WKWebView) {
            let service = Bundle.main.bundleIdentifier ?? "com.p2ps.P2PShopping"
            let account = "jwt_token"
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8), !token.isEmpty {
                // Encode token as JSON string to prevent JS injection
                let encoder = JSONEncoder()
                guard let encodedData = try? encoder.encode(token), let encodedToken = String(data: encodedData, encoding: .utf8) else { return }

                let script = """
                (function() {
                    try {
                        localStorage.setItem('authToken', \(encodedToken));
                        window.dispatchEvent(
                            new CustomEvent('p2p:tokenReady', { detail: { token: \(encodedToken) } })
                        );
                    } catch(e) {
                        console.error('[P2P iOS] Token injection failed:', e);
                    }
                })();
                """
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
        
        private func injectAutoPingScript(_ webView: WKWebView) {
            let js = """
            (function() {
                document.addEventListener('change', function(e) {
                    var target = e.target;
                    if (target.type === 'checkbox' && target.checked) {
                        var itemContainer = target.closest('li') || target.closest('[data-id]');
                        var itemId = itemContainer ? (itemContainer.getAttribute('data-id') || itemContainer.id) : null;
                        if (!itemId) {
                            var nameEl = itemContainer ? itemContainer.querySelector('span') : null;
                            itemId = nameEl ? nameEl.innerText.trim() : 'ui_item_' + Date.now();
                        }
                        var storeId = 'Lidl_Vite_Physical';
                        if (window.P2PBridge && window.P2PBridge.postTelemetry) {
                            window.P2PBridge.postTelemetry(storeId, itemId, 'WEB_UI_CHECKOFF');
                        }
                    }
                }, true);
            })();
            """
            webView.evaluateJavaScript(js, nil)
        }
        
        // Task #216: External Links Handler
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            let host = url.host ?? ""
            let scheme = url.scheme ?? ""
            print("P2PWebView: Verificăm navigare către: \(url.absoluteString)")
            
            // 1. Whitelist local development addresses (exact matches only)
            if host == "localhost" || host == "127.0.0.1" || host == "::1" {
                decisionHandler(.allow)
                return
            }
            
            // 2. Allow same origin
            if let parentHost = parent.url.host, host == parentHost {
                decisionHandler(.allow)
                return
            }
            
            // 3. Handle specific app-launch schemes
            if ["tel", "mailto", "sms"].contains(scheme) {
                print("P2PWebView: Redirectăm către aplicație externă: \(url.absoluteString)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            // 4. Redirect other http/https to system browser if not same origin/local
            if ["http", "https"].contains(scheme) {
                print("P2PWebView: Redirectăm către browser extern: \(url.absoluteString)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            // Default: cancel any other unknown schemes
            decisionHandler(.cancel)
        }
    }
}
