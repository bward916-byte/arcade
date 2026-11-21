import Foundation

// The simulation for the trial slice: town 1 only. Ported from dunefall/index.html
// (updPlayer, updCoins, updFolk, updRaiders, dawn, dusk), without towns 2-5, cutscenes,
// weather, the tomb, fishing, the shop upgrades and saving.

struct Target {
    enum Kind { case slot, tool, mend, bank, shop, merc }
    let k: Kind
    let b: Building?
    let shop: Shop?
}

final class Game {
    // screen, in game pixels
    var W = 400.0
    var H = 190.0
    var GY = 140.0
    var cam = 0.0
    var NOW = 0.0

    let DAY_LEN = 100.0
    let WORLD = 3200.0
    let NILE = 3106.0
    var WELL_X = 1655.0
    var TOWN: (Double, Double) = (1296, 1992)
    var QUARRY = 985.0
    var PAST: (Double, Double) = (2080, 2200)
    var OASIS = 2485.0
    var town = 0
    var day0 = 0
    var feat = Feat.pyramid
    /// built, recruits, raiders brought down, towns rebuilt
    var stats = [0, 0, 0, 0]
    var relics = Set<String>()
    var ended = false
    var ankh = false
    var poison = false
    var rocks: [Rock] = []
    var storm: Storm?
    var stormAt = -1.0
    var trip: Double?
    var scene: Cine?
    var sceneQueue: [Cine] = []
    var zoom = 1.0
    var fade = 0.0
    var rodN = [5, 8]
    var rodT = 0.0
    var rodSpot = -1
    var digN = 0
    var digToday = 0
    var digT = 0.0
    var carry = 0
    var cardSub = ""
    var introFires = false
    var picked = 0
    var hidePlayer = false
    var rain: Double?
    var rainAt = -1.0
    var lush = false
    var ecl: Double?
    var eclAt = -1.0
    var omen = false
    var fest = 0.0
    var festDone = false
    var festT = 0.0
    var ufo: Ufo?
    var ufoDone = false
    var ufoSeen = false
    var deepT = 0.0
    var trapCd = 0.0
    var devils: [Devil] = []
    func trapXs() -> [Double] {
        let tb = B(.tomb)
        if feat != .cliff || tb.gone || tb.level > 0 { return [] }
        return [tb.x + 90, tb.x + 130, tb.x + 170]
    }
    func trapUp(_ i: Int) -> Bool { return sin(NOW * 1.6 + Double(i) * 2.1) > 0.2 }
    var ln: Int { return day - day0 }
    var townName: String { return TOWNS[town % 5] }

    var state = GameState.title
    var t = 0.62
    var day = 1
    var dark = 0.0
    var nextId = 1
    var shake = 0.0
    var flash = 0.0
    var report = ""
    var input = Input()
    var snd: Sound?
    /// 0 a light tap, 1 a knock, 2 a heavy blow, 3 success
    var onBuzz: ((Int) -> Void)?
    var onDawn: (() -> Void)?
    var bank = 0
    var up = Set<String>()
    var shops: [Shop] = []
    var caravan: Caravan?
    var carAt = -1.0
    var crowd: [Stroller] = []
    var slow = 0.0

    var player = Player()
    var bs: [Building] = []
    var coins: [Coin] = []
    var folk: [Folk] = []
    var nomads: [Nomad] = []
    var raiders: [Raider] = []
    var herd: [Goat] = []
    var hares: [Hare] = []
    var urns: [Urn] = []
    var camps: [Camp] = []
    var parts: [Part] = []
    var arrows: [Arrow] = []
    var rings: [Ring] = []
    var stuck: [Stuck] = []
    var fallen: [Fallen] = []
    var prints: [Footprint] = []
    var raid: [RaidPlan] = []
    var nightN = 0
    var nightDown = 0
    var nightGates = 0
    var nightLost = 0
    var hadNight = false

    var seen = Set<String>()
    var hintText = ""
    var hintT = 0.0
    var cardText = ""
    var cardT = 0.0

    init() { reset() }

    func B(_ k: BType) -> Building { return bs[k.rawValue] }

    func reset(_ townIn: Int = 0, keep: Bool = false) {
        let cf = TCFG[townIn % 5]
        let ox = cf.ox
        town = townIn
        feat = cf.feat
        usePalette(cf.feat.rawValue)
        WELL_X = 1655 + ox; TOWN = (1296 + ox, 1992 + ox); QUARRY = cf.quarry; PAST = cf.past; OASIS = cf.oasis
        if !keep { stats = [0, 0, 0, 0]; relics = []; up = []; ended = false; seen = []; day = 1; day0 = 0; ufoDone = false; ufoSeen = false }
        state = .title
        t = 0.62; dark = 0; nextId = 1; shake = 0; flash = 0; report = ""
        player = Player()
        player.x = WELL_X - 22
        func at(_ k: BType) -> Double { return (cf.bx[k] ?? 1400) + ox }
        func site(_ k: BType) -> Building {
            let x = cf.sites[k]
            let b = Building(k, x ?? -9999)
            if x == nil || k == .btemple { b.gone = true }
            return b
        }
        bs = [Building(.market, at(.market)), Building(.tea, at(.tea)), Building(.guard, at(.guard)), Building(.pen, at(.pen)),
              Building(.well, 1640 + ox), Building(.temple, at(.temple)), Building(.gw, 1290 + ox), Building(.ge, 1978 + ox),
              Building(.bank, at(.bank)), Building(.dock, 3040), site(.sphinx), site(.tomb), site(.grove), site(.hermit), site(.btemple)]
        coins = []; folk = []; nomads = []; raiders = []; herd = []; parts = []; arrows = []
        rings = []; stuck = []; fallen = []; prints = []; raid = []
        hadNight = false
        hintText = ""; hintT = 0
        bank = 0; shops = [Shop(.guard), Shop(.pen)]; caravan = nil; carAt = -1; crowd = []; slow = 0
        ankh = false; poison = false; rocks = []; storm = nil; stormAt = -1; trip = nil; scene = nil; sceneQueue = []; zoom = 1; fade = 0
        rodN = [5, 8]; rodT = 0; rodSpot = -1; digN = 0; digToday = 0; digT = 0; carry = 0
        rain = nil; rainAt = -1; lush = false; ecl = nil; eclAt = -1; omen = false; fest = 0; festDone = false; ufo = nil; deepT = 0; trapCd = 0
        devils = [Devil(x: 520, dir: 1, a: 260, b: max(420, 1296 + ox - 130)), Devil(x: min(2900, 1992 + ox + 220), dir: -1, a: min(2700, 1992 + ox + 110), b: 2990)]
        camps = cf.camps.map { Camp(x: $0.0, cap: $0.1) }
        urns = cf.urns.map { Urn(x: $0.0, n: $0.1) }
        hares = (0..<5).map { newHare($0) }
        for i in 0..<camps.count { for _ in 0..<camps[i].cap { addNomad(i, fromEdge: false) } }
        player.ammo = maxAmmo
        player.x = startX()
        introFires = false; hidePlayer = false
        cam = clampD(player.x - W / 2, 0, WORLD - W)
    }

    /// Open ground near the well, well clear of anything that takes coins.
    func startX() -> Double {
        var best = WELL_X - 50, bestGap = -1.0
        var x = WELL_X - 110
        while x <= WELL_X + 110 {
            var gap = 999.0
            for b in bs where !b.gone { gap = min(gap, x < b.x ? b.x - x : (x > b.x + b.w ? x - b.x - b.w : 0)) }
            for sh in shops { gap = min(gap, abs(x - shopX(sh.k))) }
            if gap > bestGap { bestGap = gap; best = x }
            x += 4
        }
        return best
    }

    func card(_ a: String, _ b: String) { cardText = a; cardSub = b; cardT = 3.6 }

    func start(intro: Bool = true) {
        reset()
        state = .play
        t = 0.08
        if intro {
            // The fall of the town, told in three shots: the storm and the riders, the fires, and the one who comes back.
            sceneQueue = [Cine(k: "intro2", text: "They burned what the sand did not bury. The bazaar went dark, and stayed dark.", dur: 5, fx: WELL_X + 70, zoom: 1.18),
                          Cine(k: "intro3", text: "Years later, one rider comes back: eight coins, and a long memory.", dur: 5.2, fx: startX() - 250, zoom: 1.3)]
            scene = Cine(k: "intro1", text: "First the river left. Then the storm came, and the riders came with it.", dur: 5, fx: 520, zoom: 1.12)
            t = 0.645
            cam = 40
            hidePlayer = true
            storm = Storm(front: 150)
            for i in 0..<5 {
                let r = Raider(id: 800 + i, kind: i == 2 ? .boss : .rider, x: 300 - Double(i) * 46, side: 1, hp: 3)
                r.state = .flee
                raiders.append(r)
            }
            snd?.horn()
            buzz(2)
        } else {
            card("DUNEFALL", "Bring the town back")
            hint("start")
        }
    }

    // ---------- cutscenes: the camera goes to look at something, with a caption
    func showScene(_ k: String, _ text: String, _ dur: Double, _ z: Double, _ fx: Double? = nil) {
        if seen.contains("c_" + k) || state != .play || trip != nil || scene != nil { return }
        seen.insert("c_" + k)
        scene = Cine(k: k, text: text, dur: dur, fx: fx ?? player.x, zoom: z)
    }
    func endScene() {
        guard let sc = scene else { return }
        scene = nil
        if !sceneQueue.isEmpty {
            let nx = sceneQueue.removeFirst()
            scene = nx
            if nx.k == "intro2" {
                t = 0.8
                storm = nil
                raiders = []
                introFires = true
                cam = clampD(WELL_X - W / 2 - 130, 0, WORLD - W)
                snd?.rob(); snd?.gong()
                buzz(2)
            } else if nx.k == "intro3" {
                t = 0.03
                introFires = false
                hidePlayer = false
                player.x = startX() - 250
                player.dir = 1
                cam = clampD(player.x - W / 2, 0, WORLD - W)
                snd?.dawn()
            }
            return
        }
        if sc.k.hasPrefix("intro") { finishIntro() }
    }
    private func finishIntro() {
        sceneQueue = []
        scene = nil
        t = 0.08
        storm = nil
        raiders = []
        parts = []
        introFires = false
        hidePlayer = false
        player.x = startX()
        player.vx = 0
        player.dir = 1
        shake = 0
        cam = clampD(player.x - W / 2, 0, WORLD - W)
        snd?.fanfare()
        buzz(3)
        card("DUNEFALL", "Bring the town back")
        hint("start")
    }
    func skipScene() {
        guard let sc = scene, sc.t > 0.6 else { return }
        if sc.k.hasPrefix("intro") { finishIntro() } else { endScene() }
    }

    // ---------- sailing on
    func todo() -> [String] {
        var out: [String] = []
        for k in [BType.market, .tea, .guard, .pen, .bank, .temple] where B(k).level == 0 { out.append(B(k).def.name.lowercased()) }
        if B(.well).level < 2 { out.append("obelisk") }
        return out
    }
    var fare: Int { return clampI((player.coins + bank) >> 1, 8, 25) }
    func clampI(_ v: Int, _ a: Int, _ b: Int) -> Int { return max(a, min(b, v)) }
    func nextTown() {
        let carryCoins = fare
        let nt = town + 1
        let oldDay = day
        stats[3] += 1
        reset(nt, keep: true)
        day = oldDay + 1
        day0 = oldDay
        t = 0.08
        player.coins = carryCoins
        state = .play
        fade = 1
        card(townName, TOWNSUB[town % 5] + ". You bring \(carryCoins) coins with you")
        onDawn?()
    }
    func finish() {
        state = .end
        stats[3] += 1
        ended = true
        trip = nil
        snd?.gong()
    }
    func stormK(_ x: Double) -> Double {
        guard let st = storm else { return 0 }
        return clampD(min((st.front - x) / 90, (st.dur - st.t) / 5), 0, 1)
    }
    func fishSpots() -> [Double] { return [OASIS > 0 ? OASIS + 18 : -999, NILE - 130] }
    var digX: Double { return feat == .oasis ? 660 : -999 }
    var sellX: Double { return B(.market).level > 0 ? B(.market).mid : WELL_X - 30 }

