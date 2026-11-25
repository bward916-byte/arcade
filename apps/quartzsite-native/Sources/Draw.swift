import CoreGraphics
import Foundation

/// Paints the whole frame with CoreGraphics: sky, ridges, cactus, the camp strip, rigs, people, rings and the HUD.
final class Renderer {
    let g: Game
    let c: Canvas
    var W = 0.0
    var H = 0.0
    var GY = 0.0
    var cam = 0.0
    var NOW = 0.0
    var dark = 0.0
    var lights: [(Double, Double, Double)] = []

    let SKY: [(Double, Col, Col)] = [
        (0, Col(0x6f6aa8), Col(0xf7b98c)), (0.08, Col(0x4aa6dc), Col(0xf3e2c0)), (0.5, Col(0x3f9fdc), Col(0xf5e6c6)),
        (0.6, Col(0x5a4a96), Col(0xf89a4a)), (0.66, Col(0x3a2466), Col(0xea5a3a)), (0.73, Col(0x080c26), Col(0x262456)),
        (0.93, Col(0x080c26), Col(0x262456)), (1.001, Col(0x6f6aa8), Col(0xf7b98c))
    ]
    let SAG = Col(0x4f7a4a)
    let SAGD = Col(0x355a36)

    init(game: Game, canvas: Canvas) {
        g = game
        c = canvas
    }

    // MARK: frame

    func draw() {
        W = g.W; H = g.H; GY = g.GY; NOW = g.time
        g.texts.removeAll(keepingCapacity: true)
        g.hits.removeAll(keepingCapacity: true)
        lights.removeAll(keepingCapacity: true)
        if g.showRigs { rigSheet(); return }
        switch g.phase {
        case .title:
            cam = (g.WORLD - W) * (0.5 - 0.5 * cos(NOW * 0.045))
            scene(0.615)
            titleOverlay()
        case .pick:
            cam = 560
            scene(0.3)
            pickOverlay()
        case .play:
            cam = g.cam
            scene(g.dayT)
            hud()
        }
    }

    /// Every rig side by side with a person, for checking shapes and scale.
    private func rigSheet() {
        dark = 0
        c.vfill(0, 0, W, H, [(0, Col(0x4aa6dc)), (1, Col(0xf3e2c0))])
        let k = 0.86
        c.save()
        c.scale(k, k)
        let y1 = H * 0.5 / k, y2 = H * 0.97 / k
        c.R(0, y1, W / k, 3, Col(0xcaa878)); c.R(0, y2, W / k, 3, Col(0xcaa878))
        let l = g.safeL / k + 10
        rig(.tent, l + 16, y1, 0, 1)
        person(l + 44, y1, 0, 1, 0, false)
        rig(.minivan, l + 86, y1, 1, 1)
        rig(.van, l + 158, y1, 1, 1)
        rig(.classB, l + 236, y1, 2, 1)
        person(l + 284, y1, 2, -1, 0, false)
        rig(.skoolie, l + 52, y2, 2, 1)
        person(l + 112, y2, 1, 1, 0, false)
        rig(.classC, l + 170, y2, 2, 1)
        rig(.classA, l + 290, y2, 2, 1)
        c.restore()
    }

    private func skyAt(_ t: Double) -> (Col, Col) {
        var i = 0
        while i + 2 < SKY.count && t >= SKY[i + 1].0 { i += 1 }
        let a = SKY[i], b = SKY[i + 1]
        let f = clampD((t - a.0) / max(0.0001, b.0 - a.0), 0, 1)
        return (Col.mix(a.1, b.1, f), Col.mix(a.2, b.2, f))
    }
    private func darkness(_ t: Double) -> Double {
        if t < 0.6 { return 0 }
        if t < 0.73 { return (t - 0.6) / 0.13 }
        if t < 0.93 { return 1 }
        return clampD(1 - (t - 0.93) / 0.07, 0, 1)
    }

