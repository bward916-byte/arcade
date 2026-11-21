import Foundation

// Shared helpers, colours and the entity types. Ported from dunefall/index.html.

let PI = Double.pi

func clampD(_ v: Double, _ a: Double, _ b: Double) -> Double { return v < a ? a : (v > b ? b : v) }
func rnd(_ a: Double, _ b: Double) -> Double { return a + Double.random(in: 0..<1) * (b - a) }
func chance(_ p: Double) -> Bool { return Double.random(in: 0..<1) < p }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { return a + (b - a) * t }
func hashN(_ n: Double) -> Double { let v = sin(n * 127.1 + 3.7) * 43758.5453; return v - floor(v) }
func sgn(_ v: Double) -> Double { return v > 0 ? 1 : (v < 0 ? -1 : 0) }

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

let SAND = Col(0xe6c588), SAND2 = Col(0xd4ad6c), WOOD = Col(0x7a5632), DARKC = Col(0x3a2a1c)
let GOLD = Col(0xf2c14e), TEAL = Col(0x2fa7a0), RED = Col(0xb5412e), LAPIS = Col(0x2c4f9e)
let MUD = Col(0xc9a26c), MUD2 = Col(0xb08854), MUDD = Col(0x86663f)
let PLA = Col(0xeedfbc), PLA2 = Col(0xcdb88c), STONE = Col(0xd2b47e), STONE2 = Col(0xa98652)
let ROBE: [Col] = [Col(0xe8dcc0), Col(0xc9d6c2), Col(0xd9b99a), Col(0xb9c4d9), Col(0xe2c9a0)]
let TURB: [Col] = [Col(0xf3ead2), RED, LAPIS, Col(0xe0a030), TEAL]
let SKIN: [Col] = [Col(0xb8804e), Col(0x9a6a40), Col(0xc9925e)]

enum BType: Int { case market, tea, guard, pen, well, temple, gw, ge }
enum Role { case folk, digger, guard, herder }

struct Def {
    let name: String
    let w: Double
    let cost: [Int]
    let pay: Int
    let tier: Bool
    let tool: Role?
    let gate: Bool
    let h: [Double]
}

let DEF: [BType: Def] = [
    .market: Def(name: "BAZAAR", w: 78, cost: [6, 10, 16], pay: 3, tier: true, tool: .digger, gate: false, h: [14, 30, 46, 52]),
    .tea: Def(name: "TEAHOUSE", w: 66, cost: [6, 10], pay: 2, tier: true, tool: nil, gate: false, h: [12, 34, 44]),
    .guard: Def(name: "BARRACKS", w: 60, cost: [8, 12, 18], pay: 0, tier: true, tool: .guard, gate: false, h: [14, 32, 52, 62]),
    .pen: Def(name: "CAMEL YARD", w: 72, cost: [6, 12], pay: 0, tier: true, tool: .herder, gate: false, h: [10, 24, 28]),
    .well: Def(name: "WELL", w: 30, cost: [10, 22], pay: 0, tier: false, tool: nil, gate: false, h: [10, 22, 78]),
    .temple: Def(name: "TEMPLE", w: 72, cost: [12, 18], pay: 4, tier: true, tool: nil, gate: false, h: [16, 46, 58]),
    .gw: Def(name: "WEST GATE", w: 14, cost: [4, 8, 14], pay: 0, tier: true, tool: nil, gate: true, h: [4, 16, 26, 36]),
    .ge: Def(name: "EAST GATE", w: 14, cost: [4, 8, 14], pay: 0, tier: true, tool: nil, gate: true, h: [4, 16, 26, 36])
]
let GHP: [Double] = [0, 16, 34, 60]

protocol Walker: AnyObject {
    var x: Double { get set }
    var dir: Double { get set }
    var walk: Double { get set }
    var moving: Bool { get set }
}
@discardableResult
func stepTo(_ o: Walker, _ tx: Double, _ speed: Double, _ dt: Double) -> Bool {
    let dx = tx - o.x
    if abs(dx) < 1.5 { o.moving = false; return true }
    o.dir = sgn(dx)
    o.x += o.dir * min(abs(dx), speed * dt)
    o.walk += dt
    o.moving = true
    return false
}

final class Building {
    let type: BType
    let def: Def
    var x: Double
    let w: Double
    var level = 0
    var paid = 0
    var incoming = 0
    var badges = 0
    var rin = 0
    var claim = 0
    var building = false
    var robbed = false
    var progress = 0.0
    var need = 1.0
    var hp = 0.0
    var idle = 0.0
    var shake = 0.0
    var acd = 0.0
    init(_ t: BType, _ x: Double) {
        type = t
        def = DEF[t]!
        self.x = x
        w = def.w
    }
    var tall: Double { return def.h[min(level, def.h.count - 1)] }
    var mid: Double { return x + w / 2 }
}

enum CoinState { case air, ground, back, slot, tool, mend }
final class Coin {
    var x: Double
    var h: Double
    var vx = 0.0
    var vh = 0.0
    var st: CoinState
    var age = 0.0
    var claimed = 0
    var free = false
    var b: Building?
    var tx = 0.0
    var th = 0.0
    init(x: Double, h: Double, st: CoinState) { self.x = x; self.h = h; self.st = st }
}

final class Player {
    var x = 0.0
    var vx = 0.0
    var dir = 1.0
    var phase = 0.0
    var coins = 8
    var cd = 0.0
    var toss = 0.0
    var ammo = 6
    var rl = 0.0
    var rlT = 1.0
    var gcd = 0.0
    var draw = 0.0
    var lock = false
    var idle = 0.0
    var kneelT = 0.0
    var kneelK = 0.0
    var aim = 1.0
    var st = 0
}

