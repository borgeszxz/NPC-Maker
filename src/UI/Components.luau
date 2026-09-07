local Theme = require(script.Parent.Theme)
local Maid = require(script.Parent.Parent.Utils.Maid)

local Components = {}

local Color = Theme.Color
local Modifier = Enum.StudioStyleGuideModifier

local PADDING = 8
local CORNER = UDim.new(0, 4)
local FONT_BODY = Theme.Font.Regular
local FONT_MEDIUM = Theme.Font.Medium
local FONT_BOLD = Theme.Font.Bold
local CHECK_MARK = "\u{2713}"
local CROSS_MARK = "\u{00D7}"
local ARROW_DOWN = "\u{25BC}"
local ARROW_UP = "\u{25B2}"

local activeMaid: Maid.Maid? = nil

function Components.init(maid: Maid.Maid)
	activeMaid = maid
end

local function track<T>(item: T): T
	local maid = activeMaid
	if maid then
		return maid.add(item)
	end
	return item
end

local function nextOrder(parent: Instance): number
	local current = parent:GetAttribute("NPCM_Order")
	local order = (if typeof(current) == "number" then current else 0) + 1
	parent:SetAttribute("NPCM_Order", order)
	return order
end

local function corner(instance: Instance)
	local radius = Instance.new("UICorner")
	radius.CornerRadius = CORNER
	radius.Parent = instance
end

function Components.column(parent: Instance, name: string, gap: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = nextOrder(parent)
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or 4)
	layout.Parent = frame

	return frame
end

