import CoreGraphics
import Foundation

enum Mode { case title, pick, outfit, chart, sail, port, market, tavern, duel, end }

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
    /// A small moving picture of what the choice gives you, drawn at the left of its button.
    var pic = ""
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
    // weather
    var weather = 0
    var wxDays = 2
    var wxRain = 0.0
    var wxDark = 0.0
    var wxFog = 0.0
    var rough = 0.0
    var bolts: [Bolt] = []
    var boltT = 3.0
    var flashT = 0.0
    var thunderIn = -1.0
    // the interactive part of an event, the arrival summary, the last event's title
    var play: Play?
    var sum: LegSum?
    var sumT = 0.0
    var sumRow = -1
    var evTitle = ""
    var leg0Day = 1
    var leg0Gold = 0
    var leg0Crew = 0
    var leg0Fights = 0
    var legEvents = 0
    var legFrom = ""
    var rumourHeard = false
    // what is going on in this port: 0 nothing, 1 dock work, 2 a thief, 3 rats in the stores, 4 a festival, 5 an old sailor's barrels
    var ups: [String: Int] = [:]
    var perkRip = false
    var perkWind = false
    var perkFury = false
    var rainbowT = 0.0
    var portJob = 0
    var portJobs: [Int] = []
    var jobsDone: Set<Int> = []
    var portJobDone: Bool {
        get { return jobsDone.contains(portJob) }
        set { if newValue { jobsDone.insert(portJob) } }
    }
    // work taken on in one port and paid for in the next
    var cargoPay = 0
    var cargoHold = 0
    var fareDue = 0
    var fareBy = 0
    var bounty = false
    var duelPort = false
    var duelSport = false
    var saluteT = 0.0
    var saluteN = 0
    var chatWho = 0
    var chatLine = 0
    var chatT = 0.0
    var portMsg = ""
    var saveT = 1.0
    var won = false
    // an event is first sighted, with the clock slowed, before it is upon you
    var omenK = ""
    /// What is being acted out on deck (or seen off the ship), from first sighting until the card is answered.
    var sceneK = ""
    var sceneT = 0.0
    /// Things that happen on the deck itself; everything else is far off and wants the wide view.
    static let deckScenes: Set<String> = ["sick", "leak", "calm", "fall", "brawl", "galley", "rats", "spar", "stowaway", "catch", "bottle", "scurvy", "foulwater", "weevils", "plank", "neptune", "albatross", "grumble", "flotsam"]
    /// How fast the voyage is running: it eases down as something comes into view and back up afterwards.
    var pace = 1.0
    var pendTitle = ""
    var pendText = ""
    /// How far along the leg each event falls, so they are spread over the passage and never bunch up.
    var evMarks: [Double] = []
    /// The day on which the next event may fall. Never sooner than seven days after the last one ended.
    var nextEvAt = 0.0
    /// The rare sights: each can be met once in a voyage, and most voyages meet only one or two.
    var rareSeen: Set<String> = []
    func nowDays() -> Double { return (Double(day - 1) + dayT / DAYLEN) * Double(SUNS) }
    /// Leagues between two ports, as the chart shows them.
    func legDist(_ a: Port, _ b: Port) -> Double {
        let dx = (b.x - a.x) * 900.0 / 540.0, dy = b.y - a.y
        return clampD(((dx * dx + dy * dy).squareRoot() * 760).rounded(), 170, 520)
    }
    /// The longer of the passages open from here: what to stock for.
    func nextLegLen() -> Double {
        return STAGES[min(5, leg + 1)].map { legDist(here, $0) }.max() ?? 300
    }
    // what the crew has got through since the last port
    var legAte = 0.0
    var legDrank = 0.0
    // the stores counter ticking down on the top bar
    var sdLast = -1
    // a small chance offered between events: a quick game the player can take or leave
    var offerK = ""
    var offerT = 0.0
    var offerDone = false
    var lastEvEnd = 0.0
    /// For screenshots: keep an offer on screen.
    static var offerHold = false
    var sdFloat: [(Double, Int)] = []
    // the camera: close on the deck while under way, pulling back when there is something far off to see
    var camZ = 1.0
    var camFx = 0.0
    var camFy = 0.0
    var omenT = 0.0
    var festT = 0.0
    var bellT = 6.0
    var bellSwing = 0.0
    var deckForce = -1
    var seaForce = -1
    var cardT = 9.0          // seconds since the card on screen appeared
    var uiLock = false       // buttons are not live while a card is still flying in
    var rings: [(x: Double, y: Double, w: Double, h: Double, t: Double)] = []
    var downX = 0.0
    var downY = 0.0
    var toastText = ""
    var toastT = 0.0
    var sparks: [Spark] = []
    var shake = 0.0

    // the voyage
    var gold = 1050
    var food = 0.0
    /// Food and water are one thing now: stores, counted by the player in days. Old code that speaks of
    /// water reaches the same casks.
    var water: Double { get { return food } set { food = newValue } }
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

    /// Your ship as she is now: the hull you bought plus whatever the shipwrights have added since.
    var ship: ShipDef {
        var s = SHIPS[shipI]
        s.speed *= 1 + 0.09 * Double(up("sails"))
        s.hull += 25 * up("hull")
        s.hold += 50 * up("hold")
        s.crew += 2 * up("berths")
        return s
    }
    func up(_ k: String) -> Int { return ups[k] ?? 0 }
    var here: Port { return STAGES[leg][path[leg]] }

    func newGame() {
        gold = 1050; food = 0; water = 0; planks = 0; bait = 0; powder = 0; arms = 0
        crew = 0; hull = 0; shipI = 1; day = 1; leg = 0; dist = 0; legLen = 1; route = 1; half = false
        dayT = 0; tod = 0.3; hasMap = false; sinceEvent = 0; lastEv = ""; path = [0, 0, 0, 0, 0, 0]; rareSeen = []; nextEvAt = 0
        men = []; log = []; dead = []; sea = 0; halfDays = 0; rot = 0; wind = 1; blk = false; wellUsed = false
        over = false; card = nil; duel = nil; recruit = nil; fights = 0
        omenK = ""; omenT = 0; sceneK = ""; sceneT = 0; camZ = 1; camFx = 0
        cargoPay = 0; cargoHold = 0; fareDue = 0; bounty = false; duelPort = false; duelSport = false; portJobs = []; jobsDone = []
        ups = [:]; perkRip = false; perkWind = false; perkFury = false; rainbowT = 0
        play = nil; sum = nil; weather = 0; wxDays = 2; bolts.removeAll(); thunderIn = -1
    }

    // ---------- small helpers
    func toast(_ s: String) { toastText = s; toastT = 3.2 }
    /// The day of the voyage as the player sees it: several suns cross the sky for each step of the rules.
    var cal: Int { return (day - 1) * SUNS + 1 + (mode == .sail ? min(SUNS - 1, Int(dayT / DAYLEN * Double(SUNS))) : 0) }
    func logIt(_ s: String) { log.append("Day \(cal): \(s)") }
    func show(_ title: String, _ text: String, _ opts: [Opt]) {
        card = CardV(title: title, text: text, opts: opts)
        evTitle = title
        cardT = 0
        snd?.whoosh()
    }
    func puff(_ x: Double, _ y: Double, _ n: Int, _ c: Col, _ speed: Double, _ grav: Double, _ r: Double, _ life: Double) {
        if sparks.count > 260 { return }
        for _ in 0..<n {
            let a = rnd(0, PI * 2), v = rnd(0.3, 1) * speed
            sparks.append(Spark(x: x, y: y, vx: cos(a) * v, vy: sin(a) * v - speed * 0.3, life: life * rnd(0.6, 1), max: life, r: r * rnd(0.6, 1.2), c: c, grav: grav))
        }
    }

    // ---------- the hold
    var holdMax: Int { return ship.hold }
    var holdUsed: Int { return Int(food.rounded(.up)) + planks + bait + powder + arms + cargoHold }
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
    /// What the crew eats and drinks in one watch.
    func ration() -> Double { return Double(crew) * RATION * (half ? 0.5 : 1) }
    /// Stores the crew gets through in a day on full rations.
    func fullDay() -> Double { return max(0.05, Double(max(1, crew)) * RATION * (1 - 0.15 * min(2, E("cook"))) / Double(SUNS)) }
    /// How many days the stores aboard will last at the ration now in force.
    func storeDays() -> Int { return Int(food / (fullDay() * (half ? 0.5 : 1))) }
    /// About how many days the next passage takes (the longer of the two ways).
    func passageDays() -> Int { return Int((nextLegLen() / max(1, 42 * ship.speed)).rounded(.up)) * SUNS }
    /// What to carry before sailing: the passage and a few days spare.
    func storesNeeded() -> Int { return passageDays() + SUNS }
    /// Days left to port on this passage, at the present speed.
    func daysToGo() -> Int { return Int((max(0, legLen - dist) / max(0.1, dps() / Double(SUNS))).rounded(.up)) }
    /// Stores costed out for so many days.
    func storeUnits(_ days: Int) -> Int { return Int((Double(days) * fullDay() * 1.08).rounded(.up)) }
    func storeCost(_ days: Int) -> Int {
        guard let g = GOODS.first(where: { $0.k == "food" }) else { return 0 }
        return max(0, storeUnits(days) - Int(food.rounded(.up))) * price(g)
    }
    /// Buy stores up to so many days, as far as gold and hold allow.
    func provision(_ days: Int) {
        guard let g = GOODS.first(where: { $0.k == "food" }) else { return }
        if marketPort && portLacks().contains("food") { toast("They sell no stores here"); return }
        var n = max(0, storeUnits(days) - Int(food.rounded(.up)))
        if n == 0 { toast("You already have stores for \(Int(food / fullDay())) days"); return }
        n = min(n, holdMax - holdUsed)
        n = min(n, gold / price(g))
        if n <= 0 { toast(holdMax - holdUsed <= 0 ? "The hold is full" : "Not enough gold"); return }
        give("food", n)
        gold -= n * price(g)
        snd?.coin()
        let got = Int(food / fullDay())
        toast(got >= days ? "Stores for \(got) days" : "Stores for \(got) days: all you could \(holdMax - holdUsed <= 0 ? "stow" : "afford")")
    }
    func consume(drain: Bool = true) {
        if drain {
            let u = ration()
            let f0 = food
            food = max(0, food - u * (1 - 0.15 * min(2, E("cook"))))
            legAte += f0 - food
        }
        sea += 1
        halfDays = half ? halfDays + 1 : 0
        let r = food * 0.01 * (sea > 5 ? 2 : 1) * (E("cook") > 0 ? 0.5 : 1)
        food -= r
        rot += r
        if rot >= 4 {
            toast("\(Int(rot)) stores spoiled in the hold")
            rot -= Double(Int(rot))
        }
        let sick = men.first(where: { $0.st == 2 })
        if food <= 0 {
            if let s = sick, chance(0.6) { killMan(s, "dies of hunger and thirst") } else { sickOne("no stores left") }
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
        won = false
        clearSave()
        let pct = Int(((Double(leg) + min(1, dist / max(1, legLen))) / 5 * 100).rounded())
        endText = why + "\nDay \(cal), \(pct)% of the way."
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
    /// What sort of place this port is: fishing village, garrison, trading city, smugglers' cove, mill island.
    func portKind() -> Int { return (leg * 2 + path[leg]) % 5 }
    /// What this port's market does not carry. Only a trading city sells everything.
    func portLacks() -> [String] {
        if !marketPort && mode != .port { return [] }
        return [["powder", "arms"], ["bait", "planks"], [], ["planks", "bait"], ["powder", "bait"]][portKind()]
    }
    /// The smugglers have no well worth the name.
    func wellDry() -> Bool { return portKind() == 3 }
    func lacksText() -> String {
        let names = portLacks().compactMap { k in GOODS.first(where: { $0.k == k })?.n.lowercased() }
        return names.isEmpty ? "" : "no " + names.joined(separator: " or ") + " sold here"
    }
    func buy(_ g: Good) {
        if marketPort && portLacks().contains(g.k) { toast("They do not sell \(g.n.lowercased()) here"); return }
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
        let per = Double(crew) * RATION
        let watches = Double(Int((nextLegLen() / max(1, 42 * ship.speed)).rounded(.up)) + 2)
        let want: [(String, Int)] = [("food", Int((per * (watches + 2)).rounded(.up))), ("planks", 6), ("bait", 6), ("powder", 5), ("arms", min(crew, 8))]
        for w in want {
            guard let g = GOODS.first(where: { $0.k == w.0 }) else { continue }
            if marketPort && portLacks().contains(g.k) { continue }
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
        if food < 1 { toast("Buy stores first: the crew must eat and drink"); return }
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
        leg0Day = day; leg0Gold = gold; leg0Crew = crew; leg0Fights = fights; legEvents = 0; legFrom = here.n
        legLen = legDist(here, STAGES[min(5, leg + 1)][path[min(5, leg + 1)]])
        dist = 0; dayT = 0; sinceEvent = 0
        legAte = 0; legDrank = 0
        evMarks = []
        nextEvAt = nowDays() + rnd(2, 4)
        lastEvEnd = nowDays(); offerDone = false; offerK = ""
        autoPost()
        mode = .sail
        card = nil
        logIt("Sailed for " + STAGES[leg + 1][path[leg + 1]].n + (route == 1 ? " by the open sea" : " along the coast"))
    }
    func dps() -> Double {
        var v = 42 * ship.speed * wind * (1 - 0.15 * rough)
        if Double(fitCount()) < Double(ship.crew) / 2 { v *= 0.75 }
        v *= 1 + 0.08 * E("helm") + 0.04 * E("rig")
        return v
    }
    func nextDay() {
        day += 1
        consume(drain: false)
        if over { return }
        if leg == 4 && !blk && dist > legLen * 0.55 { blk = true; startOmen("blockade"); return }
        let carp = E("carp")
        if carp > 0 && hull < Double(ship.hull) { hull = min(Double(ship.hull), hull + 3 * carp) }
        for _ in 0..<postCount("fish") where bait > 0 && chance(0.55) {
            addGood("food", 2)
            if chance(0.25) { bait -= 1 }
        }
        wind = rnd(0.8, 1.2)
        let wasWet = weather == 2 || weather == 3
        rollWeather()
        if wasWet && weather < 2 { rainbowT = 16 }
        weatherDay()
        if over { return }
    }
    func arrive() {
        // what was promised in the last port falls due in this one
        portMsg = ""
        if cargoPay > 0 { gold += cargoPay; portMsg = "Cargo delivered: +\(cargoPay) gold. "; logIt("Delivered a merchant's cargo"); cargoPay = 0; cargoHold = 0 }
        if fareDue > 0 {
            let late = day > fareBy
            let f = late ? fareDue / 2 : fareDue
            gold += f
            portMsg += late ? "Your passenger pays half for a slow passage: +\(f) gold." : "Your passenger pays in full: +\(f) gold."
            fareDue = 0
        }
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
        rumourHeard = false
        rollPortJobs(); festT = 0; bellT = 5
        if weather == 3 { setWeather(2, days: 1) }
        var warns: [String] = []
        let hullPct = Int((hull / Double(max(1, ship.hull)) * 100).rounded())
        if Int(food / fullDay()) < storesNeeded() { warns.append("buy stores before sailing") }
        if hullPct < 60 { warns.append("hull needs repair") }
        let laid = men.filter { $0.st != 0 }.count
        if laid > 0 { warns.append("\(laid) laid up") }
        if gold < wagesDue() { warns.append("short of wages") }
        sum = LegSum(from: legFrom, to: here.n, days: (day - leg0Day) * SUNS, leagues: Int(legLen), events: legEvents, gold: gold - leg0Gold, lost: max(0, leg0Crew - crew), hull: hullPct, fights: fights - leg0Fights, wages: wagesDue(), ate: Int((legAte / fullDay()).rounded()), drank: Int(food / fullDay()), warns: warns)
        sumT = 0
        sumRow = -1
        if !portMsg.isEmpty { toast(portMsg) }
    }
    func finish() {
        over = true
        let score = gold + crew * 60 + Int(hull) * 3 - day * 4
        endTitle = "Santa Aurelia!"
        won = true
        clearSave()
        endText = "You made port on day \(cal) with \(crew) hands and \(gold) gold.\nScore: \(max(0, score))" + (dead.isEmpty ? "" : "\nLost on the way: " + dead.joined(separator: ", "))
        mode = .end
        card = nil
        snd?.good()
    }

    // ---------- frame
    func update(_ dt: Double) {
        T += dt
        cardT += dt
        let sceneWas = sceneT
        sceneT += dt
        if mode == .sail && !sceneK.isEmpty && play == nil {
            if sceneK == "fall" && sceneWas < 0.9 && sceneT >= 0.9 { snd?.thud(); shake = max(shake, 0.25); buzz?(true) }
            if sceneK == "brawl" && card == nil && Int(sceneWas / 0.55) != Int(sceneT / 0.55) { snd?.thud() }
            if sceneK == "plank" {
                for i in 0..<3 { let tf = 0.4 + Double(i) * 1.15 + 1.45; if sceneWas < tf && sceneT >= tf { snd?.splash(); snd?.good() } }
            }
        }
        updateWeather(dt)

        rainbowT = max(0, rainbowT - dt)
        if sum != nil { sumT += dt }
        var ri = rings.count - 1
        while ri >= 0 {
            rings[ri].t += dt
            if rings[ri].t > 0.45 { rings.remove(at: ri) }
            ri -= 1
        }
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
        case .port:
            if card == nil, play != nil { updatePlay(dt) }
            updateTown(dt)
            saveT -= dt
            if saveT <= 0 && card == nil && play == nil { saveT = 4; saveGame() }
        case .end:
            // fireworks over Santa Aurelia if you made it
            if won && chance(dt * 2.2) {
                let x = rnd(W * 0.05, W * 0.5), y = rnd(30, H * 0.4)
                puff(x, y, 44, [Col(0xff5a5a), Col(0xffd257), Col(0x7fd8ff), Col(0x9ff0aa), Col(0xff9af0)][rndI(0, 4)], 210, 90, 2.6, 1.2)
                snd?.noise(0.35, 0.14, 700, 1)
            }
        case .sail:
            if !offerK.isEmpty && card == nil && play == nil {
                offerT += dt
                if Game.offerHold { offerT = 2 }
                if offerT > 6.5 || !sceneK.isEmpty || !omenK.isEmpty { offerK = "" }
            }
            // keep the voyage safe at sea too, between events
            saveT -= dt
            if saveT <= 0 && card == nil && play == nil && omenK.isEmpty && sceneK.isEmpty && !over { saveT = 6; saveGame() }
            if card == nil, play != nil {
                updatePlay(dt)
            } else if card == nil, !omenK.isEmpty {
                // time all but stops while the thing comes into view
                omenT += dt
                pace = max(0, pace - dt / 0.6)
                scroll += dt * (16 + 54 * pace) * ship.speed
                dayT = min(DAYLEN - 0.02, dayT + dt * pace)
                tod = (dayT / DAYLEN * Double(SUNS)).truncatingRemainder(dividingBy: 1)
                if omenT >= Game.omenSecs(omenK) {
                    let k = omenK
                    omenK = ""
                    event(k)
                }
            } else if card == nil {
                if !sceneK.isEmpty {
                    // whatever it was is over: nothing more for a week at the least
                    sceneK = ""
                    nextEvAt = nowDays() + rnd(4, 6)
                    lastEvEnd = nowDays(); offerDone = false
                }
                // she gathers way again after whatever stopped her
                pace = min(1, pace + dt / 0.8)
                let sd = dt * (0.1 + 0.9 * pace)
                dayT += sd
                tod = (dayT / DAYLEN * Double(SUNS)).truncatingRemainder(dividingBy: 1)
                dist += dps() * sd / DAYLEN
                scroll += sd * 70 * ship.speed
                // stores go down steadily as she sails, not in one bite at the end of the watch
                let ate = ration() * sd / DAYLEN
                let f0 = food
                food = max(0, food - ate * (1 - 0.15 * min(2, E("cook"))))
                legAte += f0 - food
                if dist >= legLen {
                    arrive()
                } else if offerK.isEmpty && !offerDone && nowDays() > lastEvEnd + 1.2 && nextEvAt - nowDays() > 1.6 {
                    // midway between events, offer something to do
                    offerDone = true
                    var pool = ["flyfish", "trim", "cask", "gleam", "turtle", "gulls", "chest"]
                    if bait > 0 { pool.append("fishing") }
                    offerK = pool.randomElement() ?? "flyfish"
                    offerT = 0
                    snd?.bell()
                } else if nowDays() >= nextEvAt {
                    offerK = ""
                    nextEvAt = nowDays() + rnd(4, 6)
                    rollEvent()
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
        if mode == .duel { mood = "battle" } else if mode == .port || mode == .market || mode == .tavern { mood = "port" } else if mode == .end { mood = "night" } else if mode == .sail {
            // one tune for the whole passage: the sun goes round too fast to change it with the hour
            mood = leg % 2 == 1 ? "sea2" : "sea"
        }
        if play?.theme == "storm" || play?.theme == "run" { mood = "battle" }
        snd?.music(T, mood)
        let atSea = mode == .sail || mode == .port || mode == .title || mode == .duel || mode == .end
        snd?.ambient(T, sea: atSea, rough: rough, rain: mode == .tavern ? wxRain * 0.3 : wxRain, birds: atSea && mode != .duel && !isNight && weather < 2, room: mode == .tavern)
    }
    var isNight: Bool { return tod > 0.78 && tod < 0.95 }

    func touchDown(_ x: Double, _ y: Double) {
        isDown = true; downX = x; downY = y
        if (mode == .sail || mode == .port) && card == nil && play != nil { tapPlay(x, y); return }
        if mode == .duel && card == nil { duel?.touch(x, y, self) }
    }
    func touchMove(_ x: Double, _ y: Double) {}
    func touchUp(_ x: Double, _ y: Double) {
        isDown = false
        if sum != nil && card == nil && sumT < LegSum.fullT { sumT = LegSum.fullT; return }
        for h in hits.reversed() where h.has(x, y) && h.has(downX, downY) {
            snd?.click()
            buzz?(false)
            rings.append((h.x, h.y, h.w, h.h, 0))
            puff(x, y, 9, Col(0xffe08a), 150, 260, 2.2, 0.4)
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
        if name == "port" { leg = 1; mode = .port; portJobs = [2, 7, 10] }
        if name == "raid" { leg = 1; mode = .port; portJob = 7; duelPort = true; startDuel(foes: 5, boss: false, prize: 45, teach: false) }
        if name == "shark" { playShark() }
        if name == "win" { fights = 4; log = ["Day 3: Ran into a storm", "Day 30: Made port at Gull Cay", "Day 71: Took a pirate ship by boarding", "Day 118: Took the Red Mary"]; finish() }
        if name == "saved" { leg = 2; mode = .port; saveGame(); mode = .title }
        if name == "deckzoom" { ups = ["sails": 1, "guns": 1]; deckForce = 0; camZ = 2.6 }
        if name == "evfall" { startOmen("fall"); sceneT = 2.6; omenT = 1.6; Game.omenHold = true; camZ = 2.6 }
        if name == "evfallcard" { startOmen("fall"); sceneT = 2.6; omenK = ""; event("fall"); camZ = 2.6 }
        if name == "evbrawl" { startOmen("brawl"); sceneT = 1.3; omenT = 1.6; Game.omenHold = true; camZ = 2.6 }
        if name == "evgalley" { startOmen("galley"); sceneT = 1.3; omenK = ""; event("galley"); camZ = 2.6 }
        if name == "evsick" { startOmen("sick"); sceneT = 2.4; omenT = 1.6; Game.omenHold = true; camZ = 2.6 }
        if name == "evbottle" { startOmen("bottle"); sceneT = 2; omenT = 1.6; Game.omenHold = true; camZ = 2 }
        if name == "evwhale" { startOmen("whale"); sceneT = 1.2; omenT = 1.6; Game.omenHold = true }
        if name == "evspout" { startOmen("spout"); sceneT = 2; omenT = 1.6; Game.omenHold = true }
        if name == "evspar" { startOmen("spar"); sceneT = 2; omenT = 1.6; Game.omenHold = true; camZ = 2.6 }
        if name == "evstow" { startOmen("stowaway"); sceneT = 2; omenK = ""; event("stowaway"); camZ = 2.6 }
        if name == "evcatch" { startOmen("catch"); sceneT = 2; omenT = 1.6; Game.omenHold = true; camZ = 2.6 }
        if name == "omen" { startOmen("pirates"); omenT = 1.6; Game.omenHold = true }
        if name == "hang1" { deckForce = 25; camZ = 2.6; nextEvAt = 9999 }
        if name == "hang2" { deckForce = 26; camZ = 2.6; nextEvAt = 9999 }
        if name == "hang3" { deckForce = 27; camZ = 2.6; nextEvAt = 9999 }
        if name == "life1" { deckForce = 17; camZ = 2.6; nextEvAt = 9999 }
        if name == "life2" { deckForce = 18; camZ = 2.6; nextEvAt = 9999 }
        if name == "life3" { deckForce = 20; camZ = 2.6; nextEvAt = 9999 }
        if name == "life4" { deckForce = 22; camZ = 2.6; nextEvAt = 9999 }
        if name == "life5" { deckForce = 16; camZ = 2.6; nextEvAt = 9999 }
        if name == "life6" { deckForce = 23; camZ = 2.6; nextEvAt = 9999 }
        if name == "evneptune" { startOmen("neptune"); sceneT = 2; omenT = 1.6; Game.omenHold = true; camZ = 2.6 }
        if name == "evalb" { startOmen("albatross"); sceneT = 2; omenT = 1.6; Game.omenHold = true; camZ = 2.6 }
        if name == "evlight" { startOmen("lightning"); sceneT = 1.2; omenT = 1.6; Game.omenHold = true }
        if name == "evkraken" { startOmen("kraken"); sceneT = 2; omenT = 1.6; Game.omenHold = true }
        if name == "evstelmo" { startOmen("stelmo"); sceneT = 2; omenT = 1.6; Game.omenHold = true }
        if name == "evcomet" { startOmen("comet"); sceneT = 2.6; omenT = 1.6; Game.omenHold = true }
        if name == "evwhite" { startOmen("whitewhale"); sceneT = 1.2; omenK = ""; event("whitewhale") }
        if name == "evplank" { startOmen("plank"); sceneT = 2.0; omenT = 1.6; Game.omenHold = true; camZ = 1.9 }
        if name == "evscurvy" { startOmen("scurvy"); sceneT = 2; omenK = ""; event("scurvy"); camZ = 2.6 }
        if name == "acts" { deckForce = 9; camZ = 2.6; half = true; nextEvAt = 9999; day = 6 }
        if name == "acts2" { deckForce = 11; camZ = 2.6; nextEvAt = 9999; day = 9 }
        if name == "yard2" { leg = 1; mode = .port; gold = 900; shipwright(); cardT = 9 }
        if name == "yard" { leg = 1; mode = .port; shipwright() }
        if name == "decklife" { ups = ["sails": 2, "hull": 1, "guns": 1]; deckForce = 5; seaForce = 0 }
        if name == "coach1" { UserDefaults.standard.set(false, forKey: "fh_coached"); shipI = 1; crew = ship.crew; hull = Double(ship.hull); syncMen(); marketPort = false; mode = .outfit; return }
        if name == "coach2" { UserDefaults.standard.set(false, forKey: "fh_coached"); leg = 0; mode = .sail; legLen = 300; dist = 20; food = 60; day = 1; dayT = 1; deckForce = 0; camZ = 2.6; nextEvAt = 9999; return }
        if name == "coach3" { UserDefaults.standard.set(false, forKey: "fh_coached"); leg = 1; mode = .port; food = 4; portJobs = []; return }
        if name == "choices" { UserDefaults.standard.set(true, forKey: "fh_coached"); leg = 1; mode = .sail; food = 40; powder = 5; planks = 4; event("kraken"); cardT = 9; return }
        if name == "chartc" { UserDefaults.standard.set(false, forKey: "fh_coached"); leg = 0; mode = .chart; return }
        if name == "evrogue" { startOmen("rogue"); sceneT = 3.4; omenT = 2.6; Game.omenHold = true; return }
        if name == "evrogue2" { startOmen("rogue"); sceneT = 5; omenK = ""; event("rogue"); return }
        if name == "wideshot" { leg = 1; mode = .sail; nextEvAt = 9999; T = 2.5 / 0.035; camZ = 1.1; return }
        if name == "offer" { leg = 1; mode = .sail; nextEvAt = 9999; offerK = "flyfish"; offerT = 2; Game.offerHold = true; offerDone = true; return }
        if name == "mgfly" { leg = 1; mode = .sail; nextEvAt = 9999; startOdd("flyfish"); play?.total = 60; return }
        if name == "mgcask" { leg = 1; mode = .sail; nextEvAt = 9999; startOdd("cask"); return }
        if name == "mgstars" { leg = 1; mode = .sail; nextEvAt = 9999; startOdd("trim"); play?.score = 3; play?.tries = 3; play?.perfect = 2; play?.marks = [2, 1, 2]; play?.endT = 99; play?.endLen = 100; play?.starsShown = 3; return }
        if name == "mgstreak" { leg = 1; mode = .sail; nextEvAt = 9999; startOdd("trim"); play?.streak = 2; play?.marks = [2, 1]; play?.tries = 2; play?.score = 2; play?.pop(W / 2, H - 200, "PERFECT!", true, big: true); return }
        if name == "settings" { leg = 1; mode = .port; openSettings(); cardT = 9; return }
        if name == "mggulls" { leg = 1; mode = .sail; nextEvAt = 9999; startOdd("gulls"); play?.total = 60; return }
        if name == "mgturtle" { leg = 1; mode = .sail; nextEvAt = 9999; startOdd("turtle"); return }
        if name == "mgchest" { leg = 1; mode = .sail; nextEvAt = 9999; startOdd("chest"); return }
        if name == "mggleam" { leg = 1; mode = .sail; nextEvAt = 9999; startOdd("gleam"); play?.total = 60; return }
        if name == "intro" { mode = .title; showIntro(); return }
        if name == "outfit" { shipI = 1; crew = ship.crew; hull = Double(ship.hull); syncMen(); marketPort = false; mode = .outfit; provision(storesNeeded() + 8); return }
        if name == "lowsea" { leg = 1; mode = .sail; legLen = 300; dist = 60; food = 6; deckForce = 0; camZ = 2.6; nextEvAt = 9999; return }
        if name == "town" { leg = 1; mode = .port; portJobs = [1, 8, 11]; tod = 0.3; saluteT = 6; saluteN = 3 }
        if name == "town2" { leg = 2; path[2] = 1; mode = .port; portJobs = [6, 9, 3]; tod = 0.4 }
        if name == "pmarket" { leg = 1; path[1] = 1; mode = .port; openMarket() }
        if name == "town3" { leg = 3; path[3] = 1; mode = .port; portJobs = [7, 5, 10]; tod = 0.45 }
        if name == "town4" { leg = 4; mode = .port; portJobs = [2, 9, 11]; tod = 0.5 }
        if name == "fire" { leg = 1; mode = .port; portJob = 6; playFire() }
        if name == "townnight" { leg = 2; mode = .port; portJobs = [4, 7, 9]; tod = 0.8; festT = 30 }
        if name == "thief" { leg = 1; mode = .port; playThief() }
        if name == "tavern" { leg = 1; mode = .port; tavern() }
        if name == "summary" { leg = 1; mode = .port; legFrom = "Port Haven"; sum = LegSum(from: "Port Haven", to: here.n, days: 7, leagues: 255, events: 3, gold: 140, lost: 0, hull: 86, fights: 1, wages: wagesDue(), ate: 24, drank: 26, warns: ["water low", "1 laid up"]); sumT = 9; sumRow = -1 }
        if name == "storm" { playStorm(); wxDark = 0.85; wxRain = 1; rough = 1; boltT = 7.6 }
        if name == "leak" { playLeak() }
        if name == "dig" { hasMap = true; playIsland() }
        if name == "rain" { setWeather(2, days: 9); wxRain = 0.6; wxDark = 0.6; rough = 0.3 }
        if name == "duel" { UserDefaults.standard.set(0, forKey: Duel.lessonKey); startDuel(foes: 3, boss: false, prize: 120) }
        if name == "teach" { UserDefaults.standard.set(0, forKey: Duel.lessonKey); startDuel(foes: 3, boss: false, prize: 120); card = nil }
        if name == "fight" { startDuel(foes: 6, boss: false, prize: 120, teach: false); duel?.fury = 1; duel?.combo = 3 }
        if name == "killb1" { startDuel(foes: 6, boss: false, prize: 120, teach: false); duel?.demoKill = 0.95; duel?.demoKind = 1 }
        if name == "killb2" { startDuel(foes: 6, boss: false, prize: 120, teach: false); duel?.demoKill = 1.5; duel?.demoKind = 1 }
        if name == "killk" { startDuel(foes: 6, boss: false, prize: 120, teach: false); duel?.demoKill = 0.5; duel?.demoKind = 2 }
        if name == "kill1" { startDuel(foes: 6, boss: false, prize: 120, teach: false); duel?.demoKill = 0.5 }
        if name == "kill2" { startDuel(foes: 6, boss: false, prize: 120, teach: false); duel?.demoKill = 0.9 }
        if name == "kill3" { startDuel(foes: 6, boss: false, prize: 120, teach: false); duel?.demoKill = 1.5 }
        if name == "clash" { startDuel(foes: 6, boss: false, prize: 120, teach: false); duel?.demoClash = true }
        if name == "boss" { startDuel(foes: 1, boss: true, prize: 300, teach: false) }
        if name == "end" { finish() }
    }
}
