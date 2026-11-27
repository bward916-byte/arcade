import CoreGraphics
import Foundation

// Before a game starts: a card that shows, with a moving hand, exactly what to do.
// Shown the first two times each game comes up, and again whenever the "?" is tapped.

extension Game {
    static let howKeys = ["flyfish", "trim", "cask", "gleam", "turtle", "gulls", "fish", "storm", "run", "line", "leak", "fog", "wreck", "island", "ghost", "row", "shark", "dock", "thief", "rats", "fire", "strong"]
    func resetHowTo() { for k in Game.howKeys { UserDefaults.standard.removeObject(forKey: "fh_how_" + k) } }

    /// Decides whether this game opens with its how-to card.
    func armIntro(_ p: Play) {
        let key = "fh_how_" + p.theme
        let seen = UserDefaults.standard.integer(forKey: key)
        p.intro = seen < 2
        if seen < 2 { UserDefaults.standard.set(seen + 1, forKey: key) }
    }
    func helpSpot() -> (Double, Double) {
        let bw = min(W * 0.62, 520)
        return ((W + bw) / 2 + 24, 61)
    }

    private func hand(_ c: Canvas, _ x: Double, _ y: Double, _ down: Bool, hold: Bool = false) {
        if down {
            if hold {
                c.circStroke(x, y, 15 + sin(T * 10) * 1.5, 3, Col(0xffe08a, 0.95))
            } else {
                let ph = (T * 3).truncatingRemainder(dividingBy: 1)
                c.circStroke(x, y, 8 + ph * 16, 2.4, Col(0xffe08a, 0.95 * (1 - ph)))
            }
            c.circ(x, y, 7, Col(0xffe08a, 0.55))
        }
        let lift: Double = down ? 0 : 9
        c.save()
        c.translate(x, y + lift)
        c.RR(-3, 2, 9, 20, 4.5, Col(0x000000, 0.25))
        c.RR(-4.5, 0, 9, 20, 4.5, WHITE)
        c.RR(-11, 14, 24, 20, 8, WHITE)
        c.RRStroke(-4.5, 0, 9, 20, 4.5, 1.2, Col(0x3a2412))
        c.RRStroke(-11, 14, 24, 20, 8, 1.2, Col(0x3a2412))
        c.R(-9, 32, 20, 5, Col(0xd2a455))
        c.restore()
    }
    private func miniBar(_ c: Canvas, _ x: Double, _ y: Double, _ w: Double, _ zc: Double, _ zw: Double) {
        c.RR(x, y, w, 14, 7, Col(0x2a1a0c))
        c.RRStroke(x, y, w, 14, 7, 1.2, Col(0xd2a455, 0.8))
        c.RR(x + w * (zc - zw / 2), y, w * zw, 14, 4, Col(0x4aaa5c))
        c.RR(x + w * (zc - zw / 6), y, w * zw / 3, 14, 3, Col(0xffe08a))
    }
    private func miniBox(_ c: Canvas, _ x: Double, _ y: Double, _ lit: Bool, _ open: Bool, _ label: String) {
        c.RR(x - 20, y - 18, 40, 36, 5, open ? Col(0x5a4a1c) : Col(0xa8823f))
        c.RRStroke(x - 20, y - 18, 40, 36, 5, 1.4, Col(0x5a3d20))
        if open {
            c.circ(x, y, 9, Col(0xffd257)); c.circStroke(x, y, 9, 1.2, Col(0xb0802c))
        } else {
            c.seg(x - 20, y - 18, x + 20, y + 18, 1.2, Col(0x5a3d20)); c.seg(x + 20, y - 18, x - 20, y + 18, 1.2, Col(0x5a3d20))
        }
        if lit {
            c.RR(x - 20, y - 18, 40, 36, 5, Col(0xfff2a0, 0.55))
            c.RRStroke(x - 22, y - 20, 44, 40, 6, 2.4, Col(0xfff6d8))
        }
        if !label.isEmpty {
            c.circ(x, y - 24, 9, Col(0x1c1108, 0.9))
            c.text(label, x, y - 20, 12, Col(0xfff2a0), 0, FONTB)
        }
    }

