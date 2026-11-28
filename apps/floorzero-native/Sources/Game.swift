import Foundation

enum Mode { case title, intro, card, play, pick, ride, dead, ending }
enum ZKind { case zed, runner, dog, rat, bloater, boss, crawler, spitter, crow, wheel, riot, burner, screamer }
enum FloorKind { case normal, hole, wall, lift, roof, street, safe, rope }
enum RideKind { case stairs, hole, lift, rope, ladder, shaft }

final class Zed {
    let id: Int
    let kind: ZKind
    var x: Double
    var face = -1.0
    var hp: Double
    var maxHp: Double
    var alive = true
    var deadT = 0.0
    var walk = 0.0
    var atkT = -1.0
    var atkHit = false
    var cd = 0.0
    var aware = false
    var burn = 0.0
    var burnDps = 0.0
    var kvx = 0.0
    var stun = 0.0
    var flash = 0.0
    var seed: Double
    var speed: Double
    var reach: Double
    var dmg: Double
    var windup: Double
    var rate: Double
    var sight: Double
    var scale: Double
    var look: Int
    var y = 0.0
    var atkKind = 0      // 0 swipe, 1 lunge, 2 overhead slam
    var headless = false
    var gibbed = false
    var style = 0
    var spitCd = 1.5
    var job = 7          // what they were: suit, office, cook, medic, guard, janitor, waiter, casual, patient, builder
    var female = false
    var fatMul = 1.0
    var shield = 0       // blocks left on a riot shield
    var screamCd = 2.5
    var screamT = 0.0
    var flyT = -1.0      // launched by an over-the-top hit
    var flyVx = 0.0
    var flyVy = 0.0
    var flyRot = 0.0
    init(id: Int, kind: ZKind, x: Double, depth: Int, seed: Double) {
        self.id = id; self.kind = kind; self.x = x; self.seed = seed
        look = Int(seed * 97) % 5
        if kind == .riot { shield = 5 }
        style = Int(seed * 53) % 4
        job = Int(hashN(seed * 7.3) * 10) % 10
        female = hashN(seed * 3.1) > 0.5
        fatMul = 0.88 + hashN(seed * 9.1) * 0.42
        let d = Double(depth)
        var h = 34.0, sp = 62.0, re = 62.0, dm = 10.0, wu = 0.38, ra = 1.0, si = 520.0, sc = 1.0
        switch kind {
        case .zed: h = 34; sp = 62 + seed * 22; re = 62; dm = 10; wu = 0.38; ra = 1.0; si = 520; sc = 1.0
        case .runner: h = 22; sp = 190 + seed * 40; re = 58; dm = 8; wu = 0.26; ra = 0.8; si = 640; sc = 0.95
        case .dog: h = 20; sp = 330 + seed * 50; re = 54; dm = 6; wu = 0.2; ra = 0.6; si = 700; sc = 1.0
        case .rat: h = 5; sp = 220 + seed * 60; re = 30; dm = 2; wu = 0.15; ra = 0.5; si = 700; sc = 1.0
        case .bloater: h = 170; sp = 48; re = 84; dm = 20; wu = 0.6; ra = 1.5; si = 520; sc = 1.45
        case .crawler: h = 26; sp = 58 + seed * 20; re = 48; dm = 9; wu = 0.3; ra = 0.9; si = 520; sc = 1.0
        case .spitter: h = 30; sp = 70; re = 60; dm = 8; wu = 0.4; ra = 1.2; si = 760; sc = 1.05
        case .crow: h = 9; sp = 250 + seed * 60; re = 52; dm = 5; wu = 0.35; ra = 1.4; si = 900; sc = 1.0
        case .wheel: h = 40; sp = 210 + seed * 60; re = 72; dm = 11; wu = 0.18; ra = 1.1; si = 760; sc = 1.0
        case .riot: h = 70; sp = 58; re = 64; dm = 12; wu = 0.4; ra = 1.0; si = 560; sc = 1.08
        case .burner: h = 30; sp = 124; re = 58; dm = 9; wu = 0.3; ra = 0.9; si = 640; sc = 1.0
        case .screamer: h = 28; sp = 84; re = 58; dm = 7; wu = 0.36; ra = 1.0; si = 760; sc = 0.98
        case .boss: h = 620; sp = 74; re = 104; dm = 22; wu = 0.6; ra = 1.3; si = 2000; sc = 1.7
        }
        h *= 1 + d * 0.012
        hp = h
        maxHp = h
        speed = sp
        reach = re + seed * 18
        dmg = dm * 2.8
        windup = wu * 0.85
        rate = ra * 0.75
        sight = si
        let human = kind == .zed || kind == .runner || kind == .spitter || kind == .crawler || kind == .screamer || kind == .burner
        scale = human ? sc * (0.88 + hashN(seed * 5.7) * 0.3) : sc
    }
}

struct Item {
    var x: Double
    var kind: Int      // 0 medkit, 1 barrel, 2 sample, 3 valve
    var used = false
}
struct Prop {
    var x: Double
    var kind: Int
}

final class Floor {
    let n: Int
    var kind = FloorKind.normal
    var exitX = 0.0
    var exitRight = true
    var fireStairs = false
    /// The elevator car is gone: pry the doors and slide down the cable.
    var shaft = false
    var escape = false
    var holeX = 0.0
    var liftX = 900.0
    var wallX = 0.0
    var doorA = 0.0
    var doorB = 0.0
    var wallSide = 0.0
    var zeds: [Zed] = []
    var items: [Item] = []
    var props: [Prop] = []
    var pools: [(Double, Double)] = []
    var pack = 0        // 1 dogs, 2 rats
    var reserve = 0     // more of them waiting behind the doors
    var spawnT = 1.5
    var splats: [(Double, Double, Double)] = []
    var gunship = false
    var gunT = -1.0
    var gunX = -1.0
    var boss = false
    init(_ n: Int) { self.n = n }
}

struct Part { var x: Double; var y: Double; var vx: Double; var vy: Double; var t: Double; var life: Double; var size: Double; var col: Col; var grav: Double; var glow: Bool }
struct Floater { var x: Double; var y: Double; var text: String; var col: Col; var t: Double; var size: Double }
struct Ring { var x: Double; var y: Double; var r: Double; var t: Double; var life: Double; var col: Col }
struct Tracer { var x0: Double; var y0: Double; var x1: Double; var y1: Double; var t: Double; var life: Double; var col: Col; var w: Double; var bolt: Bool }
struct Boom { var x: Double; var y: Double; var r: Double; var t: Double; var life: Double }
struct Nade { var x0: Double; var x1: Double; var t: Double; var dur: Double; var r: Double; var dmg: Double }
struct Wave { var x: Double; var dir: Double; var left: Double; var dmg: Double; var hit: Set<Int> }
struct Beam { var x: Double; var t: Double; var done: Bool; var r: Double; var dmg: Double }
struct Slash { var x: Double; var y: Double; var face: Double; var t: Double; var big: Double; var col: Col; var mode = 0 }
struct Gib { var x: Double; var y: Double; var vx: Double; var vy: Double; var rot: Double; var vr: Double; var kind: Int; var col: Col; var t: Double }
struct Glob { var x: Double; var y: Double; var vx: Double; var vy: Double; var t: Double }

struct Input {
    var move = 0.0
    var attack = false
    /// One swipe or tap waiting to be used: 1 tap, 2 right, 3 left, 4 up, 5 down.
    var swipe = 0
    var power = false
}

final class Hero {
    var x = 300.0
    var face = 1.0
    var hp = 100.0
    var maxHp = 100.0
    var walk = 0.0
    var moving = false
    var atkT = -1.0
    var atkI = 0
    var atkHit = false
    var comboT = 0.0
    var hurtT = 0.0
    var inv = 0.0
    var atkStyle = 0
    var chain = 0
    var jump = 0.0
    var crit = -1
}

final class Game {
    var mode = Mode.title
    var t = 0.0
    var W = 960.0
    var safeL = 0.0
    var safeR = 0.0
    var input = Input()
    var swipeAge = 0.0
    var swipeShow = 0
    var swipeShowT = 0.0
    var snd: Sound?
    var haptic = 0
    var auto = false

    var tower = 0
    var floorN = 84
    var floor = Floor(84)
    var hero = Hero()
    var ups: [String: Int] = [:]
    var picksDue = 0
    var pickOpts: [Int] = []
    var pickT = 0.0
    var meter = 0.0
    var hasSample = false
    var valveShut = false
    var deaths = 0
    var kills = 0
    var playT = 0.0
    var hits = 0
    var hitsT = 0.0

    var supT = -1.0
    var supDur = 0.0
    var supType = 0
    var supName = ""
    var supX0 = 0.0
    var supStep = 0
    var supHit = Set<Int>()
    var supI = 0
    var nameT = 0.0

    var rideKind = RideKind.stairs
    /// On the rope a zombie lunges out of a window: tap to kick it off.
    var rideTap = false
    var grabDone = false
    var grabWon = false
    var rideFreeze = -1.0
    var grabAt = 1.15
    var rideT = 0.0
    var rideDur = 0.0
    var rideTo = 0
    var rideFrom = 0
    var deadT = 0.0
    var cardT = 0.0
    var introT = 0.0
    var endT = 0.0
    let introLen = 9.0
    var introFreeze = false

    var shake = 0.0
    var flash = 0.0
    var flashCol = WHITE
    var hitStop = 0.0
    var msg = ""
    var msgT = 0.0
    var sayCd = 0.0

    var parts: [Part] = []
    var floaters: [Floater] = []
    var rings: [Ring] = []
    var tracers: [Tracer] = []
    var booms: [Boom] = []
    var nades: [Nade] = []
    var waves: [Wave] = []
    var beams: [Beam] = []
    var slashes: [Slash] = []
    var gibs: [Gib] = []
    var fires: [(Double, Double, Double)] = []   // x, seconds left, width
    var pows: [(Double, Double, Double, Double)] = []   // x, y, age, size: a star where a hit lands
    var zoom = 1.0
    var slowT = 0.0
    var heroSlow = 0.0
    var muzzle = 0.0
    var globs: [Glob] = []
    var streak = 0
    var streakT = 0.0
    var droneA = 0.0
    var cdSmg = 0.0, cdShot = 0.0, cdNade = 2.0, cdDrone = 0.0, cdMini = 0.0, cdTesla = 1.0, cdOrb = 3.0, cdFlame = 0.0
    var flameOn = false
    /// The gun in the hero's hands for a moment after it fires: 1 SMG, 2 shotgun, 3 minigun, 4 flamethrower.
    var gunKind = 0
    var gunT = 0.0
    /// What the rooms beside the corridor are called in this building.
    var sideName: String { return tower == 0 ? "OFFICES" : (tower == 1 ? "SIDE WARDS" : "SUITES") }
    /// What is in the hands: 0 is the melee weapon (the default), otherwise a gun. Only ever one thing.
    var held = 0
    /// 0...1 while one weapon is being swung away over the shoulder and the other brought out; -1 otherwise.
    var swapT = -1.0
    var swapTo = 0
    var kickT = 0.0
    var heldGun: Int { return hero.atkT < 0 && supT < 0 ? held : 0 }
    /// A gun only fires once it is actually out. Mid-swing the guns keep firing as they always did.
    private func ready(_ kind: Int, exact: Bool = false) -> Bool {
        if hero.atkT >= 0 || supT >= 0 { return true }
        if swapT < 0 && (held == kind || (!exact && held > 0)) { return true }
        raise(kind, 0.4)
        return false
    }
    /// The best gun owned, carried on the back while the bat is out.
    var slungGun: Int { return lv("minigun") > 0 ? 3 : (lv("shotgun") > 0 ? 2 : (lv("flame") > 0 ? 4 : (lv("smg") > 0 ? 1 : 0))) }
    private func raise(_ kind: Int, _ secs: Double) {
        let rank = [0, 1, 4, 2, 3]
        if gunT <= 0 || rank[kind] >= rank[gunKind] { gunKind = kind; gunT = max(gunT, secs) }
    }
    private var nextId = 1

    var tw: Tower { return TOWERS[tower] }
    var depth: Int { return max(0, tw.top - floorN) }
    func lv(_ id: String) -> Int { return ups[id] ?? 0 }
    var upTotal: Int { var n = 0; for (_, v) in ups { n += v }; return n }
    var hasSave: Bool { return UserDefaults.standard.object(forKey: "fz.floor") != nil }
    var goal: String {
        if tower != 0 || (hasSample && valveShut) { return "REACH THE STREET" }
        return hasSample ? "SHUT THE WATER · FLOOR 12" : "GET THE SAMPLE · FLOOR 32"
    }

    func say(_ s: String, _ secs: Double = 3) { msg = s; msgT = secs }
    func buzz(_ n: Int) { haptic = max(haptic, n) }

