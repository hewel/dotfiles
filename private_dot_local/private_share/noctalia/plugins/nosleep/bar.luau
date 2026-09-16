--!nonstrict
-- Right-click toggles nosleep (block suspend) / sleepok (allow suspend).

local active = noctalia.state.get("active") == true
local agents = noctalia.state.get("agents")

local function agentList()
	if type(agents) ~= "table" then
		return ""
	end
	local parts = {}
	for _, name in ipairs(agents) do
		parts[#parts + 1] = tostring(name)
	end
	return table.concat(parts, "\n")
end

local function render()
	local color = active and "tertiary" or "on_surface_variant"
	local glyph = ui.glyph({
		name = active and "zzz-off" or "zzz",
		size = 14,
		color = color,
	})
	local container = barWidget.isVertical() and ui.column or ui.row
	barWidget.render(container({ gap = 4, align = "center" }, { glyph }))
	local rows = {
		{
			key = noctalia.tr("ui.title"),
			value = active and noctalia.tr("ui.blocked") or noctalia.tr("ui.allowed"),
		},
		{
			key = noctalia.tr("ui.hint"),
			value = noctalia.tr("ui.hint_value"),
		},
	}
	local listed = agentList()
	if listed ~= "" then
		rows[#rows + 1] = {
			key = noctalia.tr("ui.agents"),
			value = listed,
		}
	end
	barWidget.setTooltip(rows)
end

local function toggle()
	noctalia.state.set("nosleep_toggle", true)
end

function onClick()
	toggle()
end

function onRightClick()
	toggle()
end

noctalia.state.watch("active", function(value)
	active = value == true
	render()
end)

noctalia.state.watch("agents", function(value)
	if type(value) == "table" then
		agents = value
	else
		agents = {}
	end
	render()
end)

render()
