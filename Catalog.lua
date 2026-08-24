local _, LS = ...

-- Tagged content. Scoring reads the tags, the Today page groups by category, and the
-- details page reads everything else.
LS.activities = {
  {
    id = "zuljarra",
    title = "Build Zul'jarra's Forces Renown",
    minutes = 30,
    category = "Reputation",
    -- Renown never expires, so it is never the thing you have to do tonight.
    urgency = "ANYTIME",
    tags = { CRAFTING = 8, MOUNTS = 6, REPUTATION = 10 },
    why = "Current-tier renown rewards feed professions and collections.",
    faction = "Zul'jarra's Forces",
    detail = {
      nextReward = "Profession recipes",
      rewards = { recipes = 5, mounts = 2, transmog = 7 },
      matters = "Matches your crafting and collection goals.",
    },
  },
  {
    id = "delve",
    title = "Complete a Bountiful Delve",
    minutes = 25,
    category = "Solo content",
    -- Feeds the World Vault, which resets.
    urgency = "THIS WEEK",
    tags = { SOLO = 10, ENDGAME = 6 },
    why = "Compact solo run that also raises your World Vault tier.",
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
    urgency = "THIS WEEK",
    tags = { QUESTING = 8, REPUTATION = 6 },
    why = "Bulk reputation and currency without a group.",
    detail = {
      nextReward = "Reputation and currency",
      matters = "Only worth it while you still need renown.",
    },
  },
}

function LS:FindActivity(id)
  for _, activity in ipairs(self.activities) do
    if activity.id == id then return activity end
  end
  for _, list in ipairs({ self:GetVaultRecommendations(), self:GetProfessionRecommendations() }) do
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
