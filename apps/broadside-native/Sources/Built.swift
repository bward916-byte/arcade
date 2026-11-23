import CoreGraphics
import Foundation

// What you pay for and what moves: the eight buildings at three levels each, boats, beach finds, the dog,
// the fishing line, night lights, and the controls and HUD.

extension Game {
    func stoneRect(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        let k = camS
        c.linear(x, y, w, h, x, 0, x + w, 0, [(0, lc(0xb4ad9c)), (1, lc(0x6f6a5e))])
        let rh = 5 * k
        var r = 1.0
        while r * rh < h {
            c.R(x, y + r * rh, w, max(0.6, 0.5 * k), Col(0x000000, 0.2))
            r += 1
        }
    }
    func flameAt(_ c: Canvas, _ X: Double, _ Y: Double, _ sz: Double) {
        for i in 0..<4 {
            let fi = Double(i)
            let a = (T * 1.6 + fi * 0.27).truncatingRemainder(dividingBy: 1)
            c.ell(X + sin(T * 6 + fi) * sz * 0.25, Y - a * sz * 2.2, sz * (0.8 - a * 0.5), sz * (1.3 - a * 0.7), rgba(255, 130 + fi * 25, 40, 0.85 * (1 - a)))
        }
    }
    func drawBurnt(_ c: Canvas, _ wx: Double) {
        if !vis(wx, 60) { return }
        let k = camS
        let X = sx(wx), Y = sy(ground(wx))
        c.R(X - 22 * k, Y - 10 * k, 44 * k, 10 * k, Col(0x1a1410))
        c.poly(Col(0x1a1410), [X - 22 * k, Y - 10 * k, X - 16 * k, Y - 26 * k, X - 10 * k, Y - 10 * k])
        c.poly(Col(0x1a1410), [X + 6 * k, Y - 10 * k, X + 14 * k, Y - 22 * k, X + 20 * k, Y - 10 * k])
        for i in 0..<5 {
            let fi = Double(i)
            let a = (T * 1.4 + fi * 0.37).truncatingRemainder(dividingBy: 1)
            c.ell(X + (fi - 2) * 7 * k + sin(T * 5 + fi) * 2 * k, Y - (6 + a * 26) * k, (5 - a * 3) * k, (9 - a * 5) * k, rgba(255, 120 + fi * 20, 30, 0.8 * (1 - a)))
        }
        for i in 0..<4 {
            let fi = Double(i)
            let a = (T * 0.4 + fi * 0.25).truncatingRemainder(dividingBy: 1)
            c.circ(X + a * 20 * k, Y - (30 + a * 50) * k, (6 + a * 12) * k, Col(0x2a2622, 0.4 * (1 - a)))
        }
    }
    func drawStake(_ c: Canvas, _ wx: Double) {
        if !vis(wx, 20) { return }
        let k = camS
        let X = sx(wx), Y = sy(groundLand(wx))
        c.R(X - 1 * k, Y - 12 * k, 2 * k, 12 * k, Col(0x5a3c1e, 0.75))
        c.R(X - 6 * k, Y - 14 * k, 12 * k, 5 * k, Col(0xd8b86a, 0.75))
    }
    func drawSloop(_ c: Canvas, _ wx: Double, _ sc: Double) {
        if !vis(wx, 90) { return }
        c.save()
        c.translate(sx(wx), sy(wave(wx)))
        c.rotate(cos(wx * 0.02 + T * 1.2) * 0.04)
        c.scale(-camS * sc, camS * sc)
        c.pathFill(lc(0x7a5230)) { p in
            p.move(to: CGPoint(x: -34, y: -10))
            p.addQuadCurve(to: CGPoint(x: 36, y: -12), control: CGPoint(x: 0, y: -13))
            p.addLine(to: CGPoint(x: 24, y: 6))
            p.addLine(to: CGPoint(x: -24, y: 6))
            p.closeSubpath()
        }
        c.R(-32, -10.5, 66, 1.6, Col(0x000000, 0.25))
        c.R(-1.2, -62, 2.4, 52, lc(0x3a2512))
        c.poly(lc(0xeadfc4), [2, -60, 30, -14, 2, -14])
        c.poly(lc(0xd8ccae), [-2, -56, -22, -14, -2, -14])
        c.restore()
    }

