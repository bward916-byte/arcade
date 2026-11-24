import CoreGraphics
import Foundation

// The sea, the ships and every screen outside the sword fight.

extension Game {
    func draw(_ c: Canvas) {
        hits.removeAll(keepingCapacity: true)
        c.save()
        if shake > 0 { c.translate(rnd(-5, 5) * shake * 2.5, rnd(-5, 5) * shake * 2.5) }
        switch mode {
        case .title: drawTitle(c)
        case .pick: drawPick(c)
        case .outfit, .market: drawMarket(c)
        case .chart: drawChart(c)
        case .sail: drawSail(c)
        case .port: drawPort(c)
        case .tavern: drawTavern(c)
        case .duel: duel?.draw(c, self)
        case .end: drawEnd(c)
        }
        drawSparks(c)
        c.restore()
        if mode != .title && mode != .pick && mode != .end { drawHUD(c) }
        if sum != nil && card == nil { drawSummary(c) }
        if let cd = card { drawCard(c, cd) }
        if card != nil || sum != nil { drawSparks(c) }
        drawToast(c)
        drawRings(c)
    }

    // ---------- sky and sea
    struct Light {
        let top: Col
        let bot: Col
        let sea1: Col
        let sea2: Col
        let night: Double
        let dusk: Double
    }
    func light() -> Light {
        let t = tod
        let n = smooth((t - 0.62) / 0.1) * (1 - smooth((t - 0.9) / 0.08))
        let d1 = 1 - abs(t - 0.62) / 0.1, d2 = 1 - abs(t - 0.97) / 0.07
        let d = clampD(max(d1, d2), 0, 1)
        func m(_ day: UInt32, _ dusk: UInt32, _ night: UInt32) -> Col {
            return Col.mix(Col.mix(Col(day), Col(dusk), d), Col(night), n)
        }
        return Light(top: m(0x2f7fd0, 0x3a3f7a, 0x050c1e), bot: m(0xbfe3f5, 0xf7a35c, 0x1a2a4a), sea1: m(0x2b83bd, 0x6a6690, 0x10263c), sea2: m(0x0c3a63, 0x1a2444, 0x040b16), night: n, dusk: d)
    }

    /// Sky, sun or moon, clouds, far islands and the sea with its swell. `hz` is the horizon.
    func drawSea(_ c: Canvas, _ hz: Double) {
        let L = light()
        c.vfill(0, 0, W, hz + 1, [(0, L.top), (1, L.bot)])
        if L.night > 0.05 {
            for i in 0..<70 {
                let sx = hashN(Double(i) * 3.1) * W, sy = hashN(Double(i) * 7.7) * hz * 0.9
                let tw = 0.5 + 0.5 * sin(T * 2 + Double(i))
                c.circ(sx, sy, 0.7 + hashN(Double(i)) * 0.9, Col(0xffffff, L.night * (0.35 + 0.5 * tw)))
            }
        }
        // the sun rides an arc through the day; the moon takes the night
        let dayK = clampD(tod / 0.68, 0, 1)
        let sunX = W * (0.12 + 0.76 * dayK), sunY = hz - sin(dayK * PI) * hz * 0.78 + 8
        if L.night < 0.9 {
            let sc = Col.mix(Col(0xfff6d0), Col(0xffb060), L.dusk)
            c.glow(sunX, sunY, 150, sc.alpha(0.5 * (1 - L.night)), sc.alpha(0))
            c.circ(sunX, sunY, 17, sc.alpha(1 - L.night))
        }
        if L.night > 0.1 {
            // the moon crosses the night as the sun crossed the day
            let mk = clampD((tod - 0.64) / 0.34, 0, 1)
            let mx = W * (0.14 + 0.72 * mk), my = hz - sin(mk * PI) * hz * 0.7 + 8
            c.glow(mx, my, 90, Col(0xcfe0ff, 0.25 * L.night), Col(0xcfe0ff, 0))
            c.circ(mx, my, 13, Col(0xeef3ff, L.night))
            c.circ(mx + 5, my - 3, 11, L.top.alpha(L.night))
        }
        // clouds
        let cc = Col.mix(Col.mix(Col(0xffffff), Col(0xffc9a0), L.dusk), Col(0x2a3550), L.night)
        for i in 0..<7 {
            let sp = 4 + hashN(Double(i) * 2.3) * 6
            let span = W + 260
            var cx = (hashN(Double(i) * 5.9) * span + T * sp + scroll * 0.03).truncatingRemainder(dividingBy: span)
            if cx < 0 { cx += span }
            cx -= 130
            let cy = hz * (0.1 + hashN(Double(i) * 9.1) * 0.5)
            let s = 0.6 + hashN(Double(i) * 4.4) * 0.9
            c.ell(cx, cy + 5 * s, 46 * s, 9 * s, cc.shade(0.86).alpha(0.75))
            c.ell(cx - 20 * s, cy, 24 * s, 13 * s, cc.alpha(0.92))
            c.ell(cx + 4 * s, cy - 6 * s, 28 * s, 16 * s, cc.alpha(0.95))
            c.ell(cx + 28 * s, cy + 1 * s, 22 * s, 11 * s, cc.alpha(0.92))
        }
        // far islands on the horizon
        let ic = Col.mix(L.sea1, L.bot, 0.45)
        for i in 0..<3 {
            let span = W + 400
            var ix = (hashN(Double(i) * 8.3) * span - scroll * 0.06).truncatingRemainder(dividingBy: span)
            if ix < 0 { ix += span }
            ix -= 200
            let iw = 90 + hashN(Double(i) * 2.9) * 110, ih = 14 + hashN(Double(i) * 6.1) * 26
            c.pathFill(ic) { p in
                p.move(to: CGPoint(x: ix - iw / 2, y: hz + 1))
                p.addQuadCurve(to: CGPoint(x: ix - iw * 0.1, y: hz - ih), control: CGPoint(x: ix - iw * 0.3, y: hz - ih * 0.5))
                p.addQuadCurve(to: CGPoint(x: ix + iw * 0.18, y: hz - ih * 0.55), control: CGPoint(x: ix + iw * 0.05, y: hz - ih * 1.1))
                p.addQuadCurve(to: CGPoint(x: ix + iw / 2, y: hz + 1), control: CGPoint(x: ix + iw * 0.35, y: hz - ih * 0.5))
                p.closeSubpath()
            }
        }
        // the sea
        c.vfill(0, hz, W, H - hz, [(0, L.sea1), (1, L.sea2)])
        c.R(0, hz, W, 1.5, Col.mix(L.bot, WHITE, 0.3).alpha(0.6))
        if L.night < 0.9 {
            for i in 0..<26 {
                let k = Double(i) / 26
                let gy = hz + 3 + k * k * (H - hz)
                let gw = (6 + k * 46) * (0.6 + 0.4 * sin(T * 3 + Double(i) * 1.7))
                let gx = sunX - gw / 2 + sin(T * 1.3 + Double(i)) * 6 * k
                let ga = 0.34 * (1 - L.night) * (1 - k * 0.6)
                c.R(gx, gy, gw, 1.4 + k * 1.6, Col(0xfff2c8, ga))
            }
        }
        for i in 0..<8 {
            let k = (Double(i) + 0.5) / 8
            let y = hz + k * k * (H - hz) * 0.98 + 6
            let amp = 1.5 + k * 7, wl = 70 + k * 170
            let ph = scroll * (0.25 + k * 1.1) / wl * PI * 2 + Double(i) * 1.9
            c.pathStroke(Col(0xffffff, 0.08 + k * 0.14), 1 + k * 1.8) { p in
                var x = -10.0
                p.move(to: CGPoint(x: x, y: y + sin(x / wl * PI * 2 + ph) * amp))
                while x < W + 10 {
                    x += 14
                    p.addLine(to: CGPoint(x: x, y: y + sin(x / wl * PI * 2 + ph) * amp + sin(x * 0.021 + T * 0.8) * amp * 0.4))
                }
            }
        }
    }

