import Foundation

// The rules: who you are, what you drive and ride, the places, and the hold-to-pay ring.

enum Phase { case title, pick, play }
enum Life: Int { case nomad = 0, rver = 1 }
enum RigKind: Int { case tent = 0, minivan, van, skoolie, classB, classC, classA }
enum Area: Int { case ltva = 0, town, dome, ehrenberg, trail, scaddan }

struct RigDef {
    let name: String
    let price: Int
    let len: Double
    let high: Double
    let speed: Double
}
/// Indexed by RigKind.rawValue. Sizes are game pixels at about 3.5 to the foot.
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

/// Things to ride around on. All of them are street legal in Arizona, so they can take the road between places.
struct ToyDef {
    let name: String
    let price: Int
    let speed: Double
    let len: Double
    let gas: Int
}
let TOYS: [ToyDef] = [
    ToyDef(name: "E-bike", price: 350, speed: 100, len: 21, gas: 0),
    ToyDef(name: "Dirt bike", price: 800, speed: 150, len: 25, gas: 2),
    ToyDef(name: "Quad", price: 1200, speed: 135, len: 27, gas: 3),
    ToyDef(name: "Side-by-side", price: 2400, speed: 150, len: 38, gas: 4),
    ToyDef(name: "Supercharged side-by-side", price: 5500, speed: 215, len: 48, gas: 6)
]

/// Businesses you can license at Town Hall, each needing more money up front. They pay every morning.
struct BizDef {
    let name: String
    let cost: Int
    let pay: Int
}
let BIZ: [BizDef] = [
    BizDef(name: "Firewood delivery", cost: 250, pay: 14),
    BizDef(name: "Jewelry booth", cost: 600, pay: 30),
    BizDef(name: "Solar installs", cost: 1500, pay: 70),
    BizDef(name: "Mobile RV repair", cost: 3500, pay: 150)
]

enum SpotKind { case road, wash, camp, bench, fire, host, outhouse, board, grocery, tools, prospector, rocks, skoolie, swap, hall, lot, toys, mine, detect, rockhound, landmark, river, cabin }
struct Spot {
    let kind: SpotKind
    let x: Double
    let name: String
    var arg = 0
}
struct AreaDef {
    let name: String
    let sub: String
    let w: Double
    let spots: [Spot]
}

