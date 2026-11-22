import AVFoundation
import Foundation

/// Far Horizon's sound effects and music: short tones and bursts of filtered noise, made in code.
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
                let env = v.vol * pow(0.0001 / max(v.vol, 0.0002), u)
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
        if voices.count < 28 { voices.append(v) }
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

    // ---------- music: the same step sequencer as the web version, one track per mood
    private struct Track {
        let u: Double
        let vol: Double
        let be: Int
        let bass: [Int]
        let wave: Int
        let drum: Int
        let notes: [(Int, Int)]
    }
    private let tracks: [String: Track] = [
        "sea": Track(u: 0.19, vol: 1, be: 3, bass: [38, 45, 38, 45, 41, 45, 38, 38], wave: 1, drum: 0,
                     notes: [(62, 2), (65, 1), (69, 2), (69, 1), (67, 2), (65, 1), (64, 3), (62, 2), (65, 1), (69, 2), (72, 1), (69, 3), (0, 3), (72, 2), (69, 1), (67, 2), (65, 1), (64, 2), (67, 1), (69, 3), (65, 2), (64, 1), (62, 2), (60, 1), (62, 3), (0, 3)]),
        "sea2": Track(u: 0.2, vol: 1, be: 4, bass: [41, 48, 46, 48, 41, 48, 36, 41], wave: 1, drum: 0,
                      notes: [(65, 2), (69, 1), (72, 1), (77, 2), (76, 1), (74, 1), (72, 2), (69, 2), (70, 1), (72, 1), (74, 2), (72, 1), (69, 1), (67, 2), (0, 2), (65, 1), (69, 1), (72, 2), (74, 1), (72, 1), (70, 1), (69, 1), (67, 2), (64, 2), (65, 4), (0, 4)]),
        "port": Track(u: 0.15, vol: 0.9, be: 3, bass: [43, 50, 43, 50, 48, 50, 43, 43], wave: 2, drum: 3,
                      notes: [(67, 1), (71, 1), (74, 1), (79, 2), (78, 1), (76, 1), (74, 1), (71, 1), (74, 2), (71, 1), (72, 1), (76, 1), (72, 1), (69, 2), (66, 1), (69, 1), (74, 1), (72, 1), (71, 2), (67, 1), (67, 1), (71, 1), (74, 1), (79, 2), (78, 1), (76, 1), (79, 1), (76, 1), (74, 2), (71, 1), (72, 1), (71, 1), (69, 1), (66, 2), (69, 1), (67, 3), (0, 3)]),
        "battle": Track(u: 0.16, vol: 0.8, be: 2, bass: [38, 38, 36, 36, 34, 34, 33, 33], wave: 3, drum: 2,
                        notes: [(62, 1), (62, 1), (65, 1), (62, 1), (69, 2), (67, 1), (65, 1), (64, 1), (62, 1), (60, 2), (62, 1), (62, 1), (65, 1), (69, 1), (72, 2), (70, 1), (69, 1), (67, 1), (65, 1), (64, 2), (62, 1), (57, 1), (62, 2)]),
        "night": Track(u: 0.3, vol: 0.85, be: 3, bass: [33, 40, 36, 40], wave: 0, drum: 0,
                       notes: [(69, 2), (72, 1), (76, 3), (74, 2), (72, 1), (71, 3), (69, 2), (67, 1), (64, 3), (69, 3), (0, 3), (72, 2), (76, 1), (79, 3), (77, 2), (76, 1), (74, 3), (72, 2), (71, 1), (69, 3), (0, 3)])
    ]
    private var mood = ""
    private var noteI = 0
    private var beat = 0
    private var nextT = 0.0
    private func hz(_ n: Int) -> Double { return 440 * pow(2, Double(n - 69) / 12) }
    /// Call every frame with the game clock and the mood to play.
    func music(_ now: Double, _ m: String) {
        if muted || !running { return }
        guard let tr = tracks[m] else { return }
        if m != mood { mood = m; noteI = 0; beat = 0; nextT = now + 0.5 }
        if now < nextT { return }
        let nt = tr.notes[noteI % tr.notes.count]
        let dur = Double(nt.1) * tr.u
        if nt.0 > 0 {
            tone(hz(nt.0), dur * 1.1, tr.wave, 0.045 * tr.vol)
            tone(hz(nt.0) * 2.003, dur * 0.6, 0, 0.012 * tr.vol)
        }
        for b in beat..<(beat + nt.1) {
            let delay = Double(b - beat) * tr.u
            if b % tr.be == 0 {
                let bn = tr.bass[(b / tr.be) % tr.bass.count]
                tone(hz(bn), tr.u * Double(tr.be) * 0.9, 0, 0.06 * tr.vol, 0, delay)
            }
            if tr.drum > 0 && b % tr.drum == 0 {
                tone(90, 0.12, 0, 0.09 * tr.vol, 50, delay)
            }
        }
        beat += nt.1
        noteI += 1
        nextT = (nextT < now - 1 ? now : nextT) + dur
    }
}
