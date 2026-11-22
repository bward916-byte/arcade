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
    private let hud = HudBar()
    private let infoCard = InfoCard()
    private let jobsBox = UIView()
    private lazy var jobsPanel = panel()
    private let jobsName = UILabel()
    private let jobsNote = UILabel()
    private var jobRows: [UILabel] = []
    private var jobBtns: [UIButton] = []
    private let jobsClose = UIButton(type: .system)
    private var jobsFromPause = false
    private lazy var pausePanel = panel()
    private lazy var jumpPanel = panel()
    private lazy var overPanel = panel()
    private lazy var endPanel = panel()
    private let jumpTowns = UILabel()
    private let jumpScenes = UILabel()
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
        l.layer.cornerRadius = 10
        l.layer.borderColor = gold.withAlphaComponent(0.4).cgColor
        l.layer.borderWidth = 1
        l.layer.masksToBounds = true
    }
    /// The dark, gold-edged card every menu sits on.
    private func panel() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.15, green: 0.105, blue: 0.07, alpha: 0.96)
        v.layer.cornerRadius = 18
        v.layer.borderColor = gold.withAlphaComponent(0.85).cgColor
        v.layer.borderWidth = 2
        v.isUserInteractionEnabled = false
        return v
    }
    /// The one button a menu most wants pressed.
    private func primary(_ b: UIButton, _ size: CGFloat = 20) {
        b.setTitleColor(ink, for: .normal)
        b.titleLabel?.font = serif(size)
        b.backgroundColor = gold
        b.layer.cornerRadius = 12
        b.layer.borderColor = ink.cgColor
        b.layer.borderWidth = 2
    }
    /// Everything else: quiet, outlined in gold.
    private func secondary(_ b: UIButton, _ size: CGFloat = 15) {
        b.setTitleColor(cream, for: .normal)
        b.titleLabel?.font = serif(size)
        b.backgroundColor = ink.withAlphaComponent(0.66)
        b.layer.cornerRadius = 12
        b.layer.borderColor = gold.withAlphaComponent(0.75).cgColor
        b.layer.borderWidth = 1.5
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
        for l in [hint, card] { view.addSubview(l) }
        view.addSubview(infoCard)
        view.addSubview(hud)

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

        overBox.backgroundColor = UIColor(white: 0, alpha: 0.45)
        style(overName, 28, gold, .center)
        overName.text = "Run out of town"
        style(overText, 15, cream, .center)
        overText.numberOfLines = 2
        overText.adjustsFontSizeToFitWidth = true
        overText.minimumScaleFactor = 0.7
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

        button(pauseBtn, "")
        pauseBtn.backgroundColor = gold.withAlphaComponent(0.9)
        let bars = CAShapeLayer()
        let bp = UIBezierPath(roundedRect: CGRect(x: 9.5, y: 8.5, width: 4, height: 13), cornerRadius: 1.5)
        bp.append(UIBezierPath(roundedRect: CGRect(x: 16.5, y: 8.5, width: 4, height: 13), cornerRadius: 1.5))
        bars.path = bp.cgPath
        bars.fillColor = ink.cgColor
        pauseBtn.layer.addSublayer(bars)
        pauseBtn.addTarget(self, action: #selector(pauseTapped), for: .touchUpInside)
        view.addSubview(pauseBtn)
        pauseBox.backgroundColor = UIColor(white: 0, alpha: 0.45)
        style(pauseName, 26, gold, .center)
        pauseName.text = "Paused"
        button(resumeBtn, "Resume")
        resumeBtn.addTarget(self, action: #selector(resumeTapped), for: .touchUpInside)
        button(soundBtn, "Sound: on")
        soundBtn.addTarget(self, action: #selector(soundTapped), for: .touchUpInside)
        button(quitBtn, "Save and quit to title")
        quitBtn.titleLabel?.font = serif(17)
        quitBtn.addTarget(self, action: #selector(quitTapped), for: .touchUpInside)
        button(freeBtn, "People and jobs")
        freeBtn.titleLabel?.font = serif(15)
        freeBtn.titleLabel?.numberOfLines = 2
        freeBtn.titleLabel?.textAlignment = .center
        freeBtn.addTarget(self, action: #selector(jobsFromMenu), for: .touchUpInside)
        button(detailBtn, "Detail: full")
        detailBtn.addTarget(self, action: #selector(detailTapped), for: .touchUpInside)
        style(ruleLabel, 12, cream.withAlphaComponent(0.85), .center)
        ruleLabel.numberOfLines = 2
        ruleLabel.adjustsFontSizeToFitWidth = true
        ruleLabel.minimumScaleFactor = 0.7
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
        jumpBox.backgroundColor = UIColor(white: 0, alpha: 0.45)
        style(jumpName, 24, gold, .center)
        jumpName.text = "Towns and scenes"
        style(jumpTowns, 13, cream.withAlphaComponent(0.8), .left)
        jumpTowns.text = "Start at a town (for testing)"
        style(jumpScenes, 13, cream.withAlphaComponent(0.8), .left)
        jumpScenes.text = "Watch a scene"
        for v in [jumpName, jumpTowns, jumpScenes] { jumpBox.addSubview(v) }
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
        endBox.backgroundColor = UIColor(white: 0, alpha: 0.4)
        style(endName, 28, gold, .center)
        endName.text = "The river remembers"
        style(endStats, 14, cream, .center)
        endStats.adjustsFontSizeToFitWidth = true
        endStats.minimumScaleFactor = 0.7
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
        // the jobs list: one row per trade, with a button that sends one of them back to plain villager
        jobsBox.backgroundColor = UIColor(white: 0, alpha: 0.45)
        jobsBox.addSubview(jobsPanel)
        style(jobsName, 24, gold, .center)
        jobsName.text = "People and jobs"
        style(jobsNote, 12, cream.withAlphaComponent(0.85), .center)
        jobsNote.numberOfLines = 2
        jobsNote.text = "Releasing someone makes them a plain villager again, free to build."
        jobsBox.addSubview(jobsName); jobsBox.addSubview(jobsNote)
        for i in 0..<4 {
            let l = UILabel()
            style(l, 15, cream, .left)
            l.numberOfLines = 2
            l.adjustsFontSizeToFitWidth = true
            l.minimumScaleFactor = 0.7
            jobsBox.addSubview(l)
            jobRows.append(l)
            if i < 3 {
                let bt = UIButton(type: .system)
                button(bt, "Release one")
                secondary(bt, 14)
                bt.tag = i
                bt.addTarget(self, action: #selector(releaseTapped(_:)), for: .touchUpInside)
                jobsBox.addSubview(bt)
                jobBtns.append(bt)
            }
        }
        button(jobsClose, "Done")
        primary(jobsClose, 18)
        jobsClose.addTarget(self, action: #selector(jobsDone), for: .touchUpInside)
        jobsBox.addSubview(jobsClose)
        jobsBox.isHidden = true
        view.addSubview(jobsBox)
        pauseBox.insertSubview(pausePanel, at: 0)
        jumpBox.insertSubview(jumpPanel, at: 0)
        overBox.insertSubview(overPanel, at: 0)
        endBox.insertSubview(endPanel, at: 0)
        for bt in [resumeBtn, contBtn, dawnBtn, sailBtn] { primary(bt) }
        sailBtn.titleLabel?.font = serif(16)
        dawnBtn.titleLabel?.font = serif(17)
        for bt in [soundBtn, detailBtn, sharpBtn, quitBtn, hardBtn, moreBtn, endNewBtn] { secondary(bt) }
        secondary(freeBtn, 13)
        for bt in jumpBtns {
            secondary(bt, 13)
            bt.titleLabel?.minimumScaleFactor = 0.7
            bt.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        }
        for bt in [soundBtn, detailBtn, sharpBtn, quitBtn, hardBtn, moreBtn, endNewBtn, freeBtn] { bt.titleLabel?.adjustsFontSizeToFitWidth = true }

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
        hud.frame = CGRect(x: 0, y: 0, width: b.width, height: 36)
        hud.leftInset = left + 2
        hud.rightInset = right + 40
        pauseBtn.frame = CGRect(x: b.width - right - 34, y: 2.5, width: 30, height: 30)
        pauseBtn.layer.cornerRadius = 15
        hint.frame = CGRect(x: b.width * 0.5 - 250, y: 38, width: 500, height: 40)
        let infoW = min(b.width - 2 * (left + 160), 560)
        info.frame = CGRect(x: b.width * 0.5 - infoW / 2, y: b.height - bottom - 44, width: infoW, height: 30)
        let cardW = min(b.width - 2 * (left + 168), 440)
        infoCard.frame = CGRect(x: b.width * 0.5 - cardW / 2, y: b.height - bottom - 62, width: cardW, height: 46)
        jobsBox.frame = b
        let qw = min(b.width - left - right - 16, 520), qh = min(b.height - 12, 316)
        let qx = (b.width - qw) / 2, qy = (b.height - qh) / 2
        jobsPanel.frame = CGRect(x: qx, y: qy, width: qw, height: qh)
        jobsName.frame = CGRect(x: qx, y: qy + 10, width: qw, height: 30)
        for (i, l) in jobRows.enumerated() {
            l.frame = CGRect(x: qx + 22, y: qy + 46 + CGFloat(i) * 44, width: qw - 44 - 150, height: 40)
            if i < 3 { jobBtns[i].frame = CGRect(x: qx + qw - 22 - 140, y: qy + 48 + CGFloat(i) * 44, width: 140, height: 36) }
        }
        jobsNote.frame = CGRect(x: qx + 20, y: qy + qh - 84, width: qw - 40, height: 30)
        jobsClose.frame = CGRect(x: qx + qw / 2 - 90, y: qy + qh - 52, width: 180, height: 40)
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
        hardBtn.isHidden = !hardOpen
        goBtn.setTitle(saved ? "New game" : "Ride in", for: .normal)
        if saved { secondary(goBtn, 16) } else { primary(goBtn) }
        // one centred row, the main button widest
        var row: [(UIButton, CGFloat)] = [(moreBtn, 168)]
        if saved { row.append((contBtn, 190)) }
        row.append((goBtn, saved ? 140 : 190))
        if hardOpen { row.append((hardBtn, 150)) }
        let gap: CGFloat = 10
        let total = row.reduce(CGFloat(0)) { $0 + $1.1 } + gap * CGFloat(row.count - 1)
        let fit = min(1, (b.width - left - right - 16) / total)
        var rx = (b.width - total * fit) / 2
        for (bt, w) in row {
            bt.frame = CGRect(x: rx, y: b.height - bottom - 76, width: w * fit, height: 48)
            rx += (w + gap) * fit
        }
        titleNote.frame = CGRect(x: 20, y: b.height - bottom - 24, width: b.width - 40, height: 18)

        pauseBox.frame = b
        let pw = min(b.width - left - right - 16, 600), ph = min(b.height - 12, 272)
        let px = (b.width - pw) / 2, py = (b.height - ph) / 2
        pausePanel.frame = CGRect(x: px, y: py, width: pw, height: ph)
        pauseName.frame = CGRect(x: px, y: py + 10, width: pw, height: 32)
        ruleLabel.frame = CGRect(x: px + 20, y: py + 44, width: pw - 40, height: 36)
        resumeBtn.frame = CGRect(x: px + 20, y: py + 88, width: pw - 40, height: 46)
        let tw = (pw - 40 - 16) / 3
        for (i, bt) in [soundBtn, detailBtn, sharpBtn].enumerated() {
            bt.frame = CGRect(x: px + 20 + CGFloat(i) * (tw + 8), y: py + 144, width: tw, height: 46)
        }
        let fw = (pw - 48) * 0.6
        freeBtn.frame = CGRect(x: px + 20, y: py + 200, width: fw, height: 56)
        quitBtn.frame = CGRect(x: px + 28 + fw, y: py + 200, width: pw - 48 - fw, height: 56)

        jumpBox.frame = b
        let jw = b.width - left - right - 16, jh = min(b.height - 12, 250)
        let jx = (b.width - jw) / 2, jy = (b.height - jh) / 2
        jumpPanel.frame = CGRect(x: jx, y: jy, width: jw, height: jh)
        jumpName.frame = CGRect(x: jx, y: jy + 10, width: jw, height: 30)
        jumpTowns.frame = CGRect(x: jx + 18, y: jy + 44, width: 260, height: 18)
        jumpScenes.frame = CGRect(x: jx + 18, y: jy + 116, width: 260, height: 18)
        let gw = (jw - 32 - 4 * 8) / 5
        for (i, bt) in jumpBtns.enumerated() {
            if i == 14 { bt.frame = CGRect(x: jx + jw - 92, y: jy + 10, width: 78, height: 30); continue }
            let r = i < 5 ? 0 : (i < 10 ? 1 : 2), col = i < 5 ? i : (i - 5) % 5
            let y = r == 0 ? jy + 66 : jy + 138 + CGFloat(r - 1) * 50
            bt.frame = CGRect(x: jx + 16 + CGFloat(col) * (gw + 8), y: y, width: gw, height: 42)
        }

        let barH = b.height * 0.13
        barTop.frame = CGRect(x: 0, y: 0, width: b.width, height: barH)
        barBottom.frame = CGRect(x: 0, y: b.height - barH - 8, width: b.width, height: barH + 8)
        caption.frame = CGRect(x: 30, y: 0, width: b.width - 60, height: barH)

        endBox.frame = b
        let ew = min(b.width - left - right - 16, 560), eh = min(b.height - 12, 320)
        let ex = (b.width - ew) / 2, ey = (b.height - eh) / 2
        endPanel.frame = CGRect(x: ex, y: ey, width: ew, height: eh)
        endName.frame = CGRect(x: ex, y: ey + 12, width: ew, height: 36)
        endStats.frame = CGRect(x: ex + 20, y: ey + 50, width: ew - 40, height: eh - 50 - 70)
        let sw2 = (ew - 48) * 0.58
        sailBtn.frame = CGRect(x: ex + 20, y: ey + eh - 60, width: sw2, height: 46)
        endNewBtn.frame = CGRect(x: ex + 28 + sw2, y: ey + eh - 60, width: ew - 48 - sw2, height: 46)

        overBox.frame = b
        let ow = min(b.width - left - right - 16, 520), oh: CGFloat = 190
        let ox = (b.width - ow) / 2, oy = (b.height - oh) / 2
        overPanel.frame = CGRect(x: ox, y: oy, width: ow, height: oh)
        overName.frame = CGRect(x: ox, y: oy + 14, width: ow, height: 38)
        overText.frame = CGRect(x: ox + 16, y: oy + 58, width: ow - 32, height: 44)
        dawnBtn.isHidden = !saved
        if saved { secondary(againBtn, 16) } else { primary(againBtn) }
        let dw = (ow - 48) * 0.6
        dawnBtn.frame = CGRect(x: ox + 20, y: oy + oh - 64, width: dw, height: 48)
        againBtn.frame = saved ? CGRect(x: ox + 28 + dw, y: oy + oh - 64, width: ow - 48 - dw, height: 48) : CGRect(x: ox + ow / 2 - 100, y: oy + oh - 64, width: 200, height: 48)
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
            if args.contains("-demo-pause") { game.demo("play"); pauseTapped() }
            if args.contains("-demo-jump") { moreTapped() }
            if args.contains("-demo-jobs") { game.demo("play"); openJobs(fromPause: false) }
            if args.contains("-demo-over") { game.demo("play"); game.state = .over }
            if args.contains("-demo-end") { game.demo("play"); game.state = .end }
            if args.contains("-demo-cave") { game.demo("cave") }
            if args.contains("-demo-title2") {
                UserDefaults.standard.set(true, forKey: "dunefall.hardOpen")
                UserDefaults.standard.set(4320, forKey: "dunefall.best")
                game.demo("play"); save(); game.reset(); view.setNeedsLayout()
            }
            for key in ["raid", "cave", "fest", "obelisk", "sphinx", "eclipse", "ufo", "haboob", "btemple0", "bazaar", "temple", "deep", "btemple"] where args.contains("-demo-pan-" + key) {
                game.demo("pan-" + key)
            }
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
    // ---------- the jobs list
    private let jobRoles: [Role] = [.digger, .herder, .guard]
    private func refreshJobs() {
        let what = ["Diggers", "Herders", "Guards"]
        let does = ["bring gold from the quarry", "keep goats that pay each dawn", "hold the gates at night"]
        for i in 0..<3 {
            let n = game.head(jobRoles[i])
            jobRows[i].text = "\(what[i]): \(n)\n" + does[i]
            jobBtns[i].isEnabled = n > 0
            jobBtns[i].alpha = n > 0 ? 1 : 0.35
        }
        jobRows[3].text = "Free hands: \(game.head(.folk)) of \(game.folk.count) people\nThey build, and take tools from the racks"
    }
    private func openJobs(fromPause: Bool) {
        if game.state != .play { return }
        jobsFromPause = fromPause
        userPaused = true
        clearTouches()
        refreshJobs()
        pauseBox.isHidden = true
        jobsBox.isHidden = false
    }
    @objc private func jobsFromMenu() { openJobs(fromPause: true) }
    @objc private func releaseTapped(_ sender: UIButton) {
        if game.release(jobRoles[sender.tag]) { buzz(1) }
        refreshJobs()
    }
    @objc private func jobsDone() {
        jobsBox.isHidden = true
        if jobsFromPause { pauseBox.isHidden = false; freeBtn.setTitle("People and jobs" + crew(), for: .normal) } else { userPaused = false; last = 0 }
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
        freeBtn.setTitle("People and jobs" + crew(), for: .normal)
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
        for v in [hud, pad, fireBtn, pauseBtn] as [UIView] { v.isHidden = !playing && game.state != .over }
        if game.state == .over && dawnBtn.isHidden == (loadSave() != nil) { view.setNeedsLayout() }
        let p = game.player
        hud.coins = p.coins
        hud.vault = game.B(.bank).level > 0 ? game.bank : -1
        hud.arrows = p.ammo
        hud.arrowMax = max(6, p.ammo)
        hud.restring = p.rl > 0
        hud.people = game.folk.count
        hud.cap = game.popCap
        hud.free = game.head(.folk)
        hud.ankh = game.ankh
        hud.night = game.dark > 0.5
        hud.dayText = (game.dark > 0.5 ? "Night " : "Day ") + "\(game.ln)"
        hud.frac = game.t
        hud.refresh()
        info.isHidden = true
        if playing, let line = game.infoLine() {
            if let m = game.infoMeter() { infoCard.show(line.0, line.1, level: m.level, top: m.top, paid: m.paid, cost: m.cost) } else { infoCard.show(line.0, line.1) }
            infoCard.isHidden = false
        } else if playing && !game.raiders.contains(where: { $0.state == .raid }) {
            if let st = game.tourStep { infoCard.show("STEP \(st + 1) OF 6", game.nextGoal()) } else { infoCard.show("NEXT", game.nextGoal()) }
            infoCard.isHidden = false
        } else { infoCard.isHidden = true }
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
            if !hud.isHidden && game.state == .play && game.scene == nil && hud.peopleRect.contains(p) {
                openJobs(fromPause: false)
                return
            }
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
