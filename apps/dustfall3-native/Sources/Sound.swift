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
    private var echo = [Float](repeating: 0, count: 14553)
    private var echoI = 0
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
                    case 5:
                        // a plucked string: bright at the attack, mellowing as it rings
                        let cut = 0.03 + 0.55 * pow(1 - u, 4)
                        v.low += cut * ((2 * p - 1) - v.low)
                        x = v.low * 1.5
                    default: x = (2 * p - 1) * 0.7
                    }
                }
                s += x * env
                voices[k] = v
            }
            // a short echo, as off a canyon wall
            let back = Double(echo[echoI])
            echo[echoI] = Float(s + back * 0.3)
            echoI = (echoI + 1) % echo.count
            out[i] = Float(max(-1, min(1, (s + back * 0.22) * 1.4)))
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
    func whoosh() { noise(0.42, 0.09, 700, 0.5); noise(0.3, 0.06, 2200, 0.6) }
    func ding() { tone(1568, 0.25, 0, 0.09); tone(2093, 0.35, 0, 0.05, 0, 0.05) }
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

    // ---------- music: a written tune for each time of day, over a guitar and bass, four bars round and round
    private var seqT = 0.0
    private var seqI = 63
    private var lastMode = -1
    private var cycle = 0
    private func mf(_ m: Int) -> Double { return 440 * pow(2, Double(m - 69) / 12) }
    /// Each chord: the bass note, then three strings of the guitar.
    private let CH: [String: [Int]] = ["Am": [45, 57, 60, 64], "C": [48, 55, 60, 64], "G": [43, 55, 59, 62], "E": [40, 56, 59, 64], "F": [41, 57, 60, 65], "Dm": [38, 57, 62, 65]]
    private let PROG: [[String]] = [["Am", "C", "G", "E"], ["Am", "F", "C", "E"], ["Am", "Dm", "Am", "E"], ["Am", "Am", "F", "E"]]
    private let STEP: [Double] = [0.2, 0.3, 0.42, 0.15]
    /// The tunes, sixteen steps to the bar; 0 is a rest.
    private let TUNE: [[Int]] = [
        [69, 0, 0, 72, 0, 0, 76, 0, 74, 0, 72, 0, 69, 0, 0, 0,
         72, 0, 0, 76, 0, 0, 79, 0, 76, 0, 0, 0, 72, 0, 74, 0,
         74, 0, 0, 71, 0, 0, 67, 0, 71, 0, 74, 0, 79, 0, 0, 0,
         76, 0, 0, 0, 71, 0, 68, 0, 71, 0, 0, 0, 0, 0, 0, 0],
        [76, 0, 0, 0, 0, 0, 72, 0, 69, 0, 0, 0, 0, 0, 0, 0,
         72, 0, 0, 0, 0, 0, 69, 0, 65, 0, 0, 0, 0, 0, 0, 0,
         67, 0, 0, 0, 72, 0, 0, 0, 76, 0, 0, 0, 0, 0, 0, 0,
         71, 0, 0, 0, 0, 0, 68, 0, 64, 0, 0, 0, 0, 0, 0, 0],
        [],
        [57, 0, 60, 0, 64, 0, 60, 0, 57, 0, 60, 0, 64, 62, 60, 0,
         57, 0, 60, 0, 64, 0, 60, 0, 57, 0, 60, 0, 64, 67, 69, 0,
         53, 0, 57, 0, 60, 0, 57, 0, 53, 0, 57, 0, 60, 59, 57, 0,
         52, 0, 56, 0, 59, 0, 56, 0, 52, 0, 56, 0, 59, 62, 64, 0]
    ]
    /// Which town you are in. Each has its own key, and one of three day tunes.
    var town = 0
    private let KEY: [Int] = [0, -2, 3, -4, 5, 2, -5, -1]
    private let DAYPROG: [[String]] = [["Am", "C", "G", "E"], ["Am", "F", "C", "G"], ["Am", "G", "F", "E"]]
    private let DAYSTEP: [Double] = [0.2, 0.22, 0.185]
    private let DAYTUNE: [[Int]] = [
        [],
        [76, 0, 74, 0, 72, 0, 0, 0, 69, 0, 72, 0, 76, 0, 0, 0,
         77, 0, 0, 0, 72, 0, 69, 0, 72, 0, 0, 0, 0, 0, 0, 0,
         79, 0, 76, 0, 72, 0, 0, 0, 76, 0, 79, 0, 84, 0, 0, 0,
         83, 0, 0, 0, 79, 0, 74, 0, 71, 0, 0, 0, 0, 0, 0, 0],
        [81, 0, 0, 0, 76, 0, 0, 72, 0, 0, 76, 0, 81, 0, 0, 0,
         79, 0, 0, 0, 74, 0, 0, 71, 0, 0, 74, 0, 79, 0, 0, 0,
         77, 0, 0, 0, 72, 0, 0, 69, 0, 0, 72, 0, 77, 0, 76, 0,
         76, 0, 0, 0, 71, 0, 68, 0, 64, 0, 0, 0, 0, 0, 0, 0]
    ]
    /// How loud the saloon piano is from where the rider stands: 0 out of earshot, 1 at the door.
    var pianoVol = 0.0
    private var pianoT = 0.0
    private var pianoI = 0
    private let RAG: [Int] = [0, 0, 5, 0, 7, 7, 0, 0]
    private let RH: [Int] = [0, 7, 4, 7, 12, 7, 4, 7, 4, 7, 12, 7, 16, 12, 7, 4]
    /// A honky-tonk loop, as in the web game: stride bass under a rolling right hand.
    private func piano(_ now: Double) {
        if muted || !running || pianoVol <= 0.02 || now < pianoT { return }
        pianoT = (pianoT < now - 1 ? now : pianoT) + 0.19
        let i = pianoI
        pianoI += 1
        let st = i % 8, root = 48 + RAG[(i / 8) % 8]
        func pn(_ m: Int, _ d: Double, _ v: Double) {
            tone(mf(m), d + 0.12, 1, v * 0.1 * pianoVol)
            tone(mf(m) * 1.005, d, 2, v * 0.018 * pianoVol)
        }
        if st == 0 { pn(root - 12, 0.3, 0.5) }
        if st == 4 { pn(root - 5, 0.3, 0.45) }
        if st == 2 || st == 6 { pn(root + 4, 0.14, 0.25); pn(root + 7, 0.14, 0.25) }
        if Double.random(in: 0..<1) > 0.18 { pn(root + 12 + RH[i % 16], 0.16, 0.4) }
    }
    /// mode: 0 day, 1 dusk, 2 night, 3 raid.
    func music(_ now: Double, _ mode: Int) {
        piano(now)
        if pianoVol > 0.15 && mode != 3 { return }        // the far-off guitar gives way to the piano
        if muted || !running || now < seqT { return }
        let md = max(0, min(3, mode))
        if md != lastMode { lastMode = md; seqI = 63 }
        let key = KEY[abs(town) % KEY.count], var3 = abs(town) % 3
        seqT = (seqT < now - 1 ? now : seqT) + (md == 0 ? DAYSTEP[var3] : STEP[md])
        seqI = (seqI + 1) % 64
        if seqI == 0 { cycle += 1 }
        let st = seqI % 16, bar = seqI / 16
        let ch = (CH[md == 0 ? DAYPROG[var3][bar] : PROG[md][bar]] ?? [45, 57, 60, 64]).map { $0 + key }
        func strum(_ vol: Double, _ dur: Double) {
            for i in 1..<ch.count { tone(mf(ch[i]), dur, 5, vol, 0, Double(i - 1) * 0.018) }
        }
        switch md {
        case 0:
            // boom-chick: bass on one and three, the guitar answering, a brush on the off-beats
            if st == 0 { tone(mf(ch[0]), 0.5, 5, 0.1) } else if st == 8 { tone(mf(ch[0] + 7), 0.45, 5, 0.085) }
            if st == 4 || st == 12 { strum(0.045, 0.6) }
            if st == 14 && bar == 3 { strum(0.03, 0.4) }
            if st % 4 == 2 { noise(0.03, 0.02, 3200, 2) }
        case 1:
            // dusk: the chord picked out a string at a time
            if st == 0 { tone(mf(ch[0]), 1.6, 5, 0.09) }
            if st % 4 == 0 { tone(mf(ch[1 + (st / 4) % 3]), 1.1, 5, 0.04) }
            if st == 10 { tone(mf(ch[3]), 0.9, 5, 0.03) }
        case 2:
            // night: a low drone, a few picked notes, crickets
            if st == 0 { tone(mf(ch[0]), 3.4, 0, 0.035); tone(mf(ch[0]) * 1.5, 3.4, 0, 0.012) }
            if st == 4 || st == 9 || st == 13 { tone(mf(ch[1 + st % 3]), 1.6, 5, 0.028) }
            if st % 2 == 1 && Double.random(in: 0..<1) < 0.5 { noise(0.02, 0.012, 5200, 6) }
        default:
            // a raid: driving bass, a kick and a rattle, the guitar stabbing
            if st % 2 == 0 { tone(mf(ch[0] + (st % 4 == 2 ? 12 : 0)), 0.16, 3, 0.05) }
            if st % 4 == 0 { tone(72, 0.14, 0, 0.1, 44) }
            if st % 4 == 2 { noise(0.05, 0.05, 2600, 2) }
            if st % 8 == 6 { strum(0.03, 0.25) }
            if st == 0 && bar % 2 == 0 { tone(55, 2.3, 3, 0.02); tone(58.3, 2.3, 3, 0.01) }
        }
        // the tune comes in every other time round by day and at dusk, so the band gets a turn alone
        let tune = md == 0 && var3 > 0 ? DAYTUNE[var3] : TUNE[md]
        if !tune.isEmpty && (md == 3 || cycle % 2 == 1) && tune[seqI] > 0 {
            let f = mf(tune[seqI] + key)
            switch md {
            case 0: tone(f, 0.5, 1, 0.04, f * 0.995); tone(f * 2, 0.25, 0, 0.008)
            case 1: tone(f, 1.3, 0, 0.035, f * 1.004); tone(f * 2.002, 0.9, 0, 0.006)
            default: tone(f, 0.17, 3, 0.03); tone(f * 2, 0.12, 2, 0.008)
            }
        }
    }
}
