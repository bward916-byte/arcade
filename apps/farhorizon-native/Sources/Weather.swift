import CoreGraphics
import Foundation

// Weather over the sea: cloud, rain, fog and storms with forked lightning.

struct Bolt {
    var segs: [(Double, Double, Double, Double, Double)] = []   // x0, y0, x1, y1, width
    var age = 0.0
}

extension Game {
    /// 0 clear, 1 overcast, 2 rain, 3 storm, 4 fog
    func setWeather(_ w: Int, days: Int) {
        weather = w
        wxDays = days
        if w == 3 { boltT = 0.8 }
    }
    func rollWeather() {
        wxDays -= 1
        if wxDays > 0 { return }
        let r = rnd(0, 1)
        if r < 0.5 { setWeather(0, days: rndI(1, 3)) }
        else if r < 0.7 { setWeather(1, days: rndI(1, 2)) }
        else if r < 0.87 { setWeather(2, days: rndI(1, 2)) }
        else if r < 0.93 { setWeather(3, days: 1) }
        else { setWeather(4, days: 1) }
    }
    var weatherName: String { return ["Fair", "Overcast", "Rain", "Storm", "Fog"][min(4, max(0, weather))] }

    func updateWeather(_ dt: Double) {
        let w = min(4, max(0, weather))
        let k = min(1, dt * 0.7)
        wxRain += ([0, 0, 0.6, 1, 0][w] - wxRain) * k
        wxDark += ([0, 0.38, 0.6, 0.85, 0.25][w] - wxDark) * k
        wxFog += ([0, 0, 0.05, 0, 0.8][w] - wxFog) * k
        rough += ([0, 0.12, 0.3, 1, 0.03][w] - rough) * k
        flashT = max(0, flashT - dt)
        var i = bolts.count - 1
        while i >= 0 {
            bolts[i].age += dt
            if bolts[i].age > 0.55 { bolts.remove(at: i) }
            i -= 1
        }
        if thunderIn >= 0 {
            thunderIn -= dt
            if thunderIn < 0 { snd?.thunder(); shake = max(shake, 0.12) }
        }
        if w == 3 && wxDark > 0.5 && (mode == .sail || mode == .port) {
            boltT -= dt
            if boltT <= 0 {
                strike()
                boltT = rnd(2.4, 6.5)
            }
        }
    }

    /// Forks a bolt from one point to another by splitting the line and pushing each midpoint aside.
    private func fork(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ disp: Double, _ w: Double, _ depth: Int, _ out: inout [(Double, Double, Double, Double, Double)]) {
        if depth <= 0 {
            out.append((x0, y0, x1, y1, w))
            return
        }
        let dx = x1 - x0, dy = y1 - y0
        let len = max(1, (dx * dx + dy * dy).squareRoot())
        let off = rnd(-disp, disp)
        let mx = (x0 + x1) / 2 - dy / len * off, my = (y0 + y1) / 2 + dx / len * off
        fork(x0, y0, mx, my, disp * 0.55, w, depth - 1, &out)
        fork(mx, my, x1, y1, disp * 0.55, w, depth - 1, &out)
        if depth >= 3 && chance(0.4) {
            // a side branch, thinner and shorter, leaning away from the main stroke
            let a = atan2(dy, dx) + rnd(0.35, 0.9) * (chance(0.5) ? 1 : -1)
            let bl = len * rnd(0.35, 0.6)
            fork(mx, my, mx + cos(a) * bl, my + sin(a) * bl, disp * 0.45, w * 0.5, depth - 2, &out)
        }
    }
    func strike() {
        let hz = H * 0.5
        let x = rnd(W * 0.08, W * 0.92)
        var b = Bolt()
        fork(x + rnd(-40, 40), -6, x + rnd(-70, 70), hz + rnd(-6, 14), 46, 2.6, 6, &b.segs)
        bolts.append(b)
        flashT = 0.4
        thunderIn = rnd(0.25, 1.2)
    }

