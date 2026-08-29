local addonName, LS = ...
_G.Lodestar = LS
LS.version = "1.5.7"
-- TGA rather than PNG: the client only resolves PNG when the path carries the
-- extension, and a same-named PNG shadows the TGA. One unambiguous format avoids both.
LS.MEDIA = "Interface\\AddOns\\Lodestar\\Media\\Logo.tga"
LS.MEDIA_ICON = "Interface\\AddOns\\Lodestar\\Media\\LogoIcon.tga"
LS.MEDIA_DISCORD = "Interface\\AddOns\\Lodestar\\Media\\Discord.tga"
LS.MEDIA_GITHUB = "Interface\\AddOns\\Lodestar\\Media\\GitHub.tga"

LS.defaults = {
  -- Nothing is assumed. The welcome page asks before Lodestar filters anything out, because
  -- a goal that is off silently removes recommendations the player never learns existed.
  goals = { ENDGAME = false, SOLO = false, PREY = false, PVP = false, HOUSING = false, CRAFTING = false, MOUNTS = false, PETS = false, REPUTATION = false, QUESTING = false, GOLD = false },
  dismissed = {},
  completed = {},
  completedAuto = {},
  completedBlock = {},
  completedSnapshot = {},
  tracked = {},
  characters = {},
  knowledge = {},
  theme = "AUTO",
  colors = {},
  pageTab = { SETTINGS = "GOALS", VAULT = "raid" },
  goldSource = "AUTO",
  waypointSource = "AUTO",
  currentExpansionOnly = true,
  -- current = this expansion; all = every expansion; or an expansion name to focus
  -- one era (Cataclysm alchemy, older reputations, and so on).
  focusExpansion = "current",
  collapsed = {},
  sidebarCollapsed = false,
  repExpansions = {},
  repGroups = {},
  repFactions = {},
  frame = { point = "CENTER", relative = "CENTER", x = 0, y = 0, width = 960, height = 680 },
  minimap = { lock = true, angle = 135 },
  compact = {
    enabled = false,
    single = false,
    collapsed = false,
    point = "TOPRIGHT", relative = "TOPRIGHT", x = -20, y = -220, width = 300,
  },
  -- Widget order is filled in migrate so merge cannot splice the default array
  -- into a layout the player already edited.
  dashboard = {},
  tokenHistory = {},
  goldHistory = {},
  seenTips = {},
  -- Answering !keys is on, but every channel is a separate choice. A guild that
  -- already has a keystone addon does not want a second reply, while the same
  -- player may still want it in party.
  -- Anonymous counts of which tiles and goals get used, so the dead ones can be found.
  -- Turning this off stops Lodestar recording at all; see Analytics.lua for what is
  -- collected, or /ls analytics for the actual contents.
  analytics = true,

  -- What Lodestar's LibDataBroker object reads, for ElvUI, TukUI, Titan Panel and the
  -- rest. The name is the default because a datatext that changes its own width every
  -- few seconds shoves everything beside it around.
  broker = "name",

  -- Where the add/reset/compact controls sit while editing the dashboard. Above the
  -- canvas by default: a dashboard taller than the window puts them off the bottom of
  -- the page, where someone who just pressed Edit dashboard will not find them.
  editControls = "top",
  keystone = {
    reply = true,
    channels = {
      GUILD = true,
      OFFICER = true,
      PARTY = true,
      RAID = true,
      INSTANCE_CHAT = true,
      WHISPER = true,
    },
  },
}

local function merge(a, b)
  b = type(b) == "table" and b or {}
  for k, v in pairs(a) do
    if type(v) == "table" then
      b[k] = merge(v, b[k])
    elseif b[k] == nil then
      b[k] = v
    end
  end
  return b
end

local function anyGoal(goals)
  for _, on in pairs(goals or {}) do
    if on then return true end
  end
  return false
end

-- Having a goal on is the record that the player has been asked, whether that happened on
-- the welcome page or in Settings.
function LS:GoalsChosen()
  return anyGoal(self.db and self.db.goals)
