import Foundation

struct Pose {
    var lean = 0.0
    var head = 0.0
    var bob = 0.0
    var hipF = 0.0
    var kneeF = 0.1
    var hipB = 0.0
    var kneeB = 0.1
    var armF = 0.2
    var elbF = 0.4
    var armB = -0.2
    var elbB = 0.3
    var wpn = 0.0
}
struct Look {
    var shirt: Col
    var pants: Col
    var skin: Col
    var hair: Col
    var eye: Col
    var weapon = 0
    var zombie = false
    var fat = 1.0
    var longHair = false
    var coat = false
}

struct Rect4 {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    func has(_ px: Double, _ py: Double) -> Bool { return px >= x - 8 && px <= x + w + 8 && py >= y - 8 && py <= y + h + 8 }
}

extension Game {
    var atkBtn: (Double, Double, Double) { return (W - safeR - 104, VIEW_H - 118, 62) }
    var powBtn: (Double, Double, Double) { return (W - safeR - 238, VIEW_H - 84, 46) }
    var pauseRect: Rect4 { return Rect4(x: W / 2 - 24, y: 8, w: 48, h: 32) }
    var playRect: Rect4 { return Rect4(x: W / 2 - 170, y: 372, w: 340, h: 76) }
    var contRect: Rect4 { return Rect4(x: W / 2 - 150, y: 462, w: 300, h: 40) }
    var resumeRect: Rect4 { return Rect4(x: W / 2 - 150, y: 210, w: 300, h: 64) }
    var quitRect: Rect4 { return Rect4(x: W / 2 - 150, y: 296, w: 300, h: 54) }
    func pickRect(_ i: Int) -> Rect4 {
        let cw = 300.0, gap = 44.0
        let n = Double(max(1, pickOpts.count))
        let x0 = W / 2 - (n * cw + (n - 1) * gap) / 2
        return Rect4(x: x0 + Double(i) * (cw + gap), y: 128, w: cw, h: 330)
    }
}

final class Renderer {
    let GY = 410.0
    private var camX = 0.0
    private var camFloor = -99
    var paused = false

    func draw(_ g: Game, _ cv: Canvas) {
        let W = g.W
        cv.R(0, 0, W, VIEW_H, INK)
        switch g.mode {
        case .title: title(g, cv)
        case .intro: intro(g, cv)
        case .card: scene(g, cv); card(g, cv)
        case .play: scene(g, cv); hud(g, cv)
        case .dead: scene(g, cv); deadCard(g, cv)
        case .pick: scene(g, cv); pick(g, cv)
        case .ride: ride(g, cv)
        case .ending: ending(g, cv)
        }
        if g.flash > 0 { cv.R(0, 0, W, VIEW_H, g.flashCol.alpha(min(0.8, g.flash))) }
        if paused { pauseCard(g, cv) }
    }

    // ---------- figures
    private func limb(_ ox: Double, _ oy: Double, _ a1: Double, _ l1: Double, _ a2: Double, _ l2: Double) -> (Double, Double, Double, Double) {
        let kx = ox + l1 * sin(a1)
        let ky = oy + l1 * cos(a1)
        return (kx, ky, kx + l2 * sin(a2), ky + l2 * cos(a2))
    }
    func figure(_ cv: Canvas, _ x: Double, _ y: Double, _ face: Double, _ s: Double, _ L: Look, _ p: Pose, flash: Double = 0, fall: Double = 0, alpha: Double = 1) {
        cv.save()
        cv.translate(x, y)
        cv.scale(face * s, s)
        if fall > 0 { cv.rotate(-fall * PI / 2 * 0.97); cv.translate(0, -fall * 9) }
        if alpha < 1 { cv.alpha(alpha) }
        let fl = clampD(flash, 0, 1) * 0.85
        let shirt = Col.mix(L.shirt, WHITE, fl)
        let pants = Col.mix(L.pants, WHITE, fl)
        let skin = Col.mix(L.skin, WHITE, fl)
        let shirtD = Col.mix(shirt, BLACK, 0.3)
        let pantsD = Col.mix(pants, BLACK, 0.3)
        let skinD = Col.mix(skin, BLACK, 0.25)
        let shoe = Col(0x15151a)
        let hipY = -74.0 + p.bob
        let nx = 54 * sin(p.lean)
        let ny = hipY - 54 * cos(p.lean)
        let ha = p.lean * 1.3 + p.head
        let hx = nx + 19 * sin(ha)
        let hy = ny - 19 * cos(ha)
        let sy = ny + 9
        // back arm, back leg
        let ab = limb(nx, sy, p.armB, 27, p.armB + p.elbB, 26)
        cv.seg(nx, sy, ab.0, ab.1, 10, shirtD)
        cv.seg(ab.0, ab.1, ab.2, ab.3, 8.5, skinD)
        let lb = limb(0, hipY, p.hipB, 37, p.hipB - p.kneeB, 37)
        cv.seg(0, hipY, lb.0, lb.1, 14, pantsD)
        cv.seg(lb.0, lb.1, lb.2, lb.3, 12, pantsD)
        cv.seg(lb.2, lb.3, lb.2 + 9, lb.3, 8, shoe)
        // body
        cv.seg(0, hipY, nx, ny + 4, 25 * L.fat, shirt)
        if L.fat > 1.3 { cv.circ(nx * 0.45 + 6, (hipY + ny) / 2 + 6, 21 * L.fat * 0.62, shirt) }
        if L.coat { cv.seg(-2, hipY + 4, nx - 3, ny + 8, 9, Col.mix(shirt, BLACK, 0.18)) }
        if L.zombie {
            cv.circ(nx * 0.5 + 3, (hipY + ny) / 2, 6 * L.fat, BLOOD.alpha(0.8))
            cv.circ(nx * 0.3 - 4, hipY - 12, 4 * L.fat, BLOOD.alpha(0.7))
        }
        // front leg
        let lf = limb(0, hipY, p.hipF, 37, p.hipF - p.kneeF, 37)
        cv.seg(0, hipY, lf.0, lf.1, 14, pants)
        cv.seg(lf.0, lf.1, lf.2, lf.3, 12, pants)
        cv.seg(lf.2, lf.3, lf.2 + 10, lf.3, 8, shoe)
        // head
        cv.seg(nx, ny, hx, hy, 9, skinD)
        cv.circ(hx, hy, 15, skin)
        if L.longHair { cv.seg(hx - 9, hy - 6, hx - 14, hy + 18, 9, L.hair) }
        cv.arcFill(hx, hy, 15.6, PI * 0.98, PI * 1.9, L.hair)
        cv.circ(hx + 7, hy - 1, 2.3, L.eye)
        if L.zombie {
            cv.R(hx + 3, hy + 6, 9, 3.5, Col(0x1a0a0a))
            cv.circ(hx - 3, hy + 3, 3, BLOOD.alpha(0.7))
        }
        // front arm and what it holds
        let af = limb(nx, sy, p.armF, 27, p.armF + p.elbF, 26)
        if L.weapon > 0 {
            let wa = p.armF + p.elbF + p.wpn
            let len = L.weapon == 3 ? 78.0 : 64.0
            let gx = af.2 - 10 * sin(wa), gy = af.3 - 10 * cos(wa)
            let tx = af.2 + len * sin(wa), ty = af.3 + len * cos(wa)
            if L.weapon == 1 {
                cv.seg(gx, gy, tx, ty, 6, Col(0x8a6a44))
                cv.seg(af.2 + len * 0.45 * sin(wa), af.3 + len * 0.45 * cos(wa), tx, ty, 9.5, Col(0xd9b98a))
            } else if L.weapon == 2 {
                cv.seg(gx, gy, tx, ty, 5, Col(0xe8e4dc))
                cv.seg(tx, ty, tx + 16 * sin(wa + 1.3), ty + 16 * cos(wa + 1.3), 6, Col(0x22262e))
            } else {
                cv.seg(gx, gy, tx, ty, 4.5, Col(0xc9a24a))
                cv.seg(af.2 + len * 0.8 * sin(wa), af.3 + len * 0.8 * cos(wa), tx, ty, 3, Col(0xf2ecd8))
            }
        }
        cv.seg(nx, sy, af.0, af.1, 10.5, shirt)
        cv.seg(af.0, af.1, af.2, af.3, 9, skin)
        cv.restore()
    }

