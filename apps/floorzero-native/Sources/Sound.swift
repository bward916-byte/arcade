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
    /// Music: 0 quiet (title, menus), 1 exploring, 2 fighting, 3 boss or power move.
    var intensity = 0
    var musicOn = true
    private var sampleNo = 0
    private var nextStep = 0
    private var stepIdx = 0
    private let bassRoots: [Double] = [55.0, 55.0, 43.65, 49.0, 55.0, 55.0, 36.71, 41.2]
    private let chords: [[Double]] = [[220, 261.63, 329.63, 440], [220, 261.63, 329.63, 440], [174.61, 220, 261.63, 349.23], [196, 246.94, 293.66, 392],
                                      [220, 261.63, 329.63, 440], [220, 261.63, 329.63, 440], [146.83, 174.61, 220, 293.66], [164.81, 207.65, 246.94, 329.63]]

    /// One sixteenth note of the score. Called from the audio thread with the lock held.
    private func step(_ i: Int) {
        let lvl = intensity
        let s = i % 16
        let bar = (i / 16) % 8
        let root = bassRoots[bar]
        let ch = chords[bar]
        func v(_ wave: Int, _ f: Double, _ d: Double, _ vol: Double, _ f2: Double = 0, q: Double = 1) {
            if voices.count >= 48 { return }
            var x = Voice(wave: wave, f: f, f2: f2, dur: d, vol: vol, t: 0)
            x.q = 1 / max(0.5, q)
            voices.append(x)
        }
        if lvl == 0 {
            // a slow pad and a heartbeat of bass
            if s == 0 { for n in ch { v(0, n / 2, 2.4, 0.022) }; v(1, root, 1.6, 0.06) }
            if s == 8 { v(1, root, 0.8, 0.035) }
            if s == 12 && bar % 2 == 1 { v(0, ch[2], 1.2, 0.02) }
            return
        }
        // bass: eighth notes, an octave jump at the end of the bar
        if s % 2 == 0 {
            let up = s == 14 || (lvl >= 2 && s == 6)
            v(3, up ? root * 2 : root, 0.19, lvl >= 2 ? 0.075 : 0.055)
            v(0, root, 0.22, 0.06)
        }
        // drums
        if lvl >= 2 {
            if s % 4 == 0 || (lvl == 3 && s == 14) { v(0, 130, 0.2, 0.3, 42) }
            if s == 4 || s == 12 { v(4, 1900, 0.13, 0.11, 0, q: 1.2); v(1, 190, 0.08, 0.05) }
        } else if s == 0 || s == 10 { v(0, 110, 0.2, 0.16, 44) }
        if s % 2 == 1 || lvl == 3 { v(4, 6400, 0.035, lvl >= 2 ? 0.035 : 0.02, 0, q: 3) }
        if lvl >= 2 && s == 6 { v(4, 5200, 0.14, 0.03, 0, q: 2) }
        // arpeggio when it kicks off
        if lvl >= 2 {
            let order = [0, 2, 1, 3, 2, 3, 1, 2]
            if s % 2 == 0 || lvl == 3 {
                let n = ch[order[(s / (lvl == 3 ? 1 : 2)) % 8]]
                v(2, n * (lvl == 3 ? 2 : 1), 0.16, 0.022)
            }
        } else if s == 0 || s == 6 || s == 11 { v(1, ch[(s / 5) % 4], 0.5, 0.025) }
        // a lead line over the boss
        if lvl == 3 && (s == 0 || s == 3 || s == 6 || s == 10) { v(3, ch[(s / 3) % 4] * 2, 0.28, 0.03) }
        // stabs on the turnaround
        if lvl >= 2 && bar % 4 == 3 && (s == 8 || s == 11 || s == 14) { for n in ch { v(3, n, 0.2, 0.014) } }
    }

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
        let stepLen = Int(rate * 60 / (intensity >= 2 ? 126 : 104) / 4)
        for i in 0..<n {
            sampleNo += 1
            if sampleNo >= nextStep {
                nextStep = sampleNo + stepLen
                if musicOn && !muted { step(stepIdx) }
                stepIdx += 1
            }
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
        if voices.count < 40 { voices.append(v) }
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

    func swing() { noise(0.1, 0.08, 2400, 2); tone(520, 0.1, 0, 0.025, 180) }
    func hit(_ v: Double) { noise(0.07, 0.24 * v, 480, 1.5); tone(170, 0.12, 0, 0.14 * v, 60); noise(0.03, 0.1 * v, 3200, 2); tone(90, 0.1, 3, 0.05 * v, 50) }
    func bigHit() { noise(0.16, 0.3, 300, 1); tone(120, 0.3, 0, 0.24, 38); noise(0.05, 0.14, 4200, 2) }
    func bite() { noise(0.1, 0.16, 300, 1); tone(220, 0.12, 3, 0.05, 110); tone(160, 0.16, 0, 0.08, 70) }
    func shot() { noise(0.04, 0.08, 2600, 2); tone(900, 0.04, 2, 0.02, 200) }
    func blast() { noise(0.2, 0.26, 620, 1); tone(140, 0.18, 0, 0.14, 50); noise(0.3, 0.06, 2200, 1.5) }
    func boom() { noise(0.6, 0.42, 150, 0.8); tone(72, 0.6, 0, 0.26, 30); noise(0.9, 0.08, 900, 1); tone(210, 0.12, 3, 0.06, 60) }
    func zap() { tone(1800, 0.12, 3, 0.05, 300); noise(0.08, 0.08, 4200, 3); tone(2600, 0.2, 2, 0.02, 700, 0.05) }
    func power() { tone(160, 0.45, 3, 0.09, 1280); tone(110, 0.7, 0, 0.16, 48); noise(0.4, 0.2, 900, 1); tone(440, 0.5, 1, 0.07, 0, 0.12); tone(659.3, 0.5, 1, 0.07, 0, 0.2); tone(880, 0.7, 1, 0.08, 0, 0.28) }
    func pick() { tone(523.3, 0.12, 1, 0.07); tone(659.3, 0.12, 1, 0.07, 0, 0.09); tone(784, 0.14, 1, 0.07, 0, 0.18); tone(1046.5, 0.4, 1, 0.08, 0, 0.27); noise(0.2, 0.04, 5200, 3) }
    func groan(_ pitch: Double) { tone(95 * pitch, 0.7, 3, 0.05, 62 * pitch); tone(190 * pitch, 0.5, 0, 0.025, 120 * pitch); noise(0.5, 0.03, 500, 2) }
    func bark() { tone(520, 0.08, 2, 0.06, 230); noise(0.07, 0.1, 900, 1.5); tone(480, 0.09, 2, 0.06, 210, 0.13); noise(0.07, 0.1, 900, 1.5) }
    func squeak() { tone(2600, 0.06, 0, 0.03, 3400) }
    func heart() { tone(62, 0.16, 0, 0.3, 40); tone(58, 0.2, 0, 0.24, 36, 0.2) }
    func scream() { tone(900, 0.9, 3, 0.09, 1900); tone(1350, 0.9, 2, 0.04, 2600); noise(0.9, 0.12, 3000, 2) }
    func clang() { tone(1400, 0.2, 1, 0.08, 900); noise(0.05, 0.14, 5000, 3) }
    func crackle() { noise(0.02, 0.07, 3600, 3) }
    func roar() { tone(80, 1.3, 3, 0.14, 44); tone(120, 1.1, 2, 0.05, 60); noise(1.2, 0.14, 380, 1) }
    func win() { for (i, f) in [392.0, 523.3, 659.3, 784.0, 1046.5].enumerated() { tone(f, 0.5, 1, 0.08, 0, Double(i) * 0.12) }; tone(98, 1.4, 0, 0.16, 0, 0.1) }
    func door() { noise(0.12, 0.18, 240, 1) }
    func heal() { tone(520, 0.12, 0, 0.06); tone(780, 0.2, 0, 0.06, 0, 0.1) }
    func drop() { tone(400, 0.5, 3, 0.07, 80); noise(0.25, 0.3, 200, 1) }
    func ding() { tone(1320, 0.5, 0, 0.07); tone(1760, 0.6, 0, 0.04, 0, 0.12) }
    func dead() { tone(196, 0.9, 3, 0.08, 60) }
    func stamp() { noise(0.1, 0.25, 300, 1); tone(90, 0.2, 0, 0.14, 50) }
}
