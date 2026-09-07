local Theme = {}

local studio = settings():GetService("Studio") :: any

export type Token = string

Theme.Font = {
	Regular = Enum.Font.BuilderSans,
	Medium = Enum.Font.BuilderSansMedium,
	Bold = Enum.Font.BuilderSansBold,
}

Theme.Size = {
	Title = 26,
	Subtitle = 14,
	Heading = 18,
	Tab = 15,
	Label = 13,
	Input = 14,
	Button = 14,
	Primary = 16,
	CardName = 13,
	Small = 12,
	Tiny = 11,
}

Theme.Color = {
	MainBackground = "MainBackground",
	PanelBackground = "PanelBackground",
	HeaderBackground = "HeaderBackground",
	Item = "Item",
	Button = "Button",
	ButtonText = "ButtonText",
	MainText = "MainText",
	DimmedText = "DimmedText",
	Border = "Border",
	SubtleBorder = "SubtleBorder",
	InputFieldBackground = "InputFieldBackground",
	InputFieldBorder = "InputFieldBorder",
	DialogMainButton = "DialogMainButton",
	DialogMainButtonText = "DialogMainButtonText",
	CheckedFieldBackground = "CheckedFieldBackground",
	CheckedFieldBorder = "CheckedFieldBorder",
	ErrorText = "ErrorText",
	WarningText = "WarningText",
	LinkText = "LinkText",
	Accent = "Accent",
	AccentSoft = "AccentSoft",
	Success = "Success",
	SuccessText = "SuccessText",
	ViewportTop = "ViewportTop",
	ViewportBottom = "ViewportBottom",
}

local DARK: { [string]: Color3 } = {
	MainBackground = Color3.fromRGB(14, 17, 23),
	PanelBackground = Color3.fromRGB(21, 25, 33),
	HeaderBackground = Color3.fromRGB(18, 22, 29),
	Item = Color3.fromRGB(27, 32, 41),
	Button = Color3.fromRGB(34, 40, 51),
	ButtonText = Color3.fromRGB(222, 226, 233),
	MainText = Color3.fromRGB(240, 243, 247),
	DimmedText = Color3.fromRGB(140, 148, 162),
	Border = Color3.fromRGB(41, 48, 60),
	SubtleBorder = Color3.fromRGB(33, 39, 49),
	InputFieldBackground = Color3.fromRGB(18, 22, 29),
	InputFieldBorder = Color3.fromRGB(48, 56, 70),
	DialogMainButton = Color3.fromRGB(28, 100, 242),
	DialogMainButtonText = Color3.fromRGB(255, 255, 255),
	CheckedFieldBackground = Color3.fromRGB(18, 22, 29),
	CheckedFieldBorder = Color3.fromRGB(58, 67, 82),
	ErrorText = Color3.fromRGB(255, 107, 107),
	WarningText = Color3.fromRGB(255, 198, 92),
	LinkText = Color3.fromRGB(74, 222, 128),
	Accent = Color3.fromRGB(28, 100, 242),
	AccentSoft = Color3.fromRGB(30, 46, 78),
	Success = Color3.fromRGB(34, 197, 94),
	SuccessText = Color3.fromRGB(255, 255, 255),
	ViewportTop = Color3.fromRGB(96, 150, 220),
	ViewportBottom = Color3.fromRGB(70, 74, 82),
}

