import CoreGraphics
import CoreText
import Foundation

/// A thin drawing layer over CoreGraphics with the same shape as the web version's 2D canvas calls,
/// so the scene code reads like the original. Coordinates are y-down game pixels.
final class Canvas {
    let cg: CGContext
    let pxW: Int
    let pxH: Int
    private let space = CGColorSpaceCreateDeviceRGB()

    /// A bitmap `w` x `h` game pixels, stored at `scale` device pixels per game pixel.
    init?(w: Int, h: Int, scale: Int) {
        pxW = max(1, w * scale)
        pxH = max(1, h * scale)
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let rgb = CGColorSpaceCreateDeviceRGB()
        guard let c = CGContext(data: nil, width: max(1, w * scale), height: max(1, h * scale), bitsPerComponent: 8, bytesPerRow: 0, space: rgb, bitmapInfo: info) else { return nil }
        cg = c
        cg.translateBy(x: 0, y: CGFloat(pxH))
        cg.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    }

    func image() -> CGImage? { return cg.makeImage() }

    private func setFill(_ c: Col) {
        cg.setFillColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }
    private func setStroke(_ c: Col, _ w: Double) {
        cg.setStrokeColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
        cg.setLineWidth(CGFloat(w))
    }

    func clear(_ w: Double, _ h: Double) { cg.clear(CGRect(x: 0, y: 0, width: w, height: h)) }
    func save() { cg.saveGState() }
    func restore() { cg.restoreGState() }
    func translate(_ x: Double, _ y: Double) { cg.translateBy(x: CGFloat(x), y: CGFloat(y)) }
    func scale(_ x: Double, _ y: Double) { cg.scaleBy(x: CGFloat(x), y: CGFloat(y)) }
    func rotate(_ a: Double) { cg.rotate(by: CGFloat(a)) }
    func alpha(_ a: Double) { cg.setAlpha(CGFloat(clampD(a, 0, 1))) }
    func blend(_ m: CGBlendMode) { cg.setBlendMode(m) }
    func roundCaps(_ on: Bool) { cg.setLineCap(on ? .round : .butt) }