    // ---------- starting, saving
    func newGame() {
        clearSave()
        introT = 0
        mode = .intro
        snd?.stamp()
    }
    func startTower(_ i: Int) {
        tower = i
        ups = [:]
        picksDue = 0
        meter = 0
        hero = Hero()
        supT = -1
        clearFx()
        if i == 0 { hasSample = false; valveShut = false }
        floorN = tw.top + 1
        energy = 0; picksTaken = 0
        floor = makeFloor(floorN, entry: 300)
        hero.x = 300
        checkpoint(quiet: true)
        cardT = 0
        mode = .card
        snd?.stamp()
        save()
    }
    func save() {
        let d = UserDefaults.standard
        d.set(tower, forKey: "fz.tower")
        d.set(floorN, forKey: "fz.floor")
        d.set(ups, forKey: "fz.ups")
        d.set(hasSample, forKey: "fz.sample")
        d.set(valveShut, forKey: "fz.valve")
        d.set(deaths, forKey: "fz.deaths")
        d.set(hero.x, forKey: "fz.x")
        d.set(energy, forKey: "fz.energy"); d.set(picksTaken, forKey: "fz.picks")
    }
    func clearSave() {
        let d = UserDefaults.standard
        for k in ["fz.tower", "fz.floor", "fz.ups", "fz.sample", "fz.valve", "fz.deaths", "fz.x", "fz.energy", "fz.picks", "fz.cpFloor", "fz.cpUps", "fz.cpSample", "fz.cpValve", "fz.cpEnergy", "fz.cpPicks"] { d.removeObject(forKey: k) }
        deaths = 0; kills = 0; playT = 0
    }
    func resume() {
        let d = UserDefaults.standard
        tower = max(0, min(2, d.integer(forKey: "fz.tower")))
        floorN = max(0, min(tw.top + 1, d.integer(forKey: "fz.floor")))
        ups = (d.dictionary(forKey: "fz.ups") as? [String: Int]) ?? [:]
        hasSample = d.bool(forKey: "fz.sample")
        valveShut = d.bool(forKey: "fz.valve")
        deaths = d.integer(forKey: "fz.deaths")
        energy = d.double(forKey: "fz.energy"); picksTaken = d.integer(forKey: "fz.picks")
        cpFloor = d.object(forKey: "fz.cpFloor") != nil ? d.integer(forKey: "fz.cpFloor") : floorN
        cpUps = (d.dictionary(forKey: "fz.cpUps") as? [String: Int]) ?? ups
        cpSample = d.bool(forKey: "fz.cpSample"); cpValve = d.bool(forKey: "fz.cpValve"); cpEnergy = d.double(forKey: "fz.cpEnergy"); cpPicks = d.integer(forKey: "fz.cpPicks")
        hero = Hero()
        hero.maxHp = 100 + 25 * Double(lv("hp"))
        hero.hp = hero.maxHp
        let x = d.double(forKey: "fz.x")
        hero.x = x > 0 ? x : 300
        supT = -1; meter = 50; picksDue = 0
        clearFx()
        floor = makeFloor(floorN, entry: hero.x)
        fixEntry()
        mode = .play
        say("FLOOR \(floorN) — \(zone(floorN).name)")
    }
    func clearFx() {
        parts = []; floaters = []; rings = []; tracers = []; booms = []; nades = []; waves = []; beams = []; slashes = []; gibs = []; globs = []; fires = []; pows = []
    }

    func zone(_ n: Int) -> Zone {
        for z in tw.zones where n >= z.from { return z }
        return tw.zones[tw.zones.count - 1]
    }

    // ---------- floors
    func descTarget(_ n: Int, _ d: Int) -> Int {
        var to = max(0, n - d)
        if tower == 0 {
            if n > 32 && to < 32 { to = 32 }
            if n > 12 && to < 12 { to = 12 }
        }
        var c = n - 1
        while c > to { if isCheckpoint(c) { to = c; break }; c -= 1 }
        return to
    }
    /// A safe room every ten floors.
    func isCheckpoint(_ n: Int) -> Bool {
        let k = tw.top - n
        return n >= 1 && k > 0 && k % 10 == 0 && !(tower == 0 && (n == 32 || n == 12))
    }
    /// Floors until the next safe room, shown for the first stretch of each tower so players learn they exist.
    var safeIn: Int? {
        if depth > 31 || floor.kind == .safe || floor.kind == .street { return nil }
        var c = floorN - 1
        while c >= 1 { if isCheckpoint(c) { return floorN - c }; c -= 1 }
        return nil
    }
    var cpFloor = 0
    var cpUps: [String: Int] = [:]
    var cpSample = false
    var cpValve = false
    var cpEnergy = 0.0
    var cpPicks = 0
    var energy = 0.0
    var picksTaken = 0
    var energyNeed: Double { return 40 + 35 * Double(picksTaken) }
    func checkpoint(quiet: Bool = false) {
        cpFloor = floorN; cpUps = ups; cpSample = hasSample; cpValve = valveShut; cpEnergy = energy; cpPicks = picksTaken
        hero.hp = hero.maxHp
        let d = UserDefaults.standard
        d.set(cpFloor, forKey: "fz.cpFloor"); d.set(cpUps, forKey: "fz.cpUps"); d.set(cpSample, forKey: "fz.cpSample"); d.set(cpValve, forKey: "fz.cpValve"); d.set(cpEnergy, forKey: "fz.cpEnergy"); d.set(cpPicks, forKey: "fz.cpPicks")
        if !quiet { flash = 0.3; flashCol = MINT; snd?.heal(); buzz(2) }
    }
    func makeFloor(_ n: Int, entry: Double) -> Floor {
        let top = tw.top
        let k = top - n
        var rng = Rng(tower * 7919 + n * 131 + 17)
        let f = Floor(n)
        f.exitRight = ((top + 1 - n) % 2 == 0)
        f.exitX = f.exitRight ? FLOOR_W - 150 : 150
        let bossFloor = tower == 0 && n == 32
        let valveFloor = tower == 0 && n == 12
        if n > top { f.kind = .roof } else if n <= 0 { f.kind = .street } else if bossFloor || valveFloor { f.kind = .normal } else if isCheckpoint(n) { f.kind = .safe } else if n % 9 == 3 { f.kind = .lift } else if k % 10 == 5 && n > 6 { f.kind = .wall } else if k % 10 == 3 && n > 6 { f.kind = .rope } else if k % 5 == 1 && n > 3 { f.kind = .hole }
        // the last two floors above a safe room are outside, on the fire escape
        if f.kind == .normal && !bossFloor && !valveFloor && n > 3 && n <= top && (k % 10 == 8 || k % 10 == 9) { f.escape = true }
        if f.kind == .lift && (n / 9) % 2 == 0 { f.shaft = true }
        if f.kind == .hole {
            f.holeX = f.exitRight ? 1240 : 560
            f.fireStairs = (k / 5) % 2 == 0
        }
        if f.kind == .wall {
            f.wallX = 900 + rng.r(-120, 120)
            f.doorA = f.wallX - 250
            f.doorB = f.wallX + 250
        }
        // who is here
        var count = 6 + Int(Double(max(0, k)) * 0.11)
        if count > 15 { count = 15 }
        if f.kind == .roof { count = 5 }
        if f.kind == .street { count = 12 }
        let pr = min(0.38, 0.15 + Double(max(0, k)) * 0.005)
        let pd = min(0.14, max(0, Double(k - 6) * 0.006))
        func spot(_ r: inout Rng) -> Double {
            var x = r.r(220, FLOOR_W - 220)
            if abs(x - entry) < 380 { x = entry + (entry < FLOOR_W / 2 ? 1 : -1) * r.r(400, 900) }
            return clampD(x, 120, FLOOR_W - 120)
        }
        for _ in 0..<count {
            let r = rng.next()
            var kind = ZKind.zed
            if r < pr { kind = .runner } else if r > 1 - pd { kind = .dog } else if k > 14 && r > 0.5 && r < 0.56 { kind = .bloater } else if k > 1 && r > 0.6 && r < 0.7 { kind = .crawler } else if k > 9 && r > 0.72 && r < 0.79 { kind = .spitter } else if r > 0.40 && r < 0.45 { kind = .wheel } else if k > 5 && r > 0.45 && r < 0.5 { kind = .riot } else if k > 7 && r > 0.56 && r < 0.6 { kind = .burner } else if k > 11 && r > 0.79 && r < 0.83 { kind = .screamer }
            if f.kind == .roof { kind = .zed }
            f.zeds.append(Zed(id: nextId, kind: kind, x: spot(&rng), depth: max(0, k), seed: rng.next()))
            nextId += 1
        }
        if k > 8 && n > 1 && f.kind != .lift && !bossFloor {
            if k % 11 == 7 {
                f.pack = 1
                for _ in 0..<(4 + k / 25) { f.zeds.append(Zed(id: nextId, kind: .dog, x: spot(&rng), depth: k, seed: rng.next())); nextId += 1 }
            } else if k % 13 == 9 {
                f.pack = 2
                for _ in 0..<14 { f.zeds.append(Zed(id: nextId, kind: .rat, x: spot(&rng), depth: k, seed: rng.next())); nextId += 1 }
            }
        }
        if bossFloor && !hasSample {
            f.boss = true
            let b = Zed(id: nextId, kind: .boss, x: FLOOR_W / 2, depth: k, seed: 0.5)
            nextId += 1
            b.aware = true
            f.zeds.append(b)
        }
        if bossFloor && hasSample { f.zeds = [] }
        if f.kind == .roof || (k > 3 && k % 7 == 3 && !bossFloor) {
            for _ in 0..<(f.kind == .roof ? 2 : 3) { f.zeds.append(Zed(id: nextId, kind: .crow, x: spot(&rng), depth: max(0, k), seed: rng.next())); nextId += 1 }
        }
        f.reserve = f.kind == .street ? 12 : (k < 3 ? 2 : min(11, 5 + max(0, k) / 10))
        if bossFloor { f.reserve = 0 }
        if f.kind == .safe { f.reserve = 0 }
        if valveFloor && !valveShut { f.items.append(Item(x: FLOOR_W / 2, kind: 3)) }
        if f.kind != .roof {
            if rng.next() < 0.2 { f.items.append(Item(x: rng.r(300, FLOOR_W - 300), kind: 0)) }
            if rng.next() < 0.4 { f.items.append(Item(x: rng.r(350, FLOOR_W - 350), kind: 1)) }
            if rng.next() < 0.5 { f.items.append(Item(x: rng.r(350, FLOOR_W - 350), kind: 1)) }
            if rng.next() < 0.3 { f.items.append(Item(x: rng.r(350, FLOOR_W - 350), kind: 1)) }
        }
        var px = 260.0
        while px < FLOOR_W - 200 {
            if rng.next() < 0.6 { f.props.append(Prop(x: px + rng.r(-40, 40), kind: rng.i(5))) }
            px += 210
        }
        if f.escape { f.props = [] }
        if f.kind == .wall {
            let half = 85.0 + 70
            for z in f.zeds where abs(z.x - f.wallX) < half { z.x = f.wallX + (z.x < f.wallX ? -1 : 1) * (half + 20) }
            // nothing may sit between an office door and the fire: you could never reach it
            for i in 0..<f.items.count where abs(f.items[i].x - f.wallX) < 300 { f.items[i].x = f.wallX + (f.items[i].x < f.wallX ? -1 : 1) * rng.r(340, 460) }
            f.props = f.props.filter { abs($0.x - f.wallX) > 330 }
        }
        if f.kind == .hole { f.props = f.props.filter { abs($0.x - f.holeX) > 120 }; for i in 0..<f.items.count where abs(f.items[i].x - f.holeX) < 110 { f.items[i].x += 200 } }
        if f.kind == .lift { f.props = f.props.filter { abs($0.x - f.liftX) > 130 } }
        if f.kind == .safe { f.zeds = []; f.reserve = 0; f.items = []; f.pack = 0; f.props = f.props.filter { abs($0.x - FLOOR_W / 2) > 420 } }
        f.gunship = f.kind == .street || (f.kind == .normal && !bossFloor && !valveFloor && k > 4 && k % 9 == 6)
        for z in f.zeds { dress(z, n) }
        return f
    }
    /// Who would have been on this floor when it happened.
    func dress(_ z: Zed, _ n: Int) {
        let name = n > tw.top ? "ROOF" : (n <= 0 ? "STREET" : zone(n).name)
        var jobs: [Int] = [7, 0, 1, 9, 4]
        switch name {
        case "OFFICES": jobs = [0, 0, 1, 1, 4, 5]
        case "HOTEL", "GUEST ROOMS", "PENTHOUSES": jobs = [6, 6, 7, 7, 2, 5, 4]
        case "BALLROOMS", "CASINO": jobs = [6, 2, 2, 0, 1, 4]
        case "MEDICAL / LAB", "WARDS", "SURGERY", "LABS", "EMERGENCY": jobs = [3, 3, 3, 8, 8, 5]
        case "MALL / GARAGE": jobs = [7, 7, 9, 9, 2, 4]
        case "RESIDENTIAL": jobs = [7, 7, 7, 8, 2, 9]
        case "LOBBY": jobs = [4, 4, 0, 1, 6, 5]
        default: break
        }
        z.job = jobs[Int(hashN(z.seed * 17.3 + Double(z.id)) * Double(jobs.count)) % jobs.count]
        if z.kind == .wheel { z.job = hashN(z.seed * 2.2) > 0.3 ? 8 : 7 }
    }
    /// After landing, make sure the hero is not standing in a hazard.
    func fixEntry() {
        let f = floor
        hero.x = clampD(hero.x, 80, FLOOR_W - 80)
        if f.kind == .wall && abs(hero.x - f.wallX) < 130 {
            hero.x = f.wallX + (f.exitRight ? 1 : -1) * 170
        }
        if f.kind == .hole && abs(hero.x - f.holeX) < 70 { hero.x = f.holeX + (f.exitRight ? -1 : 1) * 110 }
        if f.kind == .lift && abs(hero.x - f.liftX) < 70 { hero.x = f.liftX + (f.exitRight ? -1 : 1) * 120 }
        f.wallSide = sgn(hero.x - f.wallX)
    }

