import CoreGraphics
import Foundation

// Buttons, cards, the top bar and the small icons: everything drawn over the scene.

extension Game {
    private func easeOutBack(_ k: Double) -> Double {
        let x = clampD(k, 0, 1) - 1
        return 1 + 2.4 * x * x * x + 1.4 * x * x
    }
    private func easeOut(_ k: Double) -> Double {
        let x = 1 - clampD(k, 0, 1)
        return 1 - x * x * x
    }

    /// A button drawn into the canvas. It is live until the next frame.
    func btn(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ label: String, _ sub: String = "", gold: Bool = false, off: Bool = false, size: Double = 16, _ act: @escaping () -> Void) {
        let pressed = isDown && !off && !uiLock && downX >= x && downX <= x + w && downY >= y && downY <= y + h
        let dy = pressed ? 2.0 : 0.0
        // a gold button breathes; any button squeezes under the finger
        let breathe = gold && !off ? 1 + sin(T * 3.2 + x * 0.01) * 0.012 : 1.0
        let sc = pressed ? 0.955 : breathe
        c.save()
        c.translate(x + w / 2, y + h / 2)
        c.scale(sc, sc)
        c.translate(-(x + w / 2), -(y + h / 2))
        if gold && !off {
            let g = 0.2 + 0.1 * sin(T * 3.2)
            c.glow(x + w / 2, y + h / 2, w * 0.62, Col(0xffd257, g), Col(0xffd257, 0))
        }
        c.RR(x, y + 3, w, h, 10, Col(0x1a0e05))
        // a painted plate of wood and brass if the art is aboard; otherwise the drawn one
        let plated = c.plate(gold ? "plate_gold" : "plate_wood", x, y + dy, w, h, corner: min(15, h * 0.36))
        if plated {
            // the gold plate is lifted a little so dark lettering reads on it
            if gold { c.RR(x + 5, y + dy + 5, w - 10, h - 10, 7, Col(0xffe9a0, 0.34)) }
            if pressed { c.RR(x, y + dy, w, h, 10, Col(0xffffff, 0.14)) }
        } else if gold {
            c.RRGrad(x, y + dy, w, h, 10, [(0, Col(0xffe69a)), (0.5, Col(0xe6ae3c)), (1, Col(0xb47a16))])
        } else {
            c.RRGrad(x, y + dy, w, h, 10, pressed ? [(0, Col(0xb98440)), (0.52, Col(0x8a5a26)), (1, Col(0x633a14))] : [(0, Col(0xa37031)), (0.52, Col(0x774a1c)), (1, Col(0x55310f))])
        }
        // gloss along the top, and a band of light that sweeps across now and then
        c.save()
        c.clipRR(x, y + dy, w, h, 10)
        if !plated { c.RRGrad(x + 3, y + dy + 2, w - 6, h * 0.42, 8, [(0, Col(0xffffff, gold ? 0.32 : 0.13)), (1, Col(0xffffff, 0))]) }
        if !off {
            let period = gold ? 2.6 : 5.2
            let ph = ((T + x * 0.004 + y * 0.002) / period).truncatingRemainder(dividingBy: 1)
            if ph < 0.32 {
                let sx = x - 50 + (w + 100) * (ph / 0.32)
                let a = gold ? 0.5 : 0.16
                c.poly(Col(0xffffff, a), [sx, y + dy, sx + 20, y + dy, sx + 4, y + dy + h, sx - 16, y + dy + h])
                c.poly(Col(0xffffff, a * 0.5), [sx + 26, y + dy, sx + 32, y + dy, sx + 16, y + dy + h, sx + 10, y + dy + h])
            }
        }
        c.restore()
        if !plated { c.RRStroke(x, y + dy, w, h, 10, gold ? 1.5 : 1.2, gold ? Col(0xfff2c0) : Col(0xe3ba68)) }
        let tc = gold ? Col(0x2a1706) : CREAM
        if sub.isEmpty {
            c.text(label, x + w / 2, y + dy + h / 2 + size * 0.34, size, tc, 0, gold ? FONTB : FONT)
        } else {
            c.text(label, x + w / 2, y + dy + h / 2 - 1, size, tc, 0, gold ? FONTB : FONT)
            c.text(sub, x + w / 2, y + dy + h / 2 + size * 0.85, size * 0.74, tc.alpha(0.85), 0, FONTI)
        }
        if off { c.RR(x, y, w, h + 3, 10, Col(0x120a04, 0.55)) }
        c.restore()
        if !off && !uiLock { hits.append(Hit(x: x, y: y, w: w, h: h, act: act)) }
    }