    private func scene(_ t: Double) {
        dark = darkness(t)
        let sk = skyAt(t)
        c.vfill(0, 0, W, GY + 1, [(0, sk.0), (1, sk.1)])

        // stars
        if dark > 0.3 {
            for i in 0..<70 {
                let n = Double(i)
                let tw = 0.6 + 0.4 * sin(NOW * (1 + hashN(n + 7) * 2) + n)
                c.R(hashN(n) * W, hashN(n + 200) * GY * 0.8, 0.8, 0.8, Col(0xffffff, (dark - 0.3) * 1.2 * tw * (0.4 + 0.6 * hashN(n + 400))))
            }
        }
        // sun by day, moon by night
        if t < 0.7 {
            let f = t / 0.68
            let sx = W * (0.08 + 0.84 * f)
            let sy = GY - sin(PI * f) * GY * 0.82 + 4
            c.glow(sx, sy, 46, Col(0xfff0c0, 0.55), Col(0xfff0c0, 0))
            c.circ(sx, sy, 6.5, Col(0xfff6dc))
        } else {
            let mx = W * 0.72, my = GY * 0.24
            c.glow(mx, my, 26, Col(0xdfe6ff, 0.3), Col(0xdfe6ff, 0))
            c.circ(mx, my, 5, Col(0xeef0fa))
            c.circ(mx + 2, my - 1, 4.4, sk.0)
        }

        // the ranges: far and hazy, then nearer and darker
        let haze = sk.1
        ridge(0.06, 1.3, GY - 6, 62, Col.mix(Col(0x6a5a80), haze, 0.55).shade(1 - dark * 0.55))
        ridge(0.14, 4.1, GY - 2, 40, Col.mix(Col(0x7a4f48), haze, 0.3).shade(1 - dark * 0.6))
        ridge(0.3, 8.7, GY + 1, 17, Col.mix(Col(0x8a5a3e), haze, 0.12).shade(1 - dark * 0.65))

        // a far stand of saguaros on the low hills
        var n = floor((cam * 0.3 - 20) / 46)
        while n * 46 < cam * 0.3 + W + 20 {
            if hashN(n + 900) < 0.6 {
                let wx = n * 46 + hashN(n + 910) * 30
                let sx = wx - cam * 0.3
                let base = ridgeY(sx + cam * 0.3, 8.7, GY + 1, 17) + 2
                saguaro(sx, base, 9 + hashN(n + 920) * 7, n + 930, Col.mix(Col(0x4a5a44), haze, 0.25).shade(1 - dark * 0.6), false)
            }
            n += 1
        }

        // the desert floor and the dirt road
        c.vfill(0, GY, W, H - GY, [(0, Col(0xdcbc8c)), (1, Col(0xb48a5a))])
        c.R(0, GY, W, 1, Col(0xf0d8ac, 0.7))
        c.R(0, GY + 7, W, 9, Col(0xe6cba0, 0.55))
        c.R(0, GY + 10, W, 0.8, Col(0xa98558, 0.5))
        c.R(0, GY + 13, W, 0.8, Col(0xa98558, 0.4))
        n = floor(cam / 23) - 1
        while n * 23 < cam + W + 23 {
            let sx = n * 23 + hashN(n + 50) * 20 - cam
            let sy = GY + 3 + hashN(n + 60) * (H - GY - 6)
            c.ell(sx, sy, 1 + hashN(n + 70) * 1.6, 0.7 + hashN(n + 80) * 0.6, Col(0x8f6c46, 0.55))
            n += 1
        }

        // cactus and brush along the strip
        n = floor((cam - 80) / 64)
        while n * 64 < cam + W + 80 {
            let wx = n * 64 + hashN(n + 3) * 44
            let sx = wx - cam
            let k = hashN(n + 31)
            if k < 0.36 { saguaro(sx, GY + 1, 26 + hashN(n + 5) * 20, n, SAG, true) }
            else if k < 0.6 { cholla(sx, GY + 1, 0.8 + hashN(n + 6) * 0.5, n) }
            else if k < 0.8 { creosote(sx, GY + 1, n) }
            else { ocotillo(sx, GY + 1, n) }
            n += 1
        }

        if g.phase == .title {
            // a rig rolling in at sunset, dust behind it
            let rx = (NOW * 24).truncatingRemainder(dividingBy: W + 160) - 80
            for i in 0..<5 {
                let d = Double(i)
                c.circ(rx - 50 - d * 9, GY + 9 - d * 1.2, 3 + d * 1.6, Col(0xe8d0a8, 0.3 - d * 0.05))
            }
            rig(.skoolie, rx, GY + 12, 2, 1)
        } else {
            for (i, sp) in g.spots.enumerated() { spot(i, sp) }
            endSigns()
            // your rig, glowing when you are close enough to tap it
            if g.phase == .play {
                let rx = g.rigX - cam
                let def = RIGS[g.rig.rawValue]
                if g.nearRig && !g.inRig {
                    let pulse = 0.3 + 0.14 * sin(NOW * 4)
                    c.glow(rx, GY - def.high * 0.45, def.len * 0.85, Col(0xffe9a0, pulse), Col(0xffe9a0, 0))
                }
                rig(g.rig, rx, GY + (g.inRig ? 12 : 0), g.panels, g.rigFace)
                if g.nearRig {
                    g.hits.append(Hit(id: 50, x: rx - def.len / 2 - 8, y: GY - def.high - 12, w: def.len + 16, h: def.high + 30))
                    if !g.inRig { g.text(g.rig == .tent ? "Your tent" : "Tap to drive", rx, GY - def.high - 8, 5.5, CREAM) }
                }
                if !g.inRig { person(g.px - cam, GY + 6, g.look, g.face, g.walk, abs(g.vx) > 4) }
            }
        }

        // big cactus close to the camera
        n = floor((cam * 1.5 - 120) / 210)
        while n * 210 < cam * 1.5 + W + 120 {
            let sx = n * 210 + hashN(n + 400) * 120 - cam * 1.5
            let shadeC = Col(0x2a3a2a).shade(1 - dark * 0.5)
            if hashN(n + 410) < 0.5 {
                if g.phase == .title { saguaro(sx, H + 14, 120 + hashN(n + 420) * 40, n + 430, shadeC, false) }
            } else {
                c.circ(sx, H + 4, 11, shadeC)
                c.circ(sx + 12, H + 6, 9, shadeC)
                c.circ(sx - 10, H + 7, 8, shadeC)
            }
            n += 1
        }

        // dusk colour, then night, then the fires and lamps
        let dusk = clampD(1 - abs(t - 0.62) / 0.08, 0, 1)
        if dusk > 0 { c.R(0, 0, W, H, Col(0xff7a30, 0.1 * dusk)) }
        if dark > 0 { c.R(0, 0, W, H, Col(0x0a1030, 0.56 * dark)) }
        if dark > 0.15 {
            for l in lights {
                c.glow(l.0, l.1, l.2, Col(0xffb050, 0.5 * dark), Col(0xffb050, 0))
            }
        }

        // floating notes and the ring
        for f in g.floaters {
            g.text(f.s, f.x - cam, f.y, 6.5, f.col.alpha(clampD(1.8 - f.t, 0, 1)), bold: true)
        }
        if g.phase == .play && g.active >= 0 { ring(g.active) }
    }

    private func ridgeY(_ wx: Double, _ seed: Double, _ base: Double, _ amp: Double) -> Double {
        let a = sin(wx * 0.011 + seed) * 0.5
        let b = sin(wx * 0.027 + seed * 2.3) * 0.3
        let d = sin(wx * 0.063 + seed * 5.1) * 0.2
        return base - amp * (0.5 + 0.5 * (a + b + d))
    }
    private func ridge(_ par: Double, _ seed: Double, _ base: Double, _ amp: Double, _ col: Col) {
        var p: [Double] = [0, GY + 1]
        var x = 0.0
        while x <= W + 5 {
            p.append(x)
            p.append(ridgeY(x + cam * par, seed, base, amp))
            x += 5
        }
        p.append(W + 5)
        p.append(GY + 1)
        c.poly(col, p)
    }

    // MARK: plants

    private func saguaro(_ x: Double, _ base: Double, _ h: Double, _ seed: Double, _ col: Col, _ detail: Bool) {
        if x < -40 || x > W + 40 { return }
        let w = max(1.6, h * 0.17)
        let body = detail ? col.shade(1 - dark * 0.35) : col
        // arms first, so the trunk overlaps their roots
        let arms = Int(hashN(seed + 11) * 3.4)
        for i in 0..<arms {
            let n = seed + Double(i) * 17
            let side = i % 2 == 0 ? -1.0 : 1.0
            let ay = base - h * (0.34 + hashN(n + 2) * 0.26)
            let reach = w * (1.5 + hashN(n + 3) * 0.9)
            let ah = h * (0.2 + hashN(n + 4) * 0.22)
            let aw = w * 0.72
            let ax = x + side * reach
            c.RR(min(x, ax) - aw / 2, ay - aw / 2, abs(ax - x) + aw, aw, aw / 2, body)
            c.RR(ax - aw / 2, ay - ah, aw, ah + aw / 2, aw / 2, body)
            if detail { c.R(ax - aw / 2 + 0.4, ay - ah + aw / 2, 0.7, ah - aw / 2, Col(0xcfe0a8, 0.35)) }
        }
        c.RR(x - w / 2, base - h, w, h + 1, w / 2, body)
        if detail {
            // ribs, a lit edge and the spines catching the light
            c.R(x - w * 0.18, base - h + w / 2, 0.6, h - w / 2, SAGD.alpha(0.6))
            c.R(x + w * 0.16, base - h + w / 2, 0.6, h - w / 2, SAGD.alpha(0.6))
            c.R(x - w / 2 + 0.4, base - h + w / 2, 0.8, h - w / 2, Col(0xdcecb0, 0.4))
        }
    }

