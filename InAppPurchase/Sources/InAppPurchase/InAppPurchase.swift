// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot
import StoreKit

#initSwiftExtension(cdecl: "in_app_purchase_init", types: [
	InAppPurchase.self,
	IAPProduct.self
])


public enum StoreError: Error {
    case failedVerification
}

@Godot
class InAppPurchase:RefCounted
{
	#signal("product_purchased", arguments: ["product_id": String.self])
	#signal("product_revoked", arguments: ["product_id": String.self])
	
	let OK:Int = 0
	let ERROR:Int = 1
	let FAILED_TO_GET_PRODUCTS:Int = 2
	let PURCHASE_FAILED:Int = 3
	let PURCHASE_SUCCESSFUL_BUT_UNVERIFIED:Int = 4
	let PURCHASE_PENDING_AUTHORIZATION:Int = 5
	let PURCHASE_CANCELLED_BY_USER:Int = 6

	private(set) var productIdentifiers:[String] = []

	private(set) var products:[Product]
	private(set) var purchasedProducts:[Product] = []
	
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
			var params:GArray = GArray()
			do
			{
				if let product: Product = try await getProduct(productIdentifier)
				{
					let result: Product.PurchaseResult = try await product.purchase()
					switch result
					{
						case let .success(.verified(transaction)):
							// Success
							let transaction: Transaction = try checkVerified(verification)
							await transaction.finish()

							params.append(value: Variant(OK))
							onComplete.callv(arguments: params)
							break
						case let .success(.unverified(_, error)):
							// Purchase successful but transaction can't be verified
							// Could be hacked phone?
							let transaction: Transaction = try checkVerified(verification)
							await transaction.finish()

							params.append(value: Variant(PURCHASE_SUCCESSFUL_BUT_UNVERIFIED))
							onComplete.callv(arguments: params)
							break
						case .pending:
							// Transaction waiting on authentication or approval
							params.append(value: Variant(PURCHASE_PENDING_AUTHORIZATION))
							onComplete.callv(arguments: params)
							break
						case .userCancelled:
							// User cancelled the purchase
							params.append(value: Variant(PURCHASE_CANCELLED_BY_USER))
							onComplete.callv(arguments: params)
							break;
					}
				}
			}
			catch
			{
				GD.pushError("Failed to get products from App Store, error: \(error)")
				params.append(value: Variant(PURCHASE_FAILED))
				onComplete.callv(arguments: params)
			}
		}
	}

	@Callable
	func isPurchased(_ productIdentifier:String) -> Bool
	{
		for product in purchasedProducts
		{
			if (product.id == productIdentifier)
			{
				return true
			}
		}

		return false
	}

	@Callable
	func getProducts(identifiers:[String], onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				let storeProducts: [Product] = try await Product.products(for: identifiers)
				var products:GArray = GArray()

				for storeProduct: Product in storeProducts
				{
					GD.print("Found product: \(storeProduct)")
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
					
					params.append(value:Variant(OK))
					params.append(value:Variant(products))
					onComplete.callv(arguments: params)
				}
			}
			catch
			{
				GD.pushError("Failed to get products from App Store, error: \(error)")
				params.append(value: Variant(FAILED_TO_GET_PRODUCTS))
				onComplete.callv(arguments: params)
			}
		}
	}

	@Callable
	func getPurchasedProducts(onComplete:Callable)
	{
		var products:GArray = GArray()
		for purchasedProduct: Product in purchasedProducts
		{
			var product:IAPProduct = IAPProduct()
			product.displayName = purchasedProduct.displayName
			product.displayPrice = purchasedProduct.displayPrice
			product.storeDescription = purchasedProduct.description
			product.productID = purchasedProduct.id
			switch (purchasedProduct.type)
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
		}

		var params:GArray = GArray()
		params.append(value:Variant(products))
		onComplete.callv(arguments: params)
	}

	@Callable
	func restorePurchases(onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				try await AppStore.sync()
				params.append(value:Variant(OK))
				onComplete.callv(arguments: params)
			}
			catch
			{
				GD.pushError("Failed to restore purchases: \(error)")
				params.append(value:Variant(ERROR))
				onComplete.callv(arguments: params)
			}
		}
	}

	// Internal functionality

	func isPurchased(_ product:Product) async throws -> Bool
	{
		return purchasedProducts.contains(product)
	}

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
				emit(signal: InAppPurchase.productPurchased, product.id)
			}
			else
			{
				self.purchasedProducts.remove(transaction.productID)
				emit(signal: InAppPurchase.productRevoked, product.id)
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