    /// Rings of light that spread from a button just tapped. Drawn over everything.
    func drawRings(_ c: Canvas) {
        for r in rings {
            let k = r.t / 0.45
            let grow = 16 * easeOut(k)
            c.RRStroke(r.x - grow, r.y - grow, r.w + grow * 2, r.h + grow * 2, 10 + grow, 3 * (1 - k), Col(0xffe9a0, 0.9 * (1 - k)))
            c.RR(r.x, r.y, r.w, r.h, 10, Col(0xffffff, 0.35 * max(0, 1 - k * 3)))
        }
    }

    func panel(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        c.RR(x + 3, y + 5, w, h, 14, Col(0x000000, 0.4))
        c.RRGrad(x, y, w, h, 14, [(0, Col(0x3a2412)), (1, Col(0x24150a))])
        c.RRStroke(x, y, w, h, 14, 2, Col(0xd2a455))
        c.RRStroke(x + 4, y + 4, w - 8, h - 8, 11, 1, Col(0xd2a455, 0.35))
    }

    /// A point on the edge of a rectangle, `k` of the way round from the top-left corner.
    private func edgePoint(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ k: Double) -> (Double, Double) {
        let per = 2 * (w + h)
        var d = (k - floor(k)) * per
        if d < w { return (x + d, y) }
        d -= w
        if d < h { return (x + w, y + d) }
        d -= h
        if d < w { return (x + w - d, y + h) }
        d -= w
        return (x, y + h - d)
    }

    func drawCard(_ c: Canvas, _ cd: CardV) {
        hits.removeAll(keepingCapacity: true)
        let t = cardT
        uiLock = t < 0.22
        let low = mode == .sail && play == nil && Game.deckScenes.contains(sceneK)
        c.R(0, 0, W, H, Col(0x000000, (low ? 0.12 : 0.42) * easeOut(t / 0.25)))
        let pw = min(W - safeL - safeR - 30, 620)
        let px = (W - pw) / 2
        let lines = wrapText(cd.text, pw - 40, 16, FONT)
        let n = cd.opts.count
        let cols = n <= 1 ? 1 : (n == 3 && pw > 520 ? 3 : 2)
        let rows = (n + cols - 1) / cols
        let bh = 46.0
        let ph = 50 + Double(lines.count) * 20.5 + 12 + Double(rows) * (bh + 8) + 8
        let py = low ? max(38, H - safeB - ph - 6) : max(38, (H - ph) / 2 + 8)

        // the card springs in from a little above
        let pop = easeOutBack(t / 0.32)
        let sc = 0.82 + 0.18 * pop
        c.save()
        c.alpha(easeOut(t / 0.16))
        c.translate(W / 2, py + ph / 2 - 18 * (1 - easeOut(t / 0.3)))
        c.scale(sc, sc)
        c.translate(-W / 2, -(py + ph / 2))

        c.glow(W / 2, py + ph / 2, pw * 0.75, Col(0xffc860, 0.1 + 0.03 * sin(T * 2)), Col(0xffc860, 0))
        panel(c, px, py, pw, ph)
        // brass studs in the corners
        for (sx, sy) in [(px + 12, py + 12), (px + pw - 12, py + 12), (px + 12, py + ph - 12), (px + pw - 12, py + ph - 12)] {
            c.circ(sx, sy, 3.2, Col(0x8a6220))
            c.circ(sx - 0.8, sy - 0.8, 1.6, Col(0xffe9a0))
        }
        // two glints run round the frame
        for i in 0..<2 {
            let (gx, gy) = edgePoint(px, py, pw, ph, T * 0.11 + Double(i) * 0.5)
            c.glow(gx, gy, 16, Col(0xfff2c0, 0.75), Col(0xfff2c0, 0))
            c.circ(gx, gy, 1.6, Col(0xffffff, 0.9))
        }
        // the title, with a light passing over it, and a rule that draws itself
        c.text(cd.title, px + 20, py + 34, 24, GOLD, -1, FONTD)
        let tw = textW(cd.title, 24, FONTD)
        let sw = ((T * 0.45).truncatingRemainder(dividingBy: 1)) * (tw + 80) - 40
        c.save()
        c.clipRect(px + 20, py + 12, tw, 28)
        c.glow(px + 20 + sw, py + 26, 22, Col(0xffffff, 0.55), Col(0xffffff, 0))
        c.restore()
        let rule = easeOut((t - 0.1) / 0.4)
        c.R(px + 20, py + 42, (pw - 40) * rule, 1.5, Col(0xd2a455, 0.7))
        if rule > 0.02 {
            let ex = px + 20 + (pw - 40) * rule
            c.poly(GOLD, [ex - 4, py + 42.75, ex, py + 39, ex + 4, py + 42.75, ex, py + 46.5])
        }
        var ty = py + 64
        for (i, l) in lines.enumerated() {
            let a = easeOut((t - 0.14 - Double(i) * 0.05) / 0.25)
            c.save()
            c.alpha(a)
            c.text(l, px + 20 + 10 * (1 - a), ty, 16, CREAM, -1, FONT)
            c.restore()
            ty += 20.5
        }
        // the choices rise into place one after another
        let by = ty - 4
        let bw = (pw - 40 - Double(cols - 1) * 8) / Double(cols)
        let after = 0.18 + min(0.3, Double(lines.count) * 0.04)
        for (i, o) in cd.opts.enumerated() {
            let col = i % cols, row = i / cols
            let a = easeOut((t - after - Double(i) * 0.07) / 0.26)
            c.save()
            c.alpha(a)
            btn(c, px + 20 + Double(col) * (bw + 8), by + Double(row) * (bh + 8) + 14 * (1 - a), bw, bh, o.label, o.sub, gold: i == 0 && !o.off, off: o.off, o.act)
            if !o.off, let tag = effectTag(o.sub) {
                // what the choice costs or brings, as a tag on the top corner of its button
                let tx2 = px + 20 + Double(col) * (bw + 8) + bw - 6, ty2 = by + Double(row) * (bh + 8) + 14 * (1 - a) - 7
                let tw2 = textW(tag.1, 12, FONTB) + 30
                c.RR(tx2 - tw2, ty2, tw2, 20, 10, Col(0x1c1108, 0.95))
                c.RRStroke(tx2 - tw2, ty2, tw2, 20, 10, 1.2, tag.2)
                icon(c, tag.0, tx2 - tw2 + 12, ty2 + 10, 14)
                c.text(tag.1, tx2 - tw2 + 22, ty2 + 14.5, 12, tag.2, -1, FONTB)
            }
            if !o.pic.isEmpty {
                if o.off { c.alpha(a * 0.45) }
                optPic(c, o.pic, px + 20 + Double(col) * (bw + 8) + 26, by + Double(row) * (bh + 8) + 14 * (1 - a) + bh / 2, Double(i))
            }
            c.restore()
        }
        c.restore()
        uiLock = false
    }

