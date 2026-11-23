import CoreGraphics
import Foundation
import ImageIO

// A test: the player drawn from Platformer Hero frames (walk, run and idle cycles rendered from the 3D rig
// to a sprite sheet, with a night-lit copy) instead of the hand-drawn figure. Townsfolk are unchanged.

final class HeroSheet {
    static let shared = HeroSheet()
    let cw = 192, ch = 227
    var day: [[CGImage]] = []
    var night: [[CGImage]] = []
    var ok: Bool { return day.count == 3 && night.count == 3 }

    private init() {
        day = HeroSheet.cut("hero", cw, ch)
        night = HeroSheet.cut("hero_night", cw, ch)
    }
    private static func cut(_ name: String, _ cw: Int, _ ch: Int) -> [[CGImage]] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return [] }
        var rows: [[CGImage]] = []
        for r in 0..<3 {
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
    /// Draws the player from the sprite sheet. Returns false if the frames are not there, so the old figure is used.
    func drawHero(_ c: Canvas, _ L: Double) -> Bool {
        let sheet = HeroSheet.shared
        if !sheet.ok { return false }
        let grow: Double = [0.74, 0.78, 0.84, 0.9, 0.9, 0.9][min(5, boat)]
        let tall = 46 * grow * camS                      // the height the old figure stood
        let fh = tall * 227 / 206, fw = fh * 192 / 227   // the frame is a little taller than the figure in it
        let moving = abs(speed) > 4
        let running = abs(speed) > 84
        let dist = walkPh / 0.17
        var row = 2, frame = Int(T / 2.4 * 16) % 16
        if moving {
            row = running ? 1 : 0
            let cycle = (running ? 2.02 : 0.98) * 46 * grow
            frame = Int(dist / cycle * 16) % 16
        }
        frame = ((frame % 16) + 16) % 16
        let X = sx(px), Y = sy(groundLand(px))
        c.ell(X, Y + 1, 9 * camS * grow, 1.9 * camS * grow, Col(0x000000, 0.16 + 0.12 * L))
        c.save()
        c.translate(X, Y)
        c.scale(face < 0 ? -1 : 1, 1)
        let top = -fh * 216 / 227
        c.drawImage(sheet.day[row][frame], -fw / 2, top, fw, fh)
        if L < 0.98 {
            c.alpha(1 - L)
            c.drawImage(sheet.night[row][frame], -fw / 2, top, fw, fh)
            c.alpha(1)
        }
        c.restore()
        // the crate, when hauling
        if haul == 2 {
            let k = camS * grow
            c.R(X - 9 * k, Y - tall - 15 * k, 18 * k, 16 * k, lc(0x8a6238))
            c.R(X - 9 * k, Y - tall - 15 * k, 18 * k, 1.4 * k, lc(0x4a2e14))
            c.seg(X - 9 * k, Y - tall - 15 * k, X + 9 * k, Y - tall + 1 * k, 1 * k, lc(0x4a2e14))
        }
        return true
    }
}
