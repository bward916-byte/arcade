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
        let hz = H * 0.56
        drawSea(c, hz)
        let wy = hz + (H - hz) * 0.42
        drawShip(c, W * 0.3, wy, min(W * 0.34, 300), 2)
        foreWave(c, wy + 4, 0, W)
        let tx = W * 0.68
        c.text("FAR HORIZON", tx + 2, H * 0.3 + 3, 50, Col(0x000000, 0.55), 0, FONTD)
        c.text("FAR HORIZON", tx, H * 0.3, 50, GOLD, 0, FONTD)
        c.textS("Choose a ship. Stock the hold. Reach Santa Aurelia.", tx, H * 0.3 + 30, 16, CREAM, 0, FONTI)
        btn(c, tx - 110, H * 0.3 + 56, 220, 52, "New voyage", gold: true, size: 20) { [unowned self] in
            self.newGame()
            self.mode = .pick
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
            c.text("\(price(g)) gold each", x + 44, y + rowH / 2 + 14, 11.5, CREAM.alpha(0.75), -1, FONTI)
            let bs = min(38.0, rowH - 8)
            let bx = x + colW - bs * 2 - 62
            btn(c, bx, y + (rowH - bs) / 2, bs, bs, "−", size: 22) { [unowned self] in self.sell(g) }
            c.text("\(have(g.k))", bx + bs + 26, y + rowH / 2 + 6, 19, GOLD, 0, FONTB)
            btn(c, bx + bs + 52, y + (rowH - bs) / 2, bs, bs, "+", size: 22) { [unowned self] in self.buy(g) }
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

    func drawSail(_ c: Canvas) {
        let hz = H * 0.5
        let wy = hz + (H - hz) * 0.5
        let omen = !omenK.isEmpty && play == nil
        let ok = omen ? min(1, omenT / 0.5) : 0
        let oe = 1 - (1 - ok) * (1 - ok)
        // the view eases in toward the ship as something comes into sight
        c.save()
        if omen {
            let z = 1 + 0.07 * oe + 0.02 * min(1, omenT / Game.omenLen)
            c.translate(W * 0.45, wy - 20); c.scale(z, z); c.translate(-W * 0.45, -(wy - 20))
        }
        drawSea(c, hz)
        weatherBack(c, hz)
        let theme = play?.theme ?? (omen ? omenK : "")
        let near = omen ? min(1, omenT / Game.omenLen) : 1
        if theme == "pirates" || theme == "blockade" {
            // she comes up from astern, growing as she closes
            drawShip(c, -W * 0.1 + W * 0.2 * near, wy - 14 + 8 * near, min(W * 0.3, 280) * (0.35 + 0.4 * near), theme == "blockade" ? 3 : 2, enemy: true)
        } else if theme == "merchant" {
            drawShip(c, W * 1.05 - W * 0.22 * near, wy - 16, min(W * 0.3, 280) * 0.5, 2, furled: near > 0.8)
        } else if theme == "castaway" {
            let rx = W * 1.0 - W * 0.22 * near, ry = wy + 16 + sin(T * 2) * 3
            c.RR(rx - 18, ry, 36, 5, 2, Col(0x8a6a44)); c.seg(rx, ry, rx, ry - 20, 1.5, Col(0x5a3d20)); c.poly(Col(0xe8e0c8), [rx, ry - 20, rx + 11, ry - 16, rx, ry - 12])
            c.circ(rx - 7, ry - 9, 3, Col(0xe3b58a)); c.R(rx - 9, ry - 6, 4, 6, Col(0x8c3b2e)); c.seg(rx - 7, ry - 6, rx - 13, ry - 16 + sin(T * 10) * 3, 1.6, Col(0xe3b58a))
            c.poly(Col(0x3a4650), [rx + 30, ry + 8, rx + 37, ry - 4, rx + 43, ry + 8])
        } else if theme == "bottle" {
            let bx = W * 0.95 - W * 0.26 * near, byy = wy + 22 + sin(T * 2.4) * 3
            c.save(); c.translate(bx, byy); c.rotate(0.5 + sin(T * 1.5) * 0.2)
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
        seaLifeBack(c, hz, wy)
        drawShip(c, W * 0.42, wy, min(W * 0.3, 280) * ship.len, ship.masts, life: true)
        foreWave(c, wy + 5, 0, W)
        seaLifeFront(c, hz, wy)
        if card == nil && chance(0.5) { puff(W * 0.42 + min(W * 0.3, 280) * ship.len * 0.5, wy + 2, 1, Col(0xffffff, 0.8), 40 + rough * 60, 120, 2.2, 0.5) }
        weatherFront(c, hz)
        let L = light()
        if L.night > 0.05 { c.R(0, 0, W, H, Col(0x04081a, 0.25 * L.night)) }
        c.restore()
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
        c.textS(lifeCaption(), W / 2, 96, 12.5, CREAM.alpha(0.92), 0, FONTI)
        let bw = 150.0, by = H - safeB - 50
        btn(c, W / 2 - bw - 6, by, bw, 44, half ? "Rations: half" : "Rations: full", half ? "saves food, risks sickness" : "tap to halve") { [unowned self] in
            self.half = !self.half
        }
        btn(c, W / 2 + 6, by, bw, 44, "Stop and fish", bait > 0 ? "lose \(SUNS) days · \(bait) bait" : "no bait", off: bait < 1) { [unowned self] in
            self.passDays(1)
            if self.over { return }
            self.playFish()
        }
    }

    // ---------- the end
    func drawEnd(_ c: Canvas) {
        let hz = H * 0.56
        drawSea(c, hz)
        let wy = hz + (H - hz) * 0.42
        if hull > 0 { drawShip(c, W * 0.24, wy, 220, ship.masts) }
        foreWave(c, wy + 4, 0, W)
        let pw = min(W * 0.56, 480), px = W - safeR - pw - 10, py = 30.0
        let lines = wrapText(endText, pw - 40, 16, FONT)
        let ph = 60 + Double(lines.count) * 21 + 66
        panel(c, px, py, pw, ph)
        c.text(endTitle, px + 20, py + 36, 26, GOLD, -1, FONTD)
        var y = py + 64
        for l in lines {
            c.text(l, px + 20, y, 16, CREAM, -1, FONT)
            y += 21
        }
        btn(c, px + 20, py + ph - 58, pw - 40, 46, "Sail again", gold: true, size: 18) { [unowned self] in
            self.newGame()
            self.mode = .title
        }
    }
}
