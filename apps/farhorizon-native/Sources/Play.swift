import CoreGraphics
import Foundation

// The hands-on part of an event at sea. Three kinds:
//   timing — a marker swings along a bar; tap as it crosses the middle
//   taps   — trouble springs up around the ship; tap each before it is too late
//   pick   — a row of crates, mounds or hatches; open a few and see what is inside

final class Play {
    enum Kind { case timing, taps, pick }
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
    var targets: [(x: Double, y: Double, age: Double, life: Double, state: Int)] = []
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
    // shared
    var t = 0.0
    var msg = ""
    var msgT = 0.0
    var msgGood = true
    var endT = -1.0
    var finished = false
    let finish: (Play) -> Void

    init(_ kind: Kind, _ theme: String, _ title: String, _ hint: String, _ finish: @escaping (Play) -> Void) {
        self.kind = kind; self.theme = theme; self.title = title; self.hint = hint; self.finish = finish
    }
    func say(_ s: String, _ good: Bool) { msg = s; msgT = 1.1; msgGood = good }
}

/// What can lie under a spot: 0 nothing, 1 some gold, 2 a hoard, 3 food, 4 planks, 5 powder, 6 water, 7 trouble, 8 a map
let SPOT_NAMES = ["Empty", "Gold", "Treasure!", "Food", "Planks", "Powder", "Water", "Trouble!", "A map"]

