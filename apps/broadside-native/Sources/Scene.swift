import CoreGraphics
import Foundation

// Sky, sea, the far hills, palms, the player and the title. The island itself is in Island.swift.

extension Game {
    func draw(_ c: Canvas) {
        c.clear(W, H)
        let L = light
        drawSky(c, L)
        if mode == .title {
            drawTitle(c, L)
            return
        }
        c.save()
        if shake > 0 { c.translate(rnd(-shake, shake), rnd(-shake, shake)) }
        drawFarHills(c, L)
        drawRidge(c, L)
        drawBackSea(c, L)
        drawOffshore(c, L)
        drawLand(c, L)
        drawPier(c, L)
        drawScenery(c, L)
        drawBuildings(c, L)
        drawThings(c, L)
        if dog { drawDog(c, L) }
        if rowPhase == 0 { drawPerson(c, L) }
        drawFishing(c, L)
        drawFrontSea(c, L)
        drawEastSea(c, L)
        drawSparks(c)
        if L < 0.5 { c.R(-10, -10, W + 20, H + 20, Col(0x060c1c, 0.34 * (0.5 - L) / 0.5)) }
        drawNightLights(c, L)
        c.restore()
        drawPops(c)
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
    func drawBarrel(_ c: Canvas, _ wx: Double, _ wy: Double, _ r: Double, _ L: Double) {
        let X = sx(wx), Y = sy(wy) - 3 * camS, w = r * camS, hh = r * 2.4 * camS
        c.ell(X + w * 0.25, Y + 0.5, w * 1.25, w * 0.3, Col(0x000000, 0.2))
        c.linear(X - w, Y - hh, w * 2, hh, X - w, 0, X + w, 0, [(0, dn(0x150e08, 0x5a3c20, L)), (0.3, dn(0x22170c, 0xa47a48, L)), (1, dn(0x080503, 0x2c1b0e, L))])
        for f in [0.16, 0.5, 0.84] {
            c.R(X - w, Y - hh * f - 0.9 * camS, w * 2, 1.8 * camS, dn(0x0a0a0c, 0x3a3c42, L))
        }
        c.ell(X, Y - hh, w, w * 0.24, dn(0x1a120a, 0x8a6a40, L))
    }

    // ---------- the edge of town: market stall and two houses
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
    // ---------- the player
    func drawPerson(_ c: Canvas, _ L: Double) {
        let moving = abs(speed) > 4
        let amt = min(1.0, abs(speed) / 40)
        let bob = moving ? abs(sin(walkPh)) * 1.1 * amt : sin(T * 1.6) * 0.3
        c.save()
        let grow: Double = [0.74, 0.78, 0.84, 0.9, 0.9, 0.9][min(5, boat)]
        c.translate(sx(px), sy(groundLand(px)))
        c.scale(camS * face * grow, camS * grow)
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
        } else if haul == 2 {
            c.seg(0.5, shY, 6, shY - 6, 3.1, shirt)
            c.seg(6, shY - 6, 4, shY - 14, 2.7, skin)
            c.R(-9, shY - 31, 18, 16, self.lc(0x8a6238))
            c.R(-9, shY - 31, 18, 1.4, self.lc(0x4a2e14))
            c.R(-9, shY - 16.4, 18, 1.4, self.lc(0x4a2e14))
            c.seg(-9, shY - 31, 9, shY - 15, 1, self.lc(0x4a2e14))
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
            let y = sy(groundLand(px)) - 62 * camS
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
    // ---------- HUD
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
        c.text("Native build: the whole home island. The open sea follows.", W / 2, ty + 70, 13, CREAM.alpha(0.75))
        let bw = 190.0, bh = 44.0
        let bx = W / 2 - bw / 2, by = min(H - 64, ty + 94)
        titleBtn = (bx, by, bw, bh)
        c.RR(bx, by + 2.5, bw, bh, 10, Col(0x000000, 0.38))
        c.RRGrad(bx, by, bw, bh, 10, [(0, Col(0xf0d48c)), (1, Col(0xb98a34))])
        c.RRStroke(bx, by, bw, bh, 10, 1.3, Col(0xfff3cc))
        c.text("BEGIN", W / 2, by + bh / 2 + 6, 17, Col(0x2a1c08), 0, FONTB)
    }
}
