-- Minimal WoW client stub: enough surface for Lodestar to load and be driven headlessly.

-- The client still exposes the 5.1 global.
unpack = unpack or table.unpack

local methods = {}
local mt = { __index = function(t, k)
  local m = methods[k]
  if m then return m end
  -- Only PascalCase keys are API methods. Addon data fields are camelCase and must stay
  -- nil when unset, or every `if row.activityID` check is silently truthy.
  if type(k) == "string" and k:match("^%u") then
    local f = function() return nil end
    rawset(t, k, f)
    return f
  end
  return nil
end }

local function new(kind, name, parent)
  return setmetatable({
    kind = kind, objName = name, parent = parent,
    children = {}, regions = {}, scripts = {}, events = {},
    shown = true, w = 100, h = 20,
  }, mt)
end

function methods.SetScript(self, key, fn) self.scripts[key] = fn end
function methods.HookScript(self, key, fn) self.scripts[key] = fn end
function methods.GetScript(self, key) return self.scripts[key] end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.SetShown(self, v) self.shown = v and true or false end
function methods.IsShown(self) return self.shown end
function methods.IsVisible(self) return self.shown end
function methods.SetWidth(self, v) self.w = v end
function methods.SetHeight(self, v) self.h = v end
function methods.SetSize(self, a, b) self.w, self.h = a, b end
function methods.GetWidth(self) return self.w end
function methods.GetHeight(self) return self.h end
function methods.GetPoint(self) return "CENTER", nil, "CENTER", 0, 0 end
function methods.SetFrameLevel(self, v) self.frameLevel = v end
function methods.GetFrameLevel(self) return self.frameLevel or 1 end
function methods.GetName(self) return self.objName end
function methods.EnableMouse(self, v) self.mouse = v and true or false end
function methods.EnableKeyboard(self, v) self.keyboard = v and true or false end
function methods.SetPropagateKeyboardInput(self, v) self.propagateKeys = v and true or false end
function methods.SetFrameStrata(self, strata) self.frameStrata = strata end
function methods.GetFrameStrata(self) return self.frameStrata end
function methods.SetToplevel(self, v) self.toplevel = v and true or false end
function methods.GetVerticalScroll(self) return 0 end
function methods.GetChildren(self) return unpack(self.children) end
function methods.GetRegions(self) return unpack(self.regions) end
function methods.RegisterEvent(self, e) self.events[e] = true end

-- Recorded so tests can assert what a theme actually painted.
function methods.SetBackdrop(self, backdrop) self.backdrop = backdrop end
function methods.SetBackdropColor(self, ...) self.bgColor = { ... } end
function methods.SetBackdropBorderColor(self, ...) self.borderColor = { ... } end
function methods.SetPoint(self, ...)
  self.points = self.points or {}
  table.insert(self.points, { ... })
end
function methods.ClearAllPoints(self) self.points = {} end

-- Clear() detaches page content by reparenting to nil, so the stub has to honour that or
-- stale widgets stay reachable and assertions read text from pages that are gone.
function methods.SetParent(self, parent)
  local old = self.parent
  if type(old) == "table" and old.children then
    for i, child in ipairs(old.children) do
      if child == self then
        table.remove(old.children, i)
        break
      end
    end
  end
  self.parent = parent
  if type(parent) == "table" and parent.children then
    table.insert(parent.children, self)
  end
end

local function region(self, kind)
  local r = new(kind, nil, self)
  function r.SetText(s, v) s.text_value = v end
  function r.GetText(s) return s.text_value end
  function r.SetTextColor(s, ...) s.color = { ... } end
  function r.GetStringHeight(s) return 12 end
  table.insert(self.regions, r)
  return r
end

function methods.CreateFontString(self) return region(self, "FontString") end
function methods.CreateTexture(self) return region(self, "Texture") end
function methods.GetThumbTexture(self)
  self.thumb = self.thumb or region(self, "Texture")
  return self.thumb
end
function methods.GetNormalTexture(self) return methods.GetThumbTexture(self) end

