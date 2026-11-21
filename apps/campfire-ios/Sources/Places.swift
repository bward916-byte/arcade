import SwiftUI
import MapKit

// Camping areas and places worth a visit, on Apple Maps. Tap a pin for directions.
struct PlacesView: View {
    @EnvironmentObject private var guide: GuideStore
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.655, longitude: -114.215),
        span: MKCoordinateSpan(latitudeDelta: 0.28, longitudeDelta: 0.28))
    @State private var picked: Pin?

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: guide.data?.pins ?? []) { pin in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon)) {
                    Button {
                        picked = pin
                    } label: {
                        Circle()
                            .fill(color(pin.kind))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(radius: 2)
                    }
                    .accessibilityLabel(pin.name)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                HStack(spacing: 14) {
                    key("LTVA", "ltva")
                    key("Camping", "free")
                    key("Worth a visit", "see")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) {
                if let pin = picked {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pin.name).font(.headline)
                                Text(kindName(pin.kind)).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                picked = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Close")
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
        default: return Color(red: 109 / 255, green: 74 / 255, blue: 168 / 255)
        }
    }

    private func kindName(_ kind: String) -> String {
        switch kind {
        case "ltva": return "Long Term Visitor Area"
        case "free": return "Camping"
        default: return "Worth a visit"
        }
    }

    private func key(_ name: String, _ kind: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color(kind)).frame(width: 10, height: 10)
            Text(name)
        }
    }
}