function Components.row(parent: Instance, name: string, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.LayoutOrder = nextOrder(parent)
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame

	return frame
end

function Components.sectionTitle(parent: Instance, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "SectionTitle"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = FONT_MEDIUM
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.LayoutOrder = nextOrder(parent)
	label.Parent = parent

	Theme.bind(label, "TextColor3", Color.MainText)
	return label
end

function Components.body(parent: Instance, text: string, dim: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Body"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = FONT_BODY
	label.TextSize = 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = text
	label.LayoutOrder = nextOrder(parent)
	label.Parent = parent

	Theme.bind(label, "TextColor3", if dim then Color.DimmedText else Color.MainText)
	return label
end

export type TextBoxOptions = {
	placeholder: string,
	height: number,
	multiLine: boolean,
	editable: boolean?,
	text: string?,
	monospace: boolean?,
}

function Components.textBox(parent: Instance, options: TextBoxOptions): TextBox
	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.Size = UDim2.new(1, 0, 0, options.height)
	box.ClearTextOnFocus = false
	box.MultiLine = options.multiLine
	box.TextEditable = options.editable ~= false
	box.TextWrapped = options.multiLine
	box.Font = if options.monospace then Enum.Font.Code else FONT_BODY
	box.TextSize = 14
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = if options.multiLine then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center
	box.PlaceholderText = options.placeholder
	box.Text = options.text or ""
	box.LayoutOrder = nextOrder(parent)
	box.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = box

	corner(box)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Parent = box

	Theme.bind(box, "BackgroundColor3", Color.InputFieldBackground)
	Theme.bind(box, "TextColor3", Color.MainText)
	Theme.bind(box, "PlaceholderColor3", Color.DimmedText)
	Theme.bind(stroke, "Color", Color.InputFieldBorder)

	return box
end

export type Button = {
	instance: TextButton,
	setEnabled: (enabled: boolean) -> (),
	setText: (text: string) -> (),
}

function Components.button(
	parent: Instance,
	text: string,
	tone: any,
	onClick: () -> ()
): Button
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AutoButtonColor = false
	button.Size = UDim2.new(0, 0, 1, 0)
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Font = FONT_BOLD
	button.TextSize = 14
	button.Text = text
	button.LayoutOrder = nextOrder(parent)
	button.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button

	corner(button)

	local kind = tone
	if typeof(tone) == "boolean" then
		kind = if tone then "primary" else "neutral"
	end

	local background = Color.Button
	local foreground = Color.ButtonText
	if kind == "primary" then
		background, foreground = Color.DialogMainButton, Color.DialogMainButtonText
	elseif kind == "success" then
		background, foreground = Color.Success, Color.SuccessText
	end

	local enabled = true
	local function paint(modifier: Enum.StudioStyleGuideModifier)
		button.BackgroundColor3 = Theme.color(background, modifier)
		button.TextColor3 = Theme.color(foreground, modifier)
	end

	Theme.bind(button, "BackgroundColor3", background)
	Theme.bind(button, "TextColor3", foreground)

	track(button.MouseEnter:Connect(function()
		if enabled then
			paint(Modifier.Hover)
		end
	end))
	track(button.MouseLeave:Connect(function()
		paint(if enabled then Modifier.Default else Modifier.Disabled)
	end))
	track(button.Activated:Connect(function()
		if not enabled then
			return
		end
		local ok, err = pcall(onClick)
		if not ok then
			warn("[NPC Maker] button handler failed: " .. tostring(err))
		end
	end))

	local function setEnabled(value: boolean)
		enabled = value
		button.Active = value
		button.AutoButtonColor = false
		paint(if value then Modifier.Default else Modifier.Disabled)
	end

	return {
		instance = button,
		setEnabled = setEnabled,
		setText = function(value: string)
			button.Text = value
		end,
	}
end

export type Toggle = {
	setValue: (value: boolean) -> (),
	getValue: () -> boolean,
}

function Components.checkbox(
	parent: Instance,
	text: string,
	initial: boolean,
	onChanged: (value: boolean) -> ()
): Toggle
	local value = initial

	local button = Instance.new("TextButton")
	button.Name = "Checkbox"
	button.BackgroundTransparency = 1
	button.Size = UDim2.new(1, 0, 0, 26)
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = nextOrder(parent)
	button.Parent = parent

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromOffset(18, 18)
	box.Position = UDim2.new(0, 0, 0.5, 0)
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Parent = button
	corner(box)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Parent = box

	local tick = Instance.new("TextLabel")
	tick.BackgroundTransparency = 1
	tick.Size = UDim2.fromScale(1, 1)
	tick.Font = FONT_BOLD
	tick.TextSize = 12
	tick.Text = CHECK_MARK
	tick.Parent = box

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(26, 0)
	label.Size = UDim2.new(1, -26, 1, 0)
	label.Font = FONT_BODY
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = button

	Theme.bind(stroke, "Color", Color.CheckedFieldBorder)
	Theme.bind(label, "TextColor3", Color.MainText)
	Theme.bind(tick, "TextColor3", Color.DialogMainButtonText)

	local function render()
		box.BackgroundColor3 = Theme.color(
			if value then Color.DialogMainButton else Color.CheckedFieldBackground
		)
		tick.Visible = value
	end

	local function setValue(newValue: boolean)
		value = newValue
		render()
	end

	track(button.Activated:Connect(function()
		setValue(not value)
		local ok, err = pcall(onChanged, value)
		if not ok then
			warn("[NPC Maker] checkbox handler failed: " .. tostring(err))
		end
	end))

	render()

	return {
		setValue = setValue,
		getValue = function(): boolean
			return value
		end,
	}
end

export type Segmented = {
	setValue: (value: string) -> (),
	getValue: () -> string,
}

export type SegmentItem = {
	id: string,
	label: string,
}

function Components.segmented(
	parent: Instance,
	items: { SegmentItem },
	initial: string,
	onChanged: (value: string) -> ()
): Segmented
	local current = initial

	local frame = Instance.new("Frame")
	frame.Name = "Segmented"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 26)
	frame.LayoutOrder = nextOrder(parent)
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame

	local buttons: { [string]: TextButton } = {}

	local function render()
		for id, button in pairs(buttons) do
			local selected = id == current
			button.BackgroundColor3 = Theme.color(
				if selected then Color.DialogMainButton else Color.Button
			)
			button.TextColor3 = Theme.color(
				if selected then Color.DialogMainButtonText else Color.ButtonText
			)
		end
	end

	for position, item in items do
		local button = Instance.new("TextButton")
		button.Name = item.id
		button.AutoButtonColor = false
		button.Size = UDim2.new(1 / #items, -4, 1, 0)
		button.Font = FONT_MEDIUM
		button.TextSize = 13
		button.Text = item.label
		button.LayoutOrder = position
		button.Parent = frame
		corner(button)

		buttons[item.id] = button

		track(button.Activated:Connect(function()
			current = item.id
			render()
			local ok, err = pcall(onChanged, current)
			if not ok then
				warn("[NPC Maker] segment handler failed: " .. tostring(err))
			end
		end))
	end

	render()

	return {
		setValue = function(value: string)
			current = value
			render()
		end,
		getValue = function(): string
			return current
		end,
	}
end

function Components.divider(parent: Instance)
	local line = Instance.new("Frame")
	line.Name = "Divider"
	line.BorderSizePixel = 0
	line.Size = UDim2.new(1, 0, 0, 1)
	line.LayoutOrder = nextOrder(parent)
	line.Parent = parent
	Theme.bind(line, "BackgroundColor3", Color.Border)
end

function Components.spacer(parent: Instance, height: number)
	local space = Instance.new("Frame")
	space.Name = "Spacer"
	space.BackgroundTransparency = 1
	space.Size = UDim2.new(1, 0, 0, height)
	space.LayoutOrder = nextOrder(parent)
	space.Parent = parent
end

export type Tabs = {
	setValue: (value: string) -> (),
	getValue: () -> string,
}

function Components.tabs(
	parent: Instance,
	items: { SegmentItem },
	initial: string,
	onChanged: (value: string) -> ()
): Tabs
	local current = initial

	local frame = Instance.new("Frame")
	frame.Name = "Tabs"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 30)
	frame.LayoutOrder = nextOrder(parent)
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame

	local buttons: { [string]: TextButton } = {}
	local underlines: { [string]: Frame } = {}

	local function render()
		for id, button in pairs(buttons) do
			local selected = id == current
			button.BackgroundColor3 = Theme.color(if selected then Color.DialogMainButton else Color.Button)
			button.TextColor3 = Theme.color(if selected then Color.DialogMainButtonText else Color.ButtonText)
			local underline = underlines[id]
			if underline then
				underline.Visible = selected
			end
		end
	end

	for position, item in items do
		local button = Instance.new("TextButton")
		button.Name = item.id
		button.AutoButtonColor = false
		button.Size = UDim2.new(1 / #items, -4, 1, 0)
		button.Font = FONT_BOLD
		button.TextSize = 15
		button.Text = item.label
		button.LayoutOrder = position
		button.Parent = frame
		corner(button)

		buttons[item.id] = button

		track(button.Activated:Connect(function()
			if current == item.id then
				return
			end
			current = item.id
			render()
			local ok, err = pcall(onChanged, current)
			if not ok then
				warn("[NPC Maker] tab handler failed: " .. tostring(err))
			end
		end))
	end

	render()

	return {
		setValue = function(value: string)
			current = value
			render()
		end,
		getValue = function(): string
			return current
		end,
	}
end

export type Dropdown = {
	setValue: (value: string) -> (),
	getValue: () -> string,
	close: () -> (),
}

function Components.dropdown(
	parent: Instance,
	options: { SegmentItem },
	initial: string,
	onChanged: (value: string) -> ()
): Dropdown
	local current = initial
	local expanded = false

	local container = Instance.new("Frame")
	container.Name = "Dropdown"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.LayoutOrder = nextOrder(parent)
	container.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = container

	local header = Instance.new("TextButton")
	header.Name = "Header"
	header.AutoButtonColor = false
	header.Size = UDim2.new(1, 0, 0, 36)
	header.Font = FONT_BODY
	header.TextSize = 14
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = 1
	header.Parent = container
	corner(header)

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, 8)
	headerPadding.PaddingRight = UDim.new(0, 8)
	headerPadding.Parent = header

	Theme.bind(header, "BackgroundColor3", Color.Button)
	Theme.bind(header, "TextColor3", Color.ButtonText)

	local list = Instance.new("Frame")
	list.Name = "Options"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.Visible = false
	list.LayoutOrder = 2
	list.Parent = container

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = list

	local optionButtons: { [string]: TextButton } = {}

	local function labelFor(id: string): string
		for _, option in options do
			if option.id == id then
				return option.label
			end
		end
		return id
	end

	local function render()
		header.Text = labelFor(current) .. "   " .. (if expanded then ARROW_UP else ARROW_DOWN)
		list.Visible = expanded
		for id, button in pairs(optionButtons) do
			local selected = id == current
			button.BackgroundColor3 = Theme.color(if selected then Color.DialogMainButton else Color.Button)
			button.TextColor3 = Theme.color(if selected then Color.DialogMainButtonText else Color.ButtonText)
		end
	end

	for position, option in options do
		local button = Instance.new("TextButton")
		button.Name = option.id
		button.AutoButtonColor = false
		button.Size = UDim2.new(1, 0, 0, 22)
		button.Font = FONT_BODY
		button.TextSize = 13
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = option.label
		button.LayoutOrder = position
		button.Parent = list
		corner(button)

		local optionPadding = Instance.new("UIPadding")
		optionPadding.PaddingLeft = UDim.new(0, 14)
		optionPadding.Parent = button

		optionButtons[option.id] = button

		track(button.Activated:Connect(function()
			current = option.id
			expanded = false
			render()
			local ok, err = pcall(onChanged, current)
			if not ok then
				warn("[NPC Maker] dropdown handler failed: " .. tostring(err))
			end
		end))
	end

	track(header.Activated:Connect(function()
		expanded = not expanded
		render()
	end))

	render()

	return {
		setValue = function(value: string)
			current = value
			render()
		end,
		getValue = function(): string
			return current
		end,
		close = function()
			expanded = false
			render()
		end,
	}
end

export type CardData = {
	thumbnail: string,
	name: string,
	creator: string,
	typeLabel: string,
	priceLabel: string,
	note: string?,
	supported: boolean,
	actionLabel: string,
}

function Components.card(
	parent: Instance,
	data: CardData,
	onAction: () -> ()
): Frame
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 0, 78)
	card.BorderSizePixel = 0
	card.LayoutOrder = nextOrder(parent)
	card.Parent = parent
	corner(card)
	Theme.bind(card, "BackgroundColor3", Color.Item)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Parent = card
	Theme.bind(stroke, "Color", Color.Border)

	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Name = "Thumbnail"
	thumbnail.Size = UDim2.fromOffset(62, 62)
	thumbnail.Position = UDim2.fromOffset(8, 8)
	thumbnail.BorderSizePixel = 0
	thumbnail.ScaleType = Enum.ScaleType.Fit
	thumbnail.Image = data.thumbnail
	thumbnail.Parent = card
	corner(thumbnail)
	Theme.bind(thumbnail, "BackgroundColor3", Color.InputFieldBackground)

	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromOffset(78, 6)
	info.Size = UDim2.new(1, -86, 1, -12)
	info.Parent = card

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 16)
	name.Font = FONT_MEDIUM
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = data.name
	name.Parent = info
	Theme.bind(name, "TextColor3", Color.MainText)

	local meta = Instance.new("TextLabel")
	meta.BackgroundTransparency = 1
	meta.Position = UDim2.fromOffset(0, 17)
	meta.Size = UDim2.new(1, 0, 0, 14)
	meta.Font = FONT_BODY
	meta.TextSize = 11
	meta.TextXAlignment = Enum.TextXAlignment.Left
	meta.TextTruncate = Enum.TextTruncate.AtEnd
	meta.Text = data.typeLabel .. "  -  " .. data.priceLabel
	meta.Parent = info
	Theme.bind(meta, "TextColor3", Color.DimmedText)

	local creator = Instance.new("TextLabel")
	creator.BackgroundTransparency = 1
	creator.Position = UDim2.fromOffset(0, 31)
	creator.Size = UDim2.new(1, 0, 0, 14)
	creator.Font = FONT_BODY
	creator.TextSize = 11
	creator.TextXAlignment = Enum.TextXAlignment.Left
	creator.TextTruncate = Enum.TextTruncate.AtEnd
	creator.Text = if data.creator ~= "" then "by " .. data.creator else ""
	creator.Parent = info
	Theme.bind(creator, "TextColor3", Color.DimmedText)

	local action = Instance.new("TextButton")
	action.Name = "Action"
	action.AutoButtonColor = false
	action.AnchorPoint = Vector2.new(0, 1)
	action.Position = UDim2.new(0, 0, 1, 0)
	action.Size = UDim2.fromOffset(64, 20)
	action.Font = FONT_BOLD
	action.TextSize = 11
	action.Text = data.actionLabel
	action.Parent = info
	corner(action)

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 70, 1, 0)
	note.Size = UDim2.new(1, -70, 0, 20)
	note.Font = FONT_BODY
	note.TextSize = 11
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextTruncate = Enum.TextTruncate.AtEnd
	note.Text = data.note or ""
	note.Parent = info

	if data.supported then
		Theme.bind(action, "BackgroundColor3", Color.DialogMainButton)
		Theme.bind(action, "TextColor3", Color.DialogMainButtonText)
		Theme.bind(note, "TextColor3", Color.DimmedText)
		track(action.Activated:Connect(function()
			local ok, err = pcall(onAction)
			if not ok then
				warn("[NPC Maker] card action failed: " .. tostring(err))
			end
		end))
	else
		action.Active = false
		action.Text = "N/A"
		Theme.bind(action, "BackgroundColor3", Color.Button, Modifier.Disabled)
		Theme.bind(action, "TextColor3", Color.ButtonText, Modifier.Disabled)
		Theme.bind(note, "TextColor3", Color.WarningText)
	end

	return card
