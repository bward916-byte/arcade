import UIKit

/// The strip across the top of the screen. Each fact gets its own pill with a small drawn icon:
/// coins, the vault, the ankh, arrows and people on the left; the day dial on the right.
final class HudBar: UIView {
    var coins = 0
    /// Coins in the treasury, or -1 before there is a treasury.
    var vault = -1
    var arrows = 0
    var arrowMax = 6
    var restring = false
    var people = 0
    var cap = 0
    var free = 0
    var ankh = false
    var night = false
    var dayText = ""
    /// How far through the day and night cycle, 0 to 1.
    var frac = 0.0
    var leftInset: CGFloat = 12
    var rightInset: CGFloat = 60
    /// Where the people pill was last drawn, so a tap on it can open the jobs list.
    private(set) var peopleRect = CGRect.zero

    private var sig = ""
    private let ink = UIColor(red: 0.11, green: 0.075, blue: 0.047, alpha: 1)
    private let gold = UIColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1)
    private let cream = UIColor(red: 0.97, green: 0.93, blue: 0.84, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Redraws only when something shown has changed.
    func refresh() {
        let s = "\(coins)|\(vault)|\(arrows)|\(arrowMax)|\(restring)|\(people)|\(cap)|\(free)|\(ankh)|\(night)|\(dayText)|\(Int(frac * 90))|\(Int(leftInset))|\(Int(rightInset))"
        if s != sig { sig = s; setNeedsDisplay() }
    }

    private func font(_ s: CGFloat) -> UIFont {
        return UIFont(name: "Georgia-Bold", size: s) ?? UIFont.boldSystemFont(ofSize: s)
    }
    private func width(_ t: String, _ size: CGFloat) -> CGFloat {
        return (t as NSString).size(withAttributes: [.font: font(size)]).width
    }
    private func text(_ t: String, _ x: CGFloat, _ cy: CGFloat, _ size: CGFloat, _ col: UIColor) {
        let a: [NSAttributedString.Key: Any] = [.font: font(size), .foregroundColor: col]
        let str = t as NSString
        let sz = str.size(withAttributes: a)
        str.draw(at: CGPoint(x: x, y: cy - sz.height / 2), withAttributes: a)
    }
    private func pill(_ x: CGFloat, _ w: CGFloat) {
        let p = UIBezierPath(roundedRect: CGRect(x: x, y: 4.5, width: w, height: 26), cornerRadius: 13)
        ink.withAlphaComponent(0.66).setFill()
        p.fill()
        gold.withAlphaComponent(0.5).setStroke()
        p.lineWidth = 1
        p.stroke()
    }

    private func coinIcon(_ cx: CGFloat, _ cy: CGFloat) {
        let r: CGFloat = 7.5
        gold.setFill()
        UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
        let ring = UIBezierPath(ovalIn: CGRect(x: cx - r + 2, y: cy - r + 2, width: r * 2 - 4, height: r * 2 - 4))
        UIColor(red: 0.7, green: 0.48, blue: 0.12, alpha: 1).setStroke()
        ring.lineWidth = 1.2
        ring.stroke()
        UIColor(white: 1, alpha: 0.7).setFill()
        UIBezierPath(ovalIn: CGRect(x: cx - 4.4, y: cy - 4.6, width: 2.6, height: 2.6)).fill()
    }
    private func chestIcon(_ x: CGFloat, _ cy: CGFloat) {
        UIColor(red: 0.5, green: 0.32, blue: 0.16, alpha: 1).setFill()
        UIBezierPath(roundedRect: CGRect(x: x, y: cy - 6, width: 16, height: 12), cornerRadius: 2.5).fill()
        UIColor(red: 0.36, green: 0.22, blue: 0.1, alpha: 1).setFill()
        UIRectFill(CGRect(x: x, y: cy - 2.2, width: 16, height: 1.2))
        gold.setFill()
        UIRectFill(CGRect(x: x + 6.5, y: cy - 6, width: 3, height: 12))
        UIBezierPath(ovalIn: CGRect(x: x + 6, y: cy - 3.4, width: 4, height: 4)).fill()
    }
    private func ankhIcon(_ cx: CGFloat, _ cy: CGFloat) {
        gold.setStroke()
        let loop = UIBezierPath(ovalIn: CGRect(x: cx - 3, y: cy - 8.5, width: 6, height: 7.5))
        loop.lineWidth = 2
        loop.stroke()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: cx, y: cy - 1)); p.addLine(to: CGPoint(x: cx, y: cy + 8.5))
        p.move(to: CGPoint(x: cx - 4.5, y: cy + 1.2)); p.addLine(to: CGPoint(x: cx + 4.5, y: cy + 1.2))
        p.lineWidth = 2
        p.lineCapStyle = .round
        p.stroke()
    }
    private func arrowIcon(_ x: CGFloat, _ cy: CGFloat) {
        cream.setStroke()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: x, y: cy + 5)); p.addLine(to: CGPoint(x: x + 11, y: cy - 6))
        p.move(to: CGPoint(x: x + 5.5, y: cy - 6)); p.addLine(to: CGPoint(x: x + 11, y: cy - 6)); p.addLine(to: CGPoint(x: x + 11, y: cy - 0.5))
        p.move(to: CGPoint(x: x, y: cy + 1.5)); p.addLine(to: CGPoint(x: x, y: cy + 5)); p.addLine(to: CGPoint(x: x + 3.5, y: cy + 5))
        p.lineWidth = 1.8
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        p.stroke()
    }
    private func personIcon(_ cx: CGFloat, _ cy: CGFloat) {
        cream.setFill()
        UIBezierPath(ovalIn: CGRect(x: cx - 3.4, y: cy - 8.5, width: 6.8, height: 6.8)).fill()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: cx - 7, y: cy + 8))
        p.addQuadCurve(to: CGPoint(x: cx + 7, y: cy + 8), controlPoint: CGPoint(x: cx, y: cy - 8))
        p.close()
        p.fill()
    }

    override func draw(_ rect: CGRect) {
        let cy: CGFloat = 17.5
        var x = leftInset

        // coins in hand
        let ct = "\(coins)"
        var w = 31 + width(ct, 16) + 12
        pill(x, w)
        coinIcon(x + 16, cy)
        text(ct, x + 29, cy, 16, cream)
        x += w + 6

        // the treasury
        if vault >= 0 {
            let vt = "\(vault)"
            w = 34 + width(vt, 16) + 12
            pill(x, w)
            chestIcon(x + 10, cy)
            text(vt, x + 32, cy, 16, cream)
            x += w + 6
        }

        // arrows: one bar each, dim while the bow is being restrung
        w = 30 + CGFloat(arrowMax) * 6 + 8
        pill(x, w)
        arrowIcon(x + 10, cy)
        for i in 0..<max(0, arrowMax) {
            let on = !restring && i < arrows
            (on ? cream : cream.withAlphaComponent(0.22)).setFill()
            UIBezierPath(roundedRect: CGRect(x: x + 28 + CGFloat(i) * 6, y: cy - 6.5, width: 3.4, height: 13), cornerRadius: 1.7).fill()
        }
        x += w + 6

        // people, with how many have nothing to do
        let pt = "\(people)/\(cap)"
        let ft = "\(free) free"
        w = 28 + width(pt, 16) + 8 + width(ft, 12) + 12
        pill(x, w)
        peopleRect = CGRect(x: x - 4, y: 0, width: w + 8, height: 40)
        personIcon(x + 15, cy)
        text(pt, x + 27, cy, 16, cream)
        text(ft, x + 27 + width(pt, 16) + 8, cy + 0.5, 12, free > 0 ? gold : cream.withAlphaComponent(0.6))
        x += w + 6

        if ankh {
            pill(x, 28)
            ankhIcon(x + 14, cy)
            x += 34
        }

        // the day dial: an arc that fills as the day and night go round
        w = 36 + width(dayText, 15) + 12
        let dx = bounds.width - rightInset - w
        if dx > x {
            pill(dx, w)
            let c = CGPoint(x: dx + 17, y: cy)
            let track = UIBezierPath(arcCenter: c, radius: 8.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            cream.withAlphaComponent(0.25).setStroke()
            track.lineWidth = 2
            track.stroke()
            let tint = night ? UIColor(red: 0.66, green: 0.76, blue: 1, alpha: 1) : gold
            let k = CGFloat(max(0, min(1, frac)))
            let arc = UIBezierPath(arcCenter: c, radius: 8.5, startAngle: -.pi / 2, endAngle: -.pi / 2 + k * .pi * 2, clockwise: true)
            tint.setStroke()
            arc.lineWidth = 2.6
            arc.lineCapStyle = .round
            arc.stroke()
            tint.setFill()
            UIBezierPath(ovalIn: CGRect(x: c.x - 4.2, y: c.y - 4.2, width: 8.4, height: 8.4)).fill()
            if night {
                // bite a crescent out of the moon
                UIColor(red: 0.13, green: 0.1, blue: 0.09, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: c.x - 1.6, y: c.y - 5, width: 7.4, height: 7.4)).fill()
            }
            text(dayText, dx + 32, cy, 15, cream)
        }
    }
}

