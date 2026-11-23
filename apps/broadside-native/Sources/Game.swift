import Foundation

enum Mode { case title, island }

/// Broadside, native. This build is the whole home island: the pier, beach, town, headland and east valley,
/// with fishing, rowing, hauling, selling, the coin-pour upgrades, paid buildings with three levels,
/// daily income, crew, and night raids. Rules ported from broadside/index.html.
final class Game {
    var W = 844.0
    var H = 390.0
    var safeL = 10.0
    var safeR = 10.0
    var safeB = 8.0
    var snd: Sound?
    var buzz: ((Bool) -> Void)?
    var T = 0.0
    var mode: Mode = .title

    // the world
    var tod = 0.3
    var day = 1
    var camX = -100.0
    var camS = 1.0
    var baseY = 300.0
    var shake = 0.0
    let DAY_LEN = 100.0
    let XMIN = -230.0
    let XEND = 3470.0

    // the player
    var px = -150.0
    var tx = -150.0
    var face = 1.0
    var speed = 0.0
    var walkPh = 0.0
    var coins = 0
    var fish = 0
    var shells = 0
    var shellV = 0
    var crates = 5
    var tales = 0
    var hauled = false
    var dog = false
    var dogX = -8.0
    var dogSp = 0.0
    var dogFace = 1.0
    var dogPh = 0.0

    // what has been bought, built, burnt and saved up
    var done: Set<String> = []
    var dmg: Set<String> = []
    var paid: [String: Int] = [:]
    var pile: [String: Int] = [:]
    var lvlOf: [String: Int] = [:]
    var goods: [String: Int] = [:]
    var items: [Item] = []
    var raidIn = 5
    var raidT = -1.0
    var raidDone = false
    var raidFlash = 0.0
    var heroOn = true
    var slowWalk = false
    var born: [Int: Double] = [:]
    var rainAmt: Double { return clampD((sin(T * 0.021 - 1.5) - 0.84) * 9, 0, 1) }

    // fishing: 0 wait, 1 fight, 2 land
    var fishing = false
    var fishPhase = 0
    var fishT = 0.0
    var fishWait = 2.5
    var fishFight = 1.2
    var fishV = 1
    var fishDeep = false
    var capShow = 0.0

    // a trip out in the boat: 0 none, 1 out, 2 fishing, 3 back
    var rowPhase = 0
    var rowX = -215.0
    var rowN = 0

    // hauling a crate: 0 none, 1 walking to it, 2 carrying
    var haul = 0

    // pouring coins
    var upgs: [Upg] = []
    let bld: [String: Bld] = ["hut": Bld(x: 520, inc: 3, def: 0), "mill": Bld(x: 2745, inc: 6, def: 0), "farm": Bld(x: 2850, inc: 5, def: 0), "smithy": Bld(x: 3130, inc: 4, def: 1), "tower": Bld(x: 2275, inc: 0, def: 2), "battery": Bld(x: 2215, inc: 0, def: 3), "wall": Bld(x: 3270, inc: 0, def: 2), "dock2": Bld(x: 3420, inc: 8, def: 0)]
    let bldOrder = ["hut", "mill", "farm", "smithy", "tower", "battery", "wall", "dock2"]
    let goodsOf: [String: String] = ["hut": "salt fish", "mill": "timber", "farm": "grain", "smithy": "iron"]
    let spots: [Spot] = [Spot(id: "dog", x: -8, near: 50), Spot(id: "fish", x: -215, near: 60), Spot(id: "row", x: -215, near: 60), Spot(id: "haul", x: 90, near: 60), Spot(id: "wright", x: 370, near: 60), Spot(id: "market", x: 1000, near: 60), Spot(id: "tavern", x: 1250, near: 60), Spot(id: "look", x: 2100, near: 70)]
    let tales_: [String] = ["\"…and the Black Sail took three prizes in a week, lad. Three!\"", "\"Keep your powder dry and your rum drier, that's what old Hendrik said.\"", "\"A captain with no lookout is a captain who meets the enemy at pistol range.\"", "\"Tortuga Cay — now there's a port. Gold runs in the gutters, or so they say.\"", "\"The sea gives. The sea takes. Mostly takes.\"", "\"Bow-on she's a sliver of a target, boy. Broadside she's a wall of guns. Choose.\""]
    let looks: [String] = ["Far out, a black sail crosses the horizon. One day.", "Gulls, swell, and nothing but sea to the edge of the world.", "A merchantman beats upwind toward Tortuga Cay. Heavy with cargo, no doubt.", "The old cannon still points to sea. Someone defended this place once."]
    let pads: [(Double, Double, Double)]
    var pour: String?
    var pourAcc = 0.0
    var pourT = 0.0
    var rings: [Ring] = []
    var spinId = ""
    var spinT = 0.0

