import SwiftUI

// Quartzsite Campfire for iPhone: ads, guide, shows, alerts and map, all read from the live site.
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
    static let primary = Color(red: 10 / 255, green: 111 / 255, blue: 105 / 255)
    static let accent = Color(red: 194 / 255, green: 67 / 255, blue: 26 / 255)
    static let soft = Color(red: 222 / 255, green: 238 / 255, blue: 234 / 255)
    static let page = Color(red: 236 / 255, green: 232 / 255, blue: 225 / 255)
    static let card = Color(red: 254 / 255, green: 252 / 255, blue: 247 / 255)
}

// The five tabs. The build's own screenshots pick a tab with a launch argument such as -demo-guide.
struct RootView: View {
    @StateObject private var guide = GuideStore()
    @State private var tab: String = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demo-areamap") { return "guide" }
        for t in ["guide", "shows", "alerts", "map"] where args.contains("-demo-" + t) { return t }
        return "sale"
    }()

    var body: some View {
        TabView(selection: $tab) {
            ForSaleView().tabItem { Label("For Sale", systemImage: "tag") }.tag("sale")
            GuideView().tabItem { Label("Guide", systemImage: "book") }.tag("guide")
            ShowsView().tabItem { Label("Shows", systemImage: "calendar") }.tag("shows")
            AlertsView().tabItem { Label("Alerts", systemImage: "bell") }.tag("alerts")
            PlacesView().tabItem { Label("Map", systemImage: "map") }.tag("map")
        }
        .environmentObject(guide)
        .task { await guide.load() }
    }
}
