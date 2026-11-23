import SwiftUI
import MapKit

// Who manages the ground: BLM land, the camping areas, the reservation, town limits, refuges and the state line.
// The shapes come from the site's bounds.json; a copy ships inside the app so they work with no signal.

struct LandLayer: Identifiable {
    let id: String
    let name: String
    let color: UIColor
    let fill: CGFloat
    let dashed: Bool
}

let landLayers: [LandLayer] = [
    LandLayer(id: "blm", name: "BLM land", color: UIColor(red: 181 / 255, green: 137 / 255, blue: 0, alpha: 1), fill: 0.26, dashed: false),
    LandLayer(id: "free", name: "Free 14-day camping areas", color: UIColor(red: 194 / 255, green: 87 / 255, blue: 26 / 255, alpha: 1), fill: 0.18, dashed: false),
    LandLayer(id: "ltva", name: "La Posa long-term area (permit)", color: UIColor(red: 15 / 255, green: 118 / 255, blue: 110 / 255, alpha: 1), fill: 0.2, dashed: false),
    LandLayer(id: "crit", name: "CRIT reservation", color: UIColor(red: 156 / 255, green: 54 / 255, blue: 181 / 255, alpha: 1), fill: 0.14, dashed: true),
    LandLayer(id: "town", name: "Quartzsite town limits", color: UIColor(red: 55 / 255, green: 65 / 255, blue: 81 / 255, alpha: 1), fill: 0.05, dashed: true),
    LandLayer(id: "refuge", name: "Wildlife refuges (Kofa)", color: UIColor(red: 47 / 255, green: 158 / 255, blue: 68 / 255, alpha: 1), fill: 0.16, dashed: false),
    LandLayer(id: "state", name: "Arizona / California line", color: UIColor(red: 17 / 255, green: 24 / 255, blue: 39 / 255, alpha: 1), fill: 0, dashed: true)]

// The answer to "Am I on BLM land?"
struct LandAnswer: Equatable {
    let onBLM: Bool?      // nil when the map cannot say
    let words: String
}

@MainActor
final class LandStore: ObservableObject {
    @Published var overlays: [String: [MKOverlay]] = [:]   // by layer id, each overlay titled with that id
    private var shapes: [(id: String, name: String, rings: [[CLLocationCoordinate2D]])] = []