    var log = ""
    var logT = 0.0
    var banner = ""
    var bannerT = 0.0
    var sparks: [Spark] = []
    var pops: [Pop] = []
    var saveT = 0.0
    var titleBtn: (Double, Double, Double, Double) = (0, 0, 0, 0)

    var light: Double { return clampD(0.5 + 0.9 * sin((tod - 0.23) * 2 * PI), 0, 1) }
    var fishCap: Int { return done.contains("fishcart") ? 12 : 5 }
    var boat: Int {
        var n = 0
        for i in 1...5 where done.contains("boat" + String(i)) { n = i }
        return n
    }
    var mates: Int {
        var n = 0
        for i in 1...10 where done.contains("mate" + String(i)) { n = i }
        return n
    }
    var stage: Int { return boat >= 3 ? 2 : (boat >= 2 ? 1 : 0) }
    var xmax: Double { return done.contains("dock2") ? XEND + 70 : XEND }
    var shipCrew: Int { return boat >= 5 ? 10 : (boat >= 4 ? 8 : 6) }
    var shipName: String { return boat >= 5 ? "frigate" : (boat >= 4 ? "brig" : "sloop") }
    var raiding: Bool { return raidT >= 0 }

    init() {
        let raw: [(Double, Double)] = [(55, 50), (350, 84), (520, 34), (1000, 62), (1100, 36), (1180, 14), (1250, 86), (1400, 44), (1480, 34), (1560, 56), (1690, 26), (2110, 76), (2215, 30), (2275, 24), (2745, 54), (2850, 42), (2960, 70), (3130, 44)]
        pads = raw.map { ($0.0 - $0.1, $0.0 + $0.1, $0.0) }
        buildUpgs()
        respawnItems()
        load()
    }

    func buildUpgs() {
        var u: [Upg] = [
            Upg(id: "rod", x: -190, cost: 8, icon: "rod"), Upg(id: "bait", x: -160, cost: 10, icon: "bait"),
            Upg(id: "fishcart", x: -60, cost: 14, icon: "fishcart"), Upg(id: "cart", x: 120, cost: 12, icon: "wheel"),
            Upg(id: "sack", x: 300, cost: 10, icon: "sack"), Upg(id: "boat1", x: 330, cost: 40, icon: "row"),
            Upg(id: "boat2", x: 330, cost: 150, icon: "skiff"), Upg(id: "deal", x: 1040, cost: 15, icon: "scales"),
            Upg(id: "nets", x: -120, cost: 30, icon: "net"), Upg(id: "lantern", x: -215, cost: 25, icon: "lamp"),
            Upg(id: "hook", x: 400, cost: 45, icon: "hook"),
            Upg(id: "mate1", x: 1300, cost: 20, icon: "mate"), Upg(id: "mate2", x: 1300, cost: 25, icon: "mate"),
            Upg(id: "mate3", x: 1300, cost: 30, icon: "mate"), Upg(id: "mate4", x: 1300, cost: 35, icon: "mate"),
            Upg(id: "mate5", x: 1300, cost: 40, icon: "mate"), Upg(id: "mate6", x: 1300, cost: 45, icon: "mate"),
            Upg(id: "boat3", x: 330, cost: 300, icon: "ship"),
            Upg(id: "hut", x: 520, cost: 30, icon: "bhut"), Upg(id: "mill", x: 2745, cost: 60, icon: "saw"),
            Upg(id: "farm", x: 2850, cost: 50, icon: "wheat"), Upg(id: "smithy", x: 3130, cost: 80, icon: "anvil"),
            Upg(id: "tower", x: 2275, cost: 70, icon: "tower"), Upg(id: "battery", x: 2215, cost: 120, icon: "cannon"),
            Upg(id: "wall", x: 3270, cost: 90, icon: "wall"), Upg(id: "dock2", x: 3420, cost: 100, icon: "skiff"),
            Upg(id: "light", x: -180, cost: 120, icon: "light"),
            Upg(id: "boat4", x: 330, cost: 600, icon: "ship"), Upg(id: "boat5", x: 330, cost: 1400, icon: "ship"),
            Upg(id: "mate7", x: 1300, cost: 60, icon: "mate"), Upg(id: "mate8", x: 1300, cost: 70, icon: "mate"),
            Upg(id: "mate9", x: 1300, cost: 90, icon: "mate"), Upg(id: "mate10", x: 1300, cost: 100, icon: "mate"),
            Upg(id: "provisions", x: 1000, cost: 60, icon: "barrel"), Upg(id: "powder", x: 2120, cost: 90, icon: "cannon"),
            Upg(id: "charts", x: 1250, cost: 80, icon: "chart")
        ]
        for id in bldOrder {
            guard let b = bld[id], let u0 = u.first(where: { $0.id == id }) else { continue }
            for n in [2, 3] {
                let mul: Double = n == 2 ? 1.5 : 2.5
                let cost = Int((Double(u0.cost) * mul).rounded())
                u.append(Upg(id: id + String(n), x: b.x, cost: cost, icon: u0.icon, tier: n, base: id))
            }
        }
        upgs = u
    }

