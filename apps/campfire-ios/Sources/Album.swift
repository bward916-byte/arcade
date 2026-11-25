import SwiftUI
import PhotosUI

// One picture in the campers' album.
struct AlbumPic: Identifiable {
    let id: String
    let photo: String
    let caption: String
    let name: String
    let waiting: String   // "" once everyone can see it
    let mine: Bool
}

// The private keys this phone was given for the pictures it added, so it can take them down later.
enum AlbumKeys {
    private static let name = "albumKeys", hiddenName = "albumHidden"
    static func all() -> [String: String] { UserDefaults.standard.dictionary(forKey: name) as? [String: String] ?? [:] }
    static func keep(_ id: String, _ key: String) {
        var m = all()
        m[id] = key
        UserDefaults.standard.set(m, forKey: name)
    }
    static func hidden() -> [String] { UserDefaults.standard.stringArray(forKey: hiddenName) ?? [] }
    static func hide(_ id: String) { UserDefaults.standard.set(Array((hidden() + [id]).suffix(200)), forKey: hiddenName) }
}

extension Site {
    private static func albumCall(_ parts: [String], _ body: [String: Any], _ fallback: String) async throws -> Data {
        var url = base.appendingPathComponent("api").appendingPathComponent("album")
        for p in parts { url = url.appendingPathComponent(p) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw SiteError(message: json?["error"] as? String ?? fallback)
        }
        return data
    }

    // Everyone's checked pictures, plus this phone's own that are still being checked.
    static func album() async throws -> [AlbumPic] {
        let data = try await albumCall(["list"], ["keys": Array(AlbumKeys.all().values)], "Photos did not load.")
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            guard let id = row["id"] as? String, let d = row["data"] as? [String: Any], let photo = d["photo"] as? String else { return nil }
            return AlbumPic(id: id, photo: photo, caption: d["caption"] as? String ?? "", name: d["name"] as? String ?? "",
                            waiting: d["waiting"] as? String ?? "", mine: row["mine"] as? Bool ?? false)
        }
    }

    static func addToAlbum(photo: String, caption: String, name: String) async throws {
        let data = try await albumCall([], ["photo": photo, "caption": caption, "name": name], "That did not go through. Try again.")
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if let id = json?["id"] as? String, let key = json?["key"] as? String { AlbumKeys.keep(id, key) }
    }

    static func removeFromAlbum(_ id: String) async {
        guard let key = AlbumKeys.all()[id] else { return }
        _ = try? await albumCall([id, "mine"], ["key": key], "")
    }

    static func reportAlbum(_ id: String) async {
        _ = try? await albumCall([id, "report"], [:], "")
    }
}

// The Photos page of the Guide: pictures campers took around Quartzsite.
struct AlbumSection: View {
    @State private var pics: [AlbumPic] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var adding = false
    @State private var note = ""
    @State private var open: AlbumPic?

    var body: some View {
        Section {
            Button {
                adding = true
            } label: {
                Label("Add a photo", systemImage: "plus.circle.fill").font(.headline)
            }
            if !note.isEmpty { Text(note).font(.footnote).foregroundColor(.secondary) }
        } header: {
            Text("Photos from campers")
        } footer: {
            Text("Sunsets, camps, rocks and good days around Quartzsite. No account needed.")
        }
        .sheet(isPresented: $adding) {
            AddPhotoView { note = "Thank you. Your photo shows to everyone once it has been checked."; Task { await load() } }
        }
        .sheet(item: $open) { pic in AlbumPicView(pic: pic) }
        .task { await load() }

        let shown = pics.filter { !AlbumKeys.hidden().contains($0.id) }
        if !loaded {
            Section { if failed { Text("Photos need a signal to load.").foregroundColor(.secondary) } else { ProgressView().frame(maxWidth: .infinity) } }
        } else if shown.isEmpty {
            Section { Text("No photos yet. Be the first to add one.").foregroundColor(.secondary) }
        } else {
            ForEach(shown) { pic in
                Section {
                    RemotePhoto(url: Site.photo(pic.photo), fill: true)
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .contentShape(Rectangle())
                    .onTapGesture { open = pic }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pic.caption).font(.subheadline.weight(.semibold))
                        Text(pic.name.isEmpty ? "From a camper" : "From \(pic.name)").font(.footnote).foregroundColor(.secondary)
                        if !pic.waiting.isEmpty {
                            Text(pic.waiting == "held" ? "Held back, not shown to others" : "Being checked, not shown to others yet")
                                .font(.footnote.weight(.semibold)).foregroundColor(.orange)
                        }
                    }
                    if pic.mine {
                        Button("Remove my photo", role: .destructive) {
                            Task { await Site.removeFromAlbum(pic.id); await load() }
                        }
                        .font(.footnote)
                    } else {
                        Button("Report") {
                            AlbumKeys.hide(pic.id)
                            note = "Reported, and hidden on this phone. Thank you."
                            pics.removeAll { $0.id == pic.id }
                            Task { await Site.reportAlbum(pic.id) }
                        }
                        .font(.footnote)
                    }
                }
            }
        }
    }

    private func load() async {
        do {
            pics = try await Site.album()
            failed = false
        } catch {
            failed = true
        }
        loaded = !failed || !pics.isEmpty
    }
}

