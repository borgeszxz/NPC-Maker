local VERSION = "1.1.0"

local root = script.Parent :: Instance
local Utils = root:WaitForChild("Utils")
local Modules = root:WaitForChild("Modules")
local UI = root:WaitForChild("UI")

local Maid = require(Utils:WaitForChild("Maid"))
local Settings = require(Modules:WaitForChild("Settings"))
local Theme = require(UI:WaitForChild("Theme"))
local MainWidget = require(UI:WaitForChild("MainWidget"))

local toolbar = plugin:CreateToolbar("NPC Maker")
local button = toolbar:CreateButton(
	"NPCMakerToggle",
	"Build NPCs from player avatars, marketplace items or asset ids",
	"",
	"NPC Maker"
)
button.ClickableWhenViewportHidden = true

Settings.init(plugin)

local maid = Maid.new()

local ok, widgetOrError = pcall(function()
	return MainWidget.create(plugin, maid)
end)

if not ok then
	maid.destroy()
	Theme.destroy()
	warn("[NPC Maker] failed to start: " .. tostring(widgetOrError))
	return
end

local widget = widgetOrError :: any

button:SetActive(widget.isEnabled())
widget.onEnabledChanged(function(enabled: boolean)
	button:SetActive(enabled)
end)

maid.add(button.Click:Connect(function()
	widget.toggle()
	button:SetActive(widget.isEnabled())
end))

local cursorAction = plugin:CreatePluginAction(
	"NPCMaker_CreateAtCursor",
	"Create NPC at cursor",
	"Creates an NPC with the current NPC Maker settings at the mouse position in the viewport.",
	"",
	true
)
maid.add(cursorAction.Triggered:Connect(function()
	widget.createAtCursor()
end))

local createAction = plugin:CreatePluginAction(
	"NPCMaker_Create",
	"Create NPC",
	"Creates an NPC with the current NPC Maker settings and spawn mode.",
	"",
	true
)
maid.add(createAction.Triggered:Connect(function()
	widget.createNPC()
end))

local toggleAction = plugin:CreatePluginAction(
	"NPCMaker_Toggle",
	"Toggle NPC Maker window",
	"Shows or hides the NPC Maker window.",
	"",
	true
)
maid.add(toggleAction.Triggered:Connect(function()
	widget.toggle()
	button:SetActive(widget.isEnabled())
end))

plugin.Unloading:Connect(function()
	maid.destroy()
	Theme.destroy()
end)

print(string.format("[NPC Maker] v%s loaded", VERSION))
