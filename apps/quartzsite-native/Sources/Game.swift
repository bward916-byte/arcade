import Foundation

// The rules: who you are, what you drive and ride, the calendar of winter events, the places, and the hold-to-pay ring.

enum Phase { case title, pick, play }
enum Life: Int { case nomad = 0, rver = 1 }
enum RigKind: Int { case tent = 0, minivan, van, skoolie, classB, classC, classA }
enum Area: Int { case ltva = 0, main, tyson, dome, skoolie, trail, scaddan, roadrunner, hijolly, plomosa, crystal, palms, desertbar, intaglios }

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
    ToyDef(name: "Bicycle", price: 60, speed: 115, len: 20, perMile: 0, range: 6),
    ToyDef(name: "E-bike", price: 350, speed: 140, len: 21, perMile: 0, range: 15),
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

/// Rig gear any camper can add. It moves over to your next rig when you trade up.
let UPGRADES: [(String, Int)] = [("Lithium battery bank", 300), ("Awning", 180), ("Roof rack", 220), ("Starlink dish", 500)]
let UP_LITHIUM = 0, UP_AWNING = 1, UP_RACK = 2, UP_STARLINK = 3

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
    EventDef(name: "Prospectors Panorama", when: "Jan 1 – Feb 28", start: 5, end: 63, area: .tyson),
    EventDef(name: "Hi Jolly Parade", when: "Sat Jan 9", start: 13, end: 13, area: .main),
    EventDef(name: "Quartzfest", when: "Jan 17–23", start: 21, end: 27, area: .roadrunner),
    EventDef(name: "Buck Connors Western Days", when: "Mar 19–20", start: 82, end: 83, area: .main)
]
let EV_GEM = 0, EV_RTR = 1, EV_RV = 2, EV_SELL = 3, EV_SKOOL = 4, EV_CRAFT = 5, EV_PAN = 6, EV_PARADE = 7, EV_QFEST = 8, EV_WESTERN = 9
/// April 15: the end of the LTVA season. Snowbirds head north the next morning.
let SEASON_END = 109
let START_WEEKDAY = 1   // Monday

