import CoreGraphics
import Foundation

// What the crew are doing on deck, and what the sea has to show, while the ship is under way.

extension Game {
    /// Which job the watch is at. Changes every few seconds; a gale puts everyone on the ropes.
    func deckAct() -> Int {
        if deckForce >= 0 { return deckForce }
        if rough > 0.6 { return 6 }
        if isNight { return Int(T / 12) % 2 == 0 ? 5 : 7 }
        return Int(T / 10 + Double(day) * 1.7) % 5
    }
    func seaAct() -> Int {
        if seaForce >= 0 { return seaForce }
        if weather >= 3 { return 7 }
        return Int(hashN(floor(T / 13) + Double(day) * 3.1) * 8)
    }
    func lifeCaption() -> String {
        let deck = ["The watch is swabbing the deck", "A hand goes aloft to check the rigging", "Someone has a line over the stern", "Gun drill: run out, fire, sponge", "The cook has the galley fire going", "A fiddle is out and the crew are dancing", "All hands hauling to shorten sail", "Lanterns lit. The night watch keeps quiet"][min(7, deckAct())]
        let sea = ["Dolphins off the bow", "A whale blows to starboard", "Flying fish skim the swell", "A sail on the horizon", "A fin is following the ship", "Driftwood from some wreck slides past", "An albatross rides the wind astern", ""][min(7, seaAct())]
        return sea.isEmpty ? deck : deck + "  ·  " + sea
    }

    private func hand(_ c: Canvas, _ x: Double, _ y: Double, _ col: Col, _ dark: Double, lean: Double = 0, hop: Double = 0) {
        c.save()
        c.translate(x, y - hop)
        c.rotate(lean)
        c.R(-2, -9, 4, 9, col.shade(dark))
        c.circ(0, -12, 2.6, Col(0xe3b58a).shade(dark))
        c.restore()
    }

