import CoreGraphics
import Foundation

// The sword fight on the pirate's deck. Cuts come high or low and must be parried on the right line;
// heavy blows cannot be parried and must be dodged; a perfect parry opens a riposte for double damage.
// Every action costs wind, and each hit drives the loser back toward the rail.

enum FoeKind { case deckhand, cutthroat, bruiser, duelist, captain }
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
    /// Where the blade pointed a frame ago: the gap between then and now is drawn as a blur.
    var pang = -0.45
    /// Teeth bared: he is in the middle of a blow.
    var grit = false
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

    // fury builds with every parry and hit and is spent on a flurry no one can stop; a boot buys an opening
    // sparks struck from the blades: each flies, falls and skips off the planks
    var emb: [(x: Double, y: Double, vx: Double, vy: Double, life: Double, max: Double, red: Bool)] = []
    var flares: [(x: Double, y: Double, t: Double, big: Double)] = []
    var dust: [(x: Double, y: Double, vx: Double, t: Double, r: Double)] = []
    // the figures ease from pose to pose instead of snapping
    var sp = Pose()
    var se = Pose()
    var sOffP = 0.0
    var sOffE = 0.0
    var lastDrawT = 0.0
    var prevPst = PState.ready
    var prevEst = EState.enter
    var fury = 0.0
    var flurry = 0
    var flT = 0.0
    var carry = 0
    var combo = 0
    var best = 0
    var kickCd = 0.0
    var punch = 0.0
    var banner = ""
    var bannerT = 0.0
    var kills = 0

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
        } else if !boss && k == foes - 1 {
            kind = .duelist
        } else if k % 3 == 2 {
            kind = (k / 3) % 2 == 0 ? .bruiser : .duelist
        } else {
            kind = .deckhand
        }
        switch kind {
        case .deckhand: emax = 1
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
        case .deckhand: return "Deckhand"
        case .cutthroat: return "Cutthroat"
        case .bruiser: return "Bruiser"
        case .duelist: return "Duelist"
        case .captain: return "Captain of the Red Mary"
        }
    }
    func say(_ s: String) { msg = s; msgT = 1.6 }
    /// A one-time tip in the middle of a fight. Each is shown once, ever.
    static let tipKey = "fh_duelTips"
    private func tipOnce(_ bit: Int, _ s: String) {
        if teaching { return }
        let seen = UserDefaults.standard.integer(forKey: Duel.tipKey)
        if seen & (1 << bit) != 0 { return }
        UserDefaults.standard.set(seen | (1 << bit), forKey: Duel.tipKey)
        msg = "Tip: " + s
        msgT = 3.0
    }

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
        if carry > 0 {
            // the flurry is not spent: it carries into the next man
            if carry >= ehp { ehp = 0; est = .hit; et = 0.35; flashE = 0.4; say("And the next, in the same breath!"); downed(g) } else { ehp -= carry; say("He staggers in already bleeding") }
            carry = 0
            return
        }
        if kind == .captain {
            say("The captain himself!")
        } else if kind == .deckhand && chance(0.45) {
            // some come in swinging
            est = .ready; et = 0.25
            say("He comes at you fast!")
        } else {
            say(kind == .deckhand ? "A deckhand jumps in" : "Another comes at you")
        }
    }

    private func gap() -> Double {
        var f = 1.0
        switch kind {
        case .deckhand: f = 1.1
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
        case .deckhand: ph = 0; pf = 0; base = 0.9
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
        let red = c.r > 0.9 && c.g < 0.5
        // a shower thrown mostly up and out to both sides, a few straight at the eye
        for i in 0..<(n * 4) {
            let a = -PI / 2 + rnd(-1.5, 1.5) + (i % 5 == 0 ? rnd(-0.6, 0.6) : 0)
            let v = rnd(140, 640) * (i % 7 == 0 ? 1.5 : 1)
            let life = rnd(0.3, 0.95)
            emb.append((x + rnd(-4, 4), y + rnd(-4, 4), cos(a) * v, sin(a) * v, life, life, red))
        }
        if emb.count > 320 { emb.removeFirst(emb.count - 320) }
        flares.append((x, y, 0, min(1.6, Double(n) / 12)))
        g.puff(x, y, max(2, n / 3), c, 160, 200, 3, 0.35)
    }
    private func kickDust(_ x: Double, _ y: Double, _ n: Int, _ dir: Double) {
        for _ in 0..<n { dust.append((x + rnd(-14, 14), y - rnd(0, 6), dir * rnd(10, 70) + rnd(-20, 20), 0, rnd(5, 11))) }
        if dust.count > 60 { dust.removeFirst(dust.count - 60) }
    }
    /// Sparks, flares and dust keep to the real clock, so they hang in the air when the fight slows.
    private func updateFx(_ dt: Double, _ g: Game) {
        let floor = feetY(g) + 4
        var i = emb.count - 1
        while i >= 0 {
            emb[i].life -= dt
            if emb[i].life <= 0 { emb.remove(at: i); i -= 1; continue }
            emb[i].vy += 1150 * dt
            emb[i].vx *= (1 - 0.9 * dt)
            emb[i].x += emb[i].vx * dt
            emb[i].y += emb[i].vy * dt
            if emb[i].y > floor && emb[i].vy > 0 {
                // it skips off the deck and loses heat
                emb[i].y = floor
                emb[i].vy *= -0.36
                emb[i].vx *= 0.62
                emb[i].life *= 0.7
            }
            i -= 1
        }
        var j = flares.count - 1
        while j >= 0 {
            flares[j].t += dt
            if flares[j].t > 0.3 { flares.remove(at: j) }
            j -= 1
        }
        var k2 = dust.count - 1
        while k2 >= 0 {
            dust[k2].t += dt
            dust[k2].x += dust[k2].vx * dt
            dust[k2].vx *= (1 - 2.2 * dt)
            dust[k2].y -= 9 * dt
            if dust[k2].t > 0.7 { dust.remove(at: k2) }
            k2 -= 1
        }
        // feet scuff the planks as each move begins
        if pst != prevPst {
            let (px, py) = playerXY(g)
            if pst == .lunge { kickDust(px - scaleS(g) * 0.2, py, 7, -1) }
            if pst == .dodge { kickDust(px, py, 6, 1) }
            if pst == .hurt { kickDust(px - scaleS(g) * 0.1, py, 5, -1) }
            prevPst = pst
        }
        if est != prevEst {
            let (fx, fy2) = foeXY(g)
            if est == .strike { kickDust(fx + scaleS(g) * 0.2, fy2, 7, 1) }
            if est == .dead { kickDust(fx + scaleS(g) * 0.1, fy2, 12, 1) }
            if est == .stag || est == .hit { kickDust(fx + scaleS(g) * 0.15, fy2, 4, 1) }
            prevEst = est
        }
    }
    private func drawFx(_ c: Canvas, _ g: Game) {
        for d in dust {
            let k = d.t / 0.7
            c.circ(d.x, d.y, d.r * (0.6 + k * 1.6), Col(0xd8c8a8, 0.3 * (1 - k)))
        }
        c.roundCaps(true)
        for e in emb {
            let k = clampD(e.life / e.max, 0, 1)
            // white hot, then yellow, orange, and a dull red as it dies
            let col = e.red ? Col.mix(Col(0x8a1408), Col(0xffb090), k) : (k > 0.7 ? Col.mix(Col(0xffe060), Col(0xffffff), (k - 0.7) / 0.3) : (k > 0.35 ? Col.mix(Col(0xff8a20), Col(0xffe060), (k - 0.35) / 0.35) : Col.mix(Col(0x7a1808), Col(0xff8a20), k / 0.35)))
            let tx = e.x - e.vx * 0.03, ty = e.y - e.vy * 0.03
            c.seg(e.x, e.y, tx, ty, 1 + 2.2 * k, col.alpha(min(1, k * 2.4)))
            if k > 0.55 { c.glow(e.x, e.y, 7, col.alpha(0.5 * k), col.alpha(0)) }
        }
        for f in flares {
            let k = f.t / 0.3
            let a = 1 - k
            let len = (50 + 110 * f.big) * (0.35 + k * 0.65)
            // a four-pointed star with a fainter cross between, and a ring running outward
            for r in 0..<4 {
                let ang = Double(r) * PI / 2 + 0.3
                c.seg(f.x, f.y, f.x + cos(ang) * len, f.y + sin(ang) * len, 3.2 * a, Col(0xffffff, a))
                let a2 = ang + PI / 4
                c.seg(f.x, f.y, f.x + cos(a2) * len * 0.5, f.y + sin(a2) * len * 0.5, 2 * a, Col(0xfff0c0, a * 0.8))
            }
            c.glow(f.x, f.y, 34 + 60 * f.big * (1 - k * 0.5), Col(0xffffff, a), Col(0xfff0c0, 0))
            c.circStroke(f.x, f.y, 14 + 150 * f.big * k, 3 * a, Col(0xfff0c0, 0.7 * a))
        }
        c.roundCaps(false)
        _ = g
    }
    private func gain(_ v: Double, _ g: Game) {
        combo += 1
        best = max(best, combo)
        fury = min(1, fury + v * (g.perkFury ? 1.5 : 1) * (1 + 0.08 * Double(min(8, combo))))
    }
    private func show(_ s: String) { banner = s; bannerT = 1.6 }
    private func hitPlayer(_ n: Int, _ g: Game) {
        combo = 0
        fury = max(0, fury - 0.1)
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
                gain(0.22, g)
                say("He overreaches. Strike!")
            } else {
                hitPlayer(2, g)
                tipOnce(1, "a red glow cannot be parried. Dodge it")
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
            if perfect { rip = 1.4; say("Perfect parry — riposte!") } else { tipOnce(2, "parry at the last moment for a double-damage riposte") }
            if teaching && lesson == line { learned() }
            gain(perfect ? 0.3 : 0.18, g)
            g.snd?.clang()
            g.buzz?(false)
            sparks(g, cx, cy, perfect ? 22 : 14, Col(0xffe9a0))
        } else {
            if par > 0 { say(line == 0 ? "He cut high" : "He cut low") }
            hitPlayer(1, g)
        }
    }

    var demoClash = false
    func update(_ dt: Double, _ g: Game) {
        if over { return }
        updateFx(dt, g)
        if demoClash {
            // for screenshots: strike sparks over and over, with the blades crossed
            t += dt
            pst = .parry; parLine = 0; est = .strike; et = 0.15; line = 0; heavy = false
            if emb.count < 60 { let (cx, cy) = clashXY(g); sparks(g, cx, cy, 20, Col(0xffe9a0)); clash = 0.25 }
            clash = max(0, clash - dt)
            return
        }
        if hold { t += dt; return }
        var d = dt
        if slow > 0 { slow -= dt; d = dt * 0.3 }
        t += d
        par = max(0, par - d); cd = max(0, cd - d); dodge = max(0, dodge - d); rip = max(0, rip - d)
        clash = max(0, clash - d); flashP = max(0, flashP - d); flashE = max(0, flashE - d); msgT = max(0, msgT - d)
        parAge += d
        if pst == .ready { wind = min(1, wind + 0.24 * d * (g.perkWind ? 1.4 : 1)) }
        kickCd = max(0, kickCd - d); punch = max(0, punch - d * 4); bannerT = max(0, bannerT - dt)
        if flurry > 0 {
            flT -= dt
            if flT <= 0 { furyHit(g) }
            return
        }
        pt -= d
        if pst != .ready && pt <= 0 { pst = .ready }
        pos += (0 - pos) * d * 0.06
        pos = clampD(pos, -1, 1)
        if msgT <= 0 && est == .ready {
            if wind < 0.2 { tipOnce(3, "you are winded. Stand a moment and it comes back") }
            else if pos > 0.55 { tipOnce(4, "he is nearly at the rail. One more hit sends him over") }
            else if pos < -0.55 { tipOnce(5, "your back is to the rail. Parry and strike to win ground") }
        }
        et -= d
        switch est {
        case .enter:
            if et <= 0 { est = .ready; et = rnd(0.6, 1.1) }
        case .ready:
            if et <= 0 { beginAttack() }
        case .wind:
            if feint && et < wd * 0.45 {
                tipOnce(0, "that was a feint. Wait for the real cut")
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
            let n = open && rip > 0 ? (g.perkRip ? 3 : 2) : 1
            rip = 0
            ehp -= n
            punch = 1
            gain(0.2, g)
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
                say(atRail ? "Over the side with him!" : (n >= 2 ? "A riposte runs him through" : "He is down"))
                if atRail { g.snd?.splash() }
                downed(g)
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

    /// A man is down: the crowd roars, and the count goes up on screen.
    private func downed(_ g: Game) {
        kills += 1
        g.snd?.wash(1.3, 0.11, 600, 1300, q: 1.2, att: 0.15, rel: 0.9)
        let left = foes - k - 1
        if kills == 1 { show("FIRST BLOOD") } else if left == 0 { show(boss ? "THE CAPTAIN FALLS!" : "THE DECK IS YOURS!") } else if left == 1 { show("ONE LEFT!") } else { show(["TWO DOWN", "THREE DOWN", "FOUR DOWN", "FIVE DOWN", "SIX DOWN"][min(4, kills - 2)]) }
    }
    /// One cut of the fury flurry. Nothing stops it.
    private func furyHit(_ g: Game) {
        flurry -= 1
        flT = 0.17
        ehp -= 1
        pst = .lunge
        pt = 0.17
        est = .hit
        et = 0.4
        flashE = 0.4
        punch = 1
        pos = min(1, pos + 0.1)
        g.shake = 0.22
        g.snd?.thud(); g.snd?.clang()
        g.buzz?(true)
        let (fx, fy) = foeXY(g)
        g.puff(fx, fy - g.H * 0.26, 16, Col(0xffb040), 260, 300, 2.8, 0.5)
        if ehp <= 0 {
            carry = flurry
            flurry = 0
            slow = 0.5
            say("Cut down!")
            downed(g)
        } else if flurry == 0 {
            say("He reels")
            est = .stag
            et = 0.8
        }
    }
    private func furyGo(_ g: Game) {
        if fury < 1 { say("Fury is not ready"); return }
        if est == .dead || est == .enter || pst == .hurt { return }
        fury = 0
        flurry = 3
        flT = 0.05
        slow = 0
        par = 0
        show("FURY!")
        g.snd?.good()
        g.snd?.wash(0.9, 0.12, 500, 2400, q: 1.5, att: 0.05, rel: 0.6)
    }
    private func kick(_ g: Game) {
        if kickCd > 0 { say("Not yet"); return }
        if pst == .hurt || est == .dead || est == .enter || est == .hit { return }
        if wind < 0.3 { say("Winded"); return }
        if est == .wind && heavy { say("Too late. Dodge!"); return }
        wind -= 0.3
        kickCd = 3
        pst = .lunge
        pt = 0.25
        est = .stag
        et = kind == .captain ? 0.55 : 0.85
        feint = false
        pos = min(1, pos + (kind == .bruiser ? 0.1 : 0.2))
        punch = 0.7
        g.shake = 0.15
        g.snd?.thud()
        g.buzz?(false)
        gain(0.1, g)
        say(pos >= 0.9 ? "He is on the rail. Finish it!" : "A boot in the chest. He is open!")
    }

    func rects(_ g: Game) -> [(Double, Double, Double, Double)] {
        let bw = min(134.0, g.W * 0.17), bh = 50.0
        let lx = g.safeL + 4, rx = g.W - g.safeR - bw - 4
        let y2 = g.H - g.safeB - bh - 6, y1 = y2 - bh - 7, y0 = y1 - bh - 7
        return [(lx, y1, bw, bh), (lx, y2, bw, bh), (rx, y1, bw, bh), (rx, y2, bw, bh), (lx, y0, bw, bh), (rx, y0, bw, bh)]
    }
    func touch(_ x: Double, _ y: Double, _ g: Game) {
        if over || est == .dead { return }
        let r = rects(g)
        var hit = -1
        for (i, q) in r.enumerated() where x >= q.0 - 6 && x <= q.0 + q.2 + 6 && y >= q.1 - 4 && y <= q.1 + q.3 + 4 { hit = i }
        if hit < 0 {
            // anywhere else: the left half parries, the right half attacks, split high and low
            if y < 60 || flurry > 0 { return }
            let upper = y < r[1].1
            hit = x < g.W / 2 ? (upper ? 0 : 1) : (upper ? 2 : 3)
        }
        if hold {
            if hit != holdWant { say("Not that one"); return }
            hold = false
            cd = 0; pst = .ready; wind = max(wind, 0.4)
            if holdWant == 3 { lungeTaught = true }
        }
        if flurry > 0 { return }
        // the button answers the finger
        if hit >= 0 && hit < r.count { g.rings.append((r[hit].0, r[hit].1, r[hit].2, r[hit].3, 0)) }
        switch hit {
        case 0: parry(0, g)
        case 1: parry(1, g)
        case 2: sidestep(g)
        case 4: furyGo(g)
        case 5: kick(g)
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
        // both men breathe and shift their weight; nobody stands like a statue
        if pst == .ready { pp.lean += sin(t * 2.1) * 0.014; pp.crouch += (0.5 + 0.5 * sin(t * 2.1)) * 0.012 + abs(sin(t * 3.3)) * 0.006; pOff += sin(t * 1.3) * s * 0.012 }
        if est == .ready { ep.lean += sin(t * 2.4 + 1) * 0.016; ep.crouch += (0.5 + 0.5 * sin(t * 2.4 + 1)) * 0.012 + abs(sin(t * 3.7)) * 0.007; eOff += sin(t * 1.6 + 2) * s * 0.014 }
        pp.grit = pst == .lunge || pst == .parry || pst == .hurt
        ep.grit = est == .strike || est == .hit || (est == .wind && heavy)
        // and every pose is reached by moving there, quickly for a cut, easily otherwise
        let dtv = clampD(t - lastDrawT, 0, 0.05)
        lastDrawT = t
        func follow(_ cur: inout Pose, _ tg: Pose, _ rate: Double) {
            let k = 1 - exp(-rate * dtv)
            cur.pang = cur.ang
            cur.ang += (tg.ang - cur.ang) * k
            cur.reach += (tg.reach - cur.reach) * k
            cur.lean += (tg.lean - cur.lean) * (1 - exp(-rate * 0.7 * dtv))
            cur.crouch += (tg.crouch - cur.crouch) * (1 - exp(-rate * 0.6 * dtv))
            cur.fall = tg.fall; cur.flash = tg.flash; cur.trail = tg.trail; cur.twoHand = tg.twoHand; cur.grit = tg.grit
        }
        follow(&sp, pp, pp.trail ? 34 : (pst == .parry ? 30 : 16))
        follow(&se, ep, ep.trail ? 34 : 16)
        let ko = 1 - exp(-18 * dtv)
        sOffP += (pOff - sOffP) * ko
        sOffE += (eOff - sOffE) * (est == .enter ? 1 : ko)
        pp = sp; ep = se; pOff = sOffP; eOff = sOffE
        let (px, _) = playerXY(g)
        let (ex, _) = foeXY(g)
        // wet planks hold a smear of each man under his feet
        c.ell(px + pOff, fy + 10, s * 0.22, s * 0.05, Col(0x0a0604, 0.28)); c.ell(ex + eOff, fy + 10, s * 0.22, s * 0.05, Col(0x0a0604, 0.28))
        // the heavy blow glows red as it gathers
        if est == .wind && heavy {
            let q = clampD(1 - et / wd, 0, 1)
            c.glow(ex + eOff, fy - s * 0.9, s * 0.5, Col(0xff3a20, 0.55 * q), Col(0xff3a20, 0))
        }
        // the rest of them, waiting their turn and shouting; your own boarders behind you
        let waiting = max(0, foes - k - 1)
        for i in 0..<min(6, waiting) {
            var cp = Pose()
            cp.ang = -1.5 + sin(t * 5 + Double(i) * 1.7) * 0.5
            cp.crouch = abs(sin(t * 4 + Double(i))) * 0.03
            let big = boss && i == waiting - 1 && waiting <= 6
            fighter(c, W * 0.7 + Double(i) * W * 0.045 + sin(t * 2 + Double(i)) * 3, fy - 10 - Double(i % 2) * 9, s * (big ? 0.72 : 0.6), -1, cp, big ? 4 : (i % 3 == 2 ? 2 : 5))
        }
        for i in 0..<max(0, 3 - lost) {
            var cp = Pose()
            cp.ang = -1.4 + sin(t * 4.4 + Double(i) * 2.1) * 0.45
            fighter(c, W * 0.3 - Double(i) * W * 0.045, fy - 10 - Double(i % 2) * 9, s * 0.6, 1, cp, 0)
        }
        c.R(0, 0, W, H, Col(0x0a0604, 0.22))
        if flurry > 0 || bannerT > 1.2 && banner == "FURY!" {
            // the world goes gold while the flurry lasts
            c.R(0, 0, W, H, Col(0xffb040, 0.16))
            for i in 0..<14 {
                let a = Double(i) / 14 * PI * 2 + t * 2
                c.seg(px + s * 0.4 + cos(a) * s * 0.5, fy - s * 0.5 + sin(a) * s * 0.4, px + s * 0.4 + cos(a) * W, fy - s * 0.5 + sin(a) * W, 2, Col(0xffe08a, 0.12))
            }
        }
        // every hit punches the view in a little
        let zoom = 1 + punch * 0.05
        c.save()
        c.translate((px + ex) / 2, fy - s * 0.4)
        c.scale(zoom, zoom)
        c.translate(-(px + ex) / 2, -(fy - s * 0.4))
        fighter(c, px + pOff, fy, s, 1, pp, 0)
        fighter(c, ex + eOff, fy, s * (kind == .bruiser ? 1.08 : (kind == .captain ? 1.05 : 1)), -1, ep, kindIndex())
        g.drawSparks(c)
        c.restore()

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
            c.glow(cx, cy, 70, Col(0xfff0c0, clash * 2.5), Col(0xfff0c0, 0))
            // the flash lights the whole deck for an instant
            c.R(0, 0, W, H, Col(0xfff0c0, min(0.14, clash * 0.5)))
        }
        drawFx(c, g)
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
        // fury, filling under the wind
        g.gauge(c, g.safeL + 10, ny + 44, 110, 7, fury, Col(0xffe08a), Col(0xff6a20))
        c.textS(fury >= 1 ? "FURY READY" : "fury", g.safeL + 130, ny + 52, 11, fury >= 1 ? Col(0xffd257, 0.7 + 0.3 * sin(t * 10)) : CREAM, -1, fury >= 1 ? FONTB : FONTI)
        if combo >= 2 {
            let cs = 1 + 0.12 * sin(t * 12)
            c.save()
            c.translate(W / 2, ny + 26)
            c.scale(cs, cs)
            c.textS("×\(combo) COMBO", 0, 0, 15 + Double(min(6, combo)), combo >= 5 ? Col(0xff9a3a) : Col(0xffe08a), 0, FONTB)
            c.restore()
        }
        if bannerT > 0 && !banner.isEmpty {
            let q = clampD((1.6 - bannerT) / 0.18, 0, 1)
            c.save()
            c.alpha(min(1, bannerT * 2.2))
            c.translate(W / 2, H * 0.2)
            c.scale(2.4 - 1.4 * q, 2.4 - 1.4 * q)
            c.rotate(-0.03)
            c.text(banner, 2, 3, 34, Col(0x000000, 0.6), 0, FONTD)
            c.text(banner, 0, 0, 34, banner == "FURY!" ? Col(0xffb040) : Col(0xffe9a0), 0, FONTD)
            c.restore()
        }

        // the four moves
        let r = rects(g)
        let late = est == .wind && !heavy && !feint && et < pw + 0.06
        let names: [(String, String)] = [("Parry high", "stop a cut from above"), ("Parry low", "stop a thrust below"), ("Dodge", "slip a heavy blow"), ("Lunge", "when he is open"), ("Fury", fury >= 1 ? "three cuts, unstoppable" : "builds as you fight"), ("Kick", kickCd > 0 ? "catching your balance" : "shove him open")]
        for (i, q) in r.enumerated() {
            var on = false
            if i == 0 { on = late && line == 0 } else if i == 1 { on = late && line == 1 } else if i == 2 { on = est == .wind && heavy && et < 0.5 } else if i == 3 { on = est == .stag } else if i == 4 { on = fury >= 1 } else { on = false }
            if hold { on = i == holdWant }
            let need: Double = i < 2 ? 0.1 : (i == 2 ? 0.22 : (i == 3 ? 0.18 : (i == 5 ? 0.3 : 0)))
            let dim = hold ? i != holdWant : (i == 4 ? fury < 1 : (i == 5 ? (kickCd > 0 || wind < need) : wind < need))
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
            if i == 4 && fury < 1 { c.RR(x + 6, y + q.3 - 7, (q.2 - 12) * fury, 3, 1.5, Col(0xff9a3a)) }
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
        case .deckhand: return 5
        case .cutthroat: return 1
        case .bruiser: return 2
        case .duelist: return 3
        case .captain: return 4
        }
    }

    /// A fight ashore: the waterfront behind, cobbles underfoot, the town looking on.
    private func drawQuay(_ c: Canvas, _ g: Game) {
        let W = g.W, H = g.H
        let hz = H * 0.44
        g.drawSea(c, hz)
        // the far side of the harbour
        c.pathFill(Col(0x5f9450)) { p in
            p.move(to: CGPoint(x: -10, y: hz + 2))
            p.addQuadCurve(to: CGPoint(x: W * 0.5, y: hz - 60), control: CGPoint(x: W * 0.2, y: hz - 70))
            p.addQuadCurve(to: CGPoint(x: W + 10, y: hz - 30), control: CGPoint(x: W * 0.8, y: hz - 90))
            p.addLine(to: CGPoint(x: W + 10, y: hz + 2))
            p.closeSubpath()
        }
        // houses along the front, shutters open, people at every window
        var hx = -10.0
        var i = 0
        while hx < W + 10 {
            let hw = 64 + hashN(Double(i) * 2.9) * 40, hh = 90 + hashN(Double(i) * 6.1) * 70
            let base = H * 0.66
            let wall = [Col(0xf3ead2), Col(0xf0d8b0), Col(0xe8c8c0), Col(0xd8e4e8), Col(0xf6e6a8)][i % 5]
            c.R(hx, base - hh, hw, hh, wall.shade(0.85))
            c.poly([Col(0xb8452c), Col(0x8a5a36), Col(0xa63a2a)][i % 3], [hx - 4, base - hh, hx + hw / 2, base - hh - hw * 0.3, hx + hw + 4, base - hh])
            for r in 0..<2 {
                for q in 0..<2 {
                    let wx = hx + hw * (Double(q) + 0.5) / 2 - 8, wy2 = base - hh + 14 + Double(r) * 34
                    c.R(wx - 2, wy2 - 2, 20, 24, Col(0x3a2412)); c.R(wx, wy2, 16, 20, Col(0x2a3a4a))
                    if hashN(Double(i * 7 + r * 3 + q)) > 0.4 { c.circ(wx + 8, wy2 + 12 + sin(g.T * 4 + Double(i + q)) * 1.5, 4.5, Col(0xe3b58a)); c.R(wx + 3, wy2 + 15, 10, 5, [Col(0x2f5f8f), Col(0x8c3b2e), Col(0x3a7a6d)][(i + q) % 3]) }
                }
            }
            hx += hw + 4
            i += 1
        }
        // cobbles
        c.vfill(0, H * 0.66, W, H * 0.34, [(0, Col(0x8a8378)), (1, Col(0x4a463e))])
        for r in 0..<7 {
            let ry = H * 0.66 + Double(r * r) * 2.6 + 4
            c.R(0, ry, W, 1.2, Col(0x2a2622, 0.45))
            var cx = (r % 2 == 0 ? 0.0 : 20.0)
            while cx < W { c.R(cx, ry, 1.2, 6 + Double(r) * 2.4, Col(0x2a2622, 0.35)); cx += 40 + Double(r) * 6 }
        }
        c.R(0, 0, W, H, Col(0x0a0604, 0.12))
    }

    private func drawDeck(_ c: Canvas, _ g: Game) {
        if g.duelPort { drawQuay(c, g); return }
        let W = g.W, H = g.H
        let hz = H * 0.44
        g.drawSea(c, hz)
        let spar = Col(0x1c120a)
        let L = g.light()
        // ---- the pirate ship lashed alongside: her side, masts, red canvas, black flag
        let side = H * 0.5
        c.vfill(0, side - 26, W, H * 0.12 + 26, [(0, Col(0x2a1410)), (1, Col(0x120806))])
        c.R(0, side - 26, W, 4, Col(0x7a1b12)); c.R(0, side - 12, W, 2, Col(0xd4a52a, 0.5))
        for i in 0..<9 {
            let gx = W * (0.04 + Double(i) * 0.115)
            c.RR(gx, side - 6, 22, 16, 2, Col(0x0a0504)); c.RRStroke(gx, side - 6, 22, 16, 2, 1.2, Col(0x7a1b12))
            c.circ(gx + 11, side + 2, 5, Col(0x1c1c20)); c.circ(gx + 11, side + 2, 2.4, Col(0x000000))
        }
        for (i, mx) in [W * 0.14, W * 0.5, W * 0.86].enumerated() {
            let top = i == 1 ? -14.0 : H * 0.02
            c.R(mx - 6, top, 12, side - top, spar)
            c.R(mx - 6, top, 3, side - top, Col(0xffffff, 0.06))
            // shrouds and ratlines
            for sd in [-1.0, 1.0] {
                for k in 0..<3 { c.seg(mx, top + 26, mx + sd * (84 + Double(k) * 16), side - 20, 1.3, spar.alpha(0.85)) }
                for j in 1..<8 {
                    let f = Double(j) / 8
                    let yy = top + 26 + (side - 46 - top) * f
                    c.seg(mx + sd * 84 * f, yy, mx + sd * 116 * f, yy, 0.9, spar.alpha(0.6))
                }
            }
            // two yards of red canvas, bellying and luffing
            for lv in 0..<2 {
                let yy = H * (0.06 + Double(lv) * 0.17) + Double(i) * 5
                let hw = 92.0 - Double(lv) * 4, sh = H * 0.14
                let belly = sin(t * 1.3 + Double(i) * 1.7 + Double(lv)) * 9
                c.R(mx - hw - 8, yy - 3, hw * 2 + 16, 6, spar)
                c.pathGrad(yy, yy + sh, [(0, Col(0x9a2418)), (1, Col(0x5a110b))]) { q in
                    q.move(to: CGPoint(x: mx - hw, y: yy + 3))
                    q.addLine(to: CGPoint(x: mx + hw, y: yy + 3))
                    q.addQuadCurve(to: CGPoint(x: mx + hw - 6, y: yy + sh), control: CGPoint(x: mx + hw + belly, y: yy + sh * 0.5))
                    q.addQuadCurve(to: CGPoint(x: mx - hw + 6, y: yy + sh), control: CGPoint(x: mx, y: yy + sh + 10 + belly * 0.6))
                    q.addQuadCurve(to: CGPoint(x: mx - hw, y: yy + 3), control: CGPoint(x: mx - hw + belly, y: yy + sh * 0.5))
                }
                for sm in 1..<5 { c.seg(mx - hw + hw * 2 * Double(sm) / 5, yy + 5, mx - hw + hw * 2 * Double(sm) / 5 + belly * 0.3, yy + sh - 4, 0.8, Col(0x3a0a06, 0.6)) }
                // shot holes
                c.circ(mx - hw * 0.4, yy + sh * 0.55, 5, Col(0x2a0805)); c.circ(mx + hw * 0.5, yy + sh * 0.35, 3.5, Col(0x2a0805))
            }
            if i == 1 {
                // the black flag
                c.pathFill(Col(0x0c0c0e)) { q in
                    q.move(to: CGPoint(x: mx + 6, y: 2))
                    for st in 1...7 { q.addLine(to: CGPoint(x: mx + 6 + Double(st) * 9, y: 2 + sin(t * 5 + Double(st) * 0.8) * 3 * Double(st) / 7)) }
                    for st in stride(from: 7, through: 0, by: -1) { q.addLine(to: CGPoint(x: mx + 6 + Double(st) * 9, y: 34 + sin(t * 5 + Double(st) * 0.8) * 3 * Double(st) / 7)) }
                    q.closeSubpath()
                }
                c.circ(mx + 34, 15, 7, Col(0xf1e7cf)); c.R(mx + 30, 20, 8, 5, Col(0xf1e7cf))
                c.circ(mx + 31.5, 14, 1.8, Col(0x0c0c0e)); c.circ(mx + 36.5, 14, 1.8, Col(0x0c0c0e))
                c.seg(mx + 24, 28, mx + 44, 20, 2, Col(0xf1e7cf)); c.seg(mx + 24, 20, mx + 44, 28, 2, Col(0xf1e7cf))
            }
        }
        // grappling lines, taut between the ships, hooks bitten into your rail
        let ry = H * 0.58
        for i in 0..<4 {
            let gx = W * (0.2 + Double(i) * 0.2)
            c.curve(gx + 30, H * 0.3, gx + 10, H * 0.5, gx, ry - 2, 1.6, Col(0xc9b88a, 0.9))
            c.arcStroke(gx, ry + 1, 6, PI, PI * 2, 2.4, Col(0x23232a)); c.arcStroke(gx - 7, ry + 1, 4, 0, PI, 2, Col(0x23232a)); c.arcStroke(gx + 7, ry + 1, 4, 0, PI, 2, Col(0x23232a))
        }
        // powder smoke drifting between the hulls, sparks rising through it
        for i in 0..<9 {
            let span = W + 300
            var sx = (hashN(Double(i) * 3.3) * span + t * (14 + hashN(Double(i)) * 16)).truncatingRemainder(dividingBy: span)
            sx -= 150
            let sy = H * (0.2 + hashN(Double(i) * 7.1) * 0.34)
            c.ell(sx, sy, 110 + hashN(Double(i) * 2.2) * 70, 26 + hashN(Double(i) * 5.5) * 18, Col(0xd8d0c8, 0.09 + 0.05 * sin(t + Double(i))))
        }
        for i in 0..<14 {
            let ph = (t * (0.18 + hashN(Double(i)) * 0.2) + hashN(Double(i) * 4.4)).truncatingRemainder(dividingBy: 1)
            let ex2 = hashN(Double(i) * 9.1) * W + sin(t * 2 + Double(i)) * 14
            c.circ(ex2, H * 0.66 - ph * H * 0.6, 1.6, Col(0xffb040, 0.9 * (1 - ph)))
        }
        // ---- your rail: turned balusters, a cap that catches the light
        c.R(0, ry + 9, W, H * 0.08, Col(0x24150a, 0.55))
        var bx = 6.0
        while bx < W {
            c.RR(bx, ry + 8, 7, H * 0.085, 2, Col(0x4a2d14))
            c.ell(bx + 3.5, ry + 8 + H * 0.03, 5.5, 5, Col(0x5a3a1c)); c.ell(bx + 3.5, ry + 8 + H * 0.06, 4.5, 4, Col(0x5a3a1c))
            c.R(bx + 1, ry + 8, 1.5, H * 0.085, Col(0xffffff, 0.08))
            bx += 24
        }
        c.RR(-4, ry, W + 8, 10, 3, Col(0x6b4423)); c.R(0, ry, W, 2.5, Col(0xb07a3c)); c.R(0, ry + 8, W, 2, Col(0x24150a))
        c.R(0, ry + H * 0.085 + 6, W, 6, Col(0x33200f))
        // the fight goes on along the rail behind you: pairs trading cuts
        for i in 0..<3 {
            let x = W * (0.18 + Double(i) * 0.32) + sin(t * 0.7 + Double(i) * 2.1) * 10
            let y = H * 0.71
            let ph = t * (3.4 + Double(i) * 0.6) + Double(i) * 1.9
            var a = Pose(), b2 = Pose()
            a.ang = -0.5 + sin(ph) * 0.9; a.reach = max(0, sin(ph)) * 0.8; a.lean = 0.05 + max(0, sin(ph)) * 0.2
            b2.ang = -0.5 + sin(ph + 2.4) * 0.9; b2.reach = max(0, sin(ph + 2.4)) * 0.8; b2.lean = 0.05 + max(0, sin(ph + 2.4)) * 0.2
            fighter(c, x - H * 0.055, y, H * 0.19, 1, a, 0)
            fighter(c, x + H * 0.055, y, H * 0.19, -1, b2, i == 1 ? 2 : 5)
            if sin(ph) > 0.92 { c.glow(x, y - H * 0.12, 16, Col(0xfff0c0, 0.9), Col(0xfff0c0, 0)) }
        }
        c.R(0, ry + 10, W, H * 0.67 - ry - 10 + H * 0.06, Col(0x1a0c10, 0.28))
        // ---- the deck: long planks running to the rail, caulked seams, nail heads, worn and wet
        let dk = H * 0.67
        c.vfill(0, dk, W, H - dk, [(0, Col(0x8a5e36)), (0.5, Col(0x6b4423)), (1, Col(0x402612))])
        var py = dk
        var gapY = 6.0
        var row = 0
        while py < H {
            c.R(0, py, W, 1.6, Col(0x1c0f06, 0.5))
            c.R(0, py + 1.6, W, 1, Col(0xffffff, 0.05))
            // butt joints and nails, staggered row by row
            let persp = (py - dk) / (H - dk)
            var jx = (row % 2 == 0 ? 60.0 : 150.0)
            while jx < W {
                let x = W / 2 + (jx - W / 2) * (0.82 + persp * 0.43)
                c.R(x, py, 1.4, gapY, Col(0x1c0f06, 0.4))
                c.circ(x - 5, py + gapY * 0.3, 1 + persp, Col(0x1c0f06, 0.5)); c.circ(x + 5, py + gapY * 0.3, 1 + persp, Col(0x1c0f06, 0.5))
                jx += 190
            }
            py += gapY
            gapY *= 1.32
            row += 1
        }
        // grain, and a wet sheen where the light comes through the rigging
        for i in 0..<16 {
            let gy = dk + hashN(Double(i) * 3.7) * (H - dk), gx = hashN(Double(i) * 8.3) * W
            c.curve(gx, gy, gx + 40, gy + 2, gx + 90, gy - 1, 0.8, Col(0x2a1608, 0.25))
        }
        c.ell(W * 0.5, H * 0.86, W * 0.42, H * 0.07, Col(0xffe0a0, 0.07 + 0.02 * sin(t * 0.9)))
        // the shadow of the rigging sliding across the planks as the ships work
        let shd = sin(t * 0.5) * 24
        for i in 0..<6 { c.seg(W * (0.08 + Double(i) * 0.17) + shd, dk, W * (0.02 + Double(i) * 0.19) + shd * 1.6, H, 5, Col(0x000000, 0.07)) }
        // ---- gear on deck: a gun on its carriage at either side, shot, a cask, a coil of rope
        for sd in [-1.0, 1.0] {
            let cx = sd < 0 ? g.safeL * 0.3 + 34 : W - g.safeR * 0.3 - 34
            let cy = H * 0.75
            c.ell(cx, cy + 20, 46, 7, Col(0x000000, 0.3))
            c.poly(Col(0x4a2d14), [cx - 30, cy + 18, cx + 30, cy + 18, cx + 24, cy + 2, cx - 24, cy + 2])
            c.circ(cx - 20, cy + 16, 8, Col(0x2a1a0c)); c.circ(cx + 20, cy + 16, 8, Col(0x2a1a0c)); c.circ(cx - 20, cy + 16, 3, Col(0x6b4423)); c.circ(cx + 20, cy + 16, 3, Col(0x6b4423))
            c.save(); c.translate(cx, cy - 2); c.rotate(sd * -0.12)
            c.RRGrad(-34, -9, 68, 18, 8, [(0, Col(0x4a4a52)), (0.4, Col(0x23232a)), (1, Col(0x0c0c10))])
            c.RR(sd * 28 - 5, -11, 10, 22, 3, Col(0x1c1c22)); c.R(-34, -5, 68, 1.5, Col(0xffffff, 0.14))
            c.restore()
            for b in 0..<3 { c.circ(cx - sd * 46 + Double(b) * 9 - 9, cy + 20, 5, Col(0x1c1c22)); c.circ(cx - sd * 46 + Double(b) * 9 - 10.5, cy + 18.5, 1.5, Col(0xffffff, 0.2)) }
        }
        let kx = W * 0.5, ky = dk + 2
        c.ell(kx, ky + 3, 34, 6, Col(0x000000, 0.25))
        c.RRGrad(kx - 20, ky - 34, 40, 38, 8, [(0, Col(0x8a6238)), (1, Col(0x4a2d14))])
        c.R(kx - 21, ky - 26, 42, 3, Col(0x1c1c22)); c.R(kx - 21, ky - 8, 42, 3, Col(0x1c1c22)); c.ell(kx, ky - 34, 20, 4.5, Col(0x6b4423))
        for r in 0..<4 { c.ellStroke(kx + 52, ky - 2 - Double(r) * 3, 18 - Double(r) * 1.5, 5, 2.6, Col(0xc9b88a)) }
        // lantern light and dusk
        c.R(0, 0, W, H, Col(0x1a0c20, 0.1 + 0.2 * L.night))
        for (i, lx) in [W * 0.14, W * 0.86].enumerated() {
            let sway = sin(t * 1.2 + Double(i) * 2) * 6
            c.seg(lx, H * 0.27, lx + sway, H * 0.36, 1.2, spar)
            c.RR(lx + sway - 6, H * 0.36, 12, 16, 3, Col(0x23180c)); c.RR(lx + sway - 4, H * 0.36 + 2.5, 8, 11, 2, Col(0xffd98a))
            c.glow(lx + sway, H * 0.38, 150, Col(0xffb050, 0.32 + 0.05 * sin(t * 9 + Double(i))), Col(0xffb050, 0))
        }
        // shafts of light coming down through the smoke
        for i in 0..<4 {
            let rx = W * (0.2 + Double(i) * 0.2) + sin(t * 0.3 + Double(i)) * 20
            c.poly(Col(0xfff0c8, 0.045), [rx, 0, rx + 46, 0, rx - 60, H, rx - 150, H])
        }
        // darker toward the edges, so the eye stays on the two blades
        c.linear(0, 0, W * 0.22, H, 0, 0, W * 0.22, 0, [(0, Col(0x000000, 0.4)), (1, Col(0x000000, 0))])
        c.linear(W * 0.78, 0, W * 0.22, H, W * 0.78, 0, W, 0, [(0, Col(0x000000, 0)), (1, Col(0x000000, 0.4))])
    }

    /// One swordsman. (x, fy) is the ground between his feet; s is his height; dir is the way he faces.
    /// style: 0 your sailor, 1 cutthroat, 2 bruiser, 3 duelist, 4 captain, 5 deckhand
    private func fighter(_ c: Canvas, _ x: Double, _ fy: Double, _ s: Double, _ dir: Double, _ p: Pose, _ style: Int) {
        let st = min(5, max(0, style))
        let shirt = [Col(0xf1ead8), Col(0x8a8478), Col(0xc9a070), Col(0xf3eee2), Col(0xf3eee2), Col(0xe8e4d8)][st]
        let coat = [Col(0x2f5f8f), Col(0x26262c), Col(0x5a3a24), Col(0x1f4a52), Col(0x8a1b12), Col(0x3a5a7a)][st]
        let legC = [Col(0xe8e0cc), Col(0x2b2420), Col(0x3a2a1c), Col(0x23262c), Col(0x16100c), Col(0xb09a6a)][st]
        let skin = [Col(0xe3b58a), Col(0xc99a6e), Col(0xb98a5e), Col(0xdcae80), Col(0xc99a6e), Col(0xd2a070)][st]
        let hair = [Col(0x5a3a1c), Col(0x1c1410), Col(0x2a1c12), Col(0x3a2a1c), Col(0x100c0a), Col(0x8a5a2c)][st]
        let sash = [Col(0xb03a2a), Col(0x6a1a1a), Col(0x8a1a1a), Col(0x7a6a2a), Col(0xd4a52a), Col(0x3a5a3a)][st]
        let long = st == 3 || st == 4
        let bare = st == 2
        let wide = st == 2 ? 1.28 : 1.0
        let ink = Col(0x140c06)
        let ol = max(1.2, s * 0.012)
        let fl = sin(t * 5 + x * 0.02), fl2 = sin(t * 7 + x * 0.03)

        c.save()
        c.translate(x, fy)
        c.ell(0, 2, s * 0.3, s * 0.04, Col(0x000000, 0.4))
        if p.fall > 0 {
            c.alpha(1 - p.fall * 0.6)
            c.translate(0, p.fall * s * 0.02)
            c.rotate(-dir * p.fall * 1.35)
        }
        c.scale(dir, 1)
        c.roundCaps(true)

        // a limb that tapers, inked round its edge
        func limb(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ w0: Double, _ w1: Double, _ col: Col) {
            let dx = x1 - x0, dy = y1 - y0
            let len = max(0.001, (dx * dx + dy * dy).squareRoot())
            let nx = -dy / len, ny = dx / len
            for pass in 0..<2 {
                let e = pass == 0 ? ol : 0
                let cc = pass == 0 ? ink : col
                let a = w0 / 2 + e, b = w1 / 2 + e
                c.poly(cc, [x0 + nx * a, y0 + ny * a, x1 + nx * b, y1 + ny * b, x1 - nx * b, y1 - ny * b, x0 - nx * a, y0 - ny * a])
                c.circ(x0, y0, a, cc); c.circ(x1, y1, b, cc)
            }
            // light along the upper edge, shade along the lower, so the limb reads as round
            let up: Double = ny < 0 ? 1 : -1
            let lx0: Double = x0 + nx * up * w0 * 0.24, ly0: Double = y0 + ny * up * w0 * 0.24
            let lx1: Double = x1 + nx * up * w1 * 0.24, ly1: Double = y1 + ny * up * w1 * 0.24
            c.seg(lx0, ly0, lx1, ly1, max(1, w1 * 0.2), Col(0xffffff, 0.16))
            let dx0: Double = x0 - nx * up * w0 * 0.27, dy0: Double = y0 - ny * up * w0 * 0.27
            let dx1: Double = x1 - nx * up * w1 * 0.27, dy1: Double = y1 - ny * up * w1 * 0.27
            c.seg(dx0, dy0, dx1, dy1, max(1, w1 * 0.26), Col(0x000000, 0.2))
        }
        func boot(_ ax: Double, _ ay: Double, _ fx: Double) {
            // shaft, turned-down cuff, foot and heel
            limb(ax, ay, fx, -s * 0.045, s * 0.082 * wide, s * 0.07 * wide, Col(0x1c120a))
            c.pathFill(ink) { q in
                q.move(to: CGPoint(x: fx - s * 0.05, y: -s * 0.075)); q.addLine(to: CGPoint(x: fx + s * 0.05, y: -s * 0.07))
                q.addQuadCurve(to: CGPoint(x: fx + s * 0.13, y: -s * 0.002), control: CGPoint(x: fx + s * 0.13, y: -s * 0.05))
                q.addLine(to: CGPoint(x: fx - s * 0.055, y: 0)); q.closeSubpath()
            }
            c.pathFill(Col(0x2a1c10)) { q in
                q.move(to: CGPoint(x: fx - s * 0.04, y: -s * 0.068)); q.addLine(to: CGPoint(x: fx + s * 0.045, y: -s * 0.062))
                q.addQuadCurve(to: CGPoint(x: fx + s * 0.118, y: -s * 0.012), control: CGPoint(x: fx + s * 0.115, y: -s * 0.045))
                q.addLine(to: CGPoint(x: fx - s * 0.045, y: -s * 0.012)); q.closeSubpath()
            }
            c.seg(fx + s * 0.02, -s * 0.05, fx + s * 0.09, -s * 0.03, max(1, s * 0.008), Col(0xffffff, 0.2))
            c.seg(fx - s * 0.04, -s * 0.105, fx + s * 0.045, -s * 0.1, s * 0.016, Col(0x0c0806))
            c.RR(fx + s * 0.012, -s * 0.114, s * 0.022, s * 0.022, 1, Col(0xb8a070))
            c.RR(ax - s * 0.058 * wide + (fx - ax) * 0.1, ay - s * 0.012, s * 0.116 * wide, s * 0.04, s * 0.012, Col(0x3a2616))
            c.RRStroke(ax - s * 0.058 * wide + (fx - ax) * 0.1, ay - s * 0.012, s * 0.116 * wide, s * 0.04, s * 0.012, ol * 0.8, ink)
        }

        let crouch = p.crouch * s
        let hipX = p.reach * s * 0.1, hipY = -s * 0.47 + crouch
        let shX = hipX + sin(p.lean) * s * 0.3, shY = hipY - cos(p.lean) * s * 0.3
        let bfX = -s * (0.2 + max(0, p.reach) * 0.08), ffX = s * (0.15 + max(0, p.reach) * 0.24)
        let bkX = (hipX + bfX) / 2 - s * 0.02, bkY = hipY / 2 - s * 0.02
        let fkX = (hipX + ffX) / 2 + s * 0.07, fkY = hipY / 2 - s * 0.03 + crouch * 0.4

        // ---- the skirts of a long coat hang behind the legs and swing with the body
        if long {
            c.pathFill(ink) { q in
                q.move(to: CGPoint(x: hipX - s * 0.12, y: hipY - s * 0.08))
                q.addQuadCurve(to: CGPoint(x: hipX - s * (0.3 + p.reach * 0.04) + fl * s * 0.02, y: hipY + s * 0.3), control: CGPoint(x: hipX - s * 0.26, y: hipY + s * 0.08))
                q.addLine(to: CGPoint(x: hipX - s * 0.02 + fl2 * s * 0.012, y: hipY + s * 0.27))
                q.addLine(to: CGPoint(x: hipX + s * 0.1, y: hipY - s * 0.02))
                q.closeSubpath()
            }
            c.pathFill(coat.shade(0.62)) { q in
                q.move(to: CGPoint(x: hipX - s * 0.105, y: hipY - s * 0.07))
                q.addQuadCurve(to: CGPoint(x: hipX - s * (0.285 + p.reach * 0.04) + fl * s * 0.02, y: hipY + s * 0.285), control: CGPoint(x: hipX - s * 0.245, y: hipY + s * 0.08))
                q.addLine(to: CGPoint(x: hipX - s * 0.03 + fl2 * s * 0.012, y: hipY + s * 0.255))
                q.addLine(to: CGPoint(x: hipX + s * 0.09, y: hipY - s * 0.02))
                q.closeSubpath()
            }
            if st == 4 { c.curve(hipX - s * 0.24, hipY + s * 0.1, hipX - s * 0.27, hipY + s * 0.2, hipX - s * 0.28 + fl * s * 0.02, hipY + s * 0.28, s * 0.012, Col(0xd4a52a)) }
        }

        // ---- back leg, then the sash ends, then the back arm
        limb(hipX - s * 0.03, hipY, bkX, bkY, s * 0.115 * wide, s * 0.09 * wide, legC.shade(0.78))
        limb(bkX, bkY, bfX, -s * 0.2, s * 0.088 * wide, s * 0.074 * wide, legC.shade(0.78))
        boot(bfX - s * 0.004, -s * 0.2, bfX)
        for i in 0..<2 {
            let ex = hipX - s * (0.1 + Double(i) * 0.04), sw = (i == 0 ? fl : fl2) * s * 0.03
            c.curve(hipX - s * 0.07, hipY - s * 0.01, ex - s * 0.03, hipY + s * 0.07, ex - s * 0.06 + sw - p.reach * s * 0.05, hipY + s * 0.17 + Double(i) * s * 0.02, s * 0.034, ink)
            c.curve(hipX - s * 0.07, hipY - s * 0.01, ex - s * 0.03, hipY + s * 0.07, ex - s * 0.06 + sw - p.reach * s * 0.05, hipY + s * 0.17 + Double(i) * s * 0.02, s * 0.022, sash.shade(0.85))
        }
        let baX = shX - s * 0.2 - p.reach * s * 0.03, baY = shY + s * 0.2 - p.reach * s * 0.1
        let bex = shX - s * 0.13, bey = shY + s * 0.13
        limb(shX - s * 0.05, shY + s * 0.04, bex, bey, s * 0.075 * wide, s * 0.062 * wide, bare ? skin.shade(0.82) : coat.shade(0.7))
        limb(bex, bey, baX, baY, s * 0.06 * wide, s * 0.046 * wide, bare ? skin.shade(0.82) : (long ? coat.shade(0.7) : shirt.shade(0.8)))
        c.circ(baX, baY, s * 0.036 + ol, ink); c.circ(baX, baY, s * 0.036, skin.shade(0.88))

        // ---- front leg
        limb(hipX + s * 0.03, hipY, fkX, fkY, s * 0.125 * wide, s * 0.095 * wide, legC)
        limb(fkX, fkY, ffX, -s * 0.2, s * 0.092 * wide, s * 0.078 * wide, legC)
        if st == 5 || st == 0 { c.seg(hipX + s * 0.05, hipY + s * 0.04, fkX + s * 0.03, fkY - s * 0.02, max(1, s * 0.008), legC.shade(0.7)) }
        boot(ffX - s * 0.004, -s * 0.2, ffX)
        // cloth gathers at the knee and where the thigh meets the hip
        c.curve(fkX - s * 0.04, fkY - s * 0.02, fkX + s * 0.005, fkY + s * 0.012, fkX + s * 0.045, fkY - s * 0.015, max(1, s * 0.008), Col(0x000000, 0.28))
        c.curve(fkX - s * 0.03, fkY - s * 0.055, fkX + s * 0.01, fkY - s * 0.03, fkX + s * 0.04, fkY - s * 0.05, max(1, s * 0.006), Col(0x000000, 0.18))
        c.curve(hipX + s * 0.0, hipY + s * 0.05, hipX + s * 0.05, hipY + s * 0.075, hipX + s * 0.09, hipY + s * 0.055, max(1, s * 0.007), Col(0x000000, 0.22))
        c.curve(bkX - s * 0.035, bkY - s * 0.015, bkX, bkY + s * 0.012, bkX + s * 0.035, bkY - s * 0.012, max(1, s * 0.007), Col(0x000000, 0.25))

        // ---- the body: broad at the shoulder, drawn in at the waist
        let wS = s * 0.125 * wide, wH = s * 0.095 * wide
        func torso(_ grow: Double, _ fill: (CGMutablePath) -> Void) {
            let q = CGMutablePath()
            q.move(to: CGPoint(x: hipX - wH - grow, y: hipY + s * 0.02 + grow))
            q.addQuadCurve(to: CGPoint(x: shX - wS - grow, y: shY + s * 0.03), control: CGPoint(x: (hipX + shX) / 2 - wS * 0.72 - grow, y: (hipY + shY) / 2))
            q.addQuadCurve(to: CGPoint(x: shX + wS * 0.9 + grow, y: shY + s * 0.02), control: CGPoint(x: shX, y: shY - s * 0.045 - grow))
            q.addQuadCurve(to: CGPoint(x: hipX + wH + grow, y: hipY + s * 0.02 + grow), control: CGPoint(x: (hipX + shX) / 2 + wS * 0.95 + grow, y: (hipY + shY) / 2 - s * 0.02))
            q.closeSubpath()
            fill(q)
        }
        torso(ol) { q in c.pathFill(ink) { $0.addPath(q) } }
        torso(0) { q in c.pathGrad(shY - s * 0.04, hipY + s * 0.02, [(0, shirt), (1, shirt.shade(0.72))]) { $0.addPath(q) } }
        if st == 5 {
            // a striped jersey
            c.save()
            torso(0) { q in c.cg.addPath(q); c.cg.clip() }
            for k in 0..<7 { c.seg(hipX - s * 0.2, hipY - Double(k) * s * 0.05, shX + s * 0.2, hipY - Double(k) * s * 0.05 - s * 0.02, s * 0.018, Col(0x2f5f8f)) }
            c.restore()
        }
        // the open neck of the shirt
        if !bare { c.poly(skin.shade(0.92), [shX + s * 0.0, shY + s * 0.0, shX + s * 0.075, shY + s * 0.005, shX + s * 0.05, shY + s * 0.1]) }
        if bare {
            // a leather jerkin over a bare chest, and ink on the arm
            c.poly(skin, [shX - s * 0.02, shY + s * 0.0, shX + s * 0.09, shY + s * 0.01, shX + s * 0.06, hipY - s * 0.04, shX - s * 0.0, hipY - s * 0.04])
            c.seg(shX + s * 0.02, shY + s * 0.07, shX + s * 0.075, shY + s * 0.075, max(1, s * 0.008), skin.shade(0.75))
        }
        // jacket, vest or coat front: two panels with the shirt showing between
        if st != 5 {
            let cf = long ? coat : (bare ? coat : coat)
            c.pathFill(cf.shade(0.8)) { q in
                q.move(to: CGPoint(x: shX - wS, y: shY + s * 0.03))
                q.addQuadCurve(to: CGPoint(x: hipX - wH, y: hipY + s * 0.02), control: CGPoint(x: (hipX + shX) / 2 - wS * 0.72, y: (hipY + shY) / 2))
                q.addLine(to: CGPoint(x: hipX - wH * 0.1, y: hipY + s * 0.02))
                q.addLine(to: CGPoint(x: shX - s * 0.005, y: shY + s * 0.0))
                q.closeSubpath()
            }
            c.pathFill(cf) { q in
                q.move(to: CGPoint(x: shX + wS * 0.9, y: shY + s * 0.02))
                q.addQuadCurve(to: CGPoint(x: hipX + wH, y: hipY + s * 0.02), control: CGPoint(x: (hipX + shX) / 2 + wS * 0.95, y: (hipY + shY) / 2 - s * 0.02))
                q.addLine(to: CGPoint(x: hipX + wH * 0.45, y: hipY + s * 0.02))
                q.addLine(to: CGPoint(x: shX + s * 0.085, y: shY + s * 0.02))
                q.closeSubpath()
            }
            if long {
                // lapel, and a row of buttons
                c.poly(cf.shade(1.25), [shX + s * 0.085, shY + s * 0.02, shX + s * 0.12, shY + s * 0.1, shX + s * 0.07, shY + s * 0.13])
                for k in 0..<4 {
                    let f = 0.25 + Double(k) * 0.2
                    c.circ(lerp(shX + s * 0.09, hipX + wH * 0.5, f), lerp(shY + s * 0.06, hipY, f), s * 0.011, st == 4 ? Col(0xffd257) : Col(0xc8c8cc))
                }
            }
            if st == 4 {
                // gold lace and an epaulette
                c.curve(shX + s * 0.085, shY + s * 0.03, (hipX + shX) / 2 + wS * 0.6, (hipY + shY) / 2, hipX + wH * 0.5, hipY + s * 0.015, s * 0.012, Col(0xd4a52a))
                c.ell(shX + wS * 0.75, shY + s * 0.01, s * 0.05, s * 0.022, Col(0xd4a52a))
                for k in 0..<4 { c.seg(shX + wS * 0.55 + Double(k) * s * 0.022, shY + s * 0.025, shX + wS * 0.55 + Double(k) * s * 0.022, shY + s * 0.055, max(1, s * 0.008), Col(0xffd257)) }
            }
            if st == 3 { c.poly(Col(0xffffff), [shX + s * 0.01, shY + s * 0.0, shX + s * 0.075, shY + s * 0.01, shX + s * 0.06, shY + s * 0.075, shX + s * 0.025, shY + s * 0.06]) }
        }
        // a baldric across the chest, then the belt, buckle and sash knot
        if st == 1 || st == 2 || st == 4 {
            c.seg(shX - wS * 0.6, shY + s * 0.05, hipX + wH * 0.8, hipY - s * 0.02, s * 0.03, Col(0x2a1a0c))
            c.RR((shX - wS * 0.6 + hipX + wH * 0.8) / 2 - s * 0.018, (shY + s * 0.05 + hipY - s * 0.02) / 2 - s * 0.018, s * 0.036, s * 0.036, 1.5, Col(0xd4a52a))
        }
        c.seg(hipX - wH - s * 0.005, hipY, hipX + wH + s * 0.005, hipY, s * 0.062, ink)
        c.seg(hipX - wH, hipY, hipX + wH, hipY, s * 0.05, st == 0 || st == 5 ? sash : Col(0x2a1a0c))
        if st == 0 || st == 5 {
            c.circ(hipX - s * 0.06, hipY, s * 0.03, sash.shade(0.8))
        } else {
            c.RR(hipX + s * 0.01, hipY - s * 0.028, s * 0.056, s * 0.056, 2, Col(0xd4a52a)); c.RR(hipX + s * 0.024, hipY - s * 0.014, s * 0.028, s * 0.028, 1, Col(0x2a1a0c))
        }

        // the cloth pulls into folds from the sword shoulder down to the belt, and falls dark on the far side
        c.save()
        torso(0) { q in c.cg.addPath(q); c.cg.clip() }
        c.linear(shX - wS * 1.2, shY - s * 0.06, wS * 2.6, s * 0.4, shX - wS, 0, shX + wS, 0, [(0, Col(0x000000, 0.34)), (0.45, Col(0x000000, 0.05)), (1, Col(0xffffff, 0.08))])
        for k in 0..<3 {
            let kd = Double(k)
            let fx0: Double = shX + wS * (0.5 - kd * 0.35), fy0: Double = shY + s * (0.06 + kd * 0.012)
            let fx1: Double = hipX + wH * (0.1 - kd * 0.3), fy1: Double = hipY - s * 0.03
            c.curve(fx0, fy0, (fx0 + fx1) / 2 + s * 0.03, (fy0 + fy1) / 2, fx1, fy1, max(1, s * 0.007), Col(0x000000, 0.2))
        }
        c.curve(hipX - wH * 0.6, hipY - s * 0.03, hipX, hipY - s * 0.055, hipX + wH * 0.7, hipY - s * 0.03, max(1, s * 0.008), Col(0x000000, 0.22))
        c.restore()
        // lantern light catches his back edge
        c.curve(hipX - wH, hipY - s * 0.01, (hipX + shX) / 2 - wS * 0.74, (hipY + shY) / 2, shX - wS, shY + s * 0.035, max(1.2, s * 0.012), Col(0xffc070, 0.38))

        // ---- neck and head
        let hdX = shX + sin(p.lean) * s * 0.1 + s * 0.02, hdY = shY - s * 0.13
        let hr = s * 0.084
        limb(shX + s * 0.01, shY - s * 0.0, hdX - s * 0.005, hdY + s * 0.05, s * 0.07, s * 0.062, skin.shade(0.82))
        // hair behind the head: a queue, or a mane for the captain
        if st == 0 || st == 3 || st == 5 {
            c.curve(hdX - hr * 0.7, hdY, hdX - hr * 1.5, hdY + hr * 0.6, hdX - hr * 1.5 + fl * s * 0.02, hdY + hr * 1.7, s * 0.034, hair)
            c.circ(hdX - hr * 1.25, hdY + hr * 0.7, s * 0.017, st == 3 ? Col(0x111111) : sash)
        } else if st == 4 {
            for k in 0..<4 {
                let kd = Double(k)
                let c1x: Double = hdX - hr * (1.3 + kd * 0.12)
                let e1x: Double = hdX - hr * (1.0 + kd * 0.2) + fl * s * 0.015, e1y: Double = hdY + hr * (1.9 - kd * 0.2)
                c.curve(hdX - hr * 0.6, hdY - hr * 0.1, c1x, hdY + hr * 0.7, e1x, e1y, s * 0.036, hair)
            }
        }
        c.circ(hdX, hdY, hr + ol, ink)
        c.poly(ink, [hdX - hr * 0.2, hdY + hr * 0.5, hdX + hr * 0.95 + ol, hdY + hr * 0.25, hdX + hr * 0.72 + ol, hdY + hr * 1.2 + ol, hdX + hr * 0.1, hdY + hr * 1.12 + ol])
        c.circ(hdX, hdY, hr, skin)
        // jaw and chin, pushed forward
        c.poly(skin, [hdX - hr * 0.2, hdY + hr * 0.5, hdX + hr * 0.95, hdY + hr * 0.25, hdX + hr * 0.7, hdY + hr * 1.14, hdX + hr * 0.12, hdY + hr * 1.06])
        c.ell(hdX + hr * 0.1, hdY + hr * 0.5, hr * 0.8, hr * 0.5, Col(0x000000, 0.06))
        // ear, nose, mouth
        c.ell(hdX - hr * 0.28, hdY + hr * 0.12, hr * 0.2, hr * 0.28, skin.shade(0.8))
        c.poly(skin.shade(0.9), [hdX + hr * 0.86, hdY - hr * 0.05, hdX + hr * 1.2, hdY + hr * 0.32, hdX + hr * 0.84, hdY + hr * 0.38])
        c.circ(hdX + hr * 0.98, hdY + hr * 0.3, max(0.7, hr * 0.06), Col(0x3a1a10, 0.7))
        c.ell(hdX + hr * 0.35, hdY + hr * 0.45, hr * 0.3, hr * 0.2, Col(0x8a3a2a, 0.12))
        c.curve(hdX - hr * 0.1, hdY + hr * 0.95, hdX + hr * 0.3, hdY + hr * 1.2, hdX + hr * 0.7, hdY + hr * 1.1, max(1, s * 0.012), Col(0x000000, 0.18))
        if p.grit {
            // teeth bared with the effort
            c.RR(hdX + hr * 0.5, hdY + hr * 0.62, hr * 0.4, hr * 0.2, hr * 0.05, Col(0x3a140c))
            c.RR(hdX + hr * 0.54, hdY + hr * 0.64, hr * 0.33, hr * 0.1, hr * 0.03, Col(0xf7f2e4))
        } else {
            c.seg(hdX + hr * 0.52, hdY + hr * 0.7, hdX + hr * 0.86, hdY + hr * (st == 0 ? 0.66 : 0.74), max(1, s * 0.01), Col(0x4a2014))
        }
        c.arcStroke(hdX, hdY, hr * 0.94, PI * 0.75, PI * 1.25, max(1, s * 0.01), Col(0xffc070, 0.4))
        // eye and brow: your man steady, theirs scowling
        let ex = hdX + hr * 0.52, ey = hdY - hr * 0.05
        c.ell(ex, ey, hr * 0.2, hr * 0.14, Col(0xffffff))
        c.circ(ex + hr * 0.07, ey, hr * 0.09, Col(0x16100a))
        c.seg(ex - hr * 0.26, ey - hr * (st == 0 ? 0.26 : 0.34), ex + hr * 0.3, ey - hr * (st == 0 ? 0.3 : 0.14), max(1.2, s * 0.016), hair.shade(0.7))
        if st == 1 {
            // a patch over the other eye, and its cord
            c.seg(hdX - hr * 0.9, hdY - hr * 0.5, hdX + hr * 0.95, hdY - hr * 0.2, max(1, s * 0.008), ink)
            c.ell(hdX + hr * 0.2, hdY - hr * 0.1, hr * 0.2, hr * 0.17, ink)
            c.seg(hdX + hr * 0.3, hdY + hr * 0.3, hdX + hr * 0.6, hdY + hr * 0.45, max(1, s * 0.007), Col(0x7a2a1a))
        }
        // beard, by the man
        if st == 2 || st == 4 {
            c.pathFill(hair) { q in
                q.move(to: CGPoint(x: hdX - hr * 0.3, y: hdY + hr * 0.3))
                q.addQuadCurve(to: CGPoint(x: hdX + hr * 0.95, y: hdY + hr * 0.5), control: CGPoint(x: hdX + hr * 0.3, y: hdY + hr * 0.75))
                q.addQuadCurve(to: CGPoint(x: hdX + hr * (st == 4 ? 0.7 : 0.55), y: hdY + hr * (st == 4 ? 2.0 : 1.7)), control: CGPoint(x: hdX + hr * 1.1, y: hdY + hr * 1.3))
                q.addQuadCurve(to: CGPoint(x: hdX - hr * 0.3, y: hdY + hr * 0.3), control: CGPoint(x: hdX - hr * 0.2, y: hdY + hr * 1.4))
            }
            c.seg(hdX + hr * 0.5, hdY + hr * 0.82, hdX + hr * 0.84, hdY + hr * 0.86, max(1, s * 0.01), Col(0x6a2a1a))
            if st == 4 { for k in 0..<2 { c.circ(hdX + hr * (0.45 + Double(k) * 0.25), hdY + hr * 1.8, s * 0.008, Col(0xffb040)) } }
        } else if st == 3 {
            c.curve(hdX + hr * 0.45, hdY + hr * 0.52, hdX + hr * 0.8, hdY + hr * 0.42, hdX + hr * 1.15, hdY + hr * 0.6, max(1.2, s * 0.014), hair)
            c.poly(hair, [hdX + hr * 0.5, hdY + hr * 0.95, hdX + hr * 0.75, hdY + hr * 0.92, hdX + hr * 0.62, hdY + hr * 1.35])
        } else if st == 1 {
            for k in 0..<6 { c.circ(hdX + hr * (0.2 + Double(k) * 0.12), hdY + hr * (0.8 + Double(k % 2) * 0.12), max(0.6, s * 0.006), hair.alpha(0.7)) }
        }
        if st == 1 || st == 2 || st == 4 { c.circStroke(hdX - hr * 0.3, hdY + hr * 0.5, hr * 0.16, max(1, s * 0.008), Col(0xffd257)) }
        // what he wears on his head
        if st == 0 || st == 1 || st == 2 {
            let bc = st == 0 ? sash : (st == 1 ? Col(0x16161a) : Col(0x8a1a1a))
            c.pathFill(bc) { q in
                q.move(to: CGPoint(x: hdX - hr * 1.02, y: hdY - hr * 0.12))
                q.addQuadCurve(to: CGPoint(x: hdX + hr * 1.0, y: hdY - hr * 0.42), control: CGPoint(x: hdX + hr * 0.1, y: hdY - hr * 0.1))
                q.addQuadCurve(to: CGPoint(x: hdX - hr * 1.02, y: hdY - hr * 0.12), control: CGPoint(x: hdX - hr * 0.2, y: hdY - hr * 1.7))
            }
            c.curve(hdX - hr * 0.9, hdY - hr * 0.2, hdX + hr * 0.1, hdY - hr * 0.22, hdX + hr * 0.98, hdY - hr * 0.44, max(1, s * 0.012), bc.shade(0.65))
            // the knot and its two tails, streaming
            c.circ(hdX - hr * 0.98, hdY - hr * 0.1, hr * 0.2, bc.shade(0.8))
            c.curve(hdX - hr * 1.0, hdY - hr * 0.1, hdX - hr * 1.6, hdY + hr * 0.1 + fl * hr * 0.2, hdX - hr * 2.2, hdY + hr * 0.5 + fl * hr * 0.5, s * 0.024, bc)
            c.curve(hdX - hr * 1.0, hdY - hr * 0.1, hdX - hr * 1.5, hdY - hr * 0.2 + fl2 * hr * 0.2, hdX - hr * 2.0, hdY - hr * 0.1 + fl2 * hr * 0.5, s * 0.02, bc.shade(0.85))
        } else if st == 5 {
            // a knitted cap with a bobble
            c.arcFill(hdX - hr * 0.05, hdY - hr * 0.2, hr * 1.04, PI * 1.02, PI * 1.98, sash)
            c.RR(hdX - hr * 1.1, hdY - hr * 0.36, hr * 2.1, hr * 0.3, hr * 0.12, sash.shade(0.75))
            c.circ(hdX - hr * 0.5, hdY - hr * 1.2, hr * 0.2, Col(0xf1ead8))
        } else {
            // a cocked hat: black felt, bound with braid; the captain's carries a plume
            let hc = Col(0x14100e)
            c.pathFill(ink) { q in
                q.move(to: CGPoint(x: hdX - hr * 1.95, y: hdY - hr * 0.42))
                q.addQuadCurve(to: CGPoint(x: hdX + hr * 2.05, y: hdY - hr * 0.62), control: CGPoint(x: hdX, y: hdY - hr * 0.12))
                q.addQuadCurve(to: CGPoint(x: hdX + hr * 0.1, y: hdY - hr * 2.3), control: CGPoint(x: hdX + hr * 1.3, y: hdY - hr * 1.5))
                q.addQuadCurve(to: CGPoint(x: hdX - hr * 1.95, y: hdY - hr * 0.42), control: CGPoint(x: hdX - hr * 1.2, y: hdY - hr * 1.4))
            }
            c.pathFill(hc) { q in
                q.move(to: CGPoint(x: hdX - hr * 1.82, y: hdY - hr * 0.48))
                q.addQuadCurve(to: CGPoint(x: hdX + hr * 1.92, y: hdY - hr * 0.66), control: CGPoint(x: hdX, y: hdY - hr * 0.22))
                q.addQuadCurve(to: CGPoint(x: hdX + hr * 0.1, y: hdY - hr * 2.15), control: CGPoint(x: hdX + hr * 1.2, y: hdY - hr * 1.45))
                q.addQuadCurve(to: CGPoint(x: hdX - hr * 1.82, y: hdY - hr * 0.48), control: CGPoint(x: hdX - hr * 1.1, y: hdY - hr * 1.35))
            }
            c.curve(hdX - hr * 1.8, hdY - hr * 0.5, hdX, hdY - hr * 0.26, hdX + hr * 1.9, hdY - hr * 0.68, max(1.2, s * 0.016), st == 4 ? Col(0xd4a52a) : Col(0x8a8a90))
            if st == 4 {
                for k in 0..<3 {
                    let kd = Double(k)
                    let c1x: Double = hdX - hr * (1.6 + kd * 0.3), c1y: Double = hdY - hr * (3.4 - kd * 0.3)
                    let e1x: Double = hdX - hr * (3.0 + kd * 0.2) + fl * hr * 0.3, e1y: Double = hdY - hr * (2.2 - kd * 0.45)
                    c.curve(hdX - hr * 0.3, hdY - hr * 1.7, c1x, c1y, e1x, e1y, s * (0.04 - kd * 0.008), k == 0 ? Col(0xf3ead2) : Col(0xd8cdb0))
                }
                c.circ(hdX + hr * 0.3, hdY - hr * 1.0, hr * 0.2, Col(0xd4a52a)); c.circ(hdX + hr * 0.3, hdY - hr * 1.0, hr * 0.09, Col(0x8a1b12))
            } else {
                c.circ(hdX + hr * 0.3, hdY - hr * 1.0, hr * 0.14, Col(0xc8c8cc))
            }
        }

        // ---- the sword arm: shoulder, elbow, wrist; then the hilt and the blade
        let armLen = s * (0.24 + max(-0.3, p.reach) * 0.07)
        let armA = p.ang * 0.62 - 0.12
        let hx = shX + cos(armA) * armLen, hy = shY + s * 0.04 + sin(armA) * armLen
        let sx0 = shX + s * 0.02, sy0 = shY + s * 0.04
        let bend = s * 0.07 * (1 - clampD(p.reach, 0, 1) * 0.85)
        let elX = (sx0 + hx) / 2 + sin(armA) * bend * -1, elY = (sy0 + hy) / 2 + cos(armA) * bend
        let armC = bare ? skin : (long || st == 0 ? coat : shirt)
        if p.twoHand {
            limb(shX - s * 0.02, shY + s * 0.07, hx - s * 0.03, hy + s * 0.03, s * 0.06 * wide, s * 0.046 * wide, armC.shade(0.8))
        }
        limb(sx0, sy0, elX, elY, s * 0.082 * wide, s * 0.066 * wide, armC)
        limb(elX, elY, hx, hy, s * 0.066 * wide, s * 0.05 * wide, armC)
        if bare {
            // an anchor inked on the upper arm, and a leather bracer
            c.seg((sx0 + elX) / 2, (sy0 + elY) / 2 - s * 0.02, (sx0 + elX) / 2, (sy0 + elY) / 2 + s * 0.02, max(1, s * 0.008), Col(0x2f4a6a, 0.8))
            c.arcStroke((sx0 + elX) / 2, (sy0 + elY) / 2 + s * 0.012, s * 0.014, 0, PI, max(1, s * 0.008), Col(0x2f4a6a, 0.8))
            limb(lerp(elX, hx, 0.45), lerp(elY, hy, 0.45), lerp(elX, hx, 0.9), lerp(elY, hy, 0.9), s * 0.064 * wide, s * 0.056 * wide, Col(0x3a2616))
        } else if long || st == 3 {
            // a deep cuff, and lace at the wrist
            limb(lerp(elX, hx, 0.62), lerp(elY, hy, 0.62), lerp(elX, hx, 0.92), lerp(elY, hy, 0.92), s * 0.078, s * 0.074, armC.shade(1.25))
            c.circ(lerp(elX, hx, 0.98), lerp(elY, hy, 0.98), s * 0.03, Col(0xffffff, 0.9))
        }
        let ca = cos(p.ang), sa = sin(p.ang)
        let nx = -sa, ny = ca
        let heavy = st == 2
        let rapier = st == 3
        let bl = s * (heavy ? 0.52 : (rapier ? 0.5 : 0.45))
        let tipX = hx + ca * bl, tipY = hy + sa * bl
        // any quick movement of the sword smears: the space between where it was and where it is
        let sweep = p.ang - p.pang
        if abs(sweep) > 0.05 && abs(sweep) < 2.6 {
            let rad = armLen + bl
            let a0 = min(p.ang, p.pang), a1 = max(p.ang, p.pang)
            let al = min(0.42, abs(sweep) * 1.1)
            c.pathFill(Col(0xffffff, al * 0.5)) { q in
                q.move(to: CGPoint(x: shX + cos(a0) * rad * 0.42, y: shY + sin(a0) * rad * 0.42))
                q.addArc(center: CGPoint(x: shX, y: shY), radius: CGFloat(rad), startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
                q.addLine(to: CGPoint(x: shX + cos(a1) * rad * 0.42, y: shY + sin(a1) * rad * 0.42))
                q.addArc(center: CGPoint(x: shX, y: shY), radius: CGFloat(rad * 0.42), startAngle: CGFloat(a1), endAngle: CGFloat(a0), clockwise: true)
                q.closeSubpath()
            }
            c.pathStroke(Col(0xffffff, al), max(1.2, s * 0.01)) { q in
                q.addArc(center: CGPoint(x: shX, y: shY), radius: CGFloat(rad), startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
            }
        }
        // the cut, hanging in the air behind the blade
        if p.trail {
            for k in 0..<5 {
                let a0 = p.ang - 1.05 + Double(k) * 0.2
                c.pathStroke(Col(0xffffff, 0.06 + Double(k) * 0.07), s * (0.2 - Double(k) * 0.03)) { q in
                    q.addArc(center: CGPoint(x: shX, y: shY), radius: CGFloat(armLen + bl * 0.72), startAngle: CGFloat(a0), endAngle: CGFloat(p.ang), clockwise: false)
                }
            }
            c.pathStroke(Col(0xfff6d8, 0.9), max(1.5, s * 0.012)) { q in
                q.addArc(center: CGPoint(x: shX, y: shY), radius: CGFloat(armLen + bl), startAngle: CGFloat(p.ang - 0.7), endAngle: CGFloat(p.ang), clockwise: false)
            }
        }
        // blade: a dark back, a bright edge, a fuller, a point that catches the light
        let bw = s * (heavy ? 0.036 : (rapier ? 0.011 : 0.024))
        let curveK = rapier ? 0.0 : 2.4
        for pass in 0..<2 {
            let e = pass == 0 ? ol : 0
            c.pathFill(pass == 0 ? ink : Col(0xeef2f5)) { q in
                q.move(to: CGPoint(x: hx + nx * (bw + e), y: hy + ny * (bw + e)))
                q.addQuadCurve(to: CGPoint(x: tipX + ca * e, y: tipY + sa * e), control: CGPoint(x: hx + ca * bl * 0.6 + nx * (bw * curveK + bw + e), y: hy + sa * bl * 0.6 + ny * (bw * curveK + bw + e)))
                q.addQuadCurve(to: CGPoint(x: hx - nx * (bw + e), y: hy - ny * (bw + e)), control: CGPoint(x: hx + ca * bl * 0.6 - nx * (bw * 0.4 + e), y: hy + sa * bl * 0.6 - ny * (bw * 0.4 + e)))
                q.closeSubpath()
            }
        }
        c.pathFill(Col(0x9aa6b0)) { q in
            q.move(to: CGPoint(x: hx - nx * bw, y: hy - ny * bw))
            q.addQuadCurve(to: CGPoint(x: tipX, y: tipY), control: CGPoint(x: hx + ca * bl * 0.6 - nx * bw * 0.4, y: hy + sa * bl * 0.6 - ny * bw * 0.4))
            q.addQuadCurve(to: CGPoint(x: hx, y: hy), control: CGPoint(x: hx + ca * bl * 0.6 + nx * bw * curveK * 0.45, y: hy + sa * bl * 0.6 + ny * bw * curveK * 0.45))
            q.closeSubpath()
        }
        if !rapier {
            let f1x: Double = hx + ca * bl * 0.45 + nx * bw * curveK * 0.5, f1y: Double = hy + sa * bl * 0.45 + ny * bw * curveK * 0.5
            c.curve(hx + ca * bl * 0.08, hy + sa * bl * 0.08, f1x, f1y, hx + ca * bl * 0.78, hy + sa * bl * 0.78, max(0.8, s * 0.005), Col(0x5a6670, 0.8))
        }
        let e0x: Double = hx + nx * bw * 0.6 + ca * bl * 0.1, e0y: Double = hy + ny * bw * 0.6 + sa * bl * 0.1
        let e1x: Double = hx + ca * bl * 0.55 + nx * bw * (curveK + 0.5), e1y: Double = hy + sa * bl * 0.55 + ny * bw * (curveK + 0.5)
        c.curve(e0x, e0y, e1x, e1y, hx + ca * bl * 0.92, hy + sa * bl * 0.92, max(0.8, s * 0.006), Col(0xffffff, 0.9))
        // a glint slides from hilt to point as the steel turns in the light
        let run = (t * 0.7 + x * 0.003).truncatingRemainder(dividingBy: 1)
        if run < 0.45 {
            let f = run / 0.45
            let gx0: Double = hx + ca * bl * f, gy0: Double = hy + sa * bl * f
            c.seg(gx0, gy0, gx0 + ca * bl * 0.12, gy0 + sa * bl * 0.12, max(1.5, bw * 1.3), Col(0xffffff, 0.75 * sin(f * PI)))
        }
        let gl = 0.5 + 0.5 * sin(t * 6 + x * 0.05)
        if gl > 0.8 || p.trail {
            let gs = s * 0.045 * (p.trail ? 1.4 : gl)
            c.seg(tipX - gs, tipY, tipX + gs, tipY, max(1, s * 0.006), Col(0xffffff, 0.9)); c.seg(tipX, tipY - gs, tipX, tipY + gs, max(1, s * 0.006), Col(0xffffff, 0.9))
            c.glow(tipX, tipY, gs * 1.4, Col(0xffffff, 0.5), Col(0xffffff, 0))
        }
        // hilt: grip and pommel, then a cup, a shell or a knuckle-bow according to the weapon
        let gold = st == 4 || st == 3 ? Col(0xffd257) : (st == 0 ? Col(0xd4a52a) : Col(0x9a8a6a))
        c.seg(hx - ca * s * 0.07, hy - sa * s * 0.07, hx, hy, s * 0.034, ink)
        c.seg(hx - ca * s * 0.065, hy - sa * s * 0.065, hx, hy, s * 0.024, Col(0x4a2d14))
        c.circ(hx - ca * s * 0.075, hy - sa * s * 0.075, s * 0.02, gold)
        if rapier {
            c.seg(hx + nx * s * 0.075, hy + ny * s * 0.075, hx - nx * s * 0.075, hy - ny * s * 0.075, s * 0.014, gold)
            c.ell(hx + ca * s * 0.012, hy + sa * s * 0.012, s * 0.04, s * 0.04, gold.shade(0.85)); c.circ(hx + ca * s * 0.012, hy + sa * s * 0.012, s * 0.022, gold)
        } else {
            c.seg(hx + nx * s * 0.06, hy + ny * s * 0.06, hx - nx * s * 0.05, hy - ny * s * 0.05, s * 0.026, ink)
            c.seg(hx + nx * s * 0.055, hy + ny * s * 0.055, hx - nx * s * 0.045, hy - ny * s * 0.045, s * 0.018, gold)
            // the bow that guards the knuckles
            c.curve(hx + nx * s * 0.055, hy + ny * s * 0.055, hx + nx * s * 0.075 - ca * s * 0.05, hy + ny * s * 0.075 - sa * s * 0.05, hx - ca * s * 0.075, hy - sa * s * 0.075, s * 0.014, gold)
        }
        // the hand, over the grip
        c.circ(hx - ca * s * 0.022, hy - sa * s * 0.022, s * 0.038 + ol, ink)
        c.circ(hx - ca * s * 0.022, hy - sa * s * 0.022, s * 0.038, skin)
        for k in 0..<3 {
            let back = 0.04 - Double(k) * 0.016
            let kx: Double = hx - ca * s * back
            let ky: Double = hy - sa * s * back
            c.seg(kx + nx * s * 0.022, ky + ny * s * 0.022, kx + nx * s * 0.036, ky + ny * s * 0.036, max(0.8, s * 0.006), skin.shade(0.7))
        }

        // struck: the whole man flares white for an instant
        if p.flash > 0 {
            let a = min(0.75, p.flash * 2)
            torso(ol) { q in c.pathFill(Col(0xffffff, a)) { $0.addPath(q) } }
            c.circ(hdX, hdY, hr + ol, Col(0xffffff, a))
            c.glow(shX, shY + s * 0.1, s * 0.45, Col(0xffffff, a * 0.6), Col(0xffffff, 0))
        }
        c.restore()
    }
}
