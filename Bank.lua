-- The bank window. Forever's character bank is tabs: CharacterBankTab_1 is the fixed base
-- bank, and each later tab is a bag socket with slots only once a bag is in it. Forever has
-- no warband bank.
--
-- Blizzard's BankFrame lives on under a hidden parent. Its BankPanel must stay shown, with
-- the character bank type set, because Blizzard's own deposit code asks it which bank is
-- open. It is only touched while the bank is open: touching it earlier taints it and breaks
-- using items from any bag (learned from BetterBags).

local _, ns = ...

local bank
local bagsOpenedByBank = false
ns.atBank = false

function ns.BankBags()
	local bags = {}
	for tab = 1, 20 do
		local bag = Enum.BagIndex["CharacterBankTab_" .. tab]
		if not bag then break end
		if C_Container.GetContainerNumSlots(bag) > 0 then bags[#bags + 1] = bag end
	end
	return bags
end

local function Sections()
	return { { key = "bank", label = "Bank", bags = ns.BankBags() } }
end

local function CloseBank()
	if C_Bank and C_Bank.CloseBankFrame then C_Bank.CloseBankFrame() else CloseBankFrame() end
end

local function Sort()
	if C_Container.SortBankBags then
		C_Container.SortBankBags()
	elseif C_Container.SortBank and Enum.BankType then
		C_Container.SortBank(Enum.BankType.Character)
	end
end

local function HideBlizzardBank()
	if not BankFrame then return end
	BankFrame:SetParent(ns.hidden)
	BankFrame:SetScript("OnHide", nil)
	BankFrame:SetScript("OnShow", nil)
	BankFrame:SetScript("OnEvent", nil)
end

-- Its money display stays registered for PLAYER_MONEY while invisible and, once the panel
-- is hidden, errors on the next gold change. Nothing else re-registers it.
local function SilenceMoneyDisplay()
	if BankPanel and BankPanel.MoneyDisplay then BankPanel.MoneyDisplay:UnregisterEvent("PLAYER_MONEY") end
end

ns.On("PLAYER_LOGIN", function()
	if not (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1) then return end
	bank = ns.CreateWindow({
		name = "SatchelBankFrame",
		title = BANK or "Bank",
		positionKey = "bankPosition",
		defaultPoint = { "TOPLEFT", "TOPLEFT", 40, -120 },
		columnsKey = "bankColumns",
		orderKey = "bank",
		sectionKeys = { "bank" },
		sections = Sections,
		sort = (C_Container.SortBankBags or C_Container.SortBank) and Sort or nil,
		close = CloseBank,
		masqueGroup = "Bank",
		bottomExtra = ns.BankTabsSupported() and ns.BANK_TABS_HEIGHT or nil,
	})
	ns.bank = bank
	ns.CreateBankTabs(bank)
	HideBlizzardBank()

	-- Escape hides the window through UISpecialFrames; leave banking mode with it.
	hooksecurefunc("CloseSpecialWindows", function()
		if ns.atBank then CloseBank() end
	end)

	-- The saved copy (BankCache.lua): bank contents load a moment after the bank opens and
	-- change while it is open, so copy once they are in and again after changes, at most
	-- twice a second, and a last time as the bank closes.
	local copyPending = false
	local function SaveCopySoon()
		if copyPending then return end
		copyPending = true
		C_Timer.After(0.5, function()
			copyPending = false
			if ns.atBank then ns.SaveBankCopy() end
		end)
	end
	ns.On("BAG_UPDATE_DELAYED", function()
		if ns.atBank then SaveCopySoon() end
	end)

	ns.On("BANKFRAME_OPENED", function()
		ns.atBank = true
		ns.HideBankCopy()
		C_Timer.After(1.5, SaveCopySoon)
		if BankPanel then
			if BankPanel.SetBankType and Enum.BankType then BankPanel:SetBankType(Enum.BankType.Character) end
			BankPanel:SetAlpha(0)
			BankPanel:EnableMouse(false)
			BankPanel:EnableKeyboard(false)
			BankPanel:Show()
			SilenceMoneyDisplay()
		end
		bank:SetShown(true)
		ns.UpdateBankTabs()
		-- Like Blizzard's bank, open the bags beside it, and close them again with it only if
		-- the bank opened them.
		bagsOpenedByBank = not ns.backpack:IsShown()
		ns.backpack:SetShown(true)
	end)

	ns.On("BANKFRAME_CLOSED", function()
		if ns.atBank then ns.SaveBankCopy() end
		ns.atBank = false
		bank:SetShown(false)
		if bagsOpenedByBank then ns.backpack:SetShown(false) end
		bagsOpenedByBank = false
		if BankPanel then BankPanel:Hide() end
		SilenceMoneyDisplay()
	end)

	-- A tab bought, or a bag put in or taken out of a tab's socket.
	for _, event in ipairs({ "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED", "BAG_CONTAINER_UPDATE" }) do
		pcall(ns.On, event, function()
			if not ns.atBank then return end
			bank:Refresh()
			ns.UpdateBankTabs()
		end)
	end
	ns.On("PLAYER_REGEN_ENABLED", function()
		if ns.atBank then ns.UpdateBankTabs() end
	end)
end)
