local Maid = {}

export type Maid = {
	add: <T>(item: T) -> T,
	destroy: () -> (),
	isEmpty: () -> boolean,
}

function Maid.new(): Maid
	local items: { any } = {}
	local destroyed = false

	local function add<T>(item: T): T
		if destroyed then

			Maid.release(item)
			return item
		end
		table.insert(items, item)
		return item
	end

	local function destroy()
		destroyed = true
		for index = #items, 1, -1 do
			Maid.release(items[index])
			items[index] = nil
		end
	end

	local function isEmpty(): boolean
		return #items == 0
	end

	return { add = add, destroy = destroy, isEmpty = isEmpty }
end

function Maid.release(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		pcall(function()
			item:Disconnect()
		end)
	elseif kind == "Instance" then
		pcall(function()
			item:Destroy()
		end)
	elseif kind == "function" then
		pcall(item)
	elseif kind == "table" and typeof(item.destroy) == "function" then
		pcall(item.destroy)
	end
end

return Maid
