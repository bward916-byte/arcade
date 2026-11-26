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
            if g.phoneOpen { phoneOverlay() }
            if g.tourOpen { tourOverlay() }
            if g.mineOpen { mineOverlay() }
            if g.boardOpen { boardOverlay() }
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
        // the Milky Way on clear desert nights, and now and then a shooting star
        let clearSky = g.phase != .play || g.weather < 2
        if dark > 0.6 && clearSky {
            let a = (dark - 0.6) * 2.5
            for i in 0..<160 {
                let n = Double(i) + 900
                let u = hashN(n)
                let bx = u * W * 1.1 - W * 0.05
                let by = GY * 0.75 - u * GY * 0.62 + (hashN(n + 1) - 0.5) * 22 * (0.6 + hashN(n + 2))
                c.R(bx, by, 0.6, 0.6, Col(0xe8eaff, a * (0.15 + 0.45 * hashN(n + 3))))
            }
            for i in 0..<7 {
                let u = Double(i) / 6
                c.glow(W * (0.05 + u * 0.95), GY * 0.75 - u * GY * 0.62, 26, Col(0xb8c0ff, 0.06 * a), Col(0xb8c0ff, 0))
            }
            let st = (NOW + 3).truncatingRemainder(dividingBy: 17)
            if st < 0.8 {
                let sx0 = W * (0.2 + hashN(floor((NOW + 3) / 17)) * 0.5), sy0 = GY * 0.12
                let p = st / 0.8
                c.seg(sx0 + p * 60 - 18, sy0 + p * 22 - 6.6, sx0 + p * 60, sy0 + p * 22, 0.7, Col(0xffffff, (1 - p) * 0.9))
            }
        }
        // New Year's Eve fireworks over town
        if g.fireworks {
            let cols: [Col] = [Col(0xff5a5a), Col(0xffd24a), Col(0x6ad0ff), Col(0xb48aff), Col(0x7aff9a), Col(0xffffff)]
            for k in 0..<5 {
                let cyc = 2.2 + Double(k) * 0.37
                let tt = (NOW + Double(k) * 0.9).truncatingRemainder(dividingBy: cyc) / cyc
                let id = floor((NOW + Double(k) * 0.9) / cyc) + Double(k) * 17
                let cx = W * (0.12 + hashN(id) * 0.76), cy = GY * (0.12 + hashN(id + 1) * 0.3)
                let col = cols[Int(hashN(id + 2) * 6) % 6]
                if tt < 0.25 {
                    let up = tt / 0.25
                    c.circ(cx, GY - (GY - cy) * up, 0.9, Col(0xfff0c0, 0.9))
                } else {
                    let p = (tt - 0.25) / 0.75
                    for j in 0..<18 {
                        let a = Double(j) / 18 * PI * 2
                        let r = p * (40 + hashN(id + 3) * 26)
                        let ex = cx + cos(a) * r, ey = cy + sin(a) * r + p * p * 12
                        c.seg(ex - cos(a) * 6 * (1 - p), ey - sin(a) * 6 * (1 - p), ex, ey, 0.9, col.alpha(0.5 * (1 - p)))
                        c.circ(ex, ey, 1.8 * (1 - p) + 0.4, col.alpha(1 - p * 0.9))
                    }
                    if p < 0.3 { c.glow(cx, cy, 60, col.alpha(0.4 * (1 - p * 3.3)), col.alpha(0)) }
                }
            }
        }
        // a rainbow the morning after rain
        if g.phase == .play && g.afterRain > 0 && t > 0.05 && t < 0.35 && g.weather < 3 {
            let rb: [Col] = [Col(0xff5a4a), Col(0xffa040), Col(0xffe060), Col(0x60d070), Col(0x5a9aff), Col(0x8a6aff)]
            for (k, col) in rb.enumerated() {
                c.arcStroke(W * 0.62, GY + 10, GY * 0.78 - Double(k) * 2.2, PI * 1.05, PI * 1.95, 2.2, col.alpha(0.22))
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
        if [Area.ltva, .dome, .trail, .scaddan, .roadrunner, .hijolly, .plomosa, .crystal, .palms].contains(ar) {
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
            if g.phase == .play {
                critters(ar)
                eventCrowds(ar)
                if ar == .main { mainDecor() }
                manners()
                if ar == .main || ar == .tyson { streetTraffic(ar) }
            }
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
            let happy = NOW - g.petT < 2.5
            dog(dx - cam, GY + 6 + g.ground(dx) - (happy ? abs(sin(NOW * 12)) * 2 : 0), g.face, g.walk * (g.onToy ? 1.6 : 1) + (abs(g.vx) > 4 ? 0 : NOW * (happy ? 6 : 0.5)), g.dogCholla)
            if happy {
                let t = (NOW - g.petT) / 2.5
                for k in 0..<3 {
                    let hx = dx - cam + Double(k - 1) * 5, hy = GY - 4 - t * 18 - Double(k) * 3
                    c.circ(hx - 1, hy, 1.3, Col(0xe0405a, 1 - t)); c.circ(hx + 1, hy, 1.3, Col(0xe0405a, 1 - t))
                    c.poly(Col(0xe0405a, 1 - t), [hx - 2.3, hy + 0.4, hx + 2.3, hy + 0.4, hx, hy + 3])
                }
            }
            if !g.onToy && g.phase == .play { g.hits.append(Hit(id: 76, x: dx - cam - 12, y: GY - 10, w: 24, h: 22)) }
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
        case .tyson:
            // Tyson Wells as it looks: white metal buildings, big peaked white show tents, flags on tall poles
            let showOn = g.phase == .play && (g.tysonShow() != nil || g.on(EV_RV))
            let gap = 150.0
            var n = floor((cam * par - 160) / gap)
            while n * gap < cam * par + W + 160 {
                let sx = n * gap - cam * par
                if hashN(n + 1800) < 0.42 {
                    let w = 96 + hashN(n + 1810) * 30, h = 22 + hashN(n + 1811) * 6
                    let col = Col(0xeceae4).shade(1 - dark * 0.5)
                    c.R(sx, GY - h, w, h + 1, col)
                    var rx = sx
                    while rx < sx + w { c.R(rx, GY - h, 0.5, h, col.shade(0.93)); rx += 3.4 }
                    c.poly(col.shade(0.88), [sx - 2, GY - h, sx + w / 2, GY - h - 7, sx + w + 2, GY - h])
                    var d = 0.0
                    while d + 20 < w {
                        c.R(sx + 8 + d, GY - 15, 16, 15, col.shade(0.84))
                        for l in 0..<5 { c.R(sx + 8 + d, GY - 14 + Double(l) * 3, 16, 0.5, col.shade(0.74)) }
                        d += 30
                    }
                } else {
                    let w = 120 + hashN(n + 1820) * 40
                    let tent = Col(0xf6f4f0).shade(1 - dark * 0.5)
                    let peaks = max(2, Int(w / 38))
                    let pw = w / Double(peaks)
                    for p in 0..<peaks {
                        let px0 = sx + Double(p) * pw
                        c.poly(tent.shade(0.95), [px0, GY - 17, px0 + pw / 2, GY - 29, px0 + pw, GY - 17])
                        c.seg(px0 + pw / 2, GY - 29, px0 + pw / 2, GY - 32, 0.5, Col(0x9a9a9a))
                    }
                    c.R(sx, GY - 17, w, 18, tent)
                    if showOn {
                        let wares: [Col] = [Col(0x9a5ad0), Col(0x2fa7a0), Col(0xe2742e), Col(0xd04a8a), Col(0x3a6ea5), Col(0xf2c14e)]
                        var j = sx + 4
                        while j < sx + w - 6 { c.R(j, GY - 13 + hashN(j * 0.1) * 3, 4, 6 + hashN(j * 0.2) * 5, wares[Int(hashN(j * 0.3) * 6) % 6].shade(1 - dark * 0.5)); j += 6 }
                    } else {
                        var j = sx + 12
                        while j < sx + w { c.R(j, GY - 17, 0.5, 18, tent.shade(0.88)); j += 12 }
                    }
                }
                // flags on tall poles, and feather flags along the aisles during a show
                if hashN(n + 1830) < 0.75 {
                    let fx = sx + gap * 0.82
                    c.R(fx - 0.5, GY - 50, 1, 50, Col(0xb8b8b4).shade(1 - dark * 0.5))
                    let wv = sin(NOW * 3 + n) * 1.2
                    let kind = Int(hashN(n + 1840) * 3)
                    if kind == 0 {
                        for st in 0..<5 { c.poly((st % 2 == 0 ? Col(0xc8281e) : Col(0xf4f4f0)).shade(1 - dark * 0.4), [fx + 0.5, GY - 50 + Double(st) * 1.5, fx + 13, GY - 50 + Double(st) * 1.5 + wv, fx + 13, GY - 48.5 + Double(st) * 1.5 + wv, fx + 0.5, GY - 48.5 + Double(st) * 1.5]) }
                        c.R(fx + 0.5, GY - 50, 5.4, 4.4, Col(0x24324a).shade(1 - dark * 0.4))
                    } else {
                        let fc = (kind == 1 ? Col(0xf2c14e) : Col(0x2f5a9a)).shade(1 - dark * 0.4)
                        c.poly(fc, [fx + 0.5, GY - 50, fx + 13, GY - 50 + wv, fx + 13, GY - 42.5 + wv, fx + 0.5, GY - 42.5])
                        if kind == 1 { c.circ(fx + 7, GY - 46.4 + wv * 0.5, 1.6, Col(0xc8281e).shade(1 - dark * 0.4)) }
                    }
                }
                if showOn {
                    for j in 0..<3 { featherFlag(sx + 18 + Double(j) * 46, GY + 1, Int(hashN(n * 3 + Double(j) + 1850) * 5), n + Double(j)) }
                }
                n += 1
            }
            // chain-link along the lot
            c.R(0, GY - 9, W, 0.5, Col(0x9a9a98, 0.6))
            var fp = -((cam * par).truncatingRemainder(dividingBy: 24))
            while fp < W { c.R(fp, GY - 9, 0.6, 9, Col(0x8a8a88, 0.6)); fp += 24 }
            if g.phase == .play && g.tysonShow() != nil {
                let tops: [Col] = [Col(0xf6f4f0), Col(0xf6f4f0), Col(0x3a6ea5), Col(0xf6f4f0), Col(0xd9412e)]
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
        case .main:
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
            // the Colorado River at the west end, and the I-10 bridge over to Blythe, California
            let bx0 = 40 - cam * 0.55
            if bx0 < W + 40 && bx0 + 420 > -40 {
                let deck = Col(0xc8c0b0).shade(1 - dark * 0.5)
                for k in 0..<6 { c.R(bx0 + 20 + Double(k) * 72, GY - 30, 7, 30, deck.shade(0.85)) }
                c.R(bx0, GY - 36, 420, 6, deck)
                c.R(bx0, GY - 37.4, 420, 1.4, deck.shade(1.1))
                for k in 0..<42 { c.R(bx0 + Double(k) * 10, GY - 40, 0.7, 3, deck.shade(0.8)) }
                c.R(bx0, GY - 40, 420, 0.7, deck.shade(0.8))
                let tc = (NOW * 30).truncatingRemainder(dividingBy: 520) - 50
                rig(.classC, bx0 + tc, GY - 36, 0, 1, 0.32)
                let tc2 = 470 - (NOW * 38 + 200).truncatingRemainder(dividingBy: 520)
                c.save(); c.translate(bx0 + tc2, GY - 36); c.scale(0.32, 0.32)
                toy(4, 0, 0, -1, -1, 0)
                c.restore()
                c.R(bx0 + 30, GY - 50, 1, 10, Col(0x6a6a6a)); c.RR(bx0 + 14, GY - 58, 34, 8, 1, Col(0x1f4a8a))
                g.text("CALIFORNIA", bx0 + 31, GY - 54, 2.8, CREAM, bold: true)
            }
            let rx1 = 560 - cam
            if rx1 > -20 {
                c.vfill(-cam - 40, GY - 9, rx1 + cam + 40, 9, [(0, Col(0x4a7a8a).shade(1 - dark * 0.55)), (1, Col(0x2f5a6a).shade(1 - dark * 0.55))])
                for k in 0..<14 {
                    let d = Double(k)
                    let wx = (hashN(d + 70) * 540 + NOW * 6).truncatingRemainder(dividingBy: 540) - cam
                    c.R(wx, GY - 7.4 + hashN(d + 71) * 5, 6 + hashN(d + 72) * 8, 0.6, Col(0xffffff, 0.3 * (1 - dark * 0.6)))
                }
                for k in 0..<5 { palm(rx1 - 10 - Double(k) * 110 + hashN(Double(k) + 80) * 30, GY - 6, 34 + hashN(Double(k) + 81) * 16, Double(k) + 82) }
            }
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
        case .hijolly, .plomosa:
            // boondockers spread out across the open desert
            let gap = ar == .hijolly ? 180.0 : 240.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1900 + Double(ar.rawValue)) < 0.6 {
                    let sx = n * gap + hashN(n + 1910) * 80 - cam * par
                    let kinds: [RigKind] = [.classA, .classC, .van, .skoolie, .classB, .minivan]
                    rig(kinds[Int(hashN(n + 1920 + Double(ar.rawValue)) * 6) % 6], sx, GY + 0.5, 2, hashN(n + 1930) < 0.5 ? 1 : -1, 0.5); campDress(sx, n)
                }
                n += 1
            }
        case .crystal:
            // the Kofa's jagged volcanic ridges, a few campers, quartz glinting on the slope
            let kx = W * 0.5 - cam * 0.18
            let kofa = Col(0x7a5a4a).shade(1 - dark * 0.6)
            c.poly(kofa, [kx - 260, GY + 1, kx - 200, GY - 40, kx - 170, GY - 28, kx - 130, GY - 62, kx - 90, GY - 44, kx - 40, GY - 70, kx + 10, GY - 38, kx + 60, GY - 52, kx + 120, GY - 30, kx + 200, GY + 1])
            c.poly(kofa.shade(0.85), [kx - 40, GY - 70, kx + 10, GY - 38, kx - 20, GY + 1, kx - 70, GY + 1])
            var n = floor((cam * par - 70) / 400)
            while n * 400 < cam * par + W + 70 {
                if hashN(n + 1950) < 0.5 { rig([.van, .classB, .classC][Int(hashN(n + 1960) * 3) % 3], n * 400 + hashN(n + 1970) * 120 - cam * par, GY + 0.5, 1, 1, 0.5); campDress(n * 400 - cam * par, n) }
                n += 1
            }
            for k in 0..<30 {
                let d = Double(k) + 1980
                let gx = (hashN(d) * 2000 - cam * 0.9)
                if gx > -10 && gx < W + 10 && sin(NOW * 2 + d) > 0.7 { c.circ(gx, GY - 2 - hashN(d + 1) * 10, 0.8, Col(0xffffff, 0.9)) }
            }
        case .palms:
            // the canyon wall, with the palms tucked high in a shady slot
            let cx = W * 0.55 - cam * 0.3
            let wall = Col(0x8a6450).shade(1 - dark * 0.6)
            c.poly(wall, [cx - 320, GY + 1, cx - 300, GY - 70, cx - 220, GY - 90, cx - 120, GY - 84, cx - 60, GY - 100, cx + 40, GY - 96, cx + 140, GY - 82, cx + 260, GY - 88, cx + 340, GY + 1])
            c.poly(Col(0x3a2a24).shade(1 - dark * 0.5), [cx - 34, GY - 98, cx - 14, GY - 98, cx - 4, GY - 20, cx - 40, GY - 20])
            for k in 0..<4 {
                let px = cx - 30 + Double(k) * 7, py = GY - 62 + Double(k % 2) * 6
                c.R(px - 0.6, py, 1.2, 10, Col(0x6a5040))
                for f in 0..<7 {
                    let a = Double(f) / 6 * PI
                    c.seg(px, py, px + cos(a) * 5, py - sin(a) * 4 + 1, 1, Col(0x4f7a3a).shade(1 - dark * 0.5))
                }
            }
            for k in 0..<8 { let d = Double(k) + 2000; c.R(cx - 300 + hashN(d) * 620, GY - 80 + hashN(d + 1) * 60, 18, 0.7, wall.shade(0.85)) }
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
            // the wash itself: a line of palo verde and ironwood, and far rigs back in the bajada
            var fw = floor((cam * 0.5 - 40) / 46)
            while fw * 46 < cam * 0.5 + W + 40 {
                if hashN(fw + 1700) < 0.6 {
                    let fx = fw * 46 + hashN(fw + 1710) * 20 - cam * 0.5
                    rig([.classC, .classA, .van, .skoolie][Int(hashN(fw + 1720) * 4) % 4], fx, GY - 9, 0, hashN(fw + 1730) < 0.5 ? 1 : -1, 0.3)
                    if dark > 0.4 && hashN(fw + 1740) < 0.5 { c.circ(fx + 10, GY - 10, 0.9, Col(0xffb050)); lights.append((fx + 10, GY - 10, 8)) }
                }
                fw += 1
            }
            var tw = floor((cam * 0.85 - 60) / 70)
            while tw * 70 < cam * 0.85 + W + 60 {
                if hashN(tw + 1750) < 0.75 {
                    let tx = tw * 70 + hashN(tw + 1760) * 40 - cam * 0.85
                    if hashN(tw + 1770) < 0.5 { paloverde(tx, GY - 2, tw) }
                    else { ironwood(tx, GY - 2, tw) }
                }
                tw += 1
            }
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
                let bx = q * 520 + 300 - bp
                let sgn = W + 80 - (cam * 0.9).truncatingRemainder(dividingBy: W + 260)
                if hashN(q + 700) < 0.6 && abs(bx - sgn) > 95 {
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
        // something on the near shoulder: tap it to pull over
        if !g.stopDone && g.stopX > -80 {
            let sx = g.stopX, sb = g.laneBase(1) + 14
            if g.stopKind == 0 {
                rig(.van, sx, sb, 0, -1, 0.8)
                c.poly(Col(0xf4f1ea, 0.85).shade(1 - dark * 0.4), [sx + 30, sb - 15, sx + 34, sb - 23, sx + 34, sb - 15])
                person(sx + 30, sb + 1, 2, -1, NOW * 6, false)
                c.seg(sx + 31, sb - 15, sx + 33 + sin(NOW * 8) * 2, sb - 22, 0.9, Col(0xd9a88a))
                c.poly(Col(0xf2862e), [sx - 40, sb, sx - 38, sb - 5, sx - 36, sb])
            } else {
                for k in 0..<3 { c.R(sx - 12 + Double(k) * 7, sb - 6 - Double(k % 2) * 2, 6, 6 + Double(k % 2) * 2, Col(0xb8925e).shade(0.9 + Double(k) * 0.06)) }
                c.R(sx + 12, sb - 14, 1, 14, Col(0x6a4e30))
                c.R(sx + 6, sb - 18, 13, 6, Col(0xf4f1ea))
                g.text("FREE", sx + 12.5, sb - 15, 3.6, Col(0xd9412e), bold: true)
                c.circ(sx - 6, sb - 9, 1.2, Col(0x2fa7a0)); c.circ(sx + 2, sb - 11, 1, Col(0xd04a8a))
            }
            let pulse = 0.5 + 0.5 * sin(NOW * 5)
            c.glow(sx, sb - 10, 30, Col(0xfff0b0, 0.22 + 0.15 * pulse), Col(0xfff0b0, 0))
            g.text(g.stopKind == 0 ? "Help?" : "Stop?", sx, sb - 34, 5, CREAM, bold: true, plate: true)
            g.hits.append(Hit(id: 66, x: sx - 46, y: sb - 44, w: 92, h: 52))
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
        if g.stopMsgT > 0 { g.text(g.stopMsg, W / 2, 38, 5.6, GOLD, bold: true, plate: true) }
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
        case 0:
            if g.driveTow {
                let back = x - RIGS[g.rig.rawValue].len / 2
                if g.toy < 3 {
                    // bike rack off the back
                    c.R(back - 4, base - 8, 5, 1.2, Col(0x2a2a2e))
                    toy(g.toy, back - 7, base - 7.5, 1, -1, 0)
                } else {
                    // a little utility trailer
                    let tx = back - 26
                    c.R(back - 6, base - 4, 7, 1.2, Col(0x3a3a3e))
                    c.R(tx - 22, base - 5.5, 44, 2.4, Col(0x4a4a4e))
                    c.circ(tx, base - 2.6, 2.8, Col(0x22201e)); c.circ(tx, base - 2.6, 1.2, Col(0x9a9a98))
                    toy(g.toy, tx, base - 5.5, 1, -1, 0)
                }
            }
            rig(g.rig, x, base, g.panels, 1)
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
        let lk = lookOf(look)
        let skin = lk.skin, shirt = lk.shirt, pants = lk.pants
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
            c.dome(x + 0.3, hy - 0.6, 2.8, lk.hat == 4 ? Col(0x3a2a1e) : lk.hatCol)
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

    /// Colours and headwear for a look: 0–3 are the player looks; higher numbers are townsfolk, each a little different.
    private func lookOf(_ look: Int) -> (skin: Col, shirt: Col, pants: Col, hat: Int, hatCol: Col) {
        if look >= 0 && look < 4 {
            return (SKINS[look], SHIRTS[look], PANTS[look], look, [Col(0xd9c07a), Col(0x8a3a5a), Col(0x2f4f7a), Col(0xefe6cf)][look])
        }
        let h = Double(look) * 1.618
        let skins = [Col(0xf0c8a0), Col(0xd9a37a), Col(0xc48a62), Col(0xa8744c), Col(0x8a5a3a), Col(0x6a4430)]
        let shirts = [Col(0xb5452f), Col(0x4a5a6e), Col(0x3f8f8a), Col(0xd9c9a8), Col(0x7a4a8a), Col(0xe2a03a), Col(0x2f6a4a), Col(0xf4f1ea), Col(0x3a6ea5), Col(0xc85a7a), Col(0x5a5a5e)]
        let pants = [Col(0x3d4a66), Col(0x2c2c30), Col(0x7a6a4e), Col(0x5a6a7a), Col(0x8a7a5a)]
        let hats = [Col(0xd9c07a), Col(0x8a3a5a), Col(0x2f4f7a), Col(0xefe6cf), Col(0x3a2a1e), Col(0x8a6a3a), Col(0xb5452f), Col(0x6a5a4a)]
        func pick(_ a: [Col], _ s: Double) -> Col { return a[Int(hashN(h + s) * Double(a.count)) % a.count] }
        return (pick(skins, 1), pick(shirts, 2), pick(pants, 3), Int(hashN(h + 4) * 6) % 6, pick(hats, 5))
    }

    func person(_ x: Double, _ base: Double, _ look: Int, _ face: Double, _ ph: Double, _ moving: Bool) {
        if x < -20 || x > W + 20 { return }
        let lk = lookOf(look)
        let skin = lk.skin, shirt = lk.shirt, pants = lk.pants
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
        let hc = lk.hatCol
        switch lk.hat {
        case 0:     // straw hat
            c.dome(x + face * 0.3, hy - 1, 2.6, hc)
            c.ell(x + face * 0.3, hy - 1, 4.6, 0.9, hc.shade(0.92))
        case 1:     // beanie
            c.dome(x + face * 0.3, hy - 0.4, 2.9, hc)
        case 2:     // ball cap
            c.dome(x + face * 0.3, hy - 0.8, 2.8, hc)
            c.R(face > 0 ? x + 2 : x - 5.4, hy - 1.2, 3.4, 0.9, hc)
        case 3:     // grey hair and a wide sun hat
            c.dome(x + face * 0.2, hy - 0.2, 2.9, Col(0xd8d8d4))
            c.ell(x + face * 0.3, hy - 1.8, 5.2, 0.9, hc)
            c.dome(x + face * 0.3, hy - 1.8, 2.3, hc)
        case 4:     // just hair
            c.dome(x + face * 0.1, hy - 0.3, 2.9, [Col(0x2a1c14), Col(0x6a4a2a), Col(0xd8c070), Col(0xc8c8c4)][Int(hashN(Double(look) + 9) * 4) % 4])
        default:    // cowboy hat
            c.dome(x + face * 0.3, hy - 1.4, 2.4, hc)
            c.ell(x + face * 0.3, hy - 1.2, 5, 0.8, hc.shade(0.9))
            c.R(x + face * 0.3 - 5, hy - 2.2, 1, 1.2, hc.shade(0.9)); c.R(x + face * 0.3 + 4, hy - 2.2, 1, 1.2, hc.shade(0.9))
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
            if g.weather == 3 && g.phase == .play {
                // a flash flood: muddy water running fast through the wash
                c.vfill(x - 60, GY - 3, 120, 9, [(0, Col(0x9a7a52).shade(1 - dark * 0.5)), (1, Col(0x6a4e30).shade(1 - dark * 0.5))])
                for k in 0..<16 {
                    let d = Double(k)
                    let fx = (hashN(d + 120) * 120 + NOW * (40 + hashN(d + 121) * 30)).truncatingRemainder(dividingBy: 120) - 60
                    c.R(x + fx, GY - 2 + hashN(d + 122) * 6, 5 + hashN(d + 123) * 7, 0.7, Col(0xe8d8b8, 0.55))
                }
                c.RR(x + 36, GY - 22, 26, 12, 1, Col(0xf2c14e))
                g.text("FLOODED", x + 49, GY - 17.6, 3.2, INK, bold: true)
                c.R(x + 48.4, GY - 10, 1.2, 10, Col(0x6a6a6a))
            }
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
            if g.neighborVisit {
                // a neighbor over for coffee, mug in hand
                person(x + 30, GY + 3, 505 + g.day * 7, -1, 0, false)
                c.R(x + 25.4, GY - 12, 2.4, 2.6, Col(0xf4f1ea))
                for k in 0..<2 {
                    let t = (NOW * 0.7 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
                    c.circ(x + 26.6 + sin(t * 6) * 0.8, GY - 13.5 - t * 6, 0.6 + t, Col(0xffffff, (1 - t) * 0.5))
                }
                if !near { g.text("Morning! It's " + g.neighbor(0).0 + ".", x + 30, GY - 32, 4.4, CREAM, bold: true, plate: true) }
            }
            if g.rigArea == g.area || g.phase != .play {
                fire(x + 4, GY + 3)
            } else {
                c.ell(x + 4, GY + 3, 6, 1.6, Col(0x4a4038))
                for j in 0..<5 { c.circ(x - 1 + Double(j) * 2.5, GY + 3, 1.2, Col(0x7a7068)) }
            }
            c.poly(Col(0x3f6a8a), [x + 16, GY + 2, x + 17, GY - 8, x + 19, GY - 8, x + 20, GY - 2, x + 25, GY - 2, x + 25, GY + 2])
            if g.rigArea == g.area && g.phase == .play {
                // home: an outdoor rug, a second chair, a little table with a lantern, the solar suitcase, the dog's bowl
                let rug = [Col(0xb5452f), Col(0xf2c14e), Col(0x3a6ea5), Col(0x3f8f6a)]
                for k in 0..<8 { c.R(x - 34 + Double(k) * 4, GY + 4.5, 4, 2.4, rug[k % 4].shade(1 - dark * 0.5)) }
                c.poly(Col(0xb5452f).shade(1 - dark * 0.4), [x - 12, GY + 2, x - 11, GY - 8, x - 9, GY - 8, x - 8, GY - 2, x - 3, GY - 2, x - 3, GY + 2])
                c.R(x + 28, GY - 7, 10, 1.4, Col(0xe8e0d0).shade(1 - dark * 0.4))
                c.R(x + 29, GY - 6, 0.8, 7, Col(0x8a8a88)); c.R(x + 36, GY - 6, 0.8, 7, Col(0x8a8a88))
                c.RR(x + 31, GY - 11, 3, 4, 0.8, Col(0x2a2a2e)); c.circ(x + 32.5, GY - 9, 1, Col(0xffd68a))
                if dark > 0.3 { lights.append((x + 32.5, GY - 9, 22)) }
                if g.panels > 0 {
                    c.poly(Col(0x24324a).shade(1 - dark * 0.3), [x + 44, GY + 2, x + 48, GY - 10, x + 62, GY - 10, x + 58, GY + 2])
                    for k in 0..<3 { c.seg(x + 46.6 + Double(k) * 4.4, GY - 1, x + 50 + Double(k) * 4.4, GY - 9.6, 0.3, Col(0x6a8aaa)) }
                }
                if g.hasDog { c.ell(x - 22, GY + 2.4, 2.4, 0.9, Col(0x3a6ea5)); c.ell(x - 22, GY + 2, 1.6, 0.5, Col(0x8ab4d8)) }
            }
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
            // Roadrunner Market: a long white block with red lettering and a roadrunner at each end
            let wall = Col(0xf2eee6)
            facade(x - 58, GY - 30, 116, 30, wall)
            let band = Col(0xd9776a).shade(1 - dark * 0.4)
            c.R(x - 58, GY - 8, 116, 7, band)
            var sc = x - 58.0
            while sc < x + 58 { c.poly(wall.shade(1 - dark * 0.45), [sc, GY - 8, sc + 6, GY - 8, sc + 3, GY - 5]); sc += 6 }
            c.R(x - 60, GY - 39, 120, 10, wall.shade(1 - dark * 0.45))
            c.R(x - 60, GY - 29.4, 120, 0.8, Col(0x000000, 0.12))
            g.text("ROADRUNNER MARKET", x, GY - 34.5, 5.4, Col(0xc8281e), bold: true)
            roadrunnerSign(x - 50, GY - 34, 1, Col(0xc8281e)); roadrunnerSign(x + 50, GY - 34, -1, Col(0xc8281e))
            g.text("DELI · ICE · BEER · PRODUCE", x - 8, GY - 25.5, 2.8, Col(0x3a3a3e), bold: true)
            pane(x - 52, GY - 21, 15, 10); pane(x - 33, GY - 21, 15, 10); pane(x - 14, GY - 21, 15, 10)
            doorway(x + 30, GY - 18, 14, 18, Col(0x6a4a34))
            c.arcStroke(x + 37, GY - 18, 8, PI, PI * 2, 1.4, wall.shade(0.8))
            c.R(x + 10, GY - 10, 13, 10, Col(0xf4f4f8).shade(1 - dark * 0.4)); g.text("ICE", x + 16.5, GY - 6, 3, Col(0x3a6ea5), bold: true)
            if dark > 0.3 { lights.append((x - 30, GY - 16, 30)) }
            label = false
            top = 56
        case .tour:
            // a converted bus with its door open and an A-frame sign out front
            rig(.skoolie, x, GY, 2, 1, 1)
            c.R(x + 30, GY - 22, 6, 19, Col(0x2a1e14))
            c.poly(Col(0x8a6a44), [x - 74, GY + 1, x - 68, GY - 16, x - 62, GY + 1])
            c.RR(x - 76, GY - 16, 16, 11, 1, Col(0x2a2a2e))
            g.text("OPEN", x - 68, GY - 12.6, 3, CREAM, bold: true)
            g.text("HOUSE", x - 68, GY - 8.4, 3, CREAM, bold: true)
            if g.phase == .play && g.on(EV_SKOOL) { person(x + 46, GY + 3, 777 + g.day, -1, 0, false) }
            top = 62
        case .pizza:
            // Silly Al's: low stucco under a red tile roof, a patio out front
            facade(x - 40, GY - 26, 80, 26, Col(0xe8d8bc))
            c.poly(Col(0xb8422e).shade(1 - dark * 0.4), [x - 46, GY - 26, x - 38, GY - 34, x + 38, GY - 34, x + 46, GY - 26])
            for j in 0..<16 { c.R(x - 42 + Double(j) * 5.4, GY - 30, 0.6, 3.6, Col(0x8a2e1e).shade(1 - dark * 0.4)) }
            c.RR(x - 32, GY - 47, 64, 11, 2, Col(0x2a2a2e))
            g.text("SILLY AL'S PIZZA", x, GY - 41.5, 4.4, Col(0xf2c14e), bold: true)
            pane(x - 34, GY - 20, 18, 11); pane(x + 16, GY - 20, 18, 11)
            doorway(x - 6, GY - 20, 12, 20, Col(0x5a2e1e))
            c.R(x + 54, GY - 22, 1, 22, Col(0x6a6a6a))
            c.poly(Col(0xd9412e).shade(1 - dark * 0.4), [x + 42, GY - 20, x + 54.5, GY - 26, x + 67, GY - 20])
            c.R(x + 47, GY - 7, 15, 1.4, wood); c.R(x + 48, GY - 6, 1, 6, wood); c.R(x + 60, GY - 6, 1, 6, wood)
            if dark > 0.3 { g.text("OPEN", x + 25, GY - 14, 3.2, Col(0xff5a6a), bold: true); lights.append((x + 25, GY - 14, 16)) }
            label = false
            top = 54
        case .post:
            // the post office: tan brick, the flag out front, a blue collection box
            facade(x - 36, GY - 26, 72, 26, Col(0xc9a07a))
            c.R(x - 40, GY - 29, 80, 3.4, Col(0xe8e0d0).shade(1 - dark * 0.4))
            g.text("POST OFFICE", x, GY - 21.5, 4.2, Col(0x24324a), bold: true)
            g.text("QUARTZSITE, AZ 85346", x, GY - 17, 2.4, Col(0x24324a))
            doorway(x - 7, GY - 14, 14, 14, Col(0x3a4a5a)); pane(x - 30, GY - 13, 14, 8); pane(x + 16, GY - 13, 14, 8)
            c.R(x - 54, GY - 50, 1, 50, Col(0xc8c8c4).shade(1 - dark * 0.4))
            let wv = sin(NOW * 4) * 0.8
            for j in 0..<5 {
                let yy = GY - 49 + Double(j) * 1.6
                c.poly((j % 2 == 0 ? Col(0xc8281e) : Col(0xf4f4f0)).shade(1 - dark * 0.4), [x - 53, yy, x - 46, yy + wv * 0.5, x - 39, yy + wv, x - 39, yy + wv + 1.6, x - 46, yy + wv * 0.5 + 1.6, x - 53, yy + 1.6])
            }
            c.R(x - 53, GY - 49, 6, 4.8, Col(0x24324a).shade(1 - dark * 0.4))
            c.RR(x + 44, GY - 12, 7, 10, 2.5, Col(0x2a4a8a).shade(1 - dark * 0.4))
            c.R(x + 44.6, GY - 2, 1, 2, Col(0x2a2a2e)); c.R(x + 49.4, GY - 2, 1, 2, Col(0x2a2a2e))
            label = false
            top = 56
        case .laundry:
            // Main Street Laundromat: a tan metal building, a palm, an old orange van parked out front
            let tan = Col(0xc8b89a)
            facade(x - 34, GY - 24, 68, 24, tan)
            var rib = x - 34.0
            while rib < x + 34 { c.R(rib, GY - 24, 0.6, 24, tan.shade(0.88 - dark * 0.4)); rib += 3.4 }
            c.poly(tan.shade(1.08 - dark * 0.45), [x - 38, GY - 24, x, GY - 33, x + 38, GY - 24])
            pane(x - 26, GY - 18, 14, 9); doorway(x - 4, GY - 18, 10, 18, Col(0x5a5a5e)); pane(x + 12, GY - 18, 14, 9)
            c.R(x + 52, GY - 38, 1.4, 38, Col(0x8a8a88))
            c.RR(x + 40, GY - 51, 26, 14, 2, Col(0xf4f4f0).shade(1 - dark * 0.3))
            g.text("LAUNDRY", x + 53, GY - 46.5, 3.2, Col(0x2f5a8a), bold: true)
            g.text("SHOWERS", x + 53, GY - 41.5, 3.2, Col(0x2f5a8a), bold: true)
            palm(x - 46, GY + 1, 36, 11)
            let vo = Col(0xe2862e).shade(1 - dark * 0.4)
            c.RR(x - 30, GY - 9, 32, 9, 3, vo)
            c.R(x - 26, GY - 7.4, 5, 3, GLASS); c.R(x - 19, GY - 7.4, 5, 3, GLASS); c.R(x - 12, GY - 7.4, 5, 3, GLASS)
            c.poly(GLASS, [x - 5, GY - 7.4, x - 1, GY - 7.4, x + 1.4, GY - 4.4, x - 5, GY - 4.4])
            c.R(x - 31, GY - 1.6, 34, 1, Col(0xc8c8c4))
            for wx in [-23.0, -4.0] { c.circ(x + wx, GY + 0.4, 2.4, TIRE); c.circ(x + wx, GY + 0.4, 1, HUB) }
            label = false
            top = 56
        case .shop:
            label = false
            switch sp.arg {
            case 0:
                // Big Market: hardware, groceries, RV basics
                // tan block: HARDWARE on the left, BIG MARKET on the right, a maroon awning over the door, a carport to the side
                facade(x - 52, GY - 30, 104, 30, Col(0xd8c4a0))
                c.R(x - 52, GY - 31.4, 104, 1.6, Col(0xc8b490).shade(1 - dark * 0.4))
                g.text("HARDWARE", x - 30, GY - 25, 4.4, Col(0xb5281e), bold: true)
                g.text("RV SUPPLY", x - 30, GY - 20, 3, Col(0x3a3a3e), bold: true)
                c.RR(x + 10, GY - 29, 36, 8, 1, Col(0xb5281e).shade(1 - dark * 0.3))
                g.text("BIG MARKET", x + 28, GY - 25, 3.8, CREAM, bold: true)
                c.poly(Col(0x7a2a2a).shade(1 - dark * 0.4), [x - 16, GY - 17, x + 16, GY - 17, x + 19, GY - 12, x - 19, GY - 12])
                pane(x - 46, GY - 15, 18, 9); pane(x + 26, GY - 15, 18, 9)
                doorway(x - 8, GY - 12, 16, 12, Col(0x5a5a5e))
                c.R(x - 92, GY - 20, 34, 1.6, Col(0x8a8a88).shade(1 - dark * 0.4))
                for cp in [-90.0, -76.0, -60.0] { c.R(x + cp, GY - 19, 0.9, 19, Col(0x6a6a6a)) }
                c.R(x + 56, GY - 14, 14, 14, Col(0x8a8a88, 0.45))
                for j in 0..<3 { c.RR(x + 57.4 + Double(j) * 4.2, GY - 9, 3.4, 8, 1.6, Col(0xf4f4f0)) }
                top = 44
            case 1, 5:
                // an RV park with a propane fill out front
                if sp.arg == 1 {
                    c.R(x - 1, GY - 40, 2, 40, Col(0x7a6a5a))
                    c.RR(x - 32, GY - 53, 64, 14, 2, Col(0x2f5a7a).shade(1 - dark * 0.3))
                    g.text("Q VIEW RV PARK", x, GY - 48.5, 3.8, CREAM, bold: true)
                    g.text("RV SPACES · PROPANE", x, GY - 43, 2.8, CREAM.alpha(0.85))
                } else {
                    c.R(x - 26, GY - 40, 2, 40, Col(0x4a4a4e)); c.R(x + 24, GY - 40, 2, 40, Col(0x4a4a4e))
                    c.RR(x - 30, GY - 54, 60, 16, 2, Col(0xf8f6f2).shade(1 - dark * 0.3))
                    g.text("PATTIE'S RV PARK", x, GY - 49, 3.8, Col(0x2a2a2e), bold: true)
                    g.text("& PROPANE", x, GY - 43.5, 3.2, Col(0xb5281e), bold: true)
                    c.R(x + 90, GY - 14, 22, 14, Col(0xe2662e).shade(1 - dark * 0.4))
                    for cr in 0..<5 { c.R(x + 91 + Double(cr) * 4.4, GY - 14, 0.5, 14, Col(0xb84a1e)) }
                }
                rig(.classC, x + 72, GY - 2, 1, -1, 0.5); rig(.classA, x - 70, GY - 2, 2, 1, 0.5)
                facade(x - 44, GY - 18, 26, 18, Col(0xd9c9a8))
                pane(x - 41, GY - 14, 8, 6); doorway(x - 29, GY - 14, 7, 14, Col(0x5a3a22))
                c.RR(x + 12, GY - 12, 32, 9, 4.5, Col(0xf4f4f0).shade(1 - dark * 0.4))
                c.R(x + 16, GY - 3, 1.4, 3, Col(0x6a6a6a)); c.R(x + 38, GY - 3, 1.4, 3, Col(0x6a6a6a))
                c.R(x + 26, GY - 14, 4, 2, Col(0x8a8a88))
                g.text("PROPANE", x + 28, GY - 7.5, 2.6, Col(0xc8281e), bold: true)
                top = 60
            case 2:
                // Happy Valley Pharmacy
                facade(x - 30, GY - 26, 60, 26, Col(0xe0d4bc))
                c.RR(x - 32, GY - 36, 64, 9, 2, Col(0x2f6a4a).shade(1 - dark * 0.3))
                g.text("HAPPY VALLEY PHARMACY", x, GY - 31.5, 3.2, CREAM, bold: true)
                c.R(x + 16, GY - 21, 8, 2.4, Col(0x3fb06a)); c.R(x + 18.8, GY - 23.8, 2.4, 8, Col(0x3fb06a))
                pane(x - 24, GY - 18, 16, 10); doorway(x - 4, GY - 18, 10, 18, Col(0x4a5a5a))
                top = 44
            case 3:
                // the auto parts store next to the market
                facade(x - 40, GY - 24, 80, 24, Col(0xf0ece4))
                c.poly(Col(0x9aa0a6).shade(1 - dark * 0.4), [x - 44, GY - 24, x - 40, GY - 28, x + 40, GY - 28, x + 44, GY - 24])
                g.text("AUTO PARTS", x - 12, GY - 19.5, 4.4, Col(0xc8281e), bold: true)
                pane(x - 34, GY - 14, 14, 8); pane(x - 4, GY - 14, 14, 8); doorway(x + 24, GY - 16, 10, 16, Col(0x3a3a3e))
                c.circ(x + 34, GY - 22, 3, Col(0x3a6ea5)); g.text("P", x + 34, GY - 22, 3, CREAM, bold: true)
                top = 40
            default:
                // Coyote Fresh Foods, with a howling coyote on the sign
                // rustic board-and-batten front under a pitched roof, a camel out front, feather flags
                let boards = Col(0x8a5a3a).shade(1 - dark * 0.45)
                facade(x - 40, GY - 26, 80, 26, Col(0x9a6a44))
                var bb = x - 40.0
                while bb < x + 40 { c.R(bb, GY - 26, 0.7, 26, boards); bb += 4 }
                c.poly(Col(0x6a4430).shade(1 - dark * 0.4), [x - 44, GY - 26, x, GY - 34, x + 44, GY - 26])
                camelSculpture(x - 58, GY + 1, 4)
                featherFlag(x + 50, GY + 1, 3, 4); featherFlag(x + 60, GY + 1, 0, 5)
                c.RR(x - 34, GY - 44, 68, 10, 2, Col(0x3a2a1e))
                g.text("COYOTE FRESH FOODS", x + 5, GY - 39, 3.4, Col(0xf2c14e), bold: true)
                let cy = Col(0xf2c14e)
                c.ell(x - 26, GY - 35, 2.6, 1.3, cy); c.circ(x - 23.4, GY - 37.6, 1, cy)
                c.seg(x - 23, GY - 38, x - 21.6, GY - 40.2, 0.6, cy); c.seg(x - 28.4, GY - 35, x - 30.6, GY - 33.6, 0.6, cy)
                c.seg(x - 27.6, GY - 34, x - 28, GY - 32.4, 0.5, cy); c.seg(x - 24.6, GY - 34, x - 24.4, GY - 32.4, 0.5, cy)
                pane(x - 34, GY - 20, 18, 10); pane(x + 16, GY - 20, 18, 10); doorway(x - 6, GY - 20, 12, 20, Col(0x4a3424))
                let fruit: [Col] = [Col(0xd9412e), Col(0xf29a2e), Col(0x6aa84a)]
                for j in 0..<3 {
                    let bx = x + 46 + Double(j) * 9
                    c.RR(bx, GY - 6, 8, 6, 1, Col(0xa98558))
                    for q in 0..<3 { c.circ(bx + 1.6 + Double(q) * 2.4, GY - 6.4, 1.3, fruit[j]) }
                }
                top = 50
            }
        case .tools:
            let wall = Col(0xb9b3a6)
            facade(x - 42, GY - 38, 84, 38, wall)
            var lx = x - 42.0
            while lx < x + 42 { c.R(lx, GY - 38, 0.7, 38, wall.shade(0.86)); lx += 4.5 }
            c.poly(Col(0x7a8088), [x - 45, GY - 38, x - 40, GY - 44, x + 40, GY - 44, x + 45, GY - 38])
            doorway(x - 9, GY - 22, 18, 22, Col(0x33302c))
            pane(x - 34, GY - 26, 16, 10); pane(x + 18, GY - 26, 16, 10)
            c.RR(x - 28, GY - 57, 56, 12, 2, Col(0xf2c418).shade(1 - dark * 0.3))
            g.text("K&B", x - 10, GY - 51, 7.4, Col(0x2a1e14), bold: true)
            g.text("TOOLS", x + 13, GY - 51, 4.4, Col(0x2a1e14), bold: true)
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
            // flats stacked out front on a pallet
            c.R(x + 40, GY - 2, 22, 2, Col(0x8a6238))
            for r in 0..<3 {
                c.R(x + 41, GY - 5 - Double(r) * 3, 20, 3, Col(0xb8925e).shade(1 - Double(r) * 0.06))
                for q in 0..<5 { c.circ(x + 43 + Double(q) * 4, GY - 4.4 - Double(r) * 3, 0.9, [Col(0x9a5ad0), Col(0xe2742e), Col(0x2fa7a0), Col(0xf0f0f4), Col(0xc85a3a)][(q + r) % 5]) }
            }
            g.text("WHOLESALE", x, GY - 47.5, 3.6, GOLD, bold: true)
            if g.phase == .play { g.hits.append(Hit(id: 52, x: x - 36, y: GY - 46, w: 100, h: 46)) }
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
            // shoppers at your table, and a hand-lettered sign
            if g.phase == .play {
                person(x - 26, GY + 3, 600 + g.day * 3, 1, 0, false)
                person(x + 25, GY + 3, 611 + g.day * 5, -1, 0, false)
                if Int(NOW / 6) % 2 == 0 { person(x + 33, GY + 4, 622 + g.day, -1, 0, false) }
            }
            c.RR(x - 12, GY - 30, 24, 7, 1, Col(0xf4f1ea))
            g.text("ROCKS · ODDITIES", x, GY - 26.5, 2.6, Col(0x7a2f3a), bold: true)
            c.R(x - 16, GY - 9, 32, 9, Col(0x7a2f3a))
            c.R(x - 17, GY - 10, 34, 1.4, Col(0x9a4a54))
            for j in 0..<g.rocks { gem(x - 12 + Double(j) * 5, GY - 10, 2.2, [Col(0x9a5ad0), Col(0xe2742e), Col(0x2fa7a0)][j % 3]) }
            for j in 0..<g.odd { skull(x + 3 + Double(j) * 5, GY - 10, 0.65) }
            for j in 0..<min(6, g.rocks + g.odd) { c.R(x - 13 + Double(j) * 5, GY - 7.4, 2.4, 1.6, Col(0xf4f1ea)) }
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
                // weathered brown wood, a flat roof with a long sign across the front, a shaded porch
                let wall = Col(0x8a6a4a)
                facade(x - 34, GY - 26, 68, 26, wall)
                c.R(x - 42, GY - 28, 84, 3, Col(0x5a4030).shade(1 - dark * 0.4))
                for px2 in [-41.0, -15.0, 14.0, 40.0] { c.R(x + px2, GY - 26, 1.4, 26, Col(0x5a4030).shade(1 - dark * 0.4)) }
                c.RR(x - 36, GY - 39, 72, 11, 1, Col(0xefe6cf).shade(1 - dark * 0.4))
                g.text("READER'S OASIS BOOKS", x, GY - 33.5, 4.2, Col(0x3a2a1e), bold: true)
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
        case .hike:
            // a brown refuge trailhead sign and a sign-in box
            let post = Col(0x5a4030).shade(1 - dark * 0.4)
            c.R(x - 16, GY - 24, 2, 24, post); c.R(x + 14, GY - 24, 2, 24, post)
            c.RR(x - 22, GY - 38, 44, 15, 1.5, Col(0x5a3a22).shade(1 - dark * 0.4))
            g.text("PALM CANYON", x, GY - 33, 3.6, Col(0xf2e8c8), bold: true)
            g.text("TRAIL · 0.5 MI", x, GY - 27.6, 2.8, Col(0xf2e8c8, 0.85))
            c.R(x + 30, GY - 12, 1.4, 12, post); c.RR(x + 26, GY - 18, 10, 7, 1, Col(0x8a8a88))
            label = false
            top = 46
        case .river:
            c.seg(x - 4, GY, x - 2, GY - 7, 0.8, Col(0xb8b8b4)); c.seg(x + 4, GY, x + 2, GY - 7, 0.8, Col(0xb8b8b4))
            c.R(x - 4, GY - 7.6, 8, 1.4, Col(0x3a8a6a)); c.R(x - 3.6, GY - 13, 1.2, 6, Col(0x3a8a6a))
            c.RR(x + 7, GY - 5, 7, 5, 1, Col(0xd8412e)); c.R(x + 7, GY - 5, 7, 1.2, Col(0xf4f4f0))
            top = 30
        }
        if label && !near {
            let nm = sp.kind == .fire && g.phase == .play ? { let n = g.neighbor(sp.x > 1400 ? 2 : 4).0; return (n + (n.hasSuffix("s") ? "' FIRE" : "'S FIRE")).uppercased() }() : sp.name
            g.text(nm, x, GY - top, 5, CREAM.alpha(0.8), bold: true)
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
            let bulbs = g.holidays ? [Col(0xff4a4a), Col(0x4aff7a), Col(0xffffff), Col(0xffd040)] : [Col(0xffd68a), Col(0xff8a6a), Col(0x8ad0ff), Col(0xb8ff8a)]
            for i in 0..<10 {
                let t = Double(i) / 9
                let lx = x - 14 + 34 * t, ly = b - 13 + sin(PI * t) * 3
                c.circ(lx, ly, 0.7, bulbs[((i + Int(seed)) % 4 + 4) % 4].alpha(0.6 + 0.4 * dark))
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
    /// Desert ironwood: a dark blue-grey dome of a tree along the washes.
    private func ironwood(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -40 || x > W + 40 { return }
        let bark = Col(0x5a4a3e).shade(1 - dark * 0.4)
        c.roundCaps(true)
        c.seg(x, base, x + 1, base - 10, 2.2, bark)
        c.seg(x + 1, base - 8, x - 8, base - 16, 1.4, bark)
        c.seg(x + 1, base - 9, x + 9, base - 17, 1.4, bark)
        c.roundCaps(false)
        for i in 0..<14 {
            let d = seed + Double(i) * 3.1
            c.circ(x - 15 + hashN(d) * 30, base - 23 + hashN(d + 1) * 9, 3.4 + hashN(d + 2) * 2.6, Col(0x6a7a72, 0.9).shade(1 - dark * 0.45))
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

        var pack = dateText(g.day) + "  " + g.clockText() + "  ·  " + g.areaName(g.area)
        if g.wood > 0 { pack += "  ·  firewood \(g.wood)" }
        if g.jewelry > 0 { pack += "  ·  pendants \(g.jewelry)" }
        if g.rocks > 0 { pack += "  ·  specimens \(g.rocks)" }
        if g.odd > 0 { pack += "  ·  oddities \(g.odd)" }
        if g.rig != .tent && !g.resident && !g.house {
            if g.tanks < 40 { pack += "  ·  tanks \(Int(100 - g.tanks))% full" }
            if g.propane < 40 { pack += "  ·  propane \(Int(g.propane))%" }
        }
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
        // a quick way for testers to write in
        let fy = 74.0
        c.RR(r - 30, fy, 30, 13, 6.5, Col(0x1c1410, 0.68))
        g.text("?", r - 21, fy + 6.5, 5.2, CREAM, bold: true)
        g.text("bug", r - 10, fy + 6.5, 3.4, CREAM.alpha(0.8))
        g.hits.append(Hit(id: 69, x: r - 36, y: fy + 1, w: 40, h: 16))
        // your phone
        do {
            c.RR(r - 30, 58, 30, 13, 6.5, Col(0x1c1410, 0.68))
            c.RR(r - 25.6, 59.6, 5.6, 9.8, 1.2, CREAM); c.R(r - 24.6, 61, 3.6, 6.6, Col(0x3b5bdb))
            g.text(g.page ? g.followersText() : "goals", r - 10, 64.5, g.page ? 4 : 3.4, CREAM, bold: true)
            if g.page && !g.seen.contains(26) { c.circ(r - 2, 59.5, 2, REDC) }
            g.hits.append(Hit(id: 67, x: r - 36, y: 60, w: 40, h: 18))
        }

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
            // places off the sketch sit on its edge, pointing the way
            let x = mx0 + (lon - lonA) / (lonB - lonA) * mw, y = my0 + (latB - lat) / (latB - latA) * mh
            return (clampD(x, mx0 + 6, mx0 + mw - 6), clampD(y, my0 + 6, my0 + mh - 6))
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
            let off: [(Double, Double, Int)] = [(-4, 4, 2), (4, -5, 1), (-4, 4, 2), (0, -6, 0), (0, 6, 0), (0, 6, 0), (0, -6, 0), (-4, 3, 2), (5, 0, 1), (5, 0, 1), (-5, 0, 2), (-5, 0, 2)]
            let o = a < off.count ? off[a] : (0.0, -6.0, 0)
            g.text(d.name, p.0 + o.0, p.1 + o.1, 3.6, ink, align: o.2, bold: true)
        }

        // the list of places: tap one to go
        let lx = mx0 + mw + 10, lw = x1 - 10 - lx
        let how: String = g.inRig ? "In your " + RIGS[g.rig.rawValue].name.lowercased() : (g.onToy ? "On your " + TOYS[g.toy].name.lowercased() : "On foot: Camel Express dial-a-ride")
        g.text(how, lx, y0 + 24, 4.4, ink.alpha(0.75), align: 1, bold: true)
        let perCol = (AREAS.count + 1) / 2
        let rowH = (mh - 6) / Double(perCol)
        let cw = (lw - 4) / 2
        for a in AREAS.indices {
            let to = Area(rawValue: a) ?? .main
            let ry = my0 + 8 + Double(a % perCol) * rowH
            let cx0 = lx + Double(a / perCol) * (cw + 4)
            let t = g.trip(to)
            let here = to == g.area
            c.RR(cx0, ry, cw, rowH - 3, 3, here ? GOLD.alpha(0.35) : (t.ok ? Col(0xffffff, 0.45) : ink.alpha(0.08)))
            g.text(AREAS[a].name, cx0 + 4, ry + rowH * 0.32, 4.4, ink.alpha(t.ok || here ? 1 : 0.5), align: 1, bold: true)
            var sub: String
            if here { sub = "You're here" }
            else if t.ok { let m = milesBetween(g.area, to); sub = (m == m.rounded() ? "\(Int(m))" : "\(m)") + " mi · " + (t.cost == 0 ? "0 coins" : "\(t.cost) coins") }
            else { sub = t.how }
            g.text(sub, cx0 + 4, ry + rowH * 0.68, 3.2, here ? ink.alpha(0.7) : (t.ok ? Col(0x2f6a3a) : REDC.shade(0.8)), align: 1)
            if !here { g.hits.append(Hit(id: 70 + a, x: cx0, y: ry, w: cw, h: rowH - 3)) }
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
    /// Your phone: the page, its followers and what it pays, and today's photo.
    private func phoneOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x000000, 0.5))
        g.hits.append(Hit(id: -1, x: 0, y: 0, w: W, h: H))
        let pw = 132.0, ph = 176.0, x0 = W / 2 - pw / 2, y0 = (H - ph) / 2
        c.RR(x0 - 4, y0 - 4, pw + 8, ph + 8, 14, Col(0x1a1a1e))
        c.RR(x0, y0, pw, ph, 11, Col(0xf2f3f5))
        c.RR(x0 + pw / 2 - 16, y0 + 2, 32, 5, 2.5, Col(0x1a1a1e))
        // header
        c.R(x0, y0 + 9, pw, 30, Col(0x3b5bdb))
        c.circ(x0 + 16, y0 + 24, 9, CREAM)
        c.circ(x0 + 16, y0 + 24, 8, Col(0x8ab4f8))
        let k = max(0, min(3, g.look))
        c.dome(x0 + 16, y0 + 32, 6.4, SHIRTS[k])
        c.circ(x0 + 16, y0 + 22.6, 4, SKINS[k])
        c.dome(x0 + 16, y0 + 20.4, 4.2, Col(0x5a3a22))
        g.text(g.page ? (g.life == .nomad ? "Nomad Life in Quartzsite" : "Snowbird Days in Quartzsite") : "Your phone", x0 + 29, y0 + 19, 4.4, CREAM, align: 1, bold: true)
        g.text(g.page ? "\(g.followersText()) followers  ·  \(g.cred) cred" : "\(g.cred) cred  ·  no page yet", x0 + 29, y0 + 27, 3.6, CREAM.alpha(0.85), align: 1)
        if !g.page {
            g.text("Start one at the Computer Corner", x0 + 29, y0 + 34, 3.2, CREAM.alpha(0.8), align: 1)
        } else if g.followers >= 1000 {
            g.text("Monetized  ·  paid \(g.pagePay) coins this morning", x0 + 29, y0 + 34, 3.2, Col(0xb8f0c0), align: 1, bold: true)
        } else {
            c.RR(x0 + 29, y0 + 32.6, 70, 2.6, 1.3, Col(0xffffff, 0.3))
            c.RR(x0 + 29, y0 + 32.6, 70 * Double(g.followers) / 1000, 2.6, 1.3, GOLD)
            g.text("\(1000 - g.followers) to go", x0 + 102, y0 + 34, 3, CREAM, align: 1)
        }
        if g.phoneTab == 1 {
            // goals: a checklist for a Quartzsite life
            let gl = g.goals()
            let doneN = gl.filter { $0.1 }.count
            g.text("GOALS  ·  \(doneN) of \(gl.count) done", x0 + 8, y0 + 46, 4, Col(0x3b5bdb), align: 1, bold: true)
            for (i, item) in gl.enumerated() {
                let gy = y0 + 54 + Double(i) * 9
                c.RR(x0 + 8, gy - 3, 6, 6, 1.4, item.1 ? Col(0x3fb06a) : Col(0xd8d8dc))
                if item.1 { c.seg(x0 + 9.4, gy, x0 + 10.6, gy + 1.4, 0.7, CREAM); c.seg(x0 + 10.6, gy + 1.4, x0 + 12.8, gy - 1.6, 0.7, CREAM) }
                g.text(item.0, x0 + 18, gy, 3.6, item.1 ? Col(0x8a8a8e) : Col(0x1c1c1e), align: 1, bold: !item.1)
            }
        } else {
        // the weather: today, tonight, tomorrow
        let td = g.temps(g.weather, g.day), tm = g.temps(g.tomorrow, g.day + 1)
        c.RR(x0 + 6, y0 + 42, pw - 12, 12, 3, Col(0xfff4d8))
        weatherIcon(x0 + 13, y0 + 48, g.weather)
        g.text(g.weatherName(g.weather) + " \(td.0)°  ·  tonight \(td.1)°", x0 + 20, y0 + 48, 3.4, Col(0x5a3a1e), align: 1, bold: true)
        weatherIcon(x0 + pw - 40, y0 + 48, g.tomorrow)
        g.text("Tmrw \(tm.0)°", x0 + pw - 33, y0 + 48, 3.2, Col(0x5a3a1e), align: 1)
        if !g.page {
            g.text("No page yet. Start one at the Computer Corner on Main Street to post photos, grow followers and get paid.", x0 + pw / 2, y0 + 90, 3.8, Col(0x5a5a5e), wrap: pw - 20)
        } else {
        // today's photo
        let subj = g.photoSubject()
        let can = !g.seen.contains(26)
        let py = y0 + 57
        c.RR(x0 + 6, py, pw - 12, 18, 4, can ? Col(0x3b5bdb, 0.12) : Col(0x000000, 0.05))
        c.RR(x0 + 9, py + 3, 16, 12, 2, Col(0x8ab4f8))
        c.circ(x0 + 17, py + 9, 3.4, Col(0x2a2a2e)); c.circ(x0 + 17, py + 9, 2, Col(0x5a7ab4))
        g.text(can ? "Post today's photo" : "Posted today's photo", x0 + 30, py + 6.5, 4, can ? Col(0x3b5bdb) : Col(0x6a6a6e), align: 1, bold: true)
        g.text(can ? "a photo " + subj.0 + "  ·  about +\(subj.1 * (g.upgrades.contains(UP_STARLINK) ? 2 : 1) + g.cred / 4)" : "Come back tomorrow", x0 + 30, py + 13, 3, Col(0x6a6a6e), align: 1)
        if can { g.hits.append(Hit(id: 68, x: x0 + 6, y: py, w: pw - 12, h: 18)) }
        // the feed
        var fy = y0 + 80
        if g.posts.isEmpty { g.text("No posts yet. Landmarks, events and finds make good ones.", x0 + pw / 2, fy + 10, 3.4, Col(0x6a6a6e), wrap: pw - 16) }
        for p in g.posts.prefix(3) {
            c.RR(x0 + 6, fy, pw - 12, 24, 4, Col(0xffffff))
            c.circ(x0 + 13, fy + 7, 3.4, Col(0xe8c9a0))
            g.text(dateText(p.day), x0 + 20, fy + 6, 3, Col(0x8a8a8e), align: 1)
            g.text(p.text.prefix(1).uppercased() + p.text.dropFirst(), x0 + 20, fy + 12.5, 3.8, Col(0x1c1c1e), align: 1, bold: true)
            g.text("♥ \(p.likes)   ·   \(p.comments) comments", x0 + 20, fy + 19, 3.2, Col(0xd9412e), align: 1)
            fy += 27
        }
        }
        }
        // tabs
        let tabs = ["Page", "Goals"]
        for (t, name) in tabs.enumerated() {
            let tx = x0 + 10 + Double(t) * (pw - 20) / 2, tw = (pw - 20) / 2 - 4
            c.RR(tx, y0 + ph - 13, tw, 10, 5, g.phoneTab == t ? Col(0x3b5bdb) : Col(0xd8d8dc))
            g.text(name, tx + tw / 2, y0 + ph - 8, 3.8, g.phoneTab == t ? CREAM : Col(0x3a3a3e), bold: true)
            g.hits.append(Hit(id: 72 + t, x: tx, y: y0 + ph - 16, w: tw, h: 15))
        }
        g.text("tap outside to close", W / 2, y0 + ph + 1.6, 3.2, CREAM.alpha(0.7))
    }

    /// Inside a converted school bus: wood ceiling, a wood stove, a bed under the back windows, plants, string lights.
    private func tourOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.65))
        g.hits.append(Hit(id: -1, x: 0, y: 0, w: W, h: H))
        let w = min(320.0, W - g.safeL - g.safeR - 20), h = 160.0
        let x0 = (W - w) / 2, y0 = (H - h) / 2
        let wood = [Col(0xc89a62), Col(0x9a6a44), Col(0xd8b484)][g.tourBus]
        let paint = [Col(0x5a8a7a), Col(0xd9c9a8), Col(0x3a5a8a)][g.tourBus]
        c.RR(x0, y0, w, h, 10, paint)
        // arched ceiling of tongue-and-groove
        c.RR(x0, y0, w, 30, 10, wood)
        for k in 0..<Int(w / 6) { c.R(x0 + Double(k) * 6, y0 + 4, 0.6, 26, wood.shade(0.82)) }
        // the bus windows down both sides, desert outside
        for k in 0..<7 {
            let wx = x0 + 14 + Double(k) * (w - 28) / 7
            c.RR(wx, y0 + 34, (w - 28) / 7 - 6, 26, 2, Col(0x2a2a2e))
            c.vfill(wx + 1.4, y0 + 35.4, (w - 28) / 7 - 8.8, 23, [(0, Col(0x8ac0e8)), (0.7, Col(0xe8c89a)), (1, Col(0xc89a6a))])
            c.R(wx + 1.4, y0 + 46, (w - 28) / 7 - 8.8, 0.8, Col(0x2a2a2e))
        }
        // string lights along the ceiling
        for k in 0..<22 {
            let t = Double(k) / 21
            let lx = x0 + 10 + t * (w - 20), ly = y0 + 30 + sin(t * PI * 3) * 2 + 2
            c.circ(lx, ly, 1, [Col(0xffd68a), Col(0xff8a6a), Col(0x8ad0ff)][k % 3])
        }
        // floor
        c.R(x0, y0 + h - 26, w, 26, wood.shade(0.75))
        for k in 0..<Int(w / 16) { c.R(x0 + Double(k) * 16, y0 + h - 26, 0.6, 26, wood.shade(0.6)) }
        // the bed at the back
        c.RR(x0 + 10, y0 + h - 52, 80, 26, 3, wood.shade(0.9))
        c.RR(x0 + 12, y0 + h - 58, 76, 10, 3, Col(0xe8dcc4))
        let quilt = [Col(0xd9412e), Col(0xf2c14e), Col(0x3a6ea5), Col(0x3f8f6a)]
        for k in 0..<8 { c.R(x0 + 14 + Double(k) * 9, y0 + h - 50, 9, 8, quilt[(k + g.tourBus) % 4]) }
        // the wood stove, pipe and glow
        let sx = x0 + w * 0.48
        c.RR(sx - 10, y0 + h - 46, 20, 20, 2, Col(0x2a2a2e))
        c.RR(sx - 6, y0 + h - 40, 12, 9, 1, Col(0xff8a2e, 0.6 + 0.3 * sin(NOW * 7)))
        c.R(sx - 2, y0 + 30, 4, h - 76, Col(0x3a3a3e))
        c.glow(sx, y0 + h - 36, 30, Col(0xffa040, 0.25), Col(0xffa040, 0))
        // kitchen counter with plants and a kettle
        c.R(x0 + w - 110, y0 + h - 46, 100, 20, wood.shade(0.85))
        c.R(x0 + w - 110, y0 + h - 48, 100, 2.4, wood.shade(1.1))
        for k in 0..<3 {
            let px = x0 + w - 100 + Double(k) * 26
            c.RR(px, y0 + h - 54, 8, 6, 1, Col(0xc85a3a))
            for l in 0..<4 { c.ell(px + 4 + Double(l - 2) * 2, y0 + h - 57 - Double(l % 2) * 2, 1.6, 3, Col(0x4f9a5a)) }
        }
        c.RR(x0 + w - 32, y0 + h - 55, 10, 7, 3, Col(0x3a6ea5))
        // a sleeping dog on the rug
        c.ell(x0 + w * 0.65, y0 + h - 18, 22, 4, Col(0xb5452f, 0.7))
        c.ell(x0 + w * 0.65, y0 + h - 21, 9, 4, Col(0x8a6a44))
        c.circ(x0 + w * 0.65 + 8, y0 + h - 22, 3.2, Col(0x8a6a44))
        let owners = ["The Okafors' 1998 Thomas, converted in their driveway over two summers", "Dusty's 2004 Blue Bird: 40 feet, a wood stove and 1,200 watts of solar", "Tess's short bus: three dogs, one bed, zero regrets"]
        c.RR(x0 + 10, y0 + 6, w - 20, 16, 4, Col(0x1c1410, 0.75))
        g.text(owners[g.tourBus], W / 2, y0 + 14, 4.4, CREAM, bold: true)
        g.text("tap anywhere to step back outside", W / 2, y0 + h + 6, 3.4, CREAM.alpha(0.7))
    }

    /// Inside the Gold Eye, side on: daylight at the portal, a timbered drift running into the hill,
    /// rails underfoot, a quartz vein in the wall, and only your lantern to see by.
    private func mineOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x050403, 0.8))
        g.hits.append(Hit(id: -1, x: 0, y: 0, w: W, h: H))
        let w = min(330.0, W - g.safeL - g.safeR - 20), h = 160.0
        let x0 = (W - w) / 2, y0 = (H - h) / 2
        let roof = y0 + 60, floor = y0 + 114
        c.save()
        c.RR(x0, y0, w, h, 10, Col(0x3a2e26))
        // the hill in cross-section: layered rock above and below the drift
        let strata = [Col(0x5a4636), Col(0x4e3c2e), Col(0x645040), Col(0x4a3a2c)]
        for k in 0..<5 {
            let yy = y0 + 24 + Double(k) * 8
            c.poly(strata[k % 4], [x0, yy, x0 + w, yy + 4 + sin(Double(k)) * 3, x0 + w, yy + 13, x0, yy + 9])
        }
        for k in 0..<4 { c.R(x0, floor + Double(k) * 12, w, 12, strata[(k + 1) % 4].shade(0.9)) }
        for k in 0..<40 { let d = Double(k) + 500; c.ell(x0 + hashN(d) * w, y0 + hashN(d + 1) * h, 1.6 + hashN(d + 2) * 3, 1 + hashN(d + 3) * 1.6, Col(0x2a2018, 0.5)) }
        // sky and the desert surface on top, the portal on the left with daylight pouring in
        c.vfill(x0, y0, w, 22, [(0, Col(0x7ab4e0)), (1, Col(0xd8e8f0))])
        c.R(x0, y0 + 21, w, 4, Col(0xc8a070))
        saguaro(x0 + 24, y0 + 22, 15, 3, SAG, false)
        saguaro(x0 + w - 40, y0 + 22, 11, 7, SAG, false)
        c.vfill(x0, roof, 30, floor - roof, [(0, Col(0xf2d8a8)), (1, Col(0xd8b07a))])
        c.glow(x0 + 18, (roof + floor) / 2, 60, Col(0xffe8b0, 0.35), Col(0xffe8b0, 0))
        // the drift itself, dark and getting darker
        c.R(x0 + 30, roof, w - 30, floor - roof, Col(0x1c1410))
        c.vfill(x0 + w * 0.6, roof, w * 0.4, floor - roof, [(0, Col(0x000000, 0)), (1, Col(0x000000, 0.0))])
        c.R(x0 + w * 0.72, roof, w * 0.28, floor - roof, Col(0x000000, 0.45))
        // rails and ties
        for k in 0..<Int((w - 30) / 7) { c.R(x0 + 32 + Double(k) * 7, floor - 2.4, 4, 2.4, Col(0x4a3420)) }
        c.R(x0 + 30, floor - 3.4, w - 30, 0.9, Col(0x7a7a7e))
        // timber sets every few yards: two posts and a cap
        var tx = x0 + 44
        while tx < x0 + w - 6 {
            let tw = Col(0x8a6238).shade(max(0.35, 1 - (tx - x0) / w * 0.8))
            c.R(tx, roof, 3.4, floor - roof - 3, tw)
            c.R(tx - 3, roof, 9.4, 3.4, tw.shade(1.1))
            tx += 46
        }
        // the quartz vein the miners followed, cutting down through the rock into the drift's back wall
        let vein: [Double] = [x0 + w * 0.40, y0 + 30, x0 + w * 0.44, y0 + 40, x0 + w * 0.42, y0 + 50, x0 + w * 0.47, roof, x0 + w * 0.45, roof + 16]
        for k in stride(from: 0, to: vein.count - 2, by: 2) {
            c.seg(vein[k], vein[k + 1], vein[k + 2], vein[k + 3], k < 6 ? 2.6 : 1.4, Col(0xe8e4dc, k < 6 ? 0.9 : 0.35))
        }
        for k in 0..<4 { let t = sin(NOW * 3 + Double(k) * 1.7); if t > 0.6 { c.circ(x0 + w * 0.41 + Double(k) * 1.6, y0 + 34 + Double(k) * 6, 0.9, Col(0xffffff)) } }
        // you, with a lantern (and the detector, if you found gold with it)
        let px = x0 + w * 0.36
        c.glow(px + 6, floor - 22, 70, Col(0xffb050, 0.28 + 0.03 * sin(NOW * 9)), Col(0xffb050, 0))
        person(px, floor - 2, g.look, 1, 0, false)
        c.seg(px + 3, floor - 14, px + 7, floor - 17, 0.8, Col(0x6a5a4a))
        c.RR(px + 5.6, floor - 17, 3.4, 5, 1, Col(0xffd080))
        switch g.mineFind {
        case 0:
            c.poly(Col(0x6a5848), [px + 18, floor - 2, px + 21, floor - 8, px + 28, floor - 9, px + 31, floor - 2])
            gem(px + 24, floor - 6, 3, Col(0xf0f0f4))
        case 1:
            c.R(x0 + w * 0.52, roof + 26, 18, 2, Col(0x6a4a2a))
            c.RR(x0 + w * 0.52 + 6, roof + 18, 6, 8, 1.4, Col(0x8a6a3a)); c.circ(x0 + w * 0.52 + 9, roof + 22, 1.6, Col(0xffd080, 0.7))
        case 2:
            c.seg(px - 2, floor - 12, px - 12, floor - 3, 0.8, Col(0x3a3a3e))
            c.ell(px - 14, floor - 2.4, 5, 1.4, Col(0x2a2a2e))
            let beep = sin(NOW * 14) > 0
            if beep { g.text("beep", px - 14, floor - 12, 3.2, GOLD, bold: true) }
            c.circ(px - 20, floor - 1.6, 1.4, GOLD)
        default:
            for k in 0..<5 {
                let bx = x0 + w * (0.55 + Double(k) * 0.07), by = roof + 4
                let sw = sin(NOW * 2 + Double(k)) * 0.6
                c.ell(bx + sw, by + 3, 1.4, 2.6, Col(0x14100c))
                c.poly(Col(0x14100c), [bx - 2.4 + sw, by + 1, bx + sw, by + 4, bx + 2.4 + sw, by + 1])
            }
        }
        c.restore()
        c.RR(x0 + 10, y0 + h - 24, w - 20, 18, 4, Col(0x000000, 0.65))
        g.text(g.mineText, W / 2, y0 + h - 15, 4.4, CREAM, bold: true, wrap: w - 30)
        g.text("THE GOLD EYE", x0 + w / 2, y0 + 11, 5.4, Col(0x3a2414), bold: true)
        g.text("tap anywhere to walk back out", W / 2, y0 + h + 6, 3.4, CREAM.alpha(0.7))
    }

    /// The community board up close: cork, pushpins, flyers with tear-off tabs.
    private func boardOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.6))
        g.hits.append(Hit(id: -1, x: 0, y: 0, w: W, h: H))
        let w = min(330.0, W - g.safeL - g.safeR - 20), h = 164.0
        let x0 = (W - w) / 2, y0 = (H - h) / 2
        c.RR(x0 - 5, y0 - 5, w + 10, h + 10, 4, Col(0x6a4a2e))
        c.R(x0, y0, w, h, Col(0xb88a58))
        for k in 0..<220 { let d = Double(k) + 300; c.circ(x0 + hashN(d) * w, y0 + hashN(d + 1) * h, 0.5, Col(0x8a6238, 0.6)) }
        let job = JOBS[g.day % JOBS.count]
        let ev = g.nextEvent()
        let sale = ["SOLAR PANEL 100W, barely used", "Quiet 2200W generator, runs great", "Bike rack, fits two bikes", "Kayak, 10 ft, with paddle", "Cast iron dutch oven"][g.day % 5]
        var notes: [(String, String, Col)] = []
        notes.append((g.seen.contains(23) ? "HELP WANTED (taken)" : "HELP WANTED", job.0 + ". Pays \(job.1). Today only.", Col(0xfff2a8)))
        notes.append(("COMING UP", ev.map { $0.name + ", " + $0.when } ?? "Season's winding down. See you next winter!", Col(0xf4f1ea)))
        notes.append(("LOST DOG", "Little brown dog, answers to Biscuit. Last seen at La Posa South. Reward!", Col(0xffd0c8)))
        notes.append(("FOR SALE", sale + ". Ask at the board.", Col(0xd8f0ff)))
        notes.append(("SUNDAY POTLUCK", "Town Park, noon. Bring a dish and your own chair.", Col(0xd8f8d0)))
        if g.business > 0 {
            notes.append(("YOUR AD", BIZ[g.business - 1].name + (g.adDays > 0 ? ". Up \(g.adDays) more days." : ". Ad's down. Post a new one."), Col(0xffe0a8)))
        } else {
            notes.append(("QUARTZSITE CAMPFIRE", "Guide, map and classifieds for the season. qcampfire.com", Col(0xf8e8ff)))
        }
        let nw = (w - 28) / 3, nh = (h - 26) / 2
        for (k, n) in notes.enumerated() {
            let tilt = (hashN(Double(k) + Double(g.day) * 0.1) - 0.5) * 6
            let nx = x0 + 8 + Double(k % 3) * (nw + 6) + tilt, ny = y0 + 8 + Double(k / 3) * (nh + 10)
            c.R(nx + 1.4, ny + 1.6, nw, nh, Col(0x000000, 0.18))
            c.R(nx, ny, nw, nh, n.2)
            c.circ(nx + nw / 2, ny + 3, 2, [Col(0xd9412e), Col(0x3a6ea5), Col(0xf2c14e), Col(0x3f8f6a)][k % 4])
            g.text(n.0, nx + nw / 2, ny + 12, 5.2, Col(0x2a1e14), bold: true)
            g.text(n.1, nx + nw / 2, ny + 30, 4.6, Col(0x3a2c1e), wrap: nw - 10)
            if k == 3 || k == 2 {
                for t in 0..<6 { c.R(nx + 3 + Double(t) * (nw - 6) / 6, ny + nh - 9, (nw - 6) / 6 - 1.2, 9, n.2.shade(0.94)) }
            }
        }
        g.text("tap anywhere to step back", W / 2, y0 + h + 9, 3.4, CREAM.alpha(0.7))
    }

    /// A tiny weather glyph for the phone.
    private func weatherIcon(_ x: Double, _ y: Double, _ w: Int) {
        switch w {
        case 0:
            c.circ(x, y, 2.6, Col(0xf2b02e))
            for k in 0..<8 { let a = Double(k) * PI / 4; c.seg(x + cos(a) * 3.4, y + sin(a) * 3.4, x + cos(a) * 4.4, y + sin(a) * 4.4, 0.5, Col(0xf2b02e)) }
        case 1:
            for k in 0..<3 { c.seg(x - 4, y - 2 + Double(k) * 2, x + 3 - Double(k), y - 2 + Double(k) * 2, 0.7, Col(0x8a8a8e)) }
        case 2:
            c.circ(x - 1.4, y, 2.2, Col(0xa8acb4)); c.circ(x + 1.6, y - 0.6, 2.6, Col(0xa8acb4)); c.R(x - 3.6, y, 7.6, 2.2, Col(0xa8acb4))
        default:
            c.circ(x - 1.4, y - 1, 2.2, Col(0x8a8e98)); c.circ(x + 1.6, y - 1.6, 2.6, Col(0x8a8e98)); c.R(x - 3.6, y - 1, 7.6, 2, Col(0x8a8e98))
            for k in 0..<3 { c.seg(x - 2 + Double(k) * 2, y + 1.6, x - 3 + Double(k) * 2, y + 3.6, 0.5, Col(0x3a6ea5)) }
        }
    }

    private func browseOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.55))
        let x0 = g.safeL + 14, x1 = W - g.safeR - 14, y0 = 8.0, y1 = H - 8
        let ink = Col(0x2a1e14)
        c.RR(x0, y0, x1 - x0, y1 - y0, 6, Col(0x3a2c3a))
        g.hits.append(Hit(id: 88, x: x0, y: y0, w: x1 - x0, h: y1 - y0))
        g.text(g.shop == 1 ? "GEM WORLD" : "ON THE TABLES", x0 + 10, y0 + 10, 8, GOLD, align: 1, bold: true)
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
            if w.name.hasPrefix("Flat") {
                // a shallow tray full of small stones
                c.RR(cx + 3, cy + ch * 0.5 - 4, 26, 13, 1.5, Col(0x8a6238).shade(w.sold ? 0.5 : 1))
                c.R(cx + 4.5, cy + ch * 0.5 - 2.5, 23, 10, Col(0xb8925e).shade(w.sold ? 0.5 : 1))
                for q in 0..<12 { gem(cx + 7 + Double(q % 4) * 5.6, cy + ch * 0.5 + 0.5 + Double(q / 4) * 3.2, 1.6, stones[(q * 3 + k) % stones.count].shade(w.sold ? 0.5 : 1)) }
            } else {
                gem(cx + 16, cy + ch * 0.5 + 6, 7, stones[n].shade(w.sold ? 0.5 : 1))
            }
            g.text(w.name, cx + 32, cy + 9, 5, w.sold ? CREAM.alpha(0.5) : ink, align: 1, bold: true, wrap: cw - 36)
            g.text(w.who, cx + 32, cy + 20, 3.6, w.sold ? CREAM.alpha(0.4) : ink.alpha(0.7), align: 1, wrap: cw - 36)
            if w.sold {
                g.text("Yours", cx + 32, cy + ch - 8, 5, GOLD, align: 1, bold: true)
            } else {
                coin(cx + 35, cy + ch - 12, 3.2)
                g.text("\(w.price)", cx + 41, cy + ch - 12, 6.4, Double(w.price) > g.money ? REDC : Col(0x2f6a3a), align: 1, bold: true)
                g.text("sells for about \(w.lo)–\(w.hi) coins", cx + 32, cy + ch - 5, 3.4, ink.alpha(0.65), align: 1)
                g.hits.append(Hit(id: 90 + k, x: cx, y: cy, w: cw, h: ch))
                if !w.haggled {
                    c.RR(cx + cw - 30, cy + 3, 27, 9, 4.5, Col(0x2a1e14, 0.85))
                    g.text("Haggle", cx + cw - 16.5, cy + 7.5, 3.8, GOLD, bold: true)
                    g.hits.append(Hit(id: 100 + k, x: cx + cw - 34, y: cy, w: 34, h: 15))
                } else {
                    g.text("haggled", cx + cw - 16.5, cy + 7.5, 3.4, ink.alpha(0.45))
                }
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
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.6))
        let w = min(300.0, W - g.safeL - g.safeR - 30), h = 166.0
        let x0 = (W - w) / 2, y0 = (H - h) / 2
        let ink = Col(0x3a2c1e)
        c.RR(x0, y0, w, h, 8, Col(0xeadfc4))
        // a sunset strip across the top of the card
        c.vfill(x0, y0, w, 30, [(0, Col(0xf29a6a)), (1, Col(0xf2c88a))])
        c.circ(x0 + w * 0.78, y0 + 30, 9, Col(0xfff0c0))
        c.R(x0, y0 + 26, w, 4, Col(0x8a5a4a))
        saguaro(x0 + 24, y0 + 30, 20, 3, SAGD, false); saguaro(x0 + w - 22, y0 + 30, 14, 6, SAGD, false)
        g.text("SEASON \(g.year) IS OVER", W / 2, y0 + 15, 9, Col(0x3a1e14), bold: true)
        let st = g.stats
        let coins = Int(g.money) - st[0]
        let sign: String = coins >= 0 ? "+" : ""
        let coinNote: String = "coins (" + sign + String(coins) + ")"
        let fol: String = "+" + String(g.followers - st[1])
        let credUp: String = "+" + String(g.cred - st[2])
        var tiles: [(String, String)] = []
        tiles.append((String(Int(g.money)), coinNote))
        tiles.append((fol, g.page ? "followers" : "no page yet"))
        tiles.append((credUp, "cred, now " + String(g.cred)))
        tiles.append((String(st[3]), "miles driven"))
        tiles.append((String(st[4]) + " · " + String(st[5]), "sold · found"))
        tiles.append((String(st[6]) + " · " + String(st[7]), "events · parties"))
        let tw = (w - 24 - 16) / 3
        for (k, t) in tiles.enumerated() {
            let tx = x0 + 12 + Double(k % 3) * (tw + 8), ty = y0 + 36 + Double(k / 3) * 30
            c.RR(tx, ty, tw, 26, 4, Col(0xffffff, 0.55))
            g.text(t.0, tx + tw / 2, ty + 10, 7, Col(0x2f6a3a), bold: true)
            g.text(t.1, tx + tw / 2, ty + 20, 3.6, ink.alpha(0.75))
        }
        let body = "The snowbirds are pulling out and it's getting hot. You're \(g.age). " + (canStay ? "You have a place for the summer and your businesses keep paying." : "With no year-round site or house, it's time to head north until fall.")
        g.text(body, W / 2, y0 + 108, 4.4, ink.alpha(0.85), wrap: w - 30)
        let bw = (w - 40) / 2
        button(80, "Head north", x0 + 15, y0 + h - 28, bw, true)
        button(81, "Stay the summer", x0 + 25 + bw, y0 + h - 28, bw, canStay)
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
    /// Townsfolk wandering a stretch of the world: some strolling, some stopped to talk.
    private func crowd(_ x0: Double, _ x1: Double, _ n: Int, _ seed: Double) {
        var folks: [(x: Double, b: Double, look: Int, face: Double, ph: Double, mv: Bool)] = []
        for i in 0..<n {
            let d = seed * 31 + Double(i) * 7.3
            let home = x0 + hashN(d) * (x1 - x0)
            let still = hashN(d + 1) < 0.4
            let amp = still ? 0 : 20 + hashN(d + 2) * 70
            let t = NOW * (0.08 + hashN(d + 3) * 0.12) + hashN(d + 4) * 6.28
            let sx = home + sin(t) * amp - cam
            if sx < -20 || sx > W + 20 { continue }
            let face = still ? (hashN(d + 5) < 0.5 ? 1.0 : -1.0) : (cos(t) >= 0 ? 1.0 : -1.0)
            folks.append((sx, GY + 2 + hashN(d + 6) * 7, 4 + Int(hashN(d + 7) * 997), face, NOW * 7 + d, !still && abs(cos(t)) > 0.15))
        }
        folks.sort { $0.b < $1.b }
        for f in folks { person(f.x, f.b, f.look, f.face, f.ph, f.mv) }
    }

    /// A feather flag: the tall curved banners you see along every Quartzsite show aisle.
    private func featherFlag(_ x: Double, _ base: Double, _ k: Int, _ seed: Double) {
        if x < -20 || x > W + 20 { return }
        let cols = [Col(0xe0408a), Col(0x2f7ad0), Col(0xf28a1e), Col(0xf2c418), Col(0x3fb06a)]
        let col = cols[((k % 5) + 5) % 5].shade(1 - dark * 0.45)
        let sw = sin(NOW * 2.4 + seed) * 1.2
        c.seg(x, base, x + sw * 0.4, base - 30, 0.6, Col(0x6a6a6a))
        c.poly(col, [x, base - 8, x + sw * 0.4, base - 30, x + 4 + sw, base - 28.4, x + 5.6 + sw * 0.8, base - 22, x + 5 + sw * 0.5, base - 12, x + 2, base - 8])
        c.poly(col.shade(1.18), [x + 1, base - 26, x + 3.4 + sw, base - 26.4, x + 4.2 + sw * 0.8, base - 22, x + 1, base - 20])
    }

    /// The RV show: shiny new rigs lined up with flags and show-price placards.
    private func rvShowLot() {
        let rows: [(Double, RigKind, Int)] = [(2215, .classB, 0), (2585, .classA, 1), (2900, .classC, 2)]
        for (k, r) in rows.enumerated() {
            let x = r.0 - cam
            if x < -90 || x > W + 90 { continue }
            c.ell(x, GY + 1, 46, 3, Col(0x000000, 0.12))
            rig(r.1, x, GY, 2, k % 2 == 0 ? 1 : -1, 0.9)
            // pennant string over the lot
            for j in 0..<9 {
                let fx = x - 44 + Double(j) * 11
                c.poly([Col(0xd9412e), Col(0xf2c14e), Col(0x3a6ea5)][j % 3], [fx, GY - 52, fx + 8, GY - 52, fx + 4, GY - 46 + sin(NOW * 3 + Double(j)) * 0.6])
            }
            c.seg(x - 46, GY - 52, x + 54, GY - 52, 0.4, Col(0x6a6a6a))
            c.R(x + 30, GY - 14, 1, 14, Col(0x8a8a88))
            c.RR(x + 20, GY - 24, 22, 11, 1, Col(0xf4f1ea))
            g.text("SHOW", x + 31, GY - 20.8, 2.8, REDC, bold: true)
            g.text("PRICE", x + 31, GY - 16.6, 2.8, REDC, bold: true)
        }
    }

    /// Show food: kettle corn, a taco truck, a barbecue smoker.
    private func foodTruck(_ wx: Double, _ kind: Int) {
        let x = wx - cam
        if x < -60 || x > W + 60 { return }
        switch kind {
        case 0:
            canopy(x, 20, Col(0xd9412e), Col(0xf4f1ea))
            c.R(x - 14, GY - 9, 28, 9, Col(0xf4f1ea).shade(1 - dark * 0.4))
            c.ell(x, GY - 12, 6, 4, Col(0x2a2a2e)); c.R(x - 1, GY - 9, 2, 9, Col(0x3a3a3e))
            for k in 0..<3 {
                let t = (NOW * 0.8 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                c.circ(x + sin(t * 6) * 2, GY - 16 - t * 16, 1.6 + t * 3, Col(0xffffff, (1 - t) * 0.4))
            }
            c.RR(x - 14, GY - 30, 28, 6, 1, Col(0xf2c14e))
            g.text("KETTLE CORN", x, GY - 27, 2.8, Col(0x7a2f1e), bold: true)
        case 1:
            let body = Col(0xf4f1ea).shade(1 - dark * 0.4)
            c.RR(x - 24, GY - 24, 48, 20, 3, body)
            c.R(x - 24, GY - 10, 48, 3, Col(0x3f8f6a))
            c.R(x - 14, GY - 20, 24, 8, Col(0x2a2a2e))
            c.poly(Col(0x3f8f6a), [x - 16, GY - 21, x + 12, GY - 21, x + 15, GY - 25, x - 19, GY - 25])
            c.circ(x - 14, GY - 2, 3, TIRE); c.circ(x + 14, GY - 2, 3, TIRE)
            c.RR(x - 12, GY - 33, 24, 7, 1, Col(0x3f8f6a))
            g.text("TACOS", x, GY - 29.5, 3.4, CREAM, bold: true)
            person(x + 2, GY - 11, 801, -1, 0, false)
        default:
            let iron = Col(0x2a2a2e)
            c.RR(x - 16, GY - 13, 26, 9, 4.5, iron)
            c.R(x + 6, GY - 26, 3, 14, iron)
            c.R(x - 14, GY - 4, 1.2, 4, iron); c.R(x + 6, GY - 4, 1.2, 4, iron)
            c.circ(x + 14, GY - 3, 3, TIRE)
            for k in 0..<5 {
                let t = (NOW * 0.5 + Double(k) / 5).truncatingRemainder(dividingBy: 1)
                c.circ(x + 7.5 + t * 10, GY - 28 - t * 24, 2 + t * 6, Col(0xc8c8c4, (1 - t) * 0.5))
            }
            c.RR(x - 30, GY - 30, 22, 7, 1, Col(0x7a2f1e))
            g.text("BBQ", x - 19, GY - 26.5, 3.4, CREAM, bold: true)
            person(x - 22, GY + 3, 802, 1, 0, false)
        }
    }

    /// A brown BLM sign at the way in.
    private func blmSign(_ wx: Double, _ name: String, _ sub: String) {
        let x = wx - cam
        if x < -40 || x > W + 40 { return }
        let post = Col(0x5a4030).shade(1 - dark * 0.4)
        c.R(x - 14, GY - 22, 2, 22, post); c.R(x + 12, GY - 22, 2, 22, post)
        c.RR(x - 20, GY - 34, 40, 14, 1.5, Col(0x6a4a2e).shade(1 - dark * 0.4))
        c.RR(x - 19, GY - 33, 38, 12, 1, Col(0x5a3a22).shade(1 - dark * 0.4))
        g.text(name, x, GY - 29, 3.4, Col(0xf2e8c8), bold: true)
        g.text(sub, x, GY - 24.5, 2.4, Col(0xf2e8c8, 0.85))
    }

    /// The people who turn up for whatever is on, sized to the event.
    private func eventCrowds(_ ar: Area) {
        let w = g.WORLD
        let day = g.dayT < 0.64
        func at(_ k: SpotKind) -> Double? { return g.spots.first(where: { $0.kind == k })?.x }
        switch ar {
        case .tyson:
            if g.on(EV_RV) { rvShowLot() }
            if day && (g.tysonShow() != nil || g.on(EV_RV)) {
                foodTruck(860, 0); foodTruck(1730, 1); foodTruck(2240, 2)
                crowd(160, w - 160, 110, 11)
            }
            else if day && g.on(EV_PAN), let x = at(.panorama) { crowd(x - 140, x + 140, 12, 12) }
        case .main:
            if day { crowd(0, w, 40, 16) }
            if day && g.on(EV_RTR), let x = at(.park) { crowd(x - 280, x + 280, 34, 13) }
            if day && g.on(EV_WESTERN), let x = at(.park) { crowd(x - 240, x + 240, 30, 14) }
            if day && g.on(EV_PARADE) { crowd(0, w, 160, 15) }
        case .skoolie:
            if g.on(EV_SKOOL) { crowd(140, w - 140, day ? 90 : 40, 17) }
        case .roadrunner:
            if g.on(EV_QFEST), let x = at(.radio) { crowd(x - 300, x + 300, day ? 26 : 12, 18) }
        default: break
        }
        // the party breaks up at 10 PM for quiet hours
        if ar == .dome { blmSign(90, "DOME ROCK", "BLM · 14-DAY LIMIT") }
        if ar == .roadrunner { blmSign(70, "ROAD RUNNER", "BLM · 14-DAY LIMIT") }
        if g.partyDay == g.day && g.partyArea == ar && g.dayT > 0.5 && g.hour() >= 12 && g.hour() < 22 { party() }
    }

    /// Your party: neighbors walk over with chairs and coolers, a couple of rigs pull in, lights go up.
    private func party() {
        let fx = g.partyX + 4 - cam
        let et = NOW - g.partyT
        if fx < -260 || fx > W + 260 { return }
        // rigs that pulled in, and string lights from a pole
        if et > 4 {
            rig(.van, fx + 150, GY - 1, 1, -1, 0.9)
            toy(4, fx + 205, GY, -1, -1, 0)
            rig(.skoolie, fx + 290, GY - 1, 2, -1, 0.9)
        }
        c.R(fx + 92, GY - 26, 1, 26, Col(0x7a6a5a).shade(1 - dark * 0.4))
        let bulbs = [Col(0xffd68a), Col(0xff8a6a), Col(0x8ad0ff), Col(0xb8ff8a)]
        for i in 0..<16 {
            let t = Double(i) / 15
            let lx = fx - 40 + 132 * t, ly = GY - 25 + sin(PI * t) * 5
            c.circ(lx, ly, 1, bulbs[i % 4].alpha(dark > 0.3 ? 1 : 0.6))
            if dark > 0.3 && i % 3 == 0 { lights.append((lx, ly, 12)) }
        }
        // cooler and a folding table
        c.RR(fx + 30, GY - 4, 9, 5, 1, Col(0x3a6ea5)); c.R(fx + 30, GY - 4.6, 9, 1, Col(0xf4f1ea))
        c.R(fx + 46, GY - 7, 18, 1.2, Col(0xe8e0d0)); c.R(fx + 47, GY - 6, 0.8, 6, Col(0x8a8a88)); c.R(fx + 62, GY - 6, 0.8, 6, Col(0x8a8a88))
        c.circ(fx + 50, GY - 8, 1.4, Col(0xd9412e)); c.R(fx + 55, GY - 9.6, 2, 2.6, Col(0xf2c14e)); c.circ(fx + 60, GY - 8, 1.2, Col(0x4f9a5a))
        // the guests: chairs on the fire's left, people standing and talking on the right
        let seats: [(Double, Bool)] = [(-46, true), (-34, true), (-22, true), (-58, true), (16, false), (24, false), (68, false), (76, false), (84, false), (104, false), (112, false), (-70, false), (122, false), (40, true)]
        for (i, s) in seats.enumerated() {
            let arrive = Double(i) * 0.45
            let f = clampD((et - arrive) / 3, 0, 1)
            if f <= 0 { continue }
            let from = (i % 2 == 0 ? -1.0 : 1.0) * (W * 0.6 + 40)
            let tx = fx + s.0
            let gx = f < 1 ? tx + (1 - f) * from : tx
            let look = 300 + i * 37
            if f < 1 {
                person(gx, GY + 3, look, from < 0 ? 1 : -1, NOW * 8 + Double(i), true)
            } else if s.1 {
                let chair = [Col(0x2f6a8a), Col(0xb5452f), Col(0x3f8f6a), Col(0x7a4a8a)][i % 4].shade(1 - dark * 0.4)
                c.seg(tx - 2, GY + 2, tx + 4, GY - 3, 0.5, Col(0x5a5a5a)); c.seg(tx + 4, GY + 2, tx - 2, GY - 3, 0.5, Col(0x5a5a5a))
                c.R(tx - 3, GY - 4, 8, 1.4, chair); c.R(tx - 3.4, GY - 11, 1.4, 7.4, chair)
                seated(tx, GY - 4, look, sin(NOW * 1.5 + Double(i)) * 0.3)
            } else {
                person(tx, GY + 3, look, s.0 < 30 ? -1 : (i % 2 == 0 ? 1 : -1), 0, false)
            }
        }
        // music in the air
        if et > 3 {
            for k in 0..<3 {
                let t = (NOW * 0.5 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                g.text("♪", fx + 10 + sin(t * 6 + Double(k)) * 8, GY - 34 - t * 26, 5, CREAM.alpha(1 - t))
            }
        }
    }

    /// Dust behind a fast ride, your generator chugging, and a neighbor who has had enough.
    private func manners() {
        // now and then someone else tears past on a side-by-side, dust and all
        if [Area.ltva, .dome, .scaddan, .roadrunner].contains(g.area) && g.dayT < 0.62 {
            let t = (NOW + 11).truncatingRemainder(dividingBy: 30)
            if t < 6 {
                let sx = -90 + t * (W + 180) / 6
                for i in 0..<12 {
                    let u = (NOW * 1.6 + Double(i) / 12).truncatingRemainder(dividingBy: 1)
                    c.circ(sx - 20 - u * 90, GY + 10 - u * 18, 3 + u * 13, Col(0xd8bc90, (1 - u) * 0.45).shade(1 - dark * 0.5))
                }
                toy(5, sx, GY + 13, 1, 333, NOW * 25)
            }
        }
        if g.onToy && g.dustAmt > 0.12 {
            let len = TOYS[max(0, g.toy)].len
            for i in 0..<12 {
                let t = (NOW * 1.6 + Double(i) / 12).truncatingRemainder(dividingBy: 1)
                let a = g.dustAmt
                c.circ(g.px - cam - g.face * (len / 2 + t * 80 * a), GY - 1 - t * 16 * a, 2 + t * 12 * a, Col(0xd8bc90, (1 - t) * 0.5 * a).shade(1 - dark * 0.5))
            }
        }
        if g.genOn && g.rigArea == g.area {
            let gx = g.rigX - cam - g.rigFace * (RIGS[g.rig.rawValue].len / 2 + 12)
            c.RR(gx - 8, GY - 11, 16, 11, 2, Col(0x2a2a2e))
            c.RR(gx - 7, GY - 10, 14, 9, 1.6, Col(0xe8a020).shade(1 - dark * 0.25))
            c.R(gx - 5, GY - 7, 10, 3, Col(0x2a2a2e))
            c.R(gx - 6, GY - 12.6, 12, 1.4, Col(0x4a4a4e))
            c.circ(gx + 4.6, GY - 2.6, 0.8, Col(0x60ff70))
            for i in 0..<4 {
                let t = (NOW * 1.2 + Double(i) / 4).truncatingRemainder(dividingBy: 1)
                c.circ(gx + 5 + t * 6, GY - 6 - t * 14, 1 + t * 3, Col(0x8a8a88, (1 - t) * 0.4))
            }
            if dark > 0.3 { g.text("brrrr", gx + 4, GY - 14 - sin(NOW * 30) * 0.4, 3, CREAM.alpha(0.6)) }
        }
        if g.madT > 0 {
            let mx = g.madX - cam
            let f = g.px - cam > mx ? 1.0 : -1.0
            person(mx, GY + 3, 777, f, 0, false)
            let shake = sin(NOW * 22) * 1.4
            c.roundCaps(true)
            c.seg(mx + f * 1.4, GY - 11, mx + f * 3 + shake, GY - 19, 1.5, Col(0xd9a37a))
            c.roundCaps(false)
            c.circ(mx + f * 3 + shake, GY - 19.6, 1.2, Col(0xd9a37a))
            g.text(g.madText, mx, GY - 30, 4.6, Col(0xffb0a0), bold: true, plate: true)
        }
    }

    /// A roadrunner on a sign, running.
    private func roadrunnerSign(_ x: Double, _ y: Double, _ dir: Double, _ col: Col) {
        c.ell(x, y, 3, 1.3, col)
        c.seg(x - 2.4 * dir, y - 0.3, x - 7 * dir, y - 2.8, 0.9, col)
        c.circ(x + 3 * dir, y - 1.8, 1.2, col)
        c.seg(x + 4 * dir, y - 1.8, x + 6.6 * dir, y - 1.3, 0.5, col)
        c.seg(x + 2.6 * dir, y - 2.8, x + 1.8 * dir, y - 4.2, 0.5, col)
        c.seg(x, y + 1, x - 1.4 * dir, y + 3.4, 0.4, col); c.seg(x + 0.8 * dir, y + 1, x + 2 * dir, y + 3.2, 0.4, col)
    }

    /// Main Street furniture: street lights, and the signal at Central Boulevard (US 95).
    private func mainDecor() {
        let pole = Col(0x6a6a6c).shade(1 - dark * 0.4)
        var n = floor((cam - 40) / 320)
        while n * 320 < cam + W + 40 {
            let sx = n * 320 + 150 - cam
            c.R(sx - 0.6, GY - 44, 1.2, 46, pole)
            c.seg(sx, GY - 44, sx + 7, GY - 45, 0.8, pole)
            if g.holidays {
                // a lit snowflake on every pole through the holidays
                let lit = dark > 0.3
                let fl = lit ? Col(0xcfeaff) : Col(0xe8eef4)
                for k in 0..<4 {
                    let a = Double(k) * PI / 4
                    c.seg(sx - cos(a) * 5, GY - 30 - sin(a) * 5, sx + cos(a) * 5, GY - 30 + sin(a) * 5, 0.6, fl)
                }
                if lit { lights.append((sx, GY - 30, 14)) }
            }
            c.RR(sx + 5, GY - 46, 5, 2, 0.8, pole)
            if dark > 0.3 { c.R(sx + 5.6, GY - 44.4, 3.8, 0.8, Col(0xffe7a0)); lights.append((sx + 7.5, GY - 40, 34)) }
            n += 1
        }
        // the intersection with Central Blvd / US 95
        let ix = 2340 - cam
        if ix > -60 && ix < W + 60 {
            for k in 0..<6 { c.R(ix - 12 + Double(k) * 4.4, GY + 6.4, 2.4, 10, Col(0xf4f4f0, 0.75)) }
            c.R(ix + 16, GY - 40, 1.6, 41, pole)
            c.RR(ix + 12.4, GY - 52, 8.8, 13, 1.6, Col(0x2a2a2e))
            let t = (NOW + 3).truncatingRemainder(dividingBy: 14)
            let lit = t < 6 ? 2 : (t < 7.6 ? 1 : 0)
            let on: [Col] = [Col(0xff4030), Col(0xffc030), Col(0x40e070)]
            for k in 0..<3 {
                let ly = GY - 49 + Double(k) * 3.8
                c.circ(ix + 16.8, ly, 1.4, k == lit ? on[k] : Col(0x3a3a3c))
                if k == lit { lights.append((ix + 16.8, ly, 10)) }
            }
            c.R(ix + 4, GY - 36, 26, 4, Col(0x1f6a3a)); g.text("MAIN ST", ix + 17, GY - 34, 2.6, CREAM, bold: true)
            c.R(ix + 4, GY - 31, 26, 4, Col(0x1f6a3a)); g.text("CENTRAL BLVD", ix + 17, GY - 29, 2.4, CREAM, bold: true)
            c.RR(ix + 22, GY - 26, 8, 8, 1, Col(0xf4f4f0)); g.text("95", ix + 26, GY - 22, 3, INK, bold: true)
        }
    }

    /// Cars and rigs rolling along the street, busier in show season.
    private func streetTraffic(_ ar: Area) {
        let span = g.WORLD + 400
        let busy = g.on(EV_GEM) || g.on(EV_RTR) || g.on(EV_RV) || g.on(EV_SELL) || g.on(EV_CRAFT)
        let n = busy ? 6 : 3
        let kinds: [RigKind] = [.classA, .minivan, .van, .classC, .skoolie, .classB]
        for k in 0..<n {
            let dir = k % 2 == 0 ? 1.0 : -1.0
            let sp = 36 + hashN(Double(k) + 60) * 22
            var wx = (NOW * sp + hashN(Double(k) + 61) * span).truncatingRemainder(dividingBy: span)
            if dir < 0 { wx = span - wx }
            let sx = wx - 200 - cam
            if sx < -130 || sx > W + 130 { continue }
            let base = dir > 0 ? GY + 12 : GY + 17
            if k % 3 == 2 { toy(4, sx, base, dir, 4 + k * 13, NOW * sp * 0.1) }
            else { rig(kinds[(k + Int(ar.rawValue)) % kinds.count], sx, base, 0, dir, 0.62) }
            if dark > 0.3 { c.glow(sx + dir * 26, base - 5, 16, Col(0xfff2c0, 0.3), Col(0xfff2c0, 0)) }
        }
    }

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
        // a jackrabbit, all ears, bounding through by day
        if !night && ar != .skoolie {
            let jc = (NOW + 13).truncatingRemainder(dividingBy: 19)
            if jc < 5 { jackrabbit(W + 30 - jc * (W + 60) / 5, GY + 5, NOW * 9) }
        }
        // a red-tailed hawk circling high
        if !night && g.weather < 2 {
            let ha = NOW * 0.35
            hawk(W * 0.55 + cos(ha) * 60, GY * 0.22 + sin(ha) * 10, NOW)
        }
        // a great horned owl on a saguaro at night
        if night && (ar == .ltva || ar == .dome || ar == .scaddan || ar == .roadrunner) {
            let ox = 520 - cam
            if ox > -20 && ox < W + 20 {
                saguaro(ox, GY + 1, 44, 77, SAG, true)
                owl(ox, GY - 45, NOW)
            }
        }
        // a dust devil spinning across on windy days
        if g.weather == 1 && !night {
            let dc = (NOW + 5).truncatingRemainder(dividingBy: 26)
            if dc < 13 { dustDevil(-30 + dc * (W + 60) / 13, GY + 2) }
        }
        // a coyote trotting past at night
        if night {
            let cx = (NOW * 18).truncatingRemainder(dividingBy: w + 300) - 150
            coyote(cx - cam, GY + 4, NOW * 10)
        }
        ravens()
    }
    private func jackrabbit(_ x: Double, _ base: Double, _ ph: Double) {
        if x < -20 || x > W + 20 { return }
        let col = Col(0x9a8a72).shade(1 - dark * 0.5)
        let hop = abs(sin(ph)) * 5
        let y = base - hop
        c.ell(x, y - 4, 4.4, 2.6, col)
        c.circ(x - 4, y - 6, 2, col)
        c.ell(x - 3.6, y - 11, 0.9, 3.6, col); c.ell(x - 5, y - 10.6, 0.9, 3.4, col.shade(0.9))
        c.ell(x - 3.6, y - 11, 0.4, 2.4, Col(0xd8a0a0, 0.6))
        c.circ(x + 4.2, y - 4.6, 1.1, Col(0xf2ede4))
        c.seg(x + 2, y - 2, x + 4 + (hop > 2 ? 3 : 0), y, 0.9, col.shade(0.85))
        c.circ(x - 4.8, y - 6.4, 0.4, INK)
    }
    private func hawk(_ x: Double, _ y: Double, _ t: Double) {
        let col = Col(0x5a4030)
        let f = sin(t * 1.4) * 1.2
        c.poly(col, [x - 9, y - f, x - 2, y - 1, x, y - 2, x + 2, y - 1, x + 9, y - f, x + 2, y + 1, x - 2, y + 1])
        c.poly(Col(0xb8502e), [x - 1.2, y + 1, x + 1.2, y + 1, x + 1.6, y + 3.4, x - 1.6, y + 3.4])
    }
    private func owl(_ x: Double, _ y: Double, _ t: Double) {
        let col = Col(0x6a5a48).shade(0.6)
        c.ell(x, y, 3.2, 4.4, col)
        c.circ(x, y - 4.4, 2.8, col)
        c.poly(col, [x - 2.6, y - 6, x - 2, y - 8.4, x - 0.8, y - 6.4])
        c.poly(col, [x + 2.6, y - 6, x + 2, y - 8.4, x + 0.8, y - 6.4])
        let blink = sin(t * 0.9) > 0.97
        if !blink { c.circ(x - 1.1, y - 4.6, 0.8, Col(0xffd040)); c.circ(x + 1.1, y - 4.6, 0.8, Col(0xffd040)) }
        if (t.truncatingRemainder(dividingBy: 9)) < 1.6 { g.text("hoo-hoo", x + 10, y - 10, 3.2, CREAM.alpha(0.6)) }
    }
    private func dustDevil(_ x: Double, _ base: Double) {
        for i in 0..<16 {
            let f = Double(i) / 15
            let r = 2 + f * 9
            let sw = sin(NOW * 6 + f * 5) * f * 5
            c.ell(x + sw, base - f * 46, r, r * 0.35, Col(0xd8bc90, 0.22 * (1 - f * 0.5)).shade(1 - dark * 0.5))
        }
        for k in 0..<5 {
            let a = NOW * 7 + Double(k) * 1.3
            c.circ(x + cos(a) * 8, base - 10 - Double(k) * 7, 0.7, Col(0x8a6a44, 0.6))
        }
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
        let fr = W - g.safeR - 12
        c.RR(fr - 64, H - 34, 64, 15, 7.5, Col(0x1c1410, 0.65))
        g.text("Send feedback", fr - 32, H - 26.5, 4.6, CREAM, bold: true)
        g.hits.append(Hit(id: 69, x: fr - 70, y: H - 40, w: 76, h: 26))
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
        let lifeSub = ["Vans, skoolies, Skooliepalooza. Starts with friends (5 cred) and a bicycle.", "A snowbird with a check coming in. Starts with 100 more coins and a side-by-side."]
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
