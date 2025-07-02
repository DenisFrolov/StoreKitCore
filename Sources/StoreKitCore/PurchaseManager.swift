import Foundation
import StoreKit

// MARK: - Public Errors

public enum PurchaseError: Error, LocalizedError {
    case noProductIDsFound
    case productNotFound
    case pending
    case paymentWasCancelled
    case purchaseNotAllowed
    case unknownError
    case verificationFailed
    case configurationMissing

    public var errorDescription: String? {
        switch self {
        case .noProductIDsFound:
            return "Product IDs not found"
        case .productNotFound:
            return "Product not found"
        case .pending:
            return "Purchase is pending"
        case .paymentWasCancelled:
            return "Payment was cancelled"
        case .purchaseNotAllowed:
            return "Purchase not allowed"
        case .unknownError:
            return "Unknown error occurred"
        case .verificationFailed:
            return "Transaction verification failed"
        case .configurationMissing:
            return "StoreKit configuration is missing"
        }
    }
}

// MARK: - Purchase State

public enum PurchaseState {
    case notStarted
    case inProgress
    case completed
    case failed(Error)
    case cancelled
}

// MARK: - Purchase Manager

@MainActor
public final class PurchaseManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs = Set<String>()
    @Published public private(set) var isLoading = false
    @Published public private(set) var purchaseState: PurchaseState = .notStarted

    // MARK: - Properties

    public static let shared = PurchaseManager()

    private var configuration: StoreKitConfiguration?
    private var productsLoaded = false
    private var transactionListener: Task<Void, Never>?

    // MARK: - Computed Properties

    public var hasValidSubscription: Bool {
        return !purchasedProductIDs.isEmpty
    }

    public var availableProducts: [Product] {
        return products.filter { !purchasedProductIDs.contains($0.id) }
    }

    public var purchasedProducts: [Product] {
        return products.filter { purchasedProductIDs.contains($0.id) }
    }

    // MARK: - Init

    private init() {
        startTransactionListener()

        Task {
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Configuration

    public func configure(with configuration: StoreKitConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    public func loadProducts() async throws {
        guard let configuration = configuration else {
            throw PurchaseError.configurationMissing
        }

        guard !productsLoaded else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            self.products = try await Product.products(for: configuration.productIdentifiers)
            self.productsLoaded = true
        } catch {
            throw error
        }
    }

    public func purchase(_ product: Product) async throws {
        guard AppStore.canMakePayments else {
            throw PurchaseError.purchaseNotAllowed
        }

        purchaseState = .inProgress

        do {
            let result = try await product.purchase()

            switch result {
            case let .success(.verified(transaction)):
                await transaction.finish()
                await updatePurchasedProducts()
                purchaseState = .completed

            case let .success(.unverified(_, error)):
                purchaseState = .failed(error)
                throw error

            case .pending:
                purchaseState = .failed(PurchaseError.pending)
                throw PurchaseError.pending

            case .userCancelled:
                purchaseState = .cancelled
                throw PurchaseError.paymentWasCancelled

            @unknown default:
                purchaseState = .failed(PurchaseError.unknownError)
                throw PurchaseError.unknownError
            }
        } catch {
            purchaseState = .failed(error)
            throw error
        }
    }

    public func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            throw error
        }
    }

    public func updatePurchasedProducts() async {
        var newPurchasedProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.revocationDate == nil {
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        newPurchasedProductIDs.insert(transaction.productID)
                    }
                } else {
                    newPurchasedProductIDs.insert(transaction.productID)
                }
            }
        }

        purchasedProductIDs = newPurchasedProductIDs
    }

    public func isPurchased(_ productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }

    public func getProduct(by id: String) -> Product? {
        return products.first { $0.id == id }
    }

    public func resetPurchaseState() {
        purchaseState = .notStarted
    }

    // MARK: - Private Methods

    private func startTransactionListener() {
        transactionListener = Task { [weak self] in
            for await verificationResult in Transaction.updates {
                await self?.handleTransaction(verificationResult)
            }
        }
    }

    private func handleTransaction(_ verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else {
            return
        }

        await updatePurchasedProducts()
        await transaction.finish()
    }
}