    func startRide(_ kind: RideKind, to: Int) {
        rideKind = kind
        rideFrom = floorN
        rideTo = to
        rideT = 0
        switch kind {
        case .stairs: rideDur = 0.5
        case .hole: rideDur = 0.8
        case .lift: rideDur = 1.5
        case .rope: rideDur = 3.0
        case .ladder: rideDur = 1.4
        case .shaft: rideDur = 1.7
        }
        rideTap = false; grabDone = false; grabWon = false
        mode = .ride
        input = Input()
        if kind == .rope || kind == .shaft { snd?.whoosh(); buzz(1) } else if kind == .ladder { snd?.stairs() } else if kind == .hole { snd?.drop(); buzz(2) } else if kind == .lift { snd?.ding(); snd?.liftHum() } else { snd?.door(); snd?.stairs() }
    }
    func arrive() {
        let old = floorN
        floorN = rideTo
        _ = old
        clearFx()
        floor = makeFloor(floorN, entry: hero.x)
        fixEntry()
        hero.atkT = -1
        supT = -1
        if rideKind == .lift { snd?.ding() }
        if rideKind == .hole { shake = 14; puff(hero.x, 0, 14, Col(0x8a8478)); buzz(3) }
        if floor.kind == .safe { checkpoint() }
        announce()
        save()
        if picksDue > 0 { rollPick(); mode = .pick; pickT = 0 } else { mode = .play }
    }
    func announce() {
        let f = floor
        let n = f.n
        switch f.kind {
        case .roof: say("THE ROOF. THE STAIRS ARE THAT WAY  ▶", 4)
        case .safe: say("FLOOR \(n) — SAFE ROOM. CHECKPOINT SAVED.", 4)
        case .street: say("THE STREET. GET TO THE PLAZA.", 4)
        case .wall: say("FLOOR \(n) — FIRE. CUT THROUGH THE \(sideName).", 4)
        case .hole: say(f.fireStairs ? "FLOOR \(n) — STAIRS ON FIRE. DROP THROUGH THE FLOOR." : "FLOOR \(n) — STAIRS GONE. DROP THROUGH THE FLOOR.", 4)
        case .lift: say(f.shaft ? "FLOOR \(n) — NO CAR. CLEAR IT. SLIDE DOWN THE SHAFT." : "FLOOR \(n) — STAIRS BLOCKED. CLEAR IT. TAKE THE ELEVATOR.", 4)
        case .rope: say("FLOOR \(n) — STAIRS COLLAPSED. ROPE DOWN THE OUTSIDE.", 4)
        case .normal:
            if f.escape { say("FLOOR \(n) — STAIRWELL GONE. OUT ON THE FIRE ESCAPE.", 3.5) } else if f.boss { snd?.roar(); say("FLOOR 32 — DR. MARR.", 4) } else if tower == 0 && n == 12 && !valveShut { say("FLOOR 12 — THE WATER MAIN. SHUT IT.", 4) } else if f.pack == 1 { say("FLOOR \(n) — DOGS. THEY ARE FAST.") } else if f.pack == 2 { say("FLOOR \(n) — RATS.") } else { say("FLOOR \(n) — \(zone(n).name)", 2.2) }
        }
    }

    // ---------- upgrades
    func rollPick() {
        let deep = upTotal >= 4
        var ok: [Int] = []
        for i in 0..<UPS.count where lv(UPS[i].id) < 3 && (!UPS[i].sup || deep) { ok.append(i) }
        ok.shuffle()
        if let g = ok.firstIndex(where: { UPS[$0].gun }), g > 0 { ok.swapAt(0, g) }
        if deep && ok.count > 2 && !UPS[ok[0]].sup && !UPS[ok[1]].sup && chance(0.6) {
            if let s = ok.firstIndex(where: { UPS[$0].sup }), s > 1 { ok.swapAt(1, s) }
        }
        pickOpts = Array(ok.prefix(2))
        if pickOpts.isEmpty { picksDue = 0 }
        pickChosen = -1
        snd?.stamp()
    }
    var pickChosen = -1
    var pickOutT = 0.0
    func choosePick(_ i: Int) {
        if mode != .pick || i < 0 || i >= pickOpts.count || pickT < 0.45 || pickChosen >= 0 { return }
        pickChosen = i
        pickOutT = 0
        flash = 0.25; flashCol = UPS[pickOpts[i]].sup ? Col(0xff6ac8) : GOLD
        snd?.pick(); buzz(3)
    }
    private func applyPick() {
        let i = pickChosen
        pickChosen = -1
        if i < 0 || i >= pickOpts.count { mode = .play; return }
        let u = UPS[pickOpts[i]]
        ups[u.id] = lv(u.id) + 1
        if u.id == "hp" { hero.maxHp = 100 + 25 * Double(lv("hp")); hero.hp = hero.maxHp }
        picksDue -= 1
        hero.inv = max(hero.inv, 1.0)
        save()
        if picksDue > 0 { rollPick(); pickT = 0 }
        if picksDue <= 0 || pickOpts.isEmpty { picksDue = 0; mode = .play; say("\(u.name)  ·  LEVEL \(lv(u.id))") }
    }

    // ---------- the frame
    func update(_ dtRaw: Double) {
        let dt = min(dtRaw, 1.0 / 20)
        t += dt
        shake = max(0, shake - dt * 40)
        flash = max(0, flash - dt * 3)
        snd?.here()
        ambience(dt)
        if msgT > 0 { msgT -= dt }
        if sayCd > 0 { sayCd -= dt }
        switch mode {
        case .title: break
        case .intro:
            let before = Int(introT / 1.8)
            if !introFreeze { introT += dt }
            if Int(introT / 1.8) != before && introT < introLen { snd?.stamp(); buzz(1) }
            if introT >= introLen { startTower(0) }
        case .card:
            cardT += dt
            if cardT > 2.4 { mode = .play; announce() }
        case .play:
            if hitStop > 0 { hitStop -= dtRaw; return }
            playT += dt
            if auto { bot() }
            zoom += (1 - zoom) * min(1, dt * 7)
            muzzle = max(0, muzzle - dt * 9)
            if slowT > 0 { slowT -= dtRaw; updatePlay(dt * 0.35) } else { updatePlay(dt) }
        case .pick:
            pickT += dt
            if auto && pickT > 0.6 { choosePick(0) }
            if pickChosen >= 0 { pickOutT += dt; if pickOutT > 0.45 { applyPick() } }
        case .ride:
            rideT += dt
            if rideFreeze >= 0 { rideT = rideFreeze }
            if rideKind == .rope && !grabDone && rideT > 0.95 {
                if auto && rideT > 1.4 { rideTap = true }
                if rideTap {
                    grabDone = true; grabWon = true; grabAt = rideT
                    snd?.bigHit(); snd?.squelch(); buzz(2); shake = 10
                } else if rideT > 1.9 {
                    grabDone = true; grabWon = false
                    hero.hp = max(1, hero.hp - 14 * (1 - 0.15 * Double(lv("armor"))))
                    snd?.groan(1); buzz(3); flash = 0.5; flashCol = HOT; shake = 12
                }
            }
            rideTap = false
            updateFx(dt)
            if rideT >= rideDur { arrive() }
        case .dead:
            deadT += dt
            updateFx(dt)
            if deadT > 2.0 { respawn() }
        case .ending:
            endT += dt
        }
    }
    var ambT = 2.0
    var humT = 0.0
    var stepT = 0.0
    var stepAlt = false
    /// The building around you: hum, wind, and things far off.
    private func ambience(_ dt: Double) {
        guard let s = snd, mode == .play || mode == .ride || mode == .pick else { return }
        let f = floor
        let outside = f.kind == .roof || f.kind == .street
        humT -= dt
        if humT <= 0 { humT = 2.2; if outside { s.wind() } else { s.hum() } }
        if mode == .ride { return }
        ambT -= dt
        if ambT <= 0 {
            ambT = rnd(3, 7)
            s.pan = rnd(-1, 1); s.near = rnd(0.4, 0.8)
            let r = Double.random(in: 0..<1)
            if outside { if r < 0.5 { s.siren() } else { s.moan() } } else if r < 0.4 { s.moan() } else if r < 0.6 { s.creak() } else if r < 0.75 { s.drip() } else if r < 0.85 { s.siren() } else if f.kind == .wall || !fires.isEmpty { s.alarm() }
            s.here()
        }
        if f.kind == .wall && Int(t * 1.5) != Int((t - dt) * 1.5) { s.at(f.wallX - hero.x); s.alarm(); s.here() }
        // wheels and wings you can hear coming
        for z in f.zeds where z.alive && z.aware && (z.kind == .wheel || z.kind == .crow) && chance(dt * 1.6) {
            s.at(z.x - hero.x); if z.kind == .wheel { s.wheel() } else { s.caw() }; s.here()
        }
    }
    func tapAdvance() {
        if mode == .intro {
            let next = ((introT / 1.8).rounded(.down) + 1) * 1.8
            introT = next
            if introT >= introLen { startTower(0) } else { snd?.stamp() }
        } else if mode == .card && cardT > 0.4 { cardT = 9 } else if mode == .ending && endT > 1.5 { mode = .title }
    }

    func respawn() {
        floorN = cpFloor
        ups = cpUps
        hasSample = cpSample
        valveShut = cpValve
        energy = cpEnergy
        picksTaken = cpPicks
        picksDue = 0
        hero = Hero()
        hero.maxHp = 100 + 25 * Double(lv("hp"))
        hero.hp = hero.maxHp
        hero.inv = 1.5
        supT = -1
        meter = 50
        clearFx()
        floor = makeFloor(floorN, entry: 300)
        hero.x = floor.exitRight ? 300 : FLOOR_W - 300
        fixEntry()
        save()
        mode = .play
        say(floorN > tw.top ? "BACK ON THE ROOF. TRY AGAIN." : "BACK AT THE SAFE ROOM · FLOOR \(floorN)", 4)
    }

    var dmgMul: Double { return (1 + 0.25 * Double(lv("dmg"))) * (1 + Double(depth) * 0.006) }