/// The card at the bottom of the screen: what you are standing at, how far along it is, and one line on what a coin does.
final class InfoCard: UIView {
    private var title = ""
    private var line = ""
    private var level = -1
    private var top = 0
    private var paid = 0
    private var cost = 0
    private var sig = ""
    private let ink = UIColor(red: 0.11, green: 0.075, blue: 0.047, alpha: 1)
    private let gold = UIColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1)
    private let cream = UIColor(red: 0.97, green: 0.93, blue: 0.84, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    func show(_ title: String, _ line: String, level: Int = -1, top: Int = 0, paid: Int = 0, cost: Int = 0) {
        let s = "\(title)|\(line)|\(level)|\(top)|\(paid)|\(cost)"
        if s == sig { return }
        sig = s
        self.title = title; self.line = line; self.level = level; self.top = top; self.paid = paid; self.cost = cost
        setNeedsDisplay()
    }
    private func font(_ s: CGFloat) -> UIFont {
        return UIFont(name: "Georgia-Bold", size: s) ?? UIFont.boldSystemFont(ofSize: s)
    }
    private func width(_ t: String, _ size: CGFloat) -> CGFloat {
        return (t as NSString).size(withAttributes: [.font: font(size)]).width
    }
    override func draw(_ rect: CGRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let bg = UIBezierPath(roundedRect: r, cornerRadius: 12)
        ink.withAlphaComponent(0.8).setFill()
        bg.fill()
        gold.withAlphaComponent(0.5).setStroke()
        bg.lineWidth = 1
        bg.stroke()

        // top row: the name, level pips, and coins paid of coins needed on the right
        let ty: CGFloat = 13
        var x: CGFloat = 14
        let ta: [NSAttributedString.Key: Any] = [.font: font(13), .foregroundColor: gold, .kern: 0.8]
        let ts = title as NSString
        let tsz = ts.size(withAttributes: ta)
        ts.draw(at: CGPoint(x: x, y: ty - tsz.height / 2), withAttributes: ta)
        x += tsz.width + 10
        if level >= 0 && top > 0 {
            for i in 0..<top {
                (i < level ? gold : cream.withAlphaComponent(0.25)).setFill()
                UIBezierPath(roundedRect: CGRect(x: x + CGFloat(i) * 9, y: ty - 3.5, width: 7, height: 7), cornerRadius: 2).fill()
            }
        }
        if cost > 0 {
            let ct = "\(paid)/\(cost)"
            let cw = width(ct, 14)
            let cx = bounds.width - 14 - cw
            let ca: [NSAttributedString.Key: Any] = [.font: font(14), .foregroundColor: cream]
            (ct as NSString).draw(at: CGPoint(x: cx, y: ty - 8.5), withAttributes: ca)
            gold.setFill()
            UIBezierPath(ovalIn: CGRect(x: cx - 17, y: ty - 6, width: 12, height: 12)).fill()
            UIColor(red: 0.7, green: 0.48, blue: 0.12, alpha: 1).setStroke()
            let ring = UIBezierPath(ovalIn: CGRect(x: cx - 15, y: ty - 4, width: 8, height: 8))
            ring.lineWidth = 1
            ring.stroke()
        }
        // second row: one line, shrunk a little if it is long, cut with an ellipsis if it still will not fit
        let avail = bounds.width - 28
        var size: CGFloat = 13
        while size > 10.5 && width(line, size) > avail { size -= 0.5 }
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byTruncatingTail
        let la: [NSAttributedString.Key: Any] = [.font: font(size), .foregroundColor: cream, .paragraphStyle: ps]
        (line as NSString).draw(in: CGRect(x: 14, y: 25, width: avail, height: 18), withAttributes: la)
    }
}

