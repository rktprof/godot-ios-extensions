import StoreKit
import SwiftGodot

#initSwiftExtension(
	cdecl: "swift_entry_point",
	types: [
		InAppPurchase.self,
		IAPProduct.self,
	]
)

public enum StoreError: Error {
	case failedVerification
}

let OK: Int = 0

@Godot
class InAppPurchase: RefCounted {
	enum InAppPurchaseStatus: Int {
		case purchaseOK = 0
		case purchaseSuccessfulButUnverified = 2
		case purchasePendingAuthorization = 3
		case purchaseCancelledByUser = 4
	}
	enum InAppPurchaseError: Int, Error {
		case failedToGetProducts = 1
		case purchaseFailed = 2
		case noSuchProduct = 3
		case failedToRestorePurchases = 4
	}
	enum AppTransactionError: Int, Error {
		case ok = 0
		case unverified = 1
		case error = 2
	}

	/// Called when a product is puchased
	#signal("product_purchased", arguments: ["product_id": String.self])
	/// Called when a purchase is revoked
	#signal("product_revoked", arguments: ["product_id": String.self])

	private(set) var productIDs: [String] = []

	private(set) var products: [Product]
	private(set) var purchasedProducts: Set<String> = Set<String>()

	var updateListenerTask: Task<Void, Error>? = nil

	required init() {
		products = []
		super.init()
	}

	required init(nativeHandle: UnsafeRawPointer) {
		products = []
		super.init(nativeHandle: nativeHandle)
	}

	deinit {
		updateListenerTask?.cancel()
	}

	/// Initialize purchases
	///
	/// - Parameters:
	/// 	- productIdentifiers: An array of product identifiers that you enter in App Store Connect.
	@Callable
	func initialize(productIDs: [String], onComplete: Callable) {
		self.productIDs = productIDs

		updateListenerTask = self.listenForTransactions()

		Task {
			await updateProducts()
			await updateProductStatus()

			onComplete.callDeferred()
		}
	}

	/// Purchase a product
	///
	/// - Parameters:
	/// 	- productID: The identifier of the product that you enter in App Store Connect.
	/// 	- onComplete: Callback with parameter: (error: Variant, status: Variant) -> (error: Int `InAppPurchaseError`, status: Int `InAppPurchaseStatus`)
	@Callable
	func purchase(_ productID: String, onComplete: Callable) {
		Task {
			do {
				if let product: Product = try await getProduct(productID) {
					let result: Product.PurchaseResult = try await product.purchase()
					switch result {
					case .success(let verification):
						// Success
						let transaction: Transaction = try checkVerified(verification)
						await transaction.finish()

						self.purchasedProducts.insert(transaction.productID)

						onComplete.callDeferred(
							Variant(OK),
							Variant(InAppPurchaseStatus.purchaseOK.rawValue)
						)
						break
					case .pending:
						// Transaction waiting on authentication or approval
						onComplete.callDeferred(
							Variant(OK),
							Variant(InAppPurchaseStatus.purchasePendingAuthorization.rawValue)
						)
						break
					case .userCancelled:
						// User cancelled the purchase
						onComplete.callDeferred(
							Variant(OK),
							Variant(InAppPurchaseStatus.purchaseCancelledByUser.rawValue)
						)
						break
					}
				} else {
					GD.pushError("IAP Product doesn't exist: \(productID)")
					onComplete.callDeferred(
						Variant(InAppPurchaseError.noSuchProduct.rawValue),
						Variant()
					)
				}
			} catch {
				GD.pushError("IAP Failed to get products from App Store, error: \(error)")
				onComplete.callDeferred(
					Variant(InAppPurchaseError.purchaseFailed.rawValue),
					Variant()
				)
			}
		}
	}

	/// Check if a product is purchased
	///
	/// - Parameters:
	/// 	- productID: The identifier of the product that you enter in App Store Connect.,
	///
	/// - Returns: True if a product is purchased
	@Callable
	func isPurchased(_ productID: String) -> Bool {
		return purchasedProducts.contains(productID)
	}

	/// Get products
	///
	/// - Parameters:
	/// 	- identifiers: An array of product identifiers that you enter in App Store Connect.
	/// 	- onComplete: Callback with parameters: (error: Variant, products: Variant) -> (error: Int, products: [``IAPProduct``])
	@Callable
	func getProducts(identifiers: [String], onComplete: Callable) {
		Task {
			do {
				let storeProducts: [Product] = try await Product.products(for: identifiers)
				var products: GArray = GArray()

				for storeProduct: Product in storeProducts {
					var product: IAPProduct = IAPProduct()
					product.displayName = storeProduct.displayName
					product.displayPrice = storeProduct.displayPrice
					product.storeDescription = storeProduct.description
					product.productID = storeProduct.id
					switch storeProduct.type {
					case .consumable:
						product.type = IAPProduct.TYPE_CONSUMABLE
					case .nonConsumable:
						product.type = IAPProduct.TYPE_NON_CONSUMABLE
					case .autoRenewable:
						product.type = IAPProduct.TYPE_AUTO_RENEWABLE
					case .nonRenewable:
						product.type = IAPProduct.TYPE_NON_RENEWABLE
					default:
						product.type = IAPProduct.TYPE_UNKNOWN
					}

					products.append(Variant(product))
				}
				onComplete.callDeferred(Variant(OK), Variant(products))
			} catch {
				GD.pushError("Failed to get products from App Store, error: \(error)")
				onComplete.callDeferred(
					Variant(InAppPurchaseError.failedToGetProducts.rawValue),
					Variant()
				)
			}
		}
	}