    /// Teddy-bear cholla: a dark trunk under a crown of pale, glowing joints.
    private func cholla(_ x: Double, _ base: Double, _ s: Double, _ seed: Double) {
        if x < -30 || x > W + 30 { return }
        let trunk = Col(0x4a3524).shade(1 - dark * 0.3)
        c.roundCaps(true)
        c.seg(x, base, x, base - 9 * s, 2.2 * s, trunk)
        c.seg(x, base - 6 * s, x - 4 * s, base - 11 * s, 1.6 * s, trunk)
        c.seg(x, base - 7 * s, x + 4 * s, base - 12 * s, 1.6 * s, trunk)
        c.roundCaps(false)
        let lit = clampD(1 - dark, 0.25, 1)
        for i in 0..<9 {
            let n = seed + Double(i) * 7.3
            let jx = x + (hashN(n + 1) - 0.5) * 14 * s
            let jy = base - (9 + hashN(n + 2) * 9) * s
            let r = (1.8 + hashN(n + 3) * 1.4) * s
            c.circ(jx, jy, r + 1.3, Col(0xfff0b4, 0.2 * lit))
            c.circ(jx, jy, r, Col.mix(Col(0x9aa86a), Col(0xe2d59a), hashN(n + 4)).shade(0.55 + 0.45 * lit))
        }
    }
    private func creosote(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -20 || x > W + 20 { return }
        let col = Col(0x5c6b3a).shade(1 - dark * 0.35)
        for i in 0..<6 {
            let n = seed + Double(i) * 3.1
            c.circ(x + (hashN(n) - 0.5) * 16, base - 3 - hashN(n + 1) * 7, 2.6 + hashN(n + 2) * 2, i % 2 == 0 ? col : col.shade(1.18))
        }
    }
    private func ocotillo(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -20 || x > W + 20 { return }
        let col = Col(0x6a7a4a).shade(1 - dark * 0.35)
        for i in 0..<7 {
            let n = seed + Double(i) * 5.7
            let lean = (Double(i) - 3) * 3.2 + (hashN(n) - 0.5) * 3
            let h = 20 + hashN(n + 1) * 14
            c.curve(x, base, x + lean * 0.3, base - h * 0.6, x + lean, base - h, 0.9, col)
            if hashN(n + 2) < 0.4 { c.circ(x + lean, base - h, 1.1, Col(0xd9482e)) }
        }
    }

    // MARK: rigs and people

