import Foundation

enum GState { case title, play }

/// The rules of Dustfall III: ride, toss coins, hire drifters, rebuild, hold the gates at night, and take the train on down the line.
final class Game {
    var W = 400.0
    var H = 185.0
    var GY = 150.0
    var state = GState.title
    var t = 0.6                 // time of day, 0 to 1; dusk is at 0.72
    var day = 1
    var clock = 0.0
    var cam = FIRE_X - 205

    // the rider
    var px = FIRE_X - 20
    var pvx = 0.0
    var pdir = -1.0
    var pphase = 0.0
    var coins = 10
    var tossCD = 0.0
    var tossT = 0.0
    var ammo = 6
    var reloadT = 0.0
    var gunCD = 0.0
    var gunT = 0.0
    var hurtT = 0.0
    var input = Input()
    private var hoofT = 0.0

    // where on the line this is, and what is in the bank
    var town = 0
    var day0 = 0                // the day you stepped off here, so `day - day0` counts days in this town
    var bank = 0
    var train: Train?
    var tripT = -1.0            // seconds since the train pulled out with you on it; under 0 when you are not aboard
    var fade = 0.0
    var onSave: (() -> Void)?
    var townName: String { return TOWN_NAMES[town % TOWN_NAMES.count] }

    var store = Building(.store, 1108)
    var saloon = Building(.saloon, 1240)
    var sheriff = Building(.sheriff, 1400)
    var stable = Building(.stable, 1590)
    var bankB = Building(.bank, 1020)
    var gateW = Building(.gateW, 958)
    var gateE = Building(.gateE, 1940)
    var station = Building(.station, 1700)
    var ticket = Building(.train, STOP + 83)
    var b: [Building] = []
    var drifters: [Drifter] = []
    var folk: [Folk] = []
    var bandits: [Bandit] = []
    var shots: [Shot] = []
    var parts: [Part] = []
    var flying: [Coin] = []
    var ground: [GCoin] = []
    var boxes: [Box] = []
    var raid: [RaidSpawn] = []
    let camps: [(Double, Int)] = [(120, 3), (700, 2), (2210, 2), (2640, 3)]

    var side = 1.0
    var duskDone = false
    var raidOn = false
    var badgePaid = 0
    var pickPaid = 0
    var shake = 0.0
    var flash = 0.0

    var hintText = ""
    var hintT = 0.0
    private var seen: Set<String> = []
    var info = ""
    var slotsFor: Building?
    var sfx: Sound?

    init() { reset() }

    func reset() {
        state = .title
        town = 0; day = 1; day0 = 0; t = 0.6; clock = 0
        coins = 10; bank = 0
        hintText = ""; hintT = 0; seen = []
        layTown()
    }

    /// Lays out the town at this stop on the line: everything boarded up, drifters at the camps, strongboxes buried.
    /// The first town has a store, saloon, sheriff and station; the stable and bank come from the second town on.
    private func layTown() {
        px = FIRE_X - 20; pvx = 0; pdir = -1; pphase = 0
        tossCD = 0; ammo = 6; reloadT = 0; gunCD = 0; gunT = 0; hurtT = 0
        cam = FIRE_X - W / 2
        store = Building(.store, 1108); saloon = Building(.saloon, 1240); sheriff = Building(.sheriff, 1400)
        stable = Building(.stable, 1590); bankB = Building(.bank, 1020)
        gateW = Building(.gateW, 958); gateE = Building(.gateE, 1940)
        station = Building(.station, 1700); ticket = Building(.train, STOP + 83)
        b = [store, saloon, sheriff]
        if town > 0 { b.append(stable); b.append(bankB) }
        b.append(station); b.append(gateW); b.append(gateE); b.append(ticket)
        for bl in b { bl.scale = 1 + 0.25 * Double(town) }
        ticket.live = false
        train = nil; tripT = -1; fade = 0
        drifters = []; folk = []; bandits = []; shots = []; parts = []; flying = []; ground = []; raid = []
        for (i, c) in camps.enumerated() {
            for k in 0..<c.1 { drifters.append(Drifter(x: c.0 - 14 + Double(k) * 13 + rnd(-2, 2), camp: i)) }
        }
        boxes = [Box(250, 6 + town), Box(610, 4), Box(2270, 4), Box(2540, 6 + town)]
        side = chance(0.5) ? 1 : -1
        duskDone = false; raidOn = false; badgePaid = 0; pickPaid = 0; shake = 0; flash = 0
        info = ""; slotsFor = nil
    }

    func start() {
        reset()
        state = .play
        hint("start", "Dustfall burned years ago. Ride with the stick, and hold the coin button to toss coins at drifters and at the boarded-up buildings.")
    }