    /// The front swell, drawn over a hull so the ship sits in the water.
    func foreWave(_ c: Canvas, _ y: Double, _ x0: Double, _ x1: Double) {
        let L = light()
        let ph = scroll * 0.02
        let sw = 1 + rough * 1.8
        c.pathFill(Col.mix(L.sea1, L.sea2, 0.45)) { p in
            var x = x0
            p.move(to: CGPoint(x: x0, y: y + 60))
            while x <= x1 {
                p.addLine(to: CGPoint(x: x, y: y + (sin(x * 0.03 + ph + T * 1.4) * 3.5 + sin(x * 0.011 - T) * 2) * sw))
                x += 8
            }
            p.addLine(to: CGPoint(x: x1, y: y + 60))
            p.closeSubpath()
        }
        c.pathStroke(Col(0xffffff, 0.55), 1.6) { p in
            var x = x0
            p.move(to: CGPoint(x: x, y: y + (sin(x * 0.03 + ph + T * 1.4) * 3.5 + sin(x * 0.011 - T) * 2) * sw))
            while x <= x1 {
                x += 8
                p.addLine(to: CGPoint(x: x, y: y + (sin(x * 0.03 + ph + T * 1.4) * 3.5 + sin(x * 0.011 - T) * 2) * sw))
            }
        }
    }

