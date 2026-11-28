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

// The picture on a pin. The site names an icon for each kind of place; this is the matching Apple symbol.
func pinSymbol(_ pin: Pin) -> String {
    let names: [String: String] = ["tent": "tent.fill", "gem": "diamond.fill", "tire": "circle.circle.fill", "drop": "drop.fill", "pump": "fuelpump.fill",
        "mail": "envelope.fill", "cart": "cart.fill", "fork": "fork.knife", "wrench": "wrench.fill", "cross": "cross.fill", "bus": "bus.fill",
        "heart": "heart.fill", "flame": "flame.fill", "spot": "binoculars.fill"]
    if let icon = pin.icon, let symbol = names[icon] { return symbol }
    return pin.kind == "see" ? "diamond.fill" : pinGroup(pin.kind).symbol
}

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
    RouteLayer(id: "off", name: "Off-road tracks", color: UIColor(red: 30 / 255, green: 64 / 255, blue: 175 / 255, alpha: 1)),
    RouteLayer(id: "hike", name: "Hiking trails", color: UIColor(red: 21 / 255, green: 128 / 255, blue: 61 / 255, alpha: 1))]

// Line colours by overlay title. BLM routes are split three ways, the same as on the website.
let routeColors: [String: UIColor] = [
    "blm-road": UIColor(red: 232 / 255, green: 89 / 255, blue: 12 / 255, alpha: 1),
    "blm-trail": UIColor(red: 194 / 255, green: 24 / 255, blue: 91 / 255, alpha: 1),
    "blm-limited": UIColor(red: 112 / 255, green: 72 / 255, blue: 232 / 255, alpha: 1),
    "off": UIColor(red: 30 / 255, green: 64 / 255, blue: 175 / 255, alpha: 1),
    "hike": UIColor(red: 21 / 255, green: 128 / 255, blue: 61 / 255, alpha: 1)]

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
        if Site.live, let (fresh, response) = try? await URLSession.shared.data(from: Site.base.appendingPathComponent("trails.json")),
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
    let land: [MKOverlay]
    let landKey: String
    let satellite: Bool
    let focus: Pin?
    let focusCount: Int
    let locateCount: Int
    let onPick: (Pin) -> Void
    let onLocate: (CLLocationCoordinate2D?, Double) -> Void   // nil when the phone will not share its location

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 34.48, longitude: -114.27),
                                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
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
        let lineKey = landKey + "/" + overlays.map { $0.title ?? "" }.joined(separator: "|")
        if lineKey != c.lineKey {
            c.lineKey = lineKey
            map.removeOverlays(map.overlays)
            map.addOverlays(land, level: .aboveRoads)      // land underneath, route lines on top
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
            let status = c.locator.authorizationStatus
            let report = onLocate
            if status == .denied || status == .restricted {
                DispatchQueue.main.async { report(nil, 0) }
            } else if let here = map.userLocation.location {
                DispatchQueue.main.async { report(here.coordinate, here.horizontalAccuracy) }
            } else {
                c.waiting = true
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CampMap
        var pinKey = "", lineKey = ""
        var focusCount = 0, locateCount = 0
        var waiting = false          // asked "where am I" and no position has come back yet
        let locator = CLLocationManager()

        init(_ parent: CampMap) { self.parent = parent }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard waiting, let here = userLocation.location else { return }
            waiting = false
            parent.onLocate(here.coordinate, here.horizontalAccuracy)
        }

        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            guard waiting else { return }
            waiting = false
            parent.onLocate(nil, 0)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let mark = annotation as? PlaceMark else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "place") as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: mark, reuseIdentifier: "place")
            view.annotation = mark
            let group = pinGroup(mark.pin.kind)
            view.markerTintColor = group.color
            view.glyphImage = UIImage(systemName: pinSymbol(mark.pin))
            view.displayPriority = mark.pin.area.isEmpty ? .defaultHigh : .required
            view.titleVisibility = .adaptive
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let mark = view.annotation as? PlaceMark { parent.onPick(mark.pin) }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let shape = overlay as? MKPolygon, let layer = landLayers.first(where: { $0.id == shape.title }) {
                let r = MKPolygonRenderer(polygon: shape)
                r.fillColor = layer.color.withAlphaComponent(layer.fill)
                r.strokeColor = layer.color
                r.lineWidth = layer.id == "blm" ? 1 : 2
                if layer.dashed { r.lineDashPattern = [6, 5] }
                return r
            }
            if let line = overlay as? MKPolyline, let layer = landLayers.first(where: { $0.id == line.title }) {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = layer.color
                r.lineWidth = 2.5
                r.lineDashPattern = [8, 6]
                return r
            }
            guard let multi = overlay as? MKMultiPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKMultiPolylineRenderer(multiPolyline: multi)
            r.strokeColor = routeColors[multi.title ?? ""] ?? .brown
            // Hiking trails are short, so they are drawn thick. Off-road tracks are dotted, as on the website.
            r.lineWidth = multi.title == "hike" ? 4 : 1.6
            if multi.title == "off" { r.lineDashPattern = [2, 5]; r.lineCap = .round; r.lineWidth = 2 }
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
    @StateObject private var landStore = LandStore()
    @State private var landOn: Set<String> = ["blm", "free", "ltva"]            // land layers showing; BLM land from the start
    @State private var layering = false
    @State private var landAnswer: LandAnswer?
    @State private var finding = false
    @AppStorage("layHint") private var hintSeen = false

    private var landShown: [MKOverlay] {
        landLayers.filter { landOn.contains($0.id) }.flatMap { landStore.overlays[$0.id] ?? [] }
    }
    private var landKey: String {
        landLayers.filter { landOn.contains($0.id) && landStore.overlays[$0.id] != nil }.map { $0.id }.joined(separator: ",")
    }
    private var layerCount: Int { landOn.count + on.count + routes.count }

    private var pins: [Pin] {
        (guide.data?.pins ?? []).filter { on.contains(pinGroup($0.kind).id) }
    }

    private var lines: [MKMultiPolyline] {
        routeLayers.filter { routes.contains($0.id) }.flatMap { trails.overlays[$0.id] ?? [] }
    }

    var body: some View {
        NavigationStack {
            CampMap(pins: pins, overlays: lines, land: landShown, landKey: landKey, satellite: satellite, focus: focus, focusCount: focusCount, locateCount: locateCount,
                    onPick: { pin in picked = pin },
                    onLocate: { here, accuracy in
                        finding = false
                        if let here { landAnswer = landStore.answer(here, accuracy: accuracy) }
                        else { landAnswer = LandAnswer(onBLM: nil, words: "Your phone did not share its location. Allow location for Campfire in Settings, then tap again.") }
                    })
            .task { await landStore.load() }
            .onAppear { askIfSent() }
            .onReceive(NotificationCenter.default.publisher(for: LandAsk.note)) { _ in askIfSent() }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    if Site.live {
                    VStack(spacing: 8) {
                        Button {
                            finding = true
                            landAnswer = nil
                            locateCount += 1
                        } label: {
                            HStack(spacing: 14) {
                                LandArt()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Am I on BLM land?").font(.title3.weight(.bold))
                                    Text("Tap to see whose land you are standing on").font(.caption.weight(.semibold)).opacity(0.9)
                                }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .background(Theme.primary).foregroundColor(.white).cornerRadius(16)
                        .shadow(color: Theme.primary.opacity(0.35), radius: 6, y: 3)
                        Button {
                            hintSeen = true
                            layering = true
                        } label: {
                            Label("Layers · \(layerCount) on", systemImage: "square.3.layers.3d").font(.subheadline.weight(.bold))
                                .padding(.horizontal, 28).padding(.vertical, 9)
                        }
                        .background(Color(.systemBackground)).foregroundColor(Theme.primary).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.primary, lineWidth: 2))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Theme.page)
                    }
                    if finding {
                        Text("Finding where you are…").font(.footnote).padding(.horizontal, 12).padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading).background(Theme.page)
                    } else if let a = landAnswer {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(a.words).font(.subheadline.weight(.semibold))
                                Text("You are the blue dot. Edges are approximate; signs and fences on the ground decide.").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                            Button { landAnswer = nil } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                                .accessibilityLabel("Close")
                        }
                        .padding(10)
                        .background(a.onBLM == true ? Theme.soft : Color(.systemBackground))
                        .overlay(Rectangle().fill(a.onBLM == false ? Theme.accent : Theme.primary).frame(width: 5), alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !hintSeen && Site.live {
                        Text("Yellow is BLM land. Tap Layers to show trails, town limits, the reservation and more.")
                            .font(.caption).foregroundColor(.secondary).padding(.horizontal, 12).padding(.bottom, 6)
                            .frame(maxWidth: .infinity, alignment: .leading).background(Theme.page)
                    }
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
                            Text(CampWords.linked(t)).font(.subheadline).lineLimit(4)
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
            .sheet(isPresented: $layering) { layerList }
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
                        Image(systemName: pinSymbol(pin)).foregroundColor(.white).font(.caption)
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

    // Every layer with a plain on/off switch.
    private var layerList: some View {
        NavigationStack {
            List {
                Section("Land") {
                    ForEach(landLayers.filter { landStore.overlays[$0.id] != nil }) { layer in
                        Toggle(isOn: Binding(get: { landOn.contains(layer.id) }, set: { if $0 { landOn.insert(layer.id) } else { landOn.remove(layer.id) } })) {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 4).fill(Color(layer.color).opacity(0.45))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(layer.color), lineWidth: 2)).frame(width: 24, height: 18)
                                Text(layer.name)
                            }
                        }
                    }
                }
                Section("Places") {
                    ForEach(pinGroups) { g in
                        Toggle(isOn: Binding(get: { on.contains(g.id) }, set: { if $0 { on.insert(g.id) } else { on.remove(g.id) } })) {
                            HStack(spacing: 10) {
                                Image(systemName: g.symbol).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                    .frame(width: 24, height: 24).background(Color(g.color)).clipShape(Circle())
                                Text(g.name)
                            }
                        }
                    }
                }
                Section {
                    ForEach(routeLayers) { layer in
                        Toggle(isOn: Binding(get: { routes.contains(layer.id) }, set: { _ in toggleRoute(layer.id) })) {
                            HStack(spacing: 10) {
                                Capsule().fill(Color(layer.color)).frame(width: 24, height: 5)
                                Text(routeName(layer))
                            }
                        }
                    }
                } header: {
                    Text("Trails and routes")
                } footer: {
                    Text("A line on the map does not mean a route is open, legal for your vehicle or passable.")
                }
            }
            .tint(Theme.primary)
            .navigationTitle("Map layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { layering = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    // Another tab's "Am I on BLM land?" button sends people here; this asks straight away.
    private func askIfSent() {
        guard LandAsk.pending else { return }
        LandAsk.pending = false
        finding = true
        landAnswer = nil
        locateCount += 1
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

// The moving picture on the "Am I on BLM land?" button: rings spreading out from a dot, like a locator. Still when the phone asks for less motion.
struct LocatorPing: View {
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var out = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { n in
                Circle().stroke(Color.white, lineWidth: 3)
                    .scaleEffect(still ? 0.8 : (out ? 1.1 : 0.25))
                    .opacity(still ? (n == 0 ? 0.7 : 0) : (out ? 0 : 0.95))
                    .animation(still ? nil : .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(n) * 0.8), value: out)
            }
            Circle().fill(Color(red: 26 / 255, green: 115 / 255, blue: 232 / 255)).frame(width: 9, height: 9).overlay(Circle().stroke(Color.white, lineWidth: 2.5))
        }
        .frame(width: 42, height: 42)
        .onAppear { out = true }
        .accessibilityHidden(true)
    }
}

