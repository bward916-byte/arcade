import CoreGraphics
import Foundation

// What the crew are doing on deck, and what the sea has to show, while the ship is under way.

extension Game {
    /// Which job the watch is at. Changes every few seconds; a gale puts everyone on the ropes.
    func deckAct() -> Int {
        if deckForce >= 0 { return deckForce }
        if rough > 0.6 { return 6 }
        // the watch is never at the same job for more than two days running
        let order = [0, 26, 13, 8, 16, 1, 25, 20, 9, 17, 2, 22, 27, 10, 14, 3, 18, 26, 11, 24, 4, 25, 15, 12, 21, 5, 27, 19, 23]
        return order[((cal / 2) * 7 + leg * 5) % order.count]
    }
    func seaAct() -> Int {
        if seaForce >= 0 { return seaForce }
        if weather >= 3 { return 7 }
        return Int(hashN(floor(T / 13) + Double(day) * 3.1) * 8)
    }
    func lifeCaption() -> String {
        let names: [Int: String] = [
            0: "The watch is swabbing the deck", 1: "A hand goes aloft to check the rigging", 2: "Someone has a line over the stern",
            3: "Gun drill: run out, fire, sponge", 4: "The cook has the galley fire going", 5: "A fiddle is out and the crew are dancing",
            6: "All hands hauling to shorten sail", 7: "Lanterns lit. The night watch keeps quiet", 8: "The sailmaker is patching a torn course",
            9: "The carpenter is sawing a new plank", 10: "The mate shoots the noon sun", 11: "Cutlass drill on the main deck",
            12: "A halyard chanty: haul, and haul again", 13: "Fresh tar on the rail, and on the men doing it", 14: "Holystones: on your knees and scrub",
            15: "Splicing and knotting on the forehatch", 16: "A cask is swayed up out of the hold", 17: "The goat is milked and the hens are fed",
            18: "Wash day: every shirt aboard is on the line", 19: "The lookout is relieved at the masthead", 20: "Captain's inspection. Stand straight",
            21: "The surgeon is shaving all comers", 22: "An old hand is spinning a yarn", 23: "Tug of war: larboard watch against starboard",
            24: "The leadsman is sounding: by the deep, nine", 25: "Two hands are slung over the side, scraping the hull",
            26: "Skylarking: the watch is swinging from the yards", 27: "Legs over the side, and one hanging from the bowsprit"
        ]
        let deck = names[deckAct()] ?? "The watch is at work"
        let sea = ["Dolphins off the bow", "A whale blows to starboard", "Flying fish skim the swell", "A sail on the horizon", "A fin is following the ship", "Driftwood from some wreck slides past", "An albatross rides the wind astern", ""][min(7, seaAct())]
        return sea.isEmpty ? deck : deck + "  ·  " + sea
    }

    private func hand(_ c: Canvas, _ x: Double, _ y: Double, _ col: Col, _ dark: Double, lean: Double = 0, hop: Double = 0) {
        tar(c, x, y, col, dark, lean: lean, hop: hop)
    }

    /// A sailor seen close: legs that walk, arms that can be put anywhere, a kerchief on his head.
    /// Arm angles run from straight down (0) round toward the bow (positive) or the stern (negative).
    func tar(_ c: Canvas, _ x: Double, _ y: Double, _ col: Col, _ dark: Double, lean: Double = 0, hop: Double = 0, walk: Double? = nil, aL: Double? = nil, aR: Double? = nil, hurt: Bool = false, kneel: Bool = false) {
        let skin = Col(0xe3b58a).shade(dark)
        let leg = Col(0x2b2a33).shade(dark)
        let body = col.shade(dark)
        // his shadow on the planks
        if abs(lean) < 1 { c.ell(x, y + 0.4, 3.6, 0.9, Col(0x000000, 0.22)) }
        c.save()
        c.translate(x, y - hop)
        c.rotate(lean)
        c.roundCaps(true)
        let hipY: Double = kneel ? -3.0 : -5.5
        var lf = -1.4, rf = 1.4, lfy = 0.0, rfy = 0.0
        if let w = walk {
            let sw = sin(w)
            lf = -sw * 2.6; rf = sw * 2.6
            lfy = -max(0, cos(w)) * 1.2; rfy = -max(0, -cos(w)) * 1.2
        }
        if kneel {
            c.seg(0, hipY, 2.4, -0.7, 1.8, leg); c.seg(2.4, -0.7, -1.0, -0.4, 1.6, leg)
            c.seg(0, hipY, -2.2, -0.6, 1.8, leg)
        } else {
            c.seg(-0.6, hipY, lf, lfy - 0.6, 1.8, leg)
            c.seg(lf - 0.4, lfy - 0.3, lf + 1.2, lfy - 0.3, 1.2, Col(0x140c06))
            if hurt {
                // the bad leg, held up off the deck
                c.seg(0.6, hipY, 2.8, -3.8, 1.8, leg); c.seg(2.8, -3.8, 1.2, -1.8, 1.6, leg)
            } else {
                c.seg(0.6, hipY, rf, rfy - 0.6, 1.8, leg)
                c.seg(rf - 0.4, rfy - 0.3, rf + 1.2, rfy - 0.3, 1.2, Col(0x140c06))
            }
        }
        let shY = hipY - 5.0
        c.seg(0, hipY - 0.4, 0, shY + 0.8, 4.0, body)
        c.seg(-1.5, hipY, 1.5, hipY, 1.3, Col(0x8a1a1a).shade(dark))
        let sway = sin(T * 2 + x) * 0.12
        var a0 = -0.2 + sway, a1 = 0.2 + sway
        if let w = walk { a0 = sin(w) * 0.7; a1 = -sin(w) * 0.7 }
        if let v = aL { a0 = v }
        if let v = aR { a1 = v }
        c.seg(-1.2, shY + 1.2, -1.2 + sin(a0) * 4.6, shY + 1.2 + cos(a0) * 4.6, 1.4, skin)
        c.seg(1.2, shY + 1.2, 1.2 + sin(a1) * 4.6, shY + 1.2 + cos(a1) * 4.6, 1.4, skin)
        // a striped shirt for some, a neckerchief for all, and a face looking where he leans
        let whoK: Double = abs(col.r * 7 + col.b * 13)
        let who = Int(whoK.rounded()) % 3
        if who == 0 { c.seg(-1.7, shY + 2.4, 1.7, shY + 2.4, 0.7, Col(0xffffff, 0.55)); c.seg(-1.7, shY + 3.9, 1.7, shY + 3.9, 0.7, Col(0xffffff, 0.55)) }
        c.seg(-1.3, shY + 0.9, 1.3, shY + 0.9, 1.0, Col(0xd8432f).shade(dark))
        c.circ(0, shY - 2.0, 2.4, skin)
        let leftArm: Double = aL ?? 0
        let face: Double = (lean < -0.05 || leftArm < -1.2) ? -1 : 1
        c.circ(face * 1.0, shY - 2.2, 0.42, Col(0x1a1008)); c.seg(face * 2.2, shY - 1.6, face * 2.9, shY - 1.3, 0.7, skin)
        c.seg(face * 0.6, shY - 0.9, face * 1.5, shY - 0.9, 0.4, Col(0x7a3a2a))
        let kc = Col.mix(col, Col(0x8a1a1a), 0.6).shade(dark)
        if who == 2 {
            // a straw hat
            c.seg(-3.4, shY - 3.6, 3.4, shY - 3.6, 0.9, Col(0xd8b860).shade(dark)); c.arcFill(0, shY - 3.6, 2.2, PI, PI * 2, Col(0xd8b860).shade(dark))
        } else {
            c.arcFill(0, shY - 2.2, 2.5, PI, PI * 2, kc)
            c.seg(-face * 2.3, shY - 2.6, -face * 3.6, shY - 1.2 + sin(T * 5 + x) * 0.5, 0.8, kc)
        }
        c.roundCaps(false)
        c.restore()
    }

    /// The people who are always there whatever the watch is doing: the man at the wheel, the captain on
    /// his quarterdeck with his glass, and the ship's cat going where she pleases.
    func deckRegulars(_ c: Canvas, _ dark: Double, wheel: Bool) {
        if wheel {
            c.seg(-58, -52, -58, -58, 1.2, Col(0x3b2412))
            c.save(); c.translate(-58, -58); c.rotate(sin(T * 0.8) * 0.5)
            c.circStroke(0, 0, 4.5, 1, Col(0x6b4423)); for j in 0..<6 { let a = Double(j) * PI / 3; c.seg(0, 0, cos(a) * 6, sin(a) * 6, 0.7, Col(0x6b4423)) }
            c.restore()
            tar(c, -62, -52, Col(0x5a4a3a), dark, lean: 0.05, aL: 1.3 + sin(T * 0.8) * 0.2, aR: 1.5 - sin(T * 0.8) * 0.2)
        }
        // the captain: a turn up and down, then a long look through the glass
        let ph = (T * 0.06).truncatingRemainder(dividingBy: 1)
        let cxp: Double = ph < 0.6 ? -76 + abs(sin(ph / 0.6 * PI * 2)) * 9 : -70
        let looking = ph >= 0.6
        let cw: Double? = looking ? nil : T * 5
        let ca: Double = looking ? 0.3 : -0.5, cb: Double = looking ? 1.9 : 0.5
        tar(c, cxp, -52, Col(0x1c2a4a), dark, walk: cw, aL: ca, aR: cb)
        c.poly(Col(0x10141c), [cxp - 3.6, -65.9, cxp + 3.6, -65.9, cxp, -69.5]); c.seg(cxp - 3.6, -65.9, cxp + 3.6, -65.9, 0.7, Col(0xd9a441))
        if looking { c.seg(cxp + 2, -63.2, cxp + 8, -64.2 + sin(T * 0.7) * 0.6, 1.3, Col(0xd9a441)) }
        // the cat
        let ct = T * 0.13
        let sit = sin(ct * 2.3) > 0.55
        let kx = sin(ct) * 46 + 6, kd: Double = cos(ct) >= 0 ? 1 : -1
        let fur = Col(0x2a2622).shade(dark)
        if sit {
            c.ell(kx, -35, 1.9, 2.3, fur); c.circ(kx + kd * 0.6, -38, 1.4, fur)
            c.poly(fur, [kx + kd * 0.6 - 1.2, -38.8, kx + kd * 0.6 - 0.9, -40.4, kx + kd * 0.6 - 0.2, -39]); c.poly(fur, [kx + kd * 0.6 + 1.2, -38.8, kx + kd * 0.6 + 0.9, -40.4, kx + kd * 0.6 + 0.2, -39])
            c.curve(kx - kd * 1.6, -33.6, kx - kd * 4, -33.2, kx - kd * 4.4, -35 + sin(T * 3) * 0.8, 0.7, fur)
        } else {
            let st = sin(T * 10)
            c.ell(kx, -35.4, 3.2, 1.5, fur); c.circ(kx + kd * 3.4, -36.4, 1.3, fur)
            c.poly(fur, [kx + kd * 3.0, -37.2, kx + kd * 3.2, -38.8, kx + kd * 3.8, -37.4])
            c.seg(kx - 2, -34.4, kx - 2 + st * 0.9, -33, 0.7, fur); c.seg(kx + 2, -34.4, kx + 2 - st * 0.9, -33, 0.7, fur)
            c.curve(kx - kd * 3, -35.6, kx - kd * 5.5, -38, kx - kd * 5, -40 + st * 0.4, 0.7, fur)
        }
        c.circ(kx + kd * (sit ? 1.1 : 3.9), sit ? -38.2 : -36.6, 0.3, Col(0xc8e060))
    }