    /// A ship seen from the side, bow to the right. (x, wy) is the middle of her waterline; len is her length.
    func drawShip(_ c: Canvas, _ x: Double, _ wy: Double, _ len: Double, _ masts: Int, enemy: Bool = false, furled: Bool = false, life: Bool = false) {
        let u = len / 200
        let L = light()
        let dark = 1 - L.night * 0.45
        let bob = sin(T * 1.3 + x * 0.01) * 2.5 * u * (1 + rough * 2.4)
        c.save()
        c.translate(x, wy + bob)
        c.rotate(sin(T * 0.9 + x * 0.02) * 0.018 * (1 + rough * 3.2))
        c.scale(u, u)
        let hullC = (enemy ? Col(0x2a2228) : Col(0x6b4423)).shade(dark)
        let hullD = (enemy ? Col(0x15101a) : Col(0x3f2613)).shade(dark)
        let trim = (enemy ? Col(0x8a1a1a) : Col(0xd9a441)).shade(dark)
        let sail = (enemy ? Col(0x8a1f1f) : Col(0xf3ead2)).shade(dark)
        let sailD = (enemy ? Col(0x5a1010) : Col(0xcdbf9c)).shade(dark)
        let spar = Col(0x3b2412).shade(dark)
        let rope = Col(0x1c1108, 0.6)
        // her shadow on the water
        c.ell(-2, 11, 104, 7, Col(0x000000, 0.2))
        // spars and sails first, so the hull overlaps the mast feet
        var mx: [Double] = [6]
        if masts == 2 { mx = [-34, 34] } else if masts >= 3 { mx = [-56, -2, 48] }
        for (i, m) in mx.enumerated() {
            let tall = (i == mx.count / 2 || mx.count == 1) ? 168.0 : 140.0
            c.R(m - 2.5, -30 - tall, 5, tall, spar)
            let levels = tall > 150 ? 3 : 2
            for lv in 0..<levels {
                let top = -30 - tall + 14 + Double(lv) * (tall - 30) / Double(levels)
                let h = (tall - 44) / Double(levels)
                let w = 60 - Double(lv == 0 ? 16 : 0) + (lv == levels - 1 ? 8 : 0)
                c.R(m - w / 2 - 4, top - 2, w + 8, 3.5, spar)
                if furled {
                    c.RR(m - w / 2, top + 1, w, 7, 3.5, sailD)
                } else {
                    let belly = 9 + sin(T * 1.7 + Double(i + lv)) * 2.5
                    c.pathGrad(top, top + h, [(0, sail), (1, sailD)]) { p in
                        p.move(to: CGPoint(x: m - w / 2, y: top + 2))
                        p.addLine(to: CGPoint(x: m + w / 2, y: top + 2))
                        p.addQuadCurve(to: CGPoint(x: m + w / 2 + 2, y: top + h), control: CGPoint(x: m + w / 2 + belly, y: top + h * 0.5))
                        p.addQuadCurve(to: CGPoint(x: m - w / 2 + 2, y: top + h), control: CGPoint(x: m + 2, y: top + h - 7))
                        p.addQuadCurve(to: CGPoint(x: m - w / 2, y: top + 2), control: CGPoint(x: m - w / 2 + belly * 0.8, y: top + h * 0.5))
                    }
                    for s in 1..<4 {
                        let sx = m - w / 2 + w * Double(s) / 4
                        c.seg(sx + belly * 0.4, top + 4, sx + belly * 0.5, top + h - 4, 0.8, sailD.alpha(0.7))
                    }
                    // light on the windward edge, reef points, and a device on the main course
                    c.curve(m - w / 2 + 2, top + 4, m - w / 2 + belly * 0.8 + 2, top + h * 0.5, m - w / 2 + 4, top + h - 3, 2.2, Col(0xffffff, enemy ? 0.08 : 0.28))
                    for rp in 0..<6 {
                        let rx = m - w / 2 + 6 + Double(rp) * (w - 12) / 5 + belly * 0.35
                        c.R(rx, top + h * 0.3, 1, 3.5, sailD.shade(0.8))
                    }
                    if lv == levels - 1 && i == mx.count / 2 {
                        let ex = m + belly * 0.4, ey = top + h * 0.52
                        if enemy {
                            c.circ(ex, ey - 2, 7, Col(0xf1e7cf, 0.9)); c.R(ex - 4, ey + 3, 8, 4, Col(0xf1e7cf, 0.9))
                            c.circ(ex - 2.6, ey - 2.5, 1.7, Col(0x1a0a0a)); c.circ(ex + 2.6, ey - 2.5, 1.7, Col(0x1a0a0a))
                        } else {
                            c.circStroke(ex, ey, 8, 1.6, REDC.shade(dark).alpha(0.8))
                            for a in 0..<8 { c.seg(ex + cos(Double(a) * PI / 4) * 3, ey + sin(Double(a) * PI / 4) * 3, ex + cos(Double(a) * PI / 4) * 11, ey + sin(Double(a) * PI / 4) * 11, 1.2, REDC.shade(dark).alpha(0.8)) }
                        }
                    }
                }
            }
            // shrouds with ratlines down to the rail, and a top for the lookout
            let topY = -30 - tall + 12
            for kx in 0..<3 {
                c.seg(m, topY, m - 12 - Double(kx) * 7, -32, 0.7, rope)
                c.seg(m, topY, m + 12 + Double(kx) * 7, -32, 0.7, rope)
            }
            for r in 2..<9 {
                let f = Double(r) / 9
                let yy = lerp(topY, -32, f)
                c.seg(m - 26 * f, yy, m - 12 * f, yy, 0.6, rope)
                c.seg(m + 12 * f, yy, m + 26 * f, yy, 0.6, rope)
            }
            if tall > 150 {
                c.RR(m - 8, -30 - tall * 0.66, 16, 6, 2, spar)
                c.R(m - 8, -30 - tall * 0.66 - 5, 1.2, 5, spar); c.R(m + 6.8, -30 - tall * 0.66 - 5, 1.2, 5, spar)
                c.circ(m, -30 - tall * 0.66 - 4, 2.4, Col(0xe3b58a).shade(dark))
            }
            // a pennant at each masthead
            let fl = sin(T * 5 + Double(i)) * 3
            c.poly(enemy ? Col(0x111111) : REDC, [m + 2.5, -30 - tall, m + 26, -30 - tall + 5 + fl, m + 2.5, -30 - tall + 10])
        }
        // stays from masthead to masthead and down to the bowsprit
        for i in 1..<max(1, mx.count) { c.seg(mx[i - 1], -160, mx[i], -168, 0.7, rope) }
        if let fm0 = mx.last { c.seg(fm0, -30 - 150, 142, -58, 0.8, rope); c.seg(fm0, -30 - 96, 128, -52, 0.7, rope) }
        if let am = mx.first { c.seg(am, -30 - 130, -100, -52, 0.8, rope) }
        // bowsprit and jib
        c.seg(84, -30, 142, -58, 4, spar)
        if !furled, let fm = mx.last {
            c.pathGrad(-170, -34, [(0, sail), (1, sailD)]) { p in
                p.move(to: CGPoint(x: 140, y: -57))
                p.addLine(to: CGPoint(x: fm + 3, y: -30 - 130))
                p.addQuadCurve(to: CGPoint(x: fm + 14, y: -40), control: CGPoint(x: fm + 22, y: -90))
                p.closeSubpath()
            }
        }
        // the hull
        c.pathGrad(-50, 10, [(0, hullC), (1, hullD)]) { p in
            p.move(to: CGPoint(x: -100, y: -50))
            p.addLine(to: CGPoint(x: -62, y: -50))
            p.addLine(to: CGPoint(x: -58, y: -31))
            p.addLine(to: CGPoint(x: 70, y: -31))
            p.addQuadCurve(to: CGPoint(x: 104, y: -40), control: CGPoint(x: 92, y: -32))
            p.addQuadCurve(to: CGPoint(x: 78, y: 8), control: CGPoint(x: 100, y: -8))
            p.addLine(to: CGPoint(x: -84, y: 8))
            p.addQuadCurve(to: CGPoint(x: -100, y: -50), control: CGPoint(x: -104, y: -14))
        }
        // planking, strake by strake, and a lighter band where the sun catches her side
        for pl in 0..<5 {
            let py = -27 + Double(pl) * 7.5
            let inset = Double(pl) * 2.5
            c.curve(-98 + inset * 0.4, py, 0, py + 1.5, 96 - inset * 3.2, py - 1, 0.7, hullD.alpha(0.75))
        }
        for b in 0..<9 { c.R(-88 + Double(b) * 21 + (Double(b % 2) * 8), -26 + Double(b % 3) * 7.5, 0.8, 7.5, hullD.alpha(0.55)) }
        c.curve(-96, -29, 0, -27.5, 98, -36, 2, Col(0xffffff, enemy ? 0.05 : 0.13))
        c.R(-98, -24, 186, 3, trim)
        c.R(-98, -20.5, 184, 1, hullD.alpha(0.8))
        c.R(-100, -52, 40, 3, trim)
        c.R(-58, -33, 130, 2.5, hullD)
        // deck rail
        c.R(-58, -38.5, 128, 1.3, trim.shade(0.85))
        for rl in 0..<15 { c.R(-56 + Double(rl) * 9, -38, 1.1, 6, trim.shade(0.8)) }
        // stern gallery: a balcony under the windows, carved brackets, the rudder
        c.R(-101, -35.5, 42, 2, trim)
        for g in 0..<5 { c.R(-99 + Double(g) * 9.5, -41, 1, 6, trim.shade(0.85)) }
        c.R(-104.5, -22, 4, 30, hullD)
        c.R(-105.5, -10, 6, 1.5, Col(0x1a1a1e)); c.R(-105.5, 0, 6, 1.5, Col(0x1a1a1e))
        // gunports with lids raised and the muzzles run out
        for i in 0..<6 {
            let gx = -50 + Double(i) * 22
            c.R(gx - 1, -18, 10, 9, trim.shade(0.75))
            c.R(gx, -17, 8, 7, Col(0x0c0806))
            c.poly(hullC.shade(1.15), [gx, -17, gx + 8, -17, gx + 9, -21, gx - 1, -21])
            c.circ(gx + 4, -13.5, 2.1, Col(0x2a2a30)); c.circ(gx + 4, -13.5, 1, Col(0x050505))
        }
        // figurehead, cathead and anchor at the bow
        c.poly(trim, [98, -41, 113, -47, 108, -40, 103, -33])
        c.circ(112, -48, 2.6, trim.shade(1.1))
        c.seg(80, -31, 88, -27, 2, spar)
        c.seg(88, -27, 88, -15, 1.3, Col(0x23232a))
        c.arcStroke(88, -15, 4.5, 0.1, PI - 0.1, 1.6, Col(0x23232a))
        c.seg(84.5, -22, 91.5, -22, 1.3, Col(0x23232a))
        // foam along the waterline, a bow wave and a wake when she is under way
        c.ell(-6, 8.5, 92, 2.4, Col(0xffffff, 0.3))
        if !furled {
            let surge = 1 + sin(T * 3.1) * 0.15
            c.pathFill(Col(0xffffff, 0.75)) { p in
                p.move(to: CGPoint(x: 76, y: 9))
                p.addQuadCurve(to: CGPoint(x: 104, y: -6 * surge), control: CGPoint(x: 96, y: 6))
                p.addQuadCurve(to: CGPoint(x: 116, y: 9), control: CGPoint(x: 112, y: -2 * surge))
                p.closeSubpath()
            }
            for wk in 0..<8 {
                let d = (Double(wk) * 17 + (T * 46).truncatingRemainder(dividingBy: 17))
                c.ell(-108 - d, 9 + sin(T * 2 + Double(wk)) * 1.5, 9 - Double(wk) * 0.7, 1.8, Col(0xffffff, 0.5 * (1 - d / 150)))
            }
        }
        // the ensign on its staff at the taffrail
        c.seg(-92, -52, -92, -84, 1.4, spar)
        let fc = enemy ? Col(0x111111) : REDC.shade(dark)
        c.pathFill(fc) { p in
            p.move(to: CGPoint(x: -92, y: -84))
            for st in 1...6 {
                let fx = -92 - Double(st) * 4.5
                p.addLine(to: CGPoint(x: fx, y: -84 + sin(T * 6 + Double(st) * 0.9) * 2.2 * Double(st) / 6))
            }
            for st in stride(from: 6, through: 0, by: -1) {
                let fx = -92 - Double(st) * 4.5
                p.addLine(to: CGPoint(x: fx, y: -70 + sin(T * 6 + Double(st) * 0.9) * 2.2 * Double(st) / 6))
            }
            p.closeSubpath()
        }
        if !enemy { c.R(-110, -78.5, 16, 2, Col(0xf1e7cf, 0.9)); c.R(-103, -84, 2, 13, Col(0xf1e7cf, 0.9)) }
        let lit = L.night > 0.3 ? Col(0xffd257) : Col(0xf0c860).shade(0.85)
        for wn in 0..<3 {
            let wxx = -96 + Double(wn) * 12
            c.R(wxx - 1, -45, 9, 10, trim.shade(0.8))
            c.R(wxx, -44, 7, 8, lit)
            c.R(wxx + 3, -44, 1, 8, trim.shade(0.7)); c.R(wxx, -40.5, 7, 1, trim.shade(0.7))
        }
        // lantern at the stern
        c.seg(-100, -52, -104, -66, 1.5, spar)
        c.circ(-104, -68, 3.5, Col(0xffd257))
        if L.night > 0.2 { c.glow(-104, -68, 34, Col(0xffc060, 0.5 * L.night), Col(0xffc060, 0)) }
        // what the yards have added: copper below the waterline, a spritsail and staysail, brass on the guns
        if !enemy {
            if up("hull") > 0 {
                c.curve(-86, 5.5, 0, 7.5, 80, 5.5, up("hull") > 1 ? 5 : 3, Col(0x4fa58a).shade(dark))
                c.curve(-86, 3.5, 0, 5.5, 80, 3.5, 0.8, Col(0xc98a45).shade(dark))
            }
            if up("sails") > 0 && !furled {
                c.pathGrad(-52, -30, [(0, sail), (1, sailD)]) { p in
                    p.move(to: CGPoint(x: 100, y: -46)); p.addLine(to: CGPoint(x: 132, y: -60)); p.addQuadCurve(to: CGPoint(x: 124, y: -36), control: CGPoint(x: 136, y: -46)); p.addLine(to: CGPoint(x: 98, y: -30)); p.closeSubpath()
                }
                if up("sails") > 1 && mx.count > 1 {
                    c.pathGrad(-150, -60, [(0, sail), (1, sailD)]) { p in
                        p.move(to: CGPoint(x: mx[0] + 4, y: -150)); p.addLine(to: CGPoint(x: mx[1] - 6, y: -62)); p.addQuadCurve(to: CGPoint(x: mx[0] + 8, y: -66), control: CGPoint(x: (mx[0] + mx[1]) / 2, y: -52)); p.closeSubpath()
                    }
                }
            }
            if up("guns") > 0 {
                for i in 0..<6 { c.circStroke(-50 + Double(i) * 22 + 4, -13.5, 2.8, 1, Col(0xd9a441)) }
                c.seg(-70, -52, -64, -60, 2.2, Col(0x2a2a30)); c.circ(-70, -52, 2, Col(0xd9a441))
                if up("guns") > 1 { c.seg(60, -38, 67, -45, 2.2, Col(0x2a2a30)); c.circ(60, -38, 2, Col(0xd9a441)) }
            }
        }
        if life {
            deckLife(c, mx, dark)
        } else {
            // a few hands on deck
            for i in 0..<4 {
                let px = -40 + Double(i) * 26 + sin(T * 0.6 + Double(i) * 2) * 6
                c.R(px - 2, -42, 4, 9, [Col(0x2f5f8f), Col(0x8c3b2e), Col(0xd9cdb0), Col(0x3a7a6d)][i].shade(dark))
                c.circ(px, -45, 2.6, Col(0xe3b58a).shade(dark))
            }
        }
        c.restore()
    }

