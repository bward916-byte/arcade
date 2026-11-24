import CoreGraphics
import Foundation

/// Paints the scene with CoreGraphics. World x runs left to right; `gy` is the ground line and heights go up from it.
final class Renderer {
    let g: Game
    let c: Canvas
    init(game: Game, canvas: Canvas) { g = game; c = canvas }

    private var W: Double { return g.W }
    private var H: Double { return g.H }
    private var gy: Double { return g.GY }

    func draw() {
        let dk = g.dark()
        let dusk = smooth(0.56, 0.70, g.t) * (1 - smooth(0.74, 0.84, g.t)) + (g.t < 0.08 ? 1 - g.t / 0.08 : 0) * 0.6
        c.save()
        if g.shake > 0 { c.translate(rnd(-1, 1) * g.shake * 2, rnd(-1, 1) * g.shake * 1.5) }
        sky(dk, dusk)
        mesas(dk, dusk)
        groundBand(dk)
        scenery()
        landmarks()
        sites(dk)
        camps(dk)
        towers()
        yard(dk)
        for bl in g.b where bl.def.wall != 0 && !bl.def.gate { building(bl, dk) }
        fires()
        centre()
        for bl in g.b where bl.wire { wire(bl) }
        if g.b.contains(where: { $0 === g.claim }) { claimSite() }
        if g.b.contains(where: { $0 === g.stable }) { ranch() }
        townSign()
        rail(dk)
        racks()
        if g.hall.level == 0 { campfire(FIRE_X, 1.0) }
        for bl in g.b where bl.def.gate { gate(bl) }
        for bx in g.boxes { box(bx) }
        coach()
        for w in g.strays { cowAt(w.x, w.dir, 1, w.seed, w.phase, horns: true) }
        gunmen()
        for m in g.mustangs {
            let coats: [(UInt32, UInt32)] = [(0x9a5a34, 0x4a2a18), (0xc9a36a, 0x8a6a40), (0x8a8480, 0x4a4642), (0x3a3230, 0x1c1816)]
            let ct = coats[Int(m.seed) % 4]
            if vis(m.x, 30) { _ = horse(sx(m.x), m.dir, m.phase, m.speed, Col(ct.0), Col(ct.1)); if m.st == 2 { c.seg(sx(m.x) + m.dir * 14, gy - 22, sx(g.px), gy - 22, 0.5, Col(0xc9a468)) } }
        }
        for tr in g.cav where vis(tr.x, 30) {
            let x = sx(tr.x)
            _ = horse(x, tr.dir, tr.phase, 118, Col(0x6e4a30), Col(0x3a2416))
            c.R(x - 3, gy - 26, 6, 9, Col(0x2f4a7a)); c.R(x - 3, gy - 22, 6, 1.2, Col(0xf2c14e)); c.R(x - 1, gy - 17, 3, 7, Col(0x8fa4c4))
            c.R(x - 2, gy - 30, 4.5, 4, Col(0xd9a878)); c.R(x - 4.5, gy - 31, 9.5, 1.3, Col(0x1c2a4a)); c.R(x - 2.5, gy - 33.6, 5.5, 3, Col(0x1c2a4a))
            c.seg(x + tr.dir * 2, gy - 24, x + tr.dir * 9, gy - 29, 1, Col(0xc9c9d0))
        }
        for f in g.folk { person(f.x, f.phase, f.dir, f.moving, f.seed, f.role, f.work) }
        for cw in g.herd where cw.x > g.pasture.1 + 2 { cowAt(cw.x, cw.dir, cw.calf ? 0.6 : 1.0, cw.seed, cw.phase, horns: false) }
        for bn in g.bandits {
            // dust or a blizzard hides them until they are close
            if g.storm { c.alpha(abs(bn.x - g.px) < 70 ? 1 : 0.35) }
            bandit(bn)
            if bn.torch && bn.st != 3 && vis(bn.x, 20) {
                let tx = sx(bn.x) - bn.side * 5, ty = gy - (bn.rider ? 30 : 19)
                c.R(tx - 0.5, ty, 1.2, 5, Col(0x4a3424))
                c.poly(Col(0xff9a2e), [tx - 2, ty, tx, ty - 5 - sin(g.clock * 17 + bn.x) * 1.5, tx + 2, ty]); c.poly(Col(0xffe08a), [tx - 1, ty, tx, ty - 2.5, tx + 1, ty])
            }
        }
        c.alpha(1)
        if g.tripT < 0 { rider() }
        coins()
        effects()
        night(dk)
        skyThings()
        weather(dk)
        duelBars()
        slots()
        c.restore()
        if g.flash > 0 { c.R(0, 0, W, H, Col(0xfff0c0, g.flash * 0.5)) }
        if g.fade > 0 { c.R(0, 0, W, H, Col(0x000000, g.fade)) }
    }

    /// The picture for a story scene, painted into its own small canvas.
    func art(_ bt: Beat) -> CGImage? {
        let w = 150.0, h = 84.0
        guard let a = Canvas(w: Int(w), h: Int(h), scale: 4) else { return nil }
        let ink = Col(0x2a1c14), paper = Col(0xead7a4)
        func frame(_ top: UInt32, _ bot: UInt32) { a.vfill(0, 0, w, h, [(0, Col(top)), (1, Col(bot))]) }
        func star5(_ x: Double, _ y: Double, _ r: Double, _ col: Col) {
            var p: [Double] = []
            for i in 0..<10 {
                let an = -PI / 2 + Double(i) * PI / 5
                let rr = i % 2 == 0 ? r : r * 0.45
                p.append(x + cos(an) * rr); p.append(y + sin(an) * rr)
            }
            a.poly(col, p)
        }
        switch bt.art {
        case "star":
            frame(0x3a2a1c, 0x1c120c)
            for i in 0..<26 { a.R(hashN(Double(i) * 3.1) * w, 58 + hashN(Double(i) * 7.3) * 24, 2 + hashN(Double(i)) * 5, 1.5, Col(0x5c5048, 0.7)) }
            a.glow(w / 2, 40, 46, Col(0xf2c14e, 0.35), Col(0xf2c14e, 0))
            a.circ(w / 2, 40, 25, Col(0x8a6a2a)); a.circ(w / 2, 40, 23, Col(0xc9a14a))
            star5(w / 2, 40, 20, Col(0xf2c14e)); star5(w / 2 - 1, 39, 12, Col(0xfff0b0, 0.5))
            a.text("SHERIFF", w / 2, 43, 6.5, Col(0x5a3c1a))
        case "eyes":
            let crane = bt.who == "crane", gun = bt.who == "gun"
            let topC: UInt32 = crane ? 0x3a3440 : (gun ? 0x4a2a22 : 0xd9a47a)
            let botC: UInt32 = crane ? 0x1c1a22 : (gun ? 0x1c120c : 0xa85e36)
            frame(topC, botC)
            let skinC: UInt32 = crane ? 0xe2c0a0 : (gun ? 0xb8804e : 0xd9a878)
            let hatC: UInt32 = crane ? 0x2a2a30 : (gun ? 0x14100e : 0x5a4030)
            let skin = Col(skinC), hat = Col(hatC)
            a.R(30, 22, 90, 62, skin)
            a.R(30, 60, 90, 24, Col(0x000000, 0.12))
            let look = gun ? -2.0 : 1.0
            let iris: UInt32 = crane ? 0x6a8a9a : 0x4a3424
            for ex in [56.0, 94.0] {
                a.RR(ex - 11, 36, 22, 4, 2, Col(0x3a2a1c)); a.ell(ex, 47, 9, 4.5, Col(0xf4ecd6))
                a.circ(ex + look, 47, 4, Col(iris)); a.circ(ex + look, 47, 1.8, ink)
                a.R(ex - 10, 41.5, 20, 2.5, skin)
            }
            a.poly(Col(0x000000, 0.15), [72, 44, 78, 44, 81, 66, 69, 66])
            if crane {
                a.RR(40, 68, 70, 7, 3, Col(0xd8d8dc)); a.ellStroke(94, 47, 12, 8, 1.4, Col(0xc9a14a)); a.seg(106, 49, 118, 70, 0.8, Col(0xc9a14a))
                a.R(18, 16, 114, 8, hat); a.R(34, 0, 82, 18, hat); a.R(34, 12, 82, 4, Col(0x6a2a30))
            } else {
                if gun { a.R(30, 62, 90, 22, Col(0xa02a22)); a.poly(Col(0x7a1c18), [30, 62, 75, 70, 120, 62, 120, 66, 75, 74, 30, 66]) }
                else { a.R(30, 74, 90, 10, Col(0xc9402f)) }
                a.poly(hat, [4, 28, 20, 16, 130, 16, 146, 28, 130, 24, 20, 24]); a.RR(36, 0, 78, 20, 6, hat)
                let band: UInt32 = gun ? 0x4a4a50 : 0x2a1c14
                a.R(36, 14, 78, 4, Col(band))
            }
            a.R(0, 22, 30, 62, Col(0x000000, 0.25)); a.R(120, 22, 30, 62, Col(0x000000, 0.25))
        case "brand":
            frame(0x8a4a2c, 0x5a2f1c)
            a.RR(-10, 10, 170, 90, 30, Col(0x9a5a34)); a.RR(6, 16, 120, 20, 10, Col(0xb06a40, 0.6))
            a.arcStroke(78, 46, 17, 0.9, PI * 2 - 0.9, 6.5, Col(0x2e1a12)); a.arcStroke(78, 46, 17, 0.9, PI * 2 - 0.9, 3, Col(0x5a2a1a))
            for i in 0..<5 { a.seg(70 + Double(i) * 4, 22 - Double(i % 2) * 3, 72 + Double(i) * 4, 12, 0.8, Col(0xffffff, 0.25)) }
        case "wire":
            frame(0x4a3424, 0x2a1c14)
            a.RR(14, 8, 122, 68, 2, paper); a.R(14, 8, 122, 12, Col(0xd8c080)); a.text("WESTERN TERRITORY TELEGRAPH", w / 2, 16.5, 5, ink)
            for (i, ln) in bt.lines.enumerated() { a.text(ln, 22, 34 + Double(i) * 12, 7, ink, center: false) }
            a.R(22, 70, 106, 0.8, Col(0x2a1c14, 0.4))
        case "hand":
            frame(0xe8b47a, 0xa85e36)
            a.R(0, 0, 60, h, Col(0x6a4a2e)); a.R(52, 0, 10, h, Col(0x3a2a1c)); a.R(54, 20, 6, 8, Col(0xf2c14e))
            a.RR(62, 30, 34, 50, 6, Col(0x3a2a1c)); a.RR(70, 14, 14, 26, 4, Col(0x5a3c22)); a.R(68, 12, 18, 5, Col(0x8a8a90))
            a.RR(98, 22, 30, 16, 6, Col(0xd9a878))
            for k in 0..<4 { a.RR(92 + Double(k) * 1.5, 24 + Double(k) * 3.6, 14, 3.4, 1.7, Col(0xc9966a)) }
            a.RR(104, 16, 8, 12, 3, Col(0xd9a878)); a.R(124, 16, 26, 28, Col(0xc9b48a))
        case "map":
            frame(0xead7a4, 0xd8c080)
            a.R(6, 6, 138, 72, Col(0x2a1c14, 0.06))
            let n = STAGES.count
            let all = bt.who == "all"
            let done = all ? n : g.town % n
            a.seg(20, 44, 130, 44, 2, ink)
            var tx = 20.0
            while tx < 130 { a.R(tx, 41, 1, 6, ink); tx += 5 }
            for i in 0..<n {
                let x = 20 + Double(i) * 27.5
                a.circ(x, 44, 6, ink)
                a.circ(x, 44, 4.6, i < done ? Col(0xf2c14e) : (i == done ? Col(0xc0392b) : paper))
                if i < done { star5(x, 44, 3.4, Col(0x8a6a2a)) }
                var nm = "?"
                if i < done && i < g.log.count { nm = nice(PLACES[g.log[i]]?.name ?? "") } else if i == done && !all { nm = nice(g.townName) }
                a.text(nm, x, i % 2 == 0 ? 30 : 62, 5, ink)
            }
            a.text("C. C. & R. RAILROAD", w / 2, 17, 6, Col(0x6a2f26))
        case "train":
            frame(0x5a3f7a, 0xf6b25a)
            a.poly(Col(0x3a2a4a), [0, 60, 30, 40, 70, 46, 110, 34, 150, 50, 150, 84, 0, 84])
            a.R(0, 70, w, 14, Col(0x2a1c24)); a.R(0, 69, w, 1, Col(0x8a8f98))
            a.RR(24, 40, 104, 26, 3, Col(0x1c1a22)); a.R(22, 37, 108, 4, Col(0x0e0c12)); a.R(24, 60, 104, 1.2, Col(0xc9a14a))
            for k in 0..<5 { a.RR(32 + Double(k) * 19, 45, 12, 10, 2, Col(0xffd98a)) }
            a.R(70, 46, 3, 8, Col(0x1c1a22)); a.circ(71.5, 45, 2.4, Col(0x1c1a22))
            for wx in [38.0, 50, 104, 116] { a.circ(wx, 68, 4, Col(0x0e0c12)); a.circ(wx, 68, 1.4, Col(0xc9a14a)) }
            a.text("S. CRANE", w / 2, 64.5, 4, Col(0xc9a14a))
        default:
            frame(0x2a3040, 0x5a5a66)
            for i in 0..<6 { a.RR(-10 + Double(i) * 28, 4 + hashN(Double(i)) * 10, 50, 16, 8, Col(0x1c2028, 0.85)) }
            a.poly(Col(0x3a3440), [0, 70, 26, 52, 60, 52, 70, 70]); a.poly(Col(0x3a3440), [80, 70, 96, 46, 134, 46, 150, 66, 150, 84, 0, 84, 0, 70])
            var x = 82.0, y = 16.0, k = 0.0
            while y < 66 {
                let nx = x + (hashN(k * 3.7) - 0.5) * 18, ny = y + 8 + hashN(k) * 5
                a.seg(x, y, nx, ny, 2, Col(0xfffbe6)); a.seg(x, y, nx, ny, 5, Col(0xbfd4ff, 0.3))
                x = nx; y = ny; k += 1
            }
            for i in 0..<30 {
                let rx = hashN(Double(i) * 5.3) * w, ry = 20 + hashN(Double(i) * 8.1) * 60
                a.seg(rx, ry, rx - 2, ry + 7, 0.6, Col(0xcfe0ee, 0.4))
            }
        }
        return a.image()
    }

