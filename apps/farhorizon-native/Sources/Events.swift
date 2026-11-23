import Foundation

// What happens at sea and in port. Each event is a card with choices; the sword fight is its own scene.

extension Game {
    /// Ends an event. An outcome is shown as its own card, so the player always sees what happened.
    func done(_ msg: String) {
        let title = card?.title ?? evTitle
        card = nil
        if deckForce < 0 { seaForce = -1 }
        if msg.isEmpty || over { return }
        toastT = 0
        show(title, msg, [Opt(mode == .sail ? "Sail on" : "Continue") { [unowned self] in self.card = nil }])
    }

    static let omenLen = 2.8
    static var omenHold = false
    /// What is seen, and said, as each event comes over the horizon.
    static let OMENS: [String: (String, String)] = [
        "storm": ("The glass is falling", "Black cloud piling up to windward"),
        "pirates": ("Sail ho!", "A black flag astern, and closing fast"),
        "blockade": ("Red sails ahead", "A great ship stands across the channel"),
        "fish": ("Gulls diving", "The water ahead is boiling with fish"),
        "wreck": ("Wreckage", "Something broken is drifting down on you"),
        "island": ("Land ho!", "A low island lifts over the horizon"),
        "calm": ("The wind is dying", "The sails slat and hang"),
        "sick": ("A man goes down", "He drops at his post, burning with fever"),
        "merchant": ("A sail to leeward", "A merchantman, signalling to speak"),
        "bottle": ("A glint in the swell", "Something small is bobbing off the bow"),
        "leak": ("A shout from below!", "Water in the hold"),
        "castaway": ("A raft!", "Someone is waving from it"),
        "ghost": ("Something pale on the water", "No lights. No one at her helm"),
        "dolphins": ("Fins off the bow", "A pod is racing in to meet you"),
        "fog": ("A grey wall ahead", "The horizon is gone"),
        "overboard": ("A cry, and a splash!", "Man overboard!")
    ]
    func startOmen(_ k: String) {
        omenK = k
        omenT = 0
        if k == "storm" { setWeather(3, days: 1) }
        if k == "fog" || k == "ghost" { setWeather(4, days: 1) }
        if k == "dolphins" { seaForce = 0 }
        // a drum, and a held note under it
        snd?.tone(72, 0.7, 0, 0.32, 48)
        snd?.tone(72, 0.6, 0, 0.26, 48, 0.55)
        snd?.held(k == "dolphins" || k == "fish" || k == "island" || k == "merchant" ? 392 : 147, 2.4, 5, 0.03, att: 0.6, rel: 1.2)
        if k == "overboard" || k == "bottle" { snd?.splash() }
        if k == "pirates" || k == "blockade" { snd?.cannon() }
    }

    func rollEvent() {
        sinceEvent = 0
        legEvents += 1
        // name, weight by the open sea, weight along the coast
        let table: [(String, Double, Double)] = [
            ("storm", 3, 1.4), ("pirates", 2.6, 1.3), ("fish", 1.4, 3), ("wreck", 2, 2), ("island", 1.1, 2.4), ("calm", 1.2, 1),
            ("sick", 0.9, 0.9), ("merchant", 1, 2.2), ("bottle", 0.8, 0.8), ("leak", 1.1, 0.9), ("castaway", 0.8, 0.8),
            ("ghost", 1.2, 0.6), ("dolphins", 1, 1.6), ("fog", 1, 1.2), ("overboard", 0.8, 0.7)
        ]
        var total = 0.0
        for t in table where t.0 != lastEv { total += route == 1 ? t.1 : t.2 }
        var r = rnd(0, total)
        for t in table where t.0 != lastEv {
            r -= route == 1 ? t.1 : t.2
            if r <= 0 { startOmen(t.0); return }
        }
        startOmen("fish")
    }