end

function Components.itemRow(
	parent: Instance,
	slot: string,
	itemName: string,
	onRemove: () -> ()
): Frame
	local row = Instance.new("Frame")
	row.Name = "ItemRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 22)
	row.LayoutOrder = nextOrder(parent)
	row.Parent = parent

	local slotLabel = Instance.new("TextLabel")
	slotLabel.BackgroundTransparency = 1
	slotLabel.Size = UDim2.fromOffset(74, 22)
	slotLabel.Font = FONT_MEDIUM
	slotLabel.TextSize = 12
	slotLabel.TextXAlignment = Enum.TextXAlignment.Left
	slotLabel.TextTruncate = Enum.TextTruncate.AtEnd
	slotLabel.Text = slot
	slotLabel.Parent = row
	Theme.bind(slotLabel, "TextColor3", Color.DimmedText)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(78, 0)
	nameLabel.Size = UDim2.new(1, -104, 1, 0)
	nameLabel.Font = FONT_BODY
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = itemName
	nameLabel.Parent = row
	Theme.bind(nameLabel, "TextColor3", Color.MainText)

	local remove = Instance.new("TextButton")
	remove.AutoButtonColor = false
	remove.AnchorPoint = Vector2.new(1, 0.5)
	remove.Position = UDim2.new(1, 0, 0.5, 0)
	remove.Size = UDim2.fromOffset(20, 18)
	remove.Font = FONT_BOLD
	remove.TextSize = 12
	remove.Text = CROSS_MARK
	remove.Parent = row
	corner(remove)
	Theme.bind(remove, "BackgroundColor3", Color.Button)
	Theme.bind(remove, "TextColor3", Color.ErrorText)

	track(remove.Activated:Connect(function()
		local ok, err = pcall(onRemove)
		if not ok then
			warn("[NPC Maker] remove handler failed: " .. tostring(err))
		end
	end))

	return row