    /// The moving picture on an upgrade's button: what the yard, or the swordmaster, will do for you.
    func optPic(_ c: Canvas, _ k: String, _ x: Double, _ y: Double, _ seed: Double) {
        let t = T + seed * 0.4
        let wood = Col(0x6b4423), dark = Col(0x2a1a0c), steel = Col(0xe6ecf0)
        c.save()
        c.translate(x, y)
        c.RR(-17, -17, 34, 34, 8, Col(0x1c1108, 0.55)); c.RRStroke(-17, -17, 34, 34, 8, 1, Col(0xd2a455, 0.6))
        c.save()
        c.clipRR(-16, -16, 32, 32, 7)
        switch k {
        case "repair":
            // a hammer driving a nail into a plank
            let sw = sin(t * 5)
            c.R(-14, 7, 28, 6, wood); c.R(-14, 9.5, 28, 0.8, dark)
            c.R(-0.8, 2 + max(0, -sw) * 2, 1.6, 6, steel)
            c.save(); c.translate(9, 6); c.rotate(-1.0 + max(0, sw) * 1.0)
            c.seg(0, 0, 0, -17, 2.4, Col(0x8a6238)); c.RR(-9, -21, 13, 6, 1.5, Col(0x9aa0a8))
            c.restore()
            if sw < -0.8 { for sp in 0..<4 { c.circ(-4 + hashN(Double(sp) + floor(t * 5)) * 8, 2 - hashN(Double(sp) * 3) * 6, 1.1, Col(0xffd257)) } }
        case "sails":
            // a mast growing a new topsail, the canvas filling
            let grow = 0.5 + 0.5 * sin(t * 1.4)
            c.R(-1, -14 - grow * 2, 2, 28 + grow * 2, Col(0x3b2412))
            let belly = 4 + sin(t * 3) * 1.5
            c.pathFill(Col(0xf3ead2)) { p in
                p.move(to: CGPoint(x: -9, y: -2)); p.addLine(to: CGPoint(x: 9, y: -2))
                p.addQuadCurve(to: CGPoint(x: 9, y: 10), control: CGPoint(x: 9 + belly, y: 4))
                p.addLine(to: CGPoint(x: -9, y: 10))
                p.addQuadCurve(to: CGPoint(x: -9, y: -2), control: CGPoint(x: -9 + belly, y: 4))
            }
            c.save(); c.alpha(grow)
            c.pathFill(Col(0xffe9a0)) { p in
                p.move(to: CGPoint(x: -6, y: -13)); p.addLine(to: CGPoint(x: 6, y: -13))
                p.addQuadCurve(to: CGPoint(x: 7, y: -4), control: CGPoint(x: 7 + belly * 0.7, y: -8))
                p.addLine(to: CGPoint(x: -7, y: -4))
                p.addQuadCurve(to: CGPoint(x: -6, y: -13), control: CGPoint(x: -7 + belly * 0.7, y: -8))
            }
            c.restore()
            for w in 0..<2 { let ph = (t * 0.9 + Double(w) * 0.5).truncatingRemainder(dividingBy: 1); c.seg(-16 + ph * 10, -8 + Double(w) * 12, -10 + ph * 10, -8 + Double(w) * 12, 1, Col(0xffffff, 0.6 * (1 - ph))) }
        case "hull":
            // copper plates on the bottom, a gleam running along them
            c.pathFill(wood) { p in
                p.move(to: CGPoint(x: -15, y: -6)); p.addLine(to: CGPoint(x: 15, y: -6))
                p.addQuadCurve(to: CGPoint(x: -11, y: 11), control: CGPoint(x: 10, y: 12)); p.closeSubpath()
            }
            for r in 0..<2 { for q in 0..<5 {
                let px2 = -12 + Double(q) * 5.2 + Double(r) * 2, py2 = 1 + Double(r) * 4.5
                if px2 < 9 - Double(r) * 5 { c.RR(px2, py2, 4.6, 3.8, 0.8, Col(0xc8763a)); c.circ(px2 + 1, py2 + 1, 0.5, Col(0x6a3a18)) }
            } }
            let gl = ((t * 0.6).truncatingRemainder(dividingBy: 1)) * 40 - 20
            c.poly(Col(0xffffff, 0.55), [gl, -8, gl + 5, -8, gl - 3, 14, gl - 8, 14])
            c.seg(-16, -7, 16, -7, 1.5, Col(0xd9a441))
        case "hold":
            // casks going down the hatch
            c.R(-15, 6, 30, 9, dark); c.R(-15, 5, 30, 1.5, wood)
            for b in 0..<2 {
                let ph = (t * 0.6 + Double(b) * 0.5).truncatingRemainder(dividingBy: 1)
                let by2 = -18 + ph * 26, bx2 = -6 + Double(b) * 12
                c.RR(bx2 - 5, by2 - 5, 10, 10, 2.5, Col(0x8a6238)); c.R(bx2 - 5, by2 - 2.5, 10, 1.2, dark); c.R(bx2 - 5, by2 + 1.5, 10, 1.2, dark)
            }
            c.R(-15, 9, 30, 6, Col(0x140c06, 0.85))
        case "guns":
            // a swivel gun on the rail: it fires, kicks, and the smoke rolls off
            let ph = (t * 0.7).truncatingRemainder(dividingBy: 1)
            let kick = ph < 0.15 ? sin(ph / 0.15 * PI) * 3 : 0
            c.R(-15, 8, 30, 3, wood); c.seg(-3, 8, -3, 2, 2, steel.shade(0.6))
            c.save(); c.translate(-3 - kick, 1); c.rotate(-0.2 - kick * 0.03)
            c.RR(-7, -3, 18, 6, 2.5, Col(0x2a2a30)); c.circ(-7, 0, 3.4, Col(0x2a2a30)); c.R(10, -3.5, 2, 7, Col(0xd9a441))
            c.restore()
            if ph < 0.12 { c.glow(11, -2, 12, Col(0xffd257, 0.95 * (1 - ph / 0.12)), Col(0xffd257, 0)) }
            if ph < 0.7 { for sm in 0..<4 { c.circ(10 + ph * 10 + Double(sm) * 2, -3 - ph * 10 - Double(sm) * 1.5, 2 + ph * 5, Col(0xf0f0f0, 0.6 * (1 - ph / 0.7))) } }
        case "berths":
            // a hammock swinging, somebody asleep in it
            let sw = sin(t * 2) * 3
            c.seg(-14, -10, -14, 12, 1.6, Col(0x3b2412)); c.seg(14, -10, 14, 12, 1.6, Col(0x3b2412))
            c.curve(-14, -6, sw, 12, 14, -6, 3, Col(0xd9cdb0)); c.curve(-14, -6, sw, 8, 14, -6, 1, Col(0x8a7a5a))
            c.circ(-6 + sw * 0.5, 0, 2.6, Col(0xe3b58a))
            for z in 0..<2 { let ph = (t * 0.5 + Double(z) * 0.5).truncatingRemainder(dividingBy: 1); c.text("z", -2 + ph * 8, -4 - ph * 10, 7 + ph * 3, Col(0xffffff, 1 - ph), 0, FONTB) }
        case "riposte":
            // one blade turns the other aside and goes through
            let ph = (t * 0.8).truncatingRemainder(dividingBy: 1)
            let th = ph < 0.4 ? 0 : min(1, (ph - 0.4) / 0.2)
            c.seg(12, -12, -4 + th * 4, 4 - th * 8, 2, steel.shade(0.7))
            c.seg(-13 + th * 8, 10 - th * 6, 3 + th * 9, -2 - th * 6, 2.4, steel)
            if ph > 0.38 && ph < 0.5 { for j in 0..<6 { let a = Double(j) * PI / 3; c.seg(1 + cos(a) * 2, 0 + sin(a) * 2, 1 + cos(a) * 7, sin(a) * 7, 1, Col(0xffe060)) } }
        case "wind":
            // breath coming back: a chest that fills, and air drawn in
            let br = 0.5 + 0.5 * sin(t * 2.4)
            c.ell(0, 3, 8 + br * 3, 9 + br * 1.5, Col(0x6ab8ff, 0.85)); c.ell(-2, 0, 3 + br, 4, Col(0xffffff, 0.35))
            for j in 0..<3 { let ph = (t * 0.8 + Double(j) / 3).truncatingRemainder(dividingBy: 1); c.curve(-16 + ph * 8, -12 + Double(j) * 5, -8 + ph * 6, -15 + Double(j) * 5, -2, -8 + Double(j) * 2, 1.1, Col(0xffffff, 0.8 * (1 - ph))) }
        default:
            // fury: a flame
            for j in 0..<3 {
                let fx = (Double(j) - 1) * 6
                let h: Double = 16 + 5 * sin(t * 9 + Double(j) * 2)
                c.poly(Col(0xff6a18), [fx - 5, 12, fx + sin(t * 7 + Double(j)) * 3, 12 - h, fx + 5, 12])
                c.poly(Col(0xffd257), [fx - 2.6, 12, fx + sin(t * 9 + Double(j)) * 1.5, 12 - h * 0.55, fx + 2.6, 12])
            }
        }
        c.restore()
        c.restore()
    }