function methods.GetParent(self) return self.parent end
function methods.SetAlpha(self, v) self.alpha = v end
function methods.GetAlpha(self) return self.alpha or 1 end
function methods.SetScale(self, v) self.scale = v end
function methods.GetScale(self) return self.scale or 1 end
function methods.SetMovable(self, v) self.movable = v and true or false end
function methods.SetResizable(self, v) self.resizable = v and true or false end
function methods.RegisterForDrag(self, btn) self.dragButton = btn end
function methods.StartMoving(self) self.moving = true end
function methods.StartSizing(self, edge)
  self.moving = true
  self.sizing = edge
end
function methods.StopMovingOrSizing(self)
  self.moving = false
  self.sizing = nil
end

AllFrames = {}
-- Lets a test pretend the client has no such XML template, the way an older or future
-- client would.
DeniedTemplates = {}

function CreateFrame(kind, name, parent, template)
  if template and DeniedTemplates[template] then
    error("unknown template " .. template, 2)
  end
  local f = new(kind, name, parent)
  f.template = template
  if parent and type(parent) == "table" and parent.children then
    table.insert(parent.children, f)
  end
  if name then _G[name] = f end
  table.insert(AllFrames, f)
  return f
end

-- Chat output, kept so tests can assert what the player is told at login.
Printed = {}
local realPrint = print
function print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
  table.insert(Printed, table.concat(parts, " "))
end

UIParent = new("Frame", "UIParent")
Minimap = new("Frame", "Minimap")
WeeklyRewardsFrame = new("Frame", "WeeklyRewardsFrame")
WeeklyRewardsFrame.shown = false
OpenedGreatVault = false
function ShowUIPanel(frame)
  if type(frame) == "table" then
    frame.shown = true
    if frame == WeeklyRewardsFrame then OpenedGreatVault = true end
  end
end
GameTooltip = new("Frame", "GameTooltip")
GameTooltipTextLeft1 = { GetText = function(self) return self._text end }
function GameTooltip:SetOwner() end
function GameTooltip:SetText(t)
  self._tip = t
  self._lines = { t }
  GameTooltipTextLeft1._text = t
end
function GameTooltip:AddLine(t)
  self._lines = self._lines or {}
  table.insert(self._lines, t)
  if not GameTooltipTextLeft1._text then
    GameTooltipTextLeft1._text = t
    self._tip = t
  end
end
function GameTooltip:ClearLines()
  self._tip = nil
  self._lines = {}
  GameTooltipTextLeft1._text = nil
end
function GameTooltip:GetText()
  return self._tip
end
SlashCmdList = {}
UISpecialFrames = {}
tinsert = table.insert

FACTION_STANDING_LABEL4 = "Neutral"
FACTION_STANDING_LABEL5 = "Friendly"
FACTION_STANDING_LABEL6 = "Honored"
FACTION_STANDING_LABEL7 = "Revered"
FACTION_STANDING_LABEL8 = "Exalted"

local timers = {}
C_Timer = {
  After = function(_, fn) if type(fn) == "function" then pcall(fn) end end,
  NewTimer = function(_, fn)
    local t = { fn = fn }
    function t.Cancel(s) s.cancelled = true end
    table.insert(timers, t)
    return t
  end,
}

function FireTimers()
  local pending = timers
  timers = {}
  for _, t in ipairs(pending) do
    if not t.cancelled and type(t.fn) == "function" then pcall(t.fn) end
  end
end

ReloadedUI = false
function ReloadUI() ReloadedUI = true end
function InCombatLockdown() return false end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

local function fontColor(r, g, b)
  local c = { r = r, g = g, b = b }
  function c.GetRGB(s) return s.r, s.g, s.b end
  return c
end
NORMAL_FONT_COLOR = fontColor(1, 0.82, 0)
HIGHLIGHT_FONT_COLOR = fontColor(1, 1, 1)
WHITE_FONT_COLOR = fontColor(1, 1, 1)
RED_FONT_COLOR = fontColor(1, 0.125, 0.125)
GRAY_FONT_COLOR = fontColor(0.5, 0.5, 0.5)

ColorPickerFrame = new("Frame", "ColorPickerFrame")
function ColorPickerFrame.SetupColorPickerAndShow(self, info)
  self.pending = info
  self.picked = { info.r, info.g, info.b, info.opacity or 1 }
end
function ColorPickerFrame.GetColorRGB(self)
  return self.picked[1], self.picked[2], self.picked[3]
end
function ColorPickerFrame.GetColorAlpha(self)
  return self.picked[4] or 1
end

