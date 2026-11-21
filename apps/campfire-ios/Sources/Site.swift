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
    static let base = URL(string: "https://quartzsitecampfire.runasp.net")!

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

    // A buyer's message. The site emails it to the seller; the seller's address is never shown.
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
