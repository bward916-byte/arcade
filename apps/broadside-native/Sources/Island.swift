import CoreGraphics
import Foundation

// The home island: the ground itself, the pier, and everything that stands on the island before you pay for it.

struct HouseStyle {
    var wall = "plaster"
    var roof = "tile"
    var rh = 18.0
    var wins: [(Double, Double)] = []
    var chimney = false
    var timber = false
}

extension Game {
    /// A day colour, darkened and cooled as the light goes.
    func lc(_ hex: UInt32) -> Col {
        let d = Col(hex)
        let n = Col(r: d.r * 0.3, g: d.g * 0.36, b: d.b * 0.5, a: 1)
        return Col.mix(n, d, light)
    }
    func vis(_ wx: Double, _ m: Double = 130) -> Bool {
        let X = sx(wx)
        return X > -m * camS && X < W + m * camS
    }
    /// Draw in local units with the origin at a world point.
    func at(_ c: Canvas, _ wx: Double, _ wy: Double, _ k: Double, _ body: () -> Void) {
        c.save()
        c.translate(sx(wx), sy(wy))
        c.scale(k, k)
        body()
        c.restore()
    }
    var BS: Double { return camS * 1.45 }

    // ---------- the wooded ridge behind the town and valley
    func drawRidge(_ c: Canvas, _ L: Double) {
        let par = camX * 0.72
        let k = camS
        let base = Col.mix(dn(0x0c1a14, 0x3f6a4a, L), dn(0x0b1a30, 0x7fa0c0, L), 0.22)
        let y0 = sy(-48)
        c.pathFill(base) { p in
            p.move(to: CGPoint(x: -10, y: self.sy(-40)))
            var x = -10.0
            while x <= self.W + 10 {
                let wx = x / k + par
                let hh = clampD((wx - 560) / 260, 0, 1) * clampD((3200 - wx) / 300, 0, 1)
                let body: Double = 46 + sin(wx * 0.006) * 20 + sin(wx * 0.021) * 8
                let tops: Double = abs(sin(wx * 0.19)) * 5 + abs(sin(wx * 0.43)) * 3
                p.addLine(to: CGPoint(x: x, y: y0 - hh * (body + tops) * k))
                x += 7
            }
            p.addLine(to: CGPoint(x: self.W + 10, y: self.sy(-40)))
            p.closeSubpath()
        }
        // birds far off
        for i in 0..<6 {
            let fi = Double(i)
            let span = W + 200
            let bx = (T * 14 + fi * 37 + sin(fi) * 60).truncatingRemainder(dividingBy: span) - 100
            let by = H * 0.2 + sin(T * 0.5 + fi) * 14 + fi * 7
            let f = sin(T * 7 + fi * 2) * 2.5
            let col = Col(0x282832, 0.35 * L)
            c.curve(bx - 4, by, bx - 2, by - 2 - f, bx, by, 1, col)
            c.curve(bx, by, bx + 2, by - 2 - f, bx + 4, by, 1, col)
        }
    }

