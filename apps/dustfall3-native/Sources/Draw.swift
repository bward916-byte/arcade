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
        camps(dk)
        for bl in g.b where bl.def.wall != 0 && !bl.def.gate { building(bl, dk) }
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
        for f in g.folk { person(f.x, f.phase, f.dir, f.moving, f.seed, f.role, f.work) }
        for bn in g.bandits { bandit(bn) }
        if g.tripT < 0 { rider() }
        coins()
        effects()
        night(dk)
        slots()
        c.restore()
        if g.flash > 0 { c.R(0, 0, W, H, Col(0xfff0c0, g.flash * 0.5)) }
        if g.fade > 0 { c.R(0, 0, W, H, Col(0x000000, g.fade)) }
    }

    private func sx(_ x: Double) -> Double { return x - g.cam }
    private func vis(_ x: Double, _ w: Double) -> Bool { let s = x - g.cam; return s > -w - 20 && s < W + 20 }

    // ---------- sky and land
    private func sky(_ dk: Double, _ dusk: Double) {
        let top = Col.mix(Col.mix(Col(0x6fb0e0), Col(0x5a3f7a), dusk), Col(0x0a0f24), dk)
        let mid = Col.mix(Col.mix(Col(0xbfdcee), Col(0xe8794a), dusk), Col(0x1a2040), dk)
        let low = Col.mix(Col.mix(Col(0xf4dfb0), Col(0xf6b25a), dusk), Col(0x2c2a4a), dk)
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
        let far = Col.mix(Col.mix(Col(0xd9a47a), Col(0xb0607a), dusk), Col(0x34365e), dk)
        let near = Col.mix(Col.mix(Col(0xc47a4a), Col(0x8a3e4a), dusk), Col(0x2a2a4e), dk)
        let nearD = Col.mix(Col.mix(Col(0xa85e36), Col(0x6a2e3a), dusk), Col(0x20203e), dk)
        var i = 0
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
                c.R(bx + 12, gy - h * 0.7, w - 26, 1, nearD.alpha(0.5))
                c.R(bx + 8, gy - h * 0.4, w - 14, 1, nearD.alpha(0.5))
            }
            i += 1
        }
    }

    private func groundBand(_ dk: Double) {
        c.vfill(0, gy, W, H - gy, [(0, Col(0xdcb680)), (0.25, Col(0xd0a66e)), (1, Col(0xb88a56))])
        c.R(0, gy, W, 1, Col(0xeccf9c))
        // the main street, packed earth between the gates
        let a = sx(966), b2 = sx(g.gateE.x)
        if b2 > 0 && a < W { c.R(max(0, a), gy + 1, min(W, b2) - max(0, a), 5, Col(0xc49a66)) }
        var i = Int(g.cam / 23)
        let end = Int((g.cam + W) / 23) + 1
        while i <= end {
            let x = Double(i) * 23 + hashN(Double(i) * 1.3) * 18
            let y = gy + 3 + hashN(Double(i) * 4.7) * (H - gy - 6)
            c.R(sx(x).rounded(), y.rounded(), 2 + hashN(Double(i)) * 3, 1, Col(0x9a744a, 0.55))
            i += 1
        }
    }

    private func scenery() {
        var i = Int((g.cam - 40) / 120)
        let end = Int((g.cam + W + 40) / 120)
        while i <= end {
            if i >= 0 {
                let x = Double(i) * 120 + hashN(Double(i) * 6.6) * 90
                let inTown = x > 890 && x < g.gateE.x + 60
                if !inTown {
                    let k = hashN(Double(i) * 2.9)
                    let s = sx(x)
                    if k < 0.45 { cactus(s, 12 + k * 22) } else if k < 0.8 { brush(s) } else { rock(s, 5 + k * 6) }
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
    private func brush(_ x: Double) {
        let col = Col(0x8a8a56)
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
        for cw in g.herd {
            let x = sx(cw.x), s = cw.calf ? 0.6 : 1.0
            let dkc = Int(cw.seed) % 3 == 0
            let body = dkc ? Col(0x3a2e28) : Col(0x8a4a2c), lo = dkc ? Col(0x2a201c) : Col(0x6c3820)
            let sw = sin(cw.phase) * 1.2
            c.save(); c.translate(x, gy); c.scale(cw.dir * s, s)
            c.R(-6 + sw * 0.4, -5, 1.5, 5, lo); c.R(-3 - sw * 0.4, -5, 1.5, 5, lo); c.R(3 + sw * 0.4, -5, 1.5, 5, lo); c.R(5.5 - sw * 0.4, -5, 1.5, 5, lo)
            c.RR(-8, -12, 16, 8, 2.5, body)
            c.RR(6, -14, 6, 5, 1.5, body); c.R(10.5, -11.5, 2, 2, lo)
            c.R(6, -15, 1, 1.5, Col(0xe8dcc4)); c.R(10, -15, 1, 1.5, Col(0xe8dcc4))
            c.seg(-8, -11, -10, -5, 0.8, lo)
            if !dkc { c.R(-3, -11, 4, 3, Col(0xe8dcc4, 0.8)) }
            c.restore()
        }
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

    private func horse(_ x: Double, _ dir: Double, _ phase: Double, _ moving: Bool, _ coat: Col, _ dark: Col) {
        c.save()
        c.translate(x, gy)
        c.scale(dir, 1)
        let bob = moving ? sin(phase * 2) * 0.8 : 0
        // legs
        let l1 = moving ? sin(phase) * 4 : 0, l2 = moving ? sin(phase + PI) * 4 : 0
        c.seg(-8, -9, -8 + l1, 0, 2, dark); c.seg(-5, -9, -5 + l2, 0, 2, coat)
        c.seg(6, -9, 6 + l2, 0, 2, dark); c.seg(9, -9, 9 + l1, 0, 2, coat)
        // body, neck, head, tail
        c.RR(-11, -16 + bob, 23, 9, 3.5, coat)
        c.poly(coat, [8, -15 + bob, 14, -23 + bob, 18, -21 + bob, 12, -10 + bob])
        c.RR(13, -26 + bob, 9, 5, 2, coat)
        c.R(20, -24 + bob, 2.5, 2, dark)
        c.poly(dark, [12, -24 + bob, 14, -28 + bob, 15, -24 + bob])
        c.poly(dark, [9, -18 + bob, 14, -24 + bob, 11, -15 + bob])
        c.curve(-11, -14 + bob, -17, -12 + bob, -15 - (moving ? sin(phase) * 2 : 0), -5, 2, dark)
        c.R(17, -24.5 + bob, 1, 1, Col(0x1c120c))
        c.restore()
    }

    private func rider() {
        let x = sx(g.px)
        let moving = abs(g.pvx) > 6
        let bob = moving ? sin(g.pphase * 2) * 0.8 : 0
        c.ell(x, gy + 1, 13, 2, Col(0x000000, 0.2))
        horse(x, g.pdir, g.pphase, moving, Col(0x9a5a34), Col(0x5a3420))
        c.save()
        c.translate(x, gy)
        c.scale(g.pdir, 1)
        // saddle blanket, leg, body
        c.R(-5, -17 + bob, 9, 3, Col(0xb5412e))
        c.R(-1, -16 + bob, 3, 7, Col(0x3a4a6a)); c.R(-1, -9.5 + bob, 4, 1.5, Col(0x2e2622))
        c.R(-3, -25 + bob, 6, 9, Col(0x8a5a3a))
        c.R(-3, -19 + bob, 6, 1.5, Col(0x4a3424))
        // gun arm or reins
        if g.gunT > 0 || g.input.fire {
            c.seg(1, -23 + bob, 9, -22 + bob, 1.6, Col(0xd9a878)); c.R(8, -23.5 + bob, 5, 1.5, Col(0x4a4a50))
            if g.gunT > 0.07 { c.circ(15, -22.5 + bob, 3, Col(0xfff0b0)); c.circ(15, -22.5 + bob, 1.6, Col(0xffffff)) }
        } else if g.tossT > 0 {
            c.seg(1, -23 + bob, 7, -28 + bob, 1.6, Col(0xd9a878))
        } else {
            c.seg(1, -22 + bob, 6, -19 + bob, 1.6, Col(0xd9a878))
            c.seg(6, -19 + bob, 14, -21 + bob, 0.6, Col(0x2e2622))
        }
        // head, bandana, hat
        c.R(-2, -29 + bob, 4.5, 4, Col(0xd9a878))
        c.R(-2, -26 + bob, 5, 1.5, Col(0xb5412e))
        c.R(-5, -30 + bob, 11, 1.5, Col(0x4a3424)); c.R(-2.5, -33 + bob, 6, 3.2, Col(0x4a3424))
        c.restore()
        if g.hurtT > 0 && Int(g.clock * 16) % 2 == 0 { c.circ(x, gy - 18, 12, Col(0xd04a3a, 0.25)) }
    }

    private func bandit(_ bn: Bandit) {
        if !vis(bn.x, 30) { return }
        let dir = bn.st == 3 ? bn.side : -bn.side
        let x = sx(bn.x)
        let moving = bn.st == 0 || bn.st == 3
        if bn.rider {
            horse(x, dir, bn.phase, moving, Col(0x3a3230), Col(0x1c1816))
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
        if bl.def.gate || bl.wire || bl.isHall { gap = 12 } else if bl.virt { gap = 26 }
        let top = gy - tall - gap - Double(rows) * 6
        let cx = sx(bl.cx)
        c.RR(cx - Double(per) * 3 - 3, top - 4, Double(per) * 6 + 6, Double(rows) * 6 + 2, 3, Col(0x2a1c14, 0.75))
        for i in 0..<n {
            let x = cx - Double(per) * 3 + 3 + Double(i % per) * 6
            let y = top + Double(i / per) * 6
            if i < bl.paid { coinAt(x, y) } else { c.ellStroke(x, y, 1.8, 1.8, 0.7, Col(0xf2c14e, 0.8)) }
        }
    }
}