    // ---------- the lie of the land (world y is negative upward; the sea is at 0)
    func groundRaw(_ x: Double) -> Double {
        if x < 0 { return 0 }
        if x < 600 { return -x * 0.03 }
        if x < 900 { return -18 - (x - 600) / 300 * 52 }
        if x < 1700 { return -70 - (x - 900) * 0.045 + sin(x * 0.02) * 3 }
        if x < 2050 { return -106 - (x - 1700) * 0.36 }
        if x < 2300 { return -232 - sin((x - 2050) * 0.03) * 4 }
        if x < 2700 { return -232 + (x - 2300) / 400 * 150 + sin(x * 0.03) * 2 }
        if x < 3280 { return -82 + (x - 2700) * 0.02 + sin(x * 0.02) * 3 }
        if x < 3470 { return lerp(-70, -3, (x - 3280) / 190) }
        return lerp(-3, 70, min(1, (x - 3470) / 140))
    }
    /// Building plots are levelled; between them the ground eases back to the natural slope.
    func ground(_ x: Double) -> Double {
        if x < 0 || x > 3300 { return groundRaw(x) }
        let B = 30.0
        var L: (Double, Double, Double)?
        var R: (Double, Double, Double)?
        for p in pads {
            if x >= p.0 && x <= p.1 { return groundRaw(p.2) }
            if p.1 < x { L = p } else if R == nil && p.0 > x { R = p }
        }
        let raw = groundRaw(x)
        if let l = L, let r = R, r.0 - l.1 < 2 * B {
            return lerp(groundRaw(l.2), groundRaw(r.2), smooth((x - l.1) / (r.0 - l.1)))
        }
        if let l = L, x - l.1 < B { return lerp(groundRaw(l.2), raw, smooth((x - l.1) / B)) }
        if let r = R, r.0 - x < B { return lerp(groundRaw(r.2), raw, smooth((r.0 - x) / B)) }
        return raw
    }
    /// Where feet go: the pier deck, the ramp down to the sand, the land, and the east dock.
    func groundLand(_ x: Double) -> Double {
        if x < 0 { return -22 }
        if x < 60 { return lerp(-22, ground(60), x / 60) }
        if x > XEND - 60 && done.contains("dock2") { return lerp(ground(XEND - 60), -12, clampD((x - (XEND - 60)) / 30, 0, 1)) }
        return ground(x)
    }
    func wave(_ x: Double) -> Double {
        return sin(x * 0.02 + T * 1.2) * 1.6 + sin(x * 0.007 - T * 0.7) * 1.2
    }
    func sx(_ x: Double) -> Double { return (x - camX) * camS + W / 2 }
    func sy(_ y: Double) -> Double { return y * camS + baseY }

    func say(_ s: String) { log = s; logT = 7 }
    func setBanner(_ s: String) { banner = s; bannerT = 3 }

