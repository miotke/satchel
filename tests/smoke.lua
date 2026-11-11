-- Headless smoke test against stubbed WoW APIs: luajit tests/smoke.lua .
local function obj(name)
  local o = { _shown = false, _name = name, _scripts = {}, _hooks = {}, _points = {} }
  return setmetatable(o, { __index = function(t, k)
    if type(k) == "string" and k:sub(1, 7) == "satchel" then return nil end
    if k == "IsShown" then return function(s) return s._shown end end
    if k == "Show" then return function(s) local was = s._shown; s._shown = true; if not was and s._scripts.OnShow then s._scripts.OnShow(s) end end end
    if k == "Hide" then return function(s) local was=s._shown; s._shown = false; if was and s._scripts.OnHide then s._scripts.OnHide(s) end end end
    if k == "SetShown" then return function(s, v) if v then s:Show() else s:Hide() end end end
    if k == "SetScript" then return function(s, n, f) s._scripts[n] = f end end
    if k == "HookScript" then return function(s, n, f) s._hooks[n] = f end end
    if k == "SetPoint" then return function(s, ...) s._points[#s._points+1] = {...} end end
    if k == "ClearAllPoints" then return function(s) s._points = {} end end
    if k == "SetText" then return function(s, v) s._text = v end end
    if k == "SetFormattedText" then return function(s, f, ...) s._text = f:format(...) end end
    if k == "GetText" then return function(s) return s._text or "" end end
    if k == "SetSize" then return function(s, w, h) s._w, s._h = w, h end end
    if k == "SetAtlas" then return function() return true end end
    if k == "GetParent" then return function(s) return rawget(s, "_parent") end end
    if k == "CreateAnimationGroup" or k == "CreateAnimation" then return function() return obj() end end
    if k == "Play" then return function(s) rawset(s, "_playing", true) end end
    if k == "Stop" then return function(s) rawset(s, "_playing", false) end end
    if k == "IsPlaying" then return function(s) return rawget(s, "_playing") == true end end
    if k == "GetFrameLevel" then return function() return 1 end end
    if k == "CreateTexture" or k == "CreateFontString" then return function() return obj() end end
    if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 1, 2 end end
    if k == "Inset" or k == "CloseButton" or k == "ItemContextOverlay" or k == "NewItemTexture" or k == "BattlepayItemTexture" then
      local c = rawget(t, "_children"); c = c or {}; rawset(t, "_children", c); c[k] = c[k] or obj(); return c[k]
    end
    return function() end
  end })
end
created, frames = 0, {}
function CreateFrame(_, name, parent) created = created + 1; local o = obj(name); o._parent = parent; frames[#frames+1] = o; if name then _G[name] = o end; return o end
UIParent = obj(); UISpecialFrames = {}; NUM_BAG_SLOTS = 4; NUM_TOTAL_BAG_FRAMES = 6
BankFrame = obj(); BankPanel = obj(); BankPanel.MoneyDisplay = obj()
Enum = { BagIndex = { ReagentBag = 5, Keyring = -2, CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, CharacterBankTab_3 = 8 }, BankType = { Character = 0 } }
function ToggleKeyRing() end
slots = { [0]=16, 18, 18, 18, 18, 36, [-2]=12, [6]=28, [7]=0, [8]=20 }
items = {}  -- "bag:slot" -> itemID
infoCalls = 0
clock = 0; debugprofilestop = function() clock = clock + 1; return clock end
UpdateAddOnMemoryUsage = function() end; time = os.time; GetTime = function() clock = clock + 1; return clock end; GetBuildInfo = function() return "1.60.1" end; GetAddOnMemoryUsage = function() return 512 end; format = string.format
C_Container = {
  GetContainerNumSlots = function(b) return slots[b] or 0 end,
  GetContainerNumFreeSlots = function(b) return 3 end,
  GetContainerItemID = function(b, s) return items[b..":"..s] end,
  GetContainerItemInfo = function(b, s) infoCalls = infoCalls + 1; local id = items[b..":"..s]; if id then return { iconFileID = 1, stackCount = 1, quality = 3, hyperlink = "x" } end end,
  GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
  SetItemSearch = function() end, SortBags = function() end, SortBankBags = function() sortedBank = true end,
}
newCleared = 0; newItems = {}
C_NewItems = { ClearAll = function() newCleared = newCleared + 1; newItems = {} end,
  IsNewItem = function(b, s) return newItems[b .. ":" .. s] == true end,
  RemoveNewItem = function(b, s) newItems[b .. ":" .. s] = nil end }
C_Item = { GetItemNameByID = function() return "Shield" end }
local timers = {}
C_Timer = { After = function(_, f) timers[#timers+1] = f end }
hooks = {}
function hooksecurefunc(n, f) hooks[n] = f end
for _, n in ipairs{"SetItemButtonTexture","SetItemButtonCount","SetItemButtonDesaturated","SetItemButtonQuality","PlaySound","GameTooltip_Hide","StaticPopup_Show"} do _G[n] = function() end end
popups = {}
StaticPopup_Show = function(name, a, b, data) popups[#popups+1] = { name = name, data = data } end
StaticPopupDialogs = {}
SOUNDKIT = {}; GetMoney = function() return 12345 end; GetMoneyString = function() return "1g" end
UnitName = function() return "Me" end; InCombatLockdown = function() return false end
altDown = false; IsAltKeyDown = function() return altDown end
cursor = nil; GetCursorInfo = function() if cursor then return "item", cursor end end; ClearCursor = function() cursor = nil end
bankClosed = false; C_Bank = { CloseBankFrame = function() bankClosed = true end }
menus = {}
local function menuDesc()
  local d = { entries = {} }
  local function add(kind) return function(self, label, a, b) local e = menuDesc(); e.kind, e.label, e.a, e.b = kind, label, a, b; table.insert(self.entries, e); return e end end
  d.CreateDivider = add("divider"); d.CreateTitle = add("title"); d.CreateRadio = add("radio"); d.CreateButton = add("button"); d.CreateCheckbox = add("check")
  return d
end
MenuUtil = { CreateContextMenu = function(owner, gen) local root = menuDesc(); gen(owner, root); menus[#menus+1] = root end }
function find(root, label) for _, e in ipairs(root.entries) do if e.label == label then return e end end end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strsplit = function(sep, s) local a, b = s:match("^(%S*)%s*(.*)$"); return a, b ~= "" and b or nil end
SlashCmdList = {}
OKAY, CANCEL, DELETE, BANK = "Okay", "Cancel", "Delete", "Bank"

local ns = {}
for _, f in ipairs{"Core","Categories","Window","Bags","Bank","Perf"} do assert(loadfile(arg[1].."/"..f..".lua"))("Satchel", ns) end
local events = frames[2]  -- frames[1] is ns.hidden
local function flush() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end
local function fire(e, ...) events._scripts.OnEvent(events, e, ...); flush() end
fire("ADDON_LOADED", "Satchel"); fire("PLAYER_LOGIN")
-- login and /reload drop the flags the client sets while loading the bags, now and 2 s later
fire("PLAYER_ENTERING_WORLD", false, true); assert(newCleared == 2, "reload clears " .. newCleared)
fire("PLAYER_ENTERING_WORLD", false, false); assert(newCleared == 2, "zoning keeps new items")
newCleared = 0
local bag, bankw = ns.backpack, ns.bank
assert(BankFrame._scripts.OnEvent == nil)

-- open
hooks.OpenBackpack(); hooks.ToggleAllBags(); flush(); assert(bag:IsShown())
assert(newCleared == 0, "opening alone clears nothing")
bag:SetShown(false); assert(newCleared == 1, "closing clears, like Blizzard"); bag:SetShown(true)
local function headers(w) local t = {}; for _, h in ipairs(w.headers) do if h:IsShown() then t[#t+1] = h.text:GetText() end end; return table.concat(t, ",") end
assert(headers(bag) == "", "no headers without categories")
local h0 = bag.frame._h

-- create category and assign via alt-right-click menu
items["2:5"] = 111; items["0:1"] = 222; fire("BAG_UPDATE_DELAYED")
local btn = bag.buttons[2][5]
altDown = true; btn._hooks.OnClick(btn, "RightButton"); altDown = false
local m = menus[#menus]; assert(find(m, "New category…"), "item menu")
find(m, "New category…").a()
local p = popups[#popups]; p.data.callback("Tanking")
assert(ns.db.categories[1].name == "Tanking" and ns.db.categories[1].items[111])
assert(headers(bag) == "Tanking,Bags,Reagents", headers(bag))
-- the categorised button is placed first
assert(bag.buttons[2][5]._points[1][5] == -18 and bag.buttons[2][5]._points[1][4] == 0, "tank item top-left")
-- item moves bag (unequip/relocate): follows category
items["2:5"] = nil; items["3:1"] = 111; fire("BAG_UPDATE_DELAYED")
assert(bag.buttons[3][1]._points[1][4] == 0 and bag.buttons[3][1]._points[1][5] == -18)
-- item absent: category hidden
items["3:1"] = nil; fire("BAG_UPDATE_DELAYED"); assert(headers(bag) == "", headers(bag))
-- drop on header assigns
items["3:1"] = 111; fire("BAG_UPDATE_DELAYED")
cursor = 222; bag.headers[1]._scripts.OnReceiveDrag(bag.headers[1]); assert(cursor == nil and ns.Categories.Of(222) == 1)
-- move Tanking below Bags from the header's right-click menu, then back up from the gear menu
bag.headers[1]._scripts.OnClick(bag.headers[1], "RightButton")
local hm = menus[#menus]; assert(not find(hm, "Move up") and find(hm, "Move down") and find(hm, "Rename…"))
find(hm, "Move down").a(); assert(headers(bag) == "Bags,Tanking,Reagents", headers(bag))
assert(bag.buttons[0][2]._points[1][5] == -18, "bags first now")
-- a hidden keyring never swallows a move: Tanking moves past Reagents, then can't go further
bag:Move("category:1", 1); assert(headers(bag) == "Bags,Reagents,Tanking", headers(bag))
assert(not bag:CanMove("category:1", 1))
bag:Move("category:1", -1); bag:Move("category:1", -1); assert(headers(bag) == "Tanking,Bags,Reagents", headers(bag))
-- the bank keeps its own order
assert(ns.db.order.bank == nil or ns.db.order.bank[1] ~= "bags")
-- drop on Bags header removes
cursor = 222; bag.headers[2]._scripts.OnReceiveDrag(bag.headers[2]); assert(ns.Categories.Of(222) == nil)
-- duplicate name refused, rename, move, delete
assert(ns.Categories.Create("tanking") == nil)
assert(ns.Categories.Create("Healing") == 2)
assert(bag:Order()[1] == "category:2", "new category goes on top")
local g = {} ; MenuUtil.CreateContextMenu(nil, function(_, root) ns.AddOptionsMenu(root); ns.Categories.AddManageMenu(root, bag) end)
local manage = find(menus[#menus], "Categories"); assert(find(manage, "Tanking") and find(find(manage, "Tanking"), "Delete…"))
ns.Categories.Delete(1); assert(#ns.db.categories == 1 and headers(bag) == "", headers(bag))
fire("BAG_UPDATE_DELAYED"); assert(ns.db.order.backpack[1] == "category:2" and #ns.db.order.backpack == 4, "deleted key dropped")

-- bank
fire("BANKFRAME_OPENED"); assert(bankw:IsShown() and BankPanel:IsShown())
local n = 0; for b, s in pairs(bankw.buttons) do for _, x in pairs(s) do if x:IsShown() then n = n + 1; assert(x.decoration:IsShown()) end end end
assert(n == 48, "bank slots " .. n)
assert(bankw.freeText:GetText() == "6/48 free", bankw.freeText:GetText())
items["8:3"] = 111; ns.Categories.Assign(111, 2); assert(headers(bankw) == "Healing,Bank", headers(bankw))
bankw:Move("bank", -1); assert(headers(bankw) == "Bank,Healing", headers(bankw))
bankw.frame.CloseButton._scripts.OnClick(); assert(bankClosed)
fire("BANKFRAME_CLOSED"); assert(not bankw:IsShown() and not BankPanel:IsShown())
-- escape path
fire("BANKFRAME_OPENED"); bankClosed = false; hooks.CloseSpecialWindows(); assert(bankClosed)
fire("BANKFRAME_CLOSED"); bankClosed = false; hooks.CloseSpecialWindows(); assert(not bankClosed, "no close away from bank")

-- pins: item 333 sits at bag 4 slot 18 (position 88 of Bags); pin it to position 3
for k in pairs(items) do items[k] = nil end
items["4:18"] = 333; items["0:1"] = 444; fire("BAG_UPDATE_DELAYED")
local b333 = bag.buttons[4][18]
altDown = true; b333._hooks.OnClick(b333, "RightButton"); altDown = false
local pm = menus[#menus]; assert(find(pm, "Pin to this slot") and not find(pm, "Unpin"))
assert(bag.positions[b333] == 88, bag.positions[b333])
bag:Pin(333, 3)
assert(bag.positions[b333] == 3 and b333.decoration.satchelPin:IsShown(), "pinned to 3")
assert(bag.positions[bag.buttons[0][1]] == 1 and bag.positions[bag.buttons[0][3]] == 4, "others flow around")
-- the item moves physically (sort, unequip): it stays at position 3
items["4:18"] = nil; items["1:7"] = 333; fire("BAG_UPDATE_DELAYED")
assert(bag.positions[bag.buttons[1][7]] == 3 and bag.buttons[1][7].decoration.satchelPin:IsShown())
assert(not b333.decoration.satchelPin:IsShown(), "old slot loses the mark")
-- a second stack of the same item flows normally
items["2:2"] = 333; fire("BAG_UPDATE_DELAYED"); assert(bag.positions[bag.buttons[1][7]] == 3 and bag.positions[bag.buttons[2][2]] ~= 3)
-- clash: two items pinned to 3, second takes the next free
items["0:5"] = 555; bag:Pin(555, 3); assert(bag.positions[bag.buttons[0][5]] == 3 and bag.positions[bag.buttons[1][7]] == 4, "first in bag order keeps the spot")
-- out of range clamps to the end
bag:Pin(555, 999); assert(bag.positions[bag.buttons[0][5]] == 88, bag.positions[bag.buttons[0][5]])
-- unpin from the menu
local b = bag.buttons[1][7]; altDown = true; b._hooks.OnClick(b, "RightButton"); altDown = false
find(menus[#menus], "Unpin").a(); assert(bag:Pins()[333] == nil and not b.decoration.satchelPin:IsShown())
-- the bank has its own pins
assert(next(bankw:Pins()) == nil)

-- new-item glow: a looted item glows; hovering (the client clears the flag) stops it
items["0:9"] = 777; newItems["0:9"] = true; fire("BAG_UPDATE_DELAYED")
local nb = bag.buttons[0][9]
assert(nb.decoration.satchelGlow:IsShown() and nb.decoration.satchelGlow.pulse:IsPlaying(), "new item glows")
assert(not (bag.buttons[0][1].decoration.satchelGlow and bag.buttons[0][1].decoration.satchelGlow:IsShown()), "old item doesn't")
C_NewItems.RemoveNewItem(0, 9); nb._hooks.OnLeave(nb)
assert(not nb.decoration.satchelGlow:IsShown(), "hover clears glow")
newItems["0:9"] = true; fire("BAG_UPDATE_DELAYED"); bag:SetShown(false); bag:SetShown(true)
assert(not nb.decoration.satchelGlow:IsShown(), "closing the bag clears glow")

-- performance: a cooldown reads no item info; a burst of events is one layout
infoCalls = 0; fire("BAG_UPDATE_COOLDOWN"); assert(infoCalls == 0, "cooldown read item info " .. infoCalls)
local layouts = ns.stats.layouts
events._scripts.OnEvent(events, "BAG_UPDATE_DELAYED"); events._scripts.OnEvent(events, "BAG_CONTAINER_UPDATE")
events._scripts.OnEvent(events, "BAG_UPDATE_COOLDOWN"); events._scripts.OnEvent(events, "INVENTORY_SEARCH_UPDATE")
flush(); assert(ns.stats.layouts == layouts + 1, "burst made " .. (ns.stats.layouts - layouts) .. " layouts")
-- hidden windows do no work, then draw once when shown
bag:SetShown(false); layouts = ns.stats.layouts; infoCalls = 0
fire("BAG_UPDATE_DELAYED"); fire("BAG_UPDATE_COOLDOWN"); fire("INVENTORY_SEARCH_UPDATE")
assert(infoCalls == 0 and ns.stats.layouts == layouts, "hidden window worked")
bag:SetShown(true); assert(ns.stats.layouts == layouts + 1)
-- empty slots skip the quest lookup
local questCalls = 0; local q = C_Container.GetContainerItemQuestInfo
C_Container.GetContainerItemQuestInfo = function(...) questCalls = questCalls + 1; return q(...) end
fire("INVENTORY_SEARCH_UPDATE"); C_Container.GetContainerItemQuestInfo = q
local filled = 0; for _ in pairs(items) do filled = filled + 1 end
assert(questCalls <= filled, "quest lookups " .. questCalls)
tickers = {}; C_Timer.NewTicker = function(_, f) local t = { f = f, Cancel = function(self) self.cancelled = true end }; tickers[#tickers+1] = t; return t end
local mem = 500; GetAddOnMemoryUsage = function() mem = mem + 2; return mem end
SlashCmdList.SATCHEL("perf"); local pf = SatchelPerfFrame; assert(pf:IsShown() and #tickers == 1)
tickers[1].f(); local txt = ""; for _, r in ipairs(frames) do end
SlashCmdList.SATCHEL("perf"); assert(not pf:IsShown() and tickers[1].cancelled, "ticker stops when hidden")
SlashCmdList.SATCHEL("perf"); assert(#tickers == 2)
-- the perf window keeps everything in memory: nothing is saved
assert(SatchelDB.perfLog == nil and SatchelPerfLog == nil, "no saved logs")

SlashCmdList.SATCHEL("bankcols 8"); assert(ns.db.bankColumns == 8)
SlashCmdList.SATCHEL("new Gathering"); assert(ns.db.categories[2].name == "Gathering" and ns.db.categories[2].id == 3)
SlashCmdList.SATCHEL("reset"); SlashCmdList.SATCHEL("keyring"); SlashCmdList.SATCHEL("help")
-- The clickable button must carry no add-on-written fields Blizzard's click reads.
for _, w in ipairs(ns.windows) do for _, slots in pairs(w.buttons) do for _, b in pairs(slots) do
  for k in pairs(b) do
    assert(k:sub(1,1) == "_" or k == "decoration" or k == "satchelBag" or k == "satchelSlot", "clickable button field " .. k)
  end
end end end
print("ok", created)
