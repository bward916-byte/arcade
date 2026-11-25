import Foundation

// The rules: who you are, what you drive and ride, the calendar of winter events, the places, and the hold-to-pay ring.

enum Phase { case title, pick, play }
enum Life: Int { case nomad = 0, rver = 1 }
enum RigKind: Int { case tent = 0, minivan, van, skoolie, classB, classC, classA }
enum Area: Int { case ltva = 0, main, tyson, dome, skoolie, trail, scaddan }

struct RigDef {
    let name: String
    let price: Int
    let len: Double
    let high: Double
    let speed: Double
    let perMile: Double
}
/// Indexed by RigKind.rawValue. Sizes are game pixels at about 3.5 to the foot. perMile is gas money.
let RIGS: [RigDef] = [
    RigDef(name: "Tent", price: 0, len: 26, high: 14, speed: 0, perMile: 0),
    RigDef(name: "Minivan", price: 400, len: 59, high: 20, speed: 150, perMile: 0.18),
    RigDef(name: "Full-size van", price: 900, len: 63, high: 24, speed: 140, perMile: 0.27),
    RigDef(name: "Used skoolie", price: 1800, len: 96, high: 41, speed: 115, perMile: 0.5),
    RigDef(name: "Class B", price: 2400, len: 70, high: 35, speed: 140, perMile: 0.24),
    RigDef(name: "Class C", price: 3600, len: 87, high: 41, speed: 125, perMile: 0.4),
    RigDef(name: "Class A", price: 6500, len: 118, high: 47, speed: 115, perMile: 0.57)
]
/// What each kind of camper can trade up to, in order.
let LADDER: [[RigKind]] = [
    [.tent, .minivan, .van, .skoolie],
    [.tent, .minivan, .van, .classB, .classC, .classA]
]
let START_RIGS: [RigKind] = [.tent, .minivan, .van]
let START_CASH: [Double] = [300, 150, 40]

/// Things to get around on. range is how far it will take you in miles (0 means anywhere).
struct ToyDef {
    let name: String
    let price: Int
    let speed: Double
    let len: Double
    let perMile: Double
    let range: Double
}
let TOYS: [ToyDef] = [
    ToyDef(name: "Bicycle", price: 60, speed: 80, len: 20, perMile: 0, range: 6),
    ToyDef(name: "E-bike", price: 350, speed: 100, len: 21, perMile: 0, range: 15),
    ToyDef(name: "Dirt bike", price: 800, speed: 150, len: 25, perMile: 0.07, range: 0),
    ToyDef(name: "Quad", price: 1200, speed: 135, len: 27, perMile: 0.15, range: 0),
    ToyDef(name: "Used car", price: 1800, speed: 160, len: 46, perMile: 0.15, range: 0),
    ToyDef(name: "Side-by-side", price: 2400, speed: 150, len: 38, perMile: 0.2, range: 0),
    ToyDef(name: "Supercharged side-by-side", price: 5500, speed: 215, len: 48, perMile: 0.3, range: 0)
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

/// The 2027 winter season, from the Quartzsite Campfire guide. Day 1 is Monday, December 28, 2026.
struct EventDef {
    let name: String
    let when: String
    let start: Int
    let end: Int
    let area: Area
}
let EVENTS: [EventDef] = [
    EventDef(name: "Tyson Wells Rock & Gem Show", when: "Jan 1–10", start: 5, end: 14, area: .tyson),
    EventDef(name: "Rubber Tramp Rendezvous", when: "Jan 9–14", start: 13, end: 18, area: .main),
    EventDef(name: "Sports, Vacation & RV Show", when: "Jan 15–23", start: 19, end: 27, area: .tyson),
    EventDef(name: "Tyson Wells Sell-A-Rama", when: "Jan 15–24", start: 19, end: 28, area: .tyson),
    EventDef(name: "Skooliepalooza", when: "Jan 16–26", start: 20, end: 30, area: .skoolie),
    EventDef(name: "Tyson Wells Arts & Craft Fair", when: "Jan 29 – Feb 7", start: 33, end: 42, area: .tyson),
    EventDef(name: "Prospectors Panorama", when: "Jan 1 – Feb 28", start: 5, end: 63, area: .tyson)
]
let EV_GEM = 0, EV_RTR = 1, EV_RV = 2, EV_SELL = 3, EV_SKOOL = 4, EV_CRAFT = 5, EV_PAN = 6
let START_WEEKDAY = 1   // Monday

enum SpotKind { case camp, bench, fire, wash, host, station, outhouse, board, grocery, gemworld, landmark, park, hall, yacht, lot, rides, tools, panorama, vendors, office, booth, bigtent, mine, detect, rockhound, river, skoolie, circle, cabin }
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
    let arrive: Double
    let lat: Double
    let lon: Double
    let spots: [Spot]
}