    private func sx(_ x: Double) -> Double { return x - g.cam }
    private func vis(_ x: Double, _ w: Double) -> Bool { let s = x - g.cam; return s > -w - 20 && s < W + 20 }

    // ---------- sky and land
    private func sky(_ dk: Double, _ dusk: Double) {
        // cloud greys the sky over; snow country has a paler, colder one
        let cl = max(g.cloudI(), g.storm ? 0.5 : 0) * 0.8
        let grey = Col.mix(Col(0x6e7680), Col(0x14161e), dk)
        let cold = g.bio == .snow
        let top = Col.mix(Col.mix(Col.mix(Col(cold ? 0x8fb4d6 : 0x6fb0e0), Col(0x5a3f7a), dusk), Col(0x0a0f24), dk), grey, cl)
        let mid = Col.mix(Col.mix(Col.mix(Col(cold ? 0xd2e2ee : 0xbfdcee), Col(0xe8794a), dusk), Col(0x1a2040), dk), grey, cl)
        let low = Col.mix(Col.mix(Col.mix(Col(cold ? 0xeef3f8 : 0xf4dfb0), Col(0xf6b25a), dusk), Col(0x2c2a4a), dk), grey, cl * 0.8)
        c.vfill(0, 0, W, gy, [(0, top), (0.6, mid), (1, low)])
        if dk > 0.25 {
            for i in 0..<70 {
                let x = hashN(Double(i) * 3.1) * W, y = hashN(Double(i) * 7.7) * gy * 0.8
                let tw = 0.5 + 0.5 * sin(g.clock * (1 + hashN(Double(i)) * 2) + Double(i))
                c.R(x.rounded(), y.rounded(), 1, 1, Col(0xfff6dc, (dk - 0.25) * tw))
            }
        }
        // the sun crosses by day; the moon by night
        if g.t > 0.02 && g.t < 0.76 {
            let u = (g.t - 0.02) / 0.74
            let x = W * (0.08 + 0.84 * u), y = gy - sin(u * PI) * gy * 0.82 + 6
            c.glow(x, y, 46, Col(0xfff2c0, 0.55 * (1 - dk)), Col(0xfff2c0, 0))
            c.circ(x, y, 9, Col.mix(Col(0xfff6d8), Col(0xff9a4a), dusk))
        } else {
            let u = g.t >= 0.76 ? (g.t - 0.76) / 0.26 : (g.t + 0.24) / 0.26
            let x = W * (0.15 + 0.7 * u), y = gy * 0.62 - sin(u * PI) * gy * 0.42
            c.glow(x, y, 30, Col(0xdfe8ff, 0.25), Col(0xdfe8ff, 0))
            c.circ(x, y, 7, Col(0xeef2ff))
            c.circ(x + 2.5, y - 1.5, 6, Col.mix(Col(0x0a0f24), Col(0x1a2040), 0.5))
        }
        // a few clouds drifting
        for i in 0..<5 {
            let w = 40 + hashN(Double(i) * 9.3) * 50
            var x = hashN(Double(i) * 4.1) * (W + 200) + g.clock * (3 + Double(i)) - g.cam * 0.05
            x = x.truncatingRemainder(dividingBy: W + 200) - 100
            let y = 14 + hashN(Double(i) * 2.2) * gy * 0.3
            let col = Col.mix(Col.mix(Col(0xffffff, 0.75), Col(0xffc9a0, 0.7), dusk), Col(0x3a4060, 0.5), dk)
            c.RR(x, y, w, 6, 3, col)
            c.RR(x + w * 0.2, y - 3, w * 0.5, 6, 3, col)
        }
    }

    private func mesas(_ dk: Double, _ dusk: Double) {
        let L = g.terrain
        let far = Col.mix(Col.mix(Col(L.far), Col(0xb0607a), dusk), Col(0x34365e), dk)
        let near = Col.mix(Col.mix(Col(L.mesa), Col(0x8a3e4a), dusk), Col(0x2a2a4e), dk)
        let cap = Col.mix(Col(L.mesaT), Col(0x4a4e72), dk)
        let nearD = Col.mix(Col.mix(Col(L.mesaS), Col(0x6a2e3a), dusk), Col(0x20203e), dk)
        var i = -4
        while i < 14 {
            let bx = Double(i) * 190 + hashN(Double(i) * 5.3) * 80 - g.cam * 0.22 - 60
            let w = 70 + hashN(Double(i) * 1.7) * 90, h = 26 + hashN(Double(i) * 8.9) * 34
            if bx > -w - 10 && bx < W + 10 {
                c.poly(far, [bx, gy, bx + 8, gy - h, bx + w - 10, gy - h, bx + w, gy])
            }
            i += 1
        }
        i = 0
        while i < 16 {
            let bx = Double(i) * 260 + hashN(Double(i) * 3.9) * 120 - g.cam * 0.45 - 80
            let w = 60 + hashN(Double(i) * 6.1) * 70, h = 34 + hashN(Double(i) * 2.3) * 44
            if bx > -w - 10 && bx < W + 10 {
                c.poly(near, [bx - 6, gy, bx + 6, gy - h * 0.55, bx + 12, gy - h, bx + w - 12, gy - h, bx + w - 4, gy - h * 0.5, bx + w + 8, gy])
                c.poly(nearD, [bx + w * 0.55, gy, bx + w * 0.6, gy - h, bx + w - 12, gy - h, bx + w - 4, gy - h * 0.5, bx + w + 8, gy])
                if g.bio == .snow { c.R(bx + 12, gy - h, w - 24, 3, cap); c.R(bx + 14, gy - h + 3, w - 34, 1, cap) }
                c.R(bx + 12, gy - h * 0.7, w - 26, 1, nearD.alpha(0.5))
                c.R(bx + 8, gy - h * 0.4, w - 14, 1, nearD.alpha(0.5))
            }
            i += 1
        }
    }

    private func groundBand(_ dk: Double) {
        let L = g.terrain
        c.vfill(0, gy, W, H - gy, [(0, Col(L.g0)), (0.25, Col(L.g1)), (1, Col(L.g2))])
        c.R(0, gy, W, 1, Col(L.edge))
        // the ford east of a river town
        if g.bio == .river || g.flooded {
            let r = g.river
            if vis(r.0, r.1 - r.0) {
                let x0 = sx(r.0), w = r.1 - r.0
                let clear = g.bio == .river && !g.flooded
                let water: [(Double, Col)] = [(0, Col(clear ? 0x7fb0c4 : 0x9a8a6a)), (1, Col(clear ? 0x4a7f98 : 0x6a6a5a))]
                c.vfill(x0, gy, w, H - gy, water)
                c.R(x0 - 2, gy, 2, H - gy, Col(0x8a8a56)); c.R(x0 + w, gy, 2, H - gy, Col(0x8a8a56))
                for k in 0..<7 {
                    let yy = gy + 2 + Double(k) * (H - gy - 3) / 7
                    let xx = x0 + 3 + (hashN(Double(k) * 3.3) * (w - 12) + g.clock * 5).truncatingRemainder(dividingBy: w - 10)
                    c.R(xx, yy, 6, 1, Col(0xd8ecf4, 0.7))
                }
            }
        }
        // the main street, packed earth between the gates
        let a = sx(966), b2 = sx(g.gateE.x)
        if b2 > 0 && a < W { c.R(max(0, a), gy + 1, min(W, b2) - max(0, a), 5, Col(L.street)) }
        var i = Int(g.cam / 23)
        let end = Int((g.cam + W) / 23) + 1
        while i <= end {
            let x = Double(i) * 23 + hashN(Double(i) * 1.3) * 18
            let y = gy + 3 + hashN(Double(i) * 4.7) * (H - gy - 6)
            if (g.bio != .river && !g.flooded) || x < g.river.0 - 3 || x > g.river.1 { c.R(sx(x).rounded(), y.rounded(), 2 + hashN(Double(i)) * 3, 1, Col(L.speck, 0.55)) }
            i += 1
        }
    }

    private func scenery() {
        var i = Int(((g.cam - 40) / 120).rounded(.down))
        let end = Int((g.cam + W + 40) / 120)
        while i <= end {
            if i >= -6 {
                let x = Double(i) * 120 + hashN(Double(i) * 6.6) * 90
                let inTown = x > 890 && x < g.gateE.x + 60
                let wet = g.bio == .river && x > g.river.0 - 14 && x < g.river.1 + 14
                let grazed = (x > g.pasture.0 - 12 && x < g.pasture.1 + 12) || [-90.0, -250, -434, -600, 752, g.sFort.x, g.missionX, g.archX, 528].contains { abs($0 - x) < 34 }
                if !inTown && !wet && !grazed {
                    let k = hashN(Double(i) * 2.9)
                    let s = sx(x)
                    if k < 0.45 {
                        switch g.bio {
                        case .desert: cactus(s, 12 + k * 22)
                        case .river: tree(s, 20 + k * 30)
                        case .canyon: if k < 0.25 { spire(s, 30 + k * 90) } else { cactus(s, 10 + k * 16) }
                        case .pine: pine(s, 26 + k * 40, snow: false)
                        case .snow: pine(s, 22 + k * 34, snow: true)
                        }
                    } else if k < 0.8 { brush(s) } else { rock(s, 5 + k * 6) }
                }
            }
            i += 1
        }
        // the old mine west of town
        if vis(MINE_X, 60) {
            let s = sx(MINE_X)
            c.poly(Col(0x8a5a3a), [s - 34, gy, s - 20, gy - 26, s + 22, gy - 30, s + 38, gy])
            c.R(s - 8, gy - 16, 16, 16, Col(0x1c120c))
            c.R(s - 10, gy - 18, 20, 2, Col(0x5a3c22)); c.R(s - 10, gy - 18, 2, 18, Col(0x5a3c22)); c.R(s + 8, gy - 18, 2, 18, Col(0x5a3c22))
        }
    }

    private func cactus(_ x: Double, _ h: Double) {
        let col = Col(0x4f7a4a), d = Col(0x3a5c38)
        c.RR(x - 2, gy - h, 4, h, 2, col)
        c.R(x + 1, gy - h + 1, 1, h - 1, d)
        c.RR(x - 7, gy - h * 0.62, 3, h * 0.3, 1.5, col); c.R(x - 7, gy - h * 0.36, 6, 2, col)
        c.RR(x + 4, gy - h * 0.8, 3, h * 0.34, 1.5, col); c.R(x + 1, gy - h * 0.5, 6, 2, col)
    }
    private func tree(_ x: Double, _ h: Double) {
        c.R(x - 1.5, gy - h * 0.5, 3, h * 0.5, Col(0x6a4a2e))
        c.circ(x, gy - h * 0.66, h * 0.3, Col(0x55783c)); c.circ(x - h * 0.2, gy - h * 0.52, h * 0.22, Col(0x4a6c34)); c.circ(x + h * 0.2, gy - h * 0.55, h * 0.24, Col(0x628846))
    }
    private func spire(_ x: Double, _ h: Double) {
        let L = g.terrain
        c.poly(Col(L.mesa), [x - h * 0.16, gy, x - h * 0.1, gy - h * 0.7, x - h * 0.04, gy - h, x + h * 0.06, gy - h * 0.96, x + h * 0.12, gy - h * 0.6, x + h * 0.18, gy])
        c.poly(Col(L.mesaS), [x + h * 0.03, gy, x + h * 0.03, gy - h * 0.98, x + h * 0.06, gy - h * 0.96, x + h * 0.12, gy - h * 0.6, x + h * 0.18, gy])
        c.R(x - h * 0.1, gy - h * 0.55, h * 0.2, 1, Col(L.mesaS, 0.5)); c.R(x - h * 0.12, gy - h * 0.3, h * 0.26, 1, Col(L.mesaS, 0.5))
    }
    private func pine(_ x: Double, _ h: Double, snow: Bool) {
        c.R(x - 1, gy - h * 0.25, 2, h * 0.25, Col(0x4a3424))
        for k in 0..<3 {
            let y = gy - h * (0.2 + Double(k) * 0.24), w = h * (0.34 - Double(k) * 0.08)
            c.poly(Col(0x3f5f44), [x - w, y, x, y - h * 0.36, x + w, y])
            if snow { c.poly(Col(0xf4f8ff), [x - w * 0.55, y - h * 0.16, x, y - h * 0.36, x + w * 0.55, y - h * 0.16, x, y - h * 0.2]) }
            else { c.poly(Col(0x2f4a36), [x, y, x, y - h * 0.36, x + w, y]) }
        }
    }
    private func brush(_ x: Double) {
        let col = Col(g.terrain.scrub)
        for k in 0..<5 { c.seg(x, gy, x - 5 + Double(k) * 2.5, gy - 5 - Double(k % 2) * 2, 1, col) }
    }
    private func rock(_ x: Double, _ r: Double) {
        c.poly(Col(0x9a7a5a), [x - r, gy, x - r * 0.5, gy - r * 0.8, x + r * 0.5, gy - r, x + r, gy])
        c.poly(Col(0x7a5c42), [x + r * 0.1, gy, x + r * 0.5, gy - r, x + r, gy])
    }

