local _, LS = ...

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

local function GroupKey(expansion, group)
  if not group or group == "" then return nil end
  return (expansion or "") .. "\t" .. group
end

local function StandingLabel(reaction)
  local name = _G["FACTION_STANDING_LABEL" .. tostring(reaction or 0)]
  if type(name) == "string" and name ~= "" then return name end
  return "Standing"
end

function LS:RepExpansionTabs()
  local tabs, seen = {}, {}
  for _, row in ipairs((self.profile and self.profile.repRows) or {}) do
    local name = row.kind == "expansion" and row.name or row.expansion
    if name and not seen[name] then
      seen[name] = true
      table.insert(tabs, { name, name })
    end
  end
  return tabs
end

function LS:HasRepSelection()
  local db = self.db
  if not db then return false end
  for _, on in pairs(db.repExpansions or {}) do
    if on then return true end
  end
  for _, on in pairs(db.repGroups or {}) do
    if on then return true end
  end
  for _, on in pairs(db.repFactions or {}) do
    if on == true then return true end
  end
  return false
end

function LS:CaresAboutRep(faction)
  if not faction or not self.db then return false end
  local id = faction.factionID
  local explicit = id and self.db.repFactions and self.db.repFactions[id]
  if explicit == true then return true end
  if explicit == false then return false end
  local groupKey = GroupKey(faction.expansion, faction.group)
  if groupKey then
    local group = self.db.repGroups and self.db.repGroups[groupKey]
    if group == true then return true end
    if group == false then return false end
  end
  return (self.db.repExpansions and self.db.repExpansions[faction.expansion]) == true
end

function LS:SetRepExpansion(name, on)
  self.db.repExpansions = self.db.repExpansions or {}
  self.db.repExpansions[name] = on and true or nil
end

function LS:SetRepGroup(expansion, group, on)
  local key = GroupKey(expansion, group)
  if not key then return end
  self.db.repGroups = self.db.repGroups or {}
  self.db.repGroups[key] = on and true or false
end

function LS:SetRepFaction(factionID, on)
  if not factionID then return end
  self.db.repFactions = self.db.repFactions or {}
  self.db.repFactions[factionID] = on and true or false
end

function LS:RepGroupOn(expansion, group)
  local key = GroupKey(expansion, group)
  if not key then return (self.db.repExpansions and self.db.repExpansions[expansion]) == true end
  local groupOn = self.db.repGroups and self.db.repGroups[key]
  if groupOn == true then return true end
  if groupOn == false then return false end
  return (self.db.repExpansions and self.db.repExpansions[expansion]) == true
end

local function AtMax(faction)
  if faction.paragonPending then return false end
  if faction.isMajor and faction.maxedRenown then return true end
  if faction.isCapped then return true end
  if (faction.reaction or 0) >= 8 then return true end
  return false
end

