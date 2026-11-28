import SwiftUI

// The desert scene at the top of each tab: sunset sky, hills, saguaros, an RV and a campfire that flickers.
struct DesertBanner: View {
    let title: String
    let subtitle: String
    var scene = "campfire"   // each tab has its own picture: campfire, market, bigtop or storm
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: still)) { time in
            Canvas { context, size in
                let t = still ? 0 : time.date.timeIntervalSinceReferenceDate
                switch scene {
                case "market": DesertBanner.paintMarket(context, size, t)
                case "bigtop": DesertBanner.paintBigTop(context, size, t)
                case "storm": DesertBanner.paintStorm(context, size, t)
                default: DesertBanner.paint(context, size, t)
                }
            }
        }
        .frame(height: 150)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(.white)
                Text(subtitle).font(.footnote.weight(.semibold)).foregroundColor(.white.opacity(0.9))
            }
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    static func paint(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        let sky = Gradient(colors: [
            Color(red: 0.16, green: 0.20, blue: 0.42), Color(red: 0.52, green: 0.30, blue: 0.52),
            Color(red: 0.93, green: 0.52, blue: 0.33), Color(red: 0.98, green: 0.78, blue: 0.48)
        ])
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

        // Stars that twinkle in the dark part of the sky.
        let stars: [(Double, Double)] = [(0.08, 0.12), (0.22, 0.30), (0.36, 0.10), (0.52, 0.22), (0.66, 0.08), (0.80, 0.26), (0.93, 0.12), (0.45, 0.36)]
        for (i, s) in stars.enumerated() {
            var c = ctx
            c.opacity = 0.35 + 0.45 * (0.5 + 0.5 * sin(t * 1.3 + Double(i) * 1.7))
            c.fill(Path(ellipseIn: CGRect(x: w * s.0, y: h * s.1, width: 2.2, height: 2.2)), with: .color(.white))
        }

        // The sun, low on the horizon, with a soft glow.
        let sun = CGPoint(x: w * 0.74, y: h * 0.60)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 46, y: sun.y - 46, width: 92, height: 92)),
                 with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.93, blue: 0.70).opacity(0.85), .clear]), center: sun, startRadius: 4, endRadius: 46))
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 16, y: sun.y - 16, width: 32, height: 32)), with: .color(Color(red: 1, green: 0.95, blue: 0.78)))

        // Far hills, then the near ground.
        var far = Path()
        far.move(to: CGPoint(x: 0, y: h * 0.74))
        let ridge: [(Double, Double)] = [(0.10, 0.60), (0.20, 0.68), (0.32, 0.52), (0.44, 0.66), (0.58, 0.58), (0.70, 0.70), (0.84, 0.56), (1.0, 0.68)]
        for p in ridge { far.addLine(to: CGPoint(x: w * p.0, y: h * p.1)) }
        far.addLine(to: CGPoint(x: w, y: h)); far.addLine(to: CGPoint(x: 0, y: h)); far.closeSubpath()
        ctx.fill(far, with: .color(Color(red: 0.42, green: 0.26, blue: 0.40)))

        var near = Path()
        near.move(to: CGPoint(x: 0, y: h * 0.84))
        near.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.80), control: CGPoint(x: w * 0.25, y: h * 0.74))
        near.addQuadCurve(to: CGPoint(x: w, y: h * 0.82), control: CGPoint(x: w * 0.78, y: h * 0.88))
        near.addLine(to: CGPoint(x: w, y: h)); near.addLine(to: CGPoint(x: 0, y: h)); near.closeSubpath()
        ctx.fill(near, with: .color(Color(red: 0.20, green: 0.13, blue: 0.20)))

        let dark = Color(red: 0.12, green: 0.08, blue: 0.13)
        saguaro(ctx, CGPoint(x: w * 0.10, y: h * 0.86), 40, dark)
        saguaro(ctx, CGPoint(x: w * 0.30, y: h * 0.82), 26, dark)
        saguaro(ctx, CGPoint(x: w * 0.92, y: h * 0.86), 46, dark)

        // The RV.
        let rv = CGRect(x: w * 0.52, y: h * 0.66, width: 62, height: 24)
        ctx.fill(Path(roundedRect: rv, cornerRadius: 5), with: .color(dark))
        ctx.fill(Path(roundedRect: CGRect(x: rv.minX + 8, y: rv.minY + 5, width: 14, height: 8), cornerRadius: 2), with: .color(Color(red: 1, green: 0.85, blue: 0.5)))
        ctx.fill(Path(roundedRect: CGRect(x: rv.minX + 28, y: rv.minY + 5, width: 14, height: 8), cornerRadius: 2), with: .color(Color(red: 1, green: 0.85, blue: 0.5).opacity(0.7)))
        for dx in [14.0, 48.0] {
            ctx.fill(Path(ellipseIn: CGRect(x: rv.minX + dx - 5, y: rv.maxY - 4, width: 10, height: 10)), with: .color(dark))
        }

        // The campfire: a glow, two logs and three flames that move.
        let fire = CGPoint(x: w * 0.40, y: h * 0.90)
        let flick = 0.5 + 0.5 * sin(t * 9) * sin(t * 5.3)
        ctx.fill(Path(ellipseIn: CGRect(x: fire.x - 34, y: fire.y - 30, width: 68, height: 48)),
                 with: .radialGradient(Gradient(colors: [Color.orange.opacity(0.55 + 0.2 * flick), .clear]), center: fire, startRadius: 2, endRadius: 34))
        for (i, tone) in [Color(red: 0.86, green: 0.24, blue: 0.10), Color.orange, Color.yellow].enumerated() {
            let k = Double(i)
            let tall = (22 - k * 6) * (0.85 + 0.25 * sin(t * (7 + k * 2) + k))
            let wide = 9 - k * 2.5
            let sway = 2.5 * sin(t * 6 + k * 1.3)
            var f = Path()
            f.move(to: CGPoint(x: fire.x - wide, y: fire.y))
            f.addQuadCurve(to: CGPoint(x: fire.x + sway, y: fire.y - tall), control: CGPoint(x: fire.x - wide, y: fire.y - tall * 0.6))
            f.addQuadCurve(to: CGPoint(x: fire.x + wide, y: fire.y), control: CGPoint(x: fire.x + wide, y: fire.y - tall * 0.6))
            f.closeSubpath()
            ctx.fill(f, with: .color(tone))
        }
        var logs = Path()
        logs.move(to: CGPoint(x: fire.x - 13, y: fire.y + 3)); logs.addLine(to: CGPoint(x: fire.x + 13, y: fire.y - 2))
        logs.move(to: CGPoint(x: fire.x - 13, y: fire.y - 2)); logs.addLine(to: CGPoint(x: fire.x + 13, y: fire.y + 3))
        ctx.stroke(logs, with: .color(Color(red: 0.30, green: 0.17, blue: 0.10)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }

    // ---- shared pieces for the other scenes ----

    static func sky(_ ctx: GraphicsContext, _ size: CGSize, _ colors: [Color]) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    // A ridge of hills across the banner, then flat ground in front of it.
    static func land(_ ctx: GraphicsContext, _ size: CGSize, _ ridge: [(Double, Double)], _ hill: Color, _ ground: Color, _ groundTop: Double) {
        let w = size.width, h = size.height
        var far = Path()
        far.move(to: CGPoint(x: 0, y: h * 0.78))
        for p in ridge { far.addLine(to: CGPoint(x: w * p.0, y: h * p.1)) }
        far.addLine(to: CGPoint(x: w, y: h)); far.addLine(to: CGPoint(x: 0, y: h)); far.closeSubpath()
        ctx.fill(far, with: .color(hill))
        ctx.fill(Path(CGRect(x: 0, y: h * groundTop, width: w, height: h * (1 - groundTop))), with: .color(ground))
    }

    static func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
        var p = Path()
        p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath()
        return p
    }

    // For Sale: a morning swap meet. A striped canopy over a table of goods, a pickup, and a string of flags in the breeze.
    static func paintMarket(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        sky(ctx, size, [Color(red: 0.36, green: 0.62, blue: 0.86), Color(red: 0.72, green: 0.84, blue: 0.92), Color(red: 0.99, green: 0.86, blue: 0.66)])
        let sun = CGPoint(x: w * 0.86, y: h * 0.26)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 40, y: sun.y - 40, width: 80, height: 80)),
                 with: .radialGradient(Gradient(colors: [Color.white.opacity(0.9), .clear]), center: sun, startRadius: 4, endRadius: 40))
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 13, y: sun.y - 13, width: 26, height: 26)), with: .color(Color(red: 1, green: 0.97, blue: 0.82)))
        land(ctx, size, [(0.12, 0.62), (0.26, 0.70), (0.40, 0.58), (0.56, 0.68), (0.72, 0.60), (0.88, 0.70), (1.0, 0.64)],
             Color(red: 0.72, green: 0.56, blue: 0.48), Color(red: 0.86, green: 0.72, blue: 0.52), 0.80)

        // The canopy: two poles, a striped roof.
        let left = w * 0.30, right = w * 0.62, top = h * 0.44, eave = h * 0.56, floor = h * 0.86
        let pole = Color(red: 0.35, green: 0.27, blue: 0.22)
        for x in [left + 4, right - 4] {
            ctx.fill(Path(CGRect(x: x - 1.5, y: eave, width: 3, height: floor - eave)), with: .color(pole))
        }
        let stripes = 6
        for i in 0..<stripes {
            let a = left + (right - left) * Double(i) / Double(stripes), b = left + (right - left) * Double(i + 1) / Double(stripes)
            let mid = (left + right) / 2
            var stripe = Path()
            stripe.move(to: CGPoint(x: a, y: eave)); stripe.addLine(to: CGPoint(x: b, y: eave))
            stripe.addLine(to: CGPoint(x: mid + (b - mid) * 0.25, y: top)); stripe.addLine(to: CGPoint(x: mid + (a - mid) * 0.25, y: top)); stripe.closeSubpath()
            ctx.fill(stripe, with: .color(i % 2 == 0 ? Color(red: 0.80, green: 0.26, blue: 0.14) : Color(red: 0.99, green: 0.96, blue: 0.90)))
        }
        // The table, with a few things for sale and a price tag.
        let table = CGRect(x: left + 12, y: h * 0.72, width: right - left - 24, height: 6)
        ctx.fill(Path(roundedRect: table, cornerRadius: 2), with: .color(pole))
        for x in [table.minX + 4, table.maxX - 7] { ctx.fill(Path(CGRect(x: x, y: table.maxY, width: 3, height: floor - table.maxY)), with: .color(pole)) }
        let goods: [(Double, Double, Double, Color)] = [(0.08, 14, 12, Color(red: 0.16, green: 0.45, blue: 0.43)), (0.32, 10, 18, Color(red: 0.93, green: 0.66, blue: 0.23)),
                                                         (0.55, 16, 9, Color(red: 0.43, green: 0.29, blue: 0.66)), (0.80, 11, 14, Color(red: 0.15, green: 0.39, blue: 0.66))]
        for g in goods {
            ctx.fill(Path(roundedRect: CGRect(x: table.minX + table.width * g.0, y: table.minY - g.2, width: g.1, height: g.2), cornerRadius: 2), with: .color(g.3))
        }
        let tag = CGPoint(x: right - 18, y: h * 0.60)
        var tagPath = Path(roundedRect: CGRect(x: tag.x, y: tag.y, width: 20, height: 12), cornerRadius: 3)
        tagPath.addEllipse(in: CGRect(x: tag.x + 2.5, y: tag.y + 4, width: 3, height: 3))
        ctx.fill(tagPath, with: .color(Color(red: 0.99, green: 0.93, blue: 0.70)), style: FillStyle(eoFill: true))

        // A pickup parked beside the stall.
        let truck = CGRect(x: w * 0.70, y: h * 0.70, width: 58, height: 14)
        let body = Color(red: 0.20, green: 0.30, blue: 0.40)
        ctx.fill(Path(roundedRect: truck, cornerRadius: 3), with: .color(body))
        ctx.fill(Path(roundedRect: CGRect(x: truck.minX + 26, y: truck.minY - 11, width: 20, height: 13), cornerRadius: 3), with: .color(body))
        ctx.fill(Path(roundedRect: CGRect(x: truck.minX + 30, y: truck.minY - 8, width: 12, height: 7), cornerRadius: 2), with: .color(Color(red: 0.80, green: 0.90, blue: 0.96)))
        for dx in [12.0, 46.0] { ctx.fill(Path(ellipseIn: CGRect(x: truck.minX + dx - 5, y: truck.maxY - 4, width: 10, height: 10)), with: .color(Color(red: 0.12, green: 0.10, blue: 0.12))) }

        // Flags on a line from the canopy to a pole, lifting in the breeze.
        let from = CGPoint(x: right, y: eave), to = CGPoint(x: w * 0.97, y: h * 0.40)
        var line = Path(); line.move(to: from); line.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: h * 0.58))
        ctx.stroke(line, with: .color(pole), lineWidth: 1)
        let flagColors = [Color(red: 0.80, green: 0.26, blue: 0.14), Color(red: 0.93, green: 0.66, blue: 0.23), Color(red: 0.16, green: 0.45, blue: 0.43), Color(red: 0.43, green: 0.29, blue: 0.66), Color(red: 0.15, green: 0.39, blue: 0.66)]
        for i in 0..<5 {
            let k = (Double(i) + 0.5) / 5
            let x = from.x + (to.x - from.x) * k
            let y = from.y + (to.y - from.y) * k + sin(k * .pi) * h * 0.07
            let lift = 3 * sin(t * 3 + Double(i))
            ctx.fill(triangle(CGPoint(x: x - 5, y: y), CGPoint(x: x + 5, y: y), CGPoint(x: x + lift, y: y + 11)), with: .color(flagColors[i]))
        }
        saguaro(ctx, CGPoint(x: w * 0.10, y: h * 0.88), 42, Color(red: 0.24, green: 0.42, blue: 0.30))
    }

    // Shows: the big tent at night, with pennants on top, a string of lights that twinkle and gems that glint.
    static func paintBigTop(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        sky(ctx, size, [Color(red: 0.07, green: 0.08, blue: 0.24), Color(red: 0.20, green: 0.14, blue: 0.40), Color(red: 0.45, green: 0.22, blue: 0.46)])
        let stars: [(Double, Double)] = [(0.06, 0.16), (0.16, 0.34), (0.30, 0.12), (0.44, 0.26), (0.60, 0.10), (0.74, 0.30), (0.90, 0.14), (0.52, 0.40), (0.95, 0.36)]
        for (i, st) in stars.enumerated() {
            var c = ctx
            c.opacity = 0.4 + 0.5 * (0.5 + 0.5 * sin(t * 1.5 + Double(i) * 1.9))
            c.fill(Path(ellipseIn: CGRect(x: w * st.0, y: h * st.1, width: 2.4, height: 2.4)), with: .color(.white))
        }
        land(ctx, size, [(0.14, 0.66), (0.30, 0.72), (0.50, 0.64), (0.70, 0.72), (0.86, 0.66), (1.0, 0.70)],
             Color(red: 0.18, green: 0.12, blue: 0.28), Color(red: 0.11, green: 0.08, blue: 0.16), 0.84)

        // The tent: a wide striped roof with two peaks, and a lit doorway.
        let left = w * 0.52, right = w * 0.95, eave = h * 0.62, floor = h * 0.86
        // The peaks sit below the title and subtitle so the words stay readable.
        let peaks = [CGPoint(x: left + (right - left) * 0.30, y: h * 0.44), CGPoint(x: left + (right - left) * 0.70, y: h * 0.44)]
        let white = Color(red: 0.98, green: 0.95, blue: 0.88), red = Color(red: 0.78, green: 0.22, blue: 0.20)
        var roof = Path()
        roof.move(to: CGPoint(x: left, y: eave)); roof.addLine(to: peaks[0])
        roof.addQuadCurve(to: peaks[1], control: CGPoint(x: (left + right) / 2, y: h * 0.56))
        roof.addLine(to: CGPoint(x: right, y: eave)); roof.closeSubpath()
        ctx.fill(roof, with: .color(white))
        for i in stride(from: 0, to: 8, by: 2) {
            let a = left + (right - left) * Double(i) / 8, b = left + (right - left) * Double(i + 1) / 8
            ctx.fill(Path(CGRect(x: a, y: eave, width: b - a, height: floor - eave)), with: .color(red))
        }
        for i in stride(from: 1, to: 8, by: 2) {
            let a = left + (right - left) * Double(i) / 8, b = left + (right - left) * Double(i + 1) / 8
            ctx.fill(Path(CGRect(x: a, y: eave, width: b - a, height: floor - eave)), with: .color(white))
        }
        let door = CGRect(x: (left + right) / 2 - 9, y: floor - 20, width: 18, height: 20)
        ctx.fill(Path(roundedRect: door, cornerRadius: 8), with: .color(Color(red: 1, green: 0.84, blue: 0.45)))
        for (i, peak) in peaks.enumerated() {
            ctx.fill(Path(CGRect(x: peak.x - 1, y: peak.y - 16, width: 2, height: 16)), with: .color(white))
            let wave = 3 * sin(t * 4 + Double(i) * 2)
            ctx.fill(triangle(CGPoint(x: peak.x + 1, y: peak.y - 16), CGPoint(x: peak.x + 15, y: peak.y - 12 + wave), CGPoint(x: peak.x + 1, y: peak.y - 8)),
                     with: .color(Color(red: 0.99, green: 0.74, blue: 0.20)))
        }

        // A string of lights from a pole on the left to the tent.
        let a = CGPoint(x: w * 0.06, y: h * 0.46), b = CGPoint(x: left + 2, y: eave - 2)
        ctx.fill(Path(CGRect(x: a.x - 1.5, y: a.y, width: 3, height: floor - a.y)), with: .color(Color(red: 0.10, green: 0.08, blue: 0.14)))
        var wire = Path(); wire.move(to: a); wire.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: h * 0.74))
        ctx.stroke(wire, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
        let bulbs = [Color(red: 1, green: 0.84, blue: 0.4), Color(red: 1, green: 0.5, blue: 0.4), Color(red: 0.5, green: 0.9, blue: 0.8), Color(red: 0.8, green: 0.6, blue: 1)]
        for i in 0..<9 {
            let k = (Double(i) + 0.5) / 9
            let x = a.x + (b.x - a.x) * k
            let y = a.y + (b.y - a.y) * k + sin(k * .pi) * h * 0.13
            var c = ctx
            c.opacity = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 3 + Double(i) * 1.4))
            c.fill(Path(ellipseIn: CGRect(x: x - 3.5, y: y, width: 7, height: 7)), with: .color(bulbs[i % bulbs.count]))
        }

        // Three gems on a stand in front, catching the light.
        let gems = [(0.18, Color(red: 0.45, green: 0.85, blue: 0.95)), (0.27, Color(red: 0.75, green: 0.55, blue: 0.98)), (0.36, Color(red: 0.98, green: 0.62, blue: 0.72))]
        for (i, g) in gems.enumerated() {
            let c0 = CGPoint(x: w * g.0, y: h * 0.80)
            var gem = Path()
            gem.move(to: CGPoint(x: c0.x - 9, y: c0.y - 5)); gem.addLine(to: CGPoint(x: c0.x - 5, y: c0.y - 11)); gem.addLine(to: CGPoint(x: c0.x + 5, y: c0.y - 11))
            gem.addLine(to: CGPoint(x: c0.x + 9, y: c0.y - 5)); gem.addLine(to: CGPoint(x: c0.x, y: c0.y + 7)); gem.closeSubpath()
            ctx.fill(gem, with: .color(g.1))
            var glint = ctx
            glint.opacity = max(0, sin(t * 2 + Double(i) * 2.1))
            glint.fill(Path(ellipseIn: CGRect(x: c0.x - 5, y: c0.y - 10, width: 4, height: 4)), with: .color(.white))
        }
    }

    // Alerts: weather coming in. Dark clouds drift across, rain slants down, lightning flickers and a flag snaps in the wind.
    static func paintStorm(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        sky(ctx, size, [Color(red: 0.16, green: 0.18, blue: 0.26), Color(red: 0.32, green: 0.33, blue: 0.42), Color(red: 0.74, green: 0.58, blue: 0.44)])
        // Lightning: a quick flash every few seconds.
        let beat = t.truncatingRemainder(dividingBy: 5)
        if beat < 0.18 {
            var flash = ctx
            flash.opacity = 0.25
            flash.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var bolt = Path()
            bolt.move(to: CGPoint(x: w * 0.70, y: h * 0.26)); bolt.addLine(to: CGPoint(x: w * 0.66, y: h * 0.44)); bolt.addLine(to: CGPoint(x: w * 0.71, y: h * 0.44))
            bolt.addLine(to: CGPoint(x: w * 0.65, y: h * 0.66))
            ctx.stroke(bolt, with: .color(Color(red: 1, green: 0.96, blue: 0.75)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        land(ctx, size, [(0.10, 0.66), (0.24, 0.58), (0.40, 0.70), (0.56, 0.60), (0.74, 0.70), (0.90, 0.62), (1.0, 0.68)],
             Color(red: 0.30, green: 0.26, blue: 0.32), Color(red: 0.42, green: 0.34, blue: 0.28), 0.84)

        // Rain, slanting with the wind.
        var rain = Path()
        for i in 0..<26 {
            let x = (Double(i) * 0.041 + t * 0.35).truncatingRemainder(dividingBy: 1.1) * w
            let y = ((Double(i) * 0.37 + t * 1.6).truncatingRemainder(dividingBy: 1)) * h * 0.84
            rain.move(to: CGPoint(x: x, y: y)); rain.addLine(to: CGPoint(x: x - 4, y: y + 10))
        }
        ctx.stroke(rain, with: .color(Color.white.opacity(0.35)), lineWidth: 1)

        // Clouds: three banks that drift left to right and wrap around.
        let cloud = Color(red: 0.22, green: 0.23, blue: 0.30)
        for i in 0..<3 {
            let speed = 0.012 + Double(i) * 0.006
            let x = ((Double(i) * 0.42 + t * speed).truncatingRemainder(dividingBy: 1.4) - 0.2) * w
            let y = h * (0.20 + Double(i) * 0.07)
            var c = Path()
            c.addEllipse(in: CGRect(x: x, y: y, width: 70, height: 26))
            c.addEllipse(in: CGRect(x: x + 22, y: y - 14, width: 54, height: 34))
            c.addEllipse(in: CGRect(x: x + 52, y: y - 2, width: 62, height: 26))
            ctx.fill(c, with: .color(cloud.opacity(0.92)))
        }

        // A warning flag on a pole, snapping in the wind, and a cactus leaning into it.
        let poleX = w * 0.16
        ctx.fill(Path(CGRect(x: poleX - 1.5, y: h * 0.46, width: 3, height: h * 0.42)), with: .color(Color(red: 0.12, green: 0.10, blue: 0.12)))
        let snap = 4 * sin(t * 9)
        var flag = Path()
        flag.move(to: CGPoint(x: poleX + 1, y: h * 0.47)); flag.addLine(to: CGPoint(x: poleX + 30, y: h * 0.50 + snap))
        flag.addLine(to: CGPoint(x: poleX + 1, y: h * 0.60)); flag.closeSubpath()
        ctx.fill(flag, with: .color(Color(red: 0.92, green: 0.42, blue: 0.12)))
        saguaro(ctx, CGPoint(x: w * 0.88, y: h * 0.88), 44, Color(red: 0.12, green: 0.14, blue: 0.14))
    }

    static func saguaro(_ ctx: GraphicsContext, _ base: CGPoint, _ tall: Double, _ color: Color) {
        var p = Path()
        p.move(to: base); p.addLine(to: CGPoint(x: base.x, y: base.y - tall))
        p.move(to: CGPoint(x: base.x, y: base.y - tall * 0.45)); p.addLine(to: CGPoint(x: base.x - tall * 0.22, y: base.y - tall * 0.45))
        p.addLine(to: CGPoint(x: base.x - tall * 0.22, y: base.y - tall * 0.72))
        p.move(to: CGPoint(x: base.x, y: base.y - tall * 0.60)); p.addLine(to: CGPoint(x: base.x + tall * 0.22, y: base.y - tall * 0.60))
        p.addLine(to: CGPoint(x: base.x + tall * 0.22, y: base.y - tall * 0.85))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(4, tall * 0.16), lineCap: .round, lineJoin: .round))
    }
}

