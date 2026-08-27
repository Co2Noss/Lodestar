local _, LS = ...

-- All The Things tracks mounts, appearances, and achievements through the client's
-- content-tracking API (Alt+click in ATT). Quest watches use the quest log. Can I
-- Mog It can flag learnable appearances already in your bags. Lodestar only reads
-- what those addons expose; it does not invent a collection database.

local MAX_TRACKED = 12

-- Matches AllTheThings/src/UI/Window Definitions.lua content-tracking types.
local TRACK_APPEARANCE = 0
local TRACK_MOUNT = 1
local TRACK_ACHIEVEMENT = 2

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function AddonLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

function LS:HasATT()
  local att = _G.ATTC
  if not att then return false end
  return type(att.SearchForObject) == "function" or type(att.GetLinkReference) == "function"
end

function LS:GetATT()
  if self:HasATT() then return _G.ATTC end
end

function LS:HasCanIMogIt()
  return CanIMogIt and type(CanIMogIt.PlayerKnowsTransmog) == "function"
end

local function ATTObject(att, field, id)
  if not att or not id then return end
  local ok, obj = pcall(att.SearchForObject, att, field, id, "field")
  if ok and obj then return obj end
  ok, obj = pcall(att.SearchForObject, att, field, id, "key")
  if ok then return obj end
end

local function ATTLabel(att, obj, fallback)
  if type(obj) == "table" then
    local label = obj.text or obj.name
    if type(label) == "string" and label ~= "" then return label end
  end
  return fallback
end

local function ATTDone(att, obj)
  if type(obj) ~= "table" then return false end
  if obj.collected then return true end
  if att and att.IsComplete then
    local ok, done = pcall(att.IsComplete, att, obj)
    if ok and done then return true end
  end
  return false
end

local function ATTSourceLine(att, obj)
  if type(obj) ~= "table" then return end
  local parent = obj.parent
  for _ = 1, 6 do
    if type(parent) ~= "table" then break end
    local label = parent.text or parent.name
    if type(label) == "string" and label ~= "" then
      return label
    end
    parent = parent.parent
  end
  if att and att.GetRelativeField then
    local mapID = Safe(att.GetRelativeField, att, obj, "mapID")
    if mapID and C_Map and C_Map.GetMapInfo then
      local info = C_Map.GetMapInfo(mapID)
      if info and info.name then return info.name end
    end
  end
end

local function TrackedIDs(trackType)
  if not (C_ContentTracking and C_ContentTracking.GetTrackedIDs) then return {} end
  local ok, ids = pcall(C_ContentTracking.GetTrackedIDs, trackType)
  if ok and type(ids) == "table" then return ids end
  return {}
end

local function TrackingWaypoint(trackType, trackID)
  if not (C_ContentTracking and C_ContentTracking.GetBestMapForTrackable) then return end
  local mapID = Safe(C_ContentTracking.GetBestMapForTrackable, trackType, trackID)
  if not mapID then return end
  local point = { mapID = mapID }
  if C_ContentTracking.GetNextWaypointForTrackable then
    local ok, mapInfo = pcall(C_ContentTracking.GetNextWaypointForTrackable, trackType, trackID, mapID)
    if ok and type(mapInfo) == "table" then
      if mapInfo.x and mapInfo.y then
        point.x = mapInfo.x * 100
        point.y = mapInfo.y * 100
      end
      if mapInfo.mapID then point.mapID = mapInfo.mapID end
    end
  end
  return point
end

local function QuestComplete(questID)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    if C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
  end
  if C_QuestLog and C_QuestLog.IsComplete then
    return C_QuestLog.IsComplete(questID) == true
  end
  return false
end