    func event(_ k: String) {
        lastEv = k
        let on = Opt("Sail on") { [unowned self] in self.done("") }
        switch k {
        case "storm":
            logIt("Ran into a storm")
            show("Storm ahead", "Black clouds are closing fast.", [
                Opt("Take the helm", "steer her through it yourself") { [unowned self] in self.playStorm() },
                Opt("Reef sails and wait", "lose 2 days") { [unowned self] in
                    self.passDays(2)
                    if self.over { return }
                    self.dmg(Double(rndI(3, 8)))
                    if !self.over { self.done("Lost 2 days") }
                }
            ])
        case "pirates":
            logIt("Pirates sighted")
            let tribute = max(40, Int(Double(gold) * 0.25))
            let n = rndI(5, 7)
            let prize = rndI(90, 200)
            show("Pirates!", "A black flag on the horizon.", [
                Opt("Fight", powder >= 2 ? "a broadside, then board her" : "no powder · blades only") { [unowned self] in
                    var foes = n
                    if self.powder >= 2 {
                        self.powder -= 2
                        foes -= 1 + self.up("guns")
                        self.snd?.cannon()
                        self.toast("Your broadside rakes her deck")
                    }
                    self.startDuel(foes: foes, boss: false, prize: prize)
                },
                Opt("Run", "trim the sails and outpace her") { [unowned self] in self.playRun(n, prize) },
                Opt("Pay tribute", "\(tribute) gold") { [unowned self] in
                    self.gold = max(0, self.gold - tribute)
                    self.done("Paid \(tribute) gold")
                }
            ])
        case "blockade":
            logIt("The Red Mary bars the way")
            show("The Red Mary", "Blood-red sails stand across the channel to Santa Aurelia. Her captain means to take your ship himself.", [
                Opt("Board her", "cross swords with her captain") { [unowned self] in
                    self.startDuel(foes: 6, boss: true, prize: 400)
                },
                Opt("Run the line", "heavy damage") { [unowned self] in
                    self.snd?.cannon()
                    self.dmg(Double(rndI(18, 30)))
                    if self.over { return }
                    if chance(0.5) { self.hurtOne("hit by shot") }
                    self.done("Shot howls overhead, but you are through")
                }
            ])
        case "fish":
            show("Fish running", "Gulls are diving on a big school.", [
                Opt("Drop lines", bait < 1 ? "no bait" : "\(min(3, bait)) casts", off: bait < 1) { [unowned self] in self.playFish() }, on
            ])
        case "wreck":
            show("Wreckage", "A broken hull drifts ahead, half under.", [
                Opt("Salvage it", "hook three crates") { [unowned self] in self.playWreck() }, on
            ])
        case "island":
            show("Land ho!", hasMap ? "It matches your treasure map!" : "An uncharted island.", [
                Opt("Go ashore", "costs a day · three digs") { [unowned self] in
                    self.passDays(1)
                    if self.over { return }
                    self.playIsland()
                }, on
            ])
        case "calm":
            show("Becalmed", "The sails hang limp. Not a breath of wind.", [
                Opt("Man the oars", "extra rations") { [unowned self] in
                    self.consume()
                    if !self.over { self.done("The crew rows her out. Extra rations used") }
                },
                Opt("Wait for wind", "lose 2 days") { [unowned self] in
                    self.passDays(2)
                    if !self.over { self.done("Lost 2 days") }
                }
            ])
        case "sick":
            show("Fever aboard", "Half the watch is laid out on deck.", [
                Opt("Rest a day", "lose 1 day · one falls sick") { [unowned self] in
                    self.toastText = ""
                    self.sickOne("the fever")
                    self.passDays(1)
                    if !self.over { self.done(self.toastText) }
                },
                Opt("Press on", "more will fall sick") { [unowned self] in
                    self.toastText = ""
                    self.sickOne("the fever")
                    if !self.over && chance(0.5) { self.sickOne("the fever") }
                    if !self.over { self.done(self.toastText) }
                }
            ])
        case "merchant":
            merchant()
        case "bottle":
            show("Something in the water", "A corked bottle bobs in the swell.", [
                Opt("Fish it out") { [unowned self] in
                    if !self.hasMap {
                        self.hasMap = true
                        self.snd?.good()
                        self.done("A treasure map! An island is marked on the route ahead")
                    } else {
                        self.gold += 30
                        self.snd?.coin()
                        self.done("A few coins inside: +30 gold")
                    }
                }, on
            ])
        case "leak":
            show("Sprung a leak", "Water is spraying through the planks.", [
                Opt("All hands below", planks > 0 ? "hammer planks over the leaks" : "no planks · stuff them with canvas") { [unowned self] in self.playLeak() },
                Opt("Bail and hope", "hull damage") { [unowned self] in
                    self.dmg(10)
                    if !self.over { self.done("Hull damaged") }
                }
            ])
        case "castaway":
            show("Castaway", "A man on a raft waves wildly. A fin circles him.", [
                Opt("Rescue him") { [unowned self] in
                    if self.crew < self.ship.crew {
                        self.crew += 1
                        self.syncMen()
                        self.done("He joins your crew")
                    } else {
                        self.gold += 40
                        self.snd?.coin()
                        self.done("He pays 40 gold for passage")
                    }
                }, on
            ])
        case "ghost":
            show("Ghost ship", "A pale ship drifts in the dark with no one at the helm.", [
                Opt("Board her", "open two hatches") { [unowned self] in self.playGhost() },
                Opt("Steer clear") { [unowned self] in self.done("") }
            ])
        case "dolphins":
            dist += 22
            show("Dolphins", "A pod races the bow wave and the crew cheers. The ship seems to fly.", [on])
        case "fog":
            show("Fog bank", "Grey fog swallows the ship. Somewhere ahead, surf is breaking.", [
                Opt("Creep through", E("look") > 0 ? "your lookout gives you longer" : "no lookout posted") { [unowned self] in self.playFog() },
                Opt("Heave to", "lose 1 day") { [unowned self] in
                    self.passDays(1)
                    if !self.over { self.done("The fog lifts by morning") }
                }
            ])
        default:
            show("Man overboard!", "A wave takes a hand off the rail.", [
                Opt("Throw a line", "three tries") { [unowned self] in self.playLine() }
            ])
        }
    }

