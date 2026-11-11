-- A bag window: the backpack and the bank are both one of these. It shows the player's
-- categories and its own sections (bags, reagents, keyring), each under a header, in an
-- order the player sets per window.

local _, ns = ...

local SLOT_SIZE, SPACING = 37, 4
local INSET_TOP, INSET_BOTTOM, PADDING = 54, 28, 8
local HEADER_HEIGHT = 18
local SECTION_GAP = SPACING * 2
local EMPTY_SLOT_ATLAS = "bags-item-slot64"
local PIN_ATLAS = "Waypoint-MapPin-ChatIcon"
local NEW_ITEM_ATLAS = "bags-glow-white"

-- Masque, when installed, skins the decoration only: the click layer must carry no add-on
-- writes (Window:Button), and Masque stores its state on the buttons it skins.
local Masque = LibStub and LibStub("Masque", true)

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
	orderKey      db.order key for this window's section order
	sectionKeys   every section key this window can show, in default order
	sections      function returning { { key, label, bags = { bagIDs }, notFree = bool }, ... }
	sort          function, or nil for no Sort button
	extraButton   { icon, tooltip, onClick } for a small button left of Sort, or nil
	close         function for the close button, or nil to just hide
	bottomExtra   extra height above the footer for a window's own bar (the bank's tabs), or nil
	masqueGroup   Masque group name for this window's slots
	onShow        function run before the window draws, or nil
	onHide        function run after the window hides, or nil
]]
function ns.CreateWindow(config)
	local self = setmetatable({ config = config, holders = {}, buttons = {}, headers = {}, dirty = true }, Window)
	if Masque and config.masqueGroup then self.masque = Masque:Group("Satchel", config.masqueGroup) end
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
		holder.window = self
		self.holders[bag] = holder
		self.buttons[bag] = {}
	end
	return holder
end

local function OnItemClick(button, mouse)
	-- Alt+right-click does nothing in Blizzard's handler, which runs first.
	if mouse ~= "RightButton" or not IsAltKeyDown() then return end
	local itemID = C_Container.GetContainerItemID(button.satchelBag, button.satchelSlot)
	local window = button:GetParent().window
	if itemID then ns.Categories.ShowItemMenu(button, itemID, window, window.positions[button]) end
end

-- Hovering a new item marks it seen, which ends its glow.
local function OnItemEnter(button)
	local bag, slot = button.satchelBag, button.satchelSlot
	if C_NewItems and C_NewItems.IsNewItem(bag, slot) then
		C_NewItems.RemoveNewItem(bag, slot)
		button:GetParent().window:UpdateButton(button)
	end
end

-- Blizzard's new-item and Store ("battle pay") glows. Satchel draws its own new-item glow,
-- and with Blizzard's handling bypassed these came back lit on every slot. Blizzard's code
-- may Show them again, so they are shrunk to nothing rather than hidden.
local function SilenceBlizzardGlows(button)
	for _, key in ipairs({ "NewItemTexture", "BattlepayItemTexture" }) do
		local texture = button[key]
		if texture then
			texture:Hide()
			texture:ClearAllPoints()
			texture:SetPoint("CENTER")
			texture:SetSize(0.001, 0.001)
		end
	end
end

local function NewItemButton(name, holder, bag, slot)
	local button = CreateFrame("ItemButton", name, holder, "ContainerFrameItemButtonTemplate")
	button:SetSize(SLOT_SIZE, SLOT_SIZE)
	button:SetID(slot)
	-- Retail takes (bag, slot); Forever takes (container, bag, slot).
	if button.Initialize then button:Initialize(holder, bag, slot) end
	return button
end

-- Each slot is two of Blizzard's buttons. The one on top takes clicks, and Satchel never
-- writes to it beyond Initialize and SetHasItem: the drawing calls set fields that its click
-- handler reads, and a field written by add-on code taints the click, so Blizzard blocks
-- using the item. The decoration underneath, which ignores the mouse, shows the item.
function Window:Button(bag, slot)
	local holder = self:Holder(bag)
	local button = self.buttons[bag][slot]
	if button then return button end

	buttonCount = buttonCount + 1
	local name = "SatchelItem" .. buttonCount
	local decoration = NewItemButton(name .. "Decoration", holder, bag, slot)
	decoration:EnableMouse(false)
	SilenceBlizzardGlows(decoration)
	local background = decoration:CreateTexture(nil, "BACKGROUND", nil, -6)
	background:SetAllPoints()
	if not background:SetAtlas(EMPTY_SLOT_ATLAS) then
		background:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
	end

	button = NewItemButton(name, holder, bag, slot)
	button:SetFrameLevel(decoration:GetFrameLevel() + 2)
	decoration:SetAllPoints(button)
	if button.GetNormalTexture and button:GetNormalTexture() then button:GetNormalTexture():SetTexture("") end
	if button.ItemContextOverlay then button.ItemContextOverlay:SetAlpha(0) end
	SilenceBlizzardGlows(button)
	button:HookScript("OnClick", OnItemClick)
	button:HookScript("OnEnter", OnItemEnter)

	button.decoration = decoration
	if self.masque then self.masque:AddButton(decoration) end
	button.satchelBag, button.satchelSlot = bag, slot
	self.buttons[bag][slot] = button
	return button