    private func updatePlay(_ dt: Double) {
        let f = floor
        let h = hero
        if hitsT > 0 { hitsT -= dt; if hitsT <= 0 { hits = 0 } }
        if nameT > 0 { nameT -= dt }
        h.inv = max(0, h.inv - dt)
        groanCd -= dt
        if groanCd < -5 && aliveCount > 0 && chance(dt * 0.5) { groanCd = 1.5; snd?.groan(rnd(0.7, 1.3)) }
        heartCd -= dt
        if h.hp < h.maxHp * 0.3 && heartCd <= 0 { heartCd = 0.85; snd?.heart(); buzz(1) }
        if floor.kind == .wall && abs(h.x - floor.wallX) < 600 && chance(dt * 14) { snd?.crackle() }
        h.hurtT = max(0, h.hurtT - dt)
        if h.comboT > 0 { h.comboT -= dt }

        // moving
        let sup = supT >= 0
        var mv = input.move
        if abs(mv) < 0.2 { mv = 0 }
        heroSlow = max(0, heroSlow - dt)
        let sp = 265 * (1 + 0.08 * Double(lv("adren"))) * (h.atkT >= 0 ? 0.35 : 1) * (heroSlow > 0 ? 0.55 : 1)
        if !sup {
            h.moving = mv != 0
            if mv != 0 {
                stepT -= dt
                if stepT <= 0 { stepT = 0.26; stepAlt.toggle(); snd?.foot(stepAlt) }
                h.x += sgn(mv) * sp * dt
                h.walk += sp * dt
                if h.atkT < 0 { h.face = sgn(mv) }
            }
        } else { h.moving = false }

        // swinging: a swipe picks the move, a tap or a hold gives a random one, and every fourth is a finisher
        if input.swipe != 0 { swipeAge += dt; if swipeAge > 0.45 { input.swipe = 0 } }
        if swipeShowT > 0 { swipeShowT -= dt }
        let sw = input.swipe
        if (input.attack || sw != 0) && h.atkT < 0 && !sup {
            input.swipe = 0; swipeAge = 0
            h.chain = h.comboT > 0 ? (h.chain + 1) % 4 : 0
            h.atkI = h.chain == 3 ? 2 : 0
            if sw > 1 {
                let last = h.chain == 3
                if sw == 2 || sw == 3 { h.face = sw == 2 ? 1 : -1; h.atkStyle = last ? 6 : 2 }        // thrust, spin to finish
                else if sw == 4 { h.atkStyle = last ? 8 : 5 }                                        // uppercut, launcher to finish
                else { h.atkStyle = last ? 7 : 3 }                                                   // low sweep, jump slam to finish
            } else if h.chain == 3 { h.atkStyle = 6 + Int.random(in: 0..<3) } else {
                var st = Int.random(in: 0..<6)
                if st == h.atkStyle { st = (st + 1) % 6 }
                h.atkStyle = st
            }
            h.crit = -1
            if h.chain != 3 && sw <= 1 && nearest(210) != nil && chance(0.1) { h.crit = Int.random(in: 0..<5); h.atkStyle = [4, 9, 1, 5, 7][h.crit] }
            if h.chain != 3 && sw > 1 && nearest(210) != nil && chance(0.1) { h.crit = sw == 4 ? 3 : (sw == 5 ? 4 : Int.random(in: 0..<3)); h.atkStyle = [4, 9, 1, 5, 7][h.crit] }
            h.atkT = 0
            h.atkHit = false
            if mv == 0 && sw != 2 && sw != 3, let z = nearest(190) { h.face = z.x >= h.x ? 1 : -1 }
            if h.chain == 3 { snd?.whoosh() } else { snd?.swing() }
        }
        if h.atkT >= 0 {
            let fin = h.atkI == 2
            let dur = fin || h.crit >= 0 ? 0.4 : (h.atkStyle == 2 ? 0.2 : 0.25)
            h.atkT += dt
            h.jump = h.atkStyle == 7 ? sin(clampD(h.atkT / (dur * 0.5), 0, 1) * PI) * 46 : 0
            if h.atkStyle == 2 && h.atkT < dur * 0.4 { h.x += h.face * 260 * dt }
            if !h.atkHit && h.atkT >= dur * (fin ? 0.5 : 0.42) {
                h.atkHit = true
                var reach = 112.0, base = 15.0, knock = 70.0
                var both = false
                switch h.atkStyle {
                case 2: reach = 140; base = 14; knock = 110          // thrust
                case 3: reach = 118; base = 13; knock = 40           // low sweep
                case 4: reach = 96; base = 12; knock = 430           // kick
                case 5: reach = 112; base = 18; knock = 260          // uppercut
                case 6: reach = 150; base = 28; knock = 470; both = true   // spin
                case 7: reach = 130; base = 32; knock = 480          // jump slam
                case 8: reach = 124; base = 36; knock = 560          // launcher
                case 9: reach = 118; base = 20; knock = 300          // punch
                default: break
                }
                var n = 0
                var struck: [Zed] = []
                if h.crit >= 0 { reach += 30 }
                for z in f.zeds where z.alive {
                    let dx = (z.x - h.x) * h.face
                    let inReach: Bool = both ? abs(dx) < reach : (dx > -24 && dx < reach)
                    if inReach {
                        struck.append(z)
                        hit(z, base * dmgMul, both ? (z.x >= h.x ? 1 : -1) : h.face, knock)
                        if h.atkStyle == 3 { z.stun = max(z.stun, 0.6) }
                        n += 1
                    }
                }
                for i in 0..<f.items.count where f.items[i].kind == 1 && !f.items[i].used {
                    let dx = (f.items[i].x - h.x) * h.face
                    if (dx > -10 || both) && abs(dx) < reach { f.items[i].used = true; explode(f.items[i].x, 170, 90) }
                }
                var mode = 0
                switch h.atkStyle {
                case 1, 5, 8: mode = 1
                case 2: mode = 2
                case 3, 4: mode = 3
                case 6: mode = 4
                default: mode = 0
                }
                slashes.append(Slash(x: h.x, y: -92, face: h.face, t: 0, big: fin ? 1.4 : 1, col: tw.hue, mode: mode))
                if h.crit >= 0 { overTheTop(struck) }
                if h.atkStyle == 7 {
                    waves.append(Wave(x: h.x, dir: 1, left: 260, dmg: 22 * dmgMul, hit: []))
                    waves.append(Wave(x: h.x, dir: -1, left: 260, dmg: 22 * dmgMul, hit: []))
                    shake = max(shake, 14); snd?.blast()
                }
                if n > 0 {
                    if fin { zoom = 1.07; if n >= 2 { slowT = 0.22 } }
                    hitStop = fin ? 0.08 : 0.035
                    shake = max(shake, fin ? 11 : 4)
                    addMeter(3 * Double(n))
                    if fin { snd?.bigHit() } else { snd?.hit(0.8) }
                    buzz(fin ? 3 : 1)
                }
            }
            if h.atkT >= dur { h.atkT = -1; h.comboT = 0.5; h.jump = 0 }
        }

        // power move
        if input.power && !sup && meter >= 100 { startSuper() }
        input.power = false
        if supT >= 0 { updateSuper(dt) }

        // the fire wall
        if f.kind == .wall {
            let e = 85.0 + 24
            if abs(h.x - f.wallX) >= e { f.wallSide = sgn(h.x - f.wallX) } else {
                let sd = f.wallSide != 0 ? f.wallSide : (h.x < f.wallX ? -1 : 1)
                h.x = f.wallX + sd * e
                if supT < 0 { hurtHero(10 * dt, f.wallX, quiet: true) }
                if sayCd <= 0 { sayCd = 4; say("TOO HOT. CUT THROUGH THE \(sideName).") }
            }
            for z in f.zeds where z.alive && abs(z.x - f.wallX) < 85 { z.burn = max(z.burn, 1.5); z.burnDps = max(z.burnDps, 22) }
            if chance(dt * 40) { parts.append(Part(x: f.wallX + rnd(-85, 85), y: -rnd(0, 220), vx: rnd(-20, 20), vy: -rnd(90, 220), t: 0, life: rnd(0.35, 0.6), size: rnd(6, 13), col: Col(0xff9a30), grav: 0, glow: true)) }
        }
        h.x = clampD(h.x, 70, FLOOR_W - 70)

        updateZeds(dt)
        updateArsenal(dt)
        updateFx(dt)
        interact()
        if picksDue > 0 && mode == .play && supT < 0 && h.hp > 0 && h.atkT < 0 { rollPick(); if !pickOpts.isEmpty { mode = .pick; pickT = 0; input = Input() } }
        gunshipRun(dt)
        if h.hp <= 0 && mode == .play {
            mode = .dead
            deadT = 0
            deaths += 1
            snd?.dead(); buzz(3)
            flash = 0.6; flashCol = BLOOD
        }
    }

    /// One swing in five turns into something ridiculous.
    private func overTheTop(_ struck: [Zed]) {
        let h = hero
        let names = ["EXPLOSIVE KICK", "DYNAMITE PUNCH", "HOME RUN", "SKY UPPERCUT", "METEOR SLAM"]
        supName = names[h.crit]
        nameT = 1.2
        zoom = 1.13
        slowT = 0.32
        flash = 0.35; flashCol = tw.hue
        shake = max(shake, 20)
        buzz(3)
        snd?.bigHit()
        let near = struck.min(by: { abs($0.x - h.x) < abs($1.x - h.x) })
        switch h.crit {
        case 0:
            splatter(near?.x ?? (h.x + h.face * 90), 180, 70 * dmgMul, h.face)
            if let z = near { launch(z, h.face * 950, -320) }
        case 1:
            explode(h.x + h.face * 90, 200, 90 * dmgMul)
        case 2:
            if let z = near { launch(z, h.face * 1350, -160) }
            snd?.clang()
        case 3:
            for z in struck { launch(z, h.face * rnd(20, 120), -rnd(1000, 1250)) }
            rings.append(Ring(x: h.x + h.face * 60, y: -80, r: 200, t: 0, life: 0.35, col: tw.hue))
        default:
            // the slam bursts everything around him: guts, not fire
            splatter(h.x - 150, 170, 55 * dmgMul, -1)
            splatter(h.x + 150, 170, 55 * dmgMul, 1)
        }
    }
    /// Send one flying. It hurts whatever it hits on the way and bursts where it lands.
    func launch(_ z: Zed, _ vx: Double, _ vy: Double) {
        if z.kind == .boss || z.kind == .bloater || z.kind == .crow || z.kind == .rat { return }
        if z.alive { z.hp = 0; kill(z, sgn(vx), false) }
        if z.kind == .burner { return }
        z.gibbed = false
        z.headless = false
        z.flyT = 0
        z.flyVx = vx
        z.flyVy = vy
        z.y = -20
    }
    func addMeter(_ v: Double) { meter = min(100, meter + v * (1 + 0.25 * Double(lv("adren")))) }
    func nearest(_ r: Double, facing: Bool = false) -> Zed? {
        var best: Zed? = nil
        var bd = r
        for z in floor.zeds where z.alive {
            let d = abs(z.x - hero.x)
            if facing && (z.x - hero.x) * hero.face < 0 { continue }
            if d < bd { bd = d; best = z }
        }
        return best
    }
    var threatCount: Int { return aliveCount + floor.reserve }
    var aliveCount: Int { var n = 0; for z in floor.zeds where z.alive { n += 1 }; return n }

