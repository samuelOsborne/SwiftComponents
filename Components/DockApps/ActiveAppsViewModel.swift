//
//  ActiveAppsViewModel.swift
//  SwiftComponents
//
//  Created by Sam on 24/10/2024.
//

import Foundation
import AppKit
import ScreenCaptureKit

public class DockAppsViewModel: ObservableObject {
    @Published private(set) var runningApps: [NSRunningApplication] = []
    @Published private(set) var dockApps: [DockAppModel] = []

    private var runningAppsTimer: Timer?
    
    init() {
        updateRunningApps()
        autoRefreshApps()
    }
    
    deinit {
        runningAppsTimer?.invalidate()
        runningAppsTimer = nil
    }

    public func autoRefreshApps() {
        runningAppsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {[weak self] _ in
            self?.updateRunningApps()
        }
    }
    
    public func stopAutoRefreshApps() {
        runningAppsTimer?.invalidate()
        runningAppsTimer = nil
    }

    private func getWindowIcon(pid: pid_t, bundleId: String) -> NSImage? {
        let workspace = NSWorkspace.shared
        if let app = workspace.runningApplications
            .first(where: { $0.processIdentifier == pid && $0.bundleIdentifier == bundleId }) {
            let icon = app.icon
            icon?.size = NSSize(width: 20, height: 20)
            return icon
        }
        return nil
    }
    
    private func updateRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular &&
            app.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        
        let runningBundleIdentifiers = Set(runningApps.compactMap { $0.bundleIdentifier })
        
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        
        var seenWindows = Set<String>()
        
        let filteredWindows = windowList.compactMap { window -> DockAppModel? in
            guard let windowNumber = window[kCGWindowNumber as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  let app = runningApps.first(where: { $0.processIdentifier == ownerPID }),
                  let bundleId = app.bundleIdentifier,
                  runningBundleIdentifiers.contains(bundleId),
                  bundleId != Bundle.main.bundleIdentifier
            else {
                return nil
            }
            
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let windowOwner = window[kCGWindowOwnerName as String] as? String ?? ""
            
            if windowOwner.lowercased().contains("menubar") ||
                (windowName.isEmpty && windowOwner.isEmpty) {
                return nil
            }
            
            let displayName = windowName.isEmpty ? windowOwner : windowName
            let windowIdentifier = "\(bundleId):\(displayName)"
            
            guard !seenWindows.contains(windowIdentifier) else {
                return nil
            }
            
            seenWindows.insert(windowIdentifier)
            
            // Get the icon for this window
            let icon = getWindowIcon(pid: ownerPID, bundleId: bundleId)
            
            return DockAppModel(
                id: windowNumber,
                name: displayName,
                appName: app.localizedName ?? windowOwner,
                pid: ownerPID,
                bundleId: bundleId,
                icon: icon
            )
        }
        
        let sortedWindows = filteredWindows.sorted {
            if $0.appName == $1.appName {
                return $0.name < $1.name
            }
            return $0.appName < $1.appName
        }
        
        DispatchQueue.main.async {
            self.dockApps = sortedWindows
        }
    }
}
