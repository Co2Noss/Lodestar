local addonName, LS = ...

-- Anonymous usage counts -------------------------------------------------------
--
-- The question this answers is which parts of Lodestar are dead. A tile nobody keeps
-- on their dashboard, a goal nobody turns on, and a settings tab nobody opens all look
-- identical from here: they are guesses. Counting them turns "I think Housing is
-- unpopular" into a number, and a feature that is genuinely unused can be cut or fixed
-- instead of maintained forever.
--
-- Three rules hold everything below together:
--
-- 1. Nothing identifies anybody. Only Lodestar's own setting names, tile IDs, and the
--    names of addons we integrate with are ever recorded. No character, guild, realm,
--    or account values, and no free text a player typed, which is also what Wago's
--    terms require. AnalyticsReport prints the entire payload so that is checkable
--    rather than something to take on faith.
-- 2. Nothing leaves the machine because of this file. The Shim is a stub unless the
--    player installed the Wago App and turned data sharing on there. Without it every
--    call here writes to an in-memory table and stops.
-- 3. Recording never breaks the addon. Every call into the sink is wrapped, and a
--    failure permanently disables the sink rather than erroring once per page view.

local WAGO_LIB = "WagoAnalytics"

-- Explicit rather than derived from db.goals: pairs order is undefined, and a stable
-- order keeps the printed report readable and diffable between sessions.
local GOALS = { "ENDGAME", "SOLO", "PREY", "PVP", "HOUSING", "CRAFTING", "MOUNTS", "PETS", "REPUTATION", "QUESTING", "GOLD" }

local function store(self)
  self.analytics = self.analytics or { switches = {}, counters = {} }
  return self.analytics
end

-- Recording is on unless the player turned it off here. The Wago App is a second,
-- independent opt-in, so a player who never installed it is already opted out.
function LS:AnalyticsOn()
  return not (self.db and self.db.analytics == false)
end

function LS:SetAnalytics(on)
  if not self.db then return end
  self.db.analytics = on and true or false
  if on then
    self:StartAnalytics()
  end
end

-- The sink is whatever the Wago App installed, or nil. RegisterAddon reads X-Wago-ID
-- from the .toc and returns false when it is absent, which is the state Lodestar ships
-- in, so analytics stay dormant until that ID names a project opted in on Wago.
function LS:AnalyticsSink()
  if self.analyticsSink ~= nil then
    return self.analyticsSink or nil
  end
  if not LibStub then return end
  -- Checked here rather than left to the Shim: an X-Wago-ID line that is present but
  -- blank reads as an empty string, which is truthy, and the Shim would register that
  -- as a project ID. Treat anything that is not a real ID as not configured.
  local meta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  local id = meta and select(2, pcall(meta, addonName, "X-Wago-ID"))
  if type(id) ~= "string" or id:match("^%s*$") then
    self.analyticsSink = false
    return
  end
  local ok, lib = pcall(function() return LibStub:GetLibrary(WAGO_LIB, true) end)
  if not ok or type(lib) ~= "table" or type(lib.RegisterAddon) ~= "function" then return end
  local got, sink = pcall(lib.RegisterAddon, lib, addonName)
  if not got or type(sink) ~= "table" then
    self.analyticsSink = false
    return
  end
  self.analyticsSink = sink
  return sink
end

-- Whether anything is actually being collected, which is not the same as having a sink.
-- The Shim hands back a table either way: with no Wago App it is a stub whose methods
-- do nothing, so a non-nil sink would report "sharing" on every install once Lodestar
-- ships the Shim and an ID. The collector addon's own global is the honest signal, and
-- it is what decides whether the player is shown a setting that could do anything.
function LS:AnalyticsSharing()
  if not _G.WagoAnalytics then return false end
  return self:AnalyticsSink() ~= nil
end

-- One bad call disables the sink for the session. These fire from page views and chat
-- handlers, so a sink that throws would otherwise throw over and over.
local function send(self, method, ...)
  local sink = self:AnalyticsSink()
  if not sink or type(sink[method]) ~= "function" then return end
  if not pcall(sink[method], sink, ...) then
    self.analyticsSink = false
  end
end

-- A binary "is this in use", recorded even when false: Wago only counts a session
-- towards a switch's active rate if that session recorded it either way, so writing
-- only the true cases would report every feature at 100% use.
function LS:Flag(name, on)
  if not self:AnalyticsOn() or type(name) ~= "string" then return end
  on = on and true or false
  store(self).switches[name] = on
  send(self, "Switch", name, on)
end

function LS:Count(name, by)
  if not self:AnalyticsOn() or type(name) ~= "string" then return end
  by = tonumber(by) or 1
  local counters = store(self).counters
  counters[name] = (counters[name] or 0) + by
  send(self, "IncrementCounter", name, by)
