local _, LS = ...

LS.professions = {}

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

local function QuestDone(questID)
  if type(questID) ~= "number" then return false end
  return Safe(C_QuestLog.IsQuestFlaggedCompleted, questID) and true or false
end

-- Knowledge points still sitting unspent in the profession's currency.
local function UnspentKnowledge(skillLineID)
  local info = Safe(C_ProfSpecs.GetCurrencyInfoForSkillLine, skillLineID)
  if type(info) ~= "table" then return 0, nil end
  return info.numAvailable or 0, info.currencyName
end

-- Walks the specialization trees and counts ranks still to buy, and ranks already
-- purchased. Unlocking a node grants its first rank for free, so spent knowledge is
-- the ranks after that.
local function TreeProgress(configID, rootNodeID)
  local queue, missing, spent = { rootNodeID }, 0, 0
  local guard = 0
  while #queue > 0 and guard < 4000 do
    guard = guard + 1
    local nodeID = table.remove(queue)
    local children = Safe(C_ProfSpecs.GetChildrenForPath, nodeID)
    if type(children) == "table" then
      for _, child in ipairs(children) do
        table.insert(queue, child)
      end
    end
    local info = Safe(C_Traits.GetNodeInfo, configID, nodeID)
    if type(info) == "table" and (info.maxRanks or 0) > 0 then
      local active = info.activeRank or 0
      local freeRank = active == 0 and 1 or 0
      missing = missing + math.max(0, (info.maxRanks or 0) - active - freeRank)
      if active > 0 then
        spent = spent + math.max(0, active - 1)
      end
    end
  end
  return missing, spent
end

local function RemainingKnowledge(skillLineID)
  local configID = Safe(C_ProfSpecs.GetConfigIDForSkillLine, skillLineID)
  if not configID then return nil, nil end
  local tabs = Safe(C_ProfSpecs.GetSpecTabIDsForSkillLine, skillLineID)
  if type(tabs) ~= "table" or #tabs == 0 then return nil, nil end
  local missing, spent = 0, 0
  for _, tabID in ipairs(tabs) do
    local tabInfo = Safe(C_ProfSpecs.GetTabInfo, tabID)
    local rootNodeID = tabInfo and tabInfo.rootNodeID
    if rootNodeID then
      local moreMissing, moreSpent = TreeProgress(configID, rootNodeID)
      missing = missing + moreMissing
      spent = spent + moreSpent
    end
  end
  return missing, spent
end

local function CountCompleted(quests, cap)
  local done = 0
  for _, questID in ipairs(quests or {}) do
    if QuestDone(questID) then done = done + 1 end
  end
  return math.min(done, cap)
end

-- Quest turn-ins, world drops and treasures are all knowledge, but they ask for very
-- different things from the player, so each gets its own bucket. Quests and drops reset
-- weekly; treasures are once per character.
local BUCKETS = {
  TREATISE = "quests",
  WEEKLY = "quests",
  GATHERING = "gathering",
  TREASURE = "treasures",
}

local function NewBucket()
  return { done = 0, total = 0, points = 0, pending = {} }
end

local function ByValue(a, b)
  if a.points ~= b.points then return a.points > b.points end
  return a.label < b.label
end

