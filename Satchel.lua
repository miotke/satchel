-- Satchel: every carried bag in one window.
--
-- WoW: Forever is a fork of the retail client, so this uses retail's bag API (C_Container,
-- ContainerFrameItemButtonTemplate). Item buttons come from Blizzard's own template, which keeps
-- clicking, using, dragging and tooltips on Blizzard's secure code paths.

local ADDON = ...

local SLOT_SIZE = 37
local SPACING = 4
local INSET_TOP, INSET_BOTTOM = 54, 28
local PADDING = 8
local EMPTY_SLOT_ATLAS = "bags-item-slot64"
local DEFAULTS = { columns = 10, scale = 1 }

local db
local frame, content, searchBox, moneyText, freeText
local holders, buttons = {}, {}
local buttonCount = 0
local dirty = true

-- Backpack, the four bag slots, then the reagent bag when one is equipped.
local function BagIDs()
	local ids = {}
	for bag = 0, NUM_BAG_SLOTS or 4 do ids[#ids + 1] = bag end
	local reagent = Enum.BagIndex and Enum.BagIndex.ReagentBag
	if reagent and C_Container.GetContainerNumSlots(reagent) > 0 then ids[#ids + 1] = reagent end
	return ids, reagent
end

-- Blizzard's buttons find their bag through their parent, so each bag gets a holder frame
-- whose ID is the bag. Forever's Initialize also asks it IsCombinedBagContainer.
local function Holder(bag)
	local holder = holders[bag]
	if not holder then
		holder = CreateFrame("Frame", nil, content)
		holder:SetAllPoints(content)
		holder:SetID(bag)
		holder.IsCombinedBagContainer = function() return false end
		holders[bag] = holder
		buttons[bag] = {}
	end
	return holder
end

local function Button(bag, slot)
	local holder = Holder(bag)
	local button = buttons[bag][slot]
	if button then return button end

	buttonCount = buttonCount + 1
	button = CreateFrame("ItemButton", "SatchelItem" .. buttonCount, holder, "ContainerFrameItemButtonTemplate")
	button:SetSize(SLOT_SIZE, SLOT_SIZE)
	local background = button:CreateTexture(nil, "BACKGROUND", nil, -6)
	background:SetAllPoints()
	if not background:SetAtlas(EMPTY_SLOT_ATLAS) then
		background:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
	end
	button:SetID(slot)
	-- Retail takes (bag, slot); Forever takes (container, bag, slot).
	if button.Initialize then button:Initialize(holder, bag, slot) end
	button.satchelBag, button.satchelSlot = bag, slot
	buttons[bag][slot] = button
	return button
end

local function UpdateButton(button)
	local bag, slot = button.satchelBag, button.satchelSlot
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local texture = info and info.iconFileID
	SetItemButtonTexture(button, texture)
	SetItemButtonCount(button, info and info.stackCount or 0)
	SetItemButtonDesaturated(button, info and info.isLocked)
	SetItemButtonQuality(button, info and info.quality, info and info.hyperlink, false, info and info.isBound)
	if button.SetHasItem then button:SetHasItem(texture) end
	if button.UpdateCooldown then button:UpdateCooldown(texture) end
	if button.UpdateNewItem then button:UpdateNewItem(info and info.quality) end
	if button.UpdateJunkItem then button:UpdateJunkItem(info and info.quality, info and info.hasNoValue) end
	if button.UpdateQuestItem then
		local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
		button:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive)
	end
	if button.SetMatchesSearch then button:SetMatchesSearch(not (info and info.isFiltered)) end
	button.readable = info and info.isReadable
end

local function UpdateFooter()
	local free, total = 0, 0
	for _, bag in ipairs((BagIDs())) do
		free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
		total = total + C_Container.GetContainerNumSlots(bag)
	end
	freeText:SetFormattedText("%d/%d free", free, total)
	moneyText:SetText(GetMoneyString(GetMoney(), true))
end

-- Lays out every slot in one grid, the reagent bag on rows of its own, and sizes the window.
local function Layout()
	local columns = db.columns
	local step = SLOT_SIZE + SPACING
	local col, row, extra = 0, 0, 0
	local bags, reagent = BagIDs()
	local shown = {}

	for _, bag in ipairs(bags) do
		if bag == reagent and col > 0 then
			col, row, extra = 0, row + 1, SPACING * 2
		end
		local slots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, slots do
			local button = Button(bag, slot)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", content, "TOPLEFT", col * step, -(row * step + extra))
			button:Show()
			UpdateButton(button)
			col = col + 1
			if col == columns then col, row = 0, row + 1 end
		end
		shown[bag] = slots
	end

	-- Hide slots of bags that shrank or were removed.
	for bag, slots in pairs(buttons) do
		local used = shown[bag] or 0
		for slot, button in pairs(slots) do
			if slot > used then button:Hide() end
		end
	end

	local rows = row + (col > 0 and 1 or 0)
	local width = columns * step - SPACING
	local height = math.max(rows, 1) * step - SPACING + extra
	content:SetSize(width, height)
	frame:SetSize(width + PADDING * 2 + 10, height + PADDING * 2 + INSET_TOP + INSET_BOTTOM)
	UpdateFooter()
	dirty = false
end

local function UpdateAll()
	for _, slots in pairs(buttons) do
		for _, button in pairs(slots) do
			if button:IsShown() then UpdateButton(button) end
		end
	end
end

local function Refresh()
	if frame:IsShown() then Layout() else dirty = true end
end

local function SavePosition()
	local point, _, relativePoint, x, y = frame:GetPoint()
	db.position = { point, relativePoint, x, y }
end

local function RestorePosition()
	frame:ClearAllPoints()
	local p = db.position
	if p then
		frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
	end
end

local function CreateWindow()
	frame = CreateFrame("Frame", "SatchelFrame", UIParent, "ButtonFrameTemplate")
	if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
	if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(frame) end
	if frame.SetTitle then frame:SetTitle(UnitName("player")) end
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	frame:SetScale(db.scale)
	RestorePosition()
	frame:Hide()

	frame.Inset:ClearAllPoints()
	frame.Inset:SetPoint("TOPLEFT", 4, -INSET_TOP)
	frame.Inset:SetPoint("BOTTOMRIGHT", -6, INSET_BOTTOM)

	content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", PADDING, -PADDING)

	searchBox = CreateFrame("EditBox", "SatchelSearchBox", frame, "SearchBoxTemplate")
	searchBox:SetHeight(20)
	searchBox:SetPoint("TOPLEFT", 16, -28)
	searchBox:SetPoint("TOPRIGHT", -68, -28)
	searchBox:HookScript("OnTextChanged", function(self)
		C_Container.SetItemSearch(self:GetText())
	end)

	local sort = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	sort:SetSize(52, 22)
	sort:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
	sort:SetText("Sort")
	sort:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
		C_Container.SortBags()
	end)

	freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	freeText:SetPoint("BOTTOMLEFT", 14, 9)
	moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	moneyText:SetPoint("BOTTOMRIGHT", -14, 9)

	frame:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
		if dirty then Layout() else UpdateAll(); UpdateFooter() end
	end)
	frame:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
		searchBox:SetText("")
		searchBox:ClearFocus()
		if C_NewItems and C_NewItems.ClearAll then C_NewItems.ClearAll() end
	end)

	table.insert(UISpecialFrames, "SatchelFrame")