    /// A rig centred on `cx` with its wheels on `base`, drawn to the same scale as the people
    /// (about 3.5 game pixels to the foot). `dir` 1 faces right; `s` shrinks it for menu cards.
    func rig(_ kind: RigKind, _ cx: Double, _ base: Double, _ panels: Int, _ dir: Double, _ s: Double = 1) {
        if cx < -130 || cx > W + 130 { return }
        c.save()
        c.translate(cx, base)
        c.scale(dir * s, s)
        c.ell(0, 0.6, RIGS[kind.rawValue].len * 0.5, 2.2, Col(0x000000, 0.22))
        var roof = 0.0
        var px0 = 0.0
        let lamp = Col(0xfff2c0), tail = Col(0xc8281e), trim = Col(0x24211f)
        switch kind {
        case .tent:
            c.poly(Col(0xd9772e), [-13, 0, 0, -14, 13, 0])
            c.poly(Col(0xb55a1e), [0, -14, 13, 0, 3, 0])
            c.poly(Col(0x3a2416), [-4, 0, -1, -9, 2, 0])
            c.seg(-13, 0, -17, 1, 0.5, Col(0xeeeeee, 0.7))
            c.seg(13, 0, 17, 1, 0.5, Col(0xeeeeee, 0.7))

        case .minivan:
            // 17 ft long, under 6 ft tall: one box, a long raked windshield running into a short sloped hood
            let col = Col(0x8fa3b0)
            let body: [Double] = [-29.5, -4, -29.3, -14.5, -27, -20, 6, -20, 17, -12.6, 27.5, -10.4, 29.5, -7, 29.5, -3.6]
            c.poly(col, body)
            c.poly(GLASS, [-25.4, -18.6, 5.2, -18.6, 14.4, -12.6, -26.4, -12.6])
            c.R(-16, -18.6, 1.1, 6, col); c.R(-3.4, -18.6, 1.3, 6, col)
            c.R(-27, -20.6, 30, 0.7, trim); c.R(-22, -21.4, 0.7, 1, trim); c.R(-2, -21.4, 0.7, 1, trim)
            c.R(-29.4, -8.2, 58.6, 0.6, col.shade(0.78))
            c.R(-29.5, -5, 59, 1.6, col.shade(0.6))
            c.R(-16, -12.4, 0.5, 7.4, col.shade(0.8)); c.R(-3, -12.4, 0.5, 7.4, col.shade(0.8)); c.R(10.5, -12.4, 0.5, 7.4, col.shade(0.8))
            c.R(-14, -11, 11, 0.6, col.shade(0.8))
            c.RR(27.4, -9.6, 2.2, 2, 0.8, lamp); c.RR(-29.6, -13.5, 1.4, 4, 0.5, tail)
            wheel(-18.5, 3.8); wheel(17.5, 3.8)
            roof = -20.6; px0 = -24

        case .van:
            // an older full-size van, 18 ft by 7 ft: tall slab sides, a stubby hood, barn doors at the back
            let col = Col(0xe6e0d2)
            let body: [Double] = [-31.5, -5, -31.5, -22, -29.5, -24, 12, -24, 20.5, -15, 30, -13.4, 31.5, -10.5, 31.5, -4.4]
            c.poly(col, body)
            c.poly(GLASS, [2.5, -22.2, 11.4, -22.2, 17.6, -15.4, 2.5, -15.4])
            c.RR(-12.5, -22, 11, 6.4, 1, GLASS)
            c.RR(-27.5, -22, 8, 6.4, 1, GLASS)
            c.R(-31.5, -12.6, 62, 1.8, Col(0x3f8f8a)); c.R(-31.5, -10.4, 62, 0.8, Col(0xb5651d))
            c.R(1.4, -22.5, 0.5, 18, col.shade(0.78)); c.R(-14.6, -22.5, 0.5, 18, col.shade(0.78))
            c.R(-31.5, -6, 63, 1.8, trim)
            c.RR(-22, -26, 7, 2.2, 0.8, Col(0xf4f1ea)); c.R(-8, -25, 16, 0.7, trim); c.R(-6, -25, 0.7, 1.2, trim); c.R(6, -25, 0.7, 1.2, trim)
            c.RR(29.6, -12.6, 2, 2.4, 0.6, lamp); c.RR(-31.7, -16, 1.3, 5, 0.4, tail)
            c.RR(30.4, -6.6, 2.2, 2.6, 0.6, Col(0xb8b8b4))
            wheel(-19, 4.2); wheel(20, 4.2)
            roof = -24; px0 = -4

        case .skoolie:
            // a conventional "dog-nose" school bus, seven windows, about 28 ft by 10 ft: body, cowl, long hood
            let col = Col(0x3f8f8a)
            c.RR(-48, -35, 75, 12, 4.5, Col(0xf1ede2))
            c.R(-48, -29, 75, 23, col)
            c.R(-48, -8, 75, 2.4, trim)
            // hood and fender
            c.poly(col.shade(0.94), [26, -20, 43, -17, 47, -14.4, 47.6, -6, 26, -6])
            c.R(26, -20.4, 17, 0.7, col.shade(0.7))
            c.R(45.8, -14, 1.6, 6, Col(0x2a2a2a))
            c.RR(46.2, -7.8, 2.6, 3, 0.6, trim)
            c.RR(44.8, -12.6, 1.6, 2.2, 0.6, lamp)
            // windshield, entry door, seven sash windows
            c.poly(GLASS, [22.2, -31, 26, -30, 26.8, -20.6, 22.2, -20.6])
            c.R(14.6, -30.4, 6.2, 22.6, GLASS); c.R(17.5, -30.4, 0.6, 22.6, col.shade(0.7)); c.R(14.6, -19.6, 6.2, 0.6, col.shade(0.7))
            for i in 0..<7 {
                let wx = -45.4 + Double(i) * 8.4
                c.RR(wx, -30.2, 6.6, 7.2, 0.8, GLASS)
                c.R(wx, -26.8, 6.6, 0.5, Col(0x8a9aa0, 0.7))
            }
            c.R(-48, -21.6, 62, 0.9, trim); c.R(-48, -16.6, 62, 0.9, trim); c.R(-48, -12, 62, 0.9, trim)
            c.R(-48, -19.6, 62, 2, Col(0xf2c14e))
            c.RR(-49.4, -8.4, 2, 3, 0.5, trim); c.RR(-48.6, -24, 1.2, 4, 0.4, tail)
            // what makes it a skoolie: roof deck with a rail, stovepipe, mirror on a long arm
            c.R(-44, -37.2, 26, 1.6, Col(0x8a6238))
            c.R(-44, -40.6, 26, 0.7, Col(0x8a6238))
            c.R(-44, -40.6, 0.8, 3.6, Col(0x8a6238)); c.R(-31, -40.6, 0.8, 3.6, Col(0x8a6238)); c.R(-18.8, -40.6, 0.8, 3.6, Col(0x8a6238))
            c.R(6, -41, 1.6, 6.4, Col(0x444444)); c.R(5.4, -41.8, 2.8, 1, Col(0x333333))
            c.seg(26.6, -27, 31, -25.4, 0.6, trim); c.RR(30.4, -28, 1.6, 4.4, 0.5, trim)
            wheel(-27, 5.4); wheel(36, 5.4)
            roof = -35.4; px0 = -14

        case .classB:
            // a high-roof camper van (Sprinter-sized, about 20 ft by 9 ft): tall roof, short dropped hood
            let col = Col(0xdcdfe2)
            let body: [Double] = [-35, -5, -35, -29, -33, -32, 14, -32, 19.5, -29, 27, -17.4, 33.5, -14.2, 35, -10.4, 35, -4.4]
            c.poly(col, body)
            c.poly(GLASS, [15.2, -27, 19.4, -27, 25.6, -17.6, 15.2, -17.6])
            c.RR(0.5, -27, 12, 8, 1.2, GLASS)
            c.RR(-29, -27, 15, 8, 1.2, GLASS)
            c.R(-35, -9.4, 70, 4.6, Col(0x3a3d40))
            c.curve(-34, -12.5, 0, -15, 26, -15.5, 1.6, Col(0x3a6ea5))
            c.R(14.2, -28, 0.5, 23, col.shade(0.75)); c.R(-0.6, -28, 0.5, 23, col.shade(0.75))
            c.R(-31, -31.6, 44, 2, Col(0x2f3236))
            c.RR(-20, -35, 12, 3.2, 1.2, Col(0xf4f4f2)); c.RR(2, -33.6, 5, 1.8, 0.6, Col(0xf4f4f2))
            c.RR(32.8, -13.6, 2.2, 2.6, 0.7, lamp); c.RR(-35.2, -24, 1.2, 9, 0.4, tail)
            wheel(-22, 4.3); wheel(21, 4.3)
            roof = -32.4; px0 = -6

        case .classC:
            // a 25 ft Class C: van cab up front, the house box behind it, and the bunk hanging over the cab
            let col = Col(0xf0ece2)
            // cab
            c.poly(col.shade(0.95), [18, -22, 27, -22, 35, -14.2, 42, -12.6, 43.5, -9.4, 43.5, -4.4, 18, -4.4])
            c.poly(GLASS, [22.4, -20.8, 26.6, -20.8, 32.6, -14.6, 22.4, -14.6])
            c.RR(41.4, -12, 2, 2.4, 0.6, lamp)
            c.RR(42, -6.6, 2.4, 2.6, 0.6, Col(0xb8b8b4))
            // house, with the tail cut up for clearance, and the cab-over
            c.poly(col, [-43.5, -11, -38, -6, 22, -6, 22, -38, -41, -38, -43.5, -35.5])
            c.poly(col, [21, -38, 30, -38, 34.4, -34, 34.4, -25.4, 21, -23])
            c.RR(24.6, -34.2, 7.4, 5, 1, GLASS)
            c.RR(-35, -29, 15, 8.4, 1, GLASS)
            c.RR(-14, -29, 12, 8.4, 1, GLASS)
            c.R(3.6, -28, 8.4, 22, col.shade(0.9)); c.RR(5.2, -26.4, 5, 5, 0.8, GLASS); c.R(4.6, -5.6, 6.4, 1.4, trim)
            c.curve(-43, -15, -8, -20, 33, -27, 2, Col(0xb5651d))
            c.curve(-43, -12, -8, -16.4, 33, -24.4, 0.9, Col(0x7a4a2a))
            c.R(-41, -10.4, 44, 0.5, col.shade(0.75)); c.R(-30, -10.4, 0.5, 4.4, col.shade(0.75)); c.R(-8, -10.4, 0.5, 4.4, col.shade(0.75))
            c.R(-32, -37.4, 34, 2, Col(0x8a8f96))
            c.RR(-22, -41.2, 12, 3.2, 1.2, Col(0xf7f7f4)); c.RR(4, -39.8, 5, 1.8, 0.6, Col(0xf7f7f4))
            c.R(-42.6, -34, 0.6, 24, Col(0xb8b8b4)); c.R(-41.2, -34, 0.6, 24, Col(0xb8b8b4))
            c.RR(-43.8, -20, 1.2, 6, 0.4, tail)
            wheel(-20, 4.5); wheel(33, 4.5)
            roof = -38.4; px0 = -8

        case .classA:
            // a 34 ft Class A: one tall bus-shaped body with a flat face, a huge windshield and a long rear overhang
            let col = Col(0xe6dfd0)
            let body: [Double] = [-59, -8, -59, -40, -56, -43, 52, -43, 57, -40.4, 59, -24, 59, -6.4, 54, -5, -52, -5]
            c.poly(col, body)
            c.poly(GLASS, [53.4, -36.4, 57.4, -35.2, 58.6, -21.6, 53.4, -21.6])
            c.RR(42, -34.4, 10, 12.4, 1.2, GLASS)
            c.RR(-48, -33.4, 18, 10, 1.2, GLASS)
            c.RR(-22, -33.4, 16, 10, 1.2, GLASS)
            c.RR(2, -33.4, 14, 10, 1.2, GLASS)
            c.R(28.4, -34.4, 9, 28, col.shade(0.9)); c.RR(30.2, -32.4, 5.4, 8, 0.8, GLASS); c.R(29.4, -6, 7, 1.6, trim)
            // full-body paint and the basement doors
            c.curve(-58, -12, -10, -17, 40, -30, 3, Col(0x7a4a2a))
            c.curve(-58, -16.4, -10, -21, 40, -34, 1.2, GOLD)
            c.curve(-58, -8.6, -10, -12, 58, -18, 1.4, Col(0x3a3230))
            c.R(-52, -16, 78, 0.5, col.shade(0.72))
            for i in 0..<5 { c.R(-52 + Double(i) * 16, -16, 0.5, 10.4, col.shade(0.72)) }
            c.R(-50, -42.4, 74, 2.2, Col(0x9a4a3a))
            c.RR(-34, -46.6, 13, 3.6, 1.2, Col(0xf7f7f4)); c.RR(8, -46.6, 13, 3.6, 1.2, Col(0xf7f7f4))
            c.dome(-8, -43, 3.2, Col(0xf7f7f4))
            c.seg(58.4, -33, 62.4, -31, 0.7, trim); c.RR(61.6, -33.4, 1.8, 5.4, 0.6, trim)
            c.RR(57, -12.4, 2.2, 3, 0.7, lamp); c.RR(-59.3, -26, 1.3, 10, 0.4, tail)
            c.R(54, -7, 5.4, 2, trim)
            wheel(-30, 5.6); wheel(40, 5.6)
            roof = -43.4; px0 = -52
        }
        if kind != .tent {
            for i in 0..<panels {
                let x = px0 + Double(i) * 12
                c.RR(x, roof - 1.6, 11, 1.8, 0.4, Col(0x1c2f6b))
                c.R(x + 0.5, roof - 1.6, 10, 0.5, Col(0x7fa0e0, 0.8))
            }
        }
        c.restore()
        if dark > 0.3 && kind != .tent { lights.append((cx, base - 12 * s, 22 * s)) }
    }
    private func wheel(_ x: Double, _ r: Double) {
        c.circ(x, -r, r + 1.3, Col(0x15120f))
        c.circ(x, -r, r, TIRE)
        c.circ(x, -r, r * 0.5, HUB)
        c.circ(x, -r, r * 0.16, TIRE)
    }

