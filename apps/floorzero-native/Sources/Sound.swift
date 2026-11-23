import AVFoundation
import Foundation

/// All the game's audio, made in code: a stereo synth with a little room echo,
/// a step sequencer that scores each tower, and the sound effects.
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
        var pan = 0.0        // -1 left … 1 right
        var bus = 0          // 0 effects, 1 music, 2 drums, 3 ambience
        var shape = 0        // 0 struck (fast decay), 1 swelled (pad)
        var vib = 0.0
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
    var theme = 0            // which tower's score
    var musicOn = true
    /// Where the next effect sits: -1 left … 1 right, and how near (1) or far (0.2).
    var pan = 0.0
    var near = 1.0

    private var sampleNo = 0
    private var nextStep = 0
    private var stepIdx = 0
    private var lastLevel = 0
    private var duck = 1.0
    private var echoL: [Float] = Array(repeating: 0, count: 7411)
    private var echoR: [Float] = Array(repeating: 0, count: 8101)
    private var echoL2: [Float] = Array(repeating: 0, count: 4801)
    private var echoR2: [Float] = Array(repeating: 0, count: 5303)
    private var iL = 0, iR = 0, iL2 = 0, iR2 = 0

    // ---------- the scores
    private struct Score {
        let bpm: Double
        let swing: Double
        let roots: [Double]
        let chords: [[Double]]
        let bass: [Int]       // sixteen steps, semitones above the root; 99 is a rest
        let lead: [Int]       // sixteen steps, index into the chord (0-3), 9 is a rest
    }
    private static let am: [Double] = [220, 261.63, 329.63, 440]
    private static let fM: [Double] = [174.61, 220, 261.63, 349.23]
    private static let gM: [Double] = [196, 246.94, 293.66, 392]
    private static let dm: [Double] = [146.83, 174.61, 220, 293.66]
    private static let em: [Double] = [164.81, 196, 246.94, 329.63]
    private static let bb: [Double] = [116.54, 146.83, 174.61, 233.08]
    private static let cM: [Double] = [130.81, 164.81, 196, 261.63]
    private static let gm: [Double] = [98, 116.54, 146.83, 196]
    private static let aM: [Double] = [110, 138.59, 164.81, 220]
    private static let dM: [Double] = [146.83, 185, 220, 293.66]
    private static let a2: [Double] = [110, 130.81, 164.81, 220]
    private static let bM: [Double] = [123.47, 155.56, 185, 246.94]
    private let scores: [Score] = [
        // Cole: driving, heavy, A minor
        Score(bpm: 124, swing: 0, roots: [55, 55, 43.65, 49, 55, 55, 36.71, 41.2],
              chords: [Sound.am, Sound.am, Sound.fM, Sound.gM, Sound.am, Sound.am, Sound.dm, Sound.em],
              bass: [0, 99, 0, 99, 0, 99, 12, 99, 0, 99, 0, 7, 99, 0, 12, 99],
              lead: [0, 9, 2, 9, 3, 9, 2, 1, 0, 9, 2, 9, 3, 2, 9, 1]),
        // Maya: tense and pulsing, D minor
        Score(bpm: 116, swing: 0, roots: [73.42, 73.42, 58.27, 65.41, 73.42, 73.42, 49, 55],
              chords: [Sound.dm, Sound.dm, Sound.bb, Sound.cM, Sound.dm, Sound.dm, Sound.gm, Sound.aM],
              bass: [0, 99, 0, 99, 0, 99, 0, 99, 0, 99, 0, 99, 0, 99, 12, 12],
              lead: [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 3, 2, 1, 0]),
        // Jo: swung and swaggering, E minor
        Score(bpm: 110, swing: 0.16, roots: [41.2, 41.2, 65.41, 73.42, 41.2, 41.2, 55, 61.74],
              chords: [Sound.em, Sound.em, Sound.cM, Sound.dM, Sound.em, Sound.em, Sound.a2, Sound.bM],
              bass: [0, 99, 99, 0, 99, 12, 99, 0, 99, 0, 10, 99, 12, 99, 7, 99],
              lead: [3, 9, 9, 2, 9, 3, 9, 9, 1, 9, 2, 9, 3, 9, 2, 0])
    ]

    func start() {
        if running { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        let src = AVAudioSourceNode(format: fmt) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let list = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let n = Int(frameCount)
            guard let me = self, list.count > 0, let rawL = list[0].mData else { return noErr }
            let outL = rawL.assumingMemoryBound(to: Float.self)
            var outR = outL
            if list.count > 1, let rawR = list[1].mData { outR = rawR.assumingMemoryBound(to: Float.self) }
            me.render(outL, outR, n, list.count > 1)
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

    private func render(_ outL: UnsafeMutablePointer<Float>, _ outR: UnsafeMutablePointer<Float>, _ n: Int, _ stereo: Bool) {
        lock.lock()
        let dt = 1 / rate
        let sc = scores[max(0, min(2, theme))]
        let bpm = sc.bpm + (intensity >= 2 ? 8 : 0)
        let base = rate * 60 / bpm / 4
        for i in 0..<n {
            sampleNo += 1
            if sampleNo >= nextStep {
                let odd = stepIdx % 2 == 1
                let len = base * (odd ? 1 - sc.swing : 1 + sc.swing)
                nextStep = sampleNo + Int(len)
                if musicOn && !muted { step(stepIdx, sc) }
                stepIdx += 1
            }
            duck += (1 - duck) * 0.00028
            var l = 0.0, r = 0.0, wet = 0.0
            for k in 0..<voices.count {
                var v = voices[k]
                v.t += dt
                if v.t < 0 || v.t > v.dur { voices[k] = v; continue }
                let u = v.t / v.dur
                var env = 0.0
                if v.shape == 1 {
                    env = v.vol * min(1, u / 0.25) * min(1, (1 - u) / 0.35)
                } else {
                    env = v.vol * pow(0.0001 / max(v.vol, 0.0002), u) * min(1, v.t / 0.004)
                }
                var f = v.f2 > 0 ? v.f * pow(v.f2 / v.f, u) : v.f
                if v.vib != 0 { f *= 1 + v.vib * sin(2 * PI * 5.5 * v.t) }
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
                var s = x * env
                if v.bus == 1 { s *= duck }
                let gl = v.pan <= 0 ? 1 : 1 - v.pan * 0.8
                let gr = v.pan >= 0 ? 1 : 1 + v.pan * 0.8
                l += s * gl
                r += s * gr
                if v.bus == 0 || v.bus == 3 { wet += s * 0.5 } else if v.bus == 2 { wet += s * 0.12 }
                voices[k] = v
            }
            // a short room echo, so nothing sounds like it is inside your head
            let dl = echoL[iL] + echoL2[iL2] * 0.7
            let dr = echoR[iR] + echoR2[iR2] * 0.7
            echoL[iL] = Float(wet) + dr * 0.33
            echoR[iR] = Float(wet) + dl * 0.33
            echoL2[iL2] = Float(wet) * 0.8 + dl * 0.2
            echoR2[iR2] = Float(wet) * 0.8 + dr * 0.2
            iL += 1; if iL >= echoL.count { iL = 0 }
            iR += 1; if iR >= echoR.count { iR = 0 }
            iL2 += 1; if iL2 >= echoL2.count { iL2 = 0 }
            iR2 += 1; if iR2 >= echoR2.count { iR2 = 0 }
            var ml = (l + Double(dl) * 0.3) * 1.25
            var mr = (r + Double(dr) * 0.3) * 1.25
            ml = ml / (1 + abs(ml) * 0.45)
            mr = mr / (1 + abs(mr) * 0.45)
            if stereo { outL[i] = Float(ml); outR[i] = Float(mr) } else { outL[i] = Float((ml + mr) * 0.5) }
        }
        voices.removeAll { $0.t > $0.dur }
        lock.unlock()
    }

    // ---------- one sixteenth note of the score (audio thread, lock held)
    private func mv(_ wave: Int, _ f: Double, _ d: Double, _ vol: Double, _ f2: Double = 0, q: Double = 1, bus: Int = 1, pan: Double = 0, shape: Int = 0, delay: Double = 0) {
        if voices.count >= 64 { return }
        var x = Voice(wave: wave, f: f, f2: f2, dur: d, vol: vol, t: -delay)
        x.q = 1 / max(0.5, q)
        x.bus = bus
        x.pan = pan
        x.shape = shape
        voices.append(x)
    }
    private func kick(_ vol: Double) {
        mv(0, 155, 0.24, vol, 42, bus: 2)
        mv(4, 3200, 0.012, vol * 0.35, 0, q: 1, bus: 2)
        duck = 0.5
    }
    private func snare(_ vol: Double) {
        mv(4, 1900, 0.17, vol, 0, q: 1.1, bus: 2)
        mv(1, 210, 0.09, vol * 0.5, 140, bus: 2)
        mv(4, 5200, 0.09, vol * 0.4, 0, q: 2, bus: 2)
    }
    private func hat(_ vol: Double, open: Bool, pan: Double) {
        mv(4, 6400, open ? 0.2 : 0.035, vol, 0, q: 3, bus: 2, pan: pan)
    }
    private func step(_ i: Int, _ sc: Score) {
        let lvl = intensity
        let s = i % 16
        let bar = (i / 16) % 8
        let root = sc.roots[bar]
        let ch = sc.chords[bar]
        // when the fight starts, or the boss arrives, say so
        if lvl != lastLevel {
            if lvl > lastLevel && lvl >= 2 {
                mv(4, 5200, 1.1, 0.12, 0, q: 0.7, bus: 2)
                mv(0, 70, 0.9, 0.3, 30, bus: 2)
                if lvl == 3 { for (k, n) in ch.enumerated() { mv(3, n, 0.9, 0.035, 0, pan: Double(k) * 0.4 - 0.6) } }
            }
            lastLevel = lvl
        }
        // a held chord under everything
        if s == 0 {
            let pv = lvl == 0 ? 0.03 : 0.02
            for (k, n) in ch.enumerated() { mv(k % 2 == 0 ? 0 : 1, n / 2, 60 / sc.bpm * 4.2, pv, 0, pan: Double(k) * 0.5 - 0.75, shape: 1) }
        }
        if lvl == 0 {
            if s == 0 { mv(1, root, 1.8, 0.07) }
            if s == 8 { mv(1, root * 1.5, 1.0, 0.03) }
            if s == 4 || s == 12 { mv(0, 110, 0.3, 0.1, 44, bus: 2) }
            if s == 14 && bar % 2 == 1 { mv(0, ch[2], 1.4, 0.03, 0, pan: 0.4) }
            return
        }
        // bass
        let b = sc.bass[s]
        if b != 99 {
            let f = root * pow(2, Double(b) / 12)
            mv(3, f, 0.2, lvl >= 2 ? 0.085 : 0.06)
            mv(0, f, 0.24, 0.09)
            if lvl >= 2 { mv(2, f * 2, 0.1, 0.018) }
        }
        // drums
        let fill = bar % 4 == 3 && s >= 12
        if lvl >= 2 {
            if s % 4 == 0 { kick(0.36) }
            if lvl == 3 && (s == 7 || s == 10) { kick(0.26) }
            if (s == 4 || s == 12) && !fill { snare(0.15) }
            if fill { snare(0.08 + Double(s - 12) * 0.03) }
            hat(s % 4 == 2 ? 0.05 : 0.028, open: s % 4 == 2 && lvl == 3, pan: s % 2 == 0 ? -0.4 : 0.4)
            if s == 0 && bar % 4 == 0 { mv(4, 5600, 0.9, 0.07, 0, q: 0.8, bus: 2) }
        } else {
            if s == 0 || s == 10 { kick(0.2) }
            if s == 4 || s == 12 { mv(4, 2400, 0.06, 0.05, 0, q: 2, bus: 2) }
            if s % 2 == 0 { hat(0.018, open: false, pan: s % 4 == 0 ? -0.3 : 0.3) }
        }
        // the tune
        let ld = sc.lead[s]
        if lvl >= 2 && ld != 9 {
            let n = ch[ld] * (lvl == 3 ? 2 : 1)
            mv(2, n, 0.15, 0.02, 0, pan: s % 2 == 0 ? -0.5 : 0.5)
            mv(1, n * 2, 0.12, 0.012, 0, pan: s % 2 == 0 ? 0.5 : -0.5, delay: 60 / sc.bpm / 4 * 0.75)
        } else if lvl == 1 && (s == 0 || s == 6 || s == 11) {
            mv(1, ch[(s / 5) % 4], 0.6, 0.028, 0, pan: s == 6 ? 0.5 : -0.5)
        }
        if lvl == 3 && (s == 0 || s == 3 || s == 6 || s == 10 || s == 13) { mv(3, ch[(s / 3) % 4] * 2, 0.3, 0.03, 0, pan: 0.2) }
        // rising noise into the next phrase
        if lvl >= 2 && bar % 4 == 3 && s == 8 { mv(4, 900, 60 / sc.bpm * 2, 0.07, 5600, q: 2.5, bus: 1, shape: 1) }
        // stabs on the turnaround
        if lvl >= 2 && bar % 4 == 3 && (s == 8 || s == 11 || s == 14) { for (k, n) in ch.enumerated() { mv(3, n, 0.2, 0.016, 0, pan: Double(k) * 0.4 - 0.6) } }
    }

    // ---------- playing effects
    private func add(_ v: Voice) {
        if muted || !running { return }
        lock.lock()
        if voices.count < 52 { voices.append(v) }
        lock.unlock()
    }
    func tone(_ f: Double, _ d: Double, _ wave: Int, _ vol: Double, _ f2: Double = 0, _ delay: Double = 0, vib: Double = 0, shape: Int = 0, bus: Int = 0) {
        if vol <= 0.0005 { return }
        var v = Voice(wave: wave, f: f, f2: f2, dur: d, vol: vol * near, t: -delay)
        v.pan = pan
        v.vib = vib
        v.shape = shape
        v.bus = bus
        add(v)
    }
    func noise(_ d: Double, _ vol: Double, _ freq: Double, _ q: Double = 1, _ delay: Double = 0, sweep: Double = 0, shape: Int = 0, bus: Int = 0) {
        if vol <= 0.0005 { return }
        var v = Voice(wave: 4, f: freq, f2: sweep, dur: d, vol: vol * near, t: -delay)
        v.q = 1 / max(0.5, q)
        v.pan = pan
        v.shape = shape
        v.bus = bus
        add(v)
    }
    /// Place the next effects at a spot `dx` game-pixels to the right of the listener.
    func at(_ dx: Double) {
        pan = max(-1, min(1, dx / 520))
        near = max(0.25, 1 - abs(dx) / 1500)
    }
    func here() { pan = 0; near = 1 }

    // combat
    func swing() { noise(0.12, 0.09, 900, 2, 0, sweep: 3600); tone(420, 0.1, 0, 0.02, 160) }
    func whoosh() { noise(0.28, 0.14, 500, 1.5, 0, sweep: 4200); tone(240, 0.26, 0, 0.04, 90) }
    func hit(_ v: Double) { noise(0.07, 0.24 * v, 480, 1.5); tone(170, 0.12, 0, 0.16 * v, 60); noise(0.03, 0.1 * v, 3200, 2); tone(90, 0.1, 3, 0.05 * v, 50); noise(0.1, 0.07 * v, 900, 1, 0.02) }
    func bigHit() { noise(0.16, 0.32, 300, 1); tone(120, 0.34, 0, 0.3, 34); noise(0.05, 0.16, 4200, 2); tone(60, 0.4, 0, 0.2, 30, 0.03); crack() }
    func crack() { noise(0.025, 0.2, 2600, 3); noise(0.02, 0.14, 4200, 3, 0.03); tone(700, 0.04, 2, 0.04, 300) }
    func squelch() { noise(0.2, 0.2, 420, 1.2, 0, sweep: 160); tone(140, 0.16, 0, 0.1, 60); noise(0.12, 0.08, 1500, 2, 0.05, sweep: 500); noise(0.3, 0.05, 700, 1, 0.1) }
    func bite() { noise(0.1, 0.16, 300, 1); tone(220, 0.12, 3, 0.05, 110); tone(160, 0.16, 0, 0.08, 70); noise(0.04, 0.1, 2800, 3, 0.04) }
    func shot() { noise(0.035, 0.1, 2600, 2); tone(900, 0.04, 2, 0.02, 200); tone(140, 0.07, 0, 0.07, 60); noise(0.18, 0.02, 1400, 1, 0.03) }
    func blast() { noise(0.2, 0.28, 620, 1); tone(140, 0.2, 0, 0.18, 46); noise(0.4, 0.06, 2200, 1.5); tone(60, 0.3, 0, 0.14, 32) }
    func boom() {
        noise(0.03, 0.3, 3600, 1)
        noise(0.7, 0.44, 150, 0.8); tone(78, 0.8, 0, 0.34, 26); tone(48, 1.1, 0, 0.22, 24, 0.05)
        noise(1.3, 0.09, 900, 1, 0.05, sweep: 200); tone(210, 0.12, 3, 0.06, 60)
        for i in 0..<4 { noise(0.05, 0.05, 3000 + Double(i) * 600, 3, 0.25 + Double(i) * 0.13) }
    }
    func zap() { tone(1800, 0.12, 3, 0.05, 300); noise(0.08, 0.08, 4200, 3); tone(2600, 0.2, 2, 0.02, 700, 0.05); noise(0.25, 0.03, 5200, 3, 0.05) }
    func clang() { tone(1400, 0.3, 1, 0.08, 900); tone(2130, 0.4, 0, 0.04); noise(0.05, 0.16, 5000, 3) }
    func glass() { for i in 0..<6 { tone(2400 + Double(i) * 430, 0.12, 0, 0.03, 0, Double(i) * 0.03); noise(0.05, 0.08, 5200, 3, Double(i) * 0.035) } }
    func power() {
        here()
        noise(0.5, 0.16, 400, 2, 0, sweep: 6000, shape: 1)
        tone(160, 0.45, 3, 0.09, 1280); tone(110, 0.8, 0, 0.2, 40); tone(55, 1.0, 0, 0.24, 28, 0.42)
        noise(0.4, 0.24, 900, 1, 0.42)
        tone(440, 0.5, 1, 0.07, 0, 0.12); tone(659.3, 0.5, 1, 0.07, 0, 0.2); tone(880, 0.7, 1, 0.08, 0, 0.28); tone(1318.5, 0.8, 0, 0.04, 0, 0.36)
    }
    // creatures
    func groan(_ pitch: Double) { tone(95 * pitch, 0.9, 3, 0.055, 62 * pitch, 0, vib: 0.05); tone(190 * pitch, 0.7, 0, 0.03, 118 * pitch, 0, vib: 0.07); noise(0.7, 0.035, 520, 2, 0, shape: 1) }
    func moan() { tone(130, 1.8, 3, 0.02, 92, 0, vib: 0.06, shape: 1, bus: 3); noise(1.6, 0.012, 420, 2, 0, shape: 1, bus: 3) }
    func bark() { tone(520, 0.08, 2, 0.07, 230); noise(0.07, 0.11, 900, 1.5); tone(480, 0.09, 2, 0.07, 210, 0.13); noise(0.07, 0.11, 900, 1.5, 0.13); tone(110, 0.3, 3, 0.03, 80, 0.2, vib: 0.2) }
    func squeak() { tone(2600, 0.06, 0, 0.03, 3400); tone(3000, 0.05, 0, 0.02, 2200, 0.07) }
    func caw() { tone(900, 0.16, 3, 0.05, 620, 0, vib: 0.12); noise(0.16, 0.06, 2200, 2); tone(860, 0.14, 3, 0.04, 560, 0.2, vib: 0.12) }
    func wheel() { tone(1900, 0.09, 0, 0.02, 2300); tone(2100, 0.07, 0, 0.015, 1700, 0.1); noise(0.2, 0.03, 300, 1) }
    func scream() { tone(900, 1.0, 3, 0.1, 1900, 0, vib: 0.04); tone(1350, 1.0, 2, 0.045, 2600, 0, vib: 0.05); noise(1.0, 0.13, 3000, 2); tone(1790, 0.9, 0, 0.03, 3300) }
    func roar() { tone(80, 1.4, 3, 0.16, 44, 0, vib: 0.08); tone(120, 1.2, 2, 0.06, 60, 0, vib: 0.08); noise(1.3, 0.16, 380, 1); tone(40, 1.4, 0, 0.2, 30) }
    func heart() { here(); tone(62, 0.16, 0, 0.32, 40); tone(58, 0.2, 0, 0.26, 36, 0.2) }
    // the building
    func foot(_ alt: Bool) { noise(0.045, 0.045, alt ? 260 : 320, 1.2); tone(alt ? 90 : 105, 0.05, 0, 0.03, 60) }
    func crackle() { noise(0.02, 0.07, 3600, 3); if Int.random(in: 0..<4) == 0 { noise(0.3, 0.03, 500, 1, 0, shape: 1) } }
    func fireWhoosh() { noise(0.6, 0.12, 300, 1, 0, sweep: 1800, shape: 1); tone(90, 0.5, 0, 0.08, 50) }
    func door() { noise(0.14, 0.22, 240, 1); tone(110, 0.16, 0, 0.14, 50); noise(0.05, 0.1, 2200, 2); for i in 0..<3 { noise(0.03, 0.05, 1800, 3, 0.1 + Double(i) * 0.06) } }
    func drop() { tone(400, 0.5, 3, 0.07, 80); noise(0.5, 0.1, 400, 1, 0, sweep: 2400, shape: 1); noise(0.25, 0.34, 200, 1, 0.5); tone(60, 0.5, 0, 0.3, 30, 0.5) }
    func ding() { here(); tone(1320, 0.7, 0, 0.07); tone(1760, 0.9, 0, 0.04, 0, 0.12); tone(2640, 0.5, 0, 0.015, 0, 0.12) }
    func liftHum() { tone(58, 1.5, 3, 0.03, 44, 0, vib: 0.02, shape: 1, bus: 3); noise(1.5, 0.03, 200, 1, 0, shape: 1, bus: 3) }
    func stairs() { for i in 0..<4 { noise(0.05, 0.07, 280, 1.2, Double(i) * 0.1); tone(100, 0.05, 0, 0.04, 60, Double(i) * 0.1) } }
    func wind() { noise(3.0, 0.03, 300, 1.5, 0, sweep: 700, shape: 1, bus: 3) }
    func hum() { tone(60, 3.0, 0, 0.012, 0, 0, shape: 1, bus: 3); tone(120, 3.0, 0, 0.006, 0, 0, shape: 1, bus: 3); noise(3.0, 0.008, 2000, 1, 0, shape: 1, bus: 3) }
    func siren() { tone(620, 2.6, 0, 0.012, 900, 0, vib: 0.0, shape: 1, bus: 3); tone(900, 2.6, 0, 0.012, 620, 2.4, shape: 1, bus: 3) }
    func alarm() { tone(880, 0.22, 2, 0.02, 0, 0, bus: 3); tone(660, 0.22, 2, 0.02, 0, 0.3, bus: 3) }
    func creak() { tone(180, 0.7, 3, 0.012, 120, 0, vib: 0.2, shape: 1, bus: 3) }
    func drip() { tone(1500, 0.05, 0, 0.012, 2600, 0, bus: 3); tone(1100, 0.06, 0, 0.008, 1900, 0.18, bus: 3) }
    // everything else
    func pick() { here(); tone(523.3, 0.12, 1, 0.07); tone(659.3, 0.12, 1, 0.07, 0, 0.09); tone(784, 0.14, 1, 0.07, 0, 0.18); tone(1046.5, 0.5, 1, 0.08, 0, 0.27); tone(1568, 0.6, 0, 0.03, 0, 0.27); noise(0.3, 0.04, 5200, 3, 0.27) }
    func heal() { here(); tone(520, 0.12, 0, 0.06); tone(780, 0.2, 0, 0.06, 0, 0.1); tone(1040, 0.3, 0, 0.04, 0, 0.2) }
    func ui() { here(); tone(700, 0.05, 1, 0.05); noise(0.02, 0.04, 3000, 2) }
    func dead() { here(); tone(196, 1.2, 3, 0.09, 55, 0, vib: 0.03); tone(98, 1.4, 0, 0.2, 40); noise(0.3, 0.2, 300, 1); tone(147, 1.0, 1, 0.05, 49, 0.2) }
    func stamp() { here(); noise(0.1, 0.27, 300, 1); tone(90, 0.24, 0, 0.18, 46); noise(0.03, 0.12, 3600, 2); tone(45, 0.5, 0, 0.14, 30) }
    func streak(_ n: Int) { here(); let b = n >= 20 ? 880.0 : (n >= 10 ? 740.0 : 587.3); tone(b, 0.1, 2, 0.05); tone(b * 1.5, 0.3, 2, 0.05, 0, 0.09); noise(0.2, 0.05, 5000, 3, 0.09) }
    func win() { here(); for (i, f) in [392.0, 523.3, 659.3, 784.0, 1046.5].enumerated() { tone(f, 0.5, 1, 0.08, 0, Double(i) * 0.12); tone(f * 2, 0.4, 0, 0.02, 0, Double(i) * 0.12) }; tone(98, 1.4, 0, 0.18, 0, 0.1); noise(1.0, 0.05, 5200, 2, 0.5) }
}
