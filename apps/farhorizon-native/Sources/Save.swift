import Foundation

// The voyage is saved whenever you are ashore, so a long passage can be picked up later.

extension Game {
    static let saveKey = "fh_save_v1"

    var hasSave: Bool { return UserDefaults.standard.dictionary(forKey: Game.saveKey) != nil }
    /// A line for the title screen: where the saved voyage stands.
    var saveLine: String {
        guard let d = UserDefaults.standard.dictionary(forKey: Game.saveKey) else { return "" }
        let day = d["cal"] as? Int ?? 1
        let port = d["port"] as? String ?? ""
        return "Day \(day) · " + port
    }
    func clearSave() { UserDefaults.standard.removeObject(forKey: Game.saveKey) }

    func saveGame() {
        if over || leg >= 5 { return }
        var crewList: [[String: Any]] = []
        for m in men { crewList.append(["n": m.n, "sk": m.sk, "sk2": m.sk2, "post": m.post, "st": m.st, "d": m.d]) }
        let d: [String: Any] = [
            "cal": cal, "port": here.n,
            "gold": gold, "food": food, "planks": planks, "bait": bait, "powder": powder, "arms": arms,
            "hull": hull, "shipI": shipI, "day": day, "leg": leg, "path": path, "route": route, "half": half,
            "hasMap": hasMap, "men": crewList, "dead": dead, "log": Array(log.suffix(40)), "ups": ups,
            "perkRip": perkRip, "perkWind": perkWind, "perkFury": perkFury,
            "cargoPay": cargoPay, "cargoHold": cargoHold, "fareDue": fareDue, "fareBy": fareBy, "bounty": bounty,
            "weather": weather, "wellUsed": wellUsed, "portJobs": portJobs, "jobsDone": Array(jobsDone),
            "blk": blk, "fights": fights, "tod": tod, "rot": rot
        ]
        UserDefaults.standard.set(d, forKey: Game.saveKey)
    }

    /// Puts a saved voyage back on the quay where it was left. Returns false if there is nothing usable.
    @discardableResult
    func loadGame() -> Bool {
        guard let d = UserDefaults.standard.dictionary(forKey: Game.saveKey) else { return false }
        newGame()
        gold = d["gold"] as? Int ?? gold
        food = d["food"] as? Double ?? 0
        // older saves kept water apart; it goes into the stores
        food += d["water"] as? Double ?? 0
        planks = d["planks"] as? Int ?? 0
        bait = d["bait"] as? Int ?? 0
        powder = d["powder"] as? Int ?? 0
        arms = d["arms"] as? Int ?? 0
        shipI = min(SHIPS.count - 1, max(0, d["shipI"] as? Int ?? 1))
        ups = d["ups"] as? [String: Int] ?? [:]
        hull = d["hull"] as? Double ?? Double(ship.hull)
        day = d["day"] as? Int ?? 1
        leg = min(4, max(0, d["leg"] as? Int ?? 0))
        if let p = d["path"] as? [Int], p.count == path.count { path = p }
        route = d["route"] as? Int ?? 1
        half = d["half"] as? Bool ?? false
        hasMap = d["hasMap"] as? Bool ?? false
        men = []
        for m in d["men"] as? [[String: Any]] ?? [] {
            let man = Man(n: m["n"] as? String ?? "Sailor", sk: m["sk"] as? String ?? ROLES[0].k)
            man.sk2 = m["sk2"] as? String ?? ""
            man.post = m["post"] as? String ?? ""
            man.st = m["st"] as? Int ?? 0
            man.d = m["d"] as? Int ?? 0
            men.append(man)
        }
        if men.isEmpty { return false }
        crew = men.count
        dead = d["dead"] as? [String] ?? []
        log = d["log"] as? [String] ?? []
        perkRip = d["perkRip"] as? Bool ?? false
        perkWind = d["perkWind"] as? Bool ?? false
        perkFury = d["perkFury"] as? Bool ?? false
        cargoPay = d["cargoPay"] as? Int ?? 0
        cargoHold = d["cargoHold"] as? Int ?? 0
        fareDue = d["fareDue"] as? Int ?? 0
        fareBy = d["fareBy"] as? Int ?? 0
        bounty = d["bounty"] as? Bool ?? false
        weather = d["weather"] as? Int ?? 0
        wellUsed = d["wellUsed"] as? Bool ?? false
        portJobs = d["portJobs"] as? [Int] ?? []
        jobsDone = Set(d["jobsDone"] as? [Int] ?? [])
        blk = d["blk"] as? Bool ?? false
        fights = d["fights"] as? Int ?? 0
        tod = d["tod"] as? Double ?? 0.3
        rot = d["rot"] as? Double ?? 0
        saluteN = 0
        mode = .port
        return true
    }
}
