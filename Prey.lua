local _, LS = ...

-- Prey hunts are world activities: they bank World Vault progress and drop gear.
-- The client already knows the active hunt. Unlock quests (Prey, Voidcores) are
-- marked important and ranked with campaign priority in Quests.lua.

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function PlayerMap()
  return Safe(C_Map and C_Map.GetBestMapForUnit, "player")
end

local function QuestTitle(questID)
  local title = Safe(C_QuestLog and C_QuestLog.GetTitleForQuestID, questID)
  if type(title) == "string" and title ~= "" then return title end
  local n = Safe(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or 0
  if type(n) == "number" and C_QuestLog and C_QuestLog.GetInfo then
    for i = 1, n do
      local info = Safe(C_QuestLog.GetInfo, i)
      if type(info) == "table" and info.questID == questID and type(info.title) == "string"
          and info.title ~= "" then
        return info.title
      end
    end
  end
end

local function QuestPoints(questID, title)
  local map, x, y
  if C_QuestLog and C_QuestLog.GetNextWaypoint then
    map, x, y = Safe(C_QuestLog.GetNextWaypoint, questID)
  end
  if not map and C_QuestLog and C_QuestLog.GetQuestUiMapID then
    map = Safe(C_QuestLog.GetQuestUiMapID, questID)
  end
  if not map then map = PlayerMap() end
  if not map then return end
  if type(x) == "number" and type(y) == "number" then
    if x <= 1 and y <= 1 then
      x, y = x * 100, y * 100
    end
    return { { map = map, x = x, y = y, title = title } }
  end
  return { { map = map, title = title } }
end

local function AttachOpen(rec, points)
  if not points then return rec end
  rec.waypoints = points
  rec.openLabel = LS:WaypointButtonLabel(points) or "Map"
  rec.open = function() LS:MarkWaypoints(points, rec.title) end
  return rec
end

function LS:ActivePreyQuest()
  local id = Safe(C_QuestLog and C_QuestLog.GetActivePreyQuest)
  if type(id) == "number" and id > 0 then return id end
end

function LS:GetPreyRecommendations()
  local out = {}
  local active = self:ActivePreyQuest()
  if active then
    local title = QuestTitle(active) or "Prey hunt"
    local rec = {
      id = "prey",
      title = "Continue: " .. title,
      category = "Solo content",
      urgency = "HIGH",
      tags = { PREY = 14, SOLO = 8, ENDGAME = 8, QUESTING = 10 },
      why = "This Prey hunt is in progress. Finishing it banks World Vault progress and hunt gear.",
      detail = {
        nextReward = "World Vault progress and hunt gear",
        source = "Prey",
        matters = "Prey hunts are world activities. The client named this hunt; Lodestar did not invent it.",
      },
    }
    table.insert(out, AttachOpen(rec, QuestPoints(active, title)))
    return out
  end

  -- Generic hunts stay off unless the player asked for Prey. Delves still cover
  -- World Vault when that goal is off. Hunt locations stay on the client's table.
  if not (self.db and self.db.goals and self.db.goals.PREY) then
    return out
  end

  local map = PlayerMap()
  local points = map and { { map = map } } or nil
  table.insert(out, AttachOpen({
    id = "prey",
    title = "Complete a Prey hunt",
    category = "Solo content",
    urgency = "MEDIUM",
    tags = { PREY = 12 },
    why = "Prey hunts are world activities: they fill the World Vault and drop gear.",
    detail = {
      nextReward = "World Vault progress and hunt gear",
      source = "Prey",
      matters = "Start a hunt from the table the client shows once Prey is unlocked. Lodestar does not invent hunt locations.",
    },
  }, points))
  return out
end

local function SafePrey(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a = pcall(fn, ...)
  if ok then return a end
end

local function PreyFactionFromName()
  local ids = SafePrey(C_MajorFactions and C_MajorFactions.GetMajorFactionIDs)
  if type(ids) ~= "table" then return end
  local needles = { "preyhunter", "preyseeker", "prey hunter", "prey seeker" }
  for _, id in ipairs(ids) do
    local data = SafePrey(C_MajorFactions and C_MajorFactions.GetMajorFactionData, id)
    local name = data and string.lower(data.name or data.factionName or "")
    if name ~= "" then
      for _, needle in ipairs(needles) do
        if name:find(needle, 1, true) then return tonumber(id) or tonumber(data.factionID) end
      end
    end
  end
end

function LS:PreyJourneyFaction()
  for _, ns in ipairs({ C_QuestLog, C_Prey, C_PreyUI, C_PreyHunts, C_DelvesUI }) do
    if type(ns) == "table" then
      local id = SafePrey(ns.GetPreyFactionForSeason)
        or SafePrey(ns.GetPreyHuntsFactionForSeason)
        or SafePrey(ns.GetPreyseekerFactionForSeason)
      if tonumber(id) then return tonumber(id) end
    end
  end
  return PreyFactionFromName()
end

function LS:OpenPreyJourney()
  if self.OpenJourneys and self:OpenJourneys() then return true end
  return false
end

function LS:PreyJourney()
  local faction = self:PreyJourneyFaction()
  local progress = self.SeasonJourneyProgress and self:SeasonJourneyProgress(faction)
  if progress then
    progress.name = progress.name or "Preyhunter's Journey"
    return progress
  end
  return { name = "Preyhunter's Journey" }
end