    func heroLook(_ t: Tower) -> Look {
        var l = Look(shirt: t.shirt, pants: t.pants, skin: t.skin, hair: t.hair, eye: Col(0x15151a))
        l.weapon = t.weapon
        l.longHair = t.weapon != 1
        return l
    }
    func heroPose(_ g: Game) -> Pose {
        let h = g.hero
        var p = Pose()
        let t = g.t
        if g.supT >= 0 {
            let u = g.supT / g.supDur
            p.lean = 0.35
            p.armF = 1.5 + sin(u * 26) * 1.6
            p.elbF = 0.2
            p.wpn = 0.1
            p.armB = -0.9
            p.hipF = 0.8; p.kneeF = 0.5; p.hipB = -0.7; p.kneeB = 0.3
            p.bob = 6
            return p
        }
        if h.moving && h.atkT < 0 {
            let ph = h.walk * 0.042
            p.hipF = 0.78 * sin(ph)
            p.hipB = -0.78 * sin(ph)
            p.kneeF = 0.25 + 0.85 * max(0, -cos(ph))
            p.kneeB = 0.25 + 0.85 * max(0, cos(ph))
            p.lean = 0.2
            p.bob = abs(cos(ph)) * 5
            p.armB = 0.8 * sin(ph)
            p.elbB = 0.9
            p.armF = -0.35 - 0.25 * sin(ph)
            p.elbF = 1.5
            p.wpn = 1.2
        } else {
            p.bob = sin(t * 2.6) * 1.5 + 2
            p.hipF = 0.2; p.hipB = -0.2
            p.armF = 0.15; p.elbF = 1.35; p.wpn = 1.25
            p.armB = -0.15; p.elbB = 0.5
            p.lean = 0.05
        }
        if h.atkT >= 0 {
            let dur = h.atkI == 2 ? 0.36 : 0.25
            let u = clampD(h.atkT / dur, 0, 1)
            let e = easeOut(min(1, u / 0.55))
            if h.atkI == 1 {
                p.armF = lerp(0.1, 2.7, e); p.elbF = 0.25; p.wpn = 0.1
            } else if h.atkI == 2 {
                p.armF = lerp(4.0, 0.7, e); p.elbF = 0.2; p.wpn = 0.15
            } else {
                p.armF = lerp(3.5, 1.1, e); p.elbF = 0.3; p.wpn = 0.1
            }
            p.lean = 0.12 + 0.32 * sin(u * PI)
            p.hipF = 0.5 + 0.25 * sin(u * PI); p.kneeF = 0.4
            p.hipB = -0.45; p.kneeB = 0.15
            p.bob = 4 + 3 * sin(u * PI)
            p.armB = -0.8
        }
        if h.hurtT > 0 { p.lean = -0.3; p.head = -0.3 }
        return p
    }
    private let zShirts: [Col] = [Col(0x5a6470), Col(0x6a5a4a), Col(0x4a5a4e), Col(0x6e4a4e), Col(0x565070)]
    func zedLook(_ z: Zed) -> Look {
        var l = Look(shirt: zShirts[z.look % 5], pants: Col(0x33363c), skin: Col(0x9fb08c), hair: Col(0x2a2a26), eye: Col(0xffe14a))
        l.zombie = true
        if z.kind == .runner { l.skin = Col(0xb89a8a); l.shirt = Col(0x7a3a36); l.eye = Col(0xff5a4a) }
        if z.kind == .bloater { l.fat = 1.9; l.skin = Col(0x9ac06a); l.shirt = Col(0x6a7a3a); l.eye = Col(0xd9ff7a) }
        if z.kind == .boss { l.fat = 1.5; l.skin = Col(0x8cc09a); l.shirt = Col(0xd9dcd6); l.pants = Col(0x2a2f3c); l.coat = true; l.eye = Col(0x7dffb0); l.hair = Col(0x9a9a92) }
        return l
    }
    func zedPose(_ z: Zed, _ t: Double) -> Pose {
        var p = Pose()
        let ph = z.walk * (z.kind == .runner ? 0.05 : 0.07)
        let sw = z.kind == .runner ? 0.75 : 0.45
        p.hipF = sw * sin(ph)
        p.hipB = -sw * sin(ph)
        p.kneeF = 0.2 + 0.5 * max(0, -cos(ph))
        p.kneeB = 0.2 + 0.5 * max(0, cos(ph))
        p.lean = z.kind == .runner ? 0.45 : 0.26
        p.head = 0.25 + 0.12 * sin(t * 3 + z.seed * 9)
        p.bob = abs(cos(ph)) * 3
        p.armF = 1.4 + 0.14 * sin(t * 3.1 + z.seed * 20)
        p.elbF = 0.15
        p.armB = 1.15 + 0.14 * sin(t * 2.7 + z.seed * 11)
        p.elbB = 0.2
        if z.atkT >= 0 {
            let u = clampD(z.atkT / z.windup, 0, 1.6)
            if u < 1 { p.armF = lerp(1.4, 2.7, u); p.armB = lerp(1.15, 2.5, u); p.lean = 0.1 } else { p.armF = 0.9; p.armB = 0.8; p.lean = 0.55 }
        }
        if z.stun > 0 { p.lean = -0.3; p.head = -0.4; p.armF = 0.4; p.armB = 0.2 }
        return p
    }
    func beast(_ cv: Canvas, _ z: Zed, _ y: Double, _ t: Double) {
        let dead = !z.alive
        let dk: Double = dead ? min(1, z.deadT * 3.5) : 0
        let mv = !dead && z.atkT < 0 && z.aware && z.stun <= 0
        let ph = z.walk * 0.085
        let bite: Double = z.atkT >= 0 ? sin(min(1, z.atkT / (z.windup + 0.28)) * PI) : 0
        let hitC = z.flash > 0.3
        cv.save()
        cv.translate(z.x, y)
        if dead { cv.alpha(max(0.2, 1 - z.deadT / 6)) }
        if z.kind == .rat {
            cv.scale(z.face, 1)
            var by = -5.0
            if !dead {
                let hop: Double = mv ? abs(sin(ph * 3)) * 2 : 0
                by = -9.0 - hop - bite * 8
            }
            cv.translate(bite * 8, 0)
            cv.curve(-13, by + 2, -26, by - 6 + sin(ph * 2) * 3, -34, by + 5, 2, Col(0xb98a86))
            if !dead {
                for lx in [-8.0, 8.0] {
                    let sw: Double = mv ? sin(ph * 3 + lx) * 5 : 0
                    cv.seg(lx, by + 4, lx + sw, 0, 2.2, Col(0x1a1512))
                }
            }
            let fur = hitC ? Col(0xe8e0d8) : Col(0x2b2420)
            cv.ell(0, by, 15, 7.5, fur)
            cv.poly(fur, [8, by - 6, 25, by + 1, 8, by + 6])
            cv.circ(9, by - 6, 3.5, fur)
            cv.ell(-4, by - 2, 5, 3, Col(0x6a1418))
            if !dead { cv.circ(16, by - 2, 1.6, Col(0xff4a3a)) }
            cv.restore()
            return
        }
        cv.scale(z.face * 1.3, 1.3)
        let trot: Double = mv ? abs(sin(ph)) * 4 : 0
        let by: Double = -46.0 + dk * 34 - trot - bite * 12
        cv.translate(bite * 22, 0)
        cv.rotate(-bite * 0.18)
        let fur = hitC ? Col(0xe8e0d8) : Col(0x2c2724)
        let furD = hitC ? Col(0xcfc6bc) : Col(0x1a1715)
        cv.curve(-36, by - 4, -52, by - 18 + sin(t * 9 + z.x) * 4 + dk * 24, -58, by - 4 + dk * 14, 5, furD)
        func leg(_ hx: Double, _ off: Double, _ col: Col) {
            if dead {
                cv.line(col, 6, [hx, by + 6, hx + 16, by + 12, hx + 34, by + 9])
            } else {
                let sw: Double = mv ? sin(ph + off) * 17 : 0
                let lift: Double = mv ? max(0, cos(ph + off)) * 9 : 0
                cv.line(col, 6, [hx, by + 6, hx + sw * 0.4 - 4, by + 24 - lift * 0.5, hx + sw + bite * 8, -lift])
            }
        }
        leg(-28, 0, furD)
        leg(18, PI * 0.9, furD)
        cv.ell(-4, by, 34, 13, fur)
        cv.circ(20, by - 1, 16, fur)
        cv.circ(-26, by + 1, 14, fur)
        cv.ell(-2, by + 2, 15, 9, Col(0x7a1c20))
        for i in 0..<4 {
            let rx = -12.0 + Double(i) * 7
            cv.curve(rx, by - 5, rx + 3, by + 3, rx - 1, by + 10, 2.2, Col(0xd8d0bc))
        }
        leg(-20, PI, fur)
        leg(26, PI * 1.9, fur)
        let hx: Double = dead ? 46 : 40
        let nod: Double = mv ? sin(ph) * 2 : 0
        let hy: Double = by - 16 + dk * 20 + nod
        cv.seg(26, by - 6, hx, hy, 15, fur)
        cv.circ(hx + 4, hy, 11, fur)
        cv.poly(fur, [hx - 2, hy - 9, hx - 6, hy - 24, hx + 7, hy - 10])
        var jaw = 0.1
        if !dead {
            let pant: Double = mv ? 0.1 + 0.08 * sin(ph * 2) : 0
            jaw = 0.12 + bite * 0.6 + pant
        }
        cv.save()
        cv.translate(hx + 8, hy + 1)
        cv.save()
        cv.rotate(-jaw * 0.5)
        cv.poly(fur, [0, -7, 24, -4, 24, 1, 0, 2])
        for i in 0..<4 { let tx = 7.0 + Double(i) * 4.5; cv.poly(Col(0xf2ecd8), [tx, 1, tx + 2, 6, tx + 4, 1]) }
        cv.restore()
        cv.rotate(jaw)
        cv.poly(Col(0x7a1014), [0, 1, 21, 2, 20, 7, 0, 8])
        for i in 0..<3 { let tx = 8.0 + Double(i) * 4.5; cv.poly(Col(0xf2ecd8), [tx, 2, tx + 2, -3, tx + 4, 2]) }
        cv.restore()
        if !dead { cv.circ(hx + 8, hy - 4, 2.6, Col(0xffe14a)) }
        if z.burn > 0 && !dead { cv.lighter(true); cv.ell(0, by - 4, 44, 24, rgba(255, 140, 40, 0.45)); cv.lighter(false) }
        cv.restore()
    }

