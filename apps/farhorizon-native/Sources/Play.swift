import CoreGraphics
import Foundation

// The hands-on part of an event at sea. Three kinds:
//   timing — a marker swings along a bar; tap as it crosses the middle
//   taps   — trouble springs up around the ship; tap each before it is too late
//   pick   — a row of crates, mounds or hatches; open a few and see what is inside

final class Play {
    enum Kind { case timing, taps, pick, hold, steer, swipe, beat, reel }
    let kind: Kind
    let theme: String      // storm, run, fish, line, leak, fog, wreck, island, ghost
    let title: String
    let hint: String
    // timing
    var rounds = 3
    var tries = 0
    var score = 0
    var perfect = 0
    var marks: [Int] = []  // 0 miss, 1 hit, 2 perfect
    var zone = 0.26
    var speed = 1.1
    var pos = 0.05
    var dir = 1.0
    var stopOnHit = false
    // taps
    var targets: [(x: Double, y: Double, age: Double, life: Double, state: Int, gold: Bool)] = []
    var spawnT = 0.7
    var spawned = 0
    var total = 6
    var life = 1.5
    var missed = 0
    // pick
    var spots: [Int] = []
    var open: [Double] = []
    var picksLeft = 3
    var found: [Int] = []
    /// one crate with something in it glints for a moment at the start: a clue for sharp eyes
    var tell = -1
    var tellHold = false
    // the how-to card shown before the game starts
    var intro = false
    var introT = 0.0
    // the newer kinds (Play2.swift): two dials, a pause between rounds, a finger held, what is coming
    var a = 0.0
    var b = 0.0
    var v = 0.0
    var tb = 0.0
    var fade = 0.3
    var wait = 0.0
    var held = false
    var cur = 0
    var obst: [(x: Double, y: Double, w: Double, done: Bool)] = []
    // watch, then repeat
    var seq: [Int] = []
    var seqI = 0
    var phase = 0
    var known = false
    var lastTap = -1
    var lastTapT = 0.0
    // shared
    var t = 0.0
    var msg = ""
    var msgT = 0.0
    var msgGood = true
    var endT = -1.0
    var endLen = 1.0
    var finished = false
    // the show: a streak counter, words that jump off the screen, a flash on a perfect, the marker's trail
    var streak = 0
    var bestStreak = 0
    var pops: [(x: Double, y: Double, t: Double, s: String, good: Bool, big: Bool)] = []
    var flash = 0.0
    var trail: [Double] = []
    var starsShown = 0
    /// How well it went, out of three, for the banner at the end.
    func stars() -> Int {
        switch kind {
        case .timing, .hold, .beat, .reel:
            if stopOnHit { return score > 0 ? (perfect > 0 ? 3 : 2) : 0 }
            let r = Double(score) / Double(max(1, rounds))
            return r >= 1 ? (perfect * 2 >= rounds ? 3 : 2) : (r >= 0.5 ? 1 : 0)
        case .taps, .steer, .swipe:
            let r = Double(score) / Double(max(1, total))
            return r >= 1 ? 3 : (r >= 0.67 ? 2 : (r >= 0.34 ? 1 : 0))
        case .pick:
            return -1
        }
    }
    func pop(_ x: Double, _ y: Double, _ s: String, _ good: Bool, big: Bool = false) { pops.append((x, y, 0, s, good, big)) }
    let finish: (Play) -> Void

    init(_ kind: Kind, _ theme: String, _ title: String, _ hint: String, _ finish: @escaping (Play) -> Void) {
        self.kind = kind; self.theme = theme; self.title = title; self.hint = hint; self.finish = finish
    }
    func say(_ s: String, _ good: Bool) { msg = s; msgT = 1.1; msgGood = good }
}

/// What can lie under a spot: 0 nothing, 1 some gold, 2 a hoard, 3 stores, 4 planks, 5 powder, 6 water, 7 trouble, 8 a map
let SPOT_NAMES = ["Empty", "Gold", "Treasure!", "Stores", "Planks", "Powder", "Stores", "Trouble!", "A map"]

extension Game {
    func startPlay(_ p: Play) {
        card = nil
        play = p
        armIntro(p)
        if mode == .port { evTitle = p.title }
        snd?.whoosh()
    }
    /// Where the ship sits on the sailing screen: middle of the waterline and her length.
    func shipSpot() -> (Double, Double, Double) {
        let hz = H * 0.5
        return (W * 0.42, hz + (H - hz) * 0.5, min(W * 0.3, 280) * ship.len)
    }

    func updatePlay(_ dt: Double) {
        guard let p = play else { return }
        if p.intro { p.introT += dt; return }
        p.t += dt
        p.msgT = max(0, p.msgT - dt)
        p.flash = max(0, p.flash - dt)
        for i in 0..<p.pops.count { p.pops[i].t += dt }
        p.pops.removeAll { $0.t > 1.1 }
        if p.endT >= 0 && p.kind != .pick {
            let el = p.endLen - p.endT
            let st = p.stars()
            if p.starsShown < st && el > 0.25 + Double(p.starsShown) * 0.22 {
                p.starsShown += 1
                snd?.coin()
                buzz?(false)
            }
        }
        // the sea keeps moving behind the game
        tod = (tod + dt / DAYLEN * 0.05).truncatingRemainder(dividingBy: 1)
        scroll += dt * (mode == .port || p.theme == "wreck" || p.theme == "island" || p.theme == "ghost" ? 8 : 70 * ship.speed)
        if p.endT >= 0 {
            p.endT -= dt
            if p.endT < 0 && !p.finished {
                p.finished = true
                play = nil
                p.finish(p)
            }
            return
        }
        switch p.kind {
        case .timing:
            p.pos += p.dir * p.speed * dt
            p.trail.append(p.pos)
            if p.trail.count > 9 { p.trail.removeFirst() }
            if p.pos > 1 { p.pos = 1; p.dir = -1 }
            if p.pos < 0 { p.pos = 0; p.dir = 1 }
        case .taps:
            p.spawnT -= dt
            if p.spawned < p.total && p.spawnT <= 0 {
                let (sx, wy, len) = shipSpot()
                var x = 0.0, y = 0.0
                if p.theme == "leak" {
                    x = sx + rnd(-0.4, 0.34) * len
                    y = wy - rnd(0.01, 0.085) * len
                } else if p.theme == "thief" || p.theme == "rats" {
                    x = rnd(W * 0.46, W - safeR - 40)
                    y = quayY() - (p.theme == "thief" ? 14 : 4)
                } else if p.theme == "fire" {
                    x = rnd(W * 0.44, W - safeR - 40)
                    y = quayY() - rnd(26, 58)
                } else if p.theme == "flyfish" || p.theme == "gulls" {
                    x = sx + rnd(-0.45, 0.5) * len
                    y = wy - rnd(0.22, 0.62) * len
                } else {
                    x = rnd(W * 0.6, W - safeR - 50)
                    y = rnd(wy - 6, H - safeB - 40)
                }
                // now and then a quick golden one, worth a little prize
                let gold = p.spawned > 0 && chance(0.18)
                p.targets.append((x, y, 0, p.life * (gold ? 0.75 : 1), 0, gold))
                p.spawned += 1
                // they come faster as it goes on
                p.spawnT = rnd(0.45, 0.85) * (1 - 0.35 * Double(p.spawned) / Double(max(1, p.total)))
                if p.theme == "leak" { snd?.splash() }
            }
            var open = 0
            for i in 0..<p.targets.count {
                p.targets[i].age += dt
                if p.targets[i].state == 0 {
                    if p.targets[i].age > p.targets[i].life {
                        p.targets[i].state = 2
                        p.targets[i].age = 0
                        p.missed += 1
                        p.streak = 0
                        p.pop(p.targets[i].x, p.targets[i].y - 26, "Missed", false)
                        shake = 0.25
                        snd?.thud()
                        buzz?(true)
                        p.say(p.theme == "leak" ? "She's taking water!" : (p.theme == "thief" ? "He ducks away!" : (p.theme == "rats" ? "Into the stores!" : (p.theme == "fire" ? "It has the roof!" : (p.theme == "shark" ? "It hits the raft!" : (p.theme == "flyfish" ? "Over the side!" : (p.theme == "gulls" ? "It got a fish!" : (p.theme == "gleam" ? "Sunk!" : "Struck a rock!"))))))), false)
                    } else {
                        open += 1
                    }
                }
            }
            if p.spawned >= p.total && open == 0 { p.endT = 1.6; p.endLen = 1.6 }
        case .pick:
            updateMemory(p)
            for i in 0..<p.open.count where p.open[i] >= 0 { p.open[i] += dt }
        case .hold, .steer, .swipe, .beat, .reel:
            updatePlay2(p, dt)
        }
    }