local LIGHT: { [string]: Color3 } = {
	MainBackground = Color3.fromRGB(244, 245, 247),
	PanelBackground = Color3.fromRGB(255, 255, 255),
	HeaderBackground = Color3.fromRGB(255, 255, 255),
	Item = Color3.fromRGB(255, 255, 255),
	Button = Color3.fromRGB(231, 233, 238),
	ButtonText = Color3.fromRGB(42, 46, 55),
	MainText = Color3.fromRGB(20, 22, 26),
	DimmedText = Color3.fromRGB(107, 114, 128),
	Border = Color3.fromRGB(223, 226, 232),
	SubtleBorder = Color3.fromRGB(235, 237, 241),
	InputFieldBackground = Color3.fromRGB(255, 255, 255),
	InputFieldBorder = Color3.fromRGB(214, 218, 225),
	DialogMainButton = Color3.fromRGB(28, 100, 242),
	DialogMainButtonText = Color3.fromRGB(255, 255, 255),
	CheckedFieldBackground = Color3.fromRGB(255, 255, 255),
	CheckedFieldBorder = Color3.fromRGB(199, 204, 213),
	ErrorText = Color3.fromRGB(217, 58, 58),
	WarningText = Color3.fromRGB(183, 121, 31),
	LinkText = Color3.fromRGB(22, 163, 74),
	Accent = Color3.fromRGB(28, 100, 242),
	AccentSoft = Color3.fromRGB(222, 232, 252),
	Success = Color3.fromRGB(22, 163, 74),
	SuccessText = Color3.fromRGB(255, 255, 255),
	ViewportTop = Color3.fromRGB(150, 180, 220),
	ViewportBottom = Color3.fromRGB(206, 216, 232),
}

type Binding = {
	instance: Instance,
	property: string,
	token: string,
	modifier: Enum.StudioStyleGuideModifier,
}

local bindings: { Binding } = {}
local themeConnection: RBXScriptConnection? = nil

function Theme.isDark(): boolean
	local ok, name = pcall(function()
		return studio.Theme.Name
	end)
	if ok and typeof(name) == "string" then
		return name ~= "Light"
	end
	return true
end

local function blend(from: Color3, to: Color3, alpha: number): Color3
	return from:Lerp(to, alpha)
end

local function applyModifier(
	color: Color3,
	modifier: Enum.StudioStyleGuideModifier,
	palette: { [string]: Color3 },
	dark: boolean
): Color3
	if modifier == Enum.StudioStyleGuideModifier.Hover then
		return blend(color, if dark then Color3.new(1, 1, 1) else Color3.new(0, 0, 0), 0.10)
	end
	if modifier == Enum.StudioStyleGuideModifier.Pressed then
		return blend(color, if dark then Color3.new(1, 1, 1) else Color3.new(0, 0, 0), 0.18)
	end
	if modifier == Enum.StudioStyleGuideModifier.Disabled then
		return blend(color, palette.MainBackground, 0.55)
	end
	return color
end

function Theme.color(token: string, modifier: Enum.StudioStyleGuideModifier?): Color3
	local dark = Theme.isDark()
	local palette = if dark then DARK else LIGHT
	local color = palette[token] or palette.MainText
	return applyModifier(color, modifier or Enum.StudioStyleGuideModifier.Default, palette, dark)
end

local function apply(binding: Binding)
	pcall(function()
		(binding.instance :: any)[binding.property] = Theme.color(binding.token, binding.modifier)
	end)
end

function Theme.bind(
	instance: Instance,
	property: string,
	token: string,
	modifier: Enum.StudioStyleGuideModifier?
)
	local binding: Binding = {
		instance = instance,
		property = property,
		token = token,
		modifier = modifier or Enum.StudioStyleGuideModifier.Default,
	}
	table.insert(bindings, binding)
	apply(binding)
end

function Theme.refresh()
	for index = #bindings, 1, -1 do
		local binding = bindings[index]
		if binding.instance.Parent == nil and not binding.instance:IsA("LayerCollector") then

			table.remove(bindings, index)
		else
			apply(binding)
		end
	end
end

function Theme.start()
	if themeConnection then
		return
	end
	themeConnection = studio.ThemeChanged:Connect(function()
		Theme.refresh()
	end)
end

function Theme.destroy()
	if themeConnection then
		themeConnection:Disconnect()
		themeConnection = nil
	end
	table.clear(bindings)
end

return Theme
