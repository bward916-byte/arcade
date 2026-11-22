import AVFoundation
import Foundation

/// Sound effects made in code: short tones and bursts of filtered noise.
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
        try? session.setCategory(.ambient, options: [.mixWithOthers])
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

    func swing() { noise(0.09, 0.07, 1800, 2) }
    func hit(_ v: Double) { noise(0.08, 0.22 * v, 520, 1.5); tone(150, 0.1, 3, 0.06 * v, 70) }
    func bite() { noise(0.1, 0.16, 300, 1); tone(220, 0.12, 3, 0.05, 110) }
    func shot() { noise(0.04, 0.07, 2400, 2) }
    func blast() { noise(0.16, 0.22, 700, 1) }
    func boom() { noise(0.5, 0.4, 160, 0.8); tone(70, 0.5, 0, 0.2, 34) }
    func zap() { tone(1800, 0.12, 3, 0.05, 300); noise(0.08, 0.08, 4200, 3) }
    func power() { tone(220, 0.5, 3, 0.09, 880); tone(110, 0.6, 0, 0.12, 55); noise(0.3, 0.2, 900, 1) }
    func pick() { tone(660, 0.1, 1, 0.07); tone(990, 0.16, 1, 0.07, 0, 0.09) }
    func door() { noise(0.12, 0.18, 240, 1) }
    func heal() { tone(520, 0.12, 0, 0.06); tone(780, 0.2, 0, 0.06, 0, 0.1) }
    func drop() { tone(400, 0.5, 3, 0.07, 80); noise(0.25, 0.3, 200, 1) }
    func ding() { tone(1320, 0.5, 0, 0.07); tone(1760, 0.6, 0, 0.04, 0, 0.12) }
    func dead() { tone(196, 0.9, 3, 0.08, 60) }
    func stamp() { noise(0.1, 0.25, 300, 1); tone(90, 0.2, 0, 0.14, 50) }
}
