//
//  WatchOSApp.swift
//  WatchOS Watch App
//
//  Created by emr09 on 16/07/2026.
//

import SwiftUI

@main
struct WatchOS_Watch_AppApp: App {
    @StateObject private var linkManager = WatchLinkManager()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(linkManager).onAppear { linkManager.activate() }
        }
    }
}
