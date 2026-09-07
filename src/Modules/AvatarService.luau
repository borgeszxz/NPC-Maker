local Players = game:GetService("Players")

local AvatarService = {}

export type UserResult = {
	userId: number,
	username: string,
}

local function friendlyError(raw: any, fallback: string): string
	local text = tostring(raw)
	if string.find(text, "Unknown user") then
		return "User not found."
	end
	if string.find(text, "HTTP") or string.find(text, "Timeout") or string.find(text, "timed out") then
		return "Roblox did not respond. Check your connection and try again."
	end
	return fallback
end

function AvatarService.resolveUser(input: string): (UserResult?, string?)
	local trimmed = string.match(input, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil, "Enter a username or UserId."
	end

	local numeric = tonumber(trimmed)
	if numeric and numeric > 0 and numeric == math.floor(numeric) then
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(numeric)
		end)
		if not ok then
			return nil, friendlyError(name, "User not found.")
		end
		return { userId = numeric, username = name }, nil
	end

	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(trimmed)
	end)
	if not ok then
		return nil, friendlyError(userId, "User not found.")
	end
	return { userId = userId, username = trimmed }, nil
end

function AvatarService.getDescription(userId: number): (HumanoidDescription?, string?)
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
	end)
	if not ok or description == nil then
		return nil, friendlyError(description, "Could not load avatar.")
	end
	return description, nil
end

function AvatarService.getDescriptionFromOutfit(outfitId: number): (HumanoidDescription?, string?)
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromOutfitIdAsync(outfitId)
	end)
	if ok and description ~= nil then
		return description, nil
	end

	local legacyOk, legacy = pcall(function()
		return (Players :: any):GetHumanoidDescriptionFromOutfitId(outfitId)
	end)
	if legacyOk and legacy ~= nil then
		return legacy, nil
	end
	return nil, friendlyError(description, "Could not load that bundle outfit.")
end

function AvatarService.blankDescription(): HumanoidDescription
	return Instance.new("HumanoidDescription")
end

function AvatarService.rigType(rig: string): Enum.HumanoidRigType
	return if rig == "R6" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15
end

function AvatarService.createModel(
	description: HumanoidDescription,
	rig: string
): (Model?, string?)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			AvatarService.rigType(rig)
		)
	end)
	if not ok or model == nil then
		return nil, friendlyError(model, "Could not build the character model.")
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		model:Destroy()
		return nil, "Roblox returned a model without a Humanoid."
	end
	return model, nil
end

return AvatarService