    // ---------- upgrades
    func lvl(_ id: String) -> Int { return lvlOf[id] ?? 1 }
    func req(_ u: Upg) -> Bool {
        if u.tier > 0 { return done.contains(u.base) && !dmg.contains(u.base) && lvl(u.base) == u.tier - 1 }
        let b = boat, m = mates
        switch u.id {
        case "bait": return done.contains("rod")
        case "boat1": return b == 0
        case "boat2": return b == 1
        case "boat3": return b == 2
        case "boat4": return b == 3
        case "boat5": return b == 4
        case "nets", "lantern", "hook", "mate1": return b >= 2
        case "mate2": return m >= 1
        case "mate3": return m >= 2
        case "mate4": return m >= 3
        case "mate5": return m >= 4
        case "mate6": return m >= 5
        case "mate7": return m >= 6 && b >= 4
        case "mate8": return m >= 7 && b >= 4
        case "mate9": return m >= 8 && b >= 5
        case "mate10": return m >= 9 && b >= 5
        case "smithy", "wall": return done.contains("mill") || done.contains("farm")
        case "battery": return done.contains("tower")
        case "dock2", "light": return b >= 1
        case "provisions", "powder", "charts": return b >= 3
        default: return true
        }
    }
    func costOf(_ u: Upg) -> Int {
        return dmg.contains(u.id) ? Int((Double(u.cost) * 0.4).rounded(.up)) : u.cost
    }
    func upgradesHere() -> [Upg] {
        return upgs.filter { !done.contains($0.id) && abs(px - $0.x) < 70 && req($0) }
    }
    func burst(_ wx: Double, _ wy: Double, _ n: Int, _ col: Col) {
        for _ in 0..<n {
            sparks.append(Spark(x: wx + rnd(-25, 25), y: wy - rnd(0, 40), vx: rnd(-30, 30), vy: rnd(-50, -15), life: 0, max: rnd(0.7, 1.3), r: 1.4, c: col, grav: 60))
        }
    }
    func apply(_ u: Upg) {
        let id = u.id
        snd?.good()
        buzz?(true)
        burst(u.x, groundLand(u.x) - 30, 18, Col(0xffe082))
        if bld[u.tier > 0 ? u.base : id] != nil {
            born[Int(u.x)] = T
            for _ in 0..<26 {
                sparks.append(Spark(x: u.x + rnd(-44, 44), y: groundLand(u.x) - rnd(0, 6), vx: rnd(-26, 26), vy: rnd(-30, -6), life: 0, max: rnd(0.6, 1.2), r: rnd(2.5, 5), c: Col(0xe2d2b0), grav: 14))
            }
            snd?.thud()
        }
        if u.tier > 0 {
            lvlOf[u.base] = u.tier
            dmg.remove(u.base)
            say(u.tier == 2 ? "Improved. It earns and defends twice as well." : "Finest on the island — three times its first worth.")
            save()
            return
        }
        if bld[id] != nil { dmg.remove(id) }
        switch id {
        case "rod": say("A proper rod. Faster bites, bigger fish.")
        case "bait": say("A bucket of bait. The fish come to you now.")
        case "fishcart": say("A fish cart. Room for twelve before you must sell.")
        case "cart": crates = 10; say("A cart! Twice the crates, four coins each.")
        case "sack": respawnItems(); say("A beachcomber's sack. The tide leaves more for you.")
        case "boat1": setBanner("A rowboat of your own"); say("Row out past the breakers — the big fish are out there.")
        case "boat2": setBanner("A skiff of your own"); say("Sail to the reef. The deep water is yours.")
        case "boat3": setBanner("A sloop of your own. Captain."); say("She rides at anchor off the pier. Sign on six hands at the tavern.")
        case "boat4": setBanner("A brig of your own"); say("Five guns a side and room for eight hands. Sign on two more at the tavern.")
        case "boat5": setBanner("A frigate. Commodore."); say("Seven guns a side, three masts, ten hands. Sign on the last two at the tavern.")
        case "deal": say("The merchant shakes your hand. Better prices from now on.")
        case "nets": say("Nets. Every deep catch comes up heavier.")
        case "lantern": say("A fishing lantern. The night sea glitters with fish.")
        case "hook": say("A salvage hook, ready for the reef wrecks.")
        case "mate1": say("Quiet Jack drinks your rum and swears he will sail with you. 1 of 6.")
        case "mate2": say("Red Meg laughs and signs on. 2 of 6.")
        case "mate3": say("Dutch Pieter nods once. 3 of 6.")
        case "mate4": say("Bones wants a share of every prize. Agreed. 4 of 6.")
        case "mate5": say("Mad Annie signs with an X. 5 of 6.")
        case "mate6": say("Silas Crane makes six. You have a crew.")
        case "mate7": say("Tom Fenn, gunner. 7 hands.")
        case "mate8": say("Black Bess signs on. A full brig crew.")
        case "mate9": say("Old Harrow, forty years at sea. 9 hands.")
        case "mate10": say("Jem Stokes makes ten. A frigate crew.")
        case "hut": say("A fisher's hut. It lays by 3 coins a day — walk past to collect.")
        case "mill": say("A sawmill in the east valley. 6 coins a day.")
        case "farm": say("A farm. 5 coins a day.")
        case "smithy": say("A smithy. 4 coins a day, and the island is better armed.")
        case "tower": say("A watchtower on the heights. Defence +2.")
        case "battery": say("A gun battery commands the bay. Defence +3.")
        case "wall": say("A palisade guards the east cove. Defence +2.")
        case "dock2": say("An east dock for traders. 8 coins a day.")
        case "light": say("The lamp is lit on the rock. Raiders lose the dark: +2 defence.")
        case "provisions": say("Salt pork, water and rum stowed. Full holds for the voyage.")
        case "powder": say("Powder and shot from the old fort. Your guns hit harder.")
        case "charts": say("Charts from the old salts. A shorter road to Tortuga Cay.")
        default: break
        }
        save()
    }
    func refund(_ id: String) {
        let n = paid[id] ?? 0
        if n <= 0 || done.contains(id) { return }
        coins += n
        paid[id] = 0
        if let u = upgs.first(where: { $0.id == id }) {
            say(String(costOf(u) - n) + " more needed — your coins come back.")
        }
    }
    func payCoin(_ u: Upg) {
        let have = paid[u.id] ?? 0
        snd?.tone(1250 + Double(min(900, have * 28)), 0.09, 1, 0.08)
        coins -= 1
        paid[u.id] = have + 1
        if have + 1 >= costOf(u) {
            done.insert(u.id)
            pour = nil
            apply(u)
        }
    }

