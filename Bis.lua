local _, LS = ...

-- SpecBiS Tooltip keeps its data in its private addon table, so the only thing
-- another addon can read is what it writes into item tooltips. Every SpecBiS line
-- ends with its own icon (136031), and its "is BiS" labels use one fixed green.
local SBT_ICON = "136031"
local SBT_GREEN = "|cff90ee90"
local SCAN_NAME = "LodestarSpecBisScan"

local function Readable(text)
  if text == nil then return false end
  if canaccessvalue and not canaccessvalue(text) then return false end
  if issecretvalue and issecretvalue(text) then return false end
  return type(text) == "string"
end

local function Plain(text)
  if not Readable(text) then return "" end
  text = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return (text:gsub("^%s*(.-)%s*$", "%1"))
end

function LS:HasSpecBisTooltip()
  if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SpecBisTooltip")) then
    return false
  end
  return TooltipDataProcessor ~= nil and CreateFrame ~= nil
end

local scanTip
local function ScanTip()
  if scanTip then return scanTip end
  if not CreateFrame then return end
  local ok, tip = pcall(CreateFrame, "GameTooltip", SCAN_NAME, nil, "GameTooltipTemplate")
  if not ok or not tip then return end
  if tip.SetOwner and WorldFrame then tip:SetOwner(WorldFrame, "ANCHOR_NONE") end
  scanTip = tip
  return tip
end

local function SpecKey()
  local spec = GetSpecialization and GetSpecialization() or 0
  local content = SBTTAB and SBTTAB.PREFERREDCONTENT or "BISO"
  return tostring(spec) .. ":" .. tostring(content)
end

-- Source text reads "Source: Boss (Location)[Drop]". The label is localized, so
-- everything up to the first colon goes.
local function SourceFromRight(right)
  local text = Plain(right)
  if text == "" then return nil end
  local after = text:match("^[^:]+:%s*(.+)$")
  text = after or text
  text = text:gsub("%[[^%]]*%]%s*$", ""):gsub("%s+", " ")
  text = text:gsub("^%s*(.-)%s*$", "%1")
  if text == "" then return nil end
  return text
end

local cache = {}

function LS:ClearSpecBisCache()
  cache = {}
end

function LS:GetSpecBisSlotStatus(slotID)
  if not self:HasSpecBisTooltip() then return end
  local itemID = GetInventoryItemID and GetInventoryItemID("player", slotID)
  if not itemID then
    return { slot = slotID, status = "empty" }
  end
  local key = slotID .. ":" .. itemID .. ":" .. SpecKey()
  if cache[key] then return cache[key] end

  local tip = ScanTip()
  if not tip then return end
  if tip.ClearLines then tip:ClearLines() end
  if tip.SetOwner and WorldFrame then tip:SetOwner(WorldFrame, "ANCHOR_NONE") end
  if not pcall(tip.SetInventoryItem, tip, "player", slotID) then return end

  local lines = tip.NumLines and tip:NumLines() or 0
  local found, isBis, source, bisItemID = false, false, nil, nil
  for i = 1, lines do
    local left = _G[SCAN_NAME .. "TextLeft" .. i]
    local right = _G[SCAN_NAME .. "TextRight" .. i]
    local lt = left and left.GetText and left:GetText()
    local rt = right and right.GetText and right:GetText()
    if Readable(rt) and rt:find(SBT_ICON, 1, true) then
      if not found then
        found = true
        source = SourceFromRight(rt)
        local id = Readable(lt) and tonumber(Plain(lt):match(":%s*(%d+)%s*$"))
        if id then bisItemID = id end
      elseif Readable(lt) and lt:find(SBT_GREEN, 1, true) then
        isBis = true
      end
    end
  end
  if tip.Hide then tip:Hide() end
  if not found then return end

  local row = {
    slot = slotID,
    equippedId = itemID,
    status = isBis and "bis" or "upgrade",
    source = source,
    bisItemId = bisItemID,
  }
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if bisItemID and info then
    local ok, name = pcall(info, bisItemID)
    if ok then row.bisName = name end
  end
  cache[key] = row
  return row
end

function LS:GetSpecBisSummary()
  if not self:HasSpecBisTooltip() then return end
  local bis, upgrade, empty, total = 0, 0, 0, 0
  local rows = {}
  for _, slotID in ipairs(self.GEAR_SLOTS or {}) do
    local row = self:GetSpecBisSlotStatus(slotID)
    if row then
      rows[slotID] = row
      total = total + 1
      if row.status == "bis" then bis = bis + 1
      elseif row.status == "upgrade" then upgrade = upgrade + 1
      elseif row.status == "empty" then empty = empty + 1 end
    end
  end
  if total == 0 then return end
  return { bis = bis, upgrade = upgrade, empty = empty, total = total, slots = rows }
end

function LS:SpecBisSourceText(row)
  if not row or not row.source then return "" end
  local src = row.source:gsub("%s*|%s*", "/"):gsub("%s*%(Raid%)", ""):gsub("%s+", " ")
  return (src:gsub("^%s*(.-)%s*$", "%1"))
end

-- One row per slot in armory order: what you wear, whether it is BiS, and where
-- the BiS piece for that slot comes from.
function LS:SpecBisListRows()
  if not self:HasSpecBisTooltip() then return {} end
  local order = {}
  for _, list in ipairs({ self.GEAR_ARMORY_LEFT, self.GEAR_ARMORY_RIGHT, self.GEAR_ARMORY_WEAPONS }) do
    for _, slotID in ipairs(list or {}) do table.insert(order, slotID) end
  end
  local out, seen = {}, {}
  for _, slotID in ipairs(order) do
    if not seen[slotID] then
      seen[slotID] = true
      local row = self:GetSpecBisSlotStatus(slotID)
      if row and row.status ~= "empty" then
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slotID)
        local name, quality, icon
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        if link and info then
          local ok, n, _, q, _, _, _, _, _, _, tex = pcall(info, link)
          if ok then name, quality, icon = n, q, tex end
        end
        if GetInventoryItemTexture then icon = GetInventoryItemTexture("player", slotID) or icon end
        if GetInventoryItemQuality then quality = GetInventoryItemQuality("player", slotID) or quality end
        table.insert(out, {
          slot = slotID,
          itemID = row.equippedId,
          name = name or ((self.GEAR_SLOT_LABELS and self.GEAR_SLOT_LABELS[slotID]) or "Slot"),
          quality = quality,
          icon = icon,
          status = row.status,
          bisName = row.bisName,
          source = self:SpecBisSourceText(row),
        })
      end
    end
  end
  return out
end

function LS:SpecBisUpgradeRows()
  local summary = self:GetSpecBisSummary()
  if not summary then return {} end
  local out = {}
  for _, slotID in ipairs(self.GEAR_SLOTS or {}) do
    local row = summary.slots[slotID]
    if row and row.status == "upgrade" then
      local label = (self.GEAR_SLOT_LABELS and self.GEAR_SLOT_LABELS[slotID]) or ("Slot " .. slotID)
      table.insert(out, {
        slot = slotID,
        label = label,
        bisName = row.bisName,
        source = self:SpecBisSourceText(row),
      })
    end
  end
  table.sort(out, function(a, b) return a.label < b.label end)
  return out
end
