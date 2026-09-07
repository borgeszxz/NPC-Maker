local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local Maid = require(script.Parent.Parent.Utils.Maid)
local Theme = require(script.Parent.Theme)

local Window = {}

local Color = Theme.Color

local TITLE_HEIGHT = 72
local TITLE_HEIGHT_COMPACT = 54
local COMPACT_WIDTH = 560
local CONTROL_SIZE = 36

export type Window = {
	host: LayerCollector,
	root: Frame,
	content: Frame,
	titleBar: Frame,
	setVisible: (visible: boolean) -> (),
	isVisible: () -> boolean,
	onVisibilityChanged: (callback: (visible: boolean) -> ()) -> (),
	addTitleControl: (glyph: string, tooltip: string, onClick: () -> (), order: number?) -> TextButton,
}

export type Options = {
	name: string,
	title: string,
	tagline: string,
	width: number,
	height: number,
}

local function createHost(options: Options, hostPlugin: Plugin?): LayerCollector
	if hostPlugin ~= nil then
		local info = DockWidgetPluginGuiInfo.new(
			Enum.InitialDockState.Float,
			false,
			false,
			options.width,
			options.height,
			360,
			420
		)
		local widget = hostPlugin:CreateDockWidgetPluginGui(options.name, info)
		widget.Name = options.name
		widget.Title = options.title
		widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		return widget
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = options.name
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 1000
	screen.Enabled = false
	screen.Parent = CoreGui
	return screen
end

