local _, LS = ...

-- Warband view: everything Lodestar has seen on every character on this account.
-- Data comes from the snapshot each character saves on login and on weekly reset.
-- Alts default to tracked. The logged-in character is always included in totals.

function LS:CharacterIsTracked(key)
  if not key then return true end
  if self.CharacterKey and key == self:CharacterKey() then return true end
  local snap = self.db and self.db.characters and self.db.characters[key]
  if snap and snap.tracked == false then return false end
  return true
end

function LS:SetCharacterTracked(key, on)
  if not key or not self.db or not self.db.characters or not self.db.characters[key] then
    return
  end
  if self.CharacterKey and key == self:CharacterKey() then return end
  if on then
    self.db.characters[key].tracked = nil
  else
    self.db.characters[key].tracked = false
  end
end

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
      tracked = self:CharacterIsTracked(key),
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
    if character.tracked then
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
  end
  return totals
end

function LS:ForgetCharacter(key)
  if self.db.characters then
    self.db.characters[key] = nil
  end
end

-- Live bags for the logged-in character, snapshots for the rest, plus the
-- warband bank when the client reports it. Lodestar does not invent an AH.
function LS:WarbandGold()
  local total, seen, countedMe = 0, 0, false
  local me = self.CharacterKey and self:CharacterKey() or ""
  local live = GetMoney and tonumber(GetMoney()) or 0
  if self.db and self.db.characters then
    for key, snap in pairs(self.db.characters) do
      if self:CharacterIsTracked(key) then
        local gold
        if key == me then
          gold = live
          countedMe = true
        else
          gold = snap and tonumber(snap.gold)
        end
        if gold then
          total = total + gold
          seen = seen + 1
        end
      end
    end
  end
  if not countedMe then
    total = total + live
    seen = seen + 1
  end
  local bankType = Enum and Enum.BankType and Enum.BankType.Account
  if C_Bank and C_Bank.FetchDepositedMoney then
    local ok, bank
    if bankType ~= nil then
      ok, bank = pcall(C_Bank.FetchDepositedMoney, bankType)
    else
      ok, bank = pcall(C_Bank.FetchDepositedMoney, 2)
    end
    if ok then total = total + (tonumber(bank) or 0) end
  end
  return total, seen
end
