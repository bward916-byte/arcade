import CoreGraphics
import Foundation

// The people of the island: townsfolk, the merchant, your crew waiting at the tavern, and workers at what you build.

extension Game {
    /// One islander. hat: 0 none, 1 straw, 2 bandana, 3 cap. work swings the near arm as if hammering or hauling.
    func drawFolk(_ c: Canvas, _ wx: Double, _ face: Double, _ sc: Double, _ ph: Double, _ moving: Bool, _ shirtHex: UInt32, _ pantsHex: UInt32, _ hat: Int, _ hatHex: UInt32 = 0xa82020, _ work: Bool = false, _ skinHex: UInt32 = 0xe0b088) {
        if !vis(wx, 30) { return }
        if heroOn {
            // the same rig as the player: pick the outfit from what this islander is
            var name = hat == 1 ? "merchant" : (shirtHex == 0x2c5f7a ? "towns2" : "towns")
            if hat == 2 { name = (hatHex & 0xff) > 0x60 ? "mate" : "mate2" }
            if work { name = "worker" }
            let tall = 46 * sc
            let frame = moving ? Int(wx / (0.98 * tall) * 16) : Int((T + wx) / 2.4 * 16)
            if drawSprite(c, name, moving ? 0 : 1, frame, wx, face, tall, light) {
                if work {
                    // tool in hand, swung from the shoulder
                    let X = sx(wx), Y = sy(groundLand(wx)), k = camS * sc
                    let a = -1.2 + abs(sin(T * 5 + wx)) * 1.1
                    let hx = X + face * 6 * k, hy = Y - 24 * k
                    c.seg(hx, hy, hx + face * cos(a) * 11 * k, hy + sin(a) * 11 * k, 1.5 * k, lc(0x5a3a1e))
                    c.R(hx + face * cos(a) * 11 * k - 2.5 * k, hy + sin(a) * 11 * k - 1.5 * k, 5 * k, 3 * k, lc(0x4a4e54))
                }
                return
            }
        }
        let bob = moving ? abs(sin(ph)) * 1.0 : sin(T * 1.6 + wx) * 0.3
        c.save()
        c.translate(sx(wx), sy(groundLand(wx)))
        c.scale(camS * face * sc, camS * sc)
        c.ell(0, 0.6, 9, 1.8, Col(0x000000, 0.14 + 0.1 * light))
        let skin = lc(skinHex), shirt = lc(shirtHex), pants = lc(pantsHex)
        let hipY = -20.0 - bob, shY = -34.0 - bob
        c.roundCaps(true)
        for side in 0..<2 {
            let p2 = ph + (side == 0 ? PI : 0)
            let swing = moving ? sin(p2) * 0.5 : 0
            let bend = moving ? max(0, -cos(p2)) * 0.7 : 0
            let kx = sin(swing) * 10, ky = hipY + cos(swing) * 10
            let fx = kx + sin(swing - bend) * 10
            let fy = min(0.0, ky + cos(swing - bend) * 10)
            let col = side == 0 ? pants.shade(0.75) : pants
            c.seg(0, hipY, kx, ky, 4.4, col)
            c.seg(kx, ky, fx, fy, 3.8, col)
            c.ell(fx + 1.6, fy - 0.9, 3.4, 1.6, lc(0x2a1c10))
        }
        let armSwing = moving ? sin(ph) * 0.55 : 0.08
        let ax = sin(armSwing) * 8, ay = shY + cos(armSwing) * 8
        c.seg(0, shY, ax, ay, 3, shirt.shade(0.72))
        c.seg(ax, ay, ax + sin(armSwing + 0.3) * 7, ay + cos(armSwing + 0.3) * 7, 2.6, skin.shade(0.78))
        c.roundCaps(false)
        c.pathFill(shirt) { p in
            p.move(to: CGPoint(x: -4.2, y: shY - 2))
            p.addLine(to: CGPoint(x: 4.4, y: shY - 2))
            p.addQuadCurve(to: CGPoint(x: 3.8, y: hipY + 1), control: CGPoint(x: 5.4, y: (shY + hipY) / 2))
            p.addLine(to: CGPoint(x: -3.6, y: hipY + 1))
            p.addQuadCurve(to: CGPoint(x: -4.2, y: shY - 2), control: CGPoint(x: -5, y: (shY + hipY) / 2))
        }
        c.R(-3.8, hipY - 1, 7.8, 2, lc(0x3a2512))
        c.R(-1.2, shY - 5, 2.6, 4, skin.shade(0.85))
        let headY = shY - 8.4
        c.circ(0.5, headY, 3.7, skin)
        c.pathFill(lc(0x3a2a1a)) { p in
            p.addArc(center: CGPoint(x: 0.3, y: headY - 0.4), radius: 3.9, startAngle: CGFloat(PI * 0.95), endAngle: CGFloat(PI * 1.95), clockwise: false)
            p.addLine(to: CGPoint(x: -3.4, y: headY + 1.6))
            p.closeSubpath()
        }
        c.circ(2.6, headY - 0.2, 0.5, Col(0x1a1008))
        if hat == 1 {
            c.ell(0.4, headY - 2.6, 7.4, 1.5, lc(0xd8c070))
            c.dome(0.4, headY - 2.8, 3.6, lc(0xc8ae5a))
        } else if hat == 2 {
            c.pathFill(lc(hatHex)) { p in
                p.addArc(center: CGPoint(x: 0.3, y: headY - 0.6), radius: 4.0, startAngle: CGFloat(PI * 1.02), endAngle: CGFloat(PI * 1.98), clockwise: false)
                p.closeSubpath()
            }
            c.seg(-3.4, headY - 1, -6.6, headY + 1.6, 1.4, lc(hatHex))
        } else if hat == 3 {
            c.dome(0.3, headY - 1.6, 3.9, lc(hatHex))
            c.R(2.6, headY - 2.2, 4, 1, lc(hatHex).shade(0.7))
        }
        c.roundCaps(true)
        if work {
            let a = -1.9 + abs(sin(T * 5 + wx)) * 1.5
            let ex = cos(a) * 8, ey = shY + sin(a) * 8 + 4
            c.seg(0.5, shY, ex + 3, ey, 3.1, shirt)
            c.seg(ex + 3, ey, ex + 9, ey - 3, 2.7, skin)
            c.seg(ex + 9, ey - 3, ex + 11, ey - 10, 1.4, lc(0x5a3a1e))
            c.R(ex + 8.6, ey - 12.5, 5, 3, lc(0x4a4e54))
        } else {
            let a2 = -armSwing
            let bx = sin(a2) * 8, by = shY + cos(a2) * 8
            c.seg(0.5, shY, bx, by, 3.1, shirt)
            c.seg(bx, by, bx + sin(a2 + 0.3) * 7, by + cos(a2 + 0.3) * 7, 2.7, skin)
        }
        c.roundCaps(false)
        c.restore()
    }