// Where each camping area sits on the sketch, on a 360 by 400 sheet. lx is which side its name goes on.
private let areaSpots: [String: (x: Double, y: Double, lx: Double, ly: Double)] = [
    "plomosa": (238, 66, 14, 4), "hijolly": (200, 98, 14, 4), "domerock": (58, 176, 0, 26), "scaddan": (300, 178, 0, -18),
    "lpnorth": (206, 214, 14, 4), "lpwest": (154, 232, -14, 4), "lptyson": (154, 286, -14, 4), "lpsouth": (206, 268, 14, 4),
    "roadrunner": (154, 356, -14, 4)
]

// The hand-drawn map of the camping areas, the two highways and Tyson Wash. Tap an area to read about it.
struct AreaMap: View {
    let areas: [GuideArea]
    @Binding var selected: String
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 360
            TimelineView(.animation(minimumInterval: 0.08, paused: still)) { time in
                Canvas { context, _ in
                    paint(context, s, still ? 0 : time.date.timeIntervalSinceReferenceDate)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { point in
                var best = ""
                var bestGap = 30.0 * s
                for a in areas {
                    guard let spot = areaSpots[a.id] else { continue }
                    let gap = hypot(point.x - spot.x * s, point.y - spot.y * s)
                    if gap < bestGap { bestGap = gap; best = a.id }
                }
                if !best.isEmpty { withAnimation { selected = selected == best ? "" : best } }
            }
        }
        .aspectRatio(360.0 / 400.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel("Sketch map of the camping areas around Quartzsite")
    }

    private func paint(_ ctx: GraphicsContext, _ s: Double, _ t: Double) {
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        let ink = Color(red: 0.25, green: 0.20, blue: 0.16)
        let sand = Gradient(colors: [Color(red: 0.97, green: 0.90, blue: 0.76), Color(red: 0.91, green: 0.79, blue: 0.62)])
        ctx.fill(Path(CGRect(x: 0, y: 0, width: 360 * s, height: 400 * s)), with: .linearGradient(sand, startPoint: .zero, endPoint: pt(0, 400)))

        // Contour rings for the hills.
        let hills: [(Double, Double, [(Double, Double)])] = [
            (52, 196, [(46, 30), (30, 18), (14, 8)]), (292, 82, [(52, 30), (34, 18), (16, 8)]), (300, 320, [(48, 40), (28, 22)])
        ]
        for hill in hills {
            for r in hill.2 {
                ctx.stroke(Path(ellipseIn: CGRect(x: (hill.0 - r.0) * s, y: (hill.1 - r.1) * s, width: r.0 * 2 * s, height: r.1 * 2 * s)),
                           with: .color(ink.opacity(0.18)), lineWidth: 1)
            }
        }
        for m in [(40.0, 232.0), (300, 70), (296, 312), (322, 330)] {
            var p = Path()
            p.move(to: pt(m.0 - 14, m.1)); p.addLine(to: pt(m.0 - 6, m.1 - 11)); p.addLine(to: pt(m.0 - 1, m.1 - 5))
            p.addLine(to: pt(m.0 + 4, m.1 - 14)); p.addLine(to: pt(m.0 + 14, m.1))
            ctx.stroke(p, with: .color(ink.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round, lineJoin: .round))
        }
        for c in [(96.0, 92.0), (110, 60), (318, 270), (60, 300), (326, 232), (270, 382)] {
            var p = Path()
            p.move(to: pt(c.0, c.1)); p.addLine(to: pt(c.0, c.1 - 16))
            p.move(to: pt(c.0, c.1 - 7)); p.addLine(to: pt(c.0 - 5, c.1 - 7)); p.addLine(to: pt(c.0 - 5, c.1 - 12))
            p.move(to: pt(c.0, c.1 - 10)); p.addLine(to: pt(c.0 + 5, c.1 - 10)); p.addLine(to: pt(c.0 + 5, c.1 - 14))
            ctx.stroke(p, with: .color(Color(red: 0.36, green: 0.48, blue: 0.30).opacity(0.75)), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round, lineJoin: .round))
        }

        // Tyson Wash, drawn as water that flows.
        var wash = Path()
        wash.move(to: pt(128, 400))
        wash.addCurve(to: pt(130, 286), control1: pt(136, 350), control2: pt(122, 318))
        wash.addCurve(to: pt(162, 180), control1: pt(138, 254), control2: pt(158, 214))
        wash.addCurve(to: pt(146, 70), control1: pt(166, 146), control2: pt(152, 110))
        wash.addCurve(to: pt(134, 0), control1: pt(140, 30), control2: pt(138, 30))
        let blue = Color(red: 0.22, green: 0.50, blue: 0.72)
        ctx.stroke(wash, with: .color(blue.opacity(0.25)), style: StrokeStyle(lineWidth: 7 * s, lineCap: .round))
        ctx.stroke(wash, with: .color(blue), style: StrokeStyle(lineWidth: 3 * s, lineCap: .round, dash: [9 * s, 7 * s], dashPhase: t * 14 * s))
        ctx.draw(Text("Tyson Wash").font(.system(size: 11 * s, weight: .semibold)).foregroundColor(blue), at: pt(52, 332), anchor: .leading)

        // The highways and Plomosa Road.
        var roads = Path()
        roads.move(to: pt(0, 150)); roads.addLine(to: pt(360, 150))
        roads.move(to: pt(180, 0)); roads.addLine(to: pt(180, 400))
        ctx.stroke(roads, with: .color(Color(red: 0.36, green: 0.34, blue: 0.38)), lineWidth: 7 * s)
        ctx.stroke(roads, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.2 * s, dash: [6 * s, 6 * s]))
        var side = Path()
        side.move(to: pt(180, 42)); side.addLine(to: pt(330, 42))
        ctx.stroke(side, with: .color(Color(red: 0.36, green: 0.34, blue: 0.38).opacity(0.7)), lineWidth: 3 * s)

