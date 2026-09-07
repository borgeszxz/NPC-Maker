local Selection = game:GetService("Selection")

local Maid = require(script.Parent.Parent.Utils.Maid)
local NPCBuilder = require(script.Parent.Parent.Modules.NPCBuilder)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local NPCListPanel = {}

local Color = Theme.Color
local MAX_ROWS = 200

export type Panel = {
	frame: Frame,
	refresh: () -> (),
}

local function describe(model: Model): string
	local parts: { string } = {}
	for _, key in { "NPCType", "Faction", "Behavior" } do
		local value = model:GetAttribute(key)
		if value ~= nil then
			table.insert(parts, tostring(value))
		end
	end
	if #parts == 0 then
		return model.ClassName
	end
	return table.concat(parts, "  -  ")
end

function NPCListPanel.mount(parent: Instance, maid: Maid.Maid): Panel
	local frame = Components.column(parent, "NPCListPanel", 8)

	local toolbar = Components.row(frame, "Toolbar", 32)
	local countLabel = Components.body(frame, "", true)
	local status = Components.status(frame)
	local list = Components.column(frame, "Rows", 4)

	local rowsMaid: Maid.Maid? = nil
	local refresh: () -> ()

	local function makeRow(model: Model)
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 44)
		row.LayoutOrder = #list:GetChildren()
		row.Parent = list
		Theme.bind(row, "BackgroundColor3", Color.Item)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(12, 4)
		name.Size = UDim2.new(1, -200, 0, 18)
		name.Font = Theme.Font.Medium
		name.TextSize = 14
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = model.Name
		name.Parent = row
		Theme.bind(name, "TextColor3", Color.MainText)

		local meta = Instance.new("TextLabel")
		meta.BackgroundTransparency = 1
		meta.Position = UDim2.fromOffset(12, 22)
		meta.Size = UDim2.new(1, -200, 0, 16)
		meta.Font = Theme.Font.Regular
		meta.TextSize = 12
		meta.TextXAlignment = Enum.TextXAlignment.Left
		meta.TextTruncate = Enum.TextTruncate.AtEnd
		meta.Text = describe(model)
		meta.Parent = row
		Theme.bind(meta, "TextColor3", Color.DimmedText)

		local actions = Instance.new("Frame")
		actions.BackgroundTransparency = 1
		actions.AnchorPoint = Vector2.new(1, 0.5)
		actions.Position = UDim2.new(1, -8, 0.5, 0)
		actions.Size = UDim2.fromOffset(176, 28)
		actions.Parent = row

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = actions

		Components.button(actions, "Select", "neutral", function()
			if model.Parent == nil then
				status.set("That NPC no longer exists.", "warning")
				refresh()
				return
			end
			Selection:Set({ model })
			status.set(string.format("Selected %s.", model.Name), "success")
		end)

		Components.button(actions, "Delete", "neutral", function()
			if model.Parent == nil then
				refresh()
				return
			end
			local label = model.Name
			NPCBuilder.remove({ model })
			status.set(string.format("Deleted %s. Ctrl+Z restores it.", label), "success")
			refresh()
		end)
	end

	refresh = function()
		if rowsMaid then
			rowsMaid.destroy()
		end
		local scoped = Maid.new()
		rowsMaid = scoped
		Components.init(scoped)

		for _, child in list:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		local models = NPCBuilder.findExisting()
		countLabel.Text = if #models == 0
			then "No NPCs in this place yet. Build one from the Avatar tab."
			else string.format("%d NPC%s in this place", #models, if #models == 1 then "" else "s")

		for index, model in models do
			if index > MAX_ROWS then
				Components.body(list, string.format("... and %d more", #models - MAX_ROWS), true)
				break
			end
			makeRow(model)
		end

		Components.init(maid)
	end

	Components.button(toolbar, "Refresh", "neutral", refresh)
	Components.button(toolbar, "Select All", "neutral", function()
		local models = NPCBuilder.findExisting()
		if #models == 0 then
			status.set("Nothing to select.", "warning")
			return
		end
		Selection:Set(models)
		status.set(string.format("Selected %d NPCs.", #models), "success")
	end)
	Components.button(toolbar, "Delete All", "neutral", function()
		local models = NPCBuilder.findExisting()
		if #models == 0 then
			status.set("Nothing to delete.", "warning")
			return
		end
		NPCBuilder.remove(models)
		status.set(string.format("Deleted %d NPCs. Ctrl+Z restores them.", #models), "success")
		refresh()
	end)

	maid.add(function()
		if rowsMaid then
			rowsMaid.destroy()
		end
	end)

	refresh()

	return {
		frame = frame,
		refresh = refresh,
	}
end

return NPCListPanel
