import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = GameViewController()
        w.makeKeyAndVisible()
        window = w
        return true
    }
    func applicationWillResignActive(_ application: UIApplication) {
        (window?.rootViewController as? GameViewController)?.background()
    }
}

/// The whole app: one bitmap the game draws into, and touches turned into game input.
final class GameViewController: UIViewController {
    private let game = Game()
    private let sound = Sound()
    private let renderer = Renderer()
    private var canvas: Canvas?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var curW = 0
    private var curH = 0
    private var started = false

    private let stage = UIView()
    private let tapLight = UIImpactFeedbackGenerator(style: .light)
    private let tapMedium = UIImpactFeedbackGenerator(style: .medium)
    private let tapHeavy = UIImpactFeedbackGenerator(style: .heavy)

    private var stickTouch: UITouch?
    private var stickX0: CGFloat = 0
    private var atkTouch: UITouch?

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .landscape }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { return .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isMultipleTouchEnabled = true
        stage.isUserInteractionEnabled = false
        stage.layer.contentsGravity = .resize
        view.addSubview(stage)
        game.snd = sound
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        stage.frame = view.bounds
        let w = Int(view.bounds.width), h = Int(view.bounds.height)
        if w == curW && h == curH { return }
        if w < h || h < 10 { return }
        curW = w; curH = h
        let gw = (VIEW_H * Double(w) / Double(h)).rounded()
        let k = VIEW_H / Double(h)
        game.W = gw
        game.safeL = Double(view.safeAreaInsets.left) * k
        game.safeR = Double(view.safeAreaInsets.right) * k
        let px = Double(h) * Double(UIScreen.main.scale)
        let scale = px / VIEW_H >= 1.7 ? 2 : 1
        canvas = Canvas(w: Int(gw), h: Int(VIEW_H), scale: scale)
        if !started {
            started = true
            let args = ProcessInfo.processInfo.arguments
            for what in ["play", "fire", "dogs", "boss", "hole", "lift", "pick", "street"] where args.contains("-demo-\(what)") { game.demo(what) }
            for i in 0..<5 where args.contains("-demo-intro\(i)") { game.newGame(); game.introT = Double(i) * 1.8 + 1.3; game.introFreeze = true }
            if args.contains("-demo-bot") {
                let report = game.botRun(40)
                if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? report.write(to: dir.appendingPathComponent("bot.txt"), atomically: true, encoding: .utf8)
                }
            }
        }
    }

    func background() {
        if game.mode == .play { renderer.paused = true }
        game.input = Input()
        stickTouch = nil; atkTouch = nil
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let raw = last == 0 ? 1.0 / 60 : now - last
        last = now
        guard let cv = canvas else { return }
        if !renderer.paused { game.update(raw) }
        if game.haptic > 0 {
            if game.haptic >= 3 { tapHeavy.impactOccurred() } else if game.haptic == 2 { tapMedium.impactOccurred() } else { tapLight.impactOccurred() }
            game.haptic = 0
        }
        if game.mode != .play && (stickTouch != nil || atkTouch != nil) && !game.auto {
            stickTouch = nil; atkTouch = nil
            game.input = Input()
        }
        renderer.draw(game, cv)
        stage.layer.contents = cv.image()
    }

    // ---------- touch
    private func gp(_ t: UITouch) -> (Double, Double) {
        let p = t.location(in: view)
        let k = VIEW_H / Double(max(1, view.bounds.height))
        return (Double(p.x) * k, Double(p.y) * k)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        sound.start()
        for t in touches {
            let (x, y) = gp(t)
            if renderer.paused {
                if game.resumeRect.has(x, y) { renderer.paused = false } else if game.quitRect.has(x, y) { renderer.paused = false; game.save(); game.auto = false; game.mode = .title }
                continue
            }
            switch game.mode {
            case .title:
                if game.hasSave && game.contRect.has(x, y) { game.auto = false; game.resume(); sound.pick() } else if game.playRect.has(x, y) { game.auto = false; game.newGame() }
            case .intro, .card, .ending:
                game.tapAdvance()
            case .pick:
                for i in 0..<game.pickOpts.count where game.pickRect(i).has(x, y) { game.choosePick(i); break }
            case .play:
                if game.auto { game.auto = false; game.input = Input() }
                if game.pauseRect.has(x, y) { renderer.paused = true; game.input = Input(); continue }
                let pb = game.powBtn
                let ab = game.atkBtn
                if hypot(x - pb.0, y - pb.1) < pb.2 + 14 { game.input.power = true; continue }
                if hypot(x - ab.0, y - ab.1) < ab.2 + 26 || x > game.W * 0.62 {
                    if atkTouch == nil { atkTouch = t; game.input.attack = true }
                    continue
                }
                if stickTouch == nil { stickTouch = t; stickX0 = t.location(in: view).x; game.input.move = 0 }
            default: break
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches where t === stickTouch {
            let dx = t.location(in: view).x - stickX0
            if abs(dx) > 10 { game.input.move = dx > 0 ? 1 : -1 } else { game.input.move = 0 }
            // let the thumb slide: the anchor follows once it is dragged far
            if dx > 44 { stickX0 = t.location(in: view).x - 44 }
            if dx < -44 { stickX0 = t.location(in: view).x + 44 }
        }
    }
    private func lift(_ touches: Set<UITouch>) {
        for t in touches {
            if t === stickTouch { stickTouch = nil; game.input.move = 0 }
            if t === atkTouch { atkTouch = nil; game.input.attack = false }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
}
