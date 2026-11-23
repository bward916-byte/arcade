import CoreGraphics
import Foundation

// The sword fight on the pirate's deck. Cuts come high or low and must be parried on the right line;
// heavy blows cannot be parried and must be dodged; a perfect parry opens a riposte for double damage.
// Every action costs wind, and each hit drives the loser back toward the rail.

enum FoeKind { case cutthroat, bruiser, duelist, captain }
enum EState { case enter, ready, wind, strike, stag, hit, dead }
enum PState { case ready, parry, lunge, dodge, hurt }

struct Pose {
    var ang = -0.45
    var reach = 0.0
    var lean = 0.05
    var crouch = 0.0
    var fall = 0.0
    var flash = 0.0
    var trail = false
    var twoHand = false
}

final class Duel {
    let boss: Bool
    let prize: Int
    let foes: Int
    let pw: Double
    var k = 0
    var lost = 0

    var kind: FoeKind = .cutthroat
    var est: EState = .enter
    var et = 0.9
    var ehp = 2
    var emax = 2
    var wd = 0.8
    var line = 0
    var heavy = false
    var feint = false
    var rage = false

    var pst: PState = .ready
    var pt = 0.0
    var php = 4
    var wind = 1.0
    var par = 0.0
    var parLine = 0
    var parAge = 9.0
    var cd = 0.0
    var dodge = 0.0
    var rip = 0.0

    var pos = 0.0
    var slow = 0.0
    var clash = 0.0
    var flashP = 0.0
    var flashE = 0.0
    var msg = ""
    var msgT = 0.0
    var tip = 0
    var t = 0.0
    var over = false

    // The first fights teach the moves: the fight freezes at each cut until the right button is tapped.
    // lesson 0 = parry high, 1 = parry low, 2 = dodge, 3 = taught. Progress is kept between fights.
    static let lessonKey = "fh_duelLesson"
    var lesson = 3
    var lungeTaught = true
    var hold = false
    var holdWant = 0

    init(foes: Int, boss: Bool, prize: Int, armed: Double, teach: Bool = true) {
        self.foes = foes
        self.boss = boss
        self.prize = prize
        pw = 0.2 + 0.16 * armed
        if teach {
            lesson = min(3, UserDefaults.standard.integer(forKey: Duel.lessonKey))
            lungeTaught = lesson > 0
        }
        setFoe()
    }
    var teaching: Bool { return lesson < 3 }
    private func learned() {
        lesson += 1
        UserDefaults.standard.set(lesson, forKey: Duel.lessonKey)
    }

    private func setFoe() {
        if boss && k == foes - 1 {
            kind = .captain
        } else if k == 0 {
            kind = .cutthroat
        } else {
            kind = k % 2 == 1 ? .bruiser : .duelist
        }
        switch kind {
        case .cutthroat: emax = 2
        case .bruiser: emax = 3
        case .duelist: emax = 3
        case .captain: emax = 6
        }
        if teaching { emax = max(emax, 3) }
        ehp = emax
        est = .enter
        et = 1.0
        rage = false
        heavy = false
        feint = false
    }
    var foeName: String {
        switch kind {
        case .cutthroat: return "Cutthroat"
        case .bruiser: return "Bruiser"
        case .duelist: return "Duelist"
        case .captain: return "Captain of the Red Mary"
        }
    }
    func say(_ s: String) { msg = s; msgT = 1.6 }

    func next(_ g: Game) {
        k += 1
        if k >= foes {
            over = true
            g.duelWon(self)
            return
        }
        setFoe()
        php = min(4, php + 1)
        pos = 0
        say(kind == .captain ? "The captain himself!" : "Another comes at you")
    }

