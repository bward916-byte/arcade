import CoreGraphics
import Foundation

// The sea chart: painted once from a height field, then drawn with the routes and ports over it.

private struct Lcg {
    var s: UInt64
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double((s >> 33) & 0xFFFFFF) / Double(0x1000000)
    }
}

private final class Fbm {
    private var p = [Int](repeating: 0, count: 514)
    init(seed: UInt64) {
        var r = Lcg(s: seed)
        for i in 0..<256 { p[i] = i }
        var i = 255
        while i > 0 {
            let j = Int(r.next() * Double(i + 1))
            let t = p[i]; p[i] = p[j]; p[j] = t
            i -= 1
        }
        for k in 0..<258 { p[256 + k] = p[k] }
    }
    private func v(_ x: Double, _ y: Double) -> Double {
        let xi = Int(floor(x)), yi = Int(floor(y))
        let xf = x - Double(xi), yf = y - Double(yi)
        let u = xf * xf * (3 - 2 * xf), w = yf * yf * (3 - 2 * yf)
        let X = xi & 255, Y = yi & 255
        let a = Double(p[p[X] + Y]), b = Double(p[p[X + 1] + Y])
        let cc = Double(p[p[X] + Y + 1]), d = Double(p[p[X + 1] + Y + 1])
        let t = a + (b - a) * u
        let t2 = cc + (d - cc) * u
        return (t + (t2 - t) * w) / 255
    }
    func at(_ x: Double, _ y: Double) -> Double {
        var s = 0.0, a = 0.5, f = 1.0
        for o in 0..<5 {
            s += v(x * f + Double(o) * 17.3, y * f + Double(o) * 9.1) * a
            a *= 0.5
            f *= 2
        }
        return s
    }
}

private let CW = 900, CH = 540
private var townAt: [[(Double, Double)]] = []

