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
    detail = {
      nextReward = "Reputation and currency",
      matters = "Only worth it while you still need the factions you chose.",
    },
  },
}

function LS:FindActivity(id)
  for _, activity in ipairs(self.activities) do
    if activity.id == id then return activity end
  end
  for _, list in ipairs({
    self:GetVaultRecommendations(),
    self:GetProfessionRecommendations(),
    self.GetMountRecommendations and self:GetMountRecommendations() or {},
    self.GetReputationRecommendations and self:GetReputationRecommendations() or {},
    self.GetGoldRecommendations and self:GetGoldRecommendations() or {},
  }) do
    for _, activity in ipairs(list) do
      if activity.id == id then return activity end
    end
  end
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
