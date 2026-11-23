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
    /// 0 turban, 1 bronze helmet, 2 wide straw hat
    var hat = 0
    var pack = false
    var lantern = false
}

struct CamelOpt {
    var trot = false
    var gallop = false
    var saddle: Col? = nil
    var kneel = 0.0
    var graze = 0.0
    var rear = 0.0
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
        puffs()
        if !g.low { skyLife() }
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
            if g.feat == .temple { farTemple(384, 1, hz); farTemple(640, 0.66, hz) }
            if g.feat == .port { farHarbour(430, hz) }
        }
        dunes(0.12, 14, 16, Col.mix(Col(0xecd3a0), hz, 0.35), Col.mix(Col(0xc39c62), hz, 0.35), 1.3, 0.012, false)
        if g.feat == .oasis { farGrove(hz) }
        c.vfill(0, GY - 46, W, 46, [(0, rgba(hz.r * 255, hz.g * 255, hz.b * 255, 0)), (1, rgba(hz.r * 255, hz.g * 255, hz.b * 255, 0.3))])
        dunes(0.28, 6, 18, Col(0xebcd90), Col(0xbd9052), 4.1, 0.017, true)
        c.vfill(0, GY - 22, W, 22, [(0, rgba(hz.r * 255, hz.g * 255, hz.b * 255, 0)), (1, rgba(hz.r * 255, hz.g * 255, hz.b * 255, 0.16))])
        if !g.low { farLife(hz) }
        ridgeRiders()
        dunes(0.55, 0, 13, SAND, Col(0xb3854a), 7.7, 0.023, true)
        backTown(hz)
        ground()
        townGround()
        groundRipples()
        groundExtra()
        wetGround()
        townProps()
        for m in g.mirages { mirage(m) }
        if !g.low { groundAir(); critters() }
        nile()
        if !g.low { nileExtra(hz) }
        quarry()
        if !g.low { quarryExtra() }
        sites()
        if !g.low { siteExtras() }
        for cp in g.camps { camp(cp); if !g.low { campExtra(cp) } }
        for u in g.urns { urn(u); urnExtra(u) }
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
        for cg in g.herd { goat(cg); goatExtra(cg) }
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
                // rolling billows on the face of the wall, and grit flying ahead of it
                y = -6; n = 0
                while y < GY + 12 {
                    let bx = edge + 6 + sin(NOW * 1.1 + n * 1.7) * 6, r = 9 + hashN(n + 3) * 7
                    c.circ(bx, y + 5, r, rgba(150, 100, 52, 0.55)); c.circ(bx - 2, y + 3, r * 0.8, rgba(214, 164, 100, 0.6)); c.circ(bx - 4, y + 1, r * 0.4, rgba(240, 200, 140, 0.45))
                    y += 10; n += 1
                }
                for q in 0..<16 {
                    let nq = Double(q)
                    let u = (NOW * (0.6 + hashN(nq + 950) * 0.8) + hashN(nq + 951)).truncatingRemainder(dividingBy: 1)
                    c.R(edge + u * 70, hashN(nq + 952) * GY, 5 + hashN(nq + 953) * 8, 0.4, rgba(120, 80, 40, 0.5 * (1 - u)))
                }
            }
        }
        // a storm on its way shows first as a brown band low in the west
        if g.stormAt > 0 && g.storm == nil {
            let k = clampD(1 - (g.stormAt - g.t) / 0.08, 0, 1)
            if k > 0 {
                c.linear(-9, 0, W * 0.6, GY, -9, 0, W * 0.6 * k + 1, 0, [(0, rgba(176, 122, 66, 0.55 * k)), (1, rgba(176, 122, 66, 0))])
                for q in 0..<5 { c.circ(-6 + Double(q) * 3 * k, GY - 8 - Double(q) * 13, (14 + Double(q % 2) * 6) * k, rgba(176, 122, 66, 0.5 * k)) }
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
        c.vfill(-9, H - 22, W + 18, 31, [(0, rgba(20, 10, 30, 0)), (1, rgba(20, 10, 30, 0.2))])
        c.vfill(-9, -9, W + 18, 27, [(0, rgba(20, 10, 30, 0.16)), (1, rgba(20, 10, 30, 0))])
        if g.state == .play && g.scene == nil && g.trip == nil { minimap(); tourArrow() }
        if g.fade > 0 { c.R(-20, -20, W + 40, H + 40, rgba(0, 0, 0, g.fade)) }
        c.restore()
        scenePanel()
    }

    // ---------- a painted look inside, for the cutscenes that go indoors
    private func flame(_ fx: Double, _ fy: Double, _ s: Double) {
        let fl = sin(NOW * 9 + fx) * s
        c.glow(fx, fy - 3 * s, 13 * s, rgba(255, 170, 70, 0.5), rgba(255, 170, 70, 0))
        c.poly(Col(0xff8a2a), [fx - 2.4 * s, fy, fx + fl * 0.6, fy - 7 * s, fx + 2.4 * s, fy])
        c.poly(Col(0xffe08a), [fx - 1.2 * s, fy, fx - fl * 0.4, fy - 4 * s, fx + 1.2 * s, fy])
    }
    private func figure(_ px: Double, _ fy: Double, _ robe: Col, _ turb: Col) {
        c.ell(px, fy + 0.4, 4, 1, rgba(0, 0, 0, 0.3))
        c.R(px - 2.4, fy - 10, 4.8, 10, robe); c.R(px - 2.4, fy - 6.4, 4.8, 1, GOLD)
        c.circ(px, fy - 12, 2.1, Col(0xb8804e)); c.R(px - 2.4, fy - 14.8, 4.8, 2.2, turb)
    }
    /// Tiny riders on a ridge, for the raid picture.
    /// A camel and rider in silhouette, feet at (px, py). ph walks the legs and bobs the body.
    private func rideMark(_ px: Double, _ py: Double, _ s: Double, _ col: Col, _ f: Double = 1, _ ph: Double = 0) {
        let bob = sin(ph * 2) * 0.35 * s
        let legs: [Double] = [-3.6, -1.6, 2, 3.8]
        for (i, lx) in legs.enumerated() {
            let sw = sin(ph + Double(i) * 1.6) * 1.3 * s
            c.seg(px + lx * s, py - 4 * s + bob, px + lx * s + sw, py, 0.8 * s, col)
        }
        c.ell(px, py - 5 * s + bob, 5.4 * s, 2.6 * s, col)
        c.ell(px - f * 0.8 * s, py - 7 * s + bob, 2.6 * s, 1.7 * s, col)
        c.seg(px - f * 5 * s, py - 5.6 * s + bob, px - f * 6.2 * s, py - 2.6 * s + bob, 0.5 * s, col)
        c.seg(px + f * 4 * s, py - 6 * s + bob, px + f * 7 * s, py - 10.5 * s + bob, 1.5 * s, col)
        c.ell(px + f * 8 * s, py - 11 * s + bob, 1.9 * s, 1.2 * s, col)
        c.RR(px - 1.6 * s, py - 13.4 * s + bob, 3.2 * s, 6.6 * s, s, col); c.circ(px, py - 14.6 * s + bob, 1.6 * s, col)
        c.poly(col, [px - f * 1.2 * s, py - 15.4 * s + bob, px - f * 3.6 * s, py - 13 * s + bob + sin(ph * 1.3) * 0.5 * s, px - f * 1.2 * s, py - 13.4 * s + bob])
    }
    /// The top of a dune layer at a screen x, by the same rule dunes() draws with.
    private func duneTop(_ sx: Double, _ par: Double, _ base: Double, _ amp: Double, _ seed: Double, _ f: Double) -> Double {
        let wx = sx + cam * par
        let a1 = (1 - abs(sin(wx * f + seed))) * 0.6
        let a2 = (0.5 + 0.5 * sin(wx * f * 2.3 + seed * 2)) * 0.28
        let a3 = (0.5 + 0.5 * sin(wx * f * 0.37 + seed * 5)) * 0.4
        return GY - base - amp * (a1 + a2 + a3)
    }
    /// Before a raid, riders with torches gather on the far ridge. With a temple you see which side; without one they show on both.
    func ridgeRiders() {
        if g.dark < 0.45 || g.low { return }
        let plans = g.raid.filter { !$0.boat && $0.kind != .mummy }
        if plans.isEmpty { return }
        let n = min(8, plans.count + 2)
        let know = g.B(.temple).level > 0
        let side = plans[0].side
        let prog = clampD((g.t - 0.7) / 0.08, 0, 1)
        let ink = Col(0x0a0a18)
        for i in 0..<n {
            let k = Double(i)
            let sd: Double = know ? side : (i % 2 == 0 ? -1 : 1)
            let off = 46 + k * (know ? 14 : 8) + prog * 30
            let px = sd < 0 ? off : W - off
            let py = duneTop(px, 0.28, 6, 18, 4.1, 0.017) + 0.6
            let ph = prog < 1 ? NOW * 5 + k * 1.3 : 0
            c.ell(px, py + 0.6, 9, 1.6, rgba(255, 170, 70, 0.16))
            rideMark(px, py, 0.62, ink, -sd, ph)
            if i == 0 || i == 1 {
                // the leaders carry a banner
                let sw = sin(NOW * 4 + k) * 0.7
                c.seg(px + sd * 0.6, py - 8, px + sd * 0.6, py - 17, 0.35, ink)
                c.poly(Col(0x8f2a1c), [px + sd * 0.6, py - 17, px + sd * 5 + sw, py - 16, px + sd * 3.4 + sw, py - 14.6, px + sd * 5 + sw, py - 13.4, px + sd * 0.6, py - 13])
            }
            flame(px - sd * 2.2, py - 9.6, 0.42)
            c.R(px - sd * 2.2 - 0.3 + sin(NOW * 2 + k) * 0.6, py - 14 - Double(i % 3), 0.6, 1.6, rgba(200, 190, 210, 0.25))
            light(px, py - 7, 12, 0.6)
        }
    }
    /// The outdoor and night-sky pictures.
    private func morePanels(_ kind: Int, _ x: Double, _ y: Double, _ pw: Double, _ ph: Double, _ fy: Double) {
        let sx = x + pw / 2
        let ink = Col(0x1c130c)
        func stars(_ n: Int) {
            for i in 0..<n {
                let k = Double(i)
                c.R(x + hashN(k + 840) * pw, y + hashN(k + 841) * (ph * 0.6), 0.6, 0.6, rgba(255, 250, 230, 0.4 + 0.5 * hashN(k + 842) * (0.7 + 0.3 * sin(NOW * 2 + k))))
            }
        }
        func dune(_ col: Col, _ h: Double, _ ph0: Double) {
            var p: [Double] = [x, y + ph]
            var q = 0.0
            while q <= pw { p.append(x + q); p.append(fy + 4 - h * (0.5 + 0.5 * sin(q * 0.045 + ph0))); q += 4 }
            p.append(x + pw); p.append(y + ph)
            c.poly(col, p)
        }
        switch kind {
        case 5:
            // the cave: a passage of spears, and the chest in the light at the end
            c.vfill(x, y, pw, ph, [(0, Col(0x2a120a)), (1, Col(0x5a2814))])
            c.poly(Col(0x3a180c), [x, y, x + 40, y, x + 58, fy, x, fy]); c.poly(Col(0x3a180c), [x + pw, y, x + pw - 40, y, x + pw - 58, fy, x + pw, fy])
            c.poly(Col(0x7a4426), [x + 58, fy, x + pw - 58, fy, x + pw, y + ph, x, y + ph])
            c.glow(sx, fy - 12, 34, rgba(255, 204, 116, 0.55), rgba(255, 204, 116, 0))
            c.R(sx - 11, fy - 30, 22, 30, ink); c.R(sx - 13, fy - 33, 26, 3.4, Col(0xe0a274))
            c.RR(sx - 5, fy - 8, 10, 8, 1.4, Col(0x6a4426)); c.R(sx - 5, fy - 8, 10, 1.6, GOLD); c.R(sx - 1, fy - 5.6, 2, 2.8, GOLD)
            for i in 0..<4 {
                let k = Double(i)
                let px = x + 26 + k * 34 + (i > 1 ? 4 : 0), py = fy + 4 + Double(i % 2) * 5
                let up = clampD(0.5 + sin(NOW * 2 + k * 1.7), 0, 1)
                c.R(px - 8, py, 16, 1.8, Col(0x4a2414)); c.R(px - 8, py, 16, 0.5, Col(0xc98052))
                for q in 0..<5 {
                    let qx = px - 6 + Double(q) * 3
                    c.seg(qx, py, qx, py - 20 * up, 0.8, Col(0x9aa0a0)); c.poly(Col(0xe4e4dc), [qx - 1, py - 20 * up, qx, py - 24 * up, qx + 1, py - 20 * up])
                }
            }
            flame(x + 50, fy - 22, 1); flame(x + pw - 50, fy - 22, 1)
        case 6:
            // the obelisk against the sun, and the town come out to see it
            c.vfill(x, y, pw, ph, [(0, Col(0x6fb6d8)), (1, Col(0xf6e2b0))])
            c.glow(sx, fy - 30, 44, rgba(255, 244, 200, 0.9), rgba(255, 244, 200, 0)); c.circ(sx, fy - 30, 11, Col(0xfff6d8))
            for i in 0..<10 { let a = Double(i) * 0.628 + NOW * 0.1; c.seg(sx + cos(a) * 14, fy - 30 + sin(a) * 14, sx + cos(a) * 40, fy - 30 + sin(a) * 40, 0.6, rgba(255, 250, 220, 0.35)) }
            dune(Col(0xe6c88c), 8, 1); dune(Col(0xf2dca4), 3, 3)
            c.poly(STONE, [sx - 4.6, fy + 2, sx - 2.8, fy - 46, sx + 2.8, fy - 46, sx + 4.6, fy + 2]); c.poly(STONE2, [sx + 1, fy + 2, sx + 0.6, fy - 46, sx + 2.8, fy - 46, sx + 4.6, fy + 2])
            c.poly(GOLD, [sx - 2.8, fy - 46, sx, fy - 52, sx + 2.8, fy - 46]); c.R(sx - 6.6, fy + 0.6, 13.2, 3, STONE2)
            for q in 0..<7 { c.R(sx - 1.6, fy - 40 + Double(q) * 5.4, 2.2, 2.6, rgba(90, 60, 26, 0.5)) }
            let robes: [Col] = [TEAL, Col(0xf6efdc), RED, Col(0x7a4a8a), Col(0xe0a030), Col(0xf6efdc)]
            for i in 0..<6 {
                let px = x + 18 + Double(i) * 12 + (i > 2 ? 62 : 0), hop = abs(sin(NOW * 5 + Double(i))) * 1.6
                figure(px, fy + 5 - hop, robes[i], i % 2 == 0 ? Col(0xf6efdc) : RED)
                c.seg(px, fy - 4 - hop, px + (i > 2 ? -3 : 3), fy - 9 - hop, 0.7, Col(0xb8804e))
            }
        case 7:
            // the Sphinx at sunrise, clear of the sand
            c.vfill(x, y, pw, ph, [(0, Col(0xe8926a)), (0.6, Col(0xf8d48a)), (1, Col(0xfbe8b8))])
            c.glow(x + pw - 30, fy - 6, 46, rgba(255, 240, 190, 0.9), rgba(255, 240, 190, 0)); c.circ(x + pw - 30, fy - 4, 12, Col(0xfff6d8))
            c.poly(Col(0xd8a868), [x + 4, fy + 4, x + 34, fy - 34, x + 64, fy + 4]); c.poly(Col(0xb88848), [x + 34, fy - 34, x + 64, fy + 4, x + 44, fy + 4])
            dune(Col(0xe6c88c), 6, 2)
            c.save()
            c.translate(sx - 40, fy + 6); c.scale(1.06, 1.06)
            c.ell(42, 1, 44, 2.2, rgba(60, 34, 8, 0.25))
            c.R(2, -3, 82, 3, STONE2); c.curve(9, -5, 0, -14, 9, -21.5, 1.3, STONE2)
            c.ell(17, -12.5, 11, 9.5, STONE); c.poly(STONE, [10, -3, 12, -19, 20, -22, 36, -20.5, 50, -23, 58, -24, 60, -3])
            c.R(26, -6.4, 28, 3.4, STONE2); c.ell(20, -5.6, 10, 2.6, STONE)
            c.poly(STONE, [48, -3, 49, -23, 58, -25, 61, -14, 60, -3]); c.R(54, -8, 25, 5, STONE); c.ell(79, -5.5, 3, 2.5, STONE)
            c.seg(12.6, -19.4, 20, -22, 0.6, Col(0xfff0c8)); c.seg(20, -22, 36, -20.5, 0.6, Col(0xfff0c8)); c.seg(36, -20.5, 49, -23, 0.6, Col(0xfff0c8))
            sphinxHead(2)
            c.restore()
        case 8:
            // riders on the ridge with torches, under the moon
            c.vfill(x, y, pw, ph, [(0, Col(0x0c1030)), (1, Col(0x2a2a5a))])
            stars(40)
            c.glow(x + 30, y + 20, 26, rgba(220, 230, 255, 0.5), rgba(220, 230, 255, 0)); c.circ(x + 30, y + 20, 8, Col(0xeef0ff)); c.circ(x + 33.4, y + 18, 7, Col(0x121638))
            dune(Col(0x1c1a3a), 26, 0.6)
            for i in 0..<5 {
                let k = Double(i)
                let px = x + 30 + k * 26, py = fy + 4 - 26 * (0.5 + 0.5 * sin((px - x) * 0.045 + 0.6)) + 1
                rideMark(px, py, 0.8 + 0.08 * Double(i % 2), Col(0x080814), 1, NOW * 4 + k * 1.2)
                flame(px - 3, py - 15, 0.55)
            }
            dune(Col(0x10102a), 8, 2.4)
        case 9:
            // the sun going out
            c.vfill(x, y, pw, ph, [(0, Col(0x1a1630)), (1, Col(0x6a4a52))])
            stars(18)
            c.glow(sx, y + 28, 40, rgba(255, 226, 170, 0.75), rgba(255, 226, 170, 0))
            for i in 0..<14 {
                let a = Double(i) * 0.449 + NOW * 0.06
                let r1 = 22 + 6 * hashN(Double(i) + 850)
                c.seg(sx + cos(a) * 13, y + 28 + sin(a) * 13, sx + cos(a) * r1, y + 28 + sin(a) * r1, 0.6, rgba(255, 240, 210, 0.6))
            }
            c.circ(sx, y + 28, 12.6, Col(0xfff0c8)); c.circ(sx + 1.2 - sin(NOW * 0.3) * 0.8, y + 28, 12.2, Col(0x0c0a18))
            dune(Col(0x4a3440), 12, 1.2); dune(Col(0x2e2230), 5, 3)
            c.poly(Col(0x3a2a36), [x + 96, fy + 2, x + 118, fy - 22, x + 140, fy + 2])
            for i in 0..<4 { figure(x + 22 + Double(i) * 9, fy + 6, Col(0x241c2a), Col(0x241c2a)); c.seg(x + 22 + Double(i) * 9, fy - 4, x + 26 + Double(i) * 9, fy - 10, 0.7, Col(0x241c2a)) }
        case 10:
            // the visitor
            c.vfill(x, y, pw, ph, [(0, Col(0x080c24)), (1, Col(0x1c2848))])
            stars(46)
            dune(Col(0x1a2038), 12, 0.4); dune(Col(0x10142a), 5, 2)
            let uy = y + 24 + sin(NOW * 2) * 1.5
            c.poly(rgba(150, 255, 220, 0.16 + 0.05 * sin(NOW * 7)), [sx - 7, uy + 4, sx + 7, uy + 4, sx + 30, fy + 8, sx - 30, fy + 8])
            c.glow(sx, uy, 30, rgba(150, 255, 220, 0.4), rgba(150, 255, 220, 0))
            c.ell(sx, uy - 3.4, 8, 5, Col(0x9ad8e8)); c.ell(sx - 2, uy - 5, 3, 1.6, rgba(255, 255, 255, 0.6))
            c.ell(sx, uy, 22, 4.6, Col(0x8a94a8)); c.ell(sx, uy - 1, 22, 3, Col(0xc4cad8)); c.ell(sx, uy + 1.6, 14, 2, Col(0x5a6278))
            for i in 0..<7 { let on = Int(NOW * 6) % 7 == i; c.circ(sx - 18 + Double(i) * 6, uy + 0.4, 1, on ? Col(0xfff3b0) : Col(0x5ad8c0)) }
            c.ell(sx, fy + 7, 26, 2.4, rgba(150, 255, 220, 0.3))
        case 11:
            // the haboob coming down on the town
            c.vfill(x, y, pw, ph, [(0, Col(0xc89a5c)), (1, Col(0xe8c890))])
            c.R(x, fy + 2, pw, ph - (fy + 2 - y), Col(0xd8b074))
            for i in 0..<5 { let bx = x + pw - 62 + Double(i) * 12, bh = 10 + hashN(Double(i) + 860) * 12; c.R(bx, fy + 2 - bh, 10, bh, Col(0xa8845a)); c.R(bx, fy + 2 - bh, 10, 1, Col(0xd8b88a)); c.R(bx + 3.4, fy - 4, 3, 6, Col(0x5a4028)) }
            c.dome(x + pw - 24, fy + 2 - 20, 6, Col(0xa8845a))
            c.R(x, y, 16, ph, Col(0x9a6a38))
            for r in 0..<6 {
                for q in 0..<6 {
                    let k = Double(r * 6 + q)
                    let bx = x + 12 + Double(q) * 12 + sin(NOW * 0.9 + k) * 2 + Double(r) * 2, by = y + 11 + Double(r) * 10.4
                    c.circ(bx, by, 8 + hashN(k + 870) * 2.6, r % 2 == 0 ? Col(0x9a6a38) : Col(0xb07e46))
                    c.circ(bx - 1.6, by - 2, 4.6, rgba(226, 180, 120, 0.5))
                }
            }
            for i in 0..<14 { let k = Double(i); let u = (NOW * 0.7 + hashN(k + 880)).truncatingRemainder(dividingBy: 1); c.R(x + 84 + u * 60, y + 8 + hashN(k + 881) * (ph - 16), 6 + hashN(k + 882) * 8, 0.4, rgba(110, 70, 30, 0.6 * (1 - u))) }
        case 12:
            // the storm has stripped the sand off something old
            c.vfill(x, y, pw, ph, [(0, Col(0xb8a078)), (1, Col(0xf0dca8))])
            dune(Col(0xd8b878), 12, 0.3)
            for sg in [-1.0, 1.0] {
                let px = sx + sg * 15
                c.poly(STONE, [px - 12, fy + 6, px - 9.4, fy - 22, px + 9.4, fy - 22, px + 12, fy + 6]); c.poly(STONE2, [px + 5, fy + 6, px + 5.6, fy - 22, px + 9.4, fy - 22, px + 12, fy + 6])
                c.R(px - 10.4, fy - 23.6, 20.8, 2, STONE)
                for q in 0..<3 { c.R(px - 6, fy - 16 + Double(q) * 6, 9, 0.5, rgba(90, 60, 26, 0.35)) }
            }
            c.R(sx - 3.4, fy - 10, 6.8, 16, Col(0x3a2a1a))
            c.poly(STONE, [sx + 46, fy + 6, sx + 47.4, fy - 28, sx + 50.6, fy - 28, sx + 52, fy + 6]); c.poly(GOLD, [sx + 47.4, fy - 28, sx + 49, fy - 31.6, sx + 50.6, fy - 28])
            dune(Col(0xe8cc94), 7, 2.2)
            for i in 0..<12 { let k = Double(i); let u = (NOW * 0.5 + hashN(k + 890)).truncatingRemainder(dividingBy: 1); c.R(x + hashN(k + 891) * pw + u * 20, fy - 20 + hashN(k + 892) * 24, 7, 0.4, rgba(255, 244, 214, 0.5 * (1 - u))) }
        default:
            // fireworks over the rooftops
            c.vfill(x, y, pw, ph, [(0, Col(0x0c1030)), (1, Col(0x3a2a5a))])
            stars(26)
            let cols: [Col] = [RED, GOLD, TEAL, Col(0xfff3b0), Col(0xd96ad0)]
            for i in 0..<4 {
                let k = Double(i)
                let u = (NOW * 0.5 + k * 0.27).truncatingRemainder(dividingBy: 1)
                let bx = x + 26 + k * 36, by = y + 16 + hashN(k + 895) * 16
                c.glow(bx, by, 16 * u + 4, cols[i].alpha(0.35 * (1 - u)), cols[i].alpha(0))
                for q in 0..<12 { let a = Double(q) * 0.5236; c.seg(bx + cos(a) * 3 * u, by + sin(a) * 3 * u, bx + cos(a) * 15 * u, by + sin(a) * 15 * u + u * u * 3, 0.6, cols[(i + q % 2) % 5].alpha(1 - u)) }
            }
            for i in 0..<9 {
                let k = Double(i)
                let bx = x + k * 17.34, bh = 12 + hashN(k + 897) * 14
                c.R(bx, fy + 8 - bh, 17.4, bh + 6, Col(0x1c1a3a)); c.R(bx + 3, fy + 8 - bh + 4, 3, 4, Col(0xffd27a)); if i % 2 == 0 { c.R(bx + 10, fy + 8 - bh + 7, 3, 4, Col(0xffd27a)) }
                if i % 3 == 1 { c.dome(bx + 8.5, fy + 8 - bh, 5, Col(0x1c1a3a)) }
            }
            for i in 0..<5 { figure(x + 30 + Double(i) * 22, fy + 12 - abs(sin(NOW * 5 + Double(i))) * 1.4, Col(0x2a2444), Col(0x2a2444)) }
        }
    }
    func scenePanel() {
        guard let sc = g.scene else { return }
        var kind = -1
        switch sc.k {
        case "bazaar": kind = 0
        case "temple": kind = 1
        case "tomb": kind = 2
        case "deep": kind = 3
        case "btemple": kind = 4
        case "cave": kind = 5
        case "obelisk": kind = 6
        case "sphinx": kind = 7
        case "raid": kind = 8
        case "eclipse": kind = 9
        case "ufo": kind = 10
        case "haboob": kind = 11
        case "btemple0": kind = 12
        case "fest": kind = 13
        default: break
        }
        if kind < 0 { return }
        let a = clampD(sc.t * 1.6 - 0.4, 0, 1) * clampD((sc.dur - sc.t) * 2, 0, 1)
        if a <= 0.01 { return }
        c.save()
        c.alpha(a)
        let pw = 156.0, ph = 74.0
        let x = ((W - pw) / 2).rounded(), y = 31.0
        let fy = y + ph - 14
        let ink = Col(0x1c130c)
        c.R(x - 3, y - 3, pw + 6, ph + 6, ink); c.R(x - 2, y - 2, pw + 4, ph + 4, GOLD); c.R(x - 1, y - 1, pw + 2, ph + 2, ink)
        if kind == 0 {
            // the bazaar: arches open on the bright street, rugs, lamps and spice
            c.vfill(x, y, pw, ph, [(0, Col(0x7a5230)), (1, Col(0x3e2614))])
            for i in 0..<3 {
                let ax = x + 14 + Double(i) * 50
                c.arch(ax, y + 12, 28, fy - y - 12, Col(0xf6d79a))
                c.vfill(ax, y + 28, 28, fy - y - 28, [(0, rgba(214, 160, 96, 0)), (1, rgba(196, 140, 84, 0.75))])
                c.R(ax + 3, fy - 16, 7, 16, rgba(150, 110, 70, 0.55)); c.R(ax + 16, fy - 22, 9, 22, rgba(160, 120, 78, 0.5))
            }
            c.R(x, fy, pw, 14, Col(0x8a6238)); c.R(x, fy, pw, 0.8, Col(0xc49a62))
            for i in 0..<8 { c.R(x + Double(i) * 20, fy + 1, 0.4, 13, rgba(40, 22, 8, 0.3)) }
            c.R(x + 46, y + 14, 14, 30, RED); c.R(x + 96, y + 14, 14, 30, LAPIS)
            for q in 0..<5 {
                c.R(x + 46, y + 17 + Double(q) * 6, 14, 1.2, GOLD); c.R(x + 96, y + 17 + Double(q) * 6, 14, 1.2, Col(0xf6efdc))
            }
            for q in 0..<5 { c.R(x + 47 + Double(q) * 3, y + 44, 0.6, 2.4, GOLD); c.R(x + 97 + Double(q) * 3, y + 44, 0.6, 2.4, Col(0xf6efdc)) }
            for i in 0..<3 {
                let lx = x + 28 + Double(i) * 50, ly = y + 14 + sin(NOW * 1.3 + Double(i)) * 0.6
                c.seg(lx, y, lx, ly, 0.3, ink)
                c.glow(lx, ly + 2, 17, rgba(255, 204, 116, 0.55), rgba(255, 204, 116, 0))
                c.poly(GOLD, [lx - 2, ly, lx + 2, ly, lx + 1.2, ly + 4, lx - 1.2, ly + 4]); c.R(lx - 0.7, ly + 1, 1.4, 2, Col(0xfff3b8))
            }
            c.R(x + 16, fy - 8, 62, 2.6, WOOD); c.R(x + 18, fy - 5.4, 2, 5.4, Col(0x5a3e22)); c.R(x + 74, fy - 5.4, 2, 5.4, Col(0x5a3e22))
            let spice: [Col] = [Col(0xe0a030), Col(0xb5412e), Col(0x7a4a8a), Col(0xe6d4a0), Col(0x5a8a4a)]
            for i in 0..<5 {
                let tx = x + 24 + Double(i) * 11.5
                c.poly(spice[i], [tx - 4.4, fy - 8, tx, fy - 15, tx + 4.4, fy - 8]); c.poly(rgba(255, 255, 255, 0.18), [tx - 4.4, fy - 8, tx, fy - 15, tx - 1, fy - 8])
            }
            figure(x + 88, fy, TEAL, Col(0xf6efdc)); figure(x + 116, fy + 2, Col(0xf6efdc), RED); figure(x + 128, fy + 1, Col(0x7a4a8a), GOLD)
            c.circ(x + 142, fy - 2.6, 3.2, GOLD); c.R(x + 140.6, fy - 6.6, 2.8, 1.6, GOLD); c.circ(x + 148, fy - 1.8, 2.2, Col(0xc98a3a))
        } else if kind == 1 || kind == 4 {
            // a temple hall: columns, the seated god, fire in the bowls
            c.vfill(x, y, pw, ph, [(0, Col(0x2a2036)), (1, Col(0x5e4a32))])
            c.R(x, fy, pw, 14, Col(0x9a8258)); c.vfill(x, fy, pw, 14, [(0, rgba(255, 220, 150, 0.25)), (1, rgba(30, 16, 8, 0.4))])
            let sx = x + pw / 2
            c.glow(sx, fy - 18, 34, rgba(255, 214, 120, kind == 1 ? 0.4 : 0.2), rgba(255, 214, 120, 0))
            for i in 0..<4 {
                let cx = x + 10 + Double(i) * 42 + (i > 1 ? 10 : 0)
                c.R(cx, y + 7, 10, fy - y - 7, STONE); c.R(cx + 7, y + 7, 3, fy - y - 7, STONE2); c.R(cx, y + 7, 1.2, fy - y - 7, rgba(255, 240, 206, 0.35))
                c.R(cx - 2, y + 3, 14, 4, STONE); c.R(cx - 1.5, fy - 3, 13, 3, STONE2)
                c.R(cx, y + 13, 10, 1.4, LAPIS); c.R(cx, y + 16, 10, 1, GOLD); c.R(cx, y + 19, 10, 1.4, RED)
                for q in 0..<6 { c.R(cx + 2 + Double(q % 2) * 3.4, y + 24 + Double(q) * 4.4, 1.6, 2.2, rgba(90, 60, 26, 0.45)) }
            }
            c.R(sx - 10, fy - 6, 20, 6, STONE2); c.R(sx - 10, fy - 6, 20, 0.8, GOLD)
            c.poly(LAPIS, [sx - 4.6, fy - 20, sx - 3.2, fy - 28.5, sx + 3.2, fy - 28.5, sx + 4.6, fy - 20])
            c.R(sx - 4, fy - 21, 8, 15, GOLD); c.R(sx - 4, fy - 11.6, 10, 5.6, GOLD); c.R(sx + 4.4, fy - 11.6, 2, 5.6, Col(0xc98a3a))
            c.circ(sx, fy - 24, 2.9, GOLD); c.R(sx - 0.5, fy - 21.4, 1, 3, LAPIS); c.R(sx - 4, fy - 16, 8, 1, LAPIS)
            for bx in [x + 36.0, x + pw - 36] {
                c.R(bx - 1, fy - 9, 2, 9, Col(0x4a3a2a)); c.poly(Col(0x8a6a3a), [bx - 4.4, fy - 11.6, bx + 4.4, fy - 11.6, bx + 2.4, fy - 8.6, bx - 2.4, fy - 8.6])
                if kind == 1 { flame(bx, fy - 11.6, 1.1) }
            }
            if kind == 1 {
                figure(x + 104, fy + 2, Col(0xf6efdc), Col(0xf6efdc))
            } else {
                // a thousand years of sand, and one shaft of daylight through the roof
                c.poly(rgba(255, 240, 200, 0.2), [sx + 14, y, sx + 30, y, sx + 44, fy + 8, sx + 6, fy + 8])
                c.poly(SAND, [x, fy - 16, x + 34, fy + 4, x, fy + 4]); c.poly(SAND, [x + pw, fy - 20, x + pw - 44, fy + 4, x + pw, fy + 4])
                c.poly(SAND2, [sx + 2, fy + 6, sx + 24, fy - 3, sx + 48, fy + 6]); c.ell(sx + 25, fy + 5, 18, 2, rgba(255, 244, 208, 0.35))
                for i in 0..<10 {
                    let n = Double(i)
                    let u = (hashN(n + 800) + NOW * 0.05 * (1 + hashN(n + 801))).truncatingRemainder(dividingBy: 1)
                    c.R(sx + 14 + hashN(n + 802) * 20 + u * 8, y + u * (ph - 8), 0.6, 0.6, rgba(255, 250, 230, 0.7))
                }
            }
        } else if kind >= 5 {
            morePanels(kind, x, y, pw, ph, fy)
        } else {
            // the tomb, and the room under it
            c.vfill(x, y, pw, ph, [(0, Col(0x14101c)), (1, Col(0x3a2c20))])
            for r in 0..<6 {
                c.R(x, y + 8 + Double(r) * 9, pw, 0.4, rgba(0, 0, 0, 0.4))
                var jx = (r % 2 == 0) ? 0.0 : 9.0
                while jx < pw { c.R(x + jx, y + 8 + Double(r) * 9, 0.4, 9, rgba(0, 0, 0, 0.3)); jx += 18 }
            }
            let paint: [Col] = [RED, LAPIS, GOLD, TEAL]
            for i in 0..<30 {
                let n = Double(i)
                c.R(x + 6 + n * 4.9, y + 11 + hashN(n + 810) * 2, 1.4 + hashN(n + 811) * 1.6, 2 + hashN(n + 812) * 3, kind == 2 ? paint[i % 4] : Col(0x5ad8c0))
            }
            c.vfill(x, y + 9, pw, 9, [(0, rgba(20, 16, 28, 0.55)), (1, rgba(20, 16, 28, 0.2))])
            c.R(x, fy, pw, 14, Col(0x4a3a2a)); c.R(x, fy, pw, 0.8, Col(0x6a543a))
            let sx = x + pw / 2
            for tx in [x + 14.0, x + pw - 14] {
                c.R(tx - 0.6, fy - 22, 1.2, 8, Col(0x5a3e22)); c.R(tx - 2, fy - 23, 4, 1.4, Col(0x8a6a3a))
                if kind == 2 { flame(tx, fy - 23, 1) } else { c.glow(tx, fy - 25, 10, rgba(90, 255, 220, 0.35), rgba(90, 255, 220, 0)) }
            }
            if kind == 2 {
                c.glow(sx, fy - 12, 40, rgba(255, 200, 100, 0.3), rgba(255, 200, 100, 0))
                c.R(sx - 27, fy - 5, 54, 5, STONE2); c.R(sx - 27, fy - 5, 54, 0.8, STONE)
                c.poly(GOLD, [sx - 24, fy - 5, sx - 22, fy - 13, sx + 16, fy - 13, sx + 24, fy - 9.5, sx + 24, fy - 5])
                for q in 0..<7 { c.R(sx - 20 + Double(q) * 5, fy - 13, 2, 8, LAPIS) }
                c.poly(LAPIS, [sx + 13, fy - 13, sx + 15, fy - 17.5, sx + 22, fy - 17, sx + 24, fy - 9.5]); c.circ(sx + 19, fy - 13.4, 3, GOLD); c.R(sx + 19.4, fy - 14.2, 1.4, 0.7, ink)
                c.poly(rgba(255, 255, 255, 0.25), [sx - 22, fy - 13, sx + 16, fy - 13, sx + 15, fy - 11.6, sx - 21.6, fy - 11.6])
                // the ankh, turning slowly in its own light
                let ay = fy - 30 + sin(NOW * 1.6) * 1.2
                c.glow(sx, ay + 3, 14, rgba(255, 236, 160, 0.6), rgba(255, 236, 160, 0))
                c.circ(sx, ay, 2.6, GOLD); c.circ(sx, ay, 1.2, Col(0x2a2030)); c.R(sx - 0.7, ay + 2.2, 1.4, 7, GOLD); c.R(sx - 3.2, ay + 3.6, 6.4, 1.3, GOLD)
                for hx in [x + 36.0, x + pw - 38] {
                    c.ell(hx, fy + 0.6, 15, 4.6, Col(0xc98a3a)); c.ell(hx, fy - 1.4, 11, 3.6, GOLD); c.ell(hx - 1, fy - 3, 6, 2.2, Col(0xffe08a))
                    for q in 0..<6 { c.ell(hx - 12 + Double(q) * 5 + hashN(hx + Double(q)) * 2, fy + 3 + hashN(hx + Double(q) + 3) * 3, 1.5, 0.8, GOLD) }
                }
                c.R(x + pw - 34, fy - 9, 13, 8, WOOD); c.R(x + pw - 34, fy - 9, 13, 1.4, GOLD); c.R(x + pw - 28.4, fy - 6.4, 1.8, 2.4, GOLD)
                for i in 0..<9 {
                    let n = Double(i)
                    if sin(NOW * 3 + n * 1.9) > 0.72 {
                        let px = (i % 2 == 0 ? x + 26 : x + pw - 50) + hashN(n + 820) * 24, py = fy - 5 + hashN(n + 821) * 6
                        c.R(px - 1.6, py - 0.25, 3.2, 0.5, Col(0xffffff)); c.R(px - 0.25, py - 1.6, 0.5, 3.2, Col(0xffffff))
                    }
                }
            } else {
                c.ell(sx, fy + 3, 40, 5, rgba(90, 255, 220, 0.2))
                c.R(sx - 7, fy - 10, 14, 10, STONE2); c.R(sx - 9, fy - 11.4, 18, 2, STONE); c.R(sx - 7, fy - 10, 1.4, 10, rgba(160, 255, 236, 0.4))
                c.glow(sx, fy - 19, 36, rgba(90, 255, 220, 0.55), rgba(90, 255, 220, 0))
                c.circ(sx, fy - 19, 5.4 + sin(NOW * 2) * 0.4, Col(0x8affe0)); c.circ(sx - 1.5, fy - 20.5, 1.7, Col(0xffffff))
                for i in 0..<7 {
                    let an = NOW * 1.4 + Double(i) * 0.9
                    c.R(sx + cos(an) * 11, fy - 19 + sin(an) * 3.4, 0.9, 0.9, Col(0xd8fff4))
                }
                for i in 0..<5 { c.R(x + 24 + Double(i) * 27, fy - 30 + hashN(Double(i) + 830) * 8, 5, 5, rgba(90, 216, 192, 0.16)) }
            }
        }
        c.vfill(x, y, pw, 9, [(0, rgba(0, 0, 0, 0.5)), (1, rgba(0, 0, 0, 0))])
        c.vfill(x, y + ph - 7, pw, 7, [(0, rgba(0, 0, 0, 0)), (1, rgba(0, 0, 0, 0.45))])
        c.alpha(1)
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
            // the river of stars, slanting across the sky
            c.save()
            c.translate(W * 0.52, GY * 0.36); c.rotate(-0.34)
            c.ell(0, 0, W * 0.75, 13, rgba(170, 180, 255, a * 0.05)); c.ell(0, 0, W * 0.62, 7, rgba(214, 210, 255, a * 0.06)); c.ell(W * 0.06, 1, W * 0.3, 3, rgba(255, 236, 226, a * 0.06))
            for i in 0..<70 {
                let n = Double(i)
                let u = hashN(n + 500) * 2 - 1, v = (hashN(n + 501) + hashN(n + 502) - 1) * 9 * (1 - abs(u) * 0.6)
                c.R(u * W * 0.66, v, 0.5, 0.5, rgba(255, 250, 236, a * (0.25 + 0.5 * hashN(n + 503)) * (0.7 + 0.3 * sin(NOW * 2 + n))))
            }
            c.restore()
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
        let lc = Col.mix(Col.mix(Col(0xe2ba7a), hz, 0.4), hz, 0.15), dc = Col.mix(Col.mix(Col(0x9c7440), hz, 0.4), hz, 0.15)
        // the small ones have lost their tops
        let cut = h < 32 ? 0.2 : 0.0
        let yt = y - h * (1 - cut)
        let rmx = x + (sp - x) * cut
        c.poly(lc, [x - w, y, x - w * cut, yt, rmx, yt + 0.5, sp, y])
        c.poly(dc, [rmx, yt + 0.5, x + w * cut, yt + 1.2, x + w, y, sp, y])
        if cut > 0 {
            c.R(x - w * cut + 1, yt - 1, 2, 1.2, lc); c.R(rmx + 1, yt - 0.4, 1.6, 1.2, dc)
        }
        // courses of stone
        var q = 3.0
        while q < h * (1 - cut) - 1 {
            let k = 1 - q / h
            let xl = x - w * k, xm = x + (sp - x) * k, xr = x + w * k
            c.R(xl, y - q, xm - xl, 0.4, rgba(120, 84, 40, 0.15))
            c.R(xm, y - q, xr - xm, 0.4, rgba(50, 30, 12, 0.14))
            // a block standing proud of the edge, or one fallen out
            let e = hashN(fx + q * 1.7)
            if e > 0.6 { c.R(xl - 0.7, y - q - 1, 1.1, 1, lc) }
            if e < 0.25 { c.R(xr - 0.6, y - q - 1, 1.2, 1, dc) }
            q += 3.5
        }
        c.seg(rmx, yt + 0.5, sp, y, 0.5, rgba(255, 240, 200, 0.35))
        // what is left of the smooth casing at the top
        if h > 50 {
            let k = 0.2
            let cap = Col.mix(lc, Col(0xfff4d8), 0.3), capd = Col.mix(dc, Col(0xfff4d8), 0.18)
            c.poly(cap, [x, y - h, x - w * k, y - h * (1 - k), x - w * k * 0.4, y - h * (1 - k) + 2, x + (sp - x) * k, y - h * (1 - k) - 1])
            c.poly(capd, [x, y - h, x + (sp - x) * k, y - h * (1 - k) - 1, x + w * k * 0.7, y - h * (1 - k) + 1.6, x + w * k, y - h * (1 - k)])
        }
        // missing blocks, stains and pale patches
        for i in 0..<(g.low ? 0 : Int(h / 3.5)) {
            let n = fx + Double(i) * 3.1
            let qq = (0.06 + hashN(n) * 0.72) * h
            let k = 1 - qq / h
            let xl = x - w * k, xm = x + (sp - x) * k, xr = x + w * k
            let v = hashN(n + 7.7)
            let px = xl + 1 + v * (xr - xl - 3)
            let sw = 0.8 + hashN(n + 2.2) * 1.8
            if hashN(n + 4.4) > 0.3 {
                c.R(px, y - qq, sw, 0.7, px < xm ? rgba(96, 62, 26, 0.3) : rgba(40, 22, 8, 0.3))
            } else {
                c.R(px, y - qq, sw, 0.6, rgba(255, 244, 212, 0.3))
            }
        }
        // the robbers' breach, with its spill of rubble
        if h > 36 {
            let qq = h * (0.22 + hashN(fx) * 0.12)
            let k = 1 - qq / h
            let bx = x - w * k + (w * k) * (0.45 + hashN(fx + 1) * 0.3)
            c.R(bx, y - qq - 2, 2.4, 2.2, rgba(40, 22, 8, 0.6)); c.R(bx - 0.4, y - qq - 2.6, 3.2, 0.6, Col.mix(lc, Col(0xfff4d8), 0.25))
            c.poly(rgba(110, 76, 36, 0.22), [bx + 0.4, y - qq, bx + 2, y - qq, bx + 5, y - qq + 9, bx - 3, y - qq + 9])
        }
        // a long crack down the shaded side
        let cx0 = x + w * 0.22
        c.seg(cx0, y - h * 0.66, cx0 + 1.5, y - h * 0.5, 0.35, rgba(30, 16, 6, 0.3)); c.seg(cx0 + 1.5, y - h * 0.5, cx0 + 0.6, y - h * 0.36, 0.35, rgba(30, 16, 6, 0.3))
    }

    func dunes(_ par: Double, _ base: Double, _ amp: Double, _ cl: Col, _ cd: Col, _ seed: Double, _ f: Double, _ rip: Bool) {
        let off = cam * par
        func hgt(_ wx: Double) -> Double {
            let a1 = (1 - abs(sin(wx * f + seed))) * 0.6
            let a2 = (0.5 + 0.5 * sin(wx * f * 2.3 + seed * 2)) * 0.28
            let a3 = (0.5 + 0.5 * sin(wx * f * 0.37 + seed * 5)) * 0.4
            return GY - base - amp * (a1 + a2 + a3)
        }
        // a smooth crest line, with the lee side of every dune lying in shadow
        var xs: [Double] = [], ys: [Double] = []
        var x = -70.0
        while x <= W + 70 { xs.append(x); ys.append(hgt(x + off)); x += 2 }
        let n = xs.count
        var body: [Double] = [xs[0], GY + 1]
        for i in 0..<n { body.append(xs[i]); body.append(ys[i]) }
        body.append(xs[n - 1]); body.append(GY + 1)
        c.poly(Col.mix(cl, cd, 0.08), body)
        let shade = Col.mix(cl, cd, 0.78), soft = Col.mix(cl, cd, 0.4)
        var pi = 1
        while pi < n - 1 {
            if ys[pi] <= ys[pi - 1] && ys[pi] < ys[pi + 1] {
                var j = pi + 1
                while j < n - 1 && ys[j + 1] >= ys[j] { j += 1 }
                let run = xs[j] - xs[pi]
                var sh: [Double] = [], sf: [Double] = []
                for k in pi...j { sh.append(xs[k]); sh.append(ys[k]) }
                sf = sh
                sh.append(xs[j] + run * 0.45); sh.append(GY + 1); sh.append(xs[pi] + run * 0.5); sh.append(GY + 1)
                sf.append(xs[j] + run * 0.45); sf.append(GY + 1); sf.append(xs[pi] + run * 0.22); sf.append(GY + 1)
                c.poly(soft, sf)
                c.poly(shade, sh)
                pi = j
            } else { pi += 1 }
        }
        for k in 0..<(n - 1) where ys[k + 1] < ys[k] - 0.02 {
            c.seg(xs[k], ys[k], xs[k + 1], ys[k + 1], 0.6, rgba(255, 244, 208, 0.5))
            if rip && !g.low && k % 2 == 0 {
                var q = 3.5
                while q < amp {
                    let wob = sin((xs[k] + off) * 0.09 + q) * 1.2
                    if ys[k] + q + wob < GY - 1 { c.seg(xs[k], ys[k] + q + wob, xs[k + 1] + 1.6, ys[k + 1] + q + wob, 0.35, rgba(120, 80, 30, 0.14)) }
                    q += 3.5
                }
            }
        }
        // specks on the sand: pebbles, stones, scrub, wind streaks and the odd glint
        let step = 6.0
        let sc = 0.55 + par
        let rock = Col.mix(cd, Col(0x6a4a2a), 0.45), scrub = Col.mix(cd, Col(0x6a7038), 0.6)
        var i = Int(floor((off - 6) / step))
        let last = g.low ? i - 1 : Int((off + W + 6) / step)
        while i <= last {
            let n = Double(i) + seed * 31
            let r = hashN(n)
            if r < 0.56 {
                let wx = Double(i) * step + hashN(n + 0.5) * step
                let y = hgt(wx), room = GY - y
                if room > 3 {
                    let sx = wx - off
                    let yy = y + 1.2 + hashN(n + 1.7) * max(0, min(room - 2.4, amp * 0.8))
                    if r < 0.2 {
                        c.R(sx, yy, 0.7 + sc * 0.6, 0.5, rgba(96, 62, 24, 0.3)); c.R(sx, yy - 0.4, 0.7 + sc * 0.6, 0.3, rgba(255, 244, 208, 0.3))
                    } else if r < 0.3 {
                        c.ell(sx, yy, 1.3 * sc, 0.75 * sc, rock); c.R(sx - 0.7 * sc, yy - 0.7 * sc, sc, 0.3, rgba(255, 240, 200, 0.35))
                        c.R(sx + 1.2 * sc, yy + 0.2, 1.6 * sc, 0.4, rgba(60, 34, 8, 0.2))
                    } else if r < 0.4 {
                        c.seg(sx, yy, sx - 1.2 * sc, yy - 2.2 * sc, 0.4, scrub); c.seg(sx, yy, sx + 0.2, yy - 2.8 * sc, 0.4, scrub); c.seg(sx, yy, sx + 1.4 * sc, yy - 2 * sc, 0.4, scrub)
                    } else if r < 0.48 {
                        c.R(sx, yy, 3 + 4 * sc, 0.35, rgba(255, 246, 214, 0.28))
                    } else if sin(NOW * 1.5 + n) > 0.8 {
                        c.R(sx, yy, 0.6, 0.6, rgba(255, 255, 240, 0.7))
                    } else {
                        c.R(sx, yy, 0.6, 0.4, rgba(255, 246, 214, 0.3))
                    }
                }
            }
            i += 1
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
        c.curve(sx - 0.5 * s, GY, sx + lean * 0.2 - 0.5 * s, GY - h * 0.5, tx - 0.5 * s, ty, 0.5 * s, rgba(255, 226, 170, 0.35))
        c.circ(tx, ty + 0.6, 1.6 * s, Col(0x5a3e22))
        if dates {
            let dz = sin(NOW * 1.6 + seed) * 0.5
            c.circ(tx - 1.5 + dz, ty + 2.5, 1.6, Col(0xd9822a)); c.circ(tx + 1.5 + dz, ty + 3, 1.6, Col(0xc2641e)); c.circ(tx + dz, ty + 4.4, 1.3, Col(0xe09a3a))
        }
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
        // brick courses, a few darker bricks, and a plinth
        var cy = 4.0
        var row = 0
        while cy < h - 1 {
            c.R(x, y + cy, w, 0.35, rgba(70, 40, 10, 0.16))
            var bx = (row % 2 == 0) ? 0.0 : 3.5
            while bx < w - 1 {
                c.R(x + bx, y + cy - 4, 0.35, 4, rgba(70, 40, 10, 0.1))
                if hashN(seed + bx * 1.7 + cy * 3.1) < 0.09 { c.R(x + bx + 0.4, y + cy - 3.7, min(6.2, w - bx - 0.6), 3.4, rgba(90, 54, 20, 0.18)) }
                bx += 7
            }
            cy += 4; row += 1
        }
        c.R(x - 0.6, y + h - 2.2, w + 1.2, 2.2, rgba(70, 40, 10, 0.22)); c.R(x, y, 1, h, rgba(255, 240, 206, 0.25))
        if h > 10 && w > 8 && !g.low {
            c.vfill(x, y + 1.2, w, min(4, h * 0.2), [(0, rgba(70, 40, 10, 0.2)), (1, rgba(70, 40, 10, 0))])
            for i in 0..<max(1, Int(w / 14)) {
                let k = Double(i)
                let sx = x + 2 + hashN(seed + k * 3.3 + 11) * (w - 6)
                let len = min(h - 4, 5 + hashN(seed + k * 4.1 + 12) * h * 0.45)
                c.vfill(sx, y + 1.2, 1 + hashN(seed + k + 13), len, [(0, rgba(70, 40, 10, 0.2)), (1, rgba(70, 40, 10, 0))])
            }
            if hashN(seed + 21) < 0.6 && h > 16 && w > 16 {
                let px = x + 3 + hashN(seed + 22) * (w - 13), py = y + h * 0.35 + hashN(seed + 23) * h * 0.4
                c.R(px, py, 6, 3.4, rgba(120, 76, 36, 0.22)); c.R(px + 1, py - 1, 3.6, 1, rgba(120, 76, 36, 0.22)); c.R(px + 1.4, py + 3.4, 3, 0.9, rgba(120, 76, 36, 0.22))
                c.R(px, py + 1.6, 6, 0.3, rgba(60, 34, 8, 0.3)); c.R(px + 3, py, 0.3, 1.6, rgba(60, 34, 8, 0.3))
            }
        }
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
        c.arch(x - 0.8, y - 0.8, w + 1.6, h + 1.2, rgba(255, 244, 214, 0.55))
        c.arch(x, y, w, h, lit ? Col.mix(Col(0xffd27a), Col(0xffb04a), 0.5 + 0.5 * sin(NOW * 9 + x)) : DARKC)
        c.R(x - 1.2, y + h, w + 2.4, 1, Col(0x8a6434))
        c.R(x - 1.8, y + w / 2, 1.4, h - w / 2, TEAL.alpha(0.85)); c.R(x + w + 0.4, y + w / 2, 1.4, h - w / 2, TEAL.alpha(0.85))
        c.R(x + w / 2 - 0.2, y + 1, 0.4, h - 1, rgba(40, 24, 10, 0.5))
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
            plot(b, x)
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
        if t == .well && L >= 1 { wellExtra(x) }
        if b.def.gate && L >= 2 && b.hp > 0 { gateExtra(x, L) }
        if b.def.gate && L >= 1 && b.hp > 0 {
            // the gate shows its hurt: cracks, then splinters, then a hole
            let k = 1 - b.hp / max(1, GHP[min(L, GHP.count - 1)])
            let hh = b.tall, crack = rgba(30, 16, 6, 0.75)
            if k > 0.2 { c.seg(x + 3, GY - hh * 0.85, x + 6, GY - hh * 0.6, 0.45, crack); c.seg(x + 6, GY - hh * 0.6, x + 4.4, GY - hh * 0.38, 0.45, crack) }
            if k > 0.45 {
                c.seg(x + 10, GY - hh * 0.7, x + 8, GY - hh * 0.45, 0.45, crack); c.seg(x + 8, GY - hh * 0.45, x + 10.6, GY - hh * 0.2, 0.45, crack)
                c.poly(crack, [x + 7, GY - hh - 0.4, x + 11, GY - hh - 0.4, x + 9.6, GY - hh + 4])
                for q in 0..<4 { c.seg(x - 3 + Double(q) * 6, GY - 0.4, x - 1 + Double(q) * 6, GY - 1.6 - Double(q % 2), 0.5, WOOD) }
            }
            if k > 0.7 {
                c.RR(x + 4.6, GY - hh * 0.55, 4.6, hh * 0.3, 1.2, rgba(16, 8, 2, 0.8))
                if g.dark < 0.95 { plume(x + 7, GY - hh, b.x + 2, 0.5, Col(0x8a8078)) }
            }
        }
        if plain && L >= 1 {
            dress(b, x, L)
            topTier(b, x, L)
            midTier(b, x, L)
            townTrim(b, x, L)
            // one gold pip by the door for each level raised
            for q in 0..<L { c.R(x + 2 + Double(q) * 2.6, GY - 2.6, 1.6, 1.6, rgba(28, 19, 12, 0.6)); c.R(x + 2.3 + Double(q) * 2.6, GY - 2.3, 1, 1, GOLD) }
        }
        if b.building && L >= 1 {
            let nh = b.def.h[min(L + 1, b.def.h.count - 1)]
            scaffold(b, x, nh, (b.def.gate || t == .well) ? 0 : b.tall)
        }
        if plain && L >= 1 {
            c.poly(rgba(236, 206, 146, 0.75), [x - 4, GY + 0.6, x - 1, GY - 1.6, x + 5, GY - 0.4, x + 9, GY + 0.6])
            c.poly(rgba(236, 206, 146, 0.75), [x + w - 10, GY + 0.6, x + w - 3, GY - 0.6, x + w + 1, GY - 2, x + w + 5, GY + 0.6])
            c.R(x - 1, GY - 1.7, 3, 0.4, rgba(255, 244, 208, 0.6)); c.R(x + w - 1, GY - 2.1, 2.6, 0.4, rgba(255, 244, 208, 0.6))
        }
        if lit && plain && L >= 1 && !b.robbed {
            // lamplight from the doorway lying across the street
            let mx = x + w * 0.5
            c.poly(rgba(255, 190, 90, 0.14), [mx - 5, GY, mx + 5, GY, mx + 15, GY + 10, mx - 15, GY + 10])
            c.poly(rgba(255, 214, 130, 0.12), [mx - 3, GY, mx + 3, GY, mx + 7, GY + 10, mx - 7, GY + 10])
            light(mx, GY + 3, 20, 0.45)
        }
        if b.robbed && L > 0 && plain {
            fire(x + w * 0.28, GY - b.tall + 3, 1.2); fire(x + w * 0.7, GY - b.tall * 0.62, 1); fire(x + w * 0.5, GY - 6, 0.8)
        }
        c.restore()
    }

    // ---------- what makes each town its own place

    /// The canyon town: one red wall of rock behind the street, with homes cut into it on two levels.
    func canyonBack(_ hz: Col, _ built: Int) {
        let x0 = g.TOWN.0 - 60 - cam, x1 = g.TOWN.1 + 60 - cam
        if x1 < -20 || x0 > W + 20 { return }
        let rock = Col.mix(Col(0xb0623a), hz, 0.22), dark = Col.mix(Col(0x8a4628), hz, 0.22), lite = Col.mix(Col(0xd08a5c), hz, 0.22)
        var top: [Double] = [x0 - 30, GY]
        var wx = g.TOWN.0 - 60
        while wx <= g.TOWN.1 + 60 {
            let n = floor(wx / 36)
            top.append(wx - cam); top.append(GY - 74 - hashN(n + 40) * 26 - (Int(n) % 3 == 0 ? 10 : 0))
            wx += 18
        }
        top.append(x1 + 30); top.append(GY)
        c.poly(rock, top)
        var q = 8.0
        while q < 96 { c.R(max(x0, -4), GY - q + sin(q) * 1.5, min(x1, W + 4) - max(x0, -4), 0.8, rgba(70, 28, 12, 0.14 + 0.06 * Double(Int(q) % 3))); q += 7 }
        var i = Int(floor((cam + g.TOWN.0 * 0 - 40) / 34))
        let last = Int((cam + W + 40) / 34)
        while i <= last {
            let n = Double(i)
            let hx = n * 34 + hashN(n + 50) * 8
            i += 1
            if hx < g.TOWN.0 - 30 || hx > g.TOWN.1 + 20 { continue }
            let x = hx - cam
            let alive = Int(n) % 6 < built
            // a long crack, and a ledge that runs along the upper homes
            c.seg(x + 20, GY - 70, x + 17 + hashN(n + 51) * 6, GY - 44, 0.5, rgba(60, 24, 10, 0.4))
            c.R(x - 2, GY - 33, 36, 2.2, lite); c.R(x - 2, GY - 30.8, 36, 1.4, dark)
            for lv in 0..<2 {
                let by = GY - Double(lv) * 33
                let dx = x + 6 + Double(lv) * 9
                c.arch(dx, by - 17, 9, 17, Col.mix(Col(0x2a120a), hz, 0.2))
                c.R(dx - 1.4, by - 18.6, 11.8, 1.6, lite)
                if alive {
                    let cloth: [Col] = [RED, TEAL, GOLD, LAPIS]
                    c.poly(Col.mix(cloth[(i + lv) % 4], hz, 0.3), [dx, by - 17, dx + 9, by - 17, dx + 7.6 + sin(NOW * 2 + n) * 0.6, by - 5, dx + 1.4, by - 5])
                    c.arch(dx + 14, by - 15, 5, 7, lit ? Col(0xffd27a) : Col.mix(Col(0x2a120a), hz, 0.2))
                    if lit { light(dx + 16.5, by - 11, 9, 0.5) }
                    c.R(dx + 13, by - 7.6, 7, 1, lite)
                    if lv == 1 && g.dark < 0.9 && Int(n) % 2 == 0 { plume(dx + 4, by - 20, n + 3, 0.5) }
                } else {
                    c.arch(dx + 14, by - 15, 5, 7, Col.mix(Col(0x2a120a), hz, 0.2))
                }
            }
            // a ladder up to the ledge
            let lx = x + 27
            c.seg(lx, GY, lx + 1.2, GY - 33, 0.5, dark); c.seg(lx + 3, GY, lx + 4.2, GY - 33, 0.5, dark)
            var ly = 3.0
            while ly < 33 { c.R(lx + ly / 33 * 1.2, GY - ly, 3.2, 0.4, dark); ly += 3.4 }
        }
    }
    /// The holy city: a colonnade the length of the street, colossi, pylons and obelisks. Columns stand as the town is rebuilt.
    func holyBack(_ hz: Col, _ built: Int) {
        let stone = Col.mix(STONE, hz, 0.32), shade = Col.mix(STONE2, hz, 0.32), hi = Col.mix(Col(0xfff0c8), hz, 0.3)
        let x0 = g.TOWN.0 + 16 - cam, x1 = g.TOWN.1 - 16 - cam
        if x1 < -20 || x0 > W + 20 { return }
        c.R(x0, GY - 4, x1 - x0, 4, shade); c.R(x0, GY - 4, x1 - x0, 0.8, hi)
        var i = 0
        var wx = g.TOWN.0 + 22
        var beam: [(Double, Double)] = []
        while wx < g.TOWN.1 - 24 {
            let n = Double(i), x = wx - cam
            let up = hashN(n + 60) < 0.3 + Double(built) / 6 * 0.7
            if x > -20 && x < W + 20 {
                if i % 9 == 4 {
                    // a seated colossus
                    c.R(x - 4, GY - 12, 18, 8, shade); c.RR(x - 1, GY - 40, 12, 28, 2, stone); c.R(x + 8, GY - 40, 3, 28, shade)
                    c.R(x - 1, GY - 20, 15, 8, stone); c.RR(x + 0.6, GY - 52, 9, 11, 2.6, stone); c.RR(x - 0.8, GY - 55, 11.8, 4.6, 1.4, Col.mix(LAPIS, hz, 0.4))
                    c.R(x - 1.6, GY - 51, 2.6, 12, Col.mix(LAPIS, hz, 0.4)); c.R(x + 9.4, GY - 51, 2.6, 12, Col.mix(LAPIS, hz, 0.4)); c.R(x + 4, GY - 42, 2.4, 3.4, Col.mix(GOLD, hz, 0.4))
                    c.R(x + 2.4, GY - 48.6, 1.6, 1, shade); c.R(x + 6.4, GY - 48.6, 1.6, 1, shade)
                } else if i % 9 == 0 {
                    // an obelisk
                    c.poly(stone, [x + 1, GY - 4, x + 2, GY - 62, x + 6, GY - 62, x + 7, GY - 4]); c.poly(shade, [x + 4.6, GY - 4, x + 4.4, GY - 62, x + 6, GY - 62, x + 7, GY - 4])
                    c.poly(Col.mix(GOLD, hz, 0.35), [x + 2, GY - 62, x + 4, GY - 67, x + 6, GY - 62])
                    for k in 0..<8 { c.R(x + 3, GY - 56 + Double(k) * 6, 1.8, 2.4, rgba(90, 60, 26, 0.4)) }
                } else if up {
                    c.R(x, GY - 40, 6, 36, stone); c.R(x + 4, GY - 40, 2, 36, shade); c.R(x, GY - 40, 0.9, 36, hi)
                    c.R(x - 1.4, GY - 43, 8.8, 3.4, stone); c.R(x - 1, GY - 6.4, 8, 2.4, shade)
                    c.R(x, GY - 36, 6, 1.4, Col.mix(LAPIS, hz, 0.4)); c.R(x, GY - 33.6, 6, 1, Col.mix(GOLD, hz, 0.4)); c.R(x, GY - 31.6, 6, 1.4, Col.mix(RED, hz, 0.4))
                    beam.append((x - 1.4, x + 7.4))
                } else {
                    let bh = 6 + hashN(n + 61) * 14
                    c.R(x, GY - 4 - bh, 6, bh, stone); c.R(x + 4, GY - 4 - bh, 2, bh, shade)
                    c.poly(stone, [x, GY - 4 - bh, x + 2, GY - 7 - bh, x + 4.4, GY - 5 - bh, x + 6, GY - 4 - bh])
                    c.RR(x + 7, GY - 7, 5, 3, 1, shade)
                }
            }
            wx += 15; i += 1
        }
        // the lintel lies only where two standing columns are neighbours
        for k in 0..<max(0, beam.count - 1) where beam[k + 1].0 - beam[k].1 < 9 {
            c.R(beam[k].0, GY - 47, beam[k + 1].1 - beam[k].0, 4.2, stone); c.R(beam[k].0, GY - 47, beam[k + 1].1 - beam[k].0, 0.8, hi)
            c.R(beam[k].0, GY - 43.6, beam[k + 1].1 - beam[k].0, 0.8, shade)
        }
    }
    /// The harbour town: the river runs behind the street, with ships moored between the houses and a crane on the quay.
    func harbourBack(_ hz: Col) {
        let x0 = g.TOWN.0 - 20 - cam, x1 = g.TOWN.1 + 20 - cam
        if x1 < -20 || x0 > W + 20 { return }
        let water = Col.mix(Col(0x3f8fb0), hz, 0.3), hull = Col.mix(Col(0x5e3a1e), hz, 0.3), sail = Col.mix(Col(0xf6efdc), hz, 0.3), rope = Col.mix(Col(0x4a3320), hz, 0.3)
        c.R(max(x0, -4), GY - 15, min(x1, W + 4) - max(x0, -4), 15, water)
        c.R(max(x0, -4), GY - 15, min(x1, W + 4) - max(x0, -4), 0.8, Col.mix(Col(0xcfeaf2), hz, 0.3))
        var i = Int(floor((cam - 80) / 96))
        let last = Int((cam + W + 80) / 96)
        while i <= last {
            let n = Double(i)
            let sxw = n * 96 + hashN(n + 70) * 30
            i += 1
            if sxw < g.TOWN.0 + 10 || sxw > g.TOWN.1 - 30 { continue }
            let x = sxw - cam, bob = sin(NOW * 1.3 + n) * 0.6
            let mh = 58 + hashN(n + 71) * 16
            c.poly(hull, [x - 16, GY - 13 + bob, x - 12, GY - 8 + bob, x + 14, GY - 8 + bob, x + 20, GY - 14 + bob, x + 14, GY - 4, x - 12, GY - 4])
            c.seg(x, GY - 8 + bob, x, GY - mh + bob, 1, rope)
            if Int(n) % 2 == 0 {
                c.poly(sail, [x - 11, GY - 20 + bob, x + 8, GY - mh + 2 + bob, x + 13, GY - 16 + bob])
                c.seg(x - 12, GY - 19 + bob, x + 9, GY - mh + 1 + bob, 0.6, rope)
            } else {
                // sail furled on its yard
                c.seg(x - 10, GY - mh + 10 + bob, x + 10, GY - mh + 6 + bob, 0.8, rope)
                c.RR(x - 9, GY - mh + 7.4 + bob, 18, 2.6, 1.2, sail)
                c.seg(x, GY - mh + bob, x - 14, GY - 12 + bob, 0.25, rope); c.seg(x, GY - mh + bob, x + 16, GY - 13 + bob, 0.25, rope)
            }
            c.poly(Col.mix(RED, hz, 0.3), [x, GY - mh + bob, x + 6 + sin(NOW * 4 + n), GY - mh + 1.6 + bob, x, GY - mh + 3.2 + bob])
            if lit { c.glow(x - 13, GY - 16 + bob, 6, rgba(255, 204, 116, 0.8), rgba(255, 204, 116, 0)); light(x - 13, GY - 15, 9, 0.5) }
        }
        // the quay crane, lifting a crate
        let cx = g.TOWN.0 + 250 - cam
        if cx > -40 && cx < W + 40 {
            let lift = 8 + sin(NOW * 0.6) * 6
            c.seg(cx, GY, cx + 6, GY - 52, 1.2, rope); c.seg(cx + 12, GY, cx + 6, GY - 52, 1.2, rope); c.seg(cx + 6, GY - 52, cx + 30, GY - 60, 1.2, rope)
            c.seg(cx + 30, GY - 60, cx + 30, GY - 34 - lift, 0.35, rope)
            c.R(cx + 26, GY - 34 - lift, 8, 7, Col.mix(Col(0x9a7040), hz, 0.3)); c.R(cx + 26, GY - 31 - lift, 8, 0.6, rope)
        }
    }
    /// The garden town: tall palms the length of the street, heavy with dates, and flowers at their feet.
    func gardenBack(_ hz: Col) {
        var wx = g.TOWN.0 + 46
        var i = 0
        while wx < g.TOWN.1 - 30 {
            let x = wx - cam, n = Double(i)
            if x > -30 && x < W + 30 {
                let h = 40 + hashN(n + 80) * 12, lean = (hashN(n + 81) - 0.5) * 8
                let sway = sin(NOW * 0.9 + n) * 1.2
                c.curve(x, GY, x + lean * 0.3, GY - h * 0.5, x + lean + sway, GY - h, 2.2, Col.mix(Col(0x7a5632), hz, 0.2))
                let tx = x + lean + sway, ty = GY - h
                for k in 0..<7 {
                    let a = -2.9 + Double(k) * 0.46
                    c.curve(tx, ty, tx + cos(a) * 9, ty + sin(a) * 9 - 3, tx + cos(a) * 17, ty + sin(a) * 8 + 5, 1.5, Col.mix(k % 2 == 0 ? Col(0x3f8a3a) : Col(0x2f6a2e), hz, 0.18))
                }
                c.circ(tx - 1.6, ty + 2.4, 1.6, Col(0xd98a2a)); c.circ(tx + 1.2, ty + 3, 1.6, Col(0xe0a030)); c.circ(tx - 0.2, ty + 4.4, 1.4, Col(0xc47a22))
                let fl: [Col] = [RED, Col(0xf6efdc), GOLD, Col(0xd96ad0)]
                for k in 0..<4 { c.circ(x - 5 + Double(k) * 3.4, GY - 1.6 - Double(k % 2), 1, fl[(i + k) % 4]) }
                c.ell(x, GY - 0.6, 7, 1.4, Col.mix(Col(0x4a8a3a), hz, 0.2))
            }
            wx += 46; i += 1
        }
    }
    /// The street itself: grass in the garden town, red rock in the canyon, planks on the quay, flagstones in the holy city.
    func townGround() {
        let tx0 = g.TOWN.0 - cam, tx1 = g.TOWN.1 - cam
        let a = max(tx0, -4), b = min(tx1, W + 4)
        switch g.feat {
        case .oasis:
            let grass = rgba(104, 158, 74, 0.62), clear = rgba(104, 158, 74, 0)
            c.linear(tx0 - 40, GY, 40, H - GY, tx0 - 40, 0, tx0, 0, [(0, clear), (1, grass)])
            if b > a { c.R(a, GY, b - a, H - GY, grass); c.R(a, GY, b - a, 1, Col(0x8fc46a)) }
            c.linear(tx1, GY, 40, H - GY, tx1, 0, tx1 + 40, 0, [(0, grass), (1, clear)])
            var i = Int(floor((cam + max(0, tx0)) / 7))
            let last = Int((cam + b) / 7)
            while i <= last {
                let n = Double(i), x = n * 7 + hashN(n + 90) * 5 - cam, y = GY + 2 + hashN(n + 91) * (H - GY - 6)
                if x > a && x < b {
                    c.seg(x, y, x - 0.8, y - 2.2, 0.4, Col(0x4a8a3a)); c.seg(x, y, x + 0.9, y - 2.6, 0.4, Col(0x5a9a44))
                    if i % 5 == 0 { c.circ(x + 1.6, y - 1, 0.7, i % 2 == 0 ? Col(0xf6efdc) : Col(0xf2c14e)) }
                }
                i += 1
            }
        case .cliff:
            c.R(-4, GY, W + 8, H - GY + 4, rgba(176, 84, 44, 0.3))
            var i = Int(floor(cam / 23))
            let last = Int((cam + W) / 23) + 1
            while i <= last {
                let n = Double(i), x = n * 23 + hashN(n + 92) * 14 - cam, y = GY + 3 + hashN(n + 93) * (H - GY - 8)
                c.seg(x, y, x + 5, y + 1.6, 0.4, rgba(80, 30, 12, 0.4)); c.seg(x + 5, y + 1.6, x + 8, y + 0.6, 0.4, rgba(80, 30, 12, 0.4))
                if i % 3 == 0 { c.RR(x + 10, y - 1, 3.4, 2.2, 1, Col(0x9a5632)); c.R(x + 10.4, y - 1, 2.4, 0.5, Col(0xd08a5c)) }
                i += 1
            }
        case .port:
            if b > a {
                c.R(a, GY, b - a, 10, Col(0x8a6238)); c.R(a, GY, b - a, 0.9, Col(0xc49a62)); c.R(a, GY + 10, b - a, 1.6, Col(0x5a3e22))
                c.R(a, GY + 11.6, b - a, H - GY - 11.6, rgba(60, 110, 140, 0.28))
                var i = Int(floor((cam + a) / 7))
                let last = Int((cam + b) / 7)
                while i <= last {
                    let x = Double(i) * 7 - cam
                    if x > a && x < b { c.R(x, GY + 0.9, 0.4, 9, rgba(50, 30, 12, 0.45)); c.R(x + 3, GY + 2 + hashN(Double(i) + 94) * 6, 0.7, 0.7, Col(0x3a2a1a)) }
                    if i % 6 == 0 && x > a && x < b { c.R(x - 1, GY + 10, 2.4, H - GY - 10, Col(0x4a3320)); c.R(x - 1, GY + 10, 0.7, H - GY - 10, Col(0x7a5632)) }
                    i += 1
                }
            }
        case .temple:
            if b > a {
                c.R(a, GY, b - a, H - GY, rgba(222, 208, 170, 0.7)); c.R(a, GY, b - a, 1, Col(0xfff0c8))
                var row = 0
                var y = GY + 4.0
                while y < H {
                    c.R(a, y, b - a, 0.5, rgba(110, 90, 50, 0.35))
                    let step = 14.0 + Double(row) * 3
                    var k = Int(floor((cam + a) / step))
                    while Double(k) * step - cam < b {
                        let x = Double(k) * step + (row % 2 == 0 ? 0 : step / 2) - cam
                        if x > a && x < b { c.R(x, y - (4 + Double(row) * 1.6), 0.5, 4 + Double(row) * 1.6, rgba(110, 90, 50, 0.3)) }
                        k += 1
                    }
                    y += 5.6 + Double(row) * 1.6; row += 1
                }
            }
        default:
            break
        }
    }
    /// Things standing on the approach roads, different in every town.
    func townProps() {
        if g.low || g.feat == .pyramid { return }
        func free(_ wx: Double) -> Bool {
            if g.camps.contains(where: { abs($0.x - wx) < 46 }) || g.urns.contains(where: { abs($0.x - wx) < 22 }) { return false }
            if abs(wx - g.QUARRY) < 70 { return false }
            return !g.bs.contains(where: { !$0.gone && wx > $0.x - 30 && wx < $0.x + $0.w + 30 })
        }
        for side in [-1.0, 1.0] {
            for k in 1..<6 {
                let wx = (side < 0 ? g.TOWN.0 : g.TOWN.1) + side * (34 + Double(k) * 44)
                let x = wx - cam
                if x < -30 || x > W + 30 || !free(wx) { continue }
                let n = wx
                switch g.feat {
                case .temple:
                    // the avenue of sphinxes
                    let f = -side
                    c.ell(x, GY + 0.6, 9, 1.4, rgba(60, 34, 8, 0.25))
                    c.R(x - 8, GY - 3, 16, 3, STONE2); c.R(x - 8, GY - 3, 16, 0.6, Col(0xfff0c8))
                    c.RR(x - 6, GY - 8, 12, 5, 2, STONE); c.RR(x + f * 3 - 2.4, GY - 13, 4.8, 6, 1.6, STONE)
                    c.R(x + f * 3 - 3, GY - 13.6, 6, 1.6, LAPIS); c.R(x + f * 5, GY - 5, f * 4, 2, STONE)
                case .port:
                    c.R(x - 6, GY - 6, 7, 6, Col(0x9a7040)); c.R(x - 6, GY - 6, 7, 0.8, Col(0xc49a62)); c.R(x - 6, GY - 3.2, 7, 0.5, Col(0x5a3e22))
                    c.R(x - 4, GY - 11.4, 6, 5.4, Col(0xa87a48)); c.R(x - 4, GY - 11.4, 6, 0.8, Col(0xc49a62))
                    c.RR(x + 3, GY - 7, 5, 7, 2, Col(0x6a4426)); c.R(x + 3, GY - 5.4, 5, 0.6, Col(0x3a2a1a)); c.R(x + 3, GY - 2.4, 5, 0.6, Col(0x3a2a1a))
                    if k % 2 == 0 { c.ell(x + 12, GY - 0.8, 4, 1.4, Col(0xb8a070)); c.ell(x + 12, GY - 1.2, 2.4, 0.8, Col(0x8a7448)) }
                    if !lit && hashN(n) > 0.5 {
                        let gy = GY - 8 - abs(sin(NOW * 2 + n)) * 2
                        c.ell(x - 12, gy, 2.4, 1.2, Col(0xf6f6f0)); c.circ(x - 12 - side * 2, gy - 1, 1, Col(0xf6f6f0)); c.R(x - 12 - side * 3.4, gy - 1, 1, 0.5, GOLD)
                    }
                case .cliff:
                    c.ell(x, GY + 0.4, 9, 1.4, rgba(60, 24, 8, 0.25))
                    c.poly(Col(0x9a5632), [x - 9, GY, x - 6, GY - 7, x + 1, GY - 10, x + 7, GY - 6, x + 10, GY]); c.poly(Col(0xc47c4e), [x - 6, GY - 7, x + 1, GY - 10, x + 3, GY - 6, x - 3, GY - 4])
                    c.poly(Col(0x7e4426), [x + 6, GY, x + 9, GY - 4, x + 14, GY - 3, x + 16, GY])
                    if k % 2 == 1 { c.seg(x - 12, GY, x - 13, GY - 5, 0.5, Col(0x6a7038)); c.seg(x - 12, GY, x - 10.6, GY - 6, 0.5, Col(0x6a7038)) }
                default:
                    // the garden town: flower beds and a bush
                    c.ell(x, GY - 2, 7, 3.4, Col(0x3f7d3a)); c.ell(x - 3, GY - 4, 4, 2.6, Col(0x5a9a44))
                    let fl: [Col] = [RED, Col(0xf6efdc), GOLD, Col(0xd96ad0)]
                    for q in 0..<5 { c.circ(x - 6 + Double(q) * 3 + hashN(n + Double(q)) * 1.4, GY - 3.6 - hashN(n + Double(q) + 5) * 2.4, 0.9, fl[(k + q) % 4]) }
                    if k % 2 == 0 && !lit {
                        let bx = x + 8 + sin(NOW * 1.7 + n) * 6, by = GY - 10 + sin(NOW * 2.9 + n) * 3, fp = abs(sin(NOW * 14 + n)) * 1.6
                        c.poly(Col(0xf2c14e), [bx, by, bx - fp, by - 1.6, bx - fp * 0.7, by + 1]); c.poly(Col(0xf2c14e), [bx, by, bx + fp, by - 1.6, bx + fp * 0.7, by + 1])
                    }
                }
            }
        }
    }
    /// A touch on every town building in the local style.
    func townTrim(_ b: Building, _ x: Double, _ L: Int) {
        if L < 1 { return }
        let w = b.w, top = GY - b.tall
        switch g.feat {
        case .oasis:
            // a vine up the corner, and a flower box
            var q = 2.0
            while q < b.tall - 4 {
                let vx = x + 1.6 + sin(q * 0.5 + b.x) * 1.4
                c.circ(vx, GY - q, 1.3, q.truncatingRemainder(dividingBy: 6) < 3 ? Col(0x3f8a3a) : Col(0x5a9a44))
                q += 2.6
            }
            c.R(x + w - 13, GY - 13, 9, 1.6, Col(0x7a5632))
            for k in 0..<4 { c.circ(x + w - 12 + Double(k) * 2.4, GY - 14, 1, k % 2 == 0 ? RED : Col(0xd96ad0)) }
        case .cliff:
            // beam ends under the roof and an ochre band at the foot
            var q = 4.0
            while q < w - 3 { c.R(x + q, top + 5, 1.6, 1.6, Col(0x5a3018)); c.R(x + q, top + 5, 1.6, 0.4, Col(0x9a5632)); q += 7 }
            c.R(x, GY - 4, w, 4, rgba(140, 60, 26, 0.4))
        case .port:
            // a blue band, a coil of rope and a net hung to dry
            c.R(x, top + 6, w, 2.2, Col(0x2f6f9a)); c.R(x, top + 8.2, w, 0.6, Col(0xf6efdc))
            c.ell(x + 5, GY - 1.2, 3, 1.2, Col(0xb8a070)); c.ell(x + 5, GY - 1.8, 1.8, 0.7, Col(0x8a7448))
            c.curve(x + w - 16, top + 12, x + w - 9, top + 19, x + w - 2, top + 12, 0.3, Col(0x3a2a1a))
            for k in 0..<5 { c.seg(x + w - 15 + Double(k) * 3, top + 12.6, x + w - 14 + Double(k) * 2.6, top + 17, 0.25, rgba(58, 42, 26, 0.6)) }
        case .temple:
            // a gilded cornice, a painted frieze and a pilaster at each corner
            c.R(x - 1, top - 1.2, w + 2, 2, GOLD); c.R(x - 1, top + 0.8, w + 2, 0.6, Col(0x8a5a22))
            var q = 1.0
            var k = 0
            while q < w - 3 { c.R(x + q, top + 2.4, 3, 2.6, k % 2 == 0 ? LAPIS : RED); q += 4; k += 1 }
            c.R(x, top + 5.4, 2.6, b.tall - 5.4, rgba(255, 240, 200, 0.3)); c.R(x + w - 2.6, top + 5.4, 2.6, b.tall - 5.4, rgba(60, 34, 8, 0.2))
        default:
            break
        }
    }
    /// What the middle levels add: something you can recognise from across the street.
    func midTier(_ b: Building, _ x: Double, _ L: Int) {
        if L < 2 { return }
        let w = b.w, top = GY - b.tall
        let maxed = L >= b.def.cost.count
        switch b.type {
        case .market:
            c.curve(x + 8, top + 7, x + w / 2, top + 11.6, x + w - 8, top + 7, 0.25, Col(0x5a3e22))
            let lamp: [Col] = [RED, GOLD, TEAL]
            for q in 0..<6 {
                let lx = x + 8 + Double(q) * (w - 16) / 5, ly = top + 7 + sin(PI * Double(q) / 5) * 2.3
                c.RR(lx - 0.9, ly, 1.8, 2.4, 0.6, lit ? Col(0xffd27a) : lamp[q % 3])
                if lit { light(lx, ly + 1, 6, 0.4) }
            }
            if !maxed {
                for k in 0..<(L >= 3 ? 2 : 1) {
                    let px = x + 18 + Double(k) * 36
                    c.seg(px, top, px, top - 9, 0.5, WOOD)
                    c.poly(k == 0 ? RED : LAPIS, [px - 7, top - 7.6, px, top - 11, px + 7, top - 7.6]); c.poly(Col(0xf6efdc), [px - 2.4, top - 9.8, px, top - 11, px + 2.4, top - 9.8])
                    c.RR(px + 3, top - 1.6, 6, 1.6, 0.5, Col(0x7a4a8a)); c.RR(px + 3.4, top - 3, 5.2, 1.5, 0.5, GOLD); c.RR(px + 3.8, top - 4.3, 4.4, 1.4, 0.5, TEAL)
                }
            }
        case .tea:
            if !maxed {
                c.R(x + 6, top - 1.2, w - 12, 1.2, Col(0x8f2a1c))
                let cush: [Col] = [TEAL, GOLD, RED, LAPIS]
                for q in 0..<4 { c.RR(x + 10 + Double(q) * 12, top - 3.5, 6, 2.4, 1, cush[q]) }
                c.R(x + w - 16, top - 5.4, 0.8, 4.2, GOLD); c.circ(x + w - 15.6, top - 6, 1.4, TEAL)
                if g.dark < 0.95 { plume(x + w - 15.6, top - 7.4, b.x + 4, 0.35) }
            }
            for sx in [x - 3.0, x + w + 2] {
                c.R(sx, GY - 13, 0.8, 13, WOOD); c.RR(sx - 1, GY - 16.4, 2.8, 3.6, 0.8, lit ? Col(0xffd27a) : GOLD); c.R(sx - 1.3, GY - 16.8, 3.4, 0.6, Col(0x5a3e22))
                if lit { light(sx + 0.4, GY - 14.6, 11, 0.5) }
            }
        case .guard:
            for sx in [x + 8.0, x + w - 12] {
                let sw = sin(NOW * 2 + sx) * 0.6
                c.poly(RED, [sx, top + 5, sx + 4, top + 5, sx + 4 + sw, top + 19, sx + 2 + sw, top + 17, sx + sw, top + 19])
                c.R(sx, top + 5, 4, 0.8, GOLD); c.circ(sx + 2 + sw * 0.4, top + 10, 1, GOLD)
            }
            if !maxed && L >= 3 {
                let lx = x + w - 20
                c.R(lx + 2, top - 10, 1, 10, WOOD); c.R(lx + 12, top - 10, 1, 10, WOOD); c.R(lx, top - 11.4, 15, 1.6, WOOD); c.R(lx + 1, top - 5, 13, 0.8, WOOD)
                c.poly(Col(0xb58a52), [lx - 1, top - 11.4, lx + 7.5, top - 16, lx + 16, top - 11.4])
                c.RR(lx + 5.6, top - 9.6, 3, 4.6, 0.8, Col(0xe8dcc0)); c.circ(lx + 7.1, top - 10.6, 1.3, Col(0xb8804e)); c.RR(lx + 5.7, top - 12.3, 2.8, 1.6, 0.8, Col(0xc98a3a))
                c.seg(lx + 9.6, top - 5, lx + 9.6, top - 14.6, 0.4, Col(0x8f6a3e))
            } else if !maxed {
                c.R(x + 6, top - 4, 1, 4, Col(0x4a3a2a)); c.R(x + 4.8, top - 5, 3.4, 1.2, Col(0x6a5238))
                if lit { fire(x + 6.5, top - 5, 0.5) }
            }
        case .pen:
            c.RR(x + w - 22, GY - 5, 8, 5, 1, Col(0xd9b85a)); c.RR(x + w - 18, GY - 9.4, 8, 4.6, 1, Col(0xe0c26a))
            c.R(x + w - 22, GY - 3, 8, 0.4, Col(0x8a6a2a)); c.R(x + w - 18, GY - 7.4, 8, 0.4, Col(0x8a6a2a))
            c.RR(x + 26, GY - 3.4, 12, 3.4, 0.8, Col(0x6a4a2a)); c.R(x + 27, GY - 3, 10, 1.2, Col(0x6fb6c8)); c.R(x + 29 + sin(NOW * 2) * 2, GY - 2.8, 3, 0.3, rgba(255, 255, 255, 0.6))
            if !maxed {
                let a = sin(NOW * 0.7 + b.x) * 3
                c.seg(x + 8, top, x + 8, top - 8, 0.4, Col(0x4a3a2a)); c.poly(GOLD, [x + 8 - a, top - 8.6, x + 8 + a, top - 7.4, x + 8 + a * 0.6, top - 6.4]); c.circ(x + 8, top - 8, 0.6, Col(0x4a3a2a))
            }
        case .temple:
            for sx in [x + 3.0, x + w - 7] {
                let sw = sin(NOW * 1.6 + sx) * 0.5
                c.poly(LAPIS, [sx, top + 4, sx + 4, top + 4, sx + 4 + sw, top + 22, sx + sw, top + 22])
                c.R(sx, top + 4, 4, 0.8, GOLD); c.R(sx + sw * 0.5, top + 12, 4, 0.8, GOLD); c.circ(sx + 2 + sw * 0.3, top + 8, 1, GOLD)
            }
            for sx in [x - 7.0, x + w + 2] {
                c.R(sx, GY - 3, 5, 3, STONE2); c.RR(sx + 0.8, GY - 9, 3.4, 6, 0.8, STONE); c.circ(sx + 2.5, GY - 10.4, 1.5, STONE); c.R(sx + 0.8, GY - 5.4, 4.4, 2.4, STONE); c.R(sx + 1.4, GY - 11.8, 2.2, 0.7, GOLD)
            }
        case .bank:
            c.R(x + 1, top + 2.4, w - 2, 0.9, GOLD)
            for q in 0..<Int(w / 6) { c.circ(x + 4 + Double(q) * 6, top + 4.8, 0.7, GOLD) }
            for sx in [x - 5.6, x + w + 1] {
                let hx = sx + (sx < x ? 3.6 : 1)
                c.R(sx, GY - 2.4, 4.6, 2.4, STONE2); c.ell(sx + 2.3, GY - 4.4, 2.3, 1.7, Col(0xc9a45a)); c.circ(hx, GY - 6.4, 2, Col(0xa87a34)); c.circ(hx, GY - 6.4, 1.4, Col(0xc9a45a))
            }
        default:
            break
        }
    }
    /// Water and palms shimmering on the midday sand. A false one thins as you come close.
    func mirage(_ m: Mirage) {
        let day = clampD(min(g.t - 0.24, 0.57 - g.t) / 0.05, 0, 1)
        let near: Double = m.real ? 1 : clampD((abs(m.x - g.player.x) - 30) / 120, 0.25, 1)
        let a = day * (1 - m.gone) * near
        if a <= 0.01 { return }
        let x = m.x - cam
        if x > W + 60 || x < -60 { return }
        c.alpha(a * 0.9)
        for j in 0..<7 {
            let k = Double(j)
            c.RR(x - 34 + k * 2.5 + sin(NOW * 3 + k * 1.3) * 3, GY - 9 + k, 68 - k * 5, 1.05, 0.5, j % 2 == 1 ? Col(0x9fd8e8) : Col(0xc8ecf2))
        }
        for o in [-18.0, -4, 14] {
            let wob = sin(NOW * 2.4 + o) * 1.5
            c.seg(x + o, GY - 9, x + o + wob, GY - 22, 1, Col(0x4a6a4a))
            for i in 0..<5 {
                let an = -PI * Double(i) / 4
                c.curve(x + o + wob, GY - 22, x + o + wob + cos(an) * 3.4, GY - 23 + sin(an) * 2, x + o + wob + cos(an) * 6.4, GY - 20 + sin(an) * 3, 0.8, Col(0x4a7a4a))
            }
            c.seg(x + o, GY - 8, x + o - wob, GY - 2, 1, rgba(74, 106, 74, 0.5))
        }
        let tx = x + 30 + sin(NOW * 2)
        c.dome(tx, GY - 12, 5, Col(0xe8d8b8)); c.R(tx - 6, GY - 12, 12, 3, Col(0xe8d8b8))
        c.alpha(1)
    }
    /// Rain leaves the sand dark and puddled; on flood days the river lies over the pasture.
    func wetGround() {
        let wet: Double = g.rain != nil ? 1 : (g.lush ? 0.6 : 0)
        if wet > 0 {
            c.R(-4, GY, W + 8, H - GY + 4, rgba(90, 60, 30, 0.16 * wet))
            var i = Int(floor(cam / 60)) - 1
            let last = Int((cam + W) / 60) + 1
            while i <= last {
                let n = Double(i)
                let x = n * 60 + hashN(n + 960) * 40 - cam, y = GY + 4 + hashN(n + 961) * (H - GY - 12), rx = 8 + hashN(n + 962) * 10
                c.ell(x, y, rx, 1.7, rgba(120, 170, 200, 0.55 * wet)); c.ell(x - rx * 0.3, y - 0.3, rx * 0.4, 0.5, rgba(255, 255, 255, 0.35 * wet))
                if g.rain != nil {
                    let u = (NOW * 2 + hashN(n + 963)).truncatingRemainder(dividingBy: 1)
                    c.ellStroke(x + (hashN(n + floor(NOW * 2)) - 0.5) * rx, y, 1 + u * 3, 0.3 + u * 0.8, 0.25, rgba(255, 255, 255, 0.6 * (1 - u)))
                }
                i += 1
            }
        }
        if g.flooded {
            let x0 = g.PAST.0 - 60 - cam
            if x0 < W {
                let sheet = rgba(96, 170, 196, 0.42), clear = rgba(96, 170, 196, 0)
                c.linear(x0, GY + 0.6, 40, H - GY, x0, 0, x0 + 40, 0, [(0, clear), (1, sheet)])
                c.R(x0 + 40, GY + 0.6, max(0, W - x0), H - GY, sheet)
                for q in 0..<18 {
                    let n = Double(q)
                    let rx = (hashN(n + 970) * W + NOW * (6 + hashN(n + 971) * 6)).truncatingRemainder(dividingBy: W)
                    if rx > x0 + 30 { c.R(rx, GY + 2 + hashN(n + 972) * (H - GY - 6), 8 + hashN(n + 973) * 10, 0.4, rgba(255, 255, 255, 0.35)) }
                }
            }
        }
    }
    /// The last town's skyline: pylon gates, obelisks and a colonnade.
    func farTemple(_ fx: Double, _ s: Double, _ hz: Col) {
        let x = fx - cam * 0.07, y = GY - 16
        if x < -90 || x > W + 90 { return }
        let lc = Col.mix(Col(0xe2ba7a), hz, 0.5), dc = Col.mix(Col(0x9c7440), hz, 0.5)
        for sg in [-1.0, 1.0] {
            let px = x + sg * 13 * s
            c.poly(lc, [px - 11 * s, y, px - 8.5 * s, y - 30 * s, px + 8.5 * s, y - 30 * s, px + 11 * s, y])
            c.poly(dc, [px + 4 * s, y, px + 5 * s, y - 30 * s, px + 8.5 * s, y - 30 * s, px + 11 * s, y])
            c.R(px - 9.5 * s, y - 31.6 * s, 19 * s, 1.8 * s, lc)
            c.seg(px - 4 * s, y - 31 * s, px - 4 * s, y - 43 * s, 0.3, dc)
            c.poly(Col.mix(RED, hz, 0.4), [px - 4 * s, y - 43 * s, px + 1 * s + sin(NOW * 3 + px) * 0.5, y - 41.6 * s, px - 4 * s, y - 40 * s])
            for q in 0..<4 { c.R(px - 6 * s, y - (8 + Double(q) * 6) * s, 10 * s, 0.3, rgba(90, 60, 26, 0.2)) }
        }
        c.R(x - 3 * s, y - 16 * s, 6 * s, 16 * s, dc); c.R(x - 4.4 * s, y - 18 * s, 8.8 * s, 2 * s, lc)
        for ox in [x - 34 * s, x + 32 * s] {
            c.poly(lc, [ox - 1.6 * s, y, ox - 1 * s, y - 36 * s, ox + 1 * s, y - 36 * s, ox + 1.6 * s, y])
            c.poly(Col.mix(GOLD, hz, 0.4), [ox - 1 * s, y - 36 * s, ox, y - 39 * s, ox + 1 * s, y - 36 * s])
        }
        for q in 0..<7 { c.R(x + 42 * s + Double(q) * 5 * s, y - 14 * s, 2.2 * s, 14 * s, q % 2 == 0 ? lc : dc) }
        c.R(x + 40 * s, y - 16 * s, 36 * s, 2.4 * s, lc)
    }
    /// The port's far shore: a lighthouse, warehouses and a forest of masts.
    func farHarbour(_ fx: Double, _ hz: Col) {
        let x = fx - cam * 0.07, y = GY - 16
        if x < -130 || x > W + 80 { return }
        let lc = Col.mix(Col(0xe6d2a8), hz, 0.5), dc = Col.mix(Col(0x8a6a48), hz, 0.5)
        c.poly(lc, [x - 5, y, x - 3, y - 34, x + 3, y - 34, x + 5, y]); c.poly(dc, [x + 1.4, y, x + 1, y - 34, x + 3, y - 34, x + 5, y])
        c.R(x - 4, y - 36, 8, 2, dc); c.R(x - 2, y - 40, 4, 4, lc); c.poly(dc, [x - 3, y - 40, x, y - 44, x + 3, y - 40])
        if lit {
            let fl = 0.6 + 0.4 * sin(NOW * 5)
            c.glow(x, y - 38, 14, rgba(255, 200, 110, 0.7 * fl), rgba(255, 200, 110, 0)); light(x, y - 38, 16, 0.6)
        } else { c.R(x - 1, y - 39, 2, 2, Col(0xfff3b8)) }
        for q in 0..<5 {
            let n = Double(q)
            let bx = x + 14 + n * 15, h = 8 + hashN(n + 900) * 8
            c.R(bx, y - h, 12, h, q % 2 == 0 ? lc : dc); c.R(bx, y - h, 12, 1, Col.mix(Col(0xfff0c8), hz, 0.4))
        }
        for q in 0..<9 {
            let n = Double(q)
            let mx = x - 16 - n * 7 - hashN(n + 910) * 3, mh = 16 + hashN(n + 911) * 12
            c.seg(mx, y, mx, y - mh, 0.4, dc)
            c.poly(Col.mix(Col(0xf6efdc), hz, 0.4), [mx - 3.4, y - 6, mx + 2.4, y - mh, mx + 4, y - 5]); c.seg(mx - 3.4, y - 6, mx + 2.4, y - mh, 0.3, dc)
        }
    }
    /// The oasis country: palm groves along the far dunes and a strip of water catching the light.
    func farGrove(_ hz: Col) {
        let trunk = Col.mix(Col(0x6a4a2a), hz, 0.45), leaf = Col.mix(Col(0x3f7d3a), hz, 0.45)
        let lx = 300 - cam * 0.2
        c.ell(lx, GY - 17.5, 46, 1.4, Col.mix(Col(0x8fd0dc), hz, 0.4)); c.R(lx - 20 + sin(NOW) * 6, GY - 17.8, 12, 0.3, rgba(255, 255, 255, 0.5))
        for i in 0..<26 {
            let n = Double(i)
            let x = 60 + n * 34 + hashN(n + 920) * 26 - cam * 0.2
            if x < -10 || x > W + 10 || hashN(n + 921) < 0.3 { continue }
            let y = GY - 19 - hashN(n + 922) * 4, h = 9 + hashN(n + 923) * 6, lean = (hashN(n + 924) - 0.5) * 3
            c.seg(x, y, x + lean, y - h, 0.7, trunk)
            for q in 0..<5 {
                let a = -2.6 + Double(q) * 0.52 + sin(NOW * 0.8 + n) * 0.05
                c.curve(x + lean, y - h, x + lean + cos(a) * 3, y - h + sin(a) * 3 - 1.4, x + lean + cos(a) * 5.4, y - h + sin(a) * 2.2 + 1.2, 0.6, leaf)
            }
        }
    }
    /// An unbuilt plot: low footings and a timber frame the size of what will stand there,
    /// so it reads as a place to build and not as one more house in the background.
    func plot(_ b: Building, _ x: Double) {
        let w = b.w, h = b.def.h[1]
        ruin(x, w, 6, b.x)
        let post = Col(0x9a7040), dark = Col(0x5a3e22)
        c.R(x + 2, GY - h, w - 4, h, rgba(255, 240, 200, 0.08 + 0.03 * sin(NOW * 2 + b.x)))
        let n = max(2, Int(w / 26) + 1)
        for i in 0..<n {
            let px = x + 2 + Double(i) * (w - 5.6) / Double(n - 1)
            c.R(px, GY - h, 1.6, h, post); c.R(px + 1.1, GY - h, 0.5, h, dark)
        }
        c.R(x + 1, GY - h - 0.4, w - 2, 1.8, post); c.R(x + 1, GY - h + 1, w - 2, 0.4, dark)
        c.R(x + 2, GY - h * 0.52, w - 4, 1, post); c.R(x + 2, GY - h * 0.52 + 0.8, w - 4, 0.3, dark)
        let br = min(h * 0.4, 10)
        c.seg(x + 3.6, GY - h + br, x + 3.6 + br, GY - h + 0.8, 0.6, dark); c.seg(x + w - 3.6, GY - h + br, x + w - 3.6 - br, GY - h + 0.8, 0.6, dark)
        // the doorway to come, marked out in chalk
        let dx = x + w * 0.5
        for q in 0..<4 { c.R(dx - 4.4, GY - 3 - Double(q) * 3, 0.5, 2, rgba(255, 250, 230, 0.7)); c.R(dx + 3.9, GY - 3 - Double(q) * 3, 0.5, 2, rgba(255, 250, 230, 0.7)) }
        for q in 0..<3 { c.R(dx - 3.4 + Double(q) * 2.6, GY - 13.4, 1.6, 0.5, rgba(255, 250, 230, 0.7)) }
        // a line of builders' flags along the top beam
        var fx = x + 5.0
        var k = 0
        while fx < w + x - 5 {
            let sw = sin(NOW * 3 + fx) * 0.6
            c.poly(k % 2 == 0 ? RED : TEAL, [fx, GY - h + 1.4, fx + 3, GY - h + 1.4, fx + 1.5 + sw, GY - h + 4.6])
            fx += 6.5; k += 1
        }
    }
    /// The tour's bouncing arrow over whatever the next step is, or at the screen edge pointing the way.
    func tourArrow() {
        if g.tourStep == nil { return }
        let gl = g.goal()
        guard let wx = gl.1 else { return }
        let x = wx - cam, bob = sin(NOW * 5) * 2
        let ink = Col(0x1c130c)
        if x < 10 || x > W - 10 {
            let dir: Double = x < 10 ? -1 : 1
            let ex = (x < 10 ? 14 : W - 14) + dir * bob, ey = GY - 44.0
            c.poly(ink, [ex + dir * 7, ey, ex - dir * 4, ey - 8, ex - dir * 4, ey + 8])
            c.poly(GOLD, [ex + dir * 5, ey, ex - dir * 3, ey - 6, ex - dir * 3, ey + 6])
            return
        }
        let y = GY - gl.2 - 24 + bob
        c.R(x - 2.6, y - 14, 5.2, 7, ink); c.poly(ink, [x - 6.4, y - 8, x + 6.4, y - 8, x, y + 1.4])
        c.R(x - 1.6, y - 13, 3.2, 6, GOLD); c.poly(GOLD, [x - 4.6, y - 7.2, x + 4.6, y - 7.2, x, y - 0.4])
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
        // above 24 coins each slot stands for a share of the price, so the grid never climbs into the sky
        let shown = min(cost, 24)
        for i in 0..<shown {
            let s = g.slotPos(b, i, cost)
            let x = s.x - cam, y = GY - s.h
            let full = cost <= 24 ? i < b.paid : Double(b.paid) >= Double(i + 1) * Double(cost) / 24
            c.circ(x, y, 2.3, rgba(28, 19, 12, 0.75))
            c.circ(x, y, 1.7, full ? GOLD : rgba(242, 193, 78, 0.22))
            if full { c.circ(x - 0.5, y - 0.5, 0.45, Col(0xfff3b8)) }
        }
    }

    // ---------- a second pass of life and detail over the whole scene
    func plume(_ x: Double, _ y: Double, _ seed: Double, _ scale: Double = 1, _ col: Col = Col(0xf0ece4)) {
        for q in 0..<5 {
            let u = (NOW * 0.25 + Double(q) * 0.2 + seed * 0.37).truncatingRemainder(dividingBy: 1)
            c.alpha(0.34 * (1 - u))
            c.circ(x + sin(u * 5 + seed) * 2.5 * scale + u * 5 * scale, y - u * 16 * scale, (1.2 + u * 3) * scale, col)
        }
        c.alpha(1)
    }
    func glyphs(_ x: Double, _ y: Double, _ w: Double, _ rows: Int, _ seed: Double) {
        for r in 0..<rows {
            var gx = 0.0
            var k = 0.0
            while gx < w - 1 {
                let gw = 0.8 + hashN(seed + k + Double(r) * 31) * 1.6
                let gh = 1 + hashN(seed + k * 3 + Double(r) * 17) * 1.6
                c.R(x + gx, y + Double(r) * 3.4 + (2.6 - gh) / 2, gw, gh, rgba(80, 50, 16, 0.42))
                gx += gw + 1.1; k += 1
            }
        }
    }
    func puffs() {
        for i in 0..<4 {
            let n = Double(i)
            let span = W + 200
            var x = (hashN(n + 11) * span + NOW * (2.2 + n * 0.7) - cam * 0.04).truncatingRemainder(dividingBy: span)
            if x < 0 { x += span }
            x -= 100
            let y = 22 + hashN(n + 12) * GY * 0.3
            let a = 0.5 * (1 - g.dark * 0.75)
            let warm = g.warmth(g.t)
            let col = Col.mix(Col(0xffffff), Col(0xffb48a), warm * 0.7).alpha(a)
            let sz = 0.8 + hashN(n + 13) * 0.6
            c.ell(x, y, 26 * sz, 4.4 * sz, col); c.ell(x - 10 * sz, y - 3 * sz, 11 * sz, 5 * sz, col); c.ell(x + 6 * sz, y - 4.4 * sz, 13 * sz, 6 * sz, col); c.ell(x + 18 * sz, y - 2 * sz, 9 * sz, 4 * sz, col)
            c.ell(x + 2 * sz, y + 2.2 * sz, 22 * sz, 2 * sz, rgba(120, 130, 170, 0.16 * (1 - g.dark)))
        }
    }

    /// A whirl of dust: a stack of rings that leans and wobbles, with grit orbiting it.
    func devil(_ x: Double, _ base: Double, _ h: Double, _ a: Double, _ seed: Double) {
        let n = max(5, Int(h / 3.2))
        for q in 0..<n {
            let k = Double(q) / Double(n)
            let wob = sin(NOW * 6 + k * 7 + seed) * (1 + k * h * 0.09) + sin(NOW * 0.9 + seed) * k * h * 0.12
            c.ell(x + wob, base - 1 - k * h, 1.4 + k * h * 0.2, 0.9 + k * h * 0.03, rgba(226, 196, 140, a * (1 - k * 0.55)))
            if q % 2 == 0 { c.R(x + wob + cos(NOW * 9 + k * 11 + seed) * (2 + k * h * 0.22), base - 1 - k * h, 0.7, 0.5, rgba(150, 110, 60, min(1, a * 1.8))) }
        }
        c.ell(x, base + 0.4, 3 + h * 0.12, 0.9, rgba(226, 196, 140, a * 0.9))
        c.ellStroke(x, base + 0.4, 4 + h * 0.16 + sin(NOW * 5 + seed) * 1.2, 1.1, 0.35, rgba(255, 240, 206, a * 0.8))
    }

    /// The far country: tall dust devils walking the dunes and a caravan on the ridge.
    func farLife(_ hz: Col) {
        if g.dark < 0.45 && g.rain == nil && g.storm == nil {
            for i in 0..<2 {
                let n = Double(i)
                let span = W + 200
                var fx = (hashN(n + 300) * span + NOW * (i == 0 ? 3.4 : -2.6) - cam * 0.28).truncatingRemainder(dividingBy: span)
                if fx < 0 { fx += span }
                devil(fx - 100, GY - 7 - n * 5, 50 - n * 14, 0.2, n * 9)
            }
        }
        let span = W + 260
        var x0 = (NOW * 1.1 - cam * 0.12).truncatingRemainder(dividingBy: span)
        if x0 < 0 { x0 += span }
        x0 -= 130
        let col = Col.mix(Col(0x5a3e28), hz, 0.5)
        let y = GY - 19.5
        for i in 0..<5 {
            let cx = x0 + Double(i) * 9
            let st = sin(NOW * 2.4 + Double(i) * 1.3) * 0.9
            c.ell(cx, y, 2.6, 1.2, col); c.circ(cx - 0.2, y - 1.3, 1, col); c.seg(cx + 2.2, y, cx + 3.4, y - 2.4, 0.6, col)
            c.seg(cx - 1.6, y + 0.8, cx - 1.6 + st, y + 3.4, 0.45, col); c.seg(cx + 1.6, y + 0.8, cx + 1.6 - st, y + 3.4, 0.45, col)
            if i % 2 == 0 { c.R(cx - 0.6, y - 4.2, 1.2, 2.6, col) }
            if lit {
                // each camel carries a lantern after dark
                c.glow(cx + 1, y - 2.6, 7, rgba(255, 204, 116, 0.85), rgba(255, 204, 116, 0)); c.circ(cx + 1, y - 2.6, 0.7, Col(0xfff3b8))
                c.ell(cx, y + 3.4, 4, 0.7, rgba(255, 190, 90, 0.2))
                light(cx, y - 2, 10, 0.6)
            }
        }
    }

    /// Vultures on the thermals by day; bats at dusk; shooting stars and fireflies at night.
    func skyLife() {
        if g.dark < 0.35 {
            let cx = W * 0.24 - (cam * 0.02).truncatingRemainder(dividingBy: 40), cy = GY * 0.3
            for i in 0..<3 {
                let a = NOW * 0.32 + Double(i) * 2.1
                let vx = cx + cos(a) * (26 + Double(i) * 6), vy = cy + sin(a) * 7 - Double(i) * 5
                let span = 4.4 + sin(a) * 1.6
                c.seg(vx - span, vy - 1.2, vx, vy, 0.6, rgba(40, 28, 20, 0.7)); c.seg(vx, vy, vx + span, vy - 1.2, 0.6, rgba(40, 28, 20, 0.7)); c.R(vx - 0.4, vy - 0.3, 0.8, 0.8, rgba(40, 28, 20, 0.7))
            }
        }
        if g.dark > 0.25 && g.dark < 0.95 {
            for i in 0..<5 {
                let n = Double(i)
                let bx = g.WELL_X - cam + sin(NOW * 1.5 + n * 2.3) * 120 + cos(NOW * 3.7 + n) * 14
                let by = GY - 62 + sin(NOW * 2.7 + n * 1.7) * 16
                let flap = sin(NOW * 22 + n) * 1.8
                c.poly(rgba(20, 14, 24, 0.8), [bx - 3.4, by - flap, bx - 1.2, by + 0.6, bx, by - 0.6, bx + 1.2, by + 0.6, bx + 3.4, by - flap, bx, by + 1.2])
            }
        }
        if g.dark > 0.7 {
            let cyc = NOW * 0.12
            let ph = cyc - floor(cyc)
            if ph < 0.07 {
                let k = ph / 0.07
                let sx = hashN(floor(cyc) + 1) * W * 0.8 + k * 60, sy = 8 + hashN(floor(cyc) + 2) * GY * 0.3 + k * 16
                c.linear(sx - 26, sy - 9, 28, 12, sx - 24, sy - 6.4, sx, sy, [(0, rgba(255, 255, 255, 0)), (1, rgba(255, 250, 230, 0.9 * (1 - k)))])
                c.seg(sx - 22, sy - 5.9, sx, sy, 0.6, rgba(255, 250, 230, 0.8 * (1 - k)))
                c.R(sx - 0.6, sy - 0.6, 1.4, 1.4, rgba(255, 255, 255, 1 - k))
            }
        }
    }

    /// The small things you only see if you look: snakes, scorpions, beetles, lizards, bones, burrows, a fox at night.
    func critters() {
        if g.storm != nil { return }
        var i = Int(floor(cam / 90)) - 1
        let last = Int((cam + W) / 90) + 1
        while i <= last {
            let n = Double(i)
            i += 1
            let wx = n * 90 + hashN(n + 200) * 60
            if wx < 60 || wx > g.NILE - 50 || (wx > g.TOWN.0 - 40 && wx < g.TOWN.1 + 40) { continue }
            if abs(wx - g.QUARRY) < 70 || g.zoneOf(wx) != nil || (g.OASIS > 0 && abs(wx - g.OASIS) < 95) { continue }
            if g.camps.contains(where: { abs($0.x - wx) < 60 }) { continue }
            let x = wx - cam
            let y = GY + 5 + hashN(n + 202) * (H - GY - 20)
            let night = g.dark > 0.6
            switch Int(hashN(n + 201) * 11) {
            case 0:
                // a sidewinder, and the marks it leaves
                if night { break }
                let sx = x + sin(NOW * 0.25 + n) * 20
                for q in 0..<4 { c.seg(sx - 10 - Double(q) * 6, y + 1.6, sx - 6.5 - Double(q) * 6, y - 1.2, 0.4, rgba(120, 80, 30, 0.28)) }
                var px = sx - 8.0, py = y
                for q in 1..<10 {
                    let k = Double(q)
                    let nx = sx - 8 + k * 1.9, ny = y + sin(k * 1.1 + NOW * 5) * 1.5
                    c.seg(px, py, nx, ny, 1 - k * 0.04, q % 2 == 0 ? Col(0xb89a5a) : Col(0x8a6a3a))
                    px = nx; py = ny
                }
                c.ell(px + 0.8, py, 1.3, 0.9, Col(0x8a6a3a)); c.R(px + 1.2, py - 0.5, 0.4, 0.4, Col(0x1c1008))
                if sin(NOW * 4 + n) > 0.7 { c.seg(px + 2, py, px + 3.6, py + 0.3, 0.25, RED) }
            case 1:
                // a scorpion that scuttles a little and stops
                let step = floor(NOW * 0.6 + n)
                let sx = x + (hashN(step + n) - 0.5) * 16
                let dk = Col(0x3a2a14)
                c.ell(sx, y, 2, 1, dk); c.ell(sx - 2.2, y, 1, 0.7, dk)
                c.curve(sx - 3, y, sx - 5.4, y - 1, sx - 4.4, y - 3.4 + sin(NOW * 3 + n) * 0.4, 0.6, dk); c.R(sx - 4.2, y - 4.2 + sin(NOW * 3 + n) * 0.4, 0.8, 0.8, Col(0x7a4a1a))
                c.seg(sx + 1.6, y - 0.4, sx + 3.4, y - 1.4, 0.45, dk); c.seg(sx + 1.6, y + 0.4, sx + 3.4, y + 1.2, 0.45, dk)
                for q in 0..<3 { c.seg(sx - 0.8 + Double(q), y + 0.6, sx - 1.2 + Double(q), y + 1.8, 0.25, dk) }
            case 2:
                // a scarab rolling its ball
                if night { break }
                let u = (NOW * 2.4 + n * 30).truncatingRemainder(dividingBy: 50)
                let bx = x - 25 + u
                c.circ(bx, y - 1.4, 1.6, Col(0x6a4a2a)); c.R(bx + cos(u * 1.3) * 1, y - 1.6 + sin(u * 1.3) * 1, 0.5, 0.5, Col(0x8a6a44))
                c.ell(bx - 2.6, y - 0.8, 1.4, 1, Col(0x1c2a3a)); c.R(bx - 3, y - 1.6, 0.6, 0.4, Col(0x4a8ab8))
                for q in 0..<3 { c.R(bx - 6 - Double(q) * 3, y, 1.2, 0.3, rgba(120, 80, 30, 0.25)) }
            case 3:
                // a lizard on a warm rock
                c.ell(x, y + 0.4, 5.4, 1, rgba(60, 34, 8, 0.25)); c.poly(Col(0xa8875a), [x - 5, y, x - 3, y - 3.4, x + 2, y - 4, x + 5, y]); c.poly(Col(0xc8a878), [x - 3, y - 3.4, x + 2, y - 4, x + 1, y - 2.6, x - 2.4, y - 2.2])
                if !night {
                    let cyc = NOW * 0.09 + n
                    let u = cyc - floor(cyc)
                    let lx = x - 1 + (u < 0.85 ? 0 : (u - 0.85) / 0.15 * 22), ly = u < 0.85 ? y - 4 : y - 0.6
                    c.R(lx - 2, ly - 0.6, 4, 1, Col(0x7a8a4a)); c.R(lx + 1.8, ly - 0.9, 1.4, 1.1, Col(0x7a8a4a)); c.seg(lx - 2, ly, lx - 4.6, ly + 0.5, 0.4, Col(0x7a8a4a)); c.R(lx + 2.6, ly - 0.7, 0.3, 0.3, Col(0x1c1008))
                }
            case 4:
                // old bones
                c.ell(x, y, 2.6, 2, Col(0xece6d6)); c.R(x - 1.4, y - 0.4, 0.9, 0.9, Col(0x4a4034)); c.R(x + 0.5, y - 0.4, 0.9, 0.9, Col(0x4a4034)); c.R(x - 1.2, y + 1.4, 2.4, 0.8, Col(0xd8d0bc))
                c.seg(x - 4.4, y - 0.6, x - 6.4, y - 4, 0.5, Col(0xece6d6))
                for q in 0..<4 { c.arcStroke(x + 6 + Double(q) * 2.2, y + 1.6, 2.4, PI * 1.05, PI * 1.9, 0.45, Col(0xe0d8c4)) }
            case 5:
                // shards and stones
                for q in 0..<4 {
                    let k = Double(q)
                    let sx = x - 6 + hashN(n + k * 3) * 12, sy = y - 1 + hashN(n + k * 5) * 3
                    c.ell(sx + 0.6, sy + 0.8, 1.8, 0.5, rgba(60, 34, 8, 0.22))
                    if q % 2 == 0 { c.poly(Col(0xb5673a), [sx - 1.4, sy + 0.6, sx, sy - 1.4, sx + 1.6, sy + 0.4]); c.R(sx - 0.4, sy - 0.2, 0.8, 0.3, LAPIS) } else { c.ell(sx, sy, 1.6, 1, Col(0x9a8262)); c.R(sx - 0.8, sy - 0.8, 1, 0.3, Col(0xc8b088)) }
                }
            case 6:
                // a jerboa: a burrow by day, and out hopping at night
                c.ell(x, y, 2.4, 0.9, Col(0x3a2814)); c.ell(x, y - 0.6, 3.6, 0.7, Col(0xd4ad6c))
                if night {
                    let u = (NOW * 0.9 + n).truncatingRemainder(dividingBy: 2)
                    let jx = x + 6 + (u < 1 ? u : 2 - u) * 22, hop = abs(sin(NOW * 9 + n)) * 2.6
                    c.ell(jx, y - 1.6 - hop, 1.5, 1.2, Col(0xc8a070)); c.circ(jx + 1.3, y - 2.6 - hop, 0.8, Col(0xc8a070)); c.R(jx + 1.2, y - 4.2 - hop, 0.4, 1.4, Col(0xc8a070))
                    c.curve(jx - 1.4, y - 1.4 - hop, jx - 4, y - 0.6 - hop, jx - 5, y - 2.4 - hop, 0.3, Col(0xc8a070)); c.seg(jx - 0.2, y - 0.6 - hop, jx + 0.6, y + 0.4, 0.3, Col(0xc8a070))
                }
            case 7:
                // a fennec that watches you at night; by day, just its tracks
                if night {
                    c.poly(Col(0xc89c64), [x - 2.4, y, x - 1.6, y - 4.4, x + 1.6, y - 4.4, x + 2.4, y]); c.ell(x, y - 5, 1.9, 1.5, Col(0xd8b07a))
                    let tw = sin(NOW * 0.9 + n) > 0.8 ? 0.6 : 0.0
                    c.poly(Col(0xd8b07a), [x - 1.8, y - 5.6, x - 2.6 - tw, y - 9, x - 0.4, y - 6.2]); c.poly(Col(0xd8b07a), [x + 1.8, y - 5.6, x + 2.6 + tw, y - 9, x + 0.4, y - 6.2])
                    if sin(NOW * 0.7 + n) < 0.95 { c.R(x - 1.1, y - 5.4, 0.6, 0.6, Col(0xd8ffb0)); c.R(x + 0.5, y - 5.4, 0.6, 0.6, Col(0xd8ffb0)) }
                    c.curve(x + 2, y - 0.6, x + 5, y - 0.4, x + 5.4, y - 2.6, 1.1, Col(0xc89c64))
                } else {
                    for q in 0..<6 { c.R(x - 10 + Double(q) * 4, y + (q % 2 == 0 ? 0 : 0.9), 0.9, 0.6, rgba(120, 80, 30, 0.3)) }
                }
            case 8:
                // dry brush that rolls when the wind takes it
                let u = (NOW * 9 + n * 50).truncatingRemainder(dividingBy: 120)
                let bx = x - 60 + u, hop = abs(sin(u * 0.35)) * 2.4
                c.ell(bx, y + 0.6, 2.6, 0.6, rgba(60, 34, 8, 0.2))
                for q in 0..<6 { let a = u * 0.5 + Double(q) * PI / 3; c.seg(bx, y - 2.4 - hop, bx + cos(a) * 2.6, y - 2.4 - hop + sin(a) * 2.6, 0.35, Col(0x9a8448)) }
                c.ellStroke(bx, y - 2.4 - hop, 2.4, 2.4, 0.3, Col(0x8a7438))
            case 9:
                // a small whirl of dust that comes and goes
                let cyc = NOW * 0.07 + hashN(n + 7)
                let u = cyc - floor(cyc)
                if u < 0.3 && !night && g.rain == nil { devil(x + (u / 0.3 - 0.5) * 34, y, 10 + sin(PI * u / 0.3) * 5, 0.36 * sin(PI * u / 0.3), n) }
            default:
                // a tortoise going about its day, slowly
                if night { break }
                let u = (NOW * 0.5 + n * 9).truncatingRemainder(dividingBy: 60)
                let tx = x - 30 + u
                c.dome(tx, y, 2.8, Col(0x6a6a3a)); c.dome(tx, y, 1.8, Col(0x8a8a4a)); c.R(tx - 2.8, y - 0.2, 5.6, 0.6, Col(0x4a4a2a))
                c.R(tx + 2.6, y - 1.4, 1.4, 1, Col(0x9a9a5a)); c.R(tx - 2 + sin(NOW * 3) * 0.3, y + 0.3, 0.9, 0.8, Col(0x9a9a5a)); c.R(tx + 1.2 - sin(NOW * 3) * 0.3, y + 0.3, 0.9, 0.8, Col(0x9a9a5a))
            }
        }
        // fireflies over the water at night
        if g.dark > 0.6 {
            var spots: [Double] = [g.NILE - 12]
            if g.OASIS > 0 { spots.append(g.OASIS) }
            for sp in spots {
                let x = sp - cam
                if x < -60 || x > W + 60 { continue }
                for q in 0..<7 {
                    let n = Double(q)
                    let fx = x + sin(NOW * 0.6 + n * 1.9) * 34 + sin(NOW * 2.3 + n) * 4, fy = GY - 6 + cos(NOW * 0.8 + n * 2.7) * 9
                    let on = sin(NOW * 2.2 + n * 3.1) > 0
                    if on { c.R(fx - 0.5, fy - 0.5, 1, 1, Col(0xe8ff9a)); if q < 3 { light(fx, fy, 6, 0.5) } }
                }
            }
        }
    }

    /// The streets behind the main street: ruins at first, and they come back as the town does.
    func backTown(_ hz: Col) {
        let core: [BType] = [.market, .tea, .guard, .pen, .bank, .temple]
        let built = core.filter { g.B($0).level > 0 }.count
        if g.feat == .cliff { canyonBack(hz, built); return }
        if g.feat == .temple { holyBack(hz, built); return }
        if g.feat == .port { harbourBack(hz) }
        defer { if g.feat == .oasis { gardenBack(hz) } }
        let grown = Double(min(14, g.bs.prefix(9).reduce(0) { $0 + $1.level }))
        var i = 0
        var wx = g.TOWN.0 + 22
        while wx < g.TOWN.1 - 34 {
            let n = Double(i)
            let w = 20 + hashN(n + 2) * 16
            let h = 20 + hashN(n + 3) * 14 + grown * 0.7
            let x = wx - cam
            if x < W + 12 && x + w > -30 {
                let alive = i % 6 < built
                let wall = Col.mix(i % 2 == 0 ? MUD : PLA2, hz, 0.4), shade = Col.mix(MUDD, hz, 0.4)
                if alive {
                    c.R(x, GY - h, w, h, wall); c.R(x + w - 3.5, GY - h, 3.5, h, shade); c.R(x, GY - h, w, 1, Col.mix(Col(0xfff0c8), hz, 0.3))
                    var q = 0.0
                    while q < w - 2 { c.R(x + q, GY - h - 2, 2.6, 2, wall); q += 4.6 }
                    var cy = 5.0
                    while cy < h { c.R(x, GY - h + cy, w - 3.5, 0.3, rgba(70, 40, 10, 0.12)); cy += 5 }
                    var bq = 2.0
                    while bq < w - 5 { c.R(x + bq, GY - h + 2.6, 0.9, 0.9, shade); bq += 3.6 }
                    c.vfill(x, GY - 8, w, 8, [(0, rgba(70, 40, 10, 0)), (1, rgba(70, 40, 10, 0.22))])
                    c.vfill(x, GY - h + 1, w - 3.5, 4, [(0, rgba(70, 40, 10, 0.16)), (1, rgba(70, 40, 10, 0))])
                    if i % 3 == 2 {
                        let lx = x + w - 7
                        c.seg(lx, GY, lx + 1.5, GY - h - 2, 0.35, shade); c.seg(lx + 2.4, GY, lx + 3.9, GY - h - 2, 0.35, shade)
                        var ly = 3.0
                        while ly < h { c.R(lx + ly / h * 1.5, GY - ly, 2.6, 0.3, shade); ly += 3.2 }
                    }
                    if i % 4 == 1 || g.feat == .oasis { c.dome(x + w * 0.5, GY - h, w * 0.28, Col.mix(PLA, hz, 0.35)); c.R(x + w * 0.5 - 0.4, GY - h - w * 0.28 - 3, 0.8, 3, Col.mix(GOLD, hz, 0.3)) }
                    // windows that come on at dusk, each on its own schedule
                    for k in 0..<2 {
                        let kx = x + 4 + Double(k) * (w - 13), ky = GY - h + 6 + hashN(n * 5 + Double(k)) * 5
                        let on = lit && hashN(n * 7 + Double(k) + floor(NOW * 0.12)) > 0.3
                        c.R(kx - 0.5, ky - 0.5, 4, 6, shade)
                        c.R(kx - 1.7, ky, 1, 5, Col.mix(TEAL, hz, 0.45)); c.R(kx + 3.7, ky, 1, 5, Col.mix(TEAL, hz, 0.45)); c.R(kx - 1.2, ky + 5.2, 5.4, 0.7, shade)
                        c.R(kx, ky, 3, 5, on ? Col.mix(Col(0xffd27a), Col(0xffa53a), 0.5 + 0.5 * sin(NOW * 7 + n + Double(k))) : Col.mix(DARKC, hz, 0.25))
                        if on { light(kx + 1.5, ky + 2.5, 9, 0.5) }
                    }
                    c.arch(x + w * 0.5 - 2.5, GY - 9, 5, 9, Col.mix(Col(0x5a3a22), hz, 0.3))
                    let curt: [Col] = [RED, TEAL, LAPIS, Col(0xe0a030)]
                    c.poly(Col.mix(curt[i % 4], hz, 0.3), [x + w * 0.5 - 2.5, GY - 7, x + w * 0.5 + 2.5, GY - 7, x + w * 0.5 + 2.5 + sin(NOW * 2 + n) * 0.8, GY - 1, x + w * 0.5 - 2.5 + sin(NOW * 2 + n) * 0.8, GY - 1])
                    if i % 3 == 1 {
                        // a striped awning over the door
                        let mx = x + w * 0.5
                        c.poly(Col.mix(curt[(i + 1) % 4], hz, 0.3), [mx - 6, GY - 13, mx + 6, GY - 13, mx + 7.4, GY - 9.6, mx - 7.4, GY - 9.6])
                        for k in 0..<3 { c.R(mx - 4.4 + Double(k) * 3.6, GY - 13, 1.6, 3.4, Col.mix(Col(0xf6efdc), hz, 0.3)) }
                        c.R(mx - 7.4, GY - 9.8, 14.8, 0.5, shade)
                    } else if i % 3 == 2 && h > 26 {
                        // a wooden balcony under the upper window
                        c.R(x + 2, GY - h + 13, 9, 0.8, Col.mix(WOOD, hz, 0.35)); c.R(x + 2, GY - h + 10.4, 9, 0.5, Col.mix(WOOD, hz, 0.35))
                        for k in 0..<5 { c.R(x + 2.4 + Double(k) * 2, GY - h + 10.4, 0.5, 2.8, Col.mix(WOOD, hz, 0.35)) }
                    }
                    if i % 3 == 0 && g.dark < 0.9 { c.R(x + w * 0.28, GY - h - 5, 2.4, 4, shade); plume(x + w * 0.28 + 1.2, GY - h - 5, n) }
                    if i % 5 == 2 && g.dark < 0.4 {
                        let px = x + w * 0.5 + sin(NOW * 0.4 + n) * w * 0.3
                        c.R(px - 1, GY - h - 7.5, 2, 5.5, Col.mix(ROBE[i % 5], hz, 0.3)); c.R(px - 0.9, GY - h - 9.6, 1.8, 2.1, Col.mix(TURB[i % 5], hz, 0.3))
                    }
                    if i % 2 == 1 {
                        // a washing line to the next roof
                        let x1 = x + w, y1 = GY - h + 4, x2 = x + w + 14, y2 = GY - h + 6
                        c.curve(x1, y1, (x1 + x2) / 2, y1 + 4, x2, y2, 0.3, Col.mix(Col(0x5a3e22), hz, 0.3))
                        for k in 0..<3 {
                            let u = 0.22 + Double(k) * 0.28
                            let lx = lerp(x1, x2, u), ly = lerp(y1, y2, u) + 4 * sin(PI * u) * 0.9
                            let sw = sin(NOW * 2.6 + n + Double(k)) * 0.9
                            c.poly(Col.mix(curt[(i + k) % 4], hz, 0.25), [lx - 1.6, ly, lx + 1.6, ly, lx + 1.6 + sw, ly + 4.4, lx - 1.6 + sw, ly + 4.4])
                        }
                    }
                } else {
                    var q = 0.0
                    while q < w {
                        let hh = h * (0.2 + 0.5 * hashN(n * 9 + q))
                        c.R(x + q, GY - hh, 5.05, hh, Int(q / 5) % 2 == 0 ? shade : Col.mix(MUD2, hz, 0.4))
                        c.R(x + q, GY - hh, 5.05, 0.7, Col.mix(Col(0xd9b680), hz, 0.4))
                        q += 5
                    }
                }
            }
            wx += w + 6 + hashN(n + 9) * 12
            i += 1
        }
    }

    /// Cloud shadows sliding over the sand, grains on the wind, and the shimmer over hot ground.
    func groundAir() {
        let day = 1 - g.dark
        if day > 0.1 && g.rain == nil {
            for i in 0..<3 {
                let n = Double(i)
                let span = W + 360
                var sx = (hashN(n + 610) * span + NOW * (4 + n * 1.5) - cam * 0.9).truncatingRemainder(dividingBy: span)
                if sx < 0 { sx += span }
                sx -= 180
                c.ell(sx, GY + 10 + n * 6, 80 + n * 22, 7 + n * 2, rgba(50, 30, 60, 0.07 * day))
                c.ell(sx + 30, GY + 13 + n * 6, 50 + n * 14, 5 + n, rgba(50, 30, 60, 0.05 * day))
            }
        }
        for i in 0..<9 {
            let n = Double(i)
            let span = W + 80
            var sx = (hashN(n + 620) * span + NOW * (26 + hashN(n + 621) * 30) - cam).truncatingRemainder(dividingBy: span)
            if sx < 0 { sx += span }
            sx -= 40
            let y = GY + 2 + hashN(n + 622) * (H - GY - 8)
            c.R(sx, y + sin(NOW * 3 + n) * 0.6, 9 + hashN(n + 623) * 14, 0.4, rgba(255, 244, 214, 0.1 + 0.1 * hashN(n + 624)))
        }
        let heat = max(0, 1 - abs(g.t - 0.33) / 0.2) * day
        if heat > 0.05 && g.rain == nil {
            for i in 0..<14 {
                let n = Double(i)
                let sx = hashN(n + 630) * W + sin(NOW * 1.7 + n * 2.1) * 5
                c.R(sx, GY - 1 - hashN(n + 631) * 4 + sin(NOW * 2.3 + n) * 0.5, 10 + hashN(n + 632) * 16, 0.4, rgba(255, 255, 255, 0.13 * heat))
            }
        }
    }

    /// Long soft ripples the wind has drawn across the open sand.
    func groundRipples() {
        if g.low { return }
        var ri = Int(floor(cam / 46)) - 1
        let rl = Int((cam + W) / 46) + 1
        while ri <= rl {
            let n = Double(ri)
            let wx = n * 46 + hashN(n + 980) * 30
            let x = wx - cam, y = GY + 5 + hashN(n + 981) * (H - GY - 12), len = 18 + hashN(n + 982) * 26
            if wx < g.TOWN.0 - 20 || wx > g.TOWN.1 + 20 {
                c.curve(x, y, x + len * 0.5, y - 1.6 - hashN(n + 983) * 1.4, x + len, y, 0.4, rgba(150, 110, 60, 0.22))
                c.curve(x + 2, y + 1.1, x + len * 0.5, y - 0.4, x + len - 2, y + 1.1, 0.3, rgba(255, 244, 214, 0.3))
            }
            ri += 1
        }
    }

    func groundExtra() {
        var i = Int(floor(cam / 23))
        let last = Int((cam + W) / 23) + 2
        while i < last {
            let n = Double(i)
            let wx = n * 23 + hashN(n + 40) * 15
            let x = wx - cam
            let inTown = wx > g.TOWN.0 + 8 && wx < g.TOWN.1 - 8
            if inTown {
                // worn paving along the street
                let y = GY + 1.5 + hashN(n + 41) * 5
                c.R(x, y, 5 + hashN(n + 42) * 4, 1.6, rgba(150, 118, 76, 0.4)); c.R(x, y, 5 + hashN(n + 42) * 4, 0.4, rgba(255, 236, 196, 0.35))
            } else if hashN(n + 43) < 0.4 && wx < g.NILE - 20 {
                let y = GY + 1 + hashN(n + 44) * (H - GY - 12)
                for k in 0..<4 {
                    let a = -1.9 + Double(k) * 0.42 + sin(NOW * 1.7 + n) * 0.12
                    c.seg(x, y, x + cos(a) * 4.5, y + sin(a) * 4.5, 0.45, Col(0xa89048))
                }
            }
            i += 1
        }
    }

    /// The Nile: water all the way to the far bank, moving light, boats, reeds, a wading bird, a fish now and then.
    func nileExtra(_ hz: Col) {
        let x = g.NILE - cam
        if x > W + 10 { return }
        let wd = W - x + 12
        c.vfill(x + 2, GY - 9, wd, 9.5, [(0, Col.mix(Col(0xb4dce6), hz, 0.35)), (1, Col(0x6fb6c8))])
        c.R(x + 2, GY - 10.6, wd, 1.8, Col.mix(Col(0x6a9a4a), hz, 0.45))
        for i in 0..<7 {
            let n = Double(i)
            let px = x + 16 + n * 37 + hashN(n + 80) * 14
            if px > W + 8 { continue }
            let col = Col.mix(Col(0x2c5c2e), hz, 0.5)
            c.seg(px, GY - 10, px + 0.6, GY - 16, 0.6, col)
            for k in 0..<4 { let a = -PI * (0.1 + Double(k) * 0.27); c.seg(px + 0.6, GY - 16, px + 0.6 + cos(a) * 3.6, GY - 16 + sin(a) * 2 + 1.4, 0.55, col) }
        }
        // bands of light sliding downstream
        for i in 0..<16 {
            let n = Double(i)
            let yy = GY + 1.5 + hashN(n + 90) * (H - GY - 3)
            let u = (NOW * (5 + hashN(n) * 9) + hashN(n + 91) * 300).truncatingRemainder(dividingBy: 520)
            c.R(x + u - 20, yy, 9 + hashN(n + 92) * 18, 0.6, rgba(255, 255, 255, 0.16 + 0.2 * hashN(n + 93)))
        }
        // the sun (or moon) laid on the water
        let t = g.t
        let lx = t < 0.7 ? W * (0.06 + 0.88 * clampD(t / 0.66, 0, 1.06)) : W * (0.1 + 0.8 * (t - 0.64) / 0.36)
        if lx > x + 6 {
            for q in 0..<12 {
                let n = Double(q)
                if sin(NOW * 8 + n * 2.3) < 0.1 { continue }
                let yy = GY - 7 + n * (H - GY + 6) / 12
                let sp = 2 + n * 0.9
                c.R(lx - sp + hashN(n + floor(NOW * 5)) * sp * 2, yy, 1.6 + n * 0.3, 0.6, g.dark > 0.5 ? rgba(220, 230, 255, 0.55) : rgba(255, 246, 200, 0.75))
            }
        }
        // feluccas working the far water
        for i in 0..<2 {
            let n = Double(i)
            let span = 560.0
            let bx = x + (NOW * (3 + n * 1.5) + n * 140).truncatingRemainder(dividingBy: span) - 40
            if bx < x + 6 { continue }
            let by = GY - 3.2 - n * 2.4 + sin(NOW * 1.4 + n) * 0.3
            let sc = 1 - n * 0.25
            c.alpha(clampD((bx - x - 6) / 16, 0, 1))
            c.poly(Col(0x5e3a1e), [bx - 6.5 * sc, by - 2, bx - 5 * sc, by - 1.2, bx + 6 * sc, by - 1.2, bx + 8 * sc, by - 2.4, bx + 5 * sc, by + 0.8, bx - 4 * sc, by + 0.8])
            c.seg(bx - sc, by - 1.2, bx - sc, by - 7 * sc, 0.4, Col(0x5a3e22))
            c.poly(Col(0xf6efdc), [bx - 4.5 * sc, by - 3.4, bx + 3 * sc, by - 10 * sc, bx + 5.4 * sc, by - 2.6])
            c.seg(bx - 4.5 * sc, by - 3.4, bx + 3 * sc, by - 10 * sc, 0.4, Col(0x5a3e22))
            c.poly(rgba(246, 239, 220, 0.22), [bx - 4 * sc, by + 1.4, bx + 3 * sc, by + 5 * sc, bx + 5 * sc, by + 1.4])
            c.R(bx - 5 * sc, by + 1.2, 11 * sc, 0.4, rgba(255, 255, 255, 0.4))
            if lit {
                // a lantern at the stern, and its light lying on the water
                c.glow(bx - 5.4 * sc, by - 3.4, 6, rgba(255, 204, 116, 0.85), rgba(255, 204, 116, 0)); c.circ(bx - 5.4 * sc, by - 3.4, 0.6, Col(0xfff3b8))
                for q in 0..<3 { c.R(bx - 6.4 * sc + sin(NOW * 2 + Double(q) + bx) * 0.6, by + 2 + Double(q) * 1.3, 2.4, 0.4, rgba(255, 204, 116, 0.4 - Double(q) * 0.1)) }
                light(bx - 5 * sc, by - 2, 10, 0.55)
            }
            c.alpha(1)
        }
        // foam along the bank, reeds, and an ibis working the shallows
        var fy = GY + 1.0
        while fy < H { c.R(x - 0.5 + sin(NOW * 2 + fy * 0.6) * 1.3, fy, 2.6, 0.5, rgba(255, 255, 255, 0.55)); fy += 2.4 }
        for i in 0..<10 {
            let n = Double(i)
            let rx = x - 5 + hashN(n + 95) * 9, ry = GY + 2 + n * (H - GY - 4) / 10
            let sw = sin(NOW * 1.8 + n) * 1.2
            c.seg(rx, ry, rx + sw, ry - 8 - hashN(n + 96) * 5, 0.6, Col(0x4d8a3c))
            if i % 2 == 0 { c.R(rx + sw - 0.6, ry - 10 - hashN(n + 96) * 5, 1.2, 3, Col(0x6a4a2a)) }
        }
        let ix = x + 13, iy = GY + 7
        let peck = max(0, sin(NOW * 0.9)) > 0.8 ? 3.0 : 0.0
        c.seg(ix - 1, iy, ix - 1, iy + 5, 0.4, Col(0x2a2a2a)); c.seg(ix + 1.4, iy, ix + 1.4, iy + 5, 0.4, Col(0x2a2a2a))
        c.ell(ix, iy - 1.4, 3.4, 2, Col(0xf8f6ee)); c.R(ix - 3.6, iy - 1.8, 1.6, 1.4, Col(0x2a2a2a))
        c.curve(ix + 2.4, iy - 2, ix + 4.4, iy - 5 + peck, ix + 4.6, iy - 6 + peck * 1.6, 0.9, Col(0xf8f6ee))
        c.curve(ix + 4.6, iy - 6 + peck * 1.6, ix + 6.6, iy - 5.6 + peck * 1.8, ix + 7.6, iy - 3.6 + peck * 2, 0.5, Col(0x2a2a2a))
        // a fish, every so often
        let cycle = NOW * 0.16
        let ph = cycle - floor(cycle)
        if ph < 0.1 && wd > 70 {
            let k = ph / 0.1
            let jx = x + 46 + hashN(floor(cycle)) * 110, base = GY + 9 + hashN(floor(cycle) + 5) * 10
            c.save()
            c.translate(jx + (k - 0.5) * 12, base - sin(PI * k) * 9); c.rotate((k - 0.5) * 2.2)
            c.ell(0, 0, 2.8, 1.1, Col(0xc8d8e0)); c.poly(Col(0x9fb8c8), [-2.4, 0, -4.4, -1.4, -4.4, 1.4])
            c.restore()
            c.ellStroke(jx - 6, base, 2 + k * 5, 0.8, 0.4, rgba(255, 255, 255, 0.7 * (1 - k)))
            if k > 0.7 { c.ellStroke(jx + 6, base, (k - 0.7) * 18, 0.9, 0.4, rgba(255, 255, 255, 0.8)) }
        }
    }

    /// Lilies, ducks, dragonflies and a moored skiff on the creek.
    func creekExtra(_ x: Double) {
        c.poly(Col(0x6a4426), [x - 2, GY - 12.4, x + 5, GY - 12.4, x + 4, GY - 11, x - 1, GY - 11])
        c.seg(x + 1.4, GY - 12.4, x + 1.4, GY - 17, 0.35, Col(0x5a3e22)); c.poly(Col(0xf6efdc), [x + 1.6, GY - 17, x + 4.4, GY - 13.4, x + 1.6, GY - 13])
        for i in 0..<6 {
            let n = Double(i)
            let k = 0.15 + hashN(n + 110) * 0.8
            let yy = GY + 5 + k * (H - GY - 8)
            let hw = 36 + k * 22
            let lx = x - hw * 0.8 + hashN(n + 111) * hw * 1.6 + sin(NOW * 0.5 + n) * 1.2
            c.ell(lx, yy, 2.6 + k, 1 + k * 0.3, Col(0x4d8a3c)); c.poly(Col(0x3a7896), [lx, yy, lx + 2.6 + k, yy - 0.5, lx + 2.6 + k, yy + 0.5])
            if i % 2 == 0 { c.circ(lx - 0.6, yy - 0.5, 0.9, Col(0xf8e6f0)) }
        }
        for i in 0..<2 {
            let n = Double(i)
            let yy = GY + 16 + n * 7
            let span = 76 + n * 16
            let u = (NOW * (3 + n) + n * 40).truncatingRemainder(dividingBy: span * 2)
            let dir: Double = u < span ? 1 : -1
            let dx = x - span / 2 + (u < span ? u : span * 2 - u)
            c.ell(dx, yy, 2.6, 1.4, Col(0x8a6a44)); c.circ(dx + dir * 2.4, yy - 1.4, 1.1, Col(0x2c5c2e)); c.R(dx + dir * 3.2 - 0.4, yy - 1.5, 1, 0.5, Col(0xe0a030))
            c.ellStroke(dx - dir * 2.5, yy + 0.6, 3.5, 0.7, 0.3, rgba(255, 255, 255, 0.5))
        }
        if g.dark < 0.4 {
            for i in 0..<3 {
                let n = Double(i)
                let fx = x + sin(NOW * 1.3 + n * 2.1) * 30 + sin(NOW * 5.1 + n) * 4, fy = GY - 4 + cos(NOW * 1.7 + n * 1.3) * 5
                c.R(fx - 1.6, fy, 3.2, 0.4, Col(0x2a6a8a)); c.R(fx - 0.9, fy - 0.9, 1.8, 0.4, rgba(255, 255, 255, 0.7))
            }
        }
    }

    /// What a living building has around it: washing, pots, steam, braziers, carved bands.
    func dress(_ b: Building, _ x: Double, _ L: Int) {
        let w = b.w
        switch b.type {
        case .market:
            let rug: [Col] = [Col(0x8f2a1c), LAPIS, Col(0x7a4a8a)]
            for k in 0..<2 {
                let rx = x + 22 + Double(k) * 25
                let sw = sin(NOW * 1.8 + Double(k) * 2) * 0.7
                c.poly(rug[k], [rx, GY - 22, rx + 5, GY - 22, rx + 5 + sw, GY - 11, rx + sw, GY - 11])
                for q in 0..<3 { c.R(rx + sw * Double(q) / 3, GY - 20 + Double(q) * 3, 5, 0.8, GOLD) }
            }
            c.ell(x + 2, GY - 2.4, 2.2, 2.6, Col(0xb5673a)); c.R(x + 0.8, GY - 5.6, 2.4, 1, Col(0x8f4e2a)); c.ell(x + w - 3, GY - 1.8, 1.8, 2, Col(0xc98a4a))
            c.R(x + w - 12, GY - 3, 6, 3, Col(0x4a3a2a)); if g.dark < 0.95 { plume(x + w - 9, GY - 3, b.x, 0.8, Col(0xe8e2d8)) }
            for q in 0..<4 { c.circ(x + 34 + Double(q) * 2.4, GY - 8 + Double(q % 2), 1.1, q % 2 == 0 ? Col(0xd9822a) : Col(0xc7402a)) }
        case .tea:
            plume(x + 52, GY - 5, b.x + 1, 0.5)
            c.R(x + 51, GY - 6.4, 2.4, 2.2, Col(0xc9a45a)); c.seg(x + 53.4, GY - 5.8, x + 54.6, GY - 6.6, 0.5, Col(0xc9a45a))
            let sw = sin(NOW * 1.5 + b.x) * 1.2
            c.seg(x + 33, GY - 21, x + 33 + sw, GY - 17.4, 0.3, Col(0x5a3e22)); c.R(x + 32 + sw, GY - 17.4, 2, 2.6, lit ? Col(0xffd27a) : Col(0xe0a030))
            if lit { light(x + 33 + sw, GY - 16, 13, 0.6) }
            c.R(x + 3, GY - 3, 5, 3, Col(0x4d8a3c)); c.R(x + 2.4, GY - 1.2, 6.2, 1.2, Col(0xb5673a)); c.circ(x + 5.4, GY - 4, 1, RED)
        case .guard:
            c.seg(x + 24, GY, x + 24, GY - 12, 0.9, WOOD); c.seg(x + 20.5, GY - 9, x + 27.5, GY - 9, 0.9, WOOD); c.circ(x + 24, GY - 13.4, 1.8, Col(0xd9c9a0))
            c.R(x + 22.4, GY - 9, 3.2, 5, Col(0xb89a54))
            if lit { fire(x + 5, GY - 20, 0.45); fire(x + 23, GY - 20, 0.45) }
            c.R(x + 4.4, GY - 20, 1.2, 4, Col(0x4a3a2a)); c.R(x + 22.4, GY - 20, 1.2, 4, Col(0x4a3a2a))
            glyphs(x + 26, GY - 27, 28, 1, b.x)
        case .pen:
            c.R(x + 3, GY - 4, 7, 4, Col(0xd9b85a)); c.R(x + 3, GY - 4, 7, 0.6, Col(0xf0d88a)); c.R(x + 5.2, GY - 4, 0.5, 4, Col(0x8a6a2a))
            for q in 0..<5 { c.R(x + 47 + Double(q) * 3.6 + sin(NOW * 2 + Double(q)) * 0.6, GY - 11.5, 2, 0.4, rgba(255, 255, 255, 0.6)) }
            for k in 0..<2 {
                let hx = x + 14 + Double(k) * 30 + sin(NOW * 0.5 + Double(k) * 3) * 4
                let peck = sin(NOW * 6 + Double(k) * 2) > 0.5 ? 1.2 : 0.0
                c.ell(hx, GY - 2, 1.8, 1.4, k == 0 ? Col(0xf0ece2) : Col(0xb5673a)); c.circ(hx + 1.6, GY - 3.2 + peck, 0.9, k == 0 ? Col(0xf0ece2) : Col(0xb5673a))
                c.R(hx + 2.3, GY - 3.2 + peck, 0.7, 0.4, Col(0xe0a030)); c.R(hx + 1.3, GY - 4.3 + peck, 0.7, 0.6, RED)
            }
        case .temple:
            glyphs(x + 4, GY - 26, 19, 3, b.x); glyphs(x + w - 23, GY - 26, 19, 3, b.x + 5)
            for sx in [x + 22.0, x + w - 24] {
                c.R(sx, GY - 8, 2.4, 8, STONE2); c.R(sx - 1, GY - 9.4, 4.4, 1.6, Col(0x4a3a2a))
                if lit { fire(sx + 1.2, GY - 9.4, 0.6) } else { plume(sx + 1.2, GY - 9.4, sx, 0.45, Col(0xd8d0e0)) }
            }
            c.R(x + 27, GY - 1.6, w - 54, 1.6, Col(0xe6d2a2)); c.R(x + 25, GY - 0.8, w - 50, 0.8, STONE2)
        case .bank:
            glyphs(x + 6, GY - 27, 13, 2, b.x); glyphs(x + 37, GY - 27, 13, 2, b.x + 3)
            for sx in [x + 14.0, x + 40] {
                c.R(sx, GY - 5, 3, 5, STONE2); c.ell(sx + 1.5, GY - 6.6, 2.4, 1.8, Col(0xc9a45a)); c.circ(sx + 2.6, GY - 8.2, 1.3, Col(0xc9a45a))
            }
            if sin(NOW * 2.4) > 0.86 { c.R(x + 25.6, GY - 13.4, 4.8, 0.5, Col(0xffffff)); c.R(x + 27.7, GY - 15.5, 0.5, 4.8, Col(0xffffff)) }
        default:
            break
        }
    }
    func wellExtra(_ x: Double) {
        let bob = sin(NOW * 1.1) * 1.6
        c.seg(x + 7.5, GY - 18.5, x + 7.5, GY - 10 + bob, 0.4, Col(0xe6d2a2)); c.R(x + 6, GY - 10 + bob, 3, 2.5, WOOD); c.R(x + 6, GY - 10 + bob, 3, 0.6, Col(0x9fd8e8))
        c.R(x + 1, GY - 5.2, 13, 0.6, rgba(70, 40, 10, 0.25)); c.R(x + 1, GY - 3, 13, 0.6, rgba(70, 40, 10, 0.25))
        c.ell(x - 4, GY + 1.6, 5, 1, rgba(90, 120, 130, 0.35))
        if sin(NOW * 3 + x) > 0.75 { c.R(x + 4, GY - 7.4, 1, 1, Col(0xffffff)) }
        for k in 0..<2 {
            let px = x + 2 + Double(k) * 9
            let hop = max(0, sin(NOW * 0.6 + Double(k) * 2.2) - 0.9) * 40
            c.ell(px, GY - 21.6 - hop, 1.5, 1, Col(0x9aa0aa)); c.R(px + 1, GY - 22.8 - hop, 1, 1, Col(0x9aa0aa))
        }
        c.ell(x + 20, GY - 1.6, 2, 2.4, Col(0xb5673a)); c.R(x + 19, GY - 4.6, 2, 0.9, Col(0x8f4e2a))
        if g.B(.well).level >= 3 {
            // the fountain garden
            let fx = x - 22
            c.ell(fx, GY - 0.6, 9, 2, Col(0xb39466)); c.ell(fx, GY - 1.4, 7.6, 1.5, Col(0x6fb6c8)); c.R(fx - 1.2, GY - 8, 2.4, 7, STONE); c.ell(fx, GY - 8, 3, 0.9, STONE2)
            for j in 0..<3 {
                let dirx = Double(j - 1)
                for q in 0..<6 {
                    let u = (NOW * 1.4 + Double(q) / 6 + Double(j) * 0.2).truncatingRemainder(dividingBy: 1)
                    c.R(fx + dirx * u * 6.5 - 0.3, GY - 8.6 - sin(PI * u) * 5 + u * 6.4, 0.7, 0.9, rgba(220, 244, 255, 0.85 * (1 - u * 0.5)))
                }
            }
            c.ellStroke(fx, GY - 1.4, 3 + (NOW * 2).truncatingRemainder(dividingBy: 1) * 4, 0.8, 0.3, rgba(255, 255, 255, 0.6))
            let bloom: [Col] = [RED, Col(0xd96ad0), GOLD, Col(0xf8f6ee)]
            for q in 0..<8 {
                let bx = fx - 16 + Double(q) * 4.6 + (q > 3 ? 4 : 0)
                c.seg(bx, GY, bx + sin(NOW * 2 + Double(q)) * 0.4, GY - 3, 0.4, Col(0x4d8a3c)); c.circ(bx + sin(NOW * 2 + Double(q)) * 0.4, GY - 3.4, 0.9, bloom[q % 4])
            }
        }
    }
    func gateExtra(_ x: Double, _ L: Int) {
        c.R(x + 3, GY - 9.4, 8, 0.8, Col(0x3a3a3a)); c.R(x + 3, GY - 4.6, 8, 0.8, Col(0x3a3a3a))
        for q in 0..<4 { c.R(x + 3.8 + Double(q) * 2, GY - 9.2, 0.5, 0.5, Col(0xc8c8c0)); c.R(x + 3.8 + Double(q) * 2, GY - 4.4, 0.5, 0.5, Col(0xc8c8c0)) }
        c.circ(x + 6.2, GY - 6.6, 0.7, GOLD); c.circ(x + 7.8, GY - 6.6, 0.7, GOLD)
        if L > 2 { glyphs(x + 1.5, GY - 24, 11, 2, x) }
        if L > 3 {
            c.poly(STONE, [x - 1, GY - 34, x + 0.5, GY - 44, x + 13.5, GY - 44, x + 15, GY - 34]); c.R(x + 11, GY - 44, 2.5, 10, STONE2)
            crenels(x + 0.5, GY - 44, 13, STONE); c.R(x + 0.5, GY - 41, 13, 1.2, GOLD)
            c.R(x + 5, GY - 39.4, 4, 4.4, DARKC); c.seg(x + 2, GY - 37, x + 12, GY - 37.6, 0.5, WOOD)
            pennant(x + 3, GY - 46, GOLD, 8); pennant(x + 11, GY - 46, RED, 8)
            if lit { fire(x + 7, GY - 46, 0.55) }
        }
    }
    func ruinExtra(_ x: Double, _ w: Double, _ seed: Double) {
        for k in 0..<3 {
            let n = Double(k)
            let cx = x + 4 + hashN(seed + n) * (w - 8)
            c.seg(cx, GY - 2, cx + 1.4, GY - 6, 0.3, rgba(40, 24, 10, 0.55)); c.seg(cx + 1.4, GY - 6, cx + 0.4, GY - 9.5, 0.3, rgba(40, 24, 10, 0.55))
            let bx = x - 6 + hashN(seed + n + 7) * (w + 10)
            c.R(bx, GY - 2.4, 4.4, 2.4, MUD2); c.R(bx, GY - 2.4, 4.4, 0.5, Col(0xd9b680)); c.R(bx + 3.2, GY - 2.4, 1.2, 2.4, MUDD)
            let wx = x + hashN(seed + n + 13) * w
            for q in 0..<3 {
                let a = -1.9 + Double(q) * 0.55 + sin(NOW * 1.6 + n + seed) * 0.14
                c.seg(wx, GY - 0.5, wx + cos(a) * 4, GY - 0.5 + sin(a) * 4, 0.4, Col(0x8a8a3a))
            }
        }
        c.poly(Col(0xa8603a), [x + w * 0.7, GY, x + w * 0.7 + 1, GY - 3.4, x + w * 0.7 + 3, GY - 1.6, x + w * 0.7 + 5, GY - 3, x + w * 0.7 + 6, GY])
        // a lizard that suns itself and bolts
        let cyc = NOW * 0.11 + seed
        let u = cyc - floor(cyc)
        if g.dark < 0.4 {
            let lx = x + w * 0.2 + (u < 0.8 ? 0 : (u - 0.8) / 0.2 * 26), ly = GY - 1
            c.R(lx - 2.4, ly - 0.7, 4.8, 1.1, Col(0x6a7a3a)); c.R(lx + 2.2, ly - 1, 1.5, 1.1, Col(0x6a7a3a)); c.seg(lx - 2.4, ly, lx - 5.2, ly + 0.4 + sin(NOW * 9) * 0.3, 0.4, Col(0x6a7a3a))
        }
    }
    func campExtra(_ cp: Camp) {
        let x = cp.x - cam
        if x > W + 50 || x < -50 { return }
        for k in 0..<5 {
            let kx = x - 14 + Double(k) * 6.4
            c.poly(GOLD.alpha(0.8), [kx, GY - 3, kx + 1.6, GY - 5, kx + 3.2, GY - 3, kx + 1.6, GY - 1.6])
        }
        c.seg(x + 2, GY - 14, x + 2, GY - 20, 0.5, WOOD)
        let f = sin(NOW * 5 + cp.x) * 1
        c.poly(RED, [x + 2, GY - 20, x + 8, GY - 18.8 + f, x + 2, GY - 17.4])
        c.seg(x + 26.5, GY, x + 30, GY - 8, 0.5, Col(0x3a2a1c)); c.seg(x + 33.5, GY, x + 30, GY - 8, 0.5, Col(0x3a2a1c))
        c.ell(x + 30, GY - 5, 2.2, 1.6, Col(0x2a2422)); plume(x + 30, GY - 6.6, cp.x, 0.5)
        c.R(x + 24, GY - 1.4, 12, 0.5, GOLD.alpha(0.7))
        for q in 0..<7 { c.R(x + 24 + Double(q) * 1.9, GY + 0.4, 0.5, 1, RED) }
        c.ell(x + 41, GY - 2.4, 1.6, 2.2, Col(0x9a5a3a)); c.ell(x - 26, GY - 2, 2, 2.4, Col(0xb5673a)); c.R(x - 27, GY - 5, 2, 0.9, Col(0x8f4e2a))
    }
    func urnExtra(_ u: Urn) {
        if u.open { return }
        let x = u.x - cam
        if x > W + 10 || x < -10 { return }
        if g.relics.contains("lamp") {
            let k = 0.5 + 0.5 * sin(NOW * 3 + u.x)
            c.linear(x - 3, GY - 46, 6, 40, 0, GY - 46, 0, GY - 6, [(0, rgba(255, 226, 140, 0)), (1, rgba(255, 226, 140, 0.25 + 0.2 * k))])
            c.poly(GOLD, [x - 2.4, GY - 16 - k * 2, x + 2.4, GY - 16 - k * 2, x, GY - 12.6 - k * 2])
            light(x, GY - 8, 22, 0.7)
        }
        for q in 0..<4 { c.poly(LAPIS, [x - 3 + Double(q) * 1.6, GY - 5.4, x - 2.2 + Double(q) * 1.6, GY - 6.6, x - 1.4 + Double(q) * 1.6, GY - 5.4]) }
        c.arcStroke(x - 3, GY - 6.4, 1.3, PI * 0.5, PI * 1.5, 0.5, Col(0x8f4e2a)); c.arcStroke(x + 3, GY - 6.4, 1.3, -PI * 0.5, PI * 0.5, 0.5, Col(0x8f4e2a))
        c.ell(x - 1.4, GY - 4.6, 0.7, 2.2, rgba(255, 255, 255, 0.25))
    }
    func quarryExtra() {
        let x = g.QUARRY - cam
        if x > W + 60 || x < -60 { return }
        c.seg(x - 22, GY, x - 16, GY - 17, 0.6, WOOD); c.seg(x - 18, GY, x - 12, GY - 17, 0.6, WOOD)
        for q in 0..<5 { c.seg(x - 21.3 + Double(q) * 1.2, GY - 2 - Double(q) * 3.2, x - 17.3 + Double(q) * 1.2, GY - 2 - Double(q) * 3.2, 0.5, WOOD) }
        for q in 0..<6 { c.seg(x - 30 + Double(q) * 5, GY - 4 - hashN(Double(q) + 3) * 8, x - 28 + Double(q) * 5, GY - 6 - hashN(Double(q) + 3) * 8, 0.35, rgba(70, 40, 10, 0.4)) }
        c.R(x + 30, GY - 5, 11, 4, Col(0x7a5632)); c.R(x + 30, GY - 5, 11, 0.8, Col(0xa87c4a)); c.circ(x + 32.5, GY - 1, 1.6, Col(0x3a2a1c)); c.circ(x + 38.5, GY - 1, 1.6, Col(0x3a2a1c))
        c.R(x + 32, GY - 8, 6, 3, STONE); c.R(x + 32, GY - 8, 6, 0.6, Col(0xecd6a4))
        c.seg(x + 41, GY - 4, x + 47, GY - 5.6, 0.5, WOOD)
        c.R(x + 12, GY - 4.4, 9, 0.4, rgba(70, 40, 10, 0.3)); c.R(x + 16.4, GY - 7, 0.4, 7, rgba(70, 40, 10, 0.3))
        pennant(x - 4, GY - 20, Col(0xe0a030), 6)
    }
    func goatExtra(_ gt: Goat) {
        let x = gt.x - cam, d = gt.dir
        if x < -10 || x > W + 10 { return }
        let s = gt.kid ? 0.7 : 1.0
        let hx = x + d * 4 * s, hy = GY - 6.5 * s
        c.seg(hx - d * 0.6, hy, hx - d * 1.8, hy - 2 * s, 0.5, Col(0x5a4a3a)); c.seg(hx, hy, hx - d * 0.8, hy - 2.4 * s, 0.5, Col(0x5a4a3a))
        c.R(hx + d * 0.6 - 0.25, hy + 0.6, 0.5, 0.5, Col(0x1c1008))
        if !gt.kid { c.R(hx + d * 0.4 - 0.3, hy + 2.2 * s, 0.6, 1.4, Col(0xf0ece2)) }
        c.seg(x - d * 3 * s, GY - 4.6 * s, x - d * 4.2 * s, GY - 5.8 * s + sin(NOW * 6 + gt.x) * 0.5, 0.6, Col(0xe8e0d0))
        c.R(x - 2 * s, GY - 5 * s, 4 * s, 0.6, rgba(255, 255, 255, 0.4)); c.R(x - 1, GY - 3.6 * s, 2.4 * s, 1, rgba(120, 100, 80, 0.3))
    }
    /// Carving, lamps, cargo and rigging on the far places.
    func siteExtras() {
        let tb = g.B(.tomb)
        if !tb.gone {
            let x = tb.x - cam
            if x < W + 20 && x + tb.w > -40 {
                c.poly(GOLD, [x + 23, GY - 33.4, x + 25, GY - 36, x + 27, GY - 33.4])
                let u = (NOW * 0.5).truncatingRemainder(dividingBy: 1)
                c.alpha(0.4 * (1 - u)); c.ell(x + 25 + u * 14, GY - 36 - u * 3, 3 + u * 6, 0.8, SAND); c.alpha(1)
                if tb.level > 0 {
                    glyphs(x + 14, GY - 13, 4, 3, tb.x); glyphs(x + 31, GY - 13, 4, 3, tb.x + 2)
                    if lit { fire(x + 16, GY - 15, 0.5); fire(x + 32.5, GY - 15, 0.5) }
                    for q in 0..<3 { c.R(x + 16 + Double(q) * 6, GY, 5, 1, STONE2) }
                    if tb.level > 1 {
                        c.R(x + 18.4, GY - 14.6, 11.2, 14.6, GOLD); c.R(x + 18.4, GY - 14.6, 11.2, 1, Col(0xfff3b8)); c.R(x + 28.4, GY - 14.6, 1.2, 14.6, Col(0xb8860b))
                        glyphs(x + 20, GY - 12.6, 8, 2, tb.x + 9)
                        c.circ(x + 24, GY - 4.4, 2.2, Col(0x8f2a1c)); c.circ(x + 24, GY - 4.4, 1, GOLD)
                        c.seg(x + 18.4, GY - 7, x + 29.6, GY - 7, 0.5, Col(0x8f2a1c))
                    }
                }
            }
        }
        let hm = g.B(.hermit)
        if !hm.gone {
            let x = hm.x - cam
            if x < W + 20 && x + hm.w > -20 {
                for q in 0..<3 {
                    let sw = sin(NOW * 2 + Double(q)) * 0.8
                    c.seg(x + 14 + Double(q) * 4, GY - 16, x + 14 + Double(q) * 4 + sw, GY - 12.6, 0.25, Col(0x5a3e22))
                    c.R(x + 13.4 + Double(q) * 4 + sw, GY - 12.6, 1.2, 1.4, q == 1 ? TEAL : GOLD)
                }
                c.ell(x + 6, GY - 2.4, 2.2, 2.6, Col(0xb5673a)); c.ell(x + 42, GY - 1.8, 1.8, 2, Col(0x9a5a3a))
                c.R(x + 28, GY - 0.8, 9, 0.8, Col(0x8f2a1c)); c.R(x + 28, GY - 0.8, 9, 0.25, GOLD)
            }
        }
        let bt = g.B(.btemple)
        if !bt.gone && bt.level > 0 {
            let x = bt.x - cam
            if x < W + 20 && x + bt.w > -20 {
                glyphs(x + 6, GY - 39, 78, 1, bt.x)
                for sx in [x + 1.0, x + 85] { c.R(sx, GY - 9, 4, 9, STONE2); c.R(sx - 1, GY - 10.6, 6, 1.8, Col(0x4a3a2a)); if lit { fire(sx + 2, GY - 10.6, 0.7) } }
                c.circ(x + 45, GY - 44.4, 3, GOLD); c.poly(GOLD, [x + 39, GY - 44.4, x + 45, GY - 46, x + 51, GY - 44.4, x + 45, GY - 43])
                if bt.level > 1 {
                    c.poly(GOLD, [x + 2, GY - 40, x + 45, GY - 51.6, x + 88, GY - 40, x + 84, GY - 40, x + 45, GY - 49.4, x + 6, GY - 40])
                    for sx in [x - 8.0, x + 93] {
                        c.R(sx, GY - 3, 6, 3, STONE2); c.R(sx + 1.2, GY - 17, 3.6, 14, STONE); c.R(sx + 0.8, GY - 21, 4.4, 4.4, STONE); c.R(sx + 0.4, GY - 22.4, 5.2, 1.8, LAPIS); c.R(sx + 2.4, GY - 12, 1.2, 6, GOLD)
                    }
                    for q in 0..<5 { c.R(x + 8 + Double(q) * 18, GY - 34.6, 6, 1.2, GOLD) }
                }
            }
        }
        let gv = g.B(.grove)
        if !gv.gone && gv.level > 1 && g.OASIS > 0 {
            let ox = g.OASIS - cam
            if ox > -110 && ox < W + 110 {
                palm(ox - 90, 30, 1, 41, true); palm(ox + 90, 26, 0.95, 42, true)
                for q in 0..<3 { let bx = ox - 70 + Double(q) * 7; c.R(bx, GY - 3, 5, 3, Col(0xb89a54)); c.R(bx, GY - 3, 5, 0.6, Col(0xe0c88a)); c.circ(bx + 1.4, GY - 3.6, 1.1, Col(0xd9822a)); c.circ(bx + 3.4, GY - 3.8, 1.1, Col(0xc2641e)) }
                if gv.level > 2 {
                    palm(ox - 104, 24, 0.9, 43, true); palm(ox + 104, 30, 1, 44, true)
                    c.seg(ox + 58, GY, ox + 58, GY - 9, 0.7, WOOD); c.seg(ox + 78, GY, ox + 78, GY - 9, 0.7, WOOD); c.R(ox + 57, GY - 9.6, 22, 1, WOOD)
                    for q in 0..<8 { c.circ(ox + 59.5 + Double(q) * 2.5, GY - 7.6 + sin(NOW * 2 + Double(q)) * 0.3, 1, q % 2 == 0 ? Col(0xd9822a) : Col(0xa8521a)) }
                }
            }
        }
        let dk = g.B(.dock)
        let x = dk.x - cam
        if dk.level > 0 && x < W + 40 {
            c.R(x + 8, GY - 6.4, 5, 4, Col(0x8a6434)); c.R(x + 8, GY - 6.4, 5, 0.7, Col(0xb08854)); c.R(x + 14, GY - 5.2, 4, 2.8, Col(0x7a5632)); c.R(x + 10, GY - 9.4, 4, 3, Col(0x9a7444))
            c.ell(x + 24, GY - 3.4, 2.4, 1, Col(0xc9a876)); c.ell(x + 24, GY - 4, 2, 0.8, Col(0xa88856))
            c.seg(x + 58, GY - 2.4, x + 58, GY - 16, 0.9, WOOD); c.seg(x + 58, GY - 16, x + 61.5, GY - 16, 0.6, WOOD)
            let sw = sin(NOW * 1.4) * 0.7
            c.seg(x + 61.5, GY - 16, x + 61.5 + sw, GY - 13.4, 0.3, Col(0x5a3e22)); c.R(x + 60.4 + sw, GY - 13.4, 2.2, 2.8, lit ? Col(0xffd27a) : Col(0xe0a030))
            if lit { light(x + 61.5 + sw, GY - 12, 22, 0.8) }
            let away = (g.trip ?? 0) * 26
            let bx = x + 78 + away, by = GY + 3 + sin(NOW * 1.6) * 0.6
            if g.trip == nil { c.curve(x + 66, GY - 2, x + 64, GY + 3, bx - 15, by - 4, 0.4, Col(0xc9a876)) }
            c.seg(bx - 4, by - 10.4, bx + 10, by - 26.5, 0.6, RED); c.seg(bx + 2, by - 9.6, bx + 12, by - 21, 0.4, rgba(181, 65, 46, 0.5))
            c.poly(RED, [bx + 9, by - 34, bx + 9, by - 37, bx + 4 + sin(NOW * 5) * 0.8, by - 35.6])
            c.R(bx - 15, by + 1.6, 30, 0.5, rgba(255, 255, 255, 0.45)); c.R(bx - 10, by - 3.4, 20, 0.5, GOLD)
            c.R(bx + 6, by - 6.6, 4, 2.6, Col(0x8a6434)); c.R(bx + 2, by - 6, 3, 2, Col(0xb5673a))
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
            if i % 2 == 0 && h > 44 {
                // a tomb front cut into the rock
                let dx = x + w * 0.28, y0 = GY - 14 - h * 0.42
                c.R(dx - 7, y0 - 15, 20, 15, rgba(70, 30, 14, 0.22)); c.R(dx - 8, y0 - 16.6, 22, 1.8, rock)
                for k in 0..<4 { c.R(dx - 6 + Double(k) * 5.6, y0 - 14, 1.6, 14, Col.mix(rock, Col(0xfff0d0), 0.25)) }
                c.R(dx + 0.6, y0 - 11, 4.4, 11, Col.mix(Col(0x2a120a), hz, 0.3)); c.R(dx - 8, y0, 22, 1.2, shade)
            }
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
                devil(x, GY, 30, 0.32, dv.a)
            }
        }
        let traps = g.trapXs()
        for i in 0..<traps.count {
            let x = traps[i] - cam
            if x < -12 || x > W + 12 { continue }
            c.R(x - 6, GY - 0.6, 12, 1.4, Col(0x6a5a48)); c.R(x - 6, GY - 0.6, 12, 0.4, Col(0x9a8a70))
            for q in 0..<5 { c.R(x - 5.6 + Double(q) * 2.6, GY - 0.4, 1, 1, Col(0x1c0c06)) }
            if g.trapUp(i) {
                for q in 0..<5 {
                    let sx = x - 5.1 + Double(q) * 2.6
                    c.seg(sx, GY, sx, GY - 13, 0.7, Col(0x9aa0a0)); c.poly(Col(0xe4e4dc), [sx - 0.9, GY - 13, sx, GY - 17, sx + 0.9, GY - 13])
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
    /// The Sphinx in profile, looking east. Drawn around its own origin at the west end of the plinth.
    func sphinx(_ b: Building) {
        let x = b.x - cam
        if x > W + 20 || x + b.w < -20 { return }
        let L = b.level
        let hi = Col(0xecd6a4), line = rgba(110, 78, 36, 0.4)
        if L == 0 {
            // buried to the chin
            c.poly(SAND2, [x - 8, GY, x + 18, GY - 9, x + 50, GY - 16, x + 92, GY])
            c.poly(STONE, [x + 12, GY - 6, x + 22, GY - 11, x + 38, GY - 10.5, x + 44, GY - 6]); c.seg(x + 22, GY - 11, x + 38, GY - 10.5, 0.6, hi)
            c.save(); c.translate(x, GY + 13); sphinxHead(0); c.restore()
            c.poly(SAND, [x + 4, GY, x + 20, GY - 7, x + 44, GY - 9, x + 57, GY - 13.5, x + 70, GY - 11, x + 88, GY])
            c.seg(x + 44, GY - 9, x + 57, GY - 13.5, 0.5, rgba(255, 244, 208, 0.5))
        } else {
            c.ell(x + 42, GY + 1, 46, 2.4, rgba(60, 34, 8, 0.25))
            c.save(); c.translate(x, GY)
            // plinth
            c.R(2, -3, 82, 3, STONE2); c.R(2, -3, 82, 0.6, L > 1 ? GOLD : hi)
            for q in 0..<9 { c.R(8 + Double(q) * 9, -2.2, 0.35, 2.2, rgba(60, 34, 8, 0.25)) }
            // tail, curled up over the haunch
            c.curve(9, -5, 0, -14, 9, -21.5, 1.3, STONE2); c.circ(9.6, -21.6, 1.2, STONE2)
            // haunch and body, with a darker edge so it stands off the dunes
            c.ell(17, -12.5, 11.8, 10.3, rgba(120, 84, 40, 0.55)); c.poly(rgba(120, 84, 40, 0.55), [9.2, -3, 11.2, -19.7, 20, -22.8, 36, -21.3, 50, -23.8, 58.6, -24.8, 60.8, -3])
            c.ell(17, -12.5, 11, 9.5, STONE)
            c.poly(STONE, [10, -3, 12, -19, 20, -22, 36, -20.5, 50, -23, 58, -24, 60, -3])
            c.R(26, -6.4, 28, 3.4, STONE2)
            // folded hind leg and paw
            c.ell(20, -5.6, 10, 2.6, STONE); c.R(22, -5, 12, 2, STONE); c.ell(34, -4.4, 2.6, 1.6, STONE)
            c.curve(26, -18, 31, -10, 24, -6, 0.5, line); c.R(10, -3.6, 26, 0.6, STONE2)
            // chest
            c.poly(STONE, [48, -3, 49, -23, 58, -25, 61, -14, 60, -3])
            c.poly(STONE2, [58.6, -23, 61, -14, 60.2, -8, 58.6, -8])
            // forelegs stretched out in front
            c.R(54, -8, 25, 5, STONE); c.ell(79, -5.5, 3, 2.5, STONE)
            c.R(54, -8, 25, 0.7, hi); c.R(54, -3.8, 27, 0.8, STONE2)
            for q in 0..<3 { c.R(79.4 + Double(q) * 0.9, -5.6, 0.3, 2.4, STONE2) }
            c.curve(50, -21, 45, -13, 53, -7.5, 0.5, line)
            // light along the back
            c.seg(12.6, -19.4, 20, -22, 0.6, hi); c.seg(20, -22, 36, -20.5, 0.6, hi); c.seg(36, -20.5, 49, -23, 0.6, hi)
            // weathered beds in the rock
            for q in 0..<3 { c.R(13 + Double(q) * 2, -9 - Double(q) * 4, 38 - Double(q) * 3, 0.35, rgba(110, 78, 36, 0.22)) }
            if L == 1 {
                c.seg(30, -20, 28.5, -12, 0.35, rgba(90, 60, 26, 0.5)); c.seg(42, -21.4, 43.6, -15, 0.35, rgba(90, 60, 26, 0.5))
                c.R(37, -8.6, 3, 2, STONE2); c.R(66, -8, 2.4, 1.2, STONE2)
                c.poly(SAND, [0, 0, 6, -4, 14, 0]); c.poly(SAND, [70, 0, 80, -2.4, 88, 0])
            } else {
                c.poly(GOLD, [49.6, -23.4, 58, -25.4, 58.6, -23.2, 49.6, -21.2]); c.R(53, -23.6, 2, 1.6, TEAL)
                c.R(73, -8, 1.4, 5, GOLD); c.R(30, -6.4, 1.4, 3.4, GOLD)
                c.R(10.6, -4.2, 26, 0.6, GOLD)
            }
            sphinxHead(L)
            c.restore()
            if sin(NOW * 0.7) > 0.93 { c.R(x + 61, GY - 33.6, 1.2, 0.9, Col(0xfff3b0)); light(x + 62, GY - 33, 10, 0.4) }
            if L > 1 {
                for sx in [x - 4.0, x + 87] {
                    c.R(sx, GY - 7, 2, 7, Col(0x4a3a2a)); c.R(sx - 1, GY - 8.2, 4, 1.4, Col(0x6a5238))
                    if lit { fire(sx + 1, GY - 8.2, 0.55) } else { plume(sx + 1, GY - 8.2, sx, 0.4, Col(0xd8d0e0)) }
                }
                for q in 0..<5 { c.circ(x + 62 + Double(q) * 3.4, GY - 0.8, 0.8, q % 2 == 0 ? RED : Col(0xf8f6ee)) }
            }
        }
        rising(b, x)
    }
    /// Head and striped headcloth in profile. Level 1 is worn and has lost its nose; level 2 is restored.
    private func sphinxHead(_ L: Int) {
        let cloth: Col = L > 1 ? LAPIS : STONE2
        let stripe: Col = L > 1 ? GOLD : rgba(110, 78, 36, 0.35)
        c.poly(cloth, [43, -19, 47, -35, 52, -40, 59, -39.5, 61, -36.5, 57.5, -34, 57, -27, 60, -17, 55, -17, 53.5, -24, 49, -20])
        for q in 0..<6 {
            let yy = -37.0 + Double(q) * 2.3
            let xb = yy < -35 ? 47 + (-35 - yy) : 47 - (yy + 35) / 4
            c.R(xb + 0.5, yy, 56.6 - xb, 0.7, stripe)
        }
        c.R(54.6, -22.5, 3.6, 0.7, stripe); c.R(55, -20.2, 3.9, 0.7, stripe); c.R(55.2, -18, 4.2, 0.7, stripe)
        var f: [Double] = [57.5, -36, 62.5, -36.5, 63.2, -34, 62.8, -33]
        if L > 1 { f += [65.4, -30.6, 63.4, -29.8] } else { f += [63.3, -31.6, 63, -29.8] }
        f += [64, -28.6, 63.6, -27.6, 63.8, -26.4, 62.6, -25, 58.5, -25, 57, -27, 57.5, -34]
        c.poly(STONE, f)
        c.R(58.4, -25.2, 3.8, 1.4, STONE2)
        c.R(58, -29.4, 2, 3.2, rgba(110, 78, 36, 0.18))
        c.R(57.4, -32.4, 1.3, 2.6, STONE2)
        c.R(60, -34.8, 2.8, 0.5, STONE2); c.R(60.6, -33.7, 1.8, 0.9, Col(0x2a1a0c))
        c.R(62.4, -28.4, 1.6, 0.4, STONE2)
        c.R(57.3, -37.2, 5.6, 1, L > 1 ? GOLD : STONE)
        if L > 1 {
            c.R(59, -33.3, 1.6, 0.4, LAPIS)
            c.R(62, -39.8, 1.2, 2.8, GOLD); c.R(62.8, -40.6, 1.4, 1.2, GOLD)
            c.poly(LAPIS, [61.2, -25, 63.4, -25, 63, -18.5, 61.6, -18.5]); c.R(61.4, -22.8, 1.8, 0.5, GOLD); c.R(61.5, -20.6, 1.6, 0.5, GOLD)
        } else {
            c.R(62.7, -31.7, 0.8, 1.3, STONE2)
            c.seg(52, -38, 54, -31, 0.35, rgba(90, 60, 26, 0.5))
        }
    }
    /// The cliffs town's tomb: a temple front cut into the red rock, four seated kings and a dark door.
    func cliffTomb(_ b: Building) {
        let x0 = -40 - cam, xe = b.x + 168 - cam, hh = GY - 2, dx = b.x + 19 - cam
        if x0 > W || xe < -80 { return }
        c.poly(Col(0xb0623a), [x0, GY, x0, GY - hh, xe - 20, GY - hh, xe - 8, GY - hh * 0.86, xe - 14, GY - hh * 0.66, xe + 2, GY - hh * 0.5, xe - 4, GY - hh * 0.3, xe + 10, GY - hh * 0.12, xe + 16, GY])
        c.poly(Col(0x8a4628), [xe - 20, GY - hh, xe - 8, GY - hh * 0.86, xe - 14, GY - hh * 0.66, xe + 2, GY - hh * 0.5, xe - 4, GY - hh * 0.3, xe + 10, GY - hh * 0.12, xe + 16, GY, xe + 58, GY, xe + 40, GY - hh * 0.2, xe + 34, GY - hh * 0.5, xe + 22, GY - hh * 0.8, xe + 14, GY - hh])
        for q in 1..<14 {
            let k = Double(q)
            c.R(x0, GY - hh * k / 14 + sin(k * 2.1) * 1.5, xe - x0 - 12 + Double((q * 53) % 16), 0.8, rgba(70, 28, 12, 0.13 + 0.07 * Double(q % 3)))
        }
        for i in 0..<16 {
            let n = Double(i)
            c.R(x0 + 16 + hashN(n + 33) * 250, GY - 8 - hashN(n + 34) * (hh - 14), 6 + hashN(n) * 8, 2.4, rgba(60, 24, 10, 0.28))
        }
        // the recess, in deep shadow at the top
        let fw = 150.0, fx = dx - 69, fh = min(104, GY - 20)
        c.R(fx, GY - fh, fw, fh, Col(0xc47c4e))
        c.vfill(fx, GY - fh, fw, 34, [(0, rgba(40, 14, 6, 0.75)), (1, rgba(40, 14, 6, 0))])
        c.R(fx, GY - fh, 4, fh, rgba(40, 14, 6, 0.55)); c.R(fx + fw - 4, GY - fh, 4, fh, rgba(40, 14, 6, 0.35))
        c.R(fx - 3, GY - fh - 4, fw + 6, 5, Col(0xd99a6c)); c.R(fx - 3, GY - fh - 4, fw + 6, 1, Col(0xf0c49c))
        // a frieze of little figures, and a niche with a standing god over the door
        var gi = 0.0
        while gi < fw - 12 { c.RR(fx + 7 + gi, GY - fh + 7, 3.4, 7, 1, Col(0xa85a36)); c.circ(fx + 8.7 + gi, GY - fh + 5.6, 1.7, Col(0xa85a36)); gi += 8 }
        c.R(fx + 4, GY - fh + 16, fw - 8, 1.6, Col(0xe0a274)); c.R(fx + 4, GY - fh + 18.4, fw - 8, 1, Col(0x8a4628))
        c.R(dx - 3, GY - fh + 22, 18, 26, Col(0x5a2814)); c.RR(dx + 1, GY - fh + 29, 10, 19, 2, Col(0xc98052)); c.circ(dx + 6, GY - fh + 26.4, 3.4, Col(0xc98052))
        c.R(dx + 2, GY - fh + 22.4, 8, 2.4, Col(0xb06a40)); c.circ(dx + 6, GY - fh + 21.6, 2.2, GOLD)
        // four seated kings, two each side of the door
        for sx in [fx + 8, fx + 38, fx + 90, fx + 120] {
            let top = GY - 58
            c.R(sx - 1, GY - 12, 24, 12, Col(0xa85a36)); c.R(sx, GY - 16, 22, 5, Col(0xb8693e))
            c.RR(sx + 3, top + 18, 16, 26, 2, Col(0xcf8a5a)); c.R(sx + 15, top + 18, 4, 26, Col(0xa85a36))
            c.RR(sx + 5, top + 4, 12, 13, 3, Col(0xcf8a5a)); c.RR(sx + 3, top, 16, 5, 1.5, Col(0xb8693e))
            c.R(sx + 2, top + 4, 3.4, 16, Col(0xb8693e)); c.R(sx + 16.6, top + 4, 3.4, 16, Col(0xb8693e))
            c.R(sx + 7, top + 9, 2, 1.4, Col(0x4a1c0c)); c.R(sx + 12.6, top + 9, 2, 1.4, Col(0x4a1c0c)); c.R(sx + 8.4, top + 13, 5, 0.9, Col(0x8a4628))
            c.R(sx + 9.4, top + 15, 3, 4, Col(0xb8693e)); c.R(sx + 3, top + 34, 16, 3, Col(0xa85a36))
            c.RR(sx + 4, top + 38, 5, 8, 1, Col(0xc98052)); c.RR(sx + 13, top + 38, 5, 8, 1, Col(0xc98052))
            c.R(sx + 3, top + 24, 2.6, 12, Col(0xb8693e)); c.R(sx + 16.4, top + 24, 2.6, 12, Col(0xb8693e))
        }
        c.R(dx - 6, GY - 36, 24, 36, Col(0xa85a36)); c.R(dx - 8, GY - 40, 28, 4.4, Col(0xe0a274)); c.R(dx - 8, GY - 40, 28, 1, Col(0xf0c49c))
        c.R(dx, GY - 30, 12, 30, Col(0x120805))
        for i in 0..<9 {
            let n = Double(i)
            c.RR(fx + 8 + hashN(n + 60) * (fw - 20), GY - 2 - hashN(n + 61) * 3, 4 + hashN(n) * 5, 3, 1, i % 2 == 1 ? Col(0x8a4628) : Col(0xb8693e))
        }
        c.poly(Col(0xb8693e), [xe - 30, GY, xe + 4, GY - 13, xe + 30, GY - 7, xe + 62, GY]); c.poly(Col(0x9a5632), [xe + 4, GY - 13, xe + 30, GY - 7, xe + 62, GY, xe + 22, GY])
        if b.level == 0 {
            // still walled up
            c.R(dx, GY - 30, 12, 30, Col(0x9a5632))
            var q = 3.0
            while q < 30 { c.R(dx, GY - q, 12, 0.6, Col(0x7e4426)); q += 5 }
            c.circ(dx + 6, GY - 16, 3, Col(0x7e4426)); c.circ(dx + 6, GY - 16, 1.6, Col(0xb8693e))
            c.poly(Col(0xb8693e), [dx - 16, GY, dx - 3, GY - 9, dx + 13, GY - 6, dx + 28, GY])
        } else {
            c.R(dx - 11.5, GY - 20, 1, 20, WOOD); c.R(dx + 22.5, GY - 20, 1, 20, WOOD)
            fire(dx - 11, GY - 20, 0.7); fire(dx + 23, GY - 20, 0.7)
            if !g.looted {
                // the chest, just inside the door
                c.RR(dx + 2, GY - 7, 8, 7, 1, Col(0x6a4426)); c.R(dx + 2, GY - 7, 8, 1.4, GOLD); c.R(dx + 5.2, GY - 5, 1.6, 2.4, GOLD)
                light(dx + 6, GY - 5, 12, 0.6)
                if sin(NOW * 3) > 0.5 { c.R(dx + 3, GY - 9, 5, 0.5, Col(0xffffff)); c.R(dx + 5.2, GY - 11, 0.5, 5, Col(0xffffff)) }
            } else if lit {
                c.R(dx + 1, GY - 28, 10, 28, rgba(120, 255, 170, 0.14 + 0.08 * sin(NOW * 3)))
            }
        }
        rising(b, b.x - cam)
    }
    func tomb(_ b: Building) {
        if g.feat == .cliff { cliffTomb(b); return }
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
        let deep = Col.mix(wc, Col(0x10384a), 0.35).alpha(0.5), edge = Col(0x5a8a3a)
        for k in 0..<3 {
            let f = 0.6 - Double(k) * 0.17
            c.poly(wl.alpha(0.2), [x - 5 * f, GY - 23, x + 5 * f, GY - 23, x + 38 * f - 5, GY + 1, x - 38 * f - 5, GY + 1])
        }
        c.poly(deep, [x - 5, GY - 23, x - 3.8, GY - 23, x - 30, GY + 1, x - 38, GY + 1]); c.poly(deep, [x + 5, GY - 23, x + 3.8, GY - 23, x + 30, GY + 1, x + 38, GY + 1])
        c.seg(x - 5, GY - 23, x - 38, GY + 1, 0.5, edge); c.seg(x + 5, GY - 23, x + 38, GY + 1, 0.5, edge)
        // the near reach, across the road and off the bottom of the screen
        c.poly(Col(0x8fb85a), [x - 52, GY, x - 38, GY, x - 62, H, x - 80, H])
        c.poly(Col(0x8fb85a), [x + 38, GY, x + 52, GY, x + 80, H, x + 62, H])
        c.poly(wc, [x - 38, GY, x + 38, GY, x + 62, H, x - 62, H])
        for k in 0..<3 {
            let f = 0.6 - Double(k) * 0.17
            c.poly(wl.alpha(0.2), [x - 38 * f - 5, GY, x + 38 * f - 5, GY, x + 62 * f - 9, H, x - 62 * f - 9, H])
        }
        c.poly(deep, [x - 38, GY, x - 30, GY, x - 50, H, x - 62, H]); c.poly(deep, [x + 38, GY, x + 30, GY, x + 50, H, x + 62, H])
        c.seg(x - 38, GY, x - 62, H, 0.6, edge); c.seg(x + 38, GY, x + 62, H, 0.6, edge)
        c.seg(x - 52, GY, x - 80, H, 0.5, Col(0xb6d07a)); c.seg(x + 52, GY, x + 80, H, 0.5, Col(0xb6d07a))
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
        creekExtra(x)
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
            c.poly(Col(0x6a4426), [bx - 18, by - 6.5, bx - 14, by - 4, bx + 14, by - 4, bx + 20, by - 8, bx + 14, by + 2, bx - 12, by + 2])
            c.R(bx - 14, by - 5, 28, 1.2, Col(0xd8ba88))
            c.seg(bx - 2, by - 4, bx - 2, by - 24, 1, WOOD)
            // lateen sail on its long slanted yard
            c.poly(Col(0xf6efdc), [bx - 12, by - 11, bx + 8, by - 33, bx + 14.5, by - 18, bx + 13, by - 8])
            c.poly(rgba(150, 120, 80, 0.22), [bx + 8, by - 33, bx + 14.5, by - 18, bx + 13, by - 8, bx + 9.5, by - 14])
            c.seg(bx - 13, by - 10, bx + 9, by - 34, 0.8, WOOD)
            c.seg(bx + 13, by - 8, bx + 16, by - 5, 0.3, Col(0x5a3e22)); c.seg(bx - 13, by - 10, bx - 15, by - 5, 0.3, Col(0x5a3e22))
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
        if g.relics.contains("lamp") { for u in g.urns where !u.open { c.R(mx(u.x) - 0.5, y - 0.2, 1, 1.8, Col(0xffe08a)) } }
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
        let coat = Col(0xe8e0d0), sh = Col(0xc4b89e), dark = Col(0x5a4a3a)
        c.ell(x, GY + 0.3, 4.4 * s, 0.8, rgba(50, 28, 8, 0.28))
        c.roundCaps(true)
        for (i, lx) in [-2.2, -1.2, 1.4, 2.4].enumerated() {
            let sw = (i % 2 == 0 ? wk : -wk) * 0.8
            c.seg(x + lx * s, GY - 2.6 * s, x + lx * s + sw, GY - 0.4, 0.7 * s, i % 2 == 0 ? dark : Col(0x7a6a56))
        }
        c.ell(x, GY - 4 * s, 3.6 * s, 2.1 * s, coat); c.ell(x - d * 0.6 * s, GY - 3.1 * s, 3 * s, 1.1 * s, sh)
        c.seg(x - d * 3.3 * s, GY - 4.8 * s, x - d * 4.3 * s, GY - 5.8 * s + wk * 0.3, 0.7 * s, coat)
        let hx = x + d * 3.8 * s, hy = GY - 6.2 * s + (gt.moving ? 0 : sin(NOW * 1.5 + gt.x) * 0.4)
        c.seg(x + d * 2.6 * s, GY - 4.6 * s, hx, hy, 1.6 * s, coat)
        c.ell(hx + d * 0.6 * s, hy, 1.7 * s, 1.2 * s, Col(0xd8ccb4))
        c.circ(hx + d * 1.1 * s, hy - 0.2 * s, 0.3 * s, Col(0x1c120a))
        c.seg(hx - d * 0.4 * s, hy - 0.9 * s, hx - d * 1.6 * s, hy - 2.6 * s, 0.5 * s, dark)
        c.seg(hx - d * 0.9 * s, hy - 0.2 * s, hx - d * 1.9 * s, hy + 0.5 * s, 0.6 * s, sh)
        if !gt.kid { c.seg(hx + d * 1.6 * s, hy + 0.9 * s, hx + d * 1.4 * s, hy + 2 * s, 0.4 * s, sh) }
        c.roundCaps(false)
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
        c.RR(x + d * 3.2 - 0.6, y - 13.4, 1.3, 6, 0.65, c2); c.RR(x + d * 4.9 - 0.6, y - 14, 1.3, 6.4, 0.65, c1)
        c.circ(x + d * 5.5, y - 6.6, 0.5, Col(0x1c120a)); c.circ(x - d * 5.2, y - 4.4, 1.6, Col(0xfff8ea))
        c.R(x - d * 3.4, y - 1.2, 3.2, 1.2, c2); c.R(x + d * 1.6, y - 1.2, 2, 1.2, c2)
    }

    // ---------- people
    func folk(_ f: Folk) {
        var o = PersonOpt(robe: ROBE[f.id % 5], turban: TURB[f.id % 5], skin: SKIN[f.id % 3])
        o.dir = f.dir; o.moving = f.moving; o.walk = f.walk; o.ham = f.ham; o.cheer = f.cheer > 0
        if f.id % 4 == 0 { o.beard = Col(0x3a2a1c) }
        switch f.role {
        case .folk:
            o.lantern = lit && f.id % 2 == 0
            o.tool = .hammer
            if f.id % 2 == 1 { o.sash = TURB[(f.id + 2) % 5] }
        case .digger: o.robe = Col(0xd9b99a); o.tool = .pick; o.pack = true
        case .guard: o.robe = Col(0xe8dcc0); o.turban = RED; o.sash = RED; o.tool = .spear; o.torch = lit; o.hat = 1
        case .herder: o.robe = Col(0x8a6a44); o.tool = .staff; o.hat = 2
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
        // a red glow and a marker overhead, so raiders never pass for townsfolk
        let gx = r.x - cam
        if gx > -30 && gx < W + 30 {
            let pulse = 0.5 + 0.5 * sin(NOW * 5 + Double(r.id))
            let gr: Double = r.kind == .boss ? 30 : (r.kind == .rider ? 21 : 15)
            let gh: Double = r.kind == .boss ? 46 : (r.kind == .rider ? 34 : 23)
            c.glow(gx, GY - gr * 0.6, gr, rgba(255, 60, 40, 0.3 + 0.16 * pulse), rgba(255, 60, 40, 0))
            c.ell(gx, GY + 0.6, gr * 0.45, 1.3, rgba(255, 50, 30, 0.45))
            c.poly(Col(0xff4030), [gx - 2.2, GY - gh - 3 - pulse, gx + 2.2, GY - gh - 3 - pulse, gx, GY - gh - pulse])
            light(gx, GY - gr * 0.6, gr * 0.8, 0.35)
        }
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
        c.roundCaps(true)
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
            c.RR(fx - 0.9 + d * 0.3, -1 - lf, 2, 1, 0.45, Col(0x4a3320))
            c.R(fx - 0.2 + d * 0.3, -1.6 - lf, 0.5, 0.8, Col(0x2a1a10)); c.R(fx - 0.8 + d * 0.3, -0.2 - lf, 1.8, 0.25, Col(0x2a1a10))
        }
        // a dark outline behind, then the robe
        c.poly(rgba(50, 28, 10, 0.55), [-2.7, top - 0.4, 2.7, top - 0.4, 3.9 + hem * 0.4, -1.3, -3.9 + hem * 0.4, -1.3])
        c.RR(-1.9, -14.4 - br, 3.8, 3.9, 1.5, rgba(50, 28, 10, 0.5))
        if o.pack {
            c.RR(-d * 4.2 - 1.5, -9.4 - br, 3, 4.2, 0.8, Col(0xb58a52)); c.R(-d * 4.2 - 1.5, -8.2 - br, 3, 0.4, Col(0x7a5632)); c.R(-d * 4.2 - 1.5, -6.8 - br, 3, 0.4, Col(0x7a5632))
            c.seg(-d * 3, -9.6 - br, -d * 1.2, -9.8 - br, 0.4, Col(0x5a3e22))
        }
        if !o.cheer {
            let fsw = o.moving ? sin(ph) * 1.7 : 0
            c.seg(-d * 0.9, -9.4 - br, -d * 0.9 + fsw, -5.6 - br, 1.1, Col.mix(o.robe, Col(0x3a2416), 0.3)); c.circ(-d * 0.9 + fsw, -5.3 - br, 0.55, Col.mix(o.skin, Col(0x3a2416), 0.25))
        }
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
            for s in [-1.0, 1.0] { c.seg(s * 2, sy, s * 3.9, sy - 5, 1.15, o.robe); c.circ(s * 3.9, sy - 5.5, 0.7, o.skin) }
        } else if o.tool == .none || (o.tool == .hammer && !swinging) {
            let asw = o.moving ? sin(ph + PI) * 1.9 : 0
            c.seg(d * 0.3, sy, d * 0.3 + asw, -5.4 - br, 1.2, o.robe)
            c.seg(d * 0.3, sy, d * 0.3 + asw, -5.4 - br, 1.2, sh)
            c.circ(d * 0.3 + asw, -5.1 - br, 0.65, o.skin)
        } else {
            c.seg(d * 0.6, sy, ax, ay + 0.4, 1.2, o.robe)
            c.seg(d * 0.6, sy, ax, ay + 0.4, 1.2, sh)
            c.circ(ax, ay + 0.3, 0.65, o.skin)
        }
        // head: a face with an eye and a nose, so nobody is a blank box
        c.RR(-1.6, -14.2 - br, 3.2, 3.6, 1.25, o.skin)
        c.ell(d * 0.75, -12.8 - br, 0.62, 0.48, Col(0xf6f0e0))
        c.circ(d * 0.98, -12.78 - br, 0.34, Col(0x2a1a10))
        c.R(d * 0.7 - 0.7, -13.9 - br, 1.4, 0.35, Col(0x3a2416))
        c.R(d * 1.6 - 0.3, -12.5 - br, 0.6, 0.9, o.skin); c.R(d * 1.5 - 0.3, -11.9 - br, 0.5, 0.3, rgba(60, 30, 0, 0.3))
        c.R(-d * 1.3 - 0.4, -13 - br, 0.8, 1.2, Col.mix(o.skin, Col(0x3a2416), 0.3))
        if o.veil == nil && o.beard == nil { c.R(d * 0.8 - 0.4, -11.7 - br, 1, 0.3, Col(0x6a3a28)) }
        c.R(-1.6, -11.2 - br, 3.2, 0.5, rgba(60, 30, 0, 0.25))
        if let bd = o.beard { c.RR(d > 0 ? -0.9 : -1.7, -12 - br, 2.6, 1.7, 0.7, bd) }
        if let v = o.veil { c.RR(-1.75, -12.5 - br, 3.5, 2.2, 0.7, v) }
        if o.hat == 1 {
            // a bronze helmet with a cheek guard and a red crest
            let bz = Col(0xc98a3a)
            c.RR(-2.2, -16.6 - br, 4.4, 3, 1.6, bz); c.R(-2.2, -14.6 - br, 4.4, 0.6, Col(0x8a5a22))
            c.R(-d * 1.9 - 0.5, -14.2 - br, 1, 2.2, bz); c.ell(-d * 0.5, -16.2 - br, 1, 0.5, rgba(255, 244, 200, 0.5))
            c.poly(RED, [-1.4, -16.5 - br, 0, -18.6 - br + sin(NOW * 6 + x) * 0.2, 1.4, -16.5 - br]); c.R(-0.3, -17.4 - br, 0.6, 1, Col(0x8f2a1c))
        } else if o.hat == 2 {
            // a wide straw hat against the sun
            let st = Col(0xe0c070)
            c.ell(0, -14.9 - br, 4.2, 0.9, Col(0xb89448)); c.ell(0, -15.2 - br, 4, 0.8, st)
            c.RR(-1.7, -17.2 - br, 3.4, 2.4, 1.3, st); c.R(-1.7, -15.7 - br, 3.4, 0.5, RED)
            c.seg(-1, -16.8 - br, -0.4, -15.9 - br, 0.2, Col(0xb89448)); c.seg(0.6, -17 - br, 1, -15.9 - br, 0.2, Col(0xb89448))
        } else {
            c.RR(-2.3, -16.4 - br, 4.6, 2.9, 1.3, o.turban); c.ell(0, -16.4 - br, 1.8, 0.9, o.turban)
            c.RR(-2.3, -14.8 - br, 4.6, 0.6, 0.3, rgba(0, 0, 0, 0.16)); c.circ(-d * 0.5, -16 - br, 0.5, rgba(255, 255, 255, 0.3))
            c.seg(-2.1, -15.3 - br, 2.1, -15.9 - br, 0.3, rgba(0, 0, 0, 0.18)); c.seg(-1.9, -14.9 - br, 2.1, -15.2 - br, 0.25, rgba(255, 255, 255, 0.22))
            if o.sash != nil { c.circ(d * 1.2, -15.5 - br, 0.5, GOLD) }
            let tw = sin(NOW * 8 + x) * 0.5 * (tr + 0.3)
            c.poly(o.turban, [-d * 2, -15.4 - br, -d * (3.3 + tr * 0.8), -13.6 - br + tw, -d * (2.7 + tr * 0.4), -10.8 - br, -d * 2, -12.6 - br])
        }
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
        c.roundCaps(false)
        c.restore()
        if o.lantern {
            // a small lantern swinging from the hand
            let lx = sx + d * 3.4 * PS + sin(NOW * 3 + x) * 0.5, ly = y - 5.4 * PS
            c.seg(sx + d * 2 * PS, y - 7.4 * PS, lx, ly - 1.6, 0.3, Col(0x3a2a1a))
            c.glow(lx, ly, 6, rgba(255, 204, 116, 0.7), rgba(255, 204, 116, 0))
            c.RR(lx - 0.8, ly - 1.2, 1.6, 2.4, 0.5, Col(0xffe6a0)); c.R(lx - 1, ly - 1.6, 2, 0.5, Col(0x3a2a1a))
            light(lx, ly, 12, 0.55)
        }
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
        if o.gallop || o.rear > 0.01 {
            // gallop rocks the body; rearing lifts the front end around the hind legs
            let px = sx - d * 6.5, py = by + 2
            let rock = o.gallop ? sin(ph * 2) * 0.075 * min(1, amp) : 0
            c.translate(px, py); c.rotate(-d * (o.rear * 0.44 + rock)); c.translate(-px, -py)
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
        c.RR(sx - 1.5, y - 10.6, 3, 3.2, 1.15, o.skin); c.ell(sx + d * 0.75, y - 9.2, 0.55, 0.42, Col(0xf6f0e0)); c.circ(sx + d * 0.95, y - 9.2, 0.3, Col(0x2a1a10))
        c.R(sx + d * 0.7 - 0.6, y - 10.1, 1.3, 0.3, Col(0x3a2416)); c.R(sx + d * 1.5 - 0.25, y - 9, 0.5, 0.8, o.skin); c.R(sx + d * 0.8 - 0.35, y - 8.2, 0.8, 0.25, Col(0x6a3a28))
        c.R(sx - 2.1, y - 11.1, 4.2, 0.35, rgba(0, 0, 0, 0.2))
        if let v = o.veil { c.RR(sx - 1.6, y - 9, 3.2, 1.7, 0.6, v) }
        c.RR(sx - 2.15, y - 12.7, 4.3, 2.6, 1.2, o.turban); c.ell(sx, y - 12.7, 1.6, 0.8, o.turban)
        let fl = o.fl
        c.poly(o.turban, [sx - d * 2, y - 12, sx - d * (4 + fl * 3), y - 11 + sin(NOW * 9) * fl, sx - d * (3 + fl * 2), y - 8.5, sx - d * 2, y - 9.5])
        if o.jewel { c.circ(sx + d, y - 11.6, 0.55, TEAL); c.circ(sx + d - 0.15, y - 11.75, 0.2, Col(0xd8fff4)) }
        c.restore()
    }

    func drawPlayer() {
        let p = g.player
        let sx = p.x - cam, sp = abs(p.vx), d = p.dir
        let amp = clampD(sp / 70, 0, 1.1)
        let gal = (g.up.contains("racer") || g.B(.pen).level >= 2) && sp > 125
        let trot = !gal && sp > 70
        var co = CamelOpt()
        co.trot = trot; co.gallop = gal; co.saddle = RED; co.kneel = p.kneelK; co.rear = p.rearK
        if p.kneelK <= 0.1 { co.graze = clampD((p.idle - 2.5) / 1.2, 0, 1) * (0.5 + 0.5 * sin(NOW * 0.7)) }
        camel(p.x, d, p.phase, gal ? 1.15 : amp, co) { by in
            self.rider(sx - d, by, d, RiderOpt(robe: Col(0xf6efdc), skin: Col(0xb8804e), turban: GOLD, sash: TEAL, veil: nil, fl: clampD(sp / 110, 0, 1), jewel: true))
            let y = by - 8
            let cv = self.c
            cv.R(sx - d * 3.6 - 0.6, y - 6, 1.4, 6, Col(0x6a4426))
            let tip = self.g.up.contains("fire") ? Col(0xffb04a) : PLA
            for i in 0..<min(3, p.ammo) { cv.R(sx - d * 3.6 - 0.6 + Double(i) * 0.5, y - 7.6, 0.4, 1.8, tip) }
            if self.lit {
                // a lantern on a pole behind the saddle lights the rider's way
                let lx = sx - d * 6.4 + sin(self.NOW * 4 + p.phase) * 0.4, ly = y - 9.5
                cv.seg(sx - d * 5, y - 1, sx - d * 6.2, y - 11, 0.4, Col(0x4a3a2a))
                cv.glow(lx, ly + 1.6, 9, rgba(255, 204, 116, 0.75), rgba(255, 204, 116, 0))
                cv.RR(lx - 1, ly, 2, 3, 0.6, Col(0xffe6a0)); cv.R(lx - 1.3, ly - 0.5, 2.6, 0.6, Col(0x3a2a1a)); cv.R(lx - 1.3, ly + 2.9, 2.6, 0.5, Col(0x3a2a1a))
                self.light(lx, ly + 1.6, 16, 0.5)
            }
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
        // a lantern train coming home along the far bank
        for i in 0..<6 {
            let k = Double(i)
            let px = (W * 0.06 + k * 12 + NOW * 1.2).truncatingRemainder(dividingBy: W * 0.5)
            rideMark(px, hy + 0.6, 0.62, Col(0x4a2e4a), 1, NOW * 3 + k)
            c.glow(px + 3.4, hy - 5, 8, rgba(255, 214, 130, 0.9), rgba(255, 214, 130, 0)); c.circ(px + 3.4, hy - 5, 0.7, Col(0xfff3b8))
            for q in 0..<4 { c.R(px + 2.4 - Double(q) * 0.3 + sin(NOW * 2 + k + Double(q)) * 0.6, hy + 2 + Double(q) * 1.6, 2 + Double(q) * 0.5, 0.5, rgba(255, 214, 130, 0.45 - Double(q) * 0.09)) }
        }
        // feluccas on the far water, and ibis going home
        for i in 0..<3 {
            let n = Double(i)
            let span = W + 120
            let fx = (hashN(n + 700) * span + NOW * (2.5 + n)).truncatingRemainder(dividingBy: span) - 60
            let fy = hy + 5 + n * 5, sc = 0.8 + n * 0.35
            let ink = Col(0x4a2e4a)
            c.poly(ink, [fx - 6.5 * sc, fy - 2, fx - 5 * sc, fy - 1, fx + 6 * sc, fy - 1, fx + 8 * sc, fy - 2.4, fx + 5 * sc, fy + 1, fx - 4 * sc, fy + 1])
            c.poly(rgba(255, 232, 196, 0.9), [fx - 4.5 * sc, fy - 3, fx + 3 * sc, fy - 11 * sc, fx + 5.4 * sc, fy - 2.4])
            c.seg(fx - 4.5 * sc, fy - 3, fx + 3 * sc, fy - 11 * sc, 0.4, ink)
            c.poly(rgba(74, 46, 74, 0.25), [fx - 4 * sc, fy + 1.6, fx + 3 * sc, fy + 6 * sc, fx + 5 * sc, fy + 1.6])
            c.R(fx - 7 * sc, fy + 1.2, 15 * sc, 0.4, rgba(255, 244, 210, 0.45))
        }
        for i in 0..<7 {
            let n = Double(i)
            let bx2 = (NOW * 11).truncatingRemainder(dividingBy: W + 160) - 80 + Double(i % 4) * 9 - Double(i / 4) * 5
            let by2 = H * 0.2 + abs(n - 3) * 3.2 + sin(NOW * 0.5) * 3
            let fl = sin(NOW * 6 + n * 0.7) * 1.6
            c.seg(bx2 - 3, by2 - fl, bx2, by2, 0.5, rgba(60, 36, 60, 0.7)); c.seg(bx2, by2, bx2 + 3, by2 - fl, 0.5, rgba(60, 36, 60, 0.7))
        }
        // the dune you stand on
        var dune: [Double] = [0, H]
        var dx = 0.0
        while dx <= W { dune.append(dx); dune.append(crest(dx)); dx += 4 }
        dune.append(W); dune.append(H)
        c.poly(Col(0xc9925a), dune)
        c.vfill(0, H * 0.66, W, H * 0.34, [(0, rgba(60, 30, 40, 0)), (1, rgba(60, 30, 40, 0.6))])
        for k in 1..<7 {
            let off = Double(k) * 6 + Double(k * k) * 0.8
            dx = 0
            while dx < W {
                let wob = sin(dx * 0.05 + Double(k) * 1.7) * 1.6
                c.seg(dx, crest(dx) + off + wob, dx + 4, crest(dx + 4) + off + sin((dx + 4) * 0.05 + Double(k) * 1.7) * 1.6, 0.4, rgba(90, 50, 40, 0.14))
                dx += 4
            }
        }
        for i in 0..<40 {
            let n = Double(i)
            let px2 = hashN(n + 720) * W
            let py2 = crest(px2) + 3 + hashN(n + 721) * H * 0.2
            if hashN(n + 722) < 0.5 { c.R(px2, py2, 1.2, 0.6, rgba(70, 40, 36, 0.3)); c.R(px2, py2 - 0.4, 1.2, 0.3, rgba(255, 236, 200, 0.3)) } else if sin(NOW * 1.8 + n) > 0.75 { c.R(px2, py2, 0.6, 0.6, rgba(255, 250, 230, 0.7)) }
        }
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
        var q = hh * 0.07
        while q < hh * 0.86 {
            let k = 1 - q / hh
            c.R(x - w * k, hy - q, w * k * 1.25, 0.35, rgba(150, 90, 60, 0.16 * a))
            c.R(x + w * 0.25 * k, hy - q, w * k * 0.75, 0.35, rgba(40, 20, 50, 0.16 * a))
            if hashN(x + q) > 0.55 {
                let px = x - w * k + hashN(x + q * 2) * w * k * 1.1
                c.R(px, hy - q - 1.2, 1.8 + hashN(x + q * 3) * 2, 0.9, rgba(120, 66, 60, 0.22 * a))
            }
            q += hh * 0.075
        }
        c.seg(x, hy - hh, x + w * 0.25, hy, 0.5, rgba(255, 236, 200, 0.3 * a))
    }
}
