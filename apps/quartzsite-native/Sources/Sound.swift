import AVFoundation
import Foundation

/// All the sound, made in code: a picked desert guitar, wind, campfire crackle, coyotes, and small effects.
final class Sound {
    private struct Voice {
        var wave: Int        // 0 sine, 1 triangle, 2 square, 3 sawtooth, 4 noise, 5 plucked string
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
    /// A major pentatonic across two octaves: the open, dusty sound of a western guitar.
    private let SCALE: [Double] = [110, 123.5, 138.6, 164.8, 185, 220, 246.9, 277.2, 329.6, 370, 440]

    func start() {
        if running { return }
        let session = AVAudioSession.sharedInstance()
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
                // long noises (wind) swell in and out instead of striking
                if v.wave == 4 && v.dur > 1.5 { env = v.vol * sin(PI * u) }
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
                    case 5:
                        // a plucked string: bright at first, mellowing as it rings
                        let bright = max(0, 1 - u * 5)
                        x = sin(2 * PI * p) * 0.7 + sin(4 * PI * p) * 0.25 * (0.4 + bright) + sin(6 * PI * p) * 0.15 * bright
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
        if voices.count < 30 { voices.append(v) }
        lock.unlock()
    }
    func tone(_ f: Double, _ d: Double, _ wave: Int, _ vol: Double, _ f2: Double = 0, _ delay: Double = 0) {
        if vol <= 0.0005 { return }
        add(Voice(wave: wave, f: f, f2: f2, dur: d, vol: vol, t: -delay))
    }
    func noise(_ d: Double, _ vol: Double, _ freq: Double, _ q: Double = 1, _ delay: Double = 0) {
        if vol <= 0.0005 { return }
        var v = Voice(wave: 4, f: freq, f2: 0, dur: d, vol: vol, t: -delay)
        v.q = 1 / max(0.5, q)
        add(v)
    }

    // ---------- effects
    func tap() { tone(1400, 0.03, 0, 0.03) }
    /// The ring filling: a soft rising tick per quarter.
    func tick(_ step: Int) { tone(520 + Double(step) * 130, 0.05, 1, 0.035) }
    func done() { tone(SCALE[7] * 2, 0.35, 5, 0.06); tone(SCALE[9] * 2, 0.4, 5, 0.05, 0, 0.07) }
    func coin() { tone(1850, 0.06, 0, 0.05); tone(2470, 0.12, 0, 0.045, 0, 0.05) }
    func spend() { noise(0.05, 0.08, 3200, 3); tone(880, 0.08, 1, 0.03) }
    func refund() { tone(700, 0.08, 1, 0.04, 520); tone(520, 0.1, 1, 0.03, 0, 0.07) }
    func engine(_ big: Bool) { tone(big ? 55 : 80, 1.1, 3, 0.05, big ? 95 : 140); noise(1.0, 0.05, 300, 1) }
    func dawn() { for (i, k) in [5, 7, 8, 10].enumerated() { tone(SCALE[k] * 2, 0.9, 5, 0.04, 0, Double(i) * 0.14) } }
    func season() { for (i, k) in [10, 8, 7, 5, 3].enumerated() { tone(SCALE[k] * 2, 1.2, 5, 0.05, 0, Double(i) * 0.22) } }

    // ---------- the desert around you
    private var windT = 0.0
    private var crackleT = 0.0
    private var critterT = 0.0
    /// Called every frame. dark 0...1, fire is how close a campfire is (0 far, 1 right there), windy for dust days.
    private var rainT = 0.0
    func ambience(_ now: Double, _ dark: Double, _ fire: Double, _ windy: Bool, _ raining: Bool) {
        if muted || !running { return }
        if raining && now > rainT {
            rainT = now + 1.2
            noise(1.8, 0.05, 5200, 0.6)
            noise(1.8, 0.03, 1400, 0.8)
        }
        if now > windT {
            windT = now + (windy ? 1.6 : 3.5) + Double.random(in: 0..<2)
            noise(windy ? 3.2 : 2.6, windy ? 0.07 : 0.025, Double.random(in: 280..<620), 0.7)
        }
        if fire > 0.05 && now > crackleT {
            crackleT = now + Double.random(in: 0.05..<0.25)
            noise(0.02, 0.06 * fire * (0.5 + dark * 0.5), Double.random(in: 1800..<4200), 3)
        }
        if now > critterT {
            critterT = now + Double.random(in: 9..<20)
            if dark > 0.6 {
                // coyotes yipping somewhere out past the camps
                let b = Double.random(in: 520..<640)
                tone(b, 0.6, 0, 0.022, b * 1.6)
                tone(b * 1.5, 0.35, 0, 0.016, b * 1.1, 0.55)
                tone(b * 1.3, 0.25, 0, 0.012, b * 1.7, 0.9)
            } else if dark < 0.2 {
                // a cactus wren or a quail calling
                for i in 0..<3 { tone(2600, 0.07, 0, 0.014, 2200, Double(i) * 0.12) }
            }
        }
    }