-- Test helpers: act as the player would inside the open picker.
function ChooseColor(r, g, b, a)
  local info = ColorPickerFrame.pending
  if not info then error("no colour picker is open") end
  ColorPickerFrame.picked = { r, g, b, a or 1 }
  info.swatchFunc()
end

function CancelColor()
  local info = ColorPickerFrame.pending
  if not info then error("no colour picker is open") end
  info.cancelFunc()
end

UnitName = function() return "Testchar" end
GetRealmName = function() return "Testrealm" end
UnitLevel = function() return 80 end
UnitClass = function() return "Mage", "MAGE" end
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return 62, "Arcane" end
GetProfessions = function() return 1, 2, 3, 4, 5 end
GetProfessionInfo = function(index)
  if index == 1 then return "Alchemy", nil, 100, 100, nil, nil, 171, 0, nil, nil, "Alchemy" end
  if index == 2 then return "Herbalism", nil, 100, 100, nil, nil, 182, 0, nil, nil, "Herbalism" end
  if index == 3 then return "Archaeology", nil, 200, 800, nil, nil, 794, 0, nil, nil, "Archaeology" end
  if index == 4 then return "Fishing", nil, 50, 100, nil, nil, 356, 0, nil, nil, "Fishing" end
  if index == 5 then return "Cooking", nil, 80, 100, nil, nil, 185, 0, nil, nil, "Cooking" end
end

local addonList = {
  { name = "Lodestar", security = "INSECURE", enabled = 2 },
  { name = "ElvUI", security = "INSECURE", enabled = 2 },
  { name = "Details", security = "INSECURE", enabled = 2 },
  { name = "Blizzard_WeeklyRewards", security = "SECURE", enabled = 2 },
  { name = "SomeDisabled", security = "INSECURE", enabled = 0 },
}

local function findAddon(id)
  if type(id) == "number" then return addonList[id] end
  if type(id) == "string" then
    for _, row in ipairs(addonList) do
      if row.name == id then return row end
    end
  end
end

C_AddOns = {
  IsAddOnLoaded = function() return false end,
  LoadAddOn = function() return true end,
  GetNumAddOns = function() return #addonList end,
  GetAddOnInfo = function(id)
    local a = findAddon(id)
    if not a then return nil end
    return a.name, a.name, "", true, nil, a.security, false
  end,
  GetAddOnEnableState = function(name)
    local a = findAddon(name)
    return a and a.enabled or 0
  end,
  DisableAddOn = function(name)
    local a = findAddon(name)
    if a then a.enabled = 0 end
  end,
  EnableAddOn = function(name)
    local a = findAddon(name)
    if a then a.enabled = 2 end
  end,
}

C_TradeSkillUI = {
  GetAllProfessionTradeSkillLines = function() return { 2871, 2823, 2757, 185, 356, 794 } end,
  GetProfessionInfoBySkillLineID = function(id)
    local names = {
      [2871] = "Alchemy", [2823] = "Herbalism", [2757] = "Alchemy",
      [185] = "Cooking", [356] = "Fishing", [794] = "Archaeology",
    }
    local parent = {
      [2871] = 171, [2823] = 182, [2757] = 171,
      [185] = 185, [356] = 356, [794] = 794,
    }
    return {
      professionName = names[id] or "Alchemy",
      isPrimaryProfession = id ~= 185 and id ~= 356 and id ~= 794,
      skillLevel = id == 2757 and 0 or 60,
      maxSkillLevel = id == 794 and 800 or 100,
      professionID = parent[id] or 171,
      parentProfessionID = parent[id],
      parentProfessionName = names[id],
    }
  end,
  OpenTradeSkill = function(id)
    table.insert(OpenedTradeSkills, id)
    return true
  end,
}
OpenedTradeSkills = {}

