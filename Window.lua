-- A bag window: the backpack and the bank are both one of these. Player categories come
-- first, each under its header, then the window's own sections (bags, reagents, keyring).

local _, ns = ...

local SLOT_SIZE, SPACING = 37, 4
local INSET_TOP, INSET_BOTTOM, PADDING = 54, 28, 8
local HEADER_HEIGHT = 18
local SECTION_GAP = SPACING * 2
local EMPTY_SLOT_ATLAS = "bags-item-slot64"

local Window = {}
Window.__index = Window
ns.windows = {}

local buttonCount = 0

--[[ config:
	name          global frame name
	title         window title
	positionKey   db key for the saved position
	defaultPoint  { point, relativePoint, x, y }
	columnsKey    db key for slots per row
	sections      function returning { { label, bags = { bagIDs }, notFree = bool }, ... }
	sort          function, or nil for no Sort button
	close         function for the close button, or nil to just hide
]]
function ns.CreateWindow(config)
	local self = setmetatable({ config = config, holders = {}, buttons = {}, headers = {}, dirty = true }, Window)
	self:Build()
	table.insert(ns.windows, self)
	return self
end

function ns.RefreshAll()
	for _, window in ipairs(ns.windows) do window:Refresh() end
end

-- Blizzard's buttons find their bag through their parent, so each bag gets a holder frame
-- whose ID is the bag. Forever's Initialize also asks it IsCombinedBagContainer.
function Window:Holder(bag)
	local holder = self.holders[bag]
	if not holder then
		holder = CreateFrame("Frame", nil, self.content)
		holder:SetAllPoints(self.content)
		holder:SetID(bag)
		holder.IsCombinedBagContainer = function() return false end
		self.holders[bag] = holder
		self.buttons[bag] = {}
	end
	return holder
end

local function OnItemClick(button, mouse)
	-- Alt+right-click does nothing in Blizzard's handler, which runs first.
	if mouse ~= "RightButton" or not IsAltKeyDown() then return end
	local itemID = C_Container.GetContainerItemID(button.satchelBag, button.satchelSlot)
	if itemID then ns.Categories.ShowItemMenu(button, itemID) end
end

function Window:Button(bag, slot)
	local holder = self:Holder(bag)
	local button = self.buttons[bag][slot]
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
	button:HookScript("OnClick", OnItemClick)
	self.buttons[bag][slot] = button
	return button
end

function Window:UpdateButton(button)
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

-- Dropping an item on a category's header puts it there; on a section's header, takes it out.
local function OnHeaderDrop(header)
	local kind, itemID = GetCursorInfo()
	if kind ~= "item" then return end
	ClearCursor()
	ns.Categories.Assign(itemID, header.category)
end

local function OnHeaderEnter(header)
	GameTooltip:SetOwner(header, "ANCHOR_TOP")
	GameTooltip:SetText(header.text:GetText())
	if header.category then
		GameTooltip:AddLine("Drop an item here to add it. Alt+right-click an item for more.", 1, 1, 1, true)
	else
		GameTooltip:AddLine("Drop an item here to take it out of its category.", 1, 1, 1, true)
	end
	GameTooltip:Show()
end

function Window:Header(index)
	local header = self.headers[index]
	if header then return header end
	header = CreateFrame("Button", nil, self.content)
	header:SetHeight(HEADER_HEIGHT - 2)
	header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header.text:SetPoint("LEFT")
	header:SetScript("OnReceiveDrag", OnHeaderDrop)
	header:SetScript("OnClick", OnHeaderDrop)
	header:SetScript("OnEnter", OnHeaderEnter)
	header:SetScript("OnLeave", GameTooltip_Hide)
	self.headers[index] = header
	return header
end

function Window:UpdateFooter()
	local free, total = 0, 0
	for _, section in ipairs(self.config.sections()) do
		if not section.notFree then
			for _, bag in ipairs(section.bags) do
				free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
				total = total + C_Container.GetContainerNumSlots(bag)
			end
		end
	end
	self.freeText:SetFormattedText("%d/%d free", free, total)
	self.moneyText:SetText(GetMoneyString(GetMoney(), true))
end