    /// Whatever has been left lying about the deck. It stays where it is for two or three days, then
    /// something else turns up somewhere else.
    func deckClutter(_ c: Canvas, _ dark: Double) {
        let block = Double(cal / 3)
        let kind = Int(hashN(block * 7.31 + 2) * 10)
        let x = -44 + hashN(block * 3.17) * 80
        let dk = -33.0
        let wood = Col(0x6b4a26).shade(dark)
        switch kind {
        case 2:
            // the cook's slops, waiting to go over the side, and what they attract
            c.pathFill(Col(0x5a5038).shade(dark)) { p in
                p.move(to: CGPoint(x: x - 8, y: dk)); p.addQuadCurve(to: CGPoint(x: x + 8, y: dk), control: CGPoint(x: x, y: dk - 9)); p.closeSubpath()
            }
            c.circ(x - 3, dk - 2, 1.4, Col(0xc8763a)); c.seg(x + 1, dk - 4, x + 5, dk - 1.5, 0.8, Col(0xe8e0cc)); c.circ(x + 3, dk - 1, 1.1, Col(0x7fae4a))
            for j in 0..<5 { c.circ(x + sin(T * 5 + Double(j) * 2) * 8, dk - 8 + cos(T * 6.3 + Double(j)) * 4, 0.5, Col(0x140c06)) }
            let peck = max(0, sin(T * 3))
            c.ell(x + 13, dk - 3, 3.4, 2.2, WHITE.shade(dark)); c.circ(x + 10.5 - peck, dk - 4.5 + peck * 2, 1.4, WHITE.shade(dark)); c.seg(x + 9.5 - peck, dk - 4.2 + peck * 2, x + 7.5 - peck, dk - 3.5 + peck * 2.5, 0.8, Col(0xffb040))
        case 3:
            c.RR(x - 9, dk - 8, 9, 8, 1, wood); c.RR(x + 1, dk - 8, 9, 8, 1, wood.shade(0.9)); c.RR(x - 4, dk - 16, 9, 8, 1, wood.shade(1.1))
            c.seg(x - 9, dk - 8, x, dk, 0.6, Col(0x2a1a0c)); c.seg(x + 1, dk - 8, x + 10, dk, 0.6, Col(0x2a1a0c)); c.seg(x - 4, dk - 16, x + 5, dk - 8, 0.6, Col(0x2a1a0c))
        case 4:
            // washing strung along the rail, flapping
            c.curve(x - 22, dk - 13, x, dk - 10, x + 22, dk - 13, 0.6, Col(0xfff6d8))
            for j in 0..<5 {
                let lx = x - 18 + Double(j) * 9, fl = sin(T * 4 + Double(j)) * 1.2
                let col = [Col(0xf3ead2), Col(0x8c3b2e), Col(0x2f5f8f), Col(0xf3ead2), Col(0xd9cdb0)][j].shade(dark)
                c.poly(col, [lx - 2.5, dk - 12, lx + 2.5, dk - 12, lx + 2.5 + fl, dk - 5, lx - 2.5 + fl, dk - 5])
            }
        case 5:
            for j in 0..<4 { c.ellStroke(x, dk - 1 - Double(j) * 1.4, 7 - Double(j) * 0.8, 1.6, 1.3, Col(0xc9b48a).shade(dark)) }
            c.poly(wood, [x + 10, dk, x + 11, dk - 6, x + 17, dk - 6, x + 18, dk]); c.arcStroke(x + 14, dk - 6, 3.5, PI, PI * 2, 0.7, Col(0x2a2a30))
        case 6:
            // the catch split and hung to dry
            c.seg(x - 16, dk - 14, x + 16, dk - 14, 0.6, Col(0xfff6d8)); c.seg(x - 16, dk - 14, x - 16, dk, 0.9, Col(0x3b2412)); c.seg(x + 16, dk - 14, x + 16, dk, 0.9, Col(0x3b2412))
            for j in 0..<5 { let fx = x - 12 + Double(j) * 6, sw = sin(T * 2 + Double(j)) * 0.6; c.ell(fx + sw, dk - 10, 1.4, 3.6, Col(0xbfd6e6).shade(dark)); c.poly(Col(0x9ab6c6).shade(dark), [fx + sw, dk - 6.5, fx - 2 + sw, dk - 4.5, fx + 2 + sw, dk - 4.5]) }
        case 7:
            // a hen coop, and the hen
            c.RR(x - 8, dk - 8, 16, 8, 1, wood); for j in 0..<5 { c.seg(x - 6 + Double(j) * 3, dk - 8, x - 6 + Double(j) * 3, dk, 0.6, Col(0x2a1a0c)) }
            let hx = x + 14 + sin(T * 0.8) * 4, pk = max(0, sin(T * 5))
            c.ell(hx, dk - 3, 3, 2.4, Col(0xc8763a).shade(dark)); c.circ(hx + 2.6, dk - 5 + pk * 2, 1.3, Col(0xc8763a).shade(dark)); c.poly(REDC, [hx + 2.2, dk - 6.3 + pk * 2, hx + 3.2, dk - 7.4 + pk * 2, hx + 3.6, dk - 6.2 + pk * 2])
        case 8:
            // a burst cask and its apples all over the planks
            c.save(); c.translate(x, dk - 4); c.rotate(PI / 2)
            c.RR(-4, -6, 8, 12, 2.5, wood); c.R(-4, -2, 8, 1, Col(0x2a1a0c)); c.R(-4, 2, 8, 1, Col(0x2a1a0c))
            c.restore()
            for j in 0..<6 { c.circ(x + 9 + Double(j) * 3.4 + hashN(Double(j)) * 2, dk - 1.3, 1.3, j % 2 == 0 ? Col(0xd8432f) : Col(0x9fce5a)) }
        default:
            break
        }
    }