local function Tally(objectives)
  local buckets = { quests = NewBucket(), gathering = NewBucket(), treasures = NewBucket() }

  for _, objective in ipairs(objectives or {}) do
    local quests = objective.quests or {}
    -- A limit means the quests are alternatives: several are offered, one can be turned in.
    local cap = math.min(objective.limit or #quests, #quests)
    local bucket = buckets[BUCKETS[objective.kind] or ""]
    if cap > 0 and bucket then
      local done = CountCompleted(quests, cap)
      bucket.total = bucket.total + cap
      bucket.done = bucket.done + done
      local missing = cap - done
      if missing > 0 then
        local points = missing * (objective.points or 0)
        bucket.points = bucket.points + points
        table.insert(bucket.pending, {
          label = objective.label or "Knowledge",
          kind = objective.kind,
          count = missing,
          points = points,
          map = objective.map,
          x = objective.x,
          y = objective.y,
          note = objective.note,
        })
      end
    end
  end

  -- Everything that resets, combined, for the summaries that only care about the week.
  local weekly = NewBucket()
  for _, name in ipairs({ "quests", "gathering" }) do
    local bucket = buckets[name]
    weekly.done = weekly.done + bucket.done
    weekly.total = weekly.total + bucket.total
    weekly.points = weekly.points + bucket.points
    for _, item in ipairs(bucket.pending) do
      table.insert(weekly.pending, item)
    end
  end

  for _, bucket in pairs(buckets) do
    table.sort(bucket.pending, ByValue)
  end
  table.sort(weekly.pending, ByValue)
  buckets.weekly = weekly
  return buckets
end

-- Catch-up knowledge starts dropping once the week's normal sources are exhausted, so
-- report which gates are still closed instead of a point total.
local function CatchUpStatus(catchUp)
  if type(catchUp) ~= "table" then return nil end
  local status = { hint = catchUp.hint, groups = {} }
  local ready = true
  for _, group in ipairs(catchUp.requires or {}) do
    local quests = group.quests or {}
    local need = (group.match == "any") and math.min(1, #quests) or #quests
    if need > 0 then
      local done = CountCompleted(quests, need)
      if done < need then ready = false end
      table.insert(status.groups, {
        label = group.label or "Requirement",
        done = done,
        need = need,
        ok = done >= need,
      })
    end
  end
  if #status.groups > 0 then
    status.ready = ready
  end
  return status
end

-- The professions this character has trained: two primaries plus Cooking, Fishing and
-- Archaeology when those slots are filled. Keyed by parent profession ID, because
-- GetAllProfessionTradeSkillLines returns every profession in the game, not the ones you know.
local function LearnedProfessions()
  local learned, any = {}, false
  local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
  local slots = {
    { prof1, false },
    { prof2, false },
    { archaeology, true },
    { fishing, true },
    { cooking, true },
  }
  for _, slot in ipairs(slots) do
    local index, secondary = slot[1], slot[2]
    if index then
      local name, _, skillLevel, maxSkillLevel, _, _, parentID, bonus, _, _, currentName = GetProfessionInfo(index)
      if parentID then
        learned[parentID] = {
          name = name,
          currentName = currentName or name,
          skill = skillLevel or 0,
          maxSkill = maxSkillLevel or 0,
          bonus = bonus or 0,
          secondary = secondary,
        }
        any = true
      end
    end
  end
  return learned, any
end

function LS:ScanProfessions()
  local out = {}
  local ids = Safe(C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines)
  if type(ids) ~= "table" then
    self.professions = out
    return
  end

  local learned, haveLearnedData = LearnedProfessions()

  for _, skillLineID in ipairs(ids) do
    local info = Safe(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
    local parentID = info and (info.parentProfessionID or info.professionID)
    local known = haveLearnedData and parentID and learned[parentID] or nil
    if info and info.professionName and info.professionName ~= "" and known then
      local hasSpecs = Safe(C_ProfSpecs.SkillLineHasSpecialization, skillLineID)
      if hasSpecs == nil then
        hasSpecs = Safe(C_ProfSpecs.GetConfigIDForSkillLine, skillLineID) and true or false
      end
      local isCurrent = known.currentName ~= nil and known.currentName == info.professionName
      if hasSpecs then
        local unspent, currencyName = UnspentKnowledge(skillLineID)
        local remaining, spent = RemainingKnowledge(skillLineID)
        local sources = self:KnowledgeSourcesFor(skillLineID)
        local entry = {
          skillLineID = skillLineID,
          parentID = parentID,
          name = info.professionName,
          baseName = info.parentProfessionName or info.professionName,
          skill = isCurrent and known.skill or (info.skillLevel or 0),
          maxSkill = isCurrent and known.maxSkill or (info.maxSkillLevel or 0),
          isCurrent = isCurrent,
          secondary = known.secondary,
          unspent = unspent,
          spent = spent,
          currencyName = currencyName,
          remaining = remaining,
          tracked = sources ~= nil,
        }
        if sources then
          local buckets = Tally(sources.objectives)
          entry.expansion = sources.expansion
          entry.quests = buckets.quests
          entry.gathering = buckets.gathering
          entry.treasures = buckets.treasures
          entry.weekly = buckets.weekly
          entry.catchUp = CatchUpStatus(sources.catchUp)
        end
        table.insert(out, entry)
        known.listed = true
      elseif known.secondary then
        table.insert(out, {
          skillLineID = skillLineID,
          parentID = parentID,
          name = info.professionName,
          baseName = info.parentProfessionName or known.name or info.professionName,
          skill = isCurrent and known.skill or (info.skillLevel or 0),
          maxSkill = isCurrent and known.maxSkill or (info.maxSkillLevel or 0),
          isCurrent = isCurrent,
          secondary = true,
          unspent = 0,
          remaining = nil,
          tracked = false,
        })
        known.listed = true
      end
    end
  end

  -- Archaeology never appears as an expansion skill line. Cooking and Fishing do, but
  -- if the client has not sent those lines yet the trained slot still deserves a tab.
  for parentID, known in pairs(learned) do
    if known.secondary and not known.listed then
      table.insert(out, {
        skillLineID = parentID,
        parentID = parentID,
        name = known.currentName or known.name or "Profession",
        baseName = known.name or known.currentName,
        skill = known.skill,
        maxSkill = known.maxSkill,
        isCurrent = true,
        secondary = true,
        unspent = 0,
        remaining = nil,
        tracked = false,
      })
    end
  end

  -- No expansion reported itself as current, so fall back to the newest skill line per
  -- profession rather than showing nothing.
  local sawCurrent = false
  for _, entry in ipairs(out) do
    if entry.isCurrent then sawCurrent = true end
  end
  if not sawCurrent then
    local newest = {}
    for _, entry in ipairs(out) do
      local best = newest[entry.parentID]
      if not best or entry.skillLineID > best.skillLineID then
        newest[entry.parentID] = entry
      end
    end
    for _, entry in pairs(newest) do
      entry.isCurrent = true
    end
  end

  table.sort(out, function(a, b)
    if a.secondary ~= b.secondary then return not a.secondary end
    if a.isCurrent ~= b.isCurrent then return a.isCurrent end
    return a.name < b.name
  end)
  self.professions = out
end

function LS:CurrentExpansionProfessions()
  local all = self.professions or {}
  local out = {}
  for _, prof in ipairs(all) do
    if prof.isCurrent then
      table.insert(out, prof)
    end
  end
  return #out > 0 and out or all
end

function LS:PrimaryProfessions()
  if not GetProfessions or not GetProfessionInfo then return {} end
  local prof1, prof2 = GetProfessions()
  local out = {}
  for _, index in ipairs({ prof1, prof2 }) do
    if index then
      local name, icon, _, _, _, _, parentID, _, _, _, currentName = GetProfessionInfo(index)
      if parentID then
        local match
        for _, prof in ipairs(self.professions or {}) do
          if prof.parentID == parentID and prof.isCurrent then
            match = prof
            break
          end
        end
        if not match then
          for _, prof in ipairs(self.professions or {}) do
            if prof.parentID == parentID then match = prof break end
          end
        end
        table.insert(out, {
          name = currentName or name,
          icon = icon,
          skillLineID = match and match.skillLineID or parentID,
          parentID = parentID,
        })
      end
    end
  end
  return out
end

function LS:VisibleProfessions()
  if not (self.db and self.db.currentExpansionOnly) then
    return self.professions
  end
  return self:CurrentExpansionProfessions()
end

-- Unspent knowledge, weekly tasks left, treasures left, professions where catch-up
-- knowledge is already farmable, and the knowledge those weekly tasks are still worth.
-- Dashboard and Warband always use the current expansion so leftover Khaz Algar
-- (or older) points do not look like work still to do this season.
function LS:ProfessionSummary()
  local unspent, weeklyLeft, treasureLeft, catchUpReady, weeklyPoints = 0, 0, 0, 0, 0
  for _, prof in ipairs(self:CurrentExpansionProfessions()) do
    unspent = unspent + (prof.unspent or 0)
    if prof.weekly then
      weeklyLeft = weeklyLeft + (prof.weekly.total - prof.weekly.done)
      weeklyPoints = weeklyPoints + prof.weekly.points
    end
    if prof.treasures then treasureLeft = treasureLeft + (prof.treasures.total - prof.treasures.done) end
    if prof.catchUp and prof.catchUp.ready then catchUpReady = catchUpReady + 1 end
  end
  return unspent, weeklyLeft, treasureLeft, catchUpReady, weeklyPoints
end

local function StepLines(pending)
  local out = {}
  for _, item in ipairs(pending or {}) do
    local label = item.label
    if item.count > 1 then
      label = string.format("%s (%d left)", label, item.count)
    end
    table.insert(out, string.format("%s  •  +%d knowledge", label, item.points))
  end
  return out
end

local function Plural(count, word)
  return count == 1 and word or (word .. "s")
end

local function WaypointsFromPending(pending)
  if not LS.NormalizeWaypoints then return nil end
  return LS:NormalizeWaypoints(pending)
end

function LS:GetProfessionRecommendations()
  local out = {}
  for _, prof in ipairs(self:VisibleProfessions()) do
    if (prof.unspent or 0) > 0 then
      table.insert(out, {
        id = "kp_spend_" .. prof.skillLineID,
        title = string.format("Spend %d knowledge on %s", prof.unspent, prof.name),
        minutes = 2,
        score = 34,
        why = string.format("%d unspent knowledge %s doing nothing. Spending it is an instant power gain.",
          prof.unspent, prof.unspent == 1 and "point is" or "points are"),
        category = "Professions",
        tags = { CRAFTING = 12 },
        urgency = "HIGH",
        priority = "FREE VALUE",
        detail = { source = prof.name, current = prof.unspent .. " unspent", potential = "Spent into your tree" },
      })
    end
    local quests = prof.quests
    if quests and quests.done < quests.total then
      local left = quests.total - quests.done
      table.insert(out, {
        id = "kp_weekly_" .. prof.skillLineID,
        title = string.format("Turn in %d weekly %s knowledge %s", left, prof.name, Plural(left, "quest")),
        minutes = math.max(8, left * 6),
        score = 30,
        why = string.format("Worth %d knowledge %s that %s at weekly reset. Skipping the week loses them for good.",
          quests.points, Plural(quests.points, "point"), left == 1 and "disappears" or "disappear"),
        category = "Professions",
        tags = { CRAFTING = 10 },
        urgency = "HIGH",
        priority = "WEEKLY",
        detail = {
          source = prof.name,
          current = quests.done .. "/" .. quests.total .. " turned in",
          potential = "+" .. quests.points .. " knowledge",
          steps = StepLines(quests.pending),
        },
      })
    end

    local gathering = prof.gathering
    if gathering and gathering.done < gathering.total then
      local left = gathering.total - gathering.done
      table.insert(out, {
        id = "kp_gather_" .. prof.skillLineID,
        title = string.format("Farm this week's %s knowledge drops", prof.name),
        minutes = math.max(15, left * 5),
        score = 26,
        why = string.format("%d knowledge %s still drop from working your profession this week, across %d %s.",
          gathering.points, Plural(gathering.points, "point"), left, Plural(left, "drop")),
        category = "Professions",
        tags = { CRAFTING = 9 },
        urgency = "MEDIUM",
        priority = "WEEKLY",
        detail = {
          source = prof.name,
          current = gathering.done .. "/" .. gathering.total .. " found",
          potential = "+" .. gathering.points .. " knowledge",
          steps = StepLines(gathering.pending),
        },
      })
    end

    local treasures = prof.treasures
    if treasures and treasures.done < treasures.total then
      local left = treasures.total - treasures.done
      local points = WaypointsFromPending(treasures.pending)
      table.insert(out, {
        id = "kp_treasure_" .. prof.skillLineID,
        title = string.format("Collect %d %s %s", left, prof.name, Plural(left, "treasure")),
        minutes = math.max(10, left * 8),
        score = 24,
        why = string.format("One-time knowledge worth %d %s. It never expires, so it is pure profit whenever you get to it.",
          treasures.points, Plural(treasures.points, "point")),
        category = "Professions",
        tags = { CRAFTING = 8 },
        urgency = "LOW",
        priority = "ONE TIME",
        waypoints = points,
        openLabel = points and (LS:WaypointButtonLabel(points) or "Waypoint") or nil,
        open = points and function() LS:MarkWaypoints(points, prof.name .. " treasures") end or nil,
        detail = {
          source = prof.name,
          current = treasures.done .. "/" .. treasures.total .. " collected",
          potential = "+" .. treasures.points .. " knowledge",
          steps = StepLines(treasures.pending),
        },
      })
    end

    -- Once the week's fixed sources are done, catch-up knowledge starts dropping and is
    -- effectively uncapped, so it is worth surfacing on its own.
    if prof.catchUp and prof.catchUp.ready then
      table.insert(out, {
        id = "kp_catchup_" .. prof.skillLineID,
        title = string.format("Farm catch-up knowledge for %s", prof.name),
        minutes = 20,
        score = 18,
        why = "This week's fixed sources are done, so catch-up knowledge can drop now.",
        category = "Professions",
        tags = { CRAFTING = 6 },
        urgency = "LOW",
        priority = "OPEN",
        detail = {
          source = prof.name,
          current = "All weekly gates cleared",
          potential = "Extra knowledge from world drops",
          matters = prof.catchUp.hint,
        },
      })
    end

    local needsSkill = (prof.maxSkill or 0) > 0 and (prof.skill or 0) < prof.maxSkill
    if needsSkill and (not prof.secondary or not prof.tracked) then
      local left = prof.maxSkill - prof.skill
      local secondary = prof.secondary and not prof.tracked
      table.insert(out, {
        id = "prof_level_" .. prof.skillLineID,
        title = string.format("Level %s (%d / %d)", prof.baseName or prof.name, prof.skill, prof.maxSkill),
        minutes = math.max(15, math.min(60, left)),
        score = secondary and 20 or 18,
        why = secondary
          and string.format("%s is a secondary profession. Skill is the progress that matters, and this character is not at the cap yet.",
            prof.baseName or prof.name)
          or string.format("%s is not at the skill cap. First crafts and trainer recipes in the profession window are the leveling path.",
            prof.baseName or prof.name),
        category = "Professions",
        tags = { CRAFTING = 7 },
        urgency = "MEDIUM",
        detail = {
          source = prof.baseName or prof.name,
          current = string.format("%d / %d", prof.skill, prof.maxSkill),
          potential = "Cap",
        },
      })
    end
  end
  return out
end

-- Open / Specializations on the profession card, or a click on the page body.
-- Tabs only switch the card. OpenTradeSkill needs a hardware event, so this
-- only runs from OnMouseUp.
function LS:OpenProfessionWindow(prof, spec)
  if not prof then return end
  local frame = _G.ProfessionsFrame or _G.TradeSkillFrame
  if frame and frame.IsShown and frame:IsShown() then
    local live
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
      local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
      if ok and type(info) == "table" then
        live = tonumber(info.professionID) or tonumber(info.parentProfessionID)
      end
    end
    local want = tonumber(prof.skillLineID) or tonumber(prof.parentID)
    if not live or live == want or live == tonumber(prof.parentID) or live == tonumber(prof.skillLineID) then
      if LS.HideClientFrame then LS:HideClientFrame(frame) end
      return true
    end
  end
  if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
  elseif LoadAddOn then
    pcall(LoadAddOn, "Blizzard_Professions")
  end
  if ProfessionsFrame_LoadUI then pcall(ProfessionsFrame_LoadUI) end
  local opened
  if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
    local ok, result = pcall(C_TradeSkillUI.OpenTradeSkill, prof.skillLineID)
    opened = ok and result
    if not opened and prof.parentID and prof.parentID ~= prof.skillLineID then
      ok, result = pcall(C_TradeSkillUI.OpenTradeSkill, prof.parentID)
      opened = ok and result
    end
  end
  local function front()
    local frame = _G.ProfessionsFrame or _G.TradeSkillFrame
    if frame and LS.FrontClientFrame then LS:FrontClientFrame(frame) end
  end
  front()
  if spec then
    local function goSpec()
      local frame = _G.ProfessionsFrame
      if frame and frame.specializationsTabID and frame.SetTab then
        pcall(frame.SetTab, frame, frame.specializationsTabID, true)
      end
      front()
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0.2, goSpec)
    else
      goSpec()
    end
  elseif C_Timer and C_Timer.After then
    C_Timer.After(0, front)
  end
  return opened
end