    private func campfire(_ wx: Double, _ k: Double) {
        if !vis(wx, 30) { return }
        let x = sx(wx)
        c.R(x - 6, gy - 2, 12, 2, Col(0x4a3424))
        c.seg(x - 5, gy - 1, x + 5, gy - 4, 2, Col(0x5a3c22)); c.seg(x + 5, gy - 1, x - 5, gy - 4, 2, Col(0x5a3c22))
        let f = 5 + sin(g.clock * 11 + wx) * 1.5
        c.poly(Col(0xf08a2a), [x - 4 * k, gy - 3, x, gy - 3 - (f + 4) * k, x + 4 * k, gy - 3])
        c.poly(Col(0xffd45a), [x - 2 * k, gy - 3, x + sin(g.clock * 17) * 0.8, gy - 3 - f * k, x + 2 * k, gy - 3])
    }

    private func camps(_ dk: Double) {
        for (i, cp) in g.camps.enumerated() where vis(cp.0, 70) {
            let x = sx(cp.0)
            // a patched tent and a small fire
            c.poly(Col(0xbfae8a), [x - 34, gy, x - 24, gy - 16, x - 14, gy])
            c.poly(Col(0x9a8a6a), [x - 24, gy - 16, x - 21, gy, x - 14, gy])
            campfire(cp.0 + 22, 0.7)
            _ = i
        }
        for d in g.drifters where vis(d.x, 12) {
            person(d.x, 0, d.x < FIRE_X ? 1 : -1, false, d.seed, .folk, false, ragged: true)
        }
    }

    // ---------- the town
    private func building(_ bl: Building, _ dk: Double) {
        let d = bl.def
        if !vis(bl.x, d.w) { return }
        let x = sx(bl.x).rounded(), w = d.w
        let lv = bl.level
        let h = d.h + Double(max(0, lv - 1)) * 5
        if lv == 0 {
            // burned out and boarded up
            let hh = d.h * 0.78
            c.R(x, gy - hh, w, hh, Col(0x5c5048))
            c.R(x, gy - hh, w, 2, Col(0x3a302a))
            c.poly(Col(0x3a302a), [x, gy - hh, x + w * 0.3, gy - hh - 5, x + w * 0.45, gy - hh])
            for k in 0..<Int(w / 9) { c.R(x + 3 + Double(k) * 9, gy - hh + 3, 1, hh - 3, Col(0x4a3f38)) }
            c.R(x + d.doorX, gy - 20, d.doorW, 20, Col(0x2a221e))
            c.seg(x + d.doorX - 1, gy - 18, x + d.doorX + d.doorW + 1, gy - 6, 2, Col(0x7a6a58))
            c.seg(x + d.doorX - 1, gy - 6, x + d.doorX + d.doorW + 1, gy - 18, 2, Col(0x7a6a58))
            for wn in d.wins {
                c.R(x + wn.0, gy - 21, wn.1, 12, Col(0x2a221e))
                c.R(x + wn.0 - 1, gy - 17, wn.1 + 2, 2, Col(0x7a6a58)); c.R(x + wn.0 - 1, gy - 13, wn.1 + 2, 2, Col(0x7a6a58))
            }
            c.text(d.name, x + w / 2, gy - hh + 9, 6, Col(0x8a7c6c))
            if bl.building { scaffold(x, w, d.h, bl.progress) }
            return
        }
        let wall = Col(d.wall), trim = Col(d.trim), roof = Col(d.roof)
        // side shadow, wall, clapboards
        c.R(x, gy - h, w, h, wall)
        var yy = gy - h + 4
        while yy < gy - 1 { c.R(x, yy, w, 1, Col(0x000000, 0.08)); yy += 4 }
        c.R(x + w - 4, gy - h, 4, h, Col(0x000000, 0.12))
        // false front and sign
        let fh = 11.0 + Double(lv) * 2
        c.R(x - 2, gy - h - fh, w + 4, fh, wall)
        c.R(x - 3, gy - h - fh - 2, w + 6, 3, roof)
        if g.bio == .snow { c.RR(x - 3, gy - h - fh - 4, w + 6, 3, 1.5, Col(0xf4f8ff)); c.R(x - 4, gy - 26, w + 8, 1.5, Col(0xf4f8ff)) }
        c.R(x - 2, gy - h - 1, w + 4, 2, trim)
        c.R(x + 6, gy - h - fh + 2, w - 12, fh - 4, Col(d.sign))
        c.text(d.name, x + w / 2, gy - h - fh / 2 + 2.6, 7.5, Col(d.ink))
        // porch roof and posts
        c.R(x - 4, gy - 25, w + 8, 3, roof)
        c.R(x - 4, gy - 22, w + 8, 1, Col(0x000000, 0.2))
        c.R(x - 3, gy - 22, 2, 22, trim); c.R(x + w + 1, gy - 22, 2, 22, trim)
        if w > 70 { c.R(x + w * 0.33, gy - 22, 2, 22, trim); c.R(x + w * 0.66, gy - 22, 2, 22, trim) }
        // door and windows
        c.R(x + d.doorX - 1, gy - 21, d.doorW + 2, 21, trim)
        c.R(x + d.doorX, gy - 20, d.doorW, 20, Col(0x3a2a1c))
        if bl.type == .saloon {
            c.R(x + d.doorX, gy - 14, d.doorW / 2 - 0.5, 9, Col(0xc98a4a)); c.R(x + d.doorX + d.doorW / 2 + 0.5, gy - 14, d.doorW / 2 - 0.5, 9, Col(0xc98a4a))
        }
        let lit = dk > 0.3 && !bl.robbed
        for wn in d.wins {
            c.R(x + wn.0 - 1, gy - 22, wn.1 + 2, 14, trim)
            c.R(x + wn.0, gy - 21, wn.1, 12, lit ? Col(0xffd98a) : Col(0x9fc4d4))
            c.R(x + wn.0 + wn.1 / 2 - 0.5, gy - 21, 1, 12, trim)
            if bl.type == .sheriff || bl.type == .bank { var k = 2.0; while k < wn.1 { c.R(x + wn.0 + k, gy - 21, 1, 12, Col(0x2a2a2a)); k += 4 } }
        }
        // each improvement adds something you can see
        if lv >= 2 {
            c.R(x + 8, gy - h + 3, 10, 8, trim); c.R(x + 9, gy - h + 4, 8, 6, lit ? Col(0xffd98a) : Col(0x9fc4d4))
            c.R(x + w - 18, gy - h + 3, 10, 8, trim); c.R(x + w - 17, gy - h + 4, 8, 6, lit ? Col(0xffd98a) : Col(0x9fc4d4))
        }
        if lv >= 3 {
            c.R(x + w / 2 - 1, gy - h - fh - 12, 2, 10, Col(0x3a2a1c))
            c.poly(Col(0xb5412e), [x + w / 2 + 1, gy - h - fh - 12, x + w / 2 + 11 + sin(g.clock * 4) * 1.5, gy - h - fh - 9, x + w / 2 + 1, gy - h - fh - 6])
        }
        if bl.type == .church {         // a steeple and a cross
            c.R(x + w / 2 - 6, gy - h - fh - 14, 12, 14, wall); c.poly(roof, [x + w / 2 - 8, gy - h - fh - 14, x + w / 2, gy - h - fh - 26, x + w / 2 + 8, gy - h - fh - 14])
            c.R(x + w / 2 - 0.5, gy - h - fh - 32, 1.5, 7, trim); c.R(x + w / 2 - 2.5, gy - h - fh - 30, 5.5, 1.5, trim)
            c.R(x + w / 2 - 2, gy - h - fh - 10, 4, 6, Col(0x3a2a1c))
        }
        if bl.type == .forge {          // the fire inside, and a chimney
            c.R(x + d.doorX + 2, gy - 12, d.doorW - 4, 12, Col(0xe8742a, 0.55 + 0.25 * sin(g.clock * 7)))
            c.R(x + 6, gy - h - fh - 9, 6, 9, Col(0x4a3f38))
        }
        if bl.type == .telegraph {      // a mast, and at dusk a red pennant on the side the raid will come from
            c.R(x + 8, gy - h - fh - 20, 1.5, 20, Col(0x3a2a1c)); c.R(x + 4, gy - h - fh - 18, 9.5, 1, Col(0x3a2a1c))
            if g.raidOn { c.poly(Col(0xc0392b), [x + 9, gy - h - fh - 20, x + 9 + g.side * 8, gy - h - fh - 17.5, x + 9, gy - h - fh - 15]) }
        }
        if bl.robbed { c.text("ROBBED", x + w / 2, gy - h - fh - 4, 6, Col(0xd04a3a)) }
        if bl.building { scaffold(x, w, h + fh, bl.progress) }
        if bl.flash > 0 { c.R(x - 2, gy - h - fh, w + 4, h + fh, Col(0xfff0c0, bl.flash)) }
    }

    private func scaffold(_ x: Double, _ w: Double, _ h: Double, _ p: Double) {
        let col = Col(0xc9a86a)
        c.R(x - 4, gy - h - 4, 2, h + 4, col); c.R(x + w + 2, gy - h - 4, 2, h + 4, col)
        var yy = gy - 10.0
        while yy > gy - h - 4 { c.R(x - 4, yy, w + 8, 1.5, col); yy -= 12 }
        c.seg(x - 3, gy, x + w * 0.3, gy - h, 1, col.alpha(0.8))
        // progress bar
        c.R(x + 4, gy - h - 10, w - 8, 4, Col(0x2a1c14, 0.8))
        c.R(x + 5, gy - h - 9, (w - 10) * clampD(p, 0, 1), 2, GOLD)
    }

    private func racks() {
        let sh = g.sheriff, st = g.store
        if sh.level > 0 && !sh.building && vis(g.rackX(sh), 12) {
            let x = sx(g.rackX(sh))
            c.R(x - 1, gy - 14, 2, 14, Col(0x5a3c22)); c.R(x - 5, gy - 16, 10, 8, Col(0x7a5632))
            star(x, gy - 12, 3.2, GOLD)
        }
        if st.level > 0 && !st.building && vis(g.rackX(st), 12) {
            let x = sx(g.rackX(st))
            c.R(x - 1, gy - 14, 2, 14, Col(0x5a3c22)); c.R(x - 5, gy - 16, 10, 8, Col(0x7a5632))
            c.seg(x - 3, gy - 9, x + 3, gy - 15, 1.2, Col(0xc9a86a))
            c.curve(x - 1, gy - 16, x + 3, gy - 16.5, x + 4.5, gy - 12.5, 1.4, Col(0xb8b8b8))
        }
    }

    /// The old claim out west: a weathered sign and a spoil heap; staked, a windlass over the shaft; guarded, a lookout beside it.
    private func claimSite() {
        let cl = g.claim
        if !vis(cl.x, 50) { return }
        let x = sx(cl.x).rounded(), lv = cl.level
        c.poly(Col(0xa8855a), [x - 6, gy, x + 2, gy - 9, x + 12, gy - 11, x + 22, gy])
        c.poly(Col(0x8a6a44), [x + 8, gy, x + 12, gy - 11, x + 22, gy])
        c.R(x + 30, gy - 12, 1.5, 12, Col(0x5a3c22)); c.R(x + 25, gy - 15, 12, 6, lv > 0 ? Col(0xead7a4) : Col(0x9a8a70))
        c.text("CLAIM", x + 31, gy - 10.6, 3.6, Col(0x4a2a22))
        if lv >= 1 {
            c.R(x + 12, gy - 3, 12, 3, Col(0x1c120c))
            c.R(x + 11, gy - 14, 1.5, 14, Col(0x5a3c22)); c.R(x + 23.5, gy - 14, 1.5, 14, Col(0x5a3c22))
            c.R(x + 10, gy - 15, 16, 2, Col(0x6a4a2e)); c.R(x + 17.5, gy - 13, 0.8, 9, Col(0x2e2622))
            if g.dark() < 0.6 { person(cl.x + 4, 0, 1, false, 3, .miner, true) }
        }
        if lv >= 2 {
            c.R(x - 14, gy - 16, 1.5, 16, Col(0x5a3c22)); c.R(x - 18, gy - 18, 10, 2, Col(0x6a4a2e))
            person(cl.x - 13, 0, -1, false, 8, .deputy, false)
        }
        if cl.flash > 0 { c.R(x - 8, gy - 20, 48, 20, Col(0xfff0c0, cl.flash)) }
    }

    /// The pasture east of town, the herd, and the rope rack beside the stable.
    private func ranch() {
        let st = g.stable
        if st.level > 0 && !st.building && vis(g.rackX(st), 12) {
            let x = sx(g.rackX(st))
            c.R(x - 1, gy - 14, 2, 14, Col(0x5a3c22)); c.R(x - 5, gy - 16, 10, 8, Col(0x7a5632))
            c.ellStroke(x, gy - 12, 2.6, 2.6, 1.2, Col(0xc9a468))
        }
        let p = g.pasture
        if st.level == 0 && g.herd.isEmpty { return }
        if !vis(p.0, p.1 - p.0 + 20) { return }
        let rail = Col(0x7a5632)
        var wx = p.0
        while wx <= p.1 { c.R(sx(wx) - 1, gy - 9, 2, 9, Col(0x5a3c22)); wx += 20 }
        c.R(sx(p.0), gy - 8, p.1 - p.0, 1, rail); c.R(sx(p.0), gy - 4, p.1 - p.0, 1, rail)
        c.R(sx(p.0 + 28), gy - 4, 10, 4, Col(0x6a4a2e)); c.R(sx(p.0 + 29), gy - 4, 8, 1, Col(0x8fc4d4))
        for cw in g.herd where cw.x <= p.1 + 2 { cowAt(cw.x, cw.dir, cw.calf ? 0.6 : 1.0, cw.seed, cw.phase, horns: false) }
    }