    // ---------- flames
    func flameWall(_ cv: Canvas, _ x: Double, _ w: Double, _ hgt: Double, _ seed: Double, _ t: Double) {
        cv.lighter(true)
        cv.glow(x, GY - hgt * 0.4, w * 1.5, rgba(255, 130, 40, 0.3 + 0.06 * sin(t * 11 + seed)))
        cv.lighter(false)
        let layers: [(Double, Col)] = [(1, rgba(255, 110, 25, 0.9)), (0.72, rgba(255, 200, 80, 0.95)), (0.42, rgba(255, 246, 210, 0.95))]
        let N = 14
        for (sc, col) in layers {
            var pts: [Double] = [x - w / 2 * sc, GY]
            for i in 0...N {
                let u = Double(i) / Double(N)
                let fi = Double(i)
                let wob = abs(sin(fi * 1.9 + seed + t * (5 + sc * 3) + sin(t * 3.1 + fi)))
                let fh = hgt * sc * (0.5 + 0.5 * wob) * (0.35 + 0.65 * sin(u * PI))
                let px = x - w / 2 * sc + w * sc * u
                pts.append(px - 5); pts.append(GY - fh * 0.6)
                pts.append(px + sin(t * 7 + fi) * 6); pts.append(GY - fh)
            }
            pts.append(x + w / 2 * sc); pts.append(GY)
            cv.poly(col, pts)
        }
    }

    // ---------- the floor you are on
    private func night(_ cv: Canvas, _ x: Double, _ w: Double, _ h: Double, _ t: Double) {
        cv.vfill(x, 0, w, h, [(0, Col(0x03040a)), (0.6, Col(0x140c22)), (1, Col(0x4a2018))])
        for i in 0..<50 {
            let fi = Double(i)
            let a = 0.3 + 0.7 * abs(sin(t * 0.8 + fi))
            cv.R(x + hashN(fi) * w, hashN(fi + 40) * h * 0.7, 2, 2, WHITE.alpha(a * 0.8))
        }
    }
    private func skyline(_ cv: Canvas, _ x: Double, _ w: Double, _ base: Double, _ par: Double) {
        var bx = x - 40 - (par.truncatingRemainder(dividingBy: 90))
        var i = Int(par / 90)
        while bx < x + w {
            let fi = Double(abs(i))
            let bh = 80 + hashN(fi * 3.1) * 190
            let bw = 60 + hashN(fi * 1.7) * 40
            cv.R(bx, base - bh, bw, bh, Col(0x0d0f1a))
            var wy = base - bh + 10
            while wy < base - 12 {
                var wx = bx + 6
                while wx < bx + bw - 8 {
                    if hashN(wx * 0.37 + wy * 1.3) > 0.72 { cv.R(wx, wy, 5, 7, rgba(255, 220, 160, 0.4)) }
                    wx += 11
                }
                wy += 14
            }
            bx += bw + 12
            i += 1
        }
    }
    private func sign(_ cv: Canvas, _ s: String, _ x: Double, _ y: Double, _ col: Col, _ t: Double, arrow: Bool = true) {
        let w = cv.textW(s, 14, 3) + 22
        cv.RR(x - w / 2, y - 14, w, 24, 5, Col(0x0d1a13))
        cv.text(s, x, y + 4, 14, col, 1, 3)
        if arrow {
            let b = sin(t * 5) * 4
            cv.poly(col, [x - 9, y + 16 + b, x + 9, y + 16 + b, x, y + 28 + b])
        }
    }
    private func drawFloor(_ g: Game, _ cv: Canvas, _ x0: Double, _ W: Double) {
        let f = g.floor
        let z = g.zone(f.n)
        let t = g.t
        let x1 = x0 + W
        if f.kind == .roof || f.kind == .street {
            night(cv, x0, W, GY, t)
            skyline(cv, x0, W, GY - (f.kind == .roof ? 20 : 0), x0 * 0.3)
            if f.kind == .street {
                var bx = 0.0
                var i = 0
                while bx < FLOOR_W {
                    let h = 250 + hashN(Double(i) * 5.3) * 90
                    let face: Col = i % 2 == 0 ? Col(0x17141c) : Col(0x1c1820)
                    cv.R(bx, GY - h, 190, h, face)
                    for r in 0..<3 { for c in 0..<3 {
                        let wx = bx + 22 + Double(c) * 54, wy = GY - h + 26 + Double(r) * 64
                        let burn = (i * 3 + r * 5 + c) % 7 == 0
                        cv.R(wx, wy, 36, 44, burn ? rgba(255, 140, 40, 0.75 + 0.2 * sin(t * 9 + wx)) : Col(0x07080c))
                    } }
                    bx += 200
                    i += 1
                }
                cv.lighter(true); cv.glow(x0 + W / 2, GY, 700, rgba(255, 90, 30, 0.22)); cv.lighter(false)
                cv.R(x0, GY, W, VIEW_H - GY, Col(0x17181c))
                var dx = (x0 / 90).rounded(.down) * 90
                while dx < x1 { cv.R(dx, GY + 50, 46, 4, rgba(232, 200, 96, 0.5)); dx += 90 }
                sign(cv, "THE PLAZA", f.exitX, GY - 190, MINT, t)
            } else {
                cv.R(x0, GY, W, VIEW_H - GY, Col(0x1b1d24))
                var rx = (x0 / 16).rounded(.down) * 16
                while rx < x1 { cv.R(rx, GY - 78, 2, 78, Col(0x2a2f3b)); rx += 16 }
                cv.R(x0, GY - 80, W, 4, Col(0x2a2f3b))
                let dx = f.exitX
                cv.R(dx - 110, GY - 250, 260, 250, Col(0x22262f))
                cv.R(dx - 118, GY - 258, 276, 12, Col(0x2f3440))
                cv.R(dx - 45, GY - 190, 90, 190, Col(0x060608))
                sign(cv, "STAIRS", dx, GY - 214, MINT, t)
            }
            return
        }
        // inside
        cv.R(x0, 0, W, GY - 300, Col.mix(z.wall, BLACK, 0.72))
        cv.R(x0, GY - 300, W, 300, z.wall)
        cv.R(x0, GY - 312, W, 14, Col.mix(z.floor, BLACK, 0.5))
        cv.R(x0, GY - 14, W, 14, Col.mix(z.wall, BLACK, 0.3))
        let lightsOn = f.n % 4 != 0
        var px = (x0 / 300).rounded(.down) * 300
        while px < x1 + 300 {
            // a window, then a door
            let wx = px + 40
            cv.R(wx - 6, GY - 236, 132, 152, z.trim)
            cv.vfill(wx, GY - 230, 120, 140, [(0, Col(0x05060c)), (0.55, Col(0x1a1024)), (1, Col(0x8a3a1c))])
            let par = wx * 0.5
            for b in 0..<4 {
                let fb = Double(b)
                let bh = 30 + hashN(fb + (par / 100).rounded(.down)) * 70
                cv.R(wx + fb * 30, GY - 90 - bh, 24, bh, Col(0x08090f))
            }
            cv.R(wx + 58, GY - 230, 4, 140, z.trim)
            cv.R(wx, GY - 162, 120, 4, z.trim)
            let dx = px + 200
            cv.R(dx - 4, GY - 176, 74, 176, Col.mix(z.trim, BLACK, 0.2))
            cv.R(dx, GY - 172, 66, 172, Col.mix(z.wall, BLACK, 0.45))
            cv.circ(dx + 56, GY - 84, 3.5, GOLD.alpha(0.8))
            let num = f.n * 100 + Int(abs(px) / 150) % 60 + 1
            cv.text("\(num)", dx + 33, GY - 184, 10, WHITE.alpha(0.45), 1, 1)
            // ceiling light
            cv.R(px + 150, GY - 300, 60, 5, lightsOn ? Col(0xfff2d0) : Col(0x3a3a3a))
            if lightsOn { cv.lighter(true); cv.glow(px + 180, GY - 290, 150, rgba(255, 240, 200, 0.10)); cv.lighter(false) }
            px += 300
        }
        for p in f.props where p.x > x0 - 80 && p.x < x1 + 80 { prop(cv, p, z) }
        // floor and what is under it
        cv.R(x0, GY, W, 22, z.floor)
        cv.R(x0, GY, W, 3, Col.mix(z.floor, WHITE, 0.15))
        cv.R(x0, GY + 22, W, 14, Col(0x101216))
        cv.R(x0, GY + 36, W, VIEW_H - GY - 36, Col.mix(g.zone(f.n - 1).wall, BLACK, 0.55))
        // end walls
        cv.R(-400, 0, 400 + 46, VIEW_H, Col(0x0c0d12))
        cv.R(FLOOR_W - 46, 0, 446, VIEW_H, Col(0x0c0d12))
        for (px2, r) in f.pools { cv.ell(px2, GY + 8, r, r * 0.16, Col(0x5a0c10, 0.75)) }
        // the way out
        let ex = f.exitX
        cv.R(ex - 44, GY - 190, 88, 190, Col(0x060608))
        cv.RRStroke(ex - 44, GY - 190, 88, 190, 2, 4, Col.mix(z.trim, BLACK, 0.2))
        if f.kind == .hole {
            if f.fireStairs { flameWall(cv, ex, 190, 260, 1.3, t); flameWall(cv, ex + 10, 110, 190, 3.7, t) } else {
                cv.poly(Col(0x4a443c), [ex - 90, GY, ex - 50, GY - 80, ex - 10, GY - 50, ex + 30, GY - 120, ex + 86, GY])
                cv.poly(Col(0x3a352f), [ex - 60, GY, ex - 20, GY - 40, ex + 40, GY - 70, ex + 70, GY])
            }
            sign(cv, f.fireStairs ? "ON FIRE" : "COLLAPSED", ex, GY - 214, HOT, t, arrow: false)
            let hx = f.holeX
            cv.ell(hx, GY + 8, 62, 13, Col(0x020203))
            cv.poly(Col(0x020203), [hx - 62, GY + 8, hx - 50, GY - 2, hx - 30, GY + 3, hx - 8, GY - 4, hx + 18, GY + 2, hx + 44, GY - 3, hx + 62, GY + 8])
            cv.poly(Col.mix(z.floor, BLACK, 0.4), [hx - 80, GY, hx - 62, GY - 9, hx - 56, GY])
            cv.poly(Col.mix(z.floor, BLACK, 0.4), [hx + 80, GY, hx + 64, GY - 12, hx + 54, GY])
            sign(cv, "DROP DOWN", hx, GY - 120, MINT, t)
        } else if f.kind == .lift {
            for i in 0..<4 { cv.seg(ex - 46, GY - 40 - Double(i) * 40, ex + 46, GY - 70 - Double(i) * 36, 10, Col(0x6a5238)) }
            sign(cv, "BLOCKED", ex, GY - 214, HOT, t, arrow: false)
            let lx = f.liftX
            let clear = g.aliveCount == 0
            cv.R(lx - 62, GY - 196, 124, 196, Col(0x2a2e36))
            cv.R(lx - 54, GY - 188, 52, 188, Col(0x8a929c))
            cv.R(lx + 2, GY - 188, 52, 188, Col(0x7c848e))
            cv.R(lx - 1, GY - 188, 2, 188, Col(0x1a1c20))
            cv.RR(lx - 22, GY - 224, 44, 20, 3, Col(0x0a0a0c))
            cv.text("\(f.n)", lx, GY - 209, 13, clear ? MINT : HOT, 1, 3)
            sign(cv, clear ? "ELEVATOR" : "CLEAR THE FLOOR", lx, GY - 250, clear ? MINT : HOT, t, arrow: clear)
        } else {
            sign(cv, "STAIRS", ex, GY - 214, MINT, t)
        }
        if f.kind == .wall {
            let wx = f.wallX
            cv.poly(Col(0x17120f), [wx - 120, GY, wx - 70, GY - 46, wx - 10, GY - 28, wx + 50, GY - 60, wx + 118, GY])
            cv.seg(wx - 96, GY - 300, wx + 60, GY - 20, 14, Col(0x241a14))
            cv.seg(wx + 100, GY - 300, wx - 20, GY - 40, 14, Col(0x241a14))
            flameWall(cv, wx, 220, 300, 0, t)
            flameWall(cv, wx + 14, 110, 220, 2.1, t)
            let pl = 0.6 + 0.4 * sin(t * 5)
            for (dx, sd) in [(f.doorA, 1.0), (f.doorB, -1.0)] {
                cv.R(dx - 34, GY - 156, 68, 156, Col(0x060807))
                cv.vfill(dx - 32, GY - 154, 64, 154, [(0, rgba(125, 255, 176, 0.05)), (1, rgba(125, 255, 176, 0.25))])
                cv.RRStroke(dx - 34, GY - 156, 68, 156, 2, 4, MINT.alpha(0.55 + 0.45 * pl))
                sign(cv, sd > 0 ? "OFFICES ▶" : "◀ OFFICES", dx, GY - 176, MINT, t, arrow: false)
                for i in 0..<3 {
                    let ax = dx + sd * (-90 + Double(i) * 18 + (t * 30).truncatingRemainder(dividingBy: 18))
                    cv.poly(MINT.alpha(pl), [ax, GY - 14, ax + sd * 9, GY - 8, ax, GY - 2])
                }
            }
        }
        for it in f.items where !it.used { item(cv, it, t) }
    }
    private func prop(_ cv: Canvas, _ p: Prop, _ z: Zone) {
        let x = p.x
        switch p.kind {
        case 0:   // desk
            cv.R(x - 44, GY - 50, 88, 8, Col(0x6a5238)); cv.R(x - 40, GY - 42, 6, 42, Col(0x4a3a28)); cv.R(x + 34, GY - 42, 6, 42, Col(0x4a3a28))
            cv.R(x - 16, GY - 78, 34, 24, Col(0x15171c)); cv.R(x - 13, GY - 75, 28, 18, Col(0x2c5a7a))
        case 1:   // plant
            cv.poly(Col(0x7a5236), [x - 14, GY - 30, x + 14, GY - 30, x + 10, GY, x - 10, GY])
            for i in 0..<5 { let a = -1.2 + Double(i) * 0.6; cv.seg(x, GY - 30, x + sin(a) * 34, GY - 30 - cos(a) * 44, 7, Col(0x2f6a3a)) }
        case 2:   // water cooler
            cv.R(x - 14, GY - 70, 28, 70, Col(0xd9dcd6)); cv.RR(x - 12, GY - 108, 24, 40, 8, rgba(120, 190, 230, 0.75))
        case 3:   // cabinet
            cv.R(x - 30, GY - 96, 60, 96, Col.mix(z.trim, BLACK, 0.35)); cv.R(x - 26, GY - 90, 52, 26, Col.mix(z.trim, BLACK, 0.5)); cv.R(x - 26, GY - 58, 52, 26, Col.mix(z.trim, BLACK, 0.5)); cv.R(x - 26, GY - 28, 52, 24, Col.mix(z.trim, BLACK, 0.5))
        default:  // lamp
            cv.R(x - 2, GY - 120, 4, 120, Col(0x2a2a2a)); cv.poly(Col(0xd9c48a), [x - 22, GY - 120, x + 22, GY - 120, x + 14, GY - 150, x - 14, GY - 150])
            cv.lighter(true); cv.glow(x, GY - 110, 90, rgba(255, 230, 160, 0.14)); cv.lighter(false)
        }
    }
    private func item(_ cv: Canvas, _ it: Item, _ t: Double) {
        let x = it.x
        switch it.kind {
        case 0:
            cv.RR(x - 15, GY - 22, 30, 22, 4, Col(0xf2f2ee)); cv.R(x - 3, GY - 18, 6, 14, HOT); cv.R(x - 8, GY - 14, 16, 6, HOT)
        case 1:
            cv.RR(x - 17, GY - 50, 34, 50, 5, Col(0xb8322c)); cv.R(x - 17, GY - 38, 34, 5, Col(0x7a1c18)); cv.R(x - 17, GY - 18, 34, 5, Col(0x7a1c18))
            cv.poly(GOLD, [x, GY - 34, x - 7, GY - 22, x + 7, GY - 22]); cv.text("!", x, GY - 23, 9, BLACK, 1, 3)
        case 2:
            let b = sin(t * 4) * 6
            cv.lighter(true); cv.glow(x, GY - 50 + b, 70, rgba(125, 255, 176, 0.5)); cv.lighter(false)
            cv.RR(x - 7, GY - 70 + b, 14, 40, 6, rgba(200, 255, 220, 0.9)); cv.RR(x - 5, GY - 54 + b, 10, 22, 4, Col(0x2fd67a)); cv.R(x - 8, GY - 74 + b, 16, 6, Col(0x444a52))
            cv.text("SAMPLE", x, GY - 92 + b, 13, MINT, 1, 3)
        default:
            cv.R(x - 60, GY - 96, 120, 14, Col(0x5a6068)); cv.R(x - 8, GY - 96, 16, 96, Col(0x4a5058))
            cv.lighter(true); cv.glow(x, GY - 90, 90, rgba(255, 90, 70, 0.35 + 0.15 * sin(t * 6))); cv.lighter(false)
            cv.ring(x, GY - 90, 24, 7, HOT)
            for i in 0..<4 { let a = t * 1.5 + Double(i) * PI / 2; cv.seg(x, GY - 90, x + cos(a) * 24, GY - 90 + sin(a) * 24, 5, HOT) }
            cv.text("WATER MAIN", x, GY - 130, 13, HOT, 1, 3)
        }
    }