    private func gap() -> Double {
        var f = 1.0
        switch kind {
        case .cutthroat: f = 1.0
        case .bruiser: f = 1.15
        case .duelist: f = 0.7
        case .captain: f = rage ? 0.5 : 0.75
        }
        return rnd(0.7, 1.3) * f * max(0.6, 1 - Double(k) * 0.06)
    }
    private func beginAttack() {
        est = .wind
        line = chance(0.5) ? 0 : 1
        var ph = 0.0, pf = 0.0, base = 0.8
        switch kind {
        case .cutthroat: ph = k > 0 ? 0.1 : 0; pf = 0; base = 0.82
        case .bruiser: ph = 0.42; pf = 0; base = 0.86
        case .duelist: ph = 0.08; pf = 0.35; base = 0.6
        case .captain: ph = rage ? 0.35 : 0.22; pf = 0.3; base = rage ? 0.5 : 0.62
        }
        heavy = chance(ph)
        feint = !heavy && chance(pf)
        if teaching {
            // scripted: one high cut, one low cut, one heavy blow
            feint = false
            heavy = lesson == 2
            if lesson == 0 { line = 0 } else if lesson == 1 { line = 1 }
        }
        wd = heavy ? (kind == .captain ? 0.82 : 0.98) : max(0.42, base - Double(k) * 0.03)
        if teaching { wd *= 1.25 }
        et = wd
    }
    private func sparks(_ g: Game, _ x: Double, _ y: Double, _ n: Int, _ c: Col) {
        g.puff(x, y, n, c, 220, 300, 2.4, 0.4)
    }
    private func hitPlayer(_ n: Int, _ g: Game) {
        php -= n
        pst = .hurt
        pt = 0.5
        flashP = 0.4
        pos -= 0.2 * Double(n)
        g.shake = 0.3
        g.snd?.thud()
        g.buzz?(true)
        let (px, py) = playerXY(g)
        sparks(g, px, py - g.H * 0.26, 10, Col(0xff5a3c))
        if php <= 0 || pos <= -1 {
            let overRail = pos <= -1 && php > 0
            lost += 1
            g.duelSailorDown()
            if g.over { return }
            if lost >= 3 {
                over = true
                g.duelLost(self)
                return
            }
            php = 4; pos = 0; wind = 1
            say(overRail ? "Driven over the rail! Another steps up" : "Another sailor steps up")
        }
    }
    private func resolve(_ g: Game) {
        est = .strike
        et = 0.3
        let (cx, cy) = clashXY(g)
        if heavy {
            if dodge > 0 {
                est = .stag
                et = 1.3
                g.snd?.whoosh()
                if teaching && lesson == 2 { learned() }
                say("He overreaches. Strike!")
            } else {
                hitPlayer(2, g)
            }
            return
        }
        if dodge > 0 {
            g.snd?.whoosh()
            return
        }
        if par > 0 && parLine == line {
            let perfect = parAge < 0.13
            clash = 0.3
            est = .stag
            et = perfect ? 1.3 : 0.95
            pst = .parry
            pt = 0.3
            wind = min(1, wind + 0.08)
            pos += 0.06
            if perfect { rip = 1.4; say("Perfect parry — riposte!") }
            if teaching && lesson == line { learned() }
            g.snd?.clang()
            g.buzz?(false)
            sparks(g, cx, cy, perfect ? 22 : 14, Col(0xffe9a0))
        } else {
            if par > 0 { say(line == 0 ? "He cut high" : "He cut low") }
            hitPlayer(1, g)
        }
    }

    func update(_ dt: Double, _ g: Game) {
        if over { return }
        if hold { t += dt; return }
        var d = dt
        if slow > 0 { slow -= dt; d = dt * 0.3 }
        t += d
        par = max(0, par - d); cd = max(0, cd - d); dodge = max(0, dodge - d); rip = max(0, rip - d)
        clash = max(0, clash - d); flashP = max(0, flashP - d); flashE = max(0, flashE - d); msgT = max(0, msgT - d)
        parAge += d
        if pst == .ready { wind = min(1, wind + 0.24 * d) }
        pt -= d
        if pst != .ready && pt <= 0 { pst = .ready }
        pos += (0 - pos) * d * 0.06
        pos = clampD(pos, -1, 1)
        et -= d
        switch est {
        case .enter:
            if et <= 0 { est = .ready; et = rnd(0.6, 1.1) }
        case .ready:
            if et <= 0 { beginAttack() }
        case .wind:
            if feint && et < wd * 0.45 {
                feint = false
                est = .ready
                et = rnd(0.18, 0.4)
            } else if teaching && et < (heavy ? 0.3 : pw * 0.55) && dodge <= 0 && !(par > 0 && !heavy && parLine == line) {
                hold = true
                holdWant = heavy ? 2 : line
            } else if et <= 0 {
                resolve(g)
            }
        case .strike:
            if et <= 0 { est = .ready; et = gap() }
        case .stag:
            if !lungeTaught && et < 0.75 { hold = true; holdWant = 3 }
            if et <= 0 { est = .ready; et = rnd(0.35, 0.8) }
        case .hit:
            if et <= 0 {
                if ehp <= 0 { est = .dead; et = 0.95 } else { est = .ready; et = rnd(0.4, 0.9) }
            }
        case .dead:
            if et <= 0 { next(g) }
        }
    }

