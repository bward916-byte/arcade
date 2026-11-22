import CoreGraphics
import CoreText
import Foundation

private var fontCache: [String: CTFont] = [:]
private let rgbSpace = CGColorSpaceCreateDeviceRGB()

func ctFont(_ name: String, _ size: Double) -> CTFont {
    let key = name + "|" + String(Int((size * 4).rounded()))
    if let f = fontCache[key] { return f }
    let f = CTFontCreateWithName(name as CFString, CGFloat(size), nil)
    fontCache[key] = f
    return f
}
func cgColor(_ c: Col) -> CGColor {
    let comps: [CGFloat] = [CGFloat(c.r), CGFloat(c.g), CGFloat(c.b), CGFloat(c.a)]
    return CGColor(colorSpace: rgbSpace, components: comps) ?? CGColor(gray: 1, alpha: 1)
}
private func makeLine(_ s: String, _ size: Double, _ font: String, _ c: Col) -> CTLine {
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): ctFont(font, size),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): cgColor(c)
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
}
/// The width of a string in game points.
func textW(_ s: String, _ size: Double, _ font: String = FONT) -> Double {
    let line = makeLine(s, size, font, WHITE)
    return Double(CTLineGetTypographicBounds(line, nil, nil, nil))
}
/// Break a string into lines no wider than maxW.
func wrapText(_ s: String, _ maxW: Double, _ size: Double, _ font: String = FONT) -> [String] {
    var out: [String] = []
    for para in s.components(separatedBy: "\n") {
        var line = ""
        for word in para.split(separator: " ") {
            let w = String(word)
            let trial = line.isEmpty ? w : line + " " + w
            if textW(trial, size, font) > maxW && !line.isEmpty {
                out.append(line)
                line = w
            } else {
                line = trial
            }
        }
        out.append(line)
    }
    return out
}

extension Canvas {
    /// Text with its baseline at y. align: -1 left, 0 centred, 1 right.
    func text(_ s: String, _ x: Double, _ y: Double, _ size: Double, _ c: Col, _ align: Int = 0, _ font: String = FONT) {
        if s.isEmpty { return }
        let line = makeLine(s, size, font, c)
        let w = Double(CTLineGetTypographicBounds(line, nil, nil, nil))
        var px = x
        if align == 0 { px = x - w / 2 } else if align > 0 { px = x - w }
        cg.saveGState()
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        cg.textPosition = CGPoint(x: px, y: y)
        CTLineDraw(line, cg)
        cg.restoreGState()
    }
    /// Text with a dark drop shadow, for words over the scene.
    func textS(_ s: String, _ x: Double, _ y: Double, _ size: Double, _ c: Col, _ align: Int = 0, _ font: String = FONT) {
        text(s, x + 1, y + 1.5, size, Col(0x000000, 0.7), align, font)
        text(s, x, y, size, c, align, font)
    }
    /// Wrapped text starting with its first baseline at y. Returns the y after the last line.
    @discardableResult
    func para(_ s: String, _ x: Double, _ y: Double, _ maxW: Double, _ size: Double, _ c: Col, _ align: Int = 0, _ font: String = FONT) -> Double {
        var yy = y
        for l in wrapText(s, maxW, size, font) {
            text(l, x, yy, size, c, align, font)
            yy += size * 1.28
        }
        return yy
    }
    func pathFill(_ c: Col, _ build: (CGMutablePath) -> Void) {
        let p = CGMutablePath()
        build(p)
        cg.setFillColor(cgColor(c))
        cg.addPath(p)
        cg.fillPath()
    }
    func pathStroke(_ c: Col, _ w: Double, _ build: (CGMutablePath) -> Void) {
        let p = CGMutablePath()
        build(p)
        cg.setStrokeColor(cgColor(c))
        cg.setLineWidth(CGFloat(w))
        cg.addPath(p)
        cg.strokePath()
    }
    /// A path filled with a top-to-bottom gradient between y0 and y1.
    func pathGrad(_ y0: Double, _ y1: Double, _ stops: [(Double, Col)], _ build: (CGMutablePath) -> Void) {
        let p = CGMutablePath()
        build(p)
        var comps: [CGFloat] = []
        var locs: [CGFloat] = []
        for s in stops {
            locs.append(CGFloat(s.0))
            comps.append(CGFloat(s.1.r)); comps.append(CGFloat(s.1.g)); comps.append(CGFloat(s.1.b)); comps.append(CGFloat(s.1.a))
        }
        guard let g = CGGradient(colorSpace: rgbSpace, colorComponents: comps, locations: locs, count: stops.count) else { return }
        cg.saveGState()
        cg.addPath(p)
        cg.clip()
        cg.drawLinearGradient(g, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        cg.restoreGState()
    }
    /// A rounded rectangle filled with a vertical gradient.
    func RRGrad(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ stops: [(Double, Col)]) {
        if w <= 0 || h <= 0 { return }
        let rr = CGFloat(max(0, min(r, min(w, h) / 2)))
        pathGrad(y, y + h, stops) { p in
            p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerWidth: rr, cornerHeight: rr)
        }
    }
    func RRStroke(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ lw: Double, _ c: Col) {
        if w <= 0 || h <= 0 { return }
        let rr = CGFloat(max(0, min(r, min(w, h) / 2)))
        pathStroke(c, lw) { p in
            p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerWidth: rr, cornerHeight: rr)
        }
    }
    func circStroke(_ x: Double, _ y: Double, _ r: Double, _ w: Double, _ c: Col) {
        ellStroke(x, y, r, r, w, c)
    }
    func clipRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        cg.clip(to: CGRect(x: x, y: y, width: w, height: h))
    }
    func dash(_ a: Double, _ b: Double, _ phase: Double = 0) {
        cg.setLineDash(phase: CGFloat(phase), lengths: [CGFloat(a), CGFloat(b)])
    }
    func noDash() { cg.setLineDash(phase: 0, lengths: []) }
    func roundJoin() { cg.setLineJoin(.round) }
    /// Paints an image into a rectangle, the right way up.
    func drawImage(_ img: CGImage, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        cg.saveGState()
        cg.translateBy(x: CGFloat(x), y: CGFloat(y + h))
        cg.scaleBy(x: 1, y: -1)
        cg.interpolationQuality = .high
        cg.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        cg.restoreGState()
    }
}
