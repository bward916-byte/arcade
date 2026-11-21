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
var MUD = Col(0xc9a26c), MUD2 = Col(0xb08854), MUDD = Col(0x86663f)
var PLA = Col(0xeedfbc), PLA2 = Col(0xcdb88c), STONE = Col(0xd2b47e), STONE2 = Col(0xa98652)
let ROBE: [Col] = [Col(0xe8dcc0), Col(0xc9d6c2), Col(0xd9b99a), Col(0xb9c4d9), Col(0xe2c9a0)]
let TURB: [Col] = [Col(0xf3ead2), RED, LAPIS, Col(0xe0a030), TEAL]
let SKIN: [Col] = [Col(0xb8804e), Col(0x9a6a40), Col(0xc9925e)]

enum BType: Int { case market, tea, `guard`, pen, well, temple, gw, ge, bank, dock, sphinx, tomb, grove, hermit, btemple }
enum Role { case folk, digger, `guard`, herder }

struct Def {
    let name: String
    let w: Double
    let cost: [Int]
    let pay: Int
    let tier: Bool
    let tool: Role?
    let gate: Bool
    let h: [Double]
    var far = false
}

let DEF: [BType: Def] = [
    .market: Def(name: "BAZAAR", w: 78, cost: [6, 10, 16, 24], pay: 3, tier: true, tool: .digger, gate: false, h: [14, 30, 46, 52, 58]),
    .tea: Def(name: "TEAHOUSE", w: 66, cost: [6, 10, 16], pay: 2, tier: true, tool: nil, gate: false, h: [12, 34, 44, 50]),
    .guard: Def(name: "BARRACKS", w: 60, cost: [8, 12, 18, 26], pay: 0, tier: true, tool: .guard, gate: false, h: [14, 32, 52, 62, 66]),
    .pen: Def(name: "CAMEL YARD", w: 72, cost: [6, 12, 18], pay: 0, tier: true, tool: .herder, gate: false, h: [10, 24, 28, 34]),
    .well: Def(name: "WELL", w: 30, cost: [10, 22, 34], pay: 0, tier: false, tool: nil, gate: false, h: [10, 22, 78, 78]),
    .temple: Def(name: "TEMPLE", w: 72, cost: [12, 18, 26], pay: 4, tier: true, tool: nil, gate: false, h: [16, 46, 58, 66]),
    .gw: Def(name: "WEST GATE", w: 14, cost: [4, 8, 14, 22], pay: 0, tier: true, tool: nil, gate: true, h: [4, 16, 26, 36, 46]),
    .ge: Def(name: "EAST GATE", w: 14, cost: [4, 8, 14, 22], pay: 0, tier: true, tool: nil, gate: true, h: [4, 16, 26, 36, 46]),
    .bank: Def(name: "TREASURY", w: 56, cost: [10, 16, 24], pay: 0, tier: true, tool: nil, gate: false, h: [12, 32, 40, 48]),
    .dock: Def(name: "DOCK", w: 56, cost: [20, 6], pay: 0, tier: false, tool: nil, gate: false, h: [8, 14, 14], far: true),
    .sphinx: Def(name: "SPHINX", w: 84, cost: [10, 18], pay: 0, tier: false, tool: nil, gate: false, h: [26, 40, 40], far: true),
    .tomb: Def(name: "TOMB", w: 50, cost: [14, 20], pay: 0, tier: false, tool: nil, gate: false, h: [22, 22, 22], far: true),
    .grove: Def(name: "DATE GROVE", w: 70, cost: [5, 10, 16], pay: 0, tier: false, tool: nil, gate: false, h: [30, 36, 36, 36], far: true),
    .hermit: Def(name: "HERMIT", w: 44, cost: [6, 6, 6], pay: 0, tier: false, tool: nil, gate: false, h: [30, 30, 30, 30], far: true),
    .btemple: Def(name: "BURIED TEMPLE", w: 90, cost: [12, 20], pay: 0, tier: false, tool: nil, gate: false, h: [20, 46, 50], far: true)
]

