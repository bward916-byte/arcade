import SwiftUI
import PhotosUI

// Post an ad from the phone. No account: the site emails a link that publishes it.
struct PostAdView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("email") private var email = ""
    @State private var title = ""
    @State private var price = ""
    @State private var cat = "rv"
    @State private var area = "town"
    @State private var details = ""
    @State private var run = "dates"
    @State private var from = Date()
    @State private var to = Date().addingTimeInterval(30 * 86400)
    @State private var picks: [PhotosPickerItem] = []
    @State private var sending = false
    @State private var problem = ""
    @State private var done = false
    @State private var testLink: String?

    private let areaOrder = ["town", "lpsouth", "lpnorth", "lpwest", "lptyson", "hijolly", "plomosa", "domerock", "scaddan", "roadrunner", "other"]

    var body: some View {
        NavigationStack {
            Form {
                if done {
                    Section("Almost done: check your email") {
                        if let link = testLink, let url = URL(string: link) {
                            Text("Email is not set up on the site yet, so nothing was sent. For testing, open this link to publish the ad.")
                            Link("Publish my ad", destination: url)
                        } else {
                            Text("We sent a link to \(email). Tap it to publish your ad.")
                            Text("Keep that email. The same link lets you edit the ad, mark it sold or remove it. Nothing in your inbox? Check spam.")
                                .font(.footnote).foregroundColor(.secondary)
                        }
                        Button("Done") { dismiss() }
                    }
                } else {
                    Section {
                        TextField("What are you selling", text: $title)
                        TextField("Price: $80, free, or trade", text: $price)
                        Picker("Category", selection: $cat) {
                            ForEach(Site.cats) { c in Text(c.name).tag(c.id) }
                        }
                        Picker("Where", selection: $area) {
                            ForEach(areaOrder, id: \.self) { id in Text(Site.areas[id] ?? id).tag(id) }
                        }
                    }
                    Section("Details") {
                        TextEditor(text: $details).frame(minHeight: 90)
                    }
                    Section("When should it show") {
                        Picker("Show it", selection: $run) {
                            Text("For a set time").tag("dates")
                            Text("Winter season only").tag("winter")
                            Text("Year round").tag("year")
                        }
                        if run == "dates" {
                            DatePicker("First day", selection: $from, displayedComponents: .date)
                            DatePicker("Last day", selection: $to, in: from..., displayedComponents: .date)
                        } else if run == "winter" {
                            Text("September 15 to April 15, every year.").font(.footnote).foregroundColor(.secondary)
                        }
                    }
                    Section("Photos") {
                        PhotosPicker(selection: $picks, maxSelectionCount: 3, matching: .images) {
                            Label(picks.isEmpty ? "Add up to 3 photos" : "\(picks.count) chosen. Tap to change.", systemImage: "photo.on.rectangle")
                        }
                    }
                    Section {
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Your email")
                    } footer: {
                        Text("Not shown on your ad. We send your publish link here and forward buyers' messages to it. If you reply to a buyer, they will see your address. By posting you agree to the [terms](https://qcampfire.com/terms): honest, legal, nothing objectionable.")
                    }
                    if !problem.isEmpty {
                        Section { Text(problem).foregroundColor(Theme.accent) }
                    }
                    Section {
                        Button(sending ? "Posting…" : "Post my ad") { send() }
                            .disabled(sending)
                    }
                }
            }
            .navigationTitle("Post an ad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func send() {
        let name = title.trimmingCharacters(in: .whitespaces)
        let mail = email.trimmingCharacters(in: .whitespaces)
        if name.count < 2 {
            problem = "Give it a short title."
            return
        }
        if !mail.contains("@") || !mail.contains(".") {
            problem = "Enter your email. We send the link that publishes your ad there."
            return
        }
        sending = true
        problem = ""
        Task {
            do {
                var ids: [String] = []
                for pick in picks {
                    if let raw = try await pick.loadTransferable(type: Data.self), let small = Self.shrink(raw) {
                        ids.append(try await Site.upload(photo: small))
                    }
                }
                let day = DateFormatter()
                day.calendar = Calendar(identifier: .gregorian)
                day.locale = Locale(identifier: "en_US_POSIX")
                day.dateFormat = "yyyy-MM-dd"
                var ad: [String: Any] = [
                    "title": name, "price": price.trimmingCharacters(in: .whitespaces), "cat": cat, "area": area,
                    "text": details.trimmingCharacters(in: .whitespacesAndNewlines), "run": run, "photos": ids, "email": mail
                ]
                if run == "dates" {
                    ad["from"] = day.string(from: from)
                    ad["to"] = day.string(from: to)
                }
                if let amount = Self.amount(in: price) { ad["amount"] = amount }
                testLink = try await Site.post(ad: ad)
                done = true
            } catch {
                problem = error.localizedDescription
            }
            sending = false
        }
    }

    // The first number in the price, so ads can be sorted. "Free" counts as zero.
    private static func amount(in price: String) -> Double? {
        let cleaned = price.replacingOccurrences(of: ",", with: "")
        if let r = cleaned.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) { return Double(cleaned[r]) }
        return cleaned.lowercased().contains("free") ? 0 : nil
    }

    // Photos are sent no larger than 1600 points on the long side.
    private static func shrink(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longSide = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longSide, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return small.jpegData(compressionQuality: 0.8)
    }
}