    func tapPlay(_ x: Double, _ y: Double) {
        guard let p = play, p.endT < 0 else { return }
        if p.intro { p.intro = false; snd?.click(); return }
        let (qx, qy) = helpSpot()
        if abs(x - qx) < 24 && abs(y - qy) < 24 { p.intro = true; p.introT = 0; snd?.click(); return }
        let (sx, wy, len) = shipSpot()
        switch p.kind {
        case .timing:
            let d = abs(p.pos - 0.5)
            p.tries += 1
            if d < p.zone / 2 {
                p.score += 1
                let perfect = d < p.zone / 6
                if perfect { p.perfect += 1 }
                p.marks.append(perfect ? 2 : 1)
                p.streak += 1
                p.bestStreak = max(p.bestStreak, p.streak)
                let barY = H - safeB - 58
                if perfect {
                    p.flash = 0.35
                    shake = max(shake, 0.12)
                    p.pop(W / 2, barY - 40, "PERFECT!", true, big: true)
                } else {
                    p.pop(W / 2, barY - 34, "Good", true)
                }
                if p.streak >= 2 { p.pop(W / 2 + 120, barY - 18, "\(p.streak) in a row!", true) }
                snd?.good()
                buzz?(false)
                puff(W / 2, H - safeB - 60, perfect ? 26 : 14, Col(0xffe08a), 220, 300, 2.6, 0.5)
                switch p.theme {
                case "storm": p.say(perfect ? "Dead on the wave!" : "She rides over it", true)
                case "run": p.say(perfect ? "Every stitch drawing!" : "The sails fill", true)
                case "fish": p.say(perfect ? "A big one!" : "Hooked!", true); snd?.splash(); puff(sx - len * 0.45, wy + 2, 16, Col(0xffffff, 0.9), 160, 300, 2.4, 0.5)
                case "dock": p.say(perfect ? "Stowed like a master!" : "Aboard she goes", true); snd?.coin()
                case "row": p.say(perfect ? "All together. She moves!" : "A good stroke", true); snd?.splash()
                case "strong": p.say(perfect ? "The bell rings clean off its post!" : "The bell rings!", true); snd?.bell()
                default: p.say("He has the line!", true)
                }
            } else {
                p.marks.append(0)
                p.streak = 0
                p.pop(W / 2 + (p.pos - 0.5) * min(W * 0.62, 480), H - safeB - 92, p.pos < 0.5 ? "Too soon" : "Too late", false)
                snd?.thud()
                buzz?(true)
                switch p.theme {
                case "storm": p.say("A sea breaks over the rail!", false); shake = 0.35; puff(sx, wy - len * 0.2, 30, Col(0xffffff, 0.85), 260, 320, 3, 0.7); snd?.splash()
                case "run": p.say("The canvas flogs", false)
                case "fish": p.say("It slipped the hook", false)
                case "dock": p.say("The load swings wide!", false)
                case "row": p.say("The oars clash", false)
                case "strong": p.say("Not even halfway", false)
                default: p.say("The line falls short", false); snd?.splash()
                }
            }
            p.speed *= 1.1
            p.pos = chance(0.5) ? 0.02 : 0.98
            p.dir = p.pos < 0.5 ? 1 : -1
            if p.tries >= p.rounds || (p.stopOnHit && p.score > 0) { p.endT = 1.6; p.endLen = 1.6 }
        case .taps:
            var best = -1
            var bd = 52.0
            for (i, tg) in p.targets.enumerated() where tg.state == 0 {
                let d = ((tg.x - x) * (tg.x - x) + (tg.y - y) * (tg.y - y)).squareRoot()
                if d < bd { bd = d; best = i }
            }
            if best >= 0 {
                p.targets[best].state = 1
                p.targets[best].age = 0
                p.score += 1
                p.streak += 1
                p.bestStreak = max(p.bestStreak, p.streak)
                let tq = p.targets[best]
                // quicker taps earn a louder cheer
                if tq.gold {
                    gold += 5
                    snd?.coin()
                    p.pop(tq.x, tq.y - 34, "Quick hands! +5 gold", true, big: true)
                } else {
                    p.pop(tq.x, tq.y - 30, "+1", true)
                }
                if p.streak >= 3 { p.pop(tq.x, tq.y - 52, "\(p.streak) in a row!", true, big: p.streak >= 5) }
                for j in 0..<10 {
                    let a = Double(j) / 10 * PI * 2
                    p.pops.append((tq.x + cos(a) * 4, tq.y + sin(a) * 4, 0, "•", true, false))
                }
                buzz?(false)
                if p.theme == "leak" { snd?.thud(); puff(p.targets[best].x, p.targets[best].y, 10, Col(0xc9a86a), 120, 260, 2.4, 0.4) } else { snd?.good(); puff(p.targets[best].x, p.targets[best].y, 12, Col(0xffffff, 0.9), 150, 260, 2.2, 0.4) }
            }
        case .hold, .steer, .swipe, .beat, .reel:
            tapPlay2(p, x, y)
        case .pick:
            if p.picksLeft <= 0 { return }
            if tapMemory(p, x, y) { return }
            let r = pickRects(p)
            for (i, q) in r.enumerated() where p.open[i] < 0 && x >= q.0 && x <= q.0 + q.2 && y >= q.1 - 10 && y <= q.1 + q.3 + 10 {
                p.open[i] = 0
                p.picksLeft -= 1
                let what = p.spots[i]
                p.found.append(what)
                buzz?(what == 7)
                let cx = q.0 + q.2 / 2, cy = q.1 + q.3 / 2
                switch what {
                case 1, 2: snd?.coin(); puff(cx, cy, what == 2 ? 40 : 18, Col(0xffd257), 240, 340, 3, 0.8); if what == 2 { snd?.good() }
                case 7: snd?.bad(); shake = 0.3; puff(cx, cy, 18, Col(0xff5a3c), 200, 300, 2.6, 0.5)
                case 0: snd?.thud(); puff(cx, cy, 8, Col(0xd8c49a), 110, 260, 2.2, 0.4)
                default: snd?.good(); puff(cx, cy, 14, Col(0xfff1cf), 160, 300, 2.4, 0.5)
                }
                let word = what == 7 ? "Trouble!" : (what == 0 ? "Empty..." : (what == 2 ? "TREASURE!" : SPOT_NAMES[what] + "!"))
                p.pop(cx, q.1 - 10, word, what != 7 && what != 0, big: what == 2 || what == 8)
                if what == 2 { p.flash = 0.4 }
                if what != 0 && what != 7 {
                    let n = what == 2 ? 20 : 10
                    for j in 0..<n {
                        let a = Double(j) / 10 * PI * 2, r = j < 10 ? 4.0 : 9.0
                        p.pops.append((cx + cos(a) * r, cy + sin(a) * r, 0, "•", true, false))
                    }
                }
                if p.picksLeft <= 0 { p.endT = 1.7 }
                break
            }
        }
    }

    func pickRects(_ p: Play) -> [(Double, Double, Double, Double)] {
        let n = p.spots.count
        let gap = 10.0
        let w = min(98.0, (W - safeL - safeR - 40 - gap * Double(n - 1)) / Double(n))
        let h = 100.0
        let total = w * Double(n) + gap * Double(n - 1)
        let x0 = (W - total) / 2, y = H - safeB - h - 34
        var out: [(Double, Double, Double, Double)] = []
        for i in 0..<n { out.append((x0 + Double(i) * (w + gap), y, w, h)) }
        return out
    }

    /// The little picture for what was found under a spot.
    func spotIcon(_ c: Canvas, _ what: Int, _ x: Double, _ y: Double, _ s: Double) {
        switch what {
        case 1: icon(c, "gold", x, y, s)
        case 2:
            // an open chest
            c.RR(x - s * 0.5, y - s * 0.1, s, s * 0.55, 3, Col(0x6b4423))
            c.R(x - s * 0.5, y - s * 0.1, s, s * 0.1, Col(0xd9a441))
            c.arcFill(x, y - s * 0.1, s * 0.5, PI, PI * 2, Col(0x8a5a2c))
            c.ell(x, y - s * 0.12, s * 0.42, s * 0.14, Col(0xffd257))
            c.glow(x, y - s * 0.2, s * 0.9, Col(0xffe08a, 0.6), Col(0xffe08a, 0))
        case 3: icon(c, "food", x, y, s)
        case 4: icon(c, "planks", x, y, s)
        case 5: icon(c, "powder", x, y, s)
        case 6: icon(c, "water", x, y, s)
        case 7:
            // a crab, claws up
            c.ell(x, y + s * 0.1, s * 0.36, s * 0.24, Col(0xd8432f))
            c.circ(x - s * 0.42, y - s * 0.2, s * 0.14, Col(0xd8432f)); c.circ(x + s * 0.42, y - s * 0.2, s * 0.14, Col(0xd8432f))
            c.seg(x - s * 0.3, y, x - s * 0.42, y - s * 0.16, 2, Col(0xd8432f)); c.seg(x + s * 0.3, y, x + s * 0.42, y - s * 0.16, 2, Col(0xd8432f))
            c.circ(x - s * 0.1, y - s * 0.1, 1.6, WHITE); c.circ(x + s * 0.1, y - s * 0.1, 1.6, WHITE)
        case 8:
            c.RR(x - s * 0.45, y - s * 0.32, s * 0.9, s * 0.64, 3, Col(0xe8d6a0))
            c.dash(3, 3)
            c.curve(x - s * 0.3, y + s * 0.15, x, y - s * 0.3, x + s * 0.22, y + s * 0.05, 1.4, Col(0x6b4a26))
            c.noDash()
            c.seg(x + s * 0.16, y, x + s * 0.3, y + s * 0.14, 2, REDC); c.seg(x + s * 0.3, y, x + s * 0.16, y + s * 0.14, 2, REDC)
        default:
            c.seg(x - s * 0.2, y - s * 0.2, x + s * 0.2, y + s * 0.2, 2, Col(0x8a7a5a)); c.seg(x + s * 0.2, y - s * 0.2, x - s * 0.2, y + s * 0.2, 2, Col(0x8a7a5a))
        }
    }

