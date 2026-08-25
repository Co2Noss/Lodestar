local _, LS = ...

-- Questing recommendations come from the live campaign and quest log, not a
-- Lodestar list of quest IDs. If both are empty, the player is asked to check
-- the map rather than being handed a made-up world-quest circuit.

local MAX_LOG = 4

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function CampaignStateEnum()
  return Enum and Enum.CampaignState
end

local function StateComplete()
  local e = CampaignStateEnum()
  return e and e.Complete or 1
end

local function StateInProgress()
  local e = CampaignStateEnum()
  return e and e.InProgress or 2
end

local function StateStalled()
  local e = CampaignStateEnum()
  return e and e.Stalled or 3
end

local function PlayerMap()
  return Safe(C_Map and C_Map.GetBestMapForUnit, "player")
end

local function MapPoints(mapID, x, y, title)
  if not mapID then return end
  if type(x) == "number" and type(y) == "number" then
    if x <= 1 and y <= 1 then
      x, y = x * 100, y * 100
    end
    return { { map = mapID, x = x, y = y, title = title } }
  end
  return { { map = mapID, title = title } }
end

local function QuestWaypoint(questID, title, info)
  local map, x, y
  if C_QuestLog and C_QuestLog.GetNextWaypoint then
    map, x, y = Safe(C_QuestLog.GetNextWaypoint, questID)
  end
  if not map and C_QuestLog and C_QuestLog.GetQuestUiMapID then
    map = Safe(C_QuestLog.GetQuestUiMapID, questID)
  end
  if not map and info and (info.isOnMap or info.hasLocalPOI) then
    map = PlayerMap()
  end
  return MapPoints(map, x, y, title)
end

local function IsWorldQuest(info)
  if info.isTask or info.isBounty then return true end
  if C_QuestLog and C_QuestLog.IsWorldQuest then
    return Safe(C_QuestLog.IsWorldQuest, info.questID) and true or false
  end
  return false
end

local function IsTurnIn(info)
  if info.readyForTurnIn then return true end
  if C_QuestLog and C_QuestLog.IsComplete then
    return Safe(C_QuestLog.IsComplete, info.questID) and true or false
  end
  return info.isComplete and true or false
end