extension Game {
    func buildChart() {
        let w = CW, h = CH
        let A = Double(w) / Double(h)
        let nz = Fbm(seed: 4321)
        var rng = Lcg(s: 909)
        // each port gets a hump of land behind it and a notch of water in front
        var bumps: [(Double, Double, Double, Double)] = []
        townAt = []
        for (i, st) in STAGES.enumerated() {
            var row: [(Double, Double)] = []
            for (r, n) in st.enumerated() {
                let rad = (i == 0 || i == 5) ? 0.1 : (r == 0 ? 0.085 : 0.075)
                let dx: Double = i == 0 ? -1 : (i == 5 ? 1 : 0)
                let dy: Double = dx != 0 ? 0 : (r == 0 ? -1 : 1)
                let cx = n.x * A + dx * rad * 0.6, cy = n.y + dy * rad * 0.6
                bumps.append((cx, cy, rad, 1.15))
                let ox = (rng.next() - 0.5) * rad * 1.2 + dx * rad * 0.3
                let oy = dy * rad * 0.5 + (rng.next() - 0.5) * rad * 0.4
                bumps.append((cx + ox, cy + oy, rad * 0.75, 0.9))
                bumps.append((n.x * A, n.y, 0.016, -0.8))
                row.append(((n.x * A + dx * rad * 0.34) / A, n.y + dy * rad * 0.34))
            }
            townAt.append(row)
        }
        let islets: [(Double, Double, Double)] = [(0.24, 0.5, 0.035), (0.43, 0.485, 0.04), (0.61, 0.51, 0.035), (0.79, 0.49, 0.04), (0.14, 0.93, 0.06), (0.5, 0.96, 0.07), (0.86, 0.93, 0.06), (0.33, 0.9, 0.035), (0.68, 0.91, 0.035), (0.92, 0.3, 0.03), (0.1, 0.72, 0.03)]
        for q in islets {
            bumps.append((q.0 * A, q.1, q.2, 1.05))
            bumps.append((q.0 * A + (rng.next() - 0.5) * q.2, q.1 + (rng.next() - 0.5) * q.2, q.2 * 0.7, 0.8))
        }
        var hh = [Double](repeating: 0, count: w * h)
        for y in 0..<h {
            let ny = Double(y) / Double(h)
            for x in 0..<w {
                let nx = Double(x) / Double(w)
                let ax = nx * A
                var v = -0.3 + (nz.at(ax * 5, ny * 5) - 0.48) * 0.75
                let coast = 0.13 + 0.035 * sin(nx * 11) + 0.025 * sin(nx * 29 + 1) - ny
                v += clampD(coast / 0.07, -0.2, 1.3) * 0.75
                v += clampD((0.02 - nx) / 0.03, 0, 1.3) * 0.75
                v += clampD((nx - 0.985) / 0.03, 0, 1.3) * 0.75
                for q in bumps {
                    let ddx = ax - q.0, ddy = ny - q.1
                    let d = (ddx * ddx + ddy * ddy) / (q.2 * q.2)
                    if d < 1 { v += q.3 * (1 - d) * (1 - d) }
                }
                hh[y * w + x] = v
            }
        }
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let v = hh[i]
                let gx = hh[x < w - 1 ? i + 1 : i] - hh[x > 0 ? i - 1 : i]
                let gy = hh[y < h - 1 ? i + w : i] - hh[y > 0 ? i - w : i]
                let n = Double(((x &* 73856093) ^ (y &* 19349663)) & 255) / 255 - 0.5
                var r = 0.0, g = 0.0, b = 0.0
                if v < 0 {
                    let d = clampD(-v / 0.6, 0, 1)
                    if d < 0.3 {
                        let k = d / 0.3
                        r = 104 + (40 - 104) * k; g = 202 + (134 - 202) * k; b = 200 + (178 - 200) * k
                    } else {
                        let k = (d - 0.3) / 0.7
                        r = 40 + (16 - 40) * k; g = 134 + (58 - 134) * k; b = 178 + (104 - 178) * k
                    }
                    if v > -0.025 { r += (238 - r) * 0.55; g += (246 - g) * 0.55; b += (238 - b) * 0.55 }
                    r += n * 6; g += n * 6; b += n * 6
                } else {
                    if v < 0.04 {
                        r = 234; g = 216; b = 164
                    } else if v < 0.5 {
                        let k = (v - 0.04) / 0.46
                        r = 134 + (72 - 134) * k; g = 172 + (118 - 172) * k; b = 94 + (64 - 94) * k
                    } else if v < 0.95 {
                        let k = (v - 0.5) / 0.45
                        r = 72 + (122 - 72) * k; g = 118 + (112 - 118) * k; b = 64 + (84 - 64) * k
                    } else {
                        let k = clampD((v - 0.95) / 0.6, 0, 1)
                        r = 122 + (176 - 122) * k; g = 112 + (166 - 112) * k; b = 84 + (148 - 84) * k
                    }
                    let sh = clampD(1 + (gx + gy) * (v < 0.04 ? 2 : 9), 0.55, 1.45) + n * 0.09
                    r *= sh; g *= sh; b *= sh
                }
                px[i * 4] = UInt8(clampD(r, 0, 255))
                px[i * 4 + 1] = UInt8(clampD(g, 0, 255))
                px[i * 4 + 2] = UInt8(clampD(b, 0, 255))
            }
        }
        guard let provider = CGDataProvider(data: Data(px) as CFData) else { return }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let terrain = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return }
        // lettering, towns and the compass go on top, at twice the resolution
        guard let cv = Canvas(w: w, h: h, scale: 2) else { chartImg = terrain; return }
        let W2 = Double(w), H2 = Double(h)
        cv.drawImage(terrain, 0, 0, W2, H2)
        cv.R(0, 0, W2, H2, Col(0xffe2a0, 0.07))
        var gx = 75.0
        var k = 1
        while gx < W2 {
            cv.R(gx, 0, 0.6, H2, Col(0xffffff, 0.16))
            cv.text("\(74 - k * 2)°W", gx + 3, H2 - 12, 7, Col(0xffffff, 0.6), -1, FONTI)
            gx += 75; k += 1
        }
        var gy = 67.5
        k = 1
        while gy < H2 {
            cv.R(0, gy, W2, 0.6, Col(0xffffff, 0.16))
            cv.text("\(26 - k * 2)°N", 12, gy - 3, 7, Col(0xffffff, 0.6), -1, FONTI)
            gy += 67.5; k += 1
        }
        for _ in 0..<130 {
            let x = rng.next(), y = rng.next()
            let v = hh[min(h - 1, Int(y * Double(h))) * w + min(w - 1, Int(x * Double(w)))]
            if v < -0.14 { cv.text("\(Int(-v * 70))", x * W2, y * H2, 6, Col(0xffffff, 0.42), 0, FONT) }
        }
        for _ in 0..<700 {
            let x = rng.next(), y = rng.next()
            let v = hh[min(h - 1, Int(y * Double(h))) * w + min(w - 1, Int(x * Double(w)))]
            if v > 0.07 && v < 0.8 {
                let s = 1.5 + rng.next() * 1.3
                cv.circ(x * W2 + 0.8, y * H2 + 0.8, s, Col(0x143219, 0.35))
                cv.circ(x * W2, y * H2, s, rng.next() < 0.5 ? Col(0x3f7a3c) : Col(0x56913f))
                cv.circ(x * W2 - s * 0.3, y * H2 - s * 0.3, s * 0.45, Col(0xbee182, 0.5))
            }
        }
        for (i, st) in STAGES.enumerated() {
            for (r, n) in st.enumerated() {
                let tx = townAt[i][r].0 * W2, ty = townAt[i][r].1 * H2
                cv.seg(tx, ty, n.x * W2, n.y * H2, 2, Col(0x4a321a))
                cv.ell(tx, ty, 13, 9, Col(0xd6c496, 0.85))
                let nh = (i == 0 || i == 5) ? 9 : 6
                for q in 0..<nh {
                    let hx = tx + (rng.next() - 0.5) * 20, hy = ty + (rng.next() - 0.5) * 12, s = 4 + rng.next() * 2
                    cv.R(hx - s / 2 + 1, hy - s / 2 + 1, s, s, Col(0x000000, 0.28))
                    cv.R(hx - s / 2, hy - s / 2, s, s, Col(0xf6ecd4))
                    cv.poly(q % 3 == 0 ? Col(0x8a5a36) : Col(0xb8452c), [hx - s / 2 - 0.8, hy - s / 2, hx, hy - s * 1.05, hx + s / 2 + 0.8, hy - s / 2])
                }
            }
        }
        cv.text("THE AURELIAN SEA", W2 * 0.5, H2 * 0.63, 27, Col(0xffffff, 0.3), 0, FONTD)
        cv.text("THE  MAIN", W2 * 0.52, H2 * 0.08, 20, Col(0x281808, 0.55), 0, FONTD)
        cv.text("Gulf of Storms", W2 * 0.7, H2 * 0.64, 12, Col(0xffffff, 0.5), 0, FONTI)
        cv.text("Serpent Deeps", W2 * 0.33, H2 * 0.83, 12, Col(0xffffff, 0.5), 0, FONTI)
        cv.text("Pearl Shoals", W2 * 0.52, H2 * 0.4, 11, Col(0xffffff, 0.5), 0, FONTI)
        // compass rose
        let rx = W2 * 0.93, ry = H2 * 0.82, cr = 28.0
        cv.circStroke(rx, ry, cr, 1, Col(0xfff6d8, 0.9))
        cv.circStroke(rx, ry, cr * 0.72, 1, Col(0xfff6d8, 0.9))
        for q in 0..<16 {
            let a = Double(q) / 16 * PI * 2 - PI / 2
            let rr = q % 4 == 0 ? cr * 1.3 : (q % 2 == 0 ? cr * 0.9 : cr * 0.55)
            let wd = q % 2 == 1 ? 0.1 : 0.16
            let inner = cr * 0.2
            let x1 = rx + cos(a - wd) * inner, y1 = ry + sin(a - wd) * inner
            let x2 = rx + cos(a) * rr, y2 = ry + sin(a) * rr
            let x3 = rx + cos(a + wd) * inner, y3 = ry + sin(a + wd) * inner
            let pc: Col = q % 4 == 0 ? Col(0xb0281c) : Col(0xfff6d8, 0.9)
            cv.poly(pc, [x1, y1, x2, y2, x3, y3])
        }
        cv.text("N", rx, ry - cr * 1.42, 14, Col(0xfff6d8), 0, FONTD)
        cv.RRStroke(4, 4, W2 - 8, H2 - 8, 2, 7, Col(0x3a2412))
        cv.RRStroke(9, 9, W2 - 18, H2 - 18, 2, 1.2, Col(0xd2a455))
        chartImg = cv.image() ?? terrain
    }

    func drawChart(_ c: Canvas) {
        if chartImg == nil { buildChart() }
        c.R(0, 0, W, H, Col(0x17100a))
        // the chart fills the width; the ports sit in the middle band, so the top and bottom can run off screen
        let top = 34.0
        let mw = W, mh = W * Double(CH) / Double(CW)
        let my = top + (H - top - mh) / 2
        if let img = chartImg { c.drawImage(img, 0, my, mw, mh) }
        func pos(_ p: Port) -> (Double, Double) { return (p.x * mw, my + p.y * mh) }
        func seaLane(_ a: (Double, Double), _ b: (Double, Double), _ w: Double, _ col: Col) {
            let mx = (a.0 + b.0) / 2, mmy = (a.1 + b.1) / 2
            let dx = b.0 - a.0, dy = b.1 - a.1
            c.curve(a.0, a.1, mx - dy * 0.08, mmy + dx * 0.08, b.0, b.1, w, col)
        }
        c.roundCaps(true)
        c.dash(4, 6)
        for i in 0..<5 {
            for a in STAGES[i] { for b in STAGES[i + 1] { seaLane(pos(a), pos(b), 1.2, Col(0xfff8e1, 0.5)) } }
        }
        c.noDash()
        if self.leg > 0 {
            for i in 0..<self.leg {
                let a = pos(STAGES[i][path[i]]), b = pos(STAGES[i + 1][path[i + 1]])
                seaLane(a, b, 5, Col(0x280a06, 0.7))
                seaLane(a, b, 2.6, Col(0xef4a36))
            }
        }
        let hereP = pos(here)
        let next = STAGES[min(5, self.leg + 1)]
        for n in next {
            let q = pos(n)
            seaLane(hereP, q, 5, Col(0x281406, 0.6))
            c.dash(8, 7, -T * 14)
            seaLane(hereP, q, 2.6, Col(0xffe08a))
            c.noDash()
        }
        for (i, st) in STAGES.enumerated() {
            for (r, n) in st.enumerated() {
                let p = pos(n)
                let been = i <= self.leg && path[i] == r
                let opt = i == self.leg + 1
                c.circ(p.0, p.1, opt ? 6.5 : 5, Col(0x2a1808))
                c.circ(p.0, p.1, opt ? 5 : 3.6, been ? Col(0xef4a36) : Col(0xfff6d8))
                if !opt {
                    let ly = i == self.leg ? p.1 - 22 : p.1 + 17
                    c.textS(n.n, clampD(p.0, safeL + 50, W - safeR - 50), ly, 12, been ? Col(0xffd9c9) : Col(0xfff6d8), 0, FONTB)
                }
            }
        }
        // your ship
        c.poly(Col(0x3a2412), [hereP.0 - 10, hereP.1 - 3, hereP.0 + 10, hereP.1 - 3, hereP.0 + 7, hereP.1 + 3, hereP.0 - 7, hereP.1 + 3])
        c.poly(Col(0xfff6e0), [hereP.0, hereP.1 - 4, hereP.0, hereP.1 - 18, hereP.0 + 9, hereP.1 - 5])
        // where you can go next
        for (r, n) in next.enumerated() {
            let p = pos(n)
            let sea = (next.count > 1 ? r : path[self.leg]) != 0
            let d = Int((LEG[min(4, self.leg)] * (sea ? 0.85 : 1.15)).rounded())
            let pu = 1 + sin(T * 4 + Double(r)) * 0.12
            c.circStroke(p.0, p.1, 13 * pu, 2.5, Col(0xffd257))
            let l3 = sea ? "open sea · storms, pirates" : "coast · calm, fish, islands"
            let bw = max(textW(n.n, 14, FONTB), textW(l3, 11, FONT)) + 20
            let bh = 52.0
            let bx = clampD(p.0 - bw / 2, safeL, W - safeR - bw)
            let by = p.1 + 18 + bh > H - safeB ? p.1 - 18 - bh : p.1 + 18
            c.RR(bx, by, bw, bh, 8, Col(0x3a2412, 0.94))
            c.RRStroke(bx, by, bw, bh, 8, 1.5, Col(0xd2a455))
            c.text(n.n, bx + bw / 2, by + 17, 14, Col(0xffe08a), 0, FONTB)
            c.text("\(d) leagues", bx + bw / 2, by + 32, 11.5, CREAM, 0, FONT)
            c.text(l3, bx + bw / 2, by + 45, 11, CREAM, 0, FONT)
            hits.append(Hit(x: bx, y: min(by, p.1 - 16), w: bw, h: bh + 34, act: { [unowned self] in self.pickPort(r) }))
            hits.append(Hit(x: p.0 - 22, y: p.1 - 22, w: 44, h: 44, act: { [unowned self] in self.pickPort(r) }))
        }
        c.textS("Tap your next port", W / 2, H - safeB - 8, 16, Col(0xffe08a), 0, FONTD)
    }
}
