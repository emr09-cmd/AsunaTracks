//
//  ContentView.swift
//  WatchOS Watch App
//
//  Created by emr09 on 16/07/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var linkManager: WatchLinkManager
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: linkManager.username.isEmpty ? "qrcode" : "checkmark.circle.fill")
                .font(.title2).foregroundStyle(.tint)
            Text(linkManager.username.isEmpty ? "Open AsunaTracks on iPhone and choose Link External Device" : "Linked as \(linkManager.username)")
                .multilineTextAlignment(.center)
            if linkManager.username.isEmpty { Text(linkManager.pairingCode.prefix(8)).font(.caption.monospaced()) }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
