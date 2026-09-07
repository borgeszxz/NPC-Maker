local MarketplaceItemAdapter = require(script.Parent.MarketplaceItemAdapter)
local AvatarService = require(script.Parent.AvatarService)

type AdaptedItem = MarketplaceItemAdapter.AdaptedItem

local DescriptionBuilder = {}

export type Source = {
	kind: string,
	label: string,
	userId: number?,
}

local base: HumanoidDescription = Instance.new("HumanoidDescription")
local items: { AdaptedItem } = {}
local source: Source = { kind = "Default", label = "Default rig", userId = nil }
local listeners: { () -> () } = {}

local function notify()
	for _, listener in listeners do
		local ok, err = pcall(listener)
		if not ok then
			warn("[NPC Maker] state listener failed: " .. tostring(err))
		end
	end
end

function DescriptionBuilder.onChanged(callback: () -> ()): () -> ()
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function DescriptionBuilder.getSource(): Source
	return source
end

function DescriptionBuilder.getItems(): { AdaptedItem }
	return items
end

function DescriptionBuilder.setBase(description: HumanoidDescription, newSource: Source)
	base:Destroy()
	base = description:Clone()
	source = newSource
	notify()
end

function DescriptionBuilder.resetToDefault()
	base:Destroy()
	base = AvatarService.blankDescription()
	source = { kind = "Default", label = "Default rig", userId = nil }
	items = {}
	notify()
end

function DescriptionBuilder.slotOccupant(assetTypeName: string): AdaptedItem?
	for _, item in items do
		if item.assetTypeName == assetTypeName then
			return item
		end
	end
	return nil
end

function DescriptionBuilder.addItem(item: AdaptedItem): AdaptedItem?
	local replaced: AdaptedItem? = nil
	for index = #items, 1, -1 do
		if items[index].assetTypeName == item.assetTypeName then
			replaced = items[index]
			table.remove(items, index)
		end
	end
	table.insert(items, item)
	notify()
	return replaced
end

function DescriptionBuilder.removeItem(index: number)
	if items[index] then
		table.remove(items, index)
		notify()
	end
end

function DescriptionBuilder.clearItems()
	if #items == 0 then
		return
	end
	items = {}
	notify()
end

function DescriptionBuilder.applyBundle(item: AdaptedItem): (boolean, string?)
	local description, err = MarketplaceItemAdapter.resolveBundleDescription(item.id)
	if description == nil then
		return false, err
	end

	base:Destroy()
	base = description
	source = { kind = "Bundle", label = item.name, userId = nil }

	for index = #items, 1, -1 do
		if items[index].kind == "bodypart" then
			table.remove(items, index)
		end
	end

	notify()
	return true, nil
end

function DescriptionBuilder.build(): HumanoidDescription
	local result = base:Clone()

	local accessories: { any } = {}
	local okGet, existing = pcall(function()
		return result:GetAccessories(true)
	end)
	if okGet and typeof(existing) == "table" then
		accessories = existing
	end

	local overridden: { [any]: boolean } = {}
	for _, item in items do
		if item.kind == "accessory" and item.accessoryType ~= nil then
			overridden[item.accessoryType] = true
		end
	end

	local kept: { any } = {}
	local maxOrder = 0
	for _, entry in accessories do
		if not overridden[entry.AccessoryType] then
			table.insert(kept, entry)
			if typeof(entry.Order) == "number" and entry.Order > maxOrder then
				maxOrder = entry.Order
			end
		end
	end

	for _, item in items do
		if item.kind == "clothing" or item.kind == "bodypart" then
			if item.property ~= nil then
				pcall(function()
					(result :: any)[item.property] = item.id
				end)
			end
		elseif item.kind == "accessory" and item.accessoryType ~= nil then
			local entry: any = {
				AssetId = item.id,
				AccessoryType = item.accessoryType,
				IsLayered = item.isLayered,
			}
			if item.isLayered then
				maxOrder += 1
				entry.Order = maxOrder
			end
			table.insert(kept, entry)
		end
	end

	local okSet = pcall(function()
		result:SetAccessories(kept, true)
	end)
	if not okSet then
		warn("[NPC Maker] could not apply accessories; character will use the base look.")
	end

	return result
end

function DescriptionBuilder.removeAllAccessories()
	local next = base:Clone()
	pcall(function()
		next:SetAccessories({}, true)
	end)
	base:Destroy()
	base = next

	for index = #items, 1, -1 do
		if items[index].kind == "accessory" then
			table.remove(items, index)
		end
	end
	notify()
end

function DescriptionBuilder.removeClothing()
	local next = base:Clone()
	pcall(function()
		next.Shirt = 0
		next.Pants = 0
		next.GraphicTShirt = 0
	end)
	base:Destroy()
	base = next

	for index = #items, 1, -1 do
		if items[index].kind == "clothing" then
			table.remove(items, index)
		end
	end
	notify()
end

return DescriptionBuilder
