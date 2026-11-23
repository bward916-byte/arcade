import CoreGraphics
import Foundation

// The tavern: a lamplit room with a fire, a bar, and the three people worth talking to.

extension Game {
    /// A standing figure. `hat`: 0 bandana, 1 hood, 2 tricorn, 3 bare head with an apron.
    func person(_ c: Canvas, _ x: Double, _ fy: Double, _ s: Double, coat: Col, hat: Int, phase: Double, armUp: Double = 0) {
        let br = sin(T * 1.8 + phase) * 1.2 * s
        let skin = Col(0xe3b58a)
        c.ell(x, fy + 2 * s, 20 * s, 4.5 * s, Col(0x000000, 0.3))
        // legs and boots
        c.R(x - 8 * s, fy - 36 * s, 7 * s, 34 * s, Col(0x2a2018))
        c.R(x + 1 * s, fy - 36 * s, 7 * s, 34 * s, Col(0x2a2018))
        c.RR(x - 10 * s, fy - 8 * s, 10 * s, 9 * s, 2 * s, Col(0x140c06))
        c.RR(x + 0 * s, fy - 8 * s, 11 * s, 9 * s, 2 * s, Col(0x140c06))
        // body
        c.RRGrad(x - 12 * s, fy - 78 * s + br, 24 * s, 46 * s, 7 * s, [(0, coat), (1, coat.shade(0.62))])
        c.R(x - 12 * s, fy - 44 * s + br, 24 * s, 4 * s, Col(0x1c1108))
        c.RR(x - 2.5 * s, fy - 44.5 * s + br, 5 * s, 5 * s, 1, Col(0xd9a441))
        if hat == 3 { c.RR(x - 9 * s, fy - 62 * s + br, 18 * s, 34 * s, 3 * s, Col(0xe8dfc8)) }
        // arms: one hangs, one lifts a mug or a hand
        c.seg(x - 12 * s, fy - 72 * s + br, x - 17 * s, fy - 46 * s + br, 6 * s, coat.shade(0.85))
        c.circ(x - 17 * s, fy - 44 * s + br, 3.4 * s, skin)
        let hx = x + (17 + 5 * armUp) * s, hy = fy - (46 + 26 * armUp) * s + br
        c.seg(x + 12 * s, fy - 72 * s + br, hx, hy, 6 * s, coat.shade(0.85))
        c.circ(hx, hy - 2 * s, 3.4 * s, skin)
        if armUp > 0.3 {
            c.RR(hx - 4 * s, hy - 13 * s, 9 * s, 10 * s, 1.5 * s, Col(0x8a6a44))
            c.R(hx - 4 * s, hy - 13 * s, 9 * s, 2.5 * s, Col(0xf7f0dc))
        }
        // head
        c.R(x - 3 * s, fy - 84 * s + br, 6 * s, 8 * s, skin.shade(0.85))
        c.circ(x, fy - 91 * s + br, 10 * s, skin)
        c.circ(x - 3.5 * s, fy - 92 * s + br, 1.2 * s, Col(0x1c1108)); c.circ(x + 3.5 * s, fy - 92 * s + br, 1.2 * s, Col(0x1c1108))
        c.arcStroke(x, fy - 88.5 * s + br, 3.6 * s, 0.25, PI - 0.25, 1.1 * s, Col(0x6b3a22))
        switch hat {
        case 0:
            c.arcFill(x, fy - 93 * s + br, 10.4 * s, PI, PI * 2, REDC)
            c.poly(REDC, [x - 10 * s, fy - 94 * s + br, x - 19 * s, fy - 88 * s + br, x - 11 * s, fy - 90 * s + br])
        case 1:
            c.arcFill(x, fy - 90 * s + br, 13 * s, PI * 0.95, PI * 2.05, Col(0x2a2a34))
            c.R(x - 13 * s, fy - 91 * s + br, 4 * s, 16 * s, Col(0x2a2a34)); c.R(x + 9 * s, fy - 91 * s + br, 4 * s, 16 * s, Col(0x2a2a34))
            c.R(x - 9 * s, fy - 98 * s + br, 18 * s, 6 * s, Col(0x000000, 0.45))
        case 2:
            c.poly(Col(0x1c1410), [x - 17 * s, fy - 97 * s + br, x, fy - 110 * s + br, x + 17 * s, fy - 97 * s + br, x + 10 * s, fy - 95 * s + br, x - 10 * s, fy - 95 * s + br])
            c.R(x - 14 * s, fy - 98.5 * s + br, 28 * s, 1.6 * s, Col(0xd9a441))
        default:
            c.arcFill(x, fy - 94 * s + br, 10 * s, PI * 1.05, PI * 1.95, Col(0x5a3a1c))
            c.arcStroke(x, fy - 86 * s + br, 5.5 * s, 0.1, PI - 0.1, 2.4 * s, Col(0x5a3a1c))
        }
    }