end

-- The decoration's pin mark, made the first time a pinned item shows in its slot.
local function SetPinned(button, pinned)
	local decoration = button.decoration
	if not pinned and not decoration.satchelPin then return end
	if not decoration.satchelPin then
		local mark = decoration:CreateTexture(nil, "OVERLAY", nil, 7)
		mark:SetSize(14, 14)
		mark:SetPoint("TOPRIGHT", 3, 3)
		if not mark:SetAtlas(PIN_ATLAS) then mark:SetTexture("Interface\\COMMON\\Indicator-Yellow") end
		decoration.satchelPin = mark
	end
	decoration.satchelPin:SetShown(pinned)
end

-- The new-item glow, drawn by Satchel from the client's new-item flag: Blizzard's own glow
-- does not show on the decoration on Forever. It pulses like Blizzard's.
local function SetNewItem(visual, isNew, quality)
	local glow = visual.satchelGlow
	if not isNew then
		if glow then
			glow.pulse:Stop()
			glow:Hide()
		end
		return
	end
	if not glow then
		glow = visual:CreateTexture(nil, "OVERLAY", nil, 6)
		glow:SetAllPoints()
		glow:SetBlendMode("ADD")
		local pulse = glow:CreateAnimationGroup()
		pulse:SetLooping("BOUNCE")
		local fade = pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0.3)
		fade:SetDuration(0.8)
		glow.pulse = pulse
		visual.satchelGlow = glow
	end
	local atlas = quality and NEW_ITEM_ATLAS_BY_QUALITY and NEW_ITEM_ATLAS_BY_QUALITY[quality] or NEW_ITEM_ATLAS
	if not glow:SetAtlas(atlas) and not glow:SetAtlas(NEW_ITEM_ATLAS) then
		glow:SetColorTexture(1, 1, 1, 0.25)
	end
	glow:Show()
	if not glow.pulse:IsPlaying() then glow.pulse:Play() end
end

function Window:UpdateButton(button)
	local bag, slot = button.satchelBag, button.satchelSlot
	local visual = button.decoration
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local texture = info and info.iconFileID
	if button.SetHasItem then button:SetHasItem(texture) end

	visual.satchelTexture = texture
	SetItemButtonTexture(visual, texture)
	SetItemButtonCount(visual, info and info.stackCount or 0)
	SetItemButtonDesaturated(visual, info and info.isLocked)
	SetItemButtonQuality(visual, info and info.quality, info and info.hyperlink, false, info and info.isBound)
	if visual.UpdateCooldown then visual:UpdateCooldown(texture) end
	SetNewItem(visual, info and C_NewItems and C_NewItems.IsNewItem(bag, slot), info and info.quality)
	if visual.UpdateJunkItem then visual:UpdateJunkItem(info and info.quality, info and info.hasNoValue) end
	if visual.UpdateQuestItem then
		if info then
			local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
			visual:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive)
		else
			visual:UpdateQuestItem(false)
		end
	end
	if visual.SetMatchesSearch then visual:SetMatchesSearch(not (info and info.isFiltered)) end
	if visual.SetReadable then visual:SetReadable(info and info.isReadable) end
end

local function IndexOf(list, value)
	for index, entry in ipairs(list) do
		if entry == value then return index end
	end
	return nil
end

