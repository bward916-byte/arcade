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
struct Place {
    let name: String
    let bio: Bio
    let land: String
    let note: String
}
/// Every place on the line, and the stages of the line: where there are two, the track forks and you choose.
let PLACES: [String: Place] = [
    "dustfall": Place(name: "DUSTFALL", bio: .desert, land: "High desert", note: "Dry country, but summer storms roll in off the mesas."),
    "redwater": Place(name: "REDWATER", bio: .river, land: "River valley", note: "A ford east of town slows everyone. Thunderstorms grow the herd."),
    "irongulch": Place(name: "IRON GULCH", bio: .canyon, land: "Canyon", note: "One way in, from the east. Thunder echoes off the canyon walls."),
    "lasthope": Place(name: "LAST HOPE", bio: .desert, land: "Open desert", note: "Dust storms blow most days, and storms break by night."),
    "timberline": Place(name: "TIMBERLINE", bio: .pine, land: "Pine country", note: "Wooded and wet. A thunderstorm most days."),
    "coldcreek": Place(name: "COLD CREEK", bio: .snow, land: "Winter valley", note: "Snow slows raiders on foot. Cattle will not calve."),
    "silverpeak": Place(name: "SILVER PEAK", bio: .snow, land: "Mountain pass", note: "High and cold. Blizzards blind your deputies."),
    "bitterend": Place(name: "BITTER END", bio: .snow, land: "Deep winter", note: "The end of the line, and the hardest town on it.")
]
let STAGES: [[String]] = [["dustfall"], ["redwater", "irongulch"], ["lasthope", "timberline"], ["coldcreek", "silverpeak"], ["bitterend"]]
let STAGE_NEW = ["Saloon, store, sheriff", "Adds stable, bank", "Adds bordello, doctor", "Adds church, blacksmith", "Adds telegraph"]
func stageOf(_ town: Int) -> [String] { return STAGES[((town % STAGES.count) + STAGES.count) % STAGES.count] }
func nice(_ s: String) -> String { return s.capitalized }

/// The country each town stands in. Colours are the web game's.
enum Bio { case desert, river, canyon, pine, snow }
struct Land {
    let far: UInt32, mesa: UInt32, mesaS: UInt32, mesaT: UInt32, scrub: UInt32
    let g0: UInt32, edge: UInt32, street: UInt32, g1: UInt32, g2: UInt32, speck: UInt32, dust: UInt32
}
let LANDS: [Bio: Land] = [
    .desert: Land(far: 0xd9a47a, mesa: 0xc47a4a, mesaS: 0xa85e36, mesaT: 0xe6b891, scrub: 0x8a8a56, g0: 0xdcb680, edge: 0xeccf9c, street: 0xc49a66, g1: 0xd0a66e, g2: 0xb88a56, speck: 0x9a744a, dust: 0xe2c08c),
    .river: Land(far: 0x9fa697, mesa: 0xb39a70, mesaS: 0x8f7854, mesaT: 0xd2bb92, scrub: 0x55783c, g0: 0xb9b27e, edge: 0xd8c38a, street: 0xb99c60, g1: 0xaa9e62, g2: 0x8e8a4c, speck: 0x7c6a3c, dust: 0xd8c690),
    .canyon: Land(far: 0xb97c6c, mesa: 0xc56e48, mesaS: 0x9c4f35, mesaT: 0xea9c6e, scrub: 0x7c7a42, g0: 0xd59566, edge: 0xe8aa7a, street: 0xc98558, g1: 0xbb7a4e, g2: 0x9a5e3a, speck: 0x8a5230, dust: 0xe4ac86),
    .pine: Land(far: 0x93a6a6, mesa: 0x7f9278, mesaS: 0x5f745c, mesaT: 0xa9b89a, scrub: 0x3f6a3a, g0: 0xa99b68, edge: 0xbcae78, street: 0x9a8c5c, g1: 0x877a4e, g2: 0x6a5e3a, speck: 0x5a4e2c, dust: 0xcfc496),
    .snow: Land(far: 0xb6c1d2, mesa: 0x97a4b8, mesaS: 0x77859a, mesaT: 0xf4f8ff, scrub: 0x476a52, g0: 0xe6ebf2, edge: 0xffffff, street: 0xd6dee9, g1: 0xd6dee9, g2: 0xb9c6d6, speck: 0x9aa8bc, dust: 0xf6f9ff)
]

enum BType: String { case store, saloon, sheriff, stable, bank, gateW, gateE, station, train, hall, wireW, wireE, bordello, doctor, church, forge, telegraph, claim, coach }
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
    // the stagecoach while it waters its team: where a guard is paid for
    .coach: Def(name: "STAGECOACH", w: 38, h: 14, cost: [3], pay: 0, wall: 0, trim: 0, roof: 0, sign: 0, ink: 0, doorX: 0, doorW: 0, wins: [], gate: false),
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
    var virt: Bool { return type == .train || type == .coach }
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
    var wx: [Double]?
    var place: String?
    var log: [String]?
    var extra: [Double]?      // owed, flood, duelDay, wanted man's side (0 for none), his hit points, his days left
}