    // ---------- zombies
    private func updateZeds(_ dt: Double) {
        let h = hero
        let f = floor
        // more of them burst out of the doors while you fight
        if f.reserve > 0 {
            f.spawnT -= dt
            if f.spawnT <= 0 && aliveCount < 11 {
                f.spawnT = aliveCount < 3 ? 0.5 : 1.3
                f.reserve -= 1
                var x = 200 + 300 * Double(Int.random(in: 0..<5)) + 33
                if abs(x - h.x) < 260 { x += x < h.x ? -300 : 300 }
                if f.kind == .wall && abs(x - f.wallX) < 170 { x = f.wallX + (x < f.wallX ? -200 : 200) }
                x = clampD(x, 120, FLOOR_W - 120)
                let r = Double.random(in: 0..<1)
                var kind = ZKind.zed
                if r < 0.3 { kind = .runner } else if r < 0.42 && depth > 1 { kind = .crawler } else if r < 0.5 && depth > 6 { kind = .dog } else if r < 0.57 { kind = .wheel } else if r < 0.62 && depth > 7 { kind = .burner }
                let z = Zed(id: nextId, kind: kind, x: x, depth: depth, seed: Double.random(in: 0..<1))
                nextId += 1
                z.aware = true
                z.stun = 0.25
                dress(z, f.n)
                f.zeds.append(z)
                puff(x, 0, 10, Col(0x8a7a66))
                for _ in 0..<5 { gibs.append(Gib(x: x, y: -rnd(40, 150), vx: rnd(-260, 260), vy: -rnd(60, 320), rot: rnd(0, 6), vr: rnd(-12, 12), kind: 4, col: Col(0x6a5238), t: 0)) }
                shake = max(shake, 5)
                snd?.at(x - h.x); snd?.door(); snd?.here()
            }
        }
        for z in f.zeds {
            if !z.alive {
                z.deadT += dt; z.flash = max(0, z.flash - dt * 6)
                if z.flyT >= 0 && !z.gibbed {
                    z.flyT += dt
                    z.x += z.flyVx * dt
                    z.flyVy += 1500 * dt
                    z.y += z.flyVy * dt
                    z.flyRot += dt * 15 * sgn(z.flyVx == 0 ? 1 : z.flyVx)
                    if parts.count < 520 && chance(dt * 40) { parts.append(Part(x: z.x, y: z.y - 60, vx: rnd(-60, 60), vy: rnd(-40, 120), t: 0, life: 0.5, size: rnd(3, 6), col: BLOOD, grav: 900, glow: false)) }
                    for q in f.zeds where q.alive && abs(q.x - z.x) < 48 && z.y > -190 { hit(q, 40 * dmgMul, sgn(z.flyVx), 520) }
                    if z.y < -280 {
                        // into the ceiling
                        z.gibbed = true
                        gore(z, 0, all: true)
                        floor.splats.append((z.x, 262, 30)); floor.splats.append((z.x + 30, 250, 18))
                        for _ in 0..<8 { gibs.append(Gib(x: z.x + rnd(-30, 30), y: -290, vx: rnd(-160, 160), vy: rnd(0, 200), rot: rnd(0, 6), vr: rnd(-12, 12), kind: 4, col: Col(0x8a8478), t: 0)) }
                        shake = max(shake, 12); snd?.at(z.x - h.x); snd?.bigHit(); snd?.here()
                    } else if z.x < 80 || z.x > FLOOR_W - 80 || (z.y >= 0 && z.flyT > 0.12) {
                        z.gibbed = true
                        z.x = clampD(z.x, 80, FLOOR_W - 80)
                        gore(z, sgn(z.flyVx), all: true)
                        splatter(z.x, 130, 45 * dmgMul, sgn(z.flyVx))
                    }
                }
                continue
            }
            z.flash = max(0, z.flash - dt * 5)
            z.cd -= dt
            if z.burn > 0 {
                z.burn -= dt
                z.hp -= z.burnDps * dt
                if chance(dt * 14) { parts.append(Part(x: z.x + rnd(-12, 12), y: -rnd(20, 120) * z.scale, vx: rnd(-20, 20), vy: -rnd(60, 140), t: 0, life: 0.4, size: rnd(4, 8), col: Col(0xffa030), grav: 0, glow: true)) }
                if z.hp <= 0 { kill(z, 0, false); continue }
            }
            let dx = h.x - z.x
            let ad = abs(dx)
            if !z.aware && ad < z.sight {
                z.aware = true
                if groanCd <= 0 { groanCd = 1.0; snd?.at(z.x - h.x); if z.kind == .dog { snd?.bark() } else if z.kind == .rat { snd?.squeak() } else if z.kind == .crow { snd?.caw() } else if z.kind == .wheel { snd?.wheel() } else if z.kind == .boss { snd?.roar() } else { snd?.groan((z.female ? 1.25 : 0.8) + z.seed * 0.5) }; snd?.here() }
            }
            if z.kvx != 0 {
                z.x += z.kvx * dt
                z.kvx *= pow(0.004, dt)
                if abs(z.kvx) < 12 { z.kvx = 0 }
            }
            z.x = clampD(z.x, 60, FLOOR_W - 60)
            if z.kind == .crow {
                let dive: Double = z.atkT >= 0 ? sin(min(1, z.atkT / (z.windup + 0.28)) * PI) * 105 : 0
                z.y = -196 + sin(t * 3 + z.seed * 9) * 12 + dive
            }
            if z.kind == .boss {
                // Marr throws what he made, and calls the floor down on you as he weakens
                z.spitCd -= dt
                if z.spitCd <= 0 && ad > 150 && z.atkT < 0 {
                    z.spitCd = 2.2
                    for k2 in 0..<3 { globs.append(Glob(x: z.x + z.face * 30, y: -230, vx: (h.x - z.x) / 0.8 + Double(k2 - 1) * 120, vy: -300 - Double(k2) * 40, t: 0)) }
                    snd?.at(z.x - h.x); snd?.bite(); snd?.here()
                }
                let phase = z.hp < z.maxHp * 0.3 ? 2 : (z.hp < z.maxHp * 0.65 ? 1 : 0)
                if phase > z.shield {
                    z.shield = phase
                    f.reserve += 5; f.spawnT = 0.1
                    z.speed *= 1.35
                    shake = 22; flash = 0.4; flashCol = MINT
                    say(phase == 1 ? "MARR IS CHANGING." : "MARR IS FURIOUS.", 3)
                    snd?.roar(); buzz(3)
                    burst(z.x, 260, 0, MINT)
                }
            }
            if z.kind == .burner {
                z.burn = 0
                if parts.count < 520 && chance(dt * 30) { parts.append(Part(x: z.x + rnd(-14, 14), y: -rnd(20, 150) * z.scale, vx: rnd(-30, 30), vy: -rnd(80, 200), t: 0, life: rnd(0.3, 0.6), size: rnd(5, 11), col: Col(0xff9a30), grav: 0, glow: true)) }
            }
            if z.screamT > 0 {
                z.screamT -= dt
                if chance(dt * 12) { rings.append(Ring(x: z.x + z.face * 20, y: -190, r: 260, t: 0, life: 0.45, col: Col(0xe8f0ff, 0.7))) }
                continue
            }
            if z.kind == .screamer && z.aware && z.stun <= 0 && z.atkT < 0 {
                z.screamCd -= dt
                if z.screamCd <= 0 && ad < 760 {
                    z.screamCd = 7
                    z.screamT = 0.9
                    f.reserve = min(12, f.reserve + 2)
                    f.spawnT = 0.2
                    for q in f.zeds where q.alive { q.aware = true }
                    heroSlow = 1.2
                    shake = max(shake, 12)
                    floaters.append(Floater(x: z.x, y: -230, text: "SCREEEEAM", col: Col(0xe8f0ff), t: -0.3, size: 20))
                    snd?.at(z.x - h.x); snd?.scream(); snd?.here(); buzz(2)
                    continue
                }
            }
            if z.stun > 0 { z.stun -= dt; continue }
            if z.atkT >= 0 {
                z.atkT += dt
                let wu = z.atkKind == 2 ? z.windup * 1.5 : z.windup
                if z.atkKind == 1 && z.atkT < wu { z.x += z.face * 330 * dt; z.walk += 330 * dt }
                if z.kind == .crow { z.x += z.face * 240 * dt }
                let nd = abs(h.x - z.x)
                if !z.atkHit && z.atkT >= wu {
                    z.atkHit = true
                    let extra: Double = z.atkKind == 2 ? 24 : 0
                    if nd < z.reach + 22 + extra {
                        let mul: Double = z.atkKind == 2 ? 1.5 : (z.atkKind == 1 ? 1.2 : 1)
                        hurtHero(z.dmg * mul * (1 + Double(depth) * 0.004), z.x, quiet: false)
                        if z.kind == .wheel && supT < 0 && h.inv > 0.4 { h.x = clampD(h.x + z.face * 70, 70, FLOOR_W - 70); shake = max(shake, 10) }
                        if z.kind == .burner && supT < 0 { hurtHero(5, z.x, quiet: true); for _ in 0..<6 { parts.append(Part(x: h.x + rnd(-12, 12), y: -rnd(30, 130), vx: rnd(-40, 40), vy: -rnd(80, 200), t: 0, life: 0.5, size: rnd(5, 9), col: Col(0xff9a30), grav: 0, glow: true)) } }
                    }
                    if z.atkKind == 2 { shake = max(shake, 6); puff(z.x + z.face * 50, 0, 5, Col(0x8a8478)) }
                }
                if z.atkT > wu + 0.28 { z.atkT = -1; z.cd = z.rate }
                continue
            }
            if !z.aware { z.walk += 8 * dt; continue }
            z.face = dx >= 0 ? 1 : -1
            if z.kind == .spitter {
                z.spitCd -= dt
                if ad < 230 { z.x -= z.face * z.speed * dt; z.walk += z.speed * dt } else if ad > 430 { z.x += z.face * z.speed * dt; z.walk += z.speed * dt }
                if z.spitCd <= 0 && ad < 620 {
                    z.spitCd = 2.3
                    z.atkT = 0; z.atkHit = true; z.atkKind = 0
                    let tt = 0.75
                    globs.append(Glob(x: z.x + z.face * 20, y: -118, vx: (h.x - z.x) / tt, vy: -260, t: 0))
                    snd?.bite()
                }
                continue
            }
            if ad > z.reach {
                let canLunge = z.kind == .zed || z.kind == .runner || z.kind == .dog || z.kind == .burner
                if canLunge && ad < z.reach + 150 && ad > z.reach + 40 && z.cd <= 0 && chance(dt * 3.2) {
                    z.atkT = 0; z.atkHit = false; z.atkKind = 1
                    if z.kind == .dog { snd?.bark() }
                } else {
                    z.x += z.face * z.speed * dt
                    z.walk += z.speed * dt
                }
            } else if z.cd <= 0 {
                z.atkT = 0
                z.atkHit = false
                z.atkKind = (z.kind == .zed || z.kind == .bloater || z.kind == .boss) && chance(0.35) ? 2 : 0
                if z.kind == .dog && chance(0.5) { snd?.bark() }
            }
        }
        f.zeds.removeAll { !$0.alive && ($0.deadT > 7 || $0.gibbed) }
        // spit in the air
        for i in 0..<globs.count {
            globs[i].t += dt
            globs[i].vy += 700 * dt
            globs[i].x += globs[i].vx * dt
            globs[i].y += globs[i].vy * dt
            if abs(globs[i].x - h.x) < 30 && globs[i].y > -150 && globs[i].y < -10 {
                globs[i].t = 9
                hurtHero(9 * (1 + Double(depth) * 0.004), globs[i].x - globs[i].vx, quiet: false)
                puff(h.x, -80, 6, Col(0x8cff7a))
            }
        }
        globs.removeAll { $0.t > 3 || $0.y > 0 }
    }
    /// Help from outside: a gunship rakes the floor through the windows.
    private func gunshipRun(_ dt: Double) {
        let f = floor
        if !f.gunship { return }
        if f.gunT < 0 {
            if aliveCount >= 4 || (f.kind == .street && aliveCount >= 2) { f.gunT = 0; say("AIR SUPPORT INBOUND. STAY BACK.", 3) }
            return
        }
        let before = f.gunT
        f.gunT += dt
        if Int(f.gunT / 0.1) != Int(before / 0.1) { snd?.rotor() }
        let passes = f.kind == .street ? 4 : 2
        let ph = f.gunT - 1.6
        f.gunX = -1
        if ph < 0 { return }
        let p = Int(ph / 3.6)
        let u = (ph - Double(p) * 3.6) / 2.6
        if p >= passes || u > 1 { if p >= passes { f.gunship = false }; return }
        let gx = (p % 2 == 0 ? u : 1 - u) * FLOOR_W
        f.gunX = gx
        shake = max(shake, 5)
        if chance(dt * 22) { snd?.at(gx - hero.x); snd?.shot(); snd?.here() }
        for _ in 0..<2 {
            let ix = gx + rnd(-60, 60)
            tracers.append(Tracer(x0: ix + 240, y0: -320, x1: ix, y1: 0, t: 0, life: 0.07, col: Col(0xfff0b0), w: 3, bolt: false))
            if parts.count < 520 { parts.append(Part(x: ix, y: 0, vx: rnd(-160, 160), vy: -rnd(120, 420), t: 0, life: rnd(0.2, 0.5), size: rnd(2, 5), col: Col(0xfff2b0), grav: 900, glow: true)) }
        }
        for z in f.zeds where z.alive && abs(z.x - gx) < 70 { hit(z, 260 * dt + 3, p % 2 == 0 ? 1 : -1, 470) }
        if abs(hero.x - gx) < 40 && supT < 0 { hurtHero(10 * dt, gx, quiet: true) }
        for i in 0..<f.items.count where f.items[i].kind == 1 && !f.items[i].used && abs(f.items[i].x - gx) < 40 { f.items[i].used = true; explode(f.items[i].x, 170, 90) }
    }
    /// Pieces flying off.
    func gore(_ z: Zed, _ dir: Double, all: Bool) {
        let skin = z.kind == .runner ? Col(0xb89a8a) : (z.kind == .bloater ? Col(0x9ac06a) : Col(0x9fb08c))
        let top = -150.0 * z.scale
        if gibs.count > 70 { gibs.removeFirst(20) }
        snd?.at(z.x - hero.x); snd?.squelch(); if all { snd?.crack() }; snd?.here()
        gibs.append(Gib(x: z.x, y: top, vx: dir * rnd(80, 420) + rnd(-120, 120), vy: -rnd(280, 620), rot: 0, vr: rnd(-14, 14), kind: 0, col: skin, t: 0))
        if all {
            for i in 0..<6 {
                gibs.append(Gib(x: z.x + rnd(-14, 14), y: -rnd(30, 130) * z.scale, vx: dir * rnd(60, 480) + rnd(-260, 260), vy: -rnd(160, 620), rot: rnd(0, 6), vr: rnd(-16, 16), kind: 1 + i % 3, col: i % 3 == 1 ? BLOOD : skin, t: 0))
            }
        }
        if parts.count < 520 {
            for _ in 0..<(all ? 4 : 2) { parts.append(Part(x: z.x + rnd(-20, 20), y: top + rnd(20, 100), vx: dir * rnd(20, 120) + rnd(-50, 50), vy: -rnd(10, 80), t: 0, life: rnd(0.5, 0.9), size: rnd(20, 36), col: Col(0x8a0e12, 0.42), grav: 40, glow: false)) }
            for _ in 0..<(all ? 26 : 12) { parts.append(Part(x: z.x, y: top + rnd(0, 90), vx: dir * rnd(40, 420) + rnd(-180, 180), vy: -rnd(60, 520), t: 0, life: rnd(0.5, 1.1), size: rnd(3, 8), col: BLOOD, grav: 1000, glow: false)) }
        }
    }
    func hit(_ z: Zed, _ dmg: Double, _ dir: Double, _ knock: Double) {
        if !z.alive { return }
        var dmg = dmg
        if z.kind == .riot && z.shield > 0 && dir == -z.face {
            if abs(knock) >= 450 { z.shield = 0 } else { z.shield -= 1; dmg *= 0.2 }
            if parts.count < 520 { for _ in 0..<8 { parts.append(Part(x: z.x + z.face * 34, y: -rnd(60, 140), vx: z.face * rnd(80, 420), vy: -rnd(60, 380), t: 0, life: rnd(0.15, 0.35), size: rnd(2, 4), col: Col(0xdff2ff), grav: 700, glow: true)) } }
            snd?.at(z.x - hero.x); snd?.clang(); if z.shield <= 0 { snd?.glass() }; snd?.here()
            if z.shield <= 0 { gibs.append(Gib(x: z.x + z.face * 34, y: -90, vx: z.face * rnd(120, 360), vy: -rnd(260, 480), rot: 0, vr: rnd(-12, 12), kind: 7, col: Col(0x9fb8c8), t: 0)); floaters.append(Floater(x: z.x, y: -200, text: "SHIELD BROKEN", col: Col(0xbfe8ff), t: 0, size: 16)) }
        }
        z.hp -= dmg
        z.flash = 1
        if pows.count < 24 { pows.append((z.x - dir * 8, (z.kind == .crow ? z.y : -96 * z.scale) + rnd(-26, 26), 0, min(46, 16 + dmg * 0.5))) }
        z.aware = true
        let heavy = z.kind == .bloater || z.kind == .boss
        z.kvx = dir * knock * (heavy ? 0.25 : 1)
        // a light tap no longer stops them cold: only a hard hit, or luck, breaks an attack
        let hard = abs(knock) >= 240
        z.stun = max(z.stun, heavy ? 0.06 : (z.kind == .wheel || z.kind == .riot ? 0.08 : (hard ? 0.22 : 0.0)))
        if z.atkT >= 0 && !heavy && (hard || chance(0.18)) { z.atkT = -1; z.cd = 0.3 }
        hits += 1; hitsT = 1.6
        var top = -110.0 * z.scale
        if z.kind == .rat { top = -14 } else if z.kind == .dog { top = -50 } else if z.kind == .crawler { top = -34 } else if z.kind == .crow { top = z.y }
        if floaters.count < 14 && dmg >= 3 { floaters.append(Floater(x: z.x + rnd(-12, 12), y: top - 30, text: "-\(Int(dmg.rounded()))", col: Col(0xff8a7a), t: 0, size: dmg > 40 ? 22 : 15)) }
        let nb = z.kind == .rat ? 3 : 11
        if parts.count < 300 {
            for _ in 0..<nb { parts.append(Part(x: z.x, y: top + rnd(0, 40), vx: dir * rnd(40, 320) + rnd(-80, 80), vy: -rnd(40, 320), t: 0, life: rnd(0.4, 0.9), size: rnd(3, 7), col: BLOOD, grav: 900, glow: false)) }
        }
        if parts.count < 520 && knock > 100 {
            for _ in 0..<5 { parts.append(Part(x: z.x - dir * 10, y: top + rnd(10, 50), vx: -dir * rnd(60, 380) + rnd(-140, 140), vy: -rnd(60, 380), t: 0, life: rnd(0.12, 0.3), size: rnd(2, 3.5), col: Col(0xfff6d0), grav: 600, glow: true)) }
        }
        if z.kind != .rat && chance(0.5) {
            floor.splats.append((z.x + dir * rnd(10, 70), rnd(60, 210), rnd(10, 26)))
            if floor.splats.count > 46 { floor.splats.removeFirst() }
        }
        if z.hp <= 0 { kill(z, dir, abs(knock) >= 450) }
    }
    func kill(_ z: Zed, _ dir: Double, _ heavy: Bool) {
        if !z.alive { return }
        z.alive = false
        z.deadT = 0
        z.face = dir != 0 ? -dir : z.face
        kills += 1
        streak = streakT > 0 ? streak + 1 : 1
        streakT = 1.2
        if streak == 5 || streak == 10 || streak == 20 {
            floaters.append(Floater(x: hero.x, y: -250, text: streak == 5 ? "MULTI KILL" : (streak == 10 ? "OVERKILL" : "MASSACRE"), col: GOLD, t: -0.6, size: 30))
            addMeter(10)
            snd?.streak(streak)
        }
        var gain = 4.0
        switch z.kind {
        case .rat: gain = 1
        case .crow: gain = 2
        case .boss: gain = 60
        case .bloater, .riot, .wheel, .screamer, .burner, .spitter: gain = 7
        default: gain = 4
        }
        energy += gain * (streak >= 5 ? 1.5 : 1)
        if energy >= energyNeed { energy -= energyNeed; picksTaken += 1; picksDue += 1 }
        addMeter(z.kind == .rat ? 3 : 12)
        if z.kind != .rat { floor.pools.append((z.x, rnd(30, 56))) }
        if floor.pools.count > 30 { floor.pools.removeFirst() }
        let humanoid = z.kind == .zed || z.kind == .runner || z.kind == .spitter || z.kind == .crawler || z.kind == .riot || z.kind == .screamer || z.kind == .wheel
        if z.kind == .wheel { gibs.append(Gib(x: z.x, y: -40, vx: dir * rnd(160, 420), vy: -rnd(200, 420), rot: 0, vr: rnd(-9, 9), kind: 8, col: Col(0x8a929c), t: 0)); gibs.append(Gib(x: z.x, y: -30, vx: dir * rnd(60, 300) + rnd(-80, 80), vy: -rnd(260, 520), rot: 0, vr: rnd(8, 20), kind: 9, col: Col(0x2a2a2a), t: 0)) }
        if z.kind == .burner { z.gibbed = true; gore(z, dir, all: true); explode(z.x, 120, 34) }
        if humanoid {
            if heavy && chance(0.6) { z.gibbed = true; gore(z, dir, all: true); floor.pools.append((z.x, rnd(50, 80))) } else if chance(0.4) { z.headless = true; gore(z, dir, all: false) }
        } else if z.kind == .crow || z.kind == .dog || z.kind == .rat {
            if heavy || z.kind == .crow { z.gibbed = true; for _ in 0..<5 { gibs.append(Gib(x: z.x, y: z.kind == .crow ? z.y : -30, vx: dir * rnd(40, 380) + rnd(-200, 200), vy: -rnd(120, 480), rot: rnd(0, 6), vr: rnd(-16, 16), kind: z.kind == .crow ? 5 : 2, col: z.kind == .crow ? Col(0x15151a) : BLOOD, t: 0)) } }
        }
        if z.kind == .bloater {
            z.gibbed = true
            gore(z, dir, all: true)
            explode(z.x, 150, 45, toxic: true)
            if abs(hero.x - z.x) < 110 { hurtHero(14, z.x, quiet: false) }
        }
        if z.kind == .boss {
            floor.items.append(Item(x: z.x, kind: 2))
            explode(z.x, 260, 0)
            gore(z, dir, all: true)
            shake = 26; flash = 0.8; flashCol = MINT
            say("MARR IS DOWN. TAKE THE SAMPLE.", 5)
            snd?.roar()
            buzz(3)
        }
    }
    func hurtHero(_ dmg: Double, _ fromX: Double, quiet: Bool) {
        let h = hero
        if supT >= 0 || mode != .play { return }
        if !quiet && h.inv > 0 { return }
        h.hp -= dmg * (1 - 0.15 * Double(lv("armor")))
        dmgTaken += dmg * (1 - 0.15 * Double(lv("armor")))
        if !quiet {
            h.inv = 0.25
            h.hurtT = 0.25
            shake = max(shake, 8)
            flash = 0.25; flashCol = BLOOD
            snd?.bite(); buzz(2)
            for _ in 0..<6 { parts.append(Part(x: h.x, y: -rnd(70, 130), vx: sgn(h.x - fromX) * rnd(40, 200), vy: -rnd(40, 200), t: 0, life: 0.5, size: 4, col: BLOOD, grav: 900, glow: false)) }
        }
    }

