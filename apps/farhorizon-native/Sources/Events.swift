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

    static let omenLen = 4.2
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
        "overboard": ("A cry, and a splash!", "Man overboard!"),
        "fall": ("A scream from aloft!", "A hand has lost his footing on the yard"),
        "brawl": ("Shouting on deck", "Two of the watch are at each other's throats"),
        "galley": ("Smoke amidships!", "The galley stove has gone over"),
        "rats": ("Squealing in the stores", "Rats, and plenty of them"),
        "whale": ("There she blows!", "A whale, close aboard to starboard"),
        "spout": ("A waterspout!", "A twisting column is walking across the sea"),
        "spar": ("A crack like a gunshot", "The main yard has carried away"),
        "stowaway": ("A shout from the hold", "The cooper has found someone in a cask"),
        "catch": ("The stern line goes bar-tight", "Something big is coming over the rail"),
        "scurvy": ("The watch is slow to turn out", "Loose teeth, black gums, no strength in them"),
        "foulwater": ("A stink from the casks", "The water has gone green"),
        "weevils": ("The bread is moving", "Weevils in the biscuit, and worse in the flour"),
        "plank": ("The prize is yours!", "Her crew go over the side, one at a time"),
        "kraken": ("The sea heaves up alongside", "Arms as thick as the mainmast"),
        "stelmo": ("Blue fire at the mastheads", "St Elmo's fire. Not a man speaks"),
        "comet": ("A star is falling", "It comes down burning, straight for the sea ahead"),
        "whitewhale": ("There she blows, and white!", "The white whale the old hands swear to")
    ]
    func startOmen(_ k: String) {
        omenK = k
        omenT = 0
        sceneK = k
        sceneT = 0
        if k == "storm" { setWeather(3, days: 1) }
        if k == "fog" || k == "ghost" { setWeather(4, days: 1) }
        if k == "dolphins" { seaForce = 0 }
        if k == "spout" { setWeather(1, days: 1) }
        if k == "whale" || k == "catch" || k == "kraken" || k == "whitewhale" { snd?.splash() }
        if k == "kraken" { shake = max(shake, 0.4) }
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
            ("ghost", 1.2, 0.6), ("dolphins", 1, 1.6), ("fog", 1, 1.2), ("overboard", 0.8, 0.7),
            ("fall", 1.1, 1.0), ("brawl", 1.0, 1.0), ("galley", 0.9, 0.9), ("rats", 0.9, 1.0),
            ("whale", 1.0, 0.6), ("spout", 0.9, 0.6), ("spar", 1.0, 0.9), ("stowaway", 0.7, 0.9), ("catch", 0.9, 1.1),
            ("scurvy", 1.0, 0.5), ("foulwater", 0.9, 0.7), ("weevils", 0.9, 0.8)
        ]
        // once in a long while, something a sailor tells of for the rest of his life
        let rares = ["kraken", "stelmo", "comet", "whitewhale"].filter { !rareSeen.contains($0) }
        if !rares.isEmpty && chance(0.12), let rk = rares.randomElement() {
            rareSeen.insert(rk)
            startOmen(rk)
            return
        }
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
                Opt("Reef sails and wait", "lose \(2 * SUNS) days") { [unowned self] in
                    self.passDays(2)
                    if self.over { return }
                    self.dmg(Double(rndI(3, 8)))
                    if !self.over { self.done("Lost \(2 * SUNS) days") }
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
                Opt("Go ashore", "costs \(SUNS) days · three digs") { [unowned self] in
                    self.passDays(1)
                    if self.over { return }
                    self.playIsland()
                }, on
            ])
        case "calm":
            show("Becalmed", "The sails hang limp. Not a breath of wind.", [
                Opt("Man the oars", "pull her out on the beat") { [unowned self] in self.playRow() },
                Opt("Wait for wind", "lose \(2 * SUNS) days") { [unowned self] in
                    self.passDays(2)
                    if !self.over { self.done("Lost \(2 * SUNS) days") }
                }
            ])
        case "sick":
            show("Fever aboard", "Half the watch is laid out on deck.", [
                Opt("Rest the crew", "lose \(SUNS) days · one falls sick") { [unowned self] in
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
        case "fall":
            logIt("A hand fell from the yard")
            show("A fall from aloft", "He came down forty feet onto the planks. He is up, hopping and cursing, but that leg is broken.", [
                Opt("Splint it and rest him", "he is laid up for some days") { [unowned self] in
                    self.toastText = ""
                    self.hurtOne("a broken leg")
                    if !self.over { self.done(self.toastText.isEmpty ? "The surgeon sets the bone" : self.toastText) }
                },
                Opt("Rum, and back to work", "he may not stand it") { [unowned self] in
                    if chance(0.55) {
                        self.done("He hobbles, white in the face, but he stands his watch")
                    } else {
                        self.loseCrew("Died of a broken leg")
                        if !self.over { self.done("The leg goes bad. He is buried at sea two nights later") }
                    }
                }
            ])
        case "brawl":
            logIt("A fight on deck")
            show("A fight on deck", "A missing ration, a hard word, and now two of the watch are swinging at each other with the rest cheering them on.", [
                Opt("Break it up", "you wade in yourself") { [unowned self] in self.done("They are hauled apart, glaring. It will keep") },
                Opt("Let them settle it", "one will be hurt") { [unowned self] in
                    self.toastText = ""
                    self.hurtOne("a fight on deck")
                    if !self.over { self.done(self.toastText.isEmpty ? "It ends with a split lip and a handshake" : self.toastText) }
                },
                Opt("Fine them both", "+15 gold") { [unowned self] in
                    self.gold += 15
                    self.snd?.coin()
                    self.done("Their pay is docked. They stop, and hate you instead: +15 gold")
                }
            ])
        case "galley":
            logIt("Fire in the galley")
            show("Fire in the galley!", "The stove has gone over and the deck is alight. The watch is running with buckets.", [
                Opt("Use the water casks", water >= 4 ? "lose 4 water" : "there is not enough water", off: water < 4) { [unowned self] in
                    self.water = max(0, self.water - 4)
                    self.done("Out, and nothing lost but drinking water: -4 water")
                },
                Opt("Smother it with wet canvas", "the planks will scorch") { [unowned self] in
                    self.dmg(7)
                    if !self.over { self.done("It is out, but the deck is charred through in places") }
                }
            ])
        case "rats":
            logIt("Rats in the stores")
            show("Rats in the stores", "They are all over the deck and deep in the bread.", [
                Opt("Turn out the hold", "lose \(SUNS) days hunting them") { [unowned self] in
                    self.passDays(1)
                    if !self.over { self.done("Every last one goes over the side") }
                },
                Opt("Leave them to it", "they will eat") { [unowned self] in
                    self.food = max(0, self.food - 6)
                    self.done("They get fat on your stores: -6 food")
                }
            ])
        case "kraken":
            logIt("Met the kraken")
            show("The Kraken", "It has the ship in its arms and is feeling along the rail for something to eat. A sight few live to tell of.", [
                Opt("Fire into it", powder >= 3 ? "every gun · -3 powder" : "not enough powder", off: powder < 3) { [unowned self] in
                    self.powder -= 3
                    self.snd?.boom()
                    self.shake = 0.5
                    self.done("It lets go all at once and sinks, the sea boiling black: -3 powder")
                },
                Opt("Cut the arms away", "axes and cutlasses") { [unowned self] in
                    self.dmg(14)
                    if !self.over { self.toastText = ""; self.hurtOne("the kraken") }
                    if !self.over { self.done("Hacked through, arm by arm. The rail is gone and the planks are sprung") }
                },
                Opt("Throw it the stores", "-10 food") { [unowned self] in
                    self.food = max(0, self.food - 10)
                    self.done("Cask after cask goes over. It takes them, and leaves you: -10 food")
                }
            ])
        case "stelmo":
            logIt("St Elmo's fire")
            show("St Elmo's fire", "Cold blue flame stands on every masthead and yardarm and burns nothing. The old hands say it is the saint himself.", [
                Opt("Call it a blessing", "the laid-up take heart") { [unowned self] in
                    for m in self.men where m.st != 0 { m.d = max(1, m.d - 3) }
                    self.snd?.good()
                    self.done("The whole ship is easier for it, and the sick mend faster")
                },
                Opt("Crowd on sail while it lasts", "the wind that follows is fair") { [unowned self] in
                    self.dist = min(self.legLen - 1, self.dist + 40)
                    self.done("A strong fair wind comes behind it: 40 leagues made good")
                }
            ])
        case "comet":
            logIt("A star fell into the sea")
            show("A fallen star", "It struck the sea a mile ahead. Something black and smoking is still afloat there on a raft of weed.", [
                Opt("Fish it out", "sky-iron is worth a fortune") { [unowned self] in
                    self.gold += 120
                    self.snd?.coin()
                    self.done("A lump of sky-iron the size of a man's head. Any smith will pay: +120 gold")
                },
                Opt("Steer wide of it", "the hands do not like it") { [unowned self] in self.done("You leave it hissing astern. Nobody looks back") }
            ])
        case "whitewhale":
            logIt("Raised the white whale")
            show("The white whale", "White as a sail and scarred from a hundred irons. There is a king's bounty on her, and a graveyard of boats behind her.", [
                Opt("Lower away and hunt her", "250 gold, or a stove boat") { [unowned self] in
                    if chance(0.4) {
                        self.gold += 250
                        self.snd?.coin()
                        self.done("Against all sense, you take her. The bounty is yours: +250 gold")
                    } else {
                        self.dmg(16)
                        if !self.over { self.loseCrew("Taken by the white whale") }
                        if !self.over { self.done("She comes up under the boat. One man does not come back") }
                    }
                },
                Opt("Let her pass", "the hands call it luck") { [unowned self] in
                    for m in self.men where m.st != 0 { m.d = max(1, m.d - 2) }
                    self.done("She rolls once, looks at you, and goes down. The watch cheers her")
                }
            ])
        case "plank":
            show(pendTitle, pendText, [Opt("Sail on") { [unowned self] in self.done("") }])
        case "scurvy":
            logIt("Scurvy aboard")
            show("Scurvy", "Too long on salt meat. Half the watch can barely haul, and it will get worse.", [
                Opt("Fresh food for the sick", food >= 5 ? "the best of the stores · -5 food" : "there is not enough food", off: food < 5) { [unowned self] in
                    self.food = max(0, self.food - 5)
                    self.done("Onions, lime juice and the last of the fruit. They mend slowly: -5 food")
                },
                Opt("Work them regardless", "two will go down") { [unowned self] in
                    self.toastText = ""
                    self.sickOne("scurvy")
                    if !self.over { self.sickOne("scurvy") }
                    if !self.over { self.done("Two men cannot rise from their hammocks") }
                }
            ])
        case "foulwater":
            logIt("The water went bad")
            let lost = Int((water * 0.3).rounded())
            show("Foul water", "Three casks have turned. The smell alone would drop a horse.", [
                Opt("Pour it over the side", "-\(lost) water") { [unowned self] in
                    self.water = max(0, self.water - Double(lost))
                    self.done("Green water over the rail: -\(lost) water")
                },
                Opt("Drink it anyway", "someone will sicken") { [unowned self] in
                    self.toastText = ""
                    self.sickOne("bad water")
                    if !self.over { self.done(self.toastText.isEmpty ? "They hold their noses and drink" : self.toastText) }
                }
            ])
        case "weevils":
            logIt("Weevils in the bread")
            let lost = Int((food * 0.25).rounded())
            show("Weevils", "The biscuit is alive, and the flour has gone grey with them.", [
                Opt("Throw out the worst", "-\(lost) food") { [unowned self] in
                    self.food = max(0, self.food - Double(lost))
                    self.done("A quarter of the bread goes to the fish: -\(lost) food")
                },
                Opt("Pick them out", "all hands · lose \(SUNS) days") { [unowned self] in
                    self.passDays(1)
                    if !self.over { self.done("Every biscuit rapped on the table, every sack sieved") }
                }
            ])
        case "whale":
            logIt("A whale alongside")
            show("A whale alongside", "She surfaces a cable off, longer than the ship, blows, and rolls an eye at you.", [
                Opt("Lower the boat", "meat and oil, if it goes well") { [unowned self] in
                    if chance(0.55) {
                        let a = self.addGood("food", 12)
                        self.done("Two days of butchery over the side: +\(a) food")
                    } else {
                        self.dmg(8)
                        if !self.over { self.hurtOne("the whale's flukes") }
                        if !self.over { self.done("Her flukes stave the boat in and crack a strake on the way down") }
                    }
                },
                Opt("Watch her go") { [unowned self] in self.done("The whole watch lines the rail until she sounds") }
            ])
        case "spout":
            logIt("Met a waterspout")
            show("Waterspout", "A twisting column of water, black at the top, is walking across the sea toward you.", [
                Opt("Run before it", "lose \(SUNS) days") { [unowned self] in
                    self.passDays(1)
                    if !self.over { self.done("It passes a mile astern and falls apart") }
                },
                Opt("Hold your course", "it may miss") { [unowned self] in
                    if chance(0.5) {
                        self.done("It wanders off to leeward and collapses in rain")
                    } else {
                        self.dmg(12)
                        if !self.over { self.done("It crosses the bow and takes half the rigging with it") }
                    }
                }
            ])
        case "spar":
            logIt("Lost a spar")
            show("A spar carries away", "The main yard has cracked through and hangs by its tackle, sail and all, beating against the mast.", [
                Opt("Fish it with planks", planks >= 2 ? "use 2 planks" : "not enough planks", off: planks < 2) { [unowned self] in
                    self.planks -= 2
                    self.done("Splinted, and swayed back aloft: -2 planks")
                },
                Opt("Cut it away", "short canvas · lose \(SUNS) days") { [unowned self] in
                    self.passDays(1)
                    if !self.over { self.done("It goes over the side. She crawls until a new one is rigged") }
                }
            ])
        case "stowaway":
            logIt("Found a stowaway")
            show("A stowaway", "A boy, half starved, asleep in an empty cask. He says he will work.", [
                Opt("Sign him on", crew < ship.crew ? "one more hand" : "no berth free", off: crew >= ship.crew) { [unowned self] in
                    self.crew += 1
                    self.syncMen()
                    self.done("He is rated ship's boy and given a hammock")
                },
                Opt("Feed him, land him next port", "-2 food") { [unowned self] in
                    self.food = max(0, self.food - 2)
                    self.done("He eats like three men and sleeps for a day")
                }
            ])
        case "catch":
            logIt("Landed a great fish")
            show("A monster on the line", "It takes four hands to get it over the rail, and now it is beating the deck to pieces.", [
                Opt("Salt it down", "food for the cask") { [unowned self] in
                    let a = self.addGood("food", 8)
                    self.done("Cut, salted and stowed: +\(a) food")
                },
                Opt("Feast tonight", "the laid-up mend faster") { [unowned self] in
                    self.addGood("food", 3)
                    for m in self.men where m.st != 0 { m.d = max(1, m.d - 2) }
                    self.done("Fresh fish for all hands: +3 food, and the sick are the better for it")
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
                Opt("Rescue him", "drive off the sharks") { [unowned self] in self.playShark() }, on
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
                Opt("Heave to", "lose \(SUNS) days") { [unowned self] in
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
        var g = d.prize * 3 / 2
        if bounty { g += 150; bounty = false }
        gold += g
        let pw = addGood("powder", 4), bl = addGood("arms", 2)
        logIt(d.boss ? "Took the Red Mary" : "Took a pirate ship by boarding")
        var t = "Her deck is cleared and her hold is yours.\nPlunder: \(g) gold"
        if pw > 0 { t += ", \(pw) powder" }
        if bl > 0 { t += ", \(bl) blades" }
        // first the cheering, and her crew sent over the side; then the count of the plunder
        pendTitle = d.boss ? "The Red Mary is taken!" : "The prize is yours"
        pendText = t
        card = nil
        startOmen("plank")
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
            var yo = Opt(y.n + (y.max > 1 ? " \(min(y.max, lv + 1))" : ""), maxed ? "fitted" : y.d + " · \(price) gold", off: maxed) { [unowned self] in
                if self.gold < price { self.toast("Not enough gold"); return }
                self.gold -= price
                self.ups[y.k] = lv + 1
                if y.k == "hull" { self.hull += 25 }
                self.snd?.coin(); self.snd?.good()
                self.puff(self.W / 2, self.H / 2, 40, Col(0xffd257), 260, 320, 3, 0.8)
                self.toast(y.n + " fitted")
                self.shipwright()
            }
            yo.pic = y.k
            opts.append(yo)
        }
        opts.append(Opt("Leave") { [unowned self] in self.card = nil })
        opts[0].pic = "repair"
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
            var po = Opt(a.0, a.2 ? "learned" : a.1 + " · 90 gold", off: a.2) { [unowned self] in
                if self.gold < 90 { self.toast("Not enough gold"); return }
                self.gold -= 90
                a.3()
                self.snd?.clang(); self.snd?.good()
                self.toast("Learned: " + a.0)
                self.tavernSword()
            }
            po.pic = a.0 == "The killing riposte" ? "riposte" : (a.0 == "Second wind" ? "wind" : "fury")
            opts.append(po)
        }
        opts.append(Opt("Leave") { [unowned self] in self.card = nil })
        show("The swordmaster", "An old fencing master drinks here. For a price he will show your boarders a thing or two.", opts)
    }
    func well() {
        if wellDry() { toast("The well here is brackish. Buy water at the market"); return }
        if wellUsed { toast("The casks are already filled"); return }
        wellUsed = true
        let a = addGood("water", 10)
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
