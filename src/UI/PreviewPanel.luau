local RunService = game:GetService("RunService")

local Maid = require(script.Parent.Parent.Utils.Maid)
local Settings = require(script.Parent.Parent.Modules.Settings)
local AvatarService = require(script.Parent.Parent.Modules.AvatarService)
local DescriptionBuilder = require(script.Parent.Parent.Modules.DescriptionBuilder)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local PreviewPanel = {}

local Color = Theme.Color

local REBUILD_DELAY = 0.35
local YAW_STEP = 45
local DRAG_SENSITIVITY = 0.5
local ROTATION_SMOOTHING = 10
local FRAME_MARGIN = 1.18

export type Panel = {
	refresh: () -> (),
	rebuild: () -> (),
	setStageHeight: (height: number) -> (),
}

local function readIdleAnimationId(model: Model): string?
	local animate = model:FindFirstChild("Animate")
	local idle = animate and animate:FindFirstChild("idle")
	local clip = idle and (idle:FindFirstChild("Animation1") or idle:FindFirstChildWhichIsA("Animation"))
	if clip and clip:IsA("Animation") and clip.AnimationId ~= "" then
		return clip.AnimationId
	end
	return nil
end

local function stripScripts(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
end

local function bodyExtents(model: Model): (Vector3, number, number)
	local root = model:FindFirstChild("HumanoidRootPart")
	local centre = if root and root:IsA("BasePart") then root.Position else model:GetPivot().Position

	local minY, maxY = math.huge, -math.huge
	local maxRadius = 0
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local top = child.Position.Y + child.Size.Y / 2
			local bottom = child.Position.Y - child.Size.Y / 2
			minY = math.min(minY, bottom)
			maxY = math.max(maxY, top)
			local lateral = (Vector3.new(child.Position.X, 0, child.Position.Z) - Vector3.new(centre.X, 0, centre.Z)).Magnitude
			maxRadius = math.max(maxRadius, lateral + math.max(child.Size.X, child.Size.Z) / 2)
		end
	end

	if minY == math.huge then
		return centre, 5, 1.5
	end
	local height = maxY - minY
	return Vector3.new(centre.X, (minY + maxY) / 2, centre.Z), height, maxRadius
end

function PreviewPanel.mount(content: Instance, maid: Maid.Maid, onUseAvatar: (() -> ())?, stageHeight: number?): Panel
	local config = Settings.get()

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BorderSizePixel = 0
	stage.Size = UDim2.new(1, 0, 0, stageHeight or 320)
	stage.LayoutOrder = 1
	stage.Parent = content
	maid.add(stage)

	local stageCorner = Instance.new("UICorner")
	stageCorner.CornerRadius = UDim.new(0, 10)
	stageCorner.Parent = stage

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = stage

	local function paintGradient()
		gradient.Color = ColorSequence.new(
			Theme.color(Color.ViewportTop),
			Theme.color(Color.ViewportBottom)
		)
	end
	stage.BackgroundColor3 = Color3.new(1, 1, 1)
	paintGradient()

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(170, 170, 175)
	viewport.LightColor = Color3.fromRGB(255, 252, 245)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.8)
	viewport.Parent = stage

	local world = Instance.new("WorldModel")
	world.Name = "World"
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = 55
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local placeholder = Instance.new("TextLabel")
	placeholder.Name = "Placeholder"
	placeholder.BackgroundTransparency = 1
	placeholder.Size = UDim2.new(1, -24, 1, 0)
	placeholder.Position = UDim2.fromOffset(12, 0)
	placeholder.Font = Theme.Font.Medium
	placeholder.TextSize = 14
	placeholder.TextWrapped = true
	placeholder.Text = "Pick an avatar to preview it here."
	placeholder.Parent = stage
	Theme.bind(placeholder, "TextColor3", Color.MainText)

	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.BackgroundTransparency = 1
	controls.AnchorPoint = Vector2.new(0.5, 1)
	controls.Position = UDim2.new(0.5, 0, 1, -12)
	controls.Size = UDim2.fromOffset(100, 40)
	controls.Parent = stage

	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Padding = UDim.new(0, 8)
	controlsLayout.Parent = controls

	local previewModel: Model? = nil
	local idleTrack: AnimationTrack? = nil
	local yaw = 0
	local targetYaw = 0
	local generation = 0
	local pendingThread: thread? = nil

	local focus = Vector3.zero
	local distance = 8
	local lift = 0

	local function frameCamera()
		local model = previewModel
		if model == nil then
			return
		end
		local centre, height, radius = bodyExtents(model)
		focus = centre

		local halfFov = math.rad(camera.FieldOfView / 2)
		local aspect = math.max(stage.AbsoluteSize.X, 1) / math.max(stage.AbsoluteSize.Y, 1)
		local byHeight = (height / 2 * FRAME_MARGIN) / math.tan(halfFov)
		local byWidth = (radius * FRAME_MARGIN) / (math.tan(halfFov) * aspect)
		distance = math.max(byHeight, byWidth, 4)
		lift = height * 0.04
	end

	local function updateCamera()
		if previewModel == nil then
			return
		end
		local offset = CFrame.Angles(0, math.rad(yaw), 0) * Vector3.new(0, lift, distance)
		camera.CFrame = CFrame.lookAt(focus + offset, focus + Vector3.new(0, lift * 0.5, 0))
	end

	local function clearModel()
		if idleTrack then
			pcall(function()
				idleTrack:Stop(0)
			end)
			idleTrack = nil
		end
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end
	end

	local function showPlaceholder(text: string)
		placeholder.Text = text
		placeholder.Visible = true
		controls.Visible = false
	end

	local function playIdle(model: Model, animationId: string?)
		if animationId == nil then
			return
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			return
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator == nil then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end

		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = true
			track:Play(0)
			idleTrack = track
		end
	end

	local rebuild: () -> ()

	rebuild = function()
		generation += 1
		local ticket = generation

		showPlaceholder("Building preview...")

		task.spawn(function()
			local description = DescriptionBuilder.build()
			local model, err = AvatarService.createModel(description, config.rig)
			description:Destroy()

			if ticket ~= generation then
				if model then
					model:Destroy()
				end
				return
			end

			if model == nil then
				clearModel()
				showPlaceholder(err or "Could not build the preview.")
				return
			end

			local idleId = readIdleAnimationId(model)
			stripScripts(model)

			clearModel()
			previewModel = model
			model.Parent = world

			task.wait()
			if ticket ~= generation then
				return
			end

			frameCamera()
			updateCamera()
			playIdle(model, idleId)

			placeholder.Visible = false
			controls.Visible = true
		end)
	end

	local function scheduleRebuild()
		if pendingThread then
			task.cancel(pendingThread)
			pendingThread = nil
		end
		pendingThread = task.delay(REBUILD_DELAY, function()
			pendingThread = nil
			rebuild()
		end)
	end

	Components.init(maid)
	Components.iconButton(controls, "<", 40, function()
		targetYaw -= YAW_STEP
	end)
	Components.iconButton(controls, ">", 40, function()
		targetYaw += YAW_STEP
	end)

	maid.add(RunService.Heartbeat:Connect(function(delta: number)
		if previewModel == nil then
			return
		end
		local difference = targetYaw - yaw
		if math.abs(difference) < 0.01 then
			return
		end
		yaw += difference * math.min(delta * ROTATION_SMOOTHING, 1)
		updateCamera()
	end))

	local dragging = false
	local lastX = 0

	maid.add(viewport.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			lastX = input.Position.X
		end
	end))
	maid.add(viewport.InputChanged:Connect(function(input: InputObject)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position.X - lastX
			lastX = input.Position.X
			targetYaw -= delta * DRAG_SENSITIVITY
			yaw = targetYaw
			updateCamera()
		end
	end))
	maid.add(viewport.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))

	maid.add(stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		frameCamera()
		updateCamera()
	end))

	local status = Components.status(content)
	local baseLabel = Components.body(content, "", true)

	local itemsContainer = Components.column(content, "PreviewItems", 2)
	local itemsMaid: Maid.Maid? = nil

	local function renderItems()
		local source = DescriptionBuilder.getSource()
		baseLabel.Text = string.format("Base: %s  -  %s", source.label, config.rig)

		if itemsMaid then
			itemsMaid.destroy()
		end
		local scoped = Maid.new()
		itemsMaid = scoped
		Components.init(scoped)

		itemsContainer:SetAttribute("NPCM_Order", 0)
		for _, child in itemsContainer:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		local items = DescriptionBuilder.getItems()
		if #items == 0 then
			Components.body(itemsContainer, "No marketplace items added yet.", true)
		else
			for index, item in items do
				local captured = index
				Components.itemRow(itemsContainer, item.slot, item.name, function()
					DescriptionBuilder.removeItem(captured)
				end)
			end
		end

		Components.init(maid)
	end

	Components.init(maid)
	local quickRow = Components.row(content, "PreviewQuick", 30)
	Components.button(quickRow, "Clear Items", "neutral", function()
		DescriptionBuilder.clearItems()
	end)
	Components.button(quickRow, "Reset", "neutral", function()
		DescriptionBuilder.resetToDefault()
	end)
	Components.button(quickRow, "Refresh", "neutral", function()
		rebuild()
	end)

	if onUseAvatar then
		Components.wideButton(content, "Use This Avatar", "primary", function()
			status.set("Avatar locked in. Configure the NPC in step 3.", "success")
			onUseAvatar()
		end, 46, 16)
	end

	maid.add(DescriptionBuilder.onChanged(function()
		renderItems()
		scheduleRebuild()
	end))
	maid.add(function()
		if pendingThread then
			task.cancel(pendingThread)
			pendingThread = nil
		end
		if itemsMaid then
			itemsMaid.destroy()
		end
		clearModel()
	end)

	renderItems()
	showPlaceholder("Pick an avatar, or press Refresh to preview the default rig.")

	return {
		refresh = function()
			paintGradient()
			renderItems()
		end,
		rebuild = rebuild,

		setStageHeight = function(height: number)
			if math.abs(stage.AbsoluteSize.Y - height) < 1 then
				return
			end
			stage.Size = UDim2.new(1, 0, 0, height)
			frameCamera()
			updateCamera()
		end,
	}
end

return PreviewPanel