    private func scene(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let h = g.hero
        let f = g.floor
        let t = g.t
        let target = clampD(h.x - W / 2 + h.face * 70, -40, FLOOR_W - W + 40)
        if camFloor != f.n || abs(target - camX) > 700 { camX = target; camFloor = f.n } else { camX += (target - camX) * 0.14 }
        cv.save()
        if g.shake > 0 { cv.translate(rnd(-1, 1) * g.shake, rnd(-1, 1) * g.shake * 0.6) }
        cv.translate(-camX, 0)
        drawFloor(g, cv, camX - 30, W + 60)
        let gy = GY + 6
        // the dead first, then the living
        for z in f.zeds where !z.alive { drawZed(cv, z, gy, t) }
        for z in f.zeds where z.alive { drawZed(cv, z, gy, t) }
        // the hero
        if g.mode != .dead {
            let blink = h.inv > 0 && g.supT < 0 && Int(t * 20) % 2 == 0
            cv.ell(h.x, gy + 2, 30, 6, BLACK.alpha(0.35))
            if g.supT >= 0 { cv.lighter(true); cv.glow(h.x, gy - 90, 150, g.tw.hue.alpha(0.5)); cv.lighter(false) }
            let hf: Double = h.hurtT > 0 ? 0.6 : 0
            let ha: Double = blink ? 0.45 : 1
            figure(cv, h.x, gy, h.face, 1, heroLook(g.tw), heroPose(g), flash: hf, alpha: ha)
        } else {
            figure(cv, h.x, gy, h.face, 1, heroLook(g.tw), Pose(), fall: min(1, g.deadT * 3))
        }
        if g.lv("drone") > 0 {
            let dx = h.x + cos(g.droneA) * 70, dy = gy - 190 + sin(g.droneA * 2) * 8
            cv.RR(dx - 14, dy - 5, 28, 10, 4, Col(0x3a4250)); cv.R(dx - 22, dy - 8, 44, 2.5, Col(0xc9d2dc, 0.7)); cv.circ(dx, dy + 5, 3, Col(0x7dd3ff))
        }
        effects(g, cv, gy)
        cv.restore()
    }
    private func drawZed(_ cv: Canvas, _ z: Zed, _ gy: Double, _ t: Double) {
        if z.kind == .dog || z.kind == .rat {
            if z.alive { cv.ell(z.x, gy + 2, z.kind == .rat ? 14 : 40, z.kind == .rat ? 3 : 6, BLACK.alpha(0.35)) }
            beast(cv, z, gy, t)
        } else {
            let a = z.alive ? 1.0 : max(0.15, 1 - z.deadT / 6)
            if z.alive { cv.ell(z.x, gy + 2, 30 * z.scale, 6, BLACK.alpha(0.35)) }
            if z.kind == .boss && z.alive { cv.lighter(true); cv.glow(z.x, gy - 140, 190, rgba(90, 255, 150, 0.22)); cv.lighter(false) }
            let fall: Double = z.alive ? 0 : min(1, z.deadT * 3.2)
            figure(cv, z.x, gy, z.face, z.scale, zedLook(z), zedPose(z, t), flash: z.flash, fall: fall, alpha: a)
            if z.burn > 0 && z.alive { cv.lighter(true); cv.glow(z.x, gy - 80 * z.scale, 70 * z.scale, rgba(255, 140, 40, 0.5)); cv.lighter(false) }
        }
        if z.alive && z.hp < z.maxHp && z.kind != .rat {
            let top = z.kind == .dog ? gy - 96 : gy - 178 * z.scale
            let w = z.kind == .boss ? 120.0 : 36.0
            cv.R(z.x - w / 2, top, w, 5, BLACK.alpha(0.6))
            cv.R(z.x - w / 2, top, w * clampD(z.hp / z.maxHp, 0, 1), 5, z.kind == .boss ? MINT : HOT)
        }
    }
    private func effects(_ g: Game, _ cv: Canvas, _ gy: Double) {
        for s in g.slashes {
            let u = s.t / 0.18
            cv.save()
            cv.translate(s.x, gy + s.y)
            cv.scale(s.face, 1)
            cv.lighter(true)
            cv.arcStroke(10, 0, 96 * s.big, -1.25, 0.85, 16 * (1 - u) + 2, s.col.alpha(0.85 * (1 - u)))
            cv.arcStroke(10, 0, 96 * s.big, -1.0, 0.6, 5 * (1 - u) + 1, WHITE.alpha(1 - u))
            cv.lighter(false)
            cv.restore()
        }
        for w in g.waves {
            cv.poly(rgba(230, 220, 200, 0.75), [w.x - 30, gy, w.x - w.dir * 10, gy - 150, w.x + w.dir * 26, gy - 60, w.x + w.dir * 44, gy])
            cv.lighter(true); cv.glow(w.x, gy - 40, 110, g.tw.hue.alpha(0.5)); cv.lighter(false)
        }
        for p in g.parts {
            let a = 1 - p.t / p.life
            if p.glow {
                cv.lighter(true); cv.circ(p.x, gy + p.y, p.size * (0.5 + a * 0.7), p.col.alpha(a * 0.8)); cv.lighter(false)
            } else {
                cv.R(p.x - p.size / 2, gy + p.y - p.size / 2, p.size, p.size, p.col.alpha(min(1, a * 1.6)))
            }
        }
        for tr in g.tracers {
            let a = 1 - tr.t / tr.life
            if tr.bolt {
                var pts: [Double] = [tr.x0, gy + tr.y0]
                for i in 1..<6 {
                    let u = Double(i) / 6
                    pts.append(lerp(tr.x0, tr.x1, u) + rnd(-14, 14)); pts.append(gy + lerp(tr.y0, tr.y1, u) + rnd(-14, 14))
                }
                pts.append(tr.x1); pts.append(gy + tr.y1)
                cv.lighter(true)
                cv.line(tr.col.alpha(a * 0.6), tr.w * 3, pts)
                cv.line(WHITE.alpha(a), tr.w, pts)
                cv.lighter(false)
            } else {
                cv.seg(tr.x0, gy + tr.y0, tr.x1, gy + tr.y1, tr.w, tr.col.alpha(a))
            }
        }
        for n in g.nades {
            let u = n.t / n.dur
            let x = lerp(n.x0, n.x1, u), y = gy - 90 - sin(u * PI) * 150 + u * 80
            cv.circ(x, y, 7, Col(0x2f3a2a)); cv.circ(x + 3, y - 6, 2.5, HOT)
        }
        for b in g.beams {
            if !b.done {
                let u = b.t / 0.55
                cv.ellStroke(b.x, gy + 4, b.r * (1.2 - 0.3 * u), 14, 3, rgba(160, 220, 255, 0.5 + 0.5 * u))
                cv.seg(b.x, gy - 500, b.x, gy, 2, rgba(160, 220, 255, 0.5))
            } else {
                let u = (b.t - 0.55) / 0.45
                cv.lighter(true)
                cv.R(b.x - 60 * (1 - u), gy - 560, 120 * (1 - u), 564, rgba(170, 225, 255, 0.8 * (1 - u)))
                cv.R(b.x - 22 * (1 - u), gy - 560, 44 * (1 - u), 564, WHITE.alpha(1 - u))
                cv.lighter(false)
            }
        }
        for b in g.booms {
            let u = b.t / b.life
            let r = b.r * (0.25 + 0.75 * easeOut(u))
            cv.lighter(true)
            cv.glow(b.x, gy + b.y, r * 1.3, rgba(255, 190, 70, 0.9 * (1 - u)))
            cv.circ(b.x, gy + b.y, r * 0.45 * (1 - u), rgba(255, 255, 230, 1 - u))
            cv.lighter(false)
            cv.circ(b.x, gy + b.y - r * 0.5 * u, r * (0.3 + 0.3 * u), rgba(30, 26, 26, 0.5 * u * (1 - u) * 4))
        }
        for r in g.rings {
            let u = r.t / r.life
            cv.ellStroke(r.x, gy + r.y + 70, r.r * easeOut(u), r.r * easeOut(u) * 0.28, 10 * (1 - u) + 1, r.col.alpha(1 - u))
        }
        for fl in g.floaters {
            cv.text(fl.text, fl.x, gy + fl.y, fl.size, fl.col.alpha(1 - fl.t / 0.8), 1, 3)
        }
    }