    func howText(_ p: Play) -> String {
        var s = ""
        switch p.kind {
        case .timing: s = "A marker runs along the bar. Tap anywhere when it is in the green. The gold middle is a perfect."
        case .taps: s = "Things pop up with a ring that runs out. Tap each one before its ring is gone. A gold ring is quicker and pays extra."
        case .pick:
            if p.seq.isEmpty { s = "Tap one to open it. You only get a few picks, so choose well. A glint at the start means there is something inside." } else { s = "First watch: they light up in an order. Then tap them back in the same order. Get it right and you are shown what is inside before you pick." }
        case .hold: s = "Press and hold anywhere: the bar fills. Lift your finger when the bar reaches the green."
        case .steer: s = "Keep a finger on the screen and slide it left and right. The little ship follows your finger."
        case .swipe: s = "An arrow appears. Swipe your finger across the screen the way it points, before its ring runs out."
        case .beat: s = "A white ring closes in on the gold circle. Tap at the moment they meet, and keep the rhythm."
        case .reel: s = "Tap as fast as you can to haul in. When the bar turns red, stop tapping until it calms, or the line snaps."
        }
        let stake: [String: String] = [
            "storm": "Steer through the gap in each wave. Every wave that catches her costs hull.",
            "fog": "Steer around each rock. Every rock struck costs hull.",
            "line": "Three throws to reach him, or he is lost.",
            "strong": "Send the puck up to the bell. Three rings win the purse.",
            "fire": "Miss more than two and the town will not pay.",
            "row": "Two bad strokes cost extra rations.",
            "dock": "Every load swung aboard pays gold.",
            "fish": "Every fish landed is stores for the crew.",
            "turtle": "Land her and the crew eats well.",
            "leak": "Every leak missed costs hull.",
            "run": "Every gust caught puts water between you and them.",
            "shark": "Miss two and the castaway is lost.",
            "rats": "Every rat that gets by spoils stores.",
            "thief": "Catch him often enough to get the purse back.",
            "gulls": "Every gull that gets through takes a fish.",
            "trim": "Good trimming shortens the passage."
        ]
        if let t = stake[p.theme] { s += " " + t }
        return s
    }

