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