// The question asked from another tab: it opens the Map tab, and the map asks as soon as it shows.
enum LandAsk {
    static let note = Notification.Name("askLand")
    static var pending = false
    static func go() {
        pending = true
        NotificationCenter.default.post(name: note, object: nil)
    }
}

// The picture on every "Am I on BLM land?" button: sun, yellow BLM hills, a saguaro and a camper, with locator rings on the camper.
struct LandArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(red: 11 / 255, green: 79 / 255, blue: 75 / 255))
            Circle().fill(Color(red: 1, green: 209 / 255, blue: 102 / 255)).frame(width: 16, height: 16).offset(x: 28, y: -14)
            Hills(lift: 0).fill(Color(red: 233 / 255, green: 196 / 255, blue: 106 / 255))
            Hills(lift: 8).fill(Color(red: 212 / 255, green: 165 / 255, blue: 60 / 255))
            // saguaro
            Group {
                RoundedRectangle(cornerRadius: 2.5).frame(width: 5, height: 24).offset(x: -28, y: 6)
                RoundedRectangle(cornerRadius: 2).frame(width: 4, height: 9).offset(x: -35, y: 4)
                RoundedRectangle(cornerRadius: 2).frame(width: 9, height: 4).offset(x: -32, y: 9)
                RoundedRectangle(cornerRadius: 2).frame(width: 4, height: 8).offset(x: -21, y: 1)
                RoundedRectangle(cornerRadius: 2).frame(width: 9, height: 4).offset(x: -24, y: 5)
            }
            .foregroundColor(Color(red: 31 / 255, green: 122 / 255, blue: 77 / 255))
            // camper
            RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(width: 24, height: 12).offset(x: 10, y: 12)
            RoundedRectangle(cornerRadius: 1).fill(Color(red: 125 / 255, green: 211 / 255, blue: 252 / 255)).frame(width: 7, height: 5).offset(x: 5, y: 11)
            RoundedRectangle(cornerRadius: 1).fill(Color(red: 125 / 255, green: 211 / 255, blue: 252 / 255)).frame(width: 6, height: 5).offset(x: 15, y: 11)
            Circle().fill(Color.black).frame(width: 6, height: 6).offset(x: 4, y: 19)
            Circle().fill(Color.black).frame(width: 6, height: 6).offset(x: 17, y: 19)
            LocatorPing().offset(x: 10, y: 8)
        }
        .frame(width: 96, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.55), lineWidth: 2))
        .accessibilityHidden(true)
    }

    private struct Hills: Shape {
        let lift: CGFloat
        func path(in r: CGRect) -> Path {
            var p = Path()
            let top = r.height * 0.62 + lift
            p.move(to: CGPoint(x: 0, y: top + 6))
            p.addQuadCurve(to: CGPoint(x: r.width * 0.45, y: top + 4), control: CGPoint(x: r.width * 0.22, y: top - 16 + lift))
            p.addQuadCurve(to: CGPoint(x: r.width, y: top), control: CGPoint(x: r.width * 0.72, y: top + 14 - lift))
            p.addLine(to: CGPoint(x: r.width, y: r.height))
            p.addLine(to: CGPoint(x: 0, y: r.height))
            p.closeSubpath()
            return p
        }
    }
}

// The same button for other tabs.
struct LandAskButton: View {
    var body: some View {
        Button {
            LandAsk.go()
        } label: {
            HStack(spacing: 14) {
                LandArt()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Am I on BLM land?").font(.title3.weight(.bold))
                    Text("Opens the map and shows whose land you are on").font(.caption.weight(.semibold)).opacity(0.9)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Theme.primary, Color(red: 11 / 255, green: 79 / 255, blue: 75 / 255)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