    private var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("bounds.json")
    }

    // The copy inside the app first, so the map has BLM land at once; then a fresher one from the site if there is signal.
    func load() async {
        if overlays.isEmpty {
            let saved = (try? Data(contentsOf: cacheFile)) ?? Bundle.main.url(forResource: "bounds", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
            if let saved { build(saved) }
        }
        if let (fresh, response) = try? await URLSession.shared.data(from: Site.base.appendingPathComponent("bounds.json")),
           (response as? HTTPURLResponse)?.statusCode == 200, build(fresh) {
            try? fresh.write(to: cacheFile)
        }
    }

    @discardableResult
    private func build(_ data: Data) -> Bool {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let layers = json["layers"] as? [[String: Any]] else { return false }
        var made: [String: [MKOverlay]] = [:]
        var found: [(id: String, name: String, rings: [[CLLocationCoordinate2D]])] = []
        for layer in layers {
            guard let id = layer["id"] as? String else { continue }
            var list: [MKOverlay] = []
            for area in layer["areas"] as? [[String: Any]] ?? [] {
                let name = area["n"] as? String ?? ""
                for text in area["l"] as? [String] ?? [] {
                    let pts = LandStore.decode(text)
                    let line = MKPolyline(coordinates: pts, count: pts.count)
                    line.title = id
                    list.append(line)
                }
                for poly in area["p"] as? [[String]] ?? [] {
                    let rings = poly.map { LandStore.decode($0) }.filter { $0.count > 2 }
                    guard let outer = rings.first else { continue }
                    let holes = rings.dropFirst().map { MKPolygon(coordinates: $0, count: $0.count) }
                    let shape = MKPolygon(coordinates: outer, count: outer.count, interiorPolygons: holes.isEmpty ? nil : Array(holes))
                    shape.title = id
                    list.append(shape)
                    found.append((id, name, rings))
                }
            }
            made[id] = list
        }
        guard made["blm"]?.isEmpty == false else { return false }
        overlays = made
        shapes = found
        return true
    }

    static func decode(_ text: String) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        let bytes = Array(text.utf8)
        var i = 0, lat = 0, lon = 0
        func next() -> Int {
            var result = 0, shift = 0
            while i < bytes.count {
                let b = Int(bytes[i]) - 63
                i += 1
                result |= (b & 31) << shift
                shift += 5
                if b < 32 { break }
            }
            return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        }
        while i < bytes.count {
            lat += next()
            lon += next()
            points.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5, longitude: Double(lon) / 1e5))
        }
        return points
    }

    private static func inside(_ y: Double, _ x: Double, _ ring: [CLLocationCoordinate2D]) -> Bool {
        var hit = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let yi = ring[i].latitude, xi = ring[i].longitude, yj = ring[j].latitude, xj = ring[j].longitude
            if (yi > y) != (yj > y), x < (xj - xi) * (y - yi) / (yj - yi) + xi { hit.toggle() }
            j = i
        }
        return hit
    }

    // Which mapped areas the point is inside, by layer id, with the area's name where it has one.
    private func areas(_ y: Double, _ x: Double) -> [String: String] {
        var hit: [String: String] = [:]
        for s in shapes where hit[s.id] == nil {
            if LandStore.inside(y, x, s.rings[0]) && !s.rings.dropFirst().contains(where: { LandStore.inside(y, x, $0) }) { hit[s.id] = s.name }
        }
        return hit
    }

    // The same wording as the website.
    func answer(_ at: CLLocationCoordinate2D, accuracy: Double) -> LandAnswer {
        if shapes.isEmpty { return LandAnswer(onBLM: nil, words: "You are at the blue dot. The land boundaries have not loaded, so the map cannot say whose land it is.") }
        let y = at.latitude, x = at.longitude, a = areas(y, x)
        let near = accuracy > 60 ? " Your phone is only sure of your position to about \(Int((accuracy * 3.28 / 10).rounded()) * 10) feet." : ""
        func named(_ key: String, _ fallback: String) -> String { let n = a[key] ?? ""; return n.isEmpty ? fallback : n }
        if a["ltva"] != nil { return LandAnswer(onBLM: true, words: "Yes. You are in the \(named("ltva", "La Posa")) long-term area, on BLM land. A permit is needed to camp here." + near) }
        if a["free"] != nil { return LandAnswer(onBLM: true, words: "Yes. You are on BLM land, in the \(named("free", "free")) 14-day camping area. Camping is free for up to 14 days in any 28." + near) }
        if a["blm"] != nil { return LandAnswer(onBLM: true, words: "Yes. You are on BLM land. Camping is generally allowed for up to 14 days unless the area is posted closed." + near) }
        if a["crit"] != nil { return LandAnswer(onBLM: false, words: "No. You are not on BLM land. This is the Colorado River Indian Tribes reservation; tribal rules and permits apply." + near) }
        if a["refuge"] != nil { return LandAnswer(onBLM: false, words: "No. You are not on BLM land. This is a national wildlife refuge, with its own rules." + near) }
        if a["town"] != nil { return LandAnswer(onBLM: false, words: "No. You are not on BLM land. You are inside Quartzsite town limits." + near) }
        if y < 33.2 || y > 34.25 || x < -114.75 || x > -113.85 { return LandAnswer(onBLM: nil, words: "You are outside the area this map covers, so it cannot say whose land you are on.") }
        return LandAnswer(onBLM: false, words: "No. You are not on BLM land, as far as this map knows. It is likely private or state land. The map covers the Arizona side only." + near)
    }
}
