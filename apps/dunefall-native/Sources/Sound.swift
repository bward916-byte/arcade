import AVFoundation
import Foundation

/// The web version's sound effects: short tones and bursts of filtered noise, made in code.
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
    private let HIJAZ: [Double] = [146.8, 155.6, 185, 196, 220, 233.1, 261.6, 293.7, 311.1, 370, 392]

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
        for i in 0..<notes.count { tone(HIJAZ[notes[i]] * 2, d, wave, vol, 0, lead + Double(i) * gap) }
    }

    func toss() { tone(520, 0.07, 1, 0.05, 780) }
    func pick() { tone(1250, 0.08, 0, 0.06, 1750) }
    func slot() { tone(900, 0.05, 2, 0.025, 1300) }
    func clink(_ v: Double) { tone(2100, 0.04, 1, 0.03 * v) }
    func hammer(_ v: Double) { noise(0.06, 0.16 * v, 700, 2); tone(190, 0.05, 2, 0.03 * v) }
    func empty() { tone(170, 0.12, 2, 0.04, 120) }
    func recruit() { run([0, 2, 4, 7], 0.16, 1, 0.06, 0.08) }
    func fanfare() { run([3, 4, 7, 9, 10], 0.3, 1, 0.07, 0.11) }
    func arrow(_ v: Double) { noise(0.12, 0.12 * v, 2600, 3) }
    func hit(_ v: Double) { noise(0.08, 0.2 * v, 500, 1.5); tone(140, 0.1, 3, 0.05 * v, 70) }
    func horn() { tone(110, 1.3, 3, 0.07, 104); tone(165, 1.3, 3, 0.04, 156) }
    func dawn() { run([4, 7, 9, 7, 10], 0.34, 0, 0.05, 0.2, 0.5) }
    func rob() { tone(300, 0.3, 3, 0.07, 90); noise(0.2, 0.2, 900, 1) }
    func urn() { noise(0.18, 0.2, 1500, 2); run([7, 9, 10], 0.12, 1, 0.05, 0.06) }
    func gate(_ v: Double) { noise(0.12, 0.25 * v, 220, 1) }
    func gong() { tone(98, 2.2, 0, 0.12); tone(147.5, 2, 0, 0.06); tone(246, 1.2, 1, 0.03) }
}
