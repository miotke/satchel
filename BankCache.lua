-- The bank away from a banker. While the bank is open, Satchel keeps a copy of what is in
-- it in SatchelDB.bankCache, per character; /satchel bank and the backpack's bank button
-- show that copy read-only. Its buttons are plain ones, not Blizzard's: a slot that isn't
-- reachable can't be used, so they only show the item, its tooltip and a chat link.

local _, ns = ...

local SLOT_SIZE, SPACING = 37, 4
local INSET_TOP, INSET_BOTTOM, PADDING = 54, 28, 8
local EMPTY_SLOT_ATLAS = "bags-item-slot64"

local frame, content, search, savedText, freeText
local slotButtons = {}

local function Key()
	return UnitName("player") .. "-" .. GetRealmName()
end

local function Cache()
	return ns.db.bankCache and ns.db.bankCache[Key()]
end

-- Copies the open bank. Bank contents load a moment after the bank opens, so a copy with no
-- slots yet would wipe a good one; that is never saved.
function ns.SaveBankCopy()
	local slots, total = {}, 0
	for _, bag in ipairs(ns.BankBags()) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			total = total + 1
			local info = C_Container.GetContainerItemInfo(bag, slot)
			slots[total] = info and { info.itemID, info.stackCount, info.quality, info.iconFileID, info.hyperlink } or false
		end
	end
	if total == 0 then return end
	ns.db.bankCache = ns.db.bankCache or {}
	ns.db.bankCache[Key()] = { saved = time(), slots = slots }
	if frame and frame:IsShown() then ns.DrawBankCopy() end
end

local function Ago(seconds)
	if seconds < 60 then return "just now" end
	if seconds < 3600 then return format("%d min ago", seconds / 60) end
	if seconds < 86400 then return format("%d h ago", seconds / 3600) end
	return date("%b %d", time() - seconds)
end

local function ItemName(link)
	return link and link:match("|h%[(.-)%]|h") or ""
end

local function OnEnter(button)
	if not button.link then return end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(button.link)
	GameTooltip:Show()
end

local function OnClick(button)
	if button.link then HandleModifiedItemClick(button.link) end
end

local function SlotButton(index)
	local button = slotButtons[index]
	if button then return button end
	button = CreateFrame("Button", nil, content)
	button:SetSize(SLOT_SIZE, SLOT_SIZE)
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	if not background:SetAtlas(EMPTY_SLOT_ATLAS) then
		background:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
	end
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetAllPoints()
	button.border:SetTexture("Interface\\Common\\WhiteIconFrame")
	button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	button.count:SetPoint("BOTTOMRIGHT", -2, 2)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnClick", OnClick)
	slotButtons[index] = button
	return button
end

local function Filter()
	local query = search:GetText():lower()
	for _, button in ipairs(slotButtons) do
		local match = query == "" or (button.name ~= nil and button.name:lower():find(query, 1, true) ~= nil)
		button:SetAlpha(match and 1 or 0.25)
	end
end

function ns.DrawBankCopy()
	local cache = Cache()
	local slots = cache and cache.slots or {}
	local columns = ns.db.bankColumns
	local step = SLOT_SIZE + SPACING
	local free = 0
	for index, entry in ipairs(slots) do
		local button = SlotButton(index)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", (index - 1) % columns * step, -math.floor((index - 1) / columns) * step)
		if entry then
			local _, count, quality, icon, link = unpack(entry)
			button.icon:SetTexture(icon)
			button.count:SetText(count and count > 1 and count or "")
			local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
			button.border:SetShown(color ~= nil and quality > 1)
			if color then button.border:SetVertexColor(color.r, color.g, color.b) end
			button.link, button.name = link, ItemName(link)
		else
			free = free + 1
			button.icon:SetTexture(nil)
			button.count:SetText("")
			button.border:Hide()
			button.link, button.name = nil, nil
		end
		button:Show()
	end
	for index = #slots + 1, #slotButtons do slotButtons[index]:Hide() end

	local rows = math.max(math.ceil(#slots / columns), 1)
	local width, height = columns * step - SPACING, rows * step - SPACING
	content:SetSize(width, height)
	frame:SetSize(width + PADDING * 2 + 10, height + PADDING * 2 + INSET_TOP + INSET_BOTTOM)
	if cache then
		savedText:SetText("Saved " .. Ago(time() - cache.saved))
		freeText:SetFormattedText("%d/%d free", free, #slots)
	else
		savedText:SetText("Visit a banker to save a copy of your bank.")
		freeText:SetText("")
	end
	Filter()
end

local function Create()
	frame = CreateFrame("Frame", "SatchelBankCopyFrame", UIParent, "ButtonFrameTemplate")
	if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
	if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(frame) end
	if frame.SetTitle then frame:SetTitle((BANK or "Bank") .. " (saved copy)") end
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relativePoint, x, y = frame:GetPoint()
		ns.db.bankCopyPosition = { point, relativePoint, x, y }
	end)
	frame:SetScale(ns.db.scale)
	local p = ns.db.bankCopyPosition or { "TOPLEFT", "TOPLEFT", 40, -120 }
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	frame.Inset:ClearAllPoints()
	frame.Inset:SetPoint("TOPLEFT", 4, -INSET_TOP)
	frame.Inset:SetPoint("BOTTOMRIGHT", -6, INSET_BOTTOM)

	content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", PADDING, -PADDING)

	search = CreateFrame("EditBox", "SatchelBankCopySearchBox", frame, "SearchBoxTemplate")
	search:SetHeight(20)
	search:SetPoint("TOPLEFT", 16, -28)
	search:SetPoint("TOPRIGHT", -16, -28)
	search:HookScript("OnTextChanged", Filter)

	savedText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	savedText:SetPoint("BOTTOMLEFT", 14, 9)
	freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	freeText:SetPoint("BOTTOMRIGHT", -14, 9)

	frame:SetScript("OnShow", ns.DrawBankCopy)
	frame:SetScript("OnHide", function()
		if search:GetText() ~= "" then search:SetText("") end
		search:ClearFocus()
	end)
	frame:Hide()
	table.insert(UISpecialFrames, "SatchelBankCopyFrame")
end

-- At a banker the real bank is open, so the copy isn't needed.
function ns.ToggleBankCopy()
	if ns.atBank then
		ns.Print("your bank is open")
		return
	end
	if not frame then Create() end
	frame:SetShown(not frame:IsShown())
end

function ns.HideBankCopy()
	if frame then frame:Hide() end
end
