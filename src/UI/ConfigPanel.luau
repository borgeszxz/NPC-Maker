local Maid = require(script.Parent.Parent.Utils.Maid)
local NameUtils = require(script.Parent.Parent.Utils.NameUtils)
local ValidationUtils = require(script.Parent.Parent.Utils.ValidationUtils)
local Settings = require(script.Parent.Parent.Modules.Settings)
local DescriptionBuilder = require(script.Parent.Parent.Modules.DescriptionBuilder)
local BehaviorTemplates = require(script.Parent.Parent.Modules.BehaviorTemplates)
local NPCBuilder = require(script.Parent.Parent.Modules.NPCBuilder)
local SpawnManager = require(script.Parent.Parent.Modules.SpawnManager)

local Components = require(script.Parent.Components)

local ConfigPanel = {}

local RIGS: { Components.SegmentItem } = {
	{ id = "R15", label = "R15" },
	{ id = "R6", label = "R6" },
}

local HEALTH_RULE = { min = 1, max = 1000000, default = 100, integer = false }
local SPEED_RULE = { min = 0, max = 500, default = 12, integer = false }
local JUMP_RULE = { min = 0, max = 500, default = 50, integer = false }
local LABEL_WIDTH = 118

export type Panel = {
	frame: Frame,
	refresh: () -> (),
	createNPC: () -> (),
	createAtCursor: () -> (),
	createCrowd: (amount: number, spacing: number) -> (),
	summary: () -> string,
	setStatus: (text: string, kind: string) -> (),
	readFields: () -> string?,
}

