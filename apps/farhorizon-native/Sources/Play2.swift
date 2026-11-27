import CoreGraphics
import Foundation

// More ways to play, so the games are not all one thing:
//   hold  — hold down to build power, let go in the green
//   steer — slide a finger to steer the ship past what is coming
//   swipe — swipe the way the arrow points, quickly
//   beat  — tap as the ring closes on the circle, in time
//   reel  — tap fast to haul in, ease off when the line strains
// (the sixth, watch-then-repeat, lives with the crates in Play.swift)

extension Game {
    func barBox() -> (Double, Double, Double, Double) {
        let w = min(W * 0.62, 480.0)
        return ((W - w) / 2, H - safeB - 58, w, 24)
    }
    func endPlay(_ p: Play) { p.endT = 1.6; p.endLen = 1.6 }

    func updatePlay2(_ p: Play, _ dt: Double) {
        p.v = max(0, p.v - dt)
        if p.wait > 0 {
            p.wait -= dt
            if p.wait <= 0 { nextRound2(p) }
            return
        }
        switch p.kind {
        case .hold:
            if p.held {
                p.a += p.dir * p.speed * dt
                if p.a >= 1 { p.a = 1; p.dir = -1 }
                if p.a <= 0 { p.a = 0; p.dir = 1 }
                // a tick that climbs with the power, so it can be judged by ear
                let step = Int(p.a * 10)
                if step != p.cur { p.cur = step; snd?.tone(260 + p.a * 520, 0.05, 0, 0.03) }
            }
        case .steer:
            p.a += (p.b - p.a) * min(1, dt * 10)
            p.spawnT -= dt
            if p.spawned < p.total && p.spawnT <= 0 {
                p.spawned += 1
                p.spawnT = p.life
                if p.theme == "storm" {
                    p.obst.append((rnd(0.2, 0.8), 0, p.zone, false))
                } else {
                    p.obst.append((clampD(p.a + rnd(-0.3, 0.3), 0.1, 0.9), 0, 0.09, false))
                }
            }
            for i in 0..<p.obst.count {
                p.obst[i].y += p.speed * dt
                if !p.obst[i].done && p.obst[i].y >= 0.84 {
                    p.obst[i].done = true
                    let off = abs(p.a - p.obst[i].x)
                    let struck = p.theme == "storm" ? off > p.obst[i].w : off < p.obst[i].w + 0.035
                    let (bx, by, bw, _) = barBox()
                    let px = bx + bw * p.a
                    let spy = H - safeB - 158 + 130 * 0.84
                    puff(px, spy, struck ? 14 : 5, struck ? Col(0xffffff, 0.9) : Col(0x9ff0aa, 0.8), struck ? 200 : 90, 240, 2.4, 0.45)
                    if struck {
                        p.missed += 1
                        p.streak = 0
                        shake = max(shake, 0.3)
                        snd?.thud(); buzz?(true)
                        p.pop(px, by - 60, p.theme == "storm" ? "Broadside on!" : "Struck!", false)
                        p.say(p.theme == "storm" ? "A sea breaks over the rail!" : "Struck a rock!", false)
                    } else {
                        p.score += 1
                        p.streak += 1
                        snd?.good(); buzz?(false)
                        let margin = p.theme == "storm" ? p.obst[i].w - off : off - p.obst[i].w - 0.035
                        let close = p.theme != "storm" && margin < 0.05
                        if close { p.perfect += 1 }
                        p.pop(px, by - 60, p.theme == "storm" ? "Over it!" : (close ? "A close shave!" : "Clear!"), true, big: close)
                        if p.streak >= 3 { p.pop(px + 90, by - 40, "\(p.streak) in a row!", true) }
                    }
                }
            }
            p.obst.removeAll { $0.y > 1.12 }
            if p.spawned >= p.total && p.obst.isEmpty { p.rounds = p.total; endPlay(p) }
        case .swipe:
            p.a -= dt
            if p.a <= 0 {
                swipeMiss(p, "Too slow!")
                p.held = false
                p.wait = 0.3
            }
        case .beat:
            let before = p.tb
            p.tb -= dt
            if before > 0 && p.tb <= 0 { snd?.thud(); p.v = 0.18 }
            if p.tb < -p.life / 2 {
                if !p.held {
                    p.marks.append(0)
                    p.streak = 0
                    p.pop(W / 2, H - safeB - 150, "Missed the beat", false)
                }
                p.tries += 1
                p.held = false
                if p.tries >= p.rounds { endPlay(p); return }
                p.life *= 0.94
                p.tb += p.life
            }
        case .reel:
            p.spawnT -= dt
            if p.spawnT <= 0 {
                p.dir = -p.dir
                p.spawnT = p.dir < 0 ? rnd(0.9, 1.5) : rnd(1.4, 2.4)
                if p.dir < 0 { snd?.splash() }
            }
            let surge = p.dir < 0
            p.b = max(0, p.b - dt * (surge ? 0.25 : 0.6))
            p.a = min(1, p.a + dt * (surge ? 0.1 : 0.02))
            p.tb -= dt
            if p.tb <= 0 { reelFail(p, "It got away") }
        default: break
        }
    }