C_ProfSpecs = {
  SkillLineHasSpecialization = function(id) return id ~= 185 and id ~= 356 and id ~= 794 end,
  GetConfigIDForSkillLine = function() return 1 end,
  GetCurrencyInfoForSkillLine = function() return { currencyID = 2033, quantity = 3 } end,
  GetSpecTabIDsForSkillLine = function() return {} end,
  GetTabInfo = function() return nil end,
  GetChildrenForPath = function() return {} end,
}
C_Traits = { GetNodeInfo = function() return nil end }
Currencies = {}
C_CurrencyInfo = {
  GetCurrencyInfo = function(id)
    return Currencies[id] or { quantity = 3, maxQuantity = 0 }
  end,
}
GildedStashTooltip = nil
C_UIWidgetManager = {
  GetSpellDisplayVisualizationInfo = function(id)
    if id == 7591 and GildedStashTooltip then
      return { spellInfo = { tooltip = GildedStashTooltip } }
    end
  end,
}
QuestLog = {}
SuperTrackedQuestID = nil
ActivePreyQuestID = nil
C_QuestLog = {
  IsQuestFlaggedCompleted = function() return false end,
  GetNumQuestLogEntries = function() return #QuestLog, #QuestLog end,
  GetInfo = function(i) return QuestLog[i] end,
  IsComplete = function(id)
    for _, q in ipairs(QuestLog) do
      if q.questID == id then return q.readyForTurnIn or q.isComplete or false end
    end
    return false
  end,
  IsWorldQuest = function(id)
    for _, q in ipairs(QuestLog) do
      if q.questID == id then return q.isTask == true or q.isBounty == true end
    end
    return false
  end,
  IsImportantQuest = function(id)
    for _, q in ipairs(QuestLog) do
      if q.questID == id then return q.isImportant == true end
    end
    return false
  end,
  GetActivePreyQuest = function()
    return ActivePreyQuestID
  end,
  GetTitleForQuestID = function(id)
    for _, q in ipairs(QuestLog) do
      if q.questID == id then return q.title end
    end
  end,
  GetQuestUiMapID = function(id)
    for _, q in ipairs(QuestLog) do
      if q.questID == id then return q.uiMapID end
    end
  end,
  GetNextWaypoint = function(id)
    for _, q in ipairs(QuestLog) do
      if q.questID == id and q.waypoint then
        return q.waypoint.map, q.waypoint.x, q.waypoint.y
      end
    end
  end,
}

AvailableCampaigns = {}
Campaigns = {}
C_CampaignInfo = {
  GetAvailableCampaigns = function() return AvailableCampaigns end,
  GetState = function(id) return Campaigns[id] and Campaigns[id].state or 0 end,
  GetCampaignInfo = function(id) return Campaigns[id] and Campaigns[id].info end,
  GetCurrentChapterID = function(id) return Campaigns[id] and Campaigns[id].chapterID end,
  GetChapterInfo = function(chapterID)
    for _, c in pairs(Campaigns) do
      if c.chapterID == chapterID then return c.chapterInfo end
    end
  end,
  GetCampaignID = function(questID)
    for _, q in ipairs(QuestLog) do
      if q.questID == questID then return q.campaignID end
    end
  end,
  IsCampaignQuest = function(questID)
    for _, q in ipairs(QuestLog) do
      if q.questID == questID then return q.campaignID ~= nil and q.campaignID ~= 0 end
    end
    return false
  end,
}

MAP_NAMES = {
  [2393] = "Silvermoon City",
  [2395] = "Eversong Woods",
  [2413] = "Harandar",
  [2405] = "Voidstorm",
  [2437] = "Zul'Aman",
}
-- Stub-only parent chain so tests can walk maps. Production code does not hardcode these IDs.
MAP_INFO = {
  [947] = { name = "Azeroth", mapID = 947, mapType = 1, parentMapID = 946 },
  [2400] = { name = "Midnight", mapID = 2400, mapType = 2, parentMapID = 947 },
  [2395] = { name = "Eversong Woods", mapID = 2395, mapType = 3, parentMapID = 2400 },
  [2393] = { name = "Silvermoon City", mapID = 2393, mapType = 5, parentMapID = 2395 },
  [2437] = { name = "Zul'Aman", mapID = 2437, mapType = 3, parentMapID = 2400 },
  -- Portal continents: siblings of Midnight under Azeroth, not Midnight zones.
  [2413] = { name = "Harandar", mapID = 2413, mapType = 2, parentMapID = 947 },
  [2405] = { name = "Voidstorm", mapID = 2405, mapType = 2, parentMapID = 947 },
  [2444] = { name = "Slayer's Rise", mapID = 2444, mapType = 3, parentMapID = 2405 },
}
UserWaypoint = nil
SuperTrackedUserWaypoint = false
OpenedWorldMaps = {}
TomTomWaypoints = {}
DelvePOIs = {}
AreaPOIs = {}

