//
//  ActiveAppsView.swift
//  SwiftComponents
//
//  Created by Sam on 24/10/2024.
//

import SwiftUI

struct DockApps: View {
    @ObservedObject var dockApps: DockAppsViewModel = DockAppsViewModel()
    
    var body: some View {
        VStack {
            HStack {
                ForEach(dockApps.dockApps) { dockApp in
                    VStack {
                        VStack(alignment: .leading) {
                            if let icon = dockApp.icon {
                                Image(nsImage: icon)
                            }
                            Text("\(dockApp.appName)")
                        }
                    }
                    .tag(dockApp as DockAppModel?)
                }
            }
        }
        .padding()
    }
}

#Preview {
    DockApps()
}