    // ---------- title
    func drawTitle(_ c: Canvas) {
        let splash = Art.get("splash")
        if let sp = splash {
            // the painted sunrise, filling the screen, with gulls wheeling over it
            let sc = max(W / Double(sp.width), H / Double(sp.height))
            let iw = Double(sp.width) * sc, ih = Double(sp.height) * sc
            let drift = sin(T * 0.15) * 4
            c.drawImage(sp, (W - iw) / 2 + drift - 4, H - ih, iw + 8, ih)
            for i in 0..<4 {
                let gx = W * 0.5 + cos(T * (0.3 + Double(i) * 0.05) + Double(i) * 1.9) * W * (0.25 + Double(i) * 0.04)
                let gy = H * 0.34 + sin(T * (0.42 + Double(i) * 0.04) + Double(i)) * H * 0.12
                let fl = sin(T * 7 + Double(i) * 2) * 4
                c.curve(gx - 8, gy + fl, gx - 4, gy - 3, gx, gy, 1.5, Col(0xffffff, 0.95)); c.curve(gx, gy, gx + 4, gy - 3, gx + 8, gy + fl, 1.5, Col(0xffffff, 0.95))
            }
            // the sun's road on the water, glittering
            for i in 0..<10 {
                let ph = (T * 0.5 + hashN(Double(i) * 3.3)).truncatingRemainder(dividingBy: 1)
                c.ell(W * 0.74 + (hashN(Double(i)) - 0.5) * 120, H * (0.76 + hashN(Double(i) * 7) * 0.2), 10 + ph * 8, 1.2, Col(0xfff2c0, 0.5 * sin(ph * PI)))
            }
            c.vfill(0, 0, W, H * 0.45, [(0, Col(0x3a1408, 0.45)), (1, Col(0x3a1408, 0))])
        } else {
        let hz = H * 0.56
        drawSea(c, hz)
        let wy = hz + (H - hz) * 0.42
        // a far sail, gulls, and something leaping off the bow
        let fs = W * 0.9 - (T * 4).truncatingRemainder(dividingBy: W * 0.5)
        c.poly(Col(0xf3ead2, 0.8), [fs - 6, hz, fs - 6, hz - 15, fs + 1, hz - 2]); c.poly(Col(0xf3ead2, 0.8), [fs + 2, hz, fs + 2, hz - 19, fs + 10, hz - 2]); c.poly(Col(0x3f2613), [fs - 11, hz + 1, fs + 12, hz + 1, fs + 8, hz + 4, fs - 8, hz + 4])
        for i in 0..<5 {
            let gx = W * 0.45 + cos(T * (0.3 + Double(i) * 0.05) + Double(i) * 1.9) * W * (0.2 + Double(i) * 0.04)
            let gy = hz * 0.4 + sin(T * (0.42 + Double(i) * 0.04) + Double(i)) * hz * 0.25
            let fl = sin(T * 7 + Double(i) * 2) * 4
            c.curve(gx - 8, gy + fl, gx - 4, gy - 3, gx, gy, 1.5, Col(0xffffff, 0.95)); c.curve(gx, gy, gx + 4, gy - 3, gx + 8, gy + fl, 1.5, Col(0xffffff, 0.95))
        }
        drawShip(c, W * 0.3, wy, min(W * 0.34, 300), 2, life: true)
        foreWave(c, wy + 4, 0, W)
        for i in 0..<2 {
            let ph = (T * 0.5 + Double(i) * 0.4).truncatingRemainder(dividingBy: 1)
            let dx = W * 0.52 + Double(i) * 34 + ph * 30, base = wy + 18
            if ph < 0.55 {
                let k = ph / 0.55
                c.save(); c.translate(dx, base - sin(k * PI) * 30); c.rotate(-0.9 + k * 1.8)
                c.ell(0, 0, 14, 4.5, Col(0x5a7a94)); c.ell(2, 1.5, 10, 2.4, Col(0xcfe0ea)); c.poly(Col(0x4a6a84), [-2, -4, 3, -10, 5, -4]); c.poly(Col(0x4a6a84), [-13, 0, -20, -5, -19, 5])
                c.restore()
            }
        }
        }
        let tx = splash != nil ? W * 0.5 : W * 0.68
        let ty = splash != nil ? H * 0.25 : H * 0.27
        let bx = splash != nil ? W * 0.77 : tx
        let by0 = splash != nil ? H * 0.5 - 56 : ty
        // the name, lifting on the swell, with light running across it
        let lift = sin(T * 1.3) * 2
        c.glow(tx, ty - 14 + lift, 230, Col(0xffd257, 0.14 + 0.05 * sin(T * 2)), Col(0xffd257, 0))
        c.text("FAR HORIZON", tx + 2, ty + 3 + lift, 50, splash != nil ? Col(0x3a1408, 0.9) : Col(0x000000, 0.55), 0, FONTD)
        c.text("FAR HORIZON", tx, ty + lift, 50, GOLD, 0, FONTD)
        let tw = textW("FAR HORIZON", 50, FONTD)
        let sw = ((T * 0.35).truncatingRemainder(dividingBy: 1)) * (tw + 200) - 100
        // only the letters catch the light: the name is drawn again, brighter, through a moving slit
        c.save()
        c.clipRect(tx - tw / 2 + sw - 16, ty - 46 + lift, 34, 60)
        c.text("FAR HORIZON", tx, ty + lift, 50, Col(0xfffbe8), 0, FONTD)
        c.restore()
        c.R(tx - tw / 2, ty + 12 + lift, tw * min(1, T / 1.2), 2, Col(0xd2a455, 0.8))
        c.textS("Choose a ship. Stock the hold. Reach Santa Aurelia.", tx, ty + 36, 16, CREAM, 0, FONTI)
        if hasSave {
            btn(c, bx - 130, by0 + 56, 260, 50, "Continue voyage", saveLine, gold: true, size: 19) { [unowned self] in
                if !self.loadGame() { self.clearSave() }
            }
            btn(c, bx - 130, by0 + 114, 260, 40, "New voyage", size: 16) { [unowned self] in
                self.newGame()
                self.mode = .pick
            }
        } else {
            btn(c, bx - 110, by0 + 60, 220, 52, "New voyage", gold: true, size: 20) { [unowned self] in
                self.newGame()
                self.mode = .pick
            }
        }
    }

    // ---------- choosing a ship
    func drawPick(_ c: Canvas) {
        drawSea(c, H * 0.5)
        c.R(0, 0, W, H, Col(0x0a1420, 0.45))
        c.textS("Choose your ship", W / 2, 40, 28, GOLD, 0, FONTD)
        let gap = 12.0
        let cw = (W - safeL - safeR - gap * 2) / 3
        let cy = 56.0, ch = H - cy - safeB - 6
        for (i, sh) in SHIPS.enumerated() {
            let x = safeL + Double(i) * (cw + gap)
            panel(c, x, cy, cw, ch)
            c.save()
            c.clipRect(x + 6, cy + 6, cw - 12, ch * 0.5)
            c.vfill(x + 6, cy + 6, cw - 12, ch * 0.5, [(0, Col(0x6fb4e8)), (0.62, Col(0xcfeaf6)), (0.63, Col(0x2b7fb8)), (1, Col(0x134a78))])
            drawShip(c, x + cw / 2 - 8, cy + ch * 0.36, min(cw * 0.62, 150) * sh.len, sh.masts)
            c.restore()
            var y = cy + ch * 0.5 + 26
            c.text(sh.name, x + cw / 2, y, 22, GOLD, 0, FONTD)
            y += 18
            c.text(sh.desc, x + cw / 2, y, 13, CREAM, 0, FONTI)
            y += 14
            let stats: [(String, Double)] = [("Speed", sh.speed / 1.3), ("Hold", Double(sh.hold) / 320), ("Hull", Double(sh.hull) / 140), ("Crew", Double(sh.crew) / 14)]
            for st in stats {
                c.text(st.0, x + 16, y + 9, 12, CREAM, -1, FONT)
                c.RR(x + 60, y + 1, cw - 78, 8, 4, Col(0x000000, 0.45))
                c.RR(x + 60, y + 1, (cw - 78) * clampD(st.1, 0, 1), 8, 4, GOLD2)
                y += 15
            }
            icon(c, "gold", x + cw / 2 - 22, cy + ch - 20, 18)
            c.text("\(sh.cost)", x + cw / 2 - 8, cy + ch - 14, 18, CREAM, -1, FONTB)
            hits.append(Hit(x: x, y: cy, w: cw, h: ch, act: { [unowned self] in self.chooseShip(i) }))
        }
    }

