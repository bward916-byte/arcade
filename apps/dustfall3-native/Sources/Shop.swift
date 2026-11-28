import Foundation
import StoreKit

/// The one thing for sale: the rest of the line past Dustfall. Bought once, kept for good.
@MainActor
final class Shop {
    static let id = "com.brianward.dustfall3.fullgame"
    private static let key = "dustfall3.full"
    var product: Product?
    var onChange: (() -> Void)?
    var owned: Bool { return UserDefaults.standard.bool(forKey: Shop.key) }

    func start() {
        Task { [weak self] in
            for await r in StoreKit.Transaction.updates {
                if case .verified(let tx) = r, tx.productID == Shop.id {
                    self?.grant(tx.revocationDate == nil)
                    await tx.finish()
                }
            }
        }
        Task { [weak self] in await self?.refresh() }
    }

    func grant(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Shop.key)
        onChange?()
    }

    /// Looks the product up, and checks whether this Apple ID already owns it.
    func refresh() async {
        if let list = try? await Product.products(for: [Shop.id]), let p = list.first { product = p; onChange?() }
        for await r in StoreKit.Transaction.currentEntitlements {
            if case .verified(let tx) = r, tx.productID == Shop.id, tx.revocationDate == nil { grant(true) }
        }
    }

    private var busy = false
    func buy() async -> Bool {
        // one purchase at a time: a second tap while the store's sheet is on its way must not queue another
        if busy { return false }
        busy = true
        defer { busy = false }
        // already owned on this Apple ID: hand it over without asking the store to sell it again
        for await r in StoreKit.Transaction.currentEntitlements {
            if case .verified(let tx) = r, tx.productID == Shop.id, tx.revocationDate == nil { grant(true); return true }
        }
        guard let p = product, let res = try? await p.purchase() else { return false }
        if case .success(let v) = res, case .verified(let tx) = v {
            await tx.finish()
            grant(true)
            return true
        }
        return false
    }

    func restore() async -> Bool {
        try? await AppStore.sync()
        await refresh()
        return owned
    }
}