function Window.create(options: Options, maid: Maid.Maid, hostPlugin: Plugin?): Window
	local host = createHost(options, hostPlugin)
	maid.add(host)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = host
	Theme.bind(root, "BackgroundColor3", Color.MainBackground)

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.BorderSizePixel = 0
	titleBar.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
	titleBar.Parent = root
	Theme.bind(titleBar, "BackgroundColor3", Color.HeaderBackground)

	local underline = Instance.new("Frame")
	underline.BorderSizePixel = 0
	underline.AnchorPoint = Vector2.new(0, 1)
	underline.Position = UDim2.new(0, 0, 1, 0)
	underline.Size = UDim2.new(1, 0, 0, 1)
	underline.Parent = titleBar
	Theme.bind(underline, "BackgroundColor3", Color.Border)

	local mark = Instance.new("Frame")
	mark.Name = "Mark"
	mark.BorderSizePixel = 0
	mark.AnchorPoint = Vector2.new(0, 0.5)
	mark.Position = UDim2.new(0, 16, 0.5, 0)
	mark.Size = UDim2.fromOffset(44, 44)
	mark.Parent = titleBar
	Theme.bind(mark, "BackgroundColor3", Color.Button)

	local markCorner = Instance.new("UICorner")
	markCorner.CornerRadius = UDim.new(0, 11)
	markCorner.Parent = mark

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BorderSizePixel = 0
	head.AnchorPoint = Vector2.new(0.5, 0)
	head.Position = UDim2.new(0.5, 0, 0, 8)
	head.Size = UDim2.fromOffset(15, 15)
	head.Parent = mark
	Theme.bind(head, "BackgroundColor3", Color.MainText)

	local headCorner = Instance.new("UICorner")
	headCorner.CornerRadius = UDim.new(1, 0)
	headCorner.Parent = head

	local shoulders = Instance.new("Frame")
	shoulders.Name = "Shoulders"
	shoulders.BorderSizePixel = 0
	shoulders.AnchorPoint = Vector2.new(0.5, 1)
	shoulders.Position = UDim2.new(0.5, 0, 1, -7)
	shoulders.Size = UDim2.fromOffset(26, 12)
	shoulders.Parent = mark
	Theme.bind(shoulders, "BackgroundColor3", Color.MainText)

	local shouldersCorner = Instance.new("UICorner")
	shouldersCorner.CornerRadius = UDim.new(0, 6)
	shouldersCorner.Parent = shoulders

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(72, 12)
	title.Size = UDim2.new(1, -190, 0, 30)
	title.Font = Theme.Font.Bold
	title.TextSize = Theme.Size.Title
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Text = options.title
	title.Parent = titleBar
	Theme.bind(title, "TextColor3", Color.MainText)

	local tagline = Instance.new("TextLabel")
	tagline.Name = "Tagline"
	tagline.BackgroundTransparency = 1
	tagline.Position = UDim2.fromOffset(72, 42)
	tagline.Size = UDim2.new(1, -190, 0, 18)
	tagline.Font = Theme.Font.Regular
	tagline.TextSize = Theme.Size.Subtitle
	tagline.TextXAlignment = Enum.TextXAlignment.Left
	tagline.TextTruncate = Enum.TextTruncate.AtEnd
	tagline.Text = options.tagline
	tagline.Parent = titleBar
	Theme.bind(tagline, "TextColor3", Color.DimmedText)

	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.BackgroundTransparency = 1
	controls.AnchorPoint = Vector2.new(1, 0.5)
	controls.Position = UDim2.new(1, -14, 0.5, 0)
	controls.Size = UDim2.fromOffset(0, CONTROL_SIZE)
	controls.AutomaticSize = Enum.AutomaticSize.X
	controls.Parent = titleBar

	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Padding = UDim.new(0, 6)
	controlsLayout.Parent = controls

	local controlCount = 0

	local function addTitleControl(glyph: string, tooltip: string, onClick: () -> (), order: number?): TextButton
		controlCount += 1
		local button = Instance.new("TextButton")
		button.Name = "Control_" .. glyph
		button.AutoButtonColor = false
		button.Size = UDim2.fromOffset(CONTROL_SIZE, CONTROL_SIZE)
		button.Font = Theme.Font.Bold
		button.TextSize = 17
		button.Text = glyph
		button.LayoutOrder = order or controlCount
		button.Parent = controls
		pcall(function()
			(button :: any).Tooltip = tooltip
		end)

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button

		local buttonStroke = Instance.new("UIStroke")
		buttonStroke.Thickness = 1
		buttonStroke.Parent = button

		Theme.bind(button, "BackgroundColor3", Color.Button)
		Theme.bind(button, "TextColor3", Color.ButtonText)
		Theme.bind(buttonStroke, "Color", Color.Border)

		maid.add(button.MouseEnter:Connect(function()
			button.BackgroundColor3 = Theme.color(Color.Button, Enum.StudioStyleGuideModifier.Hover)
		end))
		maid.add(button.MouseLeave:Connect(function()
			button.BackgroundColor3 = Theme.color(Color.Button)
		end))
		maid.add(button.Activated:Connect(function()
			local ok, err = pcall(onClick)
			if not ok then
				warn("[NPC Maker] title control failed: " .. tostring(err))
			end
		end))
		return button
	end

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, TITLE_HEIGHT)
	content.Size = UDim2.new(1, 0, 1, -TITLE_HEIGHT)
	content.Parent = root

	local lastHeaderWidth = -1

	local function applyHeaderSize()
		local width = root.AbsoluteSize.X
		if width <= 0 or width == lastHeaderWidth then
			return
		end
		lastHeaderWidth = width
		local compact = width < COMPACT_WIDTH
		local height = if compact then TITLE_HEIGHT_COMPACT else TITLE_HEIGHT

		titleBar.Size = UDim2.new(1, 0, 0, height)
		content.Position = UDim2.fromOffset(0, height)
		content.Size = UDim2.new(1, 0, 1, -height)

		tagline.Visible = not compact
		mark.Size = if compact then UDim2.fromOffset(34, 34) else UDim2.fromOffset(44, 44)
		head.Size = if compact then UDim2.fromOffset(12, 12) else UDim2.fromOffset(15, 15)
		head.Position = if compact then UDim2.new(0.5, 0, 0, 6) else UDim2.new(0.5, 0, 0, 8)
		shoulders.Size = if compact then UDim2.fromOffset(20, 10) else UDim2.fromOffset(26, 12)
		shoulders.Position = if compact then UDim2.new(0.5, 0, 1, -5) else UDim2.new(0.5, 0, 1, -7)

		title.TextSize = if compact then 19 else Theme.Size.Title
		title.Position = if compact then UDim2.fromOffset(60, 0) else UDim2.fromOffset(72, 12)
		title.Size = if compact
			then UDim2.new(1, -60 - 60, 1, 0)
			else UDim2.new(1, -190, 0, 30)
		title.TextYAlignment = if compact then Enum.TextYAlignment.Center else Enum.TextYAlignment.Top
	end

	applyHeaderSize()

	maid.add(RunService.Heartbeat:Connect(applyHeaderSize))

	local visibilityCallbacks: { (visible: boolean) -> () } = {}

	maid.add(host:GetPropertyChangedSignal("Enabled"):Connect(function()
		for _, callback in visibilityCallbacks do
			pcall(callback, host.Enabled)
		end
	end))

	return {
		host = host,
		root = root,
		content = content,
		titleBar = titleBar,
		setVisible = function(visible: boolean)
			host.Enabled = visible
		end,
		isVisible = function(): boolean
			return host.Enabled
		end,
		onVisibilityChanged = function(callback: (visible: boolean) -> ())
			table.insert(visibilityCallbacks, callback)
		end,
		addTitleControl = addTitleControl,
	}
end

return Window
