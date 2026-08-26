local _, LS = ...
LS.vault = { rows = {} }

local RAID_RANK = { [17] = 1, [14] = 2, [15] = 3, [16] = 4 }
local RAID_NEXT = { [17] = 14, [14] = 15, [15] = 16 }

-- Highest tier that still improves a vault reward, per category. This is patch data,
-- so it is kept here as a single editable number rather than scattered through logic.
-- A tier is only called maxed when it reaches this cap; anything below it is treated as
-- upgradable, even when the client declines to hand out an upgrade preview.
LS.tierCaps = { world = 11 }

local function EnumType(name, fallback)
  local t = Enum and Enum.WeeklyRewardChestThresholdType
  return t and t[name] or fallback
end

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function DifficultyName(id)
  if not id or id == 0 then return nil end
  if DifficultyUtil and DifficultyUtil.GetDifficultyName then
    local name = DifficultyUtil.GetDifficultyName(id)
    if name and name ~= "" then return name end
  end
  local name = Safe(GetDifficultyInfo, id)
  if name and name ~= "" then return name end
  return nil
end

local function NextRaidDifficulty(id)
  if DifficultyUtil and DifficultyUtil.GetNextPrimaryRaidDifficultyID then
    local nextID = DifficultyUtil.GetNextPrimaryRaidDifficultyID(id)
    if nextID then return nextID end
  end
  return RAID_NEXT[id]
end

local function FormatThreshold(template, threshold)
  threshold = threshold or 0
  if type(template) ~= "string" or template == "" then
    return string.format("Complete %d activities", threshold)
  end
  local ok, value = pcall(string.format, template, threshold)
  if ok then return value end
  return template
end

-- Every run the player has banked this week, expanded to one entry per run and sorted
-- best first. Blizzard reports world activities as {difficulty, numPoints} buckets and
-- dungeons as individual keystone runs, so both shapes are flattened here.
local function SortedRuns(kind, enumValue)
  local runs = {}

  if kind == "activities" then
    local history = Safe(C_MythicPlus.GetRunHistory, false, true)
    if type(history) == "table" then
      for _, run in ipairs(history) do
        table.insert(runs, run.level or 0)
      end
    end
  end

  if #runs == 0 then
    local list = Safe(C_WeeklyRewards.GetSortedProgressForActivity, enumValue, true)
    if type(list) == "table" then
      for _, entry in ipairs(list) do
        local tier = entry.difficulty or entry.level or 0
        local count = entry.numPoints or entry.numRuns or entry.runs or 1
        if type(count) ~= "number" or count < 1 then count = 1 end
        for _ = 1, math.min(count, 100) do
          table.insert(runs, tier)
        end
      end
    end
  end

  table.sort(runs, function(a, b) return a > b end)
  return runs
end