// The five towns: each has its own street plan, its own country around it, and its own thing to find.
enum Feat: Int { case pyramid, oasis, cliff, port, temple }
let TOWNS = ["DUNEFALL", "KHEPRI WELLS", "SETHAT", "AMBER GATE", "THE LAST CATARACT"]
let TOWNSUB = ["Under the pyramids", "The oasis town", "Under the red cliffs", "The river port", "The city of old temples"]
let BOSSTEXT = ["The warlord rides with them tonight.", "The Poisoner. He is making for the well: stop him before he reaches it.",
                "The Stone Lord. He stands off and rolls boulders at your gate.", "River pirates. They are landing at the dock while the raid comes from the west.",
                "The High Priest. He raises the dead, then comes for the gate himself."]
struct TownCfg {
    let feat: Feat
    let ox: Double
    let bx: [BType: Double]
    let sites: [BType: Double]
    let oasis: Double
    let past: (Double, Double)
    let quarry: Double
    let camps: [(Double, Int)]
    let urns: [(Double, Int)]
}
let TCFG: [TownCfg] = [
    TownCfg(feat: .pyramid, ox: 0, bx: [.bank: 1338, .market: 1408, .tea: 1500, .guard: 1700, .temple: 1778, .pen: 1866],
            sites: [.sphinx: 600, .tomb: 78, .grove: 2450], oasis: 2485, past: (2080, 2200), quarry: 985,
            camps: [(430, 3), (1130, 2), (2320, 2), (2860, 3)], urns: [(250, 6), (860, 4), (2230, 4), (2650, 6)]),
    TownCfg(feat: .oasis, ox: 0, bx: [.tea: 1326, .market: 1412, .guard: 1512, .temple: 1694, .pen: 1786, .bank: 1888],
            sites: [.grove: 2050, .hermit: 150], oasis: 2085, past: (2240, 2380), quarry: 900,
            camps: [(520, 3), (1120, 2), (2500, 3), (2820, 2)], urns: [(330, 6), (760, 5), (2640, 6)]),
    TownCfg(feat: .cliff, ox: 0, bx: [.guard: 1330, .bank: 1416, .temple: 1490, .pen: 1700, .market: 1806, .tea: 1896],
            sites: [.tomb: 78, .grove: 2450], oasis: 2485, past: (2080, 2200), quarry: 985,
            camps: [(470, 2), (1130, 3), (2320, 2), (2860, 3)], urns: [(640, 5), (860, 4), (2230, 5), (2700, 6)]),
    TownCfg(feat: .port, ox: 640, bx: [.market: 1326, .bank: 1424, .pen: 1500, .tea: 1694, .guard: 1782, .temple: 1866],
            sites: [.btemple: 880], oasis: -9999, past: (2700, 2820), quarry: 1500,
            camps: [(420, 3), (1080, 3), (1680, 2), (2900, 2)], urns: [(250, 6), (640, 5), (1300, 5), (1760, 4)]),
    TownCfg(feat: .temple, ox: 0, bx: [.temple: 1330, .tea: 1420, .market: 1510, .bank: 1694, .guard: 1772, .pen: 1862],
            sites: [.sphinx: 600, .tomb: 78, .grove: 2450], oasis: 2485, past: (2080, 2200), quarry: 985,
            camps: [(430, 3), (1130, 3), (2320, 3), (2860, 3)], urns: [(250, 7), (860, 5), (2230, 5), (2650, 7)])
]
let PALS: [[UInt32]] = [
    [0xc9a26c, 0xb08854, 0x86663f, 0xeedfbc, 0xcdb88c, 0xd2b47e, 0xa98652], [0xf0e6d0, 0xd6c8a8, 0xa8997a, 0xfbf6ea, 0xdcd2bc, 0xe8dcc0, 0xc0b08c],
    [0xd08a5c, 0xb06a40, 0x7e4426, 0xe6b08a, 0xc48a62, 0xcf8a5a, 0xa85a36], [0xb89464, 0x96744a, 0x6a4e2e, 0xe4d4b0, 0xc2ae84, 0xc9b084, 0x9c8258],
    [0xdcc696, 0xbfa672, 0x8e7848, 0xf0e2bc, 0xd2c092, 0xe0cc9a, 0xb49a66]
]
func usePalette(_ i: Int) {
    let q = PALS[i % 5]
    MUD = Col(q[0]); MUD2 = Col(q[1]); MUDD = Col(q[2]); PLA = Col(q[3]); PLA2 = Col(q[4]); STONE = Col(q[5]); STONE2 = Col(q[6])
}