end

export type Status = {
	set: (text: string, kind: string) -> (),
	clear: () -> (),
}

function Components.status(parent: Instance): Status
	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = FONT_BODY
	label.TextSize = 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Visible = false
	label.LayoutOrder = nextOrder(parent)
	label.Parent = parent

	local function set(text: string, kind: string)
		label.Text = text
		label.Visible = text ~= ""
		local color = Color.DimmedText
		if kind == "error" then
			color = Color.ErrorText
		elseif kind == "success" then
			color = Color.LinkText
		elseif kind == "warning" then
			color = Color.WarningText
		end
		label.TextColor3 = Theme.color(color)
	end

	return {
		set = set,
		clear = function()
			label.Text = ""
			label.Visible = false
		end,
	}
end

export type Panel = {
	frame: Frame,
	content: ScrollingFrame,
	setTitle: (text: string) -> (),
	setHeading: (text: string) -> (),
	setMode: (mode: string) -> (),
}

local HEADING_HEIGHT = 46

function Components.panel(parent: Instance, index: number, title: string): Panel
	local frame = Instance.new("Frame")
	frame.Name = "Panel" .. tostring(index)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = parent
	Theme.bind(frame, "BackgroundColor3", Color.PanelBackground)

	local radius = Instance.new("UICorner")
	radius.CornerRadius = UDim.new(0, 10)
	radius.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Parent = frame
	Theme.bind(stroke, "Color", Color.Border)

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.BackgroundTransparency = 1
	heading.Position = UDim2.fromOffset(14, 12)
	heading.Size = UDim2.new(1, -28, 0, 26)
	heading.Font = FONT_BOLD
	heading.TextSize = 18
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextTruncate = Enum.TextTruncate.AtEnd
	heading.Text = string.format("%d. %s", index, title)
	heading.Parent = frame
	Theme.bind(heading, "TextColor3", Color.MainText)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(0, HEADING_HEIGHT)
	content.Size = UDim2.new(1, 0, 1, -HEADING_HEIGHT)
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollBarThickness = 4
	content.ScrollBarImageTransparency = 0.4
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 2)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = content

	local function setMode(mode: string)
		if mode == "stack" then
			frame.Size = UDim2.new(1, 0, 0, 0)
			frame.AutomaticSize = Enum.AutomaticSize.Y
			content.ScrollingEnabled = false
			content.AutomaticCanvasSize = Enum.AutomaticSize.None
			content.CanvasSize = UDim2.new()
			content.Size = UDim2.new(1, 0, 0, 0)
			content.AutomaticSize = Enum.AutomaticSize.Y
		else
			frame.AutomaticSize = Enum.AutomaticSize.None
			frame.Size = UDim2.fromScale(1, 1)
			content.AutomaticSize = Enum.AutomaticSize.None
			content.Size = UDim2.new(1, 0, 1, -HEADING_HEIGHT)
			content.AutomaticCanvasSize = Enum.AutomaticSize.Y
			content.ScrollingEnabled = true
		end
	end

	return {
		frame = frame,
		content = content,
		setTitle = function(text: string)
			heading.Text = string.format("%d. %s", index, text)
		end,

		setHeading = function(text: string)
			heading.Text = text
		end,
		setMode = setMode,
	}