    func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Col) {
        setFill(c)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }
    /// A rectangle with rounded corners.
    func RR(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ c: Col) {
        if w <= 0 || h <= 0 { return }
        setFill(c)
        let rr = CGFloat(max(0, min(r, min(w, h) / 2)))
        cg.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: rr, cornerHeight: rr, transform: nil))
        cg.fillPath()
    }
    func poly(_ c: Col, _ p: [Double]) {
        if p.count < 6 { return }
        setFill(c)
        cg.beginPath()
        cg.move(to: CGPoint(x: p[0], y: p[1]))
        var i = 2
        while i + 1 < p.count { cg.addLine(to: CGPoint(x: p[i], y: p[i + 1])); i += 2 }
        cg.closePath()
        cg.fillPath()
    }
    func circ(_ x: Double, _ y: Double, _ r: Double, _ c: Col) {
        setFill(c)
        cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    func ell(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ c: Col) {
        setFill(c)
        cg.fillEllipse(in: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
    }
    func ellStroke(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ w: Double, _ c: Col) {
        setStroke(c, w)
        cg.strokeEllipse(in: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
    }
    func seg(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ w: Double, _ c: Col) {
        setStroke(c, w)
        cg.beginPath()
        cg.move(to: CGPoint(x: x0, y: y0))
        cg.addLine(to: CGPoint(x: x1, y: y1))
        cg.strokePath()
    }
    /// A quadratic curve, stroked.
    func curve(_ x0: Double, _ y0: Double, _ cx: Double, _ cy: Double, _ x1: Double, _ y1: Double, _ w: Double, _ c: Col) {
        setStroke(c, w)
        cg.beginPath()
        cg.move(to: CGPoint(x: x0, y: y0))
        cg.addQuadCurve(to: CGPoint(x: x1, y: y1), control: CGPoint(x: cx, y: cy))
        cg.strokePath()
    }
    /// The filled sector of a circle from angle a0 round to a1, angles increasing clockwise on screen as on a web canvas.
    func arcFill(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ c: Col) {
        setFill(c)
        cg.beginPath()
        cg.addArc(center: CGPoint(x: x, y: y), radius: CGFloat(r), startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
        cg.closePath()
        cg.fillPath()
    }
    func arcStroke(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ w: Double, _ c: Col) {
        setStroke(c, w)
        cg.beginPath()
        cg.addArc(center: CGPoint(x: x, y: y), radius: CGFloat(r), startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
        cg.strokePath()
    }
    /// The top half of a disc: a dome.
    func dome(_ x: Double, _ y: Double, _ r: Double, _ c: Col) { arcFill(x, y, r, PI, PI * 2, c) }
    func arch(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Col) {
        R(x, y + w / 2, w, h - w / 2, c)
        dome(x + w / 2, y + w / 2, w / 2, c)
    }

    private func gradient(_ stops: [(Double, Col)]) -> CGGradient? {
        var comps: [CGFloat] = []
        var locs: [CGFloat] = []
        for s in stops {
            locs.append(CGFloat(s.0))
            comps.append(CGFloat(s.1.r)); comps.append(CGFloat(s.1.g)); comps.append(CGFloat(s.1.b)); comps.append(CGFloat(s.1.a))
        }
        return CGGradient(colorSpace: space, colorComponents: comps, locations: locs, count: stops.count)
    }
    /// A linear gradient running from (x0,y0) to (x1,y1), painted into the given rectangle.
    func linear(_ rx: Double, _ ry: Double, _ rw: Double, _ rh: Double, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ stops: [(Double, Col)]) {
        guard let g = gradient(stops) else { return }
        cg.saveGState()
        cg.clip(to: CGRect(x: rx, y: ry, width: rw, height: rh))
        cg.drawLinearGradient(g, start: CGPoint(x: x0, y: y0), end: CGPoint(x: x1, y: y1), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        cg.restoreGState()
    }
    /// A vertical gradient filling a rectangle top to bottom.
    func vfill(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ stops: [(Double, Col)]) {
        linear(x, y, w, h, x, y, x, y + h, stops)
    }
    /// A round glow: `inner` at the centre fading to `outer` at radius r.
    func glow(_ x: Double, _ y: Double, _ r: Double, _ inner: Col, _ outer: Col) {
        guard let g = gradient([(0, inner), (1, outer)]) else { return }
        cg.saveGState()
        cg.clip(to: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        cg.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: CGFloat(r), options: [])
        cg.restoreGState()
    }
    /// Paints another canvas over this one, stretched to w x h game pixels.
    func stamp(_ other: Canvas, _ w: Double, _ h: Double) {
        guard let img = other.image() else { return }
        cg.saveGState()
        cg.translateBy(x: 0, y: CGFloat(h))
        cg.scaleBy(x: 1, y: -1)
        cg.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        cg.restoreGState()
    }

    /// A line of lettering. `y` is the baseline; `center` centres it on x.
    func text(_ str: String, _ x: Double, _ y: Double, _ size: Double, _ c: Col, center: Bool = true, bold: Bool = true, face: String? = nil, fit: Double = 0) {
        var font = CTFontCreateWithName((face ?? (bold ? "Georgia-Bold" : "Georgia")) as CFString, CGFloat(size), nil)
        if fit > 0 {
            // shrink to the width allowed
            let probe = CTLineCreateWithAttributedString(NSAttributedString(string: str, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
            let pw = Double(CTLineGetTypographicBounds(probe, nil, nil, nil))
            if pw > fit { font = CTFontCreateWithName((face ?? (bold ? "Georgia-Bold" : "Georgia")) as CFString, CGFloat(size * fit / pw), nil) }
        }
        let color = CGColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: str, attributes: attrs))
        let w = Double(CTLineGetTypographicBounds(line, nil, nil, nil))
        cg.saveGState()
        cg.translateBy(x: CGFloat(center ? x - w / 2 : x), y: CGFloat(y))
        cg.scaleBy(x: 1, y: -1)
        cg.textMatrix = .identity
        cg.textPosition = .zero
        CTLineDraw(line, cg)
        cg.restoreGState()
    }
}