end

function LS:MarkGoalsChosen()
  if self:GoalsChosen() then
    self.db.welcomed = true
  end
end

function LS:PageTab(page)
  return self.db and self.db.pageTab and self.db.pageTab[page]
end

function LS:SetPageTab(page, id)
  self.db.pageTab = self.db.pageTab or {}
  local was = self.db.pageTab[page]
  self.db.pageTab[page] = id
  if was ~= id and self.Count then
    self:Count("tab." .. tostring(page) .. "." .. tostring(id))
  end
end

local function migrate(db)
  db.allowResize = nil
  -- Anyone who already has goals chose them before the welcome page existed, so it should
  -- not interrupt them on the next login.
  if db.welcomed == nil and anyGoal(db.goals) then
    db.welcomed = true
  end
  -- The time budget is gone: recommendations are ranked and grouped instead of being
  -- squeezed into a session length.
  db.timeBudget = nil
  db.timeBudgetSeconds = nil
  db.migratedBudget = nil
  db.pageTab = db.pageTab or {}
  if db.settingsTab then
    db.pageTab.SETTINGS = db.settingsTab
    db.settingsTab = nil
  end
  if db.pageTab.SETTINGS == "WINDOW" then db.pageTab.SETTINGS = "LAYOUT" end
  db.dashboard = db.dashboard or {}
  if type(db.dashboard.widgets) ~= "table" or db.dashboard.widgets[1] == nil then
    if LS.DefaultDashboardWidgets then
      db.dashboard.widgets = LS.DefaultDashboardWidgets()
    end
  end
  db.tokenHistory = db.tokenHistory or {}
  if db.focusExpansion == nil then
    if db.currentExpansionOnly == false then
      db.focusExpansion = "all"
    else
      db.focusExpansion = "current"
    end
  end
  db.currentExpansionOnly = db.focusExpansion == "current"
  if not db.repSeeded then
    db.repSeeded = true
    local hasRep
    for _, on in pairs(db.repExpansions or {}) do
      if on then hasRep = true break end
    end
    if not hasRep then
      for _, on in pairs(db.repGroups or {}) do
        if on == true then hasRep = true break end
      end
    end
    if not hasRep then
      for _, on in pairs(db.repFactions or {}) do
        if on == true then hasRep = true break end
      end
    end
    if not hasRep then
      local name = LS.CurrentExpansionName and LS:CurrentExpansionName()
      if name then
        db.repExpansions = db.repExpansions or {}
        db.repExpansions[name] = true
      end
    end
  end
  if LS.SeedSeenTips then LS:SeedSeenTips(db) end
end

-- Skill-line and reputation headers use these region names instead of EXPANSION_NAME*.
LS.EXPANSION_ALIASES = {
  ["Khaz Algar"] = "The War Within",
  ["Dragon Isles"] = "Dragonflight",
  ["Kul Tiran"] = "Battle for Azeroth",
  ["Zandalari"] = "Battle for Azeroth",
  ["Outland"] = "The Burning Crusade",
  ["Northrend"] = "Wrath of the Lich King",
  ["Pandaria"] = "Mists of Pandaria",
  ["Draenor"] = "Warlords of Draenor",
}

function LS:CurrentExpansionName()
  local level = GetExpansionLevel and GetExpansionLevel()
  if level == nil then return nil end
  local name = _G["EXPANSION_NAME" .. tostring(level)]
  if type(name) == "string" and name ~= "" then return name end
end

function LS:NormalizeExpansionName(name)
  if type(name) ~= "string" or name == "" then return nil end
  return self.EXPANSION_ALIASES[name] or name
end

function LS:ExpansionReleaseIndex(name)
  name = self:NormalizeExpansionName(name)
  if not name then return end
  for i = 0, 20 do
    if _G["EXPANSION_NAME" .. i] == name then return i end
  end
end

