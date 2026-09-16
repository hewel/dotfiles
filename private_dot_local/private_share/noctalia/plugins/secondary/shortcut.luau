--!nonstrict
-- Control-center tile. Active while the secondary niri output is off.

local snapshot = noctalia.state.get("snapshot")

local function snap()
	if type(snapshot) ~= "table" then
		return {
			ready = false,
			present = false,
			enabled = false,
		}
	end
	return snapshot
end

local function render()
	local s = snap()
	local off = s.ready == true and s.present == true and s.enabled ~= true
	if s.ready ~= true then
		shortcut.setLabel(noctalia.tr("ui.unavailable"))
		shortcut.setEnabled(false)
		shortcut.setActive(false)
	elseif s.present ~= true then
		shortcut.setLabel(noctalia.tr("ui.missing"))
		shortcut.setEnabled(false)
		shortcut.setActive(false)
	else
		shortcut.setLabel(off and noctalia.tr("ui.off") or noctalia.tr("ui.on"))
		shortcut.setEnabled(true)
		shortcut.setActive(off)
	end
	shortcut.setIcon("device-desktop-off", "device-desktop")
end

function onClick()
	noctalia.state.set("command", "toggle")
end

function onRightClick()
	noctalia.state.set("command", "on")
end

function onIpc(event, _payload)
	local ev = string.lower(noctalia.string.trim(tostring(event or "")))
	if ev == "toggle" or ev == "click" then
		noctalia.state.set("command", "toggle")
	elseif ev == "off" then
		noctalia.state.set("command", "off")
	elseif ev == "on" then
		noctalia.state.set("command", "on")
	end
end

noctalia.state.watch("snapshot", function(value)
	if type(value) == "table" then
		snapshot = value
		render()
	end
end)

render()
