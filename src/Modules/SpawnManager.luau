local Selection = game:GetService("Selection")

local SpawnManager = {}

export type Mode = "Cursor" | "Origin" | "Selected"

SpawnManager.MODES = {
	{ id = "Cursor", label = "At Cursor" },
	{ id = "Origin", label = "At Origin" },
	{ id = "Selected", label = "At Selected" },
}

local function originCFrame(): CFrame
	return CFrame.new(0, 0, 0)
end

local function aboveSelection(): (CFrame?, string?)
	local selected = Selection:Get()
	if #selected == 0 then
		return nil, "Nothing is selected, so the NPC went to the origin."
	end

	for _, instance in selected do
		if instance:IsA("BasePart") then
			local top = instance.Position.Y + instance.Size.Y / 2
			return CFrame.new(instance.Position.X, top, instance.Position.Z), nil
		end
		if instance:IsA("Model") then
			local ok, boundsCFrame, boundsSize = pcall(function()
				return instance:GetBoundingBox()
			end)
			if ok and boundsCFrame then
				local position = boundsCFrame.Position
				local height = if boundsSize then boundsSize.Y / 2 else 0
				return CFrame.new(position.X, position.Y + height, position.Z), nil
			end
		end
	end

	return nil, "Select a Part or Model to spawn on. The NPC went to the origin."
end

local function atCursor(hostPlugin: Plugin): (CFrame?, string?)
	local ok, mouse = pcall(function()
		return hostPlugin:GetMouse()
	end)
	if not ok or mouse == nil then
		return nil, "Cursor position unavailable, so the NPC went to the origin."
	end

	local hitOk, hit = pcall(function()
		return mouse.Hit
	end)
	if not hitOk or typeof(hit) ~= "CFrame" then
		return nil, "Cursor position unavailable, so the NPC went to the origin."
	end

	local target: Instance? = nil
	pcall(function()
		target = mouse.Target
	end)
	if target == nil then
		return nil, "The cursor was not over any part, so the NPC went to the origin."
	end

	return CFrame.new(hit.Position), nil
end

function SpawnManager.resolve(mode: string, hostPlugin: Plugin): (CFrame, string?)
	if mode == "Selected" then
		local cframe, warning = aboveSelection()
		return cframe or originCFrame(), warning
	end
	if mode == "Cursor" then
		local cframe, warning = atCursor(hostPlugin)
		return cframe or originCFrame(), warning
	end
	return originCFrame(), nil
end

function SpawnManager.atCursorOrNil(hostPlugin: Plugin): (CFrame?, string?)
	return atCursor(hostPlugin)
end

return SpawnManager
