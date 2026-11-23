import SwiftUI

// The guide as the site sends it: lists of cards, the camping areas, show dates and map pins.
struct GuideData: Codable {
    var lists: [GuideList]
    var areas: [GuideArea]
    var shows: [Show]
    var pins: [Pin]
}

struct GuideList: Codable, Identifiable {
    let id: String
    let section: String
    let label: String
    var cards: [GuideCard]
}

struct GuidePhoto: Codable, Hashable {
    let url: String
    let page: String
    let credit: String
}

struct GuideCard: Codable, Hashable {
    let title: String
    let text: String
    var map: String?
    var photo: GuidePhoto?
}

// The photo (with its credit) and the Google Maps link under a guide card, when the site sends them.
struct CardExtras: View {
    let map: String?
    let photo: GuidePhoto?
    var body: some View {
        if let photo, let url = URL(string: photo.url) {
            VStack(alignment: .leading, spacing: 4) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.15)
                }
                .frame(maxWidth: .infinity).frame(height: 180).clipped().cornerRadius(10)
                if let page = URL(string: photo.page) {
                    Link(photo.credit, destination: page).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        if let map, let url = URL(string: map) {
            Link(destination: url) { Label("Open in Google Maps", systemImage: "mappin.and.ellipse") }
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct GuideArea: Codable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let text: String
    var photo: GuidePhoto?
}

struct Show: Codable, Hashable {
    var b: [String]? // the badge: month, then days
    let n: String   // name
    let w: String   // when
    let p: String   // place
    let s: String   // "ok" when the dates are confirmed
    let d: String   // details
}

struct Pin: Codable, Identifiable {
    var id: String { name }
    let name: String
    let lat: Double
    let lon: Double
    let kind: String   // ltva, free, see, svc, food or med
    let area: String
    var text: String?  // what the guide says about the place
    var list: String?  // which guide list it is in
    var map: String?   // Google Maps link
    var icon: String?  // the website's icon name for this kind of place: tire, pump, mail and so on
}

// Loads the guide once for all tabs. The last copy is kept on the phone, and a copy ships inside the app, so it opens with no signal.
@MainActor
final class GuideStore: ObservableObject {
    @Published var data: GuideData?
    @Published var failed = false

    private var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("guide.json")
    }

    func load() async {
        if data == nil, let saved = try? Data(contentsOf: cacheFile), let old = try? JSONDecoder().decode(GuideData.self, from: saved) {
            data = old
        }
        // First launch with no signal: use the copy of the guide that ships inside the app.
        if data == nil, let url = Bundle.main.url(forResource: "guide", withExtension: "json"),
           let packed = try? Data(contentsOf: url), let old = try? JSONDecoder().decode(GuideData.self, from: packed) {
            data = old
        }
        do {
            let fresh = try await Site.guide()
            data = try JSONDecoder().decode(GuideData.self, from: fresh)
            try? fresh.write(to: cacheFile)
            failed = false
        } catch {
            failed = data == nil
        }
    }
}

struct GuideView: View {
    @EnvironmentObject private var guide: GuideStore
    @State private var suggesting = false
    @State private var section = ProcessInfo.processInfo.arguments.contains("-demo-areamap") ? "areamap" : "start"
    private let icons = ["start": "flag", "areamap": "map", "camping": "tent", "wash": "water.waves", "services": "wrench.and.screwdriver", "rocks": "diamond", "mines": "hammer", "trips": "car", "nature": "leaf", "nomad": "bus", "town": "building.2"]
    @State private var search = ""

    private let sections: [Category] = [
        Category(id: "start", name: "Start here"), Category(id: "areamap", name: "Map"), Category(id: "camping", name: "Camping"), Category(id: "wash", name: "Washes"),
        Category(id: "services", name: "Services"), Category(id: "rocks", name: "Rockhounding"),
        Category(id: "mines", name: "Gold and ghost camps"), Category(id: "trips", name: "Trips and trails"), Category(id: "nature", name: "Plants and animals"), Category(id: "nomad", name: "Nomads and skoolies"), Category(id: "town", name: "Town")
    ]

