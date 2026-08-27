local _, LS = ...

-- Tagged content. Scoring reads the tags, the Today page groups by category, and the
-- details page reads everything else.
LS.activities = {
  {
    id = "delve",
    title = "Complete a Bountiful Delve",
    minutes = 25,
    category = "Solo content",
    -- Feeds the World Vault, which resets.
    urgency = "MEDIUM",
    tags = { SOLO = 10, ENDGAME = 6 },
    why = "Compact solo run that also raises your World Vault tier.",
    skipIf = function()
      if LS.GetBountifulDelveRecommendations then return true end
      return LS.BountifulDelveWorthDoing and not LS:BountifulDelveWorthDoing()
    end,
    detail = {
      nextReward = "World Vault progress",
      matters = "Cheapest way to fill or upgrade a World Vault slot.",
    },
  },
  {
    id = "worldquests",
    title = "Clear a zone of World Quests",
    minutes = 20,
    category = "Questing",
    urgency = "MEDIUM",
    tags = { QUESTING = 8 },
    why = "Bulk reputation and currency without a group.",
    skipIf = function()
      return LS.GetQuestRecommendations ~= nil
    end,
    detail = {
      nextReward = "Reputation and currency",
      matters = "Only worth it while you still need the factions you chose.",
    },
  },
}

local VAULT_ROW = { raid = "Raid", activities = "Dungeons", world = "World" }

-- vault_world_1_up / vault_raid_2_fill. Lua patterns have no |, so each suffix is its own match.
local function ParseVaultSlot(id)
  id = id or ""
  local kind, index = id:match("^vault_(%a+)_(%d+)_up$")
  if kind then return kind, index, "up" end
  kind, index = id:match("^vault_(%a+)_(%d+)_fill$")
  if kind then return kind, index, "fill" end
end

-- Compact and Progress must never print a raw id. These labels come from Lodestar's
-- own vault id scheme, not from invented slot names.
function LS:ActivityLabel(id)
  id = id or ""
  if id:sub(1, 12) == "vault_claim_" then
    return "Claim last week's Great Vault"
  end
  local kind, index, mode = ParseVaultSlot(id)
  local row = kind and VAULT_ROW[kind]
  if row then
    local verb = mode == "up" and "Upgrade" or "Fill"
    return string.format("%s %s Vault slot %s", verb, row, index)
  end
  return "That activity"
end

function LS:FindActivity(id)
  if not id then return end
  for _, activity in ipairs(self.activities) do
    if activity.id == id then
      local skip = false
      if activity.skipIf then
        local ok, hide = pcall(activity.skipIf)
        skip = ok and hide
      end
      if not skip then return activity end
    end
  end
  local lists = {
    self:GetVaultRecommendations(),
    self:GetProfessionRecommendations(),
    self.GetMountRecommendations and self:GetMountRecommendations() or {},
    self.GetReputationRecommendations and self:GetReputationRecommendations() or {},
    self.GetGoldRecommendations and self:GetGoldRecommendations() or {},
    self.GetHandyNotesRecommendations and self:GetHandyNotesRecommendations() or {},
    self.GetBountifulDelveRecommendations and self:GetBountifulDelveRecommendations() or {},
    self.GetPreyRecommendations and self:GetPreyRecommendations() or {},
    self.GetQuestRecommendations and self:GetQuestRecommendations() or {},
    self.GetPvPRecommendations and self:GetPvPRecommendations() or {},
    self.GetHousingRecommendations and self:GetHousingRecommendations() or {},
    self.GetPetRecommendations and self:GetPetRecommendations() or {},
  }
  local function search(want)
    for _, list in ipairs(lists) do
      for _, activity in ipairs(list) do
        if activity.id == want then return activity end
      end
    end
  end
  local found = search(id)
  if found then return found end
  -- The suffix flips when a slot fills or the week resets. Keep the tracked id so
  -- Untrack still matches, but show this week's live card.
  local kind, index, mode = ParseVaultSlot(id)
  if not kind then return end
  local sibling = string.format("vault_%s_%s_%s", kind, index, mode == "up" and "fill" or "up")
  found = search(sibling)
  if not found then return end
  local copy = {}
  for k, v in pairs(found) do copy[k] = v end
  copy.id = id
  return copy
end

-- Live renown for a catalog activity, when the faction is one the client knows about.
function LS:FactionProgress(name)
  if not name then return nil end
  for _, faction in ipairs(self.profile.majorFactions or {}) do
    if faction.name == name then
      return {
        rank = faction.renown,
        progress = faction.progress,
        total = faction.total,
      }
    end
  end
  local rep = self.profile.reputations and self.profile.reputations[name]
  if rep then
    return { progress = rep.progress, total = rep.total }
  end
end