    // ---------- rules
    func costOf(_ b: Building) -> Int {
        if b.gone || b.level >= b.def.cost.count || capped(b) { return 0 }
        let c = b.def.cost[b.level]
        if b.type == .dock {
            if b.level == 0 && !todo().isEmpty { return 0 }
            if b.level > 0 { return c }
        }
        return Int(ceil(Double(c) * (1 + 0.25 * Double(town))))
    }
    /// The well sets how high the town can rise: one level, then two, then (with the obelisk) all the way.
    func capped(_ b: Building) -> Bool {
        let w = B(.well).level
        return b.def.tier && b.level >= (w == 0 ? 1 : (w == 1 ? 2 : 4))
    }
    func rackX(_ b: Building) -> Double { return b.type == .market ? b.x - 9 : b.x + b.w + 8 }
    var popCap: Int { return 10 + 6 * B(.well).level + 4 * B(.tea).level }
    var reloadTime: Double { return max(1.5, 4 - Double(B(.guard).level)) }
    var maxAmmo: Int { return up.contains("quiver") ? 9 : 6 }
    func shopX(_ k: BType) -> Double { return B(k).x - 9 }
    func shopItem(_ k: BType) -> ShopItem? {
        if B(k).level == 0 { return nil }
        return (SHOP[k] ?? []).first(where: { !up.contains($0.key) })
    }
    func buzz(_ k: Int) { onBuzz?(k) }
    func head(_ r: Role) -> Int { return folk.filter { $0.role == r }.count }
    func near(_ x: Double) -> Double { return clampD(1 - abs(x - player.x) / 280, 0, 1) }
    func inTown(_ b: Building) -> Bool { return b.x > TOWN.0 - 20 && b.x < TOWN.1 + 20 }
    var lit: Bool { return dark > 0.45 }

    func darkness(_ t: Double) -> Double {
        if t < 0.06 { return 0.5 * (1 - t / 0.06) }
        if t < 0.58 { return 0 }
        if t < 0.70 { return (t - 0.58) / 0.12 }
        if t < 0.94 { return 1 }
        return 1 - 0.5 * (t - 0.94) / 0.06
    }
    func warmth(_ t: Double) -> Double {
        let a = 1 - abs(t - 0.61) / 0.09
        let b = 1 - min(abs(t - 1), t) / 0.05
        return max(0, max(a, b))
    }

    func hint(_ k: String, again: Bool = false, _ text: String? = nil) {
        if seen.contains(k) && !again { return }
        guard let s = text ?? HINTS[k] else { return }
        seen.insert(k)
        hintText = s
        hintT = 5.5
    }

    /// What a coin would do where the player stands: a title and a line for the HUD.
    func infoLine() -> (String, String)? {
        if state != .play { return nil }
        let x = player.x
        if let tg = target(x) {
            switch tg.k {
            case .shop:
                if let sh = tg.shop, let it = shopItem(sh.k) { return (it.name.uppercased(), "\(sh.paid + sh.inc) of \(it.cost) coins. " + it.text) }
            case .merc:
                if let cv = caravan { return ("CARAVAN", "\(cv.paid + cv.inc) of 4 coins hires a guard") }
            case .tool:
                if let b = tg.b {
                    let what = b.def.tool == .digger ? "digger" : (b.def.tool == .guard ? "guard" : "herder")
                    return ("TOOL RACK", "A coin outfits a " + what)
                }
            case .slot:
                if let b = tg.b {
                    if b.type == .dock && b.level > 0 { return ("FELUCCA", "\(b.paid + b.incoming) of \(costOf(b)) coins. You sail on with \(fare) coins") }
                    return (b.def.name, "\(b.paid + b.incoming) of \(costOf(b)) coins")
                }
            case .mend:
                if let b = tg.b { return (b.def.name, "A coin patches the gate") }
            case .bank:
                return ("TREASURY", bank > 0 ? "Toss to deposit, or with an empty purse to draw five" : "Toss to deposit")
            }
        }
        if let z = zoneOf(x) {
            if z.building { return (z.def.name, head(.folk) > 0 ? "Being built" : "Nobody free to build") }
            if capped(z) && z.level < z.def.cost.count { return (z.def.name, "Raise the well to build higher") }
            if z.type == .dock && z.level == 0 && !todo().isEmpty { return ("DOCK", "Still to do: " + todo().joined(separator: ", ")) }
        }
        return nil
    }

    // ---------- spawning
    func coin(_ x: Double, _ h: Double, _ vx: Double, _ vh: Double, _ free: Bool) {
        let c = Coin(x: x, h: h, st: .air)
        c.vx = vx; c.vh = vh; c.free = free
        coins.append(c)
    }
    func dust(_ x: Double, _ h: Double, _ n: Int, _ col: Col = Col(0xe6c890)) {
        for _ in 0..<n {
            parts.append(Part(x: x + rnd(-2, 2), h: h + rnd(0, 2), vx: rnd(-10, 10), vh: rnd(4, 14), max: rnd(0.5, 1.1), col: col, grav: -14))
        }
    }
    func spark(_ x: Double, _ h: Double, _ n: Int, _ col: Col = Col(0xfff3b0)) {
        for _ in 0..<n {
            var p = Part(x: x + rnd(-3, 3), h: h + rnd(-2, 3), vx: rnd(-9, 9), vh: rnd(-4, 12), max: rnd(0.3, 0.6), col: col, grav: 0)
            p.lit = true
            parts.append(p)
        }
    }
    func confetti(_ x: Double, _ h: Double, _ n: Int) {
        let cols: [Col] = [RED, Col(0xf3e3bc), LAPIS, GOLD, TEAL]
        for i in 0..<n {
            parts.append(Part(x: x + rnd(-6, 6), h: h, vx: rnd(-30, 30), vh: rnd(25, 70), max: rnd(1, 1.9), col: cols[i % 5], grav: -90))
        }
    }
    func puff(_ x: Double, _ h: Double, _ vx: Double, _ vh: Double, _ life: Double, _ col: Col, _ r: Double, _ a: Double) {
        var p = Part(x: x, h: h, vx: vx, vh: vh, max: life, col: col, grav: 0)
        p.smoke = true; p.r = r; p.a = a
        parts.append(p)
    }
    func newHare(_ i: Int) -> Hare {
        let w = i % 2 == 0
        let x = w ? rnd(max(90, TOWN.0 - 520), TOWN.0 - 70) : rnd(TOWN.1 + 70, min(NILE - 140, TOWN.1 + 520))
        return Hare(x: x, west: w)
    }
    func addNomad(_ camp: Int, fromEdge: Bool) {
        let c = camps[camp]
        let side: Double = chance(0.5) ? -1 : 1
        let home = c.x + side * rnd(9, 18)
        let x = fromEdge ? clampD(c.x + (c.x < WELL_X ? -170 : 170), 20, NILE - 20) : home
        nomads.append(Nomad(id: nextId, camp: camp, home: home, x: x, dir: -side))
        nextId += 1
    }
    func arrivals() {
        for i in 0..<camps.count {
            if folk.count + nomads.count < popCap && nomads.filter({ $0.camp == i }).count < camps[i].cap {
                addNomad(i, fromEdge: true)
            }
        }
    }
    func recruit(_ d: Nomad) {
        nomads.removeAll { $0 === d }
        stats[1] += 1
        folk.append(Folk(id: d.id, x: d.x, dir: d.dir, role: .folk))
        rings.append(Ring(x: d.x, t: 0.4))
        dust(d.x, 3, 8); spark(d.x, 10, 8)
        snd?.recruit()
        hint("recruit")
    }
    func spawnRaider(_ p: RaidPlan) {
        let g = p.side < 0 ? B(.gw) : B(.ge)
        var x = p.kind == .mummy ? B(.tomb).x + 62 : g.x + p.side * 360
        if p.kind != .mummy && abs(player.x - x) < W * 0.7 { x += p.side * W * 0.8 }
        if p.boat { x = NILE - 24 - rnd(0, 20) }
        x = clampD(x, 10, NILE - 10)
        let base: Int
        switch p.kind {
        case .bandit: base = 2
        case .rider: base = 3
        case .boss: base = 12
        case .mummy: base = 8
        }
        raiders.append(Raider(id: nextId, kind: p.kind, x: x, side: p.side, hp: base + p.hp))
        nextId += 1
        let look = clampD(x, 60, NILE - 60)
        if p.kind == .boss {
            let msg = BOSSTEXT[feat.rawValue]
            hint("boss\(day)", again: true, msg)
            showScene("boss\(town)", msg, 3.8, 1.2, look)
        } else if abs(x - player.x) > W * 0.45 {
            let msg = p.kind == .mummy ? "The dead are walking." : (p.boat ? "They are landing at the dock." : "Raiders, from the \(p.side < 0 ? "west" : "east").")
            hint("spot\(day)\(p.side)\(p.kind.rawValue)", again: false, msg)
            showScene("spot\(day)", msg, 1.5, 1.08, look)
        }
    }

    // ---------- day and night
    func dawn() {
        snd?.dawn()
        if hadNight && nightN > 0 {
            var s = "Last night: \(nightN) raiders, \(nightDown) brought down, "
            if nightGates > 0 { s += "\(nightGates) gate" + (nightGates > 1 ? "s" : "") + " broken" } else { s += "the gates held" }
            if nightLost > 0 { s += ", \(nightLost) robbed" }
            report = s
        } else { report = "" }
        hadNight = false
        rodN = [5, 8]; digToday = 0
        let want = (town == 0 && ln <= 5) ? 5 : 3
        var i = hares.count
        while i < want { hares.append(newHare(i + day)); i += 1 }
        let tea = B(.tea)
        var income: [String] = []
        let workers = folk.filter { $0.role == .folk }.count
        if poison { poison = false; hint("poisoned", again: true) } else {
            for f in folk where f.role == .folk { coin(f.hidden ? tea.x + 33 : f.x, 6, rnd(-22, 22), rnd(50, 75), true) }
            if workers > 0 { income.append("villagers \(workers)") }
        }
        for b in bs {
            if b.level > 0 && b.def.pay > 0 && !b.robbed {
                for _ in 0..<(b.def.pay * b.level) { coin(b.mid, 5, rnd(-40, 40), rnd(55, 90), true) }
                income.append("\(b.def.name.lowercased()) \(b.def.pay * b.level)")
            }
            b.robbed = false
            if b.def.gate { b.hp = GHP[b.level] }
        }
        if B(.sphinx).level > 0 { for _ in 0..<2 { coin(B(.sphinx).x + 70, 4, rnd(-20, 20), rnd(40, 70), true) }; income.append("sphinx 2") }
        if B(.dock).level > 0 { for _ in 0..<2 { coin(B(.dock).x + 34, 6, rnd(-16, 16), rnd(40, 60), true) }; income.append("dock 2") }
        if B(.btemple).level > 0 { for _ in 0..<3 { coin(B(.btemple).x + 45, 6, rnd(-20, 20), rnd(40, 60), true) }; income.append("old temple 3") }
        if relics.contains("scarab") { for _ in 0..<3 { coin(player.x, 16, rnd(-20, 20), rnd(40, 70), true) }; income.append("scarab 3") }
        if B(.grove).level > 0 { for _ in 0..<(lush ? 6 : 3) { coin(OASIS + rnd(-20, 20), 18, rnd(-14, 14), rnd(20, 50), true) }; income.append("dates \(lush ? 6 : 3)") }
        lush = false; omen = false
        var goats = 0
        for c in herd {
            if !c.kid { coin(c.x, 4, rnd(-14, 14), rnd(35, 60), true); goats += 1 }
            c.kid = false
        }
        if goats > 0 { income.append("goats \(goats)") }
        let big = B(.pen).level >= 3
        if herd.count < min(big ? 12 : 8, head(.herder) * (big ? 3 : 2)) { herd.append(Goat(x: rnd(PAST.0 + 8, PAST.1 - 8))) }
        if !income.isEmpty { report = "This morning: " + income.joined(separator: ", ") + ". " + report }
        bank += min(3 * B(.bank).level, bank >> 3)
        carAt = ln % 3 == 0 ? 0.13 : -1
        raid = []
        for r in raiders {
            if r.kind == .mummy {
                dust(r.x, 6, 16, Col(0xd8d0b8))
                coin(r.x, 6, rnd(-20, 20), 60, true)
                r.dead = true
            } else { r.state = .flee }
        }
        raiders.removeAll { $0.dead }
        stormAt = (ln >= 3 && chance(0.3)) ? rnd(0.14, 0.3) : -1
        if feat == .port && B(.btemple).gone && ln >= 2 { stormAt = rnd(0.2, 0.34) }
        rainAt = -1; eclAt = -1
        if stormAt < 0 {
            if feat == .oasis ? (ln >= 2 && chance(0.3)) : (ln >= 3 && chance(0.12)) { rainAt = rnd(0.3, 0.5) } else if ln >= 4 && chance(0.08) { eclAt = rnd(0.3, 0.44) }
        }
        arrivals()
        if !folk.isEmpty { hint("dawn") }
        onDawn?()
    }