    // ---------- explosions and bursts
    func puff(_ x: Double, _ y: Double, _ n: Int, _ c: Col) {
        for _ in 0..<n { parts.append(Part(x: x + rnd(-20, 20), y: y - rnd(0, 30), vx: rnd(-160, 160), vy: -rnd(20, 180), t: 0, life: rnd(0.4, 0.9), size: rnd(5, 11), col: c, grav: 200, glow: false)) }
    }
    func explode(_ x: Double, _ r: Double, _ dmg: Double, toxic: Bool = false) {
        booms.append(Boom(x: x, y: -40, r: r, t: 0, life: 0.5))
        // smaller blasts a beat later, around the first
        for i in 0..<3 { booms.append(Boom(x: x + rnd(-r, r) * 0.6, y: -rnd(20, 150), r: r * rnd(0.35, 0.6), t: -0.06 - Double(i) * 0.07, life: 0.4)) }
        rings.append(Ring(x: x, y: -40, r: r * 1.3, t: 0, life: 0.35, col: toxic ? Col(0x8cff7a) : Col(0xffd9a0)))
        rings.append(Ring(x: x, y: -40, r: r * 2.0, t: 0, life: 0.55, col: WHITE.alpha(0.5)))
        shake = max(shake, 16)
        zoom = max(zoom, 1.05)
        flash = max(flash, 0.18); flashCol = toxic ? Col(0xb8ff9a) : Col(0xffe2b0)
        snd?.at(x - hero.x); snd?.boom(); snd?.here(); buzz(3)
        let hot: Col = toxic ? Col(0x8cff7a) : Col(0xffb040)
        if parts.count < 520 {
            // fire, fast sparks, falling embers, rolling smoke
            for _ in 0..<16 { parts.append(Part(x: x, y: -30, vx: rnd(-420, 420), vy: -rnd(80, 520), t: 0, life: rnd(0.4, 0.9), size: rnd(5, 11), col: hot, grav: 700, glow: true)) }
            for _ in 0..<22 { let a = rnd(0, PI * 2), sp = rnd(300, 900); parts.append(Part(x: x, y: -50, vx: cos(a) * sp, vy: sin(a) * sp - 200, t: 0, life: rnd(0.25, 0.6), size: rnd(2, 4), col: Col(0xfff2b0), grav: 900, glow: true)) }
            for _ in 0..<10 { parts.append(Part(x: x + rnd(-r, r) * 0.7, y: -rnd(120, 260), vx: rnd(-60, 60), vy: -rnd(20, 120), t: 0, life: rnd(1.0, 1.8), size: rnd(3, 5), col: Col(0xff8a30), grav: 260, glow: true)) }
            for _ in 0..<9 { parts.append(Part(x: x + rnd(-r, r) * 0.5, y: -rnd(10, 120), vx: rnd(-70, 70), vy: -rnd(40, 150), t: 0, life: rnd(0.9, 1.7), size: rnd(18, 34), col: toxic ? Col(0x3a5a30, 0.5) : Col(0x26221f, 0.55), grav: -50, glow: false)) }
        }
        if gibs.count < 90 {
            for _ in 0..<7 { gibs.append(Gib(x: x + rnd(-20, 20), y: -rnd(10, 80), vx: rnd(-520, 520), vy: -rnd(200, 700), rot: rnd(0, 6), vr: rnd(-18, 18), kind: 4, col: toxic ? Col(0x4a5a30) : (chance(0.5) ? Col(0x3a3a3a) : Col(0x7a1c18)), t: 0)) }
        }
        fires.append((x, toxic ? -1.6 : 2.6, r * 0.5))
        if !toxic { snd?.fireWhoosh() }
        if fires.count > 8 { fires.removeFirst() }
        if dmg <= 0 { return }
        for z in floor.zeds where z.alive {
            let d = abs(z.x - x)
            if d < r { hit(z, dmg * (1 - 0.5 * d / r), z.x >= x ? 1 : -1, 520) }
        }
        let f = floor
        for i in 0..<f.items.count where f.items[i].kind == 1 && !f.items[i].used && abs(f.items[i].x - x) < r {
            f.items[i].used = true
            let bx = f.items[i].x
            nades.append(Nade(x0: bx, x1: bx, t: 0, dur: 0.18, r: 170, dmg: 90))
        }
    }
    /// A body bursting: the same reach as a blast, but blood, ropes of gut and wet chunks in place of fire.
    func splatter(_ x: Double, _ r: Double, _ dmg: Double, _ dir: Double) {
        rings.append(Ring(x: x, y: -60, r: r * 0.9, t: 0, life: 0.3, col: Col(0xc01820)))
        shake = max(shake, 9)
        snd?.at(x - hero.x); snd?.squelch(); snd?.crack(); snd?.here(); buzz(2)
        if gibs.count > 90 { gibs.removeFirst(24) }
        for i in 0..<6 { gibs.append(Gib(x: x + rnd(-16, 16), y: -rnd(50, 110), vx: dir * rnd(40, 380) + rnd(-300, 300), vy: -rnd(260, 720), rot: rnd(0, 6), vr: rnd(-10, 10), kind: 10, col: i % 2 == 0 ? Col(0xc8566a) : Col(0xa83a4e), t: 0)) }
        for _ in 0..<7 { gibs.append(Gib(x: x + rnd(-20, 20), y: -rnd(30, 120), vx: dir * rnd(40, 300) + rnd(-380, 380), vy: -rnd(200, 760), rot: rnd(0, 6), vr: rnd(-16, 16), kind: 2, col: BLOOD, t: 0)) }
        for _ in 0..<3 { gibs.append(Gib(x: x, y: -rnd(60, 120), vx: rnd(-320, 320), vy: -rnd(300, 640), rot: rnd(0, 6), vr: rnd(-14, 14), kind: 1, col: Col(0xd8d0bc), t: 0)) }
        if parts.count < 560 {
            for _ in 0..<46 { let a = rnd(0, PI * 2), sp = rnd(120, 640); parts.append(Part(x: x, y: -rnd(50, 110), vx: cos(a) * sp + dir * 80, vy: sin(a) * sp - 220, t: 0, life: rnd(0.5, 1.2), size: rnd(3, 9), col: chance(0.3) ? Col(0x7a0c12) : BLOOD, grav: 1300, glow: false)) }
            for _ in 0..<6 { parts.append(Part(x: x + rnd(-30, 30), y: -rnd(40, 130), vx: rnd(-50, 50), vy: -rnd(10, 70), t: 0, life: rnd(0.5, 0.9), size: rnd(16, 30), col: Col(0xa01018, 0.4), grav: 60, glow: false)) }
        }
        for _ in 0..<4 { floor.splats.append((x + rnd(-r, r) * 0.7, rnd(70, 240), rnd(14, 34))) }
        if floor.splats.count > 60 { floor.splats.removeFirst(floor.splats.count - 60) }
        floor.pools.append((x, rnd(50, 80))); floor.pools.append((x + rnd(-90, 90), rnd(24, 44)))
        if floor.pools.count > 30 { floor.pools.removeFirst(floor.pools.count - 30) }
        if dmg <= 0 { return }
        for z in floor.zeds where z.alive {
            let d = abs(z.x - x)
            if d < r { hit(z, dmg * (1 - 0.5 * d / r), z.x >= x ? 1 : -1, 420) }
        }
    }
    func burst(_ x: Double, _ r: Double, _ dmg: Double, _ col: Col) {
        rings.append(Ring(x: x, y: -80, r: r, t: 0, life: 0.4, col: col))
        rings.append(Ring(x: x, y: -80, r: r * 1.5, t: 0, life: 0.6, col: WHITE.alpha(0.5)))
        if parts.count < 520 {
            for _ in 0..<26 { let a = rnd(0, PI * 2), sp = rnd(250, 800); parts.append(Part(x: x, y: -80, vx: cos(a) * sp, vy: sin(a) * sp * 0.6 - 120, t: 0, life: rnd(0.25, 0.6), size: rnd(2, 5), col: col, grav: 500, glow: true)) }
            for _ in 0..<6 { parts.append(Part(x: x + rnd(-r, r) * 0.5, y: 0, vx: rnd(-90, 90), vy: -rnd(30, 120), t: 0, life: rnd(0.6, 1.1), size: rnd(16, 28), col: Col(0x8a8478, 0.4), grav: -30, glow: false)) }
        }
        shake = max(shake, 16)
        for z in floor.zeds where z.alive && abs(z.x - x) < r { hit(z, dmg, z.x >= x ? 1 : -1, 560) }
        let f = floor
        for i in 0..<f.items.count where f.items[i].kind == 1 && !f.items[i].used && abs(f.items[i].x - x) < r {
            f.items[i].used = true
            explode(f.items[i].x, 170, 90)
        }
        snd?.blast(); buzz(3)
    }

