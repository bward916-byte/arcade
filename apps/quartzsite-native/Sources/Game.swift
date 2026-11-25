import Foundation

// The rules of the prototype: who you are, what you drive, the camp strip and the hold-to-pay ring.

enum Phase { case title, pick, play }
enum Life: Int { case nomad = 0, rver = 1 }
enum RigKind: Int { case tent = 0, minivan, van, skoolie, classB, classC, classA }

struct RigDef {
    let name: String
    let price: Int
    let len: Double
    let high: Double
    let speed: Double
}
/// Indexed by RigKind.rawValue.
let RIGS: [RigDef] = [
    RigDef(name: "Tent", price: 0, len: 26, high: 14, speed: 0),
    RigDef(name: "Minivan", price: 400, len: 59, high: 20, speed: 150),
    RigDef(name: "Full-size van", price: 900, len: 63, high: 24, speed: 140),
    RigDef(name: "Used skoolie", price: 1800, len: 96, high: 41, speed: 115),
    RigDef(name: "Class B", price: 2400, len: 70, high: 35, speed: 140),
    RigDef(name: "Class C", price: 3600, len: 87, high: 41, speed: 125),
    RigDef(name: "Class A", price: 6500, len: 118, high: 47, speed: 115)
]
/// What each kind of camper can trade up to, in order.
let LADDER: [[RigKind]] = [
    [.tent, .minivan, .van, .skoolie],
    [.tent, .minivan, .van, .classB, .classC, .classA]
]
let START_RIGS: [RigKind] = [.tent, .minivan, .van]
let START_CASH: [Double] = [300, 150, 40]

enum SpotKind { case wash, camp, fire, grocery, tools, rocks, skoolie, swap, lot }
struct Spot {
    let kind: SpotKind
    let x: Double
    let name: String
}
/// What holding the ring at a spot does: `cost` is paid as the ring fills, `earn` is paid out when it closes.
struct Offer {
    let label: String
    let cost: Int
    let earn: Int
    let dur: Double
}

struct TextItem {
    var s: String
    var x: Double
    var y: Double
    var size: Double
    var col: Col
    var align: Int      // 0 centre, 1 left, 2 right
    var bold: Bool
    var wrap: Double    // 0 for a single line
    var plate: Bool
}
struct Floater {
    var s: String
    var x: Double
    var y: Double
    var t: Double
    var col: Col
}
struct Hit {
    let id: Int
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}
struct SaveData: Codable {
    var life: Int
    var rig: Int
    var look: Int
    var money: Double
    var health: Double
    var cred: Int
    var day: Int
    var dayT: Double
    var wood: Int
    var rocks: Int
    var odd: Int
    var panels: Int
    var px: Double
    var rigX: Double
}

final class Input {
    var stick = 0.0
    var hold = false
}

final class Game {
    var W = 400.0
    var H = 185.0
    var GY = 150.0
    var safeL = 0.0
    var safeR = 0.0
    let WORLD = 2900.0
    let DAYLEN = 100.0

    var phase = Phase.title
    var time = 0.0
    let input = Input()
    var texts: [TextItem] = []
    var hits: [Hit] = []
    var floaters: [Floater] = []
    /// 1 a ring closed, 2 money came back, 3 a light tap. The app turns these into haptics.
    var events: [Int] = []
    var hasSave = false
    var showRigs = false

    // the camper
    var life = Life.nomad
    var rig = RigKind.minivan
    var look = 0
    var pickRig = 1

    // the day
    var px = 760.0
    var vx = 0.0
    var face = 1.0
    var walk = 0.0
    var cam = 0.0
    var rigX = 690.0
    var rigFace = 1.0
    var inRig = false
    var money = 150.0
    var health = 100.0
    var cred = 0
    var day = 1
    var dayT = 0.12
    var wood = 0
    var rocks = 0
    var odd = 0
    var panels = 0
    var rockBuy = 24
    var rockSell = 42
    var oddBuy = 30
    var oddSell = 55

    // the ring
    var active = -1
    var ringSpot = -1
    var ringProg = 0.0
    var ringPaid = 0.0
    var holdLock = false
    var nearRig = false

    var hintText = ""
    var hintT = 0.0
    var shown: Set<String> = []

