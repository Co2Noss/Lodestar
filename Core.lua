local addonName, LS = ...
_G.Lodestar = LS
LS.version = "1.12.1"
-- TGA rather than PNG: the client only resolves PNG when the path carries the
-- extension, and a same-named PNG shadows the TGA. One unambiguous format avoids both.
LS.MEDIA = "Interface\\AddOns\\Lodestar\\Media\\Logo.tga"
LS.MEDIA_ICON = "Interface\\AddOns\\Lodestar\\Media\\LogoIcon.tga"

LS.defaults = {
  -- Nothing is assumed. The welcome page asks before Lodestar filters anything out, because
  -- a goal that is off silently removes recommendations the player never learns existed.
  goals = { ENDGAME = false, SOLO = false, CRAFTING = false, MOUNTS = false, REPUTATION = false, QUESTING = false },
  dismissed = {},
  completed = {},
  tracked = {},
  characters = {},
  knowledge = {},
  theme = "AUTO",
  colors = {},
  pageTab = { SETTINGS = "GOALS", VAULT = "raid" },
  currentExpansionOnly = true,
  collapsed = {},
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

local function RefreshState()
  if not LS.db then return end
  if LS.ScanPlayer then LS:ScanPlayer() end
  LS:ScanVault()
  if LS.ScanProfessions then LS:ScanProfessions() end
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
    RefreshState()
    if LS.db.welcomed then
      print("|cff59d8c9Lodestar " .. LS.version .. "|r loaded. /ls to open.")
    else
      print("|cff59d8c9Lodestar " .. LS.version .. "|r loaded. Pick what you care about to get started.")
      LS:OpenFull("WELCOME")
    end
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
  elseif msg == "reset" then
    LodestarDB = nil
    ReloadUI()
  else
    LS:Toggle()
  end
end
