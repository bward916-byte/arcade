import UIKit

/// The name of the game over the first morning. It stands a moment, then catches at one edge,
/// burns across, and blows off down the wind as ash and sparks.
final class BurnLogoView: UIView {
    private let pic = CALayer()
    private let ash = CAEmitterLayer()
    private let ember = CAEmitterLayer()
    private var src: [UInt8] = []
    private var thr: [Float] = []
    private var solid: [Int32] = []
    private var pw = 0, ph = 0
    private var builtFor = CGSize.zero
    private var box = CGRect.zero
    private var p = 0.0
    private var wait = 0.0
    private var tail = 0.0
    private var lit = false
    private var started = false
    /// Holds the burn part-way, for a still picture.
    var frozen: Double?
    var onStart: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(pic)
        let sq = BurnLogoView.fleck(round: false), dot = BurnLogoView.fleck(round: true)
        ash.emitterShape = .rectangle
        ash.emitterMode = .surface
        ash.birthRate = 0
        ash.emitterCells = [
            cell(sq, rate: 380, life: 2.4, vel: 130, lon: -0.3, range: 0.7, ay: -26, ax: 95, scale: 0.3, fade: -0.4, color: UIColor(red: 0.15, green: 0.12, blue: 0.1, alpha: 0.95)),
            cell(sq, rate: 200, life: 2.8, vel: 100, lon: -0.45, range: 0.9, ay: -34, ax: 80, scale: 0.2, fade: -0.34, color: UIColor(red: 0.62, green: 0.58, blue: 0.52, alpha: 0.9))
        ]
        ember.emitterShape = .rectangle
        ember.emitterMode = .surface
        ember.renderMode = .additive
        ember.birthRate = 0
        ember.emitterCells = [
            cell(dot, rate: 170, life: 1.2, vel: 150, lon: -0.5, range: 0.9, ay: -60, ax: 70, scale: 0.3, fade: -0.85, color: UIColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)),
            cell(dot, rate: 50, life: 0.7, vel: 60, lon: -1.2, range: 1.2, ay: -40, ax: 30, scale: 0.55, fade: -1.5, color: UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 0.8))
        ]
        layer.addSublayer(ash)
        layer.addSublayer(ember)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private static func fleck(round: Bool) -> CGImage? {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12), format: f).image { ctx in
            UIColor.white.setFill()
            if round { ctx.cgContext.fillEllipse(in: CGRect(x: 1, y: 1, width: 10, height: 10)) }
            else {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 1, y: 5)); p.addLine(to: CGPoint(x: 5, y: 2)); p.addLine(to: CGPoint(x: 11, y: 4)); p.addLine(to: CGPoint(x: 9, y: 9)); p.addLine(to: CGPoint(x: 3, y: 10)); p.close(); p.fill()
            }
        }
        return img.cgImage
    }

    private func cell(_ img: CGImage?, rate: Float, life: Float, vel: CGFloat, lon: CGFloat, range: CGFloat, ay: CGFloat, ax: CGFloat, scale: CGFloat, fade: Float, color: UIColor) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.contents = img
        c.birthRate = rate
        c.lifetime = life
        c.lifetimeRange = life * 0.4
        c.velocity = vel
        c.velocityRange = vel * 0.55
        c.emissionLongitude = lon
        c.emissionRange = range
        c.yAcceleration = ay
        c.xAcceleration = ax
        c.scale = scale
        c.scaleRange = scale * 0.6
        c.scaleSpeed = -scale * 0.25
        c.alphaSpeed = fade
        c.spin = 1.5
        c.spinRange = 6
        c.color = color.cgColor
        return c
    }

    /// Draws the name once, for this screen size, and works out the order it will burn in.
    func build(size: CGSize, title: UIFont, day: UIFont, gold: UIColor, cream: UIColor) {
        if size == builtFor || size.width < 50 { return }
        builtFor = size
        ash.frame = CGRect(origin: .zero, size: size)
        ember.frame = CGRect(origin: .zero, size: size)
        func name(_ col: UIColor) -> NSAttributedString {
            return NSAttributedString(string: "Dustfall III", attributes: [.font: title, .foregroundColor: col, .kern: 2])
        }
        let ts = name(gold).size()
        let sh = NSShadow()
        sh.shadowColor = UIColor.black
        sh.shadowBlurRadius = 4
        sh.shadowOffset = .zero
        let dayStr = NSAttributedString(string: "Day 1", attributes: [.font: day, .foregroundColor: cream, .kern: 3, .shadow: sh])
        let ds = dayStr.size()
        let lw = ts.width + 44, lh = ts.height + ds.height + 22
        var k: CGFloat = 1
        if lw > size.width * 0.9 { k = size.width * 0.9 / lw }
        let s = 2 * k
        pw = max(8, Int(lw * s)); ph = max(8, Int(lh * s))
        box = CGRect(x: (size.width - lw * k) / 2, y: size.height * 0.15, width: lw * k, height: lh * k)
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: pw * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { pw = 0; return }
        ctx.translateBy(x: 0, y: CGFloat(ph))
        ctx.scaleBy(x: s, y: -s)
        UIGraphicsPushContext(ctx)
        name(UIColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 1)).draw(at: CGPoint(x: 22, y: 8))
        name(UIColor(red: 0.54, green: 0.18, blue: 0.15, alpha: 1)).draw(at: CGPoint(x: 22, y: 5))
        name(gold).draw(at: CGPoint(x: 22, y: 1))
        let dy = ts.height + 8
        dayStr.draw(at: CGPoint(x: (lw - ds.width) / 2, y: dy))
        gold.setFill()
        let ruleW = max(10, (lw - ds.width) / 2 - lw * 0.16 - 18)
        UIRectFill(CGRect(x: lw * 0.16, y: dy + ds.height / 2, width: ruleW, height: 2))
        UIRectFill(CGRect(x: lw * 0.84 - ruleW, y: dy + ds.height / 2, width: ruleW, height: 2))
        UIGraphicsPopContext()
        guard let d = ctx.data else { pw = 0; return }
        src = Array(UnsafeBufferPointer(start: d.assumingMemoryBound(to: UInt8.self), count: pw * ph * 4))
        thr = [Float](repeating: 0, count: pw * ph)
        solid = []
        func h(_ a: Int, _ b: Int, _ seed: Int) -> Float {
            var v = UInt32(truncatingIfNeeded: a &* 374761393 &+ b &* 668265263 &+ seed &* 1442695041)
            v = (v ^ (v >> 13)) &* 1274126177
            v ^= v >> 16
            return Float(v & 0xffff) / 65535
        }
        func vn(_ x: Int, _ y: Int, _ cell: Int, _ seed: Int) -> Float {
            let gx = x / cell, gy = y / cell
            let fx = Float(x % cell) / Float(cell), fy = Float(y % cell) / Float(cell)
            let ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
            let a = h(gx, gy, seed), b = h(gx + 1, gy, seed), c = h(gx, gy + 1, seed), e = h(gx + 1, gy + 1, seed)
            return (a + (b - a) * ux) * (1 - uy) + (c + (e - c) * ux) * uy
        }
        let fw = Float(pw)
        for y in 0..<ph {
            for x in 0..<pw {
                let i = y * pw + x
                if src[i * 4 + 3] == 0 { continue }
                solid.append(Int32(i))
                thr[i] = 0.08 + 0.72 * Float(x) / fw + 0.14 * vn(x, y, 46, 1) + 0.06 * vn(x, y, 13, 2) + 0.02 * h(x, y, 3)
            }
        }
        render()
    }

    /// Whole again, and waiting.
    func reset() {
        lit = false; started = false
        p = 0; wait = 0; tail = 0
        ash.birthRate = 0; ember.birthRate = 0
        render()
    }

    func ignite(after: Double) {
        lit = true
        wait = after
    }

    /// Moves the fire along. False once the last of the ash has blown away.
    func step(_ dt: Double) -> Bool {
        if !lit { return true }
        if wait > 0 { wait -= dt; return true }
        if !started {
            started = true
            p = 0
            onStart?()
            ash.birthRate = 1; ember.birthRate = 1
        }
        if p < 1.06 {
            p += dt / 2.7 * 1.06
            if let f = frozen { p = min(p, f) }
            render()
            let u = CGFloat((p - 0.19) / 0.72)
            CATransaction.begin(); CATransaction.setDisableActions(true)
            for e in [ash, ember] {
                e.emitterPosition = CGPoint(x: box.minX + min(max(u, 0), 1) * box.width, y: box.midY)
                e.emitterSize = CGSize(width: box.width * 0.07, height: box.height * 0.72)
            }
            if u > 1.03 || p >= 1.06 { ash.birthRate = 0; ember.birthRate = 0 }
            CATransaction.commit()
            return true
        }
        tail += dt
        return tail < 3.2
    }

    private func render() {
        if pw == 0 || src.isEmpty { return }
        var out = [UInt8](repeating: 0, count: pw * ph * 4)
        let pf: Float = started ? Float(p) : -1
        src.withUnsafeBufferPointer { s in
            thr.withUnsafeBufferPointer { t in
                solid.withUnsafeBufferPointer { ix in
                    out.withUnsafeMutableBufferPointer { o in
                        for n in 0..<ix.count {
                            let i = Int(ix[n])
                            let d = t[i] - pf
                            if d <= 0 { continue }
                            let j = i * 4
                            let a = Float(s[j + 3])
                            if d < 0.018 {
                                o[j] = UInt8(a); o[j + 1] = UInt8(a * 0.93); o[j + 2] = UInt8(a * 0.62)
                            } else if d < 0.045 {
                                o[j] = UInt8(a); o[j + 1] = UInt8(a * 0.52); o[j + 2] = UInt8(a * 0.14)
                            } else if d < 0.11 {
                                let k = (d - 0.045) / 0.065, m = 1 - k
                                o[j] = UInt8(Float(s[j]) * k + a * 0.17 * m)
                                o[j + 1] = UInt8(Float(s[j + 1]) * k + a * 0.09 * m)
                                o[j + 2] = UInt8(Float(s[j + 2]) * k + a * 0.05 * m)
                            } else {
                                o[j] = s[j]; o[j + 1] = s[j + 1]; o[j + 2] = s[j + 2]
                            }
                            o[j + 3] = s[j + 3]
                        }
                    }
                }
            }
        }
        guard let prov = CGDataProvider(data: Data(out) as CFData),
              let img = CGImage(width: pw, height: ph, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: pw * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: prov, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        pic.frame = box
        pic.contents = img
        CATransaction.commit()
    }
}
