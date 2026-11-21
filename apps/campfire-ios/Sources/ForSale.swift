import SwiftUI

@MainActor
final class Store: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var failed = false
    @Published var loaded = false

    func load() async {
        do {
            listings = try await Site.listings()
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }
}

// The For Sale tab: search, category chips, sort, and a grid of ads.
struct ForSaleView: View {
    @StateObject private var store = Store()
    @State private var search = ""
    @State private var cat = ""
    @State private var sort = "new"
    @State private var path: [Listing] = []
    @State private var posting = ProcessInfo.processInfo.arguments.contains("-demo-post")

    private var shown: [Listing] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        var list = store.listings.filter { l in
            (cat.isEmpty || l.cat == cat) &&
            (q.isEmpty || (l.title + " " + l.text + " " + Site.catName(l.cat)).lowercased().contains(q))
        }
        list.sort { a, b in
            if a.sold != b.sold { return !a.sold }
            if sort != "new" {
                switch (a.amount, b.amount) {
                case let (x?, y?) where x != y: return sort == "low" ? x < y : x > y
                case (_?, nil): return true
                case (nil, _?): return false
                default: break
                }
            }
            return a.ts > b.ts
        }
        return list
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    DesertBanner(title: "Quartzsite Campfire", subtitle: "Buy, sell and trade around Quartzsite")
                        .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", "")
                            ForEach(Site.cats) { c in chip(c.name, c.id) }
                        }
                        .padding(.horizontal)
                    }
                    Text("Meet in person, in daylight, and pay cash. Never send money, gift cards or codes to someone you have not met.")
                        .font(.footnote)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.soft)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    if store.failed {
                        Text("The ads did not load. Check your signal and pull down to try again.")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else if store.loaded && shown.isEmpty {
                        Text(store.listings.isEmpty ? "No ads yet." : "Nothing matches. Try another category or clear the search.")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else if !store.loaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .top)], spacing: 12) {
                        ForEach(shown) { l in
                            NavigationLink(value: l) { ListingCard(listing: l) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Theme.page)
            .navigationTitle("For Sale")
            .navigationDestination(for: Listing.self) { l in ListingDetail(listing: l) }
            .searchable(text: $search, prompt: "Search ads")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        posting = true
                    } label: {
                        Label("Post an ad", systemImage: "plus.circle.fill").labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            Text("Newest first").tag("new")
                            Text("Price: low to high").tag("low")
                            Text("Price: high to low").tag("high")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort")
                }
            }
            .sheet(isPresented: $posting) { PostAdView() }
            .refreshable { await store.load() }
            .task {
                await store.load()
                // For the build's own screenshot of the ad screen.
                if ProcessInfo.processInfo.arguments.contains("-demo-ad"),
                   let first = store.listings.first(where: { !$0.photos.isEmpty }) {
                    path = [first]
                }
            }
        }
    }

    private func chip(_ name: String, _ id: String) -> some View {
        Button {
            cat = id
        } label: {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(cat == id ? Theme.primary : Theme.card)
                .foregroundColor(cat == id ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(cat == id ? 0 : 0.12)))
        }
        .buttonStyle(.plain)
    }
}

// The photo at the top of a card, or the category name when there is none.
struct Cover: View {
    let listing: Listing

    var body: some View {
        Theme.soft
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                if let first = listing.photos.first {
                    AsyncImage(url: Site.photo(first)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            Text("Photo is being checked").font(.caption).foregroundColor(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                } else {
                    Text(Site.catName(listing.cat)).font(.caption.weight(.semibold)).foregroundColor(.secondary)
                }
            }
            .clipped()
            .opacity(listing.sold ? 0.45 : 1)
    }
}

struct ListingCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Cover(listing: listing)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(listing.price.isEmpty ? "Ask" : listing.price)
                        .font(.headline)
                        .foregroundColor(Theme.primary)
                    Spacer()
                    if listing.sold {
                        Text("Sold").font(.caption.weight(.bold)).foregroundColor(Theme.accent)
                    }
                }
                Text(listing.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text([Site.areas[listing.area] ?? "", Site.ago(listing.ts)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.card)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
