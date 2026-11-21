import Foundation

// The simulation for the trial slice: town 1 only. Ported from dunefall/index.html
// (updPlayer, updCoins, updFolk, updRaiders, dawn, dusk), without towns 2-5, cutscenes,
// weather, the tomb, fishing, the shop upgrades and saving.

struct Target {
    enum Kind { case slot, tool, mend }
    let b: Building
    let k: Kind
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
    let WELL_X = 1655.0
    let TOWN: (Double, Double) = (1296, 1992)
    let QUARRY = 985.0
    let PAST: (Double, Double) = (2080, 2200)

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

    func reset() {
        state = .title
        t = 0.62; day = 1; dark = 0; nextId = 1; shake = 0; flash = 0; report = ""
        player = Player()
        player.x = WELL_X - 22
        bs = [Building(.market, 1408), Building(.tea, 1500), Building(.guard, 1700), Building(.pen, 1866),
              Building(.well, 1640), Building(.temple, 1778), Building(.gw, 1290), Building(.ge, 1978)]
        coins = []; folk = []; nomads = []; raiders = []; herd = []; parts = []; arrows = []
        rings = []; stuck = []; fallen = []; prints = []; raid = []
        hadNight = false
        seen = []; hintText = ""; hintT = 0
        camps = [Camp(x: 430, cap: 3), Camp(x: 1130, cap: 2), Camp(x: 2320, cap: 2), Camp(x: 2860, cap: 3)]
        urns = [Urn(x: 250, n: 6), Urn(x: 860, n: 4), Urn(x: 2230, n: 4), Urn(x: 2650, n: 6)]
        hares = (0..<5).map { newHare($0) }
        for i in 0..<camps.count { for _ in 0..<camps[i].cap { addNomad(i, fromEdge: false) } }
        cam = player.x - W / 2
    }

    func start() {
        reset()
        state = .play
        t = 0.08
        cardText = "DUNEFALL"
        cardT = 3.6
        hint("start")
    }