    let spots: [Spot] = [
        Spot(kind: .skoolie, x: 230, name: "SKOOLIEPALOOZA"),
        Spot(kind: .wash, x: 560, name: "DRY WASH"),
        Spot(kind: .camp, x: 760, name: "YOUR CAMP"),
        Spot(kind: .fire, x: 1040, name: "NEIGHBORS' FIRE"),
        Spot(kind: .grocery, x: 1340, name: "POP-UP GROCERY"),
        Spot(kind: .tools, x: 1660, name: "KB TOOLS"),
        Spot(kind: .rocks, x: 1990, name: "ROCK & MINERAL SHOW"),
        Spot(kind: .swap, x: 2300, name: "YOUR TABLE"),
        Spot(kind: .lot, x: 2620, name: "USED RIGS")
    ]

    // MARK: text and hints

    func text(_ s: String, _ x: Double, _ y: Double, _ size: Double, _ col: Col, align: Int = 0, bold: Bool = false, wrap: Double = 0, plate: Bool = false) {
        texts.append(TextItem(s: s, x: x, y: y, size: size, col: col, align: align, bold: bold, wrap: wrap, plate: plate))
    }
    func float(_ s: String, _ x: Double, _ col: Col) {
        floaters.append(Floater(s: s, x: x, y: GY - 34, t: 0, col: col))
    }
    func hint(_ key: String, _ s: String) {
        if shown.contains(key) { return }
        shown.insert(key)
        hintText = s
        hintT = 8
    }

    // MARK: starting

    func tap(_ x: Double, _ y: Double) {
        var id = -1
        for h in hits where x >= h.x && x <= h.x + h.w && y >= h.y && y <= h.y + h.h { id = h.id }
        switch phase {
        case .title:
            if id == 2 || !hasSave { phase = .pick } else if id == 1 { phase = .play } else { return }
            events.append(3)
        case .pick:
            if id == 0 { life = .nomad }
            if id == 1 { life = .rver }
            if id >= 10 && id <= 12 { pickRig = id - 10 }
            if id >= 20 && id <= 23 { look = id - 20 }
            if id == 99 { begin() }
            if id >= 0 { events.append(3) }
        case .play:
            if id == 50 { toggleRig() }
        }
    }

    func begin() {
        rig = START_RIGS[pickRig]
        money = START_CASH[pickRig] + (life == .rver ? 100 : 0)
        cred = life == .nomad ? 5 : 0
        health = 100; day = 1; dayT = 0.12
        wood = 0; rocks = 0; odd = 0; panels = 0
        px = 760; rigX = 690; rigFace = 1; inRig = false; vx = 0
        active = -1; ringSpot = -1; ringProg = 0; ringPaid = 0
        shown = []
        floaters = []
        phase = .play
        hint("start", "Walk with the left pad. Stand by a glowing spot and hold the right side to fill its ring. Let go early and your money comes back.")
    }

    func toggleRig() {
        if inRig {
            inRig = false
            px = rigX + rigFace * (RIGS[rig.rawValue].len / 2 + 8)
            face = rigFace
            vx = 0
        } else if rig == .tent {
            hint("tent", "A tent stays put. Trade up at Used Rigs, east of the shows, and you can drive.")
        } else if abs(px - rigX) < RIGS[rig.rawValue].len / 2 + 22 {
            refund()
            inRig = true
            vx = 0
            hint("drive", "You're behind the wheel. Tap the rig again to get out.")
        }
        events.append(3)
    }

    // MARK: saving

    func snapshot() -> SaveData? {
        if phase != .play { return nil }
        return SaveData(life: life.rawValue, rig: rig.rawValue, look: look, money: money + ringPaid, health: health, cred: cred, day: day,
                        dayT: dayT, wood: wood, rocks: rocks, odd: odd, panels: panels, px: inRig ? rigX : px, rigX: rigX)
    }
    func restore(_ s: SaveData) {
        life = Life(rawValue: s.life) ?? .nomad
        rig = RigKind(rawValue: s.rig) ?? .minivan
        look = s.look; money = s.money; health = s.health; cred = s.cred; day = s.day; dayT = s.dayT
        wood = s.wood; rocks = s.rocks; odd = s.odd; panels = s.panels; px = s.px; rigX = s.rigX
        inRig = false
        shown = ["start"]
        hasSave = true
    }

