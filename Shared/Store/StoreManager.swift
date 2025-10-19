import Foundation
import Combine
#if os(iOS) || targetEnvironment(macCatalyst)
import StoreKit
#endif

private enum StoreConstants {
    static let premiumProductID = "com.exrector.clockw3.premium"
}

#if os(iOS) || targetEnvironment(macCatalyst)
@available(iOS 15.0, macCatalyst 15.0, *)
@MainActor
final class StoreManager: ObservableObject {
    enum PurchaseResult {
        case success
        case pending
        case cancelled
    }

    enum StoreError: LocalizedError {
        case productUnavailable
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .productUnavailable:
                return "Product is temporarily unavailable. Please try again later."
            case .failedVerification:
                return "The App Store could not verify this purchase."
            }
        }
    }

    @Published private(set) var priceText: String?
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var isPremiumUnlocked: Bool = false
    @Published private(set) var hasPurchaseUnlock: Bool = false

    private var premiumProduct: Product?
    private var purchaseUnlocked: Bool

    init() {
        purchaseUnlocked = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.premiumPurchaseKey)

        if !purchaseUnlocked && SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.premiumUnlockedKey) {
            purchaseUnlocked = true
            SharedUserDefaults.shared.set(true, forKey: SharedUserDefaults.premiumPurchaseKey)
        }

        isPremiumUnlocked = purchaseUnlocked
        hasPurchaseUnlock = purchaseUnlocked

        Task {
            await loadProductsIfNeeded()
            await refreshEntitlementStatus()
            await listenForTransactions()
        }
    }

    // MARK: - Public API

    func loadProductsIfNeeded() async {
        guard premiumProduct == nil else { return }

        do {
            let products = try await Product.products(for: [StoreConstants.premiumProductID])
            if let product = products.first {
                premiumProduct = product
                priceText = product.displayPrice
            }
        } catch {
            // Проглатываем ошибку — повторим позже
        }
    }

    func purchasePremium() async throws -> PurchaseResult {
        let product: Product
        do {
            product = try await ensurePremiumProduct()
        } catch StoreError.productUnavailable {
#if DEBUG
            // В отладке разрешаем локальную имитацию покупки для быстрого теста UI
            setPurchaseUnlocked(true)
            return .success
#else
            throw StoreError.productUnavailable
#endif
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verify(verification)
            await transaction.finish()
            setPurchaseUnlocked(true)
            return .success
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restorePurchases() async throws {
        if let latest = await Transaction.latest(for: StoreConstants.premiumProductID) {
            do {
                let transaction = try verify(latest)
                setPurchaseUnlocked(transaction.revocationDate == nil)
            } catch {
                throw error
            }
        } else {
            setPurchaseUnlocked(false)
        }
    }

    // MARK: - Private helpers

    private func ensurePremiumProduct() async throws -> Product {
        if let product = premiumProduct {
            return product
        }

        let products = try await Product.products(for: [StoreConstants.premiumProductID])
        guard let product = products.first else {
            throw StoreError.productUnavailable
        }
        premiumProduct = product
        priceText = product.displayPrice
        return product
    }

    private func refreshEntitlementStatus() async {
        if let latest = await Transaction.latest(for: StoreConstants.premiumProductID) {
            do {
                let transaction = try verify(latest)
                setPurchaseUnlocked(transaction.revocationDate == nil)
            } catch {
                // игнорируем в отладке
            }
        } else {
            setPurchaseUnlocked(false)
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            do {
                let transaction = try verify(update)

                if transaction.productID == StoreConstants.premiumProductID {
                    setPurchaseUnlocked(transaction.revocationDate == nil)
                }

                await transaction.finish()
            } catch {
                // Игнорируем ошибки в подписке на апдейты
            }
        }
    }

    private func setPurchaseUnlocked(_ value: Bool) {
        guard purchaseUnlocked != value else { return }

        purchaseUnlocked = value
        isPremiumUnlocked = value
        hasPurchaseUnlock = value

        SharedUserDefaults.shared.set(value, forKey: SharedUserDefaults.premiumPurchaseKey)
        SharedUserDefaults.shared.set(value, forKey: SharedUserDefaults.premiumUnlockedKey)
        SharedUserDefaults.shared.synchronize()
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}
#else
@MainActor
final class StoreManager: ObservableObject {
    enum PurchaseResult {
        case success
        case pending
        case cancelled
    }

    @Published private(set) var priceText: String?
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var isPremiumUnlocked: Bool = false
    @Published private(set) var hasPurchaseUnlock: Bool = false

    private var purchaseUnlocked: Bool

    init() {
        purchaseUnlocked = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.premiumPurchaseKey)

        if !purchaseUnlocked && SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.premiumUnlockedKey) {
            purchaseUnlocked = true
            SharedUserDefaults.shared.set(true, forKey: SharedUserDefaults.premiumPurchaseKey)
        }

        isPremiumUnlocked = purchaseUnlocked
        hasPurchaseUnlock = purchaseUnlocked
    }

    func loadProductsIfNeeded() async { }

    func purchasePremium() async throws -> PurchaseResult { .cancelled }

    func restorePurchases() async throws { }
}
#endif