    func drawPlayBody(_ c: Canvas) {
        guard let p = play else { return }
        let (sx, wy, len) = shipSpot()
        // what is going on, in a strip under the top bar
        let bw = min(W * 0.62, 520), bx = (W - bw) / 2, by = 36.0
        let slide = min(1, p.t / 0.3)
        let ease = 1 - (1 - slide) * (1 - slide)
        c.save()
        c.translate(0, -50 * (1 - ease))
        c.RR(bx + 2, by + 3, bw, 50, 12, Col(0x000000, 0.35))
        c.RRGrad(bx, by, bw, 50, 12, [(0, Col(0x3a2412, 0.95)), (1, Col(0x24150a, 0.95))])
        c.RRStroke(bx, by, bw, 50, 12, 1.8, Col(0xd2a455))
        c.text(p.title, W / 2, by + 21, 19, GOLD, 0, FONTD)
        c.text(p.hint, W / 2, by + 41, 14, CREAM, 0, FONT)
        c.restore()

        switch p.kind {
        case .timing:
            if p.theme == "fish" {
                // lines over the stern
                for i in 0..<3 {
                    let lx = sx - len * (0.3 + Double(i) * 0.08)
                    c.curve(lx, wy - len * 0.2, lx - 20, wy - len * 0.05, lx - 34 - Double(i) * 8, wy + 14 + sin(T * 2 + Double(i)) * 3, 1, Col(0xfff6d8, 0.8))
                    c.circ(lx - 34 - Double(i) * 8, wy + 14 + sin(T * 2 + Double(i)) * 3, 2.5, REDC)
                }
            }
            if p.theme == "line" {
                // the man in the water
                let mx = sx - len * 0.75, my = wy + 22 + sin(T * 3) * 3
                c.ellStroke(mx, my + 4, 16 + sin(T * 4) * 3, 4, 1.2, Col(0xffffff, 0.6))
                c.circ(mx, my - 4, 5, Col(0xe3b58a))
                c.seg(mx - 3, my, mx - 10, my - 12 + sin(T * 9) * 3, 2.2, Col(0xe3b58a)); c.seg(mx + 3, my, mx + 10, my - 12 - sin(T * 9) * 3, 2.2, Col(0xe3b58a))
            }
            if p.theme == "cask" {
                // the cask, bobbing off the quarter, and the boathook reaching for it
                let cx = sx - len * 0.7, cy = wy + 18 + sin(T * 2.2) * 3
                c.save(); c.translate(cx, cy); c.rotate(sin(T * 1.6) * 0.25)
                c.RR(-9, -7, 18, 14, 4, Col(0x8a6238)); c.R(-9, -3, 18, 1.4, Col(0x2a1a0c)); c.R(-9, 2, 18, 1.4, Col(0x2a1a0c))
                c.restore()
                c.ellStroke(cx, cy + 8, 20, 4, 1.2, Col(0xffffff, 0.55))
                let reach = (p.pos - 0.5) * 30
                c.seg(sx - len * 0.45, wy - len * 0.12, cx + reach, cy - 10, 1.6, Col(0x6b4a26))
            }
            if p.theme == "turtle" {
                // a big sea turtle paddling just under the surface off the quarter
                let cx = sx + len * 0.66 + sin(T * 0.6) * 14, cy = wy + 6 + sin(T * 1.8) * 2
                c.ell(cx, cy, 20, 11, Col(0x4a6a3a)); c.ell(cx - 2, cy - 2, 15, 7, Col(0x6a8a4a))
                for j in 0..<3 { c.ellStroke(cx - 8 + Double(j) * 7, cy - 2, 3.5, 2.5, 1, Col(0x3a5a2a)) }
                c.ell(cx + 22, cy - 1, 6, 4.5, Col(0x8aa06a)); c.circ(cx + 25, cy - 2.5, 1, Col(0x0c1014))
                let fl = sin(T * 3) * 4
                c.ell(cx + 10, cy + 10 + fl, 9, 3, Col(0x5a7a4a)); c.ell(cx - 12, cy + 10 - fl, 7, 2.5, Col(0x5a7a4a))
                c.ellStroke(cx, cy + 8, 30, 5, 1.2, Col(0xffffff, 0.5))
                let reach = (p.pos - 0.5) * 30
                c.curve(sx + len * 0.42, wy - len * 0.12, (sx + len * 0.42 + cx) / 2, wy - len * 0.2, cx + reach, cy - 16, 1.2, Col(0xd9cdb0))
                // the net swinging on the end of the line
                let nx = cx + reach, ny = cy - 9
                c.ellStroke(nx, ny, 13, 7, 1.4, Col(0xd9cdb0))
                for j in -2...2 { c.seg(nx + Double(j) * 5, ny - 6, nx + Double(j) * 5, ny + 6, 0.7, Col(0xd9cdb0, 0.7)) }
                c.seg(nx - 12, ny, nx + 12, ny, 0.7, Col(0xd9cdb0, 0.7))
            }
            if p.theme == "trim" {
                // the sail filling and spilling as the marker swings
                let fill = 1 - abs(p.pos - 0.5) * 2
                c.textS(fill > 0.7 ? "Drawing well" : "Luffing", W / 2 - min(W * 0.62, 480) / 2 + 50, H - safeB - 74, 13, fill > 0.7 ? Col(0x9ff0aa) : Col(0xffc8a0), 0, FONTB)
            }
            if p.theme == "run" {
                // the pirate, astern and gaining or falling back
                let gap = 0.16 - Double(p.score) * 0.05 + Double(p.tries - p.score) * 0.04
                drawShip(c, sx - len * 0.5 - W * max(0.02, gap), wy - 6, len * 0.62, 2, enemy: true)
            }
            let w = min(W * 0.62, 480), x = (W - w) / 2, y = H - safeB - 58, h = 26.0
            // one pip per try
            for i in 0..<p.rounds {
                let px = W / 2 + (Double(i) - Double(p.rounds - 1) / 2) * 22
                c.circ(px, y - 26, 7, Col(0x1c1108))
                let m = i < p.marks.count ? p.marks[i] : -1
                c.circ(px, y - 26, 5.2, m < 0 ? Col(0x000000, 0.4) : (m == 0 ? Col(0xe0402f) : (m == 2 ? Col(0xffe08a) : GREENC)))
            }
            c.RR(x - 4, y - 4, w + 8, h + 8, 16, Col(0x1c1108, 0.9))
            c.RRStroke(x - 4, y - 4, w + 8, h + 8, 16, 1.6, Col(0xd2a455))
            c.RRGrad(x, y, w, h, 12, [(0, Col(0x4a2f18)), (1, Col(0x2a1a0c))])
            let zw = w * p.zone
            let pulse = 0.75 + 0.25 * sin(T * 6)
            c.RRGrad(W / 2 - zw / 2, y, zw, h, 6, [(0, Col(0x7fd88a, pulse)), (1, Col(0x3a9a4c, pulse))])
            c.RR(W / 2 - zw / 6, y, zw / 3, h, 4, Col(0xffe08a, 0.95))
            // the zone lights up while the marker is in it
            let inZone = abs(p.pos - 0.5) < p.zone / 2
            if inZone && p.endT < 0 { c.RR(W / 2 - zw / 2 - 3, y - 3, zw + 6, h + 6, 8, Col(0xfff2a0, 0.35 + 0.25 * sin(T * 30))) }
            for i in 0..<10 { let tx = x + w * Double(i + 1) / 11; c.seg(tx, y + h - 5, tx, y + h - 1, 1, Col(0xffffff, 0.25)) }
            for (i, tp) in p.trail.enumerated() {
                let f = Double(i + 1) / Double(p.trail.count + 1)
                c.RR(x + w * tp - 2.5, y - 4, 5, h + 8, 2.5, Col(0xffffff, 0.22 * f))
            }
            let mx = x + w * p.pos
            c.glow(mx, y + h / 2, 30, Col(0xffffff, 0.5), Col(0xffffff, 0))
            c.RR(mx - 3.5, y - 7, 7, h + 14, 3.5, WHITE)
            c.poly(WHITE, [mx - 9, y - 14, mx + 9, y - 14, mx, y - 4])
            c.textS(p.endT < 0 ? (p.streak >= 2 ? "\(p.streak) in a row! Keep it going" : "Tap when the marker is in the middle") : "", W / 2, y + h + 22, 13, p.streak >= 2 ? Col(0xfff2a0) : CREAM, 0, FONTI)
        case .taps:
            for tg in p.targets {
                if tg.state == 0 {
                    let k = clampD(tg.age / tg.life, 0, 1)
                    if tg.gold {
                        let pr = 30 + sin(T * 12) * 3
                        c.circ(tg.x, tg.y, pr, Col(0xffd257, 0.18))
                        c.circStroke(tg.x, tg.y, pr, 2.4, Col(0xffe08a, 0.95))
                        for j in 0..<4 {
                            let a = T * 3 + Double(j) * PI / 2
                            c.circ(tg.x + cos(a) * pr, tg.y + sin(a) * pr, 2.6, Col(0xfff6d8))
                        }
                    }
                    if p.theme == "leak" {
                        // water jetting from a sprung plank
                        for j in 0..<5 {
                            let a = -PI / 2 + (Double(j) - 2) * 0.3 + sin(T * 13 + Double(j)) * 0.12
                            let l = 16 + 16 * k + sin(T * 17 + Double(j) * 2) * 4
                            c.seg(tg.x, tg.y, tg.x + cos(a) * l, tg.y + sin(a) * l * 0.8 + l * 0.25, 2.2, Col(0xbfe6ff, 0.9))
                        }
                        c.circ(tg.x, tg.y, 4, Col(0x0a0604))
                    } else if p.theme == "thief" {
                        // a hooded figure with a purse, looking for a gap in the crowd
                        let pop = min(1, tg.age / 0.15)
                        c.RR(tg.x - 7, tg.y - 4 - 20 * pop, 14, 24 * pop, 4, Col(0x23232c))
                        c.circ(tg.x, tg.y - 28 * pop, 7, Col(0x23232c)); c.circ(tg.x + 1, tg.y - 27 * pop, 4, Col(0xe3b58a))
                        c.circ(tg.x + 10, tg.y - 10 * pop, 4.5, Col(0xd9a441)); c.circ(tg.x + 10, tg.y - 10 * pop, 2, Col(0xfff2c0))
                    } else if p.theme == "shark" {
                        // a fin cutting in toward the raft
                        let dir = tg.x > W * 0.78 ? -1.0 : 1.0
                        let sxx = tg.x - dir * (1 - k) * 40
                        c.poly(Col(0x3a4650), [sxx - 11, tg.y + 4, sxx + 2 * dir, tg.y - 20, sxx + 11, tg.y + 4])
                        c.ellStroke(sxx, tg.y + 5, 18, 3, 1.2, Col(0xffffff, 0.6))
                        c.seg(sxx - dir * 12, tg.y + 5, sxx - dir * 34, tg.y + 7, 1, Col(0xffffff, 0.4))
                    } else if p.theme == "fire" {
                        // flames taking hold of a roof
                        for j in 0..<5 {
                            let ph = T * (6 + Double(j)) + Double(j) * 1.9
                            let fh = (14 + 12 * k) * (0.6 + 0.4 * sin(ph))
                            let fxx = tg.x + (Double(j) - 2) * 6
                            c.poly(Col(0xff6a20, 0.9), [fxx - 6, tg.y, fxx + sin(ph) * 3, tg.y - fh, fxx + 6, tg.y])
                            c.poly(Col(0xffd257, 0.9), [fxx - 3, tg.y, fxx, tg.y - fh * 0.55, fxx + 3, tg.y])
                        }
                        c.glow(tg.x, tg.y - 8, 40, Col(0xff8a30, 0.5), Col(0xff8a30, 0))
                        c.circ(tg.x + sin(T * 2) * 4, tg.y - 30 - k * 14, 6 + k * 6, Col(0x3a3a3a, 0.4))
                    } else if p.theme == "flyfish" {
                        // a silver fish skipping through the air over the deck, fins out like wings
                        c.save(); c.translate(tg.x, tg.y); c.scale(1.7, 1.7); c.translate(-tg.x, -tg.y)
                        let fx = tg.x + sin(tg.age * 5 + tg.y) * 6, fy = tg.y + cos(tg.age * 6 + tg.x) * 3
                        let dirn: Double = Int(tg.x) % 2 == 0 ? 1 : -1
                        c.ell(fx, fy, 9, 3.6, Col(0x9ec8e0)); c.ell(fx + dirn * 1, fy + 1, 7, 1.6, Col(0xe8f4fa))
                        c.poly(Col(0x6a9ab8), [fx - dirn * 8, fy, fx - dirn * 14, fy - 4, fx - dirn * 13, fy + 4])
                        let wf = sin(T * 26 + tg.x) * 4
                        c.poly(Col(0xcfe6f2, 0.9), [fx - dirn * 2, fy - 1, fx + dirn * 4, fy - 10 - wf, fx + dirn * 6, fy - 1])
                        c.circ(fx + dirn * 6, fy - 0.8, 0.9, Col(0x0c1014))
                        for j in 0..<3 { c.circ(fx - dirn * (14 + Double(j) * 5), fy + 2 + Double(j), 1, Col(0xbfe6ff, 0.6 - Double(j) * 0.18)) }
                        c.restore()
                    } else if p.theme == "gulls" {
                        // a gull coming down on the fish drying in the rigging, wings beating
                        c.save(); c.translate(tg.x, tg.y); c.scale(1.6, 1.6)
                        let dive = min(1, tg.age / tg.life)
                        let gy2 = -10 + dive * 10
                        let wf = sin(T * 18 + tg.x) * 6
                        c.ell(0, gy2, 7, 3, WHITE); c.circ(6, gy2 - 1.5, 2.6, WHITE)
                        c.poly(Col(0xffb040), [8, gy2 - 1.8, 12, gy2 - 0.8, 8, gy2 - 0.4]); c.circ(6.8, gy2 - 2.2, 0.6, Col(0x0c1014))
                        c.poly(Col(0xe6ecf0), [-2, gy2 - 1, -14, gy2 - 8 - wf, -4, gy2 + 1]); c.poly(Col(0xe6ecf0), [1, gy2 - 1, 8, gy2 - 12 - wf, 4, gy2])
                        c.poly(Col(0x3a3e44), [-14, gy2 - 8 - wf, -18, gy2 - 9 - wf, -12, gy2 - 6 - wf])
                        // the fish it is after
                        c.ell(0, 12, 6, 2.2, Col(0x9ab6c6)); c.poly(Col(0x7a96a6), [-6, 12, -10, 9.5, -10, 14.5])
                        c.restore()
                    } else if p.theme == "gleam" {
                        // something bright turning over in the swell
                        let rise = min(1, tg.age / 0.2)
                        c.ellStroke(tg.x, tg.y + 5, 18, 4, 1.2, Col(0xffffff, 0.5))
                        c.glow(tg.x, tg.y, 26 * rise, Col(0xffe08a, 0.7), Col(0xffe08a, 0))
                        let sp = 6 + 3 * sin(T * 9 + tg.x)
                        c.seg(tg.x - sp * rise, tg.y, tg.x + sp * rise, tg.y, 1.6, Col(0xfff8d0)); c.seg(tg.x, tg.y - sp * rise, tg.x, tg.y + sp * rise, 1.6, Col(0xfff8d0))
                        c.circ(tg.x, tg.y, 5, Col(0xffd257)); c.circ(tg.x - 1.5, tg.y - 1.5, 1.6, Col(0xfffbe0))
                    } else if p.theme == "rats" {
                        let rx = tg.x + sin(T * 14 + tg.x) * 3
                        c.ell(rx, tg.y, 10, 5.5, Col(0x5a5560)); c.circ(rx + 9, tg.y - 1, 4, Col(0x5a5560)); c.circ(rx + 10, tg.y - 5, 2, Col(0x8a8590))
                        c.curve(rx - 9, tg.y, rx - 18, tg.y - 6, rx - 22, tg.y + 2, 1.3, Col(0xc99a9a)); c.circ(rx + 11, tg.y - 1.5, 0.9, Col(0x000000))
                    } else {
                        // a rock breaking the surface
                        let rise = min(1, tg.age / 0.25)
                        c.ellStroke(tg.x, tg.y + 6, 26, 6, 1.4, Col(0xffffff, 0.55))
                        c.poly(Col(0x2e3238), [tg.x - 20, tg.y + 6, tg.x - 8, tg.y - 18 * rise, tg.x + 4, tg.y - 8 * rise, tg.x + 12, tg.y - 22 * rise, tg.x + 22, tg.y + 6])
                        c.poly(Col(0x4a5058), [tg.x - 8, tg.y - 18 * rise, tg.x + 4, tg.y - 8 * rise, tg.x - 2, tg.y + 6, tg.x - 14, tg.y + 6])
                    }
                    // the ring closes as time runs out
                    c.circStroke(tg.x, tg.y, 16 + 26 * (1 - k), 3, k > 0.65 ? Col(0xff5a3c) : Col(0xffd257))
                } else if tg.state == 1 && tg.age < 0.9 {
                    let a = 1 - tg.age / 0.9
                    if p.theme == "leak" {
                        c.RR(tg.x - 9, tg.y - 6, 18, 12, 2, Col(0xc9a86a, 0.5 + 0.5 * a))
                        c.circ(tg.x - 6, tg.y - 3, 1.2, Col(0x3a2412)); c.circ(tg.x + 6, tg.y + 3, 1.2, Col(0x3a2412))
                    } else {
                        c.textS(p.theme == "shark" ? "Driven off!" : p.theme == "fire" ? "Doused!" : (p.theme == "thief" || p.theme == "rats" ? "Got him!" : (p.theme == "flyfish" || p.theme == "gleam" ? "Got it!" : (p.theme == "gulls" ? "Shoo!" : "Clear!"))), tg.x, tg.y - 20 - (1 - a) * 14, 15, Col(0x9ff0aa, a), 0, FONTB)
                    }
                } else if tg.state == 2 && tg.age < 0.7 {
                    c.textS("✕", tg.x, tg.y, 26, Col(0xff5a3c, 1 - tg.age / 0.7), 0, FONTB)
                }
            }
            var verb = "Cleared "
            if p.theme == "gulls" { verb = "Shooed " } else if p.theme == "leak" { verb = "Plugged " } else if ["thief", "rats", "flyfish", "gleam"].contains(p.theme) { verb = "Caught " }
            c.textS(verb + "\(p.score) / \(p.total)", W / 2, H - safeB - 22, 16, CREAM, 0, FONTB)
        case .pick:
            let r = pickRects(p)
            for (i, q) in r.enumerated() {
                let o = p.open[i]
                let bob = o < 0 ? sin(T * 2.2 + Double(i) * 1.3) * 3 : 0
                let cx = q.0 + q.2 / 2
                c.save()
                c.translate(0, bob)
                if o < 0 {
                    c.RR(q.0, q.1 + 4, q.2, q.3, 12, Col(0x000000, 0.3))
                    c.RRGrad(q.0, q.1, q.2, q.3, 12, [(0, Col(0x4a2f18, 0.95)), (1, Col(0x2a1a0c, 0.95))])
                    c.RRStroke(q.0, q.1, q.2, q.3, 12, 1.6, p.picksLeft > 0 ? Col(0xffd257, 0.6 + 0.4 * sin(T * 4 + Double(i))) : Col(0x6b4a26))
                    let iy = q.1 + q.3 * 0.46
                    if p.theme == "island" {
                        // a mound of sand
                        c.arcFill(cx, iy + 16, 26, PI, PI * 2, Col(0xe0c890))
                        c.arcFill(cx - 6, iy + 16, 14, PI, PI * 2, Col(0xf0dca8))
                        c.seg(cx + 10, iy - 14, cx + 10, iy + 4, 2, Col(0x6b4a26)); c.poly(Col(0x9a9388), [cx + 6, iy + 2, cx + 14, iy + 2, cx + 10, iy + 12])
                    } else if p.theme == "ghost" {
                        // a hatch
                        c.RR(cx - 24, iy - 18, 48, 38, 3, Col(0x3a3f44))
                        c.RRStroke(cx - 24, iy - 18, 48, 38, 3, 1.5, Col(0x8fa0a8))
                        c.seg(cx - 24, iy - 5, cx + 24, iy - 5, 1, Col(0x8fa0a8)); c.seg(cx - 24, iy + 8, cx + 24, iy + 8, 1, Col(0x8fa0a8))
                        c.circStroke(cx, iy + 1, 5, 1.6, Col(0xc8d6dc))
                    } else {
                        // a floating crate
                        c.RR(cx - 22, iy - 18, 44, 36, 3, Col(0xa8823f))
                        c.RRStroke(cx - 22, iy - 18, 44, 36, 3, 1.5, Col(0x5a3d20))
                        c.seg(cx - 22, iy - 18, cx + 22, iy + 18, 1.5, Col(0x5a3d20)); c.seg(cx + 22, iy - 18, cx - 22, iy + 18, 1.5, Col(0x5a3d20))
                        c.ellStroke(cx, iy + 22, 28, 4, 1, Col(0xffffff, 0.5))
                    }
                    c.text("?", cx, q.1 + q.3 - 10, 15, CREAM.alpha(0.8), 0, FONTB)
                    if !p.seq.isEmpty { drawMemoryMark(c, p, i, q, cx, iy) }
                    if i == p.tell && (p.tellHold || (p.t > 0.6 && p.t < 1.5)) {
                        // a glint: there is something in this one
                        let gk = p.tellHold ? 1.0 : sin((p.t - 0.6) / 0.9 * PI)
                        let gx = cx + 16, gy = iy - 14, gl = 13 * gk
                        c.seg(gx - gl, gy, gx + gl, gy, 2, Col(0xfff6d8, gk)); c.seg(gx, gy - gl, gx, gy + gl, 2, Col(0xfff6d8, gk))
                        c.seg(gx - gl * 0.5, gy - gl * 0.5, gx + gl * 0.5, gy + gl * 0.5, 1.2, Col(0xffe08a, gk)); c.seg(gx - gl * 0.5, gy + gl * 0.5, gx + gl * 0.5, gy - gl * 0.5, 1.2, Col(0xffe08a, gk))
                        c.circ(gx, gy, 3 * gk, WHITE)
                    }
                } else {
                    // opened: the lid flies and what was inside pops up
                    let k = min(1, o / 0.35)
                    let pop = 1 + 0.5 * sin(k * PI) * (1 - k * 0.3)
                    let what = p.spots[i]
                    let good = what != 0 && what != 7
                    c.RRGrad(q.0, q.1, q.2, q.3, 12, good ? [(0, Col(0x5a4a1c, 0.95)), (1, Col(0x2f2408, 0.95))] : [(0, Col(0x2a2622, 0.9)), (1, Col(0x16130f, 0.9))])
                    c.RRStroke(q.0, q.1, q.2, q.3, 12, 1.6, what == 7 ? Col(0xff5a3c) : (good ? Col(0xffd257) : Col(0x6b5a44)))
                    c.save()
                    c.translate(cx, q.1 + q.3 * 0.42)
                    c.scale(pop, pop)
                    spotIcon(c, what, 0, 0, 38)
                    c.restore()
                    if o < 0.6 && p.theme != "island" {
                        // the lid spinning away
                        let lk = o / 0.6
                        c.save()
                        c.alpha(1 - lk)
                        c.translate(cx + lk * 34, q.1 + q.3 * 0.2 - sin(lk * PI) * 46)
                        c.rotate(lk * 3.2)
                        c.RR(-22, -4, 44, 8, 2, p.theme == "ghost" ? Col(0x3a3f44) : Col(0xa8823f))
                        c.RRStroke(-22, -4, 44, 8, 2, 1.2, p.theme == "ghost" ? Col(0x8fa0a8) : Col(0x5a3d20))
                        c.restore()
                    }
                    c.text(SPOT_NAMES[what], cx, q.1 + q.3 - 10, 13, what == 7 ? Col(0xff9a8a) : (good ? GOLD : CREAM.alpha(0.6)), 0, FONTB)
                }
                c.restore()
            }
            c.textS(p.phase > 0 ? memoryLine(p) : (p.picksLeft > 0 ? "Picks left: \(p.picksLeft)" : ""), W / 2, H - safeB - 12, 15, p.phase > 0 ? Col(0xfff2a0) : CREAM, 0, FONTB)
        case .hold, .steer, .swipe, .beat, .reel:
            drawPlay2(c, p)
        }
        for pp in p.pops {
            if pp.t < 0 { continue }
            if pp.s == "•" {
                // a spark flying out from a hit
                let a = Double(abs(Int(pp.x * 13 + pp.y * 7)) % 10) / 10 * PI * 2
                let r = 6 + pp.t * 90
                c.circ(pp.x + cos(a) * r, pp.y + sin(a) * r + pp.t * pp.t * 60, 2.6 * (1 - pp.t), Col(0xffe08a, max(0, 1 - pp.t / 0.6)))
                continue
            }
            let a = max(0, 1 - pp.t / 1.1)
            let sc = pp.big ? 1 + 0.6 * max(0, 0.25 - pp.t) * 4 : 1
            c.save()
            c.alpha(a)
            c.translate(pp.x, pp.y - pp.t * 34)
            c.scale(sc, sc)
            c.textS(pp.s, 0, 0, pp.big ? 28 : 17, pp.good ? (pp.big ? Col(0xfff2a0) : Col(0x9ff0aa)) : Col(0xff9a8a), 0, FONTB)
            c.restore()
        }
        if p.flash > 0 { c.R(0, 0, W, H, Col(0xfff8e0, p.flash * 0.9)) }
        if p.endT >= 0 && p.kind != .pick {
            // how it went: up to three stars ring up one after another
            let el = p.endLen - p.endT
            let st = p.stars()
            let a = min(1, el / 0.2)
            let words = ["Bad luck", "Not bad", "Well done!", "Masterly!"][max(0, min(3, st))]
            let bw2 = 280.0, bh2 = 96.0, bx2 = W / 2 - bw2 / 2, by2 = H * 0.5 - bh2 / 2 - 20
            c.save()
            c.alpha(a)
            c.translate(W / 2, by2 + bh2 / 2); let sc = 0.8 + 0.2 * min(1, el / 0.25); c.scale(sc, sc); c.translate(-W / 2, -(by2 + bh2 / 2))
            c.RR(bx2 + 3, by2 + 4, bw2, bh2, 18, Col(0x000000, 0.4))
            c.RRGrad(bx2, by2, bw2, bh2, 18, [(0, Col(0x3a2412, 0.97)), (1, Col(0x1e1108, 0.97))])
            c.RRStroke(bx2, by2, bw2, bh2, 18, 2, Col(0xd2a455))
            c.text(words, W / 2, by2 + 30, 22, st >= 2 ? GOLD : CREAM, 0, FONTD)
            for i in 0..<3 {
                let sx2 = W / 2 + Double(i - 1) * 50, sy2 = by2 + 64
                let on = i < p.starsShown
                let popK = on ? min(1, (el - 0.25 - Double(i) * 0.22) / 0.15) : 1
                let r = 17 * (on ? 1 + 0.4 * (1 - popK) : 1)
                var pts: [Double] = []
                for k in 0..<10 {
                    let ang = -PI / 2 + Double(k) * PI / 5
                    let rr = k % 2 == 0 ? r : r * 0.45
                    pts.append(sx2 + cos(ang) * rr); pts.append(sy2 + sin(ang) * rr)
                }
                if on {
                    c.glow(sx2, sy2, 30, Col(0xffd257, 0.5), Col(0xffd257, 0))
                    c.poly(Col(0xffd257), pts)
                } else {
                    c.poly(Col(0x000000, 0.35), pts)
                }
            }
            if p.bestStreak >= 3 { c.text("Best run: \(p.bestStreak) in a row", W / 2, by2 + bh2 + 18, 13, CREAM.alpha(0.85), 0, FONTI) }
            c.restore()
        }
        if p.msgT > 0 && !p.msg.isEmpty {
            let a = min(1, p.msgT * 2.5)
            let sc = 1 + 0.25 * max(0, p.msgT - 0.9) * 5
            c.save()
            c.alpha(a)
            c.translate(W / 2, H * 0.36)
            c.scale(sc, sc)
            c.textS(p.msg, 0, 0, 24, p.msgGood ? Col(0xffe9a0) : Col(0xff9a8a), 0, FONTB)
            c.restore()
        }
        _ = sx; _ = wy
    }