/// The stagecoach: 0 rolling in, 1 stopped by the saloon, 2 rolling out east, 3 held up at the rock arch.
struct Coach {
    var x: Double
    var st = 0
    var t = 0.0
    var guarded = false
    var gt = 0.0
    var done = false
    var fl = 0.0
    var phase = 0.0
    var moving = true
    var rob: [Bool] = []
}

/// A man with a price on his head, holed up at the old mission or the rock arch.
final class Outlaw {
    var x: Double
    let side: Double
    var hp = 6
    var days = 3
    var cd = 1.2
    var flash = 0.0
    var dir: Double
    let name: String
    let reward: Int
    init(x: Double, side: Double, name: String, reward: Int) { self.x = x; self.side = side; dir = -side; self.name = name; self.reward = reward }
}

/// High noon: 0 waiting for the bell, 1 the marker is swinging, 2 over.
struct Duel {
    var t = 0.0
    var st = 0
    var t0 = 0.0
    var per = 2.3
    var hw = 0.2
    var hits = 0
    var pos = -1.0
    var end = 0.0
    var held = true
    var oppUp = true
    var oppX: Double
    let name: String
}

/// A stray longhorn grazing out past the rock arch.
struct Stray {
    var x: Double
    var tx: Double
    var dir = 1.0
    var tame = false
    var t = 0.0
    var phase = 0.0
    let seed: Double
}
let OUTLAWS = ["Black Jack Tully", "Dutch Annie", "One-Eye Garza", "Mad Dog Riley", "The Pecos Kid", "Curly Bill Stokes"]
let DUELISTS = ["Cole Varney", "Dutch Maddox", "One-Eye Reese", "Eli Vance", "Ned Purdy"]

/// One picture of a story scene: what is drawn, a heading, a caption, and the lines of a telegram.
struct Beat {
    let art: String
    var who = ""
    let head: String
    let cap: String
    var lines: [String] = []
}
/// The story, from the web game: who burned Dustfall, and what becomes of him.
let STORY: [String: [Beat]] = [
    "s1": [Beat(art: "star", head: "Your father’s badge", cap: "In the ashes of the sheriff’s office you find your father’s badge."),
           Beat(art: "eyes", who: "rider", head: "You, the rider", cap: "This town did not just empty out. Somebody burned it down. But who?")],
    "s2": [Beat(art: "brand", head: "The raiders’ brand", cap: "Every raider’s horse carries the same brand: the letter C."),
           Beat(art: "wire", head: "A telegram", cap: "C is for Crane, the railroad boss. His raiders want you off this land.", lines: ["CRANE CATTLE AND RAIL", "IS BUYING ALL THE LAND", "AT DUSTFALL"])],
    "s3": [Beat(art: "eyes", who: "gun", head: "Crane’s hired gun", cap: "Crane has sent a gunfighter to get rid of you."),
           Beat(art: "hand", head: "Duel at noon", cap: "Meet him on main street at noon. Wait for the marker, then fire first.")],
    "a1": [Beat(art: "map", head: "The rail line", cap: "Dustfall stands again. Now rebuild the towns Crane still holds.")],
    "a2": [Beat(art: "map", head: "The rail line", cap: "Two towns are behind you. Three are still to come."),
           Beat(art: "eyes", who: "gun", head: "Crane’s riders", cap: "Crane pays his men better out here. Expect bigger raids.")],
    "a3": [Beat(art: "train", head: "Crane’s private train", cap: "Crane has come out in his own rail car to watch you fail.")],
    "a4": [Beat(art: "map", head: "The rail line", cap: "Bitter End. This is the last town on the line."),
           Beat(art: "eyes", who: "crane", head: "Silas Crane", cap: "Crane is here himself. Get every building here to its best and he is finished.")],
    "won": [Beat(art: "hand", head: "You won the duel", cap: "Crane’s gunfighter is beaten."),
            Beat(art: "eyes", who: "crane", head: "Silas Crane", cap: "Crane hears about it the same night. He will send another.")],
    "storm": [Beat(art: "storm", head: "Storm season", cap: "The first big thunderstorm rolls in. Lightning finds raiders caught in the open.")],
    "end": [Beat(art: "map", who: "all", head: "All five towns rebuilt", cap: "Every town stands again. There is nothing left for Crane to buy."),
            Beat(art: "eyes", who: "crane", head: "Silas Crane", cap: "He leaves on the night train and never comes back."),
            Beat(art: "star", head: "The end", cap: "The line belongs to the people who live on it.")]
]
