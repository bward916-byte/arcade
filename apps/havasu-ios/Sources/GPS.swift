import SwiftUI
import CoreLocation
import UIKit

// "My GPS coordinates" for an emergency: the numbers shown large, with the nearest landmark and ways to pass them on.
// The position is worked out on the phone and is never sent to the site.

final class OneFix: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var place: CLLocation?
    @Published var note = ""
    @Published var busy = false
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func find() {
        busy = true
        note = ""
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted { fail(); return }
        if status == .notDetermined { manager.requestWhenInUseAuthorization() } else { manager.requestLocation() }
    }

    private func fail() {
        busy = false
        note = "Your phone did not share its location. Allow location for Campfire in Settings, then tap again. Or open Maps and press and hold on the blue dot."
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard busy else { return }
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways { manager.requestLocation() }
        else if status == .denied || status == .restricted { fail() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last { place = last; busy = false }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { fail() }
}

struct GPSCard: View {
    let pins: [Pin]
    @StateObject private var fix = OneFix()
    @State private var copied = false

    private func numbers(_ p: CLLocation) -> String { String(format: "%.5f, %.5f", p.coordinate.latitude, p.coordinate.longitude) }
    private func feet(_ p: CLLocation) -> Int { Int((p.horizontalAccuracy * 3.28 / 10).rounded()) * 10 }

    // "About 2.1 miles west of Dome Rock", from the nearest camping pin or sight.
    private func near(_ p: CLLocation) -> String {
        var best: (name: String, d: Double, dx: Double, dy: Double)?
        for pin in pins where pin.kind == "ltva" || pin.kind == "free" || pin.kind == "see" {
            let dy = (p.coordinate.latitude - pin.lat) * 69, dx = (p.coordinate.longitude - pin.lon) * 57.6, d = (dx * dx + dy * dy).squareRoot()
            if best == nil || d < best!.d { best = (pin.name, d, dx, dy) }
        }
        guard let b = best, b.d <= 60 else { return "" }
        if b.d < 0.15 { return "At " + b.name }
        let angle = (atan2(b.dx, b.dy) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        let dir = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"][Int((angle / 45).rounded()) % 8]
        return "About " + (b.d < 10 ? String(format: "%.1f", b.d) : String(Int(b.d.rounded()))) + " miles " + dir + " of " + b.name
    }

    private func message(_ p: CLLocation) -> String {
        let where_ = near(p)
        return "My location: " + numbers(p) + " (GPS, within about \(feet(p)) feet)." + (where_.isEmpty ? "" : " " + where_ + ", near Lake Havasu City, Arizona.")
            + " Map: https://maps.apple.com/?ll=" + String(format: "%.5f,%.5f", p.coordinate.latitude, p.coordinate.longitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A campsite has no address. Your phone can give your exact position, even with no signal.").font(.subheadline)
            Button {
                copied = false
                fix.find()
            } label: {
                Label(fix.place == nil ? "Show my GPS coordinates" : "Update my coordinates", systemImage: "location.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent)
            if fix.busy { Text("Finding where you are…").font(.footnote).foregroundColor(.secondary) }
            if !fix.note.isEmpty { Text(fix.note).font(.footnote).foregroundColor(Theme.accent) }
            if let p = fix.place {
                Text(numbers(p)).font(.system(size: 26, weight: .bold, design: .rounded)).textSelection(.enabled).minimumScaleFactor(0.7).lineLimit(1)
                Text("Good to within about \(feet(p)) feet." + (near(p).isEmpty ? "" : " " + near(p) + ".")).font(.subheadline)
                Text("Read the two numbers to the 911 dispatcher exactly as shown: latitude first, then longitude. The minus sign means west.")
                    .font(.footnote).foregroundColor(.secondary)
                HStack(spacing: 10) {
                    Link(destination: URL(string: "tel:911")!) { Label("Call 911", systemImage: "phone.fill") }.buttonStyle(.borderedProminent).tint(Theme.accent)
                    ShareLink(item: message(p)) { Label("Share", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                    Button {
                        UIPasteboard.general.string = message(p)
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
    }
}