        func label(_ words: String, _ x: Double, _ y: Double, _ anchor: UnitPoint) {
            ctx.draw(Text(words).font(.system(size: 10 * s)).foregroundColor(ink.opacity(0.75)), at: pt(x, y), anchor: anchor)
        }
        label("I-10 west to Blythe", 14, 136, .leading)
        label("east to Phoenix", 346, 136, .trailing)
        label("Hwy 95 to Parker", 190, 18, .leading)
        label("Hwy 95 to Yuma", 170, 388, .trailing)
        label("Plomosa Rd", 326, 32, .trailing)

        // Compass.
        ctx.stroke(Path(ellipseIn: CGRect(x: 319 * s, y: 359 * s, width: 26 * s, height: 26 * s)), with: .color(ink.opacity(0.6)), lineWidth: 1.2)
        var north = Path()
        north.move(to: pt(332, 362)); north.addLine(to: pt(336, 372)); north.addLine(to: pt(328, 372)); north.closeSubpath()
        ctx.fill(north, with: .color(Color(red: 0.76, green: 0.26, blue: 0.10)))
        ctx.draw(Text("N").font(.system(size: 10 * s, weight: .bold)).foregroundColor(ink), at: pt(332, 352), anchor: .center)

        // Town, with a glow that breathes.
        let glow = 20 + 5 * sin(t * 2)
        ctx.fill(Path(ellipseIn: CGRect(x: (180 - glow) * s, y: (150 - glow) * s, width: glow * 2 * s, height: glow * 2 * s)),
                 with: .color(Color.orange.opacity(0.28)))
        ctx.fill(Path(roundedRect: CGRect(x: 170 * s, y: 140 * s, width: 20 * s, height: 20 * s), cornerRadius: 4 * s), with: .color(Color(red: 0.76, green: 0.26, blue: 0.10)))
        ctx.draw(Text("Quartzsite").font(.system(size: 12 * s, weight: .bold)).foregroundColor(ink), at: pt(196, 172), anchor: .leading)

