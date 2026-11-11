-- Shared state: saved settings, bag IDs and one event frame for every file.
--
-- WoW: Forever is a fork of the retail client, so Satchel uses retail's bag API (C_Container,
-- ContainerFrameItemButtonTemplate). Item buttons come from Blizzard's own template, which keeps
-- clicking, using, dragging and tooltips on Blizzard's secure code paths.

local ADDON, ns = ...

local DEFAULTS = {
	columns = 10,
	bankColumns = 14,
	scale = 1,
	showReagent = true,
	showKeyring = false,
}

ns.REAGENT = Enum.BagIndex and Enum.BagIndex.ReagentBag
ns.KEYRING = Enum.BagIndex and Enum.BagIndex.Keyring

-- Blizzard's bag and bank windows live on under this, invisible but otherwise untouched.
ns.hidden = CreateFrame("Frame")
ns.hidden:Hide()

-- What /satchel perf reports.
ns.stats = { layouts = 0, lastLayoutMs = 0, totalLayoutMs = 0, maxLayoutMs = 0, slotFrames = 0 }

-- While the perf window is open, timings and memory samples also go to SatchelPerfLog, a
-- SavedVariable WoW writes to disk on /reload or logout (read it with tools/perf-report.lua).
-- Each list keeps only its newest entries, so the file stays small.
local LOG_LIMIT = 2000
ns.logging = false

local function Append(list, entry)
	list[#list + 1] = entry
	if #list > LOG_LIMIT then table.remove(list, 1) end
end

function ns.StartLogging()
	if ns.logging then return end
	ns.logging = true
	SatchelPerfLog = SatchelPerfLog or {}
	local log = SatchelPerfLog
	log.sessions, log.work, log.samples = log.sessions or {}, log.work or {}, log.samples or {}
	Append(log.sessions, { started = time(), clock = GetTime(), build = (GetBuildInfo()) })
end

function ns.StopLogging()
	ns.logging = false
end

-- kind is "layout", "update" or "cooldowns"; slots is how many slots the pass touched.
function ns.RecordWork(kind, window, ms, slots)
	if kind == "layout" then
		local stats = ns.stats
		stats.layouts = stats.layouts + 1
		stats.lastLayoutMs = ms
		stats.totalLayoutMs = stats.totalLayoutMs + ms
		stats.maxLayoutMs = math.max(stats.maxLayoutMs, ms)
	end
	if ns.logging then
		Append(SatchelPerfLog.work, { GetTime(), kind, window, ms, slots, InCombatLockdown() and 1 or 0 })
	end
end

function ns.RecordMemory(kilobytes)
	if ns.logging then Append(SatchelPerfLog.samples, { GetTime(), kilobytes }) end
end

function ns.Print(message)
	print("|cffffd100Satchel|r: " .. message)
end

local listeners = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	for _, listener in ipairs(listeners[event]) do listener(...) end
end)

function ns.On(event, listener)
	if not listeners[event] then
		listeners[event] = {}
		events:RegisterEvent(event)
	end
	table.insert(listeners[event], listener)
end

ns.On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	SatchelDB = SatchelDB or {}
	ns.db = SatchelDB
	for key, value in pairs(DEFAULTS) do
		if ns.db[key] == nil then ns.db[key] = value end
	end
	-- { { id = 1, name = "Tanking", items = { [itemID] = true } }, ... }
	ns.db.categories = ns.db.categories or {}
	-- Categories made before they had ids get one; the order per window refers to them by it.
	ns.db.nextCategoryID = ns.db.nextCategoryID or 1
	for _, category in ipairs(ns.db.categories) do
		if not category.id then
			category.id = ns.db.nextCategoryID
			ns.db.nextCategoryID = category.id + 1
		end
	end
	-- { backpack = { "category:1", "bags", "reagent", "keyring" }, bank = { ... } }
	ns.db.order = ns.db.order or {}
	-- { backpack = { [itemID] = position in its group }, bank = { ... } }
	ns.db.pins = ns.db.pins or {}
end)