    private func cowAt(_ wx: Double, _ dir: Double, _ s: Double, _ seed: Double, _ phase: Double, horns: Bool) {
        if !vis(wx, 20) { return }
        let x = sx(wx)
        let dkc = Int(seed) % 3 == 0
        let body = dkc ? Col(0x3a2e28) : Col(0x8a4a2c), lo = dkc ? Col(0x2a201c) : Col(0x6c3820)
        let sw = sin(phase) * 1.2
        c.save(); c.translate(x, gy); c.scale(dir * s, s)
        c.R(-6 + sw * 0.4, -5, 1.5, 5, lo); c.R(-3 - sw * 0.4, -5, 1.5, 5, lo); c.R(3 + sw * 0.4, -5, 1.5, 5, lo); c.R(5.5 - sw * 0.4, -5, 1.5, 5, lo)
        c.RR(-8, -12, 16, 8, 2.5, body)
        c.RR(6, -14, 6, 5, 1.5, body); c.R(10.5, -11.5, 2, 2, lo)
        if horns {
            c.curve(7, -14, 4, -18, 1.5, -18.5, 1, Col(0xe8dcc4)); c.curve(10.5, -14, 14, -18, 16.5, -18.5, 1, Col(0xe8dcc4))
        } else {
            c.R(6, -15, 1, 1.5, Col(0xe8dcc4)); c.R(10, -15, 1, 1.5, Col(0xe8dcc4))
        }
        c.seg(-8, -11, -10, -5, 0.8, lo)
        if !dkc { c.R(-3, -11, 4, 3, Col(0xe8dcc4, 0.8)) }
        c.restore()
    }

    /// The old mission west of town and the rock arch east of it, where wanted men hole up and road agents wait.
    private func landmarks() {
        let L = g.terrain
        if vis(g.missionX, 50) {
            let x = sx(g.missionX).rounded()
            let adobe = Col(0xd9c2a0), sh = Col(0xb39a78)
            c.R(x - 26, gy - 20, 30, 20, adobe); c.R(x - 26, gy - 20, 30, 2, sh); c.R(x, gy - 20, 4, 20, sh)
            c.R(x - 16, gy - 12, 7, 12, Col(0x3a2a1c)); c.R(x - 4, gy - 15, 4, 5, Col(0x3a2a1c))
            c.R(x + 6, gy - 34, 12, 34, adobe); c.R(x + 15, gy - 34, 3, 34, sh)
            c.R(x + 9, gy - 30, 6, 7, Col(0x3a2a1c)); c.circ(x + 12, gy - 26, 1.6, Col(0xc9a14a))
            c.poly(sh, [x + 5, gy - 34, x + 12, gy - 40, x + 19, gy - 34])
            c.R(x + 11.4, gy - 46, 1.2, 6, Col(0x5a3c22)); c.R(x + 9.6, gy - 44, 4.8, 1.2, Col(0x5a3c22))
            c.poly(sh, [x - 34, gy, x - 30, gy - 9, x - 26, gy - 6, x - 26, gy])
        }
        if vis(g.archX, 60) {
            let x = sx(g.archX).rounded()
            let rock = Col(L.mesa), rs = Col(L.mesaS)
            c.poly(rock, [x - 34, gy, x - 30, gy - 30, x - 22, gy - 44, x + 8, gy - 48, x + 26, gy - 40, x + 32, gy - 18, x + 34, gy, x + 20, gy, x + 18, gy - 20, x + 6, gy - 30, x - 10, gy - 28, x - 18, gy - 14, x - 20, gy])
            c.poly(rs, [x + 8, gy - 48, x + 26, gy - 40, x + 32, gy - 18, x + 34, gy, x + 20, gy, x + 18, gy - 20, x + 14, gy - 34])
            c.R(x - 24, gy - 36, 26, 1, rs.alpha(0.5)); c.R(x - 28, gy - 22, 8, 1, rs.alpha(0.5))
            if g.bio == .snow { c.poly(Col(0xf4f8ff), [x - 22, gy - 44, x + 8, gy - 48, x + 26, gy - 40, x + 10, gy - 44, x - 18, gy - 41]) }
        }
    }

    /// The windmill and the water tower, which stand behind the street.
    private func towers() {
        let st = Col(0x5a4a3a), dkw = Col(0x3a2a1c)
        if vis(992, 40) {
            let x = sx(992).rounded()
            c.seg(x - 7, gy, x - 1.5, gy - 62, 1.4, st); c.seg(x + 7, gy, x + 1.5, gy - 62, 1.4, st)
            var k = 0.0
            while k < 5 { let yy = gy - 8 - k * 11, hw = 6.4 - k * 1; c.seg(x - hw, yy, x + hw, yy, 0.8, st); c.seg(x - hw, yy, x + hw - 1, yy - 11, 0.6, st); k += 1 }
            let a = g.clock * (g.wx == 0 ? 1.2 : 4)
            for i in 0..<8 { let an = a + Double(i) * PI / 4; c.seg(x, gy - 64, x + cos(an) * 10, gy - 64 + sin(an) * 10, 1.6, Col(0xb9b2a4)) }
            c.circ(x, gy - 64, 2, dkw); c.poly(Col(0xb5412e), [x - 3, gy - 64, x - 13, gy - 68, x - 13, gy - 60])
            if g.rodsLv > 0 { c.R(x - 0.5, gy - 82, 1, 10, Col(0x4a4a52)); c.R(x - 1, gy - 83, 2, 2, Col(0xd0d4dc)) }
        }
        if vis(1206, 40) {
            let x = sx(1206).rounded()
            for dx in [-9.0, -3, 3, 9] { c.R(x + dx - 0.7, gy - 46, 1.4, 46, st) }
            c.seg(x - 9, gy - 8, x + 9, gy - 30, 0.7, st); c.seg(x + 9, gy - 8, x - 9, gy - 30, 0.7, st)
            c.RR(x - 13, gy - 68, 26, 23, 2, Col(0x8a6a4a)); c.R(x - 13, gy - 60, 26, 1.4, dkw); c.R(x - 13, gy - 52, 26, 1.4, dkw)
            c.poly(dkw, [x - 15, gy - 68, x, gy - 78, x + 15, gy - 68])
            c.seg(x + 13, gy - 48, x + 20, gy - 40, 1.2, dkw)
            if g.towerLv > 0 { c.R(x - 12, gy - 10, 10, 6, Col(0xc0392b)); c.circ(x - 10, gy - 3, 2.4, dkw); c.circ(x - 4, gy - 3, 2.4, dkw); c.seg(x - 2, gy - 8, x + 6, gy - 12, 1, Col(0xc9c9d0)) }
        }
    }

    /// Flames on a burning roof, and the lightning rods once they are fitted.
    private func fires() {
        for bl in g.b where bl.def.wall != 0 && !bl.def.gate && bl.level > 0 && vis(bl.x, bl.def.w + 20) {
            let x = sx(bl.x), top = gy - bl.def.h - Double(max(0, bl.level - 1)) * 5 - 10
            if g.rodsLv > 0 { c.R(x + 4, top - 9, 1, 9, Col(0x4a4a52)); c.R(x + 3.5, top - 10, 2, 1.5, Col(0xd0d4dc)) }
            if !bl.burning { continue }
            let big = (1 + 0.9 * min(1, bl.fireT / 6)) * (0.5 + 0.5 * bl.fireHp)
            var k = 3.0
            while k < bl.def.w - 3 {
                let f = (6 + sin(g.clock * 11 + k * 1.7) * 3 + hashN(k) * 4) * big
                c.poly(Col(0xff7a2a), [x + k - 3, top + 1, x + k, top + 1 - f, x + k + 3, top + 1])
                c.poly(Col(0xffd45a), [x + k - 1.5, top + 1, x + k, top + 1 - f * 0.55, x + k + 1.5, top + 1])
                k += 5
            }
            c.glow(x + bl.def.w / 2, top - 3, bl.def.w * 0.7, Col(0xff9638, 0.28), Col(0xff9638, 0))
        }
        // riflemen hired onto a gatehouse roof
        for gt in [g.gateW, g.gateE] where gt.rifles >= 4 && vis(gt.x, 30) {
            let x = sx(gt.x), top = gy - gt.def.h - 16
            for i in 0..<(gt.rifles / 4) {
                let hx = x + [-2.0, 13, 4][i]
                c.R(hx, top - 3, 3, 3, Col(0xe2aa7c)); c.R(hx - 1, top - 4, 5, 1, Col(0x5a4630)); c.R(hx, top - 6, 3, 2, Col(0x5a4630))
                c.R(gt.type == .gateE ? hx + 2 : hx - 5, top - 1, 6, 1, Col(0x2a1c14))
            }
        }
    }

    /// The old rail yard past the far east camp: dead engines, a hobo jungle and a boxcar nobody will open.
    private func yard(_ dk: Double) {
        let Y = g.yardX
        if g.cam + W < Y - 40 { return }
        let x0 = sx(Y)
        // the old main line and a siding
        var wx = (max(Y, g.cam) / 4).rounded(.up) * 4
        while wx < g.cam + W { c.R(sx(wx), gy, 2, 1, Col(0x4a3626)); wx += 4 }
        c.R(max(x0, 0), gy - 1, W - max(x0, 0), 1, Col(0x7a6a5a))
        c.R(max(x0 + 60, 0), gy - 4, max(0, sx(Y + 560) - max(x0 + 60, 0)), 1, Col(0x6a5a4a))
        func hulk(_ wxx: Double, _ rust: UInt32) {
            if !vis(wxx, 80) { return }
            let x = sx(wxx).rounded()
            c.ell(x + 26, gy + 1, 34, 2.4, Col(0x000000, 0.2))
            c.RR(x + 6, gy - 20, 30, 12, 3, Col(rust)); c.R(x + 36, gy - 28, 14, 20, Col(rust)); c.R(x + 35, gy - 30, 16, 2, Col(0x2a2220))
            c.R(x + 39, gy - 25, 7, 6, Col(0x14100e)); c.R(x + 10, gy - 28, 4, 8, Col(0x2a2220)); c.R(x + 8, gy - 30, 8, 2, Col(0x2a2220))
            c.poly(Col(0x3a3230), [x, gy - 2, x + 6, gy - 10, x + 6, gy - 2])
            for k in [12.0, 22, 32, 44] { c.circ(x + k, gy - 5, 4, Col(0x2a2220)); c.circ(x + k, gy - 5, 1.2, Col(0x6a5a4a)) }
            for i in 0..<9 { c.R(x + 8 + hashN(Double(i) + wxx) * 38, gy - 19 + hashN(Double(i) * 2 + wxx) * 9, 2 + hashN(Double(i)) * 4, 1, Col(0x96542c, 0.6)) }
        }
        hulk(Y + 90, 0x4a3a34); hulk(Y + 190, 0x3a3a40)
        // a switch stand
        if vis(Y + 40, 30) { let x = sx(Y + 40).rounded(); c.R(x, gy - 22, 1.4, 22, Col(0x3a2a1c)); c.R(x - 3, gy - 26, 7, 5, Col(g.ghostAt > 0 && dk > 0.5 ? 0xff5a3c : 0x8fcf6a)) }
        // the hobo jungle: a barrel fire and three men who have seen everything
        let hx = g.sHobo.x
        if vis(hx, 50) {
            let x = sx(hx).rounded()
            c.R(x - 3, gy - 8, 7, 8, Col(0x4a4a50)); c.R(x - 3.5, gy - 9, 8, 1.2, Col(0x2a2220))
            c.poly(Col(0xff9a2e), [x - 2.5, gy - 9, x, gy - 15 - sin(g.clock * 13) * 2, x + 2.5, gy - 9]); c.poly(Col(0xffe08a), [x - 1.2, gy - 9, x, gy - 12, x + 1.2, gy - 9])
            for (dx, col) in [(-12.0, UInt32(0x6a5a4a)), (10.0, UInt32(0x4a5a4a)), (18.0, UInt32(0x5a4a5a))] {
                c.R(x + dx - 2, gy - 9, 5, 6, Col(col)); c.R(x + dx - 1.5, gy - 12.4, 4, 3.6, Col(0xc9966a)); c.R(x + dx - 3, gy - 13.6, 7, 1.2, Col(0x3a2a1c)); c.R(x + dx - 2, gy - 3, 5, 3, Col(0x3a3230))
            }
            c.poly(Col(0x8a7a5a), [x + 26, gy, x + 34, gy - 12, x + 42, gy])
        }
        // the sealed boxcar, chalk marks and all
        let cx = g.sCar.x
        if vis(cx, 60) {
            let x = (sx(cx) - 29).rounded(), gg = gy - 3
            c.ell(x + 29, gy + 1, 34, 2.4, Col(0x000000, 0.2))
            c.R(x, gg - 22, 58, 18, Col(0x6a3a2a))
            var k = 0.0
            while k < 58 { c.R(x + k, gg - 22, 1, 18, Col(0x140a06, 0.25)); k += 4 }
            c.R(x - 1, gg - 24, 60, 2, Col(0x2a2220)); c.R(x, gg - 5, 58, 1, Col(0x2a2220))
            if g.carCool > 0 { c.R(x + 21, gg - 21, 16, 17, Col(0x0e0908)) } else {
                c.R(x + 21, gg - 21, 16, 17, Col(0x5a4638)); c.seg(x + 21, gg - 21, x + 37, gg - 4, 0.8, Col(0x3a2c24)); c.seg(x + 37, gg - 21, x + 21, gg - 4, 0.8, Col(0x3a2c24)); c.R(x + 28, gg - 13, 3, 3, Col(0xc9a14a))
                if dk > 0.5 { c.glow(x + 29, gg - 13, 20, Col(0x8fcf6a, 0.25 + 0.1 * sin(g.clock * 3)), Col(0x8fcf6a, 0)) }
            }
            for (dx, dy) in [(6.0, -16.0), (8, -14), (10, -16), (46, -12), (48, -12), (47, -14), (47, -10), (44, -18)] { c.R(x + dx, gg + dy, 1, 1, Col(0xe8e2d2)) }
            for wxx in [8.0, 16, 42, 50] { c.circ(x + wxx, gy - 2, 2.2, Col(0x1f1f26)) }
        }
    }