-- The window's order of category and section keys, kept in step with the categories that
-- exist: deleted ones drop out, new ones go on top, and sections never seen go last.
function Window:Order()
	local order = ns.db.order[self.config.orderKey] or {}
	ns.db.order[self.config.orderKey] = order
	local valid, present = {}, {}
	for _, category in ipairs(ns.Categories.List()) do valid[ns.Categories.Key(category.id)] = true end
	for _, key in ipairs(self.config.sectionKeys) do valid[key] = true end
	for index = #order, 1, -1 do
		local key = order[index]
		if not valid[key] or present[key] then table.remove(order, index) else present[key] = true end
	end
	local top = 1
	for _, category in ipairs(ns.Categories.List()) do
		local key = ns.Categories.Key(category.id)
		if not present[key] then
			table.insert(order, top, key)
			top = top + 1
		end
	end
	for _, key in ipairs(self.config.sectionKeys) do
		if not present[key] then table.insert(order, key) end
	end
	return order
end

-- The entry key moves past its neighbour among what the window shows, so hidden entries
-- (empty categories, a switched-off keyring) never swallow a move. An entry that is not
-- showing moves past its neighbour in the full order.
function Window:Neighbor(key, offset)
	local shown = self.shownKeys or {}
	local index = IndexOf(shown, key)
	if index then return shown[index + offset] end
	local order = self:Order()
	index = IndexOf(order, key)
	return index and order[index + offset]
end

function Window:CanMove(key, offset)
	return self:Neighbor(key, offset) ~= nil
end

function Window:Move(key, offset)
	local neighbor = self:Neighbor(key, offset)
	if not neighbor then return end
	local order = self:Order()
	table.remove(order, IndexOf(order, key))
	local index = IndexOf(order, neighbor)
	table.insert(order, offset > 0 and index + 1 or index, key)
	self.dirty = true
	self:Refresh()
end

-- Dropping an item on a category's header puts it there; on a section's header, takes it out.
local function OnHeaderDrop(header)
	local kind, itemID = GetCursorInfo()
	if kind ~= "item" then return end
	ClearCursor()
	ns.Categories.Assign(itemID, header.category)
end

local function ShowHeaderMenu(header)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	local window, key, id = header.window, header.key, header.category
	MenuUtil.CreateContextMenu(header, function(_, root)
		root:CreateTitle(header.text:GetText())
		if header.auto then
			root:CreateButton("Turn off Quest Items", function() ns.SetOption("questCategory", false) end)
			return
		end
		ns.Categories.AddMoveButtons(root, window, key)
		if id then
			root:CreateButton("Rename…", function() ns.Categories.PromptRename(id) end)
			root:CreateButton("Delete…", function() ns.Categories.ConfirmDelete(id) end)
		end
	end)
end

local function OnHeaderClick(header, mouse)
	if mouse == "RightButton" then ShowHeaderMenu(header) else OnHeaderDrop(header) end
end

local function OnHeaderEnter(header)
	GameTooltip:SetOwner(header, "ANCHOR_TOP")
	GameTooltip:SetText(header.text:GetText())
	if header.auto then
		GameTooltip:AddLine("Quest items gather here on their own, always at the bottom.", 1, 1, 1, true)
		GameTooltip:AddLine("Right-click to turn this section off.", 0.8, 0.8, 0.8, true)
	else
		if header.category then
			GameTooltip:AddLine("Drop an item here to add it. Alt+right-click an item for more.", 1, 1, 1, true)
		else
			GameTooltip:AddLine("Drop an item here to take it out of its category.", 1, 1, 1, true)
		end
		GameTooltip:AddLine("Right-click to move this section.", 0.8, 0.8, 0.8, true)
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
	header.window = self
	header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	header:SetScript("OnReceiveDrag", OnHeaderDrop)
	header:SetScript("OnClick", OnHeaderClick)
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

function Window:Pins()
	local pins = ns.db.pins[self.config.orderKey] or {}
	ns.db.pins[self.config.orderKey] = pins
	return pins
end

-- Pins itemID to a position in whatever group it shows in, or unpins it when position is nil.
function Window:Pin(itemID, position)
	self:Pins()[itemID] = position
	self.dirty = true
	self:Refresh()
end

