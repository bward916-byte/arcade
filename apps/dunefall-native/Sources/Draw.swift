import CoreGraphics
import Foundation

// Scene drawing for the trial slice. Ported from the draw routines in dunefall/index.html:
// every shape is still drawn in code, there are no image files.

enum Tool { case none, hammer, pick, spear, staff, sword }

struct PersonOpt {
    var robe: Col
    var turban: Col
    var skin: Col
    var dir = 1.0
    var moving = false
    var walk = 0.0
    var veil: Col? = nil
    var beard: Col? = nil
    var sash: Col? = nil
    var cheer = false
    var tool = Tool.none
    var ham = 0.0
    var torch = false
    var lean = 0.0
}

struct CamelOpt {
    var trot = false
    var gallop = false
    var saddle: Col? = nil
    var kneel = 0.0
    var graze = 0.0
    var col = Col(0x8a5a32)
    var dk = Col(0x5a391c)
    var lt = Col(0xad7a48)
    var load: Col? = nil
}

struct RiderOpt {
    var robe: Col
    var skin: Col
    var turban: Col
    var sash: Col? = nil
    var veil: Col? = nil
    var fl = 0.0
    var jewel = false
}

struct Star { let x: Double; let y: Double; let b: Double; let s: Double; let f: Double; let p: Double }
struct Light { let x: Double; let y: Double; let r: Double; let k: Double }

final class Renderer {
    let g: Game
    let c: Canvas
    let ovl: Canvas
    var W = 0.0
    var H = 0.0
    var GY = 0.0
    var cam = 0.0
    var NOW = 0.0
    var lights: [Light] = []
    let stars: [Star]
    let PS = 1.4
    let SKY: [(Double, Col, Col)] = [
        (0, Col(0x6a5f9a), Col(0xf6b98a)), (0.08, Col(0x4fb3d9), Col(0xf4e3bd)), (0.5, Col(0x4aaed6), Col(0xf6e6c0)),
        (0.6, Col(0x6a4a8a), Col(0xf79a4e)), (0.66, Col(0x3a2460), Col(0xe8603a)), (0.73, Col(0x070b24), Col(0x252252)),
        (0.93, Col(0x070b24), Col(0x252252)), (1.001, Col(0x6a5f9a), Col(0xf6b98a))
    ]

    init(game: Game, canvas: Canvas, overlay: Canvas) {
        g = game
        c = canvas
        ovl = overlay
        var st: [Star] = []
        for i in 0..<110 {
            let n = Double(i)
            st.append(Star(x: hashN(n), y: hashN(n + 200) * 0.92, b: 0.35 + 0.65 * hashN(n + 400),
                           s: hashN(n + 600) < 0.14 ? 1 : 0.5, f: 1 + hashN(n + 700) * 3, p: hashN(n + 800) * 6))
        }
        stars = st
    }

    var lit: Bool { return g.dark > 0.45 }
    var sunLean: Double { return g.dark > 0.5 ? 0 : clampD((0.33 - g.t) * 3.2, -1.1, 1.1) }
    func light(_ x: Double, _ y: Double, _ r: Double, _ k: Double) { lights.append(Light(x: x, y: y, r: r, k: k)) }

    func skyAt(_ t: Double) -> (Col, Col) {
        var i = 0
        while i + 2 < SKY.count && SKY[i + 1].0 <= t { i += 1 }
        let a = SKY[i], b = SKY[i + 1]
        let k = clampD((t - a.0) / (b.0 - a.0), 0, 1)
        return (Col.mix(a.1, b.1, k), Col.mix(a.2, b.2, k))
    }

    // ---------- the frame
    func draw() {
        W = g.W; H = g.H; GY = g.GY; cam = g.cam; NOW = g.NOW
        lights = []
        c.save()
        c.alpha(1)
        c.blend(.normal)
        if g.state == .title || g.state == .end {
            title()
            c.restore()
            return
        }
        let hz = skyAt(g.t).1
        sky()
        if g.shake > 0 { c.translate(rnd(-1, 1) * g.shake * 4, rnd(-1, 1) * g.shake * 3) }
        if g.zoom > 1.001 {
            let zx = clampD((g.scene?.fx ?? g.player.x) - cam, W * 0.25, W * 0.75)
            c.translate(zx, GY + 8); c.scale(g.zoom, g.zoom); c.translate(-zx, -GY - 8)
        }
        if g.feat == .cliff { cliffs(hz) } else {
            if g.feat != .oasis { farPyramid(150, 62, 58, hz); farPyramid(232, 46, 44, hz); farPyramid(292, 30, 30, hz) }
            if g.feat != .port { farPyramid(520, 40, 40, hz) }
            farPyramid(700, 54, 50, hz)
            if g.feat != .oasis { farPyramid(762, 28, 27, hz) }
        }
        dunes(0.12, 14, 16, Col.mix(Col(0xecd3a0), hz, 0.35), Col.mix(Col(0xc39c62), hz, 0.35), 1.3, 0.012, false)
        dunes(0.28, 6, 18, Col(0xebcd90), Col(0xbd9052), 4.1, 0.017, true)
        dunes(0.55, 0, 13, SAND, Col(0xb3854a), 7.7, 0.023, true)
        ground()
        nile()
        quarry()
        sites()
        for cp in g.camps { camp(cp) }
        for u in g.urns { urn(u) }
        let palms: [Double] = [330, 560, 930, 1210, 2040, 2260, 2590, 2780, 2960]
        for i in 0..<palms.count {
            let wx = palms[i]
            if (wx > g.TOWN.0 - 40 && wx < g.TOWN.1 + 40) || abs(wx - g.QUARRY) < 60 { continue }
            let n = Double(i)
            palm(wx - cam, 18 + hashN(n + 40) * 14, 0.8 + hashN(n) * 0.3, 50 + n, false)
        }
        for f in g.prints {
            c.alpha(0.3 * (1 - f.t / 12))
            c.ell(f.x - cam, GY + 1.2, 1.5, 0.6, Col(0x7a5226))
        }
        c.alpha(1)
        for r in g.rings where r.t >= 0 {
            let k = r.t
            c.ellStroke(r.x - cam, GY, 6 + k * 70, 1.5 + k * 13, 1.4 * (1 - k) + 0.3, rgba(255, 226, 140, 1 - k))
        }
        for k in [BType.bank, .market, .tea, .well, .guard, .temple, .pen] { front(g.B(k)) }
        for b in g.bs { rack(b) }
        shopSigns()
        for cg in g.herd { goat(cg) }
        for h in g.hares { hare(h) }
        for d in g.nomads {
            person(d.x, 0, PersonOpt(robe: Col(0x2c3f6e), turban: Col(0x1f2c50), skin: SKIN[d.id % 3], dir: d.dir, moving: d.moving, walk: d.walk, veil: Col(0x1f2c50)))
        }
        for f in g.folk where !f.hidden { folk(f) }
        let shopper: [Col] = [Col(0x7a4a8a), Col(0x3a7a6a), Col(0xc2643a), Col(0x4a5a9a), Col(0xd9c9a0), Col(0x8a3a3a)]
        for cr in g.crowd where !cr.hidden {
            var o = PersonOpt(robe: shopper[cr.id % 6], turban: TURB[(cr.id + 1) % 5], skin: SKIN[cr.id % 3])
            o.dir = cr.dir; o.moving = cr.moving; o.walk = cr.walk
            if cr.id % 2 == 1 { o.sash = GOLD }
            person(cr.x, 0, o)
        }
        if let cv = g.caravan { caravan(cv) }
        for f in g.fallen {
            c.alpha(clampD(1 - f.t / 5, 0, 1))
            let k = min(1, f.t * 3.2)
            let w = lerp(6, 14, k), hh = lerp(16, 3.4, k), hop = sin(PI * k) * 5
            c.R(f.x - cam - w / 2 - f.dir * k * 4, GY - hh - hop, w, hh, Col(0x2a2422))
        }
        c.alpha(1)
        for r in g.raiders { raider(r) }
        if g.trip == nil && !g.hidePlayer { drawPlayer() }
        front(g.B(.gw)); front(g.B(.ge))
        for b in g.bs { slots(b) }
        for b in g.bs where b.building {
            let x = b.mid - cam
            let y = GY - b.def.h[min(b.level + 1, b.def.h.count - 1)] - 12
            c.R(x - 9, y, 18, 2.4, rgba(28, 19, 12, 0.75))
            c.R(x - 8.5, y + 0.5, 17 * clampD(b.progress / b.need, 0, 1), 1.4, GOLD)
        }
        for cn in g.coins {
            if cn.st == .back && cn.age < 0 { continue }
            let x = cn.x - cam, y = GY - cn.h - 1.6
            let spin = abs(sin(cn.age * 9 + cn.x))
            c.ell(x, y, 1.7 * (cn.st == .ground ? 1 : 0.35 + 0.65 * spin), 1.7, GOLD)
            c.R(x - 0.5, y - 0.9, 0.6, 0.6, Col(0xfff3b8))
            if cn.st == .ground && sin(NOW * 3 + cn.x * 0.7) > 0.9 {
                c.R(x - 2.5, y - 0.25, 5, 0.5, Col(0xffffff)); c.R(x - 0.25, y - 2.5, 0.5, 5, Col(0xffffff))
            }
        }
        for s in g.stuck {
            let x = s.x - cam
            if x < -10 || x > W + 10 { continue }
            c.save()
            c.alpha(clampD((22 - s.t) / 4, 0, 1))
            c.translate(x, GY + 0.6); c.rotate(s.ang)
            c.seg(-7.5, 0, -0.6, 0, 0.6, Col(0xe8dcc0)); c.R(-8.6, -1, 2.2, 0.8, RED); c.R(-8.6, 0.2, 2.2, 0.8, Col(0x8f2a1c))
            c.restore()
        }
        for a in g.arrows {
            c.save()
            c.translate(a.x - cam, GY - a.h); c.rotate(atan2(-a.vh, a.vx))
            c.linear(-24, -0.3, 24, 0.6, -24, 0, 0, 0, [(0, rgba(255, 244, 214, 0)), (1, rgba(255, 244, 214, 0.5))])
            c.seg(-6.5, 0, 0, 0, 0.7, Col(0xe8dcc0)); c.poly(Col(0xd8d8d0), [0, -1, 2.2, 0, 0, 1])
            c.R(-7.6, -1, 2, 0.8, RED); c.R(-7.6, 0.2, 2, 0.8, RED)
            c.restore()
        }
        for q in g.parts {
            let k = q.life / q.max
            if q.smoke {
                c.alpha(q.a * (1 - k))
                c.circ(q.x - cam, GY - q.h, q.r * (0.6 + k * 1.6), q.col)
            } else {
                c.alpha(clampD(1 - k, 0, 1))
                let s = q.lit ? 1.0 : 1.5
                c.R(q.x - cam - 0.6, GY - q.h - 0.6, s, s, q.col)
            }
        }
        c.alpha(1)
        for rk in g.rocks {
            let x = rk.x - cam
            if x < -12 || x > W + 12 { continue }
            c.ell(x, GY + 0.4, 6.4, 1.1, rgba(40, 20, 8, 0.35))
            c.save()
            c.translate(x, GY - 5.6); c.rotate(rk.rot)
            c.circ(0, 0, 5.8, Col(0x8f4e2a)); c.circ(-1, -1.2, 4.4, Col(0xb06a40)); c.R(-3.4, -0.4, 3, 0.7, Col(0x5e2e16)); c.R(0.6, 1.6, 3.2, 0.7, Col(0x5e2e16))
            c.restore()
        }
        if g.carry > 0 {
            let x = g.player.x - cam, y = GY - 38 + sin(NOW * 3)
            c.ell(x, y, 3, 3.6, GOLD); c.R(x - 1.4, y - 5.4, 2.8, 2, GOLD); c.R(x - 3.4, y - 0.6, 6.8, 1, LAPIS)
            let sx = g.sellX - cam, by = GY - 52 + sin(NOW * 5) * 2.5
            c.poly(GOLD, [sx - 4, by, sx + 4, by, sx, by + 6]); c.R(sx - 1.2, by - 6, 2.4, 6, GOLD)
        }
        // the haboob: a wall of dust coming from the west, and the air inside it
        if let st = g.storm {
            let fx = st.front - cam
            let k = g.stormK(g.player.x)
            if fx > -40 {
                let edge = min(fx, W + 20)
                c.R(-9, -9, edge + 9, H + 18, rgba(176, 122, 66, 0.5 + 0.22 * k))
                var y = -6.0
                var n = 0.0
                while y < GY + 12 {
                    c.circ(edge + sin(NOW * 0.8 + n) * 5, y, 15 + hashN(n) * 9, rgba(196, 142, 80, 0.75))
                    y += 13; n += 1
                }
            }
        }
        if g.rain != nil {
            c.R(-9, -9, W + 18, H + 18, rgba(70, 96, 130, 0.22))
            for q in 0..<70 {
                let n = Double(q)
                let rx = (hashN(n) * (W + 60) + NOW * 60).truncatingRemainder(dividingBy: W + 60) - 30
                let ry = (hashN(n + 50) * H + NOW * (260 + hashN(n + 9) * 120)).truncatingRemainder(dividingBy: H)
                c.seg(rx, ry, rx + 2.4, ry + 8, 0.45, rgba(210, 230, 255, 0.5))
            }
        }
        // dusk colour, then night with pools of firelight cut out of it
        let warm = g.warmth(g.t)
        if warm > 0 { c.R(-9, -9, W + 18, H + 18, rgba(255, 118, 48, warm * 0.16)) }
        if g.dark > 0.02 {
            ovl.save()
            ovl.blend(.normal)
            ovl.clear(W, H)
            ovl.R(0, 0, W, H, rgba(8, 10, 44, g.dark * 0.62))
            ovl.blend(.destinationOut)
            for l in lights { ovl.glow(l.x, l.y, l.r, Col(r: 0, g: 0, b: 0, a: min(1, l.k)), Col(r: 0, g: 0, b: 0, a: 0)) }
            ovl.blend(.normal)
            ovl.restore()
            c.stamp(ovl, W, H)
            c.blend(.plusLighter)
            for l in lights { c.glow(l.x, l.y, l.r * 0.6, rgba(255, 170, 80, 0.16 * min(1, l.k) * g.dark), rgba(255, 150, 60, 0)) }
            c.blend(.normal)
        }
        if g.flash > 0 { c.R(-9, -9, W + 18, H + 18, rgba(255, 244, 214, g.flash * 0.5)) }
        // soft dark corners, then the map strip and the raid warnings
        c.linear(-9, -9, 60, H + 18, -9, 0, 51, 0, [(0, rgba(20, 10, 30, 0.22)), (1, rgba(20, 10, 30, 0))])
        c.linear(W - 51, -9, 60, H + 18, W - 51, 0, W + 9, 0, [(0, rgba(20, 10, 30, 0)), (1, rgba(20, 10, 30, 0.22))])
        if g.state == .play && g.scene == nil && g.trip == nil { minimap() }
        if g.fade > 0 { c.R(-20, -20, W + 40, H + 40, rgba(0, 0, 0, g.fade)) }
        c.restore()
    }