final class Folk: Walker {
    let id: Int
    var x: Double
    var dir: Double
    var walk = 0.0
    var moving = false
    var wait = 0.0
    var wx: Double
    var hidden = false
    var role: Role
    var work = 0.0
    var cd = 0.0
    var ham = 0.0
    var side: Double
    var cheer = 0.0
    init(id: Int, x: Double, dir: Double, role: Role) {
        self.id = id; self.x = x; self.dir = dir; self.role = role
        wx = x
        side = id % 2 == 1 ? 1 : -1
    }
}

final class Nomad: Walker {
    let id: Int
    let camp: Int
    let home: Double
    var x: Double
    var dir: Double
    var walk = 0.0
    var moving = false
    var target: Coin?
    var wait: Double
    var wx: Double
    init(id: Int, camp: Int, home: Double, x: Double, dir: Double) {
        self.id = id; self.camp = camp; self.home = home; self.x = x; self.dir = dir
        wait = rnd(0, 3)
        wx = home
    }
}

enum RaidKind { case bandit, rider }
enum RaidState { case raid, flee }
final class Raider: Walker {
    let id: Int
    let kind: RaidKind
    var x: Double
    var dir: Double
    let side: Double
    var hp: Int
    var state = RaidState.raid
    var loot = 0
    var walk = 0.0
    var cd = 0.0
    var hurt = 0.0
    var stag = 0.0
    var moving = true
    var dead = false
    init(id: Int, kind: RaidKind, x: Double, side: Double, hp: Int) {
        self.id = id; self.kind = kind; self.x = x; self.side = side; self.hp = hp
        dir = -side
    }
    /// speed, damage to a gate, coins knocked from the purse
    var speed: Double { return kind == .bandit ? 38 : 70 }
    var rob: Int { return kind == .bandit ? 3 : 4 }
}

final class Goat: Walker {
    var x: Double
    var dir = 1.0
    var walk = 0.0
    var moving = false
    var t = 0.0
    var tx: Double
    var kid = true
    init(x: Double) { self.x = x; tx = x }
}

final class Hare {
    var x: Double
    let west: Bool
    var dir = 1.0
    var t: Double
    var hop = 0.0
    var tx: Double
    var dead = false
    init(x: Double, west: Bool) { self.x = x; self.west = west; t = rnd(0, 2); tx = x }
}

final class Urn {
    let x: Double
    let n: Int
    var open = false
    init(x: Double, n: Int) { self.x = x; self.n = n }
}

struct Camp { let x: Double; let cap: Int }
struct Arrow { var x: Double; var h: Double; var vx: Double; var vh: Double; var life: Double; var mine: Bool }
struct Part {
    var x: Double
    var h: Double
    var vx: Double
    var vh: Double
    var life = 0.0
    var max: Double
    var col: Col
    var grav: Double
    var smoke = false
    var r = 1.5
    var a = 1.0
    var lit = false
}
struct Ring { var x: Double; var t: Double }
struct Stuck { var x: Double; var ang: Double; var t: Double }
struct Fallen { var x: Double; var t: Double; var dir: Double }
struct Footprint { var x: Double; var t: Double }
struct RaidPlan { var t: Double; var side: Double; var kind: RaidKind; var hp: Int }

struct Input {
    var stick = 0.0
    var toss = false
    var fire = false
    var reload = false
}

enum GameState { case title, play, over }

let HINTS: [String: String] = [
    "start": "Ride out to the tents and toss a coin to a nomad.",
    "urn": "An old urn under the sand. Ride over coins to pick them up.",
    "recruit": "A nomad joins you. Ride up to a ruin in town and toss coins to rebuild it.",
    "funded": "Paid for. Your villagers will work until it is done.",
    "noworkers": "Paid for, but nobody is free to build. Recruit a nomad first.",
    "market1": "The bazaar is open and pays every morning. Toss a coin at the tool rack on its left to outfit a digger.",
    "tea1": "The teahouse is open. It pays each morning and hides your villagers at night.",
    "guard1": "The barracks stand. Toss a coin at the spear rack on its right and a villager takes up the watch.",
    "pen1": "The camel yard: your camel runs faster. A coin on the crook rack makes a herder, and goats pay each dawn.",
    "well1": "The well is rebuilt. Buildings can now rise a second level.",
    "well2": "The obelisk is raised. The town can grow to its full height.",
    "temple1": "The temple gong will tell you each dusk which side the raiders are coming from.",
    "gate": "A gate. Raiders have to break it down before they can get in.",
    "digger": "A digger. They work the old quarry west of town by day. Ride out and collect the gold.",
    "guard": "A guard. Guards hold the gates after dark.",
    "herder": "A herder. Goats in the east pasture pay a coin each at dawn.",
    "raid": "Raiders come after dark. Keep at least one coin in your purse.",
    "hit": "Robbed. If they catch you with an empty purse, you are run out of town.",
    "robbed": "Raiders robbed a building. It will not pay this morning.",
    "mug": "A raider ran one of your villagers off. The teahouse and your guards keep them safe.",
    "broke": "Out of coins. Morning brings more.",
    "dawn": "Morning. Ride through town and gather what it earned.",
    "back": "You turn in the saddle: arrows go at the nearest raider, in front or behind.",
    "reload": "Restringing. The quiver refills in a moment.",
    "cap": "Rebuild the well first. Then the town can rise higher.",
    "hare": "A desert hare. Run it down or shoot it for two coins.",
    "hare2": "Two coins for the hare.",
    "relic": "A digger struck something old. Extra gold at the quarry."
]
