local AvatarEditorService = game:GetService("AvatarEditorService")

local AvatarService = require(script.Parent.AvatarService)

local MarketplaceItemAdapter = {}

export type AdaptedItem = {
	supported: boolean,
	reason: string?,
	kind: string,
	id: number,
	name: string,
	creator: string,
	price: number?,
	offSale: boolean,
	itemType: string,
	assetTypeName: string,
	slot: string,
	accessoryType: Enum.AccessoryType?,
	isLayered: boolean,
	property: string?,
	thumbnail: string,
}

local CLOTHING_PROPERTIES: { [string]: string } = {
	Shirt = "Shirt",
	Pants = "Pants",
	TShirt = "GraphicTShirt",
	Face = "Face",
}

local BODY_PART_PROPERTIES: { [string]: string } = {
	Head = "Head",
	Torso = "Torso",
	LeftArm = "LeftArm",
	RightArm = "RightArm",
	LeftLeg = "LeftLeg",
	RightLeg = "RightLeg",
}

local ACCESSORY_TYPES: { [string]: string } = {
	Hat = "Hat",
	HairAccessory = "Hair",
	FaceAccessory = "Face",
	NeckAccessory = "Neck",
	ShoulderAccessory = "Shoulder",
	FrontAccessory = "Front",
	BackAccessory = "Back",
	WaistAccessory = "Waist",
	TShirtAccessory = "TShirt",
	ShirtAccessory = "Shirt",
	PantsAccessory = "Pants",
	JacketAccessory = "Jacket",
	SweaterAccessory = "Sweater",
	ShortsAccessory = "Shorts",
	LeftShoeAccessory = "LeftShoe",
	RightShoeAccessory = "RightShoe",
	DressSkirtAccessory = "DressSkirt",
	EyebrowAccessory = "Eyebrow",
	EyelashAccessory = "Eyelash",
}

local LAYERED_TYPES: { [string]: boolean } = {
	TShirtAccessory = true,
	ShirtAccessory = true,
	PantsAccessory = true,
	JacketAccessory = true,
	SweaterAccessory = true,
	ShortsAccessory = true,
	LeftShoeAccessory = true,
	RightShoeAccessory = true,
	DressSkirtAccessory = true,
}

local FRIENDLY_SLOTS: { [string]: string } = {
	HairAccessory = "Hair",
	Hat = "Hat",
	FaceAccessory = "Face Accessory",
	NeckAccessory = "Neck",
	ShoulderAccessory = "Shoulder",
	FrontAccessory = "Front",
	BackAccessory = "Back",
	WaistAccessory = "Waist",
	Shirt = "Shirt",
	Pants = "Pants",
	TShirt = "T-Shirt",
	Face = "Face",
}

local function accessoryTypeFromName(name: string): Enum.AccessoryType?
	local ok, value = pcall(function()
		return (Enum.AccessoryType :: any)[name]
	end)
	if ok and typeof(value) == "EnumItem" then
		return value
	end
	return nil
end

local function slotLabel(assetTypeName: string): string
	return FRIENDLY_SLOTS[assetTypeName] or assetTypeName
end

function MarketplaceItemAdapter.thumbnailFor(id: number, itemType: string): string
	local kind = if itemType == "Bundle" then "BundleThumbnail" else "Asset"
	return string.format("rbxthumb://type=%s&id=%d&w=150&h=150", kind, id)
end

local function unsupported(id: number, name: string, assetTypeName: string, reason: string): AdaptedItem
	return {
		supported = false,
		reason = reason,
		kind = "unsupported",
		id = id,
		name = name,
		creator = "",
		price = nil,
		offSale = false,
		itemType = "Asset",
		assetTypeName = assetTypeName,
		slot = slotLabel(assetTypeName),
		accessoryType = nil,
		isLayered = false,
		property = nil,
		thumbnail = MarketplaceItemAdapter.thumbnailFor(id, "Asset"),
	}
end