    // ---------- things out on the water west of the pier
    func drawOffshore(_ c: Canvas, _ L: Double) {
        let k = camS
        // the rock, and the lighthouse you can raise on it
        if vis(-338, 220) {
            let wy = wave(-338) * 0.3
            at(c, -338, wy, k) {
                c.poly(self.lc(0x77746a), [-46, 10, -36, -8, -18, -20, 4, -24, 26, -16, 40, -4, 48, 10])
                c.poly(self.lc(0x4e4c46), [4, -24, 26, -16, 40, -4, 48, 10, 10, 10])
                for i in 0..<7 {
                    let fi = Double(i)
                    c.ell(-44 + fi * 15, 9 + sin(self.T * 2 + fi) * 1.5, 9, 2, Col(0xf0faff, 0.5 + 0.2 * sin(self.T * 2)))
                }
                if self.done.contains("light") {
                    let by = -22.0, hh = 96.0
                    c.linear(-10, by - hh, 20, hh, -9, 0, 9, 0, [(0, self.lc(0xf6f2e8)), (1, self.lc(0xa8a498))])
                    c.poly(self.lc(0xf6f2e8), [-10, by, -6, by - hh, 6, by - hh, 10, by])
                    c.poly(self.lc(0xb8b4a8), [2, by, 1.5, by - hh, 6, by - hh, 10, by])
                    for f in [0.22, 0.55] {
                        let yy: Double = by - hh * f
                        let hw: Double = 10 - 4 * f
                        c.poly(self.lc(0xa82a26), [-hw, yy, hw, yy, hw - 0.7, yy - 16, -hw + 0.7, yy - 16])
                    }
                    c.R(-9, by - hh - 2, 18, 2.5, Col(0x1a1a1e))
                    c.R(-5, by - hh - 12, 10, 10, L < 0.5 ? Col(0xfff3b0) : Col(0xcfd8dc))
                    c.poly(Col(0x2a2a30), [-7, by - hh - 12, 0, by - hh - 21, 7, by - hh - 12])
                    c.R(-1.6, by - 12, 3.2, 12, Col(0x2a1a0e))
                }
            }
        }
        // mooring buoy
        if vis(-330) {
            at(c, -330, wave(-330), k) {
                c.circ(0, -3, 5, Col(0xc03030))
                c.R(-5, -4, 10, 2, Col(0xf0f0f0))
                c.R(-1, -10, 2, 6, Col(0x333333))
            }
        }
        // your ship at anchor
        if boat >= 3 && vis(-520, 300) {
            let sc: Double = boat >= 5 ? 1.34 : (boat >= 4 ? 1.16 : 1)
            drawAnchoredShip(c, -520, sc, boat >= 5 ? 3 : 2, Col(0x6b4423), Col(0xeadfc4), Col(0x1f4a9c), L)
        }
        // raiders standing off in the dark
        if raiding && vis(-640, 300) {
            drawAnchoredShip(c, -640, 1.05, 2, Col(0x16110d), Col(0x2a2622), Col(0x101010), L)
            if raidFlash > 0 {
                let X = sx(-606), Y = sy(wave(-640) - 14)
                c.glow(X, Y, 60 * k, Col(0xffdc78, 0.9), Col(0xff8c28, 0))
                c.circ(X, Y, 7 * k, Col(0xfff4c0))
            }
            for i in 0..<5 {
                let a = (T * 0.5 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
                c.circ(sx(-600 + a * 50), sy(wave(-640) - 16 - a * 26), (5 + a * 12) * k, Col(0xd8d4cc, 0.3 * (1 - a)))
            }
        }
    }

    func drawAnchoredShip(_ c: Canvas, _ wx: Double, _ sc: Double, _ masts: Int, _ hull: Col, _ sail: Col, _ flag: Col, _ L: Double, _ full: Bool = false) {
        let tilt = cos(wx * 0.02 + T * 1.2) * 0.025
        c.save()
        c.translate(sx(wx), sy(wave(wx)))
        c.rotate(tilt)
        c.scale(camS * sc, camS * sc)
        let hl = Col.mix(hull.shade(0.3), hull, L)
        let sl = Col.mix(sail.shade(0.3), sail, L)
        // hull with a raised stern and a bowsprit
        c.pathFill(hl) { p in
            p.move(to: CGPoint(x: -84, y: -30))
            p.addLine(to: CGPoint(x: -84, y: -6))
            p.addLine(to: CGPoint(x: -72, y: 14))
            p.addLine(to: CGPoint(x: 62, y: 14))
            p.addQuadCurve(to: CGPoint(x: 92, y: -24), control: CGPoint(x: 84, y: 4))
            p.addLine(to: CGPoint(x: 66, y: -18))
            p.addLine(to: CGPoint(x: -52, y: -18))
            p.addLine(to: CGPoint(x: -52, y: -30))
            p.closeSubpath()
        }
        c.R(-84, -6, 172, 2.2, hl.shade(0.6))
        c.R(-52, -19.5, 120, 2, Col.mix(Col(0x3a2a14), Col(0xd8b86a), L))
        var gx = -40.0
        while gx < 60 {
            c.R(gx, -12, 6, 5, Col(0x0c0a08))
            gx += 20
        }
        c.seg(88, -24, 122, -36, 2, hl.shade(0.7))
        // masts, yards and furled sails
        let spots: [Double] = masts == 3 ? [-46, 4, 50] : [-22, 36]
        for (i, mx) in spots.enumerated() {
            let mh: Double = masts == 3 && i == 1 ? 138 : 118
            c.R(mx - 1.6, -18 - mh, 3.2, mh, hl.shade(0.65))
            for f in [0.42, 0.78] {
                let yy: Double = -18 - mh * f
                let hw: Double = 30 - f * 12
                c.R(mx - hw, yy, hw * 2, 2, hl.shade(0.6))
                c.pathFill(sl) { p in
                    p.move(to: CGPoint(x: mx - hw, y: yy + 2))
                    p.addQuadCurve(to: CGPoint(x: mx + hw, y: yy + 2), control: CGPoint(x: mx, y: yy + 11))
                    p.closeSubpath()
                }
            }
            if full {
                // set sails, bellied by the wind
                let belly = 7 + sin(self.T * 1.1 + mx) * 1.5
                for (fa, fb) in [(0.78, 0.44), (0.42, 0.1)] {
                    let ya: Double = -18 - mh * fa + 2
                    let yb: Double = -18 - mh * fb
                    let wa: Double = 30 - fa * 12
                    let wb: Double = 30 - fb * 12 + 2
                    c.pathFill(sl) { p in
                        p.move(to: CGPoint(x: mx - wa, y: ya))
                        p.addLine(to: CGPoint(x: mx + wa, y: ya))
                        p.addQuadCurve(to: CGPoint(x: mx + wb, y: yb), control: CGPoint(x: mx + wb + belly, y: (ya + yb) / 2))
                        p.addQuadCurve(to: CGPoint(x: mx - wb, y: yb), control: CGPoint(x: mx + belly * 0.6, y: yb + 5))
                        p.addQuadCurve(to: CGPoint(x: mx - wa, y: ya), control: CGPoint(x: mx - wb + belly * 0.5, y: (ya + yb) / 2))
                    }
                    c.pathFill(Col(0x000000, 0.1)) { p in
                        p.move(to: CGPoint(x: mx - wa, y: ya))
                        p.addQuadCurve(to: CGPoint(x: mx - wb, y: yb), control: CGPoint(x: mx - wb + belly * 0.5, y: (ya + yb) / 2))
                        p.addLine(to: CGPoint(x: mx - wb * 0.3, y: yb + 2))
                        p.addLine(to: CGPoint(x: mx - wa * 0.3, y: ya))
                        p.closeSubpath()
                    }
                }
            }
            c.seg(mx, -18 - mh, mx - 34, -18, 0.6, Col(0x000000, 0.4))
            c.seg(mx, -18 - mh, mx + 34, -18, 0.6, Col(0x000000, 0.4))
        }
        let top = spots[spots.count - 1]
        let fy: Double = -18 - 118
        let fw = sin(T * 5) * 2
        c.poly(Col.mix(flag.shade(0.4), flag, L), [top, fy, top + 18, fy + 3 + fw, top, fy + 9])
        if full {
            let jx = spots[spots.count - 1]
            c.poly(sl, [jx + 4, -120, 120, -36, jx + 4, -30])
        }
        c.restore()
        if full { return }
        // anchor cable
        c.curve(sx(wx - 70 * sc), sy(wave(wx)) + 6 * camS, sx(wx - 90 * sc), sy(40), sx(wx - 104 * sc), sy(70), 1 * camS, Col(0x3c2814, 0.8))
    }

    // ---------- the ground
    func drawLand(_ c: Canvas, _ L: Double) {
        let k = camS
        let wx0 = camX - W / 2 / k - 50
        let wx1 = camX + W / 2 / k + 50
        if wx1 < -150 || wx0 > XEND + 170 { return }
        let bot = H + 12
        let a0 = max(0.0, wx0), a1 = min(wx1, XEND + 160)
        // dunes behind the beach
        if wx0 < 900 {
            c.pathFill(dn(0x2a2418, 0xe8d8b0, L)) { p in
                p.move(to: CGPoint(x: self.sx(-20), y: self.sy(0)))
                var x = -20.0
                while x <= 900 {
                    let rise: Double = 18 + sin(x * 0.02) * 8 + max(0, x - 500) * 0.05
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(max(0, x)) - rise)))
                    x += 20
                }
                p.addLine(to: CGPoint(x: self.sx(900), y: self.sy(self.ground(900))))
                p.closeSubpath()
            }
        }
        // the body of the island: sand
        if a1 > a0 || wx0 < 0 {
            c.pathGrad(sy(-240), bot, [(0, dn(0x2e281c, 0xe2d2a6, L)), (0.55, dn(0x1e180f, 0xb89a68, L)), (1, dn(0x100c08, 0x6a5234, L))]) { p in
                p.move(to: CGPoint(x: self.sx(-140), y: bot))
                p.addLine(to: CGPoint(x: self.sx(-140), y: self.sy(70)))
                p.addLine(to: CGPoint(x: self.sx(-60), y: self.sy(34)))
                p.addLine(to: CGPoint(x: self.sx(0), y: self.sy(0)))
                var x = a0
                while x <= a1 {
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x))))
                    x += 6
                }
                p.addLine(to: CGPoint(x: self.sx(a1), y: self.sy(self.ground(a1))))
                p.addLine(to: CGPoint(x: self.sx(a1), y: bot))
                p.closeSubpath()
            }
        }
        // inland the ground is earth, eased in from the sand at either end
        func earth(_ e0: Double, _ e1: Double, _ alpha: Double) {
            let b0 = max(e0, wx0), b1 = min(e1, wx1)
            if b1 <= b0 { return }
            let top = dn(0x241a10, 0x8a6a44, L).alpha(alpha)
            let low = dn(0x0e0a06, 0x4a3420, L).alpha(alpha)
            c.pathGrad(sy(-240), bot, [(0, top), (1, low)]) { p in
                p.move(to: CGPoint(x: self.sx(b0), y: bot))
                var x = b0
                while x < b1 {
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x))))
                    x += 6
                }
                p.addLine(to: CGPoint(x: self.sx(b1), y: self.sy(self.ground(b1))))
                p.addLine(to: CGPoint(x: self.sx(b1), y: bot))
                p.closeSubpath()
            }
        }
        for i in 0..<6 {
            let fi = Double(i)
            earth(600 + fi * 26, 600 + (fi + 1) * 26 + 0.5, (fi + 1) / 7)
            earth(3184 + fi * 26, 3184 + (fi + 1) * 26 + 0.5, (6 - fi) / 7)
        }
        earth(756, 3184.5, 1)
        // strata and buried stones
        if wx1 > 640 && wx0 < 3340 {
            for (off, a) in [(16.0, 0.16), (34.0, 0.13), (58.0, 0.1), (90.0, 0.08)] {
                c.pathStroke(Col(0x1e1208, a), 2 * k) { p in
                    var x = max(660, wx0)
                    var first = true
                    while x <= min(3300, wx1) {
                        let pt = CGPoint(x: self.sx(x), y: self.sy(self.ground(x) + off + sin(x * 0.013 + off) * 5))
                        if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                        x += 14
                    }
                }
            }
            for i in 0..<70 {
                let wx = 660 + Double((i * 197) % 2640)
                if wx < wx0 || wx > wx1 { continue }
                let d = 14 + Double((i * 53) % 110)
                let r = (2.5 + Double((i * 7) % 5)) * k
                c.ell(sx(wx), sy(ground(wx) + d), r, r * 0.65, lc(0x8a8274).alpha(0.8))
            }
        }
        // foam on the west shore
        let fo = sin(T * 1.4) * 10
        c.ell(sx(8 + fo), sy(0), 30 * k, 2.5 * k, Col(0xffffff, 0.45))
        c.ell(sx(28 + fo), sy(ground(28)) - 1, 20 * k, 1.5 * k, Col(0xffffff, 0.2))
        // beach ripples, wrack and shell grit
        if wx0 < 640 {
            for (off, a) in [(9.0, 0.10), (19.0, 0.08), (31.0, 0.07), (46.0, 0.06)] {
                c.pathStroke(Col(0x785a32, a), 1 * k) { p in
                    var x = max(64, wx0)
                    var first = true
                    while x <= min(640, wx1) {
                        let pt = CGPoint(x: self.sx(x), y: self.sy(self.ground(x) + off + sin(x * 0.05 + off) * 2.2))
                        if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                        x += 10
                    }
                }
            }
            for i in 0..<30 {
                let fi = Double(i)
                let wx = 70 + hashN(fi + 11) * 560
                if wx < wx0 || wx > wx1 { continue }
                c.ell(sx(wx), sy(ground(wx)) + (2 + hashN(fi + 12) * 26) * k, 1.6 * k, 1 * k, Col(0xfffaeb, 0.35 + 0.3 * hashN(fi + 13)))
            }
            for i in 0..<30 {
                let fi = Double(i)
                let wx = 66 + hashN(fi + 41) * 120
                c.ell(sx(wx), sy(ground(wx)) + (1 + hashN(fi + 42) * 3) * k, (2 + hashN(fi + 43) * 4) * k, 0.9 * k, i % 3 == 0 ? Col(0x5a3c1e, 0.5) : Col(0x325028, 0.55))
            }
        }
        // turf over the high ground
        let g0 = max(wx0, 860.0), g1 = min(wx1, 3330.0)
        if g1 > g0 {
            c.pathFill(dn(0x12261a, 0x5f9a48, L)) { p in
                p.move(to: CGPoint(x: self.sx(g0), y: self.sy(self.ground(g0))))
                var x = g0
                while x <= g1 {
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x)) - 1 * k))
                    x += 8
                }
                x = g1
                while x >= g0 {
                    let fade = min(1.0, (x - 860) / 40, (3330 - x) / 40)
                    let depth: Double = (9 + sin(x * 0.37) * 2.5) * max(0.1, fade)
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x)) + depth * k))
                    x -= 8
                }
                p.closeSubpath()
            }
        }
        // the path, worn pale
        let p0 = max(wx0, 60.0), p1 = min(wx1, 3300.0)
        if p1 > p0 {
            c.pathFill(Col(0x967850, 0.55)) { p in
                p.move(to: CGPoint(x: self.sx(p0), y: self.sy(self.ground(p0)) + 1.5 * k))
                var x = p0
                while x <= p1 {
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x)) + 1.5 * k))
                    x += 10
                }
                x = p1
                while x >= p0 {
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x)) + 6 * k))
                    x -= 10
                }
                p.closeSubpath()
            }
        }
        // cobbles through the town
        var cx = (max(930, wx0) / 7).rounded(.up) * 7
        while cx < min(1640, wx1) {
            for r in 0..<2 {
                let fr = Double(r)
                let pick = Int(cx / 7) + r
                let stone: UInt32 = [0x9a958a, 0x8a8478, 0xa8a294][((pick % 3) + 3) % 3]
                c.ell(sx(cx + fr * 3.5), sy(ground(cx)) + (2.2 + fr * 3.2) * k, 3.1 * k, 1.5 * k, lc(stone))
            }
            cx += 7
        }
        // grass blades along the turf edge
        var gx = (max(865, wx0) / 4).rounded(.up) * 4
        c.roundCaps(true)
        while gx < min(3325, wx1) {
            let inTown = gx > 930 && gx < 1640 && Int(gx) % 3 != 0
            if !inTown {
                let X = sx(gx), Y = sy(ground(gx)) + 1
                let hgt = (3.5 + hashN(gx) * 5.5) * k
                let ln = (hashN(gx + 2) - 0.5) * 5 * k + sin(T * 1.6 + gx * 0.05) * 1.2 * k
                c.curve(X, Y, X + ln * 0.3, Y - hgt * 0.6, X + ln, Y - hgt, 1.1 * k, hashN(gx + 3) > 0.6 ? lc(0x8ab84a) : lc(0x4f8f34))
            }
            gx += 4
        }
        c.roundCaps(false)
    }

    // ---------- the east cove: water over the sloping sand
    func drawEastSea(_ c: Canvas, _ L: Double) {
        let k = camS
        let wx1 = camX + W / 2 / k + 30
        if wx1 < XEND - 10 { return }
        let top = sy(-4), bot = H + 2
        c.pathGrad(top, bot, [(0, dn(0x12303e, 0x2f8a96, L).alpha(0.82)), (1, dn(0x081822, 0x15485a, L).alpha(0.94))]) { p in
            p.move(to: CGPoint(x: self.sx(self.XEND - 34), y: bot))
            p.addLine(to: CGPoint(x: self.sx(self.XEND - 8), y: self.sy(self.wave(self.XEND - 8))))
            var x = self.XEND - 8
            while x <= wx1 {
                p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.wave(x))))
                x += 8
            }
            p.addLine(to: CGPoint(x: self.sx(wx1), y: bot))
            p.closeSubpath()
        }
        c.pathStroke(Col(0xdcf0f5, 0.3 + 0.3 * L), 2) { p in
            var x = self.XEND - 8
            var first = true
            while x <= wx1 {
                let pt = CGPoint(x: self.sx(x), y: self.sy(self.wave(x)))
                if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                x += 8
            }
        }
        let fo = sin(T * 1.4 + 2) * 8
        c.ell(sx(XEND - 6 + fo), sy(-1), 26 * k, 2.2 * k, Col(0xffffff, 0.4))
    }

    // ---------- the pier
    func drawPier(_ c: Canvas, _ L: Double) {
        let k = camS
        if sx(70) < -20 || sx(-250) > W + 20 { return }
        let deck = sy(-22)
        var px0 = -230.0
        while px0 <= -10 {
            let X = sx(px0)
            c.linear(X - 3 * k, deck, 6 * k, H - deck, X - 3 * k, 0, X + 3 * k, 0, [(0, dn(0x1c120a, 0x6e4a26, L)), (1, dn(0x0a0604, 0x2e1c0e, L))])
            c.R(X - 3 * k, sy(wave(px0)) - 4 * k, 6 * k, 8 * k, Col(0x285a50, 0.55))
            if px0 > -230 {
                c.seg(sx(px0 - 40), deck + 5 * k, X, deck + 30 * k, 1.8 * k, dn(0x140c06, 0x3a2512, L))
                c.seg(X, deck + 5 * k, sx(px0 - 40), deck + 30 * k, 1.8 * k, dn(0x140c06, 0x3a2512, L))
            }
            px0 += 40
        }
        let x0 = sx(-245), x1 = sx(0)
        c.vfill(x0, deck - 5 * k, x1 - x0, 7 * k, [(0, dn(0x2a1c10, 0x9a7446, L)), (1, dn(0x160e08, 0x5e4226, L))])
        var pl = -240.0
        while pl <= 0 {
            c.R(sx(pl), deck - 5 * k, 1 * k, 7 * k, Col(0x000000, 0.33))
            pl += 9
        }
        c.R(x0, deck - 5 * k, x1 - x0, 1.5 * k, Col(0xfff0c8, 0.12))
        // the ramp down to the sand
        let ry: Double = sy(ground(60))
        let rx: Double = sx(60)
        c.poly(dn(0x241810, 0x8a6840, L), [x1, deck - 5 * k, x1, deck + 2 * k, rx, ry + 1 * k, rx, ry - 4 * k])
        var rp = 4.0
        while rp < 60 {
            c.R(sx(rp), sy(groundLand(rp)) - 4 * k, 1 * k, 5 * k, Col(0x000000, 0.3))
            rp += 6
        }
        // rail, lantern post, net rack, barrels, bollard, lobster pots
        let wood = dn(0x1c120a, 0x4a2e14, L)
        c.R(sx(-245), deck - 20 * k, 2.5 * k, 16 * k, wood)
        c.R(sx(-180), deck - 20 * k, 2.5 * k, 16 * k, wood)
        c.R(sx(-245), deck - 20 * k, sx(-120) - sx(-245), 2.2 * k, wood)
        c.R(sx(-238), deck - 44 * k, 3 * k, 40 * k, dn(0x100a06, 0x3a2512, L))
        c.R(sx(-238), deck - 44 * k, 10 * k, 2 * k, dn(0x100a06, 0x3a2512, L))
        c.R(sx(-232), deck - 42 * k, 6 * k, 8 * k, L < 0.5 ? Col(0xffcc66) : Col(0xc8a860))
        c.R(sx(-233), deck - 43 * k, 8 * k, 1.5 * k, Col(0x222222))
        c.R(sx(-233), deck - 34 * k, 8 * k, 1.5 * k, Col(0x222222))
        for i in 0..<7 {
            let fi = Double(i)
            c.seg(sx(-172 + fi * 6), deck - 16 * k, sx(-150 + fi * 6), deck - 3 * k, 0.8 * k, Col(0xc8be9f, 0.5))
            c.seg(sx(-150 + fi * 6), deck - 16 * k, sx(-172 + fi * 6), deck - 3 * k, 0.8 * k, Col(0xc8be9f, 0.5))
        }
        c.R(sx(-176), deck - 18 * k, 2 * k, 14 * k, wood)
        c.R(sx(-108), deck - 18 * k, 2 * k, 14 * k, wood)
        c.R(sx(-176), deck - 18 * k, sx(-106) - sx(-176), 1.5 * k, wood)
        if done.contains("nets") {
            for i in 0..<8 {
                let fi = Double(i)
                c.seg(sx(-62 + fi * 4), deck - 18 * k, sx(-40 + fi * 4), deck - 2 * k, 0.8 * k, Col(0xc8be9f, 0.7))
                c.seg(sx(-40 + fi * 4), deck - 18 * k, sx(-62 + fi * 4), deck - 2 * k, 0.8 * k, Col(0xc8be9f, 0.7))
            }
        }
        drawBarrel(c, -92, -22, 5, L)
        drawBarrel(c, -80, -22, 5, L)
        c.R(sx(-30) - 2.5 * k, deck - 13 * k, 5 * k, 9 * k, Col(0x2a2a2a))
        c.circ(sx(-30), deck - 13 * k, 3.5 * k, Col(0x2a2a2a))
        for wx in [-200.0, -192.0] {
            let X = sx(wx), Y = deck - 5 * k
            c.RRStroke(X - 5 * k, Y - 7 * k, 10 * k, 7 * k, 1, 1 * k, lc(0x6a4a22))
            c.seg(X - 5 * k, Y - 3.5 * k, X + 5 * k, Y - 3.5 * k, 1 * k, lc(0x6a4a22))
        }
        // the fish cart, with the catch on it
        if done.contains("fishcart") {
            let X = sx(-50), Y = deck - 4 * k
            c.R(X - 11 * k, Y - 14 * k, 22 * k, 8 * k, lc(0x8a6238))
            c.circStroke(X - 6 * k, Y - 3.5 * k, 3.5 * k, 1.4 * k, Col(0x2a1a0e))
            c.circStroke(X + 6 * k, Y - 3.5 * k, 3.5 * k, 1.4 * k, Col(0x2a1a0e))
            for i in 0..<min(fish, 4) {
                c.ell(X - 7 * k + Double(i) * 4.5 * k, Y - 15 * k, 2.5 * k, 1.1 * k, lc(0x9fb8c8))
            }
        }
        // an old dory tied alongside
        at(c, -140, wave(-140), k) {
            c.pathFill(self.lc(0x7a5230)) { p in
                p.move(to: CGPoint(x: -18, y: -6))
                p.addQuadCurve(to: CGPoint(x: 18, y: -6), control: CGPoint(x: 0, y: -8))
                p.addLine(to: CGPoint(x: 11, y: 4))
                p.addLine(to: CGPoint(x: -11, y: 4))
                p.closeSubpath()
            }
            c.R(-9, -6, 18, 1.5, self.lc(0x4a2e14))
        }
        // the east dock, when it is built
    }

    // ---------- trees
    func drawTree(_ c: Canvas, _ wx: Double, _ h: Double, _ seed: Double) {
        if !vis(wx, 90) { return }
        let sw = sin(T * 0.7 + seed) * 1.2
        at(c, wx, ground(wx), camS) {
            c.ell(4, 1, h * 0.3, 3, Col(0x000000, 0.14))
            c.poly(self.lc(0x5a4028), [-3.4, 0, -2.2, -h * 0.55, 2.2, -h * 0.55, 3.6, 0])
            c.seg(0, -h * 0.4, -h * 0.16, -h * 0.62, 1.8, self.lc(0x5a4028))
            c.seg(0, -h * 0.45, h * 0.18, -h * 0.66, 1.8, self.lc(0x5a4028))
            let blobs: [(Double, Double, Double)] = [(-0.24, 0.62, 0.26), (0.24, 0.66, 0.25), (0, 0.84, 0.3), (-0.1, 0.7, 0.26), (0.14, 0.52, 0.2)]
            for (i, b) in blobs.enumerated() {
                let jx = (hashN(seed * 7 + Double(i)) - 0.5) * h * 0.08
                c.circ(b.0 * h + jx + sw * b.1, -b.1 * h, b.2 * h, self.lc(0x2f6a36))
            }
            for (i, b) in blobs.enumerated() {
                let jx = (hashN(seed * 7 + Double(i)) - 0.5) * h * 0.08
                c.circ(b.0 * h + jx + sw * b.1 - b.2 * h * 0.22, -b.1 * h - b.2 * h * 0.26, b.2 * h * 0.66, self.lc(0x4f9448))
            }
            c.circ(-0.12 * h + sw, -0.9 * h, 0.1 * h, self.lc(0x7ab85a).alpha(0.7))
        }
    }
    func drawCypress(_ c: Canvas, _ wx: Double, _ h: Double) {
        if !vis(wx, 60) { return }
        let sw = sin(T * 0.8 + wx) * 1.6
        at(c, wx, ground(wx), camS) {
            c.R(-1.4, -8, 2.8, 8, self.lc(0x4a3420))
            c.pathFill(self.lc(0x1f4a2c)) { p in
                p.move(to: CGPoint(x: -h * 0.11, y: -6))
                p.addQuadCurve(to: CGPoint(x: sw, y: -h), control: CGPoint(x: -h * 0.15, y: -h * 0.6))
                p.addQuadCurve(to: CGPoint(x: h * 0.11, y: -6), control: CGPoint(x: h * 0.15 + sw * 0.5, y: -h * 0.6))
                p.closeSubpath()
            }
            c.pathFill(self.lc(0x34703e)) { p in
                p.move(to: CGPoint(x: -h * 0.09, y: -10))
                p.addQuadCurve(to: CGPoint(x: sw, y: -h), control: CGPoint(x: -h * 0.13, y: -h * 0.6))
                p.addQuadCurve(to: CGPoint(x: -h * 0.01, y: -10), control: CGPoint(x: -h * 0.02, y: -h * 0.5))
                p.closeSubpath()
            }
        }
    }

    // ---------- a house, in one of several builds
    func drawHouse(_ c: Canvas, _ wx: Double, _ w: Double, _ h: Double, _ st: HouseStyle, _ L: Double) {
        if !vis(wx, w + 40) { return }
        let wallHex: UInt32 = st.wall == "stone" ? 0xa29c8e : (st.wall == "wood" ? 0x8e6a40 : 0xe6d8b6)
        let roofHex: UInt32 = st.roof == "thatch" ? 0xb89a50 : (st.roof == "wood" ? 0x5e4430 : 0x9a4030)
        let lit = L < 0.5
        let age = T - (born[Int(wx)] ?? -99)
        let grow: Double = age < 0.9 ? max(0.05, 1 - pow(1 - age / 0.9, 3)) : 1
        at(c, wx, ground(wx), BS) {
            if grow < 1 { c.scale(1, grow) }
            let hw = w / 2
            c.ell(4, 1, hw + 10, 3.5, Col(0x000000, 0.2))
            c.R(-hw - 2, -3, w + 4, 4, self.lc(0x77726a))
            c.linear(-hw, -h, w, h - 2, -hw, 0, hw, 0, [(0, self.lc(wallHex)), (1, self.lc(wallHex).shade(0.7))])
            if st.wall == "stone" {
                var row = 6.0
                while row < h - 2 {
                    c.R(-hw, -row, w, 0.5, Col(0x000000, 0.2))
                    var bx = -hw + (Int(row / 6) % 2 == 0 ? 5.0 : 10.0)
                    while bx < hw {
                        c.R(bx, -row, 0.5, 6, Col(0x000000, 0.16))
                        bx += 10
                    }
                    row += 6
                }
            } else if st.wall == "wood" {
                var bx = -hw + 5
                while bx < hw {
                    c.R(bx, -h, 0.6, h - 2, Col(0x000000, 0.22))
                    bx += 5
                }
            }
            if st.timber {
                let beam = self.lc(0x4a3220)
                c.R(-hw, -h, 2.4, h - 2, beam)
                c.R(hw - 2.4, -h, 2.4, h - 2, beam)
                c.R(-hw, -h * 0.5, w, 2, beam)
                c.R(-hw, -h, w, 2, beam)
                c.seg(-hw + 2, -h * 0.5, -hw * 0.45, -h + 2, 1.6, beam)
                c.seg(hw - 2, -h * 0.5, hw * 0.45, -h + 2, 1.6, beam)
            }
            // roof
            let rf = self.lc(roofHex)
            c.poly(rf, [-hw - 5, -h, 0, -h - st.rh, hw + 5, -h])
            c.poly(rf.shade(0.72), [0, -h - st.rh, hw + 5, -h, 2, -h])
            if st.roof == "tile" {
                for q in 1..<4 {
                    let f = Double(q) / 4
                    c.seg(-(hw + 5) * (1 - f), -h - st.rh * f, (hw + 5) * (1 - f), -h - st.rh * f, 0.5, Col(0x000000, 0.2))
                }
            } else if st.roof == "thatch" {
                var q = -hw - 2
                while q < hw + 4 {
                    c.seg(q, -h + 1.5, q + 1, -h - 1.5, 0.8, rf.shade(0.7))
                    q += 3
                }
            }
            c.R(-hw - 5, -h - 0.5, w + 10, 1.6, rf.shade(0.55))
            if st.chimney {
                let cx = hw * 0.55
                c.R(cx - 3, -h - st.rh * 0.5 - 12, 6, 14, self.lc(0x7a6a5a))
                c.R(cx - 3.8, -h - st.rh * 0.5 - 13.5, 7.6, 2, self.lc(0x5a4c40))
                for i in 0..<4 {
                    let a = (self.T * 0.3 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1)
                    c.circ(cx + a * 10 + sin(self.T + Double(i)) * 2, -h - st.rh * 0.5 - 14 - a * 30, 3 + a * 6, Col(0xe0ddd6, 0.3 * (1 - a)))
                }
            }
            // door and windows, lit after dark
            c.arch(-4.5, -15, 9, 15, self.lc(0x4a2e14))
            c.circ(2.4, -7, 0.7, Col(0xd8b86a))
            for (dx, dy) in st.wins {
                c.R(dx - 5, dy - 6, 10, 12, self.lc(0x4a3220))
                c.R(dx - 4, dy - 5, 8, 10, lit ? Col(0xffcc66) : Col(0x2a2c34))
                c.R(dx - 0.4, dy - 5, 0.8, 10, self.lc(0x4a3220))
                c.R(dx - 4, dy - 0.4, 8, 0.8, self.lc(0x4a3220))
                if lit { c.glow(dx, dy, 16, Col(0xffc86e, 0.3), Col(0xffc86e, 0)) }
            }
        }
    }

    func drawRock(_ c: Canvas, _ wx: Double, _ r: Double, _ seed: Double) {
        if !vis(wx, 40) { return }
        at(c, wx, ground(max(0, wx)) + 1, camS) {
            c.ell(r * 0.2, 0, r * 1.15, r * 0.16, Col(0x000000, 0.2))
            var pts: [Double] = []
            var shade: [Double] = []
            for q in 0...7 {
                let a = PI - Double(q) / 7 * PI
                let jr = 0.8 + hashN(seed * 9 + Double(q)) * 0.32
                pts.append(cos(a) * r * jr); pts.append(-sin(a) * r * 0.72 * jr)
                if q >= 4 { shade.append(cos(a) * r * jr); shade.append(-sin(a) * r * 0.72 * jr) }
            }
            c.poly(self.lc(0x8e8a80), pts)
            shade.append(r * 0.15); shade.append(0)
            c.poly(Col(0x000000, 0.22), shade)
            c.seg(pts[2], pts[3], pts[6], pts[7], 0.7, Col(0xfffff5, 0.22 * self.light))
        }
    }

    func drawLamp(_ c: Canvas, _ wx: Double, _ L: Double) {
        if !vis(wx, 40) { return }
        let k = camS
        let X = sx(wx), Y = sy(ground(wx))
        c.R(X - 1.2 * k, Y - 46 * k, 2.4 * k, 46 * k, Col(0x1c1c20))
        c.R(X - 3 * k, Y - 3 * k, 6 * k, 3 * k, Col(0x1c1c20))
        c.R(X - 4.5 * k, Y - 47 * k, 9 * k, 1.6 * k, Col(0x1c1c20))
        c.R(X - 3.5 * k, Y - 58 * k, 7 * k, 1.6 * k, Col(0x1c1c20))
        c.R(X - 3 * k, Y - 56.4 * k, 6 * k, 9.4 * k, L < 0.5 ? Col(0xffd98a) : Col(0xe6e6d2, 0.55))
    }

    // ---------- everything that stands on the island from the start
    func drawScenery(_ c: Canvas, _ L: Double) {
        let k = camS
        // the low hedge line behind the high ground
        let wx0 = camX - W / 2 / k - 30, wx1 = camX + W / 2 / k + 30
        let h0 = max(880, wx0), h1 = min(3300, wx1)
        if h1 > h0 {
            c.pathFill(Col.mix(dn(0x0a1a10, 0x356a3a, L), dn(0x0b1a30, 0x7fa0c0, L), 0.12)) { p in
                p.move(to: CGPoint(x: self.sx(h0), y: self.sy(self.ground(h0))))
                var x = h0
                while x <= h1 {
                    let up: Double = 15 + abs(sin(x * 0.11)) * 9 + abs(sin(x * 0.037)) * 10
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x)) - up * k))
                    x += 5
                }
                x = h1
                while x >= h0 {
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x)) + 2))
                    x -= 12
                }
                p.closeSubpath()
            }
        }
        // woods and cypresses
        let woods: [(Double, Double, Double)] = [(905, 74, 1), (960, 60, 2), (1332, 78, 3), (1505, 66, 4), (1640, 84, 5), (1745, 70, 6), (2330, 80, 7), (2395, 96, 8), (2450, 72, 9), (2640, 88, 10), (2700, 70, 11), (2760, 94, 12), (2960, 84, 13), (3030, 72, 14), (3190, 90, 15), (3215, 66, 16)]
        for (wx, h, sd) in woods { drawTree(c, wx, h, sd) }
        for (wx, h) in [(1235.0, 92.0), (1262, 70), (1880, 104), (1912, 82), (2118, 96), (2520, 88), (2548, 110), (3075, 84)] { drawCypress(c, wx, h) }
        // rocks
        for (wx, r, sd) in [(-34.0, 16.0, 1.0), (14, 11, 2), (640, 13, 3), (770, 18, 4), (830, 9, 5), (1190, 10, 6), (1985, 15, 7), (2610, 12, 8), (3300, 14, 9), (84, 7, 10), (108, 6, 11), (330, 5, 12), (560, 6, 13)] {
            drawRock(c, wx, r, sd)
        }
        // dune grass
        for (wx, n) in [(150.0, 7), (178, 5), (262, 8), (300, 6), (410, 9), (455, 6), (590, 9), (628, 7), (690, 8)] where vis(wx, 30) {
            let X = sx(wx), Y = sy(ground(wx)) + 1
            for j in 0..<n {
                let fj = Double(j)
                let a = -0.8 + fj * (1.6 / Double(n - 1)) + sin(T * 1.3 + wx + fj) * 0.06
                let len = (11 + hashN(wx + fj) * 9) * k
                c.curve(X + (fj - Double(n) / 2) * 1.2 * k, Y, X + sin(a) * len * 0.4, Y - len * 0.8, X + sin(a) * len, Y - len * 0.9, 1.2 * k, j % 2 == 0 ? lc(0x7a9a48) : lc(0xa8b060))
            }
        }
        // the warehouse, with crates on the dock and the hand cart
        drawHouse(c, 55, 70, 38, HouseStyle(wall: "stone", roof: "wood", rh: 14, wins: [(-20, -24)]), L)
        for i in 0..<min(crates, 3) {
            let wx = 104 + Double(i) * 13
            let X = sx(wx), Y = sy(ground(wx))
            c.R(X - 6 * k, Y - 12 * k, 12 * k, 12 * k, lc(0x8a6238))
            c.RRStroke(X - 6 * k, Y - 12 * k, 12 * k, 12 * k, 0.5, 1, Col(0x2a1a0e))
            c.seg(X - 6 * k, Y - 12 * k, X + 6 * k, Y, 1, Col(0x2a1a0e))
        }
        if done.contains("cart") {
            let X = sx(135), Y = sy(ground(135))
            c.R(X - 12 * k, Y - 14 * k, 24 * k, 9 * k, lc(0x8a6238))
            c.circStroke(X, Y - 4.5 * k, 4.5 * k, 1.5 * k, Col(0x2a1a0e))
            c.seg(X + 12 * k, Y - 12 * k, X + 22 * k, Y - 8 * k, 1.5 * k, Col(0x2a1a0e))
        }
        // a dinghy hauled up the sand, and the net-drying rack
        if vis(232, 60) {
            c.save()
            c.translate(sx(232), sy(ground(232)))
            c.rotate(-0.16)
            c.scale(k, k)
            c.ell(2, 2, 30, 4, Col(0x000000, 0.22))
            c.pathFill(lc(0x8a6238)) { p in
                p.move(to: CGPoint(x: -27, y: -11))
                p.addQuadCurve(to: CGPoint(x: 29, y: -12), control: CGPoint(x: 0, y: -13))
                p.addQuadCurve(to: CGPoint(x: 18, y: 2), control: CGPoint(x: 26, y: 0))
                p.addLine(to: CGPoint(x: -19, y: 2))
                p.addQuadCurve(to: CGPoint(x: -27, y: -11), control: CGPoint(x: -26, y: -2))
            }
            c.R(-26, -12.4, 54, 1.8, lc(0x2a5a7a))
            c.seg(-8, -12, 20, -20, 1.6, lc(0x5a3a1e))
            c.restore()
        }
        if vis(452, 60) {
            let X = sx(452), Y = sy(ground(452))
            for dx in [-22.0, 0, 22] { c.seg(X + dx * k, Y, X + dx * k, Y - 30 * k, 2 * k, lc(0x5a3a1e)) }
            c.seg(X - 24 * k, Y - 29 * k, X + 24 * k, Y - 29 * k, 2 * k, lc(0x5a3a1e))
            for i in 0...22 {
                let fi = Double(i)
                let xx = X - 22 * k + fi * 2 * k
                c.seg(xx, Y - 29 * k, xx + sin(fi * 0.6 + T) * 1.2 * k, Y - (8 + sin(fi * 0.5) * 3) * k, 0.6 * k, Col(0x3c463c, 0.55))
            }
            for (fx, col) in [(-12.0, UInt32(0xc03030)), (6, 0xe0a030), (15, 0xf0f0f0)] {
                c.circ(X + fx * k, Y - 11 * k, 1.8 * k, Col(col))
            }
        }
        // the shipwright's shed, with the next hull on the stocks
        if vis(350, 140) {
            at(c, 350, ground(350), BS) {
                c.ell(0, 1, 60, 4, Col(0x000000, 0.25))
                c.R(-50, -46, 100, 46, Col(0x0a0e16, 0.5 - 0.2 * L))
                let wood = self.lc(0x8a6238)
                for xx in [-55.0, 50, -20, 16] { c.R(xx, -50, 4.5, 50, wood) }
                c.poly(self.lc(0x4a3a2a), [-62, -50, 0, -74, 62, -50, 62, -46, -62, -46])
                c.poly(wood, [-60, -48, 0, -72, 60, -48])
                c.poly(Col(0x000000, 0.25), [-60, -48, 0, -72, 0, -48])
                c.R(-30, -8, 10, 8, self.lc(0x3a2a1a))
                c.R(20, -8, 10, 8, self.lc(0x3a2a1a))
                c.pathFill(self.lc(0x9a7040)) { p in
                    p.move(to: CGPoint(x: -34, y: -22))
                    p.addQuadCurve(to: CGPoint(x: -24, y: -8), control: CGPoint(x: -36, y: -10))
                    p.addLine(to: CGPoint(x: 26, y: -8))
                    p.addQuadCurve(to: CGPoint(x: 38, y: -26), control: CGPoint(x: 40, y: -12))
                    p.addLine(to: CGPoint(x: 30, y: -22))
                    p.closeSubpath()
                }
                for i in 0..<4 {
                    let fi = Double(i)
                    c.seg(-33 + fi, -20 + fi * 3, 36, -22 + fi * 3.5, 0.8, Col(0x000000, 0.4))
                }
                if self.boat >= 1 && self.boat < 3 {
                    c.R(-1, -62, 2.5, 40, self.lc(0x3a2512))
                    c.poly(self.lc(0xeadfc4), [1, -60, 26, -26, 1, -26])
                }
            }
        }
        // palms
        for (wx, h, lean) in [(160.0, 70.0, -0.35), (640, 84, 0.3), (500, 78, 0.4), (735, 62, -0.3), (1150, 70, 0.2), (1420, 80, -0.25), (1680, 66, 0.3)] where vis(wx, 100) {
            drawPalm(c, wx, h, lean, L)
        }
        // fence up the climb, and the signpost
        var fx = 620.0
        while fx <= 880 {
            let X = sx(fx), Y = sy(ground(fx))
            c.R(X - 1.2 * k, Y - 14 * k, 2.4 * k, 14 * k, lc(0x5a3a1e))
            if fx < 880 {
                let X2 = sx(fx + 28), Y2 = sy(ground(fx + 28))
                c.seg(X, Y - 10 * k, X2, Y2 - 10 * k, 1.5 * k, lc(0x5a3a1e))
                c.seg(X, Y - 5 * k, X2, Y2 - 5 * k, 1.5 * k, lc(0x5a3a1e))
            }
            fx += 28
        }
        if vis(590, 40) {
            let X = sx(590), Y = sy(ground(590))
            c.R(X - 1.5 * k, Y - 30 * k, 3 * k, 30 * k, lc(0x4a2e14))
            c.poly(lc(0xd8b86a), [X - 2 * k, Y - 28 * k, X + 16 * k, Y - 28 * k, X + 20 * k, Y - 24 * k, X + 16 * k, Y - 20 * k, X - 2 * k, Y - 20 * k])
        }
        // the town: market hall and stall, cottages, the tavern
        drawHouse(c, 1000, 88, 46, HouseStyle(wall: "plaster", roof: "tile", rh: 18, wins: [(-26, -30), (26, -30)]), L)
        if vis(1000, 90) {
            at(c, 1000, ground(1000), BS) {
                let wood = self.lc(0x8a6238)
                c.R(-38, -16, 76, 3, wood)
                c.R(-36, -13, 3, 13, wood)
                c.R(33, -13, 3, 13, wood)
                c.R(-38, -40, 2, 24, wood)
                c.R(36, -40, 2, 24, wood)
                for i in 0..<7 {
                    let ax = -42 + Double(i) * 12
                    c.pathFill(i % 2 == 1 ? self.lc(0xe8d090) : self.lc(0xb03030)) { p in
                        p.move(to: CGPoint(x: ax, y: -40))
                        p.addLine(to: CGPoint(x: ax + 12, y: -40))
                        p.addLine(to: CGPoint(x: ax + 12, y: -30))
                        p.addQuadCurve(to: CGPoint(x: ax, y: -30), control: CGPoint(x: ax + 6, y: -26))
                        p.closeSubpath()
                    }
                }
                c.R(-38, -40, 76, 2, Col(0x000000, 0.3))
                for (fx, col) in [(-28.0, UInt32(0xb8c8d8)), (-14, 0xd0a060), (0, 0xb8c8d8), (14, 0xe0d0b0), (26, 0x9fb0c0)] {
                    c.ell(fx, -18, 6, 2.2, self.lc(col))
                }
            }
        }
        drawHouse(c, 1100, 54, 40, HouseStyle(wall: "plaster", roof: "thatch", rh: 16, wins: [(0, -28)]), L)
        drawHouse(c, 1250, 120, 66, HouseStyle(wall: "plaster", roof: "tile", rh: 24, wins: [(-36, -50), (36, -50), (-36, -20), (36, -20)], chimney: true, timber: true), L)
        if vis(1250, 120) {
            // the tavern sign, flower boxes and barrels
            at(c, 1250, ground(1250), BS) {
                c.R(14, -40, 14, 1.4, Col(0x1c1c20))
                let sw = sin(self.T * 1.4) * 0.08
                c.save()
                c.translate(22, -39)
                c.rotate(sw)
                c.RR(-7, 1, 14, 10, 1.5, self.lc(0x5a3a1e))
                c.ell(0, 6, 3.6, 2.4, self.lc(0xd8b86a))
                c.restore()
                for fx in [-36.0, 36] {
                    c.R(fx - 6, -13, 12, 3, self.lc(0x8a6238))
                    let petals: [UInt32] = [0xe04060, 0xf0d040, 0xf08030, 0xe04060]
                    for i in 0..<4 { c.circ(fx - 4.4 + Double(i) * 2.9, -14.5, 1.3, Col(petals[i])) }
                }
            }
            drawBarrel(c, 1200, ground(1250) + 3, 6, L)
            drawBarrel(c, 1300, ground(1250) + 3, 6, L)
        }
        drawHouse(c, 1400, 64, 46, HouseStyle(wall: "stone", roof: "wood", rh: 16, wins: [(-18, -30), (18, -30)]), L)
        if stage >= 1 { drawHouse(c, 1480, 58, 42, HouseStyle(wall: "plaster", roof: "thatch", rh: 16, wins: [(0, -28)]), L) }
        drawHouse(c, 1560, 80, 54, HouseStyle(wall: "plaster", roof: "tile", rh: 20, wins: [(-24, -38), (24, -38)], chimney: true, timber: true), L)
        // the well and a bench
        if vis(1180, 40) {
            at(c, 1180, ground(1180), BS) {
                c.R(-10, -12, 20, 12, self.lc(0x9a968a))
                c.R(-10, -12, 20, 1.6, self.lc(0x6e6a60))
                c.R(-9, -32, 2, 20, self.lc(0x4a2e14))
                c.R(7, -32, 2, 20, self.lc(0x4a2e14))
                c.poly(self.lc(0x4a3a2a), [-13, -30, 0, -38, 13, -30])
                c.seg(0, -30, 0, -14, 0.8, Col(0x888888))
                c.R(-3, -16, 6, 5, self.lc(0x6a4a22))
            }
            let X = sx(1160), Y = sy(ground(1160))
            c.R(X - 12 * k, Y - 9 * k, 24 * k, 2.4 * k, lc(0x8a6238))
            c.R(X - 12 * k, Y - 17 * k, 24 * k, 2 * k, lc(0x8a6238))
            c.R(X - 11 * k, Y - 9 * k, 2 * k, 9 * k, lc(0x3a2512))
            c.R(X + 9 * k, Y - 9 * k, 2 * k, 9 * k, lc(0x3a2512))
        }
        // bushes, flowers and street lamps
        for bx in [930.0, 1060, 1330, 1480, 1620, 1760] where vis(bx, 30) {
            let X = sx(bx), Y = sy(ground(bx))
            for j in 0..<3 { c.circ(X + (Double(j) - 1) * 6 * k, Y - 5 * k, 6 * k, lc(0x3f7a3a)) }
            c.circ(X - 3 * k, Y - 8 * k, 3.4 * k, lc(0x5a9a4a))
        }
        for i in 0..<24 {
            let wx = 900 + Double((i * 83) % 1000)
            if !vis(wx, 10) { continue }
            let blooms: [UInt32] = [0xe8d040, 0xe07070, 0xf0f0f0, 0xc070e0]
            c.circ(sx(wx), sy(ground(wx)) - 3 * k, 1.3 * k, Col(blooms[i % 4]))
        }
        for lx in [915.0, 1148, 1345, 1622, 2400, 2905, 3210] { drawLamp(c, lx, L) }
        // the windmill on the slope
        if vis(1690, 80) {
            at(c, 1690, ground(1690), BS) {
                c.ell(0, 1, 22, 3, Col(0x000000, 0.25))
                c.poly(self.lc(0xa29c8e), [-18, 0, 18, 0, 11, -52, -11, -52])
                c.poly(Col(0x000000, 0.2), [-18, 0, -6, 0, -3, -52, -11, -52])
                c.poly(self.lc(0x4a3a2a), [-13, -52, 0, -64, 13, -52])
                c.R(-4, -14, 8, 14, self.lc(0x2a1a0e))
                c.R(-3, -36, 6, 7, L < 0.5 ? Col(0xffcc66) : Col(0x2a1a0e))
                c.save()
                c.translate(0, -50)
                c.rotate(self.T * 0.6)
                for _ in 0..<4 {
                    c.rotate(PI / 2)
                    c.R(-1, 0, 2, 34, self.lc(0x5a3a1e))
                    c.R(1, 6, 7, 26, self.lc(0xebe1c8).alpha(0.9))
                    for j in 0..<4 { c.R(1, 8 + Double(j) * 6, 7, 0.6, Col(0x000000, 0.3)) }
                }
                c.restore()
                c.circ(0, -50, 2.4, self.lc(0x3a2512))
            }
        }
        // steps cut into the headland climb
        var st = 1720.0
        while st < 2040 {
            if vis(st, 30) { c.R(sx(st), sy(ground(st)) - 1.5 * k, 18 * k, 1.5 * k, Col(0x000000, 0.3)) }
            st += 22
        }
        // the ruined fort and its old cannon on the headland
        if vis(2110, 110) {
            at(c, 2110, ground(2110), BS) {
                let stone = self.lc(0xa29c8e)
                c.ell(0, 1, 50, 4, Col(0x000000, 0.25))
                c.R(-44, -40, 30, 40, stone)
                c.R(-14, -24, 58, 24, stone)
                c.R(28, -56, 24, 56, stone)
                c.R(-44, -40, 8, 40, Col(0x000000, 0.22))
                c.R(28, -56, 6, 56, Col(0x000000, 0.22))
                for i in 0..<4 { c.R(-44 + Double(i) * 8, -46, 5, 6, stone) }
                for i in 0..<3 { c.R(28 + Double(i) * 9, -62, 5, 6, stone) }
                var row = 8.0
                while row < 56 {
                    c.R(-44, -row, 96, 0.5, Col(0x000000, 0.14))
                    row += 8
                }
                c.R(-32, -30, 8, 10, Col(0x2a1a0e))
                c.R(36, -44, 6, 8, Col(0x2a1a0e))
                c.poly(self.lc(0x5a3a1e), [-62, 0, -44, 0, -46, -7, -60, -7])
                c.circ(-58, -3.4, 3.4, self.lc(0x3a2512))
                c.circ(-48, -3.4, 3.4, self.lc(0x3a2512))
                c.save()
                c.translate(-50, -9)
                c.rotate(PI + 0.22)
                c.poly(self.lc(0x34363e), [-6, -3.2, 18, -2.3, 18, 2.3, -6, 3.2])
                c.R(17, -3, 2.2, 6, self.lc(0x22242a))
                c.circ(-6.5, 0, 2.2, self.lc(0x34363e))
                c.restore()
                c.circ(-30, -42, 6, self.lc(0x3f7a3a))
                c.circ(20, -26, 5, self.lc(0x3f7a3a))
                // flag
                c.R(39, -102, 1.6, 40, self.lc(0x3a2512))
                c.poly(self.lc(0x8a2a2a), [40.6, -102, 54, -99 + sin(self.T * 5) * 1.6, 40.6, -94])
            }
        }
        // split-rail fence along the valley road, haystacks
        var vx = 2380.0
        while vx < 2640 {
            if vis(vx, 40) {
                let X = sx(vx), Y = sy(ground(vx)), X2 = sx(vx + 26), Y2 = sy(ground(vx + 26))
                c.seg(X, Y, X, Y - 13 * k, 2.2 * k, lc(0x6a4a2a))
                c.seg(X, Y - 10 * k, X2, Y2 - 10 * k, 1.4 * k, lc(0x6a4a2a))
                c.seg(X, Y - 5 * k, X2, Y2 - 5 * k, 1.4 * k, lc(0x6a4a2a))
            }
            vx += 26
        }
        for hx in [2630.0, 2660, 3200] where vis(hx, 30) {
            let X = sx(hx), Y = sy(ground(hx))
            c.pathFill(lc(0xd4b04a)) { p in
                p.move(to: CGPoint(x: X - 11 * k, y: Y))
                p.addQuadCurve(to: CGPoint(x: X, y: Y - 21 * k), control: CGPoint(x: X - 10 * k, y: Y - 18 * k))
                p.addQuadCurve(to: CGPoint(x: X + 11 * k, y: Y), control: CGPoint(x: X + 10 * k, y: Y - 18 * k))
                p.closeSubpath()
            }
        }
        // sheep in the meadow
        for i in 0..<4 {
            let fi = Double(i)
            let home: Double = [2935, 3000, 3060, 2610][i]
            let wx = home + sin(T * 0.13 + fi * 2.3) * 26
            if !vis(wx, 30) { continue }
            let dir: Double = cos(T * 0.13 + fi * 2.3) > 0 ? 1 : -1
            c.save()
            c.translate(sx(wx), sy(ground(wx)))
            c.scale(k * dir, k)
            c.R(-5, -5, 1.6, 5, Col(0x2a2622))
            c.R(4, -5, 1.6, 5, Col(0x2a2622))
            c.ell(0, -8, 8, 5, lc(0xf0ece0))
            c.circ(-4, -10, 3, lc(0xf0ece0))
            c.circ(4, -10.5, 3, lc(0xf0ece0))
            let graze = sin(T * 0.4 + fi * 3) > 0.2
            c.ell(8.5, graze ? -4 : -9, 2.6, 2, Col(0x2a2622))
            c.restore()
        }
        // butterflies by day, fireflies by night
        if L > 0.5 {
            for i in 0..<9 {
                let fi = Double(i)
                let bx = 700 + Double((i * 331) % 2500) + sin(T * 0.5 + fi * 1.7) * 40
                if !vis(bx, 10) { continue }
                let by = ground(bx) - 14 - abs(sin(T * 0.9 + fi)) * 22
                let fl = abs(sin(T * 14 + fi * 3)) * 3.4 * k + 0.6
                let wings: [UInt32] = [0xffd24a, 0xf4f0e6, 0xff9a5a, 0x9ad0ff]
                let col = Col(wings[i % 4])
                c.ell(sx(bx) - fl * 0.5, sy(by), fl * 0.5, 2.2 * k, col)
                c.ell(sx(bx) + fl * 0.5, sy(by), fl * 0.5, 2.2 * k, col)
            }
        }
        // the dog asleep by the warehouse door, until you feed him
        if !dog && vis(-8, 30) {
            at(c, -8, -22, k * 1.4) {
                c.ell(0, -3, 9, 3.5 + sin(self.T * 1.2) * 0.3, self.lc(0x8a6a3a))
                c.circ(7, -4.5, 3.2, self.lc(0x8a6a3a))
                c.ell(9, -5, 1.5, 2.5, self.lc(0x5a3a1a))
            }
        }
        // a crab on the beach
        let crabX = 240 + sin(T * 0.5) * 60
        if vis(crabX, 20) {
            at(c, crabX, ground(crabX), k) {
                c.ell(0, -2.5, 4, 2.5, Col(0xc84a30))
                for s in [-1.0, 1] {
                    for j in 0..<3 { c.seg(s * 3, -2 + Double(j) * 0.8, s * (6 + sin(self.T * 12 + Double(j)) * 0.8), -0.4 + Double(j) * 0.2, 0.9, Col(0xc84a30)) }
                    c.circ(s * 5.4, -4.6, 1.2, Col(0xc84a30))
                }
            }
        }
    }
}
