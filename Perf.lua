-- /satchel perf: a small window with Satchel's memory and redraw timings, refreshed every
-- second while it is open. Reading add-on memory walks every loaded add-on, so it runs only
-- while this window shows; so does logging to SatchelPerfLog (Core.lua).

local ADDON, ns = ...

local frame, text, ticker
local lastMemory

local function Update()
	UpdateAddOnMemoryUsage()
	local memory = GetAddOnMemoryUsage(ADDON)
	local growth = lastMemory and memory - lastMemory or 0
	lastMemory = memory
	ns.RecordMemory(memory)
	local stats = ns.stats
	local average = stats.layouts > 0 and stats.totalLayoutMs / stats.layouts or 0
	text:SetText(format(
		"Memory  %.0f KB  (%+.1f KB/s)\nSlot frames  %d\nRedraws  %d\nLast  %.2f ms   Avg  %.2f ms\nSlowest  %.2f ms",
		memory, growth, stats.slotFrames, stats.layouts, stats.lastLayoutMs, average, stats.maxLayoutMs))
end

local function Create()
	frame = CreateFrame("Frame", "SatchelPerfFrame", UIParent, "ButtonFrameTemplate")
	if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(frame) end
	if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(frame) end
	if frame.SetTitle then frame:SetTitle("Satchel perf (logging)") end
	frame:SetSize(240, 130)
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relativePoint, x, y = frame:GetPoint()
		ns.db.perfPosition = { point, relativePoint, x, y }
	end)
	local p = ns.db.perfPosition or { "CENTER", "CENTER", 0, 200 }
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	if frame.Inset then frame.Inset:Hide() end

	text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", 14, -30)
	text:SetJustifyH("LEFT")
	text:SetSpacing(3)

	frame:SetScript("OnShow", function()
		lastMemory = nil
		ns.StartLogging()
		Update()
		ticker = C_Timer.NewTicker(1, Update)
	end)
	frame:SetScript("OnHide", function()
		if ticker then ticker:Cancel() end
		ticker = nil
		ns.StopLogging()
	end)
	frame:Hide()
	table.insert(UISpecialFrames, "SatchelPerfFrame")
end

function ns.TogglePerf()
	if not frame then Create() end
	frame:SetShown(not frame:IsShown())
end