    func merchant() {
        func buy(_ k: String, _ n: Int, _ cost: Int) -> () -> Void {
            return { [unowned self] in
                if self.gold < cost { self.toast("Not enough gold"); return }
                let a = self.addGood(k, n)
                if a == 0 { self.toast("The hold is full"); return }
                self.gold -= cost
                self.snd?.coin()
                self.toast("+\(a) \(k)")
            }
        }
        show("Merchant ship", "They offer to trade.", [
            Opt("Food ×10", "50 gold", buy("food", 10, 50)), Opt("Water ×10", "30 gold", buy("water", 10, 30)),
            Opt("Planks ×5", "50 gold", buy("planks", 5, 50)), Opt("Sail on") { [unowned self] in self.done("") }
        ])
    }

    // ---------- the sword fight
    func startDuel(foes: Int, boss: Bool, prize: Int, teach: Bool = true) {
        card = nil
        fights += 1
        let ratio = min(1, Double(arms) / Double(max(1, crew)))
        let d = Duel(foes: max(1, foes), boss: boss, prize: prize, armed: ratio, teach: teach)
        d.fury = perkFury ? 0.5 : 0
        duel = d
        mode = .duel
        // no briefing: the first fight walks through each move as it comes up
        toast(d.teaching ? "Watch his blade. The first cuts will wait for you" : (duelPort ? (duelSport ? "Blunted blades. First to three touches" : "Raiders on the quay!") : (boss ? "Her captain steps onto the deck" : "Boarders away!")))
    }
    func duelSailorDown() {
        // a tournament is fought with blunted blades: pride is all that is lost
        if duelSport { toast("A touch! Your man is out of the bout"); return }
        if chance(0.5) { loseCrew("A sailor is cut down") } else { hurtOne("cut down in the boarding") }
    }
    func duelWon(_ d: Duel) {
        duel = nil
        snd?.good()
        if duelPort {
            mode = .port
            portJobDone = true
            let sport = duelSport
            duelPort = false; duelSport = false
            let g = d.prize * 2
            gold += g
            festT = max(festT, 6)
            if sport {
                show("Champion of the quay", "The crowd carries your man round the square on their shoulders.\nThe purse: \(g) gold.", [Opt("Take a bow") { [unowned self] in self.card = nil }])
            } else {
                let fix = min(Double(ship.hull) - hull, 20)
                hull += max(0, fix)
                logIt("Drove pirates off the quay at " + here.n)
                show("The town is saved", "The raiders run for their boats. The harbour master presses \(g) gold on you, and the yard mends your hull for nothing.", [Opt("Their thanks is enough") { [unowned self] in self.card = nil }])
            }
            return
        }
        mode = .sail
        var g = d.prize * 2
        if bounty { g += 150; bounty = false }
        gold += g
        let pw = addGood("powder", 4), bl = addGood("arms", 2)
        logIt(d.boss ? "Took the Red Mary" : "Took a pirate ship by boarding")
        var t = "Her deck is cleared and her hold is yours.\nPlunder: \(g) gold"
        if pw > 0 { t += ", \(pw) powder" }
        if bl > 0 { t += ", \(bl) blades" }
        show(d.boss ? "The Red Mary is taken!" : "The prize is yours", t, [Opt("Sail on") { [unowned self] in self.done("") }])
    }
    func duelLost(_ d: Duel) {
        duel = nil
        if over { return }
        if duelPort {
            mode = .port
            portJobDone = true
            let sport = duelSport
            duelPort = false; duelSport = false
            if sport {
                show("Beaten", "Three touches against you. The crowd is kind about it.", [Opt("Next time") { [unowned self] in self.card = nil }])
            } else {
                let loss = min(gold, 60)
                gold -= loss
                show("Driven off the quay", "The raiders take what they came for, and \(loss) gold from your own chest.", [Opt("Back to the ship") { [unowned self] in self.card = nil }])
            }
            return
        }
        mode = .sail
        logIt("Driven back from a boarding")
        let loss = min(gold, d.boss ? 200 : 80)
        gold -= loss
        dmg(d.boss ? 18 : 8)
        if over { return }
        show("Driven back", "Your boarders are thrown back over the rail. You cut the grapples and run, \(loss) gold lighter.", [Opt("Sail on") { [unowned self] in self.done("") }])
    }

