import AVFoundation
import Foundation

/// Far Horizon's sound effects and music: short tones and bursts of filtered noise, made in code.
final class Sound {
    private struct Voice {
        var wave: Int        // 0 sine, 1 triangle, 2 square, 3 sawtooth, 4 noise, 5 reed (sine with overtones)
        var f: Double
        var f2: Double
        var dur: Double
        var vol: Double
        var t: Double        // negative while waiting out a delay
        var phase = 0.0
        var low = 0.0
        var band = 0.0
        var q = 1.0
    }

    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var voices: [Voice] = []
    private let lock = NSLock()
    private let rate = 44100.0
    private var echo = [Double](repeating: 0, count: 13230)   // 0.3 s
    private var echoI = 0
    private var running = false
    var muted = false

    func start() {
        if running { return }
        let session = AVAudioSession.sharedInstance()
        // .playback so the game is heard even with the ring switch on silent; it still mixes with music
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return }
        let src = AVAudioSourceNode(format: fmt) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let list = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let n = Int(frameCount)
            guard let me = self, list.count > 0, let raw = list[0].mData else { return noErr }
            let out = raw.assumingMemoryBound(to: Float.self)
            me.render(out, n)
            return noErr
        }
        node = src
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: fmt)
        do { try engine.start(); running = true } catch { running = false }
    }

    func resume() {
        if running && !engine.isRunning { try? engine.start() }
    }

    private func render(_ out: UnsafeMutablePointer<Float>, _ n: Int) {
        lock.lock()
        let dt = 1 / rate
        for i in 0..<n {
            var s = 0.0
            for k in 0..<voices.count {
                var v = voices[k]
                v.t += dt
                if v.t < 0 || v.t > v.dur { voices[k] = v; continue }
                let u = v.t / v.dur
                // a few milliseconds of attack so notes do not click
                let env = v.vol * pow(0.0001 / max(v.vol, 0.0002), u) * min(1, v.t / 0.008)
                let f = v.f2 > 0 ? v.f * pow(v.f2 / v.f, u) : v.f
                var x = 0.0
                if v.wave == 4 {
                    let white = Double.random(in: -1...1)
                    let fc = 2 * sin(PI * min(f, 6500) / rate)
                    v.low += fc * v.band
                    let high = white - v.low - v.q * v.band
                    v.band += fc * high
                    x = v.band * 1.6
                } else {
                    v.phase += f * dt
                    if v.phase >= 1 { v.phase -= 1 }
                    let p = v.phase
                    switch v.wave {
                    case 0: x = sin(2 * PI * p)
                    case 1: x = 4 * abs(p - 0.5) - 1
                    case 2: x = p < 0.5 ? 0.6 : -0.6
                    case 5: x = sin(2 * PI * p) * 0.7 + sin(4 * PI * p) * 0.22 + sin(6 * PI * p) * 0.12
                    default: x = (2 * p - 1) * 0.7
                    }
                }
                s += x * env
                voices[k] = v
            }
            let wet = echo[echoI]
            echo[echoI] = s + wet * 0.34
            echoI += 1
            if echoI >= echo.count { echoI = 0 }
            out[i] = Float(max(-1, min(1, (s + wet * 0.3) * 1.4)))
        }
        voices.removeAll { $0.t > $0.dur }
        lock.unlock()
    }

    private func add(_ v: Voice) {
        if muted || !running { return }
        lock.lock()
        if voices.count < 44 { voices.append(v) }
        lock.unlock()
    }
    func tone(_ f: Double, _ d: Double, _ wave: Int, _ vol: Double, _ f2: Double = 0, _ delay: Double = 0) {
        if vol <= 0.0005 { return }
        add(Voice(wave: wave, f: f, f2: f2, dur: d, vol: vol, t: -delay))
    }
    func noise(_ d: Double, _ vol: Double, _ freq: Double, _ q: Double = 1) {
        if vol <= 0.0005 { return }
        var v = Voice(wave: 4, f: freq, f2: 0, dur: d, vol: vol, t: 0)
        v.q = 1 / max(0.5, q)
        add(v)
    }
    func click() { tone(520, 0.05, 0, 0.07, 480) }
    func coin() { tone(900, 0.12, 2, 0.04, 1500); tone(1350, 0.14, 2, 0.035, 2000, 0.07) }
    func good() { tone(523, 0.14, 1, 0.1); tone(784, 0.26, 1, 0.1, 0, 0.11) }
    func bad() { tone(220, 0.35, 3, 0.09, 80) }
    func boom() { noise(0.45, 0.5, 300, 1); tone(110, 0.3, 0, 0.28, 45) }
    func cannon() { noise(0.7, 0.6, 420, 1); tone(150, 0.55, 0, 0.45, 36) }
    func clang() { tone(2400, 0.25, 2, 0.045, 2300); tone(3350, 0.3, 1, 0.055, 3200); noise(0.06, 0.18, 5000, 2) }
    func whoosh() { noise(0.16, 0.12, 2400, 3) }
    func thud() { noise(0.1, 0.3, 380, 1.5); tone(130, 0.12, 3, 0.07, 70) }
    func splash() { noise(0.3, 0.14, 1800, 2); noise(0.2, 0.1, 600, 1.5) }
    func thunder() { noise(1.8, 0.6, 120, 1) }
    func gull() { tone(1500, 0.18, 0, 0.03, 1100); tone(1600, 0.22, 0, 0.03, 1050, 0.24) }

    // ---------- music: a small band per mood — melody, a harmony line, bass, held chords, a plucked accompaniment and drums
    private struct Track {
        let u: Double          // seconds per step
        let vol: Double
        let be: Int            // steps per bass beat
        let bass: [Int]        // one chord root per beat
        let scale: [Int]       // pitch classes of the key
        let lead: Int
        let drum: Int
        let a: [(Int, Int)]    // first tune (note, steps)
        let b: [(Int, Int)]    // second tune, played after the first has gone round twice
    }
    private static let dMinor = [2, 4, 5, 7, 9, 10, 0]
    private static let fMajor = [5, 7, 9, 10, 0, 2, 4]
    private static let gMajor = [7, 9, 11, 0, 2, 4, 6]
    private static let aMinor = [9, 11, 0, 2, 4, 5, 7]
    private let tracks: [String: Track] = [
        "sea": Track(u: 0.19, vol: 1, be: 3, bass: [38, 45, 38, 45, 41, 45, 38, 38], scale: Sound.dMinor, lead: 5, drum: 0,
                     a: [(62, 2), (65, 1), (69, 2), (69, 1), (67, 2), (65, 1), (64, 3), (62, 2), (65, 1), (69, 2), (72, 1), (69, 3), (0, 3), (72, 2), (69, 1), (67, 2), (65, 1), (64, 2), (67, 1), (69, 3), (65, 2), (64, 1), (62, 2), (60, 1), (62, 3), (0, 3)],
                     b: [(69, 3), (72, 2), (74, 1), (72, 3), (69, 3), (67, 2), (69, 1), (70, 2), (69, 1), (67, 3), (65, 3), (69, 3), (72, 2), (74, 1), (77, 3), (74, 3), (72, 2), (69, 1), (67, 2), (64, 1), (62, 6)]),
        "sea2": Track(u: 0.2, vol: 1, be: 4, bass: [41, 48, 46, 48, 41, 48, 36, 41], scale: Sound.fMajor, lead: 5, drum: 0,
                      a: [(65, 2), (69, 1), (72, 1), (77, 2), (76, 1), (74, 1), (72, 2), (69, 2), (70, 1), (72, 1), (74, 2), (72, 1), (69, 1), (67, 2), (0, 2), (65, 1), (69, 1), (72, 2), (74, 1), (72, 1), (70, 1), (69, 1), (67, 2), (64, 2), (65, 4), (0, 4)],
                      b: [(72, 4), (74, 2), (77, 2), (76, 3), (74, 1), (72, 4), (70, 2), (72, 2), (74, 2), (70, 2), (69, 4), (67, 2), (0, 2), (72, 4), (77, 2), (81, 2), (79, 3), (77, 1), (76, 2), (72, 2), (74, 2), (76, 2), (77, 6), (0, 2)]),
        "port": Track(u: 0.15, vol: 0.9, be: 3, bass: [43, 50, 43, 50, 48, 50, 43, 43], scale: Sound.gMajor, lead: 2, drum: 3,
                      a: [(67, 1), (71, 1), (74, 1), (79, 2), (78, 1), (76, 1), (74, 1), (71, 1), (74, 2), (71, 1), (72, 1), (76, 1), (72, 1), (69, 2), (66, 1), (69, 1), (74, 1), (72, 1), (71, 2), (67, 1), (67, 1), (71, 1), (74, 1), (79, 2), (78, 1), (76, 1), (79, 1), (76, 1), (74, 2), (71, 1), (72, 1), (71, 1), (69, 1), (66, 2), (69, 1), (67, 3), (0, 3)],
                      b: [(74, 2), (79, 1), (83, 2), (81, 1), (79, 1), (78, 1), (76, 1), (74, 2), (71, 1), (72, 2), (76, 1), (79, 2), (76, 1), (74, 3), (0, 3), (74, 2), (79, 1), (83, 2), (86, 1), (84, 1), (83, 1), (81, 1), (79, 2), (76, 1), (74, 1), (72, 1), (69, 1), (66, 2), (69, 1), (67, 3), (0, 3)]),
        "battle": Track(u: 0.16, vol: 0.8, be: 2, bass: [38, 38, 36, 36, 34, 34, 33, 33], scale: Sound.dMinor, lead: 3, drum: 2,
                        a: [(62, 1), (62, 1), (65, 1), (62, 1), (69, 2), (67, 1), (65, 1), (64, 1), (62, 1), (60, 2), (62, 1), (62, 1), (65, 1), (69, 1), (72, 2), (70, 1), (69, 1), (67, 1), (65, 1), (64, 2), (62, 1), (57, 1), (62, 2)],
                        b: [(74, 2), (72, 1), (70, 1), (69, 2), (67, 1), (65, 1), (67, 1), (69, 1), (70, 2), (69, 2), (74, 2), (77, 1), (76, 1), (74, 2), (72, 1), (70, 1), (69, 1), (67, 1), (65, 1), (64, 1), (62, 4)]),
        "night": Track(u: 0.3, vol: 0.85, be: 3, bass: [33, 40, 36, 40], scale: Sound.aMinor, lead: 0, drum: 0,
                       a: [(69, 2), (72, 1), (76, 3), (74, 2), (72, 1), (71, 3), (69, 2), (67, 1), (64, 3), (69, 3), (0, 3), (72, 2), (76, 1), (79, 3), (77, 2), (76, 1), (74, 3), (72, 2), (71, 1), (69, 3), (0, 3)],
                       b: [(76, 3), (79, 2), (81, 1), (79, 3), (76, 3), (74, 2), (76, 1), (77, 3), (76, 6), (72, 3), (74, 2), (76, 1), (74, 3), (71, 3), (69, 6)])
    ]
    private var mood = ""
    private var noteI = 0
    private var beat = 0
    private var nextT = 0.0
    private func hz(_ n: Int) -> Double { return 440 * pow(2, Double(n - 69) / 12) }
    /// The note `steps` scale degrees away from `n`, staying in the key.
    private func degree(_ n: Int, _ steps: Int, _ scale: [Int]) -> Int {
        var m = n, left = abs(steps)
        let dir = steps < 0 ? -1 : 1
        var guardN = 0
        while left > 0 && guardN < 40 {
            m += dir
            guardN += 1
            if scale.contains(((m % 12) + 12) % 12) { left -= 1 }
        }
        return m
    }
    /// Call every frame with the game clock and the mood to play.
    func music(_ now: Double, _ m: String) {
        if muted || !running { return }
        guard let tr = tracks[m] else { return }
        if m != mood { mood = m; noteI = 0; beat = 0; nextT = now + 0.5 }
        if now < nextT { return }
        // form: A A B A, with the harmony line joining on the repeats
        let la = tr.a.count, lb = tr.b.count
        let cycle = la * 3 + lb
        let at = noteI % cycle
        var nt = tr.a[0]
        var section = 0
        if at < la { nt = tr.a[at] } else if at < la * 2 { nt = tr.a[at - la]; section = 1 } else if at < la * 2 + lb { nt = tr.b[at - la * 2]; section = 2 } else { nt = tr.a[at - la * 2 - lb]; section = 3 }
        let dur = Double(nt.1) * tr.u
        let v = tr.vol
        if nt.0 > 0 {
            tone(hz(nt.0), dur * 1.15, tr.lead, 0.042 * v)
            tone(hz(nt.0) * 2.003, dur * 0.6, 0, 0.01 * v)
            if section == 1 || section == 3 {
                // a third below, in key
                tone(hz(degree(nt.0, -2, tr.scale)), dur * 1.1, 1, 0.022 * v)
            } else if section == 2 {
                // the second tune is doubled an octave down
                tone(hz(nt.0 - 12), dur * 1.1, 1, 0.02 * v)
            }
        }
        for b in beat..<(beat + nt.1) {
            let delay = Double(b - beat) * tr.u
            let bi = (b / tr.be) % tr.bass.count
            let root = tr.bass[bi]
            let third = degree(root, 2, tr.scale), fifth = degree(root, 4, tr.scale)
            let inBeat = b % tr.be
            if inBeat == 0 {
                tone(hz(root), tr.u * Double(tr.be) * 0.9, 0, 0.06 * v, 0, delay)
                // the chord held softly above the bass
                let hold = tr.u * Double(tr.be) * 1.6
                tone(hz(root + 12), hold, 0, 0.011 * v, 0, delay)
                tone(hz(third + 12), hold, 0, 0.011 * v, 0, delay)
                tone(hz(fifth + 12), hold, 0, 0.011 * v, 0, delay)
            } else {
                // plucked chord notes between the beats
                let pick = [fifth + 12, third + 24, root + 24][(b + bi) % 3]
                tone(hz(pick), tr.u * 0.9, 1, 0.017 * v, 0, delay)
                if tr.be >= 3 && inBeat == tr.be - 1 { tone(hz(fifth), tr.u * 0.8, 0, 0.03 * v, 0, delay) }
            }
            if tr.drum > 0 {
                if b % tr.drum == 0 { tone(90, 0.12, 0, 0.09 * v, 50, delay) }
                // a shaker on the off steps; a snare-like tap on every other beat
                if b % tr.drum != 0 { hat(0.035 * v, delay) }
                if b % (tr.drum * 2) == tr.drum { snare(0.06 * v, delay) }
            }
        }
        beat += nt.1
        noteI += 1
        nextT = (nextT < now - 1 ? now : nextT) + dur
    }
    private func hat(_ vol: Double, _ delay: Double) {
        var v = Voice(wave: 4, f: 6000, f2: 0, dur: 0.04, vol: vol, t: -delay)
        v.q = 0.5
        add(v)
    }
    private func snare(_ vol: Double, _ delay: Double) {
        var v = Voice(wave: 4, f: 1900, f2: 0, dur: 0.11, vol: vol, t: -delay)
        v.q = 0.7
        add(v)
    }
}