    // ---------- sky and the far country
    func sky() {
        let (top, bot) = skyAt(g.t)
        c.vfill(0, 0, W, GY, [(0, top), (1, bot)])
        c.R(0, GY, W, H - GY, bot)
        if g.dark > 0.2 {
            let a = (g.dark - 0.2) * 1.25
            for s in stars {
                let tw = 0.6 + 0.4 * sin(NOW * s.f + s.p)
                c.R(s.x * W, s.y * (GY - 12), s.s, s.s, rgba(255, 248, 226, a * s.b * tw))
            }
        }
        let t = g.t
        if t < 0.7 {
            let u = clampD(t / 0.66, 0, 1.06)
            let arc = sin(PI * min(u, 1))
            let sx = W * (0.06 + 0.88 * u), sy = GY - 6 - arc * (GY - 26), low = 1 - arc
            c.glow(sx, sy, 60 + low * 40, rgba(255, 230 - low * 60, 170 - low * 90, 0.75), rgba(255, 200, 120, 0))
            c.save()
            c.translate(sx, sy); c.rotate(NOW * 0.03)
            for i in 0..<12 {
                c.rotate(PI / 6)
                let len = 70 + low * 30 + Double(i % 2) * 18
                c.poly(rgba(255, 240, 200, 0.05 + low * 0.03), [-2.5, 0, 0, -len, 2.5, 0])
            }
            c.restore()
            c.circ(sx, sy, 7 + low * 3, Col.mix(Col(0xfffce8), Col(0xff9646), low))
            c.circ(sx, sy, 4 + low * 2, rgba(255, 255, 255, 0.5))
            if let e = g.ecl {
                let k = clampD(e / 20, 0, 1)
                c.circ(sx + (k - 0.5) * 22, sy, 7.6 + low * 3, Col(0x0a0a18))
                c.arcStroke(sx + (k - 0.5) * 22, sy, 8.4 + low * 3, 0, PI * 2, 0.5, rgba(255, 236, 190, 0.5 * sin(PI * k)))
            }
        }
        if t > 0.64 || t < 0.04 {
            let u = t < 0.04 ? 1 : (t - 0.64) / 0.36
            let sx = W * (0.1 + 0.8 * u), sy = GY - 10 - sin(PI * u) * (GY - 30)
            c.glow(sx, sy, 34, rgba(210, 220, 255, 0.28), rgba(210, 220, 255, 0))
            c.circ(sx, sy, 6, Col(0xf4f0dc))
            c.circ(sx + 3.2, sy - 1.6, 5.2, Col.mix(top, bot, clampD(sy / GY, 0, 1)))
        }
        c.linear(0, GY - 46, W, 46, 0, GY - 46, 0, GY, [(0, rgba(255, 236, 196, 0)), (1, rgba(255, 236, 196, 0.34 * (1 - g.dark)))])
        for i in 0..<5 {
            let n = Double(i)
            let span = W + 140
            var x = (hashN(n + 31) * W * 1.6 + NOW * (1.5 + n * 0.4) - cam * 0.03).truncatingRemainder(dividingBy: span)
            if x < 0 { x += span }
            x -= 70
            let y = 14 + hashN(n + 50) * GY * 0.4
            c.ell(x, y, 34 + hashN(n) * 30, 1.8 + hashN(n + 9) * 1.6, rgba(255, 246, 228, 0.16 * (1 - g.dark * 0.7)))
        }
        if g.dark < 0.5 {
            for i in 0..<5 {
                let n = Double(i)
                let fx = (NOW * 9 + n * 7).truncatingRemainder(dividingBy: W + 80) - 40 + n * 6
                let fy = GY * 0.32 + sin(NOW * 0.6 + n) * 4 + Double((i * 13) % 9) * 2
                let wg = sin(NOW * 7 + n) * 1.4
                c.seg(fx - 3, fy - wg, fx, fy + 0.6, 0.5, rgba(40, 28, 20, 0.55))
                c.seg(fx, fy + 0.6, fx + 3, fy - wg, 0.5, rgba(40, 28, 20, 0.55))
            }
        }
    }

    func farPyramid(_ fx: Double, _ h: Double, _ w: Double, _ hz: Col) {
        let x = fx - cam * 0.07, y = GY - 16
        if x < -w || x > W + w { return }
        let sp = x + w * 0.3
        let lc = Col.mix(Col(0xe2ba7a), hz, 0.4), dc = Col.mix(Col(0x9c7440), hz, 0.4)
        c.poly(Col.mix(lc, hz, 0.15), [x - w, y, x, y - h, sp, y])
        c.poly(Col.mix(dc, hz, 0.15), [x, y - h, x + w, y, sp, y])
        c.seg(x, y - h, sp, y, 0.5, rgba(255, 240, 200, 0.35))
    }

    func dunes(_ par: Double, _ base: Double, _ amp: Double, _ cl: Col, _ cd: Col, _ seed: Double, _ f: Double, _ rip: Bool) {
        let off = cam * par
        var cols: [Col] = []
        for k in 0..<5 { cols.append(Col.mix(cl, cd, Double(k) * 0.25)) }
        var py = -1.0
        var first = true
        var x = -2.0
        while x <= W + 2 {
            let wx = x + off
            let a1 = (1 - abs(sin(wx * f + seed))) * 0.6
            let a2 = (0.5 + 0.5 * sin(wx * f * 2.3 + seed * 2)) * 0.28
            let a3 = (0.5 + 0.5 * sin(wx * f * 0.37 + seed * 5)) * 0.4
            let y = GY - base - amp * (a1 + a2 + a3)
            if first { py = y; first = false }
            let k = clampD((y - py) * 1.5 + 0.12, 0, 1)
            c.R(x, y, 2.05, GY - y, cols[Int((k * 4).rounded())])
            if y < py - 0.05 { c.R(x, y, 2.05, 0.8, rgba(255, 244, 208, 0.45)) } else if rip {
                var q = 3.0
                while q < amp { c.R(x, y + q + sin(wx * 0.09 + q) * 1.2, 2.05, 0.45, rgba(120, 80, 30, 0.13)); q += 3.5 }
            }
            py = y
            x += 2
        }
    }

    func ground() {
        c.vfill(-4, GY, W + 8, H - GY + 4, [(0, Col(0xecce92)), (0.35, SAND), (1, Col(0xc79a58))])
        c.R(-4, GY, W + 8, 1, Col(0xf6dfaa))
        let tx0 = g.TOWN.0 - cam, tx1 = g.TOWN.1 - cam
        let road = rgba(196, 158, 104, 0.55), clear = rgba(196, 158, 104, 0)
        c.linear(tx0 - 30, GY, 40, H - GY, tx0 - 30, 0, tx0 + 10, 0, [(0, clear), (1, road)])
        c.R(tx0 + 10, GY, tx1 - tx0 - 6, H - GY, road)
        c.linear(tx1 + 4, GY, 40, H - GY, tx1 + 4, 0, tx1 + 44, 0, [(0, road), (1, clear)])
        var i = Int(floor(cam / 9))
        let last = Int((cam + W) / 9) + 2
        while i < last {
            let n = Double(i)
            let wx = n * 9 + hashN(n) * 7, dp = hashN(n + 0.5)
            let y = GY + 2 + dp * (H - GY - 4), len = (6 + hashN(n + 2) * 12) * (0.6 + dp)
            let x = wx - cam
            c.curve(x, y, x + len / 2, y - 1.2, x + len, y, 0.45, rgba(140, 96, 44, 0.3))
            c.curve(x, y + 0.6, x + len / 2, y - 0.6, x + len, y + 0.6, 0.45, rgba(255, 240, 200, 0.3))
            if hashN(n + 7) < 0.14 { c.R(x + 3, y + 1, 1.8, 1.2, Col(0xa8875a)); c.R(x + 3, y + 1, 1.8, 0.4, Col(0xd8ba88)) }
            i += 1
        }
    }

    func nile() {
        let x = g.NILE - cam
        if x > W + 10 { return }
        c.vfill(x, GY - 1, W - x + 10, H - GY + 2, [(0, Col(0x6fb6c8)), (1, Col(0x2c6f9e))])
        for i in 0..<8 {
            let n = Double(i)
            let rx = x + 6 + hashN(n + 70) * 80 + sin(NOW * 1.3 + n) * 3
            c.R(rx, GY + 2 + hashN(n + 71) * (H - GY - 6), 8 + hashN(n) * 10, 0.6, rgba(255, 255, 255, 0.35))
        }
        c.poly(SAND2, [x - 10, GY + 0.5, x, GY - 2, x + 3, GY + 0.5])
    }

    func palm(_ sx: Double, _ h: Double, _ s: Double, _ seed: Double, _ dates: Bool) {
        if sx < -30 || sx > W + 30 { return }
        let sw = sin(NOW * 1.3 + seed) * 1.2 * s
        let lean = (hashN(seed) - 0.5) * 8 * s
        let tx = sx + lean + sw * 0.4, ty = GY - h
        c.curve(sx, GY, sx + lean * 0.2, GY - h * 0.5, tx, ty, 2 * s, WOOD)
        for i in 1..<6 {
            let k = Double(i) / 6
            let x = sx + lean * k * k + sw * 0.4 * k, y = GY - h * k
            c.seg(x - s, y, x + s, y, 0.5, Col(0x5a3e22))
        }
        for i in 0..<8 {
            let a = -PI * (0.02 + Double(i) / 7 * 0.96)
            let len = (10 + hashN(seed + Double(i)) * 4) * s
            let ex = tx + cos(a) * len + sw, ey = ty + sin(a) * len * 0.55 + len * 0.42
            c.curve(tx, ty, tx + cos(a) * len * 0.6 + sw * 0.5, ty + sin(a) * len * 0.7, ex, ey, 1.5 * s, i % 2 == 1 ? Col(0x3f7d3a) : Col(0x2c5c2e))
        }
        if dates { c.circ(tx - 1.5, ty + 2.5, 1.6, Col(0xd9822a)); c.circ(tx + 1.5, ty + 3, 1.6, Col(0xc2641e)) }
    }

    func fire(_ sx: Double, _ y: Double, _ s: Double) {
        let f = sin(NOW * 13 + sx) * 0.5 + sin(NOW * 21) * 0.3
        c.poly(Col(0xe8602a), [sx - 2.5 * s, y, sx + f, y - 6 * s - f, sx + 2.5 * s, y])
        c.poly(Col(0xffc24a), [sx - 1.5 * s, y, sx - f * 0.5, y - 3.6 * s, sx + 1.5 * s, y])
        light(sx, y - 4, 34 * s * (1 + 0.08 * sin(NOW * 17 + sx)), 1)
    }