-- Pinned items take their position in the group, the first of each item ID only; a taken or
-- out-of-range position falls to the next free one. Everything else fills the gaps in bag order.
function Window:Arrange(buttons, itemOf)
	local pins, count = self:Pins(), #buttons
	local placed, rest, taken, pinned = {}, {}, {}, {}
	for _, button in ipairs(buttons) do
		local itemID = itemOf[button]
		local position = itemID and not taken[itemID] and pins[itemID]
		if position then
			taken[itemID] = true
			pinned[button] = true
			position = math.min(position, count)
			while placed[position] do position = position % count + 1 end
			placed[position] = button
		else
			rest[#rest + 1] = button
		end
	end
	local free = 1
	for _, button in ipairs(rest) do
		while placed[free] do free = free + 1 end
		placed[free] = button
	end
	return placed, pinned
end

-- Sorts every slot into groups, in the window's order: an item in a category goes to that
-- category's group, everything else (empty slots too) to its section's.
local QUEST_CLASS = Enum.ItemClass and Enum.ItemClass.Questitem or 12
local QUEST_LABEL = "Quest Items"
-- itemID -> whether it is a quest item. An item's quest status doesn't change, so each is
-- looked up once per session.
local questItems = {}

local function IsQuestItem(itemID, bag, slot)
	local known = questItems[itemID]
	if known ~= nil then return known end
	local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
	local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
	known = classID == QUEST_CLASS or quest.isQuestItem == true or quest.questID ~= nil
	questItems[itemID] = known
	return known
end

function Window:Groups()
	local byKey, used, itemOf = {}, {}, {}
	-- Quest items gather on their own at the bottom, unless the player put one in a category.
	local quest = ns.db.questCategory and { label = QUEST_LABEL, auto = true, buttons = {} } or nil
	for _, category in ipairs(ns.Categories.List()) do
		byKey[ns.Categories.Key(category.id)] = { label = category.name, category = category.id, buttons = {} }
	end
	for _, section in ipairs(self.config.sections()) do
		local group = { label = section.label, buttons = {} }
		byKey[section.key] = group
		for _, bag in ipairs(section.bags) do
			local slots = C_Container.GetContainerNumSlots(bag)
			used[bag] = slots
			for slot = 1, slots do
				local button = self:Button(bag, slot)
				local itemID = C_Container.GetContainerItemID(bag, slot)
				itemOf[button] = itemID
				local id = ns.Categories.Of(itemID)
				local target = id and byKey[ns.Categories.Key(id)] or group
				if not id and quest and itemID and IsQuestItem(itemID, bag, slot) then target = quest end
				table.insert(target.buttons, button)
			end
		end
	end

	local groups, shownKeys, hasCategories = {}, {}, false
	for _, key in ipairs(self:Order()) do
		local group = byKey[key]
		if group and #group.buttons > 0 then
			group.key = key
			group.buttons, group.pinned = self:Arrange(group.buttons, itemOf)
			groups[#groups + 1] = group
			shownKeys[#shownKeys + 1] = key
			hasCategories = hasCategories or group.category ~= nil
		end
	end
	-- Always last and never in the order, so moves step past nothing hidden down there.
	if quest and #quest.buttons > 0 then
		quest.buttons, quest.pinned = self:Arrange(quest.buttons, itemOf)
		groups[#groups + 1] = quest
		hasCategories = true
	end
	self.shownKeys = shownKeys
	return groups, used, hasCategories
end

function Window:Layout()
	local start = debugprofilestop and debugprofilestop()
	local columns = ns.db[self.config.columnsKey]
	local step = SLOT_SIZE + SPACING
	local width = columns * step - SPACING
	local groups, used, labelled = self:Groups()
	local y, headerCount, placed = 0, 0, 0
	self.positions = {}

	for index, group in ipairs(groups) do
		placed = placed + #group.buttons
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
			header.key = group.key
			header.auto = group.auto
			header:Show()
			y = y + HEADER_HEIGHT
		end
		for n, button in ipairs(group.buttons) do
			local col, row = (n - 1) % columns, math.floor((n - 1) / columns)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self.content, "TOPLEFT", col * step, -(y + row * step))
			button:Show(); button.decoration:Show()
			self.positions[button] = n
			SetPinned(button, group.pinned[button] == true)
			self:UpdateButton(button)
		end
		y = y + math.ceil(#group.buttons / columns) * step - SPACING
	end

	for index = headerCount + 1, #self.headers do self.headers[index]:Hide() end
	-- Hide slots of bags that shrank, were removed or are switched off.
	for bag, slots in pairs(self.buttons) do
		for slot, button in pairs(slots) do
			if slot > (used[bag] or 0) then button:Hide(); button.decoration:Hide() end
		end
	end

	local height = math.max(y, SLOT_SIZE)
	self.content:SetSize(width, height)
	local bottom = INSET_BOTTOM + (self.config.bottomExtra or 0)
	self.frame:SetSize(width + PADDING * 2 + 10, height + PADDING * 2 + INSET_TOP + bottom)
	self:ReSkin()
	self:UpdateFooter()
	self.dirty = false
	if start then
		ns.stats.slotFrames = buttonCount * 2
		ns.RecordWork("layout", self.config.orderKey, debugprofilestop() - start, placed)
	end
end

-- Drawing re-applies Blizzard's quality border over a Masque skin, so the whole group is
-- skinned again after a pass, once, rather than per slot.
function Window:ReSkin()
	if self.masque then self.masque:ReSkin() end
end

function Window:UpdateAll()
	local start, count = debugprofilestop and debugprofilestop(), 0
	for _, slots in pairs(self.buttons) do
		for _, button in pairs(slots) do
			if button:IsShown() then
				self:UpdateButton(button)
				count = count + 1
			end
		end
	end
	self:ReSkin()
	if start then ns.RecordWork("update", self.config.orderKey, debugprofilestop() - start, count) end
end

-- Cooldowns change far more often than anything else (BAG_UPDATE_COOLDOWN fires on many
-- casts), so they skip reading item info: each slot keeps the icon it last drew.
function Window:UpdateCooldowns()
	local start, count = debugprofilestop and debugprofilestop(), 0
	for _, slots in pairs(self.buttons) do
		for _, button in pairs(slots) do
			local visual = button.decoration
			if visual.satchelTexture and button:IsShown() and visual.UpdateCooldown then
				visual:UpdateCooldown(visual.satchelTexture)
				count = count + 1
			end
		end
	end
	if start then ns.RecordWork("cooldowns", self.config.orderKey, debugprofilestop() - start, count) end
end

local WORK = { cooldowns = 1, update = 2, layout = 3 }

-- Events often come several to a frame (looting fires a few), so a window does the largest
-- piece of work they asked for once, on the next frame. Hidden windows only remember that
-- a layout is due; showing draws everything anyway.
function Window:Schedule(work)
	if not self.frame:IsShown() then
		if work == "layout" then self.dirty = true end
		return
	end
	if self.pending then
		if WORK[work] > WORK[self.pending] then self.pending = work end
		return
	end
	self.pending = work
	C_Timer.After(0, function()
		local pending = self.pending
		self.pending = nil
		if not self.frame:IsShown() then
			if pending == "layout" then self.dirty = true end
		elseif pending == "layout" then
			self:Layout()
		elseif pending == "update" then
			self:UpdateAll()
		else
			self:UpdateCooldowns()
		end
	end)
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

local function ShowOptionsMenu(gear)
	MenuUtil.CreateContextMenu(gear, function(_, root)
		ns.AddOptionsMenu(root)
		ns.Categories.AddManageMenu(root, gear.window)
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
	frame.Inset:SetPoint("BOTTOMRIGHT", -6, INSET_BOTTOM + (config.bottomExtra or 0))

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
		gear.window = self
		gear:SetScript("OnClick", ShowOptionsMenu)
		right = right - 24
	end
	if config.extraButton then
		local extra = config.extraButton
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(20, 20)
		button:SetPoint("TOPRIGHT", right, -28)
		button:SetNormalTexture(extra.icon)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button:SetScript("OnClick", extra.onClick)
		button:SetScript("OnEnter", function()
			GameTooltip:SetOwner(button, "ANCHOR_TOP")
			GameTooltip:SetText(extra.tooltip)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", GameTooltip_Hide)
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
		if self.config.onShow then self.config.onShow() end
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

local function ScheduleAll(work)
	return function()
		for _, window in ipairs(ns.windows) do window:Schedule(work) end
	end
end

ns.On("PLAYER_LOGIN", function()
	ns.On("BAG_UPDATE_DELAYED", ScheduleAll("layout"))
	ns.On("BAG_CONTAINER_UPDATE", ScheduleAll("layout"))
	ns.On("ITEM_LOCK_CHANGED", function(bag, slot)
		if slot then EachShown("UpdateSlot", bag, slot) end
	end)
	ns.On("PLAYER_MONEY", function() EachShown("UpdateFooter") end)
	ns.On("BAG_UPDATE_COOLDOWN", ScheduleAll("cooldowns"))
	for _, event in ipairs({ "INVENTORY_SEARCH_UPDATE", "BAG_NEW_ITEMS_UPDATED", "QUEST_ACCEPTED" }) do
		ns.On(event, ScheduleAll("update"))
	end
	local updateAll = ScheduleAll("update")
	ns.On("UNIT_QUEST_LOG_CHANGED", function(unit)
		if unit == "player" then updateAll() end
	end)
end)
