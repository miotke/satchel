-- The bank's tab bar: one button per character bank tab after the first. On Forever each of
-- those tabs is a bag socket with slots only once a bag is in it (Bank.lua). A bought tab
-- takes a bag by drop or click and gives it back by drag. The next tab to buy shows a plus;
-- buying is protected, so that button is Blizzard's purchase template with its own click.

local _, ns = ...

local SIZE = 28
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local PLUS_ATLAS = "Garr_Building-AddFollowerPlus"
local SOCKETS = Enum.BagIndex and Enum.BagIndex.Characterbanktab
local CHARACTER = Enum.BankType and Enum.BankType.Character

ns.BANK_TABS_HEIGHT = SIZE + 8

-- { bag = Enum.BagIndex of the tab, socket = its slot in SOCKETS, button, purchase }
local tabs = {}

function ns.BankTabsSupported()
	return SOCKETS ~= nil and CHARACTER ~= nil and C_Bank ~= nil and C_Bank.FetchPurchasedBankTabData ~= nil
		and Enum.BagIndex.CharacterBankTab_2 ~= nil
end

local function Location(tab)
	return ItemLocation:CreateFromBagAndSlot(SOCKETS, tab.socket)
end

local function HasBag(tab)
	return C_Item.DoesItemExist(Location(tab))
end

-- Picks up the socket's bag, places the cursor's bag in it, or swaps the two, like
-- Blizzard's own bank bag buttons.
local function PickupBag(tab)
	if InCombatLockdown() then
		ns.Print("bank bags can't be changed in combat")
		return
	end
	C_Container.PickupContainerItem(SOCKETS, tab.socket)
end

local function OnEnter(button)
	local tab = button.tab
	GameTooltip:SetOwner(button, "ANCHOR_TOP")
	if HasBag(tab) then
		GameTooltip:SetBagItem(SOCKETS, tab.socket)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Drag to take this bag out. Drop a bag here to swap it.", 0.8, 0.8, 0.8, true)
	else
		GameTooltip:SetText("Empty bank bag slot", 1, 1, 1)
		GameTooltip:AddLine("Drop a bag here to add its slots to your bank.", 0.8, 0.8, 0.8, true)
	end
	GameTooltip:Show()
end

local function OnPurchaseEnter(button)
	GameTooltip:SetOwner(button, "ANCHOR_TOP")
	GameTooltip:SetText("Buy a bank tab", 1, 1, 1)
	local nextTab = C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(CHARACTER)
	if nextTab and nextTab.tabCost then GameTooltip:AddLine(GetMoneyString(nextTab.tabCost, true), 1, 1, 1) end
	GameTooltip:AddLine("Each tab holds one bag.", 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end

local function OnClick(button)
	if GetCursorInfo() == "item" or IsModifiedClick("PICKUPITEM") then PickupBag(button.tab) end
end

local function OnDrag(button)
	PickupBag(button.tab)
end

function ns.CreateBankTabs(window)
	if not ns.BankTabsSupported() then return end
	local bar = CreateFrame("Frame", nil, window.frame)
	bar:SetPoint("BOTTOMLEFT", 12, 30)
	bar:SetSize(1, SIZE)

	for index = 2, 20 do
		local bag = Enum.BagIndex["CharacterBankTab_" .. index]
		if not bag then break end
		local tab = { bag = bag, socket = index }

		local button = CreateFrame("Button", nil, bar)
		button:SetSize(SIZE, SIZE)
		button:SetPoint("LEFT", #tabs * (SIZE + 4), 0)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints()
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button:RegisterForDrag("LeftButton")
		button:SetScript("OnClick", OnClick)
		button:SetScript("OnDragStart", OnDrag)
		button:SetScript("OnReceiveDrag", OnDrag)
		button:SetScript("OnEnter", OnEnter)
		button:SetScript("OnLeave", GameTooltip_Hide)
		button.tab = tab

		-- Never set its OnClick: the template's own opens Blizzard's purchase dialog.
		local purchase = CreateFrame("Button", "SatchelBuyBankTab" .. index, bar, "BankPanelPurchaseButtonScriptTemplate")
		purchase:SetAttribute("overrideBankType", CHARACTER)
		purchase:SetAllPoints(button)
		local plus = purchase:CreateTexture(nil, "ARTWORK")
		plus:SetPoint("CENTER")
		plus:SetSize(SIZE, SIZE)
		plus:SetAtlas(PLUS_ATLAS)
		purchase:SetScript("OnEnter", OnPurchaseEnter)
		purchase:SetScript("OnLeave", GameTooltip_Hide)
		purchase:Hide()

		tab.button, tab.purchase = button, purchase
		tabs[#tabs + 1] = tab
	end
end

-- Bought tabs show their bag (or an empty socket); of the rest only the next one, the only
-- one that can be bought, shows a plus. The purchase buttons are protected, so they change
-- only out of combat; PLAYER_REGEN_ENABLED catches up.
function ns.UpdateBankTabs()
	if #tabs == 0 then return end
	local bought = {}
	for _, data in ipairs(C_Bank.FetchPurchasedBankTabData(CHARACTER) or {}) do bought[data.ID] = true end
	local canBuy = not C_Bank.CanPurchaseBankTab or C_Bank.CanPurchaseBankTab(CHARACTER)
	local combat = InCombatLockdown()
	local offered = false
	for _, tab in ipairs(tabs) do
		if bought[tab.bag] then
			tab.button.icon:SetTexture(HasBag(tab) and C_Item.GetItemIcon(Location(tab)) or EMPTY_BAG)
			tab.button:Show()
			if not combat then tab.purchase:Hide() end
		else
			tab.button:Hide()
			if not combat then tab.purchase:SetShown(canBuy and not offered) end
			offered = true
		end
	end
end
