import SwiftUI

// One ad, full size, with Contact seller and Share.
struct ListingDetail: View {
    let listing: Listing
    @State private var contacting = false
    @State private var reporting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !listing.photos.isEmpty {
                    TabView {
                        ForEach(listing.photos, id: \.self) { id in
                            AsyncImage(url: Site.photo(id)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit()
                                } else if phase.error != nil {
                                    Text("Photo is being checked").foregroundColor(.secondary)
                                } else {
                                    ProgressView()
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: listing.photos.count > 1 ? .always : .never))
                    .frame(height: 300)
                    .background(Theme.soft)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(listing.price.isEmpty ? "Ask" : listing.price)
                            .font(.title.weight(.bold))
                            .foregroundColor(Theme.primary)
                        Spacer()
                        if listing.sold {
                            Text("Sold").font(.subheadline.weight(.bold)).foregroundColor(Theme.accent)
                        }
                    }
                    Text(listing.title).font(.title3.weight(.semibold))
                    Text([Site.catName(listing.cat), Site.areas[listing.area] ?? "", "listed " + Site.ago(listing.ts)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if !listing.text.isEmpty {
                        Text(listing.text)
                    }
                    Text("Meet in person, in daylight, and pay cash. Never send money, gift cards or codes to someone you have not met.")
                        .font(.footnote)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.soft)
                        .cornerRadius(10)
                    if !listing.sold {
                        Button {
                            contacting = true
                        } label: {
                            Text("Contact seller").font(.headline).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    Button(role: .destructive) {
                        reporting = true
                    } label: {
                        Label("Report this ad", systemImage: "flag").font(.footnote)
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(Theme.page)
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: Site.link(listing.id))
            }
        }
        .sheet(isPresented: $contacting) {
            ContactSheet(listing: listing)
        }
        .confirmationDialog("Report this ad to the owner? It will be hidden on this phone.", isPresented: $reporting, titleVisibility: .visible) {
            Button("Report and hide", role: .destructive) {
                Hidden.add(listing.id)
                Task { await Site.reportAd(listing.id) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// The buyer's message. The site forwards it by email; the seller's address is never shown.
struct ContactSheet: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    @AppStorage("contact") private var from = ""
    @State private var message = ""
    @State private var sending = false
    @State private var problem = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Text("Sent. The seller will reply to you directly at \(from).")
                        Button("Done") { dismiss() }
                    }
                } else {
                    Section("Your message") {
                        TextEditor(text: $message).frame(minHeight: 110)
                    }
                    Section("Your email or phone, so the seller can reply") {
                        TextField("you@example.com or 555-123-4567", text: $from)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if !problem.isEmpty {
                        Section { Text(problem).foregroundColor(Theme.accent) }
                    }
                    Section {
                        Button(sending ? "Sending…" : "Send to seller") { send() }
                            .disabled(sending)
                    }
                }
            }
            .navigationTitle("Contact the seller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if message.isEmpty { message = "Hi, is your \"\(listing.title)\" still available?" }
            }
        }
    }

    private func send() {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let contact = from.trimmingCharacters(in: .whitespaces)
        if text.isEmpty || contact.isEmpty {
            problem = "Write a message and give your email or phone."
            return
        }
        sending = true
        problem = ""
        Task {
            do {
                try await Site.contact(id: listing.id, message: text, from: contact)
                sent = true
            } catch {
                problem = error.localizedDescription
            }
            sending = false
        }
    }
}