C_AreaPoiInfo = {
  GetDelvesForMap = function(mapID)
    local list = DelvePOIs[mapID] or {}
    local ids = {}
    for _, poi in ipairs(list) do table.insert(ids, poi.areaPoiID) end
    return ids
  end,
  GetAreaPOIForMap = function(mapID)
    local list = AreaPOIs[mapID] or DelvePOIs[mapID] or {}
    local ids = {}
    for _, poi in ipairs(list) do table.insert(ids, poi.areaPoiID) end
    return ids
  end,
  GetAreaPOIInfo = function(mapID, poiID)
    for _, bucket in ipairs({ DelvePOIs[mapID], AreaPOIs[mapID] }) do
      for _, poi in ipairs(bucket or {}) do
        if poi.areaPoiID == poiID then return poi end
      end
    end
  end,
}

UiMapPoint = {
  CreateFromCoordinates = function(map, x, y)
    return { uiMapID = map, position = { x = x, y = y } }
  end,
}
C_Map = {
  GetMapInfo = function(id)
    local info = MAP_INFO[id]
    if info then
      return { name = info.name, mapID = info.mapID, mapType = info.mapType, parentMapID = info.parentMapID }
    end
    return MAP_NAMES[id] and { name = MAP_NAMES[id], mapID = id } or { name = "Map " .. tostring(id), mapID = id }
  end,
  GetMapChildrenInfo = function(parent, mapType, allDescendants)
    local out = {}
    for _, info in pairs(MAP_INFO) do
      if not mapType or info.mapType == mapType then
        local match = info.parentMapID == parent
        if not match and allDescendants then
          local walk = info.parentMapID
          for _ = 1, 8 do
            if not walk then break end
            if walk == parent then match = true break end
            local up = MAP_INFO[walk]
            walk = up and up.parentMapID
          end
        end
        if match then
          table.insert(out, { mapID = info.mapID, name = info.name, mapType = info.mapType, parentMapID = info.parentMapID })
        end
      end
    end
    return out
  end,
  GetBestMapForUnit = function() return 2393 end,
  GetPlayerMapPosition = function()
    return { x = 0.5, y = 0.5, GetXY = function(s) return s.x, s.y end }
  end,
  CanSetUserWaypointOnMap = function() return true end,
  SetUserWaypoint = function(point) UserWaypoint = point end,
  ClearUserWaypoint = function() UserWaypoint = nil end,
  HasUserWaypoint = function() return UserWaypoint ~= nil end,
}
C_SuperTrack = {
  SetSuperTrackedUserWaypoint = function(on) SuperTrackedUserWaypoint = on and true or false end,
  GetSuperTrackedQuestID = function() return SuperTrackedQuestID end,
}
function OpenWorldMap(id)
  table.insert(OpenedWorldMaps, id)
end