// One picture, full screen.
struct AlbumPicView: View {
    let pic: AlbumPic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                RemotePhoto(url: Site.photo(pic.photo), fill: false)
                Text(pic.caption).font(.headline).padding(.horizontal)
                Text(pic.name.isEmpty ? "From a camper" : "From \(pic.name)").font(.subheadline).foregroundColor(.secondary)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

// Choose a picture, add a caption and, if you like, your name.
struct AddPhotoView: View {
    var done: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("askName") private var name = ""
    @State private var pick: PhotosPickerItem?
    @State private var small: Data?
    @State private var caption = ""
    @State private var sending = false
    @State private var problem = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $pick, matching: .images) {
                        Label(small == nil ? "Choose a photo" : "Choose a different photo", systemImage: "photo.on.rectangle")
                    }
                    if let small, let image = UIImage(data: small) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).frame(maxWidth: .infinity)
                    }
                }
                Section {
                    TextField("Caption: Sunset from Dome Rock", text: $caption)
                    TextField("Your name (optional)", text: $name)
                } footer: {
                    Text("Photos taken around Quartzsite, please. Each one is checked before others see it.")
                }
                if !problem.isEmpty { Section { Text(problem).foregroundColor(.red) } }
                Section {
                    TermsLine(verb: "adding a photo")
                    Button(sending ? "Adding…" : "Add my photo") { send() }
                        .disabled(sending)
                }
            }
            .navigationTitle("Add a photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: pick) { item in
                Task {
                    guard let item, let raw = try? await item.loadTransferable(type: Data.self) else { return }
                    small = Self.shrink(raw)
                    if small == nil { problem = "That photo could not be read. Try another." } else { problem = "" }
                }
            }
        }
    }

    private func send() {
        let words = String(caption.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
        guard let small else { problem = "Choose a photo first."; return }
        if words.count < 3 { problem = "Add a few words about the picture."; return }
        sending = true
        problem = ""
        Task {
            do {
                let id = try await Site.upload(photo: small)
                try await Site.addToAlbum(photo: id, caption: words, name: String(name.trimmingCharacters(in: .whitespaces).prefix(40)))
                done()
                dismiss()
            } catch {
                problem = error.localizedDescription
            }
            sending = false
        }
    }

    private static func shrink(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longSide = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longSide, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let made = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return made.jpegData(compressionQuality: 0.8)
    }
}

// A picture from the site. Loads again each time it comes on screen, and a failed try does not stick:
// the second try skips anything the phone saved earlier.
struct RemotePhoto: View {
    let url: URL
    let fill: Bool
    @State private var image: UIImage?
    @State private var failed = false
    @State private var tries = 0

    var body: some View {
        Group {
            if let image {
                if fill { Image(uiImage: image).resizable().scaledToFill() } else { Image(uiImage: image).resizable().scaledToFit() }
            } else if failed {
                Button("Photo did not load. Tap to try again.") { failed = false; tries += 1 }
                    .font(.footnote).frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .task(id: tries) { await load() }
    }

    private func load() async {
        if image != nil { return }
        for fresh in [false, true] {
            var req = URLRequest(url: url)
            if fresh { req.cachePolicy = .reloadIgnoringLocalCacheData }
            if let (data, response) = try? await URLSession.shared.data(for: req),
               (response as? HTTPURLResponse)?.statusCode == 200, let made = UIImage(data: data) {
                image = made
                failed = false
                return
            }
            if Task.isCancelled { return }   // scrolled away: try again when it comes back
        }
        failed = true
    }
}