enum SpotKind { case pool, solar, beerbelly, carls, terribles, camp, bench, fire, wash, host, station, outhouse, board, grocery, gemworld, landmark, park, hall, yacht, lot, rides, tools, panorama, vendors, office, booth, bigtent, mine, detect, rockhound, river, skoolie, circle, cabin, parade, rvpark, house, computer, radio, cleanup, camel, dogpark, stray, pizza, post, laundry, shop, tour, hike, bar, watch, village, labyrinth, magic }
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
    AreaDef(name: "La Posa South", sub: "LTVA 2.5 miles south of town · water and the dump station", w: 3040, arrive: 1130, lat: 33.6255, lon: -114.216, spots: [
        Spot(kind: .labyrinth, x: 2640, name: "ROCK LABYRINTH"),
        Spot(kind: .magic, x: 2900, name: "MAGIC CIRCLE"),
        Spot(kind: .board, x: 260, name: "BULLETIN BOARD"),
        Spot(kind: .host, x: 500, name: "CAMP HOST"),
        Spot(kind: .station, x: 760, name: "DUMP & WATER"),
        Spot(kind: .outhouse, x: 980, name: "OUTHOUSE"),
        Spot(kind: .camp, x: 1260, name: "YOUR CAMP"),
        Spot(kind: .bench, x: 1400, name: "JEWELRY BENCH"),
        Spot(kind: .fire, x: 1710, name: "NEIGHBORS' FIRE"),
        Spot(kind: .wash, x: 2150, name: "DRY WASH")
    ]),
    AreaDef(name: "Main Street", sub: "Quartzsite, in season · west to east along Main", w: 5420, arrive: 180, lat: 33.667, lon: -114.214, spots: [
        Spot(kind: .gemworld, x: 550, name: "GEM WORLD"),
        Spot(kind: .landmark, x: 760, name: "HI JOLLY MONUMENT", arg: 0),
        Spot(kind: .lot, x: 880, name: "USED RIGS"),
        Spot(kind: .shop, x: 1080, name: "BIG MARKET", arg: 0),
        Spot(kind: .rides, x: 1250, name: "RIDES FOR SALE"),
        Spot(kind: .shop, x: 1410, name: "Q VIEW RV PARK", arg: 1),
        Spot(kind: .camel, x: 1560, name: "CAMEL SCULPTURE", arg: 1),
        Spot(kind: .rvpark, x: 1760, name: "HOLIDAY PALMS RV PARK"),
        Spot(kind: .yacht, x: 1980, name: "QUARTZSITE YACHT CLUB"),
        Spot(kind: .pizza, x: 2140, name: "SILLY AL'S PIZZA"),
        Spot(kind: .post, x: 2300, name: "POST OFFICE"),
        Spot(kind: .shop, x: 2440, name: "HAPPY VALLEY PHARMACY", arg: 2),
        Spot(kind: .camel, x: 2580, name: "THE RED GHOST", arg: 0),
        Spot(kind: .parade, x: 2740, name: "PARADE ROUTE"),
        Spot(kind: .shop, x: 2890, name: "AUTO PARTS", arg: 3),
        Spot(kind: .grocery, x: 3030, name: "ROADRUNNER MARKET"),
        Spot(kind: .laundry, x: 3200, name: "MAIN STREET LAUNDROMAT"),
        Spot(kind: .computer, x: 3350, name: "THE COMPUTER CORNER"),
        Spot(kind: .board, x: 3490, name: "COMMUNITY BOARD"),
        Spot(kind: .hall, x: 3630, name: "TOWN HALL"),
        Spot(kind: .landmark, x: 3780, name: "CELIA'S RAINBOW GARDENS", arg: 4),
        Spot(kind: .park, x: 3940, name: "TOWN PARK"),
        Spot(kind: .dogpark, x: 4110, name: "QUARTZSITE DOG PARK"),
        Spot(kind: .shop, x: 4260, name: "COYOTE FRESH FOODS", arg: 4),
        Spot(kind: .shop, x: 4400, name: "PATTIE'S RV PARK & PROPANE", arg: 5),
        Spot(kind: .landmark, x: 4550, name: "READER'S OASIS", arg: 1),
        Spot(kind: .house, x: 4740, name: "HOUSE FOR SALE"),
        Spot(kind: .camel, x: 4910, name: "CAMEL SCULPTURE", arg: 2),
        Spot(kind: .camel, x: 5040, name: "CAMEL SCULPTURE", arg: 3),
        Spot(kind: .terribles, x: 150, name: "TERRIBLE'S"),
        Spot(kind: .carls, x: 345, name: "CARL'S JR."),
        Spot(kind: .solar, x: 5250, name: "SOLAR BILL'S")
    ]),
    AreaDef(name: "Tyson Wells", sub: "The show grounds on Kuehn Street", w: 3340, arrive: 160, lat: 33.6625, lon: -114.2215, spots: [
        Spot(kind: .tools, x: 380, name: "K&B TOOLS"),
        Spot(kind: .panorama, x: 700, name: "PROSPECTORS PANORAMA"),
        Spot(kind: .vendors, x: 1060, name: "SHOW VENDORS"),
        Spot(kind: .office, x: 1370, name: "SHOW OFFICE"),
        Spot(kind: .booth, x: 1580, name: "YOUR BOOTH", arg: 0),
        Spot(kind: .landmark, x: 1880, name: "TYSON'S WELL", arg: 2),
        Spot(kind: .camel, x: 2100, name: "CAMEL SCULPTURE", arg: 4),
        Spot(kind: .bigtent, x: 2400, name: "THE BIG TENT"),
        Spot(kind: .camel, x: 2760, name: "CAMEL SCULPTURE", arg: 5),
        Spot(kind: .pool, x: 3090, name: "RICE RANCH RV PARK"),
        Spot(kind: .beerbelly, x: 545, name: "BEER BELLY'S ADULT DAY CARE")
    ]),
    AreaDef(name: "Dome Rock", sub: "Free BLM camping west of town · 14-day limit", w: 4240, arrive: 2350, lat: 33.648, lon: -114.33, spots: [
        Spot(kind: .rockhound, x: 430, name: "ROCKHOUNDING"),
        Spot(kind: .mine, x: 820, name: "GOLD EYE MINE"),
        Spot(kind: .detect, x: 1220, name: "OLD PLACER DIGGINGS"),
        Spot(kind: .camp, x: 1620, name: "YOUR CAMP"),
        Spot(kind: .bench, x: 1760, name: "JEWELRY BENCH"),
        Spot(kind: .wash, x: 2080, name: "DRY WASH"),
        Spot(kind: .cleanup, x: 2380, name: "DESERT CLEANUP"),
        Spot(kind: .mine, x: 2960, name: "NUGGET MINE", arg: 1),
        Spot(kind: .cabin, x: 3300, name: "STONE CABIN"),
        Spot(kind: .detect, x: 3600, name: "NUGGET WASH"),
        Spot(kind: .rockhound, x: 3900, name: "OLD TAILINGS")
    ]),
    AreaDef(name: "Ehrenberg", sub: "Public land 10 miles west, toward the river", w: 2200, arrive: 1960, lat: 33.625, lon: -114.39, spots: [
        Spot(kind: .river, x: 260, name: "THE RIVER"),
        Spot(kind: .skoolie, x: 660, name: "SKOOLIEPALOOZA"),
        Spot(kind: .booth, x: 960, name: "YOUR SPOT", arg: 1),
        Spot(kind: .circle, x: 1260, name: "THE CIRCLE"),
        Spot(kind: .tour, x: 1480, name: "OPEN HOUSE"),
        Spot(kind: .landmark, x: 1700, name: "PIONEER CEMETERY", arg: 3)
    ]),
    AreaDef(name: "Pipeline Trail", sub: "Rough desert two-track east of La Posa", w: 2800, arrive: 160, lat: 33.636, lon: -114.183, spots: [
        Spot(kind: .cabin, x: 1050, name: "MINER'S CABIN"),
        Spot(kind: .rockhound, x: 1920, name: "QUARTZ WASH")
    ]),
    AreaDef(name: "Scaddan Wash", sub: "Free 14-day BLM camping east of town", w: 2200, arrive: 300, lat: 33.6493, lon: -114.1512, spots: [
        Spot(kind: .camp, x: 640, name: "DISPERSED CAMP"),
        Spot(kind: .stray, x: 1300, name: "BY THE WASH"),
        Spot(kind: .fire, x: 1080, name: "NOMAD FIRE"),
        Spot(kind: .rockhound, x: 1520, name: "WASH AGATES"),
        Spot(kind: .wash, x: 1900, name: "MESQUITE WASH"),
        Spot(kind: .cleanup, x: 300, name: "DESERT CLEANUP")
    ]),
    AreaDef(name: "Road Runner", sub: "Free BLM camping 5 miles south · 14-day limit", w: 2300, arrive: 2050, lat: 33.5807, lon: -114.2181, spots: [
        Spot(kind: .wash, x: 400, name: "DRY WASH"),
        Spot(kind: .cleanup, x: 160, name: "DESERT CLEANUP"),
        Spot(kind: .radio, x: 900, name: "QUARTZFEST"),
        Spot(kind: .camp, x: 1450, name: "YOUR CAMP"),
        Spot(kind: .bench, x: 1590, name: "JEWELRY BENCH")
    ]),
    AreaDef(name: "Hi Jolly", sub: "Free BLM camping 3 miles north · 14-day limit", w: 2200, arrive: 160, lat: 33.7097, lon: -114.2168, spots: [
        Spot(kind: .wash, x: 520, name: "DRY WASH"),
        Spot(kind: .fire, x: 880, name: "NEIGHBORS' FIRE"),
        Spot(kind: .camp, x: 1280, name: "YOUR CAMP"),
        Spot(kind: .cleanup, x: 1760, name: "DESERT CLEANUP")
    ]),
    AreaDef(name: "Plomosa Road", sub: "BLM camping 6 miles north under the Plomosa Mountains · 14-day limit", w: 2400, arrive: 160, lat: 33.749, lon: -114.216, spots: [
        Spot(kind: .wash, x: 460, name: "DRY WASH"),
        Spot(kind: .fire, x: 900, name: "NOMAD FIRE"),
        Spot(kind: .camp, x: 1380, name: "YOUR CAMP"),
        Spot(kind: .detect, x: 1900, name: "OLD PLACER GROUND")
    ]),
    AreaDef(name: "Crystal Hill", sub: "Kofa refuge, 12 miles southeast · quartz crystals in the hillside", w: 2000, arrive: 160, lat: 33.526, lon: -114.118, spots: [
        Spot(kind: .rockhound, x: 860, name: "CRYSTAL HILL"),
        Spot(kind: .camp, x: 1480, name: "KOFA CAMP")
    ]),
    AreaDef(name: "Palm Canyon", sub: "Kofa refuge, 25 miles south · native palms up a side canyon", w: 1700, arrive: 160, lat: 33.36, lon: -114.106, spots: [
        Spot(kind: .hike, x: 980, name: "PALM CANYON TRAIL")
    ]),
    AreaDef(name: "The Desert Bar", sub: "Near Parker, 40 miles north · open winter weekends, noon to sunset", w: 1800, arrive: 160, lat: 34.202, lon: -114.149, spots: [
        Spot(kind: .bar, x: 980, name: "THE DESERT BAR")
    ]),
    AreaDef(name: "Blythe Intaglios", sub: "Across the river, north of Blythe, California · giant figures in the desert floor", w: 1800, arrive: 160, lat: 33.8, lon: -114.532, spots: [
        Spot(kind: .hike, x: 960, name: "THE INTAGLIOS", arg: 1),
        Spot(kind: .hike, x: 1160, name: "LOOSE CABLE", arg: 2)
    ])
]
/// The same desert, a thousand years ago: what's there to see in each place, area by area.
let PAST_SPOTS: [[Spot]] = [
    [Spot(kind: .watch, x: 900, name: "PRONGHORN", arg: 0), Spot(kind: .watch, x: 1700, name: "SAGUARO FOREST", arg: 8)],
    [Spot(kind: .watch, x: 1200, name: "OLD FOOT TRAIL", arg: 11), Spot(kind: .watch, x: 2600, name: "QUAIL", arg: 7)],
    [Spot(kind: .watch, x: 1400, name: "MULE DEER", arg: 5)],
    [Spot(kind: .watch, x: 900, name: "BIGHORN", arg: 1)],
    [Spot(kind: .watch, x: 260, name: "BEAVER POND", arg: 4), Spot(kind: .village, x: 900, name: "RIVER VILLAGE"), Spot(kind: .watch, x: 1500, name: "TRACKS IN THE MUD", arg: 16)],
    [Spot(kind: .watch, x: 1200, name: "COYOTES", arg: 6)],
    [Spot(kind: .watch, x: 1000, name: "DESERT TORTOISE", arg: 3)],
    [Spot(kind: .watch, x: 900, name: "ROADRUNNER", arg: 12)],
    [Spot(kind: .watch, x: 1000, name: "CHUCKWALLA", arg: 13)],
    [Spot(kind: .watch, x: 1100, name: "GOLDEN EAGLE", arg: 14)],
    [Spot(kind: .watch, x: 900, name: "KIT FOX", arg: 15)],
    [Spot(kind: .watch, x: 400, name: "CONDOR", arg: 2), Spot(kind: .watch, x: 980, name: "FAN PALMS", arg: 10)],
    [Spot(kind: .watch, x: 900, name: "BIGHORN", arg: 1)],
    [Spot(kind: .watch, x: 960, name: "THE GREAT FIGURES", arg: 9)]
]
/// What you note down watching each thing, back in 1026.
let WILD: [(String, String)] = [
    ("pronghorn", "Pronghorn: the fastest runners in North America, racing across the flats"),
    ("bighorn", "Desert bighorn, picking their way along the ledges"),
    ("condor", "A California condor, wings nine feet across, riding the thermals"),
    ("desert tortoise", "A desert tortoise out on a warm winter afternoon"),
    ("beavers", "Beavers working the willows along the river"),
    ("mule deer", "Mule deer browsing at the edge of the mesquite"),
    ("coyotes", "A coyote family trotting down the wash"),
    ("quail", "A covey of Gambel's quail, topknots bobbing"),
    ("saguaro forest", "A forest of saguaros, some already a century and a half old"),
    ("the great figures", "The great figures, freshly scraped into the dark desert pavement"),
    ("fan palms", "Fan palms in the canyon, with a spring at their feet"),
    ("old foot trail", "A foot trail toward the river, broken buff pottery along its edge"),
    ("roadrunner", "A roadrunner sprinting after a lizard"),
    ("chuckwalla", "A chuckwalla sunning on a black rock, puffing up at you"),
    ("golden eagle", "A golden eagle on a snag, watching the whole valley"),
    ("kit fox", "A kit fox, all ears, at the mouth of its den"),
    ("the jaguar", "A jaguar, come down to the river at dusk to drink. It looks at you for a long moment, then goes on drinking")
]
/// The same places near the end of the last ice age, about 13,000 years ago: cooler and wetter, Joshua trees and creosote on the
/// valley floor, juniper and pinyon woodland on the hills, and no saguaros, ironwood or ocotillo yet.
let ICE_SPOTS: [[Spot]] = [
    [Spot(kind: .watch, x: 1300, name: "MAMMOTHS", arg: 100)],
    [Spot(kind: .watch, x: 1400, name: "JOSHUA TREES", arg: 101)],
    [Spot(kind: .watch, x: 1200, name: "WESTERN CAMELS", arg: 102)],
    [Spot(kind: .watch, x: 900, name: "GROUND SLOTH", arg: 103)],
    [Spot(kind: .watch, x: 1700, name: "THE BIG RIVER", arg: 104)],
    [Spot(kind: .watch, x: 1100, name: "DIRE WOLVES", arg: 105)],
    [Spot(kind: .watch, x: 1000, name: "WILD HORSES", arg: 106)],
    [Spot(kind: .watch, x: 900, name: "PACKRAT NEST", arg: 107)],
    [Spot(kind: .watch, x: 1000, name: "TERATORN", arg: 108)],
    [Spot(kind: .watch, x: 1100, name: "HUNTERS' CAMP", arg: 109)],
    [Spot(kind: .watch, x: 900, name: "JUNIPER WOODLAND", arg: 110)],
    [Spot(kind: .watch, x: 400, name: "PINYON CANYON", arg: 111)],
    [Spot(kind: .watch, x: 900, name: "SABERTOOTH", arg: 112)],
    [Spot(kind: .watch, x: 960, name: "BARE PAVEMENT", arg: 113)]
]
let DEEP_SPOTS: [[Spot]] = [
    [Spot(kind: .watch, x: 1300, name: "THE SHORE", arg: 200)],
    [Spot(kind: .watch, x: 1400, name: "GOMPHOTHERES", arg: 201)],
    [Spot(kind: .watch, x: 1300, name: "THREE-TOED HORSES", arg: 202)],
    [Spot(kind: .watch, x: 1300, name: "BONE-CRUSHING DOGS", arg: 203)],
    [Spot(kind: .watch, x: 1400, name: "THE TIDE FLATS", arg: 204)],
    [Spot(kind: .watch, x: 1100, name: "GIANT TORTOISE", arg: 205)],
    [Spot(kind: .watch, x: 1200, name: "GIANT CAMELS", arg: 206)],
    [Spot(kind: .watch, x: 1200, name: "SHOREBIRDS", arg: 207)],
    [Spot(kind: .watch, x: 1200, name: "SABERTOOTH", arg: 208)],
    [Spot(kind: .watch, x: 1200, name: "PALM GROVE", arg: 209)],
    [Spot(kind: .watch, x: 1200, name: "PRONGHORN", arg: 210)],
    [Spot(kind: .watch, x: 1100, name: "THE LAST RHINOS", arg: 211)],
    [Spot(kind: .watch, x: 1100, name: "GROUND SLOTH", arg: 212)],
    [Spot(kind: .watch, x: 1100, name: "FISH IN THE SHALLOWS", arg: 213)]
]
let WILD_DEEP: [(String, String)] = [
    ("the shore", "Water where the desert will be. A long arm of the Gulf, or a great lake, reaches up this valley, and the Colorado River has not cut its way down to it yet"),
    ("the gomphotheres", "Gomphotheres: four-tusked cousins of the elephant, browsing the trees"),
    ("three-toed horses", "Small three-toed horses, a whole herd, grazing where the grass is green"),
    ("bone-crushing dogs", "Heavy-jawed dogs built to crack bone, working over a carcass"),
    ("the tide flats", "Mud flats that flood and drain. Barnacles on the rocks, this far from any sea you know"),
    ("a giant tortoise", "A tortoise the size of a boulder, in no hurry at all"),
    ("giant camels", "Camels taller than any you will see at Hi Jolly's tomb. They started out here, in North America"),
    ("the shorebirds", "Wading birds by the hundred, working the shallows"),
    ("a sabertooth", "A big sabertooth cat on a rock above the water, watching the horses"),
    ("the palm grove", "Fan palms in a thick grove. It is warmer and much wetter than the desert you left"),
    ("the pronghorn", "Pronghorn, with horns in shapes that will not last: forked, spiralled, four at a time"),
    ("the last rhinos", "Short-legged, barrel-bodied rhinos wallowing at the water's edge, near the end of their time on this continent"),
    ("a ground sloth", "A small ground sloth, new to this continent, pulling down branches"),
    ("fish in the shallows", "Schools of fish flashing in clear warm water over a sand bottom")
]
let WILD_ICE: [(String, String)] = [
    ("the mammoths", "Columbian mammoths, a family of them, pulling up grass along the wash"),
    ("the Joshua trees", "Joshua trees and creosote where saguaros will stand one day. The saguaros have not arrived yet"),
    ("the camels", "Western camels. Camels began in North America; these are the last of them"),
    ("the ground sloth", "A Shasta ground sloth, big as a bear, stripping a Joshua tree"),
    ("the river", "The Colorado running high and cold with meltwater from the Rockies"),
    ("the dire wolves", "Dire wolves, heavier than any wolf alive now, watching you from the rise"),
    ("the horses", "Wild horses. They will die out here, and come back with the Spanish twelve thousand years on"),
    ("the packrat nest", "A packrat's nest of twigs and juniper berries. In 13,000 years, nests like this are how scientists will know what grew here"),
    ("the teratorn", "A teratorn, twelve feet from wingtip to wingtip, circling"),
    ("the hunters' camp", "A small band camped by the wash: a fire, stone points being worked, children. Among the first people in this country"),
    ("the woodland", "Juniper and pinyon pine across hills that will be bare rock in your time"),
    ("the canyon", "Pinyon pines and oaks in the canyon, in the cool and the shade"),
    ("the sabertooth", "A sabertooth cat on a ledge, in no hurry at all"),
    ("the pavement", "Bare desert pavement. The giant figures are twelve thousand years in the future")
]
func wildOf(_ arg: Int) -> (String, String) { return arg >= 200 ? WILD_DEEP[arg - 200] : (arg >= 100 ? WILD_ICE[arg - 100] : WILD[arg]) }
/// Places and moments you can look around from the title screen.
let PREVIEWS: [(String, String)] = [
    ("La Posa South camp", "ltva"), ("Camp at night", "night"), ("Camp party", "party"),
    ("Main Street", "main"), ("Main Street west", "mainwest"), ("Main Street east", "maineast"),
    ("Main Street at night", "mainnight"), ("Gem World", "gemfront"), ("Tyson Wells gem show", "gem"),
    ("RV show", "rvshow"), ("Dome Rock", "dome"), ("Inside the mine", "minein"),
    ("Ehrenberg: Skooliepalooza", "skoolie"), ("Pipeline Trail", "trail"), ("Scaddan Wash", "scaddan"),
    ("Road Runner: Quartzfest", "qfest"), ("Hi Jolly", "hijolly"), ("Plomosa Road", "plomosa"),
    ("Crystal Hill", "crystal"), ("Palm Canyon", "palms"), ("The Desert Bar", "desertbar"),
    ("Blythe Intaglios", "intaglios"), ("1026: the desert", "past"), ("1026: river village", "pastriver"),
    ("Ice age: mammoths", "ice"), ("Ice age: hunters' camp", "icecamp"), ("Rock labyrinth", "labyrinth")
]
let LANDMARKS = ["Pay respects at Hi Jolly's tomb", "Browse the books", "Read the stage-stop plaque", "Walk the old cemetery", "Walk Celia's Rainbow Gardens"]
let CAMELS = 6
/// The people camped around you. Short name, who they are.
let NEIGHBORS: [(String, String)] = [
    ("Marge & Hal", "snowbirds from Minnesota, 22nd winter"),
    ("Dusty", "full-timer in a '78 Airstream"),
    ("Tess", "travels with three rescue dogs"),
    ("Ray", "retired lineman, fixes anything solar"),
    ("The Okafors", "first winter in their skoolie"),
    ("Bev", "paints rocks and leaves them on trails"),
    ("Juan", "sells tamales from his van on weekends"),
    ("Gloria", "has been coming since 1979")
]
/// Odd jobs pinned to the bulletin board: one a day, a new one each morning.
let JOBS: [(String, Int)] = [("Wash a Class A", 40), ("Help set up a vendor tent", 30), ("Haul water for a neighbor", 20), ("Fix a flat on a fifth wheel", 35), ("Dog-sit for the day", 25), ("Install a neighbor's solar panel", 50), ("Unload a rock dealer's trailer", 45)]
/// Traffic on the highway: a car, then rigs. Lengths match the drawings.
let CAR_LEN: [Double] = [46, 59, 63, 87, 118, 96]

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
/// Something on a vendor's table at the gem show. Worth is what it should fetch from a booth.
struct Ware {
    let name: String
    let who: String
    var price: Int
    let lo: Int
    let hi: Int
    var sold: Bool
    var haggled = false
}
let WARE_NAMES = ["Amethyst cluster", "Fire agate slab", "Quartz point", "Geode pair", "Petrified wood round", "Chrysocolla nugget", "Turquoise nugget", "Desert rose", "Jasper slab", "Opal chip"]
let WARE_WORTH = [60, 90, 24, 40, 55, 45, 70, 20, 30, 80]
/// Who sells it, and how their prices run against what things are worth (percent).
let SELLERS: [(String, Int, Int)] = [("Retired rockhound from Oregon", 65, 80), ("Nomad couple selling off a van", 40, 110), ("Skoolie kids with a tumbler", 45, 70), ("Snowbird lapidary club", 85, 100)]

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
    var rockVals: [Int]
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
    var jewelVals: [Int]
    var detector: Bool
    var campDays: Int
    var age: Int
    var year: Int
    var resident: Bool
    var house: Bool
    var upgrades: [Int]
    var followers: Int
    var camels: [Int]
    var hasDog: Bool
    var dogCholla: Bool
    var weather: Int
    var afterRain: Int
    var tanks: Double?
    var propane: Double?
    var stats: [Int]?
    var notes: [Int]?
    var era: Int?
    var sStart: Int?
    var best: Int?
    var began: Double?
    var seen: [Int]?
    var dug: [String: Int]?
    var boothDay: Int?
    var mailDay: Int?
    var magic: Bool?
    var stripe: Int?
    var flag: Int?
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
    var spots: [Spot] { return deep ? DEEP_SPOTS[area.rawValue] : iceAge ? ICE_SPOTS[area.rawValue] : (inPast ? PAST_SPOTS[area.rawValue] : AREAS[area.rawValue].spots) }
    var iceAge: Bool { return era == 2 }
    var deep: Bool { return era == 3 }
    var notesHere: Int { return fieldNotes.filter { deep ? $0 >= 200 : (iceAge ? ($0 >= 100 && $0 < 200) : $0 < 100) }.count }
    var notesTotal: Int { return (iceAge || deep) ? 14 : 18 }
    var foundMagic = false
    var stripe = 0, flag = 0, customOpen = false
    var mapQuad = -1
    var moneySeen = -1.0, coinPopT = 0.0, coinPopN = 0
    var alsOpen = false
    // a thousand years back: same land, no roads, no rigs
    var era = 0
    var inPast: Bool { return era >= 1 }
    var fieldNotes: Set<Int> = []
    var flashT = 0.0
    var credSeen = -1, credPopT = 0.0, credPopN = 0
    // the contest score: cred earned in one season, so a late start or a long life is no advantage
    var seasonStartCred = 0
    var bestSeason = 0
    var seasonBegan = 0.0
    var rulesOpen = false
    var mapBig = false
    // looking around: any place, any event, without touching the saved game or the contest score
    var previewing = false
    var previewOpen = false
    private var previewStash: SaveData?
    var seasonCred: Int { return max(0, cred - seasonStartCred) }
    var plantShow = false   // demo only: a lineup of the desert plants
    var rigHere: Bool { return !inPast && rigArea == area }
    var toyHere: Bool { return !inPast && toyArea == area }

    /// Step through: your rig and rides stay in 2026; you go on foot.
    func timeTravel(_ target: Int) {
        refund()
        era = target
        inRig = false; onToy = false; vx = 0
        mapOpen = false
        flashT = 1.2
        arriveT = 4.5
        events.append(7)
        hintT = 0
        if era == 1 { hint("past", "Winter, 1026. No roads, no rigs, saguaros everywhere. Watch the animals for your field notes (each new one is +1 cred), and visit the river village at Ehrenberg: there is something to do there every day.") }
        if era == 2 { hint("ice", "About 13,000 years ago, at the end of the last ice age. Cooler and wetter: Joshua trees on the flats, juniper on the hills, no saguaros yet. Mammoths, camels, horses and ground sloths live here. Each new sighting is +1 cred.") }
        if era == 3 { hint("deep", "About five million years ago. Water fills the valley toward Blythe, the Colorado River is only just arriving, and the country is warm, green and wet. No people anywhere. Each new sighting is +1 cred.") }
    }
    var WORLD: Double { return AREAS[area.rawValue].w }

    // the day
    var px = 1260.0
    var vx = 0.0
    var face = 1.0
    var walk = 0.0
    var cam = 0.0
    /// Where you last pointed: you walk, ride or drive there on your own.
    var moveTarget: Double? = nil
    func pointTo(_ gx: Double) { moveTarget = clampD(cam + gx / ZOOM, 30, WORLD - 30) }
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
    /// What each stone or pendant in your pack should fetch from a booth.
    var rockVals: [Int] = []
    var jewelVals: [Int] = []
    var rocks: Int { return rockVals.count }
    var jewelry: Int { return jewelVals.count }
    var odd = 0
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

    // a life: one winter season a year until the end
    var age = 61
    var year = 1
    var resident = false
    var house = false
    var upgrades: Set<Int> = []
    var packCap: Int { return upgrades.contains(UP_RACK) ? 8 : 5 }
    var muted = false
    /// People following your Facebook page. It starts paying at 1,000.
    var followers = 0
    /// Camel sculptures you've photographed on the self-guided tour.
    var camels: Set<Int> = []
    var hasDog = false
    var dogCholla = false
    /// 0 clear, 1 windy with dust, 2 cloudy, 3 rain. Washes run on rain days; rockhounding is best the two days after.
    var weather = 0
    var afterRain = 0
    var seasonCard = false
    /// This season so far: starting coins, followers and cred, then miles, sales, finds, events and parties.
    var stats = [150, 0, 0, 0, 0, 0, 0, 0]
    var ended = false
    var endTitle = ""
    var endText = ""

    // the gem show up close
    var browseOpen = false
    var wares: [Ware] = []
    var shop = 0                          // 0 the show tables at Tyson Wells, 1 Gem World
    var stock: [Int: (Int, [Ware])] = [:] // each shop's stock for the day
    var dug: [String: Int] = [:]          // finds taken today, by place
    var mailDay = -6                      // the last General Delivery pickup
    // camp manners: dust from riding fast, a generator running into quiet hours
    var dustAmt = 0.0, speedT = 0.0, dustCool = 0.0
    var madT = 0.0, madX = 0.0, madText = ""
    var genOn = false, genMadDay = -1
    // living in a rig: the tanks fill up and the propane runs down
    var tanks = 100.0, propane = 100.0
    var popFreeze = false
    var zooShow = false
    var clockFreeze = false               // screenshots only

    /// The clock: 7 AM at first light (0), 6 PM at dusk (0.66), and 7 AM again at 1.
    func hour() -> Double {
        return dayT < 0.66 ? 7 + dayT / 0.66 * 11 : (18 + (dayT - 0.66) / 0.34 * 13).truncatingRemainder(dividingBy: 24)
    }
    func clockText() -> String {
        let h = hour(), hh = Int(h), mm = Int((h - Double(hh)) * 60) / 10 * 10
        return "\(hh % 12 == 0 ? 12 : hh % 12):" + String(format: "%02d", mm) + (hh < 12 ? " AM" : " PM")
    }
    /// Quiet hours: 10 PM to 6 AM.
    var quietHours: Bool { let h = hour(); return h >= 22 || h < 6 }
    var waresDay = -1

    // cinematics: a list of shots, four seconds each, with a caption for each
    var cineShots: [Int] = []
    var cineCaps: [String] = []
    var cineT = 0.0
    var inCine: Bool { return !cineShots.isEmpty }
    var cineFreeze = false
    // the drive between places: a side-on run down the highway (or the trail)
    struct Car { var x: Double; var lane: Int; var kind: Int; var v: Double }
    var driving = false
    var driveTo: Area = .ltva
    var driveMiles = 0.0, driveLeft = 0.0, driveSecs = 10.0
    var driveLane = 1, driveLaneY = 1.0, driveSpeed = 0.0, driveScroll = 0.0
    var driveCars: [Car] = []
    var driveNext = 2.0, driveBump = 0.0, driveLen = 60.0
    var driveVeh = 0, driveDirt = false, driveFreeze = false, driveTow = false
    // a party at your camp: the neighbors stay till late
    var partyDay = -1, partyArea: Area = .ltva, partyX = 0.0, partyT = 0.0
    // something on the shoulder worth pulling over for: 0 a broken-down van, 1 a free pile
    var stopX = -999.0, stopKind = 0, stopDone = false, stopMsg = "", stopMsgT = 0.0
    let SHOT = 4.2

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
    /// A full-screen card is up and the day stands still.
    var overlay: Bool { return mapOpen || browseOpen || seasonCard || ended || inCine || driving || phoneOpen || tourOpen || mineOpen || boardOpen || alsOpen || customOpen }
    var tourOpen = false, tourBus = 0
    var boardOpen = false
    var petT = -99.0                      // when you last petted the dog
    var petDay = -1

    /// 0 Sunday ... 6 Saturday.
    var weekday: Int { return (START_WEEKDAY + day - 1) % 7 }
    /// The Desert Bar keeps winter weekend hours, noon to sunset.
    var barOpen: Bool { return (weekday == 0 || weekday == 6) && hour() >= 12 && hour() < 18 }

    /// The next event on the calendar, for the board.
    func nextEvent() -> EventDef? {
        return EVENTS.enumerated().filter { $0.offset != EV_PAN && $0.element.start > day }.min(by: { $0.element.start < $1.element.start })?.element
    }
    var mineOpen = false, mineFind = 0, mineText = ""   // inside the Gold Eye: 0 specimen, 1 lantern, 2 gold, 3 bats
    // your page, on your phone
    struct PagePost { var text: String; var day: Int; var likes: Int; var comments: Int }
    var phoneOpen = false
    var tomorrow = 0                      // the forecast for tomorrow

    /// New Year's Eve: fireworks over town from 11:30 to 12:30.
    var fireworks: Bool { return phase == .play && day == 4 && dayT > 0.8 && dayT < 0.835 }
    /// Holiday lights stay up through Three Kings Day, January 6.
    var holidays: Bool { return day <= 10 }

    /// Who's around today: the same faces, rotating through the week.
    func neighbor(_ salt: Int) -> (String, String) {
        return NEIGHBORS[(day + salt * 3 + area.rawValue * 5) % NEIGHBORS.count]
    }
    var phoneTab = 0                      // 0 your page, 1 goals

    /// Things worth doing in a Quartzsite life, checked off as you go.
    func goals() -> [(String, Bool)] {
        return [
            ("Start your page at the Computer Corner", page),
            ("Reach 1,000 followers and get paid", followers >= 1000),
            ("Sell at a show booth", stats[4] > 0),
            ("Throw a party for the neighbors", stats[7] > 0 || partyDay >= 0),
            ("Visit all \(CAMELS) camel sculptures", camels.count >= CAMELS),
            ("Put solar on your rig", panels > 0),
            ("Trade up to a bigger rig", rig.rawValue > START_RIGS[min(pickRig, START_RIGS.count - 1)].rawValue),
            ("Start a business at Town Hall", business > 0),
            ("Adopt a dog from the dog park", hasDog),
            ("Go back in time and fill 10 field notes", fieldNotes.count >= 10),
            ("Save 5,000 coins", money >= 5000),
            ("Get a year-round RV site or a house", resident || house)
        ]
    }

    /// Highs and lows for the day: mild winter days, cold nights, warming into March.
    func temps(_ w: Int, _ d: Int) -> (Int, Int) {
        let base = d < 35 ? (66, 40) : (d < 63 ? (70, 43) : (77, 50))
        let adj = w == 3 ? -7 : (w == 2 ? -3 : (w == 1 ? -1 : 0))
        return (base.0 + adj, base.1 + (w >= 2 ? 4 : 0))
    }
    func weatherName(_ w: Int) -> String { return ["Sunny", "Windy", "Cloudy", "Rain"][max(0, min(3, w))] }
    var openURL: String? = nil            // the app opens this (feedback email)

    /// A morning visit: most days a neighbor wanders over with coffee.
    var neighborVisit: Bool {
        return phase == .play && rigHere && dayT > 0.02 && dayT < 0.25 && !seen.contains(27) && hashN(Double(day) * 3.7 + 0.2) < 0.6
    }

    /// An email to the developer, with the build and where you are filled in.
    func feedback() {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let body = "Build \(build) · \(dateText(day)) · \(areaName(area))\n\nWhat happened, or what's not right about Quartzsite:\n\n"
        let enc = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        openURL = "mailto:bward916@gmail.com?subject=Quartzsite%20Winter%20beta%20feedback&body=" + enc
        events.append(3)
    }
    var posts: [PagePost] = []
    var pagePay = 0                       // what the page paid this morning

    /// What's going on right where you stand, for a photo.
    func photoSubject() -> (String, Int) {
        let ev: Int? = area == .tyson ? tysonShow() : (area == .skoolie && on(EV_SKOOL) ? EV_SKOOL : (area == .roadrunner && on(EV_QFEST) ? EV_QFEST : (area == .main ? [EV_PARADE, EV_RTR, EV_WESTERN].first(where: { on($0) }) : nil)))
        if let e = ev { return ("at the " + EVENTS[e].name, 40) }
        if let sp = spots.first(where: { ($0.kind == .landmark || $0.kind == .camel || $0.kind == .panorama) && abs($0.x - px) < 120 }) { return ("at " + sp.name.capitalized, 25) }
        if partyDay == day && partyArea == area && dayT > 0.5 { return ("from our party at camp", 30) }
        if dayT > 0.73 && dayT < 0.95 { return ("of the stars over " + areaName(area), 18) }
        if dayT > 0.6 && dayT <= 0.73 { return ("of the sunset at " + areaName(area), 22) }
        return ("from " + areaName(area), 8)
    }
    func postPhoto() {
        if inPast { float("No signal for another thousand years", px, CREAM); return }
        if seen.contains(26) { return }
        seen.insert(26)
        let s = photoSubject()
        post("a photo " + s.0, s.1)
        events.append(1)
    }
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
            if rulesOpen {
                if id == 84 { events.append(10) } else { rulesOpen = false }
                events.append(3)
                return
            }
            if previewOpen {
                if id >= 200 && id < 200 + PREVIEWS.count { startPreview(id - 200) } else { previewOpen = false }
                events.append(3)
                return
            }
            if id == 83 { rulesOpen = true; events.append(3); return }
            if id == 88 { previewOpen = true; events.append(3); return }
            if id == 69 { feedback(); return }
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
            if previewing && id == 86 { endPreview(); events.append(3); return }
            if inCine {
                // a tap skips ahead to the last shot, a second tap ends it
                if cineT < Double(cineShots.count - 1) * SHOT { cineT = Double(cineShots.count - 1) * SHOT } else { cineShots = [] }
                return
            }
            if driving {
                if id == 65 { driveLeft = 0; driving = false; shown.insert("drive"); events.append(3); return }
                if id == 66 && !stopDone { pullOver(); return }
                if driveDirt { return }
                let lane = y < GY ? 0 : 1
                if lane != driveLane { driveLane = lane; events.append(3) }
                return
            }
            if ended {
                if id == 82 { hasSave = false; ended = false; phase = .pick }
                return
            }
            if seasonCard {
                if id == 80 { newSeason(stay: false) }
                if id == 81 && (resident || house) { newSeason(stay: true) }
                events.append(3)
                return
            }
            if customOpen {
                if id >= 310 && id < 318 { stripe = id - 310 } else if id >= 320 && id < 327 { flag = id - 320 } else if id != 62 { customOpen = false }
                events.append(3)
                return
            }
            if alsOpen {
                if id == 58 { playPool() } else if id >= 340 && id < 343 { orderAl(id - 340) } else if id != 62 { alsOpen = false }
                events.append(3)
                return
            }
            if tourOpen { tourOpen = false; events.append(3); return }
            if mineOpen { mineOpen = false; events.append(3); return }
            if boardOpen { boardOpen = false; events.append(3); return }
            if phoneOpen {
                if id == 68 { postPhoto() }
                else if id == 72 { phoneTab = 0; events.append(3) }
                else if id == 73 { phoneTab = 1; events.append(3) }
                else { phoneOpen = false; events.append(3) }
                return
            }
            if browseOpen {
                if id >= 100 && id < 100 + wares.count { haggle(id - 100) }
                else if id >= 90 && id < 90 + wares.count { buyWare(id - 90) } else if id == 89 || id < 0 { browseOpen = false }
                events.append(3)
                return
            }
            if mapOpen {
                #if DEBUG
                if id == 64 { testWeek(); return }
                #endif
                if id == 85 { timeTravel(era == 1 ? 0 : 1); return }
                if id == 57 { timeTravel(era == 2 ? 0 : 2); return }
                if id == 305 { timeTravel(era == 3 ? 0 : 3); return }
                if id >= 300 && id < 304 { mapQuad = id - 300; events.append(3); return }
                if id == 304 && !inPast {
                    mapQuad = -1
                    if area != .dome { go(.dome) }
                    if area == .dome && !inRig {
                        mapOpen = false
                        px = 2720
                        if onToy { toyX = px }
                    }
                    hint("nugget", "Gold Nugget Road runs east from Dome Rock, past the cleanup: mines, a stone cabin, a wash to detect")
                    events.append(3)
                    return
                }
                if id == 55 { mapQuad = -1; events.append(3); return }
                if id == 54 { backToCamp(); events.append(3); return }
                if id >= 70 && id < 70 + AREAS.count { mapQuad = -1; go(Area(rawValue: id - 70) ?? area) } else if id == 61 || id < 0 { mapOpen = false }
                events.append(3)
                return
            }
            if id == 56 && !inPast { refund(); alsOpen = true; events.append(3); return }
            if id == 59 && rigHere && !inRig { refund(); customOpen = true; events.append(3); return }
            if id == 50 { shown.insert("rigUsed"); toggleRig() }
            if id == 51 { shown.insert("toyUsed"); toggleToy() }
            if id == 53, let b = spots.firstIndex(where: { $0.kind == .board && abs($0.x - px) < 60 }) {
                _ = b
                refund(); shown.insert("boardUsed"); boardOpen = true; events.append(3)
                return
            }
            if id == 60 { openMap() }
            if id == 52 { openBrowse() }
            if id == 63 { muted = !muted }
            if id == 69 { refund(); feedback(); return }
            if id == 76 && hasDog {
                petT = time
                events.append(5)
                if petDay != day {
                    petDay = day
                    health = min(100, health + 4)
                    float(dogCholla ? "Careful. Comb that cholla out at camp" : ["Good dog.", "Best dog in Quartzsite.", "Who's a good dog?"][day % 3], px, CREAM)
                }
                return
            }
            if id == 67 { refund(); phoneOpen = true; events.append(3); hint("phone", "Your page. Post one photo a day from wherever you are: events, landmarks, sunsets and starry nights reach the most people.") }
        }
    }

    func begin() {
        rig = START_RIGS[pickRig]
        money = START_CASH[pickRig] + (life == .rver ? 100 : 0)
        cred = life == .nomad ? 5 : 0
        seasonStartCred = cred; seasonBegan = Date().timeIntervalSince1970
        stats = [Int(money), 0, cred, 0, 0, 0, 0, 0]
        health = 100; day = 1; dayT = 0.12
        wood = 0; rockVals = []; odd = 0; jewelVals = []; panels = 0
        area = .ltva; rigArea = .ltva
        px = 1260; rigX = 1150; rigFace = 1; inRig = false; vx = 0
        // your first ride: nomads pedal, snowbirds bring the side-by-side
        toy = life == .nomad ? 0 : 5; toyArea = .ltva; toyX = 1215; onToy = false
        detector = false; permitDays = 14; campDays = 0; business = 0; adDays = 0; page = false; seen = []; boothDay = 0
        active = -1; ringSpot = -1; ringProg = 0; ringPaid = 0
        mapOpen = false
        browseOpen = false; seasonCard = false; ended = false
        age = life == .nomad ? 31 : 61
        year = 1; resident = false; house = false; upgrades = []; followers = 0; camels = []; hasDog = false; dogCholla = false; weather = 0; afterRain = 0
        shown = []
        floaters = []
        phase = .play
        arriveT = 4.5
        cineShots = [0, 1, 2, 3]
        cineCaps = ["I-10, Arizona. Exit 17.", "Every winter, the desert fills up.", "Snowbirds, nomads, skoolies and rockhounds.", "Your first winter · " + dateText(1)]
        cineT = 0
        hint("start", "Tap anywhere to walk there. Stand by a glowing spot and hold the HOLD button to fill its ring. Let go early and your money comes back. Tap your " + (life == .nomad ? "bike" : "side-by-side") + " to ride; it's much faster than walking. Tap MAP to go somewhere else.")
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

    /// Something worth sharing. With a page, it brings followers (twice as many with Starlink).
    func post(_ what: String, _ reach: Int) {
        if !page { return }
        let n = reach * (upgrades.contains(UP_STARLINK) ? 2 : 1) + cred / 4
        let before = followers
        followers += n
        posts.insert(PagePost(text: what, day: day, likes: n * 3 + Int.random(in: 0...12) + followers / 80, comments: n / 3 + Int.random(in: 0...4)), at: 0)
        if posts.count > 12 { posts.removeLast() }
        float("Posted: " + what + "  +\(n) followers", px, Col(0x8ab4f8))
        if before < 1000 && followers >= 1000 {
            hintT = 0
            hint("monetize", "1,000 followers. Your page is monetized now and pays every morning.")
        }
    }
    func followersText() -> String {
        return followers >= 1000 ? String(format: "%.1fk", Double(followers) / 1000) : "\(followers)"
    }

    /// How far the ground rises above the road line at x (negative is up). Only Pipeline Trail is rough,
    /// and it flattens out around the places you stop.
    func ground(_ x: Double) -> Double {
        if area != .trail { return 0 }
        var flat = 1.0
        for sp in spots { flat = min(flat, clampD((abs(x - sp.x) - 40) / 60, 0, 1)) }
        if x < 260 { flat = min(flat, clampD((x - 160) / 100, 0, 1)) }
        let h = 5 + 4 * sin(x * 0.021) + 2.5 * sin(x * 0.057 + 1.3)
        return -max(0, h) * flat
    }
    func slope(_ x: Double) -> Double { return atan((ground(x + 4) - ground(x - 4)) / 8) }

    /// Where the burro herd is grazing right now, in world pixels (the drawing uses the same).
    func herdX() -> Double { return (time * 4 + 340).truncatingRemainder(dividingBy: WORLD + 400) - 200 + 39 }

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
        if inPast { return Trip(ok: true, cost: 0, how: "Walk the old trails") }
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
        if [.crystal, .palms, .desertbar, .intaglios].contains(to) { return Trip(ok: false, cost: 0, how: "\(Int(mi)) miles out. You need wheels") }
        if area == .skoolie { return Trip(ok: true, cost: 0, how: "Ride back with a nomad family") }
        return Trip(ok: true, cost: 2, how: "Camel Express dial-a-ride")
    }

    /// For testing: jump a week ahead to reach the January events quickly. Remove before release.
    private func testWeek() {
        for _ in 0..<7 where !seasonCard { dawn() }
        mapMsg = "Test: skipped to " + dateText(day)
        mapMsgT = 2.5
        if seasonCard { mapOpen = false }
    }

    /// A game of eight-ball in the back room at Silly Al's. Once a day; half the time you win the table.
    private func orderAl(_ k: Int) {
        let cost = [10, 8, 5][k]
        if seen.contains(47 + k) { mapMsg = ["One pie is plenty for today", "You've had your greens", "One beer. You're driving"][k]; mapMsgT = 2.5; return }
        if money < Double(cost) { mapMsg = "That's \(cost) coins"; mapMsgT = 2.5; return }
        seen.insert(47 + k)
        money -= Double(cost)
        events.append(6)
        if k == 0 {
            health = min(100, health + 26)
            if !seen.contains(24) { seen.insert(24); cred += 1; post("pizza at Silly Al's", 15) }
            mapMsg = "Best pizza in town, hot out of the oven"
        } else if k == 1 {
            health = min(100, health + 20)
            mapMsg = "A big salad. You feel virtuous"
        } else {
            health = min(100, health + 6)
            mapMsg = "A cold one at the bar. The regulars nod"
        }
        mapMsgT = 3
    }
    private func playPool() {
        if seen.contains(42) { mapMsg = "One game a day. The table's taken"; mapMsgT = 2.5; return }
        if money < 5 { mapMsg = "A game is 5 coins"; mapMsgT = 2.5; return }
        seen.insert(42)
        money -= 5
        if Double.random(in: 0..<1) < 0.5 {
            money += 17; cred += 1
            mapMsg = "You ran the table. 12 coins up, and the regulars noticed"
            events.append(5)
        } else {
            mapMsg = "Scratched on the eight. Good game anyway"
        }
        mapMsgT = 3.5
    }

    /// Straight home: to the place your rig is parked, and to its door.
    private func backToCamp() {
        if inPast || inRig { return }
        if rigArea != area {
            go(rigArea)
            if area != rigArea { return }
        } else {
            mapOpen = false
        }
        if !onToy { px = clampD(rigX - 40, 30, WORLD - 30) } else { px = clampD(rigX - 70, 30, WORLD - 30); toyX = px }
        cam = clampD(px - W / ZOOM / 2, 0, max(0, WORLD - W / ZOOM))
    }

    private func go(_ to: Area) {
        let t = trip(to)
        if !t.ok { mapMsg = t.how; mapMsgT = 2.5; return }
        if Double(t.cost) > money { mapMsg = "Not enough coins for that"; mapMsgT = 2.5; return }
        money -= Double(t.cost)
        mapOpen = false
        let mi = milesBetween(area, to)
        stats[3] += Int(mi.rounded())
        let hiking = inPast || (!inRig && !onToy && (to == .trail || area == .trail))
        let veh = inRig ? 0 : (onToy ? 1 : (area == .skoolie ? 3 : 2))
        let dirt = to == .trail || area == .trail
        travel(to)
        if mi >= 1 && !hiking { startDrive(to, mi, veh, dirt) }
    }

    /// The trip itself: you are already there as far as the save knows; this is the ride.
    func startDrive(_ to: Area, _ mi: Double, _ veh: Int, _ dirt: Bool) {
        driving = true; driveTo = to; driveMiles = mi; driveLeft = mi
        driveVeh = veh; driveDirt = dirt
        var spd = 150.0
        if veh == 0 { spd = RIGS[rig.rawValue].speed; driveLen = RIGS[rig.rawValue].len }
        else if veh == 1 { spd = TOYS[max(0, toy)].speed; driveLen = TOYS[max(0, toy)].len }
        else { driveLen = veh == 3 ? RIGS[RigKind.skoolie.rawValue].len : RIGS[RigKind.minivan.rawValue].len }
        driveSecs = clampD(mi * 2.2 * 150 / max(60, spd), 6, 24)
        driveTow = veh == 0 && toy >= 0 && toyArea == to
        if driveTow && toy >= 3 { driveLen += 44 }
        driveLane = 1; driveLaneY = 1; driveSpeed = 0.25; driveScroll = 0
        driveCars = []; driveNext = 1.2; driveBump = 0
        stopX = -999; stopDone = false; stopMsgT = 0
        stopKind = Double.random(in: 0..<1) < 0.5 ? 0 : 1
        if dirt || seen.contains(33) || Double.random(in: 0..<1) > 0.6 { stopDone = true }
    }

    /// Pull over for whatever is on the shoulder.
    private func pullOver() {
        stopDone = true
        seen.insert(33)
        driveSpeed = 0.08
        if stopKind == 1 && odd >= 3 { stopKind = 0 }
        if stopKind == 0 {
            cred += 2
            stopMsg = "You helped a stranded van get going.  +2 cred"
            post("helping a stranded van on the highway", 6)
        } else {
            odd += 1
            stopMsg = "A FREE sign and a box of oddities.  +1 oddity"
        }
        stopMsgT = 2.6
        events.append(1)
    }

    /// Where a lane's wheels sit on the screen.
    func laneBase(_ l: Double) -> Double { return GY - 9 + l * 18 }

    private func driveStep(_ dt: Double) {
        if driveFreeze { return }
        if driveBump > 0 { driveBump -= dt }
        driveSpeed += ((driveBump > 0 ? 0.3 : 1) - driveSpeed) * min(1, dt * 1.1)
        driveLaneY += (Double(driveLane) - driveLaneY) * min(1, dt * 7)
        let v = 240 * driveSpeed
        driveScroll += v * dt
        driveLeft -= dt * driveMiles / driveSecs * driveSpeed
        if !driveDirt {
            driveNext -= dt
            if driveNext <= 0 && driveLeft > driveMiles * 0.12 {
                driveNext = rnd(1.3, 3)
                driveCars.append(Car(x: W + 100, lane: Int.random(in: 0...1), kind: Int.random(in: 0..<6), v: rnd(0.3, 0.6) * 240))
            }
        }
        if stopMsgT > 0 { stopMsgT -= dt }
        if !stopDone {
            if stopX < -900 && driveLeft < driveMiles * 0.6 { stopX = W + 70 }
            if stopX > -900 { stopX -= v * dt; if stopX < -80 { stopDone = true } }
        }
        let me = W * 0.3
        var i = 0
        while i < driveCars.count {
            driveCars[i].x -= (v - driveCars[i].v) * dt
            let car = driveCars[i]
            if car.x < -160 || car.x > W + 400 { driveCars.remove(at: i); continue }
            let reach = (driveLen + CAR_LEN[car.kind]) / 2 + 1
            if driveBump <= 0 && car.lane == driveLane && abs(driveLaneY - Double(driveLane)) < 0.4 && car.x > me && car.x - me < reach {
                driveBump = 1.3
                driveSpeed = 0.15
                health = max(0, health - 3)
                events.append(6)
            }
            i += 1
        }
        if driveLeft <= 0 {
            driveLeft = 0
            driving = false
            shown.insert("drive")
        }
    }

    private func travel(_ to: Area) {
        let from = area
        area = to
        px = AREAS[to.rawValue].arrive
        vx = 0
        if inRig { rigArea = to; rigX = px; rigFace = px < WORLD / 2 ? 1 : -1 }
        if onToy { toyArea = to; toyX = px }
        // your ride comes along with the rig: bikes on the rack, the rest on a trailer
        if inRig && toy >= 0 && toyArea == from {
            toyArea = to
            toyX = clampD(px - rigFace * (RIGS[rig.rawValue].len / 2 + 34), 40, WORLD - 40)
        }
        face = px < WORLD / 2 ? 1 : -1
        cam = clampD(px - W / ZOOM / 2, 0, max(0, WORLD - W / ZOOM))
        active = -1
        ringSpot = -1
        floaters = []
        arriveT = 4.5
        events.append(4)
        if to == .main { hint("gwtap", "Tap the Gem World storefront to browse its flats and specimens.") }
        if to == .skoolie && !on(EV_SKOOL) { hint("skoolnot", "Quiet out here. Skooliepalooza gathers on " + EVENTS[EV_SKOOL].when + ".") }
        if to == .tyson && tysonShow() == nil { hint("tysonnot", "The show grounds are empty today. Next: " + nextOf([EV_GEM, EV_SELL, EV_CRAFT]) + ".") }
    }

    // MARK: saving

    func snapshot() -> SaveData? {
        if phase != .play || ended || previewing { return nil }
        return rawSnapshot()
    }
    private func rawSnapshot() -> SaveData {
        return SaveData(life: life.rawValue, rig: rig.rawValue, look: look, money: money + ringPaid, health: health, cred: cred, day: day,
                        dayT: dayT, wood: wood, rockVals: rockVals, odd: odd, panels: panels, px: inRig ? rigX : px, rigX: rigX,
                        area: area.rawValue, rigArea: rigArea.rawValue, toy: toy, toyArea: toyArea.rawValue, toyX: onToy ? px : toyX,
                        permitDays: permitDays, business: business, adDays: adDays, page: page, jewelVals: jewelVals, detector: detector, campDays: campDays,
                        age: age, year: year, resident: resident, house: house, upgrades: Array(upgrades), followers: followers,
                        camels: Array(camels), hasDog: hasDog, dogCholla: dogCholla,
                        weather: weather, afterRain: afterRain, tanks: tanks, propane: propane, stats: stats, notes: Array(fieldNotes), era: era, sStart: seasonStartCred, best: bestSeason, began: seasonBegan,
                        seen: Array(seen), dug: dug, boothDay: boothDay, mailDay: mailDay, magic: foundMagic, stripe: stripe, flag: flag)
    }
    func restore(_ s: SaveData) {
        life = Life(rawValue: s.life) ?? .nomad
        rig = RigKind(rawValue: s.rig) ?? .minivan
        look = s.look; money = s.money; health = s.health; cred = s.cred; day = s.day; dayT = s.dayT
        wood = s.wood; rockVals = s.rockVals; odd = s.odd; panels = s.panels; px = s.px; rigX = s.rigX
        area = Area(rawValue: s.area) ?? .ltva
        rigArea = Area(rawValue: s.rigArea) ?? .ltva
        toy = s.toy; toyArea = Area(rawValue: s.toyArea) ?? .main; toyX = s.toyX
        permitDays = s.permitDays; business = s.business; adDays = s.adDays; page = s.page; jewelVals = s.jewelVals; detector = s.detector
        campDays = s.campDays
        age = s.age; year = s.year; resident = s.resident; house = s.house; upgrades = Set(s.upgrades); followers = s.followers; camels = Set(s.camels); hasDog = s.hasDog; dogCholla = s.dogCholla; weather = s.weather; afterRain = s.afterRain
        tanks = s.tanks ?? 100; propane = s.propane ?? 100
        if let st = s.stats, st.count == 8 { stats = st }
        fieldNotes = Set(s.notes ?? []); era = s.era ?? 0
        seasonStartCred = s.sStart ?? s.cred; bestSeason = s.best ?? 0
        seasonBegan = s.began ?? Date().timeIntervalSince1970
        // today's limits come back with the save, so quitting and reopening can't reset them
        seen = Set(s.seen ?? []); dug = s.dug ?? [:]
        boothDay = s.boothDay ?? 0; mailDay = s.mailDay ?? mailDay
        foundMagic = s.magic ?? false
        stripe = s.stripe ?? 0
        flag = s.flag ?? 0
        inRig = false; onToy = false
        shown = ["start"]
        hasSave = true
    }

    /// Crossing the fence at the intaglios: the site steward comes out, and word gets around.
    private func trespass(_ words: String, _ cost: Int) {
        cred = max(0, cred - cost)
        madT = 5; madX = px + 46; madText = words
        float("-\(cost) cred", px, REDC)
        events.append(2)
    }

    func startPreview(_ k: Int) {
        previewStash = hasSave ? rawSnapshot() : nil
        previewOpen = false
        previewing = true
        demo(PREVIEWS[k].1)
        hintT = 0
    }
    func endPreview() {
        refund()
        previewing = false
        clockFreeze = false; driveFreeze = false; cineFreeze = false
        driving = false; mapOpen = false; browseOpen = false; phoneOpen = false; tourOpen = false; mineOpen = false; boardOpen = false
        alsOpen = false; seasonCard = false; ended = false; cineShots = []; genOn = false; madT = 0; dustAmt = 0; plantShow = false; showRigs = false
        floaters = []; hintT = 0
        life = .nomad; pickRig = 1
        begin()
        cineShots = []
        era = 0; fieldNotes = []; bestSeason = 0; dug = [:]; seen = []
        if let s = previewStash { restore(s) } else { hasSave = false }
        previewStash = nil
        phase = .title
        previewOpen = true
    }

    /// Screens for the build machine's screenshots.
    func demo(_ key: String) {
        if key == "pick" { phase = .pick; return }
        if key == "rigs" { showRigs = true; return }
        life = .nomad; pickRig = 1; look = 1
        begin()
        if !key.hasPrefix("cine") { cineShots = [] } else { cineFreeze = true }
        hintT = 0
        if key == "night" { px = 1690; dayT = 0.8; wood = 3 }
        if key == "drive" || key == "drivenight" {
            rig = .classC; inRig = true; dayT = key == "drive" ? 0.3 : 0.78
            travel(.skoolie); startDrive(.skoolie, 10, 0, false)
            driveLeft = 6.5; driveSpeed = 1; driveScroll = 900; driveLane = 1; driveLaneY = 1
            driveCars = [Car(x: W * 0.7, lane: 0, kind: 3, v: 120), Car(x: W * 0.93, lane: 1, kind: 0, v: 130)]
            driveFreeze = true
            if key == "drivenight" { stopDone = false; stopKind = 1; stopX = W * 0.62 }
        }
        if key == "drivestop" {
            rig = .classB; inRig = true; dayT = 0.25
            travel(.roadrunner); startDrive(.roadrunner, 5, 0, false)
            driveLeft = 2.5; driveSpeed = 1; driveScroll = 400; driveCars = []
            stopDone = false; stopKind = 0; stopX = W * 0.66; driveFreeze = true
        }
        if key == "party" {
            dayT = 0.7; clockFreeze = true
            let x = spots.first(where: { $0.kind == .camp })?.x ?? 1260
            px = x + 40
            partyDay = day; partyArea = area; partyX = x; partyT = -40; seen.insert(18)
        }
        if key == "gemfront" { place(.main, 550); dayT = 0.3; clockFreeze = true }
        if key == "gemworld" {
            let x = spots.first(where: { $0.kind == .gemworld })?.x ?? 0
            area = .main; px = x - 20; money = 600; dayT = 0.3; shown.insert("gwtap"); openBrowse()
        }
        if key == "dust" {
            place(.ltva, 1500); toy = 5; toyArea = .ltva; toyX = 1500; onToy = true; vx = 140; dayT = 0.3
            clockFreeze = true; dustAmt = 1; madT = 99; madX = 1640; madText = "Slow down! You're dusting our camp!"
        }
        if key == "gen" {
            dayT = 0.8; clockFreeze = true; genOn = true; madT = 99; madX = rigX + 70; madText = "It's after ten! Shut that generator off!"
            px = rigX + 30
        }
        if key == "drivetow" {
            life = .rver; toy = 5; toyArea = .ltva; rig = .classA; inRig = true; dayT = 0.2
            travel(.dome); startDrive(.dome, 4, 0, false)
            driveLeft = 2; driveSpeed = 1; driveScroll = 300; driveCars = [Car(x: W * 0.8, lane: 0, kind: 1, v: 120)]
            stopDone = true; driveFreeze = true
        }
        if key == "drivetrail" {
            toy = 5; onToy = true; dayT = 0.35
            travel(.trail); startDrive(.trail, 3, 1, true)
            driveLeft = 1.5; driveSpeed = 1; driveScroll = 700; driveFreeze = true
        }
        if key == "ltva" { px = 760; dayT = 0.3; rig = .classB; inRig = true; rigX = 760 }
        if key == "main" { place(.main, 3920); money = 400; day = 14 }
        if key == "mainwest" { place(.main, 2150); money = 400; day = 9; dayT = 0.35 }
        if key == "maineast" { place(.main, 3060); money = 400; day = 9; dayT = 0.4 }
        if key == "mainnight" { place(.main, 3020); money = 400; day = 9; dayT = 0.78; clockFreeze = true }
        if key == "propane" { place(.main, 4400); money = 400; propane = 20; tanks = 30; dayT = 0.4; clockFreeze = true }
        if key == "readers" { place(.main, 4440); money = 400; day = 9; dayT = 0.3 }
        if key == "gem" { place(.tyson, 1050); money = 300; day = 7; rockVals = [40] }
        if key == "rain" { place(.dome, 2060); rig = .classB; rigArea = .dome; rigX = 1500; weather = 3; dayT = 0.3 }
        if key == "windy" { px = 1500; weather = 1; dayT = 0.25 }
        if key == "critters" { place(.dome, 260); dayT = 0.42 }
        if key == "trailride" { place(.trail, 640); toy = 6; toyArea = .trail; toyX = 640; onToy = true; vx = 150; dayT = 0.3 }
        if key == "cine0" { cineT = 1.5 }
        if key == "cine1" { cineT = 5.8 }
        if key == "cine2" { cineT = 10.2 }
        if key == "cine3" { cineT = 15 }
        if key == "cine4" { cineShots = [4]; cineCaps = ["April. The snowbirds head north."]; cineT = 2 }
        if key == "happy" { px = 1260; dayT = 0.6; rig = .classC; life = .rver }
        if key == "cleanup" { place(.dome, 2380); dayT = 0.3 }
        if key == "dog" { place(.main, 4110); hasDog = true; dayT = 0.3 }
        if key == "camels" { place(.tyson, 2760); camels = [0, 1, 2, 3, 4] }
        if key == "page" { place(.dome, 120); page = true; cred = 60; followers = 940; upgrades = [3]; dayT = 0.3 }
        if key == "river" { place(.skoolie, 220); dayT = 0.25; clockFreeze = true }
        if key == "food" { day = 8; place(.tyson, 860); dayT = 0.3; clockFreeze = true }
        if key == "blm" { place(.roadrunner, 120); dayT = 0.3; clockFreeze = true }
        if key == "booth" {
            day = 8; area = .tyson; let x = spots.first(where: { $0.kind == .booth })?.x ?? 0
            place(.tyson, x - 20); boothDay = day; rockVals = [40, 55, 70]; odd = 2; dayT = 0.3; clockFreeze = true
        }
        if key == "haggle" {
            day = 8; place(.tyson, 900); money = 500; dayT = 0.3; clockFreeze = true; openBrowse()
            wares[0].haggled = true; wares[0].price = Int(Double(wares[0].price) * 0.8); mapMsg = wares[0].who + ": \"Alright, \(wares[0].price) and it's yours.\""; mapMsgT = 99
        }
        if key == "rvshow" { day = 22; place(.tyson, 2560); dayT = 0.3; clockFreeze = true }
        if key == "hijolly" { place(.hijolly, 900); dayT = 0.6; clockFreeze = true }
        if key == "plomosa" { place(.plomosa, 1200); dayT = 0.3; clockFreeze = true }
        if key == "crystal" { place(.crystal, 840); dayT = 0.35; clockFreeze = true }
        if key == "palms" { place(.palms, 960); dayT = 0.3; clockFreeze = true }
        if key == "plants" { place(.plomosa, 300); dayT = 0.3; clockFreeze = true; plantShow = true }
        if key == "ice" { place(.ltva, 1300); era = 2; dayT = 0.3; clockFreeze = true }
        if key == "zoo" { place(.hijolly, 400); era = 2; dayT = 0.4; clockFreeze = true; zooShow = true }
        if key == "icecat" { place(.desertbar, 900); era = 2; dayT = 0.4; clockFreeze = true }
        if key == "icecamel" { place(.tyson, 1200); era = 2; dayT = 0.4; clockFreeze = true }
        if key == "icesloth" { place(.dome, 900); era = 2; dayT = 0.4; clockFreeze = true }
        if key == "icewolf" { place(.trail, 1100); era = 2; dayT = 0.4; clockFreeze = true }
        if key == "icehorse" { place(.scaddan, 1000); era = 2; dayT = 0.4; clockFreeze = true }
        if key == "icecamp" { place(.plomosa, 1100); era = 2; dayT = 0.6; clockFreeze = true }
        if key == "labyrinth" { place(.ltva, 2640); dayT = 0.3; clockFreeze = true }
        if key == "magic" { place(.ltva, 2890); dayT = 0.4; clockFreeze = true }
        if key == "west" { place(.main, 250); dayT = 0.4; clockFreeze = true }
        if key == "nugget" { place(.dome, 3120); dayT = 0.4; clockFreeze = true }
        if key == "beerbelly" { place(.tyson, 470); dayT = 0.5; clockFreeze = true }
        if key == "solar" { place(.main, 5250); dayT = 0.4; clockFreeze = true }
        if key == "pool" { place(.tyson, 3090); dayT = 0.5; clockFreeze = true }
        if key == "custom" { place(.ltva, 1180); dayT = 0.5; clockFreeze = true; stripe = 3; flag = 2; customOpen = true }
        if key == "mapq" { place(.ltva, 1180); mapOpen = true; mapQuad = 1 }
        if key == "busy" { place(.ltva, 1900); dayT = 0.4; clockFreeze = true; stripe = 5; flag = 1 }
        if key == "pops" { place(.dome, 600); dayT = 0.4; clockFreeze = true; popFreeze = true }
        if key == "deep" { place(.ltva, 1250); era = 3; dayT = 0.4; clockFreeze = true }
        if key == "deeprhino" { place(.palms, 1100); era = 3; dayT = 0.5; clockFreeze = true }
        if key == "deep2" { place(.main, 1380); era = 3; dayT = 0.5; clockFreeze = true }
        if key == "kb" { place(.tyson, 400); dayT = 0.4; clockFreeze = true }
        if key == "als" { place(.main, 1520); dayT = 0.5; clockFreeze = true; alsOpen = true }
        if key == "past" { place(.ltva, 1500); era = 1; dayT = 0.3; clockFreeze = true }
        if key == "pastriver" { place(.skoolie, 800); era = 1; dayT = 0.35; clockFreeze = true }
        if key == "pastmain" { place(.main, 1520); era = 1; dayT = 0.6; clockFreeze = true }
        if key == "desertbar" { day = 6; place(.desertbar, 960); dayT = 0.45; clockFreeze = true }
        if key == "intagyell" { place(.intaglios, 1160); dayT = 0.4; clockFreeze = true; madT = 99; madX = 1206; madText = "Hey! Off the figures! Those have been here a thousand years!" }
        if key == "intaglios" { place(.intaglios, 940); dayT = 0.25; clockFreeze = true }
        if key == "board" { place(.main, 3490); day = 9; dayT = 0.3; clockFreeze = true; business = 1; adDays = 2; boardOpen = true }
        if key == "minein" { place(.dome, 820); dayT = 0.3; clockFreeze = true; detector = true; mineFind = 2; mineText = "Your detector sounds off over the old ore dump at the portal: a small nugget, 42 coins."; mineOpen = true }
        if key == "tour" { day = 24; place(.skoolie, 1480); dayT = 0.3; clockFreeze = true; tourBus = 0; tourOpen = true }
        if key == "newyear" { place(.ltva, 1400); day = 4; dayT = 0.81; clockFreeze = true }
        if key == "xmas" { place(.main, 2620); day = 2; dayT = 0.76; clockFreeze = true }
        if key == "flood" { place(.roadrunner, 400); weather = 3; dayT = 0.3; clockFreeze = true }
        if key == "coffee" { dayT = 0.12; clockFreeze = true; px = rigX + 120; day = 2 }
        if key == "wildnight" { place(.ltva, 600); dayT = 0.82; clockFreeze = true }
        if key == "rainbow" { place(.dome, 600); dayT = 0.15; afterRain = 2; weather = 0; clockFreeze = true }
        if key == "windy" { place(.scaddan, 900); dayT = 0.3; weather = 1; clockFreeze = true }
        if key == "phone" {
            place(.main, 740); page = true; cred = 40; followers = 1460; pagePay = 36; dayT = 0.35; clockFreeze = true
            posts = [PagePost(text: "pizza at Silly Al's", day: 3, likes: 88, comments: 9), PagePost(text: "a photo of the sunset at La Posa South", day: 2, likes: 141, comments: 17), PagePost(text: "a party at camp", day: 1, likes: 203, comments: 31), PagePost(text: "helping a stranded van on the highway", day: 1, likes: 64, comments: 5)]
            shown.insert("phone"); phoneOpen = true
        }
        if key == "goals" {
            place(.main, 740); page = true; followers = 320; hasDog = true; camels = [0, 1, 2]; panels = 1; dayT = 0.35; clockFreeze = true
            shown.insert("phone"); phoneOpen = true; phoneTab = 1
        }
        if key == "qfest" { place(.roadrunner, 900); day = 22; dayT = 0.4 }
        if key == "western" { place(.main, 3920); day = 82; dayT = 0.45 }
        if key == "gear" { life = .rver; rig = .classC; panels = 2; upgrades = [0, 1, 2, 3]; rigX = 1150; px = 1240; dayT = 0.35 }
        if key == "computer" { place(.main, 3350); rig = .van }
        if key == "browse" { place(.tyson, 1050); money = 300; day = 7; openBrowse() }
        if key == "parade" { place(.main, 2740); day = 13; dayT = 0.3 }
        if key == "home" { place(.main, 4660); money = 25000; day = 60; life = .rver; resident = true; dayT = 0.6 }
        if key == "season" { day = SEASON_END + 1; resident = true; business = 2; cred = 40; money = 2840; followers = 1320; page = true; stats = [150, 0, 5, 214, 18, 31, 9, 3]; seasonCard = true }
        if key == "end" { age = 84; year = 24; cred = 210; money = 18000; house = true; finish() }
        if key == "rules" { phase = .title; rulesOpen = true }
        if key == "previews" { phase = .title; previewOpen = true }
        if key == "tyson" { life = .rver; place(.tyson, 2390); money = 3000; day = 21; rig = .classB }
        if key == "dome" { place(.dome, 800); rig = .classB; rigArea = .dome; rigX = 1520; dayT = 0.56 }
        if key == "toys" { place(.main, 1250); money = 3000; toy = 3; toyArea = .main; toyX = 1180 }
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
        cam = clampD(px - W / ZOOM / 2, 0, max(0, WORLD - W / ZOOM))
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
    /// Finds are limited: each spot gives up only so much in a day.
    func left(_ i: Int) -> Int {
        let cap: Int
        switch spots[i].kind {
        case .rockhound: cap = 3
        case .detect: cap = 4
        case .mine: cap = 2
        case .gemworld: cap = 3
        case .vendors: cap = 4
        case .skoolie: cap = 2
        case .fire: cap = 2         // a neighbor only burns so much wood in a night
        case .cabin: cap = 1
        case .booth: cap = 8
        default: return 99
        }
        return cap - (dug["\(area.rawValue)-\(i)"] ?? 0)
    }

    private func sellOffer() -> Offer? {
        // now and then a collector at the table pays well over the going price
        let mix: Int = day * 13 + rocks * 3 + odd * 7 + jewelry * 11
        let collector: Bool = hashN(Double(mix) + 0.5) > 0.72
        let m = collector ? 1.35 : 1.0
        let who = collector ? "A collector wants " : "Sell "
        if let v = jewelVals.first { return Offer(label: who + (collector ? "your pendant" : "a pendant"), cost: 0, earn: Int(Double(v) * m), dur: 1.1) }
        if odd > 0 { return Offer(label: who + (collector ? "your oddity" : "an oddity"), cost: 0, earn: Int(Double(oddSell) * m), dur: 1.1) }
        if let v = rockVals.first { return Offer(label: who + (collector ? "your specimen" : "a specimen"), cost: 0, earn: Int(Double(v) * m), dur: 1.1) }
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
        if left(i) <= 0 { return nil }
        switch sp.kind {
        case .wash:
            // no wood gathering on BLM land: the dead wood is shelter for the desert
            return nil
        case .camp:
            if rigArea != area {
                return rig == .tent ? Offer(label: "Pitch your tent here", cost: 0, earn: 0, dur: 2) : nil
            }
            if area == .ltva && permitDays <= 0 { return nil }
            if dogCholla { return Offer(label: "Comb the cholla off your dog", cost: 0, earn: 0, dur: 2.4) }
            if genOn { return Offer(label: "Shut off the generator", cost: 0, earn: 0, dur: 0.8) }
            if neighborVisit { return Offer(label: "Coffee with the neighbor", cost: 0, earn: 0, dur: 1.6) }
            if cred >= 25 && !page { return Offer(label: "Start a Facebook page", cost: 0, earn: 0, dur: 2) }
            if dayT > 0.55 && dayT < 0.72 && !seen.contains(18) { return Offer(label: "Throw a party for the neighbors", cost: 20, earn: 0, dur: 2.2) }
            return health < 96 ? Offer(label: "Rest by your fire", cost: 0, earn: 0, dur: 2.2) : nil
        case .bench:
            if rigArea != area { return nil }
            return rocks > 0 && jewelry < 4 ? Offer(label: "Wire-wrap a pendant", cost: 0, earn: 0, dur: 2.6) : nil
        case .fire:
            return wood > 0 ? Offer(label: "Sell " + neighbor(sp.x > 1400 ? 2 : 4).0 + " a bundle of firewood", cost: 0, earn: 10, dur: 0.9) : nil
        case .host:
            if permitDays < 4 { return Offer(label: "14-day LTVA permit", cost: 40, earn: 0, dur: 1.2) }
            return wood < 10 ? Offer(label: "Buy a firewood bundle from the host", cost: 7, earn: 0, dur: 0.8) : nil
        case .station:
            return inRig && rig != .tent && !seen.contains(11) ? Offer(label: "Dump tanks and fill water", cost: 0, earn: 0, dur: 2) : nil
        case .outhouse:
            return health < 96 ? Offer(label: "Use the outhouse", cost: 0, earn: 0, dur: 1.0) : nil
        case .board:
            if business > 0 && adDays == 0 { return Offer(label: "Post an ad: " + BIZ[business - 1].name, cost: 10, earn: 0, dur: 1.2) }
            if !seen.contains(23) && health > 15 { let j = JOBS[day % JOBS.count]; return Offer(label: "Odd job: " + j.0, cost: 0, earn: j.1, dur: 2.6) }
            return Offer(label: "Read the board", cost: 0, earn: 0, dur: 0.4)
        case .grocery:
            return health < 96 ? Offer(label: "Groceries", cost: 15, earn: 0, dur: 1.0) : nil
        case .gemworld:
            return rocks < packCap ? Offer(label: "Rough rock to work (\(left(i)) left today)", cost: rockBuy + 14, earn: 0, dur: 1.0) : nil
        case .park:
            if on(EV_WESTERN) { return seen.contains(16) ? nil : Offer(label: "Cowboy poetry and live country music", cost: 0, earn: 0, dur: 2) }
            if on(EV_RTR) { return seen.contains(12) ? nil : Offer(label: "Rubber Tramp Rendezvous: free workshops on solar, builds and boondocking", cost: 0, earn: 0, dur: 2) }
            if dayT < 0.4 && !seen.contains(19) { return Offer(label: "Play pickleball", cost: 0, earn: 0, dur: 2.2) }
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
        case .solar:
            if rig == .tent { return nil }
            return panels < 2 ? Offer(label: panels == 0 ? "Solar panel, installed" : "Second solar panel", cost: panels == 0 ? 120 : 200, earn: 0, dur: 1.6) : nil
        case .beerbelly:
            return seen.contains(44) ? nil : Offer(label: "A cold one at Beer Belly's", cost: 6, earn: 0, dur: 1.6)
        case .carls:
            return seen.contains(45) ? nil : Offer(label: inRig ? "Drive-thru burger" : "Burger and fries", cost: 9, earn: 0, dur: 1.4)
        case .terribles:
            return seen.contains(46) ? nil : Offer(label: "Coffee from the Starbucks inside", cost: 6, earn: 0, dur: 1.2)
        case .tools:
            if rig == .tent { return nil }
            for u in [UP_LITHIUM, UP_AWNING, UP_RACK] where !upgrades.contains(u) { return Offer(label: UPGRADES[u].0, cost: UPGRADES[u].1, earn: 0, dur: 1.8) }
            return nil
        case .camel:
            return camels.contains(sp.arg) ? nil : Offer(label: "Photograph the camel sculpture", cost: 0, earn: 0, dur: 1.2)
        case .dogpark:
            return hasDog && !seen.contains(22) ? Offer(label: "Let your dog run", cost: 0, earn: 0, dur: 2) : nil
        case .stray:
            return hasDog ? nil : Offer(label: "Share your sandwich with the stray", cost: 5, earn: 0, dur: 2.4)
        case .pizza:
            return seen.contains(24) ? nil : Offer(label: "Pizza and a cold one", cost: 14, earn: 0, dur: 1.6)
        case .post:
            return day - mailDay >= 7 ? Offer(label: "Pick up your General Delivery mail", cost: 0, earn: 0, dur: 1.2) : nil
        case .pool:
            return seen.contains(43) ? nil : Offer(label: "Day pass: swim in the new pool", cost: 8, earn: 0, dur: 2.4)
        case .laundry:
            return seen.contains(25) ? nil : Offer(label: "Shower and laundry", cost: 11, earn: 0, dur: 2)
        case .tour:
            return on(EV_SKOOL) && !seen.contains(28) ? Offer(label: "Tour a converted bus", cost: 0, earn: 0, dur: 1.4) : nil
        case .shop:
            if sp.arg == 0 && wood <= 5 { return Offer(label: "Buy 5 firewood bundles", cost: 25, earn: 0, dur: 1.2) }
            if (sp.arg == 1 || sp.arg == 5) && rig != .tent && propane < 90 { return Offer(label: "Fill propane", cost: Int((100 - propane) * 0.3) + 4, earn: 0, dur: 1.4) }
            return nil
        case .cleanup:
            return seen.contains(21) || health < 15 ? nil : Offer(label: "Pick up trash with the cleanup crew", cost: 0, earn: 0, dur: 2.4)
        case .radio:
            return on(EV_QFEST) && !seen.contains(17) ? Offer(label: "Get on the air with the hams", cost: 0, earn: 0, dur: 2.2) : nil
        case .computer:
            if rig == .tent || upgrades.contains(UP_STARLINK) { return nil }
            return Offer(label: UPGRADES[UP_STARLINK].0, cost: UPGRADES[UP_STARLINK].1, earn: 0, dur: 2)
        case .panorama:
            return on(EV_PAN) && !detector ? Offer(label: "Metal detector", cost: 150, earn: 0, dur: 1.4) : nil
        case .vendors:
            guard let e = tysonShow() else { return nil }
            if e == EV_GEM { return rocks < packCap ? Offer(label: "Mineral specimen", cost: rockBuy, earn: 0, dur: 1.0) : nil }
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
            return health > 20 ? Offer(label: "Explore the old mine (\(left(i)) left today)", cost: 0, earn: 0, dur: 3) : nil
        case .detect:
            return detector ? Offer(label: "Swing the detector (\(left(i)) left today)", cost: 0, earn: 0, dur: 2.6) : nil
        case .rockhound:
            return rocks < packCap && health > 10 ? Offer(label: "Look for quartz (\(left(i)) left today)", cost: 0, earn: 0, dur: 2.2) : nil
        case .landmark:
            return seen.contains(sp.arg) ? nil : Offer(label: LANDMARKS[sp.arg], cost: 0, earn: 0, dur: 1.5)
        case .river:
            return health < 96 ? Offer(label: "Sit by the river", cost: 0, earn: 0, dur: 2.2) : nil
        case .watch:
            if sp.arg == 16 && dayT < 0.5 { return nil }
            return !fieldNotes.contains(sp.arg) ? Offer(label: "Watch quietly: " + wildOf(sp.arg).0, cost: 0, earn: 0, dur: 2.2) : nil
        case .village:
            if !fieldNotes.contains(20) { return Offer(label: "Visit the river village", cost: 0, earn: 0, dur: 2.4) }
            if seen.contains(39) { return nil }
            if day % 3 == 0 { return Offer(label: "Play hoop and pole with the village kids", cost: 0, earn: 0, dur: 2.4) }
            if day % 3 == 1 { return Offer(label: "Help grind mesquite pods", cost: 0, earn: 0, dur: 2.6) }
            return rocks > 0 ? Offer(label: "Trade a stone for a painted pot", cost: 0, earn: 0, dur: 1.8) : nil
        case .labyrinth:
            return seen.contains(40) ? nil : Offer(label: "Walk the labyrinth to the middle", cost: 0, earn: 0, dur: 6)
        case .magic:
            return seen.contains(41) ? nil : Offer(label: "Say hello at the Magic Circle", cost: 0, earn: 0, dur: 1.6)
        case .hike:
            if sp.arg == 2 { return !seen.contains(36) ? Offer(label: "Duck under the cable for a closer look", cost: 0, earn: 0, dur: 1.4) : nil }
            if sp.arg == 1 { return !seen.contains(30) ? Offer(label: "Walk the fence line to the figures", cost: 0, earn: 0, dur: 1.8) : nil }
            return !seen.contains(29) && health > 15 ? Offer(label: "Hike up to the palms", cost: 0, earn: 0, dur: 2.6) : nil
        case .bar:
            return barOpen && !seen.contains(31) ? Offer(label: "A cold drink and live music", cost: 12, earn: 0, dur: 1.8) : nil
        case .skoolie:
            return on(EV_SKOOL) && odd < 3 ? Offer(label: "Cow skull or other oddity", cost: oddBuy, earn: 0, dur: 1.0) : nil
        case .circle:
            return on(EV_SKOOL) && !seen.contains(13) ? Offer(label: "Potluck at the circle", cost: 0, earn: 0, dur: 2) : nil
        case .cabin:
            return health > 15 ? Offer(label: "Search the old cabin", cost: 0, earn: 0, dur: 2.2) : nil
        case .parade:
            return on(EV_PARADE) && !seen.contains(15) ? Offer(label: "Watch the Hi Jolly Parade", cost: 0, earn: 0, dur: 2) : nil
        case .rvpark:
            if !resident { return Offer(label: "Year-round site", cost: 600, earn: 0, dur: 2.4) }
            return health < 96 ? Offer(label: "Rest at your site", cost: 0, earn: 0, dur: 2) : nil
        case .house:
            if !house { return Offer(label: "Buy the house", cost: 20000, earn: 0, dur: 3) }
            return health < 96 ? Offer(label: "Rest at home", cost: 0, earn: 0, dur: 2) : nil
        }
    }

    /// Why a spot has nothing to offer right now.
    func note(_ i: Int) -> String {
        let sp = spots[i]
        if inRig { return sp.kind == .station ? "Done for today" : "Tap your rig to get out" }
        if left(i) <= 0 {
            switch sp.kind {
            case .gemworld, .vendors, .skoolie: return "Sold out of that today. More tomorrow"
            case .mine: return "Explored enough for one day"
            case .fire: return "They have plenty of wood for tonight"
            case .cabin: return "You've been through the cabin today"
            case .booth: return "A good day at the booth. Pack up till tomorrow"
            default: return "Picked over for today. Come back tomorrow"
            }
        }
        switch sp.kind {
        case .wash: return weather == 3 ? "The wash is running. Stay out of it" : "No wood gathering on BLM land. Buy bundles in town"
        case .camp:
            if rigArea != area { return "Your rig is parked at " + areaName(rigArea) }
            if area == .ltva && permitDays <= 0 { return "Your permit ran out. See the camp host" }
            return "Home. You feel fine"
        case .bench:
            if rigArea != area { return "Your tools are with your rig" }
            return jewelry >= 4 ? "Plenty made. Sell them from a booth at a show" : "Bring rough rock or a specimen to work"
        case .fire: return neighbor(sp.x > 1400 ? 2 : 4).0 + " needs firewood. Buy it at Big Market or from the host"
        case .host: return "Camp host Gloria: permit good for \(permitDays) more days"
        case .station: return rig == .tent ? "Tents don't need it" : (seen.contains(11) ? "Done for today" : "Drive your rig over to dump and fill")
        case .outhouse: return "You're good for now"
        case .pizza: return "Back tomorrow for another slice"
        case .post: return "Next mail in \(7 - (day - mailDay)) days"
        case .pool: return "One swim a day. The water was perfect"
        case .laundry: return seen.contains(25) ? "Clean as a whistle" : "You're clean enough"
        case .tour: return on(EV_SKOOL) ? "One open house a day. Back tomorrow" : "Bus open houses during Skooliepalooza"
        case .shop: return ["Hardware, groceries and RV basics", "RV spaces and propane", "Prescriptions. Call ahead in summer", "Parts for the rig", "Fresh meat, deli and quick groceries", "RV spaces and propane fills"][max(0, min(5, sp.arg))]
        case .board:
            if seen.contains(23) { return business > 0 ? "Your ad is up \(adDays) more days. New jobs tomorrow" : "New odd jobs go up every morning" }
            if business == 0 { return "Too worn out for work. Rest first" }
            return "Your ad is up \(adDays) more days"
        case .grocery: return "You're not hungry"
        case .gemworld: return "Pack is full"
        case .park:
            if on(EV_WESTERN) { return "See you tomorrow at Western Days" }
            if on(EV_RTR) { return "See you tomorrow at the Rendezvous" }
            return "Rubber Tramp Rendezvous: " + EVENTS[EV_RTR].when
        case .hall: return "You run every business in town"
        case .yacht: return "Back tomorrow night"
        case .lot: return "Top of the line. Nothing bigger here"
        case .rides: return "Nothing faster for sale"
        case .solar: return rig == .tent ? "Solar needs a roof. Trade up first" : "Two panels up. You're set for sun"
        case .beerbelly: return "See you tomorrow at day care"
        case .carls: return "They were out of ranch. They always are"
        case .terribles: return "Rows of pumps, EV chargers out back"
        case .tools: return rig == .tent ? "Gear needs a rig. Trade up first" : "Your rig is fully kitted out"
        case .camel: return "On the tour: \(camels.count) of \(CAMELS) camels"
        case .dogpark: return hasDog ? "Tired dog, happy dog" : "Off-leash, away from cholla and coyotes"
        case .stray: return "Your dog came from here"
        case .cleanup: return seen.contains(21) ? "The desert looks better. Back tomorrow" : "Too worn out. Rest first"
        case .radio: return on(EV_QFEST) ? "73 till tomorrow" : "Quartzfest ham radio week: " + EVENTS[EV_QFEST].when
        case .computer: return rig == .tent ? "A dish needs a roof. Trade up first" : "Your dish is up. Your page reaches twice as far"
        case .panorama: return on(EV_PAN) ? "Try the old placer diggings at Dome Rock" : "Open " + EVENTS[EV_PAN].when
        case .vendors:
            guard let e = tysonShow() else { return "Next show: " + nextOf([EV_GEM, EV_SELL, EV_CRAFT]) }
            if e == EV_CRAFT { return "Crafts and art. Sell your pendants from a booth" }
            if e == EV_GEM { return "Pack is full. Tap the tables to look closer" }
            return "Pack is full. Sell from a booth"
        case .office: return tysonShow() == nil ? "Closed between shows" : "Your space is paid for today"
        case .booth:
            if sp.arg == 1 { return on(EV_SKOOL) ? "Nothing to sell" : "Skooliepalooza: " + EVENTS[EV_SKOOL].when }
            if tysonShow() == nil { return "Booths only during shows" }
            return boothDay == day ? "Nothing to sell" : "Rent vendor space at the show office"
        case .bigtent: return on(EV_RV) ? "Top of the line already" : "Sports, Vacation & RV Show: " + EVENTS[EV_RV].when
        case .mine: return "Too worn out. Rest first"
        case .detect: return "You need a metal detector from Prospectors Panorama"
        case .rockhound: return rocks >= packCap ? "Pack is full" : "Too worn out. Rest first"
        case .landmark: return "You've been here today"
        case .river: return "The river's nice today"
        case .watch: return sp.arg == 16 && !fieldNotes.contains(16) ? "Big cat tracks in the mud. Come back toward dusk" : "In your field notes. Sit and watch as long as you like"
        case .village: return seen.contains(39) ? "They wave as you pass. Come back tomorrow" : "Bring a stone to trade for a pot"
        case .labyrinth: return "You've walked it today. Getting to the middle is the point"
        case .magic: return "Good people. No photos here"
        case .hike:
            if sp.arg == 2 { return "Stay outside the fence. One footprint lasts for centuries here" }
            if sp.arg == 1 { return "You've seen them today. Stay outside the fences" }
            return seen.contains(29) ? "One climb a day is plenty" : "Too worn out. Rest first"
        case .bar: return barOpen ? "Back next weekend" : "Open Saturdays and Sundays, noon to sunset"
        case .skoolie: return on(EV_SKOOL) ? "Pack is full" : "Skooliepalooza: " + EVENTS[EV_SKOOL].when + " (projected)"
        case .circle: return on(EV_SKOOL) ? "See you tomorrow" : "Skooliepalooza: " + EVENTS[EV_SKOOL].when + " (projected)"
        case .cabin: return "Too worn out. Rest first"
        case .parade: return on(EV_PARADE) ? "What a parade" : "Hi Jolly Parade: " + EVENTS[EV_PARADE].when
        case .rvpark: return "Your site. You feel fine"
        case .house: return "Home. You feel fine"
        }
    }

    private func complete(_ i: Int, _ o: Offer) {
        let sp = spots[i]
        let x = sp.x
        dug["\(area.rawValue)-\(i)", default: 0] += 1
        switch sp.kind {
        case .park, .radio, .circle, .parade, .bigtent, .vendors: stats[6] += 1
        case .booth: stats[4] += 1
        case .mine, .detect, .rockhound: stats[5] += 1
        default: break
        }
        switch sp.kind {
        case .wash:
            break
        case .camp:
            if o.label.hasPrefix("Coffee") {
                seen.insert(27)
                health = min(100, health + 5)
                cred += 1
                if rocks < packCap && Double.random(in: 0..<1) < 0.25 {
                    rockVals.append(Int(rnd(18, 40)))
                    float(neighbor(0).0 + " gave you a geode they cracked", x, GOLD)
                } else {
                    let tips = ["The agate's better after rain.", "Gem show crowds are lighter before ten.", "Your dog and ours should be friends.", "Ask me anything about solar.", "I know a guy with a cheap used side-by-side.", "The dump station line is short at lunch.", "Coffee's on any morning you want it."]
                    let n = neighbor(0)
                    float(n.0 + ": \"" + tips[day % tips.count] + "\"", x, CREAM)
                    hint("met" + n.0, "You met " + n.0 + ", " + n.1 + ".")
                }
            } else if rigArea != area {
                rigArea = area
                rigX = x - 60
                campDays = 0
                float("Tent pitched", x, CREAM)
            } else if genOn {
                genOn = false
                float(quietHours ? "Quiet at last" : "Generator off. Nice and quiet", x, CREAM)
            } else if dogCholla {
                dogCholla = false
                float("Flicked it off with the comb, pulled the spines", x, GREEN)
            } else if cred >= 25 && !page {
                page = true
                float("Your page is live", x, GOLD)
                hintT = 0
                followers = cred * 3
                hint("page", "Your Facebook page is up. Landmarks, events, finds and the wildlife all make posts that bring followers. At 1,000 followers it starts paying.")
            } else if dayT > 0.55 && dayT < 0.72 && !seen.contains(18) {
                seen.insert(18)
                cred += 4
                partyDay = day; partyArea = area; partyX = x; partyT = time
                stats[7] += 1
                float("Here they come, chairs and coolers", x, GOLD)
                post("a party at camp", 40)
            } else {
                health = min(100, health + (upgrades.contains(UP_AWNING) ? 32 : 20))
                float(upgrades.contains(UP_AWNING) ? "Rested in the shade" : "Rested", x, GREEN)
            }
        case .bench:
            let v = rockVals.removeFirst()
            jewelVals.append(v + Int(rnd(14, 28)))
            float("+1 pendant", x, CREAM)
            hint("jewel", "Pendants sell for a bit more than raw stone from a booth at a show. Small money, but it adds up.")
        case .fire:
            wood -= 1
            cred += 1
        case .host:
            if o.label.hasPrefix("Buy a firewood") {
                wood += 1
                float("+1 firewood bundle", x, CREAM)
                hint("woodbuy", "Firewood comes from town: Big Market sells 5 bundles cheaper than the host. Neighbors at their fires pay 10 a bundle.")
            } else {
                permitDays += 14
                float("Permit for 14 more days", x, CREAM)
            }
        case .station:
            seen.insert(11)
            tanks = 100
            health = min(100, health + 10)
            float("Tanks dumped, water full", x, GREEN)
        case .pizza:
            seen.insert(24)
            health = min(100, health + 30)
            cred += 1
            float("Best slice in town", x, GREEN)
            post("pizza at Silly Al's", 15)
        case .post:
            mailDay = day
            let amt = life == .rver ? 120 : 30
            money += Double(amt)
            float(life == .rver ? "Your check came  +\(amt)" : "A card from home with \(amt) inside", x, GOLD)
            events.append(5)
        case .pool:
            seen.insert(43)
            health = min(100, health + 25)
            if !shown.contains("pool") { shown.insert("pool"); cred += 1; post("the new pool at Rice Ranch", 10) }
            float("A long swim in the new pool", x, GREEN)
        case .laundry:
            seen.insert(25)
            health = min(100, health + 30)
            float("Hot shower, clean clothes", x, GREEN)
        case .tour:
            seen.insert(28)
            cred += 1
            health = min(100, health + 5)
            tourBus = day % 3
            tourOpen = true
            post("touring a skoolie at Skooliepalooza", 12)
        case .shop:
            if o.label.hasPrefix("Buy 5 firewood") {
                wood += 5
                float("+5 firewood bundles", x, CREAM)
                hint("woodbuy", "Sell bundles to neighbors at their campfires for 10 apiece. No gathering wood on BLM land.")
            } else {
                propane = 100
                float("Propane full", x, CREAM)
            }
        case .outhouse:
            health = min(100, health + 6)
            // once in a long while somebody has left something behind
            if Double.random(in: 0..<1) < 0.04 && !seen.contains(38) {
                seen.insert(38)
                let finds: [(String, Double, Int)] = [("A gold ring on the shelf! Worth 120 coins", 120, 3), ("A silver belt buckle somebody forgot. 60 coins", 60, 2), ("A wallet with 40 coins. You keep the cash and hand the cards to the host", 40, 4), ("A pocket knife with a turquoise handle. 45 coins", 45, 2)]
                let f = finds[Int.random(in: 0..<finds.count)]
                money += f.1; cred += f.2
                hintT = 0
                hint("privy\(day)", f.0 + ".")
                float("A rare find!", x, GOLD)
                events.append(5)
            }
            float("Relief", x, GREEN)
        case .board:
            if o.label.hasPrefix("Read") {
                boardOpen = true
            } else if o.label.hasPrefix("Odd job") {
                seen.insert(23)
                health = max(0, health - 8)
                cred += 1
            } else {
                adDays = 3
                cred += 1
                float("Ad posted for 3 days", x, CREAM)
            }
        case .grocery:
            health = min(100, health + 45)
            float("Fed", x, GREEN)
        case .gemworld:
            rockVals.append(rockSell + Int(rnd(-8, 8)))
            float("+1 rough rock", x, CREAM)
        case .park:
            if on(EV_WESTERN) {
                seen.insert(16)
                cred += 2
                health = min(100, health + 10)
                float("Yeehaw", x, GOLD)
                post("Buck Connors Western Days", 50)
            } else if on(EV_RTR) {
                seen.insert(12)
                cred += 2
                if odd < 3 { odd += 1; float("Swapped gear with another nomad: an old lantern", x, CREAM) } else { float("+2 cred", x, GOLD) }
                post("the Rubber Tramp Rendezvous", 50)
            } else if dayT < 0.4 && !seen.contains(19) {
                seen.insert(19)
                cred += 2
                health = min(100, health + 8)
                float("Won a game of doubles", x, GOLD)
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
        case .solar:
            panels += 1
            float("Solar on the roof", x, CREAM)
        case .beerbelly:
            seen.insert(44)
            health = min(100, health + 8)
            if !shown.contains("beerbelly") { shown.insert("beerbelly"); cred += 1; post("Beer Belly's Adult Day Care", 10) }
            float("Cold beer, live music, good company", x, GREEN)
        case .carls:
            seen.insert(45)
            health = min(100, health + 22)
            float("No ranch. Again", x, CREAM)
        case .terribles:
            seen.insert(46)
            health = min(100, health + 10)
            float("Coffee for the road", x, GREEN)
        case .tools:
            if let u = [UP_LITHIUM, UP_AWNING, UP_RACK].first(where: { !upgrades.contains($0) }) {
                upgrades.insert(u)
                float(UPGRADES[u].0 + " installed", x, CREAM)
                let why = [UP_LITHIUM: "Your solar now banks twice the power, so it pays twice as much each morning.",
                           UP_AWNING: "Shade at camp. Resting at your camp does more for you now.",
                           UP_RACK: "Room for eight stones in your pack instead of five."]
                hintT = 0
                hint("up\(u)", why[u] ?? "")
            }
        case .camel:
            camels.insert(sp.arg)
            cred += 1
            float("Camel \(camels.count) of \(CAMELS)", x, GOLD)
            post("a camel sculpture", 15)
            if camels.count == CAMELS {
                cred += 10
                post("the whole camel sculpture tour", 150)
                hintT = 0
                hint("camels", "You found every camel on the tour. Hi Jolly would be proud.")
            }
        case .dogpark:
            seen.insert(22)
            cred += 1
            health = min(100, health + 6)
            float("Zoomies", x, GOLD)
            post("the dog at the dog park", 40)
        case .stray:
            hasDog = true
            cred += 2
            float("You have a dog now", x, GOLD)
            hintT = 0
            hint("dog", "The dog follows you everywhere. Watch for cholla: if it gets stuck in the fur, comb it out at your camp.")
        case .cleanup:
            seen.insert(21)
            cred += 2
            health = max(0, health - 4)
            float("Two bags of trash out of the wash", x, GOLD)
            post("a desert cleanup", 20)
        case .radio:
            seen.insert(17)
            cred += 2
            float("You talked to a ham in New Zealand", x, GOLD)
            post("Quartzfest", 40)
        case .computer:
            upgrades.insert(UP_STARLINK)
            cred += 1
            float("Starlink is up", x, GOLD)
            hintT = 0
            hint("starlink", "Internet anywhere. Your posts reach twice as many people.")
        case .panorama:
            detector = true
            float("Metal detector", x, CREAM)
            hint("detect", "Take it to the old placer diggings at Dome Rock.")
        case .vendors:
            if tysonShow() == EV_GEM { rockVals.append(rockBuy + Int(rnd(6, 24))); float("+1 specimen", x, CREAM); hint("browse", "Tap the vendor tables to look closer at what each one is selling.") } else { odd += 1; float("+1 oddity", x, CREAM) }
        case .office:
            boothDay = day
            float("Your booth is set up", x, CREAM)
        case .booth:
            if o.label.hasPrefix("A collector") { float("Sold to a collector!", x, GOLD) } else { float("Sold!", x, GREEN) }
            if !jewelVals.isEmpty { jewelVals.removeFirst(); cred += 2 } else if odd > 0 { odd -= 1; cred += 3 } else { rockVals.removeFirst(); cred += 2 }
            if sp.arg == 1 { cred += 1 }
        case .mine:
            health = max(0, health - 12)
            let r = Double.random(in: 0..<1)
            if r < 0.4 && rocks < packCap { let v = Int(rnd(25, 60)); rockVals.append(v); mineFind = 0; mineText = "A quartz vein in the wall. You chip out a specimen worth about \(v)." }
            else if r < 0.6 && odd < 3 { odd += 1; mineFind = 1; mineText = "An old carbide lantern on a timber ledge. Someone will want that." }
            else if r < 0.8 && detector { let g = Int(rnd(20, 60)); money += Double(g); mineFind = 2; mineText = "Your detector sounds off over the old ore dump at the portal: a small nugget, \(g) coins." }
            else { mineFind = 3; mineText = "Just bats, and the cold air of the old drift. Good to see, though." }
            cred += 1
            mineOpen = true
            hint("minesafe", "Real abandoned mines are deadly: bad air, rotten timbers and open shafts. Stay out and stay alive. This one's only a game.")
        case .detect:
            let r = Double.random(in: 0..<1)
            if r < 0.5 { let g = Int(rnd(1, 6)); money += Double(g); float("Old coins +\(g)", x, GOLD) }
            else if r < 0.65 && odd < 3 { odd += 1; float("A rusty spur", x, CREAM) }
            else if r < 0.73 { let g = Int(rnd(40, 120)); money += Double(g); float("Gold nugget! +\(g)", x, GOLD); cred += 2; post("a gold nugget", 80) }
            else { float("Pull tab", x, CREAM) }
        case .rockhound:
            health = max(0, health - 4)
            if area == .crystal {
                if Double.random(in: 0..<1) < 0.7 { rockVals.append(Int(rnd(30, 80))); float("+1 quartz crystal, clear as glass", x, GOLD) } else { float("Just broken shards", x, CREAM) }
                hint("kofa", "Crystal Hill is in the Kofa refuge: hand collecting only, and only a small amount each year. Leave the hill for the next person.")
            }
            else if afterRain > 0 { rockVals.append(Int(rnd(30, 60))); float("Washed out of the bank after the rain", x, GOLD) }
            else if Double.random(in: 0..<1) < 0.55 { rockVals.append(Int(rnd(16, 40))); float("+1 quartz", x, CREAM) } else { float("Pretty gravel", x, CREAM) }
        case .landmark:
            seen.insert(sp.arg)
            cred += 1
            float("+1 cred", x, GOLD)
            post(["Hi Jolly's tomb", "Reader's Oasis", "Tyson's Well", "the pioneer cemetery", "Celia's Rainbow Gardens"][sp.arg], 20)
        case .river:
            health = min(100, health + 14)
            float("Calm", x, GREEN)
        case .watch:
            fieldNotes.insert(sp.arg)
            health = min(100, health + 4)
            hintT = 0
            hint("wild\(sp.arg)", wildOf(sp.arg).1 + ".")
            cred += sp.arg == 16 ? 4 : 1
            float("Field notes \(notesHere)/\(notesTotal)", x, GOLD)
        case .labyrinth:
            seen.insert(40)
            cred += 3
            health = min(100, health + 6)
            float("The middle. You stand there a while", x, GOLD)
            post("the rock labyrinth at La Posa", 12)
        case .magic:
            seen.insert(41)
            cred += 1
            if !foundMagic {
                foundMagic = true
                hintT = 0
                hint("magic", "The Magic Circle: a clothing-optional corner of La Posa South that the regulars keep quiet about. It's on your map now. Be respectful, and no photos.")
            }
            float("They wave you over for coffee", x, GREEN)
        case .village where fieldNotes.contains(20):
            seen.insert(39)
            if o.label.hasPrefix("Play") { cred += 2; health = min(100, health + 4); float("You lose, badly. The kids are delighted", x, GOLD) }
            else if o.label.hasPrefix("Help") { cred += 1; health = min(100, health + 12); float("Sweet mesquite flour, and a place by the fire", x, GREEN) }
            else { if !rockVals.isEmpty { rockVals.removeFirst() }; if odd < 3 { odd += 1 }; cred += 2; float("A red-on-buff pot, wrapped in bark for the walk home", x, GOLD) }
        case .village:
            fieldNotes.insert(20)
            health = min(100, health + 10)
            cred += 3
            float("They share tepary beans and river fish, served in buff pottery", x, GOLD)
            hintT = 0
            hint("village", "The river people farm the floodplain after the summer floods and trade along desert trails as far as the coast. Their descendants, River Yuman peoples like the Mojave and Quechan, still live along the Colorado today.")
        case .hike:
            if sp.arg == 2 {
                seen.insert(36)
                trespass("Hey! Off the figures! Those have been here a thousand years!", 3)
            } else if sp.arg == 1 {
                seen.insert(30)
                cred += 2
                float("Figures scraped into the desert floor long, long ago", x, GOLD)
                post("the Blythe Intaglios", 28)
                hint("intaglios", "The intaglios are sacred to the tribes of the river. Look from outside the fences and leave the desert pavement untouched.")
            } else {
                seen.insert(29)
                health = max(0, health - 6)
                cred += 2
                float("California fan palms: some of the only native palms in Arizona", x, GREEN)
                post("hiking to the hidden palms in Kofa", 30)
            }
        case .bar:
            seen.insert(31)
            health = min(100, health + 10)
            cred += 2
            float("Solar-powered and off the grid. Great band today", x, GOLD)
            post("an afternoon at the Desert Bar", 26)
        case .skoolie:
            odd += 1
            cred += 1
            float("+1 oddity", x, CREAM)
        case .circle:
            seen.insert(13)
            health = min(100, health + 15)
            cred += 2
            float("Fed and welcomed", x, GOLD)
            post("Skooliepalooza", 70)
        case .cabin:
            health = max(0, health - 6)
            let r = Double.random(in: 0..<1)
            if r < 0.45 && odd < 3 { odd += 1; float("Found an old canteen", x, CREAM) }
            else if r < 0.75 { let g = Int(rnd(8, 28)); money += Double(g); float("Stashed silver +\(g)", x, GOLD) }
            else { float("Just packrat nests", x, CREAM) }
            cred += 1
        case .parade:
            seen.insert(15)
            cred += 2
            health = min(100, health + 6)
            float("Camels, floats and side-by-sides", x, GOLD)
            post("the Hi Jolly Parade", 60)
        case .rvpark:
            if !resident {
                resident = true
                float("A site of your own", x, GOLD)
                hintT = 0
                hint("resident", "You live at Holiday Palms now: 8 coins a day, rest any time, and you can stay the summer when the snowbirds leave.")
            } else {
                health = min(100, health + 30)
                float("Rested", x, GREEN)
            }
        case .house:
            if !house {
                house = true
                cred += 10
                float("Sticks and bricks in Quartzsite", x, GOLD)
                hintT = 0
                hint("house", "A house in town. Rest here any time, and when April comes you can stay through the summer with the AC on.")
            } else {
                health = min(100, health + 40)
                float("Home", x, GREEN)
            }
        }
        if o.earn > 0 {
            money += Double(o.earn)
            float("+\(o.earn)", x, GREEN)
            events.append(5)
        }
        if o.cost > 0 { events.append(6) }
        if cred >= 12 { hint("cred12", "Folks wave when you walk by now.") }
        if cred >= 25 && !page { hint("cred25", "People know your name. Start a Facebook page at your camp.") }
        events.append(1)
    }

    private func refund() {
        if ringPaid > 0.5 {
            money += ringPaid
            moneySeen = money
            float("Let go early: your \(Int(ringPaid.rounded())) coins came back", px, GOLD)
            hintT = 0
            hint("holdfull", "Keep holding HOLD until the ring closes all the way. Letting go early gives your coins back.")
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
        if inCine && !cineFreeze {
            cineT += dt
            if cineT >= Double(cineShots.count) * SHOT { cineShots = [] }
        }
        if hintT > 0 && !overlay { hintT -= dt }
        if arriveT > 0 && !overlay { arriveT -= dt }
        if flashT > 0 { flashT -= dt }
        if credPopT > 0 { credPopT -= dt }
        if popFreeze { credPopT = 0.9; credPopN = 3; coinPopT = 0.8; coinPopN = 60 }
        if coinPopT > 0 { coinPopT -= dt }
        if phase == .play {
            if moneySeen < 0 || previewing { moneySeen = money }
            let gain = money - moneySeen
            if gain >= 1 {
                coinPopN = (coinPopT > 0 ? coinPopN : 0) + Int(gain)
                coinPopT = 1.5
                if gain >= 25 { events.append(12) }
                moneySeen = money
            } else if gain < 0 { moneySeen = money }
        }
        if phase == .play {
            if credSeen < 0 || previewing { credSeen = cred }
            if cred > credSeen { credPopN = credPopT > 0 ? credPopN + cred - credSeen : cred - credSeen; credPopT = 1.6; events.append(11) }
            credSeen = cred
        }
        if phase == .play && driving { driveStep(dt) }
        if phase == .play && !overlay { play(dt) }
    }

    private func dawn() {
        day += 1
        events.append(7)
        rockBuy = Int(rnd(18, 32))
        rockSell = rockBuy + Int(rnd(10, 30))
        oddBuy = Int(rnd(24, 40))
        oddSell = oddBuy + Int(rnd(14, 40))
        jewelSell = rockSell + Int(rnd(8, 20))
        seen = []
        dug = [:]
        if afterRain > 0 { afterRain -= 1 }
        if rig != .tent && !resident && !house && !inPast {
            tanks = max(0, tanks - 22)
            propane = max(0, propane - (weather >= 2 ? 12 : 8))
            if tanks <= 0 {
                health = max(0, health - 12)
                hintT = 0
                hint("tanks\(day)", "Fresh water's gone and the gray tank is full. Drive the rig to a dump station to dump and fill.")
            } else if tanks < 30 {
                hint("tankslow", "Your tanks are getting full. Drive the rig to the dump and water station at La Posa South.")
            }
            if propane <= 0 {
                health = max(0, health - 10)
                hintT = 0
                hint("propane\(day)", "Out of propane: no heater and a cold night. Fill up at Pattie's or Q View on Main Street.")
            } else if propane < 25 {
                hint("propanelow", "Propane's running low. Pattie's and Q View on Main Street fill tanks.")
            }
        }
        if hasDog && !dogCholla && area != .main && area != .tyson && Double.random(in: 0..<1) < 0.15 {
            dogCholla = true
            hintT = 0
            hint("cholla\(day)", "Your dog got into a cholla. Comb it out at your camp. Never grab it with bare fingers.")
        }
        // today's weather is what yesterday's forecast said; roll the next one
        weather = tomorrow
        let roll = Double.random(in: 0..<1)
        tomorrow = roll < 0.72 ? 0 : (roll < 0.86 ? 1 : (roll < 0.95 ? 2 : 3))
        if weather == 3 {
            afterRain = 3
            hintT = 0
            hint("rain\(day)", "Rain in the desert. The washes are running, so stay out of them. The washes are the best rockhounding for a couple of days after.")
            if rig != .tent {
                for sp in AREAS[rigArea.rawValue].spots where sp.kind == .wash && abs(sp.x - rigX) < 160 {
                    money -= 150
                    health = max(0, health - 15)
                    hintT = 0
                    hint("stuck\(day)", "Your rig was parked by a wash when it ran. The tow out cost 150 coins. Never camp in a wash.")
                    break
                }
            }
        } else if weather == 1 {
            hintT = 0
            hint("wind\(day)", "A windy day. Dust everywhere. Tie down your awning.")
        }
        var total = panels * 6 * (upgrades.contains(UP_LITHIUM) ? 2 : 1)
        if business > 0 {
            var b = 0
            for k in 0..<business { b += BIZ[k].pay }
            if adDays > 0 { b = b * 3 / 2; adDays -= 1 }
            total += b
        }
        if page {
            followers += cred / 5
            pagePay = followers >= 1000 ? followers / 40 : 0
            total += pagePay
        }
        if resident { total -= 8 }
        if permitDays > 0 && rigArea == .ltva {
            permitDays -= 1
            if permitDays == 0 { hintT = 0; hint("permit\(day)", "Your LTVA permit ran out. The camp host sells another 14 days.") }
        }
        if rigArea == .dome || rigArea == .scaddan || rigArea == .roadrunner {
            campDays += 1
            if campDays == 12 { hintT = 0; hint("limit\(day)", "Two days left on your 14 at " + areaName(rigArea) + ". BLM wants you to move on after that.") }
        } else {
            campDays = 0
        }
        for e in EVENTS.indices where EVENTS[e].start == day && e != EV_PAN {
            hintT = 0
            hint("ev\(e)", EVENTS[e].name + " opens today at " + areaName(EVENTS[e].area) + ".")
        }
        if total != 0 {
            money += Double(total)
            float((total > 0 ? "+\(total)" : "-\(-total)") + " overnight", px, total > 0 ? GREEN : REDC)
        }
        if day == SEASON_END - 6 { hintT = 0; hint("seasonsoon\(year)", "The season ends April 15. Snowbirds head north; if you have a year-round RV site or a house, you can stay the summer.") }
        events.append(9)
        if day > SEASON_END {
            refund()
            bestSeason = max(bestSeason, seasonCred)
            seasonCard = true
            events.append(8)
        }
    }

    /// The end of a winter: head north for the summer, or stay if you have a place to live.
    private func newSeason(stay: Bool) {
        seasonCard = false
        bestSeason = max(bestSeason, seasonCred)
        seasonStartCred = cred; seasonBegan = Date().timeIntervalSince1970
        defer { stats = [Int(money), followers, cred, 0, 0, 0, 0, 0] }
        if stay {
            var b = 0
            for k in 0..<business { b += BIZ[k].pay }
            money += Double(b * 40)
            if resident && !house { money -= 600 }
            health = house ? 100 : 75
        } else {
            health = 100
            if rig != .tent || rigArea != .ltva { rigArea = .ltva; rigX = AREAS[0].arrive - 100 }
            area = .ltva
            px = AREAS[0].arrive
            if toy >= 0 { toyArea = .ltva; toyX = px + 60 }
            inRig = false; onToy = false
        }
        year += 1
        age += 1
        day = 1; dayT = 0.12
        permitDays = 14; campDays = 0; boothDay = 0; seen = []; adDays = 0
        cam = clampD(px - W / ZOOM / 2, 0, max(0, WORLD - W / ZOOM))
        floaters = []
        // the desert keeps everyone eventually
        if age >= 95 || (age >= 72 && Double.random(in: 0..<1) < Double(age - 70) * 0.05) {
            finish()
            return
        }
        if stay {
            cineShots = [5, 3]
            cineCaps = ["Summer. 110 in the shade, and you stayed.", "Winter \(year) · age \(age)"]
        } else {
            cineShots = [4, 0, 3]
            cineCaps = ["April. The snowbirds head north.", "October. Back down I-10.", "Winter \(year) · age \(age)"]
        }
        cineT = 0
        arriveT = 4.5
        hintT = 0
        hint("season\(year)", "Season \(year). You're \(age) now. " + (stay ? "You rode out the summer in Quartzsite." : "Back from up north, and the desert is filling up again."))
    }

    /// The last card: how the life in the desert went.
    func finish() {
        ended = true
        seasonCard = false
        mapOpen = false
        browseOpen = false
        var b = 0
        for k in 0..<business { b += BIZ[k].cost }
        let worth = Int(money) + (house ? 20000 : 0) + RIGS[rig.rawValue].price + b
        endTitle = worth > 30000 || cred > 150 ? "You prospered" : (worth > 5000 || cred > 50 ? "You lived OK" : "You scraped by")
        let home = house ? "in your house in town" : (resident ? "at your site at Holiday Palms" : (rig == .tent ? "in a tent at " + areaName(rigArea) : "in your " + RIGS[rig.rawValue].name.lowercased() + " at " + areaName(rigArea)))
        endText = "\(year) winters in the desert. You passed at \(age), " + home + ", with \(cred) people who'd call you a friend" + (page ? " and a Facebook page that remembered you" : "") + "."
    }

    // MARK: the gem show up close

    func openBrowse() {
        let s: Int
        if area == .main { s = 1 } else if area == .tyson && tysonShow() == EV_GEM { s = 0 } else { return }
        refund()
        if waresDay == day { stock[shop] = (day, wares) }
        shop = s
        if let st = stock[s], st.0 == day {
            wares = st.1
        } else if s == 1 {
            wares = gemWorldStock()
        } else {
            wares = []
            for k in 0..<6 {
                let n = Int(hashN(Double(day * 13 + k)) * 10) % 10
                let seller = SELLERS[(k / 2 + day) % SELLERS.count]
                let pct = Double(seller.1) + hashN(Double(day * 7 + k) + 0.5) * Double(seller.2 - seller.1)
                let w = WARE_WORTH[n]
                wares.append(Ware(name: WARE_NAMES[n], who: seller.0, price: max(5, Int(Double(w) * pct / 100)), lo: Int(Double(w) * 0.8), hi: Int(Double(w) * 1.15), sold: false))
            }
        }
        waresDay = day
        browseOpen = true
        mapMsg = ""
        if s == 1 { hint("gemworld", "Gem World is wholesale. A flat is a whole tray of small stones bought cheap to resell at a booth. Single specimens are in the cases. Stock changes every day.") }
    }

    /// Gem World's floor today: two wholesale flats and four specimens, below show prices.
    private func gemWorldStock() -> [Ware] {
        var out: [Ware] = []
        let flats = [("Flat of tumbled stones", 110), ("Flat of geode halves", 150), ("Flat of quartz points", 95), ("Flat of polished jasper", 120), ("Flat of desert roses", 85)]
        for k in 0..<2 {
            let f = flats[(day * 3 + k * 2) % flats.count]
            let pct = 0.6 + hashN(Double(day * 11 + k)) * 0.12
            out.append(Ware(name: f.0, who: "Wholesale · 24 pieces", price: Int(Double(f.1) * pct), lo: Int(Double(f.1) * 0.85), hi: Int(Double(f.1) * 1.15), sold: false))
        }
        let where_ = ["Specimen room", "Back warehouse", "Glass case", "Bins by the register"]
        for k in 0..<4 {
            let n = Int(hashN(Double(day * 17 + k + 40)) * 10) % 10
            let w = WARE_WORTH[n]
            let pct = 0.7 + hashN(Double(day * 5 + k) + 0.3) * 0.12
            out.append(Ware(name: WARE_NAMES[n], who: where_[k], price: max(5, Int(Double(w) * pct)), lo: Int(Double(w) * 0.8), hi: Int(Double(w) * 1.15), sold: false))
        }
        return out
    }

    /// Ask for a better price: about half the time they come down a fifth. Once per piece.
    private func haggle(_ k: Int) {
        if wares[k].sold || wares[k].haggled { return }
        wares[k].haggled = true
        let who = shop == 1 ? "The clerk" : wares[k].who.components(separatedBy: " ·").first ?? "The seller"
        let odds = 0.45 + min(0.25, Double(cred) / 200)
        if Double.random(in: 0..<1) < odds {
            wares[k].price = max(3, Int((Double(wares[k].price) * 0.8).rounded()))
            mapMsg = who + ": \"Alright, \(wares[k].price) and it's yours.\""
            events.append(1)
        } else {
            mapMsg = who + ": \"Sorry, that's firm.\""
            events.append(3)
        }
        mapMsgT = 3
    }

    private func buyWare(_ k: Int) {
        if wares[k].sold { return }
        if rocks >= packCap { mapMsg = "Your pack is full"; mapMsgT = 2; return }
        if Double(wares[k].price) > money { mapMsg = "Not enough coins"; mapMsgT = 2; return }
        money -= Double(wares[k].price)
        events.append(6)
        rockVals.append(Int(rnd(Double(wares[k].lo), Double(wares[k].hi))))
        wares[k].sold = true
        if !seen.contains(34 + shop) { seen.insert(34 + shop); cred += 1 }
        events.append(1)
    }

    private func play(_ dt: Double) {
        let before = dayT
        if !clockFreeze { dayT += dt / DAYLEN }
        if dayT >= 1 { dayT -= 1; dawn() }
        // no solar yet: the generator comes on at dusk to keep the lights on
        if !inPast && before < 0.64 && dayT >= 0.64 && rigArea != .main && rigArea != .tyson && rig != .tent && panels == 0 && !resident && !house {
            genOn = true
            hint("gen", "No solar yet, so your generator runs in the evening. Shut it off at your camp before 10 PM. Quiet hours run until 6 AM. Solar panels at K&B Tools mean no generator at all.")
        }
        if genOn && dayT < 0.3 { genOn = false }
        if genOn && quietHours && genMadDay != day && rigHere {
            genMadDay = day
            cred = max(0, cred - 2)
            madT = 4; madX = rigX + 70; madText = "It's after ten! Shut that generator off!"
            float("-2 cred", rigX, REDC)
        } else if genOn && quietHours && genMadDay != day {
            genMadDay = day
            cred = max(0, cred - 2)
            hintT = 0
            hint("genaway\(day)", "Your generator ran past 10 PM while you were away. The neighbors are not happy.  -2 cred")
        }
        health = max(0, health - dt * 100 / (DAYLEN * 2.2) * (weather == 1 ? 1.3 : 1))
        if health < 35 && inPast { hint("hungrypast", "You're run down, and there's no grocery for a thousand years. Open the map and return to 2026.") }
        else if health < 35 { hint("hungry", "You're run down. Groceries on Main Street, the outhouse and your own camp all help.") }

        // moving: on foot, on a ride, or behind the wheel
        var s = abs(input.stick) < 0.15 ? 0 : input.stick
        if overlay || input.hold || arriveT > 0 || s != 0 { moveTarget = nil }
        if let t = moveTarget {
            let d = t - px
            let wheels = inRig || onToy
            if abs(d) < (wheels ? 6 : 2.5) { moveTarget = nil }
            else if wheels { s = clampD(d / 46, -1, 1); if abs(s) < 0.3 { s = d > 0 ? 0.3 : -0.3 } }
            else { s = d > 0 ? 1 : -1 }
        }
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
        cam += (clampD(px - W / ZOOM / 2, 0, max(0, WORLD - W / ZOOM)) - cam) * min(1, dt * 6)

        // dust: a motor ride going fast on the dirt throws a cloud over everyone's camp
        let motor = onToy && toy >= 2 && toy < TOYS.count
        let dirtRoad = area != .main && area != .tyson
        dustAmt += ((motor && dirtRoad ? min(1, abs(vx) / TOYS[max(0, toy)].speed) : 0) - dustAmt) * min(1, dt * 3)
        if dustCool > 0 { dustCool -= dt }
        if madT > 0 { madT -= dt }
        if motor && dirtRoad && area != .trail && abs(vx) > TOYS[toy].speed * 0.65 {
            speedT += dt
            var near: Double? = nil
            for sp in spots where [SpotKind.fire, .circle, .host, .booth, .skoolie, .radio, .cleanup].contains(sp.kind) && abs(sp.x - px) < 110 { near = sp.x }
            if partyDay == day && partyArea == area && dayT > 0.5 && hour() < 22 && abs(partyX - px) < 170 { near = partyX }
            if dustCool <= 0 && (near != nil || speedT > 3.5) {
                dustCool = 9; speedT = 0
                cred = max(0, cred - 1)
                madT = 3.5
                madX = near ?? (px - face * 70)
                madText = ["Slow down! You're dusting our camp!", "Hey! Our dinner's full of dust now!", "Slow it down, buddy! People live here!", "Thanks a lot. Now I have to wipe the solar panels."][Int.random(in: 0..<4)]
                float("-1 cred", px, REDC)
                events.append(6)
                hint("dust", "Riding fast past camps throws dust over everyone. Ease off around camps and people stay friendly.")
            }
        } else {
            speedT = max(0, speedT - dt)
        }
        nearRig = rigHere && (inRig || abs(px - rigX) < RIGS[rig.rawValue].len / 2 + 22)
        nearToy = toy >= 0 && toyHere && !inRig && (onToy || abs(px - toyX) < TOYS[toy].len / 2 + 18)

        // wild burros nearby make a good post, once a day
        if page && !seen.contains(20) && (area == .dome || area == .trail || area == .scaddan) && (dayT < 0.6 || dayT > 0.95) && abs(px - herdX()) < 50 {
            seen.insert(20)
            post("wild burros", 45)
        }

        // no wheels past the fence at the intaglios: tire tracks are what the fences are for
        if area == .intaglios && !inPast && (onToy || inRig) && px > 560 {
            px = 556; vx = 0
            if !seen.contains(37) { seen.insert(37); trespass("No vehicles past the fence! Park here and walk!", 2) }
        }
        // which spot is in reach
        var best = -1
        var bd = 30.0
        for (i, sp) in spots.enumerated() {
            // Gem World is a long building: anywhere along its front counts
            let d = sp.kind == .gemworld ? max(0, abs(px - sp.x) - 110) : abs(px - sp.x)
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
            float("Not enough coins", px, REDC)
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
