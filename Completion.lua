local _, LS = ...

local function Snapshot(activity)
  if type(activity) ~= "table" then return nil end
  return {
    title = activity.title,
    why = activity.why,
    category = activity.category,
  }
end

function LS:ProfessionBySkillLine(skillLineID)
  skillLineID = tonumber(skillLineID)
  if not skillLineID then return end
  for _, prof in ipairs(self.professions or {}) do
    if prof.skillLineID == skillLineID then return prof end
  end
end

local function ProfLevelDone(prof)
  return type(prof) == "table"
    and (prof.maxSkill or 0) > 0
    and (prof.skill or 0) >= prof.maxSkill
end

local function BucketDone(bucket)
  return type(bucket) == "table" and (bucket.total or 0) > 0 and (bucket.done or 0) >= bucket.total
end

local function ProfessionName(prof)
  if LS.ProfessionActivityName then return LS:ProfessionActivityName(prof) end
  return prof.name or prof.baseName or "Profession"
end

local function ProfLevelSnapshot(prof)
  local label = ProfessionName(prof)
  return {
    id = "prof_level_" .. prof.skillLineID,
    title = string.format("Level %s (%d / %d)", label, prof.skill, prof.maxSkill),
    why = string.format("%s reached %d / %d.", label, prof.skill, prof.maxSkill),
    category = "Professions",
  }
end

local function ProfessionCompletionActivity(prof, id)
  if type(prof) ~= "table" or not id then return end
  local sid = prof.skillLineID
  local label = ProfessionName(prof)
  if id == "prof_level_" .. sid and ProfLevelDone(prof) then
    return ProfLevelSnapshot(prof)
  end
  if id == "kp_weekly_" .. sid and prof.quests and BucketDone(prof.quests) then
    return {
      id = id,
      title = string.format("Weekly %s knowledge quests done", label),
      why = string.format("Every weekly %s knowledge quest for this week is turned in.", label),
      category = "Professions",
    }
  end
  if id == "kp_gather_" .. sid and prof.gathering and BucketDone(prof.gathering) then
    return {
      id = id,
      title = string.format("Weekly %s knowledge drops done", label),
      why = string.format("Every %s knowledge drop for this week is collected.", label),
      category = "Professions",
    }
  end
  if id == "kp_treasure_" .. sid and prof.treasures and BucketDone(prof.treasures) then
    return {
      id = id,
      title = string.format("%s knowledge treasures collected", label),
      why = string.format("Every one-time %s knowledge treasure is collected.", label),
      category = "Professions",
    }
  end
  if id == "kp_spend_" .. sid
    and not LS:CanSpendKnowledge(prof)
    and (prof.spent or 0) > 0
    and (prof.unspent or 0) == 0 then
    return {
      id = id,
      title = string.format("%s knowledge tree finished", label),
      why = string.format("Every purchasable %s specialization rank is bought.", label),
      category = "Professions",
    }
  end
  if id == "kp_catchup_" .. sid
    and prof.catchUp
    and prof.catchUp.ready
    and LS:ProfessionTreesFull(prof) then
    return {
      id = id,
      title = string.format("%s catch-up knowledge handled", label),
      why = "Weekly gates are clear and the specialization tree is complete.",
      category = "Professions",
    }
  end
end

function LS:ProfessionCompletionActivity(id)
  local sid = id and id:match("_(%d+)$")
  if not sid then return end
  local prof = self:ProfessionBySkillLine(tonumber(sid))
  if not prof then return end
  return ProfessionCompletionActivity(prof, id)
end

function LS:CompletedActivity(id)
  if not id then return end
  local live = self:ProfessionCompletionActivity(id)
  if live then return live end
  local snap = self.db and self.db.completedSnapshot and self.db.completedSnapshot[id]
  if type(snap) == "table" and snap.title then
    return {
      id = id,
      title = snap.title,
      why = snap.why,
      category = snap.category,
    }
  end
  return self:FindActivity(id)
end

local function ProfessionCompletionChecks()
  local out = {}
  for _, prof in ipairs(LS.professions or {}) do
    local sid = prof.skillLineID
    local ids = {
      "prof_level_" .. sid,
      "kp_weekly_" .. sid,
      "kp_gather_" .. sid,
      "kp_treasure_" .. sid,
      "kp_spend_" .. sid,
      "kp_catchup_" .. sid,
    }
    for _, id in ipairs(ids) do
      local activity = ProfessionCompletionActivity(prof, id)
      if activity then out[id] = activity end
    end
  end
  return out
end

function LS:SyncAutoCompleted()
  if not self.db then return end
  self.db.completedAuto = self.db.completedAuto or {}
  self.db.completedBlock = self.db.completedBlock or {}
  self.db.completedSnapshot = self.db.completedSnapshot or {}

  local checks = ProfessionCompletionChecks()
  for id, activity in pairs(checks) do
    if not self.db.completedBlock[id] then
      if not self.db.completed[id] then
        self.db.completed[id] = true
        self.db.completedAuto[id] = true
        self.db.completedSnapshot[id] = Snapshot(activity)
      elseif self.db.completedAuto[id] then
        self.db.completedSnapshot[id] = Snapshot(activity)
      end
    end
  end

  for id, auto in pairs(self.db.completedAuto) do
    if auto and not checks[id] then
      self.db.completed[id] = nil
      self.db.completedAuto[id] = nil
      self.db.completedSnapshot[id] = nil
      self.db.completedBlock[id] = nil
    end
  end
end

function LS:MarkCompleted(id, activity)
  if not self.db or not id then return end
  self.db.completed = self.db.completed or {}
  self.db.completedAuto = self.db.completedAuto or {}
  self.db.completedBlock = self.db.completedBlock or {}
  self.db.completedSnapshot = self.db.completedSnapshot or {}
  self.db.completed[id] = true
  self.db.completedAuto[id] = nil
  self.db.completedBlock[id] = nil
  local snap = Snapshot(activity or self:ProfessionCompletionActivity(id) or self:FindActivity(id))
  if snap then self.db.completedSnapshot[id] = snap end
end

function LS:UnmarkCompleted(id)
  if not self.db or not id then return end
  local wasAuto = self.db.completedAuto and self.db.completedAuto[id]
  self.db.completed[id] = nil
  if wasAuto then
    self.db.completedAuto[id] = nil
    self.db.completedBlock = self.db.completedBlock or {}
    self.db.completedBlock[id] = true
  end
  if self.db.completedSnapshot then self.db.completedSnapshot[id] = nil end
end

function LS:ClearCompletedFlags()
  if not self.db then return end
  self.db.dismissed = {}
  self.db.completed = {}
  self.db.completedAuto = {}
  self.db.completedBlock = {}
  self.db.completedSnapshot = {}
end