        // The camping areas: filled for a Long Term Visitor Area, open for free 14-day camping.
        let teal = Color(red: 10 / 255, green: 111 / 255, blue: 105 / 255)
        for a in areas {
            guard let spot = areaSpots[a.id] else { continue }
            let on = a.id == selected
            let r = on ? 14.0 : 12.0
            if on {
                let pulse = 20 + 4 * sin(t * 4)
                ctx.stroke(Path(ellipseIn: CGRect(x: (spot.x - pulse) * s, y: (spot.y - pulse) * s, width: pulse * 2 * s, height: pulse * 2 * s)),
                           with: .color(Color.orange.opacity(0.7)), lineWidth: 3 * s)
            }
            let dot = Path(ellipseIn: CGRect(x: (spot.x - r) * s, y: (spot.y - r) * s, width: r * 2 * s, height: r * 2 * s))
            ctx.fill(dot, with: .color(a.kind == "ltva" ? teal : .white))
            ctx.stroke(dot, with: .color(on ? Color(red: 0.76, green: 0.26, blue: 0.10) : teal), lineWidth: (on ? 4 : 2.5) * s)
            let anchor: UnitPoint = spot.lx < 0 ? .trailing : spot.lx > 0 ? .leading : .center
            let dx = spot.lx < 0 ? spot.lx - 4 : spot.lx > 0 ? spot.lx + 4 : 0
            ctx.draw(Text(a.name).font(.system(size: 12 * s, weight: .bold)).foregroundColor(ink), at: pt(spot.x + dx, spot.y + (spot.lx == 0 ? spot.ly : 0)), anchor: anchor)
        }
    }
}