local function WatchedQuestIDs()
  local out, seen = {}, {}
  local function add(questID)
    if questID and not seen[questID] then
      seen[questID] = true
      table.insert(out, questID)
    end
  end
  if C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
    local n = C_QuestLog.GetNumQuestWatches() or 0
    for i = 1, n do
      add(C_QuestLog.GetQuestIDForQuestWatchIndex(i))
    end
  end
  if C_QuestLog and C_QuestLog.GetNumWorldQuestWatches and C_QuestLog.GetQuestIDForWorldQuestWatchIndex then
    local n = C_QuestLog.GetNumWorldQuestWatches() or 0
    for i = 1, n do
      add(C_QuestLog.GetQuestIDForWorldQuestWatchIndex(i))
    end
  end
  return out
end

local function AppearanceKnown(sourceID)
  if CanIMogIt and CanIMogIt.GetItemLinkFromSourceID and CanIMogIt.PlayerKnowsTransmog then
    local link = CanIMogIt:GetItemLinkFromSourceID(sourceID)
    if link then
      local ok, known = pcall(CanIMogIt.PlayerKnowsTransmog, CanIMogIt, link)
      if ok and known then return true end
    end
  end
  if C_TransmogCollection and C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
    return C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID) == true
  end
  return false
end

local function MountJournalIDsAlreadyRecommended(self)
  local covered = {}
  if not self.GetMountRecommendations then return covered end
  for _, rec in ipairs(self:GetMountRecommendations()) do
    local farmID = rec.id and rec.id:match("^mount_(.+)$")
    if farmID then
      for _, farm in ipairs(self.mountFarms or {}) do
        if farm.id == farmID and farm.mountID then
          covered[farm.mountID] = true
        end
      end
    end
  end
  return covered
end

function LS:GetATTRecommendations()
  local out = {}
  if not self:HasATT() then return out end
  if not (C_ContentTracking or C_QuestLog) then return out end

  local att = self:GetATT()
  local goals = self.db.goals or {}
  local seen = {}
  local mountCovered = MountJournalIDsAlreadyRecommended(self)

  local function push(rec)
    if not rec or not rec.id or seen[rec.id] or #out >= MAX_TRACKED then return end
    seen[rec.id] = true
    table.insert(out, rec)
  end

  if goals.MOUNTS and C_ContentTracking then
    for _, mountID in ipairs(TrackedIDs(TRACK_MOUNT)) do
      if not mountCovered[mountID] and not self:HasMount(mountID) then
        local spellID
        if C_MountJournal and C_MountJournal.GetMountInfoByID then
          spellID = select(2, C_MountJournal.GetMountInfoByID(mountID))
        end
        local obj = (spellID and ATTObject(att, "mountID", spellID)) or ATTObject(att, "mountID", mountID)
        if not ATTDone(att, obj) then
          local name = ATTLabel(att, obj, "Tracked mount")
          local wp = TrackingWaypoint(TRACK_MOUNT, mountID)
          push({
            id = "att_mount_" .. mountID,
            title = "Track " .. name,
            minutes = 20,
            score = 24,
            why = "You are tracking this mount in All The Things.",
            category = "Mounts",
            tags = { MOUNTS = 14 },
            urgency = "MEDIUM",
            priority = "OPEN",
            waypoints = wp and { { title = name, mapID = wp.mapID, x = wp.x, y = wp.y } } or nil,
            detail = {
              source = ATTSourceLine(att, obj) or "All The Things",
              current = "Tracked, not collected",
              matters = "Lodestar follows mounts you track in ATT.",
            },
          })
        end
      end
    end
  end

  if goals.MOUNTS and C_ContentTracking then
    for _, sourceID in ipairs(TrackedIDs(TRACK_APPEARANCE)) do
      if not AppearanceKnown(sourceID) then
        local obj = ATTObject(att, "sourceID", sourceID)
        if not ATTDone(att, obj) then
          local name = ATTLabel(att, obj, "Tracked appearance")
          local wp = TrackingWaypoint(TRACK_APPEARANCE, sourceID)
          push({
            id = "att_appearance_" .. sourceID,
            title = "Track " .. name,
            minutes = 15,
            score = 22,
            why = "You are tracking this appearance in All The Things.",
            category = "Mounts",
            tags = { MOUNTS = 12 },
            urgency = "MEDIUM",
            priority = "OPEN",
            waypoints = wp and { { title = name, mapID = wp.mapID, x = wp.x, y = wp.y } } or nil,
            detail = {
              source = ATTSourceLine(att, obj) or "All The Things",
              current = "Tracked, not collected",
              matters = "Lodestar follows appearances you track in ATT.",
            },
          })
        end
      end
    end
  end

  if goals.ENDGAME and C_ContentTracking then
    for _, achievementID in ipairs(TrackedIDs(TRACK_ACHIEVEMENT)) do
      local obj = ATTObject(att, "achievementID", achievementID)
      if not ATTDone(att, obj) then
        local _, _, completed = Safe(GetAchievementInfo, achievementID)
        if not completed then
          local name = ATTLabel(att, obj, "Tracked achievement")
          push({
            id = "att_achievement_" .. achievementID,
            title = "Track " .. name,
            minutes = 25,
            score = 20,
            why = "You are tracking this achievement in All The Things.",
            category = "Great Vault & endgame",
            tags = { ENDGAME = 8 },
            urgency = "MEDIUM",
            priority = "OPEN",
            detail = {
              source = ATTSourceLine(att, obj) or "All The Things",
              current = "Tracked, not finished",
              matters = "Lodestar follows achievements you track in ATT.",
            },
          })
        end
      end
    end
  end

  if goals.QUESTING then
    for _, questID in ipairs(WatchedQuestIDs()) do
      if not QuestComplete(questID) then
        local obj = ATTObject(att, "questID", questID)
        if not ATTDone(att, obj) then
          local title = ATTLabel(att, obj, Safe(C_QuestLog.GetTitleForQuestID, questID) or ("Quest " .. questID))
          push({
            id = "att_quest_" .. questID,
            title = "Track " .. title,
            minutes = 15,
            score = 18,
            why = "This quest is on your watch list through All The Things.",
            category = "Questing",
            tags = { QUESTING = 10 },
            urgency = "MEDIUM",
            priority = "OPEN",
            detail = {
              source = ATTSourceLine(att, obj) or "Quest log watch",
              current = "Watched, not finished",
              matters = "Lodestar follows quests you watch in ATT.",
            },
          })
        end
      end
    end
  end

  return out
