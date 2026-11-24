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

/// The whole app: a bitmap the game draws into, native labels and buttons over it, and touch controls.
final class GameViewController: UIViewController {
    private let game = Game()
    private let sound = Sound()
    private var canvas: Canvas?
    private var renderer: Renderer?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var paused = false
    private var userPaused = false
    private var curW = 0
    private var curH = 0
    private var curScale = 0
    private var demoDone = false

    private let stage = UIView()
    private let purse = UILabel()
    private let folkLabel = UILabel()
    private let ammoLabel = UILabel()
    private let dayLabel = UILabel()
    private let hint = UILabel()
    private let info = UILabel()
    private let menuBtn = UIButton(type: .system)

    private let titleBox = UIView()
    private let titleName = UILabel()
    private let titleSub = UILabel()
    private let startBtn = UIButton(type: .system)

    private let pauseBox = UIView()
    private let pauseTitle = UILabel()
    private let resumeBtn = UIButton(type: .system)
    private let soundBtn = UIButton(type: .system)
    private let restartBtn = UIButton(type: .system)

    private let stickRing = UIView()
    private let knob = UIView()
    private let fireBtn = UIView()
    private let fireIcon = UILabel()

    private var stickTouch: UITouch?
    private var fireTouch: UITouch?
    private var tossTouch: UITouch?
    private var stickCenter = CGPoint.zero
    private var fireCenter = CGPoint.zero
    private var tStick = 0.0
    private var tToss = false
    private var tFire = false
    private var tossLatch = false     // a tap shorter than one frame still counts
    private var fireLatch = false

