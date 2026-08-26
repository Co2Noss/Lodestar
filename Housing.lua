local _, LS = ...

-- Housing is a goal. Lodestar ranks a missing house, unfinished neighborhood
-- initiatives, and weekly housing quests already in the log. It does not invent
-- plots, quest IDs, or a shopping list. The dashboard tile opens the client's
-- Housing Dashboard; teleport uses C_Housing.TeleportHome when the client has
-- a house GUID.

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

local function Count(t)
  if type(t) ~= "table" then return 0 end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function Num(v)
  if type(v) == "number" then return v end
  if type(v) == "string" then return tonumber(v) end
  if type(v) ~= "table" then return end
  return tonumber(v.progress) or tonumber(v.current) or tonumber(v.contribution)
    or tonumber(v.playerContribution) or tonumber(v.quantity) or tonumber(v.value)
    or tonumber(v.amount) or tonumber(v.favor) or tonumber(v.houseFavor)
    or tonumber(v.levelFavor)
end

local function Cap(v)
  if type(v) ~= "table" then return end
  return tonumber(v.maxProgress) or tonumber(v.required) or tonumber(v.total)
    or tonumber(v.max) or tonumber(v.contributionRequired) or tonumber(v.threshold)
    or tonumber(v.goal)
end

local function FirstHouse(houses)
  if type(houses) ~= "table" then return end
  if houses[1] then return houses[1] end
  for _, house in pairs(houses) do
    if type(house) == "table" then return house end
  end
end

function LS:HousingAPIsReady()
  return C_Housing and (C_Housing.GetPlayerOwnedHouses or C_Housing.GetCurrentHouseInfo) and true
end

function LS:PlayerOwnsHouse()
  local houses = Safe(C_Housing and C_Housing.GetPlayerOwnedHouses)
  if type(houses) == "table" and Count(houses) > 0 then return true end
  local info = Safe(C_Housing and C_Housing.GetCurrentHouseInfo)
  if type(info) == "table" and (info.houseName or info.plotID or info.ownerName or info.houseGUID) then
    return true
  end
  return false
end

function LS:OpenHousingDashboard()
  if self.ClientFrameShown and self:ClientFrameShown("HousingDashboardFrame") then
    self:HideClientFrame(_G.HousingDashboardFrame)
    return true
  end
  if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_HousingDashboard")
  elseif LoadAddOn then
    pcall(LoadAddOn, "Blizzard_HousingDashboard")
  end
  local frame = _G.HousingDashboardFrame
  if frame then
    if ShowUIPanel then
      pcall(ShowUIPanel, frame)
    elseif frame.Show then
      frame:Show()
    end
    if self.FrontClientFrame then self:FrontClientFrame(frame) end
    return true
  end
  local micro = _G.HousingMicroButton
  if micro and micro.Click then
    pcall(micro.Click, micro)
    return true
  end
  if ToggleHousingDashboard then
    pcall(ToggleHousingDashboard)
    return true
  end
  return false
end

function LS:TeleportToHouse()
  local info = self:HousingProgress()
  if not info or not info.owned then return false end
  if not (info.neighborhoodGUID and info.houseGUID) then return false end
  if not (C_Housing and C_Housing.TeleportHome) then return false end
  -- Protected: must run from the click, not through pcall.
  C_Housing.TeleportHome(info.neighborhoodGUID, info.houseGUID, info.plotID)
  return true
end

local function FavorForLevel(level)
  return Safe(C_Housing and C_Housing.GetHouseLevelFavorForLevel, level)
end

local function CurrentFavor(houseGUID)
  local a, b, c = Safe(C_Housing and C_Housing.GetCurrentHouseLevelFavor, houseGUID)
  if type(a) == "table" then
    return Num(a), tonumber(a.level) or tonumber(a.houseLevel)
  end
  if type(a) == "number" then
    local level
    if type(b) == "number" and b >= 1 and b <= 50 and (not c or b <= (c or b)) then
      -- Some clients return favor, level; others return current, needed.
      if b <= 40 and (not c or type(c) ~= "number" or c > b) and FavorForLevel(b) then
        level = b
      end
    end
    return a, level
  end
end

function LS:HousingProgress()
  local out = { owned = false }
  if not self:HousingAPIsReady() then return out end
  local houses = Safe(C_Housing.GetPlayerOwnedHouses)
  local house = FirstHouse(houses) or Safe(C_Housing.GetCurrentHouseInfo)
  if type(house) ~= "table" then return out end
  out.owned = true
  out.name = house.houseName
  out.neighborhood = house.neighborhoodName
  out.plotID = house.plotID
  out.houseGUID = house.houseGUID
  out.neighborhoodGUID = house.neighborhoodGUID
  out.level = tonumber(house.houseLevel) or tonumber(house.level)
  local favor, favorLevel = CurrentFavor(house.houseGUID)
  out.favor = favor
  if not out.level then out.level = favorLevel end
  local maxLevel = Safe(C_Housing.GetMaxHouseLevel)
  out.maxLevel = tonumber(maxLevel)
  if type(out.favor) == "number" and not out.level then
    local cap = out.maxLevel or 20
    local level = 1
    local nextNeed
    for lv = 1, cap do
      local need = FavorForLevel(lv)
      if type(need) ~= "number" then break end
      if out.favor >= need then
        level = lv
      else
        nextNeed = need
        break
      end
    end
    out.level = level
    out.nextFavor = nextNeed
  elseif type(out.favor) == "number" and out.level then
    out.nextFavor = FavorForLevel((out.level or 1) + 1)
  end
  if type(out.favor) == "number" and type(out.nextFavor) == "number" and out.nextFavor > 0 then
    local prev = 0
    if out.level then
      local need = FavorForLevel(out.level)
      if type(need) == "number" then prev = need end
    end
    local span = out.nextFavor - prev
    if span > 0 then
      out.fill = math.max(0, math.min(1, (out.favor - prev) / span))
    else
      out.fill = 1
    end
  elseif out.maxLevel and out.level and out.level >= out.maxLevel then
    out.fill = 1
  end
  return out
