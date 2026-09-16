--!nonstrict
-- Polls nosleep.service, herdr panes, and systemd agent-turn inhibitors.
-- working/blocked agents (and grok turns) turn nosleep on; sleepok when they finish if we started it.

local UNIT = "nosleep.service"
local weOwn = false
local busy = false

local function shQuote(value)
	return "'" .. string.gsub(tostring(value), "'", "'\\''") .. "'"
end

local function herdrBin()
	local path = noctalia.expandPath("~/.local/bin/herdr")
	if type(path) == "string" and type(noctalia.fileExists) == "function" and noctalia.fileExists(path) then
		return path
	end
	if noctalia.commandExists("herdr") then
		return "herdr"
	end
	return nil
end

local function ownPath()
	if type(noctalia.pluginDataDir) ~= "function" then
		return nil
	end
	local dir = noctalia.pluginDataDir()
	if type(dir) ~= "string" or dir == "" then
		return nil
	end
	return dir .. "/owned"
end

local function persistOwn()
	local path = ownPath()
	if path == nil then
		return
	end
	if weOwn then
		noctalia.writeFile(path, "1")
	else
		noctalia.removeFile(path)
	end
end

local function loadOwn()
	local path = ownPath()
	if path == nil then
		weOwn = false
		return
	end
	weOwn = type(noctalia.fileExists) == "function" and noctalia.fileExists(path) == true
end

local function publish(active, agents)
	noctalia.state.set("active", active == true)
	noctalia.state.set("agents", agents or {})
	noctalia.state.set("owned", weOwn == true)
end

local function appendUnique(items, name)
	if name == nil or name == "" then
		return
	end
	for _, existing in ipairs(items) do
		if existing == name then
			return
		end
	end
	items[#items + 1] = name
end

local function agentItems(decoded)
	local items = {}
	if type(decoded) ~= "table" then
		return items
	end
	local panes = decoded
	if type(decoded.result) == "table" and type(decoded.result.panes) == "table" then
		panes = decoded.result.panes
	elseif type(decoded.panes) == "table" then
		panes = decoded.panes
	end
	if type(panes) ~= "table" then
		return items
	end
	for _, pane in ipairs(panes) do
		if type(pane) == "table" then
			local status = string.lower(tostring(pane.agent_status or ""))
			if status == "working" or status == "blocked" then
				local agent = noctalia.string.trim(tostring(pane.agent or "herdr"))
				if agent == "" then
					agent = "herdr"
				end
				local title = noctalia.string.trim(tostring(pane.terminal_title_stripped or pane.terminal_title or ""))
				local name = agent
				if title ~= "" then
					name = agent .. " · " .. title
				end
				appendUnique(items, name)
			end
		end
	end
	return items
end

local function appendTurnInhibitors(items, decoded)
	if type(decoded) ~= "table" then
		return
	end
	for _, it in ipairs(decoded) do
		if type(it) == "table" then
			local mode = string.lower(tostring(it.mode or ""))
			local why = string.lower(tostring(it.why or ""))
			if mode == "block" and string.find(why, "agent turn", 1, true) then
				local who = noctalia.string.trim(tostring(it.who or "agent"))
				if who == "" then
					who = "agent"
				end
				appendUnique(items, who .. " · turn")
			end
		end
	end
end

local function runFish(fn, thenFn)
	if busy then
		return
	end
	busy = true
	noctalia.runAsync("fish -c " .. shQuote(fn), function()
		busy = false
		if thenFn then
			thenFn()
		end
	end, 8000)
end

local function probeUnit(agents)
	noctalia.runAsync("systemctl --user is-active " .. UNIT, function(result)
		local out = noctalia.string.trim(tostring(result.stdout or ""))
		local active = result.exitCode == 0 and out == "active"
		local need = #agents > 0
		if need and not active and not busy then
			weOwn = true
			persistOwn()
			publish(true, agents)
			runFish("nosleep", function()
				noctalia.runAsync("systemctl --user is-active " .. UNIT, function(r2)
					local on = r2.exitCode == 0 and noctalia.string.trim(tostring(r2.stdout or "")) == "active"
					publish(on, agents)
				end, 2000)
			end)
			return
		end
		if (not need) and weOwn and active and not busy then
			weOwn = false
			persistOwn()
			runFish("sleepok", function()
				publish(false, agents)
			end)
			return
		end
		if (not need) and weOwn and not active then
			weOwn = false
			persistOwn()
		end
		publish(active, agents)
	end, 2000)
end

local function finishProbe(agents)
	noctalia.runAsync("systemd-inhibit --list --json=short --no-pager", function(result)
		if result.exitCode == 0 then
			appendTurnInhibitors(agents, noctalia.json.decode(result.stdout or ""))
		end
		probeUnit(agents)
	end, 3000)
end

local function probe()
	local bin = herdrBin()
	if bin == nil then
		finishProbe({})
		return
	end
	noctalia.runAsync(shQuote(bin) .. " pane list", function(result)
		local agents = {}
		if result.exitCode == 0 then
			agents = agentItems(noctalia.json.decode(result.stdout or ""))
		end
		finishProbe(agents)
	end, 5000)
end

function update()
	noctalia.setUpdateInterval(2000)
	probe()
end

noctalia.state.watch("nosleep_toggle", function(value)
	if value == true then
		noctalia.state.set("nosleep_toggle", false)
		runFish("nosleep-toggle", probe)
	end
end)

loadOwn()
publish(false, {})
probe()
