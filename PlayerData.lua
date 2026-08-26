local _, LS = ...
LS.profile = {
  professions = {},
  reputations = {},
  majorFactions = {},
  mounts = {},
  transmog = {},
  level = 0,
  class = "",
  spec = "",
  vault = {},
}

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end

function LS:CharacterKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

-- Midnight's cap is 90. The client reports the live cap when it can.
function LS:EndgameLevel()
  local cap = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
  cap = tonumber(cap)
  if cap and cap > 1 then return cap end
  return 90
end

function LS:PlayerLevel()
  local n = self.profile and tonumber(self.profile.level)
  if n and n > 0 then return n end
  return tonumber(UnitLevel and UnitLevel("player")) or 0
end

function LS:IsEndgameLevel()
  local level = self:PlayerLevel()
  return level > 0 and level >= self:EndgameLevel()
end

function LS:GetLevelingRecommendations()
  local level = self:PlayerLevel()
  local cap = self:EndgameLevel()
  if level <= 0 or level >= cap then return {} end
  local why = "Great Vault waits until then. Play what you enjoy."
  if self.db and self.db.goals and self.db.goals.CRAFTING then
    why = "Great Vault waits until then. Play what you enjoy, and keep professions moving while you level."
  else
    why = why .. " Train professions along the way if you want them."
  end
  return {
    {
      id = "level_cap",
      title = string.format("Level to %d", cap),
      why = why,
      category = "Questing",
      tags = { ENDGAME = 16, QUESTING = 8, SOLO = 4 },
      urgency = "HIGH",
      priority = "HIGH PRIORITY",
      detail = {
        current = string.format("Level %d", level),
        potential = string.format("Level %d", cap),
        matters = "Endgame rewards are gated on the cap. Until then the best use of time is leveling and whatever else you picked.",
      },
    },
  }
end

function LS:ScanPlayer()
  local p = self.profile
  p.level = UnitLevel("player") or 0
  p.class = select(2, UnitClass("player")) or ""
  p.classFile = p.class
  local specIndex = GetSpecialization and GetSpecialization()
  p.spec = specIndex and select(2, GetSpecializationInfo(specIndex)) or ""

  local professions, seen = {}, {}
  local ids = Safe(C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines)
  if type(ids) == "table" then
    for _, id in ipairs(ids) do
      local info = Safe(C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
      if info and info.isPrimaryProfession and info.professionName and not seen[info.professionName] then
        seen[info.professionName] = true
        table.insert(professions, {
          name = info.professionName,
          skill = info.skillLevel or 0,
          max = info.maxSkillLevel or 0,
        })
      end
    end
  end
  p.professions = professions

  local reps = {}
  local n = Safe(C_Reputation and C_Reputation.GetNumFactions) or 0
  for i = 1, n do
    local info = Safe(C_Reputation.GetFactionDataByIndex, i)
    if info and not info.isHeader and info.name then
      local lo = info.currentReactionThreshold or 0
      local hi = info.nextReactionThreshold or lo
      reps[info.name] = {
        name = info.name,
        factionID = info.factionID,
        progress = math.max(0, (info.currentStanding or lo) - lo),
        total = math.max(0, hi - lo),
      }
    end
  end
  p.reputations = reps

  local majors = {}
  local majorIDs = Safe(C_MajorFactions and C_MajorFactions.GetMajorFactionIDs)
  if type(majorIDs) == "table" then
    for _, factionID in ipairs(majorIDs) do
      local data = Safe(C_MajorFactions.GetMajorFactionData, factionID)
      if data and data.name then
        table.insert(majors, {
          factionID = factionID,
          name = data.name,
          renown = data.renownLevel or 0,
          maxRenown = data.renownLevelThreshold and data.renownLevel or nil,
          progress = data.renownReputationEarned or 0,
          total = data.renownLevelThreshold or 0,
          unlocked = Safe(C_MajorFactions.HasMaximumRenown, factionID) ~= true,
        })
      end
    end
  end
  table.sort(majors, function(a, b) return a.name < b.name end)
  p.majorFactions = majors

  local total, collected = Safe(C_MountJournal and C_MountJournal.GetNumMounts)
  p.mounts = { total = total or 0, collected = collected or 0 }

  local transmogCollected = Safe(C_TransmogCollection and C_TransmogCollection.GetNumTransmogSources)
  p.transmog = { collected = transmogCollected or 0 }
end

function LS:SaveSnapshot()
  if not self.db then return end
  self.db.characters = self.db.characters or {}
  local p = self.profile
  local filled, totalSlots, upgradable = self:VaultSummary()
  local unspent, weeklyLeft, treasureLeft, catchUpReady, weeklyPoints = 0, 0, 0, 0, 0
  if self.ProfessionSummary then
    unspent, weeklyLeft, treasureLeft, catchUpReady, weeklyPoints = self:ProfessionSummary()
  end

  local renown = {}
  for _, faction in ipairs(p.majorFactions or {}) do
    table.insert(renown, { name = faction.name, renown = faction.renown })
  end

  local key = self:CharacterKey()
  local prev = self.db.characters[key]
  self.db.characters[key] = {
    name = UnitName("player"),
    realm = GetRealmName(),
    level = p.level,
    class = p.class,
    spec = p.spec,
    lastSeen = time(),
    gold = GetMoney and tonumber(GetMoney()) or 0,
    mounts = p.mounts and p.mounts.collected or 0,
    vault = { filled = filled, total = totalSlots, upgradable = upgradable },
    knowledge = {
      unspent = unspent,
      weekly = weeklyLeft,
      weeklyPoints = weeklyPoints,
      treasures = treasureLeft,
      catchUpReady = catchUpReady,
    },
    renown = renown,
    tracked = prev and prev.tracked,
  }
end
