--!nonstrict
-- niri event-stream consumer. Builds a ribbon snapshot; UI entries never talk to niri.

local NIRI = "/usr/bin/niri"
local GAP = 6
local watching = false
local haveWorkspaces = false
local haveWindows = false
local dirty = false

local workspaces = {}
local windowsById = {}
local outputs = {}

local EMPTY = {
	backend = "niri",
	ready = false,
	outputs = {},
	workspaces = {},
}

local function asMap(list)
	local map = {}
	if type(list) ~= "table" then
		return map
	end
	for _, item in ipairs(list) do
		if type(item) == "table" and item.id ~= nil then
			map[tostring(item.id)] = item
		end
	end
	return map
end

local function number(value, fallback)
	local n = tonumber(value)
	if n == nil then
		return fallback
	end
	return n
end

local function ingestOutputs(decoded)
	if type(decoded) ~= "table" then
		return
	end
	local nextOutputs = {}
	for name, info in pairs(decoded) do
		if type(info) == "table" then
			local logical = info.logical or info
			nextOutputs[tostring(name)] = {
				name = tostring(name),
				width = number(logical.width, 1920),
				height = number(logical.height, 1080),
			}
		end
	end
	if next(nextOutputs) ~= nil then
		outputs = nextOutputs
	end
end

local function ingestWorkspaces(list)
	if type(list) ~= "table" then
		return
	end
	workspaces = list
	haveWorkspaces = true
end

local function ingestWindows(list)
	windowsById = asMap(list)
	haveWindows = true
end

local function upsertWindow(win)
	if type(win) ~= "table" or win.id == nil then
		return
	end
	windowsById[tostring(win.id)] = win
	haveWindows = true
end

local function removeWindow(id)
	if id == nil then
		return
	end
	windowsById[tostring(id)] = nil
end

local function outputSize(name)
	local out = outputs[tostring(name or "")]
	if out ~= nil then
		return out.width, out.height
	end
	return 1920, 1080
end

