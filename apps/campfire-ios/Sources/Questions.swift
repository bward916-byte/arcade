import SwiftUI

// One answer to a camper's question. An answer marked guide was matched from the guide by the AI check.
struct QAnswer: Identifiable {
    let id: String
    var text: String
    let name: String
    let ts: Double
    let guide: Bool
    let title: String
    var up: Int
    let said: Int
    let waiting: Bool   // not passed by the check yet, so only its poster sees it
    var photo = ""      // the poster's account photo, if they have an account with one
    var acct = false    // posted from an account
    var mine = false    // posted from the account signed in on this phone
}

struct Question: Identifiable {
    let id: String
    var text: String
    let name: String
    let ts: Double
    let edited: Bool
    let waiting: Bool
    var answers: [QAnswer]
    var photo = ""
    var acct = false
    var mine = false
}

// The private keys this phone was given for its own questions and answers, so their owner can edit or delete them with no account.
enum MyPosts {
    private static let keysName = "askKeys", thanksName = "askThanks"
    static func key(_ id: String) -> String? { (UserDefaults.standard.dictionary(forKey: keysName) as? [String: String])?[id] }
    static func allKeys() -> [String] { Array((UserDefaults.standard.dictionary(forKey: keysName) as? [String: String] ?? [:]).values) }
    static func keep(_ id: String, _ key: String) {
        var all = UserDefaults.standard.dictionary(forKey: keysName) as? [String: String] ?? [:]
        all[id] = key
        UserDefaults.standard.set(all, forKey: keysName)
    }
    static func thanked(_ id: String) -> Bool { (UserDefaults.standard.stringArray(forKey: thanksName) ?? []).contains(id) }
    static func keepThanks(_ id: String) {
        var all = UserDefaults.standard.stringArray(forKey: thanksName) ?? []
        all.append(id)
        UserDefaults.standard.set(Array(all.suffix(500)), forKey: thanksName)
    }
}

// Ask a question, see what the guide already says, and answer other campers. No account needed.
struct QuestionsView: View {
    @EnvironmentObject private var guide: GuideStore
    @State private var rows: [Question] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var show: String
    // The "A camper is asking" strip opens this with only the questions that still need an answer.
    init(startOpen: Bool = false) { _show = State(initialValue: startOpen ? "open" : "all") }
    @State private var asking = ""
    @AppStorage("askName") private var name = ""
    @AppStorage("askEmail") private var email = ""
    @State private var sending = false
    @State private var note = ""
    @State private var drafts: [String: String] = [:]   // an answer being typed, by question
    @State private var editing = ""                      // id of the question or answer being edited
    @State private var editText = ""
    @AppStorage(Hidden.name) private var hiddenRaw = ""
    @ObservedObject private var account = AccountStore.shared
    @State private var signingIn = false
    @State private var backEmail = ""                    // getting back into posts made on another device
    @State private var backCode = ""
    @State private var backNote = ""
    @State private var backSent = false

    // Everything except what this phone's owner reported.
    private var visible: [Question] {
        rows.filter { !Hidden.has(hiddenRaw, $0.id) }.map { q in
            var copy = q
            copy.answers = q.answers.filter { !Hidden.has(hiddenRaw, $0.id) }
            return copy
        }
    }
    private var waiting: [Question] { visible.filter { $0.answers.isEmpty } }
    private var done: [Question] { visible.filter { !$0.answers.isEmpty } }
    private var shown: [Question] { show == "open" ? waiting : show == "done" ? done : waiting + done }

