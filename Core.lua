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
	-- { { name = "Tanking", items = { [itemID] = true } }, ... }, in display order.
	ns.db.categories = ns.db.categories or {}
end)