    func drawToast(_ c: Canvas) {
        if toastT <= 0 || toastText.isEmpty { return }
        let a = min(1, toastT * 2)
        let age = 3.2 - toastT
        let size = 15.0
        let lines = wrapText(toastText, min(W * 0.7, 520), size, FONT)
        var tw = 0.0
        for l in lines { tw = max(tw, textW(l, size, FONT)) }
        let w = tw + 32, h = Double(lines.count) * 19 + 14
        let x = (W - w) / 2, y = mode == .duel ? 100.0 : 40.0
        // drops in with a little bounce
        let sc = 0.8 + 0.2 * easeOutBack(age / 0.3)
        c.save()
        c.alpha(a * easeOut(age / 0.15))
        c.translate(W / 2, y + h / 2 - 16 * (1 - easeOut(age / 0.28)))
        c.scale(sc, sc)
        c.translate(-W / 2, -(y + h / 2))
        c.glow(W / 2, y + h / 2, w * 0.6, Col(0xfff2c0, 0.25 * max(0, 1 - age / 0.6)), Col(0xfff2c0, 0))
        c.RR(x + 2, y + 3, w, h, 9, Col(0x000000, 0.35))
        c.RRGrad(x, y, w, h, 9, [(0, Col(0xfbf3dc)), (1, Col(0xe6d6aa))])
        c.RRStroke(x, y, w, h, 9, 1.5, Col(0x6b4a26))
        var ty = y + 20
        for l in lines {
            c.text(l, W / 2, ty, size, Col(0x2a1706), 0, FONT)
            ty += 19
        }
        c.restore()
    }