    // ---------- saving
    func snapshot() -> SaveData {
        // coins part-paid into something count as still in the purse
        var purse = coins + badgePaid + pickPaid
        for bl in b { purse += bl.paid + bl.incoming }
        var sb: [SaveB] = []
        for bl in b { sb.append(SaveB(type: bl.type.rawValue, level: bl.level, building: bl.building, progress: bl.progress, hp: bl.hp, robbed: bl.robbed)) }
        var sf: [SaveF] = []
        for f in folk { sf.append(SaveF(x: f.x, role: f.role == .deputy ? 1 : (f.role == .miner ? 2 : 0))) }
        var dr: [Int] = []
        for i in 0..<camps.count { dr.append(drifters.filter { $0.camp == i }.count) }
        var bx: [Bool] = []
        for q in boxes { bx.append(q.open) }
        return SaveData(town: town, day: day, day0: day0, t: t, coins: purse, bank: bank, ammo: ammo, px: px, side: side,
                        train: train != nil, b: sb, folk: sf, drifters: dr, boxes: bx, seen: Array(seen))
    }

    /// Picks a saved game up again. A game saved at night comes back at dusk the same night.
    func restore(_ s: SaveData) {
        reset()
        town = max(0, s.town); day = max(1, s.day); day0 = s.day0
        layTown()
        coins = max(0, s.coins); bank = max(0, s.bank); ammo = max(0, min(6, s.ammo))
        if ammo == 0 { ammo = 6 }
        t = s.t >= 0.72 ? 0.715 : clampD(s.t, 0, 1)
        side = s.side < 0 ? -1 : 1
        seen = Set(s.seen)
        for sb in s.b {
            guard let bl = b.first(where: { $0.type.rawValue == sb.type }) else { continue }
            bl.level = max(0, min(bl.maxLevel, sb.level)); bl.building = sb.building && bl.level < bl.maxLevel
            bl.progress = clampD(sb.progress, 0, 1); bl.hp = sb.hp; bl.robbed = sb.robbed
        }
        folk = []
        for sf in s.folk {
            let f = Folk(x: sf.x)
            f.role = sf.role == 1 ? .deputy : (sf.role == 2 ? .miner : .folk)
            folk.append(f)
        }
        drifters = []
        for (i, c) in camps.enumerated() {
            let n = i < s.drifters.count ? max(0, min(c.1, s.drifters[i])) : c.1
            for k in 0..<n { drifters.append(Drifter(x: c.0 - 14 + Double(k) * 13 + rnd(-2, 2), camp: i)) }
        }
        for (i, bx) in boxes.enumerated() where i < s.boxes.count { bx.open = s.boxes[i] }
        if s.train && station.level > 0 { train = Train(x: STOP, v: 0); ticket.live = true }
        px = clampD(s.px, 30, WORLD - 30)
        cam = clampD(px - W / 2, 0, WORLD - W)
        state = .play
    }

    /// Set scenes for the simulator screenshots.
    func demo(_ name: String) {
        if name == "title" { return }
        start()
        hintT = 0
        if name == "train" { town = 1; day = 9; day0 = 6; layTown(); stable.level = 1; bankB.level = 1; bank = 12 }
        store.level = 1; sheriff.level = 1; saloon.level = 2
        gateW.level = 1; gateW.hp = GHP[1]; gateE.level = 2; gateE.hp = GHP[2]
        drifters.removeAll { $0.camp == 1 }
        for i in 0..<6 { let f = Folk(x: 1180 + Double(i) * 46); folk.append(f) }
        folk[0].role = .deputy; folk[1].role = .deputy; folk[2].role = .miner
        coins = 14; px = 1330; pdir = 1
        if name == "night" {
            day = 5; t = 0.8; duskDone = true; raidOn = true; side = 1
            px = 1880; pdir = 1
            for i in 0..<5 { bandits.append(Bandit(x: 1975 + Double(i) * 30, rider: i % 3 == 2, side: 1, hp: 3)) }
            px = 1850; folk[0].x = 1925; folk[1].x = 1916
        } else if name == "train" {
            t = 0.3; station.level = 1; train = Train(x: STOP, v: 0); ticket.live = true
            ticket.paid = 3; px = STOP + 96; pdir = -1
        } else {
            day = 3; t = 0.4; station.paid = 6; px = 1690
            for i in 0..<5 { ground.append(GCoin(x: 1150 + Double(i) * 7, y: 0, vx: 0, vy: 0, age: 1)) }
        }
        cam = clampD(px - W / 2, 0, WORLD - W)
    }

    /// How dark it is: 0 by day, 1 in the middle of the night.
    func dark() -> Double {
        if t < 0.05 { return 1 - t / 0.05 }
        return smooth(0.66, 0.76, t)
    }

    func hint(_ key: String, _ text: String, again: Bool = false) {
        if !again && seen.contains(key) { return }
        seen.insert(key)
        hintText = text
        hintT = 7
    }

    private func puff(_ x: Double, _ y: Double, _ n: Int, _ c: Col, _ sp: Double = 30) {
        for _ in 0..<n {
            parts.append(Part(x: x, y: y, vx: rnd(-sp, sp), vy: rnd(-sp, sp * 0.2), life: rnd(0.3, 0.7), max: 0.7, c: c, s: rnd(1, 2), grav: 60))
        }
    }