    // ---------- what the player does
    private func parry(_ ln: Int, _ g: Game) {
        if cd > 0 || pst == .hurt || pst == .lunge { return }
        if wind < 0.1 { say("Winded"); return }
        wind -= 0.1
        par = pw; parLine = ln; parAge = 0
        cd = 0.4
        pst = .parry
        pt = 0.32
        g.snd?.click()
    }
    private func sidestep(_ g: Game) {
        if pst == .hurt || cd > 0.25 { return }
        if wind < 0.22 { say("Winded"); return }
        wind -= 0.22
        dodge = 0.5
        pst = .dodge
        pt = 0.5
        cd = 0.55
        pos -= 0.1
        g.snd?.whoosh()
    }
    private func lunge(_ g: Game) {
        if pst == .hurt || pst == .lunge || cd > 0.3 { return }
        if wind < 0.18 { say("Winded — catch your breath"); return }
        wind -= 0.18
        pst = .lunge
        pt = 0.34
        cd = 0.5
        let (fx, fy) = foeXY(g)
        let open = est == .stag
        let stop = est == .wind && !heavy && !feint && et > wd * 0.62
        if open || stop {
            let n = open && rip > 0 ? 2 : 1
            rip = 0
            ehp -= n
            let atRail = pos >= 0.9
            pos += 0.2 * Double(n)
            if atRail { ehp = 0 }
            est = .hit
            et = 0.45
            flashE = 0.4
            g.shake = 0.25
            g.snd?.thud()
            g.snd?.clang()
            g.buzz?(true)
            sparks(g, fx, fy - g.H * 0.26, n == 2 ? 22 : 12, Col(0xffd257))
            if ehp <= 0 {
                slow = 0.6
                say(atRail ? "Over the side with him!" : (n == 2 ? "A riposte runs him through" : "He is down"))
                if atRail { g.snd?.splash() }
            } else if n == 2 {
                say("Riposte!")
            } else if stop {
                say("A stop-hit!")
            }
            if kind == .captain && !rage && ehp > 0 && ehp <= 3 {
                rage = true
                say("He throws off his coat. Now he means it.")
            }
        } else if est == .ready || est == .enter {
            clash = 0.25
            g.snd?.clang()
            let (cx, cy) = clashXY(g)
            sparks(g, cx, cy, 6, Col(0xffe9a0))
            et = min(et, 0.22)
            if tip < 2 { tip += 1; say("Blocked. Parry first, then lunge") }
        }
    }

    func rects(_ g: Game) -> [(Double, Double, Double, Double)] {
        let bw = min(134.0, g.W * 0.17), bh = 54.0
        let lx = g.safeL + 4, rx = g.W - g.safeR - bw - 4
        let y2 = g.H - g.safeB - bh - 6, y1 = y2 - bh - 8
        return [(lx, y1, bw, bh), (lx, y2, bw, bh), (rx, y1, bw, bh), (rx, y2, bw, bh)]
    }
    func touch(_ x: Double, _ y: Double, _ g: Game) {
        if over || est == .dead { return }
        let r = rects(g)
        var hit = -1
        for (i, q) in r.enumerated() where x >= q.0 - 6 && x <= q.0 + q.2 + 6 && y >= q.1 - 4 && y <= q.1 + q.3 + 4 { hit = i }
        if hit < 0 {
            // anywhere else: the left half parries, the right half attacks, split high and low
            if y < 60 { return }
            let upper = y < r[1].1
            hit = x < g.W / 2 ? (upper ? 0 : 1) : (upper ? 2 : 3)
        }
        if hold {
            if hit != holdWant { say("Not that one"); return }
            hold = false
            cd = 0; pst = .ready; wind = max(wind, 0.4)
            if holdWant == 3 { lungeTaught = true }
        }
        switch hit {
        case 0: parry(0, g)
        case 1: parry(1, g)
        case 2: sidestep(g)
        default: lunge(g)
        }
    }

    // ---------- where things stand on the deck
    private func scaleS(_ g: Game) -> Double { return g.H * 0.46 }
    private func feetY(_ g: Game) -> Double { return g.H * 0.9 }
    private func centre(_ g: Game) -> Double { return g.W / 2 + pos * g.W * 0.13 }
    private func playerXY(_ g: Game) -> (Double, Double) { return (centre(g) - scaleS(g) * 0.4, feetY(g)) }
    private func foeXY(_ g: Game) -> (Double, Double) { return (centre(g) + scaleS(g) * 0.4, feetY(g)) }
    private func clashXY(_ g: Game) -> (Double, Double) { return (centre(g), feetY(g) - scaleS(g) * (line == 0 ? 0.78 : 0.42)) }