/// West to east: Ehrenberg, Dome Rock, Quartzsite, La Posa, Pipeline Trail, Scaddan Wash.
let AREAS: [AreaDef] = [
    AreaDef(name: "La Posa LTVA", sub: "The long-term visitor area south of town", w: 2400, spots: [
        Spot(kind: .road, x: 90, name: "QUARTZSITE", arg: 1),
        Spot(kind: .board, x: 330, name: "BULLETIN BOARD"),
        Spot(kind: .host, x: 570, name: "CAMP HOST"),
        Spot(kind: .outhouse, x: 810, name: "OUTHOUSE"),
        Spot(kind: .camp, x: 1080, name: "YOUR CAMP"),
        Spot(kind: .bench, x: 1220, name: "JEWELRY BENCH"),
        Spot(kind: .fire, x: 1530, name: "NEIGHBORS' FIRE"),
        Spot(kind: .wash, x: 1960, name: "DRY WASH"),
        Spot(kind: .road, x: 2310, name: "PIPELINE TRAIL", arg: 4)
    ]),
    AreaDef(name: "Quartzsite", sub: "Main Street, in season", w: 3640, spots: [
        Spot(kind: .road, x: 90, name: "DOME ROCK", arg: 2),
        Spot(kind: .landmark, x: 340, name: "HI JOLLY'S TOMB", arg: 0),
        Spot(kind: .grocery, x: 650, name: "POP-UP GROCERY"),
        Spot(kind: .tools, x: 960, name: "KB TOOLS"),
        Spot(kind: .prospector, x: 1260, name: "PROSPECTOR SUPPLY"),
        Spot(kind: .landmark, x: 1560, name: "READER'S OASIS", arg: 1),
        Spot(kind: .rocks, x: 1890, name: "ROCK & MINERAL SHOW"),
        Spot(kind: .swap, x: 2190, name: "YOUR TABLE"),
        Spot(kind: .board, x: 2410, name: "COMMUNITY BOARD"),
        Spot(kind: .hall, x: 2660, name: "TOWN HALL"),
        Spot(kind: .lot, x: 2960, name: "USED RIGS"),
        Spot(kind: .toys, x: 3260, name: "TOYS & E-BIKES"),
        Spot(kind: .road, x: 3550, name: "LA POSA LTVA", arg: 0)
    ]),
    AreaDef(name: "Dome Rock", sub: "Free BLM camping west of town", w: 2640, spots: [
        Spot(kind: .road, x: 90, name: "EHRENBERG", arg: 3),
        Spot(kind: .rockhound, x: 430, name: "ROCKHOUNDING"),
        Spot(kind: .mine, x: 820, name: "GOLD EYE MINE"),
        Spot(kind: .detect, x: 1220, name: "OLD PLACER DIGGINGS"),
        Spot(kind: .camp, x: 1620, name: "YOUR CAMP"),
        Spot(kind: .bench, x: 1760, name: "JEWELRY BENCH"),
        Spot(kind: .wash, x: 2080, name: "DRY WASH"),
        Spot(kind: .road, x: 2550, name: "QUARTZSITE", arg: 1)
    ]),
    AreaDef(name: "Ehrenberg", sub: "Down by the Colorado River", w: 1700, spots: [
        Spot(kind: .river, x: 300, name: "THE RIVER"),
        Spot(kind: .skoolie, x: 760, name: "SKOOLIEPALOOZA"),
        Spot(kind: .road, x: 1610, name: "DOME ROCK", arg: 2)
    ]),
    AreaDef(name: "Pipeline Trail", sub: "Rough desert two-track east of La Posa", w: 2800, spots: [
        Spot(kind: .road, x: 90, name: "LA POSA LTVA", arg: 0),
        Spot(kind: .cabin, x: 1050, name: "MINER'S CABIN"),
        Spot(kind: .rockhound, x: 1920, name: "QUARTZ WASH"),
        Spot(kind: .road, x: 2710, name: "SCADDAN WASH", arg: 5)
    ]),
    AreaDef(name: "Scaddan Wash", sub: "Free 14-day BLM camping east of town", w: 2200, spots: [
        Spot(kind: .road, x: 90, name: "PIPELINE TRAIL", arg: 4),
        Spot(kind: .camp, x: 640, name: "DISPERSED CAMP"),
        Spot(kind: .fire, x: 1080, name: "NOMAD FIRE"),
        Spot(kind: .rockhound, x: 1520, name: "WASH AGATES"),
        Spot(kind: .wash, x: 1900, name: "MESQUITE WASH")
    ])
]
let LANDMARKS = ["Pay respects at Hi Jolly's tomb", "Browse the books"]

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
    var area: Int
    var rigArea: Int
    var toy: Int
    var toyArea: Int
    var toyX: Double
    var permitDays: Int
    var business: Int
    var adDays: Int
    var page: Bool
    var jewelry: Int
    var detector: Bool
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

    // where everything is
    var area = Area.ltva
    var rigArea = Area.ltva
    var spots: [Spot] { return AREAS[area.rawValue].spots }
    var WORLD: Double { return AREAS[area.rawValue].w }

    // the day
    var px = 1080.0
    var vx = 0.0
    var face = 1.0
    var walk = 0.0
    var cam = 0.0
    var rigX = 980.0
    var rigFace = 1.0
    var inRig = false
    var toy = -1
    var toyArea = Area.town
    var toyX = 0.0
    var onToy = false
    var money = 150.0
    var health = 100.0
    var cred = 0
    var day = 1
    var dayT = 0.12
    var wood = 0
    var rocks = 0
    var odd = 0
    var jewelry = 0
    var panels = 0
    var detector = false
    var permitDays = 14
    var business = 0
    var adDays = 0
    var page = false
    var seen: Set<Int> = []
    var rockBuy = 24
    var rockSell = 42
    var oddBuy = 30
    var oddSell = 55
    var jewelSell = 56

    // the ring
    var active = -1
    var ringSpot = -1
    var ringProg = 0.0
    var ringPaid = 0.0
    var holdLock = false
    var nearRig = false
    var nearToy = false

    var hintText = ""
    var hintT = 0.0
    var arriveT = 0.0
    var shown: Set<String> = []

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
    func areaName(_ a: Area) -> String { return AREAS[a.rawValue].name }

    // MARK: starting

    func tap(_ x: Double, _ y: Double) {
        var id = -1
        for h in hits where x >= h.x && x <= h.x + h.w && y >= h.y && y <= h.y + h.h { id = h.id }
        switch phase {
        case .title:
            if id == 2 || !hasSave { phase = .pick } else if id == 1 { phase = .play; arriveT = 4.5 } else { return }
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
            if id == 51 { toggleToy() }
        }
    }

    func begin() {
        rig = START_RIGS[pickRig]
        money = START_CASH[pickRig] + (life == .rver ? 100 : 0)
        cred = life == .nomad ? 5 : 0
        health = 100; day = 1; dayT = 0.12
        wood = 0; rocks = 0; odd = 0; jewelry = 0; panels = 0
        area = .ltva; rigArea = .ltva
        px = 1080; rigX = 980; rigFace = 1; inRig = false; vx = 0
        toy = -1; onToy = false
        detector = false; permitDays = 14; business = 0; adDays = 0; page = false; seen = []
        active = -1; ringSpot = -1; ringProg = 0; ringPaid = 0
        shown = []
        floaters = []
        phase = .play
        arriveT = 4.5
        hint("start", "Walk with the left pad. Stand by a glowing spot and hold the right side to fill its ring. Let go early and your money comes back. Your LTVA permit is paid for 14 days.")
    }

    func toggleRig() {
        if inRig {
            inRig = false
            px = rigX + rigFace * (RIGS[rig.rawValue].len / 2 + 8)
            face = rigFace
            vx = 0
        } else if rigArea != area {
            return
        } else if rig == .tent {
            hint("tent", "A tent stays put. Trade up at Used Rigs in town and you can drive.")
        } else if abs(px - rigX) < RIGS[rig.rawValue].len / 2 + 22 {
            refund()
            if onToy { onToy = false; toyX = px }
            inRig = true
            vx = 0
            hint("drive", "You're behind the wheel. Drive to a road sign and hold to head somewhere else. Tap the rig to get out.")
        }
        events.append(3)
    }

    func toggleToy() {
        if inRig || toy < 0 || toyArea != area { return }
        if onToy {
            onToy = false
            toyX = px
        } else if abs(px - toyX) < TOYS[toy].len / 2 + 18 {
            onToy = true
            px = toyX
            vx = 0
            hint("ride", "Off you go. You can still stop at places while you ride, and it's legal on the road to any town.")
        }
        events.append(3)
    }

    // MARK: saving

    func snapshot() -> SaveData? {
        if phase != .play { return nil }
        return SaveData(life: life.rawValue, rig: rig.rawValue, look: look, money: money + ringPaid, health: health, cred: cred, day: day,
                        dayT: dayT, wood: wood, rocks: rocks, odd: odd, panels: panels, px: inRig ? rigX : px, rigX: rigX,
                        area: area.rawValue, rigArea: rigArea.rawValue, toy: toy, toyArea: toyArea.rawValue, toyX: onToy ? px : toyX,
                        permitDays: permitDays, business: business, adDays: adDays, page: page, jewelry: jewelry, detector: detector)
    }
    func restore(_ s: SaveData) {
        life = Life(rawValue: s.life) ?? .nomad
        rig = RigKind(rawValue: s.rig) ?? .minivan
        look = s.look; money = s.money; health = s.health; cred = s.cred; day = s.day; dayT = s.dayT
        wood = s.wood; rocks = s.rocks; odd = s.odd; panels = s.panels; px = s.px; rigX = s.rigX
        area = Area(rawValue: s.area) ?? .ltva
        rigArea = Area(rawValue: s.rigArea) ?? .ltva
        toy = s.toy; toyArea = Area(rawValue: s.toyArea) ?? .town; toyX = s.toyX
        permitDays = s.permitDays; business = s.business; adDays = s.adDays; page = s.page; jewelry = s.jewelry; detector = s.detector
        inRig = false; onToy = false
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
        arriveT = 0
        if key == "night" { px = 1500; dayT = 0.8; wood = 3 }
        if key == "ltva" { px = 640; dayT = 0.3; cred = 30; business = 1; adDays = 2 }
        if key == "town" { travelTo(.town, 360); money = 400 }
        if key == "show" { travelTo(.town, 1880); money = 180; rocks = 1 }
        if key == "lot" { travelTo(.town, 2940); money = 900; rig = .van; rigArea = .town; rigX = 2800; panels = 1 }
        if key == "dome" { travelTo(.dome, 800); rig = .classB; rigArea = .dome; rigX = 1520; dayT = 0.56 }
        if key == "toys" { travelTo(.town, 3250); money = 3000; toy = 2; toyArea = .town; toyX = 3170 }
        if key == "ride" { travelTo(.dome, 1260); toy = 4; toyArea = .dome; toyX = 1260; onToy = true; detector = true }
        if key == "skoolie" { travelTo(.ehrenberg, 745); money = 240; rig = .skoolie; rigArea = .ehrenberg; rigX = 980; panels = 2; dayT = 0.58 }
        if key == "trail" { travelTo(.trail, 1080); toy = 3; toyArea = .trail; toyX = 1080; onToy = true; dayT = 0.42 }
        if key == "scaddan" { travelTo(.scaddan, 660); toy = 3; toyArea = .scaddan; toyX = 660; onToy = true; dayT = 0.57 }
        arriveT = key == "town" ? 2.5 : 0
    }
    private func travelTo(_ a: Area, _ x: Double) {
        area = a
        px = x
        cam = clampD(px - W / 2, 0, max(0, WORLD - W))
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
    func toyPrice(_ n: Int) -> Int {
        return max(50, TOYS[n].price - (toy >= 0 ? TOYS[toy].price / 2 : 0))
    }
    func gasCost() -> Int {
        if inRig { return 4 + Int(RIGS[rig.rawValue].len / 20) }
        if onToy && toy >= 0 && toy < TOYS.count { return TOYS[toy].gas }
        return 5
    }

    func offer(_ i: Int) -> Offer? {
        let sp = spots[i]
        if inRig && sp.kind != .road { return nil }
        switch sp.kind {
        case .road:
            let toArea = Area(rawValue: sp.arg) ?? .town
            if inRig && (area == .trail || toArea == .trail) { return nil }
            let to = areaName(toArea)
            let isTrail = area == .trail || toArea == .trail
            let verb = inRig ? "Drive to " : (onToy ? "Ride to " : (isTrail ? "Hike to " : "Catch a ride to "))
            return Offer(label: verb + to, cost: isTrail ? 0 : gasCost(), earn: 0, dur: 1.4)
        case .wash:
            return wood < 5 ? Offer(label: "Gather firewood", cost: 0, earn: 0, dur: 1.5) : nil
        case .camp:
            if rigArea != area {
                return rig == .tent ? Offer(label: "Pitch your tent here", cost: 0, earn: 0, dur: 2) : nil
            }
            if area == .ltva && permitDays <= 0 { return nil }
            if cred >= 25 && !page { return Offer(label: "Start a Facebook page", cost: 0, earn: 0, dur: 2) }
            return health < 96 ? Offer(label: area == .ltva ? "Rest: water, dump, hot meal" : "Rest by your fire", cost: 0, earn: 0, dur: 2.2) : nil
        case .bench:
            if rigArea != area { return nil }
            return rocks > 0 && jewelry < 4 ? Offer(label: "Wire-wrap a pendant", cost: 0, earn: 0, dur: 2.6) : nil
        case .fire:
            return wood > 0 ? Offer(label: "Sell a bundle of firewood", cost: 0, earn: 10, dur: 0.9) : nil
        case .host:
            return permitDays < 4 ? Offer(label: "14-day LTVA permit", cost: 40, earn: 0, dur: 1.2) : nil
        case .outhouse:
            return health < 96 ? Offer(label: "Use the outhouse", cost: 0, earn: 0, dur: 1.0) : nil
        case .board:
            return business > 0 && adDays == 0 ? Offer(label: "Post an ad: " + BIZ[business - 1].name, cost: 10, earn: 0, dur: 1.2) : nil
        case .grocery:
            return health < 96 ? Offer(label: "Groceries", cost: 15, earn: 0, dur: 1.0) : nil
        case .tools:
            if rig == .tent || panels >= 2 { return nil }
            return Offer(label: panels == 0 ? "Solar panel" : "Second solar panel", cost: panels == 0 ? 120 : 200, earn: 0, dur: 1.6)
        case .prospector:
            return detector ? nil : Offer(label: "Metal detector", cost: 150, earn: 0, dur: 1.4)
        case .rocks:
            return rocks < 3 ? Offer(label: "Mineral specimen", cost: rockBuy, earn: 0, dur: 1.0) : nil
        case .skoolie:
            return odd < 3 ? Offer(label: "Cow skull or other oddity", cost: oddBuy, earn: 0, dur: 1.0) : nil
        case .swap:
            if jewelry > 0 { return Offer(label: "Sell a pendant", cost: 0, earn: jewelSell, dur: 1.1) }
            if odd > 0 { return Offer(label: "Sell an oddity", cost: 0, earn: oddSell, dur: 1.1) }
            if rocks > 0 { return Offer(label: "Sell a specimen", cost: 0, earn: rockSell, dur: 1.1) }
            return nil
        case .hall:
            return business < BIZ.count ? Offer(label: "License: " + BIZ[business].name, cost: BIZ[business].cost, earn: 0, dur: 2.2) : nil
        case .lot:
            guard let n = nextRig() else { return nil }
            return Offer(label: "Trade up: " + RIGS[n.rawValue].name, cost: lotPrice(n), earn: 0, dur: 2.2)
        case .toys:
            let n = toy + 1
            return n < TOYS.count ? Offer(label: (toy >= 0 ? "Trade up: " : "") + TOYS[n].name, cost: toyPrice(n), earn: 0, dur: 2) : nil
        case .mine:
            return health > 20 ? Offer(label: "Explore the old mine", cost: 0, earn: 0, dur: 3) : nil
        case .detect:
            return detector ? Offer(label: "Swing the detector", cost: 0, earn: 0, dur: 2.6) : nil
        case .rockhound:
            return rocks < 3 && health > 10 ? Offer(label: "Rockhound the hillside", cost: 0, earn: 0, dur: 2.2) : nil
        case .landmark:
            return seen.contains(sp.arg) ? nil : Offer(label: LANDMARKS[sp.arg], cost: 0, earn: 0, dur: 1.5)
        case .river:
            return health < 96 ? Offer(label: "Sit by the river", cost: 0, earn: 0, dur: 2.2) : nil
        case .cabin:
            return health > 15 ? Offer(label: "Search the old cabin", cost: 0, earn: 0, dur: 2.2) : nil
        }
    }

    /// Why a spot has nothing to offer right now.
    func note(_ i: Int) -> String {
        if inRig {
            let sp = spots[i]
            if sp.kind == .road {
                let toArea = Area(rawValue: sp.arg) ?? .town
                if area == .trail || toArea == .trail {
                    return "Too rough for your rig. Take a side-by-side or bike"
                }
            }
            return "Tap your rig to get out"
        }
        switch spots[i].kind {
        case .road: return ""
        case .wash: return "Arms full. Sell it at the neighbors' fire"
        case .camp:
            if rigArea != area { return "Your rig is parked at " + areaName(rigArea) }
            if area == .ltva && permitDays <= 0 { return "Your permit ran out. See the camp host" }
            return "Home. You feel fine"
        case .bench:
            if rigArea != area { return "Your tools are with your rig" }
            return jewelry >= 4 ? "Plenty made. Sell them at your table in town" : "Bring a mineral specimen to work"
        case .fire: return "Bring firewood from the dry wash"
        case .host: return "Permit good for \(permitDays) more days"
        case .outhouse: return "You're good for now"
        case .board:
            if business == 0 { return "Start a business at Town Hall, then advertise here" }
            return "Your ad is up \(adDays) more days"
        case .grocery: return "You're not hungry"
        case .tools: return rig == .tent ? "Solar needs a roof. Get a rig first" : "Your roof is full of panels"
        case .prospector: return "Try the old diggings at Dome Rock"
        case .rocks: return "Pack is full. Sell at your table"
        case .skoolie: return "Pack is full. Sell at your table in town"
        case .swap: return "Nothing to sell. Shows, mines and your bench"
        case .hall: return "You run every business in town"
        case .lot: return "Top of the line. Nothing bigger here"
        case .toys: return "Nothing faster on the lot"
        case .mine: return "Too worn out. Rest first"
        case .detect: return "You need a metal detector from Prospector Supply in town"
        case .rockhound: return rocks >= 3 ? "Pack is full" : "Too worn out. Rest first"
        case .landmark: return "You've been here today"
        case .river: return "The river's nice today"
        case .cabin: return "Too worn out. Rest first"
        }
    }

    private func complete(_ i: Int, _ o: Offer) {
        let sp = spots[i]
        let x = sp.x
        switch sp.kind {
        case .road:
            travel(Area(rawValue: sp.arg) ?? .town)
        case .wash:
            wood += 1
            float("+1 firewood", x, CREAM)
        case .camp:
            if rigArea != area {
                rigArea = area
                rigX = x - 60
                float("Tent pitched", x, CREAM)
            } else if cred >= 25 && !page {
                page = true
                float("Your page is live", x, GOLD)
                hintT = 0
                hint("page", "Your Facebook page is up. Followers come with cred, and the page pays a little every morning. Visiting landmarks gives it posts.")
            } else {
                health = min(100, health + (area == .ltva ? 26 : 18))
                float("Rested", x, GREEN)
            }
        case .bench:
            rocks -= 1
            jewelry += 1
            float("+1 pendant", x, CREAM)
            hint("jewel", "Pendants sell for a bit more than raw stones at your table in town. Small money, but it adds up.")
        case .fire:
            wood -= 1
            cred += 1
        case .host:
            permitDays += 14
            float("Permit for 14 more days", x, CREAM)
        case .outhouse:
            health = min(100, health + 6)
            float("Relief", x, GREEN)
        case .board:
            adDays = 3
            cred += 1
            float("Ad posted for 3 days", x, CREAM)
        case .grocery:
            health = min(100, health + 45)
            float("Fed", x, GREEN)
        case .tools:
            panels += 1
            float("Solar on the roof", x, CREAM)
        case .prospector:
            detector = true
            float("Metal detector", x, CREAM)
            hint("detect", "Take it to the old placer diggings at Dome Rock, west of town.")
        case .rocks:
            rocks += 1
            float("+1 specimen", x, CREAM)
        case .skoolie:
            odd += 1
            cred += 1
            float("+1 oddity", x, CREAM)
        case .swap:
            if jewelry > 0 { jewelry -= 1; cred += 2 } else if odd > 0 { odd -= 1; cred += 3 } else { rocks -= 1; cred += 2 }
        case .hall:
            business += 1
            cred += 3
            float(BIZ[business - 1].name + " is open", x, GOLD)
            hint("biz", "It pays every morning. Post an ad on a bulletin board and it pays half again for three days.")
        case .lot:
            if let n = nextRig() {
                rig = n
                rigArea = area
                rigX = x - 110
                rigFace = 1
                float(RIGS[n.rawValue].name + " is yours", x, GOLD)
                hint("newrig", "New wheels. Walk up to your rig and tap it to climb in.")
            }
        case .toys:
            toy += 1
            toyArea = area
            toyX = onToy ? px : x - 50
            float(TOYS[toy].name + " is yours", x, GOLD)
            hint("toy", "Tap it to hop on. Tap again to hop off.")
        case .mine:
            health = max(0, health - 12)
            let r = Double.random(in: 0..<1)
            if r < 0.4 && rocks < 3 { rocks += 1; float("Found a specimen", x, CREAM) }
            else if r < 0.6 && odd < 3 { odd += 1; float("Found an old lantern", x, CREAM) }
            else if r < 0.8 { let g = Int(rnd(20, 60)); money += Double(g); float("+$\(g) in gold", x, GOLD) }
            else { float("Just bats", x, CREAM) }
            cred += 1
        case .detect:
            let r = Double.random(in: 0..<1)
            if r < 0.5 { let g = Int(rnd(1, 6)); money += Double(g); float("Old coins +$\(g)", x, GOLD) }
            else if r < 0.65 && odd < 3 { odd += 1; float("A rusty spur", x, CREAM) }
            else if r < 0.73 { let g = Int(rnd(40, 120)); money += Double(g); float("Gold nugget! +$\(g)", x, GOLD); cred += 2 }
            else { float("Pull tab", x, CREAM) }
        case .rockhound:
            health = max(0, health - 4)
            if Double.random(in: 0..<1) < 0.55 { rocks += 1; float("+1 specimen", x, CREAM) } else { float("Pretty gravel", x, CREAM) }
        case .landmark:
            seen.insert(sp.arg)
            cred += page ? 2 : 1
            float(page ? "Posted to your page" : "+1 cred", x, GOLD)
        case .river:
            health = min(100, health + 14)
            float("Calm", x, GREEN)
        case .cabin:
            health = max(0, health - 6)
            let r = Double.random(in: 0..<1)
            if r < 0.45 && odd < 3 { odd += 1; float("Found an old canteen", x, CREAM) }
            else if r < 0.75 { let g = Int(rnd(8, 28)); money += Double(g); float("Stashed silver +$\(g)", x, GOLD) }
            else { float("Just packrat nests", x, CREAM) }
            cred += 1
        }
        if o.earn > 0 {
            money += Double(o.earn)
            float("+$\(o.earn)", x, GREEN)
        }
        if cred >= 12 { hint("cred12", "Folks wave when you walk by now.") }
        if cred >= 25 && !page { hint("cred25", "People know your name. Start a Facebook page at your camp.") }
        events.append(1)
    }

    private func travel(_ to: Area) {
        let from = area.rawValue
        area = to
        var ex = WORLD / 2
        for s in spots where s.kind == .road && s.arg == from { ex = s.x < WORLD / 2 ? s.x + 80 : s.x - 80 }
        px = ex
        vx = 0
        if inRig { rigArea = to; rigX = px; rigFace = ex < WORLD / 2 ? 1 : -1 }
        if onToy { toyArea = to; toyX = px }
        face = ex < WORLD / 2 ? 1 : -1
        cam = clampD(px - W / 2, 0, max(0, WORLD - W))
        active = -1
        ringSpot = -1
        floaters = []
        arriveT = 4.5
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
        if arriveT > 0 { arriveT -= dt }
        if phase == .play { play(dt) }
    }

    private func dawn() {
        day += 1
        rockBuy = Int(rnd(18, 32))
        rockSell = rockBuy + Int(rnd(10, 30))
        oddBuy = Int(rnd(24, 40))
        oddSell = oddBuy + Int(rnd(14, 40))
        jewelSell = rockSell + Int(rnd(8, 20))
        seen = []
        var total = panels * 6
        if business > 0 {
            var b = 0
            for k in 0..<business { b += BIZ[k].pay }
            if adDays > 0 { b = b * 3 / 2; adDays -= 1 }
            total += b
        }
        if page { total += cred / 3 }
        if permitDays > 0 {
            permitDays -= 1
            if permitDays == 0 { hintT = 0; hint("permit\(day)", "Your LTVA permit ran out. The camp host sells another 14 days.") }
        }
        if total > 0 {
            money += Double(total)
            float("+$\(total) overnight", px, GREEN)
        }
    }

    private func play(_ dt: Double) {
        dayT += dt / DAYLEN
        if dayT >= 1 { dayT -= 1; dawn() }
        health = max(0, health - dt * 100 / (DAYLEN * 2.2))
        if health < 35 { hint("hungry", "You're run down. Groceries in town, the outhouse and your own camp all help.") }

        // moving: on foot, on a toy, or behind the wheel
        let s = abs(input.stick) < 0.15 ? 0 : input.stick
        if inRig {
            let top = RIGS[rig.rawValue].speed
            vx += (s * top - vx) * min(1, dt * 2.2)
            rigX = clampD(rigX + vx * dt, 60, WORLD - 60)
            if abs(vx) > 6 { rigFace = vx > 0 ? 1 : -1 }
            px = rigX
        } else if onToy && toy >= 0 && toy < TOYS.count {
            let top = TOYS[toy].speed
            vx += (s * top - vx) * min(1, dt * 3.5)
            px = clampD(px + vx * dt, 30, WORLD - 30)
            if abs(vx) > 5 { face = vx > 0 ? 1 : -1 }
            toyX = px
            walk += abs(vx) * dt * 0.4
        } else {
            let top = health <= 0 ? 36.0 : 64.0
            vx += (s * top - vx) * min(1, dt * 9)
            px = clampD(px + vx * dt, 30, WORLD - 30)
            if abs(vx) > 4 { face = vx > 0 ? 1 : -1; walk += dt * 11 }
        }
        cam += (clampD(px - W / 2, 0, max(0, WORLD - W)) - cam) * min(1, dt * 6)
        nearRig = rigArea == area && (inRig || abs(px - rigX) < RIGS[rig.rawValue].len / 2 + 22)
        nearToy = toy >= 0 && toyArea == area && !inRig && (onToy || abs(px - toyX) < TOYS[toy].len / 2 + 18)

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
