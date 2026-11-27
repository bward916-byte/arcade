import UIKit

struct Pose {
    var lean = 0.0
    var head = 0.0
    var bob = 0.0
    var hipF = 0.0
    var kneeF = 0.1
    var hipB = 0.0
    var kneeB = 0.1
    var armF = 0.2
    var elbF = 0.4
    var armB = -0.2
    var elbB = 0.3
    var wpn = 0.0
    var jaw = 0.0
}
struct Look {
    var shirt: Col
    var pants: Col
    var skin: Col
    var hair: Col
    var eye: Col
    var weapon = 0
    var tier = 0             // melee weapon upgrade: 1 steel, 2 nails, 3 barbed wire
    var gun = 0              // gun in the hands right now
    var slung = 0            // gun carried on the back
    var zombie = false
    var fat = 1.0
    var longHair = false
    var coat = false
    var v = 0
    var noHead = false
    var job = -1
    var female = false
    var sleeve: Col? = nil
    var lower = 0          // 1 skirt, 2 apron, 3 gown
    var lowerCol = Col(0xffffff)
    var hat = 0            // 1 chef, 2 hard hat, 3 cap, 4 surgical cap
    var hatCol = Col(0xffffff)
    var barefoot = false
}

struct Rect4 {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    func has(_ px: Double, _ py: Double) -> Bool { return px >= x - 8 && px <= x + w + 8 && py >= y - 8 && py <= y + h + 8 }
}

extension Game {
    var atkBtn: (Double, Double, Double) { return (W - safeR - 104, VIEW_H - 118, 62) }
    var powBtn: (Double, Double, Double) { return (W - safeR - 238, VIEW_H - 84, 46) }
    var pauseRect: Rect4 { return Rect4(x: W / 2 - 24, y: 8, w: 48, h: 32) }
    var playRect: Rect4 { return Rect4(x: W / 2 - 170, y: 372, w: 340, h: 76) }
    var contRect: Rect4 { return Rect4(x: W / 2 - 150, y: 462, w: 300, h: 40) }
    var resumeRect: Rect4 { return Rect4(x: W / 2 - 150, y: 210, w: 300, h: 64) }
    var quitRect: Rect4 { return Rect4(x: W / 2 - 150, y: 296, w: 300, h: 54) }
    var musicRect: Rect4 { return Rect4(x: W / 2 - 150, y: 372, w: 300, h: 46) }
    func pickRect(_ i: Int) -> Rect4 {
        let cw = 300.0, gap = 44.0
        let n = Double(max(1, pickOpts.count))
        let x0 = W / 2 - (n * cw + (n - 1) * gap) / 2
        return Rect4(x: x0 + Double(i) * (cw + gap), y: 116, w: cw, h: 384)
    }
}

final class Renderer {
    let GY = 410.0
    // ---------- painted art (walls, zombie heads, upgrade icons); the drawn versions are used if a picture is missing
    private var art: [String: CGImage] = [:]
    private var artMiss: Set<String> = []
    func pic(_ name: String) -> CGImage? {
        if let i = art[name] { return i }
        if artMiss.contains(name) { return nil }
        if let i = UIImage(named: name)?.cgImage { art[name] = i; return i }
        artMiss.insert(name)
        return nil
    }
    private var wallKey = ""
    private var wallImg: CGImage?
    private var wallTw = 1000.0
    /// The wall picture scaled once to screen pixels (and tinted), so each frame is a plain copy.
    private func wallFor(_ name: String, _ tint: Col, _ h: Double, _ sc: Double) -> CGImage? {
        let key = "\(name)|\(tint.r)|\(tint.g)|\(tint.b)|\(tint.a)|\(h)|\(sc)"
        if key == wallKey { return wallImg }
        wallKey = key
        wallImg = nil
        guard let src = pic(name) else { return nil }
        let ph = max(1, Int((h * sc).rounded()))
        let pw = max(1, Int((Double(src.width) / Double(src.height) * Double(ph)).rounded()))
        let info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let c = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else { return nil }
        c.interpolationQuality = .high
        c.draw(src, in: CGRect(x: 0, y: 0, width: pw, height: ph))
        c.setFillColor(red: CGFloat(tint.r), green: CGFloat(tint.g), blue: CGFloat(tint.b), alpha: CGFloat(tint.a))
        c.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
        wallImg = c.makeImage()
        wallTw = Double(pw) / sc
        return wallImg
    }
    private func wallTiles(_ cv: Canvas, _ im: CGImage, _ x0: Double, _ x1: Double, _ y: Double, _ h: Double, _ block: Int) {
        let tw = wallTw
        let off = (hashN(Double(block) * 3.7 + 1) * tw).rounded()
        var i = Int(((x0 - off) / tw).rounded(.down))
        while Double(i) * tw + off < x1 {
            cv.img(im, Double(i) * tw + off, y, tw + 0.5, h, (i + block) % 2 != 0, fast: true)
            i += 1
        }
    }
    private func wallArt(_ z: Zone) -> (String, Col) {
        switch z.name {
        case "OFFICES": return ("hall_office.jpg", z.wall.alpha(0.1))
        case "HOTEL", "GUEST ROOMS": return ("hall_hotel.jpg", Col(0x120a0a).alpha(0.14))
        case "PENTHOUSES": return ("hall_penthouse.jpg", Col(0x0a0814).alpha(0.05))
        case "RESIDENTIAL": return ("hall_apartment.jpg", Col(0x0c120c).alpha(0.34))
        case "MEDICAL / LAB", "LABS": return ("hall_lab.jpg", Col(0x0a1016).alpha(0.18))
        case "MALL / GARAGE": return ("hall_mall.jpg", z.wall.alpha(0.06))
        case "LOBBY": return ("hall_lobby.jpg", Col(0x0a0806).alpha(0.12))
        case "BALLROOMS": return ("hall_ballroom.jpg", Col(0x140c10).alpha(0.32))
        case "WARDS": return ("hall_hospital.jpg", Col(0x0c1c22).alpha(0.38))
        case "SURGERY": return ("hall_surgery.jpg", Col(0x061014).alpha(0.1))
        case "EMERGENCY": return ("hall_surgery.jpg", Col(0x4a0c0c).alpha(0.26))
        case "CASINO": return ("hall_casino.jpg", z.wall.alpha(0.05))
        default: return ("hall_office.jpg", z.wall.alpha(0.2))
        }
    }
    /// Who rents this block of three floors.
    private func tenant(_ z: Zone, _ block: Int) -> String {
        var names: [String]
        switch z.name {
        case "OFFICES": names = ["HALVERSEN & PIKE  LAW", "NORTHSTAR TRAVEL", "KESTREL INSURANCE", "BRIGHTLINE MEDIA", "VANTA ACCOUNTING", "PIXELFORGE GAMES", "MERIDIAN REALTY", "ODELL DENTAL"]
        case "HOTEL": names = ["SKYLINE SUITES", "THE SPA", "CLUB LOUNGE", "CONFERENCE ROOMS", "HONEYMOON FLOOR"]
        case "RESIDENTIAL": names = ["THE ROWANS", "ALDER COURT", "GARDEN FLATS", "MERIDIAN LOFTS", "TENANTS ONLY"]
        case "MEDICAL / LAB": names = ["MARR BIOTECH", "BLOOD LAB", "RADIOLOGY", "SPECIMEN STORE", "CLEAN ROOM 4"]
        case "MALL / GARAGE": names = ["FOOD COURT", "TOY KINGDOM", "ELECTRO CITY", "FASHION ROW", "PARKING LEVEL"]
        case "WARDS": names = ["MATERNITY", "CHILDREN'S WARD", "CARDIOLOGY", "RECOVERY", "ISOLATION"]
        case "SURGERY": names = ["THEATRE 1", "THEATRE 2", "INTENSIVE CARE", "ANAESTHETICS"]
        case "LABS": names = ["PATHOLOGY", "BLOOD BANK", "VIROLOGY", "MORGUE"]
        case "EMERGENCY": names = ["TRIAGE", "TRAUMA BAY", "AMBULANCE DOCK"]
        case "PENTHOUSES": names = ["ROYAL SUITE", "SKY TERRACE", "THE ALDER CLUB", "PRESIDENTIAL SUITE", "OBSERVATORY BAR"]
        case "GUEST ROOMS": names = ["EAST WING", "WEST WING", "HONEYMOON SUITES", "FAMILY ROOMS", "BUSINESS FLOOR", "POOL DECK", "THE SPA", "LAUNDRY"]
        case "BALLROOMS": names = ["GRAND BALLROOM", "WEDDING HALL", "BANQUET KITCHEN", "THE ORCHID ROOM"]
        case "CASINO": names = ["HIGH ROLLERS", "SLOT HALL", "THE VAULT"]
        default: names = []
        }
        if names.isEmpty { return "" }
        return names[((block % names.count) + names.count) % names.count]
    }
    /// A zombie's head in profile, drawn round (0, 0) and facing right.
    private func zedHead(_ cv: Canvas, _ L: Look, _ skin: Col, _ ink: Col, _ bone: Col, _ jawOpen: Double, _ bob: Double) {
            // a real skull in profile: brow, nose, lips, a jaw that drops
            let o = clampD(jawOpen, 0, 1.2)
            let v = abs(L.v)
            let dark = Col.mix(skin, BLACK, 0.45), mid = Col.mix(skin, BLACK, 0.2), lite = Col.mix(skin, WHITE, 0.16)
            let fatJ = L.fat > 1.3 ? 3.0 : 0.0
            let skull: [Double] = [-9, 14, -14, 8, -16.5, 0, -16, -8, -11.5, -15, -3, -18.5, 5, -17.5, 10.5, -13.5, 13, -8, 15, -5, 14, -2, 18, 3.5, 15.2, 5.2, 15.8, 7.6, 9, 9, -3, 9 + fatJ]
            let jaw: [Double] = [-6, 5, 9, 7.5 + o * 2, 15, 9.5 + o * 5, 14.2, 12.5 + o * 6, 12, 16.5 + o * 7 + fatJ * 0.5, 4, 17.5 + o * 6 + fatJ, -5, 12.5 + fatJ]
            // inside of the mouth, then the jaw, then the skull over both
            cv.poly(Col(0x1e0608), [6, 6, 15.5, 7, 14.5, 11 + o * 5.5, 6, 11 + o * 4])
            cv.poly(mid, jaw); cv.line(ink, 2.4, jaw + [-6, 5])
            for i in 0..<4 { cv.R(8.2 + Double(i) * 1.8, 8.6 + o * 5 - Double(i) * 0.15, 1.4, 2.6, bone) }
            cv.poly(skin, skull); cv.line(ink, 2.4, skull + [-9, 14])
            // shadow under the back of the skull, hollow cheek, temple
            cv.poly(mid, [-16.5, 0, -14, 8, -9, 14, -3, 9, -6, 2, -11, -3])
            cv.ell(6.5, 4.5, 3.6, 4.4, dark.alpha(0.55))
            cv.ell(1.5, -6, 4, 3, mid.alpha(0.7))
            cv.seg(4, 0.8, 11.5, 1.8, 1.5, lite.alpha(0.8))
            cv.seg(0, -15, 8, -13.5, 1.4, lite.alpha(0.6))
            // upper teeth through torn lips
            for i in 0..<4 { cv.R(8.6 + Double(i) * 1.8, 6.2, 1.4, 2.6, bone) }
            cv.seg(8, 6.2, 15.6, 7.2, 1.1, Col(0x3a0c10))
            // ear
            cv.ell(-4, 0.5, 3.4, 4.8, ink); cv.ell(-4, 0.5, 2.3, 3.7, mid); cv.seg(-4.5, -1.5, -3.2, 2, 1, dark)
            // nose shadow, nostril, creases
            cv.seg(14.2, -1.5, 17.2, 3.4, 1.2, dark.alpha(0.7)); cv.circ(15.6, 4.3, 0.9, ink)
            cv.seg(12, 3, 10, 8, 0.9, dark.alpha(0.8))
            cv.seg(3, -12, 10, -10.6, 0.8, dark.alpha(0.6)); cv.seg(2, -9.8, 8, -9, 0.8, dark.alpha(0.5))
            // sunken socket, cloudy eye, heavy brow
            cv.ell(9, -3.6, 5, 4, Col(0x14100e))
            if v % 4 != 3 {
                cv.lighter(true); cv.circ(10, -3.4, 5.5, L.eye.alpha(0.22)); cv.lighter(false)
                cv.ell(10, -3.4, 2.5, 2.1, Col.mix(L.eye, WHITE, 0.55)); cv.circ(10.8, -3.3, 0.9, Col(0x2a2a22))
            } else {
                cv.seg(9, -2, 9.6, 5, 1.6, BLOOD.alpha(0.85)); cv.circ(9, -3.4, 1.6, Col(0x4a0a0e))
            }
            cv.ell(9, -1, 4.2, 1.6, dark.alpha(0.6))
            cv.line(dark, 2.6, [3, -8.6, 9, -8.4, 15, -5.4])
            // each one is rotting somewhere different
            if v % 4 == 0 {
                cv.poly(Col(0x4a0a0e), [1, 3, 7, 2.5, 8, 8, 2, 9]); for i in 0..<3 { cv.R(2.6 + Double(i) * 1.8, 5, 1.3, 2.6, bone) }
            } else if v % 4 == 1 {
                cv.seg(13, 9 + o * 4, 12.5, 16 + o * 6, 1.8, BLOOD.alpha(0.85)); cv.circ(10, 13 + o * 5, 2.2, BLOOD.alpha(0.7))
            } else if v % 4 == 2 {
                cv.seg(-9, -13, -1, -15.5, 2.6, Col(0x6a1418)); cv.seg(-6, -15.5, -4.5, -12, 1.3, bone); cv.seg(-5, -13, -6.5, -6, 1.2, BLOOD.alpha(0.8))
            }
            cv.circ(-8, 8, 1.6, dark.alpha(0.7)); cv.circ(-1, -9, 1.2, dark.alpha(0.6)); cv.circ(3, 12 + o * 3, 1.4, dark.alpha(0.6))
            // hair follows the skull
            let hx = 0.0, hy = 0.0
            let hairD = Col.mix(L.hair, BLACK, 0.3)
            if L.female {
                cv.poly(L.hair, [-17.5, 2, -17, -8, -12, -16, -3, -19.6, 5.5, -18.6, 11, -14.5, 12, -10, 5, -12, -3, -10.5, -7, -4, -8, 4, -12, 8])
                cv.line(ink, 1.6, [-17.5, 2, -17, -8, -12, -16, -3, -19.6, 5.5, -18.6, 11, -14.5, 12, -10])
                cv.seg(-12, -12, -4, -15, 1, hairD); cv.seg(-13, -6, -8, -9, 1, hairD)
                if v % 3 == 0 {
                    cv.circ(hx - 16, hy - 10, 7.6, ink); cv.circ(hx - 16, hy - 10, 6.2, L.hair); cv.seg(hx - 19, hy - 11, hx - 14, hy - 8, 1, hairD)
                } else if v % 3 == 1 {
                    cv.seg(hx - 12, hy - 6, hx - 18, hy + 24, 8, L.hair); cv.seg(hx - 7, hy - 6, hx - 11, hy + 22, 5, hairD); cv.seg(hx + 9, hy - 12, hx + 12, hy + 2, 1.6, L.hair)
                } else {
                    cv.seg(hx - 15, hy - 8, hx - 27, hy + 3 + sin(bob) * 2, 6.5, ink); cv.seg(hx - 15, hy - 8, hx - 27, hy + 3 + sin(bob) * 2, 4.6, L.hair)
                }
            } else if L.hat == 0 && v % 3 == 0 {
                // balding: a fringe round the back
                cv.poly(L.hair, [-17, 2, -16.6, -7, -13, -12, -9, -8, -9.5, -1, -11, 5])
                cv.seg(-2, -18, 1, -21, 1.2, L.hair); cv.seg(2, -18, 6, -20, 1.2, L.hair)
            } else {
                cv.poly(L.hair, [-17.2, 1, -17, -8, -12, -16, -3, -19.8, 5.5, -18.8, 10.5, -14.8, 4, -13.5, -4, -11.5, -8.5, -5, -10, 3])
                cv.line(ink, 1.6, [-17.2, 1, -17, -8, -12, -16, -3, -19.8, 5.5, -18.8, 10.5, -14.8])
                cv.seg(-10, -13, -2, -16, 1, hairD); cv.seg(-2, -19, 3, -22.5, 2.2, L.hair); cv.seg(-9, -16, -13, -20, 2.2, L.hair)
            }
    }
    /// A living person's head in profile, drawn round (0, 0) and facing right.
    private func heroHead(_ cv: Canvas, _ L: Look, _ skin: Col, _ ink: Col, _ bob: Double) {
        let dark = Col.mix(skin, BLACK, 0.42), mid = Col.mix(skin, BLACK, 0.16), lite = Col.mix(skin, WHITE, 0.2)
        let hairD = Col.mix(L.hair, BLACK, 0.35), hairL = Col.mix(L.hair, WHITE, 0.18)
        let head: [Double] = [-8, 15, -13.5, 8, -16, 0, -15.5, -8, -11, -15, -3, -18.5, 5, -17.5, 10.5, -13.5, 13, -8.5, 13.8, -5, 13.2, -2.2, 17.2, 3, 14.8, 5, 15.2, 7, 14.4, 8.3, 15, 10, 13.6, 13.6, 9.5, 16.8, 2, 16, -4, 12.5]
        if L.longHair {
            // hair down the back, behind the head
            cv.line(ink, 12, [-10, -8, -16, 6, -15, 24 + sin(bob) * 1.5]); cv.line(L.hair, 9.5, [-10, -8, -16, 6, -15, 24 + sin(bob) * 1.5])
            cv.line(hairD, 3, [-11, -2, -13, 10, -12, 22])
        }
        cv.poly(skin, head); cv.line(ink, 2.4, head + [-8, 15])
        // shade under the jaw and the back of the head, light on the cheek and brow
        cv.poly(mid, [-16, 0, -13.5, 8, -8, 15, -4, 12.5, 2, 16, 9.5, 16.8, 8, 12, -2, 8, -8, 0])
        cv.seg(4, 2.5, 11, 3.5, 2, lite.alpha(0.7)); cv.seg(1, -14.5, 8, -13, 1.4, lite.alpha(0.6))
        // ear
        cv.ell(-4, 0.5, 3.3, 4.6, ink); cv.ell(-4, 0.5, 2.2, 3.5, mid); cv.seg(-4.6, -1.4, -3.3, 2, 1, dark)
        // eye, lid, brow
        cv.ell(9.3, -2.8, 3, 2.5, WHITE); cv.circ(10.4, -2.7, 1.7, L.eye); cv.circ(10.9, -3.2, 0.5, WHITE)
        cv.line(ink, 1.3, [6.2, -3.6, 9.4, -5.4, 12.6, -3.8])
        cv.line(hairD, 2.3, [4.5, -7.6, 9.5, -8.2, 14, -6.4])
        // nose, mouth, chin
        cv.seg(14.2, -1.4, 16.8, 3, 1, dark.alpha(0.6)); cv.circ(15.4, 4.2, 0.8, dark)
        cv.seg(9.8, 9.2, 14.6, 8.6, 1.5, Col.mix(skin, Col(0x6a1c1c), 0.6))
        cv.seg(11, 12.6, 13.2, 12.2, 1, dark.alpha(0.5)); cv.seg(11.6, 4, 10.4, 7, 0.8, dark.alpha(0.5))
        // hair over the skull
        if L.longHair {
            cv.poly(L.hair, [-17.6, 4, -17.2, -8, -12, -16.4, -3, -20, 6, -19, 11.5, -15, 13.2, -9.5, 7, -12, 0, -11, -5, -5, -6.5, 5, -11, 9])
            cv.line(ink, 1.7, [-17.6, 4, -17.2, -8, -12, -16.4, -3, -20, 6, -19, 11.5, -15, 13.2, -9.5])
            cv.seg(-12, -12, -3, -16, 1.2, hairL); cv.seg(-13, -5, -8, -9, 1, hairD); cv.seg(1, -17, 8, -15, 1, hairD)
            cv.seg(11.5, -13, 13.6, -4, 1.8, L.hair)
        } else {
            cv.poly(L.hair, [-17, 1, -16.8, -8, -12, -16.2, -3, -20, 6, -19.2, 12, -15, 13, -11, 6, -13.5, -2, -12, -7.5, -6, -8, 1.5, -11, 4])
            cv.line(ink, 1.7, [-17, 1, -16.8, -8, -12, -16.2, -3, -20, 6, -19.2, 12, -15, 13, -11])
            cv.seg(-11, -12.5, -2, -16.5, 1.2, hairL); cv.seg(0, -17.5, 8, -16, 1, hairD)
            cv.poly(L.hair, [-8, 1.5, -5.6, 1.5, -6, 6.5, -8.4, 5])
        }
    }
    /// A gun drawn from the hand at (ox, oy), pointing along the weapon angle.
    private func gun(_ cv: Canvas, _ kind: Int, _ ox: Double, _ oy: Double, _ wa: Double, _ ink: Col) {
        let dx = sin(wa), dy = cos(wa), ux = cos(wa), uy = -sin(wa)
        func bar(_ d0: Double, _ d1: Double, _ u: Double, _ w: Double, _ c: Col) {
            cv.seg(ox + dx * d0 + ux * u, oy + dy * d0 + uy * u, ox + dx * d1 + ux * u, oy + dy * d1 + uy * u, w + 3, ink)
            cv.seg(ox + dx * d0 + ux * u, oy + dy * d0 + uy * u, ox + dx * d1 + ux * u, oy + dy * d1 + uy * u, w, c)
        }
        let steel = Col(0x3a404a), dark = Col(0x1e2228), wood = Col(0x7a4e2a)
        switch kind {
        case 1:
            bar(22, 34, 1, 3, steel); bar(-8, 22, 0, 8, dark)
            cv.seg(ox + dx * 8, oy + dy * 8, ox + dx * 5 - ux * 15, oy + dy * 5 - uy * 15, 8, ink)
            cv.seg(ox + dx * 8, oy + dy * 8, ox + dx * 5 - ux * 15, oy + dy * 5 - uy * 15, 5, steel)
        case 2:
            bar(28, 56, 1.5, 3.6, Col(0x565e6a)); bar(-18, -2, -1, 7, wood); bar(-4, 30, 0, 6.5, dark); bar(20, 34, -3.5, 4.5, wood)
        case 3:
            bar(-12, 26, 0, 12, dark)
            for u in [-3.6, 0.0, 3.6] { bar(26, 54, u, 2.2, Col(0x6a727e)) }
            bar(50, 54, 0, 9, steel)
        default:
            bar(-6, 30, 0, 6, Col(0x5a626c)); bar(30, 46, 0, 3.4, steel); bar(-10, 6, -7, 8, Col(0xb8402a))
            cv.circ(ox + dx * 48, oy + dy * 48, 3, Col(0xff9a30))
        }
    }
    private func fit(_ cv: Canvas, _ im: CGImage, _ cx: Double, _ cy: Double, _ box: Double) {
        let w = Double(im.width), h = Double(im.height), s = box / max(w, h)
        cv.img(im, cx - w * s / 2, cy - h * s / 2, w * s, h * s, false)
    }
    /// Outside on the fire escape: the brick face of the building, a steel landing, a long way down.
    private func escapeBack(_ g: Game, _ cv: Canvas, _ x0: Double, _ W: Double) {
        let f = g.floor, t = g.t, x1 = x0 + W
        let steel = Col(0x2b303a), steelD = Col(0x14171d), steelL = Col(0x4a5262)
        cv.R(x0, 0, W, VIEW_H, Col(0x0a0b12))
        if let im = wallFor("hall_brick.jpg", Col(0x050814).alpha(0.3), GY + 70, cv.sc) { wallTiles(cv, im, x0, x1, 0, GY + 70, f.n) }
        cv.lighter(true); cv.R(x0, 0, W, GY, rgba(255, 120, 40, 0.035 + 0.02 * sin(t * 7))); cv.lighter(false)
        cv.vfill(x0, GY + 12, W, VIEW_H - GY - 12, [(0, BLACK.alpha(0.5)), (1, BLACK.alpha(0.92))])
        // the flight you came down, and the next one going on below
        let d = f.exitRight ? 1.0 : -1.0
        let e = FLOOR_W - f.exitX
        func flight(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) {
            cv.seg(ax, ay, bx, by, 7, steelD); cv.seg(ax, ay - 16, bx, by - 16, 7, steelD)
            cv.seg(ax, ay, bx, by, 4, steel); cv.seg(ax, ay - 16, bx, by - 16, 4, steel)
            for i in 0...12 { let k = Double(i) / 12; let sx = ax + (bx - ax) * k, sy = ay + (by - ay) * k; cv.R(sx - 9, sy - 10, 18, 3.5, steelL) }
            cv.seg(ax, ay - 58, bx, by - 58, 3.5, steel)
        }
        flight(e + d * 330, GY - 330, e + d * 40, GY)
        flight(f.exitX - d * 40, GY + 12, f.exitX - d * 300, GY + 150)
        // back rail
        cv.R(x0, GY - 56, W, 4, steel); cv.R(x0, GY - 56, W, 1.2, steelL); cv.R(x0, GY - 30, W, 2.5, steel)
        var rx = (x0 / 60).rounded(.down) * 60
        while rx < x1 { cv.R(rx, GY - 56, 3, 56, steel); rx += 60 }
        // landing
        var bx = (x0 / 240).rounded(.down) * 240
        while bx < x1 + 240 { cv.poly(steelD, [bx, GY + 12, bx + 12, GY + 12, bx + 12, GY + 70, bx + 60, GY + 12, bx + 72, GY + 12, bx + 6, GY + 92, bx, GY + 92]); bx += 240 }
        cv.R(x0, GY, W, 12, steel)
        cv.R(x0, GY, W, 2, steelL)
        var sx = (x0 / 14).rounded(.down) * 14
        while sx < x1 { cv.R(sx, GY + 3, 2, 9, steelD); sx += 14 }
        if f.n % 2 == 0 { sign(cv, "FIRE ESCAPE", f.exitX - d * 520, GY - 250, HOT, t, arrow: false) }
    }
    private var camX = 0.0
    // ---------- smoothing: poses ease toward where they are going instead of snapping between states
    private var lastT = -1.0
    private var rdt = 1.0 / 60
    private var frameN = 0
    private var heroP: Pose?
    private var zedP: [ObjectIdentifier: (Pose, Int)] = [:]
    private func blend(_ a: Pose, _ b: Pose, _ k: Double) -> Pose {
        var p = b
        p.lean = lerp(a.lean, b.lean, k); p.head = lerp(a.head, b.head, k); p.bob = lerp(a.bob, b.bob, k)
        p.hipF = lerp(a.hipF, b.hipF, k); p.kneeF = lerp(a.kneeF, b.kneeF, k); p.hipB = lerp(a.hipB, b.hipB, k); p.kneeB = lerp(a.kneeB, b.kneeB, k)
        p.armF = lerp(a.armF, b.armF, k); p.elbF = lerp(a.elbF, b.elbF, k); p.armB = lerp(a.armB, b.armB, k); p.elbB = lerp(a.elbB, b.elbB, k)
        p.wpn = lerp(a.wpn, b.wpn, k); p.jaw = lerp(a.jaw, b.jaw, k)
        return p
    }
    private func ease(_ rate: Double) -> Double { return 1 - exp(-rate * rdt) }
    private func smoothHero(_ g: Game) -> Pose {
        let tgt = heroPose(g)
        let h = g.hero
        // swings stay snappy, everything else (stopping, turning to shoot, getting hurt) glides
        let rate: Double = h.atkT >= 0 || g.supT >= 0 ? 34 : (h.hurtT > 0 ? 26 : 15)
        let p = heroP.map { blend($0, tgt, ease(rate)) } ?? tgt
        heroP = p
        return p
    }
    private func smoothZed(_ z: Zed, _ t: Double) -> Pose {
        let tgt = zedPose(z, t)
        let id = ObjectIdentifier(z)
        let rate: Double = z.atkT >= 0 ? 26 : 13
        let p = zedP[id].map { blend($0.0, tgt, ease(rate)) } ?? tgt
        zedP[id] = (p, frameN)
        return p
    }
    private var camFloor = -99
    var paused = false