    func nextRound2(_ p: Play) {
        switch p.kind {
        case .hold:
            if p.tries >= p.rounds || (p.stopOnHit && p.score > 0) { endPlay(p); return }
            p.a = 0; p.dir = 1
            p.b = min(rnd(0.5, 0.88), 1 - p.zone / 2)
            p.speed *= 1.12
        case .swipe:
            p.spawned += 1
            if p.spawned >= p.total {
                // the last bucket: steam where the fire was, if the chain did its work
                if p.missed <= 2 { puff(W * 0.66, quayY() - 24, 26, Col(0xe8e8e8, 0.8), 130, -40, 4, 1.2) }
                endPlay(p); return
            }
            var d = rndI(0, 3)
            if d == p.cur { d = (d + 1) % 4 }
            p.cur = d
            p.life *= 0.95
            p.a = p.life
        case .reel:
            if p.tries >= p.rounds || (p.stopOnHit && p.score > 0) { endPlay(p); return }
            p.a = 1; p.b = 0; p.cur = 0; p.dir = 1
            p.spawnT = rnd(1.2, 2.0)
            p.tb = p.life
        default: break
        }
    }

    func tapPlay2(_ p: Play, _ x: Double, _ y: Double) {
        if p.wait > 0 { return }
        switch p.kind {
        case .hold:
            p.held = true; p.a = 0; p.dir = 1
        case .steer:
            steerTo(p, x)
        case .swipe:
            p.held = true
        case .beat:
            beatTap(p)
        case .reel:
            reelTap(p)
        default: break
        }
    }
    func movePlay(_ x: Double, _ y: Double) {
        guard let p = play, p.endT < 0, card == nil, !p.intro else { return }
        if p.kind == .steer { steerTo(p, x) }
        if p.kind == .swipe && p.held && p.wait <= 0 {
            let dx = x - downX, dy = y - downY
            if dx * dx + dy * dy > 36 * 36 {
                p.held = false
                let d = abs(dx) > abs(dy) ? (dx > 0 ? 0 : 2) : (dy > 0 ? 1 : 3)
                swipeDone(p, d)
            }
        }
    }
    func releasePlay(_ x: Double, _ y: Double) {
        guard let p = play, p.endT < 0, !p.intro else { return }
        if p.kind == .hold && p.held && p.wait <= 0 { holdRelease(p) }
        if p.kind == .swipe { p.held = false }
    }

    private func steerTo(_ p: Play, _ x: Double) {
        let (bx, _, bw, _) = barBox()
        p.b = clampD((x - bx) / bw, 0.06, 0.94)
    }

    private func holdRelease(_ p: Play) {
        p.held = false
        p.tries += 1
        let d = abs(p.a - p.b)
        let (bx, by, bw, _) = barBox()
        let px = bx + bw * p.a
        if d < p.zone / 2 {
            let perfect = d < p.zone / 6
            p.score += 1
            if perfect { p.perfect += 1; p.flash = 0.35 }
            p.marks.append(perfect ? 2 : 1)
            p.pop(px, by - 36, perfect ? "PERFECT!" : "Good", true, big: perfect)
            snd?.good(); buzz?(false)
            puff(px, by, perfect ? 26 : 14, Col(0xffe08a), 220, 300, 2.6, 0.5)
            if p.theme == "strong" {
                snd?.bell()
                p.say(perfect ? "The bell rings clean off its post!" : "The bell rings!", true)
            } else {
                snd?.splash()
                p.say("He has the line!", true)
            }
        } else {
            p.marks.append(0)
            let short = p.a < p.b
            p.pop(px, by - 36, short ? "Too soft" : "Too hard", false)
            snd?.thud(); buzz?(true)
            if p.theme == "strong" {
                p.say(short ? "Not even halfway" : "Past the bell and off the top", false)
            } else {
                snd?.splash()
                p.say(short ? "The line falls short" : "Clean over his head", false)
            }
        }
        p.wait = 0.9
    }