/// The morning's account: what each source paid, the total, and how last night went.
final class DawnCard: UIView {
    private var day = 0
    private var income: [(String, Int)] = []
    private var night: (n: Int, down: Int, gates: Int, lost: Int)?
    private var sig = ""
    private let ink = UIColor(red: 0.11, green: 0.075, blue: 0.047, alpha: 1)
    private let gold = UIColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1)
    private let cream = UIColor(red: 0.97, green: 0.93, blue: 0.84, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Three sources to a row.
    var wantHeight: CGFloat {
        let rows = CGFloat((income.count + 2) / 3)
        return 38 + rows * 24 + (night != nil ? 34 : 0) + 8
    }
    func show(day: Int, income: [(String, Int)], night: (n: Int, down: Int, gates: Int, lost: Int)?) {
        var s = "\(day)"
        for it in income { s += "|\(it.0)\(it.1)" }
        if let n = night { s += "|\(n.n),\(n.down),\(n.gates),\(n.lost)" }
        if s == sig { return }
        sig = s
        self.day = day; self.income = income; self.night = night
        setNeedsDisplay()
    }
    private func font(_ s: CGFloat) -> UIFont {
        return UIFont(name: "Georgia-Bold", size: s) ?? UIFont.boldSystemFont(ofSize: s)
    }
    private func put(_ t: String, _ x: CGFloat, _ cy: CGFloat, _ size: CGFloat, _ col: UIColor, right: Bool = false) -> CGFloat {
        let a: [NSAttributedString.Key: Any] = [.font: font(size), .foregroundColor: col]
        let str = t as NSString
        let sz = str.size(withAttributes: a)
        str.draw(at: CGPoint(x: right ? x - sz.width : x, y: cy - sz.height / 2), withAttributes: a)
        return sz.width
    }
    private func coin(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        gold.setFill()
        UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
        UIColor(red: 0.7, green: 0.48, blue: 0.12, alpha: 1).setStroke()
        let ring = UIBezierPath(ovalIn: CGRect(x: cx - r + 1.6, y: cy - r + 1.6, width: r * 2 - 3.2, height: r * 2 - 3.2))
        ring.lineWidth = 1
        ring.stroke()
    }
    override func draw(_ rect: CGRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let bg = UIBezierPath(roundedRect: r, cornerRadius: 14)
        ink.withAlphaComponent(0.84).setFill()
        bg.fill()
        gold.withAlphaComponent(0.6).setStroke()
        bg.lineWidth = 1.2
        bg.stroke()

        // header: a small rising sun, the day, and the morning's total on the right
        let hy: CGFloat = 19
        gold.setFill()
        UIBezierPath(arcCenter: CGPoint(x: 24, y: hy + 5), radius: 7, startAngle: .pi, endAngle: 0, clockwise: true).fill()
        gold.setStroke()
        let rays = UIBezierPath()
        for i in 0..<5 {
            let a = CGFloat.pi + CGFloat(i) * .pi / 4
            rays.move(to: CGPoint(x: 24 + cos(a) * 9.5, y: hy + 5 + sin(a) * 9.5)); rays.addLine(to: CGPoint(x: 24 + cos(a) * 13, y: hy + 5 + sin(a) * 13))
        }
        rays.lineWidth = 1.6
        rays.lineCapStyle = .round
        rays.stroke()
        UIBezierPath(rect: CGRect(x: 12, y: hy + 5, width: 24, height: 1.4)).fill()
        _ = put("DAWN OF DAY \(day)", 44, hy, 14, gold)
        let total = income.reduce(0) { $0 + $1.1 }
        if total > 0 {
            let w = put("+\(total)", bounds.width - 14, hy, 17, cream, right: true)
            coin(bounds.width - 14 - w - 12, hy, 7)
        }
        cream.withAlphaComponent(0.2).setFill()
        UIRectFill(CGRect(x: 12, y: 34, width: bounds.width - 24, height: 1))

        // the sources, three to a row: amount in gold, then the name
        let colW = (bounds.width - 28) / 3
        for (i, it) in income.enumerated() {
            let cx = 14 + CGFloat(i % 3) * colW, cy = 50 + CGFloat(i / 3) * 24
            let w = put("\(it.1)", cx, cy, 15, gold)
            _ = put(it.0.prefix(1).uppercased() + it.0.dropFirst(), cx + w + 6, cy, 12.5, cream)
        }

        // last night, as four short facts
        if let n = night {
            let top = 38 + CGFloat((income.count + 2) / 3) * 24
            cream.withAlphaComponent(0.2).setFill()
            UIRectFill(CGRect(x: 12, y: top + 2, width: bounds.width - 24, height: 1))
            let ny = top + 19
            var x: CGFloat = 14
            x += put("LAST NIGHT", x, ny, 11, gold) + 12
            let facts: [(String, String, Bool)] = [("\(n.n)", "raiders", false), ("\(n.down)", "brought down", false),
                                                   (n.gates > 0 ? "\(n.gates)" : "", n.gates > 0 ? "gate\(n.gates > 1 ? "s" : "") broken" : "gates held", n.gates > 0),
                                                   ("\(n.lost)", "robbed", n.lost > 0)]
            let bad = UIColor(red: 1, green: 0.5, blue: 0.4, alpha: 1)
            for f in facts {
                if !f.0.isEmpty { x += put(f.0, x, ny, 14, f.2 ? bad : cream) + 4 }
                x += put(f.1, x, ny + 0.5, 11.5, cream.withAlphaComponent(0.75)) + 12
            }
        }
    }
}