function MarketplaceItemAdapter.adapt(result: any): AdaptedItem
	local id = tonumber(result.Id) or 0
	local name = tostring(result.Name or "Unnamed")
	local creator = tostring(result.CreatorName or "")
	local itemType = tostring(result.ItemType or "Asset")
	local assetTypeName = tostring(result.AssetType or "")
	local price = tonumber(result.Price) or tonumber(result.LowestPrice)
	local offSale = result.IsOffSale == true or (price == nil)

	if id <= 0 then
		return unsupported(0, name, assetTypeName, "This result has no usable id.")
	end

	local base = {
		supported = true,
		reason = nil :: string?,
		id = id,
		name = name,
		creator = creator,
		price = price,
		offSale = offSale,
		itemType = itemType,
		assetTypeName = assetTypeName,
		thumbnail = MarketplaceItemAdapter.thumbnailFor(id, itemType),
	}

	if itemType == "Bundle" then
		local item: AdaptedItem = {
			supported = true,
			reason = nil,
			kind = "bundle",
			id = base.id,
			name = base.name,
			creator = base.creator,
			price = base.price,
			offSale = base.offSale,
			itemType = "Bundle",
			assetTypeName = tostring(result.BundleType or "Bundle"),
			slot = "Bundle",
			accessoryType = nil,
			isLayered = false,
			property = nil,
			thumbnail = base.thumbnail,
		}
		return item
	end

	local clothingProperty = CLOTHING_PROPERTIES[assetTypeName]
	if clothingProperty then
		return {
			supported = true,
			reason = nil,
			kind = "clothing",
			id = base.id,
			name = base.name,
			creator = base.creator,
			price = base.price,
			offSale = base.offSale,
			itemType = itemType,
			assetTypeName = assetTypeName,
			slot = slotLabel(assetTypeName),
			accessoryType = nil,
			isLayered = false,
			property = clothingProperty,
			thumbnail = base.thumbnail,
		}
	end

	local bodyProperty = BODY_PART_PROPERTIES[assetTypeName]
	if bodyProperty then
		return {
			supported = true,
			reason = nil,
			kind = "bodypart",
			id = base.id,
			name = base.name,
			creator = base.creator,
			price = base.price,
			offSale = base.offSale,
			itemType = itemType,
			assetTypeName = assetTypeName,
			slot = slotLabel(assetTypeName),
			accessoryType = nil,
			isLayered = false,
			property = bodyProperty,
			thumbnail = base.thumbnail,
		}
	end

	local accessoryName = ACCESSORY_TYPES[assetTypeName]
	if accessoryName then
		local accessoryType = accessoryTypeFromName(accessoryName)
		if accessoryType == nil then
			return unsupported(id, name, assetTypeName, "This Studio build does not know that accessory type.")
		end
		return {
			supported = true,
			reason = nil,
			kind = "accessory",
			id = base.id,
			name = base.name,
			creator = base.creator,
			price = base.price,
			offSale = base.offSale,
			itemType = itemType,
			assetTypeName = assetTypeName,
			slot = slotLabel(assetTypeName),
			accessoryType = accessoryType,
			isLayered = LAYERED_TYPES[assetTypeName] == true,
			property = nil,
			thumbnail = base.thumbnail,
		}
	end

	return unsupported(
		id,
		name,
		assetTypeName,
		string.format("NPC Maker cannot apply %s items to a character.", assetTypeName ~= "" and assetTypeName or "these")
	)
end

function MarketplaceItemAdapter.fromId(id: number, hint: string): (AdaptedItem?, string?)
	local order: { string }
	if hint == "Asset" then
		order = { "Asset" }
	elseif hint == "Bundle" then
		order = { "Bundle" }
	else
		order = { "Asset", "Bundle" }
	end

	local lastError: any = nil
	for _, kind in order do
		local enumOk, itemTypeEnum = pcall(function()
			return (Enum.AvatarItemType :: any)[kind]
		end)
		if not enumOk then
			continue
		end

		local ok, details = pcall(function()
			return AvatarEditorService:GetItemDetails(id, itemTypeEnum)
		end)
		if ok and typeof(details) == "table" then
			details.ItemType = details.ItemType or kind
			return MarketplaceItemAdapter.adapt(details), nil
		end
		lastError = details
	end

	if lastError ~= nil and string.find(tostring(lastError), "HTTP") then
		return nil, "Roblox did not respond. Try again."
	end
	return nil, "No catalog item found with that id."
end

function MarketplaceItemAdapter.resolveBundleDescription(bundleId: number): (HumanoidDescription?, string?)
	local ok, details = pcall(function()
		return AvatarEditorService:GetItemDetails(bundleId, Enum.AvatarItemType.Bundle)
	end)
	if not ok or typeof(details) ~= "table" then
		return nil, "Could not read that bundle."
	end

	local bundled = details.BundledItems
	if typeof(bundled) ~= "table" then
		return nil, "That bundle exposes no items."
	end

	for _, entry in bundled do
		if entry.Type == "UserOutfit" then
			local outfitId = tonumber(entry.Id)
			if outfitId then
				return AvatarService.getDescriptionFromOutfit(outfitId)
			end
		end
	end

	return nil, "That bundle has no outfit, so its look cannot be applied."
end

MarketplaceItemAdapter.LAYERED_TYPES = LAYERED_TYPES
MarketplaceItemAdapter.ACCESSORY_TYPES = ACCESSORY_TYPES

return MarketplaceItemAdapter
