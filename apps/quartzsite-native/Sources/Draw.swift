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
            if g.driving { driveScene(); return }
            cam = g.cam
            scene(g.dayT)
            hud()
            if g.mapOpen { mapOverlay() }
            if g.browseOpen { browseOverlay() }
            if g.seasonCard { seasonOverlay() }
            if g.ended { endOverlay() }
            if g.inCine { cinematic() }
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

        // clouds: a few on clear days, a grey ceiling when it rains
        let wx = g.phase == .play ? g.weather : 0
        if wx >= 2 { c.R(0, 0, W, GY, Col(0x5a6274, wx == 3 ? 0.5 : 0.28)) }
        clouds(wx, sk.1)

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
        if ar == .ltva || ar == .dome || ar == .trail || ar == .scaddan || ar == .roadrunner {
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
        if ar == .trail && g.phase == .play {
            var pts: [Double] = [0, GY + 3]
            var x = 0.0
            while x <= W + 4 { pts.append(x); pts.append(GY + g.ground(x + cam)); x += 4 }
            pts.append(W + 4); pts.append(GY + 3)
            c.poly(Col(0xc9a372), pts)
            x = 0
            while x <= W { c.R(x, GY + g.ground(x + cam) - 0.4, 4.4, 0.9, Col(0xe0c49a)); x += 4 }
        }
        if !paved {
            var r0 = floor((cam - 40) / 90)
            while r0 * 90 < cam + W + 40 {
                if hashN(r0 + 2100 + seed) < 0.55 { rock(r0 * 90 + hashN(r0 + 2110) * 60 - cam, GY + 2 + hashN(r0 + 2120) * 3, 1.6 + hashN(r0 + 2130) * 2.6) }
                r0 += 1
            }
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
                else if k < 0.3 { saguaro(sx, GY + 1, 26 + hashN(n + 5) * 20, n, SAG, true) }
                else if k < 0.48 { cholla(sx, GY + 1, 0.8 + hashN(n + 6) * 0.5, n) }
                else if k < 0.62 { creosote(sx, GY + 1, n) }
                else if k < 0.72 { ocotillo(sx, GY + 1, n) }
                else if k < 0.8 { barrel(sx, GY + 1, 0.9 + hashN(n + 8) * 0.5, n) }
                else if k < 0.88 { beavertail(sx, GY + 1, n) }
                else { paloverde(sx, GY + 1, n) }
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
            if g.phase == .play { critters(ar) }
            if g.phase == .play && g.area == .main && g.on(EV_PARADE) { parade() }
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

        if wx == 1 { wind() }
        if wx == 3 { rain() }

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
            if g.rig != .tent { gear(rx, GY + (g.inRig ? 12 : 0), def, g.rigFace, !g.inRig) }
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
            let gx = (g.onToy ? g.px : g.toyX)
            let tb = (g.onToy ? GY + 7 : GY + 2) + g.ground(gx)
            if g.area == .trail {
                // tilt with the ground, and buck a little at speed
                let hop = g.onToy ? abs(sin(gx * 0.09)) * min(1, abs(g.vx) / 160) * 2.4 : 0
                c.save()
                c.translate(tx, tb - hop)
                c.rotate(g.slope(gx) * 0.9)
                toy(g.toy, 0, 0, g.onToy ? g.face : 1, g.onToy ? g.look : -1, g.onToy ? g.walk : 0)
                c.restore()
            } else {
                toy(g.toy, tx, tb, g.onToy ? g.face : 1, g.onToy ? g.look : -1, g.onToy ? g.walk : 0)
            }
            if g.nearToy {
                g.hits.append(Hit(id: 51, x: tx - len / 2 - 8, y: GY - 34, w: len + 16, h: 52))
            }
        }
        if g.hasDog && !g.inRig {
            let dx = g.px - g.face * (g.onToy ? 26 : 13)
            dog(dx - cam, GY + 6 + g.ground(dx), g.face, g.walk * (g.onToy ? 1.6 : 1) + (abs(g.vx) > 4 ? 0 : NOW * 0.5), g.dogCholla)
        }
        if !g.inRig && !g.onToy { person(g.px - cam, GY + 6 + g.ground(g.px), g.look, g.face, g.walk, abs(g.vx) > 4) }
    }

    /// The extras on your own rig: a roof rack, a Starlink dish, and the awning rolled out when you're parked.
    private func gear(_ rx: Double, _ base: Double, _ def: RigDef, _ dir: Double, _ parked: Bool) {
        let roof = base - def.high - 0.5
        let half = def.len / 2
        if g.upgrades.contains(UP_RACK) {
            let fx = rx + dir * half * 0.42
            c.R(fx - 9, roof - 4, 18, 0.8, Col(0x2a2a2a))
            c.R(fx - 9, roof - 4, 0.8, 4, Col(0x2a2a2a)); c.R(fx + 8.2, roof - 4, 0.8, 4, Col(0x2a2a2a))
            c.RR(fx - 7, roof - 8, 8, 4.4, 0.8, Col(0x3a5a7a)); c.RR(fx + 1.4, roof - 7, 5, 3.4, 0.6, Col(0x8a6238))
        }
        if g.upgrades.contains(UP_STARLINK) {
            let dx = rx - dir * half * 0.62
            c.R(dx - 0.5, roof - 4, 1, 4, Col(0x8a8a8a))
            c.RR(dx - 4, roof - 6, 8, 2.4, 1.2, Col(0xf4f4f0))
        }
        if g.upgrades.contains(UP_AWNING) && parked {
            // rolled out over the door side, striped, on two poles
            let a0 = rx - half * 0.55, a1 = rx + half * 0.35
            let top = roof + 2.4, low = roof + 2.4 + def.high * 0.15
            let stripes: [Col] = [Col(0x3a6ea5), Col(0xf4f1ea)]
            let n = 6
            for k in 0..<n {
                let u0 = Double(k) / Double(n), u1 = Double(k + 1) / Double(n)
                c.poly(stripes[k % 2], [a0 + (a1 - a0) * u0, top, a0 + (a1 - a0) * u1, top, a0 + (a1 - a0) * u1 + 2, low, a0 + (a1 - a0) * u0 + 2, low])
            }
            c.R(a0 + 1.6, low, 0.8, base - low + 2, Col(0x9a9a9a)); c.R(a1 + 1.6, low, 0.8, base - low + 2, Col(0x9a9a9a))
            c.ell(rx - half * 0.1, base + 0.4, half * 0.5, 1.4, Col(0x000000, 0.12))
        }
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
                    rig(k, sx, GY + 0.5, hashN(n + 1230) < 0.5 ? 2 : 0, hashN(n + 1240) < 0.5 ? 1 : -1, 0.5); campDress(sx, n)
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
                for i in 0..<18 { let d = n * 7.1 + Double(i); c.R(sx + hashN(d) * w, GY - h + hashN(d + 3) * h, 0.7, 0.7, hashN(d + 5) < 0.5 ? col.shade(0.9) : col.shade(1.07)) }
                c.R(sx + w * 0.2, GY - h - 5, w * 0.6, 5, col)
                c.R(sx + w * 0.2 - 0.6, GY - h - 5.6, w * 0.6 + 1.2, 1, col.shade(1.12))
                c.R(sx - 0.6, GY - h - 0.6, w + 1.2, 1, col.shade(1.12))
                c.R(sx, GY - h + 0.4, w, 1.2, Col(0x000000, 0.14))
                let signs: [Col] = [Col(0xb5452f), Col(0x2f5a7a), Col(0x3f8f6a), Col(0x7a4a8a), Col(0x2a2a2e)]
                c.RR(sx + w * 0.26, GY - h - 4.2, w * 0.48, 3.4, 0.6, signs[Int(hashN(n + 1340) * 5) % 5].shade(1 - dark * 0.4))
                for i in 0..<5 { c.R(sx + w * 0.3 + Double(i) * w * 0.08, GY - h - 3.1, w * 0.05, 1.2, Col(0xf4f1ea, 0.7)) }
                let awn = [Col(0xd9412e), Col(0x3a6ea5), Col(0x4f9a5a), Col(0xf2c14e)][Int(hashN(n + 1350) * 4) % 4].shade(1 - dark * 0.4)
                pane(sx + 5, GY - h * 0.45, w * 0.3, h * 0.33)
                c.poly(awn, [sx + 3, GY - h * 0.5, sx + 7 + w * 0.3, GY - h * 0.5, sx + 9 + w * 0.3, GY - h * 0.5 + 3.4, sx + 1, GY - h * 0.5 + 3.4])
                for i in 0..<4 { c.R(sx + 3 + Double(i) * (w * 0.3 + 4) / 4, GY - h * 0.5, (w * 0.3 + 4) / 8, 3.4, Col(0xf4f1ea, 0.5)) }
                doorway(sx + w * 0.55, GY - h * 0.45, 7, h * 0.45, col.shade(0.55))
                c.R(sx + w * 0.72, GY - h - 3, 6, 3, Col(0xc0c0bc).shade(1 - dark * 0.5))
                c.R(sx + w * 0.72 + 1, GY - h - 2.2, 4, 0.5, Col(0x8a8a88))
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
                    rig(kinds[Int(hashN(n + 1420) * 5) % 5], sx, GY + 0.5, 1, hashN(n + 1430) < 0.5 ? 1 : -1, 0.5); campDress(sx, n)
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
                    if h < 0.6 { rig(.skoolie, sx, GY + 0.5, 2, hashN(n + 1470) < 0.5 ? 1 : -1, 0.5); campDress(sx, n) }
                    else if h < 0.85 { rig(.van, sx, GY + 0.5, 1, 1, 0.5); campDress(sx, n) }
                    else { rig(.tent, sx, GY + 0.5, 0, 1, 0.55) }
                } else if h < 0.5 {
                    rig(.van, sx, GY + 0.5, 1, 1, 0.5); campDress(sx, n)
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
        case .roadrunner:
            let fest = g.phase == .play && g.on(EV_QFEST)
            let gap = fest ? 80.0 : 280.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1560) < (fest ? 0.85 : 0.5) {
                    let sx = n * gap + hashN(n + 1570) * 30 - cam * par
                    let kinds: [RigKind] = [.classA, .classC, .van, .classB]
                    rig(kinds[Int(hashN(n + 1580) * 4) % 4], sx, GY + 0.5, 1, hashN(n + 1590) < 0.5 ? 1 : -1, 0.5); campDress(sx, n)
                    if fest {
                        // a tall mast with a wire antenna strung off it
                        let h = 34 + hashN(n + 1600) * 20
                        c.R(sx + 8, GY - h, 0.6, h, Col(0x6a6a6a))
                        c.seg(sx + 8.3, GY - h, sx + 30, GY - 4, 0.3, Col(0x5a5a5a, 0.7))
                        c.R(sx + 4, GY - h, 9, 0.5, Col(0x6a6a6a))
                    }
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
                    rig(kinds[Int(hashN(n + 1540) * 5) % 5], sx, GY + 0.5, 2, hashN(n + 1550) < 0.5 ? 1 : -1, 0.5); campDress(sx, n)
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

    // MARK: the drive

    private func driveScene() {
        dark = darkness(g.dayT)
        let sk = skyAt(g.dayT)
        cam = g.driveScroll
        let hz = GY - 38
        c.vfill(0, 0, W, hz + 1, [(0, sk.0), (1, sk.1)])
        if dark > 0.3 {
            for i in 0..<60 {
                let n = Double(i)
                c.R(hashN(n) * W, hashN(n + 200) * hz * 0.85, 0.8, 0.8, Col(0xffffff, (dark - 0.3) * (0.4 + 0.6 * hashN(n + 400))))
            }
            c.glow(W * 0.78, hz * 0.3, 24, Col(0xdfe6ff, 0.3), Col(0xdfe6ff, 0))
            c.circ(W * 0.78, hz * 0.3, 5, Col(0xeef0fa)); c.circ(W * 0.78 + 2, hz * 0.3 - 1, 4.4, sk.0)
        } else {
            c.glow(W * 0.8, hz * 0.32, 42, Col(0xfff0c0, 0.55), Col(0xfff0c0, 0))
            c.circ(W * 0.8, hz * 0.32, 6.5, Col(0xfff6dc))
        }
        clouds(g.weather, sk.1)
        ridge(0.03, 1.3, hz - 4, 46, Col.mix(Col(0x6a5a80), sk.1, 0.55).shade(1 - dark * 0.55))
        ridge(0.09, 4.1, hz + 1, 24, Col.mix(Col(0x8a5a4a), sk.1, 0.35).shade(1 - dark * 0.6))
        c.vfill(0, hz, W, H - hz, [(0, Col(0xdcbc8c).shade(1 - dark * 0.6)), (1, Col(0xc49464).shade(1 - dark * 0.6))])
        // far side of the road: small cactus and brush drifting by
        let fp = cam * 0.35
        var n = floor(fp / 34) - 1
        while n * 34 < fp + W + 40 {
            let sx = n * 34 + hashN(n + 900) * 22 - fp
            let k = hashN(n + 910)
            if k < 0.28 { saguaro(sx, hz + 10, 13 + hashN(n + 920) * 10, n, SAG, false) }
            else if k < 0.5 { creosote(sx, hz + 10, n) }
            else if k < 0.62 { cholla(sx, hz + 10, 0.55, n) }
            else if k < 0.7 { ocotillo(sx, hz + 10, n) }
            n += 1
        }
        // the power line along the highway, a hawk now and then
        if !g.driveDirt {
            let pp = cam * 0.55
            var m = floor(pp / 96) - 1
            var tops: [(Double, Double)] = []
            while m * 96 < pp + W + 100 { tops.append((m * 96 - pp, m)); m += 1 }
            let pole = Col(0x6a4e36).shade(1 - dark * 0.5), wire = Col(0x2a2420, 0.55)
            let ty = hz - 24
            for (i, t) in tops.enumerated() {
                c.R(t.0 - 0.8, ty, 1.6, 36, pole)
                c.R(t.0 - 6, ty + 2, 12, 1.2, pole)
                if i + 1 < tops.count {
                    let u = tops[i + 1].0
                    c.curve(t.0 - 5, ty + 2, (t.0 + u) / 2 - 5, ty + 8, u - 5, ty + 2, 0.4, wire)
                    c.curve(t.0 + 5, ty + 2, (t.0 + u) / 2 + 5, ty + 8, u + 5, ty + 2, 0.4, wire)
                }
                if dark < 0.3 && hashN(t.1 + 500) < 0.2 {
                    let hk = Col(0x4a3426)
                    c.ell(t.0, ty - 2.4, 1.4, 2.4, hk); c.circ(t.0 + 0.4, ty - 5, 1, hk)
                    c.poly(Col(0xe8c040), [t.0 + 1.2, ty - 5.2, t.0 + 2.4, ty - 4.8, t.0 + 1.2, ty - 4.4])
                }
            }
            // a billboard now and then
            let bp = cam * 0.45
            var q = floor(bp / 520) - 1
            let ads = ["ROCKS · GEMS · FOSSILS  NEXT EXIT", "QUARTZSITE  ROCK & RV CAPITAL", "FREE DUMP & WATER  WITH FILL-UP", "METEORITES! SKULLS! ODDITIES!", "TYSON WELLS  ROCK & GEM SHOW"]
            while q * 520 < bp + W + 200 {
                if hashN(q + 700) < 0.6 {
                    let bx = q * 520 + 300 - bp
                    let leg = Col(0x5a4a3a).shade(1 - dark * 0.5)
                    c.R(bx - 18, hz - 8, 1.6, 18, leg); c.R(bx + 16, hz - 8, 1.6, 18, leg)
                    c.R(bx - 32, hz - 30, 64, 22, Col(0x2a2420).shade(1 - dark * 0.3))
                    c.R(bx - 31, hz - 29, 62, 20, [Col(0xf2c14e), Col(0xf4f1ea), Col(0x3a6ea5), Col(0xd9412e)][Int(hashN(q + 710) * 4) % 4].shade(1 - dark * 0.5))
                    let ad = ads[Int(hashN(q + 720) * Double(ads.count)) % ads.count]
                    let parts = ad.components(separatedBy: "  ")
                    let ink = hashN(q + 710) * 4 >= 2 ? Col(0xf4f1ea) : INK
                    g.text(parts[0], bx, hz - 22, 4, ink, bold: true)
                    if parts.count > 1 { g.text(parts[1], bx, hz - 15, 3.4, ink) }
                }
                q += 1
            }
        }
        let ry0 = GY - 25, ry1 = GY + 15
        if g.driveDirt {
            c.R(0, ry0 + 4, W, ry1 - ry0 - 8, Col(0xb8925e).shade(1 - dark * 0.6))
            let lb = g.laneBase(1)
            c.R(0, lb - 7, W, 2.4, Col(0x9a7448).shade(1 - dark * 0.6))
            c.R(0, lb - 1.4, W, 2.6, Col(0x9a7448).shade(1 - dark * 0.6))
            for i in 0..<40 {
                let d = Double(i)
                let x = (hashN(d + 30) * (W + 60) - cam).truncatingRemainder(dividingBy: W + 60)
                c.ell(x < -30 ? x + W + 60 : x, ry0 + 6 + hashN(d + 31) * (ry1 - ry0 - 12), 0.8 + hashN(d + 32) * 1.4, 0.6, Col(0x7a5a3a, 0.6))
            }
        } else {
            let asphalt = Col(0x48484c).shade(1 - dark * 0.5)
            c.R(0, ry0 - 2, W, 2, Col(0xa89070).shade(1 - dark * 0.6))
            c.R(0, ry0, W, ry1 - ry0, asphalt)
            for i in 0..<50 {
                let d = Double(i)
                let x = (hashN(d + 50) * (W + 20) - cam).truncatingRemainder(dividingBy: W + 20)
                c.R(x < -10 ? x + W + 20 : x, ry0 + hashN(d + 51) * (ry1 - ry0), 1, 0.6, asphalt.shade(1.25))
            }
            c.R(0, ry0 + 1.6, W, 0.9, Col(0xf2c14e, 0.85))
            c.R(0, ry1 - 2.4, W, 0.9, Col(0xf4f1ea, 0.85))
            var d = -cam.truncatingRemainder(dividingBy: 40)
            while d < W { c.R(d, (ry0 + ry1) / 2 - 0.5, 18, 1, Col(0xf4f1ea, 0.9)); d += 40 }
            c.R(0, ry1, W, 2, Col(0xa89070).shade(1 - dark * 0.6))
            // mile posts on the shoulder
            var mp = -(cam.truncatingRemainder(dividingBy: 220)) + 200
            while mp < W + 10 {
                c.R(mp - 0.8, ry1 + 2, 1.6, 9, Col(0x1f6a3a).shade(1 - dark * 0.4))
                c.R(mp - 0.8, ry1 + 3, 1.6, 1.4, Col(0xf4f1ea, 0.9))
                mp += 220
            }
        }
        // a green sign now and then, counting down
        let sgx = W + 80 - (cam * 0.9).truncatingRemainder(dividingBy: W + 260)
        if !g.driveDirt && sgx > -60 {
            let post = Col(0x8a8a88).shade(1 - dark * 0.5)
            c.R(sgx - 20, ry0 - 30, 1.4, 30, post); c.R(sgx + 19, ry0 - 30, 1.4, 30, post)
            c.RR(sgx - 26, ry0 - 44, 52, 17, 2, Col(0x1f6a3a).shade(1 - dark * 0.4))
            c.RR(sgx - 24.6, ry0 - 42.6, 49.2, 14.2, 1.4, Col(0xf4f1ea, 0.9))
            c.RR(sgx - 24, ry0 - 42, 48, 13, 1.2, Col(0x1f6a3a).shade(1 - dark * 0.4))
            let name = (g.driveTo == .skoolie ? "Ehrenberg" : AREAS[g.driveTo.rawValue].name).uppercased()
            g.text(name.count > 12 ? String(name.prefix(12)) : name, sgx, ry0 - 38.5, 3.6, Col(0xf4f1ea), bold: true)
            g.text("\(Int(g.driveLeft.rounded(.up))) mi", sgx, ry0 - 32.5, 3.8, Col(0xf4f1ea), bold: true)
        }
        // traffic and you, far lane first
        let me = W * 0.3
        let bob = g.driveDirt ? abs(sin(NOW * 9)) * 1.2 : sin(NOW * 22) * 0.25
        let mb = g.laneBase(g.driveLaneY) - bob
        for lane in 0...1 {
            for car in g.driveCars where car.lane == lane { traffic(car) }
            if (lane == 0) == (g.driveLaneY < 0.5) { driveYou(me, mb) }
        }
        // dust kicked up behind you on the dirt
        if g.driveDirt {
            for i in 0..<7 {
                let t = (NOW * 1.6 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
                c.circ(me - g.driveLen / 2 - 2 - t * 56, mb - 2 - t * 9, 2 + t * 7, Col(0xd8b88a, (1 - t) * 0.45).shade(1 - dark * 0.5))
            }
        }
        // the near shoulder: bigger plants rushing past
        let np = cam * 1.6
        n = floor(np / 120) - 1
        while n * 120 < np + W + 120 {
            let sx = n * 120 + hashN(n + 960) * 70 - np
            let k = hashN(n + 970)
            if k < 0.12 { saguaro(sx, H + 6, 52 + hashN(n + 980) * 16, n, SAG, true) }
            else if k < 0.35 { barrel(sx, H - 2, 1.2, n) }
            else if k < 0.55 { creosote(sx, H - 1, n) }
            else if k < 0.68 { cholla(sx, H - 1, 1.1, n) }
            else if k < 0.78 { rock(sx, H - 3, 3 + hashN(n + 990) * 3) }
            n += 1
        }
        // where you're headed, and a way to skip
        let left = g.driveLeft
        let mi = left == left.rounded() ? "\(Int(left))" : String(format: "%.1f", left)
        c.RR(W / 2 - 74, 6, 148, 18, 9, Col(0x1c1410, 0.7))
        g.text("To " + AREAS[g.driveTo.rawValue].name + "  ·  " + mi + " mi", W / 2, 13, 5.4, CREAM, bold: true)
        c.RR(W / 2 - 60, 19, 120, 2.4, 1.2, Col(0xffffff, 0.2))
        c.RR(W / 2 - 60, 19, 120 * clampD(1 - left / max(0.01, g.driveMiles), 0, 1), 2.4, 1.2, GOLD)
        let r = W - g.safeR - 8
        c.RR(r - 44, 6, 44, 18, 9, Col(0x1c1410, 0.7))
        g.text("SKIP", r - 22, 15, 5.4, CREAM, bold: true)
        g.hits.append(Hit(id: 65, x: r - 50, y: 0, w: 56, h: 32))
        if g.driveBump > 0.5 { g.text("Bump!", me, mb - 44, 8, REDC, bold: true) }
        if !g.shown.contains("drive") && !g.driveDirt {
            g.text("Tap high or low to change lanes. Pass the slow traffic.", W / 2, H - 10, 5, CREAM, bold: true, plate: true)
        }
    }

    /// Your rig, your ride, or the shuttle you caught, rolling right.
    private func driveYou(_ x: Double, _ base: Double) {
        if dark > 0.3 {
            let nose = x + g.driveLen / 2
            c.poly(Col(0xfff2c0, 0.16 * dark), [nose, base - 9, nose + 110, base - 20, nose + 110, base + 6])
        }
        switch g.driveVeh {
        case 0: rig(g.rig, x, base, g.panels, 1)
        case 1: toy(g.toy, x, base, 1, g.look, g.driveScroll * 0.12)
        case 3: rig(.skoolie, x, base, 0, 1)
        default: rig(.minivan, x, base, 0, 1)
        }
    }

    private func traffic(_ car: Game.Car) {
        let b = g.laneBase(Double(car.lane))
        let kinds: [RigKind] = [.minivan, .minivan, .van, .classC, .classA, .skoolie]
        if car.kind == 0 { toy(4, car.x, b, 1, Int(hashN(car.v) * 4), g.driveScroll * 0.1) }
        else { rig(kinds[car.kind], car.x, b, 0, 1) }
        if dark > 0.3 {
            let tail = car.x - CAR_LEN[car.kind] / 2
            c.glow(tail, b - 7, 7, Col(0xff3020, 0.5 * dark), Col(0xff3020, 0))
        }
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
            // side-by-side: a stock utility side-by-side with half doors, a roof, a cargo bed and knobby tires
            let body = Col(0x5a6a3a)
            for wx in [-12.0, 12.6] { c.circ(wx, -5.2, 5.2, dk); c.circ(wx, -5.2, 2.4, Col(0x4a4a4a)); c.circ(wx, -5.2, 1, HUB) }
            c.poly(body, [-19, -8, -19, -13.4, -8, -13.4, -7, -10.6, 9, -10.6, 12, -14.4, 18.6, -12.6, 19.6, -8])
            c.poly(body.shade(1.12), [-6.6, -10.6, 7, -10.6, 7, -15.4, -6.6, -15.4])
            c.R(-6.2, -15, 13, 0.8, body.shade(0.7))
            c.R(-19, -8, 39, 2.2, Col(0x2a2a2a))
            c.R(-19, -16.2, 10, 2.8, Col(0x3a3a3a))
            c.seg(-19, -16.2, -19, -13.4, 0.8, dk); c.seg(-9, -16.2, -9, -13.4, 0.8, dk)
            c.seg(-8, -10.6, -8, -26, 1.1, dk); c.seg(-8, -26, 8, -26, 1.1, dk); c.seg(8, -26, 12, -14.4, 1.1, dk)
            c.seg(0, -15.4, 0, -26, 0.8, dk)
            c.R(-9, -27.4, 18, 1.6, Col(0x2a2a2a))
            c.R(-5, -17, 3.6, 6.4, Col(0x1e1e1e))
            c.RR(17.4, -13.4, 2, 1.6, 0.6, Col(0xfff2c0))
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
            if g.phase == .play && g.weather == 3 {
                // the wash is running: muddy water sheeting across
                c.vfill(x - 70, GY + 0.5, 140, 6, [(0, Col(0x9a8c74, 0.8)), (1, Col(0x7a6a54, 0.85))])
                c.R(x - 70, GY + 0.5, 140, 0.8, Col(0xd8d0c0, 0.6))
                for j in 0..<12 {
                    let fx = x - 66 + ((NOW * 30 + Double(j) * 23).truncatingRemainder(dividingBy: 132))
                    c.R(fx, GY + 1 + Double(j % 3) * 2, 6, 0.6, Col(0xd8c0a0, 0.7))
                }
            }
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
            pane(x - 28, GY - 22, 9, 6); pane(x + 1, GY - 22, 7, 6)
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
            facade(x - 42, GY - 38, 84, 38, wall)
            var lx = x - 42.0
            while lx < x + 42 { c.R(lx, GY - 38, 0.7, 38, wall.shade(0.86)); lx += 4.5 }
            c.poly(Col(0x7a8088), [x - 45, GY - 38, x - 40, GY - 44, x + 40, GY - 44, x + 45, GY - 38])
            doorway(x - 9, GY - 22, 18, 22, Col(0x33302c))
            pane(x - 34, GY - 26, 16, 10); pane(x + 18, GY - 26, 16, 10)
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
            facade(x - 40, GY - 32, 80, 32, adobe)
            c.R(x - 42, GY - 36, 84, 5, adobe.shade(1.08))
            c.R(x - 12, GY - 40, 24, 5, adobe.shade(1.08))
            for j in 0..<6 { c.R(x - 36 + Double(j) * 14, GY - 30, 1.4, 2, Col(0x6a4a2a)) }
            doorway(x - 7, GY - 22, 14, 22, Col(0x5a3a22)); c.R(x - 0.3, GY - 22, 0.6, 22, Col(0x3a2414))
            pane(x - 33, GY - 22, 14, 10); pane(x + 19, GY - 22, 14, 10)
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
            facade(x - 36, GY - 30, 72, 30, wall)
            c.RR(x - 30, GY - 44, 60, 12, 2, Col(0x6a3a7a))
            g.text("GEM WORLD", x, GY - 38, 6, CREAM, bold: true)
            doorway(x - 6, GY - 20, 12, 20, Col(0x4a3424))
            pane(x - 30, GY - 22, 18, 10); pane(x + 12, GY - 22, 18, 10)
            for j in 0..<4 { gem(x - 27 + Double(j) * 4.4, GY - 13, 1.4, [Col(0x9a5ad0), Col(0xf0f0f4), Col(0xe2742e), Col(0x2fa7a0)][j]) }
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
            if g.phase == .play && g.on(EV_WESTERN) {
                c.R(x - 26, GY - 6, 52, 6, Col(0x8a6238))
                c.R(x - 26, GY - 30, 1.4, 24, Col(0x5a3e24)); c.R(x + 24.6, GY - 30, 1.4, 24, Col(0x5a3e24))
                c.R(x - 30, GY - 38, 60, 9, Col(0x7a2f1e))
                g.text("BUCK CONNORS WESTERN DAYS", x, GY - 33.4, 3.4, GOLD, bold: true)
                for j in 0..<3 {
                    let bx = x - 12 + Double(j) * 12
                    person(bx, GY - 6, 0, 1, sin(NOW * 4 + Double(j)), false)
                    c.ell(bx + 2.6, GY - 13, 2.4, 1.6, Col(0x9a5a2a)); c.seg(bx + 4, GY - 13.6, bx + 8, GY - 17, 0.5, Col(0x6a4a2a))
                }
                for j in 0..<7 { person(x - 42 + Double(j) * 14, GY + 4, j % 4, j % 2 == 0 ? 1 : -1, 0, false) }
                label = false
            } else if rtr {
                c.R(x - 30, GY - 36, 60, 9, Col(0x3f8f8a))
                g.text("RUBBER TRAMP RENDEZVOUS", x, GY - 31.4, 3.6, CREAM, bold: true)
                for j in 0..<6 { person(x - 30 + Double(j) * 12, GY + 2, j % 4, j % 2 == 0 ? 1 : -1, 0, false) }
                label = false
            }
            top = 44
        case .yacht:
            // the Quartzsite Yacht Club: a desert bar with a boat on the roof sign
            let wall = Col(0x3a6ea5)
            facade(x - 34, GY - 26, 68, 26, wall)
            c.R(x - 34, GY - 28, 68, 2, Col(0xf4f4f0))
            c.poly(Col(0xf4f4f0), [x - 18, GY - 34, x + 18, GY - 34, x + 12, GY - 29, x - 12, GY - 29])
            c.seg(x, GY - 34, x, GY - 46, 0.8, Col(0xf4f4f0)); c.poly(Col(0xf4f4f0), [x + 0.6, GY - 45, x + 10, GY - 36, x + 0.6, GY - 36])
            g.text("YACHT CLUB", x, GY - 21, 4.6, CREAM, bold: true)
            doorway(x - 6, GY - 15, 12, 15, Col(0x2a2018))
            pane(x - 28, GY - 15, 14, 8); pane(x + 14, GY - 15, 14, 8)
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
                if g.phase == .play && e == EV_GEM {
                    g.hits.append(Hit(id: 52, x: x - 66, y: GY - 34, w: 132, h: 40))
                    if near { g.text("Tap a table to look closer", x, GY + 12, 4.6, CREAM, plate: true) }
                }
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
            pane(x - 16, GY - 19, 10, 6)
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
            doorway(x - 11, GY - 15, 8, 15, Col(0x241810))
            c.R(x - 20, GY - 16, 6, 6, Col(0x1c1410))
            let st = Col(0x9a8a78).shade(1 - dark * 0.35)
            c.RR(x + 16, GY - 14, 18, 14, 2, st)
            c.R(x + 15, GY - 15, 20, 2, st.shade(0.8))
            top = 38
        case .parade:
            // the corner of Moon Mountain Avenue and Main Street, where the parade passes
            c.R(x - 0.6, GY - 30, 1.2, 30, Col(0x8a8f96))
            c.RR(x - 20, GY - 34, 40, 6, 1, Col(0x1f6b3a)); g.text("MOON MOUNTAIN AV", x, GY - 31, 3, CREAM, bold: true)
            c.RR(x - 14, GY - 27, 28, 5, 1, Col(0x1f6b3a)); g.text("MAIN ST", x, GY - 24.6, 3, CREAM, bold: true)
            if g.phase == .play && g.on(EV_PARADE) {
                for j in 0..<9 { person(x - 60 + Double(j) * 15 + (j % 2 == 0 ? 0 : 4), GY + 1, j % 4, j % 3 == 0 ? -1 : 1, 0, false) }
                c.R(x - 70, GY - 46, 140, 8, Col(0xb5452f))
                g.text("HI JOLLY PARADE · TODAY", x, GY - 42, 4, CREAM, bold: true)
                label = false
            }
            top = 40
        case .rvpark:
            // Holiday Palms: a block wall, palms, RVs parked in rows
            palm(x - 70, GY + 1, 54, 11); palm(x + 72, GY + 1, 48, 13)
            rig(.classA, x - 30, GY, 2, 1, 0.62)
            rig(.classC, x + 36, GY, 1, -1, 0.62)
            c.R(x - 80, GY - 7, 160, 7, Col(0xc9a87a))
            for j in 0..<16 { c.R(x - 80 + Double(j) * 10, GY - 7, 0.6, 7, Col(0xa8885a)) }
            c.R(x - 4, GY - 7, 8, 7, Col(0x5a4a3a, 0.0))
            c.RR(x - 34, GY - 50, 68, 12, 2, Col(0x2f6a5a))
            g.text("HOLIDAY PALMS RV PARK", x, GY - 44, 4.2, CREAM, bold: true)
            if g.phase == .play && g.resident { c.RR(x - 14, GY - 18, 28, 7, 1, GOLD); g.text("YOUR SITE", x, GY - 14.6, 3.2, INK, bold: true) }
            label = false
            top = 58
        case .house:
            // a small block house with a carport and a gravel yard
            let wall = Col(0xe2d0ac)
            facade(x - 30, GY - 24, 44, 24, wall)
            c.poly(Col(0x7a4a34), [x - 34, GY - 24, x - 8, GY - 36, x + 18, GY - 24])
            doorway(x - 6, GY - 16, 9, 16, Col(0x6a4a2e))
            pane(x - 24, GY - 18, 12, 8)
            c.R(x + 14, GY - 20, 26, 2, Col(0x8a8f96)); c.R(x + 38, GY - 20, 1, 20, Col(0x8a8f96))
            c.R(x + 30, GY - 30, 8, 6, Col(0xb8b8b4))
            for j in 0..<8 { c.ell(x - 34 + Double(j) * 10, GY - 0.6, 3, 1, Col(0xa89880)) }
            saguaro(x + 52, GY + 1, 34, 77, SAG, true)
            if g.phase == .play && g.house {
                if dark > 0.3 { lights.append((x - 18, GY - 14, 26)) }
                c.R(x - 44, GY - 14, 0.8, 14, wood); c.RR(x - 52, GY - 20, 16, 7, 1, GOLD); g.text("HOME", x - 44, GY - 16.6, 3.2, INK, bold: true)
            } else {
                c.R(x - 44, GY - 14, 0.8, 14, wood); c.RR(x - 54, GY - 21, 20, 8, 1, Col(0xd9412e)); g.text("FOR SALE", x - 44, GY - 17, 3, CREAM, bold: true)
            }
            label = false
            top = 44
        case .radio:
            if g.phase == .play && !g.on(EV_QFEST) {
                c.R(x - 1, GY - 22, 2, 22, wood)
                c.RR(x - 30, GY - 36, 60, 16, 2, Col(0x7a5a3a))
                g.text("QUARTZFEST", x, GY - 31, 5, CREAM, bold: true)
                g.text("Ham radio week, Jan 17–23", x, GY - 25, 3.4, CREAM)
                label = false
                top = 44
                break
            }
            canopy(x, 30, Col(0xf4f1ea), Col(0x3a6ea5))
            c.R(x - 24, GY - 10, 48, 10, Col(0x4a4a4e))
            for j in 0..<3 { c.RR(x - 20 + Double(j) * 14, GY - 16, 10, 6, 1, Col(0x2a2a2e)); c.circ(x - 17 + Double(j) * 14, GY - 13, 1, Col(0xf2c14e)); c.R(x - 14 + Double(j) * 14, GY - 14, 3, 2, Col(0x5ad06a)) }
            person(x - 10, GY + 2, 2, 1, 0, false); person(x + 12, GY + 2, 3, -1, 0, false)
            c.R(x + 40, GY - 60, 1, 60, Col(0x7a7a7a))
            for j in 0..<4 { c.R(x + 34 + Double(j) * 0.0, GY - 60 + Double(j) * 4, 13 - Double(j) * 2, 0.7, Col(0x7a7a7a)) }
            c.RR(x - 22, GY - 44, 44, 8, 1.4, Col(0x2a2a2e))
            g.text("QUARTZFEST", x, GY - 40, 4.4, Col(0x8ad0f0), bold: true)
            label = false
            top = 50
        case .camel:
            camelSculpture(x, GY, sp.arg)
            if g.phase == .play && g.camels.contains(sp.arg) { c.circ(x + 14, GY - 30, 3, GOLD); c.seg(x + 12.6, GY - 30, x + 13.6, GY - 29, 0.6, INK); c.seg(x + 13.6, GY - 29, x + 15.6, GY - 31.4, 0.6, INK) }
            top = 40
        case .dogpark:
            // a fenced off-leash park with a gate and a water bowl
            for j in 0..<13 { c.R(x - 48 + Double(j) * 8, GY - 12, 0.6, 12, Col(0x8a8f96)) }
            c.R(x - 48, GY - 12, 96, 0.6, Col(0x8a8f96)); c.R(x - 48, GY - 6, 96, 0.5, Col(0x8a8f96))
            c.ell(x + 20, GY - 0.5, 3, 1, Col(0x3a6ea5))
            if g.phase == .play && g.hasDog && g.seen.contains(22) { dog(x - 10 + sin(NOW * 2) * 30, GY + 1, cos(NOW * 2) > 0 ? 1 : -1, NOW * 12, false) }
            else { dog(x - 20, GY + 1, 1, NOW * 3, false); dog(x + 6, GY + 1, -1, NOW * 3 + 1, false) }
            top = 26
        case .stray:
            if g.phase == .play && g.hasDog { top = 20; label = false; break }
            dog(x, GY + 2, -1, NOW * 1.5, false)
            top = 22
        case .cleanup:
            // a cleanup crew's pickup with trash bags, a sign and a couple of volunteers
            c.poly(Col(0x9a3a2a), [x - 26, GY - 4, x - 26, GY - 12, x - 4, GY - 12, x, GY - 17, x + 12, GY - 17, x + 16, GY - 11, x + 24, GY - 10, x + 24, GY - 4])
            c.poly(GLASS, [x + 1, GY - 16, x + 11, GY - 16, x + 14, GY - 11.4, x + 1, GY - 11.4])
            for wx in [-16.0, 14.0] { c.circ(x + wx, GY - 3.4, 3.4, TIRE); c.circ(x + wx, GY - 3.4, 1.4, HUB) }
            for j in 0..<3 { c.circ(x - 22 + Double(j) * 6, GY - 14, 3, Col(0x2a2a2a)); c.R(x - 22.6 + Double(j) * 6, GY - 17.6, 1.2, 1.4, Col(0x2a2a2a)) }
            person(x + 34, GY + 2, 0, -1, 0, false); person(x + 46, GY + 2, 2, -1, 0, false)
            c.R(x - 44, GY - 16, 0.8, 16, wood); c.RR(x - 56, GY - 24, 24, 9, 1, Col(0x4f9a5a))
            g.text("CLEANUP", x - 44, GY - 19.6, 3.4, CREAM, bold: true)
            label = false
            top = 32
        case .computer:
            // The Computer Corner: a small shop with a dish on the roof
            let wall = Col(0xd8d4cc)
            facade(x - 26, GY - 24, 52, 24, wall)
            c.R(x - 28, GY - 26, 56, 3, Col(0x3a6ea5))
            doorway(x - 6, GY - 16, 12, 16, Col(0x3a3a3e))
            pane(x - 22, GY - 18, 12, 8); pane(x + 10, GY - 18, 12, 8)
            c.R(x + 14, GY - 32, 1, 6, Col(0x8a8a8a)); c.RR(x + 9.6, GY - 34, 10, 3, 1.4, Col(0xf4f4f0))
            c.RR(x - 24, GY - 36, 30, 8, 1.4, Col(0x2a2a2e))
            g.text("COMPUTER CORNER", x - 9, GY - 32, 3.2, Col(0x8ad0f0), bold: true)
            label = false
            top = 44
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
                let st = Col(0x8a7a66)
                c.poly(st.shade(0.7), [x - 15, GY + 0.6, x + 15, GY + 0.6, x + 15, GY - 2, x - 15, GY - 2])
                c.poly(st, [x - 13, GY - 1, x - 4, GY - 30, x + 4, GY - 30, x + 13, GY - 1])
                c.poly(st.shade(0.82), [x, GY - 30, x + 4, GY - 30, x + 13, GY - 1, x + 4, GY - 1])
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
                facade(x - 34, GY - 30, 68, 30, wall)
                c.poly(Col(0x9a4a3a), [x - 38, GY - 30, x - 30, GY - 38, x + 30, GY - 38, x + 38, GY - 30])
                c.RR(x - 26, GY - 47, 52, 10, 2, Col(0x2f5a4a))
                g.text("READER'S OASIS", x, GY - 42, 4.6, CREAM, bold: true)
                doorway(x - 6, GY - 20, 12, 20, Col(0x4a3424))
                let spines: [Col] = [Col(0xb5452f), Col(0x3a6ea5), Col(0xf2c14e), Col(0x3f8f8a), Col(0x7a4a8a), Col(0xe8dcc4)]
                for side in [-1.0, 1.0] {
                    let tx = x + side * 22
                    c.R(tx - 9, GY - 8, 18, 1.4, wood)
                    c.R(tx - 8, GY - 6.6, 1, 6.6, wood); c.R(tx + 7, GY - 6.6, 1, 6.6, wood)
                    for j in 0..<8 { c.R(tx - 8 + Double(j) * 2, GY - 8 - 3.6 - hashN(Double(j) + side * 9) * 1.4, 1.6, 3.6 + hashN(Double(j) + side * 9) * 1.4, spines[j % 6]) }
                }
                label = false
                top = 56
            } else if sp.arg == 4 {
                // Celia's Rainbow Gardens: desert plantings, a rainbow arch, a little pioneer village
                c.curve(x - 26, GY, x, GY - 52, x + 26, GY, 1.2, Col(0xd9412e))
                c.curve(x - 23, GY, x, GY - 46, x + 23, GY, 1.2, Col(0xf2c14e))
                c.curve(x - 20, GY, x, GY - 40, x + 20, GY, 1.2, Col(0x4f9a5a))
                c.curve(x - 17, GY, x, GY - 34, x + 17, GY, 1.2, Col(0x3a6ea5))
                for j in 0..<3 { let hx = x - 12 + Double(j) * 9; doorway(hx - 3, GY - 5, 6, 5, Col(0xb89a74)); c.poly(Col(0x7a4a34), [hx - 4, GY - 5, hx, GY - 8, hx + 4, GY - 5]) }
                cholla(x - 34, GY + 1, 0.8, 12); creosote(x + 34, GY + 1, 13)
                c.R(x - 1, GY - 16, 2, 0.1, wood)
                g.text("CELIA'S RAINBOW GARDENS", x, GY - 58, 3.8, CREAM, bold: true)
                label = false
                top = 60
            } else if sp.arg == 2 {
                // Tyson's Well: the 1864 stage stop, marked by a plaque on a stone base
                doorway(x - 8, GY - 12, 16, 12, Col(0xa89880))
                for j in 0..<10 { let d = Double(j); c.ell(x - 6 + hashN(d + 140) * 12, GY - 2 - hashN(d + 141) * 9, 1.8, 1.2, Col(0x8a7a64)) }
                c.RR(x - 6, GY - 20, 12, 9, 1, Col(0x6a4a2a))
                c.RR(x - 5, GY - 19, 10, 7, 0.6, Col(0x9a7a3a))
                g.text("1864", x, GY - 15.4, 3, CREAM, bold: true)
                c.seg(x + 16, GY, x + 16, GY - 18, 0.9, wood); c.seg(x + 26, GY, x + 26, GY - 18, 0.9, wood)
                c.R(x + 14, GY - 19, 14, 1.4, wood); doorway(x + 18, GY - 12, 6, 12, Col(0x6a6a6a))
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

    /// A stucco or block wall: a little texture, a shadow under the roofline, a darker footing.
    private func facade(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ col: Col) {
        let cc = col.shade(1 - dark * 0.45)
        c.R(x, y, w, h, cc)
        let n = min(90, Int(w * h / 40))
        for i in 0..<n {
            let d = Double(i) * 1.37 + w * 0.13 + h * 0.71
            c.R(x + hashN(d) * w, y + hashN(d + 9) * h, 0.8, 0.6, hashN(d + 5) < 0.5 ? cc.shade(0.92) : cc.shade(1.06))
        }
        c.R(x, y, w, 1.8, Col(0x000000, 0.16))
        c.R(x, y + h - 1.6, w, 1.6, cc.shade(0.8))
    }
    /// A framed window with a sill, a glint by day and warm light at night.
    private func pane(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        let frame = Col(0xefe8da).shade(1 - dark * 0.5)
        c.R(x - 0.9, y - 0.9, w + 1.8, h + 1.8, frame)
        if dark > 0.35 {
            c.R(x, y, w, h, Col(0xffd68a))
            lights.append((x + w / 2, y + h / 2, max(10, w * 1.3)))
        } else {
            c.vfill(x, y, w, h, [(0, Col(0x7a98b4)), (1, Col(0x2b3a4a))])
            c.poly(Col(0xffffff, 0.2), [x + w * 0.12, y + h, x + w * 0.42, y, x + w * 0.6, y, x + w * 0.3, y + h])
        }
        c.R(x + w / 2 - 0.3, y, 0.6, h, frame)
        c.R(x - 1.6, y + h + 0.9, w + 3.2, 1.2, frame.shade(0.88))
    }
    /// A paneled door with a frame and a brass knob.
    private func doorway(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ col: Col) {
        let cc = col.shade(1 - dark * 0.3)
        c.R(x - 0.8, y - 0.8, w + 1.6, h + 0.8, Col(0xefe8da).shade(1 - dark * 0.5))
        c.R(x, y, w, h, cc)
        if w > 4 {
            c.R(x + 1.2, y + 1.4, w - 2.4, h * 0.4, cc.shade(1.14))
            c.R(x + 1.2, y + h * 0.5, w - 2.4, h * 0.4, cc.shade(1.14))
        }
        c.circ(x + w - 1.6, y + h * 0.56, 0.6, GOLD)
    }

    /// Life around a parked rig in the background: a flag, camp chairs, string lights at night.
    private func campDress(_ x: Double, _ seed: Double) {
        let b = GY + 0.5
        if hashN(seed + 1601) < 0.45 {
            let fx = x - 24
            c.R(fx - 0.35, b - 16, 0.7, 16, Col(0xc8c8c4).shade(1 - dark * 0.5))
            let fc = [Col(0xd9412e), Col(0x3a6ea5), Col(0xf2c14e), Col(0x4f9a5a), Col(0x8a4aa8)][Int(hashN(seed + 1602) * 5) % 5].shade(1 - dark * 0.5)
            let wv = sin(NOW * 5 + seed) * 0.8
            c.poly(fc, [fx, b - 16, fx + 3, b - 15.6 + wv, fx + 6, b - 16 + wv * 0.4, fx + 6, b - 12.6 + wv * 0.4, fx + 3, b - 12.4 + wv, fx, b - 12.8])
        }
        if hashN(seed + 1603) < 0.5 {
            let chair = [Col(0x2f6a8a), Col(0xb5452f), Col(0x3f8f6a)][Int(hashN(seed + 1604) * 3) % 3].shade(1 - dark * 0.5)
            for k in 0..<2 {
                let cx = x + 22 + Double(k) * 5
                c.seg(cx - 1.4, b, cx + 1.4, b - 2.4, 0.4, Col(0x5a5a5a)); c.seg(cx + 1.4, b, cx - 1.4, b - 2.4, 0.4, Col(0x5a5a5a))
                c.R(cx - 1.6, b - 2.8, 3.2, 0.9, chair); c.R(cx - 1.6, b - 5.4, 0.9, 2.8, chair)
            }
            if dark < 0.3 { c.R(x + 30, b - 2, 2, 2, Col(0xd8d4cc)) }
        }
        if dark > 0.3 && hashN(seed + 1605) < 0.65 {
            let bulbs = [Col(0xffd68a), Col(0xff8a6a), Col(0x8ad0ff), Col(0xb8ff8a)]
            for i in 0..<10 {
                let t = Double(i) / 9
                let lx = x - 14 + 34 * t, ly = b - 13 + sin(PI * t) * 3
                c.circ(lx, ly, 0.7, bulbs[(i + Int(seed)) % 4].alpha(0.6 + 0.4 * dark))
            }
            lights.append((x + 3, b - 11, 16))
        }
    }

    /// A barrel cactus, ribbed, with yellow flowers on top.
    private func barrel(_ x: Double, _ base: Double, _ s: Double, _ seed: Double) {
        if x < -20 || x > W + 20 { return }
        let col = Col(0x5a8a4a).shade(1 - dark * 0.35)
        c.ell(x, base - 5 * s, 4 * s, 5.4 * s, col)
        for k in -1...1 { c.R(x + Double(k) * 1.6 * s - 0.25, base - 9.6 * s, 0.5, 9 * s, col.shade(0.8)) }
        c.ell(x, base - 10.2 * s, 2.6 * s, 1 * s, Col(0xe8c040))
        c.ell(x, base - 5 * s, 4 * s, 5.4 * s, Col(0xd04a3a, 0.12))
    }
    /// Beavertail prickly pear: flat blue-green pads, magenta flowers on the edges.
    private func beavertail(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -20 || x > W + 20 { return }
        let col = Col(0x7a8a9a).shade(1 - dark * 0.35)
        let pads: [(Double, Double, Double)] = [(0, -4, 0), (-5, -7, -0.4), (5, -8, 0.4), (1, -12, 0.1)]
        for (k, p) in pads.enumerated() where k < 2 + Int(hashN(seed) * 3) {
            c.save(); c.translate(x + p.0, base + p.1); c.rotate(p.2)
            c.ell(0, 0, 3, 4.4, col)
            for d in 0..<4 { c.circ(-1.6 + Double(d % 2) * 3.2, -1.6 + Double(d / 2) * 3.2, 0.3, Col(0xe8e0c8)) }
            c.restore()
        }
        if hashN(seed + 2) < 0.6 { c.circ(x - 5, base - 11.6, 1.1, Col(0xd04a8a)); c.circ(x + 6, base - 12.4, 1.1, Col(0xd04a8a)) }
    }
    /// A palo verde: green bark, a feathery yellow-green canopy.
    private func paloverde(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -40 || x > W + 40 { return }
        let bark = Col(0x7a9a4a).shade(1 - dark * 0.4)
        c.roundCaps(true)
        c.seg(x, base, x - 1, base - 12, 2, bark)
        c.seg(x - 1, base - 10, x - 9, base - 20, 1.3, bark)
        c.seg(x - 1, base - 11, x + 8, base - 21, 1.3, bark)
        c.roundCaps(false)
        for i in 0..<16 {
            let d = seed + Double(i) * 2.3
            c.circ(x - 14 + hashN(d) * 28, base - 26 + hashN(d + 1) * 10, 3 + hashN(d + 2) * 2.4, Col(0xa8b85a, 0.85).shade(1 - dark * 0.4))
        }
    }
    /// A desert rock with a lit top.
    private func rock(_ x: Double, _ base: Double, _ r: Double) {
        let col = Col(0x8a6a54).shade(1 - dark * 0.4)
        c.ell(x, base - r * 0.4, r, r * 0.6, col)
        c.ell(x - r * 0.2, base - r * 0.65, r * 0.6, r * 0.25, col.shade(1.25))
        c.ell(x, base + 0.3, r * 1.1, r * 0.2, Col(0x000000, 0.15))
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

    /// A gold coin, the game's money.
    func coin(_ x: Double, _ y: Double, _ r: Double) {
        c.circ(x, y, r, Col(0xb8862a))
        c.circ(x, y, r * 0.82, GOLD)
        c.arcStroke(x, y, r * 0.55, 0, PI * 2, max(0.4, r * 0.12), Col(0xb8862a))
        c.circ(x - r * 0.3, y - r * 0.3, r * 0.22, Col(0xfff2c0, 0.8))
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
        let label = o.earn > 0 ? "+\(o.earn)" : "\(o.cost)"
        let short = Double(o.cost) > g.money + g.ringPaid
        g.text(label, x, y, label.count > 4 ? 5.6 : 7, short ? REDC : (o.earn > 0 ? GREEN : CREAM), bold: true)
        g.text(o.label, x, y + 18, 5, CREAM)
        if g.ringProg <= 0 { g.text("hold", x, y - 17, 4, CREAM.alpha(0.6 + 0.3 * sin(NOW * 4))) }
    }

    private func hud() {
        let l = g.safeL + 8, r = W - g.safeR - 8
        c.RR(l, 5, 132, 14, 7, Col(0x1c1410, 0.68))
        coin(l + 10, 12, 4)
        g.text("\(Int((g.money + 0.0001).rounded(.down)))", l + 17, 12, 7.5, GOLD, align: 1, bold: true)
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
        if g.page { pack += "  ·  \(g.followersText()) followers" }
        g.text(pack, r, 12, 5.5, CREAM, align: 2, bold: true, plate: true)
        // the map button
        c.RR(r - 30, 24, 30, 13, 6.5, Col(0x1c1410, 0.68))
        c.arcStroke(r - 22, 30.5, 3.2, 0, PI * 2, 0.8, GOLD)
        c.poly(GOLD, [r - 22, 34.6, r - 24.4, 31.4, r - 19.6, 31.4])
        g.text("MAP", r - 11, 30.5, 5, CREAM, bold: true)
        g.hits.append(Hit(id: 60, x: r - 36, y: 20, w: 40, h: 22))
        // sound on / off
        c.RR(r - 30, 41, 30, 13, 6.5, Col(0x1c1410, 0.68))
        c.poly(CREAM, [r - 25, 45.6, r - 22.6, 45.6, r - 19.6, 43, r - 19.6, 52, r - 22.6, 49.4, r - 25, 49.4])
        if g.muted { c.seg(r - 18, 44.4, r - 13, 50.6, 0.9, REDC); c.seg(r - 13, 44.4, r - 18, 50.6, 0.9, REDC) }
        else { c.arcStroke(r - 19.6, 47.5, 3, -0.8, 0.8, 0.7, CREAM); c.arcStroke(r - 19.6, 47.5, 5.4, -0.8, 0.8, 0.7, CREAM.alpha(0.7)) }
        g.text(g.muted ? "OFF" : "ON", r - 7, 47.5, 4, CREAM.alpha(0.8), bold: true)
        g.hits.append(Hit(id: 63, x: r - 36, y: 42, w: 40, h: 18))

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
        g.text(dateText(g.day) + "  ·  age \(g.age)  ·  season \(g.year)", x0 + 70, y0 + 10, 5.6, ink.alpha(0.7), align: 1, bold: true)
        // close
        c.circ(x1 - 11, y0 + 10, 6, ink.alpha(0.12))
        c.seg(x1 - 14, y0 + 7, x1 - 8, y0 + 13, 1, ink); c.seg(x1 - 8, y0 + 7, x1 - 14, y0 + 13, 1, ink)
        g.hits.append(Hit(id: 62, x: x0, y: y0, w: x1 - x0, h: y1 - y0))
        g.hits.append(Hit(id: 61, x: x1 - 22, y: y0, w: 22, h: 22))

        // the sketch map
        let mx0 = x0 + 10, my0 = y0 + 22, mw = (x1 - x0) * 0.5, mh = y1 - y0 - 58
        c.RR(mx0, my0, mw, mh, 3, Col(0xe2cfa4))
        let lonA = -114.42, lonB = -114.13, latA = 33.57, latB = 33.69
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
        let n95 = mp(33.69, -114.216), s95 = mp(33.57, -114.216)
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
            let off: [(Double, Double, Int)] = [(-4, 4, 2), (4, -5, 1), (-4, 4, 2), (0, -6, 0), (0, 6, 0), (0, 6, 0), (0, -6, 0), (-4, 3, 2)]
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
            else if t.ok { let m = milesBetween(g.area, to); sub = (m == m.rounded() ? "\(Int(m))" : "\(m)") + " mi · " + (t.cost == 0 ? "0 coins" : "\(t.cost) coins") }
            else { sub = t.how }
            g.text(sub, lx + 5, ry + rowH * 0.68, 3.8, here ? ink.alpha(0.7) : (t.ok ? Col(0x2f6a3a) : REDC.shade(0.8)), align: 1)
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
        // testing only: skip a week to reach the events
        c.RR(x1 - 66, y0 + 4, 48, 12, 6, REDC.alpha(0.85))
        g.text("TEST: +1 WEEK", x1 - 42, y0 + 10, 3.8, CREAM, bold: true)
        g.hits.append(Hit(id: 64, x: x1 - 68, y: y0 + 2, w: 52, h: 16))
        if g.mapMsgT > 0 {
            g.text(g.mapMsg, (x0 + x1) / 2, my0 + mh * 0.5, 6, CREAM.alpha(clampD(g.mapMsgT, 0, 1)), bold: true, plate: true)
        }
    }

    /// Up close at the Rock & Gem Show: six things on the tables, who's selling, and what each should fetch.
    private func browseOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.55))
        let x0 = g.safeL + 14, x1 = W - g.safeR - 14, y0 = 8.0, y1 = H - 8
        let ink = Col(0x2a1e14)
        c.RR(x0, y0, x1 - x0, y1 - y0, 6, Col(0x3a2c3a))
        g.hits.append(Hit(id: 88, x: x0, y: y0, w: x1 - x0, h: y1 - y0))
        g.text("ON THE TABLES", x0 + 10, y0 + 10, 8, GOLD, align: 1, bold: true)
        g.text("\(Int(g.money)) coins  ·  pack \(g.rocks)/\(g.packCap)", x0 + 96, y0 + 10, 5.4, CREAM.alpha(0.8), align: 1, bold: true)
        c.circ(x1 - 11, y0 + 10, 6, Col(0xffffff, 0.15))
        c.seg(x1 - 14, y0 + 7, x1 - 8, y0 + 13, 1, CREAM); c.seg(x1 - 8, y0 + 7, x1 - 14, y0 + 13, 1, CREAM)
        g.hits.append(Hit(id: 89, x: x1 - 22, y: y0, w: 22, h: 22))
        let cols = 3.0
        let cw = (x1 - x0 - 20 - 8 * (cols - 1)) / cols
        let ch = (y1 - y0 - 34 - 8) / 2
        let stones: [Col] = [Col(0x9a5ad0), Col(0xe2742e), Col(0xf0f0f4), Col(0xb48a5a), Col(0x8a5a3a), Col(0x2fa7a0), Col(0x3fb0a8), Col(0xd8b8a0), Col(0xc85a3a), Col(0xe8e0f0)]
        for (k, w) in g.wares.enumerated() {
            let cx = x0 + 10 + Double(k % 3) * (cw + 8), cy = y0 + 24 + Double(k / 3) * (ch + 8)
            c.RR(cx, cy, cw, ch, 4, w.sold ? Col(0xffffff, 0.08) : Col(0xeadfc4))
            // the stone itself
            let n = WARE_NAMES.firstIndex(of: w.name) ?? 0
            c.ell(cx + 16, cy + ch * 0.5 + 6, 11, 3, Col(0x000000, 0.18))
            gem(cx + 16, cy + ch * 0.5 + 6, 7, stones[n].shade(w.sold ? 0.5 : 1))
            g.text(w.name, cx + 32, cy + 9, 5, w.sold ? CREAM.alpha(0.5) : ink, align: 1, bold: true, wrap: cw - 36)
            g.text(w.who, cx + 32, cy + 20, 3.6, w.sold ? CREAM.alpha(0.4) : ink.alpha(0.7), align: 1, wrap: cw - 36)
            if w.sold {
                g.text("Yours", cx + 32, cy + ch - 8, 5, GOLD, align: 1, bold: true)
            } else {
                coin(cx + 35, cy + ch - 12, 3.2)
                g.text("\(w.price)", cx + 41, cy + ch - 12, 6.4, Double(w.price) > g.money ? REDC : Col(0x2f6a3a), align: 1, bold: true)
                g.text("sells for about \(w.lo)–\(w.hi) coins", cx + 32, cy + ch - 5, 3.4, ink.alpha(0.65), align: 1)
                g.hits.append(Hit(id: 90 + k, x: cx, y: cy, w: cw, h: ch))
            }
        }
        if g.mapMsgT > 0 { g.text(g.mapMsg, (x0 + x1) / 2, (y0 + y1) / 2, 6, CREAM.alpha(clampD(g.mapMsgT, 0, 1)), bold: true, plate: true) }
    }

    private func card(_ title: String, _ body: String) -> (Double, Double, Double, Double) {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.6))
        let w = min(260.0, W - g.safeL - g.safeR - 40), h = 120.0
        let x0 = (W - w) / 2, y0 = (H - h) / 2
        c.RR(x0, y0, w, h, 8, Col(0xeadfc4))
        g.text(title, W / 2, y0 + 18, 10, Col(0x3a2c1e), bold: true)
        g.text(body, W / 2, y0 + 48, 5, Col(0x3a2c1e).alpha(0.85), wrap: w - 30)
        return (x0, y0, w, h)
    }
    private func button(_ id: Int, _ label: String, _ x: Double, _ y: Double, _ w: Double, _ on: Bool) {
        c.RR(x, y, w, 18, 9, on ? GOLD : Col(0x3a2c1e, 0.15))
        g.text(label, x + w / 2, y + 9, 5.6, on ? INK : Col(0x3a2c1e, 0.45), bold: true)
        if on { g.hits.append(Hit(id: id, x: x, y: y - 4, w: w, h: 26)) }
    }

    /// April 15: head north or stay the summer.
    private func seasonOverlay() {
        let canStay = g.resident || g.house
        let body = "The snowbirds are pulling out and it's getting hot. You're \(g.age). " + (canStay ? "You have a place to stay the summer, and your businesses would keep paying." : "Without a year-round site or a house, it's time to head north until the fall.")
        let r = card("SEASON'S OVER", body)
        let bw = (r.2 - 40) / 2
        button(80, "Head north", r.0 + 15, r.1 + r.3 - 30, bw, true)
        button(81, "Stay the summer", r.0 + 25 + bw, r.1 + r.3 - 30, bw, canStay)
    }

    /// The end of a life in the desert.
    private func endOverlay() {
        let r = card(g.endTitle.uppercased(), g.endText)
        // a lone saguaro at sunset on the card
        c.circ(r.0 + 30, r.1 + r.3 - 22, 9, Col(0xf29a2e, 0.55))
        saguaro(r.0 + 36, r.1 + r.3 - 8, 26, 5, SAGD, false)
        saguaro(r.0 + r.2 - 34, r.1 + r.3 - 8, 18, 9, SAGD, false)
        button(82, "Start a new life", r.0 + r.2 / 2 - 50, r.1 + r.3 - 30, 100, true)
    }

    /// The Hi Jolly Parade: camels, floats, classic cars and side-by-sides rolling down Main Street.
    private func parade() {
        let gap = 64.0
        let shift = (NOW * 12).truncatingRemainder(dividingBy: gap * 12)
        for i in 0..<60 {
            let wx = Double(i) * gap + shift - gap * 6
            let sx = wx - cam
            if sx < -60 || sx > W + 60 { continue }
            let y = GY + 12
            switch i % 6 {
            case 0, 3: camel(sx, y, Double(i) + NOW * 3)
            case 1:
                // a flatbed float with bunting and waving riders
                c.RR(sx - 24, y - 9, 48, 6, 1, Col(0xf2c14e))
                for j in 0..<6 { c.poly([Col(0xd9412e), Col(0xf4f4f0), Col(0x3a6ea5)][j % 3], [sx - 24 + Double(j) * 8, y - 3, sx - 16 + Double(j) * 8, y - 3, sx - 20 + Double(j) * 8, y + 1]) }
                for wx2 in [-16.0, 16.0] { c.circ(sx + wx2, y - 1, 2.6, TIRE) }
                person(sx - 8, y - 9, 0, 1, 0, false); person(sx + 8, y - 9, 3, 1, 0, false)
            case 2: toy(5, sx, y, 1, i % 4, 0)
            case 4:
                // a classic car
                c.poly(Col(0x3a8aaa), [sx - 18, y - 3, sx - 18, y - 9, sx - 8, y - 9, sx - 4, y - 14, sx + 8, y - 14, sx + 12, y - 9, sx + 19, y - 8, sx + 19, y - 3])
                c.poly(GLASS, [sx - 3, y - 13, sx + 7, y - 13, sx + 10, y - 9.4, sx - 6, y - 9.4])
                for wx2 in [-11.0, 12.0] { c.circ(sx + wx2, y - 3, 3.2, TIRE); c.circ(sx + wx2, y - 3, 1.4, Col(0xd8d8d4)) }
            default:
                // walkers with a banner
                person(sx - 9, y, 1, 1, NOW * 6 + Double(i), true); person(sx + 9, y, 2, 1, NOW * 6 + Double(i) + 1, true)
                c.seg(sx - 7, y - 10, sx - 7, y - 22, 0.6, Col(0x6a6a6a)); c.seg(sx + 11, y - 10, sx + 11, y - 22, 0.6, Col(0x6a6a6a))
                c.R(sx - 7, y - 22, 18, 6, Col(0xf4f1ea)); g.text("QZ", sx + 2, y - 19, 3.2, REDC, bold: true)
            }
        }
    }

    /// A dromedary in the Army Camel Corps tradition.
    private func camel(_ x: Double, _ base: Double, _ ph: Double) {
        let col = Col(0xb8885a).shade(1 - dark * 0.4)
        let sw = sin(ph) * 2.4
        c.roundCaps(true)
        for (lx, s) in [(-7.0, sw), (-4.0, -sw), (5.0, -sw), (8.0, sw)] { c.seg(x + lx, base - 12, x + lx + s, base, 1.4, col.shade(0.85)) }
        c.ell(x, base - 14, 11, 4.6, col)
        c.ell(x - 1, base - 18, 5, 4, col)
        c.curve(x + 9, base - 14, x + 13, base - 18, x + 13, base - 24, 2, col)
        c.ell(x + 15, base - 24.6, 3.2, 1.6, col)
        c.roundCaps(false)
        c.R(x - 4, base - 21, 7, 1.4, Col(0xd9412e))
    }

    // MARK: weather

    private func clouds(_ wx: Int, _ haze: Col) {
        let count = [3, 4, 7, 9][max(0, min(3, wx))]
        for i in 0..<count {
            let d = Double(i)
            let sp = 3 + hashN(d + 300) * 5
            let cx = (hashN(d + 310) * (W + 200) + NOW * sp - cam * 0.05).truncatingRemainder(dividingBy: W + 200) - 100
            let cy = GY * (0.12 + hashN(d + 320) * 0.35)
            let r = 10 + hashN(d + 330) * 14
            let col = (wx >= 2 ? Col(0x8a909c) : Col(0xffffff)).alpha((wx >= 2 ? 0.85 : 0.5) * (1 - dark * 0.7))
            c.ell(cx, cy, r * 1.8, r * 0.55, col)
            c.ell(cx - r * 0.6, cy - r * 0.2, r * 0.9, r * 0.5, col)
            c.ell(cx + r * 0.7, cy - r * 0.3, r, r * 0.6, col)
        }
    }
    private func rain() {
        for i in 0..<140 {
            let d = Double(i)
            let x = (hashN(d + 500) * (W + 40) + NOW * 30).truncatingRemainder(dividingBy: W + 40) - 20
            let y = (hashN(d + 510) * H + NOW * (220 + hashN(d + 520) * 80)).truncatingRemainder(dividingBy: H)
            c.seg(x, y, x - 2, y + 7, 0.5, Col(0xc8d4e4, 0.45))
        }
        c.R(0, GY, W, H - GY, Col(0x3a3440, 0.18))
    }
    private func wind() {
        c.R(0, 0, W, H, Col(0xc8a070, 0.12))
        for i in 0..<60 {
            let d = Double(i)
            let x = (hashN(d + 600) * (W + 60) + NOW * (160 + hashN(d + 610) * 120)).truncatingRemainder(dividingBy: W + 60) - 30
            let y = GY - 30 + hashN(d + 620) * (H - GY + 40)
            c.seg(x, y, x - 10 - hashN(d + 630) * 10, y + 0.6, 0.6, Col(0xe8d0a8, 0.35))
        }
        // a couple of tumbleweeds bouncing through
        for i in 0..<2 {
            let d = Double(i)
            let span = W + 120
            let x = (NOW * (70 + d * 25) + d * 200).truncatingRemainder(dividingBy: span) - 60
            let y = GY + 4 - abs(sin(NOW * 5 + d)) * 7
            let r = 4 + d * 1.5
            for k in 0..<6 {
                let a = NOW * 6 + Double(k) * 1.05
                c.arcStroke(x, y - r, r * (0.6 + Double(k % 3) * 0.2), a, a + 2.4, 0.5, Col(0x8a6a44, 0.9))
            }
        }
    }

    // MARK: desert life

    /// Burros, javelina, quail, roadrunners and coyotes, drifting through each place at the hours they keep.
    private func critters(_ ar: Area) {
        if ar == .main || ar == .tyson { ravens(); return }
        let t = g.dayT
        let dusk = (t > 0.55 && t < 0.72) || t < 0.1
        let night = dark > 0.5
        let w = g.WORLD
        // a small herd of wild burros grazing their way along
        if (ar == .dome || ar == .trail || ar == .scaddan) && !night {
            let hx = g.herdX() - 39
            for k in 0..<4 { burro(hx + Double(k) * 26 - cam, GY + 2 + Double(k % 2), Double(k) * 1.7) }
        }
        // javelina at dusk
        if (ar == .ltva || ar == .dome || ar == .scaddan) && dusk {
            let jx = w * 0.7 - (NOW * 9).truncatingRemainder(dividingBy: w * 0.8)
            for k in 0..<3 { javelina(jx + Double(k) * 12 - cam, GY + 3, NOW * 8 + Double(k)) }
        }
        // quail running in a line by day
        if !night && ar != .skoolie {
            let qx = (NOW * 22 + 420).truncatingRemainder(dividingBy: w + 600) - 300
            for k in 0..<5 { quail(qx - Double(k) * 6 - cam, GY + 6, NOW * 20 + Double(k)) }
        }
        // a roadrunner sprinting the road now and then
        if !night {
            let cyc = (NOW + 7).truncatingRemainder(dividingBy: 24)
            if cyc < 6 { roadrunner(g.px - cam - W * 0.6 + cyc * (W * 1.2 / 6), GY + 8, NOW * 30) }
        }
        // a coyote trotting past at night
        if night {
            let cx = (NOW * 18).truncatingRemainder(dividingBy: w + 300) - 150
            coyote(cx - cam, GY + 4, NOW * 10)
        }
        ravens()
    }
    private func ravens() {
        if dark > 0.5 { return }
        for i in 0..<2 {
            let d = Double(i)
            let x = (NOW * (14 + d * 6) + d * 260).truncatingRemainder(dividingBy: W + 80) - 40
            let y = GY * (0.25 + d * 0.15) + sin(NOW * 0.7 + d) * 8
            let f = sin(NOW * 6 + d * 2) * 2.2
            c.seg(x - 4, y - f, x, y, 0.8, INK); c.seg(x, y, x + 4, y - f, 0.8, INK)
        }
    }
    private func burro(_ x: Double, _ base: Double, _ ph: Double) {
        if x < -20 || x > W + 20 { return }
        let col = Col(0x8a7a6a).shade(1 - dark * 0.5)
        let sw = sin(NOW * 2 + ph) * 1.2
        c.roundCaps(true)
        for (lx, s0) in [(-4.0, sw), (-2.0, -sw), (3.0, -sw), (5.0, sw)] { c.seg(x + lx, base - 6, x + lx + s0, base, 1, col.shade(0.8)) }
        c.ell(x, base - 8, 6.4, 3, col)
        let graze = sin(NOW * 0.6 + ph) > 0.3
        let hx = x + 7, hy = graze ? base - 3 : base - 11
        c.seg(x + 4.4, base - 9, hx, hy, 2.2, col)
        c.ell(hx + 1, hy, 2.4, 1.4, col.shade(0.95)); c.circ(hx + 2.8, hy + 0.4, 0.9, Col(0xe8e0d4))
        c.seg(hx - 0.4, hy - 1, hx - 1.2, hy - 4.4, 0.7, col.shade(0.9)); c.seg(hx + 0.4, hy - 1, hx + 0.6, hy - 4.6, 0.7, col.shade(0.9))
        c.seg(x - 6.4, base - 8.6, x - 7.6, base - 5, 0.6, col.shade(0.7))
        c.roundCaps(false)
        c.R(x - 4, base - 10.8, 7, 0.6, col.shade(0.6))
    }
    private func javelina(_ x: Double, _ base: Double, _ ph: Double) {
        if x < -12 || x > W + 12 { return }
        let col = Col(0x3e3632).shade(1 - dark * 0.3)
        let sw = sin(ph) * 0.8
        c.seg(x - 2, base - 2.4, x - 2 + sw, base, 0.8, col); c.seg(x + 2, base - 2.4, x + 2 - sw, base, 0.8, col)
        c.ell(x, base - 3.6, 4, 2.2, col)
        c.poly(col, [x - 3.6, base - 3, x - 6, base - 2.6, x - 3.4, base - 1.6])
        c.R(x - 1.6, base - 5.6, 3.6, 0.6, Col(0xb8b0a4, 0.7))
        c.circ(x - 5.6, base - 2.7, 0.4, Col(0x1a1614))
    }
    private func quail(_ x: Double, _ base: Double, _ ph: Double) {
        if x < -6 || x > W + 6 { return }
        let col = Col(0x7a7a84).shade(1 - dark * 0.3)
        c.ell(x, base - 2 - abs(sin(ph)) * 0.6, 2, 1.5, col)
        c.circ(x + 1.6, base - 3.4, 0.9, col.shade(0.8))
        c.seg(x + 1.6, base - 4.2, x + 2.4, base - 5.6, 0.4, INK)
    }
    private func roadrunner(_ x: Double, _ base: Double, _ ph: Double) {
        if x < -10 || x > W + 10 { return }
        let col = Col(0x6a5a4a)
        let sw = sin(ph) * 1.6
        c.seg(x, base - 3, x + sw, base, 0.5, Col(0x4a4a4a)); c.seg(x, base - 3, x - sw, base, 0.5, Col(0x4a4a4a))
        c.ell(x, base - 4, 3, 1.4, col)
        c.seg(x - 2.4, base - 4.4, x - 8, base - 6.4, 1, col)
        c.circ(x + 3, base - 5.4, 1.1, col)
        c.seg(x + 3.6, base - 5.4, x + 6, base - 5.2, 0.4, INK)
        c.seg(x + 2.6, base - 6.2, x + 1.6, base - 7.6, 0.6, col.shade(0.7))
    }
    private func coyote(_ x: Double, _ base: Double, _ ph: Double) {
        if x < -16 || x > W + 16 { return }
        let col = Col(0x7a6a52).shade(0.6)
        let sw = sin(ph) * 1.4
        for (lx, s0) in [(-4.0, sw), (-2.4, -sw), (3.0, -sw), (4.6, sw)] { c.seg(x + lx, base - 5, x + lx + s0, base, 0.8, col) }
        c.ell(x, base - 6.4, 5.4, 2.2, col)
        c.seg(x - 5, base - 6.8, x - 9, base - 4.8, 1.2, col)
        c.poly(col, [x + 4.4, base - 7.6, x + 9, base - 7, x + 5, base - 5.4])
        c.poly(col, [x + 5, base - 7.6, x + 5.6, base - 10, x + 6.4, base - 7.6])
        c.circ(x + 6.6, base - 7.2, 0.5, Col(0xffe080, 0.9))
    }

    // MARK: cinematics

    /// The current shot of a cinematic, with fades between shots and a caption.
    private func cinematic() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        let i = min(g.cineShots.count - 1, Int(g.cineT / g.SHOT))
        let u = (g.cineT - Double(i) * g.SHOT) / g.SHOT
        c.R(0, 0, W, H, Col(0x000000))
        switch g.cineShots[i] {
        case 0: shotHighway(u)
        case 1: shotWide(u)
        case 2: shotFire(u)
        case 3: shotDawn(u)
        case 4: shotNorth(u)
        default: shotSummer(u)
        }
        // letterbox, caption, fades
        c.R(0, 0, W, 14, Col(0x000000)); c.R(0, H - 14, W, 14, Col(0x000000))
        let cap = g.cineCaps[min(i, g.cineCaps.count - 1)]
        let a = clampD(min(u * 4, (1 - u) * 4), 0, 1)
        if g.cineShots[i] == 3 {
            c.vfill(0, H * 0.36 - 30, W, 60, [(0, Col(0x1c1410, 0)), (0.5, Col(0x1c1410, 0.45 * a)), (1, Col(0x1c1410, 0))])
            g.text("QUARTZSITE", W / 2, H * 0.36, 26, CREAM.alpha(a), bold: true)
            g.text(cap, W / 2, H * 0.36 + 20, 7, GOLD.alpha(a), bold: true)
        } else {
            g.text(cap, W / 2, H - 26, 7, CREAM.alpha(a), bold: true)
        }
        g.text("tap to skip", W - g.safeR - 30, 7, 4, CREAM.alpha(0.4))
        let fade = clampD(1 - min(u, 1 - u) * 6, 0, 1)
        if fade > 0 { c.R(0, 0, W, H, Col(0x000000, fade)) }
    }

    @discardableResult
    private func cineSky(_ t: Double) -> Col {
        let sk = skyAt(t)
        c.vfill(0, 0, W, H, [(0, sk.0), (1, sk.1)])
        return sk.1
    }

    /// I-10 at sunset: your rig rolls past saguaros toward the Quartzsite exit sign.
    private func shotHighway(_ u: Double) {
        let haze = cineSky(0.61)
        dark = 0.15
        c.glow(W * 0.7, GY * 0.62, 70, Col(0xffd0a0, 0.6), Col(0xffd0a0, 0))
        c.circ(W * 0.7, GY * 0.62, 9, Col(0xfff0d0))
        let pan = u * 260
        cam = pan
        ridge(0.1, 2.2, GY - 4, 50, Col.mix(Col(0x6a4a6a), haze, 0.5))
        ridge(0.3, 6.1, GY, 22, Col.mix(Col(0x5a3a3a), haze, 0.3))
        c.R(0, GY, W, H - GY, Col(0x6a4a3a))
        c.R(0, GY + 6, W, 14, Col(0x3a3634))
        var lx = -(pan * 2).truncatingRemainder(dividingBy: 26)
        while lx < W { c.R(lx, GY + 12.6, 12, 0.9, Col(0xf2c14e, 0.9)); lx += 26 }
        // the exit sign slides in
        let sx = W * 1.1 - u * W * 0.55
        c.R(sx - 1, GY - 40, 2, 46, Col(0x8a8f96)); c.R(sx + 50, GY - 40, 2, 46, Col(0x8a8f96))
        c.RR(sx - 6, GY - 66, 64, 28, 3, Col(0xf4f4f0)); c.RR(sx - 5, GY - 65, 62, 26, 2.6, Col(0x1f6b3a))
        g.text("EXIT 17", sx + 26, GY - 58, 5.6, CREAM, bold: true)
        g.text("QUARTZSITE", sx + 26, GY - 47.4, 6, CREAM, bold: true)
        // saguaros sliding past in silhouette
        for k in 0..<6 {
            let d = Double(k)
            let x = (d * 120 - pan * 1.6).truncatingRemainder(dividingBy: W + 200) + (d * 120 - pan * 1.6 < 0 ? W + 200 : 0) - 60
            saguaro(x, GY + 2, 50 + hashN(d + 40) * 30, d + 41, Col(0x2a2a24), false)
        }
        let rk = g.rig == .tent ? RigKind.minivan : g.rig
        rig(rk, W * 0.42, GY + 18, g.panels, 1)
        for k in 0..<4 { let d = Double(k); c.circ(W * 0.42 - RIGS[rk.rawValue].len / 2 - 6 - d * 8, GY + 16 - d, 3 + d * 1.6, Col(0xe8c8a0, 0.25 - d * 0.05)) }
    }

    /// The whole La Posa spread out at dusk: rows and rows of rigs, saguaros and cholla glowing in front.
    private func shotWide(_ u: Double) {
        let haze = cineSky(0.63)
        dark = 0.2
        c.glow(W * 0.25, GY * 0.75, 60, Col(0xffb070, 0.55), Col(0xffb070, 0))
        cam = u * 120
        ridge(0.08, 3.3, GY - 10, 46, Col.mix(Col(0x5a4a6a), haze, 0.55))
        c.R(0, GY - 14, W, H, Col(0x8a6a4e))
        for row in 0..<4 {
            let r = Double(row)
            let s = 0.22 + r * 0.08
            let y = GY - 12 + r * 9
            var x = -40.0 - (cam * (0.3 + r * 0.2)).truncatingRemainder(dividingBy: 40)
            var k = 0.0
            while x < W + 40 {
                let kinds: [RigKind] = [.classA, .classC, .classB, .van, .skoolie, .classA]
                rig(kinds[Int(hashN(k + r * 31) * 6) % 6], x, y, 0, hashN(k + r * 7) < 0.5 ? 1 : -1, s)
                x += 34 + r * 12 + hashN(k + r * 3) * 14
                k += 1
            }
        }
        // the foreground garden, lit gold from the low sun
        dark = 0
        for k in 0..<5 {
            let d = Double(k)
            let x = d * W / 4 + 20 - u * 30
            if k % 2 == 0 { saguaro(x, H - 10, 70 + hashN(d) * 20, d + 9, Col(0x3a5a34), true) } else { cholla(x, H - 12, 2.2, d + 5) }
        }
    }

    /// Night at camp: the fire, the chairs, the stars.
    private func shotFire(_ u: Double) {
        cineSky(0.85)
        dark = 1
        for i in 0..<120 {
            let n = Double(i)
            c.R(hashN(n + 5) * W, hashN(n + 205) * H * 0.7, 0.9, 0.9, Col(0xffffff, 0.3 + 0.6 * hashN(n + 405) * (0.6 + 0.4 * sin(NOW * 2 + n))))
        }
        c.R(0, H * 0.68, W, H, Col(0x1a1418))
        let fx = W * 0.5, fy = H * 0.78
        c.glow(fx, fy - 10, 110 + sin(NOW * 9) * 6, Col(0xffa040, 0.55), Col(0xffa040, 0))
        c.save(); c.translate(fx, fy); c.scale(3, 3)
        fire(0, 0)
        c.restore()
        c.save(); c.translate(fx - 60, fy + 10); c.scale(2.6, 2.6); person(0, 0, 1, 1, 0, false); c.restore()
        c.save(); c.translate(fx + 64, fy + 10); c.scale(2.6, 2.6); person(0, 0, 3, -1, 0, false); c.restore()
        c.save(); c.translate(W * 0.86, H * 0.68); c.scale(1.4, 1.4); rig(.classB, 0, 0, 0, -1); c.restore()
        saguaro(W * 0.12, H * 0.7, 60, 3, Col(0x0e0c10), false)
    }

    /// Dawn over a cholla garden, the sun coming up behind the title.
    private func shotDawn(_ u: Double) {
        cineSky(0.02 + u * 0.06)
        dark = 0
        let sy = GY * 0.95 - u * 30
        c.glow(W * 0.5, sy, 90, Col(0xffe0a0, 0.6), Col(0xffe0a0, 0))
        c.circ(W * 0.5, sy, 10, Col(0xfff2d0))
        ridge(0.1, 1.7, GY - 2, 40, Col(0x6a4a5a))
        c.R(0, GY, W, H - GY, Col(0x9a7454))
        for k in 0..<7 { let d = Double(k); cholla(d * W / 6 + 10, H - 8 - hashN(d) * 10, 1.8 + hashN(d + 3) * 0.8, d + 20) }
        saguaro(W * 0.15, H - 4, 90, 31, Col(0x2e4a2c), true)
        saguaro(W * 0.86, H - 4, 76, 33, Col(0x2e4a2c), true)
    }

    /// April: a line of rigs heading up Highway 95 into the sunset.
    private func shotNorth(_ u: Double) {
        let haze = cineSky(0.64)
        dark = 0.25
        ridge(0.1, 5.2, GY - 6, 44, Col.mix(Col(0x5a3a5a), haze, 0.4))
        c.R(0, GY, W, H - GY, Col(0x7a5a44))
        // the road runs away from us toward the horizon
        c.poly(Col(0x3a3634), [W * 0.46, GY, W * 0.54, GY, W * 0.9, H, W * 0.1, H])
        c.seg(W * 0.5, GY, W * 0.5, H, 0.8, Col(0xf2c14e, 0.8))
        for k in 0..<6 {
            let d = Double(k)
            let t = ((d / 6 + u * 0.25).truncatingRemainder(dividingBy: 1))
            let y = H - 22 - t * (H - 22 - GY)
            let sc = 0.15 + (1 - t) * 0.6
            let x = W * 0.5 + (1 - t) * W * 0.12
            rig([RigKind.classA, .classC, .skoolie, .classB, .van, .classA][k], x, y, 0, 1, sc)
        }
        c.R(W * 0.2 - 1, GY - 20, 2, 26, Col(0x8a8f96)); c.RR(W * 0.2 - 14, GY - 30, 28, 12, 2, Col(0xf4f4f0))
        g.text("95 NORTH", W * 0.2, GY - 24, 4.4, INK, bold: true)
        saguaro(W * 0.88, H, 80, 51, Col(0x2a2a24), false)
    }

    /// Summer: heat shimmer and an empty desert.
    private func shotSummer(_ u: Double) {
        cineSky(0.3)
        dark = 0
        c.glow(W * 0.5, GY * 0.25, 120, Col(0xfff8e0, 0.7), Col(0xfff8e0, 0))
        c.circ(W * 0.5, GY * 0.25, 12, Col(0xffffff))
        ridge(0.1, 8.1, GY - 4, 40, Col(0xc0a090))
        c.R(0, GY, W, H - GY, Col(0xe0c49a))
        for k in 0..<10 {
            let y = GY - 6 + Double(k) * 1.6
            c.R(0, y + sin(NOW * 6 + Double(k)) * 0.8, W, 0.6, Col(0xffffff, 0.12))
        }
        saguaro(W * 0.3, GY + 20, 64, 61, SAG, true)
        if g.rig != .tent { rig(g.rig, W * 0.66, GY + 16, g.panels, -1) }
        g.text("110°", W * 0.84, GY * 0.3, 14, Col(0xd9412e, 0.85), bold: true)
    }

    /// The town's camel sculptures, each made differently: wheel rims, scrap steel, painted plate.
    private func camelSculpture(_ x: Double, _ base: Double, _ k: Int) {
        let cols: [Col] = [Col(0x7a2a1e), Col(0x5a5a5e), Col(0xc8902e), Col(0x3a6ea5), Col(0x8a6a4a), Col(0xb5452f)]
        let col = cols[k % 6].shade(1 - dark * 0.4)
        c.R(x - 12, base - 2, 24, 2, Col(0x8a8580))
        if k == 0 {
            // the Red Ghost, built of wheel rims
            c.ellStroke(x, base - 15, 8, 5, 1.2, col); c.ellStroke(x - 2, base - 21, 3.2, 3.2, 1, col)
            c.seg(x + 7, base - 17, x + 12, base - 26, 1.2, col); c.ellStroke(x + 13, base - 27, 2.6, 1.6, 1, col)
            for q in [-6.0, -3.0, 3.0, 6.0] { c.seg(x + q, base - 11, x + q, base - 2, 1, col) }
            return
        }
        let sw = 0.0
        for (lx, s0) in [(-5.0, sw), (-2.4, sw), (3.0, sw), (5.6, sw)] { c.seg(x + lx, base - 12, x + lx + s0, base - 2, 1.3, col.shade(0.85)) }
        c.ell(x, base - 15, 9, 4.6, col)
        c.ell(x - 1, base - 19.6, 4.6, 3.8, col)
        if k % 2 == 0 { c.ell(x + 3.6, base - 19, 3, 3, col) }
        c.curve(x + 8, base - 15, x + 12, base - 20, x + 12, base - 26, 2, col)
        c.ell(x + 14, base - 26.6, 3, 1.6, col)
        if k == 3 { for j in 0..<4 { c.circ(x - 5 + Double(j) * 3.4, base - 15, 1, [Col(0xf2c14e), Col(0xd9412e), Col(0xf4f1ea), Col(0x4f9a5a)][j]) } }
    }

    /// A medium dog trotting along, tail going.
    func dog(_ x: Double, _ base: Double, _ dir: Double, _ ph: Double, _ limp: Bool) {
        if x < -12 || x > W + 12 { return }
        let col = Col(0xa8743e).shade(1 - dark * 0.4)
        let sw = sin(ph) * 1.4
        c.roundCaps(true)
        c.seg(x - 2.6 * dir, base - 3.4, x - 2.6 * dir + sw, base, 0.9, col.shade(0.85))
        c.seg(x + 2.6 * dir, base - 3.4, x + 2.6 * dir - (limp ? 0 : sw), base - (limp ? 1 : 0), 0.9, col.shade(0.85))
        c.ell(x, base - 4.2, 3.6, 1.8, col)
        c.seg(x - 3.4 * dir, base - 4.6, x - 5.4 * dir, base - 7 + sin(ph * 2) * 1, 0.7, col)
        c.circ(x + 3.6 * dir, base - 6.2, 1.7, col)
        c.ell(x + 5 * dir, base - 5.8, 1.2, 0.8, col.shade(0.9))
        c.poly(col.shade(0.7), [x + 2.8 * dir, base - 7.4, x + 3.4 * dir, base - 9, x + 4 * dir, base - 7.2])
        c.roundCaps(false)
        if limp { c.circ(x - 1, base - 4.4, 1, Col(0xd8d4a0)) }
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
        let lifeSub = ["Vans, skoolies, Skooliepalooza. Starts with friends: 5 cred.", "A snowbird with a check coming in. Starts with 100 more coins."]
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
            coin(x + 60, 96, 3)
            g.text("start with \(cash)", x + 65, 96, 5.4, GOLD, align: 1)
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