end

-- Weekly housing work already in the log (Housewarming and the like). Title and
-- weekly flags come from the client. Lodestar does not keep a quest ID list.
function LS:IsHousingWeeklyQuest(info)
  if type(info) ~= "table" or not info.questID then return false end
  local title = string.lower(info.title or "")
  local named = title:find("housewarming", 1, true) ~= nil
    or title:find("house warming", 1, true) ~= nil
  local weekly = info.isWeekly and true or false
  local freq = info.frequency
  local weeklyEnum = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly
  if freq == 2 or (weeklyEnum and freq == weeklyEnum) then weekly = true end
  local tagged = info.tagName == "Housing" or info.questTagType == "Housing"
  if C_QuestLog and C_QuestLog.GetQuestTagInfo then
    local tag = Safe(C_QuestLog.GetQuestTagInfo, info.questID)
    if type(tag) == "table" then
      local tagName = string.lower(tostring(tag.tagName or tag.name or ""))
      if tagName:find("hous", 1, true) then tagged = true end
    elseif type(tag) == "string" and string.lower(tag):find("hous", 1, true) then
      tagged = true
    end
  end
  return named or (weekly and tagged)
end

local function HousingQuestLog()
  local n = Safe(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or 0
  local out = {}
  if type(n) ~= "number" or n <= 0 or not (C_QuestLog and C_QuestLog.GetInfo) then
    return out
  end
  for i = 1, n do
    local info = Safe(C_QuestLog.GetInfo, i)
    if type(info) == "table" and info.questID and not info.isHeader and not info.isHidden then
      table.insert(out, info)
    end
  end
  return out
end

local function AttachDashboard(rec)
  rec.openLabel = "Dashboard"
  rec.open = function() LS:OpenHousingDashboard() end
  return rec
end

function LS:GetHousingRecommendations()
  local out = {}
  if not (self.db and self.db.goals and self.db.goals.HOUSING) then return out end
  if not self:HousingAPIsReady() then return out end

  local houses = Safe(C_Housing.GetPlayerOwnedHouses)
  local listed = type(houses) == "table"
  if listed and not self:PlayerOwnsHouse() and self.IsEndgameLevel and self:IsEndgameLevel() then
    table.insert(out, AttachDashboard({
      id = "housing_house",
      title = "Claim a house",
      why = "The client has no house on this character.",
      category = "Housing",
      tags = { HOUSING = 14 },
      urgency = "MEDIUM",
      priority = "MEDIUM PRIORITY",
      detail = {
        matters = "Housing stays off the plan until the client reports a house, or work still to do on one.",
      },
    }))
  end

  local initiative = Safe(C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetCurrentInitiative)
  if type(initiative) == "table"
      and not (initiative.isComplete or initiative.isFinished or initiative.complete) then
    local progress = Safe(C_NeighborhoodInitiative.GetInitiativeProgress)
    local contribution = Safe(C_NeighborhoodInitiative.GetPlayerContribution)
    local have = Num(contribution) or Num(progress) or Num(initiative)
    local cap = Cap(contribution) or Cap(progress) or Cap(initiative)
    if have and cap and cap > 0 and have < cap then
      local name = initiative.name or initiative.title
      table.insert(out, AttachDashboard({
        id = "housing_initiative",
        title = (type(name) == "string" and name ~= "" and name) or "Contribute to the neighborhood",
        why = string.format("%d / %d neighborhood contribution.", have, cap),
        category = "Housing",
        tags = { HOUSING = 12, ENDGAME = 4 },
        urgency = "HIGH",
        priority = "HIGH PRIORITY",
        detail = {
          current = tostring(have),
          potential = tostring(cap),
          matters = "Neighborhood initiatives reset. Leaving it on the table spends the week.",
        },
      }))
    end
  end

  for _, info in ipairs(HousingQuestLog()) do
    if self:IsHousingWeeklyQuest(info) then
      local title = info.title or "Housing weekly"
      local ready = info.readyForTurnIn or (C_QuestLog and C_QuestLog.IsComplete
        and Safe(C_QuestLog.IsComplete, info.questID))
      table.insert(out, AttachDashboard({
        id = "housing_quest_" .. tostring(info.questID),
        title = ready and ("Turn in: " .. title) or title,
        why = ready and "This housing weekly is ready to turn in."
          or "Weekly housing work already in your log.",
        category = "Housing",
        tags = { HOUSING = 12, ENDGAME = 4 },
        urgency = ready and "HIGH" or "HIGH",
        priority = "HIGH PRIORITY",
        detail = {
          matters = "Lodestar only ranks housing weeklies the client already put in the log.",
        },
      }))
    end
  end
  return out
end
