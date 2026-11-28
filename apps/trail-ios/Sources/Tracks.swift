import Foundation
import CoreLocation

struct TrackPoint: Codable {
    let lat: Double
    let lon: Double
    let ele: Double
    let t: Date
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

struct Track: Codable, Identifiable {
    var id = UUID()
    var name: String
    var started: Date
    var miles: Double
    var points: [TrackPoint]
}

struct Waypoint: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var lat: Double
    var lon: Double
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

// Records a track from the phone's GPS. It keeps going with the screen off because the app declares the location
// background mode; iOS shows its blue location indicator while that is happening.
final class Tracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var recording = false
    @Published var points: [TrackPoint] = []
    @Published var miles = 0.0
    @Published var clock = "0:00"
    @Published var elevationText = ""
    @Published var note = ""
    private let manager = CLLocationManager()
    private var started = Date()
    private var last: CLLocation?
    private var timer: Timer?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            note = "Location is off for this app. Turn it on in Settings to record."
            return
        }
        if status == .notDetermined { manager.requestWhenInUseAuthorization() }
        points = []
        miles = 0
        last = nil
        started = Date()
        clock = "0:00"
        elevationText = ""
        note = ""
        recording = true
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    // Ends the recording. Returns nil when it is too short to be worth keeping.
    func stop() -> Track? {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        timer?.invalidate()
        timer = nil
        recording = false
        let kept = points
        points = []
        guard kept.count > 1 else {
            note = "Nothing recorded: the phone had no GPS fix yet."
            return nil
        }
        let name = "Track " + started.formatted(date: .abbreviated, time: .shortened)
        note = String(format: "Saved %.2f mi", miles)
        return Track(name: name, started: started, miles: miles, points: kept)
    }

    private func tick() {
        let s = Int(Date().timeIntervalSince(started))
        clock = s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard recording else { return }
        for place in locations where place.horizontalAccuracy >= 0 && place.horizontalAccuracy <= 50 {
            if let last { miles += place.distance(from: last) / 1609.344 }
            last = place
            points.append(TrackPoint(lat: place.coordinate.latitude, lon: place.coordinate.longitude, ele: place.altitude, t: place.timestamp))
            elevationText = String(format: "%.0f ft", place.altitude * 3.28084)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if recording && (status == .denied || status == .restricted) {
            _ = stop()
            note = "Location is off for this app. Turn it on in Settings to record."
        }
    }
}

// Saved tracks and waypoints, kept as two JSON files in the app's Documents folder on the phone.
final class Store: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var waypoints: [Waypoint] = []
    private let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var tracksFile: URL { folder.appendingPathComponent("tracks.json") }
    private var waypointsFile: URL { folder.appendingPathComponent("waypoints.json") }

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: tracksFile), let saved = try? decoder.decode([Track].self, from: data) { tracks = saved }
        if let data = try? Data(contentsOf: waypointsFile), let saved = try? decoder.decode([Waypoint].self, from: data) { waypoints = saved }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(tracks) { try? data.write(to: tracksFile, options: .atomic) }
        if let data = try? encoder.encode(waypoints) { try? data.write(to: waypointsFile, options: .atomic) }
    }

    func add(track: Track) { tracks.insert(track, at: 0); save() }
    func add(waypoint: Waypoint) { waypoints.append(waypoint); save() }
    func removeTracks(at offsets: IndexSet) { for i in offsets.sorted(by: >) { tracks.remove(at: i) }; save() }
    func removeWaypoints(at offsets: IndexSet) { for i in offsets.sorted(by: >) { waypoints.remove(at: i) }; save() }

    // A GPX copy of a track for sharing, written to the temporary folder.
    func gpxFile(for track: Track) -> URL? {
        let stamp = ISO8601DateFormatter()
        var text = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\" creator=\"TrailApp\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n<trk><name>"
        text += track.name.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        text += "</name><trkseg>\n"
        for p in track.points {
            text += String(format: "<trkpt lat=\"%.6f\" lon=\"%.6f\"><ele>%.1f</ele><time>", p.lat, p.lon, p.ele) + stamp.string(from: p.t) + "</time></trkpt>\n"
        }
        text += "</trkseg></trk>\n</gpx>\n"
        let safe = track.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ".")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(safe + ".gpx")
        do { try text.write(to: file, atomically: true, encoding: .utf8); return file } catch { return nil }
    }
}