    // ---------- drawing
    func draw(_ c: Canvas, _ g: Game) {
        let W = g.W, H = g.H
        drawDeck(c, g)
        let s = scaleS(g), fy = feetY(g)
        var pp = Pose(), ep = Pose()
        pp.ang = -0.45 + sin(t * 3) * 0.05
        ep.ang = -0.45 + sin(t * 3 + 2) * 0.05
        var pOff = 0.0, eOff = 0.0
        switch est {
        case .enter:
            eOff = s * 0.9 * clampD(et / 1.0, 0, 1)
        case .wind:
            let q = clampD(1 - et / wd, 0, 1)
            if heavy {
                ep.ang = lerp(-0.45, -2.5, min(1, q * 1.6)); ep.twoHand = true; ep.lean = -0.2 * q; ep.crouch = 0.04 * q
            } else if line == 0 {
                ep.ang = lerp(-0.45, -1.95, min(1, q * 2)); ep.lean = -0.14 * q
            } else {
                ep.ang = lerp(-0.45, 0.85, min(1, q * 2)); ep.reach = -0.5 * q; ep.crouch = 0.07 * q; ep.lean = 0.12 * q
            }
            eOff = s * 0.05 * q
        case .strike:
            let q = clampD(1 - et / 0.3, 0, 1)
            let z = min(1, q * 3)
            if heavy {
                ep.ang = lerp(-2.5, 0.75, z); ep.twoHand = true; ep.lean = 0.3 * z
            } else if line == 0 {
                ep.ang = lerp(-1.95, 0.45, z); ep.lean = 0.22 * z
            } else {
                ep.ang = lerp(0.85, 0.12, z); ep.crouch = 0.07; ep.lean = 0.26 * z
            }
            ep.reach = min(1, q * 2.2)
            ep.trail = true
            eOff = -s * 0.16 * sin(min(1, q * 1.4) * PI * 0.8)
        case .stag:
            ep.ang = 1.1 + sin(t * 9) * 0.08; ep.lean = -0.26 + sin(t * 8) * 0.04; eOff = s * 0.12
        case .hit:
            ep.ang = 1.2; ep.lean = -0.4; eOff = s * 0.18; ep.flash = flashE
        case .dead:
            ep.fall = clampD(1 - et / 0.95, 0, 1); ep.ang = 1.4; eOff = s * 0.2
        default:
            break
        }
        switch pst {
        case .parry:
            pp.ang = parLine == 0 ? -1.25 : 0.55
            pp.reach = 0.25
            pp.crouch = parLine == 1 ? 0.06 : 0
        case .lunge:
            let q = clampD(1 - pt / 0.34, 0, 1)
            pp.ang = lerp(-0.3, 0.02, min(1, q * 3)); pp.reach = sin(min(1, q * 1.3) * PI * 0.85); pp.lean = 0.3 * pp.reach; pp.crouch = 0.06 * pp.reach
            pp.trail = true
            pOff = s * 0.18 * pp.reach
        case .dodge:
            let q = sin(clampD(1 - pt / 0.5, 0, 1) * PI)
            pp.lean = -0.34 * q; pp.crouch = 0.08 * q; pOff = -s * 0.2 * q
        case .hurt:
            pp.lean = -0.3; pp.ang = 0.9; pOff = -s * 0.1; pp.flash = flashP
        default:
            break
        }
        let (px, _) = playerXY(g)
        let (ex, _) = foeXY(g)
        // the heavy blow glows red as it gathers
        if est == .wind && heavy {
            let q = clampD(1 - et / wd, 0, 1)
            c.glow(ex + eOff, fy - s * 0.9, s * 0.5, Col(0xff3a20, 0.55 * q), Col(0xff3a20, 0))
        }
        fighter(c, px + pOff, fy, s, 1, pp, 0)
        fighter(c, ex + eOff, fy, s * (kind == .bruiser ? 1.08 : (kind == .captain ? 1.05 : 1)), -1, ep, kindIndex())
        g.drawSparks(c)

        // the warning over his head
        let hx = ex + eOff, hy = fy - s * 1.22
        if est == .wind {
            let q = clampD(et / wd, 0, 1)
            let late = et < pw + 0.06
            let col = heavy ? Col(0xff3a20) : (late ? Col(0xff7a30) : Col(0xffc040))
            c.circStroke(hx, hy, 12 + 22 * q, 4, col)
            let label = heavy ? "DODGE" : (line == 0 ? "HIGH" : "LOW")
            c.textS(label, hx, hy + 6, 17, col, 0, FONTB)
            if !heavy {
                let ay = line == 0 ? hy - 22 : hy + 22
                let dir = line == 0 ? -1.0 : 1.0
                c.poly(col, [hx - 9, ay, hx + 9, ay, hx, ay + dir * 12])
            }
        } else if est == .stag {
            c.textS(rip > 0 ? "RIPOSTE!" : "OPEN!", hx, hy + 6, 20, Col(0xffe08a), 0, FONTB)
        }
        if clash > 0 {
            let (cx, cy) = clashXY(g)
            c.glow(cx, cy, 50, Col(0xfff0c0, clash * 2.5), Col(0xfff0c0, 0))
        }
        if msgT > 0 && !msg.isEmpty {
            c.save()
            c.alpha(min(1, msgT * 2))
            c.textS(msg, W / 2, H * 0.3, 20, CREAM, 0, FONTB)
            c.restore()
        }

        // who is winning
        let ny = 52.0
        c.textS(foeName, W - g.safeR - 8, ny, 16, kind == .captain ? Col(0xff9a8a) : CREAM, 1, FONTB)
        for i in 0..<emax {
            let x = W - g.safeR - 16 - Double(i) * 17
            c.circ(x, ny + 14, 6.5, Col(0x1c1108))
            c.circ(x, ny + 14, 5, i < ehp ? Col(0xe0402f) : Col(0x000000, 0.4))
        }
        c.textS("Your blade", g.safeL + 8, ny, 16, CREAM, -1, FONTB)
        for i in 0..<4 {
            let x = g.safeL + 16 + Double(i) * 17
            c.circ(x, ny + 14, 6.5, Col(0x1c1108))
            c.circ(x, ny + 14, 5, i < php ? GREENC : Col(0x000000, 0.4))
        }
        g.gauge(c, g.safeL + 10, ny + 28, 110, 7, wind, Col(0xbfe6ff), Col(0x4a8fd0))
        c.textS("wind", g.safeL + 130, ny + 36, 11, CREAM, -1, FONTI)
        c.textS("Pirates left \(foes - k)   ·   Sailors lost \(lost)/3", W / 2, ny, 14, CREAM, 0, FONT)

        // the four moves
        let r = rects(g)
        let late = est == .wind && !heavy && !feint && et < pw + 0.06
        let names: [(String, String)] = [("Parry high", "stop a cut from above"), ("Parry low", "stop a thrust below"), ("Dodge", "slip a heavy blow"), ("Lunge", "when he is open")]
        for (i, q) in r.enumerated() {
            var on = false
            if i == 0 { on = late && line == 0 } else if i == 1 { on = late && line == 1 } else if i == 2 { on = est == .wind && heavy && et < 0.5 } else { on = est == .stag }
            if hold { on = i == holdWant }
            let need: Double = i < 2 ? 0.1 : (i == 2 ? 0.22 : 0.18)
            let dim = hold ? i != holdWant : wind < need
            let pu = on ? 1 + sin(t * 18) * 0.04 : 1.0
            c.save()
            c.translate(q.0 + q.2 / 2, q.1 + q.3 / 2)
            c.scale(pu, pu)
            let x = -q.2 / 2, y = -q.3 / 2
            c.RR(x, y + 3, q.2, q.3, 12, Col(0x1a0e05))
            if on {
                c.glow(0, 0, q.2 * 0.8, Col(0xffd257, 0.5), Col(0xffd257, 0))
                c.RRGrad(x, y, q.2, q.3, 12, [(0, Col(0xffe9a0)), (1, Col(0xd49a2a))])
                c.RRStroke(x, y, q.2, q.3, 12, 2.5, Col(0xfff6d8))
            } else {
                c.RRGrad(x, y, q.2, q.3, 12, [(0, Col(0x7a5230)), (1, Col(0x3f2613))])
                c.RRStroke(x, y, q.2, q.3, 12, 1.5, Col(0xd2a455))
            }
            let tc = on ? Col(0x3a2408) : CREAM
            c.text(names[i].0, 0, -2, 17, tc, 0, FONTB)
            c.text(names[i].1, 0, 13, 10.5, tc.alpha(0.85), 0, FONTI)
            if dim { c.RR(x, y, q.2, q.3 + 3, 12, Col(0x120a04, 0.5)) }
            c.restore()
        }
        drawLesson(c, g)
    }

