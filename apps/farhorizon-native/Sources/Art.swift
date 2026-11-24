import CoreGraphics
import Foundation
import ImageIO

/// Painted art shipped with the app: the splash picture, the wooden button plates and a few icons.
/// Everything else in the game is drawn in code, and every use of these falls back to drawn shapes
/// if a file is missing.
enum Art {
    private static var cache: [String: CGImage] = [:]
    private static var missing: Set<String> = []
    private static var slices: [String: [CGImage]] = [:]

    static func get(_ name: String) -> CGImage? {
        if let i = cache[name] { return i }
        if missing.contains(name) { return nil }
        for ext in ["png", "jpg"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                cache[name] = img
                return img
            }
        }
        missing.insert(name)
        return nil
    }

    /// The picture cut into nine: four corners that keep their shape, and edges and a middle that stretch.
    static func nine(_ name: String, _ cut: Int) -> [CGImage]? {
        if let s = slices[name] { return s }
        guard let img = get(name) else { return nil }
        let w = img.width, h = img.height
        if w <= cut * 2 + 2 || h <= cut * 2 + 2 { return nil }
        let xs = [0, cut, w - cut, w], ys = [0, cut, h - cut, h]
        var out: [CGImage] = []
        for r in 0..<3 {
            for q in 0..<3 {
                guard let p = img.cropping(to: CGRect(x: xs[q], y: ys[r], width: xs[q + 1] - xs[q], height: ys[r + 1] - ys[r])) else { return nil }
                out.append(p)
            }
        }
        slices[name] = out
        return out
    }
}

extension Canvas {
    /// A wooden plate stretched to any size without squashing its brass corners. False if the art is missing.
    @discardableResult
    func plate(_ name: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, corner: Double) -> Bool {
        guard let s = Art.nine(name, 46) else { return false }
        let k = min(corner, w / 2, h / 2)
        let xs = [x, x + k, x + w - k, x + w], ys = [y, y + k, y + h - k, y + h]
        for r in 0..<3 {
            for q in 0..<3 {
                let pw = xs[q + 1] - xs[q], ph = ys[r + 1] - ys[r]
                if pw <= 0 || ph <= 0 { continue }
                // a hair of overlap so no seam shows between the pieces
                drawImage(s[r * 3 + q], xs[q] - (q > 0 ? 0.4 : 0), ys[r] - (r > 0 ? 0.4 : 0), pw + (q > 0 ? 0.4 : 0), ph + (r > 0 ? 0.4 : 0))
            }
        }
        return true
    }
}
