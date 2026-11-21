import SwiftUI

// Quartzsite Campfire, native trial: the For Sale list and the ad screen, read from the live site.
@main
struct CampfireApp: App {
    var body: some Scene {
        WindowGroup {
            ForSaleView()
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
