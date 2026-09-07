local RunService = game:GetService("RunService")

local Maid = require(script.Parent.Parent.Utils.Maid)
local Settings = require(script.Parent.Parent.Modules.Settings)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Window = require(script.Parent.Window)
local AvatarPanel = require(script.Parent.AvatarPanel)
local PreviewPanel = require(script.Parent.PreviewPanel)
local ConfigPanel = require(script.Parent.ConfigPanel)
local NPCListPanel = require(script.Parent.NPCListPanel)
local CreatePanel = require(script.Parent.CreatePanel)

local MainWidget = {}

local DEFAULT_WIDTH = 1240
local DEFAULT_HEIGHT = 820

local TAB_ROW_HEIGHT = 56
local MARGIN = 14
local GAP = 12

local MIN_PANEL_WIDTH = 320

local BUILDER_FRACTIONS = { 0.37, 0.29, 0.34 }
local CREATE_FRACTIONS = { 0.5, 0.5 }

local PREVIEW_STAGE_TALL = 460
local PREVIEW_STAGE_SHORT = 320

local TABS: { Components.SegmentItem } = {
	{ id = "Avatar", label = "Avatar" },
	{ id = "NPC", label = "NPC" },
	{ id = "Create", label = "Create" },
}

export type Widget = {
	toggle: () -> (),
	isEnabled: () -> boolean,
	onEnabledChanged: (callback: (enabled: boolean) -> ()) -> (),
	createNPC: () -> (),
	createAtCursor: () -> (),
}

type Page = {
	frame: ScrollingFrame,
	layout: UIListLayout,
	holders: { Frame },
	panels: { Components.Panel },
	fractions: { number },
}

local function newPage(parent: Instance, name: string, count: number, fractions: { number }): Page
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
	frame.ScrollBarThickness = 5
	frame.ScrollBarImageTransparency = 0.4
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.ScrollingEnabled = false
	frame.Visible = false
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, GAP)

	local holders: { Frame } = {}
	for index = 1, count do
		local holder = Instance.new("Frame")
		holder.Name = "Column" .. tostring(index)
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = index
		holder.Parent = frame
		holders[index] = holder
	end

	return {
		frame = frame,
		layout = layout,
		holders = holders,
		panels = {},
		fractions = fractions,
	}
end

local function applyPageLayout(page: Page, width: number): boolean
	local count = #page.holders
	local usable = width - MARGIN * 2
	local columns = usable >= MIN_PANEL_WIDTH * count + GAP * (count - 1)

	if columns then
		page.layout.Parent = nil
		page.frame.ScrollingEnabled = false
		page.frame.AutomaticCanvasSize = Enum.AutomaticSize.None
		page.frame.CanvasSize = UDim2.new()

		local totalGap = GAP * (count - 1)
		local x = 0
		for index, holder in page.holders do
			local fraction = page.fractions[index] or (1 / count)
			local holderWidth = (usable - totalGap) * fraction
			holder.AutomaticSize = Enum.AutomaticSize.None
			holder.Position = UDim2.fromOffset(x, 0)
			holder.Size = UDim2.new(0, holderWidth, 1, 0)
			x += holderWidth + GAP
			local panel = page.panels[index]
			if panel then
				panel.setMode("column")
			end
		end
	else
		for index, holder in page.holders do
			holder.Position = UDim2.new()
			holder.Size = UDim2.new(1, 0, 0, 0)
			holder.AutomaticSize = Enum.AutomaticSize.Y
			local panel = page.panels[index]
			if panel then
				panel.setMode("stack")
			end
		end
		page.layout.Parent = page.frame
		page.frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.frame.ScrollingEnabled = true
	end

	return columns
end