    func dusk() {
        if B(.tea).level > 0 { arrivals() }
        let d = ln + min(town, (ln - 1) >> 1)
        if d < 2 { return }
        if omen { hint("omen", again: true); return }
        let boss = ln >= 5 && ln % 3 == 1
        let port = boss && feat == .port
        let s0: Double = port ? -1 : (chance(0.5) ? 1 : -1)
        let n = min(1 + Int(floor(Double(d) * 0.7)), 12)
        let sph = B(.sphinx).level > 0
        for i in 0..<n {
            let odd = town > 0 ? (i % 3 != 0) : (i % 2 != 0)
            let side = odd ? s0 : -s0
            if side < 0 && sph && i % 2 == 1 { continue }
            raid.append(RaidPlan(t: 0.74 + rnd(0, 0.09), side: side, kind: (d >= 4 && i % 3 == 2) ? .rider : .bandit, hp: d >> 3))
        }
        if boss { raid.append(RaidPlan(t: 0.79, side: port ? 1 : s0, kind: .boss, hp: d >> 2, boat: port)) }
        if port { for i in 0..<3 { raid.append(RaidPlan(t: 0.795 + Double(i) * 0.006, side: 1, kind: .bandit, hp: d >> 3, boat: true)) } }
        let dead = B(.tomb).level > 0 && ln % 3 == 0
        if dead { for i in 0..<min(2 + (ln >> 2), 5) { raid.append(RaidPlan(t: 0.75 + Double(i) * 0.02, side: -1, kind: .mummy, hp: d >> 3)) } }
        hadNight = true; nightN = raid.count; nightDown = 0; nightGates = 0; nightLost = 0
        let know = B(.temple).level > 0
        var gi = 0
        for f in folk where f.role == .guard {
            f.side = know ? (gi % 3 == 2 ? -s0 : s0) : (gi % 2 == 1 ? 1 : -1)
            gi += 1
        }
        snd?.horn()
        if know { snd?.gong() }
        showScene("raid", "They always come after dark.", 3.2, 1.25)
        let star = relics.contains("star")
        if town % 5 == 0 && (!ufoDone || star) && ufo == nil && ln >= (star ? 3 : 4) && !boss && (star || chance(0.25)) {
            ufoDone = true
            let tb = B(.tomb)
            ufo = Ufo(x: !tb.gone ? tb.x + 70 : max(120, TOWN.0 - 420))
        }
        if up.contains("falcon") {
            let w = raid.filter { $0.side < 0 }.count
            let e = raid.count - w
            snd?.falcon()
            hint("falcon\(day)", again: true, "Your falcon is back: \(w) gathering to the west, \(e) to the east.")
        } else if dead {
            hint("mummy", again: true)
        } else {
            let side = s0 < 0 ? "west" : "east"
            hint("raid", again: true, know ? "The gong sounds: raiders from the \(side) tonight." : (boss ? BOSSTEXT[feat.rawValue] : nil))
        }
    }

    // ---------- tossing coins
    func slotPos(_ b: Building, _ i: Int, _ n: Int) -> (x: Double, h: Double) {
        let cols = max(1, min(n, 8))
        let row = i / cols
        let inRow = min(cols, n - row * cols)
        let rows = Int(ceil(Double(n) / Double(cols)))
        let x = b.mid - Double(inRow - 1) * 3 + Double(i % cols) * 6
        let h = b.tall + 12 + Double(rows - 1 - row) * 6
        return (x, h)
    }
    func zoneOf(_ x: Double) -> Building? {
        return bs.first(where: { !$0.gone && x > $0.x - 6 && x < $0.x + $0.w + 6 })
    }
    func target(_ x: Double) -> Target? {
        for sh in shops {
            if let it = shopItem(sh.k), abs(x - shopX(sh.k)) < 7 {
                return sh.paid + sh.inc < it.cost ? Target(k: .shop, b: nil, shop: sh) : nil
            }
        }
        if let cv = caravan, cv.stopped, !cv.sold, B(.market).level > 0, abs(x - cv.x - 22) < 12 {
            return cv.paid + cv.inc < 4 ? Target(k: .merc, b: nil, shop: nil) : nil
        }
        for b in bs where b.def.tool != nil && b.level > 0 && abs(x - rackX(b)) < 8 {
            return b.badges + b.rin < 3 ? Target(k: .tool, b: b, shop: nil) : nil
        }
        guard let b = zoneOf(x), !b.building else { return nil }
        if b.def.gate && b.level > 0 && b.hp > 0 && dark > 0.3 && b.hp + 8 * Double(b.incoming) < GHP[b.level] {
            return Target(k: .mend, b: b, shop: nil)
        }
        let cost = costOf(b)
        if cost > 0 && b.paid + b.incoming < cost { return Target(k: .slot, b: b, shop: nil) }
        if b.type == .bank && b.level > 0 { return Target(k: .bank, b: b, shop: nil) }
        return nil
    }
    func tossCoin(_ tg: Target?, _ fromBank: Bool) {
        let p = player
        if fromBank { bank -= 1 } else { p.coins -= 1 }
        p.toss = 0.25
        snd?.toss()
        buzz(0)
        guard let tg = tg else {
            coin(p.x + p.dir * 7, 16, p.dir * 26 + p.vx * 0.4, 45, false)
            p.kneelT = 1.5
            return
        }
        let c = Coin(x: p.x, h: 17, st: .slot)
        c.b = tg.b
        c.shop = tg.shop
        switch tg.k {
        case .slot:
            if let b = tg.b {
                let cost = costOf(b)
                let sp = slotPos(b, b.paid + b.incoming, cost)
                b.incoming += 1
                p.lock = b.incoming + b.paid >= cost
                b.idle = 0
                c.tx = sp.x; c.th = sp.h
            }
        case .tool:
            if let b = tg.b {
                c.st = .tool; c.tx = rackX(b) - 3 + Double(b.badges + b.rin) * 3; c.th = 10
                b.rin += 1
            }
        case .mend:
            if let b = tg.b { c.st = .mend; c.tx = b.x + 7; c.th = 10; b.incoming += 1 }
        case .bank:
            if let b = tg.b { c.st = .bank; c.tx = b.mid; c.th = 12 }
            if p.coins == 0 { p.lock = true }
        case .shop:
            if let sh = tg.shop, let it = shopItem(sh.k) {
                c.st = .shop; c.tx = shopX(sh.k); c.th = 17
                sh.inc += 1
                p.lock = sh.inc + sh.paid >= it.cost
            }
        case .merc:
            if let cv = caravan {
                c.st = .merc; c.tx = cv.x + 22; c.th = 13
                cv.inc += 1
                p.lock = cv.inc + cv.paid >= 4
            }
        }
        coins.append(c)
    }
    func built(_ b: Building) {
        b.building = false; b.paid = 0; b.level += 1; b.shake = 0.3
        stats[0] += 1
        rings.append(Ring(x: b.mid, t: 0)); rings.append(Ring(x: b.mid, t: -0.15))
        flash = max(flash, 0.25)
        for f in folk where abs(f.x - b.mid) < 130 { f.cheer = 1.8 }
        confetti(b.mid, b.tall, 16); dust(b.mid, 2, 14)
        snd?.fanfare()
        buzz(3)
        for i in 0..<34 {
            parts.append(Part(x: b.x + rnd(0, b.w), h: rnd(2, b.tall), vx: rnd(-26, 26), vh: rnd(30, 95), max: rnd(0.6, 1.3),
                              col: i % 3 != 0 ? Col(0xffe08a) : Col(0xfff8dc), grav: -120))
        }
        let L = b.level
        if L >= 3 && !b.def.gate && !b.def.far { hint("lv", again: true, "The \(b.def.name.lowercased()) is at level \(L)" + (L == b.def.cost.count ? ", as high as it goes." : ".")) }
        if !festDone && !b.def.far && todo().isEmpty {
            festDone = true
            fest = 14
            for f in folk { f.cheer = 6 }
            hint("festival", again: true)
        }
        switch b.type {
        case .gw, .ge:
            b.hp = GHP[L]; hint("gate")
        case .market:
            hint("market\(L)")
            if L == 1 { showScene("bazaar", "The bazaar is open again.", 3.6, 1.25, b.mid) }
        case .tea: hint("tea\(L)")
        case .guard: hint("guard\(L)")
        case .pen: hint("pen\(L)")
        case .bank: hint("bank\(L)")
        case .well:
            hint(L == 2 ? "well2x" : "well\(L)")
            if L == 2 { showScene("obelisk", "The obelisk stands. Travellers will see it for miles.", 3.8, 1.35, b.mid) }
        case .temple:
            hint("temple\(L)")
            if L == 1 { showScene("temple", "The temple lamps are lit again.", 3.6, 1.25, b.mid) }
        case .dock: hint("dock1")
        case .sphinx:
            hint("sphinx1")
            showScene("sphinx", "The Sphinx looks east again.", 3.4, 1.3, b.mid)
        case .tomb:
            ankh = true
            for _ in 0..<18 { coin(b.x + 25, 6, rnd(-50, 50), rnd(60, 110), true) }
            hint("tomb1")
            showScene("tomb", "Gold, an ankh, and something that should have stayed asleep.", 4.5, 1.3, b.mid + 30)
        case .grove: hint("grove1")
        case .btemple:
            for _ in 0..<20 { coin(b.x + 45, 8, rnd(-60, 60), rnd(60, 120), true) }
            hint("btemple1")
            showScene("btemple", "A temple nobody has seen for a thousand years.", 3.8, 1.3, b.mid)
        case .hermit: break
        }
    }

