import CoreGraphics
import Foundation

// Buttons, cards, the top bar and the small icons: everything drawn over the scene.

extension Game {
    /// A button drawn into the canvas. It is live until the next frame.
    func btn(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ label: String, _ sub: String = "", gold: Bool = false, off: Bool = false, size: Double = 16, _ act: @escaping () -> Void) {
        let pressed = isDown && !off && downX >= x && downX <= x + w && downY >= y && downY <= y + h
        let dy = pressed ? 2.0 : 0.0
        c.RR(x, y + 3, w, h, 10, Col(0x1a0e05))
        if gold {
            c.RRGrad(x, y + dy, w, h, 10, [(0, Col(0xffe69a)), (0.5, Col(0xe6ae3c)), (1, Col(0xb47a16))])
            c.RRStroke(x, y + dy, w, h, 10, 1.5, Col(0xfff2c0))
        } else {
            c.RRGrad(x, y + dy, w, h, 10, [(0, Col(0xa37031)), (0.52, Col(0x774a1c)), (1, Col(0x55310f))])
            c.RRStroke(x, y + dy, w, h, 10, 1.2, Col(0xe3ba68))
        }
        let tc = gold ? Col(0x2a1706) : CREAM
        if sub.isEmpty {
            c.text(label, x + w / 2, y + dy + h / 2 + size * 0.34, size, tc, 0, gold ? FONTB : FONT)
        } else {
            c.text(label, x + w / 2, y + dy + h / 2 - 1, size, tc, 0, gold ? FONTB : FONT)
            c.text(sub, x + w / 2, y + dy + h / 2 + size * 0.85, size * 0.74, tc.alpha(0.85), 0, FONTI)
        }
        if off {
            c.RR(x, y, w, h + 3, 10, Col(0x120a04, 0.55))
        } else {
            hits.append(Hit(x: x, y: y, w: w, h: h, act: act))
        }
    }

    func panel(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        c.RR(x + 3, y + 5, w, h, 14, Col(0x000000, 0.4))
        c.RRGrad(x, y, w, h, 14, [(0, Col(0x3a2412)), (1, Col(0x24150a))])
        c.RRStroke(x, y, w, h, 14, 2, Col(0xd2a455))
        c.RRStroke(x + 4, y + 4, w - 8, h - 8, 11, 1, Col(0xd2a455, 0.35))
    }

    func drawCard(_ c: Canvas, _ cd: CardV) {
        hits.removeAll(keepingCapacity: true)
        c.R(0, 0, W, H, Col(0x000000, 0.35))
        let pw = min(W - safeL - safeR - 30, 620)
        let px = (W - pw) / 2
        let lines = wrapText(cd.text, pw - 40, 16, FONT)
        let n = cd.opts.count
        let cols = n <= 1 ? 1 : (n == 3 && pw > 520 ? 3 : 2)
        let rows = (n + cols - 1) / cols
        let bh = 46.0
        let ph = 50 + Double(lines.count) * 20.5 + 12 + Double(rows) * (bh + 8) + 8
        let py = max(38, (H - ph) / 2 + 8)
        panel(c, px, py, pw, ph)
        c.text(cd.title, px + 20, py + 34, 24, GOLD, -1, FONTD)
        c.R(px + 20, py + 42, pw - 40, 1.5, Col(0xd2a455, 0.6))
        var ty = py + 64
        for l in lines {
            c.text(l, px + 20, ty, 16, CREAM, -1, FONT)
            ty += 20.5
        }
        let by = ty - 4
        let bw = (pw - 40 - Double(cols - 1) * 8) / Double(cols)
        for (i, o) in cd.opts.enumerated() {
            let col = i % cols, row = i / cols
            btn(c, px + 20 + Double(col) * (bw + 8), by + Double(row) * (bh + 8), bw, bh, o.label, o.sub, gold: i == 0 && !o.off, off: o.off, o.act)
        }
    }

    func drawToast(_ c: Canvas) {
        if toastT <= 0 || toastText.isEmpty { return }
        let a = min(1, toastT * 2)
        let size = 15.0
        let lines = wrapText(toastText, min(W * 0.7, 520), size, FONT)
        var tw = 0.0
        for l in lines { tw = max(tw, textW(l, size, FONT)) }
        let w = tw + 32, h = Double(lines.count) * 19 + 14
        let x = (W - w) / 2, y = 40.0
        c.save()
        c.alpha(a)
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
        x = pill(c, x, "day", "Day \(day)")
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
