local _, LS = ...

-- Battle Pets is a goal. Lodestar ranks locked slots, an empty team, and pet
-- battle quests already in the log. It does not invent species IDs, trainers,
-- or a catching circuit. The dashboard tile reads C_PetJournal.

local MAX_QUESTS = 4

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if ok then return a, b, c, d, e end
end

function LS:PetJournalReady()
  return C_PetJournal and (C_PetJournal.GetOwnedPetIDs or C_PetJournal.GetPetLoadOutInfo
    or C_PetJournal.GetNumPets) and true
end

local function PetInfo(guid)
  if not guid or not (C_PetJournal and C_PetJournal.GetPetInfoByPetID) then return end
  local ok, speciesID, customName, level, _, _, _, _, name, icon = pcall(C_PetJournal.GetPetInfoByPetID, guid)
  if not ok or (not speciesID and not name) then return end
  return {
    guid = guid,
    speciesID = speciesID,
    name = (customName and customName ~= "" and customName) or name,
    speciesName = name,
    icon = icon,
    level = tonumber(level),
  }
end

local function OwnedGuids()
  local out = {}
  local ids = Safe(C_PetJournal and C_PetJournal.GetOwnedPetIDs)
  if type(ids) == "table" then
    for k, v in pairs(ids) do
      local guid = type(v) == "string" and v or (type(k) == "string" and k)
      if guid then table.insert(out, guid) end
    end
    return out
  end
  local n = select(2, Safe(C_PetJournal and C_PetJournal.GetNumPets))
  n = tonumber(n) or 0
  for i = 1, n do
    local a = Safe(C_PetJournal and C_PetJournal.GetPetInfoByIndex, i)
    if type(a) == "string" then table.insert(out, a) end
  end
  return out
end

function LS:BattlePetProgress()
  if not self:PetJournalReady() then return end
  local guids = OwnedGuids()
  local species, pets = {}, {}
  for _, guid in ipairs(guids) do
    local info = PetInfo(guid)
    if info then
      table.insert(pets, info)
      if info.speciesID then species[info.speciesID] = true end
    end
  end
  local unique = 0
  for _ in pairs(species) do unique = unique + 1 end
  local summoned = Safe(C_PetJournal and C_PetJournal.GetSummonedPetGUID)
  local team = {}
  for slot = 1, 3 do
    local guid, _, _, _, locked = Safe(C_PetJournal and C_PetJournal.GetPetLoadOutInfo, slot)
    local pet = guid and PetInfo(guid)
    team[slot] = {
      slot = slot,
      guid = guid,
      locked = locked and true or false,
      name = pet and pet.name,
      icon = pet and pet.icon,
      level = pet and pet.level,
      summoned = summoned and guid == summoned or false,
    }
  end
  return {
    unique = unique,
    owned = #pets,
    summoned = summoned and PetInfo(summoned) or nil,
    team = team,
  }
end

function LS:OpenPetJournal()
  local tab = COLLECTIONS_JOURNAL_TAB_INDEX_PETS or 2
  local frame = _G.CollectionsJournal
  if self.ClientFrameShown and self:ClientFrameShown(frame) then
    local current = frame and frame.selectedTab
    if CollectionsJournal_GetTab then
      current = Safe(CollectionsJournal_GetTab, frame) or current
    end
    if not current or current == tab then
      self:HideClientFrame(frame)
      return true
    end
  end
  if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
  elseif LoadAddOn then
    pcall(LoadAddOn, "Blizzard_Collections")
  end
  frame = _G.CollectionsJournal
  if ToggleCollectionsJournal then
    pcall(ToggleCollectionsJournal, tab)
    if self.FrontClientFrame then self:FrontClientFrame(frame or _G.CollectionsJournal) end
    return true
  end
  if frame then
    if ShowUIPanel then
      pcall(ShowUIPanel, frame)
    elseif frame.Show then
      frame:Show()
    end
    if CollectionsJournal_SetTab then
      pcall(CollectionsJournal_SetTab, frame, tab)
    end
    if self.FrontClientFrame then self:FrontClientFrame(frame) end
    return true
  end
  return false
end

function LS:SummonBattlePet(guid)
  if not guid or not (C_PetJournal and C_PetJournal.SummonPetByGUID) then return false end
  -- Call from the click. Do not wrap in pcall.
  C_PetJournal.SummonPetByGUID(guid)
  return true
end