C_Reputation = {
  ExpandAllFactionHeaders = function() end,
  GetNumFactions = function() return #ReputationFactions end,
  GetFactionDataByIndex = function(i) return ReputationFactions[i] end,
  IsMajorFaction = function(id) return id == 2600 end,
  IsFactionParagon = function() return false end,
  GetFactionParagonInfo = function() return 0, 10000, 0, false end,
}
ReputationFactions = {
  { name = "The War Within", isHeader = true, isChild = false, isCollapsed = false },
  { name = "Khaz Algar", isHeader = true, isChild = true, isCollapsed = false },
  { name = "Council of Dornogal", factionID = 2590, isHeader = false, isChild = true,
    currentStanding = 8500, currentReactionThreshold = 6000, nextReactionThreshold = 12000,
    reaction = 5 },
  { name = "Zul'jarra's Forces", factionID = 2600, isHeader = false, isChild = true,
    currentStanding = 500, currentReactionThreshold = 0, nextReactionThreshold = 2500,
    reaction = 4 },
  { name = "Undermine", isHeader = true, isChild = true, isCollapsed = false },
  { name = "The Cartels of Undermine", factionID = 2653, isHeader = false, isChild = true,
    currentStanding = 1500, currentReactionThreshold = 0, nextReactionThreshold = 3000,
    reaction = 4 },
  { name = "Dragonflight", isHeader = true, isChild = false, isCollapsed = false },
  { name = "Valdrakken Accord", factionID = 2510, isHeader = false, isChild = true,
    currentStanding = 42000, currentReactionThreshold = 42000, nextReactionThreshold = 42000,
    reaction = 8, isCapped = true },
}
C_MajorFactions = {
  GetMajorFactionIDs = function() return { 2600 } end,
  GetMajorFactionData = function()
    return { name = "Zul'jarra's Forces", renownLevel = 7, renownReputationEarned = 900,
             renownLevelThreshold = 2500 }
  end,
  HasMaximumRenown = function() return false end,
}
C_MountJournal = {
  GetNumMounts = function() return 600, 0 end,
  GetMountIDs = function()
    return { 69, 168, 183, 185, 213, 264, 304, 349, 363, 410, 411, 415, 425,
             442, 444, 445, 473, 478, 515, 531, 533, 542, 543, 559, 613, 634, 751, 899 }
  end,
  GetMountInfoByID = function(id)
    local names = {
      [69] = "Rivendare's Deathcharger", [168] = "Fiery Warhorse", [183] = "Ashes of Al'ar",
      [185] = "Raven Lord", [213] = "Swift White Hawkstrider", [264] = "Blue Proto-Drake",
      [304] = "Mimiron's Head", [349] = "Onyxian Drake", [363] = "Invincible",
      [410] = "Armored Razzashi Raptor", [411] = "Swift Zulian Panther",
      [415] = "Pureblood Fire Hawk", [425] = "Flametalon of Alysrazor",
      [442] = "Blazing Drake", [444] = "Life-Binder's Handmaiden", [445] = "Experiment 12-B",
      [473] = "Heavenly Onyx Cloud Serpent", [478] = "Astral Cloud Serpent",
      [515] = "Son of Galleon", [531] = "Spawn of Horridon", [533] = "Cobalt Primordial Direhorn",
      [542] = "Thundering Cobalt Cloud Serpent", [543] = "Clutch of Ji-Kun",
      [559] = "Kor'kron Juggernaut", [613] = "Ironhoof Destroyer", [634] = "Solar Spirehawk",
      [751] = "Felsteel Annihilator", [899] = "Abyss Worm",
    }
    local collected = CollectedMounts[id] == true
    return names[id] or ("Mount " .. tostring(id)), 0, 0, false, true, 1, false, false, nil, false, collected, id
  end,
}
CollectedMounts = {}
C_TransmogCollection = { GetNumTransmogSources = function() return 5000 end }

SavedInstances = {}
SavedWorldBosses = {}
RequestRaidInfo = function() end
GetNumSavedInstances = function() return #SavedInstances end
GetSavedInstanceInfo = function(i)
  local s = SavedInstances[i]
  if not s then return end
  return s.name, s.id or i, s.reset or 0, s.difficulty or 0, s.locked == true, false,
    0, s.isRaid ~= false, s.maxPlayers or 25, s.difficultyName or "",
    s.numEncounters or 0, s.encounterProgress or 0, false, s.instanceID
end
GetSavedInstanceEncounterInfo = function(i, j)
  local s = SavedInstances[i]
  local e = s and s.encounters and s.encounters[j]
  if not e then return end
  return e.name, nil, e.killed == true
end
GetNumSavedWorldBosses = function() return #SavedWorldBosses end
GetSavedWorldBossInfo = function(i)
  local s = SavedWorldBosses[i]
  if not s then return end
  return s.name, s.id or i, s.reset or 0
end

Enum = {
  WeeklyRewardChestThresholdType = { Raid = 1, Activities = 2, World = 3 },
  UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
  CampaignState = { Invalid = 0, Complete = 1, InProgress = 2, Stalled = 3 },
}
DifficultyUtil = {
  ID = { DungeonHeroic = 2, DungeonMythic = 23, DungeonChallenge = 8,
         PrimaryRaidLFR = 17, PrimaryRaidNormal = 14, PrimaryRaidHeroic = 15, PrimaryRaidMythic = 16 },
  GetDifficultyName = function(id)
    local names = { [17] = "Raid Finder", [14] = "Normal", [15] = "Heroic", [16] = "Mythic",
                    [2] = "Heroic", [23] = "Mythic", [8] = "Mythic Keystone" }
    return names[id] or ("Difficulty " .. tostring(id))
  end,
  GetNextPrimaryRaidDifficultyID = function(id)
    local next_ = { [17] = 14, [14] = 15, [15] = 16 }
    return next_[id]
  end,
}

