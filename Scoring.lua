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
    if not activity.requiresProfession or #(self.profile.professions or {}) > 0 then
      consider(activity)
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

  table.sort(out, function(a, b)
    if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
    return a.title < b.title
  end)
  return out
end

-- Recommendations grouped for the Today tabs. Tab order is stable so the strip does not
-- jump around as scores change; the work inside each tab is still ranked best first.
local CATEGORY_ORDER = {
  ["Great Vault"] = 1,
  ["Professions"] = 2,
  ["Reputation"] = 3,
  ["Solo content"] = 4,
  ["Questing"] = 5,
}

function LS:GetCategories()
  local list = self:GetRecommendations()
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

  table.sort(groups, function(a, b)
    local ia = CATEGORY_ORDER[a.name] or 50
    local ib = CATEGORY_ORDER[b.name] or 50
    if ia ~= ib then return ia < ib end
    return a.name < b.name
  end)
  return groups, #list
end