    // The lists to show: one section, or every card that matches the search.
    private var lists: [GuideList] {
        guard let data = guide.data else { return [] }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return data.lists.filter { $0.section == section } }
        return data.lists.compactMap { list in
            let hits = list.cards.filter { ($0.title + " " + $0.text).lowercased().contains(q) }
            if hits.isEmpty { return nil }
            var copy = list
            copy.cards = hits
            return copy
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section {
                        DesertBanner(title: "Quartzsite Guide", subtitle: "Camping, services, rocks and day trips")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sections) { s in
                                    Button {
                                        section = s.id
                                    } label: {
                                        Label(s.name, systemImage: icons[s.id] ?? "circle")
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(section == s.id ? Theme.primary : Theme.card)
                                            .foregroundColor(section == s.id ? .white : .primary)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color.black.opacity(section == s.id ? 0 : 0.12)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading)
                            .padding(.trailing, 48)
                        }
                        .swipeHint()
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                if search.isEmpty && (section == "start" || section == "camping") {
                    Section { LandAskButton() }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if search.isEmpty && section == "start" {
                    Section {
                        NavigationLink {
                            QuestionsView()
                        } label: {
                            Label("Ask a question or help answer one", systemImage: "questionmark.bubble")
                                .font(.subheadline.weight(.semibold))
                        }
                    } footer: {
                        Text("Campers ask and answer each other here. No account needed.")
                    }
                }
                if guide.data == nil {
                    Section {
                        if guide.failed {
                            Text("The guide did not load. Check your signal and pull down to try again.").foregroundColor(.secondary)
                        } else {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    }
                }
                if search.isEmpty && section == "areamap", let data = guide.data {
                    AreaMapSection(data: data)
                }
                if search.isEmpty && section == "camping", let areas = guide.data?.areas {
                    Section("Camping areas") {
                        ForEach(areas) { a in
                            DisclosureGroup {
                                Text(CampWords.linked(a.text)).font(.subheadline)
                                CardExtras(map: nil, photo: a.photo)
                            } label: {
                                Text(a.name).font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
                ForEach(lists) { list in
                    Section(list.label) {
                        ForEach(list.cards, id: \.self) { card in
                            DisclosureGroup {
                                Text(CampWords.linked(card.text)).font(.subheadline).textSelection(.enabled)
                                CardExtras(map: card.map, photo: card.photo)
                            } label: {
                                Text(card.title).font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
                if !search.isEmpty && lists.isEmpty && guide.data != nil {
                    Text("Nothing in the guide matches.").foregroundColor(.secondary)
                }
                Section {
                    Button {
                        suggesting = true
                    } label: {
                        Label("Suggest a fix or a missing place", systemImage: "square.and.pencil")
                    }
                } footer: {
                    Text("No account needed. Each suggestion is checked before the guide changes.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.page)
            .navigationTitle("Guide")
            .sheet(isPresented: $suggesting) { SuggestSheet() }
            .searchable(text: $search, prompt: "Search the guide")
            .refreshable { await guide.load() }
        }
    }
}

// The big gem, rock and RV shows.
struct ShowsView: View {
    @EnvironmentObject private var guide: GuideStore

    var body: some View {
        NavigationStack {
            List {
                if let shows = guide.data?.shows {
                    Section {
                        DesertBanner(title: "Show season", subtitle: "Gem, rock and RV shows all winter", scene: "bigtop")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    ForEach(shows, id: \.self) { show in
                        HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Text(show.b?.first ?? "").font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 3).background(show.s == "ok" ? Theme.primary : Theme.accent)
                            Text((show.b?.count ?? 0) > 1 ? show.b![1] : "").font(.system(size: 13, weight: .heavy, design: .rounded))
                                .minimumScaleFactor(0.6).lineLimit(1).padding(.vertical, 6).padding(.horizontal, 2)
                        }
                        .frame(width: 58)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.black.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(show.n).font(.headline)
                            Text(show.w).font(.subheadline.weight(.semibold)).foregroundColor(Theme.primary)
                            Text(show.p).font(.subheadline).foregroundColor(.secondary)
                            Text(show.d).font(.subheadline)
                            Text(show.s == "ok" ? "Dates confirmed" : "Check the dates before you go")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(show.s == "ok" ? Theme.primary : Theme.accent)
                        }
                        }
                        .padding(.vertical, 4)
                    }
                } else if guide.failed {
                    Text("The show dates did not load. Check your signal and pull down to try again.").foregroundColor(.secondary)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.page)
            .navigationTitle("Shows")
            .refreshable { await guide.load() }
        }
    }
}
