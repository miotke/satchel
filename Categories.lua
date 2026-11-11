-- Player-made categories. An item belongs to at most one, by item ID, so it returns to its
-- category wherever it lands: after unequipping it, looting another or moving it between bags.

local _, ns = ...

local Categories = {}
ns.Categories = Categories

function Categories.List()
	return ns.db.categories
end

-- The index of the category holding itemID, or nil.
function Categories.Of(itemID)
	if not itemID then return nil end
	for index, category in ipairs(ns.db.categories) do
		if category.items[itemID] then return index end
	end
	return nil
end

-- Puts itemID in the category at index, or in none when index is nil.
function Categories.Assign(itemID, index)
	for _, category in ipairs(ns.db.categories) do category.items[itemID] = nil end
	if index and ns.db.categories[index] then ns.db.categories[index].items[itemID] = true end
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

-- Returns the new category's index, or nil when the name is empty or taken.
function Categories.Create(name)
	name = CleanName(name)
	if not name then return nil end
	table.insert(ns.db.categories, { name = name, items = {} })
	return #ns.db.categories
end

function Categories.Rename(index, name)
	name = CleanName(name)
	if not name then return end
	ns.db.categories[index].name = name
	ns.RefreshAll()
end

function Categories.Delete(index)
	table.remove(ns.db.categories, index)
	ns.RefreshAll()
end

function Categories.Move(index, offset)
	local list = ns.db.categories
	local target = index + offset
	if not list[target] then return end
	list[index], list[target] = list[target], list[index]
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
	OnAccept = function(_, data) Categories.Delete(data.index) end,
}

local function PromptName(title, initial, callback)
	StaticPopup_Show("SATCHEL_CATEGORY_NAME", title, nil, { initial = initial, callback = callback })
end

function Categories.PromptNew(itemID)
	PromptName("New category", "", function(name)
		local index = Categories.Create(name)
		if index then
			if itemID then Categories.Assign(itemID, index) else ns.RefreshAll() end
		end
	end)
end

-- Alt+right-click on an item.
function Categories.ShowItemMenu(owner, itemID)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(C_Item.GetItemNameByID(itemID) or "Category")
		for index, category in ipairs(ns.db.categories) do
			root:CreateRadio(category.name,
				function() return Categories.Of(itemID) == index end,
				function() Categories.Assign(itemID, index) end)
		end
		root:CreateButton("New category…", function() Categories.PromptNew(itemID) end)
		if Categories.Of(itemID) then
			root:CreateButton("Remove from category", function() Categories.Assign(itemID, nil) end)
		end
	end)
end

-- The gear menu's Categories submenu.
function Categories.AddManageMenu(root)
	local menu = root:CreateButton("Categories")
	menu:CreateButton("New category…", function() Categories.PromptNew() end)
	for index, category in ipairs(ns.db.categories) do
		local entry = menu:CreateButton(category.name)
		entry:CreateButton("Rename…", function()
			PromptName("Rename " .. category.name, category.name, function(name) Categories.Rename(index, name) end)
		end)
		if index > 1 then entry:CreateButton("Move up", function() Categories.Move(index, -1) end) end
		if index < #ns.db.categories then entry:CreateButton("Move down", function() Categories.Move(index, 1) end) end
		entry:CreateButton("Delete…", function()
			StaticPopup_Show("SATCHEL_DELETE_CATEGORY", category.name, nil, { index = index })
		end)
	end
end
