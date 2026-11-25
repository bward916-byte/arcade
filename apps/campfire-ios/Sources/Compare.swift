import SwiftUI

// Free camping against the permit area. Every "BLM", "LTVA" and "Long Term Visitor Area" in the guide's text is a link to this.

enum CampWords {
    static let note = Notification.Name("campCompare")
    private static let pattern = try! NSRegularExpression(pattern: "\\b(BLM|LTVAs?|Long[- ]Term Visitor Areas?)\\b")

    // The text with those words turned into links. The link is handled inside the app, not opened in a browser.
    static func linked(_ text: String) -> AttributedString {
        var out = AttributedString(text)
        let whole = NSRange(text.startIndex..., in: text)
        for m in pattern.matches(in: text, range: whole) {
            guard let r = Range(m.range, in: text), let lo = AttributedString.Index(r.lowerBound, within: out), let hi = AttributedString.Index(r.upperBound, within: out) else { continue }
            out[lo..<hi].link = URL(string: "campfire://compare")
            out[lo..<hi].underlineStyle = Text.LineStyle(pattern: .dot)
            out[lo..<hi].foregroundColor = Theme.primary
        }
        return out
    }
}

struct CompareView: View {
    @Environment(\.dismiss) private var dismiss
    private let rows: [(String, String, String)] = [
        ("Cost", "Free", "$40 for 14 days, or $180 for the season"),
        ("How long", "14 days in any 28", "All season, Sept 15 to April 15"),
        ("Dump station", "No", "Yes, at La Posa South"),
        ("Water fill", "No", "Yes"),
        ("Trash", "No, carry it out", "Yes, dumpsters"),
        ("Restrooms", "No", "Yes"),
        ("Checking in", "A free date card from the camp host", "Buy the permit at the entrance. After hours, find a spot and register in the morning"),
        ("Where", "Plomosa Road, Hi Jolly, Dome Rock, Scaddan Wash, Road Runner", "La Posa North, South, West and Tyson Wash")]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Both are on BLM land, the public land run by the Bureau of Land Management. The difference is what you get.")
                }
                ForEach(rows, id: \.0) { row in
                    Section(row.0) {
                        HStack(alignment: .top, spacing: 12) {
                            side("Free 14-day areas", row.1, Theme.accent)
                            Divider()
                            side("La Posa permit area", row.2, Theme.primary)
                        }
                    }
                }
                Section {
                    Button {
                        dismiss()
                        LandAsk.go()
                    } label: {
                        Label("Am I on BLM land?", systemImage: "location.fill").font(.headline)
                    }
                } footer: {
                    Text("Prices and rules are the BLM's and can change. Away from these areas, most BLM land also allows free camping for 14 days unless it is posted closed.")
                }
            }
            .navigationTitle("Free camping or the permit area?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }

    private func side(_ head: String, _ text: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(head).font(.caption.weight(.bold)).foregroundColor(color)
            Text(text).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Shown above every Post button: posting means agreeing to the terms.
struct TermsLine: View {
    var verb = "posting"
    var body: some View {
        Text("By \(verb) you agree to the [terms of use](https://qcampfire.com/terms): be kind, nothing objectionable. Posts are checked, and anyone can report one.")
            .font(.footnote).foregroundColor(.secondary)
    }
}

// The first time someone posts anything, they are asked to agree to the terms. The answer is remembered on the phone.
enum Terms {
    static var agreed: Bool {
        get { UserDefaults.standard.bool(forKey: "agreedTerms") }
        set { UserDefaults.standard.set(newValue, forKey: "agreedTerms") }
    }
    // Runs the post now if they already agreed; otherwise holds it and raises the question.
    static func check(_ pending: inout (() -> Void)?, _ asking: inout Bool, _ go: @escaping () -> Void) {
        if agreed { go() } else { pending = go; asking = true }
    }
}

extension View {
    func termsGate(_ asking: Binding<Bool>, _ pending: Binding<(() -> Void)?>) -> some View {
        alert("Before you post", isPresented: asking) {
            Button("I agree") { Terms.agreed = true; pending.wrappedValue?(); pending.wrappedValue = nil }
            Link("Read the terms", destination: Site.termsPage)
            Button("Cancel", role: .cancel) { pending.wrappedValue = nil }
        } message: {
            Text("Posting means you agree to the terms of use. Be kind. No nudity, hate, threats, scams or anything illegal. Posts are checked, anyone can report one, and people who break the rules are blocked.")
        }
    }
}