function ConfigPanel.mount(parent: Instance, maid: Maid.Maid, hostPlugin: Plugin): Panel
	local config = Settings.get()

	local frame = Components.column(parent, "ConfigPanel", 10)

	Components.sectionTitle(frame, "NPC Name")
	local nameBox = Components.textBox(frame, {
		placeholder = "Leave blank to name it after the avatar",
		height = 38,
		multiLine = false,
		text = config.npcName,
	})

	local rigHolder = Components.labelledRow(frame, "Rig Type", LABEL_WIDTH)
	local rigSwitch = Components.segmented(rigHolder, RIGS, config.rig, function(value)
		config.rig = value
		Settings.save()
	end)

	Components.divider(frame)

	local healthBox = Components.field(frame, { label = "Health", text = tostring(config.health), labelWidth = LABEL_WIDTH })
	local speedBox = Components.field(frame, { label = "WalkSpeed", text = tostring(config.walkSpeed), labelWidth = LABEL_WIDTH })
	local jumpBox = Components.field(frame, { label = "JumpPower", text = tostring(config.jumpPower), labelWidth = LABEL_WIDTH })

	Components.divider(frame)

	local behaviorOptions: { Components.SegmentItem } = {}
	for _, template in BehaviorTemplates.list() do
		table.insert(behaviorOptions, { id = template.id, label = template.label })
	end

	local behaviorRow = Components.labelledRow(frame, "Behavior", LABEL_WIDTH)
	local behaviorDropdown = Components.dropdown(behaviorRow, behaviorOptions, config.behavior, function(value)
		config.behavior = value
		Settings.save()
	end)

	local spawnRow = Components.labelledRow(frame, "Spawn Position", LABEL_WIDTH)
	local spawnDropdown = Components.dropdown(spawnRow, SpawnManager.MODES, config.spawnMode, function(value)
		config.spawnMode = value
		Settings.save()
	end)

	Components.divider(frame)
	Components.sectionTitle(frame, "Options")
	local configToggle = Components.checkbox(frame, "Add Config", config.createConfig, function(value)
		config.createConfig = value
		Settings.save()
	end)
	local attributesToggle = Components.checkbox(frame, "Add Attributes", config.addAttributes, function(value)
		config.addAttributes = value
		Settings.save()
	end)

	Components.spacer(frame, 4)
	local createButton: Components.Button
	local status = Components.status(frame)

	local busy = false

	local function readFields(): string?
		local complaint: string? = nil

		config.npcName = ValidationUtils.trim(nameBox.Text)

		local health, healthErr = ValidationUtils.number(healthBox.Text, HEALTH_RULE)
		config.health = health
		complaint = complaint or (if healthErr then "Health: " .. healthErr else nil)

		local speed, speedErr = ValidationUtils.number(speedBox.Text, SPEED_RULE)
		config.walkSpeed = speed
		complaint = complaint or (if speedErr then "WalkSpeed: " .. speedErr else nil)

		local jump, jumpErr = ValidationUtils.number(jumpBox.Text, JUMP_RULE)
		config.jumpPower = jump
		complaint = complaint or (if jumpErr then "JumpPower: " .. jumpErr else nil)

		healthBox.Text = tostring(config.health)
		speedBox.Text = tostring(config.walkSpeed)
		jumpBox.Text = tostring(config.jumpPower)

		Settings.save()
		return complaint
	end

	local function sourceType(): string
		if #DescriptionBuilder.getItems() > 0 then
			return "Marketplace"
		end
		return DescriptionBuilder.getSource().kind
	end

	local function buildOptions(spawnMode: string): (NPCBuilder.Options, string?)
		local spawnCFrame, spawnWarning = SpawnManager.resolve(spawnMode, hostPlugin)
		local source = DescriptionBuilder.getSource()

		local name = config.npcName
		if name == "" then
			name = NameUtils.defaultName(source.label)
		end

		return {
			description = DescriptionBuilder.build(),
			rig = config.rig,
			name = name,
			health = config.health,
			walkSpeed = config.walkSpeed,
			jumpPower = config.jumpPower,
			npcType = config.npcType,
			faction = config.faction,
			behavior = config.behavior,
			spawnCFrame = spawnCFrame,
			createConfig = config.createConfig,
			addAttributes = config.addAttributes,
			useNpcFolder = config.useNpcFolder,
			addBehaviorScript = config.addBehaviorScript,
			sourceType = sourceType(),
			originalUserId = source.userId,
		}, spawnWarning
	end

	local function beginWork(label: string): boolean
		if busy then
			return false
		end
		local complaint = readFields()
		busy = true
		createButton.setEnabled(false)
		createButton.setText(label)
		status.set(complaint or label, if complaint then "warning" else "info")
		return true
	end

	local function endWork()
		busy = false
		createButton.setEnabled(true)
		createButton.setText("Create NPC")
	end

	local function createNPC(spawnOverride: string?)
		if not beginWork("Creating NPC...") then
			return
		end

		task.spawn(function()
			task.wait()

			local options, spawnWarning = buildOptions(spawnOverride or config.spawnMode)
			local model, err, animationNote = NPCBuilder.create(options)
			options.description:Destroy()
			endWork()

			if model == nil then
				status.set(err or "Could not create the NPC.", "error")
				return
			end

			local message = string.format("Created %s. Ctrl+Z undoes it.", model.Name)
			local caveat = spawnWarning or animationNote
			status.set(if caveat then message .. " " .. caveat else message, if caveat then "warning" else "success")
		end)
	end

	local function createCrowd(amount: number, spacing: number)
		if not beginWork("Creating crowd...") then
			return
		end

		task.spawn(function()
			task.wait()

			local options, spawnWarning = buildOptions(config.spawnMode)
			local models, err, animationNote = NPCBuilder.createCrowd(options, amount, spacing)
			options.description:Destroy()
			endWork()

			if #models == 0 then
				status.set(err or "Could not create the crowd.", "error")
				return
			end

			local message = string.format("Created %d NPCs. Ctrl+Z undoes them all.", #models)
			local caveat = spawnWarning or animationNote
			status.set(if caveat then message .. " " .. caveat else message, if caveat then "warning" else "success")
		end)
	end

	createButton = Components.wideButton(frame, "Create NPC", "success", function()
		createNPC(nil)
	end, 50, 16)

	maid.add(nameBox.FocusLost:Connect(function()
		config.npcName = ValidationUtils.trim(nameBox.Text)
		Settings.save()
	end))
	for _, box in { healthBox, speedBox, jumpBox } do
		maid.add(box.FocusLost:Connect(function()
			local complaint = readFields()
			if complaint then
				status.set(complaint, "warning")
			end
		end))
	end

	local function refresh()
		rigSwitch.setValue(config.rig)
		spawnDropdown.setValue(config.spawnMode)
		behaviorDropdown.setValue(config.behavior)
		configToggle.setValue(config.createConfig)
		attributesToggle.setValue(config.addAttributes)
		nameBox.Text = config.npcName
		healthBox.Text = tostring(config.health)
		speedBox.Text = tostring(config.walkSpeed)
		jumpBox.Text = tostring(config.jumpPower)
	end

	local function summary(): string
		readFields()
		local source = DescriptionBuilder.getSource()
		local items = DescriptionBuilder.getItems()
		local name = if config.npcName ~= "" then config.npcName else NameUtils.defaultName(source.label)
		return table.concat({
			"Name|" .. name,
			string.format("Look|%s + %d marketplace item%s", source.label, #items, if #items == 1 then "" else "s"),
			"Rig|" .. config.rig,
			string.format("Stats|Health %g  -  WalkSpeed %g  -  JumpPower %g", config.health, config.walkSpeed, config.jumpPower),
			"Behavior|" .. config.behavior,
			string.format("Identity|%s  -  %s", config.npcType, config.faction),
			"Spawn|" .. config.spawnMode,
		}, "\n")
	end

	return {
		frame = frame,
		refresh = refresh,
		createNPC = function()
			createNPC(nil)
		end,
		createAtCursor = function()
			createNPC("Cursor")
		end,
		createCrowd = createCrowd,
		summary = summary,
		setStatus = status.set,
		readFields = readFields,
	}
end

return ConfigPanel
