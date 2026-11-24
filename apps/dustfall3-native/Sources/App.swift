import UIKit
import CoreText

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
    private let ammoView = AmmoView()
    private let dayLabel = UILabel()
    private let hint = UILabel()
    private let info = UILabel()
    private let menuBtn = UIButton(type: .system)

    private let titleBox = UIView()
    private let titleName = UILabel()
    private let titleSub = UILabel()
    private var titleLayers: [UILabel] = []
    private var numLayers: [UILabel] = []
    private let titleShade = CAGradientLayer()
    private let introTop = UIView()
    private let introBot = UIView()
    private let introCap = UILabel()
    private let introCard = UIView()
    private let introCardName = UILabel()
    private let introCardDay = UILabel()
    private let introSkip = UILabel()
    private let cutClip = UIView()
    private let cutPanel = UIView()
    private var cutT = 0.0
    private var cutN = 0
    private let cutMask = CAShapeLayer()
    private var cutIdx = 0
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

    /// Rye, the web game's display face, shipped with the app.
    private func rye(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Rye-Regular", size: size) ?? UIFont(name: "Georgia-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }

    /// One line of the title, as three stacked labels: ink, rust, then the face colour, for the web game's hard double shadow.
    private func stacked(_ into: UIView, _ make: (UIColor) -> NSAttributedString, _ face: UIColor) -> [UILabel] {
        var out: [UILabel] = []
        for col in [UIColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 1), UIColor(red: 0.54, green: 0.18, blue: 0.15, alpha: 1), face] {
            let l = UILabel()
            l.attributedText = make(col)
            l.textAlignment = .center
            l.adjustsFontSizeToFitWidth = true
            l.minimumScaleFactor = 0.4
            into.addSubview(l)
            out.append(l)
        }
        return out
    }

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
        b.titleLabel?.font = rye(primary ? 19 : 16)
        b.setTitleColor(primary ? dark : cream, for: .normal)
        b.backgroundColor = primary ? gold : UIColor(white: 1, alpha: 0.14)
        b.layer.cornerRadius = 10
        b.layer.borderWidth = primary ? 0 : 1
        b.layer.borderColor = UIColor(white: 1, alpha: 0.3).cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        if let url = Bundle.main.url(forResource: "Rye", withExtension: "ttf") { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
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
        purse.font = rye(17); folkLabel.font = rye(14); dayLabel.font = rye(14)
        ammoLabel.text = ""
        ammoView.backgroundColor = .clear
        ammoView.isUserInteractionEnabled = false
        view.addSubview(ammoView)
        hint.numberOfLines = 0
        hint.adjustsFontSizeToFitWidth = false
        hint.backgroundColor = UIColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 0.86)
        info.numberOfLines = 2
        purse.textColor = gold

        style(menuBtn, "Menu", primary: false)
        menuBtn.titleLabel?.font = rye(14)
        menuBtn.backgroundColor = UIColor(white: 0, alpha: 0.45)
        menuBtn.addTarget(self, action: #selector(openMenu), for: .touchUpInside)
        view.addSubview(menuBtn)

        // title
        // the title, as in the web game: the name in Rye over the live scene, with thunder on the wind
        titleBox.backgroundColor = .clear
        titleShade.colors = [UIColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 0.1).cgColor, UIColor(red: 0.14, green: 0.09, blue: 0.06, alpha: 0.68).cgColor]
        titleBox.layer.addSublayer(titleShade)
        titleLayers = stacked(titleBox, { col in
            NSAttributedString(string: "Dustfall", attributes: [.font: self.rye(110), .foregroundColor: col, .kern: 4])
        }, UIColor(red: 0.96, green: 0.9, blue: 0.74, alpha: 1))
        numLayers = stacked(titleBox, { col in
            let m = NSMutableAttributedString()
            let star: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34, weight: .black), .foregroundColor: col, .baselineOffset: 12]
            m.append(NSAttributedString(string: "\u{2605} ", attributes: star))
            m.append(NSAttributedString(string: "III", attributes: [.font: self.rye(72), .foregroundColor: col, .kern: 6]))
            m.append(NSAttributedString(string: " \u{2605}", attributes: star))
            return m
        }, gold)
        titleSub.text = "Open range, wide skies, and thunder on the wind."
        titleSub.font = serif(17, bold: false)
        titleSub.textColor = cream
        titleSub.textAlignment = .center
        titleSub.numberOfLines = 1
        titleSub.adjustsFontSizeToFitWidth = true
        titleSub.layer.shadowColor = UIColor.black.cgColor; titleSub.layer.shadowOpacity = 0.9; titleSub.layer.shadowRadius = 4; titleSub.layer.shadowOffset = CGSize(width: 0, height: 1)
        style(startBtn, "Ride in", primary: true)
        startBtn.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        style(newBtn, "New game", primary: false)
        newBtn.addTarget(self, action: #selector(startGame), for: .touchUpInside)
        titleBox.addSubview(titleSub); titleBox.addSubview(startBtn); titleBox.addSubview(newBtn)
        startBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        refreshTitle()
        view.addSubview(titleBox)
        // the opening: black bars, a line of story, and the name of the game as the sun comes up
        for v in [introTop, introBot] { v.backgroundColor = .black; v.isHidden = true; v.isUserInteractionEnabled = false; view.addSubview(v) }
        introCap.font = serif(19, bold: false); introCap.textColor = cream; introCap.textAlignment = .center; introCap.numberOfLines = 2
        introCap.layer.shadowColor = UIColor.black.cgColor; introCap.layer.shadowOpacity = 1; introCap.layer.shadowRadius = 5; introCap.layer.shadowOffset = .zero
        introCap.isHidden = true
        view.addSubview(introCap)
        introSkip.text = "Tap to skip"; introSkip.font = serif(12, bold: false); introSkip.textColor = cream.withAlphaComponent(0.55); introSkip.textAlignment = .right
        introSkip.isHidden = true
        view.addSubview(introSkip)
        introCard.isHidden = true; introCard.isUserInteractionEnabled = false
        introCardName.text = "Dustfall III"; introCardName.font = rye(46); introCardName.textColor = gold; introCardName.textAlignment = .center
        introCardName.layer.shadowColor = UIColor.black.cgColor; introCardName.layer.shadowOpacity = 1; introCardName.layer.shadowRadius = 0; introCardName.layer.shadowOffset = CGSize(width: 0, height: 4)
        introCardDay.text = "Day 1"; introCardDay.font = serif(20, bold: false); introCardDay.textColor = cream; introCardDay.textAlignment = .center
        introCardDay.layer.shadowColor = UIColor.black.cgColor; introCardDay.layer.shadowOpacity = 1; introCardDay.layer.shadowRadius = 4; introCardDay.layer.shadowOffset = .zero
        introCard.addSubview(introCardName); introCard.addSubview(introCardDay)
        view.addSubview(introCard)

        // pause menu
        pauseBox.backgroundColor = UIColor(red: 0.1, green: 0.06, blue: 0.04, alpha: 0.82)
        pauseBox.isHidden = true
        pauseTitle.text = "Paused"
        pauseTitle.font = rye(26)
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
        cutBox.backgroundColor = UIColor(red: 0.047, green: 0.027, blue: 0.02, alpha: 1)
        cutBox.isHidden = true
        cutClip.clipsToBounds = true
        cutClip.layer.mask = cutMask
        cutArt.layer.magnificationFilter = .nearest
        cutArt.contentMode = .scaleToFill
        cutClip.addSubview(cutArt)
        cutPanel.backgroundColor = UIColor(red: 0.047, green: 0.027, blue: 0.02, alpha: 1)
        cutPanel.layer.borderColor = UIColor(red: 0.42, green: 0.29, blue: 0.18, alpha: 1).cgColor
        cutPanel.layer.borderWidth = 0
        let rule = UIView(frame: CGRect(x: 0, y: 0, width: 4000, height: 2))
        rule.backgroundColor = UIColor(red: 0.42, green: 0.29, blue: 0.18, alpha: 1)
        cutPanel.addSubview(rule)
        cutHead.font = rye(15); cutHead.textColor = gold; cutHead.textAlignment = .center; cutHead.adjustsFontSizeToFitWidth = true
        cutCap.font = serif(20, bold: false); cutCap.textColor = cream; cutCap.textAlignment = .center; cutCap.numberOfLines = 3
        cutCap.adjustsFontSizeToFitWidth = true; cutCap.minimumScaleFactor = 0.7
        cutTap.font = serif(13, bold: false); cutTap.textColor = gold.withAlphaComponent(0.75); cutTap.textAlignment = .right
        cutBox.addSubview(cutClip); cutBox.addSubview(cutPanel); cutBox.addSubview(cutHead); cutBox.addSubview(cutCap); cutBox.addSubview(cutTap)
        cutBox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(nextBeat)))
        view.addSubview(cutBox)
        // run out of town
        overBox.backgroundColor = UIColor(red: 0.08, green: 0.04, blue: 0.03, alpha: 0.88)
        overBox.isHidden = true
        overTitle.text = "Run out of town"; overTitle.font = rye(34); overTitle.textColor = gold; overTitle.textAlignment = .center
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
        ammoView.frame = ammoLabel.frame
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
        titleBox.frame = view.bounds
        CATransaction.begin(); CATransaction.setDisableActions(true)
        titleShade.frame = CGRect(x: 0, y: 0, width: max(bw, bh), height: max(bw, bh))
        CATransaction.commit()
        let th = min(bh * 0.3, 118), ty = bh * 0.07
        for (i, lb) in titleLayers.enumerated() { lb.frame = CGRect(x: 20, y: ty + CGFloat([6, 3, 0][i]), width: bw - 40, height: th) }
        for (i, lb) in numLayers.enumerated() { lb.frame = CGRect(x: 20, y: ty + th * 0.8 + CGFloat([5, 3, 0][i]), width: bw - 40, height: th * 0.62) }
        let by = ty + th * 1.46
        titleSub.frame = CGRect(x: 40, y: by, width: bw - 80, height: 24)
        introTop.frame = CGRect(x: 0, y: 0, width: bw, height: bh * 0.11)
        introBot.frame = CGRect(x: 0, y: bh * 0.89, width: bw, height: bh * 0.11)
        introCap.frame = CGRect(x: 40, y: bh * 0.89 - 62, width: bw - 80, height: 54)
        introSkip.frame = CGRect(x: bw - r - 140, y: bh * 0.89 + 6, width: 130, height: 18)
        introCard.frame = view.bounds
        introCardName.frame = CGRect(x: 0, y: bh * 0.3, width: bw, height: 60)
        introCardDay.frame = CGRect(x: 0, y: bh * 0.3 + 62, width: bw, height: 28)
        startBtn.frame = CGRect(x: bw / 2 - 150, y: by + 32, width: 300, height: 48)
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
        newBtn.frame = CGRect(x: bw / 2 - 150, y: by + 86, width: 300, height: 38)
        // the closeup fills the top of the frame, as in the web game; the words sit on a panel under it
        let ph = bh * 0.7
        let csc = max(bw / 200, ph / 78)
        cutClip.frame = CGRect(x: 0, y: 0, width: bw, height: ph)
        cutArt.transform = .identity
        cutArt.frame = CGRect(x: (bw - 200 * csc) / 2, y: bh * 0.35 - 57 * csc, width: 200 * csc, height: 112 * csc)
        cutPanel.frame = CGRect(x: 0, y: ph, width: bw, height: bh - ph)
        cutHead.frame = CGRect(x: 30, y: ph + 8, width: bw - 60, height: 22)
        let cm = max(l, 40)
        cutCap.frame = CGRect(x: cm, y: ph + 30, width: bw - 2 * cm, height: bh - ph - 30 - 22)
        cutTap.frame = CGRect(x: bw - r - 320, y: bh - 22, width: 310, height: 18)

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
            if args.contains("-demo-intro") { game.beginIntro() }
            if args.contains("-demo-gallery") { demoMode = true; game.demo("gallery") }
            if args.contains("-demo-town") { demoMode = true; game.demo("town") }
            if args.contains("-demo-cut3") { demoMode = true; game.demo("day"); game.cut = [STORY["s1"]![0]] }
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
        game.beginIntro()
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
        head.font = rye(22); head.textColor = gold; head.textAlignment = .center
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
    @objc private func nextBeat() { if !game.cut.isEmpty && cutT > 0.9 { game.cut.removeFirst(); sound.click() } }
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
                cutT = 0
                cutIdx += 1
                sound.whoosh(); sound.sting()
                cutN = max(cutN, game.cut.count)
                let k = NSAttributedString(string: bt.head.uppercased(), attributes: [.font: rye(15), .foregroundColor: gold, .kern: 2.5])
                cutHead.attributedText = k
                cutCap.text = bt.cap
                clearTouches()
            }
            cutT += min(0.05, max(0, raw))
            let i = cutN - game.cut.count + 1
            cutTap.text = (cutN > 1 ? "\(i) of \(cutN)  \u{00B7}  " : "") + (game.cut.count > 1 ? "Tap to go on \u{25B8}" : "Tap to ride on \u{25B8}")
            cutTap.alpha = cutT > 0.9 ? 1 : 0
            if let img = renderer?.art(bt, cutT) { cutArt.image = UIImage(cgImage: img) }
            // it drifts slowly inward, and each new picture comes up out of the dark
            let z = CGFloat(1 + 0.05 * min(cutT, 9) / 9)
            cutArt.transform = CGAffineTransform(scaleX: z, y: z)
            let fa = CGFloat(min(1, cutT / 0.4))
            cutHead.alpha = fa; cutCap.alpha = fa
            // each picture opens differently, as in the web game: an iris, a wipe, blinds
            let cb = cutClip.bounds
            let u = CGFloat(min(1, cutT / 0.55)), e = u * u * (3 - 2 * u)
            let path = UIBezierPath()
            switch cutIdx % 3 {
            case 1:
                let rad = e * (cb.width * cb.width + cb.height * cb.height).squareRoot() * 0.56
                path.append(UIBezierPath(ovalIn: CGRect(x: cb.midX - rad, y: cb.midY - rad, width: rad * 2, height: rad * 2)))
            case 2:
                path.append(UIBezierPath(rect: CGRect(x: 0, y: 0, width: cb.width * e, height: cb.height)))
            default:
                let n = 9
                let bh2 = cb.height / CGFloat(n)
                for i in 0..<n { path.append(UIBezierPath(rect: CGRect(x: 0, y: CGFloat(i) * bh2, width: cb.width, height: bh2 * e + 0.5))) }
            }
            CATransaction.begin(); CATransaction.setDisableActions(true)
            cutMask.frame = cb
            cutMask.path = path.cgPath
            CATransaction.commit()
            cutBox.isHidden = false
        } else if !cutBox.isHidden { cutBox.isHidden = true; cutShown = ""; cutN = 0; last = 0 }
        guard let r = renderer, let cv = canvas else { return }
        r.draw()
        stage.layer.contents = cv.image()
        updateHUD()
    }

    private func set(_ l: UILabel, _ text: String) {
        if l.text != text { l.text = text }
    }

    private func updateHUD() {
        let playing = game.state == .play && game.gallery == nil
        titleBox.isHidden = game.state != .title
        let intro = game.state == .intro
        introTop.isHidden = !intro; introBot.isHidden = !intro; introSkip.isHidden = !intro
        introCap.isHidden = !intro || game.introCap.isEmpty
        if intro && introCap.text != game.introCap && !game.introCap.isEmpty {
            introCap.text = game.introCap
            introCap.alpha = 0
            UIView.animate(withDuration: 0.6) { self.introCap.alpha = 1 }
        }
        if introCard.isHidden == (intro && game.introCard) {
            introCard.isHidden = !(intro && game.introCard)
            if !introCard.isHidden { introCard.alpha = 0; UIView.animate(withDuration: 0.5) { self.introCard.alpha = 1 } }
        }
        for v in [purse, folkLabel, ammoLabel, ammoView, dayLabel, menuBtn, stickRing, knob, fireBtn, coinBtn] as [UIView] { v.isHidden = !playing }
        fireBtn.alpha = tFire ? 1 : 0.8
        coinBtn.alpha = tToss ? 1 : 0.8
        if !playing { hint.isHidden = true; info.isHidden = true; return }
        set(purse, "\u{25CF} \(game.coins)" + (game.bank > 0 ? " +\(game.bank)" : ""))
        set(folkLabel, "Folk \(game.folk.count)")
        let rk = game.reloadT > 0 ? 1 - game.reloadT / max(0.1, game.reloadMax) : -1
        if ammoView.ammo != game.ammo || abs(ammoView.reload - rk) > 0.01 { ammoView.ammo = game.ammo; ammoView.reload = rk; ammoView.setNeedsDisplay() }
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
        if game.gallery != nil && !userPaused {
            // at the shooting gallery a tap is a shot, where you touched
            for t in touches {
                let p = t.location(in: view)
                game.galleryShot(Double(p.x / view.bounds.width) * game.W, Double(p.y / view.bounds.height) * game.H)
            }
            return
        }
        if game.state == .intro { if game.introT > 0.8 { game.endIntro(); last = 0 }; return }
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


/// Six rounds in the cylinder: brass when loaded, dark when spent, and filling one by one while he reloads.
final class AmmoView: UIView {
    var ammo = 6
    var reload = -1.0        // 0 to 1 while reloading, under 0 otherwise

    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        let brass = UIColor(red: 0.95, green: 0.76, blue: 0.31, alpha: 1), tip = UIColor(red: 0.78, green: 0.5, blue: 0.3, alpha: 1)
        let spent = UIColor(white: 1, alpha: 0.2)
        let n = reload >= 0 ? Int(reload * 6) : ammo
        let bw: CGFloat = 8, gap: CGFloat = 5, total = 6 * bw + 5 * gap
        let x0 = (bounds.width - total) / 2, y0 = (bounds.height - 20) / 2
        for i in 0..<6 {
            let x = x0 + CGFloat(i) * (bw + gap)
            let on = i < n
            let body = UIBezierPath(roundedRect: CGRect(x: x, y: y0 + 7, width: bw, height: 13), cornerRadius: 1.5)
            (on ? brass : spent).setFill(); body.fill()
            let nose = UIBezierPath()
            nose.move(to: CGPoint(x: x + 0.8, y: y0 + 7)); nose.addQuadCurve(to: CGPoint(x: x + bw - 0.8, y: y0 + 7), controlPoint: CGPoint(x: x + bw / 2, y: y0 - 5)); nose.close()
            (on ? tip : spent).setFill(); nose.fill()
            if on { UIColor(white: 1, alpha: 0.45).setFill(); c.fill(CGRect(x: x + 1.5, y: y0 + 8, width: 1.6, height: 11)) }
            UIColor(red: 0.16, green: 0.1, blue: 0.06, alpha: on ? 0.55 : 0.3).setFill(); c.fill(CGRect(x: x, y: y0 + 17.5, width: bw, height: 1.2))
        }
        if reload >= 0 {
            // the bar under them runs as he loads
            UIColor(white: 0, alpha: 0.5).setFill(); c.fill(CGRect(x: x0, y: bounds.height - 4, width: total, height: 2.5))
            brass.setFill(); c.fill(CGRect(x: x0, y: bounds.height - 4, width: total * CGFloat(reload), height: 2.5))
        }
    }
}
