//
//  StoreManager.swift
//  PointiOS
//
//  StoreKit 2 integration for Point Pro subscriptions
//

import Foundation
import StoreKit

// MARK: - Product IDs
enum PointProducts {
    static let monthly = "pointpro_monthly"
    static let annual = "pointpro_annual"
    static let allProducts = [monthly, annual]
}

// MARK: - Store Manager
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - Computed Properties
    var isPro: Bool {
        !purchasedProductIDs.isEmpty
    }

    var monthlyProduct: Product? {
        products.first { $0.id == PointProducts.monthly }
    }

    var annualProduct: Product? {
        products.first { $0.id == PointProducts.annual }
    }

    var monthlyPrice: String {
        monthlyProduct?.displayPrice ?? "$2.99"
    }

    var annualPrice: String {
        annualProduct?.displayPrice ?? "$19.99"
    }

    var annualPricePerMonth: String {
        guard let annual = annualProduct else { return "$1.67" }
        let pricePerMonth = annual.price / 12
        return pricePerMonth.formatted(.currency(code: annual.priceFormatStyle.currencyCode))
    }

    var savingsPercent: Int {
        guard let monthly = monthlyProduct, let annual = annualProduct else { return 44 }
        let monthlyAnnualized = monthly.price * 12
        let savings = ((monthlyAnnualized - annual.price) / monthlyAnnualized) * 100
        return NSDecimalNumber(decimal: savings).intValue
    }

    // MARK: - Private
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Initialization
    private init() {
        // Start listening for transactions
        updateListenerTask = listenForTransactions()

        // Load products and check entitlements
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            products = try await Product.products(for: PointProducts.allProducts)
            products.sort { $0.price < $1.price }
            print("✅ StoreKit: Loaded \(products.count) products")
            for product in products {
                print("   - \(product.id): \(product.displayPrice)")
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ StoreKit: Failed to load products - \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                isLoading = false
                print("✅ StoreKit: Purchase successful - \(product.id)")
                return true

            case .userCancelled:
                isLoading = false
                print("ℹ️ StoreKit: User cancelled purchase")
                return false

            case .pending:
                isLoading = false
                errorMessage = "Purchase is pending approval"
                print("ℹ️ StoreKit: Purchase pending")
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            isLoading = false
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ StoreKit: Purchase failed - \(error)")
            return false
        }
    }

    func purchaseMonthly() async -> Bool {
        guard let product = monthlyProduct else {
            errorMessage = "Monthly subscription not available"
            return false
        }
        return await purchase(product)
    }

    func purchaseAnnual() async -> Bool {
        guard let product = annualProduct else {
            errorMessage = "Annual subscription not available"
            return false
        }
        return await purchase(product)
    }

    // MARK: - Restore Purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            isLoading = false

            let success = isPro
            print(success ? "✅ StoreKit: Restore successful" : "ℹ️ StoreKit: No purchases to restore")
            return success
        } catch {
            isLoading = false
            errorMessage = "Restore failed: \(error.localizedDescription)"
            print("❌ StoreKit: Restore failed - \(error)")
            return false
        }
    }

    // MARK: - Update Purchased Products
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        purchasedProductIDs = purchasedIDs

        // Sync with ProEntitlements
        ProEntitlements.shared.setPro(isPro)
        print("🔐 StoreKit: Pro status = \(isPro)")
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Verification
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    // MARK: - Manage Subscriptions
    func showManageSubscriptions() async {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
            } catch {
                print("Failed to show manage subscriptions: \(error)")
            }
        }
    }
}

// MARK: - Store Error
enum StoreError: LocalizedError {
    case failedVerification
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        }
    }
}