end

function Components.pillTabs(
	parent: Instance,
	items: { SegmentItem },
	initial: string,
	onChanged: (value: string) -> ()
): Tabs
	local current = initial

	local frame = Instance.new("Frame")
	frame.Name = "PillTabs"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = frame

	local buttons: { [string]: TextButton } = {}

	local function render()
		for id, button in pairs(buttons) do
			local selected = id == current
			button.BackgroundColor3 = Theme.color(if selected then Color.DialogMainButton else Color.Button)
			button.TextColor3 = Theme.color(if selected then Color.DialogMainButtonText else Color.ButtonText)
		end
	end

	for position, item in items do
		local button = Instance.new("TextButton")
		button.Name = item.id
		button.AutoButtonColor = false
		button.Size = UDim2.fromOffset(132, 34)
		button.Font = FONT_BOLD
		button.TextSize = 15
		button.Text = item.label
		button.LayoutOrder = position
		button.Parent = frame

		local radius = Instance.new("UICorner")
		radius.CornerRadius = UDim.new(0, 8)
		radius.Parent = button

		buttons[item.id] = button

		track(button.Activated:Connect(function()
			if current == item.id then
				return
			end
			current = item.id
			render()
			local ok, err = pcall(onChanged, current)
			if not ok then
				warn("[NPC Maker] pill tab handler failed: " .. tostring(err))
			end
		end))
	end

	render()

	return {
		setValue = function(value: string)
			current = value
			render()
		end,
		getValue = function(): string
			return current
		end,
	}
