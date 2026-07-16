//
//  OnboardingView.swift
//  AsunaTracks
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)

// MARK: - Tab Order Persistence

struct TabOrderStore {
    static let key = "tabOrder"
    static let defaultOrder = ["search", "seasons", "myList"]

    static func load() -> [String] {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        let ids = raw.split(separator: ",").map(String.init)
        let valid = Set(defaultOrder)
        if Set(ids) == valid, ids.count == valid.count { return ids }
        return defaultOrder
    }

    static func save(_ ids: [String]) {
        UserDefaults.standard.set(ids.joined(separator: ","), forKey: key)
    }
}

// MARK: - Tab Item Model

struct TabItem: Identifiable, Equatable {
    let id: String
    let label: String
    let systemImage: String
    let isLocked: Bool

    static let discover = TabItem(id: "discover", label: "Discover", systemImage: "house.fill",        isLocked: true)
    static let search   = TabItem(id: "search",   label: "Search",   systemImage: "magnifyingglass",    isLocked: false)
    static let seasons  = TabItem(id: "seasons",  label: "Seasons",  systemImage: "calendar",           isLocked: false)
    static let myList   = TabItem(id: "myList",   label: "My List",  systemImage: "bookmark",           isLocked: false)
    static let profile  = TabItem(id: "profile",  label: "Profile",  systemImage: "person.crop.circle", isLocked: true)

    static let all: [TabItem] = [.discover, .search, .seasons, .myList, .profile]

    static func from(id: String) -> TabItem {
        all.first { $0.id == id } ?? .search
    }

    static func ordered(midSlots: [String]) -> [TabItem] {
        [.discover] + midSlots.map { from(id: $0) } + [.profile]
    }
}

// MARK: - Onboarding Page Model

private struct OnboardingPage: Identifiable {
    let id: Int
    let systemImage: String
    let accent: Color
    let title: String
    let body: String
    var showsCustomizer: Bool = false
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        systemImage: "sparkles",
        accent: Color(red: 0.43, green: 0.49, blue: 1.0),
        title: "Welcome to\nAsunaTracks",
        body: "Your personal hub for anime and manga — discover titles, track your progress, and build a list that's entirely yours."
    ),
    OnboardingPage(
        id: 1,
        systemImage: "rectangle.grid.2x2.fill",
        accent: Color(red: 0.22, green: 0.78, blue: 0.71),
        title: "Discover &\nExplore",
        body: "Browse popular anime and manga, filter by genre, and dive into rich detail pages with characters, themes, and more."
    ),
    OnboardingPage(
        id: 2,
        systemImage: "bookmark.fill",
        accent: Color(red: 1.0, green: 0.44, blue: 0.60),
        title: "Track Your\nProgress",
        body: "Save titles to My List, mark episodes or chapters as you go, leave ratings, and keep favorites close at hand."
    ),
    OnboardingPage(
        id: 3,
        systemImage: "square.grid.3x1.below.line.grid.1x2.fill",
        accent: Color(red: 0.55, green: 0.85, blue: 0.55),
        title: "Your Nav,\nYour Way",
        body: "Hold a tab for 1 second, then drag it to reorder. Discover and Profile stay pinned — everything else is yours.",
        showsCustomizer: true
    ),
    OnboardingPage(
        id: 4,
        systemImage: "person.crop.circle.fill",
        accent: Color(red: 0.99, green: 0.72, blue: 0.25),
        title: "Sync with\nYour Account",
        body: "Sign in to sync your list across devices and unlock your full AsunaTracks profile. You can also skip and browse freely."
    ),
]

// MARK: - OnboardingView

struct OnboardingView: View {

    // false = always show (dev mode). true = persist to AppStorage and never show again.
    private let shouldPersistSetup: Bool = true

    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    @AppStorage("isUserSignedIn")    private var isUserSignedIn:     Bool = false
    @AppStorage("authUsername")      private var authUsername:        String = ""
    @AppStorage("authAvatarURL")     private var authAvatarURL:       String = ""

    @State private var currentPage:   Int    = 0
    @State private var showSignIn:    Bool   = false
    @State private var animateTabBar: Bool   = false

    // Tab customizer — persisted immediately on every drag
    @State private var tabOrder:      [String] = TabOrderStore.load()
    // Which row is being dragged (nil = none)
    @State private var draggingID:    String?  = nil
    // Which row is showing the "lift" highlight (long-press active)
    @State private var liftedID:      String?  = nil

    @Environment(\.colorScheme) private var colorScheme