    func draw(_ g: Game, _ cv: Canvas) {
        let W = g.W
        cv.R(0, 0, W, VIEW_H, INK)
        switch g.mode {
        case .title: title(g, cv)
        case .intro: intro(g, cv)
        case .card: scene(g, cv); card(g, cv)
        case .play: scene(g, cv); hud(g, cv)
        case .dead: scene(g, cv); deadCard(g, cv)
        case .pick: scene(g, cv); pick(g, cv)
        case .ride: ride(g, cv)
        case .ending: ending(g, cv)
        }
        if g.flash > 0 { cv.R(0, 0, W, VIEW_H, g.flashCol.alpha(min(0.8, g.flash))) }
        if paused { pauseCard(g, cv) }
    }

    // ---------- figures
    private func limb(_ ox: Double, _ oy: Double, _ a1: Double, _ l1: Double, _ a2: Double, _ l2: Double) -> (Double, Double, Double, Double) {
        let kx = ox + l1 * sin(a1)
        let ky = oy + l1 * cos(a1)
        return (kx, ky, kx + l2 * sin(a2), ky + l2 * cos(a2))
    }
    /// Two-part limb with a dark outline under both parts, so joints stay clean.
    private func limb2(_ cv: Canvas, _ ox: Double, _ oy: Double, _ L: (Double, Double, Double, Double), _ w1: Double, _ c1: Col, _ w2: Double, _ c2: Col, _ ink: Col) {
        cv.seg(ox, oy, L.0, L.1, w1 + 3.4, ink)
        cv.seg(L.0, L.1, L.2, L.3, w2 + 3.4, ink)
        cv.seg(ox, oy, L.0, L.1, w1, c1)
        cv.seg(L.0, L.1, L.2, L.3, w2, c2)
    }
    func figure(_ cv: Canvas, _ x: Double, _ y: Double, _ face: Double, _ s: Double, _ L: Look, _ p: Pose, flash: Double = 0, fall: Double = 0, alpha: Double = 1) {
        cv.save()
        cv.translate(x, y)
        cv.scale(face * s, s)
        if fall > 0 { cv.rotate(-fall * PI / 2 * 0.97); cv.translate(0, -fall * 9) }
        if alpha < 1 { cv.alpha(alpha) }
        let fl = clampD(flash, 0, 1) * 0.85
        let shirt = Col.mix(L.shirt, WHITE, fl)
        let pants = Col.mix(L.pants, WHITE, fl)
        let skin = Col.mix(L.skin, WHITE, fl)
        let shirtD = Col.mix(shirt, BLACK, 0.3)
        let shirtL = Col.mix(shirt, WHITE, 0.14)
        let pantsD = Col.mix(pants, BLACK, 0.3)
        let skinD = Col.mix(skin, BLACK, 0.25)
        let ink = Col(0x0b0c10)
        let shoe: Col = L.barefoot ? skin : Col(0x15151a)
        let bone = Col(0xd8d0bc)
        let slv = Col.mix(L.sleeve ?? L.shirt, WHITE, fl)
        let zed = L.zombie
        let fat = L.fat
        let hipY = -74.0 + p.bob
        let sl = sin(p.lean), cl = cos(p.lean)
        // a point `up` along the spine and `fw` in front of it
        func T(_ up: Double, _ fw: Double) -> (Double, Double) { return (up * sl + fw * cl, hipY - up * cl + fw * sl) }
        let nx = 54 * sl
        let ny = hipY - 54 * cl
        let ha = p.lean * 1.3 + p.head
        let hx = nx + 20 * sin(ha)
        let hy = ny - 20 * cos(ha)
        let sy = ny + 9
        // back arm, back leg
        let ab = limb(nx, sy, p.armB, 27, p.armB + p.elbB, 26)
        limb2(cv, nx, sy, ab, 10.5, Col.mix(slv, BLACK, 0.3), 8.5, skinD, ink)
        cv.circ(ab.2, ab.3, 5.6, skinD)
        let lb = limb(0, hipY, p.hipB, 37, p.hipB - p.kneeB, 37)
        limb2(cv, 0, hipY, lb, 15, pantsD, 12, pantsD, ink)
        cv.seg(lb.2 - 2, lb.3, lb.2 + 11, lb.3, 10.5, ink)
        cv.seg(lb.2 - 2, lb.3, lb.2 + 11, lb.3, 7.5, shoe)
        // body: a shaped torso, not a bar
        let b0 = T(-3, -11 * fat), b1 = T(26, -13 * fat), b2 = T(52, -12 * fat), b3 = T(59, -3)
        let f3 = T(58, 7), f2 = T(48, 14 * fat), f1 = T(26, 16 * fat), f0 = T(0, 12 * fat), w0 = T(-6, 0)
        let body: [Double] = [b0.0, b0.1, b1.0, b1.1, b2.0, b2.1, b3.0, b3.1, f3.0, f3.1, f2.0, f2.1, f1.0, f1.1, f0.0, f0.1, w0.0, w0.1]
        cv.line(ink, 4, body + [b0.0, b0.1])
        cv.poly(shirt, body)
        // light on the chest, shade on the back
        let c1 = T(46, 2), c2 = T(46, 12 * fat), c3 = T(20, 14 * fat), c4 = T(20, 3)
        cv.poly(shirtL, [c1.0, c1.1, c2.0, c2.1, c3.0, c3.1, c4.0, c4.1])
        let k1 = T(50, -11 * fat), k2 = T(4, -10 * fat), k3 = T(4, -5 * fat), k4 = T(50, -6 * fat)
        cv.poly(shirtD, [k1.0, k1.1, k2.0, k2.1, k3.0, k3.1, k4.0, k4.1])
        let bl0 = T(1, -11 * fat), bl1 = T(1, 12 * fat)
        cv.seg(bl0.0, bl0.1, bl1.0, bl1.1, 4, Col.mix(pants, BLACK, 0.45))
        if L.job >= 0 {
            switch L.job {
            case 0:
                let a0 = T(58, 7), a1 = T(34, 15 * fat), a2 = T(44, 6)
                cv.poly(Col(0xe8e6e0), [a0.0, a0.1, a1.0, a1.1, a2.0, a2.1])
                let t1 = T(36, 14 * fat)
                cv.seg(a0.0, a0.1, t1.0, t1.1, 4, Col(0x8a1c20))
                let bt = T(18, 15 * fat); cv.circ(bt.0, bt.1, 2, Col(0x0b0c10))
            case 2:
                for i in 0..<3 { let b = T(44 - Double(i) * 12, 13 * fat), c = T(44 - Double(i) * 12, 6); cv.circ(b.0, b.1, 2, Col(0x8a8a86)); cv.circ(c.0, c.1, 2, Col(0x8a8a86)) }
            case 3:
                let v0 = T(58, 7), v1 = T(44, 12 * fat), v2 = T(50, 3)
                cv.line(shirtD, 3, [v0.0, v0.1, v1.0, v1.1, v2.0, v2.1])
                if L.coat { let st = T(40, 15 * fat); cv.ring(st.0, st.1, 5, 2, Col(0x2a2a2a)) }
            case 4:
                let bd = T(42, 13 * fat); cv.circ(bd.0, bd.1, 4.5, GOLD); cv.circ(bd.0, bd.1, 2, Col(0x8a6a20))
                let e0 = T(54, -10 * fat), e1 = T(54, 10 * fat); cv.seg(e0.0, e0.1, e1.0, e1.1, 3, Col(0x0e1420))
            case 5:
                let pa = T(42, 12 * fat); cv.R(pa.0 - 5, pa.1 - 3, 10, 6, Col(0xe8e6e0))
                let z0 = T(56, 6), z1 = T(6, 13 * fat); cv.seg(z0.0, z0.1, z1.0, z1.1, 1.6, Col(0x2a2a2a))
            case 6:
                let a0 = T(58, 7), a1 = T(30, 15 * fat), a2 = T(42, 4)
                cv.poly(Col(0xe8e6e0), [a0.0, a0.1, a1.0, a1.1, a2.0, a2.1])
                let bw = T(56, 9); cv.poly(Col(0x0b0c10), [bw.0 - 5, bw.1 - 4, bw.0 + 5, bw.1 + 4, bw.0 + 5, bw.1 - 4, bw.0 - 5, bw.1 + 4])
            case 7:
                let hd = T(56, -9); cv.circ(hd.0, hd.1, 9, shirtD)
            case 9:
                for u in [18.0, 38.0] { let r0 = T(u, -12 * fat), r1 = T(u, 15 * fat); cv.seg(r0.0, r0.1, r1.0, r1.1, 4.5, Col(0xe8e8d0)) }
                let y0 = T(2, 10 * fat), y1 = T(56, 8); cv.seg(y0.0, y0.1, y1.0, y1.1, 4, Col(0xf0e040))
            default: break
            }
        }
        if fat > 1.3 {
            let belly = T(18, 14 * fat)
            cv.circ(belly.0, belly.1, 15 * fat, shirt)
            cv.circ(belly.0 + 4, belly.1 + 3, 5, Col(0xd9e07a, 0.85)); cv.circ(belly.0 - 8, belly.1 - 8, 3.5, Col(0xd9e07a, 0.8)); cv.circ(belly.0 + 9, belly.1 - 9, 3, Col(0xd9e07a, 0.8))
        }
        if L.coat {
            let t0 = T(-4, -12 * fat), t1 = T(-26, -16), t2 = T(-24, -4), t3 = T(-2, 0)
            cv.poly(Col.mix(shirt, BLACK, 0.12), [t0.0, t0.1, t1.0, t1.1, t2.0, t2.1, t3.0, t3.1])
            let l0 = T(56, 6), l1 = T(30, 13 * fat)
            cv.seg(l0.0, l0.1, l1.0, l1.1, 3, Col.mix(shirt, BLACK, 0.3))
        }
        if zed {
            // torn hem, a wound with ribs showing, old blood
            let h0 = T(-3, -9 * fat), h1 = T(-11, -5), h2 = T(-3, -1), h3 = T(-10, 5), h4 = T(-2, 9 * fat)
            cv.poly(shirt, [h0.0, h0.1, h1.0, h1.1, h2.0, h2.1, h3.0, h3.1, h4.0, h4.1])
            let r0 = T(42, 3), r1 = T(42, 14 * fat), r2 = T(22, 15 * fat), r3 = T(24, 4)
            cv.poly(Col(0x5a1216), [r0.0, r0.1, r1.0, r1.1, r2.0, r2.1, r3.0, r3.1])
            for i in 0..<3 {
                let a0 = T(38 - Double(i) * 6, 5), a1 = T(36 - Double(i) * 6, 13 * fat)
                cv.seg(a0.0, a0.1, a1.0, a1.1, 2.4, bone)
            }
            let s0 = T(12, 6)
            cv.circ(s0.0, s0.1, 6 * fat, BLOOD.alpha(0.8))
            let s1 = T(50, 8)
            cv.circ(s1.0, s1.1, 4, BLOOD.alpha(0.7))
        } else {
            let col0 = T(58, 7), col1 = T(50, 9)
            cv.seg(col0.0, col0.1, col1.0, col1.1, 4, shirtD)
        }
        // front leg
        let lf = limb(0, hipY, p.hipF, 37, p.hipF - p.kneeF, 37)
        let shin: Col = zed && L.v % 2 == 1 ? skin : pants
        limb2(cv, 0, hipY, lf, 15, pants, 12, shin, ink)
        if zed && L.v % 2 == 1 { cv.circ(lf.0, lf.1, 7, pants); cv.circ((lf.0 + lf.2) / 2, (lf.1 + lf.3) / 2, 3, BLOOD.alpha(0.8)) }
        cv.seg(lf.2 - 2, lf.3, lf.2 + 12, lf.3, 11, ink)
        cv.seg(lf.2 - 2, lf.3, lf.2 + 12, lf.3, 8, shoe)
        if L.lower > 0 {
            let lc = Col.mix(L.lowerCol, WHITE, fl)
            let w0 = T(4, -12 * fat), w1 = T(4, 13 * fat)
            let len: Double = L.lower == 3 ? 44 : (L.lower == 2 ? 40 : 30)
            if L.lower == 2 {
                // an apron hangs off the front only
                let top = T(40, 15 * fat)
                let pts: [Double] = [top.0, top.1, w1.0 + 3, w1.1, w1.0 + 6, hipY + len, w1.0 - 16, hipY + len, w1.0 - 14, w1.1]
                cv.line(ink, 3.4, pts + [top.0, top.1]); cv.poly(lc, pts)
                if zed { cv.circ(w1.0 - 4, hipY + 14, 7, BLOOD.alpha(0.8)); cv.circ(w1.0 - 9, hipY + 28, 4, BLOOD.alpha(0.7)) }
            } else {
                let sway = (p.hipF - p.hipB) * 5
                let pts: [Double] = [w0.0, w0.1, w1.0, w1.1, w1.0 + 6 + max(0, sway), hipY + len, w0.0 - 6 + min(0, sway), hipY + len]
                cv.line(ink, 3.4, pts + [w0.0, w0.1]); cv.poly(lc, pts)
                cv.poly(Col.mix(lc, BLACK, 0.25), [w0.0, w0.1, w0.0 + 8, w0.1, w0.0 + 2 + min(0, sway), hipY + len, w0.0 - 6 + min(0, sway), hipY + len])
                if zed { cv.poly(lc, [w0.0 - 6, hipY + len, w0.0 + 2, hipY + len + 9, w0.0 + 8, hipY + len, w0.0 + 15, hipY + len + 7, w0.0 + 20, hipY + len]); cv.circ(w1.0 - 6, hipY + 16, 5, BLOOD.alpha(0.75)) }
            }
        }
        // neck and head
        cv.seg(nx, ny, (nx + hx) / 2, (ny + hy) / 2, 12, ink)
        cv.seg(nx, ny, (nx + hx) / 2, (ny + hy) / 2, 9, skinD)
        if L.noHead {
            cv.circ((nx + hx) / 2, (ny + hy) / 2, 6, Col(0x7a1014)); cv.circ((nx + hx) / 2, (ny + hy) / 2, 2.5, bone)
        } else if zed {
            cv.seg(nx, ny, hx, hy, 12, ink); cv.seg(nx, ny, hx, hy, 9, skinD)
            cv.save(); cv.translate(hx, hy); cv.rotate(clampD(ha, -1.2, 1.2) * 0.35)
            zedHead(cv, L, skin, ink, bone, p.jaw, p.bob)
            cv.restore()
            let hc = Col.mix(L.hatCol, WHITE, fl)
            switch L.hat {
            case 1:
                cv.save(); cv.translate(hx - 2, hy - 13); cv.rotate(-0.25)
                cv.RR(-13, -26, 26, 28, 9, ink); cv.RR(-11, -24, 22, 25, 8, hc); cv.circ(-7, -22, 8, hc); cv.circ(7, -22, 8, hc); cv.circ(0, -26, 8, hc)
                cv.R(-11, -6, 22, 6, Col.mix(hc, BLACK, 0.12)); cv.circ(4, -14, 3, BLOOD.alpha(0.7))
                cv.restore()
            case 2:
                cv.arcFill(hx, hy - 3, 17.5, PI, PI * 2, ink); cv.arcFill(hx, hy - 3, 16, PI, PI * 2, hc)
                cv.seg(hx - 16, hy - 4, hx + 22, hy - 4, 4.5, ink); cv.seg(hx - 15, hy - 4, hx + 21, hy - 4, 2.6, hc)
                cv.seg(hx, hy - 18, hx, hy - 6, 2.4, Col.mix(hc, BLACK, 0.2))
            case 3:
                cv.arcFill(hx, hy - 4, 16.5, PI, PI * 2, hc); cv.R(hx - 16, hy - 8, 32, 5, Col.mix(hc, BLACK, 0.3))
                cv.seg(hx + 6, hy - 5, hx + 24, hy - 3, 4, Col(0x0b0c10)); cv.circ(hx + 6, hy - 13, 3, GOLD)
            case 4:
                cv.arcFill(hx, hy - 2, 16.2, PI * 0.98, PI * 1.98, hc); cv.seg(hx - 14, hy - 3, hx - 20, hy + 4, 2, hc)
            case 5:
                cv.circ(hx - 1, hy - 2, 19, ink); cv.circ(hx - 1, hy - 2, 17.5, hc)
                cv.poly(rgba(150, 200, 230, 0.55), [hx + 2, hy - 10, hx + 18, hy - 8, hx + 19, hy + 8, hx + 4, hy + 10])
                cv.line(Col(0x0b0c10), 2, [hx + 2, hy - 10, hx + 18, hy - 8, hx + 19, hy + 8, hx + 4, hy + 10])
                cv.seg(hx - 16, hy - 12, hx + 12, hy - 15, 2.5, Col(0x3a4458)); cv.circ(hx + 8, hy + 3, 3, BLOOD.alpha(0.8))
            default: break
            }
        } else {
            cv.seg(nx, ny, hx, hy, 12, ink); cv.seg(nx, ny, hx, hy, 9, skinD)
            cv.save(); cv.translate(hx, hy); cv.rotate(clampD(ha, -1.2, 1.2) * 0.3)
            heroHead(cv, L, skin, ink, p.bob)
            cv.restore()
        }
        // front arm and what it holds
        let af = limb(nx, sy, p.armF, 27, p.armF + p.elbF, 26)
        let wa = p.armF + p.elbF + p.wpn
        if L.slung > 0 { cv.seg(nx - 9, sy - 4, nx + 9, sy + 30, 2.2, Col(0x2a2018)); gun(cv, L.slung, nx - 7, sy + 34, 2.75, ink) }
        if L.slung < 0 && L.weapon > 0 {
            // the melee weapon rides on the back while a gun is out
            let sc: Col = L.tier > 0 ? Col(0xaab4c0) : (L.weapon == 1 ? Col(0xc8a070) : (L.weapon == 2 ? Col(0xe8e8e8) : Col(0xd0a860)))
            cv.seg(nx - 9, sy - 4, nx + 9, sy + 30, 2.2, Col(0x2a2018))
            cv.seg(nx - 13, sy + 38, nx + 12, sy - 26, 8.5, ink); cv.seg(nx - 13, sy + 38, nx + 12, sy - 26, 5.5, sc)
            cv.seg(nx - 13, sy + 38, nx - 9, sy + 28, 5.5, Col(0x2a2018))
        }
        if L.gun > 0 {
            gun(cv, L.gun, af.2, af.3, wa, ink)
        } else if L.weapon > 0 {
            let len = L.weapon == 3 ? 78.0 : 64.0
            let gx = af.2 - 10 * sin(wa), gy = af.3 - 10 * cos(wa)
            let tx = af.2 + len * sin(wa), ty = af.3 + len * cos(wa)
            let mx = af.2 + len * 0.45 * sin(wa), my = af.3 + len * 0.45 * cos(wa)
            if L.weapon == 1 {
                cv.seg(gx, gy, tx, ty, 9.5, ink); cv.seg(mx, my, tx, ty, 13, ink)
                cv.seg(gx, gy, tx, ty, 6, Col(0x8a6a44)); cv.seg(mx, my, tx, ty, 9.5, Col(0xd9b98a))
                cv.seg(mx, my, tx, ty, 3, Col(0xf0d8b0))
                cv.circ(tx - 6 * sin(wa), ty - 6 * cos(wa), 3, BLOOD.alpha(0.8))
            } else if L.weapon == 2 {
                let bx = tx + 17 * sin(wa + 1.3), by = ty + 17 * cos(wa + 1.3)
                cv.seg(gx, gy, tx, ty, 8.5, ink); cv.seg(tx, ty, bx, by, 9.5, ink)
                cv.seg(gx, gy, tx, ty, 5, Col(0xe8e4dc)); cv.seg(tx, ty, bx, by, 6, Col(0x22262e))
                cv.seg(gx, gy, af.2 + 8 * sin(wa), af.3 + 8 * cos(wa), 6, Col(0x2a2a2a))
            } else {
                cv.seg(gx, gy, tx, ty, 8, ink)
                cv.seg(gx, gy, tx, ty, 4.5, Col(0xc9a24a))
                cv.seg(af.2 + len * 0.8 * sin(wa), af.3 + len * 0.8 * cos(wa), tx, ty, 3, Col(0xf2ecd8))
                cv.seg(gx, gy, af.2 + 14 * sin(wa), af.3 + 14 * cos(wa), 6, Col(0x3a2a1c))
            }
            if L.tier > 0 {
                // upgraded: a steel skin, then nails, then barbed wire
                let ux = cos(wa), uy = -sin(wa)
                let s0 = L.weapon == 1 ? 0.0 : 0.2
                let ax = af.2 + len * s0 * sin(wa), ay = af.3 + len * s0 * cos(wa)
                let wd: Double = L.weapon == 1 ? 9.5 : 4.5
                cv.seg(L.weapon == 1 ? mx : ax, L.weapon == 1 ? my : ay, tx, ty, wd, Col(0xaab4c0))
                if L.weapon == 1 { cv.seg(ax, ay, mx, my, 6, Col(0x7c8692)) }
                cv.seg(mx + ux * wd * 0.22, my + uy * wd * 0.22, tx + ux * wd * 0.22, ty + uy * wd * 0.22, 1.6, WHITE.alpha(0.85))
                cv.seg(gx, gy, af.2 + 12 * sin(wa), af.3 + 12 * cos(wa), 6, Col(0x1c1c20))
                if L.tier >= 2 {
                    for i in 0..<5 {
                        let k = 0.55 + Double(i) * 0.1
                        let px = af.2 + len * k * sin(wa), py = af.3 + len * k * cos(wa)
                        let sd: Double = i % 2 == 0 ? 1 : -1
                        let r = wd * 0.5 + 7
                        cv.seg(px, py, px + ux * r * sd, py + uy * r * sd, 3.2, ink)
                        cv.seg(px, py, px + ux * r * sd, py + uy * r * sd, 1.5, Col(0xd8dce2))
                    }
                }
                if L.tier >= 3 {
                    var pts: [Double] = []
                    for i in 0...8 {
                        let k = 0.5 + Double(i) * 0.06
                        let sd: Double = i % 2 == 0 ? 1 : -1
                        pts.append(af.2 + len * k * sin(wa) + ux * (wd * 0.5 + 1.5) * sd); pts.append(af.3 + len * k * cos(wa) + uy * (wd * 0.5 + 1.5) * sd)
                    }
                    cv.line(Col(0x2a2c30), 1.8, pts)
                    cv.circ(tx - 10 * sin(wa), ty - 10 * cos(wa), 3.4, BLOOD.alpha(0.85)); cv.circ(mx, my, 2.6, BLOOD.alpha(0.8))
                }
            }
        }
        let sleeve: Col = zed && L.v == 1 ? skin : slv
        limb2(cv, nx, sy, af, 11, sleeve, 9, skin, ink)
        if zed && L.v == 1 { cv.circ(nx, sy, 7, shirt) }
        let cap: Col = zed && L.v == 1 ? shirt : (L.sleeve != nil ? slv : shirtL)
        cv.circ(nx, sy, 6.5, cap)
        cv.circ(af.2, af.3, 6, skin)
        if zed {
            let fa = p.armF + p.elbF
            for d in [-0.55, 0.0, 0.55] { cv.seg(af.2, af.3, af.2 + 9 * sin(fa + d), af.3 + 9 * cos(fa + d), 2.4, Col(0x2a2a22)) }
            for d in [-0.5, 0.2] { let fb = p.armB + p.elbB; cv.seg(ab.2, ab.3, ab.2 + 8 * sin(fb + d), ab.3 + 8 * cos(fb + d), 2.2, Col(0x1c1c18)) }
        }
        cv.restore()
    }