/// The end-of-run summary: a night picture of riders with lanterns across the top, then the numbers as tiles.
final class SummaryView: UIView {
    private var title = ""
    private var sub = ""
    private var tiles: [(String, String)] = []
    private var footer = ""
    private var sig = ""
    private let gold = UIColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1)
    private let cream = UIColor(red: 0.97, green: 0.93, blue: 0.84, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    func show(title: String, sub: String, tiles: [(String, String)], footer: String) {
        var s = title + sub + footer
        for t in tiles { s += t.0 + t.1 }
        if s == sig { return }
        sig = s
        self.title = title; self.sub = sub; self.tiles = tiles; self.footer = footer
        setNeedsDisplay()
    }
    private func font(_ s: CGFloat) -> UIFont {
        return UIFont(name: "Georgia-Bold", size: s) ?? UIFont.boldSystemFont(ofSize: s)
    }
    private func centred(_ t: String, _ cx: CGFloat, _ cy: CGFloat, _ size: CGFloat, _ col: UIColor) {
        let a: [NSAttributedString.Key: Any] = [.font: font(size), .foregroundColor: col]
        let str = t as NSString
        let sz = str.size(withAttributes: a)
        str.draw(at: CGPoint(x: cx - sz.width / 2, y: cy - sz.height / 2), withAttributes: a)
    }
    /// A camel and rider in silhouette, feet at (x, y), carrying a lantern.
    private func rider(_ cg: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat) {
        let dark = UIColor(red: 0.03, green: 0.03, blue: 0.08, alpha: 1)
        dark.setFill(); dark.setStroke()
        UIBezierPath(ovalIn: CGRect(x: x - 9 * s, y: y - 13 * s, width: 18 * s, height: 8 * s)).fill()
        let legs = UIBezierPath()
        for lx in [-6, -3, 3.4, 6.4] as [CGFloat] { legs.move(to: CGPoint(x: x + lx * s, y: y - 7 * s)); legs.addLine(to: CGPoint(x: x + lx * s, y: y)) }
        legs.move(to: CGPoint(x: x + 7 * s, y: y - 10 * s)); legs.addLine(to: CGPoint(x: x + 12 * s, y: y - 18 * s))
        legs.lineWidth = 1.6 * s
        legs.lineCapStyle = .round
        legs.stroke()
        UIBezierPath(ovalIn: CGRect(x: x + 10.6 * s, y: y - 20.6 * s, width: 6 * s, height: 3.6 * s)).fill()
        UIBezierPath(roundedRect: CGRect(x: x - 2.8 * s, y: y - 22 * s, width: 5.6 * s, height: 10 * s), cornerRadius: 2 * s).fill()
        UIBezierPath(ovalIn: CGRect(x: x - 2.6 * s, y: y - 26.6 * s, width: 5.2 * s, height: 5.2 * s)).fill()
        // the lantern and its glow
        let lc = CGPoint(x: x + 5 * s, y: y - 17 * s)
        let cols = [UIColor(red: 1, green: 0.8, blue: 0.45, alpha: 0.75).cgColor, UIColor(red: 1, green: 0.8, blue: 0.45, alpha: 0).cgColor] as CFArray
        if let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
            cg.drawRadialGradient(gr, startCenter: lc, startRadius: 0, endCenter: lc, endRadius: 15 * s, options: [])
        }
        UIColor(red: 1, green: 0.95, blue: 0.72, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: lc.x - 1.4 * s, y: lc.y - 1.8 * s, width: 2.8 * s, height: 3.6 * s)).fill()
    }
    override func draw(_ rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let w = bounds.width
        let artH: CGFloat = 86
        // the picture: night sky, a moon, a ridge, and the lantern train crossing it
        cg.saveGState()
        UIBezierPath(roundedRect: CGRect(x: 3, y: 3, width: w - 6, height: artH + 14), cornerRadius: 15).addClip()
        cg.clip(to: CGRect(x: 0, y: 0, width: w, height: artH + 3))
        let sky = [UIColor(red: 0.05, green: 0.06, blue: 0.19, alpha: 1).cgColor, UIColor(red: 0.2, green: 0.18, blue: 0.38, alpha: 1).cgColor] as CFArray
        if let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sky, locations: [0, 1]) {
            cg.drawLinearGradient(gr, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: artH + 3), options: [])
        }
        for i in 0..<46 {
            let hx = CGFloat((i * 7919) % 997) / 997, hyy = CGFloat((i * 104729) % 991) / 991
            UIColor(white: 1, alpha: 0.35 + 0.5 * CGFloat(i % 5) / 5).setFill()
            UIRectFill(CGRect(x: 6 + hx * (w - 12), y: 6 + hyy * (artH * 0.6), width: 1.2, height: 1.2))
        }
        let mc = CGPoint(x: w - 54, y: 28)
        let halo = [UIColor(red: 0.86, green: 0.9, blue: 1, alpha: 0.45).cgColor, UIColor(red: 0.86, green: 0.9, blue: 1, alpha: 0).cgColor] as CFArray
        if let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: halo, locations: [0, 1]) {
            cg.drawRadialGradient(gr, startCenter: mc, startRadius: 0, endCenter: mc, endRadius: 30, options: [])
        }
        UIColor(red: 0.93, green: 0.94, blue: 1, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: mc.x - 10, y: mc.y - 10, width: 20, height: 20)).fill()
        UIColor(red: 0.08, green: 0.09, blue: 0.24, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: mc.x - 5.5, y: mc.y - 12, width: 18, height: 18)).fill()
        func ridge(_ h: CGFloat, _ ph: CGFloat, _ x: CGFloat) -> CGFloat { return artH - 6 - h * (0.5 + 0.5 * sin(x * 0.016 + ph)) }
        let back = UIBezierPath()
        back.move(to: CGPoint(x: 0, y: artH + 4))
        var x: CGFloat = 0
        while x <= w { back.addLine(to: CGPoint(x: x, y: ridge(34, 0.8, x))); x += 6 }
        back.addLine(to: CGPoint(x: w, y: artH + 4))
        UIColor(red: 0.17, green: 0.16, blue: 0.36, alpha: 1).setFill()
        back.fill()
        let n = max(4, Int(w / 100))
        for i in 0..<n {
            let rx = 40 + CGFloat(i) * (w - 110) / CGFloat(n - 1)
            rider(cg, rx, ridge(34, 0.8, rx) + 1.5, 1.25)
        }
        let front = UIBezierPath()
        front.move(to: CGPoint(x: 0, y: artH + 4))
        x = 0
        while x <= w { front.addLine(to: CGPoint(x: x, y: ridge(12, 2.6, x) + 6)); x += 6 }
        front.addLine(to: CGPoint(x: w, y: artH + 4))
        UIColor(red: 0.06, green: 0.06, blue: 0.16, alpha: 1).setFill()
        front.fill()
        cg.restoreGState()
        gold.withAlphaComponent(0.7).setFill()
        UIRectFill(CGRect(x: 3, y: artH + 3, width: w - 6, height: 1.5))

        // words and numbers
        centred(title, w / 2, artH + 24, 24, gold)
        var y = artH + 44
        if !sub.isEmpty { centred(sub, w / 2, artH + 48, 13, cream.withAlphaComponent(0.9)); y = artH + 64 }
        let cols = min(4, max(1, tiles.count))
        let gap: CGFloat = 8
        let tw = (w - 40 - gap * CGFloat(cols - 1)) / CGFloat(cols)
        for (i, t) in tiles.enumerated() {
            let tx = 20 + CGFloat(i % cols) * (tw + gap), ty = y + CGFloat(i / cols) * 50
            let box = UIBezierPath(roundedRect: CGRect(x: tx, y: ty, width: tw, height: 44), cornerRadius: 9)
            UIColor(white: 1, alpha: 0.06).setFill()
            box.fill()
            gold.withAlphaComponent(0.35).setStroke()
            box.lineWidth = 1
            box.stroke()
            centred(t.0, tx + tw / 2, ty + 15, 19, gold)
            centred(t.1, tx + tw / 2, ty + 33, 10.5, cream.withAlphaComponent(0.85))
        }
        if !footer.isEmpty {
            let rows = CGFloat((tiles.count + cols - 1) / cols)
            centred(footer, w / 2, y + rows * 50 + 8, 13, cream)
        }
    }
}