    // ---------- in port
    func openMarket() { marketPort = true; mode = .market }
    func tavern() {
        if recruit == nil { recruit = Man() }
        mode = .tavern
        snd?.bell()
    }
    func tavernHire() {
        guard let rec = recruit else { return }
        if crew >= ship.crew { toast("Your crew is full"); return }
        if gold < 40 { toast("Not enough gold"); return }
        gold -= 40
        men.append(rec)
        crew += 1
        recruit = nil
        autoPost()
        snd?.coin()
        toast(rec.n + " signs on")
    }
    func tavernMap() {
        if hasMap { toast("You already carry a map"); return }
        if gold < 120 { toast("Not enough gold"); return }
        gold -= 120
        hasMap = true
        snd?.coin()
        show("The old chart", "He slides it across the table and is gone before you look up.\nAn island is marked on your next leg. Go ashore there and dig.", [Opt("Pocket it") { [unowned self] in self.card = nil }])
    }
    func tavernSurgeon() {
        let down = laidUp()
        if down == 0 { toast("All hands are well"); return }
        if gold < down * 20 { toast("Not enough gold"); return }
        gold -= down * 20
        for m in men where !m.fit { m.st = 0; m.d = 0 }
        autoPost()
        snd?.good()
        toast("The surgeon patches them up")
    }
    /// What the yards can add to a ship: key, name, what it does, most levels, price of the first.
    static let YARD: [(k: String, n: String, d: String, max: Int, cost: Int)] = [
        ("sails", "Taller masts", "+9% speed", 2, 150),
        ("hull", "Copper sheathing", "+25 hull", 2, 140),
        ("hold", "Deeper hold", "+50 hold", 2, 120),
        ("guns", "Swivel guns", "thin boarders more", 2, 160),
        ("berths", "Extra berths", "+2 crew", 1, 130)
    ]
    func shipwright() {
        let need = Int(Double(ship.hull) - hull)
        let cost = need * 2
        var opts: [Opt] = [
            Opt("Repair the hull", need > 0 ? "\(cost) gold" : "nothing to mend", off: need <= 0) { [unowned self] in
                let can = min(need, self.gold / 2)
                if can <= 0 { self.toast("Not enough gold"); return }
                self.gold -= can * 2
                self.hull += Double(can)
                self.snd?.good()
                self.toast("Hull repaired by \(can)")
                self.shipwright()
            }
        ]
        for y in Game.YARD {
            let lv = up(y.k)
            let price = y.cost + lv * (y.cost * 3 / 4)
            let maxed = lv >= y.max
            opts.append(Opt(y.n + (y.max > 1 ? " \(min(y.max, lv + 1))" : ""), maxed ? "fitted" : y.d + " · \(price) gold", off: maxed) { [unowned self] in
                if self.gold < price { self.toast("Not enough gold"); return }
                self.gold -= price
                self.ups[y.k] = lv + 1
                if y.k == "hull" { self.hull += 25 }
                self.snd?.coin(); self.snd?.good()
                self.puff(self.W / 2, self.H / 2, 40, Col(0xffd257), 260, 320, 3, 0.8)
                self.toast(y.n + " fitted")
                self.shipwright()
            })
        }
        opts.append(Opt("Leave") { [unowned self] in self.card = nil })
        let fitted = Game.YARD.reduce(0) { $0 + up($1.k) }
        show("Shipwright", (need > 0 ? "She needs \(need) points of work." : "She is sound.") + " The yard can also improve her" + (fitted > 0 ? " further." : "."), opts)
    }
    func tavernSword() {
        let all: [(String, String, Bool, () -> Void)] = [
            ("The killing riposte", "a perfect parry hits for 3", perkRip, { [unowned self] in self.perkRip = true }),
            ("Second wind", "wind returns 40% faster", perkWind, { [unowned self] in self.perkWind = true }),
            ("Blood up", "fury builds faster, starts half full", perkFury, { [unowned self] in self.perkFury = true })
        ]
        var opts: [Opt] = []
        for a in all {
            opts.append(Opt(a.0, a.2 ? "learned" : a.1 + " · 90 gold", off: a.2) { [unowned self] in
                if self.gold < 90 { self.toast("Not enough gold"); return }
                self.gold -= 90
                a.3()
                self.snd?.clang(); self.snd?.good()
                self.toast("Learned: " + a.0)
                self.tavernSword()
            })
        }
        opts.append(Opt("Leave") { [unowned self] in self.card = nil })
        show("The swordmaster", "An old fencing master drinks here. For a price he will show your boarders a thing or two.", opts)
    }
    func well() {
        if wellUsed { toast("The casks are already filled"); return }
        wellUsed = true
        let a = addGood("water", 15)
        snd?.splash()
        toast(a > 0 ? "+\(a) fresh water" : "The hold is full")
    }
    func setSail() {
        let due = wagesDue()
        let short = gold < due
        show("Your ship", "Ready to cast off? The crew is owed \(due) gold in wages" + (short ? " — more than you have. Unpaid men may desert." : "."), [
            Opt("Set sail") { [unowned self] in self.card = nil; self.mode = .chart },
            Opt("Stay") { [unowned self] in self.card = nil }
        ])
    }
}