    func heroLook(_ t: Tower) -> Look {
        var l = Look(shirt: t.shirt, pants: t.pants, skin: t.skin, hair: t.hair, eye: Col(0x15151a))
        l.weapon = t.weapon
        l.longHair = t.weapon != 1
        return l
    }
    func heroPose(_ g: Game) -> Pose {
        let h = g.hero
        var p = Pose()
        let t = g.t
        if g.supT >= 0 {
            let u = g.supT / g.supDur
            p.lean = 0.35
            p.armF = 1.5 + sin(u * 26) * 1.6
            p.elbF = 0.2
            p.wpn = 0.1
            p.armB = -0.9
            p.hipF = 0.8; p.kneeF = 0.5; p.hipB = -0.7; p.kneeB = 0.3
            p.bob = 6
            return p
        }
        if h.moving && h.atkT < 0 {
            let ph = h.walk * 0.042
            p.hipF = 0.78 * sin(ph)
            p.hipB = -0.78 * sin(ph)
            p.kneeF = 0.25 + 0.85 * max(0, -cos(ph))
            p.kneeB = 0.25 + 0.85 * max(0, cos(ph))
            p.lean = 0.2
            p.bob = abs(cos(ph)) * 5
            p.armB = 0.8 * sin(ph)
            p.elbB = 0.9
            p.armF = -0.35 - 0.25 * sin(ph)
            p.elbF = 1.5
            p.wpn = 1.2
        } else {
            p.bob = sin(t * 2.6) * 1.5 + 2
            p.hipF = 0.2; p.hipB = -0.2
            p.armF = 0.15; p.elbF = 1.35; p.wpn = 1.25
            p.armB = -0.15; p.elbB = 0.5
            p.lean = 0.05
        }
        if h.atkT >= 0 {
            let fin = h.atkI == 2
            let dur = fin || h.crit >= 0 ? 0.4 : (h.atkStyle == 2 ? 0.2 : 0.25)
            let u = clampD(h.atkT / dur, 0, 1)
            let e = easeOut(min(1, u / 0.55))
            let sw = sin(u * PI)
            p.lean = 0.12 + 0.32 * sw
            p.hipF = 0.5 + 0.25 * sw; p.kneeF = 0.4
            p.hipB = -0.45; p.kneeB = 0.15
            p.bob = 4 + 3 * sw
            p.armB = -0.8
            p.elbF = 0.25; p.wpn = 0.1
            switch h.atkStyle {
            case 1: p.armF = lerp(0.1, 2.7, e)                         // backhand, rising
            case 2: p.armF = 1.5; p.elbF = lerp(1.7, 0.02, e); p.wpn = 0; p.lean = 0.3 + 0.2 * sw; p.hipF = 0.9; p.hipB = -0.8   // thrust
            case 3: p.armF = lerp(-0.3, 1.2, e); p.lean = 0.6; p.bob = 16; p.kneeF = 1.0; p.kneeB = 0.9; p.wpn = 0.5          // low sweep
            case 4: p.hipF = lerp(0.1, 1.6, e); p.kneeF = lerp(1.2, 0.05, e); p.lean = -0.25; p.armF = -0.6; p.elbF = 1.2; p.wpn = 1.2; p.armB = -1.2   // kick
            case 5: p.armF = lerp(-0.7, 2.9, e); p.lean = 0.3 - 0.5 * e; p.bob = 12 - 12 * e                                 // uppercut
            case 6: p.armF = 1.55; p.elbF = 0.05; p.wpn = 0; p.lean = 0.1; p.hipF = 0.5; p.hipB = -0.5                          // spin
            case 7: p.armF = lerp(4.1, 0.4, easeOut(max(0, u - 0.35) / 0.3)); p.kneeF = 0.9; p.kneeB = 0.9; p.hipF = 0.7; p.bob = u > 0.5 ? 14 : 0   // jump slam
            case 9: p.armB = 1.5; p.elbB = lerp(1.7, 0.02, e); p.armF = -0.9; p.elbF = 1.3; p.wpn = 1.3; p.lean = 0.3 + 0.25 * sw; p.hipF = 0.9; p.hipB = -0.8   // punch
            case 8: p.armF = lerp(-0.5, 3.3, e); p.lean = 0.25 - 0.55 * e; p.hipF = 0.8; p.bob = 14 - 16 * e                 // launcher
            default: p.armF = lerp(3.5, 1.1, e); p.elbF = 0.3
            }
        }
        if g.heldGun > 0 {
            let kick = g.kickT > 0 ? g.kickT / 0.15 : 0
            p.armF = 1.32 + 0.35 * kick; p.elbF = 0.2; p.wpn = 0.05; p.armB = 1.0; p.elbB = 0.7; p.lean -= 0.12 * kick
        }
        if g.swapT >= 0 && h.atkT < 0 && g.supT < 0 {
            // swing what is in the hand up and back over the shoulder, then bring the other one out
            let k = g.swapT < 0.5 ? g.swapT * 2 : (1 - g.swapT) * 2
            p.armF += (-2.6 - p.armF) * k; p.elbF += (-0.7 - p.elbF) * k; p.wpn += (-0.5 - p.wpn) * k
            p.lean -= 0.06 * k
        }
        if h.hurtT > 0 { p.lean = -0.3; p.head = -0.3 }
        return p
    }
    private let zShirts: [Col] = [Col(0x5a6470), Col(0x6a5a4a), Col(0x4a5a4e), Col(0x6e4a4e), Col(0x565070)]
    func zedLook(_ z: Zed) -> Look {
        var l = Look(shirt: zShirts[z.look % 5], pants: Col(0x33363c), skin: Col(0x9fb08c), hair: Col(0x2a2a26), eye: Col(0xffe14a))
        l.zombie = true
        l.v = z.look % 5
        l.female = z.female
        l.fat = z.fatMul
        let hairs: [Col] = [Col(0x2a2a26), Col(0x5a3a22), Col(0x8a7a4a), Col(0x6a6a66), Col(0x3a1c14)]
        l.hair = hairs[(z.look + z.style) % 5]
        let skins: [Col] = [Col(0x9fb08c), Col(0xa8a890), Col(0x8a9a80), Col(0x7f8f6c)]
        l.skin = skins[(z.look * 3 + z.style) % 4]
        if z.kind == .zed || z.kind == .runner || z.kind == .crawler || z.kind == .wheel {
            l.job = z.job
            switch z.job {
            case 0:   // suit
                let suits: [Col] = [Col(0x23283a), Col(0x3a3a40), Col(0x1c1c22), Col(0x4a3a30)]
                l.shirt = suits[z.look % 4]; l.pants = l.shirt
                if z.female { l.lower = 1; l.lowerCol = l.shirt }
            case 1:   // office
                let tops: [Col] = [Col(0xc9d2dc), Col(0x8aa0c0), Col(0xd9b0b8), Col(0xb8c8a0), Col(0xe0d8c0)]
                l.shirt = tops[z.look % 5]; l.pants = Col(0x2a2f3c)
                if z.female { l.lower = 1; l.lowerCol = Col(0x2a2a30) }
            case 2:   // cook
                l.shirt = Col(0xe8e6e0); l.pants = Col(0x5a5f68); l.lower = 2; l.lowerCol = Col(0xd0ccc0); l.hat = 1; l.hatCol = Col(0xf2f0ea)
            case 3:   // medic
                let scrubs: [Col] = [Col(0x3a9a94), Col(0x4a78b0), Col(0x7a9ad0), Col(0x5aa07a)]
                l.shirt = scrubs[z.look % 4]; l.pants = l.shirt
                if z.look % 3 == 0 { l.coat = true; l.shirt = Col(0xdcdcd4) } else { l.hat = 4; l.hatCol = l.shirt }
            case 4:   // guard
                l.shirt = Col(0x26324a); l.pants = Col(0x1c2434); l.hat = 3; l.hatCol = Col(0x1c2434)
            case 5:   // janitor
                l.shirt = Col(0x5a6a5a); l.pants = Col(0x5a6a5a)
            case 6:   // waiter
                l.shirt = Col(0x1c1c22); l.sleeve = Col(0xe8e6e0); l.pants = Col(0x1c1c22)
                if z.female { l.lower = 2; l.lowerCol = Col(0xe8e6e0) }
            case 8:   // patient
                l.shirt = Col(0xa8c4d4); l.lower = 3; l.lowerCol = Col(0xa8c4d4); l.pants = l.skin; l.barefoot = true
            case 9:   // builder
                l.shirt = Col(0xe07a20); l.pants = Col(0x3a4a66); l.hat = 2; l.hatCol = Col(0xf0c020)
            default:  // casual
                let tees: [Col] = [Col(0x6a4a7a), Col(0x4a6a8a), Col(0x8a4a3a), Col(0x4a7a5a), Col(0x7a7a3a)]
                l.shirt = tees[z.look % 5]; l.pants = Col(0x3a4a66)
                if z.female && z.look % 2 == 0 { l.lower = 1; l.lowerCol = Col(0x3a4a66) }
            }
        }
        if z.kind == .runner { l.skin = Col(0xb89a8a); l.eye = Col(0xff5a4a); l.fat = min(l.fat, 0.95) }
        if z.kind == .spitter { l.fat = 1.15; l.skin = Col(0xb7c46a); l.shirt = Col(0x4a5a30); l.eye = Col(0x8cff7a) }
        if z.kind == .riot { l.shirt = Col(0x1c2230); l.pants = Col(0x161a24); l.hat = 5; l.hatCol = Col(0x161a24); l.fat = 1.2; l.female = false; l.job = 4 }
        if z.kind == .burner { l.skin = Col(0x2a2420); l.shirt = Col(0x1a1614); l.pants = Col(0x141210); l.hair = Col(0x0e0c0a); l.eye = Col(0xffa030) }
        if z.kind == .screamer { l.skin = Col(0xd0d4c8); l.female = true; l.v = 1; l.hair = Col(0x1a1a1e); l.shirt = Col(0xdcdcd8); l.lower = 3; l.lowerCol = Col(0xdcdcd8); l.pants = Col(0xd0d4c8); l.barefoot = true; l.eye = Col(0xffffff); l.fat = 0.9 }
        l.noHead = z.headless
        if z.kind == .bloater { l.fat = 1.9; l.skin = Col(0x9ac06a); l.shirt = Col(0x6a7a3a); l.eye = Col(0xd9ff7a) }
        if z.kind == .boss { l.fat = 1.5; l.skin = Col(0x8cc09a); l.shirt = Col(0xd9dcd6); l.pants = Col(0x2a2f3c); l.coat = true; l.eye = Col(0x7dffb0); l.hair = Col(0x9a9a92) }
        return l
    }
    func zedPose(_ z: Zed, _ t: Double) -> Pose {
        var p = Pose()
        let ph = z.walk * (z.kind == .runner ? 0.05 : 0.07)
        let sw = z.kind == .runner ? 0.75 : 0.45
        p.hipF = sw * sin(ph)
        p.hipB = -sw * sin(ph)
        p.kneeF = 0.2 + 0.5 * max(0, -cos(ph))
        p.kneeB = 0.2 + 0.5 * max(0, cos(ph))
        p.lean = z.kind == .runner ? 0.45 : 0.26
        p.head = 0.25 + 0.12 * sin(t * 3 + z.seed * 9)
        p.bob = abs(cos(ph)) * 3
        p.armF = 1.4 + 0.14 * sin(t * 3.1 + z.seed * 20)
        p.elbF = 0.15
        p.armB = 1.15 + 0.14 * sin(t * 2.7 + z.seed * 11)
        p.elbB = 0.2
        p.jaw = 0.35 + 0.3 * sin(t * 5 + z.seed * 30)
        switch z.style {
        case 1: p.armB = 0.2; p.elbB = 0.3; p.head = 0.5; p.hipB *= 0.4          // one arm, dragging a leg
        case 2: p.armF = 0.3 + 0.2 * sin(t * 2 + z.seed); p.armB = 0.1; p.lean += 0.12; p.head = -0.2   // arms down, slumped
        case 3: p.armF = 2.2 + 0.3 * sin(t * 6 + z.seed * 9); p.armB = 1.9 + 0.3 * sin(t * 5); p.head = -0.3   // clawing at the air
        default: break
        }
        if z.atkT >= 0 {
            let wu = z.atkKind == 2 ? z.windup * 1.5 : z.windup
            let u = clampD(z.atkT / wu, 0, 1.6)
            if z.atkKind == 1 {
                p.lean = 0.9; p.armF = 1.6; p.armB = 1.5; p.hipF = 1.0; p.kneeF = 0.3; p.hipB = -1.0; p.kneeB = 0.2; p.bob = -10 * sin(min(1, u) * PI)
            } else if z.atkKind == 2 {
                if u < 1 { p.armF = lerp(1.4, 3.6, u); p.armB = lerp(1.2, 3.4, u); p.lean = -0.2 * u } else { p.armF = 0.5; p.armB = 0.4; p.lean = 0.75; p.bob = 8 }
            } else if u < 1 { p.armF = lerp(1.4, 2.7, u); p.armB = lerp(1.15, 2.5, u); p.lean = 0.1 } else { p.armF = 0.9; p.armB = 0.8; p.lean = 0.55 }
            p.jaw = 1.1
        }
        if z.kind == .crawler {
            let ph2 = z.walk * 0.09
            p.lean = 1.32; p.bob = 52; p.head = -0.9
            p.hipF = -1.45; p.kneeF = 0.05; p.hipB = -1.55; p.kneeB = 0.0
            p.armF = 1.9 + 0.7 * sin(ph2); p.elbF = -0.5; p.armB = 1.9 - 0.7 * sin(ph2); p.elbB = -0.5
            if z.atkT >= 0 { p.armF = 2.6; p.head = -1.2 }
        }
        if z.kind == .wheel {
            let ph2 = z.walk * 0.05
            p.bob = 28; p.lean = 0.28; p.head = 0.2
            p.hipF = 1.45; p.kneeF = 1.45; p.hipB = 1.3; p.kneeB = 1.35
            p.armF = 0.5 + 0.6 * sin(ph2); p.elbF = 0.5; p.armB = 0.5 + 0.6 * sin(ph2 + 0.4); p.elbB = 0.5
            if z.atkT >= 0 { p.armF = 1.7; p.armB = 1.5; p.elbF = 0.1; p.lean = 0.55 }
        }
        if z.kind == .screamer && z.screamT > 0 { p.lean = -0.3; p.head = -0.7; p.jaw = 1.2; p.armF = -0.6; p.armB = -0.9; p.elbF = -0.4; p.elbB = -0.4 }
        if z.kind == .spitter && z.atkT >= 0 { p.lean = -0.25 + 0.6 * min(1, z.atkT * 4); p.head = -0.5; p.jaw = 1.2; p.armF = 0.3; p.armB = 0.1 }
        if z.stun > 0 { p.lean = z.kind == .crawler ? 1.2 : -0.3; p.head = -0.4; p.armF = 0.4; p.armB = 0.2 }
        return p
    }
    func beast(_ cv: Canvas, _ z: Zed, _ y: Double, _ t: Double) {
        let dead = !z.alive
        let dk: Double = dead ? min(1, z.deadT * 3.5) : 0
        let mv = !dead && z.atkT < 0 && z.aware && z.stun <= 0
        let ph = z.walk * 0.085
        let bite: Double = z.atkT >= 0 ? sin(min(1, z.atkT / (z.windup + 0.28)) * PI) : 0
        let hitC = z.flash > 0.3
        cv.save()
        cv.translate(z.x, y)
        if dead { cv.alpha(max(0.2, 1 - z.deadT / 6)) }
        if z.kind == .rat {
            cv.scale(z.face, 1)
            var by = -5.0
            if !dead {
                let hop: Double = mv ? abs(sin(ph * 3)) * 2 : 0
                by = -9.0 - hop - bite * 8
            }
            cv.translate(bite * 8, 0)
            cv.curve(-13, by + 2, -26, by - 6 + sin(ph * 2) * 3, -34, by + 5, 2, Col(0xb98a86))
            if !dead {
                for lx in [-8.0, 8.0] {
                    let sw: Double = mv ? sin(ph * 3 + lx) * 5 : 0
                    cv.seg(lx, by + 4, lx + sw, 0, 2.2, Col(0x1a1512))
                }
            }
            let fur = hitC ? Col(0xe8e0d8) : Col(0x2b2420)
            cv.ell(0, by, 15, 7.5, fur)
            cv.poly(fur, [8, by - 6, 25, by + 1, 8, by + 6])
            cv.circ(9, by - 6, 3.5, fur)
            cv.ell(-4, by - 2, 5, 3, Col(0x6a1418))
            if !dead { cv.circ(16, by - 2, 1.6, Col(0xff4a3a)) }
            cv.restore()
            return
        }
        cv.scale(z.face * 1.3, 1.3)
        let trot: Double = mv ? abs(sin(ph)) * 4 : 0
        let by: Double = -46.0 + dk * 34 - trot - bite * 12
        cv.translate(bite * 22, 0)
        cv.rotate(-bite * 0.18)
        let fur = hitC ? Col(0xe8e0d8) : Col(0x2c2724)
        let furD = hitC ? Col(0xcfc6bc) : Col(0x1a1715)
        cv.curve(-36, by - 4, -52, by - 18 + sin(t * 9 + z.x) * 4 + dk * 24, -58, by - 4 + dk * 14, 5, furD)
        func leg(_ hx: Double, _ off: Double, _ col: Col) {
            if dead {
                cv.line(col, 6, [hx, by + 6, hx + 16, by + 12, hx + 34, by + 9])
            } else {
                let sw: Double = mv ? sin(ph + off) * 17 : 0
                let lift: Double = mv ? max(0, cos(ph + off)) * 9 : 0
                cv.line(col, 6, [hx, by + 6, hx + sw * 0.4 - 4, by + 24 - lift * 0.5, hx + sw + bite * 8, -lift])
            }
        }
        leg(-28, 0, furD)
        leg(18, PI * 0.9, furD)
        cv.ell(-4, by, 34, 13, fur)
        cv.circ(20, by - 1, 16, fur)
        cv.circ(-26, by + 1, 14, fur)
        cv.ell(-2, by + 2, 15, 9, Col(0x7a1c20))
        for i in 0..<4 {
            let rx = -12.0 + Double(i) * 7
            cv.curve(rx, by - 5, rx + 3, by + 3, rx - 1, by + 10, 2.2, Col(0xd8d0bc))
        }
        leg(-20, PI, fur)
        leg(26, PI * 1.9, fur)
        let hx: Double = dead ? 46 : 40
        let nod: Double = mv ? sin(ph) * 2 : 0
        let hy: Double = by - 16 + dk * 20 + nod
        cv.seg(26, by - 6, hx, hy, 15, fur)
        cv.circ(hx + 4, hy, 11, fur)
        cv.poly(fur, [hx - 2, hy - 9, hx - 6, hy - 24, hx + 7, hy - 10])
        var jaw = 0.1
        if !dead {
            let pant: Double = mv ? 0.1 + 0.08 * sin(ph * 2) : 0
            jaw = 0.12 + bite * 0.6 + pant
        }
        cv.save()
        cv.translate(hx + 8, hy + 1)
        cv.save()
        cv.rotate(-jaw * 0.5)
        cv.poly(fur, [0, -7, 24, -4, 24, 1, 0, 2])
        for i in 0..<4 { let tx = 7.0 + Double(i) * 4.5; cv.poly(Col(0xf2ecd8), [tx, 1, tx + 2, 6, tx + 4, 1]) }
        cv.restore()
        cv.rotate(jaw)
        cv.poly(Col(0x7a1014), [0, 1, 21, 2, 20, 7, 0, 8])
        for i in 0..<3 { let tx = 8.0 + Double(i) * 4.5; cv.poly(Col(0xf2ecd8), [tx, 2, tx + 2, -3, tx + 4, 2]) }
        cv.restore()
        if !dead { cv.circ(hx + 8, hy - 4, 2.6, Col(0xffe14a)) }
        if z.burn > 0 && !dead { cv.lighter(true); cv.ell(0, by - 4, 44, 24, rgba(255, 140, 40, 0.45)); cv.lighter(false) }
        cv.restore()
    }

