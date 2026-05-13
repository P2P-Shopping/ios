import Foundation
import WebKit
import UIKit
import Photos

/// Task #222 - Native Camera & Gallery Intent (iOS)
/// Task #224 - On-Device Image Compression (iOS)
class CameraBridgeHandler: NSObject, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private weak var webView: WKWebView?
    private var callbackId: String?
    
    init(webView: WKWebView) {
        self.webView = webView
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "cameraBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        
        if action == "openNativeCamera" {
            self.callbackId = body["callbackId"] as? String
            presentImagePicker()
        }
    }
    
    private func presentImagePicker() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Select Image Source", message: nil, preferredStyle: .actionSheet)
            
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
                    self.checkCameraPermission {
                        self.showPicker(sourceType: .camera)
                    }
                })
            }
            
            alert.addAction(UIAlertAction(title: "Photo Gallery", style: .default) { _ in
                self.checkPhotoLibraryPermission {
                    self.showPicker(sourceType: .photoLibrary)
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            // For iPad compatibility
            if let topController = self.getTopViewController() {
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = topController.view
                    popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                topController.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func showPicker(sourceType: UIImagePickerController.SourceType) {
        DispatchQueue.main.async {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = sourceType
            if let topController = self.getTopViewController() {
                topController.present(picker, animated: true, completion: nil)
            }
        }
    }
    
    private func checkCameraPermission(completion: @escaping () -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { completion() } }
            }
        case .denied, .restricted:
            print("[CameraBridge] Camera permission denied")
        @unknown default:
            break
        }
    }
    
    private func checkPhotoLibraryPermission(completion: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            completion()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized || status == .limited {
                    DispatchQueue.main.async { completion() }
                }
            }
        case .denied, .restricted:
            print("[CameraBridge] Photo Library permission denied")
        @unknown default:
            break
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[.originalImage] as? UIImage else {
            sendResult(base64: nil)
            return
        }
        
        // Task #224 - Process and Compress
        processImage(image)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        sendResult(base64: nil)
    }
    
    private func processImage(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let maxDimension: CGFloat = 1920
            var finalImage = image
            
            // 1. Resize if needed
            let size = image.size
            if size.width > maxDimension || size.height > maxDimension {
                let ratio = size.width / size.height
                var newSize: CGSize
                if size.width > size.height {
                    newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
                } else {
                    newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
                }
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    finalImage = resizedImage
                }
                UIGraphicsEndImageContext()
            }
            
            // 2. Compress to JPEG 80%
            if let data = finalImage.jpegData(compressionQuality: 0.8) {
                let base64 = data.base64EncodedString()
                self.sendResult(base64: base64)
            } else {
                self.sendResult(base64: nil)
            }
        }
    }
    
    private func sendResult(base64: String?) {
        DispatchQueue.main.async {
            let result = base64 != nil ? "'\(base64!)'" : "null"
            let js = "window.onNativeImageReceived(\(result))"
            self.webView?.evaluateJavaScript(js, completionHandler: { (result, error) in
                if let error = error {
                    print("[CameraBridge] Error calling JS: \(error)")
                }
            })
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        var topController = keyWindow?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
}
