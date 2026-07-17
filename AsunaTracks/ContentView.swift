//
//  ContentView.swift
//  AsunaTracks
//
//  Created by emr09 on 06/06/2026.
//

import SwiftUI
#if os(iOS)
import WebKit
#endif
import UIKit
import AsunaTracksUpdateAlert

#if os(iOS)

// MARK: - Tab Identifier
enum AppTab: Hashable {
    case discover
    case search
    case seasons
    case myList
    case profile
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .discover

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
        let raw: RawMediaInfo?

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

        struct RawMediaInfo: Decodable {
            let source: String?
            let duration: String?
            let chapters: Int?
            let volumes: Int?
            let background: String?
            let published: RawDateInfo?
            let aired: RawDateInfo?
            let members: Int?
            let favorites: Int?
            let scored_by: Int?
            let studios: [MediaNamedResource]?
            let producers: [MediaNamedResource]?
            let licensors: [MediaNamedResource]?
            let authors: [MediaNamedResource]?
            let serializations: [MediaNamedResource]?
            let titles: [MediaTitle]?
            let external: [MediaLink]?
            let streaming: [MediaLink]?
        }

        struct RawDateInfo: Decodable {
            let string: String?
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
        NavigationLink {
            MediaDetailView(item: item)
        } label: {
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
                if let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data), let msg = apiError.message, !msg.isEmpty {
                    throw NSError(domain: "APIError", code: -2, userInfo: [NSLocalizedDescriptionKey: msg, "raw": raw])
                }
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
    private var discoverView: some View {
        ZStack {
            // Adaptive background: pure black in Dark Mode, pure white in Light Mode
            (colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.07) : Color.white)
                .ignoresSafeArea()

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
                                ScreenStateView(
                                    systemImage: "wifi.exclamationmark",
                                    title: "Could not load AsunaTracks",
                                    message: errorMessage,
                                    retryTitle: "Retry",
                                    retry: { Task { await fetchAnime() } }
                                )
                                .frame(width: 220, height: 300)
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
                                ScreenStateView(
                                    systemImage: "wifi.exclamationmark",
                                    title: "Could not load AsunaTracks",
                                    message: mangaErrorMessage,
                                    retryTitle: "Retry",
                                    retry: { Task { await fetchManga() } }
                                )
                                .frame(width: 220, height: 300)
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
                                        animeCard(item)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 24)
                }
            }
            .task {
                await fetchAnime()
                await fetchManga()
                await loadActionAnime()
            }
            AsunaTracksUpdateAlert()
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(TabItem.ordered(midSlots: TabOrderStore.load())) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.label, systemImage: tab.systemImage) }
            }
        }

    }

    @ViewBuilder
    private func tabContent(for tab: TabItem) -> some View {
        switch tab.id {
        case "discover": navigationContainer { discoverView.navigationTitle("Discover") }.tag(AppTab.discover)
        case "search": navigationContainer { SearchView() }.tag(AppTab.search)
        case "seasons": navigationContainer { PlaceholderTabView(title: "Seasons", systemImage: "calendar").navigationTitle("Seasons") }.tag(AppTab.seasons)
        case "myList": navigationContainer { MyListView() }.tag(AppTab.myList)
        case "profile": navigationContainer { ProfileView(colorScheme: colorScheme, selectedTab: $selectedTab) }.tag(AppTab.profile)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
            .navigationViewStyle(StackNavigationViewStyle())
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

struct MediaDetailView: View {
    let item: ContentView.Anime
    var listEntry: MyListEntry?

    @State private var detailResponse: MediaDetailResponse?
    @State private var isLoadingDetails = false
    @State private var detailErrorMessage: String?

    private var media: ContentView.Anime {
        detailResponse?.media ?? item
    }

    private var displayTitle: String {
        media.title_english?.isEmpty == false ? media.title_english! : media.title
    }

    private var originalTitle: String? {
        guard let english = media.title_english, !english.isEmpty, english != media.title else { return nil }
        return media.title
    }

    private var progressTotal: Int {
        if media.media_type == "manga" {
            return media.chapters ?? 0
        }
        return media.episodes ?? 0
    }

    private var progressLabel: String {
        media.media_type == "manga" ? "Chapters" : "Episodes"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                metrics
                trackingSummary
                facts
                alternateTitles
                productionInfo
                genres
                synopsis
                backgroundInfo
                relations
                characters
                themeSongs
                externalLinks
            }
            .padding()
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .overlay {
            if isLoadingDetails && detailResponse == nil {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .task {
            await loadDetails()
        }
        .refreshable {
            await loadDetails()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let bannerURLString = media.banner_image_url, let bannerURL = URL(string: bannerURLString) {
                detailImage(url: bannerURL, aspectRatio: 16.0 / 9.0)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(alignment: .top, spacing: 14) {
                if let imageURLString = detailResponse?.coverImageURL ?? media.image_url, let imageURL = URL(string: imageURLString) {
                    detailImage(url: imageURL, aspectRatio: 2.0 / 3.0)
                        .frame(width: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.16), radius: 12, y: 8)
                } else {
                    posterPlaceholder
                        .frame(width: 118, height: 177)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(displayTitle)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    if let originalTitle {
                        Text(originalTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(metaLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let status = listEntry?.status {
                        StatusBadge(status: status)
                    }
                }
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
            MetricPill(title: "Score", value: scoreText, color: .pink)
            MetricPill(title: "Rank", value: rankText, color: .cyan)
            MetricPill(title: "Popularity", value: popularityText, color: .mint)
            MetricPill(title: progressLabel, value: progressTotal > 0 ? "\(progressTotal)" : "-", color: .orange)
        }
    }

    @ViewBuilder
    private var trackingSummary: some View {
        if let listEntry {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Progress")
                    .font(.headline)

                HStack(spacing: 10) {
                    MetricPill(title: "Progress", value: progressText(for: listEntry), color: .cyan)
                    MetricPill(title: "Rating", value: listEntry.score10.map { String(format: "%.1f", $0) } ?? "-", color: .pink)
                    MetricPill(title: "Favorite", value: listEntry.favorite ? "Yes" : "No", color: .mint)
                }
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Details")
                    .font(.headline)
                if isLoadingDetails {
                    ProgressView()
                        .scaleEffect(0.75)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                factTile(title: "Format", value: nonEmpty(media.type, fallback: media.media_type?.capitalized ?? "-"))
                factTile(title: media.media_type == "manga" ? "Published" : "Aired", value: detailDateText)
                if media.media_type == "manga" {
                    factTile(title: "Chapters", value: formattedCount(detailChapters))
                    factTile(title: "Volumes", value: formattedCount(detailVolumes))
                } else {
                    factTile(title: "Source", value: detailSource)
                    factTile(title: "Duration", value: detailDuration)
                }
                factTile(title: "Members", value: formattedCount(detailMembersCount))
                factTile(title: "Favorites", value: formattedCount(detailFavoritesCount))
                factTile(title: "Scored By", value: formattedCount(detailScoredBy))
            }

            if let detailErrorMessage {
                Text(detailErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var genres: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Genres")
                .font(.headline)

            if let genres = media.genres, !genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genres, id: \.name) { genre in
                            Text(genre.name)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.14), in: Capsule())
                                .foregroundStyle(Color.cyan)
                        }
                    }
                }
            } else {
                Text("No genres available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var alternateTitles: some View {
        let titles = detailResponse?.titles ?? media.raw?.titles ?? []
        if !titles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Titles")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(titles) { title in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(title.type)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 82, alignment: .leading)
                            Text(title.title)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var productionInfo: some View {
        let rows = productionRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(media.media_type == "manga" ? "Publication" : "Production")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(rows, id: \.title) { row in
                        HStack(alignment: .top, spacing: 10) {
                            Text(row.title)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 88, alignment: .leading)
                            Text(row.value)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var synopsis: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synopsis")
                .font(.headline)
            Text(nonEmpty(media.synopsis, fallback: "No synopsis available."))
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var backgroundInfo: some View {
        let background = nonEmpty(media.raw?.background, fallback: "")
        if !background.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Background")
                    .font(.headline)
                Text(background)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var relations: some View {
        if let relationGroups = detailResponse?.relations, !relationGroups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Related")
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(relationGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.relation)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(group.entries) { entry in
                                        RelationCard(entry: entry)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var characters: some View {
        if let characters = detailResponse?.characters, !characters.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Characters")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(characters.prefix(12)) { character in
                            CharacterCard(character: character)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var themeSongs: some View {
        if let themes = detailResponse?.themes, !themes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Theme Songs")
                    .font(.headline)

                if !themes.openings.isEmpty {
                    songList(title: "Openings", songs: themes.openings)
                }
                if !themes.endings.isEmpty {
                    songList(title: "Endings", songs: themes.endings)
                }
            }
        }
    }

    @ViewBuilder
    private var externalLinks: some View {
        let links = detailResponse?.external ?? media.raw?.external ?? []
        let streaming = detailResponse?.streaming ?? media.raw?.streaming ?? []
        if !links.isEmpty || !streaming.isEmpty || detailResponse?.url != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("Links")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let urlString = detailResponse?.url, let url = URL(string: urlString) {
                            Button("MyAnimeList") { UniversalLinkOpener.open(url) }
                                .buttonStyle(.bordered)
                        }
                        ForEach(streaming.prefix(4)) { link in
                            if let url = URL(string: link.url) {
                                Button(link.name) { UniversalLinkOpener.open(url) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        ForEach(links.prefix(4)) { link in
                            if let url = URL(string: link.url) {
                                Button(link.name) { UniversalLinkOpener.open(url) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if let mediaType = media.media_type?.capitalized {
            parts.append(mediaType)
        } else if let type = media.type, !type.isEmpty {
            parts.append(type)
        }
        if let year = media.year, year > 0 {
            parts.append(String(year))
        }
        if let season = media.season, !season.isEmpty {
            parts.append(season.capitalized)
        }
        if let status = media.status, !status.isEmpty {
            parts.append(status)
        }
        if let rating = media.rating, !rating.isEmpty {
            parts.append(rating)
        }
        return parts.joined(separator: " • ")
    }

    private var scoreText: String {
        if let score = media.asunatracks_score?.rating {
            return String(format: "%.1f", score)
        }
        if let score = media.score {
            return String(format: "%.1f", score)
        }
        return "-"
    }

    private var rankText: String {
        guard let rank = media.rank, rank > 0 else { return "-" }
        return "#\(rank)"
    }

    private var popularityText: String {
        guard let popularity = media.popularity, popularity > 0 else { return "-" }
        return "#\(popularity)"
    }

    private var detailSource: String {
        nonEmpty(detailResponse?.source ?? media.raw?.source, fallback: "-")
    }

    private var detailDuration: String {
        nonEmpty(detailResponse?.duration ?? media.raw?.duration, fallback: "-")
    }

    private var detailDateText: String {
        let rawDate = media.media_type == "manga" ? media.raw?.published?.string : media.raw?.aired?.string
        if let rawDate = rawDate, !rawDate.isEmpty {
            return rawDate
        }
        if let startDate = media.start_date, !startDate.isEmpty {
            if let endDate = media.end_date, !endDate.isEmpty {
                return "\(shortDate(startDate)) to \(shortDate(endDate))"
            }
            return shortDate(startDate)
        }
        return "-"
    }

    private var detailChapters: Int? {
        media.chapters.flatMap { $0 > 0 ? $0 : nil } ?? media.raw?.chapters
    }

    private var detailVolumes: Int? {
        media.volumes.flatMap { $0 > 0 ? $0 : nil } ?? media.raw?.volumes
    }

    private var detailMembersCount: Int? {
        detailResponse?.membersCount ?? media.raw?.members
    }

    private var detailFavoritesCount: Int? {
        detailResponse?.favoritesCount ?? media.raw?.favorites
    }

    private var detailScoredBy: Int? {
        detailResponse?.scoredBy ?? media.raw?.scored_by
    }

    private var productionRows: [(title: String, value: String)] {
        var rows: [(title: String, value: String)] = []
        appendResources(&rows, title: "Studios", resources: detailResponse?.studios ?? media.raw?.studios)
        appendResources(&rows, title: "Producers", resources: detailResponse?.producers ?? media.raw?.producers)
        appendResources(&rows, title: "Licensors", resources: detailResponse?.licensors ?? media.raw?.licensors)
        appendResources(&rows, title: "Authors", resources: detailResponse?.authors ?? media.raw?.authors)
        appendResources(&rows, title: "Serializations", resources: detailResponse?.serializations ?? media.raw?.serializations)
        return rows
    }

    private func progressText(for entry: MyListEntry) -> String {
        let current = entry.progress ?? 0
        if progressTotal > 0 {
            return "\(current)/\(progressTotal)"
        }
        return "\(current)"
    }

    private func nonEmpty(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func formattedCount(_ value: Int?) -> String {
        guard let value, value > 0 else { return "-" }
        return value.formatted()
    }

    private func shortDate(_ value: String) -> String {
        value.components(separatedBy: "T").first ?? value
    }

    private func appendResources(_ rows: inout [(title: String, value: String)], title: String, resources: [MediaNamedResource]?) {
        let names = resources?.map(\.name).filter { !$0.isEmpty } ?? []
        if !names.isEmpty {
            rows.append((title: title, value: names.joined(separator: ", ")))
        }
    }

    private func factTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(nonEmpty(value, fallback: "-"))
                .font(.subheadline.bold())
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func songList(title: String, songs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            ForEach(Array(songs.prefix(4).enumerated()), id: \.offset) { _, song in
                Text(song)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func loadDetails() async {
        guard let mediaType = item.media_type, mediaType == "anime" || mediaType == "manga" else { return }
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        do {
            let url = URL(string: "https://asunatracks.space/public/api/\(mediaType)/\(item.id)")!
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            detailResponse = try JSONDecoder().decode(MediaDetailResponse.self, from: data)
            detailErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            detailErrorMessage = "More details could not be loaded."
        }
    }

    private func detailImage(url: URL, aspectRatio: CGFloat) -> some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                case .failure:
                    posterPlaceholder
                @unknown default:
                    posterPlaceholder
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

struct MediaDetailResponse: Decodable {
    let media: ContentView.Anime
    let relations: [MediaRelation]?
    let characters: [MediaCharacter]?
    let themes: MediaThemes?
    let external: [MediaLink]?
    let streaming: [MediaLink]?
    let titles: [MediaTitle]?
    let coverImageURL: String?
    let studios: [MediaNamedResource]?
    let producers: [MediaNamedResource]?
    let licensors: [MediaNamedResource]?
    let authors: [MediaNamedResource]?
    let serializations: [MediaNamedResource]?
    let source: String?
    let duration: String?
    let url: String?
    let favoritesCount: Int?
    let membersCount: Int?
    let scoredBy: Int?

    enum CodingKeys: String, CodingKey {
        case media
        case relations
        case characters
        case themes
        case external
        case streaming
        case titles
        case coverImageURL = "cover_image_url"
        case studios
        case producers
        case licensors
        case authors
        case serializations
        case source
        case duration
        case url
        case favoritesCount = "favorites_count"
        case membersCount = "members_count"
        case scoredBy = "scored_by"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        media = try container.decode(ContentView.Anime.self, forKey: .media)
        relations = try? container.decode([MediaRelation].self, forKey: .relations)
        characters = try? container.decode([MediaCharacter].self, forKey: .characters)
        themes = try? container.decode(MediaThemes.self, forKey: .themes)
        external = try? container.decode([MediaLink].self, forKey: .external)
        streaming = try? container.decode([MediaLink].self, forKey: .streaming)
        titles = try? container.decode([MediaTitle].self, forKey: .titles)
        coverImageURL = try? container.decode(String.self, forKey: .coverImageURL)
        studios = try? container.decode([MediaNamedResource].self, forKey: .studios)
        producers = try? container.decode([MediaNamedResource].self, forKey: .producers)
        licensors = try? container.decode([MediaNamedResource].self, forKey: .licensors)
        authors = try? container.decode([MediaNamedResource].self, forKey: .authors)
        serializations = try? container.decode([MediaNamedResource].self, forKey: .serializations)
        source = try? container.decode(String.self, forKey: .source)
        duration = try? container.decode(String.self, forKey: .duration)
        url = try? container.decode(String.self, forKey: .url)
        favoritesCount = try? container.decode(Int.self, forKey: .favoritesCount)
        membersCount = try? container.decode(Int.self, forKey: .membersCount)
        scoredBy = try? container.decode(Int.self, forKey: .scoredBy)
    }
}

struct MediaRelation: Identifiable, Decodable {
    let relation: String
    let entries: [MediaRelationEntry]

    var id: String {
        relation + entries.map { "\($0.id)" }.joined(separator: "-")
    }
}

struct MediaRelationEntry: Identifiable, Decodable {
    let id: Int
    let malID: Int?
    let type: String?
    let name: String
    let url: String?
    let imageURL: String?
    let mediaType: String?
    let titleEnglish: String?

    enum CodingKeys: String, CodingKey {
        case id
        case malID = "mal_id"
        case type
        case name
        case url
        case imageURL = "image_url"
        case mediaType = "media_type"
        case titleEnglish = "title_english"
    }
}

struct MediaCharacter: Identifiable, Decodable {
    let id: Int
    let malID: Int?
    let name: String
    let nameKanji: String?
    let imageURL: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case id
        case malID = "mal_id"
        case name
        case nameKanji = "name_kanji"
        case imageURL = "image_url"
        case role
    }
}

struct MediaThemes: Decodable {
    let openings: [String]
    let endings: [String]

    enum CodingKeys: String, CodingKey {
        case openings
        case endings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        openings = (try? container.decode([String].self, forKey: .openings)) ?? []
        endings = (try? container.decode([String].self, forKey: .endings)) ?? []
    }

    var isEmpty: Bool {
        openings.isEmpty && endings.isEmpty
    }
}

struct MediaTitle: Identifiable, Decodable {
    let type: String
    let title: String

    var id: String { type + title }
}

struct MediaLink: Identifiable, Decodable {
    let name: String
    let url: String

    var id: String { name + url }
}

struct MediaNamedResource: Identifiable, Decodable {
    let malID: Int?
    let name: String
    let url: String?

    var id: String {
        "\(malID ?? 0)-\(name)"
    }

    enum CodingKeys: String, CodingKey {
        case malID = "mal_id"
        case name
        case url
    }
}

struct RelationCard: View {
    let entry: MediaRelationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            relationImage
                .frame(width: 88, height: 124)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(entry.titleEnglish?.isEmpty == false ? entry.titleEnglish! : entry.name)
                .font(.caption.bold())
                .lineLimit(2)
                .frame(width: 88, alignment: .leading)

            if let type = entry.mediaType ?? entry.type {
                Text(type.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 88, alignment: .topLeading)
    }

    @ViewBuilder
    private var relationImage: some View {
        if let imageURL = entry.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    imagePlaceholder
                @unknown default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }
}

struct CharacterCard: View {
    let character: MediaCharacter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            characterImage
                .frame(width: 78, height: 78)
                .clipped()
                .clipShape(Circle())

            Text(character.name)
                .font(.caption.bold())
                .lineLimit(2)
                .frame(width: 96, alignment: .leading)

            if let role = character.role {
                Text(role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 96, alignment: .topLeading)
    }

    @ViewBuilder
    private var characterImage: some View {
        if let imageURL = character.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    imagePlaceholder
                @unknown default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "person")
                .foregroundStyle(.secondary)
        }
    }
}

enum SearchMediaType: String, CaseIterable, Identifiable {
    case anime
    case manga

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anime: "Anime"
        case .manga: "Manga"
        }
    }

    var endpoint: String {
        switch self {
        case .anime: "https://asunatracks.space/public/api/anime"
        case .manga: "https://asunatracks.space/public/api/manga"
        }
    }
}

struct SearchView: View {
    @State private var mediaType: SearchMediaType = .anime
    @State private var query = ""
    @State private var items: [ContentView.Anime] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 14)
    ]

    private var searchKey: String {
        "\(mediaType.rawValue)-\(query)"
    }

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                MyListStateView(
                    systemImage: "magnifyingglass",
                    title: "Search failed",
                    message: errorMessage,
                    retryTitle: "Retry",
                    retry: { Task { await searchNow() } }
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(items) { item in
                            SearchPosterCard(item: item)
                        }
                    }
                    .padding()

                    if items.isEmpty {
                        MyListStateView(
                            systemImage: "sparkle.magnifyingglass",
                            title: "No matches",
                            message: "Try a different title, synonym, or genre."
                        )
                        .frame(minHeight: 260)
                    }
                }
                .refreshable {
                    await searchNow()
                }
            }
        }
        .navigationTitle("Search")
        .safeAreaInset(edge: .top) {
            Picker("Type", selection: $mediaType) {
                ForEach(SearchMediaType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search titles")
        .background(Color(.systemBackground))
        .task(id: searchKey) {
            if !query.isEmpty {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard !Task.isCancelled else { return }
            await searchNow()
        }
    }

    private func searchNow() async {
        isLoading = true
        defer { isLoading = false }

        do {
            var components = URLComponents(string: mediaType.endpoint)!
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "50")
            ]

            let (data, response) = try await URLSession.shared.data(from: components.url!)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            if let envelope = try? decoder.decode(ContentView.APIResponse.self, from: data) {
                items = envelope.items
            } else {
                items = try decoder.decode([ContentView.Anime].self, from: data)
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SearchPosterCard: View {
    let item: ContentView.Anime

    var body: some View {
        NavigationLink {
            MediaDetailView(item: item)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    GeometryReader { proxy in
                        poster
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(item.tagText)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }

                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.infoLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var poster: some View {
        if let urlString = item.image_url, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    posterPlaceholder
                @unknown default:
                    posterPlaceholder
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private var displayTitle: String {
        item.title_english?.isEmpty == false ? item.title_english! : item.title
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case anime
    case manga

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .anime: "Anime"
        case .manga: "Manga"
        }
    }
}

struct MyListResponse: Decodable {
    let type: String?
    let items: [MyListEntry]
}

struct MyListEntry: Identifiable, Decodable {
    let entryID: Int
    let status: String?
    let progress: Int?
    let progressVolumes: Int?
    let score10: Double?
    let rating: Double?
    let favorite: Bool
    let media: ContentView.Anime

    var id: Int { entryID }

    enum CodingKeys: String, CodingKey {
        case entryID = "entry_id"
        case status
        case progress
        case progressEpisodes = "progress_episodes"
        case episodesWatched = "episodes_watched"
        case progressChapters = "progress_chapters"
        case chaptersRead = "chapters_read"
        case progressVolumes = "progress_volumes"
        case volumesRead = "volumes_read"
        case score10 = "score_10"
        case rating
        case favorite
        case media
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entryID = try container.decode(Int.self, forKey: .entryID)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        let progressKeys: [CodingKeys] = [.progress, .progressEpisodes, .episodesWatched, .progressChapters, .chaptersRead]
        var decodedProgress: Int?
        for key in progressKeys where decodedProgress == nil {
            decodedProgress = try container.decodeIfPresent(Int.self, forKey: key)
        }
        progress = decodedProgress
        var decodedVolumes = try container.decodeIfPresent(Int.self, forKey: .progressVolumes)
        if decodedVolumes == nil {
            decodedVolumes = try container.decodeIfPresent(Int.self, forKey: .volumesRead)
        }
        progressVolumes = decodedVolumes
        score10 = try container.decodeIfPresent(Double.self, forKey: .score10)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        favorite = try container.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        media = try container.decode(ContentView.Anime.self, forKey: .media)
    }

    func updatingProgress(_ newProgress: Int) -> MyListEntry {
        MyListEntry(entryID: entryID, status: status, progress: newProgress, progressVolumes: progressVolumes, score10: score10, rating: rating, favorite: favorite, media: media)
    }

    private init(entryID: Int, status: String?, progress: Int?, progressVolumes: Int?, score10: Double?, rating: Double?, favorite: Bool, media: ContentView.Anime) {
        self.entryID = entryID; self.status = status; self.progress = progress; self.progressVolumes = progressVolumes
        self.score10 = score10; self.rating = rating; self.favorite = favorite; self.media = media
    }
}

struct MyListView: View {
    @AppStorage("isUserSignedIn") private var isUserSignedIn: Bool = false

    @State private var filter: LibraryFilter = .all
    @State private var entries: [MyListEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingProgressUpdates: [Int: Task<Void, Never>] = [:]

    private var isSignedIn: Bool {
        isUserSignedIn && KeychainVault.readToken() != nil
    }

    private var filteredEntries: [MyListEntry] {
        switch filter {
        case .all:
            entries
        case .anime:
            entries.filter { $0.media.media_type == "anime" }
        case .manga:
            entries.filter { $0.media.media_type == "manga" }
        }
    }

    var body: some View {
        Group {
            if !isSignedIn {
                MyListStateView(
                    systemImage: "person.crop.circle.badge.plus",
                    title: "Sign in to see your list",
                    message: "Your AsunaTracks progress list appears here after you sign in from the Profile tab."
                )
            } else if isLoading && entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                MyListStateView(
                    systemImage: "books.vertical",
                    title: "My List unavailable",
                    message: errorMessage,
                    retryTitle: "Retry",
                    retry: { Task { await loadList() } }
                )
            } else if filteredEntries.isEmpty {
                MyListStateView(
                    systemImage: "plus.rectangle.on.rectangle",
                    title: "No tracked titles yet",
                    message: "Open a title from Discover and save it to your AsunaTracks list."
                )
            } else {
                List {
                    Section {
                        myListSummary(filteredEntries)
                    }
                    .listRowBackground(Color.clear)

                    Section {
                        ForEach(filteredEntries) { entry in
                            NavigationLink {
                                MediaDetailView(item: entry.media, listEntry: entry)
                            } label: {
                                MyListEntryRow(entry: entry, incrementProgress: { incrementProgress(for: entry.id) })
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .modifier(HiddenScrollContentBackground())
                .refreshable {
                    await loadList()
                }
            }
        }
        .navigationTitle("My List")
        .safeAreaInset(edge: .top) {
            Picker("My List", selection: $filter) {
                ForEach(LibraryFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .background(Color(.systemBackground))
        .task(id: isUserSignedIn) {
            if isSignedIn {
                await loadList()
            } else {
                entries = []
                errorMessage = nil
            }
        }
    }

    private func myListSummary(_ items: [MyListEntry]) -> some View {
        HStack(spacing: 10) {
            MetricPill(title: "Tracked", value: "\(items.count)", color: .cyan)
            MetricPill(title: "Favorites", value: "\(items.filter(\.favorite).count)", color: .pink)
            MetricPill(title: "Completed", value: "\(items.filter { $0.status == "completed" }.count)", color: .mint)
        }
        .padding(.vertical, 4)
    }

    private func loadList() async {
        guard isSignedIn else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var request = URLRequest(url: URL(string: "https://asunatracks.space/public/api/me/list")!)
            request.setValue(authorizationHeaderValue(), forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw NSError(
                    domain: "MyListError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: httpResponse.statusCode == 401 ? "Please sign in again." : "Server returned \(httpResponse.statusCode)."]
                )
            }

            let decoded = try JSONDecoder().decode(MyListResponse.self, from: data)
            entries = decoded.items
            for (mediaID, count) in WidgetListStore.pendingIncrements() {
                guard let entryID = entries.first(where: { $0.media.id == mediaID })?.id else { continue }
                for _ in 0..<count { incrementProgress(for: entryID) }
            }
            WidgetListStore.save(entries: entries)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func authorizationHeaderValue() -> String {
        let token = (KeychainVault.readToken() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") {
            return token
        }
        return "Bearer \(token)"
    }

    private func incrementProgress(for entryID: Int) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let entry = entries[index]
        let current = entry.progress ?? 0
        let maximum = entry.media.media_type == "manga" ? (entry.media.chapters ?? 0) : (entry.media.episodes ?? 0)
        guard maximum == 0 || current < maximum else { return }

        let updated = entry.updatingProgress(current + 1)
        entries[index] = updated
        pendingProgressUpdates[entryID]?.cancel()
        pendingProgressUpdates[entryID] = Task {
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            await saveProgress(for: updated)
        }
    }

    private func saveProgress(for entry: MyListEntry) async {
        guard let type = entry.media.media_type, let url = URL(string: "https://asunatracks.space/public/api/me/list") else { return }
        var payload: [String: Any] = ["media_type": type, "media_id": entry.media.id, "status": entry.status ?? (type == "manga" ? "reading" : "watching")]
        payload[type == "manga" ? "progress_chapters" : "progress_episodes"] = entry.progress ?? 0
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(authorizationHeaderValue(), forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            WidgetListStore.save(entries: entries)
            WidgetListStore.clearPendingIncrement(for: entry.media.id)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Progress could not be saved."
            await loadList()
        }
    }
}

struct MyListEntryRow: View {
    let entry: MyListEntry
    let incrementProgress: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            poster
                .frame(width: 56, height: 78)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(displayTitle)
                        .font(.headline)
                        .lineLimit(2)
                    if entry.favorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                    }
                }

                HStack(spacing: 8) {
                    StatusBadge(status: entry.status ?? "planning")
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let score = entry.score10 ?? entry.rating {
                    Label(String(format: "%.1f", score), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.pink)
                }
            }
            Spacer(minLength: 4)
            Divider().frame(height: 52)
            Button(action: incrementProgress) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add one \(entry.media.media_type == "manga" ? "chapter" : "episode")")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var poster: some View {
        if let urlString = entry.media.image_url, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    posterPlaceholder
                @unknown default:
                    posterPlaceholder
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }

    private var displayTitle: String {
        entry.media.title_english?.isEmpty == false ? entry.media.title_english! : entry.media.title
    }

    private var progressText: String {
        let current = entry.progress ?? 0
        let total = entry.media.media_type == "manga" ? (entry.media.chapters ?? 0) : (entry.media.episodes ?? 0)
        let label = entry.media.media_type == "manga" ? "chapters" : "episodes"
        if total > 0 {
            return "\(current)/\(total) \(label)"
        }
        return "\(current) \(label)"
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.24))
        )
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(statusText)
            .font(.caption2.bold())
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.14), in: Capsule())
    }

    private var statusText: String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var statusColor: Color {
        switch status {
        case "completed": .mint
        case "watching", "reading": .cyan
        case "paused": .orange
        case "dropped": .red
        default: .secondary
        }
    }
}

struct MyListStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var retryTitle: String?
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if let retryTitle, let retry {
                Button(retryTitle, action: retry)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

typealias ScreenStateView = MyListStateView

struct HiddenScrollContentBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

#if os(iOS)
struct ProfileView: View {
    let colorScheme: ColorScheme
    @Binding var selectedTab: AppTab
    
    @AppStorage("isUserSignedIn") private var isUserSignedIn: Bool = false
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
                    if !isUserSignedIn {
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
                            KeychainVault.deleteToken()
                            isUserSignedIn = false
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
                        if isUserSignedIn {
                            Button { WatchLinkManager.shared.linkExternalDevice() } label: {
                                row(icon: "applewatch", title: "Link External Device")
                            }
                        }
                        Button {
                            selectedTab = .myList
                        } label: {
                            row(icon: "bookmark", title: "My List")
                        }
                        
                        Button {
                            selectedTab = .search
                        } label: {
                            row(icon: "magnifyingglass", title: "Search")
                        }
                        
                        Button {
                            selectedTab = .seasons
                        } label: {
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
                                     isSignedIn: $isUserSignedIn,
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
                                     isSignedIn: $isUserSignedIn,
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
        @Binding var isSignedIn: Bool
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
                    guard let token = dict["token"] as? String, KeychainVault.saveToken(token) else { return }
                    if let user = dict["user"] as? [String: Any] {
                        if let username = user["username"] as? String { parent.authUsername = username }
                        if let avatar = user["avatar_url"] as? String { parent.authAvatarURL = avatar }
                    }
                    parent.isSignedIn = true
                    parent.isPresented = false
                }
            }
        }
    }
}

#else
struct ProfileView: View {
    let colorScheme: ColorScheme
    @Binding var selectedTab: AppTab
    var body: some View {
        ContentUnavailableView("Profile is available on iPhone", systemImage: "person.crop.circle")
    }
}
#endif

#Preview {
    ContentView()
}
#else
enum AppTab: Hashable { case discover, search, seasons, myList, profile }
struct ContentView: View { var body: some View { ContentUnavailableView("AsunaTracks is available on iPhone", systemImage: "iphone") } }
#endif