    func drawSparks(_ c: Canvas) {
        for s in sparks {
            let k = clampD(s.life / s.max, 0, 1)
            c.circ(s.x, s.y, s.r * (0.5 + k * 0.5), s.c.alpha(s.c.a * k))
        }
    }

    /// A small picture for each thing the top bar counts.
    func icon(_ c: Canvas, _ k: String, _ x: Double, _ y: Double, _ s: Double) {
        switch k {
        case "day":
            c.circ(x, y, s * 0.3, Col(0xffd257))
            for i in 0..<8 {
                let a = Double(i) * PI / 4
                c.seg(x + cos(a) * s * 0.4, y + sin(a) * s * 0.4, x + cos(a) * s * 0.52, y + sin(a) * s * 0.52, 1.4, Col(0xffd257))
            }
        case "gold":
            c.circ(x, y, s * 0.42, Col(0xb47a16))
            c.circ(x, y, s * 0.34, Col(0xffd257))
            c.circ(x - s * 0.1, y - s * 0.1, s * 0.1, Col(0xfff6c0))
        case "food":
            c.ell(x, y + s * 0.08, s * 0.46, s * 0.3, Col(0x8a5a2c))
            c.ell(x, y, s * 0.42, s * 0.26, Col(0xc98a45))
            c.seg(x - s * 0.15, y - s * 0.1, x - s * 0.05, y + s * 0.08, 1.2, Col(0x8a5a2c))
            c.seg(x + s * 0.08, y - s * 0.12, x + s * 0.18, y + s * 0.06, 1.2, Col(0x8a5a2c))
        case "water":
            c.pathFill(Col(0x4aa8e8)) { p in
                p.move(to: CGPoint(x: x, y: y - s * 0.48))
                p.addQuadCurve(to: CGPoint(x: x, y: y + s * 0.44), control: CGPoint(x: x + s * 0.62, y: y + s * 0.3))
                p.addQuadCurve(to: CGPoint(x: x, y: y - s * 0.48), control: CGPoint(x: x - s * 0.62, y: y + s * 0.3))
            }
            c.circ(x - s * 0.1, y + s * 0.1, s * 0.09, Col(0xd6efff))
        case "planks":
            c.RR(x - s * 0.45, y - s * 0.3, s * 0.9, s * 0.24, 1.5, Col(0xc9a86a))
            c.RR(x - s * 0.45, y + s * 0.04, s * 0.9, s * 0.24, 1.5, Col(0xa8823f))
        case "bait":
            c.arcStroke(x - s * 0.06, y + s * 0.12, s * 0.26, 0, PI * 1.15, 2, Col(0xdfe6ea))
            c.seg(x + s * 0.2, y + s * 0.12, x + s * 0.2, y - s * 0.44, 2, Col(0xdfe6ea))
        case "powder":
            c.circ(x, y + s * 0.06, s * 0.36, Col(0x1a1a1e))
            c.circ(x - s * 0.1, y - s * 0.04, s * 0.09, Col(0x55555e))
            c.seg(x + s * 0.18, y - s * 0.24, x + s * 0.34, y - s * 0.44, 1.5, Col(0xc9a86a))
            c.circ(x + s * 0.36, y - s * 0.46, s * 0.08, Col(0xff9a3a))
        case "arms":
            c.seg(x - s * 0.36, y + s * 0.36, x + s * 0.36, y - s * 0.36, 2.2, Col(0xe8edf1))
            c.seg(x + s * 0.36, y + s * 0.36, x - s * 0.36, y - s * 0.36, 2.2, Col(0xe8edf1))
            c.seg(x - s * 0.36, y + s * 0.36, x - s * 0.2, y + s * 0.2, 3, Col(0x8a5a2c))
            c.seg(x + s * 0.36, y + s * 0.36, x + s * 0.2, y + s * 0.2, 3, Col(0x8a5a2c))
        case "crew":
            c.circ(x, y - s * 0.2, s * 0.2, Col(0xe3b58a))
            c.arcFill(x, y + s * 0.44, s * 0.38, PI, PI * 2, Col(0x4a8fd0))
        default:
            c.pathFill(Col(0x8a5a2c)) { p in
                p.move(to: CGPoint(x: x - s * 0.5, y: y - s * 0.05))
                p.addLine(to: CGPoint(x: x + s * 0.5, y: y - s * 0.05))
                p.addLine(to: CGPoint(x: x + s * 0.34, y: y + s * 0.3))
                p.addLine(to: CGPoint(x: x - s * 0.36, y: y + s * 0.3))
                p.closeSubpath()
            }
            c.seg(x, y - s * 0.05, x, y - s * 0.5, 1.5, Col(0x8a5a2c))
            c.poly(Col(0xf1e7cf), [x + 1, y - s * 0.48, x + s * 0.34, y - s * 0.14, x + 1, y - s * 0.14])
        }
    }