// The Map section of the guide: the sketch, its key, and the area you tapped.
struct AreaMapSection: View {
    let data: GuideData
    @State private var selected = ProcessInfo.processInfo.arguments.contains("-demo-areamap") ? "lpsouth" : ""

    var body: some View {
        Section {
            AreaMap(areas: data.areas, selected: $selected)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            HStack(spacing: 14) {
                Label("Free, 14 days", systemImage: "circle")
                Label("LTVA permit", systemImage: "circle.fill")
                Label("Wash", systemImage: "water.waves")
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(Theme.primary)
            if let a = data.areas.first(where: { $0.id == selected }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(a.name).font(.headline)
                        Spacer()
                        Text(a.kind == "ltva" ? "LTVA permit" : "Free, 14 days")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.soft).foregroundColor(Theme.primary).clipShape(Capsule())
                    }
                    Text(CampWords.linked(a.text)).font(.subheadline)
                    CardExtras(map: nil, photo: a.photo)
                    if let pin = data.pins.first(where: { $0.area == a.id }),
                       let url = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(pin.lat),\(pin.lon)") {
                        Link(destination: url) { Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond") }
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.vertical, 4)
            } else {
                Text("Tap a camping area to read about it. Never camp in the wash: it floods.")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

// Shows that a row of chips keeps going: the right edge fades out under an arrow.
extension View {
    func swipeHint() -> some View {
        overlay(alignment: .trailing) {
            HStack(spacing: 0) {
                LinearGradient(colors: [Theme.page.opacity(0), Theme.page], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 28)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Theme.primary)
                    .frame(width: 26)
                    .frame(maxHeight: .infinity)
                    .background(Theme.page)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