    /// The saucer and its beam, and the train that is not there.
    private func skyThings() {
        if let gx = g.ghostX, vis(gx, 220) {
            let x = sx(gx)
            let col = Col(0xbfffd8, 0.3)
            c.poly(col, [x, gy - 1, x + 8, gy - 9, x + 8, gy - 1])
            c.RR(x + 8, gy - 23, 30, 13, 3, col); c.R(x + 12, gy - 30, 4, 7, col); c.R(x + 38, gy - 30, 16, 28, col)
            c.R(x + 58, gy - 20, 20, 12, col)
            for k in 0..<3 { c.R(x + 82 + Double(k) * 62, gy - 27, 58, 19, col); for wdx in [8.0, 20, 32, 44] { c.R(x + 82 + Double(k) * 62 + wdx, gy - 23, 6, 6, Col(0xe8fff0, 0.4)) } }
            c.glow(x + 2, gy - 22, 30, Col(0xbfffd8, 0.3), Col(0xbfffd8, 0))
        }
        guard let u = g.ufo, vis(u.x, W) else { return }
        let hx = sx(u.x), hy = gy - 76
        var x = hx, y = hy + sin(g.clock * 3) * 1.5, beam = 0.0
        if u.ph == 0 {
            let k = min(1, u.t / 1.5), e = 1 - pow(1 - k, 3)
            x = hx + u.side * W * 0.8 * (1 - e); y = -24 + (hy + 24) * e
        } else if u.ph == 1 { beam = min(1, u.t / 0.35) * min(1, max(0, (2.95 - u.t) / 0.2)) } else {
            let k = u.t / 1.1
            x = hx + u.side * k * k * W * 1.2; y = hy - k * k * gy * 1.3
        }
        if beam > 0 {
            c.poly(Col(0xb8ffd0, 0.22 * beam), [x - 6, y + 4, x + 6, y + 4, x + 20, gy, x - 20, gy])
            c.poly(Col(0xe8fff0, 0.18 * beam), [x - 3, y + 4, x + 3, y + 4, x + 10, gy, x - 10, gy])
            // what it is taking
            c.save(); c.translate(0, -u.lift * 58); c.alpha(1 - u.lift * 0.5)
            if let cw = u.cow { cowAt(cw.x, cw.dir, cw.calf ? 0.6 : 1, cw.seed, 0, horns: false) }
            if let w = u.stray { cowAt(w.x, w.dir, 1, w.seed, 0, horns: true) }
            if let m = u.mustang { _ = horse(sx(m.x), m.dir, 0, 0, Col(0x8a8480), Col(0x4a4642)) }
            c.alpha(1); c.restore()
        }
        c.glow(x, y, 34, Col(0x8cf7b0, 0.3), Col(0x8cf7b0, 0))
        c.ell(x, y, 17, 4.6, Col(0x8a94a4)); c.ell(x, y - 1.2, 15, 3, Col(0xc4ccd8))
        c.ell(x, y - 4.4, 7, 4.4, Col(0xa8f0d0, 0.85)); c.ell(x - 2, y - 5.6, 2.6, 1.6, Col(0xffffff, 0.6))
        for i in 0..<5 { c.circ(x - 12 + Double(i) * 6, y + 0.6, 1.1, Int(g.clock * 6 + Double(i)) % 2 == 0 ? Col(0xfff0a0) : Col(0xff6a5a)) }
    }

    /// The places out of town: trading post, scout camp, ghost town, oil derrick, the medicine show and the cavalry outpost.
    private func sites(_ dk: Double) {
        let wood = Col(0x7a5632), dkw = Col(0x4a3424), canvasC = Col(0xd8c8a0)
        if vis(-90, 50) {
            let x = sx(-90).rounded()
            c.R(x - 18, gy - 20, 36, 20, wood)
            var yy = gy - 17.0
            while yy < gy { c.R(x - 18, yy, 36, 1, dkw.alpha(0.5)); yy += 4 }
            c.poly(dkw, [x - 21, gy - 20, x, gy - 30, x + 21, gy - 20])
            c.R(x - 4, gy - 13, 8, 13, Col(0x2a1c14)); c.R(x - 15, gy - 14, 8, 6, dk > 0.3 ? Col(0xffd98a) : Col(0x9fc4d4))
            c.poly(Col(0xb5412e), [x + 6, gy - 16, x + 22, gy - 12, x + 22, gy - 10, x + 6, gy - 14]); c.R(x + 20, gy - 11, 1.2, 11, dkw)
            c.R(x + 8, gy - 6, 6, 6, Col(0x9a7a4a)); c.R(x + 15, gy - 5, 5, 5, Col(0x8a6a3a))
            c.R(x - 12, gy - 27, 24, 5, Col(0xead7a4)); c.text("TRADING", x, gy - 23, 4, Col(0x4a2a22))
        }
        if vis(-250, 50) {
            let x = sx(-250).rounded()
            for (dx, hh) in [(-16.0, 24.0), (10.0, 20.0)] {
                c.poly(canvasC, [x + dx - 10, gy, x + dx, gy - hh, x + dx + 10, gy]); c.poly(Col(0xb8a880), [x + dx, gy - hh, x + dx + 3, gy, x + dx + 10, gy])
                c.poly(Col(0x3a2a1c), [x + dx - 2.5, gy, x + dx, gy - 8, x + dx + 2.5, gy])
                c.seg(x + dx - 2, gy - hh - 4, x + dx + 2, gy - hh + 2, 0.7, dkw); c.seg(x + dx + 2, gy - hh - 4, x + dx - 2, gy - hh + 2, 0.7, dkw)
                c.R(x + dx - 6, gy - hh * 0.45, 12, 1.2, Col(0xb5412e))
            }
            campfire(-250 - 2, 0.6)
            if g.scoutDays > 0 { c.R(x + 24, gy - 26, 1.2, 26, dkw); c.poly(Col(0xc0392b), [x + 25, gy - 26, x + 33, gy - 23.5, x + 25, gy - 21]) }
        }
        if vis(-434, 70) {
            let x = sx(-434).rounded()
            let stone = Col(0x8a7c6c), sh = Col(0x6a5e52)
            c.R(x - 28, gy - 18, 14, 18, stone); c.poly(stone, [x - 28, gy - 18, x - 24, gy - 26, x - 20, gy - 18]); c.R(x - 24, gy - 12, 5, 7, Col(0x2a221e))
            c.R(x - 8, gy - 24, 3, 24, sh); c.R(x - 8, gy - 24, 20, 3, sh); c.R(x + 10, gy - 14, 3, 14, sh)
            c.R(x + 16, gy - 10, 14, 10, stone); c.poly(sh, [x + 16, gy - 10, x + 22, gy - 16, x + 30, gy - 10])
            c.seg(x - 5, gy - 21, x + 9, gy - 4, 1.2, Col(0x5a4a3a)); c.R(x - 2, gy - 3, 8, 3, sh)
            c.text("BANK", x + 2, gy - 26, 4, Col(0x5a4a3a))
        }
        if vis(-600, 60) {
            let x = sx(-600).rounded()
            c.ell(x, gy + 1, 18, 2.5, Col(0x14121a, 0.85))
            if g.rigLv > 0 {
                let st = Col(0x3a3230)
                c.seg(x - 10, gy, x - 2, gy - 56, 1.6, st); c.seg(x + 10, gy, x + 2, gy - 56, 1.6, st)
                var k = 0.0
                while k < 5 { let yy = gy - 8 - k * 10, hw = 9 - k * 1.5; c.seg(x - hw, yy, x + hw, yy, 1, st); c.seg(x - hw, yy, x + hw - 1.5, yy - 10, 0.7, st); k += 1 }
                c.R(x - 4, gy - 60, 8, 4, st); c.R(x - 0.5, gy - 56, 1, 50, Col(0x1c1a22))
                c.R(x + 14, gy - 8, 12, 8, Col(0x6a5a4a)); c.R(x + 13, gy - 10, 14, 2, Col(0x4a3f38))
                if g.rigBurn {
                    for k2 in 0..<5 {
                        let f = 10 + sin(g.clock * 11 + Double(k2) * 2) * 4
                        c.poly(Col(0xf08a2a), [x - 6 + Double(k2) * 3 - 3, gy - 54, x - 6 + Double(k2) * 3, gy - 54 - f, x - 6 + Double(k2) * 3 + 3, gy - 54])
                    }
                    c.poly(Col(0xffd45a), [x - 4, gy - 54, x, gy - 66 - sin(g.clock * 14) * 3, x + 4, gy - 54])
                } else {
                    let a = sin(g.clock * 2.2) * 0.35
                    c.seg(x + 12 - cos(a) * 8, gy - 16 + sin(a) * 8, x + 12 + cos(a) * 8, gy - 16 - sin(a) * 8, 1.6, st); c.R(x + 11.3, gy - 16, 1.5, 8, st)
                }
            } else {
                c.R(x - 9, gy - 10, 1.2, 10, dkw); c.R(x - 13, gy - 13, 9, 5, Col(0xead7a4)); c.text("OIL", x - 8.5, gy - 9.3, 3.4, Col(0x2a1c14))
            }
        }
        if g.showOn && vis(752, 50) {
            let x = sx(752).rounded()
            c.RR(x - 16, gy - 24, 32, 17, 2, Col(0x7a2f6a)); c.R(x - 17, gy - 26, 34, 3, Col(0xf2c14e)); c.R(x - 14, gy - 21, 28, 8, Col(0xf4ecd6))
            c.text("TONIC", x, gy - 14.6, 5, Col(0x7a2f6a))
            for wx in [x - 9, x + 9] { c.circ(wx, gy - 4.5, 4.5, dkw); c.circ(wx, gy - 4.5, 3, Col(0xc9a86a)); c.circ(wx, gy - 4.5, 0.9, dkw) }
            c.R(x + 20, gy - 12, 4, 7, Col(0x2e2622)); c.R(x + 20.3, gy - 15, 3.4, 3.2, Col(0xd9a878)); c.R(x + 19.6, gy - 19.6, 4.8, 4.6, Col(0x14100e)); c.R(x + 18.4, gy - 15.4, 7.2, 1, Col(0x14100e))
        }
        let fx = g.sFort.x
        if vis(fx, 70) {
            let x = sx(fx).rounded()
            var k = -22.0
            while k < 22 { c.R(x + k, gy - 22, 3, 22, Int(k) % 6 == 0 ? wood : dkw); c.poly(wood, [x + k, gy - 22, x + k + 1.5, gy - 26, x + k + 3, gy - 22]); k += 3 }
            c.R(x - 6, gy - 16, 12, 16, Col(0x3a2a1c)); c.R(x - 23, gy - 14, 46, 1.5, dkw)
            c.R(x + 14, gy - 44, 1.4, 22, dkw)
            let wv = sin(g.clock * 3) * 1.2
            c.poly(Col(0x2f4a7a), [x + 15.4, gy - 44, x + 28, gy - 43 + wv, x + 28, gy - 37 + wv, x + 15.4, gy - 37]); c.R(x + 15.4, gy - 41.4, 12.6, 1.4, Col(0xf2c14e))
            if g.fortNight { c.text("PATROL TONIGHT", x, gy - 29, 4, Col(0xf2c14e)) }
        }
    }

    /// The stagecoach, its team, the driver, the guard if you paid for one, and the road agents at the hold-up.
    private func coach() {
        guard let ch = g.coach else { return }
        if !vis(ch.x, 80) { return }
        let x = sx(ch.x)
        c.ell(x + 8, gy + 1, 30, 2.2, Col(0x000000, 0.2))
        _ = horse(x + 34, 1, ch.phase, ch.moving ? 60 : 0, Col(0x6e4a30), Col(0x3a2416))
        _ = horse(x + 26, 1, ch.phase + 0.8, ch.moving ? 60 : 0, Col(0x8a8480), Col(0x4a4642))
        let red = Col(0x8a2b22), dk = Col(0x2e2622), gold = Col(0xc9a14a)
        c.seg(x + 6, gy - 9, x + 24, gy - 11, 0.8, dk)                                    // the pole and traces
        c.RR(x - 12, gy - 22, 24, 14, 3, red); c.R(x - 13, gy - 24, 26, 2.5, dk); c.R(x - 12, gy - 13, 24, 1, gold)
        c.R(x - 8, gy - 20, 5, 5, Col(0xf0e0b8)); c.R(x - 1, gy - 20, 5, 5, Col(0xf0e0b8)); c.R(x - 9, gy - 14, 16, 0.8, gold)
        c.R(x + 9, gy - 20, 7, 3, dk); c.R(x - 15, gy - 19, 4, 8, Col(0x7a5632))          // the box seat and the boot
        c.R(x - 10, gy - 27, 14, 3, Col(0x7a5632)); c.R(x - 6, gy - 29, 6, 2, Col(0x5a3c22))   // luggage on the roof
        for (wx, r) in [(-7.0, 5.0), (9.0, 4.0)] {
            let cx = x + wx, cy = gy - r
            c.circ(cx, cy, r, dk); c.circ(cx, cy, r - 1.2, Col(0xc9a86a)); c.circ(cx, cy, 1, dk)
            for k in 0..<4 { let a = ch.phase * 0.5 + Double(k) * PI / 4; c.seg(cx - cos(a) * (r - 1), cy - sin(a) * (r - 1), cx + cos(a) * (r - 1), cy + sin(a) * (r - 1), 0.6, dk) }
        }
        // driver, and the guard with his shotgun
        c.R(x + 10, gy - 28, 4, 6, Col(0x5f7896)); c.R(x + 10.5, gy - 31, 3.2, 3, Col(0xd9a878)); c.R(x + 9, gy - 32, 6.5, 1.2, Col(0x4a3424)); c.R(x + 10.5, gy - 34, 3.5, 2.2, Col(0x4a3424))
        c.seg(x + 13, gy - 26, x + 22, gy - 20, 0.5, dk)
        if ch.guarded {
            c.R(x + 4, gy - 29, 4, 6, Col(0x34445a)); c.R(x + 4.5, gy - 32, 3.2, 3, Col(0xb8804e)); c.R(x + 3, gy - 33, 6.5, 1.2, Col(0x2e2622)); c.R(x + 4.5, gy - 35, 3.5, 2.2, Col(0x2e2622))
            c.seg(x + 7, gy - 27, x + 17, gy - 29, 1, Col(0x4a4a50))
            if ch.fl > 0 { c.circ(x + 19, gy - 29, 3, Col(0xfff0b0)) }
        }
        for (i, up) in ch.rob.enumerated() where up {
            let bn = Bandit(x: ch.x + 44 + Double(i) * 14, rider: false, side: 1, hp: 2)
            bandit(bn)
        }
    }

