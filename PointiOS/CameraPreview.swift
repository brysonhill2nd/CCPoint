//
//  CameraPreview.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/22/25.
//

import SwiftUI
import AVFoundation

// MARK: - Camera Preview View
struct CameraPreview: UIViewRepresentable {
    class Coordinator: NSObject {
        var parent: CameraPreview
        var captureSession: AVCaptureSession?
        
        init(_ parent: CameraPreview) {
            self.parent = parent
            super.init()
            setupCamera()
        }
        
        func setupCamera() {
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = .photo
            
            guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: backCamera),
                  let captureSession = captureSession,
                  captureSession.canAddInput(input) else { return }
            
            captureSession.addInput(input)
            captureSession.startRunning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = CameraContainerView()
        
        // Request camera permission
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                DispatchQueue.main.async {
                    if let captureSession = context.coordinator.captureSession {
                        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                        previewLayer.frame = view.bounds
                        previewLayer.videoGravity = .resizeAspectFill
                        view.layer.addSublayer(previewLayer)
                        view.previewLayer = previewLayer
                    }
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame if needed
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Custom UIView that handles layout updates
class CameraContainerView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update the preview layer frame when bounds change
        previewLayer?.frame = bounds
    }
}
