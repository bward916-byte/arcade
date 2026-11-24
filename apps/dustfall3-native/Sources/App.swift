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
    private let fireIcon = UIImageView()
    private let coinBtn = UIView()
    private let coinIcon = UIImageView()
    private let newBtn = UIButton(type: .system)
    private let mapBtn = UIButton(type: .system)
    private let mapBox = UIView()
    private var mapChoose = false
    private var hintH: CGFloat = 62
    private let cutBox = UIView()
    private let cutArt = UIImageView()
    private let cutHead = UILabel()
    private let cutCap = UILabel()
    private let cutTap = UILabel()
    private var cutShown = ""
    private let overBox = UIView()
    private let overTitle = UILabel()
    private let overText = UILabel()
    private let overBtn = UIButton(type: .system)
    private let saveKey = "dustfall3.save"
    private var demoMode = false

    private var stickTouch: UITouch?
    private var fireTouch: UITouch?
    private var tossTouch: UITouch?
    private var stickCenter = CGPoint.zero
    private var fireCenter = CGPoint.zero
    private var coinCenter = CGPoint.zero
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

    /// A revolver, drawn rather than shipped as a picture.
    private func gunImage() -> UIImage {
        return UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48)).image { ctx in
            let c = ctx.cgContext
            cream.setFill(); cream.setStroke()
            c.fill(CGRect(x: 3, y: 15, width: 24, height: 6))            // barrel
            c.fill(CGRect(x: 4, y: 12, width: 2.5, height: 3))           // front sight
            UIBezierPath(roundedRect: CGRect(x: 23, y: 12, width: 14, height: 13), cornerRadius: 3).fill()
            let h = UIBezierPath()                                       // hammer
            h.move(to: CGPoint(x: 36, y: 13)); h.addLine(to: CGPoint(x: 42, y: 8)); h.addLine(to: CGPoint(x: 44, y: 12)); h.addLine(to: CGPoint(x: 38, y: 18)); h.close(); h.fill()
            let g = UIBezierPath()                                       // grip
            g.move(to: CGPoint(x: 30, y: 23)); g.addLine(to: CGPoint(x: 40, y: 20)); g.addLine(to: CGPoint(x: 46, y: 39)); g.addLine(to: CGPoint(x: 36, y: 43)); g.close(); g.fill()
            c.setLineWidth(2)
            c.strokeEllipse(in: CGRect(x: 22, y: 24, width: 10, height: 9))   // trigger guard
            dark.setFill()
            c.fill(CGRect(x: 26, y: 15.5, width: 8, height: 1.5)); c.fill(CGRect(x: 26, y: 20, width: 8, height: 1.5))
        }
    }

    private func coinImage() -> UIImage {
        return UIGraphicsImageRenderer(size: CGSize(width: 44, height: 44)).image { ctx in
            let c = ctx.cgContext
            UIColor(red: 0.72, green: 0.53, blue: 0.16, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 4, y: 4, width: 36, height: 36))
            gold.setFill()
            c.fillEllipse(in: CGRect(x: 6, y: 5, width: 32, height: 32))
            UIColor(red: 0.72, green: 0.53, blue: 0.16, alpha: 1).setStroke()
            c.setLineWidth(2)
            c.strokeEllipse(in: CGRect(x: 11, y: 10, width: 22, height: 22))
            UIColor(red: 1, green: 0.96, blue: 0.78, alpha: 0.9).setFill()
            c.fillEllipse(in: CGRect(x: 12, y: 9, width: 7, height: 5))
        }
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
        fireIcon.image = gunImage()
        fireIcon.contentMode = .center
        fireBtn.addSubview(fireIcon)
        view.addSubview(fireBtn)
        coinBtn.isUserInteractionEnabled = false
        coinBtn.backgroundColor = UIColor(red: 0.3, green: 0.2, blue: 0.08, alpha: 0.7)
        coinBtn.layer.borderColor = UIColor(white: 1, alpha: 0.45).cgColor
        coinBtn.layer.borderWidth = 2
        coinIcon.image = coinImage()
        coinIcon.contentMode = .center
        coinBtn.addSubview(coinIcon)
        view.addSubview(coinBtn)
        game.onSave = { [weak self] in self?.saveGame() }

        pill(purse, 17); pill(folkLabel, 15); pill(ammoLabel, 15); pill(dayLabel, 15)
        pill(hint, 15); pill(info, 14)
        hint.numberOfLines = 0
        hint.adjustsFontSizeToFitWidth = false
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
        startBtn.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        style(newBtn, "New game", primary: false)
        newBtn.addTarget(self, action: #selector(startGame), for: .touchUpInside)
        titleBox.addSubview(titleName); titleBox.addSubview(titleSub); titleBox.addSubview(startBtn); titleBox.addSubview(newBtn)
        startBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        refreshTitle()
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
        style(mapBtn, "Map", primary: false)
        mapBtn.addTarget(self, action: #selector(openMap), for: .touchUpInside)
        pauseBox.addSubview(pauseTitle); pauseBox.addSubview(resumeBtn); pauseBox.addSubview(soundBtn); pauseBox.addSubview(restartBtn); pauseBox.addSubview(mapBtn)
        view.addSubview(pauseBox)
        mapBox.backgroundColor = UIColor(red: 0.1, green: 0.06, blue: 0.04, alpha: 0.94)
        mapBox.isHidden = true
        view.addSubview(mapBox)
        // story scenes: a picture, a heading, a line, and a tap to go on
        cutBox.backgroundColor = UIColor(red: 0.06, green: 0.04, blue: 0.03, alpha: 0.96)
        cutBox.isHidden = true
        cutArt.layer.magnificationFilter = .nearest
        cutArt.contentMode = .scaleAspectFit
        cutArt.layer.borderColor = gold.cgColor
        cutArt.layer.borderWidth = 2
        cutHead.font = serif(22); cutHead.textColor = gold; cutHead.textAlignment = .center; cutHead.adjustsFontSizeToFitWidth = true
        cutCap.font = serif(16, bold: false); cutCap.textColor = cream; cutCap.textAlignment = .center; cutCap.numberOfLines = 0
        cutTap.text = "Tap to continue"; cutTap.font = serif(12, bold: false); cutTap.textColor = cream.withAlphaComponent(0.6); cutTap.textAlignment = .center
        cutBox.addSubview(cutArt); cutBox.addSubview(cutHead); cutBox.addSubview(cutCap); cutBox.addSubview(cutTap)
        cutBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(nextBeat)))
        view.addSubview(cutBox)
        // run out of town
        overBox.backgroundColor = UIColor(red: 0.08, green: 0.04, blue: 0.03, alpha: 0.88)
        overBox.isHidden = true
        overTitle.text = "Run out of town"; overTitle.font = serif(34); overTitle.textColor = gold; overTitle.textAlignment = .center
        overText.font = serif(16, bold: false); overText.textColor = cream; overText.textAlignment = .center; overText.numberOfLines = 0
        style(overBtn, "Ride again", primary: true)
        overBtn.addTarget(self, action: #selector(rideAgain), for: .touchUpInside)
        overBox.addSubview(overTitle); overBox.addSubview(overText); overBox.addSubview(overBtn)
        view.addSubview(overBox)

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
        purse.frame = CGRect(x: l, y: top, width: 92, height: 30)
        folkLabel.frame = CGRect(x: l + 98, y: top, width: 74, height: 30)
        ammoLabel.frame = CGRect(x: l + 178, y: top, width: 96, height: 30)
        menuBtn.frame = CGRect(x: bw - r - 70, y: top, width: 70, height: 32)
        dayLabel.frame = CGRect(x: bw - r - 70 - 166, y: top, width: 160, height: 30)
        let hw = min(bw - l - r - 40, 520)
        hint.frame = CGRect(x: (bw - hw) / 2, y: top + 38, width: hw, height: hintH)
        fireCenter = CGPoint(x: bw - r - 58, y: bh - bot - 62)
        coinCenter = CGPoint(x: fireCenter.x - 96, y: fireCenter.y + 8)
        let iw = max(160, min(bw * 0.5, 420, 2 * (coinCenter.x - 46 - bw / 2)))
        info.frame = CGRect(x: (bw - iw) / 2, y: bh - bot - 44, width: iw, height: 40)
        stickCenter = CGPoint(x: l + 74, y: bh - bot - 70)
        stickRing.frame = CGRect(x: stickCenter.x - 54, y: stickCenter.y - 54, width: 108, height: 108)
        stickRing.layer.cornerRadius = 54
        knob.bounds = CGRect(x: 0, y: 0, width: 46, height: 46)
        knob.center = stickCenter
        knob.layer.cornerRadius = 23
        fireBtn.frame = CGRect(x: fireCenter.x - 40, y: fireCenter.y - 40, width: 80, height: 80)
        fireBtn.layer.cornerRadius = 40
        fireIcon.frame = fireBtn.bounds
        coinBtn.frame = CGRect(x: coinCenter.x - 36, y: coinCenter.y - 36, width: 72, height: 72)
        coinBtn.layer.cornerRadius = 36
        coinIcon.frame = coinBtn.bounds
        newBtn.frame = CGRect(x: bw / 2 - 150, y: bh * 0.16 + 196, width: 300, height: 42)
        titleBox.frame = view.bounds
        titleName.frame = CGRect(x: 20, y: bh * 0.16, width: bw - 40, height: 70)
        titleSub.frame = CGRect(x: 40, y: bh * 0.16 + 74, width: bw - 80, height: 48)
        startBtn.frame = CGRect(x: bw / 2 - 150, y: bh * 0.16 + 136, width: 300, height: 52)
        pauseBox.frame = view.bounds
        pauseTitle.frame = CGRect(x: 0, y: bh * 0.12, width: bw, height: 40)
        resumeBtn.frame = CGRect(x: bw / 2 - 120, y: bh * 0.12 + 54, width: 240, height: 50)
        soundBtn.frame = CGRect(x: bw / 2 - 120, y: bh * 0.12 + 114, width: 240, height: 44)
        soundBtn.frame = CGRect(x: bw / 2 - 120, y: bh * 0.12 + 114, width: 116, height: 44)
        mapBtn.frame = CGRect(x: bw / 2 + 4, y: bh * 0.12 + 114, width: 116, height: 44)
        restartBtn.frame = CGRect(x: bw / 2 - 120, y: bh * 0.12 + 166, width: 240, height: 44)
        mapBox.frame = view.bounds
        cutBox.frame = view.bounds
        overBox.frame = view.bounds
        overTitle.frame = CGRect(x: 0, y: bh * 0.2, width: bw, height: 44)
        overText.frame = CGRect(x: 40, y: bh * 0.2 + 50, width: bw - 80, height: 50)
        overBtn.frame = CGRect(x: bw / 2 - 110, y: bh * 0.2 + 112, width: 220, height: 50)
        let ah = bh * 0.52, aw = ah * 150 / 84
        cutArt.frame = CGRect(x: (bw - aw) / 2, y: bh * 0.06, width: aw, height: ah)
        cutHead.frame = CGRect(x: 30, y: bh * 0.06 + ah + 6, width: bw - 60, height: 30)
        let cm = max(l, 40)
        cutCap.frame = CGRect(x: cm, y: bh * 0.06 + ah + 36, width: bw - 2 * cm, height: bh - (bh * 0.06 + ah + 36) - 26)
        cutTap.frame = CGRect(x: 0, y: bh - 24, width: bw, height: 18)
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
        game.cam = clampD(game.px - game.W / 2, WEST, WORLD - game.W)
        renderer = Renderer(game: game, canvas: cv)
        if !demoDone && sw > sh {
            demoDone = true
            let args = ProcessInfo.processInfo.arguments
            for name in ["day", "night", "train", "snow", "storm", "map", "duel", "coach", "west", "west2", "fire", "yard", "over"] where args.contains("-demo-" + name) { demoMode = true; game.demo(name) }
            if args.contains("-demo-map") { showMap(choose: true) }
            if args.contains("-demo-cut") { demoMode = true; game.demo("day"); game.cut = [STORY["a4"]![1]] }
            if args.contains("-demo-cut2") { demoMode = true; game.demo("day"); game.cut = [STORY["s2"]![1]] }
        }
    }

    func setPaused(_ p: Bool) {
        paused = p
        last = 0
        if !p { sound.resume() }
        if p { saveGame() }
        if p && game.state == .play && !userPaused { openMenu() }
    }

    // ---------- the saved game: written at every dawn, when something is built, and whenever the app is left
    private func saveGame() {
        if demoMode || game.state != .play || game.tripT >= 0 || game.over { return }
        if let d = try? JSONEncoder().encode(game.snapshot()) { UserDefaults.standard.set(d, forKey: saveKey) }
    }
    private func loadSave() -> SaveData? {
        guard let d = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(SaveData.self, from: d)
    }
    private func refreshTitle() {
        if let s = loadSave() {
            let key = s.place ?? stageOf(max(0, s.town))[0]
            startBtn.setTitle("Continue: day \(s.day), \(nice(PLACES[key]?.name ?? "Dustfall"))", for: .normal)
            newBtn.isHidden = false
        } else {
            startBtn.setTitle("Ride in", for: .normal)
            newBtn.isHidden = true
        }
    }
    private func clearTouches() {
        stickTouch = nil; fireTouch = nil; tossTouch = nil; tStick = 0; tToss = false; tFire = false
        tossLatch = false; fireLatch = false
        knob.center = stickCenter
    }

    @objc private func startTapped() {
        guard let s = loadSave() else { startGame(); return }
        sound.start()
        game.restore(s)
        clearTouches()
    }

    @objc private func startGame() {
        UserDefaults.standard.removeObject(forKey: saveKey)
        sound.start()
        game.start()
        clearTouches()
    }

    @objc private func openMenu() {
        if game.state != .play { return }
        userPaused = true
        pauseBox.isHidden = false
        pauseTitle.text = "Paused: \(nice(game.townName)), day \(game.day)"
        clearTouches()
        saveGame()
    }

    @objc private func closeMenu() {
        userPaused = false
        pauseBox.isHidden = true
        last = 0
        sound.resume()
    }

    // ---------- the territory: every stage of the line and the places at each, the way you came, and the choice at a fork
    private func showMap(choose: Bool) {
        mapChoose = choose
        for v in mapBox.subviews { v.removeFromSuperview() }
        mapBox.frame = view.bounds
        mapBox.isHidden = false
        let bw = view.bounds.width, bh = view.bounds.height
        let ins = view.safeAreaInsets
        let l = max(ins.left, 16), r = max(ins.right, 16)
        let head = UILabel(frame: CGRect(x: 0, y: 12, width: bw, height: 30))
        head.text = choose ? "The line forks. Where to?" : "The territory"
        head.font = serif(22); head.textColor = gold; head.textAlignment = .center
        mapBox.addSubview(head)
        let n = STAGES.count
        let cur = game.town % n, lap = game.town / n, nxt = (cur + 1) % n
        let cw = (bw - l - r) / CGFloat(n)
        let rowH = (bh - 84 - 50) / 2
        for (i, opts) in STAGES.enumerated() {
            let x = l + CGFloat(i) * cw
            let hd = UILabel(frame: CGRect(x: x + 2, y: 46, width: cw - 4, height: 30))
            hd.text = STAGE_NEW[i]; hd.font = serif(11, bold: false); hd.textColor = cream.withAlphaComponent(0.75)
            hd.textAlignment = .center; hd.numberOfLines = 2
            mapBox.addSubview(hd)
            for (k, key) in opts.enumerated() {
                guard let pl = PLACES[key] else { continue }
                let y = 82 + CGFloat(k) * rowH + (opts.count == 1 ? rowH / 2 : 0)
                let li = lap * n + i
                let been = i < cur && li < game.log.count && game.log[li] == key
                let hereNow = i == cur && key == game.place
                let pick = choose && i == nxt
                let b = UIButton(type: .system)
                style(b, "", primary: pick)
                b.frame = CGRect(x: x + 4, y: y, width: cw - 8, height: 48)
                let second = hereNow ? "Here, day \(game.day - game.day0)" : (been ? "Rebuilt" : pl.land)
                b.setTitle(nice(pl.name) + "\n" + second, for: .normal)
                b.titleLabel?.numberOfLines = 2
                b.titleLabel?.textAlignment = .center
                b.titleLabel?.font = serif(13)
                b.isUserInteractionEnabled = pick
                b.accessibilityIdentifier = key
                b.addTarget(self, action: #selector(pickPlace(_:)), for: .touchUpInside)
                if hereNow { b.layer.borderColor = gold.cgColor; b.layer.borderWidth = 2 }
                if !pick && !hereNow && !been { b.alpha = 0.5 }
                mapBox.addSubview(b)
                if pick || hereNow {
                    let nt = UILabel(frame: CGRect(x: x + 4, y: y + 50, width: cw - 8, height: min(rowH - 54, 60)))
                    nt.text = pl.note; nt.font = serif(10.5, bold: false); nt.textColor = cream
                    nt.textAlignment = .center; nt.numberOfLines = 0; nt.adjustsFontSizeToFitWidth = true; nt.minimumScaleFactor = 0.7
                    mapBox.addSubview(nt)
                }
            }
        }
        if !choose {
            let back = UIButton(type: .system)
            style(back, "Back", primary: true)
            back.frame = CGRect(x: bw / 2 - 80, y: bh - 50, width: 160, height: 40)
            back.addTarget(self, action: #selector(closeMap), for: .touchUpInside)
            mapBox.addSubview(back)
        } else {
            let ft = UILabel(frame: CGRect(x: 0, y: bh - 40, width: bw, height: 24))
            ft.text = "You step off with \(game.carryOut()) coins either way."
            ft.font = serif(13, bold: false); ft.textColor = cream; ft.textAlignment = .center
            mapBox.addSubview(ft)
        }
    }
    @objc private func nextBeat() { if !game.cut.isEmpty { game.cut.removeFirst() } }
    @objc private func openMap() { showMap(choose: false) }
    @objc private func closeMap() { mapBox.isHidden = true }
    @objc private func pickPlace(_ b: UIButton) {
        guard mapChoose, let key = b.accessibilityIdentifier else { return }
        mapBox.isHidden = true
        mapChoose = false
        game.arrive(key)
        last = 0
    }

    @objc private func toggleSound() {
        sound.muted = !sound.muted
        UserDefaults.standard.set(sound.muted, forKey: "dustfall3.muted")
        soundBtn.setTitle(sound.muted ? "Sound: off" : "Sound: on", for: .normal)
    }

    @objc private func rideAgain() {
        overBox.isHidden = true
        UserDefaults.standard.removeObject(forKey: saveKey)
        game.reset()
        refreshTitle()
    }

    @objc private func restart() {
        closeMenu()
        UserDefaults.standard.removeObject(forKey: saveKey)
        game.reset()
        refreshTitle()
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
        if game.choosing && mapBox.isHidden { showMap(choose: true) }
        if game.over && overBox.isHidden {
            UserDefaults.standard.removeObject(forKey: saveKey)
            overText.text = "They caught you without a coin to your name. You lasted \(game.day) \(game.day > 1 ? "days" : "day")."
            overBox.isHidden = false
            clearTouches()
        }
        if let bt = game.cut.first {
            let key = bt.head + bt.cap
            if key != cutShown {
                cutShown = key
                if let img = renderer?.art(bt) { cutArt.image = UIImage(cgImage: img) }
                cutHead.text = bt.head; cutCap.text = bt.cap
                clearTouches()
            }
            cutBox.isHidden = false
        } else if !cutBox.isHidden { cutBox.isHidden = true; cutShown = ""; last = 0 }
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
        for v in [purse, folkLabel, ammoLabel, dayLabel, menuBtn, stickRing, knob, fireBtn, coinBtn] as [UIView] { v.isHidden = !playing }
        fireBtn.alpha = tFire ? 1 : 0.8
        coinBtn.alpha = tToss ? 1 : 0.8
        if !playing { hint.isHidden = true; info.isHidden = true; return }
        set(purse, "\u{25CF} \(game.coins)" + (game.bank > 0 ? " +\(game.bank)" : ""))
        set(folkLabel, "Folk \(game.folk.count)")
        set(ammoLabel, game.reloadT > 0 ? "Loading \(Int(game.reloadT.rounded(.up)))" : "Shots \(game.ammo)")
        let tm = game.dark() > 0.5 ? "night" : (game.t > 0.6 ? "dusk" : "")
        let wn = game.cloudI() > 0.2 || game.wx == 1 || (game.wx == 2) ? game.wxName() : ""
        set(dayLabel, wn.isEmpty ? "Day \(game.day)" + (tm.isEmpty ? "" : ", " + tm) : "Day \(game.day), \(wn.lowercased())")
        hint.isHidden = game.hintT <= 0 || userPaused
        if game.hintT > 0 && hint.text != game.hintText {
            // the box grows to fit what it has to say
            hint.text = game.hintText
            let w = hint.frame.width
            let h = min(view.bounds.height * 0.5, max(34, hint.sizeThatFits(CGSize(width: w - 16, height: 400)).height + 12))
            hintH = h
            hint.frame = CGRect(x: hint.frame.minX, y: hint.frame.minY, width: w, height: h)
        }
        info.isHidden = game.info.isEmpty || userPaused
        if !game.info.isEmpty { set(info, game.info) }
    }

    // ---------- touch: the left of the screen is the stick; the coin and gun buttons repeat for as long as they are held
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
            let df = hypot(p.x - fireCenter.x, p.y - fireCenter.y), dc = hypot(p.x - coinCenter.x, p.y - coinCenter.y)
            if df < 56 && df <= dc {
                if fireTouch == nil { fireTouch = t; tFire = true; fireLatch = true }
            } else if dc < 54 {
                if tossTouch == nil { tossTouch = t; tToss = true; tossLatch = true }
            }
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