    // ---------- the island's economy
    func defence() -> Int {
        var d = mates / 2 + (done.contains("powder") ? 1 : 0) + (done.contains("light") ? 2 : 0)
        for id in bldOrder where done.contains(id) && !dmg.contains(id) { d += (bld[id]?.def ?? 0) * lvl(id) }
        return d
    }
    func threat() -> Int { return 2 + day / 4 }
    func income(_ days: Int) {
        for id in bldOrder {
            guard let b = bld[id], done.contains(id), !dmg.contains(id) else { continue }
            let L = lvl(id)
            if b.inc > 0 { pile[id] = min(b.inc * L * 6, (pile[id] ?? 0) + b.inc * L * days) }
            if let g = goodsOf[id] { goods[g] = min(12 * L, (goods[g] ?? 0) + L * days) }
        }
    }
    func resolveRaid() {
        let str = threat(), def = defence()
        if def >= str {
            let g = 8 + str * 3
            coins += g
            say("Raiders beaten off — defence " + String(def) + " against " + String(str) + ". " + String(g) + " coins taken from their boats.")
            setBanner("RAIDERS BEATEN OFF")
            snd?.good()
        } else {
            let lost = Int(Double(coins) * 0.3)
            coins -= lost
            var burnt = ""
            let up = bldOrder.filter { done.contains($0) && !dmg.contains($0) }
            if let id = up.randomElement() {
                dmg.insert(id); done.remove(id); paid[id] = 0; pile[id] = 0
                burnt = " A building burns."
            }
            say("Raided — defence " + String(def) + " against " + String(str) + ". " + String(lost) + " coins stolen." + burnt)
            setBanner("THE ISLAND IS RAIDED")
            buzz?(true)
            snd?.bad()
        }
        raidIn = 4 + Int(rnd(0, 3))
        save()
    }
    func respawnItems() {
        items = []
        let n = done.contains("sack") ? 7 : 4
        for _ in 0..<n { items.append(Item(x: rnd(80, 560), shell: chance(0.67), pick: false)) }
        crates = done.contains("cart") ? 10 : 5
    }
    func pop(_ x: Double, _ y: Double, _ s: String) { pops.append(Pop(x: x, y: y, txt: s, t: 0)) }
    func newWait(_ deep: Bool) -> Double {
        if deep { return rnd(1.2, 3) }
        let night = done.contains("lantern") && light < 0.4
        return rnd(1.5, 4) * (done.contains("rod") ? 0.6 : 1) * (done.contains("bait") ? 0.7 : 1) * (night ? 0.6 : 1)
    }
    func cast(_ deep: Bool) {
        fishing = true; fishPhase = 0; fishT = 0; fishDeep = deep
        fishWait = newWait(deep)
    }

