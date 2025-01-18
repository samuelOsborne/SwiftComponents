//
//  ActiveAppsModel.swift
//  SwiftComponents
//
//  Created by Sam on 24/10/2024.
//

import Foundation
import AppKit
import ScreenCaptureKit

struct DockAppModel: Identifiable, Hashable {
    let id: Int
    let name: String
    let appName: String
    let pid: pid_t
    let bundleId: String
    let icon: NSImage?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DockAppModel, rhs: DockAppModel) -> Bool {
        lhs.id == rhs.id
    }
}