    // ---------- the market, at the start and in every port
    func drawMarket(_ c: Canvas) {
        drawSea(c, H * 0.5)
        c.R(0, 0, W, H, Col(0x0a1420, 0.5))
        let px = safeL, py = 38.0, pw = W - safeL - safeR, ph = H - py - safeB - 2
        panel(c, px, py, pw, ph)
        c.text(marketPort ? "Market — " + here.n : "Stock the hold", px + 20, py + 32, 22, GOLD, -1, FONTD)
        let used = holdUsed
        c.text("Hold \(used) / \(holdMax)", px + pw - 20, py + 30, 15, used >= holdMax ? Col(0xffb0a0) : CREAM, 1, FONT)
        let colW = (pw - 40 - 12) / 2
        let rowH = min(48.0, (ph - 44 - 62) / 3)
        for (i, g) in GOODS.enumerated() {
            let col = i % 2, row = i / 2
            let x = px + 20 + Double(col) * (colW + 12), y = py + 44 + Double(row) * (rowH + 4)
            c.RR(x, y, colW, rowH, 9, Col(0x000000, 0.28))
            icon(c, g.k, x + 22, y + rowH / 2, 26)
            c.text(g.n, x + 44, y + rowH / 2 - 1, 16, CREAM, -1, FONT)
            let lacking = marketPort && portLacks().contains(g.k)
            c.text(lacking ? "not sold here" : "\(price(g)) gold each", x + 44, y + rowH / 2 + 14, 11.5, lacking ? Col(0xff9a8a) : CREAM.alpha(0.75), -1, FONTI)
            let bs = min(38.0, rowH - 8)
            let bx = x + colW - bs * 2 - 62
            btn(c, bx, y + (rowH - bs) / 2, bs, bs, "−", size: 22) { [unowned self] in self.sell(g) }
            c.text("\(have(g.k))", bx + bs + 26, y + rowH / 2 + 6, 19, GOLD, 0, FONTB)
            btn(c, bx + bs + 52, y + (rowH - bs) / 2, bs, bs, "+", off: lacking, size: 22) { [unowned self] in self.buy(g) }
        }
        let by = py + ph - 54
        let bw = (pw - 40 - 12) / 2
        btn(c, px + 20, by, bw, 44, "Stock for me", "enough for the first passage") { [unowned self] in self.autoStock() }
        btn(c, px + 20 + bw + 12, by, bw, 44, marketPort ? "Done" : "Cast off", gold: true, size: 18) { [unowned self] in self.leaveMarket() }
    }

    // ---------- sailing
    /// The strip under the top bar: where this leg started, where it ends, and how far along the ship is.
    func drawProgress(_ c: Canvas) {
        let k = clampD(dist / max(1, legLen), 0, 1)
        let dest = STAGES[min(5, leg + 1)][path[min(5, leg + 1)]]
        let fromN = here.n, toN = dest.n
        let bw = min(W * 0.72, 600), bx = (W - bw) / 2, by = 36.0, bh = 44.0
        c.RR(bx + 2, by + 3, bw, bh, 12, Col(0x000000, 0.3))
        c.RRGrad(bx, by, bw, bh, 12, [(0, Col(0x2c1a0c, 0.88)), (1, Col(0x1a0e05, 0.88))])
        c.RRStroke(bx, by, bw, bh, 12, 1.4, Col(0xd2a455, 0.9))
        // names at either end of the track
        let nameW = max(textW(fromN, 12.5, FONTB), textW(toN, 12.5, FONTB)) + 14
        let lx0 = bx + nameW + 14, lx1 = bx + bw - nameW - 14, ly = by + 17
        c.text(fromN, lx0 - 12, ly + 4.5, 12.5, CREAM.alpha(0.75), 1, FONTB)
        c.text(toN, lx1 + 12, ly + 4.5, 12.5, GOLD, -1, FONTB)
        // the track: sailed water behind, open water ahead, a tick for each day's run
        c.RR(lx0, ly - 4, lx1 - lx0, 8, 4, Col(0x0a1a2c))
        c.RRGrad(lx0, ly - 4, max(8, (lx1 - lx0) * k), 8, 4, [(0, Col(0x6fd0ff)), (1, Col(0x2a86c8))])
        let perDay = max(1, dps()) / Double(SUNS)
        var dd = perDay
        while dd < legLen {
            let tx = lx0 + (lx1 - lx0) * dd / legLen
            c.R(tx - 0.5, ly - 4, 1, 8, Col(0xffffff, 0.22))
            dd += perDay
        }
        c.circ(lx0, ly, 5, Col(0x8a6a44)); c.circ(lx0, ly, 2.5, CREAM)
        c.circ(lx1, ly, 6, Col(0xb47a16)); c.circ(lx1, ly, 3.2, Col(0xffe08a))
        c.glow(lx1, ly, 14, Col(0xffd257, 0.35 + 0.2 * sin(T * 3)), Col(0xffd257, 0))
        // your ship on the track
        let sx = lx0 + (lx1 - lx0) * k, sy = ly + sin(T * 2.4) * 1.2
        c.poly(Col(0x6b4423), [sx - 9, sy - 3, sx + 10, sy - 3, sx + 6, sy + 3, sx - 7, sy + 3])
        c.seg(sx, sy - 3, sx, sy - 14, 1.1, Col(0x3b2412))
        c.poly(Col(0xf3ead2), [sx + 0.5, sy - 14, sx + 8, sy - 5, sx + 0.5, sy - 5])
        c.poly(REDC, [sx, sy - 14, sx - 5, sy - 12.5, sx, sy - 11])
        // in words
        let left = Int(max(0, legLen - dist))
        let days = Int((Double(left) / perDay).rounded(.up))
        let line = "Leg \(min(5, leg + 1)) of 5  ·  \(Int(k * 100))% sailed  ·  \(left) leagues to go" + (days > 0 ? ", about \(days) day\(days == 1 ? "" : "s")" : "") + "  ·  " + weatherName
        c.text(line, W / 2, by + bh - 7, 11.5, CREAM.alpha(0.9), 0, FONT)
    }

