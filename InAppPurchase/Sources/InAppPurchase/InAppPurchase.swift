// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot
import StoreKit

#initSwiftExtension(cdecl: "swift_entry_point", types: [
	InAppPurchase.self,
	IAPProduct.self
])


public enum StoreError: Error {
    case failedVerification
}

let OK:Int = 0
let ERROR:Int = 1
let FAILED_TO_GET_PRODUCTS:Int = 2
let PURCHASE_FAILED:Int = 3
let PURCHASE_SUCCESSFUL_BUT_UNVERIFIED:Int = 4
let PURCHASE_PENDING_AUTHORIZATION:Int = 5
let PURCHASE_CANCELLED_BY_USER:Int = 6
let NO_SUCH_PRODUCT:Int = 7

@Godot
class InAppPurchase:RefCounted
{
	#signal("product_purchased", arguments: ["product_id": String.self])
	#signal("product_revoked", arguments: ["product_id": String.self])

	private(set) var productIdentifiers:[String] = []

	private(set) var products:[Product]
	private(set) var purchasedProducts: Set<String> = Set<String>()
	
	var updateListenerTask: Task<Void, Error>? = nil

	required init()
	{
		products = []
		super.init()
	}
	
	required init(nativeHandle: UnsafeRawPointer) {
		products = []
		super.init(nativeHandle: nativeHandle)
	}

	deinit
	{
		updateListenerTask?.cancel()
	}

	@Callable
	func initialize(_ productIdentifiers:[String])
	{
		self.productIdentifiers = productIdentifiers

		updateListenerTask = self.listenForTransactions()
		
		Task
		{
			await updateProducts()
			await updateProductStatus()
		}
	}

	@Callable
	func purchase(_ productIdentifier:String, onComplete:Callable)
	{
		Task
		{
			do
			{
				if let product: Product = try await getProduct(productIdentifier)
				{
					let result: Product.PurchaseResult = try await product.purchase()
					switch result
					{
						case .success(let verification):
							// Success
							let transaction: Transaction = try checkVerified(verification)
							await transaction.finish()

							onComplete.callDeferred(Variant(OK))
							break
						case .pending:
							// Transaction waiting on authentication or approval
							onComplete.callDeferred(Variant(PURCHASE_PENDING_AUTHORIZATION))
							break
						case .userCancelled:
							// User cancelled the purchase
							onComplete.callDeferred(Variant(PURCHASE_CANCELLED_BY_USER))
							break;
					}
				} else {
					GD.pushError("IAP Product doesn't exist: \(productIdentifier)")
					onComplete.callDeferred(Variant(NO_SUCH_PRODUCT))
				}
			}
			catch
			{
				GD.pushError("IAP Failed to get products from App Store, error: \(error)")
				onComplete.callDeferred(Variant(PURCHASE_FAILED))
			}
		}
	}

	@Callable
	func isPurchased(_ productID:String) -> Bool
	{
		return purchasedProducts.contains(productID)
	}

	@Callable
	func getProducts(identifiers:[String], onComplete:Callable)
	{
		Task
		{
			do
			{
				let storeProducts: [Product] = try await Product.products(for: identifiers)
				var products:GArray = GArray()

				for storeProduct: Product in storeProducts
				{
					var product:IAPProduct = IAPProduct()
					product.displayName = storeProduct.displayName
					product.displayPrice = storeProduct.displayPrice
					product.storeDescription = storeProduct.description
					product.productID = storeProduct.id
					switch (storeProduct.type)
					{
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
					
					onComplete.callDeferred(Variant(OK), Variant(products))
				}
			}
			catch
			{
				GD.pushError("Failed to get products from App Store, error: \(error)")
				onComplete.callDeferred(Variant(FAILED_TO_GET_PRODUCTS), Variant())
			}
		}
	}

	@Callable
	func restorePurchases(onComplete:Callable)
	{
		Task
		{
			do
			{
				try await AppStore.sync()
				onComplete.callDeferred(Variant(OK))
			}
			catch
			{
				GD.pushError("Failed to restore purchases: \(error)")
				onComplete.callDeferred(Variant(ERROR))
			}
		}
	}

	// Internal functionality

	func getProduct(_ productIdentifier:String) async throws -> Product?
	{
		var product:[Product] = []
		do
		{
			product = try await Product.products(for: ["identifier"])
		}
		catch
		{
			GD.pushError("Unable to get product with identifier: \(productIdentifier): \(error)")
		}

		return product.first
	}

	func updateProducts() async
	{
		do
		{
			let storeProducts = try await Product.products(for: productIdentifiers)
			products = storeProducts
		}
		catch
		{
			GD.pushError("Failed to get products from App Store: \(error)")
		}
	}

	func updateProductStatus() async
	{
		for await result: VerificationResult<Transaction> in Transaction.currentEntitlements
		{
			guard case .verified(let transaction) = result else
			{
				continue
			}

			if transaction.revocationDate == nil
			{
				self.purchasedProducts.insert(transaction.productID)
				emit(signal: InAppPurchase.productPurchased, transaction.productID)
			}
			else
			{
				self.purchasedProducts.remove(transaction.productID)
				emit(signal: InAppPurchase.productRevoked, transaction.productID)
			}
		}
	}

	func checkVerified<T>(_ result:VerificationResult<T>) throws -> T
	{
		switch result
		{
			case .unverified:
				throw StoreError.failedVerification
			case .verified(let safe):
				return safe
		}
	}

	func listenForTransactions() -> Task<Void, Error>
	{
		return Task.detached
		{
			for await result: VerificationResult<Transaction> in Transaction.updates
			{
				do
				{
					let transaction: Transaction = try self.checkVerified(result)

					await self.updateProductStatus()
					await transaction.finish()
				}
				catch
				{
					GD.pushWarning("Transaction failed verification")
				}
			}
		}
	}
}