    func drawFolkAll(_ c: Canvas, _ L: Double) {
        let k = camS
        // bunting across the street once the town has grown
        if stage >= 1 && vis(1090, 140) {
            let x1 = sx(1010), y1 = sy(ground(1010)) - 86 * k, x2 = sx(1170), y2 = sy(ground(1170)) - 94 * k
            c.curve(x1, y1, (x1 + x2) / 2, (y1 + y2) / 2 + 20 * k, x2, y2, 0.8, Col(0x3c2814, 0.7))
            let flags: [UInt32] = [0xb03030, 0xe8d090, 0x2c5f7a, 0xe8e0d0]
            for i in 1..<10 {
                let f = Double(i) / 10
                let px2 = lerp(x1, x2, f)
                let py2 = lerp(y1, y2, f) + sin(f * PI) * 10 * k
                let sw = sin(T * 3 + Double(i)) * 1.2 * k
                c.poly(lc(flags[i % 4]), [px2 - 3 * k, py2, px2 + 3 * k, py2, px2 + sw, py2 + 8 * k])
            }
        }
        // chickens by the cottage
        for i in 0..<3 {
            let fi = Double(i)
            let cx = 1080 + fi * 14 + sin(T * 0.4 + fi * 2) * 8
            if !vis(cx, 20) { continue }
            let peck = max(0, sin(T * 5 + fi * 1.7))
            c.save()
            c.translate(sx(cx), sy(ground(cx)))
            c.scale(k * 1.3 * (cos(T * 0.4 + fi * 2) > 0 ? 1 : -1), k * 1.3)
            let body = i == 1 ? lc(0x8a4a2a) : lc(0xf0ece0)
            c.seg(-0.8, -1.4, -0.8, 0, 0.6, lc(0xd8a030))
            c.seg(1, -1.4, 1, 0, 0.6, lc(0xd8a030))
            c.ell(0, -3.5, 4, 2.8, body)
            c.poly(body, [-3, -4, -6.5, -6.5, -3.4, -2])
            c.circ(3.6, -5.6 + peck * 3.4, 1.8, body)
            c.poly(lc(0xd8a030), [5, -5.6 + peck * 3.4, 6.8, -5 + peck * 3.6, 5, -4.6 + peck * 3.4])
            c.R(3.2, -8 + peck * 3.4, 1.2, 1.2, Col(0xc03030))
            c.restore()
        }
        // the merchant behind his stall, and the tavern keeper at her door
        drawFolk(c, 1046, -1, 0.88, 0, false, 0x4e6b3a, 0x3a3d52, 1)
        drawFolk(c, 1218, 1, 0.86, 0, false, 0xd9d2c0, 0x5a4632, 0, 0, false, 0xc98b5e)
        // townsfolk about their day; indoors after dark
        if L > 0.25 {
            let walkers: [(Double, Double, Double, UInt32, UInt32, Int)] = [(1120, 150, 0.11, 0x8b2f2f, 0x3a3d52, 1), (1420, 190, 0.083, 0x2c5f7a, 0x5a4632, 3), (1010, 70, 0.14, 0x6a4c8a, 0x2a2a2e, 0), (330, 190, 0.07, 0xb07a2a, 0x4a5a6e, 1)]
            for (i, w) in walkers.enumerated() {
                let a = T * w.2 + Double(i) * 1.9
                let wx = w.0 + sin(a) * w.1
                let v = cos(a)
                drawFolk(c, wx, v > 0 ? 1 : -1, 0.86, wx * 0.17, abs(v) > 0.12, w.3, w.4, w.5, 0x6a5a42)
            }
        }
        // the hands you have signed, waiting outside the tavern
        let bands: [UInt32] = [0xa82020, 0x2a5aa8, 0x2f8a3a, 0xc89a20, 0x7a2a8a, 0xe06a20, 0x333333, 0xd0d0d0, 0x1f6a6a, 0x8a2a4a]
        let shirts: [UInt32] = [0xd9d2c0, 0x8b2f2f, 0x2c5f7a, 0x4e6b3a, 0xb07a2a]
        for i in 0..<min(10, mates) {
            let wx = 1284 + Double(i) * 12.5
            drawFolk(c, wx, i % 2 == 0 ? -1 : 1, 0.88, 0, false, shirts[i % 5], 0x3a3d52, 2, bands[i], false, i % 3 == 1 ? 0xa86b43 : 0xe0b088)
        }
        // workers where you have built
        let jobs: [(String, Double, Double)] = [("hut", 548, 1), ("mill", 2712, -1), ("farm", 2935, -1), ("smithy", 3096, -1), ("dock2", 3436, 1)]
        for (id, wx, dir) in jobs where done.contains(id) && !dmg.contains(id) && L > 0.2 {
            drawFolk(c, wx, dir, 0.88, 0, false, id == "smithy" ? 0x4a3a30 : 0xc8b890, 0x4a3d32, id == "farm" ? 1 : 0, 0, true)
        }
        // a lookout up the watchtower
        if done.contains("tower") && !dmg.contains("tower") && lvl("tower") < 3 && vis(2275, 60) {
            let hgt = 78 + Double(lvl("tower") - 1) * 26
            c.save()
            c.translate(sx(2275), sy(ground(2275)) - (hgt + 3) * k)
            c.scale(k * 0.8, k * 0.8)
            c.R(-3, -16, 6, 14, lc(0x2c5f7a))
            c.circ(0, -19.5, 3.4, lc(0xe0b088))
            c.dome(0, -20.4, 3.6, lc(0xa82020))
            c.seg(-2, -13, -9, -17, 2, lc(0x2c5f7a))
            c.seg(-9, -17, -15, -18, 1.4, lc(0xd8b86a))
            c.restore()
        }
    }
}
