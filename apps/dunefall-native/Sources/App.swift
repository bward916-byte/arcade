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
    private var overlay: Canvas?
    private var renderer: Renderer?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var paused = false
    private var curW = 0
    private var curH = 0
    private var demoDone = false

    private let stage = UIView()
    private let purse = UILabel()
    private let dayLabel = UILabel()
    private let info = UILabel()
    private let hint = UILabel()
    private let card = UILabel()
    private let pad = UIView()
    private let knob = UIView()
    private let tossBtn = UILabel()
    private let fireBtn = UILabel()
    private let titleBox = UIView()
    private let titleName = UILabel()
    private let titleTag = UILabel()
    private let titleNote = UILabel()
    private let goBtn = UIButton(type: .system)
    private let overBox = UIView()
    private let overName = UILabel()
    private let overText = UILabel()
    private let againBtn = UIButton(type: .system)

    private var stickTouch: UITouch?
    private var tossTouch: UITouch?
    private var fireTouch: UITouch?
    private var padCenter = CGPoint.zero
    private var tossCenter = CGPoint.zero
    private var fireCenter = CGPoint.zero

    private let cream = UIColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1)
    private let gold = UIColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1)
    private let ink = UIColor(red: 0.11, green: 0.075, blue: 0.047, alpha: 1)

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .landscape }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { return .bottom }

    private func serif(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Georgia-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }
    private func style(_ l: UILabel, _ size: CGFloat, _ color: UIColor, _ align: NSTextAlignment) {
        l.font = serif(size)
        l.textColor = color
        l.textAlignment = align
        l.shadowColor = UIColor(white: 0, alpha: 0.7)
        l.shadowOffset = CGSize(width: 0, height: 1)
        l.isUserInteractionEnabled = false
    }
    private func plate(_ l: UILabel) {
        l.backgroundColor = ink.withAlphaComponent(0.78)
        l.layer.cornerRadius = 8
        l.layer.masksToBounds = true
    }
    private func round(_ l: UILabel, _ text: String) {
        style(l, 15, ink, .center)
        l.shadowColor = nil
        l.text = text
        l.backgroundColor = gold.withAlphaComponent(0.82)
        l.layer.borderColor = ink.withAlphaComponent(0.8).cgColor
        l.layer.borderWidth = 2
        l.layer.masksToBounds = true
    }
    private func button(_ b: UIButton, _ text: String) {
        b.setTitle(text, for: .normal)
        b.setTitleColor(ink, for: .normal)
        b.titleLabel?.font = serif(22)
        b.backgroundColor = gold
        b.layer.cornerRadius = 10
        b.layer.borderColor = ink.cgColor
        b.layer.borderWidth = 2
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isMultipleTouchEnabled = true
        game.snd = sound

        stage.isUserInteractionEnabled = false
        stage.layer.magnificationFilter = .nearest
        stage.layer.contentsGravity = .resize
        view.addSubview(stage)

        style(purse, 16, cream, .left)
        style(dayLabel, 16, cream, .right)
        style(info, 14, cream, .center); plate(info)
        style(hint, 14, cream, .center); plate(hint)
        hint.numberOfLines = 2
        style(card, 30, gold, .center)
        card.numberOfLines = 2
        for l in [purse, dayLabel, info, hint, card] { view.addSubview(l) }

        pad.isUserInteractionEnabled = false
        pad.backgroundColor = ink.withAlphaComponent(0.45)
        pad.layer.borderColor = cream.withAlphaComponent(0.5).cgColor
        pad.layer.borderWidth = 2
        knob.backgroundColor = gold.withAlphaComponent(0.9)
        knob.layer.borderColor = ink.cgColor
        knob.layer.borderWidth = 2
        pad.addSubview(knob)
        view.addSubview(pad)
        round(tossBtn, "Coin")
        round(fireBtn, "Bow")
        view.addSubview(tossBtn)
        view.addSubview(fireBtn)

        style(titleName, 64, gold, .center)
        titleName.text = "DUNEFALL"
        titleName.adjustsFontSizeToFitWidth = true
        style(titleTag, 17, cream, .center)
        titleTag.text = "Build a town from the sand. Hold it through the night."
        style(titleNote, 12, cream, .center)
        titleNote.text = "Native trial: the first town"
        button(goBtn, "Ride in")
        goBtn.addTarget(self, action: #selector(ride), for: .touchUpInside)
        for v in [titleName, titleTag, titleNote, goBtn] as [UIView] { titleBox.addSubview(v) }
        view.addSubview(titleBox)

        overBox.backgroundColor = ink.withAlphaComponent(0.72)
        style(overName, 34, gold, .center)
        overName.text = "Run out of town"
        style(overText, 16, cream, .center)
        overText.text = "The raiders caught you with an empty purse."
        button(againBtn, "New game")
        againBtn.addTarget(self, action: #selector(ride), for: .touchUpInside)
        for v in [overName, overText, againBtn] as [UIView] { overBox.addSubview(v) }
        overBox.isHidden = true
        view.addSubview(overBox)

        let dl = CADisplayLink(target: self, selector: #selector(tick(_:)))
        dl.add(to: .main, forMode: .common)
        link = dl
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds
        let s = view.safeAreaInsets
        let left = max(s.left, 12), right = max(s.right, 12), bottom = max(s.bottom, 8)
        stage.frame = b
        purse.frame = CGRect(x: left + 4, y: 6, width: b.width * 0.6, height: 22)
        dayLabel.frame = CGRect(x: b.width - right - 164, y: 6, width: 160, height: 22)
        hint.frame = CGRect(x: b.width * 0.5 - 250, y: 32, width: 500, height: 40)
        info.frame = CGRect(x: b.width * 0.5 - 150, y: b.height - bottom - 30, width: 300, height: 24)
        card.frame = CGRect(x: 0, y: b.height * 0.22, width: b.width, height: 80)

        pad.frame = CGRect(x: left + 16, y: b.height - bottom - 78, width: 132, height: 60)
        pad.layer.cornerRadius = 30
        knob.frame = CGRect(x: 66 - 23, y: 30 - 23, width: 46, height: 46)
        knob.layer.cornerRadius = 23
        padCenter = CGPoint(x: pad.frame.midX, y: pad.frame.midY)
        tossBtn.frame = CGRect(x: b.width - right - 166, y: b.height - bottom - 74, width: 64, height: 64)
        fireBtn.frame = CGRect(x: b.width - right - 84, y: b.height - bottom - 96, width: 64, height: 64)
        tossBtn.layer.cornerRadius = 32
        fireBtn.layer.cornerRadius = 32
        tossCenter = CGPoint(x: tossBtn.frame.midX, y: tossBtn.frame.midY)
        fireCenter = CGPoint(x: fireBtn.frame.midX, y: fireBtn.frame.midY)

        titleBox.frame = b
        titleName.frame = CGRect(x: 20, y: b.height * 0.06, width: b.width - 40, height: 76)
        titleTag.frame = CGRect(x: 20, y: b.height * 0.06 + 74, width: b.width - 40, height: 24)
        goBtn.frame = CGRect(x: b.width * 0.5 - 90, y: b.height - bottom - 78, width: 180, height: 48)
        titleNote.frame = CGRect(x: 20, y: b.height - bottom - 26, width: b.width - 40, height: 18)

        overBox.frame = b
        overName.frame = CGRect(x: 20, y: b.height * 0.24, width: b.width - 40, height: 44)
        overText.frame = CGRect(x: 20, y: b.height * 0.24 + 48, width: b.width - 40, height: 24)
        againBtn.frame = CGRect(x: b.width * 0.5 - 90, y: b.height * 0.24 + 92, width: 180, height: 48)
        rebuild()
    }

    /// Sizes the game bitmap the way the web version sizes its canvas: about 185 game pixels tall.
    private func rebuild() {
        let sw = Double(view.bounds.width), sh = Double(view.bounds.height)
        if sw < 50 || sh < 50 { return }
        let dpr = Double(view.window?.screen.scale ?? UIScreen.main.scale)
        let sc = max(2.0, 2 * (sh * dpr / 370).rounded())
        let w = Int(ceil(sw * dpr / sc)), h = Int(ceil(sh * dpr / sc))
        if w == curW && h == curH && renderer != nil { return }
        guard let cv = Canvas(w: w, h: h, scale: 2), let ov = Canvas(w: w, h: h, scale: 1) else { return }
        curW = w; curH = h
        canvas = cv; overlay = ov
        game.W = Double(w); game.H = Double(h)
        game.GY = Double(h) - clampD((Double(h) * 0.24).rounded(), 30, 46)
        game.cam = clampD(game.player.x - game.W / 2, 0, game.WORLD - game.W)
        renderer = Renderer(game: game, canvas: cv, overlay: ov)
        if !demoDone && sw > sh {
            demoDone = true
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demo-play") { game.demo("play") }
            if args.contains("-demo-night") { game.demo("night") }
        }
    }

    func setPaused(_ p: Bool) {
        paused = p
        last = 0
        if !p { sound.resume() }
        if p { clearTouches() }
    }

    @objc private func ride() {
        sound.start()
        game.start()
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
        updateHUD()
    }

    private func set(_ l: UILabel, _ text: String) {
        if l.text != text { l.text = text }
    }
    private func updateHUD() {
        let playing = game.state == .play
        titleBox.isHidden = game.state != .title
        overBox.isHidden = game.state != .over
        for v in [purse, dayLabel, pad, tossBtn, fireBtn] as [UIView] { v.isHidden = game.state == .title }
        let p = game.player
        let arrows = p.rl > 0 ? "restringing" : String(repeating: "|", count: max(0, p.ammo))
        set(purse, "Coins \(p.coins)    Arrows \(arrows)    Free hands \(game.head(.folk))")
        set(dayLabel, game.dark > 0.5 ? "Night \(game.day)" : "Day \(game.day)")
        if playing, let line = game.infoLine() {
            set(info, line.0 + "   " + line.1)
            info.isHidden = false
        } else { info.isHidden = true }
        let showHint = playing && game.hintT > 0
        if showHint { set(hint, game.hintText) } else if playing && game.t < 0.2 && !game.report.isEmpty { set(hint, game.report) }
        hint.isHidden = !(showHint || (playing && game.t < 0.2 && !game.report.isEmpty))
        if playing && game.cardT > 0 {
            set(card, game.cardText + "\nBring the town back")
            card.alpha = CGFloat(min(1, game.cardT))
            card.isHidden = false
        } else { card.isHidden = true }
        tossBtn.alpha = game.input.toss ? 1 : 0.8
        fireBtn.alpha = game.input.fire ? 1 : (p.rl > 0 ? 0.4 : 0.8)
    }

    // ---------- touch: left side is the stick, the two round buttons toss a coin and loose an arrow
    private func moveStick(_ p: CGPoint) {
        let dx = max(-34, min(34, p.x - padCenter.x))
        game.input.stick = Double(dx) / 34
        knob.transform = CGAffineTransform(translationX: dx, y: 0)
    }
    private func clearTouches() {
        stickTouch = nil; tossTouch = nil; fireTouch = nil
        game.input.stick = 0; game.input.toss = false; game.input.fire = false
        knob.transform = .identity
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if game.state != .play { return }
        for t in touches {
            let p = t.location(in: view)
            if p.y < 30 && p.x < view.bounds.width * 0.6 { game.input.reload = true; continue }
            if p.x < view.bounds.width * 0.45 {
                if stickTouch == nil { stickTouch = t; moveStick(p) }
                continue
            }
            let dt = hypot(p.x - tossCenter.x, p.y - tossCenter.y)
            let df = hypot(p.x - fireCenter.x, p.y - fireCenter.y)
            if dt <= df && dt < 80 && tossTouch == nil { tossTouch = t; game.input.toss = true } else if df < 80 && fireTouch == nil { fireTouch = t; game.input.fire = true }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches where t === stickTouch { moveStick(t.location(in: view)) }
    }
    private func lift(_ touches: Set<UITouch>) {
        for t in touches {
            if t === stickTouch { stickTouch = nil; game.input.stick = 0; knob.transform = .identity }
            if t === tossTouch { tossTouch = nil; game.input.toss = false }
            if t === fireTouch { fireTouch = nil; game.input.fire = false }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
}