    // ---------- update
    func update(_ dt0: Double) {
        var dt = dt0
        NOW += dt
        if cardT > 0 { cardT -= dt } else if hintT > 0 { hintT -= dt }
        if state == .title || state == .end { return }
        if state == .over {
            updWorld(dt)
            return
        }
        if slow > 0 { slow -= dt; dt *= 0.28 }
        if let sc = scene {
            sc.t += dt
            dark = darkness(t)
            updWorld(dt); updFolk(dt * 0.5)
            var pan = 0.02
            if sc.k == "intro1" {
                updRaiders(dt)
                shake = max(shake, 0.07)
                pan = 0.45
                if chance(dt * 30) { puff(cam + rnd(0, W), rnd(0, 30), rnd(140, 240), rnd(-4, 12), rnd(0.5, 1.1), Col(0xf0d6a0), 2.8, 0.35) }
            } else if sc.k == "intro2" {
                pan = 0.6
                sc.fx += 9 * dt
                if chance(dt * 40) {
                    var e = Part(x: cam + rnd(0, W), h: rnd(4, 40), vx: rnd(8, 30), vh: rnd(14, 40), max: rnd(1, 2.2), col: chance(0.5) ? Col(0xffc24a) : Col(0xe8602a), grav: 4)
                    e.lit = true
                    parts.append(e)
                }
                if chance(dt * 6) { puff(cam + rnd(0, W), rnd(20, 50), rnd(6, 16), rnd(8, 18), rnd(1.5, 3), Col(0x2a2422), 5, 0.3) }
            } else if sc.k == "intro3" {
                let p = player
                let goal = startX()
                if p.x < goal - 2 {
                    p.vx = 96
                    p.x = min(goal, p.x + p.vx * dt)
                    p.phase += p.vx * dt * 0.075
                    if chance(dt * 12) { dust(p.x - 8, 0, 1) }
                } else { p.vx = 0 }
                sc.fx = p.x + 30
                pan = 0.05
            }
            cam = lerp(cam, clampD(sc.fx - W / 2, 0, WORLD - W), 1 - pow(pan, dt))
            zoom = lerp(zoom, sc.zoom, 1 - pow(0.03, dt))
            if sc.t > sc.dur { endScene() }
            return
        }
        zoom = lerp(zoom, 1, 1 - pow(0.03, dt))
        let t0 = t
        t += dt / DAY_LEN
        if t0 < 0.66 && t >= 0.66 { dusk() }
        if t >= 1 { t -= 1; day += 1; dawn() }
        dark = darkness(t)
        if let e = ecl { dark = max(dark, 0.85 * sin(PI * clampD(e / 20, 0, 1))) }
        var i = raid.count - 1
        while i >= 0 {
            if i < raid.count && t >= raid[i].t && t > 0.5 { let r = raid.remove(at: i); spawnRaider(r) }
            i -= 1
        }
        if let tr = trip {
            let nt = tr + dt
            trip = nt
            if nt > 2.4 { fade = min(1, fade + dt * 2.2) }
            if nt > 4 {
                trip = nil
                if town % 5 == 4 && !ended { finish() } else { nextTown() }
                return
            }
        } else {
            fade = max(0, fade - dt * 0.6)
            updPlayer(dt)
        }
        updCoins(dt); updFolk(dt); updFinds(dt); updRaiders(dt); updWorld(dt)
        let p = player
        let want = clampD(p.x - W / 2 + p.dir * 24, 0, WORLD - W)
        cam = lerp(cam, want, 1 - pow(0.0015, dt))
        let raiding = raiders.contains(where: { $0.state == .raid })
        let mode = raiding ? 3 : (dark > 0.5 ? 2 : ((t > 0.5 && warmth(t) > 0.12) ? 1 : 0))
        snd?.music(NOW, mode, mode == 0 ? 0.3 + 0.7 * near(B(.market).x) : 1)
    }

    /// Fishing by the water, and the sunken tomb outside the oasis town.
    func updFinds(_ dt: Double) {
        let p = player
        let still = abs(p.vx) < 3 && trip == nil
        let safe = !raiders.contains(where: { $0.state == .raid && abs($0.x - p.x) < 120 })
        let spots = fishSpots()
        var si = -1
        for k in 0..<2 where spots[k] > 0 && abs(p.x - spots[k]) < 13 { si = k }
        if si >= 0 { hint(rodN[si] > 0 ? "fish" : "fished", again: false) }
        if si >= 0 && still && safe && rodN[si] > 0 {
            let wx = si == 1 ? NILE + 12 : spots[0] - 13
            p.dir = wx < p.x ? -1 : 1
            if rodSpot != si { rodSpot = si; rodT = rnd(2.4, 4.2) }
            rodT -= dt
            if rodT <= 0 {
                rodN[si] -= 1
                rodT = rnd(2.4, 4.2)
                let big = chance(0.2)
                for _ in 0..<(big ? 3 : 1) { coin(wx, 3, -p.dir * rnd(26, 40), rnd(60, 80), true) }
                for _ in 0..<10 {
                    parts.append(Part(x: wx + rnd(-4, 4), h: rnd(0, 3), vx: rnd(-22, 22), vh: rnd(20, 60), max: rnd(0.4, 0.8), col: Col(0xcfeaf2), grav: -160))
                }
                snd?.recruit()
                buzz(0)
                hint(big ? "fishbig" : "fish2", again: true)
            }
        } else { rodSpot = -1 }
        let dx = digX
        if dx > 0 && abs(p.x - dx) < 14 {
            hint(digN >= 6 ? "digdone" : (carry > 0 ? "digfull" : (digToday >= 3 ? "digrest" : "dig")), again: true)
            if still && safe && carry == 0 && digN < 6 && digToday < 3 {
                digT += dt
                if chance(dt * 9) { dust(dx + rnd(-6, 6), 1, 1) }
                if digT >= 3 + Double(digN) * 0.7 {
                    digT = 0
                    let worth = [5, 6, 8, 10, 12, 15]
                    carry = worth[digN]
                    digN += 1; digToday += 1
                    snd?.urn()
                    spark(p.x, 22, 10)
                    hint("relicfound", again: true, "A relic worth \(carry) coins. Carry it to \(B(.market).level > 0 ? "the bazaar" : "the trader by the well"): one at a time.")
                }
            } else { digT = 0 }
        } else { digT = 0 }
        if carry > 0 && still && abs(p.x - sellX) < 18 {
            let v = carry
            carry = 0
            for _ in 0..<v { coin(sellX + rnd(-6, 6), 10 + rnd(0, 8), rnd(-30, 30), rnd(40, 80), true) }
            snd?.recruit()
            spark(p.x, 18, 12)
            hint("sold", again: true, "Sold for \(v) coins.")
        }
        let tb = B(.tomb)
        if town % 5 == 0 && tb.level > 0 && ufoSeen && !relics.contains("star") && abs(p.x - tb.x - 25) < 12 {
            hint("deep0")
            if still && safe {
                deepT += dt
                if chance(dt * 8) { dust(tb.x + 25 + rnd(-6, 6), 1, 1) }
                if deepT > 4 {
                    deepT = 0
                    relics.insert("star")
                    for _ in 0..<12 { coin(tb.x + 25, 8, rnd(-40, 40), rnd(60, 100), true) }
                    snd?.gong()
                    buzz(3)
                    hint("star", again: true)
                    showScene("deep", "Under the tomb, a room no mason ever cut. Its keeper left one thing behind.", 4.5, 1.35, tb.x + 25)
                }
            } else { deepT = 0 }
        } else { deepT = 0 }
        let hm = B(.hermit)
        if !hm.gone && abs(p.x - hm.x - 22) < 70 { hint("hermit0") }
    }

    func updPlayer(_ dt: Double) {
        let p = player
        let a = input.stick
        let d: Double = abs(a) > 0.1 ? sgn(a) : 0
        if d != 0 { p.dir = d }
        let speeds: [Double] = [104, 120, 136, 146]
        let tack = 1 + (up.contains("saddle") ? 0.12 : 0) + (up.contains("racer") ? 0.14 : 0)
        let want = d * speeds[min(B(.pen).level, 3)] * tack
        let rate = ((d == 0 || want * p.vx < 0) ? 900.0 : 340.0) * dt
        if d == 0 && abs(p.vx) > 50 { dust(p.x + sgn(p.vx) * 9, 0, 2) }
        p.vx += clampD(want - p.vx, -rate, rate)
        p.x = clampD(p.x + p.vx * dt, 30, NILE - 14)
        if p.x <= 30 || p.x >= NILE - 14 { p.vx = 0 }
        let sp = abs(p.vx)
        p.idle = sp < 3 ? p.idle + dt : 0
        p.kneelT = max(0, p.kneelT - dt)
        let kneelWant: Double = (sp < 4 && d == 0 && (p.kneelT > 0 || p.idle > 7)) ? 1 : 0
        p.kneelK = lerp(p.kneelK, kneelWant, 1 - pow(0.004, dt))
        p.phase += sp * dt * 0.075
        p.toss -= dt; p.cd -= dt; p.gcd -= dt; p.draw -= dt
        if sp > 60 && chance(dt * 14) { dust(p.x - p.dir * 8, 0, 1) }
        if sp > 80 && chance(dt * 10) {
            puff(p.x - p.dir * 9, 1, -p.dir * rnd(4, 14), rnd(3, 8), rnd(0.8, 1.6), Col(0xecd2a0), 2.4, 0.42)
        }
        let st = Int(floor(p.phase / PI * 2))
        if st != p.st {
            p.st = st
            if sp > 10 {
                let odd = (st & 1) == 1
                prints.append(Footprint(x: p.x - p.dir * (odd ? 6 : -5), t: 0))
                if prints.count > 70 { prints.removeFirst() }
            }
        }
        // the purse
        if !input.toss { p.lock = false }
        if input.toss && !p.lock && p.cd <= 0 {
            let tg = target(p.x)
            var blocked = false
            var dockWait = false
            if tg == nil, let z = zoneOf(p.x), !z.building, z.level < z.def.cost.count, capped(z) { blocked = true }
            if tg == nil, let z = zoneOf(p.x), z.type == .dock, z.level == 0, !z.building, !todo().isEmpty { blocked = true; dockWait = true }
            var paying = false
            if let k = tg?.k, k != .bank { paying = true }
            var drawing = false
            if let k = tg?.k, k == .bank { drawing = true }
            if blocked {
                p.lock = true
                snd?.empty()
                if dockWait { hint("dock0", again: true, "No boat will stop at half a town. Still to do: " + todo().joined(separator: ", ") + ".") } else { hint("cap", again: true) }
            } else if paying && bank > 0 {
                tossCoin(tg, true)
                p.cd = 0.2
            } else if p.coins > 0 {
                tossCoin(tg, false)
                p.cd = 0.2
            } else if drawing && bank > 0 {
                let n = min(5, bank)
                bank -= n
                p.lock = true
                snd?.urn()
                let bx = B(.bank).x + 28
                for i in 0..<n {
                    let c = Coin(x: bx, h: 10, st: .back)
                    c.age = -Double(i) * 0.07
                    coins.append(c)
                }
            } else if !bs.contains(where: { $0.paid > 0 }) && !shops.contains(where: { $0.paid > 0 }) {
                snd?.empty()
                p.cd = 0.5
                hint("broke", again: true)
            }
        }
        // the bow
        if p.rl > 0 {
            p.rl -= dt
            if p.rl <= 0 { p.ammo = maxAmmo; snd?.slot() }
        }
        if input.reload && p.rl <= 0 && p.ammo < maxAmmo { p.rl = reloadTime; p.rlT = p.rl; hint("reload") }
        input.reload = false
        if input.fire && p.gcd <= 0 && p.rl <= 0 {
            if p.ammo > 0 {
                var best: Double? = nil
                var bestD = 240.0
                for r in raiders where r.state == .raid {
                    let dd = abs(r.x - p.x)
                    if dd < bestD && dd > 4 { bestD = dd; best = r.x }
                }
                if best == nil {
                    bestD = 200
                    for h in hares {
                        let dd = abs(h.x - p.x)
                        if dd < bestD && dd > 4 { bestD = dd; best = h.x }
                    }
                }
                var ad = p.dir
                if let bx = best { ad = sgn(bx - p.x) }
                if ad != p.dir { hint("back", again: false) }
                p.aim = ad
                p.ammo -= 1; p.gcd = 0.38; p.draw = 0.25
                arrows.append(Arrow(x: p.x + ad * 6, h: 19, vx: ad * 300, vh: 20, life: 0.6, mine: true, fire: up.contains("fire")))
                snd?.arrow(1)
                if p.ammo == 0 { p.rl = reloadTime; p.rlT = p.rl; hint("reload") }
            } else {
                p.rl = reloadTime; p.rlT = p.rl
            }
        }
        for u in urns where !u.open && abs(u.x - p.x) < 10 {
            u.open = true
            for _ in 0..<u.n { coin(u.x, 4, rnd(-34, 34), rnd(60, 95), true) }
            snd?.urn()
            dust(u.x, 2, 8)
            hint("urn")
        }
    }