    // ---------- flames
    func flameWall(_ cv: Canvas, _ x: Double, _ w: Double, _ hgt: Double, _ seed: Double, _ t: Double) {
        cv.lighter(true)
        cv.glow(x, GY - hgt * 0.4, w * 1.5, rgba(255, 130, 40, 0.3 + 0.06 * sin(t * 11 + seed)))
        cv.lighter(false)
        let layers: [(Double, Col)] = [(1, rgba(255, 110, 25, 0.9)), (0.72, rgba(255, 200, 80, 0.95)), (0.42, rgba(255, 246, 210, 0.95))]
        let N = 14
        for (sc, col) in layers {
            var pts: [Double] = [x - w / 2 * sc, GY]
            for i in 0...N {
                let u = Double(i) / Double(N)
                let fi = Double(i)
                let wob = abs(sin(fi * 1.9 + seed + t * (5 + sc * 3) + sin(t * 3.1 + fi)))
                let fh = hgt * sc * (0.5 + 0.5 * wob) * (0.35 + 0.65 * sin(u * PI))
                let px = x - w / 2 * sc + w * sc * u
                pts.append(px - 5); pts.append(GY - fh * 0.6)
                pts.append(px + sin(t * 7 + fi) * 6); pts.append(GY - fh)
            }
            pts.append(x + w / 2 * sc); pts.append(GY)
            cv.poly(col, pts)
        }
    }

    // ---------- the floor you are on
    private func night(_ cv: Canvas, _ x: Double, _ w: Double, _ h: Double, _ t: Double) {
        cv.vfill(x, 0, w, h, [(0, Col(0x03040a)), (0.6, Col(0x140c22)), (1, Col(0x4a2018))])
        for i in 0..<50 {
            let fi = Double(i)
            let a = 0.3 + 0.7 * abs(sin(t * 0.8 + fi))
            cv.R(x + hashN(fi) * w, hashN(fi + 40) * h * 0.7, 2, 2, WHITE.alpha(a * 0.8))
        }
    }
    private func skyline(_ cv: Canvas, _ x: Double, _ w: Double, _ base: Double, _ par: Double) {
        var bx = x - 40 - (par.truncatingRemainder(dividingBy: 90))
        var i = Int(par / 90)
        while bx < x + w {
            let fi = Double(abs(i))
            let bh = 80 + hashN(fi * 3.1) * 190
            let bw = 60 + hashN(fi * 1.7) * 40
            cv.R(bx, base - bh, bw, bh, Col(0x0d0f1a))
            var wy = base - bh + 10
            while wy < base - 12 {
                var wx = bx + 6
                while wx < bx + bw - 8 {
                    if hashN(wx * 0.37 + wy * 1.3) > 0.72 { cv.R(wx, wy, 5, 7, rgba(255, 220, 160, 0.4)) }
                    wx += 11
                }
                wy += 14
            }
            bx += bw + 12
            i += 1
        }
    }
    private func sign(_ cv: Canvas, _ s: String, _ x: Double, _ y: Double, _ col: Col, _ t: Double, arrow: Bool = true, alpha: Double = 1) {
        let w = cv.textW(s, 14, 3) + 22
        cv.RR(x - w / 2, y - 14, w, 24, 5, Col(0x0d1a13).alpha(alpha))
        cv.text(s, x, y + 4, 14, col.alpha(alpha), 1, 3)
        if arrow {
            let b = sin(t * 5) * 4
            cv.poly(col, [x - 9, y + 16 + b, x + 9, y + 16 + b, x, y + 28 + b])
        }
    }
    private func drawFloor(_ g: Game, _ cv: Canvas, _ x0: Double, _ W: Double) {
        let f = g.floor
        let z = g.zone(f.n)
        let t = g.t
        let x1 = x0 + W
        if f.kind == .roof || f.kind == .street {
            night(cv, x0, W, GY, t)
            skyline(cv, x0, W, GY - (f.kind == .roof ? 20 : 0), x0 * 0.3)
            if f.kind == .street {
                var bx = 0.0
                var i = 0
                while bx < FLOOR_W {
                    let h = 250 + hashN(Double(i) * 5.3) * 90
                    let face: Col = i % 2 == 0 ? Col(0x17141c) : Col(0x1c1820)
                    cv.R(bx, GY - h, 190, h, face)
                    for r in 0..<3 { for c in 0..<3 {
                        let wx = bx + 22 + Double(c) * 54, wy = GY - h + 26 + Double(r) * 64
                        let burn = (i * 3 + r * 5 + c) % 7 == 0
                        cv.R(wx, wy, 36, 44, burn ? rgba(255, 140, 40, 0.75 + 0.2 * sin(t * 9 + wx)) : Col(0x07080c))
                    } }
                    bx += 200
                    i += 1
                }
                cv.lighter(true); cv.glow(x0 + W / 2, GY, 700, rgba(255, 90, 30, 0.22)); cv.lighter(false)
                cv.R(x0, GY, W, VIEW_H - GY, Col(0x17181c))
                var dx = (x0 / 90).rounded(.down) * 90
                while dx < x1 { cv.R(dx, GY + 50, 46, 4, rgba(232, 200, 96, 0.5)); dx += 90 }
                sign(cv, "THE PLAZA", f.exitX, GY - 190, MINT, t)
            } else {
                cv.R(x0, GY, W, VIEW_H - GY, Col(0x1b1d24))
                var rx = (x0 / 16).rounded(.down) * 16
                while rx < x1 { cv.R(rx, GY - 78, 2, 78, Col(0x2a2f3b)); rx += 16 }
                cv.R(x0, GY - 80, W, 4, Col(0x2a2f3b))
                let dx = f.exitX
                cv.R(dx - 110, GY - 250, 260, 250, Col(0x22262f))
                cv.R(dx - 118, GY - 258, 276, 12, Col(0x2f3440))
                cv.R(dx - 45, GY - 190, 90, 190, Col(0x060608))
                sign(cv, "STAIRS", dx, GY - 214, MINT, t)
            }
            return
        }
        // inside
        if f.escape { escapeBack(g, cv, x0, W) } else {
        let wa = wallArt(z)
        if let im = wallFor(wa.0, wa.1, 300, cv.sc) {
            cv.R(x0, 0, W, GY - 300, Col(0x05060a))
            wallTiles(cv, im, x0, x1, GY - 300, 300, f.n / 3)
            if f.n % 4 == 0 { cv.R(x0, 0, W, GY, BLACK.alpha(hashN((t * 11).rounded(.down)) > 0.72 ? 0.1 : 0.3)) }
            let who = tenant(z, f.n / 3)
            if !who.isEmpty && f.kind != .safe {
                // tenant plaques fade out while they pass under the panel at top left or a kill banner
                let busy = g.floaters.contains { $0.size >= 30 && $0.t < 1.2 }
                for sx in [520.0, 1290.0] {
                    let on = sx - x0
                    var a = clampD((on - 330) / 90, 0, 1)
                    if busy { a = min(a, 0.25) }
                    if a > 0.02 { sign(cv, who, sx, GY - 268, Col.mix(z.trim, WHITE, 0.55), t, arrow: false, alpha: a) }
                }
            }
        } else {
        cv.R(x0, 0, W, GY - 300, Col.mix(z.wall, BLACK, 0.72))
        cv.R(x0, GY - 300, W, 300, z.wall)
        cv.R(x0, GY - 312, W, 14, Col.mix(z.floor, BLACK, 0.5))
        cv.R(x0, GY - 14, W, 14, Col.mix(z.wall, BLACK, 0.3))
        cv.R(x0, GY - 104, W, 90, Col.mix(z.wall, BLACK, 0.13))
        cv.R(x0, GY - 107, W, 4, Col.mix(z.trim, BLACK, 0.25))
        var sx2 = (x0 / 100).rounded(.down) * 100
        while sx2 < x1 { cv.R(sx2, GY - 103, 1.5, 89, Col.mix(z.wall, BLACK, 0.26)); sx2 += 100 }
        let lightsOn = f.n % 4 != 0
        var px = (x0 / 300).rounded(.down) * 300
        while px < x1 + 300 {
            // a window, then a door
            let wx = px + 40
            cv.R(wx - 6, GY - 236, 132, 152, z.trim)
            cv.vfill(wx, GY - 230, 120, 140, [(0, Col(0x05060c)), (0.55, Col(0x1a1024)), (1, Col(0x8a3a1c))])
            let par = wx * 0.5
            for b in 0..<4 {
                let fb = Double(b)
                let bh = 30 + hashN(fb + (par / 100).rounded(.down)) * 70
                cv.R(wx + fb * 30, GY - 90 - bh, 24, bh, Col(0x08090f))
            }
            cv.R(wx + 58, GY - 230, 4, 140, z.trim)
            cv.R(wx, GY - 162, 120, 4, z.trim)
            let dx = px + 200
            cv.R(dx - 4, GY - 176, 74, 176, Col.mix(z.trim, BLACK, 0.2))
            cv.R(dx, GY - 172, 66, 172, Col.mix(z.wall, BLACK, 0.45))
            cv.circ(dx + 56, GY - 84, 3.5, GOLD.alpha(0.8))
            let num = f.n * 100 + Int(abs(px) / 150) % 60 + 1
            cv.text("\(num)", dx + 33, GY - 184, 10, WHITE.alpha(0.45), 1, 1)
            // something on the wall between the door and the next window
            let hd = hashN(px * 0.013 + Double(f.n) * 1.7)
            let ox = px + 302
            if hd < 0.22 {
                cv.R(ox - 22, GY - 232, 44, 56, Col(0x1a1c22)); cv.R(ox - 19, GY - 229, 38, 50, Col.mix(z.trim, Col(0x7a4a3a), hashN(px)))
                cv.poly(Col.mix(z.wall, WHITE, 0.3), [ox - 19, GY - 190, ox - 4, GY - 212, ox + 6, GY - 198, ox + 19, GY - 216, ox + 19, GY - 179, ox - 19, GY - 179])
            } else if hd < 0.4 {
                cv.RR(ox - 8, GY - 176, 16, 44, 5, Col(0xb8221c)); cv.R(ox - 3, GY - 184, 6, 9, Col(0x2a2a2a)); cv.seg(ox + 3, GY - 180, ox + 12, GY - 166, 2.5, Col(0x1a1a1a)); cv.R(ox - 8, GY - 160, 16, 8, Col(0xe8e6e0))
            } else if hd < 0.55 {
                cv.R(ox - 22, GY - 286, 44, 22, Col(0x15171c)); for i in 0..<5 { cv.R(ox - 19, GY - 283 + Double(i) * 4, 38, 2, Col(0x3a3f4a)) }
            } else if hd < 0.7 {
                cv.line(Col.mix(z.wall, BLACK, 0.5), 2, [ox - 10, GY - 250, ox - 2, GY - 226, ox - 12, GY - 204, ox + 2, GY - 180, ox - 6, GY - 150])
                cv.line(Col.mix(z.wall, BLACK, 0.5), 1.5, [ox - 2, GY - 226, ox + 14, GY - 214])
            } else if hd < 0.82 {
                for i in 0..<4 { let bx2 = ox - 18 + hashN(px + Double(i)) * 36, by2 = GY - 150 - hashN(px + Double(i) * 3) * 90; cv.circ(bx2, by2, 3.2, Col(0x0b0c10)); cv.ring(bx2, by2, 5, 1.2, Col.mix(z.wall, WHITE, 0.25)) }
            } else {
                cv.RR(ox - 20, GY - 240, 40, 26, 3, Col(0x0d1a13)); cv.text("EXIT", ox, GY - 222, 13, MINT, 1, 3)
                cv.lighter(true); cv.glow(ox, GY - 227, 46, rgba(125, 255, 176, 0.16)); cv.lighter(false)
            }
            // ceiling light: a cone of it on the floor; dead floors flicker
            var on = lightsOn
            if !lightsOn { on = hashN((t * 11).rounded(.down) + px) > 0.72 }
            cv.R(px + 146, GY - 302, 68, 7, Col(0x15171c))
            cv.R(px + 150, GY - 300, 60, 5, on ? Col(0xfff2d0) : Col(0x3a3a3a))
            if on {
                cv.lighter(true)
                cv.glow(px + 180, GY - 290, 150, rgba(255, 240, 200, 0.10))
                cv.poly(rgba(255, 240, 200, 0.045), [px + 150, GY - 295, px + 210, GY - 295, px + 300, GY, px + 60, GY])
                cv.ell(px + 180, GY + 6, 120, 9, rgba(255, 240, 200, 0.06))
                cv.lighter(false)
            }
            // firelight from the city falling through the window
            cv.lighter(true); cv.poly(rgba(255, 130, 60, 0.05), [wx, GY - 90, wx + 120, GY - 90, wx + 190, GY, wx + 40, GY]); cv.lighter(false)
            px += 300
        }
        }
        for (sx, sy2, sr) in f.splats where sx > x0 - 60 && sx < x1 + 60 {
            cv.circ(sx, GY - sy2, sr, Col(0x6a0c12, 0.82)); cv.circ(sx + sr * 0.7, GY - sy2 - sr * 0.4, sr * 0.45, Col(0x6a0c12, 0.8)); cv.circ(sx - sr * 0.8, GY - sy2 + sr * 0.3, sr * 0.35, Col(0x6a0c12, 0.8))
            cv.seg(sx, GY - sy2, sx, GY - sy2 + sr * 2.4, 3, Col(0x6a0c12, 0.75)); cv.seg(sx + sr * 0.5, GY - sy2, sx + sr * 0.5, GY - sy2 + sr * 1.4, 2.2, Col(0x6a0c12, 0.7))
        }
        for p in f.props where p.x > x0 - 80 && p.x < x1 + 80 { prop(cv, p, z) }
        // floor and what is under it
        cv.R(x0, GY, W, 22, z.floor)
        cv.R(x0, GY, W, 3, Col.mix(z.floor, WHITE, 0.15))
        var tx2 = (x0 / 75).rounded(.down) * 75
        while tx2 < x1 { cv.R(tx2, GY + 3, 1.5, 19, Col.mix(z.floor, BLACK, 0.3)); tx2 += 75 }
        cv.vfill(x0, GY + 3, W, 10, [(0, WHITE.alpha(0.07)), (1, WHITE.alpha(0))])
        cv.R(x0, GY + 22, W, 14, Col(0x101216))
        cv.R(x0, GY + 36, W, VIEW_H - GY - 36, Col.mix(g.zone(f.n - 1).wall, BLACK, 0.55))
        }
        // end walls
        cv.R(-400, 0, 400 + 46, VIEW_H, Col(0x0c0d12))
        cv.R(FLOOR_W - 46, 0, 446, VIEW_H, Col(0x0c0d12))
        for (px2, r) in f.pools { cv.ell(px2, GY + 8, r, r * 0.16, Col(0x5a0c10, 0.75)) }
        // the way out
        let ex = f.exitX
        if f.kind == .rope {
            // the stairs caved in, so out the window: glass smashed out, a fire hose tied to the radiator and thrown over the sill
            cv.R(ex - 66, GY - 222, 132, 150, Col.mix(z.trim, BLACK, 0.55))
            cv.vfill(ex - 58, GY - 214, 116, 134, [(0, Col(0x0a0c1c)), (1, Col(0x2a1410))])
            for i in 0..<6 {
                let bx = ex - 56 + Double(i) * 19, bh = 30 + hashN(Double(i) + 4) * 50
                cv.R(bx, GY - 80 - bh, 15, bh, Col(0x05060c))
                if hashN(Double(i) + 9) > 0.5 { cv.R(bx + 4, GY - 76 - bh * 0.6, 4, 4, rgba(255, 200, 120, 0.7)) }
            }
            cv.lighter(true); cv.glow(ex + 20, GY - 84, 46, rgba(255, 110, 30, 0.35 + 0.1 * sin(t * 6))); cv.lighter(false)
            let gl = Col(0xbfe0ff).alpha(0.55)
            cv.poly(gl, [ex - 58, GY - 214, ex - 30, GY - 214, ex - 48, GY - 188, ex - 58, GY - 170])
            cv.poly(gl, [ex + 58, GY - 214, ex + 40, GY - 214, ex + 52, GY - 180])
            cv.poly(gl, [ex - 58, GY - 80, ex - 40, GY - 80, ex - 58, GY - 104])
            cv.poly(gl, [ex + 58, GY - 80, ex + 30, GY - 80, ex + 50, GY - 98, ex + 58, GY - 120])
            cv.R(ex - 70, GY - 80, 140, 10, Col.mix(z.trim, WHITE, 0.15))
            // radiator and the hose
            cv.R(ex - 50, GY - 62, 100, 56, Col(0x6a707a))
            for i in 0..<8 { cv.R(ex - 46 + Double(i) * 12.5, GY - 60, 7, 52, Col(0x8a909a)) }
            let hose = Col(0xc23a22)
            cv.ring(ex - 10, GY - 34, 14, 6, hose)
            cv.line(hose, 7, [ex - 10, GY - 48, ex - 4, GY - 76, ex + 8, GY - 84, ex + 20, GY - 76, ex + 24, GY - 40, ex + 28, GY + 12])
            cv.line(Col(0x8a2414), 2, [ex - 4, GY - 76, ex + 8, GY - 84, ex + 20, GY - 76])
        } else if f.escape {
            // a hatch in the landing with a ladder going down
            cv.R(ex - 40, GY - 2, 80, 14, Col(0x020203))
            cv.R(ex - 26, GY - 150, 5, 160, Col(0x4a5262)); cv.R(ex + 21, GY - 150, 5, 160, Col(0x4a5262))
            for i in 0..<8 { cv.R(ex - 22, GY - 140 + Double(i) * 19, 44, 4, Col(0x5a6272)) }
            cv.seg(ex - 24, GY - 150, ex - 34, GY - 166, 4, Col(0x4a5262)); cv.seg(ex + 24, GY - 150, ex + 34, GY - 166, 4, Col(0x4a5262))
        } else {
            // a stairwell door: frame, the first steps going down, a rail, green exit light from above
            cv.R(ex - 52, GY - 198, 104, 198, Col.mix(z.trim, BLACK, 0.6))
            cv.R(ex - 44, GY - 190, 88, 190, Col(0x06070a))
            for i in 0..<7 {
                let k = Double(i), fade = 0.95 - k * 0.12
                cv.R(ex - 44 + k * 8, GY - 13 - k * 16, 88 - k * 8, 13, Col(0x151820).alpha(fade))
                cv.R(ex - 44 + k * 8, GY - 16 - k * 16, 88 - k * 8, 3, Col(0x3a4150).alpha(fade))
            }
            cv.seg(ex - 40, GY - 62, ex + 42, GY - 160, 3.5, Col(0x4a5262)); cv.seg(ex - 40, GY - 62, ex - 40, GY - 16, 3, Col(0x4a5262))
            cv.vfill(ex - 44, GY - 190, 88, 80, [(0, rgba(125, 255, 176, 0.24)), (1, rgba(125, 255, 176, 0))])
            cv.RRStroke(ex - 44, GY - 190, 88, 190, 2, 4, Col.mix(z.trim, BLACK, 0.2))
        }
        if f.kind == .hole {
            if f.fireStairs { flameWall(cv, ex, 190, 260, 1.3, t); flameWall(cv, ex + 10, 110, 190, 3.7, t) } else {
                cv.poly(Col(0x4a443c), [ex - 90, GY, ex - 50, GY - 80, ex - 10, GY - 50, ex + 30, GY - 120, ex + 86, GY])
                cv.poly(Col(0x3a352f), [ex - 60, GY, ex - 20, GY - 40, ex + 40, GY - 70, ex + 70, GY])
            }
            sign(cv, f.fireStairs ? "ON FIRE" : "COLLAPSED", ex, GY - 214, HOT, t, arrow: false)
            let hx = f.holeX
            cv.ell(hx, GY + 8, 62, 13, Col(0x020203))
            cv.poly(Col(0x020203), [hx - 62, GY + 8, hx - 50, GY - 2, hx - 30, GY + 3, hx - 8, GY - 4, hx + 18, GY + 2, hx + 44, GY - 3, hx + 62, GY + 8])
            cv.poly(Col.mix(z.floor, BLACK, 0.4), [hx - 80, GY, hx - 62, GY - 9, hx - 56, GY])
            cv.poly(Col.mix(z.floor, BLACK, 0.4), [hx + 80, GY, hx + 64, GY - 12, hx + 54, GY])
            sign(cv, "DROP DOWN", hx, GY - 120, MINT, t)
        } else if f.kind == .lift {
            for i in 0..<4 { cv.seg(ex - 46, GY - 40 - Double(i) * 40, ex + 46, GY - 70 - Double(i) * 36, 10, Col(0x6a5238)) }
            sign(cv, "BLOCKED", ex, GY - 214, HOT, t, arrow: false)
            let lx = f.liftX
            let clear = g.threatCount == 0
            cv.R(lx - 62, GY - 196, 124, 196, Col(0x2a2e36))
            if f.shaft {
                // no car: the doors are pried apart on an empty shaft with the cable hanging in it
                cv.R(lx - 54, GY - 188, 108, 188, Col(0x030304))
                cv.R(lx - 3, GY - 188, 6, 188, Col(0x3a3a3e)); cv.R(lx - 1, GY - 188, 2, 188, Col(0x6a6a70))
                for i in 0..<4 { cv.R(lx - 54, GY - 160 + Double(i) * 44, 108, 3, Col(0x15161a)) }
                cv.R(lx - 70, GY - 188, 20, 188, Col(0x8a929c)); cv.R(lx + 50, GY - 188, 20, 188, Col(0x7c848e))
                cv.seg(lx - 40, GY - 120, lx + 40, GY - 118, 4, Col(0xd8a020))
            } else {
            cv.R(lx - 54, GY - 188, 52, 188, Col(0x8a929c))
            cv.R(lx + 2, GY - 188, 52, 188, Col(0x7c848e))
            cv.R(lx - 1, GY - 188, 2, 188, Col(0x1a1c20))
            }
            cv.RR(lx - 22, GY - 224, 44, 20, 3, Col(0x0a0a0c))
            cv.text("\(f.n)", lx, GY - 209, 13, clear ? MINT : HOT, 1, 3)
            sign(cv, clear ? (f.shaft ? "SLIDE DOWN" : "ELEVATOR") : "CLEAR THE FLOOR", lx, GY - 250, clear ? MINT : HOT, t, arrow: clear)
        } else if f.kind == .rope {
            sign(cv, "ROPE DOWN", ex, GY - 250, MINT, t)
        } else if f.escape {
            sign(cv, "LADDER DOWN", ex, GY - 214, MINT, t)
        } else {
            sign(cv, "STAIRS", ex, GY - 214, MINT, t)
        }
        if f.kind == .wall {
            let wx = f.wallX
            cv.poly(Col(0x17120f), [wx - 120, GY, wx - 70, GY - 46, wx - 10, GY - 28, wx + 50, GY - 60, wx + 118, GY])
            cv.seg(wx - 96, GY - 300, wx + 60, GY - 20, 14, Col(0x241a14))
            cv.seg(wx + 100, GY - 300, wx - 20, GY - 40, 14, Col(0x241a14))
            flameWall(cv, wx, 220, 300, 0, t)
            flameWall(cv, wx + 14, 110, 220, 2.1, t)
            let pl = 0.6 + 0.4 * sin(t * 5)
            for (dx, sd) in [(f.doorA, 1.0), (f.doorB, -1.0)] {
                cv.R(dx - 34, GY - 156, 68, 156, Col(0x060807))
                cv.vfill(dx - 32, GY - 154, 64, 154, [(0, rgba(125, 255, 176, 0.05)), (1, rgba(125, 255, 176, 0.25))])
                cv.RRStroke(dx - 34, GY - 156, 68, 156, 2, 4, MINT.alpha(0.55 + 0.45 * pl))
                sign(cv, sd > 0 ? "\(g.sideName) ▶" : "◀ \(g.sideName)", dx, GY - 176, MINT, t, arrow: false)
                for i in 0..<3 {
                    let ax = dx + sd * (-90 + Double(i) * 18 + (t * 30).truncatingRemainder(dividingBy: 18))
                    cv.poly(MINT.alpha(pl), [ax, GY - 14, ax + sd * 9, GY - 8, ax, GY - 2])
                }
            }
        }
        if f.kind == .safe {
            let cx = FLOOR_W / 2
            cv.lighter(true); cv.glow(cx, GY - 140, 520, rgba(90, 255, 160, 0.16 + 0.03 * sin(t * 2))); cv.lighter(false)
            cv.RR(cx - 130, GY - 268, 260, 44, 8, Col(0x0d1a13)); cv.RRStroke(cx - 130, GY - 268, 260, 44, 8, 3, MINT)
            cv.text("SAFE ROOM", cx, GY - 238, 26, MINT, 1, 3)
            cv.text("CHECKPOINT · HEALED", cx, GY - 206, 12, MINT.alpha(0.8), 1, 3)
            // a cot, crates, a lantern, a barricaded door
            cv.R(cx - 250, GY - 34, 150, 10, Col(0x4a5a4a)); cv.R(cx - 250, GY - 24, 8, 24, Col(0x2a2a2a)); cv.R(cx - 108, GY - 24, 8, 24, Col(0x2a2a2a)); cv.RR(cx - 250, GY - 46, 40, 14, 6, Col(0xd9dcd6))
            for i in 0..<3 { let bx = cx + 110 + Double(i % 2) * 64, by = GY - 56 - Double(i / 2) * 56; cv.R(bx, by, 60, 56, Col(0x6a5238)); cv.RRStroke(bx, by, 60, 56, 2, 3, Col(0x3a2c1c)); cv.R(bx + 22, by + 20, 16, 16, HOT); cv.R(bx + 28, by + 23, 4, 10, WHITE); cv.R(bx + 25, by + 26, 10, 4, WHITE) }
            cv.R(cx - 30, GY - 40, 6, 40, Col(0x2a2a2a)); cv.RR(cx - 39, GY - 66, 24, 28, 6, Col(0xffe6a0)); cv.lighter(true); cv.glow(cx - 27, GY - 52, 120, rgba(255, 220, 140, 0.3)); cv.lighter(false)
        }
        for it in f.items where !it.used { item(cv, it, t) }
        if f.gunT >= 0 && f.gunship {
            // searchlight, and the gunship itself where there is sky to see it against
            let lx = f.gunX >= 0 ? f.gunX : FLOOR_W / 2 + sin(t * 1.3) * 500
            cv.lighter(true)
            cv.poly(rgba(220, 235, 255, f.gunX >= 0 ? 0.16 : 0.07), [lx + 300, GY - 330, lx + 360, GY - 330, lx + 90, GY, lx - 90, GY])
            cv.ell(lx, GY + 4, 100, 12, rgba(220, 235, 255, 0.16))
            cv.lighter(false)
            if f.kind == .street {
                let hx2 = lx + 320, hy2 = 70 + sin(t * 2) * 8
                cv.ell(hx2, hy2, 70, 20, Col(0x0b0c10)); cv.R(hx2 - 150, hy2 - 5, 90, 9, Col(0x0b0c10)); cv.poly(Col(0x0b0c10), [hx2 - 150, hy2 - 24, hx2 - 136, hy2 - 24, hx2 - 128, hy2, hx2 - 150, hy2])
                cv.R(hx2 - 110 * abs(sin(t * 40)) , hy2 - 26, 220 * abs(sin(t * 40)), 4, Col(0x2a2f3b)); cv.R(hx2 - 3, hy2 - 26, 6, 10, Col(0x0b0c10))
                cv.poly(rgba(140, 200, 230, 0.5), [hx2 + 30, hy2 - 12, hx2 + 62, hy2 - 2, hx2 + 30, hy2 + 4])
                cv.circ(hx2 + 40, hy2 + 16, 4, HOT.alpha(0.6 + 0.4 * sin(t * 12)))
            }
        }
    }
    private func prop(_ cv: Canvas, _ p: Prop, _ z: Zone) {
        let x = p.x
        switch p.kind {
        case 0:   // desk
            cv.R(x - 44, GY - 50, 88, 8, Col(0x6a5238)); cv.R(x - 40, GY - 42, 6, 42, Col(0x4a3a28)); cv.R(x + 34, GY - 42, 6, 42, Col(0x4a3a28))
            cv.R(x - 16, GY - 78, 34, 24, Col(0x15171c)); cv.R(x - 13, GY - 75, 28, 18, Col(0x2c5a7a))
        case 1:   // plant
            cv.poly(Col(0x7a5236), [x - 14, GY - 30, x + 14, GY - 30, x + 10, GY, x - 10, GY])
            for i in 0..<5 { let a = -1.2 + Double(i) * 0.6; cv.seg(x, GY - 30, x + sin(a) * 34, GY - 30 - cos(a) * 44, 7, Col(0x2f6a3a)) }
        case 2:   // water cooler
            cv.R(x - 14, GY - 70, 28, 70, Col(0xd9dcd6)); cv.RR(x - 12, GY - 108, 24, 40, 8, rgba(120, 190, 230, 0.75))
        case 3:   // cabinet
            cv.R(x - 30, GY - 96, 60, 96, Col.mix(z.trim, BLACK, 0.35)); cv.R(x - 26, GY - 90, 52, 26, Col.mix(z.trim, BLACK, 0.5)); cv.R(x - 26, GY - 58, 52, 26, Col.mix(z.trim, BLACK, 0.5)); cv.R(x - 26, GY - 28, 52, 24, Col.mix(z.trim, BLACK, 0.5))
        default:  // lamp
            cv.R(x - 2, GY - 120, 4, 120, Col(0x2a2a2a)); cv.poly(Col(0xd9c48a), [x - 22, GY - 120, x + 22, GY - 120, x + 14, GY - 150, x - 14, GY - 150])
            cv.lighter(true); cv.glow(x, GY - 110, 90, rgba(255, 230, 160, 0.14)); cv.lighter(false)
        }
    }
    private func item(_ cv: Canvas, _ it: Item, _ t: Double) {
        let x = it.x
        switch it.kind {
        case 0:
            cv.RR(x - 15, GY - 22, 30, 22, 4, Col(0xf2f2ee)); cv.R(x - 3, GY - 18, 6, 14, HOT); cv.R(x - 8, GY - 14, 16, 6, HOT)
        case 1:
            cv.RR(x - 17, GY - 50, 34, 50, 5, Col(0xb8322c)); cv.R(x - 17, GY - 38, 34, 5, Col(0x7a1c18)); cv.R(x - 17, GY - 18, 34, 5, Col(0x7a1c18))
            cv.poly(GOLD, [x, GY - 34, x - 7, GY - 22, x + 7, GY - 22]); cv.text("!", x, GY - 23, 9, BLACK, 1, 3)
        case 2:
            let b = sin(t * 4) * 6
            cv.lighter(true); cv.glow(x, GY - 50 + b, 70, rgba(125, 255, 176, 0.5)); cv.lighter(false)
            cv.RR(x - 7, GY - 70 + b, 14, 40, 6, rgba(200, 255, 220, 0.9)); cv.RR(x - 5, GY - 54 + b, 10, 22, 4, Col(0x2fd67a)); cv.R(x - 8, GY - 74 + b, 16, 6, Col(0x444a52))
            cv.text("SAMPLE", x, GY - 92 + b, 13, MINT, 1, 3)
        default:
            cv.R(x - 60, GY - 96, 120, 14, Col(0x5a6068)); cv.R(x - 8, GY - 96, 16, 96, Col(0x4a5058))
            cv.lighter(true); cv.glow(x, GY - 90, 90, rgba(255, 90, 70, 0.35 + 0.15 * sin(t * 6))); cv.lighter(false)
            cv.ring(x, GY - 90, 24, 7, HOT)
            for i in 0..<4 { let a = t * 1.5 + Double(i) * PI / 2; cv.seg(x, GY - 90, x + cos(a) * 24, GY - 90 + sin(a) * 24, 5, HOT) }
            cv.text("WATER MAIN", x, GY - 130, 13, HOT, 1, 3)
        }
    }