end

function Components.grid(
	parent: Instance,
	name: string,
	cellWidth: number,
	cellHeight: number
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = nextOrder(parent)
	frame.Parent = parent

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = frame

	return frame
end

function Components.gridCard(
	parent: Instance,
	data: CardData,
	onAction: () -> ()
): Frame
	local card = Instance.new("Frame")
	card.Name = "GridCard"
	card.BorderSizePixel = 0
	card.LayoutOrder = nextOrder(parent)
	card.Parent = parent
	Theme.bind(card, "BackgroundColor3", Color.Item)

	local radius = Instance.new("UICorner")
	radius.CornerRadius = UDim.new(0, 10)
	radius.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Parent = card
	Theme.bind(stroke, "Color", Color.SubtleBorder)

	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Name = "Thumbnail"
	thumbnail.BorderSizePixel = 0
	thumbnail.Position = UDim2.fromOffset(8, 8)
	thumbnail.Size = UDim2.new(1, -16, 1, -66)
	thumbnail.ScaleType = Enum.ScaleType.Fit
	thumbnail.Image = data.thumbnail
	thumbnail.Parent = card
	Theme.bind(thumbnail, "BackgroundColor3", Color.InputFieldBackground)

	local thumbRadius = Instance.new("UICorner")
	thumbRadius.CornerRadius = UDim.new(0, 8)
	thumbRadius.Parent = thumbnail

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0, 1)
	name.Position = UDim2.new(0, 10, 1, -34)
	name.Size = UDim2.new(1, -20, 0, 18)
	name.Font = FONT_MEDIUM
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = data.name
	name.Parent = card
	Theme.bind(name, "TextColor3", Color.MainText)

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.AnchorPoint = Vector2.new(0, 1)
	price.Position = UDim2.new(0, 10, 1, -10)
	price.Size = UDim2.new(1, -56, 0, 20)
	price.Font = FONT_BODY
	price.TextSize = 12
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.TextTruncate = Enum.TextTruncate.AtEnd
	price.Text = data.priceLabel
	price.Parent = card
	Theme.bind(price, "TextColor3", Color.DimmedText)

	local action = Instance.new("TextButton")
	action.Name = "Action"
	action.AutoButtonColor = false
	action.AnchorPoint = Vector2.new(1, 1)
	action.Position = UDim2.new(1, -10, 1, -8)
	action.Size = UDim2.fromOffset(30, 30)
	action.Font = FONT_BOLD
	action.TextSize = 20
	action.Text = data.actionLabel
	action.Parent = card

	local actionRadius = Instance.new("UICorner")
	actionRadius.CornerRadius = UDim.new(1, 0)
	actionRadius.Parent = action

	if data.supported then
		Theme.bind(action, "BackgroundColor3", Color.DialogMainButton)
		Theme.bind(action, "TextColor3", Color.DialogMainButtonText)
		track(action.MouseEnter:Connect(function()
			action.BackgroundColor3 = Theme.color(Color.DialogMainButton, Modifier.Hover)
			stroke.Color = Theme.color(Color.Accent)
		end))
		track(action.MouseLeave:Connect(function()
			action.BackgroundColor3 = Theme.color(Color.DialogMainButton)
			stroke.Color = Theme.color(Color.SubtleBorder)
		end))
		track(action.Activated:Connect(function()
			local ok, err = pcall(onAction)
			if not ok then
				warn("[NPC Maker] card action failed: " .. tostring(err))
			end
		end))
		if data.note then
			price.Text = data.note
		end
	else
		action.Active = false
		action.Text = "-"
		Theme.bind(action, "BackgroundColor3", Color.Button, Modifier.Disabled)
		Theme.bind(action, "TextColor3", Color.ButtonText, Modifier.Disabled)
		price.Text = data.note or "Cannot be applied"
		Theme.bind(price, "TextColor3", Color.WarningText)
	end

	return card