    // ---------- the play screen furniture
    private func bar(_ cv: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ k: Double, _ c: Col) {
        cv.RR(x, y, w, h, h / 2, BLACK.alpha(0.6))
        if k > 0.01 { cv.RR(x + 2, y + 2, max(h - 4, (w - 4) * clampD(k, 0, 1)), h - 4, (h - 4) / 2, c) }
    }
    private func hud(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let t = g.t
        let f = g.floor
        let x = 16 + g.safeL
        cv.RR(x - 8, 8, 250, 100, 12, BLACK.alpha(0.5))
        let label = f.kind == .roof ? "ROOF" : (f.kind == .street ? "STREET" : "FLOOR \(f.n)")
        let place: String = f.kind == .roof || f.kind == .street ? g.tw.building : "\(g.tw.building) · \(g.zone(f.n).name)"
        cv.text("\(g.tw.who) · \(place)", x, 24, 10, WHITE.alpha(0.65), 0, 1)
        cv.text(label, x, 52, 27, g.tw.hue, 0, 3)
        let hpCol: Col = g.hero.hp < g.hero.maxHp * 0.3 ? HOT : Col(0x7fd67a)
        bar(cv, x, 60, 234, 16, g.hero.hp / g.hero.maxHp, hpCol)
        bar(cv, x, 82, 234, 12, g.meter / 100, g.meter >= 100 ? GOLD : Col(0xb89a50))
        // what you carry
        var ix = x
        for u in UPS where g.lv(u.id) > 0 {
            cv.RR(ix - 2, 114, 30, 30, 8, BLACK.alpha(0.5))
            cv.text(u.icon, ix + 13, 136, 17, WHITE, 1, 1)
            for l in 0..<g.lv(u.id) { cv.R(ix + 2 + Double(l) * 9, 146, 7, 3, u.sup ? Col(0xff8ad8) : GOLD) }
            ix += 34
        }
        // one goal
        let s = g.goal
        let gw = cv.textW(s, 13, 2) + 44
        let gx = W - g.safeR - 12 - gw
        cv.RR(gx, 10, gw, 26, 13, BLACK.alpha(0.55))
        cv.poly(GOLD, [gx + 12, 16, gx + 22, 23, gx + 12, 30])
        cv.text(s, gx + 30, 28, 13, WHITE, 0, 2)
        if g.hits >= 3 {
            cv.stamp("\(g.hits)", W - g.safeR - 74, 78, 34, WHITE, 2)
            cv.text("HITS", W - g.safeR - 20, 76, 14, WHITE.alpha(0.9), 2, 3)
        }
        // pause
        let pr = g.pauseRect
        cv.RR(pr.x, pr.y, pr.w, pr.h, 9, BLACK.alpha(0.45))
        cv.R(pr.x + 16, pr.y + 9, 5, 14, WHITE.alpha(0.85)); cv.R(pr.x + 27, pr.y + 9, 5, 14, WHITE.alpha(0.85))
        // message
        if g.msgT > 0 {
            let a = min(1, g.msgT * 2)
            let mw = min(W - 120, cv.textW(g.msg, 17, 2) + 44)
            cv.RR(W / 2 - mw / 2, 52, mw, 34, 10, BLACK.alpha(0.62 * a))
            cv.text(g.msg, W / 2, 75, 17, GOLD.alpha(a), 1, 2)
        }
        if g.nameT > 0 {
            let k = min(1, (1.5 - g.nameT) / 0.2)
            cv.save()
            cv.translate(W / 2, 150)
            cv.rotate(-0.04)
            cv.scale(1 + (1 - k) * 1.5, 1 + (1 - k) * 1.5)
            cv.alpha(min(1, g.nameT * 3))
            cv.stamp(g.supName, 0, 0, 44, g.tw.hue, 1)
            cv.restore()
        }
        // buttons
        let ab = g.atkBtn
        cv.circ(ab.0, ab.1, ab.2, BLACK.alpha(0.35))
        cv.ring(ab.0, ab.1, ab.2, 4, WHITE.alpha(g.input.attack ? 0.95 : 0.5))
        cv.save()
        cv.translate(ab.0, ab.1)
        cv.rotate(-0.7)
        cv.RR(-6, -34, 12, 60, 5, WHITE.alpha(0.85)); cv.RR(-4, 22, 8, 16, 3, WHITE.alpha(0.6))
        cv.restore()
        let pb = g.powBtn
        let ready = g.meter >= 100
        if ready { cv.lighter(true); cv.glow(pb.0, pb.1, pb.2 * 2.1, GOLD.alpha(0.3 + 0.15 * sin(t * 6))); cv.lighter(false) }
        cv.circ(pb.0, pb.1, pb.2, BLACK.alpha(0.4))
        cv.ring(pb.0, pb.1, pb.2, 4, WHITE.alpha(0.25))
        cv.arcStroke(pb.0, pb.1, pb.2, -PI / 2, -PI / 2 + 2 * PI * clampD(g.meter / 100, 0.001, 1), 5, GOLD)
        let bc = ready ? GOLD : WHITE.alpha(0.4)
        cv.poly(bc, [pb.0 + 6, pb.1 - 26, pb.0 - 14, pb.1 + 4, pb.0 - 2, pb.1 + 4, pb.0 - 8, pb.1 + 26, pb.0 + 14, pb.1 - 6, pb.0 + 2, pb.1 - 6])
        // stick hint
        if g.playT < 6 {
            let a = clampD(6 - g.playT, 0, 1) * 0.7
            cv.text("◀  DRAG TO RUN  ▶", 150 + g.safeL, VIEW_H - 60, 15, WHITE.alpha(a), 1, 2)
        }
    }
    private func deadCard(_ g: Game, _ cv: Canvas) {
        let a = min(1, g.deadT * 2)
        cv.R(0, 0, g.W, VIEW_H, rgba(60, 0, 0, 0.55 * a))
        cv.stamp("DOWN.", g.W / 2, 260, 96, HOT.alpha(a), 1)
        cv.text("Getting back up", g.W / 2, 310, 18, WHITE.alpha(a * 0.8), 1, 1)
    }
    private func card(_ g: Game, _ cv: Canvas) {
        let k = min(1, g.cardT / 0.25)
        cv.R(0, 0, g.W, VIEW_H, BLACK.alpha(0.5))
        cv.save()
        cv.translate(g.W / 2, 250)
        cv.rotate(-0.04)
        cv.scale(1 + (1 - k) * 2, 1 + (1 - k) * 2)
        cv.alpha(k)
        cv.stamp(g.tw.who, 0, 0, 150, g.tw.hue, 1)
        cv.stamp("\(g.tw.top) FLOORS TO THE STREET", 0, 62, 40, WHITE, 1)
        cv.restore()
        cv.text(g.tw.building, g.W / 2, 400, 16, WHITE.alpha(0.7), 1, 2)
    }
    private func pick(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let k = min(1, g.pickT * 4)
        cv.R(0, 0, W, VIEW_H, BLACK.alpha(0.76 * k))
        cv.text("PICK ONE", W / 2, 72, 36, GOLD, 1, 3)
        cv.text("One every six floors. They stack.", W / 2, 100, 14, WHITE.alpha(0.75), 1, 1)
        for i in 0..<g.pickOpts.count {
            let u = UPS[g.pickOpts[i]]
            let r = g.pickRect(i)
            let y = r.y + (1 - k) * 30
            let edge = u.sup ? Col(0xff6ac8) : Col(0x7db8ff)
            cv.RR(r.x, y, r.w, r.h, 16, u.sup ? Col(0x2a1638) : Col(0x18202c))
            cv.RRStroke(r.x, y, r.w, r.h, 16, 3, edge)
            if u.sup { cv.text("★ SUPER WEAPON ★", r.x + r.w / 2, y + 28, 12, Col(0xffb0e8), 1, 3) }
            cv.text(u.icon, r.x + r.w / 2, y + 112, 64, WHITE, 1, 1)
            cv.text(u.name, r.x + r.w / 2, y + 160, 24, u.sup ? Col(0xffb0e8) : Col(0xa8d0ff), 1, 3)
            let l = g.lv(u.id)
            cv.text(l == 0 ? "NEW" : "LEVEL \(l + 1)", r.x + r.w / 2, y + 184, 13, GOLD, 1, 3)
            for p in 0..<3 { cv.RR(r.x + r.w / 2 - 34 + Double(p) * 24, y + 194, 20, 5, 2, p <= l ? GOLD : WHITE.alpha(0.2)) }
            wrap(cv, u.desc, r.x + r.w / 2, y + 232, 16, r.w - 44, WHITE.alpha(0.9))
            cv.RR(r.x + 30, y + r.h - 62, r.w - 60, 40, 10, WHITE.alpha(0.12))
            cv.text("TAKE", r.x + r.w / 2, y + r.h - 36, 16, WHITE, 1, 3)
        }
    }
    private func wrap(_ cv: Canvas, _ s: String, _ cx: Double, _ y: Double, _ size: Double, _ maxW: Double, _ c: Col) {
        var line = ""
        var yy = y
        for word in s.split(separator: " ") {
            let trial: String = line.isEmpty ? String(word) : line + " " + String(word)
            if cv.textW(trial, size, 1) > maxW && !line.isEmpty {
                cv.text(line, cx, yy, size, c, 1, 1)
                yy += size * 1.35
                line = String(word)
            } else { line = trial }
        }
        if !line.isEmpty { cv.text(line, cx, yy, size, c, 1, 1) }
    }
    private func pauseCard(_ g: Game, _ cv: Canvas) {
        cv.R(0, 0, g.W, VIEW_H, BLACK.alpha(0.72))
        cv.text("PAUSED", g.W / 2, 150, 44, GOLD, 1, 3)
        let r = g.resumeRect
        cv.RR(r.x, r.y, r.w, r.h, 14, GOLD)
        cv.text("RESUME", g.W / 2, r.y + 42, 26, BLACK, 1, 3)
        let q = g.quitRect
        cv.RR(q.x, q.y, q.w, q.h, 14, WHITE.alpha(0.14))
        cv.text("QUIT TO TITLE", g.W / 2, q.y + 34, 18, WHITE, 1, 2)
        cv.text("Your floor is saved.", g.W / 2, q.y + 86, 13, WHITE.alpha(0.6), 1, 1)
    }

