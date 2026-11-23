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

        // ---- hills behind the town
        c.pathFill(Col(0x4d7f52).shade(dark * 0.9)) { p in
            p.move(to: CGPoint(x: W * 0.3, y: hz + 4))
            p.addQuadCurve(to: CGPoint(x: W * 0.56, y: hz - 122), control: CGPoint(x: W * 0.4, y: hz - 96))
            p.addQuadCurve(to: CGPoint(x: W * 0.8, y: hz - 92), control: CGPoint(x: W * 0.68, y: hz - 150))
            p.addQuadCurve(to: CGPoint(x: W + 10, y: hz - 118), control: CGPoint(x: W * 0.92, y: hz - 60))
            p.addLine(to: CGPoint(x: W + 10, y: hz + 4))
            p.closeSubpath()
        }
        c.pathFill(Col(0x5f9450).shade(dark)) { p in
            p.move(to: CGPoint(x: W * 0.36, y: hz + 4))
            p.addQuadCurve(to: CGPoint(x: W * 0.64, y: hz - 82), control: CGPoint(x: W * 0.48, y: hz - 76))
            p.addQuadCurve(to: CGPoint(x: W + 10, y: hz - 58), control: CGPoint(x: W * 0.84, y: hz - 96))
            p.addLine(to: CGPoint(x: W + 10, y: hz + 4))
            p.closeSubpath()
        }
        // terraced fields and a winding road up the hill
        for i in 0..<5 { c.curve(W * (0.5 + Double(i) * 0.09), hz - 26 - Double(i % 2) * 14, W * (0.56 + Double(i) * 0.09), hz - 42 - Double(i % 2) * 14, W * (0.62 + Double(i) * 0.09), hz - 30 - Double(i % 2) * 14, 1.2, Col(0x3f7a3c).shade(dark)) }
        c.curve(W * 0.6, hz + 2, W * 0.7, hz - 40, W * 0.6, hz - 96, 2.5, Col(0xd9c48a).shade(dark * 0.9))

        // ---- on the hilltop: a church with a bell, or a fort with a flag
        let tx = W * 0.58, ty = hz - 108
        if (leg + path[leg]) % 2 == 0 {
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

        // ---- the town: a back row on the slope, then the big houses along the waterfront
        func house(_ hx: Double, _ base: Double, _ hw: Double, _ hh: Double, _ k: Int) {
            let wall = [Col(0xf3ead2), Col(0xf0d8b0), Col(0xe8c8c0), Col(0xd8e4e8), Col(0xf6e6a8)][k % 5].shade(dark)
            let roof = [Col(0xb8452c), Col(0x8a5a36), Col(0xa63a2a), Col(0x6b4a3a)][k % 4].shade(dark)
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
        for i in 0..<8 {
            let hx = W * 0.47 + Double(i) * W * 0.062 + hashN(seed + Double(i)) * 8
            house(hx, hz - 26 - hashN(seed + Double(i) * 3.3) * 22, 20 + hashN(seed + Double(i) * 1.7) * 8, 18 + hashN(seed + Double(i) * 5.1) * 8, i + 2)
        }
        // palms between the rows
        for i in 0..<5 {
            let px = W * 0.44 + Double(i) * W * 0.125 + hashN(seed + Double(i) * 9) * 18
            let sw = sin(T * 1.2 + Double(i)) * 2 * (1 + rough * 2)
            c.curve(px, hz - 4, px + 3 + sw * 0.5, hz - 22, px + 5 + sw, hz - 40, 2.6, Col(0x6b4a26).shade(dark))
            for a in [-2.5, -1.8, -1.0, -0.3, 0.4] { c.curve(px + 5 + sw, hz - 40, px + 5 + sw + cos(a) * 11, hz - 44 + sin(a) * 10, px + 5 + sw + cos(a) * 20, hz - 37 + sin(a) * 14, 2.8, Col(0x3f7a3c).shade(dark)) }
        }
        var fx = W * 0.4
        var k = 0
        while fx < W + 20 {
            let hw = 30 + hashN(seed + Double(k) * 2.9) * 16, hh = 30 + hashN(seed + Double(k) * 6.1) * 24
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
        for i in 0..<3 {
            let sx = W * (0.5 + Double(i) * 0.14) + hashN(seed + Double(i) * 12) * 20
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

        // ---- the bay: fishing boats working, a rowing boat ferrying to your ship
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
        let nw = textW(nm, 24, FONTD) + 44
        let sway = sin(T * 1.3) * 0.02
        c.save()
        c.translate(W / 2, 38)
        c.rotate(sway)
        c.seg(-nw / 2 + 14, -6, -nw / 2 + 14, 8, 1.5, Col(0x1c1108)); c.seg(nw / 2 - 14, -6, nw / 2 - 14, 8, 1.5, Col(0x1c1108))
        c.RR(-nw / 2 + 2, 11, nw, 34, 7, Col(0x000000, 0.3))
        c.RRGrad(-nw / 2, 8, nw, 34, 7, [(0, Col(0x6b4423)), (1, Col(0x3f2613))])
        c.RRStroke(-nw / 2, 8, nw, 34, 7, 1.6, Col(0xd2a455))
        c.text(nm, 0, 33, 24, GOLD, 0, FONTD)
        c.restore()

        // something is going on in town: a call-out over the quay
        if sum == nil && card == nil && portJob > 0 && !portJobDone {
            let jobs: [(String, String)] = [("", ""), ("Work on the docks", "load cargo for pay"), ("Stop, thief!", "a cutpurse on the quay"), ("Rats on the gangway", "save your stores"), ("Festival tonight", "join the town"), ("An old sailor waves", "he has something for you")]
            let j = jobs[min(5, portJob)]
            let jw = 210.0, jx = W * 0.66 - jw / 2, jy = qy - 108 + sin(T * 3) * 3
            c.glow(jx + jw / 2, jy + 22, 150, Col(0xffd257, 0.2 + 0.1 * sin(T * 4)), Col(0xffd257, 0))
            c.poly(Col(0xe6ae3c), [jx + jw / 2 - 9, jy + 43, jx + jw / 2 + 9, jy + 43, jx + jw / 2, jy + 56])
            btn(c, jx, jy, jw, 44, "!  " + j.0, j.1, gold: true) { [unowned self] in
                switch self.portJob {
                case 1: self.playDock()
                case 2: self.playThief()
                case 3: self.playRats()
                case 4: self.joinFestival()
                default: self.playBarrels()
                }
            }
        }

        // what you can do ashore
        let names: [(String, String)] = [("Market", "buy and sell"), ("Tavern", "crew · maps · surgeon"), ("Shipwright", "mend the hull"), ("Well", wellUsed ? "casks filled" : "free water"), ("Set sail", "wages \(wagesDue())g")]
        let gap = 8.0
        let bw = (W - safeL - safeR - gap * 4) / 5
        let by = H - safeB - 52
        for (i, nm2) in names.enumerated() {
            let x = safeL + Double(i) * (bw + gap)
            btn(c, x, by, bw, 46, nm2.0, nm2.1, gold: i == 4, off: i == 3 && wellUsed) { [unowned self] in
                switch i {
                case 0: self.openMarket()
                case 1: self.tavern()
                case 2: self.shipwright()
                case 3: self.well()
                default: self.setSail()
                }
            }
        }
    }
}
