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
            cam = (g.WORLD - W / ZOOM) * (0.5 - 0.5 * cos(NOW * 0.045))
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
            if g.alsOpen { alsOverlay() }
            if g.customOpen { customOverlay() }
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

        // from here down the world is drawn closer in: bigger people, rigs and plants, less empty sky
        let fullW = W, fullH = H
        let gys = GY + 2
        let text0 = g.texts.count, hit0 = g.hits.count
        c.save()
        c.translate(0, gys - GY * ZOOM)
        c.scale(ZOOM, ZOOM)
        W = fullW / ZOOM
        H = GY + (fullH - gys) / ZOOM

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
        hillDetail(0.14, 4.1 + seed, GY - 2, ar == .dome ? 30 : 40, Col.mix(Col(0x7a4f48), haze, 0.3).shade(1 - dark * 0.6))
        ridge(0.3, 8.7 + seed, GY + 1, ar == .skoolie ? 8 : (ar == .trail ? 24 : 17), Col.mix(Col(0x8a5a3e), haze, 0.12).shade(1 - dark * 0.65))
        hillDetail(0.3, 8.7 + seed, GY + 1, ar == .skoolie ? 8 : (ar == .trail ? 24 : 17), Col.mix(Col(0x8a5a3e), haze, 0.12).shade(1 - dark * 0.65))

        // a far stand of saguaros on the low hills
        if g.iceAge || g.deep {
            // ice age hills carry juniper and pinyon woodland, not cactus
            var jn = floor((cam * 0.3 - 20) / 13)
            while jn * 13 < cam * 0.3 + W + 20 {
                let wx = jn * 13 + hashN(jn + 8800) * 10
                let top = ridgeY(wx, 8.7 + seed, GY + 1, ar == .skoolie ? 8 : (ar == .trail ? 24 : 17))
                let jy = top + 1 + hashN(jn + 8810) * max(0, GY - top - 3)
                c.ell(wx - cam * 0.3, jy, 2.2 + hashN(jn + 8820) * 1.6, 1.6, (g.deep ? Col(0x5e8a4c) : Col(0x3e5a40)).shade(1 - dark * 0.6))
                jn += 1
            }
        } else if g.inPast || [Area.ltva, .dome, .trail, .scaddan, .roadrunner, .hijolly, .plomosa, .crystal, .palms, .desertbar].contains(ar) {
            var n = floor((cam * 0.3 - 20) / 46)
            while n * 46 < cam * 0.3 + W + 20 {
                if hashN(n + 900 + seed) < (g.inPast || ar == .dome || ar == .trail ? 0.85 : 0.5) {
                    let wx = n * 46 + hashN(n + 910) * 30
                    let sx = wx - cam * 0.3
                    let base = ridgeY(sx + cam * 0.3, 8.7 + seed, GY + 1, ar == .trail ? 24 : 17) + 2
                    saguaro(sx, base, 9 + hashN(n + 920) * 7, n + 930, Col.mix(Col(0x4a5a44), haze, 0.25).shade(1 - dark * 0.6), false)
                }
                n += 1
            }
        }
        if ar == .skoolie { river(haze) }
        if g.inPast { pastBackground(ar) } else { background(ar, haze) }

        // the desert floor and the dirt road
        let paved = !g.inPast && (ar == .main || ar == .tyson)
        let dirt = paved ? Col(0xd2b488) : (ar == .trail ? Col(0xd4b282) : Col(0xdcbc8c))
        c.vfill(0, GY, W, H - GY, [(0, dirt), (1, Col(0xb48a5a))])
        c.R(0, GY, W, 1, Col(0xf0d8ac, 0.7))
        washes()
        clutter()
        if g.area == .dome && !g.inPast { goldRoad() }
        if g.deep {
            // five million years back the valley holds water: a long arm of it lies between you and the hills
            let sea = Col(0x3f93b4).shade(1 - dark * 0.5)
            c.R(0, GY - 8, W, 9, sea)
            c.R(0, GY - 8.3, W, 0.6, Col(0xe8dcb8).shade(1 - dark * 0.5))
            for q in 0..<26 {
                let d = Double(q)
                let wx0 = (hashN(d + 9060) * (W + 40) + NOW * (2 + hashN(d + 9061) * 3)).truncatingRemainder(dividingBy: W + 40) - 20
                c.R(wx0, GY - 7 + hashN(d + 9062) * 7, 5 + hashN(d + 9063) * 9, 0.3, Col(0xe8f6ff, 0.55))
            }
            c.R(0, GY, W, 1.4, Col(0xf4ead0).shade(1 - dark * 0.5))
        }
        if g.iceAge || g.deep {
            // wetter country: the flats are grassy between the shrubs
            c.R(0, GY, W, H - GY, Col(0x7a8a4a, 0.24))
            var gn = floor(cam / 7) - 1
            while gn * 7 < cam + W + 7 {
                let gx = gn * 7 + hashN(gn + 8900) * 7 - cam
                let gy = GY + 2 + hashN(gn + 8910) * (H - GY - 4)
                for q in 0..<3 { c.seg(gx + Double(q) - 1, gy, gx + (Double(q) - 1) * 1.8, gy - 1.6 - hashN(gn + Double(q)) * 1.4, 0.3, Col(0x8a9a4e).shade(1 - dark * 0.5)) }
                gn += 1
            }
        }
        if paved {
            // Main Street and Kuehn Street are paved
            c.R(0, GY + 6, W, 11, Col(0x5a5450))
            var lx = -((cam).truncatingRemainder(dividingBy: 30))
            while lx < W { c.R(lx, GY + 11.2, 12, 0.8, Col(0xf2c14e, 0.8)); lx += 30 }
        } else if g.inPast {
            // no road yet: just a foot trail worn into the desert
            c.R(0, GY + 9, W, 2.4, Col(0xe6cba0, 0.45))
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
        // the desert floor is strewn with rock everywhere: gravel, fist-sized stones, a few as big as a bowling ball,
        // dark with desert varnish and lit on top
        let tones: [Col] = [Col(0x6a4a38), Col(0x7e5a44), Col(0x5a4a44), Col(0x8a6a50), Col(0x4e3c34)]
        var n = floor(cam / 5) - 2
        while n * 5 < cam + W + 10 {
            for q in 0..<2 {
                let d = n * 2 + Double(q)
                let sx = n * 5 + hashN(d + 50) * 5 - cam
                let depth = hashN(d + 60)
                let sy = GY + 2.5 + depth * (H - GY - 4)
                if paved && sy < GY + 18.5 { continue }
                let big = hashN(d + 70)
                let r: Double = big > 0.96 ? 1.1 + hashN(d + 75) * 0.5 : (big > 0.75 ? 0.6 + hashN(d + 75) * 0.4 : 0.25 + hashN(d + 75) * 0.3)
                let k = r * (0.8 + depth * 0.5)
                let col = tones[Int(hashN(d + 80) * 5) % 5].shade(1 - dark * 0.45)
                c.ell(sx, sy, k * 1.25, k * 0.8, col)
                if k > 0.6 { c.ell(sx - k * 0.25, sy - k * 0.28, k * 0.7, k * 0.35, col.shade(1.3)) }
            }
            n += 1
        }

        // cactus and brush along the strip: dense at Dome Rock, sparse in town, palms by the river
        let skip = g.inPast ? 0 : (paved ? 0.7 : (ar == .ltva ? 0.3 : 0))
        let sagCut = g.inPast ? 0.5 : 0.3
        n = floor((cam - 80) / 64)
        while n * 64 < cam + W + 80 {
            if hashN(n + 77 + seed) >= skip {
                let wx = n * 64 + hashN(n + 3) * 44
                let sx = wx - cam
                let k = hashN(n + 31 + seed)
                if g.deep { deepPlant(sx, k, n) }
                else if g.iceAge { icePlant(sx, k, n) }
                else if ar == .dome && wx > 2700 && !g.inPast {
                    // Gold Nugget Road is thick with it: two or three plants where the flats have one
                    goldPlant(sx, k, n)
                    goldPlant(sx + 24 + hashN(n + 41) * 10, hashN(n + 131 + seed), n + 500)
                    if hashN(n + 43) < 0.6 { goldPlant(sx - 20 - hashN(n + 47) * 8, hashN(n + 231 + seed), n + 900) }
                }
                else if ar == .skoolie && g.inPast && k < 0.4 { cottonwood(sx, GY + 1, n) }
                else if ar == .skoolie && k < 0.25 { palm(sx, GY + 1, 40 + hashN(n + 5) * 22, n) }
                else if k < sagCut {
                    if hashN(n + 91) < 0.1 { sagSkeleton(sx, GY + 1, 30 + hashN(n + 5) * 24, n) } else { saguaro(sx, GY + 1, 22 + hashN(n + 5) * 36, n, SAG, true) }
                }
                else if k < 0.48 { cholla(sx, GY + 1, 0.8 + hashN(n + 6) * 0.5, n) }
                else if k < 0.57 { creosote(sx, GY + 1, n) }
                else if k < 0.62 { brittlebush(sx, GY + 1, n) }
                else if k < 0.72 { ocotillo(sx, GY + 1, n) }
                else if k < 0.78 { barrel(sx, GY + 1, 0.9 + hashN(n + 8) * 0.5, n) }
                else if k < 0.85 { beavertail(sx, GY + 1, n) }
                else if k < 0.91 { paloverde(sx, GY + 1, n) }
                else if k < 0.96 { mesquite(sx, GY + 1, n) }
                else { ironwood(sx, GY + 1, n) }
            }
            n += 1
        }

        if g.plantShow {
            let px0 = 30.0
            beavertail(px0, GY + 1, 5); beavertail(px0 + 22, GY + 1, 19); cholla(px0 + 44, GY + 1, 1, 3); cholla(px0 + 64, GY + 1, 0.8, 17)
            paloverde(px0 + 100, GY + 1, 7); mesquite(px0 + 160, GY + 1, 11); ironwood(px0 + 225, GY + 1, 13); cottonwood(px0 + 285, GY + 1, 2)
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
            if g.phase == .play {
                let town = !g.inPast && (ar == .main || ar == .tyson)
                let kl = g.inPast ? 0 : (town ? 2 : Int(hashN(Double(ar.rawValue) * 7.3 + 1) * 4) % 4)
                let kr = g.inPast ? 0 : (town ? 3 : Int(hashN(Double(ar.rawValue) * 5.1 + 2) * 4) % 4)
                edgeBlock(8 - cam, kl, 1)
                edgeBlock(g.WORLD - 8 - cam, kr, -1)
            }
            for (i, sp) in g.spots.enumerated() { spot(i, sp) }
            if g.phase == .play && g.inPast {
                pastWild(ar)
            } else if g.phase == .play {
                critters(ar)
                eventCrowds(ar)
                if ar == .main { mainDecor() }
                manners()
            }
            if g.phase == .play && !g.inPast && g.area == .main && g.on(EV_PARADE) { parade() }
            if g.phase == .play { drawYou() }
            if g.phase == .play && !g.inPast && (ar == .main || ar == .tyson) { streetTraffic(ar) }
        }

        if wx == 1 { wind() }
        if wx == 3 { rain() }

        // dusk colour, then night, then the fires and lamps
        let dusk = clampD(1 - abs(t - 0.62) / 0.08, 0, 1)
        if dusk > 0 { c.R(0, 0, W, H, Col(0xff7a30, 0.1 * dusk)) }
        if dark > 0 { c.R(0, 0, W, H, Col(0x0a1030, 0.42 * dark)) }
        if dark > 0.15 {
            for l in lights {
                c.glow(l.0, l.1, l.2, Col(0xffb050, 0.5 * dark), Col(0xffb050, 0))
            }
        }

        if g.iceAge { c.R(0, 0, W, H, Col(0x9ab8c8, 0.1)) }
        if g.deep { c.R(0, 0, W, H, Col(0xffe6a8, 0.07)) }
        // the step through time: a bright flash that fades
        if g.flashT > 0 { c.R(0, 0, W, H, Col(0xfff4d8, clampD(g.flashT, 0, 1))) }

        // floating notes and the ring
        for f in g.floaters {
            g.text(f.s, f.x - cam, f.y, 6.5, f.col.alpha(clampD(1.8 - f.t, 0, 1)), bold: true)
        }
        if g.phase == .play && g.active >= 0 { ring(g.active) }

        // back to screen units; move the labels and tap targets drawn in the world to where they landed
        c.restore()
        W = fullW; H = fullH
        for i in text0..<g.texts.count {
            g.texts[i].x *= ZOOM
            g.texts[i].y = gys + (g.texts[i].y - GY) * ZOOM
            g.texts[i].size *= ZOOM
            g.texts[i].wrap *= ZOOM
        }
        for i in hit0..<g.hits.count {
            let h = g.hits[i]
            g.hits[i] = Hit(id: h.id, x: h.x * ZOOM, y: gys + (h.y - GY) * ZOOM, w: h.w * ZOOM, h: h.h * ZOOM)
        }
    }

    /// Your rig, your toy and you, with a soft glow on whatever you can tap.
    private func drawYou() {
        let pulse = 0.3 + 0.14 * sin(NOW * 4)
        if g.rigHere && !g.inRig {
            // always know which way home is; when you're run down, the camp itself is pointed out
            let rx0 = g.rigX - cam
            let b = abs(sin(NOW * 4)) * 2.4
            let lx = g.safeL / ZOOM
            if rx0 < -24 {
                c.poly(GOLD, [lx + 8 - b, GY - 34, lx + 15 - b, GY - 38.4, lx + 15 - b, GY - 29.6])
                g.text("your camp", lx + 18 - b, GY - 34, 4.2, GOLD, align: 1, bold: true, plate: true)
            } else if rx0 > W + 24 {
                let rx1 = W - g.safeR / ZOOM
                c.poly(GOLD, [rx1 - 8 + b, GY - 34, rx1 - 15 + b, GY - 38.4, rx1 - 15 + b, GY - 29.6])
                g.text("your camp", rx1 - 18 + b, GY - 34, 4.2, GOLD, align: 2, bold: true, plate: true)
            } else if g.health < 60 && !g.nearRig && !g.onToy {
                tapArrow(rx0 + 44, GY - 30, "Rest by your fire here")
            }
        }
        if g.rigHere {
            let rx = g.rigX - cam
            let def = RIGS[g.rig.rawValue]
            if g.nearRig && !g.inRig {
                c.glow(rx, GY - def.high * 0.45, def.len * 0.85, Col(0xffe9a0, pulse), Col(0xffe9a0, 0))
            }
            rig(g.rig, rx, GY + (g.inRig ? 12 : 0), g.panels, g.rigFace)
            if g.rig != .tent { rigCustom(rx, GY + (g.inRig ? 12 : 0), def, g.rigFace, 1) }
            if g.rig != .tent { gear(rx, GY + (g.inRig ? 12 : 0), def, g.rigFace, !g.inRig) }
            if g.nearRig && !g.inRig && !g.onToy && g.rig != .tent && g.phase == .play {
                g.text("Paint & flag", rx, GY + 8, 4, GOLD, bold: true, plate: true)
            }
            if g.nearRig {
                g.hits.append(Hit(id: 50, x: rx - def.len / 2 - 8, y: GY - def.high - 12, w: def.len + 16, h: def.high + 14))
                if !g.inRig && !g.onToy && g.rig != .tent { g.hits.append(Hit(id: 59, x: rx - 24, y: GY + 2, w: 48, h: 13)) }
                if !g.inRig && !g.onToy {
                    if g.rig != .tent && !g.shown.contains("rigUsed") { tapArrow(rx, GY - def.high - 4, "Tap here to drive") }
                    else { g.text(g.rig == .tent ? "Your tent" : "Tap to drive", rx, GY - def.high - 8, 5.5, CREAM) }
                }
            }
        }
        if g.toy >= 0 && g.toyHere && !g.inRig {
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
                if !g.shown.contains("toyUsed") { tapArrow(tx, GY - 22, "Tap here to ride") } else { g.text("Tap to ride", tx, GY - 26, 5.5, CREAM) }
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
                toyFlag(0, 0, g.onToy ? g.face : 1)
                c.restore()
            } else {
                toy(g.toy, tx, tb, g.onToy ? g.face : 1, g.onToy ? g.look : -1, g.onToy ? g.walk : 0)
                toyFlag(tx, tb, g.onToy ? g.face : 1)
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
            let gap = 40.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                let h = hashN(n + 1200)
                let sx = n * gap + hashN(n + 1210) * 18 - cam * par
                if h < 0.8 {
                    let kinds: [RigKind] = [.classA, .classC, .classA, .classB, .classC, .van, .classA, .skoolie]
                    let k = kinds[Int(hashN(n + 1220) * 8) % 8]
                    let face = hashN(n + 1240) < 0.5 ? 1.0 : -1.0
                    let st = hashN(n + 1250)
                    if st < 0.28 { camper(0, sx, GY + 0.5, face, n, 0.5) }
                    else if st < 0.5 { camper(Int(hashN(n + 1260) * 9) % 9, sx, GY + 0.5, face, n, 0.5) }
                    else { rig(k, sx, GY + 0.5, hashN(n + 1230) < 0.5 ? 2 : 0, face, 0.5) }
                    campDress(sx, n)
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
                let vr = Int(hashN(n + 1360) * 6) % 6
                if vr == 0 {
                    // brick: courses and a soldier row
                    var by = GY - h + 3
                    while by < GY - 1 { c.R(sx, by, w, 0.25, col.shade(0.84)); by += 2.2 }
                    c.R(sx, GY - h + 1.6, w, 1.2, col.shade(0.9))
                } else if vr == 1 {
                    // board and batten
                    var bx = sx + 2
                    while bx < sx + w { c.R(bx, GY - h, 0.35, h, col.shade(0.84)); bx += 3 }
                } else if vr == 2 {
                    // a row of small upper windows and a painted band
                    for i in 0..<4 { c.RR(sx + w * 0.62 + Double(i % 2) * 6, GY - h + 3.4 + Double(i / 2) * 5, 4, 3, 0.3, GLASS.shade(1 - dark * 0.3)) }
                    c.R(sx, GY - h * 0.56, w, 1.6, signs_band(n).shade(1 - dark * 0.4))
                } else if vr == 3 {
                    // a mural: desert sunset on the side wall
                    c.R(sx + w * 0.6, GY - h + 3, w * 0.34, h * 0.42, Col(0xf2a44e).shade(1 - dark * 0.4))
                    c.dome(sx + w * 0.77, GY - h + 3 + h * 0.42, w * 0.09, Col(0xf8e08a).shade(1 - dark * 0.4))
                    c.poly(Col(0x7a4a6a).shade(1 - dark * 0.4), [sx + w * 0.6, GY - h + 3 + h * 0.42, sx + w * 0.68, GY - h + 3 + h * 0.2, sx + w * 0.76, GY - h + 3 + h * 0.34, sx + w * 0.86, GY - h + 3 + h * 0.16, sx + w * 0.94, GY - h + 3 + h * 0.42])
                } else if vr == 4 {
                    // corrugated metal siding with rust streaks
                    var bx = sx + 1
                    while bx < sx + w { c.R(bx, GY - h, 0.5, h, col.shade(1.1)); bx += 2 }
                    for i in 0..<4 { c.R(sx + hashN(n + Double(i) + 1370) * w, GY - h, 0.8, 4 + hashN(n + Double(i) + 1380) * 9, Col(0x8a4a2a, 0.45)) }
                }
                // rooftop: a swamp cooler, a water tank, a dish or a flag, by turns
                let rf = Int(hashN(n + 1390) * 5) % 5
                if rf == 0 {
                    c.R(sx + 3, GY - h - 7, 0.8, 7, Col(0x6a6a6a)); c.R(sx + 6.2, GY - h - 7, 0.8, 7, Col(0x6a6a6a)); c.RR(sx + 1.6, GY - h - 12, 7, 5.4, 1.4, Col(0x9aa0a4).shade(1 - dark * 0.5))
                } else if rf == 1 {
                    c.R(sx + 4, GY - h - 13, 0.4, 13, Col(0xc8c8c4))
                    c.poly(Col(0xc8281e).shade(1 - dark * 0.4), [sx + 4.4, GY - h - 13, sx + 10, GY - h - 12.4 + sin(NOW * 4 + n) * 0.5, sx + 4.4, GY - h - 10])
                } else if rf == 2 {
                    c.R(sx + 5, GY - h - 4, 0.5, 4, Col(0x6a6a6a)); c.arcFill(sx + 5.2, GY - h - 4.6, 2.4, PI * 0.2, PI * 1.2, Col(0xd8d8d4).shade(1 - dark * 0.5))
                } else if rf == 3 {
                    c.R(sx + 4, GY - h - 9, 0.4, 9, Col(0x5a5a5a)); for i in 0..<3 { c.R(sx + 2.4, GY - h - 8.6 + Double(i) * 1.8, 3.6, 0.3, Col(0x5a5a5a)) }
                }
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
            let gap = 130.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1400) < 0.78 {
                    let sx = n * gap + hashN(n + 1410) * 60 - cam * par
                    let kinds: [RigKind] = [.van, .classB, .skoolie, .classC, .tent]
                    campRig(n, kinds[Int(hashN(n + 1420) * 5) % 5], sx, 1, hashN(n + 1430) < 0.5 ? 1 : -1); campDress(sx, n)
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
        case .desertbar:
            // the Buckskin Mountains, rough and red, and a dirt lot full of trucks and side-by-sides
            let bx = W * 0.5 + 200 - cam * 0.2
            let rock = Col(0x9a5a3e).shade(1 - dark * 0.6)
            massif([bx - 360, GY + 1, bx - 300, GY - 46, bx - 240, GY - 30, bx - 180, GY - 66, bx - 100, GY - 40, bx - 40, GY - 58, bx + 40, GY - 34, bx + 120, GY - 50, bx + 220, GY + 1], rock)
            var n = floor((cam * par - 70) / 90)
            while n * 90 < cam * par + W + 70 {
                if hashN(n + 2100) < 0.6 {
                    let sx = n * 90 + hashN(n + 2110) * 30 - cam * par
                    if hashN(n + 2120) < 0.5 { toy(5, sx, GY + 0.5, 1, -1, 0) } else { toy(4, sx, GY + 0.5, -1, -1, 0) }
                }
                n += 1
            }
        case .intaglios:
            // flat desert pavement running to the Big Maria Mountains
            let mx = W * 0.5 - cam * 0.15
            massif([mx - 400, GY + 1, mx - 300, GY - 36, mx - 200, GY - 28, mx - 100, GY - 50, mx, GY - 40, mx + 120, GY - 56, mx + 260, GY - 30, mx + 400, GY + 1], Col(0x7a5a52).shade(1 - dark * 0.6))
        case .hijolly, .plomosa:
            // boondockers spread out across the open desert
            let gap = ar == .hijolly ? 120.0 : 150.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1900 + Double(ar.rawValue)) < 0.75 {
                    let sx = n * gap + hashN(n + 1910) * 50 - cam * par
                    let kinds: [RigKind] = [.classA, .classC, .van, .skoolie, .classB, .minivan]
                    campRig(n, kinds[Int(hashN(n + 1920 + Double(ar.rawValue)) * 6) % 6], sx, 2, hashN(n + 1930) < 0.5 ? 1 : -1); campDress(sx, n)
                }
                n += 1
            }
        case .crystal:
            // the Kofa's jagged volcanic ridges, a few campers, quartz glinting on the slope
            let kx = W * 0.5 - cam * 0.18
            let kofa = Col(0x7a5a4a).shade(1 - dark * 0.6)
            massif([kx - 260, GY + 1, kx - 200, GY - 40, kx - 170, GY - 28, kx - 130, GY - 62, kx - 90, GY - 44, kx - 40, GY - 70, kx + 10, GY - 38, kx + 60, GY - 52, kx + 120, GY - 30, kx + 200, GY + 1], kofa)
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
            canyonWall(W * 0.5 + 300 - cam * 0.3)
        case .roadrunner:
            let fest = g.phase == .play && g.on(EV_QFEST)
            let gap = fest ? 80.0 : 150.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1560) < (fest ? 0.85 : 0.7) {
                    let sx = n * gap + hashN(n + 1570) * 30 - cam * par
                    let kinds: [RigKind] = [.classA, .classC, .van, .classB]
                    campRig(n, kinds[Int(hashN(n + 1580) * 4) % 4], sx, 1, hashN(n + 1590) < 0.5 ? 1 : -1); campDress(sx, n)
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
                    let pick = hashN(tw + 1770)
                    if pick < 0.4 { paloverde(tx, GY - 2, tw, 0.6) }
                    else if pick < 0.7 { mesquite(tx, GY - 2, tw, 0.6) }
                    else { ironwood(tx, GY - 2, tw, 0.6) }
                }
                tw += 1
            }
            let gap = 130.0
            var n = floor((cam * par - 70) / gap)
            while n * gap < cam * par + W + 70 {
                if hashN(n + 1520) < 0.75 {
                    let sx = n * gap + hashN(n + 1530) * 50 - cam * par
                    let kinds: [RigKind] = [.classC, .skoolie, .van, .classA, .minivan]
                    campRig(n, kinds[Int(hashN(n + 1540) * 5) % 5], sx, 2, hashN(n + 1550) < 0.5 ? 1 : -1); campDress(sx, n)
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
        let reach = sp.kind == .gemworld ? 170.0 : (sp.kind == .hike && sp.arg == 1 ? 640.0 : 130.0)
        if x < -reach || x > W + reach { return }
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
            if g.rigHere || g.phase != .play {
                fire(x + 4, GY + 3)
            } else {
                c.ell(x + 4, GY + 3, 6, 1.6, Col(0x4a4038))
                for j in 0..<5 { c.circ(x - 1 + Double(j) * 2.5, GY + 3, 1.2, Col(0x7a7068)) }
            }
            c.poly(Col(0x3f6a8a), [x + 16, GY + 2, x + 17, GY - 8, x + 19, GY - 8, x + 20, GY - 2, x + 25, GY - 2, x + 25, GY + 2])
            if g.rigHere && g.phase == .play {
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
            saguaro(x - 58, GY + 1, 82, 4242, SAG, true)
            facade(x - 40, GY - 26, 80, 26, Col(0xe8d8bc))
            if g.phase == .play && !g.inPast {
                g.hits.append(Hit(id: 56, x: x - 40, y: GY - 34, w: 80, h: 36))
                if near { g.text("tap the building to go inside", x, GY + 6, 3.6, CREAM, plate: true) }
            }
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
            // K&B Tools sets up under a big white frame tent at the show grounds: open sides, tables and racks of tools
            let vinyl = Col(0xf4f2ec).shade(1 - dark * 0.4)
            for q in 0..<5 { c.R(x - 60 + Double(q) * 30 - 0.6, GY - 26, 1.2, 26, Col(0x8a8f96)) }
            for q in 0..<4 {
                let px = x - 60 + Double(q) * 30
                c.poly(vinyl, [px - 1, GY - 26, px + 15, GY - 40, px + 31, GY - 26])
                c.poly(vinyl.shade(0.9), [px + 15, GY - 40, px + 31, GY - 26, px + 22, GY - 26])
                c.R(px - 1, GY - 26, 32, 3.4, vinyl.shade(0.94))
            }
            c.RR(x - 36, GY - 54, 72, 12, 2, Col(0xf2c418).shade(1 - dark * 0.3))
            g.text("K&B", x - 14, GY - 48, 7.4, Col(0x2a1e14), bold: true)
            g.text("TOOLS", x + 12, GY - 48, 4.6, Col(0x2a1e14), bold: true)
            c.R(x - 30, GY - 42, 0.8, 4, Col(0x6a6a6a)); c.R(x + 30, GY - 42, 0.8, 4, Col(0x6a6a6a))
            // pegboard at the back, bins and tables out front
            c.R(x - 56, GY - 22, 112, 14, Col(0xb89a6a).shade(1 - dark * 0.5))
            let tool: [Col] = [Col(0xc8281e), Col(0x2e4a7a), Col(0xf2c418), Col(0x3a3a3e), Col(0x3f8f6a)]
            for q in 0..<22 { c.R(x - 53 + Double(q) * 5, GY - 20 + Double(q % 3) * 2, 1.2, 5 + Double(q % 2) * 2, tool[q % 5].shade(1 - dark * 0.4)) }
            for q in 0..<3 {
                let tx = x - 50 + Double(q) * 38
                c.R(tx, GY - 8, 28, 1.6, Col(0x8a6238)); c.R(tx + 1, GY - 7, 1, 7, Col(0x6a6a6a)); c.R(tx + 26, GY - 7, 1, 7, Col(0x6a6a6a))
                for k in 0..<6 { c.RR(tx + 1.5 + Double(k) * 4.4, GY - 11.4, 3.6, 3.4, 0.6, tool[(k + q) % 5].shade(1 - dark * 0.4)) }
            }
            if g.phase == .play { person(x + 40, GY + 1, 512, -1, 0, false) }
            if dark > 0.3 { lights.append((x - 30, GY - 22, 24)); lights.append((x + 30, GY - 22, 24)) }
            label = false
            top = 62
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
            // Gem World on Main Street: a huge wholesale warehouse, five storefronts long, with a rock yard out front
            let wall = Col(0xe2d6bc)
            let x0 = x - 145.0, bw = 290.0
            let hh = 60.0
            facade(x0, GY - hh, bw, hh, wall)
            // corrugated siding and a long low metal roof, high overhead
            var sx = x0 + 3
            while sx < x0 + bw { c.R(sx, GY - hh + 1, 0.4, hh - 2, wall.shade(0.9 - dark * 0.4)); sx += 4 }
            let roof = Col(0x8a8f96).shade(1 - dark * 0.45)
            c.poly(roof, [x0 - 4, GY - hh, x0 + bw * 0.5, GY - hh - 10, x0 + bw + 4, GY - hh])
            c.R(x0 - 4, GY - hh - 1, bw + 8, 1.6, roof.shade(0.8))
            // the sign, painted big across the upper wall
            c.RR(x - 74, GY - hh + 5, 148, 17, 2, Col(0x6a3a7a).shade(1 - dark * 0.3))
            g.text("GEM WORLD", x, GY - hh + 12, 9, CREAM, bold: true)
            g.text("WHOLESALE  ·  ROUGH  ·  SLABS  ·  BEADS  ·  FINDINGS", x, GY - hh + 19, 3, GOLD, bold: true)
            // a row of high windows under the eaves
            for w in 0..<7 { if w < 2 || w > 5 { c.RR(x0 + 12 + Double(w) * 41, GY - hh + 8, 14, 6, 0.8, GLASS.shade(1 - dark * 0.3)) } }
            // three tall roll-up doors open onto aisles of pallet racking
            let jewel: [Col] = [Col(0x9a5ad0), Col(0xf0f0f4), Col(0xe2742e), Col(0x2fa7a0), Col(0xc85a3a), Col(0x5a8ad0)]
            for d in 0..<3 {
                let dx = x0 + 34 + Double(d) * 90
                c.R(dx, GY - 34, 42, 34, Col(0x2a2420).shade(1 - dark * 0.2))
                c.R(dx, GY - 37, 42, 4, Col(0x9a9a98).shade(1 - dark * 0.4))
                if dark > 0.35 { c.R(dx, GY - 33, 42, 33, Col(0xffc060, 0.25)); lights.append((dx + 21, GY - 16, 34)) }
                for r in 0..<6 {
                    let sy = GY - 31 + Double(r) * 5.2
                    c.R(dx + 3, sy + 3, 36, 0.7, Col(0x8a6238))
                    for q in 0..<8 { c.R(dx + 4 + Double(q) * 4.4, sy, 3.6, 3, jewel[(q + r + d) % 6].shade(0.85 - dark * 0.3)) }
                }
            }
            for w in 0..<4 { pane(x0 + 8 + Double(w) * 90, GY - 24, 18, 11) }
            doorway(x0 + bw - 22, GY - 20, 11, 20, Col(0x4a3424))
            // the yard: pallets of flats, bins of rough rock, and a few boulders of rose quartz and amethyst
            for k in 0..<6 {
                let px = x0 + 12 + Double(k) * 48
                c.R(px, GY - 1.6, 20, 1.6, Col(0x8a6238))
                for r in 0..<(2 + k % 2) {
                    c.R(px + 1, GY - 4.6 - Double(r) * 3, 18, 3, Col(0xb8925e).shade(1 - Double(r) * 0.06 - dark * 0.3))
                    for q in 0..<5 { c.circ(px + 3 + Double(q) * 3.6, GY - 4 - Double(r) * 3, 0.9, jewel[(q + r + k) % 6]) }
                }
            }
            for k in 0..<4 {
                let bx = x0 + 36 + Double(k) * 62
                c.R(bx, GY - 6, 10, 6, Col(0x6a6a70).shade(1 - dark * 0.4))
                for q in 0..<4 { c.circ(bx + 1.6 + Double(q) * 2.3, GY - 6.2, 1.5, [Col(0xe8a8b8), Col(0x9a5ad0), Col(0xf0f0f4), Col(0x7ac0a0)][(q + k) % 4].shade(1 - dark * 0.3)) }
            }
            if g.phase == .play { g.hits.append(Hit(id: 52, x: x0, y: GY - 60, w: bw, h: 60)) }
            label = false
            top = 76
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
            g.text(sp.arg == 1 ? "NUGGET" : "GOLD EYE", x - 34, GY - 17.6, 3.6, REDC, bold: true)
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
                g.text("CELIA'S RAINBOW GARDENS", x, GY - 58, 3.8, CREAM, bold: true, plate: true)
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
        case .hike where sp.arg == 2:
            // a sagging stretch of cable, and a sign nobody should need
            c.R(x - 14, GY - 6, 1, 7, Col(0x7a6a5a)); c.R(x + 14, GY - 6, 1, 7, Col(0x7a6a5a))
            c.curve(x - 14, GY - 4.6, x, GY + 1, x + 14, GY - 4.6, 0.6, Col(0x8a8a88))
            c.R(x + 18, GY - 12, 1, 12, Col(0x5a4030))
            c.RR(x + 12, GY - 19, 14, 8, 1, Col(0xf4f1ea))
            g.text("KEEP OUT", x + 19, GY - 15, 2.4, REDC, bold: true)
            label = false
            top = 30
        case .hike where sp.arg == 1:
            // the giant: 171 feet from head to toe, far longer than the screen is wide, scraped into dark desert pavement.
            // it lies in front of the trail, behind a cable fence that runs the whole length
            let pave = Col(0x7a5c46).shade(1 - dark * 0.5), line = Col(0xe2d0ac).shade(1 - dark * 0.5)
            let berm = Col(0x5a4232).shade(1 - dark * 0.5)
            let depth = H - GY
            let cy = GY + depth * 0.56
            let reachY = depth * 0.36
            c.R(x - 380, GY + 3, 980, depth, pave)
            // desert pavement: a tight carpet of dark varnished stones. The figures are where the stones were raked away
            for q in 0..<420 {
                let d = Double(q)
                let rr = 0.4 + hashN(d + 5002) * hashN(d + 5003) * 1.3
                let rx = x - 378 + hashN(d + 5000) * 976
                let ry = GY + 4 + hashN(d + 5001) * (depth - 5)
                let rc = (q % 3 == 0 ? Col(0x4e3a30) : (q % 3 == 1 ? Col(0x66483a) : Col(0x5a4a44))).shade(1 - dark * 0.45)
                c.ell(rx, ry, rr * 1.25, rr * 0.8, rc)
                if rr > 0.8 { c.ell(rx - rr * 0.25, ry - rr * 0.25, rr * 0.7, rr * 0.3, rc.shade(1.3)) }
            }
            c.roundCaps(true)
            for pass in 0..<2 {
                let col = pass == 0 ? berm : line
                let o = pass == 0 ? 1.0 : 0.0
                let wide = pass == 0 ? 2.0 : 0.0
                // head, body, arms flung wide, legs apart, feet turned out
                c.ell(x - 300, cy + o, 13 + wide * 0.4, 5.4 + wide * 0.3, col)
                c.seg(x - 286, cy + o, x - 60, cy + o, 6 + wide, col)
                c.seg(x - 244, cy + o, x - 226, cy - reachY + o, 3.2 + wide, col)
                c.seg(x - 244, cy + o, x - 222, cy + reachY + o, 3.2 + wide, col)
                c.seg(x - 226, cy - reachY + o, x - 204, cy - reachY - 1 + o, 2.6 + wide, col)
                c.seg(x - 222, cy + reachY + o, x - 200, cy + reachY + 1 + o, 2.6 + wide, col)
                c.seg(x - 60, cy + o, x + 110, cy - reachY * 0.6 + o, 4.4 + wide, col)
                c.seg(x - 60, cy + o, x + 110, cy + reachY * 0.6 + o, 4.4 + wide, col)
                c.seg(x + 110, cy - reachY * 0.6 + o, x + 126, cy - reachY * 0.9 + o, 3 + wide, col)
                c.seg(x + 110, cy + reachY * 0.6 + o, x + 126, cy + reachY * 0.9 + o, 3 + wide, col)
                // the four-legged animal, and the spiral, farther along the fence
                c.seg(x + 300, cy + o, x + 420, cy + o, 5 + wide, col)
                c.seg(x + 420, cy + o, x + 446, cy - reachY * 0.5 + o, 3.4 + wide, col)
                c.seg(x + 300, cy + o, x + 276, cy + reachY * 0.4 + o, 2.2 + wide, col)
                for q in 0..<4 {
                    let lx = x + 316 + Double(q) * 30
                    c.seg(lx, cy + o, lx + (q < 2 ? -5.0 : 5.0), cy + (q % 2 == 0 ? -reachY * 0.8 : reachY * 0.8) + o, 2.6 + wide, col)
                }
                c.arcStroke(x + 520, cy + o, 9, 0, PI * 1.6, 2 + wide * 0.6, col)
                c.arcStroke(x + 520, cy + o, 4.4, PI, PI * 2.6, 1.8 + wide * 0.6, col)
            }
            c.roundCaps(false)
            // the fence: posts and two cables between the trail and the figures
            var fx = x - 380.0
            while fx <= x + 600 { c.R(fx, GY - 5, 1, 8, Col(0x7a6a5a).shade(1 - dark * 0.4)); fx += 20 }
            c.R(x - 380, GY - 3.6, 981, 0.6, Col(0x8a8a88)); c.R(x - 380, GY - 0.6, 981, 0.6, Col(0x8a8a88))
            c.RR(x - 18, GY - 26, 36, 12, 1.4, Col(0x5a3a22).shade(1 - dark * 0.4))
            c.R(x - 1, GY - 14, 2, 14, Col(0x5a4030))
            // an interpretive panel with the giant drawn whole, since from the fence you only ever see a piece of him
            let bx = x + 62.0
            c.R(bx - 15, GY - 12, 1.4, 12, Col(0x5a4030)); c.R(bx + 13.6, GY - 12, 1.4, 12, Col(0x5a4030))
            c.RR(bx - 22, GY - 38, 44, 27, 1.6, Col(0x5a3a22).shade(1 - dark * 0.4))
            c.RR(bx - 20.4, GY - 36.4, 40.8, 18.4, 1, Col(0x7a5c46).shade(1 - dark * 0.3))
            let ch = Col(0xeedcb8)
            c.roundCaps(true)
            c.circ(bx - 14, GY - 27, 1.8, ch); c.seg(bx - 12, GY - 27, bx + 2, GY - 27, 1.3, ch)
            c.seg(bx - 9, GY - 27, bx - 8, GY - 33, 0.8, ch); c.seg(bx - 9, GY - 27, bx - 8, GY - 21, 0.8, ch)
            c.seg(bx - 8, GY - 33, bx - 5.4, GY - 33.4, 0.7, ch); c.seg(bx - 8, GY - 21, bx - 5.4, GY - 20.6, 0.7, ch)
            c.seg(bx + 2, GY - 27, bx + 15, GY - 31, 1, ch); c.seg(bx + 2, GY - 27, bx + 15, GY - 23, 1, ch)
            c.seg(bx + 15, GY - 31, bx + 16.6, GY - 32.6, 0.7, ch); c.seg(bx + 15, GY - 23, bx + 16.6, GY - 21.4, 0.7, ch)
            c.roundCaps(false)
            c.circ(bx - 3, GY - 30.6, 0.5, Col(0xd9412e))
            g.text("you are here", bx + 4, GY - 33.6, 1.7, Col(0xf2e8c8))
            g.text("THE GIANT · 171 FEET · 450–2,000 YEARS OLD", bx, GY - 14.6, 1.7, Col(0xf2e8c8), bold: true)
            g.text("BLYTHE INTAGLIOS", x, GY - 22.4, 3, Col(0xf2e8c8), bold: true)
            g.text("PLEASE STAY OUTSIDE", x, GY - 17.6, 2.4, Col(0xf2e8c8, 0.85))
            label = false
            top = 36
        case .bar:
            // the Desert Bar: a hand-built steel church, a long bar under shade, solar panels, a little stage
            let steel = Col(0xb8bcc0).shade(1 - dark * 0.5)
            c.R(x - 70, GY - 30, 34, 30, steel)
            c.poly(steel.shade(0.9), [x - 74, GY - 30, x - 53, GY - 48, x - 32, GY - 30])
            c.R(x - 54, GY - 62, 2, 16, steel); c.R(x - 58, GY - 58, 10, 2, steel)
            c.arch(x - 59, GY - 18, 10, 18, Col(0x2a2a2e))
            c.R(x - 20, GY - 26, 70, 2.4, Col(0x8a6a44).shade(1 - dark * 0.4))
            for k in 0..<5 { c.R(x - 18 + Double(k) * 17, GY - 24, 1.2, 24, Col(0x6a4a2e)) }
            c.R(x - 16, GY - 10, 62, 10, Col(0x6a4a2e).shade(1 - dark * 0.4))
            for k in 0..<4 { c.poly(Col(0x24324a), [x - 14 + Double(k) * 16, GY - 27, x - 2 + Double(k) * 16, GY - 27, x + Double(k) * 16, GY - 32, x - 12 + Double(k) * 16, GY - 32]) }
            c.R(x + 58, GY - 6, 30, 6, Col(0x5a4030)); c.R(x + 58, GY - 26, 30, 2, Col(0x5a4030))
            // the church is welded plate: seams, rivets, a rusted patina creeping up, a round window, a bell
            let rust = Col(0x8a4a2a)
            for k in 0..<5 { c.R(x - 70 + Double(k) * 8.5, GY - 30, 0.3, 30, steel.shade(0.8)) }
            for k in 0..<4 { c.R(x - 70, GY - 30 + Double(k) * 8, 34, 0.3, steel.shade(0.82)) }
            for k in 0..<7 { c.R(x - 69 + hashN(Double(k) + 8700) * 32, GY - 3 - hashN(Double(k) + 8710) * 10, 1 + hashN(Double(k) + 8720) * 2, 3 + hashN(Double(k) + 8710) * 10, rust.alpha(0.35)) }
            c.circ(x - 53, GY - 36, 3, Col(0x2a2a2e)); c.circ(x - 53, GY - 36, 2.3, Col(0x6aa0c8).shade(1 - dark * 0.3)); c.seg(x - 55.3, GY - 36, x - 50.7, GY - 36, 0.3, Col(0x2a2a2e)); c.seg(x - 53, GY - 38.3, x - 53, GY - 33.7, 0.3, Col(0x2a2a2e))
            c.R(x - 54, GY - 47, 2, 2.4, Col(0x2a2a2e)); c.dome(x - 53, GY - 43.4, 1.6, Col(0xb8924a))
            c.seg(x - 74, GY - 30, x - 53, GY - 48, 0.5, steel.shade(1.15))
            // the bar itself: corrugated shade, a back shelf of bottles, stools, a cooler, strings of lights
            for k in 0..<17 { c.R(x - 20 + Double(k) * 4.2, GY - 26, 0.4, 2.4, Col(0x6a5238)) }
            c.R(x - 14, GY - 20, 58, 0.6, Col(0x8a6238)); for k in 0..<14 { c.RR(x - 12 + Double(k) * 4, GY - 23.6, 1.3, 3.6, 0.4, [Col(0x4a9a6a), Col(0xd8a850), Col(0xb86a4a), Col(0x6a90d0)][k % 4].shade(1 - dark * 0.3)) }
            c.R(x - 17, GY - 11, 64, 1.4, Col(0xb8742e).shade(1 - dark * 0.4))
            for k in 0..<6 { c.R(x - 12 + Double(k) * 10.4 - 0.3, GY - 5, 0.6, 5, Col(0x8a8f96)); c.ell(x - 12 + Double(k) * 10.4, GY - 5.4, 2.2, 0.8, Col(0x5a3a22)) }
            c.RR(x + 34, GY - 8, 9, 8, 0.8, Col(0xc8281e).shade(1 - dark * 0.4)); c.R(x + 34, GY - 8.6, 9, 1, Col(0xf4f4f0).shade(1 - dark * 0.4))
            for k in 0..<16 {
                let t = Double(k) / 15
                c.circ(x - 20 + t * 70, GY - 24.6 + sin(t * PI * 4) * 1.2, 0.6, [Col(0xffd68a), Col(0xff8a6a), Col(0x8ad0ff)][k % 3])
            }
            // the stage: a tin back wall, two amps, a drum; and out front, the hand-lettered rules
            c.R(x + 58, GY - 24, 30, 18, Col(0x9aa0a4).shade(1 - dark * 0.5)); for k in 0..<10 { c.R(x + 59 + Double(k) * 3, GY - 24, 0.4, 18, Col(0x7a8084).shade(1 - dark * 0.5)) }
            c.RR(x + 60, GY - 13, 6, 7, 0.6, Col(0x1c1a1a)); c.circ(x + 63, GY - 9.6, 2, Col(0x3a3a3e)); c.RR(x + 81, GY - 13, 6, 7, 0.6, Col(0x1c1a1a)); c.circ(x + 84, GY - 9.6, 2, Col(0x3a3a3e))
            c.RR(x - 96, GY - 22, 20, 12, 1, Col(0xf2e8c8).shade(1 - dark * 0.4)); c.R(x - 87, GY - 10, 1.4, 10, Col(0x6a4a2e))
            g.text("NO CELL", x - 86, GY - 19, 2.4, REDC, bold: true); g.text("NO CARDS", x - 86, GY - 16, 2.4, REDC, bold: true); g.text("NO WORRIES", x - 86, GY - 13, 2.2, INK, bold: true)
            // the wreck that's been parked out front for forty years, and the cooling tower
            c.poly(rust.shade(1 - dark * 0.4), [x + 98, GY - 1, x + 98, GY - 7, x + 104, GY - 8, x + 107, GY - 13, x + 118, GY - 13, x + 121, GY - 8, x + 128, GY - 7, x + 128, GY - 1])
            c.RR(x + 108.6, GY - 12, 8, 3.6, 0.5, Col(0x2a2420)); c.ell(x + 104, GY - 0.6, 2.6, 1, Col(0x2a2420)); c.ell(x + 122, GY - 0.6, 2.6, 1, Col(0x2a2420))
            for k in 0..<4 { c.R(x - 28 + Double(k) * 0.9, GY - 44, 0.5, 44, steel.shade(0.9)) }
            c.poly(steel.shade(0.95), [x - 31, GY - 44, x - 22, GY - 44, x - 24, GY - 50, x - 29, GY - 50])
            if g.barOpen && g.phase == .play {
                person(x + 66, GY - 6, 920, 1, 0, false); person(x + 80, GY - 6, 921, -1, 0, false)
                for k in 0..<3 { let t = (NOW * 0.6 + Double(k) / 3).truncatingRemainder(dividingBy: 1); g.text("♪", x + 72 + sin(t * 6) * 6, GY - 30 - t * 20, 4.4, CREAM.alpha(1 - t)) }
                for k in 0..<6 { person(x - 10 + Double(k) * 11, GY + 3, 930 + k, k % 2 == 0 ? 1 : -1, 0, false) }
            } else {
                c.RR(x + 4, GY - 20, 22, 8, 1, Col(0xf4f1ea)); g.text("CLOSED", x + 15, GY - 16, 2.8, REDC, bold: true)
            }
            g.text("THE DESERT BAR", x + 10, GY - 40, 5, GOLD, bold: true)
            label = false
            top = 66
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
        case .solar:
            // Solar Bill's: a low shop under a roof of panels, more panels racked out front, a service bay with a rig on charge
            let wall = Col(0xf0e6c8)
            facade(x - 40, GY - 24, 80, 24, wall)
            for q in 0..<8 {
                let px = x - 40 + Double(q) * 10
                c.poly(Col(0x1e3a5c).shade(1 - dark * 0.4), [px + 0.6, GY - 25, px + 9.4, GY - 25, px + 8.4, GY - 31, px + 1.6, GY - 31])
                c.seg(px + 5, GY - 25, px + 5, GY - 31, 0.25, Col(0xc8d8e8, 0.7)); c.seg(px + 1, GY - 28, px + 9, GY - 28, 0.25, Col(0xc8d8e8, 0.7))
            }
            c.RR(x - 30, GY - 46, 60, 12, 2, Col(0xf2c418).shade(1 - dark * 0.3))
            c.circ(x - 23, GY - 40, 3.4, Col(0xe8782e)); for q in 0..<8 { let a = Double(q) / 8 * PI * 2; c.seg(x - 23 + cos(a) * 4, GY - 40 + sin(a) * 4, x - 23 + cos(a) * 5.4, GY - 40 + sin(a) * 5.4, 0.5, Col(0xe8782e)) }
            g.text("SOLAR BILL'S", x + 5, GY - 40, 5, INK, bold: true)
            c.R(x - 20, GY - 34, 0.8, 4, Col(0x6a6a6a)); c.R(x + 20, GY - 34, 0.8, 4, Col(0x6a6a6a))
            pane(x - 34, GY - 18, 16, 10); doorway(x - 12, GY - 18, 10, 18, Col(0x4a3424))
            c.R(x + 6, GY - 20, 30, 20, Col(0x2a2420).shade(1 - dark * 0.2)); c.R(x + 6, GY - 22, 30, 2.4, Col(0x9a9a98).shade(1 - dark * 0.4))
            for q in 0..<4 { c.RR(x + 9 + Double(q) * 6.6, GY - 9, 5.4, 9, 0.6, Col(0x2e4a7a).shade(1 - dark * 0.4)); c.R(x + 10 + Double(q) * 6.6, GY - 8, 3.4, 1, Col(0xf2c418)) }
            for q in 0..<3 {
                let px = x + 50 + Double(q) * 13
                c.seg(px + 8, GY, px + 7.4, GY - 8, 0.6, Col(0x8a8a88))
                c.poly(Col(0x1e3a5c).shade(1 - dark * 0.4), [px - 2, GY, px + 7.4, GY - 10, px + 12, GY - 10, px + 3, GY])
                c.seg(px + 0.5, GY - 2.6, px + 9.6, GY - 7.4, 0.25, Col(0xc8d8e8, 0.7))
            }
            g.text("PANELS · BATTERIES · INVERTERS", x, GY + 6, 2.6, CREAM.alpha(0.8))
            top = 52
        case .beerbelly:
            // Beer Belly's Adult Day Care: an open-air bar under shade cloth, a little stage, string lights
            for q in 0..<5 { c.R(x - 52 + Double(q) * 26 - 0.7, GY - 28, 1.4, 28, wood) }
            c.poly(Col(0xd8c8a0).shade(1 - dark * 0.45), [x - 58, GY - 28, x - 50, GY - 34, x + 50, GY - 34, x + 58, GY - 28])
            for q in 0..<12 { c.R(x - 54 + Double(q) * 9, GY - 28, 8, 1.6, (q % 2 == 0 ? Col(0xc8281e) : Col(0xf4f4f0)).shade(1 - dark * 0.4)) }
            c.RR(x - 46, GY - 50, 92, 14, 2, Col(0x3a2414).shade(1 - dark * 0.2))
            g.text("BEER BELLY'S", x, GY - 45.4, 5.4, GOLD, bold: true)
            g.text("ADULT DAY CARE", x, GY - 39.6, 3.4, CREAM, bold: true)
            c.R(x - 30, GY - 36, 0.8, 3, Col(0x6a6a6a)); c.R(x + 30, GY - 36, 0.8, 3, Col(0x6a6a6a))
            c.R(x - 46, GY - 20, 50, 8, Col(0x2a1a14)); for q in 0..<9 { c.RR(x - 44 + Double(q) * 5.4, GY - 19, 2, 5.4, 0.7, [Col(0x8ad0a0), Col(0xd8a850), Col(0xb86a4a)][q % 3]) }
            c.R(x - 48, GY - 10, 54, 2, Col(0xb8742e).shade(1 - dark * 0.3)); c.R(x - 46, GY - 8, 50, 8, Col(0x7a4a2a).shade(1 - dark * 0.3))
            if g.phase == .play {
                for q in 0..<4 {
                    let sx0 = x - 40 + Double(q) * 12
                    c.R(sx0 - 0.4, GY - 5, 0.8, 5, Col(0x8a8f96)); c.ell(sx0, GY - 5.4, 2.6, 0.9, Col(0x8a2e1e))
                    if q != 2 { seated(sx0, GY - 5.8, 700 + q, 0.3) }
                }
                // the stage: one guitar, one amp, a few people dancing in the dust
                c.R(x + 18, GY - 3, 34, 3, Col(0x5a4030).shade(1 - dark * 0.3))
                person(x + 30, GY - 2, 720, -1, 0, false)
                c.seg(x + 26, GY - 13, x + 34, GY - 9, 1.2, Col(0xb8742e)); c.ell(x + 34.6, GY - 8.6, 2.4, 1.8, Col(0xd8a850))
                c.RR(x + 42, GY - 10, 7, 7, 0.8, Col(0x1c1a1a)); c.circ(x + 45.5, GY - 6.5, 2.2, Col(0x3a3a3e))
                for q in 0..<2 { person(x + 66 + Double(q) * 12, GY + 2 - abs(sin(NOW * 5 + Double(q) * 1.4)) * 1.6, 730 + q, q == 0 ? -1 : 1, NOW * 6, true) }
            }
            for q in 0..<14 {
                let t = Double(q) / 13
                let lx = x - 52 + 104 * t, ly = GY - 27 + sin(PI * t * 4) * 1.4
                c.circ(lx, ly, 0.7, [Col(0xffd68a), Col(0xff8a6a), Col(0x8ad0ff), Col(0xb8ff8a)][q % 4])
            }
            if dark > 0.3 { lights.append((x - 20, GY - 18, 30)); lights.append((x + 30, GY - 14, 26)) }
            label = false
            top = 58
        case .carls:
            // Carl's Jr.: the burger place by the freeway, a drive-thru lane wrapping round with a car at the window
            let wall = Col(0xe8dcc0)
            facade(x - 34, GY - 26, 62, 26, wall)
            c.R(x - 36, GY - 30, 66, 5, Col(0xc8281e).shade(1 - dark * 0.35)); c.R(x - 36, GY - 25.4, 66, 1, Col(0xf2c418).shade(1 - dark * 0.35))
            pane(x - 30, GY - 19, 14, 11); pane(x - 14, GY - 19, 14, 11); doorway(x + 3, GY - 19, 9, 19, Col(0x5a5a5e))
            c.RR(x + 16, GY - 17, 9, 7, 0.8, GLASS.shade(1 - dark * 0.3)); c.R(x + 15, GY - 10, 11, 1, Col(0x8a8f96))
            c.R(x - 3.8, GY - 36, 1.6, 10, Col(0x8a8a88))
            c.RR(x - 17, GY - 49, 28, 14, 2, Col(0xc8281e).shade(1 - dark * 0.3))
            g.text("CARL'S JR.", x - 3, GY - 42, 3.8, Col(0xf8e8a0), bold: true)
            c.RR(x + 30, GY - 38, 24, 6, 1, Col(0xf4f4f0).shade(1 - dark * 0.3))
            g.text("DRIVE THRU", x + 42, GY - 35, 2.6, INK, bold: true)
            c.RR(x + 36, GY - 20, 12, 14, 1, Col(0x2a2a2e)); c.R(x + 41.4, GY - 6, 1.2, 6, Col(0x5a5a5a))
            for q in 0..<4 { c.R(x + 37.4, GY - 18.6 + Double(q) * 3, 9.2, 2, [Col(0xf2c418), Col(0xe8782e), Col(0xf4f4f0), Col(0xc8281e)][q].shade(0.9)) }
            g.text("SORRY, NO RANCH", x + 42, GY - 23, 2.2, Col(0xf8e8a0), bold: true, plate: true)
            if g.phase == .play { toy(4, x + 30, GY + 2, 1, 740, 0) }
            c.poly(Col(0xf4f4f0, 0.8), [x + 52, GY + 5, x + 58, GY + 3, x + 58, GY + 7])
            if dark > 0.3 { lights.append((x - 3, GY - 42, 24)); lights.append((x - 10, GY - 14, 30)) }
            label = false
            top = 66
        case .terribles:
            // Terrible's: the big new travel centre off the exit. A long canopy over rows of pumps, the store with a
            // coffee counter inside, a line of EV chargers along the side
            let wall = Col(0xe6e0d4)
            facade(x - 104, GY - 30, 70, 30, wall)
            c.R(x - 106, GY - 35, 74, 6, Col(0xc8281e).shade(1 - dark * 0.35))
            g.text("TERRIBLE'S", x - 69, GY - 32, 4.6, Col(0xf8e8a0), bold: true)
            for q in 0..<3 { pane(x - 100 + Double(q) * 16, GY - 21, 13, 12) }
            doorway(x - 50, GY - 20, 11, 20, Col(0x4a6a7a))
            c.RR(x - 100, GY - 27.6, 30, 5, 1, Col(0x1e5a44).shade(1 - dark * 0.3))
            g.text("STARBUCKS INSIDE", x - 85, GY - 25, 2.3, CREAM, bold: true)
            // the canopy and its islands
            let can = Col(0xf4f4f0).shade(1 - dark * 0.35)
            c.R(x - 26, GY - 40, 132, 6, can); c.R(x - 26, GY - 35.4, 132, 1.4, Col(0xc8281e).shade(1 - dark * 0.35))
            for q in 0..<6 {
                let px = x - 16 + Double(q) * 22.4
                c.R(px - 0.9, GY - 34, 1.8, 34, Col(0xd8d8d4).shade(1 - dark * 0.4))
                c.RR(px - 5, GY - 2, 10, 2.6, 0.6, Col(0xb8b8b4).shade(1 - dark * 0.4))
                for k in 0..<2 {
                    let ux = px - 4.4 + Double(k) * 5.4
                    c.RR(ux, GY - 12, 3.4, 10.4, 0.5, Col(0xe8e8e4).shade(1 - dark * 0.4)); c.R(ux + 0.4, GY - 11, 2.6, 2.4, Col(0x1a2a3a)); c.R(ux + 0.4, GY - 8, 2.6, 1.2, [Col(0xc8281e), Col(0x3a8a4a)][k])
                    c.curve(ux + 3.4, GY - 8, ux + 5, GY - 4, ux + 3.6, GY - 5.6, 0.3, Col(0x1c1a1a))
                }
                if dark > 0.3 { c.R(px - 8, GY - 34.2, 16, 0.8, Col(0xfff2c0)); lights.append((px, GY - 18, 26)) }
            }
            if g.phase == .play {
                rig(.classC, x + 40, GY + 1, 0, 1, 0.62); toy(4, x - 4, GY + 2, -1, 750, 0)
                person(x + 14, GY + 1, 760, 1, 0, false)
            }
            // the EV chargers
            for q in 0..<5 {
                let ex = x + 116 + Double(q) * 9
                c.RR(ex - 1.4, GY - 13, 2.8, 13, 0.8, Col(0xf4f4f0).shade(1 - dark * 0.4)); c.R(ex - 0.9, GY - 11.6, 1.8, 2.6, Col(0x3ad07a))
                c.curve(ex + 1.4, GY - 8, ex + 4, GY - 3, ex + 2, GY - 1, 0.3, Col(0x1c1a1a))
            }
            c.RR(x + 112, GY - 22, 44, 6, 1, Col(0x2e8a5a).shade(1 - dark * 0.3))
            g.text("EV CHARGING", x + 134, GY - 19, 2.6, CREAM, bold: true)
            // the tall price sign you can read from the freeway
            c.R(x - 122, GY - 70, 2.4, 70, Col(0x8a8a88))
            c.RR(x - 138, GY - 86, 34, 18, 2, Col(0xc8281e).shade(1 - dark * 0.3))
            g.text("TERRIBLE'S", x - 121, GY - 80, 3.4, Col(0xf8e8a0), bold: true)
            g.text("GAS · DIESEL · EV", x - 121, GY - 74, 2.2, CREAM, bold: true)
            c.RR(x - 136, GY - 66, 30, 9, 1, Col(0x1c1a1a)); g.text("3.89  4.29", x - 121, GY - 61.4, 2.8, Col(0x7aff8a), bold: true)
            if dark > 0.3 { lights.append((x - 121, GY - 78, 28)); lights.append((x - 69, GY - 16, 36)) }
            label = false
            top = 94
        case .pool:
            // Rice Ranch RV Park and its new pool: a gate sign, a low block wall, blue water, umbrellas and palms
            palm(x - 64, GY + 1, 40, 21); palm(x + 66, GY + 1, 34, 23)
            camper(0, x - 104, GY - 1, 1, 81, 0.7); camper(2, x + 110, GY - 1, -1, 83, 0.7)
            c.R(x - 46, GY - 30, 1.6, 30, wood); c.R(x + 44.4, GY - 30, 1.6, 30, wood)
            c.RR(x - 48, GY - 40, 96, 12, 2, Col(0x2f6f8a).shade(1 - dark * 0.3))
            g.text("RICE RANCH RV PARK", x, GY - 34, 5, CREAM, bold: true)
            c.RR(x - 20, GY - 27, 40, 7, 1.5, Col(0xf2c418).shade(1 - dark * 0.3))
            g.text("NEW POOL NOW OPEN", x, GY - 23.4, 3, INK, bold: true)
            let deck = Col(0xe8e0d0).shade(1 - dark * 0.45)
            c.R(x - 42, GY - 6, 84, 7, deck)
            c.RR(x - 36, GY - 5, 72, 4.6, 1.6, Col(0x3aa8d8).shade(1 - dark * 0.35))
            for q in 0..<9 {
                let wx0 = x - 33 + Double(q) * 7.6 + sin(NOW * 1.4 + Double(q)) * 1.2
                c.R(wx0, GY - 4 + Double(q % 2) * 1.6, 4, 0.4, Col(0xdff4ff, 0.8))
            }
            if g.phase == .play && dark < 0.6 {
                for q in 0..<3 {
                    let hx = x - 20 + Double(q) * 19 + sin(NOW * 0.7 + Double(q) * 2) * 3
                    c.circ(hx, GY - 4.6, 1.8, [Col(0xc89a7a), Col(0x8a5a3a), Col(0xe0b090)][q]); c.dome(hx, GY - 5.2, 1.9, [Col(0xf4f4f0), Col(0xd9412e), Col(0x3a3a3e)][q])
                }
            }
            c.arcStroke(x + 30, GY - 6, 2.4, PI, PI * 2, 0.5, Col(0xc8c8c4)); c.arcStroke(x + 33, GY - 6, 2.4, PI, PI * 2, 0.5, Col(0xc8c8c4))
            for q in 0..<2 {
                let ux = x - 28 + Double(q) * 54
                c.R(ux - 0.3, GY - 22, 0.6, 16, Col(0x8a8a88))
                c.poly([Col(0xd9412e), Col(0xf2c14e)][q].shade(1 - dark * 0.4), [ux - 10, GY - 20, ux, GY - 25, ux + 10, GY - 20])
                c.poly(Col(0xf4f4f0).shade(1 - dark * 0.4), [ux - 7, GY - 8, ux + 3, GY - 8, ux + 6, GY - 11, ux + 7, GY - 11, ux + 4, GY - 7, ux - 7, GY - 7])
            }
            if dark > 0.35 { c.glow(x, GY - 3, 44, Col(0x6ad0ff, 0.35), Col(0x6ad0ff, 0)) }
            label = false
            top = 46
        case .labyrinth:
            // a walking labyrinth laid out in small rocks on the desert floor, seen at a slant
            let depth = H - GY
            let cy = GY + depth * 0.56
            let stone = Col(0x5e4a3e).shade(1 - dark * 0.45)
            for ring in 1...5 {
                let rx = Double(ring) * 11.5, ry = Double(ring) * depth * 0.085
                let gap = Double(ring % 2) * PI + 0.3
                let steps = ring * 16
                for q in 0..<steps {
                    let a = Double(q) / Double(steps) * PI * 2
                    var da = abs(a - gap); if da > PI { da = PI * 2 - da }
                    if da < 0.34 { continue }
                    let rr = 0.7 + hashN(Double(ring * 97 + q)) * 0.6
                    c.ell(x + cos(a) * rx, cy + sin(a) * ry, rr, rr * 0.7, q % 3 == 0 ? stone.shade(1.25) : stone)
                }
            }
            c.ell(x, cy, 2.2, 1.2, Col(0xe8d8b8).shade(1 - dark * 0.4))
            if near && g.ringProg > 0 {
                // you, walking the rings inward as you hold
                let pp = min(1, g.ringProg)
                let ringF = 5.5 - pp * 5
                let a = pp * PI * 9
                let wx = x + cos(a) * ringF * 11.5, wy = cy + sin(a) * ringF * depth * 0.085
                c.ell(wx, wy + 0.6, 1.6, 0.6, Col(0x000000, 0.25))
                c.seg(wx, wy, wx, wy - 4, 1.4, Col(0x3a4a6a)); c.circ(wx, wy - 5.2, 1.3, Col(0xc89a7a))
            }
            c.R(x - 44, GY - 12, 1, 12, Col(0x6a5a48)); c.RR(x - 52, GY - 19, 17, 8, 1, Col(0xf2e8c8).shade(1 - dark * 0.4))
            g.text("LABYRINTH", x - 43.5, GY - 15, 2.4, INK, bold: true)
            top = 34
        case .magic:
            // the Magic Circle: rigs drawn up behind a windbreak of tarps. All you see from the track is hats
            camper(1, x - 62, GY - 1, 1, 71, 0.8); camper(6, x + 66, GY - 1, -1, 73, 0.8)
            let cloth: [Col] = [Col(0x8a5a9a), Col(0xd8a850), Col(0x3f8f8a), Col(0xc8684a), Col(0x5a7ab0)]
            for q in 0..<9 {
                let px = x - 38 + Double(q) * 8.6
                c.R(px, GY - 16, 0.8, 16, Col(0x6a5a48))
                c.R(px + 0.8, GY - 15, 7.8, 13, cloth[q % 5].shade(1 - dark * 0.45))
            }
            if g.phase == .play && dark < 0.6 {
                for q in 0..<4 {
                    let hx = x - 26 + Double(q) * 16 + sin(NOW * 0.6 + Double(q)) * 1.5
                    c.circ(hx, GY - 17.4, 2.4, [Col(0xc89a7a), Col(0x8a5a3a), Col(0xe0b090), Col(0xa87850)][q])
                    c.ell(hx, GY - 19.4, 4.2, 1.1, [Col(0xd8c8a0), Col(0x4a6a8a), Col(0xb5452f), Col(0xe8e0d0)][q]); c.dome(hx, GY - 19.4, 2.4, [Col(0xd8c8a0), Col(0x4a6a8a), Col(0xb5452f), Col(0xe8e0d0)][q])
                }
            }
            c.R(x - 48, GY - 14, 1, 14, Col(0x6a5a48)); c.RR(x - 58, GY - 22, 21, 9, 1, Col(0xf2e8c8).shade(1 - dark * 0.4))
            g.text(g.foundMagic ? "MAGIC CIRCLE" : "KNOCK FIRST", x - 47.5, GY - 17.6, 2.3, Col(0x6a3a7a), bold: true)
            label = false
            top = 34
        case .watch:
            pastSight(sp.arg, x)
            top = 40
        case .village:
            village(x)
            label = false
            top = 62
        case .river:
            c.seg(x - 4, GY, x - 2, GY - 7, 0.8, Col(0xb8b8b4)); c.seg(x + 4, GY, x + 2, GY - 7, 0.8, Col(0xb8b8b4))
            c.R(x - 4, GY - 7.6, 8, 1.4, Col(0x3a8a6a)); c.R(x - 3.6, GY - 13, 1.2, 6, Col(0x3a8a6a))
            c.RR(x + 7, GY - 5, 7, 5, 1, Col(0xd8412e)); c.R(x + 7, GY - 5, 7, 1.2, Col(0xf4f4f0))
            top = 30
        }
        if sp.kind == .board && g.phase == .play && !g.inRig {
            g.hits.append(Hit(id: 53, x: x - 22, y: GY - 44, w: 44, h: 46))
            if !g.shown.contains("boardUsed") { tapArrow(x, GY - 40, "Tap here to read"); label = false }
        }
        if label && !near {
            let nm = sp.kind == .fire && g.phase == .play ? { let n = g.neighbor(sp.x > 1400 ? 2 : 4).0; return (n + (n.hasSuffix("s") ? "' FIRE" : "'S FIRE")).uppercased() }() : sp.name
            g.text(nm.capitalized, x, GY - top - 2, 3.8, CREAM, bold: true, plate: true)
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
        if w < 36 || h < 18 { return }
        // parapet cap, a painted wainscot, vigas or a cornice, a downspout, the meter and conduit, rooftop gear, and wear
        let hsh = hashN(w * 1.31 + h * 0.77)
        c.R(x - 0.8, y - 1.2, w + 1.6, 1.6, cc.shade(0.76))
        c.R(x, y + h * 0.74, w, 0.5, cc.shade(0.84))
        c.R(x, y + h * 0.74 + 0.5, w, h * 0.26 - 2.1, Col(0x000000, 0.05))
        if hsh < 0.45 {
            var vx = x + 4
            while vx < x + w - 3 { c.circ(vx, y + 3.4, 0.8, Col(0x5a3e28).shade(1 - dark * 0.4)); vx += 7 }
        } else {
            c.R(x, y + 2.6, w, 0.6, cc.shade(1.12))
        }
        c.R(x + w - 2.4, y + 1, 0.9, h - 1.4, cc.shade(0.68))
        c.R(x + 2.2, y + h - 10, 2.6, 3.6, Col(0x8a8f96).shade(1 - dark * 0.4)); c.R(x + 3.2, y + 2, 0.5, h - 12, Col(0x8a8f96, 0.7))
        if hsh > 0.3 {
            let ax = x + w * (0.25 + hsh * 0.4)
            c.RR(ax, y - 6, 8, 4.8, 0.6, Col(0xb8bcc0).shade(1 - dark * 0.45))
            for q in 0..<3 { c.R(ax + 1.2 + Double(q) * 2.2, y - 5, 0.6, 2.8, Col(0x6a6e72)) }
        }
        if hsh > 0.6 { c.R(x + w * 0.12, y - 8, 0.6, 8, Col(0x5a5a5a)); c.dome(x + w * 0.12, y - 8, 2.2, Col(0xd8d8d4).shade(1 - dark * 0.4)) }
        c.seg(x + w * (0.3 + hsh * 0.3), y + h * 0.2, x + w * (0.34 + hsh * 0.3), y + h * 0.36, 0.3, cc.shade(0.8))
        c.RR(x + w * 0.5 - 1, y + 5, 2, 1.6, 0.5, Col(0x3a3634))
        if dark > 0.35 { c.glow(x + w * 0.5, y + 7.4, 7, Col(0xffd68a, 0.45), Col(0xffd68a, 0)) }
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
        if hashN(seed + 1611) < 0.42 {
            // a pair of solar panels on the ground, propped toward the south sun, a cord running back to the rig
            let sxp = x + (hashN(seed + 1612) < 0.5 ? -34.0 : 34.0)
            for k in 0..<2 {
                let px = sxp + Double(k) * 5.4
                c.seg(px + 3.6, b, px + 3.2, b - 3.4, 0.4, Col(0x8a8a88))
                c.poly(Col(0x1e3a5c).shade(1 - dark * 0.4), [px - 1.4, b, px + 3.2, b - 4.2, px + 7.6, b - 4.2, px + 3.2, b])
                c.seg(px + 0.9, b - 2.1, px + 5.4, b - 2.1, 0.25, Col(0xc8d8e8, 0.7))
                c.seg(px + 1.4, b, px + 5.6, b - 4.2, 0.25, Col(0xc8d8e8, 0.7))
            }
            c.curve(sxp, b, (sxp + x) / 2, b + 1.4, x, b, 0.3, Col(0x2a2a2a, 0.7))
        }
        let odd = hashN(seed + 1613)
        if odd < 0.14 {
            // a blue water barrel and jugs
            c.RR(x - 30, b - 5, 3.4, 5, 0.8, Col(0x2e5a9a).shade(1 - dark * 0.5)); c.RR(x - 26, b - 2.4, 1.8, 2.4, 0.4, Col(0x7ab0e0).shade(1 - dark * 0.5))
        } else if odd < 0.28 {
            // a generator humming away
            c.RR(x + 16, b - 3.2, 4.4, 3.2, 0.5, Col(0xc8281e).shade(1 - dark * 0.5)); c.R(x + 16.6, b - 4, 3.2, 0.8, Col(0x2a2a2a))
        } else if odd < 0.4 {
            // a rock-ringed yard with a little cactus garden and a whirligig
            for q in 0..<6 { c.circ(x - 20 + Double(q) * 2.2, b + 0.4, 0.6, Col(0xd8d0c0).shade(1 - dark * 0.5)) }
            c.R(x - 15, b - 4, 0.3, 4, Col(0x8a8a88))
            let wa = NOW * 4 + seed
            c.seg(x - 15 + cos(wa) * 1.6, b - 4 + sin(wa) * 1.6, x - 15 - cos(wa) * 1.6, b - 4 - sin(wa) * 1.6, 0.4, Col(0xf2c14e))
            c.seg(x - 15 - sin(wa) * 1.6, b - 4 + cos(wa) * 1.6, x - 15 + sin(wa) * 1.6, b - 4 - cos(wa) * 1.6, 0.4, Col(0xd9412e))
        } else if odd < 0.5 {
            // a Starlink dish on a short pole
            c.R(x + 12, b - 7, 0.4, 7, Col(0x8a8a88)); c.poly(Col(0xeeeeea).shade(1 - dark * 0.5), [x + 10.4, b - 8.6, x + 13.8, b - 7.8, x + 13.6, b - 6.8, x + 10.2, b - 7.6])
        } else if odd < 0.6 {
            // a clothesline between two poles
            c.R(x + 30, b - 7, 0.3, 7, Col(0x8a8a88)); c.R(x + 42, b - 7, 0.3, 7, Col(0x8a8a88)); c.seg(x + 30, b - 6.8, x + 42, b - 6.8, 0.2, Col(0xeeeeee, 0.7))
            for q in 0..<4 { c.R(x + 31.4 + Double(q) * 2.6, b - 6.8, 1.8, 2.6 + Double(q % 2), [Col(0xd9412e), Col(0xf4f4f0), Col(0x3a6ea5), Col(0xf2c14e)][q].shade(1 - dark * 0.5)) }
        }
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








    /// A tapered limb: wide at the root, narrow at the tip, with a round joint.
    private func taper(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ w0: Double, _ w1: Double, _ col: Col) {
        let dx = x1 - x0, dy = y1 - y0
        let len = max(0.001, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len, ny = dx / len
        let a0 = w0 / 2, a1 = w1 / 2
        c.poly(col, [x0 + nx * a0, y0 + ny * a0, x1 + nx * a1, y1 + ny * a1, x1 - nx * a1, y1 - ny * a1, x0 - nx * a0, y0 - ny * a0])
        c.circ(x1, y1, a1, col)
    }

    /// A crooked, tapering bough that forks as it goes. With ink off it only measures, collecting the twig tips.
    private func bough(_ x: Double, _ y: Double, _ a: Double, _ len: Double, _ w: Double, _ depth: Int, _ seed: Double, _ bark: Col, _ spread: Double, _ droop: Double, _ ink: Bool, _ tips: inout [(Double, Double, Double)]) {
        let a2 = a + (hashN(seed) - 0.5) * 0.7
        let mx = x + cos(a) * len * 0.5
        let my = y + sin(a) * len * 0.5
        let ex = mx + cos(a2) * len * 0.5
        let ey = my + sin(a2) * len * 0.5
        if ink {
            taper(x, y, mx, my, w, w * 0.84, bark)
            taper(mx, my, ex, ey, w * 0.84, w * 0.7, bark)
        }
        if depth == 0 { tips.append((ex, ey, a2)); return }
        let n = hashN(seed + 1) < 0.3 ? 3 : 2
        for k in 0..<n {
            let d = Double(k)
            let f = d / Double(n - 1) - 0.5
            var na: Double = a2 + f * spread * 2 + (hashN(seed + 2 + d) - 0.5) * 0.35
            na += na > -PI / 2 ? droop : -droop
            na = max(-PI - 0.3, min(0.3, na))
            let s2 = abs(seed * 1.7 + d * 13.1 + 3).truncatingRemainder(dividingBy: 9973)
            let nl = len * (0.66 + hashN(seed + 5 + d) * 0.16)
            bough(ex, ey, na, nl, w * 0.7, depth - 1, s2, bark, spread, droop, ink, &tips)
        }
    }


    /// Foothill palo verde: a short green trunk forking low into smooth green limbs, and a wide broom of fine green twigs. Nearly leafless in winter.
    private func paloverde(_ x: Double, _ base: Double, _ seed: Double, _ s: Double = 1) {
        if x < -50 * s || x > W + 50 * s { return }
        let k = 1 - dark * 0.45
        let h = 44 * s * (0.85 + hashN(seed + 1) * 0.3)
        let bark = Col(0x7fa35c).shade(k)
        let n = 3 + Int(hashN(seed + 3) * 2)
        let y0 = base - h * 0.1
        var tips: [(Double, Double, Double)] = []
        for i in 0..<n {
            let f = Double(i) / Double(n - 1) - 0.5
            bough(x + f * 1.5 * s, y0, -PI / 2 + f * 1.25, h * 0.24, 2.4 * s, 3, seed + Double(i) * 7.7, bark, 0.42, 0, false, &tips)
        }
        let haze = Col(0xb9c860, 0.13).shade(k)
        for t in tips { c.circ(t.0, t.1 - h * 0.03, h * 0.085, haze) }
        taper(x, base, x, y0, 3.4 * s, 2.8 * s, bark.shade(0.88))
        c.R(x - 1.7 * s, base - 0.6, 3.4 * s, 1, bark.shade(0.7))
        var unused: [(Double, Double, Double)] = []
        for i in 0..<n {
            let f = Double(i) / Double(n - 1) - 0.5
            bough(x + f * 1.5 * s, y0, -PI / 2 + f * 1.25, h * 0.24, 2.4 * s, 3, seed + Double(i) * 7.7, bark, 0.42, 0, true, &unused)
        }
        let twig = Col(0x9dba62, 0.9).shade(k)
        let nt = s > 0.7 ? 6 : 3
        let tw = 0.32 * s + 0.1
        for (i, t) in tips.enumerated() {
            let d = Double(i)
            for q in 0..<nt {
                let e = Double(q)
                let a: Double = t.2 + (e / Double(nt - 1) - 0.5) * 1.5 + (hashN(seed + d * 5 + e) - 0.5) * 0.3
                let L = h * (0.07 + hashN(seed + d * 3 + e + 9) * 0.05)
                c.seg(t.0, t.1, t.0 + cos(a) * L, t.1 + sin(a) * L, tw, twig)
            }
        }
    }

    /// Velvet mesquite: crooked near-black trunks leaning apart, a low wide crown, thin olive leaves that hang and sway.
    private func mesquite(_ x: Double, _ base: Double, _ seed: Double, _ s: Double = 1) {
        if x < -55 * s || x > W + 55 * s { return }
        let k = 1 - dark * 0.45
        let h = 38 * s * (0.85 + hashN(seed + 1) * 0.3)
        let bark = Col(0x3e3026).shade(1 - dark * 0.35)
        let n = 2 + Int(hashN(seed + 4) * 2)
        var tips: [(Double, Double, Double)] = []
        var unused: [(Double, Double, Double)] = []
        for pass in 0..<2 {
            if pass == 1 {
                let back = Col(0x5f6f3e, 0.5).shade(k)
                for t in tips { c.ell(t.0, t.1 + h * 0.01, h * 0.11, h * 0.06, back) }
            }
            for i in 0..<n {
                let d = Double(i)
                let f = d / Double(n - 1) - 0.5
                let a: Double = -PI / 2 + f * 1.3 + (hashN(seed + d) - 0.5) * 0.2
                if pass == 0 { bough(x + f * 5 * s, base, a, h * 0.27, 3 * s, 4, seed + d * 5.3, bark, 0.5, 0.12, false, &tips) }
                else { bough(x + f * 5 * s, base, a, h * 0.27, 3 * s, 4, seed + d * 5.3, bark, 0.5, 0.12, true, &unused) }
            }
        }
        let leaf = Col(0x76873f, 0.6).shade(k)
        let leaf2 = Col(0x8e9c52, 0.6).shade(k)
        let lw = 0.5 * s + 0.1
        c.roundCaps(true)
        for (i, t) in tips.enumerated() {
            let d = Double(i)
            c.ell(t.0 + (hashN(seed + d) - 0.5) * h * 0.06, t.1 - h * 0.02, h * 0.1, h * 0.045, i % 2 == 0 ? leaf2 : leaf)
            for q in 0..<3 {
                let e = Double(q)
                let lx = t.0 + (hashN(seed + d * 4 + e + 20) - 0.5) * h * 0.2
                let ly = t.1 + hashN(seed + d * 4 + e + 40) * h * 0.03
                let sway = sin(NOW * 1.1 + d + e) * 0.3 * s
                let drop = h * (0.05 + hashN(seed + d * 2 + e) * 0.05)
                c.seg(lx, ly, lx + (hashN(seed + d + e) - 0.5) * 1.5 * s + sway, ly + drop, lw, q % 2 == 0 ? leaf2 : leaf)
            }
        }
        c.roundCaps(false)
    }

    /// Desert ironwood: a stout grey trunk, heavy grey limbs, one dense blue-grey evergreen crown lit from above.
    private func ironwood(_ x: Double, _ base: Double, _ seed: Double, _ s: Double = 1) {
        if x < -55 * s || x > W + 55 * s { return }
        let k = 1 - dark * 0.45
        let h = 46 * s * (0.85 + hashN(seed + 1) * 0.3)
        let bark = Col(0x857e74).shade(k)
        let y0 = base - h * 0.16
        var tips: [(Double, Double, Double)] = []
        var unused: [(Double, Double, Double)] = []
        for i in 0..<3 {
            let f = Double(i) - 1
            bough(x + f * 1.2 * s, y0, -PI / 2 + f * 0.55, h * 0.2, 3 * s, 3, seed + Double(i) * 6.1, bark, 0.36, 0, false, &tips)
        }
        taper(x, base, x, base - h * 0.17, 4.6 * s, 3.6 * s, bark.shade(0.85))
        for i in 0..<3 {
            let f = Double(i) - 1
            bough(x + f * 1.2 * s, y0, -PI / 2 + f * 0.55, h * 0.2, 3 * s, 3, seed + Double(i) * 6.1, bark, 0.36, 0, true, &unused)
        }
        let under = Col(0x4a5a52).shade(k)
        let mid = Col(0x66786c).shade(k)
        let top = Col(0x84968a).shade(k)
        let r = h * 0.11
        var mx = 0.0, my = 0.0
        for t in tips { mx += t.0; my += t.1 }
        mx /= Double(max(1, tips.count)); my /= Double(max(1, tips.count))
        c.ell(mx, my + r * 0.3, h * 0.3, h * 0.17, under)
        for t in tips { c.circ(t.0, t.1 + r * 0.35, r, under) }
        for t in tips { c.circ(t.0 + (mx - t.0) * 0.45 - r * 0.2, t.1 + (my - t.1) * 0.45 - r * 0.2, r * 0.85, mid) }
        for (i, t) in tips.enumerated() { c.circ(t.0 - r * 0.2 + (hashN(seed + Double(i)) - 0.5) * r * 0.5, t.1 - r * 0.15, r * 0.8, mid) }
        for (i, t) in tips.enumerated() where hashN(seed + Double(i) + 50) < 0.6 { c.circ(t.0 - r * 0.35, t.1 - r * 0.5, r * 0.42, top) }
    }

    /// Fremont cottonwood by the river: a pale trunk, big bare limbs in winter, the last gold leaves hanging on.
    private func cottonwood(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -60 || x > W + 60 { return }
        let k = 1 - dark * 0.45
        let h = 58 + hashN(seed + 7) * 20
        let bark = Col(0xa39686).shade(k)
        var tips: [(Double, Double, Double)] = []
        taper(x, base, x + 1, base - h * 0.3, 5.5, 4.2, bark.shade(0.9))
        for i in 0..<3 {
            let f = Double(i) - 1
            bough(x + 1, base - h * 0.3, -PI / 2 + f * 0.6, h * 0.2, 3.4, 3, seed + Double(i) * 4.1, bark, 0.4, 0, true, &tips)
        }
        let gold = Col(0xd9b23c, 0.8).shade(k)
        let twig = bark.shade(1.1)
        for (i, t) in tips.enumerated() {
            let d = Double(i)
            for q in 0..<4 {
                let a = t.2 + (Double(q) / 3 - 0.5) * 1.4
                c.seg(t.0, t.1, t.0 + cos(a) * h * 0.06, t.1 + sin(a) * h * 0.06, 0.3, twig)
            }
            if hashN(seed + d * 3) < 0.45 {
                for q in 0..<3 {
                    let e = Double(q)
                    c.circ(t.0 + (hashN(seed + d + e) - 0.5) * 5, t.1 + (hashN(seed + d + e + 9) - 0.5) * 5, 0.9, gold)
                }
            }
        }
    }

    /// Beavertail prickly pear: a low clump, barely ankle high, of blue-grey pads each about the size of a hand. No flowers till spring.
    private func beavertail(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -16 || x > W + 16 { return }
        let lit = clampD(1 - dark, 0.3, 1)
        let padC = Col.mix(Col(0x7f9c98), Col(0x8c7f9c), hashN(seed + 4) * 0.5).shade(0.55 + 0.45 * lit)
        let n = 4 + Int(hashN(seed) * 4)
        let wid = 2.2 + hashN(seed + 7) * 2.2
        var pads: [(Double, Double, Double, Double)] = []
        for i in 0..<n {
            let d = Double(i)
            let f = d / Double(n - 1) - 0.5
            let pa: Double = f * 1.7 + (hashN(seed + d + 1) - 0.5) * 0.5
            let pl: Double = 2.9 + hashN(seed + d + 2) * 0.9
            pads.append((x + f * wid * 2, base + 0.4, pa, pl))
        }
        let ground = pads
        for (i, p) in ground.enumerated() where hashN(seed + Double(i) + 11) < 0.7 {
            let qx: Double = p.0 + sin(p.2) * p.3 * 0.9
            let qy: Double = p.1 - cos(p.2) * p.3 * 0.9
            let qa: Double = p.2 + (hashN(seed + Double(i) + 12) - 0.5) * 1.2
            pads.append((qx, qy, qa, p.3 * 0.85))
        }
        c.ell(x, base + 0.6, wid + 2, 0.9, Col(0x000000, 0.12))
        for (i, p) in pads.enumerated() {
            pad(p.0, p.1, p.2, p.3, padC.shade(0.78), false)
            pad(p.0 - 0.12, p.1 - 0.1, p.2, p.3 * 0.9, padC.shade(0.95 + Double(i % 3) * 0.05), true)
        }
    }
    /// One pad: egg-shaped, narrow at the joint, with a few red-brown glochid dots.
    private func pad(_ x: Double, _ y: Double, _ a: Double, _ L: Double, _ col: Col, _ dots: Bool) {
        let ca = cos(a), sa = sin(a)
        var right: [Double] = []
        var left: [Double] = []
        for i in 0...8 {
            let t = Double(i) / 8
            let sn: Double = max(0, sin(PI * (0.12 + 0.88 * t)))
            let hw: Double = i == 8 ? 0 : L * 0.42 * pow(sn, 0.8) * (0.55 + 0.45 * t)
            let py: Double = -t * L
            right += [x + hw * ca - py * sa, y + hw * sa + py * ca]
            left = [x - hw * ca - py * sa, y - hw * sa + py * ca] + left
        }
        c.poly(col, right + left)
        if !dots { return }
        let gl = Col(0x6a3e2e, 0.6)
        for r in 0..<2 {
            for q in 0..<2 {
                let px: Double = (Double(q) - 0.5) * L * 0.3
                let py: Double = -L * (0.38 + Double(r) * 0.26)
                c.circ(x + px * ca - py * sa, y + px * sa + py * ca, 0.14, gl)
            }
        }
    }


    /// Creosote: an open vase of thin grey stems with small dark olive leaves toward the tips.
    private func creosote(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -24 || x > W + 24 { return }
        let k = 1 - dark * 0.35
        let stem = Col(0x6e6658).shade(k)
        let leaf = Col(0x55682f).shade(k)
        let leaf2 = Col(0x6c7d3a).shade(k)
        let n = 11 + Int(hashN(seed) * 5)
        for i in 0..<n {
            let f = Double(i) / Double(n - 1) - 0.5
            let m = seed + Double(i) * 3.1
            let h = 9 + hashN(m + 1) * 8
            let sx: Double = x + f * 3
            let ex: Double = x + f * h * 1.5 + (hashN(m) - 0.5) * 3
            let ey: Double = base - h * (1 - abs(f) * 0.5)
            c.curve(sx, base, x + f * 5, base - h * 0.5, ex, ey, 0.4, stem)
            for q in 0..<5 {
                let e = Double(q)
                let t = 0.45 + e * 0.13
                let lx: Double = sx + (ex - sx) * t + (hashN(m + e) - 0.5) * 2.4
                let ly: Double = base + (ey - base) * t + (hashN(m + e + 7) - 0.5) * 2
                c.circ(lx, ly, 0.75 + hashN(m + e + 3) * 0.5, (i + q) % 2 == 0 ? leaf2 : leaf)
            }
        }
    }
    /// Brittlebush: a low silver-grey mound.
    private func brittlebush(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -12 || x > W + 12 { return }
        let k = 1 - dark * 0.35
        let r = 4 + hashN(seed) * 2.5
        for i in 0..<9 {
            let a = PI + Double(i) / 8 * PI
            c.circ(x + cos(a) * r * 0.75, base - 1 + sin(a) * r * 0.55, r * 0.42, (i % 2 == 0 ? Col(0xb4bca6) : Col(0x9fa890)).shade(k))
        }
        c.ell(x, base - 0.6, r * 0.9, r * 0.4, Col(0xa9b29a).shade(k))
    }
    /// Ocotillo: a spray of long thorny grey-green canes. Bare in winter; no flowers till spring.
    private func ocotillo(_ x: Double, _ base: Double, _ seed: Double) {
        if x < -30 || x > W + 30 { return }
        let k = 1 - dark * 0.35
        let c1 = Col(0x7c7f62).shade(k)
        let c2 = Col(0x5f6a4c).shade(k)
        let n = 9 + Int(hashN(seed) * 5)
        c.roundCaps(true)
        for i in 0..<n {
            let f = Double(i) / Double(n - 1) - 0.5
            let m = seed + Double(i) * 5.7
            let h = 24 + hashN(m + 1) * 16
            let lean: Double = f * h * 0.75 + (hashN(m) - 0.5) * 3
            let wob: Double = (hashN(m + 3) - 0.5) * 5
            let sx: Double = x + f * 2.4
            c.curve(sx, base, sx + lean * 0.2 + wob, base - h * 0.55, x + lean, base - h, 0.75, i % 2 == 0 ? c2 : c1)
        }
        c.roundCaps(false)
    }
    /// Compass barrel: a ribbed column leaning toward the sun, red spines down the ribs, a ring of yellow fruit on top.
    private func barrel(_ x: Double, _ base: Double, _ s: Double, _ seed: Double) {
        if x < -20 || x > W + 20 { return }
        let k = 1 - dark * 0.35
        let h = (7 + hashN(seed + 1) * 5) * s
        let w = 4.6 * s
        let lean = (hashN(seed + 2) - 0.3) * 1.4 * s
        let body = Col(0x5d8454).shade(k)
        let tx = x + lean * 0.5
        let ty = base - h + w * 0.3
        c.poly(body, [x - w / 2, base, tx - w / 2, ty, tx + w / 2, ty, x + w / 2, base])
        c.ell(tx, ty, w / 2, w * 0.36, body)
        c.ell(x, base, w / 2, 0.8, body.shade(0.8))
        let spine = Col(0xc8525a, 0.75).shade(k)
        for i in 0..<5 {
            let fx = (Double(i) / 4 - 0.5) * w * 0.82
            c.seg(x + fx, base - 0.4, tx + fx, base - h + w * 0.18, 0.35 * s, spine)
        }
        c.ell(tx, base - h + w * 0.1, w * 0.36, w * 0.16, Col(0xd8a868).shade(k))
        for i in 0..<3 { c.circ(tx + (Double(i) - 1) * w * 0.2, base - h + w * 0.02, 0.5 * s, Col(0xe8c83a).shade(k)) }
    }
    /// California fan palm: a stout ringed trunk, a skirt of dead thatch, a round crown of fan leaves.
    private func palm(_ x: Double, _ base: Double, _ h: Double, _ seed: Double) {
        if x < -40 || x > W + 40 { return }
        let k = 1 - dark * 0.4
        let lean = (hashN(seed + 3) - 0.5) * 6
        let trunk = Col(0x7a6450).shade(k)
        let tx = x + lean
        let ty = base - h
        taper(x, base, tx, ty + 8, 4.2, 3.2, trunk)
        let rings = Int(h / 5)
        for i in 0..<rings {
            let d = Double(i)
            c.R(x + lean * (d * 5 / h) - 2, base - 3 - d * 5, 4, 0.5, trunk.shade(0.75))
        }
        let thatch = Col(0xa8946a).shade(k)
        c.poly(thatch, [tx - 2.4, ty + 1, tx + 2.4, ty + 1, tx + 4.2, ty + 12, tx + 2, ty + 15, tx - 2, ty + 15, tx - 4.2, ty + 12])
        for i in 0..<6 {
            let d = Double(i)
            c.seg(tx - 3.4 + d * 1.36, ty + 4, tx - 3.8 + d * 1.5, ty + 14, 0.35, thatch.shade(0.75))
        }
        let leaf = Col(0x55803e).shade(k)
        let leaf2 = Col(0x6a9448).shade(k)
        for i in 0..<11 {
            let d = Double(i)
            let a: Double = -PI * 1.05 + d * PI * 1.1 / 10 + sin(NOW * 1.2 + seed + d) * 0.03
            let r = 9 + hashN(seed + d) * 3
            let fx: Double = tx + cos(a) * r
            let fy: Double = ty + sin(a) * r * 0.8 + (sin(a) > -0.4 ? 2.5 : 0)
            c.seg(tx, ty, fx, fy, 0.6, leaf.shade(0.8))
            var pts: [Double] = [tx + (fx - tx) * 0.5, ty + (fy - ty) * 0.5]
            for q in 0..<7 {
                let b = a + (Double(q) / 6 - 0.5) * 1.5
                pts.append(fx + cos(b) * 5.5); pts.append(fy + sin(b) * 5.5)
            }
            c.poly(i % 2 == 0 ? leaf2 : leaf, pts)
        }
    }

    /// Palm Canyon in the Kofa: a jagged volcanic wall with one narrow shadowed slot, the palms green in its throat.
    private func canyonWall(_ cx: Double) {
        let k = 1 - dark * 0.6
        let wall = Col(0x8a6450).shade(k)
        c.poly(wall, [cx - 330, GY + 1, cx - 300, GY - 48, cx - 250, GY - 62, cx - 200, GY - 54, cx - 150, GY - 70, cx - 90, GY - 60, cx - 44, GY - 74, cx - 27, GY - 67, cx - 18, GY - 57, cx - 9, GY - 70, cx + 40, GY - 64, cx + 90, GY - 72, cx + 150, GY - 56, cx + 210, GY - 66, cx + 270, GY - 50, cx + 340, GY + 1])
        // lit and shaded faces, and the bedding in the rock
        c.poly(wall.shade(1.1), [cx - 150, GY - 70, cx - 90, GY - 60, cx - 110, GY - 20, cx - 170, GY - 24])
        c.poly(wall.shade(0.88), [cx + 90, GY - 72, cx + 150, GY - 56, cx + 130, GY - 18, cx + 70, GY - 22])
        for i in 0..<9 {
            let d = Double(i) + 2000
            c.R(cx - 300 + hashN(d) * 600, GY - 52 + hashN(d + 1) * 30, 14 + hashN(d + 2) * 16, 0.6, wall.shade(0.84))
        }
        // talus at the foot of the wall
        c.poly(wall.shade(1.14), [cx - 330, GY + 1, cx - 290, GY - 14, cx - 120, GY - 18, cx - 40, GY - 12, cx + 60, GY - 18, cx + 240, GY - 13, cx + 340, GY + 1])
        // the slot
        let shadow = Col(0x3e2c26).shade(1 - dark * 0.5)
        c.poly(shadow, [cx - 27, GY - 67, cx - 18, GY - 57, cx - 9, GY - 70, cx - 13, GY - 34, cx - 17, GY - 15, cx - 22, GY - 34])
        c.poly(shadow.shade(1.35), [cx - 18, GY - 57, cx - 9, GY - 70, cx - 13, GY - 34, cx - 17, GY - 15])
        for i in 0..<5 {
            let d = Double(i)
            let px = cx - 21 + d * 1.9
            let py = GY - 30 - Double(i % 2) * 5 - d
            c.R(px - 0.35, py, 0.7, 6, Col(0x6a5040).shade(k))
            c.R(px - 0.8, py, 1.6, 2.2, Col(0xa8946a).shade(k))
            c.dome(px, py + 0.4, 2.3, Col(0x5a8a40).shade(1 - dark * 0.5))
        }
        // the wash spilling out of the canyon mouth
        c.poly(Col(0xe2c898, 0.55).shade(k), [cx - 19, GY - 15, cx - 15, GY - 15, cx + 2, GY + 1, cx - 40, GY + 1])
    }

    /// A mountain range with some form to it: shaded faces falling away from every peak, a ridge line, and haze where it meets the desert floor.
    private func massif(_ pts: [Double], _ col: Col) {
        c.poly(col, pts)
        let n = pts.count / 2
        if n < 3 { return }
        for i in 1..<(n - 1) {
            let px = pts[i * 2], py = pts[i * 2 + 1]
            let lx = pts[i * 2 - 2], ly = pts[i * 2 - 1]
            let rx = pts[i * 2 + 2], ry = pts[i * 2 + 3]
            if py >= ly || py >= ry { continue }
            // the shaded side, with a spur running down from the peak
            c.poly(col.shade(0.84), [px, py, rx, ry, rx, GY + 1, px + (rx - px) * 0.3, GY + 1])
            c.poly(col.shade(1.1), [px, py, px - (px - lx) * 0.45, py + (ly - py) * 0.5, px - (px - lx) * 0.2, GY + 1, px + (rx - px) * 0.3, GY + 1])
            c.seg(px, py, px + (rx - px) * 0.18, py + (GY - py) * 0.55, 0.5, col.shade(0.7))
        }
        var lo = pts[0], hi = pts[0]
        for i in 0..<n { lo = min(lo, pts[i * 2]); hi = max(hi, pts[i * 2]) }
        // rock texture: gullies running down from the crest, ledges and banding across the faces, scree at the foot
        func crest(_ x: Double) -> Double {
            for i in 0..<(n - 1) {
                let ax = pts[i * 2], bx = pts[i * 2 + 2]
                if x >= ax && x <= bx && bx > ax { return pts[i * 2 + 1] + (pts[i * 2 + 3] - pts[i * 2 + 1]) * (x - ax) / (bx - ax) }
            }
            return GY
        }
        if hi - lo > 40 && hi > 0 && lo < W {
            let cnt = Int((hi - lo) / 9)
            for k in 0..<cnt {
                let d = Double(k)
                let x = lo + (d + hashN(d + lo * 0.01 + 8600)) * (hi - lo) / Double(cnt)
                if x < -10 || x > W + 10 { continue }
                let top = crest(x)
                let room = GY - top
                if room < 6 { continue }
                let hk = hashN(d * 1.9 + lo * 0.013 + 8610)
                if hk < 0.4 {
                    let lean = (hashN(d + 8620) - 0.5) * 8
                    c.seg(x, top + 1.5, x + lean, top + room * (0.35 + hk), 0.4, col.shade(0.76))
                    c.seg(x + 0.8, top + 2, x + lean + 0.8, top + room * (0.3 + hk), 0.25, col.shade(1.16))
                } else if hk < 0.75 {
                    let y = top + room * (0.2 + hashN(d + 8630) * 0.65)
                    let len = 5 + hashN(d + 8640) * 12
                    c.seg(x - len / 2, y, x + len / 2, y + (hashN(d + 8650) - 0.5) * 1.6, 0.5, col.shade(0.8))
                    c.seg(x - len / 2, y - 0.6, x + len / 2, y - 0.6 + (hashN(d + 8650) - 0.5) * 1.6, 0.25, col.shade(1.18))
                } else {
                    let y = GY - hashN(d + 8660) * min(room * 0.3, 8)
                    let r = 1 + hashN(d + 8670) * 2.2
                    c.poly(col.shade(0.72), [x - r, y + r * 0.5, x - r * 0.5, y - r * 0.6, x + r * 0.5, y - r * 0.7, x + r, y + r * 0.5])
                    c.poly(col.shade(1.2), [x - r * 0.5, y - r * 0.6, x + r * 0.5, y - r * 0.7, x, y])
                }
            }
        }
        let haze = Col(0xe6c8a0).shade(1 - dark * 0.6)
        c.vfill(lo, GY - 22, hi - lo, 23, [(0, haze.alpha(0)), (1, haze.alpha(0.42))])
    }

    /// Teddy bear cholla: a dark trunk carrying a rounded, fuzzy head of short stubby joints, pale straw on top and
    /// darker underneath, glowing where the sun catches the spines. Dropped joints litter the ground around it.
    private func cholla(_ x: Double, _ base: Double, _ s: Double, _ seed: Double) {
        if x < -30 * s || x > W + 30 * s { return }
        let lit = clampD(1 - dark, 0.3, 1)
        let dead = Col(0x2a201a).shade(1 - dark * 0.3)
        for i in 0..<6 {
            let d = Double(i)
            c.ell(x + (hashN(seed + d + 60) - 0.5) * 18 * s, base + 0.5, 1.2 * s, 0.7 * s, Col(0xa89a62).shade(0.5 + 0.5 * lit))
        }
        let th = (7 + hashN(seed + 1) * 4) * s
        taper(x, base, x + 0.3 * s, base - th, 2.4 * s, 1.9 * s, dead)
        let cx = x + 0.3 * s
        let cy = base - th - 3.2 * s
        let n = 16 + Int(hashN(seed + 2) * 8)
        var js: [(Double, Double, Double, Double, Double)] = []
        for i in 0..<n {
            let d = Double(i)
            let a = hashN(seed + d * 1.7 + 10) * PI * 2
            let rr = hashN(seed + d * 2.3 + 11).squareRoot()
            let ox = cos(a) * rr * 5.2 * s
            let oy = sin(a) * rr * 4.2 * s
            let dir = atan2(oy - 0.5 * s, ox)
            let L = (1.5 + hashN(seed + d + 30)) * s
            js.append((cx + ox, cy + oy, cx + ox + cos(dir) * L, cy + oy + sin(dir) * L * 0.9, oy))
        }
        js.sort { $0.4 > $1.4 }
        c.roundCaps(true)
        let halo = Col(0xfff3c4, 0.16 * lit)
        for j in js { c.seg(j.0, j.1, j.2, j.3, 3.3 * s, halo) }
        for j in js {
            let t = clampD((j.4 / (4.2 * s) + 1) / 2, 0, 1)
            c.seg(j.0, j.1, j.2, j.3, 2.1 * s, Col.mix(Col(0xd9d08c), Col(0x7c7440), t).shade(0.5 + 0.5 * lit))
        }
        let spine = Col(0xf6ebb8, 0.7 * lit)
        for (i, j) in js.enumerated() {
            let t = clampD((j.4 / (4.2 * s) + 1) / 2, 0, 1)
            if t < 0.75 { c.seg(j.0 - 0.3 * s, j.1 - 0.35 * s, j.2 - 0.3 * s, j.3 - 0.35 * s, 0.8 * s, Col(0xfffbe0, 0.6 * (1 - t) * lit)) }
            let mx = (j.0 + j.2) / 2, my = (j.1 + j.3) / 2
            for q in 0..<5 {
                let a = hashN(seed + Double(i * 5 + q) + 70) * PI * 2
                c.seg(mx + cos(a) * s, my + sin(a) * s, mx + cos(a) * 1.9 * s, my + sin(a) * 1.9 * s, 0.22 * s, spine)
            }
        }
        c.roundCaps(false)
    }

    /// One saguaro column: a little fuller through the middle, pleated with alternating shadowed and sunlit ribs.
    private func sagColumn(_ x: Double, _ y0: Double, _ y1: Double, _ w: Double, _ body: Col, _ detail: Bool, _ flat: Bool) {
        let top = y1 + w / 2
        var right: [Double] = []
        var left: [Double] = []
        for i in 0...8 {
            let t = Double(i) / 8
            let ww = w / 2 * (0.9 + 0.14 * sin(PI * t))
            let yy = y0 + (top - y0) * t
            right += [x + ww, yy]
            left = [x - ww, yy] + left
        }
        c.poly(body, right + left)
        c.ell(x, top, w / 2 * 0.9, w / 2, body)
        if !flat { c.circ(x, y0, w / 2 * 0.9, body) }
        if detail {
            let nr = max(3, Int(w / 1.1))
            for i in 0..<nr {
                let rx = x - w * 0.45 + w * 0.9 * (Double(i) + 0.5) / Double(nr)
                c.R(rx - 0.18, y1 + w * 0.4, 0.36, y0 - y1 - w * 0.4, i % 2 == 0 ? SAGD.alpha(0.6) : Col(0xa9c88a, 0.35))
            }
            c.R(x - w * 0.42, y1 + w * 0.5, 0.5, y0 - y1 - w * 0.5, Col(0xe4f0bc, 0.4))
            c.R(x + w * 0.3, y1 + w * 0.5, w * 0.14, y0 - y1 - w * 0.5, Col(0x24402a, 0.25))
        }
    }
    /// Saguaro: young ones are plain spears; old ones grow arms at different heights, most curving up, now and then one drooping.
    /// A corky brown base, and sometimes a woodpecker hole.
    private func saguaro(_ x: Double, _ base: Double, _ h: Double, _ seed: Double, _ col: Col, _ detail: Bool) {
        if x < -50 || x > W + 50 { return }
        let w = max(1.6, h < 70 ? min(7.5, h * 0.13 + 1.2) : h * 0.15)
        let body = detail ? col.shade(1 - dark * 0.35) : col
        let most = h < 44 ? 2.6 : 4.6
        let arms = h < 30 ? 0 : Int(hashN(seed + 11) * most)
        let flip = Int(hashN(seed + 5) * 2)
        c.roundCaps(true)
        for i in 0..<arms {
            let n = seed + Double(i) * 17
            let side = (i + flip) % 2 == 0 ? -1.0 : 1.0
            let ay = base - h * (0.34 + hashN(n + 2) * 0.28)
            let reach = w * (1.2 + hashN(n + 3) * 0.7)
            let ah = h * (0.14 + hashN(n + 4) * 0.26)
            let aw = w * (0.58 + hashN(n + 6) * 0.14)
            let ax = x + side * reach
            if hashN(n + 7) < 0.12 {
                c.curve(x, ay, ax, ay, ax + side * reach * 0.3, ay + reach * 0.7, aw, body)
            } else {
                c.curve(x, ay, ax, ay + reach * 0.15, ax, ay - reach * 0.9, aw, body)
                sagColumn(ax, ay - reach * 0.8, ay - reach * 0.9 - ah, aw, body, detail, false)
            }
        }
        c.roundCaps(false)
        sagColumn(x, base + 1, base - h, w, body, detail, true)
        if detail {
            c.poly(Col(0x6a5a3e, 0.75).shade(1 - dark * 0.35), [x - w * 0.46, base + 1, x - w * 0.46, base - h * 0.07, x - w * 0.2, base - h * 0.1, x + w * 0.1, base - h * 0.06, x + w * 0.46, base - h * 0.09, x + w * 0.46, base + 1])
            if h > 40 && hashN(seed + 21) < 0.5 { c.ell(x + w * 0.1, base - h * 0.7, 0.7, 0.9, Col(0x1a241a)) }
        }
    }

    /// A bouncing arrow that says what to do, for the first time you meet something you can use.
    private func tapArrow(_ x: Double, _ y: Double, _ words: String) {
        let b = abs(sin(NOW * 4)) * 4
        c.R(x - 1.4, y - 14 - b, 2.8, 6.6, GOLD)
        c.poly(GOLD, [x - 4.4, y - 8 - b, x + 4.4, y - 8 - b, x, y - 1 - b])
        g.text(words, x, y - 19 - b, 4.8, GOLD, bold: true, plate: true)
    }

    /// What stops you at each end of a place: boulders, a wire fence, a closed road or a work site.
    private func edgeBlock(_ x: Double, _ kind: Int, _ flipX: Double) {
        if x < -60 || x > W + 60 { return }
        let k = 1 - dark * 0.45
        switch kind {
        case 0:
            let rk = Col(0x7a6250).shade(k)
            c.ell(x, GY - 5, 12, 9, rk); c.ell(x + flipX * 13, GY - 3, 9, 6, rk.shade(0.88)); c.ell(x - flipX * 10, GY - 2, 7, 4.6, rk.shade(1.1))
            c.ell(x - 3, GY - 9, 7, 3.4, rk.shade(1.2)); c.ell(x + flipX * 20, GY - 1, 4, 2.6, rk.shade(0.8))
        case 1:
            let post = Col(0x6a5a48).shade(k)
            for i in 0..<5 { let px = x - 24 + Double(i) * 12; c.R(px, GY - 13, 1.2, 14, post) }
            for i in 0..<3 { c.R(x - 24, GY - 11 + Double(i) * 3.6, 49, 0.4, Col(0x8a8a88)) }
            c.RR(x - 11, GY - 22, 22, 9, 1, Col(0xf4f1ea).shade(k))
            g.text("PRIVATE LAND", x, GY - 19.4, 2.4, REDC, bold: true)
            g.text("NO ENTRY", x, GY - 16, 2.2, INK)
        case 2:
            for i in 0..<2 {
                let bx = x - 12 + Double(i) * 24
                c.seg(bx - 4, GY, bx, GY - 11, 0.9, Col(0x8a8a88)); c.seg(bx + 4, GY, bx, GY - 11, 0.9, Col(0x8a8a88))
            }
            for r in 0..<2 {
                let by = GY - 12 + Double(r) * 5
                c.R(x - 18, by, 36, 3, Col(0xf4f1ea).shade(k))
                for q in 0..<6 { c.poly(Col(0xe2742e).shade(k), [x - 18 + Double(q) * 6, by + 3, x - 15 + Double(q) * 6, by + 3, x - 12 + Double(q) * 6, by, x - 15 + Double(q) * 6, by]) }
            }
            c.RR(x - 12, GY - 23, 24, 8, 1, Col(0xe2742e).shade(k))
            g.text("ROAD CLOSED", x, GY - 19, 2.6, INK, bold: true)
            for i in 0..<2 { let cx = x + flipX * (24 + Double(i) * 8); c.poly(Col(0xe2742e).shade(k), [cx - 2, GY, cx + 2, GY, cx, GY - 6]); c.R(cx - 1.4, GY - 3.4, 2.8, 1, Col(0xf4f1ea)) }
        default:
            // a work site: a dirt pile, barrels and a small excavator
            c.poly(Col(0xb48a5a).shade(k), [x - 26, GY, x - 12, GY - 12, x + 2, GY])
            let yel = Col(0xe8b020).shade(k)
            c.R(x + 4, GY - 4, 20, 4, Col(0x2a2624)); c.RR(x + 8, GY - 13, 12, 9, 1, yel); c.RR(x + 14, GY - 12, 5, 4, 0.6, GLASS)
            c.seg(x + 9, GY - 11, x - 2, GY - 20, 2, yel); c.seg(x - 2, GY - 20, x - 8, GY - 10, 1.6, yel)
            c.poly(Col(0x3a3634), [x - 10, GY - 10, x - 5, GY - 10, x - 8, GY - 6])
            for i in 0..<2 { let bx = x + flipX * 34 + Double(i) * 6; c.RR(bx - 2, GY - 7, 4, 7, 1, Col(0xe2742e).shade(k)); c.R(bx - 2, GY - 5, 4, 1, Col(0xf4f1ea)); c.R(bx - 2, GY - 2.6, 4, 1, Col(0xf4f1ea)) }
        }
    }

    /// Life on the hills behind: scattered small rocks, a few outcrops, a dirt track winding across, and far-off campers.
    private func hillDetail(_ par: Double, _ seed: Double, _ base: Double, _ amp: Double, _ col: Col) {
        let rockC = col.shade(0.76)
        let track = Col(0xe8d0a8, 0.42).shade(1 - dark * 0.5)
        var px = -6.0
        var lastY = 0.0
        var have = false
        while px <= W + 6 {
            let wx = px + cam * par
            let top = ridgeY(wx, seed, base, amp)
            let room = GY - top
            if room > 7 {
                let y = top + room * (0.5 + 0.22 * sin(wx * 0.021 + seed))
                if have { c.seg(px - 6, lastY, px, y, 0.6, track) }
                lastY = y; have = true
            } else { have = false }
            px += 6
        }
        // a second track lower down, switchbacks climbing toward the ridge, and somebody raising dust on the main one
        px = -6.0; have = false
        while px <= W + 6 {
            let wx = px + cam * par
            let top = ridgeY(wx, seed, base, amp)
            let room = GY - top
            if room > 12 {
                let y = top + room * (0.8 + 0.1 * sin(wx * 0.017 + seed * 2))
                if have { c.seg(px - 6, lastY, px, y, 0.5, track) }
                lastY = y; have = true
            } else { have = false }
            px += 6
        }
        var zn = floor((cam * par - 80) / 150)
        while zn * 150 < cam * par + W + 80 {
            let wx = zn * 150 + hashN(zn + seed * 5 + 6100) * 90
            let top = ridgeY(wx, seed, base, amp)
            let room = GY - top
            if room > 14 {
                let sx = wx - cam * par
                var y = top + room * 0.5
                var xx = sx
                for q in 0..<4 {
                    let nx = sx + (q % 2 == 0 ? 9.0 : -7.0), ny = y - room * 0.1
                    c.seg(xx, y, nx, ny, 0.5, track)
                    xx = nx; y = ny
                }
            }
            zn += 1
        }
        if !g.inPast && g.phase == .play && dark < 0.6 {
            let span = W + 60
            let vx = (NOW * (5 + par * 10) + seed * 53).truncatingRemainder(dividingBy: span) - 30
            let wx = vx + cam * par
            let top = ridgeY(wx, seed, base, amp)
            let room = GY - top
            if room > 7 {
                let y = top + room * (0.5 + 0.22 * sin(wx * 0.021 + seed))
                for q in 0..<4 { c.circ(vx - 2 - Double(q) * 2.4, y - 0.4 - Double(q) * 0.3, 0.8 + Double(q) * 0.5, Col(0xe8d0a8, 0.3 - Double(q) * 0.06)) }
                c.RR(vx - 1.4, y - 1.5, 2.8, 1.3, 0.3, Col(0xc8281e).shade(1 - dark * 0.5))
            }
        }
        var n = floor((cam * par - 10) / 9)
        while n * 9 < cam * par + W + 10 {
            let wx = n * 9 + hashN(n + seed * 31 + 6000) * 9
            let sx = wx - cam * par
            let top = ridgeY(wx, seed, base, amp)
            let room = GY - top
            if room > 4 {
                let y = top + 1.5 + hashN(n + seed * 17 + 6010) * (room - 3)
                let kind = hashN(n + seed * 13 + 6020)
                if kind > 0.93 {
                    c.poly(rockC, [sx - 4, y + 1, sx - 2.4, y - 2.6, sx + 0.6, y - 3.4, sx + 3.6, y - 1.4, sx + 4.6, y + 1])
                    c.poly(rockC.shade(1.25), [sx - 2.4, y - 2.6, sx + 0.6, y - 3.4, sx + 0.2, y - 1.6])
                } else if kind > 0.64 && !g.inPast && g.phase == .play && abs(ridgeY(wx + 4, seed, base, amp) - ridgeY(wx - 4, seed, base, amp)) < 1.5 {
                    let hv = hashN(n + seed * 11 + 6030)
                    if hv < 0.3 {
                        // a trailer with its truck
                        c.RR(sx + 2.2, y - 1.2, 2.4, 1.2, 0.3, [Col(0x3a3a3e), Col(0x8a2a24), Col(0x2e4a6a)][Int(hv * 10) % 3].shade(1 - dark * 0.5))
                    } else if hv < 0.45 {
                        c.poly(Col(0xd9772e).shade(1 - dark * 0.5), [sx + 2.4, y, sx + 3.6, y - 1.6, sx + 4.8, y])
                    }
                    if hv > 0.8 { c.R(sx - 3.2, y - 3.4, 0.2, 3.4, Col(0xc8c8c4)); c.R(sx - 3.2, y - 3.4, 1.2, 0.7, Col(0xd9412e)) }
                    c.RR(sx - 1.8, y - 1.6, 3.6, 1.6, 0.4, (hv > 0.6 ? Col(0xc8bca4) : Col(0xddd6c6)).shade(1 - dark * 0.5))
                    c.R(sx - 1, y - 1.3, 1.2, 0.6, Col(0x3a4a5a))
                    c.circ(sx - 0.9, y + 0.1, 0.35, Col(0x1a1614)); c.circ(sx + 0.9, y + 0.1, 0.35, Col(0x1a1614))
                    if dark > 0.5 { c.circ(sx + 2.6, y - 0.2, 0.5, Col(0xffb050, 0.9)) }
                } else {
                    c.ell(sx, y, 0.5 + kind * 0.7, 0.35 + kind * 0.35, rockC)
                }
            }
            n += 1
        }
    }

    /// A tow vehicle in local units, nose to the right.
    private func towTruck(_ x0: Double, _ col: Col, _ suv: Bool) {
        if suv {
            c.poly(col, [x0, -5, x0, -17, x0 + 3, -21, x0 + 24, -21, x0 + 30, -14, x0 + 38, -12.4, x0 + 38, -5])
            c.RR(x0 + 4, -19.6, 8, 5.4, 0.8, GLASS); c.RR(x0 + 14, -19.6, 8, 5.4, 0.8, GLASS)
        } else {
            c.poly(col, [x0, -5, x0, -13, x0 + 18, -13, x0 + 18, -21, x0 + 29, -21, x0 + 33, -14, x0 + 42, -12.4, x0 + 42, -5])
            c.RR(x0 + 20, -19.6, 8, 5.4, 0.8, GLASS)
            c.R(x0, -13.6, 18, 0.8, col.shade(0.7))
        }
        let len = suv ? 38.0 : 42.0
        c.RR(x0 + len - 1.6, -11, 1.8, 2.4, 0.5, Col(0xfff2c0))
        wheel(x0 + 8, 4); wheel(x0 + len - 8, 4)
    }

    /// The other kinds of rig you see camped out there: fifth wheels, travel trailers, Airstreams, truck campers,
    /// teardrops, toy haulers, old canned hams, box-truck conversions and pop-ups. Local units, nose to the right.
    func camper(_ style: Int, _ cx: Double, _ base: Double, _ dir: Double, _ seed: Double, _ s: Double) {
        if cx < -80 || cx > W + 80 { return }
        let accents: [Col] = [Col(0x2f7f86), Col(0x8a3030), Col(0x2e4a7a), Col(0x4a6a3a), Col(0xc8742e), Col(0x6a4a8a), Col(0x8a7a5a)]
        let trucks: [Col] = [Col(0xd8d4cc), Col(0x3a3a3e), Col(0x8a2a24), Col(0x2e4a6a), Col(0x9a9a98), Col(0x5a6a4a)]
        let acc = accents[Int(hashN(seed + 7720) * 7) % 7]
        let tcol = trucks[Int(hashN(seed + 7730) * 6) % 6]
        let white = hashN(seed + 7740) < 0.7 ? Col(0xeeeae0) : Col(0xd8cdb8)
        c.save()
        c.translate(cx, base)
        c.scale(dir * s, s)
        c.ell(0, 0.6, 46, 2.2, Col(0x000000, 0.2))
        switch style {
        case 0:
            // fifth wheel: the tall nose rides over the pickup's bed
            towTruck(8, tcol, false)
            c.poly(white, [-52, -8, -52, -41, 20, -41, 30, -37, 30, -24, 8, -24, 8, -8])
            c.curve(-51, -18, -20, -22, 28, -30, 2, acc); c.curve(-51, -14.6, -20, -18, 28, -26.6, 0.8, acc.shade(0.7))
            c.RR(-44, -34, 12, 8, 1, GLASS); c.RR(-26, -34, 10, 8, 1, GLASS); c.RR(12, -36, 12, 6, 1, GLASS)
            c.R(-10, -32, 8, 24, white.shade(0.9)); c.RR(-8.4, -30, 4.8, 5, 0.8, GLASS)
            c.RR(-40, -44.4, 12, 3.4, 1.2, Col(0xf7f7f4))
            wheel(-30, 4); wheel(-20, 4)
        case 1:
            // travel trailer behind an SUV
            towTruck(14, tcol, true)
            c.RR(-50, -34, 58, 28, 4, white)
            c.R(-50, -18, 58, 2.4, acc); c.R(-50, -14.4, 58, 0.8, acc.shade(0.7))
            c.RR(-44, -30, 12, 8, 1, GLASS); c.RR(-12, -30, 12, 8, 1, GLASS)
            c.R(-28, -30, 8, 22, white.shade(0.9)); c.RR(-26.4, -28, 4.8, 5, 0.8, GLASS)
            c.seg(8, -8, 16, -7, 1, Col(0x3a3634)); c.RR(-36, -37.4, 12, 3.4, 1.2, Col(0xf7f7f4))
            wheel(-24, 4)
        case 2:
            // a polished aluminum Airstream
            towTruck(14, tcol, false)
            let silver = Col(0xc4c8cc)
            c.RR(-50, -32, 58, 26, 12, silver)
            c.RR(-48, -31, 54, 9, 8, Col(0xe4e8ec, 0.7))
            for i in 0..<4 { c.R(-38 + Double(i) * 12, -31, 0.4, 24, silver.shade(0.82)) }
            c.RR(-44, -27, 10, 6, 2, GLASS); c.RR(-14, -27, 10, 6, 2, GLASS); c.RR(-28, -27, 7, 20, 2, silver.shade(0.9))
            c.R(-50, -14, 58, 1, acc)
            c.seg(8, -8, 16, -7, 1, Col(0x3a3634))
            wheel(-26, 4); wheel(-16, 4)
        case 3:
            // a truck camper: the box sits in the bed and reaches out over the cab
            towTruck(-22, tcol, false)
            c.poly(white, [-24, -13, -24, -36, 10, -36, 12, -28, 8, -22, -4, -22, -4, -13])
            c.R(-24, -24, 20, 1.6, acc); c.RR(-20, -33, 9, 6, 1, GLASS); c.RR(-2, -34, 9, 5, 1, GLASS)
        case 4:
            // a teardrop behind a small car
            towTruck(2, tcol, true)
            c.poly(acc, [-34, -5, -34, -14, -28, -20, -18, -21, -8, -14, -6, -5])
            c.R(-34, -9, 28, 1, Col(0xf4f1ea)); c.RR(-27, -17, 8, 5, 2, GLASS); c.circ(-20, -3.4, 4.2, Col(0x15120f)); c.circ(-20, -3.4, 3, TIRE); c.circ(-20, -3.4, 1.4, HUB)
            c.seg(-6, -7, 4, -7, 0.9, Col(0x3a3634))
        case 5:
            // a toy hauler: a big boxy trailer with loud graphics and the ramp door down
            towTruck(12, tcol, false)
            c.poly(white, [-54, -8, -54, -42, 4, -42, 10, -36, 10, -8])
            c.poly(acc, [-54, -30, -30, -30, -14, -12, -54, -12]); c.poly(Col(0x1c1a1a), [-54, -26, -34, -26, -22, -12, -54, -12])
            c.RR(-8, -36, 12, 8, 1, GLASS); c.R(-22, -34, 8, 26, white.shade(0.9))
            c.poly(Col(0x6a6a70), [-54, -8, -72, 0, -70, 0, -54, -5])
            c.seg(4, -9, 14, -8, 1, Col(0x3a3634))
            wheel(-34, 4); wheel(-24, 4)
        case 6:
            // an old canned-ham trailer, two-tone, behind a wagon
            towTruck(8, tcol, true)
            c.RR(-44, -30, 46, 24, 10, Col(0xf2ecdc))
            c.poly(acc, [-44, -16, 2, -16, 2, -10, -2, -6, -40, -6, -44, -10])
            c.poly(Col(0xf2ecdc), [-44, -17, -20, -20, 2, -17, 2, -16, -44, -16])
            c.RR(-38, -27, 10, 7, 2, GLASS); c.RR(-10, -27, 8, 7, 2, GLASS); c.RR(-24, -27, 7, 20, 2, Col(0xe4dcc8))
            c.seg(2, -8, 10, -7, 1, Col(0x3a3634))
            wheel(-22, 3.6)
        case 7:
            // a box truck somebody built out themselves: a painted side, a stovepipe, a deck on the roof
            c.poly(tcol, [20, -5, 20, -22, 30, -22, 36, -14, 40, -12.4, 40, -5])
            c.RR(22, -20.4, 7, 6, 0.8, GLASS)
            c.R(-38, -36, 58, 31, acc)
            c.poly(Col(0xf2c14e), [-38, -12, -20, -24, -6, -16, 8, -28, 20, -18, 20, -5, -38, -5])
            c.circ(8, -29, 3.4, Col(0xfff0c0))
            c.RR(-30, -30, 9, 7, 1, GLASS); c.RR(-14, -30, 9, 7, 1, GLASS)
            c.R(-34, -39, 40, 1, Col(0x6a4a2e)); for i in 0..<5 { c.R(-34 + Double(i) * 10, -42, 0.8, 3, Col(0x6a4a2e)) }; c.R(-34, -42.6, 41, 0.8, Col(0x6a4a2e))
            c.R(12, -43, 1.6, 7, Col(0x3a3634)); c.R(11, -44, 3.6, 1.2, Col(0x3a3634))
            wheel(-22, 4.4); wheel(30, 4.4)
        default:
            // a pop-up tent trailer with its canvas bunk ends out
            towTruck(10, tcol, true)
            c.R(-40, -14, 40, 9, white); c.R(-40, -12, 40, 1.2, acc)
            let canvas = Col(0xd8c8a0)
            c.poly(canvas, [-36, -14, -34, -26, -6, -26, -4, -14])
            c.poly(canvas.shade(0.9), [-40, -14, -52, -16, -46, -24, -34, -26, -36, -14]); c.poly(canvas.shade(0.9), [0, -14, 10, -16, 6, -24, -6, -26, -4, -14])
            c.R(-35, -27.4, 30, 1.6, white)
            c.RR(-28, -23, 8, 5, 1, Col(0x8aa0b0, 0.8)); c.RR(-16, -23, 8, 5, 1, Col(0x8aa0b0, 0.8))
            c.seg(0, -8, 12, -7, 1, Col(0x3a3634))
            wheel(-20, 3.6)
        }
        c.restore()
        if dark > 0.3 { lights.append((cx, base - 12 * s, 20 * s)) }
    }

    /// One camp in the background: more often than not something other than a motorhome.
    private func campRig(_ n: Double, _ kind: RigKind, _ sx: Double, _ panels: Int, _ dir: Double) {
        let pick = hashN(n * 3.3 + 7700 + Double(g.area.rawValue))
        if pick < 0.24 { camper(0, sx, GY + 0.5, dir, n, 0.5) }
        else if pick < 0.6 { camper(Int(hashN(n + 7710 + Double(g.area.rawValue) * 3) * 9) % 9, sx, GY + 0.5, dir, n, 0.5) }
        else { rig(kind, sx, GY + 0.5, panels, dir, 0.5) }
    }

    /// A dead saguaro: the grey woody ribs left standing in a bundle, some fallen at its foot.
    private func sagSkeleton(_ x: Double, _ base: Double, _ h: Double, _ seed: Double) {
        if x < -30 || x > W + 30 { return }
        let wood = Col(0x9a8e7c).shade(1 - dark * 0.45)
        c.roundCaps(true)
        for i in 0..<7 {
            let d = Double(i)
            let lean = (d - 3) * 0.9 + (hashN(seed + d) - 0.5)
            let hh = h * (0.55 + hashN(seed + d + 5) * 0.45)
            c.seg(x + (d - 3) * 0.7, base, x + lean * 1.6, base - hh, 0.6, i % 2 == 0 ? wood : wood.shade(0.82))
        }
        c.seg(x - 4, base, x - 16, base - 1.4, 0.6, wood.shade(0.9)); c.seg(x + 3, base + 0.6, x + 15, base - 0.6, 0.6, wood)
        c.ell(x, base, 3.4, 1.2, Col(0x6a5a48).shade(1 - dark * 0.45))
        c.roundCaps(false)
    }

    /// Joshua tree: a shaggy trunk forking into a few thick arms, each ending in a spiky ball of leaves.
    private func joshua(_ x: Double, _ base: Double, _ h: Double, _ seed: Double) {
        if x < -40 || x > W + 40 { return }
        let bark = Col(0x6a5a44).shade(1 - dark * 0.45)
        let leaf = Col(0x6a8a4a).shade(1 - dark * 0.45)
        var tips: [(Double, Double, Double)] = []
        taper(x, base, x, base - h * 0.4, h * 0.11, h * 0.09, bark)
        for i in 0..<2 {
            let f = Double(i) - 0.5
            bough(x, base - h * 0.4, -PI / 2 + f * 1.1, h * 0.3, h * 0.085, 1, seed + Double(i) * 4.3, bark, 0.5, 0, true, &tips)
        }
        c.roundCaps(true)
        for (i, t) in tips.enumerated() {
            c.circ(t.0, t.1, h * 0.06, leaf.shade(0.8))
            for q in 0..<11 {
                let a = Double(q) / 11 * PI * 2 + Double(i)
                c.seg(t.0, t.1, t.0 + cos(a) * h * 0.13, t.1 + sin(a) * h * 0.13, 0.5, q % 2 == 0 ? leaf : leaf.shade(1.2))
            }
        }
        c.roundCaps(false)
    }
    /// Juniper: a low, dense, dark evergreen with a twisted trunk.
    private func juniper(_ x: Double, _ base: Double, _ s: Double, _ seed: Double) {
        if x < -30 || x > W + 30 { return }
        let g1 = Col(0x3e5a40).shade(1 - dark * 0.45)
        c.seg(x, base, x + 1.5 * s, base - 8 * s, 2 * s, Col(0x6a5a4a).shade(1 - dark * 0.45))
        for i in 0..<7 {
            let d = Double(i)
            c.circ(x + (hashN(seed + d) - 0.5) * 16 * s, base - 9 * s - hashN(seed + d + 3) * 10 * s, (4 + hashN(seed + d + 6) * 3) * s, i % 2 == 0 ? g1 : g1.shade(1.18))
        }
    }
    /// What grows on the valley floor in the ice age: Joshua trees, creosote, yucca, juniper and bunchgrass.
    private func icePlant(_ sx: Double, _ k: Double, _ n: Double) {
        if k < 0.28 { joshua(sx, GY + 1, 26 + hashN(n + 5) * 16, n) }
        else if k < 0.56 { creosote(sx, GY + 1, n) }
        else if k < 0.7 { juniper(sx, GY + 1, 0.9 + hashN(n + 6) * 0.4, n) }
        else if k < 0.84 {
            let leaf = Col(0x7a9a5a).shade(1 - dark * 0.45)
            for q in 0..<9 { let a = -PI + Double(q) / 8 * PI; c.seg(sx, GY + 1, sx + cos(a) * 5, GY + 1 + sin(a) * 5, 0.6, leaf) }
            c.seg(sx, GY - 2, sx + 0.6, GY - 13, 0.5, Col(0x9a8a5a)); c.ell(sx + 0.6, GY - 14, 1.2, 2.4, Col(0xe8e0c0).shade(1 - dark * 0.4))
        } else {
            for q in 0..<8 { c.seg(sx + Double(q) - 4, GY + 1, sx + (Double(q) - 4) * 1.6, GY - 4 - hashN(n + Double(q)) * 3, 0.4, Col(0xb0a860).shade(1 - dark * 0.45)) }
        }
    }

    /// A Columbian mammoth.
    private func mammoth(_ x: Double, _ base: Double, _ s: Double, _ ph: Double) {
        if x < -40 * s || x > W + 40 * s { return }
        let fur = Col(0x6a4a34).shade(1 - dark * 0.5)
        let sw = sin(NOW * 1.2 + ph) * s
        c.roundCaps(true)
        let legs: [(Double, Double)] = [(-8, sw), (-4, -sw), (6, -sw), (10, sw)]
        for (lx, s0) in legs { c.seg(x + lx * s, base - 12 * s, x + lx * s + s0, base, 3.6 * s, fur.shade(0.82)) }
        c.ell(x, base - 16 * s, 13 * s, 8.5 * s, fur)
        c.ell(x + 5 * s, base - 23 * s, 7 * s, 5.4 * s, fur)
        c.ell(x + 13 * s, base - 22 * s, 5.4 * s, 6.6 * s, fur.shade(1.06))
        c.ell(x + 9.6 * s, base - 21 * s, 2.4 * s, 3.4 * s, fur.shade(0.85))
        let curl = sin(NOW * 0.8 + ph) * 2 * s
        c.curve(x + 16.6 * s, base - 19 * s, x + 21 * s, base - 9 * s, x + 17 * s + curl, base - 2.4 * s, 2.4 * s, fur.shade(1.06))
        c.curve(x + 15 * s, base - 16.4 * s, x + 23 * s, base - 8 * s, x + 26 * s, base - 16 * s, 1.1 * s, Col(0xf0e8d8).shade(1 - dark * 0.4))
        c.circ(x + 14.6 * s, base - 23.4 * s, 0.6 * s, INK)
        for q in 0..<7 { c.seg(x - 9 * s + Double(q) * 3 * s, base - 9 * s, x - 9.4 * s + Double(q) * 3 * s, base - 6.6 * s, 0.5 * s, fur.shade(0.75)) }
        c.seg(x - 12.6 * s, base - 18 * s, x - 14 * s, base - 11 * s, 0.8 * s, fur.shade(0.8))
        c.roundCaps(false)
    }
    /// A big cat: tawny and spotted for the jaguar, heavier with long teeth for the sabertooth.
    private func cat(_ x: Double, _ base: Double, _ s: Double, _ col: Col, _ saber: Bool, _ spots: Bool, _ drink: Bool) {
        let cc = col.shade(1 - dark * 0.45)
        c.roundCaps(true)
        for lx in [-5.0, -3.0, 4.0, 6.0] { c.seg(x + lx * s, base - 5 * s, x + lx * s, base, 1.5 * s, cc.shade(0.85)) }
        c.ell(x, base - 7 * s, 8 * s, 3.2 * s, cc)
        let hx = x + 9 * s, hy = drink ? base - 3 * s : base - 10 * s
        c.seg(x + 6 * s, base - 8 * s, hx, hy, 2.6 * s, cc)
        c.circ(hx + 1 * s, hy, 2.4 * s, cc)
        c.poly(cc, [hx, hy - 2 * s, hx + 0.6 * s, hy - 4 * s, hx + 1.6 * s, hy - 2 * s])
        if saber { c.seg(hx + 2.4 * s, hy + 1 * s, hx + 2.6 * s, hy + 4 * s, 0.6 * s, Col(0xf4f0e4)) }
        c.curve(x - 8 * s, base - 7 * s, x - 14 * s, base - 4 * s, x - 15 * s, base - 9 * s + sin(NOW * 2) * s, 1 * s, cc)
        if spots { for q in 0..<9 { c.circ(x - 6 * s + Double(q) * 1.5 * s, base - 8 * s + Double(q % 3) * 1.2 * s, 0.5 * s, Col(0x2a1e14, 0.8)) } }
        c.roundCaps(false)
    }
    /// The big animals moving through the ice age valley.
    private func iceWild(_ ar: Area) {
        if dark > 0.5 { return }
        let t = NOW * 0.2
        soar(W * 0.5 + cos(t) * W * 0.3, GY * 0.44 + sin(t * 1.3) * 8, 34, true)
        if [Area.main, .tyson, .hijolly, .roadrunner, .scaddan].contains(ar) {
            let hx = (NOW * 5).truncatingRemainder(dividingBy: g.WORLD + 400) - 200
            for k in 0..<3 { mammoth(hx + Double(k) * 46 - cam, GY + 2, 0.8 + Double(k % 2) * 0.25, Double(k) * 1.4) }
        }
        if [Area.dome, .trail, .plomosa, .crystal, .desertbar].contains(ar) {
            let hx = g.WORLD - (NOW * 11).truncatingRemainder(dividingBy: g.WORLD + 400) + 200
            for k in 0..<5 { hoofed(hx + Double(k) * 24 - cam, GY + 2 + Double(k % 2), 1.25, 2, Double(k)) }
        }
    }
    /// What there is to watch, 13,000 years back.
    private func iceSight(_ k: Int, _ x: Double) {
        let base = GY + 1
        switch k {
        case 0:
            mammoth(x - 30, base, 1.1, 0); mammoth(x + 26, base, 0.9, 1.6); mammoth(x + 2, base + 1, 0.55, 3)
        case 1:
            for q in 0..<4 { joshua(x - 50 + Double(q) * 32, base, 34 + hashN(Double(q) + 9100) * 14, Double(q) + 9110) }
        case 2:
            for q in 0..<3 {
                let cx = x - 28 + Double(q) * 28
                c.ell(cx - 1, base - 19, 4.6, 3.4, Col(0x8a7a6a).shade(1 - dark * 0.5))
                hoofed(cx, base + Double(q % 2), 1.5, 2, Double(q) * 1.3)
            }
        case 3:
            joshua(x + 12, base, 40, 9200)
            let fur = Col(0xa88a5e).shade(1 - dark * 0.5)
            c.roundCaps(true)
            c.seg(x - 8, base - 2, x - 16, base, 3, fur.shade(0.85))
            c.ell(x - 4, base - 9, 6.4, 9, fur)
            c.circ(x - 1, base - 20, 3, fur.shade(1.05))
            c.seg(x - 1, base - 15, x + 8, base - 22 + sin(NOW * 1.5) * 1.4, 2.2, fur)
            for q in 0..<3 { c.seg(x + 8, base - 22, x + 10, base - 23.4 + Double(q) * 1.2, 0.4, INK) }
            c.seg(x - 6, base - 2, x - 6, base, 2.6, fur.shade(0.85)); c.seg(x - 1, base - 2, x - 1, base, 2.6, fur.shade(0.85))
            c.roundCaps(false)
        case 4:
            c.R(x - 80, base + 4, 160, 5, Col(0x5a8aa0, 0.6))
            for q in 0..<8 { let u = (NOW * 0.3 + Double(q) / 8).truncatingRemainder(dividingBy: 1); c.R(x - 80 + u * 160, base + 5 + Double(q % 3), 8, 0.6, Col(0xe8f0f4, 0.6)) }
        case 5:
            for q in 0..<3 {
                c.save(); c.translate(x - 20 + Double(q) * 20, base + 1 + Double(q % 2)); c.scale(1.5, 1.5)
                coyote(0, 0, NOW * 2 + Double(q))
                c.restore()
            }
        case 6:
            for q in 0..<4 {
                let hx = x - 36 + Double(q) * 24
                hoofed(hx, base + Double(q % 2), 1.3, 2, Double(q) * 1.1)
                c.seg(hx - 9, base - 15, hx - 13, base - 7, 0.9, Col(0x3a2e24))
            }
        case 7:
            for q in 0..<16 { let d = Double(q); c.seg(x - 8 + hashN(d + 9300) * 16, base, x - 8 + hashN(d + 9310) * 16, base - 2 - hashN(d + 9320) * 6, 0.5, Col(0x7a6248)) }
            c.ell(x + 12, base - 1.4, 2.4, 1.4, Col(0x8a7a6a)); c.circ(x + 14.4, base - 2, 1, Col(0x8a7a6a)); c.seg(x + 9.6, base - 1, x + 6, base - 0.4, 0.3, Col(0x8a7a6a))
        case 8:
            let t = NOW * 0.22
            soar(x + cos(t) * 60, GY - 78 + sin(t) * 10, 44, true)
        case 9:
            // a small hunting band: a hide shelter, a fire, a stone point being worked
            c.poly(Col(0x9a7a56).shade(1 - dark * 0.5), [x - 44, base, x - 30, base - 18, x - 14, base])
            c.seg(x - 30, base - 18, x - 31, base - 22, 0.6, Col(0x5a4030)); c.seg(x - 30, base - 18, x - 28, base - 22, 0.6, Col(0x5a4030))
            fire(x, base + 2)
            villager(x - 12, base, 31, 2); villager(x + 14, base, 32, 0); villager(x + 26, base + 1, 33, 3)
            c.seg(x + 17, base - 1, x + 19, base - 26, 0.5, Col(0x6a4a2e)); c.poly(Col(0xc8c0b0), [x + 18, base - 26, x + 19, base - 30, x + 20, base - 26])
        case 10:
            for q in 0..<5 { juniper(x - 50 + Double(q) * 25, base, 1.1 + hashN(Double(q) + 9400) * 0.5, Double(q) + 9410) }
        case 11:
            for q in 0..<4 {
                let px = x - 30 + Double(q) * 20
                c.R(px - 0.8, base - 14, 1.6, 14, Col(0x5a4030).shade(1 - dark * 0.45))
                for r in 0..<4 { c.poly(Col(0x3a5a3e).shade(1 - dark * 0.45 + Double(r) * 0.04), [px - 8 + Double(r) * 1.6, base - 8 - Double(r) * 5, px, base - 17 - Double(r) * 5, px + 8 - Double(r) * 1.6, base - 8 - Double(r) * 5]) }
            }
        case 12:
            let rock = Col(0x7a6a5a).shade(1 - dark * 0.5)
            c.poly(rock, [x - 36, base, x - 24, base - 22, x + 10, base - 26, x + 30, base])
            cat(x - 6, base - 25, 1.2, Col(0xb8925e), true, false, false)
        default:
            c.ell(x, base + 8, 110, 7, Col(0x5a4636).shade(1 - dark * 0.5))
        }
    }

    /// A side-by-side in one of the makes you see out here, two seats or four, helmets on, whip flag up.
    private func sxs(_ cx: Double, _ base: Double, _ dir: Double, _ brand: Int, _ four: Bool) {
        if cx < -60 || cx > W + 60 { return }
        let paints: [(Col, Col)] = [(Col(0xc8281e), Col(0xf4f4f0)), (Col(0xf2c418), Col(0x1c1a1a)), (Col(0x3a9a3a), Col(0x1c1a1a)), (Col(0x2a5ad0), Col(0xf4f4f0)), (Col(0x2a2a2e), Col(0xc8281e)), (Col(0xe8782e), Col(0x1c1a1a)), (Col(0x2fa7a0), Col(0xf4f4f0))]
        let p = paints[brand % 7]
        let body = p.0.shade(1 - dark * 0.4), trim = p.1.shade(1 - dark * 0.4)
        let ext = four ? 9.0 : 0.0
        c.save()
        c.translate(cx, base)
        c.scale(dir, 1)
        c.ell(0, 0.6, 20 + ext / 2, 2, Col(0x000000, 0.22))
        c.poly(body, [-17 - ext, -5, -17 - ext, -11, -9 - ext, -13, 6, -13, 14, -9.6, 19, -8.4, 19, -5])
        c.poly(trim, [-17 - ext, -8, -6 - ext, -10.6, 6, -10.6, 14, -8, 14, -7, -17 - ext, -7])
        let cage = Col(0x1c1a1a)
        c.seg(-14 - ext, -12, -11 - ext, -22, 0.9, cage); c.seg(-11 - ext, -22, 4, -22, 0.9, cage); c.seg(4, -22, 9, -12.6, 0.9, cage)
        c.seg(-3 - ext / 2, -22, -3 - ext / 2, -13, 0.7, cage)
        let seats = four ? 2 : 1
        for k in 0..<seats {
            let hx = 1.0 - Double(k) * 9
            c.RR(hx - 2.4, -17, 4.4, 5.6, 1.4, [Col(0x3a4a6a), Col(0x7a3a3a)][k % 2])
            c.circ(hx, -18.6, 2.5, [Col(0xf4f4f0), Col(0x2a2a2e), Col(0xe2742e)][(brand + k) % 3]); c.R(hx + 0.6, -19.4, 2, 1.3, Col(0x1a2030))
        }
        c.seg(-15 - ext, -12, -17 - ext, -30, 0.3, Col(0x8a8a88)); c.poly(Col(0xff6a2a), [-17 - ext, -30, -22 - ext, -28.4, -17 - ext, -27])
        c.RR(17.6, -9.4, 1.8, 1.8, 0.5, Col(0xfff2c0))
        wheel(-11 - ext, 4.6); wheel(12, 4.6)
        c.restore()
        if dark > 0.3 { lights.append((cx + dir * 22, base - 8, 16)) }
    }

    /// Inside Silly Al's: the bar down one side, the pool table in the back room.
    private func alsOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.7))
        g.hits.append(Hit(id: -2, x: 0, y: 0, w: W, h: H))
        let x0 = g.safeL + 10, x1 = W - g.safeR - 10, y0 = 5.0, y1 = H - 5
        let w = x1 - x0
        // the room is drawn big: a low ceiling, so people fill it
        let RW = 118.0
        let S = min((w - 6) / RW, (y1 - y0 - 20) / 46.5)
        let ox = x0 + (w - RW * S) / 2, oy = y1 - 4 - 12 * S
        func sx(_ u: Double) -> Double { return ox + u * S }
        func sy(_ v: Double) -> Double { return oy + v * S }
        let pt = sy(-34) - 14
        c.RR(x0, pt, w, y1 - pt, 5, Col(0x21140f))
        g.text("SILLY AL'S", x0 + 9, pt + 7.4, 7, GOLD, align: 1, bold: true)
        g.text("order off the chalkboard  ·  tap the pool table for a game  ·  tap the floor to step back out", x1 - 9, pt + 7.4, 3.4, CREAM.alpha(0.8), align: 2)
        g.hits.append(Hit(id: 62, x: ox, y: sy(-34), w: RW * S, h: 34 * S))
        c.save()
        c.translate(ox, oy)
        c.scale(S, S)
        let woodD = Col(0x4a2a1a), woodM = Col(0x7a4a2a), woodL = Col(0xb8742e), brass = Col(0xd8b048)
        // plaster wall, stained and patched, over dark plank wainscot
        c.R(0, -34, RW, 34, Col(0xd6b676))
        for q in 0..<90 {
            let d = Double(q)
            c.R(hashN(d + 9601) * RW, -31 + hashN(d + 9602) * 17, 0.3 + hashN(d + 9603) * 1.4, 0.2, Col(0xbf9e5e, 0.7))
        }
        c.ell(60, -27, 9, 2.4, Col(0xc8a868, 0.6)); c.ell(20, -19, 6, 3, Col(0xdcc088, 0.5))
        c.R(0, -13, RW, 13, Col(0x6a3e26))
        var pl = 0.0
        while pl < RW { c.R(pl, -13, 0.2, 13, woodD); c.R(pl + 1.2, -13 + hashN(pl) * 9, 0.15, 2.4, Col(0x5a321e)); pl += 2.6 }
        c.R(0, -13.7, RW, 0.9, Col(0x8a5a36)); c.R(0, -0.9, RW, 0.9, Col(0x3a2418))
        // a low ceiling: stained drop tiles between dark beams
        c.R(0, -34, RW, 3, Col(0xe4dccb))
        var tl = 0.0
        while tl < RW { c.R(tl, -34, 0.15, 3, Col(0xb4ac9c)); tl += 5 }
        c.ell(44, -32.6, 4, 0.8, Col(0xc8b48a, 0.8)); c.ell(97, -32.4, 3, 0.7, Col(0xc8b48a, 0.8))
        c.R(0, -31.2, RW, 0.6, woodD)
        for q in 0..<5 { c.R(8 + Double(q) * 25, -34, 1.8, 3.6, Col(0x5a3a26)) }
        // red and cream checkerboard tile, scuffed
        c.R(0, 0, RW, 12, Col(0xe6dcc8))
        let rows: [(Double, Double, Double)] = [(0, 2.6, 4), (2.6, 3.8, 5.2), (6.4, 5.6, 6.8)]
        for (r, row) in rows.enumerated() {
            var tx = -Double(r) * 1.4
            var k = r
            while tx < RW { if k % 2 == 0 { c.R(max(0, tx), row.0, min(row.2, RW - max(0, tx)), row.1, Col(0xa63a2c)) }; tx += row.2; k += 1 }
        }
        for q in 0..<14 { c.ell(hashN(Double(q) + 9611) * RW, 1 + hashN(Double(q) + 9612) * 10, 2.4, 0.5, Col(0x3a2418, 0.12)) }
        // a string of pennants and a row of old licence plates up under the ceiling
        for q in 0..<24 {
            let u = 2 + Double(q) * 3.5
            if u > 84 { break }
            c.poly([Col(0xc8281e), Col(0xf2c418), Col(0x2e5a9a), Col(0x3a8a4a)][q % 4], [u, -30.6, u + 2.6, -30.6, u + 1.3, -28.4 + sin(Double(q)) * 0.3])
        }
        // ---- the bar ----
        // back bar: carved shelves around a spotted mirror, bottles two deep, a register, a TV with the game on
        c.R(3, -28, 36, 15, woodD); c.R(3, -28.8, 36, 1, woodL)
        c.R(4.4, -27, 33.2, 12.4, Col(0x9ab0b4)); c.poly(Col(0xffffff, 0.25), [8, -27, 14, -27, 8, -14.6, 4.4, -14.6])
        for q in 0..<7 { c.circ(6 + hashN(Double(q) + 9620) * 30, -26 + hashN(Double(q) + 9621) * 10, 0.3, Col(0x6a7a7c, 0.6)) }
        let glassC: [Col] = [Col(0x4a9a6a), Col(0xd8a850), Col(0xb86a4a), Col(0x6a90d0), Col(0xe8e0c0), Col(0x7a3a2a)]
        for r in 0..<2 {
            let sv = -21.4 + Double(r) * 6.4
            c.R(4.4, sv, 33.2, 0.6, woodL)
            for q in 0..<16 {
                let bu = 5.4 + Double(q) * 2
                let bh = 3 + hashN(Double(q + r * 20) + 9630) * 1.6
                c.RR(bu, sv - bh, 1.3, bh, 0.4, glassC[(q * 3 + r) % 6]); c.R(bu + 0.4, sv - bh - 0.9, 0.5, 1, glassC[(q * 3 + r) % 6].shade(0.8))
                c.R(bu + 0.15, sv - bh * 0.6, 1, 1, Col(0xf4f0e0, 0.8))
            }
        }
        c.R(3, -13.6, 36, 0.8, woodL)
        // the TV
        c.RR(41, -30, 11, 7.4, 0.6, Col(0x141414)); c.R(41.6, -29.4, 9.8, 6.2, Col(0x3a8a4a))
        c.R(46.4, -29.4, 0.2, 6.2, Col(0xffffff, 0.6)); c.circ(46.5 + sin(NOW * 1.3) * 3.4, -26.4 + cos(NOW * 1.9) * 1.6, 0.4, Col(0xffffff))
        c.R(41.6, -24, 9.8, 0.8, Col(0x1a2a5a)); c.R(46, -22.6, 1, 1.2, Col(0x2a2a2a))
        // the bartender, behind the counter
        person(25, -0.4, 640, -1, 0, false)
        c.seg(21.4, -13.4, 19, -12.2, 1.2, Col(0xe8e0d0))
        // the counter: thick wood top, padded rail, panelled front, brass foot rail
        c.R(2.4, -12.4, 45.2, 1.3, woodL); c.R(2.4, -12.4, 45.2, 0.35, Col(0xd89848)); c.RR(2, -11.3, 46, 1.2, 0.6, Col(0x5a1e16))
        c.R(3.4, -10.1, 43.6, 10.1, woodM)
        for q in 0..<6 { c.RR(4.4 + Double(q) * 7.2, -9, 6, 7, 0.5, Col(0x6a3e22)); c.RR(5.2 + Double(q) * 7.2, -8.2, 4.4, 5.4, 0.4, woodM) }
        c.R(3.4, -1.9, 43.6, 0.45, brass); for q in 0..<5 { c.R(6 + Double(q) * 9.6, -1.9, 0.4, 1.9, brass) }
        // on the bar: a tap tower, glasses, a pizza on a stand, shakers, a tip jar
        c.R(31.2, -16.4, 3.6, 1, Col(0xc8c8cc)); c.R(32.6, -15.4, 0.8, 3, Col(0xa8a8ac))
        for q in 0..<3 { c.R(31.5 + Double(q) * 1.1, -18.6, 0.6, 2.3, [Col(0xc8281e), Col(0xf2c418), Col(0x2e5a9a)][q]) }
        for q in 0..<4 { c.poly(Col(0xf0d890, 0.9), [36 + Double(q) * 2.2, -12.4, 36.3 + Double(q) * 2.2, -15, 37.5 + Double(q) * 2.2, -15, 37.8 + Double(q) * 2.2, -12.4]); c.R(36.3 + Double(q) * 2.2, -15.4, 1.2, 0.5, Col(0xffffff)) }
        c.R(11.6, -13.6, 0.5, 1.2, Col(0xc8c8cc)); c.ell(11.8, -13.8, 4.2, 0.8, Col(0xc8c8cc)); c.ell(11.8, -14.2, 3.8, 0.7, Col(0xe0a84a)); for q in 0..<5 { c.circ(9.4 + Double(q) * 1.2, -14.3, 0.3, Col(0xa82a1e)) }
        c.RR(17, -14.4, 0.9, 2, 0.3, Col(0xf4f4f0)); c.RR(18.2, -14.4, 0.9, 2, 0.3, Col(0xa83a2c)); c.RR(4.4, -15, 1.8, 2.6, 0.4, Col(0xc8e0e8, 0.8)); c.R(4.8, -13.6, 1, 1, Col(0x5a8a4a))
        // stools and the regulars
        for q in 0..<5 {
            let u = 7.5 + Double(q) * 9
            c.R(u - 0.3, -7.2, 0.6, 7.2, Col(0x9a9ea4)); c.ell(u, -0.2, 2.2, 0.5, Col(0x6a6e74)); c.R(u - 1.4, -3, 2.8, 0.3, Col(0x9a9ea4))
            c.RR(u - 2.2, -8.2, 4.4, 1.3, 0.6, Col(0x8a2e1e)); c.R(u - 2.2, -7.2, 4.4, 0.3, brass)
            if q == 0 || q == 2 || q == 3 { seated(u, -8.4, 610 + q, 0.3) }
        }
        // three pendant lamps over the bar
        for q in 0..<3 {
            let u = 9 + Double(q) * 14
            c.R(u - 0.1, -31, 0.2, 4.4, Col(0x2a2a2a)); c.poly(Col(0x8a2e1e), [u - 2.2, -24.6, u - 1, -26.8, u + 1, -26.8, u + 2.2, -24.6])
            c.glow(u, -23, 9, Col(0xffe0a0, 0.3), Col(0xffe0a0, 0))
        }
        // ---- the middle of the room ----
        // the chalkboard menu
        c.RR(52, -30, 22, 15.4, 0.6, woodL); c.R(52.8, -29.2, 20.4, 13.8, Col(0x243028))
        for q in 0..<12 { c.R(53.4 + hashN(Double(q) + 9640) * 18, -28.6 + hashN(Double(q) + 9641) * 12.6, 1.6, 0.15, Col(0xffffff, 0.08)) }
        c.R(52, -14.8, 22, 0.6, woodM); c.R(58, -15.2, 1.6, 0.4, Col(0xf4f4f0)); c.R(61, -15.2, 1.2, 0.4, Col(0xf2c418))
        // a ceiling fan turning slowly
        for fu in [46.0, 79.0] {
            c.R(fu - 0.2, -31, 0.4, 1.4, Col(0x3a3a3a)); c.ell(fu, -29.4, 1.2, 0.5, brass)
            for k in 0..<4 { let a = NOW * 2.4 + Double(k) * PI / 2; c.seg(fu, -29.4, fu + cos(a) * 7, -29.4 + sin(a) * 0.7, 0.8, woodM) }
        }
        // a booth: red vinyl benches, a checked cloth, a pie and a pitcher
        c.RR(50.4, -13, 4.4, 13, 1, Col(0x8a2e1e)); c.R(51, -12, 0.3, 10, Col(0x6a1e12)); c.R(53.2, -12, 0.3, 10, Col(0x6a1e12))
        c.RR(71.2, -13, 4.4, 13, 1, Col(0x8a2e1e)); c.R(72, -12, 0.3, 10, Col(0x6a1e12)); c.R(74.2, -12, 0.3, 10, Col(0x6a1e12))
        c.R(62.4, -7.6, 1.2, 7.6, Col(0x5a5a5a)); c.R(56, -8.8, 14, 1, woodL)
        for q in 0..<7 { c.R(56 + Double(q) * 2, -8.8, 1, 2.6, q % 2 == 0 ? Col(0xc8281e) : Col(0xf4f4f0)); c.R(57 + Double(q) * 2, -8.8, 1, 2.6, q % 2 == 0 ? Col(0xf4f4f0) : Col(0xc8281e)) }
        c.ell(62.4, -9.2, 3.6, 0.7, Col(0xc8c8cc)); c.ell(62.4, -9.5, 3.2, 0.6, Col(0xe0a84a)); for q in 0..<4 { c.circ(60.6 + Double(q) * 1.2, -9.6, 0.3, Col(0xa82a1e)) }
        c.poly(Col(0xf0d890, 0.9), [67, -8.8, 66.8, -12.4, 69, -12.4, 68.8, -8.8]); c.RR(58, -11.4, 0.9, 2.6, 0.3, Col(0xa83a2c))
        // framed photos, a dartboard, a jukebox glowing in the corner
        for q in 0..<3 {
            let fu = 76.4 + Double(q % 2) * 4.6, fv = -27.4 + Double(q / 2) * 5.4
            c.R(fu, fv, 3.8, 4.4, woodD); c.R(fu + 0.5, fv + 0.5, 2.8, 3.4, [Col(0xc8b89a), Col(0x9ab0c8), Col(0xd8c0a0)][q]); c.ell(fu + 1.9, fv + 2.6, 1, 0.8, Col(0x5a4a3a, 0.7))
        }
        c.circ(82.4, -19.4, 2.6, Col(0x1c1a1a)); c.circ(82.4, -19.4, 2.1, Col(0xe8e0c8)); c.circ(82.4, -19.4, 1.3, Col(0x2a6a3a)); c.circ(82.4, -19.4, 0.5, Col(0xc8281e))
        for q in 0..<8 { let a = Double(q) / 8 * PI * 2; c.seg(82.4, -19.4, 82.4 + cos(a) * 2.1, -19.4 + sin(a) * 2.1, 0.1, Col(0x1c1a1a)) }
        c.RR(77, -13.4, 6.4, 13.4, 2.4, Col(0x7a2218)); c.RR(77.8, -12.4, 4.8, 5.4, 2, Col(0xf8d880))
        for q in 0..<3 { c.R(78.2 + Double(q) * 1.5, -12 , 1, 4.6, [Col(0xff5a6a), Col(0x5ad0ff), Col(0x8aff7a)][q].alpha(0.5 + 0.4 * sin(NOW * 3 + Double(q) * 2))) }
        c.R(77.8, -6, 4.8, 0.5, brass); c.R(78.4, -4.6, 3.6, 3, Col(0x3a2418)); c.glow(80.2, -9, 8, Col(0xffd880, 0.22), Col(0xffd880, 0))
        // ---- the back room: deep green walls, the table under a long shaded lamp ----
        c.R(86, -31, 32, 18, Col(0x2e4a3a)); c.R(84.6, -31, 1.6, 31, Col(0x5a3a26)); c.R(84.6, -31, 33.4, 1, Col(0x5a3a26))
        for q in 0..<30 { c.R(86.4 + hashN(Double(q) + 9650) * 31, -30 + hashN(Double(q) + 9651) * 16, 1.2, 0.15, Col(0x24402e)) }
        // cue rack, score beads, a beer mirror
        c.R(108.4, -27, 7, 12, woodD); for q in 0..<4 { c.seg(109.6 + Double(q) * 1.5, -26.2, 109.6 + Double(q) * 1.5, -15.6, 0.3, Col(0xd8b878)); c.R(109.4 + Double(q) * 1.5, -17, 0.4, 1.4, Col(0x1c1a1a)) }
        c.seg(88, -28.6, 100, -28.6, 0.15, Col(0x1c1a1a)); for q in 0..<14 { c.circ(88.6 + Double(q) * 0.8 + (q > 8 ? 1.4 : 0), -28.6, 0.35, q % 2 == 0 ? Col(0xc8281e) : Col(0xf4f4f0)) }
        c.R(88, -25.4, 6.4, 5, brass); c.R(88.5, -24.9, 5.4, 4, Col(0x8aa8b0)); c.ell(91.2, -22.9, 1.8, 1.2, Col(0xc8281e, 0.7))
        // the lamp
        c.seg(97, -31, 97, -24, 0.15, brass); c.seg(107, -31, 107, -24, 0.15, brass)
        c.poly(Col(0x2a6a3a), [93, -21.4, 95.4, -24, 108.6, -24, 111, -21.4]); c.R(93, -21.6, 18, 0.5, brass)
        c.poly(Col(0xffe8b0, 0.16), [94, -21, 110, -21, 115, -10.6, 89, -10.6])
        // the table, side on
        c.RR(89.6, -10.8, 24.8, 2.4, 0.8, Col(0x5a3018)); c.R(90.6, -10.8, 22.8, 0.7, Col(0x2f8a4a))
        for q in 0..<3 { c.circ(90.4 + Double(q) * 11.6, -9.4, 0.6, Col(0x12100e)); c.circ(92.6 + Double(q) * 9.2, -8.9, 0.25, Col(0xe8e0d0)) }
        c.R(91.4, -8.4, 21.2, 2.4, Col(0x4a2814)); c.poly(Col(0x3a2010), [92, -6, 95, -6, 94.2, 0, 92.6, 0]); c.poly(Col(0x3a2010), [109, -6, 112, -6, 111.4, 0, 109.8, 0])
        let balls: [Col] = [Col(0xf2c418), Col(0x2a5ad0), Col(0xc8281e), Col(0x6a3a8a), Col(0xe8782e), Col(0x1c1a1a), Col(0xf4f4f0)]
        for q in 0..<7 { c.circ(93 + hashN(Double(q) + 9500) * 18, -11.4, 0.6, balls[q]) }
        person(87.4, 0.6, 655, 1, 0, false); c.seg(88.6, -10.4, 96, -12.2, 0.3, Col(0xd8b878))
        person(115.4, 0.6, 660, -1, 0, false); c.seg(116.6, 0, 116, -17, 0.3, Col(0xd8b878))
        // soft dark at the corners so the lamps do the lighting
        c.poly(Col(0x000000, 0.22), [0, -34, 10, -34, 0, -20]); c.poly(Col(0x000000, 0.22), [RW, -34, RW - 10, -34, RW, -20])
        c.restore()
        // words and taps, in screen space
        g.text("TODAY", sx(63), sy(-27.6), 1.5 * S, Col(0xf2e8c8), bold: true)
        let menu: [(String, String)] = [("Pizza", "10"), ("Big salad", "8"), ("Cold beer", "5")]
        for q in 0..<3 {
            let v = -24.4 + Double(q) * 3.2
            g.text(menu[q].0, sx(54), sy(v), 1.45 * S, Col(0xf4f4f0), align: 1, bold: true)
            g.text(menu[q].1, sx(72), sy(v), 1.45 * S, GOLD, align: 2, bold: true)
            g.hits.append(Hit(id: 340 + q, x: sx(52), y: sy(v - 1.6), w: 22 * S, h: 3.2 * S))
        }
        g.hits.append(Hit(id: 58, x: sx(87), y: sy(-25), w: 30 * S, h: 26 * S))
        tapArrow(sx(102), sy(-13.4), "Tap for a game")
        if g.mapMsgT > 0 { g.text(g.mapMsg, (x0 + x1) / 2, y1 - 9, 5.4, CREAM.alpha(clampD(g.mapMsgT, 0, 1)), bold: true, plate: true) }
    }

    /// Your own touches on your rig: a painted stripe down the side and a flag flying off the back.
    private func rigCustom(_ cx: Double, _ base: Double, _ def: RigDef, _ dir: Double, _ s: Double) {
        let len = def.len * s, high = def.high * s
        if g.stripe > 0 {
            let col = STRIPES[g.stripe % STRIPES.count].shade(1 - dark * 0.4)
            c.R(cx - len * 0.36, base - high * 0.44, len * 0.72, 1.5 * s, col)
            c.R(cx - len * 0.36, base - high * 0.44 - 1.3 * s, len * 0.72, 0.5 * s, col.shade(1.3))
        }
        if g.flag > 0 {
            let fx = cx - dir * len * 0.47
            let ty = base - high - 15 * s
            c.R(fx - 0.3 * s, ty, 0.6 * s, 15 * s + high * 0.4, Col(0xc8c8c4).shade(1 - dark * 0.4))
            let wv = sin(NOW * 5) * 0.9 * s
            let a = FLAGS[g.flag % FLAGS.count]
            c.poly(a.0.shade(1 - dark * 0.4), [fx, ty, fx - dir * 5 * s, ty + 0.4 * s + wv, fx - dir * 10 * s, ty + wv * 0.4, fx - dir * 10 * s, ty + 6 * s + wv * 0.4, fx - dir * 5 * s, ty + 6.4 * s + wv, fx, ty + 6 * s])
            c.poly(a.1.shade(1 - dark * 0.4), [fx, ty + 2 * s, fx - dir * 5 * s, ty + 2.4 * s + wv, fx - dir * 10 * s, ty + 2 * s + wv * 0.4, fx - dir * 10 * s, ty + 4 * s + wv * 0.4, fx - dir * 5 * s, ty + 4.4 * s + wv, fx, ty + 4 * s])
        }
    }
    /// The flag you picked flies from a whip on your toy too.
    private func toyFlag(_ x: Double, _ y: Double, _ dir: Double) {
        if g.flag <= 0 { return }
        let fx = x - dir * 9, ty = y - 27
        c.seg(fx, y - 8, fx - dir * 0.8, ty, 0.3, Col(0xc8c8c4))
        let wv = sin(NOW * 6) * 0.7
        let a = FLAGS[g.flag % FLAGS.count]
        c.poly(a.0.shade(1 - dark * 0.4), [fx - dir * 0.8, ty, fx - dir * 7, ty + 0.6 + wv, fx - dir * 7, ty + 4.2 + wv, fx - dir * 0.8, ty + 4])
        c.poly(a.1.shade(1 - dark * 0.4), [fx - dir * 0.8, ty + 1.4, fx - dir * 7, ty + 1.9 + wv, fx - dir * 7, ty + 3 + wv, fx - dir * 0.8, ty + 2.7])
    }
    private func customOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.6))
        g.hits.append(Hit(id: -2, x: 0, y: 0, w: W, h: H))
        let pw = 230.0, ph = min(H - 12, 150.0), x0 = W / 2 - pw / 2, y0 = (H - ph) / 2
        c.RR(x0, y0, pw, ph, 6, Col(0xeadfc4))
        g.hits.append(Hit(id: 62, x: x0, y: y0, w: pw, h: ph))
        let ink = Col(0x3a2c1e)
        g.text("MAKE IT YOURS", x0 + 10, y0 + 10, 7, ink, align: 1, bold: true)
        g.text("tap outside to finish", x0 + pw - 10, y0 + 10, 3.4, ink.alpha(0.6), align: 2)
        let def = RIGS[g.rig.rawValue]
        let sc = min(1.0, 150 / def.len)
        c.RR(x0 + 10, y0 + 18, pw - 20, ph - 74, 3, Col(0xbfd8e8))
        c.R(x0 + 10, y0 + ph - 64, pw - 20, 8, Col(0xd8bc90))
        rig(g.rig, W / 2, y0 + ph - 62, g.panels, 1, sc)
        rigCustom(W / 2, y0 + ph - 62, def, 1, sc)
        g.text("Stripe", x0 + 12, y0 + ph - 41, 4.2, ink, align: 1, bold: true)
        for q in 0..<8 {
            let bx = x0 + 44 + Double(q) * 22
            c.RR(bx, y0 + ph - 48, 18, 13, 3, q == 0 ? Col(0xffffff, 0.6) : STRIPES[q])
            if q == 0 { g.text("none", bx + 9, y0 + ph - 41.4, 3, ink) }
            if q == g.stripe { c.RR(bx - 1.2, y0 + ph - 49.2, 20.4, 15.4, 3.6, GOLD.alpha(0.0)); c.R(bx + 2, y0 + ph - 34, 14, 1.4, ink) }
            g.hits.append(Hit(id: 310 + q, x: bx - 2, y: y0 + ph - 50, w: 22, h: 18))
        }
        g.text("Flag", x0 + 12, y0 + ph - 19, 4.2, ink, align: 1, bold: true)
        for q in 0..<7 {
            let bx = x0 + 44 + Double(q) * 22
            c.RR(bx, y0 + ph - 26, 18, 13, 3, q == 0 ? Col(0xffffff, 0.6) : FLAGS[q].0)
            if q > 0 { c.R(bx, y0 + ph - 21.6, 18, 4.2, FLAGS[q].1) } else { g.text("none", bx + 9, y0 + ph - 19.4, 3, ink) }
            if q == g.flag { c.R(bx + 2, y0 + ph - 12, 14, 1.4, ink) }
            g.hits.append(Hit(id: 320 + q, x: bx - 2, y: y0 + ph - 28, w: 22, h: 18))
        }
    }

    /// A real desert wash now and then: a pale sandy channel cutting across the flat, cut banks, cobbles, drift, trees along it.
    private func washes() {
        let ar = g.area
        if [Area.main, .tyson, .intaglios].contains(ar) { return }
        for k in 0..<2 {
            let hk = hashN(Double(ar.rawValue) * 3.7 + Double(k) * 11 + 9800)
            if hk < 0.25 { continue }
            let wx = g.WORLD * (k == 0 ? 0.2 + hk * 0.14 : 0.62 + hk * 0.16)
            if g.spots.contains(where: { abs($0.x - wx) < 110 }) { continue }
            let sx = wx - cam
            if sx < -140 || sx > W + 140 { continue }
            let d = H - GY
            let lean = (hk - 0.5) * 90
            let tl = sx - 20, tr = sx + 20, bl = sx - 44 + lean, br = sx + 44 + lean
            let sand = Col(0xf0e0bc).shade(1 - dark * 0.5)
            c.poly(sand, [tl, GY, tr, GY, br, H, bl, H])
            c.seg(tl, GY, bl, H, 1.6, Col(0x8a6a48, 0.8).shade(1 - dark * 0.5))
            c.seg(tl - 1.4, GY, bl - 2.4, H, 0.6, Col(0xf8ecd0, 0.6))
            c.seg(tr, GY, br, H, 1.1, Col(0xa8845c, 0.7).shade(1 - dark * 0.5))
            for q in 0..<22 {
                let dq = Double(q)
                let v = hashN(dq + hk * 100 + 9810), uu = 0.08 + hashN(dq + hk * 100 + 9820) * 0.84
                let lx = tl + (bl - tl) * v, rx = tr + (br - tr) * v
                let px = lx + (rx - lx) * uu, py = GY + v * d
                if q % 3 == 0 { c.seg(px - 3, py, px + 3, py + 0.5, 0.3, Col(0xc8b088, 0.7)) }
                else { let r = 0.5 + hashN(dq + 9830) * (0.8 + v * 1.4); c.ell(px, py, r, r * 0.7, [Col(0x8a8078), Col(0xb0a090), Col(0x6a5a50)][q % 3].shade(1 - dark * 0.5)) }
            }
            let vd = 0.55
            c.roundCaps(true)
            c.seg(tl + (bl - tl) * vd + 6, GY + vd * d, tl + (bl - tl) * vd + 22, GY + vd * d - 1.6, 1.2, Col(0x9a8a78).shade(1 - dark * 0.5))
            c.seg(tl + (bl - tl) * vd + 14, GY + vd * d - 0.8, tl + (bl - tl) * vd + 17, GY + vd * d - 3.4, 0.5, Col(0x9a8a78).shade(1 - dark * 0.5))
            c.roundCaps(false)
            if g.weather == 3 && g.phase == .play {
                c.poly(Col(0x8a6a48, 0.75), [tl + 3, GY, tr - 3, GY, br - 6, H, bl + 6, H])
            }
            if !g.iceAge && !g.deep { paloverde(sx - 38, GY + 1, hk * 50 + 3); ironwood(sx + 40, GY + 1, hk * 70 + 5, 0.8); mesquite(sx + 4, GY + 1, hk * 90 + 7, 0.5) }
        }
    }

    /// The small stuff lying around: fire rings, cairns, old tires, signs and stakes out in the desert; street furniture in town.
    private func clutter() {
        if g.inPast || g.phase == .title { return }
        let ar = g.area
        let town = ar == .main || ar == .tyson
        let cell = town ? 74.0 : 96.0
        let sh = 1 - dark * 0.5
        var n = floor((cam - 40) / cell)
        while n * cell < cam + W + 40 {
            let hk = hashN(n * 1.7 + Double(ar.rawValue) * 13 + 9900)
            let wx = n * cell + hashN(n + 9910) * (cell - 20)
            n += 1
            if hk < 0.3 || wx < 60 || wx > g.WORLD - 60 { continue }
            if g.spots.contains(where: { abs($0.x - wx) < (town ? 52 : 44) }) { continue }
            let x = wx - cam, b = GY + 1
            let kind = Int(hk * 1000) % 12
            if town {
                switch kind {
                case 0, 1:
                    c.RR(x - 2, b - 7, 4, 7, 0.6, [Col(0x2e5a9a), Col(0xc8281e)][kind].shade(sh)); c.R(x - 1.4, b - 6, 2.8, 2.2, Col(0xe8e8e0).shade(sh))
                case 2:
                    c.RR(x - 2.2, b - 6, 4.4, 6, 1, Col(0x4a6a4a).shade(sh)); c.R(x - 2.6, b - 6.6, 5.2, 0.9, Col(0x3a4a3a).shade(sh))
                case 3:
                    c.RR(x - 1.2, b - 5, 2.4, 5, 0.8, Col(0xd9a81e).shade(sh)); c.R(x - 2, b - 3.6, 4, 1, Col(0xd9a81e).shade(sh)); c.dome(x, b - 5, 1.3, Col(0xd9a81e).shade(sh))
                case 4:
                    c.R(x - 7, b - 4, 14, 1, Col(0x8a6238).shade(sh)); c.R(x - 7, b - 7.4, 14, 0.9, Col(0x8a6238).shade(sh)); c.R(x - 6, b - 4, 0.8, 4, Col(0x3a3a3e)); c.R(x + 5.2, b - 7.4, 0.8, 7.4, Col(0x3a3a3e)); c.R(x - 6, b - 7.4, 0.8, 3.4, Col(0x3a3a3e))
                case 5:
                    c.poly(Col(0x8a5a32).shade(sh), [x - 3.4, b, x - 4, b - 4.4, x + 4, b - 4.4, x + 3.4, b])
                    for q in 0..<5 { c.circ(x - 3 + Double(q) * 1.5, b - 5.4 - Double(q % 2), 1.1, [Col(0xe25a8a), Col(0xf2c14e), Col(0xd9412e)][q % 3].shade(sh)) }
                case 6:
                    c.poly(Col(0xf4f4f0).shade(sh), [x - 3, b, x, b - 8, x + 3, b]); c.R(x - 1.6, b - 5, 3.2, 1.6, Col(0xc8281e).shade(sh))
                case 7:
                    c.poly(Col(0xe8782e).shade(sh), [x - 1.8, b, x - 0.5, b - 5, x + 0.5, b - 5, x + 1.8, b]); c.R(x - 1.1, b - 3.2, 2.2, 0.9, Col(0xf4f4f0))
                case 8:
                    for q in 0..<4 { c.arcStroke(x - 4.5 + Double(q) * 3, b - 0.2, 1.6, PI, PI * 2, 0.4, Col(0x8a8f96)) }
                case 9:
                    c.R(x - 0.4, b - 8, 0.8, 8, Col(0x6a5238).shade(sh)); c.RR(x - 2.6, b - 11, 5.2, 3.4, 1.4, Col(0x3a3a3e).shade(sh)); c.R(x + 2.4, b - 11.6, 0.4, 2, Col(0xc8281e))
                case 10:
                    c.RR(x - 3, b - 8, 6, 8, 0.8, Col(0xe8e8e8).shade(sh)); c.R(x - 2.2, b - 7, 4.4, 3.4, Col(0x7ab0e0).shade(sh)); g.text("ICE", x, b - 2.4, 1.8, Col(0x2e5a9a), bold: true)
                default:
                    c.RR(x - 2, b - 5.4, 4, 5.4, 1.6, Col(0xf0f0ea).shade(sh)); c.R(x - 1, b - 6.4, 2, 1, Col(0x8a8f96))
                }
            } else {
                switch kind {
                case 0, 1:
                    for q in 0..<8 { let a = Double(q) / 8 * PI * 2; c.ell(x + cos(a) * 4, b + 3 + sin(a) * 1.4, 1.1, 0.8, Col(0x7a6a5e).shade(sh)) }
                    c.ell(x, b + 3, 2.4, 0.9, Col(0x2a2420)); c.seg(x - 1.6, b + 3, x + 1.8, b + 2.4, 0.5, Col(0x4a3a30))
                case 2:
                    c.ell(x, b - 1, 3.4, 1.6, Col(0x8a7a6a).shade(sh)); c.ell(x + 0.4, b - 3.2, 2.4, 1.2, Col(0x9a8a78).shade(sh)); c.ell(x - 0.2, b - 4.8, 1.6, 0.9, Col(0x7a6a5e).shade(sh)); c.ell(x, b - 6, 0.9, 0.6, Col(0xa89a88).shade(sh))
                case 3:
                    c.ellStroke(x, b - 2.6, 2.6, 2.6, 1.4, Col(0x1c1a1a)); c.ell(x + 5, b + 0.4, 3, 1, Col(0x1c1a1a))
                case 4:
                    c.R(x - 0.5, b - 12, 1, 12, Col(0x6a4a2e).shade(sh)); c.RR(x - 8, b - 20, 16, 9, 1, Col(0x6a4a2e).shade(sh))
                    g.text("14 DAY", x, b - 17.4, 2.2, Col(0xf2e8c8), bold: true); g.text("LIMIT", x, b - 14, 2.2, Col(0xf2e8c8), bold: true)
                case 5:
                    c.ell(x, b + 1, 2.2, 1.4, Col(0xeeeadc).shade(sh)); c.curve(x - 2, b + 0.4, x - 5, b - 1.6, x - 4.4, b - 3, 0.5, Col(0xeeeadc).shade(sh)); c.curve(x + 2, b + 0.4, x + 5, b - 1.6, x + 4.4, b - 3, 0.5, Col(0xeeeadc).shade(sh)); c.circ(x - 0.8, b + 0.6, 0.4, INK); c.circ(x + 0.8, b + 0.6, 0.4, INK)
                case 6:
                    c.R(x - 0.3, b - 7, 0.6, 7, Col(0xd8c8a0).shade(sh)); c.poly(Col(0xff5a9a), [x + 0.3, b - 7, x + 3.4, b - 6 + sin(NOW * 5 + wx) * 0.5, x + 0.3, b - 5])
                case 7:
                    // a desert tortoise, in no hurry
                    let tx = x + sin(NOW * 0.08 + wx) * 10
                    c.dome(tx, b + 1.6, 3, Col(0x6a6a3e).shade(sh)); c.circ(tx + 3.4, b + 0.8, 0.9, Col(0x8a8a5a).shade(sh)); c.R(tx - 2.2, b + 1.4, 1, 1, Col(0x5a5a34)); c.R(tx + 1.2, b + 1.4, 1, 1, Col(0x5a5a34))
                case 8:
                    for q in 0..<5 { c.R(x - 5, b - 1.2 - Double(q) * 1.3, 10, 1.1, (q % 2 == 0 ? Col(0x8a6238) : Col(0x7a5228)).shade(sh)) }
                case 9:
                    c.poly(Col(0xf0f0f4).shade(sh), [x - 4, b + 1, x - 2.4, b - 4, x + 1, b - 5.4, x + 4, b - 2, x + 4.6, b + 1]); c.poly(Col(0xffffff, 0.8), [x - 2.4, b - 4, x + 1, b - 5.4, x + 0.4, b - 2.6])
                case 10:
                    c.RR(x - 1.6, b - 4.4, 3.2, 4.4, 0.6, Col(0x2e5a9a).shade(sh)); c.RR(x + 2.4, b - 3.6, 2.6, 3.6, 0.5, Col(0xc8281e).shade(sh)); c.R(x + 3, b - 4.4, 1, 0.8, Col(0xf2c14e))
                default:
                    c.ell(x, b + 2, 3.6, 1, Col(0x6a4e30).shade(sh)); for q in 0..<5 { c.circ(x - 2 + Double(q), b + 1.6, 0.25, INK) }
                }
            }
        }
    }

    /// Gold Nugget Road, past the cleanup at Dome Rock: two-tracks branching everywhere, tailings, a headframe,
    /// stone ruins, rusted iron, prospect holes, and claim posts.
    private func goldPlant(_ sx: Double, _ k: Double, _ n: Double) {
        if k < 0.36 {
            if hashN(n + 91) < 0.08 { sagSkeleton(sx, GY + 1, 30 + hashN(n + 5) * 24, n) } else { saguaro(sx, GY + 1, 30 + hashN(n + 5) * 36, n, SAG, true) }
        }
        else if k < 0.52 { paloverde(sx, GY + 1, n) }
        else if k < 0.64 { ironwood(sx, GY + 1, n) }
        else if k < 0.75 { mesquite(sx, GY + 1, n) }
        else if k < 0.81 { barrel(sx, GY + 1, 0.9 + hashN(n + 8) * 0.6, n) }
        else if k < 0.9 {
            // teddy bear cholla comes in patches, a few big ones and their dropped joints rooting around them
            let cnt = 3 + Int(hashN(n + 9) * 3)
            for q in 0..<cnt { cholla(sx + (Double(q) - Double(cnt) / 2) * 7 + hashN(n + Double(q)) * 3, GY + 1 + Double(q % 2), 0.6 + hashN(n + Double(q) + 6) * 0.6, n + Double(q)) }
        }
        else if k < 0.95 { creosote(sx, GY + 1, n) }
        else { brittlebush(sx, GY + 1, n) }
    }
    private func goldRoad() {
        let x0 = 2640.0
        if cam + W < x0 - 140 { return }
        let sh = 1 - dark * 0.5
        // the mountains close in: a dark volcanic range behind, rocky foothills in front, saguaros standing all over the slopes
        for layer in 0..<2 {
            let step = layer == 0 ? 70.0 : 46.0
            let col = (layer == 0 ? Col(0x6e5246) : Col(0x8a6850)).shade(1 - dark * 0.55)
            var pts: [Double] = []
            var tops: [(Double, Double)] = []
            let a = max(0, floor((cam - 200 - x0) / step)), b = floor((cam + W + 200 - x0) / step)
            if b < a { continue }
            var i = a
            pts.append(x0 + (a - 1) * step - cam); pts.append(GY + 1)
            while i <= b {
                let wx = x0 + i * step
                let ramp = min(1, (wx - x0 + 40) / 260)
                let hh = (layer == 0 ? 46 + hashN(i * 1.7 + 9200) * 52 : 16 + hashN(i * 2.3 + 9300) * 30) * ramp
                pts.append(wx - cam); pts.append(GY - hh)
                tops.append((wx - cam, hh))
                i += 1
            }
            pts.append(x0 + (b + 1) * step - cam); pts.append(GY + 1)
            if pts.count >= 8 { massif(pts, col) }
            for (q, t) in tops.enumerated() where t.1 > 12 {
                for r in 0..<3 {
                    let d = Double(q) * 3 + Double(r) + Double(layer) * 50 + floor(a)
                    let px = t.0 + (hashN(d + 9400) - 0.5) * step * 0.8
                    let py = GY - t.1 * (0.15 + hashN(d + 9410) * 0.45)
                    let hgt = layer == 0 ? 4.0 : 6.5
                    c.R(px - 0.4, py - hgt, 0.9, hgt, Col(0x4a6a3e).shade(1 - dark * 0.5))
                    if r != 1 { c.R(px - 1.6, py - hgt * 0.6, 1.3, 0.5, Col(0x4a6a3e).shade(1 - dark * 0.5)); c.R(px - 1.6, py - hgt * 0.8, 0.5, hgt * 0.25, Col(0x4a6a3e).shade(1 - dark * 0.5)) }
                    if layer == 1 { c.ell(px + 4, py + 1, 2.6, 1.4, Col(0x5e463a).shade(1 - dark * 0.5)); c.ell(px + 3.4, py + 0.4, 1.4, 0.6, Col(0xa88a70).shade(1 - dark * 0.5)) }
                }
            }
        }
        // boulders and outcrops shouldering up along the track
        var bn = max(0, floor((cam - 60 - x0) / 58))
        while x0 + bn * 58 < cam + W + 60 {
            let wx = x0 + 30 + bn * 58 + hashN(bn + 9500) * 30
            let hk = hashN(bn + 9510)
            if !g.spots.contains(where: { abs($0.x - wx) < 40 }) {
                rock(wx - cam, GY + 1, 3 + hk * 5)
                if hk > 0.5 { rock(wx - cam + 7, GY + 1.6, 2 + hk * 2); rock(wx - cam - 5, GY + 2, 1.6 + hk) }
            }
            bn += 1
        }
        let d = H - GY
        let sgn = x0 + 60 - cam
        c.R(sgn - 0.5, GY - 26, 1, 27, Col(0x8a8f96))
        c.RR(sgn - 20, GY - 31, 40, 7, 1, Col(0x2e6a3e).shade(sh))
        g.text("GOLD NUGGET RD", sgn, GY - 27.4, 2.8, CREAM, bold: true)
        // two-tracks wandering off across the flat and forking
        let track = Col(0xf0dcb4, 0.5).shade(sh)
        var n = floor((cam - x0 - 120) / 170)
        while x0 + n * 170 < cam + W + 120 {
            if n >= 0 {
                let wx = x0 + n * 170 + hashN(n + 9950) * 60
                let sx = wx - cam
                let lean = (hashN(n + 9951) - 0.5) * 120
                for o in [-1.6, 1.6] {
                    c.curve(sx + o, GY + 0.5, sx + lean * 0.3 + o * 1.6, GY + d * 0.5, sx + lean + o * 3, H, 0.8, track)
                }
                if hashN(n + 9952) < 0.6 {
                    let fx = sx + lean * 0.25, fy = GY + d * 0.4
                    for o in [-1.2, 1.2] { c.curve(fx + o, fy, fx + 40, fy + d * 0.1 + o, fx + 90, fy + d * 0.3 + o * 2, 0.6, track) }
                }
                // what the miners left
                let px = sx + 70
                switch Int(hashN(n + 9953) * 6) % 6 {
                case 0:
                    // a tailings pile with a prospect hole
                    c.poly(Col(0xb89a78).shade(sh), [px - 20, GY + 1, px - 8, GY - 10, px + 6, GY - 12, px + 22, GY + 1])
                    c.poly(Col(0xd0b490).shade(sh), [px - 8, GY - 10, px + 6, GY - 12, px + 2, GY - 5])
                    c.ell(px + 30, GY + 4, 5, 1.6, Col(0x1c1410))
                case 1:
                    // a wooden headframe over a shaft, fenced with rusty wire
                    let tim = Col(0x6a4a2e).shade(sh)
                    c.seg(px - 8, GY + 1, px - 3, GY - 26, 1.2, tim); c.seg(px + 8, GY + 1, px + 3, GY - 26, 1.2, tim)
                    c.seg(px - 4, GY - 26, px + 4, GY - 26, 1.2, tim); c.seg(px - 6.4, GY - 10, px + 6.4, GY - 10, 0.8, tim); c.seg(px - 6.4, GY - 10, px + 4.4, GY - 18, 0.6, tim)
                    c.circ(px, GY - 24, 1.8, Col(0x5a4a40)); c.seg(px, GY - 22, px, GY + 1, 0.3, Col(0x3a3a3a))
                    c.ell(px, GY + 2, 6, 1.6, Col(0x1c1410))
                    for q in 0..<4 { c.R(px - 16 + Double(q) * 10.6, GY - 6, 0.5, 7, Col(0x8a5a3a)) }
                    c.seg(px - 16, GY - 4, px + 16, GY - 4, 0.25, Col(0x8a5a3a)); c.seg(px - 16, GY - 1.6, px + 16, GY - 1.6, 0.25, Col(0x8a5a3a))
                case 2:
                    // a roofless stone cabin
                    let st = Col(0x9a8068).shade(sh)
                    c.poly(st, [px - 16, GY + 1, px - 16, GY - 12, px - 10, GY - 15, px - 6, GY - 11, px - 6, GY - 5, px + 2, GY - 5, px + 2, GY - 13, px + 12, GY - 10, px + 14, GY + 1])
                    for q in 0..<10 { c.seg(px - 15 + hashN(Double(q) + 9960) * 26, GY - 2 - hashN(Double(q) + 9961) * 8, px - 12 + hashN(Double(q) + 9960) * 26, GY - 2 - hashN(Double(q) + 9961) * 8, 0.3, st.shade(0.75)) }
                    c.seg(px - 20, GY + 1, px - 30, GY - 1, 0.8, Col(0x6a4a2e).shade(sh))
                case 3:
                    // an ore cart off its rails, and a boiler rusting in the sun
                    c.poly(Col(0x7a4a32).shade(sh), [px - 8, GY - 8, px + 6, GY - 8, px + 4, GY - 2, px - 6, GY - 2]); c.circ(px - 4, GY - 0.6, 1.4, Col(0x2a2420)); c.circ(px + 2, GY - 0.6, 1.4, Col(0x2a2420))
                    c.RR(px + 16, GY - 7, 18, 7, 3.4, Col(0x8a4a2a).shade(sh)); c.R(px + 22, GY - 12, 2.4, 5.4, Col(0x7a4028).shade(sh)); for q in 0..<4 { c.circ(px + 19 + Double(q) * 4, GY - 3.6, 0.4, Col(0x3a2418)) }
                case 4:
                    // claim posts and a stacked-rock corner marker
                    c.R(px - 0.6, GY - 12, 1.2, 13, Col(0xf0f0ea).shade(sh)); c.RR(px - 5, GY - 17, 10, 5.4, 0.6, Col(0xf0f0ea).shade(sh))
                    g.text("CLAIM", px, GY - 14.2, 1.9, REDC, bold: true)
                    for q in 0..<4 { c.ell(px + 24, GY - Double(q) * 2.2, 3.4 - Double(q) * 0.6, 1.3, Col(0x8a7a6a).shade(sh - Double(q) * 0.03)) }
                default:
                    // an old truck gone to rust, and a rocker box
                    c.poly(Col(0x8a4a2a).shade(sh), [px - 14, GY - 2, px - 14, GY - 8, px - 4, GY - 8, px - 2, GY - 13, px + 8, GY - 13, px + 10, GY - 8, px + 16, GY - 7, px + 16, GY - 2])
                    c.RR(px - 0.6, GY - 12, 7, 3.6, 0.5, Col(0x2a2420)); c.ellStroke(px - 8, GY - 1.6, 2.4, 2.4, 0.8, Col(0x2a2420))
                    c.poly(Col(0x8a6238).shade(sh), [px + 26, GY + 1, px + 28, GY - 5, px + 42, GY - 3, px + 42, GY + 1])
                }
                // quartz float and dark desert-varnished rock scattered thick out here
                for q in 0..<10 {
                    let dq = Double(q)
                    let rx = sx + hashN(n * 7 + dq + 9970) * 170, ry = GY + 2 + hashN(n * 5 + dq + 9971) * (d - 4)
                    let r = 0.6 + hashN(n + dq + 9972) * 1.6
                    c.ell(rx, ry, r, r * 0.7, (q % 4 == 0 ? Col(0xf0f0f4) : Col(0x4e3e36)).shade(sh))
                }
            }
            n += 1
        }
    }

    private func signs_band(_ n: Double) -> Col {
        return [Col(0xb5452f), Col(0x2f5a7a), Col(0x3f8f6a), Col(0x7a4a8a), Col(0xd9a02e)][Int(hashN(n + 1365) * 5) % 5]
    }

    /// Five million years back: warm and wet. Fan palms, cottonwood, tall grass, reeds.
    private func deepPlant(_ sx: Double, _ k: Double, _ n: Double) {
        if k < 0.24 { palm(sx, GY + 1, 26 + hashN(n + 5) * 22, n) }
        else if k < 0.4 { cottonwood(sx, GY + 1, n) }
        else if k < 0.52 { mesquite(sx, GY + 1, n) }
        else if k < 0.76 {
            for q in 0..<10 { c.seg(sx + Double(q) - 5, GY + 1, sx + (Double(q) - 5) * 1.7 + sin(NOW * 1.5 + Double(q)) * 0.5, GY - 6 - hashN(n + Double(q)) * 5, 0.4, (q % 2 == 0 ? Col(0x6a9a4a) : Col(0x9ab05a)).shade(1 - dark * 0.45)) }
        } else if k < 0.9 {
            for q in 0..<7 {
                let rx = sx + Double(q) * 1.6 - 5
                c.seg(rx, GY + 1, rx + sin(NOW + Double(q)) * 0.6, GY - 11 - hashN(n + Double(q)) * 4, 0.35, Col(0x5a8a4a).shade(1 - dark * 0.45))
                if q % 2 == 0 { c.RR(rx - 0.5, GY - 13 - hashN(n + Double(q)) * 4, 1, 3, 0.5, Col(0x6a4a2e).shade(1 - dark * 0.45)) }
            }
        } else { juniper(sx, GY + 1, 0.9, n) }
    }
    /// A four-tusked gomphothere: an elephant cousin, lower and longer in the head, with short straight tusks above and below.
    private func gomphothere(_ x: Double, _ base: Double, _ s: Double, _ ph: Double) {
        if x < -40 * s || x > W + 40 * s { return }
        let hide = Col(0x7a6a5e).shade(1 - dark * 0.5)
        let sw = sin(NOW * 1.2 + ph) * s
        c.roundCaps(true)
        let legs: [(Double, Double)] = [(-8, sw), (-4, -sw), (6, -sw), (10, sw)]
        for (lx, s0) in legs { c.seg(x + lx * s, base - 10 * s, x + lx * s + s0, base, 3.2 * s, hide.shade(0.84)) }
        c.ell(x, base - 14 * s, 13 * s, 7 * s, hide)
        c.ell(x + 13 * s, base - 16 * s, 6 * s, 5 * s, hide.shade(1.05))
        c.ell(x + 9.6 * s, base - 16 * s, 2.6 * s, 3.4 * s, hide.shade(0.86))
        c.curve(x + 18 * s, base - 14 * s, x + 23 * s, base - 8 * s, x + 21 * s + sin(NOW * 0.8 + ph) * 2 * s, base - 3 * s, 2.2 * s, hide.shade(1.05))
        c.seg(x + 17 * s, base - 13.4 * s, x + 26 * s, base - 11.4 * s, 1 * s, Col(0xf0e8d8).shade(1 - dark * 0.4))
        c.seg(x + 16.6 * s, base - 11.4 * s, x + 23 * s, base - 8.6 * s, 0.9 * s, Col(0xf0e8d8).shade(1 - dark * 0.4))
        c.circ(x + 15 * s, base - 17.4 * s, 0.6 * s, INK)
        c.seg(x - 12.6 * s, base - 16 * s, x - 14 * s, base - 9 * s, 0.7 * s, hide.shade(0.8))
        c.roundCaps(false)
    }
    private func deepWild(_ ar: Area) {
        if dark > 0.5 { return }
        // birds over the water, and something always moving along the shore
        for k in 0..<7 {
            let bx = (NOW * 9 + Double(k) * 23).truncatingRemainder(dividingBy: W + 80) - 40
            let by = GY - 26 - Double(k % 3) * 5 + sin(NOW * 2 + Double(k)) * 1.6
            let f = sin(NOW * 9 + Double(k)) * 1.6
            c.seg(bx - 2.4, by - f, bx, by, 0.4, Col(0xf4f4f0)); c.seg(bx, by, bx + 2.4, by - f, 0.4, Col(0xf4f4f0))
        }
        if [Area.main, .tyson, .hijolly, .roadrunner, .ltva].contains(ar) {
            let hx = (NOW * 4).truncatingRemainder(dividingBy: g.WORLD + 400) - 200
            for k in 0..<3 { gomphothere(hx + Double(k) * 50 - cam, GY + 2, 0.75 + Double(k % 2) * 0.25, Double(k) * 1.4) }
        } else {
            let hx = g.WORLD - (NOW * 13).truncatingRemainder(dividingBy: g.WORLD + 400) + 200
            for k in 0..<7 { hoofed(hx + Double(k) * 15 - cam, GY + 2 + Double(k % 2), 0.8, 2, Double(k)) }
        }
    }
    private func deepSight(_ k: Int, _ x: Double) {
        let base = GY + 1
        let sh = 1 - dark * 0.5
        switch k {
        case 0:
            // wave-rippled sand and a line of wrack
            for q in 0..<9 { c.curve(x - 60 + Double(q) * 14, base + 3 + Double(q % 3), x - 53 + Double(q) * 14, base + 1.6 + Double(q % 3), x - 46 + Double(q) * 14, base + 3 + Double(q % 3), 0.4, Col(0xc8b088, 0.8)) }
            for q in 0..<12 { c.ell(x - 50 + hashN(Double(q) + 9070) * 100, base + 0.6, 1.2, 0.5, [Col(0x5a7a4a), Col(0xf0e8d8), Col(0x8a6a4a)][q % 3].shade(sh)) }
        case 1:
            gomphothere(x - 28, base, 1.1, 0); gomphothere(x + 30, base, 0.9, 1.7); cottonwood(x + 2, base, 9080)
        case 2:
            for q in 0..<6 { hoofed(x - 44 + Double(q) * 17, base + Double(q % 2), 0.85, 2, Double(q) * 1.1) }
        case 3:
            c.ell(x, base - 1, 9, 2.4, Col(0x8a6a58).shade(sh)); for q in 0..<5 { c.arcStroke(x - 4 + Double(q) * 2, base - 2, 2.6, PI * 1.1, PI * 1.9, 0.5, Col(0xf0e8d8).shade(sh)) }
            for q in 0..<3 {
                c.save(); c.translate(x - 22 + Double(q) * 22, base + 1 + Double(q % 2)); c.scale(1.7, 1.5)
                coyote(0, 0, NOW * 2 + Double(q))
                c.restore()
            }
        case 4:
            c.R(x - 70, base + 3, 140, 4.4, Col(0x8a7a66, 0.6))
            for q in 0..<8 { c.ell(x - 60 + Double(q) * 17, base + 5, 6, 0.8, Col(0x4a9ab8, 0.6)) }
            c.poly(Col(0x6a5e56).shade(sh), [x - 12, base + 1, x - 8, base - 7, x + 4, base - 9, x + 12, base + 1])
            for q in 0..<12 { c.circ(x - 8 + hashN(Double(q) + 9090) * 16, base - 1 - hashN(Double(q) + 9091) * 6, 0.6, Col(0xe8e0d0).shade(sh)) }
        case 5:
            let tx = x + sin(NOW * 0.07) * 12
            c.dome(tx, base, 11, Col(0x6a6a3e).shade(sh)); c.dome(tx, base, 8, Col(0x7a7a48).shade(sh))
            for q in 0..<4 { c.seg(tx - 7 + Double(q) * 4.6, base - 9 + abs(Double(q) - 1.5) * 2, tx - 7 + Double(q) * 4.6, base - 1, 0.3, Col(0x4a4a2a)) }
            c.seg(tx + 10, base - 4, tx + 16, base - 7, 2.2, Col(0x8a8a5a).shade(sh)); c.circ(tx + 16.6, base - 7.6, 1.8, Col(0x8a8a5a).shade(sh)); c.circ(tx + 17.2, base - 8, 0.3, INK)
            c.R(tx - 8, base - 1, 2.6, 2.2, Col(0x5a5a34)); c.R(tx + 5, base - 1, 2.6, 2.2, Col(0x5a5a34))
        case 6:
            for q in 0..<3 {
                let cx = x - 30 + Double(q) * 30
                hoofed(cx, base + Double(q % 2), 2.1, 2, Double(q) * 1.3)
                c.ell(cx - 1.4, base - 27, 6, 4, Col(0x9a8468).shade(sh))
                c.seg(cx + 10, base - 26, cx + 15, base - 40, 3, Col(0x9a8468).shade(sh)); c.ell(cx + 16.4, base - 41, 3.4, 2, Col(0x9a8468).shade(sh))
            }
        case 7:
            for q in 0..<16 {
                let d = Double(q)
                let bx = x - 54 + d * 7 + sin(NOW * 0.5 + d) * 2
                c.seg(bx, base + 1, bx, base - 4, 0.25, Col(0x3a3a3a)); c.ell(bx, base - 5, 1.6, 1, (q % 3 == 0 ? Col(0xe89a9a) : Col(0xf4f4f0)).shade(sh))
                c.seg(bx + 1, base - 5.6, bx + 2.4, base - 7.6 + (sin(NOW * 3 + d) > 0.4 ? 5.0 : 0.0), 0.3, Col(0xf4f4f0).shade(sh))
            }
        case 8:
            c.poly(Col(0x7a6a5a).shade(sh), [x - 34, base, x - 22, base - 20, x + 12, base - 24, x + 32, base])
            cat(x - 4, base - 23, 1.35, Col(0xc0985e), true, false, false)
        case 9:
            for q in 0..<6 { palm(x - 52 + Double(q) * 21, base, 26 + hashN(Double(q) + 9100) * 20, Double(q) + 9110) }
        case 10:
            for q in 0..<5 {
                let px = x - 36 + Double(q) * 18
                hoofed(px, base + Double(q % 2), 0.75, 0, Double(q))
                c.seg(px + 5.6, base - 12.6, px + 5, base - 16, 0.4, INK); c.seg(px + 5, base - 16, px + 6.4, base - 17.4, 0.4, INK); c.seg(px + 5, base - 16, px + 3.8, base - 17.6, 0.4, INK)
            }
        case 11:
            for q in 0..<2 {
                let rx = x - 20 + Double(q) * 40
                let hide = Col(0x8a8078).shade(sh)
                c.roundCaps(true)
                for lx in [-7.0, -3.0, 5.0, 9.0] { c.seg(rx + lx, base - 4, rx + lx, base + 1, 3, hide.shade(0.85)) }
                c.ell(rx, base - 8, 13, 6.4, hide); c.ell(rx + 13, base - 8.4, 6, 4, hide.shade(1.05))
                c.poly(Col(0xe8e0d0).shade(sh), [rx + 17.4, base - 10, rx + 19, base - 13.4, rx + 19.6, base - 9.6])
                c.poly(hide.shade(0.9), [rx + 9.6, base - 12, rx + 10.4, base - 14.6, rx + 11.6, base - 12])
                c.circ(rx + 14.6, base - 9.6, 0.5, INK)
                c.roundCaps(false)
            }
            c.ell(x, base + 3, 46, 2.2, Col(0x4a9ab8, 0.5))
        case 12:
            cottonwood(x + 12, base, 9120)
            let fur = Col(0x8a6a48).shade(sh)
            c.roundCaps(true)
            c.ell(x - 4, base - 6, 5, 6.4, fur); c.circ(x - 2, base - 14, 2.4, fur.shade(1.05))
            c.seg(x - 2, base - 10, x + 6, base - 16 + sin(NOW * 1.5) * 1.2, 1.8, fur)
            c.seg(x - 6, base - 1, x - 6, base + 1, 2.2, fur.shade(0.85)); c.seg(x - 2, base - 1, x - 2, base + 1, 2.2, fur.shade(0.85))
            c.seg(x - 8, base - 3, x - 14, base, 2, fur.shade(0.85))
            c.roundCaps(false)
        default:
            c.ell(x, base + 4, 60, 3.4, Col(0x4aa0c0, 0.75))
            for q in 0..<14 {
                let d = Double(q)
                let fx = x - 50 + ((NOW * (4 + hashN(d) * 4) + d * 9).truncatingRemainder(dividingBy: 100))
                let fy = base + 3 + hashN(d + 9130) * 2
                c.ell(fx, fy, 1.6, 0.5, Col(0xd8e8f0)); c.poly(Col(0xd8e8f0), [fx - 1.4, fy, fx - 2.6, fy - 0.7, fx - 2.6, fy + 0.7])
            }
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
        let y = GY - (g.spots[i].kind == .gemworld ? 90.0 : 68.0)
        guard let o = g.offer(i) else {
            g.text(g.note(i), x, y, 5, CREAM, plate: true)
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
        // the words sit above the ring on a dark plate, clear of shop signs and place names below
        g.text(o.label, x, y - 19, 5, CREAM, plate: true)
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
        if g.credPopT > 0 {
            // cred going up is the point of the game: make it land
            let u = clampD(g.credPopT / 1.6, 0, 1)
            let pop = sin((1 - u) * PI)
            c.glow(sx, 12.2, 18 + pop * 22, GOLD.alpha(0.55 * u), GOLD.alpha(0))
            for q in 0..<8 {
                let a = Double(q) / 8 * PI * 2 + NOW * 2
                let r0 = 6 + (1 - u) * 10, r1 = r0 + 5 * u
                c.seg(sx + cos(a) * r0, 12.2 + sin(a) * r0, sx + cos(a) * r1, 12.2 + sin(a) * r1, 1, GOLD.alpha(u))
            }
            var big: [Double] = []
            for q in 0..<10 {
                let a = -PI / 2 + Double(q) * PI / 5
                let rr = (q % 2 == 0 ? 4.0 : 1.7) * (1 + pop * 1.3)
                big.append(sx + cos(a) * rr); big.append(12.2 + sin(a) * rr)
            }
            c.poly(Col(0xfff0a0), big)
            g.text("+\(g.credPopN) cred", sx + 2, 30 - pop * 3, 8 + pop * 3, GOLD, bold: true, plate: true)
        }
        g.text("\(g.cred)", sx + 7, 12, 7, CREAM, align: 1, bold: true)
        if g.credPopT > 0 && !g.overlay {
            // and say it out loud in the middle of the screen: a starburst, a banner, stars flying up to the count
            let u = clampD(g.credPopT / 1.6, 0, 1), t = 1 - u
            let cx = W / 2, cy = H * 0.34
            c.R(0, 0, W, H, GOLD.alpha(0.2 * u * u * u))
            for q in 0..<14 {
                let a = Double(q) / 14 * PI * 2 + NOW * 0.8
                c.poly(GOLD.alpha(0.22 * u), [cx, cy, cx + cos(a) * 70, cy + sin(a) * 70, cx + cos(a + 0.12) * 70, cy + sin(a + 0.12) * 70])
            }
            for q in 0..<12 {
                let a = Double(q) / 12 * PI * 2 + 0.4
                let rr = 10 + t * 64
                let px = cx + cos(a) * rr, py = cy + sin(a) * rr * 0.6 + t * t * 26
                var st: [Double] = []
                for k in 0..<10 {
                    let b = -PI / 2 + Double(k) * PI / 5 + NOW * 3
                    let r2 = (k % 2 == 0 ? 3.0 : 1.3) * u
                    st.append(px + cos(b) * r2); st.append(py + sin(b) * r2)
                }
                c.poly([GOLD, Col(0xfff0a0), Col(0xffb040)][q % 3], st)
            }
            let fly = clampD(t * 1.8 - 0.5, 0, 1)
            if fly > 0 && fly < 1 {
                let fx = cx + (sx - cx) * fly, fy = cy + (12.2 - cy) * fly - sin(fly * PI) * 20
                c.glow(fx, fy, 9, GOLD.alpha(0.7), GOLD.alpha(0)); c.circ(fx, fy, 2.6, Col(0xfff0a0))
            }
            let grow = min(1, t * 6)
            if u > 0.25 { g.text("+\(g.credPopN) CRED", cx, cy, 10 + grow * 8, GOLD, bold: true, plate: true) }
        }
        if g.coinPopT > 0 {
            // coins arc up from where you stand and land in the purse; a big payday rains them
            let u = clampD(g.coinPopT / 1.5, 0, 1), t = 1 - u
            let cnt = min(16, 3 + g.coinPopN / 4)
            for q in 0..<cnt {
                let d = Double(q) / Double(cnt)
                let tt = t * 1.7 - d * 0.6
                if tt <= 0 || tt >= 1 { continue }
                let fx0 = W / 2 + (hashN(Double(q) + 9700) - 0.5) * 40
                let fx = fx0 + (l + 10 - fx0) * tt
                let fy = H * 0.6 + (12 - H * 0.6) * tt - sin(tt * PI) * 34
                coin(fx, fy, 3.2)
            }
            let pop = sin(min(1, t * 3) * PI)
            c.glow(l + 10, 12, 10 + pop * 10, GOLD.alpha(0.5 * u), GOLD.alpha(0))
            g.text("+\(g.coinPopN)", l + 12, 30 - pop * 2, 7 + pop * 3, GREEN, align: 1, bold: true, plate: true)
            if g.coinPopN >= 25 && !g.overlay {
                for q in 0..<18 {
                    let d = Double(q)
                    let fx = W * (0.2 + hashN(d + 9720) * 0.6)
                    let fy = -10 + (t * 1.4 - hashN(d + 9730) * 0.4) * (H * 0.9)
                    if fy > 0 && fy < H { coin(fx, fy, 2.6 + hashN(d + 9740) * 1.6) }
                }
                if u > 0.3 { g.text("+\(g.coinPopN) COINS", W / 2, H * 0.5, 11, GREEN, bold: true, plate: true) }
            }
        }

        var pack = (g.inPast ? "Winter 1026" : dateText(g.day)) + "  " + g.clockText() + "  ·  " + g.areaName(g.area)
        if g.inPast { pack = (g.deep ? "5 million years ago" : g.iceAge ? "Ice age, 11,000 BC" : "Winter 1026") + "  " + g.clockText() + "  ·  " + g.areaName(g.area) + "  ·  field notes \(g.notesHere)/\(g.notesTotal)" }
        var extras: [String] = []
        if g.wood > 0 { extras.append("firewood \(g.wood)") }
        if g.jewelry > 0 { extras.append("pendants \(g.jewelry)") }
        if g.rocks > 0 { extras.append("specimens \(g.rocks)") }
        if g.odd > 0 { extras.append("oddities \(g.odd)") }
        if g.rig != .tent && !g.resident && !g.house {
            if g.tanks < 40 { extras.insert("tanks \(Int(100 - g.tanks))% full", at: 0) }
            if g.propane < 40 { extras.insert("propane \(Int(g.propane))%", at: 0) }
        }
        if g.page { extras.append("\(g.followersText()) followers") }
        let room = r - (l + 132) - 14
        for e in extras where Double(pack.count + e.count + 5) * 2.75 < room { pack += "  ·  " + e }
        g.text(pack, r, 12, 5.5, CREAM, align: 2, bold: true, plate: true)
        if g.previewing {
            c.RR(l, 23, 74, 14, 7, REDC.alpha(0.9))
            g.text("PREVIEW  ·  tap to exit", l + 37, 30, 4.2, CREAM, bold: true)
            g.hits.append(Hit(id: 86, x: l - 4, y: 19, w: 82, h: 22))
        }
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
        g.text(dateText(g.day) + "  ·  age \(g.age)  ·  season \(g.year)", x0 + 10, y0 + 18.4, 3.6, ink.alpha(0.7), align: 1, bold: true)
        // close
        c.circ(x1 - 11, y0 + 10, 6, ink.alpha(0.12))
        c.seg(x1 - 14, y0 + 7, x1 - 8, y0 + 13, 1, ink); c.seg(x1 - 8, y0 + 7, x1 - 14, y0 + 13, 1, ink)
        g.hits.append(Hit(id: 62, x: x0, y: y0, w: x1 - x0, h: y1 - y0))
        g.hits.append(Hit(id: 61, x: x1 - 22, y: y0, w: 22, h: 22))

        // the sketch map
        let big = g.mapQuad >= 0
        let mx0 = x0 + 10, my0 = y0 + 22, mw = big ? x1 - x0 - 20 : (x1 - x0) * 0.5, mh = y1 - y0 - 58
        c.RR(mx0, my0, mw, mh, 3, Col(0xe2cfa4))
        g.hits.append(Hit(id: 55, x: mx0, y: my0, w: mw, h: mh))
        g.text(big ? "tap a pin to go  ·  tap the map to zoom back out" : "tap a quarter of the map to zoom in", mx0 + mw - 1, my0 - 2.6, 3, ink.alpha(0.55), align: 2)
        var lonA = -114.42, lonB = -114.09, latA = 33.50, latB = 33.77
        if big {
            // one quarter of the country, with some overlap so nothing sits right on the edge
            let lw = (lonB - lonA) * 0.6, lh = (latB - latA) * 0.6
            if g.mapQuad % 2 == 1 { lonA = lonB - lw } else { lonB = lonA + lw }
            if g.mapQuad / 2 == 0 { latA = latB - lh } else { latB = latA + lh }
            let qn = ["NORTHWEST", "NORTHEAST", "SOUTHWEST", "SOUTHEAST"][max(0, min(3, g.mapQuad))]
            g.text(qn, mx0 + 6, my0 + 6, 4.4, ink.alpha(0.6), align: 1, bold: true)
        } else {
            c.seg(mx0 + mw / 2, my0 + 2, mx0 + mw / 2, my0 + mh - 2, 0.4, ink.alpha(0.25))
            c.seg(mx0 + 2, my0 + mh / 2, mx0 + mw - 2, my0 + mh / 2, 0.4, ink.alpha(0.25))
            for q in 0..<4 { g.hits.append(Hit(id: 300 + q, x: mx0 + Double(q % 2) * mw / 2, y: my0 + Double(q / 2) * mh / 2, w: mw / 2, h: mh / 2)) }
        }
        func inside(_ lat: Double, _ lon: Double) -> Bool { return lon >= lonA && lon <= lonB && lat >= latA && lat <= latB }
        func mp(_ lat: Double, _ lon: Double) -> (Double, Double) {
            // places off the sketch sit on its edge, pointing the way
            let x = mx0 + (lon - lonA) / (lonB - lonA) * mw, y = my0 + (latB - lat) / (latB - latA) * mh
            return (clampD(x, mx0 + 6, mx0 + mw - 6), clampD(y, my0 + 6, my0 + mh - 6))
        }
        // the Dome Rock Mountains and the river side
        let dr = mp(33.635, -114.345)
        if !big || inside(33.635, -114.345) { c.ell(dr.0, dr.1, 16, 7, Col(0xb48a62)); c.ell(dr.0 + 6, dr.1 - 2, 9, 5, Col(0xa47a52)) }
        let riverSide = !big || g.mapQuad % 2 == 0
        if riverSide { c.curve(mx0 + 3, my0 + 4, mx0 + 8, my0 + mh * 0.5, mx0 + 2, my0 + mh - 4, 1.6, Col(0x4a86b0)) }
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
        g.text("95", lab95.0 - 4, lab95.1 + 13, 3.6, ink.alpha(0.6), bold: true)
        if riverSide { g.text("to the river", mx0 + 14, my0 + mh - 20, 3.2, Col(0x2a5a80), align: 1) }
        for a in AREAS.indices {
            let d = AREAS[a]
            if big && !inside(d.lat, d.lon) { continue }
            let p = mp(d.lat, d.lon)
            let here = a == g.area.rawValue
            if here { c.circ(p.0, p.1, 5 + sin(NOW * 4) * 0.8, GOLD.alpha(0.5)) }
            c.circ(p.0, p.1, 2.6, here ? GOLD : REDC)
            c.circ(p.0, p.1, 1, CREAM)
            let off: [(Double, Double, Int)] = [(-4, 4, 2), (4, -5, 1), (-5, 7, 2), (0, -6, 0), (0, 6, 0), (4, 6.5, 1), (5, 1, 1), (-4, 3, 2), (5, 1, 1), (-5, 1, 2), (-5, -2, 2), (-5, 6, 2), (3, 7, 2), (5, 2, 1)]
            let o = a < off.count ? off[a] : (0.0, -6.0, 0)
            let camp = !g.inPast && a == g.rigArea.rawValue
            g.text(d.name + (camp ? " (camp)" : ""), p.0 + o.0, p.1 + o.1, big ? 4.8 : 3.6, ink, align: o.2, bold: true)
            if !here { g.hits.append(Hit(id: 70 + a, x: p.0 - 9, y: p.1 - 9, w: 18, h: 18)) }
        }
        if !g.inPast && (!big || inside(33.618, -114.305)) {
            // Gold Nugget Road: the old mines out past Dome Rock
            let gn = mp(33.618, -114.305)
            c.circ(gn.0, gn.1, big ? 2.4 : 1.8, Col(0xb8862e)); c.circ(gn.0, gn.1, big ? 1 : 0.7, Col(0xfff0a0))
            g.text("Gold Nugget Rd", gn.0 - 3.4, gn.1 + 4.4, big ? 4.2 : 3.2, Col(0x6a4a1e), align: 2, bold: true)
            g.hits.append(Hit(id: 304, x: gn.0 - 48, y: gn.1 - 6, w: 56, h: 16))
        }
        if !g.inPast && (!big || inside(33.607, -114.204)) {
            let mc = mp(33.607, -114.204)
            c.circ(mc.0, mc.1, 1.6, Col(0x6a3a7a))
            g.text(g.foundMagic ? "Magic Circle" : "?", mc.0 + 3, mc.1 + 1, 3.2, Col(0x6a3a7a), align: 1, bold: true)
        }
        if !big {

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
            else if !g.inPast && a == g.rigArea.rawValue && t.ok { sub = "Your camp · " + (t.cost == 0 ? "0 coins" : "\(t.cost) coins") }
            else if t.ok { let m = milesBetween(g.area, to); sub = (m == m.rounded() ? "\(Int(m))" : "\(m)") + " mi · " + (t.cost == 0 ? "0 coins" : "\(t.cost) coins") }
            else { sub = t.how }
            g.text(sub, cx0 + 4, ry + rowH * 0.68, 3.2, here ? ink.alpha(0.7) : (t.ok ? Col(0x2f6a3a) : REDC.shade(0.8)), align: 1)
            if !here { g.hits.append(Hit(id: 70 + a, x: cx0, y: ry, w: cw, h: rowH - 3)) }
        }

        }
        if !g.inPast && !g.inRig {
            c.RR(x1 - 98, y1 - 21, 88, 13, 6.5, GOLD)
            g.text("BACK TO MY CAMP", x1 - 54, y1 - 14.5, 4.2, INK, bold: true)
            g.hits.append(Hit(id: 54, x: x1 - 102, y: y1 - 25, w: 96, h: 21))
        }
        // the calendar
        var now: [String] = []
        for e in EVENTS.indices where g.on(e) && e != EV_PAN { now.append(EVENTS[e].name) }
        var next: [Int] = []
        for e in EVENTS.indices where EVENTS[e].start > g.day && e != EV_PAN { next.append(e) }
        next.sort { EVENTS[$0].start < EVENTS[$1].start }
        let cy = y1 - 28
        let nowLine = g.inPast ? "Winter, 1026: no shows, no swap meets. Just the desert, the animals and the river people." : "Happening now: " + (now.isEmpty ? "nothing big this week" : now.joined(separator: ", "))
        g.text(nowLine, x0 + 10, cy, 4.4, ink, align: 1, bold: true, wrap: x1 - x0 - 20)
        if !next.isEmpty && !g.inPast {
            let up = next.prefix(2).map { EVENTS[$0].name + " (" + EVENTS[$0].when + ", " + AREAS[EVENTS[$0].area.rawValue].name + ")" }
            g.text("Coming up: " + up.joined(separator: " · "), x0 + 10, cy + 11, 4, ink.alpha(0.75), align: 1, wrap: x1 - x0 - 130)
        }
        #if DEBUG
        // testing only, never in a released build: skip a week to reach the events
        c.RR(x1 - 66, y0 + 4, 48, 12, 6, REDC.alpha(0.85))
        g.text("TEST: +1 WEEK", x1 - 42, y0 + 10, 3.8, CREAM, bold: true)
        g.hits.append(Hit(id: 64, x: x1 - 68, y: y0 + 2, w: 52, h: 16))
        #endif
        // the ways back in time, side by side, and home again
        #if DEBUG
        let tr = x1 - 70.0
        #else
        let tr = x1 - 22.0
        #endif
        let eras: [(String, Int, Int)] = [("1,000 YEARS", 85, 1), ("13,000 YEARS", 57, 2), ("5 MILLION YEARS", 305, 3)]
        let bw = 46.0
        for (q, e) in eras.enumerated() {
            let bx = tr - Double(3 - q) * (bw + 2.5)
            let on = g.era == e.2
            c.RR(bx, y0 + 4, bw, 12, 6, on ? Col(0x3b5bdb) : [Col(0x8a5a2e), Col(0x4a6a8a), Col(0x2e7a6a)][q])
            g.text(on ? "BACK TO 2026" : e.0, bx + bw / 2, y0 + 10, 3.4, CREAM, bold: true)
            g.hits.append(Hit(id: e.1, x: bx - 1, y: y0 + 2, w: bw + 2, h: 16))
        }
        g.text("GO BACK", tr - 3 * (bw + 2.5) - 3, y0 + 10, 3.6, ink.alpha(0.7), align: 2, bold: true)
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
        c.R(0, 0, W, H, Col(0x0c0a08, 0.72))
        g.hits.append(Hit(id: -1, x: 0, y: 0, w: W, h: H))
        let wood = [Col(0xc89a62), Col(0x9a6a44), Col(0xd8b484)][g.tourBus]
        let paint = [Col(0x5a8a7a), Col(0xd9c9a8), Col(0x3a5a8a)][g.tourBus]
        // a school bus is narrow and low inside, so draw it big: 34 feet of home, cut away along its length
        let RW = 112.0, RH = 25.0
        let availW = W - g.safeL - g.safeR - 16
        let S = min(availW / RW, (H - 34) / (RH + 9))
        let ox = (W - RW * S) / 2, oy = H / 2 + (RH * 0.5 + 1) * S
        c.save()
        c.translate(ox, oy)
        c.scale(S, S)
        // the shell: steel below the windows, the curved roof lined in tongue-and-groove
        c.RR(-2, -RH - 2.4, RW + 4, RH + 9, 4, paint)
        c.RR(0, -RH, RW, RH, 2.4, Col(0xe8dcc4))
        c.RR(0, -RH, RW, 4.4, 2.4, wood)
        var k = 0.0
        while k < RW { c.R(k, -RH + 0.6, 0.15, 3.6, wood.shade(0.8)); k += 1.6 }
        c.R(0, -RH + 4.2, RW, 0.5, wood.shade(0.7))
        // wheel wells boxed in, and the floor
        c.R(0, 0, RW, 5, wood.shade(0.72))
        k = 0
        while k < RW { c.R(k, 0, 0.15, 5, wood.shade(0.55)); k += 4.2 }
        for q in 0..<12 { c.R(hashN(Double(q) + 9670) * RW, 0.6 + hashN(Double(q) + 9671) * 3.8, 2.2, 0.12, wood.shade(0.6)) }
        // the row of bus windows with the desert outside, curtains tied back
        for q in 0..<9 {
            let wx = 14 + Double(q) * 9.4
            c.RR(wx, -RH + 6, 7.6, 7, 0.5, Col(0x2a2a2e))
            c.vfill(wx + 0.5, -RH + 6.5, 6.6, 6, [(0, Col(0x8ac0e8)), (0.62, Col(0xe8c89a)), (0.63, Col(0xb88a62)), (1, Col(0xc89a6a))])
            c.R(wx + 0.5, -RH + 9.4, 6.6, 0.3, Col(0x2a2a2e))
            if q % 3 == 1 { c.R(wx + 4, -RH + 9.8, 0.5, 2, Col(0x4a7a3e)); c.R(wx + 3.4, -RH + 10.4, 0.5, 0.8, Col(0x4a7a3e)) }
            let cur = [Col(0xd9772e), Col(0x8a4aa8), Col(0xf2c14e)][g.tourBus]
            c.poly(cur, [wx - 0.4, -RH + 5.6, wx + 1.6, -RH + 5.6, wx + 0.4, -RH + 13.2, wx - 0.4, -RH + 13.2])
            c.poly(cur.shade(0.86), [wx + 8, -RH + 5.6, wx + 6, -RH + 5.6, wx + 7.2, -RH + 13.2, wx + 8, -RH + 13.2])
        }
        c.R(13, -RH + 5.3, 86, 0.4, Col(0x6a4a2e))
        // string lights swagged along the ceiling
        for q in 0..<30 {
            let t = Double(q) / 29
            c.circ(4 + t * (RW - 8), -RH + 4.9 + abs(sin(t * PI * 5)) * 0.8, 0.35, [Col(0xffd68a), Col(0xff8a6a), Col(0x8ad0ff)][q % 3])
        }
        // the bed across the back, on a platform with drawers, piled with quilts and pillows
        c.R(1.4, -9.4, 23, 9.4, wood.shade(0.9))
        for q in 0..<3 { c.RR(2.4 + Double(q) * 7.4, -7.4, 6.4, 6, 0.4, wood.shade(1.05)); c.circ(5.6 + Double(q) * 7.4, -4.4, 0.4, Col(0x3a2a1e)) }
        c.RR(1.4, -12.4, 23, 3.2, 1, Col(0xe8dcc4))
        let quilt = [Col(0xd9412e), Col(0xf2c14e), Col(0x3a6ea5), Col(0x3f8f6a)]
        for q in 0..<8 { c.R(8 + Double(q) * 2, -12.6, 2, 1.8, quilt[(q + g.tourBus) % 4]); c.R(8 + Double(q) * 2, -10.8, 2, 1.6, quilt[(q + g.tourBus + 2) % 4]) }
        c.RR(2, -14.4, 5, 2.4, 1, Col(0xf4f0e4)); c.RR(3.4, -15.4, 4.4, 2.2, 1, Col(0xb8d0e0))
        c.R(1.4, -19, 9, 0.5, wood); for q in 0..<8 { c.R(2 + Double(q) * 1, -19 - 2.2 - hashN(Double(q) + 9680), 0.8, 2.2 + hashN(Double(q) + 9680), quilt[q % 4].shade(0.85)) }
        // a guitar on the wall, a dreamcatcher, a hanging plant
        c.ell(28.4, -6.4, 1.8, 2.4, Col(0xb8742e)); c.circ(28.4, -6.6, 0.6, Col(0x2a1a14)); c.R(28.1, -13, 0.6, 5, Col(0x5a3a22))
        c.seg(34, -RH + 4.6, 34, -RH + 8, 0.12, Col(0x8a7a5a)); c.RR(32.8, -RH + 8, 2.4, 1.8, 0.5, Col(0xc85a3a))
        for q in 0..<5 { c.curve(34, -RH + 8.4, 33 + Double(q) * 0.7, -RH + 11, 32 + Double(q) * 1, -RH + 12.6 + sin(Double(q)) * 0.6, 0.3, Col(0x4f9a5a)) }
        // the wood stove on a tiled hearth, its pipe through the roof, kindling beside it
        let stx = 40.0
        c.R(stx - 4.4, -0.8, 8.8, 0.8, Col(0x8a8078)); c.R(stx - 4.4, -10, 0.5, 9.4, Col(0x9a9088))
        c.RR(stx - 2.8, -7, 5.6, 6, 0.5, Col(0x26262a)); c.R(stx - 2.4, -1.2, 0.6, 1.2, Col(0x26262a)); c.R(stx + 1.8, -1.2, 0.6, 1.2, Col(0x26262a))
        c.RR(stx - 1.8, -5.6, 3.6, 2.8, 0.3, Col(0xff8a2e, 0.6 + 0.3 * sin(NOW * 7)))
        c.R(stx - 0.6, -RH + 4, 1.2, RH - 11, Col(0x3a3a3e)); c.glow(stx, -4, 9, Col(0xffa040, 0.3), Col(0xffa040, 0))
        for q in 0..<4 { c.seg(stx + 4.6, -0.4 - Double(q) * 0.5, stx + 8, -0.4 - Double(q) * 0.5, 0.45, Col(0x8a6238)) }
        c.ell(stx + 1.4, -7.6, 1.2, 0.5, Col(0x3a6ea5)); c.curve(stx + 2.4, -7.6, stx + 3.4, -8.4, stx + 3, -9, 0.2, Col(0x3a6ea5))
        // the galley: butcher block, a bar sink, a two-burner stove, jars on a shelf, pans hanging, a small fridge
        c.R(50, -9.6, 26, 9.6, wood.shade(0.85)); c.R(49.6, -10.4, 26.8, 0.9, wood.shade(1.15))
        for q in 0..<4 { c.RR(51 + Double(q) * 6.3, -8.4, 5.4, 7.4, 0.3, wood.shade(0.98)); c.R(53.4 + Double(q) * 6.3, -7.4, 0.8, 0.3, Col(0x3a2a1e)) }
        c.RR(54, -10.6, 5, 0.6, 0.3, Col(0xb8bcc0)); c.curve(56.4, -10.6, 56.4, -13.2, 58, -12.2, 0.3, Col(0xb8bcc0))
        c.R(63, -10.9, 7, 0.6, Col(0x26262a)); c.circ(64.8, -11, 0.9, Col(0x4a4a4e)); c.circ(68.2, -11, 0.9, Col(0x4a4a4e)); c.RR(67, -12.6, 2.6, 1.6, 0.5, Col(0xc8281e))
        c.R(50, -15.6, 20, 0.5, wood); for q in 0..<8 { c.RR(50.8 + Double(q) * 2.4, -17.8, 1.6, 2.2, 0.3, [Col(0xe0c890), Col(0x9a5a3a), Col(0x7a9a5a), Col(0xe8e0d0)][q % 4]); c.R(50.8 + Double(q) * 2.4, -18.2, 1.6, 0.5, Col(0x8a8a88)) }
        for q in 0..<3 { c.seg(72 + Double(q) * 1.8, -15.4, 72 + Double(q) * 1.8, -14, 0.12, Col(0x3a3a3e)); c.circ(72 + Double(q) * 1.8, -12.8, 0.9 + Double(q) * 0.15, Col(0x3a3a3e)) }
        c.RR(77, -12.4, 5.6, 12.4, 0.5, Col(0xe4e4e0)); c.R(77, -7.4, 5.6, 0.2, Col(0xa8a8a4)); c.R(81.6, -11, 0.4, 2.4, Col(0x8a8a88))
        c.RR(77.6, -11.6, 1.8, 1.4, 0.2, Col(0xf2c14e)); c.RR(79.8, -10.4, 1.4, 1.8, 0.2, Col(0xd9412e))
        // the dinette: two benches and a fold-down table, a map spread out, a mug
        c.RR(84.4, -8, 3.6, 8, 0.6, paint.shade(0.8)); c.RR(84.4, -13, 1.2, 5.4, 0.5, paint.shade(0.8))
        c.RR(96, -8, 3.6, 8, 0.6, paint.shade(0.8)); c.RR(98.4, -13, 1.2, 5.4, 0.5, paint.shade(0.8))
        c.R(88.6, -8.6, 6.8, 0.7, wood.shade(1.1)); c.R(91.7, -8, 0.6, 8, Col(0x5a5a5a))
        c.poly(Col(0xf0e8d0), [89.2, -8.7, 93, -8.9, 93.4, -8.6, 89.4, -8.5]); c.RR(94, -9.9, 1, 1.3, 0.2, Col(0x3a6ea5))
        // the driver's seat and wheel up front, the big windshield
        c.poly(Col(0x8ac0e8, 0.85), [103, -RH + 5, RW - 1, -RH + 7, RW - 1, -11, 103, -11])
        c.poly(Col(0xe8c89a, 0.9), [103, -14, RW - 1, -14, RW - 1, -11, 103, -11])
        c.R(102.4, -RH + 4.6, 0.7, RH - 15.4, Col(0x2a2a2e))
        c.RR(102.6, -9, 3.4, 9, 0.8, Col(0x3a3a3e)); c.RR(102.6, -15.4, 1.3, 7, 0.6, Col(0x3a3a3e))
        c.seg(107.4, -8.4, 109.4, -4, 0.5, Col(0x26262a)); c.ellStroke(107, -9.4, 1, 2.6, 0.5, Col(0x26262a))
        c.R(108.6, -10.8, 2.8, 6, Col(0x4a4a4e)); c.circ(110, -9.4, 0.5, Col(0xffd68a))
        // a rug, a dog asleep on it, boots by the door
        c.ell(60, 2.6, 14, 1.4, Col(0xb5452f, 0.85)); c.ell(60, 2.6, 10, 0.9, Col(0xf2c14e, 0.6))
        c.ell(64, 1.6, 3.6, 1.5, Col(0x8a6a44)); c.circ(67.2, 1.4, 1.2, Col(0x8a6a44)); c.poly(Col(0x6a4e30), [66.6, 0.4, 67.2, -0.5, 67.6, 0.5])
        c.curve(60.6, 1.8, 59, 1.2 + sin(NOW * 3) * 0.3, 58.4, 2.2, 0.5, Col(0x8a6a44))
        c.RR(99.6, 2.2, 1.6, 2.2, 0.3, Col(0x5a3a22)); c.RR(101.4, 2.4, 1.6, 2, 0.3, Col(0x5a3a22))
        // the owners, glad to show it off
        person(47, 3.4, 300 + g.tourBus * 7, 1, 0, false)
        person(86.5, 3.6, 311 + g.tourBus * 5, -1, 0, false)
        c.restore()
        let owners = ["The Okafors' 1998 Thomas, converted in their driveway over two summers", "Dusty's 2004 Blue Bird: 40 feet, a wood stove and 1,200 watts of solar", "Tess's short bus: three dogs, one bed, zero regrets"]
        let cy = oy - (RH + 5.4) * S
        g.text(owners[g.tourBus], W / 2, max(7, cy), 4.4, CREAM, bold: true, plate: true)
        g.text("tap anywhere to step back outside", W / 2, min(H - 5, oy + 8.6 * S), 3.4, CREAM.alpha(0.7))
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
        // look close: the drift fills the frame, you and your lantern in the middle of it
        c.clipRect(x0 + 2, y0 + 2, w - 4, h - 4)
        let mz = 1.7
        c.translate(x0 + w * 0.4, y0 + h - 30)
        c.scale(mz, mz)
        c.translate(-(x0 + w * 0.4), -floor)
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
            c.seg(vein[k], vein[k + 1], vein[k + 2], vein[k + 3], k < 6 ? 1.2 : 0.8, Col(0xd8d0c0, k < 6 ? 0.5 : 0.25))
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
            if beep { g.text("beep", x0 + w * 0.4 + (px - 14 - x0 - w * 0.4) * mz, y0 + h - 30 - 12 * mz, 4, GOLD, bold: true) }
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
        g.text("IN THE OLD MINE", x0 + w / 2, y0 + 11, 5, CREAM, bold: true, plate: true)
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
            g.text(w.name, cx + 32, cy + 10, 4.8, w.sold ? CREAM.alpha(0.5) : ink, align: 1, bold: true, wrap: cw - 36)
            g.text(w.who, cx + 32, cy + 22, 3.6, w.sold ? CREAM.alpha(0.4) : ink.alpha(0.7), align: 1, wrap: cw - 36)
            if w.sold {
                g.text("Yours", cx + 32, cy + ch - 8, 5, GOLD, align: 1, bold: true)
            } else {
                coin(cx + 35, cy + ch - 12, 3.2)
                g.text("\(w.price)", cx + 41, cy + ch - 12, 6.4, Double(w.price) > g.money ? REDC : Col(0x2f6a3a), align: 1, bold: true)
                g.text("sells for about \(w.lo)–\(w.hi) coins", cx + 32, cy + ch - 5, 3.4, ink.alpha(0.65), align: 1)
                g.hits.append(Hit(id: 90 + k, x: cx, y: cy, w: cw, h: ch))
                if !w.haggled {
                    c.RR(cx + cw - 30, cy + ch - 19, 27, 10, 5, Col(0x2a1e14, 0.85))
                    g.text("Haggle", cx + cw - 16.5, cy + ch - 14, 3.8, GOLD, bold: true)
                    g.hits.append(Hit(id: 100 + k, x: cx + cw - 36, y: cy + ch - 24, w: 36, h: 18))
                } else {
                    g.text("haggled", cx + cw - 16.5, cy + ch - 14, 3.4, ink.alpha(0.45))
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
            } else if i % 3 == 0 {
                // the dancers: stepping side to side in time, turning now and then
                let beat = NOW * 5 + Double(i)
                let turn = sin(NOW * 0.7 + Double(i)) > 0 ? 1.0 : -1.0
                person(tx + sin(beat * 0.5) * 2.4, GY + 3 - abs(sin(beat)) * 1.3, look, turn, beat, true)
            } else {
                person(tx, GY + 3, look, s.0 < 30 ? -1 : (i % 2 == 0 ? 1 : -1), 0, false)
            }
        }
        // somebody brought a guitar: sitting on the cooler, picking
        if et > 5 {
            seated(fx + 34, GY - 4, 777, 0.2)
            c.ell(fx + 37, GY - 7, 2.6, 1.9, Col(0xb8742e).shade(1 - dark * 0.4)); c.seg(fx + 38, GY - 8, fx + 44, GY - 12, 0.8, Col(0x6a4a2e))
        }
        // music in the air
        if et > 3 {
            for k in 0..<3 {
                let t2 = (NOW * 0.4 + Double(k) / 3 + 0.5).truncatingRemainder(dividingBy: 1)
                g.text("♫", fx + 40 + sin(t2 * 5 + Double(k)) * 10, GY - 30 - t2 * 24, 5, GOLD.alpha(1 - t2))
            }
            for k in 0..<3 {
                let t = (NOW * 0.5 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                g.text("♪", fx + 10 + sin(t * 6 + Double(k)) * 8, GY - 34 - t * 26, 5, CREAM.alpha(1 - t))
            }
        }
    }

    /// Dust behind a fast ride, your generator chugging, and a neighbor who has had enough.
    private func manners() {
        if g.area == .intaglios && g.madT > 0 {
            let sx = g.madX - cam
            person(sx, GY + 1, 7, g.px < g.madX ? -1 : 1, NOW * 10, g.madT > 3)
            c.seg(sx, GY - 12, sx + (g.px < g.madX ? -5 : 5), GY - 19 + sin(NOW * 14) * 1.2, 1.4, Col(0x4a6a4a))
            g.text(g.madText, sx, GY - 30, 4.6, CREAM, bold: true, plate: true)
            return
        }
        // now and then someone else tears past on a side-by-side, dust and all
        if ![Area.main, .tyson, .palms, .intaglios].contains(g.area) && g.dayT < 0.66 {
            let slot = floor(NOW / 9)
            let roll = hashN(slot * 3.1 + Double(g.area.rawValue) * 7.7)
            if roll < 0.7 {
                let t = (NOW - slot * 9) / 9
                let dir = hashN(slot + 31) < 0.5 ? 1.0 : -1.0
                let sx = dir > 0 ? -70 + t * (W + 140) : W + 70 - t * (W + 140)
                for i in 0..<8 {
                    let u = (NOW * 1.6 + Double(i) / 8).truncatingRemainder(dividingBy: 1)
                    c.circ(sx - dir * (18 + u * 60), GY + 11 - u * 12, 2.4 + u * 9, Col(0xd8bc90, (1 - u) * 0.32).shade(1 - dark * 0.5))
                }
                if roll < 0.56 { sxs(sx, GY + 13, dir, Int(hashN(slot + 77) * 7) % 7, hashN(slot + 78) < 0.35) }
                else { toy(2, sx, GY + 13, dir, 300 + Int(slot) % 40, NOW * 25) }
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
        if g.genOn && g.rigHere {
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
            // no lamp post planted in front of a shop sign
            if g.spots.contains(where: { abs($0.x - (n * 320 + 150)) < 46 }) { n += 1; continue }
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
        let ix = 2660 - cam
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
            hawk(W * 0.55 + cos(ha) * 60, GY * 0.42 + sin(ha) * 8, NOW)
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
    // MARK: a thousand years ago

    /// The natural landforms only: mountains and canyon walls, without the camps and lots.
    private func pastBackground(_ ar: Area) {
        switch ar {
        case .desertbar:
            let bx = W * 0.5 + 200 - cam * 0.2
            massif([bx - 360, GY + 1, bx - 300, GY - 46, bx - 240, GY - 30, bx - 180, GY - 66, bx - 100, GY - 40, bx - 40, GY - 58, bx + 40, GY - 34, bx + 120, GY - 50, bx + 220, GY + 1], Col(0x9a5a3e).shade(1 - dark * 0.6))
        case .intaglios:
            let mx = W * 0.5 - cam * 0.15
            massif([mx - 400, GY + 1, mx - 300, GY - 36, mx - 200, GY - 28, mx - 100, GY - 50, mx, GY - 40, mx + 120, GY - 56, mx + 260, GY - 30, mx + 400, GY + 1], Col(0x7a5a52).shade(1 - dark * 0.6))
        case .crystal:
            let kx = W * 0.5 - cam * 0.18
            let kofa = Col(0x7a5a4a).shade(1 - dark * 0.6)
            massif([kx - 260, GY + 1, kx - 200, GY - 40, kx - 170, GY - 28, kx - 130, GY - 62, kx - 90, GY - 44, kx - 40, GY - 70, kx + 10, GY - 38, kx + 60, GY - 52, kx + 120, GY - 30, kx + 200, GY + 1], kofa)
        case .palms:
            canyonWall(W * 0.5 + 300 - cam * 0.3)
        default:
            break
        }
        // mesquite and ironwood bosques along the washes, thick where the town will be one day
        let par = 0.72
        var n = floor((cam * par - 60) / 70)
        while n * 70 < cam * par + W + 60 {
            if hashN(n + 4100 + Double(ar.rawValue)) < 0.55 {
                let sx = n * 70 + hashN(n + 4110) * 40 - cam * par
                if g.deep { palm(sx, GY + 1, 24 + hashN(n + 4125) * 14, n) }
                else if g.iceAge { if hashN(n + 4120) < 0.5 { juniper(sx, GY + 1, 0.8, n) } else { joshua(sx, GY + 1, 22, n + 3) } }
                else if hashN(n + 4120) < 0.6 { mesquite(sx, GY + 1, n + 4130, 0.55) } else { ironwood(sx, GY + 1, n + 4140, 0.55) }
            }
            n += 1
        }
    }


    /// A buff-ware pot, painted red in the river people's style.
    private func pot(_ x: Double, _ base: Double, _ s: Double) {
        let buff = Col(0xd8b88a).shade(1 - dark * 0.45)
        let red = Col(0x9a3a22).shade(1 - dark * 0.45)
        c.ell(x, base - 3.4 * s, 3.6 * s, 3.4 * s, buff)
        c.R(x - 1.8 * s, base - 8 * s, 3.6 * s, 2 * s, buff)
        c.seg(x - 3 * s, base - 4 * s, x - 1 * s, base - 2 * s, 0.5 * s, red)
        c.seg(x - 1 * s, base - 2 * s, x + 1 * s, base - 4.4 * s, 0.5 * s, red)
        c.seg(x + 1 * s, base - 4.4 * s, x + 3 * s, base - 2.4 * s, 0.5 * s, red)
    }

    /// One of the river people at work: rabbit-skin robe for the cold, a willow-bark skirt, long hair.
    /// pose 0 standing, 1 grinding on a metate, 2 shaping a pot, 3 a child walking
    private func villager(_ x: Double, _ base: Double, _ seed: Double, _ pose: Int) {
        if x < -20 || x > W + 20 { return }
        let skin = Col(0x8a5a3a).shade(1 - dark * 0.45)
        let hair = Col(0x1a1412)
        let robe = (hashN(seed) < 0.5 ? Col(0x9a8a74) : Col(0x8a7058)).shade(1 - dark * 0.45)
        let skirt = Col(0xc8a878).shade(1 - dark * 0.45)
        if pose == 1 || pose == 2 {
            let a = sin(NOW * 3 + seed) * 1.6
            c.ell(x, base - 3, 4, 3, skirt)
            c.RR(x - 3, base - 12, 6, 9, 2, robe)
            c.R(x - 3, base - 16.4, 3.6, 7, hair)
            c.circ(x + 0.6, base - 14.4, 2.6, skin)
            c.R(x - 2, base - 17.2, 4.4, 1.6, hair)
            c.seg(x + 2, base - 9, x + 6 + a, base - 4, 1.2, skin)
            if pose == 1 {
                c.poly(Col(0x6a6460).shade(1 - dark * 0.4), [x + 4, base, x + 13, base, x + 12, base - 2.4, x + 5, base - 3])
                c.RR(x + 5 + a, base - 4.6, 4, 1.6, 0.8, Col(0x8a8480))
            } else {
                pot(x + 8, base, 1)
            }
            return
        }
        let k = pose == 3 ? 0.7 : 1.0
        let sw = pose == 3 ? sin(NOW * 5 + seed) * 1.2 : 0
        c.seg(x - 1, base - 8 * k, x - 1 + sw, base, 1.3, skin)
        c.seg(x + 1, base - 8 * k, x + 1 - sw, base, 1.3, skin)
        c.poly(skirt, [x - 3.4 * k, base - 13 * k, x + 3.4 * k, base - 13 * k, x + 4 * k, base - 6 * k, x - 4 * k, base - 6 * k])
        for f in 0..<4 { let fx = x - 3 * k + Double(f) * 2 * k; c.seg(fx, base - 7 * k, fx, base - 5.4 * k, 0.5, skirt.shade(0.8)) }
        c.RR(x - 3.2 * k, base - 20 * k, 6.4 * k, 8 * k, 2, robe)
        c.R(x - 3 * k, base - 25 * k, 3.4 * k, 8 * k, hair)
        c.circ(x + 0.6 * k, base - 22.6 * k, 2.6 * k, skin)
        c.R(x - 2 * k, base - 25.4 * k, 4.6 * k, 1.6 * k, hair)
    }

    /// A village on the floodplain at Ehrenberg: an earth-covered winter house, a ramada, a granary, the fields resting till the floods.
    private func village(_ x: Double) {
        if x < -200 || x > W + 200 { return }
        let earth = Col(0xa8845a).shade(1 - dark * 0.5)
        let weed = Col(0xb8a070).shade(1 - dark * 0.5)
        let pole = Col(0x6a4a2e).shade(1 - dark * 0.45)
        // the fields: cleared plots with last year's stubble, waiting on the spring flood
        for k in 0..<4 {
            let fx = x - 190 + Double(k) * 30
            c.R(fx, GY + 2, 26, 6, Col(0x9a7a52, 0.6).shade(1 - dark * 0.5))
            for j in 0..<6 { c.seg(fx + 2 + Double(j) * 4, GY + 4, fx + 2 + Double(j) * 4, GY + 1.4, 0.6, Col(0xc8b070).shade(1 - dark * 0.5)) }
        }
        // the winter house: poles and arrowweed under a thick roof of sand and earth, door to the south
        c.poly(earth, [x - 90, GY + 1, x - 82, GY - 15, x - 34, GY - 17, x - 26, GY + 1])
        c.poly(earth.shade(1.08), [x - 82, GY - 15, x - 34, GY - 17, x - 40, GY - 19, x - 76, GY - 18])
        for k in 0..<5 { c.seg(x - 80 + Double(k) * 11, GY - 16, x - 81 + Double(k) * 11, GY - 19.4, 1, pole) }
        c.RR(x - 62, GY - 10, 9, 11, 1, Col(0x2a1e14))
        if dark > 0.3 { c.R(x - 61, GY - 8, 7, 8, Col(0xffa040, 0.5)); lights.append((x - 57, GY - 5, 16)) }
        // the ramada: four posts and a flat arrowweed roof for shade and work
        for k in 0..<3 { c.R(x - 12 + Double(k) * 26, GY - 22, 1.6, 22, pole) }
        c.R(x - 16, GY - 25, 60, 4, weed)
        for k in 0..<20 { c.seg(x - 15 + Double(k) * 3, GY - 21, x - 15.4 + Double(k) * 3, GY - 18.6, 0.6, weed.shade(0.85)) }
        villager(x - 4, GY + 1, 1, 1)
        villager(x + 22, GY + 1, 2, 2)
        pot(x + 36, GY + 1, 1.2)
        pot(x + 41, GY + 1, 0.8)
        // a granary basket of woven arrowweed up on a platform, full of mesquite beans and corn
        c.R(x + 60, GY - 9, 1.6, 9, pole); c.R(x + 76, GY - 9, 1.6, 9, pole)
        c.R(x + 58, GY - 10, 22, 2, pole)
        c.ell(x + 69, GY - 17, 10, 8, weed)
        for k in 0..<5 { c.seg(x + 61 + Double(k) * 4, GY - 23, x + 61 + Double(k) * 4, GY - 11, 0.5, weed.shade(0.8)) }
        c.ell(x + 69, GY - 24.4, 8, 2.2, weed.shade(1.1))
        // the cooking fire and the family around it
        fire(x + 100, GY + 3)
        pot(x + 108, GY + 3, 1)
        villager(x + 88, GY + 1, 3, 0)
        villager(x + 120, GY + 1, 4, 0)
        let walk = (NOW * 6).truncatingRemainder(dividingBy: 60)
        villager(x + 112 + (walk < 30 ? walk : 60 - walk), GY + 2, 5, 3)
        // a dog asleep by the fire
        c.ell(x + 132, GY + 1, 4, 1.8, Col(0x8a6a44).shade(1 - dark * 0.5))
        c.circ(x + 136, GY, 1.6, Col(0x8a6a44).shade(1 - dark * 0.5))
        g.text("River Village", x + 20, GY - 46, 3.8, CREAM, bold: true, plate: true)
    }

    /// Hoofed animals: kind 0 pronghorn, 1 bighorn, 2 mule deer doe, 3 mule deer buck.
    private func hoofed(_ x: Double, _ base: Double, _ s: Double, _ kind: Int, _ ph: Double) {
        if x < -30 || x > W + 30 { return }
        let tones: [Col] = [Col(0xc08a50), Col(0x9a8064), Col(0x8a7a6a), Col(0x8a7a6a)]
        let cc = tones[kind].shade(1 - dark * 0.5)
        let belly = Col(0xf0e8dc).shade(1 - dark * 0.5)
        let sw = sin(NOW * 1.6 + ph) * s
        c.roundCaps(true)
        let legs: [(Double, Double)] = [(-5, sw), (-3, -sw), (4, -sw), (6, sw)]
        for (lx, s0) in legs { c.seg(x + lx * s, base - 9 * s, x + lx * s + s0, base, 1.1 * s, cc.shade(0.8)) }
        c.ell(x, base - 11 * s, 8 * s, 3.6 * s, cc)
        c.ell(x, base - 9.2 * s, 6 * s, 1.5 * s, kind == 0 ? belly : cc.shade(1.1))
        c.ell(x - 7 * s, base - 11 * s, 2 * s, 2.4 * s, belly)
        let graze = sin(NOW * 0.5 + ph) > 0.4
        let hx = x + 9 * s
        let hy = graze ? base - 4 * s : base - 18 * s
        c.seg(x + 6 * s, base - 12 * s, hx, hy, 2.4 * s, cc)
        c.ell(hx + 1.6 * s, hy + 0.4 * s, 2.6 * s, 1.5 * s, cc.shade(0.95))
        if kind == 0 {
            c.seg(hx, hy - 1 * s, hx - 0.4 * s, hy - 5 * s, 0.8 * s, INK)
            c.R(hx - 2.2 * s, hy + 2 * s, 1.4 * s, 2 * s, belly)
        } else if kind == 1 {
            c.ellStroke(hx - 1 * s, hy - 0.4 * s, 2.4 * s, 2.4 * s, 1.1 * s, Col(0xc8b898).shade(1 - dark * 0.5))
        } else {
            c.ell(hx - 1.4 * s, hy - 2.6 * s, 0.9 * s, 2 * s, cc.shade(0.9))
            if kind == 3 {
                let ant = Col(0xd8c8a8)
                c.seg(hx, hy - 1.6 * s, hx - 2 * s, hy - 6 * s, 0.6 * s, ant)
                c.seg(hx - 1.2 * s, hy - 4 * s, hx + 1 * s, hy - 6.4 * s, 0.6 * s, ant)
            }
        }
        c.roundCaps(false)
    }

    /// A big bird riding the air: the condor shows white under its wings and a bare head.
    private func soar(_ x: Double, _ y: Double, _ span: Double, _ condor: Bool) {
        let col = Col(condor ? 0x1a1614 : 0x5a4030)
        let f = sin(NOW * 0.9) * span * 0.06
        let h = span / 2
        c.poly(col, [x - h, y - f, x - h * 0.3, y - 1.4, x, y - 2, x + h * 0.3, y - 1.4, x + h, y - f, x + h * 0.3, y + 1.6, x - h * 0.3, y + 1.6])
        if condor {
            let wh = Col(0xf0ece4, 0.8)
            c.poly(wh, [x - h * 0.85, y - f + 0.4, x - h * 0.3, y + 0.2, x - h * 0.3, y + 1.2])
            c.poly(wh, [x + h * 0.85, y - f + 0.4, x + h * 0.3, y + 0.2, x + h * 0.3, y + 1.2])
        }
        c.circ(x, y - 1.6, 1.3, condor ? Col(0xd88a6a) : col)
    }

    /// What you came to watch, drawn where you watch it.
    private func pastSight(_ arg: Int, _ x: Double) {
        let base = GY + 1
        if arg >= 200 { deepSight(arg - 200, x); return }
        if arg >= 100 { iceSight(arg - 100, x); return }
        switch arg {
        case 16:
            // tracks by day; at dusk the jaguar itself, head down at the water
            for q in 0..<5 { c.ell(x - 30 + Double(q) * 9, base + 3 + Double(q % 2), 1.2, 0.8, Col(0x6a5238, 0.7)) }
            if g.dayT >= 0.5 { cat(x + 24, base + 1, 1.1, Col(0xd8a850), false, true, true) }
        case 0:
            for k in 0..<4 { hoofed(x - 40 + Double(k) * 24, base + Double(k % 2), 0.9, 0, Double(k) * 1.3) }
        case 1:
            let rock = Col(0x7a6a5a).shade(1 - dark * 0.5)
            c.poly(rock, [x - 40, base, x - 26, base - 26, x - 4, base - 32, x + 18, base - 22, x + 36, base])
            hoofed(x - 10, base - 31, 0.8, 1, 0)
            hoofed(x + 14, base - 21, 0.7, 1, 2)
        case 2:
            let t = NOW * 0.25
            soar(x + cos(t) * 50, GY - 80 + sin(t) * 12, 26, true)
        case 3:
            let sh = Col(0x6a5a3e).shade(1 - dark * 0.5)
            c.dome(x, base - 0.6, 5.4, sh)
            c.seg(x - 3, base - 3, x + 2, base - 4.4, 0.5, sh.shade(0.7))
            c.circ(x + 6.4, base - 1.6 - abs(sin(NOW * 0.4)) * 0.8, 1.4, Col(0x8a7a5a))
        case 4:
            c.ell(x, base + 5, 46, 5, Col(0x4a7a8a, 0.85).shade(1 - dark * 0.5))
            c.dome(x - 26, base + 4, 10, Col(0x6a5030).shade(1 - dark * 0.5))
            for k in 0..<8 { let d = Double(k); c.seg(x - 34 + d * 2, base + 3, x - 30 + d * 2, base - 4, 0.6, Col(0x8a6a44)) }
            let bx = x + 10 + sin(NOW * 0.3) * 20
            c.ell(bx, base + 4, 3.4, 1.4, Col(0x5a3a22))
            c.seg(bx - 4, base + 5, bx - 12, base + 6.4, 0.5, Col(0xc8e0e8, 0.6))
            c.seg(bx - 4, base + 3.6, bx - 12, base + 2.4, 0.5, Col(0xc8e0e8, 0.6))
        case 5:
            hoofed(x - 14, base, 1, 3, 0)
            hoofed(x + 16, base + 1, 0.95, 2, 1.7)
        case 6:
            coyote(x - 12, base + 1, NOW * 3)
            coyote(x + 10, base + 2, NOW * 3 + 1.4)
        case 7:
            for k in 0..<7 { quail(x - 24 + Double(k) * 8, base + 1 + Double(k % 2), NOW * 6 + Double(k)) }
        case 8:
            for k in 0..<5 {
                let d = Double(k)
                saguaro(x - 60 + d * 30, base, 46 + hashN(d + 4300) * 30, d + 4310, SAG, true)
            }
        case 9:
            // a giant human figure scraped into the dark desert pavement, seen from close by
            c.ell(x, base + 8, 70, 7, Col(0x4a3a30).shade(1 - dark * 0.5))
            let ln = Col(0xe8d4b0).shade(1 - dark * 0.4)
            c.circ(x - 44, base + 8, 2.4, ln)
            c.seg(x - 41, base + 8, x + 20, base + 8, 1.4, ln)
            c.seg(x - 30, base + 8, x - 22, base + 4, 1, ln); c.seg(x - 30, base + 8, x - 22, base + 12, 1, ln)
            c.seg(x + 20, base + 8, x + 44, base + 5, 1, ln); c.seg(x + 20, base + 8, x + 44, base + 11, 1, ln)
        case 10:
            c.ell(x, base + 3, 18, 2.4, Col(0x5a8aa0, 0.8).shade(1 - dark * 0.5))
            palm(x - 16, base, 44, 4400)
            palm(x + 10, base, 52, 4401)
            palm(x + 28, base, 38, 4402)
        case 11:
            c.R(x - 70, base + 6, 140, 2, Col(0xe8d4b0, 0.6))
            for k in 0..<9 { let d = Double(k); c.circ(x - 60 + hashN(d + 4500) * 120, base + 5 + hashN(d + 4510) * 4, 0.9, Col(0xc89a6a)) }
            let rk = Col(0x6a5a4a).shade(1 - dark * 0.5)
            c.ell(x + 30, base, 7, 3, rk); c.ell(x + 30, base - 4, 5, 2.4, rk.shade(1.1)); c.circ(x + 30, base - 7, 2, rk)
        case 12:
            let rx = x + sin(NOW * 0.8) * 30
            let col = Col(0x6a5a44).shade(1 - dark * 0.5)
            c.seg(rx, base - 3, rx + 1, base, 0.6, col)
            c.ell(rx, base - 4, 3.6, 1.6, col)
            c.seg(rx - 3, base - 4.4, rx - 8, base - 6.4, 1, col)
            c.circ(rx + 3, base - 6, 1.2, col)
            c.seg(rx + 4, base - 6, rx + 6.4, base - 5.8, 0.5, INK)
        case 13:
            let blk = Col(0x2a2624).shade(1 - dark * 0.3)
            c.ell(x, base - 4, 16, 6, blk)
            let lz = Col(0x4a3a2e)
            c.ell(x + 2, base - 10.4, 5, 1.6 + abs(sin(NOW * 0.7)) * 0.6, lz)
            c.seg(x - 2, base - 10, x - 9, base - 9.4, 1, lz)
            c.circ(x + 7, base - 10.6, 1.4, lz)
        case 14:
            let snag = Col(0x6a5a4a).shade(1 - dark * 0.5)
            c.seg(x, base, x + 2, base - 40, 2.4, snag)
            c.seg(x + 2, base - 30, x + 12, base - 38, 1.2, snag)
            let e = Col(0x4a3420)
            c.ell(x + 2, base - 44, 2.6, 4.4, e)
            c.circ(x + 2.6, base - 49, 1.8, Col(0x8a6a3a))
            soar(x - 60 + sin(NOW * 0.2) * 40, GY - 90, 16, false)
        case 15:
            c.dome(x - 10, base + 1, 7, Col(0xc8a070).shade(1 - dark * 0.5))
            c.ell(x - 10, base, 2.4, 2, Col(0x2a1e14))
            let fox = Col(0xc8a880).shade(1 - dark * 0.4)
            c.ell(x + 6, base - 3, 4, 2, fox)
            c.circ(x + 10, base - 4.6, 1.6, fox)
            c.poly(fox, [x + 9, base - 5.6, x + 9.4, base - 9, x + 10.4, base - 5.8])
            c.poly(fox, [x + 10.6, base - 5.8, x + 11.6, base - 9, x + 11.8, base - 5.4])
            c.seg(x + 2, base - 3, x - 3, base - 1, 1.4, fox)
            c.circ(x - 3.4, base - 1, 1, INK)
        default:
            break
        }
    }

    /// The wild things moving through, a thousand years ago: pronghorn on the flats, condors overhead, quail in the brush.
    private func pastWild(_ ar: Area) {
        if g.deep { deepWild(ar); return }
        if g.iceAge { iceWild(ar); return }
        ravens()
        let night = dark > 0.5
        if night { return }
        if [Area.ltva, .hijolly, .plomosa, .main, .tyson, .roadrunner, .scaddan].contains(ar) {
            let hx = (NOW * 9).truncatingRemainder(dividingBy: g.WORLD + 400) - 200
            for k in 0..<5 { hoofed(hx + Double(k) * 22 - cam, GY + 2 + Double(k % 2), 0.85, 0, Double(k) * 1.1) }
        }
        if [Area.dome, .crystal, .palms, .desertbar, .intaglios].contains(ar) {
            let t = NOW * 0.18
            soar(W * 0.6 + cos(t) * W * 0.3, GY * 0.44 + sin(t * 1.3) * 8, 24, true)
        }
        for k in 0..<5 { quail(260 + Double(k) * 7 - cam + sin(NOW * 0.3) * 20, GY + 2 + Double(k % 2), NOW * 6 + Double(k)) }
        // people on the trail: traders walking between the river and the mountains, a runner now and then
        let span = g.WORLD + 240
        let tx = (NOW * 7 + Double(ar.rawValue) * 310).truncatingRemainder(dividingBy: span) - 120
        for k in 0..<3 {
            let vx = tx - Double(k) * 13 - cam
            let bob = abs(sin(NOW * 5 + Double(k) * 1.3)) * 0.8
            villager(vx, GY + 2 - bob, 40 + Double(k) + Double(ar.rawValue), k == 1 ? 1 : 0)
            if k != 1 { c.RR(vx - 3.6, GY - 15 - bob, 3.2, 5, 1, Col(0xb8925e).shade(1 - dark * 0.45)); c.seg(vx - 2, GY - 15 - bob, vx + 0.6, GY - 19 - bob, 0.3, Col(0x6a4a2e)) }
        }
        let rx = g.WORLD - (NOW * 16 + Double(ar.rawValue) * 170).truncatingRemainder(dividingBy: span * 1.6) + 100
        villager(rx - cam, GY + 2 - abs(sin(NOW * 9)) * 1.4, 77, 0)
        // the small animals that were always here
        var n = floor((cam - 60) / 230)
        while n * 230 < cam + W + 60 {
            let hk = hashN(n * 2.3 + Double(ar.rawValue) * 5 + 9980)
            let wx = n * 230 + hk * 150
            let sx = wx - cam
            n += 1
            if wx < 80 || wx > g.WORLD - 80 { continue }
            switch Int(hk * 100) % 6 {
            case 0: jackrabbit(sx, GY + 2, NOW + wx)
            case 1: roadrunner(sx + sin(NOW * 0.4 + wx) * 30, GY + 2, NOW * 8)
            case 2: coyote(sx + sin(NOW * 0.15 + wx) * 40, GY + 3, NOW * 2)
            case 3:
                // a trail shrine: a heap of stones every traveller adds to, and a broken pot
                for q in 0..<9 { c.ell(sx - 5 + hashN(Double(q) + wx) * 10, GY + 1 - hashN(Double(q) + wx + 3) * 5, 2 - hashN(Double(q) + wx + 3) * 1, 1.1, Col(0x7a6a5e).shade(1 - dark * 0.45 + hashN(Double(q)) * 0.12)) }
                c.arcStroke(sx + 10, GY + 1.4, 2, PI, PI * 1.8, 0.5, Col(0xb8704a)); c.poly(Col(0xb8704a), [sx + 13, GY + 2, sx + 14.6, GY + 1, sx + 15, GY + 2.2])
            case 4:
                // a grinding slick worn into a flat boulder, the handstone left on it
                c.poly(Col(0x8a7a6a).shade(1 - dark * 0.45), [sx - 9, GY + 2, sx - 6, GY - 3, sx + 6, GY - 4, sx + 10, GY + 2])
                c.ell(sx, GY - 3, 4, 0.9, Col(0xb0a290).shade(1 - dark * 0.45)); c.ell(sx + 1, GY - 3.6, 1.6, 0.8, Col(0x5a4e44))
            default:
                for k in 0..<4 { quail(sx + Double(k) * 6 + sin(NOW * 0.5 + wx) * 14, GY + 2 + Double(k % 2), NOW * 6 + Double(k)) }
            }
        }
        // cooking smoke standing up from a camp somewhere off toward the hills
        let smx = g.WORLD * 0.55 - cam * 0.3 - g.WORLD * 0.1
        for q in 0..<9 {
            let u = (NOW * 0.07 + Double(q) / 9).truncatingRemainder(dividingBy: 1)
            c.circ(smx + sin(u * 5 + Double(q)) * 3 + u * 14, GY - 6 - u * 44, 1.2 + u * 4, Col(0xe8e0d8, (1 - u) * 0.3))
        }
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
            let y = GY * (0.44 + d * 0.1) + sin(NOW * 0.7 + d) * 6
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
        // saguaros sliding past in silhouette
        for k in 0..<6 {
            let d = Double(k)
            let x = (d * 120 - pan * 1.6).truncatingRemainder(dividingBy: W + 200) + (d * 120 - pan * 1.6 < 0 ? W + 200 : 0) - 60
            saguaro(x, GY + 2, 50 + hashN(d + 40) * 30, d + 41, Col(0x2a2a24), false)
        }
        // the exit sign slides in
        let sx = W * 1.1 - u * W * 0.55
        c.R(sx - 1, GY - 40, 2, 46, Col(0x8a8f96)); c.R(sx + 50, GY - 40, 2, 46, Col(0x8a8f96))
        c.RR(sx - 6, GY - 66, 64, 28, 3, Col(0xf4f4f0)); c.RR(sx - 5, GY - 65, 62, 26, 2.6, Col(0x1f6b3a))
        g.text("EXIT 17", sx + 26, GY - 58, 5.6, CREAM, bold: true)
        g.text("QUARTZSITE", sx + 26, GY - 47.4, 6, CREAM, bold: true)
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
        let cy = H - 62.0
        if g.hasSave {
            let bw = 96.0
            c.RR(W / 2 - bw - 6, cy, bw, 22, 11, GOLD)
            g.text("Back to camp", W / 2 - bw / 2 - 6, cy + 11, 7.5, INK, bold: true)
            g.hits.append(Hit(id: 1, x: W / 2 - bw - 6, y: cy - 4, w: bw, h: 30))
            c.RR(W / 2 + 6, cy, bw, 22, 11, Col(0x1c1410, 0.7))
            g.text("New camper", W / 2 + bw / 2 + 6, cy + 11, 7.5, CREAM, bold: true)
            g.hits.append(Hit(id: 2, x: W / 2 + 6, y: cy - 4, w: bw, h: 30))
        } else {
            let bw = 120.0
            c.RR(W / 2 - bw / 2, cy, bw, 22, 11, GOLD.alpha(0.85 + 0.15 * sin(NOW * 3)))
            g.text("Tap to roll in", W / 2, cy + 11, 7.5, INK, bold: true)
        }
        // three small buttons in a row along the bottom
        let names = ["Contest rules", "Preview areas", "Send feedback"]
        let ids = [83, 88, 69]
        let pw = 76.0, gap = 8.0
        let rx = W / 2 - (pw * 3 + gap * 2) / 2
        for k in 0..<3 {
            let bx = rx + Double(k) * (pw + gap)
            c.RR(bx, H - 33, pw, 14, 7, Col(0x1c1410, 0.7))
            g.text(names[k], bx + pw / 2, H - 26, 4.6, k == 0 ? GOLD : CREAM, bold: true)
            g.hits.append(Hit(id: ids[k], x: bx - 3, y: H - 37, w: pw + 6, h: 22))
        }
        if g.rulesOpen { rulesOverlay() }
        if g.previewOpen { previewOverlay() }
    }

    /// Pick any place or event to walk around in. Nothing here touches the saved game.
    private func previewOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.6))
        let x0 = g.safeL + 16, x1 = W - g.safeR - 16, y0 = 8.0, y1 = H - 8
        let paper = Col(0xeadfc4), ink = Col(0x3a2c1e)
        c.RR(x0, y0, x1 - x0, y1 - y0, 6, paper)
        g.hits.append(Hit(id: -2, x: 0, y: 0, w: W, h: H))
        g.text("PREVIEW AREAS", x0 + 10, y0 + 10, 7, ink, align: 1, bold: true)
        g.text("Look around anywhere. Your saved game and contest score are not touched.", x1 - 10, y0 + 10, 4, ink.alpha(0.7), align: 2)
        let cols = 3
        let rows = (PREVIEWS.count + cols - 1) / cols
        let cw = (x1 - x0 - 20) / Double(cols)
        let rh = min(17.5, (y1 - y0 - 30) / Double(rows))
        for (k, pv) in PREVIEWS.enumerated() {
            let bx = x0 + 10 + Double(k % cols) * cw
            let by = y0 + 21 + Double(k / cols) * rh
            c.RR(bx + 1, by + 1, cw - 2, rh - 2.4, 4, pv.1.hasPrefix("past") ? Col(0xd8c9a0) : Col(0xf4ecd8))
            g.text(pv.0, bx + 8, by + rh / 2 - 0.4, 4.8, ink, align: 1, bold: true)
            g.hits.append(Hit(id: 200 + k, x: bx, y: by, w: cw, h: rh))
        }
        g.text("tap outside the list to close", x0 + 10, y1 - 5, 3.4, ink.alpha(0.55), align: 1)
    }

    /// The contest's official rules, always a tap away from the title screen.
    private func rulesOverlay() {
        g.hits.removeAll(keepingCapacity: true)
        g.texts.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a08, 0.6))
        let x0 = g.safeL + 16, x1 = W - g.safeR - 16, y0 = 8.0, y1 = H - 8
        let paper = Col(0xeadfc4), ink = Col(0x3a2c1e)
        c.RR(x0, y0, x1 - x0, y1 - y0, 6, paper)
        g.hits.append(Hit(id: -2, x: 0, y: 0, w: W, h: H))
        g.text("CRED CONTEST: OFFICIAL RULES", x0 + 10, y0 + 10, 7, ink, align: 1, bold: true)
        g.text("Your best season: \(max(g.bestSeason, g.seasonCred)) cred", x1 - 10, y0 + 10, 4.6, ink.alpha(0.75), align: 2, bold: true)
        let rules: [String] = [
            "Two prizes of 150 US dollars. Contest 1 ends January 31, 2027. Contest 2 runs February 1 to March 31, 2027. Each ends at 11:59 PM Pacific time.",
            "To win, earn the most cred in a single season. A season counts toward a contest only when it is started and scored inside that contest's dates. Your score posts to the Game Center leaderboard each game morning.",
            "Free to enter. No purchase necessary. This is a game of skill. Open to legal residents of the United States who are 18 or older. Void where prohibited. One prize per person.",
            "Ties go to the player who posted the score first. Cheating, modified copies of the game, or more than one account disqualify a player. The sponsor's decisions are final.",
            "The winner must write to bward916@gmail.com within 14 days of the contest's end and prove the Game Center account is theirs. Prizes are paid by check or PayPal. Any taxes are the winner's responsibility.",
            "Sponsor: Brian Ward, Blythe, California. Apple is not a sponsor of this contest and is not involved in it in any way."
        ]
        var ry = y0 + 24
        for (i, line) in rules.enumerated() {
            g.text("\(i + 1).", x0 + 10, ry, 4, ink, align: 1, bold: true)
            g.text(line, x0 + 20, ry, 4, ink, align: 1, wrap: x1 - x0 - 34)
            ry += i == 1 ? 21 : 17
        }
        c.RR(x1 - 92, y1 - 22, 82, 15, 7.5, Col(0x3b5bdb))
        g.text("Leaderboard", x1 - 51, y1 - 14.5, 5, CREAM, bold: true)
        g.hits.append(Hit(id: 84, x: x1 - 98, y: y1 - 28, w: 94, h: 26))
        g.text("tap anywhere to close", x0 + 10, y1 - 14.5, 4, ink.alpha(0.6), align: 1)
    }

    private func card(_ id: Int, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ on: Bool) {
        if on { c.RR(x - 1.5, y - 1.5, w + 3, h + 3, 6, GOLD) }
        c.RR(x, y, w, h, 5, on ? Col(0x3a2c1e, 0.97) : Col(0x1c1410, 0.86))
        g.hits.append(Hit(id: id, x: x, y: y, w: w, h: h))
    }

    private func pickOverlay() {
        // nothing from the scene behind should show through or be tappable
        g.texts.removeAll(keepingCapacity: true)
        g.hits.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x0c0a14, 0.84))
        let l = g.safeL + 14
        let uw = W - g.safeL - g.safeR - 28

        g.text("HOW DO YOU ROLL?", l, 11, 6, GOLD, align: 1, bold: true)
        let cw = (uw - 8) / 2
        let lifeName = ["NOMAD", "RVER"]
        let lifeSub = ["Vans, skoolies and friends. Starts with 5 cred and a bicycle.", "A snowbird with a check coming. Starts with 100 more coins and a side-by-side."]
        for i in 0..<2 {
            let x = l + Double(i) * (cw + 8)
            card(i, x, 17, cw, 38, g.life.rawValue == i)
            rig(i == 0 ? .skoolie : .classC, x + 27, 50, i == 0 ? 1 : 0, 1, 0.42)
            g.text(lifeName[i], x + 54, 26, 8, CREAM, align: 1, bold: true)
            g.text(lifeSub[i], x + 54, 42, 4.2, CREAM.alpha(0.85), align: 1, wrap: cw - 60)
        }

        g.text("YOUR FIRST RIG", l, 66, 6, GOLD, align: 1, bold: true)
        let rw = (uw - 16) / 3
        for i in 0..<3 {
            let x = l + Double(i) * (rw + 8)
            card(10 + i, x, 72, rw, 42, g.pickRig == i)
            let cash = Int(START_CASH[i]) + (g.life == .rver ? 100 : 0)
            g.text(RIGS[START_RIGS[i].rawValue].name, x + 7, 80, 5.6, CREAM, align: 1, bold: true)
            rig(START_RIGS[i], x + 30, 109, 0, 1, 0.66)
            coin(x + rw - 25, 102, 3)
            g.text("\(cash)", x + rw - 20, 102, 6.4, GOLD, align: 1, bold: true)
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

let STRIPES: [Col] = [Col(0xffffff), Col(0xc8281e), Col(0x2e5a9a), Col(0x2fa7a0), Col(0xe8782e), Col(0x6a3a8a), Col(0x3a8a4a), Col(0x1c1a1a)]
let FLAGS: [(Col, Col)] = [(Col(0xffffff), Col(0xffffff)), (Col(0xc8281e), Col(0xf4f4f0)), (Col(0xf2c14e), Col(0xb5452f)), (Col(0x2fa7a0), Col(0xf4f4f0)), (Col(0x1c1a1a), Col(0xf4f4f0)), (Col(0x8a4aa8), Col(0xf2c14e)), (Col(0x3a8a4a), Col(0xf2c14e))]
