import SwiftUI

// Posts this phone's owner reported. They stay hidden on this phone.
enum Hidden {
    static let name = "hiddenIds"
    static func has(_ raw: String, _ id: String) -> Bool { raw.split(separator: ",").contains(Substring(id)) }
    static func add(_ id: String) {
        var all = (UserDefaults.standard.string(forKey: name) ?? "").split(separator: ",").map(String.init)
        if !all.contains(id) { all.append(id) }
        UserDefaults.standard.set(all.suffix(500).joined(separator: ","), forKey: name)
    }
}

// Ads posted from this phone that are still waiting for the emailed link to be tapped.
struct WaitingAd: Codable, Identifiable {
    let id: String
    let title: String
    let email: String
    let ts: Double
}

enum Waiting {
    static let name = "waitingAds"
    static func list(_ raw: String) -> [WaitingAd] {
        (try? JSONDecoder().decode([WaitingAd].self, from: Data(raw.utf8))) ?? []
    }
    static func save(_ ads: [WaitingAd]) {
        let data = (try? JSONEncoder().encode(Array(ads.suffix(10)))) ?? Data()
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: name)
    }
    static func add(id: String, title: String, email: String) {
        save(list(UserDefaults.standard.string(forKey: name) ?? "") + [WaitingAd(id: id, title: title, email: email, ts: Date().timeIntervalSince1970)])
    }
    static func remove(_ id: String) {
        save(list(UserDefaults.standard.string(forKey: name) ?? "").filter { $0.id != id })
    }
    // Drops the ones that are now published, and any older than a week.
    static func tidy(published: [String]) {
        let all = list(UserDefaults.standard.string(forKey: name) ?? "")
        let keep = all.filter { !published.contains($0.id) && $0.ts > Date().timeIntervalSince1970 - 7 * 86400 }
        if keep.count != all.count { save(keep) }
    }
}

// The rules, privacy, terms and how to reach the owner.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Havasu Campfire is a free guide, map, question board and classifieds for winter visitors around Lake Havasu City, Arizona. It is the sister app of Quartzsite Campfire. It is run by one person. There are no accounts and no passwords.")
                }
                Section("Rules for posting") {
                    Text("Be kind. No harassment, hate, sexual content, scams or illegal items.")
                    Text("Every post is checked by an automated service.")
                    Text("See something that should not be here? Tap Report on it. It is hidden on your phone at once, reviewed, and removed within 24 hours if it breaks the rules. People who post it can be blocked.")
                }
                Section("Your privacy") {
                    Text("Your email is never shown, sold or shared. Where am I uses your location on this phone only. No advertising and no tracking.")
                    Link("Privacy policy", destination: Site.privacyPage)
                    Link("Terms of use", destination: Site.termsPage)
                }
                Section("Help") {
                    Link("Help and contact", destination: Site.supportPage)
                    Link("Email info@qcampfire.com", destination: URL(string: "mailto:info@qcampfire.com")!)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// A dimmed screen with a spinner and a few words, shown while something is being sent so the tap is clearly taken.
struct BusyOverlay: ViewModifier {
    let on: Bool
    let words: String
    func body(content: Content) -> some View {
        content
            .overlay {
                if on {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView().controlSize(.large)
                            Text(words).font(.headline)
                        }
                        .padding(28)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: on)
            .interactiveDismissDisabled(on)
    }
}

extension View {
    func busy(_ on: Bool, _ words: String) -> some View { modifier(BusyOverlay(on: on, words: words)) }
}