    /// Drawn in the ship's own space: the deck runs along y = -33, bow to the right.
    func deckLife(_ c: Canvas, _ mx: [Double], _ dark: Double) {
        let coats = [Col(0x2f5f8f), Col(0x8c3b2e), Col(0xd9cdb0), Col(0x3a7a6d)]
        let act = deckAct()
        let m0 = mx[mx.count / 2]
        // the lookout aloft always has his glass out
        c.seg(m0 + 2, -30 - 168 * 0.66 - 5, m0 + 9, -30 - 168 * 0.66 - 7 + sin(T * 0.7) * 1.5, 1.4, Col(0xd9a441))
        switch act {
        case 0:
            // swabbing: two on their knees, brushes going, suds on the planks
            for i in 0..<2 {
                let x = -34 + Double(i) * 44 + sin(T * 0.5 + Double(i) * 3) * 10
                let st = sin(T * 6 + Double(i) * 2) * 3
                c.RR(x - 5, -38, 9, 5, 2, coats[i].shade(dark)); c.circ(x + 6, -40, 2.5, Col(0xe3b58a).shade(dark))
                c.seg(x + 5, -37, x + 11 + st, -33.5, 1.3, Col(0xe3b58a).shade(dark)); c.R(x + 10 + st, -34.5, 4, 2, Col(0x8a6a44))
                for b in 0..<4 { c.circ(x + 12 + Double(b) * 3 + st, -34.5 - hashN(Double(b) + floor(T * 3)) * 2, 1 + hashN(Double(b)) * 0.8, Col(0xffffff, 0.75)) }
            }
            hand(c, 40, -33, coats[2], dark); c.R(43, -37, 4, 4.5, Col(0x8a6a44))
        case 1:
            // one going up the weather shrouds, one waiting at the foot
            let f = 0.12 + 0.6 * (0.5 + 0.5 * sin(T * 0.45))
            let topY = -30 - 168.0 + 12
            let cxp = lerp(m0 - 24, m0 - 2, f), cyp = lerp(-34, topY, f)
            hand(c, cxp, cyp + 4, coats[0], dark, lean: 0.25)
            c.seg(cxp, cyp - 5, cxp + 4, cyp - 11 + sin(T * 5) * 2, 1.3, Col(0xe3b58a).shade(dark))
            hand(c, m0 - 30, -33, coats[1], dark); hand(c, 30, -33, coats[3], dark)
        case 2:
            // a line over the stern, and now and then a fish on it
            hand(c, -84, -52, coats[3], dark)
            c.seg(-86, -58, -118, -80, 1.2, Col(0x6b4a26))
            let bobY = 10 + sin(T * 2.2) * 2
            c.curve(-118, -80, -124, -30, -122, bobY, 0.6, Col(0xfff6d8, 0.8))
            c.circ(-122, bobY, 2, REDC)
            let ph = (T * 0.25).truncatingRemainder(dividingBy: 1)
            if ph < 0.18 {
                let k = ph / 0.18
                c.ell(-122, bobY - sin(k * PI) * 26, 6, 2.6, Col(0xbfd6e6)); c.poly(Col(0xbfd6e6), [-128, bobY - sin(k * PI) * 26, -133, bobY - sin(k * PI) * 26 - 3, -133, bobY - sin(k * PI) * 26 + 3])
                c.ellStroke(-122, 10, 4 + k * 10, 1.5 + k * 3, 0.8, Col(0xffffff, 0.6 * (1 - k)))
            }
            hand(c, -20, -33, coats[0], dark); hand(c, 22, -33, coats[1], dark)
        case 3:
            // gun drill: each gun fires in turn
            let cyc = T * 0.6
            let gi = Int(cyc) % 6
            let ph = cyc - floor(cyc)
            let gx = -50 + Double(gi) * 22 + 4
            if ph < 0.12 { c.glow(gx, -13.5, 26, Col(0xffd257, 0.9 * (1 - ph / 0.12)), Col(0xffd257, 0)) }
            if ph < 0.8 {
                for sm in 0..<5 { c.circ(gx + (Double(sm) - 2) * 5 * ph * 2, -10 + ph * 22 + hashN(Double(sm) + floor(cyc)) * 6, 3 + ph * 9, Col(0xf0f0f0, 0.55 * (1 - ph / 0.8))) }
            }
            for i in 0..<3 { hand(c, gx - 12 + Double(i) * 12, -33, coats[i], dark, lean: i == 1 ? 0.3 : 0, hop: ph < 0.1 ? 2 : 0) }
        case 4:
            // the galley stovepipe smoking amidships, a hand carrying the kid of stew aft
            c.R(14, -43, 4, 10, Col(0x2a2a30)); c.R(12.5, -44.5, 7, 2, Col(0x2a2a30))
            for sm in 0..<6 {
                let ph = (T * 0.4 + Double(sm) / 6).truncatingRemainder(dividingBy: 1)
                c.circ(16 - ph * 26 + sin(T * 2 + Double(sm)) * 2, -46 - ph * 34, 2 + ph * 6, Col(0xdcdcdc, 0.5 * (1 - ph)))
            }
            let wk = (T * 0.12).truncatingRemainder(dividingBy: 1)
            let hx = 10 - wk * 60
            hand(c, hx, -33, coats[2], dark); c.RR(hx - 7, -40, 5, 4, 1, Col(0x3a3a40)); c.circ(hx - 4.5, -42, 1.3, Col(0xffffff, 0.5))
            hand(c, 40, -33, coats[0], dark); hand(c, -44, -33, coats[1], dark)
        case 5:
            // a fiddler on the hatch, and the watch dancing to him
            hand(c, -30, -36, coats[1], dark)
            c.seg(-28, -44, -22, -47, 2, Col(0x8a4a1c)); c.seg(-30, -42 + sin(T * 12) * 1.5, -20, -48 + sin(T * 12) * 1.5, 0.7, Col(0xfff6d8))
            for i in 0..<4 { hand(c, -8 + Double(i) * 13, -33, coats[i], dark, lean: sin(T * 6 + Double(i)) * 0.25, hop: abs(sin(T * 6 + Double(i) * 1.3)) * 4) }
            for n in 0..<4 {
                let ph = (T * 0.5 + Double(n) * 0.25).truncatingRemainder(dividingBy: 1)
                let nx = -26 + ph * 30 + sin(T * 3 + Double(n)) * 4, ny = -52 - ph * 36
                c.circ(nx, ny, 1.8, Col(0xfff2c0, 1 - ph)); c.seg(nx + 1.6, ny, nx + 1.6, ny - 7, 0.9, Col(0xfff2c0, 1 - ph)); c.seg(nx + 1.6, ny - 7, nx + 5, ny - 5.5, 0.9, Col(0xfff2c0, 1 - ph))
            }
        case 6:
            // a gale: everyone on one rope, leaning back against it
            let heave = sin(T * 3.5) * 0.12
            c.seg(m0, -110, m0 - 22, -42, 1, Col(0xfff6d8, 0.8))
            for i in 0..<4 { hand(c, m0 - 22 - Double(i) * 8, -33, coats[i], dark, lean: -0.5 + heave) }
            c.seg(m0 - 22, -42, m0 - 50, -40, 1, Col(0xfff6d8, 0.8))
        default:
            // the night watch: a helmsman, a man forward, lanterns along the rail
            hand(c, -52, -33, coats[0], dark); hand(c, 50, -33, coats[2], dark)
            for i in 0..<4 {
                let lx = -44 + Double(i) * 32
                c.RR(lx - 1.5, -43, 3, 4.5, 1, Col(0xffd257)); c.glow(lx, -41, 20, Col(0xffc060, 0.55), Col(0xffc060, 0))
            }
        }
        if isNight && act != 7 {
            for i in 0..<2 { let lx = -40 + Double(i) * 70; c.RR(lx - 1.5, -43, 3, 4.5, 1, Col(0xffd257)); c.glow(lx, -41, 18, Col(0xffc060, 0.5), Col(0xffc060, 0)) }
        }
    }

