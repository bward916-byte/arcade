import Foundation

// Shared helpers, colours and the things in the world. Ported from dustfall-3/index.html.

let PI = Double.pi

func clampD(_ v: Double, _ a: Double, _ b: Double) -> Double { return v < a ? a : (v > b ? b : v) }
func rnd(_ a: Double, _ b: Double) -> Double { return a + Double.random(in: 0..<1) * (b - a) }
func chance(_ p: Double) -> Bool { return Double.random(in: 0..<1) < p }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { return a + (b - a) * t }
func hashN(_ n: Double) -> Double { let v = sin(n * 127.1 + 3.7) * 43758.5453; return v - floor(v) }
func sgn(_ v: Double) -> Double { return v > 0 ? 1 : (v < 0 ? -1 : 0) }
func smooth(_ a: Double, _ b: Double, _ v: Double) -> Double { let u = clampD((v - a) / (b - a), 0, 1); return u * u * (3 - 2 * u) }

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

let GOLD = Col(0xf2c14e), GOLDD = Col(0xb8862a), INK = Col(0x2a1c14), CREAM = Col(0xead7a4)
let SKIN: [Col] = [Col(0xd9a878), Col(0xb8804e), Col(0xe8bc90), Col(0x9a6a40)]
let SHIRT: [Col] = [Col(0x8a5a3a), Col(0x5f7896), Col(0x7d9484), Col(0xa9683a), Col(0x9a4433), Col(0xb9b2a4)]
let HAT: [Col] = [Col(0x4a3424), Col(0x6a4a2e), Col(0x2e2622), Col(0xc9a86a)]

// The world, as in the web game.
let FIRE_X = 1365.0, MINE_X = 830.0, DAY_LEN = 100.0
// From the second town on, everything east of the stable moves 340 further out to make room for the new buildings.
var SHIFT = 0.0
var WORLD = 3420.0
var STOP = 1798.0                       // where the locomotive pulls up; the passenger car is 64 behind it
func EX(_ x: Double) -> Double { return x > 1695 ? x + SHIFT : x }
let TOWN_W = 1010.0, TOWN_E = 1790.0
/// The line, in order. The native version rides straight down it; the web game's forks come later.
let TOWN_NAMES = ["DUSTFALL", "REDWATER", "LAST HOPE", "COLD CREEK", "BITTER END"]
func nice(_ s: String) -> String { return s.capitalized }

enum BType: String { case store, saloon, sheriff, stable, bank, gateW, gateE, station, train, hall, wireW, wireE, bordello, doctor, church, forge, telegraph, claim }
enum Role { case folk, deputy, miner, rancher }

struct Def {
    let name: String
    let w: Double
    let h: Double
    let cost: [Int]
    let pay: Int
    let wall: UInt32
    let trim: UInt32
    let roof: UInt32
    let sign: UInt32
    let ink: UInt32
    let doorX: Double
    let doorW: Double
    let wins: [(Double, Double)]      // x and width of each window
    let gate: Bool
}