function LS:ExpansionFromLabel(label)
  if type(label) ~= "string" or label == "" then return nil end
  local names = {}
  for i = 0, 20 do
    local name = _G["EXPANSION_NAME" .. i]
    if type(name) == "string" and name ~= "" then table.insert(names, name) end
  end
  for alias in pairs(self.EXPANSION_ALIASES) do
    table.insert(names, alias)
  end
  table.sort(names, function(a, b) return #a > #b end)
  for _, name in ipairs(names) do
    if label == name or label:sub(1, #name + 1) == name .. " " then
      return self:NormalizeExpansionName(name)
    end
  end
end

function LS:FocusExpansion()
  local value = self.db and self.db.focusExpansion
  if type(value) == "string" and value ~= "" then return value end
  if self.db and self.db.currentExpansionOnly == false then return "all" end
  return "current"
end

function LS:SetFocusExpansion(value)
  if value ~= "current" and value ~= "all" and (type(value) ~= "string" or value == "") then
    value = "current"
  end
  self.db.focusExpansion = value
  self.db.currentExpansionOnly = value == "current"
end

function LS:ExpansionInFocus(name)
  local focus = self:FocusExpansion()
  if focus == "all" then return true end
  name = self:NormalizeExpansionName(name)
  if not name then return false end
  if focus == "current" then return name == self:CurrentExpansionName() end
  return name == focus
end

function LS:FocusExpansionLabel()
  local focus = self:FocusExpansion()
  if focus == "all" then return "All expansions" end
  if focus == "current" then
    local name = self:CurrentExpansionName()
    return name and (name .. " (current)") or "Current expansion"
  end
  return focus
end

function LS:FocusExpansionChoices()
  local current = self:CurrentExpansionName()
  local labels, values = {}, {}
  local currentLabel = current and (current .. " (current)") or "Current expansion"
  table.insert(labels, currentLabel)
  values[currentLabel] = "current"
  table.insert(labels, "All expansions")
  values["All expansions"] = "all"
  local extras, seen = {}, { [current or ""] = true }
  local function add(name)
    name = self:NormalizeExpansionName(name)
    if name and not seen[name] and self:ExpansionReleaseIndex(name) then
      seen[name] = true
      extras[name] = true
    end
  end
  for _, prof in ipairs(self.professions or {}) do
    add(prof.expansion)
  end
  for _, row in ipairs((self.profile and self.profile.repRows) or {}) do
    if row.kind == "expansion" then add(row.name) end
  end
  local list = {}
  for name in pairs(extras) do table.insert(list, name) end
  table.sort(list, function(a, b)
    return (self:ExpansionReleaseIndex(a) or -1) > (self:ExpansionReleaseIndex(b) or -1)
  end)
  for _, name in ipairs(list) do
    table.insert(labels, name)
    values[name] = name
  end
  return labels, values
end

function LS:FormatDuration(seconds)
  seconds = math.floor((seconds or 0) + 0.5)
  if seconds < 60 then
    return seconds .. (seconds == 1 and " second" or " seconds")
  end
  local minutes = math.floor(seconds / 60)
  if minutes < 60 then
    return minutes .. " min"
  end
  local hours = math.floor(minutes / 60)
  local rest = minutes % 60
  if rest == 0 then
    return hours .. (hours == 1 and " hour" or " hours")
  end
  return hours .. "h " .. rest .. "m"
end

-- Isolation state is a separate saved variable so /ls reset cannot throw away the
-- list of addons that need turning back on after a debugging session.
function LS:DebugIsolated()
  return LodestarDebugDB and LodestarDebugDB.active and true or false
end

local function debugChat(msg)
  print("|cff59d8c9Lodestar|r " .. msg)
end

local function debugUsage()
  debugChat("|cffffcc00/ls debug|r disables every other addon and reloads, so you can tell if an error is ours.")
  debugChat("|cffffcc00/ls debug off|r turns those addons back on. This character only.")
end

local function playerName()
  return UnitName and UnitName("player") or nil
end

local function addonEnableState(name)
  local fn = C_AddOns and C_AddOns.GetAddOnEnableState
  if not fn then return 0 end
  local character = playerName()
  local ok, state = pcall(fn, name, character)
  if ok and type(state) == "number" then return state end
  ok, state = pcall(fn, name)
  if ok and type(state) == "number" then return state end
  return 0
end

local function setAddonEnabled(name, on)
  local fn = on and (C_AddOns and C_AddOns.EnableAddOn) or (C_AddOns and C_AddOns.DisableAddOn)
  if not fn then return false end
  local character = playerName()
  if pcall(fn, name, character) then return true end
  return pcall(fn, name) and true or false
end

local function keepAddon(name, security)
  if name == addonName then return true end
  if security == "SECURE" then return true end
  if type(name) == "string" and name:sub(1, 9) == "Blizzard_" then return true end
  return false
end

local function eachAddon(fn)
  local getNum = C_AddOns and C_AddOns.GetNumAddOns
  local getInfo = C_AddOns and C_AddOns.GetAddOnInfo
  if not getNum or not getInfo then return 0 end
  local n = getNum() or 0
  for i = 1, n do
    local name, _, _, _, _, security = getInfo(i)
    if name then fn(name, security or "") end
  end
  return n
end

function LS:DebugAnnounce()
  if not self:DebugIsolated() then return end
  local n = LodestarDebugDB.addons and #LodestarDebugDB.addons or 0
  debugChat("|cffffcc00debug isolation is on.|r " .. n .. " other addon" .. (n == 1 and "" or "s") .. " disabled. If the error is gone, it was not Lodestar. |cff59d8c9/ls debug|r restores them.")
end

function LS:DebugIsolate()
  if InCombatLockdown and InCombatLockdown() then
    debugChat("leave combat before isolating addons.")
    return
  end
  if self:DebugIsolated() then
    debugChat("debug isolation is already on. |cff59d8c9/ls debug off|r restores the other addons.")
    return
  end
  local saved = {}
  local seen = eachAddon(function(name, security)
    if keepAddon(name, security) then return end
    if addonEnableState(name) > 0 then
      table.insert(saved, name)
      setAddonEnabled(name, false)
    end
  end)
  if seen == 0 then
    debugChat("cannot read the addon list on this client.")
    return
  end
  setAddonEnabled(addonName, true)
  LodestarDebugDB = { active = true, addons = saved }
  debugChat("disabled " .. #saved .. " addon" .. (#saved == 1 and "" or "s") .. ". Reloading with only Lodestar enabled.")
  ReloadUI()
end

function LS:DebugRestore()
  if InCombatLockdown and InCombatLockdown() then
    debugChat("leave combat before restoring addons.")
    return
  end
  if not self:DebugIsolated() then
    debugChat("debug isolation is not on.")
    return
  end
  local saved = LodestarDebugDB.addons or {}
  for _, name in ipairs(saved) do
    setAddonEnabled(name, true)
  end
  setAddonEnabled(addonName, true)
  LodestarDebugDB = { active = false, addons = {} }
  debugChat("restored " .. #saved .. " addon" .. (#saved == 1 and "" or "s") .. ". Reloading.")
  ReloadUI()
end

function LS:DebugCommand(arg)
  arg = (arg or ""):lower():match("^%s*(.-)%s*$")
  if arg == "off" or arg == "restore" then
    self:DebugRestore()
  elseif arg == "on" or arg == "isolate" then
    self:DebugIsolate()
  elseif arg == "" then
    if self:DebugIsolated() then
      self:DebugRestore()
    else
      self:DebugIsolate()
    end
  else
    debugUsage()
  end
end

local PaintWindow

local function RefreshState()
  if not LS.db then return end
  if LS.ScanPlayer then LS:ScanPlayer() end
  LS:ScanVault()
  if LS.ScanProfessions then LS:ScanProfessions() end
  if LS.SyncAutoCompleted then LS:SyncAutoCompleted() end
  if LS.ScanMounts then LS:ScanMounts() end
  if LS.ScanReputations then LS:ScanReputations() end
  if LS.SaveSnapshot then LS:SaveSnapshot() end
  if LS.RequestTokenPrice then LS:RequestTokenPrice() end
  if LS.RecordTokenPrice then LS:RecordTokenPrice() end
  if LS.RecordAccountGold then LS:RecordAccountGold() end
  -- The datatext reads from the same scan the window does, so it never shows a number
  -- older than what Lodestar itself is showing.
  if LS.UpdateBroker then LS:UpdateBroker() end
  PaintWindow({ full = true })
end

local function WindowShown()
  return LS.frame and LS.frame:IsShown()
end

-- Live dashboard updates keep the canvas. ShowPage is for navigation, edit,
-- resize, and every page that is not the dashboard.
local function TilesFor(jobs)
  if jobs.full then return true end
  local seen, out = {}, {}
  local function add(id)
    if id and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  if jobs.vault then add("vault") end
  if jobs.professions then add("professions") end
  if jobs.housing then add("housing") end
  return out
end

local function PageNeedsRebuild(jobs)
  if jobs.full or jobs.ui then return true end
  if jobs.vault or jobs.professions or jobs.mounts or jobs.reputation then
    return true
  end
  if jobs.tradeskill and LS.page == "PROFESSIONS" then return true end
  return false
end

PaintWindow = function(jobs)
  jobs = jobs or { full = true }
  if WindowShown() then
    if LS.page == "DASHBOARD" and LS.RefreshDashboardLive then
      local tiles = TilesFor(jobs)
      if tiles == true then
        LS:RefreshDashboardLive()
      elseif #tiles > 0 then
        LS:RefreshDashboardLive(tiles)
      end
    elseif PageNeedsRebuild(jobs) then
      LS:ShowPage(LS.page or "TODAY")
    end
  end
  if jobs.full or jobs.vault or jobs.professions then
    if LS.UpdateCompact then LS:UpdateCompact() end
  end
end

local function ApplyJobs(jobs)
  if not LS.db or not jobs then return end
  if jobs.full then
    RefreshState()
    return
  end
  if jobs.player and LS.ScanPlayer then LS:ScanPlayer() end
  if jobs.vault then LS:ScanVault() end
  if (jobs.professions or jobs.tradeskill) and LS.ScanProfessions then
    LS:ScanProfessions()
  end
  if (jobs.professions or jobs.tradeskill) and LS.SyncAutoCompleted then
    LS:SyncAutoCompleted()
  end
  if jobs.mounts and LS.ScanMounts then LS:ScanMounts() end
  if jobs.reputation and LS.ScanReputations then LS:ScanReputations() end
  if (jobs.snapshot or jobs.vault or jobs.professions) and LS.SaveSnapshot then
    LS:SaveSnapshot()
  end
  if jobs.money and LS.RecordAccountGold then LS:RecordAccountGold() end
  PaintWindow(jobs)
end

-- Noisy client events used to rebuild the whole window every second. That is
-- the hitch: Clear() orphans widgets, ShowPage creates new ones, GC climbs
-- past 100MB and pauses the client. With the dashboard open, later events
-- still did that; those now update the tile that changed.
local queued
local pending
local function RefreshSoon(job)
  queued = queued or {}
  queued[job or "full"] = true
  if pending then return end
  pending = true
  C_Timer.After(1, function()
    pending = nil
    local jobs = queued
    queued = nil
    ApplyJobs(jobs)
  end)
end

local events = CreateFrame("Frame")
for _, name in ipairs({
  "ADDON_LOADED",
  "PLAYER_LOGIN",
  "PLAYER_ENTERING_WORLD",
  "WEEKLY_REWARDS_UPDATE",
  "SKILL_LINES_CHANGED",
  "TRADE_SKILL_LIST_UPDATE",
  "QUEST_TURNED_IN",
  "CURRENCY_DISPLAY_UPDATE",
  "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
  "NEW_MOUNT_ADDED",
  "UPDATE_INSTANCE_INFO",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "TOKEN_MARKET_PRICE_UPDATED",
      "PLAYER_MONEY",
      "MODIFIER_STATE_CHANGED",
      "CALENDAR_UPDATE_EVENT_LIST",
      "GUILD_ROSTER_UPDATE",
      "PLAYER_HOUSE_LIST_UPDATED",
      "CURRENT_HOUSE_INFO_UPDATED",
      "CURRENT_HOUSE_INFO_RECIEVED",
      "HOUSE_INFO_UPDATED",
      "HOUSE_LEVEL_FAVOR_UPDATED",
      "HOUSE_LEVEL_CHANGED",
      "TRACKED_HOUSE_CHANGED",
      "VIEW_HOUSES_LIST_RECIEVED",
      "CHALLENGE_MODE_COMPLETED",
      "CHAT_MSG_GUILD",
      "CHAT_MSG_OFFICER",
      "CHAT_MSG_PARTY",
      "CHAT_MSG_PARTY_LEADER",
      "CHAT_MSG_RAID",
      "CHAT_MSG_RAID_LEADER",
      "CHAT_MSG_INSTANCE_CHAT",
      "CHAT_MSG_INSTANCE_CHAT_LEADER",
      "CHAT_MSG_WHISPER",
    }) do
  pcall(events.RegisterEvent, events, name)
end

events:SetScript("OnEvent", function(_, event, arg, ...)
  if event == "ADDON_LOADED" then
    if arg == addonName then
      LodestarDB = merge(LS.defaults, LodestarDB)
      migrate(LodestarDB)
      LS.db = LodestarDB
      LS:CreateUI()
    end
    return
  end
  if not LS.db then return end
  -- Chat answers a question, so it never triggers a rescan or a repaint.
  if event:sub(1, 9) == "CHAT_MSG_" then
    if LS.HandleChatCommand then LS:HandleChatCommand(event, arg, ...) end
    return
  end
  -- A finished key means the old one is gone, so the tile has to catch up.
  if event == "CHALLENGE_MODE_COMPLETED" then
    if LS.RefreshDashboardLive then LS:RefreshDashboardLive({ "raiderio" }) end
    return
  end
  -- Combat only changes how compact mode is displayed, so it skips the rescan entirely.
  if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    if LS.CompactCombat then LS:CompactCombat(event == "PLAYER_REGEN_DISABLED") end
    return
  end
  if event == "TOKEN_MARKET_PRICE_UPDATED" then
    local changed = LS.RecordTokenPrice and LS:RecordTokenPrice()
    if changed and LS.RefreshDashboardLive then
      LS:RefreshDashboardLive({ "token" })
    end
    return
  end
  if event == "MODIFIER_STATE_CHANGED" then
    if LS.RefreshWidgetTooltip then LS:RefreshWidgetTooltip() end
    return
  end
  if event == "PLAYER_HOUSE_LIST_UPDATED" or event == "VIEW_HOUSES_LIST_RECIEVED" then
    if LS.RememberHouseList then LS:RememberHouseList(arg) end
  elseif event == "CURRENT_HOUSE_INFO_UPDATED" or event == "CURRENT_HOUSE_INFO_RECIEVED" then
    if LS.RememberCurrentHouse then LS:RememberCurrentHouse(arg) end
  elseif event == "HOUSE_LEVEL_FAVOR_UPDATED" then
    if LS.RememberHouseFavor then LS:RememberHouseFavor(arg) end
  elseif event == "HOUSE_LEVEL_CHANGED" then
    if LS.RememberHouseLevel then LS:RememberHouseLevel(arg) end
  elseif event == "HOUSE_INFO_UPDATED" then
    if LS.RememberCurrentHouse then LS:RememberCurrentHouse(arg) end
  elseif event == "TRACKED_HOUSE_CHANGED" then
    if LS.RememberTrackedHouse then LS:RememberTrackedHouse(arg) end
  end
  if event == "PLAYER_LOGIN" then
    if RequestRaidInfo then RequestRaidInfo() end
    if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
    if LS.RequestHousingInfo then LS:RequestHousingInfo() end
    RefreshState()
    if LS.db.welcomed then
      print("|cff59d8c9Lodestar " .. LS.version .. "|r loaded. /ls or /lodestar to open.")
    else
      print("|cff59d8c9Lodestar " .. LS.version .. "|r loaded. Pick what you care about to get started.")
      LS:OpenFull("WELCOME")
    end
    LS:DebugAnnounce()
    -- After RefreshState, so the snapshot describes a scanned character rather than
    -- an empty one, and after the print so nothing here can delay the login message.
    if LS.StartAnalytics then pcall(LS.StartAnalytics, LS) end
    -- At login, because the display addon that carries LibDataBroker may well have
    -- loaded after Lodestar did.
    if LS.StartBroker then pcall(LS.StartBroker, LS) end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    RefreshSoon("full")
  elseif event == "PLAYER_MONEY" then
    RefreshSoon("money")
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    return
  elseif event == "GUILD_ROSTER_UPDATE" or event == "CALENDAR_UPDATE_EVENT_LIST" then
    return
  elseif event == "TRADE_SKILL_LIST_UPDATE" then
    RefreshSoon("tradeskill")
  elseif event == "SKILL_LINES_CHANGED" then
    RefreshSoon("professions")
  elseif event == "WEEKLY_REWARDS_UPDATE" or event == "UPDATE_INSTANCE_INFO" then
    RefreshSoon("vault")
  elseif event == "NEW_MOUNT_ADDED" then
    RefreshSoon("mounts")
  elseif event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
    RefreshSoon("reputation")
  elseif event == "QUEST_TURNED_IN" then
    RefreshSoon("full")
  elseif event == "PLAYER_HOUSE_LIST_UPDATED" or event == "VIEW_HOUSES_LIST_RECIEVED"
      or event == "CURRENT_HOUSE_INFO_UPDATED" or event == "CURRENT_HOUSE_INFO_RECIEVED"
      or event == "HOUSE_INFO_UPDATED" or event == "TRACKED_HOUSE_CHANGED" then
    RefreshSoon("housing")
  elseif event == "HOUSE_LEVEL_FAVOR_UPDATED" or event == "HOUSE_LEVEL_CHANGED" then
    return
  else
    RefreshSoon("full")
  end
end)

SLASH_LODESTAR1 = "/ls"
SLASH_LODESTAR2 = "/lodestar"
SlashCmdList.LODESTAR = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  local theme = msg:match("^theme%s+(%S+)$")
  if theme then
    LS:SetTheme(theme:upper())
  elseif msg == "theme" then
    LS:PrintThemes()
  elseif msg == "compact" then
    LS:ToggleCompact()
    print("|cff59d8c9Lodestar|r compact mode: " .. (LS.db.compact.enabled and "on" or "off"))
  elseif msg == "compact single" then
    LS:SetCompactSingle(not LS.db.compact.single)
    print("|cff59d8c9Lodestar|r compact single recommendation: " .. (LS.db.compact.single and "on" or "off"))
  elseif msg == "analytics" then
    LS:PrintAnalytics()
  elseif msg == "analytics off" or msg == "analytics on" then
    LS:SetAnalytics(msg == "analytics on")
    print("|cff59d8c9Lodestar|r usage data: " .. (LS:AnalyticsOn() and "on" or "off"))
  elseif msg == "debug" or msg:match("^debug%s") then
    LS:DebugCommand(msg:match("^debug%s*(.*)$"))
  elseif msg == "reset" then
    LodestarDB = nil
    ReloadUI()
  else
    LS:Toggle()
  end
end
