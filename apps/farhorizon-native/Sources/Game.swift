import CoreGraphics
import Foundation

enum Mode { case title, pick, outfit, chart, sail, port, market, duel, end }

struct Hit {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let act: () -> Void
    func has(_ px: Double, _ py: Double) -> Bool { return px >= x && px <= x + w && py >= y && py <= y + h }
}
struct Opt {
    let label: String
    let sub: String
    let off: Bool
    let act: () -> Void
    init(_ label: String, _ sub: String = "", off: Bool = false, _ act: @escaping () -> Void) {
        self.label = label; self.sub = sub; self.off = off; self.act = act
    }
}
struct CardV {
    let title: String
    let text: String
    let opts: [Opt]
}

/// The voyage: its state, its rules and its flow from port to port. Drawing lives in the other files.
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
    var card: CardV?
    var hits: [Hit] = []
    var isDown = false
    var downX = 0.0
    var downY = 0.0
    var toastText = ""
    var toastT = 0.0
    var sparks: [Spark] = []
    var shake = 0.0

    // the voyage
    var gold = 1100
    var food = 0.0
    var water = 0.0
    var planks = 0
    var bait = 0
    var powder = 0
    var arms = 0
    var crew = 0
    var hull = 0.0
    var shipI = 1
    var day = 1
    var leg = 0
    var dist = 0.0
    var legLen = 1.0
    var route = 1
    var half = false
    var dayT = 0.0
    var tod = 0.3
    var hasMap = false
    var sinceEvent = 0
    var lastEv = ""
    var path = [0, 0, 0, 0, 0, 0]
    var men: [Man] = []
    var log: [String] = []
    var dead: [String] = []
    var sea = 0
    var halfDays = 0
    var rot = 0.0
    var wind = 1.0
    var scroll = 0.0
    var blk = false
    var wellUsed = false
    var over = false
    var endTitle = ""
    var endText = ""
    var marketPort = false
    var recruit: Man?
    var duel: Duel?
    var chartImg: CGImage?
    var fights = 0

    var ship: ShipDef { return SHIPS[shipI] }
    var here: Port { return STAGES[leg][path[leg]] }

    func newGame() {
        gold = 1100; food = 0; water = 0; planks = 0; bait = 0; powder = 0; arms = 0
        crew = 0; hull = 0; shipI = 1; day = 1; leg = 0; dist = 0; legLen = 1; route = 1; half = false
        dayT = 0; tod = 0.3; hasMap = false; sinceEvent = 0; lastEv = ""; path = [0, 0, 0, 0, 0, 0]
        men = []; log = []; dead = []; sea = 0; halfDays = 0; rot = 0; wind = 1; blk = false; wellUsed = false
        over = false; card = nil; duel = nil; recruit = nil; fights = 0
    }

    // ---------- small helpers
    func toast(_ s: String) { toastText = s; toastT = 3.2 }
    func logIt(_ s: String) { log.append("Day \(day): \(s)") }
    func show(_ title: String, _ text: String, _ opts: [Opt]) { card = CardV(title: title, text: text, opts: opts) }
    func puff(_ x: Double, _ y: Double, _ n: Int, _ c: Col, _ speed: Double, _ grav: Double, _ r: Double, _ life: Double) {
        if sparks.count > 260 { return }
        for _ in 0..<n {
            let a = rnd(0, PI * 2), v = rnd(0.3, 1) * speed
            sparks.append(Spark(x: x, y: y, vx: cos(a) * v, vy: sin(a) * v - speed * 0.3, life: life * rnd(0.6, 1), max: life, r: r * rnd(0.6, 1.2), c: c, grav: grav))
        }
    }

    // ---------- the hold
    var holdMax: Int { return ship.hold }
    var holdUsed: Int { return Int(food.rounded(.up)) + Int(water.rounded(.up)) + planks + bait + powder + arms }
    func have(_ k: String) -> Int {
        switch k {
        case "food": return Int(food)
        case "water": return Int(water)
        case "planks": return planks
        case "bait": return bait
        case "powder": return powder
        default: return arms
        }
    }
    func give(_ k: String, _ n: Int) {
        switch k {
        case "food": food = max(0, food + Double(n))
        case "water": water = max(0, water + Double(n))
        case "planks": planks = max(0, planks + n)
        case "bait": bait = max(0, bait + n)
        case "powder": powder = max(0, powder + n)
        default: arms = max(0, arms + n)
        }
    }
    /// Adds up to n of a good, as far as the hold allows. Returns how many went in.
    @discardableResult
    func addGood(_ k: String, _ n: Int) -> Int {
        let a = max(0, min(n, holdMax - holdUsed))
        give(k, a)
        return a
    }

    // ---------- the crew
    func fitCount() -> Int { return men.filter { $0.fit }.count }
    func laidUp() -> Int { return men.filter { !$0.fit }.count }
    func E(_ k: String) -> Double {
        var n = 0.0
        for m in men where m.post == k && m.fit { n += m.knows(k) ? 1.5 : 1 }
        return n
    }
    func postCount(_ k: String) -> Int { return men.filter { $0.post == k }.count }
    func roleMax(_ k: String) -> Int { return ROLES.first(where: { $0.k == k })?.max ?? 1 }
    func roleName(_ k: String) -> String { return ROLES.first(where: { $0.k == k })?.n ?? k }
    func syncMen() {
        while men.count < crew { men.append(Man()) }
        while men.count > max(0, crew) {
            if let i = men.firstIndex(where: { $0.post.isEmpty }) { men.remove(at: i) } else { men.removeLast() }
        }
    }
    /// Every fit hand to the post he knows best, then the key posts filled from whoever is left.
    func autoPost() {
        syncMen()
        for m in men { m.post = "" }
        for m in men where m.fit && postCount(m.sk) < roleMax(m.sk) { m.post = m.sk }
        for m in men where m.fit && m.post.isEmpty && !m.sk2.isEmpty && postCount(m.sk2) < roleMax(m.sk2) { m.post = m.sk2 }
        for k in ["helm", "rig", "cook", "look", "gun", "carp", "fish"] where postCount(k) == 0 {
            if let f = men.first(where: { $0.fit && $0.post.isEmpty }) { f.post = k }
        }
        for k in ["rig", "gun", "cook", "carp", "fish"] where postCount(k) < roleMax(k) {
            if let f = men.first(where: { $0.fit && $0.post.isEmpty }) { f.post = k }
        }
    }
    func killMan(_ m: Man, _ how: String) {
        guard let i = men.firstIndex(where: { $0 === m }) else { return }
        men.remove(at: i)
        crew -= 1
        dead.append(m.n)
        let t = m.n + " " + how
        toast(t); logIt(t); snd?.bad()
        if crew <= 0 { gameOver("The last of your crew is gone.") }
    }
    @discardableResult
    func layUp(_ m: Man, _ st: Int, _ days: Int, _ why: String) -> Bool {
        if !m.fit { return false }
        m.st = st; m.d = days; m.post = ""
        let t = m.n + (st == 1 ? " is wounded" : " falls sick") + (why.isEmpty ? "" : " — " + why)
        toast(t); logIt(t); snd?.bad()
        return true
    }
    func hurtOne(_ why: String) {
        syncMen()
        let pool = men.filter { $0.fit }
        if pool.isEmpty { return }
        layUp(pool[Int.random(in: 0..<pool.count)], 1, rndI(3, 5), why)
    }
    func sickOne(_ why: String) {
        syncMen()
        let pool = men.filter { $0.fit }
        if pool.isEmpty {
            if let m = men.randomElement() { killMan(m, "dies — " + why) }
            return
        }
        layUp(pool[Int.random(in: 0..<pool.count)], 2, rndI(4, 6), why)
    }
    func loseCrew(_ why: String) {
        syncMen()
        let idle = men.filter { $0.post.isEmpty }
        let pool = idle.isEmpty ? men : idle
        guard let v = pool.randomElement() else { return }
        if let i = men.firstIndex(where: { $0 === v }) { men.remove(at: i) }
        crew -= 1
        dead.append(v.n)
        let t = why + ": " + v.n
        toast(t); logIt(t); snd?.bad()
        if crew <= 0 { gameOver("The last of your crew is gone.") }
    }
    func crewDay() {
        let cook = E("cook") > 0
        for m in men {
            if over { return }
            if m.st == 1 {
                m.d -= 1
                if m.d <= 0 { m.st = 0; toast(m.n + " is back on his feet") }
            } else if m.st == 2 {
                var risk = 0.09
                if food <= 0 || water <= 0 { risk *= 2.5 }
                if cook { risk *= 0.6 }
                if chance(risk) {
                    killMan(m, "dies of fever")
                } else {
                    m.d -= 1
                    if m.d <= 0 { m.st = 0; toast(m.n + " has recovered") }
                }
            } else if !m.post.isEmpty {
                let n = (m.xp[m.post] ?? 0) + 1
                m.xp[m.post] = n
                if n == 6 && !m.knows(m.post) && m.sk2.isEmpty {
                    m.sk2 = m.post
                    let t = m.n + " has learned the " + roleName(m.post).lowercased()
                    toast(t); logIt(t)
                }
            }
        }
    }
    /// One day of eating, drinking, rot and whatever shortage does to the crew.
    func consume() {
        let u = Double(crew) * 0.35 * (half ? 0.5 : 1)
        food = max(0, food - u * (1 - 0.15 * min(2, E("cook"))))
        water = max(0, water - u)
        sea += 1
        halfDays = half ? halfDays + 1 : 0
        let r = food * 0.02 * (sea > 5 ? 2 : 1) * (E("cook") > 0 ? 0.5 : 1)
        food -= r
        rot += r
        if rot >= 4 {
            toast("\(Int(rot)) food spoiled in the hold")
            rot -= Double(Int(rot))
        }
        let sick = men.first(where: { $0.st == 2 })
        if water <= 0 {
            if let s = sick, chance(0.6) { killMan(s, "dies of thirst") } else { sickOne("no water") }
        } else if food <= 0 {
            if chance(0.6) {
                if let s = sick, chance(0.5) { killMan(s, "starves") } else { sickOne("no food") }
            }
        } else if half && chance(0.14) {
            sickOne("weak on half rations")
        } else if sea > 9 && chance(0.12 * (E("cook") > 0 ? 0.5 : 1)) {
            sickOne("scurvy, too long at sea")
        }
        if !over { crewDay() }
        if !over { autoPost() }
    }
    func passDays(_ n: Int) {
        for _ in 0..<n where !over {
            day += 1
            consume()
        }
    }
    func dmg(_ n: Double) {
        hull = max(0, hull - n)
        shake = 0.35
        buzz?(true)
        if hull <= 0 { gameOver("Your ship broke apart and sank.") }
    }
    func gameOver(_ why: String) {
        if over { return }
        over = true
        logIt(why)
        card = nil; duel = nil
        endTitle = "Lost at sea"
        let pct = Int(((Double(leg) + min(1, dist / max(1, legLen))) / 5 * 100).rounded())
        endText = why + "\nDay \(day), \(pct)% of the way."
        mode = .end
        snd?.bad()
    }

    // ---------- from the dock to the open sea
    func chooseShip(_ i: Int) {
        shipI = i
        gold -= ship.cost
        crew = ship.crew
        hull = Double(ship.hull)
        syncMen()
        autoPost()
        marketPort = false
        mode = .outfit
    }
    func price(_ g: Good) -> Int {
        let pm = marketPort ? here.pm : 1.0
        return max(1, Int((Double(g.p) * pm).rounded()))
    }
    func buy(_ g: Good) {
        let p = price(g)
        var n = g.step
        n = min(n, holdMax - holdUsed)
        n = min(n, gold / p)
        if n <= 0 { toast(gold < p ? "Not enough gold" : "The hold is full"); return }
        give(g.k, n)
        gold -= n * p
    }
    func sell(_ g: Good) {
        let n = min(g.step, have(g.k))
        if n <= 0 { return }
        give(g.k, -n)
        gold += Int((Double(n * price(g)) * 0.6).rounded(.down))
    }
    func autoStock() {
        let per = Double(crew) * 0.35
        let want: [(String, Int)] = [("water", Int((per * 9).rounded(.up))), ("food", Int((per * 10).rounded(.up))), ("planks", 6), ("bait", 6), ("powder", 5), ("arms", min(crew, 8))]
        for w in want {
            guard let g = GOODS.first(where: { $0.k == w.0 }) else { continue }
            let p = price(g)
            var n = max(0, w.1 - have(w.0))
            n = min(n, holdMax - holdUsed)
            n = min(n, gold / p)
            if n > 0 { give(w.0, n); gold -= n * p }
        }
        snd?.coin()
    }
    func leaveMarket() {
        if marketPort { mode = .port; return }
        if food < 1 || water < 1 { toast("You need food and water"); return }
        mode = .chart
    }
    func pickPort(_ row: Int) {
        let next = STAGES[min(5, leg + 1)]
        path[min(5, leg + 1)] = min(row, next.count - 1)
        let r = next.count > 1 ? row : path[leg]
        route = r == 0 ? 0 : 1
        startLeg()
    }
    func wagesDue() -> Int { return crew * WAGE }
    func payWages() {
        let due = wagesDue()
        if gold >= due {
            gold -= due
            let t = "Wages paid: \(due) gold"
            toast(t); logIt(t)
            return
        }
        let short = Int((Double(due - gold) / Double(WAGE)).rounded(.up))
        gold = 0
        var gone: [String] = []
        for _ in 0..<short where crew > 2 && chance(0.6) {
            let pool = men.filter { $0.fit }
            guard let m = pool.randomElement() ?? men.first else { continue }
            if let i = men.firstIndex(where: { $0 === m }) { men.remove(at: i) }
            crew -= 1
            gone.append(m.n)
        }
        var t = "\(short) went unpaid"
        t += gone.isEmpty ? " — they grumble but stay" : " — " + gone.joined(separator: ", ") + (gone.count > 1 ? " desert" : " deserts")
        toast(t); logIt(t); snd?.bad()
    }
    func startLeg() {
        if leg > 0 { payWages() }
        legLen = LEG[min(4, leg)] * (route == 1 ? 0.85 : 1.15)
        dist = 0; dayT = 0; sinceEvent = 0
        autoPost()
        mode = .sail
        card = nil
        logIt("Sailed for " + STAGES[leg + 1][path[leg + 1]].n + (route == 1 ? " by the open sea" : " along the coast"))
    }
    func dps() -> Double {
        var v = 42 * ship.speed * wind
        if Double(fitCount()) < Double(ship.crew) / 2 { v *= 0.75 }
        v *= 1 + 0.08 * E("helm") + 0.04 * E("rig")
        return v
    }
    func nextDay() {
        day += 1
        consume()
        if over { return }
        if leg == 4 && !blk && dist > legLen * 0.55 { blk = true; event("blockade"); return }
        let carp = E("carp")
        if carp > 0 && hull < Double(ship.hull) { hull = min(Double(ship.hull), hull + 3 * carp) }
        for _ in 0..<postCount("fish") where bait > 0 && chance(0.55) {
            addGood("food", 2)
            if chance(0.25) { bait -= 1 }
        }
        wind = rnd(0.8, 1.2)
        sinceEvent += 1
        if sinceEvent >= 3 || chance(0.4) { rollEvent() }
    }
    func arrive() {
        leg += 1
        dist = 0; sea = 0
        if halfDays >= 3 && crew > 2 {
            let pool = men.filter { $0.fit }
            if let m = pool.randomElement(), let i = men.firstIndex(where: { $0 === m }) {
                men.remove(at: i)
                crew -= 1
                let t = m.n + " deserts in port — sick of half rations"
                toast(t); logIt(t)
            }
        }
        halfDays = 0; wellUsed = false; recruit = nil
        if leg >= 5 { finish(); return }
        logIt("Made port at " + here.n)
        snd?.good()
        mode = .port
        show(here.n, "Day \(day). Land at last.\nWages of \(wagesDue()) gold fall due when you sail.", [Opt("Go ashore") { [unowned self] in self.card = nil }])
    }
    func finish() {
        over = true
        let score = gold + crew * 60 + Int(hull) * 3 - day * 4
        endTitle = "Santa Aurelia!"
        endText = "You made port on day \(day) with \(crew) hands and \(gold) gold.\nScore: \(max(0, score))" + (dead.isEmpty ? "" : "\nLost on the way: " + dead.joined(separator: ", "))
        mode = .end
        card = nil
        snd?.good()
    }

    // ---------- frame
    func update(_ dt: Double) {
        T += dt
        toastT = max(0, toastT - dt)
        shake = max(0, shake - dt)
        var i = sparks.count - 1
        while i >= 0 {
            sparks[i].life -= dt
            if sparks[i].life <= 0 {
                sparks.remove(at: i)
            } else {
                sparks[i].vy += sparks[i].grav * dt
                sparks[i].x += sparks[i].vx * dt
                sparks[i].y += sparks[i].vy * dt
            }
            i -= 1
        }
        switch mode {
        case .title, .pick, .outfit:
            scroll += dt * 50
            if mode == .title { tod = 0.3 + 0.05 * sin(T * 0.07) }
        case .sail:
            if card == nil {
                dayT += dt
                tod = (tod + dt / DAYLEN * 0.22).truncatingRemainder(dividingBy: 1)
                dist += dps() * dt / DAYLEN
                scroll += dt * 70 * ship.speed
                if dist >= legLen {
                    arrive()
                } else if dayT >= DAYLEN {
                    dayT = 0
                    nextDay()
                }
            }
        case .duel:
            if card == nil { duel?.update(dt, self) }
        default:
            break
        }
        var mood = "sea"
        if mode == .duel { mood = "battle" } else if mode == .port || mode == .market { mood = "port" } else if mode == .end { mood = "night" } else if mode == .sail {
            mood = isNight ? "night" : (leg % 2 == 1 ? "sea2" : "sea")
        }
        snd?.music(T, mood)
    }
    var isNight: Bool { return tod > 0.7 && tod < 0.95 }

    func touchDown(_ x: Double, _ y: Double) {
        isDown = true; downX = x; downY = y
        if mode == .duel && card == nil { duel?.touch(x, y, self) }
    }
    func touchMove(_ x: Double, _ y: Double) {}
    func touchUp(_ x: Double, _ y: Double) {
        isDown = false
        for h in hits.reversed() where h.has(x, y) && h.has(downX, downY) {
            snd?.click()
            h.act()
            return
        }
    }

    /// Jumps straight to a screen, for the build's simulator screenshots.
    func demo(_ name: String) {
        newGame()
        if name == "pick" { mode = .pick; return }
        chooseShip(1)
        autoStock()
        if name == "market" { return }
        if name == "chart" { leg = 2; path = [0, 1, 0, 0, 0, 0]; mode = .chart; return }
        pickPort(0)
        dist = legLen * 0.4; day = 4
        if name == "night" { tod = 0.8 }
        if name == "event" { event("pirates") }
        if name == "result" { event("ghost"); done("Her hold is full of old silver: +212 gold") }
        if name == "port" { leg = 1; mode = .port }
        if name == "duel" { UserDefaults.standard.set(0, forKey: Duel.lessonKey); startDuel(foes: 3, boss: false, prize: 120) }
        if name == "teach" { UserDefaults.standard.set(0, forKey: Duel.lessonKey); startDuel(foes: 3, boss: false, prize: 120); card = nil }
        if name == "fight" { startDuel(foes: 3, boss: false, prize: 120, teach: false) }
        if name == "boss" { startDuel(foes: 1, boss: true, prize: 300, teach: false) }
        if name == "end" { finish() }
    }
}