    private func swipeDone(_ p: Play, _ d: Int) {
        let cx = W / 2, cy = H - safeB - 92
        if d == p.cur {
            p.score += 1
            let quick = p.a > p.life * 0.55
            if quick { p.perfect += 1 }
            p.streak += 1
            p.pop(cx, cy - 64, quick ? "Quick!" : "Good", true, big: quick)
            if p.streak >= 3 { p.pop(cx + 120, cy - 40, "\(p.streak) in a row!", true) }
            snd?.splash(); buzz?(false)
            puff(cx, cy, 14, Col(0xbfe6ff), 200, 300, 2.4, 0.5)
            puff(W * 0.66, quayY() - 26, 16, Col(0xdff2ff, 0.9), 180, 320, 2.6, 0.5)
            p.v = 0.3
        } else {
            swipeMiss(p, "Wrong way!")
        }
        p.wait = 0.3
    }
    private func swipeMiss(_ p: Play, _ s: String) {
        p.missed += 1
        p.streak = 0
        p.pop(W / 2, H - safeB - 160, s, false)
        p.say("The fire spreads!", false)
        snd?.thud(); buzz?(true)
        shake = max(shake, 0.2)
    }

    private func beatTap(_ p: Play) {
        if p.held || p.tb > p.life * 0.5 + 0.01 { return }
        p.held = true
        let e = abs(p.tb)
        let cx = W / 2, cy = H - safeB - 84
        if e < 0.16 {
            let perfect = e < 0.07
            p.score += 1
            if perfect { p.perfect += 1; p.flash = 0.25 }
            p.marks.append(perfect ? 2 : 1)
            p.streak += 1
            p.pop(cx, cy - 66, perfect ? "PERFECT!" : "Good", true, big: perfect)
            if p.streak >= 2 { p.pop(cx + 120, cy - 40, "\(p.streak) in a row!", true) }
            snd?.good(); buzz?(false)
            puff(cx, cy, perfect ? 22 : 12, Col(0xffe08a), 200, 300, 2.4, 0.5)
            if p.theme == "row" {
                snd?.splash()
                p.say(perfect ? "All together. She moves!" : "A good stroke", true)
            } else {
                snd?.coin()
                p.say(perfect ? "Stowed like a master!" : "Aboard she goes", true)
            }
        } else {
            p.marks.append(0)
            p.streak = 0
            p.pop(cx, cy - 66, p.tb > 0 ? "Too soon" : "Too late", false)
            snd?.thud(); buzz?(true)
            p.say(p.theme == "row" ? "The oars clash" : "The load swings wide!", false)
        }
    }

    private func reelTap(_ p: Play) {
        let surge = p.dir < 0
        p.a -= p.speed
        p.b += surge ? 0.3 : 0.13
        if p.b > 0.8 { p.cur = 1 }
        let (bx, by, bw, _) = barBox()
        if p.b >= 1 {
            shake = max(shake, 0.3)
            reelFail(p, "The line parts!")
        } else if p.a <= 0 {
            p.a = 0
            p.score += 1
            let clean = p.cur == 0
            if clean { p.perfect += 1; p.flash = 0.3 }
            p.marks.append(clean ? 2 : 1)
            p.tries += 1
            p.pop(bx + bw / 2, by - 60, clean ? "A clean haul!" : "Landed!", true, big: clean)
            p.say(p.theme == "turtle" ? "Over the rail she comes!" : (clean ? "A big one!" : "Hooked!"), true)
            snd?.good(); snd?.splash(); buzz?(false)
            puff(bx + bw / 2, by, 20, Col(0xffffff, 0.9), 200, 300, 2.6, 0.5)
            p.wait = 0.9
        } else {
            buzz?(false)
            p.v = 0.12
            let (sx, wy, len) = shipSpot()
            puff(sx - len * (0.55 + 0.45 * p.a), wy + 18, 4, Col(0xffffff, 0.8), 90, 260, 2, 0.3)
            if surge { snd?.creak() } else { snd?.tone(520 + (1 - p.a) * 300, 0.04, 0, 0.03) }
        }
    }
    private func reelFail(_ p: Play, _ s: String) {
        let (bx, by, bw, _) = barBox()
        p.marks.append(0)
        p.tries += 1
        p.pop(bx + bw / 2, by - 60, s, false)
        p.say(p.theme == "turtle" ? "She dives, and is gone" : "It slipped the hook", false)
        snd?.thud(); buzz?(true)
        p.wait = 0.9
    }

