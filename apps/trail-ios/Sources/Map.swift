import SwiftUI
import MapLibre
import CoreLocation

// What the buttons and sheets ask of the map. The map view itself is made in MapBox below.
@MainActor
final class MapModel: ObservableObject {
    weak var view: MLNMapView?
    @Published var basemap = "topo" { didSet { apply() } }
    @Published var showLand = true { didSet { apply() } }
    @Published var landOpacity = 0.45 { didSet { apply() } }
    @Published var pendingPin: CLLocationCoordinate2D?
    private var pins: [MLNPointAnnotation] = []

    func apply() {
        guard let style = view?.style else { return }
        style.layer(withIdentifier: "topo")?.isVisible = basemap == "topo"
        style.layer(withIdentifier: "imagery")?.isVisible = basemap == "imagery"
        if let land = style.layer(withIdentifier: "land") as? MLNRasterStyleLayer {
            land.isVisible = showLand
            land.rasterOpacity = NSExpression(forConstantValue: landOpacity)
        }
    }

    func followMe() {
        view?.showsUserLocation = true
        view?.setUserTrackingMode(.follow, animated: true, completionHandler: nil)
    }

    func go(to place: CLLocationCoordinate2D) {
        view?.setCenter(place, zoomLevel: 14, animated: true)
    }

    private func line(_ coords: [CLLocationCoordinate2D], into id: String) {
        guard let source = view?.style?.source(withIdentifier: id) as? MLNShapeSource else { return }
        source.shape = coords.count > 1 ? MLNPolylineFeature(coordinates: coords, count: UInt(coords.count)) : nil
    }

    func drawLive(_ coords: [CLLocationCoordinate2D]) { line(coords, into: "live") }

    func showSaved(_ coords: [CLLocationCoordinate2D]) {
        line(coords, into: "saved")
        guard coords.count > 1 else { return }
        view?.setVisibleCoordinates(coords, count: UInt(coords.count), edgePadding: UIEdgeInsets(top: 90, left: 50, bottom: 150, right: 70), animated: true)
    }

    func showWaypoints(_ list: [Waypoint]) {
        guard let view else { return }
        view.removeAnnotations(pins)
        pins = list.map { pin in
            let mark = MLNPointAnnotation()
            mark.coordinate = pin.coordinate
            mark.title = pin.name
            mark.subtitle = String(format: "%.5f, %.5f", pin.lat, pin.lon)
            return mark
        }
        view.addAnnotations(pins)
    }
}

struct MapBox: UIViewRepresentable {
    @ObservedObject var model: MapModel
    @ObservedObject var store: Store

    func makeCoordinator() -> Coordinator { Coordinator(model: model, store: store) }

    func makeUIView(context: Context) -> MLNMapView {
        let style = Bundle.main.url(forResource: "style", withExtension: "json")
        let view = MLNMapView(frame: .zero, styleURL: style)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.delegate = context.coordinator
        view.maximumZoomLevel = 18
        // Opens on the lower Colorado River desert until the phone reports where it is.
        view.setCenter(CLLocationCoordinate2D(latitude: 33.66, longitude: -114.23), zoomLevel: 9, animated: false)
        view.showsUserLocation = true
        view.compassViewPosition = .topLeft
        let press = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pressed(_:)))
        view.addGestureRecognizer(press)
        model.view = view
        return view
    }

    func updateUIView(_ view: MLNMapView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate {
        let model: MapModel
        let store: Store
        private var centered = false

        init(model: MapModel, store: Store) {
            self.model = model
            self.store = store
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            addLine(to: style, id: "saved", color: UIColor(red: 0.16, green: 0.36, blue: 0.85, alpha: 1), width: 4)
            addLine(to: style, id: "live", color: UIColor(red: 0.85, green: 0.16, blue: 0.12, alpha: 1), width: 5)
            model.apply()
            model.showWaypoints(store.waypoints)
        }

        private func addLine(to style: MLNStyle, id: String, color: UIColor, width: Double) {
            let source = MLNShapeSource(identifier: id, shape: nil, options: nil)
            style.addSource(source)
            let layer = MLNLineStyleLayer(identifier: id + "-line", source: source)
            layer.lineColor = NSExpression(forConstantValue: color)
            layer.lineWidth = NSExpression(forConstantValue: width)
            layer.lineCap = NSExpression(forConstantValue: "round")
            layer.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(layer)
        }

        // The first fix moves the map to the phone; after that the map stays where the person leaves it.
        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard !centered, let place = userLocation?.location else { return }
            centered = true
            mapView.setCenter(place.coordinate, zoomLevel: 13, animated: true)
        }

        func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool { true }

        @objc func pressed(_ press: UILongPressGestureRecognizer) {
            guard press.state == .began, let view = press.view as? MLNMapView else { return }
            model.pendingPin = view.convert(press.location(in: view), toCoordinateFrom: view)
        }
    }
}