let DEFS: [BType: Def] = [
    .store: Def(name: "STORE", w: 70, h: 36, cost: [7, 12, 18], pay: 4, wall: 0x7d9484, trim: 0xe6d6ac, roof: 0xb44a3c, sign: 0x35523f, ink: 0xead7a4, doorX: 49, doorW: 13, wins: [(6, 35)], gate: false),
    .saloon: Def(name: "SALOON", w: 86, h: 40, cost: [6, 10, 16], pay: 3, wall: 0xa9683a, trim: 0x6a3c20, roof: 0x6a3c20, sign: 0xead7a4, ink: 0x8a2b22, doorX: 36, doorW: 14, wins: [(8, 14), (64, 14)], gate: false),
    .sheriff: Def(name: "SHERIFF", w: 66, h: 36, cost: [8, 12, 18], pay: 0, wall: 0x5f7896, trim: 0xe6d6ac, roof: 0x34445a, sign: 0xead7a4, ink: 0x27364a, doorX: 8, doorW: 13, wins: [(32, 24)], gate: false),
    .stable: Def(name: "STABLE", w: 76, h: 36, cost: [6, 12], pay: 0, wall: 0x9a4433, trim: 0xead7a4, roof: 0x4a2a22, sign: 0xead7a4, ink: 0x6a2a20, doorX: 26, doorW: 24, wins: [(8, 10), (58, 10)], gate: false),
    .bank: Def(name: "BANK", w: 64, h: 38, cost: [10], pay: 0, wall: 0xb9b2a4, trim: 0x3d4a44, roof: 0x3d4a44, sign: 0x2f3a36, ink: 0xe8d9a0, doorX: 25, doorW: 14, wins: [(6, 12), (46, 12)], gate: false),
    .gateW: Def(name: "WEST GATE", w: 14, h: 16, cost: [4, 8, 14], pay: 0, wall: 0x7a5632, trim: 0x4a3424, roof: 0x4a3424, sign: 0, ink: 0, doorX: 0, doorW: 0, wins: [], gate: true),
    .gateE: Def(name: "EAST GATE", w: 14, h: 16, cost: [4, 8, 14], pay: 0, wall: 0x7a5632, trim: 0x4a3424, roof: 0x4a3424, sign: 0, ink: 0, doorX: 0, doorW: 0, wins: [], gate: true),
    .station: Def(name: "STATION", w: 84, h: 38, cost: [20], pay: 0, wall: 0xc9a65a, trim: 0x6a2f26, roof: 0x4a3a34, sign: 0xead7a4, ink: 0x4a2a22, doorX: 36, doorW: 13, wins: [(8, 16), (60, 16)], gate: false),
    // not a building: the passenger car, where a ticket is paid
    .bordello: Def(name: "BORDELLO", w: 74, h: 38, cost: [9, 14, 20], pay: 5, wall: 0xb0506a, trim: 0xf0d9c0, roof: 0x5a2030, sign: 0xf0d9c0, ink: 0x8a2040, doorX: 30, doorW: 14, wins: [(8, 13), (53, 13)], gate: false),
    .doctor: Def(name: "DOCTOR", w: 58, h: 36, cost: [8], pay: 0, wall: 0xd9d2c0, trim: 0x3d6a5a, roof: 0x3d5a50, sign: 0xf4ecd6, ink: 0x3d6a5a, doorX: 8, doorW: 13, wins: [(29, 20)], gate: false),
    .church: Def(name: "CHURCH", w: 54, h: 40, cost: [10], pay: 0, wall: 0xe8e2d2, trim: 0x6a5a4a, roof: 0x5a4a40, sign: 0xe8e2d2, ink: 0x5a4a40, doorX: 20, doorW: 14, wins: [(5, 9), (40, 9)], gate: false),
    .forge: Def(name: "SMITHY", w: 60, h: 36, cost: [9, 14], pay: 0, wall: 0x6e5a4a, trim: 0x2e2622, roof: 0x2e2622, sign: 0x2e2622, ink: 0xe89a4a, doorX: 34, doorW: 18, wins: [(7, 16)], gate: false),
    .telegraph: Def(name: "TELEGRAPH", w: 62, h: 36, cost: [8], pay: 0, wall: 0xc9b98a, trim: 0x4a5a6a, roof: 0x3a4652, sign: 0xe8e2d2, ink: 0x2f3a46, doorX: 42, doorW: 13, wins: [(7, 26)], gate: false),
    // the town centre: campfire, then a square, then a clock tower
    .hall: Def(name: "TOWN CENTRE", w: 26, h: 14, cost: [12, 25], pay: 0, wall: 0, trim: 0, roof: 0, sign: 0, ink: 0, doorX: 0, doorW: 0, wins: [], gate: false),
    // outside each gate: barbed wire, a second apron that cuts, then a sharpshooter's nest
    .wireW: Def(name: "BARBED WIRE", w: 30, h: 10, cost: [6, 10, 16], pay: 0, wall: 0, trim: 0, roof: 0, sign: 0, ink: 0, doorX: 0, doorW: 0, wins: [], gate: false),
    .wireE: Def(name: "BARBED WIRE", w: 30, h: 10, cost: [6, 10, 16], pay: 0, wall: 0, trim: 0, roof: 0, sign: 0, ink: 0, doorX: 0, doorW: 0, wins: [], gate: false),
    // the old diggings far out west: staked, then guarded
    .claim: Def(name: "CLAIM", w: 30, h: 26, cost: [6, 8], pay: 0, wall: 0, trim: 0, roof: 0, sign: 0, ink: 0, doorX: 0, doorW: 0, wins: [], gate: false),
    .train: Def(name: "TRAIN TICKET", w: 60, h: 14, cost: [5], pay: 0, wall: 0, trim: 0, roof: 0, sign: 0, ink: 0, doorX: 0, doorW: 0, wins: [], gate: false)
]
let GHP: [Double] = [0, 16, 34, 60]      // gate hit points by level

