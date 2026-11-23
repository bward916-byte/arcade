import CoreGraphics
import Foundation
import ImageIO

// People drawn from Platformer Hero frames: walk, run and idle cycles rendered from the 3D rig to sprite sheets,
// each with a night-lit copy. The player has three outfits by rank; townsfolk, crew and workers have their own.

final class HeroSheet {
    static let shared = HeroSheet()
    let cw = 192, ch = 227
    private var day: [String: [[CGImage]]] = [:]
    private var night: [String: [[CGImage]]] = [:]
    private var missing: Set<String> = []

    /// The frames for one outfit: rows of sixteen, day and night. nil if the sheet is not in the app.
    func frames(_ name: String) -> ([[CGImage]], [[CGImage]])? {
        if let d = day[name], let n = night[name] { return (d, n) }
        if missing.contains(name) { return nil }
        let d = cut("hero_" + name), n = cut("hero_" + name + "_night")
        if d.isEmpty || n.count != d.count { missing.insert(name); return nil }
        day[name] = d
        night[name] = n
        return (d, n)
    }
    private func cut(_ file: String) -> [[CGImage]] {
        guard let url = Bundle.main.url(forResource: file, withExtension: "png"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return [] }
        var rows: [[CGImage]] = []
        for r in 0..<(img.height / ch) {
            var row: [CGImage] = []
            for i in 0..<16 {
                if let f = img.cropping(to: CGRect(x: i * cw, y: r * ch, width: cw, height: ch)) { row.append(f) }
            }
            if row.count != 16 { return [] }
            rows.append(row)
        }
        return rows
    }
}

extension Game {
    /// One figure from a sheet, feet at world x. tall is its height in world units. Returns false if the sheet is absent.
    func drawSprite(_ c: Canvas, _ name: String, _ row: Int, _ frame: Int, _ wx: Double, _ faceDir: Double, _ tall: Double, _ L: Double) -> Bool {
        guard let (d, n) = HeroSheet.shared.frames(name), row < d.count else { return false }
        let f = ((frame % 16) + 16) % 16
        let h = tall * camS
        let fh = h * 227 / 206, fw = fh * 192 / 227
        let X = sx(wx), Y = sy(groundLand(wx))
        c.ell(X, Y + 1, h * 0.2, h * 0.042, Col(0x000000, 0.16 + 0.12 * L))
        c.save()
        c.translate(X, Y)
        c.scale(faceDir < 0 ? -1 : 1, 1)
        let top = -fh * 216 / 227
        c.drawImage(d[row][f], -fw / 2, top, fw, fh)
        if L < 0.98 {
            c.alpha(1 - L)
            c.drawImage(n[row][f], -fw / 2, top, fw, fh)
            c.alpha(1)
        }
        c.restore()
        return true
    }

    /// The player: dock boy, then sailor, then captain.
    func drawHero(_ c: Canvas, _ L: Double) -> Bool {
        let grow: Double = [0.74, 0.78, 0.84, 0.9, 0.9, 0.9][min(5, boat)]
        let tall = 46 * grow
        let moving = abs(speed) > 4
        let running = abs(speed) > 84
        var row = 2, frame = Int(T / 2.4 * 16)
        if moving {
            row = running ? 1 : 0
            frame = Int(walkPh / 0.17 / ((running ? 2.02 : 0.98) * tall) * 16)
        }
        let name = stage >= 2 ? "captain" : (stage == 1 ? "sailor" : "boy")
        if !drawSprite(c, name, row, frame, px, face, tall, L) { return false }
        let X = sx(px), Y = sy(groundLand(px)), k = camS * grow
        if stage >= 2 {
            // the captain's tricorn, over the dark cap
            let hy = Y - (tall - 3.2 * grow) * camS + (moving ? 0 : sin(T * 2.6) * 0.3 * k)
            let d: Double = face < 0 ? -1 : 1
            c.poly(lc(0x1c1c24), [X - 6.5 * k * d, hy, X + 7.5 * k * d, hy, X + 4.2 * k * d, hy - 4.6 * k, X - 3.4 * k * d, hy - 4.6 * k])
            c.seg(X - 6 * k * d, hy - 0.4 * k, X + 7 * k * d, hy - 0.4 * k, 0.9 * k, lc(0xd8b86a))
        }
        if haul == 2 {
            c.R(X - 9 * k, Y - tall * camS - 15 * k, 18 * k, 16 * k, lc(0x8a6238))
            c.R(X - 9 * k, Y - tall * camS - 15 * k, 18 * k, 1.4 * k, lc(0x4a2e14))
            c.seg(X - 9 * k, Y - tall * camS - 15 * k, X + 9 * k, Y - tall * camS + 1 * k, 1 * k, lc(0x4a2e14))
        }
        return true
    }
}
