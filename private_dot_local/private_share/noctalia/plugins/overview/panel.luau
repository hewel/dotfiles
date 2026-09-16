--!nonstrict
-- Overview panel: every window on this output, scaled to fit with no scrollbar.

local NIRI = "/usr/bin/niri"
local INNER_W = 408
local WS_GAP = 8
local open = false
local snapshot = noctalia.state.get("snapshot")

local function snap()
	if type(snapshot) == "table" then
		return snapshot
	end
	return { ready = false, workspaces = {}, outputs = {} }
end

local function workspacesFor(outputName)
	local all = snap().workspaces or {}
	if outputName == nil or outputName == "" then
		for _, ws in ipairs(all) do
			if ws.focused then
				outputName = ws.output
				break
			end
		end
	end
	local list = {}
	for _, ws in ipairs(all) do
		if outputName == nil or outputName == "" or ws.output == outputName then
			list[#list + 1] = ws
		end
	end
	if #list == 0 then
		return all
	end
	return list
end

local function inViewport(tile, ws)
	local vx = ws.viewport_x or 0
	local vw = ws.viewport_w or ws.screen_w or 0
	return tile.x + tile.w > vx and tile.x < vx + vw
end

local function appFill(tile, visible)
	if tile.focused then
		return "primary"
	end
	if tile.urgent then
		return "error/0.85"
	end
	if not visible then
		return "on_surface/0.22"
	end
	local app = tostring(tile.app_id or "")
	local h = 0
	for i = 1, #app do
		h = (h * 33 + string.byte(app, i)) % 997
	end
	local roles = { "secondary/0.8", "tertiary/0.75", "primary/0.5", "on_surface/0.55" }
	return roles[(h % #roles) + 1]
end

local function run(cmd)
	noctalia.runAsync(cmd)
end

local function focusWorkspace(ws)
	if ws == nil then
		return
	end
	local cmd = NIRI .. " msg action focus-workspace " .. tostring(ws.idx)
	if ws.output ~= nil and ws.output ~= "" then
		cmd = NIRI .. " msg action focus-monitor " .. ws.output .. " ; " .. cmd
	end
	run(cmd)
	panel.close()
end

local function focusWindow(tile, ws)
	if tile ~= nil and tile.id ~= nil then
		run(NIRI .. " msg action focus-window --id " .. tostring(tile.id))
		panel.close()
		return
	end
	focusWorkspace(ws)
end

local function fit(list)
	local screenW = 1920
	local screenH = 1080
	if list[1] ~= nil then
		screenW = math.max(1, list[1].screen_w or screenW)
		screenH = math.max(1, list[1].screen_h or screenH)
	end
	local rowH = INNER_W * screenH / screenW
	if rowH > 168 then
		rowH = 168
	elseif rowH < 72 then
		rowH = 72
	end

	local rows = {}
	for _, ws in ipairs(list) do
		local rw = math.max(1, ws.ribbon_w or 0, ws.screen_w or screenW)
		local rh = math.max(1, ws.ribbon_h or 0, ws.screen_h or screenH)
		local scale = math.min(INNER_W / rw, rowH / rh)
		rows[#rows + 1] = { ws = ws, scale = scale, h = rowH, rw = rw, rh = rh }
	end
	return rows
end

local function ribbon(row)
	local ws = row.ws
	local scale = row.scale
	local cols = {}
	for _, col in ipairs(ws.columns or {}) do
		local tiles = {}
		for _, tile in ipairs(col.tiles or {}) do
			local visible = inViewport(tile, ws)
			tiles[#tiles + 1] = ui.box({
				key = "t-" .. tostring(tile.id),
				width = math.max(2, col.w * scale - 1),
				height = math.max(2, tile.h * scale - 1),
				radius = 3,
				fill = appFill(tile, visible),
				border = tile.focused and "on_primary" or (visible and "outline/0.35" or "outline/0.12"),
				borderWidth = tile.focused and 1.5 or 1,
				onClick = function()
					focusWindow(tile, ws)
				end,
			})
		end
		if #tiles == 0 then
			tiles[1] = ui.box({
				width = math.max(2, col.w * scale),
				height = row.h,
			})
		end
		cols[#cols + 1] = ui.column({ gap = 1 }, tiles)
	end
	if #cols == 0 then
		cols[1] = ui.box({
			width = INNER_W,
			height = row.h,
			radius = 6,
			fill = "surface_variant/0.25",
		})
	end
	return ui.row({
		width = INNER_W,
		height = row.h,
		gap = 1,
		fill = ws.focused and "primary/0.10" or "surface/0.28",
		radius = 8,
		border = ws.focused and "primary" or "outline/0.3",
		borderWidth = ws.focused and 1.5 or 1,
		align = "center",
		onClick = function()
			focusWorkspace(ws)
		end,
	}, cols)
end

local function workspaceBlock(row)
	local ws = row.ws
	local title = tostring(ws.idx)
	if type(ws.name) == "string" and ws.name ~= "" then
		title = title .. " · " .. ws.name
	end
	return ui.column({ key = "ws-" .. tostring(ws.id), gap = 4 }, {
		ui.row({ gap = 8, align = "center" }, {
			ui.label({
				text = title,
				fontWeight = ws.focused and "semibold" or "medium",
				color = ws.focused and "primary" or "on_surface",
			}),
			ui.label({
				text = noctalia.tr("ui.window_count", { count = ws.window_count or 0 }),
				fontSize = 11,
				color = "on_surface_variant",
				flexGrow = 1,
			}),
		}),
		ribbon(row),
	})
end

local function render()
	local outputName = noctalia.state.get("panel_output")
	if type(outputName) ~= "string" then
		outputName = ""
	end
	local list = workspacesFor(outputName)
	local rows = fit(list)
	local blocks = {}
	for _, row in ipairs(rows) do
		blocks[#blocks + 1] = workspaceBlock(row)
	end
	if #blocks == 0 then
		blocks[1] = ui.label({ text = noctalia.tr("ui.empty"), color = "on_surface_variant" })
	end

	panel.render(ui.column({ flexGrow = 1, gap = WS_GAP }, {
		ui.row({ align = "center", justify = "space_between", gap = 8 }, {
			ui.label({
				text = noctalia.tr("ui.title"),
				fontSize = 16,
				fontWeight = "bold",
				color = "on_surface",
				flexGrow = 1,
			}),
			ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = "onCloseClicked" }),
		}),
		ui.scroll({ flexGrow = 1, gap = WS_GAP }, blocks),
	}))
end

function onOpen(_context)
	open = true
	snapshot = noctalia.state.get("snapshot")
	render()
end

function onClose()
	open = false
end

function onCloseClicked()
	panel.close()
end

noctalia.state.watch("snapshot", function(value)
	if type(value) == "table" then
		snapshot = value
		if open then
			render()
		end
	end
end)