    // ---------- small games offered between events: take them or leave them
    func startOdd(_ k: String) {
        offerK = ""
        switch k {
        case "flyfish":
            let p = Play(.taps, "flyfish", "Flying fish!", "A school is skipping over the deck. Tap to catch them") { [unowned self] p in
                let got = self.addGood("food", p.score)
                self.done(p.score == 0 ? "Every one sails over the far rail" : "\(p.score) flying fish for the pot: +\(got) stores")
            }
            p.total = 7
            p.life = 1.25
            evTitle = p.title
            startPlay(p)
        case "trim":
            let p = Play(.timing, "trim", "A fresh wind", "Trim the sails each time she would luff") { [unowned self] p in
                let gain = Double(p.score * 10 + p.perfect * 6)
                self.dist = min(self.legLen - 1, self.dist + gain)
                self.done(p.score == 0 ? "The sails flog and the wind goes by" : "She leans to it and flies: \(Int(gain)) leagues made good")
            }
            p.rounds = 3
            p.zone = clampD(0.22 + 0.04 * E("rig"), 0.18, 0.34)
            p.speed = 1.2
            evTitle = p.title
            startPlay(p)
        case "cask":
            let p = Play(.timing, "cask", "A cask adrift", "Reach with the boathook. Three tries") { [unowned self] p in
                if p.score == 0 { self.done("It bobs away astern, out of reach"); return }
                switch rndI(0, 3) {
                case 0: self.done("Ship's biscuit, still dry: +\(self.addGood("food", 6)) stores")
                case 1: self.done("Good oak staves: +\(self.addGood("planks", 2)) planks")
                case 2: self.gold += 30; self.snd?.coin(); self.done("Someone's savings, sealed in wax: +30 gold")
                default: self.done("Dry powder in a tarred keg: +\(self.addGood("powder", 2)) powder")
                }
            }
            p.rounds = 3
            p.stopOnHit = true
            p.zone = 0.2
            p.speed = 1.35
            evTitle = p.title
            startPlay(p)
        case "gleam":
            let p = Play(.taps, "gleam", "Glinting in the swell", "Wreckage from some poor ship. Tap the bright things before they sink") { [unowned self] p in
                let g = p.score * 6
                self.gold += g
                if g > 0 { self.snd?.coin() }
                self.done(p.score == 0 ? "They sink before the net is over" : "Brass, silver and a pocket watch: +\(g) gold")
            }
            p.total = 5
            p.life = 1.1
            evTitle = p.title
            startPlay(p)
        case "turtle":
            let p = Play(.reel, "turtle", "A turtle alongside", "Tap fast to haul her in. Ease off when she dives") { [unowned self] p in
                if p.score == 0 { self.done("She dives, and is gone"); return }
                let got = self.addGood("food", 8 + p.perfect * 3)
                self.done(got > 0 ? "Hauled aboard in the net. Turtle soup for a week: +\(got) stores" : "Netted, but the hold is full. You let her go")
            }
            p.rounds = 1
            p.speed = 0.05
            p.life = 12; p.tb = 12
            p.a = 1; p.spawnT = rnd(1.2, 2.0)
            evTitle = p.title
            startPlay(p)
        case "gulls":
            let p = Play(.taps, "gulls", "Gulls at the catch", "They are diving on the fish drying in the rigging. Tap to shoo them") { [unowned self] p in
                let saved = max(0, 2 + p.score - p.missed)
                let got = saved > 0 ? self.addGood("food", saved) : 0
                self.done(got == 0 ? "The gulls strip the lines bare" : (p.missed == 0 ? "Not one fish lost, and the drying finished: +\(got) stores" : "The gulls took \(p.missed), you kept the rest: +\(got) stores"))
            }
            p.total = 7
            p.life = 1.15
            evTitle = p.title
            startPlay(p)
        case "chest":
            evTitle = "Crates adrift"
            var spots = [1, 3, 4, 0, 0]
            if chance(0.5) { spots[3] = 5 }
            if chance(0.1) { spots[4] = 2 }
            playPick("wreck", "Crates adrift", "Five crates lashed to a broken spar. There is time to pry open two", spots, 2) { return "" }
        default:
            evTitle = "Fish running"
            playFish()
        }
    }

