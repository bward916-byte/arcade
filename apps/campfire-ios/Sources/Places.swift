import SwiftUI
import MapKit
import CoreLocation

// The Map tab, matching the website's map: every listed place as a pin with its own icon, on/off buttons for each kind,
// route layers (BLM routes, off-road tracks, hiking trails), a satellite view, a list of places and "Where am I".

struct PinGroup: Identifiable {
    let id: String
    let name: String
    let kinds: [String]
    let symbol: String
    let color: UIColor
}

let pinGroups: [PinGroup] = [
    PinGroup(id: "camp", name: "Camping", kinds: ["ltva", "free"], symbol: "tent.fill", color: UIColor(red: 15 / 255, green: 118 / 255, blue: 110 / 255, alpha: 1)),
    PinGroup(id: "svc", name: "Services", kinds: ["svc"], symbol: "wrench.fill", color: UIColor(red: 37 / 255, green: 99 / 255, blue: 168 / 255, alpha: 1)),
    PinGroup(id: "food", name: "Food", kinds: ["food"], symbol: "fork.knife", color: UIColor(red: 194 / 255, green: 87 / 255, blue: 26 / 255, alpha: 1)),
    PinGroup(id: "med", name: "Medical", kinds: ["med"], symbol: "cross.fill", color: UIColor(red: 179 / 255, green: 38 / 255, blue: 30 / 255, alpha: 1)),
    PinGroup(id: "see", name: "Sights and trips", kinds: ["see"], symbol: "binoculars.fill", color: UIColor(red: 109 / 255, green: 74 / 255, blue: 168 / 255, alpha: 1))]

func pinGroup(_ kind: String) -> PinGroup {
    pinGroups.first { $0.kinds.contains(kind) } ?? pinGroups[4]
}

// One route layer: its button name, its colour, and the lines once they have loaded.
struct RouteLayer: Identifiable {
    let id: String
    let name: String
    let color: UIColor
}

let routeLayers: [RouteLayer] = [
    RouteLayer(id: "blm", name: "BLM routes", color: UIColor(red: 232 / 255, green: 89 / 255, blue: 12 / 255, alpha: 1)),
    RouteLayer(id: "off", name: "Off-road tracks", color: UIColor(red: 138 / 255, green: 90 / 255, blue: 43 / 255, alpha: 1)),
    RouteLayer(id: "hike", name: "Hiking trails", color: UIColor(red: 46 / 255, green: 125 / 255, blue: 50 / 255, alpha: 1))]

// Line colours by overlay title. BLM routes are split three ways, the same as on the website.
let routeColors: [String: UIColor] = [
    "blm-road": UIColor(red: 232 / 255, green: 89 / 255, blue: 12 / 255, alpha: 1),
    "blm-trail": UIColor(red: 194 / 255, green: 24 / 255, blue: 91 / 255, alpha: 1),
    "blm-limited": UIColor(red: 112 / 255, green: 72 / 255, blue: 232 / 255, alpha: 1),
    "off": UIColor(red: 138 / 255, green: 90 / 255, blue: 43 / 255, alpha: 1),
    "hike": UIColor(red: 46 / 255, green: 125 / 255, blue: 50 / 255, alpha: 1)]

// Loads the route lines from the site the first time a route button is turned on, and keeps a copy on the phone.
@MainActor
final class TrailStore: ObservableObject {
    @Published var overlays: [String: [MKMultiPolyline]] = [:]   // by layer id
    @Published var counts: [String: Int] = [:]
    @Published var loading = false
    @Published var failed = false