    /// The cries from the deck as an event unfolds, one after another, over the heads of the crew.
    func drawShouts(_ c: Canvas) {
        if sceneK.isEmpty || play != nil || card != nil { return }
        guard let lines = Game.SHOUTS[sceneK] else { return }
        let gap = max(1.2, (Game.omenSecs(sceneK) - 0.5) / Double(lines.count))
        let pv = camPivot()
        for (i, tx) in lines.enumerated() {
            let t0 = 0.25 + Double(i) * gap
            let age = sceneT - t0
            if age < 0 || age > gap + 0.5 { continue }
            let pq = min(1, age / 0.25)
            let pop = 1 - (1 - pq) * (1 - pq)
            let fade = age > gap ? max(0, 1 - (age - gap) / 0.5) : 1
            let side: Double = i % 2 == 0 ? -1 : 1
            // over the deck, a little to one side then the other
            let anchor = camPt(pv.0 + side * 34, pv.1 - 6)
            let bx = clampD(anchor.0 + side * 60, safeL + 90, W - safeR - 90)
            let by = clampD(anchor.1 - 64 - Double(i % 2) * 16, 112, H - 150)
            let tw = textW(tx, 14, FONTB) + 22
            c.save()
            c.alpha(fade)
            c.translate(bx, by)
            c.scale(0.6 + 0.4 * pop, 0.6 + 0.4 * pop)
            c.rotate(side * -0.04)
            c.RR(-tw / 2 + 1.5, -13 + 2.5, tw, 26, 11, Col(0x000000, 0.3))
            c.RR(-tw / 2, -13, tw, 26, 11, Col(0xfff8e6))
            c.RRStroke(-tw / 2, -13, tw, 26, 11, 1.4, Col(0x3a2412))
            c.poly(Col(0xfff8e6), [-side * 10 - 6, 12, -side * 10 + 6, 12, -side * 22, 26])
            c.text(tx, 0, 5, 14, Col(0x2a1808), 0, FONTB)
            c.restore()
        }
    }
    /// One arm of the kraken: up out of the water, curling over, feeling about.
    func krakenArm(_ c: Canvas, _ x: Double, _ y: Double, _ h: Double, _ ph: Double) {
        let rise = clampD(sceneT / 1.2, 0, 1)
        var px = x, py = y
        let n = 16
        for j in 1...n {
            let f = Double(j) / Double(n)
            let sway = sin(T * 1.6 + ph + f * 3.2) * (8 + f * 34) + sin(T * 0.7 + ph) * 12 * f
            let curl = f > 0.7 ? (f - 0.7) / 0.3 : 0
            let nx = x + sway + curl * curl * 40 * sin(ph * 2 + 1)
            let ny = y - h * rise * (f - curl * curl * 0.28)
            let wd = lerp(26, 5, f)
            c.seg(px, py, nx, ny, wd, Col(0x5a2030))
            c.seg(px + wd * 0.22, py, nx + wd * 0.22, ny, wd * 0.34, Col(0xd8a0a8, 0.8))
            if j % 2 == 0 { c.circ(nx + wd * 0.24, ny, wd * 0.13, Col(0xf6dcdc)) }
            px = nx; py = ny
        }
    }
    /// The point on the ship the camera holds: the middle of the deck, at shoulder height.
    func camPivot() -> (Double, Double) {
        let (sx, swy, slen) = shipSpot()
        return (sx, swy - 40 * slen / 200)
    }
    /// Where a point in the sailing scene lands on the screen.
    func camPt(_ x: Double, _ y: Double) -> (Double, Double) {
        let pv = camPivot()
        return (camFx + (x - pv.0) * camZ, camFy + (y - pv.1) * camZ)
    }
    func drawSail(_ c: Canvas) {
        let hz = H * 0.5
        let wy = hz + (H - hz) * 0.5
        let omen = !omenK.isEmpty && play == nil
        let ok = omen ? min(1, omenT / 0.5) : 0
        let oe = 1 - (1 - ok) * (1 - ok)
        // The camera rides close on the deck, where the crew can be seen at their work. It pulls back
        // only when there is something far off to look at, or a game that needs the whole sea.
        let pv = camPivot()
        let acting = omen || card != nil
        let deckEv = Game.deckScenes.contains(sceneK)
        var zT = 2.6, fxT = W * 0.5, fyT = H * 0.66
        if play != nil || (acting && !sceneK.isEmpty && !deckEv) {
            zT = 1; fxT = pv.0; fyT = pv.1
            if sceneK == "overboard" && play == nil { zT = 1.35; fxT = W * 0.58; fyT = H * 0.6 }
        } else if deckEv && card != nil {
            zT = 3; fyT = H * 0.4
        } else if deckEv && omen {
            zT = 3; fyT = H * 0.55
        }
        if sceneK == "plank" && acting {
            zT = 1.9; fxT = W * 0.66; fyT = card != nil ? H * 0.36 : H * 0.52
        }
        if sceneK == "stelmo" && acting {
            zT = 1.3; fxT = W * 0.5; fyT = H * 0.78
        }
        if sceneK == "bottle" && acting && play == nil {
            // look off the bow, where it is bobbing
            zT = 2.1; fxT = W * 0.26; fyT = card != nil ? H * 0.34 : H * 0.5
        }
        if camFx == 0 { camFx = pv.0 + (fxT - pv.0) * min(1, (camZ - 1) / 1.6); camFy = pv.1 + (fyT - pv.1) * min(1, (camZ - 1) / 1.6) }
        let ck: Double = play != nil ? 1 : 0.07
        camZ += (zT - camZ) * ck
        camFx += (fxT - camFx) * ck
        camFy += (fyT - camFy) * ck
        // the sky and far water move much less than the ship does, so the sun and moon stay in sight
        let zb = 1 + (camZ - 1) * 0.12
        c.save()
        c.translate(pv.0 + (camFx - pv.0) * 0.3, pv.1 + (camFy - pv.1) * 0.3); c.scale(zb, zb); c.translate(-pv.0, -pv.1)
        drawSea(c, hz)
        weatherBack(c, hz)
        seaLifeBack(c, hz, wy)
        c.restore()
        c.save()
        c.translate(camFx, camFy); c.scale(camZ, camZ); c.translate(-pv.0, -pv.1)
        let theme = play?.theme ?? sceneK
        let slenW = min(W * 0.3, 280) * ship.len
        let near = omen && sceneK != "plank" ? min(1, omenT / Game.omenSecs(omenK)) : 1
        if theme == "plank" {
            // the prize, lying astern with her sails clewed up
            drawShip(c, W * 0.42 - slenW * 0.5 - 150, wy - 6, min(W * 0.3, 280) * 0.7, 2, enemy: true, furled: true)
        } else if theme == "pirates" || theme == "blockade" {
            // she comes up from astern, growing as she closes
            drawShip(c, -W * 0.1 + W * 0.2 * near, wy - 14 + 8 * near, min(W * 0.3, 280) * (0.35 + 0.4 * near), theme == "blockade" ? 3 : 2, enemy: true)
        } else if theme == "merchant" {
            drawShip(c, W * 1.05 - W * 0.22 * near, wy - 16, min(W * 0.3, 280) * 0.5, 2, furled: near > 0.8)
        } else if theme == "castaway" || theme == "shark" {
            let rx = W * 1.0 - W * 0.22 * near, ry = wy + 16 + sin(T * 2) * 3
            c.RR(rx - 18, ry, 36, 5, 2, Col(0x8a6a44)); c.seg(rx, ry, rx, ry - 20, 1.5, Col(0x5a3d20)); c.poly(Col(0xe8e0c8), [rx, ry - 20, rx + 11, ry - 16, rx, ry - 12])
            c.circ(rx - 7, ry - 9, 3, Col(0xe3b58a)); c.R(rx - 9, ry - 6, 4, 6, Col(0x8c3b2e)); c.seg(rx - 7, ry - 6, rx - 13, ry - 16 + sin(T * 10) * 3, 1.6, Col(0xe3b58a))
            c.poly(Col(0x3a4650), [rx + 30, ry + 8, rx + 37, ry - 4, rx + 43, ry + 8])
        } else if theme == "bottle" {
            let bx = W * 0.42 + slenW * 0.5 + 120 - 78 * near, byy = wy + 2 + sin(T * 2.4) * 3
            c.ellStroke(bx, byy + 5, 13 + sin(T * 3) * 3, 3, 1, Col(0xffffff, 0.6))
            c.save(); c.translate(bx, byy); c.rotate(0.5 + sin(T * 1.5) * 0.2); c.scale(1.5, 1.5)
            c.RR(-3.5, -9, 7, 14, 3, Col(0x7fc8a0, 0.9)); c.R(-1.5, -14, 3, 6, Col(0x7fc8a0, 0.9)); c.R(-2, -16, 4, 2.5, Col(0x8a6238))
            c.restore()
            c.glow(bx, byy - 6, 26, Col(0xffffff, 0.5 + 0.4 * sin(T * 8)), Col(0xffffff, 0))
        } else if theme == "fish" && omen {
            for i in 0..<7 {
                let gx = W * 0.78 + sin(T * 1.3 + Double(i) * 1.7) * 60, ph = (T * 0.9 + Double(i) * 0.3).truncatingRemainder(dividingBy: 1)
                let gy = hz * 0.5 + ph * (wy + 14 - hz * 0.5)
                c.curve(gx - 7, gy - 2, gx - 3, gy - 6, gx, gy, 1.4, WHITE); c.curve(gx, gy, gx + 3, gy - 6, gx + 7, gy - 2, 1.4, WHITE)
                if ph > 0.9 { c.ellStroke(gx, wy + 16, 9, 3, 1.2, Col(0xffffff, 0.7)) }
            }
        } else if theme == "comet" {
            // it comes down the sky trailing fire, and strikes
            let k = clampD(sceneT / 2.2, 0, 1)
            let hx = lerp(W * 0.25, W * 0.82, k), hy = lerp(-20, wy - 6, k * k)
            if k < 1 {
                for j in 0..<14 {
                    let f = Double(j) / 14
                    c.circ(hx - (hx - W * 0.25) * f * 0.5, hy - (hy + 20) * f * 0.5, 7 * (1 - f) + 1, Col(0xffd257, 0.7 * (1 - f)))
                }
                c.glow(hx, hy, 60, Col(0xfff2c0, 0.9), Col(0xffb040, 0))
                c.circ(hx, hy, 6, WHITE)
            } else {
                let r = clampD((sceneT - 2.2) / 1.2, 0, 1)
                for j in 0..<11 { let a = -PI / 2 + (Double(j) - 5) * 0.2; c.seg(W * 0.82, wy - 4, W * 0.82 + cos(a) * 90 * sin(r * PI), wy - 4 + sin(a) * 120 * sin(r * PI), 3, Col(0xffffff, 0.85 * (1 - r))) }
                c.ellStroke(W * 0.82, wy + 2, 20 + r * 80, 4 + r * 8, 2, Col(0xffffff, 0.7 * (1 - r)))
                // what is left of it, smoking on the water
                c.ell(W * 0.82, wy - 1 + sin(T * 2) * 1.5, 9, 5, Col(0x1a1418)); c.circ(W * 0.82 - 2, wy - 3 + sin(T * 2) * 1.5, 2, Col(0xff6a18, 0.6 + 0.4 * sin(T * 6)))
                for j in 0..<5 { let ph = (T * 0.5 + Double(j) / 5).truncatingRemainder(dividingBy: 1); c.circ(W * 0.82 + sin(T + Double(j)) * 5 + ph * 14, wy - 8 - ph * 50, 4 + ph * 9, Col(0xd0d0d0, 0.45 * (1 - ph))) }
            }
        } else if theme == "kraken" {
            // the arms on the far side of her
            krakenArm(c, W * 0.42 - slenW * 0.3, wy + 6, 150, 0.0)
            krakenArm(c, W * 0.42 + slenW * 0.34, wy + 6, 170, 2.1)
        } else if theme == "whale" || theme == "whitewhale" {
            // she comes up out of the sea beside the ship, hangs, and goes back in
            let wx = W * 0.8, base = wy + 10
            let ph = (sceneT * 0.3).truncatingRemainder(dividingBy: 1)
            let up = sin(min(1, ph / 0.62) * PI)
            c.save()
            c.translate(wx - ph * 30, base - up * 58)
            c.rotate(-1.0 + min(1, ph / 0.62) * 1.9)
            let white = theme == "whitewhale"
            let wBody = white ? Col(0xeef2f4) : Col(0x24303a), wFin = white ? Col(0xcfd8dc) : Col(0x1c262e), wBelly = white ? Col(0xffffff) : Col(0xc8d4da)
            if white { for g in 0..<4 { c.seg(-30 + Double(g) * 22, -14, -22 + Double(g) * 22, -4, 1.2, Col(0x9aa6ac)) } }
            c.ell(0, 0, 74, 20, wBody); c.ell(8, 8, 60, 10, wBelly)
            for g in 0..<5 { c.seg(18 + Double(g) * 8, 6, 26 + Double(g) * 8, 14, 0.8, Col(0x8a98a0)) }
            c.circ(48, -3, 2.2, Col(0x0c1014)); c.circ(48.6, -3.6, 0.7, WHITE)
            c.poly(wFin, [10, 10, 30, 34, 34, 12])
            c.poly(wBody, [-70, 0, -98, -20, -90, 0, -98, 20])
            c.restore()
            if ph < 0.12 || (ph > 0.55 && ph < 0.8) {
                let k: Double = ph < 0.12 ? ph / 0.12 : (ph - 0.55) / 0.25
                for g in 0..<9 { let a = -PI / 2 + (Double(g) - 4) * 0.2; c.seg(wx + cos(a) * 20, base + sin(a) * 10, wx + cos(a) * (30 + 60 * k), base + sin(a) * (20 + 70 * k * (1 - k) * 2), 2.4, Col(0xffffff, 0.8 * (1 - k))) }
                c.ellStroke(wx, base + 4, 40 + k * 70, 6 + k * 6, 2, Col(0xffffff, 0.7 * (1 - k)))
            }
            if ph > 0.8 {
                let k = (ph - 0.8) / 0.2
                for g in 0..<6 { let a = -PI / 2 + (Double(g) - 2.5) * 0.14; c.seg(wx - 40, base - 2, wx - 40 + cos(a) * 46 * sin(k * PI), base - 2 + sin(a) * 52 * sin(k * PI), 1.8, Col(0xffffff, 0.8 * (1 - k))) }
                c.ell(wx - 30, base, 44, 7, wBody)
            }
        } else if theme == "spout" {
            // a rope of water from the cloud to the sea, writhing as it comes
            let cx = W * 1.02 - W * 0.24 * near
            let top = hz * 0.12, bot = wy - 2
            c.ell(cx, top, 150, 26, Col(0x2a3038, 0.85)); c.ell(cx - 60, top + 8, 90, 18, Col(0x3a424c, 0.8)); c.ell(cx + 70, top + 6, 100, 20, Col(0x343c46, 0.8))
            var px = cx, py = top
            for j in 1...16 {
                let f = Double(j) / 16
                let ny = lerp(top, bot, f)
                let nx = cx + sin(T * 2.4 + f * 5) * (6 + f * 26) + sin(T * 1.1 + f * 2) * 10
                let wd = lerp(46, 9, sqrt(f))
                c.seg(px, py, nx, ny, wd, Col(0x56626e, 0.8))
                c.seg(px - wd * 0.2, py, nx - wd * 0.2, ny, wd * 0.3, Col(0xaab8c4, 0.45))
                px = nx; py = ny
            }
            for g in 0..<12 {
                let ph2 = (T * 1.4 + Double(g) / 12).truncatingRemainder(dividingBy: 1)
                let a = Double(g) * 0.52
                c.circ(px + cos(a) * (10 + ph2 * 46), bot - sin(ph2 * PI) * (10 + hashN(Double(g)) * 22), 3 + ph2 * 5, Col(0xffffff, 0.7 * (1 - ph2)))
            }
            c.ellStroke(px, bot + 4, 40 + sin(T * 5) * 6, 6, 2, Col(0xffffff, 0.6))
        } else if theme == "overboard" {
            let mx = W * 0.42 - min(W * 0.3, 280) * ship.len * 0.5 - 30 - 40 * near, my = wy + 22 + sin(T * 3) * 3
            c.ellStroke(mx, my + 4, 16 + sin(T * 4) * 3, 4, 1.2, Col(0xffffff, 0.7))
            c.circ(mx, my - 4, 5, Col(0xe3b58a))
            c.seg(mx - 3, my, mx - 10, my - 12 + sin(T * 9) * 3, 2.2, Col(0xe3b58a)); c.seg(mx + 3, my, mx + 10, my - 12 - sin(T * 9) * 3, 2.2, Col(0xe3b58a))
        }
        if theme == "wreck" {
            // the broken hull you are picking over
            c.save()
            c.translate(W * 0.74, wy - 4 + sin(T * 1.1) * 3)
            c.rotate(0.22 + sin(T * 0.8) * 0.03)
            c.poly(Col(0x3f2613), [-70, -6, 50, -22, 66, 6, -60, 12])
            c.seg(-10, -12, 6, -74, 4, Col(0x2a1a0c)); c.seg(-4, -44, 30, -52, 3, Col(0x2a1a0c))
            c.poly(Col(0xcdbf9c, 0.7), [0, -70, 26, -52, 4, -40])
            c.restore()
        } else if theme == "ghost" {
            c.save()
            c.alpha(0.55 + 0.12 * sin(T * 1.7))
            drawShip(c, W * 0.76, wy - 8, min(W * 0.26, 240), 3, enemy: true, furled: true)
            c.restore()
            c.glow(W * 0.76, wy - 70, 150, Col(0x9fffd0, 0.16), Col(0x9fffd0, 0))
        } else if theme == "island" {
            c.pathFill(Col(0xe6d39a)) { p in
                p.move(to: CGPoint(x: W * 0.56, y: wy + 30))
                p.addQuadCurve(to: CGPoint(x: W + 10, y: wy - 26), control: CGPoint(x: W * 0.78, y: wy - 34))
                p.addLine(to: CGPoint(x: W + 10, y: H))
                p.addLine(to: CGPoint(x: W * 0.5, y: H))
                p.closeSubpath()
            }
            for i in 0..<3 {
                let px = W * (0.72 + Double(i) * 0.09), sw = sin(T * 1.2 + Double(i)) * 3
                c.curve(px, wy - 14, px + 4 + sw * 0.5, wy - 50, px + 8 + sw, wy - 84, 4, Col(0x6b4a26))
                for a in [-2.5, -1.8, -1.0, -0.3, 0.4] { c.curve(px + 8 + sw, wy - 84, px + 8 + sw + cos(a) * 22, wy - 90 + sin(a) * 20, px + 8 + sw + cos(a) * 40, wy - 76 + sin(a) * 28, 4.5, Col(0x3f7a3c)) }
            }
        }
        drawShip(c, W * 0.42, wy, min(W * 0.3, 280) * ship.len, ship.masts, life: true)
        foreWave(c, wy + 5, 0, W)
        seaLifeFront(c, hz, wy)
        if theme == "kraken" {
            // and the arms on this side, over her deck
            krakenArm(c, W * 0.42 - slenW * 0.08, wy + 14, 190, 1.0)
            krakenArm(c, W * 0.42 + slenW * 0.14, wy + 14, 150, 3.3)
            krakenArm(c, W * 0.42 - slenW * 0.52, wy + 12, 120, 4.4)
            for j in 0..<8 { let ph = (T * 0.8 + Double(j) / 8).truncatingRemainder(dividingBy: 1); c.ellStroke(W * 0.42 + (hashN(Double(j) * 3) - 0.5) * slenW * 1.3, wy + 14, 10 + ph * 30, 2 + ph * 4, 1.5, Col(0xffffff, 0.6 * (1 - ph))) }
        }
        c.restore()
        if sceneK == "stelmo" && play == nil { c.R(0, 0, W, H, Col(0x050a24, 0.42)) }
        drawShouts(c)
        if card == nil && chance(0.5) {
            let bw = camPt(W * 0.42 + min(W * 0.3, 280) * ship.len * 0.5, wy + 2)
            puff(bw.0, bw.1, 1, Col(0xffffff, 0.8), (40 + rough * 60) * camZ, 120, 2.2 * camZ, 0.5)
        }
        weatherFront(c, hz)
        let L = light()
        if L.night > 0.05 { c.R(0, 0, W, H, Col(0x04081a, 0.25 * L.night)) }
        if play != nil {
            drawPlay(c)
            return
        }
        if omen {
            // black bars close in top and bottom, and a line says what the lookout has seen
            let bar = 44 * oe
            c.R(0, 0, W, 30 + bar * 0.4, Col(0x000000, 0.0))
            c.vfill(0, H - 76 * oe - safeB, W, 76 * oe + safeB, [(0, Col(0x000000, 0)), (0.35, Col(0x000000, 0.72)), (1, Col(0x000000, 0.86))])
            c.vfill(0, 30, W, 40 * oe, [(0, Col(0x000000, 0.5 * oe)), (1, Col(0x000000, 0))])
            let om = Game.OMENS[omenK] ?? ("", "")
            let ta = clampD((omenT - 0.25) / 0.4, 0, 1)
            c.save()
            c.alpha(ta)
            c.textS(om.0, W / 2 - 16 * (1 - ta), H - safeB - 38, 26, GOLD, 0, FONTD)
            c.textS(om.1, W / 2 + 16 * (1 - ta), H - safeB - 14, 15, CREAM, 0, FONTI)
            c.restore()
            if Game.omenHold { omenT = min(omenT, 1.7) }
            return
        }
        drawProgress(c)
        if sceneK.isEmpty { c.textS(lifeCaption(), W / 2, 96, 12.5, CREAM.alpha(0.92), 0, FONTI) }
        let bw = 172.0, by = H - safeB - 50
        btn(c, W / 2 - bw - 6, by, bw, 44, half ? "Rations: half" : "Rations: full", half ? "saves food, risks sickness" : "tap to halve") { [unowned self] in
            self.half = !self.half
        }
        btn(c, W / 2 + 6, by, bw, 44, "Stop and fish", bait > 0 ? "lose \(SUNS) days · \(bait) bait" : "no bait", off: bait < 1) { [unowned self] in
            self.passDays(1)
            if self.over { return }
            self.playFish()
        }
        // what each button means, drawn on it: a pie, whole or cut in half; a fish on the hook
        let pxc = W / 2 - bw - 6 + 24, pyc = by + 22
        c.ell(pxc, pyc + 9, 13, 3, Col(0x000000, 0.25))
        c.circ(pxc, pyc, 12.5, Col(0xe8e0cc)); c.circStroke(pxc, pyc, 12.5, 1, Col(0x8a7a5a))
        if half {
            c.arcFill(pxc, pyc, 10, PI / 2, PI * 1.5, Col(0xc98a3a)); c.arcFill(pxc, pyc, 7.5, PI / 2, PI * 1.5, Col(0xe8b860))
            c.seg(pxc, pyc - 10, pxc, pyc + 10, 1.2, Col(0x8a1a1a))
            for j in 0..<3 { c.circ(pxc + 4 + Double(j) * 2.5, pyc + 3 - Double(j % 2) * 5, 0.9, Col(0xc98a3a)) }
        } else {
            c.circ(pxc, pyc, 10, Col(0xc98a3a)); c.circ(pxc, pyc, 7.5, Col(0xe8b860))
            for j in 0..<4 { let a = Double(j) * PI / 2 + 0.4; c.seg(pxc + cos(a) * 2, pyc + sin(a) * 2, pxc + cos(a) * 6, pyc + sin(a) * 6, 1, Col(0x8a5a2c)) }
            for j in 0..<2 { let ph = (T * 0.6 + Double(j) * 0.5).truncatingRemainder(dividingBy: 1); c.curve(pxc - 3 + Double(j) * 6, pyc - 9 - ph * 8, pxc - 1 + Double(j) * 6, pyc - 13 - ph * 8, pxc - 3 + Double(j) * 6, pyc - 17 - ph * 8, 1, Col(0xffffff, 0.6 * (1 - ph))) }
        }
        let fxc = W / 2 + 6 + 24, swing = sin(T * 2.4) * 0.3
        c.save(); c.translate(fxc, by + 8); c.rotate(swing)
        if bait < 1 { c.alpha(0.45) }
        c.seg(0, 0, 0, 14, 0.9, Col(0xfff6d8)); c.arcStroke(0, 16, 2.2, 0, PI, 1, Col(0xc8c8cc))
        c.ell(1, 22, 4.2, 8, Col(0x6fb0d8)); c.ell(2.2, 22, 2, 6, Col(0xdfeaf2)); c.poly(Col(0x4a8ab0), [1, 29, -4, 35, 6, 35]); c.circ(0.5, 17.5, 0.9, Col(0x0c1014))
        c.restore()
    }