    func updCoins(_ dt: Double) {
        let p = player
        var i = coins.count - 1
        while i >= 0 {
            let c = coins[i]
            c.age += dt
            switch c.st {
            case .air:
                c.vh -= 260 * dt
                c.x = clampD(c.x + c.vx * dt, 24, NILE - 8)
                c.h += c.vh * dt
                if c.h <= 0 {
                    c.h = 0
                    if c.vh < -45 { c.vh *= -0.35; c.vx *= 0.5; snd?.clink(near(c.x)) } else { c.st = .ground }
                }
            case .ground:
                if c.claimed == 0 && c.age > (c.free ? 0.5 : 2.2) && abs(c.x - p.x) < 13 { c.st = .back; c.age = 0 }
            case .back:
                if c.age >= 0 {
                    let dx = p.x - c.x, dh = 15 - c.h
                    let dist = hypot(dx, dh), stepLen = 210 * dt
                    if dist > stepLen { c.x += dx / dist * stepLen; c.h += dh / dist * stepLen } else {
                        coins.remove(at: i)
                        p.coins += 1
                        picked += 1
                        snd?.pick()
                        spark(p.x, 14, 2)
                    }
                }
            case .slot, .tool, .mend, .bank, .shop, .merc:
                let dx = c.tx - c.x, dh = c.th - c.h
                let dist = hypot(dx, dh), stepLen = 160 * dt
                if dist > stepLen {
                    c.x += dx / dist * stepLen; c.h += dh / dist * stepLen
                    if chance(0.6) { puff(c.x, c.h, 0, 0, 0.32, Col(0xffe08a), 1.3, 0.55) }
                } else {
                    coins.remove(at: i)
                    snd?.slot()
                    spark(c.tx, c.th + 2, 7)
                    puff(c.tx, c.th + 1, 0, 0, 0.3, Col(0xfff8dc), 3.4, 0.7)
                    landed(c)
                }
            }
            i -= 1
        }
        // Dustfall's rule: a half-paid job hands every coin back the moment you cannot or will not finish it
        let broke = p.coins + bank == 0
        for b in bs {
            let away = zoneOf(p.x) !== b
            b.idle = (!b.building && b.paid > 0 && b.incoming == 0 && (broke || away)) ? b.idle + dt : 0
            if b.idle > 0.45 {
                let c0 = costOf(b)
                let cost = c0 > 0 ? c0 : b.paid
                for k in 0..<b.paid {
                    let sp = slotPos(b, k, cost)
                    let c = Coin(x: sp.x, h: sp.h, st: .back)
                    c.age = -Double(k) * 0.07
                    coins.append(c)
                }
                b.paid = 0; b.idle = 0; p.lock = true
                let nm = b.def.name.lowercased()
                hint("refund", again: true, broke ? "Not enough coins, so they came back. The \(nm) needs \(cost)." : "Coins returned. The \(nm) needs all \(cost) at once.")
            }
        }
        for sh in shops {
            let away = abs(p.x - shopX(sh.k)) > 9
            sh.idle = (sh.paid > 0 && sh.inc == 0 && (broke || away)) ? sh.idle + dt : 0
            if sh.idle > 0.45 {
                for q in 0..<sh.paid {
                    let c = Coin(x: shopX(sh.k) - 6 + Double(q) * 3, h: 22, st: .back)
                    c.age = -Double(q) * 0.07
                    coins.append(c)
                }
                sh.paid = 0; sh.idle = 0; p.lock = true
                hint("refund", again: true, "Coins returned. That costs all of them at once.")
            }
        }
        if let cv = caravan, cv.paid > 0, !cv.sold, cv.inc == 0 {
            let away = !cv.stopped || broke || abs(p.x - cv.x - 22) > 14
            cv.idle = away ? cv.idle + dt : 0
            if cv.idle > 0.45 {
                for k in 0..<cv.paid {
                    let c = Coin(x: cv.x + 13 + Double(k) * 6, h: 21, st: .back)
                    c.age = -Double(k) * 0.07
                    coins.append(c)
                }
                cv.paid = 0; cv.idle = 0; p.lock = true
                hint("refund", again: true, "Coins returned. The caravan guard costs all 4 at once.")
            }
        }
    }

    private func landed(_ c: Coin) {
        switch c.st {
        case .bank:
            bank += 1
        case .shop:
            guard let sh = c.shop else { return }
            sh.inc -= 1
            sh.paid += 1
            if let it = shopItem(sh.k), sh.paid >= it.cost {
                sh.paid = 0
                up.insert(it.key)
                let sx = shopX(sh.k)
                rings.append(Ring(x: sx, t: 0))
                spark(sx, 16, 14); confetti(sx, 18, 10)
                snd?.fanfare()
                buzz(3)
                if it.key == "falcon" { snd?.falcon() }
                if it.key == "quiver" { player.ammo = maxAmmo; player.rl = 0 }
                hint("up_" + it.key, again: true, it.name + ". " + it.text)
            }
        case .merc:
            guard let cv = caravan else { return }
            cv.inc -= 1
            cv.paid += 1
            if cv.paid >= 4 && !cv.sold {
                cv.sold = true
                let f = Folk(id: nextId, x: cv.x + 22, dir: 1, role: .guard)
                nextId += 1
                f.cheer = 1.5
                folk.append(f)
                rings.append(Ring(x: f.x, t: 0.3))
                spark(f.x, 12, 10)
                snd?.recruit()
                hint("merc")
            }
        case .tool:
            if let b = c.b { b.rin -= 1; b.badges += 1 }
        case .mend:
            if let b = c.b {
                b.incoming -= 1
                b.hp = min(GHP[b.level], b.hp + 8); b.shake = 0.12
                snd?.hammer(near(b.x))
            }
        case .slot:
            guard let b = c.b else { return }
            b.incoming -= 1
            b.paid += 1
            if b.paid < costOf(b) { return }
            if b.type == .dock && b.level > 0 {
                b.paid = 0
                trip = 0
                snd?.fanfare()
                buzz(3)
                return
            }
            if b.type == .hermit {
                let names = ["scarab", "lamp", "charm"]
                let r = names[min(b.level, 2)]
                b.paid = 0; b.level += 1
                relics.insert(r)
                rings.append(Ring(x: b.x + 22, t: 0))
                spark(b.x + 22, 14, 14)
                snd?.fanfare(); snd?.gong()
                buzz(3)
                hint("relic_" + r, again: true)
                return
            }
            b.building = true; b.progress = 0; b.need = 3 + Double(b.paid) * 0.45
            let free = head(.folk) > 0
            hint(free ? "funded" : "noworkers", again: !free)
        default:
            break
        }
    }

    func updFolk(_ dt: Double) {
        let night = dark > 0.5
        let tea = B(.tea)
        let p = player
        for f in folk {
            f.cd -= dt
            f.ham = max(0, f.ham - dt)
            f.hidden = false
            var tx = f.x
            var sp = 30.0
            switch f.role {
            case .folk:
                let jobs = bs.filter { $0.building && (!night || inTown($0)) }
                let job = jobs.min { abs($0.x - f.x) < abs($1.x - f.x) }
                var rack: Building? = nil
                if job == nil && !night {
                    rack = bs.first { b in
                        if b.badges <= 0 { return false }
                        if b.claim == 0 || b.claim == f.id { return true }
                        return !folk.contains(where: { $0.id == b.claim && $0.role == .folk })
                    }
                }
                if let job = job {
                    tx = job.mid + Double((f.id % 5) - 2) * 6
                    sp = inTown(job) ? 46 : 70
                    if abs(f.x - tx) < 2 {
                        job.progress += dt
                        if f.cd <= 0 {
                            f.cd = 0.55; f.ham = 0.2
                            snd?.hammer(near(f.x) * 0.7)
                            dust(f.x + f.dir * 3, 3, 1)
                            job.shake = 0.06
                        }
                        if job.progress >= job.need { built(job) }
                    }
                } else if let rack = rack {
                    rack.claim = f.id
                    tx = rackX(rack); sp = 40
                    if abs(f.x - tx) < 2 {
                        rack.badges -= 1; rack.claim = 0
                        f.role = rack.def.tool ?? .folk
                        spark(f.x, 12, 8)
                        snd?.recruit()
                        hint(f.role == .digger ? "digger" : (f.role == .guard ? "guard" : "herder"))
                    }
                } else if night || stormK(f.x) > 0.1 {
                    if tea.level > 0 { tx = tea.x + 33; if abs(f.x - tx) < 2 { f.hidden = true } } else { tx = WELL_X + Double((f.id % 7) - 3) * 7 }
                } else {
                    f.wait -= dt
                    if f.wait <= 0 { f.wait = rnd(2, 6); f.wx = clampD(WELL_X + rnd(-190, 190), TOWN.0 + 24, TOWN.1 - 24) }
                    tx = f.wx; sp = 18
                }
            case .digger:
                if night || stormK(f.x) > 0.1 {
                    if tea.level > 0 { tx = tea.x + 33; if abs(f.x - tx) < 2 { f.hidden = true } } else { tx = WELL_X + Double((f.id % 7) - 3) * 7 }
                } else {
                    tx = QUARRY + Double((f.id % 5) - 2) * 8; sp = 36
                    if abs(f.x - tx) < 2 {
                        f.dir = 1
                        if f.cd <= 0 { f.cd = 0.8; f.ham = 0.25; snd?.hammer(near(f.x) * 0.5); dust(f.x + 4, 2, 2) }
                        f.work += dt
                        if f.work > 9 {
                            f.work = 0
                            let lying = coins.filter { $0.st == .ground && abs($0.x - QUARRY) < 50 }.count
                            if lying < 8 { coin(f.x + 5, 4, rnd(-12, 12), rnd(40, 60), true) }
                            if chance(0.15) {
                                for _ in 0..<3 { coin(f.x + 5, 6, rnd(-20, 20), rnd(50, 80), true) }
                                rings.append(Ring(x: f.x, t: 0.3)); spark(f.x + 4, 8, 10)
                                snd?.urn(); f.cheer = 1.5; hint("relic")
                            }
                        }
                    }
                }
            case .guard:
                let g = f.side < 0 ? B(.gw) : B(.ge)
                let k = Double(folk.filter { $0.role == .guard && $0.side == f.side && $0.id < f.id }.count)
                if dark > 0.3 { tx = f.side < 0 ? g.x + 22 + k * 7 : g.x - 8 - k * 7; sp = 46 } else {
                    f.wait -= dt
                    if f.wait <= 0 { f.wait = rnd(3, 7); f.wx = B(.guard).x + rnd(-20, 80) }
                    tx = f.wx; sp = 20
                }
                let L = B(.guard).level
                let reach = 70 + Double(L) * 14
                let r = raiders.filter { $0.state == .raid && abs($0.x - f.x) < reach }.min { abs($0.x - f.x) < abs($1.x - f.x) }
                if let r = r, f.cd <= 0 {
                    let cds: [Double] = [1.7, 1.7, 1.3, 1, 0.75]
                    f.cd = cds[min(L, 4)]
                    let dd = sgn(r.x - f.x)
                    f.dir = dd == 0 ? 1 : dd
                    f.ham = 0.25
                    arrows.append(Arrow(x: f.x, h: 15, vx: f.dir * 260, vh: 18, life: 0.6, mine: false))
                    snd?.arrow(near(f.x) * 0.6)
                }
            case .herder:
                if night { tx = B(.pen).x + 36 + Double((f.id % 3) - 1) * 8 } else {
                    f.wait -= dt
                    if f.wait <= 0 { f.wait = rnd(3, 7); f.wx = rnd(PAST.0, PAST.1) }
                    tx = f.wx; sp = 22
                }
            }
            f.cheer = max(0, f.cheer - dt)
            stepTo(f, tx, sp, dt)
        }
        for d in nomads {
            if d.target == nil {
                if let c = coins.first(where: { $0.st == .ground && !$0.free && $0.claimed == 0 && abs($0.x - d.x) < 70 }) {
                    c.claimed = d.id
                    d.target = c
                }
            }
            if let c = d.target {
                if c.st != .ground || !coins.contains(where: { $0 === c }) { d.target = nil } else if stepTo(d, c.x, 34, dt) {
                    coins.removeAll { $0 === c }
                    recruit(d)
                }
            } else {
                d.wait -= dt
                if d.wait <= 0 { d.wait = rnd(3, 8); d.wx = d.home + rnd(-10, 10) }
                stepTo(d, d.wx, 12, dt)
            }
        }
        for c in herd {
            c.t -= dt
            if c.t <= 0 { c.t = rnd(2, 6); c.tx = rnd(PAST.0, PAST.1) }
            stepTo(c, c.tx, 8, dt)
        }
        for h in hares {
            let lo = h.west ? 60.0 : TOWN.1 + 40
            let hi = h.west ? TOWN.0 - 40 : NILE - 110
            let dx = h.x - p.x
            let close = abs(dx) < 64
            if close {
                hint("hare")
                h.tx = clampD(h.x + (dx < 0 ? -1 : 1) * 60, lo, hi)
            } else {
                h.t -= dt
                if h.t <= 0 { h.t = rnd(1.5, 5); h.tx = clampD(h.x + rnd(-50, 50), lo, hi) }
            }
            if abs(h.tx - h.x) > 2 {
                h.dir = sgn(h.tx - h.x)
                h.x += h.dir * (close ? 80 : 26) * dt
                h.hop += dt * (close ? 13 : 8)
            } else { h.hop = 0 }
            if abs(dx) < 9 { catchHare(h) }
        }
        hares.removeAll { $0.dead }
    }