    private var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("trails.json")
    }

    func load() async {
        if !overlays.isEmpty || loading { return }
        loading = true
        failed = false
        var data: Data?
        if let (fresh, response) = try? await URLSession.shared.data(from: Site.base.appendingPathComponent("trails.json")),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            data = fresh
            try? fresh.write(to: cacheFile)
        } else {
            data = try? Data(contentsOf: cacheFile)
        }
        if let data, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            build(json)
        } else {
            failed = true
        }
        loading = false
    }

    private func build(_ json: [String: Any]) {
        var made: [String: [MKMultiPolyline]] = [:]
        var n: [String: Int] = [:]
        for key in ["off", "hike"] {
            var lines: [MKPolyline] = []
            for row in json[key] as? [[Any]] ?? [] where row.count > 1 {
                lines.append(TrailStore.line(row[1] as? String ?? ""))
            }
            let multi = MKMultiPolyline(lines)
            multi.title = key
            made[key] = [multi]
            n[key] = lines.count
        }
        // BLM: roads open to vehicles, vehicle trails, and limited use, each its own colour.
        let layerNames = json["blmLayers"] as? [String] ?? []
        var road: [MKPolyline] = [], trail: [MKPolyline] = [], limited: [MKPolyline] = []
        var seen = Set<String>()
        for row in json["blm"] as? [[Any]] ?? [] {
            guard row.count > 1, let enc = row[1] as? String, !seen.contains(enc) else { continue }
            seen.insert(enc)
            let line = TrailStore.line(enc)
            let layer = (row.count > 2 ? (row[2] as? NSNumber)?.intValue : nil).flatMap { $0 < layerNames.count ? layerNames[$0] : nil } ?? ""
            let use = row.count > 3 ? (row[3] as? String ?? "") : ""
            if use == "Limited" { limited.append(line) } else if layer.contains("Trails") { trail.append(line) } else { road.append(line) }
        }
        var blm: [MKMultiPolyline] = []
        for (title, lines) in [("blm-road", road), ("blm-trail", trail), ("blm-limited", limited)] where !lines.isEmpty {
            let multi = MKMultiPolyline(lines)
            multi.title = title
            blm.append(multi)
        }
        made["blm"] = blm
        n["blm"] = road.count + trail.count + limited.count
        overlays = made
        counts = n
    }

    // The lines arrive packed in Google's encoded-polyline form; this unpacks one.
    static func line(_ text: String) -> MKPolyline {
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
        return MKPolyline(coordinates: points, count: points.count)
    }
}

final class PlaceMark: NSObject, MKAnnotation {
    let pin: Pin
    let coordinate: CLLocationCoordinate2D
    var title: String? { pin.name }
    init(_ pin: Pin) {
        self.pin = pin
        self.coordinate = CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon)
    }
}

// Apple's map, wrapped so it can draw thousands of route lines and icon pins.
struct CampMap: UIViewRepresentable {
    let pins: [Pin]
    let overlays: [MKMultiPolyline]
    let satellite: Bool
    let focus: Pin?
    let focusCount: Int
    let locateCount: Int
    let onPick: (Pin) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 33.655, longitude: -114.215),
                                        span: MKCoordinateSpan(latitudeDelta: 0.28, longitudeDelta: 0.28))
        map.showsScale = true
        map.showsCompass = true
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.parent = self
        map.mapType = satellite ? .hybrid : .standard
        let pinKey = pins.map { $0.name }.joined(separator: "|")
        if pinKey != c.pinKey {
            c.pinKey = pinKey
            map.removeAnnotations(map.annotations.filter { $0 is PlaceMark })
            map.addAnnotations(pins.map { PlaceMark($0) })
        }
        let lineKey = overlays.map { $0.title ?? "" }.joined(separator: "|")
        if lineKey != c.lineKey {
            c.lineKey = lineKey
            map.removeOverlays(map.overlays)
            map.addOverlays(overlays, level: .aboveRoads)
        }
        if focusCount != c.focusCount, let pin = focus {
            c.focusCount = focusCount
            map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon),
                                             span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)), animated: true)
        }
        if locateCount != c.locateCount {
            c.locateCount = locateCount
            c.locator.requestWhenInUseAuthorization()
            map.showsUserLocation = true
            map.setUserTrackingMode(.follow, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CampMap
        var pinKey = "", lineKey = ""
        var focusCount = 0, locateCount = 0
        let locator = CLLocationManager()

        init(_ parent: CampMap) { self.parent = parent }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let mark = annotation as? PlaceMark else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "place") as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: mark, reuseIdentifier: "place")
            view.annotation = mark
            let group = pinGroup(mark.pin.kind)
            view.markerTintColor = group.color
            view.glyphImage = UIImage(systemName: group.symbol)
            view.displayPriority = mark.pin.area.isEmpty ? .defaultHigh : .required
            view.titleVisibility = .adaptive
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let mark = view.annotation as? PlaceMark { parent.onPick(mark.pin) }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let multi = overlay as? MKMultiPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKMultiPolylineRenderer(multiPolyline: multi)
            r.strokeColor = routeColors[multi.title ?? ""] ?? .brown
            r.lineWidth = 1.6
            return r
        }
    }
}

struct PlacesView: View {
    @EnvironmentObject private var guide: GuideStore
    @StateObject private var trails = TrailStore()
    @State private var picked: Pin?
    @State private var on: Set<String> = ["camp", "svc", "food", "med", "see"]   // place kinds showing
    @State private var routes: Set<String> = []                                   // route layers showing
    @State private var satellite = false
    @State private var listing = false
    @State private var focus: Pin?
    @State private var focusCount = 0
    @State private var locateCount = 0

