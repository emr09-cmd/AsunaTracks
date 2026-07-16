//
//  AsunaTracksApp.swift
//  AsunaTracks
//
//  Created by emr09 on 06/06/2026.
//

import SwiftUI

@main
struct AsunaTracksApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false

    init() {
        // One-time migration for builds that stored the token in UserDefaults.
        let defaults = UserDefaults.standard
        if let legacyToken = defaults.string(forKey: "authToken"), !legacyToken.isEmpty {
            KeychainVault.saveToken(legacyToken)
            defaults.removeObject(forKey: "authToken")
        }
        defaults.set(KeychainVault.readToken() != nil, forKey: "isUserSignedIn")
        #if os(iOS)
        WatchLinkManager.shared.activate()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedSetup {
                ContentView()
            } else {
                OnboardingView()
            }
        }
    }
}