    private func dropCoin(_ x: Double, _ h: Double = 8) {
        ground.append(GCoin(x: x + rnd(-6, 6), y: h, vx: rnd(-22, 22), vy: rnd(40, 80), age: 0))
    }

    func rackX(_ bl: Building) -> Double { return bl.type == .store ? bl.x - 12 : bl.x + bl.def.w + 8 }

    // ---------- one frame
    func update(_ dt: Double) {
        clock += dt
        if state != .play { return }
        let was = t
        t += dt / DAY_LEN
        if was < 0.72 && t >= 0.72 && !duskDone { dusk() }
        if t >= 1 { t -= 1; day += 1; dawn() }
        if hintT > 0 { hintT -= dt }
        shake = max(0, shake - dt * 3)
        flash = max(0, flash - dt * 3)
        if tripT < 0 && fade > 0 { fade = max(0, fade - dt * 0.7) }
        updTrain(dt)
        updPlayer(dt)
        updCoins(dt)
        updFolk(dt)
        updBuild(dt)
        updRaid(dt)
        updBandits(dt)
        updShots(dt)
        updParts(dt)
        updInfo()
        let want = clampD(px + pdir * 26 - W / 2, 0, WORLD - W)
        cam += (want - cam) * min(1, dt * 4)
        let mode = !bandits.isEmpty ? 3 : (dark() > 0.6 ? 2 : (t > 0.6 ? 1 : 0))
        sfx?.music(clock, mode)
    }

    private func updPlayer(_ dt: Double) {
        if tripT >= 0 { pvx = 0; return }       // aboard the train
        let want = input.stick * 84 * (1 + 0.15 * Double(town > 0 ? stable.level : 0))
        pvx += (want - pvx) * min(1, dt * 7)
        if abs(pvx) < 2 && input.stick == 0 { pvx = 0 }
        px = clampD(px + pvx * dt, 30, WORLD - 30)
        if abs(input.stick) > 0.1 { pdir = input.stick > 0 ? 1 : -1 }
        if abs(pvx) > 6 {
            pphase += dt * abs(pvx) * 0.16
            hoofT -= dt * abs(pvx) / 84
            if hoofT <= 0 { hoofT = 0.17; sfx?.hoof(0.6) }
            if chance(dt * 8) { parts.append(Part(x: px - pdir * 8, y: 0, vx: -pdir * rnd(4, 14), vy: rnd(-14, -4), life: 0.5, max: 0.5, c: Col(0xe2c08c, 0.6), s: rnd(1, 2.4), grav: 10)) }
        }
        tossCD = max(0, tossCD - dt); tossT = max(0, tossT - dt)
        gunCD = max(0, gunCD - dt); gunT = max(0, gunT - dt); hurtT = max(0, hurtT - dt)
        if reloadT > 0 { reloadT -= dt; if reloadT <= 0 { ammo = 6; sfx?.reload() } }
        // both buttons repeat for as long as they are held
        if input.toss && tossCD <= 0 { toss() }
        if input.fire { fire() }
        // strongboxes break open when the horse rides over them
        for bx in boxes where !bx.open && abs(bx.x - px) < 10 {
            bx.open = true
            for _ in 0..<bx.n { dropCoin(bx.x, 6) }
            puff(bx.x, -6, 8, Col(0x7a5632))
            sfx?.box()
            hint("box", "A strongbox the raiders buried. There are more out past both ends of town.")
        }
    }

    private func atBank() -> Bool {
        return town > 0 && bankB.level > 0 && !bankB.building && abs(px - bankB.cx) < bankB.def.w / 2 + 12
    }

