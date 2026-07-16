//
//  UniversalLinkOpener.swift
//  AsunaTracks
//

import UIKit

enum UniversalLinkOpener {
    static func open(_ webURL: URL) {
        let nativeURL = nativeURL(for: webURL)
        guard let nativeURL else {
            UIApplication.shared.open(webURL)
            return
        }
        // `canOpenURL` requires LSApplicationQueriesSchemes, which cannot be
        // represented as an array by Xcode's generated-plist build settings.
        // Opening directly lets iOS report failure, at which point we use Safari.
        UIApplication.shared.open(nativeURL, options: [:]) { opened in
            if !opened { UIApplication.shared.open(webURL) }
        }
    }

    private static func nativeURL(for url: URL) -> URL? {
        guard let host = url.host?.lowercased() else { return nil }
        let pathAndQuery = url.path + (url.query.map { "?\($0)" } ?? "")
        if host.contains("crunchyroll.com") { return URL(string: "crunchyroll:/\(pathAndQuery)") }
        if host.contains("netflix.com") { return URL(string: "netflix:/\(pathAndQuery)") }
        if host == "youtube.com" || host == "www.youtube.com" || host == "youtu.be" { return URL(string: "youtube:/\(pathAndQuery)") }
        return nil
    }
}
