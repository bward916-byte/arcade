import CoreGraphics
import Foundation

// A port town seen from the anchorage: hills, houses, a busy quay, boats in the bay, and something going on.

extension Game {
    /// The top of the quay, where people walk.
    func quayY() -> Double { return H * 0.5 + 26 }

    func updateTown(_ dt: Double) {
        if sum != nil { return }
        bellT -= dt
        if bellT <= 0 {
            snd?.bell()
            bellSwing = 2.5
            bellT = rnd(16, 28)
        }
        bellSwing = max(0, bellSwing - dt)
        // a salute as you come ashore: guns from the quay, a cheer, streamers
        if saluteN > 0 {
            saluteT -= dt
            if saluteT < 4.4 - Double(3 - saluteN) * 0.7 {
                saluteN -= 1
                snd?.cannon()
                shake = max(shake, 0.1)
                let gx = W * (0.46 + Double(saluteN) * 0.07)
                puff(gx, quayY() - 6, 26, Col(0xf0f0f0, 0.85), 120, -30, 5, 1.3)
                puff(gx, quayY() - 6, 8, Col(0xffd257), 200, 100, 2.4, 0.3)
                for _ in 0..<3 { puff(rnd(W * 0.45, W * 0.95), rnd(60, H * 0.36), 14, [Col(0xff5a5a), Col(0xffd257), Col(0x7fd8ff), Col(0x9ff0aa)][rndI(0, 3)], 120, 160, 2.4, 1.6) }
                if saluteN == 0 { snd?.wash(2.2, 0.12, 700, 1500, q: 1.2, att: 0.3, rel: 1.4) }
            }
        }
        // someone on the quay always has something to say
        chatT -= dt
        if chatT <= 0 {
            chatT = rnd(2.6, 4.2)
            chatWho = rndI(0, 12)
            chatLine = rndI(0, 19)
        }
        // hammering from the shipyard, and the fireworks of a festival night
        if chance(dt * 0.5) { snd?.tone(190, 0.05, 3, 0.022, 120); snd?.tone(190, 0.05, 3, 0.018, 120, 0.22) }
        if festT > 0 {
            festT -= dt
            if chance(dt * 2.4) {
                let x = rnd(W * 0.42, W * 0.95), y = rnd(40, H * 0.34)
                let col = [Col(0xff5a5a), Col(0xffd257), Col(0x7fd8ff), Col(0x9ff0aa), Col(0xff9af0)][rndI(0, 4)]
                puff(x, y, 46, col, 210, 90, 2.6, 1.2)
                puff(x, y, 14, WHITE, 90, 60, 1.8, 0.7)
                flashT = max(flashT, 0.08)
                snd?.noise(0.35, 0.16, 700, 1)
                snd?.tone(1800, 0.3, 4, 0.03, 4000)
            }
        }
    }

    /// What the ship needs for the next passage, and whether she has it.
    func portNeeds() -> (days: Int, foodDays: Int, waterDays: Int, foodOK: Bool, waterOK: Bool, hullPct: Int, hullOK: Bool, repair: Int, down: Int, crewOK: Bool, wagesOK: Bool, canUpgrade: Bool) {
        let days = Int((LEG[min(4, leg)] / max(1, 42 * ship.speed)).rounded(.up)) + 2
        let perDay = max(0.1, Double(crew) * RATION)
        let fd = Int(food / perDay), wd = Int(water / perDay)
        let pct = Int((hull / Double(max(1, ship.hull)) * 100).rounded())
        let down = laidUp()
        var canUp = false
        for y in Game.YARD where up(y.k) < y.max && gold - wagesDue() >= y.cost + up(y.k) * (y.cost * 3 / 4) { canUp = true }
        return (days * SUNS, fd * SUNS, wd * SUNS, fd >= days, wd >= days, pct, pct >= 70, Int(Double(ship.hull) - hull) * 2, down, down == 0 && crew >= max(2, ship.crew - 2), gold >= wagesDue(), canUp)
    }

    /// A small townsperson walking the quay.
    private func townie(_ c: Canvas, _ x: Double, _ y: Double, _ s: Double, _ coat: Col, _ dir: Double, _ phase: Double, carry: Int, dark: Double) {
        let st = sin(T * 7 + phase)
        let skin = Col(0xe3b58a).shade(dark)
        c.seg(x, y - 7 * s, x + st * 3 * s, y, 2.2 * s, Col(0x2a2018).shade(dark))
        c.seg(x, y - 7 * s, x - st * 3 * s, y, 2.2 * s, Col(0x2a2018).shade(dark))
        c.RR(x - 3.2 * s, y - 17 * s, 6.4 * s, 11 * s, 2 * s, coat.shade(dark))
        c.circ(x, y - 20 * s, 3.2 * s, skin)
        if carry == 1 {
            // a crate on the shoulder
            c.RR(x - 5 * s + dir * 2 * s, y - 30 * s, 10 * s, 8 * s, 1, Col(0xa8823f).shade(dark))
            c.seg(x + dir * 3 * s, y - 15 * s, x + dir * 4 * s, y - 23 * s, 1.8 * s, coat.shade(dark * 0.85))
        } else if carry == 2 {
            // a basket of fish
            c.arcFill(x + dir * 6 * s, y - 9 * s, 4 * s, 0, PI, Col(0x8a6a44).shade(dark))
            c.seg(x + dir * 2 * s, y - 14 * s, x + dir * 6 * s, y - 9 * s, 1.6 * s, coat.shade(dark * 0.85))
        } else {
            c.seg(x, y - 15 * s, x - st * 3.5 * s, y - 8 * s, 1.8 * s, coat.shade(dark * 0.85))
        }
        if Int(phase * 10) % 3 == 0 { c.R(x - 4 * s, y - 24 * s, 8 * s, 1.6 * s, Col(0x3a2412).shade(dark)); c.R(x - 2.6 * s, y - 27 * s, 5.2 * s, 3.4 * s, Col(0x3a2412).shade(dark)) }
    }