end

-- Blizzard's bag windows still open and close as usual, but under a hidden parent, so its own
-- bookkeeping stays intact and nothing of ours writes to its frames.
local function HideBlizzardBags()
	local hidden = CreateFrame("Frame")
	hidden:Hide()
	if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(hidden) end
	for i = 1, NUM_TOTAL_BAG_FRAMES or 6 do
		local container = _G["ContainerFrame" .. i]
		if container then container:SetParent(hidden) end
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
				frame:SetShown(not frame:IsShown())
			else
				frame:SetShown(request == "open")
			end
		end)
	end
	pending = action
end

local function IsCarriedBag(bag)
	if bag == nil then return false end
	if bag >= 0 and bag <= (NUM_BAG_SLOTS or 4) then return true end
	return Enum.BagIndex and bag == Enum.BagIndex.ReagentBag
end

local function HookBagFunctions()
	hooksecurefunc("ToggleAllBags", function() Request("toggle") end)
	hooksecurefunc("OpenAllBags", function() Request("open") end)
	hooksecurefunc("CloseAllBags", function() Request("close") end)
	hooksecurefunc("ToggleBackpack", function() Request("toggle") end)
	hooksecurefunc("OpenBackpack", function() Request("open") end)
	hooksecurefunc("CloseBackpack", function() Request("close") end)
	hooksecurefunc("ToggleBag", function(bag) if IsCarriedBag(bag) then Request("toggle") end end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= ADDON then return end
		SatchelDB = SatchelDB or {}
		db = SatchelDB
		for key, value in pairs(DEFAULTS) do
			if db[key] == nil then db[key] = value end
		end
	elseif event == "PLAYER_LOGIN" then
		CreateWindow()
		HideBlizzardBags()
		HookBagFunctions()
		self:RegisterEvent("BAG_UPDATE_DELAYED")
		self:RegisterEvent("BAG_CONTAINER_UPDATE")
		self:RegisterEvent("ITEM_LOCK_CHANGED")
		self:RegisterEvent("BAG_UPDATE_COOLDOWN")
		self:RegisterEvent("INVENTORY_SEARCH_UPDATE")
		self:RegisterEvent("BAG_NEW_ITEMS_UPDATED")
		self:RegisterEvent("QUEST_ACCEPTED")
		self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
		self:RegisterEvent("PLAYER_MONEY")
	elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_CONTAINER_UPDATE" then
		Refresh()
	elseif event == "ITEM_LOCK_CHANGED" then
		local bag, slot = ...
		local button = slot and buttons[bag] and buttons[bag][slot]
		if button and button:IsShown() then UpdateButton(button) end
	elseif event == "PLAYER_MONEY" then
		if frame:IsShown() then UpdateFooter() end
	elseif event == "UNIT_QUEST_LOG_CHANGED" and ... ~= "player" then
		return
	elseif frame:IsShown() then
		UpdateAll()
	end
end)

SLASH_SATCHEL1 = "/satchel"
SlashCmdList.SATCHEL = function(input)
	local command, value = strsplit(" ", strtrim(input or ""), 2)
	command = command:lower()
	local number = tonumber(value)
	if command == "cols" and number then
		db.columns = math.min(math.max(math.floor(number), 6), 30)
		Layout()
	elseif command == "scale" and number then
		db.scale = math.min(math.max(number, 0.5), 2)
		frame:SetScale(db.scale)
	elseif command == "reset" then
		db.position = nil
		RestorePosition()
	elseif command == "" then
		frame:SetShown(not frame:IsShown())
	else
		print("|cffffd100Satchel|r: /satchel, /satchel cols <6-30>, /satchel scale <0.5-2>, /satchel reset")
	end
end