    private func toss() {
        if coins <= 0 {
            if atBank() && bank > 0 {            // an empty purse at the bank: the teller hands five back
                let n = min(5, bank)
                bank -= n
                for k in 0..<n {
                    let c = Coin(sx: bankB.cx, sy: -12, tx: px, ty: -18, kind: 4)
                    c.u = -Double(k) * 0.12
                    flying.append(c)
                }
                sfx?.box(); tossCD = 1.2
                return
            }
            tossCD = 0.5
            sfx?.empty(); hint("broke", "Your purse is empty. Businesses pay out every morning, and strongboxes lie buried out of town.", again: true); return
        }
        tossCD = 0.2; tossT = 0.25
        let sy = -22.0
        // 1: a drifter at his fire
        var bestD: Drifter?
        var bd = 30.0
        for d in drifters where !d.taken {
            let dd = abs(d.x - px)
            if dd < bd { bd = dd; bestD = d }
        }
        if let d = bestD {
            d.taken = true
            let c = Coin(sx: px, sy: sy, tx: d.x, ty: -10, kind: 2); c.drifter = d
            flying.append(c); coins -= 1; sfx?.toss(); return
        }
        // 2: the racks beside the sheriff's office and the store
        let sh = sheriff, st = store
        if sh.level > 0 && !sh.building && abs(px - rackX(sh)) < 12 {
            if folk.contains(where: { $0.role == .folk }) {
                flying.append(Coin(sx: px, sy: sy, tx: rackX(sh), ty: -14, kind: 3)); coins -= 1; sfx?.toss()
            } else { tossCD = 0.5; sfx?.empty(); hint("nofolk", "A badge needs someone to wear it. Hire a drifter first.", again: true) }
            return
        }
        if st.level > 0 && !st.building && abs(px - rackX(st)) < 12 {
            if folk.contains(where: { $0.role == .folk }) {
                flying.append(Coin(sx: px, sy: sy, tx: rackX(st), ty: -14, kind: 5)); coins -= 1; sfx?.toss()
            } else { tossCD = 0.5; sfx?.empty(); hint("nofolk", "A pick needs someone to swing it. Hire a drifter first.", again: true) }
            return
        }
        // 3: an open bank keeps what you toss it
        if atBank() {
            flying.append(Coin(sx: px, sy: sy, tx: bankB.cx, ty: -14, kind: 6)); coins -= 1; sfx?.toss(); return
        }
        // 4: a building that can take coins, or the passenger car
        var best: Building?
        var bb = 9999.0
        for bl in b where bl.payable && bl.paid + bl.incoming < bl.cost {
            let dd = abs(bl.cx - px)
            if dd < bl.def.w / 2 + 12 && dd < bb { bb = dd; best = bl }
        }
        if let bl = best {
            bl.incoming += 1
            let c = Coin(sx: px, sy: sy, tx: bl.cx, ty: -bl.def.h - 10, kind: 1); c.bld = bl
            flying.append(c); coins -= 1; sfx?.toss(); return
        }
        // 5: nothing here wants it, so it lands in the dust
        flying.append(Coin(sx: px, sy: sy, tx: px + pdir * 18, ty: -1, kind: 0)); coins -= 1; sfx?.toss()
    }

    private func fire() {
        if reloadT > 0 || gunCD > 0 { return }
        if ammo <= 0 { sfx?.click(); gunCD = 0.4; return }
        ammo -= 1; gunCD = 0.28; gunT = 0.14
        shots.append(Shot(x: px + pdir * 12, y: -20, vx: pdir * 300, life: 0.5, mine: true))
        sfx?.gun(1); shake = max(shake, 0.4)
        parts.append(Part(x: px + pdir * 14, y: -20, vx: pdir * 20, vy: -6, life: 0.25, max: 0.25, c: Col(0xfff0b0), s: 2.5, grav: 0))
        if ammo == 0 { reloadT = Double(max(1, 5 - store.level)) }      // every level of the store takes a second off
    }

    private func updCoins(_ dt: Double) {
        var i = 0
        while i < flying.count {
            let c = flying[i]
            if c.kind == 4 { c.tx = px; c.ty = -18 }
            c.u += dt / 0.42
            if c.u >= 1 { land(c); flying.remove(at: i) } else { i += 1 }
        }
        i = 0
        while i < ground.count {
            var g = ground[i]
            g.age += dt
            if g.y > 0 || g.vy > 0 {
                g.vy -= 260 * dt; g.y += g.vy * dt; g.x += g.vx * dt
                if g.y <= 0 { g.y = 0; if g.vy < -40 { g.vy = -g.vy * 0.35 } else { g.vy = 0; g.vx = 0 } }
            }
            if g.age > 0.45 && abs(g.x - px) < 13 {
                coins += 1; sfx?.pick(); ground.remove(at: i); continue
            }
            ground[i] = g
            i += 1
        }
        // coins part-paid into a building come back when you ride away
        for bl in b where bl.paid > 0 && !bl.building && bl.incoming == 0 && abs(bl.cx - px) > bl.def.w / 2 + 44 {
            for k in 0..<bl.paid {
                let c = Coin(sx: bl.cx, sy: -bl.def.h - 10, tx: px, ty: -18, kind: 4)
                c.u = -Double(k) * 0.12
                flying.append(c)
            }
            bl.paid = 0
            hint("refund", "Coins you left on an unfinished job come back to you when you ride off.")
        }
        if badgePaid > 0 && abs(px - rackX(sheriff)) > 60 { for _ in 0..<badgePaid { flying.append(Coin(sx: rackX(sheriff), sy: -14, tx: px, ty: -18, kind: 4)) }; badgePaid = 0 }
        if pickPaid > 0 && abs(px - rackX(store)) > 60 { for _ in 0..<pickPaid { flying.append(Coin(sx: rackX(store), sy: -14, tx: px, ty: -18, kind: 4)) }; pickPaid = 0 }
    }

