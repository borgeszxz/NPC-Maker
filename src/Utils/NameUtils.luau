local NameUtils = {}

local FALLBACK = "NPC"
local MAX_LENGTH = 60

function NameUtils.sanitize(name: string): string
	local cleaned = string.gsub(name, "[%c]", "")
	cleaned = string.gsub(cleaned, "%s+", " ")
	cleaned = string.match(cleaned, "^%s*(.-)%s*$") or ""

	if #cleaned > MAX_LENGTH then
		cleaned = string.sub(cleaned, 1, MAX_LENGTH)
	end
	if cleaned == "" then
		return FALLBACK
	end
	return cleaned
end

function NameUtils.defaultName(sourceLabel: string?): string
	if sourceLabel == nil or NameUtils.sanitize(sourceLabel) == FALLBACK then
		return FALLBACK
	end
	return NameUtils.sanitize(sourceLabel) .. "_NPC"
end

function NameUtils.unique(parent: Instance, base: string): string
	local name = NameUtils.sanitize(base)
	if parent:FindFirstChild(name) == nil then
		return name
	end

	local suffix = 2
	while parent:FindFirstChild(name .. "_" .. suffix) ~= nil do
		suffix += 1
		if suffix > 9999 then

			return name .. "_" .. tostring(os.clock()):gsub("%.", "")
		end
	end
	return name .. "_" .. suffix
end

function NameUtils.indexed(base: string, index: number, total: number): string
	local width = math.max(2, #tostring(total))
	return string.format("%s_%0" .. width .. "d", NameUtils.sanitize(base), index)
end

return NameUtils
