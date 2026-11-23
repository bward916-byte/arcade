import CoreGraphics
import Foundation

// Everything Broadside draws in this slice: sky, sea, the pier and beach, the town edge, the player and the HUD.

extension Game {
    func draw(_ c: Canvas) {
        c.clear(W, H)
        let L = light
        drawSky(c, L)
        if mode == .title {
            drawTitle(c, L)
            return
        }
        drawFarHills(c, L)
        drawBackSea(c, L)
        drawLand(c, L)
        drawTown(c, L)
        drawPier(c, L)
        drawPalms(c, L)
        if boat { drawRowboat(c, L) }
        drawFishing(c, L)
        drawPerson(c, L)
        drawFrontSea(c, L)
        drawSparks(c)
        if L < 0.5 { c.R(0, 0, W, H, Col(0x060c1c, 0.34 * (0.5 - L) / 0.5)) }
        drawRings(c, L)
        drawHUD(c, L)
    }

    // ---------- sky
    func drawSky(_ c: Canvas, _ L: Double) {
        let top = dn(0x070d1c, 0x2f6ea8, L)
        let dusk = exp(-pow((L - 0.3) / 0.2, 2))
        let lowDay = Col.mix(Col(0xbfd9ea), Col(0xf2a868), dusk)
        let low = Col.mix(Col(0x1a2238), lowDay, L)
        c.vfill(0, 0, W, H, [(0, top), (0.75, low), (1, low)])
        // stars
        if L < 0.45 {
            let na = (0.45 - L) / 0.45
            for i in 0..<70 {
                let fi = Double(i)
                let x = (fi * 197.3 + Double((i * i * 31) % 113)).truncatingRemainder(dividingBy: W)
                let y = (fi * 89.7).truncatingRemainder(dividingBy: H * 0.6)
                let tw = 0.45 + 0.55 * sin(T * (1.2 + Double(i % 5) * 0.5) + fi * 1.9)
                c.R(x, y, i % 9 == 0 ? 1.6 : 1, i % 9 == 0 ? 1.6 : 1, Col(0xf0f4ff, na * tw * 0.9))
            }
        }
        // sun and moon ride an arc across the sky
        let ang = (tod - 0.25) * 2 * PI
        let sunX = W * 0.5 - cos(ang) * W * 0.42
        let sunY = H * 0.62 - sin(ang) * H * 0.5
        if sunY < H * 0.7 {
            c.glow(sunX, sunY, 120, Col(0xffe6a8, 0.5 * L + 0.15), Col(0xffe6a8, 0))
            c.circ(sunX, sunY, 15, Col(0xfff3c8))
        }
        let moonX = W * 0.5 + cos(ang) * W * 0.42
        let moonY = H * 0.62 + sin(ang) * H * 0.5
        if moonY < H * 0.7 {
            c.glow(moonX, moonY, 70, Col(0xc8dcff, 0.22), Col(0xc8dcff, 0))
            c.circ(moonX, moonY, 12, Col(0xf0f0e6))
            c.circ(moonX + 5, moonY - 3, 11, dn(0x070d1c, 0x2f6ea8, L))
        }
        // clouds drifting
        for i in 0..<6 {
            let fi = Double(i)
            let span = W + 400
            let cx = (fi * 397 + T * (5 + fi * 1.3) - camX * 0.08).truncatingRemainder(dividingBy: span)
            let x = (cx < 0 ? cx + span : cx) - 200
            let y = H * (0.10 + 0.07 * Double(i % 4))
            let sc = 0.7 + 0.25 * Double(i % 3)
            let col = Col.mix(Col(0x2a3350), Col.mix(Col(0xffffff), Col(0xffd0a0), dusk * 0.7), L).alpha(0.5)
            for j in 0..<5 {
                let fj = Double(j)
                c.ell(x + (fj - 2) * 34 * sc, y - sin(fj * 1.1 + fi) * 8 * sc, 40 * sc, 17 * sc, col)
            }
        }
    }

    func drawFarHills(_ c: Canvas, _ L: Double) {
        let horizon = sy(-55)
        for layer in 0..<2 {
            let fl = Double(layer)
            let par = camX * (0.3 + fl * 0.2)
            let col = Col.mix(dn(0x101a20, 0x4a6a5a, L), dn(0x0b1a30, 0x7fa0c0, L), layer == 0 ? 0.6 : 0.35)
            let amp = (layer == 0 ? 100.0 : 60.0) * camS * (0.7 + fl * 0.3)
            c.pathFill(col) { p in
                p.move(to: CGPoint(x: -10, y: horizon))
                var x = -10.0
                while x <= self.W + 10 {
                    let wx = x / self.camS + par
                    let hh = 0.55 + 0.3 * sin(wx * 0.004 + fl) + 0.12 * sin(wx * 0.013) + 0.18 * sin(wx * 0.0021 + fl * 2)
                    p.addLine(to: CGPoint(x: x, y: horizon - amp * hh))
                    x += 16
                }
                p.addLine(to: CGPoint(x: self.W + 10, y: horizon))
                p.closeSubpath()
            }
        }
        // haze along the horizon
        c.vfill(0, horizon - 60 * camS, W, 70 * camS, [(0, Col(0xe6ecf0, 0)), (0.8, Col(0xe6ecf0, 0.10 + 0.2 * L)), (1, Col(0xe6ecf0, 0))])
    }