    /// An event played out on the deck, in the ship's own space. It runs from the first cry until the
    /// card has been answered, so whoever is hurt is still hopping about behind the question.
    func deckScene(_ c: Canvas, _ mx: [Double], _ dark: Double) -> Bool {
        let coats = [Col(0x2f5f8f), Col(0x8c3b2e), Col(0xd9cdb0), Col(0x3a7a6d)]
        let st = sceneT
        let m0 = mx[mx.count / 2]
        let dk = -33.0
        // a mate who runs in from along the deck and then stands by
        func runner(_ i: Int, _ from: Double, _ to: Double, _ t0: Double, _ t1: Double, kneel: Bool = false, aL: Double? = nil, aR: Double? = nil) {
            let k = clampD((st - t0) / (t1 - t0), 0, 1)
            let x = lerp(from, to, k)
            if k < 1 { tar(c, x, dk, coats[i % 4], dark, lean: to > from ? 0.15 : -0.15, walk: st * 13) } else { tar(c, x, dk, coats[i % 4], dark, aL: aL, aR: aR, kneel: kneel) }
        }
        // a man with a bucket, to and fro between the water and where it is wanted
        func bucket(_ i: Int, _ from: Double, _ to: Double, _ rate: Double) -> (Double, Double) {
            let ph = (st * rate + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
            let k = ph < 0.6 ? ph / 0.6 : 1 - (ph - 0.6) / 0.4
            let x = lerp(from, to, k)
            let fwd: Double = (to > from) == (ph < 0.6) ? 1 : -1
            tar(c, x, dk, coats[i % 4], dark, lean: fwd * 0.15, walk: st * 13, aL: fwd * 1.1, aR: fwd * 1.1)
            c.RR(x + fwd * 4.2 - 1.6, dk - 8.5, 3.2, 3.2, 0.6, Col(0x6b4a26).shade(dark))
            return (x, ph)
        }
        switch sceneK {
        case "fall":
            // the frayed footrope he was standing on
            c.seg(m0 - 26, -112, m0 - 20 + sin(T * 3) * 2, -100, 0.7, Col(0xfff6d8, 0.8))
            let fx = m0 - 20
            if st < 0.3 {
                tar(c, fx, -110, coats[0], dark, lean: sin(st * 30) * 0.3, aL: -2.8, aR: 2.8)
            } else if st < 0.9 {
                let k = (st - 0.3) / 0.6
                let f0: Double = -2.6 + sin(st * 40) * 0.5, f1: Double = 2.6 + sin(st * 37) * 0.5
                tar(c, fx - k * 6, lerp(-110, dk, k * k), coats[0], dark, lean: k * 5.2, aL: f0, aR: f1)
            } else if st < 1.7 {
                let k = (st - 0.9) / 0.8
                for j in 0..<5 { c.circ(fx - 6 + (Double(j) - 2) * 4 * (0.4 + k), dk - 1 - k * 3, 1.5 + k * 2.5, Col(0xe8dcc0, 0.6 * (1 - k))) }
                tar(c, fx - 6, dk - 1.6, coats[0], dark, lean: -PI / 2, aL: -0.4, aR: 0.6)
            } else {
                // up, and hopping on the good leg with the other held clear of the deck
                let hp = abs(sin(st * 7.5))
                let hx: Double = fx - 6 + sin(st * 1.3) * 5, wave: Double = -2.3 + sin(st * 9) * 0.5
                tar(c, hx, dk, coats[0], dark, lean: sin(st * 7.5) * 0.12, hop: hp * 3.6, aL: wave, aR: 0.9, hurt: true)
                for j in 0..<3 {
                    let a = st * 3 + Double(j) * 2.1, r = 5.5 + sin(st * 11 + Double(j)) * 1.2
                    let px = fx - 6 + sin(st * 1.3) * 5 + cos(a) * r, py = dk - 19 - hp * 3.6 + sin(a) * 2.2
                    c.seg(px - 1.3, py, px + 1.3, py, 0.7, Col(0xffe060)); c.seg(px, py - 1.3, px, py + 1.3, 0.7, Col(0xffe060))
                }
            }
            runner(1, -70, fx - 22, 0.9, 1.9, aR: 1.3)
            runner(2, 72, fx + 12, 1.0, 2.1, aL: -1.3)
            runner(3, 40, fx + 24, 1.4, 2.6)
        case "sick":
            let sx = 14.0
            if st < 0.9 {
                tar(c, sx, dk, coats[2], dark, lean: sin(st * 5) * 0.22, aL: -2.7)
            } else {
                let k = clampD((st - 0.9) / 0.5, 0, 1)
                tar(c, sx + k * 3, dk - 1.6 * k, coats[2], dark, lean: k * k * PI / 2, aL: 0.3, aR: 0.5)
            }
            let fan: Double = 1.5 + sin(st * 7) * 0.5
            runner(0, -52, sx - 3, 1.0, 2.0, kneel: true, aR: fan)
            runner(1, 64, sx + 20, 1.2, 2.2, aL: -1.0)
            tar(c, -40, dk, coats[3], dark, aR: 1.2)
            if st > 2.2 {
                // sweat standing off him
                for j in 0..<3 {
                    let ph = (st * 0.8 + Double(j) / 3).truncatingRemainder(dividingBy: 1)
                    c.circ(sx + 9 + Double(j) * 2.5, dk - 4 - ph * 7, 0.8, Col(0xbfe6ff, 0.9 * (1 - ph)))
                }
            }
        case "brawl":
            let p = st * 4.2
            let pa = max(0, sin(p)), pb = max(0, sin(p + PI))
            let ax: Double = -5 + pa * 1.6 - pb * 1.4, al: Double = 0.12 + pa * 0.22 - pb * 0.3
            let bx2: Double = 7 - pb * 1.6 + pa * 1.4, bl: Double = -0.12 - pb * 0.22 + pa * 0.3
            let ah: Double = abs(sin(st * 7)) * 0.8, bh: Double = abs(sin(st * 7 + 1)) * 0.8
            let aArm: Double = 0.7 + pa * 0.95, bArm: Double = -0.7 - pb * 0.95
            tar(c, ax, dk, coats[0], dark, lean: al, hop: ah, aL: 1.1, aR: aArm)
            tar(c, bx2, dk, coats[1], dark, lean: bl, hop: bh, aL: bArm, aR: -1.1)
            if pa > 0.8 || pb > 0.8 {
                let bx: Double = pa > 0.8 ? 5 : -3
                for j in 0..<6 { let a = Double(j) * PI / 3 + st; c.seg(bx + cos(a) * 1.5, dk - 14 + sin(a) * 1.5, bx + cos(a) * 4.5, dk - 14 + sin(a) * 4.5, 0.8, Col(0xffe060)) }
            }
            for (j, wx) in [-36.0, -24.0, 26.0, 37.0].enumerated() {
                let jd = Double(j)
                let wh: Double = abs(sin(st * 6 + jd * 1.4)) * 2.6, w0: Double = -2.5 + sin(st * 8 + jd) * 0.3, w1: Double = 2.5 + sin(st * 9 + jd) * 0.3
                tar(c, wx, dk, coats[(j + 2) % 4], dark, hop: wh, aL: w0, aR: w1)
            }
        case "galley":
            // the stove on its side, and the deck round it alight
            c.R(12, dk - 6, 9, 6, Col(0x2a2a30)); c.R(19, dk - 14, 3, 9, Col(0x2a2a30))
            c.glow(16, dk - 8, 34, Col(0xff8a20, 0.55 + 0.15 * sin(T * 11)), Col(0xff8a20, 0))
            for sm in 0..<9 {
                let ph = (T * 0.45 + Double(sm) / 9).truncatingRemainder(dividingBy: 1)
                c.circ(16 - ph * 34 + sin(T * 2 + Double(sm)) * 3, dk - 12 - ph * 60, 3 + ph * 11, Col(0x3a3a3e, 0.55 * (1 - ph)))
            }
            for f in 0..<7 {
                let fx = 5 + Double(f) * 3.6
                let h: Double = 8 + 5 * sin(T * 9 + Double(f) * 1.7) + 3 * sin(T * 15 + Double(f))
                c.poly(Col(0xff6a18), [fx - 3, dk, fx + sin(T * 7 + Double(f)) * 2, dk - h, fx + 3, dk])
                c.poly(Col(0xffd257), [fx - 1.6, dk, fx + sin(T * 9 + Double(f)) * 1.2, dk - h * 0.55, fx + 1.6, dk])
            }
            for i in 0..<3 {
                let from: Double = i == 1 ? 66 : -62, to: Double = i == 1 ? 36 : -6
                let (bx, ph) = bucket(i, from, to, 0.42)
                if ph > 0.52 && ph < 0.68 {
                    let dir: Double = to > from ? 1 : -1
                    c.curve(bx + dir * 5, dk - 8, (bx + 16) / 2, dk - 20, 16, dk - 6, 1.5, Col(0x9fd8ff, 0.9))
                    for j in 0..<3 { c.circ(16 + (Double(j) - 1) * 3, dk - 8 - Double(j) * 2, 1.2, Col(0xffffff, 0.7)) }
                }
            }
        case "rats":
            for i in 0..<7 {
                let dirn: Double = i % 2 == 0 ? 1 : -1
                let ph = (st * 0.3 * (1 + Double(i) * 0.14) + hashN(Double(i) * 5.3)).truncatingRemainder(dividingBy: 1)
                let rx = -74 + 148 * (dirn > 0 ? ph : 1 - ph), ry = dk - 1.3 - abs(sin(st * 22 + Double(i))) * 0.6
                c.curve(rx - dirn * 2.4, ry, rx - dirn * 4.5, ry - 1.5, rx - dirn * 6.5, ry + 0.4, 0.6, Col(0x7a5a50))
                c.ell(rx, ry, 2.7, 1.4, Col(0x3a3430).shade(dark)); c.circ(rx + dirn * 2.6, ry - 0.2, 1.1, Col(0x3a3430).shade(dark))
                c.circ(rx + dirn * 2.4, ry - 1.3, 0.6, Col(0x9a7a70))
            }
            let cx = sin(st * 1.2) * 42, sw = sin(st * 9)
            let cd: Double = cos(st * 1.2) > 0 ? 1 : -1
            let ba: Double = cd * (1.0 + sw * 0.5)
            tar(c, cx, dk, coats[1], dark, lean: cd * 0.2, walk: st * 13, aL: ba, aR: ba)
            c.seg(cx + cd * 4, dk - 8, cx + cd * (9 + sw * 3), dk - 1.5, 0.9, Col(0x6b4a26)); c.R(cx + cd * (9 + sw * 3) - 2, dk - 2, 4, 2, Col(0xd9c07a))
            c.RR(42, dk - 8, 8, 8, 1.5, Col(0x6b4a26).shade(dark)); c.R(42, dk - 6, 8, 1, Col(0x2a1a0c)); c.R(42, dk - 3, 8, 1, Col(0x2a1a0c))
            tar(c, 46, dk - 8, coats[2], dark, hop: abs(sin(st * 9)) * 2.2, aL: -2.6, aR: 2.6)
        case "leak":
            c.RR(-22, dk - 2.5, 18, 2.5, 1, Col(0x1c1108))
            for j in 0..<12 {
                let ph = (st * 1.7 + Double(j) / 12).truncatingRemainder(dividingBy: 1)
                let px = -13 + (hashN(Double(j) * 3.3) - 0.5) * 16 * ph, py = dk - 3 - sin(ph * PI) * (16 + hashN(Double(j)) * 10)
                c.circ(px, py, 1.1 + ph * 1.2, Col(0xbfe6ff, 0.85 * (1 - ph * 0.7)))
            }
            // one on the pump, flat out
            let pm = sin(st * 10)
            c.R(13, dk - 9, 3, 9, Col(0x2a2a30)); c.seg(14.5, dk - 9, 8, dk - 10 + pm * 3.5, 1.2, Col(0x3b2412))
            tar(c, 4, dk, coats[0], dark, lean: 0.2 + pm * 0.12, aL: 1.3 - pm * 0.5, aR: 1.3 - pm * 0.5)
            c.curve(16, dk - 5, 22, dk - 6, 24, dk, 1.2, Col(0x9fd8ff, 0.8))
            for i in 1..<3 {
                let (bx, ph) = bucket(i, -22 - Double(i) * 6, 52, 0.38)
                if ph > 0.55 && ph < 0.7 { c.curve(bx + 5, dk - 8, bx + 14, dk - 14, bx + 18, dk + 6, 1.5, Col(0x9fd8ff, 0.9)) }
            }
        case "calm":
            tar(c, m0 + 6, dk, coats[0], dark, lean: -0.25, aL: 0.2, aR: 0.4, kneel: true)
            tar(c, -34, dk - 1.6, coats[1], dark, lean: -PI / 2, aL: 0.2, aR: 0.3)
            tar(c, 30, dk, coats[2], dark)
            for n in 0..<3 {
                let ph = (T * 0.4 + Double(n) / 3).truncatingRemainder(dividingBy: 1)
                let nx = 34 + ph * 14 + sin(T * 3 + Double(n)) * 3, ny = dk - 16 - ph * 26
                c.circ(nx, ny, 1.5, Col(0xfff2c0, 1 - ph)); c.seg(nx + 1.4, ny, nx + 1.4, ny - 6, 0.8, Col(0xfff2c0, 1 - ph))
            }
            tar(c, 52, dk, coats[3], dark, aR: 2.3 + sin(T * 7) * 0.5)
        case "spar":
            // the broken yard, hanging by one tackle and swinging; its sail in ribbons
            let sw = sin(T * 2.2) * 0.22
            let ax = m0 - 2.0, ay = -122.0
            let ex = ax - sin(0.9 + sw) * 46, ey = ay + cos(0.9 + sw) * 46
            c.seg(ax, ay - 14, ax, ay, 0.8, Col(0xfff6d8, 0.9))
            c.seg(ax, ay, ex, ey, 3.4, Col(0x3b2412).shade(dark))
            c.seg(ax, ay, ax + 10, ay - 5, 3.4, Col(0x3b2412).shade(dark))
            for j in 0..<4 { c.seg(ax + 10, ay - 5, ax + 12 + Double(j) * 1.5, ay - 9 + Double(j) * 2.5, 0.8, Col(0xd9c07a)) }
            for j in 0..<3 {
                let f = 0.3 + Double(j) * 0.28
                let rx = lerp(ax, ex, f), ry = lerp(ay, ey, f)
                let fl = sin(T * 6 + Double(j) * 1.7) * 6
                c.poly(Col(0xf3ead2, 0.92).shade(dark), [rx, ry, rx + 9 + fl, ry + 16, rx - 4 + fl * 0.6, ry + 24, rx - 6, ry + 6])
            }
            // two on the tackle, leaning back against it; one pointing; one running to help
            let heave = sin(T * 3.5) * 0.12
            c.seg(ex, ey, m0 - 34, dk - 9, 0.8, Col(0xfff6d8, 0.85))
            tar(c, m0 - 36, dk, coats[0], dark, lean: -0.45 + heave, aL: 1.4, aR: 1.4)
            tar(c, m0 - 45, dk, coats[1], dark, lean: -0.45 + heave, aL: 1.4, aR: 1.4)
            tar(c, m0 + 20, dk, coats[2], dark, aL: -2.7)
            runner(3, 72, m0 + 32, 0.4, 1.6, aL: -2.5, aR: 2.5)
        case "stowaway":
            // the cask he was in, on its side, and the boy held up by the collar
            c.RR(18, dk - 9, 12, 9, 2, Col(0x6b4a26).shade(dark)); c.R(18, dk - 7, 12, 1, Col(0x2a1a0c)); c.R(18, dk - 3, 12, 1, Col(0x2a1a0c))
            c.ell(30, dk - 4.5, 2, 4.5, Col(0x2a1a0c))
            let k = clampD(st / 1.2, 0, 1)
            let bx = lerp(26, 4, k)
            tar(c, bx + 6, dk, coats[0], dark, aL: -1.5, aR: 0.2)
            c.save()
            c.translate(bx, dk - 1.5 - abs(sin(st * 9)) * 1.2)
            c.scale(0.72, 0.72)
            let kick = sin(st * 11)
            tar(c, 0, 0, coats[2], dark, lean: kick * 0.15, walk: st * 16, aL: -2.2 + kick * 0.5, aR: 2.2 - kick * 0.5)
            c.restore()
            tar(c, -18, dk, coats[1], dark, aL: 0.9, aR: -0.9)
            runner(3, -66, -32, 0.3, 1.5)
            tar(c, 46, dk, coats[3], dark, aL: -1.1)
        case "catch":
            // it is over the rail and thrashing; nobody wants to be the one to grab it
            let fl = sin(st * 15), hp = abs(sin(st * 7.5)) * 3.2
            c.save()
            c.translate(0, dk - 3.5 - hp)
            c.rotate(fl * 0.35)
            c.ell(0, 0, 14, 4.6, Col(0x6a8496).shade(dark)); c.ell(1, 1.6, 11, 2.4, Col(0xdfeaf2).shade(dark))
            c.poly(Col(0x4a6478).shade(dark), [-13, 0, -21, -6 + fl * 2, -19, 0, -21, 6 + fl * 2])
            c.poly(Col(0x4a6478).shade(dark), [-2, -4, 3, -9, 6, -4])
            c.circ(10, -1, 1, Col(0x0c1014))
            c.restore()
            for j in 0..<6 {
                let ph = (st * 2 + Double(j) / 6).truncatingRemainder(dividingBy: 1)
                let a = -PI / 2 + (Double(j) - 2.5) * 0.4
                c.circ(cos(a) * 16 * ph, dk - 4 + sin(a) * 14 * ph + ph * ph * 8, 0.9, Col(0xbfe6ff, 0.9 * (1 - ph)))
            }
            tar(c, -24, dk, coats[0], dark, lean: -0.2, hop: abs(sin(st * 8)) * 2.5, aL: -2.5, aR: 2.5)
            tar(c, 24, dk, coats[1], dark, lean: 0.2, hop: abs(sin(st * 8 + 1.2)) * 2.5, aL: -2.5, aR: 2.5)
            tar(c, 16 + sin(st * 3) * 3, dk, coats[3], dark, lean: -0.5, aL: -1.4, aR: -1.4)
            c.seg(-84, -58, -118, -80, 1.2, Col(0x6b4a26)); tar(c, -84, -52, coats[2], dark, aL: -1.9)
        case "bottle":
            // two in the bows: one pointing, one fishing for it with the boathook
            tar(c, 62, dk, coats[0], dark, aR: 1.9 + sin(T * 5) * 0.15)
            let reach = sin(T * 2.4) * 3
            tar(c, 74, dk, coats[1], dark, lean: 0.35, aL: 1.2, aR: 1.5)
            c.seg(77, dk - 8, 104 + reach, dk + 22, 0.9, Col(0x6b4a26)); c.arcStroke(104 + reach, dk + 23.5, 1.6, 0, PI, 0.8, Col(0x2a2a30))
            tar(c, 30, dk, coats[2], dark, lean: 0.15, walk: T * 12)
        case "scurvy":
            // no strength in them: two slumped against the mast, one flat out, one trying to stand to his work
            tar(c, m0 - 8, dk, coats[0], dark, lean: 0.3, aL: 0.2, aR: 0.4, kneel: true)
            tar(c, m0 + 8, dk, coats[1], dark, lean: -0.3, aL: -0.3, aR: -0.1, kneel: true)
            tar(c, -40, dk - 1.6, coats[2], dark, lean: -PI / 2, aL: 0.3, aR: 0.4)
            let sag = 0.3 + sin(st * 1.5) * 0.12
            tar(c, 36, dk, coats[3], dark, lean: sag, aL: 0.5, aR: 0.9)
            c.seg(40, dk - 14, 44, dk, 0.8, Col(0x6b4a26))
            runner(0, -70, -30, 0.5, 1.8, kneel: true, aR: 1.3)
            c.RR(-27, dk - 4, 3, 3, 0.8, Col(0x8a6a44))
        case "foulwater":
            // a cask tipped at the rail, green water going over; nobody standing downwind of it
            c.save(); c.translate(30, dk - 7); c.rotate(0.9 + sin(st * 2) * 0.05)
            c.RR(-6, -5, 12, 10, 2.5, Col(0x6b4a26).shade(dark)); c.R(-6, -2.5, 12, 1, Col(0x2a1a0c)); c.R(-6, 1.5, 12, 1, Col(0x2a1a0c))
            c.restore()
            c.curve(36, dk - 5, 42, dk - 2, 43, dk + 16, 2.2, Col(0x7fae4a, 0.9))
            for j in 0..<5 { let ph = (st * 1.2 + Double(j) / 5).truncatingRemainder(dividingBy: 1); c.circ(43 + sin(Double(j) * 2) * 2, dk + 4 + ph * 16, 1.1, Col(0x9fce5a, 1 - ph)) }
            for j in 0..<4 { let ph = (st * 0.5 + Double(j) / 4).truncatingRemainder(dividingBy: 1); c.curve(26 + Double(j) * 3, dk - 14 - ph * 10, 28 + Double(j) * 3, dk - 18 - ph * 10, 26 + Double(j) * 3, dk - 22 - ph * 10, 0.8, Col(0x9fce5a, 0.7 * (1 - ph))) }
            tar(c, 22, dk, coats[0], dark, lean: 0.25, aL: 1.2, aR: 1.4)
            tar(c, 6, dk, coats[1], dark, lean: -0.25, aL: -0.2, aR: -2.9)
            tar(c, -12, dk, coats[2], dark, lean: -0.3, hop: abs(sin(st * 5)) * 1.2, aL: -2.9, aR: -0.4)
            c.RR(-38, dk - 9, 9, 9, 2, Col(0x6b4a26).shade(dark)); c.RR(-28, dk - 9, 9, 9, 2, Col(0x6b4a26).shade(dark))
        case "weevils":
            // the bread barrel open, and what is in it walking off across the deck
            c.RR(-6, dk - 10, 12, 10, 2, Col(0x6b4a26).shade(dark)); c.R(-6, dk - 7, 12, 1, Col(0x2a1a0c)); c.ell(0, dk - 10, 6, 1.6, Col(0xd9c07a))
            c.poly(Col(0xc9b48a).shade(dark), [14, dk, 17, dk - 9, 25, dk - 9, 28, dk])
            for j in 0..<14 {
                let ph = (st * 0.25 + hashN(Double(j) * 3.7)).truncatingRemainder(dividingBy: 1)
                let dirn: Double = j % 2 == 0 ? 1 : -1
                c.circ(dirn * (6 + ph * 40) + (j % 3 == 0 ? 20 : 0), dk - 0.8 - (j % 4 == 0 ? 6 * (1 - ph) : 0), 0.7, Col(0x1c1108))
            }
            let rap = abs(sin(st * 9))
            tar(c, -16, dk, coats[0], dark, lean: 0.2, aL: 0.8, aR: 1.5 - rap * 0.6)
            c.R(-11, dk - 12 + rap * 2, 3, 2, Col(0xd9c07a))
            tar(c, 34, dk, coats[1], dark, hop: abs(sin(st * 8)) * 2.4, aL: -1.0, aR: 1.0)
            tar(c, -40, dk, coats[2], dark, aL: -0.2, aR: -2.9)
        case "plank":
            // a plank run out over the taffrail; her crew walk it one by one, and yours cheer every splash
            c.R(-128, -53, 44, 1.8, Col(0xc9a070).shade(dark))
            for i in 0..<3 {
                let t0 = 0.4 + Double(i) * 1.15
                let k = (st - t0) / 1.0
                if k < 0 {
                    tar(c, -66 + Double(i) * 6, -52, Col(0x26262c), dark, aL: 0.1, aR: -0.1)
                } else if k < 1 {
                    tar(c, lerp(-66 + Double(i) * 6, -126, k), -53, Col(0x26262c), dark, lean: -0.08, walk: st * 9, aL: 0.1, aR: -0.1)
                } else {
                    let f = (st - t0 - 1.0) / 0.55
                    if f < 1 {
                        tar(c, -127 - f * 5, -53 + f * f * 62, Col(0x26262c), dark, lean: -f * 3.4, aL: -2.6, aR: 2.6)
                    } else {
                        let r = min(1, (f - 1) / 1.2)
                        c.ellStroke(-132, 10, 5 + r * 16, 1.5 + r * 4, 1, Col(0xffffff, 0.8 * (1 - r)))
                        for j in 0..<6 { let a = -PI / 2 + (Double(j) - 2.5) * 0.3; c.seg(-132, 8, -132 + cos(a) * 16 * sin(r * PI), 8 + sin(a) * 22 * sin(r * PI), 1, Col(0xffffff, 0.8 * (1 - r))) }
                    }
                }
            }
            // the bosun with a cutlass at their backs
            let prod = sin(st * 6)
            tar(c, -56, -52, coats[0], dark, lean: -0.15, aL: -1.4 - prod * 0.2, aR: 0.2)
            c.seg(-61, -62, -68 - prod * 2, -63, 0.9, Col(0xe6ecf0))
            // and the main deck gone mad
            for i in 0..<6 {
                let cxp = -30 + Double(i) * 16
                let id = Double(i)
                let hp: Double = abs(sin(st * 7 + id * 1.3)) * 3.2
                let w0: Double = -2.6 + sin(st * 9 + id) * 0.4, w1: Double = 2.6 + sin(st * 8 + id) * 0.4
                tar(c, cxp, dk, coats[i % 4], dark, hop: hp, aL: w0, aR: w1)
                // hats in the air
                let ph = (st * 0.9 + id * 0.23).truncatingRemainder(dividingBy: 1)
                c.arcFill(cxp + sin(id) * 4, dk - 20 - sin(ph * PI) * 16, 2.2, PI, PI * 2, coats[(i + 1) % 4].shade(dark))
            }
        case "stelmo":
            // cold fire on every masthead and yardarm; the watch struck dumb, faces turned up
            for (j, m) in mx.enumerated() {
                for (q, yy) in [-196.0, -150.0, -108.0].enumerated() {
                    for side in [-1.0, 0.0, 1.0] {
                        if q == 0 && side != 0 { continue }
                        let gxp = m + side * (30 - Double(q) * 4), fl = 0.6 + 0.4 * sin(T * 13 + Double(j) * 2 + Double(q) + side)
                        c.glow(gxp, yy, 14, Col(0x9fd8ff, 0.8 * fl), Col(0x6ab8ff, 0))
                        c.poly(Col(0xeaf6ff, 0.9 * fl), [gxp - 1.6, yy, gxp + sin(T * 9 + side) * 1.5, yy - 9 - fl * 4, gxp + 1.6, yy])
                    }
                }
            }
            tar(c, -40, dk, coats[0], dark, aL: -2.8, aR: 0.2)
            tar(c, -18, dk, coats[1], dark, aL: 0.3, aR: 0.4, kneel: true)
            tar(c, 10, dk, coats[2], dark, aL: -0.2, aR: 2.8)
            tar(c, 34, dk, coats[3], dark, aL: 0.3, aR: 0.4, kneel: true)
            tar(c, 56, dk, coats[0], dark, aL: -2.7, aR: 2.7)
        case "neptune":
            // King Neptune's court: a hand in a crown and a seaweed beard, and a greenhorn going into the tub
            c.RR(22, -41, 10, 8, 2, Col(0x6b4a26).shade(dark))
            let rule: Double = 2.3 + sin(st * 2) * 0.3
            tar(c, 27, -41, Col(0x3a7a6d), dark, aL: -0.4, aR: rule, kneel: true)
            c.poly(Col(0xffd257), [23.6, -53.4, 24.4, -56.4, 25.6, -54, 27, -57, 28.4, -54, 29.6, -56.4, 30.4, -53.4])
            for j in 0..<4 { c.seg(25 + Double(j) * 1.3, -49, 24.6 + Double(j) * 1.3 + sin(T * 3 + Double(j)) * 0.5, -44.5, 0.8, Col(0x4a9a5a)) }
            c.seg(32, -44, 34, -62, 0.9, Col(0xd9a441)); for j in -1...1 { c.seg(34 + Double(j) * 2, -62, 34 + Double(j) * 2.4, -66, 0.8, Col(0xd9a441)) }
            c.poly(Col(0x6b4a26).shade(dark), [-12, -33, -13, -40, 5, -40, 4, -33]); c.R(-13, -37.5, 18, 0.9, Col(0x2a1a0c)); c.ell(-4, -40, 9, 1.4, Col(0x9fd8ff))
            let dunk = (st * 0.55).truncatingRemainder(dividingBy: 1)
            let dy2 = dunk < 0.5 ? sin(dunk / 0.5 * PI) * 9 : 0
            tar(c, -4, -38 - dy2, coats[2], dark, lean: 0.2, hop: 0, aL: -2.6, aR: 2.6, kneel: true)
            if dunk > 0.5 && dunk < 0.8 { let k = (dunk - 0.5) / 0.3; for j in 0..<8 { let a = -PI / 2 + (Double(j) - 3.5) * 0.3; c.seg(-4, -40, -4 + cos(a) * 12 * sin(k * PI), -40 + sin(a) * 14 * sin(k * PI), 0.9, Col(0xbfe6ff, 0.9 * (1 - k))) } }
            tar(c, -16, -33, coats[1], dark, lean: 0.25, aL: 1.6, aR: 1.9)
            tar(c, 8, -33, coats[0], dark, lean: -0.25, aL: -1.9, aR: -1.6)
            for (j, wx) in [-40.0, -30.0, 44.0, 54.0].enumerated() {
                let jd = Double(j)
                let hp: Double = abs(sin(st * 7 + jd * 1.3)) * 2.6, w0: Double = -2.6 + sin(st * 9 + jd) * 0.3, w1: Double = 2.6 + sin(st * 8 + jd) * 0.3
                tar(c, wx, -33, coats[j % 4], dark, hop: hp, aL: w0, aR: w1)
            }
        case "albatross":
            // she comes down out of the sky onto the rail, shuffles, and looks the whole watch in the eye
            let land = clampD(st / 1.4, 0, 1)
            let ax = lerp(60, 14, land), ay = lerp(-110, -46, land * land)
            let flap = land < 1 ? sin(st * 9) * 9 : sin(st * 1.2) * 1.2
            c.ell(ax, ay, 6, 3, WHITE.shade(dark)); c.circ(ax + 6, ay - 2.4, 2.4, WHITE.shade(dark))
            c.poly(Col(0xffb040), [ax + 8, ay - 3, ax + 13, ay - 1.6, ax + 8, ay - 1.6]); c.circ(ax + 6.8, ay - 2.8, 0.45, Col(0x0c1014))
            if land < 1 {
                c.poly(Col(0xe6ecf0).shade(dark), [ax - 3, ay - 1, ax - 22, ay - 8 - flap, ax - 6, ay + 1]); c.poly(Col(0xe6ecf0).shade(dark), [ax + 1, ay - 1, ax + 4, ay - 16 - flap, ax + 5, ay])
                c.poly(Col(0x2a2a30), [ax - 22, ay - 8 - flap, ax - 28, ay - 9 - flap, ax - 20, ay - 5 - flap])
            } else {
                c.poly(Col(0x9aa6ac).shade(dark), [ax - 7, ay - 2, ax + 2, ay - 3 + flap * 0.3, ax - 2, ay + 2])
                c.seg(ax - 1, ay + 3, ax - 1, ay + 5.5, 0.8, Col(0xffb040)); c.seg(ax + 2, ay + 3, ax + 2, ay + 5.5, 0.8, Col(0xffb040))
            }
            tar(c, -4, -33, coats[0], dark, aL: -0.2, aR: 1.9)
            tar(c, -16, -33, coats[1], dark, lean: 0.1, aL: 0.3, aR: 0.4)
            tar(c, 34, -33, coats[2], dark, lean: -0.15, aL: -1.9, aR: 0.2)
            runner(3, -60, -28, 0.5, 1.8, aR: 2.2)
            tar(c, 46, -33, coats[3], dark, aL: -0.6, aR: -1.4); c.poly(Col(0xc98a3a), [40.5, -40, 43.5, -41, 43, -38.5])
        case "grumble":
            // a knot of hands by the mainmast, one up on a cask doing the talking
            c.RR(m0 + 8, -41, 9, 8, 2, Col(0x6b4a26).shade(dark))
            let fist: Double = -2.4 + sin(st * 7) * 0.5
            tar(c, m0 + 12.5, -41, coats[1], dark, lean: -0.15 + sin(st * 3.5) * 0.08, aL: fist, aR: -1.2)
            for (j, wx) in [-22.0, -12.0, -2.0, 26.0, 36.0].enumerated() {
                let jd = Double(j)
                let ang: Double = (wx < 12 ? 2.3 : -2.3) + sin(st * 6 + jd * 1.4) * 0.5
                let lft = wx < 12
                let gl: Double = lft ? 0.12 : -0.12, gh: Double = abs(sin(st * 5 + jd)) * 0.9
                let ga: Double = lft ? 0.3 : ang, gb: Double = lft ? ang : -0.3
                tar(c, m0 + wx, -33, coats[j % 4], dark, lean: gl, hop: gh, aL: ga, aR: gb)
            }
            for j in 0..<3 { let ph = (st * 0.9 + Double(j) / 3).truncatingRemainder(dividingBy: 1); c.text("!", m0 - 14 + Double(j) * 16, -52 - ph * 10, 7, Col(0xff6a4a, 1 - ph), 0, FONTB) }
        case "flotsam":
            // two in the bows with boathooks, a third heaving a line
            tar(c, 60, dk, coats[0], dark, aR: 1.9 + sin(T * 5) * 0.15)
            let reach = sin(T * 2.4) * 3
            tar(c, 74, dk, coats[1], dark, lean: 0.35, aL: 1.2, aR: 1.5)
            c.seg(77, dk - 8, 106 + reach, dk + 22, 0.9, Col(0x6b4a26)); c.arcStroke(106 + reach, dk + 23.5, 1.6, 0, PI, 0.8, Col(0x2a2a30))
            tar(c, 46, dk, coats[2], dark, lean: -0.3, aL: 1.4, aR: 1.4)
            c.curve(50, dk - 8, 80, dk - 20 + sin(T * 3) * 3, 112, dk + 20, 0.6, Col(0xfff6d8))
            runner(3, -40, 32, 0.4, 1.8, aR: 2.0)
        case "lightning":
            // the bolt has hit the maintop: fire in the rigging, burning canvas coming down
            let top = -30 - 168.0
            if st < 0.5 {
                var bx2 = m0, by2 = top - 90
                for j in 0..<7 { let nx = m0 + (hashN(Double(j) * 3.1) - 0.5) * 26 * (1 - Double(j) / 7), ny = top - 90 + Double(j + 1) * 13; c.seg(bx2, by2, nx, ny, 2.4, Col(0xffffff)); c.seg(bx2, by2, nx, ny, 6, Col(0xbfd8ff, 0.4)); bx2 = nx; by2 = ny }
                c.glow(m0, top, 90, Col(0xffffff, 0.9 * (1 - st / 0.5)), Col(0xffffff, 0))
            }
            for f in 0..<8 {
                let fx = m0 - 18 + Double(f) * 5
                let h: Double = 10 + 6 * sin(T * 9 + Double(f) * 1.7) + 3 * sin(T * 15 + Double(f))
                c.poly(Col(0xff6a18), [fx - 3.4, top + 34, fx + sin(T * 7 + Double(f)) * 2, top + 34 - h, fx + 3.4, top + 34])
                c.poly(Col(0xffd257), [fx - 1.8, top + 34, fx + sin(T * 9 + Double(f)) * 1.2, top + 34 - h * 0.55, fx + 1.8, top + 34])
            }
            c.glow(m0, top + 28, 60, Col(0xff8a20, 0.5 + 0.15 * sin(T * 11)), Col(0xff8a20, 0))
            for sm in 0..<9 { let ph = (T * 0.4 + Double(sm) / 9).truncatingRemainder(dividingBy: 1); c.circ(m0 - ph * 50 + sin(T * 2 + Double(sm)) * 4, top + 20 - ph * 70, 4 + ph * 13, Col(0x2a2a2e, 0.55 * (1 - ph))) }
            for j in 0..<6 { let ph = (T * 0.5 + Double(j) / 6).truncatingRemainder(dividingBy: 1); c.poly(Col(0xffb040, 1 - ph), [m0 - 14 + Double(j) * 6 + sin(T * 3 + Double(j)) * 4, top + 36 + ph * 150, m0 - 12 + Double(j) * 6, top + 39 + ph * 150, m0 - 15 + Double(j) * 6, top + 40 + ph * 150]) }
            runner(0, -60, m0 - 26, 0.3, 1.5, aL: -2.6, aR: 2.6)
            runner(1, 66, m0 + 22, 0.4, 1.7, aL: -2.6, aR: 2.6)
            let cl = clampD((st - 1.5) / 3, 0, 1)
            tar(c, lerp(m0 - 22, m0 - 6, cl), lerp(-34, top + 60, cl) + 5, coats[2], dark, lean: 0.25, walk: T * 8, aL: 2.4, aR: 2.8)
            tar(c, 30, -33, coats[3], dark, aL: -0.2, aR: 2.6)
        case "overboard":
            tar(c, -84, -52, coats[0], dark, aL: -1.9 + sin(T * 8) * 0.2)
            tar(c, -74, -52, coats[1], dark, aL: -2.4 + sin(T * 6) * 0.6, aR: -1.2)
            tar(c, -30, dk, coats[2], dark, lean: -0.15, walk: T * 13)
        default:
            return false
        }
        return true
    }

    /// Drawn in the ship's own space: the deck runs along y = -33, bow to the right.
    func deckLife(_ c: Canvas, _ mx: [Double], _ dark: Double) {
        let coats = [Col(0x2f5f8f), Col(0x8c3b2e), Col(0xd9cdb0), Col(0x3a7a6d)]
        let act = deckAct()
        let m0 = mx[mx.count / 2]
        // the lookout aloft always has his glass out
        c.seg(m0 + 2, -30 - 168 * 0.66 - 5, m0 + 9, -30 - 168 * 0.66 - 7 + sin(T * 0.7) * 1.5, 1.4, Col(0xd9a441))
        if mode == .sail { deckClutter(c, dark) }
        if mode == .sail && !["plank", "overboard", "catch"].contains(sceneK) { deckRegulars(c, dark, wheel: act != 10 || !sceneK.isEmpty) }
        if mode == .sail && !sceneK.isEmpty && deckScene(c, mx, dark) { return }
        switch act {
        case 0:
            // swabbing: two on their knees, brushes going, suds on the planks
            for i in 0..<2 {
                let x = -34 + Double(i) * 44 + sin(T * 0.5 + Double(i) * 3) * 10
                let st = sin(T * 6 + Double(i) * 2) * 3
                let scrub: Double = 1.1 + st * 0.12
                tar(c, x, -33, coats[i], dark, lean: 0.55, aL: scrub, aR: scrub, kneel: true)
                c.R(x + 9 + st, -34.5, 4.5, 2, Col(0x8a6a44))
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
        case 8:
            // the sailmaker and his mate, a torn course across their knees
            c.pathFill(Col(0xf3ead2).shade(dark)) { p in
                p.move(to: CGPoint(x: -22, y: -37)); p.addQuadCurve(to: CGPoint(x: 6, y: -36), control: CGPoint(x: -8, y: -41 + sin(T * 2) * 1))
                p.addLine(to: CGPoint(x: 10, y: -33)); p.addLine(to: CGPoint(x: -26, y: -33)); p.closeSubpath()
            }
            c.seg(-12, -36, -6, -34.5, 0.7, Col(0x8a1a1a)); c.seg(-9, -37, -3, -35, 0.7, Col(0x8a1a1a))
            let nd = sin(T * 4)
            tar(c, -26, -33, coats[2], dark, lean: 0.2, aL: 0.9, aR: 1.2 + nd * 0.5, kneel: true)
            tar(c, 12, -33, coats[1], dark, lean: -0.2, aL: -1.0, aR: -0.8, kneel: true)
            c.seg(-20 + nd * 2, -40 - nd * 2, -19 + nd * 2, -36, 0.5, Col(0xe6ecf0))
            tar(c, 44, -33, coats[0], dark, walk: T * 6)
        case 9:
            // the carpenter at his trestles, sawdust flying
            c.R(8, -40, 34, 2, Col(0xc9a070).shade(dark)); c.seg(12, -38, 10, -33, 1, Col(0x3b2412)); c.seg(38, -38, 40, -33, 1, Col(0x3b2412))
            let sw = sin(T * 7)
            tar(c, 20, -33, coats[3], dark, lean: 0.25, aL: 0.6, aR: 1.0 + sw * 0.35)
            c.poly(Col(0xc8c8cc).shade(dark), [25 + sw * 3, -44, 33 + sw * 3, -40, 33 + sw * 3, -37, 25 + sw * 3, -41])
            for j in 0..<5 { let ph = (T * 1.5 + Double(j) / 5).truncatingRemainder(dividingBy: 1); c.circ(30 + hashN(Double(j)) * 4, -38 + ph * 5, 0.7, Col(0xf0d8a0, 1 - ph)) }
            tar(c, 46, -33, coats[1], dark, aL: -1.2, aR: -1.0)
            c.R(-30, -36, 14, 1.5, Col(0xc9a070).shade(dark)); c.R(-28, -37.5, 14, 1.5, Col(0xb89060).shade(dark))
            tar(c, -44, -33, coats[0], dark)
        case 10:
            // noon: the mate with his sextant, the helmsman at the wheel, a boy with the slate
            let up2 = 0.5 + 0.5 * sin(T * 0.9)
            tar(c, -74, -52, coats[0], dark, aL: -0.3, aR: 2.0 + up2 * 0.5)
            c.poly(Col(0xd9a441), [-70, -66 - up2 * 2, -66, -68 - up2 * 2, -67, -64 - up2 * 2])
            c.save(); c.translate(-58, -58); c.rotate(sin(T * 0.8) * 0.5)
            c.circStroke(0, 0, 4.5, 1, Col(0x6b4423)); for j in 0..<6 { let a = Double(j) * PI / 3; c.seg(0, 0, cos(a) * 6, sin(a) * 6, 0.7, Col(0x6b4423)) }
            c.restore()
            tar(c, -62, -52, coats[1], dark, aL: 1.3, aR: 1.5)
            tar(c, -20, -33, coats[2], dark, aL: 1.2, aR: 0.8); c.R(-17, -42, 4, 3, Col(0x2a2a30))
            tar(c, 30, -33, coats[3], dark, walk: T * 6)
        case 11:
            // cutlass drill: two pairs, cut and guard, by the numbers
            for pr in 0..<2 {
                let bx = -30 + Double(pr) * 52
                let p = T * 3 + Double(pr) * 1.3
                let ca = max(0, sin(p)), cb = max(0, sin(p + PI))
                let a1: Double = 0.9 + ca * 0.9, a2: Double = -0.9 - cb * 0.9
                tar(c, bx - 6 + ca * 1.5, -33, coats[pr], dark, lean: 0.1 + ca * 0.15, aL: 0.4, aR: a1)
                tar(c, bx + 6 - cb * 1.5, -33, coats[pr + 2], dark, lean: -0.1 - cb * 0.15, aL: a2, aR: -0.4)
                c.seg(bx - 2 + ca * 3, -44 + ca * 2, bx + 3 + ca * 3, -48 + ca * 5, 0.8, Col(0xe6ecf0))
                c.seg(bx + 2 - cb * 3, -44 + cb * 2, bx - 3 - cb * 3, -48 + cb * 5, 0.8, Col(0xe6ecf0))
                if abs(sin(p)) > 0.95 { c.circ(bx, -45, 1.4, Col(0xffe060)) }
            }
        case 12:
            // four on the halyard, hands high, then down together
            let pull = max(0, sin(T * 2.6))
            c.seg(m0 - 3, -150, m0 - 12, -46 + pull * 4, 0.8, Col(0xfff6d8, 0.85))
            for i in 0..<4 {
                let hx = m0 - 12 - Double(i) * 7
                let arm: Double = 2.6 - pull * 1.6
                tar(c, hx, -33, coats[i], dark, lean: -0.1 - pull * 0.25, aL: arm, aR: arm, kneel: false)
            }
            c.seg(m0 - 12, -46 + pull * 4, m0 - 36, -41 + pull * 3, 0.8, Col(0xfff6d8, 0.85))
            tar(c, 40, -33, coats[1], dark, aL: -2.6 + sin(T * 2.6) * 0.3)
        case 13:
            // tarring the rail: two with brushes, the black creeping along behind them
            let prog = (T * 0.05).truncatingRemainder(dividingBy: 1)
            c.R(-50, -45.2, 100 * prog, 1.6, Col(0x16110c))
            for i in 0..<2 {
                let bxp = -50 + 100 * prog - Double(i) * 16, st = sin(T * 7 + Double(i) * 2)
                let ba: Double = 1.9 + st * 0.35
                tar(c, bxp - 4, -33, coats[i + 1], dark, lean: 0.15, aL: 0.5, aR: ba)
                c.seg(bxp + 0.5, -43.5 + st, bxp + 2.5, -45.5 + st, 1.4, Col(0x16110c))
                c.poly(Col(0x2a2a30), [bxp - 12, -33, bxp - 11, -37, bxp - 7, -37, bxp - 6, -33]); c.ell(bxp - 9, -37, 2, 0.6, Col(0x0c0906))
            }
            for j in 0..<4 { c.circ(-46 + Double(j) * 9, -33.3, 0.7, Col(0x16110c, 0.8)) }
            tar(c, 46, -33, coats[0], dark, aL: -0.3, aR: 1.4)
        case 14:
            // holystoning in a line, all together, the bosun pacing behind
            let push = sin(T * 3.2)
            for i in 0..<4 {
                let hx = -34 + Double(i) * 15 + push * 2.2
                let arm: Double = 1.25 + push * 0.2
                tar(c, hx, -33, coats[i], dark, lean: 0.6, aL: arm, aR: arm, kneel: true)
                c.RR(hx + 7 + push * 1.5, -34.8, 4, 2, 0.5, Col(0xd8d0c0).shade(dark))
                c.seg(hx + 5, -33.2, hx + 13, -33.2, 0.6, Col(0xffffff, 0.35))
            }
            let bx = -44 + (0.5 + 0.5 * sin(T * 0.5)) * 80
            tar(c, bx, -33, coats[1], dark, walk: T * 5, aL: 0.2, aR: 0.9)
            c.curve(bx + 3, -39, bx + 6, -36, bx + 4 + sin(T * 5), -33.5, 0.7, Col(0xc9b48a))
            c.poly(Col(0x6b4a26).shade(dark), [50, -33, 51, -39, 57, -39, 58, -33]); c.ell(54, -39, 3, 0.8, Col(0x9fd8ff))
        case 15:
            // rope work on the forehatch: a long splice, a turk's head, a coil going down
            c.RR(18, -36, 30, 3, 1, Col(0x3b2412).shade(dark))
            for j in 0..<4 { c.ellStroke(58, -34 - Double(j) * 1.3, 6 - Double(j) * 0.6, 1.5, 1.2, Col(0xc9b48a).shade(dark)) }
            let tw = sin(T * 5)
            tar(c, 24, -36, coats[0], dark, lean: 0.15, aL: 0.9, aR: 1.3 + tw * 0.3, kneel: true)
            tar(c, 42, -36, coats[2], dark, lean: -0.15, aL: -1.3 - tw * 0.3, aR: -0.9, kneel: true)
            c.curve(28, -42, 33, -39 + tw, 38, -42, 1.3, Col(0xc9b48a)); c.seg(30 + tw, -43, 31.5 + tw, -40.5, 0.6, Col(0xe6ecf0))
            c.curve(42, -40, 50, -36, 57, -37, 1.1, Col(0xc9b48a))
            tar(c, -20, -33, coats[3], dark, lean: 0.1, aL: 1.0, aR: 1.2)
            c.curve(-16, -41, -8, -45 + sin(T * 3) * 2, 0, -38, 1.0, Col(0xc9b48a)); c.circStroke(0, -37, 2, 1, Col(0xc9b48a))
        case 16:
            // swaying a cask up out of the hold on the stay tackle
            let up = 0.5 + 0.5 * sin(T * 0.9)
            let cy = lerp(-36, -74, up)
            c.RR(-22, -35.5, 24, 2.5, 1, Col(0x1c1108))
            c.seg(m0 - 2, -128, -10, cy - 8, 0.8, Col(0xfff6d8, 0.9)); c.circ(-10, cy - 8, 1.6, Col(0x3b2412))
            c.seg(-10, cy - 7, -14, cy - 2, 0.6, Col(0xfff6d8)); c.seg(-10, cy - 7, -6, cy - 2, 0.6, Col(0xfff6d8))
            c.save(); c.translate(-10, cy + 3); c.rotate(sin(T * 1.8) * 0.12)
            c.RR(-6, -6, 12, 12, 3, Col(0x8a6238).shade(dark)); c.R(-6, -3, 12, 1.2, Col(0x2a1a0c)); c.R(-6, 2, 12, 1.2, Col(0x2a1a0c))
            c.restore()
            c.seg(m0 - 2, -128, -40, -42 + up * 3, 0.8, Col(0xfff6d8, 0.9))
            let hv: Double = -0.35 - (1 - up) * 0.2 + sin(T * 5) * 0.04
            tar(c, -42, -33, coats[1], dark, lean: hv, aL: 1.5, aR: 1.5)
            tar(c, -51, -33, coats[3], dark, lean: hv, aL: 1.5, aR: 1.5)
            tar(c, 8, -33, coats[0], dark, aL: -2.2 - up * 0.4, aR: -1.6)
        case 17:
            // the goat milked, the hens fed
            let gx = 22.0
            c.seg(gx - 5, -37, gx - 5, -33, 1, WHITE.shade(dark)); c.seg(gx + 4, -37, gx + 4, -33, 1, WHITE.shade(dark)); c.seg(gx - 3, -37, gx - 3, -33, 1, Col(0xd8d0c0).shade(dark)); c.seg(gx + 6, -37, gx + 6, -33, 1, Col(0xd8d0c0).shade(dark))
            c.ell(gx, -39, 7, 3.2, WHITE.shade(dark)); c.circ(gx + 8, -42 + sin(T * 6) * 0.4, 2.2, WHITE.shade(dark))
            c.seg(gx + 8, -44, gx + 6.5, -46.5, 0.8, Col(0x8a7a5a)); c.seg(gx + 9, -44, gx + 10.5, -46.5, 0.8, Col(0x8a7a5a)); c.seg(gx + 9.5, -40.5, gx + 9.5, -38.5 + sin(T * 6) * 0.5, 0.7, WHITE.shade(dark)); c.circ(gx + 9, -42.5, 0.4, Col(0x1a1008))
            c.seg(gx - 7, -40, gx - 9, -42 + sin(T * 4), 0.8, WHITE.shade(dark))
            let mk = sin(T * 8)
            tar(c, gx - 4, -33, coats[2], dark, lean: 0.5, aL: 1.1 + mk * 0.2, aR: 1.1 - mk * 0.2, kneel: true)
            c.poly(Col(0x8a6a44).shade(dark), [gx + 0, -33, gx + 0.5, -36, gx + 4, -36, gx + 4.5, -33])
            let throwA: Double = 1.4 + sin(T * 2.5) * 0.6
            tar(c, -30, -33, coats[1], dark, aL: 0.4, aR: throwA)
            for j in 0..<6 { let ph = (T * 0.8 + Double(j) / 6).truncatingRemainder(dividingBy: 1); c.circ(-26 + ph * 14 + Double(j % 3), -40 + ph * ph * 7, 0.5, Col(0xe8c860, 1 - ph)) }
            for j in 0..<4 {
                let hx = -18 + Double(j) * 6 + sin(T * 0.7 + Double(j) * 2) * 3, pk = max(0, sin(T * 6 + Double(j) * 1.7))
                let hc = j % 2 == 0 ? Col(0xc8763a) : WHITE
                c.ell(hx, -35.4, 2.4, 1.9, hc.shade(dark)); c.circ(hx + 2, -37 + pk * 1.6, 1.1, hc.shade(dark)); c.poly(REDC, [hx + 1.7, -38 + pk * 1.6, hx + 2.4, -39 + pk * 1.6, hx + 2.8, -38 + pk * 1.6])
                c.seg(hx + 2.9, -36.8 + pk * 1.6, hx + 3.9, -36.5 + pk * 1.8, 0.6, Col(0xffb040))
            }
        case 18:
            // wash day: tubs and suds, and a line of shirts from mast to mast
            let m1 = mx[0], m2 = mx[mx.count - 1]
            c.curve(m1, -62, (m1 + m2) / 2, -56, m2, -62, 0.6, Col(0xfff6d8))
            for j in 0..<9 {
                let f = (Double(j) + 0.5) / 9
                let lx = lerp(m1, m2, f), ly = -62 + sin(f * PI) * 5.2, fl = sin(T * 4 + Double(j)) * 1.4
                let col = [Col(0xf3ead2), Col(0x8c3b2e), Col(0x2f5f8f), Col(0xf3ead2), Col(0xd9cdb0), Col(0x3a7a6d)][j % 6].shade(dark)
                c.poly(col, [lx - 3, ly, lx + 3, ly, lx + 3 + fl, ly + 8, lx - 3 + fl, ly + 8])
                if j % 2 == 0 { c.poly(col, [lx - 3, ly, lx - 5.5 + fl * 0.5, ly + 3.5, lx - 3, ly + 3]); c.poly(col, [lx + 3, ly, lx + 5.5 + fl * 0.5, ly + 3.5, lx + 3, ly + 3]) }
            }
            for i in 0..<2 {
                let tx = -28 + Double(i) * 34, sc = sin(T * 6 + Double(i) * 1.5)
                c.poly(Col(0x6b4a26).shade(dark), [tx - 6, -33, tx - 7, -39, tx + 7, -39, tx + 6, -33]); c.R(tx - 7, -37, 14, 0.8, Col(0x2a1a0c))
                for b in 0..<5 { c.circ(tx - 5 + Double(b) * 2.5, -39.6 - hashN(Double(b) + floor(T * 3) + Double(i)) * 1.8, 1.3, Col(0xffffff, 0.85)) }
                let arm: Double = 0.9 + sc * 0.25
                tar(c, tx - 9, -33, coats[i * 2], dark, lean: 0.35, aL: arm, aR: arm)
            }
            tar(c, 30, -33, coats[1], dark, aL: -2.7, aR: 2.7)
        case 19:
            // the lookout relieved: one going up, one coming down, the mate bawling at both
            let f = (T * 0.11).truncatingRemainder(dividingBy: 1)
            let topY = -30 - 168.0 + 14
            let ux = lerp(m0 - 24, m0 - 3, f), uy = lerp(-34, topY, f)
            tar(c, ux, uy + 5, coats[0], dark, lean: 0.25, walk: T * 8, aL: 2.4, aR: 2.8)
            let dx2 = lerp(m0 + 3, m0 + 24, f), dy2 = lerp(topY, -34, f)
            tar(c, dx2, dy2 + 5, coats[2], dark, lean: -0.25, walk: T * 8, aL: -2.8, aR: -2.4)
            tar(c, m0 - 34, -33, coats[1], dark, aL: -2.3, aR: 2.3)
            for j in 0..<3 { let ph = (T * 1.2 + Double(j) / 3).truncatingRemainder(dividingBy: 1); c.arcStroke(m0 - 34, -47, 3 + ph * 7, -PI * 0.75, -PI * 0.25, 0.7, Col(0xffffff, 0.7 * (1 - ph))) }
            tar(c, 36, -33, coats[3], dark, aL: -0.2, aR: 2.6)
        case 20:
            // inspection: toes on a seam, eyes front, the mate looking for something to dislike
            for i in 0..<6 {
                let fid: Double = i == 4 ? abs(sin(T * 5)) * 0.8 : 0
                let salute: Double = 2.4 + sin(T * 10) * 0.3
                let ra: Double = i == 4 ? salute : -0.02
                tar(c, -30 + Double(i) * 11, -33, coats[i % 4], dark, hop: fid, aL: 0.02, aR: ra)
            }
            c.seg(-36, -33.2, 32, -33.2, 0.5, Col(0x000000, 0.25))
            let ph = (T * 0.09).truncatingRemainder(dividingBy: 1)
            let step = floor(ph * 6) / 6 + min(1, (ph * 6).truncatingRemainder(dividingBy: 1) * 2.5) / 6
            let ix = -36 + step * 68
            let moving = (ph * 6).truncatingRemainder(dividingBy: 1) < 0.4
            let iw: Double? = moving ? T * 9 : nil
            let il: Double = moving ? 0.05 : 0.2, ia: Double = moving ? 0.3 : 1.6
            tar(c, ix, -30.5, Col(0x1c2a4a), dark, lean: il, walk: iw, aL: -0.9, aR: ia)
            c.poly(Col(0x10141c), [ix - 3.6, -44.4, ix + 3.6, -44.4, ix, -48])
        case 21:
            // the surgeon shaving all comers: one on the cask, lathered; two waiting, feeling their chins
            c.RR(-6, -41, 9, 8, 2, Col(0x6b4a26).shade(dark)); c.R(-6, -38, 9, 0.9, Col(0x2a1a0c))
            tar(c, -1.5, -41, coats[2], dark, lean: -0.12, aL: 0.4, aR: 0.6, kneel: true)
            c.arcFill(-1, -49.6, 2.4, 0, PI, Col(0xffffff)); c.poly(Col(0xf3ead2).shade(dark), [-5, -47, 2, -47, 4, -41, -7, -41])
            let rz = sin(T * 5)
            tar(c, 8, -33, coats[3], dark, lean: -0.2, aL: -1.9 - rz * 0.25, aR: -1.2)
            c.seg(2.5 - rz, -50 - rz, 4.5 - rz, -48 - rz, 0.9, Col(0xe6ecf0))
            c.poly(Col(0x8a6a44).shade(dark), [14, -33, 14.5, -37, 19, -37, 19.5, -33]); c.circ(16.5, -37.6, 1.6, WHITE)
            tar(c, -28, -33, coats[0], dark, aL: 0.2, aR: 2.5 + sin(T * 3) * 0.15)
            tar(c, -40, -33, coats[1], dark, lean: 0.1, aL: 0.3, aR: 0.4)
            for j in 0..<3 { let ph2 = (T * 0.6 + Double(j) / 3).truncatingRemainder(dividingBy: 1); c.circ(-3 + sin(T + Double(j)) * 3, -53 - ph2 * 8, 0.9, Col(0xffffff, 0.8 * (1 - ph2))) }
        case 22:
            // a yarn: the old hand on a cask with his arms going, the watch sat round him, pipe smoke
            c.RR(-4, -41, 9, 8, 2, Col(0x6b4a26).shade(dark))
            let g1: Double = -1.6 + sin(T * 2.2) * 0.9, g2: Double = 1.6 + sin(T * 2.7 + 1) * 0.9
            tar(c, 0.5, -41, coats[1], dark, lean: sin(T * 1.1) * 0.12, aL: g1, aR: g2, kneel: true)
            for (j, sx) in [-34.0, -22.0, 20.0, 31.0, 42.0].enumerated() {
                let lf = sx < 0
                let yl: Double = lf ? 0.2 : -0.2, ya: Double = lf ? 0.6 : -0.4, yb: Double = lf ? 0.4 : -0.6
                tar(c, sx, -33, coats[j % 4], dark, lean: yl, aL: ya, aR: yb, kneel: true)
            }
            c.seg(22.5, -43.2, 25, -43.6, 0.7, Col(0x3b2412)); c.circ(25.4, -44, 0.8, Col(0x3b2412))
            for j in 0..<4 { let ph = (T * 0.35 + Double(j) / 4).truncatingRemainder(dividingBy: 1); c.circ(26 + sin(T + Double(j)) * 2 + ph * 4, -46 - ph * 16, 1 + ph * 3, Col(0xe0e0e0, 0.5 * (1 - ph))) }
            if sin(T * 1.1) > 0.6 { c.textS("...", 6, -56, 7, Col(0xffffff, 0.9), 0, FONTB) }
        case 23:
            // tug of war across the waist
            let sh = sin(T * 0.8) * 7 + sin(T * 5) * 0.6
            c.seg(-46 + sh, -41, 46 + sh, -41, 1.1, Col(0xc9b48a))
            c.poly(REDC, [sh - 1.5, -41, sh + 1.5, -41, sh, -37]); c.R(-0.4, -36, 0.8, 3, Col(0xffffff, 0.6))
            for i in 0..<3 {
                let st = sin(T * 5 + Double(i)) * 0.05
                tar(c, -18 - Double(i) * 10 + sh, -33, coats[i], dark, lean: -0.5 + st, aL: 1.35, aR: 1.35)
                tar(c, 18 + Double(i) * 10 + sh, -33, coats[(i + 2) % 4], dark, lean: 0.5 - st, aL: -1.35, aR: -1.35)
            }
            tar(c, 0, -30.5, coats[3], dark, hop: abs(sin(T * 6)) * 1.5, aL: -2.6, aR: 2.6)
        case 24:
            // the leadsman in the chains, swinging the lead and calling the depth
            let ph = (T * 0.22).truncatingRemainder(dividingBy: 1)
            tar(c, 70, -33, coats[0], dark, lean: 0.25, aL: 0.6, aR: 1.5)
            if ph < 0.6 {
                let a = T * 7
                c.seg(75, -41, 75 + cos(a) * 11, -41 + sin(a) * 11, 0.7, Col(0xfff6d8)); c.circ(75 + cos(a) * 11, -41 + sin(a) * 11, 1.4, Col(0x4a4a52))
                c.circStroke(75, -41, 11, 0.5, Col(0xffffff, 0.15))
            } else {
                let k = (ph - 0.6) / 0.4
                let lx = 75 + k * 26, ly = -41 - sin(min(1, k * 1.6) * PI) * 16 + k * 50
                c.curve(75, -41, 80 + k * 10, -48, lx, min(ly, 9), 0.7, Col(0xfff6d8))
                if ly < 9 { c.circ(lx, ly, 1.4, Col(0x4a4a52)) } else { let r = min(1, (ly - 9) / 20); c.ellStroke(lx, 9, 3 + r * 10, 1 + r * 3, 0.9, Col(0xffffff, 0.7 * (1 - r))) }
            }
            tar(c, 54, -33, coats[2], dark, aL: 1.2, aR: 0.8); c.R(57, -42, 4, 3, Col(0x2a2a30))
            tar(c, -20, -33, coats[1], dark, walk: T * 6)
        case 25:
            // a stage slung over the side: two on it scraping and painting, one at the rail tending the lines
            let sw = sin(T * 1.1) * 1.6
            c.seg(-14, -44, -14 + sw, -15, 0.7, Col(0xfff6d8)); c.seg(22, -44, 22 + sw, -15, 0.7, Col(0xfff6d8))
            c.R(-18 + sw, -15, 44, 1.8, Col(0xc9a070).shade(dark))
            let sc = sin(T * 8)
            let a1: Double = 1.7 + sc * 0.3, a2: Double = 1.2 - sc * 0.25
            tar(c, -8 + sw, -15, coats[0], dark, lean: 0.3, aL: 1.0, aR: a1)
            c.seg(-2.5 + sw, -24 + sc, -0.5 + sw, -26 + sc, 1.2, Col(0x9aa0a8))
            for j in 0..<4 { let ph = (T * 1.3 + Double(j) / 4).truncatingRemainder(dividingBy: 1); c.circ(-1 + sw + hashN(Double(j)) * 3, -24 + ph * 22, 0.6, Col(0x6b4423, 1 - ph)) }
            tar(c, 12 + sw, -15, coats[2], dark, lean: 0.25, aL: 0.7, aR: a2)
            c.seg(17 + sw, -22 - sc, 19.5 + sw, -20 - sc, 1.5, Col(0x16110c)); c.R(14 + sw, -8, 12, 5, Col(0x16110c, 0.55))
            c.poly(Col(0x2a2a30), [2 + sw, -15, 2.6 + sw, -19, 6.4 + sw, -19, 7 + sw, -15])
            tar(c, -14, -33, coats[1], dark, lean: 0.35, aL: 1.3, aR: 1.5)
            // and a third lowered in a bowline further aft, kicking off the planks
            let kk = abs(sin(T * 1.7))
            c.seg(-52, -44, -52 + kk * 5, -20, 0.7, Col(0xfff6d8))
            tar(c, -52 + kk * 5, -8, coats[3], dark, lean: 0.35 + kk * 0.2, walk: T * 4, aL: 3.0, aR: 2.6)
            tar(c, -58, -33, coats[0], dark, lean: -0.3, aL: 1.4, aR: 1.4)
        case 26:
            // skylarking: two swinging out from the yardarms on a rope's end, one coming down a backstay by his hands
            for i in 0..<2 {
                let px = (i == 0 ? mx[0] : mx[mx.count - 1]) + (i == 0 ? -6.0 : 6.0), py = -128.0, L = 78.0
                let a = sin(T * 1.5 + Double(i) * 1.9) * 0.95
                let hx = px + sin(a) * L, hy = py + cos(a) * L
                c.seg(px, py, hx, hy, 0.8, Col(0xfff6d8))
                // he hangs below his hands, legs trailing the way he came
                c.save(); c.translate(hx, hy); c.rotate(-a * 0.75)
                tar(c, 0, 14.5, coats[i * 2], dark, walk: T * 3 + Double(i), aL: 3.05, aR: -3.05)
                c.restore()
                if abs(a) > 0.85 { c.textS(i == 0 ? "Wheee!" : "Ha!", hx, hy - 6, 6, Col(0xffffff, 0.9), 0, FONTB) }
            }
            let sl = (T * 0.16).truncatingRemainder(dividingBy: 1)
            let s0x = m0 + 2.0, s0y = -150.0, s1x = 78.0, s1y = -40.0
            c.seg(s0x, s0y, s1x, s1y, 0.6, Col(0xfff6d8, 0.8))
            let slx = lerp(s0x, s1x, sl), sly = lerp(s0y, s1y, sl)
            tar(c, slx, sly + 14.5, coats[1], dark, lean: 0.25, walk: T * 6, aL: 3.05, aR: -3.05)
            for (j, wx) in [-24.0, -8.0, 14.0].enumerated() {
                let jd = Double(j)
                let hp: Double = abs(sin(T * 5 + jd * 1.3)) * 1.8, w0: Double = -2.6 + sin(T * 6 + jd) * 0.3
                tar(c, wx, -33, coats[(j + 1) % 4], dark, hop: hp, aL: w0, aR: 2.4)
            }
        case 27:
            // idle hands: three sat on the rail with their legs over the side, one hanging off the bowsprit by his arms,
            // one doing pull-ups off the rail with a mate counting
            for (j, sx) in [-30.0, -20.0, -4.0].enumerated() {
                let kick = sin(T * 3 + Double(j) * 1.7)
                let skin = Col(0xe3b58a).shade(dark)
                c.seg(sx - 1, -44, sx - 1 + kick * 1.6, -38, 1.8, Col(0x2b2a33).shade(dark)); c.seg(sx + 1.2, -44, sx + 1.2 - kick * 1.6, -38, 1.8, Col(0x2b2a33).shade(dark))
                c.circ(sx - 1 + kick * 1.6, -37.4, 0.9, skin); c.circ(sx + 1.2 - kick * 1.6, -37.4, 0.9, skin)
                c.seg(sx, -44.5, sx, -49.5, 4, coats[j].shade(dark))
                c.seg(sx - 1.2, -48.5, sx - 3, -45, 1.4, skin); c.seg(sx + 1.2, -48.5, sx + 3, -45, 1.4, skin)
                c.circ(sx, -52, 2.4, skin); c.arcFill(sx, -52.2, 2.5, PI, PI * 2, Col.mix(coats[j], Col(0x8a1a1a), 0.6).shade(dark)); c.circ(sx + 1, -52.2, 0.42, Col(0x1a1008))
            }
            // off the bowsprit, swinging
            let bs = sin(T * 2.1) * 0.5
            c.save(); c.translate(98, -56); c.rotate(bs)
            tar(c, 0, 14.5, coats[3], dark, walk: T * 2.5, aL: 3.05, aR: -3.05)
            c.restore()
            // pull-ups off the rail, outboard
            let pu = 0.5 + 0.5 * sin(T * 2.6)
            let hangY = -44 + 14.5 - pu * 4.5
            tar(c, 30, hangY, coats[0], dark, aL: 3.05 - pu * 0.5, aR: -3.05 + pu * 0.5)
            tar(c, 40, -33, coats[1], dark, lean: 0.25, aL: 0.4, aR: 2.2)
            c.textS("\(Int(T * 2.6 / (PI * 2)) % 20 + 1)", 44, -50, 6, Col(0xffffff, 0.9), 0, FONTB)
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
        if card == nil && chance(0.2) { let q = mode == .sail ? camPt(x, y) : (x, y); puff(q.0, q.1, 2, Col(0xffffff, 0.8), 70, 200, 1.8, 0.4) }
    }
}