    func catchHare(_ h: Hare) {
        if h.dead { return }
        h.dead = true
        for _ in 0..<2 { coin(h.x, 6, rnd(-18, 18), rnd(40, 65), true) }
        dust(h.x, 2, 6)
        snd?.recruit()
        hint("hare2", again: true)
    }

    func hurt(_ r: Raider, _ from: Double) {
        r.hp -= 1; r.hurt = 0.15; r.stag = 0.38
        spark(r.x, 13, 6, Col(0xffffff))
        r.x += sgn(from) * 3
        snd?.hit(near(r.x))
        buzz(1)
        dust(r.x, 10, 3, RED)
        if r.hp <= 0 && r.kind == .boss {
            slow = 1.5; flash = 0.45; shake = 0.5
            for _ in 0..<8 { coin(r.x, 12, rnd(-50, 50), rnd(60, 110), true) }
            snd?.gong()
            buzz(2)
            hint("warlord", again: true)
        }
        if r.hp <= 0 {
            r.dead = true
            stats[2] += 1
            nightDown += 1
            let n = r.loot + (chance(0.35) ? 1 : 0)
            for _ in 0..<n { coin(r.x, 8, rnd(-25, 25), rnd(40, 70), true) }
            fallen.append(Fallen(x: r.x, t: 0, dir: r.dir))
            dust(r.x, 4, 8)
        }
    }

    private enum Act { case rob, none, victim(Folk), building(Building) }

    private func bossAI(_ r: Raider, _ dt: Double) -> Bool {
        let g = r.side < 0 ? B(.gw) : B(.ge)
        let gateUp = g.level > 0 && g.hp > 0
        switch feat {
        case .oasis:
            if B(.well).level == 0 || poison { return false }
            if stepTo(r, WELL_X, r.speed * 1.2, dt) {
                poison = true
                r.state = .flee
                shake = 0.35
                snd?.rob()
                hint("poison", again: true)
                for _ in 0..<16 { puff(WELL_X + rnd(-8, 8), rnd(2, 12), rnd(-8, 8), rnd(6, 20), rnd(1, 2), Col(0x7ddf6a), 2.6, 0.5) }
            }
            return true
        case .cliff:
            if !gateUp { return false }
            let stand = g.x + r.side * 128
            if abs(r.x - stand) > 4 { stepTo(r, stand, r.speed * 1.4, dt); return true }
            r.moving = false
            r.dir = -r.side
            r.bcd -= dt
            if r.bcd <= 0 {
                r.bcd = 4.2
                rocks.append(Rock(x: r.x - r.side * 10, dir: -r.side))
                snd?.gate(near(r.x))
                dust(r.x - r.side * 8, 2, 8)
            }
            return true
        case .temple:
            if r.raised >= 6 { return false }
            let stand = g.x + r.side * 150
            if abs(r.x - stand) > 4 { stepTo(r, stand, r.speed * 1.4, dt) } else { r.moving = false; r.dir = -r.side }
            r.bcd -= dt
            if r.bcd <= 0 {
                r.bcd = 8
                if raiders.filter({ $0.kind == .mummy }).count < 2 {
                    r.raised += 1
                    let mx = r.x - r.side * 16
                    raiders.append(Raider(id: nextId, kind: .mummy, x: mx, side: r.side, hp: 3))
                    nextId += 1
                    rings.append(Ring(x: mx, t: 0.2))
                    snd?.gong()
                    for _ in 0..<12 { puff(mx + rnd(-5, 5), rnd(0, 10), rnd(-6, 6), rnd(8, 22), rnd(0.8, 1.6), Col(0x7dffb0), 2.4, 0.4) }
                }
            }
            return true
        default:
            return false
        }
    }

    func updRaiders(_ dt: Double) {
        let p = player
        for r in raiders {
            r.hurt -= dt; r.cd -= dt
            if r.burn > 0 {
                r.burn -= dt
                if chance(0.5) {
                    var q = Part(x: r.x + rnd(-2, 2), h: rnd(8, 20), vx: rnd(-4, 4), vh: rnd(8, 18), max: 0.5, col: chance(0.5) ? Col(0xffc24a) : Col(0xe8602a), grav: 0)
                    q.lit = true
                    parts.append(q)
                }
            }
            if r.stag > 0 {
                r.stag -= dt; r.moving = false
                r.x = clampD(r.x - r.dir * 14 * dt, 10, NILE - 10)
                continue
            }
            if r.state == .flee {
                r.dir = r.side
                r.x += r.side * r.speed * 1.25 * dt
                r.walk += dt; r.moving = true
                if r.x < TOWN.0 - 520 || r.x > TOWN.1 + 520 || r.x < 12 || r.x > NILE - 12 { r.dead = true }
                continue
            }
            let g = r.side < 0 ? B(.gw) : B(.ge)
            let atGate = r.side < 0 ? (r.x < g.x + 2 && r.x > g.x - 8) : (r.x > g.x + 12 && r.x < g.x + 22)
            if g.level > 0 && g.hp > 0 && atGate {
                r.moving = false
                if r.cd <= 0 {
                    r.cd = 1
                    g.hp -= r.gateDmg; g.shake = 0.15
                    snd?.gate(near(g.x))
                    dust(g.x + 7, 8, 3)
                    for q in 0..<4 {
                        parts.append(Part(x: g.x + 7, h: rnd(6, 16), vx: rnd(-40, 40), vh: rnd(20, 70), max: rnd(0.6, 1),
                                          col: q % 2 == 1 ? Col(0x86663f) : Col(0xb08854), grav: -220))
                    }
                    if g.hp <= 0 { g.hp = 0; nightGates += 1; dust(g.x + 7, 6, 16); shake = 0.3 }
                }
                continue
            }
            if r.kind == .boss && bossAI(r, dt) { continue }
            var tx = WELL_X
            var act = Act.none
            let inside = r.x > TOWN.0 && r.x < TOWN.1
            let victim: Folk? = r.kind == .boss ? nil : folk.first(where: { !$0.hidden && $0.role != .guard && abs($0.x - r.x) < 60 })
            if r.rob > 0 && abs(p.x - r.x) < 110 && trip == nil { tx = p.x; act = .rob } else if let v = victim { tx = v.x; act = .victim(v) } else if inside && r.kind != .mummy {
                let b = bs.filter { $0.level > 0 && $0.def.pay > 0 && !$0.robbed }.min { abs($0.x - r.x) < abs($1.x - r.x) }
                if let b = b { tx = b.mid; act = .building(b) }
            }
            let slowed = 1 - 0.3 * stormK(r.x)
            if stepTo(r, tx, r.speed * slowed, dt) || abs(r.x - tx) < 7 {
                switch act {
                case .rob:
                    if p.coins == 0 {
                        if ankh {
                            ankh = false
                            flash = 1; shake = 0.5
                            snd?.gong()
                            buzz(2)
                            hint("ankh", again: true)
                            for o in raiders where abs(o.x - p.x) < 260 && o.kind != .mummy { o.state = .flee }
                        } else { gameOver() }
                    } else {
                        let n = min(p.coins, r.rob)
                        p.coins -= n; r.loot += n; r.state = .flee
                        if carry > 0 { carry = 0; digN -= 1; digToday -= 1; hint("relost", again: true, "The raider took the relic too.") }
                        shake = 0.35
                        buzz(2)
                        snd?.rob()
                        hint("hit")
                        dust(p.x, 12, 6, GOLD)
                    }
                case .none:
                    if r.kind != .mummy && abs(r.x - WELL_X) < 8 { r.state = .flee }
                case .victim(let v):
                    folk.removeAll { $0 === v }
                    nightLost += 1
                    dust(v.x, 6, 8)
                    snd?.rob()
                    hint("mug")
                    if r.kind != .mummy { r.state = .flee }
                case .building(let b):
                    b.robbed = true; r.loot += 2; r.state = .flee
                    nightLost += 1
                    snd?.rob()
                    hint("robbed")
                }
            }
        }
        var i = arrows.count - 1
        while i >= 0 {
            var a = arrows[i]
            a.vh -= 105 * dt; a.x += a.vx * dt; a.h += a.vh * dt; a.life -= dt
            arrows[i] = a
            var hitR: Raider? = nil
            if a.h < 26 { hitR = raiders.first(where: { !$0.dead && abs($0.x - a.x) < 7 && (a.mine || $0.state == .raid) }) }
            if let r = hitR {
                hurt(r, a.vx)
                if a.fire {
                    if !r.dead { hurt(r, a.vx) }
                    r.burn = 1.6
                }
                arrows.remove(at: i)
            } else if a.mine, let h = hares.first(where: { !$0.dead && abs($0.x - a.x) < 7 }) {
                catchHare(h)
                arrows.remove(at: i)
            } else if a.h <= 0 || a.x < 20 || a.x > NILE {
                if a.h <= 0 && a.x < NILE - 4 {
                    stuck.append(Stuck(x: a.x, ang: atan2(-a.vh, a.vx), t: 0))
                    if stuck.count > 40 { stuck.removeFirst() }
                    dust(a.x, 1, 2)
                }
                arrows.remove(at: i)
            }
            i -= 1
        }
        raiders.removeAll { $0.dead }
        // the Stone Lord's boulders
        var k = rocks.count - 1
        while k >= 0 {
            var rk = rocks[k]
            rk.t += dt; rk.x += rk.dir * 96 * dt; rk.rot += rk.dir * dt * 9
            let g = rk.dir > 0 ? B(.gw) : B(.ge)
            let atWall = rk.dir > 0 ? (rk.x >= g.x - 5 && rk.x < g.x + 10) : (rk.x <= g.x + 19 && rk.x > g.x + 4)
            if g.level > 0 && g.hp > 0 && atWall {
                g.hp = max(0, g.hp - 9); g.shake = 0.3
                rk.dead = true
                snd?.gate(near(g.x)); snd?.hit(near(g.x))
                if g.hp == 0 { nightGates += 1 }
                dust(rk.x, 6, 10, Col(0x8f4e2a))
            } else if abs(rk.x - p.x) < 9 && trip == nil {
                let n = min(2, p.coins)
                p.coins -= n
                for _ in 0..<n { coin(p.x, 10, rk.dir * rnd(20, 60), rnd(50, 80), true) }
                p.vx = rk.dir * 170
                rk.dead = true
                shake = 0.35
                buzz(2)
                snd?.hit(1)
                hint("rock", again: true)
                dust(rk.x, 4, 10)
            } else if rk.t > 7 || rk.x < 20 || rk.x > NILE - 10 || (rk.dir > 0 ? rk.x > WELL_X : rk.x < WELL_X) {
                rk.dead = true
                dust(rk.x, 3, 10)
            }
            if rk.dead { rocks.remove(at: k) } else { rocks[k] = rk }
            k -= 1
        }
    }