    private func land(_ c: Coin) {
        switch c.kind {
        case 1:
            guard let bl = c.bld else { return }
            bl.incoming = max(0, bl.incoming - 1)
            bl.paid += 1; bl.flash = 0.3; sfx?.slot()
            if bl.paid >= bl.cost && bl.virt {
                bl.paid = 0; bl.live = false; board()
            } else if bl.paid >= bl.cost {
                bl.paid = 0; bl.building = true; bl.progress = 0
                sfx?.recruit()
                if folk.isEmpty { hint("nobuild", "Paid for, but nobody is here to build it. Toss a coin to a drifter at a campfire out of town.", again: true) }
                else { hint("build", "Paid in full. Your townsfolk will build it; more hands build faster.") }
            }
        case 2:
            guard let d = c.drifter else { return }
            drifters.removeAll { $0 === d }
            let f = Folk(x: d.x)
            f.tx = FIRE_X + rnd(-60, 60)
            folk.append(f)
            sfx?.recruit()
            puff(d.x, -8, 6, GOLD)
            hint("hire", "He takes the coin and walks to town. Townsfolk build what you pay for, and leave a coin each morning.")
        case 3:
            badgePaid += 1; sfx?.slot()
            if badgePaid >= 2 {
                badgePaid = 0
                if let f = nearestIdle(rackX(sheriff)) { f.role = .deputy; sfx?.fanfare(); hint("deputy", "A deputy. At night he stands at the gate the raiders are coming to, and shoots.") }
            }
        case 5:
            pickPaid += 1; sfx?.slot()
            if pickPaid >= 2 {
                pickPaid = 0
                if let f = nearestIdle(rackX(store)) { f.role = .miner; sfx?.fanfare(); hint("miner", "A prospector. He works the old mine west of town and brings a coin back each morning.") }
            }
        case 6:
            bank += 1; sfx?.slot(); bankB.flash = 0.2
            hint("deposit", "Banked. Raiders cannot knock banked coins out of you, and the bank pays 1 a day for every 8 inside, up to 3.")
        case 4:
            coins += 1; sfx?.pick()
        default:
            ground.append(GCoin(x: c.tx, y: 0, vx: 0, vy: 0, age: 0))
        }
    }

    private func nearestIdle(_ x: Double) -> Folk? {
        var best: Folk?
        var bd = 99999.0
        for f in folk where f.role == .folk {
            let d = abs(f.x - x)
            if d < bd { bd = d; best = f }
        }
        return best
    }

    /// The one site the crew is working: the first paid-for building in the town's order.
    func site() -> Building? { return b.first { $0.building } }

    private func updFolk(_ dt: Double) {
        let s = site()
        let night = dark() > 0.4 || !bandits.isEmpty
        var dep = 0
        var plain = 0
        for f in folk {
            f.work = false
            f.shotCD = max(0, f.shotCD - dt)
            switch f.role {
            case .deputy:
                if night {
                    f.tx = side < 0 ? 976 + Double(dep) * 9 : 1930 - Double(dep) * 9
                    var tgt: Bandit?
                    var bd = 110.0
                    for bn in bandits where bn.st != 3 {
                        let d = abs(bn.x - f.x)
                        if d < bd { bd = d; tgt = bn }
                    }
                    if let bn = tgt, f.shotCD <= 0, abs(f.x - f.tx) < 30 {
                        f.shotCD = rnd(1.3, 1.9)
                        f.dir = bn.x > f.x ? 1 : -1
                        shots.append(Shot(x: f.x + f.dir * 4, y: -9, vx: f.dir * 300, life: abs(bn.x - f.x) / 300, mine: false))
                        sfx?.gun(0.5)
                        if chance(0.7) { hurt(bn, 1) }
                    }
                } else if f.wait <= 0 && !f.moving { f.tx = sheriff.cx + rnd(-50, 50); f.wait = rnd(3, 8) }
                dep += 1
            case .miner:
                if t > 0.06 && t < 0.6 { f.tx = MINE_X + Double(Int(f.seed) % 5) * 6 } else { f.tx = store.x + 20 + Double(Int(f.seed) % 4) * 8 }
            case .folk:
                if let st = s {
                    f.tx = st.x + 6 + Double(plain % 5) * (st.def.w - 12) / 5
                    if abs(f.x - f.tx) < 3 { f.work = true }
                } else if f.wait <= 0 && !f.moving { f.tx = FIRE_X + rnd(-150, 150); f.wait = rnd(2, 7) }
                plain += 1
            }
            f.wait = max(0, f.wait - dt)
            let d = f.tx - f.x
            f.moving = abs(d) > 2
            if f.moving {
                f.dir = d > 0 ? 1 : -1
                f.x += f.dir * (night && f.role == .deputy ? 52 : 34) * dt
                f.phase += dt * 9
            }
        }
    }