    private func ride(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let u = clampD(g.rideT / g.rideDur, 0, 1)
        cv.R(0, 0, W, VIEW_H, Col(0x050608))
        let hue = g.tw.hue
        switch g.rideKind {
        case .stairs:
            for i in 0..<9 {
                let y = (Double(i) * 70 + u * 280).truncatingRemainder(dividingBy: 630) - 40
                cv.poly(Col(0x1a1c22), [W / 2 - 220, y, W / 2 + 220, y + 60, W / 2 + 220, y + 78, W / 2 - 220, y + 18])
            }
            cv.stamp("FLOOR \(max(0, g.rideTo))", W / 2, 286, 64, hue, 1)
        case .hole:
            for i in 0..<26 {
                let fi = Double(i)
                let x = hashN(fi) * W
                let y = (hashN(fi + 9) * 700 - u * 1400).truncatingRemainder(dividingBy: 700)
                cv.R(x, y < 0 ? y + 700 : y, 3, 60 + hashN(fi + 3) * 80, WHITE.alpha(0.25))
            }
            figure(cv, W / 2, 250 + u * 120, 1, 1.1, heroLook(g.tw), fallPose(g.t))
            cv.stamp("DROP!", W / 2, 440, 54, hue, 1)
        case .lift:
            let open = u < 0.2 ? 1 - u / 0.2 : (u > 0.85 ? (u - 0.85) / 0.15 : 0)
            cv.R(W / 2 - 180, 60, 360, 420, Col(0x15171c))
            cv.R(W / 2 - 170, 70, 170 * (1 - open), 400, Col(0x8a929c))
            cv.R(W / 2 + 170 * open, 70, 170 * (1 - open), 400, Col(0x7c848e))
            let n = Int(lerp(Double(g.rideFrom), Double(g.rideTo), easeIO(u)).rounded())
            cv.RR(W / 2 - 60, 12, 120, 44, 8, Col(0x0a0a0c))
            cv.text("\(n)", W / 2, 46, 32, MINT, 1, 3)
            cv.poly(MINT, [W / 2 + 76, 26, W / 2 + 96, 26, W / 2 + 86, 42])
        }
        if u < 0.15 { cv.R(0, 0, W, VIEW_H, BLACK.alpha(1 - u / 0.15)) }
    }
    private func fallPose(_ t: Double) -> Pose {
        var p = Pose()
        p.armF = 2.6 + sin(t * 18) * 0.3; p.armB = -2.4 + sin(t * 16) * 0.3
        p.hipF = 0.7; p.kneeF = 0.9; p.hipB = -0.5; p.kneeB = 0.7
        p.wpn = 0.2
        return p
    }