	/// Restore purchases
	///
	/// - Parameter onComplete: Callback with parameter: (error: Variant) -> (error: Int)
	@Callable
	func restorePurchases(onComplete: Callable) {
		Task {
			do {
				try await AppStore.sync()
				onComplete.callDeferred(Variant(OK))
			} catch {
				GD.pushError("Failed to restore purchases: \(error)")
				onComplete.callDeferred(
					Variant(InAppPurchaseError.failedToRestorePurchases.rawValue)
				)
			}
		}
	}

	/// Get the current app environment
	///
	/// NOTE: On iOS 16 this might display a system prompt that asks users to authenticate
	///
	/// - Parameter onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: String)
	@Callable
	public func getEnvironment(onComplete: Callable) {
		if #available(iOS 16.0, *) {
			Task {
				do {
					let result = try await AppTransaction.shared
					switch result {
					case .verified(let appTransaction):
						onComplete.callDeferred(
							Variant(AppTransactionError.ok.rawValue),
							Variant(appTransaction.environment.rawValue)
						)
					case .unverified(let appTransaction, let verificationError):
						onComplete.callDeferred(
							Variant(AppTransactionError.unverified.rawValue),
							Variant(appTransaction.environment.rawValue)
						)
					}
				} catch {
					GD.print("Failed to get appTransaction, error: \(error)")
					onComplete.callDeferred(Variant(AppTransactionError.error.rawValue), Variant(""))
				}
			}
		} else {
			guard let path = Bundle.main.appStoreReceiptURL?.path else {
				onComplete.callDeferred(Variant(AppTransactionError.error.rawValue), Variant(""))
				return
			}

			if path.contains("CoreSimulator") {
				onComplete.callDeferred(Variant(AppTransactionError.ok.rawValue), Variant("xcode"))
			} else if path.contains("sandboxReceipt") {
				onComplete.callDeferred(Variant(AppTransactionError.ok.rawValue), Variant("sandbox"))
			} else {
				onComplete.callDeferred(Variant(AppTransactionError.ok.rawValue), Variant("production"))
			}
		}
	}

	/// Refresh the App Store signed app transaction (only iOS 16+)
	///
	/// NOTE: This will display a system prompt that asks users to authenticate
	@Callable
	public func refreshAppTransaction(onComplete: Callable) {
		if #available(iOS 16.0, *) {
			Task {
				do {
					try await AppTransaction.refresh()
					onComplete.callDeferred(Variant(AppTransactionError.ok.rawValue))
				} catch {
					onComplete.callDeferred(Variant(AppTransactionError.unverified.rawValue))
				}
			}
		} else {
			onComplete.callDeferred(Variant(OK))
		}
	}

	// Internal functionality

	func getProduct(_ productIdentifier: String) async throws -> Product? {
		var product: [Product] = []
		do {
			product = try await Product.products(for: [productIdentifier])
		} catch {
			GD.pushError("Unable to get product with identifier: \(productIdentifier): \(error)")
		}

		return product.first
	}

	func updateProducts() async {
		do {
			let storeProducts = try await Product.products(for: productIDs)
			products = storeProducts
		} catch {
			GD.pushError("Failed to get products from App Store: \(error)")
		}
	}

	func updateProductStatus() async {
		for await result: VerificationResult<Transaction> in Transaction.currentEntitlements {
			guard case .verified(let transaction) = result else {
				continue
			}

			if transaction.revocationDate == nil {
				self.purchasedProducts.insert(transaction.productID)
				emit(signal: InAppPurchase.productPurchased, transaction.productID)
			} else {
				self.purchasedProducts.remove(transaction.productID)
				emit(signal: InAppPurchase.productRevoked, transaction.productID)
			}
		}
	}

	func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
		switch result {
		case .unverified:
			throw StoreError.failedVerification
		case .verified(let safe):
			return safe
		}
	}

	func listenForTransactions() -> Task<Void, Error> {
		return Task.detached {
			for await result: VerificationResult<Transaction> in Transaction.updates {
				do {
					let transaction: Transaction = try self.checkVerified(result)

					await self.updateProductStatus()
					await transaction.finish()
				} catch {
					GD.pushWarning("Transaction failed verification")
				}
			}
		}
	}
}