    // ---------- sea
    func drawBackSea(_ c: Canvas, _ L: Double) {
        let y0 = sy(-50)
        c.vfill(0, y0, W, H - y0, [(0, dn(0x0e2733, 0x3f8494, L)), (1, dn(0x0b202c, 0x1f5868, L))])
        for layer in 0..<3 {
            let fl = Double(layer)
            let base = -34 + fl * 10
            c.pathStroke(Col(0xe1f2f6, 0.10 + 0.16 * L), 1.2) { p in
                var x = -10.0
                var first = true
                while x <= self.W + 10 {
                    let wx = (x - self.W / 2) / self.camS + self.camX
                    let y = base + (3 + fl) * sin(wx * (0.012 + fl * 0.003) + self.T * (0.5 + fl * 0.2) + fl * 2)
                    let pt = CGPoint(x: x, y: self.sy(y))
                    if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                    x += 10
                }
            }
        }
    }
    func drawFrontSea(_ c: Canvas, _ L: Double) {
        let wx0 = (0 - W / 2) / camS + camX - 20
        let wx1 = (W - W / 2) / camS + camX + 20
        let shore = 6.0
        if wx0 > shore { return }
        let right = min(wx1, shore)
        let top = sy(-4), bot = H + 2
        c.pathGrad(top, bot, [(0, dn(0x12303e, 0x2f8a96, L).alpha(0.9)), (1, dn(0x081822, 0x15485a, L).alpha(0.94))]) { p in
            p.move(to: CGPoint(x: self.sx(wx0), y: bot))
            var x = wx0
            while x <= right {
                p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.wave(x))))
                x += 8
            }
            p.addLine(to: CGPoint(x: self.sx(right), y: self.sy(self.wave(right))))
            p.addLine(to: CGPoint(x: self.sx(right + 26), y: bot))
            p.closeSubpath()
        }
        c.pathStroke(Col(0xdcf0f5, 0.3 + 0.3 * L), 2) { p in
            var x = wx0
            var first = true
            while x <= right {
                let pt = CGPoint(x: self.sx(x), y: self.sy(self.wave(x)))
                if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                x += 8
            }
        }
        // light bands under the surface
        for b in 1...5 {
            let fb = Double(b)
            let dep = fb * fb * 2.2 + 6
            c.pathStroke(Col(0x96dce1, (0.16 - fb * 0.02) * (0.4 + 0.6 * L)), 1.3) { p in
                var x = wx0
                var first = true
                while x <= right - fb * 6 {
                    let y = self.wave(x - fb * 14) * (1 - fb * 0.12) + dep + sin(x * 0.02 + self.T * 0.6 + fb) * 2
                    let pt = CGPoint(x: self.sx(x), y: self.sy(y))
                    if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                    x += 16
                }
            }
        }
        // foam where the water meets the sand
        let fx = sx(shore), fy = sy(wave(shore))
        for i in 0..<5 {
            let fi = Double(i)
            c.ell(fx - 8 * camS + fi * 6 * camS, fy + 2 + sin(T * 2 + fi) * 1.5, 7 * camS, 1.8 * camS, Col(0xf0faff, 0.45 + 0.2 * sin(T * 2 + fi)))
        }
    }

    // ---------- land
    func drawLand(_ c: Canvas, _ L: Double) {
        let wx0 = max(0.0, (0 - W / 2) / camS + camX - 20)
        let wx1 = (W - W / 2) / camS + camX + 20
        if wx1 < 0 { return }
        let bot = H + 4
        // the body of the island: sand low down, earth inland
        let topY = sy(ground(wx1)) - 10
        c.pathGrad(topY, bot, [(0, dn(0x2a2418, 0xd9c79a, L)), (0.5, dn(0x1c160e, 0xa98a5c, L)), (1, dn(0x100c08, 0x6a5234, L))]) { p in
            p.move(to: CGPoint(x: self.sx(wx0), y: bot))
            let startY: Double = wx0 <= 0 ? 6 : self.ground(wx0)
            p.addLine(to: CGPoint(x: self.sx(wx0), y: self.sy(startY)))
            var x = max(wx0, 0)
            while x <= wx1 {
                let dip: Double = x < 60 ? (60 - x) / 60 * 12 : 0
                let gy: Double = self.ground(max(60, x)) + dip
                p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(gy)))
                x += 10
            }
            p.addLine(to: CGPoint(x: self.sx(wx1), y: bot))
            p.closeSubpath()
        }
        // turf from the top of the beach inland
        let g0 = max(wx0, 560.0)
        if wx1 > g0 {
            c.pathFill(dn(0x12261a, 0x5f9a48, L)) { p in
                p.move(to: CGPoint(x: self.sx(g0), y: self.sy(self.ground(g0))))
                var x = g0
                while x <= wx1 {
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x)) - 1.5 * self.camS))
                    x += 10
                }
                x = wx1
                while x >= g0 {
                    let depth = min(7.0, (x - 560) / 20)
                    p.addLine(to: CGPoint(x: self.sx(x), y: self.sy(self.ground(x)) + depth * self.camS))
                    x -= 10
                }
                p.closeSubpath()
            }
            // grass blades
            var x = floor(g0 / 9) * 9
            while x <= wx1 {
                if x >= 575 {
                    let h = (3 + hashN(x) * 5) * camS
                    let sway = sin(T * 1.6 + x * 0.3) * 1.2 * camS
                    c.seg(sx(x), sy(ground(x)), sx(x) + sway, sy(ground(x)) - h, 1.1, dn(0x183422, 0x7cba58, L))
                }
                x += 9
            }
        }
        // pebbles and shells on the sand
        var s = floor(max(wx0, 70) / 37) * 37
        while s <= min(wx1, 560) {
            if s >= 70 {
                let r = (1 + hashN(s) * 1.6) * camS
                c.ell(sx(s + hashN(s + 3) * 20), sy(ground(s)) + (3 + hashN(s + 9) * 10) * camS, r * 1.5, r, dn(0x1a1c20, 0x9a9488, L))
            }
            s += 37
        }
    }

    func drawPier(_ c: Canvas, _ L: Double) {
        let deck = sy(-22)
        let x0 = sx(-240), x1 = sx(14)
        if x1 < -20 || x0 > W + 20 { return }
        // posts
        var px0 = -232.0
        while px0 <= 0 {
            let X = sx(px0)
            c.linear(X - 2.6 * camS, deck, 5.2 * camS, H - deck, X - 2.6 * camS, 0, X + 2.6 * camS, 0, [(0, dn(0x1c120a, 0x6e4a26, L)), (1, dn(0x0a0604, 0x2e1c0e, L))])
            px0 += 33
        }
        // cross braces
        var b = -232.0
        while b < -10 {
            c.seg(sx(b), deck + 6 * camS, sx(b + 33), deck + 30 * camS, 1.6 * camS, dn(0x140c06, 0x4a2e14, L))
            b += 33
        }
        // the deck
        c.vfill(x0, deck - 3 * camS, x1 - x0, 5 * camS, [(0, dn(0x2a1c10, 0x9a7446, L)), (1, dn(0x160e08, 0x5e4226, L))])
        var pl = -240.0
        while pl < 14 {
            c.R(sx(pl), deck - 3 * camS, 1, 5 * camS, Col(0x000000, 0.3))
            pl += 9
        }
        // rail, lantern post and a pair of barrels
        c.seg(sx(-236), deck - 3 * camS, sx(-236), deck - 20 * camS, 2 * camS, dn(0x1c120a, 0x5a3a1e, L))
        c.seg(sx(-236), deck - 18 * camS, sx(-200), deck - 18 * camS, 1.4 * camS, dn(0x1c120a, 0x5a3a1e, L))
        let lx = sx(-96)
        c.seg(lx, deck - 3 * camS, lx, deck - 38 * camS, 2 * camS, dn(0x100a06, 0x3a2512, L))
        c.R(lx - 3 * camS, deck - 44 * camS, 6 * camS, 7 * camS, L < 0.5 ? Col(0xffd27a) : Col(0xb89a5a))
        if L < 0.5 { c.glow(lx, deck - 40 * camS, 46 * camS, Col(0xffc86e, 0.45), Col(0xffc86e, 0)) }
        drawBarrel(c, -40, -22, 4.6, L)
        drawBarrel(c, -29, -22, 4.2, L)
    }

    func drawBarrel(_ c: Canvas, _ wx: Double, _ wy: Double, _ r: Double, _ L: Double) {
        let X = sx(wx), Y = sy(wy) - 3 * camS, w = r * camS, hh = r * 2.4 * camS
        c.ell(X + w * 0.25, Y + 0.5, w * 1.25, w * 0.3, Col(0x000000, 0.2))
        c.linear(X - w, Y - hh, w * 2, hh, X - w, 0, X + w, 0, [(0, dn(0x150e08, 0x5a3c20, L)), (0.3, dn(0x22170c, 0xa47a48, L)), (1, dn(0x080503, 0x2c1b0e, L))])
        for f in [0.16, 0.5, 0.84] {
            c.R(X - w, Y - hh * f - 0.9 * camS, w * 2, 1.8 * camS, dn(0x0a0a0c, 0x3a3c42, L))
        }
        c.ell(X, Y - hh, w, w * 0.24, dn(0x1a120a, 0x8a6a40, L))
    }

    func drawRowboat(_ c: Canvas, _ L: Double) {
        let wx = -150.0
        let X = sx(wx), Y = sy(wave(wx)) + 1
        c.save()
        c.translate(X, Y)
        c.rotate(cos(wx * 0.02 + T * 1.2) * 0.04)
        c.scale(camS, camS)
        c.pathFill(dn(0x1c120a, 0x7a5230, L)) { p in
            p.move(to: CGPoint(x: -22, y: -6))
            p.addQuadCurve(to: CGPoint(x: 24, y: -7), control: CGPoint(x: 0, y: -4))
            p.addLine(to: CGPoint(x: 16, y: 4))
            p.addLine(to: CGPoint(x: -15, y: 4))
            p.closeSubpath()
        }
        c.R(-18, -5.5, 36, 1.4, dn(0x2a1c10, 0xb08a58, L))
        c.seg(-4, -6, -16, -13, 1.2, dn(0x1c120a, 0x5a3a1e, L))
        c.restore()
    }

    // ---------- the edge of town: market stall and two houses
    func drawTown(_ c: Canvas, _ L: Double) {
        drawHouse(c, 1090, 54, 46, Col(0xe2d3b0), Col(0x8a3a2a), L)
        drawHouse(c, 1210, 44, 36, Col(0xd4c2a4), Col(0x6a4a2a), L)
        // market stall
        let wx = 1000.0
        let X = sx(wx), Y = sy(ground(wx)), k = camS
        if X < -120 * k || X > W + 120 * k { return }
        c.R(X - 30 * k, Y - 15 * k, 60 * k, 15 * k, dn(0x1c120a, 0x7a5632, L))
        c.R(X - 31 * k, Y - 17 * k, 62 * k, 3 * k, dn(0x2a1c10, 0x9a7446, L))
        c.seg(X - 28 * k, Y - 15 * k, X - 28 * k, Y - 44 * k, 2 * k, dn(0x140c06, 0x4a2e14, L))
        c.seg(X + 28 * k, Y - 15 * k, X + 28 * k, Y - 44 * k, 2 * k, dn(0x140c06, 0x4a2e14, L))
        for i in 0..<6 {
            let fi = Double(i)
            let col = i % 2 == 0 ? dn(0x4a1414, 0xb0302a, L) : dn(0x4a463c, 0xe8dcc0, L)
            let ax: Double = X - 33 * k + fi * 11 * k
            let bx: Double = ax + 11 * k
            let mx: Double = ax + 5.5 * k
            let y1: Double = Y - 47 * k
            let y2: Double = Y - 37 * k
            let y3: Double = Y - 34 * k
            c.poly(col, [ax, y1, bx, y1, bx, y2, mx, y3, ax, y2])
        }
        // fish laid out on the counter
        for i in 0..<5 {
            let fi = Double(i)
            c.ell(X - 20 * k + fi * 10 * k, Y - 19 * k, 4 * k, 1.5 * k, dn(0x3a4650, 0x9fb8c8, L))
        }
        drawBarrel(c, wx + 40, ground(wx + 40) + 3, 4.6, L)
    }

    func drawHouse(_ c: Canvas, _ wx: Double, _ w: Double, _ h: Double, _ wall: Col, _ roof: Col, _ L: Double) {
        let X = sx(wx), Y = sy(ground(wx)), k = camS * 1.45
        if X < -90 * k || X > W + 90 * k { return }
        let wl = Col.mix(wall.shade(0.25), wall, L)
        c.R(X - w / 2 * k - 2 * k, Y - 3 * k, w * k + 4 * k, 5 * k, dn(0x1a1c20, 0x8a8478, L))
        c.linear(X - w / 2 * k, Y - h * k, w * k, h * k - 2 * k, X - w / 2 * k, 0, X + w / 2 * k, 0, [(0, wl), (1, wl.shade(0.72))])
        let rf = Col.mix(roof.shade(0.3), roof, L)
        let eave: Double = Y - h * k
        let ridge: Double = eave - 18 * k
        let lft: Double = X - w / 2 * k - 4 * k
        let rgt: Double = X + w / 2 * k + 4 * k
        c.poly(rf, [lft, eave, X, ridge, rgt, eave])
        c.poly(rf.shade(0.75), [X, ridge, rgt, eave, X + 2 * k, eave])
        // door and windows, lit after dark
        c.arch(X - 4 * k, Y - 16 * k, 8 * k, 14 * k, dn(0x100a06, 0x4a2e14, L))
        let lit = L < 0.5
        for dx in [-w * 0.3, w * 0.3] {
            c.R(X + dx * k - 4 * k, Y - h * 0.62 * k, 8 * k, 9 * k, lit ? Col(0xffcc66) : Col(0x2a2420))
            c.R(X + dx * k - 0.4 * k, Y - h * 0.62 * k, 0.8 * k, 9 * k, dn(0x100a06, 0x3a2512, L))
            if lit { c.glow(X + dx * k, Y - h * 0.5 * k, 22 * k, Col(0xffc86e, 0.28), Col(0xffc86e, 0)) }
        }
        // chimney smoke
        let cx = X + w * 0.28 * k, cy = Y - h * k - 14 * k
        c.R(cx - 3 * k, cy, 6 * k, 12 * k, dn(0x1a1410, 0x7a6a5a, L))
        for i in 0..<4 {
            let a = (T * 0.3 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1)
            c.circ(cx + a * 10 * k + sin(T + Double(i)) * 2 * k, cy - a * 30 * k, (3 + a * 6) * k, Col(0xe0ddd6, 0.32 * (1 - a)))
        }
    }

    func drawPalms(_ c: Canvas, _ L: Double) {
        let list: [(Double, Double, Double)] = [(160, 70, -0.35), (500, 78, 0.4), (640, 84, 0.3), (735, 62, -0.3), (1150, 70, 0.2)]
        for (wx, h, lean) in list {
            let X = sx(wx)
            if X < -90 * camS || X > W + 90 * camS { continue }
            drawPalm(c, wx, h, lean, L)
        }
    }
    func drawPalm(_ c: Canvas, _ wx: Double, _ h: Double, _ lean: Double, _ L: Double) {
        let sw = sin(T * 0.7 + wx) * 0.05 + sin(T * 1.9 + wx) * 0.02
        c.save()
        c.translate(sx(wx), sy(ground(wx)))
        c.scale(camS, camS)
        c.ell(lean * 18, 1, 24, 3.5, Col(0x000000, 0.12 + 0.12 * L))
        // trunk: a tapered curve with ring scars
        let steps = 16
        c.pathFill(dn(0x18110a, 0x7a5c38, L)) { p in
            for q in 0...steps {
                let f = Double(q) / Double(steps)
                let tw = 6.6 - 3.4 * f + (f < 0.12 ? (0.12 - f) * 22 : 0)
                let pt = CGPoint(x: lean * f * f * 30 - tw, y: -f * h)
                if q == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            for q in stride(from: steps, through: 0, by: -1) {
                let f = Double(q) / Double(steps)
                let tw = 6.6 - 3.4 * f + (f < 0.12 ? (0.12 - f) * 22 : 0)
                p.addLine(to: CGPoint(x: lean * f * f * 30 + tw, y: -f * h))
            }
            p.closeSubpath()
        }
        for q in 1..<30 {
            let f = Double(q) / 30
            let tw = 6.6 - 3.4 * f
            let x = lean * f * f * 30
            c.curve(x - tw, -f * h, x, -f * h + 1.6, x + tw, -f * h - 0.4, 0.8, Col(0x140c06, 0.4))
        }
        let tx0 = lean * 30, ty0 = -h
        // fronds: a curved spine with drooping leaflets
        for a in 0..<11 {
            let fa = Double(a)
            let back = a < 5
            let an = -PI * 1.0 + fa / 10 * PI * 1.0 + sw * (1.2 + Double(a % 3) * 0.4)
            let len = 40 + Double(a % 3) * 6
            let droop = 16 + abs(cos(an)) * 16
            let leaf = back ? dn(0x07140a, 0x1f5a2a, L) : dn(0x0c2412, a % 2 == 0 ? 0x58a646 : 0x3f8f3c, L)
            var pts: [(Double, Double)] = []
            for q in 0...10 {
                let u = Double(q) / 10
                pts.append((tx0 + cos(an) * len * u, ty0 + sin(an) * len * u + droop * u * u))
            }
            c.pathStroke(leaf, 1.25) { p in
                for q in 1...10 {
                    let u = Double(q) / 10
                    let a0 = pts[q - 1], a1 = pts[q]
                    let dx = a1.0 - a0.0, dy = a1.1 - a0.1
                    let d = max(0.001, (dx * dx + dy * dy).squareRoot())
                    let nx = -dy / d, ny = dx / d
                    let ll = 3 + 10 * pow(sin(PI * min(1, u * 1.08)), 0.7)
                    for sd in [-1.0, 1.0] {
                        p.move(to: CGPoint(x: a1.0, y: a1.1))
                        let ex: Double = a1.0 + nx * sd * ll * 0.75 + dx * 1.1
                        let ey: Double = a1.1 + ny * sd * ll * 0.75 + dy * 1.1 + ll * 0.45
                        p.addLine(to: CGPoint(x: ex, y: ey))
                    }
                }
            }
            c.pathStroke(dn(0x14280e, 0xa2bc58, L), 1.1) { p in
                p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
                for q in 1...10 { p.addLine(to: CGPoint(x: pts[q].0, y: pts[q].1)) }
            }
        }
        c.circ(tx0 - 3, ty0 + 4, 2.7, dn(0x140c06, 0x5a3a16, L))
        c.circ(tx0 + 2.5, ty0 + 5, 2.7, dn(0x140c06, 0x5a3a16, L))
        c.ell(tx0, ty0, 4.4, 3.2, dn(0x140e08, 0x6a4a26, L))
        c.restore()
    }

    // ---------- the fishing line
    func drawFishing(_ c: Canvas, _ L: Double) {
        if !fishing { return }
        let hx = sx(px - 13), hy = sy(ground(px)) - 27 * camS
        let tipX = sx(px - 40), tipY = sy(ground(px)) - 46 * camS
        c.curve(hx, hy, (hx + tipX) / 2, hy - 14 * camS, tipX, tipY, 1.6 * camS, dn(0x2a1c10, 0x8a5a2a, L))
        let fwx = -262.0
        let bob = fishPhase == 1 ? sin(T * 26) * 3.2 : sin(T * 2.2) * 0.8
        let fx = sx(fwx), fy = sy(wave(fwx) + bob)
        c.curve(tipX, tipY, (tipX + fx) / 2, (tipY + fy) / 2 + (fishPhase == 1 ? 2 : 14) * camS, fx, fy, 0.8, Col(0xf0f0f0, 0.75))
        c.circ(fx, fy, 2.2 * camS, Col(0xd03a2a))
        c.circ(fx, fy - 1.2 * camS, 1.3 * camS, Col(0xf4f0e6))
        if fishPhase == 1 {
            for i in 0..<3 {
                let u = (fishT * 1.4 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                c.ellStroke(fx, fy, (3 + u * 16) * camS, (1 + u * 3) * camS, 1, Col(0xf0faff, 0.7 * (1 - u)))
            }
        }
    }

    // ---------- the player
    func drawPerson(_ c: Canvas, _ L: Double) {
        let moving = abs(speed) > 4
        let amt = min(1.0, abs(speed) / 40)
        let bob = moving ? abs(sin(walkPh)) * 1.1 * amt : sin(T * 1.6) * 0.3
        c.save()
        c.translate(sx(px), sy(ground(px)))
        c.scale(camS * face, camS)
        c.ell(0, 0.6, 9, 1.8, Col(0x000000, 0.16 + 0.12 * L))
        let skin = dn(0x4a3626, 0xe0b088, L)
        let shirt = dn(0x3a382e, 0xd9d2c0, L)
        let pants = dn(0x14110c, 0x4a3a28, L)
        let boot = dn(0x0a0806, 0x2a1c10, L)
        let hipY = -20.0 - bob
        // legs: far one first
        for side in 0..<2 {
            let ph = walkPh + (side == 0 ? PI : 0)
            let swing = moving ? sin(ph) * 0.55 * amt : 0
            let bend = moving ? max(0, -cos(ph)) * 0.8 * amt : 0
            let kx = sin(swing) * 10, ky = hipY + cos(swing) * 10
            let fx = kx + sin(swing - bend) * 10
            let fy = min(0.0, ky + cos(swing - bend) * 10)
            let col = side == 0 ? pants.shade(0.75) : pants
            c.roundCaps(true)
            c.seg(0, hipY, kx, ky, 4.4, col)
            c.seg(kx, ky, fx, fy, 3.8, col)
            c.roundCaps(false)
            c.ell(fx + 1.6, fy - 0.9, 3.4, 1.6, boot)
        }
        // far arm
        let shY = -34.0 - bob
        let armSwing = moving ? sin(walkPh) * 0.6 * amt : 0
        c.roundCaps(true)
        if !fishing {
            let ax = sin(armSwing) * 8, ay = shY + cos(armSwing) * 8
            c.seg(0, shY, ax, ay, 3, shirt.shade(0.72))
            c.seg(ax, ay, ax + sin(armSwing + 0.3) * 7, ay + cos(armSwing + 0.3) * 7, 2.6, skin.shade(0.78))
        }
        c.roundCaps(false)
        // torso
        c.pathFill(shirt) { p in
            p.move(to: CGPoint(x: -4.2, y: shY - 2))
            p.addLine(to: CGPoint(x: 4.4, y: shY - 2))
            p.addQuadCurve(to: CGPoint(x: 3.8, y: hipY + 1), control: CGPoint(x: 5.4, y: (shY + hipY) / 2))
            p.addLine(to: CGPoint(x: -3.6, y: hipY + 1))
            p.addQuadCurve(to: CGPoint(x: -4.2, y: shY - 2), control: CGPoint(x: -5, y: (shY + hipY) / 2))
        }
        c.pathFill(Col(0x000000, 0.14)) { p in
            p.move(to: CGPoint(x: -4.2, y: shY - 2))
            p.addLine(to: CGPoint(x: -1, y: shY - 2))
            p.addLine(to: CGPoint(x: -1.4, y: hipY + 1))
            p.addLine(to: CGPoint(x: -3.6, y: hipY + 1))
            p.closeSubpath()
        }
        c.R(-3.8, hipY - 1, 7.8, 2, dn(0x0a0806, 0x3a2512, L))
        // neck and head
        c.R(-1.2, shY - 5, 2.6, 4, skin.shade(0.85))
        let headY = shY - 8.4
        c.circ(0.5, headY, 3.7, skin)
        c.pathFill(dn(0x0a0806, 0x3a2a1a, L)) { p in
            p.addArc(center: CGPoint(x: 0.3, y: headY - 0.4), radius: 3.9, startAngle: CGFloat(PI * 0.95), endAngle: CGFloat(PI * 1.95), clockwise: false)
            p.addLine(to: CGPoint(x: -3.4, y: headY + 1.6))
            p.closeSubpath()
        }
        c.circ(2.6, headY - 0.2, 0.5, Col(0x1a1008))
        // near arm: swings when walking, holds the rod when fishing
        c.roundCaps(true)
        if fishing {
            c.seg(0.5, shY, 7, shY + 4, 3.1, shirt)
            c.seg(7, shY + 4, 13, shY + 7, 2.7, skin)
        } else {
            let a2 = -armSwing
            let ax = sin(a2) * 8, ay = shY + cos(a2) * 8
            c.seg(0.5, shY, ax, ay, 3.1, shirt)
            c.seg(ax, ay, ax + sin(a2 + 0.3) * 7, ay + cos(a2 + 0.3) * 7, 2.7, skin)
        }
        c.roundCaps(false)
        c.restore()

        // how full the hold is: fish shapes over your head, shown for a moment
        if capShow > 0 {
            let n = fishCap
            let a = min(1.0, capShow / 0.6)
            let gap = 13.0
            let x0 = sx(px) - Double(n - 1) * gap / 2
            let y = sy(ground(px)) - 62 * camS
            for i in 0..<n {
                let x = x0 + Double(i) * gap
                let col = i < fish ? Col(0xbfe0f0, a) : Col(0x101820, 0.55 * a)
                c.ell(x, y, 4.6, 2.2, col)
                c.poly(col, [x - 3.6, y, x - 7, y - 2.4, x - 7, y + 2.4])
            }
        }
    }

    func drawSparks(_ c: Canvas) {
        for s in sparks {
            let a = 1 - s.life / s.max
            c.circ(sx(s.x), sy(s.y), s.r * camS, s.c.alpha(a))
        }
    }

    // ---------- the round controls: actions that spin, and coin circles you pour into
    func drawRings(_ c: Canvas, _ L: Double) {
        rings = []
        var used: [Double] = []
        func place(_ wantX: Double) -> Double {
            var x = wantX
            for _ in 0..<6 {
                var moved = false
                for u in used where abs(u - x) < 74 {
                    x = u + (x >= u ? 74 : -74)
                    moved = true
                }
                if !moved { break }
            }
            used.append(x)
            return x
        }
        let headY = sy(ground(px)) - 98 * camS
        // actions
        var acts: [(String, Double)] = []
        if abs(px - -215) < 60 { acts.append(("fish", -215)) }
        if abs(px - 1000) < 60 { acts.append(("market", 1000)) }
        for (id, wx) in acts {
            let x = place(sx(wx)), y = max(96.0, headY), r = 22.0
            rings.append(Ring(id: id, x: x, y: y, r: r, pour: false))
            let busy = id == "fish" && fishing
            c.circ(x, y + 3, r + 2, Col(0x000000, 0.28))
            c.glow(x - 6, y - 8, r * 1.2, Col(0x3c4a5c, 0.95), Col(0x08121c, 0.95))
            c.circ(x, y, r, Col(0x08121c, 0.55))
            c.circStroke(x, y, r, 2, busy ? Col(0xfff0c0) : GOLD)
            c.save()
            c.translate(x, y)
            if busy { c.rotate(T * 4) }
            drawIcon(c, id)
            c.restore()
        }
        // coin circles
        for u in upgs where !done(u.id) && abs(u.x - px) < 150 {
            let near = abs(u.x - px) < 70
            let x = place(sx(u.x)), y = max(110.0, headY - 4), r = 22.0
            if near { rings.append(Ring(id: u.id, x: x, y: y, r: r, pour: true)) }
            c.alpha(near ? 1 : 0.5)
            c.circ(x, y + 3, r + 2, Col(0x000000, 0.28))
            c.circ(x, y, r, Col(0x101a28, 0.92))
            let have = paid[u.id] ?? 0
            if have > 0 {
                c.arcStroke(x, y, r, -PI / 2, -PI / 2 + 2 * PI * Double(have) / Double(u.cost), 4, GOLD)
            }
            c.circStroke(x, y, r, 1.4, GOLD2.alpha(0.8))
            c.save()
            c.translate(x, y)
            drawIcon(c, u.id)
            c.restore()
            // coin blanks above, filled as you pour: rows of six, the last row centred
            if near {
                let shown = min(12, u.cost)
                let per = Double(u.cost) / Double(shown)
                let rows = (shown + 5) / 6
                for i in 0..<shown {
                    let row = i / 6
                    let inRow = row == rows - 1 ? shown - row * 6 : 6
                    let col = i % 6
                    let bx = x + (Double(col) - Double(inRow - 1) / 2) * 11
                    let by = y - r - 12 - Double(rows - 1 - row) * 11
                    let on = Double(have) >= per * Double(i + 1) - 0.001
                    c.circ(bx, by, 4.4, on ? Col(0xffd24a) : Col(0x0a1018, 0.75))
                    c.circStroke(bx, by, 4.4, 1, on ? Col(0x8a6a10) : Col(0xd8b86a, 0.5))
                }
            }
            c.alpha(1)
        }
    }

    func drawIcon(_ c: Canvas, _ id: String) {
        let u = 9.0
        switch id {
        case "fish":
            c.ell(1, 0, u * 0.8, u * 0.42, GOLD)
            c.poly(GOLD, [-u * 0.6, 0, -u * 1.15, -u * 0.5, -u * 1.15, u * 0.5])
            c.circ(u * 0.45, -u * 0.08, 1.1, NAVY)
        case "market":
            for i in 0..<3 { c.ell(0, u * 0.5 - Double(i) * u * 0.42, u * 0.75, u * 0.26, i == 1 ? Col(0xe0a83a) : GOLD) }
        case "rod":
            c.seg(-u * 0.8, u * 0.8, u * 0.7, -u * 0.9, 1.8, GOLD)
            c.curve(u * 0.7, -u * 0.9, u * 0.9, 0, u * 0.5, u * 0.6, 1, GOLD)
            c.circ(u * 0.5, u * 0.7, 1.6, GOLD)
        case "bait":
            c.curve(-u * 0.8, u * 0.2, -u * 0.2, -u * 0.9, u * 0.2, 0, 2.2, GOLD)
            c.curve(u * 0.2, 0, u * 0.5, u * 0.7, u * 0.9, -u * 0.2, 2.2, GOLD)
        case "cart":
            c.R(-u * 0.8, -u * 0.5, u * 1.5, u * 0.7, GOLD)
            c.circStroke(-u * 0.3, u * 0.55, u * 0.36, 1.6, GOLD)
            c.circStroke(u * 0.45, u * 0.55, u * 0.36, 1.6, GOLD)
            c.seg(u * 0.7, -u * 0.3, u * 1.15, -u * 0.8, 1.6, GOLD)
        case "boat":
            c.poly(GOLD, [-u * 0.95, 0, u * 0.95, 0, u * 0.6, u * 0.6, -u * 0.6, u * 0.6])
            c.seg(0, 0, 0, -u * 0.95, 1.6, GOLD)
            c.poly(GOLD, [u * 0.15, -u * 0.9, u * 0.8, -u * 0.15, u * 0.15, -u * 0.15])
        default:
            c.circ(0, 0, 3, GOLD)
        }
    }

    // ---------- HUD
    func drawHUD(_ c: Canvas, _ L: Double) {
        let pad = max(12.0, safeL)
        let s = String(coins)
        let tw = textW(s, 15, FONTB)
        c.RR(pad - 4, 8, tw + 40, 24, 12, Col(0x08121c, 0.55))
        c.RRStroke(pad - 4, 8, tw + 40, 24, 12, 1, GOLD2.alpha(0.55))
        c.glow(pad + 7, 18, 10, Col(0xfff3b0), Col(0xa87a14))
        c.circ(pad + 9, 20, 8, Col(0xffd24a))
        c.circStroke(pad + 9, 20, 8, 1, Col(0x8a6a10))
        c.circStroke(pad + 9, 20, 5, 1, Col(0x8a6a10, 0.6))
        c.text(s, pad + 24, 25, 15, CREAM, -1, FONTB)

        let part = L > 0.5 ? (tod < 0.5 ? "Morning" : "Afternoon") : (tod < 0.5 ? "Night" : "Evening")
        c.textS("GULL CAY  ·  DAY " + String(day) + "  ·  " + part, W - max(12.0, safeR), 24, 14, CREAM, 1, FONTB)

        if logT > 0 && !log.isEmpty {
            let a = min(1.0, logT)
            let w = min(W - 2 * pad - 180, textW(log, 14) + 36)
            c.RR(W / 2 - w / 2, 46, w, 30, 15, Col(0x050c14, 0.62 * a))
            c.RRStroke(W / 2 - w / 2, 46, w, 30, 15, 1, GOLD2.alpha(0.45 * a))
            c.text(log, W / 2, 66, 14, CREAM.alpha(a))
        }
    }

    // ---------- title
    func drawTitle(_ c: Canvas, _ L: Double) {
        let horizon = H * 0.62
        c.vfill(0, horizon, W, H - horizon, [(0, dn(0x0e2733, 0x3f8494, L)), (1, dn(0x081822, 0x15485a, L))])
        for layer in 0..<4 {
            let fl = Double(layer)
            c.pathStroke(Col(0xe1f2f6, 0.14 + 0.1 * fl), 1.4) { p in
                var x = -10.0
                var first = true
                while x <= self.W + 10 {
                    let y = horizon + 14 + fl * 22 + (3 + fl * 2) * sin(x * (0.012 - fl * 0.002) + self.T * (0.6 + fl * 0.2) + fl * 2)
                    let pt = CGPoint(x: x, y: y)
                    if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
                    x += 10
                }
            }
        }
        c.R(0, 0, W, H, Col(0x04080e, 0.35))
        let fs = min(64.0, W * 0.11)
        let ty = H * 0.34
        c.text("BROADSIDE", W / 2 + 2, ty + 3, fs, Col(0x000000, 0.6), 0, FONTB)
        c.text("BROADSIDE", W / 2, ty, fs, GOLD, 0, FONTB)
        c.R(W / 2 - fs * 2.3, ty + 14, fs * 2.3 - 12, 1.5, GOLD2.alpha(0.8))
        c.R(W / 2 + 12, ty + 14, fs * 2.3 - 12, 1.5, GOLD2.alpha(0.8))
        c.save()
        c.translate(W / 2, ty + 14.75)
        c.rotate(PI / 4)
        c.R(-4, -4, 8, 8, GOLD)
        c.restore()
        c.text("From a pier and a fishing line to a ship of your own.", W / 2, ty + 46, 16, CREAM)
        c.text("Native build: the opening on the pier. More of the island follows.", W / 2, ty + 70, 13, CREAM.alpha(0.75))
        let bw = 190.0, bh = 44.0
        let bx = W / 2 - bw / 2, by = min(H - 64, ty + 94)
        titleBtn = (bx, by, bw, bh)
        c.RR(bx, by + 2.5, bw, bh, 10, Col(0x000000, 0.38))
        c.RRGrad(bx, by, bw, bh, 10, [(0, Col(0xf0d48c)), (1, Col(0xb98a34))])
        c.RRStroke(bx, by, bw, bh, 10, 1.3, Col(0xfff3cc))
        c.text("BEGIN", W / 2, by + bh / 2 + 6, 17, Col(0x2a1c08), 0, FONTB)
    }
}