    private let cream = UIColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1)
    private let gold = UIColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1)
    private let dark = UIColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 1)

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .landscape }

    private func serif(_ size: CGFloat, bold: Bool = true) -> UIFont {
        return UIFont(name: bold ? "Georgia-Bold" : "Georgia", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }

    private func pill(_ l: UILabel, _ size: CGFloat) {
        l.font = serif(size)
        l.textColor = cream
        l.textAlignment = .center
        l.backgroundColor = UIColor(white: 0, alpha: 0.45)
        l.layer.cornerRadius = 8
        l.layer.masksToBounds = true
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.6
        view.addSubview(l)
    }

    private func style(_ b: UIButton, _ title: String, primary: Bool) {
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = serif(primary ? 20 : 17)
        b.setTitleColor(primary ? dark : cream, for: .normal)
        b.backgroundColor = primary ? gold : UIColor(white: 1, alpha: 0.14)
        b.layer.cornerRadius = 10
        b.layer.borderWidth = primary ? 0 : 1
        b.layer.borderColor = UIColor(white: 1, alpha: 0.3).cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isMultipleTouchEnabled = true
        game.sfx = sound

        stage.isUserInteractionEnabled = false
        stage.layer.magnificationFilter = .nearest
        stage.layer.contentsGravity = .resize
        view.addSubview(stage)

        // the stick on the left and the gun on the right
        stickRing.isUserInteractionEnabled = false
        stickRing.layer.borderColor = UIColor(white: 1, alpha: 0.35).cgColor
        stickRing.layer.borderWidth = 2
        stickRing.backgroundColor = UIColor(white: 0, alpha: 0.15)
        knob.isUserInteractionEnabled = false
        knob.backgroundColor = UIColor(white: 1, alpha: 0.55)
        view.addSubview(stickRing)
        view.addSubview(knob)
        fireBtn.isUserInteractionEnabled = false
        fireBtn.backgroundColor = UIColor(red: 0.55, green: 0.12, blue: 0.1, alpha: 0.7)
        fireBtn.layer.borderColor = UIColor(white: 1, alpha: 0.45).cgColor
        fireBtn.layer.borderWidth = 2
        fireIcon.text = "GUN"
        fireIcon.font = serif(15)
        fireIcon.textColor = cream
        fireIcon.textAlignment = .center
        fireBtn.addSubview(fireIcon)
        view.addSubview(fireBtn)

        pill(purse, 17); pill(folkLabel, 15); pill(ammoLabel, 15); pill(dayLabel, 15)
        pill(hint, 15); pill(info, 14)
        hint.numberOfLines = 3
        hint.backgroundColor = UIColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 0.86)
        info.numberOfLines = 2
        purse.textColor = gold

        style(menuBtn, "Menu", primary: false)
        menuBtn.titleLabel?.font = serif(15)
        menuBtn.backgroundColor = UIColor(white: 0, alpha: 0.45)
        menuBtn.addTarget(self, action: #selector(openMenu), for: .touchUpInside)
        view.addSubview(menuBtn)

        // title
        titleBox.backgroundColor = UIColor(red: 0.1, green: 0.06, blue: 0.04, alpha: 0.5)
        titleName.text = "DUSTFALL III"
        titleName.font = serif(54)
        titleName.textColor = gold
        titleName.textAlignment = .center
        titleName.adjustsFontSizeToFitWidth = true
        titleName.layer.shadowColor = UIColor.black.cgColor
        titleName.layer.shadowOpacity = 0.8
        titleName.layer.shadowRadius = 3
        titleName.layer.shadowOffset = CGSize(width: 0, height: 3)
        titleSub.text = "The railroad moved away, and the town died. Ride home and rebuild it."
        titleSub.font = serif(17, bold: false)
        titleSub.textColor = cream
        titleSub.textAlignment = .center
        titleSub.numberOfLines = 2
        style(startBtn, "Ride in", primary: true)
        startBtn.addTarget(self, action: #selector(startGame), for: .touchUpInside)
        titleBox.addSubview(titleName); titleBox.addSubview(titleSub); titleBox.addSubview(startBtn)
        view.addSubview(titleBox)

        // pause menu
        pauseBox.backgroundColor = UIColor(red: 0.1, green: 0.06, blue: 0.04, alpha: 0.82)
        pauseBox.isHidden = true
        pauseTitle.text = "Paused"
        pauseTitle.font = serif(28)
        pauseTitle.textColor = gold
        pauseTitle.textAlignment = .center
        style(resumeBtn, "Resume", primary: true)
        style(soundBtn, "Sound: on", primary: false)
        style(restartBtn, "Start over", primary: false)
        resumeBtn.addTarget(self, action: #selector(closeMenu), for: .touchUpInside)
        soundBtn.addTarget(self, action: #selector(toggleSound), for: .touchUpInside)
        restartBtn.addTarget(self, action: #selector(restart), for: .touchUpInside)
        pauseBox.addSubview(pauseTitle); pauseBox.addSubview(resumeBtn); pauseBox.addSubview(soundBtn); pauseBox.addSubview(restartBtn)
        view.addSubview(pauseBox)

        sound.muted = UserDefaults.standard.bool(forKey: "dustfall3.muted")
        soundBtn.setTitle(sound.muted ? "Sound: off" : "Sound: on", for: .normal)

        let dl = CADisplayLink(target: self, selector: #selector(tick(_:)))
        dl.add(to: .main, forMode: .common)
        link = dl
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bw = view.bounds.width, bh = view.bounds.height
        let s = view.safeAreaInsets
        let l = max(s.left, 12), r = max(s.right, 12), top = max(s.top, 8), bot = max(s.bottom, 8)
        stage.frame = view.bounds
        purse.frame = CGRect(x: l, y: top, width: 74, height: 30)
        folkLabel.frame = CGRect(x: l + 80, y: top, width: 74, height: 30)
        ammoLabel.frame = CGRect(x: l + 160, y: top, width: 86, height: 30)
        menuBtn.frame = CGRect(x: bw - r - 70, y: top, width: 70, height: 32)
        dayLabel.frame = CGRect(x: bw - r - 70 - 126, y: top, width: 120, height: 30)
        let hw = min(bw - l - r - 40, 520)
        hint.frame = CGRect(x: (bw - hw) / 2, y: top + 38, width: hw, height: 62)
        let iw = min(bw * 0.5, 420)
        info.frame = CGRect(x: (bw - iw) / 2, y: bh - bot - 44, width: iw, height: 40)
        stickCenter = CGPoint(x: l + 74, y: bh - bot - 70)
        stickRing.frame = CGRect(x: stickCenter.x - 54, y: stickCenter.y - 54, width: 108, height: 108)
        stickRing.layer.cornerRadius = 54
        knob.bounds = CGRect(x: 0, y: 0, width: 46, height: 46)
        knob.center = stickCenter
        knob.layer.cornerRadius = 23
        fireCenter = CGPoint(x: bw - r - 58, y: bh - bot - 62)
        fireBtn.frame = CGRect(x: fireCenter.x - 40, y: fireCenter.y - 40, width: 80, height: 80)
        fireBtn.layer.cornerRadius = 40
        fireIcon.frame = fireBtn.bounds
        titleBox.frame = view.bounds
        titleName.frame = CGRect(x: 20, y: bh * 0.16, width: bw - 40, height: 70)
        titleSub.frame = CGRect(x: 40, y: bh * 0.16 + 74, width: bw - 80, height: 48)
        startBtn.frame = CGRect(x: bw / 2 - 110, y: bh * 0.16 + 136, width: 220, height: 52)
        pauseBox.frame = view.bounds
        pauseTitle.frame = CGRect(x: 0, y: bh * 0.12, width: bw, height: 40)
        resumeBtn.frame = CGRect(x: bw / 2 - 120, y: bh * 0.12 + 54, width: 240, height: 50)
        soundBtn.frame = CGRect(x: bw / 2 - 120, y: bh * 0.12 + 114, width: 240, height: 44)
        restartBtn.frame = CGRect(x: bw / 2 - 120, y: bh * 0.12 + 166, width: 240, height: 44)
        rebuild()
    }

    /// Sizes the game bitmap the way the web version sizes its canvas: about 185 game pixels tall.
    private func rebuild() {
        let sw = Double(view.bounds.width), sh = Double(view.bounds.height)
        if sw < 50 || sh < 50 { return }
        let dpr = Double(view.window?.screen.scale ?? UIScreen.main.scale)
        let sc = max(2.0, 2 * (sh * dpr / 370).rounded())
        let w = Int(ceil(sw * dpr / sc)), h = Int(ceil(sh * dpr / sc))
        let ps = max(2, Int(sc) / 2)
        if w == curW && h == curH && ps == curScale && renderer != nil { return }
        guard let cv = Canvas(w: w, h: h, scale: ps) else { return }
        curW = w; curH = h; curScale = ps
        canvas = cv
        game.W = Double(w); game.H = Double(h)
        game.GY = Double(h) - clampD((Double(h) * 0.24).rounded(), 30, 46)
        game.cam = clampD(game.px - game.W / 2, 0, WORLD - game.W)
        renderer = Renderer(game: game, canvas: cv)
        if !demoDone && sw > sh {
            demoDone = true
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demo-day") { game.demo("day") }
            if args.contains("-demo-night") { game.demo("night") }
        }
    }

    func setPaused(_ p: Bool) {
        paused = p
        last = 0
        if !p { sound.resume() }
        if p && game.state == .play && !userPaused { openMenu() }
    }

    @objc private func startGame() {
        sound.start()
        game.start()
        stickTouch = nil; fireTouch = nil; tossTouch = nil; tStick = 0; tToss = false; tFire = false
    }

    @objc private func openMenu() {
        if game.state != .play { return }
        userPaused = true
        pauseBox.isHidden = false
        stickTouch = nil; fireTouch = nil; tossTouch = nil; tStick = 0; tToss = false; tFire = false
        knob.center = stickCenter
    }

    @objc private func closeMenu() {
        userPaused = false
        pauseBox.isHidden = true
        last = 0
        sound.resume()
    }

    @objc private func toggleSound() {
        sound.muted = !sound.muted
        UserDefaults.standard.set(sound.muted, forKey: "dustfall3.muted")
        soundBtn.setTitle(sound.muted ? "Sound: off" : "Sound: on", for: .normal)
    }

    @objc private func restart() {
        closeMenu()
        game.reset()
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let raw = last == 0 ? 1.0 / 60 : now - last
        last = now
        if paused { return }
        game.input.stick = tStick
        game.input.toss = tToss || tossLatch
        game.input.fire = tFire || fireLatch
        tossLatch = false; fireLatch = false
        if !userPaused { game.update(min(0.05, max(0, raw))) }
        guard let r = renderer, let cv = canvas else { return }
        r.draw()
        stage.layer.contents = cv.image()
        updateHUD()
    }

    private func set(_ l: UILabel, _ text: String) {
        if l.text != text { l.text = text }
    }

    private func updateHUD() {
        let playing = game.state == .play
        titleBox.isHidden = playing
        for v in [purse, folkLabel, ammoLabel, dayLabel, menuBtn, stickRing, knob, fireBtn] as [UIView] { v.isHidden = !playing }
        if !playing { hint.isHidden = true; info.isHidden = true; return }
        set(purse, "\u{25CF} \(game.coins)")
        set(folkLabel, "Folk \(game.folk.count)")
        set(ammoLabel, game.reloadT > 0 ? "Loading" : "Shots \(game.ammo)")
        let tm = game.dark() > 0.5 ? "night" : (game.t > 0.6 ? "dusk" : "")
        set(dayLabel, "Day \(game.day)" + (tm.isEmpty ? "" : ", " + tm))
        hint.isHidden = game.hintT <= 0 || userPaused
        if game.hintT > 0 { set(hint, game.hintText) }
        info.isHidden = game.info.isEmpty || userPaused
        if !game.info.isEmpty { set(info, game.info) }
    }

    // ---------- touch: the left of the screen is the stick, the gun button fires, anywhere else tosses a coin
    private func moveStick(_ p: CGPoint) {
        let dx = max(-44, min(44, p.x - stickCenter.x))
        tStick = abs(dx) < 8 ? 0 : Double(dx / 44)
        knob.center = CGPoint(x: stickCenter.x + dx, y: stickCenter.y)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if game.state != .play || userPaused { return }
        for t in touches {
            let p = t.location(in: view)
            if p.x < view.bounds.width * 0.4 {
                if stickTouch == nil { stickTouch = t; moveStick(p) }
                continue
            }
            let df = hypot(p.x - fireCenter.x, p.y - fireCenter.y)
            if df < 54 {
                if fireTouch == nil { fireTouch = t; tFire = true; fireLatch = true }
            } else if tossTouch == nil { tossTouch = t; tToss = true; tossLatch = true }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches where t === stickTouch { moveStick(t.location(in: view)) }
    }
    private func lift(_ touches: Set<UITouch>) {
        for t in touches {
            if t === stickTouch { stickTouch = nil; tStick = 0; knob.center = stickCenter }
            if t === tossTouch { tossTouch = nil; tToss = false }
            if t === fireTouch { fireTouch = nil; tFire = false }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
}