    /// Far things, drawn before the ship: a whale, another sail, a rainbow after rain, a falling star.
    func seaLifeBack(_ c: Canvas, _ hz: Double, _ wy: Double) {
        let L = light()
        if rainbowT > 0 && L.night < 0.4 {
            let a = min(1, rainbowT / 3) * min(1, (16 - rainbowT) / 2 + 0.2) * 0.3
            let cols = [Col(0xff5a5a), Col(0xffa040), Col(0xffe060), Col(0x7fd88a), Col(0x6ab8ff), Col(0xa080e0)]
            for (i, col) in cols.enumerated() { c.arcStroke(W * 0.68, hz + 60, 250 - Double(i) * 6, PI, PI * 2, 6, col.alpha(a)) }
        }
        if L.night > 0.5 {
            let ph = (T / 6).truncatingRemainder(dividingBy: 1)
            if ph < 0.07 {
                let k = ph / 0.07, sx = hashN(floor(T / 6)) * W * 0.7 + W * 0.1, sy = hz * 0.15 + hashN(floor(T / 6) * 3) * hz * 0.3
                c.seg(sx + k * 120, sy + k * 40, sx + k * 120 - 46, sy + k * 40 - 15, 1.6, Col(0xffffff, 0.8 * (1 - k)))
            }
        }
        switch seaAct() {
        case 1:
            let wx = W * 0.8 + sin(T * 0.1) * 30, wyy = hz + 16
            c.ell(wx, wyy, 34, 7, Col(0x1f2c38))
            let ph = (T * 0.22).truncatingRemainder(dividingBy: 1)
            if ph < 0.35 {
                let k = ph / 0.35
                for j in 0..<6 { let a = -PI / 2 + (Double(j) - 2.5) * 0.16; c.seg(wx - 16, wyy - 4, wx - 16 + cos(a) * 30 * sin(k * PI), wyy - 4 + sin(a) * 34 * sin(k * PI), 1.6, Col(0xffffff, 0.75 * (1 - k))) }
            } else if ph > 0.6 && ph < 0.9 {
                let k = (ph - 0.6) / 0.3, up2 = sin(k * PI) * 20
                c.poly(Col(0x1f2c38), [wx + 34, wyy, wx + 40, wyy - up2, wx + 54, wyy - up2 - 7, wx + 46, wyy - up2 + 2, wx + 58, wyy - up2 + 5, wx + 42, wyy])
            }
        case 3:
            let sx = W * 0.95 - (T * 3).truncatingRemainder(dividingBy: W * 0.5)
            let dk = Col.mix(L.sea2, L.bot, 0.3)
            c.poly(dk, [sx - 12, hz + 1, sx + 12, hz + 1, sx + 8, hz + 4, sx - 9, hz + 4])
            c.poly(Col(0xf3ead2, 0.85 - L.night * 0.5), [sx - 6, hz, sx - 6, hz - 16, sx + 1, hz - 2]); c.poly(Col(0xf3ead2, 0.85 - L.night * 0.5), [sx + 2, hz, sx + 2, hz - 20, sx + 10, hz - 2])
        case 6:
            let bx = W * 0.2 + sin(T * 0.35) * W * 0.12, byy = hz * 0.42 + sin(T * 0.5) * 16, tilt = cos(T * 0.35) * 0.25
            c.save(); c.translate(bx, byy); c.rotate(tilt)
            c.curve(-26, -2, -12, -7, 0, 0, 2, Col(0xffffff, 0.95)); c.curve(0, 0, 12, -7, 26, -2, 2, Col(0xffffff, 0.95))
            c.ell(0, 0.5, 5, 2, Col(0xffffff)); c.poly(Col(0xffb040), [5, 0, 9, 1, 5, 1.6])
            c.restore()
        default:
            break
        }
    }

