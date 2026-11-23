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
        if gold {
            c.RRGrad(x, y + dy, w, h, 10, [(0, Col(0xffe69a)), (0.5, Col(0xe6ae3c)), (1, Col(0xb47a16))])
        } else {
            c.RRGrad(x, y + dy, w, h, 10, pressed ? [(0, Col(0xb98440)), (0.52, Col(0x8a5a26)), (1, Col(0x633a14))] : [(0, Col(0xa37031)), (0.52, Col(0x774a1c)), (1, Col(0x55310f))])
        }
        // gloss along the top, and a band of light that sweeps across now and then
        c.save()
        c.clipRR(x, y + dy, w, h, 10)
        c.RRGrad(x + 3, y + dy + 2, w - 6, h * 0.42, 8, [(0, Col(0xffffff, gold ? 0.32 : 0.13)), (1, Col(0xffffff, 0))])
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
        c.RRStroke(x, y + dy, w, h, 10, gold ? 1.5 : 1.2, gold ? Col(0xfff2c0) : Col(0xe3ba68))
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
            c.restore()
        }
        c.restore()
        uiLock = false
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
        return x + w + 5
    }

    func drawHUD(_ c: Canvas) {
        var x = safeL
        x = pill(c, x, "day", "Day \(cal)")
        x = pill(c, x, "gold", "\(gold)")
        x = pill(c, x, "food", "\(Int(food))", warn: food < Double(crew) * 0.7)
        x = pill(c, x, "water", "\(Int(water))", warn: water < Double(crew) * 0.7)
        x = pill(c, x, "planks", "\(planks)")
        x = pill(c, x, "bait", "\(bait)")
        x = pill(c, x, "powder", "\(powder)")
        x = pill(c, x, "arms", "\(arms)")
        let down = laidUp()
        x = pill(c, x, "crew", down > 0 ? "\(crew) (\(down) down)" : "\(crew)", warn: down > 0)
        // hull bar
        let w = 96.0
        if x + w < W - safeR {
            c.RR(x, 6, w, 24, 12, Col(0x1c1108, 0.82))
            c.RRStroke(x, 6, w, 24, 12, 1, Col(0xd2a455, 0.8))
            icon(c, "hull", x + 15, 18, 18)
            let k = clampD(hull / Double(max(1, ship.hull)), 0, 1)
            c.RR(x + 30, 14, w - 40, 8, 4, Col(0x000000, 0.5))
            c.RR(x + 30, 14, (w - 40) * k, 8, 4, k < 0.35 ? REDC : GREENC)
        }
    }

    func gauge(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ k: Double, _ c1: Col, _ c2: Col) {
        c.RR(x - 2, y - 2, w + 4, h + 4, (h + 4) / 2, Col(0x1c1108, 0.85))
        c.RRStroke(x - 2, y - 2, w + 4, h + 4, (h + 4) / 2, 1, Col(0xd2a455))
        let kk = clampD(k, 0, 1)
        if kk > 0.01 { c.RRGrad(x, y, w * kk, h, h / 2, [(0, c1), (1, c2)]) }
    }
}
