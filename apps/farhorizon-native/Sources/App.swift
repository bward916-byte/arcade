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
        (window?.rootViewController as? GameViewController)?.setPaused(true)
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        (window?.rootViewController as? GameViewController)?.setPaused(false)
    }
}

/// The whole app: one bitmap the game draws into, shown full screen, with touches passed straight to the game.
final class GameViewController: UIViewController {
    private let game = Game()
    private let sound = Sound()
    private var canvas: Canvas?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var paused = false
    private var curW = 0
    private var curH = 0
    private var demoDone = false
    private let stage = UIView()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .landscape }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { return .bottom }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isMultipleTouchEnabled = true
        stage.isUserInteractionEnabled = false
        stage.layer.contentsGravity = .resize
        view.addSubview(stage)
        game.snd = sound
        game.buzz = { [weak self] hard in
            if hard { self?.heavy.impactOccurred() } else { self?.light.impactOccurred() }
        }
        let dl = CADisplayLink(target: self, selector: #selector(tick(_:)))
        dl.add(to: .main, forMode: .common)
        link = dl
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds
        stage.frame = b
        let w = Int(b.width.rounded()), h = Int(b.height.rounded())
        if w < 50 || h < 50 || w < h { return }
        if w == curW && h == curH && canvas != nil { return }
        guard let cv = Canvas(w: w, h: h, scale: 2) else { return }
        curW = w; curH = h
        canvas = cv
        let s = view.safeAreaInsets
        game.W = Double(w); game.H = Double(h)
        game.safeL = max(Double(s.left), 10); game.safeR = max(Double(s.right), 10); game.safeB = max(Double(s.bottom), 8)
        if !demoDone {
            demoDone = true
            for a in ProcessInfo.processInfo.arguments where a.hasPrefix("-demo-") {
                game.demo(String(a.dropFirst(6)))
            }
        }
    }

    func setPaused(_ p: Bool) {
        paused = p
        last = 0
        if !p { sound.resume() }
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let raw = last == 0 ? 1.0 / 60 : now - last
        last = now
        if paused { return }
        guard let cv = canvas else { return }
        game.update(min(0.05, max(0, raw)))
        game.draw(cv)
        stage.layer.contents = cv.image()
    }

    private func point(_ t: UITouch) -> (Double, Double) {
        let p = t.location(in: view)
        return (Double(p.x), Double(p.y))
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        sound.start()
        for t in touches { let p = point(t); game.touchDown(p.0, p.1) }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { let p = point(t); game.touchMove(p.0, p.1) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { let p = point(t); game.touchUp(p.0, p.1) }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { let p = point(t); game.touchUp(p.0, p.1) }
    }
}