    /// A wanted man where he is holed up, and the duellist down the street.
    private func gunmen() {
        if let o = g.outlaw {
            let bn = Bandit(x: o.x, rider: false, side: -o.dir, hp: 1)
            bn.boss = true; bn.flash = o.flash; bn.st = 1
            bandit(bn)
            if vis(o.x, 40) { c.text("WANTED", sx(o.x), gy - 27, 4.5, Col(0xd04a3a)) }
        }
        if let d = g.duel, d.oppUp {
            let bn = Bandit(x: d.oppX, rider: false, side: 1, hp: 1)
            bn.boss = true; bn.st = 1
            bandit(bn)
        }
    }

    /// High noon: black bars, and the marker that swings across the star.
    private func duelBars() {
        guard let d = g.duel else { return }
        c.R(0, 0, W, 16, Col(0x000000, 0.92)); c.R(0, H - 14, W, 14, Col(0x000000, 0.92))
        if d.st != 1 { return }
        let cx = W / 2, y = 30.0, half = 70.0
        c.RR(cx - half - 4, y - 7, half * 2 + 8, 14, 5, Col(0x2a1c14, 0.85))
        c.R(cx - half, y - 1, half * 2, 2, Col(0xead7a4, 0.6))
        c.RR(cx - half * d.hw * 2.4, y - 4, half * d.hw * 4.8, 8, 2, Col(0xf2c14e, 0.25))
        c.RR(cx - half * d.hw, y - 5, half * d.hw * 2, 10, 2, Col(0xf2c14e, 0.55))
        star(cx, y, 4.5, GOLD)
        let mx = cx + d.pos * half
        c.RR(mx - 1.5, y - 8, 3, 16, 1.5, Col(0xffffff)); c.poly(Col(0xd04a3a), [mx - 3.5, y - 11, mx + 3.5, y - 11, mx, y - 6])
    }

    /// The town centre: a campfire, then a square with a well, then a clock tower.
    private func centre() {
        let hl = g.hall
        if !vis(hl.x, 60) { return }
        let x = sx(hl.x).rounded(), cx = x + 13
        let stone = Col(0xb9b2a4), dks = Col(0x8a8478)
        if hl.level >= 1 {
            c.R(x - 22, gy, 70, 2, stone)
            var k = -22.0
            while k < 48 { c.R(x + k, gy, 1, 2, dks); k += 7 }
        }
        if hl.level == 1 {
            c.R(cx - 6, gy - 6, 12, 6, stone); c.R(cx - 7, gy - 7, 14, 2, dks)
            c.R(cx - 6, gy - 16, 1.5, 10, Col(0x5a3c22)); c.R(cx + 4.5, gy - 16, 1.5, 10, Col(0x5a3c22))
            c.poly(Col(0x6a3c20), [cx - 9, gy - 16, cx, gy - 21, cx + 9, gy - 16])
        } else if hl.level >= 2 {
            c.R(cx - 8, gy - 44, 16, 44, Col(0xc9b98a)); c.R(cx + 5, gy - 44, 3, 44, Col(0x000000, 0.12))
            c.R(cx - 10, gy - 46, 20, 3, Col(0x6a3c20))
            c.poly(Col(0x6a3c20), [cx - 10, gy - 46, cx, gy - 58, cx + 10, gy - 46])
            c.circ(cx, gy - 35, 5.5, Col(0x3a2a1c)); c.circ(cx, gy - 35, 4.5, Col(0xf4ecd6))
            let a = g.t * PI * 4 - PI / 2
            c.seg(cx, gy - 35, cx + cos(a) * 3.5, gy - 35 + sin(a) * 3.5, 0.8, INK)
            c.seg(cx, gy - 35, cx + cos(a / 12) * 2.3, gy - 35 + sin(a / 12) * 2.3, 0.9, INK)
            c.R(cx - 3, gy - 12, 6, 12, Col(0x3a2a1c))
        }
        if hl.building { scaffold(x, 26, hl.level == 0 ? 18 : 50, hl.progress) }
        if hl.flash > 0 { c.R(x - 4, gy - 30, 34, 30, Col(0xfff0c0, hl.flash)) }
    }

    /// Barbed wire outside a gate: one apron, then two, then a sharpshooter's nest behind it.
    private func wire(_ bl: Building) {
        if !vis(bl.x, 40) { return }
        let x = sx(bl.x).rounded(), lv = bl.level
        let post = Col(0x5a3c22), strand = Col(0x3a3a40)
        if lv == 0 {
            if bl.building { c.R(x, gy - 6, 1.5, 6, post); c.R(x + 28, gy - 6, 1.5, 6, post); scaffold(x, 30, 8, bl.progress) }
            return
        }
        var k = 0.0
        while k <= 30 {
            c.seg(x + k - 2, gy, x + k + 2, gy - 8, 1.2, post); c.seg(x + k + 2, gy, x + k - 2, gy - 8, 1.2, post)
            k += 10
        }
        c.R(x - 2, gy - 7, 34, 0.7, strand); c.R(x - 2, gy - 4, 34, 0.7, strand)
        k = 1
        while k < 32 { c.R(x + k, gy - 8, 0.8, 2.5, strand); c.R(x + k + 2, gy - 5, 0.8, 2.5, strand); k += 5 }
        if lv >= 2 { c.R(x - 2, gy - 10, 34, 0.7, strand); c.R(x - 2, gy - 1.5, 34, 0.7, strand) }
        if lv >= 3 {
            // the nest, on the town side
            let nx = bl.type == .wireW ? x + 36 : x - 12
            c.RR(nx, gy - 5, 8, 5, 2, Col(0xb9a37a)); c.RR(nx - 3, gy - 3, 8, 3, 1.5, Col(0xa8926a)); c.RR(nx + 4, gy - 3, 8, 3, 1.5, Col(0xa8926a))
            c.R(nx + 2.5, gy - 9, 3, 3, Col(0xd9a878)); c.R(nx + 1, gy - 10, 6, 1.2, Col(0x4a3424))
            let d = bl.type == .wireW ? -1.0 : 1.0
            c.seg(nx + 4, gy - 6.5, nx + 4 + d * 8, gy - 7.5, 0.9, Col(0x2e2622))
        }
        if bl.building { scaffold(x, 30, 12, bl.progress) }
        if bl.flash > 0 { c.R(x - 2, gy - 11, 34, 11, Col(0xfff0c0, bl.flash)) }
    }

    /// The town's name on a board outside the west gate.
    private func townSign() {
        let wx = 876.0
        if !vis(wx, 50) { return }
        let x = sx(wx).rounded()
        let name = g.townName
        let w = Double(name.count) * 4.6 + 8
        c.R(x - 1, gy - 20, 2, 20, Col(0x5a3c22))
        c.R(x - w / 2, gy - 27, w, 10, Col(0xead7a4))
        c.R(x - w / 2, gy - 27, w, 1, Col(0x5a3c22)); c.R(x - w / 2, gy - 18, w, 1, Col(0x5a3c22))
        c.text(name, x, gy - 19.5, 6.5, Col(0x4a2a22))
    }

    /// The rails, laid from the east as the station goes up, and the train standing on them.
    private func rail(_ dk: Double) {
        let s = g.station
        if s.level == 0 && !s.building { return }
        let headW = s.level > 0 ? STOP - 4 : WORLD - (WORLD - STOP + 4) * clampD(s.progress, 0, 1)
        let head = sx(headW)
        if head < W {
            var wx = (max(headW, g.cam) / 4).rounded(.up) * 4
            while wx < g.cam + W { c.R(sx(wx), gy, 2, 1, Col(0x4a3626)); wx += 4 }
            c.R(max(head, 0), gy - 1, W - max(head, 0), 1, Col(0x8a8f98))
            if s.level > 0 { c.R(head - 2, gy - 5, 2, 5, Col(0x6a2f26)); c.R(head - 3, gy - 6, 4, 1, Col(0x6a2f26)) }
        }
        guard let tr = g.train else { return }
        let x = sx(tr.x)
        if x > W + 10 || x < -200 { return }
        let bk = Col(0x2b2b33), dkc = Col(0x1f1f26), br = Col(0xc9a14a), red = Col(0x7a2f26)
        let glass = dk > 0.3 ? Col(0xffd98a) : Col(0x9fc4d4)
        c.ell(x + 94, gy + 1, 96, 2.5, Col(0x000000, 0.2))
        c.save()
        c.translate(x, gy - 1)
        c.scale(1.3, 1.3)
        func wheel(_ wx: Double, _ r: Double) {
            c.circ(wx, -r, r, dkc); c.circ(wx, -r, r - 1, Col(0x4a4a56))
            let a = tr.x / (r * 1.3)
            c.seg(wx - cos(a) * (r - 1), -r - sin(a) * (r - 1), wx + cos(a) * (r - 1), -r + sin(a) * (r - 1), 0.8, dkc)
            c.circ(wx, -r, 0.9, br)
        }
        // locomotive: cowcatcher, boiler, lamp, stack, dome and cab
        c.poly(Col(0x3a3a44), [0, 0, 6, -7, 6, 0])
        c.R(6, -8, 36, 2, dkc)
        c.RR(6, -17, 24, 9, 2, bk); c.R(6, -17, 24, 1, Col(0x4a4a56))
        c.R(12, -17, 1, 9, br); c.R(21, -17, 1, 9, br)
        c.R(2, -20, 3, 3, Col(0x3a3a44)); c.R(2, -19, 1, 1, Col(0xffe58a))
        c.R(9, -22, 3, 5, dkc); c.R(8, -24, 5, 2, dkc); c.R(7, -26, 7, 2, dkc)
        c.RR(16, -20, 5, 4, 2, br)
        c.R(30, -23, 12, 15, red); c.R(29, -24, 14, 2, dkc); c.R(33, -21, 6, 5, glass)
        wheel(11, 3); wheel(19, 3); wheel(29, 4); wheel(38, 4)
        c.R(10, -4, 28, 1, br)
        // tender
        c.R(42, -6, 4, 1, dkc)
        c.R(46, -15, 15, 9, bk); c.poly(Col(0x15151a), [47, -15, 50, -18, 57, -18, 60, -15])
        wheel(50, 2.5); wheel(57, 2.5)
        // passenger car
        c.R(61, -6, 4, 1, dkc)
        c.R(64, -21, 46, 15, red); c.R(63, -23, 48, 2, dkc); c.R(64, -12, 46, 1, br)
        for k in 0..<5 { c.R(68 + Double(k) * 7.5, -19, 5, 5, glass) }
        c.R(105, -19, 3, 12, dkc)
        c.R(110, -8, 3, 2, dkc); c.R(112, -16, 1, 9, dkc)
        wheel(70, 2.5); wheel(77, 2.5); wheel(97, 2.5); wheel(104, 2.5)
        c.restore()
    }

    private func star(_ x: Double, _ y: Double, _ r: Double, _ col: Col) {
        var p: [Double] = []
        for i in 0..<10 {
            let a = -PI / 2 + Double(i) * PI / 5
            let rr = i % 2 == 0 ? r : r * 0.45
            p.append(x + cos(a) * rr); p.append(y + sin(a) * rr)
        }
        c.poly(col, p)
    }

