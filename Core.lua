local addonName, LS = ...
_G.Lodestar = LS
LS.version = "1.0.1"
-- TGA rather than PNG: the client only resolves PNG when the path carries the
-- extension, and a same-named PNG shadows the TGA. One unambiguous format avoids both.
LS.MEDIA = "Interface\\AddOns\\Lodestar\\Media\\Logo.tga"
LS.MEDIA_ICON = "Interface\\AddOns\\Lodestar\\Media\\LogoIcon.tga"

LS.defaults = {
  -- Nothing is assumed. The welcome page asks before Lodestar filters anything out, because
  -- a goal that is off silently removes recommendations the player never learns existed.
  goals = { ENDGAME = false, SOLO = false, CRAFTING = false, MOUNTS = false, REPUTATION = false, QUESTING = false, GOLD = false },
  dismissed = {},
  completed = {},
  tracked = {},
  characters = {},
  knowledge = {},
  theme = "AUTO",
  colors = {},
  pageTab = { SETTINGS = "GOALS", VAULT = "raid" },
  goldSource = "AUTO",
  currentExpansionOnly = true,
  collapsed = {},
  repExpansions = {},
  repGroups = {},
  repFactions = {},
  frame = { point = "CENTER", relative = "CENTER", x = 0, y = 0, width = 960, height = 680 },
  compact = {
    enabled = false,
    single = false,
    collapsed = false,
    point = "TOPRIGHT", relative = "TOPRIGHT", x = -20, y = -220, width = 300,
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
  self.db.pageTab[page] = id
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

local function RefreshState()
  if not LS.db then return end
  if LS.ScanPlayer then LS:ScanPlayer() end
  LS:ScanVault()
  if LS.ScanProfessions then LS:ScanProfessions() end
  if LS.ScanMounts then LS:ScanMounts() end
  if LS.ScanReputations then LS:ScanReputations() end
  if LS.SaveSnapshot then LS:SaveSnapshot() end
  LS:Refresh()
end

local pending
local function RefreshSoon()
  if pending then return end
  pending = true
  C_Timer.After(1, function()
    pending = nil
    RefreshState()
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
}) do
  pcall(events.RegisterEvent, events, name)
end

events:SetScript("OnEvent", function(_, event, arg)
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
  -- Combat only changes how compact mode is displayed, so it skips the rescan entirely.
  if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    if LS.CompactCombat then LS:CompactCombat(event == "PLAYER_REGEN_DISABLED") end
    return
  end
  if event == "PLAYER_LOGIN" then
    if RequestRaidInfo then RequestRaidInfo() end
    RefreshState()
    if LS.db.welcomed then
      print("|cff59d8c9Lodestar " .. LS.version .. "|r loaded. /ls to open.")
    else
      print("|cff59d8c9Lodestar " .. LS.version .. "|r loaded. Pick what you care about to get started.")
      LS:OpenFull("WELCOME")
    end
    LS:DebugAnnounce()
  else
    RefreshSoon()
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
  elseif msg == "debug" or msg:match("^debug%s") then
    LS:DebugCommand(msg:match("^debug%s*(.*)$"))
  elseif msg == "reset" then
    LodestarDB = nil
    ReloadUI()
  else
    LS:Toggle()
  end
end