function LS:ScanReputations()
  local rows, byID = {}, {}
  if C_Reputation and C_Reputation.ExpandAllFactionHeaders then
    pcall(C_Reputation.ExpandAllFactionHeaders)
  elseif ExpandAllFactionHeaders then
    pcall(ExpandAllFactionHeaders)
  end

  local n = Safe(C_Reputation and C_Reputation.GetNumFactions) or 0
  local expansion, group = "Other", nil
  for i = 1, n do
    local info = Safe(C_Reputation.GetFactionDataByIndex, i)
    if type(info) == "table" and info.name then
      if info.isHeader and not info.isChild then
        expansion = info.name
        group = nil
        table.insert(rows, { kind = "expansion", name = expansion })
      elseif info.isHeader then
        group = info.name
        table.insert(rows, {
          kind = "group",
          name = group,
          expansion = expansion,
        })
      else
        local lo = info.currentReactionThreshold or 0
        local hi = info.nextReactionThreshold or lo
        local faction = {
          kind = "faction",
          name = info.name,
          factionID = info.factionID,
          expansion = expansion,
          group = group,
          reaction = info.reaction or 0,
          progress = math.max(0, (info.currentStanding or lo) - lo),
          total = math.max(0, hi - lo),
          isCapped = info.isCapped == true,
          isAccountWide = info.isAccountWide == true,
        }
        table.insert(rows, faction)
        if info.factionID then byID[info.factionID] = faction end
      end
    end
  end

  local majors = {}
  for _, major in ipairs((self.profile and self.profile.majorFactions) or {}) do
    majors[major.factionID] = major
    local row = byID[major.factionID]
    if row then
      row.isMajor = true
      row.renown = major.renown
      row.maxedRenown = major.unlocked == false
        or (C_MajorFactions and C_MajorFactions.HasMaximumRenown
            and C_MajorFactions.HasMaximumRenown(major.factionID))
      row.progress = major.progress or row.progress
      row.total = major.total or row.total
    else
      local faction = {
        kind = "faction",
        name = major.name,
        factionID = major.factionID,
        expansion = "Renown",
        group = nil,
        isMajor = true,
        renown = major.renown,
        maxedRenown = major.unlocked == false,
        progress = major.progress or 0,
        total = major.total or 0,
        reaction = 0,
      }
      table.insert(rows, faction)
      byID[major.factionID] = faction
    end
  end

  if C_Reputation and C_Reputation.IsFactionParagon then
    for _, row in ipairs(rows) do
      if row.kind == "faction" and row.factionID and C_Reputation.IsFactionParagon(row.factionID) then
        row.paragon = true
        if C_Reputation.GetFactionParagonInfo then
          local ok, _, _, _, pending = pcall(C_Reputation.GetFactionParagonInfo, row.factionID)
          row.paragonPending = ok and pending == true
        end
      end
    end
  end

  if C_Reputation and C_Reputation.IsMajorFaction then
    for _, row in ipairs(rows) do
      if row.kind == "faction" and row.factionID and C_Reputation.IsMajorFaction(row.factionID) then
        row.isMajor = true
      end
    end
  end

  local map = {}
  for _, row in ipairs(rows) do
    if row.kind == "faction" then
      map[row.name] = row
    end
  end

  if self.profile then
    self.profile.repRows = rows
    self.profile.reputations = map
  end
end

function LS:GetReputationRecommendations()
  local out = {}
  if self.ScanReputations then self:ScanReputations() end
  local rows = self.profile and self.profile.repRows or {}
  for _, faction in ipairs(rows) do
    if faction.kind == "faction" and self:CaresAboutRep(faction) and not AtMax(faction) then
      local section = faction.expansion or "Reputation"
      if faction.group then
        section = section .. " — " .. faction.group
      end
      local standing = faction.isMajor
        and string.format("Renown %d", faction.renown or 0)
        or StandingLabel(faction.reaction)
      local why
      local score, urgency, priority, minutes
      if faction.paragonPending then
        why = string.format("%s has a paragon chest waiting.", faction.name)
        score, urgency, priority, minutes = 30, "HIGH", "FREE VALUE", 5
      elseif faction.isMajor then
        why = string.format("%s is Renown %d. Renown never expires, so this waits.",
          faction.name, faction.renown or 0)
        score = 22 + math.min(8, faction.renown or 0)
        urgency, priority, minutes = "LOW", "OPEN", 20
      else
        why = string.format("%s is %s. You asked Lodestar to rank %s.",
          faction.name, standing, faction.group or faction.expansion or "this reputation")
        score = 16 + (faction.reaction or 0)
        urgency, priority, minutes = "LOW", "OPEN", 25
      end
      table.insert(out, {
        id = "rep_" .. tostring(faction.factionID or faction.name),
        title = string.format("Raise %s", faction.name),
        minutes = minutes,
        score = score,
        why = why,
        category = "Reputation",
        section = section,
        tags = { REPUTATION = 12 },
        urgency = urgency,
        priority = priority,
        faction = faction.name,
        detail = {
          source = section,
          current = standing .. ((faction.total or 0) > 0
            and string.format("  %d/%d", faction.progress or 0, faction.total) or ""),
          potential = faction.isMajor and "Higher renown" or "Higher standing",
          matters = why,
        },
      })
    end
  end
  return out
end
