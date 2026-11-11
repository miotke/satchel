-- Summarises the perf log Satchel saves while its perf window is open.
-- luajit tools/perf-report.lua ".../WTF/Account/<ACCOUNT>/SavedVariables/Satchel.lua"
--
-- The SavedVariables file is Lua that only assigns tables; it loads into an empty
-- environment, so it can't call anything.

local path = assert(arg[1], "usage: luajit tools/perf-report.lua <SavedVariables/Satchel.lua>")
local env = {}
local chunk = assert(loadfile(path))
setfenv(chunk, env)
chunk()
local log = env.SatchelPerfLog
if not (log and log.samples) then
	print("No perf log yet: open /satchel perf in game, play a while, then /reload.")
	return
end

local function percentile(sorted, p)
	if #sorted == 0 then return 0 end
	return sorted[math.max(1, math.ceil(#sorted * p))]
end

-- Sessions split the log by their start clock; entries belong to the latest session before them.
local sessions = log.sessions or {}
table.sort(sessions, function(a, b) return a.clock < b.clock end)
local function sessionOf(clock)
	local found
	for index, session in ipairs(sessions) do
		if session.clock <= clock then found = index end
	end
	return found or 0
end

for index, session in ipairs(sessions) do
	local samples, work = {}, {}
	for _, s in ipairs(log.samples) do if sessionOf(s[1]) == index then samples[#samples + 1] = s end end
	for _, w in ipairs(log.work) do if sessionOf(w[1]) == index then work[#work + 1] = w end end
	if #samples + #work > 0 then
		print(("Session %d  %s  build %s"):format(index, os.date("%Y-%m-%d %H:%M", session.started), session.build or "?"))

		if #samples > 1 then
			local first, last = samples[1], samples[#samples]
			local low, high, drops = math.huge, 0, 0
			for i, s in ipairs(samples) do
				low, high = math.min(low, s[2]), math.max(high, s[2])
				if i > 1 and s[2] < samples[i - 1][2] then drops = drops + 1 end
			end
			-- Least-squares slope: steady growth across garbage collections means a leak.
			local n, sx, sy, sxx, sxy = #samples, 0, 0, 0, 0
			for _, s in ipairs(samples) do
				local x = s[1] - first[1]
				sx, sy, sxx, sxy = sx + x, sy + s[2], sxx + x * x, sxy + x * s[2]
			end
			local slope = (n * sxy - sx * sy) / math.max(n * sxx - sx * sx, 1e-9)
			print(("  Memory   %.0f → %.0f KB  (low %.0f, high %.0f), trend %+.2f KB/s over %.0f s, %d collections"):format(
				first[2], last[2], low, high, slope, last[1] - first[1], drops))
		end

		local groups, order = {}, {}
		for _, w in ipairs(work) do
			local key = w[3] .. " " .. w[2] .. (w[6] == 1 and " (combat)" or "")
			if not groups[key] then groups[key] = { ms = {}, slots = 0 }; order[#order + 1] = key end
			table.insert(groups[key].ms, w[4])
			groups[key].slots = groups[key].slots + (w[5] or 0)
		end
		table.sort(order)
		if #order > 0 then
			print(("  %-28s %6s %8s %8s %8s %8s %6s"):format("work", "count", "avg ms", "p50", "p95", "max", "slots"))
		end
		for _, key in ipairs(order) do
			local g = groups[key]
			local total = 0
			for _, ms in ipairs(g.ms) do total = total + ms end
			table.sort(g.ms)
			print(("  %-28s %6d %8.2f %8.2f %8.2f %8.2f %6.0f"):format(key, #g.ms, total / #g.ms,
				percentile(g.ms, 0.5), percentile(g.ms, 0.95), g.ms[#g.ms], g.slots / #g.ms))
		end
	end
end