    func pill(_ c: Canvas, _ x: Double, _ k: String, _ txt: String, warn: Bool = false) -> Double {
        let size = 13.0
        let w = 30 + textW(txt, size, FONT) + 8
        c.RR(x, 6, w, 24, 12, Col(0x1c1108, 0.82))
        c.RRStroke(x, 6, w, 24, 12, 1, warn ? Col(0xff7a5a) : Col(0xd2a455, 0.8))
        icon(c, k, x + 15, 18, 18)
        c.text(txt, x + 28, 22.5, size, warn ? Col(0xffb0a0) : CREAM, -1, FONT)
        if card == nil && sum == nil {
            hits.append(Hit(x: x, y: 0, w: w, h: 34, act: { [unowned self] in self.toast(self.about(k)) }))
        }
        return x + w + 5
    }

    /// What each thing along the top is for, said when it is tapped.
    func about(_ k: String) -> String {
        let per = max(0.01, ration())
        switch k {
        case "day": return "Day \(cal) of the voyage. Wages fall due each time you sail"
        case "gold": return "Gold: buys stores, repairs and upgrades, and pays the crew"
        case "food": return "Stores: food and water. \(storeDays()) days at this ration" + (mode == .sail ? "; port is \(daysToGo()) days away" : "; the next passage needs \(storesNeeded())")
        case "water": return "Water: the crew drinks every day. About \(Int(water / per) * SUNS) days left"
        case "planks": return "Planks: mend leaks and broken spars at sea"
        case "bait": return "Bait: lets you stop and fish for food"
        case "powder": return "Powder: a broadside before boarding thins the pirates"
        case "arms": return "Blades: armed hands fight better when you are boarded"
        case "crew": return "Crew: \(crew) hands aboard" + (laidUp() > 0 ? ", \(laidUp()) sick or wounded" : ", all fit")
        default: return "Hull: how sound she is. Repair at a shipwright"
        }
    }

