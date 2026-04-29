import SwiftUI
import WebKit

/// Wrapper over WKWebView to integrate into SwiftUI.
/// Handles Tasks #214 (Setup), #215 (Back Navigation), and #216 (External Links).
struct P2PWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    let permissionManager: LocationPermissionManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Task #217 (JS Bridge): Inject the location permission handler
        let bridgeHandler = LocationBridgeHandler(permissionManager: permissionManager)
        configuration.userContentController.add(bridgeHandler, name: "locationBridge")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Task #215 (Back Navigation): Native iOS swipe-to-go-back for web history
        webView.allowsBackForwardNavigationGestures = true
        
        // Task #214 (Load URL)
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Not dynamically updating the URL in this view yet
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: P2PWebView
        
        init(_ parent: P2PWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        // Task #216 (External Links Handler)
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            let host = url.host?.lowercased() ?? ""
            let scheme = url.scheme?.lowercased() ?? ""
            
            // Allow internal P2P URLs (stay in WebView)
            if host.contains("p2p-shopping.app") || host == "localhost" {
                decisionHandler(.allow)
                return
            }
            
            // Open external links and special schemes (mailto, tel) in system browser
            if scheme == "http" || scheme == "https" || scheme == "mailto" || scheme == "tel" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}