/// A camera move with a caption: the game holds still while it plays.
final class Cine {
    let k: String
    let text: String
    let dur: Double
    var fx: Double
    let zoom: Double
    var t = 0.0
    init(k: String, text: String, dur: Double, fx: Double, zoom: Double) { self.k = k; self.text = text; self.dur = dur; self.fx = fx; self.zoom = zoom }
}
final class Storm {
    var t = 0.0
    let dur = 38.0
    var front: Double
    var leak = 0.0
    var raided = false
    init(front: Double) { self.front = front }
}
/// The night visitor: it comes down, hovers, drops what it has, and goes.
final class Ufo {
    var x: Double
    var t = 0.0
    var phase = 0
    var h = 150.0
    var gt = 0.0
    var n = 0
    init(x: Double) { self.x = x }
}
struct Devil { var x: Double; var dir: Double; let a: Double; let b: Double }
struct Rock { var x: Double; var dir: Double; var rot = 0.0; var t = 0.0; var dead = false }

let GHP: [Double] = [0, 16, 34, 60, 90]

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
    var gone = false
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

enum CoinState { case air, ground, back, slot, tool, mend, bank, shop, merc }
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
    var shop: Shop?
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

enum RaidKind: Int { case bandit, rider, boss, mummy }
enum RaidState { case raid, flee }
final class Raider: Walker {
    let id: Int
    let kind: RaidKind
    var x: Double
    var dir: Double
    let side: Double
    var hp: Int
    let maxHp: Int
    var burn = 0.0
    var bcd = 1.5
    var raised = 0
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
        maxHp = hp
        dir = -side
    }
    var speed: Double {
        switch kind {
        case .bandit: return 38
        case .rider: return 70
        case .boss: return 28
        case .mummy: return 17
        }
    }
    /// coins knocked from the purse
    var rob: Int {
        switch kind {
        case .bandit: return 3
        case .rider: return 4
        case .boss: return 5
        case .mummy: return 0
        }
    }
    var gateDmg: Double { return (kind == .boss || kind == .mummy) ? 4 : 2 }
}

/// A signpost that sells one upgrade at a time.
final class Shop {
    let k: BType
    var paid = 0
    var inc = 0
    var idle = 0.0
    init(_ k: BType) { self.k = k }
}
struct ShopItem { let key: String; let cost: Int; let name: String; let text: String }
let SHOP: [BType: [ShopItem]] = [
    .guard: [ShopItem(key: "quiver", cost: 6, name: "Quiver", text: "Nine arrows instead of six."),
             ShopItem(key: "fire", cost: 10, name: "Fire arrows", text: "Every arrow bites twice as hard."),
             ShopItem(key: "falcon", cost: 12, name: "Falcon", text: "It shows you where raiders are gathering.")],
    .pen: [ShopItem(key: "saddle", cost: 8, name: "Racing saddle", text: "A faster camel."),
           ShopItem(key: "racer", cost: 14, name: "Racing camel", text: "Faster still, at a full gallop.")]
]

/// The trade caravan: in from the west every third day, a stop at the bazaar, then on to the river.
final class Caravan {
    var x: Double
    var stopped = false
    var leaving = false
    var t = 0.0
    var ph = 0.0
    var paid = 0
    var inc = 0
    var sold = false
    var idle = 0.0
    init(x: Double) { self.x = x }
}

/// Someone shopping in the bazaar: for show only.
final class Stroller: Walker {
    let id: Int
    var x: Double
    var dir = 1.0
    var walk = 0.0
    var moving = false
    var wait = 0.0
    var tx: Double
    var hidden = true
    init(id: Int, x: Double) { self.id = id; self.x = x; tx = x }
}

