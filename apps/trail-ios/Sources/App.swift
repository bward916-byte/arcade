import SwiftUI

@main
struct TrailApp: App {
    var body: some Scene {
        WindowGroup { MainView() }
    }
}

struct MainView: View {
    @StateObject private var map = MapModel()
    @StateObject private var tracker = Tracker()
    @StateObject private var store = Store()
    @State private var showLayers = false
    @State private var showSaved = false
    @State private var pinName = ""

    var body: some View {
        ZStack {
            MapBox(model: map, store: store).ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        RoundButton(symbol: "square.3.layers.3d") { showLayers = true }
                        RoundButton(symbol: "location.fill") { map.followMe() }
                        RoundButton(symbol: "list.bullet") { showSaved = true }
                    }
                    .padding(.trailing, 12)
                }
                Spacer()
                RecordBar(tracker: tracker) { finished in
                    if let finished { store.add(track: finished) }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
        }
        .onChange(of: tracker.points.count) { _ in map.drawLive(tracker.points.map { $0.coordinate }) }
        .onChange(of: store.waypoints) { _ in map.showWaypoints(store.waypoints) }
        .sheet(isPresented: $showLayers) { LayersSheet(map: map).presentationDetents([.medium]) }
        .sheet(isPresented: $showSaved) {
            SavedSheet(store: store) { track in
                showSaved = false
                map.showSaved(track.points.map { $0.coordinate })
            } goTo: { pin in
                showSaved = false
                map.go(to: pin.coordinate)
            }
        }
        .alert("New waypoint", isPresented: Binding(get: { map.pendingPin != nil }, set: { if !$0 { map.pendingPin = nil } })) {
            TextField("Name", text: $pinName)
            Button("Save") {
                if let c = map.pendingPin {
                    store.add(waypoint: Waypoint(name: pinName.isEmpty ? "Waypoint" : pinName, lat: c.latitude, lon: c.longitude))
                }
                pinName = ""
                map.pendingPin = nil
            }
            Button("Cancel", role: .cancel) { pinName = ""; map.pendingPin = nil }
        } message: {
            Text("Press and hold anywhere on the map to drop one.")
        }
    }
}

struct RoundButton: View {
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(.regularMaterial, in: Circle())
        }
        .foregroundStyle(.primary)
        .shadow(radius: 2)
    }
}

// The strip along the bottom: start or stop recording, with distance and time while it runs.
struct RecordBar: View {
    @ObservedObject var tracker: Tracker
    let finished: (Track?) -> Void

    var body: some View {
        HStack(spacing: 14) {
            if tracker.recording {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f mi", tracker.miles)).font(.title3.weight(.semibold)).monospacedDigit()
                    Text(tracker.clock + "  ·  " + tracker.elevationText).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                Button {
                    finished(tracker.stop())
                } label: {
                    Label("Stop", systemImage: "stop.fill").font(.headline).padding(.horizontal, 18).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent).tint(.red)
            } else {
                Text(tracker.note.isEmpty ? "Ready to record a track" : tracker.note).font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button {
                    tracker.start()
                } label: {
                    Label("Record", systemImage: "record.circle").font(.headline).padding(.horizontal, 18).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent).tint(.green)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct LayersSheet: View {
    @ObservedObject var map: MapModel
    var body: some View {
        NavigationStack {
            Form {
                Section("Base map") {
                    Picker("Base map", selection: $map.basemap) {
                        Text("Topo").tag("topo")
                        Text("Satellite").tag("imagery")
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Toggle("Public land", isOn: $map.showLand)
                    if map.showLand {
                        HStack {
                            Text("Strength")
                            Slider(value: $map.landOpacity, in: 0.15...0.9)
                        }
                    }
                } header: {
                    Text("Land layers")
                } footer: {
                    Text("Colors show which agency manages the land (BLM, Forest Service, Park Service, state and others). Boundaries are approximate and are not a legal boundary.")
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SavedSheet: View {
    @ObservedObject var store: Store
    let show: (Track) -> Void
    let goTo: (Waypoint) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Tracks") {
                    if store.tracks.isEmpty { Text("No tracks yet. Tap Record on the map.").foregroundStyle(.secondary) }
                    ForEach(store.tracks) { track in
                        HStack {
                            Button { show(track) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.name).foregroundStyle(.primary)
                                    Text(String(format: "%.2f mi  ·  %@", track.miles, track.started.formatted(date: .abbreviated, time: .shortened)))
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let file = store.gpxFile(for: track) {
                                ShareLink(item: file) { Image(systemName: "square.and.arrow.up") }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                    .onDelete { store.removeTracks(at: $0) }
                }
                Section("Waypoints") {
                    if store.waypoints.isEmpty { Text("Press and hold on the map to drop a waypoint.").foregroundStyle(.secondary) }
                    ForEach(store.waypoints) { pin in
                        Button { goTo(pin) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pin.name).foregroundStyle(.primary)
                                Text(String(format: "%.5f, %.5f", pin.lat, pin.lon)).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.removeWaypoints(at: $0) }
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
