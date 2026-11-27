import Foundation

enum GState { case title, intro, play }

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
    var dawnRows: [(String, Int)] = []      // this morning's takings, source by source
    var dawnTotal = 0
    var dawnSeq = 0
    var shotDir = 1.0               // which way the last shot went
    var zoom = 1.0                  // the picture drawn larger about the rider, for the opening
    var onBuzz: ((Int) -> Void)?       // 0 a tick, 1 a knock, 2 a thump
    private func buzz(_ n: Int) { onBuzz?(n) }
    var place = "dustfall"      // which of the places at this stage of the line
    var log: [String] = []      // the places behind you, in order
    var choosing = false        // the train has stopped at a fork and is waiting for you to pick

    // the stage line, wanted men, floods, duels and strays
    var coach: Coach?
    var coachSlot = Building(.coach, 1196)
    var owed = 0                // what the stage line pays you at dawn
    var outlaw: Outlaw?
    var flood = 0               // the last day the wash east of town runs full
    var duelDay = 0
    var duel: Duel?
    var strays: [Stray] = []
    private var fireWas = false

    // out west and out east: places where coins buy something on the spot
    var sPost = Building(.sPost, -90)
    var sTribe = Building(.sTribe, -250)
    var sRuin = Building(.sRuin, -434)
    var sRig = Building(.sRig, -600)
    var sShow = Building(.sShow, 752)
    var sFort = Building(.sFort, 2470)
    var sRods = Building(.sRods, 992)
    var sTower = Building(.sTower, 1206)
    var sHobo = Building(.sHobo, 3090)
    var sCar = Building(.sCar, 3182)
    var sGallery = Building(.sGallery, 186)
    var gallery: Gallery?
    var galleryDay = -1          // one go at the booth a day
    var unlocked = false         // the line past the first town has been bought
    var payAsk = false           // the train is held at the edge of town while the player is asked
    var rallyOn = false          // the last town is marching on Crane, with you at its head
    var endNow = false           // they have run him out: the ending plays
    var nameSeq = 0              // goes up each time you step off in a town, so its name can be shown
    /// Two coins on the counter: eight shots at a saloon full of things that answer when they are hit, as in the old arcade galleries.
    private func startGallery() {
        var gl = Gallery()
        for k in 0..<4 { gl.targets.append(GTarget(x: 0.08 + Double(k) * 0.05, y: 0.375, kind: 0, pay: 1)) }
        // big and still pays one; small, far or moving pays more
        gl.targets.append(GTarget(x: 0.80, y: 0.52, kind: 1, pay: 1))
        gl.targets.append(GTarget(x: 0.62, y: 0.60, kind: 2, pay: 1))
        gl.targets.append(GTarget(x: 1.55, y: 0.712, kind: 3, pay: 5))
        gl.targets.append(GTarget(x: 0.36, y: 0.70, kind: 4, pay: 2))
        gl.targets.append(GTarget(x: 0.47, y: 0.275, kind: 5, pay: 2))
        gl.targets.append(GTarget(x: 0.355, y: 0.36, kind: 6, pay: 2))
        gl.targets.append(GTarget(x: 0.47, y: 0.56, kind: 7, pay: 1))
        gl.targets.append(GTarget(x: 0.655, y: 0.36, kind: 8, pay: 1))
        gl.targets.append(GTarget(x: 0.30, y: 0.565, kind: 9, pay: 3))
        gl.targets.append(GTarget(x: 1.47, y: 0.40, kind: 10, pay: 4))
        gl.targets.append(GTarget(x: 1.36, y: 0.60, kind: 11, pay: 6))
        gl.targets.append(GTarget(x: 1.21, y: 0.47, kind: 12, pay: 2))
        gl.targets.append(GTarget(x: 1.10, y: 0.50, kind: 13, pay: 4))
        gallery = gl
        pvx = 0
        sfx?.fanfare()
        hintT = 0
    }

    /// The rat only shows now and then.
    func ratOut(_ t: Double) -> Double { return clampD(sin(t * 1.3) * 1.6 - 0.3, 0, 1) }
    /// How far the view has panned across the saloon, in game pixels: left to right and back, slowly.
    func galleryPan(_ t: Double) -> Double { return (GWIDE - 1) * W * (0.5 - 0.5 * cos(t * 0.4)) }
    /// Where a target is right now, in saloon pixels: the rat creeps, the dollar is tossed, the pendulum swings.
    func gpos(_ tg: GTarget, _ t: Double) -> (Double, Double) {
        var x = tg.x * W, y = tg.y * H
        switch tg.kind {
        case 3: x -= ratOut(t) * 9
        case 11: y -= abs(sin(t * 2.4)) * 24
        case 13: x += sin(t * 3.2) * 6
        default: break
        }
        return (x, y)
    }

    private func updGallery(_ dt: Double) {
        guard var gl = gallery else { return }
        gl.t += dt
        gl.flash = max(0, gl.flash - dt)
        for i in gl.targets.indices where gl.targets[i].hit >= 0 { gl.targets[i].hit += dt }
        if (gl.shots == 0 && gl.t - gl.last > 2.2) || gl.t > 45 {
            let n = gl.won
            gallery = nil
            gunCD = 0.6; tossCD = 0.6
            for _ in 0..<n { dropCoin(px, 14) }
            if n > 0 { sfx?.fanfare() }
            hint("gallery", n > 0 ? "\(n) \(n == 1 ? "coin" : "coins") from the shooting gallery. It opens again tomorrow." : "Not a one. The man at the counter says the sights are true.", again: true)
            return
        }
        gallery = gl
    }

    /// A tap on the booth, in game pixels: one shot where you touched.
    func galleryShot(_ x: Double, _ y: Double) {
        guard var gl = gallery, gl.shots > 0, gl.t > 0.5 else { return }
        gl.shots -= 1
        gl.last = gl.t
        gl.flash = 0.08
        sfx?.gun(0.8)
        let reach: [Double] = [7, 14, 12, 6, 7, 7, 9, 13, 9, 5.5, 5, 5, 8, 5]
        let x = x + galleryPan(gl.t)
        var best = -1
        var bd = 99.0
        for (i, tg) in gl.targets.enumerated() where tg.hit < 0 {
            if tg.kind == 3 && ratOut(gl.t) < 0.35 { continue }
            let (tx, ty) = gpos(tg, gl.t)
            let d = ((tx - x) * (tx - x) + (ty - y) * (ty - y)).squareRoot()
            if d < reach[tg.kind] && d < bd { bd = d; best = i }
        }
        if best >= 0 {
            gl.targets[best].hit = 0
            gl.won += gl.targets[best].pay
            switch gl.targets[best].kind {
            case 0: sfx?.box()
            case 1: sfx?.recruit(); sfx?.fanfare()
            case 3: sfx?.pick(); sfx?.ding()
            case 9, 13: sfx?.bell()
            case 10, 11: sfx?.ding(); sfx?.pick()
            case 12: sfx?.box()
            default: sfx?.ding()
            }
            buzz(1)
        } else { gl.holes.append((x, y)) }
        gallery = gl
    }

    var rodsLv = 0
    var towerLv = 0
    var hoboDay = 0
    var carCool = 0
    var carN = 0                // boxcars opened, over the whole game
    var bell = false            // the church bell has been rung: everyone indoors, deputies at the gates until dawn
    var stampDay = 0
    var stampede: (Int, Int)?   // head turned and head lost, while the herd is running
    var ufo: Saucer?
    var ufoAt = 0.0
    var ghostAt = 0.0
    var ghostX: Double?
    var yardX: Double { return EX(2790) }

    // ---------- fire: lightning or a raider's torch sets a roof alight, and the town fights it
    func setFire(_ bl: Building, _ why: String) {
        if bl.burning || bl.level == 0 || bl.building || bl.def.wall == 0 || bl.def.gate || bio == .snow { return }
        bl.fireT = 0; bl.fireHp = 1
        sfx?.box()
        hint("fire", "\(why) the \(bl.label.lowercased()) alight! " + (towerLv > 0 ? "The fire brigade is on it." : "Townsfolk will fight it by hand. A fire brigade, raised at the water tower, would be much faster."), again: true)
    }

    private func updFires(_ dt: Double) {
        for bl in b where bl.burning {
            let hands = Double(folk.filter { $0.role == .folk && !$0.sick && abs($0.x - bl.x) < 420 }.count)
            let top = bl.def.h + Double(max(0, bl.level - 1)) * 5 + 10
            bl.fireT += dt
            bl.fireHp -= dt * (0.016 + hands * 0.011 + (towerLv > 0 ? 0.15 : 0) + rainI() * 0.03)
            if chance(dt * 9) { parts.append(Part(x: bl.x + rnd(4, bl.def.w - 4), y: -top - rnd(2, 8), vx: rnd(6, 14), vy: -rnd(10, 18), life: rnd(1.4, 2.6), max: 2.6, c: Col(0x4e4a48, 0.7), s: rnd(2.5, 4.5), grav: -4)) }
            if (hands > 0 || towerLv > 0) && chance(dt * (towerLv > 0 ? 26 : 5 + hands * 2)) {
                parts.append(Part(x: bl.x + rnd(0, bl.def.w), y: -rnd(4, 10), vx: rnd(-10, 10), vy: -rnd(60, 70 + top * 1.6), life: 0.9, max: 0.9, c: Col(0x9fd0e8), s: 1.6, grav: 200))
            }
            if bl.fireHp <= 0 {
                bl.fireT = -1
                puff(bl.cx, -top, 8, Col(0xe4e8ec), 30)
                hint("fireout", "The fire at the \(bl.label.lowercased()) is out.", again: true)
            } else if bl.fireT > 22 {
                let n = min(4, coins + bank), nb = min(n, bank)
                bank -= nb; coins -= n - nb
                bl.fireT = -1; bl.robbed = true
                puff(bl.cx, -top, 10, Col(0x3a3634), 30)
                hint("gutted", "The \(bl.label.lowercased()) burned out before anyone stopped it. Repairs cost you \(n) coins, and it pays nothing tomorrow.", again: true)
            }
        }
    }

    // ---------- stampede: thunder spooks the herd, and it runs east until you head it off
    private func startStampede() {
        if stampede != nil || herd.count < 3 || stampDay == day { return }
        stampDay = day
        stampede = (0, 0)
        for i in herd.indices { herd[i].run = true }
        hint("stampede", "Thunder has spooked the herd! They are running east. Ride out past them to turn them back before they are gone.", again: true)
    }

    private func updStampede(_ dt: Double) {
        guard var s = stampede else { return }
        var running = 0
        var i = 0
        let p = pasture
        while i < herd.count {
            var cw = herd[i]
            if !cw.run { i += 1; continue }
            cw.x += 34 * dt; cw.dir = 1; cw.phase += dt * 12
            if chance(dt * 6) { parts.append(Part(x: cw.x - 5, y: 0, vx: -rnd(4, 14), vy: rnd(-14, -4), life: 0.5, max: 0.5, c: Col(terrain.dust, 0.6), s: rnd(1, 2.4), grav: 10)) }
            if abs(cw.x - cam - W / 2) < W * 0.6 { shake = max(shake, 0.1) }
            if px > cw.x - 6 && px - cw.x < 32 {
                cw.run = false; cw.tx = rnd(p.0 + 8, p.1 - 8); cw.wait = 0
                s.0 += 1
            } else if cw.x > EX(2760) {
                herd.remove(at: i); s.1 += 1
                continue
            } else { running += 1 }
            herd[i] = cw
            i += 1
        }
        if running == 0 {
            stampede = nil
            hint("stampEnd", s.1 > 0 ? "The stampede is over. You turned \(s.0) head and lost \(s.1)." : "You turned the whole herd. They are walking back to pasture.", again: true)
        } else { stampede = s }
    }

    // ---------- something in the sky, and something on the old line
    var devils: [Devil] = []
    var gust = 0.0                 // seconds left of a dust squall blowing through
    /// Dry country by day: dust devils wander through, and now and then a squall of dust crosses in a few seconds.
    private func updDust(_ dt: Double) {
        let dry = (bio == .desert || bio == .canyon) && wx == 0 && dark() < 0.5
        if gust > 0 { gust -= dt }
        var i = 0
        while i < devils.count {
            devils[i].t += dt; devils[i].x += devils[i].vx * dt
            if chance(dt * 8) { parts.append(Part(x: devils[i].x + rnd(-4, 4), y: 0, vx: rnd(-20, 20), vy: -rnd(10, 40), life: 0.6, max: 0.6, c: Col(terrain.dust, 0.6), s: rnd(1, 2.2), grav: 30)) }
            if devils[i].t > devils[i].life { devils.remove(at: i) } else { i += 1 }
        }
        if !dry || !cut.isEmpty || duel != nil { return }
        if devils.count < 2 && chance(dt / 14) {
            let fromLeft = chance(0.5)
            devils.append(Devil(x: fromLeft ? cam + rnd(10, W * 0.4) : cam + rnd(W * 0.6, W - 10), vx: (fromLeft ? 1 : -1) * rnd(10, 26), life: rnd(7, 13), big: chance(0.35)))
        }
        if gust <= 0 && chance(dt / 75) {
            gust = 7
            sfx?.whoosh()
            hint("gust", "A dust squall. It blows through in a moment.")
        }
    }

    private func updUfo(_ dt: Double) {
        guard var u = ufo else {
            if ufoAt > 0 && t > ufoAt && dark() > 0.8 && wx == 0 && cut.isEmpty {
                let lo = cam + 34, hi = cam + W - 34
                var kinds: [Int] = []
                if herd.contains(where: { !$0.run && $0.x > lo && $0.x < hi }) { kinds.append(0) }
                if strays.contains(where: { !$0.tame && $0.x > lo && $0.x < hi }) { kinds.append(1) }
                // it takes cattle and nothing else: never a horse
                guard let k = kinds.randomElement() else { return }
                var s = Saucer(x: px, side: chance(0.5) ? -1 : 1)
                if k == 0, let i = herd.firstIndex(where: { !$0.run && $0.x > lo && $0.x < hi }) { s.cow = herd[i]; s.x = herd[i].x; herd.remove(at: i) }
                if k == 1, let i = strays.firstIndex(where: { !$0.tame && $0.x > lo && $0.x < hi }) { s.stray = strays[i]; s.x = strays[i].x; strays.remove(at: i) }
                ufo = s; ufoAt = 0
            }
            return
        }
        u.t += dt
        if u.ph != 2 && Int(clock * 5) != Int((clock - dt) * 5) { sfx?.hum(clampD(1 - abs(u.x - px) / 320, 0.1, 1)) }
        if u.ph == 0 {
            if u.t > 1.7 { u.ph = 1; u.t = 0 }
        } else if u.ph == 1 {
            if gunT > 0.1 && abs(px - u.x) < 125 && u.lift < 0.95 {
                // a round into it: it drops what it had and runs
                if let c = u.cow { herd.append(c) }
                if let w = u.stray { strays.append(w) }
                if let m = u.mustang, m.seed != 3 { mustangs.append(m) }       // a raider's horse is not given back
                u.cow = nil; u.stray = nil; u.mustang = nil
                puff(u.x, -74, 12, Col(0xb8ffd0), 60)
                sfx?.box()
                u.ph = 2; u.t = 0; u.lift = 1
                hint("ufoshot", "You put a round into it. It dropped what it had and ran.", again: true)
            } else {
                u.lift = clampD((u.t - 0.45) / 2.3, 0, 1)
                if chance(dt * 26) { parts.append(Part(x: u.x + rnd(-10, 10), y: -rnd(0, 10), vx: rnd(-3, 3), vy: -rnd(30, 64), life: rnd(0.6, 1.1), max: 1.1, c: chance(0.5) ? Col(0xb8ffd0) : Col(0xe8fff0), s: 1.6, grav: 0)) }
                if u.t > 2.95 {
                    let what = u.cow != nil ? "a cow" : (u.stray != nil ? "a stray longhorn" : "a wild mustang")
                    u.cow = nil; u.stray = nil; u.mustang = nil
                    u.ph = 2; u.t = 0
                    shake = max(shake, 0.15)
                    for _ in 0..<6 { dropCoin(u.x, 9) }
                    hint("ufo", "Something came down out of the sky and took \(what). It left six coins in a scorched ring. A shot while the beam is on drives it off.", again: true)
                }
            }
        } else if u.t > 1.1 { ufo = nil; return }
        ufo = u
    }

    private func updYard(_ dt: Double) {
        if ghostX == nil && ghostAt > 0 && t > ghostAt && px > EX(2500) {
            ghostAt = 0
            ghostX = WORLD + 80
            sfx?.whistle()
            hint("ghost", "A train that is not there goes through the yard without a sound on the rails.", again: true)
        }
        if let gx = ghostX {
            ghostX = gx - 210 * dt
            if gx < yardX - 320 { ghostX = nil }
        }
    }

    /// The riflemen hired onto a gatehouse roof for the night.
    private func updRifles(_ dt: Double) {
        for g in [gateW, gateE] {
            let n = g.rifles / 4
            if n == 0 || g.hp <= 0 { continue }
            g.rcd -= dt
            if g.rcd > 0 { continue }
            var tgt: Bandit?
            var bd = 210 * sightK()
            for bn in bandits where bn.hp > 0 {
                let d = abs(bn.x - g.cx)
                if d < bd { bd = d; tgt = bn }
            }
            guard let bn = tgt else { continue }
            g.rcd = 1.3 / Double(n)
            let dir = bn.x > g.cx ? 1.0 : -1.0
            shots.append(Shot(x: g.cx + dir * 4, y: -44, vx: dir * 300, life: max(0.05, bd / 300), mine: false))
            sfx?.gun(clampD(1 - abs(g.cx - px) / 320, 0.15, 1) * 0.6)
            if chance(0.75) { hurt(bn, 2) }
        }
    }
    var dynamite = 0
    var loader = false
    var lantern = false
    var postSold = 0            // the day the trading post last sold something
    var scoutDays = 0
    var ruinCool = 0
    var rigLv = 0
    var rigBurn = false
    var showOn = false
    var showUsed = false
    var oatsDay = 0             // the day your horse does not tire
    var wind = 1.0              // how much gallop the horse has left
    var blown = false           // winded: back to its usual pace until it has caught its breath
    var string = 0              // mustangs broken to saddle at the stable: each makes the horse tire a quarter slower
    var over = false            // caught without a coin to your name
    var troughs: [Double] { return bio == .river ? [1337, pasture.0 + 32, river.0 + 11, river.0 + 25, river.1 - 11] : [1337, pasture.0 + 32] }
    var fortNight = false
    var cav: [Trooper] = []
    var mustangs: [Mustang] = []
    var mustangRange: (Double, Double) { return (WEST + 70, 84) }
    var rigPay: Int { return 6 + town }
    /// The two sights out west that change with the country: the ruin you salvage, and the works that pays each dawn.
    var ruinName: String {
        switch bio { case .river: return "Wrecked riverboat"; case .pine: return "Old logging camp"; case .canyon: return "Cliff dwellings"; case .snow: return "Trapper\u{2019}s cabin"; default: return "Ghost town" }
    }
    var ruinFind: String {
        switch bio {
        case .river: return "The crew wades into the flooded hold and comes out with the purser\u{2019}s cashbox. The wreck will be worth another look in a couple of days."
        case .pine: return "Under the old cookhouse floor the crew finds a payroll tin. The camp will be worth another look in a couple of days."
        case .canyon: return "High in the rock rooms the crew finds an old trader\u{2019}s cache. The cliffs will be worth another look in a couple of days."
        case .snow: return "In the root cellar the crew finds a trapper\u{2019}s stash of coin. The cabin will be worth another look in a couple of days."
        default: return "The crew turns up a strongbox under the old bank floor. The ruins will be worth another look in a couple of days."
        }
    }
    /// (the spot before, the works after, the row on the takings card, what puts it out of action)
    var rigNames: (String, String, String, String) {
        switch bio {
        case .river: return ("Fishing spot", "Fish weir", "Fish", "Lightning has split the fish weir")
        case .pine: return ("Pitch pines", "Tar kiln", "Pine tar", "Lightning has set the tar kiln alight")
        case .snow: return ("Frozen lake", "Ice house", "Ice", "The ice house roof has fallen in")
        default: return ("Oil seep", "Oil derrick", "Oil", "Lightning has set the oil derrick alight")
        }
    }
    var ruinPay: Int { return 7 + 2 * town }

    /// What the trading post has on the counter today, or nil if it has sold out.
    func postItem() -> (String, String, Int, Bool, String)? {
        if postSold == day { return nil }
        let l = ITEMS.filter { !$0.3 || !($0.0 == "loader" ? loader : lantern) }
        return l.isEmpty ? nil : l[(day + town) % l.count]
    }

    /// The last coin is in: whatever the place sells, happens.
    private func siteDone(_ bl: Building) {
        let x = bl.cx
        bl.paid = 0
        switch bl.type {
        case .sPost:
            guard let it = postItem() else { return }
            postSold = day
            if it.0 == "dyn" { dynamite += 1 } else if it.0 == "loader" { loader = true } else if it.0 == "oats" { oatsDay = day; wind = 1; blown = false } else { lantern = true }
            sfx?.recruit(); puff(x, -26, 8, GOLD, 30)
            hint("buy" + it.0, "\(it.1). \(it.4)", again: true)
        case .sTribe:
            scoutDays = 3
            sfx?.recruit(); puff(x, -26, 8, GOLD, 30)
            hint("scouts", "The scouts ride for you for three days. They will name the side each raid comes from, and ambush two raiders on the trail every night.", again: true)
        case .sRuin:
            ruinCool = 2
            sfx?.box()
            for _ in 0..<14 { parts.append(Part(x: x + rnd(-18, 18), y: -rnd(2, 16), vx: rnd(-14, 14), vy: -rnd(6, 16), life: rnd(1.2, 2.2), max: 2.2, c: Col(0xb9a98a, 0.8), s: 3, grav: 0)) }
            for _ in 0..<ruinPay { dropCoin(x + rnd(-12, 12), rnd(4, 14)) }
            hint("ruin", ruinFind, again: true)
        case .sRig:
            if rigLv == 0 {
                rigLv = 1
                sfx?.fanfare(); puff(x, -40, 14, Col(0x1c1a22), 60)
                hint("rig", "The \(rigNames.1.lowercased()) is working. It pays \(rigPay) coins at the town centre every dawn\(bio == .snow ? "" : ", though lightning can put it out of action").", again: true)
            } else {
                rigBurn = false
                sfx?.recruit(); puff(x, -30, 10, Col(0xd8dde2), 30)
                hint("capped", "The \(rigNames.1.lowercased()) is mended and working again.", again: true)
            }
        case .sShow:
            showUsed = true
            let r = rnd(0, 1)
            if r < 0.45 {
                oatsDay = day; wind = 1; blown = false
                sfx?.recruit(); puff(x, -24, 10, Col(0x8fe08a), 30)
                hint("tonic1", "Horse tonic, and it works. Your horse does not tire today.", again: true)
            } else if r < 0.7 {
                for _ in 0..<8 { dropCoin(x, 10) }
                sfx?.fanfare()
                hint("tonic2", "There was a gold piece in the bottle, and seven more in the crate. The professor looks sick.", again: true)
            } else {
                sfx?.empty()
                hint("tonic3", "Coloured water. The professor tips his hat.", again: true)
            }
        case .sGallery:
            galleryDay = day
            bl.dyn = 0
            startGallery()
        case .sRods:
            rodsLv = 1
            sfx?.fanfare(); puff(x, -50, 10, GOLD, 40)
            hint("rods", "Lightning rods go up on every roof. A strike on town now runs harmlessly to ground.", again: true)
        case .sTower:
            towerLv = 1
            sfx?.fanfare(); puff(x, -60, 10, GOLD, 40)
            hint("brigade", "The town has a fire brigade. Roof fires go out fast now.", again: true)
        case .sHobo:
            hoboDay = day
            sfx?.recruit(); puff(x, -20, 6, GOLD, 30)
            let r = rnd(0, 1)
            if r < 0.4 {
                let spots: [(Double, String)] = [(330, "by the lone tree west of the mission"), (EX(2300), "under the rock arch east of town"), (-180, "between the trading post and the scout camp"), (826, "behind the old mine")]
                let sp = spots[Int(rnd(0, 3.99))]
                boxes.append(Box(sp.0, 8 + 2 * town))
                hint("rumor1", "A hobo scratches a sign in the dirt: a box, buried \(sp.1).", again: true)
            } else if r < 0.75 && raidSize(day - day0 + town) > 0 && t < 0.72 {
                hint("rumor2", "\u{201C}They come from the \(side < 0 ? "west" : "east") tonight. We saw them watering up.\u{201D}", again: true)
            } else {
                dynamite += 1
                hint("rumor3", "One of them sells you a stick of dynamite out of his bindle. No questions asked.", again: true)
            }
        case .sCar:
            let n = carN
            carN += 1; carCool = 3
            sfx?.box(); shake = max(shake, 0.2); puff(x, -10, 12, Col(terrain.dust), 40)
            func pay(_ k: Int) { for _ in 0..<k { dropCoin(x + rnd(-8, 8), 10) } }
            if n == 0 {
                pay(10)
                cut = [Beat(art: "wire", head: "Inside the boxcar", cap: "Company ledgers, and proof: Crane paid a man to burn Dustfall.", lines: ["PAID VARNEY: DUSTFALL JOB", "PAID: TORCHES AND LAMP OIL", "SIGNED       S. CRANE"], from: "CRANE CATTLE AND RAIL: LEDGER")]
            } else if n == 1 {
                dynamite += 2
                hint("car2", "Blasting supplies, forgotten since the line was built. Two sticks of dynamite are still good.", again: true)
            } else if n == 2 {
                pay(12)
                ufo = Saucer(ph: 2, x: x, side: 1, lift: 1)
                hint("car3", "The door comes off and something green goes straight up out of it. It left twelve coins behind.", again: true)
            } else if chance(0.3) {
                dynamite += 1; pay(4)
                hint("car4", "A few coins and a stick of dynamite, this time.", again: true)
            } else {
                pay(8 + Int(rnd(0, 6.99)))
                hint("car5", "Coins in a mail sack. Nobody can say how it got in there.", again: true)
            }
        case .sFort:
            fortNight = true
            sfx?.fanfare()
            hint("fort", "The patrol saddles up. They ride tonight as soon as raiders show, and cut down those outside the walls.", again: true)
        default: break
        }
        onSave?()
    }

    /// What a site says about itself on the line at the bottom of the screen.
    private func siteInfo(_ bl: Building) -> String {
        let go = bl.paid > 0 ? " (\(bl.paid) in)" : ""
        switch bl.type {
        case .sPost:
            if let it = postItem() { return "Trading post: \(it.1), \(it.2) coins\(go). \(it.4)" }
            return "Trading post: sold out for today. He restocks every morning."
        case .sTribe:
            return scoutDays > 0 ? "Scout camp: the scouts ride for you \(scoutDays) more \(scoutDays > 1 ? "days" : "day")." : "Scout camp: 4 coins\(go) hires the scouts for three days. They name the side each raid comes from, and ambush two raiders on the trail."
        case .sRuin:
            return ruinCool > 0 ? "\(ruinName): picked over. Worth another look in \(ruinCool) \(ruinCool > 1 ? "days" : "day")." : "\(ruinName): 3 coins\(go) pays for a day of salvage. There is about \(ruinPay) to be found."
        case .sRig:
            if rigLv == 0 { return "\(rigNames.0): 14 coins\(go) builds a \(rigNames.1.lowercased()). It pays \(rigPay) coins at the town centre every dawn." }
            return rigBurn ? "\(rigNames.1): out of action. 3 coins\(go) pays a crew to mend it. It pays nothing until then." : "\(rigNames.1): working. Pays \(rigPay) coins at the town centre every dawn."
        case .sShow:
            return showUsed ? "Medicine show: one bottle to a customer. He moves on in the morning." : "Medicine show: 3 coins\(go) for a bottle of tonic. It might put fire in your horse, pay out handsomely, or be coloured water."
        case .sGallery:
            if galleryDay == day { return "Shooting gallery: one go a day. The booth opens again in the morning." }
            return "Shooting gallery: 2 coins\(go) buys eight shots across a wide saloon. Big targets pay 1 coin; small or moving ones pay more, up to 6 for the tossed silver dollar."
        case .sRods:
            return rodsLv > 0 ? "Lightning rods: fitted to every roof. A strike on town runs harmlessly to ground." : "Windmill: 5 coins\(go) fits lightning rods to every roof, so a strike cannot start a fire."
        case .sTower:
            return towerLv > 0 ? "Water tower: the fire brigade is standing by. Roof fires go out fast." : "Water tower: 6 coins\(go) raises a fire brigade. Lightning and raiders' torches start roof fires, and the brigade puts them out fast."
        case .sHobo:
            return hoboDay == day ? "Hobo jungle: they have said all they are going to say today." : "Hobo jungle: 2 coins\(go) buys a rumour: a buried box, which side tonight's raid comes from, or something out of a bindle."
        case .sCar:
            return carCool > 0 ? "Sealed boxcar: empty for now. The hobos say it fills again by itself. Look in \(carCool) \(carCool > 1 ? "days" : "day")." : "Sealed boxcar: 5 coins\(go) pays a crew with crowbars. Nobody knows what is in it. It hums after dark."
        default:
            if fortNight { return "Cavalry outpost: a patrol rides tonight, as soon as raiders show." }
            return cav.isEmpty ? "Cavalry outpost: 8 coins\(go) calls out a patrol for tonight. They cut down raiders outside the walls." : "Cavalry outpost: the patrol is out."
        }
    }

    // ---------- the cavalry: five troopers ride in behind the raiders and cut down those outside the walls
    private func updCav(_ dt: Double) {
        if fortNight && cav.isEmpty, let first = bandits.first(where: { $0.st != 3 }) {
            fortNight = false
            let s = first.side
            let x0 = s > 0 ? gateE.x + 420 : gateW.x - 420
            for i in 0..<5 { cav.append(Trooper(x: x0 + s * Double(i) * 20, dir: -s, cd: rnd(0.2, 0.8))) }
            sfx?.fanfare()
            hint("cavalry", "The cavalry! The patrol rides in behind the raiders.", again: true)
        }
        var i = 0
        while i < cav.count {
            var c = cav[i]
            c.x += c.dir * 118 * dt; c.phase += dt * 118 * 0.16
            c.cd -= dt
            if c.cd <= 0 {
                var tgt: Bandit?
                var bd = 95.0
                for bn in bandits where bn.hp > 0 && (bn.x < gateW.x || bn.x > gateE.x + 14) {
                    let d = abs(bn.x - c.x)
                    if d < bd { bd = d; tgt = bn }
                }
                if let bn = tgt {
                    c.cd = 0.7
                    let dir = bn.x > c.x ? 1.0 : -1.0
                    shots.append(Shot(x: c.x + dir * 6, y: -22, vx: dir * 300, life: max(0.05, bd / 300), mine: false))
                    sfx?.gun(clampD(1 - abs(c.x - px) / 320, 0.1, 1) * 0.5)
                    hurt(bn, 3)
                }
            }
            // they ride clean through, past the town and out the far side, as in the web game
            if (c.dir < 0 && c.x < gateW.x - 460) || (c.dir > 0 && c.x > gateE.x + 460) { cav.remove(at: i); continue }
            cav[i] = c
            i += 1
        }
    }

    // ---------- wild mustangs: gallop alongside one for a moment to rope it, then lead it in through the gate to sell
    private func updMustangs(_ dt: Double) {
        let r = mustangRange
        var slot = strays.filter { $0.tame }.count
        var i = 0
        while i < mustangs.count {
            var w = mustangs[i]
            let x0 = w.x
            let dp = px - w.x, ad = abs(dp)
            if w.st == 3 {
                w.x += w.dir * 124 * dt
                w.t += dt
                if w.x < WEST || w.x > WORLD + 30 || w.t > 9 { mustangs.remove(at: i); continue }
            } else if w.st == 2 {
                let tx = px - pdir * (20 + Double(slot) * 13)
                slot += 1
                let dx = tx - w.x
                if abs(dx) > 2 { w.dir = sgn(dx); w.x += w.dir * min(150, abs(dx) * 4) * dt }
                if w.x > gateW.x + 24 && w.x < gateE.x - 10 && has(stable) && stable.level > 0 && string < 3 {
                    string += 1
                    sfx?.recruit(); puff(w.x, -14, 8, Col(0x8fe08a), 30)
                    hint("string", "The stable breaks the mustang to saddle. With \(string) in your string your horse tires \(string * 25)% slower." + (string < 3 ? " The stable has room for \(3 - string) more." : ""), again: true)
                    mustangs.remove(at: i); continue
                }
                if w.x > gateW.x + 24 && w.x < gateE.x - 10 {
                    let n = 3 + town
                    for _ in 0..<n { dropCoin(w.x, 8) }
                    sfx?.recruit(); puff(w.x, -14, 8, GOLD, 30)
                    hint("mustangsold", "The mustang sells in town for \(n) coins.", again: true)
                    mustangs.remove(at: i); continue
                }
            } else {
                if ad < 130 { hint("mustang", "Wild mustangs. Ride fast close beside one until the loop over it closes, then lead it into town to sell.") }
                if w.st == 0 {
                    w.t -= dt
                    if w.t <= 0 { w.t = rnd(2, 7); w.going = !chance(0.4); w.tx = clampD(w.x + rnd(-50, 50), r.0, r.1) }
                    if w.going && abs(w.tx - w.x) > 1 { w.dir = sgn(w.tx - w.x); w.x += w.dir * 9 * dt }
                    if ad < 66 && (abs(pvx) > 20 || ad < 20) { w.st = 1; w.t = 3.2; w.dir = dp > 0 ? -1 : 1 }
                } else {
                    w.x += w.dir * 88 * dt
                    if w.x < r.0 { w.x = r.0; w.dir = 1 }
                    if w.x > r.1 { w.x = r.1; w.dir = -1 }
                    if chance(dt * 9) { parts.append(Part(x: w.x - w.dir * 8, y: 0, vx: -w.dir * rnd(4, 14), vy: rnd(-14, -4), life: 0.5, max: 0.5, c: Col(terrain.dust, 0.6), s: rnd(1, 2.4), grav: 10)) }
                    w.t -= dt
                    if w.t <= 0 && ad > 100 { w.st = 0; w.t = rnd(1, 3); w.going = false } else if w.t <= 0 && ad < 60 { w.t = 1; w.dir = dp > 0 ? -1 : 1 }
                }
                if ad < 40 && abs(pvx) > 40 { w.rope += dt } else { w.rope = max(0, w.rope - dt * 0.4) }
                if w.rope > 0.8 {
                    w.st = 2; w.rope = 0
                    sfx?.recruit(); puff(w.x, -16, 6, GOLD, 30)
                    hint("roped", "Roped. Lead it in through the gate and it sells in town.", again: true)
                }
            }
            w.speed = abs(w.x - x0) / max(dt, 0.001)
            w.phase += w.speed * dt * 0.16
            mustangs[i] = w
            i += 1
        }
    }
    var noStory = false         // still pictures for checking the build leave the story out
    var cut: [Beat] = []        // story pictures waiting to be shown; the game stands still while there are any
    var star = false            // every building in this town is as good as it gets
    var duelWon = false
    private var storyRest = 0.0        // no new scene until this long after the last one closed

    /// Plays the first story scene whose moment has come, once each.
    private func story() {
        if noStory || tripT >= 0 || duel != nil { return }
        if !cut.isEmpty { return }
        let resting = clock < storyRest
        let urgent: Set<String> = ["won", "end", "a1", "a2", "a3", "a4"]
        let n = STAGES.count, st = town % n, ln = day - day0
        func due(_ k: String) -> Bool {
            switch k {
            case "s1": return town == 0 && day >= 2 && t > 0.03 && t < 0.3
            case "s2": return town == 0 && ln >= 3 && t > 0.03 && t < 0.3
            case "s3": return duelDay == day && t > 0.2 && t < 0.32
            case "s4": return rigLv > 0 && (bio == .desert || bio == .canyon)
            case "yard": return px > yardX + 210
            case "ufo": return seen.contains("ufo") && t > 0.03 && t < 0.3
            case "a1": return st == 1 && town > 0 && t > 0.14
            case "a2": return st == 2 && t > 0.14
            case "a3": return st == 3 && t > 0.14
            case "a4": return st == 4 && t > 0.14
            case "won": return duelWon
            case "varney": return bandits.contains { $0.boss && $0.st != 3 }
            case "storm": return wx == 3 && cloudI() > 0.7 && rainI() < 0.5
            case "end": return endNow
            default: return false
            }
        }
        for k in ["s1", "s2", "s3", "s4", "a1", "a2", "a3", "a4", "yard", "won", "varney", "storm", "ufo", "end"] where !seen.contains("st_" + k) && (!resting || urgent.contains(k)) && due(k) {
            seen.insert("st_" + k)
            cut = STORY[k] ?? []
            storyRest = clock + 30
            // riding in on a new town opens with the place itself
            if k.hasPrefix("a"), let line = ARRIVE[place] { cut.insert(Beat(art: "vista", who: place, head: nice(townName), cap: line), at: 0) }
            return
        }
    }

    /// A town earns its star when nothing in it can be improved any further.
    private func checkStar() {
        if star { return }
        for bl in b where !bl.virt && !bl.site && bl.level < bl.maxLevel { return }
        star = true
        sfx?.fanfare(); flash = 0.5
        if !noStory && cut.isEmpty && town % STAGES.count != STAGES.count - 1 {
            cut = [Beat(art: "badge", head: "\(nice(townName)) has its star", cap: "Every building here is as good as it gets. One more town Crane will never own.")]
        }
        hint("star\(town)", "\(nice(townName)) has its star: every building here is as good as it gets.", again: true)
    }
    var flooded: Bool { return flood >= day && bio != .snow }
    var coachPay: Int { return 6 + 2 * town }
    var strayRange: (Double, Double) { return (EX(2424), EX(2744)) }
    var missionX: Double { return 420 }
    var archX: Double { return EX(2360) }
    var mapNote = ""            // set when a new town is reached, for the map to show
    var here: Place { return PLACES[place] ?? PLACES["dustfall"]! }
    var townName: String { return here.name }

    var store = Building(.store, 1108)
    var saloon = Building(.saloon, 1240)
    var sheriff = Building(.sheriff, 1400)
    var stable = Building(.stable, 1590)
    var bankB = Building(.bank, 1020)
    var gateW = Building(.gateW, 958)
    var gateE = Building(.gateE, 1940)
    var station = Building(.station, 1700)
    var ticket = Building(.train, STOP + 83)
    var hall = Building(.hall, 1352)
    var wireW = Building(.wireW, 904)
    var wireE = Building(.wireE, 1975)
    var bordello = Building(.bordello, 1490)
    var doctor = Building(.doctor, 1704)
    var church = Building(.church, 1786)
    var forge = Building(.forge, 1864)
    var telegraph = Building(.telegraph, 1948)
    var claim = Building(.claim, 528)
    /// The town's signature building: Redwater's ferry, Timberline's sawmill, Iron Gulch's smelter, Bitter End's fur trader.
    var sig = Building(.sig, 0)
    var sigName: String {
        switch place {
        case "redwater": return "Ferry"
        case "timberline": return "Sawmill"
        case "irongulch": return "Copper smelter"
        case "bitterend": return "Fur trader"
        default: return ""
        }
    }
    var sigOn: Bool { return sig.level > 0 && b.contains { $0 === sig } }
    /// Unopened and within reach: it takes the coin ahead of a drifter who is further off.
    var sigWants: Bool { return sig.level == 0 && b.contains { $0 === sig } && abs(sig.cx - px) < sig.def.w / 2 + 12 }
    /// What the signature building does, for the info line and the arrival note.
    var sigWhat: String {
        switch place {
        case "redwater": return "Tolls from the ford: 3 coins at dawn, 6 after the river floods."
        case "timberline": return "Sawn lumber: every other building here costs a quarter less."
        case "irongulch": return "Prospectors bring 2 coins each at dawn instead of 1, but the smoke draws one more raider a night."
        case "bitterend": return "Furs: 2 coins at dawn, and 1 more for every rancher, who trap all winter."
        default: return ""
        }
    }
    var herd: [Cow] = []
    var raided = false          // raiders came last night

    // the country and the day's weather: 0 clear, 1 dust storm (a blizzard in snow country), 2 rain (snowfall), 3 a thunderstorm between wxA and wxB
    var bio: Bio { return here.bio }
    var terrain: Land { return LANDS[bio]! }
    var wx = 0
    var wxA = 0.0
    var wxB = 0.0
    var bolt = 0.0              // seconds left of a lightning flash
    var boltX = 0.0
    var river: (Double, Double) { return (EX(2162), EX(2198)) }
    var storm: Bool { return wx == 1 }
    func cloudI() -> Double {
        if wx == 2 { return bio == .snow ? 0 : 0.45 }
        if wx == 3 { return smooth(wxA - 0.07, wxA + 0.02, t) * (1 - smooth(wxB - 0.02, wxB + 0.05, t)) }
        return 0
    }
    func rainI() -> Double {
        if bio == .snow { return 0 }
        if wx == 2 { return 0.4 }
        if wx == 3 { return smooth(wxA, wxA + 0.05, t) * (1 - smooth(wxB - 0.06, wxB, t)) }
        return 0
    }
    /// How far anyone can see: a dust storm or blizzard cuts it short, and so does a downpour.
    func sightK() -> Double { return (storm ? 0.6 : (rainI() > 0.6 ? 0.8 : 1)) * (lantern ? 1.2 : 1) }
    func wxName() -> String {
        switch wx {
        case 1: return bio == .snow ? "Blizzard" : "Dust storm"
        case 2: return bio == .snow ? "Snowfall" : "Rain"
        case 3: return "Thunderstorm"
        default: return ""
        }
    }
    /// The ford east of a river town slows everyone who crosses it.
    func slowAt(_ x: Double) -> Double {
        if bio != .river && !flooded { return 1 }
        return x > river.0 && x < river.1 ? (flooded && bio == .river ? 0.34 : 0.5) : 1
    }

    /// The weather for the day ahead, rolled at dawn. Returns a line for the morning's message.
    private func rollWx() -> String {
        let ln = day - day0
        let r = rnd(0, 1)
        func mkStorm() {
            wx = 3
            if chance(0.5) { wxA = rnd(0.56, 0.64); wxB = 0.93 } else { wxA = rnd(0.2, 0.3); wxB = wxA + rnd(0.26, 0.34) }
        }
        wx = 0
        if town == 0 {
            // the first town is dry country, but its third morning always has a storm building
            if ln == 3 || (ln > 4 && r < 0.3) { mkStorm() }
        } else {
            var odds: (Double, Double, Double) = (0.2, 0.05, 0.22)
            if bio == .river { odds = (0.08, 0.18, 0.27) } else if bio == .canyon { odds = (0.14, 0.08, 0.25) } else if bio == .pine { odds = (0.03, 0.25, 0.33) } else if bio == .snow { odds = (0.18, 0.22, 0) }
            if r < odds.0 { wx = 1 } else if r < odds.0 + odds.1 { wx = 2 } else if r < odds.0 + odds.1 + odds.2 { mkStorm() }
        }
        if wx > 1 && bio != .snow && !herd.isEmpty && herd.count < 12 { addCow(calf: true) }
        switch wx {
        case 3: return " A thunderstorm is building for \(wxA > 0.5 ? "tonight" : "this afternoon"): deputies see less in the downpour, and lightning finds raiders caught in the open."
        case 1: return " \(wxName()) today: the deputies cannot see far, and raiders will be close before anyone spots them."
        case 2: return bio == .snow ? " Snowfall. A quiet day." : " Rain today. The herd grows on it."
        default: return ""
        }
    }

    /// Lightning in a thunderstorm: flashes overhead, and now and then finds a raider outside the gates.
    private func updWx(_ dt: Double) {
        bolt = max(0, bolt - dt)
        if wx == 3 && t > wxB - 0.03 && flood < day + 1 && bio != .snow {
            flood = day + 1
            hint("flood", bio == .river ? "The river is up after the storm. Everyone crossing the ford is slowed to a crawl until tomorrow night." : "The storm has filled the dry wash east of town. It slows everyone who crosses until tomorrow night, and leaves gold in the gravel when it drops.", again: true)
        }
        if wx != 3 || rainI() < 0.5 { return }
        if chance(dt * 0.16) {
            var hitX = cam + rnd(0, W)
            let outside = bandits.filter { $0.st != 3 && $0.hp > 0 && ($0.x < gateW.x - 20 || $0.x > gateE.x + 30) }
            if let bn = outside.randomElement(), chance(0.5) { hitX = bn.x; hurt(bn, 3); puff(bn.x, -8, 10, Col(0xfff6dc), 50) }
            else if chance(0.3) {
                // or a roof in town
                let roofs = b.filter { $0.def.wall != 0 && !$0.def.gate && $0.level > 0 && !$0.building }
                if let bl = roofs.randomElement() {
                    hitX = bl.cx
                    if rodsLv > 0 { hint("grounded", "The lightning rods took that one. No harm done.") } else { setFire(bl, "Lightning has set") }
                }
            }
            if chance(0.5) { startStampede() }
            // lightning can set the derrick alight
            if rigLv > 0 && !rigBurn && chance(0.15) {
                rigBurn = true; hitX = sRig.cx
                hint("rigfire", "\(rigNames.3). It pays nothing until a crew mends it: 3 coins there.", again: true)
            }
            bolt = 0.35; boltX = hitX
            sfx?.thunder(clampD(1 - abs(hitX - px) / 600, 0.3, 1))
            if abs(hitX - px) < W { flash = max(flash, 0.5) }
        }
    }
    var pasture: (Double, Double) { return (EX(2030), EX(2150)) }
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
    var camps: [(Double, Int)] = [(120, 3), (700, 2), (2210, 2), (2640, 3)]

    var side = 1.0
    var duskDone = false
    var raidOn = false
    var badgePaid = 0
    var rackN: [BType: Int] = [:]      // badges, picks and ropes hanging on the racks, waiting for someone to take them: three at most
    var pickPaid = 0
    var shake = 0.0
    var flash = 0.0

    var hintText = ""
    var hintT = 0.0
    private(set) var seen: Set<String> = []
    var info = ""
    var slotsFor: Building?
    var sfx: Sound?

    init() { reset() }

    func reset() {
        state = .title
        town = 0; day = 1; day0 = 0; t = 0.6; clock = 0
        over = false
        carN = 0
        place = "dustfall"; log = []; choosing = false
        coins = 10; bank = 0
        hintText = ""; hintT = 0; seen = []
        layTown()
        // the title scene: dusk over the dead town, with thunder on the wind
        t = 0.745; wx = 3; wxA = 0.72; wxB = 0.93; titleT = 0
    }

    /// Lays out the town at this stop on the line: everything boarded up, drifters at the camps, strongboxes buried.
    /// The first town has a store, saloon, sheriff and station; the stable and bank come from the second town on,
    /// the bordello and doctor from the third, the church and blacksmith from the fourth, the telegraph at the last.
    private func layTown() {
        SHIFT = town > 0 ? 340 : 0
        WORLD = 3420 + SHIFT
        STOP = 1798 + SHIFT
        camps = [(120, 3), (700, 2), (EX(2210), 2), (EX(2640), 3), (EX(3066), 2)]       // the last is the hobo jungle
        px = FIRE_X - 20; pvx = 0; pdir = -1; pphase = 0
        tossCD = 0; ammo = 6; reloadT = 0; gunCD = 0; gunT = 0; hurtT = 0
        cam = FIRE_X - W / 2
        store = Building(.store, 1108); saloon = Building(.saloon, 1240); sheriff = Building(.sheriff, 1400)
        stable = Building(.stable, 1590); bankB = Building(.bank, 1020)
        gateW = Building(.gateW, 958); gateE = Building(.gateE, EX(1940))
        station = Building(.station, EX(1700)); ticket = Building(.train, STOP + 83)
        hall = Building(.hall, 1352); wireW = Building(.wireW, 904); wireE = Building(.wireE, EX(1975))
        bordello = Building(.bordello, 1490); doctor = Building(.doctor, 1704); church = Building(.church, 1786)
        forge = Building(.forge, 1864); telegraph = Building(.telegraph, 1948); claim = Building(.claim, 528)
        let sigX: Double = place == "redwater" ? EX(2132) : (place == "bitterend" ? EX(1700) : 250)       // west of the mission
        sig = Building(.sig, sigX)
        herd = []; raided = false; wx = 0; bolt = 0
        b = [store, saloon, sheriff]
        let stage = town % STAGES.count + (town >= STAGES.count ? STAGES.count : 0)
        coachSlot = Building(.coach, 1196); coachSlot.live = false
        star = false; cut = []
        coach = nil; outlaw = nil; flood = 0; duelDay = 0; duel = nil; owed = 0; strays = []
        for x in [2450.0, 2600, 2700] { strays.append(Stray(x: EX(x), tx: EX(x), seed: rnd(0, 100))) }
        if stage >= 1 { b.append(stable); b.append(bankB); b.append(claim); b.append(coachSlot) }
        if stage >= 2 { b.append(bordello); b.append(doctor) }
        if stage >= 3 { b.append(church); b.append(forge) }
        if stage >= 4 { b.append(telegraph) }
        sPost = Building(.sPost, -90); sTribe = Building(.sTribe, -250); sRuin = Building(.sRuin, -434); sRig = Building(.sRig, -600)
        sShow = Building(.sShow, 752); sFort = Building(.sFort, EX(2470))
        sRods = Building(.sRods, 992); sTower = Building(.sTower, 1206); sHobo = Building(.sHobo, EX(3090)); sCar = Building(.sCar, EX(3182))
        rodsLv = 0; towerLv = 0; hoboDay = 0; carCool = 0; bell = false; stampDay = 0; stampede = nil; ufo = nil; ufoAt = 0; ghostAt = 0; ghostX = nil
        sGallery = Building(.sGallery, 186); gallery = nil
        // in the last town Crane's own yard stands where the cavalry would camp
        for st in [sPost, sTribe, sRuin, sRig, sShow, sFort, sRods, sTower, sHobo, sCar, sGallery] where !(lastTown && st === sFort) { st.dyn = 0; b.append(st) }
        dynamite = 0; loader = false; lantern = false; postSold = 0; scoutDays = 0; ruinCool = 0; rigLv = 0; rigBurn = false
        showOn = false; showUsed = false; oatsDay = 0; wind = 1; blown = false; string = 0; fortNight = false; cav = []
        mustangs = [Mustang(x: -540, seed: 0), Mustang(x: -150, seed: 1), Mustang(x: -360, seed: 2)]
        // the last town: Crane's men standing about his yard past the east gate
        yardMen = []; routT = -1
        if lastTown {
            for k in 0..<5 {
                let m = Bandit(x: craneX - 30 + Double(k) * 22, rider: k == 1 || k == 3, side: 1, hp: 9)
                m.st = 2; m.face = -1; m.phase = Double(k)
                yardMen.append(m)
            }
        }
        // no railroad in the last town: the rails stop here
        if !sigName.isEmpty { b.append(sig) }
        b.append(hall); if !lastTown { b.append(station) }; b.append(gateW); b.append(gateE); b.append(wireW); b.append(wireE); b.append(ticket)
        for bl in b { bl.scale = 1 + 0.12 * Double(town) }
        ticket.live = false
        train = nil; tripT = -1; fade = 0
        drifters = []; folk = []; bandits = []; shots = []; parts = []; flying = []; ground = []; raid = []
        for (i, c) in camps.enumerated() {
            for k in 0..<c.1 { drifters.append(Drifter(x: c.0 - 14 + Double(k) * 13 + rnd(-2, 2), camp: i)) }
        }
        boxes = [Box(250, 6 + town), Box(610, 4), Box(EX(2270), 4), Box(EX(2540), 6 + town)]
        setCaps()
        side = bio == .canyon || chance(0.5) ? 1 : -1
        duskDone = false; raidOn = false; badgePaid = 0; pickPaid = 0; rackN = [:]; shake = 0; flash = 0
        duelWon = false; storyRest = 0; dawnRows = []; rallyOn = false; endNow = false; toTitle = false; zoom = 1
        info = ""; slotsFor = nil
    }

    /// Whether this town has the building at all.
    private func has(_ bl: Building) -> Bool { return b.contains { $0 === bl } }

    /// What still stands between this town and the railroad: every building open, and the clock tower up.
    func todo() -> [String] {
        var out: [String] = []
        for bl in b where bl.front && bl.level == 0 { out.append(bl.label.lowercased()) }
        if hall.level < 2 { out.append(hall.level == 0 ? "town square and clock tower" : "clock tower") }
        return out
    }

    private func setCaps() {
        // what each site costs right now, or 0 if there is nothing to buy there at the moment
        sPost.dyn = postItem()?.2 ?? 0
        // Timberline's sawmill takes a quarter off everything else in town
        let base = 1 + 0.12 * Double(town), saw = place == "timberline" && sigOn
        for bl in b where bl !== sig { bl.scale = base * (saw ? 0.75 : 1) }
        sTribe.dyn = scoutDays > 0 ? 0 : 4
        sRuin.dyn = ruinCool > 0 ? 0 : 3
        sRig.dyn = rigLv == 0 ? 14 : (rigBurn ? 3 : 0)
        sShow.dyn = showUsed ? 0 : 3; sShow.live = showOn
        sFort.dyn = fortNight || !cav.isEmpty ? 0 : 8
        sRods.dyn = rodsLv > 0 ? 0 : 5
        sTower.dyn = towerLv > 0 ? 0 : 6
        sHobo.dyn = hoboDay == day ? 0 : 2
        sCar.dyn = carCool > 0 ? 0 : 5
        sGallery.dyn = galleryDay == day ? 0 : 2
        for bl in b { bl.capL = bl.tier ? 1 + hall.level : 9 }
        station.capL = todo().isEmpty ? 9 : 0
    }

    // ---------- the opening: the camera drifts over the dead town before dawn, and the sheriff's son rides in from the east
    var reloadMax = 5.0
    var introT = 0.0
    var introCap = ""
    var introCard = false
    private var introI = 0
    private var introStep = 0
    var titleT = 0.0

    func beginIntro() {
        reset()
        wx = 0; bolt = 0
        state = .intro
        introT = 0; introI = 0; introCap = ""; introCard = false
        t = 0.955; px = FIRE_X + 470; pdir = -1; pvx = 0
        cam = clampD(1100 - W / 2, WEST, WORLD - W)
    }

    private func updIntro(_ dt: Double) {
        func ease(_ u: Double) -> Double { return u * u * (3 - 2 * u) }
        introT += dt
        while introI < INTRO.count && introT >= INTRO[introI].0 { introCap = INTRO[introI].1; introI += 1 }
        t = (0.955 + min(introT, 12) / 12 * 0.125).truncatingRemainder(dividingBy: 1)
        // the picture opens close on the dead street and draws back; as the rider comes up it closes in again and time drags
        let close = ease(clampD((introT - 7.6) / 1.2, 0, 1)) * (1 - ease(clampD((introT - 10.0) / 1.0, 0, 1)))
        zoom = 1.34 - 0.34 * ease(clampD(introT / 4.4, 0, 1)) + 0.34 * close
        let drag = 1 - 0.62 * close
        if introT > 3.6 {
            pvx = -(px > FIRE_X + 12 ? 62 : max(0, (px - FIRE_X + 20) * 2))
            px = max(FIRE_X - 20, px + pvx * dt * drag)
            pphase += abs(pvx) * dt * 0.085 * drag
            let st = Int(pphase * 4 / PI)
            if st != introStep { introStep = st; if pvx < -10 { sfx?.hoof(0.8) } }
            if pvx < -55 && chance(dt * 14) { parts.append(Part(x: px + 8, y: 0, vx: rnd(4, 14), vy: rnd(-14, -4), life: 0.5, max: 0.5, c: Col(terrain.dust, 0.6), s: rnd(1, 2.4), grav: 10)) }
        }
        let pan = 1100 + ease(clampD(introT / 4.6, 0, 1)) * 520 - W / 2
        let k = ease(clampD((introT - 4.2) / 1.8, 0, 1))
        cam = clampD(pan + (px - W * 0.42 - pan) * k, WEST, WORLD - W)
        if introT > 10.9 && !introCard { introCard = true; sfx?.fanfare() }
        if introT > 14.1 { endIntro() }
    }

    func endIntro() {
        if state != .intro { return }
        let skipped = introT < 14
        px = FIRE_X - 20; pvx = 0; pdir = -1
        t = 0.08; state = .play; zoom = 1
        introCap = ""; introCard = false
        if skipped { fade = 1; cam = clampD(px - W * 0.6, WEST, WORLD - W) }
        hint("start", "Ride with the stick, and hold the coin button to toss coins at drifters and at the boarded-up buildings.")
    }

    func start() {
        reset()
        wx = 0; bolt = 0; t = 0.08
        state = .play
        hint("start", "Dustfall burned years ago. Ride with the stick, and hold the coin button to toss coins at drifters and at the boarded-up buildings.")
    }

    // ---------- saving
    func snapshot() -> SaveData {
        // coins part-paid into something count as still in the purse
        var purse = coins + badgePaid + pickPaid + rackN.values.reduce(0, +)
        for bl in b { purse += bl.paid + bl.incoming }
        var sb: [SaveB] = []
        for bl in b { sb.append(SaveB(type: bl.type.rawValue, level: bl.level, building: bl.building, progress: bl.progress, hp: bl.hp, robbed: bl.robbed)) }
        var sf: [SaveF] = []
        for f in folk { sf.append(SaveF(x: f.x, role: f.role == .deputy ? 1 : (f.role == .miner ? 2 : (f.role == .rancher ? 3 : 0)))) }
        var dr: [Int] = []
        for i in 0..<camps.count { dr.append(drifters.filter { $0.camp == i }.count) }
        var bx: [Bool] = []
        for q in boxes { bx.append(q.open) }
        return SaveData(town: town, day: day, day0: day0, t: t, coins: purse, bank: bank, ammo: ammo, px: px, side: side,
                        train: train != nil, b: sb, folk: sf, drifters: dr, boxes: bx, seen: Array(seen), herd: herd.count, wx: [Double(wx), wxA, wxB], place: place, log: log,
                        ride: [wind, Double(string), Double(oatsDay)],
                        more: [Double(rodsLv), Double(towerLv), Double(hoboDay), Double(carCool), Double(carN), bell ? 1 : 0, Double(stampDay)],
                        west: [Double(dynamite), loader ? 1 : 0, lantern ? 1 : 0, Double(postSold), Double(scoutDays), Double(ruinCool), Double(rigLv), rigBurn ? 1 : 0, showOn ? 1 : 0, showUsed ? 1 : 0, fortNight ? 1 : 0],
                        extra: [Double(owed), Double(flood), Double(duelDay), outlaw?.side ?? 0, Double(outlaw?.hp ?? 0), Double(outlaw?.days ?? 0)])
    }

    /// Picks a saved game up again. A game saved at night comes back at dusk the same night.
    func restore(_ s: SaveData) {
        reset()
        wx = 0; bolt = 0
        town = max(0, s.town); day = max(1, s.day); day0 = s.day0
        place = s.place.flatMap { stageOf(town).contains($0) ? $0 : nil } ?? stageOf(town)[0]
        log = s.log ?? []
        if log.count != town || log.enumerated().contains(where: { !stageOf($0.offset).contains($0.element) }) { log = (0..<town).map { stageOf($0)[0] } }
        layTown()
        coins = max(0, s.coins); bank = max(0, s.bank); ammo = max(0, min(6, s.ammo))
        if ammo == 0 { ammo = 6 }
        t = s.t >= 0.72 ? 0.715 : clampD(s.t, 0, 1)
        side = s.side < 0 ? -1 : 1
        seen = Set(s.seen)
        if seen.contains("cranegone") { yardMen = [] }
        for sb in s.b {
            guard let bl = b.first(where: { $0.type.rawValue == sb.type }) else { continue }
            bl.level = max(0, min(bl.maxLevel, sb.level)); bl.building = sb.building && bl.level < bl.maxLevel
            bl.progress = clampD(sb.progress, 0, 1); bl.hp = sb.hp; bl.robbed = sb.robbed
        }
        folk = []
        for sf in s.folk {
            let f = Folk(x: sf.x)
            f.role = sf.role == 1 ? .deputy : (sf.role == 2 ? .miner : (sf.role == 3 ? .rancher : .folk))
            folk.append(f)
        }
        drifters = []
        for (i, c) in camps.enumerated() {
            let n = i < s.drifters.count ? max(0, min(c.1, s.drifters[i])) : c.1
            for k in 0..<n { drifters.append(Drifter(x: c.0 - 14 + Double(k) * 13 + rnd(-2, 2), camp: i)) }
        }
        for (i, bx) in boxes.enumerated() where i < s.boxes.count { bx.open = s.boxes[i] }
        for _ in 0..<max(0, min(12, s.herd ?? 0)) { addCow(calf: false) }
        if let r = s.ride, r.count == 3 { wind = clampD(r[0], 0, 1); string = max(0, min(3, Int(r[1]))); oatsDay = Int(r[2]) }
        if let m = s.more, m.count == 7 { rodsLv = Int(m[0]); towerLv = Int(m[1]); hoboDay = Int(m[2]); carCool = Int(m[3]); carN = Int(m[4]); bell = m[5] > 0; stampDay = Int(m[6]) }
        if let w = s.west, w.count == 11 {
            dynamite = Int(w[0]); loader = w[1] > 0; lantern = w[2] > 0; postSold = Int(w[3]); scoutDays = Int(w[4]); ruinCool = Int(w[5])
            rigLv = Int(w[6]); rigBurn = w[7] > 0; showOn = w[8] > 0; showUsed = w[9] > 0; fortNight = w[10] > 0
        }
        if let e = s.extra, e.count == 6 {
            owed = max(0, Int(e[0])); flood = Int(e[1]); duelDay = Int(e[2])
            if e[3] != 0 && e[4] > 0 {
                let o = Outlaw(x: e[3] < 0 ? missionX : archX, side: e[3] < 0 ? -1 : 1, name: OUTLAWS[day % OUTLAWS.count], reward: 8 + 2 * town)
                o.hp = Int(e[4]); o.days = max(1, Int(e[5])); outlaw = o
            }
        }
        if let w = s.wx, w.count == 3 { wx = max(0, min(3, Int(w[0]))); wxA = w[1]; wxB = w[2] }
        if s.train && station.level > 0 { train = Train(x: STOP, v: 0); ticket.live = !lastTown }
        px = clampD(s.px, WEST + 30, WORLD - 30)
        cam = clampD(px - W / 2, WEST, WORLD - W)
        state = .play
    }

    /// Set scenes for the simulator screenshots.
    /// Start play in any town on the line, with a purse to suit: for trying each one without playing up to it.
    func jump(_ n: Int) {
        guard n >= 0, n < STOPS.count else { return }
        start()
        place = STOPS[n].0; town = STOPS[n].1; log = STOPS[n].2
        day = 1 + town * 8; day0 = day - 1; t = 0.08
        layTown()
        nameSeq += 1
        coins = 12 + town * 5 + (town == STAGES.count - 1 ? 8 : 0); bank = 0
        fade = 1
        hint("jump", "\(nice(townName)). You step off with \(coins) coins, and everything here is boarded up.", again: true)
        onSave?()
    }

    /// How many townsfolk hold each job.
    func crew() -> [(Role, Int)] {
        return [Role.folk, .deputy, .miner, .rancher].map { r in (r, folk.filter { $0.role == r }.count) }
    }
    /// Take a badge, pick or rope back: one of them becomes a plain townsman again, free to build or to take another job.
    func release(_ r: Role) {
        guard r != .folk, let f = folk.first(where: { $0.role == r }) else { return }
        f.role = .folk; f.work = false; f.tx = f.x
        sfx?.slot()
    }

    func demo(_ name: String) {
        if name == "title" { return }
        start()
        noStory = true
        hintT = 0
        // lv0 to lv7: each town on the line, opened up, for a picture of every one
        let stops = STOPS
        let pre = ["lv", "sig", "wild", "buy", "mist", "ferry", "cold"].first { name.hasPrefix($0) } ?? ""
        if !pre.isEmpty, let n = Int(name.dropFirst(pre.count)), n >= 0, n < stops.count {
            place = stops[n].0; town = stops[n].1; log = stops[n].2
            day = 4 + town * 9; day0 = day - 4
            layTown()
            if town >= 1 { stable.level = 1; bankB.level = 1 }
            if town >= 2 { bordello.level = 1; doctor.level = 1 }
            if town >= 3 { church.level = 1; forge.level = 1 }
            if town >= 4 { telegraph.level = 1 }
            t = 0.3
        }
        if name == "duel" { day = 5; t = 0.4 }
        if name == "west" { day = 6; t = 0.35 }
        if name == "map" { town = 2; place = "timberline"; log = ["dustfall", "redwater"]; day = 20; day0 = 16; layTown(); stable.level = 1; bordello.level = 1; px = 1500; choosing = false }
        if name == "coach" { place = "irongulch"; log = ["dustfall"]; town = 1; day = 9; day0 = 6; layTown(); stable.level = 1; bankB.level = 1 }
        if name == "train" { place = "redwater"; log = ["dustfall"]; town = 1; day = 9; day0 = 6; layTown(); stable.level = 1; bankB.level = 1; bank = 12 }
        if name == "snow" { place = "coldcreek"; log = ["dustfall", "irongulch", "timberline"]; town = 3; day = 31; day0 = 27; layTown(); stable.level = 1; bankB.level = 1; bordello.level = 1; doctor.level = 1; church.level = 1; forge.level = 1; wx = 2 }
        if name == "storm" { wx = 3; wxA = 0.3; wxB = 0.6 }
        store.level = 1; sheriff.level = 1; saloon.level = 2; hall.level = name == "train" ? 2 : 1
        gateW.level = 1; gateW.hp = GHP[1]; gateE.level = 2; gateE.hp = GHP[2]
        drifters.removeAll { $0.camp == 1 }
        for i in 0..<6 { let f = Folk(x: 1180 + Double(i) * 46); folk.append(f) }
        folk[0].role = .deputy; folk[1].role = .deputy; folk[2].role = .miner
        coins = 14; px = 1330; pdir = 1
        if name == "lv0" || name == "lv2" { devils = [Devil(x: 1420, vx: 6, t: 3, life: 30, big: true), Devil(x: 1250, vx: -4, t: 2, life: 30, big: false)] }
        if name == "lv3" { gust = 12 }
        if name == "night" {
            day = 5; t = 0.8; duskDone = true; raidOn = true; side = 1
            px = 1880; pdir = 1
            wireE.level = 1
            for i in 0..<5 { bandits.append(Bandit(x: 2010 + Double(i) * 30, rider: i % 3 == 2, side: 1, hp: 3)) }
            px = 1850; folk[0].x = 1925; folk[1].x = 1916
        } else if name == "town" {
            // a town well along, to look at
            t = 0.36; day = 12; hall.level = 2; store.level = 2; saloon.level = 3; sheriff.level = 2; px = 1296; pdir = 1
            folk[0].x = 1260; folk[1].x = 1330; folk[2].x = 1218; folk[3].x = 1372
        } else if name == "gallery2" {
            hall.level = 1; px = 186; startGallery(); gallery?.t = 7.85; gallery?.shots = 3; gallery?.won = 9
            gallery?.targets[10].hit = 0.4; gallery?.targets[12].hit = 0.3
        } else if name == "gallery" {
            hall.level = 1; px = 186; startGallery(); gallery?.t = 3; gallery?.shots = 5; gallery?.won = 4
            gallery?.targets[4].hit = 0.3; gallery?.targets[9].hit = 0.6; gallery?.holes = [(120, 70), (230, 96)]
        } else if name == "over" {
            hall.level = 1; coins = 0; over = true
        } else if name == "fire" {
            t = 0.5; hall.level = 2; saloon.fireT = 4; saloon.fireHp = 0.8; towerLv = 1; rodsLv = 1; px = 1180; pdir = 1
        } else if name == "yard" {
            t = 0.84; hall.level = 1; px = EX(3130); pdir = 1; ghostX = EX(3330)
            ufo = Saucer(ph: 1, t: 1.4, x: EX(3040), side: 1, lift: 0.4, stray: Stray(x: EX(3040), tx: 0, seed: 1))
        } else if name == "west" {
            hall.level = 1; rigLv = 1; px = -560; pdir = -1; mustangs[0].x = -520; mustangs[2].x = -480; mustangs[0].st = 2; sRig.paid = 0
        } else if name == "west2" {
            hall.level = 1; scoutDays = 2; px = -180; pdir = -1; mustangs[1].x = -140; dynamite = 1
        } else if name == "duel" {
            hall.level = 2; startDuel(); duel?.st = 1; duel?.t = 3; duel?.t0 = 2.3; duel?.pos = 0.3; fade = 0
        } else if name == "coach" {
            t = 0.2; hall.level = 1; coach = Coach(x: coachSlot.x + 19); coach?.st = 1; coach?.moving = false; coachSlot.live = true; coachSlot.paid = 1; px = 1190
            outlaw = Outlaw(x: 1300, side: 1, name: OUTLAWS[0], reward: 10); strays[0].x = 1150; strays[0].tame = true
        } else if name == "snow" {
            t = 0.45; hall.level = 2; px = 1790; pdir = 1
        } else if name == "storm" {
            day = 4; t = 0.42; hall.level = 2; store.level = 2; px = 1210; bolt = 0.3; boltX = 1330
        } else if name == "train" {
            t = 0.3; station.level = 1; train = Train(x: STOP, v: 0); ticket.live = true
            claim.level = 1; folk[3].role = .rancher; folk[3].x = pasture.0 + 12
            for _ in 0..<4 { addCow(calf: false) }
            addCow(calf: true)
            ticket.paid = 3; px = STOP + 96; pdir = -1
        } else {
            day = 3; t = 0.4; hall.paid = 9; px = 1362
            for i in 0..<5 { ground.append(GCoin(x: 1150 + Double(i) * 7, y: 0, vx: 0, vy: 0, age: 1)) }
        }
        if name == "fort" { px = sFort.x - 40 }
        if name == "post" { px = -60 }
        if name == "mission" { px = missionX + 40; pdir = -1 }
        // set last, after the catch-all above has put the rider on main street
        if name.hasPrefix("sig") { sig.level = 1; px = sig.x + (place == "redwater" ? 10 : 30); pdir = 1; noStory = true; hintT = 0 }
        if name.hasPrefix("wild") { rigLv = 1; px = -520; pdir = -1; noStory = true; hintT = 0; if bio == .river || bio == .pine { t = 0.13 } }
        // standing at the unopened trade, drifters at the camp beside it: the coin should go to the trade
        if name.hasPrefix("mist") { px = -300; pdir = -1; demoT = 0.13; t = 0.13; noStory = true; hintT = 0 }
        if name.hasPrefix("ferry") { sig.level = 1; px = sig.x - 36; pdir = 1; demoT = 0.4; noStory = true; hintT = 0 }
        if name.hasPrefix("cold") { px = -300; pdir = 1; demoT = 0.4; noStory = true; hintT = 0; for k in 0..<9 { prints.append((px - 8 - Double(k) * 10, 1, Double(k) * 0.4 - 8)) } }
        if name.hasPrefix("lv") { demoT = 0.4 }
        if name.hasPrefix("buy") { px = sig.cx; pdir = 1; coins = 20; noStory = true; hintT = 0 }
        if ["finale", "finale2", "gone"].contains(name) {
            // the last stretch for real: the rout already under way, stories on, every earlier scene already seen
            place = "bitterend"; town = 4; log = ["dustfall", "redwater", "timberline", "irongulch"]; day = 36; day0 = 33; layTown()
            t = 0.3; hintT = 0; pdir = 1; px = craneX - 60
            for k in ["s1", "s2", "s3", "s4", "a1", "a2", "a3", "a4", "yard", "won", "varney", "storm", "ufo"] { seen.insert("st_" + k) }
            for k in 0..<14 { folk.append(Folk(x: px - 20 - Double(k) * 7)) }
            if name == "finale" { noStory = false; rallyOn = true; routT = 2.4 }
            if name == "finale2" { seen.insert("cranegone"); seen.insert("st_end"); toTitle = true; yardMen = [] }
            if name == "gone" { seen.insert("cranegone"); yardMen = []; noStory = true }
        }
        if name == "gate0" {
            place = "bitterend"; town = 4; log = ["dustfall", "redwater", "timberline", "irongulch"]; day = 36; day0 = 33; layTown()
            t = 0.4; noStory = true; hintT = 0; px = gateW.x + 30; pdir = -1
        }
        if name == "rout" {
            place = "bitterend"; town = 4; log = ["dustfall", "redwater", "timberline", "irongulch"]; day = 36; day0 = 33; layTown()
            t = 0.3; noStory = true; hintT = 0; pdir = 1
            px = craneX + 30; holdRout = 1.75
            for k in 0..<14 { folk.append(Folk(x: px - 20 - Double(k) * 7)) }
            rallyOn = true
        }
        if name == "march" {
            // the real thing, not posed: twelve-plus at work in town, a raider still hanging about, and you already past the east gate
            place = "bitterend"; town = 4; log = ["dustfall", "redwater", "timberline", "irongulch"]; day = 36; day0 = 33; layTown()
            t = 0.3; noStory = true; hintT = 0; pdir = 1
            for k in 0..<14 { folk.append(Folk(x: 1200 + Double(k) * 30)) }
            bandits.append(Bandit(x: 700, rider: false, side: -1, hp: 2))
            px = gateE.x + 60
            // like a save from before build 144: every building done, and the old ending already marked as seen
            for bl in b where bl.def.cost.count > 0 { bl.level = bl.maxLevel }
            seen.insert("st_end"); star = true
        }
        if name == "rally" {
            place = "bitterend"; town = 4; log = ["dustfall", "redwater", "timberline", "irongulch"]; day = 36; day0 = 33; layTown()
            t = 0.4; noStory = true; hintT = 0; seen.insert("rally")
            px = gateE.x - 20; pdir = 1
            for k in 0..<14 { folk.append(Folk(x: px - 20 - Double(k) * 7)) }
            rallyOn = true
        }
        if name.hasPrefix("see"), let n = Int(name.dropFirst(3)) {
            // a walk down the whole of the last town, a screen at a time, with everything built
            place = "bitterend"; town = 4; log = ["dustfall", "redwater", "timberline", "irongulch"]; day = 36; day0 = 33; layTown()
            for bl in b where [BType.store, .saloon, .sheriff, .stable, .bank, .station, .bordello, .doctor, .church, .forge, .telegraph, .claim].contains(bl.type) { bl.level = 2 }
            hall.level = 2; gateW.level = 2; gateE.level = 2; t = 0.4; noStory = true; hintT = 0
            px = WEST + 200 + Double(n) * 390
        }
        cam = clampD(px - W / 2, WEST, WORLD - W)
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
        hintT = 7 + Double(text.count) / 45
    }

    private func puff(_ x: Double, _ y: Double, _ n: Int, _ c: Col, _ sp: Double = 30) {
        for _ in 0..<n {
            parts.append(Part(x: x, y: y, vx: rnd(-sp, sp), vy: rnd(-sp, sp * 0.2), life: rnd(0.3, 0.7), max: 0.7, c: c, s: rnd(1, 2), grav: 60))
        }
    }

    private func dropCoin(_ x: Double, _ h: Double = 8) {
        ground.append(GCoin(x: x + rnd(-6, 6), y: h, vx: rnd(-22, 22), vy: rnd(40, 80), age: 0))
    }

    func rackX(_ bl: Building) -> Double { return bl.type == .store ? bl.x - 12 : (bl.type == .stable ? bl.x + bl.def.w + 18 : bl.x + bl.def.w + 8) }

    private func addCow(calf: Bool) {
        let p = pasture
        let x = rnd(p.0 + 8, p.1 - 8)
        herd.append(Cow(x: x, tx: x, calf: calf, seed: rnd(0, 100)))
    }

    // ---------- one frame
    func update(_ rawDt: Double) {
        // the first moments of the rout play in slow motion
        let dt = routT >= 0 && routT < 1.6 ? rawDt * 0.45 : rawDt
        clock += dt
        if let h = demoT { t = h }
        if state == .intro { updIntro(dt); updParts(dt); return }
        if state == .title {
            titleT += dt
            flash = max(0, flash - dt * 3); bolt = max(0, bolt - dt)
            cam = clampD(FIRE_X - W / 2 + sin(titleT * 0.07) * 160, WEST, WORLD - W)
            if chance(dt * 0.22) { bolt = 0.35; boltX = cam + rnd(0, W); flash = 0.35; sfx?.thunder(0.4) }
            updParts(dt)
            return
        }
        if state != .play { return }
        if over || !cut.isEmpty { return }
        if gallery != nil { updGallery(dt); updCoins(dt); updParts(dt); return }
        story()
        if duel != nil {
            // high noon: the day stands still until it is settled
            updDuel(dt)
            if hintT > 0 { hintT -= dt }
            shake = max(0, shake - dt * 3); flash = max(0, flash - dt * 3)
            if fade > 0 { fade = max(0, fade - dt * 0.9) }
            updCoins(dt); updShots(dt); updParts(dt)
            let want = clampD(px + 48 - W / 2, WEST, WORLD - W)
            cam += (want - cam) * min(1, dt * 3)
            sfx?.music(clock, 1)
            return
        }
        if duelDay == day && t > 0.33 && t < 0.5 && tripT < 0 { startDuel() }
        let was = t
        t += dt / DAY_LEN
        if was < 0.72 && t >= 0.72 && !duskDone { dusk() }
        if t >= 1 { t -= 1; day += 1; dawn() }
        if hintT > 0 { hintT -= dt }
        shake = max(0, shake - dt * 3)
        flash = max(0, flash - dt * 3)
        if tripT < 0 && fade > 0 { fade = max(0, fade - dt * 0.7) }
        setCaps()
        updTrain(dt)
        updPlayer(dt)
        updCoins(dt)
        updFolk(dt)
        updRally(dt)
        updBuild(dt)
        updRaid(dt)
        updBandits(dt)
        updGuns(dt)
        updShots(dt)
        updHerd(dt)
        updWx(dt)
        updDust(dt)
        updCoach(dt)
        updCav(dt)
        updFires(dt)
        updStampede(dt)
        updUfo(dt)
        updYard(dt)
        updRifles(dt)
        updMustangs(dt)
        updOutlaw(dt)
        updStrays(dt)
        fireWas = input.fire
        updParts(dt)
        updInfo()
        let want = clampD(px + pdir * 26 - W / 2, WEST, WORLD - W)
        cam += (want - cam) * min(1, dt * 4)
        let mode = !bandits.isEmpty ? 3 : (dark() > 0.6 ? 2 : (t > 0.6 ? 1 : 0))
        sfx?.town = town
        let playing = saloon.level > 0 && !saloon.building
        sfx?.pianoVol = playing ? clampD(1 - abs(saloon.x + 43 - px) / 280, 0, 1) : 0
        if playing && abs(saloon.x + 43 - px) < 230 && chance(dt * 1.6) {
            parts.append(Part(x: saloon.x + 43 + rnd(-6, 6), y: -18, vx: rnd(-5, 5), vy: -rnd(9, 14), life: 1.8, max: 1.8, c: Col(0xf0dfb4), s: 1.6, grav: 0))
        }
        sfx?.music(clock, mode)
    }

    /// Hoofprints behind the horse: they last in snow, and blow away quickly in dust.
    var prints: [(x: Double, dir: Double, age: Double)] = []
    private var printAt = 0.0
    private func updPrints(_ dt: Double) {
        let life = bio == .snow ? 14.0 : 4.0
        for i in prints.indices { prints[i].age += dt }
        prints.removeAll { $0.age > life }
        if abs(pvx) > 20 && abs(px - printAt) > 9 && bio != .river {
            printAt = px
            prints.append((px - (pvx > 0 ? 1 : -1) * 6, pvx > 0 ? 1 : -1, 0))
            if prints.count > 70 { prints.removeFirst() }
        }
    }

    private func updPlayer(_ dt: Double) {
        updPrints(dt)
        if tripT >= 0 { pvx = 0; return }       // aboard the train
        // a fresh horse gallops flat out for a few seconds, then settles to its usual pace until it has caught its wind
        let shoes = forge.level >= 2
        let riding = abs(input.stick) > 0.1
        let fresh = riding && !blown
        if fresh && oatsDay == day { wind = 1; blown = false }
        else if fresh {
            wind -= dt / ((shoes ? 9 : 5) * (1 + 0.25 * Double(string)))
            if wind <= 0 { wind = 0; blown = true; hint("wind", "Your horse is winded and has dropped to its usual pace. Let it walk or stand a moment, or water it at a trough.") }
        } else if abs(pvx) < 50 {
            let atT = troughs.contains { abs($0 - px) < 11 }
            wind = min(1, wind + dt * (atT ? 1.5 : (rainI() > 0.2 ? 0.5 : (riding ? 0.1 : 0.2))))
            if atT && wind < 1 && chance(dt * 14) { parts.append(Part(x: px + pdir * 9 + rnd(-2, 2), y: -5, vx: rnd(-8, 8), vy: -rnd(8, 18), life: 0.4, max: 0.4, c: Col(0x9fd0e8), s: 1.4, grav: 60)) }
        }
        if blown && wind > 0.35 { blown = false }
        let horse = [78.0, 104, 118][min(2, stable.level)] * (fresh ? 1.28 : 1) * (shoes ? 1.06 : 1)      // the stable and the blacksmith
        let want = input.stick * horse
        pvx += (want - pvx) * min(1, dt * 7)
        if abs(pvx) < 2 && input.stick == 0 { pvx = 0 }
        px = clampD(px + pvx * dt * slowAt(px), WEST + 30, WORLD - 30)
        if abs(input.stick) > 0.1 { pdir = input.stick > 0 ? 1 : -1 }
        if abs(pvx) > 6 {
            pphase += dt * abs(pvx) * 0.16
            hoofT -= dt * abs(pvx) / 84
            if hoofT <= 0 { hoofT = 0.17; sfx?.hoof(0.6) }
            if chance(dt * 8) { parts.append(Part(x: px - pdir * 8, y: 0, vx: -pdir * rnd(4, 14), vy: rnd(-14, -4), life: 0.5, max: 0.5, c: Col(terrain.dust, 0.6), s: rnd(1, 2.4), grav: 10)) }
        }
        tossCD = max(0, tossCD - dt); tossT = max(0, tossT - dt)
        gunCD = max(0, gunCD - dt); gunT = max(0, gunT - dt); hurtT = max(0, hurtT - dt)
        if reloadT > 0 { reloadT -= dt; if reloadT <= 0 { ammo = 6; sfx?.reload() } }
        // both buttons repeat for as long as they are held
        if !input.toss { tossHold = false }
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

    /// Where the i-th coin slot over a building sits: world x, and height above the ground (negative is up).
    func slotXY(_ bl: Building, _ i: Int) -> (Double, Double) {
        let n = max(1, bl.cost), per = min(n, 10), rows = (n + per - 1) / per
        var tall = bl.def.h + Double(max(0, bl.level - 1)) * 5
        if bl.isHall && bl.level == 1 { tall = 26 }
        if bl.isHall && bl.level >= 2 { tall = 84 }
        var gap = 34.0
        if bl.def.gate || bl.wire || bl.isHall { gap = 12 } else if bl.virt { gap = 26 } else if bl.site { gap = 4 }
        let k = max(0, min(n - 1, i)), row = k / per
        let inRow = row == rows - 1 ? n - row * per : per
        return (bl.cx - Double(inRow - 1) * 3 + Double(k % per) * 6, -(tall + gap + Double(rows) * 6) + Double(row) * 6)
    }

    private var tossHold = false      // a coin went somewhere useful while the button has been held
    private func toss() {
        let had = coins
        var dropped = false
        defer { if coins < had && !dropped { tossHold = true } }
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
        var bd = 55.0
        let sigFirst = sigWants ? abs(sig.cx - px) : 9999
        for d in drifters where !d.taken {
            let dd = abs(d.x - px)
            if dd < bd && dd <= sigFirst { bd = dd; bestD = d }
        }
        if let d = bestD {
            d.taken = true
            let c = Coin(sx: px, sy: sy, tx: d.x, ty: -10, kind: 2); c.drifter = d
            flying.append(c); coins -= 1; sfx?.toss(); return
        }
        // 2: the racks beside the sheriff's office and the store
        let sh = sheriff, st = store
        for (rb, kind, what) in [(sh, 3, "badges"), (st, 5, "picks"), (stable, 7, "ropes")] where rb.level > 0 && !rb.building && abs(px - rackX(rb)) < 12 {
            let waiting = (rackN[rb.type] ?? 0) + flying.filter { $0.kind == kind }.count
            if waiting < 3 {
                flying.append(Coin(sx: px, sy: sy, tx: rackX(rb) + Double(waiting - 1) * 6, ty: -23, kind: kind)); coins -= 1; sfx?.toss()
            } else {
                tossCD = 0.5; sfx?.empty()
                hint("rackfull", "The rack holds three \(what). When a townsman takes one, there is room for another.", again: true)
            }
            return
        }
        // 3: an open bank keeps what you toss it, unless it can be improved, which comes first
        if atBank() && !(bankB.payable && bankB.paid + bankB.incoming < bankB.cost) {
            flying.append(Coin(sx: px, sy: sy, tx: bankB.cx, ty: -14, kind: 6)); coins -= 1; sfx?.toss(); return
        }
        // after dark, a coin patches a damaged gate, or goes toward a rifleman on a gatehouse roof
        if dark() > 0.3 {
            for g in [gateW, gateE] where g.level > 0 && g.hp > 0 && !g.building && abs(px - g.cx) < g.def.w / 2 + 12 {
                let full = GHP[min(3, g.level)]
                if g.hp + 8 * Double(g.incoming) < full {
                    let c = Coin(sx: px, sy: sy, tx: g.cx, ty: -10, kind: 8); c.bld = g
                    flying.append(c); g.incoming += 1; coins -= 1; sfx?.toss(); return
                }
                if g.level > 2 && g.rifles + g.incoming < 12 {
                    let c = Coin(sx: px, sy: sy, tx: g.cx, ty: -44, kind: 9); c.bld = g
                    flying.append(c); g.incoming += 1; coins -= 1; sfx?.toss(); return
                }
            }
        }
        // a coin at an open church rings the bell
        if has(church) && church.level > 0 && !church.building && !bell && church.incoming == 0 && (church.payable == false || dark() > 0.3) && abs(px - church.cx) < church.def.w / 2 + 12 {
            let c = Coin(sx: px, sy: sy, tx: church.cx, ty: -62, kind: 10)
            flying.append(c); church.incoming += 1; coins -= 1; sfx?.toss(); return
        }
        // 4: a building that can take coins, or the passenger car
        var best: Building?
        var bb = 9999.0
        for bl in b where bl.payable && bl.paid + bl.incoming < bl.cost {
            // the one you are most nearly in front of, however wide or narrow it is
            let dd = abs(bl.cx - px), reach = bl.def.w / 2 + 12
            if dd < reach && dd / reach < bb { bb = dd / reach; best = bl }
        }
        if let bl = best {
            // each coin goes to its own slot, in order
            let p = slotXY(bl, bl.paid + bl.incoming)
            bl.incoming += 1
            let c = Coin(sx: px, sy: sy, tx: p.0, ty: p.1, kind: 1); c.bld = bl
            flying.append(c); coins -= 1; sfx?.toss(); return
        }
        // 5: nothing here wants it, so it lands in the dust. Not while the button is still held from paying
        // for something, though: the purse closes when the last slot is filled.
        if tossHold { tossCD = 0.3; return }
        dropped = true
        flying.append(Coin(sx: px, sy: sy, tx: px + pdir * 18, ty: -1, kind: 0)); coins -= 1; sfx?.toss()
    }

    private func fire() {
        if reloadT > 0 || gunCD > 0 { return }
        if ammo <= 0 { sfx?.click(); gunCD = 0.4; return }
        // with dynamite in the saddlebag, a shot into a bunch of three or more raiders is a stick of it
        if dynamite > 0 {
            var tgt: Bandit?
            var bd = 150.0
            for bn in bandits where bn.hp > 0 && (bn.x - px) * pdir > 0 && abs(bn.x - px) < bd { bd = abs(bn.x - px); tgt = bn }
            if let tg = tgt, bandits.filter({ abs($0.x - tg.x) < 36 && $0.hp > 0 }).count >= 3 {
                dynamite -= 1; gunCD = 0.7; gunT = 0.16
                for bn in bandits where abs(bn.x - tg.x) < 46 { hurt(bn, 4) }
                for _ in 0..<26 { parts.append(Part(x: tg.x + rnd(-10, 10), y: -rnd(0, 14), vx: rnd(-70, 70), vy: -rnd(20, 90), life: rnd(0.4, 1), max: 1, c: chance(0.5) ? Col(0xffb040) : Col(0x4a4038), s: rnd(2, 4.5), grav: 120)) }
                sfx?.thunder(1); buzz(2); shake = 1.4; flash = 0.5
                hint("boom", dynamite > 0 ? "Dynamite! \(dynamite) left." : "Dynamite! That was your last stick.", again: true)
                return
            }
        }
        ammo -= 1; gunCD = 0.28; gunT = 0.14
        // he shoots the way he faces, unless the only raiders in range are behind him: then he turns in the saddle and shoots back
        var sd = pdir
        let ahead = bandits.contains { $0.hp > 0 && ($0.x - px) * pdir > 0 && abs($0.x - px) < 230 }
        let behind = bandits.contains { $0.hp > 0 && ($0.x - px) * pdir < 0 && abs($0.x - px) < 230 }
        if !ahead && behind { sd = -pdir }
        shotDir = sd
        shots.append(Shot(x: px + sd * 12, y: -20, vx: sd * 300, life: 0.5, mine: true))
        sfx?.gun(1); shake = max(shake, 0.4); buzz(1)
        parts.append(Part(x: px + sd * 14, y: -20, vx: sd * 20, vy: -6, life: 0.25, max: 0.25, c: Col(0xfff0b0), s: 2.5, grav: 0))
        if ammo == 0 { reloadT = Double(max(1, 5 - store.level - (loader ? 2 : 0))); reloadMax = reloadT }      // every level of the store takes a second off
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
                coins += 1; sfx?.pick(); buzz(0); ground.remove(at: i); continue
            }
            ground[i] = g
            i += 1
        }
        // a drifter marked for a coin that is no longer on its way is free again
        for d in drifters where d.taken && !flying.contains(where: { $0.drifter === d }) { d.taken = false }
        // a drifter walks over to any coin lying close by, picks it up, and is hired
        for d in drifters where !d.taken {
            var best = -1
            var bd = 140.0
            for (k, g) in ground.enumerated() where g.y <= 0 && g.age > 0.5 {
                let dd = abs(g.x - d.x)
                if dd < bd { bd = dd; best = k }
            }
            if best < 0 { continue }
            let gx = ground[best].x
            if bd > 3 { d.x += sgn(gx - d.x) * 38 * dt } else {
                ground.remove(at: best)
                let c = Coin(sx: d.x, sy: 0, tx: d.x, ty: 0, kind: 2)
                c.drifter = d
                land(c)
                break
            }
        }
        // coins part-paid into a building come back when you ride away
        for bl in b where bl.paid > 0 && !bl.building && bl.incoming == 0 && abs(bl.cx - px) > bl.def.w / 2 + 44 {
            for k in 0..<bl.paid {
                // each comes back out of the slot it went into, the last one in first
                let p = slotXY(bl, bl.paid - 1 - k)
                let c = Coin(sx: p.0, sy: p.1, tx: px, ty: -18, kind: 4)
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
            if bl.paid >= bl.cost && bl.site {
                siteDone(bl)
            } else if bl.paid >= bl.cost && bl.type == .coach {
                bl.paid = 0; bl.live = false
                coach?.guarded = true
                sfx?.recruit()
                hint("guard", "A shotgun guard climbs up beside the driver. If the stage gets through, the line pays you \(coachPay) coins at dawn.", again: true)
            } else if bl.paid >= bl.cost && bl.virt {
                bl.paid = 0; bl.live = false; board()
            } else if bl.paid >= bl.cost && bl.type == .sig {
                bl.paid = 0; bl.level = 1; bl.flash = 0.5
                sfx?.fanfare(); puff(bl.cx, -20, 18, GOLD, 60); buzz(2)
                let done: [String: String] = [
                    "redwater": "The ferry is back on the river. Tolls from the ford come in every dawn, and double after a flood.",
                    "timberline": "The saw is turning. Every other building in Timberline now costs a quarter less.",
                    "irongulch": "The smelter is lit. Prospectors bring 2 coins each at dawn now, but the smoke draws one more raider a night.",
                    "bitterend": "The fur trader is open. 2 coins at dawn, and 1 more for every rancher out on the trap lines."]
                hint("sig" + place, done[place] ?? "", again: true)
                onSave?()
            } else if bl.paid >= bl.cost && bl.type == .claim {
                bl.paid = 0; bl.level += 1; bl.flash = 0.4
                sfx?.fanfare(); puff(bl.cx, -12, 14, GOLD, 50)
                if bl.level == 1 { hint("claim1", "The claim is staked. An old prospector works it and leaves 4 coins there each dawn, unless raiders came from the west that night.", again: true) }
                else { hint("claim2", "A hired gun watches the claim. It pays 7 coins every dawn, whatever the night brings.", again: true) }
                onSave?()
            } else if bl.paid >= bl.cost {
                bl.paid = 0; bl.building = true; bl.progress = 0
                jobSeq += 1; bl.seq = jobSeq
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
            rackN[.sheriff, default: 0] += 1; sfx?.slot()
        case 5:
            rackN[.store, default: 0] += 1; sfx?.slot()
        case 8:
            if let g = c.bld { g.incoming -= 1; g.hp = min(GHP[min(3, g.level)], g.hp + 8); g.flash = 0.2; sfx?.hammer(1) }
        case 9:
            if let g = c.bld {
                g.incoming -= 1; g.rifles += 1; sfx?.slot()
                if g.rifles % 4 == 0 { sfx?.recruit(); hint("rifle", "A rifleman climbs onto the gatehouse roof for the night. \(g.rifles / 4) of 3.", again: true) }
            }
        case 10:
            church.incoming -= 1
            bell = true
            sfx?.bell(); church.flash = 0.3
            hint("bell", "The bell rings out. Everyone is running for cover, and the deputies are at their posts until dawn.", again: true)
        case 7:
            rackN[.stable, default: 0] += 1; sfx?.slot()
        case 6:
            bank += 1; sfx?.slot(); bankB.flash = 0.2
            hint("deposit", "Banked. Raiders cannot knock banked coins out of you, and the bank pays 1 a day for every 8 inside, up to 3.")
        case 4:
            coins += 1; sfx?.pick(); buzz(0)
        default:
            ground.append(GCoin(x: c.tx, y: 0, vx: 0, vy: 0, age: 0))
        }
    }

    /// Whatever hangs on a rack, the nearest townsman with nothing to do walks over and takes.
    private func updRacks(_ dt: Double) {
        for rb in [sheriff, store, stable] where (rackN[rb.type] ?? 0) > 0 && rb.level > 0 {
            let rx = rackX(rb)
            guard let f = nearestIdle(rx), !f.hidden else { continue }
            let dx = rx - f.x
            if abs(dx) > 3 {
                f.dir = sgn(dx); f.x += f.dir * 46 * dt; f.tx = rx; f.moving = true; f.phase += dt * 9
                continue
            }
            rackN[rb.type, default: 1] -= 1
            sfx?.fanfare(); puff(rx, -16, 6, GOLD, 30)
            switch rb.type {
            case .sheriff: f.role = .deputy; hint("deputy", "A deputy. At night he stands at the gate the raiders are coming to, and shoots.")
            case .store: f.role = .miner; hint("miner", "A prospector. He works the old mine west of town and brings a coin back each morning.")
            default: f.role = .rancher; f.tend = 0; hint("rancher", "A rancher. They raise cattle in the pasture east of town, and each grown cow pays 2 coins at dawn.")
            }
        }
    }

    private func nearestIdle(_ x: Double) -> Folk? {
        var best: Folk?
        var bd = 99999.0
        for f in folk where f.role == .folk && !f.sick {
            let d = abs(f.x - x)
            if d < bd { bd = d; best = f }
        }
        return best
    }

    /// The one site the crew is working: the first paid-for building in the town's order.
    func site() -> Building? { return b.filter { $0.building }.min { $0.seq < $1.seq } }
    private var jobSeq = 0

    private func updFolk(_ dt: Double) {
        let s = site()
        let night = dark() > 0.4 || !bandits.isEmpty || bell
        var dep = 0
        var plain = 0
        var ranch = 0
        let ranchers = folk.filter { $0.role == .rancher }.count
        for f in folk {
            f.work = false
            f.shotCD = max(0, f.shotCD - dt)
            if f.sick {         // laid up at the doctor's until morning
                let d = doctor.x + 14 - f.x
                if abs(d) > 2 { f.dir = d > 0 ? 1 : -1; f.x += f.dir * 36 * dt; f.phase += dt * 9; f.moving = true } else { f.hidden = true; f.moving = false }
                continue
            }
            f.hidden = bell && f.role != .deputy && abs(f.x - f.tx) < 4
            if rallyOn {
                // everyone falls in behind you, torches up, and keeps pace with the horse
                let i = Double(folk.firstIndex { $0 === f } ?? 0)
                f.tx = px - pdir * (18 + i * 7 + (f.seed.truncatingRemainder(dividingBy: 1)) * 3)
                f.hidden = false
                let d = f.tx - f.x
                f.moving = abs(d) > 2
                if f.moving { f.dir = d > 0 ? 1 : -1; f.x += f.dir * min(abs(d) * 3, 120) * dt; f.phase += dt * 13 }
                continue
            }
            switch f.role {
            case .deputy:
                if night {
                    f.tx = side < 0 ? 976 + Double(dep) * 9 : gateE.x - 10 - Double(dep) * 9
                    var tgt: Bandit?
                    var bd = ((sheriff.level >= 2 ? 215.0 : 170.0) + (forge.level >= 1 ? 40 : 0)) * sightK()
                    for bn in bandits where bn.st != 3 {
                        let d = abs(bn.x - f.x)
                        if d < bd { bd = d; tgt = bn }
                    }
                    // beyond a hundred paces he closes on his man, never leaving the gates
                    if let bn = tgt, bd > 100 { f.tx = clampD(bn.x, gateW.x + 18, gateE.x - 6) }
                    if let bn = tgt, f.shotCD <= 0, bd <= 100 || abs(f.x - f.tx) < 3 {
                        f.shotCD = sheriff.level >= 2 ? 0.75 : 1
                        f.dir = bn.x > f.x ? 1 : -1
                        shots.append(Shot(x: f.x + f.dir * 4, y: -9, vx: f.dir * 300, life: abs(bn.x - f.x) / 300, mine: false))
                        sfx?.gun(0.5)
                        if chance(forge.level >= 1 ? 0.68 : 0.56) { hurt(bn, sheriff.level >= 3 ? 2 : 1) }
                    }
                } else if f.wait <= 0 && !f.moving { f.tx = sheriff.cx + rnd(-50, 50); f.wait = rnd(3, 8) }
                dep += 1
            case .rancher:
                if t > 0.06 && t < 0.62 {
                    f.tx = pasture.0 + 12 + Double(ranch % 4) * 20
                    if abs(f.x - f.tx) < 3 {
                        // a rancher adds a calf to the herd every so often, two head each and three with the bigger stable
                        f.tend += dt
                        if f.tend > 30 {
                            f.tend = 0
                            if bio != .snow && herd.count < min(12, ranchers * (1 + stable.level)) {      // cattle will not calve in the snow
                                addCow(calf: true)
                                hint("calf", "A calf in the pasture. It starts paying tomorrow morning.")
                            }
                        }
                    }
                } else { f.tx = stable.x + 10 + Double(ranch % 5) * 9 }
                ranch += 1
            case .miner:
                if t > 0.06 && t < 0.6 { f.tx = MINE_X + Double(Int(f.seed) % 5) * 6 } else { f.tx = store.x + 20 + Double(Int(f.seed) % 4) * 8 }
            case .folk:
                if let st = s {
                    f.tx = st.x + 6 + Double(plain % 5) * (st.def.w - 12) / 5
                    if abs(f.x - f.tx) < 3 { f.work = true }
                } else if bell { f.tx = saloon.cx + Double(plain % 5) * 5 - 10       // indoors
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
        updRacks(dt)
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
            buzz(2)
            if bl.def.gate { bl.hp = GHP[min(bl.level, 3)] }
            sfx?.fanfare(); flash = 0.4
            puff(bl.cx, -bl.def.h / 2, 16, GOLD, 50)
            // everyone turns out: streamers off the roof, and rockets for the big days
            let cols: [UInt32] = [0xb53a2e, 0xead7a4, 0x3f5fa0, 0xf2c14e, 0x5d8a4e]
            let streamers = bl.type == .saloon && bl.level == 1 ? 70 : (bl.def.wall != 0 ? 34 : 14)
            for k in 0..<streamers {
                parts.append(Part(x: bl.cx + rnd(-bl.def.w / 2, bl.def.w / 2), y: -bl.def.h - rnd(0, 12), vx: rnd(-34, 34), vy: -rnd(25, 80), life: rnd(1.1, 2.2), max: 2.2, c: Col(cols[k % 5]), s: rnd(1.4, 2.4), grav: 95))
            }
            if bl.isHall || bl.level > 2 || bl.type == .station || (bl.type == .saloon && bl.level == 1) {
                for k in 0..<(bl.isHall ? 5 : 3) {
                    let fx = bl.cx + rnd(-50, 50), fy = -(bl.def.h + 34 + rnd(0, 34)), fc = Col(cols[(k + 3) % 5])
                    for j in 0..<20 {
                        let an = Double(j) / 20 * 2 * PI, sp = rnd(28, 70)
                        parts.append(Part(x: fx, y: fy, vx: cos(an) * sp, vy: sin(an) * sp, life: rnd(0.7, 1.3), max: 1.3, c: j % 4 == 0 ? Col(0xfff0c0) : fc, s: 1.7, grav: 42))
                    }
                }
                sfx?.gun(0.35); sfx?.ding()
            }
            switch bl.type {
            case .store: hint("store1", "The store is open and pays out every morning. Toss a coin at the tool rack on its left to outfit a prospector.")
            case .saloon: hint("saloon1", "The saloon is open. It pays out every morning and draws new drifters to the camps.")
            case .sheriff: hint("sheriff1", "The sheriff's office is open. Toss a coin at the badge rack on its right and a townsman will pin it on.")
            case .gateW, .gateE:
                if bl.level >= 3 { hint("gate3", "A gatehouse with a Gatling gun on the roof. It cuts down whatever comes at that side.") }
                else { hint("gate1", "A gate. Raiders have to break it down before they can reach the town.") }
            case .hall:
                if bl.level == 1 { hint("hall1", "A town square. Buildings and gates can now be improved to their second level.") }
                else { hint("hall2", "A clock tower. Buildings can reach their third level, and the railroad will come to a town like this once the station is rebuilt.") }
            case .wireW, .wireE:
                hint("wire\(bl.level)", ["Barbed wire. It slows raiders on that side and throws riders from their horses.", "A second apron of wire. It slows them more and cuts whoever crosses it.", "A sharpshooter is dug in behind the wire. He picks raiders off before they reach the gate."][min(2, bl.level - 1)])
            case .church: hint("church1", "The church is raised. Toss a coin at it to ring the bell: everyone runs indoors and the deputies man the gates.")
            case .bordello: hint("bordello1", "The bordello is open. It pays out every morning and draws newcomers to the camps.")
            case .forge: hint("forge\(bl.level)", bl.level == 1 ? "The blacksmith is at work. Deputies shoot further and miss less." : "New shoes all round: your horse is faster.", again: true)
            case .telegraph: hint("telegraph1", "The telegraph is working. At dusk it tells you which side the raid will come from.")
            case .stable: hint("stable\(bl.level)", bl.level == 1 ? "The stable is open and your horse gallops faster. Toss a coin at the rope rack on its right to hire a rancher." : "A bigger stable. Your horse is faster still, and ranchers can keep three head each.", again: true)
            case .bank: hint("bank1", "The bank is open. Hold the coin button in front of it to pay coins in, where raiders cannot get them.")
            case .station:
                train = Train(x: WORLD + 70, v: -120)
                sfx?.whistle()
                hint("station1", "The station is up, and the rails are through. Here comes the train.", again: true)
            default: hint("built", "Built. Toss more coins at it to improve it.")
            }
            checkStar()
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
        let n = raidSize(d) + (place == "irongulch" && sigOn && raidSize(d) > 0 ? 1 : 0)      // smoke from the smelter draws them
        if n == 0 { hint("dusk1", "Night is coming. The first night is quiet; raiders come from the second."); return }
        for i in 0..<n {
            let main = (town > 0 ? i % 3 : i % 2) != 0        // down the line, two in three come from the same side
            raid.append(RaidSpawn(t: 0.74 + rnd(0, 0.09), side: bio == .canyon ? 1 : (main ? side : -side), rider: d >= 4 && i % 3 == 2, hp: d / 4))
        }
        // from the fourth night here, every third night an outlaw boss rides with them
        let ln = day - day0
        let boss = ln >= 4 && ln % 3 == 1
        if boss { raid.append(RaidSpawn(t: 0.79, side: side, rider: false, hp: d / 2, boss: true)) }
        // from the eighth night, every fifth night a gang of horsemen charges one end of town
        let gang = ln >= 8 && ln % 5 == 3
        if gang { for _ in 0..<min(2 + ln / 2, 14) { raid.append(RaidSpawn(t: 0.77 + rnd(0, 0.05), side: side, rider: true, hp: d / 4)) } }
        raidOn = true; raided = true
        var scouted = ""
        if scoutDays > 0 && raid.count > 1 {
            var k = 0
            var j = raid.count - 1
            while j >= 0 && k < 2 { if !raid[j].boss { raid.remove(at: j); k += 1 }; j -= 1 }
            scouted = " The scouts ambushed \(k) raiders on the trail; the rest are coming from the \(side < 0 ? "west" : "east")."
        } else if scoutDays > 0 { scouted = " The scouts say they are coming from the \(side < 0 ? "west" : "east")." }
        sfx?.sting()
        if gang { hint("gang", "A gang of horsemen is riding in from the \(side < 0 ? "west" : "east") tonight. Wire and a strong gate on that side will break the charge.", again: true); return }
        if boss { hint("boss", "An outlaw boss rides with them tonight. There is a bounty of 8 coins on him.", again: true); return }
        let where_ = !scouted.isEmpty ? scouted : (telegraph.level > 0 ? " The telegraph says most will come from the \(side < 0 ? "west" : "east")." : "")
        hint("raid", "Raiders tonight.\(where_) Hold the gun button to shoot. You fire at raiders ahead of you, or turn in the saddle for any behind.", again: true)
    }

    private func dawn() {
        duskDone = false; raidOn = false; raid = []
        for bn in bandits { bn.st = 3 }
        var total = 0
        var paid: [(String, Int)] = []   // what each source paid this morning, for the takings card; -1 marks one that was robbed
        for bl in b where bl.def.pay > 0 && bl.level > 0 {
            if bl.robbed { bl.robbed = false; paid.append((nice(bl.def.name), -1)); continue }
            let n = max(1, bl.def.pay * bl.level - (day - day0 > 2 ? 1 : 0))
            for _ in 0..<n { dropCoin(bl.x + bl.def.doorX + bl.def.doorW / 2, 10) }
            total += n
            paid.append((nice(bl.def.name), n))
        }
        let plain = folk.filter { $0.role == .folk }.count
        for _ in 0..<(plain / 2) { dropCoin(FIRE_X + rnd(-20, 20), 6); total += 1 }
        if plain / 2 > 0 { paid.append(("Townsfolk", plain / 2)) }
        let diggers = folk.filter { $0.role == .miner }.count
        let per = place == "irongulch" && sigOn ? 2 : 1          // the smelter pays double for ore
        for f in folk where f.role == .miner { for _ in 0..<per { dropCoin(store.x + 30, 8) }; total += per; f.wait = 0 }
        if diggers > 0 { paid.append(("Mine", diggers * per)) }
        if sigOn && (place == "redwater" || place == "bitterend") {
            let n = place == "redwater" ? (flood >= day - 1 ? 6 : 3) : 2 + folk.filter { $0.role == .rancher }.count
            for _ in 0..<n { dropCoin(sig.cx, 8) }
            total += n; paid.append((place == "redwater" ? "Ferry" : "Furs", n))
        }
        if town > 0 {
            let interest = min(3 * bankB.level, bank / 8)
            bank += interest
            if interest > 0 { paid.append(("Bank interest", interest)) }
        }
        // each grown cow pays 2 coins, and last night's calves are grown
        let p = pasture
        if ground.filter({ $0.x > p.0 - 20 && $0.x < p.1 + 20 }).count < 12 {
            let before = total
            for cw in herd where !cw.calf { dropCoin(cw.x, 4); dropCoin(cw.x, 4); total += 2 }
            if total > before { paid.append(("Cattle", total - before)) }
        }
        for i in herd.indices { herd[i].calf = false }
        // the claim pays at dawn, unless raiders came by from the west and nobody was guarding it
        var note = ""
        if claim.level > 0 {
            if claim.level < 2 && raided && side < 0 { note = " Raiders from the west cleaned out the claim overnight; a hired gun would keep it safe." }
            else { let n = claim.level > 1 ? 7 : 4; for _ in 0..<n { dropCoin(claim.cx, 5) }; total += n; paid.append(("Claim", n)) }
        }
        raided = false
        // out of town: the scouts' days run down, the ruins settle, the derrick pays, the show comes and goes
        if scoutDays > 0 { scoutDays -= 1 }
        if ruinCool > 0 { ruinCool -= 1 }
        fortNight = false; cav = []
        bell = false; gateW.rifles = 0; gateE.rifles = 0
        for f in folk { f.sick = false; f.hidden = false }
        bankB.robbed = false
        if carCool > 0 { carCool -= 1 }
        ghostX = nil; ufo = nil
        ufoAt = day - day0 >= 2 && chance(0.36) ? rnd(0.8, 0.93) : 0
        ghostAt = chance(0.4) ? rnd(0.82, 0.96) : 0
        if rigLv > 0 && !rigBurn { for _ in 0..<rigPay { dropCoin(FIRE_X + rnd(-12, 12), 6) }; total += rigPay; paid.append((rigNames.2, rigPay)) }
        let lnW = day - day0
        showOn = lnW >= 2 && lnW % 4 == 2; showUsed = false
        if showOn { note += " A medicine show has pulled up west of town. He is gone by morning." }
        mustangs.removeAll { $0.st == 3 }
        if lnW % 2 == 0 && mustangs.count < 3 { let r = mustangRange; mustangs.append(Mustang(x: rnd(r.0 + 20, r.1 - 20), seed: rnd(0, 100))) }
        // the stage line settles up, the wash drains, and the day's news
        if owed > 0 { for _ in 0..<owed { dropCoin(coachSlot.x + 19, 6) }; total += owed; paid.append(("Stage line", owed)); owed = 0 }
        if flood > 0 && flood < day && bio != .snow {
            flood = 0
            for _ in 0..<(5 + town) { ground.append(GCoin(x: rnd(river.0 + 2, river.1 - 2), y: 0, vx: 0, vy: 0, age: 1)) }
            note += " The wash has run dry again, and left gold in the gravel east of town."
        }
        let lnD = day - day0
        if strays.count < 3 { let r = strayRange; let x = rnd(r.0 + 20, r.1 - 20); strays.append(Stray(x: x, tx: x, seed: rnd(0, 100))) }
        if lnD >= 5 && lnD % 5 == 0 {
            duelDay = day
            note += " \(DUELISTS[(day + town) % DUELISTS.count]) has called you out: high noon, on main street. Fire as the marker crosses the star."
        }
        if town > 0 {
            if let o = outlaw {
                o.days -= 1
                if o.days <= 0 { outlaw = nil; note += " The wanted man slipped out of the territory." }
            }
            if outlaw == nil && sheriff.level > 0 && lnD >= 3 && lnD % 4 == 3 {
                let west = chance(0.5)
                let o = Outlaw(x: west ? missionX : archX, side: west ? -1 : 1, name: OUTLAWS[Int(rnd(0, Double(OUTLAWS.count) - 0.01))], reward: 8 + 2 * town)
                outlaw = o
                note += " Wanted: \(o.name), holed up at the \(west ? "old mission west" : "rock arch east") of town. \(o.reward) coins, dead or alive."
            }
            // the stage comes through every third day
            if lnD % 3 == 2 && coach == nil {
                coach = Coach(x: gateW.x - 380)
                note += " The stagecoach is coming in from the west: toss \(coachSlot.cost) coins at it by the saloon and a guard rides with it."
            }
        }
        // the saloon draws drifters back to the camps
        for (i, c) in camps.enumerated() {
            let here = drifters.filter { $0.camp == i }.count
            if here < c.1 && chance(saloon.level > 0 ? 0.5 : 0.15) {         // half as often as in the web game
                drifters.append(Drifter(x: c.0 - 14 + Double(here) * 13 + rnd(-2, 2), camp: i))
            }
        }
        // the bordello draws a newcomer a day for each of its levels
        for _ in 0..<bordello.level where chance(0.5) {
            if let i = camps.indices.first(where: { i in drifters.filter { $0.camp == i }.count < camps[i].1 + 1 }) {
                let here = drifters.filter { $0.camp == i }.count
                drifters.append(Drifter(x: camps[i].0 - 14 + Double(here) * 13 + rnd(-2, 2), camp: i))
            }
        }
        side = bio == .canyon || chance(0.5) ? 1 : -1       // a canyon has one way in, from the east
        note += rollWx()
        sfx?.dawn(); buzz(1)
        // trade through town adds a fifth again to whatever the morning brought
        let extra = total > 0 ? max(1, Int((Double(total) * 0.2).rounded())) : 0
        if extra > 0 { for _ in 0..<extra { dropCoin(FIRE_X + rnd(-24, 24), 7) }; total += extra; paid.append(("Trade", extra)) }
        // the takings go up on a card; the line of text carries only the day's news
        dawnRows = paid; dawnTotal = total; dawnSeq += 1
        // no line of text at dawn: the coin card says it all
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
            if tripT > 2.6 && !choosing {
                // the first town is free; the rest of the line is asked for here
                if town == 0 && !unlocked {
                    if !payAsk {
                        payAsk = true
                        if !seen.contains("st_locked") { seen.insert("st_locked"); cut = STORY["locked"] ?? [] }
                    }
                    return
                }
                // straight on if there is only one way, or stop at the fork and ask
                if lastTown { tripT = -1; fade = 0; train = Train(x: STOP, v: 0); ticket.live = false; return }
                let opts = stageOf(town + 1)
                if opts.count < 2 { arrive(opts[0]) } else { choosing = true }
            }
            return
        }
        if tr.v == 0 {
            if chance(dt * 1.2) { smoke(tr.x + 16) }
            if tr.wait > 0 {
                tr.wait -= dt
                if tr.wait <= 0 && lastTown {
                    train = tr
                    hint("railend", "End of the line. The rails stop here, and so does Crane.", again: true)
                    onSave?()
                    return
                }
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

    /// In the last town: gather enough townsfolk, then lead them out the east gate to run Crane off.
    /// Why the last town won't march yet, or "" when it will.
    var rallyBlock: String {
        // its own mark: older builds marked the game ended when the last town was fully built, which must not stop this
        if !lastTown || endNow || seen.contains("cranegone") { return "done" }
        let n = folk.filter { !$0.sick }.count
        if n < RALLY_N { return "Townsfolk: \(n) of \(RALLY_N). Gather \(RALLY_N) to run Crane out of Bitter End." }
        if dark() > 0.5 { return "Bitter End is ready. They will march at first light." }
        if duel != nil || gallery != nil || !cut.isEmpty { return "wait" }
        return ""
    }
    var rallyT = 0.0
    /// Crane's company yard, out past the east gate of the last town: where the march ends.
    var yardMen: [Bandit] = []
    var routT = -1.0             // his men have seen the town coming and are running
    /// The same, for drawing: once Crane is gone the yard stays as he left it, even in a game loaded later.
    var routShow: Double { return routT < 0 && seen.contains("cranegone") ? 99 : routT }
    var toTitle = false          // after the last scene, back to the title
    var holdRout: Double?        // test stills only: keep the rout at one moment
    var demoT: Double?           // test stills only: hold the time of day
    /// Crane's buggy: waiting by his office, then away east once he is in it.
    var buggyX: Double { let x0 = craneX + 74, u = min(8, max(0, routShow - 1.5)); return x0 + u * 30 + u * u * 55 }
    var craneX: Double { return EX(2490) }      // on the cavalry outpost's ground, which the last town doesn't have

    private func updRally(_ dt: Double) {
        if rallyBlock == "done" { return }
        if !rallyOn {
            // they gather only once you ride out the east gate; until then the town gets on with its work
            if rallyBlock.isEmpty && px > gateE.x + 20 {
                rallyT = 0
                rallyOn = true; buzz(2); sfx?.fanfare(); flash = 0.3
                hint("rally", "Bitter End comes out behind you, torches up. Keep riding east: they will follow you to Crane\u{2019}s yard.", again: true)
            }
            return
        }
        // turn back into town, or let night fall, and they go back to work
        if routT >= 0 {
            // his men run for it, the town cheers, and the sky over the yard goes up in rockets
            let was = routT
            routT += dt
            if let h = holdRout { routT = h }
            for m in yardMen { m.st = 3; m.x += (m.rider ? 120 : 75) * dt; m.phase += dt * (m.rider ? 9 : 12) }
            for at in [0.9, 1.7, 2.5, 3.2] where was < at && routT >= at {
                let cols: [UInt32] = [0xb53a2e, 0xead7a4, 0x3f5fa0, 0xf2c14e, 0x5d8a4e]
                for k in 0..<2 {
                    let fx = craneX + rnd(-90, 40), fy = -(70 + rnd(0, 40)), fc = Col(cols[Int(at * 3 + Double(k)) % 5])
                    for j in 0..<24 { let an = Double(j) / 24 * 2 * PI, sp = rnd(30, 75); parts.append(Part(x: fx, y: fy, vx: cos(an) * sp, vy: sin(an) * sp, life: rnd(0.8, 1.4), max: 1.4, c: j % 4 == 0 ? Col(0xfff0c0) : fc, s: 1.8, grav: 40)) }
                }
                sfx?.gun(0.35); buzz(1)
            }
            if was < 1.2 && routT >= 1.2 { sfx?.fanfare() }
            // the picture closes in on the yard, holds, and eases back out before the last scenes
            zoom = 1 + 0.24 * smooth(0, 0.7, routT) - 0.24 * smooth(3.4, 4.6, routT)
            if was < 0.7 && routT >= 0.7 {
                // hats in the air all down the crowd
                let hc: [UInt32] = [0x6a4a2e, 0x3a2a1c, 0x8a6a44, 0xc9a86a]
                for (k, f) in folk.enumerated() where k % 2 == 0 { parts.append(Part(x: f.x, y: -30, vx: rnd(-14, 14), vy: -rnd(70, 110), life: 1.6, max: 1.6, c: Col(hc[k % 4]), s: 2.6, grav: 110)) }
                sfx?.ding()
            }
            if routT > 4.8 {
                zoom = 1; endNow = true; rallyOn = false; toTitle = true
                seen.insert("cranegone"); seen.remove("st_end")       // the ending plays now, even if an older build already showed one
                onSave?()
            }
            return
        }
        if dark() > 0.5 || px < gateE.x - 40 { rallyOn = false; return }
        rallyT += dt
        if px > craneX - 90 {
            routT = 0; flash = 0.35; buzz(2); sfx?.gun(0.5)
            hint("rout", "Crane\u{2019}s men see the whole town coming and run for it!", again: true)
            return
        }
        // sparks off the torches as they go
        for f in folk where chance(0.05) { parts.append(Part(x: f.x - f.dir * 4, y: -24, vx: rnd(-8, 8), vy: -rnd(10, 30), life: 0.6, max: 0.6, c: Col(0xffb04a), s: 1, grav: 0)) }
    }

    /// Bitter End is the end of the line: the train comes in, but goes no further.
    var lastTown: Bool { return town % STAGES.count == STAGES.count - 1 }

    /// Bought: the train carries on.
    func payDone() { unlocked = true; payAsk = false }
    /// Not now: back on the platform with the ticket money, and the train waiting.
    func payLater() {
        payAsk = false; tripT = -1; fade = 0
        coins += ticket.cost
        train = Train(x: STOP, v: 0); ticket.paid = 0; ticket.live = true
        hint("paylater", "You step back down with your ticket money. The train will wait: Dustfall is yours to keep building.", again: true)
    }

    /// The ticket is paid: the train pulls out east with you aboard.
    private func board() {
        tripT = 0
        sfx?.whistle()
        hintT = 0
        bandits = []; raid = []; raidOn = false
    }

    /// Stepping off at the next dead town. Only coins make the trip; the town you built stays behind.
    func arrive(_ dest: String) {
        let carry = carryOut()
        choosing = false
        log.append(place); place = dest
        town += 1; day += 1; day0 = day - 1; t = 0.08
        layTown()
        nameSeq += 1
        coins = carry + (town % STAGES.count == STAGES.count - 1 ? 8 : 0); bank = 0      // the last town is the hardest: a few more to start on
        fade = 1
        let news = [1: "a stable and a bank", 2: "a bordello and a doctor", 3: "a church and a blacksmith", 4: "a telegraph office"]
        let extra = (news[town].map { " This town has \($0) to open as well." } ?? "") + (sigName.isEmpty ? "" : " Its trade is the \(sigName.lowercased()), \(place == "redwater" ? "at the ford east of town" : (place == "bitterend" ? "at the east end of main street" : "outside the west gate")).")
        hint("arrive\(town)", "\(nice(townName)): \(here.land.lowercased()). \(here.note) You step off with \(carry) coins, and everything here is boarded up.\(extra)" + (lastTown ? " No train comes past here. Gather \(RALLY_N) townsfolk and run Crane out." : ""), again: true)
        onSave?()
    }

    private func updRaid(_ dt: Double) {
        var i = 0
        while i < raid.count {
            if t >= raid[i].t {
                let r = raid[i]
                var x = r.side < 0 ? 600 - rnd(0, 120) : EX(2300) + rnd(0, 120)
                // never out of thin air: if you are out there watching, they come in from past the edge of the view
                if x > cam - 30 && x < cam + W + 30 { x = r.side < 0 ? cam - 30 - rnd(0, 60) : cam + W + 30 + rnd(0, 60) }
                let bn = Bandit(x: x, rider: r.rider, side: r.side, hp: (r.boss ? 12 : (r.rider ? 3 : 2)) + r.hp)
                bn.boss = r.boss
                bn.torch = !r.boss && chance(0.4)
                bn.rustle = !r.boss && chance(0.4)
                bandits.append(bn)
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
                if bn.boss {
                    for _ in 0..<8 { dropCoin(bn.x, 10) }
                    sfx?.fanfare(); flash = 0.3
                    hint("bounty", "The outlaw is down, and the bounty is yours: 8 coins where he fell.", again: true)
                }
                puff(bn.x, -8, 8, Col(0x3a2a1c), 34)
                bandits.remove(at: i); continue
            }
            bn.flash = max(0, bn.flash - dt); bn.hitT = max(0, bn.hitT - dt)
            // the outlaw shoots back, and a hit costs a deputy his badge unless there is a doctor in town
            if bn.boss && bn.st != 3 {
                bn.cd2 -= dt
                if bn.cd2 <= 0 {
                    var tgt: Folk?
                    var bd = 150.0
                    for f in folk where f.role == .deputy {
                        let d = abs(f.x - bn.x)
                        if d < bd { bd = d; tgt = f }
                    }
                    if let f = tgt {
                        bn.cd2 = 2.4
                        let dir = f.x > bn.x ? 1.0 : -1.0
                        shots.append(Shot(x: bn.x + dir * 6, y: -10, vx: dir * 300, life: max(0.05, bd / 300), mine: false))
                        sfx?.gun(clampD(1 - abs(bn.x - px) / 320, 0.15, 1) * 0.6)
                        if chance(0.3) {
                            puff(f.x, -8, 5, Col(0xd04a3a), 26)
                            if doctor.level > 0 { hint("patched", "A deputy was hit. The doctor patched him up and he keeps his badge.", again: true) }
                            else { f.role = .folk; hint("badge", "A deputy was shot down and has lost his badge. He is a townsman again: put another badge on the rack, and open the doctor's to keep them on their feet.") }
                        }
                    }
                }
            }
            // barbed wire on their side slows them to a crawl and throws riders, who carry on on foot
            let wr = bn.side < 0 ? wireW : wireE
            let snag = bn.st == 0 && wr.level > 0 && bn.x > wr.x - 2 && bn.x < wr.x + wr.def.w + 2
            if snag && bn.rider {
                bn.rider = false
                puff(bn.x, -6, 12, Col(0xe2c08c), 40)
                hint("thrown", "The wire threw a rider. He is on foot now.")
            }
            if snag && !bn.cut {
                bn.cut = true
                if wr.level > 1 { hurt(bn, wr.level - 1) }       // the second apron cuts whoever crosses it
            }
            let wade = slowAt(bn.x) * (bio == .snow && !bn.rider ? 0.8 : 1)      // the ford, and deep snow for men on foot
            let sp = (bn.boss ? 30.0 : (bn.rider ? 74.0 : 40.0)) * (snag ? [1, 0.4, 0.34, 0.28][min(3, wr.level)] : 1) * wade
            let gate = bn.side < 0 ? gateW : gateE
            let gx = gate.cx
            switch bn.st {
            case 1:
                if gate.level == 0 { bn.st = 0 } else {
                    gate.hp -= dt * (bn.boss ? 2 : (bn.rider ? 1.5 : 1))
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
                    if !tg.robbed && tg.level > 0 {
                        tg.robbed = true; bn.loot = 2; sfx?.rob(); buzz(2); hint("robbed", "A raider robbed a business. It will pay nothing in the morning unless you shoot him before he gets away.", again: true)
                        if bn.torch && rainI() < 0.3 { setFire(tg, "A torch has set") }
                    }
                    bn.st = 3
                }
            case 3:
                bn.x += bn.side * sp * 1.15 * dt
                bn.phase += dt * 10
                if bn.x < 300 || bn.x > EX(2600) { bandits.remove(at: i); continue }
            default:
                let dir = -bn.side
                let outside = bn.side < 0 ? bn.x < gx - 9 : bn.x > gx + 9
                // as in the web game: a coin lying loose is worth a detour, and so is a rider with a purse.
                // A standing gate still stops him, so he only goes after what is on his own side of it.
                func near(_ wx: Double) -> Bool { let o = bn.side < 0 ? wx < gx - 9 : wx > gx + 9; return o == outside || gate.level == 0 }
                bn.face = 0
                if !bn.boss && !bn.rustle {
                    var gi = -1, gd = 55.0
                    for (k, gc) in ground.enumerated() where gc.y <= 0.5 && abs(gc.x - bn.x) < gd && near(gc.x) { gd = abs(gc.x - bn.x); gi = k }
                    if gi >= 0 {
                        let dx = ground[gi].x - bn.x
                        if abs(dx) < 3 { ground.remove(at: gi); bn.loot += 1; bn.st = 3; sfx?.pick() }
                        else { bn.face = sgn(dx); bn.x += sgn(dx) * sp * dt; bn.phase += dt * (bn.rider ? 12 : 9) }
                        i += 1
                        continue
                    }
                }
                if !bn.rustle && tripT < 0 && bn.hitT <= 0 && abs(px - bn.x) < 75 && abs(px - bn.x) >= 8 && near(px) {
                    bn.face = sgn(px - bn.x)
                    bn.x += bn.face * sp * dt; bn.phase += dt * (bn.rider ? 12 : 9)
                    i += 1
                    continue
                }
                // rustlers go for a cow in the pasture
                if bn.rustle, let ci = herd.firstIndex(where: { !$0.run && abs($0.x - bn.x) < 80 }) {
                    let dx = herd[ci].x - bn.x
                    if abs(dx) < 4 {
                        herd.remove(at: ci); bn.loot += 2; bn.st = 3
                        puff(bn.x, -4, 6, Col(terrain.dust), 30)
                        hint("rustle", "Rustlers took a cow from the pasture.", again: true)
                    } else { bn.x += sgn(dx) * sp * dt; bn.phase += dt * 9 }
                    i += 1
                    continue
                }
                if !outside, let dp = folk.first(where: { $0.role == .deputy && !$0.sick && !$0.hidden && abs($0.x - bn.x) < 12 }), chance(dt * 0.3) {
                    // close work inside the walls: a deputy goes down. With a doctor he is back at dawn; without one he hands in his badge
                    sfx?.hit(0.8); puff(dp.x, -8, 5, Col(0x8a2b22), 26); buzz(2)
                    if doctor.level > 0 { dp.sick = true; hint("depdown", "A deputy was shot down. The doctor has him, and he keeps his badge.") }
                    else { dp.role = .folk; hint("badge", "A deputy was shot down and has lost his badge. He is a townsman again: put another badge on the rack, and open the doctor's to keep them on their feet.") }
                }
                if !outside {
                    // a townsman caught in the open is run off, or put in the doctor's care
                    var vic: Folk?
                    var vd = 60.0
                    for f in folk where f.role != .deputy && !f.hidden && !f.sick {
                        let d = abs(f.x - bn.x)
                        if d < vd { vd = d; vic = f }
                    }
                    if let f = vic {
                        if vd < 4 {
                            if doctor.level > 0 { f.sick = true; hint("patched2", "The doctor took them in. They will be back on their feet at dawn.", again: true) }
                            else {
                                folk.removeAll { $0 === f }
                                var ci = 0
                                var cd = 99999.0
                                for (k, cp) in camps.enumerated() where abs(cp.0 - f.x) < cd { cd = abs(cp.0 - f.x); ci = k }
                                drifters.append(Drifter(x: f.x, camp: ci))
                                hint("mug", "A bandit ran one of your townsfolk off. The doctor, the church bell and deputies keep them safe.", again: true)
                            }
                            bn.loot += 1; bn.st = 3; sfx?.empty()
                        } else { bn.x += sgn(f.x - bn.x) * sp * dt; bn.phase += dt * 9 }
                        i += 1
                        continue
                    }
                    // an outlaw boss goes for a bank that can still be robbed
                    if bn.boss && has(bankB) && bankB.level == 1 && bank > 0 && !bankB.robbed {
                        let dx = bankB.cx - bn.x
                        if abs(dx) < 4 {
                            let n = min(bank, 10)
                            bank -= n; bn.loot += n; bankB.robbed = true; bn.st = 3
                            sfx?.box()
                            hint("bankrob", "The outlaw robbed the bank. Shoot him down before he gets away and the coins are yours again.", again: true)
                        } else { bn.x += sgn(dx) * sp * dt; bn.phase += dt * 9 }
                        i += 1
                        continue
                    }
                }
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
                bn.hitT = 2; hurtT = 1.2; shake = 1; flash = 0.3; sfx?.hit(1)
                if coins <= 0 && bank <= 0 {
                    // caught without a coin to your name
                    over = true
                    return
                }
                if coins <= 0 {
                    let n = min(5, bank)
                    bank -= n; bn.loot += n; bn.st = 3
                    hint("paidoff", "Your purse was empty, so the bandit took \(n) from the bank instead. With nothing in either, you are run out of town.", again: true)
                } else {
                    let n = min(coins, bn.boss ? 5 : (bn.rider ? 4 : 3))
                    coins -= n
                    for _ in 0..<n { dropCoin(px, 14) }
                    hint("knock", "Robbed. Keep your distance and shoot. If they catch you with an empty purse and nothing in the bank, you are run out of town.")
                }
            }
            i += 1
        }
    }

    /// The Gatling gun on a gatehouse roof, and the sharpshooter behind third-level wire.
    private func updGuns(_ dt: Double) {
        if bandits.isEmpty { return }
        func volley(_ from: Building, _ h: Double, _ reach: Double, _ every: Double, _ odds: Double, _ loud: Double, _ dmg: Int) {
            from.cd -= dt
            if from.cd > 0 { return }
            var tgt: Bandit?
            var bd = reach
            for bn in bandits where bn.st != 3 && bn.hp > 0 {
                let d = abs(bn.x - from.cx)
                if d < bd { bd = d; tgt = bn }
            }
            guard let bn = tgt else { return }
            from.cd = every
            let dir = bn.x > from.cx ? 1.0 : -1.0
            shots.append(Shot(x: from.cx + dir * 4, y: -h, vx: dir * 300, life: max(0.05, bd / 300), mine: false))
            sfx?.gun(loud * clampD(1 - abs(from.cx - px) / 320, 0.15, 1))
            if chance(odds) { hurt(bn, dmg) }
        }
        // the web game's numbers: the Gatling reaches 200 and fires six rounds a second at four in ten; the nest reaches 190
        for g in [gateW, gateE] where g.level >= 3 && g.hp > 0 { volley(g, 40, 200 * sightK(), 0.17, 0.4, 0.3, 1) }
        for w in [wireW, wireE] where w.level >= 3 { volley(w, 9, 190 * sightK(), 1.1, 0.75, 0.5, 2) }
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
                if !gone, let o = outlaw, abs(o.x - s.x) < 8, o.hp > 0 {
                    o.hp -= 1; o.flash = 0.18; gone = true
                    puff(o.x, -10, 4, Col(0x8a2b22), 26); sfx?.hit(1)
                }
            }
            if gone { shots.remove(at: i) } else { shots[i] = s; i += 1 }
        }
    }

    // ---------- the stagecoach: in from the west, a stop in town, then out east past the rock arch, where road agents wait
    private func updCoach(_ dt: Double) {
        guard var c = coach else { coachSlot.live = false; return }
        func roll(_ tx: Double, _ v: Double) -> Bool {
            let dx = tx - c.x
            let vx = sgn(dx) * min(v, abs(dx) * 2 + 8)
            c.x += vx * dt; c.phase += abs(vx) * dt * 0.16; c.moving = abs(vx) > 2
            return abs(dx) < 1.5
        }
        c.fl = max(0, c.fl - dt)
        switch c.st {
        case 0:
            if roll(coachSlot.x + 19, 60) { c.st = 1; c.t = 0; c.moving = false }
        case 1:
            c.t += dt
            if c.guarded && c.gt == 0 { c.gt = c.t }
            if c.t > (c.guarded ? c.gt + 1.2 : 24) || t > 0.5 { c.st = 2 }
        case 2:
            if !c.done && c.x >= EX(2400) {
                c.st = 3; c.t = 0; c.moving = false; c.rob = [true, true]
                sfx?.sting()
            } else {
                _ = roll(WORLD + 90, 74)
                if c.x > WORLD + 70 { coach = nil; coachSlot.live = false; return }
            }
        default:
            let t0 = c.t
            c.t += dt
            if c.guarded {
                let beats: [(Double, Int)] = [(0.5, 0), (1.0, 0), (1.5, 1), (2.0, 1)]
                for (at, i) in beats where t0 < at && c.t >= at {
                    c.fl = 0.08
                    sfx?.gun(clampD(1 - abs(c.x - px) / 320, 0.15, 1))
                    shots.append(Shot(x: c.x + 18, y: -24, vx: 300, life: 0.13, mine: false))
                    if i < c.rob.count && (at == 1.0 || at == 2.0) { c.rob[i] = false; puff(c.x + 44 + Double(i) * 14, -8, 8, Col(0x3a2a1c), 34) }
                }
                if c.t > 2.5 {
                    c.st = 2; c.done = true; c.rob = []
                    owed += coachPay
                    hint("coachsafe", "The guard saw off a hold-up at the rock arch. The stage line pays you \(coachPay) coins at dawn.", again: true)
                }
            } else if c.t > 1.3 {
                for k in 0..<2 {
                    let bn = Bandit(x: c.x + 44 + Double(k) * 14, rider: false, side: 1, hp: 2)
                    bn.st = 3; bn.loot = (coachPay + k) / 2
                    bandits.append(bn)
                }
                c.rob = []; c.st = 2; c.done = true
                sfx?.box()
                hint("coachrob", "Road agents held up the stage at the rock arch and made off with the strongbox. Shoot them down before they get away and it is yours.", again: true)
            }
        }
        coachSlot.live = c.st == 1 && !c.guarded
        coach = c
    }

    // ---------- wanted posters
    private func updOutlaw(_ dt: Double) {
        guard let o = outlaw else { return }
        o.flash = max(0, o.flash - dt)
        if o.hp <= 0 {
            for _ in 0..<o.reward { dropCoin(o.x, 6) }
            puff(o.x, -8, 10, Col(0x3a2a1c), 34)
            sfx?.fanfare()
            hint("collected", "\(o.name) is down. The bounty is on the ground.", again: true)
            outlaw = nil
            return
        }
        let dp = px - o.x
        if abs(dp) > 130 { return }
        o.dir = dp >= 0 ? 1 : -1
        hint("draw", "He has seen you. Shoot first: every hit he lands knocks coins from your purse.")
        o.cd -= dt
        if o.cd > 0 { return }
        o.cd = 1.6
        let hit = chance(abs(pvx) > 70 ? 0.25 : 0.5)
        shots.append(Shot(x: o.x + o.dir * 7, y: -10, vx: o.dir * 300, life: hit ? abs(dp) / 300 : abs(dp) / 300 + 0.1, mine: false))
        sfx?.gun(0.7)
        if !hit { return }
        shake = max(shake, 0.6); flash = 0.25; sfx?.hit(1); hurtT = 0.6
        let n = min(2, coins)
        coins -= n
        for _ in 0..<n { dropCoin(px, 14) }
    }

    // ---------- high noon
    private func startDuel() {
        px = FIRE_X - 52; pdir = 1; pvx = 0
        duelDay = -day
        duel = Duel(oppX: px + 96, name: DUELISTS[(day + town) % DUELISTS.count])
        cam = clampD(px + 48 - W / 2, WEST, WORLD - W)
        fade = 1
        bandits = []; raid = []
        hint("duel", "High noon. \(duel!.name) faces you down the street. Wait for the marker, then tap the gun as it crosses the star.", again: true)
    }

    private func updDuel(_ dt: Double) {
        guard var d = duel else { return }
        let press = input.fire && !d.held
        d.held = input.fire
        d.t += dt
        gunT = max(0, gunT - dt)
        func lose(_ why: String) {
            let n = coins / 2
            coins -= n
            d.st = 2; d.end = d.t + 3.4
            shots.append(Shot(x: d.oppX - 8, y: -10, vx: -300, life: 0.3, mine: false))
            sfx?.gun(1); sfx?.hit(1); flash = 0.3; shake = 0.6; hurtT = 0.8
            hint("duelend", "\(why) \(d.name) takes \(n) \(n == 1 ? "coin" : "coins") from your purse and rides out.", again: true)
        }
        if d.st == 0 {
            if d.t >= 2.3 {
                d.st = 1; d.t0 = d.t
                d.per = max(1.5, 2.3 - 0.16 * Double(town)); d.hw = max(0.12, 0.2 - 0.016 * Double(town))
                d.hits = 0; d.pos = -1
            }
        } else if d.st == 1 {
            let u = ((d.t - d.t0) / d.per).truncatingRemainder(dividingBy: 1)
            d.pos = u < 0.5 ? u * 4 - 1 : 3 - u * 4
            if press && d.t - d.t0 > 0.3 {
                let off = abs(d.pos)
                if off <= d.hw || (off <= d.hw * 2.4 && d.hits > 0) {
                    let n = 10 + 3 * town
                    d.st = 2; d.end = d.t + 3.4; d.oppUp = false
                    gunT = 0.16; sfx?.gun(1); shake = 0.3
                    shots.append(Shot(x: px + 9, y: -22, vx: 300, life: 0.28, mine: false))
                    puff(d.oppX, -10, 10, Col(0xd04a3a), 40)
                    for _ in 0..<n { dropCoin(d.oppX, 6) }
                    sfx?.fanfare()
                    hint("duelend", "\(d.name) is down. The \(n)-coin bounty is yours.", again: true)
                    duelWon = true
                } else if off <= d.hw * 2.4 {
                    d.hits = 1; d.per *= 0.86; d.t0 = d.t - d.per * ((d.pos + 1) / 4)
                    gunT = 0.16; sfx?.gun(1); shake = 0.2
                    shots.append(Shot(x: px + 9, y: -22, vx: 300, life: 0.28, mine: false))
                    puff(d.oppX, -12, 4, Col(0xd04a3a), 26)
                    hint("duelend", "You wing him. \(d.name) is still standing. Once more.", again: true)
                } else { lose("Your shot goes wide.") }
            } else if d.t - d.t0 > d.per * 4.5 { lose("Too slow.") }
        } else if d.t > d.end {
            duel = nil; gunCD = 0.6; hintT = min(hintT, 1)
            return
        }
        duel = d
    }

    // ---------- stray longhorns: ride right up to one and it follows you, to your pasture or into town to sell
    private func updStrays(_ dt: Double) {
        var slot = 0.0
        var i = 0
        let r = strayRange, p = pasture
        while i < strays.count {
            var w = strays[i]
            if w.tame {
                let tx = px - pdir * (20 + slot * 13)
                slot += 1
                let dx = tx - w.x, sp = min(70, abs(dx) * 4)
                if abs(dx) > 2 { w.dir = sgn(dx); w.x += w.dir * sp * dt; w.phase += dt * sp * 0.12 }
                let room = has(stable) && stable.level > 0 && herd.count < 12
                if room && w.x > p.0 && w.x < p.1 {
                    herd.append(Cow(x: w.x, tx: w.x, calf: false, seed: w.seed))
                    sfx?.recruit(); puff(w.x, -10, 8, GOLD, 30)
                    hint("strayjoin", "The stray joins your herd.", again: true)
                    strays.remove(at: i); continue
                }
                if !room && w.x > gateW.x + 24 && w.x < gateE.x - 10 {
                    for _ in 0..<3 { dropCoin(w.x, 8) }
                    sfx?.recruit()
                    hint("straysell", "The stray sells in town for 3 coins. With a stable and room in the pasture, it would join your herd instead.", again: true)
                    strays.remove(at: i); continue
                }
            } else {
                if abs(px - w.x) < 12 && tripT < 0 {
                    w.tame = true
                    sfx?.pick()
                    hint("stray", "A stray longhorn. It follows you now: drive it to your pasture, or into town to sell.")
                }
                w.t -= dt
                if w.t <= 0 { w.tx = rnd(r.0 + 10, r.1 - 10); w.t = rnd(5, 12) }
                let dx = w.tx - w.x
                if abs(dx) > 1 && w.t < 4 { w.dir = sgn(dx); w.x += w.dir * 7 * dt; w.phase += dt * 5 }
            }
            strays[i] = w
            i += 1
        }
    }

    private func updHerd(_ dt: Double) {
        let p = pasture
        for i in herd.indices {
            var cw = herd[i]
            if cw.run { continue }
            cw.wait -= dt
            if cw.x > p.1 + 4 { cw.dir = -1; cw.x -= 30 * dt; cw.phase += dt * 10; herd[i] = cw; continue }      // walking back after a stampede
            if cw.wait <= 0 && abs(cw.x - cw.tx) < 1 { cw.tx = rnd(p.0 + 8, p.1 - 8); cw.wait = rnd(4, 12) }
            let d = cw.tx - cw.x
            if abs(d) >= 1 && cw.wait < 3 { cw.dir = d > 0 ? 1 : -1; cw.x += cw.dir * 7 * dt; cw.phase += dt * 5 }
            herd[i] = cw
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

    /// One line of advice: the next useful thing to spend on.
    func advice() -> String {
        if state != .play || over || !cut.isEmpty || gallery != nil || duel != nil || choosing { return "" }
        if dark() > 0.5 { return raidOn ? "Tonight: hold the gates until dawn." : "" }
        if TESTBUILD && lastTown && rallyBlock != "done" && folk.filter({ !$0.sick }).count >= RALLY_N {
            // test builds: say exactly where the march stands, so a stuck ending can be pinned down
            let n = folk.filter { !$0.sick }.count, rb = rallyBlock
            let why = rb.isEmpty ? "none" : (rb == "done" ? "done" : (rb == "wait" ? "scene/duel/gallery" : (dark() > 0.5 ? "night" : "folk")))
            return "TEST march: folk \(n)/\(RALLY_N) \u{00B7} \(dark() > 0.5 ? "night" : "day") \u{00B7} \(rallyOn ? (routT >= 0 ? "routing" : "marching") : "waiting") \u{00B7} block \(why) \u{00B7} gate \(Int(gateE.x - px)) \u{00B7} yard \(Int(craneX - px))"
        }
        if folk.isEmpty { return "Next: toss a coin to a drifter at a campfire outside town." }
        if lastTown && rallyBlock != "done" {
            if rallyOn { return routT >= 0 ? "" : "Keep riding east to Crane\u{2019}s yard: the town is behind you." }
            let why = rallyBlock
            if why.isEmpty { return "Bitter End is ready. Ride out the east gate and they will follow you to run Crane off." }
            if why != "wait" && why != "done" && (folk.count >= RALLY_N || !why.hasPrefix("Townsfolk")) { return why }
            if folk.count >= RALLY_N / 2 { return "Townsfolk: \(folk.count) of \(RALLY_N). Gather \(RALLY_N) to run Crane out of Bitter End." }
        }
        if rackN.values.contains(where: { $0 > 0 }) && !folk.contains(where: { $0.role == .folk && !$0.sick }) { return "Next: the racks are full but no townsman is free. Hire a drifter at a campfire." }
        if let st = site(), !folk.contains(where: { $0.role == .folk && !$0.sick }) {
            return "Next: nobody is free to build the \(st.label.lowercased()). Hire a drifter, or take a badge or pick back in Crew."
        }
        let first: [Building] = [saloon, store, sheriff, gateW, gateE, stable, bankB]
        for bl in first where has(bl) && bl.level == 0 && !bl.building && bl.payable { return "Next: open the \(bl.label.lowercased()) (\(bl.cost) coins)." }
        if sheriff.level > 0 && !sheriff.building && !folk.contains(where: { $0.role == .deputy }) { return "Next: a badge from the rack beside the sheriff's makes a deputy (1 coin)." }
        if store.level > 0 && !store.building && !folk.contains(where: { $0.role == .miner }) { return "Next: a pick from the rack beside the store makes a prospector (1 coin)." }
        if b.contains(where: { $0.building }) { return "" }
        if hall.payable { return "Next: improve the town centre (\(hall.cost) coins), so buildings can grow." }
        let open = b.filter { !$0.virt && !$0.site && $0.payable }
        if let bl = open.filter({ $0.level == 0 }).min(by: { $0.cost < $1.cost }) { return "Next: open the \(bl.label.lowercased()) (\(bl.cost) coins)." }
        if let bl = open.min(by: { $0.cost < $1.cost }) { return "Next: improve the \(bl.label.lowercased()) (\(bl.cost) coins)." }
        if star { return "Next: the town has its star. Take the train on when you are ready." }
        return ""
    }

    /// The line at the bottom of the screen: what the rider is standing at.
    private func updInfo() {
        info = ""; slotsFor = nil
        let sigFirst = sigWants ? abs(sig.cx - px) : 9999
        for d in drifters where abs(d.x - px) < 55 && abs(d.x - px) <= sigFirst && !d.taken { info = "Drifter: 1 coin to hire"; return }
        let sh = sheriff, st = store
        let free = folk.contains { $0.role == .folk && !$0.sick }
        func waiting(_ bl: Building, _ what: String) -> String {
            let n = rackN[bl.type] ?? 0
            if n == 0 { return "" }
            return free ? " \(n) on the rack." : " \(n) on the rack, but no townsman is free to take \(n == 1 ? "it" : "one"): hire a drifter, or release someone under Menu, Crew."
        }
        if sh.level > 0 && !sh.building && abs(px - rackX(sh)) < 12 { info = "Badge rack: 1 coin a badge, three at most. A townsman who takes one guards the gates at night." + waiting(sh, "badge"); return }
        if st.level > 0 && !st.building && abs(px - rackX(st)) < 12 { info = "Tool rack: 1 coin a pick, three at most. Each prospector brings 1 coin to the store door every dawn." + waiting(st, "pick"); return }
        if stable.level > 0 && !stable.building && abs(px - rackX(stable)) < 12 { info = "Rope rack: 1 coin a rope, three at most. Ranchers raise cattle that pay 2 coins each a day." + waiting(stable, "rope"); return }
        var best: Building?
        var bd = 9999.0
        for bl in b where (!bl.virt || bl.live) && (bl.type != .sShow || showOn) {
            let d = abs(bl.cx - px), reach = bl.def.w / 2 + 12
            if d < reach && d / reach < bd { bd = d / reach; best = bl }
        }
        guard let bl = best else { return }
        if bl.def.gate && bl.level > 0 && bl.hp > 0 && !bl.building && dark() > 0.3 {
            if bl.hp < GHP[min(3, bl.level)] { info = "\(bl.label): 1 coin patches some of the damage."; return }
            if bl.level > 2 && bl.rifles < 12 { info = "Gatehouse: 4 coins hires a rifleman for tonight. Up to three (\(bl.rifles / 4) hired, \(bl.rifles % 4) of 4 in)."; return }
        }
        if bl.type == .church && bl.level > 0 && !bl.building && !(bl.payable && dark() <= 0.3) {
            info = bell ? "Church: the bell has been rung. Everyone is under cover until dawn." : "Church bell: 1 coin. Everyone runs indoors and deputies man the gates until dawn."
            return
        }
        if bl.burning { info = "\(bl.label): on fire! " + (towerLv > 0 ? "The brigade is on it." : "Townsfolk are fighting it by hand."); return }
        if bl.site {
            if bl.payable { slotsFor = bl }
            info = siteInfo(bl)
            return
        }
        if bl.type == .coach {
            slotsFor = bl
            info = "Stagecoach: \(bl.cost) coins hires a guard" + (bl.paid > 0 ? " (\(bl.paid) in)" : "") + ". If the stage gets through, you are paid \(coachPay) at dawn."
            return
        }
        if bl.virt {
            slotsFor = bl
            info = "Train ticket: \(bl.cost) coins" + (bl.paid > 0 ? " (\(bl.paid) in)" : "") + ". You step off at the next town with \(carryOut()): half of purse and bank, never under 8 or over 25."
            return
        }
        if bl.type == .bank && bl.level > 0 && !bl.building && !(bl.payable && bl.level < bl.maxLevel) {
            info = "Bank: \(bank) inside, safe from raiders. Hold the coin button to pay in; with an empty purse it hands 5 back."
            return
        }
        if bl.type == .station && bl.level > 0 && !bl.building {
            info = train == nil ? "Station: the train is on its way." : "Station: the train waits as long as you like. The ticket is paid at the passenger car."
            return
        }
        let nm = bl.label
        if bl.type == .station && bl.capped {
            info = "Station: the railroad will not come until the town is ready. Still to do: \(todo().joined(separator: ", "))."
            return
        }
        if bl.capped {
            info = "\(nm): needs the \(hall.level == 0 ? "town square" : "clock tower") before it can be improved."
            return
        }
        if bl.isHall && bl.level < bl.maxLevel && !bl.building {
            slotsFor = bl
            info = (bl.level == 0 ? "Town centre: \(bl.cost) coins for a town square, so buildings can reach level 2" : (bl.level == 1 ? "Town centre: \(bl.cost) coins for a clock tower, so buildings can reach level 3\(lastTown ? "" : " and the railroad can come")" : "Town centre: \(bl.cost) coins for a bell and a gilded dial, so buildings can reach their last level")) + (bl.paid > 0 ? " (\(bl.paid) in)" : "")
            return
        }
        if bl.type == .sig {
            if bl.level >= 1 { info = "\(sigName): open. \(sigWhat)"; return }
            slotsFor = bl
            info = "\(sigName): \(bl.cost) coins to open it. \(sigWhat)"
            return
        }
        if bl.type == .claim {
            if bl.level >= bl.maxLevel { info = "Claim: guarded. It pays 7 coins every dawn."; return }
            slotsFor = bl
            info = (bl.level == 0 ? "Old claim: \(bl.cost) coins to stake. A prospector then leaves 4 coins here each dawn" : "Claim: \(bl.cost) coins for a hired gun. It then pays 7 a day, whatever the night brings") + (bl.paid > 0 ? " (\(bl.paid) in)" : "")
            return
        }
        if bl.wire && !bl.building && bl.level < bl.maxLevel {
            slotsFor = bl
            info = "Barbed wire: \(bl.cost) coins. " + ["Slows raiders and throws riders off their horses.", "Slows them more and cuts whoever crosses.", "Adds a sharpshooter who picks raiders off."][min(2, bl.level)] + (bl.paid > 0 ? " (\(bl.paid) in)" : "")
            return
        }
        if bl.building {
            info = site() === bl ? "\(nm): being built. More townsfolk build it faster." : "\(nm): paid for. The crew starts here when the job in hand is finished."
        } else if bl.level >= bl.maxLevel {
            info = "\(nm): as good as it gets." + (bl.def.pay > 0 ? " Pays out every morning." : "")
        } else {
            slotsFor = bl
            let verb = bl.level == 0 ? (bl.def.gate ? "to build" : (bl.type == .station ? "to rebuild, and bring the railroad" : "to open")) : "to improve"
            // what the money buys, said before it is spent
            let buys: [BType: [String]] = [
                .store: ["Pays up to 4 coins every morning, and its tool rack outfits prospectors.", "Pays up to 8 a morning, and you reload a second faster.", "Pays up to 12 a morning, and you reload faster still.", "Pays up to 16 a morning, and you reload fastest."],
                .saloon: ["Pays up to 3 coins every morning, and brings drifters back to the camps.", "Pays up to 6 a morning.", "Pays up to 9 a morning.", "Pays up to 12 a morning."],
                .sheriff: ["Its badge rack turns townsfolk into deputies, who guard the gates at night.", "Deputies see further and shoot faster.", "Deputies' shots hit twice as hard.", "The grandest office on the line."],
                .stable: ["A faster horse, a rope rack for ranchers, and a place to break mustangs.", "A faster horse still.", "The finest stable on the line."],
                .bank: ["Keeps your coins safe from raiders and pays a little interest each dawn.", "Pays more interest.", "Pays the most interest."],
                .gateW: ["Stops raiders from the west until they break it down.", "A stronger gate.", "A gatehouse with a Gatling gun, and riflemen for hire at night."],
                .gateE: ["Stops raiders from the east until they break it down.", "A stronger gate.", "A gatehouse with a Gatling gun, and riflemen for hire at night."],
                .station: ["Brings the railroad, and with it the train to the next town."],
                .bordello: ["Draws a newcomer to the camps most days.", "Draws more newcomers.", "Draws more still.", "Draws the most."],
                .doctor: ["Townsfolk hurt in a raid are back at dawn, and deputies who are shot keep their badges.", "The best care on the line."],
                .church: ["A coin rings its bell at night: everyone gets indoors and deputies man the gates.", "A finer church."],
                .forge: ["Deputies shoot further and miss less.", "New shoes: your horse is faster.", "The best smith on the line."],
                .telegraph: ["Tells you which side tonight's raid is coming from.", "A finer office."]
            ]
            let line = buys[bl.type].map { $0[min(bl.level, $0.count - 1)] } ?? (bl.level > 0 && bl.def.pay > 0 ? "Pays out every morning." : "")
            info = "\(nm): \(bl.cost) coins \(verb)" + (bl.paid > 0 ? " (\(bl.paid) in)" : "") + (line.isEmpty ? "" : ". " + line)
        }
    }
}
