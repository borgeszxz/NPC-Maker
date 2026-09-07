local Maid = require(script.Parent.Parent.Utils.Maid)
local ValidationUtils = require(script.Parent.Parent.Utils.ValidationUtils)
local Settings = require(script.Parent.Parent.Modules.Settings)
local MarketplaceBrowser = require(script.Parent.Parent.Modules.MarketplaceBrowser)
local MarketplaceItemAdapter = require(script.Parent.Parent.Modules.MarketplaceItemAdapter)
local DescriptionBuilder = require(script.Parent.Parent.Modules.DescriptionBuilder)

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local MarketplacePanel = {}

local PAGE_SIZE = 9
local CELL_WIDTH = 132
local CELL_HEIGHT = 186

export type Panel = {
	frame: Frame,
	refresh: () -> (),
}

local function priceLabel(item: MarketplaceItemAdapter.AdaptedItem): string
	if item.price == nil then
		return "Off sale"
	end
	if item.price == 0 then
		return "Free"
	end
	return string.format("%d Robux", item.price)
end

function MarketplacePanel.mount(parent: Instance, maid: Maid.Maid): Panel
	local config = Settings.get()
	local filters = config.marketplace

	local frame = Components.column(parent, "MarketplacePanel", 8)

	local searchRow = Components.row(frame, "SearchRow", 36)

	local searchBox = Components.textBox(searchRow, {
		placeholder = "Search avatar items...",
		height = 36,
		multiLine = false,
		text = filters.keyword,
	})
	searchBox.Size = UDim2.new(1, -132, 0, 36)

	local searchButton: Components.Button
	local advancedFrame: Frame

	local categoryOptions: { Components.SegmentItem } = {}
	for _, category in MarketplaceBrowser.CATEGORIES do
		table.insert(categoryOptions, { id = category.id, label = category.label })
	end

	local categoryDropdown = Components.dropdown(frame, categoryOptions, filters.category, function(value)
		filters.category = value
		Settings.save()
	end)

	advancedFrame = Components.column(frame, "Advanced", 6)
	advancedFrame.Visible = false

	Components.sectionTitle(advancedFrame, "Sort")
	local sortDropdown = Components.dropdown(advancedFrame, MarketplaceBrowser.SORTS, filters.sort, function(value)
		filters.sort = value
		Settings.save()
	end)

	local priceRow = Components.row(advancedFrame, "PriceRow", 26)
	local minBox = Components.textBox(priceRow, {
		placeholder = "Min price",
		height = 26,
		multiLine = false,
		text = if filters.minPrice > 0 then tostring(filters.minPrice) else "",
	})
	minBox.Size = UDim2.new(0.5, -3, 0, 26)
	local maxBox = Components.textBox(priceRow, {
		placeholder = "Max price",
		height = 26,
		multiLine = false,
		text = if filters.maxPrice > 0 then tostring(filters.maxPrice) else "",
	})
	maxBox.Size = UDim2.new(0.5, -3, 0, 26)

	Components.checkbox(advancedFrame, "Include off sale items", filters.includeOffSale, function(value)
		filters.includeOffSale = value
		Settings.save()
	end)

	local renderResults: () -> ()

	Components.checkbox(advancedFrame, "Hide items that cannot be applied", filters.hideUnsupported, function(value)
		filters.hideUnsupported = value
		Settings.save()
		renderResults()
	end)

	local status = Components.status(frame)

	local pagerRow = Components.row(frame, "Pager", 24)
	local prevButton: Components.Button
	local pageLabel: TextLabel
	local nextButton: Components.Button

	local resultsGrid = Components.grid(frame, "Results", CELL_WIDTH, CELL_HEIGHT)
	local emptyLabel = Components.body(frame, "", true)
	emptyLabel.Visible = false

	local resultsMaid: Maid.Maid? = nil
	local session: MarketplaceBrowser.Session? = nil
	local busy = false
	local displayPage = 1

	local function readFilters()
		filters.keyword = ValidationUtils.trim(searchBox.Text)
		filters.minPrice = (ValidationUtils.number(minBox.Text, { min = 0, max = 1000000, default = 0, integer = true }))
		filters.maxPrice = (ValidationUtils.number(maxBox.Text, { min = 0, max = 1000000, default = 0, integer = true }))
		Settings.save()
	end

	local function visibleItems(): { MarketplaceItemAdapter.AdaptedItem }
		local active = session
		if active == nil then
			return {}
		end

		local items: { MarketplaceItemAdapter.AdaptedItem } = {}
		for _, raw in active.results do
			local item = MarketplaceItemAdapter.adapt(raw)
			if item.supported or not filters.hideUnsupported then
				table.insert(items, item)
			end
		end
		return items
	end

	local function addItem(item: MarketplaceItemAdapter.AdaptedItem)
		if item.kind == "bundle" then
			status.set("Loading bundle...", "info")
			task.spawn(function()
				local ok, err = DescriptionBuilder.applyBundle(item)
				if ok then
					status.set(string.format("Bundle applied: %s", item.name), "success")
				else
					status.set(err or "Could not apply that bundle.", "error")
				end
				renderResults()
			end)
			return
		end

		local replaced = DescriptionBuilder.addItem(item)
		if replaced then
			status.set(string.format("%s replaced %s.", item.name, replaced.name), "success")
		else
			status.set(string.format("Added %s to %s.", item.name, item.slot), "success")
		end
		renderResults()
	end

	renderResults = function()
		if resultsMaid then
			resultsMaid.destroy()
		end
		local scoped = Maid.new()
		resultsMaid = scoped
		Components.init(scoped)

		resultsGrid:SetAttribute("NPCM_Order", 0)
		for _, child in resultsGrid:GetChildren() do
			if not child:IsA("UIGridLayout") then
				child:Destroy()
			end
		end

		local active = session
		local items = visibleItems()
		local totalPages = math.max(1, math.ceil(#items / PAGE_SIZE))
		displayPage = math.clamp(displayPage, 1, totalPages)

		if active == nil then
			pagerRow.Visible = false
			emptyLabel.Visible = false
			Components.init(maid)
			return
		end

		pagerRow.Visible = true

		if #items == 0 then
			emptyLabel.Visible = true
			emptyLabel.Text = if filters.hideUnsupported and #active.results > 0
				then "None of these results can be applied to a character. Turn off the filter in the advanced panel to see them anyway."
				else "No results. Try a different keyword or category."
			pageLabel.Text = "0 items"
			prevButton.setEnabled(false)
			nextButton.setEnabled(not active.isFinished)
			Components.init(maid)
			return
		end

		emptyLabel.Visible = false

		local first = (displayPage - 1) * PAGE_SIZE + 1
		local last = math.min(displayPage * PAGE_SIZE, #items)

		for index = first, last do
			local item = items[index]
			local note: string? = item.reason
			local actionLabel = "+"

			if item.supported then
				if item.kind == "bundle" then
					actionLabel = "+"
					note = "Full look"
				else
					local occupant = DescriptionBuilder.slotOccupant(item.assetTypeName)
					if occupant then
						note = "Replaces " .. occupant.name
					end
				end
			end

			Components.gridCard(resultsGrid, {
				thumbnail = item.thumbnail,
				name = item.name,
				creator = item.creator,
				typeLabel = item.assetTypeName,
				priceLabel = priceLabel(item),
				note = note,
				supported = item.supported,
				actionLabel = actionLabel,
			}, function()
				addItem(item)
			end)
		end

		pageLabel.Text = string.format("Page %d / %d  -  %d items", displayPage, totalPages, #items)
		prevButton.setEnabled(displayPage > 1)
		nextButton.setEnabled(displayPage < totalPages or not active.isFinished)

		Components.init(maid)
	end

	local function runSearch()
		if busy then
			return
		end
		busy = true
		categoryDropdown.close()
		sortDropdown.close()
		readFilters()

		searchButton.setEnabled(false)
		status.set("Searching Marketplace...", "info")

		task.spawn(function()
			local found, err = MarketplaceBrowser.search(filters)
			busy = false
			searchButton.setEnabled(true)

			if found == nil then
				session = nil
				displayPage = 1
				status.set(err or "Marketplace search failed.", "error")
				renderResults()
				return
			end

			session = found
			displayPage = 1
			status.set(string.format("%d results", #found.results), "success")
			renderResults()
		end)
	end

	local function goNext()
		local active = session
		if busy or active == nil then
			return
		end

		local totalPages = math.max(1, math.ceil(#visibleItems() / PAGE_SIZE))
		if displayPage < totalPages then
			displayPage += 1
			renderResults()
			return
		end

		if active.isFinished then
			return
		end

		busy = true
		nextButton.setEnabled(false)
		status.set("Loading more results...", "info")

		task.spawn(function()
			local added, err = MarketplaceBrowser.loadMore(active)
			busy = false

			if err then
				status.set(err, "error")
			elseif added == 0 then
				status.set(string.format("%d results (end of list)", #active.results), "info")
			else
				local pages = math.max(1, math.ceil(#visibleItems() / PAGE_SIZE))
				if displayPage < pages then
					displayPage += 1
				end
				status.set(string.format("%d results loaded", #active.results), "success")
			end
			renderResults()
		end)
	end

	local function goPrev()
		if busy or displayPage <= 1 then
			return
		end
		displayPage -= 1
		renderResults()
	end

	local function clearResults()
		session = nil
		displayPage = 1
		searchBox.Text = ""
		filters.keyword = ""
		Settings.save()
		status.clear()
		renderResults()
	end

	searchButton = Components.button(searchRow, "Search", "primary", runSearch)
	Components.iconButton(searchRow, "=", 36, function()
		advancedFrame.Visible = not advancedFrame.Visible
	end)

	local clearInside = Instance.new("TextButton")
	clearInside.Name = "Clear"
	clearInside.AutoButtonColor = false
	clearInside.BackgroundTransparency = 1
	clearInside.AnchorPoint = Vector2.new(1, 0.5)
	clearInside.Position = UDim2.new(1, 2, 0.5, 0)
	clearInside.Size = UDim2.fromOffset(26, 26)
	clearInside.Font = Theme.Font.Bold
	clearInside.TextSize = 14
	clearInside.Text = "x"
	clearInside.TextColor3 = searchBox.PlaceholderColor3
	clearInside.Parent = searchBox
	maid.add(clearInside.Activated:Connect(clearResults))

	prevButton = Components.button(pagerRow, "<", "neutral", goPrev)

	pageLabel = Instance.new("TextLabel")
	pageLabel.Name = "PageLabel"
	pageLabel.BackgroundTransparency = 1
	pageLabel.Size = UDim2.new(1, -110, 1, 0)
	pageLabel.Font = Theme.Font.Regular
	pageLabel.TextSize = 12
	pageLabel.TextXAlignment = Enum.TextXAlignment.Center
	pageLabel.TextTruncate = Enum.TextTruncate.AtEnd
	pageLabel.Text = ""
	pageLabel.LayoutOrder = 2
	pageLabel.Parent = pagerRow

	pagerRow:SetAttribute("NPCM_Order", 2)
	nextButton = Components.button(pagerRow, ">", "neutral", goNext)
	pagerRow.Visible = false

	maid.add(searchBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			runSearch()
		end
	end))
	maid.add(minBox.FocusLost:Connect(readFilters))
	maid.add(maxBox.FocusLost:Connect(readFilters))

	maid.add(function()
		if resultsMaid then
			resultsMaid.destroy()
		end
	end)

	return {
		frame = frame,
		refresh = renderResults,
	}
end

return MarketplacePanel
