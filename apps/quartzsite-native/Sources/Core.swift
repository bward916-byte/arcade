import Foundation

// Shared helpers and colours.

let PI = Double.pi

func clampD(_ v: Double, _ a: Double, _ b: Double) -> Double { return v < a ? a : (v > b ? b : v) }
func rnd(_ a: Double, _ b: Double) -> Double { return a + Double.random(in: 0..<1) * (b - a) }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { return a + (b - a) * t }
func hashN(_ n: Double) -> Double { let v = sin(n * 127.1 + 3.7) * 43758.5453; return v - floor(v) }

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
    /// The same colour made darker (f below 1) or lighter (f above 1).
    func shade(_ f: Double) -> Col { return Col(r: min(1, r * f), g: min(1, g * f), b: min(1, b * f), a: a) }
    static func mix(_ x: Col, _ y: Col, _ t: Double) -> Col {
        return Col(r: x.r + (y.r - x.r) * t, g: x.g + (y.g - x.g) * t, b: x.b + (y.b - x.b) * t, a: x.a + (y.a - x.a) * t)
    }
}

let CREAM = Col(0xf5ead2), GOLD = Col(0xf2c14e), INK = Col(0x1c1410), GREEN = Col(0x7fd08a), REDC = Col(0xe2604a)
let GLASS = Col(0x2b3a4a), TIRE = Col(0x1d1b1a), HUB = Col(0x9a9a96)
let SKINS: [Col] = [Col(0xd9a37a), Col(0xa8744c), Col(0xe8b890), Col(0xc48a62)]
let SHIRTS: [Col] = [Col(0xb5452f), Col(0x4a5a6e), Col(0x3f8f8a), Col(0xd9c9a8)]
let PANTS: [Col] = [Col(0x3d4a66), Col(0x2c2c30), Col(0x7a6a4e), Col(0x5a6a7a)]