    func person(_ x: Double, _ base: Double, _ look: Int, _ face: Double, _ ph: Double, _ moving: Bool) {
        if x < -20 || x > W + 20 { return }
        let k = ((look % 4) + 4) % 4
        let skin = SKINS[k], shirt = SHIRTS[k], pants = PANTS[k]
        let sw = moving ? sin(ph) * 3.2 : 0.0
        let hip = base - 7
        let bob = moving ? abs(sin(ph)) * 0.5 : sin(NOW * 2 + Double(look)) * 0.2
        c.ell(x, base + 0.4, 4, 1, Col(0x000000, 0.2))
        c.roundCaps(true)
        c.seg(x, hip, x - sw, base, 2.2, pants.shade(0.8))
        c.seg(x, hip, x + sw, base, 2.2, pants)
        c.RR(x - 2.7, hip - 8 - bob, 5.4, 9, 2, shirt)
        c.seg(x - face * 0.4, hip - 6.5 - bob, x - sw * 0.7, hip - 0.8, 1.6, shirt.shade(0.85))
        c.roundCaps(false)
        let hy = hip - 10.6 - bob
        c.circ(x + face * 0.4, hy, 2.7, skin)
        c.R(x + face * 1.5, hy - 0.5, 0.7, 0.7, Col(0x2a1c14))
        switch k {
        case 0:     // straw hat
            c.dome(x + face * 0.3, hy - 1, 2.6, Col(0xd9c07a))
            c.ell(x + face * 0.3, hy - 1, 4.6, 0.9, Col(0xc9ae62))
        case 1:     // beanie
            c.dome(x + face * 0.3, hy - 0.4, 2.9, Col(0x8a3a5a))
        case 2:     // ball cap
            c.dome(x + face * 0.3, hy - 0.8, 2.8, Col(0x2f4f7a))
            c.R(face > 0 ? x + 2 : x - 5.4, hy - 1.2, 3.4, 0.9, Col(0x2f4f7a))
        default:    // grey hair and a wide sun hat
            c.dome(x + face * 0.2, hy - 0.2, 2.9, Col(0xd8d8d4))
            c.ell(x + face * 0.3, hy - 1.8, 5.2, 0.9, Col(0xefe6cf))
            c.dome(x + face * 0.3, hy - 1.8, 2.3, Col(0xefe6cf))
        }
    }

