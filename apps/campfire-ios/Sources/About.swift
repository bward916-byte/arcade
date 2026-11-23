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

// The rules, privacy, terms and how to reach the owner.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Quartzsite Campfire is a free guide, map, question board and classifieds for campers around Quartzsite, Arizona. It is run by one person. There are no accounts and no passwords.")
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