    func gameOver() {
        if state == .over { return }
        state = .over
        buzz(2)
        snd?.rob()
    }

    func updWorld(_ dt: Double) {
        // rain, the eclipse, the festival, the night visitor, the trapped road
        if rainAt > 0 && t >= rainAt && rain == nil && state == .play { rain = 0; rainAt = -1; lush = true; hint("rain", again: true) }
        if let r = rain {
            rain = r + dt
            if r + dt > 22 { rain = nil }
        }
        if eclAt > 0 && t >= eclAt && ecl == nil && state == .play {
            ecl = 0; eclAt = -1; omen = true
            snd?.gong()
            hint("eclipse", again: true)
            showScene("eclipse", "The sun is going out.", 3.4, 1, player.x)
        }
        if let e = ecl {
            ecl = e + dt
            if e + dt > 20 { ecl = nil }
        }
        if fest > 0 {
            fest -= dt
            festT -= dt
            if festT <= 0 {
                festT = rnd(0.35, 0.8)
                let fx = WELL_X + rnd(-170, 170), fh = rnd(46, 84)
                let cols: [Col] = [RED, GOLD, TEAL, Col(0xfff3b0), Col(0xd96ad0)]
                let cc = cols[Int.random(in: 0..<5)]
                for q in 0..<22 {
                    let a = Double(q) / 22 * PI * 2
                    var pt = Part(x: fx, h: fh, vx: cos(a) * rnd(18, 34), vh: sin(a) * rnd(18, 34) + 10, max: rnd(0.7, 1.2), col: cc, grav: -30)
                    pt.lit = true
                    parts.append(pt)
                }
                snd?.clink(near(fx))
            }
        }
        if let u = ufo {
            u.t += dt
            if u.phase == 0 {
                u.h = max(46, u.h - 34 * dt)
                if u.t > 0.5 { hint("ufo", again: false); showScene("ufo", "Something is coming down out of the sky.", 3.6, 1.2, u.x) }
                if u.h <= 46 { u.phase = 1; u.t = 0 }
            } else if u.phase == 1 {
                ufoSeen = true
                if abs(player.x - u.x) < 34 && u.n < 8 {
                    u.gt += dt
                    if u.gt > 1 { u.gt = 0; u.n += 1; coin(u.x + rnd(-8, 8), 40, rnd(-10, 10), 0, true); hint("ufo2") }
                }
                if u.t > 18 || dark < 0.4 { u.phase = 2 }
            } else {
                u.h += 90 * dt
                if u.h > 200 { ufo = nil; hint("ufogone") }
            }
        }
        trapCd -= dt
        let traps = trapXs()
        for i in 0..<traps.count where trapCd <= 0 && trapUp(i) && abs(player.x - traps[i]) < 7 {
            trapCd = 1.2
            let p = player
            if p.coins > 0 { p.coins -= 1; coin(p.x, 12, -p.dir * rnd(30, 60), rnd(50, 80), true) }
            p.vx = -p.dir * 150
            shake = 0.3
            buzz(2)
            snd?.hit(1)
            hint("trap", again: true)
        }
        for i in 0..<devils.count {
            var dv = devils[i]
            dv.x += dv.dir * 14 * dt
            if dv.x < dv.a { dv.dir = 1 }
            if dv.x > dv.b { dv.dir = -1 }
            devils[i] = dv
        }
        // the haboob
        if stormAt > 0 && t >= stormAt && storm == nil && state == .play {
            let st = Storm(front: player.x - W / 2 - 520)
            storm = st
            stormAt = -1
            hint("storm", again: true)
            snd?.horn()
            showScene("haboob", "Haboob. Get everyone inside.", 3.4, 1, st.front + W * 0.45)
        }
        if let st = storm {
            st.front += 58 * dt
            st.t += dt
            let p = player
            let k = stormK(p.x)
            let open = p.x < TOWN.0 || p.x > TOWN.1 || !(B(.gw).level > 0 || B(.ge).level > 0)
            if k > 0.2 { shake = max(shake, 0.05 * k) }
            if k > 0.5 && open && !relics.contains("charm") && trip == nil {
                p.x = min(NILE - 14, p.x + 26 * k * dt)
                st.leak += dt
                if st.leak > 2.6 && p.coins > 0 {
                    st.leak = 0
                    p.coins -= 1
                    coin(p.x, 14, rnd(90, 150), rnd(40, 70), true)
                    snd?.rob()
                    hint("stormcoin", again: true)
                }
            }
            if !st.raided && ln >= 4 && st.front > TOWN.0 - 260 {
                st.raided = true
                for i in 0..<2 {
                    raiders.append(Raider(id: nextId, kind: .bandit, x: clampD(st.front - 40 - Double(i) * 26, 20, NILE - 20), side: -1, hp: 2))
                    nextId += 1
                }
                for r in raiders where r.side < 0 && r.dir < 0 { r.dir = 1 }
                hint("stormraid", again: true)
            }
            if k > 0.3 && chance(dt * 24) { puff(cam + rnd(0, W), rnd(0, 6), rnd(120, 220), rnd(-2, 10), rnd(0.5, 1), Col(0xf0d6a0), 2.5, 0.3) }
            if st.t > st.dur {
                storm = nil
                hint("stormover", again: true)
                let bt = B(.btemple)
                if feat == .port && bt.gone {
                    bt.gone = false
                    hint("btemple0", again: true)
                    showScene("btemple0", "The storm has uncovered the top of something very old.", 3.6, 1.25, bt.x + 45)
                } else if urns.filter({ !$0.open }).count < 4 {
                    let spots: [Double] = [340, 520, 900, 1060, 2260, 2380, 2580, 2760]
                    let free = spots.filter { x in (x < TOWN.0 - 80 || x > TOWN.1 + 80) && zoneOf(x) == nil }
                    if let x = free.randomElement() { urns.append(Urn(x: x, n: 5)) }
                }
            }
        }
        // the caravan
        if carAt > 0 && t >= carAt && caravan == nil && state == .play {
            caravan = Caravan(x: max(40, B(.gw).x - 900))
            carAt = -1
            hint("caravan")
        }
        if let cv = caravan {
            let m = B(.market)
            let stop = m.mid + 20
            if cv.stopped {
                cv.t += dt
                if (cv.t > 10 && cv.inc == 0 && cv.paid == 0) || (cv.t > 16 && cv.inc == 0) { cv.stopped = false; cv.leaving = true }
            } else {
                cv.x += 30 * dt
                cv.ph += 30 * dt * 0.075
                if !cv.leaving && cv.x >= stop {
                    cv.stopped = true; cv.t = 0
                    if m.level > 0 {
                        for _ in 0..<(3 + 2 * m.level) { coin(cv.x - 10, 6, rnd(-40, 30), rnd(50, 90), true) }
                        snd?.fanfare()
                    }
                }
                if cv.x > NILE - 30 { caravan = nil }
            }
        }
        // shoppers in the bazaar
        do {
            let m = B(.market)
            let want = m.level * 3 + B(.tea).level + (B(.well).level > 1 ? 2 : 0)
            while crowd.count < want { crowd.append(Stroller(id: nextId, x: m.mid)); nextId += 1 }
            if crowd.count > want { crowd.removeLast(crowd.count - want) }
            let home = dark > 0.4
            for c in crowd {
                if home {
                    c.tx = m.mid + Double((c.id % 3) - 1) * 25
                    if abs(c.x - c.tx) < 2 { c.hidden = true }
                } else {
                    c.hidden = false
                    c.wait -= dt
                    if c.wait <= 0 {
                        c.wait = rnd(2, 7)
                        c.tx = chance(0.6) ? m.x + rnd(4, m.w - 4) : rnd(TOWN.0 + 30, TOWN.1 - 30)
                    }
                }
                stepTo(c, c.tx, 16 + Double(c.id % 3) * 4, dt)
            }
        }
        // gate towers loose their own arrows once they are stone
        for g in [B(.gw), B(.ge)] where g.level > 2 && g.hp > 0 {
            g.acd -= dt
            let sd: Double = g.type == .gw ? -1 : 1
            if g.acd <= 0, raiders.contains(where: { $0.state == .raid && ($0.x - g.x) * sd > 0 && abs($0.x - g.x) < 110 }) {
                g.acd = 1.3
                arrows.append(Arrow(x: g.x + 7, h: 36, vx: sd * 250, vh: -58, life: 0.46, mine: false))
                snd?.arrow(near(g.x) * 0.6)
            }
        }
        var i = rings.count - 1
        while i >= 0 { rings[i].t += dt; if rings[i].t >= 1 { rings.remove(at: i) }; i -= 1 }
        i = prints.count - 1
        while i >= 0 { prints[i].t += dt; if prints[i].t > 12 { prints.remove(at: i) }; i -= 1 }
        i = stuck.count - 1
        while i >= 0 { stuck[i].t += dt; if stuck[i].t >= 22 { stuck.remove(at: i) }; i -= 1 }
        i = fallen.count - 1
        while i >= 0 { fallen[i].t += dt; if fallen[i].t >= 5 { fallen.remove(at: i) }; i -= 1 }
        i = parts.count - 1
        while i >= 0 {
            var q = parts[i]
            q.life += dt
            if q.life > q.max { parts.remove(at: i) } else {
                q.vh += q.grav * dt; q.x += q.vx * dt; q.h = max(0, q.h + q.vh * dt)
                parts[i] = q
            }
            i -= 1
        }
        if parts.count > 600 { parts.removeFirst(parts.count - 600) }
        for b in bs { b.shake = max(0, b.shake - dt) }
        shake = max(0, shake - dt)
        flash = max(0, flash - dt * 1.5)
    }