/// Seven places around Quartzsite. You get between them from the map: drive, ride, or take the Camel Express.
let AREAS: [AreaDef] = [
    AreaDef(name: "La Posa South", sub: "LTVA 2.5 miles south of town · water and the dump station", w: 2500, arrive: 1130, lat: 33.6255, lon: -114.216, spots: [
        Spot(kind: .board, x: 260, name: "BULLETIN BOARD"),
        Spot(kind: .host, x: 500, name: "CAMP HOST"),
        Spot(kind: .station, x: 760, name: "DUMP & WATER"),
        Spot(kind: .outhouse, x: 980, name: "OUTHOUSE"),
        Spot(kind: .camp, x: 1260, name: "YOUR CAMP"),
        Spot(kind: .bench, x: 1400, name: "JEWELRY BENCH"),
        Spot(kind: .fire, x: 1710, name: "NEIGHBORS' FIRE"),
        Spot(kind: .wash, x: 2150, name: "DRY WASH")
    ]),
    AreaDef(name: "Main Street", sub: "Quartzsite, in season", w: 3420, arrive: 180, lat: 33.667, lon: -114.214, spots: [
        Spot(kind: .landmark, x: 390, name: "HI JOLLY MONUMENT", arg: 0),
        Spot(kind: .grocery, x: 690, name: "POP-UP GROCERY"),
        Spot(kind: .gemworld, x: 990, name: "GEM WORLD"),
        Spot(kind: .landmark, x: 1300, name: "READER'S OASIS", arg: 1),
        Spot(kind: .park, x: 1620, name: "TOWN PARK"),
        Spot(kind: .board, x: 1920, name: "COMMUNITY BOARD"),
        Spot(kind: .hall, x: 2180, name: "TOWN HALL"),
        Spot(kind: .yacht, x: 2480, name: "QUARTZSITE YACHT CLUB"),
        Spot(kind: .lot, x: 2800, name: "USED RIGS"),
        Spot(kind: .rides, x: 3140, name: "RIDES FOR SALE")
    ]),
    AreaDef(name: "Tyson Wells", sub: "The show grounds on Kuehn Street", w: 3000, arrive: 160, lat: 33.6625, lon: -114.2215, spots: [
        Spot(kind: .tools, x: 380, name: "KB TOOLS"),
        Spot(kind: .panorama, x: 700, name: "PROSPECTORS PANORAMA"),
        Spot(kind: .vendors, x: 1060, name: "SHOW VENDORS"),
        Spot(kind: .office, x: 1370, name: "SHOW OFFICE"),
        Spot(kind: .booth, x: 1580, name: "YOUR BOOTH", arg: 0),
        Spot(kind: .landmark, x: 1880, name: "TYSON'S WELL", arg: 2),
        Spot(kind: .bigtent, x: 2400, name: "THE BIG TENT")
    ]),
    AreaDef(name: "Dome Rock", sub: "Free BLM camping west of town · 14-day limit", w: 2640, arrive: 2350, lat: 33.648, lon: -114.33, spots: [
        Spot(kind: .rockhound, x: 430, name: "ROCKHOUNDING"),
        Spot(kind: .mine, x: 820, name: "GOLD EYE MINE"),
        Spot(kind: .detect, x: 1220, name: "OLD PLACER DIGGINGS"),
        Spot(kind: .camp, x: 1620, name: "YOUR CAMP"),
        Spot(kind: .bench, x: 1760, name: "JEWELRY BENCH"),
        Spot(kind: .wash, x: 2080, name: "DRY WASH")
    ]),
    AreaDef(name: "Near Ehrenberg", sub: "Public land 10 miles west, toward the river", w: 2200, arrive: 1960, lat: 33.625, lon: -114.39, spots: [
        Spot(kind: .river, x: 260, name: "THE RIVER"),
        Spot(kind: .skoolie, x: 660, name: "SKOOLIEPALOOZA"),
        Spot(kind: .booth, x: 960, name: "YOUR SPOT", arg: 1),
        Spot(kind: .circle, x: 1260, name: "THE CIRCLE"),
        Spot(kind: .landmark, x: 1700, name: "PIONEER CEMETERY", arg: 3)
    ]),
    AreaDef(name: "Pipeline Trail", sub: "Rough desert two-track east of La Posa", w: 2800, arrive: 160, lat: 33.636, lon: -114.183, spots: [
        Spot(kind: .cabin, x: 1050, name: "MINER'S CABIN"),
        Spot(kind: .rockhound, x: 1920, name: "QUARTZ WASH")
    ]),
    AreaDef(name: "Scaddan Wash", sub: "Free 14-day BLM camping east of town", w: 2200, arrive: 300, lat: 33.6493, lon: -114.1512, spots: [
        Spot(kind: .camp, x: 640, name: "DISPERSED CAMP"),
        Spot(kind: .fire, x: 1080, name: "NOMAD FIRE"),
        Spot(kind: .rockhound, x: 1520, name: "WASH AGATES"),
        Spot(kind: .wash, x: 1900, name: "MESQUITE WASH")
    ])
]
let LANDMARKS = ["Pay respects at Hi Jolly's tomb", "Browse the books", "Read the stage-stop plaque", "Walk the old cemetery"]

