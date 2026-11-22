import UIKit

/// A thin drawing layer over CoreGraphics shaped like the web version's 2D canvas calls.
/// Coordinates are y-down game pixels.
final class Canvas {
    let cg: CGContext
    let pxW: Int
    let pxH: Int
    private let space = CGColorSpaceCreateDeviceRGB()
    private var fonts: [Int: UIFont] = [:]

    init?(w: Int, h: Int, scale: Int) {
        pxW = max(1, w * scale)
        pxH = max(1, h * scale)
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let rgb = CGColorSpaceCreateDeviceRGB()
        guard let c = CGContext(data: nil, width: max(1, w * scale), height: max(1, h * scale), bitsPerComponent: 8, bytesPerRow: 0, space: rgb, bitmapInfo: info) else { return nil }
        cg = c
        cg.translateBy(x: 0, y: CGFloat(pxH))
        cg.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
    }

    func image() -> CGImage? { return cg.makeImage() }

    private func cgc(_ c: Col) -> CGColor {
        return CGColor(colorSpace: space, components: [CGFloat(c.r), CGFloat(c.g), CGFloat(c.b), CGFloat(c.a)]) ?? UIColor.black.cgColor
    }
    private func setFill(_ c: Col) {
        cg.setFillColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }
    private func setStroke(_ c: Col, _ w: Double) {
        cg.setStrokeColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
        cg.setLineWidth(CGFloat(w))
    }

    func save() { cg.saveGState() }
    func restore() { cg.restoreGState() }
    func translate(_ x: Double, _ y: Double) { cg.translateBy(x: CGFloat(x), y: CGFloat(y)) }
    func scale(_ x: Double, _ y: Double) { cg.scaleBy(x: CGFloat(x), y: CGFloat(y)) }
    func rotate(_ a: Double) { cg.rotate(by: CGFloat(a)) }
    func alpha(_ a: Double) { cg.setAlpha(CGFloat(clampD(a, 0, 1))) }
    func lighter(_ on: Bool) { cg.setBlendMode(on ? .plusLighter : .normal) }
    func clipRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) { cg.clip(to: CGRect(x: x, y: y, width: w, height: h)) }

    func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Col) {
        setFill(c)
        cg.fill(CGRect(x: x, y: y, width: w, height: h))
    }
    func RR(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ c: Col) {
        if w <= 0 || h <= 0 { return }
        setFill(c)
        let rr = CGFloat(max(0, min(r, min(w, h) / 2)))
        cg.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: rr, cornerHeight: rr, transform: nil))
        cg.fillPath()
    }
    func RRStroke(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ lw: Double, _ c: Col) {
        if w <= 0 || h <= 0 { return }
        setStroke(c, lw)
        let rr = CGFloat(max(0, min(r, min(w, h) / 2)))
        cg.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: rr, cornerHeight: rr, transform: nil))
        cg.strokePath()
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
    /// An open line through the points, stroked.
    func line(_ c: Col, _ w: Double, _ p: [Double]) {
        if p.count < 4 { return }
        setStroke(c, w)
        cg.beginPath()
        cg.move(to: CGPoint(x: p[0], y: p[1]))
        var i = 2
        while i + 1 < p.count { cg.addLine(to: CGPoint(x: p[i], y: p[i + 1])); i += 2 }
        cg.strokePath()
    }
    func circ(_ x: Double, _ y: Double, _ r: Double, _ c: Col) {
        if r <= 0 { return }
        setFill(c)
        cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    func ell(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ c: Col) {
        if rx <= 0 || ry <= 0 { return }
        setFill(c)
        cg.fillEllipse(in: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
    }
    func ring(_ x: Double, _ y: Double, _ r: Double, _ w: Double, _ c: Col) {
        if r <= 0 { return }
        setStroke(c, w)
        cg.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    func ellStroke(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ w: Double, _ c: Col) {
        if rx <= 0 || ry <= 0 { return }
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
    func curve(_ x0: Double, _ y0: Double, _ cx: Double, _ cy: Double, _ x1: Double, _ y1: Double, _ w: Double, _ c: Col) {
        setStroke(c, w)
        cg.beginPath()
        cg.move(to: CGPoint(x: x0, y: y0))
        cg.addQuadCurve(to: CGPoint(x: x1, y: y1), control: CGPoint(x: cx, y: cy))
        cg.strokePath()
    }
    func arcFill(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ c: Col) {
        setFill(c)
        cg.beginPath()
        cg.addArc(center: CGPoint(x: x, y: y), radius: CGFloat(r), startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
        cg.closePath()
        cg.fillPath()
    }
    func arcStroke(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ w: Double, _ c: Col) {
        if r <= 0 { return }
        setStroke(c, w)
        cg.beginPath()
        cg.addArc(center: CGPoint(x: x, y: y), radius: CGFloat(r), startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
        cg.strokePath()
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
    /// A vertical gradient filling a rectangle top to bottom.
    func vfill(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ stops: [(Double, Col)]) {
        guard let g = gradient(stops) else { return }
        cg.saveGState()
        cg.clip(to: CGRect(x: x, y: y, width: w, height: h))
        cg.drawLinearGradient(g, start: CGPoint(x: x, y: y), end: CGPoint(x: x, y: y + h), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        cg.restoreGState()
    }
    /// A round glow: `inner` at the centre fading to clear at radius r.
    func glow(_ x: Double, _ y: Double, _ r: Double, _ inner: Col) {
        if r <= 0 { return }
        guard let g = gradient([(0, inner), (1, inner.alpha(0))]) else { return }
        cg.saveGState()
        cg.clip(to: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        cg.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: CGFloat(r), options: [])
        cg.restoreGState()
    }

    // ---------- text
    private func font(_ size: Double, _ weight: Int) -> UIFont {
        let key = Int(size * 4) * 8 + weight
        if let f = fonts[key] { return f }
        let w: UIFont.Weight = weight >= 3 ? .black : (weight == 2 ? .heavy : (weight == 1 ? .semibold : .regular))
        let f = UIFont.systemFont(ofSize: CGFloat(size), weight: w)
        fonts[key] = f
        return f
    }
    func textW(_ s: String, _ size: Double, _ weight: Int = 2) -> Double {
        return Double((s as NSString).size(withAttributes: [.font: font(size, weight)]).width)
    }
    /// Text with its baseline at y. align: 0 left, 1 centre, 2 right.
    func text(_ s: String, _ x: Double, _ y: Double, _ size: Double, _ c: Col, _ align: Int = 0, _ weight: Int = 2) {
        let f = font(size, weight)
        let col = UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
        let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: col]
        let str = s as NSString
        var px = CGFloat(x)
        if align != 0 {
            let w = str.size(withAttributes: attrs).width
            px -= align == 1 ? w / 2 : w
        }
        UIGraphicsPushContext(cg)
        str.draw(at: CGPoint(x: px, y: CGFloat(y) - f.ascender), withAttributes: attrs)
        UIGraphicsPopContext()
    }
    /// Text with a dark drop shadow, for stamped captions.
    func stamp(_ s: String, _ x: Double, _ y: Double, _ size: Double, _ c: Col, _ align: Int = 0) {
        text(s, x + size * 0.06, y + size * 0.08, size, BLACK.alpha(0.7), align, 3)
        text(s, x, y, size, c, align, 3)
    }
}
