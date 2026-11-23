import AVFoundation
import Foundation

/// Broadside's sound effects and music: short tones and bursts of filtered noise, made in code.
final class Sound {
    private struct Voice {
        var wave: Int        // 0 sine, 1 triangle, 2 square, 3 sawtooth, 4 noise
        var f: Double
        var f2: Double
        var dur: Double
        var vol: Double
        var t: Double        // negative while waiting out a delay
        var phase = 0.0
        var low = 0.0
        var band = 0.0
        var q = 1.0
        var atk = 0.0        // seconds to swell in; 0 is a plucked note
    }

    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var voices: [Voice] = []
    private let lock = NSLock()
    private let rate = 44100.0
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
                var env = v.vol * pow(0.0001 / max(v.vol, 0.0002), u)
                if v.atk > 0 { env = v.vol * min(1, v.t / v.atk) * (1 - u) * (1 - u) }
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
                    default: x = (2 * p - 1) * 0.7
                    }
                }
                s += x * env
                voices[k] = v
            }
            out[i] = Float(max(-1, min(1, s * 1.4)))
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

    /// A note that swells in and fades: pads, strings, the wash of the sea.
    func swell(_ f: Double, _ d: Double, _ wave: Int, _ vol: Double, _ atk: Double) {
        var v = Voice(wave: wave, f: f, f2: 0, dur: d, vol: vol, t: 0)
        v.atk = atk
        if wave == 4 { v.q = 1.2 }
        add(v)
    }

    // ---------- music: a small band in code. Each score has a chord per bar of six beats; over it play a bass,
    // a held pad, a plucked arpeggio, the melody with a soft double an octave down, and hand percussion.
    private struct Score {
        let u: Double
        let vol: Double
        let lead: Int
        let drum: Int        // 0 none, 1 shanty pulse, 2 war drums
        let chords: [(Int, [Int])]
        let mel: [(Int, Int)]
    }
    private static let Dm: (Int, [Int]) = (38, [62, 65, 69])
    private static let C: (Int, [Int]) = (36, [60, 64, 67])
    private static let F: (Int, [Int]) = (41, [60, 65, 69])
    private static let A: (Int, [Int]) = (33, [61, 64, 69])
    private static let Bb: (Int, [Int]) = (34, [58, 62, 65])
    private static let G: (Int, [Int]) = (43, [59, 62, 67])
    private static let Em: (Int, [Int]) = (40, [59, 64, 67])
    private static let D: (Int, [Int]) = (38, [57, 62, 66])
    private static let Am: (Int, [Int]) = (33, [57, 60, 64])
    private static let E: (Int, [Int]) = (40, [56, 59, 64])
    private let scores: [String: Score] = [
        // the title: a rolling shanty in D minor, two eight-bar phrases
        "title": Score(u: 0.2, vol: 1, lead: 1, drum: 1,
                       chords: [Dm, Dm, C, Dm, F, C, A, Dm, Bb, F, C, Dm, Bb, F, A, Dm],
                       mel: [(69, 2), (74, 1), (72, 2), (69, 1), (65, 2), (69, 1), (62, 3), (64, 2), (67, 1), (72, 2), (67, 1), (69, 3), (65, 2), (62, 1),
                             (65, 2), (69, 1), (72, 2), (77, 1), (76, 2), (72, 1), (67, 3), (69, 2), (65, 1), (64, 2), (61, 1), (62, 5), (0, 1),
                             (70, 2), (74, 1), (77, 3), (72, 2), (69, 1), (65, 3), (67, 2), (72, 1), (76, 2), (72, 1), (74, 3), (69, 3),
                             (70, 2), (74, 1), (77, 2), (74, 1), (72, 2), (77, 1), (81, 3), (79, 1), (76, 1), (73, 1), (76, 2), (69, 1), (74, 5), (0, 1)]),
        // the island by day: unhurried, in G
        "isle": Score(u: 0.27, vol: 0.8, lead: 1, drum: 0,
                      chords: [G, Em, C, D, Em, C, D, G],
                      mel: [(71, 2), (74, 1), (79, 3), (76, 3), (71, 2), (67, 1), (72, 2), (76, 1), (79, 2), (76, 1), (74, 4), (0, 2),
                            (76, 2), (79, 1), (83, 3), (79, 2), (76, 1), (72, 3), (74, 2), (78, 1), (81, 2), (78, 1), (79, 4), (0, 2)]),
        // night: slow and bare
        "night": Score(u: 0.36, vol: 0.75, lead: 0, drum: 0,
                       chords: [Am, F, C, E],
                       mel: [(69, 3), (72, 3), (77, 2), (76, 1), (72, 3), (67, 3), (72, 2), (76, 1), (71, 4), (0, 2)]),
        // a raid
        "raid": Score(u: 0.15, vol: 0.9, lead: 3, drum: 2,
                      chords: [Dm, Dm, Bb, A],
                      mel: [(62, 1), (62, 1), (65, 1), (69, 2), (65, 1), (62, 1), (62, 1), (65, 1), (70, 2), (69, 1),
                            (70, 1), (70, 1), (74, 1), (77, 2), (74, 1), (73, 2), (69, 1), (64, 3)])
    ]
    private var mood = ""
    private var unitI = 0
    private var melI = 0
    private var melWait = 0
    private var nextT = 0.0
    private var washT = 0.0
    private func hz(_ n: Int) -> Double { return 440 * pow(2, Double(n - 69) / 12) }
    /// Call every frame with the game clock and the mood to play.
    func music(_ now: Double, _ m: String) {
        if muted || !running { return }
        guard let sc = scores[m] else { return }
        if m != mood { mood = m; unitI = 0; melI = 0; melWait = 0; nextT = now + 0.4 }
        // the sea, breathing under everything
        if now > washT {
            washT = now + 3.2 + Double.random(in: 0...2.5)
            swell(500 + Double.random(in: 0...500), 3.4, 4, 0.05, 1.3)
        }
        if now < nextT { return }
        let u = sc.u, vol = sc.vol
        let beat = unitI % 6
        let chord = sc.chords[(unitI / 6) % sc.chords.count]
        if beat == 0 {
            tone(hz(chord.0), u * 5.4, 0, 0.07 * vol)
            tone(hz(chord.0 + 12), u * 3, 1, 0.018 * vol)
            for n in chord.1 { swell(hz(n), u * 6.4, 1, 0.017 * vol, u * 1.5) }
            swell(hz(chord.1[0] + 12) * 1.003, u * 6.4, 0, 0.01 * vol, u * 2)
        }
        if beat == 3 { tone(hz(chord.0 + 7), u * 2.6, 0, 0.045 * vol) }
        // plucked arpeggio, up and back through the chord
        let order = [0, 1, 2, 1, 2, 1]
        let an = chord.1[order[beat]] + 12
        tone(hz(an), u * 2.2, 1, (beat == 0 ? 0.026 : 0.019) * vol)
        // melody, doubled softly an octave down and a shade sharp for width
        if melWait <= 0 {
            let nt = sc.mel[melI % sc.mel.count]
            melI += 1
            melWait = nt.1
            if nt.0 > 0 {
                let d = Double(nt.1) * u
                tone(hz(nt.0), d * 1.25 + 0.1, sc.lead, 0.05 * vol)
                tone(hz(nt.0) * 1.004, d * 1.25 + 0.1, 1, 0.022 * vol)
                tone(hz(nt.0 - 12), d * 1.1, 0, 0.02 * vol)
                tone(hz(nt.0 + 12) * 1.002, d * 0.5, 0, 0.009 * vol)
                if nt.1 >= 3 { swell(hz(nt.0 - (chord.1.contains(nt.0 - 3) ? 3 : 4)), d, 1, 0.018 * vol, 0.12) }
            }
        }
        melWait -= 1
        // percussion
        if sc.drum == 1 {
            if beat == 0 { tone(95, 0.16, 0, 0.1 * vol, 52) }
            if beat == 3 { noise(0.07, 0.035 * vol, 3200, 2) }
            if beat == 2 || beat == 5 { noise(0.035, 0.016 * vol, 5200, 2) }
        } else if sc.drum == 2 {
            if beat % 3 == 0 { tone(80, 0.2, 0, 0.16 * vol, 44); noise(0.12, 0.05 * vol, 300, 1) }
            if beat == 2 || beat == 4 || beat == 5 { tone(120, 0.09, 0, 0.07 * vol, 70) }
        }
        unitI += 1
        nextT = (nextT < now - 1 ? now : nextT) + u
    }
}
