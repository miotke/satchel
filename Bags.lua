-- The backpack window: it replaces Blizzard's bag windows and answers every way of opening them.

local _, ns = ...

-- The keyring button shows keys while the window is open, even with the keyring section off.
local peekKeyring = false
local backpack

local function Sections()
	local db = ns.db
	local bags = {}
	for bag = 0, NUM_BAG_SLOTS or 4 do bags[#bags + 1] = bag end
	local sections = { { key = "bags", label = "Bags", bags = bags } }
	if ns.REAGENT and db.showReagent and C_Container.GetContainerNumSlots(ns.REAGENT) > 0 then
		sections[#sections + 1] = { key = "reagent", label = "Reagents", bags = { ns.REAGENT } }
	end
	-- Keyring slots hold only keys, so they are not free space.
	if ns.KEYRING and (db.showKeyring or peekKeyring) and C_Container.GetContainerNumSlots(ns.KEYRING) > 0 then
		sections[#sections + 1] = { key = "keyring", label = "Keyring", bags = { ns.KEYRING }, notFree = true }
	end
	return sections
end

local function SetOption(key, value)
	ns.db[key] = value
	ns.RefreshAll()
end
ns.SetOption = SetOption

function ns.AddOptionsMenu(root)
	if ns.REAGENT then
		root:CreateCheckbox("Show reagent bag", function() return ns.db.showReagent end,
			function() SetOption("showReagent", not ns.db.showReagent) end)
	end
	root:CreateCheckbox("Quest Items section", function() return ns.db.questCategory end,
		function() SetOption("questCategory", not ns.db.questCategory) end)
	if ns.KEYRING then
		root:CreateCheckbox("Show keyring", function() return ns.db.showKeyring end,
			function() SetOption("showKeyring", not ns.db.showKeyring) end)
	end
end

-- Blizzard's bag windows still open and close as usual, but under a hidden parent, so its own
-- bookkeeping stays intact and nothing of ours writes to its frames.
local function HideBlizzardBags()
	if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(ns.hidden) end
	for i = 1, NUM_TOTAL_BAG_FRAMES or 6 do
		local container = _G["ContainerFrame" .. i]
		if container then container:SetParent(ns.hidden) end
	end
end

-- Blizzard's bag functions call each other (ToggleAllBags may call OpenAllBags, which calls
-- OpenBag per bag). Post-hooks run innermost first, so the last request in a frame comes from
-- the outermost call; apply only that one, on the next frame.
local pending
local function Request(action)
	if not pending then
		C_Timer.After(0, function()
			local request = pending
			pending = nil
			if request == "toggle" then
				backpack:SetShown(not backpack:IsShown())
			else
				backpack:SetShown(request == "open")
			end
		end)
	end
	pending = action
end

local function IsCarriedBag(bag)
	if bag == nil then return false end
	if bag >= 0 and bag <= (NUM_BAG_SLOTS or 4) then return true end
	return bag == ns.REAGENT
end

local function HookBagFunctions()
	hooksecurefunc("ToggleAllBags", function() Request("toggle") end)
	hooksecurefunc("OpenAllBags", function() Request("open") end)
	hooksecurefunc("CloseAllBags", function() Request("close") end)
	hooksecurefunc("ToggleBackpack", function() Request("toggle") end)
	hooksecurefunc("OpenBackpack", function() Request("open") end)
	hooksecurefunc("CloseBackpack", function() Request("close") end)
	hooksecurefunc("ToggleBag", function(bag) if IsCarriedBag(bag) then Request("toggle") end end)
	-- The keyring's own window is hidden with the others, so its button shows keys here.
	if ToggleKeyRing and ns.KEYRING then
		hooksecurefunc("ToggleKeyRing", function()
			if ns.db.showKeyring then Request("toggle"); return end
			peekKeyring = not (backpack:IsShown() and peekKeyring)
			if peekKeyring then Request("open") end
			backpack:Refresh()
		end)
	end
end

ns.On("PLAYER_LOGIN", function()
	backpack = ns.CreateWindow({
		name = "SatchelFrame",
		title = UnitName("player"),
		positionKey = "position",
		defaultPoint = { "BOTTOMRIGHT", "BOTTOMRIGHT", -80, 120 },
		columnsKey = "columns",
		orderKey = "backpack",
		sectionKeys = { "bags", "reagent", "keyring" },
		sections = Sections,
		sort = C_Container.SortBags,
		onHide = function()
			if peekKeyring then peekKeyring = false; backpack.dirty = true end
			if C_NewItems and C_NewItems.ClearAll then C_NewItems.ClearAll() end
		end,
	})
	ns.backpack = backpack
	HideBlizzardBags()

	-- The client flags every carried item as new when it loads the bags at login and on
	-- /reload. Only items that arrive after that are new, so drop those flags then, and once
	-- more a moment later, since the bags can finish loading after the world appears.
	ns.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
		if not (isLogin or isReload) or not (C_NewItems and C_NewItems.ClearAll) then return end
		C_NewItems.ClearAll()
		C_Timer.After(2, function()
			C_NewItems.ClearAll()
			ns.RefreshAll()
		end)
		ns.RefreshAll()
	end)
	HookBagFunctions()
end)

SLASH_SATCHEL1 = "/satchel"
SlashCmdList.SATCHEL = function(input)
	local command, value = strsplit(" ", strtrim(input or ""), 2)
	command = command:lower()
	local number = tonumber(value)
	local db = ns.db
	if command == "cols" and number then
		db.columns = math.min(math.max(math.floor(number), 6), 30)
		ns.RefreshAll()
	elseif command == "bankcols" and number then
		db.bankColumns = math.min(math.max(math.floor(number), 6), 30)
		ns.RefreshAll()
	elseif command == "scale" and number then
		db.scale = math.min(math.max(number, 0.5), 2)
		for _, window in ipairs(ns.windows) do window.frame:SetScale(db.scale) end
	elseif command == "reagent" then
		SetOption("showReagent", not db.showReagent)
		ns.Print("reagent bag " .. (db.showReagent and "shown" or "hidden"))
	elseif command == "quest" then
		SetOption("questCategory", not db.questCategory)
		ns.Print("Quest Items section " .. (db.questCategory and "on" or "off"))
	elseif command == "keyring" then
		SetOption("showKeyring", not db.showKeyring)
		ns.Print("keyring " .. (db.showKeyring and "shown" or "hidden"))
	elseif command == "new" and value then
		if ns.Categories.Create(value) then ns.Print("added category " .. strtrim(value)) end
	elseif command == "perf" then
		ns.TogglePerf()
	elseif command == "reset" then
		for _, window in ipairs(ns.windows) do
			db[window.config.positionKey] = nil
			window:RestorePosition()
		end
	elseif command == "" then
		backpack:SetShown(not backpack:IsShown())
	else
		ns.Print("/satchel, /satchel cols <6-30>, /satchel bankcols <6-30>, /satchel scale <0.5-2>, "
			.. "/satchel reagent, /satchel keyring, /satchel quest, /satchel new <category>, /satchel perf, /satchel reset")
	end
end