    // ---------- power moves: sixteen names a hero, five kinds of move
    func startSuper() {
        meter = 0
        let deck = tw.deck
        supName = deck[supI % deck.count]
        supType = (supI * 3 + tower) % 5
        supI += 1
        supT = 0
        supStep = 0
        supHit = []
        supX0 = hero.x
        supDur = [0.42, 0.75, 0.55, 0.85, 0.8][supType]
        nameT = 1.5
        hero.atkT = -1
        if let z = nearest(600) { hero.face = z.x >= hero.x ? 1 : -1 }
        flash = 0.35; flashCol = tw.hue
        zoom = 1.1
        hitStop = 0.09
        shake = 10
        snd?.power(); buzz(3)
    }
    private func updateSuper(_ dt: Double) {
        let h = hero
        let f = floor
        let P = 58 * dmgMul * (1 + Double(depth) * 0.008)
        let prev = supT
        supT += dt
        let u = supT / supDur
        switch supType {
        case 0:      // a dash straight through them
            let nx = clampD(supX0 + h.face * 480 * easeOut(u * 1.25), 70, FLOOR_W - 70)
            let a = min(h.x, nx) - 50, b = max(h.x, nx) + 50
            for z in f.zeds where z.alive && z.x > a && z.x < b && !supHit.contains(z.id) {
                supHit.insert(z.id)
                hit(z, P * 1.1, h.face, 520)
            }
            if chance(dt * 60) { slashes.append(Slash(x: h.x, y: -90, face: h.face, t: 0, big: 1.5, col: tw.hue)) }
            h.x = nx
        case 1:      // spin: two rings
            if supStep == 0 && u > 0.25 { supStep = 1; burst(h.x, 250, P * 0.8, tw.hue) }
            if supStep == 1 && u > 0.65 { supStep = 2; burst(h.x, 320, P * 0.9, WHITE) }
        case 2:      // a shockwave along the floor, both ways
            if supStep == 0 && u > 0.3 {
                supStep = 1
                waves.append(Wave(x: h.x, dir: 1, left: 700, dmg: P * 1.0, hit: []))
                waves.append(Wave(x: h.x, dir: -1, left: 700, dmg: P * 1.0, hit: []))
                shake = 20
                snd?.boom()
            }
        case 3:      // drag them in, then blow them away
            if u < 0.55 {
                for z in f.zeds where z.alive && abs(z.x - h.x) < 560 && abs(z.x - h.x) > 44 {
                    z.x += sgn(h.x - z.x) * 640 * dt
                    z.stun = 0.2
                }
            } else if supStep == 0 { supStep = 1; burst(h.x, 240, P * 1.5, tw.hue) }
        default:     // a flurry
            let a = Int(prev / 0.08), b = Int(supT / 0.08)
            if b != a {
                for z in f.zeds where z.alive {
                    let dx = (z.x - h.x) * h.face
                    if dx > -30 && dx < 220 { hit(z, P * 0.24, h.face, 60) }
                }
                slashes.append(Slash(x: h.x + h.face * rnd(0, 60), y: -rnd(50, 130), face: h.face, t: 0, big: rnd(0.8, 1.4), col: b % 2 == 0 ? tw.hue : WHITE))
                snd?.swing()
            }
            if supStep == 0 && u > 0.9 { supStep = 1; burst(h.x + h.face * 80, 200, P * 0.8, tw.hue) }
        }
        if supT >= supDur { supT = -1; h.inv = 0.4 }
    }

    // ---------- the automatic weapons
    private func gunHit(_ z: Zed, _ dmg: Double, _ col: Col, _ w: Double, fromY: Double = -96, fromX: Double? = nil) {
        var ty = -90.0 * z.scale
        if z.kind == .rat { ty = -10 } else if z.kind == .dog { ty = -40 } else if z.kind == .crawler { ty = -30 } else if z.kind == .crow { ty = z.y }
        tracers.append(Tracer(x0: fromX ?? (hero.x + hero.face * 30), y0: fromY, x1: z.x, y1: ty, t: 0, life: 0.07, col: col, w: w, bolt: false))
        hit(z, dmg, z.x >= hero.x ? 1 : -1, 40)
    }
    private func casing() {
        muzzle = 1
        if gibs.count < 110 { gibs.append(Gib(x: hero.x - hero.face * 6, y: -100, vx: -hero.face * rnd(60, 200), vy: -rnd(160, 320), rot: rnd(0, 6), vr: rnd(-20, 20), kind: 6, col: Col(0xd9b04a), t: 3.5)) }
    }
    private func updateArsenal(_ dt: Double) {
        let h = hero
        let f = floor
        let scale = (1 + Double(depth) * 0.008) * 0.8
        if gunT > 0 { gunT -= dt }
        if kickT > 0 { kickT -= dt }
        if h.atkT >= 0 || supT >= 0 {
            held = 0; swapT = -1                     // a swing is always the melee weapon
        } else if swapT >= 0 {
            swapT += dt / 0.24
            if swapT >= 0.5 { held = swapTo }
            if swapT >= 1 { swapT = -1 }
        } else {
            let want = gunT > 0 ? gunKind : 0
            if want != held { swapT = 0; swapTo = want }
        }
        var l = lv("smg")
        if l > 0 {
            cdSmg -= dt
            if cdSmg <= 0, let z = nearest(560, facing: true), ready(1) { cdSmg = 0.17; raise(1, 0.3); gunHit(z, (4 + 3 * Double(l)) * scale, Col(0xffe6a0), 2); snd?.shot(); casing() }
        }
        l = lv("minigun")
        if l > 0 {
            cdMini -= dt
            if cdMini <= 0, let z = nearest(760, facing: true), ready(3) { cdMini = 0.055; raise(3, 0.3); gunHit(z, (4 + 2 * Double(l)) * scale, Col(0xffc060), 2.5, fromY: -84); casing(); if chance(0.3) { snd?.shot() } }
        }
        l = lv("shotgun")
        if l > 0 {
            cdShot -= dt
            if cdShot <= 0, let z0 = nearest(250), ready(2, exact: true) {
                kickT = 0.15
                cdShot = 1.5 - 0.2 * Double(l)
                let dir = z0.x >= h.x ? 1.0 : -1.0
                if h.atkT < 0 && supT < 0 { h.face = dir }
                raise(2, 0.6)
                for z in f.zeds where z.alive {
                    let dx = (z.x - h.x) * dir
                    if dx > 0 && dx < 270 { hit(z, (22 + 10 * Double(l)) * scale, dir, 420) }
                }
                for i in 0..<5 { tracers.append(Tracer(x0: h.x + dir * 30, y0: -96, x1: h.x + dir * 270, y1: -150 + Double(i) * 28, t: 0, life: 0.09, col: Col(0xfff0c0), w: 3, bolt: false)) }
                shake = max(shake, 6)
                snd?.blast(); buzz(1)
            }
        }
        l = lv("nade")
        if l > 0 {
            cdNade -= dt
            if cdNade <= 0, let z = nearest(640) {
                cdNade = 3.2 - 0.5 * Double(l)
                nades.append(Nade(x0: h.x, x1: z.x, t: 0, dur: 0.55, r: 130 + 15 * Double(l), dmg: (50 + 20 * Double(l)) * scale))
            }
        }
        l = lv("flame")
        flameOn = false
        if l > 0, nearest(240, facing: true) != nil, ready(4) {
            flameOn = true
            raise(4, 0.25)
            for z in f.zeds where z.alive {
                let dx = (z.x - h.x) * h.face
                if dx > 0 && dx < 240 { z.burn = max(z.burn, 2.5); z.burnDps = max(z.burnDps, 14 * Double(l) * scale); z.aware = true }
            }
            if parts.count < 300 {
                for _ in 0..<2 { parts.append(Part(x: h.x + h.face * 40, y: -92, vx: h.face * rnd(260, 520), vy: rnd(-90, 60), t: 0, life: rnd(0.25, 0.45), size: rnd(7, 14), col: Col(0xff9a30), grav: -120, glow: true)) }
            }
        }
        l = lv("drone")
        if l > 0 {
            droneA += dt * 2.2
            cdDrone -= dt
            if cdDrone <= 0, let z = nearest(430) {
                cdDrone = 0.9 / Double(l)
                gunHit(z, 18 * scale, Col(0x7dd3ff), 2.5, fromY: -190 + sin(droneA * 2) * 8, fromX: h.x + cos(droneA) * 70)
                snd?.shot()
            }
        }
        l = lv("tesla")
        if l > 0 {
            cdTesla -= dt
            if cdTesla <= 0, let z0 = nearest(460) {
                cdTesla = 1.2
                var px = h.x, py = -100.0
                var cur: Zed? = z0
                var used = Set<Int>()
                var n = 0
                while let z = cur, n < 3 + l {
                    used.insert(z.id)
                    tracers.append(Tracer(x0: px, y0: py, x1: z.x, y1: -80 * z.scale, t: 0, life: 0.18, col: Col(0xa8e8ff), w: 3.5, bolt: true))
                    hit(z, (30 + 10 * Double(l)) * scale, 0, 0)
                    z.stun = 0.5
                    px = z.x; py = -80 * z.scale
                    n += 1
                    var best: Zed? = nil
                    var bd = 300.0
                    for q in f.zeds where q.alive && !used.contains(q.id) {
                        let d = abs(q.x - px)
                        if d < bd { bd = d; best = q }
                    }
                    cur = best
                }
                snd?.zap()
            }
        }
        l = lv("orbital")
        if l > 0 {
            cdOrb -= dt
            if cdOrb <= 0 && aliveCount >= 2 {
                cdOrb = 7 - Double(l)
                var bx = h.x, bn = 0
                for z in f.zeds where z.alive {
                    var c = 0
                    for q in f.zeds where q.alive && abs(q.x - z.x) < 150 { c += 1 }
                    if c > bn { bn = c; bx = z.x }
                }
                beams.append(Beam(x: bx, t: 0, done: false, r: 160, dmg: 200 * scale))
            }
        }
    }

    // ---------- effects
    func updateFx(_ dt: Double) {
        for i in 0..<parts.count {
            parts[i].t += dt
            parts[i].vy += parts[i].grav * dt
            parts[i].x += parts[i].vx * dt
            parts[i].y += parts[i].vy * dt
            if parts[i].y > 0 && parts[i].grav > 0 { parts[i].y = 0; parts[i].vx *= 0.5; parts[i].vy = 0 }
        }
        parts.removeAll { $0.t > $0.life }
        for i in 0..<floaters.count { floaters[i].t += dt; floaters[i].y -= 50 * dt }
        floaters.removeAll { $0.t > 0.8 }
        for i in 0..<rings.count { rings[i].t += dt }
        rings.removeAll { $0.t > $0.life }
        for i in 0..<tracers.count { tracers[i].t += dt }
        tracers.removeAll { $0.t > $0.life }
        for i in 0..<booms.count { booms[i].t += dt }
        booms.removeAll { $0.t > $0.life }
        for i in 0..<slashes.count { slashes[i].t += dt }
        if streakT > 0 { streakT -= dt }
        for i in 0..<pows.count { pows[i].2 += dt }
        pows.removeAll { $0.2 > 0.14 }
        for i in 0..<fires.count {
            fires[i].1 -= dt * (fires[i].1 < 0 ? -1 : 1)
            if fires[i].1 > 0 { for z in floor.zeds where z.alive && abs(z.x - fires[i].0) < fires[i].2 { z.burn = max(z.burn, 1.2); z.burnDps = max(z.burnDps, 16) } }
        }
        fires.removeAll { abs($0.1) < 0.05 }
        for i in 0..<gibs.count {
            gibs[i].t += dt
            gibs[i].vy += 1100 * dt
            gibs[i].x += gibs[i].vx * dt
            gibs[i].y += gibs[i].vy * dt
            gibs[i].rot += gibs[i].vr * dt
            if gibs[i].y > 0 {
                gibs[i].y = 0
                if abs(gibs[i].vy) > 160 { gibs[i].vy *= -0.4; gibs[i].vx *= 0.6; gibs[i].vr *= 0.6 } else { gibs[i].vy = 0; gibs[i].vx *= 0.8; gibs[i].vr = 0 }
            }
        }
        gibs.removeAll { $0.t > 6 }
        slashes.removeAll { $0.t > 0.18 }
        var blown: [Nade] = []
        for i in 0..<nades.count { nades[i].t += dt; if nades[i].t >= nades[i].dur { blown.append(nades[i]) } }
        nades.removeAll { $0.t >= $0.dur }
        for n in blown { explode(n.x1, n.r, n.dmg) }
        for i in 0..<waves.count {
            let step = 950 * dt
            waves[i].x += waves[i].dir * step
            waves[i].left -= step
            for z in floor.zeds where z.alive && abs(z.x - waves[i].x) < 46 && !waves[i].hit.contains(z.id) {
                waves[i].hit.insert(z.id)
                hit(z, waves[i].dmg, waves[i].dir, 520)
            }
            if chance(dt * 50) { parts.append(Part(x: waves[i].x, y: 0, vx: rnd(-60, 60), vy: -rnd(120, 360), t: 0, life: 0.4, size: rnd(5, 9), col: Col(0xd9d0bc), grav: 600, glow: false)) }
        }
        waves.removeAll { $0.left <= 0 || $0.x < 40 || $0.x > FLOOR_W - 40 }
        for i in 0..<beams.count {
            beams[i].t += dt
            if !beams[i].done && beams[i].t > 0.55 {
                beams[i].done = true
                explode(beams[i].x, beams[i].r, beams[i].dmg)
                flash = 0.3; flashCol = Col(0xbfe8ff)
                shake = 22
            }
        }
        beams.removeAll { $0.t > 1.0 }
    }