    // ---------- building pieces
    func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c1: Col, _ c2: Col, _ seed: Double) {
        c.R(x, y, w, h, c1)
        c.vfill(x, y, w, h, [(0, rgba(255, 236, 190, 0.22)), (0.55, rgba(255, 236, 190, 0)), (1, rgba(70, 40, 10, 0.28))])
        c.R(x, y, w, 1.2, rgba(255, 238, 200, 0.5)); c.R(x + w - 2.5, y, 2.5, h, c2); c.R(x, y + h - 1.5, w, 1.5, c2)
        let n = Int(w * h / 70)
        for i in 0..<max(0, n) {
            let k = Double(i)
            c.R(x + 2 + hashN(seed + k * 5.1) * (w - 7), y + 3 + hashN(seed + k * 9.7) * (h - 6), 2.5, 0.5, c2)
        }
    }
    func crenels(_ x: Double, _ y: Double, _ w: Double, _ col: Col) {
        var i = 0.0
        while i < w - 2 { c.R(x + i, y - 2.5, 3, 2.5, col); i += 5 }
    }
    func ruin(_ x: Double, _ w: Double, _ h: Double, _ seed: Double) {
        var i = 0.0
        while i < w {
            let broken = hashN(seed + i * 3) < 0.22 ? 0.2 : 1.0
            let hh = h * (0.3 + 0.7 * hashN(seed + i)) * broken
            let even = Int(i / 6) % 2 == 0
            c.R(x + i, GY - hh, 6.05, hh, even ? MUDD : MUD2)
            c.R(x + i, GY - hh, 6.05, 0.8, Col(0xd9b680))
            var k = 4.0
            while k < hh { c.R(x + i + 1.5, GY - k, 2.5, 0.5, Col(0x6e5232)); k += 4 }
            i += 6
        }
        c.R(x + w * 0.44, GY - h * 0.42, 7, h * 0.42, DARKC)
        c.poly(SAND2, [x - 8, GY, x + w * 0.2, GY - 5, x + w * 0.5, GY - 2, x + w * 0.8, GY - 6, x + w + 8, GY])
        if g.introFires { fire(x + w * 0.28, GY - h * 0.55, 1.5); fire(x + w * 0.72, GY - h * 0.3, 1.2); fire(x + w * 0.5, GY - 3, 1) }
    }
    /// A wall going up: bricks laid course by course inside a timber frame.
    func scaffold(_ b: Building, _ x: Double, _ h: Double, _ base: Double) {
        let k = clampD(b.progress / b.need, 0, 1)
        let ins = base > 0 ? b.w * 0.14 : 3.0
        let w = b.w - ins * 2
        let bw = 5.0, bh = 3.0
        let rows = max(1, Int(ceil((h - base) / bh))), cols = max(1, Int(ceil(w / bw)))
        let n = Int(k * Double(rows * cols))
        let x0 = x + ins, top = GY - base
        if n > 0 {
            for i in 0..<n {
                let r = i / cols, cc = i % cols
                let bx = x0 + Double(cc) * bw - (r % 2 == 1 ? bw / 2 : 0)
                let lx = max(x0, bx)
                let rw = min(x0 + w, bx + bw) - lx - 0.4
                if rw <= 0 { continue }
                let by = top - Double(r + 1) * bh
                c.R(lx, by, rw, bh - 0.4, (r + cc) % 3 != 0 ? MUD : MUD2)
                c.R(lx, by, rw, 0.5, rgba(255, 236, 196, 0.4))
            }
        }
        for px in [x + 0.5, x + b.w - 1.5] { c.seg(px, GY, px, GY - h - 6, 1, WOOD) }
        c.seg(x + 0.5, GY - h - 4, x + b.w - 1.5, GY - h - 4, 0.8, WOOD)
        c.seg(x + 0.5, GY - h * 0.5, x + b.w - 1.5, GY - h * 0.5, 0.6, WOOD)
        c.seg(x - 15, GY, x + 1, GY - h * k, 1.4, WOOD)
    }
    func awning(_ x: Double, _ y: Double, _ w: Double, _ d: Double, _ c1: Col, _ c2: Col, _ seed: Double) {
        let fl = sin(NOW * 2.4 + seed) * 0.7
        var i = 0.0
        while i < w {
            let col = Int(i / 3) % 2 == 1 ? c1 : c2
            let dy = y + d + fl * (i / w)
            c.poly(col, [x + i, y, x + i + 3.05, y, x + i + 2.05, dy, x + i - 1, dy])
            c.circ(x + i + 0.5, dy, 1.3, col)
            i += 3
        }
        c.seg(x - 1, y + d, x - 1, GY, 0.7, WOOD); c.seg(x + w - 2, y + d, x + w - 2, GY, 0.7, WOOD)
    }
    func win(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        c.arch(x, y, w, h, lit ? Col(0xffd27a) : DARKC)
        if lit { light(x + w / 2, y + h / 2, 14, 0.6) }
    }
    func pennant(_ x: Double, _ y: Double, _ col: Col, _ len: Double) {
        c.seg(x, y, x, y - 10, 0.7, WOOD)
        let f = sin(NOW * 5 + x) * 1.2
        c.poly(col, [x, y - 10, x + len, y - 8.5 + f, x, y - 6.5])
    }

    // ---------- the town
    func front(_ b: Building) {
        let x = b.x - cam, L = b.level, w = b.w, t = b.type
        if x > W + 140 || x + w < -140 { return }
        c.save()
        if b.shake > 0 { c.translate(rnd(-1, 1) * b.shake * 4, 0) }
        let plain = !b.def.gate && t != .well
        if plain {
            let sl = sunLean, th = b.tall
            c.poly(rgba(60, 34, 8, 0.2), [x, GY, x + w, GY, x + w + sl * th * 0.6 + 3, GY + 5, x + sl * th * 0.6 - 3, GY + 5])
            c.R(x - 1, GY, w + 2, 1.6, rgba(60, 34, 8, 0.3))
        }
        if L == 0 && plain {
            ruin(x, w, b.def.h[0] + 8, b.x)
            if b.building { scaffold(b, x, b.def.h[1], 0) }
            c.restore()
            return
        }
        switch t {
        case .market: market(b, x, L)
        case .tea: tea(b, x, L)
        case .guard: barracks(b, x, L)
        case .pen: pen(b, x, L)
        case .temple: temple(b, x, L)
        case .well: well(b, x, L)
        case .gw, .ge: gate(b, x, L)
        case .bank: treasury(b, x, L)
        default: break
        }
        if plain && L >= 1 {
            topTier(b, x, L)
            // one gold pip by the door for each level raised
            for q in 0..<L { c.R(x + 2 + Double(q) * 2.6, GY - 2.6, 1.6, 1.6, rgba(28, 19, 12, 0.6)); c.R(x + 2.3 + Double(q) * 2.6, GY - 2.3, 1, 1, GOLD) }
        }
        if b.building && L >= 1 {
            let nh = b.def.h[min(L + 1, b.def.h.count - 1)]
            scaffold(b, x, nh, (b.def.gate || t == .well) ? 0 : b.tall)
        }
        if b.robbed && L > 0 && plain {
            fire(x + w * 0.28, GY - b.tall + 3, 1.2); fire(x + w * 0.7, GY - b.tall * 0.62, 1); fire(x + w * 0.5, GY - 6, 0.8)
        }
        c.restore()
    }

    func market(_ b: Building, _ x: Double, _ L: Int) {
        let w = b.w
        box(x, GY - 30, w, 30, MUD, MUD2, b.x); crenels(x, GY - 30, w, MUD)
        for k in 0..<3 {
            let ox = x + Double(k) * 25
            c.arch(ox + 6, GY - 19, 15, 19, DARKC)
            if lit { c.R(ox + 8, GY - 12, 11, 12, rgba(255, 200, 110, 0.5)); light(ox + 13, GY - 10, 20, 0.8) }
            c.R(ox + 8, GY - 5, 3, 5, Col(0xb5673a)); c.circ(ox + 16, GY - 3, 2.4, Col(0xc98a4a))
        }
        let aw: [Col] = [RED, TEAL, Col(0xe0a030)]
        for k in 0..<3 { awning(x + 3 + Double(k) * 25, GY - 23, 21, 6, aw[k], PLA, b.x + Double(k)) }
        // a string of lanterns across the stalls
        c.curve(x + 2, GY - 27, x + w / 2, GY - 23, x + w - 2, GY - 27, 0.35, Col(0x5a3e22))
        let lamp: [Col] = [RED, GOLD, TEAL, Col(0xe0a030)]
        for q in 0..<7 {
            let k = Double(q) / 6
            let lx = x + 4 + k * (w - 8), ly = GY - 27 + 4 * sin(PI * k) + 1
            c.R(lx - 1, ly, 2, 2.6, lit ? Col(0xffd27a) : lamp[q % 4])
            if lit && q % 2 == 0 { light(lx, ly + 1, 11, 0.55) }
        }
        let goods: [Col] = [Col(0xc7402a), Col(0xe0a030), Col(0x7a9a3a), Col(0x8a4a8a), Col(0xd9c070)]
        for i in 0..<5 {
            let sx = x + 5 + Double(i) * 15
            c.R(sx - 1, GY - 3, 8, 1, WOOD); c.poly(goods[i], [sx, GY - 3, sx + 3, GY - 7.5, sx + 6, GY - 3])
        }
        if L > 1 {
            box(x + 8, GY - 46, w - 16, 16, PLA, PLA2, b.x + 3); crenels(x + 8, GY - 46, w - 16, PLA)
            win(x + 16, GY - 41, 6, 9); win(x + 36, GY - 41, 6, 9); win(x + 56, GY - 41, 6, 9)
            c.R(x + 24, GY - 31, 9, 10, RED)
            for i in 0..<3 { c.R(x + 24, GY - 29 + Double(i) * 3, 9, 1, GOLD) }
            c.R(x + 45, GY - 31, 9, 8, LAPIS); c.R(x + 45, GY - 28, 9, 1, PLA)
        }
        if L > 2 {
            c.dome(x + w / 2, GY - 46, 9, TEAL)
            c.seg(x + w / 2, GY - 55, x + w / 2, GY - 59, 0.8, GOLD); c.circ(x + w / 2, GY - 59.5, 1.2, GOLD)
            pennant(x + 12, GY - 46, RED, 7); pennant(x + w - 13, GY - 46, Col(0xe0a030), 7)
        }
    }

    func tea(_ b: Building, _ x: Double, _ L: Int) {
        let w = b.w
        box(x, GY - 24, w, 24, PLA, PLA2, b.x)
        c.dome(x + 24, GY - 24, 11, Col(0xf6ecd2)); c.circ(x + 24, GY - 36, 1.2, GOLD)
        c.arch(x + 27, GY - 17, 12, 17, Col(0x5a3a22))
        if lit { c.R(x + 29, GY - 12, 8, 12, rgba(255, 200, 110, 0.6)); light(x + 33, GY - 9, 26, 1) }
        win(x + 8, GY - 17, 6, 9); win(x + 50, GY - 17, 6, 9)
        c.circ(x + 33, GY - 19.5, 1.5, lit ? Col(0xffd27a) : GOLD)
        awning(x + 42, GY - 20, 22, 5, LAPIS, PLA, b.x)
        c.R(x + 46, GY - 4, 12, 1, WOOD); c.R(x + 47, GY - 3, 1, 3, WOOD); c.R(x + 56, GY - 3, 1, 3, WOOD)
        c.ell(x + 44, GY - 1.5, 3, 1.5, RED); c.ell(x + 60, GY - 1.5, 3, 1.5, Col(0xe0a030))
        if L > 1 {
            c.R(x + 52, GY - 44, 10, 20, PLA); c.R(x + 52, GY - 44, 10, 1.2, Col(0xffffff))
            for i in 0..<4 { c.R(x + 53.5, GY - 41 + Double(i) * 3, 7, 1.2, DARKC) }
            c.dome(x + 8, GY - 24, 6, Col(0xf6ecd2))
        }
    }

    func barracks(_ b: Building, _ x: Double, _ L: Int) {
        let w = b.w
        box(x, GY - 28, w, 28, MUD2, MUDD, b.x); crenels(x, GY - 28, w, MUD2)
        c.arch(x + 8, GY - 18, 12, 18, DARKC); c.R(x + 9, GY - 13, 10, 13, Col(0x5a3a22))
        c.circ(x + 36, GY - 17, 5, RED); c.circ(x + 36, GY - 17, 1.6, GOLD)
        c.seg(x + 29, GY - 9, x + 43, GY - 25, 0.8, WOOD); c.seg(x + 43, GY - 9, x + 29, GY - 25, 0.8, WOOD)
        if L > 1 {
            let th: Double = L > 2 ? 58 : 48
            box(x + 40, GY - th, 17, th - 28, MUD2, MUDD, b.x + 7); crenels(x + 40, GY - th, 17, MUD2)
            c.R(x + 46, GY - th + 6, 4, 7, DARKC); c.R(x + 45, GY - th - 5, 7, 1.5, Col(0x4a3a2a))
            fire(x + 48.5, GY - th - 5, 0.7)
            if L > 2 { pennant(x + 42, GY - th - 2, RED, 9) }
        }
    }

    func pen(_ b: Building, _ x: Double, _ L: Int) {
        let w = b.w
        c.R(x, GY - 9, w, 9, MUD); c.R(x, GY - 9, w, 1, Col(0xe0c08a)); c.R(x + 31, GY - 8, 9, 8, WOOD)
        for i in 0..<3 { c.R(x + 31 + Double(i) * 3.4, GY - 8, 0.6, 8, Col(0x5a3e22)) }
        c.poly(Col(0xb89a54), [x + 2, GY - 20, x + 28, GY - 24, x + 30, GY - 19, x, GY - 16])
        c.seg(x + 3, GY - 17, x + 3, GY - 9, 1, WOOD); c.seg(x + 27, GY - 20, x + 27, GY - 9, 1, WOOD)
        let cc = Col(0x8a5a32)
        c.ell(x + 15, GY - 12, 6.5, 3, cc); c.circ(x + 12.5, GY - 15, 2.3, cc); c.circ(x + 17.5, GY - 15, 2.3, cc)
        c.seg(x + 21, GY - 12, x + 23.5, GY - 17, 1.8, cc); c.R(x + 22.5, GY - 18.5, 4, 2, cc)
        c.R(x + 46, GY - 12, 20, 3, WOOD); c.R(x + 47, GY - 11.5, 18, 1.5, Col(0x4a8fa6))
        if L > 1 {
            c.poly(Col(0xb89a54), [x + 44, GY - 24, x + 70, GY - 20, x + 72, GY - 16, x + 42, GY - 19])
            c.seg(x + 45, GY - 20, x + 45, GY - 9, 1, WOOD); c.seg(x + 69, GY - 17, x + 69, GY - 9, 1, WOOD)
        }
    }

    func temple(_ b: Building, _ x: Double, _ L: Int) {
        let w = b.w
        let h: Double = L > 1 ? 56 : 44
        for side in 0..<2 {
            let px = side == 0 ? x : x + w - 27
            c.poly(STONE, [px, GY, px + 3, GY - h, px + 24, GY - h, px + 27, GY])
            if side == 0 { c.poly(STONE2, [px + 22, GY, px + 21, GY - h, px + 24, GY - h, px + 27, GY]) } else {
                c.poly(STONE2, [px, GY, px + 3, GY - h, px + 6, GY - h, px + 5, GY])
            }
            c.poly(STONE, [px + 2, GY - h, px, GY - h - 3.5, px + 27, GY - h - 3.5, px + 25, GY - h])
            c.R(px, GY - h - 3.5, 27, 1, Col(0xf0dcae)); c.R(px + 3, GY - h + 3, 21, 2, TEAL); c.R(px + 3, GY - h + 6, 21, 1, RED)
            for i in 0..<3 { c.R(px + 7 + Double(i) * 5, GY - h + 12, 2, 4 + Double((i * 7) % 3), Col(0x8a6a44)) }
            c.R(px + 4, GY - 14, 19, 1, TEAL)
            pennant(px + 13, GY - h - 3, side == 0 ? RED : LAPIS, 8)
        }
        c.R(x + 27, GY - 30, w - 54, 30, DARKC); c.R(x + 25, GY - 33, w - 50, 4, STONE); c.circ(x + w / 2, GY - 36, 2.6, GOLD)
        if lit { c.R(x + 29, GY - 22, w - 58, 22, rgba(255, 190, 100, 0.45)); light(x + w / 2, GY - 14, 30, 1) }
        for cx in [x + 29, x + w - 33] {
            c.R(cx, GY - 26, 4, 26, Col(0xe6d2a2)); c.R(cx - 1, GY - 28, 6, 2.5, TEAL); c.R(cx - 0.5, GY - 1.5, 5, 1.5, STONE2)
        }
        // doves on the pylons by day
        if g.dark < 0.3 {
            for q in 0..<4 {
                let n = Double(q)
                let hop = max(0, sin(NOW * 0.7 + n * 1.9) - 0.86) * 60
                let dx = x + 5 + n * 7 + (q > 1 ? w - 44 : 0)
                let dy = GY - h - 5.4 - hop
                c.ell(dx, dy, 1.7, 1.1, Col(0xf6f2e8)); c.R(dx + 1.2, dy - 1.4, 1.2, 1.2, Col(0xf6f2e8))
                if hop > 0 { c.seg(dx - 2.4, dy - 1 - sin(NOW * 30) * 1.4, dx + 1.6, dy - 0.4, 0.6, Col(0xf6f2e8)) }
            }
        }
    }

    func well(_ b: Building, _ x: Double, _ L: Int) {
        fire(x - 13, GY - 1, 1); c.R(x - 17, GY - 1.5, 8, 1.5, Col(0x4a3a2a))
        if L == 0 {
            for i in 0..<5 {
                let n = Double(i)
                c.R(x + n * 3, GY - 2 - hashN(n) * 4, 3, 6, i % 2 == 1 ? STONE2 : Col(0x8f744a))
            }
            c.poly(SAND2, [x - 4, GY, x + 8, GY - 3, x + 20, GY])
            if b.building { scaffold(b, x, 18, 0) }
            return
        }
        var i = -40.0
        while i < 64 { c.R(x + i, GY, 5, 1.5, Int(i / 6) % 2 == 0 ? Col(0xb39466) : Col(0xc2a374)); i += 6 }
        c.R(x, GY - 6, 15, 6, STONE); c.R(x, GY - 6, 15, 1.2, Col(0xecd6a4)); c.R(x + 12.5, GY - 6, 2.5, 6, STONE2)
        c.seg(x + 1.5, GY - 6, x + 1.5, GY - 19, 1.2, WOOD); c.seg(x + 13.5, GY - 6, x + 13.5, GY - 19, 1.2, WOOD)
        c.R(x, GY - 20, 15, 1.5, WOOD)
        c.poly(Col(0xb89a54), [x - 2, GY - 20, x + 7.5, GY - 25, x + 17, GY - 20])
        c.seg(x + 7.5, GY - 18.5, x + 7.5, GY - 10, 0.4, Col(0xe6d2a2)); c.R(x + 6, GY - 10, 3, 2.5, WOOD)
        palm(x + 40, 30, 1, b.x, false); palm(x - 34, 24, 0.85, b.x + 3, false)
        if L > 1 {
            let ox = x + 21
            c.R(ox - 3, GY - 4, 13, 4, STONE); c.R(ox - 3, GY - 4, 13, 1, Col(0xecd6a4))
            c.poly(Col(0xdcc08a), [ox, GY - 4, ox + 1.6, GY - 70, ox + 5.4, GY - 70, ox + 7, GY - 4])
            c.poly(STONE2, [ox + 5, GY - 4, ox + 4.2, GY - 70, ox + 5.4, GY - 70, ox + 7, GY - 4])
            c.poly(GOLD, [ox + 1.6, GY - 70, ox + 3.5, GY - 77, ox + 5.4, GY - 70])
            light(ox + 3.5, GY - 72, 16, 0.5)
        }
    }

    func gate(_ b: Building, _ x: Double, _ L: Int) {
        let e = b.type == .ge
        if L == 0 {
            c.alpha(0.55); c.R(x + 2, GY - 5, 2, 5, WOOD); c.R(x + 9, GY - 3, 2, 3, WOOD); c.alpha(1)
            if b.building { scaffold(b, x, 16, 0) }
            return
        }
        if b.hp <= 0 {
            c.poly(MUDD, [x - 4, GY, x + 2, GY - 6, x + 8, GY - 3, x + 13, GY - 7, x + 19, GY])
            return
        }
        if L == 1 {
            for i in 0..<5 {
                let lx = x + Double(i) * 2.9
                let odd = i % 2 == 1
                let top = GY - 14 - (odd ? 1.0 : 0.0)
                let col = odd ? WOOD : Col(0x8f6a3e)
                c.R(lx, top, 2.5, GY - top, col)
                c.poly(col, [lx, top, lx + 1.25, top - 3, lx + 2.5, top])
            }
            c.R(x - 1, GY - 9, 16, 1.2, Col(0x5a3e22))
        } else {
            let h: Double = L > 2 ? 34 : 24
            if L > 2 { c.poly(STONE, [x - 2, GY, x, GY - h, x + 14, GY - h, x + 16, GY]) } else { box(x, GY - h, 14, h, MUD2, MUDD, b.x) }
            crenels(x, GY - h, 14, L > 2 ? STONE : MUD2)
            c.arch(x + 3, GY - 13, 8, 13, Col(0x5a3a22)); c.R(x + 6.7, GY - 11, 0.6, 11, DARKC)
            if L > 2 { c.R(x, GY - h + 3, 14, 1.5, TEAL); pennant(x + 7, GY - h - 2, RED, 7) }
            fire(x + (e ? -3 : 17), GY - 12, 0.6); c.R(x + (e ? -3.5 : 16.5), GY - 12, 1, 12, WOOD)
        }
        let full = GHP[L]
        if b.hp < full {
            let th = b.tall
            c.R(x - 1, GY - th - 7, 16, 2, rgba(28, 19, 12, 0.7))
            c.R(x - 1, GY - th - 7, 16 * b.hp / full, 2, b.hp / full > 0.4 ? GOLD : RED)
        }
    }

    func treasury(_ b: Building, _ x: Double, _ L: Int) {
        let w = b.w
        let h: Double = L > 1 ? 38 : 32
        c.poly(STONE, [x, GY, x + 4, GY - h, x + w - 4, GY - h, x + w, GY])
        c.poly(STONE2, [x + w - 6, GY, x + w - 8, GY - h, x + w - 4, GY - h, x + w, GY])
        c.poly(STONE, [x + 2, GY - h, x, GY - h - 4, x + w, GY - h - 4, x + w - 2, GY - h])
        c.R(x, GY - h - 4, w, 1, Col(0xecd6a4))
        var y = 6.0
        while y < h { c.R(x + 4, GY - y, w - 9, 0.5, STONE2); y += 6 }
        c.R(x + 21, GY - 20, 14, 20, Col(0x6a4a2a)); c.R(x + 21, GY - 20, 14, 1.5, GOLD)
        c.circ(x + 28, GY - 11, 2.6, GOLD); c.circ(x + 28, GY - 11, 1, Col(0x8a5f14))
        c.R(x + 10, GY - 22, 2, 8, DARKC); c.R(x + 44, GY - 22, 2, 8, DARKC)
        if L > 1 { c.R(x + 3, GY - h + 1, w - 6, 2, GOLD) }
        // what is in the vault, stacked by the door
        let stack = min(8, g.bank)
        if stack > 0 { for i in 0..<stack { c.ell(x + 40, GY - 1.2 - Double(i) * 1.3, 2.2, 0.9, GOLD) } }
    }

    /// The upgrade signposts by the barracks and the camel yard.
    func shopSigns() {
        for sh in g.shops {
            if g.B(sh.k).level == 0 { continue }
            let x = g.shopX(sh.k) - cam
            if x < -20 || x > W + 20 { continue }
            let it = g.shopItem(sh.k)
            c.seg(x, GY, x, GY - 13, 1, WOOD)
            c.R(x - 4.5, GY - 17, 9, 7, it != nil ? Col(0xecdcb0) : Col(0xb8a888))
            c.R(x - 4.5, GY - 17, 9, 0.7, Col(0xffffff)); c.R(x - 4.5, GY - 10.6, 9, 0.6, Col(0x7a5a2e))
            guard let item = it else { continue }
            upIcon(item.key, x, GY - 13.4)
            if abs(g.player.x - g.shopX(sh.k)) < 46 || sh.paid + sh.inc > 0 {
                let cols = min(item.cost, 7)
                for q in 0..<item.cost {
                    let row = q / cols
                    let inRow = min(cols, item.cost - row * cols)
                    let sx = x - Double(inRow - 1) * 3 + Double(q % cols) * 6
                    let sy = GY - 24 - Double(row) * 6
                    c.circ(sx, sy, 2.3, rgba(28, 19, 12, 0.75))
                    c.circ(sx, sy, 1.7, q < sh.paid ? GOLD : rgba(242, 193, 78, 0.22))
                }
            }
        }
    }
    func upIcon(_ n: String, _ x: Double, _ cy: Double) {
        let brown = Col(0x8a5a32)
        switch n {
        case "quiver":
            c.R(x - 1.4, cy - 2.2, 2.8, 4.8, Col(0x7a4e2a))
            for q in 0..<3 { c.R(x - 1 + Double(q) * 0.9, cy - 3.4, 0.5, 1.4, RED) }
        case "fire":
            c.seg(x - 3, cy + 1.4, x + 2, cy - 1.4, 0.6, Col(0x5a3e22))
            c.poly(Col(0xe8602a), [x + 1, cy - 0.6, x + 3.4, cy - 3.4, x + 3, cy]); c.R(x + 2, cy - 1.6, 1, 1, Col(0xffc24a))
        case "falcon":
            c.poly(Col(0x6a4a30), [x - 3.4, cy - 1.4, x, cy + 0.6, x + 3.4, cy - 1.4, x, cy - 0.4]); c.R(x - 0.6, cy - 0.4, 1.2, 2.2, Col(0x6a4a30))
        case "saddle":
            c.R(x - 3, cy - 1.4, 6, 3.4, RED); c.R(x - 3, cy - 1.4, 6, 0.7, GOLD); c.R(x - 3, cy + 1.4, 6, 0.6, GOLD)
        default:
            c.ell(x - 0.6, cy + 0.4, 2.8, 1.5, brown); c.circ(x - 1.8, cy - 1.2, 1.1, brown); c.circ(x + 0.4, cy - 1.2, 1.1, brown)
            c.seg(x + 2, cy, x + 3.2, cy - 2.4, 0.8, brown); c.R(x - 4, cy + 2, 2, 0.5, GOLD)
        }
    }

    func caravan(_ cv: Caravan) {
        let mv: Double = cv.stopped ? 0 : 1
        let loads: [Col] = [RED, LAPIS, Col(0xe0a030)]
        for i in 0..<3 {
            var co = CamelOpt()
            co.col = Col(0xa07244); co.dk = Col(0x70502c); co.lt = Col(0xc0915c); co.load = loads[i]
            let n = Double(i)
            camel(cv.x - n * 30, 1, cv.ph + n, mv * 0.45, co)
            if i > 0 { c.seg(cv.x - n * 30 + 15 - cam, GY - 22, cv.x - (n - 1) * 30 - 11 - cam, GY - 14, 0.4, Col(0x5a3e22)) }
        }
        var o = PersonOpt(robe: Col(0xf3ead2), turban: LAPIS, skin: SKIN[0])
        o.moving = mv > 0; o.walk = cv.ph * 1.4; o.tool = .staff
        person(cv.x + 22, 0, o)
        if cv.stopped && !cv.sold && g.B(.market).level > 0 {
            for i in 0..<4 {
                let x = cv.x + 13 + Double(i) * 6 - cam, y = GY - 21
                c.circ(x, y, 2.3, rgba(28, 19, 12, 0.75))
                c.circ(x, y, 1.7, i < cv.paid ? GOLD : rgba(242, 193, 78, 0.22))
            }
        }
    }

    /// What the new top levels add to each building.
    func topTier(_ b: Building, _ x: Double, _ L: Int) {
        let w = b.w
        switch b.type {
        case .market where L >= 4:
            c.dome(x + 16, GY - 46, 5, GOLD); c.dome(x + w - 16, GY - 46, 5, GOLD)
            c.R(x + 8, GY - 47, w - 16, 1.2, GOLD)
            for q in 0..<6 { pennant(x + 14 + Double(q) * 10, GY - 47, q % 2 == 0 ? RED : TEAL, 5) }
        case .tea where L >= 3:
            c.R(x + 2, GY - 25.5, w - 4, 1.5, WOOD)
            awning(x + 4, GY - 36, 22, 4, RED, PLA, b.x + 9)
            c.R(x + 30, GY - 30, 5, 5, Col(0x4d8a3c)); c.R(x + 37, GY - 31, 4, 6, Col(0x3f7d3a)); c.R(x + 29, GY - 26, 14, 1.4, Col(0xb5673a))
        case .guard where L >= 4:
            box(x + 2, GY - 44, 14, 16, MUD2, MUDD, b.x + 11); crenels(x + 2, GY - 44, 14, MUD2)
            c.R(x + 7, GY - 40, 4, 6, DARKC); pennant(x + 9, GY - 46, GOLD, 9)
            c.R(x, GY - 29, w, 1.2, GOLD)
        case .pen where L >= 3:
            c.poly(Col(0xc9a45a), [x - 2, GY - 30, x + 74, GY - 27, x + 76, GY - 23, x - 4, GY - 25])
            c.seg(x + 1, GY - 26, x + 1, GY - 9, 1.2, WOOD); c.seg(x + 71, GY - 24, x + 71, GY - 9, 1.2, WOOD)
            pennant(x + 36, GY - 28, TEAL, 8)
            let cc = Col(0xa07244)
            c.ell(x + 56, GY - 12, 5.5, 2.6, cc); c.circ(x + 54, GY - 14.6, 2, cc); c.circ(x + 58, GY - 14.6, 2, cc); c.seg(x + 51, GY - 12, x + 49, GY - 16.5, 1.6, cc)
        case .temple where L >= 3:
            for ox in [x - 7, x + w + 3] {
                c.poly(Col(0xdcc08a), [ox, GY, ox + 1, GY - 60, ox + 3.4, GY - 60, ox + 4.4, GY])
                c.poly(GOLD, [ox + 1, GY - 60, ox + 2.2, GY - 66, ox + 3.4, GY - 60])
            }
            c.R(x, GY - 59.6, 27, 1, GOLD); c.R(x + w - 27, GY - 59.6, 27, 1, GOLD)
        case .bank where L >= 3:
            c.dome(x + w / 2, GY - 42, 12, GOLD); c.dome(x + w / 2 - 3, GY - 44, 7, Col(0xfff3b8).alpha(0.5))
            c.seg(x + w / 2, GY - 54, x + w / 2, GY - 59, 0.8, GOLD)
        default:
            break
        }
    }

    func rack(_ b: Building) {
        guard b.level > 0, let tool = b.def.tool else { return }
        let x = g.rackX(b) - cam
        if x < -20 || x > W + 20 { return }
        c.seg(x - 5, GY, x - 5, GY - 9, 0.8, WOOD); c.seg(x + 5, GY, x + 5, GY - 9, 0.8, WOOD); c.R(x - 6, GY - 9, 12, 1, WOOD)
        for i in 0..<3 {
            let tx = x - 3 + Double(i) * 3
            c.alpha(i < b.badges ? 1 : 0.25)
            switch tool {
            case .digger:
                c.seg(tx, GY - 1, tx, GY - 8, 0.7, Col(0x8f6a3e)); c.seg(tx - 1.5, GY - 7, tx + 1.5, GY - 8, 0.9, Col(0x9aa0a0))
            case .guard:
                c.seg(tx, GY - 1, tx, GY - 10, 0.6, Col(0x8f6a3e)); c.poly(Col(0xd0d0c8), [tx - 0.9, GY - 10, tx, GY - 13, tx + 0.9, GY - 10])
            default:
                c.seg(tx, GY - 1, tx, GY - 9, 0.6, Col(0x8f6a3e)); c.arcStroke(tx + 1, GY - 9, 1, PI, PI * 2, 0.6, Col(0x8f6a3e))
            }
        }
        c.alpha(1)
    }

    func slots(_ b: Building) {
        let cost = g.costOf(b)
        if cost == 0 || b.building { return }
        if abs(g.player.x - b.mid) > b.w / 2 + 14 && b.paid + b.incoming == 0 { return }
        if g.scene != nil { return }
        for i in 0..<cost {
            let s = g.slotPos(b, i, cost)
            let x = s.x - cam, y = GY - s.h
            c.circ(x, y, 2.3, rgba(28, 19, 12, 0.75))
            c.circ(x, y, 1.7, i < b.paid ? GOLD : rgba(242, 193, 78, 0.22))
            if i < b.paid { c.R(x - 0.9, y - 0.9, 0.8, 0.8, Col(0xfff3b8)) }
        }
    }

    // ---------- the far places, the dock and the things to find
    func cliffs(_ hz: Col) {
        let rock = Col.mix(Col(0xb8693e), hz, 0.35), shade = Col.mix(Col(0x8a4a2a), hz, 0.35)
        for i in 0..<9 {
            let n = Double(i)
            let x = n * 120 - cam * 0.07 - 60 + hashN(n + 3) * 30
            if x < -140 || x > W + 20 { continue }
            let w = 90 + hashN(n + 5) * 50, h = 40 + hashN(n + 7) * 34
            c.poly(rock, [x, GY - 14, x + 8, GY - 14 - h, x + w - 10, GY - 14 - h + 4, x + w, GY - 14])
            c.poly(shade, [x + w * 0.62, GY - 14, x + w * 0.66, GY - 14 - h + 3, x + w - 10, GY - 14 - h + 4, x + w, GY - 14])
            var q = 8.0
            while q < h { c.R(x + 6, GY - 14 - q, w - 14, 0.6, rgba(70, 30, 14, 0.2)); q += 9 }
        }
    }
    func sites() {
        if g.OASIS > 0 { oasis() }
        let sp = g.B(.sphinx); if !sp.gone { sphinx(sp) }
        let tb = g.B(.tomb); if !tb.gone { tomb(tb) }
        let hm = g.B(.hermit); if !hm.gone { hermit(hm) }
        let bt = g.B(.btemple); if !bt.gone { btemple(bt) }
        dock(g.B(.dock))
        fishing()
        digSite()
        extras()
    }
    /// Mirages, dust devils, the trapped road and the night visitor.
    func extras() {
        if g.dark < 0.2 && g.storm == nil {
            for mx in [g.TOWN.0 - 700, g.TOWN.1 + 620] {
                let d = abs(g.player.x - mx)
                let x = mx - cam
                if d < 150 || x < -60 || x > W + 60 || mx < 80 || mx > g.NILE - 200 { continue }
                c.alpha(clampD((d - 150) / 120, 0, 1) * 0.55)
                c.ell(x, GY + 2.6, 34, 1.6, Col(0x9fd8e8)); c.ell(x - 6 + sin(NOW * 1.3) * 3, GY + 2.2, 18, 0.7, Col(0xffffff))
                c.alpha(1)
            }
            for dv in g.devils {
                let x = dv.x - cam
                if x < -20 || x > W + 20 || (dv.x > g.TOWN.0 - 60 && dv.x < g.TOWN.1 + 60) { continue }
                for q in 0..<7 {
                    let n = Double(q)
                    c.ell(x + sin(NOW * 6 + n * 0.9) * (1.5 + n * 0.7), GY - 2 - n * 4, 2 + n * 1.1, 1.3, rgba(226, 196, 140, 0.34 - n * 0.03))
                }
            }
        }
        let traps = g.trapXs()
        for i in 0..<traps.count {
            let x = traps[i] - cam
            if x < -12 || x > W + 12 { continue }
            c.R(x - 6, GY - 0.6, 12, 1.4, Col(0x6a5a48)); c.R(x - 6, GY - 0.6, 12, 0.4, Col(0x9a8a70))
            if g.trapUp(i) {
                for q in 0..<4 {
                    let sx = x - 4.5 + Double(q) * 3
                    c.poly(Col(0xc8c8c0), [sx - 1, GY - 0.6, sx, GY - 7.5, sx + 1, GY - 0.6])
                }
            }
        }
        if let u = g.ufo {
            let x = u.x - cam, y = GY - u.h + sin(NOW * 2.2) * 1.5
            if x > -80 && x < W + 80 {
                if u.phase == 1 {
                    c.poly(rgba(150, 255, 220, 0.16 + 0.05 * sin(NOW * 7)), [x - 6, y + 3, x + 6, y + 3, x + 26, GY + 2, x - 26, GY + 2])
                    c.ell(x, GY + 1.6, 24, 2, rgba(180, 255, 230, 0.3))
                }
                c.ell(x, y, 19, 4.2, Col(0x8a94a4)); c.ell(x, y - 1, 18, 2.6, Col(0xc4ccd8)); c.dome(x, y - 2, 7.5, Col(0x9fe8d8))
                c.ell(x - 2, y - 5.4, 2.6, 1.4, rgba(255, 255, 255, 0.6))
                for q in 0..<5 {
                    let on = Int(NOW * 6) % 5 == q
                    c.circ(x - 12 + Double(q) * 6, y + 1.2, 1.1, on ? Col(0xfff3b0) : Col(0x4a8a80))
                }
                light(x, y + 4, 60, 1); light(x, GY - 6, 44, u.phase == 1 ? 0.9 : 0.3)
            }
        }
    }
    private func rising(_ b: Building, _ x: Double) {
        if b.building { scaffold(b, x, b.def.h[min(b.level + 1, b.def.h.count - 1)], 0) }
    }
    func sphinx(_ b: Building) {
        let x = b.x - cam
        if x > W + 20 || x + b.w < -20 { return }
        if b.level == 0 {
            c.poly(SAND2, [x - 6, GY, x + 20, GY - 9, x + 58, GY - 12, x + 90, GY])
            c.R(x + 57, GY - 22, 13, 12, STONE); c.R(x + 57, GY - 22, 13, 1.5, Col(0xecd6a4)); c.R(x + 67, GY - 18, 1.5, 1.5, DARKC)
            c.poly(SAND, [x + 50, GY, x + 62, GY - 11, x + 78, GY])
        } else {
            c.ell(x + 42, GY + 1, 44, 2.4, rgba(60, 34, 8, 0.25))
            c.R(x + 6, GY - 15, 56, 15, STONE); c.ell(x + 12, GY - 12, 11, 12, STONE); c.R(x + 6, GY - 3, 56, 3, STONE2)
            c.R(x + 58, GY - 7, 24, 7, STONE); c.R(x + 58, GY - 7, 24, 1.2, Col(0xecd6a4)); c.R(x + 78, GY - 6, 4, 6, STONE2)
            c.poly(LAPIS, [x + 50, GY - 14, x + 54, GY - 40, x + 70, GY - 40, x + 74, GY - 14])
            for i in 0..<5 { c.R(x + 52, GY - 37 + Double(i) * 5, 20, 1.4, GOLD) }
            c.R(x + 56, GY - 36, 13, 17, STONE); c.R(x + 65, GY - 31, 2, 2, DARKC); c.R(x + 67, GY - 26, 3, 1.2, STONE2); c.R(x + 61, GY - 20, 5, 6, STONE2)
        }
        rising(b, x)
    }
    func tomb(_ b: Building) {
        let x = b.x - cam
        if x > W + 20 || x + b.w < -40 { return }
        c.poly(STONE, [x - 6, GY, x + 25, GY - 36, x + 56, GY])
        c.poly(STONE2, [x + 25, GY - 36, x + 56, GY, x + 34, GY])
        var q = 6.0
        while q < 34 { c.R(x - 6 + q * 0.86, GY - q, 31 - q * 0.86 + 9 - q * 0.26, 0.5, rgba(110, 78, 36, 0.25)); q += 6 }
        if b.level > 0 {
            c.R(x + 19, GY - 14, 10, 14, DARKC); c.R(x + 18, GY - 16, 12, 2, GOLD)
            c.R(x + 21, GY - 10, 6, 10, rgba(255, 190, 90, 0.35))
            light(x + 24, GY - 7, 14, 0.5)
        } else {
            c.R(x + 19, GY - 9, 10, 9, DARKC)
            c.poly(SAND, [x + 8, GY, x + 20, GY - 8, x + 30, GY - 5, x + 40, GY])
        }
        rising(b, x)
    }
    func oasis() {
        let x = g.OASIS - cam
        if x > W + 70 || x < -70 { return }
        let b = g.B(.grove)
        let sk = skyAt(g.t)
        let wc = Col.mix(sk.0, Col(0x247896), 0.55), wl = Col.mix(sk.1, Col(0x62bacc), 0.5)
        // the far reach, running down from the horizon
        c.poly(Col(0x7aa24a), [x - 12, GY - 24, x + 12, GY - 24, x + 50, GY + 1, x - 50, GY + 1])
        c.poly(wc, [x - 5, GY - 23, x + 5, GY - 23, x + 38, GY + 1, x - 38, GY + 1])
        c.alpha(0.55); c.poly(wl, [x - 2, GY - 23, x + 1, GY - 23, x + 8, GY + 1, x - 20, GY + 1]); c.alpha(1)
        // the near reach, across the road and off the bottom of the screen
        c.poly(Col(0x8fb85a), [x - 52, GY, x - 38, GY, x - 62, H, x - 80, H])
        c.poly(Col(0x8fb85a), [x + 38, GY, x + 52, GY, x + 80, H, x + 62, H])
        c.poly(wc, [x - 38, GY, x + 38, GY, x + 62, H, x - 62, H])
        c.alpha(0.5); c.poly(wl, [x - 20, GY, x + 8, GY, x + 14, H, x - 34, H]); c.alpha(1)
        for i in 0..<5 {
            let n = Double(i)
            let u = (NOW * 0.22 + n * 0.2).truncatingRemainder(dividingBy: 1)
            let hw = 5 + u * 33
            c.R(x - hw * 0.6 + hashN(n + 60) * hw, GY - 22 + u * 22, 2 + u * 5, 0.4, rgba(255, 255, 255, 0.45))
        }
        for i in 0..<10 {
            let n = Double(i)
            let u = (NOW * 0.16 + hashN(n + 70)).truncatingRemainder(dividingBy: 1)
            let hw = 38 + u * 24
            c.R(x - hw * 0.8 + hashN(n + 71) * hw * 1.5, GY + 3 + u * (H - GY - 4), 5 + u * 8, 0.6, rgba(255, 255, 255, 0.4 * sin(PI * u)))
        }
        for i in 0..<7 {
            let n = Double(i)
            let k = n / 6
            let lx = x - 40 - k * 20 + hashN(n) * 3, rx = x + 40 + k * 20 - hashN(n + 3) * 3
            let yy = GY + 2 + k * (H - GY - 8)
            c.seg(lx, yy, lx + sin(NOW * 2 + n) * 0.9, yy - 6 - hashN(n + 4) * 4, 0.7, Col(0x4d8a3c))
            c.seg(rx, yy, rx + sin(NOW * 2 + n + 2) * 0.9, yy - 6 - hashN(n + 5) * 4, 0.7, Col(0x4d8a3c))
            if i % 3 == 0 { c.R(lx - 0.6, yy - 9, 1.4, 3, Col(0x6a4a2a)); c.R(rx - 0.6, yy - 9, 1.4, 3, Col(0x6a4a2a)) }
        }
        // the plank bridge the road crosses on
        for px in [-34.0, -12, 12, 34] {
            c.R(x + px - 0.9, GY + 2, 1.8, 9 + abs(px) * 0.08, Col(0x4a2e18))
            c.ell(x + px, GY + 11 + abs(px) * 0.08, 3, 0.7, rgba(255, 255, 255, 0.3))
        }
        c.R(x - 46, GY - 0.4, 92, 3, Col(0x8a6434)); c.R(x - 46, GY - 0.4, 92, 0.8, Col(0xb08854)); c.R(x - 46, GY + 2.2, 92, 0.6, Col(0x4a2e18))
        for q in 0..<23 { c.R(x - 46 + Double(q) * 4, GY - 0.4, 0.5, 2.6, Col(0x5e3a1e)) }
        for px in [-45.0, -22, 0, 22, 44] { c.R(x + px - 0.6, GY - 9, 1.2, 9, Col(0x5e3a1e)) }
        for q in 0..<4 {
            let x0 = x - 45 + Double(q) * 22.3
            c.curve(x0, GY - 8.6, x0 + 11, GY - 5.6, x0 + 22.3, GY - 8.6, 0.5, Col(0xc9a876))
        }
        let tended = b.level > 0
        palm(x - 56, 34, 1.1, 7, false); palm(x + 54, 28, 1, 11, false); palm(x + 68, 22, 0.8, 13, false)
        if tended {
            let offs: [Double] = [-74, -62, -50, 48, 62, 76]
            for i in 0..<6 { palm(x + offs[i], 24 + hashN(Double(i) + 20) * 14, 0.9, 30 + Double(i), true) }
        }
        if !b.gone { rising(b, b.x - cam) }
    }
    func hermit(_ b: Building) {
        let x = b.x - cam
        if x > W + 20 || x + b.w < -20 { return }
        c.poly(Col(0x9c8258), [x - 4, GY, x + 4, GY - 20, x + 20, GY - 30, x + 38, GY - 22, x + 48, GY])
        c.poly(Col(0x7a6240), [x + 20, GY - 30, x + 38, GY - 22, x + 48, GY, x + 32, GY])
        c.arch(x + 12, GY - 16, 14, 16, DARKC)
        fire(x + 34, GY - 1, 0.7)
        var o = PersonOpt(robe: Col(0xf3ead2), turban: Col(0xf3ead2), skin: SKIN[1])
        o.beard = Col(0xf0ece2); o.tool = .staff
        person(b.x + 22, 0, o)
        for i in 0..<3 {
            c.circ(x + 14 + Double(i) * 8, GY - 36, 2.2, i < b.level ? rgba(28, 19, 12, 0.3) : GOLD)
        }
    }
    func btemple(_ b: Building) {
        let x = b.x - cam
        if x > W + 20 || x + b.w < -20 { return }
        if b.level == 0 {
            c.poly(SAND2, [x - 8, GY, x + 20, GY - 8, x + 60, GY - 10, x + 98, GY])
            for i in 0..<4 {
                let cx = x + 12 + Double(i) * 22
                let h = 6 + hashN(Double(i) + 4) * 9
                c.R(cx, GY - 8 - h, 6, h + 4, Col(0xe6d2a2)); c.R(cx - 1, GY - 10 - h, 8, 2.4, TEAL)
            }
        } else {
            c.R(x, GY - 4, 90, 4, STONE2)
            c.R(x + 4, GY - 40, 82, 6, STONE); c.R(x + 4, GY - 40, 82, 1.2, GOLD); c.R(x + 4, GY - 36, 82, 1.6, TEAL)
            c.poly(STONE, [x + 2, GY - 40, x + 45, GY - 50, x + 88, GY - 40])
            c.R(x + 14, GY - 34, 62, 30, DARKC)
            for i in 0..<5 {
                let cx = x + 8 + Double(i) * 18
                c.R(cx, GY - 34, 6, 30, Col(0xecdcb0)); c.R(cx + 4.4, GY - 34, 1.6, 30, rgba(90, 60, 20, 0.3)); c.R(cx - 1, GY - 35, 8, 2.4, TEAL)
            }
            if lit { light(x + 45, GY - 16, 30, 0.8) }
        }
        rising(b, x)
    }
    func dock(_ b: Building) {
        let x = b.x - cam
        if x > W + 40 { return }
        if b.level == 0 {
            for i in 0..<4 { c.R(x + 6 + Double(i) * 14, GY - 4 - Double(i % 2) * 3, 2, 8, WOOD) }
        } else {
            c.R(x - 2, GY - 2.4, 82, 2.4, Col(0x8a6434)); c.R(x - 2, GY - 2.4, 82, 0.6, Col(0xd8ba88))
            for i in 0..<9 { c.R(x + Double(i) * 9, GY - 2.4, 0.6, 2.4, Col(0x5e3a1e)) }
            for i in 0..<3 { c.R(x + 62 + Double(i) * 8, GY, 1.6, 8, Col(0x5e3a1e)) }
            // the felucca, waiting or under way
            let away = (g.trip ?? 0) * 26
            let bx = x + 78 + away, by = GY + 3 + sin(NOW * 1.6) * 0.6
            c.poly(Col(0x6a4426), [bx - 16, by - 4, bx + 18, by - 4, bx + 13, by + 2, bx - 11, by + 2])
            c.R(bx - 16, by - 5, 34, 1.2, Col(0xd8ba88))
            c.seg(bx - 2, by - 4, bx - 2, by - 30, 1, WOOD)
            c.poly(Col(0xf6efdc), [bx - 1, by - 30, bx + 16, by - 9, bx - 1, by - 7])
            c.seg(bx - 2, by - 30, bx - 12, by - 5, 0.4, Col(0x5a3e22))
            if g.trip != nil {
                rider(bx - 6, by - 2, 1, RiderOpt(robe: Col(0xf6efdc), skin: Col(0xb8804e), turban: GOLD, sash: TEAL, veil: nil, fl: 0.4, jewel: true))
            }
        }
        rising(b, x)
    }
    func fishing() {
        let spots = g.fishSpots()
        for i in 0..<2 {
            let fx = spots[i]
            if fx <= 0 { continue }
            let x = fx - cam
            if x < -70 || x > W + 70 { continue }
            let s = i == 1 ? x - 26 : x + 30
            c.R(s - 11, GY - 24, 1.4, 24, WOOD); c.R(s + 11, GY - 24, 1.4, 24, WOOD); c.R(s - 12.6, GY - 25, 26, 1.4, WOOD)
            for q in 0..<9 {
                let k = Double(q) / 8
                let nx = s - 9.6 + k * 20
                c.seg(nx, GY - 23.6, nx + sin(NOW * 1.6 + Double(q) * 0.5) * 0.7, GY - 12.6 + 7 * sin(PI * k), 0.35, rgba(246, 236, 206, 0.85))
            }
            for q in 0..<min(4, g.rodN[i]) {
                let hx = s - 7 + Double(q) * 4.8, hy = GY - 11 + Double(q % 2) * 2
                c.ell(hx, hy, 1.3, 3, Col(0x9fb8c8)); c.poly(Col(0x7f98a8), [hx, hy + 2.6, hx - 1.6, hy + 5, hx + 1.6, hy + 5])
            }
            if g.rodSpot == i {
                let p = g.player
                let hx = p.x - cam + p.dir * 5, hy = GY - 23
                let tipx = hx + p.dir * 17, tipy = GY - 38
                let wx = (i == 1 ? g.NILE + 12 : fx - 13) - cam, wy = GY + (i == 1 ? 1.6 : 6) + sin(NOW * 3) * 0.8
                c.curve(hx, hy, hx + p.dir * 9, hy - 11, tipx, tipy, 1.1, Col(0x3a2410))
                c.curve(tipx, tipy, (tipx + wx) / 2, GY - 10, wx, wy, 0.45, rgba(255, 255, 255, 0.95))
                c.circ(wx, wy, 2, RED)
                c.ellStroke(wx, wy + 1.4, 4.6 + sin(NOW * 3) * 1.6, 1, 0.5, rgba(255, 255, 255, 0.5))
            } else if g.rodN[i] > 0 && abs(g.player.x - fx) < 46 {
                let by = GY - 34 + sin(NOW * 5) * 1.6
                c.poly(GOLD, [x - 3, by, x + 3, by, x, by + 5]); c.R(x - 7, GY + 0.2, 14, 1, GOLD)
            }
        }
    }
    func digSite() {
        let dx = g.digX
        if dx <= 0 { return }
        let x = dx - cam
        if x < -70 || x > W + 70 { return }
        c.poly(Col(0xb08854), [x - 34, GY, x - 22, GY - 7, x + 22, GY - 7, x + 34, GY])
        c.R(x - 15, GY - 34, 30, 28, Col(0x3a2814)); c.R(x - 11, GY - 30, 22, 30, Col(0x0c0604))
        c.R(x - 18, GY - 38, 36, 5, Col(0xc9a45a)); c.R(x - 18, GY - 38, 36, 1, Col(0xe8d08a))
        c.R(x - 17, GY - 33, 5, 27, Col(0xb99a64)); c.R(x + 12, GY - 33, 5, 27, Col(0xa98652))
        for q in 0..<max(0, 6 - g.digN) { c.R(x - 8.6 + Double(q) * 3.4, GY - 44, 2.4, 2.8, GOLD) }
        if g.digT > 0 {
            let k = clampD(g.digT / (3 + Double(g.digN) * 0.7), 0, 1)
            c.R(x - 14, GY - 50, 28, 3, rgba(28, 19, 12, 0.75)); c.R(x - 13.4, GY - 49.4, 26.8 * k, 1.8, GOLD)
            light(x, GY - 18, 34, 0.7)
        }
    }

    /// The whole valley in one strip along the bottom edge, and red arrows when raiders are off screen.
    func minimap() {
        let x0 = W * 0.31, w = W * 0.38, y = H - 4.6
        let span = g.NILE + 60
        func mx(_ wx: Double) -> Double { return x0 + clampD(wx / span, 0, 1) * w }
        c.R(x0 - 1.5, y - 1.4, w + 3, 4.2, rgba(28, 19, 12, 0.6))
        c.R(x0, y, w, 1.4, rgba(230, 197, 136, 0.35))
        c.R(mx(g.TOWN.0), y - 0.4, mx(g.TOWN.1) - mx(g.TOWN.0), 2.2, rgba(246, 236, 206, 0.6))
        c.R(mx(g.NILE), y - 0.4, x0 + w - mx(g.NILE), 2.2, Col(0x4a9ab8))
        for b in g.bs where b.def.far && !b.gone { c.R(mx(b.mid) - 0.6, y - 0.8, 1.2, 3, b.level > 0 ? GOLD : rgba(242, 193, 78, 0.45)) }
        for d in g.nomads { c.R(mx(d.x) - 0.4, y + 0.2, 0.9, 0.9, Col(0x6f8fd8)) }
        if let st = g.storm { c.R(x0, y - 0.4, max(0, mx(st.front) - x0), 2.2, rgba(176, 122, 66, 0.7)) }
        if let cv = g.caravan { c.R(mx(cv.x) - 0.7, y - 0.2, 1.4, 1.6, TEAL) }
        var left = false, right = false
        let blink = sin(NOW * 9) > -0.3
        for r in g.raiders where r.state == .raid {
            if blink { c.R(mx(r.x) - 0.7, y - 0.6, 1.4, 2.6, Col(0xff4a34)) }
            if r.x < cam - 6 { left = true }
            if r.x > cam + W + 6 { right = true }
        }
        c.R(mx(g.player.x) - 0.9, y - 1.2, 1.8, 3.8, Col(0xffffff)); c.R(mx(g.player.x) - 0.5, y - 0.6, 1, 2.6, GOLD)
        let pulse = 0.55 + 0.35 * sin(NOW * 7)
        let my = GY - 34
        if left { c.poly(rgba(255, 74, 52, pulse), [10, my - 7, 3, my, 10, my + 7, 8, my]) }
        if right { c.poly(rgba(255, 74, 52, pulse), [W - 10, my - 7, W - 3, my, W - 10, my + 7, W - 8, my]) }
    }

    // ---------- the country around the town
    func camp(_ cp: Camp) {
        let x = cp.x - cam
        if x > W + 50 || x < -50 { return }
        c.poly(Col(0x3a2e2a), [x - 22, GY, x - 15, GY - 11, x + 2, GY - 14, x + 15, GY - 10, x + 21, GY])
        c.poly(Col(0x52403a), [x - 15, GY - 11, x + 2, GY - 14, x, GY, x - 12, GY])
        for k in 0..<4 {
            let n = Double(k)
            c.seg(x - 16 + n * 9, GY - 10 - Double(k % 2) * 2, x - 18 + n * 10, GY, 0.5, Col(0xc9a04a))
        }
        c.R(x - 6, GY - 8, 7, 8, Col(0x1c1410))
        c.seg(x - 23, GY, x - 15, GY - 11, 0.5, WOOD); c.seg(x + 22, GY, x + 15, GY - 10, 0.5, WOOD)
        c.R(x + 24, GY - 0.8, 12, 1.2, RED); c.R(x + 26, GY - 0.8, 1, 1.2, GOLD); c.R(x + 33, GY - 0.8, 1, 1.2, GOLD)
        fire(x + 30, GY - 1, 0.8)
        c.R(x + 38, GY - 4, 3, 4, Col(0xb5673a))
    }
    func quarry() {
        let x = g.QUARRY - cam
        if x > W + 60 || x < -60 { return }
        c.poly(Col(0xb89464), [x - 34, GY, x - 28, GY - 14, x - 10, GY - 20, x + 6, GY - 12, x + 10, GY])
        c.poly(Col(0x96764a), [x - 10, GY - 20, x + 6, GY - 12, x + 10, GY, x - 4, GY])
        c.R(x + 12, GY - 7, 9, 7, STONE); c.R(x + 12, GY - 7, 9, 1, Col(0xecd6a4)); c.R(x + 23, GY - 4, 8, 4, STONE2); c.R(x + 16, GY - 11, 7, 4, STONE)
        for i in 0..<5 {
            let n = Double(i)
            c.R(x - 30 + hashN(n + 70) * 22, GY - 3 - hashN(n + 71) * 12, 1, 1, sin(NOW * 3 + n * 2) > 0.6 ? Col(0xfff3b0) : GOLD)
        }
    }
    func urn(_ u: Urn) {
        let x = u.x - cam
        if x > W + 10 || x < -10 { return }
        if u.open { c.poly(Col(0xa8603a), [x - 4, GY, x - 3, GY - 3, x - 1, GY - 1, x + 1, GY - 4, x + 4, GY]); return }
        let clay = Col(0xb5673a)
        c.ell(x, GY - 3.5, 3.6, 4.5, clay); c.R(x - 1.8, GY - 9.5, 3.6, 2.5, clay); c.R(x - 2.4, GY - 10.2, 4.8, 1.2, Col(0x8f4e2a)); c.R(x - 3.4, GY - 4, 6.8, 1, GOLD)
        c.poly(SAND, [x - 7, GY, x - 2, GY - 2.5, x + 3, GY - 2, x + 7, GY])
        if sin(NOW * 2.5 + u.x) > 0.8 { c.R(x + 1, GY - 7, 1, 1, Col(0xffffff)) }
    }
    func goat(_ gt: Goat) {
        let x = gt.x - cam, d = gt.dir
        if x < -10 || x > W + 10 { return }
        let s = gt.kid ? 0.7 : 1.0
        let wk = gt.moving ? sin(gt.walk * 12) : 0
        c.R(x - 3 * s, GY - 5 * s, 6 * s, 3 * s, Col(0xe8e0d0))
        c.R(x - 2.6 * s + wk * 0.6, GY - 2 * s, 0.8, 2 * s, Col(0x5a4a3a)); c.R(x + 1.8 * s - wk * 0.6, GY - 2 * s, 0.8, 2 * s, Col(0x5a4a3a))
        c.R(x + d * 3 * s - (d < 0 ? 2 * s : 0), GY - 6.5 * s, 2 * s, 2.2 * s, Col(0xd8ccb4))
    }
    func hare(_ h: Hare) {
        let x = h.x - cam
        if x < -10 || x > W + 10 { return }
        let d = h.dir
        let hp = h.hop != 0 ? abs(sin(h.hop)) * 4.4 : 0
        let y = GY - hp
        let c1 = Col(0x8a5a34), c2 = Col(0x6a4226)
        c.ell(x, GY + 0.3, 5.2, 1, rgba(50, 28, 8, 0.32))
        c.ell(x, y - 3.8, 5.2, 3.3, c1); c.ell(x - d * 1.8, y - 3, 3.4, 2.9, c2); c.circ(x + d * 4.4, y - 6.4, 2.5, c1)
        c.R(x + d * 3.2 - 0.6, y - 13.4, 1.3, 6, c2); c.R(x + d * 4.9 - 0.6, y - 14, 1.3, 6.4, c1)
        c.R(x + d * 5.1, y - 7, 0.9, 0.9, Col(0x1c120a)); c.circ(x - d * 5.2, y - 4.4, 1.6, Col(0xfff8ea))
        c.R(x - d * 3.4, y - 1.2, 3.2, 1.2, c2); c.R(x + d * 1.6, y - 1.2, 2, 1.2, c2)
    }

    // ---------- people
    func folk(_ f: Folk) {
        var o = PersonOpt(robe: ROBE[f.id % 5], turban: TURB[f.id % 5], skin: SKIN[f.id % 3])
        o.dir = f.dir; o.moving = f.moving; o.walk = f.walk; o.ham = f.ham; o.cheer = f.cheer > 0
        if f.id % 4 == 0 { o.beard = Col(0x3a2a1c) }
        switch f.role {
        case .folk:
            o.tool = .hammer
            if f.id % 2 == 1 { o.sash = TURB[(f.id + 2) % 5] }
        case .digger: o.robe = Col(0xd9b99a); o.tool = .pick
        case .guard: o.robe = Col(0xe8dcc0); o.turban = RED; o.sash = RED; o.tool = .spear; o.torch = lit
        case .herder: o.robe = Col(0x8a6a44); o.tool = .staff
        }
        person(f.x, f.cheer > 0 ? abs(sin(f.cheer * 11)) * 3 : 0, o)
    }

    func raider(_ r: Raider) {
        let fl = r.hurt > 0
        if r.kind == .mummy {
            let wrap = fl ? Col(0xffffff) : Col(0xd8d0b8)
            var o = PersonOpt(robe: wrap, turban: wrap, skin: Col(0xc8c0a6))
            o.dir = r.dir; o.moving = r.moving; o.walk = r.walk * 0.5; o.veil = wrap; o.sash = Col(0xa89c7c)
            if r.stag > 0 { o.lean = -r.dir * 0.3 * min(1, r.stag * 4) }
            person(r.x, 0, o)
            c.R(r.x - cam + r.dir * 1.2 - 0.6, GY - 18.6, 1.2, 1.2, Col(0x7dffb0))
            light(r.x - cam, GY - 17, 9, 0.4)
            return
        }
        let robe = fl ? Col(0xffffff) : Col(0x2a2422)
        if r.kind == .boss {
            let x = r.x - cam
            c.save()
            c.translate(x, GY); c.scale(1.28, 1.28); c.translate(-x, -GY)
            var bc = CamelOpt()
            bc.col = Col(0x2e2018); bc.dk = Col(0x170f0a); bc.lt = Col(0x43301f); bc.saddle = Col(0x7a1c14); bc.trot = true
            camel(r.x, r.dir, r.walk * 4, 1, bc) { by in
                self.rider(x - r.dir, by, r.dir, RiderOpt(robe: fl ? Col(0xffffff) : Col(0x1c1614), skin: SKIN[1], turban: RED, sash: GOLD, veil: Col(0x1a1614), fl: 0.8, jewel: true))
                let bx = x - r.dir * 4
                let wv = sin(self.NOW * 6) * 1.2
                self.c.seg(bx, by - 6, bx, by - 27, 0.8, Col(0x3a2a1c))
                self.c.poly(RED, [bx, by - 27, bx - r.dir * 11, by - 25 + wv, bx - r.dir * 9, by - 21, bx - r.dir * 12, by - 17 + wv, bx, by - 18])
                self.c.circ(bx - r.dir * 5, by - 22.5 + wv * 0.5, 1.6, GOLD)
            }
            c.restore()
            c.R(x - 8, GY - 44, 16, 2, rgba(28, 19, 12, 0.7))
            c.R(x - 8, GY - 44, 16 * Double(max(0, r.hp)) / Double(max(1, r.maxHp)), 2, RED)
            if lit { fire(x + r.dir * 9, GY - 26, 0.5) }
        } else if r.kind == .rider {
            var co = CamelOpt()
            co.col = Col(0x4e3824); co.dk = Col(0x30200f); co.lt = Col(0x6a4c30); co.saddle = Col(0x7a1c14); co.trot = true
            let sx = r.x - cam
            camel(r.x, r.dir, r.walk * 5, 1, co) { by in
                self.rider(sx - r.dir, by, r.dir, RiderOpt(robe: robe, skin: SKIN[1], turban: Col(0x1a1614), sash: RED, veil: Col(0x1a1614), fl: 0.6))
            }
        } else {
            var o = PersonOpt(robe: robe, turban: Col(0x1a1614), skin: SKIN[r.id % 3])
            o.dir = r.dir; o.moving = r.moving; o.walk = r.walk; o.veil = Col(0x1a1614); o.sash = RED; o.tool = .sword
            o.torch = lit && r.id % 2 == 0
            if r.stag > 0 { o.lean = -r.dir * 0.5 * min(1, r.stag * 4) }
            person(r.x, 0, o)
        }
        if r.loot > 0 { c.circ(r.x - cam, GY - 18, 1.5, GOLD) }
    }

    func person(_ x: Double, _ h: Double, _ o: PersonOpt) {
        let sx = x - cam, y = GY - h, d = o.dir
        if sx < -18 || sx > W + 18 { return }
        let ph = o.walk * 10
        if h < 4 {
            let sl = sunLean * 14
            c.poly(rgba(60, 34, 8, 0.2), [sx - 3.6, GY, sx + 3.6, GY, sx + 3.6 + sl, GY + 4.4, sx - 3.6 + sl, GY + 4.4])
            c.ell(sx, GY + 0.2, 4.4, 0.9, rgba(70, 45, 20, 0.26))
        }
        c.save()
        c.translate(sx, y)
        if o.lean != 0 { c.rotate(o.lean) }
        c.scale(PS, PS)
        let br: Double = o.moving ? abs(cos(ph)) * 0.5 : sin(NOW * 2 + x) * 0.12
        let tr: Double = o.moving ? 1 : 0
        let hem = sin(NOW * 4 + x) * 0.25 - (o.moving ? d * 0.5 : 0)
        let sh = rgba(60, 30, 0, 0.22)
        let top = -10.6 - br
        for s in [-1.0, 1.0] {
            let an = ph + (s > 0 ? 0 : PI)
            let fx = s * 0.9 + (o.moving ? sin(an) * 2.1 : 0)
            let lf = o.moving ? max(0, cos(an)) * 1.2 : 0
            c.seg(s * 0.8, -4.4, fx, -0.8 - lf, 1.15, o.skin)
            c.R(fx - 0.8 + d * 0.3, -0.9 - lf, 1.8, 0.9, Col(0x4a3320))
            c.R(fx - 0.2 + d * 0.3, -1.6 - lf, 0.5, 0.8, Col(0x2a1a10)); c.R(fx - 0.8 + d * 0.3, -0.2 - lf, 1.8, 0.25, Col(0x2a1a10))
        }
        // a dark outline behind, then the robe
        c.poly(rgba(50, 28, 10, 0.55), [-2.7, top - 0.4, 2.7, top - 0.4, 3.9 + hem * 0.4, -1.3, -3.9 + hem * 0.4, -1.3])
        c.R(-1.9, -14 - br, 3.8, 3.5, rgba(50, 28, 10, 0.5))
        if tr > 0.05 {
            let wv = sin(NOW * 9 + x) * 0.7
            c.poly(o.robe, [-d * 1.8, -8.5 - br, -d * 4.6, -4 + wv, -d * 3.5, -1.8, -d * 1.8, -2.2])
        }
        c.poly(o.robe, [-2.2, top, 2.2, top, 3.2 + hem * 0.5, -2, 1.2 + hem, -1.5, -1 + hem, -1.9, -3.2 + hem * 0.5, -1.7])
        c.R(d > 0 ? -2.2 : 0.9, -10.2 - br, 1.3, 8.2, sh)
        c.seg(0.4, -9.6 - br, 0.7 + hem * 0.6, -2.2, 0.4, sh)
        c.R(-2.1, top, 4.2, 0.6, rgba(255, 255, 255, 0.18))
        // a trimmed hem, a placket, a fold or two, and the open neck
        c.poly(o.turban.alpha(0.9), [-3.2 + hem * 0.5, -2.7, 3.2 + hem * 0.5, -2.9, 3.25 + hem * 0.5, -2, 1.2 + hem, -1.5, -1 + hem, -1.9, -3.25 + hem * 0.5, -1.7])
        c.R(-3 + hem * 0.5, -3.3, 6, 0.3, rgba(255, 244, 214, 0.5))
        c.seg(-1.3, -8.4 - br, -1.7 + hem * 0.5, -3.2, 0.3, rgba(60, 30, 0, 0.2))
        c.seg(1.4, -8.8 - br, 1.9 + hem * 0.5, -3.3, 0.3, rgba(255, 255, 255, 0.16))
        c.poly(o.skin, [-0.8, top, 0.8, top, 0, top + 1.7])
        c.R(-0.2, top + 1.6, 0.4, 3.4, rgba(60, 30, 0, 0.22))
        if let s = o.sash { c.R(-2.45, -7 - br, 4.9, 1.1, s); c.R(d * 1.1 - 0.45, -7 - br, 0.9, 3.2 + hem * 0.4, s) }
        let ax = d * 2.5, ay = -8.6 - br, sy = -9.6 - br
        let swinging = o.tool == .hammer && o.ham > 0
        if o.cheer {
            for s in [-1.0, 1.0] { c.seg(s * 2, sy, s * 3.9, sy - 5, 1.15, o.robe); c.R(s * 3.9 - 0.55, sy - 6, 1.1, 1.1, o.skin) }
        } else if o.tool == .none || (o.tool == .hammer && !swinging) {
            let asw = o.moving ? sin(ph + PI) * 1.9 : 0
            c.seg(d * 0.3, sy, d * 0.3 + asw, -5.4 - br, 1.2, o.robe)
            c.seg(d * 0.3, sy, d * 0.3 + asw, -5.4 - br, 1.2, sh)
            c.R(d * 0.3 + asw - 0.5, -5.5 - br, 1, 1, o.skin)
        } else {
            c.seg(d * 0.6, sy, ax, ay + 0.4, 1.2, o.robe)
            c.seg(d * 0.6, sy, ax, ay + 0.4, 1.2, sh)
            c.R(ax - 0.5, ay - 0.2, 1, 1, o.skin)
        }
        // head: a face with an eye and a nose, so nobody is a blank box
        c.R(-1.6, -14.2 - br, 3.2, 3.5, o.skin)
        c.R(d * 0.7 - 0.6, -13.25 - br, 1.2, 0.9, Col(0xf6f0e0))
        c.R(d * 0.95 - 0.3, -13.2 - br, 0.6, 0.8, Col(0x2a1a10))
        c.R(d * 0.7 - 0.7, -13.9 - br, 1.4, 0.35, Col(0x3a2416))
        c.R(d * 1.6 - 0.3, -12.5 - br, 0.6, 0.9, o.skin); c.R(d * 1.5 - 0.3, -11.9 - br, 0.5, 0.3, rgba(60, 30, 0, 0.3))
        c.R(-d * 1.3 - 0.4, -13 - br, 0.8, 1.2, Col.mix(o.skin, Col(0x3a2416), 0.3))
        if o.veil == nil && o.beard == nil { c.R(d * 0.8 - 0.4, -11.7 - br, 1, 0.3, Col(0x6a3a28)) }
        c.R(-1.6, -11.2 - br, 3.2, 0.5, rgba(60, 30, 0, 0.25))
        if let bd = o.beard { c.R(d > 0 ? -0.9 : -1.7, -11.9 - br, 2.6, 1.4, bd) }
        if let v = o.veil { c.R(-1.75, -12.5 - br, 3.5, 2.1, v) }
        c.R(-2.25, -16.1 - br, 4.5, 2.6, o.turban); c.R(-1.6, -16.8 - br, 3.2, 0.9, o.turban)
        c.R(-2.25, -14.7 - br, 4.5, 0.5, rgba(0, 0, 0, 0.16)); c.R(-d * 0.5 - 0.4, -16.4 - br, 0.9, 0.9, rgba(255, 255, 255, 0.3))
        c.seg(-2.2, -15.3 - br, 2.2, -15.9 - br, 0.3, rgba(0, 0, 0, 0.18)); c.seg(-2, -14.9 - br, 2.2, -15.2 - br, 0.25, rgba(255, 255, 255, 0.22))
        if o.sash != nil { c.R(d * 1.2 - 0.45, -15.9 - br, 0.9, 0.9, GOLD) }
        let tw = sin(NOW * 8 + x) * 0.5 * (tr + 0.3)
        c.poly(o.turban, [-d * 2, -15.4 - br, -d * (3.3 + tr * 0.8), -13.6 - br + tw, -d * (2.7 + tr * 0.4), -10.8 - br, -d * 2, -12.6 - br])
        let sw = o.ham > 0 ? sin(o.ham * 24) * 3 : 0
        switch o.tool {
        case .hammer:
            if swinging {
                c.seg(d * 0.6, sy, ax, ay - 1 + sw * 0.4, 1.2, o.robe)
                c.seg(ax, ay, ax + d * 3, ay - 3 + sw, 0.6, WOOD)
                c.R(ax + d * 3 - 1, ay - 4.5 + sw, 2.2, 1.6, Col(0x888888))
            }
        case .pick:
            c.seg(ax, ay + 1, ax + d * 3, ay - 4 + sw, 0.6, WOOD)
            c.seg(ax + d * 1.6, ay - 5 + sw, ax + d * 4.6, ay - 3.4 + sw, 0.9, Col(0x9aa0a0))
        case .spear:
            c.seg(ax, -1, ax, -17, 0.6, Col(0x8f6a3e)); c.poly(Col(0xd8d8d0), [ax - 0.9, -17, ax, -20, ax + 0.9, -17])
            c.circ(-d * 1.7, -6.8 - br, 2.4, RED); c.circ(-d * 1.7, -6.8 - br, 1.6, Col(0x8f2a1c)); c.circ(-d * 1.7, -6.8 - br, 0.8, GOLD)
        case .staff:
            c.seg(ax, -1, ax, -15, 0.6, Col(0x8f6a3e)); c.arcStroke(ax + d, -15, 1, PI, PI * 2, 0.6, Col(0x8f6a3e))
        case .sword:
            let a0: Double = d > 0 ? -0.3 : PI - 1.3
            let a1: Double = d > 0 ? 1.3 : PI + 0.3
            c.arcStroke(ax + d, ay - 4.4, 4.4, a0, a1, 1, Col(0xe4e4dc)); c.R(ax - 0.6, ay - 0.4, 1.4, 0.6, GOLD)
        case .none:
            break
        }
        c.restore()
        if o.torch {
            let tx = sx + d * 3.5 * PS, ty = y - 14 * PS
            c.seg(sx + d * 2.5 * PS, y - 8.6 * PS, tx, ty, 0.8, WOOD)
            fire(tx, ty, 0.5)
        }
    }

    @discardableResult
    func camel(_ x: Double, _ dir: Double, _ ph: Double, _ amp: Double, _ o: CamelOpt, _ top: ((Double) -> Void)? = nil) -> Double? {
        let sx = x - cam, d = dir, kn = o.kneel
        if sx < -30 || sx > W + 30 { return nil }
        let bounce: Double = o.gallop ? 1.5 : (o.trot ? 1.15 : 0.5)
        let by = GY - 13 - abs(sin(ph * 2)) * bounce * amp + kn * 7
        let col = o.col, dk = o.dk, lt = o.lt
        let sl = sunLean * 16
        c.poly(rgba(60, 34, 8, 0.2), [sx - 11, GY, sx + 11, GY, sx + 11 + sl, GY + 4.5, sx - 11 + sl, GY + 4.5])
        c.ell(sx, GY + 0.4, 13, 1.4, rgba(50, 28, 8, 0.32))
        c.save()
        if o.gallop {
            let px = sx - d * 6.5, py = by + 2
            c.translate(px, py); c.rotate(-d * sin(ph * 2) * 0.075 * min(1, amp)); c.translate(-px, -py)
        }
        let swing: Double = o.gallop ? 6 : (o.trot ? 5.2 : 4.2)
        let lift: Double = o.trot ? 3.6 : 2.4
        for i in 0..<4 {
            let fr = i < 2, odd = i % 2 == 1
            let hx = sx + d * (fr ? 6.5 : -6.5) + (odd ? 0.9 : -0.9)
            var a = ph + (odd ? PI : 0) + (fr ? 0.35 : 0)
            if o.gallop { a = ph + (fr ? 0 : 2.4) + (odd ? 0.5 : 0) }
            let sw = sin(a) * swing * amp
            let lf = max(0, cos(a)) * lift * amp
            let kx = hx + d * sw * 0.45 + d * (fr ? 0.6 : -0.8), ky = by + 6.5 - lf * 0.3
            let fx = hx + d * sw, fy = GY - lf
            let cc = odd ? dk : col
            let KX = lerp(kx, hx + d * (fr ? 4.4 : -4.4), kn), KY = lerp(ky, by + 5.5, kn)
            let FX = lerp(fx, hx + d * (fr ? -0.6 : 0.6), kn), FY = lerp(fy, GY, kn)
            c.seg(hx, by + 1, KX, KY, 2.5, cc); c.seg(KX, KY, FX, FY - 0.6, 1.7, cc); c.circ(KX, KY, 1.3, cc)
            c.R(FX - 1.2 + d * 0.4, FY - 1.1, 2.6, 1.1, Col(0x3a2610))
            c.R(FX + d * 0.4 - 0.15, FY - 1.1, 0.3, 0.8, Col(0x1c1008)); c.R(KX - 0.7, KY - 0.5, 1.4, 1, fr ? Col.mix(cc, Col(0x3a2610), 0.45) : cc)
        }
        c.ell(sx, by - 1, 10.5, 4.9, col); c.ell(sx + d * 0.6, by + 1.5, 8.6, 2.5, dk); c.ell(sx + d * 8.3, by + 1.2, 2.3, 3.2, dk)
        c.ell(sx - d * 1.5, by - 3.7, 7, 1.3, lt.alpha(0.5))
        for q in 0..<4 {
            let n = Double(q)
            c.seg(sx + d * (7.6 + n * 0.5), by + 1 + n * 0.9, sx + d * (8.4 + n * 0.5), by + 3 + n * 0.8, 0.5, lt)
            c.seg(sx - d * 9.4 + d * n * 0.3, by - 2 + n, sx - d * 10.2 + d * n * 0.3, by - 1 + n, 0.45, dk)
        }
        for hxo in [-4.8, 2.8] {
            let hx = sx + d * hxo
            let sg = sin(ph * 2 + hxo) * 0.4 * amp
            c.ell(hx, by - 6.2, 3.3, 4.6, col); c.ell(hx - d * 0.9, by - 7.4, 1.3, 2.4, lt)
            c.R(hx - 1.6 + sg, by - 11.4, 3.2, 1.5, dk); c.R(hx - 0.8 + sg, by - 12.2, 1.6, 1, dk)
        }
        c.ell(sx - d, by - 4.2, 2.2, 1.4, dk)
        let gz = o.graze
        let nb = sin(ph * 2 + 1) * 0.8 * amp + sin(NOW * 5) * gz * 0.5
        let hx = sx + d * (15.5 + gz * 1.5), hy = by - 13.5 + nb + gz * 16
        c.roundCaps(true)
        c.curve(sx + d * 8.3, by - 0.5, sx + d * 12.6, by - 1, sx + d * 13.3, hy + 2.4, 4.4, dk)
        c.curve(sx + d * 8, by - 2.4, sx + d * 12.4, by - 3.4, sx + d * 13.6, hy + 1.4, 3.1, col)
        c.roundCaps(false)
        c.ell(hx, hy, 3.4, 2, col)
        c.R(hx + d * 1.6 - (d < 0 ? 2.2 : 0), hy - 0.5, 2.2, 2.1, col)
        c.R(hx + d * 3.2 - (d < 0 ? 0.8 : 0), hy + 0.2, 0.8, 0.8, Col(0x2a1a10))
        c.R(hx - d * 2.4 - 0.6, hy - 3.3, 1.2, 1.9, dk); c.R(hx - d * 0.6 - 1, hy - 2.4, 2.2, 1, dk)
        c.R(hx + d * 0.7 - 0.4, hy - 1, 0.8, 0.8, Col(0x1c1008)); c.R(hx + d * 0.9 - 0.2, hy - 1, 0.3, 0.3, Col(0xffffff))
        c.seg(hx + d * 0.1, hy - 1.5, hx + d * 1.4, hy - 1.8, 0.35, Col(0x1c1008))
        c.R(hx + d * 3.5 - 0.25, hy - 0.2, 0.5, 0.5, Col(0x1c1008)); c.seg(hx + d * 1.3, hy + 1.4, hx + d * 3.7, hy + 1.2, 0.35, Col(0x3a2610))
        c.R(hx - d * 2.4 - 0.3, hy - 2.9, 0.6, 1.1, Col(0xd9a070))
        c.ell(hx + d * 3, hy + 0.9, 1, 0.8, lt)
        for q in 0..<5 {
            let k = Double(q) / 4
            let mx = lerp(sx + d * 9, hx - d * 2.2, k), my = lerp(by - 3.4, hy - 1.2, k)
            c.seg(mx, my, mx - d * 0.9, my - 1.5 - sin(NOW * 3 + k * 4) * 0.2, 0.55, dk)
        }
        let tailY = by + 3.6 + sin(ph * 2) * amp
        c.seg(sx - d * 10, by - 2.4, sx - d * 12, tailY, 0.9, dk); c.R(sx - d * 12 - 0.7, tailY - 0.2, 1.4, 1.8, Col(0x3a2610))
        if let ld = o.load {
            c.R(sx - d - 3.4, by - 10.5, 6.8, 5.6, ld); c.R(sx - d - 3.4, by - 8.6, 6.8, 0.8, GOLD)
            c.R(sx - 7.6, by - 5.5, 3.2, 5.4, Col(0xb5673a)); c.R(sx + 4.4, by - 5.5, 3.2, 5.4, Col(0x7a5a34))
        }
        if let s = o.saddle {
            c.curve(hx + d * 2, hy + 1, sx + d * 9, by - 5, sx + d, by - 6, 0.35, Col(0xd8b060))
            let bx = sx - d - 3.6
            c.R(bx, by - 7.6, 7.2, 6.4, s); c.R(bx, by - 7.6, 7.2, 0.8, GOLD); c.R(bx, by - 4.6, 7.2, 0.7, TEAL); c.R(bx, by - 2, 7.2, 0.9, GOLD)
            for i in 0..<4 {
                let n = Double(i)
                c.R(bx + 0.4 + n * 2, by - 1.1, 0.8, 1.7 + sin(ph * 2 + n) * 0.5 * amp, GOLD)
            }
            // the rest of the tack: woven blanket, girth, saddlebag and waterskin, halter, brow band, chin tassel, a collar of bells
            for q in 0..<3 { c.poly(GOLD, [bx + 1.4 + Double(q) * 2.2, by - 6.4, bx + 2 + Double(q) * 2.2, by - 5.8, bx + 1.4 + Double(q) * 2.2, by - 5.2, bx + 0.8 + Double(q) * 2.2, by - 5.8]) }
            c.R(bx, by - 3.6, 7.2, 0.4, Col(0xfff3b8))
            c.R(sx - d - 0.5, by - 1.2, 1, 5.6, Col(0x5e3a1e)); c.R(sx - d - 0.5, by + 2.4, 1, 0.8, GOLD)
            let bagX = sx - d * 6.8
            c.R(bagX - 2.2, by - 3.8, 4.4, 4.8, Col(0x8a5a34)); c.R(bagX - 2.2, by - 3.8, 4.4, 1.6, Col(0x6a4426)); c.R(bagX - 0.4, by - 2.6, 0.8, 0.8, GOLD)
            c.ell(sx - d * 4.6, by + 2.6, 1.5, 2.2, Col(0x6a4a2a)); c.R(sx - d * 4.6 - 0.3, by, 0.6, 1.2, Col(0x3a2610))
            c.seg(hx - d * 1.8, hy - 1.7, hx + d * 1.4, hy - 1.4, 0.55, GOLD)
            c.R(hx + d * 1.5 - 0.3, hy - 1.3, 0.6, 3, RED); c.seg(hx - d * 1.6, hy + 0.6, hx + d * 1.6, hy + 1.2, 0.45, RED)
            c.R(hx + d * 0.6 - 0.35, hy + 2, 0.7, 2 + sin(ph * 2) * 0.5 * amp, RED); c.R(hx + d * 0.6 - 0.35, hy + 2, 0.7, 0.5, GOLD)
            c.seg(sx + d * 9, by - 4.8, sx + d * 10.4, by + 2.8, 1, RED); c.seg(sx + d * 9.3, by - 4.8, sx + d * 10.7, by + 2.8, 0.3, GOLD)
            for q in 0..<3 { c.circ(sx + d * (10 + Double(q) * 0.25), by - 2 + Double(q) * 2.2 + sin(ph * 2 + Double(q)) * 0.3 * amp, 0.7, GOLD) }
        }
        if let top = top { top(by) }
        c.restore()
        return by
    }

    func rider(_ sx: Double, _ by: Double, _ d: Double, _ o: RiderOpt) {
        c.save()
        c.translate(sx, by - 2); c.scale(1.2, 1.2); c.translate(-sx, -(by - 2))
        let y = by - 8
        c.R(sx + d * 1.4 - 0.6, y + 1, 1.3, 5.5, o.robe); c.R(sx + d * 1.6 - 0.6, y + 6, 1.6, 1, Col(0x6a4e2c))
        if o.jewel {
            let wv = sin(NOW * 7) * (0.4 + o.fl * 1.4)
            c.poly(Col(0x8f2a1c), [sx - d * 1.4, y - 7.2, sx - d * (5 + o.fl * 5), y - 4 + wv, sx - d * (4.4 + o.fl * 4), y + 1.6 + wv * 0.6, sx - d * 2, y + 1.2])
            c.poly(RED, [sx - d * 1.4, y - 7.2, sx - d * (4.6 + o.fl * 4.6), y - 4.4 + wv, sx - d * (3.6 + o.fl * 3.4), y - 0.4 + wv * 0.6, sx - d * 1.8, y - 0.6])
        }
        c.poly(o.robe, [sx - 2.4, y - 7.5, sx + 2.2, y - 7.5, sx + 2.8, y + 1.5, sx - 3, y + 1.5])
        c.R(sx - d * 2.4 - (d < 0 ? 1.2 : 0), y - 7.2, 1.2, 8.4, rgba(60, 30, 0, 0.2)); c.R(sx - 0.2, y - 6.6, 0.4, 7.6, rgba(60, 30, 0, 0.18))
        if o.jewel { c.R(sx - 2.1, y - 7.7, 4.2, 0.8, GOLD); c.R(sx + d * 0.2 - 0.5, y - 6.8, 1, 1, TEAL) }
        if let s = o.sash { c.R(sx - 2.6, y - 2.6, 5.2, 1.1, s) }
        c.R(sx - 1.5, y - 10.6, 3, 3.1, o.skin); c.R(sx + d * 0.9 - 0.3, y - 9.5, 0.6, 0.6, Col(0x2a1a10))
        c.R(sx + d * 0.7 - 0.6, y - 10.1, 1.3, 0.3, Col(0x3a2416)); c.R(sx + d * 1.5 - 0.25, y - 9, 0.5, 0.8, o.skin); c.R(sx + d * 0.8 - 0.35, y - 8.2, 0.8, 0.25, Col(0x6a3a28))
        c.R(sx - 2.1, y - 11.1, 4.2, 0.35, rgba(0, 0, 0, 0.2))
        if let v = o.veil { c.R(sx - 1.5, y - 9, 3, 1.5, v) }
        c.R(sx - 2.1, y - 12.4, 4.2, 2.3, o.turban); c.R(sx - 1.5, y - 13, 3, 0.8, o.turban)
        let fl = o.fl
        c.poly(o.turban, [sx - d * 2, y - 12, sx - d * (4 + fl * 3), y - 11 + sin(NOW * 9) * fl, sx - d * (3 + fl * 2), y - 8.5, sx - d * 2, y - 9.5])
        if o.jewel { c.R(sx + d - 0.4, y - 12, 0.9, 0.9, TEAL) }
        c.restore()
    }

    func drawPlayer() {
        let p = g.player
        let sx = p.x - cam, sp = abs(p.vx), d = p.dir
        let amp = clampD(sp / 70, 0, 1.1)
        let gal = (g.up.contains("racer") || g.B(.pen).level >= 2) && sp > 125
        let trot = !gal && sp > 70
        var co = CamelOpt()
        co.trot = trot; co.gallop = gal; co.saddle = RED; co.kneel = p.kneelK
        if p.kneelK <= 0.1 { co.graze = clampD((p.idle - 2.5) / 1.2, 0, 1) * (0.5 + 0.5 * sin(NOW * 0.7)) }
        camel(p.x, d, p.phase, gal ? 1.15 : amp, co) { by in
            self.rider(sx - d, by, d, RiderOpt(robe: Col(0xf6efdc), skin: Col(0xb8804e), turban: GOLD, sash: TEAL, veil: nil, fl: clampD(sp / 110, 0, 1), jewel: true))
            let y = by - 8
            let cv = self.c
            cv.R(sx - d * 3.6 - 0.6, y - 6, 1.4, 6, Col(0x6a4426))
            let tip = self.g.up.contains("fire") ? Col(0xffb04a) : PLA
            for i in 0..<min(3, p.ammo) { cv.R(sx - d * 3.6 - 0.6 + Double(i) * 0.5, y - 7.6, 0.4, 1.8, tip) }
            let arm = Col(0xf6efdc)
            if p.draw > 0 || p.rl > 0 {
                let bd = p.draw > 0 ? p.aim : d
                let pull: Double = p.draw > 0 ? 2 : 4
                let a0: Double = bd > 0 ? -1.25 : PI - 1.25
                let a1: Double = bd > 0 ? 1.25 : PI + 1.25
                cv.arcStroke(sx + bd * 2.5, y - 4, 5, a0, a1, 0.8, WOOD)
                cv.seg(sx + bd * 4, y - 8.7, sx + bd * pull, y - 4, 0.3, PLA); cv.seg(sx + bd * pull, y - 4, sx + bd * 4, y + 0.7, 0.3, PLA)
                cv.seg(sx, y - 4, sx + bd * 3, y - 4, 1, arm)
            } else if p.toss > 0 {
                cv.seg(sx + d * 1.5, y - 5, sx + d * 4.5, y - 9, 1.1, arm)
            } else {
                cv.seg(sx + d * 1.5, y - 4.5, sx + d * 4.5, y - 2, 1.1, arm)
            }
            if self.lit { self.fire(sx + d * 6, by - 12, 0.5) }
        }
        if lit { light(sx, GY - 12, 46, 0.9) }
    }

    // ---------- the title: dawn over the river, a caravan on the dune
    func title() {
        let hy = H * 0.5
        c.vfill(0, 0, W, hy, [(0, Col(0x3f4f96)), (0.45, Col(0xd08a7a)), (0.8, Col(0xf6b56a)), (1, Col(0xfde0a0))])
        for s in stars {
            let a = 0.55 * s.b * max(0, 1 - s.y * 2.6) * (0.6 + 0.4 * sin(NOW * s.f + s.p))
            c.R(s.x * W, s.y * hy * 0.5, s.s, s.s, rgba(255, 248, 226, a))
        }
        let sx = W * 0.7, sy = hy - 5
        c.save()
        c.translate(sx, sy); c.rotate(NOW * 0.02)
        for i in 0..<18 {
            c.rotate(PI / 9)
            c.poly(rgba(255, 226, 160, 0.08), [-4, 0, 0, -W * 0.5 - Double(i % 2) * 40, 4, 0])
        }
        c.restore()
        c.glow(sx, sy, 100, rgba(255, 244, 200, 0.95), rgba(255, 210, 130, 0))
        c.circ(sx, sy, 12, Col(0xfff8dc))
        for i in 0..<6 {
            let n = Double(i)
            let bx = (n * W / 4 + NOW * 2.4).truncatingRemainder(dividingBy: W + 220) - 110
            c.ell(bx, 14 + n * 8, 40 + n * 6, 3.2, rgba(255, 200, 170, 0.5))
        }
        // the far bank and the old pyramids
        var bank: [Double] = [0, hy]
        var bx = 0.0
        while bx <= W {
            bank.append(bx)
            bank.append(hy - 5 - 8 * (1 - abs(sin(bx * 0.014 + 1))) - 4 * sin(bx * 0.033))
            bx += 6
        }
        bank.append(W); bank.append(hy)
        c.poly(Col(0xb98a7a), bank)
        titlePyramid(W * 0.9, H * 0.17, 0.75, hy); titlePyramid(W * 0.36, H * 0.2, 0.8, hy)
        titlePyramid(W * 0.17, H * 0.36, 1, hy); titlePyramid(W * 0.52, H * 0.27, 0.95, hy)
        c.R(0, hy - 2, W, 3, Col(0x6a4a62))
        // the river, with the sun laid across it
        c.vfill(0, hy, W, H - hy, [(0, Col(0xfbd08a)), (0.5, Col(0xc77a6a)), (1, Col(0x5a4a80))])
        var r = 0.0
        while r < H * 0.3 {
            let wd = 7 + r * 1.5 + sin(NOW * 4 + r) * 3
            c.R(sx - wd / 2 + sin(NOW * 2.4 + r * 0.9) * 3, hy + r, wd, 0.7, rgba(255, 244, 200, 0.6 - r / (H * 0.3) * 0.45))
            r += 1.3
        }
        for i in 0..<30 {
            let n = Double(i)
            let rx = (hashN(n + 70) * W + NOW * Double(4 + i % 4) * 2).truncatingRemainder(dividingBy: W + 40) - 20
            c.R(rx, hy + 3 + hashN(n + 71) * H * 0.26, 8 + hashN(n) * 14, 0.6, rgba(255, 236, 200, 0.28))
        }
        // the dune you stand on
        var dune: [Double] = [0, H]
        var dx = 0.0
        while dx <= W { dune.append(dx); dune.append(crest(dx)); dx += 4 }
        dune.append(W); dune.append(H)
        c.poly(Col(0xc9925a), dune)
        c.vfill(0, H * 0.66, W, H * 0.34, [(0, rgba(60, 30, 40, 0)), (1, rgba(60, 30, 40, 0.6))])
        dx = 0
        while dx < W { c.seg(dx, crest(dx), dx + 4, crest(dx + 4), 0.8, rgba(255, 236, 190, 0.8)); dx += 4 }
        let keepCam = cam
        cam = 0
        let sad: [Col] = [TEAL, RED, Col(0x8a4a8a), GOLD]
        for q in 0..<4 {
            let n = Double(q)
            let x = (NOW * 7 + n * 17).truncatingRemainder(dividingBy: W + 140) - 70
            c.save()
            c.translate(0, crest(x) - GY - 3)
            var co = CamelOpt()
            co.saddle = sad[q]
            camel(x, 1, NOW * 5 + n * 1.7, 1, co) { by in
                if q % 2 == 0 {
                    self.rider(x - 1, by, 1, RiderOpt(robe: q == 0 ? Col(0x3a5a8a) : Col(0xb8693e), skin: Col(0xb8804e), turban: Col(0xf6efdc), sash: GOLD, veil: nil, fl: 0.35, jewel: false))
                } else {
                    self.c.R(x - 5, by - 7, 9, 5, Col(0xb58a52)); self.c.R(x - 5, by - 7, 9, 1.2, Col(0x8a5a34))
                }
            }
            c.restore()
        }
        let px = W * 0.27
        c.save()
        c.translate(0, crest(px) - GY + 1)
        var hero = CamelOpt()
        hero.saddle = RED
        camel(px, 1, NOW * 1.2, 0.12, hero) { by in
            self.rider(px - 1, by, 1, RiderOpt(robe: Col(0xf6efdc), skin: Col(0xb8804e), turban: GOLD, sash: TEAL, veil: nil, fl: 0.35, jewel: true))
            self.c.seg(px + 1.5, by - 12.5, px + 4.5, by - 10, 1.1, Col(0xf6efdc))
        }
        c.restore()
        c.save(); c.translate(0, crest(W * 0.1) - GY); palm(W * 0.1, 38, 1.2, 3, true); c.restore()
        c.save(); c.translate(0, crest(W * 0.57) - GY); palm(W * 0.57, 30, 1, 8, false); c.restore()
        c.save(); c.translate(0, crest(W * 0.88) - GY); palm(W * 0.88, 34, 1.1, 5, true); c.restore()
        cam = keepCam
        for q in 0..<22 {
            let n = Double(q)
            let sp = 40 + hashN(n + 300) * 50
            let x = (hashN(n + 301) * W + NOW * sp).truncatingRemainder(dividingBy: W + 60) - 30
            c.R(x, crest(x) + 2 + hashN(n + 302) * H * 0.2, 7 + hashN(n + 304) * 12, 0.5, rgba(255, 232, 190, 0.18 + hashN(n + 303) * 0.2))
        }
    }
    private func crest(_ x: Double) -> Double {
        let far = x > W * 0.55 ? (x - W * 0.55) * 0.04 : 0
        return H * 0.76 - sin((x / W) * PI * 0.9 + 0.2) * H * 0.12 + far
    }
    private func titlePyramid(_ x: Double, _ hh: Double, _ a: Double, _ hy: Double) {
        let w = hh * 0.78
        c.poly(rgba(236, 170, 112, a), [x - w, hy, x, hy - hh, x + w * 0.25, hy])
        c.poly(rgba(122, 74, 98, a), [x + w * 0.25, hy, x, hy - hh, x + w, hy])
        c.poly(rgba(255, 226, 170, a * 0.8), [x - w * 0.12, hy - hh * 0.88, x, hy - hh, x + w * 0.03, hy - hh * 0.88])
    }
}