/// Straight-line miles between two places.
func milesBetween(_ a: Area, _ b: Area) -> Double {
    let p = AREAS[a.rawValue], q = AREAS[b.rawValue]
    let la = (p.lat + q.lat) / 2 * PI / 180
    let dx = (p.lon - q.lon) * 69.17 * cos(la), dy = (p.lat - q.lat) * 69.17
    return (sqrt(dx * dx + dy * dy) * 2).rounded() / 2
}

func dateText(_ d: Int) -> String {
    let wk = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][(START_WEEKDAY + d - 1) % 7]
    let months: [(String, Int)] = [("Dec", 31), ("Jan", 31), ("Feb", 28), ("Mar", 31), ("Apr", 30), ("May", 31), ("Jun", 30), ("Jul", 31), ("Aug", 31), ("Sep", 30), ("Oct", 31), ("Nov", 30)]
    var n = d + 27
    var m = 0
    while n > months[m % 12].1 { n -= months[m % 12].1; m += 1 }
    return "\(wk) \(months[m % 12].0) \(n)"
}

/// What holding the ring at a spot does: `cost` is paid as the ring fills, `earn` is paid out when it closes.
struct Offer {
    let label: String
    let cost: Int
    let earn: Int
    let dur: Double
}
/// One line on the travel map: can you go there from here, how, and for how much.
struct Trip {
    let ok: Bool
    let cost: Int
    let how: String
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
    var campDays: Int
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
    var px = 1260.0
    var vx = 0.0
    var face = 1.0
    var walk = 0.0
    var cam = 0.0
    var rigX = 1150.0
    var rigFace = 1.0
    var inRig = false
    var toy = -1
    var toyArea = Area.main
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
    var campDays = 0
    var business = 0
    var adDays = 0
    var page = false
    var boothDay = 0
    /// Things done once a day: landmarks 0–3, then 10 yacht club, 11 dump station, 12 free pile, 13 the circle, 14 park rest.
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

    // the map
    var mapOpen = false
    var mapMsg = ""
    var mapMsgT = 0.0

    var hintText = ""
    var hintT = 0.0
    var arriveT = 0.0
    var shown: Set<String> = []

