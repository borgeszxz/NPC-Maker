local Maid = require(script.Parent.Parent.Utils.Maid)
local ValidationUtils = require(script.Parent.Parent.Utils.ValidationUtils)
local Settings = require(script.Parent.Parent.Modules.Settings)
local AvatarService = require(script.Parent.Parent.Modules.AvatarService)
local DescriptionBuilder = require(script.Parent.Parent.Modules.DescriptionBuilder)
local MarketplaceItemAdapter = require(script.Parent.Parent.Modules.MarketplaceItemAdapter)

local Components = require(script.Parent.Components)
local MarketplacePanel = require(script.Parent.MarketplacePanel)

local AvatarPanel = {}

local MODES: { Components.SegmentItem } = {
	{ id = "Player", label = "Player" },
	{ id = "Marketplace", label = "Marketplace" },
	{ id = "Id", label = "Asset ID" },
}

local ID_TYPES: { Components.SegmentItem } = {
	{ id = "Auto", label = "Auto Detect" },
	{ id = "Asset", label = "Asset" },
	{ id = "Bundle", label = "Bundle" },
}

export type Panel = {
	frame: Frame,
	refresh: () -> (),
}

function AvatarPanel.mount(parent: Instance, maid: Maid.Maid): Panel
	local config = Settings.get()

	local frame = Components.column(parent, "AvatarPanel", 8)

	local showPanel: (mode: string) -> ()

	Components.segmented(frame, MODES, config.avatarMode, function(value)
		config.avatarMode = value
		Settings.save()
		showPanel(value)
	end)

	local playerPanel = Components.column(frame, "PlayerPanel", 6)
	local marketplacePanel = Components.column(frame, "MarketplacePanel", 6)
	local idPanel = Components.column(frame, "IdPanel", 6)

	showPanel = function(mode: string)
		playerPanel.Visible = mode == "Player"
		marketplacePanel.Visible = mode == "Marketplace"
		idPanel.Visible = mode == "Id"
	end

	local usernameRow = Components.row(playerPanel, "UsernameRow", 30)
	local usernameBox = Components.textBox(usernameRow, {
		placeholder = "Username or UserId",
		height = 30,
		multiLine = false,
	})
	usernameBox.Size = UDim2.new(1, -104, 0, 30)

	local loadButton: Components.Button
	local playerStatus = Components.status(playerPanel)
	local playerDetails = Components.body(playerPanel, "", true)
	playerDetails.Visible = false

	local pendingDescription: HumanoidDescription? = nil
	local pendingUser: AvatarService.UserResult? = nil
	local loading = false

	local function applyPending()
		local description = pendingDescription
		local user = pendingUser
		if description == nil or user == nil then
			return
		end
		DescriptionBuilder.setBase(description, {
			kind = "Player",
			label = user.username,
			userId = user.userId,
		})
		if ValidationUtils.isBlank(config.npcName) then
			config.npcName = user.username .. "_NPC"
			Settings.save()
		end
	end

	local function loadPlayer()
		if loading then
			return
		end
		local input = ValidationUtils.trim(usernameBox.Text)
		if input == "" then
			playerStatus.set("Enter a username or UserId.", "error")
			return
		end

		loading = true
		loadButton.setEnabled(false)
		loadButton.setText("Loading...")
		playerStatus.set("Loading avatar...", "info")
		playerDetails.Visible = false

		task.spawn(function()
			local user, userErr = AvatarService.resolveUser(input)
			if user == nil then
				loading = false
				loadButton.setEnabled(true)
				loadButton.setText("Load")
				playerStatus.set(userErr or "User not found.", "error")
				return
			end

			local description, descErr = AvatarService.getDescription(user.userId)
			loading = false
			loadButton.setEnabled(true)
			loadButton.setText("Load")

			if description == nil then
				playerStatus.set(descErr or "Could not load avatar.", "error")
				return
			end

			if pendingDescription then
				pendingDescription:Destroy()
			end
			pendingDescription = description
			pendingUser = user

			applyPending()

			playerStatus.set("Avatar loaded successfully.", "success")
			playerDetails.Text = string.format("Username: %s\nUserId: %d", user.username, user.userId)
			playerDetails.Visible = true
		end)
	end

	loadButton = Components.button(usernameRow, "Load", "primary", loadPlayer)

	maid.add(usernameBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			loadPlayer()
		end
	end))

	MarketplacePanel.mount(marketplacePanel, maid)

	local idRow = Components.row(idPanel, "IdRow", 30)
	local idBox = Components.textBox(idRow, {
		placeholder = "123456789 or a roblox.com URL",
		height = 30,
		multiLine = false,
	})
	idBox.Size = UDim2.new(1, -104, 0, 30)

	local idButton: Components.Button
	local idTypeDropdown = Components.dropdown(idPanel, ID_TYPES, "Auto", function() end)
	local idStatus = Components.status(idPanel)
	local idLoading = false

	local function loadFromId()
		if idLoading then
			return
		end
		local id, parseErr = ValidationUtils.parseId(idBox.Text)
		if id == nil then
			idStatus.set(parseErr or "Not a valid id.", "error")
			return
		end

		idLoading = true
		idButton.setEnabled(false)
		idButton.setText("Loading...")
		idStatus.set("Looking up item...", "info")

		task.spawn(function()
			local item, err = MarketplaceItemAdapter.fromId(id, idTypeDropdown.getValue())
			idLoading = false
			idButton.setEnabled(true)
			idButton.setText("Load")

			if item == nil then
				idStatus.set(err or "No catalog item found with that id.", "error")
				return
			end
			if not item.supported then
				idStatus.set(item.reason or "This catalog item cannot be applied by NPC Maker.", "error")
				return
			end

			if item.kind == "bundle" then
				local ok, bundleErr = DescriptionBuilder.applyBundle(item)
				if ok then
					idStatus.set(string.format("Bundle applied: %s", item.name), "success")
				else
					idStatus.set(bundleErr or "Could not apply that bundle.", "error")
				end
				return
			end

			local replaced = DescriptionBuilder.addItem(item)
			if replaced then
				idStatus.set(string.format("%s replaced %s.", item.name, replaced.name), "success")
			else
				idStatus.set(string.format("Added %s to %s.", item.name, item.slot), "success")
			end
		end)
	end

	idButton = Components.button(idRow, "Load", "primary", loadFromId)

	maid.add(idBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			loadFromId()
		end
	end))

	maid.add(function()
		if pendingDescription then
			pendingDescription:Destroy()
			pendingDescription = nil
		end
	end)

	showPanel(config.avatarMode)

	return {
		frame = frame,
		refresh = function()
			showPanel(config.avatarMode)
		end,
	}
end

return AvatarPanel