final class Building {
    let type: BType
    let x: Double
    var level = 0
    var building = false
    var progress = 0.0
    var paid = 0
    var incoming = 0
    var hp = 0.0
    var robbed = false
    var flash = 0.0
    var live = true           // false for the ticket until the train is standing at the platform
    var scale = 1.0           // prices rise a quarter with every town down the line
    init(_ t: BType, _ x: Double) { type = t; self.x = x }
    var capL = 9              // how high it may go right now: most buildings wait on the town centre
    var cd = 0.0              // a Gatling gun's or sharpshooter's time to the next round
    var virt: Bool { return type == .train }
    var wire: Bool { return type == .wireW || type == .wireE }
    var isHall: Bool { return type == .hall }
    /// A building with a front on the street. The railroad waits until every one of them is open.
    var front: Bool { return def.wall != 0 && !def.gate && type != .station }
    /// Can only be raised one level beyond the town centre's own.
    var tier: Bool {
        switch type {
        case .store, .saloon, .sheriff, .stable, .bank, .bordello, .forge, .gateW, .gateE: return true
        default: return false
        }
    }
    var label: String {
        switch type {
        case .forge: return "Blacksmith"
        case .telegraph: return "Telegraph office"
        default: return String(def.name.prefix(1)) + String(def.name.dropFirst()).lowercased()
        }
    }
    var capped: Bool { return !building && level < maxLevel && level >= capL }
    var def: Def { return DEFS[type]! }
    var cx: Double { return x + def.w / 2 }
    var maxLevel: Int { return def.cost.count }
    var cost: Int { return level < maxLevel ? Int((Double(def.cost[level]) * scale).rounded(.up)) : 0 }
    var payable: Bool { return live && level < min(maxLevel, capL) && !building }
}

final class Drifter {
    var x: Double
    let camp: Int
    let seed: Double
    var taken = false
    init(x: Double, camp: Int) { self.x = x; self.camp = camp; seed = rnd(0, 100) }
}

final class Folk {
    var x: Double
    var tx: Double
    var role = Role.folk
    var dir = 1.0
    var phase = 0.0
    var work = false
    var moving = false
    var wait = 0.0
    var shotCD = 0.0
    var tend = 0.0            // a rancher's time at the pasture toward the next calf
    let seed: Double
    init(x: Double) { self.x = x; tx = x; seed = rnd(0, 100) }
}

final class Bandit {
    var x: Double
    var rider: Bool           // barbed wire can put him on foot
    var cut = false           // already through the wire
    var boss = false          // an outlaw with a bounty on him: slow, hard to kill, and he shoots back
    var cd2 = 2.0
    let side: Double          // which end of town he came from: -1 west, 1 east
    var hp: Int
    var st = 0                // 0 riding in, 1 breaking a gate, 2 robbing, 3 running
    var phase = 0.0
    var t = 0.0
    var hitT = 0.0
    var flash = 0.0
    var loot = 0
    var target: Building?
    init(x: Double, rider: Bool, side: Double, hp: Int) { self.x = x; self.rider = rider; self.side = side; self.hp = hp }
}

struct Shot {
    var x: Double
    var y: Double
    var vx: Double
    var life: Double
    var mine: Bool
}

struct Part {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Double
    var max: Double
    var c: Col
    var s: Double
    var grav: Double
}

/// A coin in the air on its way to something: 0 the ground, 1 a building, 2 a drifter, 3 the sheriff's badge rack, 4 back to the rider, 5 the store's pick rack, 6 the bank, 7 the stable's rope rack.
final class Coin {
    var sx: Double
    var sy: Double
    var tx: Double
    var ty: Double
    var u = 0.0
    let kind: Int
    var bld: Building?
    var drifter: Drifter?
    init(sx: Double, sy: Double, tx: Double, ty: Double, kind: Int) { self.sx = sx; self.sy = sy; self.tx = tx; self.ty = ty; self.kind = kind }
}

struct GCoin {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var age: Double
}

final class Box {
    let x: Double
    let n: Int
    var open = false
    init(_ x: Double, _ n: Int) { self.x = x; self.n = n }
}

struct RaidSpawn {
    var t: Double
    var side: Double
    var rider: Bool
    var hp: Int
    var boss = false
}

struct Cow {
    var x: Double
    var tx: Double
    var dir = 1.0
    var calf = true
    var wait = 0.0
    var phase = 0.0
    let seed: Double
}

struct Input {
    var stick = 0.0
    var toss = false
    var fire = false
}

/// The train: `v` is its speed (0 once it is standing at the platform) and `wait` the pause before the ticket goes on sale.
struct Train {
    var x: Double
    var v: Double
    var chuff = 0.0
    var wait = 0.0
}

/// What is written to disk so a game can be picked up again.
struct SaveB: Codable {
    var type: String
    var level: Int
    var building: Bool
    var progress: Double
    var hp: Double
    var robbed: Bool
}
struct SaveF: Codable {
    var x: Double
    var role: Int
}
struct SaveData: Codable {
    var v = 1
    var town: Int
    var day: Int
    var day0: Int
    var t: Double
    var coins: Int
    var bank: Int
    var ammo: Int
    var px: Double
    var side: Double
    var train: Bool
    var b: [SaveB]
    var folk: [SaveF]
    var drifters: [Int]
    var boxes: [Bool]
    var seen: [String]
    var herd: Int?
}