    /// Reads a choice's small print for what it costs or brings: "+120 gold", "-4 stores", "lose 4 days", or a risk.
    func effectTag(_ sub: String) -> (String, String, Col)? {
        let s = sub.lowercased()
        let red = Col(0xff7a5a), green = Col(0x9fe08a), amber = Col(0xffc060)
        if let r = s.range(of: "[+-] ?[0-9]+ (stores|gold|powder|planks|bait|blades|food)", options: .regularExpression) {
            let m = String(s[r])
            let plus = m.hasPrefix("+")
            let num = String(m.filter { $0.isNumber })
            let keys: [(String, String)] = [("stores", "food"), ("food", "food"), ("gold", "gold"), ("powder", "powder"), ("planks", "planks"), ("bait", "bait"), ("blades", "arms")]
            let key = keys.first(where: { m.contains($0.0) })?.1 ?? "gold"
            return (key, (plus ? "+" : "−") + num, plus ? green : red)
        }
        if let r = s.range(of: "lose [0-9]+ days", options: .regularExpression) {
            return ("day", "−" + String(String(s[r]).filter { $0.isNumber }) + " days", red)
        }
        if let r = s.range(of: "^[0-9]+ gold", options: .regularExpression) {
            return ("gold", "−" + String(String(s[r]).filter { $0.isNumber }), red)
        }
        for w in ["hurt", "lash", "risk", "danger", "may ", "will not like", "one will", "stove", "sicken", "two will"] where s.contains(w) {
            return ("crew", "risky", amber)
        }
        return nil
    }

    /// A pointing hand and a word of advice. Only on the first voyage, until the player has sailed from a port.
    func coach(_ c: Canvas, _ tx: Double, _ ty: Double, _ text: String, below: Bool) {
        if UserDefaults.standard.bool(forKey: "fh_coached") || card != nil || sum != nil || play != nil { return }
        let ph = (T * 0.9).truncatingRemainder(dividingBy: 1)
        c.circStroke(tx, ty, 8 + ph * 20, 2.4, Col(0xffe08a, 0.9 * (1 - ph)))
        let bob = abs(sin(T * 4)) * 7
        let dir: Double = below ? 1 : -1
        let hy = ty + dir * (8 + bob)
        c.save()
        c.translate(tx, hy)
        if !below { c.rotate(PI) }
        // a gloved hand, one finger out
        c.RR(-4.5 + 1.5, 2, 9, 20, 4.5, Col(0x000000, 0.25))
        c.RR(-4.5, 0, 9, 20, 4.5, WHITE)
        c.RR(-11, 14, 24, 20, 8, WHITE)
        for k in 0..<3 { c.seg(-6 + Double(k) * 6, 15, -6 + Double(k) * 6, 19, 1, Col(0x9a8a7a)) }
        c.RRStroke(-4.5, 0, 9, 20, 4.5, 1.2, Col(0x3a2412))
        c.RRStroke(-11, 14, 24, 20, 8, 1.2, Col(0x3a2412))
        c.R(-9, 32, 20, 6, Col(0xd2a455))
        c.restore()
        let tw = textW(text, 14, FONTB) + 28
        let bx = clampD(tx - tw / 2, safeL + 4, W - safeR - tw - 4)
        let byy = below ? hy + 44 : hy - 44 - 30
        c.RR(bx + 2, byy + 3, tw, 30, 15, Col(0x000000, 0.35))
        c.RR(bx, byy, tw, 30, 15, Col(0xfff8e6))
        c.RRStroke(bx, byy, tw, 30, 15, 2, Col(0xd2a455))
        c.text(text, bx + tw / 2, byy + 20, 14, Col(0x2a1808), 0, FONTB)
    }

