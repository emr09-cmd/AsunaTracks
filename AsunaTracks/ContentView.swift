//
//  ContentView.swift
//  AsunaTracks
//
//  Created by emr09 on 06/06/2026.
//

import SwiftUI
import WebKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Networking Models
    struct APIResponse: Decodable {
        let items: [Anime]
    }
    
    struct APIErrorEnvelope: Decodable {
        let message: String?
        let error: Bool?
    }

    struct Anime: Identifiable, Decodable {
        let id: Int
        let media_type: String?
        let mal_id: Int?
        let title: String
        let title_english: String?
        let title_japanese: String?
        let title_synonyms: [String]?
        let synopsis: String?
        let image_url: String?
        let banner_image_url: String?
        let score: Double?
        let rank: Int?
        let popularity: Int?
        let status: String?
        let type: String?
        let episodes: Int?
        let chapters: Int?
        let volumes: Int?
        let start_date: String?
        let end_date: String?
        let season: String?
        let year: Int?
        let age_rating: String?
        let rating: String?
        let asunatracks_score: AsunaTracksScore?
        let genres: [Genre]?

        struct Genre: Decodable {
            let id: Int?
            let mal_id: Int?
            let name: String
            let kind: String?
        }

        struct AsunaTracksScore: Decodable {
            let score: Double?
            let score_10: Double?
            let rating: Double?
            let count: Int?
        }

        var primaryGenre: String { genres?.first?.name ?? "" }
        var tagText: String { (type ?? "").uppercased().isEmpty ? "ANIME" : (type ?? "ANIME").uppercased() }

        var infoLine: String {
            var parts: [String] = []
            if let ats = asunatracks_score?.rating {
                parts.append(String(format: "★ %.1f", ats))
            } else if let sc = score {
                parts.append(String(format: "★ %.1f", sc))
            }
            if let first = genres?.first?.name, !first.isEmpty {
                parts.append(first)
            }
            if let ep = episodes, ep > 0 {
                parts.append("\(ep) eps")
            }
            if let y = year, y > 0 {
                parts.append(String(y))
            }
            if let contentRating = rating, !contentRating.isEmpty {
                parts.append(contentRating)
            }
            return parts.joined(separator: " • ")
        }
    }

    @State private var actionAnime: [Anime] = []
    @State private var isLoadingAction: Bool = false

    struct AnimeResponse: Decodable {
        let items: [Anime]
    }

    // MARK: - State
    @State private var fetchedAnime: [Anime] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var fetchedManga: [Anime] = []
    @State private var isLoadingManga = false
    @State private var mangaErrorMessage: String?

    @ViewBuilder
    private func animeCard(_ item: Anime) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 220, height: 300)
                    .overlay(
                        Group {
                            if let urlString = item.image_url, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 220, height: 300)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 220, height: 300)
                                            .clipped()
                                    case .failure:
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                    @unknown default:
                                        Color.clear
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    )
                Text(item.tagText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
            }

            Text(item.title)
                .font(.headline)
                .foregroundStyle(colorScheme == .dark ? .white : .black)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(item.infoLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(width: 220)
    }
    
    private enum Tab: String, CaseIterable {
        case discover, search, seasons, myList, profile
    }
    
    @State private var selectedTab: Tab = .discover
    
    @ViewBuilder
    private func navItem(tab: Tab, label: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                Text(label)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .layoutPriority(1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(
                isSelected
                ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                : Color.clear,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder((colorScheme == .dark ? Color.white : Color.black).opacity(0.12))
                    }
                }
            )
            .foregroundStyle(
                isSelected
                ? Color.accentColor
                : (colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))
            )
            .dynamicTypeSize(.large ... .accessibility3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Networking
    private func fetchAnime() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let url = URL(string: "https://asunatracks.space/public/api/anime")!
            let (data, response) = try await URLSession.shared.data(from: url)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            if let envelope = try? decoder.decode(APIResponse.self, from: data) {
                await MainActor.run {
                    self.fetchedAnime = envelope.items
                    self.errorMessage = nil
                }
            } else if let direct = try? decoder.decode([Anime].self, from: data) {
                await MainActor.run {
                    self.fetchedAnime = direct
                    self.errorMessage = nil
                }
            } else {
                let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
                // Try to decode a simple error envelope to surface a better message
                if let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data), let msg = apiError.message, !msg.isEmpty {
                    throw NSError(domain: "APIError", code: -2, userInfo: [NSLocalizedDescriptionKey: msg, "raw": raw])
                }
                // Log raw for diagnostics in development
                print("Raw API response:", raw)
                throw NSError(domain: "DecodeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format", "raw": raw])
            }
        } catch {
            let nsErr = error as NSError
            if let raw = nsErr.userInfo["raw"] as? String { print("Decode error raw response:\n\(raw)") }
            await MainActor.run { self.errorMessage = nsErr.localizedDescription }
        }
    }
    
    private func fetchManga() async {
        guard !isLoadingManga else { return }
        isLoadingManga = true
        defer { isLoadingManga = false }
        do {
            let url = URL(string: "https://asunatracks.space/public/api/manga")!
            let (data, response) = try await URLSession.shared.data(from: url)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            if let envelope = try? decoder.decode(APIResponse.self, from: data) {
                await MainActor.run {
                    self.fetchedManga = envelope.items
                    self.mangaErrorMessage = nil
                }
            } else if let direct = try? decoder.decode([Anime].self, from: data) {
                await MainActor.run {
                    self.fetchedManga = direct
                    self.mangaErrorMessage = nil
                }
            } else {
                let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
                if let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data), let msg = apiError.message, !msg.isEmpty {
                    throw NSError(domain: "APIError", code: -2, userInfo: [NSLocalizedDescriptionKey: msg, "raw": raw])
                }
                print("Raw Manga API response:", raw)
                throw NSError(domain: "DecodeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format", "raw": raw])
            }
        } catch {
            let nsErr = error as NSError
            if let raw = nsErr.userInfo["raw"] as? String { print("Manga decode error raw response:\n\(raw)") }
            await MainActor.run { self.mangaErrorMessage = nsErr.localizedDescription }
        }
    }
    
    @ViewBuilder
    private var contentBody: some View {
        ZStack {
            // Adaptive background: pure black in Dark Mode, pure white in Light Mode
            (colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.07) : Color.white)
                .ignoresSafeArea()

            VStack {
                // Content
                if selectedTab == .profile {
                    ProfileView(colorScheme: colorScheme)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Asunatracks")
                                        .font(.largeTitle).bold()
                                    Text("Discover anime and manga, track your progress")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            // Popular Anime Section
                            HStack {
                                Text("Popular Anime")
                                    .font(.title2).bold()
                                Spacer()
                                Button("See all") {}
                                    .font(.callout)
                            }
                            .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    if isLoading {
                                        ProgressView()
                                            .frame(width: 220, height: 300)
                                    } else if let errorMessage = errorMessage {
                                        VStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.title)
                                                .foregroundStyle(.secondary)
                                            Text(errorMessage)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 220)
                                        }
                                    } else {
                                        ForEach(fetchedAnime.prefix(12)) { item in
                                            animeCard(item)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                            }
                            
                            // Popular Manga Section
                            HStack {
                                Text("Popular Manga")
                                    .font(.title2).bold()
                                Spacer()
                                Button("See all") {}
                                    .font(.callout)
                            }
                            .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    if isLoadingManga {
                                        ProgressView()
                                            .frame(width: 220, height: 300)
                                    } else if let mangaErrorMessage = mangaErrorMessage {
                                        VStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.title)
                                                .foregroundStyle(.secondary)
                                            Text(mangaErrorMessage)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 220)
                                        }
                                    } else {
                                        ForEach(fetchedManga.prefix(12)) { item in
                                            animeCard(item)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Action Anime")
                                    .font(.title2).bold()
                                    .padding(.horizontal)

                                if isLoadingAction {
                                    ProgressView()
                                        .padding(.horizontal)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(actionAnime) { item in
                                                ZStack(alignment: .topLeading) {
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(Color.gray.opacity(0.15))
                                                        .frame(width: 220, height: 300)
                                                        .overlay(
                                                            Group {
                                                                if let urlString = item.image_url, let url = URL(string: urlString) {
                                                                    AsyncImage(url: url) { phase in
                                                                        switch phase {
                                                                        case .empty:
                                                                            ProgressView()
                                                                                .frame(width: 220, height: 300)
                                                                        case .success(let image):
                                                                            image
                                                                                .resizable()
                                                                                .scaledToFill()
                                                                                .frame(width: 220, height: 300)
                                                                                .clipped()
                                                                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                                        case .failure(_):
                                                                            ZStack {
                                                                                Color.gray.opacity(0.1)
                                                                                Image(systemName: "photo")
                                                                                    .resizable()
                                                                                    .scaledToFit()
                                                                                    .frame(width: 60, height: 60)
                                                                                    .foregroundColor(.secondary)
                                                                            }
                                                                            .frame(width: 220, height: 300)
                                                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                                        @unknown default:
                                                                            EmptyView()
                                                                        }
                                                                    }
                                                                } else {
                                                                    Color.gray.opacity(0.1)
                                                                        .frame(width: 220, height: 300)
                                                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                                }
                                                            }
                                                        )
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            Spacer(minLength: 120)
                        }
                    }
                    .task {
                        await fetchAnime()
                        await fetchManga()
                        await loadActionAnime()
                    }
                }

                // Rounded, translucent navigation bar
                HStack(spacing: 4) {
                    navItem(tab: .discover, label: "Discover", systemImage: "house")
                    navItem(tab: .search, label: "Search", systemImage: "magnifyingglass")
                    navItem(tab: .seasons, label: "Seasons", systemImage: "calendar")
                    navItem(tab: .myList, label: "My List", systemImage: "bookmark")
                    navItem(tab: .profile, label: "Profile", systemImage: "person")
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 78)
                .background(
                    .ultraThinMaterial
                        .opacity(0.95),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            (colorScheme == .dark ? Color.white : Color.black)
                                .opacity(0.12)
                        )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
            }
        }
    }
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    contentBody
                }
            } else {
                NavigationView {
                    contentBody
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
    
    private func loadActionAnime() async {
        guard let url = URL(string: "https://asunatracks.space/public/api/anime?q=&genre=13&page=1&limit=12") else { return }
        isLoadingAction = true
        defer { isLoadingAction = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AnimeResponse.self, from: data)
            actionAnime = response.items
        } catch {
            print("Failed to load Action Anime:", error)
        }
    }
}

