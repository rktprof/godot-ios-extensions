import SwiftGodot

@Godot
class IAPProduct:RefCounted
{
	static let TYPE_UNKNOWN:Int = -1
	static let TYPE_CONSUMABLE:Int = 0
	static let TYPE_NON_CONSUMABLE:Int = 1
	static let TYPE_AUTO_RENEWABLE:Int = 2
	static let TYPE_NON_RENEWABLE:Int = 3

	@Export var productID:String = ""
	@Export var displayName:String = ""
	@Export var storeDescription:String = ""
	@Export var displayPrice:String = ""
	@Export var type:Int = TYPE_UNKNOWN
}