    // ---------- one line of advice: what would help most right now
    func nextGoal() -> String {
        let p = player
        func way(_ x: Double) -> String { return x < p.x - 40 ? "to the west" : (x > p.x + 40 ? "to the east" : "right here") }
        func open(_ k: BType) -> Bool { let b = B(k); return b.level == 0 && !b.building }
        if folk.isEmpty {
            if p.coins < 3, let u = urns.filter({ !$0.open }).min(by: { abs($0.x - p.x) < abs($1.x - p.x) }) { return "Ride over the old urn \(way(u.x)) for coins" }
            if let n = nomads.min(by: { abs($0.x - p.x) < abs($1.x - p.x) }) { return "Toss a coin to a nomad at the tents \(way(n.x)): they join you and build" }
        }
        let m = B(.market)
        if open(.market) { return "Rebuild the bazaar \(way(m.mid)) for \(costOf(m)) coins: it pays every morning" }
        if m.level > 0 && head(.digger) == 0 && m.badges == 0 { return "Toss a coin on the tool rack left of the bazaar: a digger mines gold at the quarry" }
        if head(.digger) > 0 && coins.contains(where: { $0.st == .ground && abs($0.x - QUARRY) < 60 }) { return "Your diggers have gold waiting at the quarry \(way(QUARRY))" }
        if open(.gw) && ln >= 1 { return "Raise the west gate for \(costOf(B(.gw))) coins before the raiders come at night" }
        if open(.pen) { return "Rebuild the camel yard \(way(B(.pen).mid)) for \(costOf(B(.pen))) coins: goats pay each dawn" }
        if B(.pen).level > 0 && head(.herder) == 0 && B(.pen).badges == 0 { return "Toss a coin on the crook rack right of the camel yard: a herder's goats pay each dawn" }
        if open(.tea) { return "Rebuild the teahouse for \(costOf(B(.tea))) coins: it pays, and hides villagers at night" }
        if open(.ge) { return "Raise the east gate for \(costOf(B(.ge))) coins" }
        if open(.guard) { return "Rebuild the barracks for \(costOf(B(.guard))) coins, then put a coin on its spear rack for a guard" }
        if B(.guard).level > 0 && head(.guard) == 0 && B(.guard).badges == 0 { return "Toss a coin on the spear rack right of the barracks: a guard holds the gate" }
        if open(.well) { return "Rebuild the well for \(costOf(B(.well))) coins: then every building can rise a level" }
        if open(.bank) { return "Rebuild the treasury for \(costOf(B(.bank))) coins: coins kept there are safe from raiders" }
        if open(.temple) { return "Rebuild the temple for \(costOf(B(.temple))) coins: it pays well, and its gong warns you of raids" }
        let w = B(.well)
        if w.level == 1 && !w.building { return "Raise the obelisk at the well for \(costOf(w)) coins: it unlocks the top levels and the dock" }
        let dk = B(.dock)
        if dk.level == 0 && !dk.building && todo().isEmpty { return "Build the dock at the Nile, far to the east, for \(costOf(dk)) coins" }
        if dk.level > 0 { return "Pay the felucca 6 coins at the dock to sail on, or keep raising the town: higher levels pay more" }
        return "Raise any building another level: higher levels pay more each morning"
    }

    // ---------- a bot that plays the game, to see what the economy does
    func botRun(days: Int) -> String {
        start(intro: false)
        var out = "town day coins vault picked folk dig grd herd goats | bazaar tea barracks yard well temple wgate egate treasury dock\n"
        let dt = 1.0 / 30
        var lastDay = day
        var lastPicked = 0
        var steps = 0
        func stand(_ b: Building) -> Double { return b.mid }
        while state == .play && day <= days && steps < 400000 {
            steps += 1
            if let sc = scene { sc.t = 1; skipScene() }
            let p = player
            var goal: Double? = nil
            var toss = false
            let threat = raiders.filter { $0.state == .raid }.min(by: { abs($0.x - p.x) < abs($1.x - p.x) })
            var fire = false
            if let r = threat, abs(r.x - p.x) < 220 { fire = true }
            let have = p.coins + bank
            let staff = head(.digger) + head(.herder) + head(.guard)
            let free = head(.folk)
            let loose = coins.filter { $0.st == .ground && $0.claimed == 0 && abs($0.x - p.x) < 900 }.min(by: { abs($0.x - p.x) < abs($1.x - p.x) })
            // what to buy next, in the order the advice line gives it
            var buy: (x: Double, cost: Int)? = nil
            func slot(_ k: BType, _ maxLevel: Int) {
                if buy != nil { return }
                let b = B(k)
                if b.gone || b.building || b.level >= maxLevel { return }
                let c = costOf(b)
                if c > 0 { buy = (b.mid, c) }
            }
            func rack(_ k: BType, _ role: Role, _ want: Int) {
                if buy != nil { return }
                let b = B(k)
                if b.level > 0 && head(role) + b.badges + b.rin < want && free > 1 { buy = (rackX(b), 1) }
            }
            if free > 0 || folk.isEmpty {
                slot(.market, 1); rack(.market, .digger, 2); slot(.gw, 1); slot(.pen, 1); rack(.pen, .herder, 2); slot(.tea, 1); slot(.ge, 1)
                slot(.guard, 1); rack(.guard, .guard, 2); slot(.well, 1); slot(.market, 2); slot(.bank, 1); slot(.temple, 1); slot(.gw, 2); slot(.ge, 2)
                slot(.well, 2); slot(.dock, 1); slot(.market, 4); slot(.temple, 3); slot(.tea, 3); slot(.pen, 3); slot(.guard, 4); slot(.bank, 3); slot(.dock, 2)
            }
            if let c = loose, !(dark > 0.5 && (c.x < TOWN.0 - 40 || c.x > TOWN.1 + 40)) {
                goal = c.x
            } else if dark < 0.3 && p.coins > 0 && folk.count < staff + 3 && folk.count + 1 <= popCap, let n = nomads.min(by: { abs($0.x - p.x) < abs($1.x - p.x) }) {
                goal = n.x + 10
                if abs(p.x - goal!) < 14 && target(p.x) == nil && !coins.contains(where: { $0.st != .back && !$0.free && abs($0.x - n.x) < 70 }) { toss = true }
            } else if let b = buy, have >= b.cost, !(dark > 0.5 && (b.x < TOWN.0 - 40 || b.x > TOWN.1 + 40)) {
                goal = b.x
                if abs(p.x - b.x) < 3 { toss = true }
            } else if dark < 0.2 && t < 0.5 && rodN[1] > 0 {
                goal = fishSpots()[1]
            } else {
                goal = startX()
            }
            if let gx = goal { input.stick = abs(gx - p.x) < 2.5 ? 0 : sgn(gx - p.x) } else { input.stick = 0 }
            input.toss = toss
            input.fire = fire
            update(dt)
            if day != lastDay || state != .play {
                lastDay = day
                let lv = [BType.market, .tea, .guard, .pen, .well, .temple, .gw, .ge, .bank, .dock].map { String(B($0).level) }.joined(separator: " ")
                out += "\(town + 1) \(ln) \(player.coins) \(bank) \(picked - lastPicked) \(folk.count) \(head(.digger)) \(head(.guard)) \(head(.herder)) \(herd.count) | \(lv)\n"
                lastPicked = picked
            }
        }
        out += "ended: state \(state) on day \(day), town \(town + 1), steps \(steps)\n"
        return out
    }

    // ---------- saving: the town as it stood at the last dawn
    func snapshot() -> SaveData {
        let roles: [Int] = folk.map { f in
            switch f.role {
            case .folk: return 0
            case .digger: return 1
            case .guard: return 2
            case .herder: return 3
            }
        }
        var d = SaveData(day: day, coins: player.coins, bank: bank, levels: bs.map { $0.level }, roles: roles, herd: herd.count,
                         up: Array(up), urns: urns.map { $0.open }, seen: Array(seen))
        d.town = town; d.day0 = day0; d.relics = Array(relics); d.ankh = ankh; d.stats = stats
        return d
    }
    func restore(_ d: SaveData) {
        reset(d.town ?? 0)
        state = .play
        t = 0.08
        day = d.day
        day0 = d.day0 ?? 0
        player.coins = d.coins
        bank = d.bank
        up = Set(d.up)
        seen = Set(d.seen)
        relics = Set(d.relics ?? [])
        ankh = d.ankh ?? false
        if let st = d.stats, st.count == 4 { stats = st }
        for i in 0..<min(bs.count, d.levels.count) {
            let b = bs[i]
            b.level = min(d.levels[i], b.def.cost.count)
            if b.def.gate { b.hp = GHP[b.level] }
            if b.level > 0 { b.gone = false }
        }
        for i in 0..<min(urns.count, d.urns.count) { urns[i].open = d.urns[i] }
        let all: [Role] = [.folk, .digger, .guard, .herder]
        for r in d.roles {
            let f = Folk(id: nextId, x: WELL_X + rnd(-150, 150), dir: 1, role: all[max(0, min(3, r))])
            nextId += 1
            folk.append(f)
        }
        for _ in 0..<min(8, d.herd) { let gt = Goat(x: rnd(PAST.0 + 8, PAST.1 - 8)); gt.kid = false; herd.append(gt) }
        player.ammo = maxAmmo
        card(townName, "Day \(ln)")
    }

    /// Takes one worker off their job, so there is someone free to build.
    func releaseOne() -> Bool {
        for r in [Role.digger, .herder, .guard] {
            if let f = folk.first(where: { $0.role == r }) { f.role = .folk; spark(f.x, 12, 6); return true }
        }
        return false
    }

    // ---------- set scenes for the simulator screenshots
    func demo(_ k: String) {
        if k == "oasis" {
            reset(1)
            state = .play
            t = 0.3
            for bt in [BType.market, .tea, .gw, .ge] { B(bt).level = 1 }
            for j in 0..<3 {
                let f = Folk(id: nextId, x: OASIS - 110 + Double(j) * 16, dir: 1, role: j == 2 ? .guard : .folk)
                nextId += 1
                folk.append(f)
            }
            player.x = OASIS - 64
            player.coins = 9
            cam = clampD(player.x - W / 2 + 24, 0, WORLD - W)
            return
        }
        if k == "port" {
            reset(3)
            state = .play
            t = 0.3
            for bt in [BType.market, .tea, .guard, .pen, .bank, .temple, .gw, .ge, .dock] { B(bt).level = 1 }
            B(.well).level = 2
            B(.btemple).gone = false
            storm = nil
            rain = 0
            fest = 8
            devils = [Devil(x: 2860, dir: -1, a: 2800, b: 2990)]
            player.x = 3000
            player.coins = 12
            cam = clampD(player.x - W / 2, 0, WORLD - W)
            return
        }
        start(intro: false)
        hintT = 0; cardT = 0
        let setup: [(BType, Int)] = [(.market, 2), (.tea, 1), (.well, 1), (.gw, 2), (.ge, 1), (.guard, 1), (.bank, 1), (.pen, k == "night" ? 1 : 0)]
        bank = 7
        for (bt, lv) in setup {
            let b = B(bt); b.level = lv
            if b.def.gate { b.hp = GHP[lv] }
        }
        for j in 0..<5 {
            let f = Folk(id: nextId, x: WELL_X - 80 + Double(j) * 34, dir: 1, role: j == 4 ? .guard : .folk)
            nextId += 1
            folk.append(f)
        }
        player.coins = 14
        let tp = B(.temple); tp.paid = 5
        if k == "night" {
            t = 0.8; day = 3; dark = 1
            player.x = B(.gw).x + 60; player.dir = -1
            raiders.append(Raider(id: 900, kind: .bandit, x: B(.gw).x - 40, side: -1, hp: 2))
            raiders.append(Raider(id: 901, kind: .boss, x: B(.gw).x - 90, side: -1, hp: 12))
        } else {
            t = 0.3
            player.x = tp.mid - 30
            let pen = B(.pen); pen.building = true; pen.paid = 6; pen.need = 5.7; pen.progress = 2.5
            let cv = Caravan(x: B(.market).mid + 20); cv.stopped = true; cv.paid = 2
            caravan = cv
        }
        cam = clampD(player.x - W / 2 + player.dir * 24, 0, WORLD - W)
    }
}