struct ProfileView: View {
    let colorScheme: ColorScheme
    
    @AppStorage("authToken") private var authToken: String = ""
    @AppStorage("authUsername") private var authUsername: String = ""
    @AppStorage("authAvatarURL") private var authAvatarURL: String = ""
    
    @State private var showSignInSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                            .frame(width: 90, height: 90)
                        if let url = URL(string: fullAvatarURLString() ?? "") {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 80, height: 80)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                case .failure:
                                    Image(systemName: "person.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                        .foregroundStyle(.secondary)
                                @unknown default:
                                    Image(systemName: "person.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Image(systemName: "person.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if authToken.isEmpty {
                        Button {
                            showSignInSheet = true
                        } label: {
                            Text("Sign In / Register")
                                .font(.subheadline).bold()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    } else {
                        Button {
                            // Sign Out: clear stored values
                            authToken = ""
                            authUsername = ""
                            authAvatarURL = ""
                        } label: {
                            Text("Sign Out")
                                .font(.subheadline).bold()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                // Tracking Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                    VStack(spacing: 10) {
                        NavigationLink { Text("My List") } label: {
                            row(icon: "bookmark", title: "My List")
                        }
                        NavigationLink { Text("Search") } label: {
                            row(icon: "magnifyingglass", title: "Search")
                        }
                        NavigationLink { Text("Seasonal Charts") } label: {
                            row(icon: "calendar", title: "Seasonal Charts")
                        }
                    }
                    .padding(.horizontal, 12)
                }

                // About Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                    VStack(spacing: 10) {
                        if let url = URL(string: "https://asunatracks.space") {
                            Link(destination: url) {
                                row(icon: "globe", title: "Asunatracks.space")
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }

                Spacer(minLength: 80)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignInSheet) {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    InlineHTMLWebView(html: Self.signInHTML,
                                     authToken: $authToken,
                                     authUsername: $authUsername,
                                     authAvatarURL: $authAvatarURL,
                                     isPresented: $showSignInSheet)
                        .navigationTitle("Sign In")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showSignInSheet = false }
                            }
                        }
                }
            } else {
                NavigationView {
                    InlineHTMLWebView(html: Self.signInHTML,
                                     authToken: $authToken,
                                     authUsername: $authUsername,
                                     authAvatarURL: $authAvatarURL,
                                     isPresented: $showSignInSheet)
                        .navigationTitle("Sign In")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showSignInSheet = false }
                            }
                        }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }

    @ViewBuilder
    private func row(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder((colorScheme == .dark ? Color.white : Color.black).opacity(0.08))
        )
    }
    
    private func fullAvatarURLString() -> String? {
        let path = authAvatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return path }
        return "https://asunatracks.space" + (path.hasPrefix("/") ? path : "/" + path)
    }
    
    static let signInHTML: String = {
        return """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Sign In</title>
<style>
  :root { --bg:#121316; --panel:#1a1c20; --muted:#8a8f98; --accent:#6f7cff; --text:#e9ecf1; --stroke:rgba(255,255,255,0.08);}  
  html,body{margin:0;padding:0;background:var(--bg);color:var(--text);font-family:-apple-system,system-ui,Segoe UI,Roboto,Helvetica,Arial,sans-serif;}
  .container{max-width:420px;margin:24px auto 60px auto;padding:0 16px;}

  /* Dark icon badge similar to Profile style */
  .logo{width:64px;height:64px;border-radius:16px;display:flex;align-items:center;justify-content:center;margin:20px auto;background:rgba(255,255,255,0.06);color:var(--text);} 
  .logo .mark{width:28px;height:28px;border-radius:8px;background:linear-gradient(180deg, rgba(255,255,255,0.12), rgba(255,255,255,0.02));display:flex;align-items:center;justify-content:center;box-shadow:inset 0 0 0 1px var(--stroke);} 
  .logo .mark span{font-weight:800;font-size:14px;letter-spacing:0.5px;color:#cfd5ff}

  h1{font-size:24px;text-align:center;margin:8px 0 6px 0;}
  p.sub{font-size:14px;text-align:center;color:var(--muted);margin:0 0 22px 0}

  .field{display:flex;align-items:center;background:var(--panel);border:1px solid var(--stroke);border-radius:12px;padding:12px 12px;margin-bottom:12px}
  .icon{width:28px;height:28px;border-radius:8px;background:rgba(255,255,255,0.06);display:flex;align-items:center;justify-content:center;color:var(--muted);margin-right:8px;box-shadow:inset 0 0 0 1px var(--stroke);} 
  .icon svg{width:16px;height:16px;opacity:0.85;}
  .field input{flex:1;background:transparent;border:0;outline:none;color:var(--text);font-size:16px}

  .btn{display:block;width:100%;background:var(--accent);color:white;border:0;border-radius:12px;padding:12px 16px;font-weight:700;font-size:16px;margin-top:10px}
  .btn[disabled]{opacity:0.6}
  .link{display:block;text-align:center;color:var(--muted);font-size:13px;margin-top:10px;text-decoration:none}
  .divider{height:1px;background:var(--stroke);margin:22px 0}
  .error{background:#2a1315;color:#ff99a4;border:1px solid rgba(255,0,64,0.25);padding:10px 12px;border-radius:10px;font-size:13px;margin:6px 0 0}
  .success{background:#132a1d;color:#9fffc8;border:1px solid rgba(0,255,128,0.25);padding:10px 12px;border-radius:10px;font-size:13px;margin:6px 0 0}
  .status{min-height:0.01px}
</style>
</head>
<body>
  <div class="container">
    <div class="logo"><div class="mark"><span>A</span></div></div>
    <h1>Asunatracks</h1>
    <p class="sub">Sign in to track your anime and manga</p>

    <div class="field">
      <div class="icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z"/>
          <path d="M4 20a8 8 0 0 1 16 0"/>
        </svg>
      </div>
      <input id="username" type="text" placeholder="Username" autocomplete="username" />
    </div>
    <div class="field">
      <div class="icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="11" width="18" height="10" rx="2"/>
          <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
        </svg>
      </div>
      <input id="password" type="password" placeholder="Password" autocomplete="current-password" />
    </div>
    <button id="signinBtn" class="btn" onclick="signin()">Sign In</button>

    <div id="status" class="status"></div>

    <a class="link" href="#">Don't have an account?</a>
    <div class="divider"></div>
  </div>

<script>
async function signin(){
  const btn = document.getElementById('signinBtn');
  const status = document.getElementById('status');
  status.innerHTML = '';
  const u = document.getElementById('username').value.trim();
  const p = document.getElementById('password').value.trim();
  if(!u || !p){ status.innerHTML = '<div class="error">Please enter username and password.</div>'; return; }
  btn.disabled = true;
  try{
    const res = await fetch('https://asunatracks.space/public/api/auth/login',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({ username: u, password: p })
    });
    const text = await res.text();
    let data;
    try { data = JSON.parse(text); } catch(e) { throw new Error('Unexpected response'); }
    if(res.ok && data && data.token){
      status.innerHTML = '<div class="success">Signed in as <b>'+(data.user?.username || u)+'</b>. Token received.</div>';
      // Optionally, postMessage to the app. The host app can intercept this if needed.
      try { window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.login && window.webkit.messageHandlers.login.postMessage(data); } catch(e){}
    } else {
      const msg = (data && (data.error || data.message)) || 'Wrong username or password.';
      status.innerHTML = '<div class="error">'+ msg +'</div>';
    }
  } catch(err){
    status.innerHTML = '<div class="error">Network error. Please try again.</div>';
  } finally {
    btn.disabled = false;
  }
}
</script>
</body>
</html>
"""
    }()
    
    struct InlineHTMLWebView: UIViewRepresentable {
        let html: String
        @Binding var authToken: String
        @Binding var authUsername: String
        @Binding var authAvatarURL: String
        @Binding var isPresented: Bool
        
        func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
        
        func makeUIView(context: Context) -> WKWebView {
            let config = WKWebViewConfiguration()
            let contentController = WKUserContentController()
            contentController.add(context.coordinator, name: "login")
            config.userContentController = contentController
            
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.contentInsetAdjustmentBehavior = .automatic
            return webView
        }

        func updateUIView(_ uiView: WKWebView, context: Context) {
            uiView.loadHTMLString(html, baseURL: nil)
        }
        
        class Coordinator: NSObject, WKScriptMessageHandler {
            var parent: InlineHTMLWebView
            init(parent: InlineHTMLWebView) { self.parent = parent }
            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                guard message.name == "login" else { return }
                if let dict = message.body as? [String: Any] {
                    if let token = dict["token"] as? String { parent.authToken = token }
                    if let user = dict["user"] as? [String: Any] {
                        if let username = user["username"] as? String { parent.authUsername = username }
                        if let avatar = user["avatar_url"] as? String { parent.authAvatarURL = avatar }
                    }
                    // Dismiss sheet after login
                    parent.isPresented = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