function MainWidget.create(hostPlugin: Plugin, maid: Maid.Maid): Widget
	Components.init(maid)
	Theme.start()

	local window = Window.create({
		name = "NPCMaker_Window",
		title = "NPC Maker",
		tagline = "Find an avatar. Customize it. Create an NPC.",
		width = DEFAULT_WIDTH,
		height = DEFAULT_HEIGHT,
	}, maid, hostPlugin)

	local config = Settings.get()

	local tabRow = Instance.new("Frame")
	tabRow.Name = "TabRow"
	tabRow.BackgroundTransparency = 1
	tabRow.Size = UDim2.new(1, 0, 0, TAB_ROW_HEIGHT)
	tabRow.Parent = window.content

	local pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.BackgroundTransparency = 1
	pages.Position = UDim2.fromOffset(MARGIN, TAB_ROW_HEIGHT)
	pages.Size = UDim2.new(1, -MARGIN * 2, 1, -TAB_ROW_HEIGHT - MARGIN)
	pages.Parent = window.content

	local avatarPage = newPage(pages, "AvatarPage", 3, BUILDER_FRACTIONS)
	local avatarCard = Components.panel(avatarPage.holders[1], 1, "Choose Avatar")
	local previewCard = Components.panel(avatarPage.holders[2], 2, "Preview")
	local configCard = Components.panel(avatarPage.holders[3], 3, "Configure NPC")
	avatarPage.panels = { avatarCard, previewCard, configCard }

	local avatarPanel = AvatarPanel.mount(avatarCard.content, maid)
	local configPanel = ConfigPanel.mount(configCard.content, maid, hostPlugin)
	local previewPanel = PreviewPanel.mount(previewCard.content, maid, function()
		configPanel.setStatus("Avatar locked in. Configure it and press Create NPC.", "success")
	end, PREVIEW_STAGE_TALL)

	local npcPage = newPage(pages, "NPCPage", 1, { 1 })
	local npcCard = Components.panel(npcPage.holders[1], 1, "Your NPCs")
	npcCard.setHeading("Your NPCs")
	npcPage.panels = { npcCard }
	local npcList = NPCListPanel.mount(npcCard.content, maid)

	local createPage = newPage(pages, "CreatePage", 2, CREATE_FRACTIONS)
	local identityCard = Components.panel(createPage.holders[1], 1, "Identity & Presets")
	identityCard.setHeading("Identity & Presets")
	local actionCard = Components.panel(createPage.holders[2], 2, "Create")
	actionCard.setHeading("Create")
	createPage.panels = { identityCard, actionCard }
	local createPanel = CreatePanel.mount(identityCard.content, actionCard.content, maid, configPanel)

	local allPages: { [string]: Page } = {
		Avatar = avatarPage,
		NPC = npcPage,
		Create = createPage,
	}

	local lastWidth = -1
	local lastTab = ""

	local function applyLayout(force: boolean?)
		local width = pages.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local page = allPages[config.tab]
		if page == nil then
			return
		end
		if not force and width == lastWidth and config.tab == lastTab then
			return
		end
		lastWidth = width
		lastTab = config.tab

		local columns = applyPageLayout(page, width + MARGIN * 2)

		if page == avatarPage then

			previewPanel.setStageHeight(if columns then PREVIEW_STAGE_TALL else PREVIEW_STAGE_SHORT)
		end
	end

	local function showTab(id: string)
		for name, page in allPages do
			page.frame.Visible = name == id
		end
		applyLayout(true)

		if id == "Avatar" then
			avatarPanel.refresh()
			previewPanel.refresh()
			configPanel.refresh()
		elseif id == "NPC" then
			npcList.refresh()
		else
			configPanel.readFields()
			createPanel.refresh()
		end
	end

	if allPages[config.tab] == nil then
		config.tab = "Avatar"
	end

	Components.init(maid)
	local tabs = Components.pillTabs(tabRow, TABS, config.tab, function(value)
		config.tab = value
		Settings.save()
		showTab(value)
	end)

	showTab(config.tab)

	maid.add(RunService.Heartbeat:Connect(function()
		applyLayout(false)
	end))

	window.addTitleControl("*", "Identity, presets and advanced options", function()
		config.tab = "Create"
		Settings.save()
		tabs.setValue("Create")
		showTab("Create")
	end, 1)

	return {
		toggle = function()
			window.setVisible(not window.isVisible())
		end,
		isEnabled = window.isVisible,
		onEnabledChanged = window.onVisibilityChanged,
		createNPC = function()
			configPanel.createNPC()
		end,
		createAtCursor = function()
			configPanel.createAtCursor()
		end,
	}
end

return MainWidget
