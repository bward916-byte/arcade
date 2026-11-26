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
    private let hint = PadLabel()
    private let adviceLabel = PadLabel()
    private let hapLight = UIImpactFeedbackGenerator(style: .light)
    private let hapMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let info = PadLabel()
    private var plainInfo = false
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
    private let burnLogo = BurnLogoView()
    private var logoOn = false
    private var wasIntro = false
    private var cardSeen = false
    private var nameSeen = 0
    private var nameDue = false
    private let shop = Shop()
    private var payOpen = false
    private let payNote = UILabel()
    private let introSkip = UILabel()
    private let cutClip = UIView()
    private let cutPanel = UIView()
    private var cutT = 0.0
    private var cutTyped = -1
    private let cutVig = CAGradientLayer()
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
    private let cheatBtn = UIButton(type: .system)
    private let mapBtn = UIButton(type: .system)
    private let crewBtn = UIButton(type: .system)
    private let townsBtn = UIButton(type: .system)
    private let sheetBox = UIView()
    private let pauseRule = UILabel()
    private let pauseStats = UILabel()
    private let dawnCard = UIView()
    private var dawnSeen = 0
    private var dawnHideAt = 0.0
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
    private var mapLayers: [CALayer] = []
    private let pausePlaque = UIView()
    private let overPlaque = UIView()
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
        l.backgroundColor = UIColor(red: 0.16, green: 0.1, blue: 0.06, alpha: 0.78)
        l.layer.cornerRadius = 7
        l.layer.masksToBounds = true
        l.layer.borderWidth = 1
        l.layer.borderColor = UIColor(red: 0.79, green: 0.6, blue: 0.24, alpha: 0.75).cgColor
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
        b.backgroundColor = primary ? gold : UIColor(red: 0.2, green: 0.13, blue: 0.08, alpha: 0.86)
        b.layer.cornerRadius = 9
        b.layer.borderWidth = primary ? 2 : 1
        b.layer.borderColor = primary ? UIColor(red: 0.45, green: 0.3, blue: 0.08, alpha: 1).cgColor : UIColor(red: 0.79, green: 0.6, blue: 0.24, alpha: 0.75).cgColor
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.55
        b.layer.shadowRadius = 5
        b.layer.shadowOffset = CGSize(width: 0, height: 3)
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
        game.unlocked = shop.owned
        shop.onChange = { [weak self] in if let s = self { s.game.unlocked = s.game.unlocked || s.shop.owned } }
        shop.start()
        game.onBuzz = { [weak self] n in
            guard let me = self else { return }
            (n == 0 ? me.hapLight : (n == 1 ? me.hapMedium : me.hapHeavy)).impactOccurred()
        }
        pill(adviceLabel, 12)
        adviceLabel.textAlignment = .left
        adviceLabel.backgroundColor = UIColor(red: 0.16, green: 0.1, blue: 0.06, alpha: 0.6)
        adviceLabel.layer.borderWidth = 0
        adviceLabel.isHidden = true
        view.addSubview(adviceLabel)

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
        info.numberOfLines = 3
        purse.textColor = gold

        style(menuBtn, "Menu", primary: false)
        menuBtn.titleLabel?.font = rye(14)
        menuBtn.backgroundColor = UIColor(red: 0.16, green: 0.1, blue: 0.06, alpha: 0.78)
        menuBtn.layer.cornerRadius = 7
        menuBtn.layer.borderColor = UIColor(red: 0.79, green: 0.6, blue: 0.24, alpha: 0.75).cgColor
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
        style(cheatBtn, "Cheat: +200 coins", primary: false)
        cheatBtn.titleLabel?.font = rye(12)
        cheatBtn.addTarget(self, action: #selector(cheatTapped), for: .touchUpInside)
        titleBox.addSubview(cheatBtn)
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
        introCard.addSubview(burnLogo)
        burnLogo.onStart = { [weak self] in self?.sound.whoosh() }
        view.addSubview(introCard)

        // pause menu
        pauseBox.backgroundColor = UIColor(red: 0.06, green: 0.03, blue: 0.02, alpha: 0.6)
        pauseBox.isHidden = true
        pauseTitle.text = "Paused"
        pauseTitle.font = rye(22)
        pauseTitle.adjustsFontSizeToFitWidth = true
        pauseTitle.minimumScaleFactor = 0.5
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
        style(crewBtn, "Crew", primary: false)
        crewBtn.addTarget(self, action: #selector(openCrew), for: .touchUpInside)
        style(townsBtn, "Towns", primary: false)
        townsBtn.addTarget(self, action: #selector(openTowns), for: .touchUpInside)
        townsBtn.isHidden = !TESTBUILD      // a testing tool: free to use, and gone from the App Store build
        for pl in [pausePlaque, overPlaque] {
            pl.backgroundColor = UIColor(red: 0.17, green: 0.11, blue: 0.07, alpha: 0.96)
            pl.layer.cornerRadius = 12
            pl.layer.borderWidth = 2
            pl.layer.borderColor = UIColor(red: 0.79, green: 0.6, blue: 0.24, alpha: 0.9).cgColor
            pl.layer.shadowColor = UIColor.black.cgColor; pl.layer.shadowOpacity = 0.7; pl.layer.shadowRadius = 14; pl.layer.shadowOffset = CGSize(width: 0, height: 6)
            pl.isUserInteractionEnabled = false
        }
        pauseBox.addSubview(pausePlaque); overBox.addSubview(overPlaque)
        pauseBox.addSubview(pauseTitle); pauseBox.addSubview(resumeBtn); pauseBox.addSubview(soundBtn); pauseBox.addSubview(restartBtn); pauseBox.addSubview(mapBtn); pauseBox.addSubview(crewBtn); pauseBox.addSubview(townsBtn)
        pauseRule.text = "\u{2500}\u{2500}\u{2500}\u{2500}  \u{2605}  \u{2500}\u{2500}\u{2500}\u{2500}"
        pauseRule.font = serif(12); pauseRule.textColor = gold; pauseRule.textAlignment = .center
        pauseStats.font = serif(13, bold: false); pauseStats.textColor = cream; pauseStats.textAlignment = .center
        pauseBox.addSubview(pauseRule); pauseBox.addSubview(pauseStats)
        dawnCard.backgroundColor = UIColor(red: 0.17, green: 0.11, blue: 0.07, alpha: 0.92)
        dawnCard.layer.cornerRadius = 10; dawnCard.layer.borderWidth = 1.5
        dawnCard.layer.borderColor = UIColor(red: 0.79, green: 0.6, blue: 0.24, alpha: 0.85).cgColor
        dawnCard.isUserInteractionEnabled = true
        dawnCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeDawn)))
        dawnCard.isHidden = true
        view.addSubview(dawnCard)
        sheetBox.backgroundColor = UIColor(red: 0.06, green: 0.03, blue: 0.02, alpha: 0.7)
        sheetBox.isHidden = true
        view.addSubview(sheetBox)
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
        cutVig.type = .radial
        cutVig.colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0).cgColor, UIColor(red: 0.05, green: 0.02, blue: 0.01, alpha: 0.62).cgColor]
        cutVig.locations = [0, 0.55, 1]
        cutVig.startPoint = CGPoint(x: 0.5, y: 0.5)
        cutVig.endPoint = CGPoint(x: 1.08, y: 1.08)
        cutClip.layer.addSublayer(cutVig)
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
        overBox.backgroundColor = UIColor(red: 0.06, green: 0.03, blue: 0.02, alpha: 0.66)
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
        info.frame = CGRect(x: (bw - iw) / 2, y: bh - bot - 62, width: iw, height: 58)
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
        burnLogo.frame = view.bounds
        burnLogo.build(size: view.bounds.size, title: rye(min(102, bw * 0.118)), day: serif(min(36, bw * 0.042), bold: false), gold: gold, cream: cream)
        startBtn.frame = CGRect(x: bw / 2 - 150, y: by + 32, width: 300, height: 48)
        pauseBox.frame = view.bounds
        // the pause card: centred, with room round the heading and between the buttons
        let py = max(6, (bh - 318) / 2)
        pausePlaque.frame = CGRect(x: bw / 2 - 180, y: py, width: 360, height: 318)
        sheetBox.frame = view.bounds
        pauseTitle.frame = CGRect(x: bw / 2 - 156, y: py + 12, width: 312, height: 32)
        pauseRule.frame = CGRect(x: bw / 2 - 156, y: py + 44, width: 312, height: 14)
        pauseStats.frame = CGRect(x: bw / 2 - 156, y: py + 59, width: 312, height: 18)
        overPlaque.frame = CGRect(x: bw / 2 - 250, y: bh * 0.2 - 18, width: 500, height: 196)
        resumeBtn.frame = CGRect(x: bw / 2 - 140, y: py + 86, width: 280, height: 46)
        soundBtn.frame = CGRect(x: bw / 2 - 140, y: py + 142, width: 134, height: 42)
        mapBtn.frame = CGRect(x: bw / 2 + 6, y: py + 142, width: 134, height: 42)
        crewBtn.frame = CGRect(x: bw / 2 - 140, y: py + 194, width: 134, height: 42)
        townsBtn.frame = CGRect(x: bw / 2 + 6, y: py + 194, width: 134, height: 42)
        restartBtn.frame = CGRect(x: bw / 2 - 140, y: py + 252, width: 280, height: 42)
        mapBox.frame = view.bounds
        cutBox.frame = view.bounds
        overBox.frame = view.bounds
        overTitle.frame = CGRect(x: 0, y: bh * 0.2, width: bw, height: 44)
        overText.frame = CGRect(x: 40, y: bh * 0.2 + 50, width: bw - 80, height: 50)
        overBtn.frame = CGRect(x: bw / 2 - 110, y: bh * 0.2 + 112, width: 220, height: 50)
        newBtn.frame = CGRect(x: bw / 2 - 150, y: by + 86, width: 300, height: 38)
        cheatBtn.frame = CGRect(x: bw / 2 - 90, y: by + 130, width: 180, height: 28)
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
            for name in ["day", "night", "train", "snow", "storm", "map", "duel", "coach", "west", "west2", "fire", "yard", "over", "lv0", "lv1", "lv2", "lv3", "lv4", "sig1", "sig2", "sig3", "sig4", "wild1", "wild2", "wild3", "wild4", "lv5", "lv6", "lv7", "fort", "post", "mission", "gate0", "march", "rout", "rally", "see0", "see1", "see2", "see3", "see4", "see5", "see6", "see7", "see8", "see9"] where args.contains("-demo-" + name) { demoMode = true; game.demo(name) }
            if args.contains("-demo-map") { showMap(choose: true) }
            if args.contains("-demo-intro") { game.beginIntro() }
            if args.contains("-demo-plain") { demoMode = true; game.demo("day"); plainInfo = true }
            if args.contains("-demo-burn") { demoMode = true; game.demo("day"); logoOn = true; burnLogo.frozen = 0.52; burnLogo.reset(); burnLogo.ignite(after: 0) }
            if args.contains("-demo-gallery") { demoMode = true; game.demo("gallery") }
            if args.contains("-demo-gallery2") { demoMode = true; game.demo("gallery2") }
            if args.contains("-demo-town") { demoMode = true; game.demo("town") }
            if args.contains("-demo-cut3") { demoMode = true; game.demo("day"); game.cut = [Beat(art: "vista", who: "coldcreek", head: "Cold Creek", cap: ARRIVE["coldcreek"] ?? "")] }
            if args.contains("-demo-cut") { demoMode = true; game.demo("day"); game.cut = [STORY["varney"]![0]] }
            if args.contains("-demo-cut2") { demoMode = true; game.demo("day"); game.cut = [Beat(art: "vista", who: "irongulch", head: "Iron Gulch", cap: ARRIVE["irongulch"] ?? "")] }
            if args.contains("-demo-name") { demoMode = true; game.demo("day"); burnLogo.retitle("Iron Gulch", "Day 9"); logoOn = true; burnLogo.frozen = 0.45; burnLogo.reset(); burnLogo.ignite(after: 0) }
            if args.contains("-demo-cutrun") { demoMode = true; game.demo("day"); game.cut = [STORY["end"]![0]] }
            if args.contains("-demo-cutshut") { demoMode = true; game.demo("day"); game.cut = [STORY["locked"]![0]] }
            if args.contains("-demo-cut4") { demoMode = true; game.demo("day"); game.cut = [STORY["end"]![4]] }
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
            cheatBtn.isHidden = !TESTBUILD
            cheatBtn.setTitle("Cheat: +200 coins (now \(s.coins))", for: .normal)
        } else {
            startBtn.setTitle("Ride in", for: .normal)
            newBtn.isHidden = true
            cheatBtn.isHidden = true
        }
    }
    private func clearTouches() {
        stickTouch = nil; fireTouch = nil; tossTouch = nil; tStick = 0; tToss = false; tFire = false
        tossLatch = false; fireLatch = false
        knob.center = stickCenter
    }

    /// The cheat on the title screen: 200 coins straight into the saved game.
    @objc private func cheatTapped() {
        guard var s = loadSave() else { return }
        s.coins += 200
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: saveKey) }
        refreshTitle()
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
        pauseStats.text = "\(game.coins) coins   \u{00B7}   \(game.folk.count) townsfolk   \u{00B7}   \(game.bank) in the bank"
        // the card drops into place and its buttons follow one after another; the star on the rule keeps a slow pulse
        let items: [UIView] = [pausePlaque, pauseTitle, pauseRule, pauseStats, resumeBtn, soundBtn, mapBtn, crewBtn, townsBtn, restartBtn]
        for (i, v) in items.enumerated() {
            v.layer.removeAllAnimations()
            v.alpha = 0
            v.transform = i == 0 ? CGAffineTransform(scaleX: 0.9, y: 0.9) : CGAffineTransform(translationX: 0, y: 16)
            UIView.animate(withDuration: 0.34, delay: Double(i) * 0.04, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.5, options: [.allowUserInteraction], animations: {
                v.alpha = 1; v.transform = .identity
            }, completion: nil)
        }
        UIView.animate(withDuration: 1.1, delay: 0.6, options: [.autoreverse, .repeat, .allowUserInteraction], animations: { self.pauseRule.alpha = 0.45 }, completion: nil)
        clearTouches()
        saveGame()
    }

    @objc private func closeMenu() {
        userPaused = false
        pauseBox.isHidden = true
        sheetBox.isHidden = true
        last = 0
        sound.resume()
    }

    /// The morning's takings, source by source: each row slides in after the last, with a coin for every coin paid.
    @objc private func closeDawn() { dawnHideAt = 0 }

    private func showDawn() {
        for v in dawnCard.subviews { v.removeFromSuperview() }
        let rows = game.dawnRows
        if rows.isEmpty { dawnCard.isHidden = true; return }
        let w: CGFloat = 236, rowH: CGFloat = 19
        let head = UILabel(frame: CGRect(x: 0, y: 6, width: w, height: 20))
        head.text = "Morning takings"; head.font = rye(14); head.textColor = gold; head.textAlignment = .center
        dawnCard.addSubview(head)
        var moving: [UIView] = []
        for (i, row) in rows.enumerated() {
            let y = 30 + CGFloat(i) * rowH
            let line = UIView(frame: CGRect(x: 0, y: y, width: w, height: rowH))
            let nm = UILabel(frame: CGRect(x: 12, y: 0, width: 96, height: rowH))
            nm.text = row.0; nm.font = serif(12.5); nm.textColor = cream; nm.adjustsFontSizeToFitWidth = true; nm.minimumScaleFactor = 0.7
            let dots = UILabel(frame: CGRect(x: 110, y: 0, width: 78, height: rowH))
            dots.text = row.1 > 0 ? String(repeating: "\u{25CF}", count: min(row.1, 9)) : ""
            dots.font = UIFont.systemFont(ofSize: 8); dots.textColor = gold
            let amt = UILabel(frame: CGRect(x: w - 66, y: 0, width: 54, height: rowH))
            amt.text = row.1 < 0 ? "robbed" : "+\(row.1)"
            amt.font = serif(13); amt.textAlignment = .right
            amt.textColor = row.1 < 0 ? UIColor(red: 0.9, green: 0.4, blue: 0.32, alpha: 1) : gold
            line.addSubview(nm); line.addSubview(dots); line.addSubview(amt)
            dawnCard.addSubview(line)
            moving.append(line)
        }
        let ty = 30 + CGFloat(rows.count) * rowH + 3
        let rule = UIView(frame: CGRect(x: 12, y: ty, width: w - 24, height: 1))
        rule.backgroundColor = gold.withAlphaComponent(0.5)
        let total = UILabel(frame: CGRect(x: 12, y: ty + 3, width: w - 24, height: 22))
        total.text = "\(game.dawnTotal) coins to pick up"; total.font = rye(14); total.textColor = gold; total.textAlignment = .right
        dawnCard.addSubview(rule); dawnCard.addSubview(total)
        moving.append(total)
        let bw = view.bounds.width, r = view.safeAreaInsets.right
        dawnCard.frame = CGRect(x: bw - max(r, 12) - w - 4, y: dayLabel.frame.maxY + 8, width: w, height: ty + 30)
        dawnCard.layer.removeAllAnimations()
        dawnCard.isHidden = false
        dawnCard.alpha = 0
        UIView.animate(withDuration: 0.3) { self.dawnCard.alpha = 1 }
        for (i, v) in moving.enumerated() {
            v.alpha = 0; v.transform = CGAffineTransform(translationX: 24, y: 0)
            UIView.animate(withDuration: 0.3, delay: 0.25 + Double(i) * 0.22, options: [], animations: { v.alpha = 1; v.transform = .identity }, completion: nil)
        }
        dawnHideAt = CACurrentMediaTime() + 5.5 + Double(rows.count) * 0.35
    }

    // ---------- two cards off the pause menu: who holds which job, and a way to step off the train at any town
    private func sheet(_ title: String, height: CGFloat) -> UIView {
        for v in sheetBox.subviews { v.removeFromSuperview() }
        let bw = view.bounds.width, bh = view.bounds.height
        let card = UIView(frame: CGRect(x: bw / 2 - 230, y: max(6, (bh - height) / 2), width: 460, height: height))
        card.backgroundColor = UIColor(red: 0.17, green: 0.11, blue: 0.07, alpha: 0.97)
        card.layer.cornerRadius = 12; card.layer.borderWidth = 2
        card.layer.borderColor = UIColor(red: 0.79, green: 0.6, blue: 0.24, alpha: 0.9).cgColor
        let head = UILabel(frame: CGRect(x: 16, y: 12, width: 428, height: 30))
        head.text = title; head.font = rye(20); head.textColor = gold; head.textAlignment = .center
        card.addSubview(head)
        let back = UIButton(type: .system)
        style(back, "Back", primary: true)
        back.frame = CGRect(x: 150, y: height - 54, width: 160, height: 42)
        back.addTarget(self, action: #selector(closeSheet), for: .touchUpInside)
        card.addSubview(back)
        sheetBox.addSubview(card)
        view.bringSubviewToFront(sheetBox)
        sheetBox.isHidden = false
        return card
    }
    @objc private func closeSheet() { sheetBox.isHidden = true }

    @objc private func openCrew() {
        let card = sheet("The crew", height: 300)
        let names: [Role: (String, String)] = [.folk: ("Townsfolk", "They build, and every two pay a coin at dawn."), .deputy: ("Deputies", "They guard the gates at night."), .miner: ("Prospectors", "Each brings a coin from the mine at dawn."), .rancher: ("Ranchers", "They raise the cattle east of town.")]
        for (i, row) in game.crew().enumerated() {
            let y = 50 + CGFloat(i) * 46
            let nm = names[row.0] ?? ("", "")
            let l1 = UILabel(frame: CGRect(x: 22, y: y, width: 290, height: 20))
            l1.text = "\(nm.0): \(row.1)"; l1.font = serif(16); l1.textColor = cream
            let l2 = UILabel(frame: CGRect(x: 22, y: y + 20, width: 290, height: 16))
            l2.text = nm.1; l2.font = serif(11.5, bold: false); l2.textColor = cream.withAlphaComponent(0.75)
            l2.adjustsFontSizeToFitWidth = true; l2.minimumScaleFactor = 0.7
            card.addSubview(l1); card.addSubview(l2)
            if row.0 != .folk && row.1 > 0 {
                let b = UIButton(type: .system)
                style(b, "Release one", primary: false)
                b.titleLabel?.font = serif(13)
                b.frame = CGRect(x: 320, y: y + 1, width: 122, height: 34)
                b.tag = i
                b.addTarget(self, action: #selector(releaseOne(_:)), for: .touchUpInside)
                card.addSubview(b)
            }
        }
    }
    @objc private func releaseOne(_ b: UIButton) {
        let rows = game.crew()
        if b.tag >= 0 && b.tag < rows.count { game.release(rows[b.tag].0) }
        openCrew()
    }

    @objc private func openTowns() {
        let card = sheet("Step off at any town", height: 300)
        for (i, stop) in STOPS.enumerated() {
            let b = UIButton(type: .system)
            style(b, nice(PLACES[stop.0]?.name ?? stop.0), primary: false)
            b.titleLabel?.font = serif(14)
            b.frame = CGRect(x: 22 + CGFloat(i % 2) * 212, y: 50 + CGFloat(i / 2) * 46, width: 204, height: 38)
            b.tag = i
            b.addTarget(self, action: #selector(jumpTown(_:)), for: .touchUpInside)
            card.addSubview(b)
        }
    }
    // ---------- the rest of the line: asked for once the first town is done, and whenever a locked town is picked
    private func showPay() {
        payOpen = true
        let card = sheet("Ride the whole line", height: 268)
        for v in card.subviews where v is UIButton { v.removeFromSuperview() }
        let body = UILabel(frame: CGRect(x: 24, y: 44, width: 412, height: 78))
        body.numberOfLines = 0; body.textAlignment = .center; body.font = serif(15, bold: false); body.textColor = cream
        body.text = "Dustfall is yours to keep, free. Four bigger towns wait down the track: a river ferry, a sawmill in the pines, a copper smelter in the canyon, and Silas Crane at the end of the rails."
        card.addSubview(body)
        let buy = UIButton(type: .system)
        let price = shop.product?.displayPrice ?? "$1.99"
        style(buy, shop.product == nil && TESTBUILD ? "Unlock all towns (test build)" : "Unlock all towns  \u{00B7}  " + price, primary: true)
        buy.frame = CGRect(x: 80, y: 130, width: 300, height: 46)
        buy.addTarget(self, action: #selector(payBuy), for: .touchUpInside)
        card.addSubview(buy)
        let rest = UIButton(type: .system)
        style(rest, "Restore purchase", primary: false)
        rest.titleLabel?.font = serif(14)
        rest.frame = CGRect(x: 40, y: 188, width: 184, height: 38)
        rest.addTarget(self, action: #selector(payRestore), for: .touchUpInside)
        card.addSubview(rest)
        let later = UIButton(type: .system)
        style(later, "Not now", primary: false)
        later.titleLabel?.font = serif(14)
        later.frame = CGRect(x: 236, y: 188, width: 184, height: 38)
        later.addTarget(self, action: #selector(payLater), for: .touchUpInside)
        card.addSubview(later)
        payNote.frame = CGRect(x: 24, y: 234, width: 412, height: 22)
        payNote.textAlignment = .center; payNote.font = serif(13, bold: false); payNote.textColor = gold; payNote.text = ""
        card.addSubview(payNote)
    }
    private func payFinish() {
        game.unlocked = true
        sheetBox.isHidden = true; payOpen = false
        if game.payAsk { game.payDone() }
        last = 0
    }
    @objc private func payBuy() {
        if shop.product == nil {
            if TESTBUILD { shop.grant(true); payFinish(); return }
            payNote.text = "The store can\u{2019}t be reached just now. Try again in a moment."
            Task { [weak self] in await self?.shop.refresh() }
            return
        }
        payNote.text = "Asking the store\u{2026}"
        Task { [weak self] in
            let ok = await self?.shop.buy() ?? false
            if ok { self?.payFinish() } else { self?.payNote.text = "Nothing was bought." }
        }
    }
    @objc private func payRestore() {
        payNote.text = "Looking\u{2026}"
        Task { [weak self] in
            let ok = await self?.shop.restore() ?? false
            if ok { self?.payFinish() } else { self?.payNote.text = "No purchase found on this Apple ID." }
        }
    }
    @objc private func payLater() {
        sheetBox.isHidden = true; payOpen = false
        if game.payAsk { game.payLater() }
        last = 0
    }

    @objc private func jumpTown(_ b: UIButton) {
        closeMenu()
        game.jump(b.tag)
        last = 0
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
        let ink = UIColor(red: 0.16, green: 0.1, blue: 0.06, alpha: 1)
        let head = UILabel(frame: CGRect(x: 0, y: 12, width: bw, height: 30))
        head.text = choose ? "The line forks. Where to?" : "The territory"
        head.font = rye(22); head.textColor = UIColor(red: 0.54, green: 0.18, blue: 0.15, alpha: 1); head.textAlignment = .center
        mapBox.addSubview(head)
        let n = STAGES.count
        let cur = game.town % n, lap = game.town / n, nxt = (cur + 1) % n
        let cw = (bw - l - r) / CGFloat(n)
        let rowH = (bh - 84 - 50) / 2
        // a sheet of old paper with the country drawn on it: desert, a river, canyon, pines and the snow ranges,
        // the railroad running stop to stop and forking where the towns do
        for ly in mapLayers { ly.removeAllAnimations(); ly.removeFromSuperlayer() }
        mapLayers = []
        var zi: UInt32 = 0
        func put(_ ly: CALayer) { mapBox.layer.insertSublayer(ly, at: zi); zi += 1; mapLayers.append(ly) }
        let parch = CAGradientLayer()
        parch.type = .radial
        parch.colors = [UIColor(red: 0.91, green: 0.83, blue: 0.63, alpha: 1).cgColor, UIColor(red: 0.82, green: 0.7, blue: 0.47, alpha: 1).cgColor, UIColor(red: 0.5, green: 0.36, blue: 0.2, alpha: 1).cgColor]
        parch.locations = [0, 0.72, 1]
        parch.startPoint = CGPoint(x: 0.5, y: 0.5)
        parch.endPoint = CGPoint(x: 1.06, y: 1.2)
        parch.frame = view.bounds
        put(parch)
        func stops(_ i: Int) -> [CGPoint] {
            let cnt = STAGES[i].count
            return (0..<cnt).map { (k: Int) -> CGPoint in CGPoint(x: l + CGFloat(i) * cw + cw / 2, y: 82 + CGFloat(k) * rowH + (cnt == 1 ? rowH / 2 : 0) + 22) }
        }
        let midY = 82 + rowH / 2 + 22
        // the river comes down out of the snow country, past Redwater, and away south-west
        let river = UIBezierPath()
        river.move(to: CGPoint(x: l + cw * 3.45, y: 44))
        river.addCurve(to: CGPoint(x: l + cw * 1.5, y: 82 + 22 + 34), controlPoint1: CGPoint(x: l + cw * 3.0, y: midY - 6), controlPoint2: CGPoint(x: l + cw * 2.1, y: 60))
        river.addCurve(to: CGPoint(x: l + cw * 0.62, y: bh + 6), controlPoint1: CGPoint(x: l + cw * 1.1, y: midY + 20), controlPoint2: CGPoint(x: l + cw * 1.05, y: bh - 60))
        // the rails bend their way between stops, and the country is drawn clear of them, so the line runs through the gaps
        func bend(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(1, (dx * dx + dy * dy).squareRoot())
            let sg: CGFloat = Int(a.y + b.y * 2) % 2 == 0 ? 1 : -1
            return CGPoint(x: (a.x + b.x) / 2 - dy / len * 22 * sg, y: (a.y + b.y) / 2 + dx / len * 22 * sg)
        }
        var railPts: [CGPoint] = []
        for i in 0..<(n - 1) {
            for a in stops(i) {
                for b in stops(i + 1) {
                    let c = bend(a, b)
                    for q in 0...14 {
                        let u = CGFloat(q) / 14, v = 1 - u
                        railPts.append(CGPoint(x: v * v * a.x + 2 * v * u * c.x + u * u * b.x, y: v * v * a.y + 2 * v * u * c.y + u * u * b.y))
                    }
                }
            }
        }
        func nearRail(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat) -> Bool {
            for p in railPts where abs(p.x - x) < d && abs(p.y - y) < d { return true }
            return false
        }
        let land = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            let inkC = ink.withAlphaComponent(0.6)
            func hh(_ a: Int, _ b: Int) -> CGFloat { return CGFloat(hashN(Double(a) * 12.9898 + Double(b) * 78.233 + 0.5)) }
            func line(_ pts: [CGFloat], _ col: UIColor, _ w: CGFloat) {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: pts[0], y: pts[1]))
                var i = 2
                while i + 1 < pts.count { p.addLine(to: CGPoint(x: pts[i], y: pts[i + 1])); i += 2 }
                col.setStroke(); p.lineWidth = w; p.lineCapStyle = .round; p.lineJoinStyle = .round; p.stroke()
            }
            func shape(_ pts: [CGFloat], _ fill: UIColor, outline: Bool = true) {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: pts[0], y: pts[1]))
                var i = 2
                while i + 1 < pts.count { p.addLine(to: CGPoint(x: pts[i], y: pts[i + 1])); i += 2 }
                p.close()
                fill.setFill(); p.fill()
                if outline { inkC.setStroke(); p.lineWidth = 1; p.lineJoinStyle = .round; p.stroke() }
            }
            // stains and foxing on the paper
            for i in 0..<26 {
                UIColor(red: 0.55, green: 0.38, blue: 0.18, alpha: 0.05).setFill()
                UIBezierPath(ovalIn: CGRect(x: hh(i, 1) * bw - 30, y: hh(i, 2) * bh - 20, width: 30 + hh(i, 3) * 90, height: 16 + hh(i, 4) * 44)).fill()
            }
            // the river: a wash of blue between two inked banks
            UIColor(red: 0.42, green: 0.62, blue: 0.72, alpha: 0.55).setStroke()
            river.lineWidth = 8; river.lineCapStyle = .round; river.stroke()
            UIColor(red: 0.2, green: 0.36, blue: 0.48, alpha: 0.5).setStroke()
            river.lineWidth = 1; river.stroke()
            func cactus(_ x: CGFloat, _ y: CGFloat, _ k: CGFloat) {
                let g2 = UIColor(red: 0.33, green: 0.46, blue: 0.26, alpha: 0.8)
                line([x, y, x, y - 13 * k], g2, 2.8 * k)
                line([x - 4 * k, y - 9 * k, x - 4 * k, y - 5 * k, x, y - 5 * k], g2, 2 * k)
                line([x + 4 * k, y - 11 * k, x + 4 * k, y - 7 * k, x, y - 7 * k], g2, 2 * k)
            }
            func mesa(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ t: CGFloat, _ red: Bool) {
                shape([x - w / 2, y, x - w * 0.36, y - t, x + w * 0.3, y - t, x + w / 2, y], red ? UIColor(red: 0.76, green: 0.42, blue: 0.26, alpha: 0.6) : UIColor(red: 0.8, green: 0.56, blue: 0.34, alpha: 0.55))
                shape([x + w * 0.12, y, x + w * 0.16, y - t, x + w * 0.3, y - t, x + w / 2, y], ink.withAlphaComponent(0.2), outline: false)
                line([x - w * 0.4, y - t * 0.62, x + w * 0.36, y - t * 0.62], inkC.withAlphaComponent(0.3), 0.8)
                line([x - w * 0.45, y - t * 0.3, x + w * 0.43, y - t * 0.3], inkC.withAlphaComponent(0.3), 0.8)
            }
            func mountain(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ t: CGFloat) {
                shape([x - w / 2, y, x, y - t, x + w / 2, y], UIColor(red: 0.6, green: 0.56, blue: 0.54, alpha: 0.7), outline: false)
                shape([x, y - t, x + w / 2, y, x + w * 0.1, y, x + w * 0.04, y - t * 0.45], ink.withAlphaComponent(0.24), outline: false)
                shape([x - w * 0.17, y - t * 0.66, x, y - t, x + w * 0.17, y - t * 0.66, x + w * 0.07, y - t * 0.56, x, y - t * 0.68, x - w * 0.08, y - t * 0.54], UIColor(white: 1, alpha: 0.92), outline: false)
                line([x - w / 2, y, x, y - t, x + w / 2, y], inkC, 1.1)
                line([x - w * 0.2, y - t * 0.2, x - w * 0.1, y - t * 0.38], inkC.withAlphaComponent(0.35), 0.8)
            }
            func pine(_ x: CGFloat, _ y: CGFloat, _ k: CGFloat, _ snow: Bool) {
                line([x, y, x, y - 4 * k], UIColor(red: 0.3, green: 0.2, blue: 0.12, alpha: 0.8), 1.4)
                let g2 = snow ? UIColor(red: 0.3, green: 0.42, blue: 0.38, alpha: 0.85) : UIColor(red: 0.2, green: 0.38, blue: 0.24, alpha: 0.85)
                for j in 0..<3 {
                    let yy = y - 3 * k - CGFloat(j) * 4 * k, ww = (6 - CGFloat(j) * 1.5) * k
                    shape([x - ww, yy, x, yy - 6 * k, x + ww, yy], g2, outline: false)
                    if snow { shape([x - ww * 0.5, yy - 3 * k, x, yy - 6 * k, x + ww * 0.5, yy - 3 * k], UIColor(white: 1, alpha: 0.85), outline: false) }
                }
            }
            func dune(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: x - w / 2, y: y))
                p.addQuadCurve(to: CGPoint(x: x + w / 2, y: y), controlPoint: CGPoint(x: x - w * 0.1, y: y - w * 0.36))
                UIColor(red: 0.86, green: 0.7, blue: 0.42, alpha: 0.5).setFill(); p.fill()
                inkC.withAlphaComponent(0.4).setStroke(); p.lineWidth = 0.9; p.stroke()
                for j in 0..<3 { UIBezierPath(ovalIn: CGRect(x: x - w * 0.3 + CGFloat(j) * w * 0.3, y: y + 3, width: 1.4, height: 1.4)).fill() }
            }
            func tree(_ x: CGFloat, _ y: CGFloat, _ k: CGFloat) {
                line([x, y, x, y - 5 * k], UIColor(red: 0.3, green: 0.2, blue: 0.12, alpha: 0.8), 1.4)
                UIColor(red: 0.34, green: 0.5, blue: 0.26, alpha: 0.8).setFill()
                UIBezierPath(ovalIn: CGRect(x: x - 5 * k, y: y - 13 * k, width: 10 * k, height: 9 * k)).fill()
                UIBezierPath(ovalIn: CGRect(x: x - 2 * k, y: y - 15 * k, width: 7 * k, height: 7 * k)).fill()
            }
            func tuft(_ x: CGFloat, _ y: CGFloat) {
                let g2 = UIColor(red: 0.36, green: 0.52, blue: 0.28, alpha: 0.75)
                line([x - 2, y, x - 3, y - 4], g2, 1); line([x, y, x, y - 5], g2, 1); line([x + 2, y, x + 3.4, y - 4], g2, 1)
            }
            var gyI = 0
            var yy: CGFloat = 56
            while yy < bh - 14 {
                var gxI = 0
                var xx: CGFloat = 14
                while xx < bw - 8 {
                    let jx = xx + (hh(gxI, gyI) - 0.5) * 24, jy = yy + (hh(gxI + 31, gyI + 7) - 0.5) * 16
                    let rr = hh(gxI + 5, gyI + 13), kk = 0.8 + hh(gxI + 9, gyI + 3) * 0.5
                    let col = Int(max(0, min(CGFloat(n) - 1, ((jx - l) / cw).rounded(.down))))
                    let top = jy < midY
                    // nothing stands on the right of way; mountains keep further back, and are fewer
                    if nearRail(jx, jy - 8, col >= 3 ? 30 : 20) { xx += 44; gxI += 1; continue }
                    if col == 0 {
                        if rr < 0.3 { cactus(jx, jy, kk) } else if rr < 0.5 { mesa(jx, jy, 34 * kk, 15 * kk, false) } else if rr < 0.68 { dune(jx, jy, 30 * kk) }
                    } else if col == 1 {
                        if rr < 0.45 { tuft(jx, jy) } else if rr < 0.72 { tree(jx, jy, kk) }
                    } else if col == 2 {
                        if rr < 0.82 { pine(jx, jy, kk, false); pine(jx + 9 * kk, jy + 3, kk * 0.8, false) }
                    } else if col == 3 {
                        if rr < 0.6 { mesa(jx, jy, 30 * kk, 24 * kk, true) } else if rr < 0.78 { cactus(jx, jy, kk * 0.9) }
                    } else {
                        if rr < 0.55 { mountain(jx, jy, 54 * kk, 42 * kk) } else if rr < 0.72 { pine(jx, jy, kk, true) }
                    }
                    xx += 44; gxI += 1
                }
                yy += 34; gyI += 1
            }
            // a ruled border, as on a surveyor's sheet
            inkC.setStroke()
            let b1 = UIBezierPath(rect: view.bounds.insetBy(dx: 5, dy: 5)); b1.lineWidth = 2; b1.stroke()
            let b2 = UIBezierPath(rect: view.bounds.insetBy(dx: 9, dy: 9)); b2.lineWidth = 0.7; b2.stroke()
        }
        let landLayer = CALayer()
        landLayer.frame = view.bounds
        landLayer.contents = land.cgImage
        put(landLayer)
        // light running down the river
        let flow = CAShapeLayer()
        flow.frame = view.bounds
        flow.path = river.cgPath
        flow.fillColor = nil
        flow.strokeColor = UIColor(white: 1, alpha: 0.55).cgColor
        flow.lineWidth = 1.6
        flow.lineDashPattern = [5, 16]
        flow.lineCap = .round
        let fa = CABasicAnimation(keyPath: "lineDashPhase")
        fa.fromValue = 0; fa.toValue = -21; fa.duration = 1.3; fa.repeatCount = .infinity
        flow.add(fa, forKey: "flow")
        put(flow)
        // the railroad: a rail with ties across it
        let tp = UIBezierPath()
        for i in 0..<(n - 1) { for a in stops(i) { for b in stops(i + 1) { tp.move(to: a); tp.addQuadCurve(to: b, controlPoint: bend(a, b)) } } }
        let ties = CAShapeLayer()
        ties.frame = view.bounds; ties.path = tp.cgPath; ties.fillColor = nil
        ties.strokeColor = ink.withAlphaComponent(0.7).cgColor; ties.lineWidth = 8; ties.lineDashPattern = [1.6, 6]
        put(ties)
        let track = CAShapeLayer()
        track.frame = view.bounds; track.path = tp.cgPath; track.fillColor = nil
        track.strokeColor = ink.withAlphaComponent(0.85).cgColor; track.lineWidth = 2
        put(track)
        // cloud shadows crossing the country
        for i in 0..<2 {
            let cs = CAShapeLayer()
            let cwid: CGFloat = 220 + CGFloat(i) * 90
            cs.path = UIBezierPath(ovalIn: CGRect(x: -cwid / 2, y: -34, width: cwid, height: 68 + CGFloat(i) * 20)).cgPath
            cs.fillColor = UIColor(red: 0.2, green: 0.12, blue: 0.05, alpha: 0.08).cgColor
            cs.position = CGPoint(x: -200, y: bh * (i == 0 ? 0.36 : 0.7))
            let ca = CABasicAnimation(keyPath: "position.x")
            ca.fromValue = -200; ca.toValue = bw + 200; ca.duration = 34 + Double(i) * 17; ca.repeatCount = .infinity; ca.timeOffset = Double(i) * 9
            cs.add(ca, forKey: "drift")
            put(cs)
        }
        // a train working the line you have already opened
        var done: [CGPoint] = []
        for i in 0...cur {
            let li = lap * n + i
            let key = i == cur ? game.place : (li < game.log.count ? game.log[li] : STAGES[i][0])
            let pts = stops(i)
            done.append(pts[min(pts.count - 1, max(0, STAGES[i].firstIndex(of: key) ?? 0))])
        }
        if done.count > 1 {
            let rp = UIBezierPath()
            rp.move(to: done[0])
            for (k, p) in done.enumerated() where k > 0 { rp.addQuadCurve(to: p, controlPoint: bend(done[k - 1], p)) }
            let loco = CAShapeLayer()
            let lp = UIBezierPath(roundedRect: CGRect(x: -9, y: -4, width: 18, height: 8), cornerRadius: 2)
            lp.append(UIBezierPath(rect: CGRect(x: 3, y: -8, width: 4, height: 5)))
            lp.append(UIBezierPath(rect: CGRect(x: -22, y: -3.5, width: 11, height: 7)))
            loco.path = lp.cgPath
            loco.fillColor = UIColor(red: 0.48, green: 0.14, blue: 0.11, alpha: 1).cgColor
            loco.strokeColor = ink.cgColor; loco.lineWidth = 1
            loco.position = done[0]
            let ka = CAKeyframeAnimation(keyPath: "position")
            ka.path = rp.cgPath; ka.calculationMode = .paced; ka.rotationMode = .rotateAuto
            ka.duration = 3.2 * Double(done.count - 1); ka.repeatCount = .infinity
            loco.add(ka, forKey: "run")
            put(loco)
        }
        // a compass rose, its needle never quite still
        let rose = CAShapeLayer()
        let cp = UIBezierPath(ovalIn: CGRect(x: -17, y: -17, width: 34, height: 34))
        for q in 0..<4 {
            let an = CGFloat(q) * .pi / 2
            let tip = CGPoint(x: sin(an) * 22, y: -cos(an) * 22)
            cp.move(to: tip); cp.addLine(to: CGPoint(x: sin(an + 0.5) * 5, y: -cos(an + 0.5) * 5)); cp.addLine(to: CGPoint(x: sin(an - 0.5) * 5, y: -cos(an - 0.5) * 5)); cp.close()
        }
        rose.path = cp.cgPath
        rose.fillColor = UIColor(red: 0.54, green: 0.18, blue: 0.15, alpha: 0.75).cgColor
        rose.strokeColor = ink.withAlphaComponent(0.8).cgColor; rose.lineWidth = 1
        rose.position = CGPoint(x: l + 34, y: bh - 44)
        let wa = CABasicAnimation(keyPath: "transform.rotation.z")
        wa.fromValue = -0.07; wa.toValue = 0.07; wa.duration = 2.3; wa.autoreverses = true; wa.repeatCount = .infinity
        wa.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rose.add(wa, forKey: "wobble")
        put(rose)
        for (i, opts) in STAGES.enumerated() {
            let x = l + CGFloat(i) * cw
            for (k, key) in opts.enumerated() {
                guard let pl = PLACES[key] else { continue }
                let y = 82 + CGFloat(k) * rowH + (opts.count == 1 ? rowH / 2 : 0)
                let li = lap * n + i
                let been = i < cur && li < game.log.count && game.log[li] == key
                let hereNow = i == cur && key == game.place
                let pick = choose && i == nxt
                let b = UIButton(type: .system)
                style(b, "", primary: pick)
                let bwid = min(cw - 8, 128)
                b.frame = CGRect(x: x + (cw - bwid) / 2, y: y, width: bwid, height: 44)
                let second = hereNow ? "Here, day \(game.day - game.day0)" : (been ? "Rebuilt" : pl.land)
                b.setTitle(nice(pl.name) + "\n" + second, for: .normal)
                b.titleLabel?.numberOfLines = 2
                b.titleLabel?.textAlignment = .center
                b.titleLabel?.font = serif(12)
                b.titleLabel?.adjustsFontSizeToFitWidth = true
                b.isUserInteractionEnabled = pick
                b.accessibilityIdentifier = key
                b.addTarget(self, action: #selector(pickPlace(_:)), for: .touchUpInside)
                if hereNow { b.layer.borderColor = gold.cgColor; b.layer.borderWidth = 2 }
                if hereNow || pick {
                    // where you are, and where you may go, glow slowly
                    b.layer.shadowColor = (hereNow ? gold : UIColor.white).cgColor
                    b.layer.shadowOffset = .zero; b.layer.shadowRadius = 10
                    let ga = CABasicAnimation(keyPath: "shadowOpacity")
                    ga.fromValue = 0.15; ga.toValue = 1; ga.duration = 0.9; ga.autoreverses = true; ga.repeatCount = .infinity
                    b.layer.add(ga, forKey: "glow")
                }
                if !pick && !hereNow && !been { b.alpha = 0.72 }
                mapBox.addSubview(b)
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
            ft.font = serif(13); ft.textColor = ink; ft.textAlignment = .center
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
        // the name over the first morning stands through the end of the opening, then burns off as the day starts
        let st = game.state
        if st == .intro && !wasIntro { burnLogo.retitle("Dustfall III", "Day 1"); burnLogo.reset(); cardSeen = false; logoOn = false; nameDue = false; nameSeen = game.nameSeq }
        // stepping off in a new town: its name stands over the street, then burns away
        if game.nameSeq != nameSeen { nameSeen = game.nameSeq; nameDue = true }
        if nameDue && st == .play && game.cut.isEmpty && game.fade < 0.5 && !logoOn && !userPaused {
            nameDue = false
            burnLogo.retitle(nice(game.townName), "Day \(game.day)")
            burnLogo.reset(); logoOn = true; burnLogo.ignite(after: 1.4)
        }
        if game.payAsk && game.cut.isEmpty && !payOpen { showPay() }
        // the last scene and the thanks are done: back to the title, the finished game kept on disk
        if game.toTitle && game.cut.isEmpty && game.seen.contains("st_end") {
            game.toTitle = false
            saveGame()
            game.state = .title
            refreshTitle()
        }
        if st == .intro && game.introCard { cardSeen = true }
        if wasIntro && st == .play { logoOn = true; burnLogo.ignite(after: cardSeen ? 0.25 : 1.1) }
        wasIntro = st == .intro
        if logoOn {
            if st != .play { logoOn = false; burnLogo.reset() }
            else if !userPaused && game.cut.isEmpty && !burnLogo.step(min(0.05, max(0, raw))) { logoOn = false; burnLogo.reset() }
        }
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
                cutTyped = -1
                clearTouches()
            }
            cutT += min(0.05, max(0, raw))
            // the line is set down a letter at a time, without the words shifting as it goes
            let capNS = bt.cap as NSString
            let typed = min(capNS.length, Int(cutT * 44))
            if typed != cutTyped {
                cutTyped = typed
                let m = NSMutableAttributedString(string: bt.cap, attributes: [.font: serif(20, bold: false), .foregroundColor: cream])
                if typed < capNS.length { m.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: typed, length: capNS.length - typed)) }
                cutCap.attributedText = m
                cutCap.textAlignment = .center
            }
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
            cutVig.frame = cb
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
        if game.state == .title, let face = titleLayers.last {
            // lightning lights the name, as on the web title
            let fl = Float(min(1, max(0, game.bolt / 0.35)))
            face.layer.shadowColor = UIColor(red: 0.75, green: 0.82, blue: 1, alpha: 1).cgColor
            face.layer.shadowOffset = .zero
            face.layer.shadowRadius = 16
            face.layer.shadowOpacity = fl
        }
        let intro = game.state == .intro
        introTop.isHidden = !intro; introBot.isHidden = !intro; introSkip.isHidden = !intro
        introCap.isHidden = !intro || game.introCap.isEmpty
        if intro && introCap.text != game.introCap && !game.introCap.isEmpty {
            introCap.text = game.introCap
            introCap.alpha = 0
            UIView.animate(withDuration: 0.6) { self.introCap.alpha = 1 }
        }
        let showCard = (intro && game.introCard) || logoOn
        if introCard.isHidden == showCard {
            introCard.isHidden = !showCard
            if !introCard.isHidden { introCard.alpha = 0; UIView.animate(withDuration: 0.5) { self.introCard.alpha = 1 } }
        }
        for v in [purse, folkLabel, ammoLabel, ammoView, dayLabel, menuBtn, stickRing, knob, fireBtn, coinBtn] as [UIView] { v.isHidden = !playing }
        fireBtn.alpha = tFire ? 1 : 0.8
        coinBtn.alpha = tToss ? 1 : 0.8
        if !playing { hint.isHidden = true; info.isHidden = true; adviceLabel.isHidden = true; return }
        set(purse, "\u{25CF} \(game.coins)" + (game.bank > 0 ? " +\(game.bank)" : ""))
        set(folkLabel, "Folk \(game.folk.count)")
        let rk = game.reloadT > 0 ? 1 - game.reloadT / max(0.1, game.reloadMax) : -1
        if ammoView.ammo != game.ammo || abs(ammoView.reload - rk) > 0.01 { ammoView.ammo = game.ammo; ammoView.reload = rk; ammoView.setNeedsDisplay() }
        let tm = game.dark() > 0.5 ? "night" : (game.t > 0.6 ? "dusk" : "")
        let wn = game.cloudI() > 0.2 || game.wx == 1 || (game.wx == 2) ? game.wxName() : ""
        set(dayLabel, wn.isEmpty ? "Day \(game.day)" + (tm.isEmpty ? "" : ", " + tm) : "Day \(game.day), \(wn.lowercased())")
        hint.isHidden = game.hintT <= 0 || userPaused
        // the morning's takings: a card that fills in row by row, then goes
        if game.dawnSeq != dawnSeen { dawnSeen = game.dawnSeq; showDawn() }
        if !dawnCard.isHidden {
            dawnCard.frame.origin.y = hint.isHidden ? dayLabel.frame.maxY + 8 : hint.frame.maxY + 6
            if CACurrentMediaTime() > dawnHideAt || userPaused || !game.cut.isEmpty {
                dawnHideAt = .greatestFiniteMagnitude
                UIView.animate(withDuration: 0.5, animations: { self.dawnCard.alpha = 0 }, completion: { _ in self.dawnCard.isHidden = true })
            }
        }
        // the next thing worth doing, shown small under the purse whenever no message is up
        let adv = hint.isHidden && !userPaused ? game.advice() : ""
        adviceLabel.isHidden = adv.isEmpty
        if !adv.isEmpty && adviceLabel.text != adv {
            adviceLabel.text = adv
            let aw = min(view.bounds.width * 0.6, adviceLabel.sizeThatFits(CGSize(width: 600, height: 24)).width + 4)
            adviceLabel.frame = CGRect(x: purse.frame.minX, y: purse.frame.maxY + 6, width: aw, height: 22)
        }
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
        if plainInfo && info.backgroundColor != .clear {
            // the other way to show it: dark lettering straight on the ground, no plate behind
            info.backgroundColor = .clear; info.layer.borderWidth = 0; info.textColor = UIColor(red: 0.1, green: 0.06, blue: 0.04, alpha: 1)
        }
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

/// A label that keeps its words off its own edges.
final class PadLabel: UILabel {
    var pad = UIEdgeInsets(top: 5, left: 14, bottom: 5, right: 14)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: pad)) }
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines n: Int) -> CGRect {
        let r = super.textRect(forBounds: bounds.inset(by: pad), limitedToNumberOfLines: n)
        return CGRect(x: r.minX - pad.left, y: r.minY - pad.top, width: r.width + pad.left + pad.right, height: r.height + pad.top + pad.bottom)
    }
}
