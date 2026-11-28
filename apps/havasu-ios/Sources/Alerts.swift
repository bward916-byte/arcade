import SwiftUI

// Weather alerts and local news, newest first.
struct AlertsView: View {
    @State private var posts: [AlertPost] = []
    @State private var loaded = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DesertBanner(title: "Alerts", subtitle: "Weather warnings and local news", scene: "storm")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if failed {
                    Text("The alerts did not load. Check your signal and pull down to try again.").foregroundColor(.secondary)
                } else if !loaded {
                    ProgressView().frame(maxWidth: .infinity)
                } else if posts.isEmpty {
                    Text("No alerts right now.").foregroundColor(.secondary)
                }
                ForEach(posts) { post in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Site.ago(post.ts)).font(.caption).foregroundColor(.secondary)
                        if !post.text.isEmpty {
                            Text(post.text).font(.subheadline)
                        }
                        if !post.photo.isEmpty {
                            AsyncImage(url: Site.photo(post.photo)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit().cornerRadius(10)
                                }
                            }
                        }
                        if let url = firstLink(in: post) {
                            Link(destination: url) {
                                Label("Open the source", systemImage: "arrow.up.right.square").font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.page)
            .navigationTitle("Alerts")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            posts = try await Site.alerts()
            failed = false
        } catch {
            failed = posts.isEmpty
        }
        loaded = true
    }

    // The post's own link, or the first web address in its text.
    private func firstLink(in post: AlertPost) -> URL? {
        if post.link.hasPrefix("http"), let u = URL(string: post.link) { return u }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(post.text.startIndex..., in: post.text)
        return detector.firstMatch(in: post.text, options: [], range: range)?.url
    }
}