    // ---------- the end
    func drawEnd(_ c: Canvas) {
        let hz = H * 0.56
        drawSea(c, hz)
        let wy = hz + (H - hz) * 0.42
        if hull > 0 { drawShip(c, W * 0.22, wy, 220, ship.masts, furled: won, life: !won) }
        foreWave(c, wy + 4, 0, W)
        if won { c.glow(W * 0.25, hz * 0.4, 260, Col(0xffd257, 0.12 + 0.05 * sin(T * 2)), Col(0xffd257, 0)) }
        let pw = min(W * 0.58, 500), px = W - safeR - pw - 10, py = 30.0
        let lines = wrapText(endText, pw - 40, 15.5, FONT)
        let recent = Array(log.suffix(4))
        let ph = min(H - 44, 60 + Double(lines.count) * 20 + 50 + Double(recent.count) * 16 + 70)
        panel(c, px, py, pw, ph)
        c.text(endTitle, px + 20, py + 36, 26, won ? GOLD : Col(0xff9a8a), -1, FONTD)
        c.R(px + 20, py + 44, (pw - 40) * min(1, T.truncatingRemainder(dividingBy: 1000) / 1.0), 1.5, Col(0xd2a455, 0.7))
        var y = py + 66
        for l in lines {
            c.text(l, px + 20, y, 15.5, CREAM, -1, FONT)
            y += 20
        }
        // the voyage in four numbers
        let stats: [(String, String)] = [("day", "\(cal) days"), ("gold", "\(gold) gold"), ("crew", "\(crew) hands"), ("arms", "\(fights) fights")]
        let cw = (pw - 40 - 18) / 4
        for (i, st) in stats.enumerated() {
            let sx = px + 20 + Double(i) * (cw + 6)
            c.RR(sx, y, cw, 30, 8, Col(0x1c1108, 0.7)); c.RRStroke(sx, y, cw, 30, 8, 1, Col(0xd2a455, 0.45))
            icon(c, st.0, sx + 15, y + 15 + sin(T * 3 + Double(i)) * 1.2, 17)
            c.text(st.1, sx + 28, y + 20, 12.5, CREAM, -1, FONTB)
        }
        y += 46
        for l in recent {
            c.text(l, px + 20, y, 12, CREAM.alpha(0.7), -1, FONTI)
            y += 16
        }
        btn(c, px + 20, py + ph - 56, pw - 40, 46, "Sail again", gold: true, size: 18) { [unowned self] in
            self.newGame()
            self.mode = .title
        }
    }
}