    /// The lesson banner shown while the fight is frozen.
    func drawLesson(_ c: Canvas, _ g: Game) {
        if !hold { return }
        let W = g.W, H = g.H
        let lines: [(String, String)] = [
            ("He cuts HIGH", "Tap Parry high to stop it"),
            ("He thrusts LOW", "Tap Parry low to stop it"),
            ("A heavy blow — it glows red", "It cannot be parried. Tap Dodge"),
            ("He is OPEN", "Tap Lunge to strike him")
        ]
        let l = lines[holdWant]
        let bw = min(430.0, W * 0.56), bh = 74.0, bx = W / 2 - bw / 2, by = H * 0.2
        c.RR(bx, by + 3, bw, bh, 14, Col(0x000000, 0.35))
        c.RRGrad(bx, by, bw, bh, 14, [(0, Col(0x2c1a0c, 0.96)), (1, Col(0x1a0e05, 0.96))])
        c.RRStroke(bx, by, bw, bh, 14, 2, Col(0xffd257))
        c.text(l.0, W / 2, by + 30, 22, Col(0xffe9a0), 0, FONTB)
        c.text(l.1, W / 2, by + 56, 16, CREAM, 0, FONT)
        // an arrow bobbing over the button to press
        let q = rects(g)[holdWant]
        let ax = q.0 + q.2 / 2, ay = q.1 - 12 + sin(t * 7) * 5
        c.poly(Col(0xffd257), [ax - 13, ay - 16, ax + 13, ay - 16, ax, ay])
    }