    // ---------- the games behind each event
    func playStorm() {
        setWeather(3, days: 1)
        let p = Play(.steer, "storm", "Take the helm", "Slide your finger to steer through the gap in each wave") { [unowned self] p in
            let miss = p.rounds - p.score
            let d = Double(miss) * max(2, Double(rndI(3, 5)) - 0.8 * self.E("rig"))
            if d > 0 { self.dmg(d) }
            if self.over { return }
            if miss >= 3 && chance(0.5) { self.hurtOne("thrown across the deck") }
            self.setWeather(2, days: 1)
            self.done(miss == 0 ? "Not a plank started. The crew cheers the helm" : "You came through. The storm cost \(Int(d)) hull")
        }
        p.total = 5; p.rounds = 5
        p.zone = clampD(0.12 + 0.03 * E("helm"), 0.1, 0.2)
        p.speed = 0.5
        p.life = 1.5
        p.a = 0.5; p.b = 0.5
        startPlay(p)
    }
    func playRun(_ foes: Int, _ prize: Int) {
        let p = Play(.timing, "run", "Run for it", "Trim the sails as each gust comes") { [unowned self] p in
            if p.score >= 2 { self.done(p.perfect >= 2 ? "You leave them hull-down astern" : "You outran them"); return }
            self.dmg(10)
            if self.over { return }
            self.toast("They caught you!")
            self.startDuel(foes: foes, boss: false, prize: prize)
        }
        p.rounds = 3
        p.zone = clampD(0.14 + 0.06 * ship.speed + 0.04 * E("rig") + 0.03 * E("look"), 0.14, 0.36)
        p.speed = 1.25
        startPlay(p)
    }
    func playFish() {
        let used = min(3, bait)
        bait -= used
        let p = Play(.reel, "fish", "Fish running", "Tap fast to reel each one in. Ease off when it runs") { [unowned self] p in
            let raw = Double(p.score * rndI(3, 5) + p.perfect * 3) * (1 + 0.2 * self.E("fish"))
            let got = self.addGood("food", Int(raw))
            self.done(p.score == 0 ? "Not a bite. The bait is gone" : (got > 0 ? "A fine catch: +\(got) stores" : "The hold is full"))
        }
        p.rounds = max(1, used)
        p.speed = 0.07 + 0.012 * E("fish")
        p.life = 10; p.tb = 10
        p.a = 1; p.spawnT = rnd(1.2, 2.0)
        startPlay(p)
    }
    func playLine() {
        let p = Play(.hold, "line", "Man overboard!", "Hold to swing the line, let go to throw. Three tries") { [unowned self] p in
            if p.score > 0 {
                self.done("Hauled aboard, coughing and cursing, but alive")
            } else {
                self.toastText = ""
                self.loseCrew("Lost to the sea")
                if !self.over { self.done(self.toastText) }
            }
        }
        p.rounds = 3
        p.stopOnHit = true
        p.zone = clampD(0.2 + 0.05 * E("helm"), 0.18, 0.34)
        p.speed = 0.95
        p.b = 0.72
        startPlay(p)
    }
    func playLeak() {
        let p = Play(.taps, "leak", "Sprung a leak", "Tap each jet of water to hammer a plank over it") { [unowned self] p in
            let used = min(self.planks, (p.score + 1) / 2)
            self.planks -= used
            let d = Double(p.missed * 3)
            if d > 0 { self.dmg(d) }
            if self.over { return }
            self.done(p.missed == 0 ? "Every leak stopped. \(used) planks used" : "\(p.score) stopped, \(p.missed) got away: \(Int(d)) hull lost, \(used) planks used")
        }
        p.total = 6
        p.life = 1.5 + 0.2 * E("carp")
        startPlay(p)
    }
    func playFog() {
        setWeather(4, days: 1)
        let p = Play(.steer, "fog", "Rocks in the fog", "Slide your finger to steer between the rocks as they show") { [unowned self] p in
            let d = Double(p.missed * rndI(3, 5))
            if d > 0 { self.dmg(d) }
            if self.over { return }
            self.done(p.missed == 0 ? "You thread the rocks without a scratch" : "The hull scrapes \(p.missed) time\(p.missed == 1 ? "" : "s"): \(Int(d)) hull lost")
        }
        p.total = 7
        p.speed = 0.42
        p.life = 1.25
        p.fade = 0.34 - 0.1 * E("look")
        p.a = 0.5; p.b = 0.5
        startPlay(p)
    }
    /// Opens a few of a row of spots and reports what was found.
    private func playPick(_ theme: String, _ title: String, _ hint: String, _ spots: [Int], _ picks: Int, memory: Int = 0, _ trouble: @escaping () -> String) {
        let p = Play(.pick, theme, title, hint) { [unowned self] p in
            var parts: [String] = []
            var g = 0
            for what in p.found {
                switch what {
                case 1: g += rndI(30, 70)
                case 2: g += Int(Double(rndI(160, 280)) * (theme == "island" && self.hasMap ? 2.2 : 1))
                case 3: parts.append("+\(self.addGood("food", 8)) stores")
                case 4: parts.append("+\(self.addGood("planks", 5)) planks")
                case 5: parts.append("+\(self.addGood("powder", 3)) powder")
                case 6: parts.append("+\(self.addGood("food", 6)) stores")
                case 8: if self.hasMap { g += 60 } else { self.hasMap = true; parts.append("a treasure map") }
                case 7:
                    let t = trouble()
                    if self.over { return }
                    if !t.isEmpty { parts.append(t) }
                default: break
                }
            }
            if p.found.contains(2) && theme == "island" { self.hasMap = false; self.logIt("Dug up buried treasure") }
            if g > 0 { self.gold += g; parts.insert("+\(g) gold", at: 0) }
            self.done(parts.isEmpty ? "Nothing worth the trouble" : parts.joined(separator: " · "))
        }
        p.spots = spots.shuffled()
        p.tell = p.spots.indices.filter { p.spots[$0] != 0 && p.spots[$0] != 7 }.randomElement() ?? -1
        if memory > 0 {
            // they light up in an order to be tapped back; get it right and you learn what is inside
            var last = -1
            for _ in 0..<memory {
                var k = rndI(0, spots.count - 1)
                if k == last { k = (k + 1) % spots.count }
                p.seq.append(k); last = k
            }
            p.phase = 1; p.cur = -1; p.tell = -1
        }
        p.open = [Double](repeating: -1, count: spots.count)
        p.picksLeft = picks
        startPlay(p)
    }
    // ---------- things that happen ashore
    func playDock() {
        let p = Play(.beat, "dock", "Work on the docks", "Swing each load aboard on the beat") { [unowned self] p in
            let g = p.score * 14 + p.perfect * 8
            self.gold += g
            self.portJobDone = true
            if g > 0 { self.snd?.coin() }
            self.done(g > 0 ? "The merchant counts out \(g) gold for \(p.score) loads" : "Every load in the harbour. No pay today")
        }
        p.rounds = 6
        p.life = 0.9; p.tb = 0.9 * 1.6
        startPlay(p)
    }
    func playThief() {
        let p = Play(.taps, "thief", "Stop, thief!", "A cutpurse is working the quay. Tap him when he shows") { [unowned self] p in
            self.portJobDone = true
            if p.score >= 3 {
                let g = 30 + p.score * 10
                self.gold += g
                self.snd?.coin()
                self.done("Collared! The merchants pay \(g) gold for their purses back")
            } else {
                let lost = min(self.gold, 25)
                self.gold -= lost
                self.done(lost > 0 ? "He is gone into the alleys, and \(lost) of your gold with him" : "He is gone into the alleys")
            }
        }
        p.total = 5
        p.life = 1.15
        startPlay(p)
    }
    func playRats() {
        let p = Play(.taps, "rats", "Rats on the gangway", "They are after your stores. Tap each one") { [unowned self] p in
            self.portJobDone = true
            let eaten = Double(p.missed * 2)
            self.food = max(0, self.food - eaten)
            if p.missed == 0 { self.gold += 20; self.snd?.coin() }
            self.done(p.missed == 0 ? "Not one got aboard. The harbour master pays a 20 gold bounty" : "\(p.missed) got into the hold: \(Int(eaten)) stores spoiled")
        }
        p.total = 6
        p.life = 1.2
        startPlay(p)
    }
    func playBarrels() {
        portJobDone = true
        var s = [3, 6, 4, 1, 0]
        if chance(0.35) { s[4] = 8 }
        playPick("wreck", "An old sailor's gift", "\"Rap them back in my order and I'll show you the good ones.\" Then take two", s, 2, memory: 4) { return "" }
    }
    func playRow() {
        let p = Play(.beat, "row", "Man the oars", "Call the stroke. Tap on each beat") { [unowned self] p in
            let miss = p.rounds - p.score
            if miss >= 2 { self.consume() }
            if self.over { return }
            self.done(miss == 0 ? "Six clean strokes and she finds a breeze. Nothing lost" : (miss >= 2 ? "A ragged, thirsty hour at the oars. Extra rations used" : "She creeps out of the calm"))
        }
        p.rounds = 6
        p.life = 0.95; p.tb = 0.95 * 1.6
        startPlay(p)
    }
    func playShark() {
        let p = Play(.taps, "shark", "Sharks round the raft", "Tap each fin to drive it off with a musket shot") { [unowned self] p in
            if p.missed >= 2 { self.done("The raft is empty when you reach it"); return }
            if self.crew < self.ship.crew {
                self.crew += 1
                self.syncMen()
                self.done("Hauled aboard, shaking. He signs on with your crew")
            } else {
                self.gold += 60
                self.snd?.coin()
                self.done("Hauled aboard, shaking. He pays 60 gold for his life")
            }
        }
        p.total = 5
        p.life = 1.4
        startPlay(p)
    }
    func playFire() {
        let p = Play(.swipe, "fire", "Fire in the town!", "Pass the buckets down the chain, the way each one is going") { [unowned self] p in
            self.portJobDone = true
            if p.missed <= 2 {
                let g = 40 + p.score * 10
                self.gold += g
                self.snd?.coin()
                self.done(p.missed == 0 ? "Not a house lost. The town empties its pockets: +\(g) gold" : "Most of the street is saved. The town gives \(g) gold in thanks")
            } else {
                self.done("Half the street burns before it is out. No one has the heart to thank you")
            }
        }
        p.total = 7
        p.life = 1.6; p.a = 1.6
        p.cur = rndI(0, 3)
        startPlay(p)
    }
    func playStrong() {
        let p = Play(.hold, "strong", "Ring the bell", "Hold to swing the hammer. Let go to send the puck to the bell") { [unowned self] p in
            self.portJobDone = true
            let g = p.score >= 3 ? 50 + p.perfect * 10 : (p.score == 2 ? 20 : 0)
            self.gold += g
            if g > 0 { self.snd?.coin() }
            self.done(p.score >= 3 ? "Three for three. The purse is yours: +\(g) gold" : (g > 0 ? "Two out of three wins a small prize: +\(g) gold" : "The strongman keeps his purse"))
        }
        p.rounds = 3
        p.zone = 0.17
        p.speed = 1.2
        p.b = rnd(0.6, 0.85)
        startPlay(p)
    }
    func startRaid() {
        duelPort = true; duelSport = false
        startDuel(foes: 5, boss: false, prize: 45)
    }
    func startTourney() {
        duelPort = true; duelSport = true
        startDuel(foes: 3, boss: false, prize: 40)
    }
    func offerCargo() {
        let next = STAGES[min(5, leg + 1)][path[min(5, leg + 1)]].n
        let room = holdMax - holdUsed
        show("A merchant's cargo", "Thirty crates of cloth for " + next + ". He pays 130 gold when they land. They fill 30 of your hold until then." + (room < 30 ? "\nYou have room for only \(room)." : ""), [
            Opt("Take the cargo", room < 30 ? "not enough room" : "130 gold on delivery", off: room < 30) { [unowned self] in
                self.cargoPay = 130; self.cargoHold = 30
                self.portJobDone = true
                self.snd?.good()
                self.card = nil
                self.toast("Cargo stowed for " + next)
            },
            Opt("Not this time") { [unowned self] in self.card = nil }
        ])
    }
    func offerFare() {
        let next = STAGES[min(5, leg + 1)][path[min(5, leg + 1)]].n
        let watches = Int((nextLegLen() / max(1, 42 * ship.speed)).rounded(.up)) + 2
        show("A passenger", "A lady with three trunks must be in " + next + " within \(watches * SUNS) days. Ninety gold if you make it; half if you are late.", [
            Opt("Welcome aboard", "90 gold on arrival") { [unowned self] in
                self.fareDue = 90; self.fareBy = self.day + watches
                self.portJobDone = true
                self.snd?.good()
                self.card = nil
                self.toast("She has the stern cabin")
            },
            Opt("No passengers") { [unowned self] in self.card = nil }
        ])
    }
    func takeBounty() {
        portJobDone = true
        bounty = true
        snd?.good()
        show("Wanted", "The governor has posted 150 gold for the next pirate crew brought down. You tear the notice from the wall.", [Opt("They are as good as caught") { [unowned self] in self.card = nil }])
    }
    /// Three things going on, never the same three.
    func rollPortJobs() {
        var pool = [1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12]
        if isNight || chance(0.3) { pool.append(4); pool.append(4) }
        pool.shuffle()
        portJobs = []
        // one opportunity in most ports, two in some
        let want = chance(0.45) ? 2 : 1
        for j in pool where !portJobs.contains(j) && portJobs.count < want { portJobs.append(j) }
        jobsDone = []
        portJob = 0
        saluteT = 5; saluteN = 3
        chatT = 0
    }
    func runJob(_ j: Int) {
        portJob = j
        switch j {
        case 1: playDock()
        case 2: playThief()
        case 3: playRats()
        case 4: joinFestival()
        case 5: playBarrels()
        case 6: playFire()
        case 7: startRaid()
        case 8: startTourney()
        case 9: playStrong()
        case 10: offerCargo()
        case 11: offerFare()
        default: takeBounty()
        }
    }