    /// Drawn after the sky and sea, behind the ship: gloom, storm cloud and lightning.
    func weatherBack(_ c: Canvas, _ hz: Double) {
        if wxDark > 0.01 {
            c.vfill(0, 0, W, H, [(0, Col(0x10161f, 0.78 * wxDark)), (0.6, Col(0x26323c, 0.5 * wxDark)), (1, Col(0x0a1018, 0.55 * wxDark))])
            // heavy cloud rolling along the top
            for i in 0..<9 {
                let span = W + 420
                var cx = (hashN(Double(i) * 4.7) * span + T * (9 + hashN(Double(i)) * 10)).truncatingRemainder(dividingBy: span)
                cx -= 210
                let cy = hz * (0.02 + hashN(Double(i) * 2.1) * 0.34)
                let s = 1.1 + hashN(Double(i) * 6.3) * 1.2
                let lit = flashT > 0 ? flashT * 1.4 : 0
                let cc = Col.mix(Col(0x1c232d), Col(0xcfe0ff), min(0.7, lit))
                c.ell(cx, cy + 8 * s, 92 * s, 20 * s, cc.shade(0.8).alpha(0.75 * wxDark))
                c.ell(cx - 40 * s, cy, 52 * s, 26 * s, cc.alpha(0.8 * wxDark))
                c.ell(cx + 18 * s, cy - 10 * s, 60 * s, 30 * s, cc.alpha(0.85 * wxDark))
            }
        }
        for b in bolts {
            // two quick flickers, then it fades
            let fl = b.age < 0.08 ? 1.0 : (b.age < 0.14 ? 0.3 : (b.age < 0.24 ? 0.9 : max(0, 1 - (b.age - 0.24) / 0.3)))
            if fl <= 0.01 { continue }
            c.roundCaps(true)
            for s in b.segs { c.seg(s.0, s.1, s.2, s.3, s.4 * 5, Col(0x8fb4ff, 0.16 * fl)) }
            for s in b.segs { c.seg(s.0, s.1, s.2, s.3, s.4 * 2.2, Col(0xcfe0ff, 0.45 * fl)) }
            for s in b.segs { c.seg(s.0, s.1, s.2, s.3, s.4 * 0.8, Col(0xffffff, fl)) }
            c.roundCaps(false)
            if let last = b.segs.last { c.glow(last.2, hz, 90, Col(0xcfe0ff, 0.5 * fl), Col(0xcfe0ff, 0)) }
        }
    }

    /// Drawn over the ship: rain, the flash, fog.
    func weatherFront(_ c: Canvas, _ hz: Double) {
        if wxRain > 0.03 {
            let n = Int(170 * wxRain)
            let slant = 5 + rough * 9
            for i in 0..<n {
                let sp = 520 + hashN(Double(i) * 1.3) * 380
                let span = H + 60
                let y = (hashN(Double(i) * 7.1) * span + T * sp).truncatingRemainder(dividingBy: span) - 30
                var x = (hashN(Double(i) * 3.9) * (W + 80) - T * sp * slant / 18).truncatingRemainder(dividingBy: W + 80)
                if x < 0 { x += W + 80 }
                x -= 40
                let len = 12 + hashN(Double(i) * 9.7) * 12
                c.seg(x, y, x - slant * len / 18, y + len, 1, Col(0xd6e6ff, 0.16 + 0.22 * hashN(Double(i) * 5.5)))
            }
            // rings where the drops strike the water
            for i in 0..<Int(18 * wxRain) {
                let ph = (T * 1.8 + hashN(Double(i) * 2.7) * 3).truncatingRemainder(dividingBy: 1)
                let cyc = floor(T * 1.8 + hashN(Double(i) * 2.7) * 3)
                let rx = hashN(Double(i) * 8.1 + cyc) * W
                let ry = hz + 10 + hashN(Double(i) * 4.3 + cyc * 1.7) * (H - hz - 14)
                c.ellStroke(rx, ry, 2 + ph * 9, 0.6 + ph * 2.4, 1, Col(0xffffff, 0.3 * (1 - ph)))
            }
        }
        if wxFog > 0.03 {
            c.R(0, 0, W, H, Col(0xc8d2d8, 0.34 * wxFog))
            for i in 0..<10 {
                let span = W + 600
                var fx = (hashN(Double(i) * 5.3) * span + T * (6 + hashN(Double(i) * 1.9) * 9)).truncatingRemainder(dividingBy: span)
                fx -= 300
                let fy = hz * 0.5 + hashN(Double(i) * 3.3) * (H - hz * 0.5)
                c.ell(fx, fy, 230 + hashN(Double(i) * 2.2) * 160, 26 + hashN(Double(i) * 7.7) * 22, Col(0xe6edf0, 0.17 * wxFog))
            }
        }
        if flashT > 0 { c.R(0, 0, W, H, Col(0xdfe9ff, min(0.5, flashT * 1.3))) }
    }
}