-- The tier a slot locks in is the weakest run inside its top N, which is what the
-- player has to push out to improve the reward.
local function WeakestInTopRuns(runs, threshold)
  if threshold <= 0 or #runs == 0 then return nil end
  local index = math.min(threshold, #runs)
  return runs[index]
end

local function TopRunsSummary(runs, threshold)
  if #runs == 0 or threshold <= 0 then return nil end
  local counts, order = {}, {}
  for i = 1, math.min(threshold, #runs) do
    local tier = runs[i]
    if not counts[tier] then
      counts[tier] = 0
      table.insert(order, tier)
    end
    counts[tier] = counts[tier] + 1
  end
  local parts = {}
  for _, tier in ipairs(order) do
    table.insert(parts, string.format("%d x%d", tier, counts[tier]))
  end
  return table.concat(parts, ", ")
end

local function CountRunsAbove(runs, tier)
  local n = 0
  for _, value in ipairs(runs) do
    if value > tier then n = n + 1 end
  end
  return n
end

local function BestRun(runs)
  return runs[1] or 0
end

local function TierLabel(kind, level, isHeroicTier)
  if kind == "activities" then
    if isHeroicTier then
      return _G.WEEKLY_REWARDS_HEROIC or "Heroic"
    end
    local fmt = _G.WEEKLY_REWARDS_MYTHIC or "Mythic %d"
    local ok, value = pcall(string.format, fmt, level)
    return ok and value or ("Mythic " .. tostring(level))
  end
  local fmt = _G.GREAT_VAULT_WORLD_TIER or "Tier %d"
  local ok, value = pcall(string.format, fmt, level)
  return ok and value or ("Tier " .. tostring(level))
end

local function IsHeroicTier(tierID)
  local difficultyID = Safe(C_WeeklyRewards.GetDifficultyIDForActivityTier, tierID)
  local heroic = DifficultyUtil and DifficultyUtil.ID and DifficultyUtil.ID.DungeonHeroic
  return difficultyID and (difficultyID == heroic or difficultyID == 2)
end

local function RaidEncounters(index)
  return Safe(C_WeeklyRewards.GetActivityEncounterInfo, EnumType("Raid", 3), index) or {}
end

local function CountEncountersAtLeast(encounters, minDifficultyID)
  local minRank = RAID_RANK[minDifficultyID] or 0
  if minRank == 0 then return 0 end
  local n = 0
  for _, encounter in ipairs(encounters or {}) do
    if (RAID_RANK[encounter.bestDifficulty or 0] or 0) >= minRank then
      n = n + 1
    end
  end
  return n
end

local function RaidAnalysis(slot)
  local remaining = math.max(0, slot.threshold - slot.progress)
  if remaining > 0 then
    slot.current = "Empty"
    slot.potential = DifficultyName(slot.level) or "Raid Finder"
    return {
      upgradable = false,
      effort = remaining,
      text = string.format("Kill %d more raid %s.", remaining, remaining == 1 and "boss" or "bosses"),
      why = string.format("Raid Vault slot %d is empty (%d/%d bosses).", slot.index, slot.progress, slot.threshold),
      minutes = math.max(20, remaining * 15),
      score = 38 + (4 - slot.index) * 3,
    }
  end

  slot.current = DifficultyName(slot.level) or "Unknown"
  local nextID = NextRaidDifficulty(slot.level)
  if not nextID then
    slot.potential = "Maxed"
    return { upgradable = false, effort = 0, text = "Already at the highest raid difficulty.", why = "Nothing improves this slot.", minutes = 0, score = 0 }
  end

  local nextName = DifficultyName(nextID) or "higher difficulty"
  slot.potential = nextName
  local have = CountEncountersAtLeast(RaidEncounters(slot.index), nextID)
  local need = math.max(1, slot.threshold - have)
  return {
    upgradable = true,
    effort = need,
    text = string.format("Kill %d %s %s.", need, nextName, need == 1 and "boss" or "bosses"),
    why = string.format("Raid Vault slot %d currently uses %s quality. %s kills improve the reward.", slot.index, slot.current, nextName),
    minutes = math.max(20, need * 15),
    score = 44 + math.max(0, 8 - need * 2) + (4 - slot.index),
  }
end

local function RunAnalysis(kind, slot, runs)
  local noun = kind == "world" and "delve" or "dungeon"
  local nounPlural = kind == "world" and "delves" or "dungeons"
  local remaining = math.max(0, slot.threshold - slot.progress)
  if remaining > 0 then
    slot.current = "Empty"
    slot.potential = "—"
    return {
      upgradable = false,
      effort = remaining,
      text = string.format("Complete %d more %s.", remaining, remaining == 1 and noun or nounPlural),
      why = string.format("%s Vault slot %d is empty (%d/%d runs).", slot.label, slot.index, slot.progress, slot.threshold),
      minutes = math.max(15, remaining * 20),
      score = 28 + (4 - slot.index) * 2,
    }
  end

  local heroic = kind == "activities" and IsHeroicTier(slot.tier)
  slot.current = TierLabel(kind, slot.level, heroic)
  slot.topRuns = TopRunsSummary(runs, slot.threshold)

  -- The cap is whichever is higher: the known patch cap, or a tier you have actually run.
  local cap = LS.tierCaps[kind]
  local best = BestRun(runs)
  if cap and best > cap then cap = best end

  if cap and slot.level >= cap then
    slot.potential = "Maxed"
    return {
      upgradable = false,
      effort = 0,
      text = string.format("Nothing improves this slot. %s is the highest tier that counts.", slot.current),
      why = string.format("%s Vault slot %d is already at the reward cap.", slot.label, slot.index),
      minutes = 0,
      score = 0,
    }
  end

  -- Blizzard's own upgrade hint, when the client offers one.
  local hasData, _, nextLevel = Safe(C_WeeklyRewards.GetNextActivitiesIncrease, slot.tier, slot.level)
  local target
  if hasData and nextLevel and nextLevel > slot.level then
    target = nextLevel
  end

  -- Otherwise: a tier you have already cleared, or the known cap, proves an upgrade exists.
  if not target and (best > slot.level or (cap and cap > slot.level)) then
    target = slot.level + 1
  end

  if not target then
    slot.potential = "No higher run this week"
    return {
      upgradable = false,
      effort = 0,
      text = string.format("Run a higher %s to improve this slot.", noun),
      why = string.format("%s Vault slot %d sits at %s, your best run so far this week.", slot.label, slot.index, slot.current),
      minutes = 30,
      score = 12,
    }
  end

  slot.potential = TierLabel(kind, target, false)

  -- This slot is pinned by the weakest run inside its top N. Every new run above that
  -- tier pushes the weak one out, so the work left is however many are still missing.
  local above = CountRunsAbove(runs, slot.level)
  local need = math.max(1, slot.threshold - above)
  return {
    upgradable = true,
    effort = need,
    text = string.format("Complete %d %s at %s or higher.", need, need == 1 and noun or nounPlural, slot.potential),
    why = string.format("Slot %d locks in the weakest of your top %d runs, currently %s. You already have %d run%s above it, so %d more at %s pushes it out.",
      slot.index, slot.threshold, slot.current, above, above == 1 and "" or "s", need, slot.potential),
    minutes = math.max(15, need * 18),
    score = 34 + math.max(0, 8 - need) + (4 - slot.index),
  }
end

local function AnalyzeSlot(kind, label, activity, runs)
  local slot = {
    kind = kind,
    label = label,
    index = activity.index or 0,
    threshold = activity.threshold or 0,
    progress = activity.progress or 0,
    level = activity.level or 0,
    tier = activity.activityTierID or 0,
    id = activity.id,
    raidString = activity.raidString,
  }
  slot.complete = slot.progress >= slot.threshold

  local template
  if kind == "raid" then
    template = activity.raidString or _G.WEEKLY_REWARDS_THRESHOLD_RAID
  elseif kind == "activities" then
    template = _G.WEEKLY_REWARDS_THRESHOLD_DUNGEONS
  else
    template = _G.WEEKLY_REWARDS_THRESHOLD_WORLD
  end
  slot.description = FormatThreshold(template, slot.threshold)

  if kind == "raid" then
    slot.advice = RaidAnalysis(slot)
  else
    slot.advice = RunAnalysis(kind, slot, runs)
  end
  slot.recommended = slot.advice.text
  return slot
end

function LS:ScanVault()
  local vault = { rows = {} }
  if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then
    self.vault = vault
    return
  end

  local groups = {
    { "raid", "Raid", EnumType("Raid", 3) },
    { "activities", "Dungeons", EnumType("Activities", 1) },
    { "world", "World", EnumType("World", 6) },
  }

  for _, group in ipairs(groups) do
    local key, label, enumValue = group[1], group[2], group[3]
    local data = Safe(C_WeeklyRewards.GetActivities, enumValue) or {}
    local runs = key ~= "raid" and SortedRuns(key, enumValue) or {}
    local row = { label = label, slots = {}, runs = runs }
    if type(data) == "table" then
      for _, activity in ipairs(data) do
        table.insert(row.slots, AnalyzeSlot(key, label, activity, runs))
      end
      table.sort(row.slots, function(a, b) return a.index < b.index end)
    end
    vault.rows[key] = row
  end

  self.vault = vault
  if self.profile then
    self.profile.vault = vault
  end
end

function LS:VaultSummary()
  local filled, total, upgradable = 0, 0, 0
  for _, key in ipairs({ "raid", "activities", "world" }) do
    local row = self.vault and self.vault.rows and self.vault.rows[key]
    if row then
      for _, slot in ipairs(row.slots) do
        total = total + 1
        if slot.complete then filled = filled + 1 end
        if slot.advice and slot.advice.upgradable then upgradable = upgradable + 1 end
      end
    end
  end
  return filled, total, upgradable
end

-- Reward item levels come from the client's example hyperlink, not a season table.
-- Great Vault Key Info keeps Champion/Hero ranks in the Blizzard vault window; it
-- has no API, and copying its patch tables would go stale and invent iLvls.
local function RewardItemLevels(activityID)
  if not activityID then return end
  local link, upgradeLink = Safe(C_WeeklyRewards and C_WeeklyRewards.GetExampleRewardItemHyperlinks, activityID)
  local function levelFrom(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then return end
    local level = Safe(C_Item and C_Item.GetDetailedItemLevelInfo, itemLink)
    if type(level) == "number" and level > 0 then return level end
  end
  return levelFrom(link), levelFrom(upgradeLink)
end

local function DungeonMapName(mapID)
  if not mapID then return end
  local name = Safe(C_ChallengeMode and C_ChallengeMode.GetMapUIInfo, mapID)
  if type(name) == "string" and name ~= "" then return name end
end

local function AppendRewardLines(lines, slot, indent)
  local current, upgrade = RewardItemLevels(slot and slot.id)
  if not current then return end
  indent = indent or ""
  if upgrade and upgrade ~= current then
    table.insert(lines, indent .. string.format("Reward item level %d  (upgrade %d)", current, upgrade))
  else
    table.insert(lines, indent .. string.format("Reward item level %d", current))
  end
end

local function AppendNamedKeyLines(lines, limit, indent)
  local history = Safe(C_MythicPlus and C_MythicPlus.GetRunHistory, false, true)
  if type(history) ~= "table" then return end
  local runs = {}
  for _, run in ipairs(history) do
    table.insert(runs, run)
  end
  table.sort(runs, function(a, b)
    local la, lb = a.level or 0, b.level or 0
    if la == lb then return (a.mapChallengeModeID or 0) < (b.mapChallengeModeID or 0) end
    return la > lb
  end)
  indent = indent or "  "
  local added = 0
  for _, run in ipairs(runs) do
    if limit and added >= limit then break end
    local name = DungeonMapName(run.mapChallengeModeID)
    if name then
      table.insert(lines, indent .. string.format("+%d  %s", run.level or 0, name))
      added = added + 1
    end
  end
end

function LS:VaultSlotTooltipLines(slot)
  local lines = {}
  if not slot then return lines end
  local mark = slot.complete and "Filled" or "Empty"
  table.insert(lines, string.format("%s slot %d  •  %s  •  %d/%d",
    slot.label or "Vault", slot.index or 0, mark, slot.progress or 0, slot.threshold or 0))
  if slot.current then
    table.insert(lines, "Current: " .. slot.current)
  end
  if slot.potential then
    table.insert(lines, "Potential: " .. slot.potential)
  end
  AppendRewardLines(lines, slot)
  if slot.topRuns then
    table.insert(lines, string.format("Top %d runs: %s", slot.threshold, slot.topRuns))
  end
  if slot.kind == "activities" then
    AppendNamedKeyLines(lines, slot.threshold or 8)
  end
  local rec = slot.recommended or slot.description
  if rec and rec ~= "" then
    table.insert(lines, rec)
  end
  return lines
end

function LS:VaultTooltipLines()
  local lines = {}
  local filled, total, upgradable = self:VaultSummary()
  table.insert(lines, string.format("%d of %d slots filled. %d can still be improved.",
    filled, total, upgradable))
  for _, key in ipairs({ "raid", "activities", "world" }) do
    local row = self.vault and self.vault.rows and self.vault.rows[key]
    if row then
      local rowFilled, rowTotal = 0, 0
      for _, slot in ipairs(row.slots or {}) do
        rowTotal = rowTotal + 1
        if slot.complete then rowFilled = rowFilled + 1 end
      end
      table.insert(lines, string.format("%s  %d/%d", row.label, rowFilled, rowTotal))
      for _, slot in ipairs(row.slots or {}) do
        local mark = slot.complete and "Filled" or "Empty"
        local rec = slot.recommended or slot.description or ""
        if rec ~= "" then
          table.insert(lines, string.format("  Slot %d  %s  %d/%d  %s",
            slot.index, mark, slot.progress or 0, slot.threshold or 0, rec))
        else
          table.insert(lines, string.format("  Slot %d  %s  %d/%d",
            slot.index, mark, slot.progress or 0, slot.threshold or 0))
        end
        AppendRewardLines(lines, slot, "    ")
      end
      if key == "activities" then
        AppendNamedKeyLines(lines, 8, "  ")
      end
    end
  end
  return lines
end

function LS:GetVaultRecommendations()
  local out = {}
  if self.IsEndgameLevel and not self:IsEndgameLevel() then return out end
  if self:HasUnclaimedVault() then
    table.insert(out, {
      id = "vault_claim_" .. self:WeeklyResetKey(),
      title = "Claim last week's Great Vault",
      minutes = 5,
      score = 48,
      why = "Tuesday reset rolled your loot. Open the vault and pick a reward from each filled slot.",
      category = "Great Vault",
      tags = { ENDGAME = 14 },
      urgency = "HIGH",
      priority = "FREE VALUE",
      openLabel = "Open Vault",
      open = function() LS:OpenGreatVault() end,
      detail = {
        current = "Unclaimed",
        potential = "Last week's rewards",
        matters = "The chest is already earned. Leaving it sitting does not make this week's vault better.",
      },
    })
  end
  for _, key in ipairs({ "raid", "activities", "world" }) do
    local row = self.vault.rows[key]
    if row then
      for _, slot in ipairs(row.slots) do
        local advice = slot.advice
        if advice and (advice.score or 0) > 0 then
          table.insert(out, {
            id = string.format("vault_%s_%d_%s", key, slot.index, advice.upgradable and "up" or "fill"),
            title = advice.text,
            minutes = advice.minutes,
            score = advice.score,
            why = advice.why,
            category = "Great Vault",
            tags = { ENDGAME = 12 },
            urgency = advice.upgradable and "HIGH" or "MEDIUM",
            priority = advice.upgradable and "HIGH PRIORITY" or "FILL SLOT",
            detail = {
              current = slot.current,
              potential = slot.potential,
              effort = advice.effort,
              source = string.format("%s Vault slot %d", slot.label, slot.index),
            },
          })
        end
        -- Later slots are not useful until this one is filled. An upgrade on a
        -- filled slot can still sit next to unlocking the following chest.
        if not slot.complete then break end
      end
    end
  end
  return out
end

local COFFER_KEY = 3028
local COFFER_SHARDS = 3310
local SHARDS_PER_KEY = 100
local GILDED_STASH_WIDGET = 7591

local function Currency(id)
  local info = Safe(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo, id)
  if type(info) ~= "table" then return 0, 0, 0 end
  return info.quantity or 0, info.quantityEarnedThisWeek or 0, info.maxWeeklyQuantity or 0
end

-- True while any World Vault slot is empty or still below the reward cap.
function LS:WorldVaultNeedsDelves()
  local row = self.vault and self.vault.rows and self.vault.rows.world
  if not row or not row.slots or #row.slots == 0 then return true end
  for _, slot in ipairs(row.slots) do
    if not slot.complete then return true end
    if slot.advice and slot.advice.upgradable then return true end
  end
  return false
end

-- Remaining T11 Bountiful Gilded Stashes this week, or nil when the client has not
-- handed the widget over yet (it often only updates near the Delver's Headquarters).
function LS:GildedStashesRemaining()
  local widget = Safe(C_UIWidgetManager and C_UIWidgetManager.GetSpellDisplayVisualizationInfo, GILDED_STASH_WIDGET)
  local tooltip = widget and widget.spellInfo and widget.spellInfo.tooltip
  if type(tooltip) ~= "string" then return nil end
  local have, need = tooltip:match("(%d+)%s*/%s*(%d+)")
  have, need = tonumber(have), tonumber(need)
  if not have or not need or need <= 0 then return nil end
  return math.max(0, need - have)
end

-- A Bountiful Delve is only worth ranking while it still pays: World Vault, a key,
-- enough shards to make a key, or a Gilded Stash still sitting this week.
function LS:BountifulDelveWorthDoing()
  if self:WorldVaultNeedsDelves() then return true end
  local keys = Currency(COFFER_KEY)
  if keys > 0 then return true end
  local shards = Currency(COFFER_SHARDS)
  if shards >= SHARDS_PER_KEY then return true end
  local gilded = self:GildedStashesRemaining()
  if gilded and gilded > 0 then return true end
  if gilded == nil then
    -- The stash widget often only updates near the Delver's Headquarters. Several
    -- T11 runs already in the vault is a strong sign the weekly stashes are done.
    local runs = self.vault and self.vault.rows and self.vault.rows.world and self.vault.rows.world.runs or {}
    local t11, cap = 0, self.tierCaps and self.tierCaps.world or 11
    for _, tier in ipairs(runs) do
      if tier >= cap then t11 = t11 + 1 end
    end
    if t11 < 4 then return true end
  end
  return false
end

function LS:WeeklyResetKey()
  local now = (GetServerTime and GetServerTime()) or (time and time()) or 0
  local untilReset = Safe(C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset)
  if type(untilReset) == "number" then
    return tostring(math.floor((now + untilReset) / 604800))
  end
  return tostring(math.floor(now / 604800))
end

function LS:HasUnclaimedVault()
  if Safe(C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards) then return true end
  if Safe(C_WeeklyRewards and C_WeeklyRewards.HasGeneratedRewards) then return true end
  if Safe(C_WeeklyRewards and C_WeeklyRewards.CanClaimRewards) then return true end
  return false
end

function LS:OpenGreatVault()
  if self.ClientFrameShown and self:ClientFrameShown("WeeklyRewardsFrame") then
    self:HideClientFrame(_G.WeeklyRewardsFrame)
    return
  end
  if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
  elseif LoadAddOn then
    pcall(LoadAddOn, "Blizzard_WeeklyRewards")
  end
  local frame = _G.WeeklyRewardsFrame
  if frame then
    if ShowUIPanel then
      pcall(ShowUIPanel, frame)
    else
      frame:Show()
    end
    if self.FrontClientFrame then self:FrontClientFrame(frame) end
  end
  if C_WeeklyRewards and C_WeeklyRewards.OnUIInteract then
    pcall(C_WeeklyRewards.OnUIInteract)
  end
end