    // ---------- title
    private func title(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let t = g.t
        night(cv, 0, W, VIEW_H, t)
        cv.circ(W * 0.8, 96, 34, Col(0xf2ead2)); cv.circ(W * 0.8 - 10, 90, 7, Col(0xd9d0b8))
        skyline(cv, 0, W, VIEW_H - 30, t * 6)
        // the tower
        let tx = W / 2 - 90
        cv.R(tx, 40, 180, VIEW_H, Col(0x11141f))
        cv.R(tx + 60, 10, 60, 30, Col(0x161a28)); cv.R(tx + 88, -20, 4, 30, Col(0x2a3042))
        for r in 0..<32 { for c in 0..<8 {
            let h = hashN(Double(r * 13 + c * 7))
            let wx = tx + 10 + Double(c) * 21, wy = 52 + Double(r) * 15.5
            if h > 0.9 { cv.R(wx, wy, 14, 9, rgba(255, 130, 40, 0.7 + 0.3 * sin(t * 8 + h * 30))) } else if h > 0.45 { cv.R(wx, wy, 14, 9, rgba(255, 226, 170, 0.5)) } else { cv.R(wx, wy, 14, 9, Col(0x07080c)) }
        } }
        cv.lighter(true)
        cv.glow(W / 2, VIEW_H, 520, rgba(255, 90, 30, 0.3))
        for i in 0..<40 {
            let fi = Double(i)
            let u = (t * 0.22 + hashN(fi)).truncatingRemainder(dividingBy: 1)
            cv.circ(hashN(fi + 20) * W + sin(t + fi) * 20, VIEW_H - u * 560, 2.2, rgba(255, 180 - u * 100, 60, 1 - u))
        }
        cv.lighter(false)
        // the three, and what is coming
        let gy = VIEW_H - 22.0
        cv.R(0, gy, W, 30, Col(0x08090c))
        for i in 0..<3 {
            var p = Pose()
            p.bob = sin(t * 2.4 + Double(i)) * 1.5
            p.armF = 0.2; p.elbF = 1.4; p.wpn = 1.2; p.hipF = 0.25; p.hipB = -0.25
            figure(cv, 120 + g.safeL + Double(i) * 78, gy, 1, 1.05, heroLook(TOWERS[i]), p)
        }
        for i in 0..<5 {
            let z = Zed(id: 0, kind: i == 2 ? .runner : .zed, x: 0, depth: 0, seed: hashN(Double(i) + 2))
            z.walk = t * 60 + Double(i) * 40
            figure(cv, W - g.safeR - 90 - Double(i) * 62 - sin(t * 0.6) * 10, gy, -1, 1.0, zedLook(z), zedPose(z, t))
        }
        // the name
        cv.save()
        cv.translate(W / 2, 190)
        cv.rotate(-0.05)
        cv.stamp("FLOOR", -8, -40, 110, WHITE, 1)
        cv.stamp("ZERO", 8, 62, 130, GOLD, 1)
        cv.restore()
        cv.text("GET DOWN. ALL THREE OF YOU.", W / 2, 330, 16, WHITE.alpha(0.85), 1, 3)
        // play
        let r = g.playRect
        cv.save()
        cv.translate(r.x + r.w / 2, r.y + r.h / 2)
        cv.rotate(-0.03)
        let pulse = 1 + 0.03 * sin(t * 4)
        cv.scale(pulse, pulse)
        cv.RR(-r.w / 2, -r.h / 2, r.w, r.h, 8, GOLD)
        cv.save()
        cv.clipRect(-r.w / 2, -r.h / 2, r.w, 12)
        for i in -2..<16 { let sx = -r.w / 2 + Double(i) * 28 + (t * 20).truncatingRemainder(dividingBy: 28); cv.poly(BLACK, [sx, -r.h / 2, sx + 14, -r.h / 2, sx + 2, -r.h / 2 + 12, sx - 12, -r.h / 2 + 12]) }
        cv.restore()
        cv.save()
        cv.clipRect(-r.w / 2, r.h / 2 - 12, r.w, 12)
        for i in -2..<16 { let sx = -r.w / 2 + Double(i) * 28 - (t * 20).truncatingRemainder(dividingBy: 28); cv.poly(BLACK, [sx, r.h / 2 - 12, sx + 14, r.h / 2 - 12, sx + 2, r.h / 2, sx - 12, r.h / 2]) }
        cv.restore()
        cv.text(g.hasSave ? "NEW GAME" : "PLAY", 0, 15, 40, BLACK, 1, 3)
        cv.restore()
        if g.hasSave {
            let c = g.contRect
            let d = UserDefaults.standard
            let tw = TOWERS[max(0, min(2, d.integer(forKey: "fz.tower")))]
            cv.RR(c.x, c.y, c.w, c.h, 10, BLACK.alpha(0.6))
            cv.RRStroke(c.x, c.y, c.w, c.h, 10, 2, MINT)
            cv.text("CONTINUE · \(tw.who) · FLOOR \(d.integer(forKey: "fz.floor"))", W / 2, c.y + 26, 15, MINT, 1, 3)
        }
    }