    /// Screens for the build machine's screenshots.
    func demo(_ key: String) {
        if key == "pick" { phase = .pick; return }
        if key == "rigs" { showRigs = true; return }
        life = .nomad; pickRig = 1; look = 1
        begin()
        hintT = 0
        if key == "night" { px = 1010; dayT = 0.8; wood = 3 }
        if key == "show" { px = 1975; money = 180; rocks = 1 }
        if key == "skoolie" { px = 215; money = 240; rig = .skoolie; rigX = 470; panels = 2; dayT = 0.58 }
        if key == "lot" { px = 2600; money = 900; rig = .van; rigX = 2460; panels = 1 }
        cam = clampD(px - W / 2, 0, WORLD - W)
    }

    // MARK: offers

    func nextRig() -> RigKind? {
        let lad = LADDER[life.rawValue]
        guard let i = lad.firstIndex(of: rig), i + 1 < lad.count else { return nil }
        return lad[i + 1]
    }
    func lotPrice(_ k: RigKind) -> Int {
        return max(50, RIGS[k.rawValue].price - RIGS[rig.rawValue].price / 2)
    }

    func offer(_ i: Int) -> Offer? {
        if inRig { return nil }
        switch spots[i].kind {
        case .wash:
            return wood < 5 ? Offer(label: "Gather firewood", cost: 0, earn: 0, dur: 1.5) : nil
        case .camp:
            return health < 96 ? Offer(label: "Rest by your fire", cost: 0, earn: 0, dur: 2.2) : nil
        case .fire:
            return wood > 0 ? Offer(label: "Sell a bundle of firewood", cost: 0, earn: 10, dur: 0.9) : nil
        case .grocery:
            return health < 96 ? Offer(label: "Groceries", cost: 15, earn: 0, dur: 1.0) : nil
        case .tools:
            if rig == .tent || panels >= 2 { return nil }
            return Offer(label: panels == 0 ? "Solar panel" : "Second solar panel", cost: panels == 0 ? 120 : 200, earn: 0, dur: 1.6)
        case .rocks:
            return rocks < 3 ? Offer(label: "Mineral specimen", cost: rockBuy, earn: 0, dur: 1.0) : nil
        case .skoolie:
            return odd < 3 ? Offer(label: "Cow skull or other oddity", cost: oddBuy, earn: 0, dur: 1.0) : nil
        case .swap:
            if odd > 0 { return Offer(label: "Sell an oddity", cost: 0, earn: oddSell, dur: 1.1) }
            if rocks > 0 { return Offer(label: "Sell a specimen", cost: 0, earn: rockSell, dur: 1.1) }
            return nil
        case .lot:
            guard let n = nextRig() else { return nil }
            return Offer(label: "Trade up: " + RIGS[n.rawValue].name, cost: lotPrice(n), earn: 0, dur: 2.2)
        }
    }

    /// Why a spot has nothing to offer right now.
    func note(_ i: Int) -> String {
        if inRig { return "Tap your rig to get out" }
        switch spots[i].kind {
        case .wash: return "Arms full. Sell it at the neighbors' fire"
        case .camp: return "Home. You feel fine"
        case .fire: return "Bring firewood from the dry wash, west of camp"
        case .grocery: return "You're not hungry"
        case .tools: return rig == .tent ? "Solar needs a roof. Get a rig first" : "Your roof is full of panels"
        case .rocks: return "Pack is full. Sell at your table"
        case .skoolie: return "Pack is full. Sell at your table"
        case .swap: return "Nothing to sell. Buy at the mineral show or Skooliepalooza"
        case .lot: return "Top of the line. Nothing bigger here"
        }
    }