    /// Near things, drawn over the front swell.
    func seaLifeFront(_ c: Canvas, _ hz: Double, _ wy: Double) {
        let L = light()
        let dim = 1 - L.night * 0.5
        switch seaAct() {
        case 0:
            for i in 0..<3 {
                let ph = (T * 0.55 + Double(i) * 0.31).truncatingRemainder(dividingBy: 1)
                let dx = W * 0.64 + Double(i) * 38 + ph * 40, base = wy + 16 + Double(i) * 5
                if ph < 0.55 {
                    let k = ph / 0.55
                    let dy = base - sin(k * PI) * 34
                    c.save(); c.translate(dx, dy); c.rotate(-0.9 + k * 1.8)
                    c.ell(0, 0, 14, 4.5, Col(0x5a7a94).shade(dim)); c.ell(2, 1.5, 10, 2.4, Col(0xcfe0ea).shade(dim))
                    c.poly(Col(0x4a6a84).shade(dim), [-2, -4, 3, -10, 5, -4]); c.poly(Col(0x4a6a84).shade(dim), [-13, 0, -20, -5, -19, 5])
                    c.restore()
                }
                if ph < 0.08 || (ph > 0.5 && ph < 0.62) { c.ellStroke(dx, base, 10, 3, 1.2, Col(0xffffff, 0.7)); puffOnce(dx, base) }
            }
        case 2:
            for i in 0..<6 {
                let ph = (T * 0.8 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
                let fx = W * 0.05 + Double(i) * 30 + ph * W * 0.5, fy = wy + 24 + Double(i % 3) * 8 - sin(ph * PI) * 16
                c.ell(fx, fy, 6, 1.8, Col(0xdfeaf2).shade(dim))
                c.poly(Col(0xbfd6e6, 0.8), [fx - 1, fy, fx - 7, fy - 6 - sin(T * 30) * 2, fx + 3, fy - 1])
            }
        case 4:
            let fx = W * 0.2 + cos(T * 0.4) * 40, fy = wy + 26 + sin(T * 0.4) * 6
            c.poly(Col(0x3a4650).shade(dim), [fx - 9, fy, fx + 2, fy - 16, fx + 9, fy])
            c.ellStroke(fx, fy + 1, 14, 2.5, 1, Col(0xffffff, 0.45))
        case 5:
            let span = W + 160
            let dx = W + 80 - (T * 24).truncatingRemainder(dividingBy: span), dy = wy + 30 + sin(T * 1.6) * 3
            c.save(); c.translate(dx, dy); c.rotate(sin(T * 1.2) * 0.12)
            c.RR(-22, -3, 44, 6, 2, Col(0x6b4a26).shade(dim)); c.RR(-4, -9, 14, 7, 2, Col(0x8a6238).shade(dim)); c.R(-2, -9, 1.2, 7, Col(0x1c1108)); c.R(6, -9, 1.2, 7, Col(0x1c1108))
            c.restore()
            c.ellStroke(dx, dy + 3, 28, 3, 1, Col(0xffffff, 0.4))
        default:
            break
        }
        // the wake glows at night in warm seas
        if L.night > 0.5 && weather < 2 {
            let (sx, _, len) = shipSpot()
            for i in 0..<14 {
                let ph = (T * 0.5 + Double(i) / 14).truncatingRemainder(dividingBy: 1)
                c.circ(sx - len * 0.5 - ph * 120 + hashN(Double(i)) * 10, wy + 4 + hashN(Double(i) * 3) * 8, 1.6, Col(0x7fffe0, 0.7 * (1 - ph)))
            }
        }
    }
    private func puffOnce(_ x: Double, _ y: Double) {
        if card == nil && chance(0.2) { puff(x, y, 2, Col(0xffffff, 0.8), 70, 200, 1.8, 0.4) }
    }
}