struct SaveData: Codable {
    var day: Int
    var coins: Int
    var bank: Int
    var levels: [Int]
    var roles: [Int]
    var herd: Int
    var up: [String]
    var urns: [Bool]
    var seen: [String]
    var town: Int?
    var day0: Int?
    var relics: [String]?
    var ankh: Bool?
    var stats: [Int]?
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
struct Arrow { var x: Double; var h: Double; var vx: Double; var vh: Double; var life: Double; var mine: Bool; var fire = false }
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
struct RaidPlan { var t: Double; var side: Double; var kind: RaidKind; var hp: Int; var boat = false }

struct Input {
    var stick = 0.0
    var toss = false
    var fire = false
    var reload = false
}

enum GameState { case title, play, over, end }

let HINTS: [String: String] = [
    "start": "Ride out to the tents and tap the screen to toss a coin to a nomad.",
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
    "relic": "A digger struck something old. Extra gold at the quarry.",
    "bank1": "The treasury. Coins tossed here are safe from raiders, and building work is paid from it first.",
    "caravan": "A caravan is coming in from the west. It pays the bazaar, and a coin or four hires its guard.",
    "merc": "A caravan guard takes your coin and stays.",
    "warlord": "The warlord is down. His purse is yours.",
    "well2x": "The obelisk is raised. The dock by the Nile can now be built.",
    "dock1": "The dock is built. Six coins buys passage downriver on the felucca, when you are ready to leave.",
    "sphinx1": "The Sphinx is dug out. It pays two coins each dawn and turns back half the raiders from the west.",
    "tomb1": "The tomb is open: gold, and an ankh that will save you once. But the dead walk every third night.",
    "grove1": "The date grove is tended. Coins fall by the oasis each dawn.",
    "btemple1": "The buried temple is dug out. It pays three coins each dawn.",
    "btemple0": "The storm has uncovered the top of something very old, west of town.",
    "hermit0": "A hermit. For six coins he parts with something old.",
    "relic_scarab": "A scarab. Three coins find you every dawn, in every town.",
    "relic_lamp": "An old lamp. It shows what is buried: every hidden urn glows, here and in every town, and is marked on the map.",
    "well3": "A fountain garden at the well: two coins each dawn, and room for six more people.",
    "sphinx2": "The Sphinx is restored and gilded. Four coins each dawn, and it turns back two in three raiders from the west.",
    "tomb2": "The tomb is sealed with gold. The dead will not walk again.",
    "grove2": "The grove is planted out: six coins of dates each dawn.",
    "grove3": "A full orchard with drying racks: nine coins of dates each dawn.",
    "btemple2": "The old temple is restored. Six coins each dawn.",
    "gate4": "A fortified gatehouse: half again as strong, and its archers loose faster.",
    "relic_charm": "A storm charm. The haboob cannot push you or pick your purse.",
    "poison": "The well is poisoned. Your villagers earn nothing in the morning.",
    "poisoned": "The well ran foul last night: no coins from your villagers this morning.",
    "mummy": "The dead are stirring in the tomb tonight. They break gates and take villagers.",
    "ankh": "The ankh shatters and the raiders scatter. It will not save you twice.",
    "storm": "A haboob is rolling in from the west. Hard riding inside it, but the wind uncovers old things.",
    "stormcoin": "The wind is tearing coins from your purse. Get inside the walls.",
    "stormover": "The haboob has passed. Look for what it uncovered out in the dunes.",
    "stormraid": "Riders are using the dust for cover: two raiders, from the west.",
    "rock": "A boulder knocks coins from your purse.",
    "fish": "A fishing spot: look for the net rack. Stop on it and you cast a line. Each fish sells for a coin.",
    "fish2": "A coin for the fish. Stay put for more: the water restocks each morning.",
    "fishbig": "A Nile perch. Three coins.",
    "fished": "Fished out for today. Come back in the morning.",
    "dig": "A sunken tomb. Stop here and you go down. You can carry out one relic at a time.",
    "digfull": "Your hands are full. Sell this relic in town first.",
    "digrest": "The air below is bad. Three trips a day is all anyone can stand.",
    "digdone": "The sunken tomb is empty now.",
    "rain": "Rain. It will not last, but the date grove will pay double in the morning.",
    "eclipse": "The sun is going out. The raiders take it for an omen: nobody will ride tonight.",
    "omen": "No raid tonight. They will not ride under a sky that went dark.",
    "festival": "The whole town is rebuilt. Tonight they celebrate: the dock by the Nile is yours to build.",
    "ufo": "Something is coming down out of the sky, west of town.",
    "ufo2": "It drops gold where you stand, as if it wanted to see what you would do.",
    "ufogone": "It is gone. The sand under it is glass, and it was looking at the tomb.",
    "deep0": "The tomb door hums. Stand here a while.",
    "star": "A star of cold metal. The visitor will come back for it, and pay.",
    "trap": "The old way to the tomb is trapped. Cross the plates while the spikes are down.",
    "dock0": "No boat will stop at half a town. Rebuild everything and raise the obelisk first."
]
