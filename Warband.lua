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
function LS:WarbandGoldBreakdown()
  local rows, total, seen, countedMe = {}, 0, 0, false
  local me = self.CharacterKey and self:CharacterKey() or ""
  local live = GetMoney and tonumber(GetMoney()) or 0

  local function push(name, realm, gold, kind)
    if gold == nil then return end
    gold = tonumber(gold) or 0
    table.insert(rows, { name = name or "Unknown", realm = realm or "", gold = gold, kind = kind })
    total = total + gold
    if kind ~= "bank" then seen = seen + 1 end
  end

  for _, character in ipairs(self:GetWarband()) do
    if character.tracked then
      local gold
      if character.isCurrent or character.key == me then
        gold = live
        countedMe = true
      else
        local snap = self.db.characters and self.db.characters[character.key]
        gold = snap and tonumber(snap.gold)
      end
      if gold ~= nil then
        local kind = (character.isCurrent or character.key == me) and "live" or "snap"
        push(character.name, character.realm, gold, kind)
      end
    end
  end
  if not countedMe then
    push(UnitName and UnitName("player") or "You", GetRealmName and GetRealmName() or "", live, "live")
  end

  local bankType = Enum and Enum.BankType and Enum.BankType.Account
  if C_Bank and C_Bank.FetchDepositedMoney then
    local ok, bank
    if bankType ~= nil then
      ok, bank = pcall(C_Bank.FetchDepositedMoney, bankType)
    else
      ok, bank = pcall(C_Bank.FetchDepositedMoney, 2)
    end
    if ok then bank = tonumber(bank) or 0 end
    if (bank or 0) > 0 then
      push("Warband bank", "", bank, "bank")
    end
  end
  return rows, total, seen
end

function LS:WarbandGold()
  local _, total, seen = self:WarbandGoldBreakdown()
  return total, seen
end

function LS:GoldRowLabel(row)
  if not row then return "Unknown" end
  if row.kind == "bank" then return "Warband bank" end
  local name = row.name or "Unknown"
  local realm = row.realm or ""
  local mine = GetRealmName and GetRealmName() or ""
  if realm ~= "" and realm ~= mine then
    return name .. "-" .. realm
  end
  return name
end

function LS:FillGoldTooltip(tip)
  if not tip then return end
  if tip.ClearLines then tip:ClearLines() end
  if tip.SetText then tip:SetText("Gold") end
  local rows = self:WarbandGoldBreakdown()
  if not tip.AddLine then return end
  if #rows == 0 then
    tip:AddLine("No gold recorded yet.")
    return
  end
  for _, row in ipairs(rows) do
    local amount = self:FormatTokenMoney(row.gold, { format = "letters", separators = true, color = false })
    tip:AddLine(self:GoldRowLabel(row) .. "  " .. amount)
  end
end