    private func marksRow(_ c: Canvas, _ p: Play, _ y: Double) {
        let n = p.rounds
        for i in 0..<n {
            let mx = W / 2 + (Double(i) - Double(n - 1) / 2) * 20
            let m = i < p.marks.count ? p.marks[i] : -1
            var col = Col(0x0c0805, 0.7)
            if m == 2 { col = Col(0xffe08a) } else if m == 1 { col = Col(0x7fd88a) } else if m == 0 { col = Col(0xd8432f) }
            c.circ(mx, y, 6, col)
            c.circStroke(mx, y, 6, 1, Col(0xd2a455, 0.7))
        }
    }
    private func darkBar(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        c.RR(x - 3, y - 3, w + 6, h + 6, 14, Col(0x000000, 0.4))
        c.RRGrad(x, y, w, h, 12, [(0, Col(0x4a2f18)), (1, Col(0x2a1a0c))])
        c.RRStroke(x, y, w, h, 12, 1.4, Col(0xd2a455, 0.8))
    }

    func drawPlay2(_ c: Canvas, _ p: Play) {
        let (sx, wy, len) = shipSpot()
        let (bx, by, bw, bh) = barBox()
        switch p.kind {
        case .hold:
            if p.theme == "line" {
                // the man in the water, and the line going out to him
                let mx = sx - len * 0.75, my = wy + 22 + sin(T * 3) * 3
                c.ellStroke(mx, my + 4, 16 + sin(T * 4) * 3, 4, 1.2, Col(0xffffff, 0.6))
                c.circ(mx, my - 4, 5, Col(0xe3b58a))
                c.seg(mx - 3, my, mx - 10, my - 12 + sin(T * 9) * 3, 2.2, Col(0xe3b58a))
                c.seg(mx + 3, my, mx + 10, my - 12 - sin(T * 9) * 3, 2.2, Col(0xe3b58a))
                if p.a > 0.02 {
                    let ox = sx - len * 0.45, oy = wy - len * 0.12
                    let land = ox + (mx - ox) * (p.a / max(0.2, p.b))
                    c.curve(ox, oy, (ox + land) / 2, oy - 30 - 50 * p.a, land, my, 1.6, Col(0xd9cdb0))
                    c.circStroke(land, my, 6, 2.4, Col(0xf2e6c8))
                }
            } else {
                // the strongman's tower: a puck on a post and a bell to reach
                var tx = bx + bw + 34
                if tx + 22 > W - safeR { tx = bx - 34 }
                let y0 = H - safeB - 30, th = 150.0
                c.RR(tx - 16, y0 - 4, 32, 10, 3, Col(0x4a2f18))
                c.R(tx - 3, y0 - th - 14, 6, th + 12, Col(0x8a6238))
                let yb = y0 - th * p.b
                c.R(tx - 9, yb - th * p.zone / 2, 18, th * p.zone, Col(0x7fd88a, 0.45))
                c.arcFill(tx, yb + 4, 10, PI, PI * 2, Col(0xd9a441))
                c.R(tx - 11, yb + 3, 22, 3, Col(0xb0802c))
                c.circ(tx, yb + 8, 2.4, Col(0x6b4a26))
                c.RR(tx - 10, y0 - th * p.a - 5, 20, 8, 2, REDC)
                // the man with the hammer, winding up while you hold
                let side: Double = tx > W / 2 ? -1 : 1
                let wind = p.held ? 2.4 - p.a * 1.2 + sin(T * 20) * 0.05 : 0.6
                c.save(); c.translate(tx + side * 40, y0 + 6); c.scale(2.6, 2.6)
                tar(c, 0, 0, Col(0x8a2a22), 1, lean: side * -0.1, aL: wind, aR: wind)
                c.restore()
            }
            darkBar(c, bx, by, bw, bh)
            let zw = bw * p.zone
            let zx = bx + bw * p.b - zw / 2
            c.RRGrad(zx, by, zw, bh, 6, [(0, Col(0x7fd88a)), (1, Col(0x3a9a4c))])
            c.RR(zx + zw / 3, by, zw / 3, bh, 4, Col(0xffe08a, 0.95))
            let fw = bw * clampD(p.a, 0, 1)
            if fw > 8 { c.RRGrad(bx, by + 5, fw, bh - 10, 5, [(0, Col(0xffb040, 0.9)), (1, Col(0xff7a2a, 0.9))]) }
            c.RR(bx + fw - 3.5, by - 7, 7, bh + 14, 3.5, WHITE)
            let hint = p.endT >= 0 ? "" : (p.held ? "Let go in the green" : "Hold down to build power, then let go")
            c.textS(hint, W / 2, by + bh + 22, 13, CREAM, 0, FONTI)
            marksRow(c, p, by - 18)
        case .steer:
            let ph = 130.0, py = H - safeB - ph - 28
            c.RR(bx + 2, py + 3, bw, ph, 12, Col(0x000000, 0.35))
            c.RRGrad(bx, py, bw, ph, 12, [(0, Col(0x14324a, 0.93)), (1, Col(0x0c2236, 0.93))])
            c.RRStroke(bx, py, bw, ph, 12, 1.8, Col(0xd2a455))
            let drift = (T * p.speed).truncatingRemainder(dividingBy: 0.2)
            for j in 0..<5 {
                let ly = py + (Double(j) * 0.2 + drift) * ph
                c.seg(bx + 12, ly, bx + bw - 12, ly, 1, Col(0xffffff, 0.07))
            }
            for o in p.obst where o.y >= 0.04 && o.y <= 0.98 {
                let oy = py + o.y * ph
                if p.theme == "storm" {
                    let gl = bx + bw * (o.x - o.w), gr = bx + bw * (o.x + o.w)
                    if gl - bx > 16 { c.RR(bx + 5, oy - 5, gl - bx - 5, 10, 5, Col(0xffffff, 0.85)) }
                    if bx + bw - gr > 16 { c.RR(gr, oy - 5, bx + bw - 5 - gr, 10, 5, Col(0xffffff, 0.85)) }
                    // the gap to steer for
                    c.poly(Col(0x9ff0aa, 0.5 + 0.3 * sin(T * 8)), [bx + bw * o.x - 7, oy - 4, bx + bw * o.x + 7, oy - 4, bx + bw * o.x, oy + 7])
                } else {
                    let al = clampD((o.y - p.fade) / 0.15, 0, 1)
                    let ox = bx + bw * o.x, rw = bw * o.w
                    c.poly(Col(0x6a7078, al), [ox - rw, oy + 8, ox - rw * 0.3, oy - 12, ox + rw * 0.2, oy - 4, ox + rw * 0.6, oy - 14, ox + rw, oy + 8])
                    c.poly(Col(0x3e444c, al), [ox + rw * 0.2, oy - 4, ox + rw * 0.6, oy - 14, ox + rw, oy + 8, ox + rw * 0.3, oy + 8])
                    c.ellStroke(ox, oy + 8, rw * 1.1, 3, 1, Col(0xffffff, 0.5 * al))
                }
            }
            let shx = bx + bw * p.a, shy = py + ph * 0.84
            // she leans the way she is turning, and leaves a wake
            let lean = clampD((p.b - p.a) * 60, -9, 9)
            c.seg(shx - 6, shy + 12, shx - 12 - lean, py + ph - 6, 1.4, Col(0xffffff, 0.35))
            c.seg(shx + 6, shy + 12, shx + 12 - lean, py + ph - 6, 1.4, Col(0xffffff, 0.35))
            c.poly(Col(0x8a5a2c), [shx + lean, shy - 16, shx + 8 + lean * 0.4, shy - 2, shx + 7, shy + 12, shx - 7, shy + 12, shx - 8 + lean * 0.4, shy - 2])
            c.poly(Col(0xf2e6c8), [shx + lean * 0.7, shy - 8, shx + 5, shy + 6, shx - 5, shy + 6])
            c.textS(p.endT >= 0 ? "" : "Slide your finger left and right to steer", W / 2, py + ph + 18, 13, CREAM, 0, FONTI)
            c.textS("\(p.score) / \(p.total)", bx + bw - 30, py + 18, 13, CREAM, 0, FONTB)
        case .swipe:
            // the blaze the buckets are going to: it shrinks as they arrive
            let fx = W * 0.66, fy = quayY() - 4
            let f = clampD(1 - Double(p.score) / Double(max(1, p.total)) + 0.12 * Double(p.missed), 0.12, 1.3)
            c.glow(fx, fy - 20 * f, 70 * f, Col(0xffb040, 0.45), Col(0xffb040, 0))
            for j in 0..<5 {
                let ox = fx + (Double(j) - 2) * 14 * f
                let h = (34 + sin(T * 11 + Double(j) * 1.7) * 8) * f
                c.poly(Col(0xff7a2a), [ox - 9 * f, fy, ox, fy - h, ox + 9 * f, fy])
                c.poly(Col(0xffe08a), [ox - 4 * f, fy, ox, fy - h * 0.55, ox + 4 * f, fy])
            }
            // the chain of hands from the harbour to the fire, a bucket going down it
            let x0 = W * 0.36, qy = quayY() + 2
            for j in 0..<5 {
                let hx = x0 + (fx - 30 - x0) * Double(j) / 4
                let sw = sin(T * 6 + Double(j) * 1.2) * 0.4
                c.save(); c.translate(hx, qy); c.scale(2.0, 2.0)
                tar(c, 0, 0, [Col(0x2a5a8a), Col(0x8a2a22), Col(0x3a6a3a), Col(0x6a4a8a)][j % 4], 1, aL: 0.9 + sw, aR: 0.9 - sw)
                c.restore()
            }
            if p.v > 0 {
                let bk = 1 - p.v / 0.3
                let bxx = x0 + (fx - 30 - x0) * bk, byy = qy - 22 - sin(bk * PI) * 10
                c.poly(Col(0x8a6238), [bxx - 5, byy - 5, bxx + 5, byy - 5, bxx + 4, byy + 4, bxx - 4, byy + 4])
                c.R(bxx - 4, byy - 5, 8, 2, Col(0xbfe6ff))
            }
            let cx = W / 2, cy = H - safeB - 92
            if p.wait <= 0 && p.endT < 0 {
                let k = clampD(p.a / max(0.1, p.life), 0, 1)
                c.circ(cx, cy, 46, Col(0x1c1108, 0.9))
                c.circStroke(cx, cy, 46, 2, Col(0xd2a455))
                c.arcStroke(cx, cy, 52, -PI / 2, -PI / 2 + PI * 2 * k, 4, k < 0.3 ? Col(0xff5a3c) : Col(0x7fd88a))
                // the arrow, built by hand so it cannot point the wrong way
                let ux = [1.0, 0.0, -1.0, 0.0][p.cur % 4], uy = [0.0, 1.0, 0.0, -1.0][p.cur % 4]
                let nud = sin(T * 9) * 4
                let shape: [(Double, Double)] = [(-24, -9), (2, -9), (2, -22), (28, 0), (2, 22), (2, 9), (-24, 9)]
                var pts: [Double] = []
                for q in shape {
                    let ax = q.0 + nud, ay = q.1
                    pts.append(cx + ax * ux - ay * uy)
                    pts.append(cy + ax * uy + ay * ux)
                }
                c.poly(Col(0xffe08a), pts)
            }
            c.textS(p.endT >= 0 ? "" : "Swipe the way the arrow points", W / 2, H - safeB - 26, 13, CREAM, 0, FONTI)
            c.textS("Buckets passed \(p.score) / \(p.total)", W / 2, H - safeB - 8, 13, CREAM, 0, FONTB)
        case .beat:
            let cx = W / 2, cy = H - safeB - 84, R = 30.0
            if p.theme == "row" {
                // the sweeps, dipping together
                let ph2 = p.tb / max(0.1, p.life) * PI * 2
                for j in 0..<4 {
                    let ox = sx + (Double(j) - 1.5) * len * 0.13
                    c.seg(ox, wy - len * 0.03, ox + cos(ph2) * 16, wy + 14 + sin(ph2) * 5, 2, Col(0xc9a86a))
                }
            }
            if p.theme == "dock" {
                // the load swinging on the crane: it is over the hold on the beat
                let sw = sin(p.tb / max(0.1, p.life) * PI) * 70
                let lx = cx + sw, ly = cy - 78
                c.seg(cx, cy - 150, lx, ly - 10, 1.4, Col(0x3a2412))
                c.RR(lx - 13, ly - 10, 26, 20, 3, Col(0xa8823f)); c.RRStroke(lx - 13, ly - 10, 26, 20, 3, 1.4, Col(0x5a3d20))
                c.seg(lx - 13, ly - 10, lx + 13, ly + 10, 1.2, Col(0x5a3d20)); c.seg(lx + 13, ly - 10, lx - 13, ly + 10, 1.2, Col(0x5a3d20))
            }
            if p.endT < 0 && p.tries == 0 && p.tb > p.life * 0.5 { c.textS("Ready...", cx, cy - 50, 18, Col(0xfff2a0), 0, FONTB) }
            c.circ(cx, cy, R + 9, Col(0x1c1108, 0.88))
            c.circStroke(cx, cy, R, 3, Col(0xffe08a))
            if p.v > 0 { c.circ(cx, cy, R, Col(0xfff2a0, min(1, p.v * 4))) }
            if p.endT < 0 {
                let k = p.tb / max(0.1, p.life)
                if k > 0 {
                    c.circStroke(cx, cy, R + min(1.5, k) * 80, 3, Col(0xffffff, clampD(1.2 - k, 0.15, 1)))
                } else {
                    c.circStroke(cx, cy, max(4, R + k * 40), 2, Col(0xffffff, clampD(1 + k * 2.5, 0, 1)))
                }
            }
            c.textS(p.endT >= 0 ? "" : "Tap as the ring closes on the circle", W / 2, H - safeB - 26, 13, CREAM, 0, FONTI)
            marksRow(c, p, H - safeB - 8)
        case .reel:
            let surge = p.dir < 0
            let ox = sx - len * 0.45, oy = wy - len * 0.12
            let fx = sx - len * (0.55 + 0.45 * p.a)
            let wobF: Double = surge ? 14 : 3
            let wobA: Double = surge ? 4 : 2
            let leap: Double = surge && p.theme != "turtle" ? abs(sin(T * 5)) * 16 : 0
            let fy = wy + 18 + sin(T * wobF) * wobA - leap
            // the rod over the stern, bending as the strain comes on
            c.curve(ox + 14, oy + 10, ox + 4, oy - 6, ox - 2 - p.b * 6, oy + p.b * 10, 2, Col(0x6b4a26))
            c.curve(ox, oy, (ox + fx) / 2, oy + 10 + 30 * (1 - p.b), fx, fy, 1.4, p.b > 0.75 ? Col(0xff5a3c) : Col(0xfff6d8, 0.9))
            if p.theme == "turtle" {
                c.ell(fx, fy, 18, 10, Col(0x4a6a3a)); c.ell(fx - 2, fy - 2, 13, 6, Col(0x6a8a4a))
                c.ell(fx - 20, fy - 1, 6, 4.5, Col(0x8aa06a)); c.circ(fx - 23, fy - 2.5, 1, Col(0x0c1014))
                let flF: Double = surge ? 9 : 3
                let fl = sin(T * flF) * 4
                c.ell(fx - 9, fy + 9 + fl, 8, 3, Col(0x5a7a4a)); c.ell(fx + 11, fy + 9 - fl, 7, 2.5, Col(0x5a7a4a))
            } else {
                c.ell(fx, fy, 11, 4.5, Col(0x9ab6c6)); c.poly(Col(0x7a96a6), [fx - 10, fy, fx - 18, fy - 6, fx - 18, fy + 6])
                c.circ(fx + 6, fy - 1, 0.9, Col(0x0c1014))
            }
            let ringR: Double = surge ? 26 + sin(T * 12) * 5 : 18
            let ringA: Double = surge ? 0.85 : 0.5
            c.ellStroke(fx, fy + 6, ringR, 4, 1.2, Col(0xffffff, ringA))
            // how far there is still to haul
            let ty = by - 30
            c.RR(bx, ty, bw, 6, 3, Col(0x0c0805, 0.7))
            let hw = bw * clampD(1 - p.a, 0, 1)
            if hw > 6 { c.RR(bx, ty, hw, 6, 3, Col(0xffe08a)) }
            icon(c, p.theme == "turtle" ? "food" : "bait", bx + hw, ty + 3, 18)
            // the strain on the line
            darkBar(c, bx, by, bw, bh)
            if surge { c.RRStroke(bx - 2, by - 2, bw + 4, bh + 4, 13, 3, Col(0xff5a3c, 0.6 + 0.4 * sin(T * 20))) }
            let tw = bw * clampD(p.b, 0, 1)
            var tcol = Col(0x7fd88a)
            if p.b > 0.75 { tcol = Col(0xff5a3c) } else if p.b > 0.5 { tcol = Col(0xffb040) }
            if tw > 8 { c.RR(bx + 2, by + 4, tw - 2, bh - 8, 5, tcol) }
            c.R(bx + bw * 0.8, by - 3, 2, bh + 6, Col(0xff5a3c))
            c.textS("LINE STRAIN", bx + bw / 2, by + bh / 2 + 4, 11, CREAM.alpha(0.85), 0, FONTB)
            c.textS("\(max(0, Int(p.tb.rounded(.up))))s", bx + bw + 22, by + bh / 2 + 5, 13, p.tb < 3 ? Col(0xff9a8a) : CREAM, 0, FONTB)
            let hint = p.endT >= 0 || p.wait > 0 ? "" : (surge ? "It runs! Ease off" : "Tap fast to reel in")
            c.textS(hint, W / 2, by + bh + 22, 14, surge ? Col(0xff9a8a) : CREAM, 0, surge ? FONTB : FONTI)
            if p.v > 0 { c.RRStroke(bx - 2, ty - 2, bw + 4, 10, 5, 2, Col(0xfff6d8, min(1, p.v * 8))) }
            if p.rounds > 1 {
                c.textS("Fish \(min(p.rounds, p.tries + 1)) of \(p.rounds) · landed \(p.score)", bx + bw / 2, ty - 10, 13, CREAM, 0, FONTB)
            }
        default: break
        }
    }