    func drawPlayIntro(_ c: Canvas, _ p: Play) {
        let u = p.introT
        c.R(0, 0, W, H, Col(0x000000, 0.55 * min(1, u / 0.2)))
        let pw = min(W - safeL - safeR - 40, 480.0)
        let ph = min(H - 24, 276.0)
        let px = (W - pw) / 2, py = (H - ph) / 2
        c.RR(px + 3, py + 4, pw, ph, 16, Col(0x000000, 0.4))
        c.RRGrad(px, py, pw, ph, 16, [(0, Col(0x3a2412, 0.98)), (1, Col(0x1e1108, 0.98))])
        c.RRStroke(px, py, pw, ph, 16, 2, Col(0xd2a455))
        c.text(p.title, W / 2, py + 28, 20, GOLD, 0, FONTD)
        let dy = py + 42, dh = 100.0
        c.RR(px + 16, dy, pw - 32, dh, 10, Col(0x0c2236, 0.85))
        c.RRStroke(px + 16, dy, pw - 32, dh, 10, 1, Col(0xd2a455, 0.5))
        let cx = W / 2, cy = dy + dh / 2
        switch p.kind {
        case .timing:
            let s = (u / 2).truncatingRemainder(dividingBy: 1)
            let bx = cx - 110
            miniBar(c, bx, cy - 26, 220, 0.5, 0.26)
            let hit = s > 0.46 && s < 0.6
            if hit { c.RRStroke(bx + 220 * 0.37 - 2, cy - 28, 220 * 0.26 + 4, 18, 6, 2, Col(0xfff2a0)) }
            c.RR(bx + 220 * s - 2.5, cy - 31, 5, 24, 2.5, WHITE)
            hand(c, cx, cy + 2, hit)
            if hit { c.text("tap!", cx + 44, cy + 14, 15, Col(0xfff2a0), 0, FONTB) }
        case .taps:
            let t3 = u.truncatingRemainder(dividingBy: 3)
            let i = Int(t3), f = t3 - Double(i)
            let xs = [cx - 80, cx + 10, cx + 90], ys = [cy - 20, cy - 4, cy - 24]
            let prev = (i + 2) % 3
            let k = min(1, f / 0.5)
            let hx = xs[prev] + (xs[i] - xs[prev]) * k, hy = ys[prev] + (ys[i] - ys[prev]) * k
            let tapped = f > 0.6
            if !tapped {
                c.circ(xs[i], ys[i], 8, Col(0xff7a2a))
                c.circStroke(xs[i], ys[i], 12 + (1 - f / 0.6) * 12, 2.4, Col(0xffe08a))
            } else {
                c.text("+1", xs[i], ys[i] - 10 - (f - 0.6) * 20, 15, Col(0x9ff0aa), 0, FONTB)
            }
            hand(c, hx, hy + 6, f > 0.55 && f < 0.8)
        case .pick:
            let xs = [cx - 90, cx - 30, cx + 30, cx + 90]
            if p.seq.isEmpty {
                let s = u.truncatingRemainder(dividingBy: 3)
                for j in 0..<4 { miniBox(c, xs[j], cy - 16, false, j == 2 && s > 1.1, "") }
                let k = min(1, s / 0.9)
                hand(c, xs[0] + (xs[2] - xs[0]) * k, cy + 2, s > 1.0 && s < 1.35)
                if s > 1.1 { c.text("gold!", xs[2], cy - 40, 13, Col(0xfff2a0), 0, FONTB) }
            } else {
                let order = [1, 3, 0]
                let s = u.truncatingRemainder(dividingBy: 5.4)
                var lit = -1, num = 0
                var hx = xs[1], hdown = false, showHand = false
                if s < 1.8 {
                    let k = Int(s / 0.6)
                    if s - Double(k) * 0.6 < 0.42 { lit = order[k]; num = k + 1 }
                    c.text("1. watch", cx, dy + dh - 8, 13, Col(0xfff2a0), 0, FONTB)
                } else if s > 2.2 && s < 4.9 {
                    let s2 = s - 2.2
                    let k = min(2, Int(s2 / 0.9)), f = s2 - Double(k) * 0.9
                    let from = k == 0 ? xs[2] : xs[order[k - 1]]
                    hx = from + (xs[order[k]] - from) * min(1, f / 0.45)
                    hdown = f > 0.5 && f < 0.8
                    if hdown { lit = order[k]; num = k + 1 }
                    showHand = true
                    c.text("2. tap them back", cx, dy + dh - 8, 13, Col(0xfff2a0), 0, FONTB)
                }
                for j in 0..<4 { miniBox(c, xs[j], cy - 14, j == lit, false, j == lit ? "\(num)" : "") }
                if showHand { hand(c, hx, cy + 4, hdown) }
            }
        case .hold:
            let s = (u / 2.6).truncatingRemainder(dividingBy: 1)
            let bx = cx - 110
            miniBar(c, bx, cy - 26, 220, 0.72, 0.22)
            let holding = s > 0.1 && s < 0.62
            let fill = clampD((s - 0.1) / 0.52, 0, 1) * 0.72
            if fill > 0.04 { c.RR(bx, cy - 23, 220 * fill, 8, 4, Col(0xff9a3a, 0.95)) }
            c.RR(bx + 220 * fill - 2.5, cy - 31, 5, 24, 2.5, WHITE)
            hand(c, cx - 30, cy + 2, holding, hold: true)
            if holding { c.text("hold...", cx + 40, cy + 14, 15, Col(0xfff2a0), 0, FONTB) }
            if s >= 0.62 && s < 0.95 { c.text("let go!", cx + 40, cy + 14, 15, Col(0x9ff0aa), 0, FONTB) }
        case .steer:
            let s = (u / 2.6).truncatingRemainder(dividingBy: 1)
            let shx = cx + sin((s - 0.3) * PI * 2) * 80
            let ry = dy + 8 + s * (dh - 16)
            if p.theme == "storm" {
                c.RR(px + 24, ry - 4, max(8, cx + 50 - px - 24), 8, 4, Col(0xffffff, 0.85))
                c.RR(cx + 110, ry - 4, max(8, px + pw - 24 - cx - 110), 8, 4, Col(0xffffff, 0.85))
            } else {
                c.poly(Col(0x6a7078), [cx - 22, ry + 8, cx - 6, ry - 10, cx + 6, ry - 3, cx + 14, ry - 12, cx + 24, ry + 8])
            }
            let sy = cy + 4
            c.poly(Col(0x8a5a2c), [shx, sy - 14, shx + 7, sy - 2, shx + 6, sy + 10, shx - 6, sy + 10, shx - 7, sy - 2])
            c.poly(Col(0xf2e6c8), [shx, sy - 7, shx + 4, sy + 5, shx - 4, sy + 5])
            c.seg(cx - 100, cy + 30, cx + 100, cy + 30, 1.4, Col(0xffe08a, 0.6))
            c.poly(Col(0xffe08a, 0.8), [cx - 108, cy + 30, cx - 98, cy + 25, cx - 98, cy + 35])
            c.poly(Col(0xffe08a, 0.8), [cx + 108, cy + 30, cx + 98, cy + 25, cx + 98, cy + 35])
            hand(c, shx, cy + 24, true, hold: true)
        case .swipe:
            let n = Int(u / 1.8) % 2
            let s = (u / 1.8).truncatingRemainder(dividingBy: 1)
            let ux: Double = n == 0 ? 1 : 0, uy: Double = n == 0 ? 0 : -1
            let ax = cx - 90, ay = cy
            c.circ(ax, ay, 26, Col(0x1c1108, 0.9)); c.circStroke(ax, ay, 26, 1.6, Col(0xd2a455))
            let shape: [(Double, Double)] = [(-14, -5), (1, -5), (1, -13), (16, 0), (1, 13), (1, 5), (-14, 5)]
            var pts: [Double] = []
            for q in shape { pts.append(ax + q.0 * ux - q.1 * uy); pts.append(ay + q.0 * uy + q.1 * ux) }
            c.poly(Col(0xffe08a), pts)
            let k = clampD((s - 0.2) / 0.4, 0, 1)
            let x0 = cx + 30 - ux * 10, y0 = cy - 6 + (n == 0 ? 0 : 26)
            let hx = x0 + ux * 90 * k, hy = y0 + uy * 56 * k
            let moving = s > 0.15 && s < 0.65
            if moving { c.seg(x0, y0, hx, hy, 5, Col(0xffe08a, 0.5)) }
            hand(c, hx, hy, moving, hold: true)
        case .beat:
            let s = u.truncatingRemainder(dividingBy: 1)
            let bxx = cx - 60
            c.circ(bxx, cy - 6, 24, Col(0x1c1108, 0.9))
            c.circStroke(bxx, cy - 6, 16, 2.6, Col(0xffe08a))
            c.circStroke(bxx, cy - 6, 16 + (1 - s) * 30, 2.2, Col(0xffffff, 0.4 + 0.6 * s))
            let hit = s > 0.9 || s < 0.1
            if hit { c.circ(bxx, cy - 6, 16, Col(0xfff2a0, 0.7)) }
            hand(c, bxx, cy + 6, hit)
            let beat = Int(u) % 4
            for j in 0..<4 {
                c.circ(cx + 20 + Double(j) * 26, cy - 6, j == beat && hit ? 9 : 6, j <= beat ? Col(0x7fd88a) : Col(0x0c0805, 0.7))
            }
            c.text("tap . tap . tap . tap", cx + 60, cy + 24, 13, Col(0xfff2a0), 0, FONTB)
        case .reel:
            let s = (u / 4).truncatingRemainder(dividingBy: 1)
            let running = s > 0.5 && s < 0.78
            var strain = 0.0
            if s <= 0.5 { strain = s / 0.5 * 0.62 } else if running { strain = 0.62 - (s - 0.5) / 0.28 * 0.5 } else { strain = 0.12 + (s - 0.78) / 0.22 * 0.3 }
            let bx = cx - 110
            c.RR(bx, cy - 28, 220, 14, 7, Col(0x2a1a0c))
            var col = Col(0x7fd88a)
            if strain > 0.5 { col = Col(0xffb040) }
            c.RR(bx + 2, cy - 25, 216 * strain, 8, 4, col)
            c.R(bx + 220 * 0.8, cy - 30, 2, 18, Col(0xff5a3c))
            c.RRStroke(bx, cy - 28, 220, 14, 7, running ? 2.6 : 1.2, running ? Col(0xff5a3c) : Col(0xd2a455, 0.8))
            let tapping = !running && Int(u * 12) % 2 == 0
            hand(c, cx - 30, cy + 2, tapping)
            c.text(running ? "red: stop and wait" : "tap tap tap", cx + 50, cy + 14, 14, running ? Col(0xff9a8a) : Col(0xfff2a0), 0, FONTB)
        }
        _ = c.para(howText(p), W / 2, dy + dh + 20, pw - 36, 14, CREAM, 0, FONT)
        let pulse = 0.65 + 0.35 * sin(T * 5)
        c.text("Tap anywhere to start", W / 2, py + ph - 12, 16, Col(0xffe08a, pulse), 0, FONTB)
    }

    func drawPlay(_ c: Canvas) {
        drawPlayBody(c)
        guard let p = play else { return }
        drawHelpButton(c, p)
        if p.intro { drawPlayIntro(c, p) }
    }

    /// The "?" beside the title strip, to see the how-to card again.
    func drawHelpButton(_ c: Canvas, _ p: Play) {
        if p.intro || p.endT >= 0 { return }
        let (hx, hy) = helpSpot()
        if hx + 16 > W - safeR { return }
        c.circ(hx, hy, 15, Col(0x1c1108, 0.88)); c.circStroke(hx, hy, 15, 1.6, Col(0xd2a455))
        c.text("?", hx, hy + 6, 18, Col(0xffe08a), 0, FONTB)
    }
}
