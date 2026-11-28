import SwiftUI

// A correction, a closed business or a missing place, sent to the owner without an account.
struct SuggestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "change"
    @State private var listing = ""
    @State private var details = ""
    @State private var sending = false
    @State private var problem = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Text("Thanks. It will be checked, and the guide updated if it holds up.")
                        Button("Done") { dismiss() }
                    }
                } else {
                    Section {
                        Picker("What is it?", selection: $kind) {
                            Text("Something is wrong").tag("change")
                            Text("A place is missing").tag("add")
                            Text("A place has closed").tag("remove")
                        }
                    }
                    Section("Which place or listing") {
                        TextField("Name of the place", text: $listing)
                    }
                    Section("What should it say") {
                        TextEditor(text: $details).frame(minHeight: 110)
                    }
                    if !problem.isEmpty {
                        Section { Text(problem).foregroundColor(Theme.accent) }
                    }
                    Section {
                        Button(sending ? "Sending…" : "Send") { send() }
                            .disabled(sending)
                    }
                }
            }
            .navigationTitle("Suggest a fix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func send() {
        let name = listing.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || text.isEmpty { problem = "Name the place and say what should change."; return }
        sending = true
        problem = ""
        Task {
            do {
                try await Site.suggest(kind: kind, listing: name, details: text)
                sent = true
            } catch let error as SiteError {
                problem = error.message
            } catch {
                problem = "That did not send. Check your signal and try again."
            }
            sending = false
        }
    }
}