    private func fire(_ x: Double, _ base: Double) {
        c.ell(x, base, 6, 1.6, Col(0x4a4038))
        for i in 0..<5 { c.circ(x - 5 + Double(i) * 2.5, base + (i % 2 == 0 ? 0.6 : -0.4), 1.2, Col(0x7a7068)) }
        for i in 0..<3 {
            let d = Double(i)
            let fl = sin(NOW * (9 + d * 3) + d * 2) * 1.2
            let fh = 7 + sin(NOW * (7 + d * 2) + d) * 2 - d * 1.4
            c.poly(i == 0 ? Col(0xe2562a) : (i == 1 ? Col(0xf2982e) : Col(0xffe07a)), [x - 3 + d, base - 0.5, x + fl, base - fh, x + 3 - d, base - 0.5])
        }
        lights.append((x, base - 5, 46 + sin(NOW * 8) * 3))
    }

    private func canopy(_ x: Double, _ half: Double, _ top: Col, _ trim: Col) {
        c.seg(x - half + 3, GY, x - half + 3, GY - 27, 1, Col(0xdddddd))
        c.seg(x + half - 3, GY, x + half - 3, GY - 27, 1, Col(0xdddddd))
        c.poly(top, [x - half, GY - 27, x - half + 9, GY - 37, x + half - 9, GY - 37, x + half, GY - 27])
        c.R(x - half, GY - 27, half * 2, 3, trim)
    }
    private func gem(_ x: Double, _ y: Double, _ r: Double, _ col: Col) {
        c.poly(col, [x - r, y, x - r * 0.4, y - r * 1.3, x + r * 0.5, y - r * 1.1, x + r, y])
        c.poly(col.shade(1.35), [x - r * 0.4, y - r * 1.3, x, y - r * 0.4, x - r, y])
    }
    private func skull(_ x: Double, _ y: Double, _ s: Double) {
        let bone = Col(0xefe6d2)
        c.curve(x - 2 * s, y - 4 * s, x - 6 * s, y - 6 * s, x - 6.5 * s, y - 9 * s, 0.9 * s, bone)
        c.curve(x + 2 * s, y - 4 * s, x + 6 * s, y - 6 * s, x + 6.5 * s, y - 9 * s, 0.9 * s, bone)
        c.poly(bone, [x - 2.6 * s, y - 5 * s, x + 2.6 * s, y - 5 * s, x + 1.2 * s, y, x - 1.2 * s, y])
        c.circ(x - 1.2 * s, y - 3.6 * s, 0.7 * s, Col(0x2a1c14))
        c.circ(x + 1.2 * s, y - 3.6 * s, 0.7 * s, Col(0x2a1c14))
    }

    // MARK: the places along the strip

