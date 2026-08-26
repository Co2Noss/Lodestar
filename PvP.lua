local _, LS = ...

-- PvP is a goal. Lodestar ranks weekly Conquest from the client, not an invented
-- queue. Honor and rated scores live on the dashboard tile.

LS.PVP_BRACKETS = {
  { key = "2s", label = "2v2", index = 1 },
  { key = "3s", label = "3v3", index = 2 },
  { key = "rbg", label = "RBG", index = 4 },
  { key = "shuffle", label = "Shuffle", index = 7 },
  { key = "blitz", label = "Blitz", index = 9 },
}

function LS:HonorLevel()
  if UnitHonorLevel then
    local n = tonumber(UnitHonorLevel("player"))
    if n then return n end
  end
  if GetHonorLevel then
    local n = tonumber(GetHonorLevel())
    if n then return n end
  end
  return 0
end

function LS:RatedPvPInfo(index)
  if not GetPersonalRatedInfo then return end
  local ok, rating, seasonBest, weeklyBest, seasonPlayed, seasonWon = pcall(GetPersonalRatedInfo, index)
  if not ok then return end
  rating = tonumber(rating) or 0
  seasonBest = tonumber(seasonBest) or rating
  return {
    rating = rating,
    seasonBest = seasonBest,
    weeklyBest = tonumber(weeklyBest) or 0,
    seasonPlayed = tonumber(seasonPlayed) or 0,
    seasonWon = tonumber(seasonWon) or 0,
  }
end

function LS:GetPvPRecommendations()
  local out = {}
  if not (self.db and self.db.goals and self.db.goals.PVP) then return out end
  if self.IsEndgameLevel and not self:IsEndgameLevel() then return out end
  if C_PvP and C_PvP.CanPlayerUseRatedPVPUI then
    local ok, can = pcall(C_PvP.CanPlayerUseRatedPVPUI)
    if ok and can == false then return out end
  end
  local progress = C_WeeklyRewards and C_WeeklyRewards.GetConquestWeeklyProgress
    and C_WeeklyRewards.GetConquestWeeklyProgress()
  local have = progress and tonumber(progress.progress)
  local cap = progress and tonumber(progress.maxProgress)
  if have and cap and cap > 0 and have < cap then
    table.insert(out, {
      id = "pvp_conquest",
      title = "Earn weekly Conquest",
      why = string.format("%d / %d Conquest this week.", have, cap),
      category = "PvP",
      tags = { PVP = 14, ENDGAME = 4 },
      urgency = "HIGH",
      priority = "HIGH PRIORITY",
      detail = {
        current = tostring(have),
        potential = tostring(cap),
        matters = "Conquest resets. Leaving it on the table spends the week.",
      },
    })
  end
  return out
end
