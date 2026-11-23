import Foundation

// What happens at sea and in port. Each event is a card with choices; the sword fight is its own scene.

extension Game {
    /// Ends an event. An outcome is shown as its own card, so the player always sees what happened.
    func done(_ msg: String) {
        let title = card?.title ?? evTitle
        card = nil
        if msg.isEmpty || over { return }
        toastT = 0
        show(title, msg, [Opt(mode == .sail ? "Sail on" : "Continue") { [unowned self] in self.card = nil }])
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
            if r <= 0 { event(t.0); return }
        }
        event("fish")
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
            let n = rndI(3, 4)
            let prize = rndI(90, 200)
            show("Pirates!", "A black flag on the horizon.", [
                Opt("Fight", powder >= 2 ? "a broadside, then board her" : "no powder · blades only") { [unowned self] in
                    var foes = n
                    if self.powder >= 2 {
                        self.powder -= 2
                        foes -= 1
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
                    self.startDuel(foes: 3, boss: true, prize: 400)
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
        duel = d
        mode = .duel
        // no briefing: the first fight walks through each move as it comes up
        toast(d.teaching ? "Watch his blade. The first cuts will wait for you" : (boss ? "Her captain steps onto the deck" : "Boarders away!"))
    }
    func duelSailorDown() {
        if chance(0.5) { loseCrew("A sailor is cut down") } else { hurtOne("cut down in the boarding") }
    }
    func duelWon(_ d: Duel) {
        duel = nil
        mode = .sail
        let g = d.prize * 2
        gold += g
        let pw = addGood("powder", 4), bl = addGood("arms", 2)
        snd?.good()
        logIt(d.boss ? "Took the Red Mary" : "Took a pirate ship by boarding")
        var t = "Her deck is cleared and her hold is yours.\nPlunder: \(g) gold"
        if pw > 0 { t += ", \(pw) powder" }
        if bl > 0 { t += ", \(bl) blades" }
        show(d.boss ? "The Red Mary is taken!" : "The prize is yours", t, [Opt("Sail on") { [unowned self] in self.done("") }])
    }
    func duelLost(_ d: Duel) {
        duel = nil
        if over { return }
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
    func tavernRumour() {
        let all = [
            "The open sea is the quicker road, but that is where the black flags hunt.",
            "Keep a man at the masthead. In fog he buys you time among the rocks.",
            "Salt pork turns after five days out. A cook in the galley halves the waste.",
            "A carpenter at his post mends a little of the hull every day at sea.",
            "The Red Mary lies off Santa Aurelia. Her captain fights hardest when he is nearly beaten.",
            "Blades for every hand make the parry easier when you are boarded.",
            "Unpaid men walk. Count the wages before you buy the last cask of powder.",
            "A gunner and two charges of powder thin a pirate crew before the boarding."
        ]
        rumourHeard = true
        snd?.click()
        show("The barkeep leans in", all[(leg * 3 + day) % all.count], [Opt("Good to know") { [unowned self] in self.card = nil }])
    }
    func shipwright() {
        let need = Int(Double(ship.hull) - hull)
        let cost = need * 2
        show("Shipwright", need > 0 ? "She needs \(need) points of work." : "She is as sound as the day she was launched.", [
            Opt("Repair the hull", need > 0 ? "\(cost) gold" : "nothing to mend", off: need <= 0) { [unowned self] in
                let can = min(need, self.gold / 2)
                if can <= 0 { self.toast("Not enough gold"); return }
                self.gold -= can * 2
                self.hull += Double(can)
                self.snd?.good()
                self.toast("Hull repaired by \(can)")
                self.shipwright()
            },
            Opt("Leave") { [unowned self] in self.card = nil }
        ])
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
