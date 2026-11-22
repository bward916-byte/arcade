import Foundation

// Shared helpers and colours for the native Floor Zero.

let PI = Double.pi
let FLOOR_W = 1800.0
let VIEW_H = 540.0

func clampD(_ v: Double, _ a: Double, _ b: Double) -> Double { return v < a ? a : (v > b ? b : v) }
func rnd(_ a: Double, _ b: Double) -> Double { return a + Double.random(in: 0..<1) * (b - a) }
func chance(_ p: Double) -> Bool { return Double.random(in: 0..<1) < p }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { return a + (b - a) * t }
func hashN(_ n: Double) -> Double { let v = sin(n * 127.1 + 3.7) * 43758.5453; return v - floor(v) }
func sgn(_ v: Double) -> Double { return v > 0 ? 1 : (v < 0 ? -1 : 0) }
func easeOut(_ t: Double) -> Double { let u = 1 - clampD(t, 0, 1); return 1 - u * u * u }
func easeIO(_ t: Double) -> Double { let u = clampD(t, 0, 1); return u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2 }

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
    static func mix(_ x: Col, _ y: Col, _ t: Double) -> Col {
        return Col(r: x.r + (y.r - x.r) * t, g: x.g + (y.g - x.g) * t, b: x.b + (y.b - x.b) * t, a: x.a + (y.a - x.a) * t)
    }
}
/// Colour from 0-255 channels and a 0-1 alpha, the way the web version writes rgba().
func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Col {
    return Col(r: r / 255, g: g / 255, b: b / 255, a: clampD(a, 0, 1))
}

let GOLD = Col(0xffd27a), WHITE = Col(0xffffff), BLACK = Col(0x000000), BLOOD = Col(0xb0181c)
let MINT = Col(0x7dffb0), HOT = Col(0xff5a4a), INK = Col(0x0a0b10)

/// A small repeatable random source, so a floor is the same every time it is built.
struct Rng {
    var s: UInt64
    init(_ seed: Int) { s = UInt64(truncatingIfNeeded: seed &* 2654435761 &+ 88172645463325252) }
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double((s >> 33) & 0x7FFFFFFF) / 2147483648.0
    }
    mutating func r(_ a: Double, _ b: Double) -> Double { return a + next() * (b - a) }
    mutating func i(_ n: Int) -> Int { return min(n - 1, Int(next() * Double(n))) }
}

struct Zone {
    let from: Int
    let name: String
    let wall: Col
    let floor: Col
    let trim: Col
}

struct Tower {
    let who: String
    let building: String
    let top: Int
    let hue: Col
    let shirt: Col
    let pants: Col
    let hair: Col
    let skin: Col
    let weapon: Int          // 1 bat, 2 hockey stick, 3 pool cue
    let deck: [String]
    let zones: [Zone]        // highest first; a floor uses the first zone whose `from` is at or below it
}

