import SwiftUI

// Havasu Campfire for iPhone: the sister app of Quartzsite Campfire, for winter visitors around Lake Havasu City.
// Until the Havasu site exists (Site.live) it shows the Guide, Shows and Map from the guide packed inside the app.
@main
struct CampfireApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.primary)
        }
    }
}

// The site's colors.
enum Theme {
    static let primary = Color(red: 11 / 255, green: 106 / 255, blue: 134 / 255)
    static let accent = Color(red: 200 / 255, green: 72 / 255, blue: 28 / 255)
    static let soft = Color(red: 220 / 255, green: 236 / 255, blue: 241 / 255)
    static let page = Color(red: 233 / 255, green: 236 / 255, blue: 236 / 255)
    static let card = Color(red: 254 / 255, green: 252 / 255, blue: 247 / 255)
}

// The five tabs. The build's own screenshots pick a tab with a launch argument such as -demo-guide.
struct RootView: View {
    @StateObject private var guide = GuideStore()
    @State private var tab: String = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demo-areamap") || args.contains("-demo-photos") || args.contains("-demo-camping") { return "guide" }
        for t in ["guide", "shows", "alerts", "map"] where args.contains("-demo-" + t) { return t }
        return Site.live ? "sale" : "guide"
    }()

    // A question nobody has answered yet, shown above every tab. A new one is picked each time the tab changes.
    @State private var asking: String?
    @State private var waitingCount = 0
    @State private var answering = false
    @State private var comparing = false     // the free-versus-permit comparison, opened from any mention of BLM or LTVA
    @State private var stripOff = false      // closed with the X: it stays away until the app is opened again
    @State private var stripShown = false    // it tucks itself away 7.5 seconds after each tab change

    private func pickQuestion() async {
        guard Site.live, let all = try? await Site.questions() else { return }
        let open = all.filter { $0.answers.isEmpty && !$0.waiting }
        waitingCount = open.count
        asking = open.randomElement()?.text
    }

    var body: some View {
        VStack(spacing: 0) {
            if let q = asking, stripShown, !stripOff {
                HStack(spacing: 0) {
                Button {
                    answering = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("A camper is asking: \u{201C}\(q)\u{201D}")
                            .font(.footnote.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                        Text(waitingCount > 1 ? "Can you answer? \(waitingCount - 1) more waiting" : "Can you answer?")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .foregroundColor(Theme.primary)
                }
                .buttonStyle(.plain)
                Button { stripOff = true } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(Theme.primary.opacity(0.7)).padding(.trailing, 12) }
                    .accessibilityLabel("Close")
                }
                .background(Theme.soft.ignoresSafeArea(edges: .top))
                .transition(.opacity)
            }
        TabView(selection: $tab) {
            if Site.live { ForSaleView().tabItem { Label("For Sale", systemImage: "tag") }.tag("sale") }
            GuideView().tabItem { Label("Guide", systemImage: "book") }.tag("guide")
            ShowsView().tabItem { Label("Shows", systemImage: "calendar") }.tag("shows")
            if Site.live { AlertsView().tabItem { Label("Alerts", systemImage: "bell") }.tag("alerts") }
            PlacesView().tabItem { Label("Map", systemImage: "map") }.tag("map")
        }
        }
        .environmentObject(guide)
        .task { await guide.load() }
        .onReceive(NotificationCenter.default.publisher(for: LandAsk.note)) { _ in tab = "map" }
        .onReceive(NotificationCenter.default.publisher(for: CampWords.note)) { _ in comparing = true }
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "campfire" { comparing = true; return .handled }
            return .systemAction
        })
        .sheet(isPresented: $comparing) { CompareView() }
        .task(id: tab) {
            if stripOff { return }
            await pickQuestion()
            withAnimation { stripShown = true }
            try? await Task.sleep(nanoseconds: 7_500_000_000)
            withAnimation { stripShown = false }
            stripOff = true      // shown once each time the app is opened, not on every tab
        }
        .sheet(isPresented: $answering, onDismiss: { Task { await pickQuestion() } }) {
            NavigationStack {
                QuestionsView(startOpen: true)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { answering = false } } }
            }
            .environmentObject(guide)
        }
    }
}
