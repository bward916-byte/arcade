import Foundation

enum Mode { case title, island }

/// Broadside, native. This first slice is the opening of the game: the pier, the beach and the market,
/// with walking, fishing, selling and the coin-pour upgrades. Rules ported from broadside/index.html.
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
    var tod = 0.32
    var day = 1
    var camX = -100.0
    var camS = 1.0
    var baseY = 300.0
    let DAY_LEN = 100.0
    let XMIN = -236.0
    let XMAX = 1380.0

    // the player
    var px = -150.0
    var tx = -150.0
    var face = 1.0
    var speed = 0.0
    var walkPh = 0.0
    var coins = 0
    var fish = 0
    var rod = false
    var bait = false
    var cart = false
    var boat = false

    // fishing
    var fishing = false
    var fishPhase = 0
    var fishT = 0.0
    var fishWait = 2.5
    var capShow = 0.0

    // pouring coins
    let upgs: [Upg] = [Upg(id: "rod", x: -120, cost: 12), Upg(id: "bait", x: -40, cost: 18), Upg(id: "boat", x: 330, cost: 60), Upg(id: "cart", x: 930, cost: 30)]
    var paid: [String: Int] = [:]
    var pour: String?
    var pourAcc = 0.0
    var rings: [Ring] = []

    var log = ""
    var logT = 0.0
    var sparks: [Spark] = []
    var saveT = 0.0
    var titleBtn: (Double, Double, Double, Double) = (0, 0, 0, 0)

    var light: Double { return clampD(0.5 + 0.9 * sin((tod - 0.23) * 2 * PI), 0, 1) }
    var fishCap: Int { return cart ? 12 : 5 }

    init() { load() }

    // ---------- the lie of the land (world y is negative upward; the sea is at 0)
    func ground(_ x: Double) -> Double {
        if x < 0 { return -22 }
        if x < 60 { return lerp(-22, -6, smooth(x / 60)) }
        if x < 600 { return -6 - (x - 60) / 540 * 10 }
        if x < 900 { return lerp(-16, -72, smooth((x - 600) / 300)) }
        return -72 - min(14, (x - 900) / 500 * 14)
    }
    func wave(_ x: Double) -> Double {
        return sin(x * 0.02 + T * 1.2) * 1.6 + sin(x * 0.007 - T * 0.7) * 1.2
    }
    func sx(_ x: Double) -> Double { return (x - camX) * camS + W / 2 }
    func sy(_ y: Double) -> Double { return y * camS + baseY }

    func say(_ s: String) { log = s; logT = 4 }

    func done(_ id: String) -> Bool {
        switch id {
        case "rod": return rod
        case "bait": return bait
        case "cart": return cart
        case "boat": return boat
        default: return false
        }
    }
    func apply(_ id: String) {
        switch id {
        case "rod": rod = true; say("A proper rod. The fish come quicker.")
        case "bait": bait = true; say("Fresh bait. Quicker still.")
        case "cart": cart = true; say("A fish cart: carry twelve to market.")
        case "boat": boat = true; say("A rowboat of your own. The start of a fleet.")
        default: break
        }
        snd?.good()
        buzz?(true)
        let wx = upgs.first(where: { $0.id == id })?.x ?? px
        for _ in 0..<18 {
            sparks.append(Spark(x: wx + rnd(-20, 20), y: ground(wx) - rnd(30, 60), vx: rnd(-30, 30), vy: rnd(-50, -15), life: 0, max: rnd(0.7, 1.3), r: 1.4, c: Col(0xffe082), grav: 60))
        }
        save()
    }
    func refund(_ id: String) {
        let n = paid[id] ?? 0
        if n > 0 && !done(id) { coins += n; paid[id] = 0 }
    }

    // ---------- time
    func update(_ dt: Double) {
        T += dt
        if mode == .title { return }
        tod += dt / DAY_LEN
        if tod >= 1 { tod -= 1; day += 1; say("A new day on the island.") }
        if logT > 0 { logT -= dt }
        if capShow > 0 { capShow -= dt }

        // walking
        let d = tx - px
        let want = abs(d) > 3 ? sgn(d) * min(62.0, 20 + abs(d) * 1.4) : 0.0
        speed = lerp(speed, want, min(1, dt * 9))
        if abs(speed) > 2 {
            px = clampD(px + speed * dt, XMIN, XMAX)
            face = sgn(speed)
            walkPh += dt * abs(speed) * 0.19
            if fishing { fishing = false; say("Line in.") }
        } else if fishing {
            face = -1
        }

        // fishing: wait for the bite, then the fight, then the catch
        if fishing {
            fishT += dt
            if fishPhase == 0 && fishT > fishWait {
                fishPhase = 1; fishT = 0
                snd?.splash(); buzz?(false)
            } else if fishPhase == 1 && fishT > 1.3 {
                fish += 1
                capShow = 2.6
                snd?.coin()
                for _ in 0..<10 {
                    sparks.append(Spark(x: -262 + rnd(-6, 6), y: -2, vx: rnd(-26, 26), vy: rnd(-70, -30), life: 0, max: rnd(0.5, 0.9), r: 1.6, c: Col(0xe6f6ff), grav: 160))
                }
                if fish >= fishCap {
                    fishing = false
                    say("Hold full. Sell at the market in town.")
                } else {
                    fishPhase = 0; fishT = 0
                    fishWait = rnd(1.5, 4) * (rod ? 0.6 : 1) * (bait ? 0.7 : 1) * (boat ? 0.8 : 1)
                }
            }
        }

        // pouring coins into a circle
        if let id = pour, let u = upgs.first(where: { $0.id == id }) {
            pourAcc += dt
            while pourAcc > 0.07 && pour != nil {
                pourAcc -= 0.07
                let have = paid[id] ?? 0
                if have >= u.cost {
                    pour = nil
                } else if coins <= 0 {
                    refund(id); pour = nil
                    say("Not enough coins yet.")
                    snd?.bad()
                } else {
                    coins -= 1
                    paid[id] = have + 1
                    snd?.tone(1250 + Double(min(900, have * 28)), 0.09, 1, 0.08)
                    if have + 1 >= u.cost { pour = nil; apply(id) }
                }
            }
            if abs(u.x - px) > 70 { refund(id); pour = nil }
        }

        // the camera keeps your feet at the same height on screen
        camS = min(W / 560, H / 330) * 1.25
        camX = lerp(camX, px + face * 46, min(1, dt * 2.5))
        let wantBase = H * 0.78 - ground(px) * camS
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

        saveT += dt
        if saveT > 4 { saveT = 0; save() }
    }

    // ---------- touch
    func touchDown(_ x: Double, _ y: Double) {
        if mode == .title {
            mode = .island
            camX = px + 46
            camS = min(W / 560, H / 330) * 1.25
            baseY = H * 0.78 - ground(px) * camS
            snd?.good()
            if day == 1 && coins == 0 && fish == 0 { say("Tap the ground to walk. Circles appear when you are near something.") }
            return
        }
        for r in rings {
            let dx = x - r.x, dy = y - r.y
            if dx * dx + dy * dy <= (r.r + 8) * (r.r + 8) {
                if r.pour {
                    if coins <= 0 { say("No coins yet. Sell fish at the market."); snd?.bad(); return }
                    pour = r.id; pourAcc = 0.07
                } else {
                    act(r.id)
                }
                return
            }
        }
        tx = clampD((x - W / 2) / camS + camX, XMIN, XMAX)
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
        if id == "fish" {
            if fishing { fishing = false; say("Line in."); return }
            if fish >= fishCap { say("Hold full. Sell at the market first."); capShow = 2.6; return }
            fishing = true; fishPhase = 0; fishT = 0
            fishWait = rnd(1.5, 4) * (rod ? 0.6 : 1) * (bait ? 0.7 : 1)
            tx = px
            say("Line out.")
        } else if id == "market" {
            if fish <= 0 { say("Nothing to sell. Fish off the end of the pier."); return }
            let g = fish * 4
            coins += g
            fish = 0
            say("Sold the catch: +" + String(g) + " coins.")
            snd?.coin()
            buzz?(false)
            for _ in 0..<12 {
                sparks.append(Spark(x: px + rnd(-8, 8), y: ground(px) - 40, vx: rnd(-30, 30), vy: rnd(-60, -20), life: 0, max: rnd(0.6, 1.0), r: 1.5, c: Col(0xffd24a), grav: 120))
            }
            save()
        }
    }

    // ---------- keeping the game
    func save() {
        let d = UserDefaults.standard
        d.set(coins, forKey: "bs.coins"); d.set(fish, forKey: "bs.fish"); d.set(day, forKey: "bs.day")
        d.set(rod, forKey: "bs.rod"); d.set(bait, forKey: "bs.bait"); d.set(cart, forKey: "bs.cart"); d.set(boat, forKey: "bs.boat")
        d.set(px, forKey: "bs.px"); d.set(true, forKey: "bs.saved")
    }
    func load() {
        let d = UserDefaults.standard
        if !d.bool(forKey: "bs.saved") { return }
        coins = d.integer(forKey: "bs.coins"); fish = d.integer(forKey: "bs.fish"); day = max(1, d.integer(forKey: "bs.day"))
        rod = d.bool(forKey: "bs.rod"); bait = d.bool(forKey: "bs.bait"); cart = d.bool(forKey: "bs.cart"); boat = d.bool(forKey: "bs.boat")
        px = clampD(d.double(forKey: "bs.px"), XMIN, XMAX); tx = px
    }

    /// Jump straight to a part of the game, for the build's screenshots.
    func demo(_ name: String) {
        mode = .island
        coins = 34; fish = 2; rod = true; day = 3
        switch name {
        case "pier": px = -150
        case "fish": px = -215; fishing = true; fishPhase = 1; fishT = 0.4; face = -1; coins = 6
        case "town": px = 985; tod = 0.4; fish = 4
        case "night": px = -60; tod = 0.9; boat = true
        default: px = -150
        }
        tx = px
        camS = min(W / 560, H / 330) * 1.25
        camX = px + 46
        baseY = H * 0.78 - ground(px) * camS
    }
}