end

function LS:GetCanIMogItRecommendations()
  local out = {}
  if not self.db.goals.MOUNTS or not self:HasCanIMogIt() then return out end
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return out end

  local learnable = 0
  local maxBag = NUM_BAG_SLOTS or 4
  for bag = 0, maxBag do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local link = info and info.hyperlink
      if link and CanIMogIt.IsTransmogable and CanIMogIt:IsTransmogable(link) then
        local ok, canLearn = pcall(CanIMogIt.CharacterCanLearnTransmog, CanIMogIt, link)
        if ok and canLearn then
          local known
          ok, known = pcall(CanIMogIt.PlayerKnowsTransmog, CanIMogIt, link)
          if ok and not known then
            learnable = learnable + 1
          end
        end
      end
    end
  end

  if learnable > 0 then
    table.insert(out, {
      id = "cimi_bag_transmog",
      title = learnable == 1 and "Learn 1 appearance from your bags"
        or ("Learn %d appearances from your bags"):format(learnable),
      minutes = 5,
      score = 16,
      why = "Can I Mog It says these bag items teach appearances you do not have yet.",
      category = "Mounts",
      tags = { MOUNTS = 10 },
      urgency = "LOW",
      priority = "OPEN",
      detail = {
        source = "Your bags",
        current = learnable .. " learnable appearance" .. (learnable == 1 and "" or "s"),
        matters = "Visit a transmogrifier or open the Appearances tab to learn them.",
      },
    })
  end
  return out
end

function LS:GetCollectionRecommendations()
  local out = {}
  for _, rec in ipairs(self:GetATTRecommendations()) do
    table.insert(out, rec)
  end
  for _, rec in ipairs(self:GetCanIMogItRecommendations()) do
    table.insert(out, rec)
  end
  return out
end