    private func gate(_ bl: Building) {
        if !vis(bl.x, 30) { return }
        let x = sx(bl.x).rounded(), lv = bl.level
        let wood = Col(0x7a5632), dkw = Col(0x4a3424)
        if lv == 0 {
            c.R(x + 1, gy - 5, 2, 5, dkw); c.R(x + 10, gy - 4, 2, 4, dkw)
            c.seg(x - 2, gy - 1, x + 9, gy - 3, 1.5, Col(0x5c5048))
            if bl.building { scaffold(x, 14, 16, bl.progress) }
            return
        }
        let h = [0.0, 16, 26, 36][min(lv, 3)]
        if lv == 1 {
            c.R(x + 1, gy - h, 2, h, dkw); c.R(x + 11, gy - h, 2, h, dkw)
            c.seg(x, gy - 2, x + 14, gy - h + 2, 2, wood); c.seg(x + 14, gy - 2, x, gy - h + 2, 2, wood)
            c.R(x, gy - h * 0.55, 14, 2, wood)
        } else {
            var k = 0.0
            while k < 14 { c.R(x + k, gy - h + (Int(k) % 4 == 0 ? 0 : 2), 2, h, Int(k) % 4 == 0 ? wood : dkw); c.poly(wood, [x + k, gy - h, x + k + 1, gy - h - 3, x + k + 2, gy - h]); k += 2 }
            c.R(x - 1, gy - h * 0.7, 16, 2, dkw); c.R(x - 1, gy - h * 0.3, 16, 2, dkw)
            if lv >= 3 {
                c.R(x - 4, gy - h - 12, 22, 3, dkw); c.R(x - 3, gy - h - 9, 2, 9, dkw); c.R(x + 15, gy - h - 9, 2, 9, dkw)
                c.R(x - 5, gy - h - 16, 24, 4, Col(0x6a3c20))
                // the Gatling gun on the roof, pointing out of town
                let gd = bl.type == .gateW ? -1.0 : 1.0
                c.R(x + 5, gy - h - 19, 4, 3, Col(0x4a4a50)); c.seg(x + 7, gy - h - 18, x + 7 + gd * 9, gy - h - 18, 1.6, Col(0x2e2622))
            }
        }
        // what is left of the gate's strength
        let full = GHP[min(lv, 3)]
        if bl.hp < full - 0.5 {
            c.R(x - 2, gy - h - 7, 18, 3, Col(0x2a1c14, 0.8))
            c.R(x - 1, gy - h - 6, 16 * clampD(bl.hp / full, 0, 1), 1, Col(0xd04a3a))
        }
        if bl.flash > 0 { c.R(x - 1, gy - h, 16, h, Col(0xffffff, bl.flash * 2)) }
        if bl.building { scaffold(x, 14, h + 8, bl.progress) }
    }

    private func box(_ bx: Box) {
        if !vis(bx.x, 12) { return }
        let x = sx(bx.x).rounded()
        if bx.open {
            c.R(x - 5, gy - 4, 10, 4, Col(0x5a3c22)); c.poly(Col(0x7a5632), [x - 5, gy - 4, x - 7, gy - 9, x + 3, gy - 9, x + 5, gy - 4])
        } else {
            c.R(x - 5, gy - 6, 10, 6, Col(0x7a5632)); c.R(x - 5, gy - 7, 10, 2, Col(0x5a3c22))
            c.R(x - 1, gy - 5, 2, 2, GOLD); c.R(x - 5, gy - 4, 1, 4, Col(0x2e2622)); c.R(x + 4, gy - 4, 1, 4, Col(0x2e2622))
        }
    }

    // ---------- people and horses
    private func person(_ wx: Double, _ phase: Double, _ dir: Double, _ moving: Bool, _ seed: Double, _ role: Role, _ work: Bool, ragged: Bool = false) {
        if !vis(wx, 10) { return }
        let x = sx(wx)
        let k = Int(seed)
        let skin = SKIN[k % SKIN.count]
        var shirt = SHIRT[(k / 3) % SHIRT.count]
        var hat = HAT[(k / 5) % HAT.count]
        if ragged { shirt = Col.mix(shirt, Col(0x7a6a58), 0.6) }
        if role == .deputy { shirt = Col(0x34445a); hat = Col(0x2e2622) }
        if role == .miner { shirt = Col(0x7a7468); hat = Col(0xc9a86a) }
        if role == .rancher { shirt = Col(0xc9a468); hat = Col(0x6a4a2e) }
        let sw = moving ? sin(phase) * 2 : 0
        let bob = work ? abs(sin(g.clock * 9 + seed)) * 1.5 : 0
        // legs
        c.R(x - 2 + sw * 0.5, gy - 5, 2, 5, Col(0x3a3a4a)); c.R(x + 0.5 - sw * 0.5, gy - 5, 2, 5, Col(0x3a3a4a))
        // body, arms, head, hat
        c.R(x - 2.5, gy - 11 + bob * 0.3, 5, 6, shirt)
        if work {
            let a = sin(g.clock * 9 + seed)
            c.seg(x + dir * 2, gy - 9, x + dir * 6, gy - 11 - a * 3, 1.2, skin)
            c.R(x + dir * 6 - 1, gy - 13 - a * 3, 2.5, 2, Col(0x8a8a8a))
        } else {
            c.R(x + dir * 2, gy - 10, 1.2, 4, shirt)
        }
        c.R(x - 1.5, gy - 14 + bob * 0.3, 3.5, 3.2, skin)
        c.R(x - 3.5, gy - 15 + bob * 0.3, 7.5, 1.2, hat); c.R(x - 2, gy - 17 + bob * 0.3, 4.5, 2.2, hat)
        if role == .deputy { star(x - dir * 0.5, gy - 8.5, 1.5, GOLD) }
        if role == .miner { c.seg(x - dir * 2, gy - 12, x - dir * 4, gy - 4, 1, Col(0x8a6a4a)) }
    }

    /// A horse in profile, facing `dir`: jointed legs that walk or gallop, a mane and tail that stream at speed, a head that nods at rest.
    private func horse(_ x: Double, _ dir: Double, _ phase: Double, _ speed: Double, _ coat: Col, _ dark: Col, tack: Bool = false) -> Double {
        let mv = speed > 4, gal = speed > 55
        let ph = phase * 2
        let bob = gal ? sin(ph * 2) * 1.1 : (mv ? sin(ph * 2) * 0.45 : 0)
        let lite = Col.mix(coat, Col(0xffffff), 0.16), shade = Col.mix(coat, dark, 0.55)
        let hoof = Col(0x1c1410)
        c.save()
        c.translate(x, gy)
        c.scale(dir, 1)
        c.roundCaps(true)
        // one leg: hip, a knee that bends forward as the foot lifts, cannon bone, hoof
        func leg(_ hx: Double, _ off: Double, _ far: Bool, _ fore: Bool) {
            let a = ph + off
            let up = mv ? max(0, sin(a)) * (gal ? 4.2 : 2.2) : 0
            let stride = mv ? (gal ? 6.5 : 3.2) : 0
            let hy = -9.5 + bob
            let fx = hx - cos(a) * stride, fy = -1 - up
            let kx = (hx + fx) / 2 + (fore ? 1 : -1) * (0.7 + up * 0.75), ky = (hy + fy) / 2 - (fore ? 0 : 0.6)
            let col = far ? dark : shade
            c.seg(hx, hy, kx, ky, 2.6, col)
            c.seg(kx, ky, fx, fy, 1.7, col)
            c.R(fx - 1, fy - 0.2, 2.6, 1.3, hoof)
            if !far && tack { c.R(fx - 0.8, fy - 2.2, 2.2, 1.2, Col(0xf0e6d2)) }      // white socks
        }
        let offs: [Double] = gal ? [0.7, PI + 0.7, 0, PI] : [PI, PI * 1.5, 0, PI * 0.5]
        leg(-7.5, offs[2], true, false); leg(7, offs[3], true, true)
        // tail: strands that hang at rest and stream out at a gallop
        let tx = -11.0, ty = -15 + bob
        for k in 0..<5 {
            let wv = sin(g.clock * (gal ? 17 : 3) + Double(k) * 1.3 + x * 0.05) * (gal ? 1.4 : 0.5)
            let ex = tx - (gal ? 9.5 : (mv ? 4.5 : 2.6)) - Double(k - 2) * 0.4
            let ey = ty + (gal ? 1.5 : (mv ? 6 : 9)) + Double(k) * 0.8 + wv
            c.curve(tx + 0.5, ty + Double(k) * 0.4, tx - (gal ? 4 : 1.2), ty + (gal ? -1 : 3) + Double(k) * 0.4, ex, ey, 1.1, k % 2 == 0 ? dark : shade)
        }
        // barrel, quarters and chest
        c.RR(-11, -17.5 + bob, 22.5, 10, 4.5, coat)
        c.circ(-6.8, -12.6 + bob, 5.4, coat); c.circ(7.6, -12.4 + bob, 5.2, coat)
        c.RR(-8, -9.4 + bob, 15, 1.8, 0.9, shade.alpha(0.55))
        c.RR(-6, -17 + bob, 12, 1.1, 0.5, lite.alpha(0.8))
        c.curve(-10.5, -13 + bob, -8, -9 + bob, -4.5, -8.4 + bob, 0.7, shade.alpha(0.6))
        leg(-5, offs[0], false, false); leg(4.2, offs[1], false, true)
        // neck and head, which dips now and then when he stands
        let nk = sin(g.clock * 0.55 + x * 0.01)
        let nod = !mv && nk > 0.5 ? (nk > 0.86 ? 2.2 : 1.1) : (gal ? sin(ph * 2 + 1) * 0.7 : 0)
        let hy = bob + nod
        c.poly(coat, [4.5, -16.8 + bob, 11.5, -25 + hy, 16.6, -23.4 + hy, 13, -9.8 + bob, 8, -9.5 + bob])
        c.poly(shade.alpha(0.5), [11, -11 + bob, 15.6, -22.6 + hy, 16.6, -23.4 + hy, 13, -9.8 + bob])
        c.RR(12.4, -28 + hy, 9, 5.6, 2.2, coat)
        c.RR(18.2, -26.8 + hy, 5, 4.6, 2, shade)
        c.R(21.6, -24.2 + hy, 0.9, 0.9, hoof)                                    // nostril
        c.circ(15.6, -25.8 + hy, 0.75, hoof); c.R(15.2, -26.2 + hy, 0.5, 0.5, Col(0xffffff, 0.8))   // eye
        c.poly(dark, [12.6, -27.6 + hy, 13.6, -31.4 + hy, 15, -27.8 + hy]); c.poly(coat, [13, -27.8 + hy, 13.6, -30.4 + hy, 14.4, -27.8 + hy])
        if tack { c.poly(Col(0xf0e6d2), [16.6, -27.6 + hy, 18.2, -27.4 + hy, 20.2, -24 + hy, 19.2, -23.6 + hy]) }   // a blaze
        // mane: a dark crest down the neck, forelock, and strands that lift at a gallop
        c.poly(dark, [5, -17.4 + bob, 11.2, -25.6 + hy, 13.4, -28 + hy, 12.2, -23 + hy, 7.4, -14.6 + bob])
        c.seg(13.6, -28.2 + hy, 15.4, -26.6 + hy, 1.1, dark)
        if mv {
            for k in 0..<4 {
                let mx = 11.5 - Double(k) * 1.7, my = -25 + hy * 0.6 + Double(k) * 2.3
                c.seg(mx, my, mx - (gal ? 3.6 : 1.8), my - (gal ? 1.2 : -0.4) + sin(g.clock * 20 + Double(k) * 1.4) * 0.7, 0.9, dark)
            }
        }
        if tack {
            // bridle
            let lth = Col(0x2a1c14)
            c.seg(14.2, -28 + hy, 20, -23.4 + hy, 0.6, lth); c.seg(17.4, -27.6 + hy, 17.8, -22.8 + hy, 0.6, lth); c.seg(19.6, -27 + hy, 20.2, -22.6 + hy, 0.6, lth)
            c.circ(20, -23.4 + hy, 0.7, Col(0xc9c9d0))
        }
        c.roundCaps(false)
        c.restore()
        return hy
    }

