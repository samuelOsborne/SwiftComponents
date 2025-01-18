//
//  ContentView.swift
//  SwiftComponents
//
//  Created by Sam on 06/01/2025.
//

import SwiftUI
import ScreenCaptureKit

struct ContentView: View {
    @ObservedObject var viewModel = WebcamViewerViewModel()
    @ObservedObject var screenCaptureManager = ScreenCaptureManager()
        
    private let verticalLabelSpacing: CGFloat = 8
    
    var timer = Timer()
    
    init() {
        viewModel.checkAuthorization()
    }
    
    
    func takeScreenshot() {
        viewModel.takeScreenshot()
    }
    
    var body: some View {
        VStack {
            Picker("Select Webcam: ", selection: $viewModel.selectedWebcam) {
                ForEach(viewModel.webcams, id: \.uniqueID) { device in
                    Text(device.localizedName)
                        .tag(Optional(device))
                }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.webcams.isEmpty)
            .padding()
            
            PlayerContainerView(captureSession: viewModel.captureSession).padding()
            
            HStack() {
                Button("Capture webcam still") {
                    takeScreenshot()
                }
                
                Button("Take window / app screenshot") {
                    Task {
                        do {
                            try await screenCaptureManager.takeScreenShot()
                        } catch {
                            print("Error in UI")
                        }
                    }
                }
            }
            
            VStack {
                Text("Capture Type")
                Picker("Capture", selection: $screenCaptureManager.captureType) {
                    Text("Display")
                        .tag(ScreenCaptureManager.CaptureType.display)
                    Text("Window")
                        .tag(ScreenCaptureManager.CaptureType.window)
                }
            }.padding()

            
            VStack() {
                Text("Screen Content")
                switch screenCaptureManager.captureType {
                case .display:
                    Picker("Display", selection: $screenCaptureManager.selectedDisplay) {
                        ForEach(screenCaptureManager.availableDisplays, id: \.self) { display in
                            Text(display.displayName)
                                .tag(display)
                        }
                    }
                    
                case .window:
                    Picker("Window", selection: $screenCaptureManager.selectedWindow) {
                        ForEach(screenCaptureManager.availableWindows, id: \.self) { window in
                            Text(window.displayName)
                                .tag(SCWindow?.some(window))
                        }
                    }
                }
            }
            .padding()
            
            DockApps()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
