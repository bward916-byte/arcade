import Foundation

// Shared helpers and colours for Broadside. Ported from broadside/index.html.

let PI = Double.pi

func clampD(_ v: Double, _ a: Double, _ b: Double) -> Double { return v < a ? a : (v > b ? b : v) }
func rnd(_ a: Double, _ b: Double) -> Double { return a + Double.random(in: 0..<1) * (b - a) }
func chance(_ p: Double) -> Bool { return Double.random(in: 0..<1) < p }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { return a + (b - a) * t }
func sgn(_ v: Double) -> Double { return v > 0 ? 1 : (v < 0 ? -1 : 0) }
func hashN(_ n: Double) -> Double { let v = sin(n * 127.1 + 3.7) * 43758.5453; return v - floor(v) }
func smooth(_ t: Double) -> Double { let q = clampD(t, 0, 1); return q * q * (3 - 2 * q) }

struct Col {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
    init(_ hex: UInt32, _ alpha: Double = 1) {
        r = Double((hex >> 16) & 255) / 255
        g = Double((hex >> 8) & 255) / 255
        b = Double(hex & 255) / 255
        a = alpha
    }
    init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    func alpha(_ v: Double) -> Col { return Col(r: r, g: g, b: b, a: v) }
    func shade(_ k: Double) -> Col { return Col(r: clampD(r * k, 0, 1), g: clampD(g * k, 0, 1), b: clampD(b * k, 0, 1), a: a) }
    static func mix(_ x: Col, _ y: Col, _ t: Double) -> Col {
        let q = clampD(t, 0, 1)
        return Col(r: x.r + (y.r - x.r) * q, g: x.g + (y.g - x.g) * q, b: x.b + (y.b - x.b) * q, a: x.a + (y.a - x.a) * q)
    }
}
func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Col {
    return Col(r: r / 255, g: g / 255, b: b / 255, a: clampD(a, 0, 1))
}
/// A colour that runs from its night value to its day value as the light rises.
func dn(_ night: UInt32, _ day: UInt32, _ light: Double) -> Col {
    return Col.mix(Col(night), Col(day), light)
}

let CREAM = Col(0xf4e6c8), GOLD = Col(0xffd27a), GOLD2 = Col(0xd8b86a), WHITE = Col(0xffffff), BLACK = Col(0x000000)
let NAVY = Col(0x08121c)

let FONT = "Georgia"
let FONTB = "Georgia-Bold"

struct Spark {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Double
    var max: Double
    var r: Double
    var c: Col
    var grav: Double
}

/// One thing you can pour coins into.
struct Upg {
    let id: String
    let x: Double
    let cost: Int
}

/// A round control on screen this frame.
struct Ring {
    let id: String
    let x: Double
    let y: Double
    let r: Double
    let pour: Bool
}