    // ---------- doors, holes, lifts, things on the floor
    private func interact() {
        let f = floor
        let h = hero
        for i in 0..<f.items.count where !f.items[i].used {
            let it = f.items[i]
            if abs(it.x - h.x) > 34 { continue }
            if it.kind == 0 && h.hp < h.maxHp - 1 {
                f.items[i].used = true
                h.hp = min(h.maxHp, h.hp + 25)
                floaters.append(Floater(x: h.x, y: -170, text: "+25", col: MINT, t: 0, size: 20))
                snd?.heal(); buzz(1)
            } else if it.kind == 2 {
                f.items[i].used = true
                hasSample = true
                say("YOU HAVE THE SAMPLE. KEEP GOING DOWN.", 4)
                snd?.pick(); buzz(2); save()
            } else if it.kind == 3 {
                f.items[i].used = true
                valveShut = true
                say("THE WATER IS OFF. NOW THE STREET.", 4)
                rings.append(Ring(x: it.x, y: -80, r: 260, t: 0, life: 0.6, col: MINT))
                snd?.pick(); buzz(2); save()
            }
        }
        if supT >= 0 { return }
        if f.kind == .wall {
            let pairs: [(Double, Double, Double)] = [(f.doorA, f.doorB, 1), (f.doorB, f.doorA, -1)]
            for (from, to, sd) in pairs where abs(h.x - from) < 30 && (h.x - f.wallX) * sd < 0 && input.move * sd > 0 {
                puff(h.x, 0, 8, Col(0x8a8478))
                h.x = to + sd * 64
                h.face = sd
                f.wallSide = sd
                shake = max(shake, 9)
                flash = 0.15; flashCol = MINT
                puff(h.x, 0, 10, Col(0x8a8478))
                floaters.append(Floater(x: h.x, y: -210, text: "THROUGH THE \(sideName)", col: MINT, t: 0, size: 18))
                snd?.door(); buzz(2)
                return
            }
        }
        if f.kind == .hole {
            if abs(h.x - f.holeX) < 34 { startRide(.hole, to: descTarget(f.n, 2)); return }
            if abs(h.x - f.exitX) < 60 && sayCd <= 0 { sayCd = 3; say(f.fireStairs ? "THE STAIRS ARE BURNING. USE THE HOLE." : "THE STAIRS ARE GONE. USE THE HOLE.") }
            return
        }
        if f.kind == .rope {
            if abs(h.x - f.exitX) < 44 { startRide(.rope, to: descTarget(f.n, 2)) }
            return
        }
        if f.kind == .lift {
            if abs(h.x - f.liftX) < 40 {
                if threatCount == 0 { startRide(f.shaft ? .shaft : .lift, to: descTarget(f.n, 3)) } else if sayCd <= 0 { sayCd = 2.5; say("CLEAR THE FLOOR FIRST.  \(threatCount) LEFT") }
            } else if abs(h.x - f.exitX) < 60 && sayCd <= 0 { sayCd = 3; say("STAIRS BLOCKED. TAKE THE ELEVATOR.") }
            return
        }
        if abs(h.x - f.exitX) < 38 {
            if tower == 0 && f.n == 32 && !hasSample {
                if sayCd <= 0 { sayCd = 3; say(aliveBoss ? "MARR FIRST." : "TAKE THE SAMPLE FIRST.") }
                return
            }
            if tower == 0 && f.n == 12 && !valveShut {
                if sayCd <= 0 { sayCd = 3; say("SHUT THE WATER MAIN FIRST.") }
                return
            }
            if f.kind == .street { towerDone(); return }
            startRide(f.escape ? .ladder : .stairs, to: f.n - 1)
        }
    }
    var aliveBoss: Bool { return floor.zeds.contains(where: { $0.alive && $0.kind == .boss }) }

    func towerDone() {
        snd?.win(); buzz(3)
        if tower < 2 { startTower(tower + 1) } else {
            let d = UserDefaults.standard
            d.removeObject(forKey: "fz.floor")
            endT = 0
            mode = .ending
        }
    }

    // ---------- a simple player for screenshots and the balance run
    var botStuck = 0.0
    var dmgTaken = 0.0
    var sloppy = false
    var groanCd = 2.0
    var heartCd = 0.0
    var musicLevel: Int {
        switch mode {
        case .play, .dead:
            if supT >= 0 || aliveBoss { return 3 }
            for z in floor.zeds where z.alive && z.aware && abs(z.x - hero.x) < 900 { return 2 }
            return 1
        case .ride, .card: return 1
        default: return 0
        }
    }
    private func bot() {
        let f = floor
        let h = hero
        var target = f.exitX
        if f.kind == .hole { target = f.holeX }
        if f.kind == .lift { target = threatCount == 0 ? f.liftX : (nearestAny()?.x ?? f.liftX) }
        if f.boss && aliveBoss { target = nearestAny()?.x ?? target }
        for it in f.items where !it.used && (it.kind == 2 || it.kind == 3) { target = it.x }
        for it in f.items where !it.used && it.kind == 0 && h.hp < h.maxHp * 0.6 && abs(it.x - h.x) < 500 { target = it.x }
        if f.kind == .wall && (h.x - f.wallX) * (target - f.wallX) < 0 { target = h.x < f.wallX ? f.doorA : f.doorB }
        var mv = sgn(target - h.x)
        input.attack = false
        var foe = nearest(120)
        if let z0 = foe, f.kind == .wall, (z0.x - f.wallX) * (h.x - f.wallX) < 0 { foe = nil }
        if let z = foe {
            h.face = z.x >= h.x ? 1 : -1
            input.attack = !sloppy || Int(t * 2.5) % 3 != 0
            if !sloppy && (z.kind == .bloater || aliveCountNear(160) > 3) { mv = -h.face } else { mv = 0 }
            if f.kind == .wall { mv = 0 }
        }
        if meter >= 100 && aliveCountNear(420) >= 2 && (!sloppy || Int(t) % 4 == 0) { input.power = true }
        if meter >= 100 && aliveBoss { input.power = true }
        input.move = mv
    }
    func nearestAny() -> Zed? { return nearest(4000) }
    func aliveCountNear(_ r: Double) -> Int { var n = 0; for z in floor.zeds where z.alive && abs(z.x - hero.x) < r { n += 1 }; return n }

    func demo(_ what: String) {
        clearSave()
        tower = 0
        hero = Hero()
        ups = [:]
        switch what {
        case "play": ups = ["smg": 2, "nade": 1, "drone": 1]; floorN = 70
        case "fire": ups = ["smg": 1, "flame": 1]; floorN = 78
        case "dogs": ups = ["shotgun": 2, "tesla": 1, "minigun": 1, "smg": 2]; floorN = 54
        case "boss": ups = ["smg": 1, "nade": 1, "armor": 2]; floorN = 32
        case "hole": floorN = 82
        case "types": ups = ["armor": 3]; floorN = 81
        case "safe": ups = ["smg": 1]; floorN = 73
        case "gun": ups = ["smg": 1, "armor": 3, "hp": 3]; floorN = 59
        case "street": ups = ["smg": 2, "shotgun": 2, "flame": 2, "tesla": 1]; floorN = 0
        case "lift": ups = ["smg": 1]; floorN = 75
        case "escape": ups = ["smg": 1, "nade": 1]; floorN = 74
        case "guns": ups = ["shotgun": 3, "dmg": 3]; floorN = 71
        case "bat": ups = ["dmg": 3]; floorN = 71
        case "ropeF": ups = ["smg": 1]; floorN = 80
        case "ropeR", "ladderR", "shaftR", "ropeK": floorN = 80
        case "resid": ups = ["smg": 1]; floorN = 50
        case "surgery": tower = 1; ups = ["smg": 1]; floorN = 31
        case "pent": tower = 2; ups = ["smg": 1]; floorN = 53
        case "ball": tower = 2; ups = ["smg": 1]; floorN = 13
        case "hosp": tower = 1; ups = ["smg": 1]; floorN = 44
        case "hotel": tower = 2; ups = ["smg": 1]; floorN = 33
        case "casino": tower = 2; ups = ["smg": 1, "flame": 1]; floorN = 6
        case "mall": ups = ["smg": 2, "shotgun": 1]; floorN = 16
        case "lab": ups = ["smg": 2, "tesla": 1]; floorN = 29
        case "lobby": ups = ["smg": 2, "minigun": 1]; floorN = 6
        case "pick": floorN = 78; picksDue = 1; ups = ["smg": 2, "nade": 1, "armor": 1]
        default: floorN = 84
        }
        hero.x = 420
        meter = 100
        floor = makeFloor(floorN, entry: hero.x)
        fixEntry()
        for z in floor.zeds { z.aware = true }
        announce()
        if what == "fire" { hero.x = floor.wallX - 330; meter = 40 }
        if what == "types" {
            floor.zeds = []; floor.reserve = 0; hero.x = 700; meter = 0
            let kinds: [ZKind] = [.wheel, .riot, .screamer, .burner, .crawler, .spitter, .zed, .zed, .crow]
            for (i, k) in kinds.enumerated() { let z = Zed(id: 9000 + i, kind: k, x: 860 + Double(i) * 105, depth: 2, seed: hashN(Double(i) * 1.37 + 0.2)); z.aware = true; z.face = -1; z.female = i % 2 == 1; z.job = [8, 4, 7, 7, 2, 7, 0, 3, 7][i]; z.speed = 4; floor.zeds.append(z) }
        }
        if what == "lift" { hero.x = floor.liftX - 260 }
        if what == "hole" { floorN = 82; hero.x = floor.holeX - (floor.exitRight ? 300 : -300); hero.face = floor.exitRight ? 1 : -1 }
        cpFloor = floorN; cpUps = ups
        if what == "safe" { hero.x = FLOOR_W / 2 - 320 }
        if what == "gun" { floor.gunT = 1.4; hero.x = 300 }
        if what == "ropeF" { hero.x = floor.exitX - (floor.exitRight ? 320 : -320); hero.face = floor.exitRight ? 1 : -1 }
        if what == "ropeR" || what == "ladderR" || what == "shaftR" || what == "ropeK" {
            startRide(what == "ladderR" ? .ladder : (what == "shaftR" ? .shaft : .rope), to: 78)
            rideFreeze = what == "ropeR" ? 1.5 : (what == "ropeK" ? 2.05 : 0.7)
            if what == "ropeK" { grabDone = true; grabWon = true; grabAt = 1.15 }
            return
        }
        if what == "pick" { rollPick(); mode = .pick; pickT = 0 } else { mode = .play; auto = ["play", "dogs", "boss", "gun", "escape", "hosp", "hotel", "casino", "mall", "lab", "lobby", "guns", "bat", "resid", "surgery", "pent", "ball", "fire", "hole", "lift", "street", "safe", "types"].contains(what) }
    }

    /// Plays all three towers with the bot, no drawing, and reports how it went.
    func botRun(_ simMinutes: Double) -> String {
        return botOne(simMinutes, false) + botOne(simMinutes, true)
    }
    private func botOne(_ simMinutes: Double, _ slop: Bool) -> String {
        var out = slop ? "sloppy bot (idles a third of the time, never backs off)\n" : "careful bot\n"
        clearSave()
        sloppy = slop
        auto = true
        tower = 0
        dmgTaken = 0
        startTower(0)
        var lastTower = 0
        var lastDeaths = 0
        var lastDmg = 0.0
        var t0 = 0.0
        var sim = 0.0
        let dt = 1.0 / 30
        var deathFloors: [Int] = []
        var seenDeaths = 0
        var stuckT = 0.0
        var lastFloor = floorN
        while sim < simMinutes * 60 && mode != .ending {
            let fl = floorN
            update(dt)
            sim += dt
            if mode == .card { cardT = 9 }
            if deaths > seenDeaths { seenDeaths = deaths; deathFloors.append(fl); stuckT = 0 }
            if floorN != lastFloor { lastFloor = floorN; stuckT = 0 } else { stuckT += dt }
            if stuckT > 150 {
                let f = floor
                out += "  STUCK floor \(floorN) kind \(f.kind) mode \(mode) heroX \(Int(hero.x)) hp \(Int(hero.hp)) exitX \(Int(f.exitX)) wallX \(Int(f.wallX)) doors \(Int(f.doorA)),\(Int(f.doorB)) holeX \(Int(f.holeX)) alive \(aliveCount) reserve \(f.reserve) atkT \(hero.atkT) supT \(supT) picksDue \(picksDue) move \(input.move) attack \(input.attack)\n"
                for z in f.zeds where z.alive { out += "    \(z.kind) x \(Int(z.x)) hp \(Int(z.hp)) aware \(z.aware) stun \(z.stun) atkT \(z.atkT) cd \(z.cd) shield \(z.shield)\n" }
                break
            }
            if tower != lastTower {
                out += "  \(TOWERS[lastTower].who): \(String(format: "%.1f", (sim - t0) / 60)) min, deaths \(deaths - lastDeaths), damage taken \(Int(dmgTaken - lastDmg))\n"
                lastTower = tower; lastDeaths = deaths; t0 = sim; lastDmg = dmgTaken
            }
        }
        if mode == .ending {
            out += "  \(TOWERS[lastTower].who): \(String(format: "%.1f", (sim - t0) / 60)) min, deaths \(deaths - lastDeaths), damage taken \(Int(dmgTaken - lastDmg))\n"
            out += "  FINISHED in \(String(format: "%.1f", sim / 60)) min, deaths \(deaths), kills \(kills), died on floors \(deathFloors.prefix(30))\n"
        } else {
            out += "  NOT finished: tower \(tower) floor \(floorN), deaths \(deaths), kills \(kills), damage \(Int(dmgTaken)), upgrades \(ups), died on floors \(deathFloors.prefix(40))\n"
        }
        auto = false
        sloppy = false
        clearSave()
        mode = .title
        return out
    }
}
