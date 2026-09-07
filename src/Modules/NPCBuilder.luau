local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local AvatarService = require(script.Parent.AvatarService)
local BehaviorTemplates = require(script.Parent.BehaviorTemplates)
local AnimationController = require(script.Parent.AnimationController)
local NameUtils = require(script.Parent.Parent.Utils.NameUtils)

local NPCBuilder = {}

local FOLDER_NAME = "NPCs"
local CONTROLLER_NAME = "NPCController"

export type Options = {
	description: HumanoidDescription,
	rig: string,
	name: string,
	health: number,
	walkSpeed: number,
	jumpPower: number,
	npcType: string,
	faction: string,
	behavior: string,
	spawnCFrame: CFrame,
	createConfig: boolean,
	addAttributes: boolean,
	useNpcFolder: boolean,
	addBehaviorScript: boolean,
	sourceType: string,
	originalUserId: number?,
}

local function configureHumanoid(humanoid: Humanoid, options: Options, displayName: string)
	pcall(function()
		humanoid.MaxHealth = options.health
		humanoid.Health = options.health
		humanoid.WalkSpeed = options.walkSpeed
		humanoid.DisplayName = displayName
	end)

	pcall(function()
		humanoid.UseJumpPower = true
		humanoid.JumpPower = options.jumpPower
	end)
end

local function applyAttributes(model: Model, options: Options)
	model:SetAttribute("NPC", true)
	model:SetAttribute("NPCType", options.npcType)
	model:SetAttribute("Faction", options.faction)
	model:SetAttribute("Behavior", options.behavior)
	model:SetAttribute("SourceType", options.sourceType)
	if options.originalUserId ~= nil then
		model:SetAttribute("OriginalUserId", options.originalUserId)
	end
end

local function createConfigFolder(model: Model, options: Options)
	local template = BehaviorTemplates.get(options.behavior)
	local folder = Instance.new("Configuration")
	folder.Name = "Config"

	for key, value in template.config do
		folder:SetAttribute(key, value)
	end

	folder.Parent = model
end

local function createController(model: Model, options: Options)
	local template = BehaviorTemplates.get(options.behavior)
	if template.source == "" then
		return
	end

	local controller = Instance.new("Script")
	controller.Name = CONTROLLER_NAME
	controller.Source = template.source
	controller.Parent = model
end

local function placeOnGround(model: Model, ground: CFrame)
	local pivot = model:GetPivot()
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local bottom = boundsCFrame.Position.Y - boundsSize.Y / 2
	local feetToPivot = pivot.Position.Y - bottom

	local target = ground.Position + Vector3.new(0, feetToPivot + 0.05, 0)
	model:PivotTo(CFrame.new(target) * ground.Rotation)
end

local function resolveParent(options: Options): Instance
	if not options.useNpcFolder then
		return Workspace
	end

	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function decorate(model: Model, options: Options, displayName: string): string?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		configureHumanoid(humanoid, options, displayName)
	end

	local _, animationNote = AnimationController.install(model, options.rig)

	if options.addAttributes then
		applyAttributes(model, options)
	end
	if options.createConfig then
		createConfigFolder(model, options)
	end
	if options.addBehaviorScript then
		createController(model, options)
	end
	return animationNote
end

local function finishRecording(recording: string?, commit: boolean)
	if recording == nil then
		return
	end
	ChangeHistoryService:FinishRecording(
		recording,
		if commit then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
end

function NPCBuilder.create(options: Options): (Model?, string?, string?)

	local model, err = AvatarService.createModel(options.description, options.rig)
	if model == nil then
		return nil, err
	end

	local recording = ChangeHistoryService:TryBeginRecording("Create NPC", "Create NPC")
	local animationNote: string? = nil

	local ok, failure = pcall(function()
		local parent = resolveParent(options)
		local name = NameUtils.unique(parent, options.name)

		animationNote = decorate(model, options, name)
		model.Name = name
		model.Parent = parent
		placeOnGround(model, options.spawnCFrame)
	end)

	if not ok then
		model:Destroy()
		finishRecording(recording, false)
		return nil, "Could not finish the NPC: " .. tostring(failure)
	end

	finishRecording(recording, true)
	if recording == nil then
		warn("[NPC Maker] another recording was already open; this NPC is not a single undo step.")
	end

	pcall(function()
		Selection:Set({ model })
	end)

	return model, nil, animationNote
end

function NPCBuilder.createCrowd(options: Options, amount: number, spacing: number): ({ Model }, string?, string?)
	amount = math.clamp(math.floor(amount), 1, 100)
	spacing = math.max(spacing, 2)

	local base, err = AvatarService.createModel(options.description, options.rig)
	if base == nil then
		return {}, err
	end

	local recording = ChangeHistoryService:TryBeginRecording("Create NPC Crowd", "Create NPC Crowd")
	local created: { Model } = {}
	local animationNote: string? = nil

	local ok, failure = pcall(function()
		local parent = resolveParent(options)
		local baseName = NameUtils.sanitize(options.name)

		animationNote = decorate(base, options, baseName)

		local columns = math.ceil(math.sqrt(amount))
		local rows = math.ceil(amount / columns)
		local origin = options.spawnCFrame.Position
		local offsetX = (columns - 1) * spacing / 2
		local offsetZ = (rows - 1) * spacing / 2

		for index = 1, amount do
			local model = if index == 1 then base else base:Clone()
			local column = (index - 1) % columns
			local row = math.floor((index - 1) / columns)

			local name = NameUtils.indexed(baseName, index, amount)
			model.Name = NameUtils.unique(parent, name)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				pcall(function()
					humanoid.DisplayName = model.Name
				end)
			end

			model.Parent = parent

			local ground = CFrame.new(
				origin.X - offsetX + column * spacing,
				origin.Y,
				origin.Z - offsetZ + row * spacing
			) * options.spawnCFrame.Rotation
			placeOnGround(model, ground)

			table.insert(created, model)
		end
	end)

	if not ok then
		for _, model in created do
			model:Destroy()
		end
		if base.Parent == nil then
			base:Destroy()
		end
		finishRecording(recording, false)
		return {}, "Could not finish the crowd: " .. tostring(failure)
	end

	finishRecording(recording, true)
	if recording == nil then
		warn("[NPC Maker] another recording was already open; this crowd is not a single undo step.")
	end

	pcall(function()
		Selection:Set(created)
	end)

	return created, nil, animationNote
end

function NPCBuilder.findExisting(): { Model }
	local found: { Model } = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("NPC") == true then
			table.insert(found, descendant)
		end
	end
	table.sort(found, function(a: Model, b: Model): boolean
		return a.Name < b.Name
	end)
	return found
end

function NPCBuilder.remove(models: { Model }): boolean
	if #models == 0 then
		return false
	end
	local recording = ChangeHistoryService:TryBeginRecording("Delete NPCs", "Delete NPCs")
	for _, model in models do
		pcall(function()
			model:Destroy()
		end)
	end
	finishRecording(recording, true)
	return true
end

NPCBuilder.FOLDER_NAME = FOLDER_NAME

return NPCBuilder
