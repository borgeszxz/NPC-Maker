local HttpService = game:GetService("HttpService")

local STORAGE_KEY = "NPCMaker_Config_v1"

export type MarketplaceFilters = {
	keyword: string,
	category: string,
	sort: string,
	includeOffSale: boolean,
	hideUnsupported: boolean,
	minPrice: number,
	maxPrice: number,
}

export type Config = {
	tab: string,
	avatarMode: string,
	rig: string,
	npcName: string,
	health: number,
	walkSpeed: number,
	jumpPower: number,
	npcType: string,
	faction: string,
	behavior: string,
	spawnMode: string,
	createConfig: boolean,
	addAttributes: boolean,
	useNpcFolder: boolean,
	addBehaviorScript: boolean,
	marketplace: MarketplaceFilters,
}

local function defaults(): Config
	return {
		tab = "Avatar",
		avatarMode = "Player",
		rig = "R15",
		npcName = "",
		health = 100,
		walkSpeed = 12,
		jumpPower = 50,
		npcType = "Citizen",
		faction = "Neutral",
		behavior = "Wander",
		spawnMode = "Origin",
		createConfig = true,
		addAttributes = true,
		useNpcFolder = true,
		addBehaviorScript = true,
		marketplace = {
			keyword = "",
			category = "All",
			sort = "Relevance",
			includeOffSale = false,
			hideUnsupported = true,
			minPrice = 0,
			maxPrice = 0,
		},
	}
end

local Settings = {}

local pluginRef: Plugin? = nil
local config: Config = defaults()

local function merge(target: any, stored: any)
	if typeof(stored) ~= "table" then
		return
	end
	for key, value in pairs(target) do
		local incoming = stored[key]
		if incoming == nil then
			continue
		end
		if typeof(value) == "table" and typeof(incoming) == "table" then
			merge(value, incoming)
		elseif typeof(value) == typeof(incoming) then
			target[key] = incoming
		end
	end
end

function Settings.init(hostPlugin: Plugin)
	pluginRef = hostPlugin
	config = defaults()

	local ok, raw = pcall(function()
		return hostPlugin:GetSetting(STORAGE_KEY)
	end)
	if not ok or typeof(raw) ~= "string" or raw == "" then
		return
	end

	local decoded: any
	local decodeOk = pcall(function()
		decoded = HttpService:JSONDecode(raw)
	end)
	if decodeOk then
		merge(config, decoded)
	end
end

function Settings.get(): Config
	return config
end

function Settings.save()
	local host = pluginRef
	if host == nil then
		return
	end
	local encoded: string?
	local ok = pcall(function()
		encoded = HttpService:JSONEncode(config)
	end)
	if ok and encoded ~= nil then
		pcall(function()
			host:SetSetting(STORAGE_KEY, encoded)
		end)
	end
end

export type Preset = {
	id: string,
	label: string,
	health: number,
	walkSpeed: number,
	behavior: string,
	faction: string,
	npcType: string,
}

Settings.PRESETS = {
	{ id = "Friendly", label = "Friendly", health = 100, walkSpeed = 12, behavior = "Idle", faction = "Friendly", npcType = "Citizen" },
	{ id = "Wanderer", label = "Wanderer", health = 100, walkSpeed = 10, behavior = "Wander", faction = "Neutral", npcType = "Citizen" },
	{ id = "Guard", label = "Guard", health = 150, walkSpeed = 14, behavior = "Guard Area", faction = "Friendly", npcType = "Guard" },
	{ id = "Enemy", label = "Enemy", health = 150, walkSpeed = 16, behavior = "Enemy", faction = "Enemy", npcType = "Enemy" },
} :: { Preset }

function Settings.applyPreset(preset: Preset)
	config.health = preset.health
	config.walkSpeed = preset.walkSpeed
	config.behavior = preset.behavior
	config.faction = preset.faction
	config.npcType = preset.npcType
	Settings.save()
end

return Settings