    private func complete(_ i: Int, _ o: Offer) {
        let x = spots[i].x
        switch spots[i].kind {
        case .wash:
            wood += 1
            float("+1 firewood", x, CREAM)
        case .camp:
            health = min(100, health + 18)
            float("Rested", x, GREEN)
        case .fire:
            wood -= 1
            cred += 1
        case .grocery:
            health = min(100, health + 45)
            float("Fed", x, GREEN)
        case .tools:
            panels += 1
            float("Solar on the roof", x, CREAM)
        case .rocks:
            rocks += 1
            float("+1 specimen", x, CREAM)
        case .skoolie:
            odd += 1
            cred += 1
            float("+1 oddity", x, CREAM)
        case .swap:
            if odd > 0 { odd -= 1; cred += 3 } else { rocks -= 1; cred += 2 }
        case .lot:
            if let n = nextRig() {
                rig = n
                rigX = x - 110
                rigFace = 1
                float(RIGS[n.rawValue].name + " is yours", x, GOLD)
                hint("newrig", "New wheels. Walk up to your rig and tap it to climb in.")
            }
        }
        if o.earn > 0 {
            money += Double(o.earn)
            float("+$\(o.earn)", x, GREEN)
        }
        if cred >= 12 { hint("cred12", "Folks wave when you walk by now.") }
        if cred >= 30 { hint("cred30", "People know your name. A Facebook page of your own comes later.") }
        events.append(1)
    }

    private func refund() {
        if ringPaid > 0.5 {
            money += ringPaid
            float("$\(Int(ringPaid.rounded())) back", px, GOLD)
            events.append(2)
        }
        ringPaid = 0
        ringProg = 0
    }

    // MARK: the frame

    func update(_ dt: Double) {
        time += dt
        var i = 0
        while i < floaters.count {
            floaters[i].t += dt
            floaters[i].y -= dt * 9
            if floaters[i].t > 1.8 { floaters.remove(at: i) } else { i += 1 }
        }
        if hintT > 0 { hintT -= dt }
        if phase == .play { play(dt) }
    }

    private func dawn() {
        day += 1
        rockBuy = Int(rnd(18, 32))
        rockSell = rockBuy + Int(rnd(10, 30))
        oddBuy = Int(rnd(24, 40))
        oddSell = oddBuy + Int(rnd(14, 40))
        if panels > 0 {
            let pay = panels * 6
            money += Double(pay)
            float("+$\(pay) charging phones off your solar", inRig ? rigX : px, GREEN)
        }
    }

    private func play(_ dt: Double) {
        dayT += dt / DAYLEN
        if dayT >= 1 { dayT -= 1; dawn() }
        health = max(0, health - dt * 100 / (DAYLEN * 2.2))
        if health < 35 { hint("hungry", "You're run down. The pop-up grocery is east of camp, or rest by your own fire.") }

        // moving: on foot, or behind the wheel
        let s = abs(input.stick) < 0.15 ? 0 : input.stick
        if inRig {
            let top = RIGS[rig.rawValue].speed
            vx += (s * top - vx) * min(1, dt * 2.2)
            rigX = clampD(rigX + vx * dt, 60, WORLD - 60)
            if abs(vx) > 6 { rigFace = vx > 0 ? 1 : -1 }
            px = rigX
        } else {
            let top = health <= 0 ? 36.0 : 64.0
            vx += (s * top - vx) * min(1, dt * 9)
            px = clampD(px + vx * dt, 30, WORLD - 30)
            if abs(vx) > 4 { face = vx > 0 ? 1 : -1; walk += dt * 11 }
        }
        cam += (clampD(px - W / 2, 0, WORLD - W) - cam) * min(1, dt * 6)
        nearRig = inRig || abs(px - rigX) < RIGS[rig.rawValue].len / 2 + 22

        // which spot is in reach
        var best = -1
        var bd = 30.0
        for (i, sp) in spots.enumerated() {
            let d = abs(px - sp.x)
            if d < bd { bd = d; best = i }
        }
        active = best
        if active != ringSpot {
            refund()
            ringSpot = active
        }
        if !input.hold {
            if ringProg > 0 { refund() }
            holdLock = false
            return
        }
        if holdLock || active < 0 { return }
        guard let o = offer(active) else { return }
        ringProg += dt / o.dur
        let want = Double(o.cost) * min(1, ringProg)
        let step = want - ringPaid
        if step > money + 0.001 {
            refund()
            holdLock = true
            float("Not enough cash", px, REDC)
            return
        }
        money -= step
        ringPaid = want
        if ringProg >= 1 {
            ringPaid = 0
            ringProg = 0
            holdLock = true
            complete(active, o)
        }
    }
}