    // ---------- the buildings you pay for
    func drawBuildings(_ c: Canvas, _ L: Double) {
        let k = camS
        for id in bldOrder {
            guard let b = bld[id] else { continue }
            if dmg.contains(id) {
                drawBurnt(c, b.x)
            } else if !done.contains(id), let u = upgs.first(where: { $0.id == id }), req(u) {
                drawStake(c, b.x)
            }
        }
        // fisher's hut: drying racks, then barrels and a chimney, then a smokehouse
        if done.contains("hut") {
            let lv = lvl("hut"), fl = Double(lv)
            var st = HouseStyle(wall: lv > 2 ? "plaster" : "wood", roof: lv > 2 ? "tile" : (lv > 1 ? "wood" : "thatch"), rh: 13 + fl, wins: [(12, -18)])
            if lv > 1 { st.wins = [(13, -18), (-13, -18)]; st.chimney = true }
            if lv > 2 { st.wins.append((0, -36)) }
            drawHouse(c, 520, 46 + fl * 4, 24 + fl * 7, st, L)
            for r in 0..<lv {
                let wx = 568 + Double(r) * 27
                if !vis(wx, 30) { continue }
                let X = sx(wx), Y = sy(ground(wx))
                c.seg(X - 12 * k, Y, X - 12 * k, Y - 22 * k, 1.5 * k, lc(0x5a3a1e))
                c.seg(X + 12 * k, Y, X + 12 * k, Y - 22 * k, 1.5 * k, lc(0x5a3a1e))
                c.seg(X - 13 * k, Y - 21 * k, X + 13 * k, Y - 21 * k, 1.5 * k, lc(0x5a3a1e))
                for i in 0..<5 {
                    let fx: Double = X - 9 * k + Double(i) * 4.5 * k
                    c.ell(fx, Y - 16 * k + sin(T * 1.5 + Double(i + r)) * 0.4 * k, 1.3 * k, 4 * k, lc(0x9fb8c8))
                }
            }
            if lv > 1 {
                drawBarrel(c, 486, ground(486) + 3, 4.5, L)
                drawBarrel(c, 477, ground(477) + 3, 4, L)
            }
            if lv > 2 && vis(462, 30) {
                let X = sx(462), Y = sy(ground(462))
                stoneRect(c, X - 9 * k, Y - 22 * k, 18 * k, 22 * k)
                c.poly(lc(0x5a3a1e), [X - 12 * k, Y - 22 * k, X, Y - 33 * k, X + 12 * k, Y - 22 * k])
                c.R(X - 3 * k, Y - 11 * k, 6 * k, 11 * k, Col(0x1a120a))
                for i in 0..<3 {
                    let a = (T * 0.35 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                    c.circ(X + a * 8 * k, Y - (34 + a * 26) * k, (3 + a * 6) * k, Col(0xd8d4cc, 0.35 * (1 - a)))
                }
            }
        }
        // sawmill: a turning blade, log piles, then stone walls and a crane
        if done.contains("mill") {
            let lv = lvl("mill"), fl = Double(lv)
            var st = HouseStyle(wall: lv > 2 ? "stone" : "wood", roof: lv > 2 ? "tile" : "wood", rh: 16 + fl, wins: [(-22, -26)])
            if lv > 1 { st.wins.append((12, -26)) }
            st.chimney = lv > 2
            drawHouse(c, 2745, 72 + fl * 2, 34 + fl * 7, st, L)
            for pl in 0..<lv {
                let wx = 2800 + Double(pl) * 30
                if !vis(wx, 30) { continue }
                let X = sx(wx), Y = sy(ground(wx))
                let rows = 2 + min(2, pl + 1)
                for r in 0..<rows {
                    for i in 0..<(rows - r) {
                        let off: Double = Double(i) * 9 + Double(r) * 4.5 - Double(rows - 1) * 4.5
                        let cx: Double = X + off * k
                        let cy: Double = Y - (4 + Double(r) * 7.5) * k
                        c.circ(cx, cy, 4.4 * k, lc(0x7a5632))
                        c.circStroke(cx, cy, 4.4 * k, 0.8, Col(0x2a180c))
                        c.circ(cx, cy, 1.6 * k, lc(0xb08a58))
                    }
                }
            }
            if vis(2700, 40) {
                let R = 8 + fl * 3.5
                c.save()
                c.translate(sx(2700), sy(ground(2745)) - (18 + fl * 4) * k)
                c.scale(k, k)
                c.R(-2, 0, 4, 18 + fl * 4, lc(0x5a3a1e))
                c.rotate(T * (1.4 + fl * 0.3))
                c.circStroke(0, 0, R, 1.6, lc(0xa8b0b4))
                let teeth = 8 + lv * 2
                for i in 0..<teeth {
                    let a = Double(i) * 2 * PI / Double(teeth)
                    c.seg(cos(a) * R, sin(a) * R, cos(a + 0.25) * (R + 3), sin(a + 0.25) * (R + 3), 1.4, lc(0xa8b0b4))
                }
                c.circ(0, 0, 2, lc(0x4a4e54))
                c.restore()
            }
            if lv > 2 && vis(2668, 40) {
                let X = sx(2668), Y = sy(ground(2668))
                c.seg(X, Y, X, Y - 50 * k, 2.5 * k, lc(0x5a3a1e))
                c.seg(X - 3 * k, Y - 46 * k, X + 26 * k, Y - 56 * k, 2.5 * k, lc(0x5a3a1e))
                c.seg(X, Y - 30 * k, X + 12 * k, Y - 51 * k, 2.5 * k, lc(0x5a3a1e))
                let sw = sin(T * 1.3) * 2 * k
                c.seg(X + 26 * k, Y - 56 * k, X + 26 * k + sw, Y - 24 * k, 0.8 * k, Col(0x222222))
                c.ell(X + 26 * k + sw, Y - 21 * k, 7 * k, 3.4 * k, lc(0x7a5632))
            }
        }
        // farm: crops that ripen, then haystacks, then a silo
        if done.contains("farm") {
            let lv = lvl("farm"), fl = Double(lv)
            var st = HouseStyle(wall: lv > 2 ? "stone" : "plaster", roof: lv > 2 ? "tile" : (lv > 1 ? "wood" : "thatch"), rh: 15 + fl, wins: [(-14, -22)], chimney: true)
            if lv > 1 { st.wins.append((12, -22)) }
            drawHouse(c, 2850, 56 + fl * 2, 28 + fl * 7, st, L)
            for r in 0..<14 {
                let wx = 2900 + Double(r) * 13
                if !vis(wx, 20) { continue }
                let X = sx(wx), Y = sy(ground(wx)), hh = (10 + fl * 4) * k
                c.ell(X, Y + 1 * k, 7 * k, 1.6 * k, Col(0x5a3c1e, 0.5))
                let ripe = min(1.0, (fl - 1) * 0.45 + 0.25 + 0.25 * sin(Double(r)))
                let col = Col.mix(lc(0x5a8a2a), lc(0xd8b83a), ripe)
                for j in -1...1 {
                    let fj = Double(j)
                    let sway = sin(T * 1.4 + wx * 0.1 + fj) * 1.2 * k
                    c.seg(X + fj * 3 * k, Y, X + fj * 3.6 * k + sway, Y - hh, 1.4 * k, col)
                    if lv > 1 { c.ell(X + fj * 3.6 * k + sway, Y - hh, 1.3 * k, 2.6 * k, col) }
                }
            }
            var fx = 2895.0
            while fx <= 3085 {
                if vis(fx, 30) {
                    let X = sx(fx), Y = sy(ground(fx))
                    c.R(X - 1 * k, Y - 11 * k, 2 * k, 11 * k, lc(0x5a3a1e))
                    if fx < 3085 { c.seg(X, Y - 8 * k, sx(fx + 24), sy(ground(fx + 24)) - 8 * k, 1.2 * k, lc(0x5a3a1e)) }
                }
                fx += 24
            }
            for i in 0..<(lv - 1) {
                let wx = 2808 - Double(i) * 20
                if !vis(wx, 20) { continue }
                let X = sx(wx), Y = sy(ground(wx))
                c.pathFill(lc(0xe8cc6a)) { p in
                    p.move(to: CGPoint(x: X - 9 * k, y: Y))
                    p.addQuadCurve(to: CGPoint(x: X, y: Y - 19 * k), control: CGPoint(x: X - 9 * k, y: Y - 17 * k))
                    p.addQuadCurve(to: CGPoint(x: X + 9 * k, y: Y), control: CGPoint(x: X + 9 * k, y: Y - 17 * k))
                    p.closeSubpath()
                }
            }
            if lv > 2 && vis(2888, 30) {
                let X = sx(2888), Y = sy(ground(2888))
                stoneRect(c, X - 8 * k, Y - 44 * k, 16 * k, 44 * k)
                c.poly(lc(0x9a4a32), [X - 10 * k, Y - 44 * k, X, Y - 58 * k, X + 10 * k, Y - 44 * k])
                c.R(X - 2.5 * k, Y - 9 * k, 5 * k, 9 * k, Col(0x1a120a))
            }
            if vis(3010, 30) {
                let X = sx(3010), Y = sy(ground(3010))
                c.seg(X, Y, X, Y - 30 * k, 2 * k, lc(0x4a2e14))
                c.seg(X - 11 * k, Y - 23 * k, X + 11 * k, Y - 23 * k, 2 * k, lc(0x4a2e14))
                c.R(X - 6 * k, Y - 25 * k, 12 * k, 12 * k, lc(0x8a3a2a))
                c.circ(X, Y - 30 * k, 3.6 * k, lc(0xd4b04a))
                c.poly(lc(0x5a4028), [X - 6 * k, Y - 32 * k, X, Y - 39 * k, X + 6 * k, Y - 32 * k])
            }
        }
        // smithy: forge glow, then a weapon rack, then stacked cannon
        if done.contains("smithy") {
            let lv = lvl("smithy"), fl = Double(lv)
            var st = HouseStyle(wall: "stone", roof: "tile", rh: 14 + fl, wins: [(16, -22)], chimney: true)
            if lv > 1 { st.wins.append((-16, -22)) }
            drawHouse(c, 3130, 58 + fl * 2, 30 + fl * 7, st, L)
            if vis(3085, 60) {
                let X = sx(3085), Y = sy(ground(3085))
                for a2 in 0..<(lv > 2 ? 2 : 1) {
                    let AX: Double = X - Double(a2) * 18 * k
                    c.poly(lc(0x3a3a40), [AX - 9 * k, Y - 12 * k, AX + 8 * k, Y - 12 * k, AX + 4 * k, Y - 8 * k, AX + 3 * k, Y, AX - 4 * k, Y, AX - 3 * k, Y - 8 * k])
                }
                for i in 0..<5 {
                    let fi = Double(i)
                    let a = (T * 0.9 + fi * 0.2).truncatingRemainder(dividingBy: 1)
                    c.R(X + sin(fi * 3 + T * 3) * 8 * k, Y - (12 + a * 22) * k, 1.4 * k, 1.4 * k, rgba(255, 160 + fi * 15, 60, 1 - a))
                }
                let gx = sx(3130), gy = sy(ground(3130)) - 14 * k
                c.glow(gx, gy, (20 + fl * 8) * k, Col(0xff8c28, 0.3 + fl * 0.07 + 0.15 * sin(T * 7)), Col(0xff8c28, 0))
            }
            if lv > 1 && vis(3174, 30) {
                let X = sx(3174), Y = sy(ground(3174))
                c.seg(X - 10 * k, Y, X - 10 * k, Y - 20 * k, 1.6 * k, lc(0x5a3a1e))
                c.seg(X + 10 * k, Y, X + 10 * k, Y - 20 * k, 1.6 * k, lc(0x5a3a1e))
                c.seg(X - 11 * k, Y - 18 * k, X + 11 * k, Y - 18 * k, 1.6 * k, lc(0x5a3a1e))
                for i in 0..<4 {
                    let bx: Double = X - 7.5 * k + Double(i) * 5 * k
                    c.seg(bx, Y - 18 * k, bx, Y - 4 * k, 1.2 * k, lc(0xb0b8c0))
                    c.R(bx - 1.6 * k, Y - 16 * k, 3.2 * k, 1 * k, lc(0x8a6a20))
                }
            }
            if lv > 2 && vis(3196, 30) {
                let X = sx(3196), Y = sy(ground(3196))
                for r in 0..<2 {
                    for i in 0..<(2 - r) {
                        let off: Double = Double(i) * 7 + Double(r) * 3.5
                        c.R(X + (off - 10) * k, Y - (5 + Double(r) * 5) * k, 20 * k, 4.4 * k, lc(0x2e3038))
                        c.circ(X + (off + 10) * k, Y - (2.8 + Double(r) * 5) * k, 2.2 * k, Col(0x0a0a0e))
                    }
                }
            }
        }
        // watchtower: timber frame, taller, then stone
        if done.contains("tower") && vis(2275, 60) {
            let lv = lvl("tower")
            let X = sx(2275), Y = sy(ground(2275))
            var topY = Y
            if lv < 3 {
                let hgt = 78 + Double(lv - 1) * 26
                let n = 3 + (lv - 1)
                c.seg(X - 16 * k, Y, X - 10 * k, Y - hgt * k, 4 * k, lc(0x8a6238))
                c.seg(X + 16 * k, Y, X + 10 * k, Y - hgt * k, 4 * k, lc(0x8a6238))
                for i in 0..<n {
                    let f0 = Double(i) / Double(n), f1 = Double(i + 1) / Double(n)
                    let w0: Double = (16 - 6 * f0) * k
                    let w1: Double = (16 - 6 * f1) * k
                    let ya: Double = Y - hgt * f0 * k
                    let yb: Double = Y - hgt * f1 * k
                    c.seg(X - w0, ya, X + w1, yb, 2 * k, lc(0x4a2e14))
                    c.seg(X + w0, ya, X - w1, yb, 2 * k, lc(0x4a2e14))
                    c.seg(X - w1, yb, X + w1, yb, 2 * k, lc(0x4a2e14))
                }
                topY = Y - hgt * k
                c.R(X - 17 * k, topY - 3 * k, 34 * k, 4 * k, lc(0x8a6238))
                c.R(X - 17 * k, topY - 13 * k, 34 * k, 2 * k, lc(0x5a3a1e))
                for dx in [-16.0, -5, 5, 15] { c.R(X + dx * k, topY - 13 * k, 1.6 * k, 11 * k, lc(0x5a3a1e)) }
                c.poly(lc(0x5e4430), [X - 21 * k, topY - 26 * k, X, topY - 40 * k, X + 21 * k, topY - 26 * k])
                c.R(X - 15 * k, topY - 26 * k, 1.6 * k, 14 * k, lc(0x5a3a1e))
                c.R(X + 13.4 * k, topY - 26 * k, 1.6 * k, 14 * k, lc(0x5a3a1e))
                topY -= 40 * k
            } else {
                let hgt = 138.0
                stoneRect(c, X - 15 * k, Y - hgt * k, 30 * k, hgt * k)
                stoneRect(c, X - 19 * k, Y - (hgt + 4) * k, 38 * k, 5 * k)
                for m in 0..<5 { stoneRect(c, X - 19 * k + Double(m) * 8.4 * k, Y - (hgt + 11) * k, 4.6 * k, 7 * k) }
                for wy in [40.0, 78, 112] {
                    c.arch(X - 2.5 * k, Y - (wy + 2.5) * k, 5 * k, 10.5 * k, L < 0.5 ? Col(0xffcc66) : Col(0x141018))
                }
                c.arch(X - 4 * k, Y - 13 * k, 8 * k, 13 * k, Col(0x2a1a0e))
                topY = Y - (hgt + 11) * k
            }
            c.R(X - 0.8 * k, topY - 22 * k, 1.6 * k, 22 * k, lc(0x3a2512))
            c.poly(lc(0x1f4a9c), [X + 0.8 * k, topY - 22 * k, X + 16 * k, topY - 19 * k + sin(T * 5) * 2 * k, X + 0.8 * k, topY - 13 * k])
        }
        // gun battery: three guns, then gabions and a fourth, then a stone parapet and a fifth
        if done.contains("battery") && vis(2215, 120) {
            let lv = lvl("battery")
            let n = 3 + (lv - 1)
            let x0 = 2196 - Double(lv - 1) * 9
            if lv > 2 {
                let a = sx(x0 - 16), b = sx(x0 + Double(n) * 17 + 2), Y = sy(ground(2215))
                stoneRect(c, a, Y - 9 * k, b - a, 9 * k)
                for m in 0...n { stoneRect(c, sx(x0 - 14 + Double(m) * 17), Y - 15 * k, 8 * k, 6 * k) }
            }
            for i in 0..<n {
                let wx = x0 + Double(i) * 17
                let X = sx(wx), Y = sy(ground(wx))
                c.R(X - 6 * k, Y - 7 * k, 12 * k, 5 * k, lc(0x5a3a1e))
                c.circStroke(X - 3 * k, Y - 3 * k, 3.2 * k, 1.5 * k, lc(0x3a2512))
                c.save()
                c.translate(X, Y - 8 * k)
                c.rotate(PI + 0.25)
                c.R(-2 * k, -2.6 * k, 20 * k, 5.2 * k, lc(0x2e3038))
                c.R(16 * k, -3.2 * k, 2.4 * k, 6.4 * k, lc(0x1a1a1e))
                c.restore()
                if lv == 2 && i < n - 1 {
                    let GX = X + 8.5 * k
                    c.R(GX - 3.5 * k, Y - 11 * k, 7 * k, 11 * k, lc(0xa08a5a))
                    for q in 1..<4 { c.R(GX - 3.5 * k, Y - Double(q) * 2.8 * k, 7 * k, 0.7, Col(0x3c2814, 0.6)) }
                }
            }
            for i in 0..<(3 + lv * 2) {
                let r: Double = i > 3 ? 1 : 0
                let up: Double = 2.5 + r * 3.2 + (i > 6 ? 3.2 : 0)
                c.circ(sx(2262) + Double(i % 4) * 3.5 * k + r * 1.7 * k, sy(ground(2262)) - up * k, 2.2 * k, Col(0x1a1a1e))
            }
            if lv > 2 {
                let FX = sx(x0 - 24), FY = sy(ground(x0 - 24))
                c.R(FX, FY - 40 * k, 1.6 * k, 40 * k, lc(0x3a2512))
                c.poly(lc(0xb0171f), [FX + 1.6 * k, FY - 40 * k, FX + 18 * k, FY - 36 * k + sin(T * 5) * 2 * k, FX + 1.6 * k, FY - 30 * k])
            }
            if raiding && sin(T * 9) > 0.93 {
                c.circ(sx(x0 - 6) - 14 * k, sy(ground(x0 - 6)) - 12 * k, 8 * k, Col(0xffdc78, 0.9))
            }
        }
        // palisade: stakes, then taller with torches, then a stone wall and gate
        if done.contains("wall") && vis(3270, 90) {
            let lv = lvl("wall")
            if lv < 3 {
                var wx = 3238.0
                while wx <= 3304 {
                    let X = sx(wx), Y = sy(ground(wx))
                    let h: Double = (30 + Double(lv - 1) * 12 + Double(Int(wx * 7) % 5)) * k
                    c.poly(lc(0x8a6238), [X - 3 * k, Y + 2 * k, X - 3 * k, Y - h, X, Y - h - 6 * k, X + 3 * k, Y - h, X + 3 * k, Y + 2 * k])
                    c.R(X - 3 * k, Y - h, 1.5 * k, h, Col(0x000000, 0.25))
                    wx += 6
                }
                c.R(sx(3236), sy(ground(3270)) - 18 * k, sx(3306) - sx(3236), 2.5 * k, lc(0x4a2e14))
                if lv > 1 {
                    c.R(sx(3236), sy(ground(3270)) - 34 * k, sx(3306) - sx(3236), 2.5 * k, lc(0x4a2e14))
                    for tx2 in [3240.0, 3302] {
                        let X = sx(tx2), Y = sy(ground(tx2)) - 50 * k
                        c.R(X - 1 * k, Y, 2 * k, 8 * k, Col(0x2a1a0e))
                        flameAt(c, X, Y, 2.2 * k)
                    }
                }
            } else {
                let a = sx(3236), b = sx(3306), Y = sy(ground(3270))
                stoneRect(c, a, Y - 50 * k, b - a, 52 * k)
                for m in 0..<6 { stoneRect(c, a + Double(m) * (b - a - 7 * k) / 5, Y - 57 * k, 7 * k, 7 * k) }
                for f in [0.2, 0.8] { c.R(a + (b - a) * f - 1 * k, Y - 36 * k, 2 * k, 9 * k, Col(0x141018)) }
                let gx = (a + b) / 2
                c.arch(gx - 9 * k, Y - 26 * k, 18 * k, 28 * k, Col(0x2a1a0e))
                c.R(gx - 0.5 * k, Y - 24 * k, 1 * k, 26 * k, Col(0x000000, 0.4))
                for tx2 in [a + 6 * k, b - 6 * k] { flameAt(c, tx2, Y - 62 * k, 2.2 * k) }
            }
        }
        // east dock: a jetty and a trader, then a longer jetty, a crane and a second, then lamps and a big ship
        if done.contains("dock2") && vis(3520, 400) {
            let lv = lvl("dock2")
            let deck = sy(-12)
            let xe = 3540 + Double(lv - 1) * 40
            var x = 3440.0
            while x <= xe {
                let X = sx(x)
                c.linear(X - 2.5 * k, deck, 5 * k, H - deck, X - 2.5 * k, 0, X + 2.5 * k, 0, [(0, dn(0x1c120a, 0x6e4a26, L)), (1, dn(0x0a0604, 0x2e1c0e, L))])
                x += 33
            }
            let x0 = sx(3425), x1 = sx(xe + 10)
            c.vfill(x0, deck - 4 * k, x1 - x0, 6 * k, [(0, dn(0x2a1c10, 0x9a7446, L)), (1, dn(0x160e08, 0x5e4226, L))])
            var pl = 3428.0
            while pl < xe + 10 {
                c.R(sx(pl), deck - 4 * k, 1 * k, 6 * k, Col(0x000000, 0.3))
                pl += 9
            }
            drawSloop(c, xe + 60, 1)
            if lv > 1 { drawSloop(c, xe + 150, 0.85) }
            if lv > 2 { drawSloop(c, xe + 250, 1.5) }
            drawBarrel(c, 3445, -13, 4.5, L)
            drawBarrel(c, 3456, -13, 4.5, L)
            if lv > 1 {
                drawBarrel(c, 3470, -13, 4.5, L)
                drawBarrel(c, 3481, -13, 4.5, L)
                let X = sx(3520), Y = deck - 4 * k
                c.seg(X, Y, X, Y - 40 * k, 2.4 * k, lc(0x5a3a1e))
                c.seg(X - 3 * k, Y - 36 * k, X + 24 * k, Y - 46 * k, 2.4 * k, lc(0x5a3a1e))
                c.seg(X, Y - 22 * k, X + 11 * k, Y - 41 * k, 2.4 * k, lc(0x5a3a1e))
                c.seg(X + 24 * k, Y - 46 * k, X + 24 * k, Y - 18 * k, 0.8 * k, Col(0x222222))
                c.R(X + 19 * k, Y - 18 * k, 10 * k, 9 * k, lc(0x8a6238))
            }
            if lv > 2 {
                for wx in [3440.0, 3500, 3560, 3610] {
                    let X = sx(wx), Y = deck - 4 * k
                    c.R(X - 1 * k, Y - 22 * k, 2 * k, 22 * k, Col(0x2a1a0e))
                    c.R(X - 2.5 * k, Y - 27 * k, 5 * k, 6 * k, L < 0.5 ? Col(0xffd27a) : Col(0xb89a5a))
                }
            }
        }
        // coin piles waiting to be collected
        for id in bldOrder {
            guard let b = bld[id], let g = pile[id], g > 0, vis(b.x, 30) else { continue }
            let X = sx(b.x), Y = sy(groundLand(b.x)) - 66 * k + sin(T * 3) * 2 * k
            let n = min(5, (g + 5) / 6)
            c.glow(X, Y - 4, 22, Col(0xffdc6e, 0.35), Col(0xffdc6e, 0))
            for i in 0..<n {
                c.ell(X, Y - Double(i) * 3.2, 8, 3.4, Col(0xffd24a))
                c.ellStroke(X, Y - Double(i) * 3.2, 8, 3.4, 1, Col(0x8a6a10))
            }
        }
    }

    // ---------- boats, beach finds, and the catch
    func drawThings(_ c: Canvas, _ L: Double) {
        let k = camS
        for it in items where vis(it.x, 10) {
            let x = sx(it.x), y = sy(ground(it.x))
            c.ell(x, y, 4 * k, 1.2 * k, Col(0x000000, 0.2))
            if it.shell {
                c.dome(x, y - 0.5 * k, 3.5 * k, lc(0xf4e6d6))
                for i in -2...2 { c.seg(x, y - 0.5 * k, x + Double(i) * 1.5 * k, y - 3.6 * k, 0.7, Col(0xb48c78, 0.7)) }
            } else {
                c.save()
                c.translate(x, y - 2 * k)
                c.rotate(-0.5)
                c.RR(-4 * k, -1.8 * k, 8 * k, 3.6 * k, 1.4 * k, lc(0x4a8a5a))
                c.R(3.6 * k, -0.9 * k, 3 * k, 1.8 * k, lc(0x4a8a5a))
                c.R(6.2 * k, -1.1 * k, 1.2 * k, 2.2 * k, lc(0xb08a58))
                c.restore()
            }
            if it.pick { c.circStroke(x, y - 2 * k, 7 * k, 1, GOLD.alpha(0.6 + 0.3 * sin(T * 6))) }
        }
        // your boat: tied at the pier, or out on the water
        let out = rowPhase > 0
        if out || (boat >= 1 && boat < 3) {
            let bx: Double = out ? rowX : -250
            if vis(bx, 80) {
                c.save()
                c.translate(sx(bx), sy(wave(bx)) + 1)
                c.rotate(cos(bx * 0.02 + T * 1.2) * 0.045)
                c.scale(k, k)
                c.pathFill(lc(0x7a5230)) { p in
                    p.move(to: CGPoint(x: -26, y: -7))
                    p.addQuadCurve(to: CGPoint(x: 26, y: -7), control: CGPoint(x: 0, y: -9))
                    p.addLine(to: CGPoint(x: 16, y: 5))
                    p.addLine(to: CGPoint(x: -16, y: 5))
                    p.closeSubpath()
                }
                c.R(-24, -7.4, 48, 1.5, lc(0xb08a58))
                c.R(-14, -6, 28, 1.5, lc(0x3a2512))
                if boat >= 2 {
                    c.R(-1, -47, 2.5, 40, lc(0x3a2512))
                    c.pathFill(lc(0xeadfc4)) { p in
                        p.move(to: CGPoint(x: 1, y: -45))
                        p.addQuadCurve(to: CGPoint(x: 22, y: -10), control: CGPoint(x: 14, y: -30))
                        p.addLine(to: CGPoint(x: 1, y: -10))
                        p.closeSubpath()
                    }
                }
                if out {
                    // you, sitting at the oars or the line
                    let rowing = rowPhase != 2
                    let sw: Double = rowing ? sin(T * 3) : 0
                    c.R(-5, -10, 9, 4, lc(0x4a3a28))
                    c.R(-4, -22, 7, 13, lc(0xd9d2c0))
                    c.circ(-0.5, -26, 3.6, lc(0xe0b088))
                    c.dome(-0.5, -26.6, 3.8, lc(0x3a2a1a))
                    c.roundCaps(true)
                    if rowing {
                        c.seg(-1, -19, -8 + sw * 3, -13, 2.6, lc(0xd9d2c0))
                        if boat < 2 { c.seg(-6, -14, -22 + sw * 6, 6, 1.5, lc(0x5a3a1e)) }
                    } else {
                        c.seg(-1, -19, -8, -17, 2.6, lc(0xd9d2c0))
                    }
                    c.roundCaps(false)
                }
                c.restore()
            }
        }
        if done.contains("lantern") && L < 0.5 {
            let X: Double = sx(out ? rowX : -215)
            let Y: Double = sy(out ? -20 : -40)
            c.glow(X, Y, 70 * k, Col(0xffdc78, 0.4), Col(0xffdc78, 0))
        }
    }

    func drawDog(_ c: Canvas, _ L: Double) {
        if !vis(dogX, 30) { return }
        let mv = abs(dogSp) > 6
        let bob = mv ? abs(sin(dogPh * 2)) * 1.2 : 0
        c.save()
        c.translate(sx(dogX), sy(groundLand(dogX)))
        c.scale(dogFace * camS * 1.25, camS * 1.25)
        c.ell(0, 0.5, 10, 1.6, Col(0x000000, 0.14 + 0.1 * L))
        let col = lc(0x9a7646), dk = lc(0x5e4222)
        c.roundCaps(true)
        func leg(_ x: Double, _ ph: Double, _ colr: Col) {
            let a = mv ? sin(dogPh + ph) * 0.7 : 0
            let lift = mv ? max(0, cos(dogPh + ph)) * 1.6 : 0
            c.seg(x, -6, x + sin(a) * 4, -0.3 - lift, 2, colr)
        }
        leg(-5, 0, dk); leg(5.5, PI, dk)
        leg(-6.5, PI, col); leg(4, 0, col)
        c.ell(0, -7.5 - bob, 8.5, 3.6, col)
        c.curve(-8, -8.5 - bob, -12, -12 - bob, -11 + sin(T * (mv ? 16 : 5)) * 2.4, -15.5 - bob, 1.8, col)
        c.roundCaps(false)
        let hy = -11.5 - bob, hx = 9.5
        c.ell(hx, hy, 3.6, 3.1, col)
        c.ell(hx + 3.4, hy + 0.9, 2.3, 1.6, col)
        c.ell(hx - 1.6, hy - 1.5, 1.5, 2.9, dk)
        c.circ(hx + 5.4, hy + 0.6, 0.8, Col(0x0a0a0c))
        c.circ(hx + 1.3, hy - 0.8, 0.6, Col(0x0a0a0c))
        if !mv && sin(T * 5) > 0.2 { c.ell(hx + 3.6, hy + 2.6, 0.8, 1.5, Col(0xd8607a)) }
        c.restore()
    }

    // ---------- the fishing line
    func drawFishing(_ c: Canvas, _ L: Double) {
        if !fishing { return }
        let k = camS
        let out = rowPhase > 0
        let ox: Double = out ? rowX : px
        let oy: Double = out ? wave(rowX) - 16 : groundLand(px) - 25
        let hx = sx(ox - 12), hy = sy(oy)
        let tipX = sx(ox - 38), tipY = sy(oy - 20)
        c.curve(hx, hy, (hx + tipX) / 2, hy - 14 * k, tipX, tipY, 1.6 * k, lc(0x8a5a2a))
        let fwx = ox - 62
        let bite = fishPhase == 1
        let bob = bite ? sin(T * 26) * 3.2 : sin(T * 2.2) * 0.8
        let fx = sx(fwx), fy = sy(wave(fwx) + bob)
        if fishPhase == 2 {
            // the catch comes up out of the water
            let u = min(1.0, fishT / 0.7)
            let cx2 = lerp(fx, tipX, u), cy2 = lerp(fy, tipY + 10 * k, u) - sin(u * PI) * 16 * k
            c.seg(tipX, tipY, cx2, cy2, 0.8, Col(0xf0f0f0, 0.75))
            c.ell(cx2, cy2 + 4 * k, 2.4 * k, 5 * k, lc(0xbfe0f0))
            c.poly(lc(0xbfe0f0), [cx2, cy2 + 8 * k, cx2 - 2.6 * k, cy2 + 12 * k, cx2 + 2.6 * k, cy2 + 12 * k])
            return
        }
        c.curve(tipX, tipY, (tipX + fx) / 2, (tipY + fy) / 2 + (bite ? 2 : 14) * k, fx, fy, 0.8, Col(0xf0f0f0, 0.75))
        c.circ(fx, fy, 2.2 * k, Col(0xd03a2a))
        c.circ(fx, fy - 1.2 * k, 1.3 * k, Col(0xf4f0e6))
        if bite {
            for i in 0..<3 {
                let u = (fishT * 1.4 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                c.ellStroke(fx, fy, (3 + u * 16) * k, (1 + u * 3) * k, 1, Col(0xf0faff, 0.7 * (1 - u)))
            }
        }
    }

    // ---------- lamps and beams, drawn over the dark
    func drawNightLights(_ c: Canvas, _ L: Double) {
        if L >= 0.5 { return }
        let k = camS
        let a = (0.5 - L) * 2
        c.blend(.plusLighter)
        for lx in [915.0, 1148, 1345, 1622, 2400, 2905, 3210] where vis(lx, 80) {
            let X = sx(lx), Y = sy(ground(lx))
            c.glow(X, Y - 52 * k, 70 * k, Col(0xffcd78, 0.5 * a), Col(0xffcd78, 0))
            c.glow(X, Y + 2 * k, 40 * k, Col(0xffcd78, 0.18 * a), Col(0xffcd78, 0))
        }
        if vis(-229, 80) { c.glow(sx(-229), sy(-22) - 38 * k, 60 * k, Col(0xffc864, 0.45 * a), Col(0xffb450, 0)) }
        for lx in [1226.0, 1274] where vis(lx, 40) {
            let X = sx(lx), Y = sy(ground(1250)) - 30 * k
            c.glow(X, Y, 28 * k, Col(0xffbe5a, 0.5 * a), Col(0xffbe5a, 0))
            c.R(X - 2 * k, Y - 3 * k, 4 * k, 6 * k, Col(0xffcc66))
        }
        // the lighthouse sweeps the bay
        if done.contains("light") && vis(-338, 900) {
            let X = sx(-338), Y = sy(wave(-338) * 0.3) - (22 + 96 + 7) * k
            c.glow(X, Y, 30 * k, Col(0xfff4be, 0.8 * a), Col(0xfff4be, 0))
            for sd in [0.0, PI] {
                let cs = cos(T * 0.9 + sd)
                if abs(cs) < 0.12 { continue }
                let len = W * 0.7 * abs(cs), d = sgn(cs)
                c.pathFill(Col(0xfff4be, 0.16 * a * abs(cs))) { p in
                    p.move(to: CGPoint(x: X, y: Y))
                    p.addLine(to: CGPoint(x: X + d * len, y: Y - 26 * k))
                    p.addLine(to: CGPoint(x: X + d * len, y: Y + 30 * k))
                    p.closeSubpath()
                }
            }
        }
        c.blend(.normal)
    }

    func drawPops(_ c: Canvas) {
        for p in pops {
            let a = 1 - p.t / 1.2
            c.textS(p.txt, sx(p.x), sy(p.y) - p.t * 26, 17, Col(0xffd24a, a), 0, FONTB)
        }
    }

    // ---------- the round controls: actions that spin, and coin circles you pour into
    func drawRings(_ c: Canvas, _ L: Double) {
        rings = []
        if rowPhase > 0 { return }
        var used: [Double] = []
        func place(_ wantX: Double) -> Double {
            var x = clampD(wantX, 40 + safeL, W - 40 - safeR)
            for _ in 0..<8 {
                var moved = false
                for u in used where abs(u - x) < 62 {
                    x = u + (x >= u ? 62 : -62)
                    moved = true
                }
                if !moved { break }
            }
            used.append(x)
            return x
        }
        let headY = sy(groundLand(px)) - 100 * camS
        let y = max(118.0, headY)
        let r = 22.0
        var all: [(Double, String, Bool, String)] = []
        for sp in prompts() { all.append((sp.x, sp.id, false, sp.id)) }
        for u in upgradesHere() { all.append((u.x, u.id, true, u.icon)) }
        all.sort { $0.0 < $1.0 }
        for (wx, id, isPour, icon) in all {
            let x = place(sx(wx))
            rings.append(Ring(id: id, x: x, y: y, r: r, pour: isPour))
            c.circ(x, y + 3, r + 2, Col(0x000000, 0.28))
            if !isPour {
                let busy = (id == "fish" && fishing) || (id == spinId && spinT > 0)
                c.glow(x - 6, y - 8, r * 1.2, Col(0x3c4a5c, 0.95), Col(0x08121c, 0.95))
                c.circ(x, y, r, Col(0x08121c, 0.55))
                c.circStroke(x, y, r, 2, busy ? Col(0xfff0c0) : GOLD)
                c.save()
                c.translate(x, y)
                if busy { c.rotate(T * 5) }
                drawIcon(c, id == "row" && boat >= 2 ? "skiff" : id)
                c.restore()
                if id == "haul" { c.textS(String(crates), x + r - 2, y - r + 6, 12, CREAM, 0, FONTB) }
                continue
            }
            guard let u = upgs.first(where: { $0.id == id }) else { continue }
            let cost = costOf(u)
            let have = paid[id] ?? 0
            c.circ(x, y, r, Col(0x101a28, 0.92))
            if have > 0 {
                c.arcStroke(x, y, r, -PI / 2, -PI / 2 + 2 * PI * Double(have) / Double(cost), 4, GOLD)
            }
            c.circStroke(x, y, r, 1.4, GOLD2.alpha(0.8))
            c.save()
            c.translate(x, y)
            drawIcon(c, icon)
            c.restore()
            if u.tier > 0 {
                for i in 0..<u.tier { c.circ(x - Double(u.tier - 1) * 3 + Double(i) * 6, y + r - 5, 1.8, CREAM) }
            }
            // coin blanks above, filled as you pour: rows of six, the last row centred
            let shown = min(12, cost)
            let per = Double(cost) / Double(shown)
            let rows = (shown + 5) / 6
            for i in 0..<shown {
                let row = i / 6
                let inRow = row == rows - 1 ? shown - row * 6 : 6
                let col = i % 6
                let bx = x + (Double(col) - Double(inRow - 1) / 2) * 9.6
                let by = y - r - 10 - Double(rows - 1 - row) * 9.6
                let on = Double(have) >= per * Double(i + 1) - 0.001
                c.circ(bx, by, 3.9, on ? Col(0xffd24a) : Col(0x0a1018, 0.75))
                c.circStroke(bx, by, 3.9, 1, on ? Col(0x8a6a10) : Col(0xd8b86a, 0.5))
            }
            c.textS(String(cost - have), x, y + r + 15, 12, coins >= cost - have ? CREAM : Col(0xe89a8a), 0, FONTB)
            if pour == id {
                let fromX = sx(px), fromY = sy(groundLand(px)) - 40 * camS
                for q in 0..<4 {
                    let f = (T * 3.2 + Double(q) * 0.25).truncatingRemainder(dividingBy: 1)
                    let cx2 = lerp(fromX, x, f)
                    let cy2 = lerp(fromY, y, f) - sin(f * PI) * 34
                    c.circ(cx2, cy2, 4.2, Col(0xffd24a))
                    c.circStroke(cx2, cy2, 4.2, 1, Col(0x8a6a10))
                }
                c.circStroke(x, y, r + 4 + sin(T * 14) * 1.5, 2, GOLD.alpha(0.6))
            }
        }
    }

    // ---------- HUD
    func drawHUD(_ c: Canvas, _ L: Double) {
        let pad = max(12.0, safeL)
        let s = String(coins)
        let tw = textW(s, 15, FONTB)
        c.RR(pad - 4, 8, tw + 40, 24, 12, Col(0x08121c, 0.55))
        c.RRStroke(pad - 4, 8, tw + 40, 24, 12, 1, GOLD2.alpha(0.55))
        c.circ(pad + 9, 20, 8, Col(0xffd24a))
        c.circStroke(pad + 9, 20, 8, 1, Col(0x8a6a10))
        c.circStroke(pad + 9, 20, 5, 1, Col(0x8a6a10, 0.6))
        c.text(s, pad + 24, 25, 15, CREAM, -1, FONTB)
        var x = pad + tw + 46
        func chip(_ icon: String, _ txt: String) {
            let w2 = textW(txt, 14, FONTB) + 36
            c.RR(x, 8, w2, 24, 12, Col(0x08121c, 0.55))
            c.save()
            c.translate(x + 14, 20)
            c.scale(0.72, 0.72)
            drawIcon(c, icon)
            c.restore()
            c.text(txt, x + 27, 25, 14, CREAM, -1, FONTB)
            x += w2 + 6
        }
        if fish > 0 || done.contains("fishcart") { chip("fish", String(fish) + "/" + String(fishCap)) }
        if shells > 0 { chip("sack", String(shells)) }
        if mates > 0 { chip("mate", String(mates) + "/" + String(shipCrew)) }

        let right = W - max(12.0, safeR)
        let part = L > 0.5 ? (tod < 0.5 ? "Morning" : "Afternoon") : (tod < 0.5 ? "Night" : "Evening")
        c.textS("GULL CAY  ·  DAY " + String(day) + "  ·  " + part, right, 24, 14, CREAM, 1, FONTB)
        if day >= 2 || defence() > 0 {
            // shield against black sail, then how long until they come
            let def = defence(), thr = threat()
            let when = raiding ? "NOW" : (raidIn <= 0 ? "TONIGHT" : String(raidIn) + (raidIn == 1 ? " DAY" : " DAYS"))
            let weak = def < thr
            let w3 = textW(when, 12, FONTB) + 34
            var rx = right - w3
            c.RR(rx, 32, w3, 22, 11, Col(raidIn <= 1 ? 0x4a1410 : 0x08121c, 0.6))
            c.save(); c.translate(rx + 13, 43); c.scale(0.62, 0.62); drawIcon(c, "raid"); c.restore()
            c.text(when, rx + 25, 47.5, 12, raidIn <= 1 ? Col(0xffc8b8) : CREAM, -1, FONTB)
            let sd = String(def), st = String(thr)
            let w4 = textW(sd, 12, FONTB) + textW(st, 12, FONTB) + 62
            rx -= w4 + 6
            c.RR(rx, 32, w4, 22, 11, Col(0x08121c, 0.6))
            if weak { c.RRStroke(rx, 32, w4, 22, 11, 1, Col(0xff8a70, 0.5 + 0.4 * sin(T * 4))) }
            c.save(); c.translate(rx + 13, 43); c.scale(0.62, 0.62); drawIcon(c, "shield"); c.restore()
            c.text(sd, rx + 24, 47.5, 12, weak ? Col(0xffc8b8) : CREAM, -1, FONTB)
            let x2 = rx + 30 + textW(sd, 12, FONTB)
            c.save(); c.translate(x2 + 9, 43); c.scale(0.62, 0.62); drawIcon(c, "raid"); c.restore()
            c.text(st, x2 + 21, 47.5, 12, CREAM, -1, FONTB)
        }

        if bannerT > 0 {
            let a = min(1.0, bannerT)
            c.textS(banner, W / 2, H * 0.3, 26, GOLD.alpha(a), 0, FONTB)
        }
        if logT > 0 && !log.isEmpty {
            let a = min(1.0, logT)
            let maxW = min(W - 2 * pad - 60, 520.0)
            let lines = wrapText(log, maxW - 32, 14)
            var widest = 0.0
            for ln in lines { widest = max(widest, textW(ln, 14)) }
            let w = widest + 36
            let h = Double(lines.count) * 18 + 12
            let y0 = 60.0
            c.RR(W / 2 - w / 2, y0, w, h, min(15, h / 2), Col(0x050c14, 0.66 * a))
            c.RRStroke(W / 2 - w / 2, y0, w, h, min(15, h / 2), 1, GOLD2.alpha(0.45 * a))
            for (i, ln) in lines.enumerated() {
                c.text(ln, W / 2, y0 + 20 + Double(i) * 18, 14, CREAM.alpha(a))
            }
        }
    }

    // ---------- icons, drawn in gold around the origin
    func drawIcon(_ c: Canvas, _ id: String) {
        let u = 10.0
        let g = GOLD
        let dark = Col(0x1a1008)
        switch id {
        case "fish":
            c.ell(-2, 0, u * 0.55, u * 0.3, g)
            c.poly(g, [u * 0.4, 0, u * 0.85, -u * 0.35, u * 0.85, u * 0.35])
            c.circ(-u * 0.4, -u * 0.08, 1.2, dark)
        case "row":
            c.poly(g, [-u * 0.8, -u * 0.1, u * 0.8, -u * 0.1, u * 0.5, u * 0.35, -u * 0.5, u * 0.35])
            c.seg(-u * 0.1, -u * 0.1, -u * 0.6, -u * 0.85, 1.6, g)
        case "skiff":
            c.poly(g, [-u * 0.8, u * 0.2, u * 0.8, u * 0.2, u * 0.5, u * 0.6, -u * 0.5, u * 0.6])
            c.poly(g, [0, u * 0.1, 0, -u * 0.9, u * 0.6, u * 0.1])
        case "ship", "wright":
            c.poly(g, [-u * 0.9, u * 0.3, u * 0.9, u * 0.3, u * 0.6, u * 0.7, -u * 0.7, u * 0.7])
            for mx in [-u * 0.35, u * 0.3] {
                c.R(mx - 0.8, -u * 0.9, 1.6, u * 1.2, g)
                c.poly(g, [mx - u * 0.3, -u * 0.7, mx + u * 0.3, -u * 0.7, mx + u * 0.25, -u * 0.2, mx - u * 0.25, -u * 0.2])
            }
        case "haul":
            c.RRStroke(-u * 0.55, -u * 0.55, u * 1.1, u * 1.1, 1, 1.6, g)
            c.seg(-u * 0.55, -u * 0.55, u * 0.55, u * 0.55, 1.6, g)
            c.seg(u * 0.55, -u * 0.55, -u * 0.55, u * 0.55, 1.6, g)
        case "market":
            for i in 0..<3 {
                c.ell(0, u * 0.35 - Double(i) * u * 0.28, u * 0.55, u * 0.22, g)
                c.ellStroke(0, u * 0.35 - Double(i) * u * 0.28, u * 0.55, u * 0.22, 1, dark)
            }
        case "rod":
            c.seg(-u * 0.6, u * 0.7, u * 0.6, -u * 0.7, 2, g)
            c.seg(u * 0.6, -u * 0.7, u * 0.6, u * 0.2, 1, g)
            c.circStroke(u * 0.5, u * 0.4, u * 0.2, 1.4, g)
        case "wheel":
            c.circStroke(0, 0, u * 0.75, 1.6, g)
            for i in 0..<4 {
                let a = Double(i) * PI / 4
                c.seg(-cos(a) * u * 0.75, -sin(a) * u * 0.75, cos(a) * u * 0.75, sin(a) * u * 0.75, 1.4, g)
            }
        case "scales":
            c.R(-1, -u * 0.8, 2, u * 1.5, g)
            c.R(-u * 0.8, -u * 0.6, u * 1.6, 1.6, g)
            for d in [-1.0, 1] {
                c.seg(d * u * 0.75, -u * 0.6, d * u * 0.75, u * 0.1, 1.2, g)
                c.arcFill(d * u * 0.75, u * 0.15, u * 0.3, 0, PI, g)
            }
        case "mate":
            c.circ(0, -u * 0.4, u * 0.3, g)
            c.pathFill(g) { p in
                p.move(to: CGPoint(x: -u * 0.6, y: u * 0.8))
                p.addQuadCurve(to: CGPoint(x: u * 0.6, y: u * 0.8), control: CGPoint(x: 0, y: -u * 0.3))
                p.closeSubpath()
            }
        case "dog":
            c.save()
            c.rotate(-0.5)
            c.R(-u * 0.6, -u * 0.14, u * 1.2, u * 0.28, g)
            for sx2 in [-1.0, 1] {
                for sy2 in [-1.0, 1] { c.circ(sx2 * u * 0.66, sy2 * u * 0.2, u * 0.24, g) }
            }
            c.restore()
        case "light":
            c.poly(g, [-u * 0.45, u * 0.85, -u * 0.26, -u * 0.35, u * 0.26, -u * 0.35, u * 0.45, u * 0.85])
            c.R(-u * 0.34, -u * 0.72, u * 0.68, u * 0.3, g)
            c.poly(g, [-u * 0.4, -u * 0.72, 0, -u * 1.02, u * 0.4, -u * 0.72])
            c.seg(u * 0.4, -u * 0.57, u * 1.05, -u * 0.8, 1.2, g)
            c.seg(u * 0.4, -u * 0.57, u * 1.05, -u * 0.34, 1.2, g)
        case "look":
            c.save()
            c.rotate(-0.5)
            c.R(-u * 0.9, -u * 0.25, u * 1.1, u * 0.5, g)
            c.R(u * 0.2, -u * 0.35, u * 0.7, u * 0.7, g)
            c.restore()
        case "bait":
            c.R(-u * 0.5, -u * 0.2, u * 1.0, u * 0.8, g)
            c.arcStroke(0, -u * 0.2, u * 0.5, PI, 2 * PI, 1.6, g)
            for i in -1...1 { c.R(Double(i) * u * 0.25 - 1, -u * 0.05, 2, 2, dark) }
        case "sack":
            c.pathFill(g) { p in
                p.move(to: CGPoint(x: -u * 0.5, y: u * 0.7))
                p.addQuadCurve(to: CGPoint(x: -u * 0.2, y: -u * 0.5), control: CGPoint(x: -u * 0.7, y: -u * 0.1))
                p.addLine(to: CGPoint(x: u * 0.2, y: -u * 0.5))
                p.addQuadCurve(to: CGPoint(x: u * 0.5, y: u * 0.7), control: CGPoint(x: u * 0.7, y: -u * 0.1))
                p.closeSubpath()
            }
            c.R(-u * 0.25, -u * 0.6, u * 0.5, 2, dark)
        case "net":
            for i in -2...2 {
                let fi = Double(i)
                c.seg(fi * u * 0.3, -u * 0.7, fi * u * 0.3 + u * 0.3, u * 0.7, 1, g)
                c.seg(fi * u * 0.3, -u * 0.7, fi * u * 0.3 - u * 0.3, u * 0.7, 1, g)
            }
        case "lamp":
            c.R(-u * 0.4, -u * 0.5, u * 0.8, u * 0.9, g)
            c.R(-u * 0.15, -u * 0.8, u * 0.3, u * 0.3, g)
            c.R(-u * 0.3, u * 0.4, u * 0.6, u * 0.15, g)
            c.R(-u * 0.25, -u * 0.35, u * 0.5, u * 0.6, dark)
            c.circ(0, -u * 0.05, u * 0.15, Col(0xfff0a0))
        case "hook":
            c.seg(0, -u * 0.9, 0, u * 0.1, 2.2, g)
            c.arcStroke(-u * 0.3, u * 0.1, u * 0.3, 0, PI * 0.9, 2.2, g)
            c.circStroke(0, -u * 0.8, u * 0.18, 1.6, g)
        case "barrel":
            c.R(-u * 0.55, -u * 0.7, u * 1.1, u * 1.4, g)
            c.R(-u * 0.55, -u * 0.35, u * 1.1, 1.5, dark)
            c.R(-u * 0.55, u * 0.25, u * 1.1, 1.5, dark)
        case "cannon":
            c.save()
            c.rotate(-0.4)
            c.R(-u * 0.9, -u * 0.2, u * 1.5, u * 0.4, g)
            c.restore()
            c.circ(-u * 0.3, u * 0.4, u * 0.3, g)
            c.circ(-u * 0.3, u * 0.4, u * 0.1, dark)
        case "chart":
            c.R(-u * 0.75, -u * 0.55, u * 1.5, u * 1.1, g)
            c.curve(-u * 0.5, u * 0.3, -u * 0.1, -u * 0.5, u * 0.5, -u * 0.2, 1, dark)
            c.R(u * 0.3, -u * 0.3, 2, 2, dark)
        case "fishcart":
            c.R(-u * 0.7, -u * 0.4, u * 1.4, u * 0.6, g)
            c.circ(-u * 0.35, u * 0.5, u * 0.25, g)
            c.circ(u * 0.35, u * 0.5, u * 0.25, g)
            c.ell(-u * 0.2, -u * 0.1, u * 0.3, u * 0.14, dark)
            c.ell(u * 0.25, -u * 0.1, u * 0.3, u * 0.14, dark)
        case "bhut":
            c.R(-u * 0.6, -u * 0.1, u * 1.2, u * 0.8, g)
            c.poly(g, [-u * 0.85, -u * 0.1, 0, -u * 0.85, u * 0.85, -u * 0.1])
            c.R(-u * 0.15, u * 0.2, u * 0.3, u * 0.5, dark)
        case "saw":
            c.circStroke(0, 0, u * 0.6, 1.6, g)
            for i in 0..<8 {
                let a = Double(i) * PI / 4
                c.seg(cos(a) * u * 0.6, sin(a) * u * 0.6, cos(a + 0.3) * u * 0.9, sin(a + 0.3) * u * 0.9, 1.6, g)
            }
            c.circ(0, 0, u * 0.15, g)
        case "wheat":
            for dx in [-u * 0.45, 0, u * 0.45] {
                c.seg(dx, u * 0.8, dx, -u * 0.3, 1.6, g)
                for i in 0..<3 {
                    let yy: Double = -u * 0.3 - Double(i) * u * 0.22
                    c.ell(dx - u * 0.14, yy, u * 0.1, u * 0.16, g)
                    c.ell(dx + u * 0.14, yy, u * 0.1, u * 0.16, g)
                }
            }
        case "anvil":
            let shape: [Double] = [-0.9, -0.4, 0.7, -0.4, 0.4, 0, 0.2, 0, 0.2, 0.35, 0.6, 0.7, -0.6, 0.7, -0.2, 0.35, -0.2, 0, -0.5, -0.1]
            c.poly(g, shape.map { $0 * u })
        case "tower":
            c.R(-u * 0.5, -u * 0.8, u * 1.0, u * 0.5, g)
            c.seg(-u * 0.4, -u * 0.3, -u * 0.6, u * 0.85, 1.8, g)
            c.seg(u * 0.4, -u * 0.3, u * 0.6, u * 0.85, 1.8, g)
            c.seg(-u * 0.5, u * 0.3, u * 0.5, u * 0.3, 1.8, g)
        case "wall":
            for i in -2...2 {
                let cx: Double = Double(i) * u * 0.36
                c.poly(g, [cx - u * 0.15, u * 0.8, cx - u * 0.15, -u * 0.4, cx, -u * 0.8, cx + u * 0.15, -u * 0.4, cx + u * 0.15, u * 0.8])
            }
        case "shield":
            c.pathFill(g) { p in
                p.move(to: CGPoint(x: -u * 0.75, y: -u * 0.8))
                p.addLine(to: CGPoint(x: u * 0.75, y: -u * 0.8))
                p.addQuadCurve(to: CGPoint(x: 0, y: u * 0.95), control: CGPoint(x: u * 0.8, y: u * 0.5))
                p.addQuadCurve(to: CGPoint(x: -u * 0.75, y: -u * 0.8), control: CGPoint(x: -u * 0.8, y: u * 0.5))
            }
            c.R(-0.9, -u * 0.6, 1.8, u * 1.2, dark)
            c.R(-u * 0.5, -u * 0.2, u * 1.0, 1.8, dark)
        case "raid":
            c.poly(Col(0xe8a090), [-u * 0.9, u * 0.35, u * 0.9, u * 0.35, u * 0.6, u * 0.8, -u * 0.65, u * 0.8])
            c.R(-0.9, -u * 0.95, 1.8, u * 1.3, Col(0xe8a090))
            c.poly(Col(0xe8a090), [-u * 0.6, -u * 0.8, u * 0.65, -u * 0.8, u * 0.5, u * 0.1, -u * 0.5, u * 0.1])
            c.circ(0, -u * 0.38, u * 0.2, dark)
        case "tavern":
            c.R(-u * 0.45, -u * 0.4, u * 0.75, u * 0.9, g)
            c.arcStroke(u * 0.4, 0, u * 0.25, -1.3, 1.3, 1.6, g)
            c.ell(-u * 0.08, -u * 0.45, u * 0.45, u * 0.18, Col(0xfff8e0))
        default:
            c.circ(0, 0, 3, g)
        }
    }
}