let TOWERS: [Tower] = [
    Tower(who: "COLE", building: "MERIDIAN TOWER", top: 83, hue: Col(0xffd27a), shirt: Col(0x2c3a5c), pants: Col(0x2a2f3c), hair: Col(0x2a1e18), skin: Col(0xd9a67e), weapon: 1,
          deck: ["GRAND SLAM", "GROUND POUND", "FREIGHT TRAIN", "OVERTIME", "HAYMAKER HURRICANE", "METEOR FIST", "ELEVATOR PITCH", "BULLDOZER", "THUNDERCLAP", "HOSTILE TAKEOVER", "EARTHSHAKER", "ROLLING THUNDER", "PILEDRIVER", "JACKHAMMER", "KNEECAPPER", "AFTERSHOCK"],
          zones: [Zone(from: 70, name: "OFFICES", wall: Col(0x2c3340), floor: Col(0x3a3f4a), trim: Col(0x5b6472)),
                  Zone(from: 55, name: "HOTEL", wall: Col(0x3b2a2e), floor: Col(0x4a2e2a), trim: Col(0x8a5a4a)),
                  Zone(from: 40, name: "RESIDENTIAL", wall: Col(0x2e3a30), floor: Col(0x3b4a3c), trim: Col(0x6c8a6a)),
                  Zone(from: 25, name: "MEDICAL / LAB", wall: Col(0x8f9ca3), floor: Col(0x6c7d86), trim: Col(0x4f6672)),
                  Zone(from: 10, name: "MALL / GARAGE", wall: Col(0x3a3a3a), floor: Col(0x4a4a4a), trim: Col(0x8a8a8a)),
                  Zone(from: 0, name: "LOBBY", wall: Col(0x2a2620), floor: Col(0x5a4c38), trim: Col(0xc9a24a))]),
    Tower(who: "MAYA", building: "ST. ANNE HOSPITAL", top: 48, hue: Col(0x7dd3ff), shirt: Col(0x2f9c98), pants: Col(0x25324a), hair: Col(0x1a1414), skin: Col(0xb98056), weapon: 2,
          deck: ["CODE BLUE", "DRAGON RUSH", "HUNDRED PALMS", "TRIAGE", "TORNADO KICK", "TIGER SWEEP", "POLE VAULT", "SHADOW STEP", "FLYING DRAGON", "FLATLINE", "LOTUS BLOOM", "IRON PALM WAVE", "WHIRLING MONK", "THUNDER KNEE", "RISING PHOENIX"],
          zones: [Zone(from: 36, name: "WARDS", wall: Col(0x8fa3a8), floor: Col(0x62767c), trim: Col(0x3f5a62)),
                  Zone(from: 24, name: "SURGERY", wall: Col(0x7c9aa0), floor: Col(0x4f6a70), trim: Col(0x2f4a52)),
                  Zone(from: 12, name: "LABS", wall: Col(0x56666e), floor: Col(0x3c4a52), trim: Col(0x7dffb0)),
                  Zone(from: 0, name: "EMERGENCY", wall: Col(0x4a3434), floor: Col(0x3a2a2a), trim: Col(0xff5a4a))]),
    Tower(who: "JO", building: "THE ALDER HOTEL", top: 60, hue: Col(0xff8a6a), shirt: Col(0xb8322c), pants: Col(0x22222a), hair: Col(0xe3c26a), skin: Col(0xe6b891), weapon: 3,
          deck: ["LAST CALL", "BLADE STORM", "CRESCENT REAPER", "BAR FIGHT", "NEEDLE RAIN", "GUILLOTINE", "WHIRLWIND", "PHANTOM CROSS", "SKYFALL", "THOUSAND CUTS", "LOW TIDE", "IRON BUTTERFLY", "LAST RITES", "HOME RUN", "BOOT AND BLADE", "COMET"],
          zones: [Zone(from: 45, name: "PENTHOUSES", wall: Col(0x3a2a3e), floor: Col(0x2e2030), trim: Col(0xc9a24a)),
                  Zone(from: 20, name: "GUEST ROOMS", wall: Col(0x4a322c), floor: Col(0x5a3830), trim: Col(0x9a6a4a)),
                  Zone(from: 8, name: "BALLROOMS", wall: Col(0x3a2e22), floor: Col(0x4a3a24), trim: Col(0xd9b45a)),
                  Zone(from: 0, name: "CASINO", wall: Col(0x2a1418), floor: Col(0x4a1a20), trim: Col(0xffd27a))])
]

struct UpDef {
    let id: String
    let name: String
    let icon: String
    let desc: String
    let gun: Bool
    let sup: Bool
}
let UPS: [UpDef] = [
    UpDef(id: "smg", name: "AUTO SMG", icon: "🔫", desc: "Fires by itself at the nearest one.", gun: true, sup: false),
    UpDef(id: "shotgun", name: "SHOTGUN", icon: "💥", desc: "Blasts anything that gets close.", gun: true, sup: false),
    UpDef(id: "nade", name: "GRENADES", icon: "💣", desc: "Lobs a grenade into the crowd.", gun: true, sup: false),
    UpDef(id: "flame", name: "FLAMETHROWER", icon: "🔥", desc: "Sets fire to whatever is in front.", gun: true, sup: false),
    UpDef(id: "drone", name: "GUN DRONE", icon: "🛸", desc: "A drone circles you and shoots.", gun: true, sup: false),
    UpDef(id: "minigun", name: "MINIGUN", icon: "⚙️", desc: "A wall of bullets. Never stops.", gun: true, sup: true),
    UpDef(id: "tesla", name: "TESLA COIL", icon: "⚡️", desc: "Lightning jumps from one to the next.", gun: true, sup: true),
    UpDef(id: "orbital", name: "ORBITAL STRIKE", icon: "🛰", desc: "A beam from the sky on the biggest pack.", gun: true, sup: true),
    UpDef(id: "armor", name: "RIOT ARMOR", icon: "🛡", desc: "Bites hurt a lot less.", gun: false, sup: false),
    UpDef(id: "hp", name: "SECOND WIND", icon: "🩸", desc: "More health, and a full heal now.", gun: false, sup: false),
    UpDef(id: "dmg", name: "HEAVY HITTER", icon: "💪", desc: "Every swing and power move hits harder.", gun: false, sup: false),
    UpDef(id: "adren", name: "ADRENALINE", icon: "💉", desc: "Run faster. The power meter fills faster.", gun: false, sup: false)
]
