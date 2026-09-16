--!nonstrict
-- Watches niri outputs and toggles the configured secondary connector.

local NIRI = "niri"
local busy = false
local snapshot = {
	ready = false,
	present = false,
	enabled = false,
	enabled_count = 0,
}

local function shQuote(value)
	return "'" .. string.gsub(tostring(value), "'", "'\\''") .. "'"
end

local function targetName()
	local value = noctalia.string.trim(tostring(noctalia.getConfig("output") or "HDMI-A-1"))
	if value == "" then
		return "HDMI-A-1"
	end
	return value
end

local function shouldNotify()
	return noctalia.getConfig("notify") ~= false
end

local function niriBin()
	if noctalia.commandExists("niri") then
		return NIRI
	end
	return nil
end

local function publish(next)
	snapshot = next
	noctalia.state.set("snapshot", next)
end

local function outputEnabled(info)
	if type(info) ~= "table" then
		return false
	end
	return info.current_mode ~= nil
end

local function matchesTarget(name, info, target)
	if string.lower(tostring(name or "")) == string.lower(target) then
		return true
	end
	if type(info) == "table" then
		return string.lower(tostring(info.name or "")) == string.lower(target)
	end
	return false
end

local function parseOutputs(decoded, target)
	local present = false
	local enabled = false
	local enabledCount = 0
	if type(decoded) ~= "table" then
		return present, enabled, enabledCount
	end
	for name, info in pairs(decoded) do
		if type(info) == "table" then
			local on = outputEnabled(info)
			if on then
				enabledCount = enabledCount + 1
			end
			if matchesTarget(name, info, target) then
				present = true
				enabled = on
			end
		end
	end
	return present, enabled, enabledCount
end

local function probe()
	local bin = niriBin()
	if bin == nil then
		publish({
			ready = false,
			present = false,
			enabled = false,
			enabled_count = 0,
		})
		return
	end
	local target = targetName()
	noctalia.runAsync(bin .. " msg --json outputs", function(result)
		if result == nil or result.exitCode ~= 0 then
			publish({
				ready = false,
				present = false,
				enabled = false,
				enabled_count = 0,
			})
			return
		end
		local present, enabled, enabledCount = parseOutputs(noctalia.json.decode(result.stdout or ""), target)
		publish({
			ready = true,
			present = present,
			enabled = enabled,
			enabled_count = enabledCount,
			output = target,
		})
	end, 3000)
end

local function notify(kind, key)
	if not shouldNotify() then
		return
	end
	local title = noctalia.tr("ui.title")
	local body = noctalia.tr(key)
	if kind == "error" then
		noctalia.notifyError(title, body)
		return
	end
	noctalia.notify(title, body)
end

local function apply(action)
	if busy then
		return
	end
	local bin = niriBin()
	if bin == nil then
		notify("error", "ui.err_niri")
		return
	end
	if snapshot.present ~= true then
		notify("error", "ui.err_missing")
		return
	end

	local wantOn = snapshot.enabled ~= true
	if action == "on" then
		wantOn = true
	elseif action == "off" then
		wantOn = false
	end
	if wantOn == (snapshot.enabled == true) then
		return
	end
	if (not wantOn) and (tonumber(snapshot.enabled_count) or 0) <= 1 then
		notify("error", "ui.err_last")
		return
	end

	busy = true
	local flag = wantOn and "on" or "off"
	noctalia.runAsync(bin .. " msg output " .. shQuote(targetName()) .. " " .. flag, function(result)
		busy = false
		if result == nil or result.exitCode ~= 0 then
			notify("error", "ui.err_failed")
			probe()
			return
		end
		if wantOn then
			notify("ok", "ui.notify_on")
		else
			notify("ok", "ui.notify_off")
		end
		probe()
	end, 5000)
end

function update()
	noctalia.setUpdateInterval(2000)
	probe()
end

function onOutputsChanged()
	probe()
end

function onConfigChanged()
	probe()
end

function onIpc(event, _payload)
	local ev = string.lower(noctalia.string.trim(tostring(event or "")))
	if ev == "toggle" or ev == "click" then
		apply("toggle")
	elseif ev == "off" then
		apply("off")
	elseif ev == "on" then
		apply("on")
	elseif ev == "refresh" or ev == "probe" then
		probe()
	end
end

noctalia.state.watch("command", function(value)
	if type(value) ~= "string" or value == "" then
		return
	end
	noctalia.state.set("command", "")
	apply(value)
end)

publish(snapshot)
probe()
