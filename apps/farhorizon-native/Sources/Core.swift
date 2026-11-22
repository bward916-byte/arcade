import Foundation

// Shared helpers, colours and the voyage data. Ported from far-horizon/index.html.

let PI = Double.pi

func clampD(_ v: Double, _ a: Double, _ b: Double) -> Double { return v < a ? a : (v > b ? b : v) }
func rnd(_ a: Double, _ b: Double) -> Double { return a + Double.random(in: 0..<1) * (b - a) }
func rndI(_ a: Int, _ b: Int) -> Int { return b <= a ? a : Int.random(in: a...b) }
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

let INK = Col(0x1c1108), CREAM = Col(0xfff1cf), GOLD = Col(0xf3c969), GOLD2 = Col(0xd49a2a), WOODC = Col(0x6b4423), WOOD2 = Col(0x3f2613)
let PANEL = Col(0x2a1a0c), REDC = Col(0xc0392b), GREENC = Col(0x58c06a), WHITE = Col(0xffffff), BLACK = Col(0x000000)

let FONT = "Baskerville-SemiBold"
let FONTB = "Baskerville-Bold"
let FONTI = "Baskerville-Italic"
let FONTD = "Copperplate-Bold"

struct ShipDef {
    let name: String
    let cost: Int
    let speed: Double
    let hold: Int
    let hull: Int
    let crew: Int
    let masts: Int
    let len: Double
    let desc: String
}
let SHIPS: [ShipDef] = [
    ShipDef(name: "Sloop", cost: 300, speed: 1.3, hold: 120, hull: 70, crew: 6, masts: 1, len: 0.8, desc: "Fast, cheap to feed"),
    ShipDef(name: "Brig", cost: 500, speed: 1.0, hold: 200, hull: 100, crew: 10, masts: 2, len: 1.0, desc: "Balanced"),
    ShipDef(name: "Galleon", cost: 560, speed: 0.8, hold: 320, hull: 140, crew: 14, masts: 3, len: 1.22, desc: "Slow, tough, many mouths")
]

struct Port {
    let n: String
    let pm: Double
    let x: Double
    let y: Double
}
let STAGES: [[Port]] = [
    [Port(n: "Port Haven", pm: 1, x: 0.05, y: 0.5)],
    [Port(n: "Gull Cay", pm: 1.2, x: 0.24, y: 0.26), Port(n: "Shark Tooth Key", pm: 1.3, x: 0.23, y: 0.74)],
    [Port(n: "Port Verde", pm: 0.9, x: 0.43, y: 0.24), Port(n: "Blackwater", pm: 1.25, x: 0.42, y: 0.72)],
    [Port(n: "Smuggler's Reach", pm: 1.4, x: 0.61, y: 0.27), Port(n: "Fort Carlisle", pm: 1, x: 0.6, y: 0.75)],
    [Port(n: "Coral Bay", pm: 1.1, x: 0.79, y: 0.25), Port(n: "Tortola Deep", pm: 1.2, x: 0.78, y: 0.72)],
    [Port(n: "Santa Aurelia", pm: 1, x: 0.97, y: 0.5)]
]
let LEG: [Double] = [260, 300, 280, 340, 320]
let DAYLEN = 3.6
let WAGE = 5

struct Good {
    let k: String
    let n: String
    let p: Int
    let step: Int
}
let GOODS: [Good] = [
    Good(k: "food", n: "Food", p: 4, step: 5), Good(k: "water", n: "Water", p: 2, step: 5), Good(k: "planks", n: "Planks", p: 8, step: 1),
    Good(k: "bait", n: "Bait", p: 3, step: 1), Good(k: "powder", n: "Powder", p: 10, step: 1), Good(k: "arms", n: "Blades", p: 12, step: 1)
]

let FIRST = ["Tom", "Ned", "Jack", "Will", "Sam", "Abel", "Finn", "Hugh", "Davy", "Pete", "Amos", "Cole", "Eli", "Gus", "Ike", "Jem", "Kit", "Luke", "Mack", "Nat", "Obed", "Rafe", "Silas", "Wat"]
let LAST = ["Reed", "Pike", "Flint", "Marsh", "Tanner", "Cobb", "Hale", "Rook", "Drake", "Quill", "Stone", "Thorne", "Vane", "Wren", "Yarrow", "Bell", "Crane", "Dunn", "Frost", "Gale"]

/// The seven posts a sailor can hold, and how many each takes.
let ROLES: [(k: String, n: String, max: Int)] = [
    (k: "helm", n: "Helm", max: 1), (k: "rig", n: "Rigging", max: 2), (k: "look", n: "Lookout", max: 1), (k: "gun", n: "Guns", max: 2),
    (k: "cook", n: "Galley", max: 2), (k: "carp", n: "Carpenter", max: 2), (k: "fish", n: "Fishing", max: 2)
]

final class Man {
    let n: String
    let sk: String
    var sk2: String = ""
    var post: String = ""
    /// 0 fit, 1 wounded, 2 sick
    var st = 0
    var d = 0
    var xp: [String: Int] = [:]
    init() {
        n = FIRST[Int.random(in: 0..<FIRST.count)] + " " + LAST[Int.random(in: 0..<LAST.count)]
        sk = ROLES[Int.random(in: 0..<ROLES.count)].k
    }
    var fit: Bool { return st == 0 }
    func knows(_ k: String) -> Bool { return sk == k || sk2 == k }
    var first: String { return String(n.split(separator: " ").first ?? "Sailor") }
}

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