    private func updBuild(_ dt: Double) {
        for bl in b { bl.flash = max(0, bl.flash - dt) }
        guard let bl = site() else { return }
        let hands = min(folk.filter { $0.work }.count, 5)
        if hands == 0 { return }
        bl.progress += dt * (bl.def.gate ? 0.063 : 0.0245) * Double(hands)
        if chance(dt * 3 * Double(hands)) {
            sfx?.hammer(clampD(1 - abs(bl.cx - px) / 300, 0, 1))
            puff(bl.x + rnd(0, bl.def.w), -rnd(2, bl.def.h), 2, Col(0xe2c08c), 16)
        }
        if bl.progress >= 1 {
            bl.building = false; bl.progress = 0; bl.level += 1
            if bl.def.gate { bl.hp = GHP[min(bl.level, 3)] }
            sfx?.fanfare(); flash = 0.4
            puff(bl.cx, -bl.def.h / 2, 16, GOLD, 50)
            switch bl.type {
            case .store: hint("store1", "The store is open and pays out every morning. Toss two coins at the pick outside it to send a townsman prospecting.")
            case .saloon: hint("saloon1", "The saloon is open. It pays out every morning and draws new drifters to the camps.")
            case .sheriff: hint("sheriff1", "The sheriff's office is open. Toss two coins at the badge outside it to make a deputy.")
            case .gateW, .gateE: hint("gate1", "A gate. Raiders have to break it down before they can reach the town.")
            case .stable: hint("stable\(bl.level)", "The stable is open, and you ride a faster horse.", again: true)
            case .bank: hint("bank1", "The bank is open. Hold the coin button in front of it to pay coins in, where raiders cannot get them.")
            case .station:
                train = Train(x: WORLD + 70, v: -120)
                sfx?.whistle()
                hint("station1", "The station is up, and the rails are through. Here comes the train.", again: true)
            default: hint("built", "Built. Toss more coins at it to improve it.")
            }
            onSave?()
        }
    }

    // ---------- night
    private func raidSize(_ d: Int) -> Int {
        if d < 2 { return 0 }
        return min(d - 1 + max(0, d - 5) + town, 12 + town * 2 + max(0, d - 9), 40)
    }

    private func dusk() {
        duskDone = true
        let d = day - day0 + town         // every town down the line starts a night harder
        let n = raidSize(d)
        if n == 0 { hint("dusk1", "Night is coming. The first night is quiet; raiders come from the second."); return }
        for i in 0..<n {
            raid.append(RaidSpawn(t: 0.74 + rnd(0, 0.09), side: i % 2 == 1 ? side : -side, rider: d >= 4 && i % 3 == 2, hp: d / 4))
        }
        raidOn = true
        sfx?.sting()
        hint("raid", "Raiders tonight, most from the \(side < 0 ? "west" : "east"). Hold the gun button to shoot the way you face.", again: true)
    }

    private func dawn() {
        duskDone = false; raidOn = false; raid = []
        for bn in bandits { bn.st = 3 }
        var total = 0
        for bl in b where bl.def.pay > 0 && bl.level > 0 {
            if bl.robbed { bl.robbed = false; continue }
            let n = max(1, bl.def.pay * bl.level - (day - day0 > 2 ? 1 : 0))
            for _ in 0..<n { dropCoin(bl.x + bl.def.doorX + bl.def.doorW / 2, 10) }
            total += n
        }
        let plain = folk.filter { $0.role == .folk }.count
        for _ in 0..<(plain / 2) { dropCoin(FIRE_X + rnd(-20, 20), 6); total += 1 }
        for f in folk where f.role == .miner { dropCoin(store.x + 30, 8); total += 1; f.wait = 0 }
        if town > 0 { bank += min(3 * bankB.level, bank / 8) }
        // the saloon draws drifters back to the camps
        for (i, c) in camps.enumerated() {
            let here = drifters.filter { $0.camp == i }.count
            if here < c.1 && (saloon.level > 0 || chance(0.3)) {
                drifters.append(Drifter(x: c.0 - 14 + Double(here) * 13 + rnd(-2, 2), camp: i))
            }
        }
        side = chance(0.5) ? 1 : -1
        sfx?.dawn()
        hint("dawn\(day)", total > 0 ? "Day \(day). The town paid out \(total) coins this morning: ride past to pick them up." : "Day \(day). Nothing paid out this morning. Open the store or the saloon.", again: true)
        onSave?()
    }

    // ---------- the railroad: the train rolls in once the station is up and waits for you to buy a ticket
    private func smoke(_ x: Double) {
        parts.append(Part(x: x, y: -34, vx: rnd(-5, 5), vy: rnd(-16, -8), life: 1.3, max: 1.3, c: Col(0xcfc6ba, 0.7), s: rnd(2, 4), grav: -5))
    }

    /// How many coins step off the train with you: half of purse and bank together, never under 8 nor over 25.
    func carryOut() -> Int { return max(8, min(25, (coins + bank) / 2)) }