function LS:IsPetBattleQuest(info)
  if type(info) ~= "table" or not info.questID then return false end
  if info.isPetBattle then return true end
  local tagged = info.tagName or info.questTagType
  if type(tagged) == "string" then
    local lower = tagged:lower()
    if lower:find("pet battle", 1, true) or lower == "petbattle" then return true end
  end
  local tag = Safe(C_QuestLog and C_QuestLog.GetQuestTagInfo, info.questID)
  local petType = Enum and Enum.QuestTagType and Enum.QuestTagType.PetBattle
  if type(tag) == "table" then
    if petType and (tag.tagID == petType or tag.worldQuestType == petType
        or tag.questTagType == petType) then
      return true
    end
    local name = string.lower(tostring(tag.tagName or tag.name or ""))
    if name:find("pet battle", 1, true) or name == "petbattle" then return true end
  elseif type(tag) == "string" then
    local name = tag:lower()
    if name:find("pet battle", 1, true) then return true end
  end
  return false
end

local function QuestLog()
  local n = Safe(C_QuestLog and C_QuestLog.GetNumQuestLogEntries) or 0
  local out = {}
  if type(n) ~= "number" or n <= 0 or not (C_QuestLog and C_QuestLog.GetInfo) then
    return out
  end
  for i = 1, n do
    local info = Safe(C_QuestLog.GetInfo, i)
    if type(info) == "table" and info.questID and not info.isHeader and not info.isHidden then
      table.insert(out, info)
    end
  end
  return out
end

local function AttachJournal(rec)
  rec.openLabel = "Journal"
  rec.open = function() LS:OpenPetJournal() end
  return rec
end

local function IsWeekly(info)
  if info.isWeekly then return true end
  local freq = info.frequency
  local weeklyEnum = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly
  return freq == 2 or (weeklyEnum and freq == weeklyEnum)
end

function LS:GetPetRecommendations()
  local out = {}
  if not (self.db and self.db.goals and self.db.goals.PETS) then return out end
  if not self:PetJournalReady() then return out end

  local progress = self:BattlePetProgress() or { unique = 0, owned = 0, team = {} }
  local locked, emptyUnlocked = 0, 0
  for slot = 1, 3 do
    local row = progress.team[slot]
    if row and row.locked then
      locked = locked + 1
    elseif row and not row.guid then
      emptyUnlocked = emptyUnlocked + 1
    end
  end
  local journalLocked = C_PetJournal.IsJournalUnlocked
    and Safe(C_PetJournal.IsJournalUnlocked) == false
  if journalLocked or (locked == 3) or (locked > 0 and (progress.owned or 0) == 0) then
    table.insert(out, AttachJournal({
      id = "pets_training",
      title = "Unlock battle pets",
      why = "Battle pet slots are still locked on this character.",
      category = "Battle Pets",
      tags = { PETS = 14 },
      urgency = "MEDIUM",
      priority = "MEDIUM PRIORITY",
      detail = {
        matters = "Lodestar only ranks this while the client says the journal or team slots are locked.",
      },
    }))
  elseif emptyUnlocked > 0 and (progress.owned or 0) > 0 then
    table.insert(out, AttachJournal({
      id = "pets_team",
      title = "Fill your battle pet team",
      why = "An unlocked slot has no pet slotted.",
      category = "Battle Pets",
      tags = { PETS = 10 },
      urgency = "LOW",
      priority = "LOW PRIORITY",
      detail = {
        matters = "The team comes from C_PetJournal.GetPetLoadOutInfo. Lodestar does not pick a pet for you.",
      },
    }))
  end

  local n = 0
  for _, info in ipairs(QuestLog()) do
    if n >= MAX_QUESTS then break end
    if self:IsPetBattleQuest(info) then
      n = n + 1
      local title = info.title or "Pet battle"
      local ready = info.readyForTurnIn or Safe(C_QuestLog and C_QuestLog.IsComplete, info.questID)
      local weekly = IsWeekly(info)
      table.insert(out, AttachJournal({
        id = (weekly and "pets_weekly_" or "pets_quest_") .. tostring(info.questID),
        title = ready and ("Turn in: " .. title) or title,
        why = ready and "This pet battle quest is ready to turn in."
          or "A pet battle quest is already in your log.",
        category = "Battle Pets",
        tags = { PETS = 12 },
        urgency = ready and "HIGH" or "MEDIUM",
        priority = ready and "HIGH PRIORITY" or "MEDIUM PRIORITY",
        detail = {
          matters = "Lodestar only ranks pet battle quests the client already put in the log.",
        },
      }))
    end
  end
  return out
end