    // ---------- time
    func update(_ dt: Double) {
        T += dt
        snd?.music(T, mode == .title ? "title" : (raiding ? "raid" : (light < 0.3 ? "night" : "isle")))
        if mode == .title { return }
        tod += dt / DAY_LEN
        if tod >= 1 {
            tod -= 1; day += 1
            respawnItems(); income(1); raidIn -= 1
            say(raidIn <= 0 ? "Black sails sighted off the headland. They will come tonight." : "A new day on the island.")
        }
        if logT > 0 { logT -= dt }
        if bannerT > 0 { bannerT -= dt }
        if capShow > 0 { capShow -= dt }
        if spinT > 0 { spinT -= dt }
        if shake > 0 { shake = max(0, shake - dt * 6) }
        if raidFlash > 0 { raidFlash -= dt }
        if light > 0.5 && chance(dt * 0.08) { snd?.gull() }

        // walking
        if rowPhase == 0 {
            let d = tx - px
            let top: Double = abs(d) > 70 && !slowWalk ? 118 : 62
            let want = abs(d) > 4 ? sgn(d) * min(top, 20 + abs(d) * 1.4) : 0.0
            speed = lerp(speed, want, min(1, dt * 8))
            if abs(speed) > 2 {
                px = clampD(px + speed * dt, XMIN, xmax)
                face = sgn(speed)
                walkPh += dt * abs(speed) * 0.17
                if px > 70 && chance(dt * (abs(speed) > 80 ? 9 : 4)) {
                    let sand = px < 600 || px > 3280
                    sparks.append(Spark(x: px - face * 3, y: groundLand(px) - 1, vx: -face * rnd(4, 14), vy: rnd(-12, -4), life: 0, max: rnd(0.4, 0.8), r: rnd(1.4, 2.6), c: sand ? Col(0xe8d6aa, 0.5) : Col(0x968464, 0.5), grav: 10))
                }
                if fishing { fishing = false; say("Line in.") }
            } else if fishing {
                face = -1
            }
        }

        // beach finds
        if let i = items.firstIndex(where: { $0.pick && abs(px - $0.x) < 12 }) {
            let it = items.remove(at: i)
            shells += 1
            shellV += it.shell ? 2 : 1
            say(it.shell ? "A pretty shell. Worth a coin or two." : "A corked bottle — a note inside? No. Rum. Empty.")
            snd?.click()
        }

        // coin piles waiting at buildings
        for id in bldOrder {
            guard let b = bld[id], let g = pile[id], g > 0, abs(px - b.x) < 46 else { continue }
            pile[id] = 0
            coins += g
            pop(b.x, groundLand(b.x) - 60, "+" + String(g))
            snd?.coin()
        }

        // raids come at night
        if raidT >= 0 {
            raidT += dt
            if chance(dt * 2.5) {
                raidFlash = 0.14
                shake = max(shake, 2)
                snd?.cannon()
                let hx = rnd(-250, 120)
                let wet = hx < 0
                for _ in 0..<14 {
                    sparks.append(Spark(x: hx + rnd(-6, 6), y: wet ? 0 : groundLand(hx), vx: rnd(-40, 40), vy: rnd(-130, -50), life: 0, max: rnd(0.5, 1.0), r: rnd(1.4, 2.6), c: wet ? Col(0xe6f6ff) : Col(0xc8b48a), grav: 240))
                }
                if wet { snd?.splash() } else { snd?.thud() }
            }
            if !raidDone && raidT > 5 { raidDone = true; resolveRaid() }
            if raidT > 8 { raidT = -1 }
        } else if raidIn <= 0 && light < 0.12 {
            raidT = 0; raidDone = false
            say("RAID! Black sails off the pier — guns flash in the dark.")
        }

        // fishing: the wait, the fight, the catch
        if fishing {
            fishT += dt
            if fishPhase == 0 && fishT > fishWait {
                fishPhase = 1; fishT = 0; fishFight = rnd(1.1, 1.4)
                snd?.splash(); buzz?(false)
            } else if fishPhase == 1 && fishT > fishFight {
                fishPhase = 2; fishT = 0
                var v = 1
                if fishDeep { v = Int(rnd(2, 4)) + (done.contains("nets") ? 1 : 0) }
                if done.contains("rod") && chance(0.5) { v += 1 }
                if done.contains("lantern") && light < 0.4 { v += 1 }
                fishV = v
            } else if fishPhase == 2 && fishT > 0.7 {
                fish = min(fishCap, fish + fishV)
                capShow = 2.6
                let fxw: Double = rowPhase > 0 ? rowX : px
                pop(fxw, (rowPhase > 0 ? 0 : -22) - 40, "+" + String(fishV))
                snd?.coin()
                if rowPhase > 0 { rowN += 1 }
                if fish >= fishCap {
                    fishing = false
                    say("Hold full. Sell at the market.")
                    if rowPhase > 0 { rowPhase = 3 }
                } else if rowPhase > 0 && rowN >= 3 {
                    fishing = false
                } else {
                    cast(fishDeep)
                }
            }
        }

        // a trip out in the boat
        if rowPhase > 0 {
            let out: Double = boat >= 2 ? -900 : -560
            if rowPhase == 1 {
                rowX = lerp(rowX, out, min(1, dt * 0.8))
                if abs(rowX - out) < 15 { rowPhase = 2; rowN = 0; cast(true) }
            } else if rowPhase == 2 {
                if !fishing {
                    if rowN >= 3 { rowPhase = 3 } else { cast(true) }
                }
            } else {
                rowX = lerp(rowX, -215, min(1, dt * 0.8))
                if abs(rowX + 215) < 12 {
                    rowPhase = 0
                    px = -215; tx = -215; speed = 0
                    say("Back at the pier, salt in your hair.")
                }
            }
        }

        // hauling a crate from the dock to the warehouse
        if haul == 1 {
            if abs(px - 104) < 9 && abs(speed) < 6 { haul = 2; tx = 62 } else if abs(tx - 104) > 8 { haul = 0 }
        } else if haul == 2 {
            if abs(px - 62) < 9 && abs(speed) < 6 {
                crates -= 1
                let g = done.contains("cart") ? 4 : 3
                coins += g
                pop(px, groundLand(px) - 40, "+" + String(g))
                snd?.coin()
                haul = 0
                if crates <= 0 { say("That is the lot for today.") }
            } else if abs(tx - 62) > 8 {
                haul = 0
            }
        }

        // pouring coins into a circle: slow at first, then a stream
        if let id = pour, let u = upgs.first(where: { $0.id == id }) {
            pourT += dt
            if done.contains(id) || !req(u) {
                pour = nil
            } else if abs(px - u.x) > 70 || coins <= 0 {
                refund(id); pour = nil
            } else {
                pourAcc += dt * min(40, 7 + pourT * 12)
                while pourAcc >= 1 && coins > 0 && pour != nil {
                    pourAcc -= 1
                    payCoin(u)
                }
                if coins <= 0 && pour != nil { refund(id); pour = nil; snd?.bad() }
            }
        } else {
            pourT = 0
        }

        // the dog keeps to heel
        if dog {
            let want = px - face * 24
            let d = want - dogX
            if abs(d) > 400 { dogX = want }
            let v: Double = abs(d) > 10 ? sgn(d) * min(150, 30 + abs(d) * 1.6) : 0
            dogSp = lerp(dogSp, v, min(1, dt * 8))
            dogX += dogSp * dt
            if abs(dogSp) > 4 { dogFace = sgn(dogSp); dogPh += dt * abs(dogSp) * 0.16 }
        }

        // the camera keeps your feet at the same height on screen
        let fx: Double = rowPhase > 0 ? rowX : px
        let fy: Double = rowPhase > 0 ? -8 : groundLand(px)
        camS = min(W / 560, H / 330) * 1.25
        camX = lerp(camX, fx + (face > 0 ? 56 : -24), min(1, dt * 2.5))
        let wantBase = H * 0.78 - fy * camS
        baseY = lerp(baseY, wantBase, min(1, dt * 4))

        var i = sparks.count - 1
        while i >= 0 {
            sparks[i].life += dt
            if sparks[i].life > sparks[i].max {
                sparks.remove(at: i)
            } else {
                sparks[i].x += sparks[i].vx * dt
                sparks[i].y += sparks[i].vy * dt
                sparks[i].vy += sparks[i].grav * dt
            }
            i -= 1
        }
        var j = pops.count - 1
        while j >= 0 {
            pops[j].t += dt
            if pops[j].t > 1.2 { pops.remove(at: j) }
            j -= 1
        }

        saveT += dt
        if saveT > 4 { saveT = 0; save() }
    }