    func joinFestival() {
        portJobDone = true
        festT = 14
        snd?.good()
        let f = addGood("food", 6)
        var healed = ""
        if let m = men.first(where: { !$0.fit }) { m.st = 0; m.d = 0; healed = " " + m.n + " is back on his feet." ; autoPost() }
        show("Festival night", "Drums, roast pig and fireworks over the harbour. The crew come back singing.\n+\(f) stores from the feast." + healed, [Opt("Watch the fireworks") { [unowned self] in self.card = nil }])
    }

    func playWreck() {
        var s = [4, 3, 1, 0, 7]
        if chance(0.5) { s[3] = 5 }
        if chance(0.3) { s[2] = 2 }
        playPick("wreck", "Wreckage", "Three crates are within reach of the boat hook", s, 3) { [unowned self] in
            self.dmg(6)
            return "the wreck rolls and gouges your hull"
        }
    }
    func playIsland() {
        var s = [3, 6, 0, 0, 7, 1]
        if hasMap || chance(0.5) { s[2] = 2 }
        playPick("island", "Ashore", hasMap ? "The map marks one of these. Three digs" : "Somewhere to dig. Three tries", s, 3) { [unowned self] in
            self.hurtOne("pinched and poisoned by a crab")
            return "a crab gets a sailor"
        }
    }
    func playGhost() {
        var s = [2, 8, 7, 0]
        if chance(0.4) { s[3] = 1 }
        playPick("ghost", "Ghost ship", "The hatches creak in turn. Repeat it to learn which is cursed, then open two", s, 2, memory: 4) { [unowned self] in
            self.toastText = ""
            self.loseCrew("Something drags a sailor below")
            return self.toastText
        }
    }
}

