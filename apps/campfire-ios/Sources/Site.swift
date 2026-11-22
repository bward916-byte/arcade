import Foundation

// One ad, as the site sends it.
struct Listing: Identifiable, Hashable {
    let id: String
    var title: String
    var price: String
    var cat: String
    var area: String
    var text: String
    var photos: [String]
    var sold: Bool
    var ts: Double
    var amount: Double?
}

struct AlertPost: Identifiable {
    let id: String
    let text: String
    let photo: String
    let link: String
    let ts: Double
}

struct Category: Identifiable {
    let id: String
    let name: String
}

struct SiteError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// Everything the app asks the website for.
enum Site {
    static let base = URL(string: "https://qcampfire.com")!

    static let cats: [Category] = [
        Category(id: "rv", name: "RV parts and solar"), Category(id: "camp", name: "Camping gear"),
        Category(id: "rocks", name: "Rocks and gems"), Category(id: "wheels", name: "Vehicles and off-road"),
        Category(id: "tools", name: "Tools"), Category(id: "home", name: "Household"),
        Category(id: "free", name: "Free"), Category(id: "wanted", name: "Wanted"), Category(id: "services", name: "Services")
    ]
    static let areas: [String: String] = [
        "plomosa": "Plomosa Road", "hijolly": "Hi Jolly", "domerock": "Dome Rock", "scaddan": "Scaddan Wash",
        "lpnorth": "La Posa North", "lpwest": "La Posa West", "lptyson": "La Posa Tyson Wash", "lpsouth": "La Posa South",
        "roadrunner": "Road Runner", "town": "In town", "other": "Somewhere else"
    ]

    static func catName(_ id: String) -> String {
        cats.first(where: { $0.id == id })?.name ?? "Other"
    }

    static func photo(_ id: String) -> URL {
        base.appendingPathComponent("_blob").appendingPathComponent(id)
    }

    // The link people share. It shows the price, title and photo when pasted into Facebook or a text.
    static func link(_ id: String) -> URL {
        base.appendingPathComponent("l").appendingPathComponent(id)
    }

    static func ago(_ ts: Double) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: Date(timeIntervalSince1970: ts / 1000), relativeTo: Date())
    }

    static func listings() async throws -> [Listing] {
        let url = base.appendingPathComponent("api").appendingPathComponent("docs").appendingPathComponent("listings")
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        var out: [Listing] = []
        for row in rows {
            guard let id = row["id"] as? String, let d = row["data"] as? [String: Any], let title = d["title"] as? String else { continue }
            out.append(Listing(
                id: id,
                title: title,
                price: d["price"] as? String ?? "",
                cat: d["cat"] as? String ?? "",
                area: d["area"] as? String ?? "",
                text: d["text"] as? String ?? "",
                photos: d["photos"] as? [String] ?? [],
                sold: d["sold"] as? Bool ?? false,
                ts: (d["ts"] as? NSNumber)?.doubleValue ?? 0,
                amount: (d["amount"] as? NSNumber)?.doubleValue
            ))
        }
        return out
    }

    // The guide, show dates and map pins. The site lays the owner's edits over it before sending.
    static func guide() async throws -> Data {
        let url = base.appendingPathComponent("api").appendingPathComponent("guide")
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 { throw SiteError(message: "The guide did not load.") }
        return data
    }

    // Weather alerts and local news.
    static func alerts() async throws -> [AlertPost] {
        let url = base.appendingPathComponent("api").appendingPathComponent("docs").appendingPathComponent("posts")
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        var out: [AlertPost] = []
        for row in rows {
            guard let id = row["id"] as? String, let d = row["data"] as? [String: Any] else { continue }
            if (d["board"] as? String) != "alerts" || (d["parent"] as? String ?? "") != "" { continue }
            let text = d["text"] as? String ?? ""
            let photo = d["photo"] as? String ?? ""
            if text.isEmpty && photo.isEmpty { continue }
            out.append(AlertPost(id: id, text: text, photo: photo, link: d["url"] as? String ?? "", ts: (d["ts"] as? NSNumber)?.doubleValue ?? 0))
        }
        return out.sorted { $0.ts > $1.ts }
    }

    // One photo for a new ad. The site checks it before it shows.
    static func upload(photo: Data) async throws -> String {
        var req = URLRequest(url: base.appendingPathComponent("api").appendingPathComponent("photos"))
        req.httpMethod = "POST"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: req, from: photo)
        let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw SiteError(message: body?["error"] as? String ?? "A photo did not upload. Try again.")
        }
        guard let id = body?["id"] as? String else { throw SiteError(message: "A photo did not upload. Try again.") }
        return id
    }

    // A new ad. The site emails a link that publishes it. In test mode it hands the link straight back.
    static func post(ad: [String: Any]) async throws -> String? {
        var req = URLRequest(url: base.appendingPathComponent("api").appendingPathComponent("ads"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ad)
        let (data, response) = try await URLSession.shared.data(for: req)
        let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw SiteError(message: body?["error"] as? String ?? "That did not go through. Check your signal and try again.")
        }
        return body?["testLink"] as? String
    }

    // A buyer's message. The site emails it to the seller; the seller's address is never shown.
    // Sends a correction or a missing listing to the owner. No account needed.
    static func suggest(kind: String, listing: String, details: String) async throws {
        let url = base.appendingPathComponent("api").appendingPathComponent("suggest")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["kind": kind, "listing": listing, "details": details])
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw SiteError(message: body?["error"] as? String ?? "That did not send. Try again in a moment.")
        }
    }

    static func contact(id: String, message: String, from: String) async throws {
        let url = base.appendingPathComponent("api").appendingPathComponent("ads").appendingPathComponent(id).appendingPathComponent("contact")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["message": message, "from": from])
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw SiteError(message: body?["error"] as? String ?? "That did not send. Try again in a moment.")
        }
    }
}