    func drawHUD(_ c: Canvas) {
        var x = safeL
        x = pill(c, x, "day", "Day \(cal)")
        x = pill(c, x, "gold", "\(gold)")
        // stores in days, the way the captain thinks of them; red when they will not last to port
        let sdays = storeDays()
        let short = mode == .sail ? sdays < daysToGo() : sdays < storesNeeded()
        let fx0 = x
        x = pill(c, x, "food", "\(sdays) days", warn: short)
        // each day eaten floats up off the counter, so the player sees the stores going
        if mode == .sail && card == nil && play == nil {
            if sdLast >= 0 && sdays < sdLast && sdLast - sdays < 6 { sdFloat.append((T, sdLast - sdays)) }
        }
        sdLast = sdays
        sdFloat.removeAll { T - $0.0 > 1.5 }
        for f in sdFloat {
            let age = T - f.0
            c.text("−\(f.1) day", (fx0 + x - 5) / 2, 44 + age * 16, 12, Col(0xffb0a0, max(0, 1 - age / 1.5)), 0, FONTB)
        }
        x = pill(c, x, "planks", "\(planks)")
        x = pill(c, x, "bait", "\(bait)")
        x = pill(c, x, "powder", "\(powder)")
        x = pill(c, x, "arms", "\(arms)")
        let down = laidUp()
        x = pill(c, x, "crew", down > 0 ? "\(crew) (\(down) down)" : "\(crew)", warn: down > 0)
        // hull bar
        let w = 96.0
        if x + w < W - safeR - 34 {
            c.RR(x, 6, w, 24, 12, Col(0x1c1108, 0.82))
            c.RRStroke(x, 6, w, 24, 12, 1, Col(0xd2a455, 0.8))
            icon(c, "hull", x + 15, 18, 18)
            let k = clampD(hull / Double(max(1, ship.hull)), 0, 1)
            c.RR(x + 30, 14, w - 40, 8, 4, Col(0x000000, 0.5))
            c.RR(x + 30, 14, (w - 40) * k, 8, 4, k < 0.35 ? REDC : GREENC)
        }
        if mode == .sail || mode == .port || mode == .chart {
            // the settings cog, top right
            let gx = W - safeR - 20, gy = 18.0
            c.circ(gx, gy, 13, Col(0x1c1108, 0.82)); c.circStroke(gx, gy, 13, 1, Col(0xd2a455, 0.8))
            c.roundCaps(true)
            for k2 in 0..<8 { let a = Double(k2) * PI / 4; c.seg(gx + cos(a) * 5, gy + sin(a) * 5, gx + cos(a) * 8.5, gy + sin(a) * 8.5, 2.6, CREAM) }
            c.roundCaps(false)
            c.circ(gx, gy, 6, CREAM); c.circ(gx, gy, 2.6, Col(0x1c1108))
            if card == nil && sum == nil && play == nil {
                hits.append(Hit(x: gx - 20, y: 0, w: 40, h: 38, act: { [unowned self] in self.snd?.click(); self.openSettings() }))
            }
        }
    }

    func gauge(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ k: Double, _ c1: Col, _ c2: Col) {
        c.RR(x - 2, y - 2, w + 4, h + 4, (h + 4) / 2, Col(0x1c1108, 0.85))
        c.RRStroke(x - 2, y - 2, w + 4, h + 4, (h + 4) / 2, 1, Col(0xd2a455))
        let kk = clampD(k, 0, 1)
        if kk > 0.01 { c.RRGrad(x, y, w * kk, h, h / 2, [(0, c1), (1, c2)]) }
    }
}