local function buildRibbon(ws)
	local screenW, screenH = outputSize(ws.output)
	local columns = {}
	local columnByIndex = {}
	local windowCount = 0

	for _, win in pairs(windowsById) do
		if type(win) == "table" and tonumber(win.workspace_id) == tonumber(ws.id) then
			windowCount = windowCount + 1
			if win.is_floating ~= true then
				local layout = win.layout or {}
				local pos = layout.pos_in_scrolling_layout
				local size = layout.tile_size
				if type(pos) == "table" and type(size) == "table" then
					local colIndex = number(pos[1], 1)
					local tileIndex = number(pos[2], 1)
					local col = columnByIndex[colIndex]
					if col == nil then
						col = { index = colIndex, tiles = {}, w = 0, h = 0, x = 0 }
						columnByIndex[colIndex] = col
						columns[#columns + 1] = col
					end
					local tw = number(size[1], 0)
					local th = number(size[2], 0)
					if tw > col.w then
						col.w = tw
					end
					col.tiles[#col.tiles + 1] = {
						id = tonumber(win.id),
						app_id = tostring(win.app_id or ""),
						title = tostring(win.title or ""),
						tile = tileIndex,
						w = tw,
						h = th,
						x = 0,
						y = 0,
						focused = win.is_focused == true,
						urgent = win.is_urgent == true,
					}
				end
			end
		end
	end

	table.sort(columns, function(a, b)
		return a.index < b.index
	end)

	local x = 0
	local ribbonH = 0
	for _, col in ipairs(columns) do
		table.sort(col.tiles, function(a, b)
			return a.tile < b.tile
		end)
		col.x = x
		local y = 0
		for _, tile in ipairs(col.tiles) do
			tile.x = x
			tile.y = y
			tile.w = col.w
			y = y + tile.h + GAP
		end
		col.h = math.max(0, y - GAP)
		if col.h > ribbonH then
			ribbonH = col.h
		end
		x = x + col.w + GAP
	end

	local ribbonW = math.max(0, x - GAP)
	if ribbonH <= 0 then
		ribbonH = screenH
	end

	local focusTile = nil
	for _, col in ipairs(columns) do
		for _, tile in ipairs(col.tiles) do
			if tile.focused or tonumber(tile.id) == tonumber(ws.active_window_id) then
				focusTile = tile
				break
			end
		end
		if focusTile ~= nil then
			break
		end
	end

	local viewportW = screenW
	local viewportX = 0
	if focusTile ~= nil then
		viewportX = focusTile.x + focusTile.w * 0.5 - viewportW * 0.5
	end
	local maxX = math.max(0, ribbonW - viewportW)
	if viewportX < 0 then
		viewportX = 0
	elseif viewportX > maxX then
		viewportX = maxX
	end

	return {
		id = tonumber(ws.id),
		idx = tonumber(ws.idx) or 0,
		name = ws.name,
		output = tostring(ws.output or ""),
		active = ws.is_active == true,
		focused = ws.is_focused == true,
		urgent = ws.is_urgent == true,
		window_count = windowCount,
		ribbon_w = ribbonW,
		ribbon_h = ribbonH,
		viewport_x = viewportX,
		viewport_w = viewportW,
		viewport_h = screenH,
		screen_w = screenW,
		screen_h = screenH,
		columns = columns,
	}
end

local function publish()
	if not haveWorkspaces then
		noctalia.state.set("snapshot", EMPTY)
		return
	end

	local list = {}
	for _, ws in ipairs(workspaces) do
		if type(ws) == "table" then
			list[#list + 1] = buildRibbon(ws)
		end
	end
	table.sort(list, function(a, b)
		if a.output ~= b.output then
			return a.output < b.output
		end
		return a.idx < b.idx
	end)

	noctalia.state.set("snapshot", {
		backend = "niri",
		ready = true,
		outputs = outputs,
		workspaces = list,
	})
end

local function markDirty()
	dirty = true
end

local function handleEvent(decoded)
	if type(decoded) ~= "table" then
		return
	end
	if decoded.WorkspacesChanged ~= nil then
		ingestWorkspaces(decoded.WorkspacesChanged.workspaces)
		markDirty()
	elseif decoded.WindowsChanged ~= nil then
		ingestWindows(decoded.WindowsChanged.windows)
		markDirty()
	elseif decoded.WindowOpenedOrChanged ~= nil then
		local win = decoded.WindowOpenedOrChanged.window
		-- Ignore title-only chatter from terminals; still apply layout/focus.
		upsertWindow(win)
		markDirty()
	elseif decoded.WindowClosed ~= nil then
		removeWindow(decoded.WindowClosed.id)
		markDirty()
	elseif decoded.WindowLayoutsChanged ~= nil then
		local changes = decoded.WindowLayoutsChanged.changes or decoded.WindowLayoutsChanged
		if type(changes) == "table" then
			for _, change in ipairs(changes) do
				if type(change) == "table" then
					local id = change[1] or change.id
					local layout = change[2] or change.layout
					if id ~= nil and windowsById[tostring(id)] ~= nil and type(layout) == "table" then
						windowsById[tostring(id)].layout = layout
					end
				end
			end
		end
		markDirty()
	elseif decoded.WorkspaceActivated ~= nil then
		local id = decoded.WorkspaceActivated.id
		local focused = decoded.WorkspaceActivated.focused == true
		local outputName = nil
		for _, ws in ipairs(workspaces) do
			if tonumber(ws.id) == tonumber(id) then
				outputName = ws.output
				break
			end
		end
		for _, ws in ipairs(workspaces) do
			if tonumber(ws.id) == tonumber(id) then
				ws.is_active = true
				if focused then
					ws.is_focused = true
				end
			else
				if outputName ~= nil and tostring(ws.output) == tostring(outputName) then
					ws.is_active = false
				end
				if focused then
					ws.is_focused = false
				end
			end
		end
		markDirty()
	elseif decoded.WindowFocusChanged ~= nil then
		local id = decoded.WindowFocusChanged.id
		for _, win in pairs(windowsById) do
			win.is_focused = tonumber(win.id) == tonumber(id)
		end
		markDirty()
	elseif decoded.WorkspaceUrgencyChanged ~= nil then
		local id = decoded.WorkspaceUrgencyChanged.id
		local urgent = decoded.WorkspaceUrgencyChanged.urgent == true
		for _, ws in ipairs(workspaces) do
			if tonumber(ws.id) == tonumber(id) then
				ws.is_urgent = urgent
			end
		end
		markDirty()
	end
end

local function startWatch()
	if watching then
		return
	end
	if not noctalia.commandExists("niri") then
		noctalia.state.set("snapshot", EMPTY)
		return
	end
	noctalia.runAsync(NIRI .. " msg --json outputs", function(result)
		if result ~= nil and result.exitCode == 0 then
			ingestOutputs(noctalia.json.decode(result.stdout or ""))
			markDirty()
		end
	end)
	local ok = noctalia.runStream(NIRI .. " msg --json event-stream", function(line)
		local text = noctalia.string.trim(tostring(line or ""))
		if text == "" then
			return
		end
		local decoded = noctalia.json.decode(text)
		if decoded == nil then
			return
		end
		handleEvent(decoded)
	end)
	watching = ok == true
	if not watching then
		noctalia.state.set("snapshot", EMPTY)
	end
end

function update()
	noctalia.setUpdateInterval(80)
	if dirty then
		dirty = false
		publish()
	end
end

function onExit(_signal, _reason)
	watching = false
end

noctalia.state.set("snapshot", EMPTY)
noctalia.setUpdateInterval(80)
startWatch()
