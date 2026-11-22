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
        case .duel: duel?.draw(c, self)
        case .end: drawEnd(c)
        }
        drawSparks(c)
        c.restore()
        if mode != .title && mode != .pick && mode != .end { drawHUD(c) }
        if let cd = card { drawCard(c, cd) }
        drawToast(c)
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
            let mx = W * 0.72, my = hz * 0.28
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
        c.pathFill(Col.mix(L.sea1, L.sea2, 0.45)) { p in
            var x = x0
            p.move(to: CGPoint(x: x0, y: y + 60))
            while x <= x1 {
                p.addLine(to: CGPoint(x: x, y: y + sin(x * 0.03 + ph + T * 1.4) * 3.5 + sin(x * 0.011 - T) * 2))
                x += 8
            }
            p.addLine(to: CGPoint(x: x1, y: y + 60))
            p.closeSubpath()
        }
        c.pathStroke(Col(0xffffff, 0.55), 1.6) { p in
            var x = x0
            p.move(to: CGPoint(x: x, y: y + sin(x * 0.03 + ph + T * 1.4) * 3.5 + sin(x * 0.011 - T) * 2))
            while x <= x1 {
                x += 8
                p.addLine(to: CGPoint(x: x, y: y + sin(x * 0.03 + ph + T * 1.4) * 3.5 + sin(x * 0.011 - T) * 2))
            }
        }
    }

    /// A ship seen from the side, bow to the right. (x, wy) is the middle of her waterline; len is her length.
    func drawShip(_ c: Canvas, _ x: Double, _ wy: Double, _ len: Double, _ masts: Int, enemy: Bool = false, furled: Bool = false) {
        let u = len / 200
        let L = light()
        let dark = 1 - L.night * 0.45
        let bob = sin(T * 1.3 + x * 0.01) * 2.5 * u
        c.save()
        c.translate(x, wy + bob)
        c.rotate(sin(T * 0.9 + x * 0.02) * 0.018)
        c.scale(u, u)
        let hullC = (enemy ? Col(0x2a2228) : Col(0x6b4423)).shade(dark)
        let hullD = (enemy ? Col(0x15101a) : Col(0x3f2613)).shade(dark)
        let trim = (enemy ? Col(0x8a1a1a) : Col(0xd9a441)).shade(dark)
        let sail = (enemy ? Col(0x8a1f1f) : Col(0xf3ead2)).shade(dark)
        let sailD = (enemy ? Col(0x5a1010) : Col(0xcdbf9c)).shade(dark)
        let spar = Col(0x3b2412).shade(dark)
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
                }
            }
            // a pennant at each masthead
            let fl = sin(T * 5 + Double(i)) * 3
            c.poly(enemy ? Col(0x111111) : REDC, [m + 2.5, -30 - tall, m + 26, -30 - tall + 5 + fl, m + 2.5, -30 - tall + 10])
        }
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
        c.R(-98, -24, 186, 3, trim)
        c.R(-100, -52, 40, 3, trim)
        c.R(-58, -33, 130, 2.5, hullD)
        for i in 0..<6 {
            let gx = -50 + Double(i) * 22
            c.R(gx, -17, 8, 7, hullD)
            c.R(gx, -17, 8, 1.5, trim.alpha(0.7))
        }
        let lit = L.night > 0.3 ? Col(0xffd257) : Col(0xf0c860).shade(0.85)
        c.R(-96, -44, 7, 8, lit); c.R(-84, -44, 7, 8, lit); c.R(-72, -44, 7, 8, lit)
        // lantern at the stern
        c.seg(-100, -52, -104, -66, 1.5, spar)
        c.circ(-104, -68, 3.5, Col(0xffd257))
        if L.night > 0.2 { c.glow(-104, -68, 34, Col(0xffc060, 0.5 * L.night), Col(0xffc060, 0)) }
        // a few hands on deck
        for i in 0..<4 {
            let px = -40 + Double(i) * 26 + sin(T * 0.6 + Double(i) * 2) * 6
            c.R(px - 2, -42, 4, 9, [Col(0x2f5f8f), Col(0x8c3b2e), Col(0xd9cdb0), Col(0x3a7a6d)][i].shade(dark))
            c.circ(px, -45, 2.6, Col(0xe3b58a).shade(dark))
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
        btn(c, px + 20, by, bw, 44, "Stock for me", "about ten days of supplies") { [unowned self] in self.autoStock() }
        btn(c, px + 20 + bw + 12, by, bw, 44, marketPort ? "Done" : "Cast off", gold: true, size: 18) { [unowned self] in self.leaveMarket() }
    }

    // ---------- sailing
    func drawSail(_ c: Canvas) {
        let hz = H * 0.5
        drawSea(c, hz)
        let wy = hz + (H - hz) * 0.5
        drawShip(c, W * 0.42, wy, min(W * 0.3, 280) * ship.len, ship.masts)
        foreWave(c, wy + 5, 0, W)
        if card == nil && chance(0.5) { puff(W * 0.42 + min(W * 0.3, 280) * ship.len * 0.5, wy + 2, 1, Col(0xffffff, 0.8), 40, 120, 2.2, 0.5) }
        let L = light()
        if L.night > 0.05 { c.R(0, 0, W, H, Col(0x04081a, 0.25 * L.night)) }
        // the leg, as a line with the ship on it
        let lx0 = W * 0.2, lx1 = W * 0.8, ly = 46.0
        let k = clampD(dist / max(1, legLen), 0, 1)
        c.dash(4, 5)
        c.seg(lx0, ly, lx1, ly, 1.5, Col(0xfff6d8, 0.7))
        c.noDash()
        c.seg(lx0, ly, lx0 + (lx1 - lx0) * k, ly, 2.5, Col(0xef4a36))
        c.circ(lx0, ly, 4, Col(0xef4a36)); c.circ(lx1, ly, 4.5, Col(0xfff6d8))
        let shipX = lx0 + (lx1 - lx0) * k
        c.poly(Col(0xfff6d8), [shipX - 6, ly - 6, shipX + 7, ly, shipX - 6, ly + 6])
        let dest = STAGES[min(5, leg + 1)][path[min(5, leg + 1)]]
        c.textS(dest.n + " — \(Int(max(0, legLen - dist))) leagues", W / 2, ly + 20, 14, CREAM, 0, FONT)
        let bw = 150.0, by = H - safeB - 50
        btn(c, W / 2 - bw - 6, by, bw, 44, half ? "Rations: half" : "Rations: full", half ? "saves food, risks sickness" : "tap to halve") { [unowned self] in
            self.half = !self.half
        }
        btn(c, W / 2 + 6, by, bw, 44, "Stop and fish", bait > 0 ? "lose a day · \(bait) bait" : "no bait", off: bait < 1) { [unowned self] in
            self.passDays(1)
            if self.over { return }
            let used = min(3, self.bait)
            self.bait -= used
            let got = self.addGood("food", Int(Double(used * rndI(3, 6)) * (1 + 0.2 * self.E("fish"))))
            self.snd?.splash()
            self.toast(got > 0 ? "A day at the lines: +\(got) food" : "The hold is full")
        }
    }

    // ---------- in port
    func drawPort(_ c: Canvas) {
        let hz = H * 0.5
        drawSea(c, hz)
        let L = light()
        let dark = 1 - L.night * 0.5
        // the island and its town
        let seed = Double(leg * 7 + path[leg] * 3)
        c.pathFill(Col(0x5f8f4a).shade(dark)) { p in
            p.move(to: CGPoint(x: W * 0.3, y: hz + 2))
            p.addQuadCurve(to: CGPoint(x: W * 0.62, y: hz - 86), control: CGPoint(x: W * 0.42, y: hz - 70))
            p.addQuadCurve(to: CGPoint(x: W * 0.84, y: hz - 50), control: CGPoint(x: W * 0.74, y: hz - 108))
            p.addQuadCurve(to: CGPoint(x: W + 10, y: hz - 24), control: CGPoint(x: W * 0.94, y: hz - 30))
            p.addLine(to: CGPoint(x: W + 10, y: hz + 2))
            p.closeSubpath()
        }
        c.pathFill(Col(0x4a7a3c).shade(dark)) { p in
            p.move(to: CGPoint(x: W * 0.5, y: hz + 2))
            p.addQuadCurve(to: CGPoint(x: W * 0.7, y: hz - 44), control: CGPoint(x: W * 0.58, y: hz - 40))
            p.addQuadCurve(to: CGPoint(x: W + 10, y: hz - 10), control: CGPoint(x: W * 0.86, y: hz - 46))
            p.addLine(to: CGPoint(x: W + 10, y: hz + 2))
            p.closeSubpath()
        }
        c.R(W * 0.34, hz - 2, W * 0.7, 6, Col(0xe8d6a0).shade(dark))
        for i in 0..<12 {
            let hx = W * 0.44 + Double(i) * W * 0.045 + hashN(seed + Double(i)) * 10
            let hy = hz - 4 - hashN(seed + Double(i) * 3.3) * 34
            let hw = 16 + hashN(seed + Double(i) * 1.7) * 10, hh = 11 + hashN(seed + Double(i) * 5.1) * 7
            c.R(hx, hy - hh, hw, hh, Col(0xf3ead2).shade(dark))
            let roof: Col = (i % 3 == 0 ? Col(0x8a5a36) : Col(0xb8452c)).shade(dark)
            c.poly(roof, [hx - 2, hy - hh, hx + hw / 2, hy - hh - 8, hx + hw + 2, hy - hh])
            c.R(hx + hw * 0.35, hy - 6, 4, 6, L.night > 0.3 ? Col(0xffd257) : Col(0x5a3a1c))
            if L.night > 0.3 { c.R(hx + 3, hy - hh + 3, 3, 3, Col(0xffd257)) }
        }
        // a church or a fort on the hill
        let tx = W * 0.64, ty = hz - 84
        if (leg + path[leg]) % 2 == 0 {
            c.R(tx - 6, ty - 26, 12, 30, Col(0xf3ead2).shade(dark))
            c.poly(Col(0xb8452c).shade(dark), [tx - 8, ty - 26, tx, ty - 40, tx + 8, ty - 26])
            c.R(tx - 0.8, ty - 48, 1.6, 9, Col(0x3a2412)); c.R(tx - 3, ty - 45, 6, 1.6, Col(0x3a2412))
        } else {
            c.R(tx - 22, ty - 12, 44, 16, Col(0x9a9388).shade(dark))
            for i in 0..<5 { c.R(tx - 22 + Double(i) * 10, ty - 16, 5, 5, Col(0x9a9388).shade(dark)) }
            c.seg(tx, ty - 12, tx, ty - 34, 1.5, Col(0x3a2412))
            c.poly(REDC, [tx, ty - 34, tx + 14, ty - 30 + sin(T * 5) * 2, tx, ty - 26])
        }
        for i in 0..<6 {
            let px = W * 0.38 + Double(i) * W * 0.11 + hashN(seed + Double(i) * 9) * 20
            let sw = sin(T * 1.2 + Double(i)) * 2
            c.curve(px, hz - 1, px + 3 + sw * 0.5, hz - 14, px + 4 + sw, hz - 26, 2.2, Col(0x6b4a26).shade(dark))
            let fronds: [Double] = [-2.4, -1.7, -0.9, -0.3, 0.4]
            let topX = px + 4 + sw, topY = hz - 26
            let leaf = Col(0x3f7a3c).shade(dark)
            for a in fronds {
                let mx2 = topX + cos(a) * 9, my2 = topY + sin(a) * 9 - 3
                let ex = topX + cos(a) * 16, ey = topY + sin(a) * 12 + 3
                c.curve(topX, topY, mx2, my2, ex, ey, 2.4, leaf)
            }
        }
        // the pier and your ship at anchor
        let wy = hz + (H - hz) * 0.4
        c.R(W * 0.5, hz + 8, W * 0.2, 5, Col(0x8a6a44).shade(dark))
        for i in 0..<6 { c.R(W * 0.5 + Double(i) * W * 0.038, hz + 8, 3, 18, Col(0x5a3d20).shade(dark)) }
        drawShip(c, W * 0.26, wy, min(W * 0.28, 250) * ship.len, ship.masts, furled: true)
        foreWave(c, wy + 5, 0, W)
        if L.night > 0.05 { c.R(0, 0, W, H, Col(0x04081a, 0.25 * L.night)) }
        c.textS(here.n, W / 2, 54, 26, GOLD, 0, FONTD)
        // what you can do ashore
        let names: [(String, String)] = [("Market", "buy and sell"), ("Tavern", "crew · maps · surgeon"), ("Shipwright", "mend the hull"), ("Well", wellUsed ? "casks filled" : "free water"), ("Set sail", "wages \(wagesDue())g")]
        let gap = 8.0
        let bw = (W - safeL - safeR - gap * 4) / 5
        let by = H - safeB - 52
        for (i, nm) in names.enumerated() {
            let x = safeL + Double(i) * (bw + gap)
            btn(c, x, by, bw, 46, nm.0, nm.1, gold: i == 4, off: i == 3 && wellUsed) { [unowned self] in
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