    private func scene(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let h = g.hero
        let f = g.floor
        let t = g.t
        let target = clampD(h.x - W / 2 + h.face * 70, -40, FLOOR_W - W + 40)
        rdt = lastT < 0 ? 1.0 / 60 : clampD(g.t - lastT, 0, 0.05)
        lastT = g.t
        frameN += 1
        if frameN % 120 == 0 { zedP = zedP.filter { frameN - $0.value.1 < 30 } }
        if camFloor != f.n || abs(target - camX) > 700 { camX = target; camFloor = f.n; zedP = [:] } else { camX += (target - camX) * ease(9) }
        cv.save()
        if g.shake > 0 { cv.translate(rnd(-1, 1) * g.shake, rnd(-1, 1) * g.shake * 0.6) }
        if g.zoom > 1.001 { cv.translate(W / 2, GY - 60); cv.scale(g.zoom, g.zoom); cv.translate(-W / 2, -(GY - 60)) }
        cv.translate(-camX, 0)
        drawFloor(g, cv, camX - 30, W + 60)
        let gy = GY + 6
        // the dead first, then the living
        for z in f.zeds where !z.alive { drawZed(cv, z, gy, t) }
        for z in f.zeds where z.alive { drawZed(cv, z, gy, t) }
        // the hero
        if g.mode != .dead {
            let blink = h.inv > 0 && g.supT < 0 && Int(t * 20) % 2 == 0
            cv.ell(h.x, gy + 2, 30, 6, BLACK.alpha(0.35))
            if g.supT >= 0 { cv.lighter(true); cv.glow(h.x, gy - 90, 150, g.tw.hue.alpha(0.5)); cv.lighter(false) }
            let hf: Double = h.hurtT > 0 ? 0.6 : 0
            let ha: Double = blink ? 0.45 : 1
            var hface = h.face
            if h.atkT >= 0 && h.atkStyle == 6 { hface = sin(h.atkT / 0.4 * PI * 4) >= 0 ? h.face : -h.face }
            var hl = heroLook(g.tw); hl.tier = g.lv("dmg"); hl.gun = g.heldGun; hl.slung = hl.gun > 0 ? -1 : g.slungGun
            figure(cv, h.x, gy - h.jump, hface, 1, hl, smoothHero(g), flash: hf, alpha: ha)
        } else {
            figure(cv, h.x, gy, h.face, 1, heroLook(g.tw), Pose(), fall: min(1, g.deadT * 3))
        }
        if g.lv("drone") > 0 {
            let dx = h.x + cos(g.droneA) * 70, dy = gy - 190 + sin(g.droneA * 2) * 8
            cv.RR(dx - 14, dy - 5, 28, 10, 4, Col(0x3a4250)); cv.R(dx - 22, dy - 8, 44, 2.5, Col(0xc9d2dc, 0.7)); cv.circ(dx, dy + 5, 3, Col(0x7dd3ff))
        }
        effects(g, cv, gy)
        // things hanging in front of the camera, sliding by faster than the hallway
        if f.kind != .roof && f.kind != .street {
            var k = Int((camX * 1.35 - 200) / 520)
            while true {
                let fx = Double(k) * 520 + 260
                let sx = camX + (fx - camX * 1.35)
                if sx > camX + W + 120 { break }
                let h1 = hashN(Double(k) * 3.7 + Double(f.n))
                if h1 > 0.55 {
                    cv.curve(sx - 90, -10, sx - 20, 70 + h1 * 60, sx + 80, -10, 5, Col(0x050608)); cv.curve(sx - 40, -10, sx + 20, 40 + h1 * 40, sx + 120, -10, 3, Col(0x050608))
                } else if h1 > 0.25 {
                    cv.R(sx - 60, 0, 120, 16 + h1 * 30, Col(0x050608)); cv.seg(sx, 16, sx + sin(t * 2 + fx) * 6, 60 + h1 * 60, 3, Col(0x050608))
                    if h1 > 0.4 && Int(t * 9 + fx).isMultiple(of: 5) { cv.lighter(true); cv.glow(sx + sin(t * 2 + fx) * 6, 64 + h1 * 60, 30, rgba(160, 210, 255, 0.8)); cv.lighter(false) }
                }
                k += 1
            }
        }
        cv.restore()
        // screen space: dust in the light, embers, a dark edge
        cv.lighter(true)
        let fiery = f.kind == .wall || f.kind == .roof || f.kind == .street || !g.fires.isEmpty
        for i in 0..<26 {
            let fi = Double(i)
            let px = (hashN(fi) * W + t * (6 + hashN(fi + 3) * 14) - camX * 0.2).truncatingRemainder(dividingBy: W)
            let py = (hashN(fi + 7) * VIEW_H + sin(t * 0.6 + fi) * 20)
            if fiery && i % 2 == 0 {
                let u = (t * (0.12 + hashN(fi + 1) * 0.2) + hashN(fi + 5)).truncatingRemainder(dividingBy: 1)
                cv.circ(px < 0 ? px + W : px, VIEW_H - u * VIEW_H, 2, rgba(255, 170 - u * 90, 60, 0.9 * (1 - u)))
            } else {
                cv.circ(px < 0 ? px + W : px, py, 1.4 + hashN(fi + 2) * 1.6, rgba(255, 240, 210, 0.10))
            }
        }
        cv.lighter(false)
        cv.vfill(0, 0, W, 80, [(0, BLACK.alpha(0.45)), (1, BLACK.alpha(0))])
        cv.vfill(0, VIEW_H - 70, W, 70, [(0, BLACK.alpha(0)), (1, BLACK.alpha(0.5))])
        cv.glow(0, VIEW_H / 2, 260, BLACK.alpha(0.3)); cv.glow(W, VIEW_H / 2, 260, BLACK.alpha(0.3))
    }
    private func crow(_ cv: Canvas, _ z: Zed, _ gy: Double, _ t: Double) {
        let y = gy + z.y
        let flap = sin(t * 16 + z.seed * 10)
        cv.ell(z.x, gy + 2, 16, 3, BLACK.alpha(0.2))
        cv.save()
        cv.translate(z.x, y)
        cv.scale(z.face, 1)
        if z.atkT >= 0 { cv.rotate(0.5) }
        let body = z.flash > 0.3 ? Col(0xe8e0d8) : Col(0x14141a)
        cv.poly(Col(0x0b0b10), [-6, -2, -30, -6 - flap * 22, -14, 4])
        cv.ell(0, 0, 17, 8, body)
        cv.poly(body, [-14, -2, -30, 2, -28, 7, -12, 5])
        cv.circ(14, -5, 7, body)
        cv.poly(Col(0xc9a24a), [19, -6, 31, -3, 19, -1])
        cv.poly(Col(0x1c1c24), [2, -3, -16, -4 - flap * 26, 8, 3])
        cv.circ(16, -6, 2, Col(0xff3a2a))
        cv.circ(-2, 3, 3.5, Col(0x7a1014))
        cv.restore()
        if z.hp < z.maxHp { cv.R(z.x - 14, y - 24, 28, 4, BLACK.alpha(0.6)); cv.R(z.x - 14, y - 24, 28 * clampD(z.hp / z.maxHp, 0, 1), 4, HOT) }
    }
    /// A zombie dragging itself along the floor on its arms.
    private func crawler(_ cv: Canvas, _ z: Zed, _ gy: Double, _ t: Double) {
        let L = zedLook(z)
        let dead = !z.alive
        let ph = z.walk * 0.075
        let pull: Double = dead ? 0 : cos(ph)
        let ink = Col(0x0b0c10)
        let fl = clampD(z.flash, 0, 1) * 0.85
        let shirt = Col.mix(L.shirt, WHITE, fl), skin = Col.mix(L.skin, WHITE, fl)
        let skinD = Col.mix(skin, BLACK, 0.25), shirtD = Col.mix(shirt, BLACK, 0.3)
        cv.save()
        cv.translate(z.x, gy)
        cv.scale(z.face * z.scale, z.scale)
        if dead { cv.alpha(max(0.15, 1 - z.deadT / 6)) }
        // what it leaves behind
        cv.seg(-150, 1, -40, 1, 9, Col(0x5a0c10, 0.55)); cv.seg(-200, 1, -150, 1, 6, Col(0x5a0c10, 0.3))
        let lurch = pull * 5
        cv.translate(lurch, 0)
        let lift: Double = dead ? 0 : 8 + 4 * sin(ph * 2)
        // trailing legs: one whole and limp, one gone at the knee
        cv.line(ink, 15.5, [-34, -9, -64, -6 + sin(ph) * 1.5, -92, -5])
        cv.line(Col(0x33363c), 12, [-34, -9, -64, -6 + sin(ph) * 1.5, -92, -5])
        cv.seg(-92, -5, -103, -8, 10, ink); cv.seg(-92, -5, -102, -8, 7, Col(0x15151a))
        cv.seg(-32, -7, -58, -4, 15.5, ink); cv.seg(-32, -7, -58, -4, 12, Col(0x33363c))
        cv.circ(-60, -4, 6, Col(0x7a1014)); cv.seg(-60, -4, -68, -3, 3, Col(0xd8d0bc))
        cv.curve(-40, -4, -70, 4 + sin(ph * 2) * 2, -96, -1, 4, Col(0xb0606a)); cv.curve(-50, -3, -80, -8, -112, 0, 3, Col(0x8a3a44))
        // far arm
        let reachB = 34 - 26 * pull
        let shx = 12.0, shy = -22 - lift
        cv.line(ink, 12, [shx, shy, shx + reachB * 0.5, shy - 14, shx + reachB, -3])
        cv.line(shirtD, 8.5, [shx, shy, shx + reachB * 0.5, shy - 14]); cv.line(skinD, 7.5, [shx + reachB * 0.5, shy - 14, shx + reachB, -3])
        // body: hips on the floor, chest pushed up on the arms
        let body: [Double] = [-38, -18, -10, -24 - lift * 0.6, 16, -32 - lift, 24, -20 - lift, 12, -8 - lift * 0.5, -36, -1]
        cv.line(ink, 4, body + [-38, -18]); cv.poly(shirt, body)
        cv.poly(shirtD, [-36, -1, 12, -8 - lift * 0.5, 4, -4, -34, 0])
        cv.circ(-8, -14 - lift * 0.4, 6, BLOOD.alpha(0.8)); cv.circ(-26, -10, 4.5, BLOOD.alpha(0.75))
        for i in 0..<3 { let rx = -2.0 + Double(i) * 6; cv.seg(rx, -22 - lift * 0.7, rx - 2, -12 - lift * 0.5, 2.2, Col(0xd8d0bc)) }
        // head up, looking at you
        let hx = 36.0, hy = -36 - lift + (dead ? 22 : sin(ph * 2) * 2)
        cv.seg(20, -26 - lift, hx, hy, 12, ink); cv.seg(20, -26 - lift, hx, hy, 9, skinD)
        if !z.headless {
            let open: Double = z.atkT >= 0 ? 1.1 : 0.4 + 0.3 * sin(t * 5 + z.seed * 20)
            cv.save(); cv.translate(hx, hy); cv.rotate(-0.3)
            zedHead(cv, L, skin, ink, Col(0xd8d0bc), open, ph)
            cv.restore()
        } else { cv.circ(hx - 6, hy + 4, 6, Col(0x7a1014)) }
        // near arm: reach, plant, drag
        let reachA = 34 + 26 * pull
        let up: Double = dead ? 0 : max(0, -sin(ph)) * 16
        cv.line(ink, 13, [shx + 4, shy + 4, shx + 4 + reachA * 0.5, shy - 10 - up * 0.5, shx + 4 + reachA, -3 - up])
        cv.line(shirt, 9.5, [shx + 4, shy + 4, shx + 4 + reachA * 0.5, shy - 10 - up * 0.5]); cv.line(skin, 8.5, [shx + 4 + reachA * 0.5, shy - 10 - up * 0.5, shx + 4 + reachA, -3 - up])
        let hxA = shx + 4 + reachA, hyA = -3 - up
        cv.circ(hxA, hyA, 5.5, skin)
        for d in [-4.0, 0.0, 4.0] { cv.seg(hxA + 2, hyA + d * 0.3, hxA + 11, hyA + d * 0.8 + 2, 2.2, Col(0x2a2a22)) }
        cv.restore()
    }
    private func drawZed(_ cv: Canvas, _ z: Zed, _ gy: Double, _ t: Double) {
        if z.gibbed { return }
        if z.flyT >= 0 {
            var p = Pose()
            p.armF = 2.6; p.armB = -2.2; p.hipF = 0.9; p.hipB = -0.7; p.kneeF = 0.8; p.kneeB = 0.5; p.jaw = 1.2; p.head = -0.5
            cv.lighter(true)
            for i in 1..<4 { cv.circ(z.x - z.flyVx * 0.02 * Double(i), gy + z.y - 70 - z.flyVy * 0.02 * Double(i), 26 - Double(i) * 5, WHITE.alpha(0.10)) }
            cv.lighter(false)
            cv.save(); cv.translate(z.x, gy + z.y - 70); cv.rotate(z.flyRot)
            figure(cv, 0, 70, 1, z.scale, zedLook(z), p, flash: 0.3)
            cv.restore()
            return
        }
        if z.kind == .crawler {
            crawler(cv, z, gy, t)
            if z.alive && z.hp < z.maxHp { cv.R(z.x - 18, gy - 78, 36, 5, BLACK.alpha(0.6)); cv.R(z.x - 18, gy - 78, 36 * clampD(z.hp / z.maxHp, 0, 1), 5, HOT) }
            return
        }
        if z.kind == .crow { if z.alive { crow(cv, z, gy, t) }; return }
        if z.kind == .dog || z.kind == .rat {
            if z.alive { cv.ell(z.x, gy + 2, z.kind == .rat ? 14 : 40, z.kind == .rat ? 3 : 6, BLACK.alpha(0.35)) }
            beast(cv, z, gy, t)
        } else {
            let a = z.alive ? 1.0 : max(0.15, 1 - z.deadT / 6)
            if z.alive { cv.ell(z.x, gy + 2, (z.kind == .wheel ? 48 : 30) * z.scale, 6, BLACK.alpha(0.35)) }
            if z.kind == .wheel && z.alive {
                // the chair, behind the rider
                cv.save(); cv.translate(z.x, gy); cv.scale(z.face, 1)
                let ink = Col(0x0b0c10), steel = Col(0x8a929c)
                cv.ring(-10, -30, 30, 7, ink)
                cv.line(ink, 8, [-22, -96, -18, -44, 24, -44, 40, -12, 52, -9]); cv.line(steel, 4.5, [-22, -96, -18, -44, 24, -44, 40, -12, 52, -9])
                cv.seg(-22, -94, -34, -96, 7, ink); cv.seg(-22, -94, -33, -96, 4, Col(0x2a2a2a))
                cv.R(-20, -48, 44, 8, Col(0x3a5a8a)); cv.R(-24, -92, 7, 46, Col(0x3a5a8a))
                cv.circ(46, -7, 8.5, ink); cv.circ(46, -7, 5.5, Col(0x3a3a3a))
                cv.restore()
            }
            if z.kind == .burner && z.alive { flameWall(cv, z.x, 50, 150 * z.scale, z.seed * 9, t); cv.lighter(true); cv.glow(z.x, gy - 90, 130, rgba(255, 140, 40, 0.4)); cv.lighter(false) }
            if z.kind == .boss && z.alive { cv.lighter(true); cv.glow(z.x, gy - 140, 190, rgba(90, 255, 150, 0.22)); cv.lighter(false) }
            if z.kind == .spitter && z.alive { cv.lighter(true); cv.glow(z.x + z.face * 8, gy - 118, 46, rgba(140, 255, 120, 0.3 + 0.2 * sin(t * 6))); cv.lighter(false) }
            let fall: Double = z.alive ? 0 : (z.kind == .crawler ? 0 : min(1, z.deadT * 3.2))
            figure(cv, z.x, gy, z.face, z.scale, zedLook(z), smoothZed(z, t), flash: z.flash, fall: fall, alpha: a)
            if z.burn > 0 && z.alive { cv.lighter(true); cv.glow(z.x, gy - 80 * z.scale, 70 * z.scale, rgba(255, 140, 40, 0.5)); cv.lighter(false) }
            if z.kind == .wheel && z.alive {
                // the near wheel, over the rider's hip, turning as it rolls
                cv.save(); cv.translate(z.x - z.face * 10, gy - 30); cv.rotate(z.walk / 30 * z.face)
                cv.ring(0, 0, 30, 6.5, Col(0x0b0c10)); cv.ring(0, 0, 30, 3.5, Col(0x2a2a2a)); cv.ring(0, 0, 25, 2, Col(0xc9d2dc))
                for i in 0..<6 { let a2 = Double(i) * PI / 3; cv.seg(0, 0, cos(a2) * 25, sin(a2) * 25, 1.6, Col(0xc9d2dc)) }
                cv.circ(0, 0, 5, Col(0x8a929c))
                cv.restore()
            }
            if z.kind == .riot && z.alive && z.shield > 0 {
                cv.save(); cv.translate(z.x, gy); cv.scale(z.face * z.scale, z.scale)
                if z.atkT >= 0 { cv.rotate(0.25) }
                cv.RR(22, -152, 30, 124, 9, rgba(150, 195, 225, 0.42)); cv.RRStroke(22, -152, 30, 124, 9, 3, Col(0x0b0c10)); cv.RRStroke(24, -150, 26, 120, 8, 1.5, rgba(220, 240, 255, 0.7))
                cv.R(24, -108, 26, 16, Col(0x161a24, 0.85)); cv.R(27, -103, 20, 2, WHITE.alpha(0.85)); cv.R(27, -98, 14, 2, WHITE.alpha(0.85))
                for i in 0..<(5 - z.shield) { cv.seg(28 + Double(i) * 4, -140 + Double(i) * 17, 44 - Double(i) * 2, -122 + Double(i) * 15, 1.4, rgba(240, 250, 255, 0.85)) }
                cv.restore()
            }
        }
        if z.alive && z.hp < z.maxHp && z.kind != .rat {
            var top = gy - 178 * z.scale
            if z.kind == .dog { top = gy - 96 } else if z.kind == .crawler { top = gy - 70 }
            let w = z.kind == .boss ? 120.0 : 36.0
            cv.R(z.x - w / 2, top, w, 5, BLACK.alpha(0.6))
            cv.R(z.x - w / 2, top, w * clampD(z.hp / z.maxHp, 0, 1), 5, z.kind == .boss ? MINT : HOT)
        }
    }
    private func effects(_ g: Game, _ cv: Canvas, _ gy: Double) {
        for s in g.slashes {
            let u = s.t / 0.18
            cv.save()
            cv.translate(s.x, gy + s.y)
            cv.scale(s.face, s.mode == 1 ? -1 : 1)
            cv.lighter(true)
            if s.mode == 2 {
                cv.seg(20, 0, 60 + 130 * u, 0, 14 * (1 - u) + 2, s.col.alpha(0.85 * (1 - u)))
                cv.seg(30, 0, 70 + 130 * u, 0, 4, WHITE.alpha(1 - u))
            } else if s.mode == 3 {
                cv.arcStroke(10, 70, 100 * s.big, -0.5, 0.5, 14 * (1 - u) + 2, s.col.alpha(0.85 * (1 - u)))
                cv.arcStroke(10, 70, 100 * s.big, -0.35, 0.35, 4, WHITE.alpha(1 - u))
            } else if s.mode == 4 {
                cv.ellStroke(0, 10, 150 * (0.5 + 0.5 * u), 40 * (0.5 + 0.5 * u), 14 * (1 - u) + 2, s.col.alpha(0.9 * (1 - u)))
                cv.ellStroke(0, 10, 140 * (0.5 + 0.5 * u), 34 * (0.5 + 0.5 * u), 4, WHITE.alpha(1 - u))
            } else {
                cv.arcStroke(10, 0, 96 * s.big, -1.25, 0.85, 16 * (1 - u) + 2, s.col.alpha(0.85 * (1 - u)))
                cv.arcStroke(10, 0, 96 * s.big, -1.0, 0.6, 5 * (1 - u) + 1, WHITE.alpha(1 - u))
            }
            cv.lighter(false)
            cv.restore()
        }
        for gb in g.gibs {
            let a = min(1, (6 - gb.t) / 1.5)
            cv.save()
            cv.translate(gb.x, gy + gb.y - 5)
            cv.rotate(gb.rot)
            cv.alpha(a)
            switch gb.kind {
            case 0:
                cv.circ(0, 0, 16, Col(0x0b0c10)); cv.circ(0, 0, 14, gb.col)
                cv.circ(5, -2, 4.5, Col(0x14100e)); cv.circ(5.5, -2, 2, Col(0xffe14a))
                cv.poly(Col(0x7a1014), [-9, 9, 9, 9, 4, 17, -5, 16]); cv.circ(-4, 5, 3, BLOOD)
            case 1:
                cv.seg(-13, 0, 13, 0, 12, Col(0x0b0c10)); cv.seg(-13, 0, 13, 0, 8.5, gb.col); cv.circ(-13, 0, 4.5, Col(0x7a1014)); cv.circ(13, 0, 5, gb.col)
            case 2:
                cv.poly(Col(0x7a1014), [-10, -6, 8, -9, 12, 4, -2, 10, -12, 3]); cv.seg(-4, -2, 6, 2, 2.4, Col(0xd8d0bc))
            case 3:
                cv.seg(-16, 0, 16, 0, 14, Col(0x0b0c10)); cv.seg(-16, 0, 16, 0, 10.5, Col(0x33363c)); cv.seg(14, 0, 24, 3, 8, Col(0x15151a)); cv.circ(-16, 0, 5, Col(0x7a1014))
            case 4:
                cv.poly(gb.col, [-12, -4, 12, -6, 10, 5, -11, 4])
            case 6:
                cv.R(-4, -1.5, 8, 3, gb.col); cv.R(2, -1.5, 2, 3, Col(0x8a6a20))
            case 7:
                cv.RR(-15, -60, 30, 120, 9, rgba(150, 195, 225, 0.42)); cv.RRStroke(-15, -60, 30, 120, 9, 3, Col(0x0b0c10)); cv.seg(-8, -40, 8, 10, 1.5, WHITE.alpha(0.8)); cv.seg(6, -30, -6, 30, 1.5, WHITE.alpha(0.8))
            case 8:
                cv.line(Col(0x0b0c10), 8, [-22, -50, -18, 0, 24, 0, 40, 30]); cv.line(gb.col, 4.5, [-22, -50, -18, 0, 24, 0, 40, 30]); cv.R(-20, -4, 44, 8, Col(0x3a5a8a))
            case 9:
                cv.ring(0, 0, 28, 6.5, Col(0x0b0c10)); cv.ring(0, 0, 28, 3.5, gb.col); for i in 0..<6 { let a2 = Double(i) * PI / 3; cv.seg(0, 0, cos(a2) * 25, sin(a2) * 25, 1.6, Col(0xc9d2dc)) }
            case 10:
                // a rope of gut
                let pts: [Double] = [-24, 2, -15, -6, -6, 5, 3, -5, 12, 5, 20, -3, 26, 3]
                cv.line(Col(0x0b0c10), 9.5, pts); cv.line(gb.col, 6.5, pts); cv.line(Col.mix(gb.col, WHITE, 0.35), 1.6, [-15, -8, -6, 3, 3, -7, 12, 3])
                cv.circ(-24, 2, 4, Col(0x7a1014)); cv.circ(26, 3, 3.5, BLOOD)
            default:
                cv.poly(gb.col, [-9, 0, 2, -4, 10, 0, 1, 3])
            }
            cv.restore()
        }
        for gl in g.globs {
            cv.lighter(true); cv.glow(gl.x, gy + gl.y, 30, rgba(140, 255, 120, 0.5)); cv.lighter(false)
            cv.circ(gl.x, gy + gl.y, 8, Col(0x8cff7a)); cv.circ(gl.x - gl.vx * 0.03, gy + gl.y - gl.vy * 0.03, 5, Col(0x8cff7a, 0.6)); cv.circ(gl.x + 2, gy + gl.y - 2, 3, Col(0xe8ffd0))
        }
        for w in g.waves {
            cv.poly(rgba(230, 220, 200, 0.75), [w.x - 30, gy, w.x - w.dir * 10, gy - 150, w.x + w.dir * 26, gy - 60, w.x + w.dir * 44, gy])
            cv.lighter(true); cv.glow(w.x, gy - 40, 110, g.tw.hue.alpha(0.5)); cv.lighter(false)
        }
        for p in g.parts {
            let a = 1 - p.t / p.life
            if p.glow {
                cv.lighter(true); cv.circ(p.x, gy + p.y, p.size * (0.5 + a * 0.7), p.col.alpha(a * 0.8)); cv.lighter(false)
            } else if p.size > 12 {
                cv.circ(p.x, gy + p.y, p.size * (1.6 - a * 0.6), p.col.alpha(p.col.a * min(1, a * 1.4)))
            } else {
                cv.R(p.x - p.size / 2, gy + p.y - p.size / 2, p.size, p.size, p.col.alpha(min(1, a * 1.6)))
            }
        }
        for tr in g.tracers {
            let a = 1 - tr.t / tr.life
            if tr.bolt {
                var pts: [Double] = [tr.x0, gy + tr.y0]
                for i in 1..<6 {
                    let u = Double(i) / 6
                    pts.append(lerp(tr.x0, tr.x1, u) + rnd(-14, 14)); pts.append(gy + lerp(tr.y0, tr.y1, u) + rnd(-14, 14))
                }
                pts.append(tr.x1); pts.append(gy + tr.y1)
                cv.lighter(true)
                cv.line(tr.col.alpha(a * 0.6), tr.w * 3, pts)
                cv.line(WHITE.alpha(a), tr.w, pts)
                cv.lighter(false)
            } else {
                cv.seg(tr.x0, gy + tr.y0, tr.x1, gy + tr.y1, tr.w, tr.col.alpha(a))
            }
        }
        for n in g.nades {
            let u = n.t / n.dur
            let x = lerp(n.x0, n.x1, u), y = gy - 90 - sin(u * PI) * 150 + u * 80
            cv.circ(x, y, 7, Col(0x2f3a2a)); cv.circ(x + 3, y - 6, 2.5, HOT)
        }
        for b in g.beams {
            if !b.done {
                let u = b.t / 0.55
                cv.ellStroke(b.x, gy + 4, b.r * (1.2 - 0.3 * u), 14, 3, rgba(160, 220, 255, 0.5 + 0.5 * u))
                cv.seg(b.x, gy - 500, b.x, gy, 2, rgba(160, 220, 255, 0.5))
            } else {
                let u = (b.t - 0.55) / 0.45
                cv.lighter(true)
                cv.R(b.x - 60 * (1 - u), gy - 560, 120 * (1 - u), 564, rgba(170, 225, 255, 0.8 * (1 - u)))
                cv.R(b.x - 22 * (1 - u), gy - 560, 44 * (1 - u), 564, WHITE.alpha(1 - u))
                cv.lighter(false)
            }
        }
        for fr in g.fires {
            if fr.1 > 0 { flameWall(cv, fr.0, fr.2 * 1.6, 70 * min(1, fr.1), fr.0 * 0.01, g.t) } else { cv.ell(fr.0, gy + 2, fr.2 * 1.2 * min(1, -fr.1), 7, Col(0x6cdc5a, 0.5)); cv.lighter(true); cv.glow(fr.0, gy, fr.2 * 1.2, rgba(120, 255, 100, 0.2 * min(1, -fr.1))); cv.lighter(false) }
        }
        for b in g.booms where b.t >= 0 {
            let u = b.t / b.life
            let r = b.r * (0.25 + 0.75 * easeOut(u))
            cv.lighter(true)
            cv.glow(b.x, gy + b.y, r * 1.3, rgba(255, 190, 70, 0.9 * (1 - u)))
            cv.circ(b.x, gy + b.y, r * 0.45 * (1 - u), rgba(255, 255, 230, 1 - u))
            cv.lighter(false)
            cv.circ(b.x, gy + b.y - r * 0.5 * u, r * (0.3 + 0.3 * u), rgba(30, 26, 26, 0.5 * u * (1 - u) * 4))
        }
        for r in g.rings {
            let u = r.t / r.life
            cv.ellStroke(r.x, gy + r.y + 70, r.r * easeOut(u), r.r * easeOut(u) * 0.28, 10 * (1 - u) + 1, r.col.alpha(1 - u))
        }
        cv.lighter(true)
        for pw in g.pows {
            let u = pw.2 / 0.14, sz = pw.3 * (0.6 + 0.6 * u), th = sz * 0.16
            cv.poly(WHITE.alpha(1 - u), [pw.0 - sz, gy + pw.1, pw.0, gy + pw.1 - th, pw.0 + sz, gy + pw.1, pw.0, gy + pw.1 + th])
            cv.poly(rgba(255, 230, 170, 1 - u), [pw.0 - th, gy + pw.1, pw.0, gy + pw.1 - sz, pw.0 + th, gy + pw.1, pw.0, gy + pw.1 + sz])
            cv.circ(pw.0, gy + pw.1, sz * 0.3, WHITE.alpha(1 - u))
        }
        if g.muzzle > 0 { cv.glow(g.hero.x + g.hero.face * 40, gy - 96, 70, rgba(255, 220, 140, 0.55 * g.muzzle)); cv.poly(rgba(255, 240, 190, g.muzzle), [g.hero.x + g.hero.face * 30, gy - 100, g.hero.x + g.hero.face * 64, gy - 96, g.hero.x + g.hero.face * 30, gy - 92]) }
        cv.lighter(false)
        for fl in g.floaters {
            cv.text(fl.text, fl.x, gy + fl.y, fl.size, fl.col.alpha(1 - fl.t / 0.8), 1, 3)
        }
    }