    private var pins: [Pin] {
        (guide.data?.pins ?? []).filter { on.contains(pinGroup($0.kind).id) }
    }

    private var lines: [MKMultiPolyline] {
        routeLayers.filter { routes.contains($0.id) }.flatMap { trails.overlays[$0.id] ?? [] }
    }

    var body: some View {
        NavigationStack {
            CampMap(pins: pins, overlays: lines, satellite: satellite, focus: focus, focusCount: focusCount, locateCount: locateCount) { pin in
                picked = pin
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            textChip("All", on.count == pinGroups.count) { on = Set(pinGroups.map { $0.id }) }
                            textChip("None", on.isEmpty) { on = []; picked = nil }
                            ForEach(pinGroups) { g in
                                iconChip(g.name, g.symbol, Color(g.color), on.contains(g.id)) {
                                    if on.contains(g.id) { on.remove(g.id) } else { on.insert(g.id) }
                                }
                            }
                            ForEach(routeLayers) { layer in
                                lineChip(routeName(layer), Color(layer.color), routes.contains(layer.id)) { toggleRoute(layer.id) }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .background(Theme.page)
                    .swipeHint()
                    if trails.failed {
                        Text("The routes did not load. Check your signal.").font(.caption).padding(6).frame(maxWidth: .infinity).background(Theme.page)
                    } else if !routes.isEmpty {
                        Text("A line on the map does not mean a route is open, legal for your vehicle or passable.")
                            .font(.caption2).foregroundColor(.secondary).padding(.horizontal, 12).padding(.bottom, 6)
                            .frame(maxWidth: .infinity, alignment: .leading).background(Theme.page)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if picked == nil {
                    VStack(spacing: 10) {
                        roundButton(satellite ? "map" : "globe.americas.fill", satellite ? "Show the road map" : "Show satellite") { satellite.toggle() }
                        roundButton("location.fill", "Where am I") { locateCount += 1 }
                        roundButton("list.bullet", "List of places") { listing = true }
                    }
                    .padding(.trailing, 14)
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let pin = picked {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pin.name).font(.headline)
                                Text(pin.list ?? pinGroup(pin.kind).name).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                picked = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Close")
                        }
                        if let t = pin.text, !t.isEmpty {
                            Text(t).font(.subheadline).lineLimit(4)
                        }
                        Button {
                            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon)))
                            item.name = pin.name
                            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                        } label: {
                            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .padding()
                }
            }
            .sheet(isPresented: $listing) { placeList }
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // Every place now showing, by name. Tapping one moves the map there and opens it.
    private var placeList: some View {
        NavigationStack {
            List(pins.sorted { $0.name < $1.name }, id: \.name) { pin in
                Button {
                    listing = false
                    focus = pin
                    focusCount += 1
                    picked = pin
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: pinGroup(pin.kind).symbol).foregroundColor(.white).font(.caption)
                            .frame(width: 26, height: 26).background(Color(pinGroup(pin.kind).color)).clipShape(Circle())
                        Text(pin.name).foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("\(pins.count) places shown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { listing = false } } }
        }
    }

    private func routeName(_ layer: RouteLayer) -> String {
        if routes.contains(layer.id), trails.loading { return layer.name + " …" }
        if routes.contains(layer.id), let n = trails.counts[layer.id] { return layer.name + " " + String(n) }
        return layer.name
    }

    private func toggleRoute(_ id: String) {
        if routes.contains(id) { routes.remove(id) } else {
            routes.insert(id)
            Task { await trails.load() }
        }
    }

    private func chipShape<V: View>(_ selected: Bool, _ action: @escaping () -> Void, @ViewBuilder _ label: () -> V) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { label() }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(selected ? Theme.primary : Color(.systemBackground))
                .foregroundColor(selected ? .white : .primary)
                .clipShape(Capsule())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func textChip(_ name: String, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        chipShape(selected, action) { Text(name) }
    }

    // A place button: its icon on a coloured disc, then the name.
    private func iconChip(_ name: String, _ symbol: String, _ color: Color, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        chipShape(selected, action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                .frame(width: 20, height: 20).background(color).clipShape(Circle()).overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            Text(name)
        }
    }

    // A route button: a short line in the route's colour, then the name.
    private func lineChip(_ name: String, _ color: Color, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        chipShape(selected, action) {
            Capsule().fill(color).frame(width: 20, height: 5).overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
            Text(name)
        }
    }

    private func roundButton(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundColor(Theme.primary)
                .frame(width: 46, height: 46).background(.regularMaterial).clipShape(Circle()).shadow(radius: 2)
        }
        .accessibilityLabel(label)
    }
}