end

function Components.labelledRow(parent: Instance, label: string, labelWidth: number): Frame
	local row = Instance.new("Frame")
	row.Name = "LabelledRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = nextOrder(parent)
	row.Parent = parent

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromOffset(labelWidth, 36)
	text.Font = FONT_MEDIUM
	text.TextSize = 13
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = label
	text.Parent = row
	Theme.bind(text, "TextColor3", Color.MainText)

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(labelWidth + 6, 0)
	holder.Size = UDim2.new(1, -labelWidth - 6, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	return holder
end

export type FieldOptions = {
	label: string,
	text: string,
	placeholder: string?,
	labelWidth: number?,
}

function Components.field(parent: Instance, options: FieldOptions): TextBox
	local row = Instance.new("Frame")
	row.Name = "Field"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 36)
	row.LayoutOrder = nextOrder(parent)
	row.Parent = parent

	local width = options.labelWidth or 96

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(width, 36)
	label.Font = FONT_MEDIUM
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = options.label
	label.Parent = row
	Theme.bind(label, "TextColor3", Color.MainText)

	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.Position = UDim2.fromOffset(width + 6, 0)
	box.Size = UDim2.new(1, -width - 6, 1, 0)
	box.ClearTextOnFocus = false
	box.MultiLine = false
	box.Font = FONT_BODY
	box.TextSize = 14
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.PlaceholderText = options.placeholder or ""
	box.Text = options.text
	box.Parent = row

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = box

	corner(box)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Parent = box

	Theme.bind(box, "BackgroundColor3", Color.InputFieldBackground)
	Theme.bind(box, "TextColor3", Color.MainText)
	Theme.bind(box, "PlaceholderColor3", Color.DimmedText)
	Theme.bind(stroke, "Color", Color.InputFieldBorder)

	return box
