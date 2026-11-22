import SwiftUI
import MapKit

// Camping areas, services and places worth a visit, on Apple Maps. Pick a kind at the top; tap a pin for directions.
struct PinGroup: Identifiable {
    let id: String
    let name: String
    let kinds: [String]
}

struct PlacesView: View {
    @EnvironmentObject private var guide: GuideStore
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.655, longitude: -114.215),
        span: MKCoordinateSpan(latitudeDelta: 0.28, longitudeDelta: 0.28))
    @State private var picked: Pin?
    @State private var show = ""   // "" is everything, else one group

    // The groups in the filter row and the pin kinds inside each.
    private let groups: [PinGroup] = [
        PinGroup(id: "camp", name: "Camping", kinds: ["ltva", "free"]), PinGroup(id: "svc", name: "Services", kinds: ["svc"]),
        PinGroup(id: "food", name: "Food", kinds: ["food"]), PinGroup(id: "med", name: "Medical", kinds: ["med"]),
        PinGroup(id: "see", name: "Sights and trips", kinds: ["see"])]

    private var pins: [Pin] {
        let all = guide.data?.pins ?? []
        guard let g = groups.first(where: { $0.id == show }) else { return all }
        return all.filter { g.kinds.contains($0.kind) }
    }

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: pins) { pin in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon)) {
                    Button {
                        picked = pin
                    } label: {
                        Circle()
                            .fill(color(pin.kind))
                            .frame(width: pin.area.isEmpty ? 16 : 22, height: pin.area.isEmpty ? 16 : 22)
                            .overlay(Circle().stroke(Color.white, lineWidth: pin.area.isEmpty ? 2 : 3))
                            .shadow(radius: 2)
                    }
                    .accessibilityLabel(pin.name)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("", "All", nil)
                        ForEach(groups) { g in chip(g.id, g.name, color(g.kinds[0])) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Theme.page)
                .swipeHint()
            }
            .safeAreaInset(edge: .bottom) {
                if let pin = picked {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pin.name).font(.headline)
                                Text(pin.list ?? kindName(pin.kind)).font(.subheadline).foregroundColor(.secondary)
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
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func color(_ kind: String) -> Color {
        switch kind {
        case "ltva": return Theme.primary
        case "free": return Theme.accent
        case "svc": return Color(red: 37 / 255, green: 99 / 255, blue: 168 / 255)
        case "food": return Color(red: 194 / 255, green: 87 / 255, blue: 26 / 255)
        case "med": return Color(red: 179 / 255, green: 38 / 255, blue: 30 / 255)
        default: return Color(red: 109 / 255, green: 74 / 255, blue: 168 / 255)
        }
    }

    private func kindName(_ kind: String) -> String {
        switch kind {
        case "ltva": return "Long Term Visitor Area"
        case "free": return "Camping"
        case "svc": return "Services"
        case "food": return "Food"
        case "med": return "Medical"
        default: return "Worth a visit"
        }
    }

    // One button in the filter row.
    private func chip(_ id: String, _ name: String, _ dot: Color?) -> some View {
        Button {
            show = id
            picked = nil
        } label: {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 10, height: 10) }
                Text(name)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(show == id ? Theme.primary : Color(.systemBackground))
            .foregroundColor(show == id ? .white : .primary)
            .clipShape(Capsule())
        }
        .accessibilityAddTraits(show == id ? .isSelected : [])
    }
}
