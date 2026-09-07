local Maid = require(script.Parent.Parent.Utils.Maid)
local ValidationUtils = require(script.Parent.Parent.Utils.ValidationUtils)
local Settings = require(script.Parent.Parent.Modules.Settings)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local ConfigPanel = require(script.Parent.ConfigPanel)

local CreatePanel = {}

local Color = Theme.Color

local AMOUNT_RULE = { min = 1, max = 100, default = 10, integer = true }
local SPACING_RULE = { min = 2, max = 200, default = 6, integer = false }
local LABEL_WIDTH = 132

export type Panel = {
	refresh: () -> (),
}

local function summaryRow(parent: Instance, key: string, value: string)
	local row = Instance.new("Frame")
	row.Name = "SummaryRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 26)
	row.LayoutOrder = #parent:GetChildren()
	row.Parent = parent

	local keyLabel = Instance.new("TextLabel")
	keyLabel.BackgroundTransparency = 1
	keyLabel.Size = UDim2.fromOffset(100, 26)
	keyLabel.Font = Theme.Font.Medium
	keyLabel.TextSize = 14
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.Text = key
	keyLabel.Parent = row
	Theme.bind(keyLabel, "TextColor3", Color.DimmedText)

	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.Position = UDim2.fromOffset(104, 0)
	valueLabel.Size = UDim2.new(1, -104, 0, 26)
	valueLabel.Font = Theme.Font.Regular
	valueLabel.TextSize = 15
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
	valueLabel.Text = value
	valueLabel.Parent = row
	Theme.bind(valueLabel, "TextColor3", Color.MainText)
end

function CreatePanel.mount(
	leftContent: Instance,
	rightContent: Instance,
	maid: Maid.Maid,
	configPanel: ConfigPanel.Panel
): Panel
	local config = Settings.get()

	local left = Components.column(leftContent, "IdentityPanel", 12)

	Components.sectionTitle(left, "Identity")
	local typeBox = Components.field(left, { label = "NPC Type", text = config.npcType, labelWidth = LABEL_WIDTH })
	local factionBox = Components.field(left, { label = "Faction", text = config.faction, labelWidth = LABEL_WIDTH })

	Components.divider(left)
	Components.sectionTitle(left, "Presets")
	local presetRow = Components.row(left, "Presets", 36)
	local presetStatus = Components.status(left)

	Components.divider(left)
	Components.sectionTitle(left, "Advanced")
	local folderToggle = Components.checkbox(left, "Put NPCs inside Workspace.NPCs", config.useNpcFolder, function(value)
		config.useNpcFolder = value
		Settings.save()
	end)
	local scriptToggle = Components.checkbox(left, "Add behavior controller script", config.addBehaviorScript, function(value)
		config.addBehaviorScript = value
		Settings.save()
	end)

	local right = Components.column(rightContent, "CreateActions", 12)

	Components.sectionTitle(right, "Summary")
	local summaryList = Components.column(right, "Summary", 2)

	Components.divider(right)
	Components.sectionTitle(right, "Single NPC")
	local singleRow = Components.row(right, "Single", 50)
	local createButton = Components.button(singleRow, "Create NPC", "success", configPanel.createNPC)
	createButton.instance.TextSize = 16
	createButton.instance.Size = UDim2.new(0.5, -3, 1, 0)
	createButton.instance.AutomaticSize = Enum.AutomaticSize.None
	local cursorButton = Components.button(singleRow, "Create at Cursor", "primary", configPanel.createAtCursor)
	cursorButton.instance.TextSize = 16
	cursorButton.instance.Size = UDim2.new(0.5, -3, 1, 0)
	cursorButton.instance.AutomaticSize = Enum.AutomaticSize.None

	Components.divider(right)
	Components.sectionTitle(right, "Crowd")
	local amountBox = Components.field(right, { label = "Amount", text = "10", labelWidth = LABEL_WIDTH })
	local spacingBox = Components.field(right, { label = "Spacing (studs)", text = "6", labelWidth = LABEL_WIDTH })
	local crowdStatus = Components.status(right)

	Components.wideButton(right, "Create Crowd", "primary", function()
		local amount, amountErr = ValidationUtils.number(amountBox.Text, AMOUNT_RULE)
		local spacing, spacingErr = ValidationUtils.number(spacingBox.Text, SPACING_RULE)
		amountBox.Text = tostring(amount)
		spacingBox.Text = tostring(spacing)

		local complaint = amountErr or spacingErr
		if complaint then
			crowdStatus.set(complaint, "warning")
		else
			crowdStatus.clear()
		end
		configPanel.createCrowd(amount, spacing)
	end, 50, 16)

	local function readIdentity()
		local npcType = ValidationUtils.trim(typeBox.Text)
		local faction = ValidationUtils.trim(factionBox.Text)
		config.npcType = if npcType ~= "" then npcType else "Citizen"
		config.faction = if faction ~= "" then faction else "Neutral"
		typeBox.Text = config.npcType
		factionBox.Text = config.faction
		Settings.save()
	end

	local function renderSummary()
		for _, child in summaryList:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		for line in string.gmatch(configPanel.summary(), "[^\n]+") do
			local key, value = string.match(line, "^([^|]+)|(.*)$")
			if key and value then
				summaryRow(summaryList, key, value)
			end
		end
	end

	for _, preset in Settings.PRESETS do
		local captured = preset
		Components.button(presetRow, preset.label, "neutral", function()
			Settings.applyPreset(captured)
			typeBox.Text = config.npcType
			factionBox.Text = config.faction
			configPanel.refresh()
			renderSummary()
			presetStatus.set(string.format("Preset applied: %s.", captured.label), "success")
		end)
	end

	maid.add(typeBox.FocusLost:Connect(function()
		readIdentity()
		renderSummary()
	end))
	maid.add(factionBox.FocusLost:Connect(function()
		readIdentity()
		renderSummary()
	end))

	local function refresh()
		typeBox.Text = config.npcType
		factionBox.Text = config.faction
		folderToggle.setValue(config.useNpcFolder)
		scriptToggle.setValue(config.addBehaviorScript)
		renderSummary()
	end

	refresh()

	return {
		refresh = refresh,
	}
end

return CreatePanel