    func drawPort(_ c: Canvas) {
        let hz = H * 0.5
        drawSea(c, hz)
        weatherBack(c, hz)
        let L = light()
        let night = L.night
        let dark = (1 - night * 0.5) * (1 - wxDark * 0.3)
        let seed = Double(leg * 7 + path[leg] * 3)
        let qy = quayY()
        let lampOn = night > 0.25 || wxDark > 0.5
        let warm = Col(0xffd257)

        // every port is laid out its own way: a hill town, a low sandbar village, a walled city, a cliff cove
        let lay = (leg * 2 + path[leg]) % 4
        let hf: Double = [1.0, 0.3, 0.85, 1.3][lay]
        // every port has its own character
        let kind = (leg * 2 + path[leg]) % 5
        let kindName = ["Fishing village", "Garrison town", "Trading city", "Smugglers' cove", "Mill island"][kind]
        if kind == 3 {
            // a volcano smoking behind the cove
            let vx = W * 0.84
            c.poly(Col(0x4a4048).shade(dark), [vx - 190, hz + 4, vx - 26, hz - 176, vx + 26, hz - 176, vx + 200, hz + 4])
            c.poly(Col(0x5a4c52).shade(dark), [vx - 26, hz - 176, vx + 26, hz - 176, vx + 60, hz - 110, vx + 6, hz - 136, vx - 30, hz - 100])
            c.glow(vx, hz - 178, 46, Col(0xff6a20, 0.5 + 0.25 * sin(T * 2.3)), Col(0xff6a20, 0))
            c.curve(vx - 6, hz - 172, vx - 22, hz - 120, vx - 40, hz - 70, 3, Col(0xff7a30, 0.75 + 0.2 * sin(T * 3)))
            for sm in 0..<9 {
                let ph = (T * 0.09 + Double(sm) / 9).truncatingRemainder(dividingBy: 1)
                c.circ(vx + ph * 90 + sin(T * 0.7 + Double(sm)) * 8, hz - 184 - ph * 120, 12 + ph * 34, Col(0x3a3438, 0.5 * (1 - ph)))
            }
        }
        // ---- hills behind the town
        let pt = leg * 2 + path[leg]
        let hillA = [Col(0x4d7f52), Col(0xb89a5a), Col(0x9a5a3a), Col(0x7a8a8a), Col(0x2f5a48)][pt % 5]
        let hillB = [Col(0x5f9450), Col(0xd0b06a), Col(0xb8704a), Col(0x98a8a4), Col(0x3a6e54)][pt % 5]
        c.pathFill(hillA.shade(dark * 0.9)) { p in
            p.move(to: CGPoint(x: W * 0.3, y: hz + 4))
            p.addQuadCurve(to: CGPoint(x: W * 0.56, y: hz - 122 * hf), control: CGPoint(x: W * 0.4, y: hz - 96 * hf))
            p.addQuadCurve(to: CGPoint(x: W * 0.8, y: hz - 92 * hf), control: CGPoint(x: W * 0.68, y: hz - 150 * hf))
            p.addQuadCurve(to: CGPoint(x: W + 10, y: hz - 118 * hf), control: CGPoint(x: W * 0.92, y: hz - 60 * hf))
            p.addLine(to: CGPoint(x: W + 10, y: hz + 4))
            p.closeSubpath()
        }
        c.pathFill(hillB.shade(dark)) { p in
            p.move(to: CGPoint(x: W * 0.36, y: hz + 4))
            p.addQuadCurve(to: CGPoint(x: W * 0.64, y: hz - 82 * hf), control: CGPoint(x: W * 0.48, y: hz - 76 * hf))
            p.addQuadCurve(to: CGPoint(x: W + 10, y: hz - 58 * hf), control: CGPoint(x: W * 0.84, y: hz - 96 * hf))
            p.addLine(to: CGPoint(x: W + 10, y: hz + 4))
            p.closeSubpath()
        }
        if lay == 0 || lay == 3 {
        // terraced fields and a winding road up the hill
        for i in 0..<5 { c.curve(W * (0.5 + Double(i) * 0.09), hz - 26 - Double(i % 2) * 14, W * (0.56 + Double(i) * 0.09), hz - 42 - Double(i % 2) * 14, W * (0.62 + Double(i) * 0.09), hz - 30 - Double(i % 2) * 14, 1.2, Col(0x3f7a3c).shade(dark)) }
        c.curve(W * 0.6, hz + 2, W * 0.7, hz - 40, W * 0.6, hz - 96, 2.5, Col(0xd9c48a).shade(dark * 0.9))

        }
        // ---- on the hilltop: a church with a bell, or a fort with a flag
        let tx = W * 0.58, ty = hz - 108 * hf
        if lay == 1 {
            // no hill to build on
        } else if lay != 2 && (leg + path[leg]) % 2 == 0 {
            c.R(tx - 16, ty - 14, 32, 22, Col(0xf3ead2).shade(dark))
            c.poly(Col(0xb8452c).shade(dark), [tx - 19, ty - 14, tx, ty - 28, tx + 19, ty - 14])
            c.R(tx + 10, ty - 44, 12, 52, Col(0xf3ead2).shade(dark))
            c.poly(Col(0xb8452c).shade(dark), [tx + 8, ty - 44, tx + 16, ty - 60, tx + 24, ty - 44])
            c.R(tx + 15.2, ty - 70, 1.6, 11, Col(0x3a2412)); c.R(tx + 12, ty - 66, 8, 1.6, Col(0x3a2412))
            // the bell swings when it rings
            let ring = sin(T * 9) * 2 * min(1, bellSwing)
            c.R(tx + 12.5, ty - 40, 7, 9, Col(0x1c1108))
            c.circ(tx + 16 + ring, ty - 35, 2.6, Col(0xd9a441).shade(dark))
            c.R(tx - 3, ty - 2, 6, 10, lampOn ? warm : Col(0x5a3a1c))
        } else {
            c.R(tx - 30, ty - 8, 60, 18, Col(0x9a9388).shade(dark))
            for i in 0..<7 { c.R(tx - 30 + Double(i) * 9, ty - 13, 5, 6, Col(0x9a9388).shade(dark)) }
            c.R(tx - 10, ty - 26, 20, 20, Col(0x8a8378).shade(dark))
            for i in 0..<3 { c.R(tx - 10 + Double(i) * 7.5, ty - 30, 5, 5, Col(0x8a8378).shade(dark)) }
            c.seg(tx, ty - 26, tx, ty - 52, 1.6, Col(0x3a2412))
            c.poly(REDC.shade(dark), [tx, ty - 52, tx + 18, ty - 47 + sin(T * 5) * 2, tx, ty - 42])
            for i in 0..<3 { c.R(tx - 24 + Double(i) * 20, ty - 2, 7, 3, Col(0x1c1108)) }
        }

        if kind == 4 || kind == 0 {
            // windmills turning on the ridge
            for wm in 0..<(kind == 4 ? 3 : 1) {
                let wx = W * (0.72 + Double(wm) * 0.08), wyy = hz - 96 * hf + Double(wm % 2) * 14
                c.poly(Col(0xf3ead2).shade(dark), [wx - 8, wyy + 26, wx - 5, wyy - 4, wx + 5, wyy - 4, wx + 8, wyy + 26])
                c.poly(Col(0x8a5a36).shade(dark), [wx - 7, wyy - 4, wx, wyy - 13, wx + 7, wyy - 4])
                c.save(); c.translate(wx, wyy - 5); c.rotate(T * (0.9 + rough) + Double(wm))
                for bl in 0..<4 {
                    c.rotate(PI / 2)
                    c.seg(0, 0, 0, -24, 1.4, Col(0x3a2412))
                    c.poly(Col(0xf7f0dc, 0.92).shade(dark), [1, -6, 7, -7, 7, -23, 1, -23])
                    _ = bl
                }
                c.restore()
            }
        }
        // ---- a lighthouse on the point, its beam sweeping at night
        let lhx = W - safeR - 30, lhy = hz - 62
        if lampOn {
            let a = T * 0.9
            c.save()
            c.translate(lhx, lhy - 52)
            c.rotate(sin(a) * 1.1 + PI)
            c.pathFill(Col(0xfff2c0, 0.13 + 0.05 * sin(T * 3))) { p in
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: W * 0.8, y: -46)); p.addLine(to: CGPoint(x: W * 0.8, y: 46)); p.closeSubpath()
            }
            c.restore()
        }
        c.poly(Col(0xf3ead2).shade(dark), [lhx - 9, lhy, lhx - 6, lhy - 46, lhx + 6, lhy - 46, lhx + 9, lhy])
        c.R(lhx - 7.5, lhy - 30, 15, 7, REDC.shade(dark)); c.R(lhx - 8.5, lhy - 12, 17, 7, REDC.shade(dark))
        c.R(lhx - 8, lhy - 50, 16, 4, Col(0x3a2412)); c.R(lhx - 5, lhy - 58, 10, 8, lampOn ? warm : Col(0xbfe3f5).shade(dark))
        c.poly(Col(0x3a2412), [lhx - 7, lhy - 58, lhx, lhy - 66, lhx + 7, lhy - 58])
        if lampOn { c.glow(lhx, lhy - 54, 40, Col(0xfff2c0, 0.7), Col(0xfff2c0, 0)) }

        if lay == 3 {
            // a cliff closes the cove on the seaward side, with a fall coming down it
            let cx = W * 0.8
            c.poly(Col(0x6a6258).shade(dark), [cx, hz + 4, cx + 30, hz - 120, cx + 70, hz - 184, W + 10, hz - 196, W + 10, hz + 4])
            c.poly(Col(0x7c7468).shade(dark), [cx + 30, hz - 120, cx + 70, hz - 184, cx + 96, hz - 150, cx + 60, hz - 60])
            c.poly(Col(0x3f7450).shade(dark), [cx + 64, hz - 186, W + 10, hz - 200, W + 10, hz - 186, cx + 80, hz - 176])
            let wxf = cx + 120
            c.R(wxf - 5, hz - 184, 10, 186, Col(0xdff2ff, 0.85))
            for j in 0..<8 { let ph = (T * 0.9 + Double(j) / 8).truncatingRemainder(dividingBy: 1); c.R(wxf - 4 + hashN(Double(j)) * 6, hz - 184 + ph * 180, 1.6, 12, Col(0xffffff, 0.9)) }
            for j in 0..<6 { let ph = (T * 1.2 + Double(j) / 6).truncatingRemainder(dividingBy: 1); c.circ(wxf + (hashN(Double(j) * 3) - 0.5) * 30, hz + 2 - ph * 12, 3 + ph * 6, Col(0xffffff, 0.6 * (1 - ph))) }
        }
        // ---- the town: a back row on the slope, then the big houses along the waterfront
        func house(_ hx: Double, _ base: Double, _ hw: Double, _ hh: Double, _ k: Int) {
            // each town builds in its own stone and tiles its own way
            let townWall = [Col(0xf3ead2), Col(0xe8c090), Col(0xffffff), Col(0xc8b8a0), Col(0xf0d0c8), Col(0xd0dce0)][pt % 6]
            let townRoof = [Col(0xb8452c), Col(0x7a5030), Col(0x3a6a9a), Col(0x4a4a52), Col(0x9a3a4a), Col(0x4a7a4a)][pt % 6]
            let wall = Col.mix([Col(0xf3ead2), Col(0xf0d8b0), Col(0xe8c8c0), Col(0xd8e4e8), Col(0xf6e6a8)][k % 5], lay == 1 ? Col(0xb08a52) : townWall, lay == 1 ? 0.85 : 0.6).shade(dark)
            let roof = Col.mix([Col(0xb8452c), Col(0x8a5a36), Col(0xa63a2a), Col(0x6b4a3a)][k % 4], lay == 1 ? Col(0xd8b860) : townRoof, lay == 1 ? 0.9 : 0.7).shade(dark)
            c.R(hx, base - hh, hw, hh, wall)
            c.R(hx + hw * 0.62, base - hh, hw * 0.38, hh, Col(0x000000, 0.1))
            c.poly(roof, [hx - 3, base - hh, hx + hw / 2, base - hh - hw * 0.34, hx + hw + 3, base - hh])
            // chimney and its smoke
            let chx = hx + hw * 0.72
            c.R(chx, base - hh - hw * 0.3, 4, hw * 0.2, roof.shade(0.8))
            if k % 2 == 0 {
                for sm in 0..<4 {
                    let ph = (T * 0.35 + Double(sm) * 0.25 + hashN(Double(k))).truncatingRemainder(dividingBy: 1)
                    c.circ(chx + 2 + ph * 14 + sin(T + Double(sm)) * 2, base - hh - hw * 0.3 - ph * 30, 2.5 + ph * 5, Col(0xe8e8e8, 0.3 * (1 - ph) * dark))
                }
            }
            // windows and a door
            let lit = lampOn && hashN(Double(k) * 3.3 + seed) > 0.25
            let cols = hw > 30 ? 3 : 2, rows = hh > 38 ? 2 : 1
            for r in 0..<rows {
                for q in 0..<cols {
                    let wx = hx + hw * (Double(q) + 0.5) / Double(cols) - 3
                    let wyy = base - hh + 7 + Double(r) * 15
                    c.R(wx - 1, wyy - 1, 8, 9, Col(0x3a2412).shade(dark))
                    c.R(wx, wyy, 6, 7, lit ? warm : Col(0x6f8fa8).shade(dark))
                    if !lit { c.R(wx - 2, wyy + 7, 10, 2, Col(0x8a3b2e).shade(dark)) }
                }
            }
            c.RR(hx + hw * 0.4, base - 11, 7, 11, 1.5, Col(0x5a3a1c).shade(dark))
            if lit { c.glow(hx + hw / 2, base - hh / 2, hw * 0.9, Col(0xffc060, 0.16), Col(0xffc060, 0)) }
        }
        let tiers = [1, 0, 2, 3][lay]
        for tr in stride(from: tiers - 1, through: 0, by: -1) {
            for i in 0..<8 {
                let td = Double(tr)
                let hx = W * (0.47 + td * 0.03) + Double(i) * W * 0.062 + hashN(seed + Double(i) + td * 7) * 8
                if lay == 3 && hx > W * 0.8 { continue }
                house(hx, hz - 26 - td * 30 - hashN(seed + Double(i) * 3.3 + td) * 22, 20 + hashN(seed + Double(i) * 1.7) * 8, 18 + hashN(seed + Double(i) * 5.1) * 8, i + 2 + tr * 3)
            }
        }
        if lay == 2 {
            // the city wall, towers and all, behind the waterfront
            let stone = Col(0xa8a090).shade(dark)
            c.R(W * 0.4, qy - 62, W, 62, stone)
            for i in 0..<40 { c.R(W * 0.4 + Double(i) * 14, qy - 68, 8, 7, stone) }
            for i in 0..<10 { c.R(W * 0.4, qy - 52 + Double(i) * 6, W, 0.7, Col(0x000000, 0.12)) }
            for tw in 0..<3 {
                let twx = W * (0.46 + Double(tw) * 0.2)
                c.R(twx, qy - 96, 34, 96, Col(0x98907e).shade(dark)); for i in 0..<4 { c.R(twx - 2 + Double(i) * 10, qy - 103, 7, 8, Col(0x98907e).shade(dark)) }
                c.R(twx + 14, qy - 78, 6, 12, lampOn ? warm : Col(0x2a2622))
                c.seg(twx + 17, qy - 103, twx + 17, qy - 126, 1.4, Col(0x3a2412)); c.poly(REDC.shade(dark), [twx + 17, qy - 126, twx + 33, qy - 121 + sin(T * 5 + Double(tw)) * 2, twx + 17, qy - 116])
            }
        }
        // palms between the rows
        let palmN = [5, 10, 2, 4][lay]
        for i in 0..<palmN {
            let px = W * 0.44 + Double(i) * W * 0.6 / Double(palmN) + hashN(seed + Double(i) * 9) * 18
            let sw = sin(T * 1.2 + Double(i)) * 2 * (1 + rough * 2)
            c.curve(px, hz - 4, px + 3 + sw * 0.5, hz - 22, px + 5 + sw, hz - 40, 2.6, Col(0x6b4a26).shade(dark))
            for a in [-2.5, -1.8, -1.0, -0.3, 0.4] { c.curve(px + 5 + sw, hz - 40, px + 5 + sw + cos(a) * 11, hz - 44 + sin(a) * 10, px + 5 + sw + cos(a) * 20, hz - 37 + sin(a) * 14, 2.8, Col(0x3f7a3c).shade(dark)) }
        }
        var fx = W * 0.4
        var k = 0
        while fx < W + 20 {
            let hw = 30 + hashN(seed + Double(k) * 2.9) * 16, hh = (30 + hashN(seed + Double(k) * 6.1) * 24) * [1.0, 0.6, 1.4, 0.9][lay]
            house(fx, qy - 2, hw, hh, k + Int(seed))
            // a shop sign or a line of washing between some of them
            if k % 3 == 1 {
                c.seg(fx + hw, qy - hh * 0.7, fx + hw + 16, qy - hh * 0.6, 0.8, Col(0x1c1108))
                for wsh in 0..<3 { c.R(fx + hw + 2 + Double(wsh) * 5, qy - hh * 0.7 + Double(wsh) * 1.2, 4, 6 + sin(T * 3 + Double(wsh)) * 1, [Col(0xffffff), Col(0xc0392b), Col(0x4a8fd0)][wsh].shade(dark)) }
            }
            fx += hw + 6 + hashN(seed + Double(k) * 4.2) * 14
            k += 1
        }

        // ---- the quay: stone wall, steps, bollards, lamps, stalls, stacked cargo, a crane
        let qx0 = W * 0.38
        c.R(qx0, qy - 2, W - qx0 + 10, 5, Col(0xd8ccb0).shade(dark))
        c.vfill(qx0, qy + 3, W - qx0 + 10, 22, [(0, Col(0x8a8378).shade(dark)), (1, Col(0x4a463e).shade(dark))])
        for i in 0..<40 { c.R(qx0 + Double(i) * 16 + (i % 2 == 0 ? 0 : 8), qy + 3 + Double(i % 3) * 7, 1, 7, Col(0x2a2622, 0.5)) }
        for i in 0..<3 { c.R(qx0, qy + 9 + Double(i) * 7, W - qx0 + 10, 0.8, Col(0x2a2622, 0.45)) }
        c.R(qx0, qy + 24, W - qx0 + 10, 3, Col(0x1f3a2c, 0.8))
        // a wooden pier running out toward your ship
        let pierY = qy + 8
        c.R(W * 0.3, pierY, W * 0.1, 4, Col(0x8a6a44).shade(dark))
        for i in 0..<5 { c.R(W * 0.3 + Double(i) * W * 0.024, pierY, 3, 20, Col(0x5a3d20).shade(dark)) }
        for i in 0..<7 {
            let bx = qx0 + 30 + Double(i) * (W - qx0 - 40) / 6
            c.RR(bx - 3, qy - 8, 6, 8, 2, Col(0x23232a)); c.R(bx - 4, qy - 9, 8, 2.5, Col(0x33333a))
        }
        // street lamps
        for i in 0..<5 {
            let lx = qx0 + 60 + Double(i) * (W - qx0 - 70) / 4.4
            c.R(lx - 1, qy - 30, 2, 28, Col(0x1c1108))
            c.RR(lx - 4, qy - 38, 8, 9, 2, lampOn ? warm : Col(0x8a8a80).shade(dark)); c.R(lx - 5, qy - 40, 10, 2.5, Col(0x1c1108))
            if lampOn { c.glow(lx, qy - 33, 46, Col(0xffc060, 0.5), Col(0xffc060, 0)); c.ell(lx, qy, 22, 4, Col(0xffc060, 0.2)) }
        }
        // market stalls with striped awnings
        let stallN = [3, 1, 4, 2][lay]
        for i in 0..<stallN {
            let sx = W * (0.5 + Double(i) * 0.42 / Double(max(1, stallN))) + hashN(seed + Double(i) * 12) * 20
            let ac = [Col(0xc0392b), Col(0x2f7fd0), Col(0x3f9a4c)][(i + Int(seed)) % 3].shade(dark)
            c.R(sx - 15, qy - 20, 2, 18, Col(0x5a3d20).shade(dark)); c.R(sx + 13, qy - 20, 2, 18, Col(0x5a3d20).shade(dark))
            c.R(sx - 16, qy - 9, 32, 7, Col(0x8a6a44).shade(dark))
            let flap = sin(T * 2.2 + Double(i)) * 1.2
            for stp in 0..<6 {
                let x0 = sx - 19 + Double(stp) * 6.4
                c.poly(stp % 2 == 0 ? ac : Col(0xf7f0dc).shade(dark), [x0, qy - 24, x0 + 6.4, qy - 24, x0 + 6.4, qy - 16 + flap, x0, qy - 16 + flap])
            }
            for fr in 0..<4 { c.circ(sx - 10 + Double(fr) * 6.5, qy - 11, 2.3, [Col(0xff9a3a), Col(0xd8432f), Col(0xffd257), Col(0x7fc86a)][fr].shade(dark)) }
        }
        // crates and barrels
        for i in 0..<4 {
            let cx = qx0 + 16 + Double(i) * (W - qx0) * 0.26 + hashN(seed + Double(i) * 21) * 26
            c.RR(cx, qy - 12, 12, 10, 1.5, Col(0xa8823f).shade(dark)); c.RRStroke(cx, qy - 12, 12, 10, 1.5, 1, Col(0x5a3d20).shade(dark))
            c.RR(cx + 9, qy - 21, 11, 9, 1.5, Col(0xb8924f).shade(dark)); c.RRStroke(cx + 9, qy - 21, 11, 9, 1.5, 1, Col(0x5a3d20).shade(dark))
            c.ell(cx + 28, qy - 7, 5, 7, Col(0x6b4423).shade(dark)); c.R(cx + 23, qy - 9, 10, 1.2, Col(0x1c1108)); c.R(cx + 23, qy - 5, 10, 1.2, Col(0x1c1108))
        }
        // the harbour crane, swinging a load out over the water
        let crx = qx0 + 26
        let swing = sin(T * 0.7)
        c.R(crx - 3, qy - 54, 6, 52, Col(0x3a2412).shade(dark))
        c.seg(crx, qy - 52, crx - 44 - swing * 8, qy - 70, 4, Col(0x4a2f18).shade(dark))
        c.seg(crx, qy - 30, crx - 22, qy - 61, 2, Col(0x4a2f18).shade(dark))
        let hookX = crx - 44 - swing * 8, drop = 22 + (0.5 + 0.5 * sin(T * 0.7 + 1.3)) * 26
        c.seg(hookX, qy - 70, hookX, qy - 70 + drop, 1, Col(0x1c1108))
        c.RR(hookX - 7, qy - 70 + drop, 14, 11, 1.5, Col(0xa8823f).shade(dark)); c.RRStroke(hookX - 7, qy - 70 + drop, 14, 11, 1.5, 1, Col(0x5a3d20).shade(dark))

        // ---- people: the quay is never still
        let coats = [Col(0x2f5f8f), Col(0x8c3b2e), Col(0xd9cdb0), Col(0x3a7a6d), Col(0x6a4a8a), Col(0xb8862a), Col(0x4a4a52)]
        let crowd = festT > 0 ? 20 : 13
        for i in 0..<crowd {
            let sp = 9 + hashN(seed + Double(i) * 3.1) * 16
            let dirR = i % 2 == 0
            let span = W - qx0 - 20
            var px = (hashN(seed + Double(i) * 7.7) * span + T * sp * (dirR ? 1 : -1)).truncatingRemainder(dividingBy: span)
            if px < 0 { px += span }
            townie(c, qx0 + 10 + px, qy - 1 - hashN(Double(i) * 5.5) * 2, 1.0 + hashN(Double(i) * 2.2) * 0.25, coats[i % coats.count], dirR ? 1 : -1, Double(i) * 1.7, carry: i % 4 == 0 ? 1 : (i % 5 == 0 ? 2 : 0), dark: dark)
        }
        // dancers under the lamps on a festival night
        if festT > 0 {
            for i in 0..<5 {
                let dx = W * 0.62 + Double(i) * 16, hop = abs(sin(T * 6 + Double(i))) * 5
                townie(c, dx, qy - 1 - hop, 1.15, coats[(i + 3) % coats.count], i % 2 == 0 ? 1 : -1, Double(i) * 2.3, carry: 0, dark: 1)
            }
            // bunting across the quay
            for i in 0..<22 {
                let bxx = qx0 + 20 + Double(i) * (W - qx0 - 40) / 21
                let sag = sin(Double(i) / 21 * PI) * 10
                c.poly([Col(0xff5a5a), Col(0xffd257), Col(0x7fd8ff), Col(0x9ff0aa)][i % 4], [bxx - 4, qy - 52 + sag, bxx + 4, qy - 52 + sag, bxx, qy - 44 + sag + sin(T * 5 + Double(i)) * 1.5])
            }
        }
        // a dog that chases along the quay and back
        let dgx = qx0 + 60 + (0.5 + 0.5 * sin(T * 0.45)) * (W - qx0 - 140)
        let dgd = cos(T * 0.45) > 0 ? 1.0 : -1.0
        c.ell(dgx, qy - 5, 6, 3.2, Col(0x8a5a2c).shade(dark)); c.circ(dgx + dgd * 6, qy - 7.5, 2.8, Col(0x8a5a2c).shade(dark))
        c.seg(dgx - dgd * 5, qy - 6, dgx - dgd * 9, qy - 11 + sin(T * 14) * 2, 1.4, Col(0x8a5a2c).shade(dark))
        c.seg(dgx - 3, qy - 3, dgx - 3 + sin(T * 16) * 2, qy, 1.3, Col(0x6b4423).shade(dark)); c.seg(dgx + 3, qy - 3, dgx + 3 - sin(T * 16) * 2, qy, 1.3, Col(0x6b4423).shade(dark))

        // a horse and cart making deliveries along the front
        let cartSpan = W - qx0 + 120
        let cartX = qx0 - 60 + (T * 22).truncatingRemainder(dividingBy: cartSpan)
        c.RR(cartX - 16, qy - 14, 26, 9, 2, Col(0x8a6238).shade(dark)); c.R(cartX - 14, qy - 21, 9, 7, Col(0xa8823f).shade(dark)); c.R(cartX - 4, qy - 19, 8, 5, Col(0x6b4423).shade(dark))
        c.circ(cartX - 9, qy - 4, 4.5, Col(0x2a1a0c)); c.circ(cartX + 4, qy - 4, 4.5, Col(0x2a1a0c)); c.circ(cartX - 9, qy - 4, 1.5, Col(0x8a6238)); c.circ(cartX + 4, qy - 4, 1.5, Col(0x8a6238))
        c.ell(cartX + 24, qy - 11, 9, 5, Col(0x6b4a2c).shade(dark)); c.seg(cartX + 31, qy - 13, cartX + 36, qy - 20, 4, Col(0x6b4a2c).shade(dark)); c.ell(cartX + 38, qy - 21, 4.5, 2.6, Col(0x6b4a2c).shade(dark))
        for lg in 0..<4 { c.seg(cartX + 18 + Double(lg) * 4, qy - 8, cartX + 18 + Double(lg) * 4 + sin(T * 9 + Double(lg) * 1.6) * 2.5, qy, 1.5, Col(0x4a3018).shade(dark)) }
        c.seg(cartX + 10, qy - 10, cartX + 17, qy - 11, 1, Col(0x1c1108))
        // a street performer: juggling by day, breathing fire after dark
        let jx = W * 0.57
        townie(c, jx, qy - 1, 1.3, Col(0xb03a8a), 1, 0.4, carry: 0, dark: dark)
        if lampOn {
            let ph = (T * 0.45).truncatingRemainder(dividingBy: 1)
            if ph < 0.4 {
                let k2 = ph / 0.4
                c.glow(jx + 16 + k2 * 14, qy - 30 - k2 * 6, 22 + k2 * 16, Col(0xffa030, 0.8 * (1 - k2)), Col(0xffa030, 0))
                c.poly(Col(0xffd257, 0.9 * (1 - k2)), [jx + 5, qy - 26, jx + 30 + k2 * 14, qy - 40 - k2 * 6, jx + 30 + k2 * 14, qy - 22])
            }
        } else {
            for bl in 0..<3 {
                let ph = (T * 1.2 + Double(bl) / 3).truncatingRemainder(dividingBy: 1)
                c.circ(jx - 7 + ph * 14, qy - 30 - sin(ph * PI) * 22, 2.4, [Col(0xff5a5a), Col(0xffd257), Col(0x7fd8ff)][bl])
            }
        }
        if kind == 1 {
            // the garrison drilling: a file of redcoats behind a drum and colours
            let mx0 = qx0 + 40 + (T * 14).truncatingRemainder(dividingBy: W - qx0 - 60)
            for i in 0..<6 {
                let sx2 = mx0 - Double(i) * 11
                if sx2 < qx0 + 6 { continue }
                townie(c, sx2, qy - 1, 1.15, i == 0 ? Col(0x2f5f8f) : Col(0xc0392b), 1, 1.0, carry: 0, dark: dark)
                if i > 0 { c.seg(sx2 + 3, qy - 14, sx2 + 5, qy - 30, 1.2, Col(0x3a2412)) }
            }
            c.seg(mx0 + 2, qy - 14, mx0 + 2, qy - 40, 1.4, Col(0x3a2412)); c.poly(REDC.shade(dark), [mx0 + 2, qy - 40, mx0 + 18, qy - 36 + sin(T * 6) * 2, mx0 + 2, qy - 31])
        }
        if kind == 0 {
            // nets drying, and a catch being hauled up the wall
            for i in 0..<3 {
                let nx = W * (0.74 + Double(i) * 0.06)
                c.seg(nx, qy, nx, qy - 22, 1.5, Col(0x5a3d20).shade(dark))
                if i > 0 { c.curve(nx - W * 0.06, qy - 22, nx - W * 0.03, qy - 8, nx, qy - 22, 1, Col(0xc9b88a).shade(dark)); for m in 0..<5 { c.seg(nx - W * 0.06 + Double(m) * W * 0.012, qy - 21, nx - W * 0.06 + Double(m) * W * 0.012 + 3, qy - 12, 0.5, Col(0xc9b88a, 0.8)) } }
            }
            let hx2 = qx0 + 70, lift = (0.5 + 0.5 * sin(T * 1.1)) * 14
            c.seg(hx2, qy - 4, hx2, qy + 30 - lift, 0.9, Col(0xc9b88a))
            c.arcFill(hx2, qy + 30 - lift, 9, 0, PI, Col(0xc9b88a, 0.7).shade(dark))
            for f in 0..<3 { c.ell(hx2 - 5 + Double(f) * 5, qy + 32 - lift + sin(T * 12 + Double(f)) * 1.5, 3.5, 1.5, Col(0xcfe0ea)) }
        }
        // chatter
        let lines = ["Fresh fish!", "Mind the cart!", "Welcome, captain!", "Rope! Good rope!", "Oranges, two a penny!", "That's her, the new ship", "Storm coming, I reckon", "Pirates off the cape again", "Lovely day for it", "Out of the way!", "Any work going?", "She's a fine vessel", "Hot pies!", "Who'll buy my eels?", "Watch your purse", "The tide's on the turn", "Three cheers for the captain!", "Is that a parrot?", "Careful with that crate!", "Sing us a shanty!"]
        if sum == nil && play == nil && chatT > 0.5 {
            let i = chatWho
            let sp = 9 + hashN(seed + Double(i) * 3.1) * 16
            let span = W - qx0 - 20
            var px = (hashN(seed + Double(i) * 7.7) * span + T * sp * (i % 2 == 0 ? 1 : -1)).truncatingRemainder(dividingBy: span)
            if px < 0 { px += span }
            let bxx = clampD(qx0 + 10 + px, qx0 + 60, W - safeR - 70)
            let tw = textW(lines[chatLine], 12, FONT) + 16
            let a = min(1, chatT * 2) 
            c.save()
            c.alpha(a)
            c.RR(bxx - tw / 2, qy - 50, tw, 19, 8, Col(0xfbf3dc)); c.RRStroke(bxx - tw / 2, qy - 50, tw, 19, 8, 1, Col(0x6b4a26))
            c.poly(Col(0xfbf3dc), [bxx - 4, qy - 32, bxx + 4, qy - 32, bxx, qy - 26])
            c.text(lines[chatLine], bxx, qy - 36.5, 12, Col(0x2a1706), 0, FONT)
            c.restore()
        }

        // ---- the bay: fishing boats working, a rowing boat ferrying to your ship
        if kind == 2 {
            // merchantmen lying at anchor off the trading city
            drawShip(c, W * 0.62, qy + 66, 66, 3, furled: true)
            drawShip(c, W * 0.88, qy + 58, 54, 2, furled: true)
        }
        for i in 0..<3 {
            let bx = W * (0.55 + Double(i) * 0.15) + sin(T * 0.12 + Double(i) * 2) * W * 0.05
            let by = qy + 44 + Double(i) * 16 + sin(T * 1.4 + Double(i)) * 1.5
            let sc = 0.8 + Double(i) * 0.2
            c.ell(bx, by + 4 * sc, 20 * sc, 3 * sc, Col(0x000000, 0.18))
            c.poly(Col(0x7a4a26).shade(dark), [bx - 18 * sc, by - 4 * sc, bx + 20 * sc, by - 4 * sc, bx + 14 * sc, by + 3 * sc, bx - 14 * sc, by + 3 * sc])
            c.R(bx - 18 * sc, by - 5 * sc, 38 * sc, 1.6 * sc, Col(0xd9a441).shade(dark))
            c.seg(bx - 2 * sc, by - 4 * sc, bx - 2 * sc, by - 32 * sc, 1.6 * sc, Col(0x3b2412).shade(dark))
            let sailC = [Col(0xf3ead2), Col(0xc0513a), Col(0xe8d6a0)][i].shade(dark)
            c.poly(sailC, [bx - 1 * sc, by - 31 * sc, bx + 15 * sc + sin(T * 1.7 + Double(i)) * 2, by - 9 * sc, bx - 1 * sc, by - 7 * sc])
            c.circ(bx - 9 * sc, by - 8 * sc, 2.4 * sc, Col(0xe3b58a).shade(dark)); c.R(bx - 11 * sc, by - 6 * sc, 4 * sc, 4 * sc, Col(0x2f5f8f).shade(dark))
            if lampOn { c.circ(bx + 12 * sc, by - 9 * sc, 2, warm); c.glow(bx + 12 * sc, by - 9 * sc, 20, Col(0xffc060, 0.5), Col(0xffc060, 0)) }
        }
        // ---- wildlife: a pelican on a pile, crabs on the wall, fish jumping, a turtle, dolphins playing in the bay
        let pelX = W * 0.3 + 3, pelY = qy + 8
        c.ell(pelX, pelY - 8, 6, 5, Col(0xf3f0e6).shade(dark)); c.circ(pelX + 4, pelY - 15, 3.2, Col(0xf3f0e6).shade(dark))
        c.poly(Col(0xe8a83a).shade(dark), [pelX + 6, pelY - 16, pelX + 17, pelY - 12 + sin(T * 0.8) * 1.5, pelX + 6, pelY - 12]); c.circ(pelX + 5, pelY - 16, 0.8, Col(0x000000))
        c.seg(pelX - 1, pelY - 3, pelX - 1, pelY, 1, Col(0xe8a83a)); c.seg(pelX + 2, pelY - 3, pelX + 2, pelY, 1, Col(0xe8a83a))
        for i in 0..<3 {
            let crx2 = qx0 + 40 + Double(i) * W * 0.17 + sin(T * 0.9 + Double(i) * 2.2) * 22, cry = qy + 12 + Double(i % 2) * 6
            c.ell(crx2, cry, 4.5, 3, Col(0xd8432f).shade(dark))
            for lg in 0..<3 { c.seg(crx2 - 4, cry + Double(lg) - 1, crx2 - 7 - sin(T * 14 + Double(lg + i)) * 1.5, cry + Double(lg) * 1.5, 0.8, Col(0xd8432f).shade(dark)); c.seg(crx2 + 4, cry + Double(lg) - 1, crx2 + 7 + sin(T * 14 + Double(lg + i)) * 1.5, cry + Double(lg) * 1.5, 0.8, Col(0xd8432f).shade(dark)) }
            c.circ(crx2 - 6, cry - 4, 1.6, Col(0xd8432f).shade(dark)); c.circ(crx2 + 6, cry - 4, 1.6, Col(0xd8432f).shade(dark))
        }
        for i in 0..<4 {
            let ph = (T * 0.33 + hashN(Double(i) * 2.7)).truncatingRemainder(dividingBy: 1)
            let cyc = floor(T * 0.33 + hashN(Double(i) * 2.7))
            let jx2 = W * 0.36 + hashN(Double(i) * 5.1 + cyc) * W * 0.6, jy2 = qy + 46 + hashN(Double(i) * 9.3 + cyc) * 50
            if ph < 0.3 {
                let k3 = ph / 0.3
                c.save(); c.translate(jx2 + k3 * 16, jy2 - sin(k3 * PI) * 18); c.rotate(-0.8 + k3 * 1.6)
                c.ell(0, 0, 6, 2.2, Col(0xcfe0ea).shade(dark)); c.poly(Col(0xcfe0ea).shade(dark), [-5, 0, -9, -3, -9, 3])
                c.restore()
            }
            if ph < 0.6 { c.ellStroke(jx2 + (ph < 0.3 ? 0 : 16), jy2, 3 + ph * 22, 1 + ph * 5, 1, Col(0xffffff, 0.5 * (1 - ph / 0.6))) }
        }
        let tux = W * 0.48 + sin(T * 0.13) * W * 0.1, tuy = qy + 92 + sin(T * 0.9) * 2
        c.ell(tux, tuy, 9, 5, Col(0x3f6a3c, 0.85)); c.circ(tux + 10 * (cos(T * 0.13) > 0 ? 1 : -1), tuy - 1, 3, Col(0x5a8a4a, 0.85))
        c.ell(tux - 6, tuy + 4 + sin(T * 3) * 1.5, 4, 1.6, Col(0x5a8a4a, 0.7)); c.ell(tux + 6, tuy + 4 - sin(T * 3) * 1.5, 4, 1.6, Col(0x5a8a4a, 0.7))
        if Int(T / 17) % 2 == 0 {
            for i in 0..<2 {
                let ph = (T * 0.5 + Double(i) * 0.4).truncatingRemainder(dividingBy: 1)
                let dx = W * 0.8 + Double(i) * 30 - ph * 30, dbase = qy + 104
                if ph < 0.55 {
                    let k4 = ph / 0.55
                    c.save(); c.translate(dx, dbase - sin(k4 * PI) * 26); c.rotate(2.2 - k4 * 1.8 + PI)
                    c.ell(0, 0, 12, 4, Col(0x5a7a94).shade(dark)); c.poly(Col(0x4a6a84).shade(dark), [-2, -3.5, 3, -9, 4, -3.5]); c.poly(Col(0x4a6a84).shade(dark), [-11, 0, -17, -4, -17, 4])
                    c.restore()
                }
            }
        }
        // the swell slapping the quay wall
        for i in 0..<16 {
            let fx2 = qx0 + Double(i) * (W - qx0) / 15
            let up2 = max(0, sin(T * 1.6 + Double(i) * 0.9))
            c.ell(fx2, qy + 25 - up2 * 3, 14, 1.5 + up2 * 2.5, Col(0xffffff, 0.25 + 0.3 * up2))
        }
        let wy = hz + (H - hz) * 0.4
        let shipX = W * 0.2
        let ferry = (T * 0.06).truncatingRemainder(dividingBy: 1)
        let tri = ferry < 0.5 ? ferry * 2 : 2 - ferry * 2
        let rbx = shipX + min(W * 0.28, 250) * ship.len * 0.45 + tri * (W * 0.3 - shipX - 60), rby = wy - 4 + sin(T * 2) * 1.5
        c.poly(Col(0x5a3d20).shade(dark), [rbx - 13, rby - 3, rbx + 13, rby - 3, rbx + 9, rby + 3, rbx - 9, rby + 3])
        c.circ(rbx - 3, rby - 7, 2.6, Col(0xe3b58a).shade(dark)); c.circ(rbx + 4, rby - 7, 2.6, Col(0xe3b58a).shade(dark))
        let oar = sin(T * 4) * 7
        c.seg(rbx, rby - 3, rbx - 12 + oar, rby + 7, 1.3, Col(0xc9a86a).shade(dark)); c.seg(rbx, rby - 3, rbx + 12 + oar, rby + 7, 1.3, Col(0xc9a86a).shade(dark))

        drawShip(c, shipX, wy, min(W * 0.28, 250) * ship.len, ship.masts, furled: true)
        foreWave(c, wy + 5, 0, W)

        // ---- gulls wheeling over the harbour
        if night < 0.5 && weather < 3 {
            for i in 0..<6 {
                let gx = W * 0.5 + cos(T * (0.3 + Double(i) * 0.05) + Double(i) * 1.9) * W * (0.22 + Double(i) * 0.03)
                let gy = hz * 0.45 + sin(T * (0.42 + Double(i) * 0.04) + Double(i)) * hz * 0.3
                let fl = sin(T * 7 + Double(i) * 2) * 4
                c.curve(gx - 8, gy + fl, gx - 4, gy - 3, gx, gy, 1.5, Col(0xffffff, 0.95))
                c.curve(gx, gy, gx + 4, gy - 3, gx + 8, gy + fl, 1.5, Col(0xffffff, 0.95))
            }
        }
        weatherFront(c, hz)
        if night > 0.05 { c.R(0, 0, W, H, Col(0x04081a, 0.22 * night)) }

        if play != nil {
            drawPlay(c)
            return
        }
        // the town's name on a hanging board
        let nm = here.n
        let sub = kindName + (lacksText().isEmpty ? "" : "  ·  " + lacksText()) + (wellDry() ? "  ·  no well" : "")
        let nw = max(textW(nm, 24, FONTD) + 44, textW(sub, 12, FONTI) + 30)
        let sway = sin(T * 1.3) * 0.02
        c.save()
        c.translate(W / 2, 38)
        c.rotate(sway)
        c.seg(-nw / 2 + 14, -6, -nw / 2 + 14, 8, 1.5, Col(0x1c1108)); c.seg(nw / 2 - 14, -6, nw / 2 - 14, 8, 1.5, Col(0x1c1108))
        c.RR(-nw / 2 + 2, 11, nw, 46, 7, Col(0x000000, 0.3))
        c.RRGrad(-nw / 2, 8, nw, 46, 7, [(0, Col(0x6b4423)), (1, Col(0x3f2613))])
        c.RRStroke(-nw / 2, 8, nw, 46, 7, 1.6, Col(0xd2a455))
        c.text(nm, 0, 32, 24, GOLD, 0, FONTD)
        c.text(sub, 0, 47, 12, CREAM.alpha(0.9), 0, FONTI)
        c.restore()

        // things going on in town: a call-out over the quay for each
        if sum == nil && card == nil {
            let jobs: [(String, String)] = [("", ""), ("Dock work", "load cargo for pay"), ("Stop, thief!", "a cutpurse on the quay"), ("Rats!", "save your stores"), ("Festival", "join the town tonight"), ("An old sailor", "has something for you"), ("Fire!", "the town is burning"), ("Pirate raid!", "defend the quay"), ("Tournament", "blunted blades, a purse"), ("Strongman", "ring the bell, win a prize"), ("Cargo", "carry it to the next port"), ("Passenger", "wants passage"), ("Bounty", "the governor's notice")]
            let open = portJobs.filter { !jobsDone.contains($0) }
            let jw = min(176.0, (W - qx0 - safeR - 16) / 3 - 8)
            for (n, j) in open.enumerated() {
                let jb = jobs[min(12, j)]
                let jx = qx0 + 14 + Double(n) * (jw + 8), jy = qy - 120 + sin(T * 3 + Double(n) * 1.4) * 3
                let urgent = j == 6 || j == 7 || j == 2 || j == 3
                c.glow(jx + jw / 2, jy + 22, 110, (urgent ? Col(0xff5a3c, 0.22 + 0.12 * sin(T * 6)) : Col(0xffd257, 0.16 + 0.08 * sin(T * 4))), Col(0xffd257, 0))
                c.poly(urgent ? Col(0xd0452c) : Col(0xe6ae3c), [jx + jw / 2 - 8, jy + 41, jx + jw / 2 + 8, jy + 41, jx + jw / 2, jy + 52])
                btn(c, jx, jy, jw, 42, "!  " + jb.0, jb.1, gold: true, size: 15) { [unowned self] in self.runJob(j) }
                if urgent { c.RRStroke(jx, jy, jw, 42, 10, 2.5, Col(0xff5a3c, 0.55 + 0.45 * sin(T * 6))) }
            }
        }

        // ---- the harbour master's reckoning: what she needs before the next passage
        let need = portNeeds()
        let gap = 8.0
        let bw = (W - safeL - safeR - gap * 4) / 5
        let bh = 54.0
        let by = H - safeB - bh - 6
        let sy = by - 32
        c.RR(safeL, sy, W - safeL - safeR, 26, 13, Col(0x1c1108, 0.86))
        c.RRStroke(safeL, sy, W - safeL - safeR, 26, 13, 1.2, Col(0xd2a455, 0.85))
        var chx = safeL + 12
        c.text("Next passage \(need.days) days:", chx, sy + 17.5, 12.5, CREAM.alpha(0.85), -1, FONTI)
        chx += textW("Next passage \(need.days) days:", 12.5, FONTI) + 10
        let chips: [(String, String, Bool)] = [
            ("food", "food \(need.foodDays)d", need.foodOK),
            ("water", "water \(need.waterDays)d", need.waterOK),
            ("hull", "hull \(need.hullPct)%", need.hullOK),
            ("crew", need.down > 0 ? "\(need.down) laid up" : "\(crew)/\(ship.crew) hands", need.crewOK),
            ("gold", "wages \(wagesDue())", need.wagesOK)
        ]
        for ch in chips {
            let tw = textW(ch.1, 12.5, FONTB)
            if chx + tw + 44 > W - safeR - 8 { break }
            let pulse = ch.2 ? 0.0 : 0.5 + 0.5 * sin(T * 6)
            if !ch.2 { c.RR(chx - 4, sy + 3, tw + 44, 20, 10, Col(0xc0392b, 0.35 + 0.3 * pulse)) }
            icon(c, ch.0, chx + 8, sy + 13 + (ch.2 ? 0 : sin(T * 8) * 1.5), 16)
            c.text(ch.1, chx + 20, sy + 17.5, 12.5, ch.2 ? CREAM : Col(0xffc8b8), -1, FONTB)
            // a tick, or a cross that throbs
            let mx2 = chx + tw + 30
            if ch.2 {
                c.roundCaps(true); c.seg(mx2 - 4, sy + 13, mx2 - 1, sy + 17, 2.2, GREENC); c.seg(mx2 - 1, sy + 17, mx2 + 5, sy + 9, 2.2, GREENC); c.roundCaps(false)
            } else {
                let r = 3.6 + pulse * 1.2
                c.seg(mx2 - r, sy + 13 - r, mx2 + r, sy + 13 + r, 2.4, Col(0xff6a50)); c.seg(mx2 + r, sy + 13 - r, mx2 - r, sy + 13 + r, 2.4, Col(0xff6a50))
            }
            chx += tw + 46
        }

        // ---- where to go: each door shows what is waiting behind it
        let ready = need.foodOK && need.waterOK && need.hullOK && need.wagesOK
        let tiles: [(String, String, Int)] = [
            ("Market", !need.foodOK && !need.waterOK ? "buy food and water" : (!need.foodOK ? "you need food" : (!need.waterOK ? "you need water" : (lacksText().isEmpty ? "stores are good" : lacksText()))), need.foodOK && need.waterOK ? 0 : 1),
            ("Tavern", need.down > 0 ? "\(need.down) need the surgeon" : (crew < ship.crew ? "\(ship.crew - crew) berths empty" : "crew · maps"), need.down > 0 ? 1 : (crew < ship.crew ? 2 : 0)),
            ("Shipwright", !need.hullOK ? "repairs: \(need.repair) gold" : (need.canUpgrade ? "upgrade available" : "she is sound"), !need.hullOK ? 1 : (need.canUpgrade ? 2 : 0)),
            ("Well", wellDry() ? "brackish · no use" : (wellUsed ? "casks filled" : "free fresh water"), wellUsed || wellDry() ? 0 : 2),
            ("Set sail", ready ? "ready for sea" : "not ready yet", ready ? 0 : 1)
        ]
        for (i, tl) in tiles.enumerated() {
            let x = safeL + Double(i) * (bw + gap)
            btn(c, x, by, bw, bh, "", "", gold: i == 4 && ready, off: i == 3 && (wellUsed || wellDry())) { [unowned self] in
                switch i {
                case 0: self.openMarket()
                case 1: self.tavern()
                case 2: self.shipwright()
                case 3: self.well()
                default: self.setSail()
                }
            }
            let dim = i == 3 && (wellUsed || wellDry())
            let ink = i == 4 && ready ? Col(0x2a1706) : CREAM
            // the moving sign on each door
            let ix = x + 24, iy = by + bh / 2
            c.save()
            if dim { c.alpha(0.45) }
            switch i {
            case 0:
                // a basket, the fruit jostling
                c.arcFill(ix, iy + 1, 11, 0, PI, Col(0x8a6a44)); c.arcStroke(ix, iy + 1, 11, PI, PI * 2, 1.6, Col(0x6b4a26))
                for f in 0..<3 { c.circ(ix - 6 + Double(f) * 6, iy - 2 + sin(T * 4 + Double(f) * 2) * 1.5, 3.4, [Col(0xff9a3a), Col(0xd8432f), Col(0x7fc86a)][f]) }
            case 1:
                // a mug, the foam rising and a drop running down
                c.RR(ix - 8, iy - 8, 14, 17, 2.5, Col(0x8a6a44)); c.arcStroke(ix + 7, iy, 5, -PI / 2, PI / 2, 2, Col(0x8a6a44))
                c.RR(ix - 9, iy - 11 - abs(sin(T * 2.4)) * 2, 16, 6, 3, Col(0xf7f0dc))
                c.circ(ix - 4, iy - 2 + (T * 8).truncatingRemainder(dividingBy: 12), 1.3, Col(0xf7f0dc, 0.8))
            case 2:
                // a hammer coming down, sparks when it lands
                let sw = sin(T * 5)
                c.save(); c.translate(ix + 6, iy + 8); c.rotate(-0.9 + max(0, sw) * 0.9)
                c.seg(0, 0, 0, -17, 2.6, Col(0x8a6238)); c.RR(-7, -22, 14, 7, 1.5, Col(0x9aa0a8))
                c.restore()
                if sw < -0.85 { for sp in 0..<4 { c.circ(ix - 6 + hashN(Double(sp) + floor(T * 5)) * 8, iy + 4 - hashN(Double(sp) * 3 + floor(T * 5)) * 8, 1.3, Col(0xffd257)) } }
                c.R(ix - 12, iy + 8, 14, 3, Col(0x6b4423))
            case 3:
                // drops falling into a bucket
                let ph = (T * 0.9).truncatingRemainder(dividingBy: 1)
                c.circ(ix, iy - 12 + ph * 14, 2.2, Col(0x6fd0ff, 1 - ph * 0.3))
                c.poly(Col(0x8a6a44), [ix - 9, iy + 2, ix + 9, iy + 2, ix + 7, iy + 13, ix - 7, iy + 13]); c.ell(ix, iy + 2, 9, 2.6, Col(0x4aa8e8))
                if ph > 0.85 { c.ellStroke(ix, iy + 2, 4 + (ph - 0.85) * 30, 1.5, 1, Col(0xffffff, 0.8)) }
            default:
                // your ship, rocking, a pennant streaming
                c.save(); c.translate(ix, iy + 2); c.rotate(sin(T * 2) * 0.12)
                c.poly(Col(0x6b4423), [-12, 2, 13, 2, 9, 9, -9, 9]); c.seg(0, 2, 0, -15, 1.4, Col(0x3b2412))
                c.poly(Col(0xf3ead2), [1, -14, 11, -1, 1, -1]); c.poly(REDC, [0, -15, -7 - sin(T * 7) * 1.5, -13, 0, -11])
                c.restore()
                c.ellStroke(ix, iy + 13, 12 + sin(T * 3) * 2, 2, 1, Col(0xffffff, 0.5))
            }
            // the words shrink to fit the door, whatever the width of the screen
            let room = max(20, bw - 44 - 10)
            let ts = min(16, 16 * room / max(1, textW(tl.0, 16, FONTB)))
            let ss = min(11, 11 * room / max(1, textW(tl.1, 11, FONTI)))
            c.text(tl.0, x + 44, by + 23, ts, ink, -1, FONTB)
            c.text(tl.1, x + 44, by + 39, ss, (tl.2 == 1 ? Col(0xffb0a0) : ink.alpha(0.85)), -1, FONTI)
            c.restore()
            // a badge on the corner: red and throbbing when it matters, gold when there is something to gain
            if tl.2 > 0 && !dim {
                let red = tl.2 == 1
                let r = 9 + (red ? sin(T * 7) * 1.6 : sin(T * 3) * 0.8)
                c.glow(x + bw - 6, by + 4, 22, (red ? Col(0xff5a3c, 0.6) : Col(0xffd257, 0.5)), Col(0xff5a3c, 0))
                c.circ(x + bw - 6, by + 4, r, red ? Col(0xd0352c) : Col(0xe6ae3c)); c.circStroke(x + bw - 6, by + 4, r, 1.5, Col(0xfff2c0))
                c.text(red ? "!" : "+", x + bw - 6, by + 9, 15, red ? WHITE : Col(0x2a1706), 0, FONTB)
            } else if i == 4 && ready {
                c.glow(x + bw / 2, by + bh / 2, bw * 0.7, Col(0xffd257, 0.2 + 0.12 * sin(T * 4)), Col(0xffd257, 0))
            }
        }
    }
}
