-- Player-made categories. An item belongs to at most one, by item ID, so it returns to its
-- category wherever it lands: after unequipping it, looting another or moving it between bags.
-- Each category has a stable id; where it shows is each window's order (Window:Order).

local _, ns = ...

local Categories = {}
ns.Categories = Categories

function Categories.List()
	return ns.db.categories
end

function Categories.Get(id)
	for _, category in ipairs(ns.db.categories) do
		if category.id == id then return category end
	end
	return nil
end

function Categories.Key(id)
	return "category:" .. id
end

-- itemID -> category id, so a layout looks each slot up once instead of scanning every
-- category. Rebuilt on the next lookup after any change.
local itemIndex

-- The id of the category holding itemID, or nil.
function Categories.Of(itemID)
	if not itemID then return nil end
	if not itemIndex then
		itemIndex = {}
		for _, category in ipairs(ns.db.categories) do
			for id in pairs(category.items) do itemIndex[id] = category.id end
		end
	end
	return itemIndex[itemID]
end

-- Puts itemID in the category with id, or in none when id is nil.
function Categories.Assign(itemID, id)
	for _, category in ipairs(ns.db.categories) do category.items[itemID] = nil end
	local category = id and Categories.Get(id)
	if category then category.items[itemID] = true end
	itemIndex = nil
	ns.RefreshAll()
end

local function CleanName(name)
	name = strtrim(name or "")
	if name == "" then return nil end
	for _, category in ipairs(ns.db.categories) do
		if category.name:lower() == name:lower() then
			ns.Print("a category named " .. category.name .. " already exists")
			return nil
		end
	end
	return name
end

-- Returns the new category's id, or nil when the name is empty or taken.
function Categories.Create(name)
	name = CleanName(name)
	if not name then return nil end
	local id = ns.db.nextCategoryID
	ns.db.nextCategoryID = id + 1
	table.insert(ns.db.categories, { id = id, name = name, items = {} })
	return id
end

function Categories.Rename(id, name)
	name = CleanName(name)
	local category = Categories.Get(id)
	if not (name and category) then return end
	category.name = name
	ns.RefreshAll()
end

function Categories.Delete(id)
	for index, category in ipairs(ns.db.categories) do
		if category.id == id then table.remove(ns.db.categories, index) break end
	end
	itemIndex = nil
	ns.RefreshAll()
end

local function EditBox(dialog)
	return dialog.editBox or dialog.EditBox
end

StaticPopupDialogs.SATCHEL_CATEGORY_NAME = {
	text = "%s",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 32,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(self, data)
		local box = EditBox(self)
		box:SetText(data.initial or "")
		box:HighlightText()
		box:SetFocus()
	end,
	OnAccept = function(self, data)
		data.callback(EditBox(self):GetText())
	end,
	EditBoxOnEnterPressed = function(box, data)
		data.callback(box:GetText())
		box:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(box)
		box:GetParent():Hide()
	end,
}

StaticPopupDialogs.SATCHEL_DELETE_CATEGORY = {
	text = "Delete the %s category? Its items go back to your bags.",
	button1 = DELETE,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnAccept = function(_, data) Categories.Delete(data.id) end,
}

local function PromptName(title, initial, callback)
	StaticPopup_Show("SATCHEL_CATEGORY_NAME", title, nil, { initial = initial, callback = callback })
end

function Categories.PromptNew(itemID)
	PromptName("New category", "", function(name)
		local id = Categories.Create(name)
		if id then
			if itemID then Categories.Assign(itemID, id) else ns.RefreshAll() end
		end
	end)
end

function Categories.PromptRename(id)
	local category = Categories.Get(id)
	PromptName("Rename " .. category.name, category.name, function(name) Categories.Rename(id, name) end)
end

function Categories.ConfirmDelete(id)
	StaticPopup_Show("SATCHEL_DELETE_CATEGORY", Categories.Get(id).name, nil, { id = id })
end

-- Alt+right-click on an item; position is where it shows in window, for pinning.
function Categories.ShowItemMenu(owner, itemID, window, position)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(C_Item.GetItemNameByID(itemID) or "Category")
		for _, category in ipairs(ns.db.categories) do
			root:CreateRadio(category.name,
				function() return Categories.Of(itemID) == category.id end,
				function() Categories.Assign(itemID, category.id) end)
		end
		root:CreateButton("New category…", function() Categories.PromptNew(itemID) end)
		if Categories.Of(itemID) then
			root:CreateButton("Remove from category", function() Categories.Assign(itemID, nil) end)
		end
		if window and position then
			root:CreateDivider()
			if window:Pins()[itemID] then
				root:CreateButton("Unpin", function() window:Pin(itemID, nil) end)
			else
				root:CreateButton("Pin to this slot", function() window:Pin(itemID, position) end)
			end
		end
	end)
end

-- Move up and Move down for one entry of window's order.
function Categories.AddMoveButtons(menu, window, key)
	if window:CanMove(key, -1) then menu:CreateButton("Move up", function() window:Move(key, -1) end) end
	if window:CanMove(key, 1) then menu:CreateButton("Move down", function() window:Move(key, 1) end) end
end

-- The gear menu's Categories submenu, for the window whose gear was clicked.
function Categories.AddManageMenu(root, window)
	local menu = root:CreateButton("Categories")
	menu:CreateButton("New category…", function() Categories.PromptNew() end)
	for _, category in ipairs(ns.db.categories) do
		local entry = menu:CreateButton(category.name)
		entry:CreateButton("Rename…", function() Categories.PromptRename(category.id) end)
		Categories.AddMoveButtons(entry, window, Categories.Key(category.id))
		entry:CreateButton("Delete…", function() Categories.ConfirmDelete(category.id) end)
	end
end
