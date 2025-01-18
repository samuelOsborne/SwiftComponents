//
//  ScreenCaptureManager.swift
//  SwiftComponents
//
//  Created by Sam on 13/01/2025.
//

import ScreenCaptureKit
import Combine
import AppKit

extension SCWindow {
    var displayName: String {
        switch (owningApplication, title) {
        case (.some(let application), .some(let title)):
            return "\(application.applicationName): \(title)"
        case (.none, .some(let title)):
            return title
        case (.some(let application), .none):
            return "\(application.applicationName): \(windowID)"
        default:
            return ""
        }
    }
}

func getDisplayName(for displayID: CGDirectDisplayID) -> String {
    let screens = NSScreen.screens
    if let screen = screens.first(where: { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == displayID }) {
        return screen.localizedName
    }
    return "Display \(displayID)"
}

extension SCDisplay {
    var displayName: String {
        "\(getDisplayName(for: displayID)) \(width) x \(height)"
    }
}

@MainActor
class ScreenCaptureManager : ObservableObject {
    enum CaptureType {
        case display
        case window
    }
    
    private var filter: SCContentFilter?
    private var config: SCStreamConfiguration?
    
    @Published var captureType: CaptureType = .display
    
    var displayNames: [String] = []
    
    @Published var selectedDisplay: SCDisplay?
    
    @Published var selectedWindow: SCWindow?
    
    @Published var isAppExcluded = false
    
    @Published var showCursor = false
    
    // Combine subscribers.
    private var subscriptions = Set<AnyCancellable>()
    
    private var isSetup = false
    
    private var availableApps = [SCRunningApplication]()
    
    @Published private(set) var availableDisplays = [SCDisplay]()
    
    @Published private(set) var availableWindows = [SCWindow]()
    
    private var contentFilter: SCContentFilter {
        var filter: SCContentFilter
        switch captureType {
        case .display:
            guard let display = selectedDisplay else { fatalError("No display selected.") }
            
            var excludedApps = [SCRunningApplication]()
            
            // If a user chooses to exclude the app from the stream,
            // exclude it by matching its bundle identifier.
            if isAppExcluded {
                excludedApps = availableApps.filter { app in
                    Bundle.main.bundleIdentifier == app.bundleIdentifier
                }
            }
            // Create a content filter with excluded apps.
            filter = SCContentFilter(display: display,
                                     excludingApplications: excludedApps,
                                     exceptingWindows: [])
        case .window:
            guard let window = selectedWindow else { fatalError("No window selected.") }
            // Create a content filter that includes a single window.
            filter = SCContentFilter(desktopIndependentWindow: window)
        }
        
        return filter
    }
    
    init() {
        Task {
            do {
                await start()
            } catch {
                print("Error setting up filter.")
            }
        }
    }
    
    /// Starts capturing screen content.
    func start() async {
        // Exit early if already running.
        if !isSetup {
            // Starting polling for available screen content.
            await monitorAvailableContent()
            isSetup = true
        }
    }

    func monitorAvailableContent() async {
        guard !isSetup else { return }
        // Refresh the lists of capturable content.
        await self.refreshAvailableContent()
        Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.refreshAvailableContent()
            }
        }
        .store(in: &subscriptions)
    }
    
    private func refreshAvailableContent() async {
        do {
            // Retrieve the available screen content to capture.
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                        onScreenWindowsOnly: true)
            availableDisplays = availableContent.displays
            
            let windows = filterWindows(availableContent.windows)
            if windows != availableWindows {
                availableWindows = windows
            }
            availableApps = availableContent.applications
            
            if selectedDisplay == nil {
                selectedDisplay = availableDisplays.first
            }
            if selectedWindow == nil {
                selectedWindow = availableWindows.first
            }
        } catch {
            print("Failed to get the shareable content: \(error.localizedDescription)")
        }
    }
    
    private func filterWindows(_ windows: [SCWindow]) -> [SCWindow] {
        windows
        // Sort the windows by app name.
            .sorted { $0.owningApplication?.applicationName ?? "" < $1.owningApplication?.applicationName ?? "" }
        // Remove windows that don't have an associated .app bundle.
            .filter { $0.owningApplication != nil && $0.owningApplication?.applicationName != "" }
        // Remove this app's window from the list.
            .filter { $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier }
    }
    
    func writeImageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer, filename: String) {
        // Get the Downloads directory path
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("Could not access Downloads directory")
            return
        }
        
        // Create the file URL
        let fileURL = downloadsURL.appendingPathComponent(filename)
        
        // Get the image buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Could not get image buffer from sample buffer")
            return
        }
        
        // Create CIImage from the image buffer
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // Create context for rendering
        let context = CIContext()
        
        // Convert to PNG data
        if let pngData = context.pngRepresentation(of: ciImage, format: .RGBA8, colorSpace: ciImage.colorSpace!) {
            do {
                try pngData.write(to: fileURL)
                print("Successfully wrote image to: \(fileURL.path)")
            } catch {
                print("Error writing to file: \(error)")
            }
        } else {
            print("Could not create PNG data from image")
        }
    }
    
    public func takeScreenShot() async throws {
        let myConfiguration = SCStreamConfiguration();
        
        myConfiguration.width = Int(self.contentFilter.contentRect.width)
        myConfiguration.height = Int(self.contentFilter.contentRect.height)
        
        myConfiguration.showsCursor = self.showCursor
                
        // Call the screenshot API and get your screenshot image
        if let screenshot = try? await SCScreenshotManager.captureSampleBuffer(contentFilter: self.contentFilter, configuration:
                                                                                myConfiguration) {
            print("Fetched screenshot.")
            let timestamp = ISO8601DateFormatter().string(from: Date())
            
            writeImageFromSampleBuffer(screenshot, filename: "screen_\(timestamp).png")
        } else {
            print("Failed to fetch screenshot.")
        }
    }
}