    private func kindIndex() -> Int {
        switch kind {
        case .cutthroat: return 1
        case .bruiser: return 2
        case .duelist: return 3
        case .captain: return 4
        }
    }

    private func drawDeck(_ c: Canvas, _ g: Game) {
        let W = g.W, H = g.H
        let hz = H * 0.44
        g.drawSea(c, hz)
        // the other ship's rigging against the sky
        let spar = Col(0x1c120a)
        for (i, mx) in [W * 0.16, W * 0.5, W * 0.84].enumerated() {
            let top = i == 1 ? -10.0 : H * 0.04
            c.R(mx - 5, top, 10, H * 0.66 - top, spar)
            c.R(mx - 70, H * 0.27 + Double(i) * 6, 140, 5, spar)
            c.RR(mx - 64, H * 0.27 + Double(i) * 6 + 4, 128, 9, 4, Col(0x7a1b12))
            c.seg(mx, top + 20, mx - 110, H * 0.6, 1.2, spar.alpha(0.8))
            c.seg(mx, top + 20, mx + 110, H * 0.6, 1.2, spar.alpha(0.8))
            for j in 1..<7 {
                let k = Double(j) / 7
                c.seg(mx - 110 * k, top + 20 + (H * 0.6 - top - 20) * k, mx + 110 * k, top + 20 + (H * 0.6 - top - 20) * k, 0.8, spar.alpha(0.6))
            }
        }
        // the rail
        let ry = H * 0.58
        c.R(0, ry, W, 7, Col(0x4a2d14))
        c.R(0, ry, W, 2, Col(0x8a5a2c))
        var bx = 8.0
        while bx < W {
            c.R(bx, ry + 7, 6, H * 0.08, Col(0x3f2613))
            bx += 26
        }
        c.R(0, ry + H * 0.08 + 5, W, 5, Col(0x33200f))
        // the men fighting along the rail behind you
        for i in 0..<5 {
            let x = W * (0.1 + Double(i) * 0.2) + sin(t * 0.7 + Double(i) * 2.1) * 12
            let y = H * 0.7
            let sw = sin(t * (5 + Double(i)) + Double(i))
            let mine = i % 2 == 0
            c.ell(x, y + 1, 12, 3, Col(0x000000, 0.25))
            c.R(x - 4, y - 22, 8, 14, mine ? Col(0x25486c) : Col(0x241c20))
            c.seg(x - 2, y - 8, x - 4, y, 3, Col(0x1a1410)); c.seg(x + 2, y - 8, x + 5, y, 3, Col(0x1a1410))
            c.circ(x, y - 26, 4.5, Col(0xb98a5e))
            let dir = mine ? 1.0 : -1.0
            c.seg(x + dir * 4, y - 18, x + dir * 14, y - 22 - sw * 8, 2.2, Col(0xb98a5e))
            c.seg(x + dir * 14, y - 22 - sw * 8, x + dir * 28, y - 30 - sw * 14, 1.6, Col(0xdfe6ea))
        }
        // the deck
        c.vfill(0, H * 0.67, W, H * 0.33, [(0, Col(0x7a5230)), (1, Col(0x4a2d14))])
        var py = H * 0.67
        var gapY = 7.0
        while py < H {
            c.R(0, py, W, 1.3, Col(0x000000, 0.25))
            py += gapY
            gapY *= 1.32
        }
        for i in 0..<12 {
            let x = W * Double(i) / 11
            c.seg(W / 2 + (x - W / 2) * 0.82, H * 0.67, W / 2 + (x - W / 2) * 1.25, H, 0.8, Col(0x000000, 0.14))
        }
        // lantern light and dusk
        let L = g.light()
        c.R(0, 0, W, H, Col(0x1a0c20, 0.12 + 0.2 * L.night))
        for lx in [W * 0.16, W * 0.84] {
            c.circ(lx, H * 0.36, 5, Col(0xffd257))
            c.glow(lx, H * 0.36, 120, Col(0xffb050, 0.3), Col(0xffb050, 0))
        }
    }