    // ---------- the sounds of a place: generators, crowds, traffic, engines, owls, running water
    private var genT = 0.0, crowdT = 0.0, carT = 0.0, motorT = 0.0, owlT = 0.0, roadT = 0.0, floodT = 0.0
    func places(_ now: Double, gen: Double, crowd: Double, traffic: Bool, motor: Double, owl: Bool, road: Bool, flood: Double) {
        if muted || !running { return }
        if gen > 0.05 && now > genT {
            genT = now + 0.5
            tone(58, 0.55, 2, 0.009 * gen)
            noise(0.55, 0.012 * gen, 220, 1.2)
        }
        if crowd > 0.05 && now > crowdT {
            crowdT = now + Double.random(in: 0.35..<0.8)
            noise(1.2, 0.018 * crowd, Double.random(in: 450..<1100), 2.2)
            if Double.random(in: 0..<1) < 0.12 { tone(Double.random(in: 300..<420), 0.18, 0, 0.012 * crowd, 260) }
        }
        if traffic && now > carT {
            carT = now + Double.random(in: 5..<11)
            noise(1.8, 0.03, Double.random(in: 500..<900), 0.7)
            tone(70, 1.4, 3, 0.012, 55)
        }
        if motor > 0.05 && now > motorT {
            motorT = now + 0.18
            tone(70 + motor * 90, 0.22, 3, 0.012 + motor * 0.012, 72 + motor * 95)
        }
        if owl && now > owlT {
            owlT = now + Double.random(in: 12..<24)
            tone(330, 0.35, 0, 0.018, 300); tone(330, 0.25, 0, 0.014, 300, 0.45); tone(330, 0.5, 0, 0.016, 290, 0.8)
        }
        if road && now > roadT {
            roadT = now + 0.45
            noise(0.6, 0.028, 260, 0.9)
        }
        if flood > 0.05 && now > floodT {
            floodT = now + 0.4
            noise(0.7, 0.04 * flood, 900, 0.5)
        }
    }

    // ---------- music: a picked guitar, slow by day, slower at night, livelier on event days
    private var seqT = 0.0
    private var seqI = 0
    private var noteI = 5
    /// mode: 0 day, 1 dusk, 2 night, 3 an event is on.
    func music(_ now: Double, _ mode: Int) {
        if muted || !running || now < seqT { return }
        let step = [0.42, 0.55, 0.7, 0.3][max(0, min(3, mode))]
        seqT = (seqT < now - 1 ? now : seqT) + step
        seqI = (seqI + 1) % 16
        // the bass walks the root and fifth
        if seqI % 4 == 0 {
            let root = [0, 0, 3, 4][(seqI / 4) % 4]
            tone(SCALE[root] * 0.5, 1.4, 5, mode == 2 ? 0.03 : 0.045)
        }
        let chance = [0.55, 0.4, 0.25, 0.75][max(0, min(3, mode))]
        if Double.random(in: 0..<1) < chance {
            let moves = [-2, -1, -1, 1, 1, 2]
            noteI = max(3, min(SCALE.count - 1, noteI + moves[Int.random(in: 0..<6)]))
            tone(SCALE[noteI] * 2, mode == 2 ? 1.6 : 1.1, 5, mode == 2 ? 0.022 : 0.034)
            if mode == 3 && seqI % 2 == 0 { noise(0.03, 0.03, 4000, 2) }
        }
    }
}