C_MythicPlus = {
  GetRunHistory = function()
    return {
      { level = 7, completed = true, mapChallengeModeID = 403 },
      { level = 6, completed = true, mapChallengeModeID = 2 },
      { level = 5, completed = true, mapChallengeModeID = 403 },
      { level = 4, completed = true, mapChallengeModeID = 2 },
    }
  end,
}

C_ChallengeMode = {
  GetMapUIInfo = function(id)
    if id == 403 then return "The Rookery" end
    if id == 2 then return "Temple of the Jade Serpent" end
  end,
}

C_Item = {
  GetDetailedItemLevelInfo = function(link)
    if type(link) == "string" and link ~= "" then return 305 end
  end,
}

C_WowTokenPublic = {
  UpdateMarketPrice = function() end,
  GetCurrentMarketPrice = function()
    return 258652 * 10000
  end,
}

C_DateAndTime = {
  GetSecondsUntilWeeklyReset = function()
    return 16 * 3600 + 13 * 60
  end,
  GetSecondsUntilDailyReset = function()
    return 8 * 3600
  end,
}

GetCursorPosition = function() return 0, 0 end

function BreakUpLargeNumbers(n)
  n = math.floor(math.abs(tonumber(n) or 0))
  local s = tostring(n)
  return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function GetCoinTextureString(amount, height)
  amount = math.floor(tonumber(amount) or 0)
  local g = math.floor(amount / 10000)
  local size = tonumber(height) or 0
  return g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:" .. size .. ":" .. size .. ":2:0|t"
end

function GetMoneyString(amount, separateThousands)
  amount = math.floor(tonumber(amount) or 0)
  local g = math.floor(amount / 10000)
  local num = separateThousands and BreakUpLargeNumbers(g) or tostring(g)
  return num .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
end


-- Mirrors the reported live state: raid slot at Raid Finder, dungeons partly done,
-- world tiers of 11, 11 and 7 where 11 is the cap.
C_WeeklyRewards = {
  GetActivities = function(kind)
    local all = {
      { type = 1, index = 1, level = 17, threshold = 2, progress = 4, id = 1 },
      { type = 1, index = 2, level = 0, threshold = 4, progress = 4, id = 2 },
      { type = 1, index = 3, level = 0, threshold = 6, progress = 4, id = 3 },
      { type = 2, index = 1, level = 7, threshold = 1, progress = 4, id = 4 },
      { type = 2, index = 2, level = 6, threshold = 4, progress = 4, id = 5 },
      { type = 2, index = 3, level = 0, threshold = 8, progress = 4, id = 6 },
      { type = 3, index = 1, level = 11, threshold = 2, progress = 8, id = 7 },
      { type = 3, index = 2, level = 11, threshold = 4, progress = 8, id = 8 },
      { type = 3, index = 3, level = 7, threshold = 8, progress = 8, id = 9 },
    }
    if not kind then return all end
    local out = {}
    for _, activity in ipairs(all) do
      if activity.type == kind then table.insert(out, activity) end
    end
    return out
  end,
  GetActivityEncounterInfo = function() return nil end,
  GetDifficultyIDForActivityTier = function(tier) return tier end,
  GetNextActivitiesIncrease = function() return nil end,
  HasAvailableRewards = function() return false end,
  HasGeneratedRewards = function() return false end,
  CanClaimRewards = function() return false end,
  OnUIInteract = function() end,
  GetExampleRewardItemHyperlinks = function(id)
    if not id then return end
    return "|Hitem:" .. tostring(id) .. "|h|h", nil
  end,
  GetSortedProgressForActivity = function(kind)
    local id = type(kind) == "table" and kind.type or kind
    if id == 3 then
      return {
        { difficulty = 11, numPoints = 1 }, { difficulty = 11, numPoints = 1 },
        { difficulty = 8, numPoints = 1 }, { difficulty = 8, numPoints = 1 },
        { difficulty = 7, numPoints = 1 }, { difficulty = 7, numPoints = 1 },
        { difficulty = 7, numPoints = 1 }, { difficulty = 7, numPoints = 1 },
      }
    end
    return {}
  end,
}

GetTime = function() return 1000 end
time = os.time
date = os.date