    // ---------- the opening: five quick shots
    private func stampIn(_ cv: Canvas, _ s: String, _ t: Double, _ col: Col, _ g: Game) {
        let k = min(1, t / 0.25)
        let sc = 1 + (1 - k) * (1 - k) * 2.2
        cv.save()
        cv.translate(40 + g.safeL, 96)
        cv.rotate(-0.045)
        cv.scale(sc, sc)
        cv.alpha(k)
        cv.stamp(s, 0, 0, 58, col, 0)
        cv.R(0, 12, cv.textW(s, 58, 3), 6, col)
        cv.restore()
    }
    private func intro(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let shot = min(4, Int(g.introT / 1.8))
        let t = g.introT - Double(shot) * 1.8
        let T = g.t
        let gy = 452.0
        let confetti: [Col] = [Col(0xff6b8a), GOLD, Col(0x7dd3ff), Col(0x8fe08a)]
        cv.save()
        switch shot {
        case 0:
            night(cv, 0, W, 400, T); skyline(cv, 0, W, 380, 0)
            cv.R(0, gy, W, VIEW_H - gy, Col(0x1a1420))
            var rx = 0.0
            while rx < W { cv.R(rx, gy - 92, 1.6, 92, Col(0x3a4050)); rx += 14 }
            cv.R(0, gy - 94, W, 4, Col(0x3a4050))
            cv.R(W - 360, gy - 92, 300, 92, Col(0x3b2420)); cv.R(W - 366, gy - 97, 312, 6, Col(0xc9a24a))
            for i in 0..<28 {
                let u = Double(i) / 27
                let lx = 40 + (W - 80) * u, ly = 150 + 200 * u * (1 - u)
                cv.lighter(true); cv.glow(lx, ly, 26, rgba(255, 230, 160, 0.3)); cv.lighter(false)
                cv.circ(lx, ly, 2.8, Col(0xffe6a0))
            }
            for i in 0..<3 {
                var p = Pose()
                p.bob = abs(sin(T * 3.6 + Double(i))) * 5
                p.armF = 2.6 + sin(T * 3.6 + Double(i)) * 0.3; p.elbF = 0.2; p.hipF = 0.2; p.hipB = -0.2
                var l = heroLook(TOWERS[i]); l.weapon = 0
                figure(cv, W * 0.3 + Double(i) * 84, gy, i == 0 ? 1 : -1, 0.95, l, p)
            }
            for i in 0..<40 {
                let fi = Double(i)
                let u = (T * 0.3 + hashN(fi)).truncatingRemainder(dividingBy: 1)
                let cc: Col = confetti[i % 4]
                cv.R(hashN(fi + 50) * W + sin(T * 2 + fi) * 20, u * 470, 6, 3, cc)
            }
            stampIn(cv, "SUNDAY. A PARTY.", t, GOLD, g)
        case 1:
            cv.vfill(0, 0, W, VIEW_H, [(0, Col(0x04100c)), (1, Col(0x0c2a1c))])
            cv.R(W * 0.55, 260, 260, 220, Col(0x1c2a26)); cv.ell(W * 0.55 + 130, 260, 130, 30, Col(0x16221e))
            for i in 0..<3 {
                let u = (T * 0.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                cv.ellStroke(W * 0.55 + 130, 262, 40 + u * 240, 10 + u * 54, 4 * (1 - u) + 1, rgba(90, 255, 150, 0.8 * (1 - u)))
            }
            cv.lighter(true); cv.glow(W * 0.55 + 130, 260, 260, rgba(60, 255, 140, 0.35)); cv.lighter(false)
            var p = Pose()
            p.armF = 1.2; p.elbF = 0.3; p.lean = 0.2
            var l = Look(shirt: Col(0xd9dcd6), pants: Col(0x2a2f3c), skin: Col(0xc9a384), hair: Col(0x9a9a92), eye: Col(0x15151a)); l.coat = true
            figure(cv, W * 0.55 + 10, 250, 1, 1.0, l, p)
            for i in 0..<5 { let u = (T * 1.4 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1); cv.circ(W * 0.55 + 66 + u * 30, 190 + u * 70, 4, MINT.alpha(1 - u)) }
            cv.vfill(0, VIEW_H - 200, W, 200, [(0, rgba(40, 220, 110, 0)), (1, rgba(40, 220, 110, 0.3 * min(1, t / 1.2)))])
            stampIn(cv, "POISONED WATER.", t, MINT, g)
        case 2:
            let bt = t.truncatingRemainder(dividingBy: 0.9)
            if bt < 0.3 { cv.translate(rnd(-8, 8) * (1 - bt / 0.3), rnd(-6, 6) * (1 - bt / 0.3)) }
            night(cv, 0, W, 400, T)
            var bx = -30.0
            var bi = 0
            while bx < W {
                let h = 250 + hashN(Double(bi) * 5.3) * 90
                let face: Col = bi % 2 == 0 ? Col(0x17141c) : Col(0x1c1820)
                cv.R(bx, gy - h, 160, h, face)
                for r in 0..<3 { for c in 0..<3 {
                    let burn = (bi * 3 + r * 5 + c) % 5 == 0
                    cv.R(bx + 16 + Double(c) * 48, gy - h + 22 + Double(r) * 62, 34, 42, burn ? rgba(255, 140, 40, 0.8) : Col(0x07080c))
                } }
                bx += 172
                bi += 1
            }
            cv.lighter(true); cv.glow(W / 2, gy, 700, rgba(255, 90, 30, 0.35)); cv.lighter(false)
            cv.R(0, gy, W, VIEW_H - gy, Col(0x17181c))
            for i in 0..<11 {
                let z = Zed(id: 0, kind: i % 4 == 1 ? .runner : .zed, x: 0, depth: 0, seed: hashN(Double(i) * 3 + 1))
                z.look = i
                z.walk = T * 160 + Double(i) * 30
                let zx = ((g.introT - 3.6) * 190 + Double(i) * 74).truncatingRemainder(dividingBy: W + 200) - 100
                figure(cv, zx, gy, 1, 1.02, zedLook(z), zedPose(z, T))
            }
            if bt < 0.6 {
                let u = bt / 0.6
                let ex = W * (0.35 + 0.3 * hashN((t / 0.9).rounded(.down)))
                cv.lighter(true)
                cv.glow(ex, gy - 40, 230 * (0.3 + 0.7 * easeOut(u)), rgba(255, 190, 70, 0.95 * (1 - u)))
                cv.lighter(false)
            }
            stampIn(cv, "EVERYONE TURNED.", t, HOT, g)
        case 3:
            cv.R(0, 0, W, VIEW_H, Col(0x05060a))
            let pw = W / 3
            for i in 0..<3 {
                let k = easeIO(clampD((t - Double(i) * 0.12) / 0.3, 0, 1))
                let off = (1 - k) * (i % 2 == 0 ? -VIEW_H : VIEW_H)
                let tw = TOWERS[i]
                let x0 = Double(i) * pw
                cv.save()
                cv.translate(0, off)
                cv.clipRect(x0 + 3, 0, pw - 6, VIEW_H)
                cv.vfill(x0, 0, pw, VIEW_H, [(0, Col(0x0a0c16)), (1, Col.mix(tw.hue, BLACK, 0.75))])
                cv.R(x0 + pw / 2 - 70, 150, 140, 400, Col(0x11141f))
                for r in 0..<20 { for c in 0..<5 { if hashN(Double(r * 7 + c * 3 + i * 11)) > 0.5 { cv.R(x0 + pw / 2 - 58 + Double(c) * 24, 162 + Double(r) * 15, 14, 8, rgba(255, 226, 170, 0.45)) } } }
                var p = Pose()
                p.armF = 0.2; p.elbF = 1.4; p.wpn = 1.2; p.hipF = 0.3; p.hipB = -0.3; p.bob = sin(T * 3 + Double(i)) * 2
                figure(cv, x0 + pw / 2 - 6, gy, 1, 1.3, heroLook(tw), p)
                cv.stamp(tw.who, x0 + pw / 2, 96, 54, tw.hue, 1)
                cv.text("\(tw.top) FLOORS", x0 + pw / 2, 126, 20, WHITE, 1, 3)
                cv.restore()
            }
            if t > 0.6 {
                let k = min(1, (t - 0.6) / 0.25)
                cv.save()
                cv.translate(W / 2, VIEW_H - 40)
                cv.rotate(-0.03)
                cv.scale(1 + (1 - k) * 1.5, 1 + (1 - k) * 1.5)
                cv.alpha(k)
                cv.stamp("MEET AT THE BOTTOM.", 0, 0, 44, WHITE, 1)
                cv.restore()
            }
        default:
            let hit = t > 1.0
            if hit && t < 1.25 { cv.translate(rnd(-12, 12), rnd(-8, 8)) }
            night(cv, 0, W, 400, T); skyline(cv, 0, W, 390, 0)
            cv.R(0, gy, W, VIEW_H - gy, Col(0x1b1d24))
            let dx = W * 0.72
            cv.R(dx - 40, gy - 250, 300, 250, Col(0x22262f)); cv.R(dx, gy - 190, 110, 190, Col(0x060608))
            cv.lighter(true); cv.glow(dx + 55, gy - 100, 170, rgba(255, 200, 120, 0.25)); cv.lighter(false)
            for i in 0..<3 {
                let z = Zed(id: 0, kind: i == 1 ? .runner : .zed, x: 0, depth: 0, seed: hashN(Double(i) + 5))
                z.look = i
                z.walk = T * 200
                let hu = clampD((t - 1.0) / 0.7, 0, 1)
                let fi = Double(i)
                let stand: Double = W * 0.42 + fi * 60
                let run: Double = dx + 40 - t * (330 - fi * 40)
                let zx: Double = hit ? stand + hu * (260 + fi * 80) : max(stand, run)
                if hit {
                    cv.save(); cv.translate(zx, gy - sin(hu * PI) * (150 + Double(i) * 40)); cv.rotate(hu * (5 + Double(i) * 2))
                    figure(cv, 0, 0, -1, 1, zedLook(z), zedPose(z, T)); cv.restore()
                } else { figure(cv, zx, gy, -1, 1, zedLook(z), zedPose(z, T)) }
            }
            var p = Pose()
            let u = clampD((t - 0.8) / 0.3, 0, 1)
            p.armF = lerp(3.6, 0.9, easeOut(u)); p.elbF = 0.25; p.wpn = 0.1
            p.lean = 0.15 + 0.3 * sin(u * PI); p.hipF = 0.5; p.hipB = -0.45; p.kneeF = 0.4
            figure(cv, W * 0.34, gy, 1, 1.15, heroLook(TOWERS[0]), p)
            if hit && t < 1.4 {
                let a = 1 - (t - 1.0) / 0.4
                cv.lighter(true)
                cv.arcStroke(W * 0.34 + 20, gy - 110, 150, -1.25, 0.75, 18 * a + 2, rgba(255, 240, 200, a))
                cv.lighter(false)
                cv.R(0, 0, W, VIEW_H, WHITE.alpha(max(0, 0.7 - (t - 1.0) * 4)))
            }
            stampIn(cv, "TRAPPED.", t, GOLD, g)
        }
        cv.restore()
        if t < 0.25 { cv.R(0, 0, W, VIEW_H, WHITE.alpha(1 - t / 0.25)) }
        cv.R(0, 0, W, 22, BLACK)
        cv.text("skip  ▶", W - g.safeR - 20, 44, 13, GOLD.alpha(0.7), 2, 1)
    }

    private func ending(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let t = g.endT
        night(cv, 0, W, VIEW_H, g.t)
        skyline(cv, 0, W, VIEW_H - 40, 0)
        cv.vfill(0, VIEW_H - 260, W, 260, [(0, rgba(255, 150, 80, 0)), (1, rgba(255, 170, 90, 0.5))])
        let gy = VIEW_H - 40.0
        cv.R(0, gy, W, 40, Col(0x101216))
        for i in 0..<3 {
            var p = Pose()
            p.armF = 2.8; p.elbF = 0.2; p.wpn = 0.1; p.bob = abs(sin(g.t * 3 + Double(i))) * 5; p.hipF = 0.2; p.hipB = -0.2
            figure(cv, W / 2 - 90 + Double(i) * 90, gy, 1, 1.15, heroLook(TOWERS[i]), p)
        }
        let k = min(1, t / 0.3)
        cv.save()
        cv.translate(W / 2, 130)
        cv.rotate(-0.04)
        cv.scale(1 + (1 - k) * 2, 1 + (1 - k) * 2)
        cv.stamp("FLOOR ZERO.", 0, 0, 84, GOLD, 1)
        cv.restore()
        cv.text("All three made it to the plaza.", W / 2, 190, 20, WHITE, 1, 2)
        let mins = Int(g.playT / 60)
        cv.text("\(mins) minutes   ·   \(g.kills) put down   ·   went down \(g.deaths) times", W / 2, 224, 15, WHITE.alpha(0.8), 1, 1)
        if t > 1.5 { cv.text("tap", W / 2, 262, 14, GOLD.alpha(0.6 + 0.3 * sin(g.t * 4)), 1, 2) }
    }
}