    private var isLastPage: Bool { currentPage == onboardingPages.count - 1 }
    private var isSignedIn: Bool { isUserSignedIn }

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(onboardingPages) { page in
                        pageCard(page).tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                dotIndicator
                    .padding(.bottom, 28)

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .onChange(of: isUserSignedIn) { signedIn in
            if signedIn {
                showSignIn = false
                finishSetup()
            }
        }
        .onChange(of: currentPage) { _ in
            if onboardingPages[currentPage].showsCustomizer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                        animateTabBar = true
                    }
                }
            } else {
                animateTabBar = false
            }
        }
        .sheet(isPresented: $showSignIn) { signInSheet }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            (colorScheme == .dark
             ? Color(red: 0.07, green: 0.07, blue: 0.09)
             : Color(red: 0.97, green: 0.97, blue: 0.99))
                .ignoresSafeArea()

            Circle()
                .fill(onboardingPages[currentPage].accent.opacity(colorScheme == .dark ? 0.15 : 0.08))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(y: -60)
                .animation(.easeInOut(duration: 0.55), value: currentPage)
        }
    }

    // MARK: - Dot indicator

    private var dotIndicator: some View {
        HStack(spacing: 8) {
            ForEach(onboardingPages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage
                          ? onboardingPages[currentPage].accent
                          : Color.secondary.opacity(0.3))
                    .frame(width: i == currentPage ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
            }
        }
    }

    // MARK: - Page card

    @ViewBuilder
    private func pageCard(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer()

            if page.showsCustomizer {
                embeddedTabCustomizer(accent: page.accent)
                    .padding(.bottom, 20)
            } else {
                iconBadge(page: page)
                    .padding(.bottom, 36)

                Text(page.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 14)

                Text(page.body)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func iconBadge(page: OnboardingPage) -> some View {
        ZStack {
            Circle().fill(page.accent.opacity(0.15)).frame(width: 120, height: 120)
            Circle().fill(page.accent.opacity(0.22)).frame(width: 90, height: 90)
            Image(systemName: page.systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(page.accent)
        }
    }

    // MARK: - Embedded Tab Customizer (page 3)

    @ViewBuilder
    private func embeddedTabCustomizer(accent: Color) -> some View {
        let previewTabs = TabItem.ordered(midSlots: tabOrder)

        VStack(spacing: 0) {
            Text(onboardingPages[3].title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

            Text(onboardingPages[3].body)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.bottom, 20)

            // Live liquid glass pill — updates as rows are dragged
            liquidGlassPill(tabs: previewTabs, accent: accent)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Drag-to-reorder rows
            VStack(spacing: 1) {
                ForEach(previewTabs) { tab in
                    reorderRow(tab: tab, accent: accent)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)

            // Hint label
            HStack(spacing: 4) {
                Image(systemName: "hand.point.up.left")
                    .font(.caption2)
                Text("Hold 1 sec then drag to reorder")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
            .padding(.top, 8)

            // Reset
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    tabOrder = TabOrderStore.defaultOrder
                }
                TabOrderStore.save(TabOrderStore.defaultOrder)
            } label: {
                Text("Reset to Default")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Liquid glass pill

    private func liquidGlassPill(tabs: [TabItem], accent: Color) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let isActive = tab.id == "discover"
                VStack(spacing: 3) {
                    ZStack {
                        if isActive {
                            Capsule()
                                .fill(accent.opacity(0.20))
                                .frame(width: 40, height: 26)
                                .scaleEffect(animateTabBar ? 1.0 : 0.4)
                                .opacity(animateTabBar ? 1.0 : 0.0)
                        }
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? accent : Color.secondary.opacity(0.55))
                            .scaleEffect(animateTabBar ? 1.0 : 0.6)
                            .opacity(animateTabBar ? 1.0 : 0.0)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.68)
                                .delay(Double(index) * 0.06),
                                value: animateTabBar
                            )
                    }
                    Text(tab.label)
                        .font(.system(size: 8, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? accent : Color.secondary.opacity(0.55))
                        .opacity(animateTabBar ? 1.0 : 0.0)
                        .offset(y: animateTabBar ? 0 : 4)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.68)
                            .delay(0.1 + Double(index) * 0.06),
                            value: animateTabBar
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(glassBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.20 : 0.60),
                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.10), radius: 14, y: 5)
        .offset(y: animateTabBar ? 0 : 16)
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: animateTabBar)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tabOrder)
    }

    // MARK: - Reorder row
    // Uses a 1-second long press to activate drag, giving users a clear handle.

    @ViewBuilder
    private func reorderRow(tab: TabItem, accent: Color) -> some View {
        let isLifted = liftedID == tab.id

        HStack(spacing: 14) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tab.isLocked
                          ? Color.secondary.opacity(0.10)
                          : accent.opacity(isLifted ? 0.25 : 0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: tab.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tab.isLocked ? Color.secondary : accent)
            }

            Text(tab.label)
                .font(.body)
                .foregroundStyle(tab.isLocked ? .secondary : .primary)

            Spacer()

            if tab.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                // Drag handle — animated when lifted
                Image(systemName: isLifted ? "line.3.horizontal" : "line.3.horizontal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isLifted ? accent : Color.secondary.opacity(0.4))
                    .scaleEffect(isLifted ? 1.15 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isLifted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(isLifted
                      ? (colorScheme == .dark ? Color(red: 0.20, green: 0.20, blue: 0.28) : Color(red: 0.93, green: 0.93, blue: 1.0))
                      : (colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.16) : Color.white))
        )
        .opacity(tab.isLocked ? 0.6 : 1.0)
        .scaleEffect(isLifted ? 1.02 : 1.0)
        .shadow(color: isLifted ? accent.opacity(0.18) : .clear, radius: 8, y: 3)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isLifted)
        .zIndex(isLifted ? 1 : 0)
        // 1-second long press activates drag mode
        .onLongPressGesture(minimumDuration: tab.isLocked ? 99 : 1.0) {
            // Long press completed — mark as lifted so drag is ready
            withAnimation { liftedID = tab.id }
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
        // Native drag-and-drop (works immediately once long press fires)
        #if !os(tvOS) && !os(watchOS)
        .onDrag {
            guard !tab.isLocked else { return NSItemProvider() }
            draggingID = tab.id
            return NSItemProvider(object: tab.id as NSString)
        }
        .onDrop(
            of: [UTType.plainText],
            delegate: TabReorderDelegate(
                targetTab:    tab,
                tabOrder:     $tabOrder,
                draggingID:   $draggingID,
                liftedID:     $liftedID,
                onCommit:     { TabOrderStore.save(tabOrder) }
            )
        )
        #endif
    }

    private var glassBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.22, blue: 0.28).opacity(0.85),
                    Color(red: 0.15, green: 0.15, blue: 0.20).opacity(0.90),
                ],
                startPoint: .top, endPoint: .bottom
            ))
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [Color.white.opacity(0.75), Color.white.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            ))
        }
    }

    // MARK: - Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        let accent = onboardingPages[currentPage].accent

        if isLastPage {
            VStack(spacing: 12) {
                if isSignedIn {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Signed in as \(authUsername.isEmpty ? "your account" : authUsername)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)
                } else {
                    HStack(spacing: 10) {
                        Button { showSignIn = true } label: {
                            Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(OnboardingAccentButton(accent: accent))

                        Button { finishSetup() } label: {
                            Text("Later")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(OnboardingGhostButton(colorScheme: colorScheme))
                    }
                }

                Button { finishSetup() } label: {
                    Text("Complete Setup")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(OnboardingAccentButton(accent: accent))
            }
        } else {
            HStack(spacing: 10) {
                Button {
                    withAnimation { currentPage = onboardingPages.count - 1 }
                } label: {
                    Text("Skip")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(OnboardingGhostButton(colorScheme: colorScheme))

                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
                .buttonStyle(OnboardingAccentButton(accent: accent))
            }
        }
    }

    // MARK: - Sign-in sheet

    private var signInSheet: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { signInContent }
            } else {
                NavigationView { signInContent }
                    .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }

    private var signInContent: some View {
        ProfileView.InlineHTMLWebView(
            html: ProfileView.signInHTML,
            isSignedIn: $isUserSignedIn,
            authUsername: $authUsername,
            authAvatarURL: $authAvatarURL,
            isPresented: $showSignIn
        )
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: toolbarTrailingPlacement) {
                Button("Done") { showSignIn = false }
            }
        }
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        if #available(iOS 16.0, *) { return .topBarTrailing }
        return .navigationBarTrailing
    }

    // MARK: - Finish

    private func finishSetup() {
        TabOrderStore.save(tabOrder)
        if shouldPersistSetup {
            hasCompletedSetup = true
        } else {
            hasCompletedSetup = true
        }
    }
}

// MARK: - Tab Reorder Delegate

#if !os(tvOS) && !os(watchOS)
struct TabReorderDelegate: DropDelegate {
    let targetTab:  TabItem
    @Binding var tabOrder:   [String]
    @Binding var draggingID: String?
    @Binding var liftedID:   String?
    let onCommit: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard
            !targetTab.isLocked,
            let fromID = draggingID,
            fromID != targetTab.id,
            let fromIndex = tabOrder.firstIndex(of: fromID),
            let toIndex   = tabOrder.firstIndex(of: targetTab.id)
        else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            tabOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
        // Save immediately so every mid-drag state is persisted
        onCommit()
    }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation { liftedID = nil }
        draggingID = nil
        onCommit()
        return true
    }
}
#endif

// MARK: - Button Styles

struct OnboardingAccentButton: ButtonStyle {
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent)
                    .opacity(configuration.isPressed ? 0.75 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct OnboardingGhostButton: ButtonStyle {
    let colorScheme: ColorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.07)
                          : Color.black.opacity(0.05))
                    .opacity(configuration.isPressed ? 0.5 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
#else
struct OnboardingView: View { var body: some View { ContentUnavailableView("Complete setup on iPhone", systemImage: "iphone") } }
#endif

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
}