    // ---------- which actions are open where you stand
    func spotOK(_ id: String) -> Bool {
        switch id {
        case "dog": return !dog && fish > 0
        case "fish": return rowPhase == 0 && (fish < fishCap || fishing)
        case "row": return boat >= 1 && !fishing
        case "haul": return crates > 0 && haul == 0
        case "wright": return boat >= 3
        default: return true
        }
    }
    func prompts() -> [Spot] {
        if rowPhase > 0 { return [] }
        return spots.filter { abs(px - $0.x) < $0.near && spotOK($0.id) }
    }

    // ---------- touch
    func snapCam() {
        camS = min(W / 560, H / 330) * 1.25
        camX = px + 56
        baseY = H * 0.78 - groundLand(px) * camS
    }
    func touchDown(_ x: Double, _ y: Double) {
        if mode == .title {
            mode = .island
            snapCam()
            snd?.good()
            if day == 1 && coins == 0 && fish == 0 && done.isEmpty {
                say("A dockhand with a dream and empty pockets. Tap the ground to walk; hold a coin circle to pour coins in.")
            }
            return
        }
        if rowPhase > 0 { return }
        for r in rings {
            let dx = x - r.x, dy = y - r.y
            if dx * dx + dy * dy <= (r.r + 8) * (r.r + 8) {
                if r.pour {
                    guard let u = upgs.first(where: { $0.id == r.id }) else { return }
                    if coins <= 0 { say("No coins. Fish, haul, sell."); snd?.bad(); return }
                    payCoin(u)
                    if done.contains(u.id) { return }
                    if coins <= 0 { refund(u.id); return }
                    pour = r.id; pourAcc = -0.4; pourT = 0
                } else {
                    spinId = r.id; spinT = 0.8
                    act(r.id)
                }
                return
            }
        }
        if fishing { fishing = false }
        let wx = (x - W / 2) / camS + camX
        for i in 0..<items.count where abs(wx - items[i].x) < 22 && abs(y - sy(ground(items[i].x))) < 40 {
            tx = items[i].x
            items[i].pick = true
            return
        }
        tx = clampD(wx, XMIN, xmax)
    }
    func touchMove(_ x: Double, _ y: Double) {}
    func touchUp(_ x: Double, _ y: Double) {
        if let id = pour {
            refund(id)
            pour = nil
        }
    }

    func act(_ id: String) {
        snd?.click()
        switch id {
        case "dog":
            fish -= 1; dog = true; dogX = -8
            say("He eats the fish in two bites and decides you are his captain.")
            snd?.good()
        case "fish":
            if fishing { fishing = false; say("Line in."); return }
            if fish >= fishCap { say("Hold full. Sell at the market first."); capShow = 2.6; return }
            cast(false)
            tx = px
            say("Line out.")
        case "row":
            if fish >= fishCap { say("Hold full. Sell at the market first."); return }
            rowPhase = 1; rowX = px; rowN = 0
            say(boat >= 2 ? "Sail up. Out to the reef." : "Oars out. Past the breakers.")
        case "haul":
            haul = 1; tx = 104
            if !hauled { say("Carry the merchant's crates off the dock into the warehouse — " + (done.contains("cart") ? "4" : "3") + " coins each.") }
            hauled = true
        case "market":
            let base = Double(fish * 4 + shellV) * (done.contains("deal") ? 1.5 : 1)
            let g = Int(base.rounded())
            if g > 0 {
                coins += g
                say("Sold " + String(fish) + " fish and " + String(shells) + " finds for " + String(g) + " coins.")
                fish = 0; shells = 0; shellV = 0; capShow = 2.6
                snd?.coin(); buzz?(false)
                burst(px, groundLand(px) - 40, 12, Col(0xffd24a))
                save()
            } else {
                say("Nothing to sell. The merchant shoos you off.")
            }
        case "tavern":
            say(tales_[tales % tales_.count])
            tales += 1
        case "look":
            say(looks.randomElement() ?? "")
        case "wright":
            if mates < shipCrew {
                say("A " + shipName + " needs " + String(shipCrew) + " hands. You have " + String(mates) + ". Buy rounds at the tavern.")
            } else {
                say("Your crew is aboard and the " + shipName + " is ready. The open sea comes in the next build.")
            }
        default: break
        }
    }