local function QuestLogEntries()
  local n = Safe(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or 0
  local out = {}
  if type(n) ~= "number" or n <= 0 or not (C_QuestLog and C_QuestLog.GetInfo) then
    return out
  end
  for i = 1, n do
    local info = Safe(C_QuestLog.GetInfo, i)
    if type(info) == "table" and info.questID and not info.isHeader and not info.isHidden
        and not IsWorldQuest(info) then
      table.insert(out, info)
    end
  end
  return out
end

local function CampaignName(campaignID)
  local info = Safe(C_CampaignInfo and C_CampaignInfo.GetCampaignInfo, campaignID)
  if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
    return info.name
  end
end

local function ChapterName(campaignID)
  local chapterID = Safe(C_CampaignInfo and C_CampaignInfo.GetCurrentChapterID, campaignID)
  if not chapterID then return end
  local info = Safe(C_CampaignInfo and C_CampaignInfo.GetChapterInfo, chapterID)
  if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
    return info.name
  end
end

local function CampaignIDForQuest(info)
  if info.campaignID and info.campaignID ~= 0 then return info.campaignID end
  if C_CampaignInfo and C_CampaignInfo.GetCampaignID then
    local id = Safe(C_CampaignInfo.GetCampaignID, info.questID)
    if id and id ~= 0 then return id end
  end
  if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest then
    if Safe(C_CampaignInfo.IsCampaignQuest, info.questID) then
      return info.campaignID
    end
  end
end

local function CollectCampaignIDs(log)
  local ids, seen = {}, {}
  local function add(id)
    if type(id) == "number" and id ~= 0 and not seen[id] then
      seen[id] = true
      table.insert(ids, id)
    end
  end
  local available = Safe(C_CampaignInfo and C_CampaignInfo.GetAvailableCampaigns)
  if type(available) == "table" then
    for _, id in ipairs(available) do add(id) end
  end
  for _, info in ipairs(log) do
    add(CampaignIDForQuest(info))
  end
  return ids
end

local function PickCampaign(ids, log)
  local complete, inProgress, stalled = StateComplete(), StateInProgress(), StateStalled()
  local byID = {}
  for _, info in ipairs(log) do
    local id = CampaignIDForQuest(info)
    if id and not byID[id] then byID[id] = info end
  end

  local best, bestRank
  for _, id in ipairs(ids) do
    local state = Safe(C_CampaignInfo and C_CampaignInfo.GetState, id)
    if state ~= complete then
      local rank = 0
      if byID[id] then
        rank = 40
      elseif state == stalled then
        rank = 30
      elseif state == inProgress then
        rank = 20
      else
        rank = 10
      end
      if not bestRank or rank > bestRank then
        best, bestRank = { id = id, state = state, quest = byID[id] }, rank
      end
    end
  end
  return best
end

local function AttachOpen(rec, points)
  if not points then return rec end
  rec.waypoints = points
  rec.openLabel = LS:WaypointButtonLabel(points) or "Map"
  rec.open = function() LS:MarkWaypoints(points, rec.title) end
  return rec
end

local function CampaignRec(picked)
  local name = CampaignName(picked.id) or "campaign"
  local chapter = ChapterName(picked.id)
  local quest = picked.quest
  local stalled = picked.state == StateStalled()
  local inProgress = picked.state == StateInProgress()
  local title, why, urgency

  if quest and quest.title and quest.title ~= "" then
    title = (IsTurnIn(quest) and "Turn in: " or "Continue: ") .. quest.title
    why = "Current " .. name .. " quest in your log."
    if chapter then why = why .. " Chapter: " .. chapter .. "." end
    urgency = IsTurnIn(quest) and "HIGH" or (stalled and "HIGH" or "MEDIUM")
  elseif stalled then
    title = "Catch up on " .. name
    why = "This campaign is stalled. Check the map for the next chapter."
    if chapter then why = "Stalled on " .. chapter .. ". Check the map for the next step." end
    urgency = "HIGH"
  elseif inProgress then
    title = "Continue " .. name
    why = chapter and ("Current chapter: " .. chapter .. ".")
      or "The campaign is in progress. Check the map if the next quest is not in your log."
    urgency = "MEDIUM"
  else
    title = "Catch up on " .. name
    why = "This campaign is available and you have not finished it. Check the map to start or resume it."
    urgency = "MEDIUM"
  end

  local rec = {
    id = "campaign_" .. tostring(picked.id),
    title = title,
    category = "Questing",
    urgency = urgency,
    tags = { QUESTING = 14 },
    why = why,
    detail = {
      nextReward = "Campaign progress",
      source = "Campaign",
      matters = why,
    },
  }
  if quest then
    return AttachOpen(rec, QuestWaypoint(quest.questID, quest.title, quest))
  end
  local map = PlayerMap()
  return AttachOpen(rec, map and { { map = map } } or nil)
end

local function LogRec(info, superTracked)
  local ready = IsTurnIn(info)
  local title = info.title or ("Quest " .. tostring(info.questID))
  if ready then title = "Turn in: " .. title end
  local why
  if ready then
    why = "This quest is ready to turn in."
  elseif info.questID == superTracked then
    why = "This is the quest you are super-tracking."
  elseif info.isOnMap or info.hasLocalPOI then
    why = "This quest is on the map."
  else
    why = "In your quest log."
  end
  local rec = {
    id = "quest_" .. tostring(info.questID),
    title = title,
    category = "Questing",
    urgency = ready and "HIGH" or (info.questID == superTracked and "MEDIUM" or "LOW"),
    tags = { QUESTING = ready and 12 or 8 },
    why = why,
    detail = {
      nextReward = ready and "Turn-in" or "Quest progress",
      source = "Quest log",
      matters = why,
    },
  }
  return AttachOpen(rec, QuestWaypoint(info.questID, info.title, info))
end

local function CheckMapRec()
  local map = PlayerMap()
  local points = map and { { map = map } } or nil
  return AttachOpen({
    id = "quest_check_map",
    title = "Check your map and pick up quests",
    category = "Questing",
    urgency = "LOW",
    tags = { QUESTING = 6 },
    why = "Nothing in the quest log and no campaign chapter waiting. Open the map and take the quests that are there.",
    detail = {
      nextReward = "Whatever the map is offering",
      matters = "Lodestar will not invent quests. Once something is in your log or a campaign chapter is available, it will show up here.",
    },
  }, points)
end

function LS:GetQuestRecommendations()
  local out = {}
  local log = QuestLogEntries()
  local picked = PickCampaign(CollectCampaignIDs(log), log)
  local usedQuest
  if picked then
    table.insert(out, CampaignRec(picked))
    usedQuest = picked.quest and picked.quest.questID
  end

  local superTracked = Safe(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)
  local extras = {}
  for _, info in ipairs(log) do
    if info.questID ~= usedQuest then
      table.insert(extras, info)
    end
  end
  table.sort(extras, function(a, b)
    local function rank(info)
      local r = 0
      if IsTurnIn(info) then r = r + 100 end
      if info.questID == superTracked then r = r + 50 end
      if info.isOnMap or info.hasLocalPOI then r = r + 10 end
      return r
    end
    local ra, rb = rank(a), rank(b)
    if ra ~= rb then return ra > rb end
    return (a.title or "") < (b.title or "")
  end)
  for i = 1, math.min(MAX_LOG, #extras) do
    table.insert(out, LogRec(extras[i], superTracked))
  end

  if #out == 0 then
    table.insert(out, CheckMapRec())
  end
  return out
end