    private func spot(_ i: Int, _ sp: Spot) {
        let x = sp.x - cam
        if x < -130 || x > W + 130 { return }
        let near = g.phase == .play && g.active == i
        if near {
            let pulse = 0.28 + 0.12 * sin(NOW * 4)
            c.glow(x, GY - 16, 62, Col(0xffe9a0, pulse), Col(0xffe9a0, 0))
        }
        var top = 44.0
        switch sp.kind {
        case .wash:
            let wood = Col(0x5a4230)
            c.roundCaps(true)
            c.seg(x - 20, GY, x - 22, GY - 22, 2.4, wood)
            c.seg(x - 22, GY - 14, x - 32, GY - 26, 1.5, wood)
            c.seg(x - 22, GY - 18, x - 12, GY - 30, 1.5, wood)
            c.seg(x - 21, GY - 22, x - 24, GY - 33, 1.2, wood)
            for j in 0..<5 {
                let d = Double(j)
                c.seg(x - 4 + d * 1.5, GY - 1 - d * 1.6, x + 16 - d * 1.5, GY - 2 - d * 1.6, 1.8, j % 2 == 0 ? Col(0x7a5a3a) : Col(0x8f6c46))
            }
            c.roundCaps(false)
            top = 38
        case .camp:
            fire(x + 4, GY + 3)
            c.poly(Col(0x3f6a8a), [x + 16, GY + 2, x + 17, GY - 8, x + 19, GY - 8, x + 20, GY - 2, x + 25, GY - 2, x + 25, GY + 2])
            top = 30
        case .fire:
            rig(.minivan, x - 62, GY, 0, -1)
            rig(.van, x + 70, GY, 1, 1)
            fire(x, GY + 3)
            person(x - 16, GY + 3, 1, 1, 0, false)
            person(x + 15, GY + 3, 3, -1, 0, false)
            person(x + 24, GY + 2, 2, -1, 0, false)
            top = 34
        case .grocery:
            canopy(x, 30, Col(0xf4f1ea), Col(0x4f9a5a))
            person(x + 2, GY - 1, 0, -1, 0, false)
            c.R(x - 24, GY - 10, 48, 2, Col(0x8a6a44))
            c.R(x - 22, GY - 8, 1.2, 8, Col(0x6a4e30)); c.R(x + 21, GY - 8, 1.2, 8, Col(0x6a4e30))
            let fruit: [Col] = [Col(0xd9412e), Col(0xf29a2e), Col(0x6aa84a), Col(0xf2d24e)]
            for j in 0..<4 {
                let bx = x - 22 + Double(j) * 11.5
                c.RR(bx, GY - 16, 10, 6, 1, Col(0xa98558))
                for q in 0..<3 { c.circ(bx + 2 + Double(q) * 3, GY - 16.5, 1.6, fruit[j]) }
            }
            top = 46
        case .tools:
            let wall = Col(0xb9b3a6)
            c.R(x - 42, GY - 38, 84, 38, wall)
            var lx = x - 42.0
            while lx < x + 42 { c.R(lx, GY - 38, 0.7, 38, wall.shade(0.86)); lx += 4.5 }
            c.poly(Col(0x7a8088), [x - 45, GY - 38, x - 40, GY - 44, x + 40, GY - 44, x + 45, GY - 38])
            c.R(x - 9, GY - 22, 18, 22, Col(0x33302c))
            c.R(x - 34, GY - 26, 16, 10, GLASS); c.R(x + 18, GY - 26, 16, 10, GLASS)
            c.RR(x - 28, GY - 57, 56, 12, 2, Col(0xa32a22))
            g.text("KB TOOLS", x, GY - 51, 7, CREAM, bold: true)
            for j in 0..<3 { c.RR(x + 24 + Double(j) * 5, GY - 9, 4, 9, 1.5, Col(0xe8e8e4)) }
            if dark > 0.3 { lights.append((x - 26, GY - 21, 22)); lights.append((x + 26, GY - 21, 22)) }
            top = 66
        case .rocks:
            canopy(x, 36, Col(0x3a6ea5), Col(0xf2c14e))
            person(x - 8, GY - 1, 3, 1, 0, false)
            c.R(x - 30, GY - 10, 60, 10, Col(0x3a2c3a))
            c.R(x - 31, GY - 11, 62, 1.4, Col(0x5a4a5a))
            let gems: [Col] = [Col(0x9a5ad0), Col(0xf0f0f4), Col(0xe2742e), Col(0x2fa7a0), Col(0xd04a6a), Col(0xf2c14e), Col(0x6aa84a)]
            for j in 0..<7 { gem(x - 26 + Double(j) * 8.6, GY - 11, 2.2 + hashN(Double(j) + 3) * 1.4, gems[j]) }
            top = 46
        case .skoolie:
            rig(.skoolie, x - 58, GY, 2, -1)
            // a painted awning off the bus, a table of skulls, antlers and bottles, and prayer flags
            c.seg(x + 30, GY, x + 30, GY - 24, 1, Col(0x8a6238))
            c.poly(Col(0xb5452f), [x - 2, GY - 25, x + 32, GY - 23, x + 32, GY - 20, x - 2, GY - 22])
            let flags: [Col] = [Col(0xd9412e), Col(0xf2c14e), Col(0x3f8f8a), Col(0x9a5ad0), Col(0xf29a2e)]
            for j in 0..<5 {
                let fx = x + 1 + Double(j) * 6
                c.poly(flags[j], [fx, GY - 21, fx + 4, GY - 21 + Double(j) * 0.4, fx + 2, GY - 16.5])
            }
            c.R(x + 2, GY - 9, 28, 9, Col(0x4a2f4a))
            c.R(x + 1, GY - 10, 30, 1.4, Col(0x6a4a6a))
            skull(x + 8, GY - 10, 1)
            skull(x + 17, GY - 10, 0.75)
            c.RR(x + 22, GY - 15, 2, 5, 0.6, Col(0x3f8f8a)); c.RR(x + 25.5, GY - 14, 2, 4, 0.6, Col(0xb5651d))
            person(x + 38, GY + 2, 1, -1, 0, false)
            g.text("SKOOLIEPALOOZA", x - 30, GY - 54, 6.5, GOLD, bold: true)
            g.text("Ehrenberg  ·  the nomad gathering", x - 30, GY - 47, 4, CREAM.alpha(0.9))
            top = 46
        case .swap:
            c.R(x - 16, GY - 9, 32, 9, Col(0x7a2f3a))
            c.R(x - 17, GY - 10, 34, 1.4, Col(0x9a4a54))
            for j in 0..<g.rocks { gem(x - 10 + Double(j) * 6, GY - 10, 2.4, [Col(0x9a5ad0), Col(0xe2742e), Col(0x2fa7a0)][j % 3]) }
            for j in 0..<g.odd { skull(x + 4 + Double(j) * 6, GY - 10, 0.7) }
            c.seg(x - 20, GY, x - 20, GY - 18, 1, Col(0x8a6238))
            c.RR(x - 27, GY - 25, 14, 8, 1, Col(0xefe6cf))
            g.text("FOR SALE", x - 20, GY - 21, 3.6, INK, bold: true)
            top = 34
        case .lot:
            c.seg(x - 72, GY, x - 72, GY - 58, 1.2, Col(0xdddddd))
            c.seg(x + 72, GY, x + 72, GY - 58, 1.2, Col(0xdddddd))
            c.curve(x - 72, GY - 58, x, GY - 50, x + 72, GY - 58, 0.6, Col(0xffffff, 0.8))
            let pen: [Col] = [Col(0xd9412e), Col(0xf2c14e), Col(0x3a6ea5), Col(0xf4f1ea)]
            for j in 0..<13 {
                let f = (Double(j) + 0.5) / 13
                let fx = x - 72 + f * 144
                let fy = GY - 58 + 4 * (1 - (2 * f - 1) * (2 * f - 1))
                c.poly(pen[j % 4], [fx - 2.4, fy, fx + 2.4, fy, fx, fy + 5 + sin(NOW * 3 + Double(j)) * 0.6])
            }
            if g.phase == .play, let nx = g.nextRig() { rig(nx, x + 4, GY, 0, -1) } else { rig(.classC, x + 4, GY, 0, -1) }
            top = 66
        }
        if sp.kind != .tools && sp.kind != .skoolie && !near {
            g.text(sp.name, x, GY - top, 5, CREAM.alpha(0.8), bold: true)
        }
    }

    private func endSigns() {
        let ends: [(Double, String, String)] = [(400, "EHRENBERG", "west: nomad country    east: Quartzsite"), (g.WORLD - 70, "THE BIG TENT", "RV show: coming next")]
        for e in ends {
            let x = e.0 - cam
            if x < -80 || x > W + 80 { continue }
            c.R(x - 1, GY - 22, 2, 22, Col(0x6a4e30))
            c.RR(x - 30, GY - 34, 60, 15, 2, Col(0x7a5a3a))
            g.text(e.1, x, GY - 29.5, 5, CREAM, bold: true)
            g.text(e.2, x, GY - 23.5, 3.4, CREAM.alpha(0.85))
        }
    }

    // MARK: ring, HUD, screens

    private func ring(_ i: Int) {
        let x = g.spots[i].x - cam
        let y = GY - 84.0
        guard let o = g.offer(i) else {
            g.text(g.note(i), x, y + 8, 5, CREAM.alpha(0.9))
            return
        }
        let r = 11.0
        c.circ(x, y, r + 2.5, Col(0x1c1410, 0.62))
        c.arcStroke(x, y, r, 0, PI * 2, 2.6, Col(0xffffff, 0.22))
        if g.ringProg > 0 {
            c.roundCaps(true)
            c.arcStroke(x, y, r, -PI / 2, -PI / 2 + PI * 2 * min(1, g.ringProg), 2.6, o.earn > 0 ? GREEN : GOLD)
            c.roundCaps(false)
        }
        let label = o.earn > 0 ? "+$\(o.earn)" : (o.cost > 0 ? "$\(o.cost)" : "FREE")
        let short = Double(o.cost) > g.money + g.ringPaid
        g.text(label, x, y, label.count > 4 ? 5.6 : 7, short ? REDC : (o.earn > 0 ? GREEN : CREAM), bold: true)
        g.text(o.label, x, y + 18, 5, CREAM)
        if g.ringProg <= 0 { g.text("hold", x, y - 17, 4, CREAM.alpha(0.6 + 0.3 * sin(NOW * 4))) }
    }