-- Sorts every slot into groups: categories in their order, then the window's sections. Empty
-- slots stay in their section.
function Window:Groups()
	local categorized, sections, used = {}, {}, {}
	for index, section in ipairs(self.config.sections()) do
		local group = { label = section.label, buttons = {} }
		sections[index] = group
		for _, bag in ipairs(section.bags) do
			local slots = C_Container.GetContainerNumSlots(bag)
			used[bag] = slots
			for slot = 1, slots do
				local button = self:Button(bag, slot)
				local category = ns.Categories.Of(C_Container.GetContainerItemID(bag, slot))
				if category then
					categorized[category] = categorized[category] or {}
					table.insert(categorized[category], button)
				else
					table.insert(group.buttons, button)
				end
			end
		end
	end

	local groups = {}
	for index, category in ipairs(ns.Categories.List()) do
		if categorized[index] then
			groups[#groups + 1] = { label = category.name, category = index, buttons = categorized[index] }
		end
	end
	local hasCategories = #groups > 0
	for _, group in ipairs(sections) do
		if #group.buttons > 0 then groups[#groups + 1] = group end
	end
	return groups, used, hasCategories
end

function Window:Layout()
	local columns = ns.db[self.config.columnsKey]
	local step = SLOT_SIZE + SPACING
	local width = columns * step - SPACING
	local groups, used, labelled = self:Groups()
	local y, headerCount = 0, 0

	for index, group in ipairs(groups) do
		if index > 1 then y = y + SPACING + SECTION_GAP end
		-- Headers only once a category shows, so a bag without categories stays one grid.
		if labelled then
			headerCount = headerCount + 1
			local header = self:Header(headerCount)
			header:ClearAllPoints()
			header:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
			header:SetWidth(width)
			header.text:SetText(group.label)
			header.category = group.category
			header:Show()
			y = y + HEADER_HEIGHT
		end
		for n, button in ipairs(group.buttons) do
			local col, row = (n - 1) % columns, math.floor((n - 1) / columns)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self.content, "TOPLEFT", col * step, -(y + row * step))
			button:Show()
			self:UpdateButton(button)
		end
		y = y + math.ceil(#group.buttons / columns) * step - SPACING
	end

	for index = headerCount + 1, #self.headers do self.headers[index]:Hide() end
	-- Hide slots of bags that shrank, were removed or are switched off.
	for bag, slots in pairs(self.buttons) do
		for slot, button in pairs(slots) do
			if slot > (used[bag] or 0) then button:Hide() end
		end
	end

	local height = math.max(y, SLOT_SIZE)
	self.content:SetSize(width, height)
	self.frame:SetSize(width + PADDING * 2 + 10, height + PADDING * 2 + INSET_TOP + INSET_BOTTOM)
	self:UpdateFooter()
	self.dirty = false
end

function Window:UpdateAll()
	for _, slots in pairs(self.buttons) do
		for _, button in pairs(slots) do
			if button:IsShown() then self:UpdateButton(button) end
		end
	end
end

function Window:UpdateSlot(bag, slot)
	local button = self.buttons[bag] and self.buttons[bag][slot]
	if button and button:IsShown() then self:UpdateButton(button) end
end

function Window:Refresh()
	if self.frame:IsShown() then self:Layout() else self.dirty = true end
end

function Window:IsShown() return self.frame:IsShown() end
function Window:SetShown(shown) self.frame:SetShown(shown) end

function Window:SavePosition()
	local point, _, relativePoint, x, y = self.frame:GetPoint()
	ns.db[self.config.positionKey] = { point, relativePoint, x, y }
end

function Window:RestorePosition()
	local p = ns.db[self.config.positionKey] or self.config.defaultPoint
	self.frame:ClearAllPoints()
	self.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function ShowOptionsMenu(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		ns.AddOptionsMenu(root)
		ns.Categories.AddManageMenu(root)
	end)
end

function Window:Build()
	local config = self.config
	local frame = CreateFrame("Frame", config.name, UIParent, "ButtonFrameTemplate")
	self.frame = frame
	if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
	if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(frame) end
	if frame.SetTitle then frame:SetTitle(config.title) end
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		self:SavePosition()
	end)
	frame:SetScale(ns.db.scale)
	self:RestorePosition()
	frame:Hide()
	if config.close and frame.CloseButton then
		frame.CloseButton:SetScript("OnClick", config.close)
	end

	frame.Inset:ClearAllPoints()
	frame.Inset:SetPoint("TOPLEFT", 4, -INSET_TOP)
	frame.Inset:SetPoint("BOTTOMRIGHT", -6, INSET_BOTTOM)

	self.content = CreateFrame("Frame", nil, frame)
	self.content:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", PADDING, -PADDING)

	-- Right of the search box: Sort, then the gear menu.
	local right = -16
	local hasMenu = MenuUtil and MenuUtil.CreateContextMenu
	if hasMenu then
		local gear = CreateFrame("Button", nil, frame)
		gear:SetSize(20, 20)
		gear:SetPoint("TOPRIGHT", right, -28)
		gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
		gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
		gear:SetScript("OnClick", ShowOptionsMenu)
		right = right - 24
	end
	if config.sort then
		local sort = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		sort:SetSize(52, 22)
		sort:SetPoint("TOPRIGHT", right, -27)
		sort:SetText("Sort")
		sort:SetScript("OnClick", function()
			if InCombatLockdown() then return end
			PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
			config.sort()
		end)
		right = right - 56
	end

	local search = CreateFrame("EditBox", config.name .. "SearchBox", frame, "SearchBoxTemplate")
	self.search = search
	search:SetHeight(20)
	search:SetPoint("TOPLEFT", 16, -28)
	search:SetPoint("TOPRIGHT", right - 4, -28)
	search:HookScript("OnTextChanged", function(box)
		C_Container.SetItemSearch(box:GetText())
	end)

	self.freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.freeText:SetPoint("BOTTOMLEFT", 14, 9)
	self.moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.moneyText:SetPoint("BOTTOMRIGHT", -14, 9)

	frame:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
		if self.dirty then self:Layout() else self:UpdateAll(); self:UpdateFooter() end
	end)
	frame:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
		if search:GetText() ~= "" then search:SetText("") end
		search:ClearFocus()
		if self.config.onHide then self.config.onHide() end
	end)

	table.insert(UISpecialFrames, config.name)
end

local function EachShown(method, ...)
	for _, window in ipairs(ns.windows) do
		if window:IsShown() then window[method](window, ...) end
	end
end

ns.On("PLAYER_LOGIN", function()
	ns.On("BAG_UPDATE_DELAYED", ns.RefreshAll)
	ns.On("BAG_CONTAINER_UPDATE", ns.RefreshAll)
	ns.On("ITEM_LOCK_CHANGED", function(bag, slot)
		if slot then EachShown("UpdateSlot", bag, slot) end
	end)
	ns.On("PLAYER_MONEY", function() EachShown("UpdateFooter") end)
	for _, event in ipairs({ "BAG_UPDATE_COOLDOWN", "INVENTORY_SEARCH_UPDATE", "BAG_NEW_ITEMS_UPDATED", "QUEST_ACCEPTED" }) do
		ns.On(event, function() EachShown("UpdateAll") end)
	end
	ns.On("UNIT_QUEST_LOG_CHANGED", function(unit)
		if unit == "player" then EachShown("UpdateAll") end
	end)
end)
