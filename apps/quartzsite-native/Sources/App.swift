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

/// All the words on screen: the game lists them each frame in game pixels and this view draws them crisp.
final class TextLayer: UIView {
    var items: [TextItem] = []
    var k: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { return nil }

    override func draw(_ rect: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        for it in items {
            if it.s.isEmpty { continue }
            let size = CGFloat(it.size) * k
            let font: UIFont = it.bold ? (UIFont(name: "Georgia-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)) : UIFont.systemFont(ofSize: size, weight: .semibold)
            let a = CGFloat(it.col.a)
            let col = UIColor(red: CGFloat(it.col.r), green: CGFloat(it.col.g), blue: CGFloat(it.col.b), alpha: a)
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: col, .paragraphStyle: para]
            let bright = it.col.r + it.col.g + it.col.b > 1.2
            if bright && !it.plate {
                let sh = NSShadow()
                sh.shadowColor = UIColor(white: 0, alpha: 0.8 * a)
                sh.shadowOffset = CGSize(width: 0, height: 1)
                sh.shadowBlurRadius = 2
                attrs[.shadow] = sh
            }
            let ns = it.s as NSString
            let limit = it.wrap > 0 ? CGFloat(it.wrap) * k : 4000
            let box = ns.boundingRect(with: CGSize(width: limit, height: 4000), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            let tw = ceil(box.width), th = ceil(box.height)
            var x = CGFloat(it.x) * k
            if it.align == 0 { x -= tw / 2 } else if it.align == 2 { x -= tw }
            let y = CGFloat(it.y) * k - th / 2
            let r = CGRect(x: x, y: y, width: tw, height: th)
            if it.plate {
                cg.setFillColor(UIColor(red: 0.11, green: 0.078, blue: 0.063, alpha: 0.78 * a).cgColor)
                cg.addPath(UIBezierPath(roundedRect: r.insetBy(dx: -10, dy: -6), cornerRadius: 9).cgPath)
                cg.fillPath()
            }
            ns.draw(with: r, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        }
    }
}

/// The whole app: a bitmap the game paints, a layer of text over it, and the touch controls.
final class GameViewController: UIViewController {
    private let game = Game()
    private let sound = Sound()
    private var lastStep = 0
    private var canvas: Canvas?
    private var renderer: Renderer?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var paused = false
    private var curW = 0
    private var curH = 0
    private var demoDone = false
    private var k: CGFloat = 2

    private let stage = UIView()
    private let words = TextLayer(frame: .zero)
    private var stickTouch: UITouch?
    private var holdTouch: UITouch?
    private let tapLight = UIImpactFeedbackGenerator(style: .light)
    private let tapDone = UINotificationFeedbackGenerator()
    private let saveKey = "quartzsite.native.save5"

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .landscape }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { return .bottom }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isMultipleTouchEnabled = true
        stage.isUserInteractionEnabled = false
        view.addSubview(stage)
        view.addSubview(words)
        if let data = UserDefaults.standard.data(forKey: saveKey), let s = try? JSONDecoder().decode(SaveData.self, from: data) {
            game.restore(s)
        }
        sound.start()
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        stage.frame = view.bounds
        words.frame = view.bounds
        rebuild()
    }
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        view.setNeedsLayout()
    }

    private func rebuild() {
        let sw = Double(view.bounds.width), sh = Double(view.bounds.height)
        if sw < 50 || sh < 50 || sw < sh { return }
        let dpr = Double(view.window?.screen.scale ?? UIScreen.main.scale)
        let sc = max(2.0, 2 * (sh * dpr / 370).rounded())
        let w = Int(ceil(sw * dpr / sc)), h = Int(ceil(sh * dpr / sc))
        k = CGFloat(sw / Double(w))
        words.k = k
        game.safeL = Double(view.safeAreaInsets.left) / Double(k)
        game.safeR = Double(view.safeAreaInsets.right) / Double(k)
        if w == curW && h == curH && renderer != nil { return }
        guard let cv = Canvas(w: w, h: h, scale: Int(sc)) else { return }
        curW = w; curH = h
        canvas = cv
        game.W = Double(w); game.H = Double(h)
        game.GY = Double(h) - clampD((Double(h) * 0.26).rounded(), 34, 50)
        renderer = Renderer(game: game, canvas: cv)
        if !demoDone {
            demoDone = true
            for key in ["pick", "rigs", "play", "night", "ltva", "main", "gem", "tyson", "dome", "toys", "ride", "skoolie", "map", "trail", "scaddan", "browse", "parade", "home", "season", "end", "gear", "computer", "rain", "windy", "critters", "page", "qfest", "western", "trailride", "cine0", "cine1", "cine2", "cine3", "cine4", "happy", "cleanup", "dog", "camels", "drive", "drivenight", "drivetrail", "drivestop"] where ProcessInfo.processInfo.arguments.contains("-demo-" + key) {
                game.demo(key)
            }
        }
    }