    func drawTavern(_ c: Canvas) {
        let floorY = H * 0.6
        let flick = 0.82 + 0.1 * sin(T * 9) + 0.08 * sin(T * 23.7)
        // back wall of dark boards, lit warm from the fire on the right
        c.vfill(0, 0, W, floorY, [(0, Col(0x1a0f08)), (1, Col(0x3a2414))])
        var bx = 0.0
        var bi = 0
        while bx < W {
            let bw = 38 + hashN(Double(bi) * 3.7) * 20
            c.R(bx, 0, 1.4, floorY, Col(0x0e0704, 0.7))
            c.R(bx + 2, 0, bw - 3, floorY, Col(0xffffff, 0.012 + 0.02 * hashN(Double(bi) * 1.3)))
            bx += bw
            bi += 1
        }
        c.glow(W * 0.88, floorY - 40, W * 0.5, Col(0xff8a30, 0.3 * flick), Col(0xff8a30, 0))
        // ceiling beams
        c.R(0, 30, W, 12, Col(0x140b05))
        for i in 0..<5 { c.R(W * (0.1 + Double(i) * 0.2) - 7, 30, 14, floorY - 30, Col(0x1c1009)); c.R(W * (0.1 + Double(i) * 0.2) - 7, 30, 3, floorY - 30, Col(0xffffff, 0.04)) }
        // a window on the harbour
        let L = light()
        let wx0 = W * 0.03 + safeL, wy0 = 62.0, ww = 86.0, wh = 70.0
        c.RR(wx0 - 5, wy0 - 5, ww + 10, wh + 10, 4, Col(0x140b05))
        c.vfill(wx0, wy0, ww, wh, [(0, L.top), (0.62, L.bot), (0.63, L.sea1), (1, L.sea2)])
        if L.night > 0.3 { c.circ(wx0 + ww * 0.7, wy0 + 16, 7, Col(0xeef3ff, L.night)) } else { c.circ(wx0 + ww * 0.3, wy0 + 20, 8, Col(0xfff6d0)) }
        // a mast tip rocking past the glass
        let mxp = wx0 + ww * 0.5 + sin(T * 0.8) * 6
        c.seg(mxp, wy0 + wh * 0.62, mxp + sin(T * 0.8) * 3, wy0 + 12, 2, Col(0x1c1108))
        c.poly(REDC, [mxp + sin(T * 0.8) * 3, wy0 + 12, mxp + 14, wy0 + 16 + sin(T * 5) * 2, mxp + sin(T * 0.8) * 3, wy0 + 20])
        if wxRain > 0.1 { for i in 0..<10 { let ry = (hashN(Double(i) * 3.1) * wh + T * 90).truncatingRemainder(dividingBy: wh); c.seg(wx0 + hashN(Double(i) * 7.3) * ww, wy0 + ry, wx0 + hashN(Double(i) * 7.3) * ww - 2, wy0 + ry + 7, 1, Col(0xd6e6ff, 0.5)) } }
        c.R(wx0 + ww / 2 - 1.5, wy0, 3, wh, Col(0x140b05)); c.R(wx0, wy0 + wh / 2 - 1.5, ww, 3, Col(0x140b05))
        // the bar along the back wall: shelves of bottles, kegs, the barkeep
        let barX = W * 0.3, barW = W * 0.38, barY = floorY - 46
        for sh in 0..<2 {
            let sy = 74 + Double(sh) * 34
            c.R(barX + 10, sy + 22, barW - 20, 4, Col(0x140b05))
            for b in 0..<11 {
                let bxp = barX + 20 + Double(b) * (barW - 40) / 10
                let hh = 14 + hashN(Double(b * 3 + sh * 17)) * 9
                let bc = [Col(0x3f7a3c), Col(0x8a3b2e), Col(0xb47a16), Col(0x2f5f8f), Col(0x6b4a26)][(b + sh * 2) % 5]
                c.RR(bxp - 3.5, sy + 22 - hh, 7, hh, 2, bc.shade(0.9))
                c.R(bxp - 1.3, sy + 18 - hh, 2.6, 5, bc.shade(0.7))
                c.R(bxp - 2.4, sy + 23 - hh, 1.3, hh - 5, Col(0xffffff, 0.3 * flick))
            }
        }
        person(c, barX + barW * 0.5, barY + 30, 0.92, coat: Col(0x5a3a2a), hat: 3, phase: 0.3, armUp: 0.2 + 0.2 * sin(T * 2.2))
        c.RRGrad(barX, barY, barW, 50, 4, [(0, Col(0x7a5230)), (0.12, Col(0x5a3a1c)), (1, Col(0x2c1a0c))])
        c.R(barX - 4, barY - 4, barW + 8, 7, Col(0x8a6238))
        c.R(barX - 4, barY - 4, barW + 8, 2, Col(0xffffff, 0.12))
        for i in 0..<6 { c.R(barX + 12 + Double(i) * (barW - 24) / 5 - 1, barY + 6, 2, 44, Col(0x1c1009)) }
        for i in 0..<3 {
            let mx = barX + barW * (0.14 + Double(i) * 0.3)
            c.RR(mx - 5, barY - 16, 10, 12, 2, Col(0x8a6a44)); c.R(mx - 5, barY - 16, 10, 3, Col(0xf7f0dc)); c.arcStroke(mx + 6, barY - 10, 3.5, -PI / 2, PI / 2, 1.5, Col(0x8a6a44))
        }
        // kegs stacked at the end of the bar
        for i in 0..<3 {
            let kx = barX - 34 + (i == 2 ? 17.0 : Double(i) * 34), ky = i == 2 ? floorY - 66 : floorY - 28
            c.ell(kx, ky, 17, 20, Col(0x6b4423)); c.ellStroke(kx, ky, 17, 20, 2, Col(0x2a1a0c))
            c.ellStroke(kx, ky, 11, 13, 1.2, Col(0x3a2412)); c.circ(kx, ky, 2.2, Col(0x1c1108))
        }
        // the hearth
        let fx = W * 0.88 - safeR * 0.5, fw = 104.0
        c.RR(fx - fw / 2 - 12, floorY - 132, fw + 24, 134, 6, Col(0x4a4640))
        for i in 0..<14 { c.RRStroke(fx - fw / 2 - 12 + Double(i % 4) * 32 - (i / 4 % 2 == 0 ? 0 : 16), floorY - 132 + Double(i / 4) * 34, 32, 34, 2, 1, Col(0x2a2622)) }
        c.R(fx - fw / 2 - 18, floorY - 140, fw + 36, 10, Col(0x3a2412))
        c.arch(fx - fw / 2, floorY - 84, fw, 84, Col(0x0a0604))
        c.glow(fx, floorY - 26, 120, Col(0xffa040, 0.55 * flick), Col(0xffa040, 0))
        c.RR(fx - 34, floorY - 12, 68, 8, 3, Col(0x2a1a0c)); c.RR(fx - 26, floorY - 18, 54, 8, 3, Col(0x3a2412))
        for i in 0..<7 {
            let ph = T * (5 + Double(i) * 0.9) + Double(i) * 1.7
            let fh = 26 + 20 * (0.5 + 0.5 * sin(ph)) + (i % 2 == 0 ? 10 : 0)
            let fxx = fx - 26 + Double(i) * 8.6 + sin(ph * 0.7) * 3
            c.poly(Col(0xff7a20, 0.85), [fxx - 8, floorY - 14, fxx + sin(ph) * 5, floorY - 14 - fh, fxx + 8, floorY - 14])
            c.poly(Col(0xffd257, 0.9), [fxx - 4.5, floorY - 14, fxx + sin(ph * 1.3) * 3, floorY - 14 - fh * 0.58, fxx + 4.5, floorY - 14])
        }
        if chance(0.25) { puff(fx + rnd(-20, 20), floorY - 40, 1, Col(0xffc060), 30, -60, 1.6, 0.9) }
        // the floor
        c.vfill(0, floorY, W, H - floorY, [(0, Col(0x4a2f18)), (1, Col(0x1c1108))])
        for i in 0..<7 { c.R(0, floorY + Double(i * i) * 3.2 + 4, W, 1.2, Col(0x140b05, 0.6)) }
        for i in 0..<12 { c.seg(W / 2 + (Double(i) - 5.5) * 60, floorY, W / 2 + (Double(i) - 5.5) * 150, H, 1, Col(0x140b05, 0.45)) }
        c.glow(fx, floorY + 30, 190, Col(0xff8a30, 0.2 * flick), Col(0xff8a30, 0))
        // lanterns hanging from the beams
        for i in 0..<3 {
            let lx = W * (0.2 + Double(i) * 0.25), sway = sin(T * 1.1 + Double(i) * 2) * 0.06
            c.save()
            c.translate(lx, 42)
            c.rotate(sway)
            c.seg(0, 0, 0, 26, 1.2, Col(0x0a0604))
            c.glow(0, 36, 95, Col(0xffc060, 0.42 * flick), Col(0xffc060, 0))
            c.RR(-7, 26, 14, 20, 3, Col(0x23180c)); c.RR(-4.5, 29, 9, 14, 2, Col(0xffd98a, 0.95)); c.R(-8, 24, 16, 3, Col(0x140b05))
            c.restore()
        }
        // the people you came to see stand over their buttons
        let down = laidUp()
        let full = crew >= ship.crew
        let gap = 8.0
        let bw = (W - safeL - safeR - gap * 4) / 5
        let by = H - safeB - 52
        let fy = by - 10
        func cx(_ i: Int) -> Double { return safeL + Double(i) * (bw + gap) + bw / 2 }
        // a table and candle between them
        for i in [1, 3] {
            let tx = (cx(i) + cx(i - 1)) / 2
            c.ell(tx, fy - 34, 40, 9, Col(0x6b4423)); c.ell(tx, fy - 36, 40, 9, Col(0x8a6238)); c.R(tx - 3, fy - 32, 6, 30, Col(0x3a2412))
            c.R(tx - 1.5, fy - 48, 3, 10, Col(0xf7f0dc)); c.poly(Col(0xffd257), [tx - 2.5, fy - 48, tx + sin(T * 11) * 1.5, fy - 56 - flick * 3, tx + 2.5, fy - 48])
            c.glow(tx, fy - 52, 44, Col(0xffc060, 0.4 * flick), Col(0xffc060, 0))
        }
        if recruit != nil { person(c, cx(0), fy, 1.0, coat: Col(0x2f5f8f), hat: 0, phase: 0, armUp: 0.5 + 0.5 * sin(T * 1.3)) }
        person(c, cx(1), fy, 1.0, coat: Col(0x2a2a34), hat: 1, phase: 1.4)
        person(c, cx(2), fy, 1.0, coat: Col(0x6a2a2a), hat: 2, phase: 2.6)
        // the swordmaster, with his blade point-down in front of him
        person(c, cx(3), fy, 1.0, coat: Col(0x1f4a3a), hat: 0, phase: 3.9)
        c.seg(cx(3) + 20, fy - 46, cx(3) + 24, fy - 2, 2, Col(0xdfe6ea)); c.seg(cx(3) + 15, fy - 44, cx(3) + 25, fy - 46, 2.5, Col(0xd9a441))
        c.RR(W / 2 - 96, 44, 192, 26, 5, Col(0x2a1a0c, 0.92)); c.RRStroke(W / 2 - 96, 44, 192, 26, 5, 1.4, Col(0xd2a455))
        c.text(here.n + " Tavern", W / 2, 62, 16, GOLD, 0, FONTD)
        let rec = recruit
        let names: [(String, String, Bool)] = [
            (rec == nil ? "No one to hire" : "Hire " + (rec?.n ?? ""), rec == nil ? "come back next port" : (full ? "crew full" : roleName(rec?.sk ?? "").lowercased() + " · 40 gold"), rec == nil || full),
            ("Treasure map", hasMap ? "you have one" : "120 gold", hasMap),
            ("Surgeon", down > 0 ? "\(down) laid up · \(down * 20) gold" : "all hands well", down == 0),
            ("Swordmaster", perkRip && perkWind && perkFury ? "nothing left to teach" : "fighting lessons", perkRip && perkWind && perkFury),
            ("Leave", "back to the quay", false)
        ]
        for (i, nm) in names.enumerated() {
            btn(c, safeL + Double(i) * (bw + gap), by, bw, 46, nm.0, nm.1, gold: i == 4, off: nm.2) { [unowned self] in
                switch i {
                case 0: self.tavernHire()
                case 1: self.tavernMap()
                case 2: self.tavernSurgeon()
                case 3: self.tavernSword()
                default: self.mode = .port
                }
            }
        }
    }
}
