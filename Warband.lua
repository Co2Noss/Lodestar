local _, LS = ...

-- Warband view: everything Lodestar has seen on every character on this account.
-- Data comes from the snapshot each character saves on login and on weekly reset.
function LS:GetWarband()
  local list = {}
  for key, snapshot in pairs(self.db.characters or {}) do
    local entry = {
      key = key,
      name = snapshot.name or key,
      realm = snapshot.realm or "",
      level = snapshot.level or 0,
      class = snapshot.class or "",
      spec = snapshot.spec or "",
      lastSeen = snapshot.lastSeen or 0,
      vault = snapshot.vault or {},
      knowledge = snapshot.knowledge or {},
      renown = snapshot.renown or {},
      mounts = snapshot.mounts or 0,
      isCurrent = key == self:CharacterKey(),
    }
    table.insert(list, entry)
  end
  table.sort(list, function(a, b)
    if a.isCurrent ~= b.isCurrent then return a.isCurrent end
    if a.level ~= b.level then return a.level > b.level end
    return a.name < b.name
  end)
  return list
end

function LS:GetWarbandTotals()
  local totals = {
    characters = 0,
    vaultsWithSlots = 0,
    vaultUpgrades = 0,
    unspentKnowledge = 0,
    weeklyKnowledge = 0,
    weeklyKnowledgePoints = 0,
    renownTargets = 0,
  }
  for _, character in ipairs(self:GetWarband()) do
    totals.characters = totals.characters + 1
    local vault = character.vault or {}
    if (vault.filled or 0) > 0 then
      totals.vaultsWithSlots = totals.vaultsWithSlots + 1
    end
    totals.vaultUpgrades = totals.vaultUpgrades + (vault.upgradable or 0)
    local knowledge = character.knowledge or {}
    totals.unspentKnowledge = totals.unspentKnowledge + (knowledge.unspent or 0)
    totals.weeklyKnowledge = totals.weeklyKnowledge + (knowledge.weekly or 0)
    totals.weeklyKnowledgePoints = totals.weeklyKnowledgePoints + (knowledge.weeklyPoints or 0)
    totals.renownTargets = totals.renownTargets + #(character.renown or {})
  end
  return totals
end

function LS:ForgetCharacter(key)
  if self.db.characters then
    self.db.characters[key] = nil
  end
end