    // MARK: text, hints, calendar

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
    func on(_ e: Int) -> Bool { return day >= EVENTS[e].start && day <= EVENTS[e].end }
    /// Which Tyson Wells show is running today, if any.
    func tysonShow() -> Int? {
        for e in [EV_GEM, EV_SELL, EV_CRAFT] where on(e) { return e }
        return nil
    }
    /// The next of these events still to come, as "Name, when".
    func nextOf(_ ids: [Int]) -> String {
        var best = -1
        for e in ids where EVENTS[e].start > day && (best < 0 || EVENTS[e].start < EVENTS[best].start) { best = e }
        return best < 0 ? "Done for this season" : EVENTS[best].name + ", " + EVENTS[best].when
    }

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
            if mapOpen {
                if id >= 70 && id < 70 + AREAS.count { go(Area(rawValue: id - 70) ?? area) } else if id == 61 || id < 0 { mapOpen = false }
                events.append(3)
                return
            }
            if id == 50 { toggleRig() }
            if id == 51 { toggleToy() }
            if id == 60 { openMap() }
        }
    }

    func begin() {
        rig = START_RIGS[pickRig]
        money = START_CASH[pickRig] + (life == .rver ? 100 : 0)
        cred = life == .nomad ? 5 : 0
        health = 100; day = 1; dayT = 0.12
        wood = 0; rocks = 0; odd = 0; jewelry = 0; panels = 0
        area = .ltva; rigArea = .ltva
        px = 1260; rigX = 1150; rigFace = 1; inRig = false; vx = 0
        toy = -1; onToy = false
        detector = false; permitDays = 14; campDays = 0; business = 0; adDays = 0; page = false; seen = []; boothDay = 0
        active = -1; ringSpot = -1; ringProg = 0; ringPaid = 0
        mapOpen = false
        shown = []
        floaters = []
        phase = .play
        arriveT = 4.5
        hint("start", "Walk with the left pad. Stand by a glowing spot and hold the right side to fill its ring. Let go early and your money comes back. Tap MAP to go somewhere else.")
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
            hint("tent", "A tent stays put. Trade up at Used Rigs on Main Street and you can drive.")
        } else if abs(px - rigX) < RIGS[rig.rawValue].len / 2 + 22 {
            refund()
            if onToy { onToy = false; toyX = px }
            inRig = true
            vx = 0
            hint("drive", "You're behind the wheel. Open the map to drive somewhere, or pull up to the dump station. Tap the rig to get out.")
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
            hint("ride", "You can still stop at places while you ride. Open the map to ride to another place.")
        }
        events.append(3)
    }

    // MARK: getting around

    func openMap() {
        refund()
        mapOpen = true
        mapMsg = ""
        hint("map", "Pick a place. You go in whatever you're in: your rig, your ride, or on foot by the Camel Express dial-a-ride.")
    }

    /// How you would get from here to there right now.
    func trip(_ to: Area) -> Trip {
        if to == area { return Trip(ok: false, cost: 0, how: "You're here") }
        let mi = milesBetween(area, to)
        if to == .trail || area == .trail {
            if inRig || (onToy && toy == 4) { return Trip(ok: false, cost: 0, how: "Too rough. Take a side-by-side or bike") }
            if onToy { return Trip(ok: true, cost: 0, how: "Ride the trail") }
            let next = to == .trail ? area : to
            if next == .ltva || next == .scaddan { return Trip(ok: true, cost: 0, how: "Hike the trail") }
            return Trip(ok: false, cost: 0, how: "Hike in from La Posa or Scaddan Wash")
        }
        if inRig { return Trip(ok: true, cost: max(1, Int((mi * RIGS[rig.rawValue].perMile).rounded(.up))), how: "Drive the " + RIGS[rig.rawValue].name.lowercased()) }
        if onToy {
            let t = TOYS[toy]
            if t.range > 0 && mi > t.range { return Trip(ok: false, cost: 0, how: "Too far for the " + t.name.lowercased()) }
            return Trip(ok: true, cost: Int((mi * t.perMile).rounded(.up)), how: "Ride the " + t.name.lowercased())
        }
        if to == .skoolie { return Trip(ok: false, cost: 0, how: "10 miles out. You need wheels") }
        if area == .skoolie { return Trip(ok: true, cost: 0, how: "Ride back with a nomad family") }
        return Trip(ok: true, cost: 2, how: "Camel Express dial-a-ride")
    }

    private func go(_ to: Area) {
        let t = trip(to)
        if !t.ok { mapMsg = t.how; mapMsgT = 2.5; return }
        if Double(t.cost) > money { mapMsg = "Not enough money for that"; mapMsgT = 2.5; return }
        money -= Double(t.cost)
        mapOpen = false
        travel(to)
    }

    private func travel(_ to: Area) {
        area = to
        px = AREAS[to.rawValue].arrive
        vx = 0
        if inRig { rigArea = to; rigX = px; rigFace = px < WORLD / 2 ? 1 : -1 }
        if onToy { toyArea = to; toyX = px }
        face = px < WORLD / 2 ? 1 : -1
        cam = clampD(px - W / 2, 0, max(0, WORLD - W))
        active = -1
        ringSpot = -1
        floaters = []
        arriveT = 4.5
        if to == .skoolie && !on(EV_SKOOL) { hint("skoolnot", "Quiet out here. Skooliepalooza gathers on " + EVENTS[EV_SKOOL].when + ".") }
        if to == .tyson && tysonShow() == nil { hint("tysonnot", "The show grounds are empty today. Next: " + nextOf([EV_GEM, EV_SELL, EV_CRAFT]) + ".") }
    }

    // MARK: saving

    func snapshot() -> SaveData? {
        if phase != .play { return nil }
        return SaveData(life: life.rawValue, rig: rig.rawValue, look: look, money: money + ringPaid, health: health, cred: cred, day: day,
                        dayT: dayT, wood: wood, rocks: rocks, odd: odd, panels: panels, px: inRig ? rigX : px, rigX: rigX,
                        area: area.rawValue, rigArea: rigArea.rawValue, toy: toy, toyArea: toyArea.rawValue, toyX: onToy ? px : toyX,
                        permitDays: permitDays, business: business, adDays: adDays, page: page, jewelry: jewelry, detector: detector, campDays: campDays)
    }
    func restore(_ s: SaveData) {
        life = Life(rawValue: s.life) ?? .nomad
        rig = RigKind(rawValue: s.rig) ?? .minivan
        look = s.look; money = s.money; health = s.health; cred = s.cred; day = s.day; dayT = s.dayT
        wood = s.wood; rocks = s.rocks; odd = s.odd; panels = s.panels; px = s.px; rigX = s.rigX
        area = Area(rawValue: s.area) ?? .ltva
        rigArea = Area(rawValue: s.rigArea) ?? .ltva
        toy = s.toy; toyArea = Area(rawValue: s.toyArea) ?? .main; toyX = s.toyX
        permitDays = s.permitDays; business = s.business; adDays = s.adDays; page = s.page; jewelry = s.jewelry; detector = s.detector
        campDays = s.campDays
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
        if key == "night" { px = 1690; dayT = 0.8; wood = 3 }
        if key == "ltva" { px = 760; dayT = 0.3; rig = .classB; inRig = true; rigX = 760 }
        if key == "main" { place(.main, 1610); money = 400; day = 14 }
        if key == "gem" { place(.tyson, 1050); money = 300; day = 7; rocks = 1 }
        if key == "tyson" { life = .rver; place(.tyson, 2390); money = 3000; day = 21; rig = .classB }
        if key == "dome" { place(.dome, 800); rig = .classB; rigArea = .dome; rigX = 1520; dayT = 0.56 }
        if key == "toys" { place(.main, 3130); money = 3000; toy = 3; toyArea = .main; toyX = 3050 }
        if key == "ride" { place(.dome, 1260); toy = 6; toyArea = .dome; toyX = 1260; onToy = true; detector = true }
        if key == "skoolie" { place(.skoolie, 650); money = 240; day = 22; rig = .skoolie; rigArea = .skoolie; rigX = 880; panels = 2; dayT = 0.58 }
        if key == "trail" { place(.trail, 1080); toy = 3; toyArea = .trail; toyX = 1080; onToy = true; dayT = 0.42 }
        if key == "scaddan" { place(.scaddan, 660); toy = 3; toyArea = .scaddan; toyX = 660; onToy = true; dayT = 0.57 }
        if key == "map" { toy = 1; toyArea = .ltva; toyX = 1300; onToy = true; px = 1300; day = 18; mapOpen = true }
        arriveT = key == "main" ? 2.5 : 0
        hintT = 0
    }
    private func place(_ a: Area, _ x: Double) {
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
        return max(20, TOYS[n].price - (toy >= 0 ? TOYS[toy].price / 2 : 0))
    }
    /// What you'd sell first from your booth.
    private func sellOffer() -> Offer? {
        if jewelry > 0 { return Offer(label: "Sell a pendant", cost: 0, earn: jewelSell, dur: 1.1) }
        if odd > 0 { return Offer(label: "Sell an oddity", cost: 0, earn: oddSell, dur: 1.1) }
        if rocks > 0 { return Offer(label: "Sell a specimen", cost: 0, earn: rockSell, dur: 1.1) }
        return nil
    }
    func boothOpen(_ i: Int) -> Bool {
        let sp = spots[i]
        if sp.arg == 1 { return on(EV_SKOOL) }
        return tysonShow() != nil && boothDay == day
    }

    func offer(_ i: Int) -> Offer? {
        let sp = spots[i]
        if inRig && sp.kind != .station { return nil }
        switch sp.kind {
        case .wash:
            return wood < 5 ? Offer(label: "Gather firewood", cost: 0, earn: 0, dur: 1.5) : nil
        case .camp:
            if rigArea != area {
                return rig == .tent ? Offer(label: "Pitch your tent here", cost: 0, earn: 0, dur: 2) : nil
            }
            if area == .ltva && permitDays <= 0 { return nil }
            if cred >= 25 && !page { return Offer(label: "Start a Facebook page", cost: 0, earn: 0, dur: 2) }
            return health < 96 ? Offer(label: "Rest by your fire", cost: 0, earn: 0, dur: 2.2) : nil
        case .bench:
            if rigArea != area { return nil }
            return rocks > 0 && jewelry < 4 ? Offer(label: "Wire-wrap a pendant", cost: 0, earn: 0, dur: 2.6) : nil
        case .fire:
            return wood > 0 ? Offer(label: "Sell a bundle of firewood", cost: 0, earn: 10, dur: 0.9) : nil
        case .host:
            return permitDays < 4 ? Offer(label: "14-day LTVA permit", cost: 40, earn: 0, dur: 1.2) : nil
        case .station:
            return inRig && rig != .tent && !seen.contains(11) ? Offer(label: "Dump tanks and fill water", cost: 0, earn: 0, dur: 2) : nil
        case .outhouse:
            return health < 96 ? Offer(label: "Use the outhouse", cost: 0, earn: 0, dur: 1.0) : nil
        case .board:
            return business > 0 && adDays == 0 ? Offer(label: "Post an ad: " + BIZ[business - 1].name, cost: 10, earn: 0, dur: 1.2) : nil
        case .grocery:
            return health < 96 ? Offer(label: "Groceries", cost: 15, earn: 0, dur: 1.0) : nil
        case .gemworld:
            return rocks < 3 ? Offer(label: "Rough rock to work", cost: rockBuy + 14, earn: 0, dur: 1.0) : nil
        case .park:
            if on(EV_RTR) { return seen.contains(12) ? nil : Offer(label: "Rubber Tramp Rendezvous: talks and the free pile", cost: 0, earn: 0, dur: 2) }
            return health < 96 && !seen.contains(14) ? Offer(label: "Rest in the shade", cost: 0, earn: 0, dur: 1.6) : nil
        case .hall:
            return business < BIZ.count ? Offer(label: "License: " + BIZ[business].name, cost: BIZ[business].cost, earn: 0, dur: 2.2) : nil
        case .yacht:
            return seen.contains(10) ? nil : Offer(label: "Burger and karaoke", cost: 12, earn: 0, dur: 1.6)
        case .lot:
            guard let n = nextRig() else { return nil }
            return Offer(label: "Trade up: " + RIGS[n.rawValue].name, cost: lotPrice(n), earn: 0, dur: 2.2)
        case .rides:
            let n = toy + 1
            return n < TOYS.count ? Offer(label: (toy >= 0 ? "Trade up: " : "") + TOYS[n].name, cost: toyPrice(n), earn: 0, dur: 2) : nil
        case .tools:
            if rig == .tent || panels >= 2 { return nil }
            return Offer(label: panels == 0 ? "Solar panel" : "Second solar panel", cost: panels == 0 ? 120 : 200, earn: 0, dur: 1.6)
        case .panorama:
            return on(EV_PAN) && !detector ? Offer(label: "Metal detector", cost: 150, earn: 0, dur: 1.4) : nil
        case .vendors:
            guard let e = tysonShow() else { return nil }
            if e == EV_GEM { return rocks < 3 ? Offer(label: "Mineral specimen", cost: rockBuy, earn: 0, dur: 1.0) : nil }
            if e == EV_SELL { return odd < 3 ? Offer(label: "Swap-meet oddity", cost: oddBuy, earn: 0, dur: 1.0) : nil }
            return nil
        case .office:
            return tysonShow() != nil && boothDay != day ? Offer(label: "Vendor space for today", cost: 20, earn: 0, dur: 1.4) : nil
        case .booth:
            return boothOpen(i) ? sellOffer() : nil
        case .bigtent:
            guard on(EV_RV), let n = nextRig() else { return nil }
            return Offer(label: "Show deal: " + RIGS[n.rawValue].name, cost: lotPrice(n) * 85 / 100, earn: 0, dur: 2.2)
        case .mine:
            return health > 20 ? Offer(label: "Explore the old mine", cost: 0, earn: 0, dur: 3) : nil
        case .detect:
            return detector ? Offer(label: "Swing the detector", cost: 0, earn: 0, dur: 2.6) : nil
        case .rockhound:
            return rocks < 3 && health > 10 ? Offer(label: "Look for quartz on the hillside", cost: 0, earn: 0, dur: 2.2) : nil
        case .landmark:
            return seen.contains(sp.arg) ? nil : Offer(label: LANDMARKS[sp.arg], cost: 0, earn: 0, dur: 1.5)
        case .river:
            return health < 96 ? Offer(label: "Sit by the river", cost: 0, earn: 0, dur: 2.2) : nil
        case .skoolie:
            return on(EV_SKOOL) && odd < 3 ? Offer(label: "Cow skull or other oddity", cost: oddBuy, earn: 0, dur: 1.0) : nil
        case .circle:
            return on(EV_SKOOL) && !seen.contains(13) ? Offer(label: "Potluck at the circle", cost: 0, earn: 0, dur: 2) : nil
        case .cabin:
            return health > 15 ? Offer(label: "Search the old cabin", cost: 0, earn: 0, dur: 2.2) : nil
        }
    }

    /// Why a spot has nothing to offer right now.
    func note(_ i: Int) -> String {
        let sp = spots[i]
        if inRig { return sp.kind == .station ? "Done for today" : "Tap your rig to get out" }
        switch sp.kind {
        case .wash: return "Arms full. Sell it at the neighbors' fire"
        case .camp:
            if rigArea != area { return "Your rig is parked at " + areaName(rigArea) }
            if area == .ltva && permitDays <= 0 { return "Your permit ran out. See the camp host" }
            return "Home. You feel fine"
        case .bench:
            if rigArea != area { return "Your tools are with your rig" }
            return jewelry >= 4 ? "Plenty made. Sell them from a booth at a show" : "Bring rough rock or a specimen to work"
        case .fire: return "Bring firewood from the dry wash"
        case .host: return "Permit good for \(permitDays) more days"
        case .station: return rig == .tent ? "Tents don't need it" : (seen.contains(11) ? "Done for today" : "Drive your rig over to dump and fill")
        case .outhouse: return "You're good for now"
        case .board:
            if business == 0 { return "Start a business at Town Hall, then advertise here" }
            return "Your ad is up \(adDays) more days"
        case .grocery: return "You're not hungry"
        case .gemworld: return "Pack is full"
        case .park:
            if on(EV_RTR) { return "See you tomorrow at the Rendezvous" }
            return "Rubber Tramp Rendezvous: " + EVENTS[EV_RTR].when
        case .hall: return "You run every business in town"
        case .yacht: return "Back tomorrow night"
        case .lot: return "Top of the line. Nothing bigger here"
        case .rides: return "Nothing faster for sale"
        case .tools: return rig == .tent ? "Solar needs a roof. Get a rig first" : "Your roof is full of panels"
        case .panorama: return on(EV_PAN) ? "Try the old placer diggings at Dome Rock" : "Open " + EVENTS[EV_PAN].when
        case .vendors:
            guard let e = tysonShow() else { return "Next show: " + nextOf([EV_GEM, EV_SELL, EV_CRAFT]) }
            if e == EV_CRAFT { return "Crafts and art. Sell your pendants from a booth" }
            return "Pack is full. Sell from a booth"
        case .office: return tysonShow() == nil ? "Closed between shows" : "Your space is paid for today"
        case .booth:
            if sp.arg == 1 { return on(EV_SKOOL) ? "Nothing to sell" : "Skooliepalooza: " + EVENTS[EV_SKOOL].when }
            if tysonShow() == nil { return "Booths only during shows" }
            return boothDay == day ? "Nothing to sell" : "Rent vendor space at the show office"
        case .bigtent: return on(EV_RV) ? "Top of the line already" : "Sports, Vacation & RV Show: " + EVENTS[EV_RV].when
        case .mine: return "Too worn out. Rest first"
        case .detect: return "You need a metal detector from Prospectors Panorama"
        case .rockhound: return rocks >= 3 ? "Pack is full" : "Too worn out. Rest first"
        case .landmark: return "You've been here today"
        case .river: return "The river's nice today"
        case .skoolie: return on(EV_SKOOL) ? "Pack is full" : "Skooliepalooza: " + EVENTS[EV_SKOOL].when + " (projected)"
        case .circle: return on(EV_SKOOL) ? "See you tomorrow" : "Skooliepalooza: " + EVENTS[EV_SKOOL].when + " (projected)"
        case .cabin: return "Too worn out. Rest first"
        }
    }

    private func complete(_ i: Int, _ o: Offer) {
        let sp = spots[i]
        let x = sp.x
        switch sp.kind {
        case .wash:
            wood += 1
            float("+1 firewood", x, CREAM)
        case .camp:
            if rigArea != area {
                rigArea = area
                rigX = x - 60
                campDays = 0
                float("Tent pitched", x, CREAM)
            } else if cred >= 25 && !page {
                page = true
                float("Your page is live", x, GOLD)
                hintT = 0
                hint("page", "Your Facebook page is up. It pays a little every morning, more as your cred grows. Landmarks give it posts.")
            } else {
                health = min(100, health + 20)
                float("Rested", x, GREEN)
            }
        case .bench:
            rocks -= 1
            jewelry += 1
            float("+1 pendant", x, CREAM)
            hint("jewel", "Pendants sell for a bit more than raw stone from a booth at a show. Small money, but it adds up.")
        case .fire:
            wood -= 1
            cred += 1
        case .host:
            permitDays += 14
            float("Permit for 14 more days", x, CREAM)
        case .station:
            seen.insert(11)
            health = min(100, health + 10)
            float("Tanks dumped, water full", x, GREEN)
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
        case .gemworld:
            rocks += 1
            float("+1 rough rock", x, CREAM)
        case .park:
            if on(EV_RTR) {
                seen.insert(12)
                cred += 2
                if odd < 3 { odd += 1; float("Free pile: an old lantern", x, CREAM) } else { float("+2 cred", x, GOLD) }
            } else {
                seen.insert(14)
                health = min(100, health + 10)
                float("Cooled off", x, GREEN)
            }
        case .hall:
            business += 1
            cred += 3
            float(BIZ[business - 1].name + " is open", x, GOLD)
            hint("biz", "It pays every morning. Post an ad on a bulletin board and it pays half again for three days.")
        case .yacht:
            seen.insert(10)
            health = min(100, health + 20)
            cred += 1
            float("You sang. People clapped", x, GOLD)
        case .lot, .bigtent:
            if let n = nextRig() {
                rig = n
                rigArea = area
                rigX = x - 110
                rigFace = 1
                campDays = 0
                float(RIGS[n.rawValue].name + " is yours", x, GOLD)
                hint("newrig", "New wheels. Walk up to your rig and tap it to climb in.")
            }
        case .rides:
            toy += 1
            toyArea = area
            toyX = onToy ? px : x - 50
            float(TOYS[toy].name + " is yours", x, GOLD)
            hint("toy", "Tap it to hop on. Tap again to hop off.")
        case .tools:
            panels += 1
            float("Solar on the roof", x, CREAM)
        case .panorama:
            detector = true
            float("Metal detector", x, CREAM)
            hint("detect", "Take it to the old placer diggings at Dome Rock.")
        case .vendors:
            if tysonShow() == EV_GEM { rocks += 1; float("+1 specimen", x, CREAM) } else { odd += 1; float("+1 oddity", x, CREAM) }
        case .office:
            boothDay = day
            float("Your booth is set up", x, CREAM)
        case .booth:
            if jewelry > 0 { jewelry -= 1; cred += 2 } else if odd > 0 { odd -= 1; cred += 3 } else { rocks -= 1; cred += 2 }
            if sp.arg == 1 { cred += 1 }
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
            if Double.random(in: 0..<1) < 0.55 { rocks += 1; float("+1 quartz", x, CREAM) } else { float("Pretty gravel", x, CREAM) }
        case .landmark:
            seen.insert(sp.arg)
            cred += page ? 2 : 1
            float(page ? "Posted to your page" : "+1 cred", x, GOLD)
        case .river:
            health = min(100, health + 14)
            float("Calm", x, GREEN)
        case .skoolie:
            odd += 1
            cred += 1
            float("+1 oddity", x, CREAM)
        case .circle:
            seen.insert(13)
            health = min(100, health + 15)
            cred += 2
            float("Fed and welcomed", x, GOLD)
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
        if mapMsgT > 0 { mapMsgT -= dt }
        if hintT > 0 && !mapOpen { hintT -= dt }
        if arriveT > 0 && !mapOpen { arriveT -= dt }
        if phase == .play && !mapOpen { play(dt) }
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
        if permitDays > 0 && rigArea == .ltva {
            permitDays -= 1
            if permitDays == 0 { hintT = 0; hint("permit\(day)", "Your LTVA permit ran out. The camp host sells another 14 days.") }
        }
        if rigArea == .dome || rigArea == .scaddan {
            campDays += 1
            if campDays == 12 { hintT = 0; hint("limit\(day)", "Two days left on your 14 at " + areaName(rigArea) + ". BLM wants you to move on after that.") }
        } else {
            campDays = 0
        }
        for e in EVENTS.indices where EVENTS[e].start == day && e != EV_PAN {
            hintT = 0
            hint("ev\(e)", EVENTS[e].name + " opens today at " + areaName(EVENTS[e].area) + ".")
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
        if health < 35 { hint("hungry", "You're run down. Groceries on Main Street, the outhouse and your own camp all help.") }

        // moving: on foot, on a ride, or behind the wheel
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
