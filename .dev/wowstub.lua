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
function methods.GetFrameLevel(self) return 1 end
function methods.GetVerticalScroll(self) return 0 end
function methods.GetChildren(self) return unpack(self.children) end
function methods.GetRegions(self) return unpack(self.regions) end
function methods.RegisterEvent(self, e) self.events[e] = true end

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

AllFrames = {}

function CreateFrame(kind, name, parent, template)
  local f = new(kind, name, parent)
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
GameTooltip = new("Frame", "GameTooltip")
SlashCmdList = {}

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

function ReloadUI() end

UnitName = function() return "Testchar" end
GetRealmName = function() return "Testrealm" end
UnitLevel = function() return 80 end
UnitClass = function() return "Mage", "MAGE" end
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return 62, "Arcane" end
GetProfessions = function() return 1, 2 end
GetProfessionInfo = function(index)
  if index == 1 then return "Alchemy", nil, 100, 100, nil, nil, 171 end
  return "Herbalism", nil, 100, 100, nil, nil, 182
end

C_AddOns = { IsAddOnLoaded = function() return false end }

C_TradeSkillUI = {
  GetAllProfessionTradeSkillLines = function() return { 2871, 2823, 2757 } end,
  GetProfessionInfoBySkillLineID = function(id)
    local names = { [2871] = "Alchemy", [2823] = "Herbalism", [2757] = "Alchemy" }
    return {
      professionName = names[id] or "Alchemy",
      isPrimaryProfession = true,
      skillLevel = id == 2757 and 0 or 60,
      maxSkillLevel = 100,
      professionID = names[id] == "Herbalism" and 182 or 171,
    }
  end,
}

C_ProfSpecs = {
  SkillLineHasSpecialization = function() return true end,
  GetConfigIDForSkillLine = function() return 1 end,
  GetCurrencyInfoForSkillLine = function() return { currencyID = 2033, quantity = 3 } end,
  GetSpecTabIDsForSkillLine = function() return {} end,
  GetTabInfo = function() return nil end,
  GetChildrenForPath = function() return {} end,
}
C_Traits = { GetNodeInfo = function() return nil end }
C_CurrencyInfo = { GetCurrencyInfo = function() return { quantity = 3, maxQuantity = 0 } end }
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end }

C_Reputation = {
  GetNumFactions = function() return 1 end,
  GetFactionDataByIndex = function()
    return { name = "Zul'jarra's Forces", factionID = 2600, currentStanding = 500,
             currentReactionThreshold = 0, nextReactionThreshold = 2500 }
  end,
}
C_MajorFactions = {
  GetMajorFactionIDs = function() return { 2600 } end,
  GetMajorFactionData = function()
    return { name = "Zul'jarra's Forces", renownLevel = 7, renownReputationEarned = 900,
             renownLevelThreshold = 2500 }
  end,
  HasMaximumRenown = function() return false end,
}
C_MountJournal = { GetNumMounts = function() return 600, 420 end }
C_TransmogCollection = { GetNumTransmogSources = function() return 5000 end }

Enum = { WeeklyRewardChestThresholdType = { Raid = 1, Activities = 2, World = 3 } }
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
      { level = 7, completed = true }, { level = 6, completed = true },
      { level = 5, completed = true }, { level = 4, completed = true },
    }
  end,
}

-- Mirrors the reported live state: raid slot at Raid Finder, dungeons partly done,
-- world tiers of 11, 11 and 7 where 11 is the cap.
C_WeeklyRewards = {
  GetActivities = function()
    return {
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
  end,
  GetActivityEncounterInfo = function() return nil end,
  GetDifficultyIDForActivityTier = function(tier) return tier end,
  GetNextActivitiesIncrease = function() return nil end,
  GetSortedProgressForActivity = function(activity)
    if activity.type == 3 then
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