    /// The rider: hat, scarf, vest, gunbelt and boots in the stirrups, on a saddled horse.
    private func rider() {
        let x = sx(g.px)
        let speed = abs(g.pvx)
        let mv = speed > 4, gal = speed > 55
        c.ell(x, gy + 1, 14, 2.2, Col(0x000000, 0.22))
        let headY = horse(x, g.pdir, g.pphase, speed, Col(0x9a5a34), Col(0x4a2a18), tack: true)
        let ph = g.pphase * 2
        let hb = gal ? sin(ph * 2) * 1.1 : (mv ? sin(ph * 2) * 0.45 : 0)
        // he rises a little out of the saddle at a gallop
        let bob = hb - (gal && sin(ph * 2 - 1.2) > 0 ? 1 : 0)
        let lean = gal ? 1.2 : 0
        let lth = Col(0x2a1c14), skin = Col(0xd9a878), skinD = Col(0xb8804e)
        c.save()
        c.translate(x, gy)
        c.scale(g.pdir, 1)
        c.roundCaps(true)
        // saddle blanket, saddle, horn, cinch
        c.RR(-6.5, -18.6 + hb, 12, 3.6, 1, Col(0xb5412e)); c.R(-6.5, -16.4 + hb, 12, 0.8, Col(0xf2c14e)); c.R(-6.5, -17.6 + hb, 12, 0.5, Col(0x2e4a6a))
        c.RR(-4.6, -20.2 + hb, 9, 3, 1.5, Col(0x5a3420)); c.RR(-5.4, -21.4 + hb, 2.4, 2.6, 1, Col(0x4a2a18)); c.R(3.2, -21.6 + hb, 1.3, 2.2, Col(0x4a2a18))
        c.R(0.4, -17.2 + hb, 1.2, 7.4, lth)
        // the streaming scarf
        let n = mv ? (gal ? 14 : 8) : 5
        for i in 0..<n {
            let u = Double(i) / Double(n)
            let wv = sin(g.clock * (mv ? 15 : 3) - Double(i) * 0.55) * (0.3 + u * (gal ? 1.8 : 1))
            let sxx = -2 - Double(i) * 0.62 + lean, syy = -27.4 + bob + (mv ? wv : Double(i) * 0.55 + wv * 0.3)
            c.R(sxx, syy, 0.9, 1.5 - u * 0.7, i > n * 6 / 10 ? Col(0x8f2c23) : Col(0xc9402f))
        }
        // leg: chaps over jeans, boot and spur in the stirrup
        c.seg(0.2, -19 + bob, 3.2, -13.2 + hb, 3, Col(0x6a4a2e))
        c.seg(3.2, -13.2 + hb, 2.4, -8.8 + hb, 2.4, Col(0x7a5632))
        c.seg(1.4, -17 + hb, 2.6, -8 + hb, 0.5, lth)                                   // stirrup leather
        c.RR(1, -9.2 + hb, 5, 2.2, 0.8, Col(0x2e2622)); c.R(1, -7.4 + hb, 1.4, 0.9, Col(0x2e2622)); c.circ(0.6, -8 + hb, 0.6, Col(0xc9c9d0))
        c.R(0.6, -7.2 + hb, 5.6, 0.7, Col(0x8a8a90))                                    // stirrup iron
        // body: shirt, vest, gunbelt and holster
        c.RR(-3.2 + lean, -27.2 + bob, 6.6, 9.6, 1.4, Col(0xc9b48a))
        c.R(-3.2 + lean, -27 + bob, 2.2, 8.6, Col(0x5a3c22)); c.R(1.4 + lean, -26.6 + bob, 1.6, 8, Col(0x5a3c22))
        c.R(-3.4 + lean * 0.5, -19.6 + bob, 7, 1.5, Col(0x3a2a1c)); c.R(0.2 + lean * 0.5, -19.7 + bob, 1.4, 1.6, Col(0xf2c14e))
        c.RR(-3.6, -19 + bob, 2.6, 4.4, 0.8, Col(0x3a2a1c)); c.R(-3.2, -20.2 + bob, 1.4, 1.6, Col(0x8a8a90))
        // neckerchief knot
        c.RR(-2.4 + lean, -28.4 + bob, 5.6, 2.2, 1, Col(0xc9402f))
        // head: jaw, ear, eye, hair at the nape
        let hx = lean * 1.3
        c.RR(-2 + hx, -32.6 + bob, 5.2, 4.8, 1.3, skin)
        c.R(-2 + hx, -29.4 + bob, 4.4, 1, skinD.alpha(0.6))
        c.R(-2.3 + hx, -32.4 + bob, 1.5, 3.2, Col(0x3a2a1c))
        c.R(1.7 + hx, -31.2 + bob, 0.8, 0.9, Col(0x1c120c)); c.R(2.9 + hx, -30.6 + bob, 0.7, 1.1, skinD)
        // hat: brim with a curl, creased crown, band
        c.RR(-6 + hx, -33.6 + bob, 13, 1.7, 0.8, Col(0x4a3424)); c.R(-6 + hx, -34.2 + bob, 1.6, 0.9, Col(0x4a3424)); c.R(5.4 + hx, -34.2 + bob, 1.6, 0.9, Col(0x4a3424))
        c.RR(-3 + hx, -37.4 + bob, 7, 4.2, 1.6, Col(0x5a4030)); c.R(-3 + hx, -34.6 + bob, 7, 1.1, Col(0x2a1c14)); c.R(-0.6 + hx, -37.4 + bob, 2.2, 0.8, Col(0x4a3424))
        c.R(-2.2 + hx, -36.6 + bob, 1, 2, Col(0x6e5240))
        // arm: sleeve to the elbow, forearm, hand
        let shx = 0.6 + lean, shy = -25.4 + bob
        func arm(_ ex: Double, _ ey: Double, _ hxx: Double, _ hyy: Double) {
            c.seg(shx, shy, ex, ey, 2.2, Col(0xc9b48a)); c.seg(ex, ey, hxx, hyy, 1.8, Col(0xb8a27a)); c.circ(hxx, hyy, 1.1, skin)
        }
        if g.gunT > 0 || g.input.fire {
            arm(4.4, -24.2 + bob, 8.6, -24.6 + bob)
            c.R(8.6, -25.6 + bob, 5.6, 1.6, Col(0x4a4a50)); c.R(8.4, -24.4 + bob, 1.6, 2.4, Col(0x5a3c22)); c.R(10, -24.2 + bob, 1.4, 1, Col(0x3a3a40))
            if g.gunT > 0.07 { c.circ(16, -24.8 + bob, 3.2, Col(0xfff0b0)); c.circ(16, -24.8 + bob, 1.7, Col(0xffffff)); c.seg(17, -24.8 + bob, 21, -24.8 + bob, 1, Col(0xfff0b0, 0.8)) }
        } else if g.tossT > 0 {
            arm(4, -27.4 + bob, 7.4, -30.6 + bob)
        } else {
            arm(3.2, -21.6 + bob, 6.4, -20.2 + hb)
            // reins from his hand to the bit
            c.curve(6.4, -20.2 + hb, 13, -18.4 + hb, 20, -23.4 + headY, 0.55, lth)
        }
        c.roundCaps(false)
        c.restore()
        if g.hurtT > 0 && Int(g.clock * 16) % 2 == 0 { c.circ(x, gy - 18, 12, Col(0xd04a3a, 0.25)) }
    }

    private func bandit(_ bn: Bandit) {
        if !vis(bn.x, 30) { return }
        let dir = bn.st == 3 ? bn.side : -bn.side
        let x = sx(bn.x)
        let moving = bn.st == 0 || bn.st == 3
        if bn.rider {
            _ = horse(x, dir, bn.phase, moving ? 74 : 0, Col(0x3a3230), Col(0x1c1816))
            let bob = moving ? sin(bn.phase * 2) * 0.8 : 0
            c.R(x - 3, gy - 25 + bob, 6, 9, Col(0x2e2622)); c.R(x - 1, gy - 16 + bob, 3, 7, Col(0x2a2a30))
            c.R(x - 2, gy - 29 + bob, 4.5, 4, Col(0xb8804e)); c.R(x - 2.5, gy - 27 + bob, 5.5, 2.4, Col(0xa02a22))
            c.R(x - 5, gy - 30 + bob, 11, 1.5, Col(0x14100e)); c.R(x - 2.5, gy - 33 + bob, 6, 3.2, Col(0x14100e))
        } else {
            let sw = moving ? sin(bn.phase) * 2 : 0
            c.R(x - 2 + sw * 0.5, gy - 5, 2, 5, Col(0x2a2a30)); c.R(x + 0.5 - sw * 0.5, gy - 5, 2, 5, Col(0x2a2a30))
            c.R(x - 2.5, gy - 11, 5, 6, Col(0x2e2622))
            c.R(x - 1.5, gy - 14, 3.5, 3.2, Col(0xb8804e)); c.R(x - 2, gy - 12.6, 4.5, 1.8, Col(0xa02a22))
            c.R(x - 3.5, gy - 15, 7.5, 1.2, Col(0x14100e)); c.R(x - 2, gy - 17, 4.5, 2.2, Col(0x14100e))
            if bn.st == 1 || bn.st == 2 { let a = sin(g.clock * 12 + bn.x); c.seg(x + dir * 2, gy - 9, x + dir * 6, gy - 10 - a * 3, 1.2, Col(0x8a8a8a)) }
        }
        if bn.boss {            // taller, in a long red duster, gun drawn
            c.R(x - 3, gy - 14, 6, 10, Col(0x6a231c)); c.R(x - 3.5, gy - 8, 7, 4, Col(0x561a14))
            c.R(x - 1.5, gy - 17.5, 3.5, 3.5, Col(0xb8804e)); c.R(x - 2, gy - 15.6, 4.5, 1.6, Col(0x14100e))
            c.R(x - 4.5, gy - 18.5, 9.5, 1.3, Col(0x14100e)); c.R(x - 2.5, gy - 21, 5.5, 2.8, Col(0x14100e))
            c.seg(x + dir * 2, gy - 11, x + dir * 7, gy - 11, 1.3, Col(0x8a8a8a))
        }
        if bn.loot > 0 { c.circ(x - dir * 4, gy - 9, 2.5, Col(0xc9a86a)); c.R(x - dir * 4 - 0.5, gy - 10, 1, 2, INK) }
        if bn.flash > 0 { c.circ(x, gy - (bn.rider ? 18 : 9), bn.rider ? 13 : 7, Col(0xffffff, 0.5)) }
    }

    // ---------- coins, shots, dust
    private func coinAt(_ x: Double, _ y: Double) {
        c.circ(x, y, 2, GOLDD); c.circ(x, y, 1.5, GOLD); c.R(x - 0.8, y - 1, 0.8, 0.8, Col(0xfff6c8))
    }

    private func coins() {
        for gc in g.ground where vis(gc.x, 6) { coinAt(sx(gc.x), gy - 2 - gc.y) }
        for fc in g.flying where fc.u > 0 {
            let u = fc.u
            let x = lerp(fc.sx, fc.tx, u), y = lerp(fc.sy, fc.ty, u) - sin(u * PI) * 16
            coinAt(sx(x), gy + y)
        }
    }

    private func effects() {
        for s in g.shots {
            let x = sx(s.x)
            c.seg(x, gy + s.y, x - sgn(s.vx) * 9, gy + s.y, 1, Col(0xfff0b0, 0.9))
        }
        for p in g.parts {
            let a = clampD(p.life / p.max, 0, 1)
            c.R(sx(p.x) - p.s / 2, gy + p.y - p.s, p.s, p.s, p.c.alpha(p.c.a * a))
        }
    }

    /// Rain, snow, dust and lightning, over everything.
    private func weather(_ dk: Double) {
        let rain = g.rainI(), snowy = g.bio == .snow
        if g.storm {
            c.R(0, 0, W, H, snowy ? Col(0xf4f8ff, 0.3) : Col(0xb08a52, 0.3))
            for i in 0..<46 {
                let sp = 150 + hashN(Double(i) * 1.9) * 120
                let x = W - (hashN(Double(i) * 5.3) * W + g.clock * sp).truncatingRemainder(dividingBy: W + 30)
                let y = hashN(Double(i) * 8.1) * H + sin(g.clock * 2 + Double(i)) * 3
                c.R(x, y, snowy ? 3 : 9, 1, snowy ? Col(0xffffff, 0.8) : Col(g.terrain.dust, 0.45))
            }
        } else if snowy && g.wx == 2 {
            for i in 0..<60 {
                let x = (hashN(Double(i) * 5.3) * W + sin(g.clock * 0.8 + Double(i)) * 6 - g.cam * 0.3).truncatingRemainder(dividingBy: W)
                let y = (hashN(Double(i) * 8.1) * H + g.clock * (14 + hashN(Double(i)) * 14)).truncatingRemainder(dividingBy: H)
                c.R(x < 0 ? x + W : x, y, 1.4, 1.4, Col(0xffffff, 0.85))
            }
        } else if rain > 0.03 {
            c.R(0, 0, W, H, Col(0x2a3440, 0.16 * rain))
            let n = Int(90 * rain)
            for i in 0..<n {
                let x = (hashN(Double(i) * 5.3) * (W + 40) - g.clock * 60).truncatingRemainder(dividingBy: W + 40) + W
                let xx = x.truncatingRemainder(dividingBy: W + 40) - 20
                let y = (hashN(Double(i) * 8.1) * H + g.clock * (240 + hashN(Double(i)) * 80)).truncatingRemainder(dividingBy: H)
                c.seg(xx, y, xx - 2, y + 7, 0.6, Col(0xcfe0ee, 0.45))
            }
        }
        if g.bolt > 0 {
            let a = clampD(g.bolt / 0.35, 0, 1)
            var x = sx(g.boltX), y = 0.0
            var k = 0.0
            while y < gy {
                let nx = x + (hashN(g.boltX + k) - 0.5) * 16, ny = min(gy, y + 9 + hashN(g.boltX * 2 + k) * 8)
                c.seg(x, y, nx, ny, 1.6, Col(0xfffbe6, a)); c.seg(x, y, nx, ny, 4, Col(0xbfd4ff, a * 0.25))
                x = nx; y = ny; k += 1
            }
        }
    }

    private func night(_ dk: Double) {
        if dk <= 0.02 { return }
        c.R(0, 0, W, H, Col(0x0a1030, 0.36 * dk))
        c.blend(.plusLighter)
        func light(_ wx: Double, _ h: Double, _ r: Double, _ a: Double) {
            if !vis(wx, r) { return }
            c.glow(sx(wx), gy - h, r, Col(0xffb85a, a * dk), Col(0xffb85a, 0))
        }
        light(FIRE_X, 5, 60 + sin(g.clock * 9) * 3, 0.5)
        for cp in g.camps { light(cp.0 + 22, 4, 34, 0.4) }
        if let tr = g.train { light(tr.x + 3, 25, 30, 0.6); light(tr.x + 130, 22, 40, 0.3) }
        for bl in g.b where bl.level > 0 && !bl.def.gate && !bl.robbed {
            for wn in bl.def.wins { light(bl.x + wn.0 + wn.1 / 2, 15, 22, 0.28) }
        }
        c.blend(.normal)
    }

    /// Coin slots over the building the rider is standing at: filled ones are paid.
    private func slots() {
        guard let bl = g.slotsFor, vis(bl.x, bl.def.w) else { return }
        let n = bl.cost
        if n <= 0 { return }
        let per = min(n, 10)
        let rows = (n + per - 1) / per
        var tall = bl.def.h + Double(max(0, bl.level - 1)) * 5
        if bl.isHall && bl.level == 1 { tall = 26 }
        var gap = 34.0
        if bl.def.gate || bl.wire || bl.isHall { gap = 12 } else if bl.virt { gap = 26 } else if bl.site { gap = 4 }
        let top = gy - tall - gap - Double(rows) * 6
        let cx = sx(bl.cx)
        // every row is centred over the building, with no panel behind
        for i in 0..<n {
            let row = i / per
            let inRow = row == rows - 1 ? n - row * per : per
            let x = cx - Double(inRow - 1) * 3 + Double(i % per) * 6
            let y = top + Double(row) * 6
            if i < bl.paid { coinAt(x, y) } else {
                c.ellStroke(x, y, 1.9, 1.9, 1.5, Col(0x2a1c14, 0.7))
                c.ellStroke(x, y, 1.9, 1.9, 0.7, Col(0xf7d877))
            }
        }
    }
}
