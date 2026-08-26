local _, LS = ...

function LS:GetRecommendations()
  local out = {}

  local function consider(activity, baseScore)
    if self.db.dismissed[activity.id] or self.db.completed[activity.id] then return end
    local score = baseScore or 0
    for goal, on in pairs(self.db.goals) do
      if on then
        score = score + (activity.tags and activity.tags[goal] or 0)
      end
    end
    if score <= 0 then return end
    if self.db.tracked[activity.id] then
      score = score + 25
    end
    activity.score = score
    table.insert(out, activity)
  end

  for _, activity in ipairs(self.activities or {}) do
    local skip = false
    if activity.skipIf then
      local ok, hide = pcall(activity.skipIf)
      skip = ok and hide
    end
    if not skip and (not activity.requiresProfession or #(self.profile.professions or {}) > 0) then
      consider(activity)
    end
  end

  if self.GetLevelingRecommendations then
    for _, leveling in ipairs(self:GetLevelingRecommendations()) do
      consider(leveling)
    end
  end

  if self.db.goals.ENDGAME then
    for _, vault in ipairs(self:GetVaultRecommendations()) do
      consider(vault, vault.score)
    end
  end

  if self.db.goals.CRAFTING then
    for _, profession in ipairs(self:GetProfessionRecommendations()) do
      consider(profession, profession.score)
    end
  end

  if self.db.goals.MOUNTS and self.GetMountRecommendations then
    for _, mount in ipairs(self:GetMountRecommendations()) do
      consider(mount, mount.score)
    end
  end

  if self.db.goals.REPUTATION and self.GetReputationRecommendations then
    for _, rep in ipairs(self:GetReputationRecommendations()) do
      consider(rep, rep.score)
    end
  end

  if self.db.goals.GOLD and self.GetGoldRecommendations then
    for _, gold in ipairs(self:GetGoldRecommendations()) do
      consider(gold, gold.score)
    end
  end

  if self.db.goals.PVP and self.GetPvPRecommendations then
    for _, pvp in ipairs(self:GetPvPRecommendations()) do
      consider(pvp, pvp.score)
    end
  end

  if self.db.goals.HOUSING and self.GetHousingRecommendations then
    for _, house in ipairs(self:GetHousingRecommendations()) do
      consider(house, house.score)
    end
  end

  if self.db.goals.SOLO and self.GetHandyNotesRecommendations then
    for _, rare in ipairs(self:GetHandyNotesRecommendations()) do
      consider(rare, rare.score)
    end
  end

  if self.GetBountifulDelveRecommendations then
    for _, delve in ipairs(self:GetBountifulDelveRecommendations()) do
      consider(delve)
    end
  end

  if self.GetPreyRecommendations then
    for _, hunt in ipairs(self:GetPreyRecommendations()) do
      consider(hunt)
    end
  end

  if self.GetQuestRecommendations then
    for _, quest in ipairs(self:GetQuestRecommendations()) do
      consider(quest)
    end
  end

  table.sort(out, function(a, b)
    if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
    return a.title < b.title
  end)
  return out
end

-- Compact mode and Progress both read this list: tracked cards that are still on
-- the plan, then any tracked id that is no longer being generated.
function LS:TrackedActivities()
  local out, have = {}, {}
  for _, activity in ipairs(self:GetRecommendations()) do
    if self.db.tracked[activity.id] then
      have[activity.id] = true
      table.insert(out, activity)
    end
  end
  for id, on in pairs(self.db.tracked or {}) do
    if on and not have[id] and not self.db.dismissed[id] and not self.db.completed[id] then
      local activity = self:FindActivity(id)
      table.insert(out, activity or {
        id = id,
        title = self:ActivityLabel(id),
        why = "That activity is no longer being generated.",
        score = 0,
      })
    end
  end
  table.sort(out, function(a, b)
    if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
    return (a.title or a.id or "") < (b.title or b.id or "")
  end)
  return out
end

-- Recommendations grouped for the Today tabs. Tab order is stable so the strip does not
-- jump around as scores change; the work inside each tab is still ranked best first.
local CATEGORY_ORDER = {
  ["Great Vault"] = 1,
  ["Professions"] = 2,
  ["Mounts"] = 3,
  ["Reputation"] = 4,
  ["Gold"] = 5,
  ["Solo content"] = 6,
  ["Questing"] = 7,
  ["PvP"] = 8,
  ["Housing"] = 9,
}

-- Weekly work disappears at reset. Long-term work waits. Everything else is for today.
function LS:ActivityHorizon(activity)
  local id = (activity and activity.id) or ""
  local cat = (activity and activity.category) or ""
  if cat == "Great Vault" or cat == "PvP" or id == "delve" or id == "prey"
      or id == "pvp_conquest" or id == "housing_initiative"
      or id:sub(1, 14) == "housing_quest_" or id:sub(1, 6) == "vault_" then
    return "WEEKLY"
  end
  if id:sub(1, 10) == "kp_weekly_" or id:sub(1, 10) == "kp_gather_" then
    return "WEEKLY"
  end
  if cat == "Mounts" or cat == "Reputation" or cat == "Gold" or cat == "Housing" then
    return "LONG"
  end
  if id:sub(1, 12) == "kp_treasure_" or id:sub(1, 11) == "kp_catchup_"
      or id:sub(1, 11) == "prof_level_" then
    return "LONG"
  end
  return "TODAY"
end

function LS:GetCategories(horizon)
  local list = self:GetRecommendations()
  if horizon then
    local filtered = {}
    for _, activity in ipairs(list) do
      if self:ActivityHorizon(activity) == horizon then
        table.insert(filtered, activity)
      end
    end
    list = filtered
  end
  local groups, index = {}, {}

  for _, activity in ipairs(list) do
    local name = activity.category or "Other"
    local group = index[name]
    if not group then
      group = { name = name, activities = {}, minutes = 0, best = 0 }
      index[name] = group
      table.insert(groups, group)
    end
    table.insert(group.activities, activity)
    group.minutes = group.minutes + (activity.minutes or 0)
    group.best = math.max(group.best, activity.score or 0)
  end

  for _, group in ipairs(groups) do
    if group.name == "Reputation" then
      table.sort(group.activities, function(a, b)
        if (a.section or "") ~= (b.section or "") then
          return (a.section or "") < (b.section or "")
        end
        if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
        return (a.title or "") < (b.title or "")
      end)
    end
  end

  table.sort(groups, function(a, b)
    local ia = CATEGORY_ORDER[a.name] or 50
    local ib = CATEGORY_ORDER[b.name] or 50
    if ia ~= ib then return ia < ib end
    return a.name < b.name
  end)
  return groups, #list
end