    // ---------- keeping the game
    func save() {
        let d: [String: Any] = ["coins": coins, "fish": fish, "shells": shells, "shellV": shellV, "day": day, "tod": tod, "px": px,
                                "crates": crates, "raidIn": raidIn, "tales": tales, "hauled": hauled, "dog": dog,
                                "done": Array(done), "dmg": Array(dmg), "paid": paid, "pile": pile, "lvl": lvlOf, "goods": goods]
        UserDefaults.standard.set(d, forKey: "bs.island.v2")
    }
    func load() {
        guard let d = UserDefaults.standard.dictionary(forKey: "bs.island.v2") else { return }
        coins = d["coins"] as? Int ?? 0
        fish = d["fish"] as? Int ?? 0
        shells = d["shells"] as? Int ?? 0
        shellV = d["shellV"] as? Int ?? 0
        day = max(1, d["day"] as? Int ?? 1)
        tod = d["tod"] as? Double ?? 0.3
        crates = d["crates"] as? Int ?? 5
        raidIn = d["raidIn"] as? Int ?? 5
        tales = d["tales"] as? Int ?? 0
        hauled = d["hauled"] as? Bool ?? false
        dog = d["dog"] as? Bool ?? false
        done = Set(d["done"] as? [String] ?? [])
        dmg = Set(d["dmg"] as? [String] ?? [])
        paid = d["paid"] as? [String: Int] ?? [:]
        pile = d["pile"] as? [String: Int] ?? [:]
        lvlOf = d["lvl"] as? [String: Int] ?? [:]
        goods = d["goods"] as? [String: Int] ?? [:]
        // coins left half-poured when the game closed come back
        for (id, n) in paid where n > 0 && !done.contains(id) { coins += n; paid[id] = 0 }
        px = clampD(d["px"] as? Double ?? -150, XMIN, xmax)
        tx = px
        dogX = px - 24
        respawnItems()
    }

    /// Jump straight to a part of the game, for the build's screenshots.
    func demo(_ name: String) {
        if name == "title" { mode = .title; return }
        mode = .island
        done = []; dmg = []; paid = [:]; pile = [:]; lvlOf = [:]
        coins = 34; fish = 2; day = 3; tod = 0.34; raidIn = 4; raidT = -1; dog = false
        done.insert("rod")
        func all(_ level: Int) {
            for u in upgs where u.tier == 0 { done.insert(u.id) }
            for id in bldOrder { lvlOf[id] = level; pile[id] = 12 }
            dog = true; coins = 420; day = 14
        }
        switch name {
        case "walk": px = 150; tx = 560; slowWalk = true; done.insert("boat1")
        case "run": px = 900; tx = 1500; done.insert("boat1"); done.insert("boat2")
        case "oldfig": px = 150; tx = 560; slowWalk = true; done.insert("boat1"); heroOn = false
        case "pier": px = -150
        case "fish": px = -215; fishing = true; fishPhase = 1; fishT = 0.4; face = -1; coins = 6
        case "beach": px = 300; done.insert("boat1"); done.insert("cart"); coins = 55
        case "town": px = 1080; tod = 0.4; fish = 4; done.insert("boat1"); done.insert("boat2")
        case "fort": all(1); px = 2180; tod = 0.42
        case "valley": all(1); px = 2840; tod = 0.36
        case "valley2": all(2); px = 2840; tod = 0.36
        case "valley3": all(3); px = 2840; tod = 0.36
        case "east": all(3); px = 3330; tod = 0.45
        case "hut3": all(3); px = 505; tod = 0.4
        case "ship": all(2); px = -200; tod = 0.44
        case "night": all(2); px = 1210; tod = 0.9
        case "raid": all(1); px = -120; tod = 0.752; raidIn = 0; pile = [:]
        case "burnt": all(1); px = 2790; tod = 0.4; dmg.insert("mill"); done.remove("mill"); pile = [:]
        default: px = -150
        }
        if name != "walk" && name != "run" && name != "oldfig" { tx = px }
        dogX = px - 24
        respawnItems()
        snapCam()
    }
}
