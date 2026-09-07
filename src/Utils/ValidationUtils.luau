local ValidationUtils = {}

export type NumberRule = {
	min: number,
	max: number,
	default: number,
	integer: boolean?,
}

function ValidationUtils.number(text: string, rule: NumberRule): (number, string?)
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return rule.default, nil
	end

	local parsed = tonumber(trimmed)
	if parsed == nil then
		return rule.default, string.format("%q is not a number", trimmed)
	end

	if parsed ~= parsed then
		return rule.default, "value is not a number"
	end
	if parsed == math.huge or parsed == -math.huge then
		return rule.default, "value is out of range"
	end

	if rule.integer then
		parsed = math.floor(parsed + 0.5)
	end

	if parsed < rule.min then
		return rule.min, string.format("clamped to minimum %g", rule.min)
	end
	if parsed > rule.max then
		return rule.max, string.format("clamped to maximum %g", rule.max)
	end

	return parsed, nil
end

function ValidationUtils.parseId(text: string): (number?, string?)
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil, "Enter an id."
	end

	local direct = tonumber(trimmed)
	if direct and direct > 0 and direct == math.floor(direct) then
		return direct, nil
	end

	if string.find(trimmed, "roblox%.com") then

		for _, pattern in { "catalog/(%d+)", "bundles/(%d+)", "library/(%d+)", "item%?id=(%d+)" } do
			local captured = string.match(trimmed, pattern)
			if captured then
				local value = tonumber(captured)
				if value then
					return value, nil
				end
			end
		end
		return nil, "Could not find an id in that URL."
	end

	return nil, "Not a valid id or Roblox URL."
end

function ValidationUtils.isBlank(text: string): boolean
	return string.match(text, "^%s*(.-)%s*$") == ""
end

function ValidationUtils.trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") or ""
end

return ValidationUtils