end

-- For a value that is already a total, such as how many tiles are on the dashboard.
-- Incrementing those would measure how often the count was taken.
function LS:Measure(name, value)
  if not self:AnalyticsOn() or type(name) ~= "string" then return end
  value = tonumber(value)
  if not value then return end
  store(self).counters[name] = value
  send(self, "SetCounter", name, value)
end

-- The shape of this install: which goals, tiles, integrations, and settings are on.
-- Safe to call again after the player changes any of them, since a switch is a value
-- for the session rather than an event.
function LS:AnalyticsSnapshot()
  if not self:AnalyticsOn() or not self.db then return end

  local goalsOn = 0
  for _, goal in ipairs(GOALS) do
    local on = self.db.goals and self.db.goals[goal] and true or false
    if on then goalsOn = goalsOn + 1 end
    self:Flag("goal." .. goal, on)
  end
  self:Measure("goals.on", goalsOn)

  -- Every registered tile, not just the ones in the layout, so an unused tile is
  -- recorded as unused rather than going missing from the numbers entirely.
  local layout = self.DashboardLayout and self:DashboardLayout() or {}
  local placed = {}
  for _, entry in ipairs(layout) do
    if entry and entry.id then placed[entry.id] = true end
  end
  for _, spec in ipairs(self.widgetCatalog or {}) do
    self:Flag("widget." .. spec.id, placed[spec.id] or false)
  end
  self:Measure("widgets.on", #layout)

  if self.OptionalAddonStatus then
    for _, row in ipairs(self:OptionalAddonStatus()) do
      -- Spaces would make these awkward to read back on the dashboard.
      self:Flag("addon." .. row.name:gsub("%s+", ""), row.loaded)
    end
  end

  self:Flag("setting.compact", self.db.compact and self.db.compact.enabled)
  self:Flag("setting.compactSingle", self.db.compact and self.db.compact.single)
  self:Flag("setting.sidebarCollapsed", self.db.sidebarCollapsed)
  self:Flag("setting.welcomed", self.db.welcomed)
  self:Flag("setting.minimapLocked", self.db.minimap and self.db.minimap.lock)
  self:Flag("setting.focusCurrentExpansion", (self.db.focusExpansion or "current") == "current")
  self:Flag("theme." .. tostring(self.db.theme or "AUTO"), true)
  self:Flag("source.gold." .. tostring(self.db.goldSource or "AUTO"), true)
  self:Flag("source.waypoint." .. tostring(self.db.waypointSource or "AUTO"), true)

  local keystone = self.db.keystone or {}
  self:Flag("keystone.reply", keystone.reply)
  for _, channel in ipairs({ "GUILD", "OFFICER", "PARTY", "RAID", "INSTANCE_CHAT", "WHISPER" }) do
    self:Flag("keystone.channel." .. channel, keystone.channels and keystone.channels[channel])
  end
  if self.KeystoneSharingOn then
    self:Flag("keystone.sharing", self:KeystoneSharingOn())
  end
end

function LS:StartAnalytics()
  if not self:AnalyticsOn() then return end
  self:Flag("version." .. tostring(self.version), true)
  self:AnalyticsSnapshot()
end

-- What /ls analytics prints. Sorted so two sessions can be compared by eye, and built
-- from the same table that was sent rather than describing it separately, because a
-- transparency report that is written by hand drifts from what actually goes out.
function LS:AnalyticsReport()
  local data = store(self)
  local lines = {}
  local names = {}
  for name in pairs(data.switches) do table.insert(names, name) end
  table.sort(names)
  for _, name in ipairs(names) do
    table.insert(lines, name .. ": " .. (data.switches[name] and "on" or "off"))
  end
  names = {}
  for name in pairs(data.counters) do table.insert(names, name) end
  table.sort(names)
  for _, name in ipairs(names) do
    table.insert(lines, name .. ": " .. tostring(data.counters[name]))
  end
  return lines
end

function LS:PrintAnalytics()
  if not print then return end
  print("|cff59d8c9Lodestar|r usage data. This is everything, and none of it names you or your characters.")
  if not self:AnalyticsOn() then
    print("Recording is off. Settings, Optional Addons turns it back on.")
    return
  end
  if not self:AnalyticsSharing() then
    print("Nothing is being sent: this is kept in memory only, because the Wago App is not sharing data here.")
  end
  local lines = self:AnalyticsReport()
  if #lines == 0 then
    print("Nothing recorded yet this session.")
    return
  end
  for _, line in ipairs(lines) do
    print("  " .. line)
  end
end
