import SwiftUI
import PhotosUI

// A camper's account. It is optional: everything in the app works without one. An account puts a camp name and photo
// beside your answers, counts you among the top helpers, and keeps your posts with you on any phone.

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()
    @Published var me: Me?
    func load() async { me = await Site.me() }
}

// A round photo, or the first letter of the name on a coloured disc.
struct Avatar: View {
    let photo: String
    let name: String
    let size: CGFloat

    private var letter: some View {
        Circle().fill(Theme.primary)
            .overlay(Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()).font(.system(size: size * 0.45, weight: .bold)).foregroundColor(.white))
    }

    var body: some View {
        Group {
            if photo.isEmpty { letter } else {
                AsyncImage(url: Site.photo(photo)) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { letter }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

// The campers who have answered the most.
struct HelpersCard: View {
    let signedIn: Bool
    let onSignIn: () -> Void
    @State private var rows: [Helper] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Top helpers", systemImage: "star.fill").font(.headline).foregroundColor(Theme.accent)
            if rows.isEmpty {
                Text(loaded ? "Nobody is on the board yet. Answer a question while signed in and your name goes here." : "Loading…")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                HStack(spacing: 10) {
                    Text(String(i + 1)).font(.subheadline.weight(.bold)).foregroundColor(Theme.accent).frame(width: 18)
                    Avatar(photo: r.photo, name: r.handle, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.handle).font(.subheadline.weight(.semibold))
                        Text((r.answers == 1 ? "1 answer" : "\(r.answers) answers") + (r.thanks > 0 ? " · \(r.thanks) thanks" : "")).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            if !signedIn {
                Button("Sign in to be counted", action: onSignIn).buttonStyle(.borderless).font(.footnote)
            }
        }
        .task { rows = await Site.helpers(); loaded = true }
    }
}

// Sign in, pick a camp name, add a photo, sign out, or delete the account.
struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var account = AccountStore.shared
    @AppStorage("askEmail") private var email = ""
    @State private var code = ""
    @State private var sent = false
    @State private var naming = false
    @State private var handle = ""
    @State private var ideas: [String] = []
    @State private var note = ""
    @State private var busy = false
    @State private var pick: PhotosPickerItem?
    @State private var renaming = false
    @State private var deleteWord = ""

    var body: some View {
        NavigationStack {
            Form {
                if let me = account.me { profile(me) } else if naming { nameStep } else { signIn }
                if !note.isEmpty { Section { Text(note).font(.footnote).foregroundColor(Theme.accent) } }
            }
            .navigationTitle(account.me == nil ? "Sign in or join" : "My account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .busy(busy, "One moment…")
        }
    }

    @ViewBuilder private var signIn: some View {
        Section {
            TextField("you@example.com", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.emailAddress)
            Button(sent ? "Send the code again" : "Email me a sign-in code") { sendCode() }
        } header: {
            Text("Email")
        } footer: {
            Text("An account is optional. It puts your camp name and photo beside your answers, counts you among the top helpers, and keeps your posts with you on any phone. There is no password, and your email is never shown.")
        }
        if sent {
            Section {
                TextField("6-digit code", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                Button("Sign in") { useCode("") }
            } header: {
                Text("Code from the email")
            } footer: {
                Text("Nothing in your inbox? Check spam and Promotions.")
            }
        }
    }

    @ViewBuilder private var nameStep: some View {
        Section {
            TextField("Dusty Roadrunner", text: $handle).autocorrectionDisabled()
            Button("Create my account") { useCode(handle.trimmingCharacters(in: .whitespaces)) }
        } header: {
            Text("Pick your camp name")
        } footer: {
            Text("Everyone sees this, so not your full name or email. You can change it later.")
        }
        ideaList
    }

    private var ideaList: some View {
        Section("Stuck? Tap an idea") {
            ForEach(ideas, id: \.self) { idea in
                Button(idea) { handle = idea }.foregroundColor(.primary)
            }
            Button("More ideas") { Task { ideas = await Site.nameIdeas() } }
        }
    }

    @ViewBuilder private func profile(_ me: Me) -> some View {
        Section {
            HStack(spacing: 14) {
                Avatar(photo: me.photo, name: me.handle, size: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(me.handle).font(.title3.weight(.bold))
                    Text(me.email).font(.footnote).foregroundColor(.secondary)
                }
            }
            PhotosPicker(selection: $pick, matching: .images) { Text(me.photo.isEmpty ? "Add a photo" : "Change photo") }
            if !me.photo.isEmpty { Button("Remove photo", role: .destructive) { setPhoto("") } }
            Button("Change name") { handle = me.handle; renaming.toggle(); if ideas.isEmpty { Task { ideas = await Site.nameIdeas() } } }
        } footer: {
            Text("Your name and photo show beside your questions and answers. A new photo shows to others after a quick check. Your email is never shown.")
        }
        .onChange(of: pick) { item in
            guard let item else { return }
            Task {
                busy = true
                note = ""
                if let raw = try? await item.loadTransferable(type: Data.self), let small = PostAdView.shrink(raw), let id = try? await Site.upload(photo: small) {
                    setPhoto(id)
                } else {
                    note = "That photo did not upload. Try a different one."
                    busy = false
                }
                pick = nil
            }
        }
        if renaming {
            Section("New camp name") {
                TextField("Dusty Roadrunner", text: $handle).autocorrectionDisabled()
                Button("Save name") { rename() }
            }
            ideaList
        }
        Section { Button("Sign out") { Task { await Site.signOut(); account.me = nil } } }
        Section {
            TextField("Type DELETE to confirm", text: $deleteWord).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Button("Delete my account", role: .destructive) { deleteAccount() }.disabled(deleteWord.trimmingCharacters(in: .whitespaces) != "DELETE")
        } header: {
            Text("Delete my account")
        } footer: {
            Text("This removes your account, your photo, and the questions and answers you posted while signed in. It cannot be undone. Ads are managed from the link in their own email.")
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        note = ""
        Task {
            do { try await work() }
            catch let error as SiteError { note = error.message; if naming || renaming { ideas = await Site.nameIdeas() } }
            catch { note = "That did not work. Check your signal and try again." }
            busy = false
        }
    }

    private func sendCode() {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        if !e.contains("@") { note = "Enter your email address."; return }
        email = e
        run { try await Site.signInCode(email: e); sent = true }
    }

    private func useCode(_ name: String) {
        let c = code.trimmingCharacters(in: .whitespaces)
        if c.count < 6 { note = "Type the 6-digit code from the email."; return }
        if naming && name.count < 2 { note = "Pick a camp name of at least 2 letters."; return }
        run {
            switch try await Site.enter(email: email, code: c, handle: name) {
            case .signedIn(let me): account.me = me; naming = false; code = ""; sent = false
            case .needName(let list): ideas = list; naming = true
            }
        }
    }

    private func rename() {
        let name = handle.trimmingCharacters(in: .whitespaces)
        if name.count < 2 { note = "Pick a camp name of at least 2 letters."; return }
        run { let r = try await Site.setProfile(handle: name); account.me?.handle = r.handle; renaming = false }
    }

    private func setPhoto(_ id: String) {
        run { let r = try await Site.setProfile(photo: id); account.me?.photo = r.photo }
    }

    private func deleteAccount() {
        run { try await Site.deleteAccount(); account.me = nil; deleteWord = "" }
    }
}