    private func updTrain(_ dt: Double) {
        guard var tr = train else { return }
        if tripT >= 0 {
            tripT += dt
            fade = clampD(tripT / 2.2, 0, 1)
            tr.x += tripT * tripT * 26 * dt
            tr.chuff -= dt * (2 + tripT * 4)
            if tr.chuff <= 0 { tr.chuff = 1; sfx?.chuff(1); smoke(tr.x + 16) }
            train = tr
            if tripT > 2.6 { arrive() }
            return
        }
        if tr.v == 0 {
            if chance(dt * 1.2) { smoke(tr.x + 16) }
            if tr.wait > 0 {
                tr.wait -= dt
                if tr.wait <= 0 {
                    ticket.live = true
                    hint("ticket", "The railroad is here. The train will wait as long as you like: finish the town if you want to, then toss \(ticket.cost) coins at the passenger car to ride on to the next ghost town.", again: true)
                    train = tr
                    onSave?()
                    return
                }
            }
            train = tr
            return
        }
        tr.v = -clampD((tr.x - STOP) * 1.1, 10, 120)
        tr.x += tr.v * dt
        tr.chuff -= dt * (1 + abs(tr.v) / 30)
        if tr.chuff <= 0 { tr.chuff = 1; sfx?.chuff(clampD(1 - abs(tr.x - px) / 500, 0.15, 1)); smoke(tr.x + 16) }
        if tr.x <= STOP + 0.5 { tr.x = STOP; tr.v = 0; tr.wait = 1.5; sfx?.whistle(); flash = 0.2 }
        train = tr
    }

    /// The ticket is paid: the train pulls out east with you aboard.
    private func board() {
        tripT = 0
        sfx?.whistle()
        hintT = 0
        bandits = []; raid = []; raidOn = false
    }

    /// Stepping off at the next dead town. Only coins make the trip; the town you built stays behind.
    private func arrive() {
        let carry = carryOut()
        town += 1; day += 1; day0 = day - 1; t = 0.08
        layTown()
        coins = carry; bank = 0
        fade = 1
        let extra = town == 1 ? " This town has a stable and a bank to open as well." : ""
        hint("arrive\(town)", "\(nice(townName)). You step off with \(carry) coins, and everything here is boarded up. Prices and raids are both a little stiffer down the line.\(extra)", again: true)
        onSave?()
    }

    private func updRaid(_ dt: Double) {
        var i = 0
        while i < raid.count {
            if t >= raid[i].t {
                let r = raid[i]
                let x = r.side < 0 ? 600 - rnd(0, 120) : 2300 + rnd(0, 120)
                bandits.append(Bandit(x: x, rider: r.rider, side: r.side, hp: (r.rider ? 3 : 2) + r.hp))
                raid.remove(at: i)
            } else { i += 1 }
        }
    }

    private func hurt(_ bn: Bandit, _ n: Int) {
        bn.hp -= n; bn.flash = 0.15
        puff(bn.x, -10, 4, Col(0x8a2b22), 26)
        sfx?.hit(clampD(1 - abs(bn.x - px) / 260, 0.2, 1))
    }

    private func updBandits(_ dt: Double) {
        var i = 0
        while i < bandits.count {
            let bn = bandits[i]
            if bn.hp <= 0 {
                if chance(0.35) { dropCoin(bn.x, 8) }
                for _ in 0..<bn.loot { dropCoin(bn.x, 8) }
                puff(bn.x, -8, 8, Col(0x3a2a1c), 34)
                bandits.remove(at: i); continue
            }
            bn.flash = max(0, bn.flash - dt); bn.hitT = max(0, bn.hitT - dt)
            let sp = bn.rider ? 74.0 : 40.0
            let gate = bn.side < 0 ? gateW : gateE
            let gx = gate.cx
            switch bn.st {
            case 1:
                if gate.level == 0 { bn.st = 0 } else {
                    gate.hp -= dt * (bn.rider ? 1.5 : 1)
                    bn.t += dt
                    if bn.t > 0.6 { bn.t = 0; sfx?.gate(clampD(1 - abs(gx - px) / 300, 0, 1)); gate.flash = 0.15; puff(gx, -8, 2, Col(0x7a5632), 20) }
                    if gate.hp <= 0 {
                        gate.level = 0; gate.hp = 0; gate.paid = 0
                        puff(gx, -10, 18, Col(0x7a5632), 60); shake = 1
                        hint("gatedown", "A gate is down. Pay to raise it again, and make it stronger.", again: true)
                    }
                }
            case 2:
                bn.t += dt
                if bn.t > 2.4, let tg = bn.target {
                    if !tg.robbed && tg.level > 0 { tg.robbed = true; bn.loot = 2; sfx?.rob(); hint("robbed", "A raider robbed a business. It will pay nothing in the morning unless you shoot him before he gets away.", again: true) }
                    bn.st = 3
                }
            case 3:
                bn.x += bn.side * sp * 1.15 * dt
                bn.phase += dt * 10
                if bn.x < 300 || bn.x > 2600 { bandits.remove(at: i); continue }
            default:
                let dir = -bn.side
                let outside = bn.side < 0 ? bn.x < gx - 9 : bn.x > gx + 9
                if outside && gate.level > 0 && abs(bn.x - gx) < 13 { bn.st = 1; bn.t = 0 } else {
                    var tx = FIRE_X
                    if !outside {
                        if bn.target == nil || bn.target!.robbed || bn.target!.level == 0 {
                            var best: Building?
                            var bd = 99999.0
                            for bl in b where bl.def.pay > 0 && bl.level > 0 && !bl.robbed {
                                let d = abs(bl.cx - bn.x)
                                if d < bd { bd = d; best = bl }
                            }
                            bn.target = best
                        }
                        if let tg = bn.target { tx = tg.x + tg.def.doorX + tg.def.doorW / 2 }
                        if abs(bn.x - tx) < 4 {
                            if bn.target != nil { bn.st = 2; bn.t = 0 } else { bn.st = 3 }
                        }
                    }
                    let d2 = outside ? dir : sgn(tx - bn.x)
                    bn.x += d2 * sp * dt
                    bn.phase += dt * (bn.rider ? 12 : 9)
                }
            }
            // riding into one costs you coins from your purse
            if bn.st != 3 && bn.hitT <= 0 && abs(bn.x - px) < 9 && hurtT <= 0 {
                let n = min(coins, bn.rider ? 4 : 3)
                coins -= n
                for _ in 0..<n { dropCoin(px, 14) }
                bn.hitT = 2; hurtT = 1.2; shake = 1; flash = 0.3; sfx?.hit(1)
                hint("knock", "A raider knocked coins out of your purse. Keep your distance and shoot.")
            }
            i += 1
        }
    }