// ---------- the summary shown on making port

struct LegSum {
    static let fullT = 4.4
    let from: String
    let to: String
    let days: Int
    let leagues: Int
    let events: Int
    let gold: Int
    let lost: Int
    let hull: Int
    let fights: Int
    let wages: Int
    let ate: Int
    let drank: Int
    let warns: [String]
}

extension Game {
    func drawSummary(_ c: Canvas) {
        guard let s = sum else { return }
        hits.removeAll(keepingCapacity: true)
        let t = sumT
        func eo(_ k: Double) -> Double { let x = 1 - clampD(k, 0, 1); return 1 - x * x * x }
        c.R(0, 0, W, H, Col(0x000000, 0.5 * eo(t / 0.3)))
        let pw = min(W - safeL - safeR - 40, 560), ph = min(H - 40, 340.0)
        let px = (W - pw) / 2, py = max(34, (H - ph) / 2 + 12)
        let pop = eo(t / 0.35)
        c.save()
        c.alpha(eo(t / 0.2))
        c.translate(W / 2, py + ph / 2 + 30 * (1 - pop))
        c.scale(0.9 + 0.1 * pop, 0.9 + 0.1 * pop)
        c.translate(-W / 2, -(py + ph / 2))
        panel(c, px, py, pw, ph)
        c.text("Landfall", px + 20, py + 32, 24, GOLD, -1, FONTD)
        c.text(s.to, px + pw - 20, py + 32, 20, CREAM, 1, FONTB)
        // the passage, sailed again in miniature
        let lx0 = px + 34, lx1 = px + pw - 34, ly = py + 58
        let k = eo((t - 0.2) / 1.3)
        c.dash(4, 5); c.seg(lx0, ly, lx1, ly, 1.5, Col(0xfff6d8, 0.5)); c.noDash()
        c.seg(lx0, ly, lx0 + (lx1 - lx0) * k, ly, 3, Col(0xef4a36))
        c.circ(lx0, ly, 4.5, Col(0xef4a36)); c.circ(lx1, ly, 5, k >= 1 ? Col(0xffd257) : Col(0xfff6d8))
        let shx = lx0 + (lx1 - lx0) * k
        c.poly(Col(0x6b4423), [shx - 10, ly - 3, shx + 10, ly - 3, shx + 6, ly + 3, shx - 8, ly + 3])
        c.poly(Col(0xf3ead2), [shx - 1, ly - 16, shx + 8, ly - 5, shx - 1, ly - 5])
        c.seg(shx - 1, ly - 3, shx - 1, ly - 17, 1.2, Col(0x3b2412))
        if k >= 1 { c.glow(lx1, ly, 22, Col(0xffd257, 0.5 + 0.3 * sin(T * 5)), Col(0xffd257, 0)) }
        c.text(s.from, lx0, ly + 18, 12, CREAM.alpha(0.8), 0, FONTI)
        // the tally: each line counts up in turn
        let rows: [(String, String, Int, String, Bool)] = [
            ("day", "Days · \(s.events) event\(s.events == 1 ? "" : "s")" + (s.fights > 0 ? " · \(s.fights) fight\(s.fights == 1 ? "" : "s")" : ""), s.days, "", false),
            ("food", "Days of stores used", s.ate, "-", false),
            ("water", "Days of stores left", s.drank, "", s.drank < storesNeeded()),
            ("gold", "Gold won or lost", s.gold, s.gold > 0 ? "+" : "", s.gold < 0),
            ("crew", s.lost > 0 ? "Hands lost" : "All hands safe", s.lost, "", s.lost > 0),
            ("planks", "Hull sound", s.hull, "%", s.hull < 50)
        ]
        let colW = (pw - 40 - 14) / 2
        for (i, r) in rows.enumerated() {
            let st = 0.7 + Double(i) * 0.34
            let a = eo((t - st) / 0.25)
            if a <= 0 { continue }
            if i > sumRow { sumRow = i; snd?.click(); if r.0 == "gold" && s.gold > 0 { snd?.coin() } }
            let col = i % 2, row = i / 2
            let rx = px + 20 + Double(col) * (colW + 14), ry = py + 84 + Double(row) * 42
            c.save()
            c.alpha(a)
            c.translate(14 * (1 - a), 0)
            c.RR(rx, ry, colW, 38, 9, Col(0x1c1108, 0.7))
            c.RRStroke(rx, ry, colW, 38, 9, 1, Col(0xd2a455, 0.45))
            icon(c, r.0, rx + 20, ry + 19, 22)
            c.text(r.1, rx + 40, ry + 24, 14, CREAM, -1, FONT)
            let n = Int((Double(r.2) * eo((t - st) / 0.6)).rounded())
            let shown = r.0 == "crew" && s.lost == 0 ? "✓" : (n == 0 && r.3 == "-" ? "" : r.3.replacingOccurrences(of: "%", with: "")) + "\(n)" + (r.3 == "%" ? "%" : "")
            c.text(shown, rx + colW - 12, ry + 26, 19, r.4 ? Col(0xff9a8a) : GOLD, 1, FONTB)
            c.restore()
        }
        // the verdict, stamped on
        let vt = 0.7 + 6 * 0.34 + 0.25
        if t > vt {
            let hard = s.lost > 0 || s.hull < 50
            let swift = !hard && s.days <= Int((Double(s.leagues) / 44).rounded(.up)) * SUNS
            let word = hard ? "A HARD PASSAGE" : (swift ? "A SWIFT PASSAGE" : "A FAIR PASSAGE")
            let vc = hard ? Col(0xff7a5a) : (swift ? Col(0xffe08a) : Col(0x9ff0aa))
            let q = clampD((t - vt) / 0.22, 0, 1)
            if sumRow < 99 { sumRow = 99; snd?.thud(); if !hard { snd?.good() }; shake = 0.12; puff(W / 2, py + 244, 30, vc, 260, 320, 3, 0.7) }
            c.save()
            c.alpha(q)
            c.translate(W / 2, py + 231)
            c.rotate(-0.04)
            c.scale(2.2 - 1.2 * q, 2.2 - 1.2 * q)
            let tw = textW(word, 22, FONTD) + 36
            c.RRStroke(-tw / 2, -20, tw, 34, 6, 2.5, vc)
            c.text(word, 0, 5, 22, vc, 0, FONTD)
            c.restore()
        }
        if t > vt + 0.3 && !s.warns.isEmpty {
            // what wants seeing to before you sail again
            let wa = eo((t - vt - 0.3) / 0.3)
            c.save()
            c.alpha(wa * (0.8 + 0.2 * sin(T * 5)))
            c.text("!  " + s.warns.joined(separator: "  ·  "), W / 2, py + 266, 13.5, Col(0xff9a8a), 0, FONTB)
            c.restore()
        }
        c.restore()
        if t >= LegSum.fullT - 0.9 {
            let a = eo((t - (LegSum.fullT - 0.9)) / 0.3)
            c.save()
            c.alpha(a)
            btn(c, px + pw / 2 - 140, py + ph - 58 + 10 * (1 - a), 280, 46, "Go ashore", "wages of \(s.wages) gold fall due when you sail", gold: true, size: 17) { [unowned self] in self.sum = nil }
            c.restore()
        }
    }
}