    // Guide entries that share words with what is being typed.
    private var matches: [GuideCard] {
        let skip: Set<String> = ["where", "what", "when", "does", "anyone", "know", "there", "have", "with", "that", "this", "from", "about", "quartzsite", "good", "best", "need", "find", "near", "area", "town", "place", "can", "the", "and", "for", "are", "any", "you", "get", "buy", "how", "who"]
        let words = asking.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 3 && !skip.contains($0) }
        guard !words.isEmpty, let data = guide.data else { return [] }
        var scored: [(Int, GuideCard)] = []
        for list in data.lists {
            for card in list.cards {
                let title = card.title.lowercased(), text = card.text.lowercased()
                var score = 0
                for w in words { score += (title.contains(w) ? 3 : 0) + (text.contains(w) ? 1 : 0) }
                if score >= 3 { scored.append((score, card)) }
            }
        }
        return scored.sorted { $0.0 > $1.0 }.prefix(3).map { $0.1 }
    }

    var body: some View {
        List {
            Section { HelpersCard(signedIn: account.me != nil) { signingIn = true } }
            Section {
                TextField("Type a question. Where can I…?", text: $asking, axis: .vertical).lineLimit(2...4)
                ForEach(matches, id: \.self) { card in
                    DisclosureGroup {
                        Text(card.text).font(.subheadline)
                    } label: {
                        Label(card.title, systemImage: "book").font(.subheadline.weight(.semibold))
                    }
                }
                if let me = account.me {
                    HStack(spacing: 8) { Avatar(photo: me.photo, name: me.handle, size: 26); Text("Posting as ") + Text(me.handle).bold() }.font(.subheadline)
                } else {
                    TextField("Your first name or camp (optional)", text: $name)
                    TextField("Email (optional, never shown)", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Sign in to post with your camp name and photo") { signingIn = true }.buttonStyle(.borderless).font(.footnote)
                }
                Button(sending ? "Posting…" : "Ask campers") { ask() }.disabled(sending)
                if !note.isEmpty { Text(note).font(.footnote).foregroundColor(.secondary) }
            } header: {
                Text("Ask a question")
            } footer: {
                Text("You can edit or delete your posts from this phone. Add an email only if you want to do that from another device later. By posting you agree to the [terms](https://qcampfire.com/terms): be kind, nothing objectionable.")
            }

            Section {
                DisclosureGroup("Posted from another device?") {
                    Text("If you gave an email when you posted, enter it here. We send a code that lets this phone edit and delete those posts.").font(.footnote).foregroundColor(.secondary)
                    TextField("you@example.com", text: $backEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Email me a code") { sendCode() }.buttonStyle(.borderless)
                    if backSent {
                        TextField("6-digit code", text: $backCode).keyboardType(.numberPad).textContentType(.oneTimeCode)
                        Button("Unlock my posts") { useCode() }.buttonStyle(.borderless)
                    }
                    if !backNote.isEmpty { Text(backNote).font(.footnote).foregroundColor(.secondary) }
                }
                .font(.subheadline)
            }

            Section {
                Picker("Show", selection: $show) {
                    Text("All \(visible.count)").tag("all")
                    Text("Needs an answer \(waiting.count)").tag("open")
                    Text("Answered \(done.count)").tag("done")
                }
                .pickerStyle(.segmented)
                if !waiting.isEmpty && show != "done" {
                    Text(waiting.count == 1 ? "1 question needs an answer. Can you help?" : "\(waiting.count) questions need an answer. Can you help?")
                        .font(.subheadline.weight(.semibold)).foregroundColor(Theme.accent)
                }
                if !loaded {
                    if failed { Text("Questions need a signal to load. Pull down to try again.").foregroundColor(.secondary) }
                    else { ProgressView().frame(maxWidth: .infinity) }
                } else if visible.isEmpty {
                    Text("No questions yet. Be the first.").foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color.clear)

            ForEach(shown) { q in
                Section {
                    DisclosureGroup {
                        HStack(spacing: 6) { if q.acct { Avatar(photo: q.photo, name: q.name, size: 22) }; Text(byline(q)).font(.footnote).foregroundColor(.secondary) }
                        if q.waiting { Text("Only you can see this until a quick check passes it.").font(.footnote).italic().foregroundColor(.secondary) }
                        mine(question: q.id, answer: "", text: q.text, joined: false, own: q.mine)
                        reportButton(question: q.id, answer: "", own: q.mine)
                        ForEach(ordered(q.answers)) { a in
                            VStack(alignment: .leading, spacing: 6) {
                                if a.guide { Text("From the guide: " + a.title).font(.subheadline.weight(.semibold)).foregroundColor(Theme.primary) }
                                Text(a.text).font(.subheadline).textSelection(.enabled)
                                HStack(spacing: 6) { if a.acct && !a.guide && a.said <= 1 { Avatar(photo: a.photo, name: a.name, size: 22) }; Text(byline(a)).font(.footnote).foregroundColor(.secondary) }
                                if a.waiting { Text("Only you can see this until a quick check passes it.").font(.footnote).italic().foregroundColor(.secondary) }
                                Button {
                                    thank(q.id, a.id)
                                } label: {
                                    Label(thanksLabel(a), systemImage: MyPosts.thanked(a.id) ? "hand.thumbsup.fill" : "hand.thumbsup")
                                }
                                .buttonStyle(.borderless).font(.footnote)
                                .disabled(MyPosts.thanked(a.id))
                                if !a.guide { mine(question: q.id, answer: a.id, text: a.text, joined: a.said > 1, own: a.mine) }
                                if !a.guide { reportButton(question: q.id, answer: a.id, own: a.mine) }
                            }
                            .padding(.vertical, 2)
                        }
                        TextField("Know the answer? Share it.", text: Binding(get: { drafts[q.id] ?? "" }, set: { drafts[q.id] = $0 }), axis: .vertical).lineLimit(1...4)
                        Button("Answer") { answer(q.id) }.buttonStyle(.borderless)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(q.text).font(.subheadline.weight(.semibold))
                            if q.answers.isEmpty {
                                Text("Needs an answer").font(.caption.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Theme.accent).foregroundColor(.white).clipShape(Capsule())
                            } else {
                                Text(countLabel(q)).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.page)
        .navigationTitle("Questions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $signingIn, onDismiss: { Task { await load() } }) { AccountView() }
    }

    // Small pieces of text, worked out here so the screen layout above stays simple.
    private func byline(_ q: Question) -> String {
        let who = q.name.isEmpty ? "A camper" : q.name
        return who + " · " + Site.ago(q.ts) + (q.edited ? " · edited" : "")
    }
    private func byline(_ a: QAnswer) -> String {
        var who = a.name.isEmpty ? "A camper" : a.name
        if a.guide { who = "Matched by the AI check" } else if a.said > 1 { who = String(a.said) + " campers said this" }
        return who + " · " + Site.ago(a.ts)
    }
    private func thanksLabel(_ a: QAnswer) -> String { a.up > 0 ? "Thanks · " + String(a.up) : "Thanks" }
    private func countLabel(_ q: Question) -> String { q.answers.count == 1 ? "1 answer" : String(q.answers.count) + " answers" }
    // Most-thanked answers first, then oldest first.
    private func ordered(_ answers: [QAnswer]) -> [QAnswer] {
        answers.sorted { x, y in x.up != y.up ? x.up > y.up : x.ts < y.ts }
    }

    // Edit and Delete, shown only on this phone's own posts.
    @ViewBuilder
    private func mine(question: String, answer: String, text: String, joined: Bool, own: Bool) -> some View {
        let id = answer.isEmpty ? question : answer
        let key = MyPosts.key(id) ?? ""     // an account owns its posts on any phone, with no key
        if !key.isEmpty || own, !joined {
            if editing == id {
                TextField("Your words", text: $editText, axis: .vertical).lineLimit(1...5)
                HStack {
                    Button("Save") { change(question, answer, key, "edit", editText) }.buttonStyle(.borderless)
                    Spacer()
                    Button("Cancel") { editing = "" }.buttonStyle(.borderless)
                }
            } else {
                HStack {
                    Text("Yours").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                    Button("Edit") { editText = text; editing = id }.buttonStyle(.borderless)
                    Button("Delete", role: .destructive) { change(question, answer, key, "delete", "") }.buttonStyle(.borderless)
                }
                .font(.footnote)
            }
        }
    }

    // Report, shown on other people's posts. It tells the owner and hides the post on this phone.
    @ViewBuilder
    private func reportButton(question: String, answer: String, own: Bool) -> some View {
        let id = answer.isEmpty ? question : answer
        if MyPosts.key(id) == nil && !own {
            Button(role: .destructive) {
                Hidden.add(id)
                note = "Reported, and hidden on this phone. Thank you."
                Task { await Site.report(question: question, answer: answer) }
            } label: {
                Label("Report", systemImage: "flag")
            }
            .buttonStyle(.borderless).font(.footnote)
        }
    }

    private func sendCode() {
        let e = backEmail.trimmingCharacters(in: .whitespaces)
        if e.isEmpty { return }
        backSent = true
        backNote = "If posts were made with that address, a code is on its way. Check your inbox, spam and Promotions."
        Task { await Site.recoverCode(email: e) }
    }

    private func useCode() {
        let e = backEmail.trimmingCharacters(in: .whitespaces), c = backCode.trimmingCharacters(in: .whitespaces)
        if c.isEmpty { return }
        Task {
            do {
                let keys = try await Site.recoverKeys(email: e, code: c)
                for (id, key) in keys { MyPosts.keep(id, key) }
                email = e
                backCode = ""
                backSent = false
                backNote = String(keys.count) + " of your posts can now be edited here."
                await load()
            } catch let error as SiteError { backNote = error.message }
            catch { backNote = "That code did not work. Check it, or ask for a new one." }
        }
    }

    private func load() async {
        do { rows = try await Site.questions(); failed = false; loaded = true }
        catch { failed = true }
    }

    private func ask() {
        let text = asking.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count < 8 { note = "Write a few more words so campers know what you need."; return }
        sending = true
        note = ""
        Task {
            do {
                let made = try await Site.ask(text: text, name: name, email: email)
                MyPosts.keep(made.id, made.key)
                asking = ""
                note = "Posted. You can see it now; other campers will see it after a quick check."
                await load()
            } catch let error as SiteError { note = error.message }
            catch { note = "That did not post. Check your signal and try again." }
            sending = false
        }
    }

    private func answer(_ qid: String) {
        let text = (drafts[qid] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count < 2 { return }
        Task {
            do {
                let made = try await Site.answer(question: qid, text: text, name: name, email: email)
                MyPosts.keep(made.id, made.key)
                drafts[qid] = ""
                await load()
            } catch let error as SiteError { note = error.message }
            catch { note = "That did not post. Check your signal and try again." }
        }
    }

    private func thank(_ qid: String, _ aid: String) {
        Task {
            if (try? await Site.thanks(question: qid, answer: aid)) != nil {
                MyPosts.keepThanks(aid)
                await load()
            }
        }
    }

    private func change(_ qid: String, _ aid: String, _ key: String, _ action: String, _ text: String) {
        Task {
            do {
                try await Site.mine(question: qid, answer: aid, key: key, action: action, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
                editing = ""
                await load()
            } catch let error as SiteError { note = error.message }
            catch { note = "That did not save. Try again." }
        }
    }
}