    private func updShots(_ dt: Double) {
        var i = 0
        while i < shots.count {
            var s = shots[i]
            s.x += s.vx * dt; s.life -= dt
            var gone = s.life <= 0
            if s.mine && !gone {
                for bn in bandits where abs(bn.x - s.x) < 8 && bn.hp > 0 {
                    hurt(bn, 1); gone = true; break
                }
            }
            if gone { shots.remove(at: i) } else { shots[i] = s; i += 1 }
        }
    }

    private func updParts(_ dt: Double) {
        var i = 0
        while i < parts.count {
            var p = parts[i]
            p.life -= dt
            if p.life <= 0 { parts.remove(at: i); continue }
            p.vy += p.grav * dt; p.x += p.vx * dt; p.y += p.vy * dt
            if p.y > 0 { p.y = 0; p.vy = 0 }
            parts[i] = p
            i += 1
        }
        if parts.count > 260 { parts.removeFirst(parts.count - 260) }
    }

    /// The line at the bottom of the screen: what the rider is standing at.
    private func updInfo() {
        info = ""; slotsFor = nil
        for d in drifters where abs(d.x - px) < 30 && !d.taken { info = "Drifter: 1 coin to hire"; return }
        let sh = sheriff, st = store
        if sh.level > 0 && !sh.building && abs(px - rackX(sh)) < 12 { info = "Deputy's badge: 2 coins (\(badgePaid) in). Needs a townsman without a job."; return }
        if st.level > 0 && !st.building && abs(px - rackX(st)) < 12 { info = "Prospector's pick: 2 coins (\(pickPaid) in). Needs a townsman without a job."; return }
        var best: Building?
        var bd = 9999.0
        for bl in b where !bl.virt || bl.live {
            let d = abs(bl.cx - px)
            if d < bl.def.w / 2 + 12 && d < bd { bd = d; best = bl }
        }
        guard let bl = best else { return }
        if bl.virt {
            slotsFor = bl
            info = "Train ticket: \(bl.cost) coins" + (bl.paid > 0 ? " (\(bl.paid) in)" : "") + ". You step off at the next town with \(carryOut()): half of purse and bank, never under 8 or over 25."
            return
        }
        if bl.type == .bank && bl.level > 0 && !bl.building {
            info = "Bank: \(bank) inside, safe from raiders. Hold the coin button to pay in; with an empty purse it hands 5 back."
            return
        }
        if bl.type == .station && bl.level > 0 && !bl.building {
            info = train == nil ? "Station: the train is on its way." : "Station: the train waits as long as you like. The ticket is paid at the passenger car."
            return
        }
        let nm = String(bl.def.name.prefix(1)) + String(bl.def.name.dropFirst()).lowercased()
        if bl.building {
            info = site() === bl ? "\(nm): being built. More townsfolk build it faster." : "\(nm): paid for. The crew starts here when the job in hand is finished."
        } else if bl.level >= bl.maxLevel {
            info = "\(nm): as good as it gets." + (bl.def.pay > 0 ? " Pays out every morning." : "")
        } else {
            slotsFor = bl
            let verb = bl.level == 0 ? (bl.def.gate ? "to raise" : (bl.type == .station ? "to rebuild, and bring the railroad" : "to open")) : "to improve"
            info = "\(nm): \(bl.cost) coins \(verb)" + (bl.paid > 0 ? " (\(bl.paid) in)" : "") + (bl.level > 0 && bl.def.pay > 0 ? ". Pays out every morning." : "")
        }
    }
}