end

function Components.iconButton(
	parent: Instance,
	glyph: string,
	size: number,
	onClick: () -> ()
): TextButton
	local button = Instance.new("TextButton")
	button.Name = "IconButton"
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(size, size)
	button.Font = FONT_BOLD
	button.TextSize = math.floor(size * 0.5)
	button.Text = glyph
	button.LayoutOrder = nextOrder(parent)
	button.Parent = parent
	corner(button)

	Theme.bind(button, "BackgroundColor3", Color.Button)
	Theme.bind(button, "TextColor3", Color.ButtonText)

	track(button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.color(Color.Button, Modifier.Hover)
	end))
	track(button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.color(Color.Button)
	end))
	track(button.Activated:Connect(function()
		local ok, err = pcall(onClick)
		if not ok then
			warn("[NPC Maker] icon button handler failed: " .. tostring(err))
		end
	end))

	return button
end

function Components.wideButton(
	parent: Instance,
	text: string,
	tone: string,
	onClick: () -> (),
	height: number?,
	textSize: number?
): Button
	local holder = Instance.new("Frame")
	holder.Name = "WideButtonRow"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, height or 44)
	holder.LayoutOrder = nextOrder(parent)
	holder.Parent = parent

	local button = Components.button(holder, text, tone, onClick)
	button.instance.Size = UDim2.new(1, 0, 1, 0)
	button.instance.AutomaticSize = Enum.AutomaticSize.None
	button.instance.TextSize = textSize or 16
	return button
end

Components.PADDING = PADDING

return Components