    private func hud() {
        let l = g.safeL + 8, r = W - g.safeR - 8
        c.RR(l, 5, 132, 14, 7, Col(0x1c1410, 0.68))
        g.text("$\(Int((g.money + 0.0001).rounded(.down)))", l + 7, 12, 7.5, GOLD, align: 1, bold: true)
        // health
        let hx = l + 46
        c.circ(hx, 11, 2, REDC); c.circ(hx + 3, 11, 2, REDC)
        c.poly(REDC, [hx - 1.9, 12, hx + 4.9, 12, hx + 1.5, 16])
        c.RR(hx + 8, 10, 34, 4, 2, Col(0xffffff, 0.2))
        c.RR(hx + 8, 10, 34 * g.health / 100, 4, 2, g.health < 35 ? REDC : GREEN)
        // cred
        let sx = l + 100
        var star: [Double] = []
        for k in 0..<10 {
            let a = -PI / 2 + Double(k) * PI / 5
            let rr = k % 2 == 0 ? 4.0 : 1.7
            star.append(sx + cos(a) * rr); star.append(12.2 + sin(a) * rr)
        }
        c.poly(GOLD, star)
        g.text("\(g.cred)", sx + 7, 12, 7, CREAM, align: 1, bold: true)

        var pack = "Day \(g.day)"
        if g.wood > 0 { pack += "  ·  firewood \(g.wood)" }
        if g.rocks > 0 { pack += "  ·  specimens \(g.rocks)" }
        if g.odd > 0 { pack += "  ·  oddities \(g.odd)" }
        g.text(pack, r, 12, 5.5, CREAM, align: 2, bold: true, plate: true)

        // the pad and the hold button
        let py = H - 24
        let pxc = g.safeL + 40
        c.RR(pxc - 30, py - 9, 60, 18, 9, Col(0xffffff, 0.13))
        c.circ(pxc + g.input.stick * 20, py, 8, Col(0xffffff, 0.4))
        let bx = W - g.safeR - 34
        c.circ(bx, py, 13, Col(0xffffff, g.input.hold ? 0.34 : 0.14))
        c.arcStroke(bx, py, 13, 0, PI * 2, 1, Col(0xffffff, 0.45))
        g.text(g.inRig ? "" : "HOLD", bx, py, 4.6, CREAM.alpha(0.85), bold: true)

        if g.hintT > 0 {
            g.text(g.hintText, W / 2, H - 22, 5.4, CREAM.alpha(clampD(g.hintT, 0, 1)), wrap: W * 0.46, plate: true)
        }
    }

    private func titleOverlay() {
        c.R(0, 0, W, 13, Col(0x000000))
        c.R(0, H - 13, W, 13, Col(0x000000))
        c.vfill(0, 13, W, 70, [(0, Col(0x1c0f1c, 0.55)), (1, Col(0x1c0f1c, 0))])
        g.text("QUARTZSITE", W / 2, 42, 27, CREAM, bold: true)
        g.text("A DESERT WINTER", W / 2, 62, 8, GOLD, bold: true)
        if g.hasSave {
            let bw = 96.0
            c.RR(W / 2 - bw - 6, H - 52, bw, 22, 11, GOLD)
            g.text("Back to camp", W / 2 - bw / 2 - 6, H - 41, 7.5, INK, bold: true)
            g.hits.append(Hit(id: 1, x: W / 2 - bw - 6, y: H - 56, w: bw, h: 30))
            c.RR(W / 2 + 6, H - 52, bw, 22, 11, Col(0x1c1410, 0.7))
            g.text("New camper", W / 2 + bw / 2 + 6, H - 41, 7.5, CREAM, bold: true)
            g.hits.append(Hit(id: 2, x: W / 2 + 6, y: H - 56, w: bw, h: 30))
        } else {
            g.text("Tap to roll in", W / 2, H - 40, 8, CREAM.alpha(0.65 + 0.35 * sin(NOW * 3)), bold: true)
        }
    }

    private func card(_ id: Int, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ on: Bool) {
        if on { c.RR(x - 1.5, y - 1.5, w + 3, h + 3, 6, GOLD) }
        c.RR(x, y, w, h, 5, on ? Col(0x3a2c1e, 0.97) : Col(0x1c1410, 0.86))
        g.hits.append(Hit(id: id, x: x, y: y, w: w, h: h))
    }

    private func pickOverlay() {
        c.R(0, 0, W, H, Col(0x0c0a14, 0.6))
        let l = g.safeL + 14
        let uw = W - g.safeL - g.safeR - 28

        g.text("HOW DO YOU ROLL?", l, 11, 6, GOLD, align: 1, bold: true)
        let cw = (uw - 8) / 2
        let lifeName = ["NOMAD", "RVER"]
        let lifeSub = ["Vans, skoolies, Skooliepalooza. Starts with friends: 5 cred.", "A snowbird with a check coming in. Starts with $100 more."]
        for i in 0..<2 {
            let x = l + Double(i) * (cw + 8)
            card(i, x, 17, cw, 36, g.life.rawValue == i)
            rig(i == 0 ? .skoolie : .classC, x + 36, 48, i == 0 ? 1 : 0, 1, 0.56)
            g.text(lifeName[i], x + 74, 28, 9, CREAM, align: 1, bold: true)
            g.text(lifeSub[i], x + 74 + (cw - 80) / 2, 42, 4.6, CREAM.alpha(0.85), wrap: cw - 80)
        }

        g.text("YOUR FIRST RIG", l, 64, 6, GOLD, align: 1, bold: true)
        let rw = (uw - 16) / 3
        for i in 0..<3 {
            let x = l + Double(i) * (rw + 8)
            card(10 + i, x, 70, rw, 42, g.pickRig == i)
            rig(START_RIGS[i], x + 29, 105, 0, 1, 0.74)
            let cash = Int(START_CASH[i]) + (g.life == .rver ? 100 : 0)
            g.text(RIGS[START_RIGS[i].rawValue].name, x + 57, 84, 6, CREAM, align: 1, bold: true)
            g.text("$\(cash) cash", x + 57, 96, 5.4, GOLD, align: 1)
        }

        g.text("YOU", l, 124, 6, GOLD, align: 1, bold: true)
        for i in 0..<4 {
            let x = l + Double(i) * 34
            card(20 + i, x, 130, 28, 38, g.look == i)
            person(x + 14, 163, i, 1, 0, false)
        }
        let bw = 112.0
        let bx = l + uw - bw
        c.RR(bx, 140, bw, 26, 13, GOLD)
        g.text("Hit the road", bx + bw / 2, 153, 9, INK, bold: true)
        g.hits.append(Hit(id: 99, x: bx, y: 134, w: bw, h: 38))
    }
}