    // ---------- watch, then repeat: an opening act for some of the crate games

    func updateMemory(_ p: Play) {
        if p.phase != 1 { return }
        let k = Int(floor((p.t - 0.9) / 0.55))
        if k >= p.seq.count { p.phase = 2; p.seqI = 0; return }
        if k >= 0 && k != p.cur {
            p.cur = k
            snd?.tone(440 + Double(p.seq[k]) * 90, 0.16, 1, 0.09)
        }
    }
    /// A tap while repeating the order. Returns true if the tap was used up here.
    func tapMemory(_ p: Play, _ x: Double, _ y: Double) -> Bool {
        if p.phase == 1 { return true }
        if p.phase != 2 { return false }
        let r = pickRects(p)
        for (i, q) in r.enumerated() where x >= q.0 && x <= q.0 + q.2 && y >= q.1 - 10 && y <= q.1 + q.3 + 10 {
            let cx = q.0 + q.2 / 2
            if i == p.seq[p.seqI] {
                p.seqI += 1
                p.lastTap = i; p.lastTapT = p.t
                snd?.tone(440 + Double(i) * 90, 0.16, 1, 0.09)
                buzz?(false)
                if p.seqI >= p.seq.count {
                    p.phase = 0
                    p.known = true
                    p.flash = 0.3
                    snd?.good()
                    p.pop(W / 2, q.1 - 30, "Well remembered!", true, big: true)
                }
            } else {
                p.phase = 0
                p.known = false
                shake = max(shake, 0.2)
                snd?.bad(); buzz?(true)
                p.pop(cx, q.1 - 16, "Wrong order", false)
            }
            return true
        }
        return true
    }
    /// What the watch-and-repeat adds to a closed crate: the flash, and afterwards what was learned.
    func drawMemoryMark(_ c: Canvas, _ p: Play, _ i: Int, _ q: (Double, Double, Double, Double), _ cx: Double, _ iy: Double) {
        var lit = false
        if p.phase == 1 {
            let tt = (p.t - 0.9) / 0.55
            let k = Int(floor(tt))
            if k >= 0 && k < p.seq.count && p.seq[k] == i && tt - Double(k) < 0.7 { lit = true }
        }
        if p.phase != 1 && p.lastTap == i && p.t - p.lastTapT < 0.25 { lit = true }
        if lit {
            c.RR(q.0, q.1, q.2, q.3, 12, Col(0xfff2a0, 0.5))
            c.RRStroke(q.0 - 2, q.1 - 2, q.2 + 4, q.3 + 4, 13, 3, Col(0xfff6d8))
            var n = p.seqI
            if p.phase == 1 { n = Int(floor((p.t - 0.9) / 0.55)) + 1 }
            c.circ(cx, q.1 - 4, 11, Col(0x1c1108, 0.9)); c.circStroke(cx, q.1 - 4, 11, 1.5, Col(0xffe08a))
            c.text("\(n)", cx, q.1 + 1, 14, Col(0xfff2a0), 0, FONTB)
        }
        if p.known && p.phase == 0 {
            let what = p.spots[i]
            if p.theme == "ghost" {
                if what == 7 {
                    c.RRStroke(q.0, q.1, q.2, q.3, 12, 2.4, Col(0xff5a3c, 0.7 + 0.3 * sin(T * 6)))
                    c.textS("cursed", cx, q.1 + 16, 12, Col(0xff9a8a), 0, FONTB)
                }
            } else if what != 0 && what != 7 {
                let gk = 0.6 + 0.4 * sin(T * 5 + Double(i))
                let gx = cx + 16, gy = iy - 14, gl = 11 * gk
                c.seg(gx - gl, gy, gx + gl, gy, 2, Col(0xfff6d8, gk)); c.seg(gx, gy - gl, gx, gy + gl, 2, Col(0xfff6d8, gk))
                c.circ(gx, gy, 2.6, WHITE)
            }
        }
    }
    func memoryLine(_ p: Play) -> String {
        if p.phase == 1 { return "Watch the order..." }
        if p.phase == 2 { return "Now tap them in the same order: \(p.seqI) of \(p.seq.count)" }
        return ""
    }
}