    // ---------- rules
    func costOf(_ b: Building) -> Int {
        if b.level >= b.def.cost.count || capped(b) { return 0 }
        return b.def.cost[b.level]
    }
    func capped(_ b: Building) -> Bool { return b.def.tier && b.level >= 1 + B(.well).level }
    func rackX(_ b: Building) -> Double { return b.type == .market ? b.x - 9 : b.x + b.w + 8 }
    var popCap: Int { return 10 + 6 * B(.well).level + 4 * B(.tea).level }
    var reloadTime: Double { return max(1.5, 4 - Double(B(.guard).level)) }
    let maxAmmo = 6
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
            case .tool:
                let what = tg.b.def.tool == .digger ? "digger" : (tg.b.def.tool == .guard ? "guard" : "herder")
                return ("TOOL RACK", "A coin outfits a " + what)
            case .slot:
                return (tg.b.def.name, "\(tg.b.paid + tg.b.incoming) of \(costOf(tg.b)) coins")
            case .mend:
                return (tg.b.def.name, "A coin patches the gate")
            }
        }
        if let z = zoneOf(x) {
            if z.building { return (z.def.name, head(.folk) > 0 ? "Being built" : "Nobody free to build") }
            if capped(z) && z.level < z.def.cost.count { return (z.def.name, "Raise the well to build higher") }
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
        folk.append(Folk(id: d.id, x: d.x, dir: d.dir, role: .folk))
        rings.append(Ring(x: d.x, t: 0.4))
        dust(d.x, 3, 8); spark(d.x, 10, 8)
        snd?.recruit()
        hint("recruit")
    }
    func spawnRaider(_ p: RaidPlan) {
        let g = p.side < 0 ? B(.gw) : B(.ge)
        var x = g.x + p.side * 360
        if abs(player.x - x) < W * 0.7 { x += p.side * W * 0.8 }
        x = clampD(x, 10, NILE - 10)
        raiders.append(Raider(id: nextId, kind: p.kind, x: x, side: p.side, hp: (p.kind == .bandit ? 2 : 3) + p.hp))
        nextId += 1
        if abs(x - player.x) > W * 0.45 {
            hint("spot\(day)\(p.side)", again: false, "Raiders, from the \(p.side < 0 ? "west" : "east").")
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
        let want = day <= 5 ? 5 : 3
        var i = hares.count
        while i < want { hares.append(newHare(i + day)); i += 1 }
        let tea = B(.tea)
        for f in folk where f.role == .folk {
            coin(f.hidden ? tea.x + 33 : f.x, 6, rnd(-22, 22), rnd(50, 75), true)
        }
        for b in bs {
            if b.level > 0 && b.def.pay > 0 && !b.robbed {
                for _ in 0..<(b.def.pay * b.level) { coin(b.mid, 5, rnd(-40, 40), rnd(55, 90), true) }
            }
            b.robbed = false
            if b.def.gate { b.hp = GHP[b.level] }
        }
        for c in herd {
            if !c.kid { coin(c.x, 4, rnd(-14, 14), rnd(35, 60), true) }
            c.kid = false
        }
        if herd.count < min(8, head(.herder) * 2) { herd.append(Goat(x: rnd(PAST.0 + 8, PAST.1 - 8))) }
        raid = []
        for r in raiders { r.state = .flee }
        arrivals()
        if !folk.isEmpty { hint("dawn") }
    }

    func dusk() {
        if B(.tea).level > 0 { arrivals() }
        let d = day
        if d < 2 { return }
        let s0: Double = chance(0.5) ? 1 : -1
        let n = min(1 + Int(floor(Double(d) * 0.7)), 12)
        for i in 0..<n {
            let side = i % 2 == 1 ? s0 : -s0
            raid.append(RaidPlan(t: 0.74 + rnd(0, 0.09), side: side, kind: (d >= 4 && i % 3 == 2) ? .rider : .bandit, hp: d >> 3))
        }
        hadNight = true; nightN = raid.count; nightDown = 0; nightGates = 0; nightLost = 0
        let know = B(.temple).level > 0
        var gi = 0
        for f in folk where f.role == .guard {
            f.side = know ? (gi % 3 == 2 ? -s0 : s0) : (gi % 2 == 1 ? 1 : -1)
            gi += 1
        }
        snd?.horn()
        if know { snd?.gong() }
        hint("raid", again: true, know ? "The gong sounds: raiders from the \(s0 < 0 ? "west" : "east") tonight." : nil)
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
        return bs.first { x > $0.x - 6 && x < $0.x + $0.w + 6 }
    }
    func target(_ x: Double) -> Target? {
        for b in bs where b.def.tool != nil && b.level > 0 && abs(x - rackX(b)) < 8 {
            return b.badges + b.rin < 3 ? Target(b: b, k: .tool) : nil
        }
        guard let b = zoneOf(x), !b.building else { return nil }
        if b.def.gate && b.level > 0 && b.hp > 0 && dark > 0.3 && b.hp + 8 * Double(b.incoming) < GHP[b.level] {
            return Target(b: b, k: .mend)
        }
        let cost = costOf(b)
        return cost > 0 && b.paid + b.incoming < cost ? Target(b: b, k: .slot) : nil
    }
    func tossCoin(_ tg: Target?) {
        let p = player
        p.coins -= 1
        p.toss = 0.25
        snd?.toss()
        guard let tg = tg else {
            coin(p.x + p.dir * 7, 16, p.dir * 26 + p.vx * 0.4, 45, false)
            p.kneelT = 1.5
            return
        }
        let b = tg.b
        let c: Coin
        switch tg.k {
        case .slot:
            let cost = costOf(b)
            let sp = slotPos(b, b.paid + b.incoming, cost)
            b.incoming += 1
            p.lock = b.incoming + b.paid >= cost
            b.idle = 0
            c = Coin(x: p.x, h: 17, st: .slot); c.tx = sp.x; c.th = sp.h
        case .tool:
            c = Coin(x: p.x, h: 17, st: .tool); c.tx = rackX(b) - 3 + Double(b.badges + b.rin) * 3; c.th = 10
            b.rin += 1
        case .mend:
            c = Coin(x: p.x, h: 17, st: .mend); c.tx = b.x + 7; c.th = 10
            b.incoming += 1
        }
        c.b = b
        coins.append(c)
    }
    func built(_ b: Building) {
        b.building = false; b.paid = 0; b.level += 1; b.shake = 0.3
        rings.append(Ring(x: b.mid, t: 0)); rings.append(Ring(x: b.mid, t: -0.15))
        flash = max(flash, 0.25)
        for f in folk where abs(f.x - b.mid) < 130 { f.cheer = 1.8 }
        confetti(b.mid, b.tall, 16); dust(b.mid, 2, 14)
        snd?.fanfare()
        for i in 0..<34 {
            parts.append(Part(x: b.x + rnd(0, b.w), h: rnd(2, b.tall), vx: rnd(-26, 26), vh: rnd(30, 95), max: rnd(0.6, 1.3),
                              col: i % 3 != 0 ? Col(0xffe08a) : Col(0xfff8dc), grav: -120))
        }
        if b.def.gate { b.hp = GHP[b.level]; hint("gate") } else {
            let key: String
            switch b.type {
            case .market: key = "market"
            case .tea: key = "tea"
            case .guard: key = "guard"
            case .pen: key = "pen"
            case .well: key = "well"
            default: key = "temple"
            }
            hint(key + "\(b.level)")
        }
    }

    // ---------- update
    func update(_ dt0: Double) {
        let dt = dt0
        NOW += dt
        if hintT > 0 { hintT -= dt }
        if cardT > 0 { cardT -= dt }
        if state == .title { return }
        if state == .over {
            updWorld(dt)
            return
        }
        let t0 = t
        t += dt / DAY_LEN
        if t0 < 0.66 && t >= 0.66 { dusk() }
        if t >= 1 { t -= 1; day += 1; dawn() }
        dark = darkness(t)
        var i = raid.count - 1
        while i >= 0 {
            if t >= raid[i].t && t > 0.5 { let r = raid.remove(at: i); spawnRaider(r) }
            i -= 1
        }
        updPlayer(dt); updCoins(dt); updFolk(dt); updRaiders(dt); updWorld(dt)
        let p = player
        let want = clampD(p.x - W / 2 + p.dir * 24, 0, WORLD - W)
        cam = lerp(cam, want, 1 - pow(0.0015, dt))
    }

    func updPlayer(_ dt: Double) {
        let p = player
        let a = input.stick
        let d: Double = abs(a) > 0.1 ? sgn(a) : 0
        if d != 0 { p.dir = d }
        let speeds: [Double] = [104, 120, 136]
        let want = d * speeds[min(B(.pen).level, 2)]
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
            let zb = zoneOf(p.x)
            var blocked = false
            if tg == nil, let z = zb, !z.building, z.level < z.def.cost.count, capped(z) { blocked = true }
            if blocked {
                p.lock = true
                snd?.empty()
                hint("cap", again: true)
            } else if p.coins > 0 {
                tossCoin(tg)
                p.cd = 0.2
            } else if !bs.contains(where: { $0.paid > 0 }) {
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
                arrows.append(Arrow(x: p.x + ad * 6, h: 19, vx: ad * 300, vh: 20, life: 0.6, mine: true))
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
                        snd?.pick()
                        spark(p.x, 14, 2)
                    }
                }
            case .slot, .tool, .mend:
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
                    if let b = c.b { landed(c.st, b) }
                }
            }
            i -= 1
        }
        // Dustfall's rule: a half-paid job hands every coin back the moment you cannot or will not finish it
        let broke = p.coins == 0
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
    }

    private func landed(_ st: CoinState, _ b: Building) {
        if st == .tool { b.rin -= 1; b.badges += 1; return }
        b.incoming -= 1
        if st == .mend {
            b.hp = min(GHP[b.level], b.hp + 8); b.shake = 0.12
            snd?.hammer(near(b.x))
            return
        }
        b.paid += 1
        if b.paid < costOf(b) { return }
        b.building = true; b.progress = 0; b.need = 3 + Double(b.paid) * 0.45
        let free = head(.folk) > 0
        hint(free ? "funded" : "noworkers", again: !free)
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
                } else if night {
                    if tea.level > 0 { tx = tea.x + 33; if abs(f.x - tx) < 2 { f.hidden = true } } else { tx = WELL_X + Double((f.id % 7) - 3) * 7 }
                } else {
                    f.wait -= dt
                    if f.wait <= 0 { f.wait = rnd(2, 6); f.wx = clampD(WELL_X + rnd(-190, 190), TOWN.0 + 24, TOWN.1 - 24) }
                    tx = f.wx; sp = 18
                }
            case .digger:
                if night {
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
                    let cds: [Double] = [1.7, 1.7, 1.3, 1]
                    f.cd = cds[min(L, 3)]
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
        dust(r.x, 10, 3, RED)
        if r.hp <= 0 {
            r.dead = true
            nightDown += 1
            let n = r.loot + (chance(0.35) ? 1 : 0)
            for _ in 0..<n { coin(r.x, 8, rnd(-25, 25), rnd(40, 70), true) }
            fallen.append(Fallen(x: r.x, t: 0, dir: r.dir))
            dust(r.x, 4, 8)
        }
    }

    private enum Act { case rob, none, victim(Folk), building(Building) }

    func updRaiders(_ dt: Double) {
        let p = player
        for r in raiders {
            r.hurt -= dt; r.cd -= dt
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
                    g.hp -= 2; g.shake = 0.15
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
            var tx = WELL_X
            var act = Act.none
            let inside = r.x > TOWN.0 && r.x < TOWN.1
            let victim = folk.first { !$0.hidden && $0.role != .guard && abs($0.x - r.x) < 60 }
            if abs(p.x - r.x) < 110 { tx = p.x; act = .rob } else if let v = victim { tx = v.x; act = .victim(v) } else if inside {
                let b = bs.filter { $0.level > 0 && $0.def.pay > 0 && !$0.robbed }.min { abs($0.x - r.x) < abs($1.x - r.x) }
                if let b = b { tx = b.mid; act = .building(b) }
            }
            if stepTo(r, tx, r.speed, dt) || abs(r.x - tx) < 7 {
                switch act {
                case .rob:
                    if p.coins == 0 { gameOver() } else {
                        let n = min(p.coins, r.rob)
                        p.coins -= n; r.loot += n; r.state = .flee
                        shake = 0.35
                        snd?.rob()
                        hint("hit")
                        dust(p.x, 12, 6, GOLD)
                    }
                case .none:
                    if abs(r.x - WELL_X) < 8 { r.state = .flee }
                case .victim(let v):
                    folk.removeAll { $0 === v }
                    nightLost += 1
                    dust(v.x, 6, 8)
                    snd?.rob()
                    hint("mug")
                    r.state = .flee
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
            if a.h < 26 { hitR = raiders.first { !$0.dead && abs($0.x - a.x) < 7 && (a.mine || $0.state == .raid) } }
            if let r = hitR {
                hurt(r, a.vx)
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
    }

    func gameOver() {
        if state == .over { return }
        state = .over
        snd?.rob()
    }

    func updWorld(_ dt: Double) {
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

    // ---------- set scenes for the simulator screenshots
    func demo(_ k: String) {
        start()
        hintT = 0; cardT = 0
        let setup: [(BType, Int)] = [(.market, 2), (.tea, 1), (.well, 1), (.gw, 2), (.ge, 1), (.guard, 1)]
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
            raiders.append(Raider(id: 901, kind: .rider, x: B(.gw).x - 90, side: -1, hp: 3))
        } else {
            t = 0.3
            player.x = tp.mid - 30
            let pen = B(.pen); pen.building = true; pen.paid = 6; pen.need = 5.7; pen.progress = 2.5
        }
        cam = clampD(player.x - W / 2 + player.dir * 24, 0, WORLD - W)
    }
}
