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
        if let gl = g.gallery { galleryBooth(gl); return }
        let dk = g.dark()
        let dusk = smooth(0.56, 0.70, g.t) * (1 - smooth(0.74, 0.84, g.t)) + (g.t < 0.08 ? 1 - g.t / 0.08 : 0) * 0.6
        c.save()
        if g.shake > 0 { c.translate(rnd(-1, 1) * g.shake * 2, rnd(-1, 1) * g.shake * 1.5) }
        if g.zoom != 1 { c.translate(W * 0.45, gy * 0.88); c.scale(g.zoom, g.zoom); c.translate(-W * 0.45, -gy * 0.88) }
        sky(dk, dusk)
        mesas(dk, dusk)
        groundBand(dk)
        tufts()
        scenery()
        landmarks()
        sites(dk)
        camps(dk)
        towers()
        yard(dk)
        for tx in g.troughs where vis(tx, 12) && (tx < g.river.0 - 2 || tx > g.river.1 + 2 || g.bio == .river) {
            let x = sx(tx).rounded()
            if tx > g.river.0 - 2 && tx < g.river.1 + 2 { continue }
            c.R(x - 6, gy - 5, 12, 5, Col(0x6a4a2e)); c.R(x - 5, gy - 5, 10, 1.4, Col(0x8fc4d4)); c.R(x - 6, gy - 2, 1.4, 2, Col(0x4a3424)); c.R(x + 4.6, gy - 2, 1.4, 2, Col(0x4a3424))
        }
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
        if g.lastTown { craneYard() }
        if (g.rallyBlock.isEmpty && !g.rallyOn) || (g.rallyOn && g.routT < 0) {
            // point the way: the east gate first, then Crane's yard; an arrow at the screen edge when it is off to the right
            let gx = sx(g.rallyOn ? g.craneX - 10 : g.gateE.x + 7), bob = sin(g.clock * 4) * 2
            let ax = min(gx, W - 14), ay = gy - 34 + bob
            c.glow(ax, ay, 12, Col(0xffd27a, 0.35), Col(0xffd27a, 0))
            if gx > W - 14 { c.poly(Col(0xf2c14e), [ax - 6, ay - 5, ax + 4, ay, ax - 6, ay + 5]) } else { c.poly(Col(0xf2c14e), [ax - 5, ay - 6, ax + 5, ay - 6, ax, ay + 3]) }
            c.text(g.rallyOn ? "CRANE\u{2019}S YARD" : "EAST GATE", ax - (gx > W - 14 ? 26 : 0), ay - 9, 4.4, Col(0xf2c14e), face: "Rye-Regular")
        }
        for bx in g.boxes { box(bx) }
        coach()
        for w in g.strays { cowAt(w.x, w.dir, 1, w.seed, w.phase, horns: true) }
        gunmen()
        for m in g.mustangs {
            let coats: [(UInt32, UInt32)] = [(0x9a5a34, 0x4a2a18), (0xc9a36a, 0x8a6a40), (0x8a8480, 0x4a4642), (0x3a3230, 0x1c1816)]
            let ct = coats[Int(m.seed) % 4]
            if vis(m.x, 30) && m.st < 2 && m.rope > 0 {
                // the loop closing as you keep pace
                c.ellStroke(sx(m.x), gy - 36, 4.5, 4.5, 0.6, Col(0xc9a468, 0.4))
                c.arcStroke(sx(m.x), gy - 36, 4.5, -PI / 2, -PI / 2 + 2 * PI * min(1, m.rope / 0.8), 1.4, Col(0xf2c14e))
            }
            if vis(m.x, 30) { _ = horse(sx(m.x), m.dir, m.phase, m.speed, Col(ct.0), Col(ct.1)); if m.st == 2 { c.seg(sx(m.x) + m.dir * 14, gy - 22, sx(g.px), gy - 22, 0.5, Col(0xc9a468)) } }
        }
        for tr in g.cav where vis(tr.x, 30) {
            let x = sx(tr.x)
            _ = horse(x, tr.dir, tr.phase, 118, Col(0x6e4a30), Col(0x3a2416))
            c.save(); c.translate(0, -HLIFT); defer { c.restore() }
            c.R(x - 3, gy - 26, 6, 9, Col(0x2f4a7a)); c.R(x - 3, gy - 22, 6, 1.2, Col(0xf2c14e)); c.R(x - 1, gy - 17, 3, 7, Col(0x8fa4c4))
            c.R(x - 2, gy - 30, 4.5, 4, Col(0xd9a878)); c.R(x - 4.5, gy - 31, 9.5, 1.3, Col(0x1c2a4a)); c.R(x - 2.5, gy - 33.6, 5.5, 3, Col(0x1c2a4a))
            c.seg(x + tr.dir * 2, gy - 24, x + tr.dir * 9, gy - 29, 1, Col(0xc9c9d0))
        }
        for f in g.folk where !f.hidden { person(f.x, f.phase, f.dir, f.moving, f.seed, f.role, f.work) }
        if g.rallyOn {
            for (i, f) in g.folk.enumerated() where i % 2 == 0 && vis(f.x, 20) {
                let tx = sx(f.x) + f.dir * 3, ty = gy - 22
                c.R(tx - 0.5, ty, 1.2, 7, Col(0x4a3424))
                c.glow(tx, ty - 2, 9, Col(0xffa040, 0.35), Col(0xffa040, 0))
                c.poly(Col(0xff9a2e), [tx - 2, ty, tx, ty - 5 - sin(g.clock * 17 + f.x) * 1.5, tx + 2, ty]); c.poly(Col(0xffe08a), [tx - 1, ty, tx, ty - 2.5, tx + 1, ty])
            }
        }
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
        drifting(dk)
        night(dk)
        skyThings()
        weather(dk)
        finish(dk, dusk)
        duelBars()
        slots()
        radar()
        // a vignette and a little grain over the whole picture
        c.glow(W / 2, H * 0.52, (W * W + H * H).squareRoot() * 0.56, Col(0x1a0e08, 0), Col(0x1a0e08, 0.4))
        let fr = Double(Int(g.clock * 24))
        for i in 0..<90 { c.R(hashN(Double(i) * 3.3 + fr) * W, hashN(Double(i) * 7.7 + fr * 1.3) * H, 1, 1, Col(i % 2 == 0 ? 0xffffff : 0x000000, 0.045)) }
        c.restore()
        if g.flash > 0 { c.R(0, 0, W, H, Col(0xfff0c0, g.flash * 0.5)) }
        if g.fade > 0 { c.R(0, 0, W, H, Col(0x000000, g.fade)) }
    }

    /// The picture for a story scene, as in the web game: a 200 by 112 closeup, redrawn every frame so it moves.
    private var cu: Canvas?
    func art(_ bt: Beat, _ t: Double) -> CGImage? {
        if cu == nil { cu = Canvas(w: 200, h: 112, scale: 4) }
        guard let a = cu else { return nil }
        a.save()
        a.alpha(1)
        func q(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: UInt32, _ al: Double = 1) { a.R(x.rounded(), y.rounded(), w, h, Col(c, al)) }
        func hs(_ i: Int) -> Double { return hashN(Double(i) * 1.37 + 0.11) }
        func star(_ cx: Double, _ cy: Double, _ r0: Double, _ r1: Double, _ rot: Double, _ c: UInt32) {
            var p: [Double] = []
            for i in 0..<10 {
                let an = rot + Double(i) * PI / 5
                let r = i % 2 == 1 ? r1 : r0
                p.append(cx + sin(an) * r); p.append(cy - cos(an) * r)
            }
            a.poly(Col(c), p)
        }
        func motes(_ n: Int, _ c: UInt32) {
            for i in 0..<n {
                let x = (hs(i + 3) * 240 + t * (6 + hs(i + 9) * 14)).truncatingRemainder(dividingBy: 240) - 20
                let y = hs(i + 5) * 112 + sin(t * 0.8 + Double(i)) * 4
                q(x, y, hs(i) > 0.7 ? 2 : 1, 1, c, 0.25 + 0.5 * hs(i + 7))
            }
        }
        /// The upper half of an ellipse.
        func hell(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: UInt32) {
            a.save(); a.translate(cx, cy); a.scale(1, ry / rx); a.dome(0, 0, rx, Col(c)); a.restore()
        }
        func puffs(_ n: Int, _ step: Double, _ rate: Double, _ al: Double, _ c: UInt32, _ at: (Double, Int) -> (Double, Double, Double)) {
            for i in 0..<n {
                let k = (t * rate + Double(i) * step).truncatingRemainder(dividingBy: 1)
                let p = at(k, i)
                a.circ(p.0, p.1, p.2, Col(c, al * (1 - k)))
            }
        }
        switch bt.art {
        case "eyes":
            // a face under a hat brim: the rider, Crane's hired gun, a hobo, or Crane himself
            let who = bt.who.isEmpty ? "rider" : bt.who
            let F: [UInt32]       // bg, bg2, hat, band, skin, shade, iris, brow
            switch who {
            case "gun": F = [0xb98a5a, 0xcaa070, 0x16131a, 0x5a5450, 0xc99266, 0x96663f, 0x6a5a3a, 0x120b08]
            case "hobo": F = [0x8a7a66, 0x9a8a74, 0x5a5a52, 0x4a4a44, 0xc8956a, 0x9a6a44, 0x6a7a6a, 0x8a8478]
            case "crane": F = [0x2a2430, 0x3a3040, 0x2a2c36, 0x7a6a3a, 0xe0b890, 0xb98e68, 0x8a9aa8, 0xd8d2c4]
            default: F = [0xd8a868, 0xe8c088, 0x3b2a1e, 0xb53a2e, 0xd9a06e, 0xb47a4c, 0x4a6a8a, 0x2e1a12]
            }
            let look = (sin(t * 0.6 + (who == "gun" ? 2 : 0)) * 3).rounded()
            let blink = (t + (who == "gun" ? 1.3 : 0)).truncatingRemainder(dividingBy: 4.4) < 0.13
            q(0, 0, 200, 112, F[0])
            for i in 0..<5 { q(0, 8 + Double(i) * 22 + sin(t * 0.3 + Double(i)) * 2, 200, 5, F[1]) }
            q(50, 31, 100, 81, F[4]); q(50, 31, 13, 81, F[5]); q(137, 31, 13, 81, F[5])
            if who == "crane" { hell(100, 22, 50, 26, F[2]); q(50, 18, 100, 6, F[3]); q(22, 24, 156, 7, F[2]) }
            else { q(46, -6, 108, 30, F[2]); q(46, 17, 108, 6, F[3]); q(4, 24, 192, 8, F[2]); q(0, 27, 200, 4, F[2]); q(14, 22, 172, 3, F[2]) }
            q(50, 32, 100, 10, 0x140a06, 0.5); q(50, 42, 100, 4, 0x140a06, 0.2)
            q(61, 43, 31, 4, F[7]); q(108, 43, 31, 4, F[7]); q(86, 45, 8, 3, F[7]); q(106, 45, 8, 3, F[7])
            for ex in [66.0, 110.0] {
                q(ex, 50, 24, 8, 0xf0e6d6); q(ex + 8 + look, 50, 9, 8, F[6]); q(ex + 11 + look, 52, 3, 4, 0x120b08); q(ex + 10 + look, 51, 2, 2, 0xffffff)
                q(ex, 50, 24, who == "rider" ? 2 : 3, F[5]); q(ex, 56, 24, 2, F[5])
                if blink { q(ex, 50, 24, 8, F[4]); q(ex, 54, 24, 1, F[7]) }
                q(ex - 5, 60, 3, 1, F[5]); q(ex + 26, 60, 3, 1, F[5])
            }
            q(95, 55, 10, 25, F[5]); q(92, 79, 16, 4, F[5]); q(97, 58, 3, 18, F[4])
            if who == "rider" {
                q(44, 87, 112, 25, 0xb53a2e); q(44, 87, 112, 3, 0x8f2c23)
                for i in 0..<9 { q(52 + Double(i) * 12, 94 + Double(i % 2) * 7, 3, 3, 0xead7a4) }
                q(96, 90, 8, 22, 0x9a3026)
            } else if who == "hobo" {
                q(50, 80, 100, 32, 0x8a8478)
                for i in 0..<40 { q(52 + hs(i + 20) * 94, 82 + hs(i + 21) * 28, 2, 3, i % 2 == 1 ? 0xa8a296 : 0x6a665c) }
                q(84, 90, 32, 3, 0x5a3a30); q(112, 90, 30, 4, 0x5a3a22); q(140, 86, 7, 8, 0x3a2a1e)
                puffs(4, 0.25, 0.3, 0.35, 0xd8d2dc) { k, i in (144 + sin(t + Double(i)) * 3, 84 - k * 40, 2 + k * 6) }
            } else if who == "gun" {
                q(72, 85, 56, 7, 0x16131a); q(66, 89, 10, 5, 0x16131a); q(124, 89, 10, 5, 0x16131a); q(84, 97, 32, 3, 0x7a4a34)
                for i in 0..<8 { q(118 + Double(i) * 1.6, 34 + Double(i) * 5, 3, 4, 0x8a3a30) }
                for i in 0..<26 { q(58 + hs(i + 40) * 84, 98 + hs(i + 60) * 12, 1, 1, F[5]) }
            } else {
                q(70, 85, 60, 7, 0xe8e2d2); q(64, 89, 10, 5, 0xe8e2d2); q(126, 89, 10, 5, 0xe8e2d2); q(86, 97, 28, 3, 0x8a5a44)
                q(118, 96, 36, 5, 0x6a4a2e); q(118, 96, 36, 1, 0x8a6240)
                q(154, 96, 4, 5, sin(t * 3) > 0 ? 0xff8a2a : 0xffcf6b)
                puffs(5, 0.2, 0.35, 0.4, 0xd8d2dc) { k, i in (158 + k * 18 + sin(t + Double(i)) * 3, 92 - k * 46, 3 + k * 7) }
                a.ellStroke(122, 54, 15, 15, 1.5, Col(0xc9a14a)); a.seg(136, 60, 150, 112, 1.5, Col(0xc9a14a))
            }
            motes(14, who == "crane" ? 0x8a809a : 0xfff3c4)
        case "star":
            // his father's star, in the ashes
            q(0, 0, 200, 112, 0xa8814e)
            for i in 0..<60 { q(hs(i + 1) * 200, hs(i + 2) * 112, 2 + hs(i + 3) * 5, 1 + hs(i) * 2, i % 3 != 0 ? 0x8f6c40 : 0xc09a62) }
            for i in 0..<9 { q(hs(i + 11) * 180, hs(i + 13) * 100, 10 + hs(i + 15) * 26, 4 + hs(i + 17) * 8, 0x1a1412, 0.5) }
            a.save(); a.translate(28, 20); a.rotate(0.5)
            q(-10, -6, 120, 11, 0x1c1614); q(-10, -6, 120, 2, 0x3a302a)
            for i in 0..<8 { q(Double(i) * 14, -3, 6, 2, sin(t * 2 + Double(i)) > 0.6 ? 0xff8a2a : 0x5a2a1a) }
            a.restore()
            a.ell(104, 66, 34, 10, Col(0x1e120a, 0.45))
            star(100, 56, 32, 13, 0.18, 0x5a5f68); star(100, 55, 29, 11.5, 0.18, 0xaeb4bd)
            a.save(); a.cg.clip(to: CGRect(x: 100, y: 0, width: 100, height: 112)); star(100, 55, 29, 11.5, 0.18, 0xd8dde4); a.restore()
            a.circ(100, 55, 7, Col(0x8a9098)); a.circ(100, 55, 5, Col(0xc4cad2))
            for i in 0..<5 { let an = 0.18 + Double(i) * PI * 0.4; a.circ(100 + sin(an) * 29, 55 - cos(an) * 29, 2.4, Col(0x8a9098)) }
            for i in 0..<16 { q(70 + hs(i + 70) * 60, 40 + hs(i + 80) * 30, 3, 1, 0x3c2818, 0.5) }
            let gk = max(0, sin(t * 1.7))
            q(113 - 9 * gk, 38, 18 * gk + 1, 1, 0xffffff, gk); q(113, 38 - 9 * gk, 1, 18 * gk + 1, 0xffffff, gk); q(112, 37, 3, 3, 0xffffff, gk)
            let hk = clampD((t - 1.1) / 1.2, 0, 1), hx = 200 - hk * 62
            q(hx, 70, 70, 34, 0x5a3a22); q(hx - 14, 74, 16, 7, 0x6a4429); q(hx - 18, 84, 20, 7, 0x6a4429); q(hx - 12, 94, 14, 7, 0x6a4429); q(hx, 70, 70, 3, 0x7a5434); q(hx + 40, 62, 40, 50, 0x2e241c)
            motes(12, 0xe8d8b0)
        case "brand":
            // the brand on a raider's horse
            let by = sin(t * 1.4) * 1.2
            q(0, 0, 200, 112, 0x7a4628)
            for i in 0..<7 { q(0, 6 + Double(i) * 17 + by, 200, 7, i % 2 == 1 ? 0x8a5432 : 0x6f3f24) }
            for i in 0..<70 { q(hs(i + 5) * 200, hs(i + 6) * 112 + by, 6 + hs(i) * 8, 1, 0x28140a, 0.25) }
            q(120, 0, 80, 34 + by, 0x8a2f26)
            for i in 0..<5 { q(120, 4 + Double(i) * 7 + by, 80, 2, i % 2 == 1 ? 0xead7a4 : 0x3f5fa0) }
            q(116, 0, 5, 36 + by, 0x3a2416); q(150, 30 + by, 10, 82, 0x4a2f1c); q(152, 30 + by, 2, 82, 0x6a4429); q(146, 70 + by, 18, 10, 0x8d8780)
            a.roundCaps(true)
            let rings: [(UInt32, Double, Double)] = [(0xb0764a, 9, 0), (0x2a1206, 6, 0), (0x140803, 3, 0.5)]
            for (c, w, o) in rings {
                a.ellStroke(74 + o, 62 + by + o, 27, 27, w, Col(c))
                a.arcStroke(74 + o, 62 + by + o, 13, 0.75, 5.55, w, Col(c))
            }
            a.roundCaps(false)
            puffs(4, 0.25, 0.3, 0.25, 0xe8e0d8) { k, i in (74 + sin(Double(i) * 2 + t) * 10, 36 - k * 30 + by, 3 + k * 5) }
        case "wire":
            // a telegram, typed out as you watch
            q(0, 0, 200, 112, 0x4a3020)
            for i in 0..<6 { q(0, Double(i) * 20, 200, 1, 0x3a2416) }
            for i in 0..<40 { q(hs(i + 2) * 200, hs(i + 4) * 112, 8 + hs(i) * 14, 1, 0x5a3c24, 0.5) }
            a.glow(170, 10, 120, Col(0xffd68c, 0.5), Col(0xffd68c, 0))
            a.save(); a.translate(100, 57); a.rotate(-0.025)
            q(-82, -28, 168, 62, 0x140a06, 0.4); q(-84, -31, 168, 62, 0xefe4c4); q(-84, -31, 168, 11, 0xd8c9a0); q(-84, -20, 168, 1, 0x8a7a5a)
            a.text(bt.from, -78, -22.6, 7, Col(0x4a3a2a), center: false, face: "Courier-Bold")
            var n = Int(t * 26)
            for (i, ln) in bt.lines.enumerated() {
                let shown = String(ln.prefix(max(0, n)))
                n -= ln.count + 5
                let y = -15 + Double(i) * 14
                a.text(shown, -76, y + 7.6, 9.5, Col(0x2a1c14), center: false, face: "Courier-Bold")
                if !shown.isEmpty && shown.count < ln.count && Int(t * 8) % 2 == 1 { q(-76 + Double(shown.count) * 5.7, y, 5, 8, 0x2a1c14) }
            }
            a.restore()
        case "map":
            // the rail line: towns you have rebuilt, where you are now, and what Crane still holds
            q(0, 0, 200, 112, 0xe2cf9c)
            for i in 0..<30 { q(hs(i + 1) * 200, hs(i + 2) * 112, 10 + hs(i + 3) * 30, 6 + hs(i) * 10, 0xa0783c, 0.12) }
            let n = STAGES.count, lap = g.town / n
            let all = bt.who == "all"
            let cur = all ? n : g.town % n
            let xs = [24.0, 62, 100, 138, 176], ys = [56.0, 50, 60, 48, 55]
            for i in 0..<4 {
                // a dashed line between stops
                let dx = xs[i + 1] - xs[i], dy = ys[i + 1] - ys[i], len = (dx * dx + dy * dy).squareRoot()
                var u = 0.0
                while u < len { let v = min(len, u + 5); a.seg(xs[i] + dx * u / len, ys[i] + dy * u / len, xs[i] + dx * v / len, ys[i] + dy * v / len, 2, Col(0x2a1c14)); u += 8 }
            }
            for i in 0..<n {
                let x = xs[i], y = ys[i], up = i % 2 == 1, done = i < cur
                var nm = STAGES[i].count > 1 ? "?" : (PLACES[STAGES[i][0]]?.name ?? "")
                let li = lap * n + i
                if done { nm = PLACES[li < g.log.count ? g.log[li] : STAGES[i][0]]?.name ?? nm } else if i == cur { nm = g.townName }
                if done { star(x, y, 7.5, 3.3, 0, 0x2a1c14); star(x, y, 5.8, 2.5, 0, 0xe8b830) } else { a.circ(x, y, 4, Col(0x2a1c14)) }
                if i == cur {
                    a.ellStroke(x, y, 8 + sin(t * 3.2), 8 + sin(t * 3.2), 1.6, Col(0xb0261c))
                    a.text("YOU ARE HERE", clampD(x, 42, 158), y + (up ? 13 : -13) + 2.1, 6, Col(0xb0261c))
                }
                a.text(nice(nm), clampD(x, 38, 162), y + (up ? -12 : 12) + 2.3, 6.5, Col(0x2a1c14))
            }
            star(36, 82, 4.6, 2, 0, 0x2a1c14); star(36, 82, 3.5, 1.5, 0, 0xe8b830)
            a.text("rebuilt", 43, 84.6, 6, Col(0x2a1c14), center: false)
            a.ellStroke(84, 82, 3.6, 3.6, 1.2, Col(0xb0261c)); a.text("you are here", 91, 84.6, 6, Col(0x2a1c14), center: false)
            a.circ(140, 82, 2.8, Col(0x2a1c14)); a.text("held by Crane", 146, 84.6, 6, Col(0x2a1c14), center: false)
        case "train":
            // Crane's private car, parked up the line at night
            q(0, 0, 200, 112, 0x12122a)
            for i in 0..<40 { q(hs(i + 1) * 200, hs(i + 2) * 30, 1, 1, 0xcfd6ff, 0.4 + 0.6 * abs(sin(t + Double(i)))) }
            q(0, 26, 200, 64, 0x1f3a2e); q(0, 26, 200, 3, 0x2f5444); q(0, 22, 200, 5, 0x16281f); q(0, 84, 200, 3, 0xc9a14a); q(0, 32, 200, 1, 0xc9a14a)
            for wx in [-34.0, 64, 162] {
                q(wx - 3, 35, 78, 40, 0x16281f); q(wx, 38, 72, 34, 0xffcf6b); q(wx, 38, 72, 5, 0x8a2f26); q(wx + 35, 38, 2, 34, 0x16281f)
                a.vfill(wx, 38, 72, 34, [(0, Col(0xfff0be, 0)), (1, Col(0xc87828, 0.45))])
            }
            hell(88, 52, 10, 6, 0x140c0a); q(74, 51, 28, 2, 0x140c0a); q(80, 53, 16, 13, 0x140c0a); q(70, 64, 36, 8, 0x140c0a); q(66, 68, 44, 4, 0x140c0a)
            q(96, 61, 12, 2, 0x3a2416)
            let ck = 0.5 + 0.5 * sin(t * 2.4)
            q(108, 60, 3, 3, ck > 0.5 ? 0xffb13b : 0xc0501e); a.circ(109, 61, 6, Col(0xff9a2e, 0.5 * ck))
            a.text("C R A N E", 74, 83.4, 9, Col(0xc9a14a), center: false)
            q(0, 90, 200, 6, 0x0c0c14)
            for x in [20.0, 70, 130, 180] { a.circ(x, 98, 11, Col(0x0a0a10)); a.circ(x, 98, 4, Col(0x2a2a36)) }
            q(0, 108, 200, 4, 0x3a3a46)
            for i in 0..<7 {
                let k = (t * 0.16 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
                a.circ(k * 240 - 20, 100 - sin(k * 3 + Double(i)) * 8, 9 + Double(i % 3) * 4, Col(0xb8b8cc, 0.3 * sin(k * PI)))
            }
        case "hand":
            // a hand over a holster
            q(0, 0, 200, 112, 0xd2ac74)
            for i in 0..<6 { q(0, 10 + Double(i) * 19, 200, 6, i % 2 == 1 ? 0xc49a62 : 0xdab888) }
            q(0, 86, 200, 26, 0xb98f58)
            q(0, 0, 92, 112, 0x2e241c); q(84, 0, 10, 112, 0x3d3026); q(0, 0, 92, 3, 0x3d3026); q(0, 38, 128, 9, 0x5a3a22); q(0, 38, 128, 2, 0x7a5434)
            for i in 0..<8 { q(6 + Double(i) * 11, 34, 5, 8, 0xc9a14a); q(6 + Double(i) * 11, 34, 5, 2, 0xead7a4) }
            q(58, 47, 40, 58, 0x6a4429); q(58, 47, 40, 3, 0x8a6240); q(62, 100, 32, 8, 0x5a3a22); q(58, 47, 4, 58, 0x4a2f1c)
            for i in 0..<5 { q(66 + Double(i) * 6, 54, 2, 2, 0xc9a14a) }
            q(66, 26, 20, 24, 0x3a2a1e); q(66, 26, 20, 3, 0x5a4636); q(70, 20, 8, 8, 0x6a6a72); q(84, 30, 6, 6, 0x8a8f98)
            let tw = sin(t * 7) > 0.86 ? 2.0 : 0, hy = 40 + (sin(t * 1.1) * 1.5).rounded()
            q(118, hy, 36, 24, 0xd9a06e); q(118, hy, 36, 3, 0xe8b888); q(150, hy - 10, 50, 30, 0x2e241c); q(146, hy - 4, 8, 26, 0xead7a4)
            for i in 0..<4 { q(104 - Double(i) * 2 + (i == 1 ? -tw : 0), hy + 2 + Double(i) * 6, 16 + Double(i) * 2, 5, i % 2 == 1 ? 0xc99266 : 0xd9a06e) }
            q(112, hy - 7 + tw, 8, 9, 0xd9a06e)
            q(100, hy + 26, 60, 5, 0x140a06, 0.25)
            motes(10, 0xfff3c4)
        case "saucer":
            // what came down over the pasture
            q(0, 0, 200, 112, 0x0e1030)
            let band: [UInt32] = [0x141640, 0x1a1c4a, 0x202456, 0x262a5e, 0x2c3066]
            for i in 0..<5 { q(0, 60 + Double(i) * 8, 200, 8, band[i]) }
            for i in 0..<60 { q(hs(i + 1) * 200, hs(i + 2) * 70, 1, 1, i % 5 != 0 ? 0xcfd6ff : 0xffffff, 0.35 + 0.65 * abs(sin(t * 1.3 + Double(i)))) }
            let sx0 = 100 + sin(t * 0.7) * 5, sy0 = 26 + sin(t * 1.9) * 2
            a.poly(Col(0x96ffc0, 0.4), [sx0 - 12, sy0 + 6, sx0 + 12, sy0 + 6, sx0 + 44, 100, sx0 - 44, 100])
            for i in 0..<7 {
                let k = (t * 0.5 + Double(i) / 7).truncatingRemainder(dividingBy: 1), y = 100 - (94 - sy0) * k, w = 44 - 32 * k
                q(sx0 - w, y, w * 2, 2, 0xd6ffe4, 0.3 * (1 - k))
            }
            a.save(); a.translate(sx0 + sin(t * 1.1) * 3, 66 + sin(t * 0.8) * 5); a.rotate(sin(t * 0.9) * 0.35)
            q(-13, -7, 26, 13, 0x101a16); q(11, -11, 9, 9, 0x101a16); q(18, -13, 2, 3, 0x101a16); q(-15, -6, 3, 2, 0x101a16)
            for lx in [-11.0, -6, 5, 10] { q(lx, 5, 3, 10 + sin(t * 4 + lx) * 2, 0x101a16) }
            q(-17, -5, 2, 9, 0x101a16); q(-5, -7, 7, 5, 0x2a3a34)
            a.restore()
            hell(sx0, sy0 - 5, 17, 14, 0xbfe8ff); q(sx0 - 10, sy0 - 14, 5, 3, 0xe8f8ff)
            a.ell(sx0, sy0 + 2, 50, 11, Col(0x565f74)); a.ell(sx0, sy0 - 1, 50, 8, Col(0x8a94a8)); q(sx0 - 36, sy0 - 5, 72, 2, 0xc8d0e0)
            a.ell(sx0, sy0 + 8, 16, 4, Col(0x2a3244))
            let lamp: [UInt32] = [0xff5a3c, 0xffd76a, 0x8cf7b0, 0x6fe3ea]
            for i in 0..<9 { let an = t * 3 + Double(i) * 0.7; if sin(an) > -0.3 { q(sx0 + cos(an) * 44 - 2, sy0 + 1 + sin(an) * 3, 4, 3, lamp[i % 4]) } }
            q(0, 100, 200, 12, 0x0a0c1c)
            for i in 0..<9 { q(8 + Double(i) * 24, 92, 2, 9, 0x0a0c1c) }
            q(0, 95, 200, 1, 0x0a0c1c); q(0, 98, 200, 1, 0x0a0c1c)
            q(22, 82, 10, 14, 0x0a0c1c); q(24, 76, 6, 6, 0x0a0c1c); q(19, 75, 16, 2, 0x0a0c1c); q(23, 72, 8, 3, 0x0a0c1c); q(8, 88, 16, 8, 0x0a0c1c); q(4, 84, 6, 6, 0x0a0c1c)
            a.ell(sx0, 101, 46, 5, Col(0x82ffb4, 0.25))
        case "storm":
            // the first big storm, coming in off the mesas
            let fl = max(0, sin(t * 1.7)) > 0.93 || t.truncatingRemainder(dividingBy: 3.1) < 0.12
            a.translate(0, -14)
            q(0, 112, 200, 14, fl ? 0x34364a : 0x06060c)
            q(0, 0, 200, 112, fl ? 0x5a6088 : 0x1c2038)
            let lit: [UInt32] = [0x6a709a, 0x7a80a8, 0x8a90b4, 0x9aa0c0, 0xa8aecb, 0xb4bad4], dim: [UInt32] = [0x22284a, 0x2a3056, 0x343a62, 0x40466c, 0x4c5276, 0x585e80]
            for i in 0..<6 { q(0, 40 + Double(i) * 9, 200, 9, fl ? lit[i] : dim[i]) }
            let cloud: UInt32 = fl ? 0x3a4060 : 0x0c0e1c
            for i in 0..<16 { a.circ(Double(i) * 14 - 4 + sin(t * 0.2 + Double(i)) * 2, 18 + hs(i + 3) * 10, 16 + hs(i + 5) * 10, Col(cloud)) }
            q(0, 0, 200, 20, cloud)
            if fl {
                var x = 128.0, y = 30.0
                let seed = Int(t * 2)
                for i in 0..<7 {
                    let nx = x + (hs(i + seed) - 0.5) * 22, ny = y + 9
                    a.seg(x, y, nx, ny, 2, Col(0xffffff))
                    if i == 3 { a.seg(nx, ny, nx - 18, ny + 14, 2, Col(0xffffff)) }
                    x = nx; y = ny
                }
                a.circ(128, 30, 26, Col(0xdce6ff, 0.5))
            }
            a.poly(Col(fl ? 0x2a2c40 : 0x0a0a14), [0, 112, 0, 84, 20, 84, 24, 74, 58, 74, 62, 86, 96, 88, 100, 80, 124, 80, 128, 90, 160, 90, 164, 70, 190, 70, 194, 88, 200, 88, 200, 112])
            q(0, 100, 200, 12, fl ? 0x34364a : 0x06060c)
            let huts: [(Double, Double, Double)] = [(70, 14, 10), (86, 18, 14), (106, 12, 9), (120, 16, 12)]
            for (bx, bw, bh) in huts {
                q(bx, 100 - bh, bw, bh, fl ? 0x22243a : 0x040408); q(bx + 3, 100 - bh + 3, 3, 3, 0xffcf6b)
                if bw > 13 { q(bx + bw - 6, 100 - bh + 3, 3, 3, 0xffcf6b) }
            }
            for i in 0..<70 {
                let x = ((hs(i + 1) * 260 - t * 90 * (0.6 + hs(i + 2))).truncatingRemainder(dividingBy: 260) + 260).truncatingRemainder(dividingBy: 260) - 30
                let y = (hs(i + 3) * 112 + t * 260 * (0.7 + hs(i + 4) * 0.5)).truncatingRemainder(dividingBy: 112)
                a.seg(x, y, x - 3, y + 8, 1, Col(0xc8d6f0, 0.5))
            }
        case "vista":
            // riding in on a town for the first time: its country, the empty street, the name on the sign
            let bio = PLACES[bt.who]?.bio ?? .desert
            let lit = bt.from == "lit"
            var P: [UInt32]       // sky top, sky low, far, near, ground, street
            switch bio {
            case .river: P = [0x7fb6dc, 0xe8e2b8, 0x9fb08a, 0x6f9358, 0xa9a25e, 0x8c8446]
            case .canyon: P = [0xd88a5a, 0xf2c48a, 0xb5573a, 0x8a3a26, 0xc77a4a, 0xa05e36]
            case .pine: P = [0x8aa6b0, 0xd0d8c8, 0x5f7f6a, 0x2f5238, 0x7a7448, 0x5c5632]
            case .snow: P = [0x9ab4d0, 0xeef2f8, 0xb6c4d6, 0x8494ac, 0xe8eef6, 0xc4d0de]
            default: P = [0x6fa8d8, 0xf4dca8, 0xd9a47a, 0xc47a4a, 0xdcb680, 0xc09a62]
            }
            if lit { P[0] = 0x2a2850; P[1] = 0xe8794a }
            a.translate(0, -12)       // the frame shows the middle of the picture; bring the street and the rider up into it
            q(0, -12, 200, 14, P[0])
            for i in 0..<8 { a.R(0, Double(i) * 10, 200, 10, Col.mix(Col(P[0]), Col(P[1]), Double(i) / 7)) }
            a.circ(150, lit ? 74 : 40, 16, Col(0xfff2c0, 0.25)); a.circ(150, lit ? 74 : 40, 9, Col(lit ? 0xffb060 : 0xfff2c0))
            for i in 0..<3 { let cx = (hs(i + 2) * 240 + t * (2 + Double(i))).truncatingRemainder(dividingBy: 240) - 20; q(cx, 24 + Double(i) * 7, 26, 3, 0xffffff, 0.5); q(cx + 5, 22 + Double(i) * 7, 14, 2, 0xffffff, 0.5) }
            // the far country
            if bio == .snow {
                for i in 0..<6 {
                    let mx = Double(i) * 38 - 6 + hs(i) * 10, mh = 26 + hs(i + 3) * 16
                    a.poly(Col(P[2]), [mx - 26, 80, mx, 80 - mh, mx + 26, 80]); a.poly(Col(P[3], 0.6), [mx, 80 - mh, mx + 26, 80, mx + 6, 80])
                    a.poly(Col(0xffffff), [mx - 7, 80 - mh * 0.72, mx, 80 - mh, mx + 7, 80 - mh * 0.72, mx + 3, 80 - mh * 0.64, mx, 80 - mh * 0.74, mx - 3, 80 - mh * 0.62])
                }
            } else if bio == .pine {
                a.poly(Col(P[2]), [0, 80, 0, 62, 30, 56, 70, 64, 110, 54, 150, 62, 200, 56, 200, 80])
                for i in 0..<22 {
                    let px = Double(i) * 9.4 + hs(i) * 4, ph = 12 + hs(i + 6) * 10
                    if px > 78 && px < 122 { continue }
                    a.poly(Col(P[3]), [px - 4, 80, px, 80 - ph, px + 4, 80]); a.poly(Col(P[3]), [px - 3, 80 - ph * 0.4, px, 80 - ph - 3, px + 3, 80 - ph * 0.4])
                }
            } else if bio == .canyon {
                a.poly(Col(P[2]), [0, 80, 0, 50, 200, 50, 200, 80])
                a.poly(Col(P[3]), [0, 86, 0, 14, 34, 14, 46, 30, 52, 60, 70, 80]); a.poly(Col(P[3]), [200, 86, 200, 18, 170, 18, 158, 34, 150, 62, 132, 80])
                for i in 0..<6 { q(0, 22 + Double(i) * 10, 44 - Double(i) * 1, 1, 0x6a2a1c, 0.5); q(160 + Double(i) * 1, 26 + Double(i) * 10, 40, 1, 0x6a2a1c, 0.5) }
            } else if bio == .river {
                hell(40, 80, 60, 22, P[2]); hell(130, 80, 80, 26, P[2]); hell(190, 80, 40, 16, P[3])
                for i in 0..<7 { let tx = 8 + Double(i) * 30 + hs(i) * 8; if tx > 80 && tx < 120 { continue }; q(tx, 72, 1.5, 8, 0x4a3424); a.circ(tx + 0.7, 69, 5, Col(P[3])) }
                a.poly(Col(0x7fb0c4), [0, 96, 0, 88, 40, 84, 78, 82, 78, 84, 44, 90, 0, 104]); q(6, 92, 14, 1, 0xd8ecf4, 0.7 * (0.5 + 0.5 * sin(t * 2))); q(30, 87, 10, 1, 0xd8ecf4, 0.6)
            } else {
                a.poly(Col(P[2]), [0, 80, 0, 60, 26, 60, 32, 52, 66, 52, 72, 64, 112, 64, 118, 56, 150, 56, 156, 66, 200, 66, 200, 80])
                a.poly(Col(P[3]), [150, 80, 156, 48, 162, 44, 192, 44, 200, 54, 200, 80])
                for cx in [14.0, 60, 176] { q(cx, 70, 2, 10, 0x55783c); q(cx - 3, 73, 3, 1.5, 0x55783c); q(cx - 3, 71, 1.5, 3, 0x55783c); q(cx + 2, 75, 3, 1.5, 0x55783c); q(cx + 3.5, 72, 1.5, 4, 0x55783c) }
            }
            // the ground, and the street running in to the town
            q(0, 80, 200, 32, P[4])
            a.poly(Col(P[5]), [88, 80, 112, 80, 150, 112, 50, 112])
            for i in 0..<10 { q(hs(i + 11) * 200, 84 + hs(i + 13) * 24, 3, 1, P[5], 0.6) }
            // the town itself: false fronts down both sides, dark and boarded, or lit at the last
            let shack: UInt32 = bio == .snow ? 0x4a4a58 : 0x3a2e28
            let fronts: [(Double, Double, Double)] = [(44, 12, 13), (57, 14, 18), (72, 15, 14), (113, 15, 16), (129, 13, 20), (143, 14, 12)]
            for (bx, bw, bh) in fronts {
                q(bx, 81 - bh, bw, bh, shack); q(bx - 1, 81 - bh - 3, bw + 2, 3, shack); q(bx, 81 - bh * 0.45, bw, 1, 0x000000, 0.3)
                if lit { q(bx + 2, 81 - bh + 4, 3, 3, 0xffcf6b); q(bx + bw - 5, 81 - bh + 4, 3, 3, 0xffcf6b); a.circ(bx + bw / 2, 81 - bh + 5, 9, Col(0xffb85a, 0.14)) }
                else { q(bx + 2, 81 - bh + 4, 3, 3, 0x14100e); q(bx + 1.5, 81 - bh + 5, 4, 1, 0x6a5a48) }
                if bio == .snow { q(bx - 1, 81 - bh - 4, bw + 2, 1.5, 0xffffff) }
            }
            // the rider coming up the street
            let rb = sin(t * 6) * 0.6
            a.save(); a.translate(0, -9)
            q(88, 104.5, 24, 2, 0x000000, 0.2)
            q(95, 96 + rb, 11, 5, 0x1c1410); q(104, 93 + rb, 4, 4, 0x1c1410); q(95.5, 100, 1.5, 5, 0x1c1410); q(99, 100, 1.5, 5 - rb, 0x1c1410); q(103, 100, 1.5, 5, 0x1c1410)
            q(98, 89 + rb, 4, 7, 0x2a2430); q(96.5, 87.6 + rb, 7, 1.2, 0x14100e); q(98, 85.6 + rb, 4, 2.2, 0x14100e); q(94, 97 + rb, 1.5, 4, 0x1c1410)
            a.restore()
            // the sign by the road, with the company's board nailed under it until the town is won
            a.save(); a.translate(160, 44); a.rotate(sin(t * 1.1) * 0.012)
            q(-2, 0, 3, 56, 0x4a3424); q(-31, 0, 60, 15, 0x3a2a1c); q(-30, 1, 58, 13, 0x8a6a44); q(-30, 1, 58, 1, 0xa8885c)
            a.text(nice(PLACES[bt.who]?.name ?? ""), -1, 11.4, 9, Col(0x2a1c14), face: "Rye-Regular", fit: 52)
            if !lit && bt.who != "dustfall" { q(-22, 17, 42, 8, 0x6a231c); a.text("CRANE C. & R.", -1, 23.2, 5, Col(0xead7a4), fit: 38) }
            a.restore()
            motes(bio == .snow ? 34 : 12, bio == .snow ? 0xffffff : 0xfff3c4)
        case "runout":
            // dusk on the road east of town: Crane's men riding off into the sun, you after them, the town behind you with torches
            a.translate(0, -12)
            for i in 0..<11 { a.R(0, Double(i) * 9 - 12, 200, 9, Col.mix(Col(0x2a1a38), Col(0xe8743a), Double(i) / 10)) }
            a.circ(168, 82, 32, Col(0xffb060, 0.14)); a.circ(168, 84, 14, Col(0xffa860))
            a.poly(Col(0x6a2c2a), [0, 90, 0, 72, 40, 66, 90, 74, 140, 64, 200, 70, 200, 90])
            q(0, 88, 200, 30, 0x5a3424); q(0, 88, 200, 1, 0x8a5a3a)
            func rider(_ x: Double, _ y: Double, _ k: Double, _ col: UInt32, _ dir: Double) {
                let gl = sin(t * 14 + x) * 1.4 * k
                q(x - 5 * k, y - 6 * k, 10 * k, 3.4 * k, col); q(x + dir * 4 * k - 1.5 * k, y - 8.5 * k, 3 * k, 3 * k, col)
                for (lx, ph) in [(-4.0, 1.0), (-2.0, -1.0), (2.0, 1.0), (4.0, -1.0)] { q(x + lx * k + gl * ph, y - 2.8 * k, 0.9 * k, 2.8 * k, col) }
                q(x - 1 * k, y - 11 * k, 2.2 * k, 5 * k, col); a.circ(x + 0.1 * k, y - 12 * k, 1.3 * k, Col(col)); q(x - 2.2 * k, y - 13.4 * k, 4.6 * k, 0.8 * k, col)
            }
            // Crane's men, small against the sun, dust behind them
            for i in 0..<3 {
                let rx = 150 + Double(i) * 11 + sin(t * 0.7) * 2, ry = 88 - Double(i % 2) * 0.5
                rider(rx, ry, 0.75, 0x1c1210, 1)
                for k in 0..<3 { a.circ(rx - 7 - Double(k) * 3, ry - 1.5, 1.2 + Double(k) * 0.5, Col(0xc89a6a, 0.35 - Double(k) * 0.1)) }
            }
            // you, out in front
            rider(104, 100, 1.15, 0x120a08, 1)
            // the town on foot behind you, lit by its own torches
            for i in 0..<18 {
                let bx = 4 + Double(i) * 4.8 + hs(i) * 2, h = 9 + hs(i + 9) * 3.5, by = 100 + hs(i + 3) * 2 - 1
                let bob = abs(sin(t * 8 + Double(i) * 1.7)) * 0.9
                q(bx, by - h + bob, 2.6, h - 2.6, 0x140c0a)
                q(bx + 0.2, by - 2.6, 0.9, 2.6, 0x140c0a); q(bx + 1.5, by - 2.6, 0.9, 2.6, 0x140c0a)
                a.circ(bx + 1.3, by - h - 0.6 + bob, 1.5, Col(0x140c0a))
                if i % 4 == 0 { q(bx - 0.6, by - h - 1.6 + bob, 3.8, 0.7, 0x140c0a) }
                if i % 2 == 0 {
                    let tx = bx + 2.6, ty = by - h - 3 + bob
                    q(tx, ty, 0.7, 5, 0x3a2414)
                    a.circ(tx + 0.3, ty - 1, 6, Col(0xffa040, 0.14))
                    a.poly(Col(0xff8a2a), [tx - 1.2, ty, tx + 0.3, ty - 3.6 - sin(t * 17 + Double(i)) * 1, tx + 1.8, ty]); a.poly(Col(0xffe08a), [tx - 0.4, ty, tx + 0.3, ty - 1.6, tx + 1, ty])
                } else if i % 4 == 1 {
                    q(bx + 2.4, by - h - 5 + bob, 0.6, 7, 0x3a2414); q(bx + 1.4, by - h - 5.6 + bob, 2.6, 0.6, 0x3a2414)
                    for k in 0..<3 { q(bx + 1.4 + Double(k) * 1, by - h - 7.6 + bob, 0.5, 2, 0x3a2414) }
                }
            }
            for k in 0..<10 { let u = (t * 0.6 + Double(k) * 0.1).truncatingRemainder(dividingBy: 1); q(6 + hs(k) * 90, 92 - u * 50, 0.8, 0.8, 0xffc070, 1 - u) }
        case "shut":
            // a bigger town down the line, dark at dusk, with the company's chain across the road
            let snow = (PLACES[bt.who]?.bio ?? .desert) == .snow
            let sil: UInt32 = snow ? 0x2a2c3c : 0x1c1210
            a.translate(0, -12)
            for i in 0..<11 { a.R(0, Double(i) * 9 - 12, 200, 9, Col.mix(Col(0x1a1838), Col(snow ? 0x8a9ac0 : 0xd8623a), Double(i) / 10)) }
            a.circ(100, 78, 30, Col(0xffb060, 0.16)); a.circ(100, 80, 13, Col(snow ? 0xdfe8f8 : 0xff9a50))
            a.poly(Col(snow ? 0x5a6a8a : 0x6a2c2a), [0, 82, 0, 62, 30, 54, 60, 64, 96, 50, 130, 62, 170, 52, 200, 60, 200, 82])
            let big: [(Double, Double, Double)] = [(1, 18, 18), (21, 22, 27), (45, 16, 20), (63, 24, 31), (89, 17, 22), (108, 19, 26), (129, 26, 33), (157, 18, 21), (177, 22, 28)]
            for (i, f) in big.enumerated() {
                let (bx, bw, bh) = f
                q(bx, 82 - bh, bw, bh, sil); q(bx - 1, 82 - bh - 2, bw + 2, 2, sil)
                if i % 3 == 0 { a.poly(Col(sil), [bx - 1, 82 - bh - 2, bx + bw / 2, 82 - bh - 9, bx + bw + 1, 82 - bh - 2]) } else { q(bx + bw * 0.2, 82 - bh - 5, bw * 0.6, 3, sil) }
                q(bx - 1.5, 71, bw + 3, 1.6, 0x0c0808); q(bx + 1, 72, 1, 10, 0x0c0808); q(bx + bw - 2, 72, 1, 10, 0x0c0808)
                var wy = 82 - bh + 5
                while wy < 68 { for wx in [bx + 3, bx + bw - 6] { q(wx, wy, 3, 4, 0x0c0808); q(wx - 0.5, wy + 1.5, 4, 1, 0x6a5a48, 0.8) }; wy += 9 }
                if snow { q(bx - 1, 82 - bh - 4, bw + 2, 1.5, 0xffffff, 0.9) }
                if i == 3 || i == 6 { q(bx + bw / 2 - 1.5, 82 - bh + 5, 3, 4, 0xffcf6b, 0.3 + 0.25 * sin(t * 3 + Double(i))) }
            }
            a.poly(Col(sil), [138, 50, 142, 30, 146, 50]); q(141.6, 24, 0.9, 7, sil); q(140, 26, 4, 0.9, sil)
            q(91, 38, 12, 9, sil); q(93, 47, 1.2, 14, sil); q(99.8, 47, 1.2, 14, sil); a.poly(Col(sil), [90, 38, 97, 33, 104, 38])
            q(0, 80, 200, 32, snow ? 0xc4d0de : 0x6a4030); a.poly(Col(snow ? 0xaab6c8 : 0x54301f), [88, 80, 112, 80, 150, 112, 50, 112])
            for i in 0..<4 { let cx = (hs(i + 4) * 220 + t * (5 + Double(i) * 2)).truncatingRemainder(dividingBy: 220) - 10; q(cx, 40 + hs(i) * 14 + sin(t * 4 + Double(i)) * 1.5, 3, 1, 0x0c0808); q(cx + 1, 39 + hs(i) * 14, 1, 1, 0x0c0808) }
            // the gate: two posts, a sagging chain, the board and its padlock
            q(50, 64, 4, 38, 0x2a1c14); q(146, 64, 4, 38, 0x2a1c14); q(49, 63, 6, 2, 0x4a3424); q(145, 63, 6, 2, 0x4a3424)
            let sway = sin(t * 1.3) * 0.8
            for i in 0..<24 { let u = Double(i) / 23; q(54 + u * 92, 70 + sin(u * Double.pi) * (9 + sway), 3, 1.6, i % 2 == 0 ? 0x9a9aa4 : 0x5a5a64) }
            a.save(); a.translate(100, 80 + sway); a.rotate(sin(t * 1.3) * 0.03)
            q(-30, 0, 60, 19, 0x2a1c14); q(-29, 1, 58, 17, 0x7a241c); q(-29, 1, 58, 1, 0xa8483a)
            a.text("CLOSED", 0, 10.4, 9, Col(0xead7a4), face: "Rye-Regular", fit: 52)
            a.text("CRANE CATTLE & RAIL", 0, 16, 3.6, Col(0xead7a4), fit: 50)
            q(-3, -5, 6, 5, 0xd8b860); q(-2, -8, 4, 3, 0x000000, 0); a.ellStroke(0, -5.4, 2, 2.4, 0.9, Col(0xb8b8c0))
            a.restore()
            motes(snow ? 34 : 14, snow ? 0xffffff : 0xffc890)
        case "poster":
            // a wanted poster nailed to the boards
            q(0, 0, 200, 112, 0x4a3426)
            for i in 0..<10 { q(Double(i) * 22, 0, 1, 112, 0x3a2a1e) }
            a.save(); a.translate(100, 58); a.rotate(sin(t * 0.7) * 0.012 - 0.02); a.scale(0.78, 0.78)
            q(-43, -38, 90, 80, 0x000000, 0.25)
            q(-44, -40, 88, 80, 0xe6d4a4); q(-44, -40, 88, 1, 0xf4e8c4); q(-44, 39, 88, 1, 0xb8a070)
            for i in 0..<12 { q(-44 + hs(i) * 74, -40 + hs(i + 4) * 74, 6 + hs(i + 2) * 8, 3, 0xc8b078, 0.35) }
            a.text("WANTED", 0, -26, 13, Col(0x2a1c14), face: "Rye-Regular")
            q(-17, -22, 34, 30, 0xcdb888); q(-17, -22, 34, 1, 0x2a1c14); q(-17, 7, 34, 1, 0x2a1c14); q(-17, -22, 1, 30, 0x2a1c14); q(16, -22, 1, 30, 0x2a1c14)
            q(-12, -14, 24, 3, 0x1c1410); q(-7, -20, 14, 7, 0x1c1410); q(-7, -15, 14, 1, 0x6a231c)
            q(-7, -11, 14, 13, 0xb8885a); q(-7, -11, 14, 2, 0x8a6240); q(5, -9, 2, 11, 0x9a7048)
            q(-5, -7, 3, 2, 0x1c1410); q(2, -7, 3, 2, 0x1c1410); q(-5, -8, 3, 1, 0x3a2a1c); q(2, -8, 3, 1, 0x3a2a1c)
            q(-6, -2, 12, 2, 0x2a1c14); q(-7, 0, 2, 2, 0x2a1c14); q(5, 0, 2, 2, 0x2a1c14)
            a.seg(3, -10, 6, -3, 0.8, Col(0x7a3a2a))
            q(-10, 2, 20, 5, 0x3a2e28); q(-2, 2, 4, 3, 0xa02a22)
            a.text("VARNEY", 0, 18, 8, Col(0x2a1c14), face: "Rye-Regular")
            a.text("ROBBERY AND ARSON", 0, 25, 4.4, Col(0x2a1c14))
            a.text("$500 REWARD", 0, 35, 7, Col(0x8a2b22), face: "Rye-Regular")
            q(-1.5, -38, 3, 3, 0x6a6a72); q(-1, -37.5, 1, 1, 0xc9c9d0)
            a.restore()
            motes(8, 0xfff3c4)
        default:
            // the star, pinned on
            q(0, 0, 200, 112, 0x4a3426)
            for i in 0..<10 { q(Double(i) * 22, 0, 1, 112, 0x3a2a1e) }
            q(120, 0, 80, 112, 0xb53a2e); q(118, 0, 4, 112, 0x2e1a12)
            for i in 0..<6 { q(108, 10 + Double(i) * 18, 5, 5, 0xc9a14a) }
            a.save(); a.translate(72, 56)
            for i in 0..<12 { a.rotate(PI / 6); a.poly(Col(0xffe9a8, 0.1 + 0.1 * sin(t * 2 + Double(i))), [0, 0, -7, -70, 7, -70]) }
            a.restore()
            let rot = sin(t * 0.5) * 0.04
            star(72, 57, 34, 14, rot, 0x6a5a20); star(72, 56, 31, 12.5, rot, 0xe8c84a)
            a.save(); a.cg.clip(to: CGRect(x: 72, y: 0, width: 128, height: 112)); star(72, 56, 31, 12.5, rot, 0xfff0a8); a.restore()
            a.circ(72, 56, 8, Col(0xc9a14a)); a.circ(72, 56, 5.5, Col(0xfff0a8))
            let gk = max(0, sin(t * 2.1))
            q(88 - 11 * gk, 36, 22 * gk + 1, 1, 0xffffff, gk); q(88, 36 - 11 * gk, 1, 22 * gk + 1, 0xffffff, gk)
            motes(10, 0xfff3c4)
        }
        a.restore()
        return a.image()
    }

    private func sx(_ x: Double) -> Double { return x - g.cam }
    private func vis(_ x: Double, _ w: Double) -> Bool { let s = x - g.cam; return s > -w - 20 && s < W + 20 }

    // ---------- sky and land
    /// Grass along the street, wheel ruts down the middle of it, and a flock crossing the sky.
    private func tufts() {
        let L = g.terrain
        let snow = g.bio == .snow
        let blade = Col(snow ? 0xcfdbe8 : (g.bio == .river || g.bio == .pine ? 0x5f8a44 : L.scrub)), blade2 = Col.mix(blade, Col(0x000000), 0.25)
        var i = Int(((g.cam - 10) / 5).rounded(.down))
        while Double(i) * 5 < g.cam + W + 10 {
            let wx = Double(i) * 5 + hashN(Double(i) * 2.9) * 4
            let k = hashN(Double(i) * 5.1 + 0.7)
            i += 1
            if k < 0.42 { continue }
            if (g.bio == .river || g.flooded) && wx > g.river.0 - 3 && wx < g.river.1 + 3 { continue }
            let x = sx(wx)
            let inTown = wx > g.gateW.x && wx < g.gateE.x
            if inTown && k < 0.72 { continue }
            let hgt = (inTown ? 2 : 2.5) + k * 3
            let sway = sin(g.clock * 1.6 + wx * 0.13) * 0.7
            c.seg(x, gy + 0.4, x - 1 + sway, gy - hgt, 0.7, blade2); c.seg(x + 1, gy + 0.4, x + 1.4 + sway, gy - hgt * 1.2, 0.7, blade); c.seg(x + 2, gy + 0.4, x + 3.2 + sway, gy - hgt * 0.8, 0.7, blade2)
            if !snow && k > 0.93 { c.R(x + 0.8 + sway, gy - hgt * 1.2 - 1, 1.2, 1.2, Col(hashN(Double(i)) > 0.5 ? 0xf2d94e : 0xe8e2d2)) }
        }
        // ruts down main street
        let a = sx(g.gateW.x + 14), b2 = sx(g.gateE.x)
        if b2 > 0 && a < W {
            let l = max(0, a), r = min(W, b2)
            c.R(l, gy + 2.4, r - l, 0.7, Col(L.speck, 0.35)); c.R(l, gy + 4.2, r - l, 0.7, Col(L.speck, 0.28))
        }
        // a flock, by day and in fair weather
        if g.dark() < 0.3 && g.wx == 0 {
            let fx = (g.clock * 9).truncatingRemainder(dividingBy: W + 160) - 80 - g.cam * 0.02
            for j in 0..<6 {
                let bx = fx + Double(j % 3) * 9 - Double(j / 3) * 5, by = H * 0.2 + Double(j / 3) * 6 + Double(j % 3) * 3 + sin(g.clock * 0.7 + Double(j)) * 2
                let fl = sin(g.clock * 7 + Double(j) * 1.3) * 1.3
                let bc = Col(0x2e2226, 0.8)
                c.ell(bx, by, 1.5, 0.7, bc); c.R(bx + 1.2, by - 0.5, 1.1, 0.7, bc)
                c.seg(bx, by, bx - 1.6, by - fl * 1.1 - 0.6, 0.8, bc); c.seg(bx - 1.6, by - fl * 1.1 - 0.6, bx - 3.4, by - fl * 0.6, 0.6, bc)
                c.seg(bx, by, bx + 0.6, by - fl * 1.1 - 0.8, 0.8, bc); c.seg(bx + 0.6, by - fl * 1.1 - 0.8, bx - 0.6, by - fl * 0.7 - 1.6, 0.6, bc)
            }
        }
    }

    /// The shooting gallery from the counter: three rows of targets crossing a striped booth.
    private func galleryBooth(_ gl: Gallery) {
        // the room is wider than the screen; the view drifts across it and back
        let SW = W * GWIDE
        c.save(); c.translate(-g.galleryPan(gl.t), 0)
        c.vfill(0, 0, SW, H, [(0, Col(0x3a1a18)), (1, Col(0x1c0c0c))])
        var sx3 = 0.0, si = 0
        while sx3 < SW { c.R(sx3, 0, 14, H, Col(si % 2 == 0 ? 0x5a2420 : 0x4a1c1a, 0.9)); sx3 += 14; si += 1 }
        c.vfill(0, 0, SW, H * 0.75, [(0, Col(0x000000, 0.45)), (1, Col(0x000000, 0))])
        // a saloon, and everything in it answers when it is hit
        let fy = H * 0.74, t = gl.t
        func first(_ k: Int) -> GTarget? { return gl.targets.first { $0.kind == k } }
        func spot(_ tg: GTarget, _ dx: Double = 0) {
            if tg.hit >= 0 { return }
            let x = tg.x * W + dx, y = tg.y * H
            c.circ(x, y, 2.6, Col(0xffffff, 0.9)); c.circ(x, y, 1.7, Col(0xd0392b)); c.circ(x, y, 0.7, Col(0xffffff))
        }
        c.R(0, fy, SW, H * 0.8 - fy + 2, Col(0x5a3c22)); c.R(0, fy, SW, 1, Col(0x8a6238)); c.R(0, fy - 5, SW, 5, Col(0x3a2420))
        var fb = 0.0
        while fb < SW { c.R(fb, fy + 1, 0.8, 14, Col(0x3a2a1c, 0.6)); fb += 18 }
        // the back bar: a mirror, a shelf of bottles, the counter with its bell
        c.R(W * 0.04, H * 0.2, W * 0.24, H * 0.215, Col(0x3a2a1c)); c.R(W * 0.05, H * 0.215, W * 0.22, H * 0.12, Col(0x9fb8c4, 0.55))
        c.poly(Col(0xffffff, 0.18), [W * 0.06, H * 0.215, W * 0.12, H * 0.215, W * 0.08, H * 0.335, W * 0.05, H * 0.335])
        c.R(W * 0.04, H * 0.41, W * 0.24, 2, Col(0x8a6238))
        for tg in gl.targets where tg.kind == 0 {
            let x = tg.x * W, by = H * 0.41
            if tg.hit < 0 {
                c.RR(x - 2.6, by - 10, 5.2, 10, 1.4, Col(0x4f8a5a)); c.R(x - 1.1, by - 15, 2.2, 5.4, Col(0x4f8a5a)); c.R(x - 1.4, by - 15.6, 2.8, 1.2, Col(0xd8b860))
                c.R(x - 2.6, by - 7, 5.2, 3.4, Col(0xf0e8d8)); c.R(x - 1.6, by - 9.4, 0.9, 7, Col(0xffffff, 0.4))
            } else {
                c.R(x - 2.6, by - 2.4, 5.2, 2.4, Col(0x4f8a5a)); c.poly(Col(0x4f8a5a), [x - 2.6, by - 2.4, x - 1, by - 5, x + 0.4, by - 2.4])
                if tg.hit < 0.7 { for j in 0..<7 { let an = Double(j) * 0.9, u = tg.hit / 0.7; c.R(x + cos(an) * u * 16, by - 8 - sin(an) * u * 12 + u * u * 14, 1.6, 1.6, Col(0x9fe0b0, 1 - u)) } }
            }
            spot(tg)
        }
        c.R(W * 0.02, H * 0.6, W * 0.31, fy - H * 0.6, Col(0x6a4a2e)); c.R(W * 0.015, H * 0.595, W * 0.32, 2.4, Col(0x9a7448))
        var bp = W * 0.04
        while bp < W * 0.31 { c.R(bp, H * 0.63, W * 0.05, fy - H * 0.63 - 3, Col(0x5a3c22)); bp += W * 0.065 }
        if let tg = first(9) {
            let x = tg.x * W, y = tg.y * H, sh = tg.hit >= 0 && tg.hit < 1.2 ? sin(tg.hit * 40) * 1.2 : 0
            c.dome(x + sh, y + 4, 3.6, Col(0xd8b860)); c.R(x + sh - 4.4, y + 4, 8.8, 1, Col(0x8a6a2a)); c.circ(x + sh, y - 0.2, 0.9, Col(0xfff0a8))
            if tg.hit >= 0 && tg.hit < 1.2 { for j in 0..<3 { c.arcStroke(x, y + 2, 6 + Double(j) * 3, -2.2, -0.9, 0.6, Col(0xfff0a8, 1 - tg.hit / 1.2)) } }
            spot(tg)
        }
        // a moose head on the wall: its eyes light up
        if let tg = first(6) {
            let x = tg.x * W, y = tg.y * H, on = tg.hit >= 0 && tg.hit < 2.5
            c.RR(x - 5, y + 4, 10, 4, 1.5, Col(0x4a3424))
            c.ell(x, y, 4.4, 5.4, Col(0x6a4a2e)); c.ell(x, y + 4.4, 3, 2.6, Col(0x5a3c22)); c.R(x - 1.6, y + 4.6, 1, 0.8, Col(0x1c120c)); c.R(x + 0.8, y + 4.6, 1, 0.8, Col(0x1c120c))
            for sd in [-1.0, 1.0] {
                c.curve(x + sd * 3, y - 4, x + sd * 9, y - 6, x + sd * 11, y - 12, 1.3, Col(0xe8dcc4)); c.seg(x + sd * 8, y - 6.4, x + sd * 8, y - 11, 1.1, Col(0xe8dcc4)); c.seg(x + sd * 10.4, y - 9, x + sd * 13.4, y - 10, 1.1, Col(0xe8dcc4))
                c.circ(x + sd * 2, y - 1, 1, on ? Col(0xff4a3a) : Col(0x1c120c))
                if on { c.glow(x + sd * 2, y - 1, 5, Col(0xff4a3a, 0.6), Col(0xff4a3a, 0)) }
            }
            if on { c.R(x - 2, y + 7, 4, 1.4 + sin(tg.hit * 12) * 1, Col(0x1c120c)) }
            spot(tg, 0)
        }
        // a brass spittoon: it rings and spins
        if let tg = first(4) {
            let x = tg.x * W, y = tg.y * H, k = tg.hit >= 0 && tg.hit < 1.5 ? cos(tg.hit * 14) * (1 - tg.hit / 1.5) : 1
            c.save(); c.translate(x, y + 4); c.scale(abs(k) < 0.15 ? 0.15 : k, 1)
            c.poly(Col(0xc9a14a), [-4.4, 0, -3, -6, 3, -6, 4.4, 0]); c.R(-4.6, -7.4, 9.2, 1.6, Col(0xe8c84a)); c.R(-2.4, -5, 1, 4, Col(0xfff0a8, 0.6))
            c.restore()
            spot(tg)
        }
        // the batwing doors, the night outside, and a pair of boots that dance
        c.R(W * 0.41, H * 0.34, W * 0.12, fy - H * 0.34, Col(0x141a30)); c.R(W * 0.405, H * 0.33, W * 0.13, 2, Col(0x3a2a1c)); c.R(W * 0.405, H * 0.33, 2, fy - H * 0.33, Col(0x3a2a1c)); c.R(W * 0.535 - 2, H * 0.33, 2, fy - H * 0.33, Col(0x3a2a1c))
        for j in 0..<6 { c.R(W * 0.42 + hashN(Double(j) * 3.1) * W * 0.1, H * 0.36 + hashN(Double(j) * 7.7) * H * 0.1, 1, 1, Col(0xfff6dc, 0.7)) }
        if let tg = first(7) {
            let on = tg.hit >= 0 && tg.hit < 2.6, flap = on ? cos(tg.hit * 9) * (1 - tg.hit / 2.6) : 1
            let hop = on ? abs(sin(tg.hit * 11)) * 3 : 0
            c.R(W * 0.445, fy - 4 - hop, 4.6, 4, Col(0x2a1c14)); c.R(W * 0.445, fy - 9 - hop, 3, 5.4, Col(0x2a1c14))
            c.R(W * 0.485, fy - 4 - (on ? 3 - hop : 0), 4.6, 4, Col(0x2a1c14)); c.R(W * 0.4865, fy - 9 - (on ? 3 - hop : 0), 3, 5.4, Col(0x2a1c14))
            for sd in [-1.0, 1.0] {
                let hx = sd < 0 ? W * 0.412 : W * 0.528
                c.save(); c.translate(hx, H * 0.5); c.scale(-sd * (abs(flap) < 0.12 ? 0.12 : flap), 1)
                c.RR(0, 0, W * 0.055, H * 0.16, 2, Col(0x8a5a2a)); c.R(1, 2, W * 0.055 - 2, 1, Col(0xa8744a))
                var lv = 3.0
                while lv < W * 0.055 - 2 { c.R(lv, 5, 0.8, H * 0.16 - 9, Col(0x5a3c22)); lv += 3.4 }
                c.restore()
            }
            spot(tg)
        }
        // a lamp on a chain: it swings
        if let tg = first(5) {
            let x = tg.x * W, y = tg.y * H
            let an = tg.hit >= 0 ? sin(tg.hit * 6) * 0.5 * exp(-tg.hit * 0.7) : sin(t * 0.8) * 0.03
            c.save(); c.translate(x, 27); c.rotate(an)
            c.R(-0.4, 0, 0.8, y - 27 - 4, Col(0x2a1c14))
            c.glow(0, y - 27, 26, Col(0xffd27a, 0.3), Col(0xffd27a, 0))
            c.poly(Col(0x3a2a1c), [-7, y - 27 - 1, -3, y - 27 - 5, 3, y - 27 - 5, 7, y - 27 - 1]); c.RR(-3, y - 27 - 1, 6, 5, 2, Col(0xffe9a8))
            c.restore()
            if tg.hit < 0 { spot(tg) }
        }
        // a wanted poster: it drops off its nail
        if let tg = first(8) {
            let x = tg.x * W, y = tg.y * H, u = tg.hit >= 0 ? min(1, tg.hit * 1.6) : 0
            c.save(); c.translate(x - 6, y - 8 + u * u * (fy - y)); c.rotate(u * 1.1)
            c.R(0, 0, 12, 16, Col(0xe6d4a4)); c.R(1.4, 1.6, 9.2, 2.2, Col(0x2a1c14)); c.R(3, 5, 6, 6, Col(0xb8885a)); c.R(3, 5, 6, 1.6, Col(0x1c1410)); c.R(2, 12.6, 8, 1, Col(0x8a2b22))
            c.restore()
            c.R(x - 0.5, y - 9, 1, 1, Col(0x6a6a72))
            spot(tg)
        }
        // a rocking chair: it rocks
        if let tg = first(2) {
            let x = tg.x * W, an = tg.hit >= 0 ? sin(tg.hit * 5) * 0.24 * exp(-tg.hit * 0.45) : 0
            c.save(); c.translate(x, fy - 1); c.rotate(an)
            let wd = Col(0x8a5a2a), wdD = Col(0x5a3c22)
            c.curve(-12, -1.5, 0, 3.4, 12, -1.5, 1.6, wdD)
            c.R(-8, -12, 1.6, 11.4, wd); c.R(6, -12, 1.6, 11.4, wd); c.R(-8.6, -12.6, 17, 1.8, wd)
            c.R(-8, -32, 1.6, 20, wd); c.R(-4.6, -30, 1.2, 18, wdD); c.R(-1.4, -30, 1.2, 18, wdD); c.R(-8.6, -32.6, 9.6, 1.8, wd)
            c.R(-9, -19, 16, 1.4, wdD); c.R(6, -19.6, 1.6, 8, wdD)
            c.restore()
            spot(tg)
        }
        // the piano: it plays, and the notes float up
        if let tg = first(1) {
            let x = tg.x * W, y = tg.y * H, on = tg.hit >= 0 && tg.hit < 3
            c.R(x - 20, y - 14, 40, fy - y + 14, Col(0x3a2420)); c.R(x - 21, y - 16, 42, 2.6, Col(0x5a3c2c)); c.R(x - 18, y - 11, 36, 9, Col(0x2a1814))
            c.R(x - 20, y + 4, 40, 4.4, Col(0x1c120c)); c.R(x - 19, y + 4.6, 38, 3, Col(0xf4ecd6))
            var kx = -19.0, ki = 0
            while kx < 19 {
                let down = on && (Int(tg.hit * 9) + ki) % 4 == 0
                c.R(x + kx, y + 4.6 + (down ? 0.8 : 0), 0.3, 3, Col(0x8a8478)); if ki % 7 != 2 && ki % 7 != 6 { c.R(x + kx + 1.3, y + 4.6, 1.3, 1.9, Col(0x1c120c)) }
                kx += 2.7; ki += 1
            }
            c.R(x - 20, y + 8.4, 2, fy - y - 8.4, Col(0x2a1814)); c.R(x + 18, y + 8.4, 2, fy - y - 8.4, Col(0x2a1814))
            c.R(x - 8, fy - 9, 12, 2, Col(0x6a2f26)); c.R(x - 7, fy - 7, 1.4, 7, Col(0x3a2420)); c.R(x + 1.6, fy - 7, 1.4, 7, Col(0x3a2420))
            if on { for j in 0..<5 { let u = (tg.hit * 0.6 + Double(j) * 0.2).truncatingRemainder(dividingBy: 1); let nx = x - 12 + Double(j) * 6 + sin(u * 6 + Double(j)) * 3, ny = y - 18 - u * 26; c.circ(nx, ny, 1.4, Col(0xfff0c0, 1 - u)); c.R(nx + 0.9, ny - 5, 0.6, 5, Col(0xfff0c0, 1 - u)) } }
            spot(tg)
        }
        // the far end of the room: a wall clock, a hat rack, a window, the card table, an ace on the wall
        c.R(W * 1.25, H * 0.24, W * 0.085, H * 0.19, Col(0x3a2a1c)); c.R(W * 1.255, H * 0.25, W * 0.075, H * 0.17, Col(0x141a30))
        c.circ(W * 1.305, H * 0.3, 4, Col(0xf4ecd0)); c.circ(W * 1.31, H * 0.295, 3.4, Col(0x141a30))
        c.R(W * 1.2915, H * 0.25, 1, H * 0.17, Col(0x3a2a1c)); c.R(W * 1.255, H * 0.333, W * 0.075, 1, Col(0x3a2a1c))
        if let tg = first(13) {
            let x0 = tg.x * W, (bx, by0) = g.gpos(tg, t), drop = tg.hit >= 0 ? min(fy - 2 - by0, tg.hit * tg.hit * 160) : 0
            c.RR(x0 - 8, H * 0.22, 16, H * 0.33, 2, Col(0x5a3c22)); c.RR(x0 - 6.4, H * 0.385, 12.8, H * 0.15, 1, Col(0x1c120c))
            c.poly(Col(0x6a4a2e), [x0 - 9, H * 0.22, x0, H * 0.19, x0 + 9, H * 0.22])
            c.circ(x0, H * 0.3, 6, Col(0xd8b860)); c.circ(x0, H * 0.3, 5, Col(0xf4ecd6))
            c.seg(x0, H * 0.3, x0 + 2.6, H * 0.3 - 1.6, 0.7, Col(0x1c120c)); c.seg(x0, H * 0.3, x0, H * 0.3 - 4, 0.6, Col(0x1c120c))
            if tg.hit < 0 { c.seg(x0, H * 0.39, bx, by0, 0.7, Col(0xc9a14a)) } else { c.seg(x0, H * 0.39, x0, H * 0.44, 0.7, Col(0xc9a14a)) }
            c.circ(tg.hit < 0 ? bx : x0 + 2, by0 + drop, 2.8, Col(0xe8c84a)); c.circ((tg.hit < 0 ? bx : x0 + 2) - 0.8, by0 + drop - 0.8, 0.9, Col(0xfff0a8))
        }
        if let tg = first(12) {
            let x = tg.x * W, y = tg.y * H, wd = Col(0x5a3c22)
            c.R(x - 0.9, y + 2, 1.8, fy - y - 2, wd); c.R(x - 6, fy - 1.6, 12, 1.6, wd); c.seg(x, y + 8, x - 5, y + 5, 1, wd); c.seg(x, y + 8, x + 5, y + 5, 1, wd)
            if tg.hit < 1.3 {
                let u = max(0, tg.hit)
                c.save(); c.translate(x + u * 26, y - u * 40 + u * u * 46); c.rotate(u * 7)
                c.ell(0, 2, 8.4, 1.8, Col(0x8a6238)); c.RR(-4.2, -4.6, 8.4, 6.6, 2, Col(0x9a7448)); c.R(-4.2, 0, 8.4, 1.2, Col(0x3a2420))
                c.restore()
            }
            spot(tg)
        }
        let tcx = W * 1.36
        c.R(tcx - 17, fy - 16, 34, 2.4, Col(0x8a5a2a)); c.R(tcx - 17, fy - 13.6, 34, 1, Col(0x2f5a3a)); c.R(tcx - 1.6, fy - 12.6, 3.2, 11, Col(0x5a3c22)); c.R(tcx - 8, fy - 1.8, 16, 1.8, Col(0x5a3c22))
        c.R(tcx - 12, fy - 17.2, 5, 1.2, Col(0xf4ecd6)); c.R(tcx - 6, fy - 17.2, 5, 1.2, Col(0xf4ecd6)); c.R(tcx + 8, fy - 20, 3, 4, Col(0xd8a850, 0.8))
        if let tg = first(11) {
            let (x, y) = g.gpos(tg, t)
            if tg.hit < 0 {
                let wv = abs(cos(t * 9)) * 2.6 + 0.5
                c.ell(x, y, wv, 3, Col(0xd8dce4)); c.ell(x - wv * 0.3, y - 0.8, wv * 0.4, 1.2, Col(0xffffff, 0.8))
            } else if tg.hit < 0.9 {
                for j in 0..<7 { let an = Double(j) * 0.9; c.R(x + cos(an) * tg.hit * 20, y - sin(an) * tg.hit * 16, 1.3, 1.3, Col(0xffffff, 1 - tg.hit / 0.9)) }
            }
        }
        if let tg = first(10) {
            let x = tg.x * W, y = tg.y * H, u = tg.hit >= 0 ? min(1, tg.hit * 1.4) : 0
            c.save(); c.translate(x, y + u * u * (fy - y - 4)); c.rotate(u * 5)
            c.RR(-3.8, -5, 7.6, 10, 1, Col(0xb5412e)); c.RR(-3.2, -4.4, 6.4, 8.8, 0.8, Col(0xf4ecd6))
            c.poly(Col(0x1c120c), [0, -2.6, 2.2, 0.8, -2.2, 0.8]); c.circ(-1, 0.9, 1.1, Col(0x1c120c)); c.circ(1, 0.9, 1.1, Col(0x1c120c)); c.R(-0.4, 1, 0.8, 2.2, Col(0x1c120c))
            c.restore()
            c.R(x - 0.5, y - 6.4, 1, 1, Col(0x6a6a72))
        }
        // a rat in the corner: out of its hole now and then, and gone when it is hit
        if let tg = first(3) {
            let hx = tg.x * W + 6, hy = fy - 0.5, out = tg.hit < 0 ? g.ratOut(t) : 0
            c.dome(hx, hy, 6.5, Col(0x0c0606))
            if tg.hit < 0 && out > 0.02 {
                let rx = hx - out * 13
                c.ell(rx, hy - 2.6, 5, 2.6, Col(0x6a625a)); c.circ(rx - 4.6, hy - 3, 2, Col(0x6a625a)); c.circ(rx - 4.2, hy - 5, 1.1, Col(0x8a7f74)); c.R(rx - 6.4, hy - 3.4, 0.7, 0.7, Col(0x0c0606)); c.R(rx - 7.2, hy - 2.6, 1, 0.6, Col(0xe8a8a0))
                c.curve(rx + 4.6, hy - 2, rx + 8, hy - 5, rx + 10, hy - 1, 0.6, Col(0xb89a90))
                if out > 0.35 { spot(tg, -out * 9 - 6) }
            } else if tg.hit >= 0 && tg.hit < 0.9 {
                for j in 0..<5 { let an = Double(j) * 1.3; c.R(hx - 8 + cos(an) * tg.hit * 14, hy - 4 - sin(an) * tg.hit * 12, 1.2, 1.2, Col(0xfff0a8, 1 - tg.hit / 0.9)) }
            }
        }
        for h in gl.holes { c.circ(h.0, h.1, 1.6, Col(0x0c0606)); c.circ(h.0, h.1, 2.6, Col(0x000000, 0.25)) }
        // what each hit paid, rising off the target
        for tg in gl.targets where tg.hit >= 0 && tg.hit < 1 {
            let (x, y) = g.gpos(tg, t)
            c.text("+\(tg.pay)", x, y - 6 - tg.hit * 14, tg.pay >= 4 ? 10 : 8, Col(0xffe08a, 1 - tg.hit), face: "Rye-Regular")
        }
        c.restore()
        // the awning and its sign
        c.R(0, 0, W, 20, Col(0x8a2f26))
        var ax = 0.0, ai = 0
        while ax < W { c.R(ax, 0, 12, 20, Col(ai % 2 == 0 ? 0xb5412e : 0xf0e8d8)); c.poly(Col(ai % 2 == 0 ? 0xb5412e : 0xf0e8d8), [ax, 20, ax + 12, 20, ax + 6, 27]); ax += 12; ai += 1 }
        c.R(0, 19.4, W, 1, Col(0x000000, 0.25))
        c.RR(W / 2 - 78, 3, 156, 15, 3, Col(0x2a1c14)); c.RR(W / 2 - 76, 4.4, 152, 12.2, 2, Col(0xead7a4))
        c.text("SHOOTING GALLERY", W / 2, 14, 9, Col(0x8a2f26), face: "Rye-Regular", fit: 144)
        // the counter, shots left, and the take
        let cy = H * 0.8
        c.R(0, cy, W, H - cy, Col(0x6a4a2e)); c.R(0, cy, W, 3, Col(0x9a7448)); c.R(0, cy + 3, W, 1, Col(0x3a2a1c))
        var px2 = 0.0
        while px2 < W { c.R(px2, cy + 4, 0.8, H - cy, Col(0x3a2a1c, 0.5)); px2 += 22 }
        for i in 0..<8 {
            let bx = 14 + Double(i) * 7, on = i < gl.shots
            c.RR(bx, cy + 11, 4, 9, 1, on ? Col(0xf2c14e) : Col(0x000000, 0.3)); c.poly(on ? Col(0xc88a4a) : Col(0x000000, 0.3), [bx + 0.4, cy + 11, bx + 3.6, cy + 11, bx + 2, cy + 6.4])
        }
        coinAt(W - 60, cy + 15)
        c.text("\(gl.won)", W - 44, cy + 19, 11, GOLD, face: "Rye-Regular")
        c.text(gl.shots > 0 ? "Small or moving targets pay more" : "That is your eight", W / 2, cy + 18.6, 8, Col(0xead7a4), bold: false)
        // the rifle on the counter, and its flash
        c.seg(W / 2 - 26, H + 2, W / 2 - 6, cy - 6, 5, Col(0x4a3424)); c.seg(W / 2 - 8, cy - 2, W / 2 + 2, cy - 22, 2.4, Col(0x3a3a40))
        if gl.flash > 0 { c.circ(W / 2 + 3, cy - 25, 6, Col(0xfff0b0, 0.9)); c.R(0, 0, W, H, Col(0xfff0c0, 0.12)) }
        c.glow(W / 2, H * 0.5, (W * W + H * H).squareRoot() * 0.56, Col(0x000000, 0), Col(0x000000, 0.45))
    }

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
            let sa = (dk - 0.25) * (1 - cl)
            // the river of stars, slanting low across the sky
            for i in 0..<70 {
                let u = hashN(Double(i) * 2.3 + 0.4)
                let x = u * W, y = gy * (0.16 + 0.3 * u) + (hashN(Double(i) * 6.1) - 0.5) * gy * 0.17
                c.R(x.rounded(), y.rounded(), 1, 1, Col(0xcfd8ff, sa * 0.32))
            }
            for i in 0..<80 {
                let x = (hashN(Double(i) * 3.1) * W).rounded(), y = (hashN(Double(i) * 7.7) * gy * 0.8).rounded()
                let tw = 0.5 + 0.5 * sin(g.clock * (1 + hashN(Double(i)) * 2) + Double(i))
                c.R(x, y, 1, 1, Col(i % 7 == 0 ? 0xffd9b0 : (i % 5 == 0 ? 0xc8dcff : 0xfff6dc), sa * tw))
                if i % 11 == 0 { c.R(x - 1, y, 3, 1, Col(0xfff6dc, sa * tw * 0.45)); c.R(x, y - 1, 1, 3, Col(0xfff6dc, sa * tw * 0.45)) }
            }
            // now and then one falls
            let ph = (g.clock / 9).truncatingRemainder(dividingBy: 1), n = floor(g.clock / 9)
            if ph < 0.08 {
                let u = ph / 0.08
                let x = hashN(n * 3.7) * W * 0.8 + W * 0.1 + u * 50, y = hashN(n * 9.1) * gy * 0.3 + 6 + u * 17
                c.seg(x - 13, y - 4.4, x, y, 0.8, Col(0xffffff, sa * (1 - u)))
            }
        }
        // the sun crosses by day; the moon by night
        if g.t > 0.02 && g.t < 0.76 {
            let u = (g.t - 0.02) / 0.74
            let x = W * (0.08 + 0.84 * u), y = gy - sin(u * PI) * gy * 0.82 + 6
            // long rays turning slowly, and a wide burn along the horizon as it sets
            let rayA = 0.09 * (1 - dk) * (1 - cl)
            if rayA > 0.01 {
                for k in 0..<10 {
                    let an = Double(k) * PI / 5 + g.clock * 0.05, rr = k % 2 == 0 ? 70.0 : 48.0
                    c.poly(Col(0xfff2c0, rayA), [x, y, x + cos(an - 0.06) * rr, y + sin(an - 0.06) * rr, x + cos(an + 0.06) * rr, y + sin(an + 0.06) * rr])
                }
            }
            if dusk > 0.05 { c.glow(x, gy, 150, Col(0xffa85a, 0.4 * dusk * (1 - dk)), Col(0xffa85a, 0)) }
            c.glow(x, y, 46, Col(0xfff2c0, 0.55 * (1 - dk)), Col(0xfff2c0, 0))
            c.circ(x, y, 9, Col.mix(Col(0xfff6d8), Col(0xff9a4a), dusk))
        } else {
            let u = g.t >= 0.76 ? (g.t - 0.76) / 0.26 : (g.t + 0.24) / 0.26
            let x = W * (0.15 + 0.7 * u), y = gy * 0.62 - sin(u * PI) * gy * 0.42
            c.glow(x, y, 30, Col(0xdfe8ff, 0.25), Col(0xdfe8ff, 0))
            c.circ(x, y, 7, Col(0xeef2ff))
            c.circ(x - 2.6, y + 1.2, 1.3, Col(0xc6cfe6)); c.circ(x - 3.6, y - 2.4, 0.8, Col(0xc6cfe6)); c.circ(x - 0.6, y + 4, 0.9, Col(0xc6cfe6))
            c.circ(x + 2.5, y - 1.5, 6, Col.mix(Col(0x0a0f24), Col(0x1a2040), 0.5))
        }
        // a few clouds drifting
        for i in 0..<5 {
            let w = 40 + hashN(Double(i) * 9.3) * 50
            var x = hashN(Double(i) * 4.1) * (W + 200) + g.clock * (3 + Double(i)) - g.cam * 0.05
            x = x.truncatingRemainder(dividingBy: W + 200) - 100
            let y = 14 + hashN(Double(i) * 2.2) * gy * 0.3
            let col = Col.mix(Col.mix(Col(0xffffff, 0.9), Col(0xffc9a0, 0.88), dusk), Col(0x3a4060, 0.6), dk)
            let under = Col.mix(Col.mix(Col(0xc4d0e0, 0.9), Col(0xc4705a, 0.88), dusk), Col(0x23284a, 0.6), dk)
            // a flat grey belly, and a heaped top catching the light
            c.RR(x + 2, y + 2, w - 4, 5, 2.5, under)
            c.RR(x, y, w, 5.5, 2.75, col)
            c.circ(x + w * 0.28, y, 5, col); c.circ(x + w * 0.5, y - 2.5, 7, col); c.circ(x + w * 0.72, y + 0.5, 4.5, col)
        }
    }

    private func mesas(_ dk: Double, _ dusk: Double) {
        let L = g.terrain
        let far = Col.mix(Col.mix(Col(L.far), Col(0xb0607a), dusk), Col(0x34365e), dk)
        let near = Col.mix(Col.mix(Col(L.mesa), Col(0x8a3e4a), dusk), Col(0x2a2a4e), dk)
        let cap = Col.mix(Col(L.mesaT), Col(0x4a4e72), dk)
        let nearD = Col.mix(Col.mix(Col(L.mesaS), Col(0x6a2e3a), dusk), Col(0x20203e), dk)
        let hz = Col.mix(Col.mix(Col(g.bio == .snow ? 0xeef3f8 : 0xf4dfb0), Col(0xf6b25a), dusk), Col(0x2c2a4a), dk)
        // a far blue line of hills, almost lost in the haze
        let off = g.cam * 0.1
        var ri = floor(off / 24) - 1
        var rp: [Double] = [-30, gy]
        while ri * 24 - off < W + 30 {
            rp.append(ri * 24 - off); rp.append(gy - 9 - hashN(ri * 1.9) * 15 - hashN(floor(ri / 4) * 0.37) * 14)
            ri += 1
        }
        rp.append(W + 30); rp.append(gy)
        c.poly(Col.mix(far, hz, 0.5), rp)
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
                // the lit rim, paler bands of rock, and scree at the foot
                let nearL = Col.mix(near, Col(0xffffff), 0.2 * (1 - dk))
                c.R(bx + 12, gy - h, w * 0.5 - 6, 1.2, nearL)
                c.R(bx + 13, gy - h * 0.86, w * 0.4, 1, nearL.alpha(0.6))
                c.R(bx + 9, gy - h * 0.55, w * 0.46, 1, nearL.alpha(0.45))
                c.poly(nearD.alpha(0.6), [bx - 16, gy, bx - 3, gy - h * 0.2, bx + 10, gy])
                c.poly(near, [bx + w, gy, bx + w + 9, gy - h * 0.18, bx + w + 22, gy])
            }
            i += 1
        }
        // haze lying along the foot of the hills
        c.vfill(0, gy - 28, W, 28, [(0, hz.alpha(0)), (1, hz.alpha(0.5 - 0.28 * dk))])
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
        // pebbles, and cracks in the hardpan
        var j = Int((g.cam / 37).rounded(.down)) - 1
        while Double(j) * 37 < g.cam + W + 20 {
            let wx = Double(j) * 37 + hashN(Double(j) * 6.3) * 30
            let y = (gy + 5 + hashN(Double(j) * 2.1) * (H - gy - 10)).rounded()
            let wet = (g.bio == .river || g.flooded) && wx > g.river.0 - 8 && wx < g.river.1 + 8
            if !wet {
                let x = sx(wx).rounded()
                if hashN(Double(j) * 9.9) > 0.5 {
                    c.ell(x + 0.6, y + 1.1, 2.6, 0.7, Col(0x000000, 0.16))
                    c.ell(x, y, 2.2, 1.3, Col(L.g2)); c.R(x - 1.3, y - 1, 1.8, 0.7, Col(L.edge, 0.8))
                } else if g.bio != .snow {
                    let ck = Col(L.speck, 0.5)
                    c.seg(x, y, x + 5, y + 1.5, 0.6, ck); c.seg(x + 5, y + 1.5, x + 8, y + 0.5, 0.6, ck); c.seg(x + 5, y + 1.5, x + 6, y + 4, 0.6, ck)
                }
            }
            j += 1
        }
        c.vfill(0, H - 10, W, 10, [(0, Col(0x000000, 0)), (1, Col(0x000000, 0.2))])
    }

    private func scenery() {
        var i = Int(((g.cam - 40) / 120).rounded(.down))
        let end = Int((g.cam + W + 40) / 120)
        while i <= end {
            if i >= -6 {
                let x = Double(i) * 120 + hashN(Double(i) * 6.6) * 90
                let inTown = x > 890 && x < g.gateE.x + 60
                let wet = g.bio == .river && x > g.river.0 - 14 && x < g.river.1 + 14
                let grazed = (x > g.pasture.0 - 12 && x < g.pasture.1 + 12) || [-90.0, -250, -434, -600, 752, 186, g.sFort.x, g.missionX, g.archX, 528].contains { abs($0 - x) < 34 }
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
            let rock = Col(0x8a5a3a), rockD = Col(0x6a4028), tim = Col(0x6a4a2e), timD = Col(0x3a2a1c)
            // the hill, its shaded side, and the spoil tipped out beside it
            c.poly(rock, [s - 40, gy, s - 26, gy - 24, s - 8, gy - 34, s + 20, gy - 32, s + 34, gy - 16, s + 44, gy])
            c.poly(rockD, [s + 20, gy - 32, s + 34, gy - 16, s + 44, gy, s + 24, gy, s + 16, gy - 20])
            c.R(s - 30, gy - 14, 20, 1, rockD.alpha(0.5)); c.R(s - 22, gy - 25, 30, 1, rockD.alpha(0.5))
            c.poly(Col(0x9a7a5a), [s - 54, gy, s - 45, gy - 8, s - 37, gy - 5, s - 30, gy])
            // the timbered mouth: posts and a cap, more sets going back into the dark, a lantern
            c.R(s - 9, gy - 18, 18, 18, Col(0x120a08))
            c.R(s - 6, gy - 14, 12, 0.8, timD.alpha(0.7)); c.R(s - 6, gy - 14, 0.8, 14, timD.alpha(0.7)); c.R(s + 5.2, gy - 14, 0.8, 14, timD.alpha(0.7)); c.R(s - 4, gy - 10, 8, 0.7, timD.alpha(0.45))
            c.R(s - 11, gy - 19, 2.6, 19, tim); c.R(s + 8.4, gy - 19, 2.6, 19, tim); c.R(s - 13, gy - 21.4, 26, 2.8, tim)
            c.R(s - 13, gy - 21.4, 26, 0.7, Col(0x8a6a44)); c.R(s - 11, gy - 19, 0.7, 19, Col(0x8a6a44))
            c.seg(s - 8.6, gy - 18.6, s - 5.6, gy - 15, 0.8, timD); c.seg(s + 8.6, gy - 18.6, s + 5.6, gy - 15, 0.8, timD)
            c.R(s + 11.6, gy - 15, 1.8, 2.8, timD); c.R(s + 12, gy - 14.4, 1, 1.6, Col(g.dark() > 0.3 ? 0xffd27a : 0xcfc8a8))
            // rails, and a cart of ore
            c.R(s - 4, gy - 0.9, 34, 0.6, Col(0x4a4a52))
            for k in 0..<7 { c.R(s - 2 + Double(k) * 5, gy - 0.4, 2.4, 0.8, timD) }
            let ox = s + 17.0
            c.poly(Col(0x5a5a62), [ox - 6, gy - 8, ox + 6, gy - 8, ox + 4.6, gy - 2.4, ox - 4.6, gy - 2.4]); c.R(ox - 6.4, gy - 8.6, 12.8, 1, Col(0x3a3a40))
            for k in 0..<4 { c.circ(ox - 3.6 + Double(k) * 2.4, gy - 9 - Double(k % 2), 1.6, Col(k % 2 == 0 ? 0x7a6a5a : 0xc9a14a)) }
            c.circ(ox - 3.4, gy - 1.6, 1.5, Col(0x2e2a2c)); c.circ(ox + 3.4, gy - 1.6, 1.5, Col(0x2e2a2c))
            // the board over the mouth, and a pick and shovel leaning by it
            c.R(s - 8, gy - 28, 16, 5, Col(0xead7a4)); c.R(s - 0.4, gy - 23, 0.8, 1.8, timD); c.text("MINE", s, gy - 24.2, 3.6, Col(0x4a2a22))
            c.seg(s - 16, gy, s - 13, gy - 11, 0.8, tim); c.curve(s - 16, gy - 10.4, s - 13, gy - 12.4, s - 10, gy - 10.4, 1, Col(0x8a8a90))
            c.seg(s - 20, gy, s - 18.4, gy - 10, 0.8, tim); c.RR(s - 21.4, gy - 3, 2.6, 3, 1, Col(0x8a8a90))
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
        if bl.building {
            // a job in hand: what stands now, with the new work rising through it from the ground as the crew gets on
            let bx = sx(bl.x).rounded(), full = d.h + Double(bl.level) * 5 + 26
            let cut = gy - full * clampD(bl.progress, 0, 1)
            bl.building = false
            building(bl, dk)
            c.save(); c.cg.clip(to: CGRect(x: bx - 14, y: cut, width: d.w + 28, height: gy + 6 - cut))
            bl.level += 1
            building(bl, dk)
            bl.level -= 1
            c.restore()
            bl.building = true
            c.R(bx - 2, cut - 0.6, d.w + 4, 1.2, Col(0xe2c08c, 0.8))
            scaffold(bx, d.w, full, bl.progress)
            return
        }
        let x = sx(bl.x).rounded(), w = d.w
        let lv = bl.level
        let h = d.h + Double(max(0, lv - 1)) * 5
        if lv == 0 {
            // burned out years ago: scorched boards, a ragged roofline, and the sign hanging by one nail
            let hh = d.h * 0.78
            let char = Col(0x2e2622), board = Col(0x7a6a58)
            c.ell(x + w / 2, gy + 1.2, w * 0.56, 2.2, Col(0x000000, 0.16))
            c.vfill(x, gy - hh, w, hh, [(0, Col(0x3e3530)), (0.55, Col(0x5c5048)), (1, Col(0x675b50))])
            for k in 0..<Int(w / 6) {
                let px = x + 2 + Double(k) * 6
                c.R(px, gy - hh + 2, 0.8, hh - 2, Col(0x4a3f38))
                if hashN(bl.x + Double(k) * 3.1) > 0.68 { c.R(px + 1, gy - 4 - hh * 0.8 * hashN(bl.x + Double(k)), 4, 3 + hashN(Double(k)) * 5, Col(0x241c18, 0.8)) }
            }
            var roofP: [Double] = [x - 1, gy - hh + 1.5]
            let rn = max(4, Int(w / 8))
            for k in 0...rn { roofP.append(x + Double(k) / Double(rn) * w); roofP.append(gy - hh - 1 - hashN(bl.x * 0.7 + Double(k) * 4.3) * 7) }
            roofP.append(x + w + 1); roofP.append(gy - hh + 1.5)
            c.poly(char, roofP)
            c.seg(x + w * 0.2, gy - hh, x + w * 0.34, gy - hh - 13, 1.6, char); c.seg(x + w * 0.34, gy - hh - 13, x + w * 0.5, gy - hh - 2, 1.4, char)
            c.seg(x + w * 0.74, gy - hh, x + w * 0.72, gy - hh - 10, 1.4, char)
            if hashN(bl.x * 0.31) > 0.35 {
                // a crow keeping watch on the rafter
                let cx = x + w * 0.34, cy = gy - hh - 15.5 + (sin(g.clock * 0.9 + bl.x) > 0.93 ? 0.8 : 0)
                c.R(cx - 0.6, cy + 1.2, 0.5, 1.6, Col(0x4a4038)); c.R(cx + 0.6, cy + 1.2, 0.5, 1.6, Col(0x4a4038))
                c.ell(cx, cy, 2.6, 1.7, Col(0x15121a)); c.ell(cx - 0.4, cy - 0.5, 1.6, 0.6, Col(0x3a3a5a, 0.7)); c.circ(cx + 2.2, cy - 1.4, 1.2, Col(0x15121a)); c.R(cx + 2.4, cy - 1.8, 0.5, 0.5, Col(0xd8d8e0)); c.poly(Col(0x4a4038), [cx + 3.2, cy - 1.6, cx + 5, cy - 1.1, cx + 3.2, cy - 0.7]); c.poly(Col(0x15121a), [cx - 2, cy - 0.5, cx - 5.4, cy + 1.6, cx - 1.6, cy + 1.2])
            }
            c.R(x + d.doorX, gy - 20, d.doorW, 20, Col(0x1e1814))
            c.vfill(x + d.doorX - 1, gy - 31, d.doorW + 2, 11, [(0, Col(0x1a1412, 0)), (1, Col(0x1a1412, 0.6))])
            c.seg(x + d.doorX - 1, gy - 18, x + d.doorX + d.doorW + 1, gy - 6, 2, board)
            c.seg(x + d.doorX - 1, gy - 6, x + d.doorX + d.doorW + 1, gy - 18, 2, board)
            c.R(x + d.doorX - 1, gy - 13, d.doorW + 2, 2, Col(0x8a7a66))
            c.R(x + d.doorX, gy - 12.6, 0.8, 0.8, Col(0x2a221e)); c.R(x + d.doorX + d.doorW - 0.8, gy - 12.6, 0.8, 0.8, Col(0x2a221e))
            for wn in d.wins {
                c.vfill(x + wn.0 - 1, gy - 30, wn.1 + 2, 9, [(0, Col(0x1a1412, 0)), (1, Col(0x1a1412, 0.6))])
                c.R(x + wn.0, gy - 21, wn.1, 12, Col(0x1e1814))
                c.poly(Col(0x9ab0b8, 0.5), [x + wn.0, gy - 9, x + wn.0, gy - 13, x + wn.0 + wn.1 * 0.4, gy - 9])
                c.seg(x + wn.0 - 1, gy - 18, x + wn.0 + wn.1 + 1, gy - 16.4, 2, board); c.seg(x + wn.0 - 1, gy - 12, x + wn.0 + wn.1 + 1, gy - 13.4, 2, Col(0x8a7a66))
            }
            c.save()
            c.translate(x + w / 2, gy - hh + 7.5)
            c.rotate(-0.08 + sin(g.clock * 1.3 + bl.x) * 0.012)
            c.R(-w * 0.31, -4.5, w * 0.62, 8.5, Col(0x4a3f38)); c.R(-w * 0.31, -4.5, w * 0.62, 1, Col(0x6e6054)); c.R(-w * 0.31, 3.2, w * 0.62, 0.8, Col(0x2e2622))
            c.text(d.name, 0, 2, 6, Col(0x9a8c7a), fit: w * 0.56)
            c.restore()
            // fallen timbers and weeds at the foot of the wall
            c.seg(x + w * 0.62, gy - 0.5, x + w * 0.9, gy - 5, 1.6, char); c.R(x + w * 0.1, gy - 2, 7, 2, Col(0x3a302a)); c.R(x + w * 0.14, gy - 3.4, 4, 1.4, char)
            for k in 0..<4 {
                let wxx = x + 3 + hashN(bl.x + Double(k) * 7.7) * (w - 6), sw = sin(g.clock * 1.5 + Double(k) + bl.x) * 0.6
                c.seg(wxx, gy, wxx - 1 + sw, gy - 4, 0.7, Col(0x6a7040)); c.seg(wxx + 1, gy, wxx + 2 + sw, gy - 5.5, 0.7, Col(0x808648))
            }
            if bl.building { scaffold(x, w, d.h, bl.progress) }
            return
        }
        c.ell(x + w / 2, gy + 1.2, w * 0.56, 2.2, Col(0x000000, 0.16))
        if dk < 0.6 { c.poly(Col(0x000000, 0.13 * (1 - dk / 0.6)), [x + 6, gy + 0.5, x + w + 6, gy + 0.5, x + w + 15, gy + 4.5, x + 12, gy + 4.5]) }
        let wall = Col(d.wall), trim = Col(d.trim), roof = Col(d.roof)
        let wallD = Col.mix(wall, Col(0x000000), 0.2), wallL = Col.mix(wall, Col(0xffffff), 0.14)
        let lit = dk > 0.3 && !bl.robbed
        let glass = lit ? Col(0xffd98a) : Col(0x9fc4d4)
        let upright = bl.type == .stable || bl.type == .bordello || bl.type == .forge || bl.type == .church
        let fh = 11.0 + Double(lv) * 2
        // a lamp post at the corner, lit after dark
        c.R(x - 11, gy - 24, 1.4, 24, Col(0x2e2622)); c.R(x - 13, gy - 2, 5.4, 2, Col(0x2e2622))
        c.R(x - 12.5, gy - 29, 4.4, 5, Col(0x2e2622)); c.R(x - 11.8, gy - 28.2, 3, 3.4, dk > 0.3 ? Col(0xffe08a) : Col(0xd8dcc8)); c.R(x - 13, gy - 30, 5.4, 1.2, Col(0x1c1816))
        // the boardwalk
        c.R(x - 6, gy - 2, w + 12, 2, Col(0x9a7a52)); c.R(x - 6, gy - 2, w + 12, 0.6, Col(0xc4a474))
        var bk = 0.0
        while bk < w + 12 { c.R(x - 6 + bk, gy - 1.4, 0.6, 1.4, Col(0x4a3626, 0.6)); bk += 6 }
        // the wall: clapboards or upright boards, corner boards, a shaded side
        c.R(x, gy - h, w, h - 2, wall)
        if upright {
            var k = 3.0
            while k < w { c.R(x + k, gy - h, 0.7, h - 2, wallD.alpha(0.55)); c.R(x + k + 0.7, gy - h, 0.5, h - 2, wallL.alpha(0.25)); k += 4 }
        } else {
            var yy = gy - h + 3.5
            while yy < gy - 3 { c.R(x, yy, w, 0.7, wallD.alpha(0.5)); c.R(x, yy + 0.7, w, 0.5, wallL.alpha(0.3)); yy += 3.5 }
        }
        c.R(x + w - 5, gy - h, 5, h - 2, Col(0x000000, 0.1))
        // weather: odd boards gone pale or dark, rain streaks from the eaves, nail heads, light from the left, dust near the ground
        var wk = 0
        while Double(wk) * 7 < w - 4 {
            let r = hashN(bl.x * 0.13 + Double(wk) * 2.7), bx0 = x + 2 + Double(wk) * 7
            if upright {
                if r > 0.62 { c.R(bx0, gy - h, 3.3, h - 2, r > 0.82 ? Col(0x000000, 0.09) : Col(0xffffff, 0.08)) }
            } else if r > 0.5 {
                let rows = max(1, Int((h - 9) / 3.5))
                let by = gy - h + 3.5 * Double(1 + Int(r * 97) % rows)
                c.R(bx0, by + 0.7, max(0, min(6 + r * 8, x + w - bx0 - 2)), 2.8, r > 0.78 ? Col(0x000000, 0.09) : Col(0xffffff, 0.08))
            }
            if r < 0.3 { c.vfill(bx0 + 1, gy - h, 1.6, 5 + r * 30, [(0, Col(0x2a1c14, 0.24)), (1, Col(0x2a1c14, 0))]) }
            wk += 1
        }
        var nx = 4.0
        while nx < w - 2 { c.R(x + nx, gy - h + 5, 0.6, 0.6, Col(0x000000, 0.3)); c.R(x + nx, gy - 8, 0.6, 0.6, Col(0x000000, 0.3)); nx += upright ? 4 : 12 }
        c.linear(x, gy - h, w, h - 2, x, 0, x + w, 0, [(0, Col(0xfff0d0, 0.13)), (0.35, Col(0xfff0d0, 0)), (0.7, Col(0x000000, 0)), (1, Col(0x000000, 0.17))])
        c.vfill(x, gy - 10, w, 8, [(0, Col(0x3a2a1c, 0)), (1, Col(0x3a2a1c, 0.3))])
        c.R(x, gy - h, 1.8, h - 2, trim); c.R(x + w - 1.8, gy - h, 1.8, h - 2, trim)
        c.R(x, gy - 5, w, 3, wallD.alpha(0.5))
        // the false front, its cornice and dentils
        if bl.type == .stable {
            // a barn: gable, hayloft door and hoist
            c.poly(wall, [x - 2, gy - h, x + w / 2, gy - h - fh - 6, x + w + 2, gy - h])
            c.poly(roof, [x - 5, gy - h + 1, x + w / 2, gy - h - fh - 9, x + w + 5, gy - h + 1, x + w + 2, gy - h + 1, x + w / 2, gy - h - fh - 6, x - 2, gy - h + 1])
            c.R(x + w / 2 - 5, gy - h - 9, 10, 9, trim); c.R(x + w / 2 - 4, gy - h - 8, 8, 8, Col(0x2a1c14))
            c.R(x + w / 2 - 0.5, gy - h - fh - 9, 1.2, 4, Col(0x2e2622)); c.R(x + w / 2 - 0.5, gy - h - fh - 5.4, 5, 1, Col(0x2e2622))
        } else {
            c.R(x - 2, gy - h - fh, w + 4, fh, wall)
            var yy = gy - h - fh + 3.5
            while yy < gy - h - 1 { c.R(x - 2, yy, w + 4, 0.6, wallD.alpha(0.4)); yy += 3.5 }
            c.R(x - 2, gy - h - fh, 1.6, fh, trim); c.R(x + w + 0.4, gy - h - fh, 1.6, fh, trim)
            c.R(x - 4, gy - h - fh - 3, w + 8, 3, roof); c.R(x - 4, gy - h - fh - 3, w + 8, 0.8, Col.mix(roof, Col(0xffffff), 0.3))
            var dx = 0.0
            while dx < w + 2 { c.R(x - 1 + dx, gy - h - fh, 2, 1.5, trim); dx += 4 }
            c.linear(x - 2, gy - h - fh, w + 4, fh, x - 2, 0, x + w + 2, 0, [(0, Col(0xfff0d0, 0.13)), (0.4, Col(0xfff0d0, 0)), (1, Col(0x000000, 0.15))])
            c.R(x - 2, gy - h - fh + 1.5, w + 4, 1.4, Col(0x000000, 0.2))
            for k in 0..<3 { let r = hashN(bl.x * 0.21 + Double(k) * 4.1); c.vfill(x + 2 + r * (w - 6), gy - h - fh + 1.5, 1.4, 3 + r * (fh - 4), [(0, Col(0x2a1c14, 0.25)), (1, Col(0x2a1c14, 0))]) }
        }
        if g.bio == .snow { c.RR(x - 4, gy - h - fh - 5, w + 8, 3, 1.5, Col(0xf4f8ff)); c.R(x - 5, gy - 27.5, w + 10, 1.8, Col(0xf4f8ff)) }
        c.R(x - 2, gy - h - 1, w + 4, 2, trim)
        // the sign: a bordered board, lettered in the game's display face
        let sy0 = bl.type == .stable ? gy - h + 3 : gy - h - fh + 2, sh = bl.type == .stable ? 8.0 : fh - 4
        c.R(x + 5, sy0, w - 10, sh, Col(d.ink)); c.R(x + 6, sy0 + 1, w - 12, sh - 2, Col(d.sign))
        c.R(x + 6, sy0 + 1, w - 12, 0.7, Col(0xffffff, 0.35))
        c.text(d.name, x + w / 2, sy0 + sh / 2 + 2.5, 7, Col(d.ink), face: "Rye-Regular", fit: w - 16)
        if bl.type == .sheriff { star(x + 3, sy0 + sh / 2, 2.4, GOLD); star(x + w - 3, sy0 + sh / 2, 2.4, GOLD) }
        if bl.type == .doctor { c.R(x + w - 8, gy - h + 4, 5, 1.6, Col(0x3d8a5a)); c.R(x + w - 6.3, gy - h + 2.3, 1.6, 5, Col(0x3d8a5a)) }
        // upper windows, or a balcony, come with the second level
        if lv >= 2 && bl.type != .stable {
            for ux in [x + 8, x + w - 18] {
                c.R(ux - 1, gy - h + 2, 12, 10, trim); c.R(ux, gy - h + 3, 10, 8, glass)
                c.R(ux + 4.6, gy - h + 3, 0.8, 8, trim); c.R(ux, gy - h + 6.6, 10, 0.8, trim)
                c.R(ux - 3, gy - h + 2, 2, 10, wallD); c.R(ux + 11, gy - h + 2, 2, 10, wallD)
                if !lit { c.poly(Col(0xffffff, 0.3), [ux, gy - h + 3, ux + 4, gy - h + 3, ux, gy - h + 7]) }
            }
            if bl.type == .bordello || bl.type == .saloon {
                c.R(x - 4, gy - 33, w + 8, 1, trim); c.R(x - 4, gy - 27.4, w + 8, 1.2, trim)
                var rx = 0.0
                while rx < w + 8 { c.R(x - 4 + rx, gy - 33, 0.9, 6, trim); rx += 3 }
            }
        }
        // the porch: a slanted shingle roof, a valance, posts with brackets, shade beneath
        let py = gy - 26.0
        c.poly(roof, [x - 6, py + 4, x - 2, py, x + w + 2, py, x + w + 6, py + 4])
        // shingles, each a little different, and the lit top edge
        var tx = 0.0, ti = 0
        while tx < w + 6 {
            let tone = hashN(bl.x + Double(ti) * 1.7)
            if tx < w + 1 { c.R(x - 1.5 + tx, py + 0.5, 2.2, 1.4, tone > 0.5 ? Col(0xffffff, 0.1) : Col(0x000000, 0.1)) }
            c.R(x - 3.4 + tx, py + 2.3, 2.2, 1.5, tone > 0.5 ? Col(0x000000, 0.1) : Col(0xffffff, 0.08))
            tx += 2.5; ti += 1
        }
        c.R(x - 2, py, w + 4, 0.6, Col(0xffffff, 0.22))
        var sx2 = 2.0
        while sx2 < w + 8 { c.R(x - 5 + sx2, py + 1, 0.6, 3, Col(0x000000, 0.22)); sx2 += 5 }
        c.R(x - 4, py + 1.8, w + 8, 0.6, Col(0x000000, 0.18))
        c.R(x - 6, py + 4, w + 12, 1.2, Col.mix(roof, Col(0x000000), 0.35))
        if bl.type == .saloon || bl.type == .bordello || bl.type == .store {
            var vx = 0.0, vi = 0
            while vx < w + 10 {
                c.poly(vi % 2 == 0 ? Col(d.sign) : Col(d.ink), [x - 5 + vx, py + 5.2, x - 1 + vx, py + 5.2, x - 3 + vx, py + 8])
                vx += 4; vi += 1
            }
        }
        c.vfill(x, py + 5.2, w, 11, [(0, Col(0x000000, 0.34)), (1, Col(0x000000, 0))])
        var posts = [x - 3, x + w + 1]
        if w > 70 { posts.append(x + w * 0.33); posts.append(x + w * 0.66) }
        for px in posts {
            c.R(px, py + 5.2, 1.8, gy - 2 - py - 5.2, trim); c.R(px + 1.2, py + 5.2, 0.6, gy - 2 - py - 5.2, Col(0x000000, 0.22))
            c.R(px - 0.5, gy - 4, 2.8, 2, trim)
            c.poly(trim, [px - 2.4, py + 5.2, px, py + 5.2, px, py + 8.4]); c.poly(trim, [px + 1.8, py + 5.2, px + 4.2, py + 5.2, px + 1.8, py + 8.4])
        }
        // the door
        if bl.type == .stable {
            c.R(x + d.doorX - 5, gy - 21, d.doorW + 10, 19, trim); c.R(x + d.doorX - 4, gy - 20, d.doorW + 8, 18, Col(0x2a1c14))
            c.seg(x + d.doorX - 4, gy - 20, x + d.doorX + d.doorW / 2, gy - 2, 1, trim); c.seg(x + d.doorX + d.doorW + 4, gy - 20, x + d.doorX + d.doorW / 2, gy - 2, 1, trim)
            c.R(x + d.doorX - 2, gy - 5, 6, 3, Col(0xd8b860)); c.R(x + d.doorX + d.doorW - 3, gy - 6, 5, 4, Col(0xc9a850))
        } else {
            c.R(x + d.doorX - 1.4, gy - 22, d.doorW + 2.8, 20, trim)
            c.R(x + d.doorX, gy - 20.6, d.doorW, 18.6, Col(0x3a2a1c))
            c.R(x + d.doorX + 1.5, gy - 19, d.doorW - 3, 3.2, glass.alpha(lit ? 0.95 : 0.7))
            if bl.type == .saloon {
                c.R(x + d.doorX, gy - 13, d.doorW / 2 - 0.5, 8, Col(0xc98a4a)); c.R(x + d.doorX + d.doorW / 2 + 0.5, gy - 13, d.doorW / 2 - 0.5, 8, Col(0xc98a4a))
                var lx = 1.0
                while lx < d.doorW / 2 - 1 { c.R(x + d.doorX + lx, gy - 12, 0.6, 6, Col(0x8a5a2a)); c.R(x + d.doorX + d.doorW / 2 + 0.5 + lx, gy - 12, 0.6, 6, Col(0x8a5a2a)); lx += 2 }
            } else {
                c.R(x + d.doorX + 1.5, gy - 14.6, d.doorW - 3, 5, Col(0x4e3826)); c.R(x + d.doorX + 1.5, gy - 8.4, d.doorW - 3, 5.6, Col(0x4e3826))
                c.R(x + d.doorX + d.doorW - 3, gy - 10.4, 1.2, 1.2, Col(0xd8b860))
            }
            c.R(x + d.doorX - 2, gy - 2.8, d.doorW + 4, 1, Col(0x6a5238))
        }
        // the windows: frame, sill, panes, a curtain, and with the second level a flower box
        for (wi, wn) in d.wins.enumerated() {
            let wx = x + wn.0, ww = wn.1
            c.R(wx - 1.4, gy - 22.4, ww + 2.8, 14.8, trim)
            c.R(wx, gy - 21, ww, 12, glass)
            if !lit { c.vfill(wx, gy - 21, ww, 12, [(0, Col(0xdff0ff, 0.25)), (0.5, Col(0x000000, 0.05)), (1, Col(0x000000, 0.3))]) }
            c.R(wx, gy - 21, ww, 1, Col(0x000000, 0.3)); c.R(wx, gy - 21, 0.8, 12, Col(0x000000, 0.2))
            if lit { c.R(wx, gy - 14, ww, 5, Col(0xff9a3a, 0.28)) } else { c.poly(Col(0xffffff, 0.32), [wx, gy - 21, wx + ww * 0.45, gy - 21, wx, gy - 14]) }
            if bl.type == .store {
                // goods on show
                let goods: [UInt32] = [0xb5412e, 0x3f6f9a, 0xd8b860, 0x5f8a4a]
                var gx = 1.0, gi = wi
                while gx < ww - 3 { c.R(wx + gx, gy - 13 - Double(gi % 2) * 2, 3, 4 + Double(gi % 2) * 2, Col(goods[gi % 4])); gx += 4.4; gi += 1 }
            } else if bl.type == .sheriff || bl.type == .bank {
                var k = 2.0
                while k < ww { c.R(wx + k, gy - 21, 1, 12, Col(0x2a2a2a)); k += 3.4 }
            } else {
                let cur: UInt32 = bl.type == .bordello ? 0xc0392b : (bl.type == .doctor ? 0xf4f0e4 : (bl.type == .saloon ? 0x8a2f26 : 0xead7a4))
                c.poly(Col(cur, 0.9), [wx, gy - 21, wx + ww * 0.42, gy - 21, wx, gy - 12]); c.poly(Col(cur, 0.9), [wx + ww, gy - 21, wx + ww * 0.58, gy - 21, wx + ww, gy - 12])
            }
            c.R(wx + ww / 2 - 0.4, gy - 21, 0.8, 12, trim); c.R(wx, gy - 15.4, ww, 0.8, trim)
            c.R(wx - 2.4, gy - 9, ww + 4.8, 1.6, trim)
            if lv >= 2 && bl.type != .sheriff && bl.type != .bank {
                c.R(wx - 1.5, gy - 7.6, ww + 3, 2.6, Col(0x6a4a2e))
                var fx = 0.0, fi = wi
                while fx < ww + 1 { c.R(wx - 1 + fx, gy - 9.4, 1.6, 2, Col(0x4f8a3e)); c.R(wx - 0.6 + fx, gy - 10.4, 1.2, 1.2, Col(fi % 2 == 0 ? 0xe8553f : 0xf2d94e)); fx += 2.6; fi += 1 }
            }
        }
        // a hitching rail, a barrel, and with the third level a flag
        if bl.type == .saloon || bl.type == .store || bl.type == .sheriff {
            let hx = x + w + 9
            c.R(hx, gy - 7, 1.4, 7, Col(0x5a3c22)); c.R(hx + 11, gy - 7, 1.4, 7, Col(0x5a3c22)); c.R(hx - 1, gy - 7.6, 14.4, 1.4, Col(0x6a4a2e))
        }
        if bl.type == .store || bl.type == .saloon || bl.type == .forge {
            let bx2 = x + w - 9
            c.RR(bx2, gy - 9, 6, 7, 1.5, Col(0x7a5632)); c.R(bx2, gy - 7.4, 6, 0.8, Col(0x3a2a1c)); c.R(bx2, gy - 4.4, 6, 0.8, Col(0x3a2a1c)); c.R(bx2 + 0.6, gy - 9, 4.8, 0.8, Col(0x9a7448))
        }
        if bl.type == .saloon || bl.type == .bordello || bl.type == .doctor || bl.type == .bank {
            // a chimney, smoking by day and by night
            let cx2 = x + w - 15, cy2 = gy - h - fh - 3
            c.R(cx2, cy2 - 8, 5, 8, Col(0x7a4a3a)); c.R(cx2 - 0.6, cy2 - 9.4, 6.2, 1.6, Col(0x4a2e26))
            for br in 0..<4 { let byy = cy2 - 2 - Double(br) * 2; c.R(cx2, byy, 5, 0.4, Col(0x3a2420, 0.7)); c.R(cx2 + (br % 2 == 0 ? 1.6 : 3.2), byy - 2, 0.4, 2, Col(0x3a2420, 0.6)) }
            c.R(cx2 + 3.6, cy2 - 8, 1.4, 8, Col(0x000000, 0.18)); c.R(cx2, cy2 - 8, 5, 1.2, Col(0x1c1412, 0.5))
            for i in 0..<4 {
                let k = (g.clock * 0.22 + Double(i) * 0.25 + bl.x * 0.01).truncatingRemainder(dividingBy: 1)
                c.circ(cx2 + 2.5 + k * 9 + sin(g.clock + Double(i)) * 1.5, cy2 - 11 - k * 16, 1.6 + k * 3.4, Col(0xe8e2dc, 0.3 * (1 - k)))
            }
        }
        if lv >= 4 {
            // the grandest it gets: a gilded cornice, bunting along the porch, a weathervane
            c.R(x - 3, gy - h - fh - 1.4, w + 6, 1.4, Col(0xf2c14e)); c.R(x - 3, gy - h - fh - 1.4, w + 6, 0.4, Col(0xfff0a8))
            var bx3 = 0.0, bi = 0
            while bx3 < w - 2 { c.poly(Col([0xb5412e, 0xf4ecd6, 0x2f4a7a][bi % 3] as UInt32), [x + bx3, py + 5.4, x + bx3 + 4, py + 5.4, x + bx3 + 2, py + 9]); bx3 += 4.6; bi += 1 }
            c.R(x + 9, gy - h - fh - 10, 0.8, 9, Col(0x2a1c14)); c.poly(Col(0x2a1c14), [x + 5, gy - h - fh - 9.4, x + 13.5, gy - h - fh - 10.8, x + 13.5, gy - h - fh - 8])
            c.R(x + 7.4, gy - h - fh - 7, 4, 0.6, Col(0x2a1c14))
        }
        if lv >= 3 {
            c.R(x + w / 2 - 1, gy - h - fh - 15, 1.6, 12, Col(0x3a2a1c))
            let wv = sin(g.clock * 4) * 1.5
            c.poly(Col(0xb5412e), [x + w / 2 + 0.6, gy - h - fh - 15, x + w / 2 + 11 + wv, gy - h - fh - 13.4, x + w / 2 + 11 + wv, gy - h - fh - 9.6, x + w / 2 + 0.6, gy - h - fh - 9])
            c.R(x + w / 2 + 0.6, gy - h - fh - 13, 10 + wv, 1, Col(0xf4ecd6)); c.R(x + w / 2 + 0.6, gy - h - fh - 15, 4, 2.6, Col(0x2f4a7a))
        }
        if bl.type == .church {
            // a belfry with louvres and a bell that swings when it is rung, a shingled spire, a gilt cross, coloured glass
            let mx = x + w / 2, by0 = gy - h - fh
            c.R(mx - 7, by0 - 16, 14, 16, wall); c.R(mx + 4, by0 - 16, 3, 16, Col(0x000000, 0.12)); c.R(mx - 8, by0 - 17, 16, 1.4, trim)
            c.R(mx - 4, by0 - 13, 8, 9, Col(0x2a1c14))
            for k in 0..<3 { c.R(mx - 4, by0 - 12 + Double(k) * 3, 8, 0.6, Col(0x5a4a3a)) }
            c.save(); c.translate(mx, by0 - 12.5); c.rotate(g.bell ? sin(g.clock * 7) * 0.5 : 0)
            c.poly(Col(0xd8b860), [-2.4, 5.5, -1.4, 1, 1.4, 1, 2.4, 5.5]); c.R(-0.4, 5.5, 0.8, 1.2, Col(0x8a6a2a))
            c.restore()
            c.poly(roof, [mx - 9, by0 - 17, mx, by0 - 34, mx + 9, by0 - 17]); c.poly(Col(0x000000, 0.18), [mx, by0 - 34, mx + 9, by0 - 17, mx + 1, by0 - 17])
            for k in 1..<4 { let u = Double(k) / 4; c.R(mx - 9 * u, by0 - 34 + 17 * u, 18 * u, 0.5, Col(0x000000, 0.25)) }
            c.R(mx - 0.6, by0 - 42, 1.4, 9, Col(0xf2c14e)); c.R(mx - 3, by0 - 39.6, 6.2, 1.4, Col(0xf2c14e))
            let panes: [UInt32] = [0xb5412e, 0x3f6f9a, 0xd8b860, 0x5f8a4a]
            for wn in d.wins {
                let wx = x + wn.0, ww = wn.1
                for k in 0..<4 { c.R(wx + ww * Double(k % 2) / 2, gy - 21 + Double(k / 2) * 6, ww / 2, 6, Col(panes[k], lit ? 0.9 : 0.6)) }
                c.R(wx + ww / 2 - 0.3, gy - 21, 0.6, 12, Col(0x2a1c14)); c.R(wx, gy - 15.3, ww, 0.6, Col(0x2a1c14))
                c.poly(wall, [wx - 0.2, gy - 21.2, wx + ww * 0.32, gy - 21.2, wx - 0.2, gy - 18]); c.poly(wall, [wx + ww + 0.2, gy - 21.2, wx + ww * 0.68, gy - 21.2, wx + ww + 0.2, gy - 18])
            }
        }
        if bl.type == .forge {
            // the fire inside throwing its light out of the door, a stone stack with sparks going up, horseshoes nailed to the wall
            c.R(x + d.doorX + 2, gy - 12, d.doorW - 4, 12, Col(0xe8742a, 0.55 + 0.25 * sin(g.clock * 7)))
            c.glow(x + d.doorX + d.doorW / 2, gy - 8, 16, Col(0xff8a3a, 0.26 + 0.1 * sin(g.clock * 7)), Col(0xff8a3a, 0))
            c.R(x + 5, gy - h - fh - 12, 8, 12, Col(0x8a8478)); c.R(x + 4.4, gy - h - fh - 13.4, 9.2, 1.6, Col(0x6a665e))
            for k in 0..<3 { c.R(x + 5 + Double(k % 2) * 4, gy - h - fh - 10 + Double(k) * 3.4, 4, 0.5, Col(0x5a564e)) }
            for i in 0..<6 {
                let k = (g.clock * 0.7 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
                c.R(x + 9 + sin(g.clock * 3 + Double(i) * 2) * 3 + k * 4, gy - h - fh - 14 - k * 18, 1, 1, Col(0xffb040, 1 - k))
            }
            for k in 0..<3 { c.ellStroke(x + w - 22 + Double(k) * 5, gy - 17, 1.5, 1.8, 0.7, Col(0x8a8a90)); c.R(x + w - 22.8 + Double(k) * 5, gy - 15.6, 1.6, 1, wall) }
        }
        if bl.type == .telegraph {      // a mast, and at dusk a red pennant on the side the raid will come from
            c.R(x + 8, gy - h - fh - 20, 1.5, 20, Col(0x3a2a1c)); c.R(x + 4, gy - h - fh - 18, 9.5, 1, Col(0x3a2a1c))
            if g.raidOn { c.poly(Col(0xc0392b), [x + 9, gy - h - fh - 20, x + 9 + g.side * 8, gy - h - fh - 17.5, x + 9, gy - h - fh - 15]) }
        }
        // what each trade keeps out front
        let pk = Col(0x2a1c14)
        switch bl.type {
        case .saloon:
            c.R(x + 3, gy - 6.4, 11, 1.2, Col(0x7a5632)); c.R(x + 4, gy - 5.2, 1, 3, Col(0x5a3c22)); c.R(x + 12, gy - 5.2, 1, 3, Col(0x5a3c22)); c.R(x + 3, gy - 9.6, 11, 1, Col(0x7a5632)); c.R(x + 3, gy - 9.6, 1, 4, Col(0x5a3c22)); c.R(x + 13, gy - 9.6, 1, 4, Col(0x5a3c22))
            c.R(x + d.doorX - 6.5, gy - 19, 4.6, 6.4, Col(0xe8dcb8)); c.R(x + d.doorX - 5.8, gy - 18, 3.2, 1, Col(0x8a2b22)); c.R(x + d.doorX - 5.8, gy - 16.2, 3.2, 0.5, pk); c.R(x + d.doorX - 5.8, gy - 15, 3.2, 0.5, pk)
        case .store:
            c.RR(x + 3, gy - 7, 5, 5, 2, Col(0xd8c8a0)); c.RR(x + 7, gy - 6.4, 5, 4.4, 2, Col(0xc8b88e)); c.R(x + 4.6, gy - 7.6, 1.6, 1, Col(0x8a7a5a))
            c.R(x + w - 19, gy - 8, 7, 6, Col(0x9a7448)); c.R(x + w - 19, gy - 8, 7, 0.8, Col(0x6a4a2e)); c.seg(x + w - 19, gy - 8, x + w - 12, gy - 2, 0.6, Col(0x6a4a2e))
        case .sheriff:
            for k in 0..<2 { let px0 = x + d.doorX - 7 - Double(k) * 5.4; c.R(px0, gy - 19, 4.4, 6, Col(0xe6d4a4)); c.R(px0 + 1.2, gy - 17.6, 2, 2, Col(0x8a6240)); c.R(px0 + 0.8, gy - 14.8, 2.8, 0.5, pk) }
        case .bank:
            var qy = gy - 6.0, qi = 0
            while qy > gy - h + 2 {
                let qw = qi % 2 == 0 ? 5.0 : 3.4
                c.R(x, qy, qw, 3.4, Col(0xd8d2c4)); c.R(x + w - qw, qy, qw, 3.4, Col(0xd8d2c4))
                qy -= 4; qi += 1
            }
            c.R(x + d.doorX + d.doorW + 4, gy - 17, 5, 3.4, Col(0xd8b860)); c.R(x + d.doorX + d.doorW + 4.8, gy - 15.8, 3.4, 0.5, pk)
        case .stable:
            c.R(x + 3, gy - 7, 9, 5, Col(0xd8b860)); c.R(x + 3, gy - 5.2, 9, 0.5, Col(0x9a7a30)); c.R(x + 6, gy - 7, 0.5, 5, Col(0x9a7a30)); c.R(x + 5, gy - 11, 7, 4, Col(0xe0c070)); c.R(x + 5, gy - 9.4, 7, 0.5, Col(0x9a7a30))
            c.RR(x + w - 9, gy - 5, 4.4, 4.4, 1, Col(0x6a6a72)); c.R(x + w - 9, gy - 5, 4.4, 0.8, Col(0x9a9aa6))
        case .station:
            c.R(x + 4, gy - 6.4, 12, 1.2, Col(0x7a5632)); c.R(x + 5, gy - 5.2, 1, 3, Col(0x5a3c22)); c.R(x + 14, gy - 5.2, 1, 3, Col(0x5a3c22))
            c.R(x + w - 14, gy - 7, 8, 5, Col(0x6a3a26)); c.R(x + w - 14, gy - 5.4, 8, 0.6, Col(0xd8b860)); c.R(x + w - 10.6, gy - 7.6, 1.4, 0.8, Col(0xd8b860))
        case .doctor:
            c.R(x + d.doorX - 7, gy - 19, 5, 5, Col(0xf4f0e4)); c.R(x + d.doorX - 5.1, gy - 18.4, 1.2, 3.8, Col(0x3f8a5a)); c.R(x + d.doorX - 6.4, gy - 17.1, 3.8, 1.2, Col(0x3f8a5a))
        case .bordello:
            c.R(x + d.doorX - 4, gy - 20, 0.5, 2, pk); c.RR(x + d.doorX - 5.4, gy - 18, 3.2, 4, 1.4, Col(0xd0392b))
            if dk > 0.3 { c.glow(x + d.doorX - 3.8, gy - 16, 8, Col(0xff5a4a, 0.5 * dk), Col(0xff5a4a, 0)) }
        case .forge:
            c.R(x + 3, gy - 6, 9, 1.4, Col(0x4a4a52)); c.R(x + 4, gy - 4.6, 7, 1.8, Col(0x3a3a40)); c.R(x + 6, gy - 2.8, 3, 2.8, Col(0x3a3a40))
            c.ellStroke(x + w - 6, gy - 6, 4.5, 4.5, 0.9, Col(0x6a4a2e)); c.seg(x + w - 10.5, gy - 6, x + w - 1.5, gy - 6, 0.6, Col(0x6a4a2e)); c.seg(x + w - 6, gy - 10.5, x + w - 6, gy - 1.5, 0.6, Col(0x6a4a2e))
        case .telegraph:
            c.R(x + 4.6, gy - h - fh - 19.4, 1.2, 1.4, Col(0x7ad8b8)); c.R(x + 11.6, gy - h - fh - 19.4, 1.2, 1.4, Col(0x7ad8b8))
            c.curve(x + 13, gy - h - fh - 18, x + w * 0.6, gy - h - fh - 8, x + w + 14, gy - h - fh - 16, 0.4, Col(0x1c1410))
        case .church:
            c.circ(x + w / 2, gy - h + 6, 3.4, trim); c.circ(x + w / 2, gy - h + 6, 2.6, Col(0x3f6f9a)); c.R(x + w / 2 - 0.3, gy - h + 3.4, 0.6, 5.2, Col(0xd8b860)); c.R(x + w / 2 - 2.6, gy - h + 5.7, 5.2, 0.6, Col(0xd8b860))
        default: break
        }
        // a lamp by every door, lit after dark
        c.R(x + d.doorX + d.doorW + 1.8, gy - 19.6, 0.5, 1.4, pk); c.R(x + d.doorX + d.doorW + 1, gy - 18.2, 2, 2.8, pk); c.R(x + d.doorX + d.doorW + 1.4, gy - 17.7, 1.2, 1.8, Col(dk > 0.3 ? 0xffd27a : 0xcfc8a8))
        if bl.robbed { c.text("ROBBED", x + w / 2, gy - h - fh - 4, 6, Col(0xd04a3a)) }
        if bl.building { scaffold(x, w, h + fh, bl.progress) }
        if bl.flash > 0 { c.R(x - 2, gy - h - fh, w + 4, h + fh, Col(0xfff0c0, bl.flash)) }
    }

    /// Staging that climbs a little ahead of the work, a ladder, and dust coming off the top course.
    private func scaffold(_ x: Double, _ w: Double, _ h: Double, _ p: Double) {
        let col = Col(0xc9a86a), dkc = Col(0x8a6a3a)
        let done = h * clampD(p, 0, 1), top = min(h + 6, done + 8)
        c.R(x - 4, gy - top, 1.6, top, col); c.R(x + w + 2.4, gy - top, 1.6, top, col); c.R(x + w * 0.5, gy - top, 1.2, top, dkc.alpha(0.6))
        var yy = gy - 9.0
        while yy > gy - top { c.R(x - 5, yy, w + 10, 1.4, col); c.R(x - 5, yy + 1.4, w + 10, 0.5, dkc); yy -= 11 }
        c.seg(x - 3, gy, x + w * 0.28, gy - top, 0.8, col.alpha(0.8)); c.seg(x + w + 3, gy, x + w * 0.72, gy - top, 0.8, col.alpha(0.8))
        c.R(x + w + 5, gy - top, 0.7, top, dkc); c.R(x + w + 8, gy - top, 0.7, top, dkc)
        var ly = gy - 2.0
        while ly > gy - top { c.R(x + w + 5, ly, 3.7, 0.6, dkc); ly -= 3 }
        for i in 0..<8 {
            let k = (g.clock * 0.8 + hashN(Double(i) * 3.3 + x * 0.01)).truncatingRemainder(dividingBy: 1)
            let dx = x + hashN(Double(i) * 7.7 + 0.3) * w
            c.circ(dx + sin(g.clock + Double(i)) * 2, gy - done - k * 10, 1.4 + k * 2.8, Col(0xe2c08c, 0.42 * (1 - k)))
        }
    }

    private func racks() {
        let sh = g.sheriff, st = g.store
        // each rack takes one coin at a time: an empty slot hangs over it while you are near
        for bl in [sh, st, g.stable] where bl.level > 0 && !bl.building && abs(g.px - g.rackX(bl)) < 46 && vis(g.rackX(bl), 12) {
            let n = g.rackN[bl.type] ?? 0
            for k in 0..<3 {
                let x = sx(g.rackX(bl)) + Double(k - 1) * 6
                if k < n { coinAt(x, gy - 23) } else { c.ellStroke(x, gy - 23, 1.9, 1.9, 1.5, Col(0x2a1c14, 0.7)); c.ellStroke(x, gy - 23, 1.9, 1.9, 0.7, Col(0xf7d877)) }
            }
        }
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
        if !vis(cl.x, 70) { return }
        let x = sx(cl.x).rounded(), lv = cl.level
        c.ell(x + 8, gy + 0.6, 36, 1.8, Col(0x000000, 0.12))
        // the spoil heap, in bands, with loose rock at its foot
        c.poly(Col(0xa8855a), [x - 12, gy, x - 2, gy - 12, x + 10, gy - 16, x + 18, gy - 12, x + 28, gy])
        c.poly(Col(0x8a6a44), [x + 10, gy - 16, x + 18, gy - 12, x + 28, gy, x + 12, gy])
        c.seg(x - 6, gy - 5, x + 8, gy - 8, 0.6, Col(0x6a4e30, 0.6)); c.seg(x - 2, gy - 9.6, x + 9, gy - 12, 0.6, Col(0xc9a86a, 0.6))
        for k in 0..<5 { c.RR(x - 10 + hashN(Double(k) * 2.9) * 34, gy - 2, 3, 2.2, 1, Col(k % 2 == 0 ? 0x8a8478 : 0x76706a)) }
        c.R(x + 34, gy - 14, 1.5, 14, Col(0x5a3c22)); c.RR(x + 27, gy - 19, 16, 7.5, 1, lv > 0 ? Col(0xead7a4) : Col(0x9a8a70))
        c.text("CLAIM", x + 35, gy - 13.6, 4.2, Col(0x4a2a22), fit: 14)
        if lv >= 1 {
            // a timbered mouth with a lantern, a windlass turning over it, and a sluice running off
            c.R(x + 8, gy - 13, 14, 13, Col(0x14100c))
            c.R(x + 7, gy - 14, 2, 14, Col(0x5a3c22)); c.R(x + 21, gy - 14, 2, 14, Col(0x5a3c22)); c.R(x + 6, gy - 16, 18, 2.4, Col(0x6a4a2e)); c.R(x + 6, gy - 16, 18, 0.6, Col(0x9a744a))
            c.circ(x + 19, gy - 10, 1.2, Col(0xffd27a)); c.glow(x + 19, gy - 10, 6, Col(0xffd27a, 0.4), Col(0xffd27a, 0))
            let an = g.clock * 1.5
            c.R(x + 14.6, gy - 15, 0.8, 9, Col(0x2e2622)); c.circ(x + 15, gy - 18.4, 2.2, Col(0x4a3424)); c.seg(x + 15, gy - 18.4, x + 15 + cos(an) * 3.4, gy - 18.4 + sin(an) * 3.4, 0.7, Col(0x9a744a))
            c.poly(Col(0x7a5632), [x - 4, gy - 6, x - 22, gy - 2, x - 22, gy, x - 4, gy - 4]); c.poly(Col(0x9fc8dc, 0.8), [x - 5, gy - 5.6, x - 21, gy - 2, x - 21, gy - 1.2, x - 5, gy - 4.6])
            c.R(x - 14, gy - 3, 1, 3, Col(0x4a3424)); c.R(x - 6, gy - 4, 1, 4, Col(0x4a3424))
            for k in 0..<3 { let u = (g.clock * 0.9 + Double(k) / 3).truncatingRemainder(dividingBy: 1); c.R(x - 5 - u * 16, gy - 5.4 + u * 3.6, 1.2, 0.5, Col(0xffffff, 0.7)) }
            if g.dark() < 0.6 { person(cl.x + 4, 0, 1, false, 3, .miner, true) }
        }
        if lv >= 2 {
            // the hired gun's post: a lamp on a pole, a crate to sit on
            c.R(x - 34, gy - 18, 1.5, 18, Col(0x5a3c22)); c.R(x - 38, gy - 20, 10, 2, Col(0x6a4a2e)); c.circ(x - 30, gy - 16.6, 1.1, Col(0xffd27a))
            c.R(x - 44, gy - 5, 6, 5, Col(0x7a5632)); c.R(x - 44, gy - 5, 6, 0.7, Col(0x9a744a))
            person(cl.x - 30, 0, -1, false, 8, .deputy, false)
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
        if !vis(wx, 26) { return }
        let x = sx(wx)
        let kind = Int(seed) % 3
        let body = kind == 0 ? Col(0x3a2e28) : (kind == 1 ? Col(0x8a4a2c) : Col(0xa8623a))
        let lo = Col.mix(body, Col(0x000000), 0.32), hi = Col.mix(body, Col(0xffffff), 0.16), cream = Col(0xe8dcc4), hoof = Col(0x1c1410)
        let sw = sin(phase) * 1.3
        // pasture cattle have their heads down at the grass much of the time; the tail keeps the flies off
        let graze = !horns && sin(g.clock * 0.35 + seed * 1.7) > 0.25
        let tail = sin(g.clock * 2.6 + seed) * 2
        c.save(); c.translate(x, gy); c.scale(dir * s, s)
        c.roundCaps(true)
        c.ell(0, 0.8, 11, 1.6, Col(0x000000, 0.18))
        // a leg hinged at the knee: it swings forward lifted, and pushes back planted; the four go in turn
        func leg(_ hx: Double, _ off: Double, _ col: Col, _ w: Double) {
            let a = phase + off
            let fx = hx + sin(a) * 2.3, lift = max(0, cos(a)) * 1.2, fy = -0.9 - lift
            let kx = (hx + fx) / 2 + 0.5 + lift * 0.5, ky = -3.5 - lift * 0.3
            c.seg(hx, -6.6, kx, ky, w, col); c.seg(kx, ky, fx, fy, w - 0.3, col)
            c.R(fx - 1.1, fy - 0.1, 2.3, 1, hoof); c.R(fx, fy - 0.1, 0.3, 1, Col(0x4a3a30))
        }
        leg(-4.8, PI, lo, 1.6); leg(5.4, PI * 1.5, lo, 1.6)
        c.curve(-9, -13, -11.5, -10, -10.5 + tail * 0.5, -5, 0.8, lo); c.ell(-10.5 + tail * 0.5, -4.2, 0.9, 1.5, hoof)
        // a deep barrel, the hip and the shoulder, light along the back and shade under the belly
        c.RR(-9, -14, 17.5, 9, 3, body)
        c.circ(-6.4, -10.6, 3.6, body); c.circ(6, -10.4, 3.9, body)
        c.poly(body, [3, -14, 7, -15.2, 9.5, -13, 8, -8])
        c.RR(-7, -14, 12, 1.1, 0.5, hi.alpha(0.7))
        c.vfill(-8.4, -8.4, 16.4, 3.2, [(0, lo.alpha(0)), (1, lo.alpha(0.7))])
        c.R(-8.4, -13.6, 1, 2.4, lo.alpha(0.5))
        c.curve(4.4, -13.4, 7.4, -10.6, 5, -7.2, 0.6, lo.alpha(0.5))
        if kind == 1 { c.RR(-4, -13.4, 5, 4, 1.5, cream.alpha(0.9)); c.circ(3.4, -9.6, 1.6, cream.alpha(0.9)) }
        if kind == 2 { c.RR(-1, -7.6, 7, 2, 1, cream.alpha(0.85)) }
        if !horns && s > 0.8 { c.RR(-4.6, -5.8, 3.4, 2.2, 1, Col(0xe8a8a0)); c.R(-4, -3.8, 0.6, 0.9, Col(0xd08a84)); c.R(-2.6, -3.8, 0.6, 0.9, Col(0xd08a84)) }
        leg(-6.6, 0, body, 2); leg(6.8, PI / 2, body, 2)
        // neck, dewlap and head
        let hx = 11.2, hy = graze ? -4.8 + sin(g.clock * 5 + seed) * 0.4 : -14.0
        c.seg(7.6, -11.6, hx - 1, hy + 0.6, 4.2, body)
        c.curve(8, -9, 9.5, graze ? -6 : -9.5, hx - 0.5, hy + 2.4, 1, lo.alpha(0.6))
        c.RR(hx - 2.6, hy - 2.4, 5.6, 4.8, 1.6, body)
        let mz = graze ? 1.0 : 0.0
        c.RR(hx + 1.6, hy - 1 + mz, 3, 3, 1.2, kind == 0 ? Col(0x5a4a44) : Col(0xd8b8a0))
        c.R(hx + 3.4, hy + 0.4 + mz, 0.6, 0.6, Col(0x14100e))
        c.R(hx - 0.2, hy - 1.2, 0.9, 0.9, Col(0x14100e)); c.R(hx - 0.2, hy - 1.2, 0.4, 0.4, Col(0xffffff, 0.7))
        c.poly(lo, [hx - 2.6, hy - 1.6, hx - 5, hy - 2.6, hx - 2.4, hy - 0.2])
        if kind != 0 { c.R(hx + 0.5, hy - 2.4, 1.3, 3.2, cream.alpha(0.85)) }
        if horns {
            c.curve(hx - 1.6, hy - 2.2, hx - 5, hy - 6, hx - 8.5, hy - 5.4, 1.1, cream); c.curve(hx + 1, hy - 2.2, hx + 4.6, hy - 6, hx + 8, hy - 5.4, 1.1, cream)
            c.R(hx - 9, hy - 6, 1, 1, Col(0x3a2e28)); c.R(hx + 7.6, hy - 6, 1, 1, Col(0x3a2e28))
        } else {
            c.R(hx - 1.8, hy - 3.4, 1, 1.4, cream); c.R(hx + 0.6, hy - 3.4, 1, 1.4, cream)
        }
        c.roundCaps(false)
        c.restore()
    }

    /// The old mission west of town and the rock arch east of it, where wanted men hole up and road agents wait.
    private func landmarks() {
        let L = g.terrain
        if vis(g.missionX, 50) {
            let x = sx(g.missionX).rounded()
            let adobe = Col(0xd9c2a0), sh = Col(0xb39a78), tile = Col(0xb0563a), dkw = Col(0x3a2a1c)
            c.ell(x - 4, gy + 1.2, 36, 2.4, Col(0x000000, 0.16))
            // the nave: weathered adobe, a curved gable with a round window, a tiled roof edge and beam ends
            c.R(x - 28, gy - 22, 34, 22, adobe); c.R(x + 2, gy - 22, 4, 22, sh)
            c.vfill(x - 28, gy - 8, 34, 8, [(0, Col(0x8a6a4a, 0)), (1, Col(0x8a6a4a, 0.35))])
            c.poly(adobe, [x - 28, gy - 22, x - 24, gy - 27, x - 17, gy - 29, x - 11, gy - 33, x - 5, gy - 29, x + 2, gy - 27, x + 6, gy - 22])
            c.R(x - 29, gy - 22.6, 36, 1.4, tile)
            for k in 0..<9 { c.R(x - 28 + Double(k) * 4, gy - 22.6, 0.6, 1.4, Col(0x7a3424)) }
            c.circ(x - 11, gy - 27.5, 2.2, dkw); c.circ(x - 11, gy - 27.5, 1.4, Col(0x6a8aa0))
            for k in 0..<5 { c.R(x - 25 + Double(k) * 6.4, gy - 19.4, 1.6, 1.2, Col(0x6a4a2e)) }
            // an arched door of planks, and a narrow arched window
            c.R(x - 15, gy - 11, 8, 11, dkw); c.circ(x - 11, gy - 11, 4, dkw); c.R(x - 11.3, gy - 14, 0.6, 14, Col(0x5a3c22)); c.R(x - 9.6, gy - 6, 1, 1, Col(0xd8b860))
            c.R(x - 4, gy - 16, 3.4, 5, dkw); c.circ(x - 2.3, gy - 16, 1.7, dkw)
            // the bell tower: two arched openings, a bell in the upper one, a tiled cap and a wooden cross
            c.R(x + 6, gy - 40, 14, 40, adobe); c.R(x + 17, gy - 40, 3, 40, sh); c.R(x + 5, gy - 27, 16, 1, sh)
            for (oy, hung) in [(gy - 37.0, true), (gy - 24.0, false)] {
                c.R(x + 9.5, oy, 6, 7, dkw); c.circ(x + 12.5, oy, 3, dkw)
                if hung { c.poly(Col(0xc9a14a), [x + 10.6, oy + 5.5, x + 11.6, oy + 0.5, x + 13.4, oy + 0.5, x + 14.4, oy + 5.5]); c.R(x + 12.1, oy + 5.5, 0.8, 1, Col(0x8a6a2a)) }
            }
            c.poly(tile, [x + 4.5, gy - 40, x + 13, gy - 47, x + 21.5, gy - 40]); c.poly(Col(0x7a3424), [x + 13, gy - 47, x + 21.5, gy - 40, x + 14, gy - 40])
            c.R(x + 12.4, gy - 54, 1.2, 7.5, Col(0x5a3c22)); c.R(x + 10.4, gy - 52, 5.2, 1.2, Col(0x5a3c22))
            // cracks, a fallen corner, the yard wall and two grave markers
            c.seg(x - 22, gy - 20, x - 20, gy - 14, 0.5, sh); c.seg(x - 20, gy - 14, x - 21.5, gy - 10, 0.5, sh); c.seg(x + 9, gy - 18, x + 11, gy - 12, 0.5, sh)
            c.poly(sh, [x - 36, gy, x - 32, gy - 9, x - 28, gy - 6, x - 28, gy])
            c.R(x + 22, gy - 6, 16, 6, adobe); c.R(x + 22, gy - 6.8, 16, 1, sh); c.R(x + 30, gy - 6, 3, 6, dkw.alpha(0.5))
            for gx3 in [x + 42.0, x + 48] { c.R(gx3, gy - 6, 0.9, 6, Col(0x6a5a48)); c.R(gx3 - 1.4, gy - 4.6, 3.7, 0.9, Col(0x6a5a48)) }
        }
        if vis(g.archX, 60) {
            let x = sx(g.archX).rounded()
            let rock = Col(L.mesa), rs = Col(L.mesaS)
            c.poly(rock, [x - 34, gy, x - 30, gy - 30, x - 22, gy - 44, x + 8, gy - 48, x + 26, gy - 40, x + 32, gy - 18, x + 34, gy, x + 20, gy, x + 18, gy - 20, x + 6, gy - 30, x - 10, gy - 28, x - 18, gy - 14, x - 20, gy])
            c.poly(rs, [x + 8, gy - 48, x + 26, gy - 40, x + 32, gy - 18, x + 34, gy, x + 20, gy, x + 18, gy - 20, x + 14, gy - 34])
            c.R(x - 24, gy - 36, 26, 1, rs.alpha(0.5)); c.R(x - 28, gy - 22, 8, 1, rs.alpha(0.5))
            // more of the rock's banding, light on the crown, fallen boulders and scrub at the foot
            c.R(x - 30, gy - 29, 12, 0.8, rs.alpha(0.5)); c.R(x - 27, gy - 12, 8, 0.8, rs.alpha(0.4)); c.R(x + 22, gy - 28, 9, 0.8, Col(0x000000, 0.14)); c.R(x + 21, gy - 12, 12, 0.8, Col(0x000000, 0.14))
            c.R(x - 18, gy - 45.4, 24, 1, Col(0xffffff, 0.16))
            c.ell(x, gy + 1, 40, 2, Col(0x000000, 0.14))
            for (bx3, br) in [(x - 41.0, 3.6), (x + 41.0, 4.4), (x + 48.0, 2.6), (x - 2.0, 2.2)] { c.ell(bx3, gy - br * 0.7, br, br * 0.8, rock); c.ell(bx3 + br * 0.3, gy - br * 0.5, br * 0.6, br * 0.5, rs) }
            for k in 0..<4 { let wx0 = x - 46 + Double(k) * 3; c.seg(wx0, gy, wx0 - 1 + sin(g.clock * 1.4 + Double(k)) * 0.6, gy - 5, 0.7, Col(0x6a7040)) }
            if g.bio == .snow { c.poly(Col(0xf4f8ff), [x - 22, gy - 44, x + 8, gy - 48, x + 26, gy - 40, x + 10, gy - 44, x - 18, gy - 41]) }
        }
    }

    /// The windmill and the water tower, which stand behind the street.
    private func towers() {
        let st = Col(0x5a4a3a), dkw = Col(0x3a2a1c)
        if vis(992, 40) {
            let x = sx(992).rounded()
            let steel = Col(0x6a5a48), steelL = Col(0x9a8a72), steelD = Col(0x3a2e24)
            c.ell(x, gy + 1.2, 12, 1.8, Col(0x000000, 0.16))
            // a tapering lattice tower: far legs in shadow, near legs lit, girts and crossed braces, stone footings
            c.seg(x - 3, gy, x - 0.8, gy - 62, 0.9, steelD); c.seg(x + 3, gy, x + 0.8, gy - 62, 0.9, steelD)
            c.seg(x - 8, gy, x - 1.6, gy - 62, 1.5, steel); c.seg(x + 8, gy, x + 1.6, gy - 62, 1.5, steel)
            c.seg(x - 8.5, gy, x - 2.1, gy - 62, 0.5, steelL)
            var k = 0.0
            while k < 5 {
                let yy = gy - 8 - k * 11, hw = 7.2 - k * 1.15, hw2 = 7.2 - (k + 1) * 1.15
                c.seg(x - hw, yy, x + hw, yy, 0.9, steel)
                c.seg(x - hw, yy, x + hw2, yy - 11, 0.6, steel); c.seg(x + hw, yy, x - hw2, yy - 11, 0.6, steelD)
                k += 1
            }
            c.RR(x - 9.6, gy - 1.4, 3.2, 2, 0.8, Col(0x8a8478)); c.RR(x + 6.4, gy - 1.4, 3.2, 2, 0.8, Col(0x8a8478))
            // the pump rod working up and down, and the pump at the foot
            let a = g.clock * (g.wx == 0 ? 1.2 : 4)
            c.R(x - 0.3, gy - 60 + sin(a) * 1.5, 0.6, 56, Col(0x2e2a2c))
            c.R(x - 1.5, gy - 6, 3, 6, Col(0x4a4a52)); c.R(x - 1.5, gy - 6, 1, 6, Col(0x7a7a86)); c.seg(x + 1.5, gy - 4.4, x + 4.5, gy - 3.4, 1, Col(0x4a4a52))
            c.R(x - 4, gy - 55, 8, 1, steelD)
            // the tail vane and the fan: a ring of blades, alternately light and shaded
            c.seg(x, gy - 64, x - 13, gy - 64, 0.8, steelD)
            c.poly(Col(0xb5412e), [x - 9, gy - 64, x - 17, gy - 69, x - 17, gy - 59]); c.poly(Col(0x8a2f22), [x - 9, gy - 64, x - 17, gy - 64, x - 17, gy - 59])
            for i in 0..<12 {
                let an = a + Double(i) * PI / 6
                let c0 = cos(an), s0 = sin(an), c1 = cos(an + 0.32), s1 = sin(an + 0.32)
                c.poly(Col(i % 2 == 0 ? 0xc9c2b4 : 0xa39c8e), [x + c0 * 3, gy - 64 + s0 * 3, x + c0 * 10.5, gy - 64 + s0 * 10.5, x + c1 * 10.5, gy - 64 + s1 * 10.5])
            }
            c.ellStroke(x, gy - 64, 10.5, 10.5, 0.6, Col(0x8a8478)); c.ellStroke(x, gy - 64, 5.5, 5.5, 0.5, Col(0x8a8478))
            c.circ(x, gy - 64, 1.8, dkw); c.circ(x - 0.4, gy - 64.4, 0.7, steelL)
            if g.rodsLv > 0 { c.R(x - 0.5, gy - 82, 1, 10, Col(0x4a4a52)); c.R(x - 1, gy - 83, 2, 2, Col(0xd0d4dc)) }
        }
        if vis(1206, 40) {
            let x = sx(1206).rounded()
            let post = Col(0x5e4630), postL = Col(0x86684a), postD = Col(0x33251a), iron = Col(0x2e2a2c)
            c.ell(x + 2, gy + 1.4, 17, 2.4, Col(0x000000, 0.18))
            // the far legs and their braces, in shadow
            for dx in [-5.0, 5] { c.R(x + dx - 0.8, gy - 45, 1.6, 45, postD) }
            c.seg(x - 5, gy - 6, x + 5, gy - 24, 0.7, postD); c.seg(x + 5, gy - 6, x - 5, gy - 24, 0.7, postD)
            // the near legs, splayed a little and lit from the left, on stone footings
            for (dx, top) in [(-11.0, -9.0), (11.0, 9.0)] {
                c.poly(post, [x + dx - 1.3, gy, x + dx + 1.3, gy, x + top + 1.1, gy - 46, x + top - 1.1, gy - 46])
                c.seg(x + dx - 0.9, gy, x + top - 0.8, gy - 46, 0.6, postL)
                c.RR(x + dx - 2.6, gy - 1.6, 5.2, 2.4, 1, Col(0x8a8478))
            }
            for yy in [gy - 14.0, gy - 30] { c.R(x - 10.6, yy, 21.2, 1.5, post); c.R(x - 10.6, yy, 21.2, 0.5, postL) }
            c.seg(x - 10.4, gy - 14, x + 10, gy - 29, 0.9, post); c.seg(x + 10.4, gy - 14, x - 10, gy - 29, 0.9, post)
            c.seg(x - 10, gy - 30.5, x + 9.4, gy - 45, 0.8, post); c.seg(x + 10, gy - 30.5, x - 9.4, gy - 45, 0.8, post)
            // a ladder up the side
            c.R(x - 17, gy - 50, 0.7, 50, postD); c.R(x - 14, gy - 50, 0.7, 50, postD)
            var ly = gy - 3.0
            while ly > gy - 50 { c.R(x - 17, ly, 3.7, 0.6, postD); ly -= 3.4 }
            // the deck and its joists
            c.R(x - 16, gy - 48.4, 32, 2.4, post); c.R(x - 16, gy - 48.4, 32, 0.7, postL); c.R(x - 16, gy - 46.2, 32, 0.6, postD)
            var jx = -14.0
            while jx <= 14 { c.R(x + jx, gy - 46, 1.2, 1.6, postD); jx += 4.6 }
            // the tank: staves each a little different, rounded by the light, damp at the foot, bound in iron
            let ty = gy - 69.0, th = 20.6
            c.R(x - 13, ty, 26, th, Col(0x8a6a4a))
            var sv = -13.0, si = 0
            while sv < 13 {
                let r = hashN(Double(si) * 3.7 + 1.2)
                if r > 0.6 { c.R(x + sv, ty, 2.1, th, Col(0xffffff, 0.07)) } else if r < 0.25 { c.R(x + sv, ty, 2.1, th, Col(0x000000, 0.1)) }
                c.R(x + sv + 2.1, ty, 0.5, th, Col(0x3a2a1c, 0.55))
                sv += 2.6; si += 1
            }
            c.linear(x - 13, ty, 26, th, x - 13, 0, x + 13, 0, [(0, Col(0x000000, 0.22)), (0.22, Col(0xfff0d0, 0.2)), (0.5, Col(0x000000, 0)), (1, Col(0x000000, 0.42))])
            c.vfill(x - 13, ty + th - 7, 26, 7, [(0, Col(0x1e2a1c, 0)), (1, Col(0x1e2a1c, 0.4))])
            for k in 0..<4 { c.vfill(x - 10 + hashN(Double(k) * 5.1) * 20, ty + 3 + hashN(Double(k)) * 5, 1.2, 9, [(0, Col(0x2a1c14, 0.3)), (1, Col(0x2a1c14, 0))]) }
            for hy in [ty + 3.0, ty + 10, ty + 17] { c.R(x - 13.4, hy, 26.8, 1.3, iron); c.R(x - 9, hy, 6, 0.4, Col(0x8a868c)); c.R(x - 0.6, hy - 0.4, 1.6, 2.1, iron) }
            // a shingled cone of a roof, its shadow on the tank, and a finial
            c.R(x - 13, ty, 26, 1.6, Col(0x000000, 0.3))
            c.poly(Col(0x4a3424), [x - 15.5, ty, x, ty - 10.5, x + 15.5, ty])
            c.poly(Col(0x6a4c30), [x - 15.5, ty, x, ty - 10.5, x - 3, ty])
            for k in 1..<4 { let u = Double(k) / 4; c.seg(x - 15.5 * u, ty - 10.5 * (1 - u), x + 15.5 * u, ty - 10.5 * (1 - u), 0.5, Col(0x2a1c14, 0.6)) }
            c.R(x - 0.5, ty - 13.5, 1, 3.4, iron); c.circ(x, ty - 14, 1, iron)
            // the spout, its rope and weight, and a slow drip into a dark patch
            c.seg(x + 13, gy - 51, x + 22, gy - 43, 1.8, postD); c.seg(x + 13, gy - 51.6, x + 22, gy - 43.6, 0.6, postL)
            c.seg(x + 21, gy - 44, x + 15, gy - 58, 0.5, Col(0xc9a468)); c.R(x + 23.3, gy - 43, 0.5, 6, Col(0xc9a468)); c.R(x + 22.4, gy - 37, 2.2, 3, iron)
            let dr = (g.clock * 0.7).truncatingRemainder(dividingBy: 1)
            c.R(x + 21.6, gy - 42 + dr * dr * 40, 0.8, 1.6, Col(0x9fd0e4, 0.8 * (1 - dr)))
            c.ell(x + 22, gy + 0.6, 3.5, 0.9, Col(0x4a3a2a, 0.35))
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
        // what it is taking stands where it stood until the beam has it, in its own coat
        if u.ph < 2 {
            // it shrinks away as it nears the top of the beam
            let ax = sx(u.cow?.x ?? u.stray?.x ?? u.x), shr = 1 - clampD((u.lift - 0.55) / 0.45, 0, 1) * 0.88
            c.save(); c.translate(ax, gy - u.lift * 58); c.scale(shr, shr); c.translate(-ax, -gy); c.alpha(1 - u.lift * 0.5)
            if let cw = u.cow { cowAt(cw.x, cw.dir, cw.calf ? 0.6 : 1, cw.seed, 0, horns: false) }
            if let w = u.stray { cowAt(w.x, w.dir, 1, w.seed, 0, horns: true) }
            if let m = u.mustang {
                let coats: [(UInt32, UInt32)] = [(0x9a5a34, 0x4a2a18), (0xc9a36a, 0x8a6a40), (0x8a8480, 0x4a4642), (0x3a3230, 0x1c1816)]
                let ct = coats[Int(m.seed) % 4]
                _ = horse(sx(m.x), m.dir, u.lift > 0 ? g.clock * 3 : 0, u.lift > 0 ? 20 : 0, Col(ct.0), Col(ct.1))
            }
            c.alpha(1); c.restore()
            c.blend(.plusLighter); c.ell(hx, gy + 2, 30 + beam * 8, 4, Col(0x8cf7b0, 0.08 + 0.14 * beam)); c.blend(.normal)
        }
        if beam > 0 {
            c.poly(Col(0xb8ffd0, 0.16 * beam), [x - 7, y + 4, x + 7, y + 4, x + 24, gy, x - 24, gy])
            c.poly(Col(0xb8ffd0, 0.2 * beam), [x - 5, y + 4, x + 5, y + 4, x + 17, gy, x - 17, gy])
            c.poly(Col(0xe8fff0, 0.2 * beam), [x - 2.5, y + 4, x + 2.5, y + 4, x + 9, gy, x - 9, gy])
            // rings climbing the beam, and motes caught in it
            for k in 0..<5 {
                let f = (g.clock * 0.9 + Double(k) / 5).truncatingRemainder(dividingBy: 1)
                let yy = gy - f * (gy - y - 6), hw = 5 + 12 * (1 - f)
                c.ellStroke(x, yy, hw, hw * 0.16, 0.6, Col(0xe8fff0, 0.4 * beam * (1 - f * 0.6)))
            }
            for k in 0..<12 {
                let f = (g.clock * (0.5 + hashN(Double(k)) * 0.5) + hashN(Double(k) * 3.3)).truncatingRemainder(dividingBy: 1)
                c.R(x + (hashN(Double(k) * 7.1) - 0.5) * 26 * (1 - f * 0.6), gy - f * (gy - y - 8), 1, 1, Col(0xffffff, 0.7 * beam * (1 - f)))
            }
        }
        c.save(); c.translate(x, y); c.rotate(sin(g.clock * 2.2) * 0.05)
        c.glow(0, 0, 42, Col(0x8cf7b0, 0.28), Col(0x8cf7b0, 0))
        // a dark belly with a ring that brightens when the beam is on
        c.ell(0, 2.6, 11, 3, Col(0x343c4a)); c.ell(0, 3.2, 6.4, 1.8, Col(0xb8ffd0, 0.5 + 0.45 * beam)); c.ell(0, 3.2, 3, 0.9, Col(0xffffff, 0.3 + 0.6 * beam))
        // the dome, with someone looking out
        c.ell(0, -4.4, 7.6, 5, Col(0x7ad8b8, 0.55))
        c.ell(0, -3.6, 2.2, 2.8, Col(0x16241e, 0.85)); c.ell(0, -6, 2.7, 2, Col(0x16241e, 0.85))
        c.R(-1.7, -6.3, 1.2, 0.7, Col(0xd8fff0)); c.R(0.5, -6.3, 1.2, 0.7, Col(0xd8fff0))
        c.ell(-2.6, -6.8, 2.6, 1.4, Col(0xffffff, 0.45))
        c.R(-0.2, -11.4, 0.4, 2.2, Col(0x98a2b2)); c.circ(0, -11.8, 0.9, Int(g.clock * 3) % 2 == 0 ? Col(0xff6a5a) : Col(0x7a2a22))
        // the hull: a lens of brushed metal, lit along the top and shadowed beneath
        c.ell(0, 0, 19, 4.8, Col(0x566070)); c.ell(0, -0.8, 18.4, 3.8, Col(0x98a2b2)); c.ell(0, -1.6, 16, 2.5, Col(0xc8d0dc)); c.ell(-4, -2.5, 8, 0.9, Col(0xffffff, 0.5))
        c.R(-18.6, -0.2, 37.2, 0.5, Col(0x343c4a, 0.7))
        for k in -3...3 { c.R(Double(k) * 5 - 0.2, -3.3 + abs(Double(k)) * 0.4, 0.4, 3, Col(0x343c4a, 0.35)) }
        // running lights chasing round the rim
        for i in 0..<9 {
            let lx = -16 + Double(i) * 4, ly = 1.5 - lx * lx / 256 * 1.3
            let on = (Int(g.clock * 8) + i) % 3 == 0
            if on { c.glow(lx, ly, 3.6, Col(0xfff0a0, 0.55), Col(0xfff0a0, 0)) }
            c.circ(lx, ly, 1, on ? Col(0xfff0a0) : Col(0xc04a3e))
        }
        c.restore()
    }

    /// The places out of town: trading post, scout camp, ghost town, oil derrick, the medicine show and the cavalry outpost.
    private func sites(_ dk: Double) {
        let wood = Col(0x7a5632), dkw = Col(0x4a3424), canvasC = Col(0xd8c8a0)
        if vis(-90, 70) {
            let x0 = sx(-90).rounded()
            c.save(); c.translate(x0, gy); c.scale(1.7, 1.7); c.translate(-x0, -gy)
            defer { c.restore() }
            let x = x0 - 3
            let log = Col(0x8a6238), logD = Col(0x5a3c22), logL = Col(0xa87a48)
            _ = wood
            c.ell(x, gy + 1, 26, 1.8, Col(0x000000, 0.16))
            // a stone chimney, smoking
            c.R(x + 11, gy - 34, 6, 16, Col(0x8a8478)); c.R(x + 10.4, gy - 35, 7.2, 1.4, Col(0x6a665e))
            for k in 0..<4 { c.R(x + 11 + Double(k % 2) * 3, gy - 33 + Double(k) * 3.6, 3, 0.5, Col(0x5a564e)) }
            for i in 0..<4 {
                let k = (g.clock * 0.25 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1)
                c.circ(x + 14 + k * 7 + sin(g.clock + Double(i)) * 1.2, gy - 37 - k * 13, 1.4 + k * 3, Col(0xe8e2dc, 0.3 * (1 - k)))
            }
            // walls of stacked logs, their ends showing at the corners
            c.R(x - 18, gy - 20, 36, 20, log)
            var yy = gy - 20.0
            while yy < gy {
                c.R(x - 18, yy, 36, 0.6, logL); c.R(x - 18, yy + 3.2, 36, 0.8, logD)
                c.circ(x - 18.4, yy + 2, 1.7, logD); c.circ(x - 18.4, yy + 2, 0.9, logL); c.circ(x + 18.4, yy + 2, 1.7, logD); c.circ(x + 18.4, yy + 2, 0.9, logL)
                yy += 4
            }
            c.R(x + 12, gy - 20, 6, 20, Col(0x000000, 0.12))
            // a shingled roof with a deep eave
            c.poly(Col(0x4a3424), [x - 23, gy - 19, x, gy - 31, x + 23, gy - 19]); c.poly(Col(0x6a4a2e), [x - 23, gy - 19, x, gy - 31, x - 3, gy - 19])
            for k in 1..<4 { let u = Double(k) / 4; c.seg(x - 23 * u, gy - 31 + 12 * u, x + 23 * u, gy - 31 + 12 * u, 0.4, Col(0x2a1c14, 0.6)) }
            // a plank door with antlers over it, and a window of goods
            c.R(x - 4.5, gy - 13, 9, 13, Col(0x3a2a1c)); c.R(x - 3.6, gy - 12, 7.2, 12, Col(0x5a3c22)); c.R(x - 0.2, gy - 12, 0.4, 12, Col(0x3a2a1c)); c.R(x + 2, gy - 6.5, 0.9, 0.9, Col(0xd8b860))
            c.curve(x - 4, gy - 16.5, x - 2.5, gy - 14, x, gy - 14.5, 0.7, Col(0xe8dcc4)); c.curve(x + 4, gy - 16.5, x + 2.5, gy - 14, x, gy - 14.5, 0.7, Col(0xe8dcc4))
            c.R(x - 15.6, gy - 14.6, 9.2, 7.2, logD); c.R(x - 15, gy - 14, 8, 6, dk > 0.3 ? Col(0xffd98a) : Col(0x9fc4d4)); c.R(x - 11.2, gy - 14, 0.5, 6, logD)
            c.R(x - 14.4, gy - 10.4, 2, 2.4, Col(0xb5412e)); c.R(x - 10, gy - 10.8, 2.2, 2.8, Col(0x3f6f9a))
            // an awning on a post with pelts hanging from it, and a lantern by the door
            c.poly(Col(0xb5412e), [x + 5, gy - 16, x + 23, gy - 12.5, x + 23, gy - 11, x + 5, gy - 14.5]); c.poly(Col(0xead7a4), [x + 11, gy - 14.8, x + 17, gy - 13.6, x + 17, gy - 12.2, x + 11, gy - 13.4])
            c.R(x + 21, gy - 11.5, 1.2, 11.5, dkw)
            for (px0, pelt) in [(x + 8.0, Col(0x8a5a34)), (x + 12.0, Col(0xb9a27a)), (x + 16.0, Col(0x5a4636))] {
                c.R(px0, gy - 13.4, 0.4, 1.8, dkw); c.poly(pelt, [px0 - 1.4, gy - 11.6, px0 + 1.8, gy - 11.6, px0 + 1.2, gy - 7, px0 - 0.8, gy - 7])
            }
            c.R(x - 7.4, gy - 15.4, 1.6, 2.4, Col(0x2a1c14)); c.R(x - 7, gy - 14.9, 0.9, 1.5, Col(dk > 0.3 ? 0xffd27a : 0xcfc8a8))
            // goods out front: a barrel, crates, sacks, a wagon wheel against the wall
            c.RR(x + 8, gy - 6.5, 5, 6.5, 1.3, Col(0x7a5632)); c.R(x + 8, gy - 5, 5, 0.6, Col(0x3a2a1c)); c.R(x + 8, gy - 2.4, 5, 0.6, Col(0x3a2a1c))
            c.R(x + 14, gy - 5, 5.4, 5, Col(0x9a7a4a)); c.R(x + 14, gy - 5, 5.4, 0.7, Col(0x6a4a2e)); c.R(x + 15, gy - 9, 4, 4, Col(0x8a6a3a))
            c.RR(x - 24, gy - 4.6, 5, 4.6, 2, Col(0xd8c8a0)); c.RR(x - 21, gy - 4, 4.6, 4, 2, Col(0xc8b88e))
            c.ellStroke(x - 14.5, gy - 4, 3.6, 3.6, 0.8, Col(0x5a3c22)); c.seg(x - 18, gy - 4, x - 11, gy - 4, 0.5, Col(0x5a3c22)); c.seg(x - 14.5, gy - 7.5, x - 14.5, gy - 0.5, 0.5, Col(0x5a3c22))
            // the sign, swinging a little
            c.save(); c.translate(x, gy - 28.5); c.rotate(sin(g.clock * 1.4) * 0.03)
            c.R(-13, 0, 26, 5.6, Col(0xead7a4)); c.R(-13, 0, 26, 0.6, Col(0xfff4d8)); c.R(-13, 5, 26, 0.6, Col(0x8a6a3a))
            c.text("TRADING POST", 0, 4.2, 3.6, Col(0x4a2a22), fit: 24)
            c.restore()
        }
        if vis(-250, 70) {
            // the camp: two painted lodges with their poles showing, hides on a drying rack
            let x = sx(-250).rounded()
            c.save(); c.translate(x, gy); c.scale(1.35, 1.35); c.translate(-x, -gy)
            c.ell(x - 2, gy + 0.6, 34, 1.8, Col(0x000000, 0.14))
            let lodges: [(Double, Double, UInt32)] = [(-16, 24, 0xb5412e), (11, 20, 0x2f6a8a)]
            for (dx, hh, band) in lodges {
                let ax = x + dx
                for pd in [-3.0, 0, 3] { c.seg(ax + pd * 0.3, gy - hh + 1, ax - pd, gy - hh - 5, 0.6, dkw) }
                c.poly(canvasC, [ax - 10, gy, ax, gy - hh, ax + 10, gy]); c.poly(Col(0xb8a880), [ax, gy - hh, ax + 3, gy, ax + 10, gy])
                c.poly(Col(0x5a4a3a), [ax - 1.6, gy - hh + 4, ax, gy - hh, ax + 1.6, gy - hh + 4])
                c.poly(Col(0x3a2a1c), [ax - 2.6, gy, ax, gy - 9, ax + 2.6, gy])
                let by = gy - hh * 0.45
                c.R(ax - 5.4, by, 10.8, 1.4, Col(band))
                for j in 0..<5 { let zx = ax - 4.4 + Double(j) * 2.2; c.poly(Col(band), [zx - 1, by + 4.4, zx, by + 2.4, zx + 1, by + 4.4]) }
                c.circ(ax, gy - hh * 0.72, 1.3, Col(0xe8c84a))
                c.R(ax - 9.6, gy - 0.9, 1, 0.9, dkw); c.R(ax + 8.6, gy - 0.9, 1, 0.9, dkw)
            }
            c.R(x + 26, gy - 11, 0.9, 11, dkw); c.R(x + 37, gy - 11, 0.9, 11, dkw); c.R(x + 25.4, gy - 11.6, 13, 0.9, dkw)
            c.poly(Col(0xa8744a), [x + 28, gy - 10.6, x + 32, gy - 10.6, x + 31.4, gy - 4.6, x + 28.6, gy - 4.6]); c.poly(Col(0xc9a86a), [x + 33, gy - 10.6, x + 36.4, gy - 10.6, x + 35.8, gy - 5.6, x + 33.4, gy - 5.6])
            c.restore()
            campfire(-250 - 2, 0.6)
            if g.scoutDays > 0 { c.R(x + 54, gy - 30, 1.2, 30, dkw); c.poly(Col(0xc0392b), [x + 55, gy - 30, x + 63, gy - 27.5, x + 55, gy - 25]) }
        }
        if vis(-434, 80) {
            // the old bank: broken stone walls, the arched door, two stumps of column, the vault door where it fell
            let x = sx(-434).rounded()
            let stone = Col(0x8a7c6c), sh = Col(0x6a5e52), lt = Col(0xa89a88)
            c.ell(x, gy + 0.6, 40, 2, Col(0x000000, 0.14))
            let cols: [(Double, Double, Double)] = [(-34, 12, 32), (-22, 10, 26), (-12, 10, 30), (-2, 10, 21), (8, 10, 24), (18, 8, 15), (26, 8, 9)]
            for (i, cl) in cols.enumerated() {
                let (dx, w2, hh) = cl
                let cc = i % 2 == 0 ? stone : sh
                c.R(x + dx, gy - hh, w2, hh, cc)
                c.poly(cc, [x + dx, gy - hh, x + dx + w2 * 0.3, gy - hh - 2.5, x + dx + w2 * 0.6, gy - hh])
                var cy = gy - 4.0, row = 0
                while cy > gy - hh { c.R(x + dx, cy, w2, 0.5, Col(0x4a4038, 0.45)); c.R(x + dx + (row % 2 == 0 ? 3 : 7), cy, 0.5, 4, Col(0x4a4038, 0.45)); cy -= 4; row += 1 }
                c.R(x + dx, gy - hh, 0.8, hh, Col(0xffffff, 0.08))
            }
            c.R(x - 20, gy - 18, 9, 18, Col(0x1c1612)); c.dome(x - 15.5, gy - 18, 4.5, Col(0x1c1612))
            c.R(x - 33, gy - 29, 22, 5.4, lt); c.R(x - 33, gy - 29, 22, 0.7, Col(0xc8bca8)); c.text("BANK", x - 22, gy - 24.8, 4, Col(0x4a4038))
            c.R(x - 9, gy - 20, 6, 8, Col(0x1c1612))
            for k in 0..<3 { c.R(x - 8.4 + Double(k) * 2.2, gy - 20, 0.6, 8, Col(0x5a5a62)) }
            let stumps: [(Double, Double)] = [(x + 4, 14), (x + 13, 8)]
            for (cxx, ch) in stumps { c.R(cxx, gy - ch, 4, ch, lt); c.R(cxx - 0.8, gy - 1.6, 5.6, 1.6, lt); c.R(cxx - 0.6, gy - ch - 1, 5.2, 1.2, Col(0xc8bca8)); c.R(cxx + 1, gy - ch, 0.6, ch, Col(0x6a5e52, 0.6)) }
            c.ell(x + 27, gy - 2, 7, 2.4, Col(0x3a3a42)); c.ell(x + 27, gy - 2.6, 5.6, 1.8, Col(0x5a5a64)); c.circ(x + 27, gy - 2.6, 1.2, Col(0xc9a14a))
            for k in 0..<7 { c.RR(x - 30 + hashN(Double(k) * 3.7) * 62, gy - 2.2, 3 + hashN(Double(k)) * 2, 2.4, 1, k % 2 == 0 ? sh : stone) }
            for k in 0..<5 { let wxx = x - 28 + Double(k) * 13; c.seg(wxx, gy, wxx - 1.5, gy - 5, 0.6, Col(0x6a7a4a)); c.seg(wxx, gy, wxx + 1.6, gy - 4, 0.6, Col(0x6a7a4a)) }
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
                // a seep nobody has drilled: tar bubbling up, a painted board, survey stakes, a tipped barrel
                c.ell(x - 3, gy + 0.8, 6, 0.8, Col(0x8a7ab0, 0.35))
                for k in 0..<3 { let u = (g.clock * 0.5 + Double(k) * 0.33).truncatingRemainder(dividingBy: 1); c.circ(x - 8 + Double(k) * 8, gy + 0.4 - u * 1.5, 0.6 + u * 1.2, Col(0x3a3644, 1 - u)) }
                c.R(x - 9, gy - 13, 1.4, 13, dkw); c.RR(x - 16, gy - 19, 15, 7.5, 1, Col(0xead7a4)); c.R(x - 16, gy - 19, 15, 0.7, Col(0xfff4d8)); c.text("OIL", x - 8.5, gy - 13.4, 4.6, Col(0x2a1c14), face: "Rye-Regular")
                for sxx in [x - 24.0, x + 22] { c.R(sxx, gy - 8, 0.8, 8, dkw); c.poly(Col(0xc0392b), [sxx + 0.8, gy - 8, sxx + 4.5, gy - 6.6, sxx + 0.8, gy - 5.2]) }
                c.save(); c.translate(x + 13, gy - 3); c.rotate(0.25); c.RR(-5, -3, 10, 6, 1.5, Col(0x4a3f38)); c.R(-2.6, -3, 0.8, 6, Col(0x2a2622)); c.R(1.8, -3, 0.8, 6, Col(0x2a2622)); c.restore()
            }
        }
        if g.showOn && vis(752, 50) {
            let x = sx(752).rounded()
            c.RR(x - 16, gy - 24, 32, 17, 2, Col(0x7a2f6a)); c.R(x - 17, gy - 26, 34, 3, Col(0xf2c14e)); c.R(x - 14, gy - 21, 28, 8, Col(0xf4ecd6))
            c.text("TONIC", x, gy - 14.6, 5, Col(0x7a2f6a))
            for j in 0..<9 { c.poly(Col(0xf2c14e), [x - 17 + Double(j) * 3.8, gy - 23, x - 15.1 + Double(j) * 3.8, gy - 20.6, x - 13.2 + Double(j) * 3.8, gy - 23]) }
            c.R(x - 15, gy - 9.4, 30, 0.8, Col(0x4a1c40)); for j in 0..<6 { c.R(x - 13 + Double(j) * 4.6, gy - 12.6, 1.8, 3.2, Col(j % 2 == 0 ? 0x4f8a5a : 0xb5412e)) }
            c.circ(x - 19, gy - 20, 1.2, Col(0xffd27a)); c.glow(x - 19, gy - 20, 5, Col(0xffd27a, 0.4), Col(0xffd27a, 0))
            for wx in [x - 9, x + 9] { c.circ(wx, gy - 4.5, 4.5, dkw); c.circ(wx, gy - 4.5, 3, Col(0xc9a86a)); c.circ(wx, gy - 4.5, 0.9, dkw) }
            c.R(x + 20, gy - 12, 4, 7, Col(0x2e2622)); c.R(x + 20.3, gy - 15, 3.4, 3.2, Col(0xd9a878)); c.R(x + 19.6, gy - 19.6, 4.8, 4.6, Col(0x14100e)); c.R(x + 18.4, gy - 15.4, 7.2, 1, Col(0x14100e))
        }
        if vis(186, 60) {
            // the shooting gallery: a striped booth with pennants
            let x = sx(186).rounded()
            c.save(); c.translate(x, gy); c.scale(1.3, 1.3); c.translate(-x, -gy)
            c.ell(x, gy + 0.6, 26, 1.6, Col(0x000000, 0.14))
            c.R(x - 20, gy - 24, 40, 24, Col(0x5a2420)); c.R(x - 18, gy - 20, 36, 12, Col(0x1c0c0c))
            var k = 0.0, i = 0
            while k < 44 { c.poly(Col(i % 2 == 0 ? 0xb5412e : 0xf0e8d8), [x - 22 + k, gy - 24, x - 18 + k, gy - 24, x - 20 + k, gy - 20]); c.R(x - 22 + k, gy - 30, 4, 6, Col(i % 2 == 0 ? 0xb5412e : 0xf0e8d8)); k += 4; i += 1 }
            c.poly(Col(0x8a2f26), [x - 24, gy - 30, x, gy - 40, x + 24, gy - 30])
            c.R(x - 18, gy - 8, 36, 8, Col(0x7a5632)); c.R(x - 19, gy - 9, 38, 1.6, Col(0x9a7448))
            for j in 0..<3 { let tx2 = x - 12 + ((g.clock * 8 + Double(j) * 12).truncatingRemainder(dividingBy: 30)); c.circ(tx2, gy - 15, 2, Col(0xe8c84a)) }
            c.R(x - 0.6, gy - 47, 1.2, 8, Col(0x3a2a1c)); c.poly(Col(0xf2c14e), [x + 0.6, gy - 47, x + 8 + sin(g.clock * 4), gy - 45, x + 0.6, gy - 43])
            c.RR(x - 15, gy - 37, 30, 6, 1, Col(0xead7a4)); c.text("GALLERY", x, gy - 32.4, 4.6, Col(0x8a2f26), face: "Rye-Regular", fit: 27)
            for j in 0..<9 { c.circ(x - 20 + Double(j) * 5, gy - 25.6, 0.9, Col((j + Int(g.clock * 2)) % 2 == 0 ? 0xffe9a8 : 0xb5412e)) }
            c.R(x - 17, gy - 12, 34, 0.8, Col(0x3a2a1c)); c.R(x - 14, gy - 15.4, 2, 3.4, Col(0x4f8a5a)); c.R(x + 11, gy - 15, 3, 3, Col(0xc9a14a)); c.seg(x - 6, gy - 9, x + 4, gy - 10.6, 0.9, Col(0x3a3a40))
            c.R(x - 21, gy - 30, 1.4, 30, Col(0x3a2a1c)); c.R(x + 19.6, gy - 30, 1.4, 30, Col(0x3a2a1c))
            c.restore()
        }
        let fx = g.sFort.x
        if vis(fx, 70) && !g.lastTown {
            let x = sx(fx).rounded()
            c.save(); c.translate(x, gy); c.scale(1.35, 1.35); c.translate(-x, -gy)
            let lg = Col(0x8a6238), lgD = Col(0x5a3c22), lgL = Col(0xa87a48), blue = Col(0x2f4a7a)
            _ = (wood, dkw)
            c.ell(x, gy + 1, 40, 2, Col(0x000000, 0.16))
            // tents and a barracks roof showing over the wall
            c.poly(Col(0xe8dcc0), [x - 16, gy - 22, x - 10, gy - 30, x - 4, gy - 22]); c.poly(Col(0xc8b890), [x - 10, gy - 30, x - 4, gy - 22, x - 8, gy - 22])
            c.poly(Col(0x6a4a2e), [x + 2, gy - 22, x + 12, gy - 29, x + 22, gy - 22])
            // the palisade: pointed logs, every other one a little shorter, tied with two rails
            var k = -26.0, ki = 0
            while k < 26 {
                let drop = ki % 2 == 0 ? 0.0 : 1.5, lc = ki % 2 == 0 ? lg : Col(0x76522e)
                c.R(x + k, gy - 22 + drop, 3, 22 - drop, lc); c.R(x + k, gy - 22 + drop, 0.7, 22 - drop, lgL.alpha(0.7)); c.R(x + k + 2.4, gy - 22 + drop, 0.6, 22 - drop, lgD)
                c.poly(lc, [x + k, gy - 22 + drop, x + k + 1.5, gy - 26 + drop, x + k + 3, gy - 22 + drop])
                k += 3; ki += 1
            }
            c.R(x - 27, gy - 15, 54, 1.4, lgD); c.R(x - 27, gy - 7, 54, 1.4, lgD)
            // a blockhouse at each corner: overhanging top, firing slits, a shingled cap, a lamp after dark
            for sdx in [-35.0, 26.0] {
                c.R(x + sdx, gy - 34, 9, 34, lg); c.R(x + sdx + 6.4, gy - 34, 2.6, 34, Col(0x000000, 0.16))
                var ly = gy - 32.0
                while ly < gy { c.R(x + sdx, ly, 9, 0.6, lgD); ly += 4 }
                c.R(x + sdx - 1.5, gy - 36, 12, 2.4, lgD)
                c.R(x + sdx + 1.5, gy - 30, 2, 1, Col(0x1c1410)); c.R(x + sdx + 5.4, gy - 30, 2, 1, Col(0x1c1410))
                c.poly(Col(0x4a3424), [x + sdx - 2.5, gy - 36, x + sdx + 4.5, gy - 43, x + sdx + 11.5, gy - 36])
                c.R(x + sdx + 3.6, gy - 26, 1.6, 2.2, Col(dk > 0.3 ? 0xffd27a : 0x2a1c14))
            }
            // the gate: two leaves, braced and strapped with iron, under a painted board
            c.R(x - 8, gy - 19, 16, 19, Col(0x3a2a1c)); c.R(x - 7, gy - 18, 6.6, 18, Col(0x6a4a2e)); c.R(x + 0.4, gy - 18, 6.6, 18, Col(0x6a4a2e))
            c.seg(x - 7, gy - 18, x - 0.4, gy, 0.7, lgD); c.seg(x + 7, gy - 18, x + 0.4, gy, 0.7, lgD)
            c.R(x - 7, gy - 13, 14, 0.9, Col(0x2e2a2c)); c.R(x - 7, gy - 5, 14, 0.9, Col(0x2e2a2c))
            c.R(x - 11, gy - 24.5, 22, 4.6, Col(0xead7a4)); c.text("U.S. CAVALRY", x, gy - 21.2, 3, Col(0x27364a), fit: 20)
            // a sentry walking the wall with his rifle
            let sxp = x + sin(g.clock * 0.5) * 14, sdir = cos(g.clock * 0.5) > 0 ? 1.0 : -1.0
            c.R(sxp - 1.2, gy - 28.5, 2.4, 4, blue); c.R(sxp - 1, gy - 30.6, 2, 2.1, Col(0xd9a878)); c.R(sxp - 1.4, gy - 31.6, 2.8, 1.1, blue); c.R(sxp + sdir * 1.2, gy - 31, 1.2, 0.5, blue)
            c.seg(sxp + sdir * 1.4, gy - 25, sxp + sdir * 1.9, gy - 32.5, 0.5, Col(0x2a1c14))
            // the colours on a tall pole
            c.R(x + 15, gy - 52, 1.1, 26, lgD); c.circ(x + 15.5, gy - 52.4, 0.9, Col(0xf2c14e))
            let wv = sin(g.clock * 3) * 1.2
            c.poly(Col(0xb5412e), [x + 16.1, gy - 51.5, x + 29, gy - 50.5 + wv, x + 29, gy - 43.5 + wv, x + 16.1, gy - 44.5])
            for st in 0..<3 { let oy = Double(st) * 2; c.poly(Col(0xf4ecd6), [x + 16.1, gy - 50.3 + oy, x + 29, gy - 49.3 + wv + oy, x + 29, gy - 48.5 + wv + oy, x + 16.1, gy - 49.5 + oy]) }
            c.R(x + 16.1, gy - 51.5, 5.4, 3.6, blue)
            // a field gun by the gate, and rifles stacked
            c.ellStroke(x - 15, gy - 3, 3, 3, 0.8, lgD); c.seg(x - 18, gy - 3, x - 12, gy - 3, 0.5, lgD); c.seg(x - 15, gy - 6, x - 15, gy, 0.5, lgD)
            c.seg(x - 16, gy - 4, x - 9, gy - 6.4, 2, Col(0x2e2a2c)); c.seg(x - 17, gy - 3, x - 21, gy - 0.6, 0.9, lgD)
            c.seg(x + 12, gy, x + 14, gy - 7, 0.6, Col(0x2a1c14)); c.seg(x + 16, gy, x + 14, gy - 7, 0.6, Col(0x2a1c14)); c.seg(x + 14, gy - 0.4, x + 14, gy - 7, 0.6, Col(0x2a1c14))
            if g.fortNight { c.text("PATROL TONIGHT", x, gy - 57, 4, Col(0xf2c14e)) }
            c.restore()
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
        // shading, the door, curtains, a roof rail, the leather slings and a lamp
        c.R(x - 12, gy - 22, 24, 1, Col(0xffffff, 0.14)); c.vfill(x - 12, gy - 14, 24, 6, [(0, Col(0x000000, 0)), (1, Col(0x000000, 0.3))])
        c.R(x - 2.2, gy - 21, 0.5, 12, Col(0x4a1c16)); c.R(x + 4.6, gy - 21, 0.5, 12, Col(0x4a1c16))
        c.poly(Col(0x8a2f26, 0.9), [x - 8, gy - 20, x - 5.5, gy - 20, x - 8, gy - 16.5]); c.poly(Col(0x8a2f26, 0.9), [x + 4, gy - 20, x + 1.5, gy - 20, x + 4, gy - 16.5])
        c.R(x - 11, gy - 28.4, 18, 0.6, gold); c.R(x - 11, gy - 28.4, 0.6, 4, gold); c.R(x + 6.4, gy - 28.4, 0.6, 4, gold)
        c.curve(x - 10, gy - 8, x, gy - 5.5, x + 11, gy - 8, 1, Col(0x4a3424))
        c.R(x + 7.4, gy - 18, 1.8, 2.6, dk); c.R(x + 7.8, gy - 17.5, 1, 1.5, Col(g.dark() > 0.3 ? 0xffd27a : 0xd8dcc8))
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
        let cx = W / 2, y = 60.0, half = 70.0        // below the line of instructions, not behind it
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
            // a well in the square: a stone ring, a shingled roof on two posts, a windlass, a rope and a bucket
            c.ell(cx, gy + 0.6, 12, 1.6, Col(0x000000, 0.16))
            c.RR(cx - 7, gy - 7, 14, 7, 1.5, stone); c.R(cx - 8, gy - 8, 16, 1.6, dks)
            for k in 0..<4 { c.R(cx - 7 + Double(k) * 3.6, gy - 6 + Double(k % 2) * 3, 3.2, 0.5, dks) }
            c.R(cx - 6.4, gy - 18, 1.5, 10, Col(0x5a3c22)); c.R(cx + 4.9, gy - 18, 1.5, 10, Col(0x5a3c22))
            c.R(cx - 5, gy - 14, 10, 1, Col(0x3a2a1c)); c.R(cx + 5.6, gy - 15, 2.4, 0.8, Col(0x3a2a1c)); c.R(cx + 7.6, gy - 15, 0.8, 2.4, Col(0x3a2a1c))
            c.R(cx - 0.3, gy - 13.4, 0.6, 4, Col(0xc9a468)); c.R(cx - 1.6, gy - 10, 3.2, 2.6, Col(0x6a4a2e))
            c.poly(Col(0x6a3c20), [cx - 10, gy - 18, cx, gy - 24, cx + 10, gy - 18]); c.poly(Col(0x4a2a18), [cx, gy - 24, cx + 10, gy - 18, cx + 1, gy - 18])
        } else if hl.level >= 2 {
            // the clock tower: a stone base with a door, a clapboard shaft, the dial, an open belfry, a steep shingled cap and a vane
            let body = Col(0xc9b98a), bodyD = Col(0xa8966a), roofC = Col(0x6a3c20), gilt = hl.level >= 3
            c.ell(cx, gy + 0.8, 16, 2, Col(0x000000, 0.18))
            c.R(cx - 10, gy - 14, 20, 14, stone); c.R(cx - 10, gy - 14, 3, 14, Col(0xd8d2c4)); c.R(cx + 7, gy - 14, 3, 14, dks)
            for k in 0..<3 { c.R(cx - 10, gy - 4.6 - Double(k) * 4.6, 20, 0.5, dks) }
            c.R(cx - 3, gy - 10, 6, 10, Col(0x3a2a1c)); c.dome(cx, gy - 10, 3, Col(0x3a2a1c)); c.R(cx - 0.2, gy - 10, 0.4, 10, Col(0x5a3c22)); c.R(cx + 1.4, gy - 5, 0.8, 0.8, Col(0xd8b860))
            c.R(cx - 11, gy - 15.4, 22, 1.8, dks)
            c.R(cx - 8, gy - 46, 16, 31, body)
            var sy = gy - 44.0
            while sy < gy - 16 { c.R(cx - 8, sy, 16, 0.5, bodyD); sy += 3 }
            c.R(cx + 5, gy - 46, 3, 31, Col(0x000000, 0.14)); c.R(cx - 8, gy - 46, 1.4, 31, Col(0xffffff, 0.18))
            c.R(cx - 1.6, gy - 26, 3.2, 6, Col(0x3a2a1c)); c.R(cx - 2.2, gy - 20, 4.4, 0.8, bodyD)
            c.R(cx - 10, gy - 48, 20, 2.4, roofC)
            c.circ(cx, gy - 37, 6.6, Col(0x3a2a1c)); c.circ(cx, gy - 37, 5.7, gilt ? Col(0xf2c14e) : Col(0x8a8478)); c.circ(cx, gy - 37, 4.8, Col(0xf4ecd6))
            for k in 0..<12 { let an = Double(k) * PI / 6, sz = k % 3 == 0 ? 0.9 : 0.5; c.R(cx + cos(an) * 4 - sz / 2, gy - 37 + sin(an) * 4 - sz / 2, sz, sz, INK) }
            let a = g.t * PI * 4 - PI / 2
            c.seg(cx, gy - 37, cx + cos(a) * 3.6, gy - 37 + sin(a) * 3.6, 0.8, INK)
            c.seg(cx, gy - 37, cx + cos(a / 12) * 2.4, gy - 37 + sin(a / 12) * 2.4, 0.9, INK)
            c.circ(cx, gy - 37, 0.7, gilt ? Col(0xf2c14e) : INK)
            c.R(cx - 8, gy - 58, 16, 10, body); c.R(cx + 5, gy - 58, 3, 10, Col(0x000000, 0.14))
            for ox in [-3.4, 3.4] {
                c.R(cx + ox - 2, gy - 56, 4, 7, Col(0x2a1c14)); c.dome(cx + ox, gy - 56, 2, Col(0x2a1c14))
                if gilt {
                    let sw = sin(g.clock * 2.4 + ox) * 0.9
                    c.poly(Col(0xf2c14e), [cx + ox - 1.5 + sw, gy - 50.4, cx + ox - 0.8, gy - 54.4, cx + ox + 0.8, gy - 54.4, cx + ox + 1.5 + sw, gy - 50.4])
                }
            }
            c.R(cx - 10, gy - 60, 20, 2.2, roofC)
            c.poly(roofC, [cx - 10, gy - 60, cx, gy - 76, cx + 10, gy - 60]); c.poly(Col(0x000000, 0.2), [cx, gy - 76, cx + 10, gy - 60, cx + 1, gy - 60])
            for k in 1..<4 { let u = Double(k) / 4; c.R(cx - 10 * u, gy - 76 + 16 * u, 20 * u, 0.5, Col(0x000000, 0.25)) }
            c.R(cx - 0.4, gy - 82, 0.8, 6.4, Col(0x2a1c14)); c.circ(cx, gy - 76.4, 1, gilt ? Col(0xf2c14e) : Col(0x2a1c14))
            let wv = sin(g.clock * 0.7) > 0 ? 1.0 : -1.0
            c.poly(Col(0x2a1c14), [cx - wv * 4, gy - 81, cx + wv * 4.5, gy - 82.2, cx + wv * 4.5, gy - 79.8])
        }
        if hl.building { scaffold(x, 26, hl.level == 0 ? 18 : 78, hl.progress) }
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
        // boiler shine and rivets, cowcatcher slats, a bell, the side rods turning with the wheels
        c.R(7, -15.4, 22, 0.8, Col(0xffffff, 0.16)); c.R(6, -10, 24, 2, Col(0x000000, 0.25))
        for k in 0..<7 { c.R(8 + Double(k) * 3.2, -9.4, 0.6, 0.6, Col(0x6a6a76)) }
        for k in 0..<3 { c.seg(1 + Double(k) * 1.8, 0, 6, -6 + Double(k) * 1.6, 0.4, Col(0x15151a)) }
        c.RR(23, -22.6, 2.6, 2.2, 1, br); c.R(24, -20.6, 0.6, 1.2, dkc)
        let ra = tr.x / (4 * 1.3)
        c.seg(29 + cos(ra) * 2.2, -4 + sin(ra) * 2.2, 38 + cos(ra) * 2.2, -4 + sin(ra) * 2.2, 1, Col(0x9a9aa6))
        c.seg(14, -3.4, 29 + cos(ra) * 2.2, -4 + sin(ra) * 2.2, 0.8, Col(0x7a7a86))
        c.R(29, -24.6, 14, 0.7, Col(0x4a4a56)); c.R(30, -14, 12, 0.7, br); c.R(33, -21, 6, 0.6, Col(0x000000, 0.3))
        // coal heaped in the tender
        for k in 0..<6 { c.circ(48.5 + Double(k) * 2, -15.6 - hashN(Double(k) * 2.3) * 1.6, 1.2, Col(0x0c0c10)) }
        c.R(46, -15, 15, 1, Col(0x4a4a56)); c.R(46, -9, 15, 0.6, br)
        // the car: a raised roof with lights, framed windows, panel lines and trucks
        c.R(67, -25, 40, 2, dkc); c.R(68, -24.4, 38, 0.6, glass.alpha(0.6))
        for k in 0..<5 {
            let wx0 = 68 + Double(k) * 7.5
            c.R(wx0 - 0.5, -19.5, 6, 0.6, br); c.R(wx0 - 0.5, -14, 6, 0.6, br); c.R(wx0 + 2.2, -19, 0.5, 5, Col(0x4a1c16))
            if dk <= 0.3 { c.poly(Col(0xffffff, 0.3), [wx0, -19, wx0 + 2.4, -19, wx0, -16]) }
        }
        c.R(64, -10.5, 46, 0.5, Col(0x4a1c16)); c.R(64, -21, 46, 0.7, Col(0xffffff, 0.12)); c.R(64, -8, 46, 2, Col(0x000000, 0.2))
        c.R(66, -6, 12, 1.4, dkc); c.R(94, -6, 12, 1.4, dkc)
        // steam off the stack, and the headlamp's beam after dark
        for i in 0..<5 {
            let k = (g.clock * 0.5 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
            c.circ(10.5 + k * 16, -28 - k * 14, 1.6 + k * 4, Col(0xe8e2dc, 0.4 * (1 - k)))
        }
        if dk > 0.3 { c.blend(.plusLighter); c.poly(Col(0xffe58a, 0.18 * dk), [2, -18.5, -46, -26, -46, -2]); c.blend(.normal) }
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

    /// Crane's company yard past the east gate of the last town: a rail fence, his office, a wagon,
    /// the company arch, and his men, who run when the town comes for them.
    private func craneYard() {
        let yx = g.craneX
        if !vis(yx, 220) { return }
        let x = sx(yx).rounded(), wood = Col(0x5a4030), dk = Col(0x2e2218)
        c.ell(x, gy + 0.6, 86, 2.4, Col(0x000000, 0.12))
        // the office: dark planks, a tin roof, the company flag
        let ox = x + 30
        c.R(ox, gy - 30, 44, 30, Col(0x3e342e)); var pk = 0.0
        while pk < 44 { c.R(ox + pk, gy - 30, 0.6, 30, Col(0x2a221e)); pk += 5.5 }
        c.poly(Col(0x6a6e74), [ox - 4, gy - 30, ox + 22, gy - 41, ox + 48, gy - 30]); c.R(ox - 4, gy - 31, 52, 1.4, Col(0x8a8e94))
        c.R(ox + 17, gy - 14, 10, 14, Col(0x1c1612)); c.R(ox + 5, gy - 24, 8, 7, Col(0xd8a850, g.dark() > 0.4 ? 0.9 : 0.4)); c.R(ox + 31, gy - 24, 8, 7, Col(0xd8a850, g.dark() > 0.4 ? 0.9 : 0.4))
        c.RR(ox + 8, gy - 38.6, 28, 5, 0.6, Col(0x1c1612)); c.text("OFFICE", ox + 22, gy - 34.8, 3.8, Col(0xd8b860), fit: 26)
        c.R(ox + 46, gy - 54, 1.2, 54, dk)
        let wave = sin(g.clock * 3) * 1.4
        c.poly(Col(0x7a241c), [ox + 47.2, gy - 54, ox + 61, gy - 51 + wave, ox + 47.2, gy - 47]); c.text("C", ox + 52, gy - 49.4, 4, Col(0xead7a4), face: "Rye-Regular")
        // the wagon, loaded
        let wx = x - 76
        c.R(wx, gy - 12, 34, 7, Col(0x6a4a2e)); c.R(wx, gy - 12, 34, 1, Col(0x8a6238)); c.RR(wx + 2, gy - 19, 12, 7, 1, Col(0x8a7450)); c.RR(wx + 15, gy - 18, 10, 6, 1, Col(0x7a6448))
        for wcx in [wx + 6, wx + 28] { c.circ(wcx, gy - 4, 4, dk); c.circ(wcx, gy - 4, 3, Col(0x6a4a2e)); c.circ(wcx, gy - 4, 0.9, dk) }
        // rail fence round the pen
        var fx = x - 84.0
        while fx < x + 86 { c.R(fx, gy - 11, 1.4, 11, wood); fx += 14 }
        c.R(x - 84, gy - 9, 170, 1, wood); c.R(x - 84, gy - 5, 170, 1, wood)
        // the company arch over the road in, which comes down when the town arrives
        let ax = x - 20, tip = g.routT < 0 ? 0 : min(1.45, g.routT * g.routT * 1.6)
        c.R(ax - 26, gy - 34, 2.4, 34, dk)
        c.save(); c.translate(ax + 25, gy); c.rotate(-tip * 0.9); c.translate(-(ax + 25), -gy)
        c.R(ax + 24, gy - 34, 2.4, 34, dk)
        c.restore()
        c.save(); c.translate(ax - 25, gy - 33); c.rotate(tip)
        c.R(-1, -1.5, 52, 2.4, dk)
        c.RR(4, 1.5, 44, 8, 0.8, Col(0x7a241c)); c.R(4, 1.5, 44, 0.7, Col(0xa8483a))
        c.text("CRANE CATTLE & RAIL", 26, 7.4, 3.7, Col(0xead7a4), fit: 42)
        c.restore()
        for m in g.yardMen where m.x < g.craneX + 700 { bandit(m) }
    }

    private func gate(_ bl: Building) {
        if !vis(bl.x, 30) { return }
        let x = sx(bl.x).rounded(), lv = bl.level
        let wood = Col(0x7a5632), dkw = Col(0x4a3424)
        if lv == 0 {
            // the burned gate: a faint outline of the wall that stood here, two charred posts,
            // one leaf fallen flat, a heap of stones, and a board on a stake saying what it was
            var k = 0.0
            while k < 14 { c.R(x + k, gy - 16, 1.6, 16, Col(0xffffff, 0.12)); c.poly(Col(0xffffff, 0.12), [x + k, gy - 16, x + k + 0.8, gy - 18, x + k + 1.6, gy - 16]); k += 2 }
            c.R(x, gy - 14, 2.8, 14, Col(0x2e2622)); c.R(x + 11, gy - 10, 2.8, 10, Col(0x2e2622))
            c.poly(Col(0x2e2622), [x, gy - 14, x + 1.4, gy - 16.5, x + 2.8, gy - 14]); c.R(x + 0.4, gy - 14, 0.7, 14, Col(0x4a3f38))
            c.R(x + 11, gy - 10, 2.8, 1, Col(0x4a3f38)); c.circ(x + 12.4, gy - 11, 1.2, Col(0xff8a2a, 0.5 + 0.3 * sin(g.clock * 5 + x)))
            c.save(); c.translate(x + 2, gy - 1.4); c.rotate(-0.08)
            c.R(0, -1.6, 14, 3.2, Col(0x3a2c22)); c.R(2, -1.6, 0.6, 3.2, Col(0x1c1612)); c.R(6, -1.6, 0.6, 3.2, Col(0x1c1612)); c.R(10, -1.6, 0.6, 3.2, Col(0x1c1612))
            c.restore()
            c.RR(x + 4, gy - 2.6, 4, 2.8, 1, Col(0x8a8478)); c.RR(x + 7, gy - 1.8, 3.4, 2, 1, Col(0x76706a))
            let sxx = bl.type == .gateW ? x - 12 : x + 20
            c.R(sxx + 4.4, gy - 10, 1, 10, Col(0x4a3424)); c.RR(sxx, gy - 14, 10, 5, 0.8, Col(0xead7a4)); c.R(sxx, gy - 14, 10, 0.6, Col(0xfff4d8))
            c.text("GATE", sxx + 5, gy - 10.6, 3.2, Col(0x4a2a22), fit: 9)
            if bl.building { scaffold(x, 14, 16, bl.progress) }
            return
        }
        let h = [0.0, 16, 26, 36][min(lv, 3)]
        if lv == 1 {
            c.R(x + 1, gy - h, 2.4, h, dkw); c.R(x + 11, gy - h, 2.4, h, dkw)
            c.R(x + 1, gy - h, 0.8, h, Col(0x6a4a2e)); c.R(x + 11, gy - h, 0.8, h, Col(0x6a4a2e))
            c.R(x + 0.4, gy - h - 1.4, 3.6, 1.6, wood); c.R(x + 10.4, gy - h - 1.4, 3.6, 1.6, wood)
            c.seg(x, gy - 2, x + 14, gy - h + 2, 2, wood); c.seg(x + 14, gy - 2, x, gy - h + 2, 2, wood)
            c.R(x, gy - h * 0.55, 14, 2, wood); c.R(x, gy - h * 0.55, 14, 0.7, Col(0x9a744a))
            c.R(x + 6.4, gy - h * 0.55 + 0.6, 1, 1, Col(0x2e2622))
        } else {
            var k = 0.0
            while k < 14 {
                let tall = Int(k) % 4 == 0, top = gy - h + (tall ? 0 : 2)
                c.R(x + k, top, 2, h, tall ? wood : Col(0x664628)); c.R(x + k, top, 0.6, h, Col(0x9a744a, tall ? 0.8 : 0.4)); c.R(x + k + 1.5, top, 0.5, h, dkw)
                c.poly(tall ? wood : Col(0x664628), [x + k, top, x + k + 1, top - 3, x + k + 2, top])
                k += 2
            }
            // iron straps with rivets, and a footing of field stones
            for fy in [gy - h * 0.7, gy - h * 0.3] {
                c.R(x - 1, fy, 16, 2, Col(0x2e2a2c)); c.R(x - 1, fy, 16, 0.6, Col(0x5a565c))
                var rv = 0.0
                while rv < 16 { c.R(x - 0.4 + rv, fy + 0.8, 0.7, 0.7, Col(0x8a868c)); rv += 4 }
            }
            for st in 0..<4 { c.RR(x - 1.5 + Double(st) * 4.2, gy - 3, 4.6, 3.6, 1.2, Col(st % 2 == 0 ? 0x8a8478 : 0x76706a)); c.R(x - 0.8 + Double(st) * 4.2, gy - 2.8, 2.6, 0.6, Col(0xa8a294)) }
            if lv >= 3 {
                c.R(x - 4, gy - h - 12, 22, 3, dkw); c.R(x - 3, gy - h - 9, 2, 9, dkw); c.R(x + 15, gy - h - 9, 2, 9, dkw)
                c.R(x - 5, gy - h - 16, 24, 4, Col(0x6a3c20))
                // the Gatling gun on the roof, pointing out of town
                let gd = bl.type == .gateW ? -1.0 : 1.0
                c.R(x + 5, gy - h - 19, 4, 3, Col(0x4a4a50)); c.seg(x + 7, gy - h - 18, x + 7 + gd * 9, gy - h - 18, 1.6, Col(0x2e2622))
                for sh in 0..<6 { c.R(x - 5 + Double(sh) * 4, gy - h - 16, 3.4, 1.4, Col(0x7e4a28)) }
                // a pennant over the watch post
                let fw = sin(g.clock * 4 + bl.x) * 1.2
                c.R(x + 6.6 - gd * 7, gy - h - 26, 0.8, 10, dkw)
                c.poly(Col(0xb23a2e), [x + 7 - gd * 7, gy - h - 26, x + 7 - gd * 14, gy - h - 24 + fw, x + 7 - gd * 7, gy - h - 22])
            }
        }
        // a lantern on the town side, lit after dark
        let ls = bl.type == .gateW ? 1.0 : -1.0, lx = x + 7 + ls * 9
        c.seg(x + 7 + ls * 6, gy - h + 3, lx, gy - h + 3, 0.8, Col(0x2e2622))
        c.R(lx - 1.2, gy - h + 3.4, 2.4, 3.6, Col(0x2e2622)); c.R(lx - 0.6, gy - h + 4.1, 1.2, 2, Col(g.dark() > 0.3 ? 0xffd27a : 0x9a8a5a))
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
        c.save()
        defer { c.restore() }
        let k = Int(seed)
        // no two quite the same height or build
        c.translate(x, gy); c.scale(PSCALE * (0.95 + Double(k % 4) * 0.035), PSCALE * (0.93 + Double(k % 5) * 0.035)); c.translate(-x, -gy)
        let skin = SKIN[k % SKIN.count]
        var shirt = SHIRT[(k / 3) % SHIRT.count]
        var hat = HAT[(k / 5) % HAT.count]
        if ragged { shirt = Col.mix(shirt, Col(0x7a6a58), 0.6) }
        if role == .deputy { shirt = Col(0x34445a); hat = Col(0x2e2622) }
        if role == .miner { shirt = Col(0x7a7468); hat = Col(0xc9a86a) }
        if role == .rancher { shirt = Col(0xc9a468); hat = Col(0x6a4a2e) }
        let sw = moving ? sin(phase) * 2.2 : 0
        let bob = (work ? abs(sin(g.clock * 9 + seed)) * 1.5 : 0) * 0.3 + (moving ? abs(sin(phase)) * 0.5 : 0)
        let woman = k % 4 == 1 && role == .folk && !ragged
        let trousers = Col([0x3a3a4a, 0x4a3a2a, 0x2e3a4e, 0x5a4a3a][(k / 2) % 4] as UInt32)
        let boot = Col(0x2a1c14)
        c.ell(x, gy + 0.6, 4.4, 1, Col(0x000000, 0.2))
        if woman {
            // a long skirt that sways, an apron, a bonnet
            let hem = sw * 0.6
            c.poly(shirt, [x - 2.4, gy - 10 - bob, x + 2.6, gy - 10 - bob, x + 4 + hem, gy - 0.6, x - 3.8 + hem, gy - 0.6])
            c.R(x - 3.6 + hem, gy - 1.4, 7.4, 0.8, Col.mix(shirt, Col(0x000000), 0.3))
            c.poly(Col(0xf0e8d8, 0.9), [x - 1.2, gy - 8.6 - bob, x + 1.6, gy - 8.6 - bob, x + 2.2 + hem * 0.6, gy - 2.6, x - 1.8 + hem * 0.6, gy - 2.6])
            c.R(x - 2.4, gy - 12.2 - bob, 5, 3, shirt); c.R(x - 2.4, gy - 9.6 - bob, 5, 0.8, Col.mix(shirt, Col(0x000000), 0.35))
        } else {
            // legs that stride, boots, a belt
            // each leg bends at the knee: it comes forward lifted and goes back planted
            for (side, far) in [(1.0, true), (-1.0, false)] {
                let a = phase + (side > 0 ? PI : 0)
                let fwd = moving ? sin(a) * 2.5 : 0, lift = moving ? max(0, cos(a)) * 1.5 : 0
                let hxp = x + (side > 0 ? 0.9 : -0.7), fxp = hxp + fwd * dir, fyp = gy - 1 - lift
                let kxp = (hxp + fxp) / 2 + dir * (0.4 + lift * 0.7), kyp = gy - 3.4 - lift * 0.4
                let lc = far ? Col.mix(trousers, Col(0x000000), 0.25) : trousers
                c.seg(hxp, gy - 5.8, kxp, kyp, 1.9, lc); c.seg(kxp, kyp, fxp, fyp, 1.7, lc)
                c.R(fxp - 1.2 + dir * 0.5, fyp - 0.4, 2.8, 1.4, boot); c.R(fxp - 1.2 + dir * 0.5, fyp + 0.6, 2.8, 0.4, Col(0x14100e))
            }
            if role == .rancher { c.seg(x - 0.8, gy - 5.6, x - 0.8 + sw, gy - 1.6, 2.6, Col(0x8a6238, 0.9)) }
            c.R(x - 2.5, gy - 11.6 - bob, 5.2, 6.2, shirt)
            c.R(x + 1.4, gy - 11.6 - bob, 1.3, 6.2, Col.mix(shirt, Col(0x000000), 0.22))
            c.R(x - 2.5, gy - 6.4 - bob, 5.2, 1, Col(0x2a1c14)); c.R(x - 0.4, gy - 6.5 - bob, 1.2, 1.2, Col(0xd8b860))
            if role == .deputy || k % 3 == 0 { c.R(x - 2.5, gy - 11.6 - bob, 1.5, 5.2, Col(0x2e2622, 0.8)); c.R(x + 1.2, gy - 11.6 - bob, 1.5, 5.2, Col(0x2e2622, 0.8)) }       // a vest
            if role == .miner { c.R(x - 1.6, gy - 11.6 - bob, 0.8, 5.2, Col(0x4a3424)); c.R(x + 1, gy - 11.6 - bob, 0.8, 5.2, Col(0x4a3424)) }                                   // braces
        }
        // arms: one swings as he walks, the other works or hangs
        let sleeve = Col.mix(shirt, Col(0x000000), 0.12)
        if work {
            let a = sin(g.clock * 9 + seed)
            c.seg(x + dir * 1.8, gy - 10.4 - bob, x + dir * 6, gy - 11.4 - a * 3 - bob, 1.5, sleeve)
            c.circ(x + dir * 6, gy - 11.4 - a * 3 - bob, 0.9, skin)
            c.seg(x + dir * 6, gy - 11.4 - a * 3 - bob, x + dir * 8.4, gy - 15 - a * 3 - bob, 0.9, Col(0x6a4a2e)); c.R(x + dir * 8.4 - 1.4, gy - 16.4 - a * 3 - bob, 2.8, 1.6, Col(0x8a8a90))
        } else {
            c.seg(x + dir * 2.2, gy - 10.6 - bob, x + dir * 2.6 - sw * 0.5, gy - 6.6 - bob, 1.4, sleeve); c.circ(x + dir * 2.6 - sw * 0.5, gy - 6.2 - bob, 0.8, skin)
        }
        c.seg(x - dir * 2.2, gy - 10.6 - bob, x - dir * 2.6 + sw * 0.5, gy - 6.6 - bob, 1.4, Col.mix(sleeve, Col(0x000000), 0.15))
        // head: a neck, a face with a nose, hair at the back, an eye, sometimes a beard or a neckerchief
        c.R(x - 0.9, gy - 12 - bob, 1.9, 0.9, Col.mix(skin, Col(0x000000), 0.22))
        c.RR(x - 1.7, gy - 15.2 - bob, 3.8, 3.8, 0.9, skin)
        c.R(x + dir * 2 - 0.35, gy - 13.7 - bob, 0.7, 0.9, Col.mix(skin, Col(0x000000), 0.15))
        c.R(x - dir * 1.5 - 0.5, gy - 14.8 - bob, 1, 2.4, Col([0x2a1c14, 0x6a4a2e, 0x9a8a7a, 0x1c1410][k % 4] as UInt32))
        c.R(x - 2.5, gy - 11.6 - bob, 5.2, 0.7, Col(0xffffff, 0.12))
        c.R(x + dir * 0.9 - 0.3, gy - 13.9 - bob, 0.7, 0.8, Col(0x1c120c))
        if !woman && k % 5 == 2 { c.R(x - 1.7, gy - 12.6 - bob, 3.8, 1.4, Col(k % 2 == 0 ? 0x4a3424 : 0xb9b2a4)) }
        if !woman && k % 3 == 1 { c.R(x - 2, gy - 11.9 - bob, 4.4, 1.1, Col(0xb5412e)) }
        if woman {
            c.RR(x - 2.4, gy - 16.6 - bob, 5.2, 3, 1.4, hat); c.R(x - dir * 2.6 - 0.6, gy - 15.4 - bob, 1.6, 3.4, hat); c.R(x - 2.4, gy - 14.4 - bob, 5.2, 0.6, Col(0xf0e8d8))
        } else if k % 7 == 3 && role == .folk {
            // a bowler
            c.RR(x - 2.2, gy - 17.4 - bob, 4.8, 2.8, 1.4, hat); c.R(x - 3, gy - 15.4 - bob, 6.4, 0.9, hat)
        } else {
            c.RR(x - 3.9, gy - 15.9 - bob, 8.2, 1.2, 0.6, hat); c.RR(x - 2.1, gy - 18 - bob, 4.6, 2.6, 0.9, hat)
            c.R(x - 2.1, gy - 16.4 - bob, 4.6, 0.6, Col.mix(hat, Col(0x000000), 0.4))
        }
        // the small things: a collar and buttons, a brow and a mouth, a crease in the hat, a bun and a shawl
        if woman {
            c.circ(x - dir * 2.3, gy - 13.2 - bob, 1.1, Col([0x2a1c14, 0x6a4a2e, 0x9a8a7a, 0x1c1410][k % 4] as UInt32))
            c.poly(Col.mix(shirt, Col(0xffffff), 0.3), [x - 2.6, gy - 12 - bob, x + 2.8, gy - 12 - bob, x + 0.1, gy - 8.8 - bob])
        } else {
            c.R(x - 1.5, gy - 11.9 - bob, 3.2, 0.7, Col.mix(shirt, Col(0xffffff), 0.32))
            c.R(x + dir * 0.4 - 0.3, gy - 10.4 - bob, 0.6, 0.6, Col(0xf0e6d2, 0.85)); c.R(x + dir * 0.4 - 0.3, gy - 8.8 - bob, 0.6, 0.6, Col(0xf0e6d2, 0.85))
            if k % 5 != 2 { c.R(x + dir * 1 - 0.5, gy - 12.3 - bob, 1, 0.35, Col(0x7a3a2a)) }
            if !(k % 7 == 3 && role == .folk) { c.R(x - 0.3, gy - 18 - bob, 0.7, 1.4, Col.mix(hat, Col(0x000000), 0.3)) }
        }
        c.R(x + dir * 0.8 - 0.5, gy - 14.6 - bob, 1.1, 0.35, Col(0x3a2a1c))
        if role == .deputy { star(x - dir * 0.8, gy - 9.4 - bob, 1.5, GOLD); c.R(x + dir * 2.4, gy - 6.4 - bob, 1.4, 2.6, Col(0x2a1c14)) }
        if role == .miner { c.seg(x - dir * 2.4, gy - 13, x - dir * 4.2, gy - 3, 0.9, Col(0x8a6a4a)); c.poly(Col(0x8a8a90), [x - dir * 4.6, gy - 13.8, x - dir * 1, gy - 13, x - dir * 4, gy - 12]) }
        if role == .rancher { c.ellStroke(x - dir * 2.6, gy - 7 - bob, 1.6, 1.9, 0.6, Col(0xc9a468)) }
    }

    /// A horse in profile, facing `dir`: jointed legs that walk or gallop, a mane and tail that stream at speed, a head that nods at rest.
    private func horse(_ x: Double, _ dir: Double, _ phase: Double, _ speed: Double, _ coat: Col, _ dark: Col, tack: Bool = false) -> Double {
        let mv = speed > 4, gal = speed > 55
        // a gallop is one long bound a stride, not a quick patter: slower legs, more reach, a rocking back
        let ph = gal ? phase * 1.15 : phase * 2
        let bob = gal ? sin(ph + 0.9) * 1.6 : (mv ? sin(ph * 2) * 0.45 : 0)
        let lite = Col.mix(coat, Col(0xffffff), 0.16), shade = Col.mix(coat, dark, 0.55)
        let hoof = Col(0x1c1410)
        c.save()
        c.translate(x, gy)
        c.scale(dir, 1)
        c.roundCaps(true)
        // one leg: hip, a knee that bends forward as the foot lifts, cannon bone, hoof
        func leg(_ hx: Double, _ off: Double, _ far: Bool, _ fore: Bool) {
            let a = ph + off
            let up = mv ? (gal ? pow(max(0, sin(a)), 0.8) * 5.6 : max(0, sin(a)) * 2.2) : 0
            let stride = mv ? (gal ? (fore ? 9.5 : 8.2) : 3.2) : 0
            let hy = -9.5 - HLIFT + bob
            let fx = hx - cos(a) * stride, fy = -1 - up
            let kx = (hx + fx) / 2 + (fore ? 1 : -1) * (0.7 + up * (gal ? 0.95 : 0.75)), ky = (hy + fy) / 2 - (fore ? 0 : 0.6)
            let col = far ? dark : shade
            c.seg(hx, hy, kx, ky, 2.5, col)
            c.seg(kx, ky, fx, fy, 1.6, col)
            c.circ(kx, ky, 1.25, col)                                  // knee or hock
            c.circ(fx + 0.2, fy - 1.3, 1.05, col)                      // fetlock
            c.R(fx - 1, fy - 0.2, 2.6, 1.3, hoof); c.R(fx - 0.8, fy - 0.2, 1, 0.5, Col(0x5a4a40))
            if !far && tack { c.R(fx - 0.8, fy - 2.2, 2.2, 1.2, Col(0xf0e6d2)) }      // white socks
        }
        // hind feet land almost together, then the fore feet, then all four are off the ground
        let offs: [Double] = gal ? [0, 2.6, 0.6, 3.2] : [PI, PI * 1.5, 0, PI * 0.5]
        leg(-7.5, offs[2], true, false); leg(7, offs[3], true, true)
        c.translate(0, -HLIFT)       // everything from here up is the body, carried on longer legs
        if gal { c.translate(0, -14); c.rotate(sin(ph + 2.2) * 0.07); c.translate(0, 14) }
        // tail: strands that hang at rest and stream out at a gallop
        let tx = -11.0, ty = -15 + bob
        for k in 0..<5 {
            let wv = sin(g.clock * (gal ? 17 : 3) + Double(k) * 1.3 + x * 0.05) * (gal ? 1.4 : 0.5)
            let ex = tx - (gal ? 9.5 : (mv ? 4.5 : 2.6)) - Double(k - 2) * 0.4
            let ey = ty + (gal ? 1.5 : (mv ? 6 : 9)) + Double(k) * 0.8 + wv
            c.curve(tx + 0.5, ty + Double(k) * 0.4, tx - (gal ? 4 : 1.2), ty + (gal ? -1 : 3) + Double(k) * 0.4, ex, ey, 1.1, k % 2 == 0 ? dark : shade)
        }
        // barrel, quarters and chest
        c.RR(-11, -17.5 + bob, 22.5, 9.4, 4.5, coat)
        c.circ(-6.8, -12.9 + bob, 4.9, coat); c.circ(7.6, -12.8 + bob, 4.7, coat)
        c.RR(-8, -9.4 + bob, 15, 1.8, 0.9, shade.alpha(0.55))
        c.RR(-6, -17 + bob, 12, 1.1, 0.5, lite.alpha(0.8))
        c.curve(-10.5, -13 + bob, -8, -9 + bob, -4.5, -8.4 + bob, 0.7, shade.alpha(0.6))
        // muscle and light: the shoulder, the stifle, a sheen on the quarters, faint dapples, the girth of the belly
        c.curve(5.4, -16.6 + bob, 9.6, -13 + bob, 6.2, -9.4 + bob, 0.7, shade.alpha(0.55))
        c.curve(-3.6, -15.6 + bob, -6.2, -12.4 + bob, -3.8, -9.2 + bob, 0.6, shade.alpha(0.4))
        c.ell(-7.4, -14.8 + bob, 2.7, 1.6, lite.alpha(0.42)); c.ell(7.4, -14.6 + bob, 2, 1.3, lite.alpha(0.32))
        for k in 0..<5 { c.circ(-8.2 + Double(k) * 2.5, -13.4 + bob + hashN(Double(k) * 3.1 + coat.r * 9) * 2.6, 0.7, lite.alpha(0.2)) }
        c.vfill(-9, -10.4 + bob, 17, 2.4, [(0, dark.alpha(0)), (1, dark.alpha(0.35))])
        c.translate(0, HLIFT); leg(-5, offs[0], false, false); leg(4.2, offs[1], false, true); c.translate(0, -HLIFT)
        // neck and head, which dips now and then when he stands
        let nk = sin(g.clock * 0.55 + x * 0.01)
        let nod = !mv && nk > 0.5 ? (nk > 0.86 ? 2.2 : 1.1) : (gal ? sin(ph * 2 + 1) * 0.7 : 0)
        let hy = bob + nod
        c.poly(coat, [4.5, -16.8 + bob, 11.5, -25 + hy, 16.6, -23.4 + hy, 13, -9.8 + bob, 8, -9.5 + bob])
        c.poly(shade.alpha(0.5), [11, -11 + bob, 15.6, -22.6 + hy, 16.6, -23.4 + hy, 13, -9.8 + bob])
        c.RR(12.4, -28 + hy, 9, 5.6, 2.2, coat)
        c.RR(18.2, -26.8 + hy, 5, 4.6, 2, shade)
        c.R(21.6, -24.2 + hy, 0.9, 0.9, hoof)                                    // nostril
        c.circ(14.4, -23.9 + hy, 2.3, coat); c.arcStroke(14.4, -23.9 + hy, 2.3, 0.2, 2.2, 0.6, shade.alpha(0.6))   // the round of the jaw
        c.seg(18.4, -22.4 + hy, 22.4, -22.8 + hy, 0.5, hoof.alpha(0.6))            // the line of the mouth
        c.seg(14.8, -26.7 + hy, 16.4, -26.5 + hy, 0.5, dark)                       // a lid over the eye
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
        c.translate(x, gy - HLIFT)
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
        // how much gallop is left, shown only while it is short
        if g.wind < 0.995 {
            c.RR(x - 8, gy - 48, 16, 3, 1.5, Col(0x24160f, 0.8))
            c.R(x - 7, gy - 47, 14 * g.wind, 1, g.blown ? Col(0xe0633c) : Col(0x8fd0e8))
        }
        // six rounds over his head while he reloads, filling as they go in
        if g.reloadT > 0 {
            let k = 1 - g.reloadT / max(0.1, g.reloadMax)
            c.RR(x - 8, gy - 55, 16, 6, 1.5, Col(0x2a1a10, 0.85))
            for i in 0..<6 { c.R(x - 6.5 + Double(i) * 2.3, gy - 54, 1.4, 4, Double(i) < k * 6 ? Col(0xf2c14e) : Col(0x5a4a3c)) }
        }
    }

    private func bandit(_ bn: Bandit) {
        if !vis(bn.x, 30) { return }
        let dir = bn.st == 3 ? bn.side : (bn.face != 0 ? bn.face : -bn.side)
        let x = sx(bn.x)
        let moving = bn.st == 0 || bn.st == 3
        c.save()
        defer { c.restore() }
        if !bn.rider { c.translate(x, gy); c.scale(PSCALE, PSCALE); c.translate(-x, -gy) }
        if bn.rider {
            _ = horse(x, dir, bn.phase, moving ? 74 : 0, Col(0x3a3230), Col(0x1c1816))
            let bob = moving ? sin(bn.phase * 2) * 0.8 : 0
            c.translate(0, -HLIFT)
            c.R(x - 3, gy - 25 + bob, 6, 9, Col(0x2e2622)); c.R(x - 1, gy - 16 + bob, 3, 7, Col(0x2a2a30))
            c.R(x - 2, gy - 29 + bob, 4.5, 4, Col(0xb8804e)); c.R(x - 2.5, gy - 27 + bob, 5.5, 2.4, Col(0xa02a22))
            c.R(x - 5, gy - 30 + bob, 11, 1.5, Col(0x14100e)); c.R(x - 2.5, gy - 33 + bob, 6, 3.2, Col(0x14100e))
            // a belt and bandolier, eyes in the hat's shadow, a hat band, the coat blowing back, a pistol out
            c.R(x - 3, gy - 20 + bob, 6, 1, Col(0x6a4a2e)); c.seg(x - 3, gy - 25 + bob, x + 3, gy - 18 + bob, 0.7, Col(0x6a4a2e))
            c.R(x - 2 + (dir > 0 ? 2.2 : 0.3), gy - 28.4 + bob, 1.6, 0.7, Col(0x14100e))
            c.R(x - 2.5, gy - 30.6 + bob, 6, 0.6, Col(0x8a2b22))
            c.poly(Col(0x241c18), [x - dir * 3, gy - 24 + bob, x - dir * (7 + sin(bn.phase) * 1.2), gy - 17 + bob, x - dir * 3, gy - 17 + bob])
            c.seg(x + dir * 1, gy - 23 + bob, x + dir * 6, gy - 21 + bob, 1.3, Col(0x2e2622)); c.seg(x + dir * 6, gy - 21.4 + bob, x + dir * 9, gy - 21.8 + bob, 0.9, Col(0x8a8a8a))
            c.translate(0, HLIFT)
        } else {
            let sw = moving ? sin(bn.phase) * 2 : 0
            c.R(x - 2 + sw * 0.5, gy - 5, 2, 5, Col(0x2a2a30)); c.R(x + 0.5 - sw * 0.5, gy - 5, 2, 5, Col(0x2a2a30))
            c.R(x - 2.5, gy - 11, 5, 6, Col(0x2e2622))
            c.R(x - 1.5, gy - 14, 3.5, 3.2, Col(0xb8804e)); c.R(x - 2, gy - 12.6, 4.5, 1.8, Col(0xa02a22))
            c.R(x - 3.5, gy - 15, 7.5, 1.2, Col(0x14100e)); c.R(x - 2, gy - 17, 4.5, 2.2, Col(0x14100e))
            c.R(x - 2.5, gy - 6.4, 5, 0.8, Col(0x6a4a2e)); c.R(x - 2, gy - 15.6, 4.5, 0.5, Col(0x8a2b22))
            c.R(x - 1.5 + (dir > 0 ? 1.8 : 0.2), gy - 13.6, 1.4, 0.6, Col(0x14100e))
            c.poly(Col(0x241c18), [x - dir * 2.5, gy - 10, x - dir * 4.4, gy - 4.5, x - dir * 2.5, gy - 5])
            c.R(x - 2.4 + sw * 0.5, gy - 1, 2.6, 1, Col(0x14100e)); c.R(x + 0.3 - sw * 0.5, gy - 1, 2.6, 1, Col(0x14100e))
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
        // now and then one catches the light
        let gl = sin(g.clock * 4 + x * 0.37 + y * 0.9)
        if gl > 0.9 { let k = (gl - 0.9) * 10; c.R(x - 0.8 - 2.2 * k, y - 1.2, 4.4 * k + 0.8, 0.6, Col(0xffffff, k)); c.R(x - 0.7, y - 1.2 - 2.2 * k, 0.6, 4.4 * k + 0.8, Col(0xffffff, k)) }
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
            c.seg(x, gy + s.y, x - sgn(s.vx) * 15, gy + s.y, 2.6, Col(0xffc860, 0.22))
            c.seg(x, gy + s.y, x - sgn(s.vx) * 9, gy + s.y, 1, Col(0xfff0b0, 0.9))
        }
        for p in g.parts {
            let a = clampD(p.life / p.max, 0, 1)
            c.R(sx(p.x) - p.s / 2, gy + p.y - p.s, p.s, p.s, p.c.alpha(p.c.a * a))
        }
    }

    /// A strip at the top of the picture: the whole country end to end, the town between its gates, you, and any raiders.
    private func radar() {
        if g.duel != nil || g.state != .play || !g.cut.isEmpty { return }
        let x0 = W * 0.655, w = W * 0.29, y = 27.0          // under the day and menu plates, clear of the top row
        func mx(_ wx: Double) -> Double { return x0 + clampD((wx - WEST) / (WORLD - WEST), 0, 1) * w }
        c.RR(x0 - 4, y - 5.5, w + 8, 11, 3.5, Col(0x2a1c14, 0.74))
        c.R(x0 - 2, y - 5.5, w + 4, 0.5, Col(0xc9a03c, 0.7)); c.R(x0 - 2, y + 5, w + 4, 0.5, Col(0xc9a03c, 0.35))
        c.R(x0, y + 2, w, 0.7, Col(0xead7a4, 0.45))
        let a = mx(g.gateW.x), b = mx(g.gateE.x)
        c.R(a, y - 0.4, b - a, 2.4, Col(0xead7a4, 0.3))
        for bl in g.b where bl.def.wall != 0 && !bl.def.gate && bl.level > 0 { c.R(mx(bl.cx) - 0.5, y - 1.6, 1, 3.6, Col(0xead7a4, 0.55)) }
        c.R(a - 0.4, y - 2.4, 0.9, 4.4, Col(g.gateW.level > 0 ? 0xc9a86a : 0x6a5a48)); c.R(b - 0.4, y - 2.4, 0.9, 4.4, Col(g.gateE.level > 0 ? 0xc9a86a : 0x6a5a48))
        c.R(mx(g.cam), y + 3.6, max(2, mx(g.cam + W) - mx(g.cam)), 0.6, Col(0xffffff, 0.55))
        let pulse = 0.65 + 0.35 * sin(g.clock * 7)
        for bn in g.bandits where bn.hp > 0 {
            let bx = mx(bn.x)
            c.circ(bx, y + 0.6, bn.boss ? 1.7 : 1.1, Col(0xff4a3a, pulse))
        }
        if let o = g.outlaw { c.R(mx(o.x) - 0.6, y - 1.2, 1.2, 2.6, Col(0xff9a3a)) }
        let px = mx(g.px)
        c.poly(GOLD, [px - 1.8, y - 4.2, px + 1.8, y - 4.2, px, y - 1.2])
    }

    /// The last touches over the whole scene: the colour of the hour, the sun in the lens, and things passing close to the eye.
    private func finish(_ dk: Double, _ dusk: Double) {
        // the hour tints everything: gold toward evening, blue before dawn
        if dusk > 0.02 { c.R(0, 0, W, H, Col(0xff7a2a, 0.11 * dusk * (1 - dk))) }
        if g.t < 0.12 { c.R(0, 0, W, H, Col(0x6a8ad0, 0.1 * (1 - g.t / 0.12))) }
        // by day the sun flares in the glass: a string of pale discs from it through the middle of the picture
        let u = (g.t - 0.02) / 0.74
        if u > 0 && u < 1 && dk < 0.3 && g.cloudI() < 0.3 && g.wx != 3 {
            let sxp = W * (0.08 + 0.84 * u), syp = gy - sin(u * PI) * gy * 0.82 + 6
            let ax = W / 2 - sxp, ay = H * 0.5 - syp
            let fl: [(Double, Double, UInt32, Double)] = [(0.45, 5, 0xffe0a0, 0.10), (0.8, 9, 0xa0d8ff, 0.07), (1.25, 4, 0xffc0a0, 0.10), (1.6, 13, 0xfff0c0, 0.05), (1.95, 6, 0xa0ffd0, 0.06)]
            c.blend(.plusLighter)
            for (fk, r, col, al) in fl { c.circ(sxp + ax * fk, syp + ay * fk, r, Col(col, al * (1 - dk / 0.3))) }
            c.blend(.normal)
        }
        // a dust squall: the air goes the colour of the ground, and streaks of grit cross the picture
        if g.gust > 0 {
            let k = sin(clampD(1 - g.gust / 7, 0, 1) * PI)
            c.R(0, 0, W, H, Col(g.terrain.dust, 0.36 * k))
            for i in 0..<46 {
                var x = (hashN(Double(i) * 5.3) * (W + 80) - g.clock * (190 + hashN(Double(i)) * 160)).truncatingRemainder(dividingBy: W + 80)
                if x < 0 { x += W + 80 }
                let y = hashN(Double(i) * 9.7) * H
                c.seg(x - 40, y, x - 40 + 14 + hashN(Double(i) * 2) * 22, y - 1.5, 0.8, Col(0xfff0d0, 0.3 * k))
            }
        }
        // cloud shadows drifting over the ground
        if dk < 0.5 {
            for i in 0..<2 {
                var x = (g.clock * (5 + Double(i) * 3) + Double(i) * 260 - g.cam * 0.9).truncatingRemainder(dividingBy: W + 260)
                if x < 0 { x += W + 260 }
                c.ell(x - 130, gy + 8 + Double(i) * 6, 90 + Double(i) * 30, 5, Col(0x000000, 0.07 * (1 - dk * 2)))
            }
        }
        // things close to the eye slide past faster than the street: fence posts, weeds, a cactus, dark and soft
        let near = Col.mix(Col(0x2a1c14), Col(0x05060c), dk)
        let off = g.cam * 1.5
        var k = floor(off / 150) - 1
        while k * 150 - off < W + 40 {
            let x = k * 150 - off + hashN(k * 3.7) * 90, r = hashN(k * 9.1)
            if r < 0.3 {
                c.R(x, H - 15, 3.4, 15, near.alpha(0.85)); c.R(x - 14, H - 11, 30, 2, near.alpha(0.85)); c.R(x - 14, H - 6, 30, 2, near.alpha(0.85)); c.R(x + 22, H - 13, 3, 13, near.alpha(0.85))
            } else if r < 0.6 {
                for j in 0..<5 { let bx2 = x + Double(j) * 3, sw = sin(g.clock * 1.6 + Double(j) + k) * 1.5; c.seg(bx2, H, bx2 + sw + Double(j - 2) * 1.5, H - 8 - hashN(k + Double(j)) * 7, 1.2, near.alpha(0.8)) }
            } else if r < 0.72 && (g.bio == .desert || g.bio == .canyon) {
                c.RR(x, H - 20, 5, 20, 2.5, near.alpha(0.85)); c.RR(x - 6, H - 14, 4, 8, 2, near.alpha(0.85)); c.R(x - 6, H - 8, 8, 3, near.alpha(0.85)); c.RR(x + 7, H - 17, 4, 9, 2, near.alpha(0.85)); c.R(x + 3, H - 10, 8, 3, near.alpha(0.85))
            }
            k += 1
        }
    }

    /// Things the wind carries: tumbleweeds over dry ground, and dust hanging in the daylight.
    private func drifting(_ dk: Double) {
        // dust devils: a leaning funnel of spinning dust, small or tall, with whatever it has picked up
        for d in g.devils where vis(d.x, 30) {
            let k = sin(min(1, d.t / d.life) * PI)
            let hgt = (d.big ? 52.0 : 24.0) * (0.4 + 0.6 * k), x0 = sx(d.x)
            let n = d.big ? 14 : 9
            for j in 0..<n {
                let u = Double(j) / Double(n - 1)
                let y = gy - u * hgt
                let sway = sin(g.clock * 2.2 + u * 3 + d.x * 0.05) * (2 + u * (d.big ? 7 : 4))
                let rw = (d.big ? 3.0 : 2.0) + u * u * (d.big ? 11 : 6)
                let spin = sin(g.clock * 9 + Double(j) * 1.3) * rw * 0.35
                c.ell(x0 + sway + spin, y, rw, 1.3 + u * 1.2, Col(g.terrain.dust, (0.36 - u * 0.2) * k))
                c.ellStroke(x0 + sway - spin, y, rw * 0.8, 1 + u, 0.5, Col(0xffffff, 0.1 * k))
            }
            for j in 0..<(d.big ? 10 : 5) {
                let a = g.clock * (5 + Double(j % 3)) + Double(j) * 2.1, u = hashN(Double(j) * 3.3 + 0.2)
                let rw = 3 + u * (d.big ? 12 : 6)
                c.R(x0 + cos(a) * rw + sin(g.clock * 2.2 + u * 3 + d.x * 0.05) * (2 + u * 5), gy - u * hgt + sin(a) * 1.5, 1, 1, Col(0x5a4a38, 0.7 * k))
            }
            c.ell(x0, gy + 0.6, d.big ? 9 : 5, 1.4, Col(g.terrain.dust, 0.4 * k))
        }
        if (g.bio == .desert || g.bio == .canyon) && !g.flooded {
            for i in 0..<2 {
                let sp = 26.0 + Double(i) * 11 + (g.storm ? 45 : 0)
                let span = W + 520 + Double(i) * 260
                let tt = g.clock * sp + Double(i) * 370
                var x = (tt + g.cam).truncatingRemainder(dividingBy: span)
                if x < 0 { x += span }
                x = span - x - 60
                if x > W + 20 || x < -20 { continue }
                let hop = abs(sin(tt * 0.045)) * 5
                let r = 3.6 + Double(i) * 0.8, y = gy - r - hop + 0.5, rot = -tt * 0.09
                c.ell(x, gy + 0.8, r * (1 - hop * 0.08), 0.9, Col(0x000000, 0.16))
                c.ellStroke(x, y, r, r, 0.8, Col(0x8a6a3c)); c.ellStroke(x, y, r * 0.6, r * 0.6, 0.6, Col(0xa88450))
                for k in 0..<5 {
                    let an = rot + Double(k) * PI / 5
                    c.seg(x - cos(an) * r, y - sin(an) * r, x + cos(an) * r, y + sin(an) * r, 0.5, Col(0x7a5c34, 0.9))
                }
            }
        }
        if dk < 0.45 && !g.storm {
            for i in 0..<16 {
                var x = (hashN(Double(i) * 4.9) * (W + 40) + g.clock * (3 + hashN(Double(i)) * 5) - g.cam * 0.6).truncatingRemainder(dividingBy: W + 40)
                if x < 0 { x += W + 40 }
                let y = gy - 6 - hashN(Double(i) * 7.3) * gy * 0.45 + sin(g.clock * 0.6 + Double(i)) * 4
                c.R(x - 20, y, 1, 1, Col(0xfff4d0, 0.3 * (1 - dk * 2.2) * (0.5 + 0.5 * sin(g.clock * 1.4 + Double(i) * 2.1))))
            }
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
            // rings where the drops land, and the ground gone dark and wet
            c.R(0, gy, W, H - gy, Col(0x1c2430, 0.14 * rain))
            for i in 0..<Int(22 * rain) {
                let k = (g.clock * 2.2 + hashN(Double(i) * 2.7)).truncatingRemainder(dividingBy: 1)
                let cyc = floor(g.clock * 2.2 + hashN(Double(i) * 2.7))
                let rx0 = hashN(Double(i) * 9.1 + cyc * 1.3) * W, ry0 = gy + 2 + hashN(Double(i) * 4.3 + cyc * 0.7) * (H - gy - 4)
                c.ellStroke(rx0, ry0, 0.8 + k * 3.2, 0.3 + k * 0.9, 0.5, Col(0xdcecf8, 0.45 * (1 - k)))
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
        c.vfill(0, gy, W, H - gy, [(0, Col(0x060a22, 0.34 * dk)), (1, Col(0x060a22, 0.5 * dk))])
        c.blend(.plusLighter)
        func light(_ wx: Double, _ h: Double, _ r: Double, _ a: Double) {
            if !vis(wx, r) { return }
            c.glow(sx(wx), gy - h, r, Col(0xffb85a, a * dk), Col(0xffb85a, 0))
        }
        light(FIRE_X, 5, 60 + sin(g.clock * 9) * 3, 0.5)
        for bl in g.b where bl.def.wall != 0 && !bl.def.gate && bl.level > 0 { light(bl.x - 10.3, 26.5, 30, 0.5) }
        for cp in g.camps { light(cp.0 + 22, 4, 34, 0.4) }
        if let tr = g.train { light(tr.x + 3, 25, 30, 0.6); light(tr.x + 130, 22, 40, 0.3) }
        for bl in g.b where bl.level > 0 && !bl.def.gate && !bl.robbed {
            for wn in bl.def.wins { light(bl.x + wn.0 + wn.1 / 2, 15, 22, 0.28) }
        }
        // lamplight and window light lying on the street, and the gate lanterns
        for bl in g.b where bl.def.wall != 0 && !bl.def.gate && bl.level > 0 && vis(bl.x, bl.def.w + 30) {
            let lx = sx(bl.x - 10.3)
            c.ell(lx, gy + 3, 17, 3.2, Col(0xffb85a, 0.13 * dk)); c.ell(lx, gy + 2.6, 9, 1.8, Col(0xffd08a, 0.13 * dk))
            if !bl.robbed { for wn in bl.def.wins { c.ell(sx(bl.x + wn.0 + wn.1 / 2), gy + 2.6, wn.1 * 0.9 + 3, 2, Col(0xffc878, 0.1 * dk)) } }
        }
        for bl in g.b where bl.def.gate && bl.level > 0 {
            let h = [0.0, 16, 26, 36][min(bl.level, 3)]
            light(bl.x + 7 + (bl.type == .gateW ? 9 : -9), h - 5, 15, 0.5)
        }
        // fireflies out past the gates on a fair night
        if g.bio != .snow && g.wx == 0 {
            var k = Int((g.cam / 46).rounded(.down)) - 1
            while Double(k) * 46 < g.cam + W + 20 {
                let fk = Double(k)
                let wx = fk * 46 + hashN(fk * 3.3) * 40
                k += 1
                if wx > g.gateW.x - 30 && wx < g.gateE.x + 30 { continue }
                let blink = max(0, sin(g.clock * 2.1 + fk * 1.7))
                let x = sx(wx) + sin(g.clock * 0.7 + fk) * 8, y = gy - 5 - hashN(fk * 8.1) * 15 + sin(g.clock * 1.1 + fk * 2) * 3
                c.glow(x, y, 4, Col(0xd8ff7a, 0.4 * blink * dk), Col(0xd8ff7a, 0))
                c.R(x - 0.5, y - 0.5, 1, 1, Col(0xeaffa0, blink * dk))
            }
        }
        c.blend(.normal)
    }

    /// Coin slots over the building the rider is standing at: filled ones are paid.
    private func slots() {
        guard let bl = g.slotsFor, vis(bl.x, bl.def.w) else { return }
        let n = bl.cost
        if n <= 0 { return }
        // every row is centred over the building, with no panel behind
        for i in 0..<n {
            let p = g.slotXY(bl, i)
            let x = sx(p.0), y = gy + p.1
            if i < bl.paid { coinAt(x, y) } else {
                c.ellStroke(x, y, 1.9, 1.9, 1.5, Col(0x2a1c14, 0.7))
                c.ellStroke(x, y, 1.9, 1.9, 0.7, Col(0xf7d877))
            }
        }
    }
}