    func setPaused(_ p: Bool) {
        paused = p
        last = 0
        if p { clearTouches(); save() } else { sound.resume() }
    }
    private func save() {
        guard let s = game.snapshot(), let data = try? JSONEncoder().encode(s) else {
            if game.ended { UserDefaults.standard.removeObject(forKey: saveKey) }
            return
        }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let raw = last == 0 ? 1.0 / 60 : now - last
        last = now
        if paused { return }
        game.update(min(0.05, max(0, raw)))
        guard let r = renderer, let cv = canvas else { return }
        r.draw()
        stage.layer.contents = cv.image()
        words.items = game.texts
        words.setNeedsDisplay()
        sound.muted = game.muted
        for e in game.events {
            switch e {
            case 1: tapDone.notificationOccurred(.success); sound.done()
            case 2: tapLight.impactOccurred(); sound.refund()
            case 3: tapLight.impactOccurred(); sound.tap()
            case 4: sound.engine(game.inRig && game.rig.rawValue >= RigKind.skoolie.rawValue)
            case 5: sound.coin()
            case 6: sound.spend()
            case 7: sound.dawn()
            case 8: sound.season()
            default: break
            }
        }
        game.events.removeAll()
        // the ring ticks as it fills
        let step = Int(game.ringProg * 4)
        if step > lastStep { sound.tick(step) }
        lastStep = step
        // the desert around you, and the guitar
        if game.phase != .pick && (!game.overlay || game.inCine || game.driving) {
            let dk = r.dark
            var fire = 0.0
            if game.phase == .play {
                for sp in game.spots where sp.kind == .fire || sp.kind == .circle || (sp.kind == .camp && game.rigArea == game.area) {
                    fire = max(fire, 1 - abs(sp.x - game.px) / 160)
                }
            }
            sound.ambience(now, dk, max(0, fire), game.phase == .play && game.weather == 1, game.phase == .play && game.weather == 3)
            var eventOn = false
            for e in EVENTS.indices where e != EV_PAN && game.on(e) && EVENTS[e].area == game.area { eventOn = true }
            sound.music(now, game.phase == .play && eventOn ? 3 : (dk > 0.6 ? 2 : (dk > 0.15 ? 1 : 0)))
        }
    }

    // MARK: touch

    private func moveStick(_ p: CGPoint) {
        let centre = (CGFloat(game.safeL) + 40) * k
        let dx = max(-1, min(1, (p.x - centre) / (26 * k)))
        game.input.stick = Double(dx)
    }
    private func clearTouches() {
        stickTouch = nil; holdTouch = nil
        game.input.stick = 0; game.input.hold = false
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: view)
            let gx = Double(p.x / k), gy = Double(p.y / k)
            if game.phase != .play || game.overlay {
                game.tap(gx, gy)
                continue
            }
            // a tap on your glowing rig climbs in or out
            var onRig = false
            for h in game.hits where h.id >= 50 && gx >= h.x && gx <= h.x + h.w && gy >= h.y && gy <= h.y + h.h { onRig = true }
            if onRig {
                game.tap(gx, gy)
                continue
            }
            if p.x < view.bounds.width * 0.42 {
                if stickTouch == nil { stickTouch = t; moveStick(p) }
            } else if holdTouch == nil {
                holdTouch = t
                game.input.hold = true
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches where t === stickTouch { moveStick(t.location(in: view)) }
    }
    private func lift(_ touches: Set<UITouch>) {
        for t in touches {
            if t === stickTouch { stickTouch = nil; game.input.stick = 0 }
            if t === holdTouch { holdTouch = nil; game.input.hold = false }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
}
