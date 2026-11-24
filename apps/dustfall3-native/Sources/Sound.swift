import AVFoundation
import Foundation

/// Dustfall III's sound: short tones and bursts of filtered noise, made in code, as in the web version.
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
    private let SCALE: [Double] = [110, 130.8, 146.8, 164.8, 196, 220, 261.6, 293.7, 329.6, 392, 440]

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
    private func run(_ notes: [Int], _ d: Double, _ wave: Int, _ vol: Double, _ gap: Double, _ lead: Double = 0) {
        for i in 0..<notes.count { tone(SCALE[notes[i]] * 2, d, wave, vol, 0, lead + Double(i) * gap) }
    }

    func toss() { tone(520, 0.07, 1, 0.05, 780) }
    func pick() { tone(1250, 0.08, 0, 0.06, 1750) }
    func slot() { tone(900, 0.05, 2, 0.025, 1300) }
    func hammer(_ v: Double) { noise(0.06, 0.16 * v, 700, 2); tone(190, 0.05, 2, 0.03 * v) }
    func empty() { tone(170, 0.12, 2, 0.04, 120) }
    func recruit() { run([0, 2, 4, 5], 0.16, 1, 0.06, 0.08) }
    func fanfare() { run([2, 4, 5, 7, 9], 0.3, 1, 0.07, 0.11) }
    func gun(_ v: Double) { noise(0.16, 0.5 * v, 1200, 1); tone(160, 0.12, 3, 0.09 * v, 60) }
    func click() { tone(1400, 0.03, 2, 0.03) }
    func reload() { tone(700, 0.04, 2, 0.03); tone(900, 0.04, 2, 0.03, 0, 0.12) }
    func hit(_ v: Double) { noise(0.08, 0.2 * v, 500, 1.5); tone(140, 0.1, 3, 0.05 * v, 70) }
    func sting() { tone(110, 1.3, 3, 0.07, 104); tone(165, 1.3, 3, 0.04, 156) }
    func dawn() { run([4, 5, 7, 5, 9], 0.34, 0, 0.05, 0.2, 0.5) }
    func rob() { tone(300, 0.3, 3, 0.07, 90); noise(0.2, 0.2, 900, 1) }
    func box() { noise(0.18, 0.2, 1500, 2); run([5, 7, 9], 0.12, 1, 0.05, 0.06) }
    func gate(_ v: Double) { noise(0.12, 0.25 * v, 220, 1) }
    func bell() { for d in [0.0, 0.6, 1.2] { tone(659, 1.2, 1, 0.13, 654, d); tone(1318, 0.8, 0, 0.05, 0, d) } }
    func hum(_ v: Double) { tone(150, 0.26, 0, 0.03 * v + 0.008, 176) }
    func thunder(_ v: Double) { noise(1.6, 0.5 * v, 110, 0.8); tone(60, 1.2, 3, 0.06 * v, 38) }
    func whistle() { tone(620, 0.9, 1, 0.07, 600); tone(830, 0.9, 1, 0.05, 800); tone(620, 0.5, 1, 0.06, 590, 1.0); tone(830, 0.5, 1, 0.04, 790, 1.0) }
    func chuff(_ v: Double) { noise(0.12, 0.22 * v, 420, 1) }
    func hoof(_ v: Double) { noise(0.035, 0.07 * v, 320, 1.2) }

    // ---------- music: one small band, a different pattern for day, dusk, night and a raid
    private var seqT = 0.0
    private var seqI = 0
    private var noteI = 4
    private let patterns: [(Double, [Character], Double)] = [
        (0.24, Array("D..t..D.t...D.t."), 0.36), (0.32, Array("D.....t...D....."), 0.28),
        (0.44, Array("........D......."), 0.14), (0.16, Array("D.DtD.t.D.DtDtt."), 0.32)
    ]
    /// mode: 0 day, 1 dusk, 2 night, 3 raid.
    func music(_ now: Double, _ mode: Int) {
        if muted || !running || now < seqT { return }
        let m = patterns[max(0, min(3, mode))]
        seqT = (seqT < now - 1 ? now : seqT) + m.0
        seqI = (seqI + 1) % 16
        let ch = m.1[seqI]
        let raid = mode == 3
        if ch == "D" { tone(raid ? 70 : 92, 0.15, 0, 0.09, raid ? 44 : 56) } else if ch == "t" { noise(0.03, 0.04, 3000, 2) }
        if seqI == 0 {
            if raid { tone(55, 2.3, 3, 0.028); tone(58.3, 2.3, 3, 0.014) } else if mode == 2 { tone(55, 3, 0, 0.03) } else if mode == 1 { tone(55, 2.6, 0, 0.035) }
        }
        if Double.random(in: 0..<1) < m.2 && (!raid || seqI % 2 == 0) {
            let steps = [-2, -1, -1, 1, 1, 2]
            noteI = max(raid ? 0 : 1, min(raid ? 5 : SCALE.count - 1, noteI + steps[Int.random(in: 0..<6)]))
            let f = SCALE[noteI]
            switch mode {
            case 0: tone(f * 2, 0.42, 1, 0.035); tone(f * 4.006, 0.2, 0, 0.01)
            case 1: tone(f * 2, 1.2, 0, 0.03, f * 2.01)
            case 2: tone(f * 2, 1.5, 0, 0.02, f * 2.004)
            default: tone(f, 0.22, 3, 0.03); tone(f * 0.5, 0.22, 2, 0.012)
            }
        }
    }
}
