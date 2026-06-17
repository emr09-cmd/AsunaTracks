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
