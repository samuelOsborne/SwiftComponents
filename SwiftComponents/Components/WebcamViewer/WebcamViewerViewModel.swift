//
//  WebcamViewerViewModel.swift
//  SwiftComponents
//
//  Created by Sam on 06/01/2025.
//
//  Credits:
//  Modified code from Benoit Pasquier's blog: https://benoitpasquier.com/webcam-utility-app-macos-swiftui/
//

import Foundation
import AVFoundation
import Combine
import AppKit

//Todo: Test with multiple sources
class WebcamViewerViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isGranted: Bool = false
    @Published var webcams: [AVCaptureDevice] = []
    @Published var selectedWebcam: AVCaptureDevice? {
        didSet {
            if let device = selectedWebcam {
                startSessionForDevice(device)
            }
        }
    }
    
    var captureSession: AVCaptureSession!
    private var videoOutput: AVCaptureVideoDataOutput?
    private var shouldTakeScreenshot = false
    
    private var observer: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    private let concurrentWriter = DispatchQueue(label: "com.swiftcomponents.webcamviewmodel", qos: .userInitiated)
    
    override init() {
        super.init()
        captureSession = AVCaptureSession()
        setupBindings()
        setupDeviceMonitoring()
    }
    
    private func setupDeviceMonitoring() {
        webcams = listWebcams()
        
        observer = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.webcams = self?.listWebcams() ?? []
        }
        
        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.webcams = self?.listWebcams() ?? []
        }
    }
    
    func setupBindings() {
        $isGranted
            .sink { [weak self] isGranted in
                if isGranted {
                    self?.prepareCamera()
                } else {
                    self?.stopSession()
                }
            }
            .store(in: &cancellables)
    }
    
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isGranted = true
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.isGranted = granted
                    }
                }
            }
            
        case .denied:
            self.isGranted = false
            return
            
        case .restricted:
            self.isGranted = false
            return
        @unknown default:
            fatalError()
        }
    }
    
    func listWebcams() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, AVCaptureDevice.DeviceType.external],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        captureSession.startRunning()
    }
    
    func startSessionForDevice(_ device: AVCaptureDevice) {
        do {
            self.stopSession()
            
            let input = try AVCaptureDeviceInput(device: device)
            addInput(input)
            
            // Setup video output
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "screenshot.queue"))
            if let output = videoOutput, captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            
            startSession()
        } catch {
            print("Something went wrong - ", error.localizedDescription)
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
    }
    
    func prepareCamera() {
        captureSession.sessionPreset = .high
        
        if let device = AVCaptureDevice.default(for: .video) {
            self.selectedWebcam = device
            startSessionForDevice(device)
        }
    }
    
    func addInput(_ input: AVCaptureInput) {
        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)
    }
    
    func takeScreenshot() {
        shouldTakeScreenshot = true
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard shouldTakeScreenshot,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                
        concurrentWriter.sync {
            shouldTakeScreenshot = false
        }
        
        concurrentWriter.async {
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            if let tiffData = image.tiffRepresentation,
               let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let fileURL = downloadsURL.appendingPathComponent("webcam_\(timestamp).png")
                
                do {
                    try tiffData.write(to: fileURL)
                } catch {
                    print("Failed to save screenshot: \(error.localizedDescription)")
                }
            }
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