extension Game {
    func startPlay(_ p: Play) {
        card = nil
        play = p
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
        p.t += dt
        p.msgT = max(0, p.msgT - dt)
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
                } else {
                    x = rnd(W * 0.6, W - safeR - 50)
                    y = rnd(wy - 6, H - safeB - 40)
                }
                p.targets.append((x, y, 0, p.life, 0))
                p.spawned += 1
                p.spawnT = rnd(0.45, 0.85)
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
                        shake = 0.25
                        snd?.thud()
                        buzz?(true)
                        p.say(p.theme == "leak" ? "She's taking water!" : (p.theme == "thief" ? "He ducks away!" : (p.theme == "rats" ? "Into the stores!" : "Struck a rock!")), false)
                    } else {
                        open += 1
                    }
                }
            }
            if p.spawned >= p.total && open == 0 { p.endT = 0.9 }
        case .pick:
            for i in 0..<p.open.count where p.open[i] >= 0 { p.open[i] += dt }
        }
    }

    func tapPlay(_ x: Double, _ y: Double) {
        guard let p = play, p.endT < 0 else { return }
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
                snd?.good()
                buzz?(false)
                puff(W / 2, H - safeB - 60, perfect ? 26 : 14, Col(0xffe08a), 220, 300, 2.6, 0.5)
                switch p.theme {
                case "storm": p.say(perfect ? "Dead on the wave!" : "She rides over it", true)
                case "run": p.say(perfect ? "Every stitch drawing!" : "The sails fill", true)
                case "fish": p.say(perfect ? "A big one!" : "Hooked!", true); snd?.splash(); puff(sx - len * 0.45, wy + 2, 16, Col(0xffffff, 0.9), 160, 300, 2.4, 0.5)
                case "dock": p.say(perfect ? "Stowed like a master!" : "Aboard she goes", true); snd?.coin()
                default: p.say("He has the line!", true)
                }
            } else {
                p.marks.append(0)
                snd?.thud()
                buzz?(true)
                switch p.theme {
                case "storm": p.say("A sea breaks over the rail!", false); shake = 0.35; puff(sx, wy - len * 0.2, 30, Col(0xffffff, 0.85), 260, 320, 3, 0.7); snd?.splash()
                case "run": p.say("The canvas flogs", false)
                case "fish": p.say("It slipped the hook", false)
                case "dock": p.say("The load swings wide!", false)
                default: p.say("The line falls short", false); snd?.splash()
                }
            }
            p.speed *= 1.1
            p.pos = chance(0.5) ? 0.02 : 0.98
            p.dir = p.pos < 0.5 ? 1 : -1
            if p.tries >= p.rounds || (p.stopOnHit && p.score > 0) { p.endT = 1.0 }
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
                buzz?(false)
                if p.theme == "leak" { snd?.thud(); puff(p.targets[best].x, p.targets[best].y, 10, Col(0xc9a86a), 120, 260, 2.4, 0.4) } else { snd?.good(); puff(p.targets[best].x, p.targets[best].y, 12, Col(0xffffff, 0.9), 150, 260, 2.2, 0.4) }
            }
        case .pick:
            if p.picksLeft <= 0 { return }
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

    func drawPlay(_ c: Canvas) {
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
            let mx = x + w * p.pos
            c.glow(mx, y + h / 2, 30, Col(0xffffff, 0.5), Col(0xffffff, 0))
            c.RR(mx - 3.5, y - 7, 7, h + 14, 3.5, WHITE)
            c.poly(WHITE, [mx - 9, y - 14, mx + 9, y - 14, mx, y - 4])
            c.textS(p.endT < 0 ? "Tap when the marker is in the middle" : "", W / 2, y + h + 22, 13, CREAM, 0, FONTI)
        case .taps:
            for tg in p.targets {
                if tg.state == 0 {
                    let k = clampD(tg.age / tg.life, 0, 1)
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
                        c.textS(p.theme == "thief" || p.theme == "rats" ? "Got him!" : "Clear!", tg.x, tg.y - 20 - (1 - a) * 14, 15, Col(0x9ff0aa, a), 0, FONTB)
                    }
                } else if tg.state == 2 && tg.age < 0.7 {
                    c.textS("✕", tg.x, tg.y, 26, Col(0xff5a3c, 1 - tg.age / 0.7), 0, FONTB)
                }
            }
            c.textS((p.theme == "leak" ? "Plugged " : (p.theme == "thief" || p.theme == "rats" ? "Caught " : "Cleared ")) + "\(p.score) / \(p.total)", W / 2, H - safeB - 22, 16, CREAM, 0, FONTB)
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
                    c.text(SPOT_NAMES[what], cx, q.1 + q.3 - 10, 13, what == 7 ? Col(0xff9a8a) : (good ? GOLD : CREAM.alpha(0.6)), 0, FONTB)
                }
                c.restore()
            }
            c.textS(p.picksLeft > 0 ? "Picks left: \(p.picksLeft)" : "", W / 2, H - safeB - 12, 15, CREAM, 0, FONTB)
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

    // ---------- the games behind each event
    func playStorm() {
        setWeather(3, days: 1)
        let p = Play(.timing, "storm", "Take the helm", "Turn her bow into each wave as it comes") { [unowned self] p in
            let miss = p.rounds - p.score
            let d = Double(miss) * max(2, Double(rndI(3, 5)) - 0.8 * self.E("rig"))
            if d > 0 { self.dmg(d) }
            if self.over { return }
            if miss >= 3 && chance(0.5) { self.hurtOne("thrown across the deck") }
            self.setWeather(2, days: 1)
            self.done(miss == 0 ? "Not a plank started. The crew cheers the helm" : "You came through. The storm cost \(Int(d)) hull")
        }
        p.rounds = 4
        p.zone = clampD(0.2 + 0.05 * E("helm"), 0.16, 0.36)
        p.speed = 1.15
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
        let p = Play(.timing, "fish", "Fish running", "Strike as each one takes the bait") { [unowned self] p in
            let raw = Double(p.score * rndI(3, 5) + p.perfect * 3) * (1 + 0.2 * self.E("fish"))
            let got = self.addGood("food", Int(raw))
            self.done(p.score == 0 ? "Not a bite. The bait is gone" : (got > 0 ? "A fine catch: +\(got) food" : "The hold is full"))
        }
        p.rounds = max(1, used)
        p.zone = clampD(0.22 + 0.05 * E("fish"), 0.18, 0.36)
        p.speed = 1.0
        startPlay(p)
    }
    func playLine() {
        let p = Play(.timing, "line", "Man overboard!", "Throw the line. Three tries") { [unowned self] p in
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
        p.speed = 1.3
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
        let p = Play(.taps, "fog", "Rocks in the fog", "Tap each rock as it shows, to steer clear") { [unowned self] p in
            let d = Double(p.missed * rndI(3, 5))
            if d > 0 { self.dmg(d) }
            if self.over { return }
            self.done(p.missed == 0 ? "You thread the rocks without a scratch" : "The hull scrapes \(p.missed) time\(p.missed == 1 ? "" : "s"): \(Int(d)) hull lost")
        }
        p.total = 6
        p.life = 1.25 + 0.3 * E("look")
        startPlay(p)
    }
    /// Opens a few of a row of spots and reports what was found.
    private func playPick(_ theme: String, _ title: String, _ hint: String, _ spots: [Int], _ picks: Int, _ trouble: @escaping () -> String) {
        let p = Play(.pick, theme, title, hint) { [unowned self] p in
            var parts: [String] = []
            var g = 0
            for what in p.found {
                switch what {
                case 1: g += rndI(30, 70)
                case 2: g += Int(Double(rndI(160, 280)) * (theme == "island" && self.hasMap ? 2.2 : 1))
                case 3: parts.append("+\(self.addGood("food", 8)) food")
                case 4: parts.append("+\(self.addGood("planks", 5)) planks")
                case 5: parts.append("+\(self.addGood("powder", 3)) powder")
                case 6: parts.append("+\(self.addGood("water", 10)) water")
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
        p.open = [Double](repeating: -1, count: spots.count)
        p.picksLeft = picks
        startPlay(p)
    }
    // ---------- things that happen ashore
    func playDock() {
        let p = Play(.timing, "dock", "Work on the docks", "Swing each load aboard as the crane comes over") { [unowned self] p in
            let g = p.score * 14 + p.perfect * 8
            self.gold += g
            self.portJobDone = true
            if g > 0 { self.snd?.coin() }
            self.done(g > 0 ? "The merchant counts out \(g) gold for \(p.score) loads" : "Every load in the harbour. No pay today")
        }
        p.rounds = 5
        p.zone = 0.24
        p.speed = 1.2
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
            self.done(p.missed == 0 ? "Not one got aboard. The harbour master pays a 20 gold bounty" : "\(p.missed) got into the hold: \(Int(eaten)) food spoiled")
        }
        p.total = 6
        p.life = 1.2
        startPlay(p)
    }
    func playBarrels() {
        portJobDone = true
        var s = [3, 6, 4, 1, 0]
        if chance(0.35) { s[4] = 8 }
        playPick("wreck", "An old sailor's gift", "\"Sailed with your father, I did. Take two, with my blessing.\"", s, 2) { return "" }
    }
    func joinFestival() {
        portJobDone = true
        festT = 14
        snd?.good()
        let f = addGood("food", 6)
        var healed = ""
        if let m = men.first(where: { !$0.fit }) { m.st = 0; m.d = 0; healed = " " + m.n + " is back on his feet." ; autoPost() }
        show("Festival night", "Drums, roast pig and fireworks over the harbour. The crew come back singing.\n+\(f) food from the feast." + healed, [Opt("Watch the fireworks") { [unowned self] in self.card = nil }])
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
        playPick("ghost", "Ghost ship", "Three hatches on her deck. You dare open two", s, 2) { [unowned self] in
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
}

extension Game {
    func drawSummary(_ c: Canvas) {
        guard let s = sum else { return }
        hits.removeAll(keepingCapacity: true)
        let t = sumT
        func eo(_ k: Double) -> Double { let x = 1 - clampD(k, 0, 1); return 1 - x * x * x }
        c.R(0, 0, W, H, Col(0x000000, 0.5 * eo(t / 0.3)))
        let pw = min(W - safeL - safeR - 40, 560), ph = min(H - 44, 322.0)
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
            ("day", "Days at sea", s.days, "", false),
            ("hull", "Leagues sailed", s.leagues, "", false),
            ("arms", "Events met" + (s.fights > 0 ? " · \(s.fights) fight\(s.fights == 1 ? "" : "s")" : ""), s.events, "", false),
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
            let rx = px + 20 + Double(col) * (colW + 14), ry = py + 88 + Double(row) * 44
            c.save()
            c.alpha(a)
            c.translate(14 * (1 - a), 0)
            c.RR(rx, ry, colW, 38, 9, Col(0x1c1108, 0.7))
            c.RRStroke(rx, ry, colW, 38, 9, 1, Col(0xd2a455, 0.45))
            icon(c, r.0, rx + 20, ry + 19, 22)
            c.text(r.1, rx + 40, ry + 24, 14, CREAM, -1, FONT)
            let n = Int((Double(r.2) * eo((t - st) / 0.6)).rounded())
            let shown = r.0 == "crew" && s.lost == 0 ? "✓" : r.3.replacingOccurrences(of: "%", with: "") + "\(n)" + (r.3 == "%" ? "%" : "")
            c.text(shown, rx + colW - 12, ry + 26, 19, r.4 ? Col(0xff9a8a) : GOLD, 1, FONTB)
            c.restore()
        }
        // the verdict, stamped on
        let vt = 0.7 + 6 * 0.34 + 0.25
        if t > vt {
            let hard = s.lost > 0 || s.hull < 50
            let swift = !hard && s.days <= Int((Double(s.leagues) / 44).rounded(.up))
            let word = hard ? "A HARD PASSAGE" : (swift ? "A SWIFT PASSAGE" : "A FAIR PASSAGE")
            let vc = hard ? Col(0xff7a5a) : (swift ? Col(0xffe08a) : Col(0x9ff0aa))
            let q = clampD((t - vt) / 0.22, 0, 1)
            if sumRow < 99 { sumRow = 99; snd?.thud(); if !hard { snd?.good() }; shake = 0.12; puff(W / 2, py + 244, 30, vc, 260, 320, 3, 0.7) }
            c.save()
            c.alpha(q)
            c.translate(W / 2, py + 238)
            c.rotate(-0.04)
            c.scale(2.2 - 1.2 * q, 2.2 - 1.2 * q)
            let tw = textW(word, 22, FONTD) + 36
            c.RRStroke(-tw / 2, -20, tw, 34, 6, 2.5, vc)
            c.text(word, 0, 5, 22, vc, 0, FONTD)
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