    /// One swordsman. (x, fy) is the ground between his feet; s is his height; dir is the way he faces.
    private func fighter(_ c: Canvas, _ x: Double, _ fy: Double, _ s: Double, _ dir: Double, _ p: Pose, _ style: Int) {
        // colours by who he is: 0 your sailor, 1 cutthroat, 2 bruiser, 3 duelist, 4 captain
        let shirts: [Col] = [Col(0x2f5f8f), Col(0x3a3a40), Col(0x5a3a24), Col(0x24303a), Col(0x7a1b12)]
        let skins: [Col] = [Col(0xe3b58a), Col(0xc99a6e), Col(0xb98a5e), Col(0xd9a878), Col(0xc99a6e)]
        let bands: [Col] = [Col(0xb03a2a), Col(0x111111), Col(0x8a1a1a), Col(0x1a1a1a), Col(0x16100a)]
        let shirt = shirts[style], skin = skins[style], band = bands[style]
        let wide = style == 2 ? 1.3 : 1.0
        c.save()
        c.translate(x, fy)
        c.ell(0, 2, s * 0.26, s * 0.035, Col(0x000000, 0.35))
        if p.fall > 0 {
            c.alpha(1 - p.fall * 0.6)
            c.translate(0, p.fall * s * 0.02)
            c.rotate(-dir * p.fall * 1.35)
        }
        c.scale(dir, 1)
        c.roundCaps(true)
        let crouch = p.crouch * s
        let hipX = p.reach * s * 0.1, hipY = -s * 0.47 + crouch
        let shX = hipX + sin(p.lean) * s * 0.3, shY = hipY - cos(p.lean) * s * 0.3
        let legC = Col(0x2b1d12), boot = Col(0x15100a)
        // legs: the back one braces, the front one steps into the lunge
        let bfX = -s * (0.2 + max(0, p.reach) * 0.08), ffX = s * (0.15 + max(0, p.reach) * 0.24)
        let bkX = (hipX + bfX) / 2 - s * 0.02, bkY = hipY / 2 - s * 0.02
        let fkX = (hipX + ffX) / 2 + s * 0.07, fkY = hipY / 2 - s * 0.03 + crouch * 0.4
        c.seg(hipX, hipY, bkX, bkY, s * 0.085 * wide, legC); c.seg(bkX, bkY, bfX, -s * 0.03, s * 0.075 * wide, legC)
        c.seg(bfX - s * 0.03, -s * 0.02, bfX + s * 0.06, -s * 0.02, s * 0.06, boot)
        c.seg(hipX, hipY, fkX, fkY, s * 0.09 * wide, legC); c.seg(fkX, fkY, ffX, -s * 0.03, s * 0.08 * wide, legC)
        c.seg(ffX - s * 0.02, -s * 0.02, ffX + s * 0.09, -s * 0.02, s * 0.06, boot)
        // the back arm, out for balance
        let baX = shX - s * 0.16, baY = shY + s * 0.16 - p.reach * s * 0.08
        c.seg(shX - s * 0.03, shY + s * 0.03, baX, baY, s * 0.06 * wide, shirt.shade(0.8))
        c.circ(baX, baY, s * 0.035, skin)
        // coat tails for the captain
        if style == 4 {
            c.pathFill(Col(0x5a130c)) { q in
                q.move(to: CGPoint(x: hipX - s * 0.08, y: hipY - s * 0.06))
                q.addLine(to: CGPoint(x: hipX - s * 0.24, y: hipY + s * 0.2))
                q.addLine(to: CGPoint(x: hipX - s * 0.06, y: hipY + s * 0.16))
                q.addLine(to: CGPoint(x: hipX + s * 0.06, y: hipY + s * 0.02))
                q.closeSubpath()
            }
        }
        // body, belt and sash
        c.seg(hipX, hipY, shX, shY, s * 0.2 * wide, shirt)
        c.seg(hipX + s * 0.02, hipY - s * 0.02, shX + s * 0.05, shY + s * 0.03, s * 0.07 * wide, shirt.shade(1.25))
        c.seg(hipX - s * 0.09 * wide, hipY, hipX + s * 0.1 * wide, hipY, s * 0.055, style == 0 ? Col(0xb03a2a) : Col(0x16100a))
        if style == 4 {
            c.seg(hipX + s * 0.07, hipY - s * 0.04, shX + s * 0.09, shY + s * 0.06, s * 0.03, Col(0xd4a52a))
        }
        // head
        let hdX = shX + sin(p.lean) * s * 0.1 + s * 0.02, hdY = shY - s * 0.13
        c.seg(shX, shY, hdX, hdY + s * 0.04, s * 0.06, skin.shade(0.85))
        c.circ(hdX, hdY, s * 0.082, skin)
        c.circ(hdX + s * 0.045, hdY - s * 0.01, s * 0.011, Col(0x1a1008))
        if style == 0 {
            c.arcFill(hdX, hdY - s * 0.01, s * 0.086, PI * 1.05, PI * 1.98, band)
            c.seg(hdX - s * 0.08, hdY - s * 0.02, hdX - s * 0.15, hdY + s * 0.04, s * 0.02, band)
        } else if style == 1 || style == 2 {
            c.arcFill(hdX, hdY - s * 0.01, s * 0.086, PI * 1.02, PI * 1.98, band)
            c.seg(hdX - s * 0.01, hdY - s * 0.05, hdX + s * 0.07, hdY + s * 0.01, s * 0.022, Col(0x111111))
            c.arcFill(hdX + s * 0.01, hdY + s * 0.03, s * 0.07, 0.1, PI * 0.9, Col(0x2a1c12))
        } else {
            // a cocked hat; the captain's carries a feather
            c.pathFill(band) { q in
                q.move(to: CGPoint(x: hdX - s * 0.16, y: hdY - s * 0.04))
                q.addQuadCurve(to: CGPoint(x: hdX + s * 0.17, y: hdY - s * 0.05), control: CGPoint(x: hdX, y: hdY - s * 0.02))
                q.addQuadCurve(to: CGPoint(x: hdX, y: hdY - s * 0.19), control: CGPoint(x: hdX + s * 0.1, y: hdY - s * 0.12))
                q.addQuadCurve(to: CGPoint(x: hdX - s * 0.16, y: hdY - s * 0.04), control: CGPoint(x: hdX - s * 0.1, y: hdY - s * 0.12))
            }
            if style == 4 {
                c.seg(hdX - s * 0.15, hdY - s * 0.045, hdX + s * 0.16, hdY - s * 0.055, s * 0.014, Col(0xd4a52a))
                c.curve(hdX - s * 0.04, hdY - s * 0.15, hdX - s * 0.16, hdY - s * 0.3, hdX - s * 0.26, hdY - s * 0.2, s * 0.035, Col(0xf3ead2))
                c.arcFill(hdX + s * 0.015, hdY + s * 0.035, s * 0.075, 0.1, PI * 0.9, Col(0x16100a))
            }
        }
        // the sword arm and the blade
        let armLen = s * (0.24 + max(-0.3, p.reach) * 0.07)
        let armA = p.ang * 0.62 - 0.12
        let hx = shX + cos(armA) * armLen, hy = shY + s * 0.04 + sin(armA) * armLen
        c.seg(shX, shY + s * 0.03, hx, hy, s * 0.065 * wide, shirt.shade(1.1))
        if p.twoHand { c.seg(shX - s * 0.02, shY + s * 0.06, hx - s * 0.02, hy + s * 0.02, s * 0.055 * wide, shirt.shade(0.85)) }
        c.circ(hx, hy, s * 0.04, skin)
        let bl = s * (style == 2 ? 0.5 : 0.44)
        let ca = cos(p.ang), sa = sin(p.ang)
        let tipX = hx + ca * bl, tipY = hy + sa * bl
        if p.trail {
            c.pathStroke(Col(0xffffff, 0.35), s * 0.05) { q in
                q.addArc(center: CGPoint(x: shX, y: shY), radius: CGFloat(armLen + bl * 0.8), startAngle: CGFloat(p.ang - 0.9), endAngle: CGFloat(p.ang), clockwise: false)
            }
        }
        let nx = -sa, ny = ca
        let bw = s * (style == 2 ? 0.032 : 0.022)
        c.pathFill(Col(0xe8edf1)) { q in
            q.move(to: CGPoint(x: hx + nx * bw, y: hy + ny * bw))
            q.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: CGPoint(x: hx + ca * bl * 0.6 + nx * bw * 2.2, y: hy + sa * bl * 0.6 + ny * bw * 2.2))
            q.addQuadCurve(to: CGPoint(x: hx - nx * bw, y: hy - ny * bw), control: CGPoint(x: hx + ca * bl * 0.6 - nx * bw * 0.4, y: hy + sa * bl * 0.6 - ny * bw * 0.4))
            q.closeSubpath()
        }
        c.seg(hx + ca * bl * 0.1, hy + sa * bl * 0.1, hx + ca * bl * 0.85, hy + sa * bl * 0.85, s * 0.006, Col(0xffffff, 0.8))
        c.seg(hx + nx * s * 0.05, hy + ny * s * 0.05, hx - nx * s * 0.05, hy - ny * s * 0.05, s * 0.022, Col(0xd4a52a))
        c.seg(hx - ca * s * 0.05, hy - sa * s * 0.05, hx, hy, s * 0.028, Col(0x3a2412))
        if p.flash > 0 {
            c.circ(shX, shY + s * 0.1, s * 0.3, Col(0xffffff, min(0.6, p.flash * 1.5)))
        }
        c.restore()
    }
}
