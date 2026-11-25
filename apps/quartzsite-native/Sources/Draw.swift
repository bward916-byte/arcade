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
            if g.mapOpen { mapOverlay() }
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
        let y0 = H * 0.2 / k
        c.R(0, y0, W / k, 2, Col(0xcaa878))
        for n in 0..<7 { toy(n, l + 22 + Double(n) * 52, y0, 1, n % 2 == 0 ? n % 4 : -1, 0) }
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
        let ar = g.phase == .play ? g.area : Area.ltva
        let seed = Double(ar.rawValue) * 3.1
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

        // the ranges: far and hazy, then nearer and darker; each place has its own skyline
        let haze = sk.1
        ridge(0.06, 1.3 + seed, GY - 6, 62, Col.mix(Col(0x6a5a80), haze, 0.55).shade(1 - dark * 0.55))
        if ar == .dome {
            // Dome Rock itself: a big rounded granite dome close behind the camps
            let dx = W * 0.62 + 260 - cam * 0.14
            let rock = Col.mix(Col(0x8a5a44), haze, 0.22).shade(1 - dark * 0.6)
            c.ell(dx, GY + 4, 118, 64, rock)
            c.ell(dx + 30, GY + 2, 80, 52, rock.shade(0.9))
            c.ell(dx - 50, GY - 8, 40, 26, rock.shade(1.08))
        }
        ridge(0.14, 4.1 + seed, GY - 2, ar == .dome ? 30 : 40, Col.mix(Col(0x7a4f48), haze, 0.3).shade(1 - dark * 0.6))
        ridge(0.3, 8.7 + seed, GY + 1, ar == .skoolie ? 8 : (ar == .trail ? 24 : 17), Col.mix(Col(0x8a5a3e), haze, 0.12).shade(1 - dark * 0.65))

        // a far stand of saguaros on the low hills
        if ar == .ltva || ar == .dome || ar == .trail || ar == .scaddan {
            var n = floor((cam * 0.3 - 20) / 46)
            while n * 46 < cam * 0.3 + W + 20 {
                if hashN(n + 900 + seed) < (ar == .dome || ar == .trail ? 0.85 : 0.5) {
                    let wx = n * 46 + hashN(n + 910) * 30
                    let sx = wx - cam * 0.3
                    let base = ridgeY(sx + cam * 0.3, 8.7 + seed, GY + 1, ar == .trail ? 24 : 17) + 2
                    saguaro(sx, base, 9 + hashN(n + 920) * 7, n + 930, Col.mix(Col(0x4a5a44), haze, 0.25).shade(1 - dark * 0.6), false)
                }
                n += 1
            }
        }
        if ar == .skoolie { river(haze) }
        background(ar, haze)

        // the desert floor and the dirt road
        let paved = ar == .main || ar == .tyson
        let dirt = paved ? Col(0xd2b488) : (ar == .trail ? Col(0xd4b282) : Col(0xdcbc8c))
        c.vfill(0, GY, W, H - GY, [(0, dirt), (1, Col(0xb48a5a))])
        c.R(0, GY, W, 1, Col(0xf0d8ac, 0.7))
        if paved {
            // Main Street and Kuehn Street are paved
            c.R(0, GY + 6, W, 11, Col(0x5a5450))
            var lx = -((cam).truncatingRemainder(dividingBy: 30))
            while lx < W { c.R(lx, GY + 11.2, 12, 0.8, Col(0xf2c14e, 0.8)); lx += 30 }
        } else if ar == .trail {
            c.R(0, GY + 6, W, 11, Col(0xc9a372, 0.7))
            c.R(0, GY + 8.2, W, 1.3, Col(0x9a7448, 0.75))
            c.R(0, GY + 13.8, W, 1.3, Col(0x9a7448, 0.75))
        } else {
            c.R(0, GY + 7, W, 9, Col(0xe6cba0, 0.55))
            c.R(0, GY + 10, W, 0.8, Col(0xa98558, 0.5))
            c.R(0, GY + 13, W, 0.8, Col(0xa98558, 0.4))
        }
        var n = floor(cam / 23) - 1
        while n * 23 < cam + W + 23 {
            let sx = n * 23 + hashN(n + 50) * 20 - cam
            let sy = GY + 3 + hashN(n + 60) * (H - GY - 6)
            c.ell(sx, sy, 1 + hashN(n + 70) * 1.6, 0.7 + hashN(n + 80) * 0.6, Col(0x8f6c46, 0.55))
            n += 1
        }

        // cactus and brush along the strip: dense at Dome Rock, sparse in town, palms by the river
        let skip = paved ? 0.7 : (ar == .ltva ? 0.3 : 0)
        n = floor((cam - 80) / 64)
        while n * 64 < cam + W + 80 {
            if hashN(n + 77 + seed) >= skip {
                let wx = n * 64 + hashN(n + 3) * 44
                let sx = wx - cam
                let k = hashN(n + 31 + seed)
                if ar == .skoolie && k < 0.25 { palm(sx, GY + 1, 40 + hashN(n + 5) * 22, n) }
                else if k < 0.36 { saguaro(sx, GY + 1, 26 + hashN(n + 5) * 20, n, SAG, true) }
                else if k < 0.6 { cholla(sx, GY + 1, 0.8 + hashN(n + 6) * 0.5, n) }
                else if k < 0.8 { creosote(sx, GY + 1, n) }
                else { ocotillo(sx, GY + 1, n) }
            }
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
            if g.phase == .play { drawYou() }
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

    /// Your rig, your toy and you, with a soft glow on whatever you can tap.
    private func drawYou() {
        let pulse = 0.3 + 0.14 * sin(NOW * 4)
        if g.rigArea == g.area {
            let rx = g.rigX - cam
            let def = RIGS[g.rig.rawValue]
            if g.nearRig && !g.inRig {
                c.glow(rx, GY - def.high * 0.45, def.len * 0.85, Col(0xffe9a0, pulse), Col(0xffe9a0, 0))
            }
            rig(g.rig, rx, GY + (g.inRig ? 12 : 0), g.panels, g.rigFace)
            if g.nearRig {
                g.hits.append(Hit(id: 50, x: rx - def.len / 2 - 8, y: GY - def.high - 12, w: def.len + 16, h: def.high + 30))
                if !g.inRig && !g.onToy { g.text(g.rig == .tent ? "Your tent" : "Tap to drive", rx, GY - def.high - 8, 5.5, CREAM) }
            }
        }
        if g.toy >= 0 && g.toyArea == g.area && !g.inRig {
            let tx = (g.onToy ? g.px : g.toyX) - cam
            let len = TOYS[g.toy].len
            if g.onToy && abs(g.vx) > 25 {
                for i in 0..<4 {
                    let d = Double(i)
                    c.circ(tx - g.face * (14 + d * 7), GY + 3 - d * 1.1, 2.2 + d * 1.2, Col(0xe8d0a8, 0.28 - d * 0.05))
                }
            }
            if g.nearToy && !g.onToy {
                c.glow(tx, GY - 8, len * 0.9, Col(0xffe9a0, pulse), Col(0xffe9a0, 0))
                g.text("Tap to ride", tx, GY - 26, 5.5, CREAM)
            }
            toy(g.toy, tx, g.onToy ? GY + 7 : GY + 2, g.onToy ? g.face : 1, g.onToy ? g.look : -1, g.onToy ? g.walk : 0)
            if g.nearToy {
                g.hits.append(Hit(id: 51, x: tx - len / 2 - 8, y: GY - 34, w: len + 16, h: 52))
            }
        }
        if !g.inRig && !g.onToy { person(g.px - cam, GY + 6, g.look, g.face, g.walk, abs(g.vx) > 4) }
    }

    private func river(_ haze: Col) {
        let top = GY - 11
        let water = Col.mix(Col(0x2e6f8e), haze, 0.25).shade(1 - dark * 0.6)
        c.vfill(0, top, W, GY - top + 1, [(0, water.shade(1.15)), (1, water)])
        c.R(0, top - 1, W, 1.4, Col.mix(Col(0x4a6a3a), haze, 0.3).shade(1 - dark * 0.6))
        // the far bank: tamarisk and arrowweed
        var n = floor((cam * 0.5 - 20) / 18)
        while n * 18 < cam * 0.5 + W + 20 {
            let sx = n * 18 + hashN(n + 1500) * 10 - cam * 0.5
            c.circ(sx, top - 2, 3 + hashN(n + 1510) * 3, Col.mix(Col(0x5a7048), haze, 0.35).shade(1 - dark * 0.6))
            n += 1
        }
        // glints drifting downstream
        for i in 0..<18 {
            let d = Double(i)
            let gx = (hashN(d + 1600) * W + NOW * (6 + hashN(d + 1610) * 6) - cam * 0.6).truncatingRemainder(dividingBy: W + 20)
            let gy = top + 2 + hashN(d + 1620) * 8
            c.R(gx < 0 ? gx + W + 20 : gx, gy, 3 + hashN(d + 1630) * 5, 0.6, Col(0xffffff, 0.35 * (0.5 + 0.5 * sin(NOW * 2 + d))))
        }
    }

    /// The middle distance: rows of RVs at the LTVA, false-front stores in town, buses by the river.
    private func background(_ ar: Area, _ haze: Col) {
        let par = 0.72
        switch ar {
        case .ltva:
            let gap = 58.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                let h = hashN(n + 1200)
                let sx = n * gap + hashN(n + 1210) * 18 - cam * par
                if h < 0.7 {
                    let kinds: [RigKind] = [.classA, .classC, .classA, .classB, .classC, .van, .classA, .skoolie]
                    let k = kinds[Int(hashN(n + 1220) * 8) % 8]
                    rig(k, sx, GY + 0.5, hashN(n + 1230) < 0.5 ? 2 : 0, hashN(n + 1240) < 0.5 ? 1 : -1, 0.5)
                } else if h < 0.8 {
                    rig(.tent, sx, GY + 0.5, 0, 1, 0.55)
                } else if h < 0.88 {
                    outhouse(sx, GY + 0.5, 0.5)
                }
                n += 1
            }
        case .main, .tyson:
            let gap = 74.0
            var n = floor((cam * par - 80) / gap)
            let walls: [Col] = [Col(0xd9b48a), Col(0xe8dcc4), Col(0xb98a6a), Col(0x9fb7b0), Col(0xe0c890)]
            while n * gap < cam * par + W + 80 {
                let sx = n * gap - cam * par
                let w = 46 + hashN(n + 1300) * 20
                let h = 18 + hashN(n + 1310) * 12
                let col = walls[Int(hashN(n + 1320) * 5) % 5].shade(1 - dark * 0.5)
                c.R(sx, GY - h, w, h + 1, col)
                c.R(sx + w * 0.2, GY - h - 5, w * 0.6, 5, col)
                c.R(sx, GY - h * 0.55, w, 2.4, col.shade(0.7))
                c.R(sx + 5, GY - h * 0.45, w * 0.3, h * 0.35, GLASS.alpha(0.8))
                c.R(sx + w * 0.55, GY - h * 0.45, 7, h * 0.45, col.shade(0.55))
                if dark > 0.3 { lights.append((sx + w * 0.3, GY - h * 0.3, 14)) }
                if hashN(n + 1330) < 0.5 {
                    c.R(sx + w + 8, GY - 30, 0.8, 31, Col(0x5a4a3a).shade(1 - dark * 0.5))
                    c.R(sx + w + 5, GY - 29, 7, 0.8, Col(0x5a4a3a).shade(1 - dark * 0.5))
                }
                n += 1
            }
            if ar == .tyson && g.phase == .play && g.tysonShow() != nil {
                let tops: [Col] = [Col(0xf4f1ea), Col(0x3a6ea5), Col(0xd9412e), Col(0xf2c14e), Col(0x4f9a5a)]
                var k = floor((cam * 0.85 - 40) / 34)
                while k * 34 < cam * 0.85 + W + 40 {
                    let sx = k * 34 - cam * 0.85
                    let tc = tops[Int(hashN(k + 1700) * 5) % 5].shade(1 - dark * 0.5)
                    c.R(sx - 12, GY - 14, 0.6, 14, Col(0xcccccc)); c.R(sx + 11.4, GY - 14, 0.6, 14, Col(0xcccccc))
                    c.poly(tc, [sx - 14, GY - 14, sx - 9, GY - 19, sx + 9, GY - 19, sx + 14, GY - 14])
                    if hashN(k + 1710) < 0.6 { person(sx + (hashN(k + 1720) - 0.5) * 16, GY + 1, Int(hashN(k + 1730) * 4), hashN(k + 1740) < 0.5 ? 1 : -1, 0, false) }
                    k += 1
                }
            }
        case .dome:
            // a few other boondockers spread far apart
            let gap = 260.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1400) < 0.6 {
                    let sx = n * gap + hashN(n + 1410) * 120 - cam * par
                    let kinds: [RigKind] = [.van, .classB, .skoolie, .classC, .tent]
                    rig(kinds[Int(hashN(n + 1420) * 5) % 5], sx, GY + 0.5, 1, hashN(n + 1430) < 0.5 ? 1 : -1, 0.5)
                }
                n += 1
            }
        case .skoolie:
            let gather = g.phase == .play && g.on(EV_SKOOL)
            let gap = gather ? 62.0 : 300.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                let sx = n * gap + hashN(n + 1450) * 20 - cam * par
                let h = hashN(n + 1460)
                if gather {
                    if h < 0.6 { rig(.skoolie, sx, GY + 0.5, 2, hashN(n + 1470) < 0.5 ? 1 : -1, 0.5) }
                    else if h < 0.85 { rig(.van, sx, GY + 0.5, 1, 1, 0.5) }
                    else { rig(.tent, sx, GY + 0.5, 0, 1, 0.55) }
                } else if h < 0.5 {
                    rig(.van, sx, GY + 0.5, 1, 1, 0.5)
                }
                n += 1
            }
        case .trail:
            let gap = 420.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1480) < 0.45 {
                    let sx = n * gap + hashN(n + 1490) * 160 - cam * par
                    toy(5, sx, GY + 0.5, hashN(n + 1495) < 0.5 ? 1 : -1, 1, 0)
                }
                n += 1
            }
        case .scaddan:
            let gap = 210.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1520) < 0.65 {
                    let sx = n * gap + hashN(n + 1530) * 90 - cam * par
                    let kinds: [RigKind] = [.classC, .skoolie, .van, .classA, .minivan]
                    rig(kinds[Int(hashN(n + 1540) * 5) % 5], sx, GY + 0.5, 2, hashN(n + 1550) < 0.5 ? 1 : -1, 0.5)
                }
                n += 1
            }
        }
        // haze over the middle distance so it sits back
        c.vfill(0, GY - 34, W, 35, [(0, haze.alpha(0)), (1, haze.alpha(0.3 * (1 - dark)))])
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
            c.R(-35, -9.4, 70, 4.6, Col(0x3a3d40))
            c.curve(-34, -12.5, 0, -15, 26, -15.5, 1.6, Col(0x3a6ea5))
            c.poly(GLASS, [15.2, -27, 19.4, -27, 25.6, -17.6, 15.2, -17.6])
            c.RR(0.5, -27, 12, 8, 1.2, GLASS)
            c.RR(-29, -27, 15, 8, 1.2, GLASS)
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
            c.curve(-43, -15, -8, -20, 33, -27, 2, Col(0xb5651d))
            c.curve(-43, -12, -8, -16.4, 33, -24.4, 0.9, Col(0x7a4a2a))
            c.RR(24.6, -34.2, 7.4, 5, 1, GLASS)
            c.RR(-35, -29, 15, 8.4, 1, GLASS)
            c.RR(-14, -29, 12, 8.4, 1, GLASS)
            c.R(3.6, -28, 8.4, 22, col.shade(0.9)); c.RR(5.2, -26.4, 5, 5, 0.8, GLASS); c.R(4.6, -5.6, 6.4, 1.4, trim)
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
            // full-body paint first, so the windows and the door sit on top of it
            c.curve(-58, -12, -10, -17, 40, -30, 3, Col(0x7a4a2a))
            c.curve(-58, -16.4, -10, -21, 40, -34, 1.2, GOLD)
            c.curve(-58, -8.6, -10, -12, 58, -18, 1.4, Col(0x3a3230))
            c.poly(GLASS, [53.4, -36.4, 57.4, -35.2, 58.6, -21.6, 53.4, -21.6])
            c.RR(42, -34.4, 10, 12.4, 1.2, GLASS)
            c.RR(-48, -33.4, 18, 10, 1.2, GLASS)
            c.RR(-22, -33.4, 16, 10, 1.2, GLASS)
            c.RR(2, -33.4, 14, 10, 1.2, GLASS)
            c.R(28.4, -34.4, 9, 28, col.shade(0.9)); c.RR(30.2, -32.4, 5.4, 8, 0.8, GLASS); c.R(29.4, -6, 7, 1.6, trim)
            // the basement doors
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

    /// A bike, quad or side-by-side centred on `cx`, wheels on `base`. `rider` is a look index, or -1 for none.
    func toy(_ k: Int, _ cx: Double, _ base: Double, _ dir: Double, _ rider: Int, _ spin: Double) {
        if cx < -60 || cx > W + 60 { return }
        c.save()
        c.translate(cx, base)
        c.scale(dir, 1)
        c.ell(0, 0.4, TOYS[max(0, min(k, TOYS.count - 1))].len * 0.5, 1.4, Col(0x000000, 0.22))
        let dk = Col(0x22201e)
        let seat: [(Double, Double)] = [(-2.4, -10.6), (-2.4, -10.6), (-4, -11.4), (-1.6, -12.4), (-2, -7), (-3.4, -14.8), (-3.2, -19.4)]
        let sp = seat[max(0, min(k, 6))]
        // in the car the driver sits behind the glass, so draw them first
        if rider >= 0 && k == 4 { seated(sp.0, sp.1, rider, 1.0) }
        c.roundCaps(true)
        switch k {
        case 0, 1:
            // bicycle, or an e-bike with a battery on the down tube
            let fr = k == 0 ? Col(0xb5452f) : Col(0x2f6f8a)
            for wx in [-7.0, 7.0] {
                c.ellStroke(wx, -3.6, 3.4, 3.4, 1, dk)
                c.seg(wx - 2.6 * cos(spin), -3.6 - 2.6 * sin(spin), wx + 2.6 * cos(spin), -3.6 + 2.6 * sin(spin), 0.3, Col(0x9a9a96))
            }
            c.seg(-7, -3.6, -2, -10, 1.1, fr); c.seg(-2, -10, 5, -10.6, 1.1, fr); c.seg(5, -10.6, 7, -3.6, 1.1, fr)
            c.seg(-2, -10, 0, -4, 1.1, fr); c.seg(0, -4, -7, -3.6, 1.1, fr)
            if k == 1 { c.RR(-1.6, -9.6, 2.4, 5, 0.8, Col(0x3a3a3a)) }
            c.seg(-2, -10, -3, -12, 0.8, dk); c.R(-5, -12.6, 4, 1.2, dk)
            c.seg(5, -10.6, 5.6, -13.4, 0.8, dk); c.seg(4.4, -13.6, 7, -13.4, 0.8, dk)
        case 2:
            // dirt bike: knobby tires, high fender, tank and long seat
            let red = Col(0xc8281e)
            for wx in [-8.0, 8.4] { c.circ(wx, -4, 4, dk); c.circ(wx, -4, 1.8, HUB) }
            c.seg(8.4, -4, 5.6, -13, 1.2, Col(0xb8b8b4))
            c.poly(red, [5, -12.6, 11, -11.6, 8, -10.4])
            c.poly(red, [-2, -10, 5, -12.6, 6, -9, -1, -7.6])
            c.R(-9, -11, 9, 1.6, dk)
            c.poly(Col(0xf4f4f0), [-12, -10.6, -6, -11.4, -8, -9])
            c.seg(-8, -4, -1, -7, 1.4, Col(0x6a6a6a)); c.seg(-1, -7, 4, -5, 1.2, Col(0x6a6a6a))
            c.seg(5.6, -13, 4.4, -15, 0.9, dk); c.seg(3, -15.2, 7, -15, 0.9, dk)
        case 3:
            // quad: four fat wheels (two showing), fenders, racks front and back
            let body = Col(0x3a6a3a)
            for wx in [-8.4, 8.6] { c.circ(wx, -4.4, 4.4, dk); c.circ(wx, -4.4, 2, HUB) }
            c.poly(body, [-13, -8, -11, -11, -5, -11, -3, -8.4, 3, -8.4, 5, -11.4, 11, -11.4, 13, -8, 13, -6.6, -13, -6.6])
            c.R(-6, -12.6, 9, 2.2, dk)
            c.R(-13, -13, 6, 0.8, Col(0x2a2a2a)); c.R(7, -13.2, 6, 0.8, Col(0x2a2a2a))
            c.seg(4, -11.4, 3, -15, 0.9, dk); c.seg(1.6, -15.4, 5.4, -15, 0.9, dk)
            c.circ(13, -9.4, 0.9, Col(0xfff2c0))
        case 4:
            // a small used SUV, the kind people tow behind a motorhome
            let body = Col(0x6a7a5a)
            c.poly(body, [-23, -5, -23, -17, -20, -21, 6, -21, 12, -14, 21, -12.6, 23, -9.6, 23, -5])
            c.poly(GLASS.alpha(0.55), [-18, -19.6, -6, -19.6, -6, -14, -19, -14])
            c.poly(GLASS.alpha(0.55), [-4.6, -19.6, 5, -19.6, 10, -14, -4.6, -14])
            c.R(-5.6, -20, 1.2, 15, body.shade(0.8))
            c.R(-23, -9, 46, 1, body.shade(0.75))
            c.R(-23, -6.6, 46, 2, Col(0x2a2a2a))
            c.circ(-24.4, -12, 3.4, dk); c.circ(-24.4, -12, 1.6, HUB)
            c.R(-18, -22.4, 22, 1, dk)
            c.RR(21.4, -11.6, 1.8, 2, 0.6, Col(0xfff2c0))
            for wx in [-14.0, 14.0] { c.circ(wx, -4.6, 4.6, Col(0x15120f)); c.circ(wx, -4.6, 3.6, TIRE); c.circ(wx, -4.6, 1.8, HUB) }
        case 5:
            // side-by-side: roll cage, two seats, a little bed in back
            let body = Col(0xd8d4cc)
            for wx in [-12.0, 12.6] { c.circ(wx, -4.8, 4.8, dk); c.circ(wx, -4.8, 2.2, HUB) }
            c.poly(body, [-19, -6.6, -18, -12, -8, -12, -6, -9.4, 8, -9.4, 12, -12.6, 18, -11, 19, -6.6])
            c.R(-19, -6.6, 38, 2, Col(0x3a3a3a))
            c.R(-18, -14.6, 8, 2.4, Col(0x5a4a3a))
            c.seg(-8, -9.4, -7, -26, 1, dk); c.seg(-7, -26, 8, -26, 1, dk); c.seg(8, -26, 12, -12.6, 1, dk)
            c.seg(-1, -9.4, -1, -26, 0.8, dk)
            c.R(-6, -15, 4, 5.6, Col(0x2a2a2a))
            c.circ(18.6, -9, 0.9, Col(0xfff2c0))
        default:
            // supercharged side-by-side: lifted on long-travel arms, light bar, hood scoop
            let red = Col(0xb8231a)
            for wx in [-15.0, 16.0] {
                c.seg(wx, -5.8, wx * 0.45, -12, 0.9, Col(0x6a6a6a))
                c.seg(wx, -5.8, wx * 0.5, -16, 1.2, GOLD)
                c.circ(wx, -5.8, 5.8, dk); c.circ(wx, -5.8, 2.6, Col(0x2a2a2a)); c.circ(wx, -5.8, 1.2, Col(0xb8b8b4))
            }
            c.poly(red, [-24, -11, -22, -17, -9, -17, -7, -14, 10, -14, 15, -18, 23, -16.4, 24, -11])
            c.R(-24, -11, 48, 2, Col(0x1e1e1e))
            c.poly(Col(0x2a2a2a), [12, -17.4, 17, -19, 18, -17.4])
            c.seg(-9, -14, -8, -31, 1.1, dk); c.seg(-8, -31, 9, -31, 1.1, dk); c.seg(9, -31, 15, -18, 1.1, dk)
            c.seg(0, -14, 0, -31, 0.9, dk)
            c.R(-4, -33.2, 12, 1.8, Col(0x2a2a2a)); c.R(-3.4, -33, 10.8, 1, Col(0xfff2c0))
            c.R(-22, -20, 9, 3, Col(0x4a4a4a))
            c.R(-6.4, -20, 4.4, 6, Col(0x2a2a2a))
            c.circ(23.6, -13.6, 1, Col(0xfff2c0))
            if dark > 0.3 { lights.append((cx + dir * 26, base - 14, 26)) }
        }
        c.roundCaps(false)
        if rider >= 0 && k != 4 { seated(sp.0, sp.1, rider, k >= 5 ? 1.0 : 1.4) }
        c.restore()
    }

    /// A rider sitting at (x, hip) in the current transform, facing right, hands forward.
    private func seated(_ x: Double, _ hip: Double, _ look: Int, _ reach: Double) {
        let k = ((look % 4) + 4) % 4
        let skin = SKINS[k], shirt = SHIRTS[k], pants = PANTS[k]
        c.roundCaps(true)
        c.seg(x, hip, x + 4.4, hip - 0.4, 2.2, pants)
        c.seg(x + 4.4, hip - 0.4, x + 5, hip + 4.4, 2, pants.shade(0.85))
        c.RR(x - 2.6, hip - 8.6, 5.2, 9, 2, shirt)
        c.seg(x + 0.6, hip - 6.8, x + 4 + reach * 2, hip - 4.6, 1.5, shirt.shade(0.85))
        c.roundCaps(false)
        let hy = hip - 11.2
        c.circ(x + 0.4, hy, 2.7, skin)
        c.R(x + 1.5, hy - 0.5, 0.7, 0.7, Col(0x2a1c14))
        // a helmet on the bikes and quads, the usual hat otherwise
        if reach > 1.2 {
            c.dome(x + 0.2, hy - 0.2, 3.1, Col(0x2a2a2a))
            c.R(x + 1.4, hy - 1.2, 2.2, 1, Col(0x5a8aaa))
        } else {
            c.dome(x + 0.3, hy - 0.6, 2.8, [Col(0xd9c07a), Col(0x8a3a5a), Col(0x2f4f7a), Col(0xefe6cf)][k])
        }
    }

    /// A desert fan palm, the kind that line the river.
    private func palm(_ x: Double, _ base: Double, _ h: Double, _ seed: Double) {
        if x < -40 || x > W + 40 { return }
        let lean = (hashN(seed + 3) - 0.5) * 8
        let trunk = Col(0x6a5240).shade(1 - dark * 0.4)
        c.roundCaps(true)
        c.curve(x, base, x + lean * 0.3, base - h * 0.5, x + lean, base - h, 3, trunk)
        c.poly(Col(0x9a8a6a).shade(1 - dark * 0.4), [x + lean - 3, base - h + 2, x + lean + 3, base - h + 2, x + lean + 2.4, base - h + 12, x + lean - 2.4, base - h + 12])
        let leaf = Col(0x4f7a3a).shade(1 - dark * 0.4)
        for i in 0..<9 {
            let a = -PI * 0.95 + Double(i) * PI * 0.95 / 8 + sin(NOW * 1.2 + seed + Double(i)) * 0.04
            let r = 12 + hashN(seed + Double(i)) * 4
            c.curve(x + lean, base - h, x + lean + cos(a) * r * 0.6, base - h + sin(a) * r * 0.6 - 3, x + lean + cos(a) * r, base - h + sin(a) * r + 3, 1.8, leaf)
        }
        c.roundCaps(false)
    }

    /// A wheel drawn in screen space, outside a rig's own transform.
    private func wheelAt(_ x: Double, _ base: Double, _ r: Double) {
        c.circ(x, base - r, r + 1, Col(0x15120f))
        c.circ(x, base - r, r, TIRE)
        c.circ(x, base - r, r * 0.5, HUB)
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
        var label = true
        let wood = Col(0x8a6238)
        switch sp.kind {
        case .wash:
            let dw = Col(0x5a4230)
            c.roundCaps(true)
            c.seg(x - 20, GY, x - 22, GY - 22, 2.4, dw)
            c.seg(x - 22, GY - 14, x - 32, GY - 26, 1.5, dw)
            c.seg(x - 22, GY - 18, x - 12, GY - 30, 1.5, dw)
            c.seg(x - 21, GY - 22, x - 24, GY - 33, 1.2, dw)
            for j in 0..<5 {
                let d = Double(j)
                c.seg(x - 4 + d * 1.5, GY - 1 - d * 1.6, x + 16 - d * 1.5, GY - 2 - d * 1.6, 1.8, j % 2 == 0 ? Col(0x7a5a3a) : Col(0x8f6c46))
            }
            c.roundCaps(false)
            top = 38
        case .camp:
            if g.rigArea == g.area || g.phase != .play {
                fire(x + 4, GY + 3)
            } else {
                c.ell(x + 4, GY + 3, 6, 1.6, Col(0x4a4038))
                for j in 0..<5 { c.circ(x - 1 + Double(j) * 2.5, GY + 3, 1.2, Col(0x7a7068)) }
            }
            c.poly(Col(0x3f6a8a), [x + 16, GY + 2, x + 17, GY - 8, x + 19, GY - 8, x + 20, GY - 2, x + 25, GY - 2, x + 25, GY + 2])
            top = 30
        case .bench:
            c.R(x - 12, GY - 9, 24, 1.6, Col(0xd8d4cc))
            c.seg(x - 10, GY - 7.4, x - 7, GY, 0.8, Col(0x6a6a6a)); c.seg(x - 7, GY - 7.4, x - 10, GY, 0.8, Col(0x6a6a6a))
            c.seg(x + 10, GY - 7.4, x + 7, GY, 0.8, Col(0x6a6a6a)); c.seg(x + 7, GY - 7.4, x + 10, GY, 0.8, Col(0x6a6a6a))
            c.R(x - 9, GY - 12, 4, 3, Col(0x4a4a4e)); c.R(x - 8, GY - 13.4, 2, 1.4, Col(0x4a4a4e))
            c.seg(x - 2, GY - 9.2, x + 2, GY - 12, 0.6, Col(0xb8b8b4))
            c.curve(x + 4, GY - 9.2, x + 6, GY - 14, x + 8, GY - 9.2, 0.4, Col(0xd9b46a))
            gem(x + 6, GY - 10, 1.2, Col(0x2fa7a0))
            c.R(x + 9, GY - 13, 1.8, 3.8, Col(0x3a3a3a)); c.circ(x + 9.9, GY - 13.4, 1.6, Col(0xffe7a0))
            if dark > 0.3 { lights.append((x + 10, GY - 13, 18)) }
            top = 28
        case .fire:
            rig(.minivan, x - 62, GY, 0, -1)
            rig(.van, x + 70, GY, 1, 1)
            fire(x, GY + 3)
            person(x - 16, GY + 3, 1, 1, 0, false)
            person(x + 15, GY + 3, 3, -1, 0, false)
            person(x + 24, GY + 2, 2, -1, 0, false)
            top = 34
        case .host:
            // the camp host's trailer, a flag and a sign
            let tc = Col(0xefe9dc)
            c.RR(x - 34, GY - 26, 46, 21, 6, tc)
            c.R(x - 34, GY - 14, 46, 1.6, Col(0x3a6ea5))
            c.RR(x - 28, GY - 22, 9, 6, 1, GLASS); c.RR(x + 1, GY - 22, 7, 6, 1, GLASS)
            c.R(x - 14, GY - 22, 7, 16, tc.shade(0.88))
            c.seg(x + 12, GY - 8, x + 18, GY - 3, 1, Col(0x4a4a4a))
            wheelAt(x - 14, GY, 3.6)
            c.R(x + 22, GY - 40, 0.8, 40, Col(0xb8b8b4))
            for j in 0..<4 { c.R(x + 23, GY - 40 + Double(j) * 2, 10 + sin(NOW * 3 + Double(j)) * 0.6, 1, j % 2 == 0 ? Col(0xc8281e) : Col(0xf4f4f0)) }
            c.R(x + 23, GY - 40, 4, 4, Col(0x2a3a7a))
            c.R(x - 46, GY - 14, 0.8, 14, wood); c.RR(x - 54, GY - 21, 17, 8, 1, Col(0x5a4a3a))
            g.text("HOST", x - 45.5, GY - 17, 3.8, CREAM, bold: true)
            top = 48
        case .outhouse:
            outhouse(x, GY, 1)
            top = 40
        case .board:
            c.R(x - 15, GY - 28, 1.8, 28, wood); c.R(x + 13.2, GY - 28, 1.8, 28, wood)
            c.poly(Col(0x5a3e24), [x - 21, GY - 38, x, GY - 43, x + 21, GY - 38])
            c.R(x - 19, GY - 38, 38, 19, wood)
            c.R(x - 17.5, GY - 36.5, 35, 16, Col(0xc49a68))
            let paper: [Col] = [Col(0xf4f1ea), Col(0xf2e08a), Col(0xa8d8e8), Col(0xf4c4c4), Col(0xf4f1ea), Col(0xc8e8b0)]
            for j in 0..<6 {
                let d = Double(j)
                let fx = x - 16 + d * 5.6 + hashN(d + 7) * 1.2
                let fy = GY - 35 + hashN(d + 3) * 5
                c.R(fx, fy, 4.4, 5.4 + sin(NOW * 2 + d) * 0.3, paper[j])
                c.circ(fx + 2.2, fy + 0.4, 0.5, REDC)
            }
            if g.phase == .play && g.adDays > 0 {
                c.R(x - 5, GY - 30, 10, 8, GOLD)
                g.text("YOU", x, GY - 26, 3.4, INK, bold: true)
            }
            top = 50
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
            label = false
            top = 66
        case .skoolie:
            if g.phase == .play && !g.on(EV_SKOOL) {
                c.R(x - 1, GY - 22, 2, 22, wood)
                c.RR(x - 34, GY - 36, 68, 16, 2, Col(0x7a5a3a))
                g.text("SKOOLIEPALOOZA", x, GY - 31, 5, GOLD, bold: true)
                g.text("Jan 16–26 (projected)", x, GY - 25, 3.6, CREAM)
                label = false
                top = 44
                break
            }
            rig(.skoolie, x - 58, GY, 2, -1)
            // a painted awning off the bus, a table of skulls, antlers and bottles, and prayer flags
            c.seg(x + 30, GY, x + 30, GY - 24, 1, wood)
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
            g.text("Be nice · leave no trace · pay it forward", x - 30, GY - 47, 4, CREAM.alpha(0.9))
            label = false
            top = 46
        case .hall:
            // Town Hall: adobe with a parapet and a flag
            let adobe = Col(0xd9b48a)
            c.R(x - 40, GY - 32, 80, 32, adobe)
            c.R(x - 42, GY - 36, 84, 5, adobe.shade(1.08))
            c.R(x - 12, GY - 40, 24, 5, adobe.shade(1.08))
            for j in 0..<6 { c.R(x - 36 + Double(j) * 14, GY - 30, 1.4, 2, Col(0x6a4a2a)) }
            c.R(x - 7, GY - 22, 14, 22, Col(0x5a3a22)); c.R(x - 0.3, GY - 22, 0.6, 22, Col(0x3a2414))
            c.R(x - 33, GY - 22, 14, 10, GLASS); c.R(x + 19, GY - 22, 14, 10, GLASS)
            g.text("TOWN HALL", x, GY - 29, 4.6, Col(0x5a3a22), bold: true)
            c.R(x + 48, GY - 48, 0.8, 48, Col(0xb8b8b4))
            for j in 0..<4 { c.R(x + 49, GY - 48 + Double(j) * 2, 10 + sin(NOW * 3 + Double(j)) * 0.6, 1, j % 2 == 0 ? Col(0xc8281e) : Col(0xf4f4f0)) }
            c.R(x + 49, GY - 48, 4, 4, Col(0x2a3a7a))
            label = false
            top = 50
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
        case .rides:
            c.seg(x - 40, GY, x - 40, GY - 30, 1, Col(0xdddddd))
            c.seg(x + 40, GY, x + 40, GY - 30, 1, Col(0xdddddd))
            c.RR(x - 30, GY - 40, 60, 11, 2, Col(0x2a2a2e))
            g.text("RIDES FOR SALE", x, GY - 34.4, 4.8, GOLD, bold: true)
            let shown = g.phase == .play ? min(g.toy + 1, TOYS.count - 1) : 5
            toy(shown, x + 6, GY + 2, -1, -1, 0)
            label = false
            top = 46
        case .station:
            // the La Posa South dump lanes and water faucets
            c.R(x - 30, GY - 1, 60, 1.6, Col(0x8a8580))
            c.R(x - 4, GY - 1.6, 8, 1, Col(0x3a3a3a))
            for side in [-18.0, 18.0] {
                c.R(x + side - 0.8, GY - 14, 1.6, 14, Col(0x4a6a8a))
                c.R(x + side - 3, GY - 15, 6, 1.6, Col(0x4a6a8a))
                c.circ(x + side, GY - 12, 1.4, Col(0x2a6aa8))
            }
            c.R(x - 1, GY - 26, 1.6, 26, Col(0x8a8f96)); c.RR(x - 16, GY - 34, 32, 9, 1.4, Col(0x2a5a8a))
            g.text("DUMP · WATER", x, GY - 29.6, 3.6, CREAM, bold: true)
            label = false
            top = 42
        case .gemworld:
            // Gem World on Main Street, with its wheel-rim camel out front
            let wall = Col(0xe8dcc4)
            c.R(x - 36, GY - 30, 72, 30, wall)
            c.RR(x - 30, GY - 44, 60, 12, 2, Col(0x6a3a7a))
            g.text("GEM WORLD", x, GY - 38, 6, CREAM, bold: true)
            c.R(x - 6, GY - 20, 12, 20, Col(0x4a3424))
            c.R(x - 30, GY - 22, 18, 10, GLASS); c.R(x + 12, GY - 22, 18, 10, GLASS)
            for j in 0..<4 { gem(x - 27 + Double(j) * 4.4, GY - 13, 1.4, [Col(0x9a5ad0), Col(0xf0f0f4), Col(0xe2742e), Col(0x2fa7a0)][j]) }
            let rim = Col(0x7a2a1e)
            c.ellStroke(x + 48, GY - 13, 6, 4, 1, rim); c.ellStroke(x + 46, GY - 18, 2.4, 2.4, 0.9, rim)
            c.seg(x + 53, GY - 15, x + 57, GY - 22, 1, rim); c.ellStroke(x + 58, GY - 23, 2, 1.2, 0.8, rim)
            for q in [43.0, 46.0, 50.0, 53.0] { c.seg(x + q, GY - 10, x + q, GY, 0.8, rim) }
            label = false
            top = 52
        case .park:
            // Town Park: shade ramadas and palms; banners and a crowd during the Rubber Tramp Rendezvous
            let rtr = g.phase == .play && g.on(EV_RTR)
            for side in [-22.0, 22.0] {
                c.R(x + side - 12, GY - 16, 1, 16, Col(0x8a8f96)); c.R(x + side + 11, GY - 16, 1, 16, Col(0x8a8f96))
                c.poly(Col(0x4f7a6a), [x + side - 15, GY - 16, x + side, GY - 22, x + side + 15, GY - 16])
                c.R(x + side - 8, GY - 7, 16, 1.4, wood)
            }
            palm(x - 48, GY + 1, 46, 3); palm(x + 50, GY + 1, 52, 7)
            if rtr {
                c.R(x - 30, GY - 36, 60, 9, Col(0x3f8f8a))
                g.text("RUBBER TRAMP RENDEZVOUS", x, GY - 31.4, 3.6, CREAM, bold: true)
                for j in 0..<6 { person(x - 30 + Double(j) * 12, GY + 2, j % 4, j % 2 == 0 ? 1 : -1, 0, false) }
                label = false
            }
            top = 44
        case .yacht:
            // the Quartzsite Yacht Club: a desert bar with a boat on the roof sign
            let wall = Col(0x3a6ea5)
            c.R(x - 34, GY - 26, 68, 26, wall)
            c.R(x - 34, GY - 28, 68, 2, Col(0xf4f4f0))
            c.poly(Col(0xf4f4f0), [x - 18, GY - 34, x + 18, GY - 34, x + 12, GY - 29, x - 12, GY - 29])
            c.seg(x, GY - 34, x, GY - 46, 0.8, Col(0xf4f4f0)); c.poly(Col(0xf4f4f0), [x + 0.6, GY - 45, x + 10, GY - 36, x + 0.6, GY - 36])
            g.text("YACHT CLUB", x, GY - 21, 4.6, CREAM, bold: true)
            c.R(x - 6, GY - 15, 12, 15, Col(0x2a2018))
            c.R(x - 28, GY - 15, 14, 8, GLASS); c.R(x + 14, GY - 15, 14, 8, GLASS)
            if dark > 0.3 { lights.append((x, GY - 12, 30)) }
            label = false
            top = 54
        case .panorama:
            // Prospectors Panorama: gems, gold and prospecting gear, January into February
            let open = g.phase != .play || g.on(EV_PAN)
            canopy(x, 34, Col(0xe8d08a), Col(0x7a4a2a))
            if open {
                c.R(x - 28, GY - 10, 56, 10, Col(0x4a3a2a))
                c.circ(x - 16, GY - 12, 4.6, Col(0x6a6a6a)); c.circ(x - 16, GY - 12, 3.4, Col(0x8a8a86)); c.circ(x - 16, GY - 12, 1.2, GOLD)
                c.seg(x + 6, GY - 10, x + 2, GY - 24, 0.8, Col(0x2a2a2a)); c.ell(x + 6.6, GY - 10.4, 3.4, 1, Col(0x2a2a2a))
                c.seg(x + 16, GY - 10, x + 12, GY - 24, 0.8, Col(0x2a2a2a)); c.ell(x + 16.6, GY - 10.4, 3.4, 1, Col(0x2a2a2a))
            }
            top = 46
        case .vendors:
            // the Tyson Wells grounds: rows of canopies on show days, an empty lot between shows
            let show: Int? = g.phase == .play ? g.tysonShow() : Optional(EV_GEM)
            if let e = show {
                for j in 0..<3 {
                    let cx = x - 46 + Double(j) * 46
                    canopy(cx, 20, [Col(0xf4f1ea), Col(0x3a6ea5), Col(0xd9412e)][j], Col(0xf2c14e))
                    c.R(cx - 16, GY - 9, 32, 9, Col(0x4a3a4a))
                    for q in 0..<5 {
                        let gx = cx - 13 + Double(q) * 6.4
                        if e == EV_GEM { gem(gx, GY - 9, 1.8 + hashN(Double(q + j * 5)) * 1.2, [Col(0x9a5ad0), Col(0xf0f0f4), Col(0xe2742e), Col(0x2fa7a0), Col(0xd04a6a)][q]) }
                        else if e == EV_SELL { c.R(gx - 1.8, GY - 13, 3.6, 4, [Col(0x8a6a4a), Col(0x5a6a7a), Col(0xb8b8b4), Col(0x7a4a3a), Col(0x3a5a3a)][q]) }
                        else { c.R(gx - 2, GY - 14, 4, 5, [Col(0xd9412e), Col(0xf2c14e), Col(0x3f8f8a), Col(0x9a5ad0), Col(0xf4f1ea)][q]) }
                    }
                    person(cx + 8, GY + 3, (j + 1) % 4, -1, 0, false)
                }
                g.text(EVENTS[e].name.uppercased(), x, GY - 46, 4.6, GOLD, bold: true)
                label = false
                top = 52
            } else {
                c.R(x - 1, GY - 22, 2, 22, wood)
                c.RR(x - 30, GY - 36, 60, 16, 2, Col(0x7a5a3a))
                g.text("TYSON WELLS", x, GY - 31, 5, CREAM, bold: true)
                g.text("Next: " + g.nextOf([EV_GEM, EV_SELL, EV_CRAFT]), x, GY - 25, 3.2, CREAM, wrap: 56)
                label = false
                top = 44
            }
        case .office:
            let tc = Col(0xefe9dc)
            c.RR(x - 22, GY - 22, 44, 18, 4, tc)
            c.RR(x - 16, GY - 19, 10, 6, 1, GLASS)
            c.R(x + 2, GY - 19, 8, 15, tc.shade(0.88))
            c.R(x - 22, GY - 12, 44, 1.4, Col(0x3a6ea5))
            wheelAt(x - 8, GY, 3.4)
            c.RR(x - 18, GY - 30, 36, 7, 1, Col(0x2a2a2e))
            g.text("SHOW OFFICE", x, GY - 26.4, 3.6, GOLD, bold: true)
            label = false
            top = 38
        case .booth:
            if g.phase == .play && !g.boothOpen(i) {
                c.R(x - 14, GY - 1, 28, 1, Col(0xb48a5a))
                for q in [-14.0, 14.0] { c.R(x + q - 0.5, GY - 3, 1, 3, Col(0xd9412e)) }
                top = 28
                break
            }
            canopy(x, 22, Col(0x9a5ad0), Col(0xf4f1ea))
            c.R(x - 16, GY - 9, 32, 9, Col(0x7a2f3a))
            c.R(x - 17, GY - 10, 34, 1.4, Col(0x9a4a54))
            for j in 0..<g.rocks { gem(x - 12 + Double(j) * 5, GY - 10, 2.2, [Col(0x9a5ad0), Col(0xe2742e), Col(0x2fa7a0)][j % 3]) }
            for j in 0..<g.odd { skull(x + 3 + Double(j) * 5, GY - 10, 0.65) }
            for j in 0..<g.jewelry { c.curve(x - 14 + Double(j) * 4, GY - 10, x - 12 + Double(j) * 4, GY - 15, x - 10 + Double(j) * 4, GY - 10, 0.4, Col(0xd9b46a)) }
            top = 40
        case .bigtent:
            if g.phase != .play || g.on(EV_RV) {
                // the Big Tent: a long white show tent with peaks and flags
                let tw = Col(0xf4f4f0).shade(1 - dark * 0.4)
                c.R(x - 90, GY - 30, 180, 30, tw)
                for j in 0..<4 {
                    let px0 = x - 90 + Double(j) * 45
                    c.poly(tw.shade(0.96), [px0, GY - 30, px0 + 22.5, GY - 48, px0 + 45, GY - 30])
                    c.seg(px0 + 22.5, GY - 48, px0 + 22.5, GY - 58, 0.6, Col(0x8a8a8a))
                    c.poly([Col(0xd9412e), Col(0x3a6ea5), Col(0xf2c14e), Col(0x4f9a5a)][j], [px0 + 23, GY - 58, px0 + 31 + sin(NOW * 3 + Double(j)) * 0.8, GY - 55.5, px0 + 23, GY - 53])
                }
                for j in 0..<9 { c.R(x - 88 + Double(j) * 20, GY - 30, 0.8, 30, Col(0xcfcfc8)) }
                c.R(x - 14, GY - 22, 28, 22, Col(0x3a3a3e))
                c.RR(x - 46, GY - 28, 92, 8, 2, Col(0xb5452f))
                g.text("SPORTS, VACATION & RV SHOW", x, GY - 24, 3.8, CREAM, bold: true)
                if g.phase == .play, let nx = g.nextRig() { rig(nx, x + 140, GY, 2, -1) }
                label = false
                top = 66
            } else {
                c.R(x - 1, GY - 22, 2, 22, wood)
                c.RR(x - 34, GY - 36, 68, 16, 2, Col(0x7a5a3a))
                g.text("THE BIG TENT", x, GY - 31, 5, CREAM, bold: true)
                g.text("RV Show " + EVENTS[EV_RV].when, x, GY - 25, 3.6, CREAM)
                label = false
                top = 44
            }
        case .cabin:
            let woodD = Col(0x6a4a2e).shade(1 - dark * 0.35)
            c.R(x - 24, GY - 22, 34, 22, woodD)
            c.poly(Col(0x4a3420).shade(1 - dark * 0.35), [x - 27, GY - 22, x - 7, GY - 31, x + 13, GY - 22])
            c.R(x - 11, GY - 15, 8, 15, Col(0x241810))
            c.R(x - 20, GY - 16, 6, 6, Col(0x1c1410))
            let st = Col(0x9a8a78).shade(1 - dark * 0.35)
            c.RR(x + 16, GY - 14, 18, 14, 2, st)
            c.R(x + 15, GY - 15, 20, 2, st.shade(0.8))
            top = 38
        case .circle:
            if g.phase == .play && !g.on(EV_SKOOL) { top = 28; label = false; break }
            fire(x, GY + 3)
            for j in 0..<6 {
                let a = Double(j) / 6 * PI * 2
                person(x + cos(a) * 22, GY + 2 + sin(a) * 1.5, j % 4, cos(a) > 0 ? -1 : 1, 0, false)
            }
            c.R(x + 30, GY - 8, 18, 1.4, wood); c.R(x + 31, GY - 6.6, 1, 6.6, wood); c.R(x + 46, GY - 6.6, 1, 6.6, wood)
            for q in 0..<4 { c.ell(x + 34 + Double(q) * 3.6, GY - 9, 1.6, 0.9, [Col(0xd9412e), Col(0xf2c14e), Col(0x6aa84a), Col(0xb5651d)][q]) }
            top = 36
        case .mine:
            // the Gold Eye: a timbered adit in a rocky hillside, an ore cart on its rails
            let rock = Col(0x8a6248).shade(1 - dark * 0.4)
            c.poly(rock, [x - 70, GY + 1, x - 46, GY - 34, x - 16, GY - 52, x + 20, GY - 46, x + 50, GY - 24, x + 72, GY + 1])
            c.poly(rock.shade(0.86), [x + 20, GY - 46, x + 50, GY - 24, x + 72, GY + 1, x + 34, GY + 1])
            for j in 0..<9 { let d = Double(j); c.ell(x - 50 + d * 12, GY - 6 - hashN(d + 40) * 18, 3 + hashN(d + 41) * 3, 1.6, rock.shade(0.75)) }
            c.arch(x - 9, GY - 26, 18, 26, Col(0x120c08))
            c.R(x - 11, GY - 27, 2.6, 27, Col(0x6a4a2a)); c.R(x + 8.4, GY - 27, 2.6, 27, Col(0x6a4a2a))
            c.R(x - 13, GY - 29, 26, 3, Col(0x7a5632))
            c.R(x + 6, GY - 1.2, 40, 0.8, Col(0x4a4a4a)); c.R(x + 6, GY + 0.6, 40, 0.8, Col(0x4a4a4a))
            c.poly(Col(0x6a5a4a), [x + 20, GY - 9, x + 34, GY - 9, x + 32, GY - 2, x + 22, GY - 2])
            c.circ(x + 24, GY - 1.4, 1.6, TIRE); c.circ(x + 30, GY - 1.4, 1.6, TIRE)
            c.R(x - 34, GY - 14, 0.8, 14, wood); c.RR(x - 44, GY - 22, 20, 9, 1, Col(0xe8dcc4))
            g.text("GOLD EYE", x - 34, GY - 17.6, 3.6, REDC, bold: true)
            top = 62
        case .detect:
            // old placer diggings: spoil piles and a cabin with the roof gone
            for j in 0..<4 { let d = Double(j); c.ell(x - 30 + d * 18, GY, 8 + hashN(d + 60) * 4, 4 + hashN(d + 61) * 3, Col(0xb99068)) }
            c.R(x + 22, GY - 16, 1.6, 16, Col(0x5a4230)); c.R(x + 40, GY - 13, 1.6, 13, Col(0x5a4230))
            c.R(x + 22, GY - 9, 20, 1.4, Col(0x5a4230)); c.R(x + 24, GY - 5, 16, 1.4, Col(0x5a4230))
            c.seg(x + 22, GY - 16, x + 34, GY - 20, 1.2, Col(0x5a4230))
            c.R(x - 4, GY - 3, 8, 1.2, Col(0x7a6a5a))
            top = 34
        case .rockhound:
            let rock = Col(0x9a6a4e).shade(1 - dark * 0.4)
            c.poly(rock, [x - 50, GY + 1, x - 20, GY - 22, x + 14, GY - 18, x + 48, GY + 1])
            let stones: [Col] = [Col(0xd8d4cc), Col(0xc85a3a), Col(0x7a5aa0), Col(0xe2c070), Col(0x5a8a6a), Col(0xf0f0f0)]
            for j in 0..<14 { let d = Double(j); gem(x - 40 + d * 6, GY - 2 - hashN(d + 80) * 12, 1 + hashN(d + 81) * 1.2, stones[j % 6]) }
            c.seg(x + 30, GY - 4, x + 36, GY - 14, 0.9, Col(0x6a4a2a)); c.R(x + 34, GY - 15.6, 5, 1.6, Col(0x5a5a5a))
            top = 36
        case .landmark:
            if sp.arg == 0 {
                // Hi Jolly's tomb: a stone pyramid with a copper camel on top
                let st = Col(0xc8b8a0)
                c.poly(st, [x - 13, GY, x - 4, GY - 30, x + 4, GY - 30, x + 13, GY])
                for j in 0..<22 { let d = Double(j); let yy = hashN(d + 90) * 28; let w2 = 12 - yy * 0.3; c.ell(x + (hashN(d + 91) - 0.5) * 2 * w2, GY - 2 - yy, 1.6, 1.1, hashN(d + 92) < 0.5 ? st.shade(0.82) : Col(0xf0ece4)) }
                let cu = Col(0x8a5a3a)
                c.ell(x, GY - 36, 5, 2.4, cu); c.circ(x - 1, GY - 38.4, 2, cu)
                c.seg(x + 4, GY - 36, x + 6.4, GY - 41, 1.1, cu); c.ell(x + 7.2, GY - 41.4, 1.6, 0.9, cu)
                for q in [-3.4, -1.6, 1.8, 3.4] { c.seg(x + q, GY - 35, x + q, GY - 30.6, 0.7, cu) }
                c.R(x - 6, GY - 10, 12, 5, Col(0x6a5040)); g.text("HI JOLLY", x, GY - 7.6, 2.6, CREAM, bold: true)
                top = 52
            } else if sp.arg == 1 {
                // Reader's Oasis: the desert bookstore with tables of books out front
                let wall = Col(0xe2d2b4)
                c.R(x - 34, GY - 30, 68, 30, wall)
                c.poly(Col(0x9a4a3a), [x - 38, GY - 30, x - 30, GY - 38, x + 30, GY - 38, x + 38, GY - 30])
                c.RR(x - 26, GY - 47, 52, 10, 2, Col(0x2f5a4a))
                g.text("READER'S OASIS", x, GY - 42, 4.6, CREAM, bold: true)
                c.R(x - 6, GY - 20, 12, 20, Col(0x4a3424))
                let spines: [Col] = [Col(0xb5452f), Col(0x3a6ea5), Col(0xf2c14e), Col(0x3f8f8a), Col(0x7a4a8a), Col(0xe8dcc4)]
                for side in [-1.0, 1.0] {
                    let tx = x + side * 22
                    c.R(tx - 9, GY - 8, 18, 1.4, wood)
                    c.R(tx - 8, GY - 6.6, 1, 6.6, wood); c.R(tx + 7, GY - 6.6, 1, 6.6, wood)
                    for j in 0..<8 { c.R(tx - 8 + Double(j) * 2, GY - 8 - 3.6 - hashN(Double(j) + side * 9) * 1.4, 1.6, 3.6 + hashN(Double(j) + side * 9) * 1.4, spines[j % 6]) }
                }
                label = false
                top = 56
            } else if sp.arg == 2 {
                // Tyson's Well: the 1864 stage stop, marked by a plaque on a stone base
                c.R(x - 8, GY - 12, 16, 12, Col(0xa89880))
                for j in 0..<10 { let d = Double(j); c.ell(x - 6 + hashN(d + 140) * 12, GY - 2 - hashN(d + 141) * 9, 1.8, 1.2, Col(0x8a7a64)) }
                c.RR(x - 6, GY - 20, 12, 9, 1, Col(0x6a4a2a))
                c.RR(x - 5, GY - 19, 10, 7, 0.6, Col(0x9a7a3a))
                g.text("1864", x, GY - 15.4, 3, CREAM, bold: true)
                c.seg(x + 16, GY, x + 16, GY - 18, 0.9, wood); c.seg(x + 26, GY, x + 26, GY - 18, 0.9, wood)
                c.R(x + 14, GY - 19, 14, 1.4, wood); c.R(x + 18, GY - 12, 6, 12, Col(0x6a6a6a))
                top = 34
            } else {
                // the old Ehrenberg pioneer cemetery: a wooden arch, rock-covered graves, a few crosses
                c.seg(x - 24, GY, x - 24, GY - 26, 1.2, wood); c.seg(x + 24, GY, x + 24, GY - 26, 1.2, wood)
                c.R(x - 26, GY - 28, 52, 3, wood)
                g.text("PIONEER CEMETERY", x, GY - 32, 3.6, CREAM, bold: true)
                for j in 0..<5 {
                    let gx = x - 18 + Double(j) * 9
                    c.ell(gx, GY - 0.5, 3.6, 1.6, Col(0xb8a088))
                    c.R(gx - 0.4, GY - 7, 0.8, 6, Col(0xd8d0c0)); c.R(gx - 2, GY - 5.4, 4, 0.8, Col(0xd8d0c0))
                }
                label = false
                top = 40
            }
        case .river:
            c.seg(x - 4, GY, x - 2, GY - 7, 0.8, Col(0xb8b8b4)); c.seg(x + 4, GY, x + 2, GY - 7, 0.8, Col(0xb8b8b4))
            c.R(x - 4, GY - 7.6, 8, 1.4, Col(0x3a8a6a)); c.R(x - 3.6, GY - 13, 1.2, 6, Col(0x3a8a6a))
            c.RR(x + 7, GY - 5, 7, 5, 1, Col(0xd8412e)); c.R(x + 7, GY - 5, 7, 1.2, Col(0xf4f4f0))
            top = 30
        }
        if label && !near {
            g.text(sp.name, x, GY - top, 5, CREAM.alpha(0.8), bold: true)
        }
    }

    /// A concrete vault toilet like the ones at the LTVA.
    private func outhouse(_ x: Double, _ base: Double, _ s: Double) {
        if x < -30 || x > W + 30 { return }
        c.save()
        c.translate(x, base)
        c.scale(s, s)
        let wall = Col(0xcdb894).shade(1 - dark * 0.4)
        c.R(-12, -26, 24, 26, wall)
        var y = -26.0
        while y < 0 { c.R(-12, y, 24, 0.4, wall.shade(0.88)); y += 3 }
        c.poly(Col(0x6a4a34), [-15, -26, 0, -31, 15, -26])
        c.R(6, -36, 2.2, 8, Col(0x2a2a2a))
        c.R(-6, -21, 11, 21, Col(0x7a5a44))
        c.R(-4, -17, 3, 3, Col(0x2a4a8a))
        c.R(-12, -2, 24, 2, wall.shade(0.8))
        c.restore()
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

        var pack = dateText(g.day) + "  ·  " + g.areaName(g.area)
        if g.wood > 0 { pack += "  ·  firewood \(g.wood)" }
        if g.jewelry > 0 { pack += "  ·  pendants \(g.jewelry)" }
        if g.rocks > 0 { pack += "  ·  specimens \(g.rocks)" }
        if g.odd > 0 { pack += "  ·  oddities \(g.odd)" }
        g.text(pack, r, 12, 5.5, CREAM, align: 2, bold: true, plate: true)
        // the map button
        c.RR(r - 30, 24, 30, 13, 6.5, Col(0x1c1410, 0.68))
        c.arcStroke(r - 22, 30.5, 3.2, 0, PI * 2, 0.8, GOLD)
        c.poly(GOLD, [r - 22, 34.6, r - 24.4, 31.4, r - 19.6, 31.4])
        g.text("MAP", r - 11, 30.5, 5, CREAM, bold: true)
        g.hits.append(Hit(id: 60, x: r - 36, y: 20, w: 40, h: 22))

        // the pad and the hold button
        let py = H - 24
        let pxc = g.safeL + 40
        c.RR(pxc - 30, py - 9, 60, 18, 9, Col(0xffffff, 0.13))
        c.circ(pxc + g.input.stick * 20, py, 8, Col(0xffffff, 0.4))
        let bx = W - g.safeR - 34
        c.circ(bx, py, 13, Col(0xffffff, g.input.hold ? 0.34 : 0.14))
        c.arcStroke(bx, py, 13, 0, PI * 2, 1, Col(0xffffff, 0.45))
        g.text("HOLD", bx, py, 4.6, CREAM.alpha(0.85), bold: true)

        if g.arriveT > 0 {
            let a = clampD(min(g.arriveT, (4.5 - g.arriveT) * 2), 0, 1)
            let d = AREAS[g.area.rawValue]
            g.text(d.name.uppercased(), W / 2, H * 0.3, 17, CREAM.alpha(a), bold: true)
            g.text(d.sub, W / 2, H * 0.3 + 15, 6.5, GOLD.alpha(a), bold: true)
        }
        if g.hintT > 0 {
            g.text(g.hintText, W / 2, H - 22, 5.4, CREAM.alpha(clampD(g.hintT, 0, 1)), wrap: W * 0.46, plate: true)
        }
    }

    /// The travel map: a sketch of Quartzsite with the five places, how you'd get to each, and the event calendar.
    private func mapOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.55))
        let x0 = g.safeL + 14, x1 = W - g.safeR - 14, y0 = 8.0, y1 = H - 8
        let paper = Col(0xeadfc4), ink = Col(0x3a2c1e)
        c.RR(x0, y0, x1 - x0, y1 - y0, 6, paper)
        g.text("WHERE TO?", x0 + 10, y0 + 10, 8, ink, align: 1, bold: true)
        g.text(dateText(g.day), x0 + 70, y0 + 10, 5.6, ink.alpha(0.7), align: 1, bold: true)
        // close
        c.circ(x1 - 11, y0 + 10, 6, ink.alpha(0.12))
        c.seg(x1 - 14, y0 + 7, x1 - 8, y0 + 13, 1, ink); c.seg(x1 - 8, y0 + 7, x1 - 14, y0 + 13, 1, ink)
        g.hits.append(Hit(id: 62, x: x0, y: y0, w: x1 - x0, h: y1 - y0))
        g.hits.append(Hit(id: 61, x: x1 - 22, y: y0, w: 22, h: 22))

        // the sketch map
        let mx0 = x0 + 10, my0 = y0 + 22, mw = (x1 - x0) * 0.5, mh = y1 - y0 - 58
        c.RR(mx0, my0, mw, mh, 3, Col(0xe2cfa4))
        let lonA = -114.42, lonB = -114.13, latA = 33.605, latB = 33.69
        func mp(_ lat: Double, _ lon: Double) -> (Double, Double) {
            return (mx0 + (lon - lonA) / (lonB - lonA) * mw, my0 + (latB - lat) / (latB - latA) * mh)
        }
        // the Dome Rock Mountains and the river side
        let dr = mp(33.635, -114.345)
        c.ell(dr.0, dr.1, 16, 7, Col(0xb48a62)); c.ell(dr.0 + 6, dr.1 - 2, 9, 5, Col(0xa47a52))
        c.curve(mx0 + 3, my0 + 4, mx0 + 8, my0 + mh * 0.5, mx0 + 2, my0 + mh - 4, 1.6, Col(0x4a86b0))
        // I-10 and Highway 95
        let road = Col(0x6a5a4a)
        let i10: [(Double, Double)] = [(33.622, -114.42), (33.648, -114.33), (33.662, -114.25), (33.664, -114.18), (33.655, -114.13)]
        for k in 0..<(i10.count - 1) {
            let a = mp(i10[k].0, i10[k].1), b = mp(i10[k + 1].0, i10[k + 1].1)
            c.seg(a.0, a.1, b.0, b.1, 1.6, road)
        }
        let n95 = mp(33.69, -114.216), s95 = mp(33.605, -114.216)
        c.seg(n95.0, n95.1, s95.0, s95.1, 1.2, road)
        let lab10 = mp(33.652, -114.29), lab95 = mp(33.60 + 0.02, -114.211)
        g.text("I-10", lab10.0, lab10.1 - 5, 3.6, ink.alpha(0.6), bold: true)
        g.text("95", lab95.0 + 4, lab95.1, 3.6, ink.alpha(0.6), bold: true)
        g.text("to the river", mx0 + 14, my0 + mh - 6, 3.2, Col(0x2a5a80), align: 1)
        for a in AREAS.indices {
            let d = AREAS[a]
            let p = mp(d.lat, d.lon)
            let here = a == g.area.rawValue
            if here { c.circ(p.0, p.1, 5 + sin(NOW * 4) * 0.8, GOLD.alpha(0.5)) }
            c.circ(p.0, p.1, 2.6, here ? GOLD : REDC)
            c.circ(p.0, p.1, 1, CREAM)
            let off: [(Double, Double, Int)] = [(-4, 4, 2), (4, -5, 1), (-4, 4, 2), (0, -6, 0), (0, 6, 0), (0, 6, 0), (0, -6, 0)]
            g.text(d.name, p.0 + off[a].0, p.1 + off[a].1, 3.6, ink, align: off[a].2, bold: true)
        }

        // the list of places: tap one to go
        let lx = mx0 + mw + 10, lw = x1 - 10 - lx
        let how: String = g.inRig ? "In your " + RIGS[g.rig.rawValue].name.lowercased() : (g.onToy ? "On your " + TOYS[g.toy].name.lowercased() : "On foot: Camel Express dial-a-ride")
        g.text(how, lx, y0 + 24, 4.4, ink.alpha(0.75), align: 1, bold: true)
        let rowH = (mh - 6) / Double(AREAS.count)
        for a in AREAS.indices {
            let to = Area(rawValue: a) ?? .main
            let ry = my0 + 8 + Double(a) * rowH
            let t = g.trip(to)
            let here = to == g.area
            c.RR(lx, ry, lw, rowH - 3, 3, here ? GOLD.alpha(0.35) : (t.ok ? Col(0xffffff, 0.45) : ink.alpha(0.08)))
            g.text(AREAS[a].name, lx + 5, ry + rowH * 0.32, 5, ink.alpha(t.ok || here ? 1 : 0.5), align: 1, bold: true)
            var sub: String
            if here { sub = "You're here" }
            else if t.ok { let m = milesBetween(g.area, to); sub = (m == m.rounded() ? "\(Int(m))" : "\(m)") + " mi · " + (t.cost == 0 ? "free" : "$\(t.cost)") }
            else { sub = t.how }
            g.text(sub, lx + 5, ry + rowH * 0.68, 3.8, t.ok ? Col(0x2f6a3a) : REDC.shade(0.8), align: 1)
            if !here { g.hits.append(Hit(id: 70 + a, x: lx, y: ry, w: lw, h: rowH - 3)) }
        }

        // the calendar
        var now: [String] = []
        for e in EVENTS.indices where g.on(e) && e != EV_PAN { now.append(EVENTS[e].name) }
        var next: [Int] = []
        for e in EVENTS.indices where EVENTS[e].start > g.day && e != EV_PAN { next.append(e) }
        next.sort { EVENTS[$0].start < EVENTS[$1].start }
        let cy = y1 - 28
        g.text("Happening now: " + (now.isEmpty ? "nothing big this week" : now.joined(separator: ", ")), x0 + 10, cy, 4.4, ink, align: 1, bold: true, wrap: x1 - x0 - 20)
        if !next.isEmpty {
            let up = next.prefix(2).map { EVENTS[$0].name + " (" + EVENTS[$0].when + ", " + AREAS[EVENTS[$0].area.rawValue].name + ")" }
            g.text("Coming up: " + up.joined(separator: " · "), x0 + 10, cy + 11, 4, ink.alpha(0.75), align: 1, wrap: x1 - x0 - 20)
        }
        if g.mapMsgT > 0 {
            g.text(g.mapMsg, (x0 + x1) / 2, my0 + mh * 0.5, 6, CREAM.alpha(clampD(g.mapMsgT, 0, 1)), bold: true, plate: true)
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