    // ---------- the play screen furniture
    private func bar(_ cv: Canvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ k: Double, _ c: Col) {
        cv.RR(x, y, w, h, h / 2, BLACK.alpha(0.6))
        if k > 0.01 { cv.RR(x + 2, y + 2, max(h - 4, (w - 4) * clampD(k, 0, 1)), h - 4, (h - 4) / 2, c) }
    }
    private func hud(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let t = g.t
        let f = g.floor
        let x = 16 + g.safeL
        cv.RR(x - 8, 8, 250, 124, 12, BLACK.alpha(0.5))
        let label = f.kind == .roof ? "ROOF" : (f.kind == .street ? "STREET" : "FLOOR \(f.n)")
        let place: String = f.kind == .roof || f.kind == .street ? g.tw.building : (f.escape ? "\(g.tw.building) · FIRE ESCAPE" : "\(g.tw.building) · \(g.zone(f.n).name)")
        cv.text("\(g.tw.who) · \(place)", x, 24, 10, WHITE.alpha(0.65), 0, 1)
        cv.text(label, x, 52, 27, g.tw.hue, 0, 3)
        let hpCol: Col = g.hero.hp < g.hero.maxHp * 0.3 ? HOT : Col(0x7fd67a)
        // three bars, each one says what it is
        bar(cv, x, 60, 234, 20, g.hero.hp / g.hero.maxHp, hpCol)
        cv.text("♥ HEALTH", x + 8 + 1, 75 + 1, 11, BLACK.alpha(0.7), 0, 3)
        cv.text("♥ HEALTH", x + 8, 75, 11, WHITE, 0, 3)
        cv.text("\(max(0, Int(g.hero.hp.rounded(.up)))) / \(Int(g.hero.maxHp))", x + 226 + 1, 75 + 1, 11, BLACK.alpha(0.7), 2, 3)
        cv.text("\(max(0, Int(g.hero.hp.rounded(.up)))) / \(Int(g.hero.maxHp))", x + 226, 75, 11, WHITE, 2, 3)
        let full = g.meter >= 100
        bar(cv, x, 84, 234, 18, g.meter / 100, full ? GOLD : Col(0xb89a50))
        cv.text(full ? "⚡ POWER MOVE READY — TAP ⚡" : "⚡ POWER MOVE", x + 8 + 1, 97 + 1, 10.5, BLACK.alpha(0.7), 0, 3)
        cv.text(full ? "⚡ POWER MOVE READY — TAP ⚡" : "⚡ POWER MOVE", x + 8, 97, 10.5, full && Int(t * 4) % 2 == 0 ? HOT : WHITE, 0, 3)
        bar(cv, x, 106, 234, 18, g.energy / g.energyNeed, Col(0x7db8ff))
        cv.text("★ NEXT UPGRADE", x + 8 + 1, 119 + 1, 10.5, BLACK.alpha(0.7), 0, 3)
        cv.text("★ NEXT UPGRADE", x + 8, 119, 10.5, WHITE, 0, 3)
        cv.text("kill to fill", x + 226 + 1, 119 + 1, 10, BLACK.alpha(0.7), 2, 1)
        cv.text("kill to fill", x + 226, 119, 10, WHITE.alpha(0.8), 2, 1)
        // what you carry
        var ix = x
        for u in UPS where g.lv(u.id) > 0 {
            cv.RR(ix - 2, 138, 30, 30, 8, BLACK.alpha(0.5))
            if let ic = pic("up_\(u.id).png") { fit(cv, ic, ix + 13, 153, 25) } else { cv.text(u.icon, ix + 13, 160, 17, WHITE, 1, 1) }
            for l in 0..<g.lv(u.id) { cv.R(ix + 2 + Double(l) * 9, 170, 7, 3, u.sup ? Col(0xff8ad8) : GOLD) }
            ix += 34
        }
        // one goal
        let s = g.goal
        let gw = cv.textW(s, 13, 2) + 44
        let gx = W - g.safeR - 12 - gw
        cv.RR(gx, 10, gw, 26, 13, BLACK.alpha(0.55))
        cv.poly(GOLD, [gx + 12, 16, gx + 22, 23, gx + 12, 30])
        cv.text(s, gx + 30, 28, 13, WHITE, 0, 2)
        if g.hits >= 3 {
            cv.stamp("\(g.hits)", W - g.safeR - 74, 78, 34, WHITE, 2)
            cv.text("HITS", W - g.safeR - 20, 76, 14, WHITE.alpha(0.9), 2, 3)
        }
        if g.hero.hp < g.hero.maxHp * 0.3 {
            let a = (0.3 + 0.2 * sin(t * 7)) * (1 - g.hero.hp / (g.hero.maxHp * 0.3) * 0.6)
            cv.vfill(0, 0, W, 90, [(0, BLOOD.alpha(a)), (1, BLOOD.alpha(0))]); cv.vfill(0, VIEW_H - 90, W, 90, [(0, BLOOD.alpha(0)), (1, BLOOD.alpha(a))])
        }
        // pause
        let pr = g.pauseRect
        cv.RR(pr.x, pr.y, pr.w, pr.h, 9, BLACK.alpha(0.45))
        cv.R(pr.x + 16, pr.y + 9, 5, 14, WHITE.alpha(0.85)); cv.R(pr.x + 27, pr.y + 9, 5, 14, WHITE.alpha(0.85))
        // message
        if g.msgT > 0 {
            let a = min(1, g.msgT * 2)
            let mw = min(W - 120, cv.textW(g.msg, 17, 2) + 44)
            cv.RR(W / 2 - mw / 2, 52, mw, 34, 10, BLACK.alpha(0.62 * a))
            cv.text(g.msg, W / 2, 75, 17, GOLD.alpha(a), 1, 2)
        }
        if g.nameT > 0 {
            let k = min(1, (1.5 - g.nameT) / 0.2)
            cv.save()
            cv.translate(W / 2, 150)
            cv.rotate(-0.04)
            cv.scale(1 + (1 - k) * 1.5, 1 + (1 - k) * 1.5)
            cv.alpha(min(1, g.nameT * 3))
            cv.stamp(g.supName, 0, 0, 44, g.tw.hue, 1)
            cv.restore()
        }
        // buttons
        // swipe pad: four arrows, the last swipe lights up
        let ab = g.atkBtn
        cv.circ(ab.0, ab.1, ab.2, BLACK.alpha(0.3))
        cv.ring(ab.0, ab.1, ab.2, 3, WHITE.alpha(g.input.attack || g.swipeShowT > 0 ? 0.8 : 0.35))
        for k in 2...5 {
            let ang: Double = k == 2 ? 0 : (k == 3 ? PI : (k == 4 ? -PI / 2 : PI / 2))
            let on = g.swipeShowT > 0 && g.swipeShow == k
            let r = ab.2 * (on ? 0.72 : 0.6)
            cv.save(); cv.translate(ab.0 + cos(ang) * r, ab.1 + sin(ang) * r); cv.rotate(ang)
            cv.poly(on ? g.tw.hue : WHITE.alpha(0.55), [9, 0, -5, -10, -5, 10])
            cv.restore()
        }
        cv.circ(ab.0, ab.1, 7, WHITE.alpha(0.45))
        let pb = g.powBtn
        let ready = g.meter >= 100
        if ready { cv.lighter(true); cv.glow(pb.0, pb.1, pb.2 * 2.1, GOLD.alpha(0.3 + 0.15 * sin(t * 6))); cv.lighter(false) }
        cv.circ(pb.0, pb.1, pb.2, BLACK.alpha(0.4))
        cv.ring(pb.0, pb.1, pb.2, 4, WHITE.alpha(0.25))
        cv.arcStroke(pb.0, pb.1, pb.2, -PI / 2, -PI / 2 + 2 * PI * clampD(g.meter / 100, 0.001, 1), 5, GOLD)
        let bc = ready ? GOLD : WHITE.alpha(0.4)
        cv.poly(bc, [pb.0 + 6, pb.1 - 26, pb.0 - 14, pb.1 + 4, pb.0 - 2, pb.1 + 4, pb.0 - 8, pb.1 + 26, pb.0 + 14, pb.1 - 6, pb.0 + 2, pb.1 - 6])
        // stick hint
        if g.playT < 6 {
            let a = clampD(6 - g.playT, 0, 1) * 0.7
            cv.text("◀  DRAG TO RUN  ▶", 150 + g.safeL, VIEW_H - 60, 15, WHITE.alpha(a), 1, 2)
            cv.RR(g.atkBtn.0 - 170, g.atkBtn.1 - g.atkBtn.2 - 47, 262, 42, 10, BLACK.alpha(a * 0.75))
            cv.text("SWIPE TO FIGHT", g.atkBtn.0, g.atkBtn.1 - g.atkBtn.2 - 30, 13, WHITE.alpha(a), 1, 2)
            cv.text("↑ uppercut   ↓ sweep   ←→ lunge   tap: strike", g.atkBtn.0 - 40, g.atkBtn.1 - g.atkBtn.2 - 12, 9.5, WHITE.alpha(a * 0.85), 1, 1)
        }
    }
    private func deadCard(_ g: Game, _ cv: Canvas) {
        let a = min(1, g.deadT * 2)
        cv.R(0, 0, g.W, VIEW_H, rgba(60, 0, 0, 0.55 * a))
        cv.stamp("DOWN.", g.W / 2, 260, 96, HOT.alpha(a), 1)
        cv.text(g.cpFloor > g.tw.top ? "Back to the roof" : "Back to the safe room on floor \(g.cpFloor)", g.W / 2, 310, 18, WHITE.alpha(a * 0.8), 1, 1)
    }
    private func card(_ g: Game, _ cv: Canvas) {
        let k = min(1, g.cardT / 0.25)
        cv.R(0, 0, g.W, VIEW_H, BLACK.alpha(0.5))
        cv.save()
        cv.translate(g.W / 2, 250)
        cv.rotate(-0.04)
        cv.scale(1 + (1 - k) * 2, 1 + (1 - k) * 2)
        cv.alpha(k)
        cv.stamp(g.tw.who, 0, 0, 150, g.tw.hue, 1)
        cv.stamp("\(g.tw.top) FLOORS TO THE STREET", 0, 62, 40, WHITE, 1)
        cv.restore()
        cv.text(g.tw.building, g.W / 2, 400, 16, WHITE.alpha(0.7), 1, 2)
    }
    /// What the next level of an upgrade adds, in a few words.
    private func gain(_ id: String, _ next: Int) -> String {
        switch id {
        case "smg": return ["Auto-fire at the nearest", "Harder-hitting rounds", "Rips through a crowd"][next - 1]
        case "shotgun": return ["Point-blank blast", "Reloads faster", "Twice the punch"][next - 1]
        case "nade": return ["One grenade every 3 s", "Bigger blast, faster", "Carpet the hallway"][next - 1]
        case "flame": return ["Burns what's in front", "Hotter fire", "They melt"][next - 1]
        case "drone": return ["One shot a second", "Fires twice as fast", "Three shots a second"][next - 1]
        case "minigun": return ["18 rounds a second", "Heavier rounds", "Nothing gets close"][next - 1]
        case "tesla": return ["Chains through 4", "Chains through 5", "Chains through 6"][next - 1]
        case "orbital": return ["A strike every 6 s", "Every 5 s", "Every 4 s"][next - 1]
        case "armor": return ["20% less damage", "40% less damage", "60% less damage"][next - 1]
        case "hp": return ["+25 health, full heal", "+50 health, full heal", "+75 health, full heal"][next - 1]
        case "dmg": return ["Steel: +25% damage", "Nails: +50% damage", "Barbed wire: +75% damage"][next - 1]
        default: return ["Faster, quicker power", "Faster still", "Never stop moving"][next - 1]
        }
    }
    private func pick(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let t = g.t
        let k = min(1, g.pickT * 4)
        cv.R(0, 0, W, VIEW_H, BLACK.alpha(0.8 * k))
        // slow rays behind everything
        cv.save()
        cv.translate(W / 2, 300)
        cv.rotate(t * 0.12)
        cv.lighter(true)
        for i in 0..<12 {
            let a = Double(i) * PI / 6
            cv.poly(GOLD.alpha(0.035 * k), [0, 0, cos(a) * 900, sin(a) * 900, cos(a + 0.2) * 900, sin(a + 0.2) * 900])
        }
        cv.lighter(false)
        cv.restore()
        cv.save()
        cv.translate(W / 2, 74)
        cv.rotate(-0.03)
        cv.scale(1 + (1 - k) * 1.2, 1 + (1 - k) * 1.2)
        cv.alpha(k)
        cv.stamp("PICK ONE", 0, 0, 46, GOLD, 1)
        cv.restore()
        cv.text("Earned with kills. They stack. You lose what you gained since the last safe room if you die.", W / 2, 104, 12, WHITE.alpha(0.7 * k), 1, 1)
        for i in 0..<g.pickOpts.count {
            let u = UPS[g.pickOpts[i]]
            let r = g.pickRect(i)
            let l = g.lv(u.id)
            let kin = easeOut(clampD((g.pickT - 0.08 - Double(i) * 0.12) / 0.3, 0, 1))
            let chosen = g.pickChosen == i
            let other = g.pickChosen >= 0 && !chosen
            let out = g.pickChosen >= 0 ? clampD(g.pickOutT / 0.45, 0, 1) : 0
            let edge: Col = u.sup ? Col(0xff6ac8) : (u.gun ? Col(0x7db8ff) : Col(0x8fe08a))
            let dark: Col = u.sup ? Col(0x2a1238) : (u.gun ? Col(0x131c2c) : Col(0x12241a))
            let pulse = 0.5 + 0.5 * sin(t * 3.4 + Double(i) * 1.7)
            let bobY: Double = sin(t * 1.8 + Double(i) * 2) * 4
            let tilt: Double = (i == 0 ? -0.022 : 0.022) * (1 - (chosen ? out : 0))
            var sc = 0.86 + 0.14 * kin
            if chosen { sc *= 1 + 0.12 * sin(out * PI) + 0.05 * out }
            if other { sc *= 1 - 0.25 * out }
            cv.save()
            cv.translate(r.x + r.w / 2, r.y + r.h / 2 + (1 - kin) * 320 + bobY)
            cv.rotate(tilt)
            cv.scale(sc, sc)
            cv.alpha(other ? 1 - out : kin)
            let hw = r.w / 2, hh = r.h / 2
            // glow, body, frame
            cv.lighter(true); cv.glow(0, 0, 250, edge.alpha(0.14 + 0.1 * pulse + (chosen ? 0.4 * out : 0))); cv.lighter(false)
            cv.RR(-hw + 5, -hh + 8, r.w, r.h, 18, BLACK.alpha(0.5))
            cv.RR(-hw, -hh, r.w, r.h, 18, dark)
            cv.save()
            cv.clipRect(-hw, -hh, r.w, 150)
            cv.vfill(-hw, -hh, r.w, 150, [(0, edge.alpha(0.34)), (1, edge.alpha(0))])
            cv.restore()
            // the emblem
            cv.save()
            cv.translate(0, -hh + 92)
            cv.rotate(t * 0.5)
            cv.lighter(true)
            for s in 0..<10 {
                let a = Double(s) * PI / 5
                cv.poly(edge.alpha(0.16 + 0.08 * pulse), [0, 0, cos(a) * 74, sin(a) * 74, cos(a + 0.26) * 74, sin(a + 0.26) * 74])
            }
            cv.lighter(false)
            cv.restore()
            cv.circ(0, -hh + 92, 48, BLACK.alpha(0.45))
            cv.ring(0, -hh + 92, 48, 3, edge.alpha(0.7 + 0.3 * pulse))
            if let ic = pic("up_\(u.id).png") { fit(cv, ic, 0, -hh + 92 + sin(t * 2.4 + Double(i)) * 3, 80) } else { cv.text(u.icon, 0, -hh + 113 + sin(t * 2.4 + Double(i)) * 3, 56, WHITE, 1, 1) }
            // name and level
            cv.stamp(u.name, 0, -hh + 182, 25, WHITE, 1)
            let pipW = 34.0
            for p in 0..<3 {
                let px = -pipW * 1.5 - 4 + Double(p) * (pipW + 4)
                let fill: Col = p < l ? GOLD : (p == l ? edge.alpha(0.55 + 0.45 * pulse) : WHITE.alpha(0.14))
                cv.RR(px, -hh + 194, pipW, 7, 3, fill)
            }
            cv.text(l == 0 ? "NEW" : "LEVEL \(l)  ▶  \(l + 1)", 0, -hh + 222, 12, GOLD, 1, 3)
            // what it does, and what this level adds
            wrap(cv, u.desc, 0, -hh + 246, 14, r.w - 50, WHITE.alpha(0.78))
            cv.RR(-hw + 22, hh - 104, r.w - 44, 30, 8, edge.alpha(0.16))
            cv.text(gain(u.id, min(3, l + 1)), 0, hh - 84, 14, edge, 1, 3)
            // take
            cv.RR(-hw + 22, hh - 62, r.w - 44, 42, 12, edge.alpha(0.82 + 0.18 * pulse))
            cv.text("TAKE", 0, hh - 34, 19, BLACK, 1, 3)
            cv.RRStroke(-hw, -hh, r.w, r.h, 18, 3 + pulse, edge)
            // a shine sweeping across
            let sweep = (t * 0.45 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1.6)
            if sweep < 1 {
                cv.save()
                cv.clipRect(-hw + 2, -hh + 2, r.w - 4, r.h - 4)
                cv.lighter(true)
                let sx = -hw - 80 + sweep * (r.w + 160)
                cv.poly(WHITE.alpha(0.10), [sx, -hh, sx + 46, -hh, sx - 30, hh, sx - 76, hh])
                cv.lighter(false)
                cv.restore()
            }
            // corner ribbon
            if u.sup || l == 0 {
                let label = u.sup ? "SUPER" : "NEW"
                cv.save()
                cv.clipRect(-hw, -hh, r.w, r.h)
                cv.translate(hw - 44, -hh + 44)
                cv.rotate(PI / 4)
                cv.R(-90, -13, 180, 26, u.sup ? Col(0xff6ac8) : GOLD)
                cv.text(label, 0, 6, 13, BLACK, 1, 3)
                cv.restore()
            }
            if chosen {
                cv.lighter(true); cv.RR(-hw, -hh, r.w, r.h, 18, WHITE.alpha(0.5 * (1 - out))); cv.lighter(false)
                cv.ring(0, 0, 120 + out * 260, 8 * (1 - out) + 1, edge.alpha(1 - out))
            }
            cv.restore()
        }
    }
    private func wrap(_ cv: Canvas, _ s: String, _ cx: Double, _ y: Double, _ size: Double, _ maxW: Double, _ c: Col) {
        var line = ""
        var yy = y
        for word in s.split(separator: " ") {
            let trial: String = line.isEmpty ? String(word) : line + " " + String(word)
            if cv.textW(trial, size, 1) > maxW && !line.isEmpty {
                cv.text(line, cx, yy, size, c, 1, 1)
                yy += size * 1.35
                line = String(word)
            } else { line = trial }
        }
        if !line.isEmpty { cv.text(line, cx, yy, size, c, 1, 1) }
    }
    private func pauseCard(_ g: Game, _ cv: Canvas) {
        cv.R(0, 0, g.W, VIEW_H, BLACK.alpha(0.72))
        cv.text("PAUSED", g.W / 2, 150, 44, GOLD, 1, 3)
        let r = g.resumeRect
        cv.RR(r.x, r.y, r.w, r.h, 14, GOLD)
        cv.text("RESUME", g.W / 2, r.y + 42, 26, BLACK, 1, 3)
        let q = g.quitRect
        cv.RR(q.x, q.y, q.w, q.h, 14, WHITE.alpha(0.14))
        cv.text("QUIT TO TITLE", g.W / 2, q.y + 34, 18, WHITE, 1, 2)
        let m = g.musicRect
        cv.RR(m.x, m.y, m.w, m.h, 14, WHITE.alpha(0.14))
        cv.text((g.snd?.musicOn ?? true) ? "MUSIC: ON" : "MUSIC: OFF", g.W / 2, m.y + 30, 16, WHITE, 1, 2)
        cv.text("Your floor is saved.", g.W / 2, m.y + 74, 13, WHITE.alpha(0.6), 1, 1)
        cv.text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))", g.W / 2, VIEW_H - 18, 10, WHITE.alpha(0.35), 1, 1)
    }

    private func ride(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let u = clampD(g.rideT / g.rideDur, 0, 1)
        cv.R(0, 0, W, VIEW_H, Col(0x050608))
        let hue = g.tw.hue
        switch g.rideKind {
        case .stairs:
            for i in 0..<9 {
                let y = (Double(i) * 70 + u * 280).truncatingRemainder(dividingBy: 630) - 40
                cv.poly(Col(0x1a1c22), [W / 2 - 220, y, W / 2 + 220, y + 60, W / 2 + 220, y + 78, W / 2 - 220, y + 18])
            }
            cv.stamp("FLOOR \(max(0, g.rideTo))", W / 2, 286, 64, hue, 1)
        case .hole:
            for i in 0..<26 {
                let fi = Double(i)
                let x = hashN(fi) * W
                let y = (hashN(fi + 9) * 700 - u * 1400).truncatingRemainder(dividingBy: 700)
                cv.R(x, y < 0 ? y + 700 : y, 3, 60 + hashN(fi + 3) * 80, WHITE.alpha(0.25))
            }
            figure(cv, W / 2, 250 + u * 120, 1, 1.1, heroLook(g.tw), fallPose(g.t))
            cv.stamp("DROP!", W / 2, 440, 54, hue, 1)
        case .lift:
            let open = u < 0.2 ? 1 - u / 0.2 : (u > 0.85 ? (u - 0.85) / 0.15 : 0)
            cv.R(W / 2 - 180, 60, 360, 420, Col(0x15171c))
            cv.R(W / 2 - 170, 70, 170 * (1 - open), 400, Col(0x8a929c))
            cv.R(W / 2 + 170 * open, 70, 170 * (1 - open), 400, Col(0x7c848e))
            let n = Int(lerp(Double(g.rideFrom), Double(g.rideTo), easeIO(u)).rounded())
            cv.RR(W / 2 - 60, 12, 120, 44, 8, Col(0x0a0a0c))
            cv.text("\(n)", W / 2, 46, 32, MINT, 1, 3)
            cv.poly(MINT, [W / 2 + 76, 26, W / 2 + 96, 26, W / 2 + 86, 42])
        case .rope:
            // rappelling down the outside of the tower; a zombie lunges out of a window on the way
            let rt = g.rideT
            let drop = rt * 300
            outsideWall(cv, W, drop)
            let cx = W / 2 + 40
            let swing = sin(rt * 3.2) * 18
            let hy = 330 + sin(rt * 6.5) * 6
            cv.seg(cx + 10, -20, cx + 10 + swing * 0.4, hy - 150, 6, Col(0xc23a22))
            cv.seg(cx + 10 + swing * 0.4, hy - 150, cx + swing, hy - 112, 6, Col(0xc23a22))
            var p = Pose()
            p.armF = 2.9; p.elbF = 0.35; p.armB = 2.6; p.elbB = 0.5; p.wpn = 2.4
            p.hipF = 1.25; p.kneeF = 1.4; p.hipB = 0.9; p.kneeB = 1.2; p.lean = -0.15
            let kick = g.grabDone && g.grabWon ? clampD((rt - 1.15) / 0.25, 0, 1) * (1 - clampD((rt - 1.6) / 0.3, 0, 1)) : 0
            if kick > 0 { p.hipF = lerp(1.25, -1.2, kick); p.kneeF = lerp(1.4, 0.1, kick) }
            figure(cv, cx + swing, hy, -1, 1.15, heroLook(g.tw), p)
            // the window and who is in it
            let wy = 560 - (rt - 0.6) * 300
            if rt > 0.6 && rt < 2.8 {
                let wx = cx - 170
                cv.R(wx - 70, wy - 150, 140, 150, Col(0x1a1310)); cv.R(wx - 62, wy - 142, 124, 134, Col(0x2a0e0a))
                cv.lighter(true); cv.glow(wx, wy - 70, 80, rgba(255, 110, 30, 0.4)); cv.lighter(false)
                let z = Zed(id: 0, kind: .zed, x: 0, depth: 3, seed: 0.37)
                var zp = zedPose(z, g.t)
                zp.armF = 1.55; zp.armB = 1.45; zp.elbF = 0.1; zp.elbB = 0.2; zp.jaw = 1
                if !g.grabDone {
                    let reach = clampD((rt - 0.9) / 0.9, 0, 1)
                    figure(cv, wx + reach * 70, wy - 10, 1, 1.1, zedLook(z), zp)
                } else if g.grabWon {
                    let k = rt - 1.15
                    cv.save(); cv.translate(wx + 60 + k * 260, wy + k * k * 900); cv.rotate(k * 5)
                    figure(cv, 0, 0, 1, 1.1, zedLook(z), fallPose(g.t))
                    cv.restore()
                    for i in 0..<10 { let fi = Double(i); cv.circ(wx + 80 + fi * 18 + k * 120, wy - 100 + hashN(fi) * 40 + k * 200, 4 + hashN(fi + 3) * 4, BLOOD.alpha(max(0, 1 - k))) }
                } else {
                    figure(cv, wx + 90, wy - 10, 1, 1.1, zedLook(z), zp)
                }
                cv.R(wx - 76, wy - 6, 152, 12, Col(0x6a5a50))
            }
            if !g.grabDone && rt > 0.95 {
                let b = 0.5 + 0.5 * sin(g.t * 18)
                cv.ring(cx + swing, hy - 90, 70 + b * 10, 5, GOLD.alpha(0.6 + 0.4 * b))
                cv.stamp("TAP TO KICK!", W / 2, 110, 48, GOLD, 1)
            } else if g.grabDone && rt < 2.4 {
                cv.stamp(g.grabWon ? "KICKED OFF!" : "GRABBED!", W / 2, 110, 48, g.grabWon ? GOLD : HOT, 1)
            }
            cv.stamp("FLOOR \(max(0, g.rideTo))", W / 2, 500, 40, hue, 1)
        case .ladder:
            // down the fire escape ladder, hand over hand
            let rt = g.rideT
            outsideWall(cv, W, rt * 220)
            let cx = W / 2
            let steel = Col(0x3a4150), steelL = Col(0x5a6272)
            cv.R(cx - 44, 0, 8, VIEW_H, steel); cv.R(cx + 36, 0, 8, VIEW_H, steel)
            let off = (rt * 220).truncatingRemainder(dividingBy: 34)
            var y = -34 + off
            while y < VIEW_H { cv.R(cx - 40, y, 80, 6, steelL); y += 34 }
            let gy = 640 - rt * 220
            if gy > -20 && gy < VIEW_H + 20 {
                cv.R(0, gy, W, 14, steel); var gx = 0.0; while gx < W { cv.R(gx, gy + 3, 2, 8, Col(0x14171d)); gx += 14 }
                cv.R(0, gy - 56, W, 4, steel)
            }
            let ph = rt * 9
            var p = Pose()
            p.armF = 2.8 + 0.35 * sin(ph); p.elbF = 0.4; p.armB = 2.8 - 0.35 * sin(ph); p.elbB = 0.4; p.wpn = 2.3
            p.hipF = 0.9 + 0.5 * max(0, sin(ph)); p.kneeF = 1.2; p.hipB = 0.9 + 0.5 * max(0, -sin(ph)); p.kneeB = 1.2
            figure(cv, cx, 360 + sin(ph * 2) * 4, 1, 1.15, heroLook(g.tw), p)
            cv.stamp("FIRE ESCAPE", W / 2, 110, 44, hue, 1)
            cv.stamp("FLOOR \(max(0, g.rideTo))", W / 2, 500, 40, hue, 1)
        case .shaft:
            // sliding down the elevator cable with sparks off the gloves
            let rt = g.rideT
            let drop = rt * 900
            cv.R(0, 0, W, VIEW_H, Col(0x0b0c0e))
            cv.R(W / 2 - 260, 0, 520, VIEW_H, Col(0x14151a))
            let j0 = Int(((drop - 200) / 180).rounded(.down))
            for j in j0..<(j0 + 6) {
                let yy = Double(j) * 180 - drop
                cv.R(W / 2 - 260, yy, 520, 10, Col(0x24262c))
                cv.R(W / 2 + 160, yy + 20, 90, 130, Col(0x2a2e36)); cv.R(W / 2 + 205, yy + 20, 2, 130, Col(0x0a0a0c))
                cv.text("\(max(0, g.rideFrom - j))", W / 2 + 205, yy + 14, 12, MINT.alpha(0.7), 1, 2)
            }
            cv.R(W / 2 - 4, 0, 8, VIEW_H, Col(0x4a4a50)); cv.R(W / 2 - 1, 0, 2, VIEW_H, Col(0x8a8a92))
            var p = Pose()
            p.armF = 3.0; p.elbF = 0.2; p.armB = 2.9; p.elbB = 0.3; p.wpn = 2.4
            p.hipF = 0.4; p.kneeF = 0.6; p.hipB = 0.2; p.kneeB = 0.5
            figure(cv, W / 2 + 6, 380, 1, 1.15, heroLook(g.tw), p)
            cv.lighter(true)
            for i in 0..<14 {
                let fi = Double(i)
                let k = (g.t * 3 + hashN(fi)).truncatingRemainder(dividingBy: 1)
                cv.circ(W / 2 + (hashN(fi + 2) - 0.5) * 80 * k, 220 + k * 160, 3 * (1 - k) + 1, rgba(255, 200 - k * 120, 60, 1 - k))
            }
            cv.glow(W / 2, 220, 40, rgba(255, 170, 60, 0.5))
            cv.lighter(false)
            cv.stamp("ELEVATOR SHAFT", W / 2, 110, 44, hue, 1)
            cv.stamp("FLOOR \(max(0, g.rideTo))", W / 2, 500, 40, hue, 1)
        }
        if u < 0.15 { cv.R(0, 0, W, VIEW_H, BLACK.alpha(1 - u / 0.15)) }
    }
    /// The tower's outside brick face, scrolling up as you go down.
    private func outsideWall(_ cv: Canvas, _ W: Double, _ drop: Double) {
        cv.R(0, 0, W, VIEW_H, Col(0x0a0b12))
        if let im = wallFor("hall_brick.jpg", Col(0x050814).alpha(0.35), VIEW_H, cv.sc) {
            let y0 = -(drop.truncatingRemainder(dividingBy: VIEW_H))
            wallTiles(cv, im, 0, W, y0, VIEW_H, 7)
            wallTiles(cv, im, 0, W, y0 + VIEW_H, VIEW_H, 8)
        }
        cv.lighter(true); cv.R(0, 0, W, VIEW_H, rgba(255, 110, 40, 0.05)); cv.lighter(false)
        cv.vfill(0, 0, W, 120, [(0, BLACK.alpha(0.5)), (1, BLACK.alpha(0))])
    }
    private func fallPose(_ t: Double) -> Pose {
        var p = Pose()
        p.armF = 2.6 + sin(t * 18) * 0.3; p.armB = -2.4 + sin(t * 16) * 0.3
        p.hipF = 0.7; p.kneeF = 0.9; p.hipB = -0.5; p.kneeB = 0.7
        p.wpn = 0.2
        return p
    }

    // ---------- title
    private func title(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let t = g.t
        night(cv, 0, W, VIEW_H, t)
        cv.circ(W * 0.8, 96, 34, Col(0xf2ead2)); cv.circ(W * 0.8 - 10, 90, 7, Col(0xd9d0b8))
        skyline(cv, 0, W, VIEW_H - 30, t * 6)
        // the tower
        let tx = W / 2 - 90
        cv.R(tx, 40, 180, VIEW_H, Col(0x11141f))
        cv.R(tx + 60, 10, 60, 30, Col(0x161a28)); cv.R(tx + 88, -20, 4, 30, Col(0x2a3042))
        for r in 0..<32 { for c in 0..<8 {
            let h = hashN(Double(r * 13 + c * 7))
            let wx = tx + 10 + Double(c) * 21, wy = 52 + Double(r) * 15.5
            if h > 0.9 { cv.R(wx, wy, 14, 9, rgba(255, 130, 40, 0.7 + 0.3 * sin(t * 8 + h * 30))) } else if h > 0.45 { cv.R(wx, wy, 14, 9, rgba(255, 226, 170, 0.5)) } else { cv.R(wx, wy, 14, 9, Col(0x07080c)) }
        } }
        cv.lighter(true)
        cv.glow(W / 2, VIEW_H, 520, rgba(255, 90, 30, 0.3))
        for i in 0..<40 {
            let fi = Double(i)
            let u = (t * 0.22 + hashN(fi)).truncatingRemainder(dividingBy: 1)
            cv.circ(hashN(fi + 20) * W + sin(t + fi) * 20, VIEW_H - u * 560, 2.2, rgba(255, 180 - u * 100, 60, 1 - u))
        }
        cv.lighter(false)
        // the three, and what is coming
        let gy = VIEW_H - 22.0
        cv.R(0, gy, W, 30, Col(0x08090c))
        for i in 0..<3 {
            var p = Pose()
            p.bob = sin(t * 2.4 + Double(i)) * 1.5
            p.armF = 0.2; p.elbF = 1.4; p.wpn = 1.2; p.hipF = 0.25; p.hipB = -0.25
            figure(cv, 120 + g.safeL + Double(i) * 78, gy, 1, 1.05, heroLook(TOWERS[i]), p)
        }
        for i in 0..<5 {
            let z = Zed(id: 0, kind: i == 2 ? .runner : .zed, x: 0, depth: 0, seed: hashN(Double(i) + 2))
            z.walk = t * 60 + Double(i) * 40
            figure(cv, W - g.safeR - 90 - Double(i) * 62 - sin(t * 0.6) * 10, gy, -1, 1.0, zedLook(z), zedPose(z, t))
        }
        // the name
        cv.save()
        cv.translate(W / 2, 190)
        cv.rotate(-0.05)
        cv.stamp("FLOOR", -8, -40, 110, WHITE, 1)
        cv.stamp("ZERO", 8, 62, 130, GOLD, 1)
        cv.restore()
        cv.text("GET DOWN. ALL THREE OF YOU.", W / 2, 330, 16, WHITE.alpha(0.85), 1, 3)
        // play
        let r = g.playRect
        cv.save()
        cv.translate(r.x + r.w / 2, r.y + r.h / 2)
        cv.rotate(-0.03)
        let pulse = 1 + 0.03 * sin(t * 4)
        cv.scale(pulse, pulse)
        cv.RR(-r.w / 2, -r.h / 2, r.w, r.h, 8, GOLD)
        cv.save()
        cv.clipRect(-r.w / 2, -r.h / 2, r.w, 12)
        for i in -2..<16 { let sx = -r.w / 2 + Double(i) * 28 + (t * 20).truncatingRemainder(dividingBy: 28); cv.poly(BLACK, [sx, -r.h / 2, sx + 14, -r.h / 2, sx + 2, -r.h / 2 + 12, sx - 12, -r.h / 2 + 12]) }
        cv.restore()
        cv.save()
        cv.clipRect(-r.w / 2, r.h / 2 - 12, r.w, 12)
        for i in -2..<16 { let sx = -r.w / 2 + Double(i) * 28 - (t * 20).truncatingRemainder(dividingBy: 28); cv.poly(BLACK, [sx, r.h / 2 - 12, sx + 14, r.h / 2 - 12, sx + 2, r.h / 2, sx - 12, r.h / 2]) }
        cv.restore()
        cv.text(g.hasSave ? "NEW GAME" : "PLAY", 0, 15, 40, BLACK, 1, 3)
        cv.restore()
        if g.hasSave {
            let c = g.contRect
            let d = UserDefaults.standard
            let tw = TOWERS[max(0, min(2, d.integer(forKey: "fz.tower")))]
            cv.RR(c.x, c.y, c.w, c.h, 10, BLACK.alpha(0.6))
            cv.RRStroke(c.x, c.y, c.w, c.h, 10, 2, MINT)
            cv.text("CONTINUE · \(tw.who) · FLOOR \(d.integer(forKey: "fz.floor"))", W / 2, c.y + 26, 15, MINT, 1, 3)
        }
    }

    // ---------- the opening: five quick shots
    private func stampIn(_ cv: Canvas, _ s: String, _ t: Double, _ col: Col, _ g: Game) {
        let k = min(1, t / 0.25)
        let sc = 1 + (1 - k) * (1 - k) * 2.2
        cv.save()
        cv.translate(40 + g.safeL, 96)
        cv.rotate(-0.045)
        cv.scale(sc, sc)
        cv.alpha(k)
        cv.stamp(s, 0, 0, 58, col, 0)
        cv.R(0, 12, cv.textW(s, 58, 3), 6, col)
        cv.restore()
    }
    private func intro(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let shot = min(4, Int(g.introT / 1.8))
        let t = g.introT - Double(shot) * 1.8
        let T = g.t
        let gy = 452.0
        let confetti: [Col] = [Col(0xff6b8a), GOLD, Col(0x7dd3ff), Col(0x8fe08a)]
        cv.save()
        switch shot {
        case 0:
            night(cv, 0, W, 400, T); skyline(cv, 0, W, 380, 0)
            cv.R(0, gy, W, VIEW_H - gy, Col(0x1a1420))
            var rx = 0.0
            while rx < W { cv.R(rx, gy - 92, 1.6, 92, Col(0x3a4050)); rx += 14 }
            cv.R(0, gy - 94, W, 4, Col(0x3a4050))
            cv.R(W - 360, gy - 92, 300, 92, Col(0x3b2420)); cv.R(W - 366, gy - 97, 312, 6, Col(0xc9a24a))
            for i in 0..<28 {
                let u = Double(i) / 27
                let lx = 40 + (W - 80) * u, ly = 150 + 200 * u * (1 - u)
                cv.lighter(true); cv.glow(lx, ly, 26, rgba(255, 230, 160, 0.3)); cv.lighter(false)
                cv.circ(lx, ly, 2.8, Col(0xffe6a0))
            }
            for i in 0..<3 {
                var p = Pose()
                p.bob = abs(sin(T * 3.6 + Double(i))) * 5
                p.armF = 2.6 + sin(T * 3.6 + Double(i)) * 0.3; p.elbF = 0.2; p.hipF = 0.2; p.hipB = -0.2
                var l = heroLook(TOWERS[i]); l.weapon = 0
                figure(cv, W * 0.3 + Double(i) * 84, gy, i == 0 ? 1 : -1, 0.95, l, p)
            }
            for i in 0..<40 {
                let fi = Double(i)
                let u = (T * 0.3 + hashN(fi)).truncatingRemainder(dividingBy: 1)
                let cc: Col = confetti[i % 4]
                cv.R(hashN(fi + 50) * W + sin(T * 2 + fi) * 20, u * 470, 6, 3, cc)
            }
            stampIn(cv, "SUNDAY. A PARTY.", t, GOLD, g)
        case 1:
            cv.vfill(0, 0, W, VIEW_H, [(0, Col(0x04100c)), (1, Col(0x0c2a1c))])
            // pipes on the back wall
            for i in 0..<4 { cv.R(0, 60 + Double(i) * 34, W, 10, Col(0x10241c)); cv.R(120 + Double(i) * 260, 60, 12, 136, Col(0x10241c)) }
            let vx = W * 0.58, vTop = 300.0
            // the catwalk he stands on, and its ladder
            cv.R(vx - 330, vTop - 4, 190, 10, Col(0x2a3a34))
            var rx2 = vx - 330.0
            while rx2 < vx - 140 { cv.R(rx2, vTop - 54, 3, 50, Col(0x2a3a34)); rx2 += 30 }
            cv.R(vx - 330, vTop - 56, 190, 4, Col(0x2a3a34))
            cv.R(vx - 320, vTop + 6, 6, 260, Col(0x22302a)); cv.R(vx - 286, vTop + 6, 6, 260, Col(0x22302a))
            for i in 0..<8 { cv.R(vx - 320, vTop + 24 + Double(i) * 30, 40, 4, Col(0x22302a)) }
            // the vat: a steel drum, open at the top, full of green
            cv.R(vx - 150, vTop, 300, 260, Col(0x25352f))
            cv.R(vx - 150, vTop, 26, 260, Col(0x3a4c44)); cv.R(vx + 110, vTop, 40, 260, Col(0x18241f))
            for i in 0..<3 { cv.R(vx - 154, vTop + 50 + Double(i) * 76, 308, 9, Col(0x101a16)) }
            cv.poly(GOLD, [vx - 30, vTop + 150, vx + 30, vTop + 150, vx, vTop + 98]); cv.text("!", vx, vTop + 144, 30, BLACK, 1, 3)
            cv.ell(vx, vTop, 150, 30, Col(0x101a16))
            cv.ell(vx, vTop + 3, 138, 24, Col(0x1f9a52))
            cv.ell(vx - 20, vTop + 1, 90, 13, Col(0x56e88a))
            for i in 0..<3 {
                let u = (T * 0.7 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                cv.ellStroke(vx - 70, vTop + 3, 12 + u * 60, 3 + u * 12, 3 * (1 - u) + 0.5, rgba(200, 255, 220, 0.9 * (1 - u)))
            }
            for i in 0..<9 {
                let fi = Double(i)
                let u = (T * (0.5 + hashN(fi) * 0.5) + hashN(fi + 5)).truncatingRemainder(dividingBy: 1)
                cv.circ(vx - 110 + hashN(fi + 9) * 220, vTop - 2 - u * 70, 3 + hashN(fi + 2) * 5 * (1 - u), rgba(140, 255, 180, 0.8 * (1 - u)))
            }
            cv.lighter(true)
            cv.glow(vx, vTop - 10, 330, rgba(60, 255, 140, 0.32 + 0.06 * sin(T * 5)))
            cv.vfill(vx - 140, vTop - 220, 280, 220, [(0, rgba(60, 255, 140, 0)), (1, rgba(60, 255, 140, 0.22))])
            cv.lighter(false)
            // Marr on the catwalk, tipping a canister in
            var p = Pose()
            p.armF = 1.15; p.elbF = 0.35; p.lean = 0.22; p.armB = 0.9; p.elbB = 0.5; p.hipF = 0.2; p.hipB = -0.2
            var l = Look(shirt: Col(0xd9dcd6), pants: Col(0x2a2f3c), skin: Col(0xc9a384), hair: Col(0x9a9a92), eye: Col(0x15151a)); l.coat = true
            figure(cv, vx - 214, vTop - 4, 1, 1.0, l, p)
            let cx = vx - 150.0, cy = vTop - 104.0
            cv.save()
            cv.translate(cx, cy)
            cv.rotate(0.95)
            cv.RR(-16, -24, 32, 48, 5, Col(0x0b0c10)); cv.RR(-14, -22, 28, 44, 4, Col(0xe8c860)); cv.R(-14, -6, 28, 12, Col(0x15151a))
            cv.R(-6, 22, 12, 8, Col(0x3a3a3a))
            cv.restore()
            // the stream, from the spout down to the surface
            let sx0 = cx + 22, sy0 = cy + 16, sx1 = vx - 70, sy1 = vTop + 2
            cv.curve(sx0, sy0, sx0 + 34, sy0 + 20, sx1, sy1, 9, Col(0x56e88a))
            cv.curve(sx0, sy0, sx0 + 34, sy0 + 20, sx1, sy1, 3.5, Col(0xd0ffe0))
            for i in 0..<6 {
                let u = (T * 2.2 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
                cv.circ(sx1 + (hashN(Double(i)) - 0.5) * 60 * u, sy1 - sin(u * PI) * 34, 3.5 * (1 - u) + 1, rgba(180, 255, 200, 1 - u))
            }
            cv.vfill(0, VIEW_H - 160, W, 160, [(0, rgba(40, 220, 110, 0)), (1, rgba(40, 220, 110, 0.28 * min(1, t / 1.0)))])
            stampIn(cv, "POISONED WATER.", t, MINT, g)
        case 2:
            let bt = t.truncatingRemainder(dividingBy: 0.9)
            if bt < 0.3 { cv.translate(rnd(-8, 8) * (1 - bt / 0.3), rnd(-6, 6) * (1 - bt / 0.3)) }
            night(cv, 0, W, 400, T)
            var bx = -30.0
            var bi = 0
            while bx < W {
                let h = 250 + hashN(Double(bi) * 5.3) * 90
                let face: Col = bi % 2 == 0 ? Col(0x17141c) : Col(0x1c1820)
                cv.R(bx, gy - h, 160, h, face)
                for r in 0..<3 { for c in 0..<3 {
                    let burn = (bi * 3 + r * 5 + c) % 5 == 0
                    cv.R(bx + 16 + Double(c) * 48, gy - h + 22 + Double(r) * 62, 34, 42, burn ? rgba(255, 140, 40, 0.8) : Col(0x07080c))
                } }
                bx += 172
                bi += 1
            }
            cv.lighter(true); cv.glow(W / 2, gy, 700, rgba(255, 90, 30, 0.35)); cv.lighter(false)
            cv.R(0, gy, W, VIEW_H - gy, Col(0x17181c))
            for i in 0..<11 {
                let z = Zed(id: 0, kind: i % 4 == 1 ? .runner : .zed, x: 0, depth: 0, seed: hashN(Double(i) * 3 + 1))
                z.look = i
                z.walk = T * 160 + Double(i) * 30
                let zx = ((g.introT - 3.6) * 190 + Double(i) * 74).truncatingRemainder(dividingBy: W + 200) - 100
                figure(cv, zx, gy, 1, 1.02, zedLook(z), zedPose(z, T))
            }
            if bt < 0.6 {
                let u = bt / 0.6
                let ex = W * (0.35 + 0.3 * hashN((t / 0.9).rounded(.down)))
                cv.lighter(true)
                cv.glow(ex, gy - 40, 230 * (0.3 + 0.7 * easeOut(u)), rgba(255, 190, 70, 0.95 * (1 - u)))
                cv.lighter(false)
            }
            stampIn(cv, "EVERYONE TURNED.", t, HOT, g)
        case 3:
            cv.R(0, 0, W, VIEW_H, Col(0x05060a))
            let pw = W / 3
            for i in 0..<3 {
                let k = easeIO(clampD((t - Double(i) * 0.12) / 0.3, 0, 1))
                let off = (1 - k) * (i % 2 == 0 ? -VIEW_H : VIEW_H)
                let tw = TOWERS[i]
                let x0 = Double(i) * pw
                cv.save()
                cv.translate(0, off)
                cv.clipRect(x0 + 3, 0, pw - 6, VIEW_H)
                cv.vfill(x0, 0, pw, VIEW_H, [(0, Col(0x0a0c16)), (1, Col.mix(tw.hue, BLACK, 0.75))])
                cv.R(x0 + pw / 2 - 70, 150, 140, 400, Col(0x11141f))
                for r in 0..<20 { for c in 0..<5 { if hashN(Double(r * 7 + c * 3 + i * 11)) > 0.5 { cv.R(x0 + pw / 2 - 58 + Double(c) * 24, 162 + Double(r) * 15, 14, 8, rgba(255, 226, 170, 0.45)) } } }
                var p = Pose()
                p.armF = 0.2; p.elbF = 1.4; p.wpn = 1.2; p.hipF = 0.3; p.hipB = -0.3; p.bob = sin(T * 3 + Double(i)) * 2
                figure(cv, x0 + pw / 2 - 6, gy, 1, 1.3, heroLook(tw), p)
                cv.stamp(tw.who, x0 + pw / 2, 96, 54, tw.hue, 1)
                cv.text("\(tw.top) FLOORS", x0 + pw / 2, 126, 20, WHITE, 1, 3)
                cv.restore()
            }
            if t > 0.6 {
                let k = min(1, (t - 0.6) / 0.25)
                cv.save()
                cv.translate(W / 2, VIEW_H - 40)
                cv.rotate(-0.03)
                cv.scale(1 + (1 - k) * 1.5, 1 + (1 - k) * 1.5)
                cv.alpha(k)
                cv.stamp("MEET AT THE BOTTOM.", 0, 0, 44, WHITE, 1)
                cv.restore()
            }
        default:
            let hit = t > 1.0
            if hit && t < 1.25 { cv.translate(rnd(-12, 12), rnd(-8, 8)) }
            night(cv, 0, W, 400, T); skyline(cv, 0, W, 390, 0)
            cv.R(0, gy, W, VIEW_H - gy, Col(0x1b1d24))
            let dx = W * 0.72
            cv.R(dx - 40, gy - 250, 300, 250, Col(0x22262f)); cv.R(dx, gy - 190, 110, 190, Col(0x060608))
            cv.lighter(true); cv.glow(dx + 55, gy - 100, 170, rgba(255, 200, 120, 0.25)); cv.lighter(false)
            for i in 0..<3 {
                let z = Zed(id: 0, kind: i == 1 ? .runner : .zed, x: 0, depth: 0, seed: hashN(Double(i) + 5))
                z.look = i
                z.walk = T * 200
                let hu = clampD((t - 1.0) / 0.7, 0, 1)
                let fi = Double(i)
                let stand: Double = W * 0.42 + fi * 60
                let run: Double = dx + 40 - t * (330 - fi * 40)
                let zx: Double = hit ? stand + hu * (260 + fi * 80) : max(stand, run)
                if hit {
                    cv.save(); cv.translate(zx, gy - sin(hu * PI) * (150 + Double(i) * 40)); cv.rotate(hu * (5 + Double(i) * 2))
                    figure(cv, 0, 0, -1, 1, zedLook(z), zedPose(z, T)); cv.restore()
                } else { figure(cv, zx, gy, -1, 1, zedLook(z), zedPose(z, T)) }
            }
            var p = Pose()
            let u = clampD((t - 0.8) / 0.3, 0, 1)
            p.armF = lerp(3.6, 0.9, easeOut(u)); p.elbF = 0.25; p.wpn = 0.1
            p.lean = 0.15 + 0.3 * sin(u * PI); p.hipF = 0.5; p.hipB = -0.45; p.kneeF = 0.4
            figure(cv, W * 0.34, gy, 1, 1.15, heroLook(TOWERS[0]), p)
            if hit && t < 1.4 {
                let a = 1 - (t - 1.0) / 0.4
                cv.lighter(true)
                cv.arcStroke(W * 0.34 + 20, gy - 110, 150, -1.25, 0.75, 18 * a + 2, rgba(255, 240, 200, a))
                cv.lighter(false)
                cv.R(0, 0, W, VIEW_H, WHITE.alpha(max(0, 0.7 - (t - 1.0) * 4)))
            }
            stampIn(cv, "TRAPPED.", t, GOLD, g)
        }
        cv.restore()
        if t < 0.25 { cv.R(0, 0, W, VIEW_H, WHITE.alpha(1 - t / 0.25)) }
        cv.R(0, 0, W, 22, BLACK)
        cv.text("skip  ▶", W - g.safeR - 20, 44, 13, GOLD.alpha(0.7), 2, 1)
    }

    private func ending(_ g: Game, _ cv: Canvas) {
        let W = g.W
        let t = g.endT
        night(cv, 0, W, VIEW_H, g.t)
        skyline(cv, 0, W, VIEW_H - 40, 0)
        cv.vfill(0, VIEW_H - 260, W, 260, [(0, rgba(255, 150, 80, 0)), (1, rgba(255, 170, 90, 0.5))])
        let gy = VIEW_H - 40.0
        cv.R(0, gy, W, 40, Col(0x101216))
        for i in 0..<3 {
            var p = Pose()
            p.armF = 2.8; p.elbF = 0.2; p.wpn = 0.1; p.bob = abs(sin(g.t * 3 + Double(i))) * 5; p.hipF = 0.2; p.hipB = -0.2
            figure(cv, W / 2 - 90 + Double(i) * 90, gy, 1, 1.15, heroLook(TOWERS[i]), p)
        }
        let k = min(1, t / 0.3)
        cv.save()
        cv.translate(W / 2, 130)
        cv.rotate(-0.04)
        cv.scale(1 + (1 - k) * 2, 1 + (1 - k) * 2)
        cv.stamp("FLOOR ZERO.", 0, 0, 84, GOLD, 1)
        cv.restore()
        cv.text("All three made it to the plaza.", W / 2, 190, 20, WHITE, 1, 2)
        let mins = Int(g.playT / 60)
        cv.text("\(mins) minutes   ·   \(g.kills) put down   ·   went down \(g.deaths) times", W / 2, 224, 15, WHITE.alpha(0.8), 1, 1)
        if t > 1.5 { cv.text("tap", W / 2, 262, 14, GOLD.alpha(0.6 + 0.3 * sin(g.t * 4)), 1, 2) }
    }
}
