import GameController
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
    private let dawnBtn = UIButton(type: .system)
    private let contBtn = UIButton(type: .system)
    private let pauseBtn = UIButton(type: .system)
    private let pauseBox = UIView()
    private let pauseName = UILabel()
    private let resumeBtn = UIButton(type: .system)
    private let soundBtn = UIButton(type: .system)
    private let quitBtn = UIButton(type: .system)
    private var userPaused = false
    private let freeBtn = UIButton(type: .system)
    private let barTop = UIView()
    private let barBottom = UIView()
    private let caption = UILabel()
    private let endBox = UIView()
    private let endName = UILabel()
    private let endStats = UILabel()
    private let sailBtn = UIButton(type: .system)
    private let endNewBtn = UIButton(type: .system)
    private let detailBtn = UIButton(type: .system)
    private let ruleLabel = UILabel()
    private let hardBtn = UIButton(type: .system)
    private let moreBtn = UIButton(type: .system)
    private let sharpBtn = UIButton(type: .system)
    /// 2 draws at the screen's own resolution, 1 at half of it, 0 at the old blocky size.
    private var sharp = UserDefaults.standard.object(forKey: "dunefall.sharp") == nil ? 2 : UserDefaults.standard.integer(forKey: "dunefall.sharp")
    private var curScale = 0
    private let jumpBox = UIView()
    private let jumpName = UILabel()
    private var jumpBtns: [UIButton] = []
    private let sceneKeys = ["intro", "bazaar", "temple", "obelisk", "sphinx", "tomb", "deep", "btemple", "raid"]
    private let sceneNames = ["Intro", "Bazaar", "Temple", "Obelisk", "Sphinx", "Tomb", "Deep room", "Buried temple", "First raid"]
    private var hardOn = false
    private var scored = false
    private var slowT = 0.0
    private let autoLow = !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-demo") })
    private var best: Int { return UserDefaults.standard.integer(forKey: "dunefall.best") }
    private var hardOpen: Bool { return UserDefaults.standard.bool(forKey: "dunefall.hardOpen") }
    private var tStick = 0.0
    private var tToss = false
    private var tFire = false
    private var padMenuWas = false
    private let tapLight = UIImpactFeedbackGenerator(style: .light)
    private let tapMedium = UIImpactFeedbackGenerator(style: .medium)
    private let tapHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let tapDone = UINotificationFeedbackGenerator()
    private let saveKey = "dunefall.native.save"

    private var stickTouch: UITouch?
    private var tossTouch: UITouch?
    private var fireTouch: UITouch?
    private var padCenter = CGPoint.zero
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
        purse.adjustsFontSizeToFitWidth = true
        purse.minimumScaleFactor = 0.7
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
        round(fireBtn, "")
        // a drawn bow and arrow on the one button; a coin is tossed by tapping anywhere else
        let bow = UIBezierPath()
        bow.addArc(withCenter: CGPoint(x: 24, y: 32), radius: 20, startAngle: -1.25, endAngle: 1.25, clockwise: true)
        let tipX = 24 + 20 * cos(1.25), tipY = 20 * sin(1.25)
        bow.move(to: CGPoint(x: tipX, y: 32 - tipY)); bow.addLine(to: CGPoint(x: tipX, y: 32 + tipY))
        bow.move(to: CGPoint(x: 14, y: 32)); bow.addLine(to: CGPoint(x: 54, y: 32))
        bow.move(to: CGPoint(x: 46, y: 25)); bow.addLine(to: CGPoint(x: 54, y: 32)); bow.addLine(to: CGPoint(x: 46, y: 39))
        let bowLayer = CAShapeLayer()
        bowLayer.path = bow.cgPath
        bowLayer.strokeColor = ink.cgColor
        bowLayer.fillColor = UIColor.clear.cgColor
        bowLayer.lineWidth = 3
        bowLayer.lineCap = .round
        bowLayer.lineJoin = .round
        fireBtn.layer.addSublayer(bowLayer)
        view.addSubview(fireBtn)

        style(titleName, 64, gold, .center)
        titleName.text = "DUNEFALL"
        titleName.adjustsFontSizeToFitWidth = true
        style(titleTag, 17, cream, .center)
        titleTag.text = "Build a town from the sand. Hold it through the night."
        style(titleNote, 12, cream, .center)
        titleNote.text = ""
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

        button(dawnBtn, "Back to the last dawn")
        dawnBtn.titleLabel?.font = serif(17)
        dawnBtn.addTarget(self, action: #selector(resumeSave), for: .touchUpInside)
        overBox.addSubview(dawnBtn)
        button(contBtn, "Continue")
        contBtn.addTarget(self, action: #selector(resumeSave), for: .touchUpInside)
        titleBox.addSubview(contBtn)

        button(pauseBtn, "II")
        pauseBtn.titleLabel?.font = serif(15)
        pauseBtn.backgroundColor = gold.withAlphaComponent(0.8)
        pauseBtn.addTarget(self, action: #selector(pauseTapped), for: .touchUpInside)
        view.addSubview(pauseBtn)
        pauseBox.backgroundColor = ink.withAlphaComponent(0.78)
        style(pauseName, 34, gold, .center)
        pauseName.text = "Paused"
        button(resumeBtn, "Resume")
        resumeBtn.addTarget(self, action: #selector(resumeTapped), for: .touchUpInside)
        button(soundBtn, "Sound: on")
        soundBtn.addTarget(self, action: #selector(soundTapped), for: .touchUpInside)
        button(quitBtn, "Save and quit to title")
        quitBtn.titleLabel?.font = serif(17)
        quitBtn.addTarget(self, action: #selector(quitTapped), for: .touchUpInside)
        button(freeBtn, "Free a worker to build")
        freeBtn.titleLabel?.font = serif(15)
        freeBtn.titleLabel?.numberOfLines = 2
        freeBtn.titleLabel?.textAlignment = .center
        freeBtn.addTarget(self, action: #selector(freeTapped), for: .touchUpInside)
        button(detailBtn, "Detail: full")
        detailBtn.addTarget(self, action: #selector(detailTapped), for: .touchUpInside)
        style(ruleLabel, 14, cream, .center)
        ruleLabel.numberOfLines = 3
        button(sharpBtn, "Sharpness: high")
        sharpBtn.addTarget(self, action: #selector(sharpTapped), for: .touchUpInside)
        for v in [pauseName, resumeBtn, soundBtn, freeBtn, quitBtn, detailBtn, ruleLabel, sharpBtn] as [UIView] { pauseBox.addSubview(v) }
        button(hardBtn, "Hard mode: off")
        hardBtn.titleLabel?.font = serif(15)
        hardBtn.addTarget(self, action: #selector(hardTapped), for: .touchUpInside)
        titleBox.addSubview(hardBtn)
        button(moreBtn, "Towns and scenes")
        moreBtn.titleLabel?.font = serif(15)
        moreBtn.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        titleBox.addSubview(moreBtn)
        jumpBox.backgroundColor = ink.withAlphaComponent(0.9)
        style(jumpName, 20, gold, .center)
        jumpName.text = "Start at any town, or watch a scene"
        jumpBox.addSubview(jumpName)
        for i in 0..<15 {
            let bt = UIButton(type: .system)
            let name = i < 5 ? "\(i + 1). " + TOWNS[i].capitalized : (i < 14 ? sceneNames[i - 5] : "Close")
            button(bt, name)
            bt.titleLabel?.font = serif(13)
            bt.titleLabel?.adjustsFontSizeToFitWidth = true
            bt.tag = i
            bt.addTarget(self, action: #selector(jumpTapped(_:)), for: .touchUpInside)
            jumpBox.addSubview(bt)
            jumpBtns.append(bt)
        }
        jumpBox.isHidden = true
        if UserDefaults.standard.object(forKey: "dunefall.low") != nil { game.low = UserDefaults.standard.bool(forKey: "dunefall.low") }
        for bar in [barTop, barBottom] {
            bar.backgroundColor = .black
            bar.isUserInteractionEnabled = false
            bar.isHidden = true
            view.addSubview(bar)
        }
        style(caption, 16, cream, .center)
        caption.numberOfLines = 2
        barBottom.addSubview(caption)
        endBox.backgroundColor = ink.withAlphaComponent(0.6)
        style(endName, 34, gold, .center)
        endName.text = "The river remembers"
        style(endStats, 15, cream, .center)
        endStats.numberOfLines = 0
        button(sailBtn, "Sail on to a sixth town")
        sailBtn.titleLabel?.font = serif(17)
        sailBtn.addTarget(self, action: #selector(sailOn), for: .touchUpInside)
        button(endNewBtn, "New game")
        endNewBtn.addTarget(self, action: #selector(ride), for: .touchUpInside)
        for v in [endName, endStats, sailBtn, endNewBtn] as [UIView] { endBox.addSubview(v) }
        endBox.isHidden = true
        view.addSubview(endBox)
        pauseBox.isHidden = true
        view.addSubview(pauseBox)
        view.addSubview(jumpBox)

        game.onBuzz = { [weak self] k in self?.buzz(k) }
        game.onDawn = { [weak self] in self?.save() }

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
        dayLabel.frame = CGRect(x: b.width - right - 210, y: 6, width: 160, height: 22)
        pauseBtn.frame = CGRect(x: b.width - right - 40, y: 4, width: 38, height: 28)
        hint.frame = CGRect(x: b.width * 0.5 - 250, y: 32, width: 500, height: 40)
        let infoW = min(b.width - 2 * (left + 160), 560)
        info.frame = CGRect(x: b.width * 0.5 - infoW / 2, y: b.height - bottom - 44, width: infoW, height: 30)
        info.numberOfLines = 2
        info.adjustsFontSizeToFitWidth = true
        info.minimumScaleFactor = 0.6
        card.frame = CGRect(x: 0, y: b.height * 0.22, width: b.width, height: 80)

        pad.frame = CGRect(x: left + 16, y: b.height - bottom - 78, width: 132, height: 60)
        pad.layer.cornerRadius = 30
        knob.frame = CGRect(x: 66 - 23, y: 30 - 23, width: 46, height: 46)
        knob.layer.cornerRadius = 23
        padCenter = CGPoint(x: pad.frame.midX, y: pad.frame.midY)
        fireBtn.frame = CGRect(x: b.width - right - 84, y: b.height - bottom - 84, width: 64, height: 64)
        fireBtn.layer.cornerRadius = 32
        fireCenter = CGPoint(x: fireBtn.frame.midX, y: fireBtn.frame.midY)

        titleBox.frame = b
        titleName.frame = CGRect(x: 20, y: b.height * 0.06, width: b.width - 40, height: 76)
        titleTag.frame = CGRect(x: 20, y: b.height * 0.06 + 74, width: b.width - 40, height: 24)
        let saved = loadSave() != nil
        contBtn.isHidden = !saved
        if saved {
            contBtn.frame = CGRect(x: b.width * 0.5 - 190, y: b.height - bottom - 78, width: 180, height: 48)
            goBtn.frame = CGRect(x: b.width * 0.5 + 10, y: b.height - bottom - 78, width: 180, height: 48)
        } else {
            goBtn.frame = CGRect(x: b.width * 0.5 - 90, y: b.height - bottom - 78, width: 180, height: 48)
        }
        goBtn.setTitle(saved ? "New game" : "Ride in", for: .normal)
        pauseBox.frame = b
        pauseName.frame = CGRect(x: 20, y: b.height * 0.1, width: b.width - 40, height: 44)
        resumeBtn.frame = CGRect(x: b.width * 0.5 - 130, y: b.height * 0.1 + 56, width: 260, height: 46)
        soundBtn.frame = CGRect(x: b.width * 0.5 - 130, y: b.height * 0.1 + 110, width: 260, height: 46)
        pauseName.frame = CGRect(x: 20, y: b.height * 0.04, width: b.width - 40, height: 40)
        resumeBtn.frame = CGRect(x: b.width * 0.5 - 270, y: b.height * 0.04 + 52, width: 260, height: 46)
        soundBtn.frame = CGRect(x: b.width * 0.5 + 10, y: b.height * 0.04 + 52, width: 260, height: 46)
        freeBtn.frame = CGRect(x: b.width * 0.5 - 270, y: b.height * 0.04 + 108, width: 260, height: 46)
        quitBtn.frame = CGRect(x: b.width * 0.5 + 10, y: b.height * 0.04 + 108, width: 260, height: 46)
        detailBtn.frame = CGRect(x: b.width * 0.5 - 270, y: b.height * 0.04 + 164, width: 260, height: 46)
        sharpBtn.frame = CGRect(x: b.width * 0.5 + 10, y: b.height * 0.04 + 164, width: 260, height: 46)
        ruleLabel.frame = CGRect(x: 20, y: b.height * 0.04 + 216, width: b.width - 40, height: 44)
        hardBtn.frame = CGRect(x: b.width - right - 176, y: b.height - bottom - 78, width: 164, height: 48)
        hardBtn.isHidden = !hardOpen
        moreBtn.frame = CGRect(x: left + 12, y: b.height - bottom - 78, width: 170, height: 48)
        jumpBox.frame = b
        jumpName.frame = CGRect(x: 20, y: b.height * 0.06, width: b.width - 40, height: 28)
        let gw = (b.width - left - right - 24 - 4 * 8) / 5
        for (i, bt) in jumpBtns.enumerated() {
            let row = i / 5, col = i % 5
            bt.frame = CGRect(x: left + 12 + CGFloat(col) * (gw + 8), y: b.height * 0.06 + 44 + CGFloat(row) * 58 + (row > 0 ? 14 : 0), width: gw, height: 46)
        }
        let barH = b.height * 0.13
        barTop.frame = CGRect(x: 0, y: 0, width: b.width, height: barH)
        barBottom.frame = CGRect(x: 0, y: b.height - barH - 8, width: b.width, height: barH + 8)
        caption.frame = CGRect(x: 30, y: 0, width: b.width - 60, height: barH)
        endBox.frame = b
        endName.frame = CGRect(x: 20, y: b.height * 0.05, width: b.width - 40, height: 42)
        endStats.frame = CGRect(x: 20, y: b.height * 0.05 + 44, width: b.width - 40, height: b.height * 0.45)
        sailBtn.frame = CGRect(x: b.width * 0.5 - 250, y: b.height - bottom - 62, width: 260, height: 46)
        endNewBtn.frame = CGRect(x: b.width * 0.5 + 30, y: b.height - bottom - 62, width: 200, height: 46)
        titleNote.frame = CGRect(x: 20, y: b.height - bottom - 26, width: b.width - 40, height: 18)

        overBox.frame = b
        overName.frame = CGRect(x: 20, y: b.height * 0.24, width: b.width - 40, height: 44)
        overText.frame = CGRect(x: 20, y: b.height * 0.24 + 48, width: b.width - 40, height: 24)
        dawnBtn.isHidden = !saved
        dawnBtn.frame = CGRect(x: b.width * 0.5 - 230, y: b.height * 0.24 + 92, width: 240, height: 48)
        againBtn.frame = saved ? CGRect(x: b.width * 0.5 + 30, y: b.height * 0.24 + 92, width: 180, height: 48) : CGRect(x: b.width * 0.5 - 90, y: b.height * 0.24 + 92, width: 180, height: 48)
        rebuild()
    }

    /// Sizes the game bitmap the way the web version sizes its canvas: about 185 game pixels tall.
    private func rebuild() {
        let sw = Double(view.bounds.width), sh = Double(view.bounds.height)
        if sw < 50 || sh < 50 { return }
        let dpr = Double(view.window?.screen.scale ?? UIScreen.main.scale)
        let sc = max(2.0, 2 * (sh * dpr / 370).rounded())
        let w = Int(ceil(sw * dpr / sc)), h = Int(ceil(sh * dpr / sc))
        let isc = Int(sc)
        let ps = sharp >= 2 ? isc : (sharp == 1 ? max(2, isc / 2) : 2)
        if w == curW && h == curH && ps == curScale && renderer != nil { return }
        guard let cv = Canvas(w: w, h: h, scale: ps), let ov = Canvas(w: w, h: h, scale: 1) else { return }
        curW = w; curH = h; curScale = ps
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
            if args.contains("-demo-port") { game.demo("port") }
            if args.contains("-demo-oasis") { game.demo("oasis") }
            if args.contains("-demo-desert") { game.demo("desert") }
            if args.contains("-demo-scene") { game.demo("scene") }
            if args.contains("-demo-cliff") { game.demo("cliff") }
            if args.contains("-demo-last") { game.demo("last") }
            if args.contains("-demo-econ") {
                let bot = Game()
                bot.W = game.W; bot.H = game.H; bot.GY = game.GY
                var text = bot.botRun(days: 34)
                let bot2 = Game()
                bot2.W = game.W; bot2.H = game.H; bot2.GY = game.GY
                text += "\n" + bot2.botRun(days: 20, hard: true)
                if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? text.write(to: dir.appendingPathComponent("econ.txt"), atomically: true, encoding: .utf8)
                }
            }
            if args.contains("-demo-intro") { sound.start(); game.start() }
            if args.contains("-demo-fires") { game.start(); game.update(5.2); game.update(0.05) }
        }
    }

    func setPaused(_ p: Bool) {
        paused = p
        last = 0
        if !p { sound.resume() }
        if p { clearTouches(); save() }
    }

    @objc private func ride() {
        sound.start()
        game.hard = hardOn && hardOpen
        game.start()
    }
    @objc private func moreTapped() {
        jumpBox.isHidden = false
    }
    @objc private func jumpTapped(_ sender: UIButton) {
        jumpBox.isHidden = true
        let i = sender.tag
        if i >= 14 { return }
        sound.start()
        if i < 5 {
            game.hard = hardOn && hardOpen
            game.jump(i)
        } else {
            game.viewScene(sceneKeys[i - 5])
        }
    }
    @objc private func hardTapped() {
        hardOn = !hardOn
        hardBtn.setTitle(hardOn ? "Hard mode: on" : "Hard mode: off", for: .normal)
    }
    private func sharpName() -> String { return "Sharpness: " + ["low", "medium", "high"][max(0, min(2, sharp))] }
    @objc private func sharpTapped() {
        sharp = sharp <= 0 ? 2 : sharp - 1
        UserDefaults.standard.set(sharp, forKey: "dunefall.sharp")
        UserDefaults.standard.set(true, forKey: "dunefall.sharpUser")
        sharpBtn.setTitle(sharpName(), for: .normal)
        rebuild()
    }
    @objc private func detailTapped() {
        game.low = !game.low
        UserDefaults.standard.set(game.low, forKey: "dunefall.low")
        detailBtn.setTitle(game.low ? "Detail: low" : "Detail: full", for: .normal)
    }
    @objc private func resumeSave() {
        guard let d = loadSave() else { return }
        sound.start()
        game.restore(d)
    }
    @objc private func pauseTapped() {
        if game.state != .play { return }
        userPaused = true
        freeBtn.setTitle("Free a worker to build" + crew(), for: .normal)
        detailBtn.setTitle(game.low ? "Detail: low" : "Detail: full", for: .normal)
        sharpBtn.setTitle(sharpName(), for: .normal)
        ruleLabel.text = game.townName + (game.hard ? " (hard)" : "") + "\n" + TOWNRULE[game.town % 5]
        pauseBox.isHidden = false
        clearTouches()
    }
    @objc private func resumeTapped() {
        userPaused = false
        pauseBox.isHidden = true
        last = 0
    }
    @objc private func freeTapped() {
        let done = game.releaseOne()
        freeBtn.setTitle((done ? "Freed one. Free another" : "Nobody to free") + crew(), for: .normal)
    }
    private func crew() -> String {
        return "\n\(game.folk.count) people: \(game.head(.folk)) free, \(game.head(.digger)) diggers, \(game.head(.herder)) herders, \(game.head(.guard)) guards"
    }
    @objc private func sailOn() {
        game.nextTown()
    }
    @objc private func soundTapped() {
        sound.muted = !sound.muted
        soundBtn.setTitle(sound.muted ? "Sound: off" : "Sound: on", for: .normal)
    }
    @objc private func quitTapped() {
        save()
        userPaused = false
        pauseBox.isHidden = true
        game.reset()
        view.setNeedsLayout()
    }

    // The town is kept as it stood at the last dawn.
    private func save() {
        if game.state != .play { return }
        if let data = try? JSONEncoder().encode(game.snapshot()) { UserDefaults.standard.set(data, forKey: saveKey) }
    }
    private func loadSave() -> SaveData? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(SaveData.self, from: data)
    }

    private func buzz(_ k: Int) {
        switch k {
        case 0: tapLight.impactOccurred()
        case 1: tapMedium.impactOccurred()
        case 2: tapHeavy.impactOccurred()
        default: tapDone.notificationOccurred(.success)
        }
    }

    /// A paired game controller: stick or d-pad rides, A tosses, X or B looses an arrow, Y restrings, Menu pauses.
    private func readInput() {
        var stick = tStick, toss = tToss, fire = tFire
        if let pad = GCController.controllers().first?.extendedGamepad {
            let ax = Double(pad.leftThumbstick.xAxis.value)
            let dp = Double(pad.dpad.xAxis.value)
            if abs(ax) > 0.25 { stick = ax } else if abs(dp) > 0.25 { stick = dp }
            if pad.buttonA.isPressed { toss = true }
            if pad.buttonX.isPressed || pad.buttonB.isPressed { fire = true }
            if pad.buttonY.isPressed { game.input.reload = true }
            let menu = pad.buttonMenu.isPressed
            if menu && !padMenuWas {
                if game.state == .title { ride() } else if userPaused { resumeTapped() } else { pauseTapped() }
            }
            padMenuWas = menu
        }
        game.input.stick = stick
        game.input.toss = toss
        game.input.fire = fire
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let raw = last == 0 ? 1.0 / 60 : now - last
        last = now
        if paused { return }
        readInput()
        if userPaused { return }
        // if the phone cannot keep up for a few seconds, step the sharpness down, then the small detail, and say so
        if autoLow && game.state == .play && game.scene == nil {
            let canSharp = sharp > 0 && !UserDefaults.standard.bool(forKey: "dunefall.sharpUser")
            let canLow = !game.low && UserDefaults.standard.object(forKey: "dunefall.low") == nil
            if canSharp || canLow {
                slowT = max(0, slowT + (raw > 1.0 / 38 ? raw : -raw * 0.5))
                if slowT > 3 {
                    slowT = 0
                    if canSharp {
                        sharp -= 1
                        UserDefaults.standard.set(sharp, forKey: "dunefall.sharp")
                        rebuild()
                        game.hint("sharp\(sharp)", again: true, "Sharpness lowered to keep things smooth. You can change it in the pause menu.")
                    } else {
                        game.low = true
                        UserDefaults.standard.set(true, forKey: "dunefall.low")
                        game.hint("lowdetail", again: true, "Low detail is on to keep things smooth. You can change it in the pause menu.")
                    }
                }
            }
        }
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
        let cut = game.state == .play && game.scene != nil
        let sailing = game.state == .play && game.trip != nil
        let playing = game.state == .play && !cut && !sailing
        barTop.isHidden = !cut
        barBottom.isHidden = !cut
        if cut, let sc = game.scene { set(caption, sc.text) }
        endBox.isHidden = game.state != .end
        if game.state == .end {
            let st = game.stats
            set(endStats, "Towns rebuilt: \(st[3])\nDays on the road: \(game.day)\nBuildings raised: \(st[0])\nNomads who joined you: \(st[1])\nRaiders brought down: \(st[2])\nRelics: \(game.relics.isEmpty ? "none" : game.relics.sorted().joined(separator: ", "))\nCoins in hand: \(game.player.coins + game.bank)\nScore: \(game.score)\(game.hard ? " (hard)" : "")   Best: \(max(best, game.score))")
        }
        if game.state == .end || game.state == .over {
            if !scored {
                scored = true
                if game.score > best { UserDefaults.standard.set(game.score, forKey: "dunefall.best") }
                if game.state == .end && !hardOpen { UserDefaults.standard.set(true, forKey: "dunefall.hardOpen"); view.setNeedsLayout() }
            }
            if game.state == .over { set(overText, "Caught with an empty purse.   Score \(game.score), best \(best)") }
        } else if game.state == .play { scored = false }
        if game.state == .title { set(titleNote, best > 0 ? "Best run: \(best)" : "") }
        titleBox.isHidden = game.state != .title
        overBox.isHidden = game.state != .over
        for v in [purse, dayLabel, pad, fireBtn, pauseBtn] as [UIView] { v.isHidden = !playing && game.state != .over }
        if game.state == .over && dawnBtn.isHidden == (loadSave() != nil) { view.setNeedsLayout() }
        let p = game.player
        let arrows = p.rl > 0 ? "restringing" : String(repeating: "|", count: max(0, p.ammo))
        let vault = (game.B(.bank).level > 0 ? "    Vault \(game.bank)" : "") + (game.ankh ? "    Ankh" : "")
        set(purse, "Coins \(p.coins)\(vault)    Arrows \(arrows)    People \(game.folk.count) of \(game.popCap), \(game.head(.folk)) free")
        set(dayLabel, game.dark > 0.5 ? "Night \(game.ln)" : "Day \(game.ln)")
        if playing, let line = game.infoLine() {
            set(info, line.0 + "   " + line.1)
            info.textAlignment = .center
            info.isHidden = false
        } else if playing && !game.raiders.contains(where: { $0.state == .raid }) {
            if let st = game.tourStep { set(info, "Step \(st + 1) of 6: " + game.nextGoal()) } else { set(info, "Next: " + game.nextGoal()) }
            info.isHidden = false
        } else { info.isHidden = true }
        let showHint = playing && game.hintT > 0
        if showHint { set(hint, game.hintPin ? game.hintText + "  (tap to close)" : game.hintText) } else if playing && game.t < 0.2 && !game.report.isEmpty { set(hint, game.report) }
        hint.isHidden = game.cardT > 0 || !(showHint || (playing && game.t < 0.2 && !game.report.isEmpty))
        if game.state == .play && !cut && game.cardT > 0 {
            set(card, game.cardText + "\n" + game.cardSub)
            card.alpha = CGFloat(min(1, game.cardT))
            card.isHidden = false
        } else { card.isHidden = true }
        let atDock = abs(p.x - game.B(.dock).x - 60) < 90 && !game.raiders.contains(where: { abs($0.x - p.x) < 260 })
        fireBtn.alpha = game.input.fire ? 1 : (atDock ? 0.25 : (p.rl > 0 ? 0.4 : 0.8))
    }

    // ---------- touch: left side is the stick, the two round buttons toss a coin and loose an arrow
    private func moveStick(_ p: CGPoint) {
        let dx = max(-34, min(34, p.x - padCenter.x))
        tStick = Double(dx) / 34
        knob.transform = CGAffineTransform(translationX: dx, y: 0)
    }
    private func clearTouches() {
        stickTouch = nil; tossTouch = nil; fireTouch = nil
        tStick = 0; tToss = false; tFire = false
        game.input.stick = 0; game.input.toss = false; game.input.fire = false
        knob.transform = .identity
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if game.state != .play || userPaused { return }
        if game.scene != nil { game.skipScene(); return }
        if game.trip != nil { return }
        for t in touches {
            let p = t.location(in: view)
            if !hint.isHidden && hint.frame.insetBy(dx: 0, dy: -8).contains(p) {
                // a tap holds the memo on screen; a second tap puts it away
                if game.hintPin { game.hintPin = false; game.hintT = 0 } else {
                    if game.hintT <= 0 { game.hintText = game.report }
                    game.hintT = 9; game.hintPin = true
                }
                continue
            }
            if p.y < 30 && p.x < view.bounds.width * 0.6 { game.input.reload = true; continue }
            if p.x < view.bounds.width * 0.4 {
                if stickTouch == nil { stickTouch = t; moveStick(p) }
                continue
            }
            let df = hypot(p.x - fireCenter.x, p.y - fireCenter.y)
            if df < 52 {
                if fireTouch == nil { fireTouch = t; tFire = true }
            } else if tossTouch == nil { tossTouch = t; tToss = true }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches where t === stickTouch { moveStick(t.location(in: view)) }
    }
    private func lift(_ touches: Set<UITouch>) {
        for t in touches {
            if t === stickTouch { stickTouch = nil; tStick = 0; knob.transform = .identity }
            if t === tossTouch { tossTouch = nil; tToss = false }
            if t === fireTouch { fireTouch = nil; tFire = false }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { lift(touches) }
}
