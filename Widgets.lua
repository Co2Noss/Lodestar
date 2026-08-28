local _, LS = ...

-- Extra dashboard tiles. Mythic+ and gold read the client. Raider.IO colours
-- Mythic+ when it is loaded. Currency and PvP are always available.

function LS:RecordAccountGold()
  if not self.db then return end
  local copper = self.WarbandGold and self:WarbandGold() or (GetMoney and tonumber(GetMoney())) or 0
  if not copper or copper <= 0 then return end
  self.db.goldHistory = self.db.goldHistory or {}
  local last = self.db.goldHistory[#self.db.goldHistory]
  if last and last.p == copper then return end
  table.insert(self.db.goldHistory, { t = time and time() or 0, p = copper })
  while #self.db.goldHistory > 32 do
    table.remove(self.db.goldHistory, 1)
  end
end

function LS:RaiderIOProfile()
  if not (RaiderIO and RaiderIO.GetProfile) then return end
  local name = UnitName and UnitName("player")
  local realm = GetRealmName and GetRealmName()
  if not name then return end
  local ok, profile = pcall(RaiderIO.GetProfile, name, realm)
  if not ok then ok, profile = pcall(RaiderIO.GetProfile, "player") end
  if not ok or type(profile) ~= "table" then return end
  local mplus = profile.mythicKeystoneProfile
  if type(mplus) ~= "table" or mplus.hasRenderableData == false then return end
  return mplus
end

function LS:SeasonDungeonMaps()
  if not (C_ChallengeMode and C_ChallengeMode.GetMapTable) then return {} end
  local ok, maps = pcall(C_ChallengeMode.GetMapTable)
  if not ok or type(maps) ~= "table" then return {} end
  local out = {}
  for _, mapID in ipairs(maps) do
    if type(mapID) == "table" then
      mapID = mapID.id or mapID.mapID or mapID.challengeMapID
    end
    if tonumber(mapID) then table.insert(out, tonumber(mapID)) end
  end
  return out
end

function LS:SeasonBestKeyLevel(mapID)
  if C_MythicPlus and C_MythicPlus.GetSeasonBestForMap then
    local ok, intime, overtime = pcall(C_MythicPlus.GetSeasonBestForMap, mapID)
    if ok then
      local a = type(intime) == "table" and tonumber(intime.level) or tonumber(intime)
      local b = type(overtime) == "table" and tonumber(overtime.level) or tonumber(overtime)
      if a and b then return math.max(a, b) end
      if a or b then return a or b end
    end
  end
  if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
    if ok and type(summary) == "table" then
      for _, run in ipairs(summary.runs or {}) do
        local id = run.challengeModeID or run.mapChallengeModeID or run.mapID
        if id == mapID then
          return tonumber(run.bestRunLevel or run.level)
        end
      end
    end
  end
  local mplus = self:RaiderIOProfile()
  for _, row in ipairs((mplus and mplus.sortedDungeons) or {}) do
    local dungeon = row.dungeon or row
    local id = dungeon.id or dungeon.mapId or dungeon.challengeMapId
    if id == mapID then return tonumber(row.level or dungeon.level) end
  end
end

function LS:KeyLevelColor(level)
  if C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor then
    local ok, color = pcall(C_ChallengeMode.GetKeystoneLevelRarityColor, level)
    if ok and type(color) == "table" then
      if color.GetRGB then
        local r, g, b = color:GetRGB()
        if r then return r, g, b end
      end
      if color.r then return color.r, color.g, color.b end
    end
    if ok and type(color) == "number" then
      return color, select(2, C_ChallengeMode.GetKeystoneLevelRarityColor(level))
    end
  end
  if RaiderIO and RaiderIO.GetScoreColor then
    local ok, r, g, b = pcall(RaiderIO.GetScoreColor, (tonumber(level) or 0) * 150)
    if ok then return r, g, b end
  end
  local tone = self.colors and self.colors.accent or { 1, 0.82, 0 }
  return tone[1], tone[2], tone[3]
end

function LS:MythicPlusScore()
  local mplus = self:RaiderIOProfile()
  if mplus and tonumber(mplus.currentScore) then
    return tonumber(mplus.currentScore), "raiderio"
  end
  if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
    local ok, score = pcall(C_ChallengeMode.GetOverallDungeonScore)
    score = ok and tonumber(score)
    if score then return score, "blizzard" end
  end
  if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
    if ok and type(summary) == "table" then
      local score = tonumber(summary.currentSeasonScore)
      if score then return score, "blizzard" end
    end
  end
  return 0
end

function LS:MythicPlusScoreColor(score)
  if RaiderIO and RaiderIO.GetScoreColor then
    local ok, r, g, b = pcall(RaiderIO.GetScoreColor, score)
    if ok and r then return r, g, b end
  end
  if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
    local ok, color = pcall(C_ChallengeMode.GetDungeonScoreRarityColor, score)
    if ok and type(color) == "table" then
      if color.GetRGB then
        local r, g, b = color:GetRGB()
        if r then return r, g, b end
      end
      if color.r then return color.r, color.g, color.b end
    end
  end
  local tone = self.colors and self.colors.accent or { 1, 0.82, 0 }
  return tone[1], tone[2], tone[3]
end

function LS:CurrencyCatalog()
  local out = {}
  if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize) then return out end
  local n = tonumber(C_CurrencyInfo.GetCurrencyListSize()) or 0
  local expansion = GetExpansionLevel and GetExpansionLevel()
  local expansionName = expansion and _G["EXPANSION_NAME" .. tostring(expansion)]
  local inCurrent, seenHeader = false, false
  local group
  for i = 1, n do
    local info = C_CurrencyInfo.GetCurrencyListInfo(i)
    if type(info) == "table" then
      if info.isHeader then
        seenHeader = true
        group = info.name
        inCurrent = expansionName and info.name
          and info.name:find(expansionName, 1, true) and true or false
      elseif not info.isTypeUnused and info.discovered ~= false then
        local id = info.currencyTypesID or info.currencyID
        if not id and C_CurrencyInfo.GetCurrencyListLink then
          local link = C_CurrencyInfo.GetCurrencyListLink(i)
          if type(link) == "string" and C_CurrencyInfo.GetCurrencyIDFromLink then
            id = C_CurrencyInfo.GetCurrencyIDFromLink(link)
          end
        end
        if id then
          table.insert(out, {
            id = id,
            name = info.name or ("Currency " .. tostring(id)),
            quantity = tonumber(info.quantity) or 0,
            icon = info.iconFileID or info.icon,
            quality = info.quality,
            current = inCurrent or not seenHeader,
            group = group,
          })
        end
      end
    end
  end
  return out
end

local function LiveCurrency(row)
  if not row or not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return row end
  local live = C_CurrencyInfo.GetCurrencyInfo(row.id)
  if type(live) ~= "table" then return row end
  if live.quantity ~= nil then row.quantity = live.quantity end
  row.icon = live.iconFileID or live.icon or row.icon
  if live.quality ~= nil then row.quality = live.quality end
  if live.name and live.name ~= "" then row.name = live.name end
  return row
end

function LS:TrackedCurrencies()
  local catalog = self:CurrencyCatalog()
  local opts = self:WidgetOpts("currency")
  local chosen = opts.ids
  local out = {}
  if type(chosen) == "table" then
    local want = {}
    for _, id in ipairs(chosen) do want[id] = true end
    for _, row in ipairs(catalog) do
      if want[row.id] then table.insert(out, LiveCurrency(row)) end
    end
    return out
  end
  for _, row in ipairs(catalog) do
    if row.current then table.insert(out, LiveCurrency(row)) end
  end
  if #out == 0 then
    for i = 1, math.min(4, #catalog) do table.insert(out, LiveCurrency(catalog[i])) end
  end
  return out
end

-- Which currencies are ticked. No stored list means the default, this expansion.
function LS:CurrencyTracked(id)
  local opts = self:WidgetOpts("currency")
  local chosen = opts.ids
  if type(chosen) == "table" then
    for _, entry in ipairs(chosen) do
      if entry == id then return true end
    end
    return false
  end
  for _, row in ipairs(self:CurrencyCatalog()) do
    if row.id == id then return row.current and true or false end
  end
  return false
end

-- Stored in catalog order rather than click order, so the tile does not reshuffle
-- itself every time something is ticked.
function LS:SetCurrencyTracked(id, on)
  local catalog = self:CurrencyCatalog()
  local selected = {}
  for _, row in ipairs(catalog) do
    selected[row.id] = self:CurrencyTracked(row.id)
  end
  selected[id] = on and true or false
  local ids = {}
  for _, row in ipairs(catalog) do
    if selected[row.id] then table.insert(ids, row.id) end
  end
  self:SetWidgetOpt("currency", "ids", ids)
end

-- Back to the default: track this expansion, decided live rather than frozen now.
function LS:ResetTrackedCurrencies()
  self:SetWidgetOpt("currency", "ids", nil)
end

local function PaintCurrencyIcon(parent, icon, x, y, size)
  size = size or 16
  if icon == nil or icon == false or icon == 0 or icon == "" then return 0 end
  local art = parent:CreateTexture(nil, "ARTWORK")
  art:SetSize(size, size)
  art:SetPoint("TOPLEFT", x, y)
  if art.SetTexture then pcall(art.SetTexture, art, icon) end
  return size
end

local function Hit(parent, x, y, w, h)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetPoint("TOPLEFT", x, y)
  frame:SetSize(math.max(8, w), math.max(8, h))
  frame:EnableMouse(true)
  return frame
end

-- UseContainerItem is protected. Addon Lua cannot call it, even from OnMouseUp.
-- A SecureActionButton uses the bag slot from the click itself.
local function SecureItemHit(parent, x, y, w, h, bag, slot)
  local frame
  local ok, created = pcall(CreateFrame, "Button", nil, parent, "SecureActionButtonTemplate")
  if ok and created then
    frame = created
  else
    frame = CreateFrame("Button", nil, parent)
  end
  frame:SetPoint("TOPLEFT", x, y)
  frame:SetSize(math.max(8, w), math.max(8, h))
  frame:EnableMouse(true)
  if frame.RegisterForClicks then
    pcall(frame.RegisterForClicks, frame, "AnyDown", "AnyUp")
  end
  local lockdown = InCombatLockdown and InCombatLockdown()
  if not lockdown and frame.SetAttribute then
    if bag ~= nil and slot ~= nil then
      pcall(frame.SetAttribute, frame, "type", "item")
      pcall(frame.SetAttribute, frame, "item", string.format("%d %d", bag, slot))
      pcall(frame.SetAttribute, frame, "bag", bag)
      pcall(frame.SetAttribute, frame, "slot", slot)
    else
      pcall(frame.SetAttribute, frame, "type", nil)
      pcall(frame.SetAttribute, frame, "item", nil)
      pcall(frame.SetAttribute, frame, "bag", nil)
      pcall(frame.SetAttribute, frame, "slot", nil)
    end
  end
  return frame
end

-- CastSpellByName is protected the same way. Keystone Hero ports use type=spell.
local function SecureSpellHit(parent, x, y, w, h, spellName)
  local frame
  local ok, created = pcall(CreateFrame, "Button", nil, parent, "SecureActionButtonTemplate")
  if ok and created then
    frame = created
  else
    frame = CreateFrame("Button", nil, parent)
  end
  frame:SetPoint("TOPLEFT", x, y)
  frame:SetSize(math.max(8, w), math.max(8, h))
  frame:EnableMouse(true)
  if frame.RegisterForClicks then
    pcall(frame.RegisterForClicks, frame, "AnyDown", "AnyUp")
  end
  local lockdown = InCombatLockdown and InCombatLockdown()
  if not lockdown and frame.SetAttribute then
    if type(spellName) == "string" and spellName ~= "" then
      pcall(frame.SetAttribute, frame, "type", "spell")
      pcall(frame.SetAttribute, frame, "spell", spellName)
    else
      pcall(frame.SetAttribute, frame, "type", nil)
      pcall(frame.SetAttribute, frame, "spell", nil)
    end
  end
  return frame
end

local function PaintFillBar(self, parent, x, y, width, height, fill)
  fill = math.max(0, math.min(1, tonumber(fill) or 0))
  height = math.max(6, tonumber(height) or 8)
  width = math.max(8, tonumber(width) or 8)
  local bg = parent:CreateTexture(nil, "ARTWORK")
  bg:SetSize(width, height)
  bg:SetPoint("TOPLEFT", x, y)
  bg.progressTrack = true
  if bg.SetColorTexture then
    local c = self.colors and (self.colors.panel or self.colors.card) or { 0.12, 0.12, 0.14 }
    bg:SetColorTexture(c[1], c[2], c[3], 1)
  end
  local inner = math.max(0, math.floor((width - 2) * fill + 0.5))
  if inner > 0 then
    local bar = parent:CreateTexture(nil, "ARTWORK")
    bar:SetSize(inner, math.max(2, height - 2))
    bar:SetPoint("TOPLEFT", x + 1, y - 1)
    bar.progressFill = fill
    if bar.SetColorTexture then
      local a = self.colors and self.colors.accent or { 0.35, 0.85, 0.79 }
      bar:SetColorTexture(a[1], a[2], a[3], 1)
    end
  end
  return height
end

-- Saturated red that still reads on ElvUI's near-black cards. Theme warn is for
-- copy and is often too muted on dark palettes; Blizzard's warn already pops.
function LS:MissingEnchantColor()
  return 1, 0.18, 0.12
end

local function PaintIconBorder(parent, art, size, r, g, b)
  local t = math.max(2, math.min(3, math.floor(size * 0.10 + 0.5)))
  local function edge(w, h, point)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetSize(w, h)
    tex:SetPoint(point, art, point, 0, 0)
    if tex.SetDrawLayer then tex:SetDrawLayer("OVERLAY", 2) end
    if tex.SetColorTexture then tex:SetColorTexture(r, g, b, 1) end
    tex.missingEnchant = true
  end
  edge(size, t, "TOPLEFT")
  edge(size, t, "BOTTOMLEFT")
  edge(t, size, "TOPLEFT")
  edge(t, size, "TOPRIGHT")
end

-- The key you are carrying, under the dungeon grid. Read from the client, so it does
-- not need Astral Keys or any other keystone addon to be loaded. Hovering shows the
-- real item tooltip and clicking links it, the same as the keystone in your bags.
local KEY_LINE_H = 26

local function PaintKeystoneLine(self, parent, width)
  local w = self.widgets
  local label, _, level = self:KeystoneLabel()

  local caption = w.text(parent, width - 12, 9)
  if caption.ClearAllPoints then caption:ClearAllPoints() end
  caption:SetPoint("BOTTOM", 0, 15)
  if caption.SetJustifyH then caption:SetJustifyH("CENTER") end
  if self.colors then caption:SetTextColor(unpack(self.colors.muted)) end
  caption:SetText(label and "Current Keystone" or "No Current Keystone")

  local line = w.text(parent, width - 12, 11)
  if line.ClearAllPoints then line:ClearAllPoints() end
  line:SetPoint("BOTTOM", 0, 3)
  if line.SetJustifyH then line:SetJustifyH("CENTER") end
  if label then
    line:SetText(label)
    local r, g, b = self:KeyLevelColor(level)
    if r then line:SetTextColor(r, g, b, 1) end
  else
    line:SetText("Nothing in your bags")
    if self.colors then line:SetTextColor(unpack(self.colors.muted)) end
  end

  local hit = Hit(parent, 6, -(math.max(0, (parent:GetHeight() or KEY_LINE_H) - KEY_LINE_H)), width - 12, KEY_LINE_H)
  if hit.ClearAllPoints then
    hit:ClearAllPoints()
    hit:SetPoint("BOTTOMLEFT", 6, 0)
    hit:SetPoint("BOTTOMRIGHT", -6, 0)
    hit:SetHeight(KEY_LINE_H)
  end
  hit.text = { text_value = label or "No keystone" }
  self:HoverTip(hit, function(tip)
    self:FillKeystoneTooltip(tip)
  end)
  hit:SetScript("OnMouseUp", function()
    if self.HideWidgetTip then self:HideWidgetTip() end
    if self:LinkKeystoneToChat() then return end
    if self.OpenMythicPlus then self:OpenMythicPlus() end
  end)
  return line, hit
end

LS.GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
LS.GEAR_SLOT_LABELS = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest",
  [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist",
  [10] = "Hands", [11] = "Finger", [12] = "Finger", [13] = "Trinket",
  [14] = "Trinket", [15] = "Back", [16] = "Main Hand", [17] = "Off Hand",
}

-- Permanent enchants this expansion. Matches the client's item-link enchant
-- field and the slot map Enchant Me uses for Midnight (helm, shoulder, chest,
-- legs, feet, rings, weapons). Wrist and back do not take enchants. Off-hand
-- only flags weapons, not shields or held-in-off-hand.
LS.ENCHANT_SLOTS = {
  [1] = true, [3] = true, [5] = true, [7] = true, [8] = true,
  [11] = true, [12] = true, [16] = true, [17] = true,
}

local OFFHAND_WEAPON = {
  INVTYPE_WEAPON = true,
  INVTYPE_2HWEAPON = true,
  INVTYPE_WEAPONOFFHAND = true,
}

local SOCKET_CAUTION = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"

local INVTYPE_SLOTS = {
  INVTYPE_HEAD = { 1 },
  INVTYPE_NECK = { 2 },
  INVTYPE_SHOULDER = { 3 },
  INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16, 17 },
  INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_HOLDABLE = { 17 },
  INVTYPE_SHIELD = { 17 },
  INVTYPE_RANGED = { 16 },
  INVTYPE_RANGEDRIGHT = { 16 },
}

local function ItemLevelOf(link, loc)
  if loc and C_Item and C_Item.GetCurrentItemLevel and C_Item.DoesItemExist then
    local okExist, exists = pcall(C_Item.DoesItemExist, loc)
    if okExist and exists then
      local ok, level = pcall(C_Item.GetCurrentItemLevel, loc)
      if ok and tonumber(level) then return tonumber(level) end
    end
  end
  if link and C_Item and C_Item.GetDetailedItemLevelInfo then
    local ok, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
    if ok and tonumber(level) then return tonumber(level) end
  end
  if link and GetDetailedItemLevelInfo then
    local ok, level = pcall(GetDetailedItemLevelInfo, link)
    if ok and tonumber(level) then return tonumber(level) end
  end
  if link and GetItemInfo then
    local ok, _, _, _, level = pcall(GetItemInfo, link)
    if ok and tonumber(level) then return tonumber(level) end
  end
end

local function ItemInfo(link)
  if not link or not GetItemInfo then return end
  local ok, name, _, quality, level, _, _, _, _, equipLoc, texture = pcall(GetItemInfo, link)
  if not ok then return end
  return name, quality, level, equipLoc, texture
end

local function ItemLinkFields(link)
  if type(link) ~= "string" then return end
  local payload = link:match("[Hh]?item:([^|]+)")
  if not payload then return end
  local fields, i = {}, 1
  for part in string.gmatch(payload .. ":", "([^:]*):") do
    fields[i] = part
    i = i + 1
  end
  return fields
end

local function TooltipLines(slot)
  if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return end
  local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
  if not ok or type(data) ~= "table" then return end
  return data.lines or data.lineData
end

local function LineType(line)
  return line and (line.type or line.lineType)
end

function LS:ItemEnchantID(link)
  local fields = ItemLinkFields(link)
  if not fields then return end
  return tonumber(fields[2]) or 0
end

-- Gems live in item-link fields 3–6. Zero and empty mean no gem; a filled id
-- means the socket is occupied even when GetItemStats still lists EMPTY_SOCKET.
function LS:ItemGemCount(link)
  local fields = ItemLinkFields(link)
  if not fields then return 0 end
  local n = 0
  for i = 3, 6 do
    local id = tonumber(fields[i])
    if id and id > 0 then n = n + 1 end
  end
  return n
end

function LS:SlotMissingEnchant(piece)
  if not piece or not piece.link then return false end
  if not self.ENCHANT_SLOTS[piece.slot] then return false end
  if piece.slot == 17 and not OFFHAND_WEAPON[piece.equipLoc] then return false end
  local enchantType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
  local lines = TooltipLines(piece.slot)
  if lines and #lines > 0 and enchantType then
    for _, line in ipairs(lines) do
      if LineType(line) == enchantType then return false end
    end
    return true
  end
  return (self:ItemEnchantID(piece.link) or 0) == 0
end

function LS:SlotEmptySocket(piece)
  if not piece or not piece.link then return false end
  local gems = self:ItemGemCount(piece.link)
  -- A gemmed ring is left alone: stats often still report EMPTY_SOCKET.
  if (piece.slot == 11 or piece.slot == 12) and gems > 0 then
    return false
  end
  local sockets = 0
  local socketType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.GemSocket
  local lines = TooltipLines(piece.slot)
  if lines and socketType then
    for _, line in ipairs(lines) do
      if LineType(line) == socketType then
        sockets = sockets + 1
        if not (line.gemIcon or line.icon or tonumber(line.gemID)) and gems == 0 then
          return true
        end
      end
    end
  end
  local stats
  if C_Item and C_Item.GetItemStats then
    local ok, result = pcall(C_Item.GetItemStats, piece.link)
    if ok then stats = result end
  end
  if type(stats) ~= "table" and GetItemStats then
    local ok, result = pcall(GetItemStats, piece.link)
    if ok then stats = result end
  end
  if type(stats) == "table" then
    local fromStats = 0
    for key, n in pairs(stats) do
      if type(key) == "string" and key:find("EMPTY_SOCKET", 1, true) then
        fromStats = fromStats + (tonumber(n) or 0)
      end
    end
    sockets = math.max(sockets, fromStats)
  end
  return gems < sockets
end

function LS:EquippedGear()
  local out = {}
  for _, slot in ipairs(self.GEAR_SLOTS) do
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    local loc
    if ItemLocation and ItemLocation.CreateFromEquipmentSlot then
      local ok, created = pcall(function() return ItemLocation:CreateFromEquipmentSlot(slot) end)
      if ok then loc = created end
    end
    local name, quality, level, equipLoc, texture = ItemInfo(link)
    quality = GetInventoryItemQuality and GetInventoryItemQuality("player", slot) or quality
    texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot) or texture
    table.insert(out, {
      slot = slot,
      link = link,
      name = name,
      quality = tonumber(quality),
      ilvl = ItemLevelOf(link, loc) or tonumber(level),
      icon = texture,
      equipLoc = equipLoc,
    })
    local piece = out[#out]
    piece.missingEnchant = self:SlotMissingEnchant(piece)
    piece.emptySocket = self:SlotEmptySocket(piece)
  end
  return out
end

local function AverageGear(pieces)
  local sum, count, qSum, qCount = 0, 0, 0, 0
  for _, piece in ipairs(pieces or {}) do
    if piece.ilvl then
      sum = sum + piece.ilvl
      count = count + 1
    end
    if piece.quality then
      qSum = qSum + piece.quality
      qCount = qCount + 1
    end
  end
  if count == 0 then return end
  return sum / count, qCount > 0 and math.floor((qSum / qCount) + 0.5) or nil
end

function LS:BagBestGear(equipped)
  equipped = equipped or self:EquippedGear()
  local best = {}
  for _, piece in ipairs(equipped) do
    best[piece.slot] = piece.ilvl or 0
  end
  local quality = {}
  local function consider(link, loc)
    local name, q, level, equipLoc, texture = ItemInfo(link)
    local ilvl = ItemLevelOf(link, loc) or tonumber(level)
    if not ilvl or not equipLoc then return end
    local slots = INVTYPE_SLOTS[equipLoc]
    if not slots then return end
    local target
    for _, slot in ipairs(slots) do
      if not target or (best[slot] or 0) < (best[target] or 0) then
        target = slot
      end
    end
    if target and ilvl > (best[target] or 0) then
      best[target] = ilvl
      quality[target] = tonumber(q)
    end
  end
  local bags = NUM_BAG_SLOTS or NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
  for bag = 0, bags do
    local n
    if C_Container and C_Container.GetContainerNumSlots then
      n = C_Container.GetContainerNumSlots(bag)
    elseif GetContainerNumSlots then
      n = GetContainerNumSlots(bag)
    end
    n = tonumber(n) or 0
    for slot = 1, n do
      local link
      if C_Container and C_Container.GetContainerItemLink then
        link = C_Container.GetContainerItemLink(bag, slot)
      elseif GetContainerItemLink then
        link = GetContainerItemLink(bag, slot)
      end
      local loc
      if ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local ok, created = pcall(function()
          return ItemLocation:CreateFromBagAndSlot(bag, slot)
        end)
        if ok then loc = created end
      end
      consider(link, loc)
    end
  end
  local pieces = {}
  for _, slot in ipairs(self.GEAR_SLOTS) do
    local equippedPiece
    for _, piece in ipairs(equipped) do
      if piece.slot == slot then equippedPiece = piece break end
    end
    table.insert(pieces, {
      slot = slot,
      ilvl = best[slot] ~= 0 and best[slot] or (equippedPiece and equippedPiece.ilvl),
      quality = quality[slot] or (equippedPiece and equippedPiece.quality),
    })
  end
  return AverageGear(pieces)
end

function LS:PlayerItemLevels()
  local equipped = self:EquippedGear()
  local equippedAvg, equippedQuality = AverageGear(equipped)
  local apiTotal, apiEquipped
  if GetAverageItemLevel then
    apiTotal, apiEquipped = GetAverageItemLevel()
  end
  equippedAvg = tonumber(apiEquipped) or equippedAvg
  local bagAvg, bagQuality = self:BagBestGear(equipped)
  if tonumber(apiTotal) and equippedAvg and tonumber(apiTotal) > equippedAvg + 0.05 then
    bagAvg = tonumber(apiTotal)
  end
  bagAvg = bagAvg or equippedAvg
  bagQuality = bagQuality or equippedQuality
  return {
    equipped = equippedAvg,
    bags = bagAvg,
    equippedQuality = equippedQuality,
    bagsQuality = bagQuality,
    slots = equipped,
  }
end

local function RoundIlvl(n)
  n = tonumber(n)
  if not n then return "—" end
  return tostring(math.floor(n + 0.5))
end

local function SafeExtra(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g, h, i end
end

local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function DaysInMonth(year, month)
  if month == 2 and year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
    return 29
  end
  return MONTH_DAYS[month] or 30
end

local function ShiftCalendarDay(now, delta)
  local year, month, day = now.year, now.month, now.monthDay + delta
  while day > DaysInMonth(year, month) do
    day = day - DaysInMonth(year, month)
    month = month + 1
    if month > 12 then month, year = 1, year + 1 end
  end
  while day < 1 do
    month = month - 1
    if month < 1 then month, year = 12, year - 1 end
    day = day + DaysInMonth(year, month)
  end
  return (year - now.year) * 12 + (month - now.month), day
end

function LS:CalendarNow()
  local t = SafeExtra(C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime)
  if type(t) == "table" and tonumber(t.monthDay) then return t end
end

local function CalendarKind(ev)
  local cal = string.lower(tostring(ev.calendarType or ""))
  if cal == "guild" or cal == "guild_event" or cal == "community_event" or cal == "communityevent" then
    return "guild"
  end
  if cal == "player" then return "invite" end
  if cal == "holiday" or cal == "system" then return "holiday" end
  if type(ev.invitedBy) == "string" and ev.invitedBy ~= "" then return "invite" end
  return "other"
end

function LS:CalendarEventsForDays(startDelta, count)
  local now = self:CalendarNow()
  if not now or not (C_Calendar and C_Calendar.GetNumDayEvents) then return {} end
  SafeExtra(C_Calendar.OpenCalendar)
  local out, seen = {}, {}
  for i = 0, count - 1 do
    local offset, day = ShiftCalendarDay(now, startDelta + i)
    local n = tonumber(SafeExtra(C_Calendar.GetNumDayEvents, offset, day)) or 0
    for idx = 1, n do
      local ev = SafeExtra(C_Calendar.GetDayEvent, offset, day, idx)
      if type(ev) == "table" and type(ev.title) == "string" and ev.title ~= "" then
        local seq = string.upper(tostring(ev.sequenceType or ""))
        if seq ~= "END" then
          local kind = CalendarKind(ev)
          local key = kind == "holiday" and ("h:" .. ev.title) or (tostring(ev.eventID or ev.title) .. ":" .. day)
          if not seen[key] then
            seen[key] = true
            table.insert(out, { title = ev.title, kind = kind, day = day })
          end
        end
      end
    end
  end
  local gn = tonumber(SafeExtra(C_Calendar.GetNumGuildEvents)) or 0
  for idx = 1, gn do
    local ev = SafeExtra(C_Calendar.GetGuildEventInfo, idx)
    if type(ev) == "table" and type(ev.title) == "string" and ev.title ~= "" then
      local key = "g:" .. tostring(ev.eventID or ev.title)
      if not seen[key] then
        seen[key] = true
        table.insert(out, { title = ev.title, kind = "guild", day = tonumber(ev.monthDay) })
      end
    end
  end
  return out
end

function LS:CalendarWeeks()
  local now = self:CalendarNow()
  if not now then return { thisWeek = {}, nextWeek = {} } end
  local back = (tonumber(now.weekday) or 1) - 1
  return {
    thisWeek = self:CalendarEventsForDays(-back, 7),
    nextWeek = self:CalendarEventsForDays(-back + 7, 7),
  }
end

function LS:OpenCalendar()
  if self.ClientFrameShown and self:ClientFrameShown("CalendarFrame") then
    self:HideClientFrame(_G.CalendarFrame)
    return true
  end
  SafeExtra(C_Calendar and C_Calendar.OpenCalendar)
  if self.OpenClientFrame and self:OpenClientFrame("Blizzard_Calendar", "CalendarFrame") then
    return true
  end
  if ToggleCalendar then
    pcall(ToggleCalendar)
    if self.FrontClientFrame then self:FrontClientFrame(_G.CalendarFrame) end
    return true
  end
  return false
end

function LS:GuildSummary()
  local inGuild = SafeExtra(IsInGuild)
  if not inGuild then return { inGuild = false } end
  local name, rankName = SafeExtra(GetGuildInfo, "player")
  if type(name) ~= "string" or name == "" then name = nil end
  if type(rankName) ~= "string" or rankName == "" then rankName = nil end
  SafeExtra(C_GuildInfo and C_GuildInfo.GuildRoster)
  local total, online = SafeExtra(GetNumGuildMembers)
  total = tonumber(total)
  online = tonumber(online)
  if total and not online then
    online = 0
    for i = 1, total do
      local _, _, _, _, _, _, _, _, isOnline = SafeExtra(GetGuildRosterInfo, i)
      if isOnline then online = online + 1 end
    end
  end
  if not total then
    local club = SafeExtra(C_Club and C_Club.GetGuildClubId)
    if club and C_Club and C_Club.GetClubMembers then
      local members = SafeExtra(C_Club.GetClubMembers, club)
      if type(members) == "table" then
        total = #members
        online = 0
        for _, memberId in ipairs(members) do
          local info = SafeExtra(C_Club.GetMemberInfo, club, memberId)
          if type(info) == "table" and (info.isOnline or info.presence == 1) then
            online = online + 1
          end
        end
      end
    end
  end
  return { inGuild = true, name = name, rank = rankName, online = online or 0, total = total or 0 }
end

function LS:OpenCommunities()
  if self.ClientFrameShown and self:ClientFrameShown("CommunitiesFrame") then
    self:HideClientFrame(_G.CommunitiesFrame)
    return true
  end
  if self.OpenClientFrame and self:OpenClientFrame("Blizzard_Communities", "CommunitiesFrame") then
    return true
  end
  if ToggleGuildFrame then
    pcall(ToggleGuildFrame)
    if self.FrontClientFrame then self:FrontClientFrame(_G.CommunitiesFrame) end
    return true
  end
  return false
end

local function ChallengeMapName(mapID)
  if not (mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then return end
  local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
  if ok and type(name) == "string" and name ~= "" then return name end
end

local function SpellBookBank()
  return (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
end

local function IsFlyoutType(itemType)
  return itemType == "FLYOUT" or itemType == 2
    or (Enum and Enum.SpellBookItemType and itemType == Enum.SpellBookItemType.Flyout)
end

local function SpellBookSlot(slot, bank)
  local name, subName, spellID, description, itemType, flyoutID
  if C_SpellBook and C_SpellBook.GetSpellBookItemName then
    local ok, n, sub = pcall(C_SpellBook.GetSpellBookItemName, slot, bank)
    if ok then name, subName = n, sub end
  elseif GetSpellBookItemName then
    local ok, n, sub = pcall(GetSpellBookItemName, slot, bank or "spell")
    if ok then name, subName = n, sub end
  end
  if C_SpellBook and C_SpellBook.GetSpellBookItemType then
    local ok, kind, actionID, id = pcall(C_SpellBook.GetSpellBookItemType, slot, bank)
    if ok then
      itemType = kind
      if IsFlyoutType(kind) then
        flyoutID = actionID or id
      else
        spellID = id or actionID
      end
    end
  end
  if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
    if ok and type(info) == "table" then
      spellID = spellID or info.spellID
      itemType = itemType or info.itemType
      flyoutID = flyoutID or info.flyoutID or (IsFlyoutType(info.itemType) and (info.actionID or info.spellID))
    end
  end
  if C_SpellBook and C_SpellBook.GetSpellBookItemDescription then
    local ok, desc = pcall(C_SpellBook.GetSpellBookItemDescription, slot, bank)
    if ok then description = desc end
  end
  if (not description or description == "") and spellID then
    if C_Spell and C_Spell.GetSpellDescription then
      local ok, desc = pcall(C_Spell.GetSpellDescription, spellID)
      if ok then description = desc end
    elseif GetSpellDescription then
      local ok, desc = pcall(GetSpellDescription, spellID)
      if ok then description = desc end
    end
  end
  if (not name or name == "") and spellID and C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, spellID)
    if ok then name = n end
  end
  return {
    name = name,
    subName = subName,
    spellID = spellID,
    flyoutID = flyoutID,
    description = description,
    itemType = itemType,
    slot = slot,
    bank = bank,
  }
end

local function SpellMatchesDungeon(spell, dungeonName)
  if not spell or not dungeonName or dungeonName == "" then return end
  if IsFlyoutType(spell.itemType) then return end
  local function fold(s)
    s = string.lower(s or "")
    s = s:gsub("^the%s+", "")
    return s
  end
  local hay = fold((spell.description or "") .. "\n" .. (spell.name or ""))
  local needle = fold(dungeonName)
  if needle == "" then return end
  return hay:find(needle, 1, true) and true or false
end

local function FlyoutSpells(spell)
  local flyoutID = spell and (spell.flyoutID or (IsFlyoutType(spell.itemType) and spell.spellID))
  if not flyoutID or not IsFlyoutType(spell and spell.itemType) then return end
  local n
  if GetFlyoutInfo then
    local ok, _, _, numSlots = pcall(GetFlyoutInfo, flyoutID)
    if ok then n = tonumber(numSlots) end
  end
  if not n and C_Spell and C_Spell.GetFlyoutInfo then
    local ok, info = pcall(C_Spell.GetFlyoutInfo, flyoutID)
    if ok then
      if type(info) == "table" then n = tonumber(info.numSlots or info.slotCount)
      else n = tonumber(info) end
    end
  end
  n = tonumber(n) or 0
  if n <= 0 then return end
  local out = {}
  for i = 1, n do
    local id, known, spellName, description
    if GetFlyoutSlotInfo then
      local ok, spellID, _, isKnown, name = pcall(GetFlyoutSlotInfo, flyoutID, i)
      if ok then id, known, spellName = spellID, isKnown, name end
    elseif C_Spell and C_Spell.GetFlyoutSlotInfo then
      local ok, info = pcall(C_Spell.GetFlyoutSlotInfo, flyoutID, i)
      if ok and type(info) == "table" then
        id, known, spellName = info.spellID, info.isKnown, info.name
      end
    end
    if known == false then -- skip unknown
    else
      if (not description or description == "") and id and C_Spell and C_Spell.GetSpellDescription then
        local ok, desc = pcall(C_Spell.GetSpellDescription, id)
        if ok then description = desc end
      end
      if spellName or id then
        table.insert(out, {
          name = spellName,
          spellID = id,
          description = description,
          slot = spell.slot,
          bank = spell.bank,
        })
      end
    end
  end
  if #out == 0 then return end
  return out
end

local function EachPlayerSpell(fn)
  local bank = SpellBookBank()
  local seen = false
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    local ok, lines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    lines = ok and tonumber(lines) or 0
    for i = 1, lines do
      local okInfo, info, extraOffset, extraCount = pcall(C_SpellBook.GetSpellBookSkillLineInfo, i)
      if okInfo then
      local lineName
      local offset, count
      if type(info) == "table" then
        lineName = info.name
        offset = tonumber(info.itemIndexOffset) or 0
        count = tonumber(info.numSpellBookItems) or 0
      elseif type(info) == "string" then
        lineName = info
        offset = tonumber(extraOffset) or 0
        count = tonumber(extraCount) or 0
      else
        offset, count = 0, 0
      end
      for j = 1, count do
        seen = true
        if fn(SpellBookSlot(offset + j, bank), lineName) then return end
      end
      end
    end
  end
  if seen then return end
  if C_SpellBook and C_SpellBook.GetSpellBookItemName then
    for slot = 1, 400 do
      local spell = SpellBookSlot(slot, bank)
      if not spell.name or spell.name == "" then break end
      if fn(spell) then return end
    end
    return
  end
  if GetNumSpellTabs and GetSpellTabInfo then
    local tabs = tonumber(GetNumSpellTabs()) or 0
    for i = 1, tabs do
      local lineName, _, offset, count = GetSpellTabInfo(i)
      offset = tonumber(offset) or 0
      count = tonumber(count) or 0
      for j = 1, count do
        if fn(SpellBookSlot(offset + j, "spell"), lineName) then return end
      end
    end
  end
end

function LS:MythicPlusTeleports()
  local maps = self:SeasonDungeonMaps()
  local names = {}
  for _, mapID in ipairs(maps) do
    names[mapID] = ChallengeMapName(mapID)
  end
  local out = {}
  EachPlayerSpell(function(spell)
    if not spell or not spell.name then return end
    local pack = FlyoutSpells(spell) or { spell }
    for _, row in ipairs(pack) do
      for mapID, dungeonName in pairs(names) do
        if not out[mapID] and SpellMatchesDungeon(row, dungeonName) then
          out[mapID] = row
        end
      end
    end
  end)
  return out
end

function LS:MythicPlusTeleport(mapID)
  mapID = tonumber(mapID)
  if not mapID then return end
  local all = self:MythicPlusTeleports()
  return all and all[mapID]
end

function LS:CastMythicPlusTeleport(mapID)
  local port = self:MythicPlusTeleport(mapID)
  if not port or not port.name then return false end
  -- Protected: must run from the click, not through pcall.
  if CastSpellByName then
    CastSpellByName(port.name)
    return true
  end
  if C_SpellBook and C_SpellBook.CastSpell and port.slot then
    C_SpellBook.CastSpell(port.slot, port.bank)
    return true
  end
  if C_Spell and C_Spell.CastSpellByID and port.spellID then
    C_Spell.CastSpellByID(port.spellID)
    return true
  end
  if CastSpellByID and port.spellID then
    CastSpellByID(port.spellID)
    return true
  end
  return false
end

function LS:OpenMythicPlus()
  if self.HideWidgetTip then self:HideWidgetTip() end
  if self.ClientFrameShown and self:ClientFrameShown("ChallengesFrame") then
    self:HideClientFrame(_G.PVEFrame)
    self:HideClientFrame(_G.ChallengesFrame)
    return true
  end
  if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_ChallengesUI")
  elseif LoadAddOn then
    pcall(LoadAddOn, "Blizzard_ChallengesUI")
  end
  if PVEFrame_ShowFrame then
    local ok = pcall(PVEFrame_ShowFrame, "ChallengesFrame")
    if ok then
      -- Raise the group-finder window, not ChallengesFrame. That child has its
      -- own backdrop; lifting it to DIALOG/toplevel paints a dark box over the tab.
      self:FrontClientFrame(PVEFrame)
      return true
    end
  end
  if PVEFrame_ToggleFrame then
    local ok = pcall(PVEFrame_ToggleFrame, "ChallengesFrame")
    if ok then return true end
  end
  if self.OpenClientFrame and self:OpenClientFrame(nil, "PVEFrame") then
    if ChallengesFrame then
      if ShowUIPanel then pcall(ShowUIPanel, ChallengesFrame)
      elseif ChallengesFrame.Show then ChallengesFrame:Show() end
    end
    return true
  end
  return false
end

local function RegisterExtraWidgets()
  LS:RegisterWidget({
    id = "raiderio",
    title = "Mythic+",
    defaultSize = "half",
    defaultH = 5,
    click = function(self)
      if self.OpenMythicPlus then self:OpenMythicPlus() end
    end,
    tooltip = function(self, tip)
      self:FillPlayerTooltip(tip)
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "raiderio", "What this tile shows. !keys replies are in Settings.", {
          { "score", "Score", true },
          { "dungeons", "Dungeons", true },
          { "teleport", "Teleport", true },
          { "key", "Your key", true },
        })
      end
      local w = self.widgets
      height = height or 80
      if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        local now = (GetTime and GetTime()) or 0
        if not self._mplusMapAt or now - self._mplusMapAt > 5 then
          self._mplusMapAt = now
          pcall(C_MythicPlus.RequestMapInfo)
        end
      end
      local ports = (self:WidgetOptOn("raiderio", "teleport", true)
        and self.MythicPlusTeleports and self:MythicPlusTeleports()) or {}
      local showScore = self:WidgetOptOn("raiderio", "score", true)
      local showMaps = self:WidgetOptOn("raiderio", "dungeons", true)
      local showKey = self:WidgetOptOn("raiderio", "key", true)
      local score, source = self:MythicPlusScore()
      local scoreH = showScore and math.max(18, math.min(28, math.floor(height * 0.22))) or 0
      local keyH = showKey and KEY_LINE_H or 0
      if showScore then
        local amount = w.text(parent, width, scoreH - 2)
        if amount.ClearAllPoints then amount:ClearAllPoints() end
        amount:SetPoint("TOP", 0, -2)
        if amount.SetJustifyH then amount:SetJustifyH("CENTER") end
        if amount.SetFont then
          amount:SetFont(self:ThemeFont(), math.max(16, math.min(24, scoreH - 4)), "")
        end
        if source or (score and score > 0) then
          amount:SetText(tostring(score or 0))
          local r, g, b = self:MythicPlusScoreColor(score or 0)
          if r then amount:SetTextColor(r, g, b, 1) end
        else
          amount:SetText("No score yet")
          if self.colors then amount:SetTextColor(unpack(self.colors.muted)) end
        end
      end
      local maps = showMaps and self:SeasonDungeonMaps() or {}
      if #maps == 0 then
        if not showScore and not showKey then
          local hint = w.text(parent, width - 16, 10)
          hint:SetPoint("TOP", 0, -8)
          if hint.SetJustifyH then hint:SetJustifyH("CENTER") end
          if self.colors then hint:SetTextColor(unpack(self.colors.muted)) end
          hint:SetText("Score and dungeons are hidden. Edit dashboard to pick some.")
        elseif showMaps then
          local hint = w.text(parent, width - 16, 10)
          hint:SetPoint("TOP", 0, -(scoreH + 4))
          if hint.SetJustifyH then hint:SetJustifyH("CENTER") end
          if self.colors then hint:SetTextColor(unpack(self.colors.muted)) end
          hint:SetText("This season's dungeons appear when the client sends them.")
        end
        if showKey then PaintKeystoneLine(self, parent, width) end
        return height
      end
      local cols = math.min(4, math.max(1, #maps))
      local rows = math.ceil(#maps / cols)
      local gap = 4
      local innerW = math.max(1, width - 12)
      local innerH = math.max(1, height - scoreH - keyH - 8)
      if parent.SetClipsChildren then parent:SetClipsChildren(true) end
      local size = math.max(12, math.min(
        math.floor((innerW - gap * (cols - 1)) / cols),
        math.floor((innerH - gap * (rows - 1)) / rows)
      ))
      local usedW = cols * size + (cols - 1) * gap
      local usedH = rows * size + (rows - 1) * gap
      local x0 = math.floor((width - usedW) / 2)
      local y0 = -(scoreH + math.max(2, math.floor((innerH - usedH) / 2)))
      local fontSize = math.max(14, math.min(22, math.floor(size * 0.5)))
      for i, mapID in ipairs(maps) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = x0 + col * (size + gap)
        local top = y0 - row * (size + gap)
        local name, texture
        if C_ChallengeMode.GetMapUIInfo then
          local ok, n, _, _, tex = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
          if ok then name, texture = n, tex end
        end
        local art = parent:CreateTexture(nil, "ARTWORK")
        art:SetSize(size, size)
        art:SetPoint("TOPLEFT", x, top)
        if art.SetTexture and texture then art:SetTexture(texture) end
        if art.SetColorTexture and not texture and self.colors then
          art:SetColorTexture(unpack(self.colors.panel or self.colors.card))
        end
        if art.SetDrawLayer then art:SetDrawLayer("ARTWORK", 0) end
        -- Dim the whole icon so the key sits on the same field on every dungeon.
        -- A smaller plate only showed up on bright art.
        local shade = parent:CreateTexture(nil, "ARTWORK")
        shade:SetSize(size, size)
        shade:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
        if shade.SetDrawLayer then shade:SetDrawLayer("ARTWORK", 1) end
        if shade.SetColorTexture then shade:SetColorTexture(0, 0, 0, 0.35) end
        local level = self:SeasonBestKeyLevel(mapID)
        local num = w.text(parent, size, fontSize)
        if num.ClearAllPoints then num:ClearAllPoints() end
        num:SetPoint("CENTER", art, "CENTER", 0, 0)
        if num.SetJustifyH then num:SetJustifyH("CENTER") end
        if num.SetJustifyV then num:SetJustifyV("MIDDLE") end
        num:SetWidth(size)
        if num.SetFont then
          num:SetFont(self:ThemeFont(), fontSize, "OUTLINE")
        end
        if num.SetShadowColor then num:SetShadowColor(0, 0, 0, 1) end
        if num.SetShadowOffset then num:SetShadowOffset(2, -2) end
        num:SetText(level and tostring(level) or "–")
        if level then
          num:SetTextColor(self:KeyLevelColor(level))
        elseif self.colors then
          num:SetTextColor(unpack(self.colors.muted))
        end
        local dungeonID, dungeonName, dungeonLevel = mapID, name, level
        local port = self:WidgetOptOn("raiderio", "teleport", true) and ports[dungeonID]
        if port then
          local a = self.colors and self.colors.accent or { 0.35, 0.85, 0.79 }
          PaintIconBorder(parent, art, size, a[1], a[2], a[3])
        end
        local hit
        if port and port.name then
          hit = SecureSpellHit(parent, x, top, size, size, port.name)
        else
          hit = Hit(parent, x, top, size, size)
        end
        if dungeonName then hit.text = { text_value = dungeonName } end
        self:HoverTip(hit, function(tip)
          if tip.ClearLines then tip:ClearLines() end
          tip:SetText(dungeonName or "Dungeon")
          if tip.AddLine then
            if dungeonLevel then
              tip:AddLine("Best this season: +" .. tostring(dungeonLevel))
            else
              tip:AddLine("No timed run this season.")
            end
            if port and port.name then
              tip:AddLine(port.name)
              tip:AddLine("Keystone Hero teleport is unlocked. Click to teleport.")
            else
              tip:AddLine("Click to open Mythic+ Dungeons.")
            end
          end
        end)
        hit:SetScript("OnMouseUp", function()
          if self.HideWidgetTip then self:HideWidgetTip() end
          local live = self:WidgetOptOn("raiderio", "teleport", true)
            and self.MythicPlusTeleport and self:MythicPlusTeleport(dungeonID)
          if live then
            if not (hit.GetAttribute and hit:GetAttribute("type") == "spell") then
              if self.CastMythicPlusTeleport then self:CastMythicPlusTeleport(dungeonID) end
            end
            if self.frame then self.frame:Hide() end
            return
          end
          if self.OpenMythicPlus then self:OpenMythicPlus() end
        end)
        if dungeonName then art.mapName = dungeonName end
        if dungeonID then art.mapID = dungeonID end
      end
      if showKey then PaintKeystoneLine(self, parent, width) end
      return height
    end,
  })

  LS:RegisterWidget({
    id = "tsm_gold",
    title = "Gold",
    defaultSize = "half",
    tooltip = function(self, tip)
      if self.FillGoldTooltip then self:FillGoldTooltip(tip) end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintMoneyFormatSettings(parent, width, "tsm_gold", "line", true)
      end
      local w = self.widgets
      height = height or 80
      self:RecordAccountGold()
      local now = self:WarbandGold()
      local history = self.db and self.db.goldHistory
      local opts = self:WidgetOpts("tsm_gold")
      local format = opts.format or "letters"
      local colorOn = opts.color ~= false
      local sepOn = opts.separators
      if sepOn == nil then sepOn = true end
      sepOn = sepOn and true or false
      local style = (opts.chart or "line") == "line" and "line" or "bars"
      local amount = w.text(parent, width - 24, 18)
      amount:SetPoint("TOPLEFT", 12, -6)
      if amount.SetDrawLayer then amount:SetDrawLayer("OVERLAY", 6) end
      local text, r, g, b = self:FormatTokenMoney(now or 0, {
        format = format, color = colorOn, separators = sepOn,
      })
      amount:SetText(text)
      amount:SetTextColor(r, g, b, 1)
      if self.FitText then self:FitText(amount, width - 24, 1) end
      local hint = w.text(parent, width - 24, 10)
      hint:SetPoint("TOPLEFT", 12, -30)
      if hint.SetDrawLayer then hint:SetDrawLayer("OVERLAY", 6) end
      if self.FitText then self:FitText(hint, width - 24, 1) end
      if self.colors then hint:SetTextColor(unpack(self.colors.muted)) end
      hint:SetText("Gold Lodestar has seen across this warband.")
      if #(history or {}) >= 2 then
        local inset = 46
        local plotH = math.max(16, (height or 80) - inset - 6)
        local plot = CreateFrame("Frame", nil, parent)
        plot:SetPoint("TOPLEFT", 0, -inset)
        plot:SetPoint("BOTTOMRIGHT", 0, 4)
        plot:SetHeight(plotH)
        if plot.SetClipsChildren then plot:SetClipsChildren(true) end
        self:PaintSparkline(plot, history, width, 0, self.colors, style, plotH)
      end
      return height
    end,
  })

  LS:RegisterWidget({
    id = "currency",
    title = "Currencies",
    defaultSize = "half",
    defaultH = 5,
    click = function(self)
      if self.OpenCurrencies then self:OpenCurrencies() end
    end,
    tooltip = function(_, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("Currencies")
      if tip.AddLine then
        tip:AddLine("Hover a currency for the same tooltip as the currency tab.")
        tip:AddLine("Click to open the currency tab. Click again to close it.")
      end
    end,
    render = function(self, parent, width, height)
      local w = self.widgets
      height = height or 80
      -- The full currency list is far longer than a tile, and a tile that shows the
      -- first eight hides the rest with no way to reach them. The list gets a
      -- settings page; the tile keeps a button to it.
      if self.dashboardEdit then
        local y = -4
        local note = w.text(parent, width - 24, 10)
        note:SetPoint("TOPLEFT", 12, y)
        if self.colors then note:SetTextColor(unpack(self.colors.muted)) end
        local tracked = #self:TrackedCurrencies()
        local total = #self:CurrencyCatalog()
        if total > 0 then
          note:SetText(string.format("Tracking %d of %d currencies. Default is this expansion.", tracked, total))
        else
          note:SetText("No currencies from the client yet.")
        end
        y = y - 20

        local open = w.button(parent, "Choose currencies", math.min(180, width - 24), 24, 11)
        open:SetPoint("TOPLEFT", 12, y)
        w.paint(open, "panel")
        open:SetScript("OnMouseUp", function()
          self:SetPageTab("SETTINGS", "CURRENCIES")
          self:ShowPage("SETTINGS")
        end)
        y = y - 28

        local where = w.text(parent, width - 24, 10)
        where:SetPoint("TOPLEFT", 12, y)
        if self.colors then where:SetTextColor(unpack(self.colors.muted)) end
        where:SetText("Settings → Currencies")
        return height
      end
      local rows = self:TrackedCurrencies()
      if #rows == 0 then
        local none = w.text(parent, width - 24, 11)
        none:SetPoint("TOPLEFT", 12, -6)
        none:SetText("No currencies from the client yet.")
        return height
      end
      local rowH = math.max(18, math.min(28, math.floor((height - 8) / math.max(1, #rows))))
      local iconSize = math.max(14, math.min(22, rowH - 4))
      local y = -4
      for _, row in ipairs(rows) do
        local iconW = PaintCurrencyIcon(parent, row.icon, 12, y, iconSize)
        local textX = 12 + (iconW > 0 and iconW + 6 or 0)
        local qty = BreakUpLargeNumbers and BreakUpLargeNumbers(row.quantity) or tostring(row.quantity)
        local qtyW = math.min(72, math.max(40, math.floor(width * 0.28)))
        local nameW = math.max(40, width - textX - qtyW - 16)
        local fontSize = math.max(11, math.min(14, rowH - 6))
        local textY = y - math.floor((rowH - 14) / 2)
        local name = w.text(parent, nameW, fontSize)
        name:SetPoint("TOPLEFT", textX, textY)
        name:SetText(row.name)
        if self.FitText then self:FitText(name, nameW, 1) end
        local amt = w.text(parent, qtyW, fontSize)
        amt:SetPoint("TOPRIGHT", -12, textY)
        if amt.SetJustifyH then amt:SetJustifyH("RIGHT") end
        amt:SetText(qty)
        if self.FitText then self:FitText(amt, qtyW, 1) end
        local r, g, b = self:QualityColor(row.quality)
        if r then
          name:SetTextColor(r, g, b, 1)
          amt:SetTextColor(r, g, b, 1)
        end
        local currencyID = row.id
        local hit = Hit(parent, 8, y, width - 16, rowH)
        self:HoverTip(hit, function(tip) self:FillCurrencyTooltip(tip, currencyID) end)
        hit:SetScript("OnMouseUp", function()
          if self.OpenCurrencies then self:OpenCurrencies() end
        end)
        y = y - rowH
      end
      return height
    end,
  })

  LS:RegisterWidget({
    id = "pvp",
    title = "PvP",
    defaultSize = "half",
    defaultH = 5,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("PvP")
      if tip.AddLine then
        tip:AddLine("Honor " .. tostring(self:HonorLevel()))
        tip:AddLine("Season ratings from the client.")
      end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        local rows = {}
        for _, bracket in ipairs(LS.PVP_BRACKETS or {}) do
          table.insert(rows, { bracket.key, bracket.label, bracket.key ~= "rbg" })
        end
        return self:PaintWidgetSettings(parent, width, "pvp", "Season rating. Toggle brackets.", rows)
      end
      local w = self.widgets
      height = height or 80
      local honor = self:HonorLevel()
      local brackets = LS.PVP_BRACKETS or {}
      local shown = {}
      for _, bracket in ipairs(brackets) do
        if self:WidgetOptOn("pvp", bracket.key, bracket.key ~= "rbg") then
          table.insert(shown, bracket)
        end
      end
      local bodyH = math.max(40, height - 8)
      local honorH = math.max(18, math.min(28, math.floor(bodyH * 0.28)))
      local rest = bodyH - honorH
      local rowH = #shown > 0 and math.max(14, math.floor(rest / #shown)) or 16
      local amount = w.text(parent, width - 24, honorH - 2)
      amount:SetPoint("TOPLEFT", 12, -4)
      if self.colors then amount:SetTextColor(unpack(self.colors.accent)) end
      if amount.SetFont then
        amount:SetFont(self:ThemeFont(), math.max(14, math.min(22, honorH - 4)), "")
      end
      amount:SetText("Honor " .. tostring(honor))
      if self.FitText then self:FitText(amount, width - 24, 1) end
      local y = -(honorH + 2)
      for _, bracket in ipairs(shown) do
        local info = self:RatedPvPInfo(bracket.index)
        local rating = info and info.rating or 0
        local line = w.text(parent, width - 24, math.max(11, math.min(14, rowH - 2)))
        line:SetPoint("TOPLEFT", 12, y)
        line:SetText(string.format("%s  %d", bracket.label, rating))
        if self.FitText then self:FitText(line, width - 24, 1) end
        local hit = Hit(parent, 8, y, width - 16, rowH)
        local label, value, best = bracket.label, rating, info and info.seasonBest
        self:HoverTip(hit, function(tip)
          if tip.ClearLines then tip:ClearLines() end
          tip:SetText(label)
          if tip.AddLine then
            tip:AddLine("Season rating: " .. tostring(value))
            if best then tip:AddLine("Season best: " .. tostring(best)) end
          end
        end)
        y = y - rowH
      end
      return height
    end,
  })

  LS:RegisterWidget({
    id = "itemlevel",
    title = "Item Level",
    defaultSize = "half",
    defaultH = 5,
    click = function(self)
      if self.OpenCharacter then self:OpenCharacter() end
    end,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local info = self:PlayerItemLevels()
      tip:SetText("Item Level")
      if tip.AddLine then
        tip:AddLine("Equipped  " .. RoundIlvl(info.equipped))
        tip:AddLine("In bags  " .. RoundIlvl(info.bags))
        tip:AddLine("In bags is the higher of the client's average and the best pieces in your bags.")
        tip:AddLine("Missing enchants and empty sockets are listed beside the gear so two flags on one piece never overlap.")
        tip:AddLine("A red border is a missing enchant. A yellow caution is an empty gem slot.")
        tip:AddLine("Click to open the character panel. Click again to close it.")
      end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "itemlevel", "What this tile shows.", {
          { "bags", "Bags", true },
          { "slots", "Slots", true },
          { "flags", "Flags", true },
        })
      end
      local w = self.widgets
      height = height or 80
      local info = self:PlayerItemLevels()
      local showBags = self:WidgetOptOn("itemlevel", "bags", true)
      local showSlots = self:WidgetOptOn("itemlevel", "slots", true)
      local showFlags = self:WidgetOptOn("itemlevel", "flags", true)
      local amount = w.text(parent, width - 24, 18)
      amount:SetPoint("TOPLEFT", 12, -4)
      amount:SetText(RoundIlvl(info.equipped))
      local er, eg, eb = self:QualityColor(info.equippedQuality)
      if er then amount:SetTextColor(er, eg, eb, 1)
      elseif self.colors then amount:SetTextColor(unpack(self.colors.accent)) end
      local equippedLabel = w.text(parent, width - 24, 10)
      equippedLabel:SetPoint("TOPLEFT", 12, -24)
      if self.colors then equippedLabel:SetTextColor(unpack(self.colors.muted)) end
      equippedLabel:SetText("Equipped")
      if showBags then
      local bags = w.text(parent, math.floor(width / 2) - 12, 16)
      bags:SetPoint("TOPRIGHT", -12, -4)
      if bags.SetJustifyH then bags:SetJustifyH("RIGHT") end
      bags:SetWidth(math.floor(width / 2) - 12)
      bags:SetText(RoundIlvl(info.bags))
      local br, bg, bb = self:QualityColor(info.bagsQuality)
      if br then bags:SetTextColor(br, bg, bb, 1)
      elseif self.colors then bags:SetTextColor(unpack(self.colors.accent)) end
      local bagsLabel = w.text(parent, math.floor(width / 2) - 12, 10)
      bagsLabel:SetPoint("TOPRIGHT", -12, -24)
      if bagsLabel.SetJustifyH then bagsLabel:SetJustifyH("RIGHT") end
      bagsLabel:SetWidth(math.floor(width / 2) - 12)
      if self.colors then bagsLabel:SetTextColor(unpack(self.colors.muted)) end
      bagsLabel:SetText("In bags")
      end
      local slots = info.slots or {}
      local filled = 0
      for _, piece in ipairs(slots) do
        if piece.icon or piece.link then filled = filled + 1 end
      end
      -- Captions live in a list beside (or below) the grid so two flags on one
      -- slot cannot paint on top of each other under a 22px icon.
      local issues = {}
      if showFlags then
        for _, piece in ipairs(slots) do
          local name = (self.GEAR_SLOT_LABELS and self.GEAR_SLOT_LABELS[piece.slot])
            or piece.name or "Slot"
          if piece.missingEnchant then
            table.insert(issues, { label = name .. "  ·  No enchant", kind = "enchant" })
          end
          if piece.emptySocket then
            table.insert(issues, { label = name .. "  ·  No socket", kind = "socket" })
          end
        end
      end
      if filled == 0 or (not showSlots and #issues == 0) then
        return height
      end
      local stacked = width < 360 or not showSlots
      local listW = (#issues > 0 and not stacked and showSlots) and math.max(118, math.floor(width * 0.36)) or 0
      local cols = 8
      local rows = math.ceil(#slots / cols)
      local gap = 3
      local listH = #issues * 12
      local innerW = math.max(1, width - 16 - listW - (listW > 0 and 8 or 0))
      local innerH = math.max(1, height - 42 - ((stacked and #issues > 0) and (listH + 8) or 0))
      local size = math.max(10, math.min(
        math.floor((innerW - gap * (cols - 1)) / cols),
        math.floor((innerH - gap * (rows - 1)) / rows)
      ))
      local usedW = math.min(#slots, cols) * size + (math.min(#slots, cols) - 1) * gap
      local x0 = listW > 0 and 8 or math.floor((width - usedW) / 2)
      local y = -40
      local rowPitch = size + gap
      if showSlots then
      for i, piece in ipairs(slots) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = x0 + col * (size + gap)
        local top = y - row * rowPitch
        local art = parent:CreateTexture(nil, "ARTWORK")
        art:SetSize(size, size)
        art:SetPoint("TOPLEFT", x, top)
        if piece.icon and art.SetTexture then pcall(art.SetTexture, art, piece.icon) end
        if (not piece.icon) and art.SetColorTexture and self.colors then
          art:SetColorTexture(unpack(self.colors.panel or self.colors.card))
        end
        if art.SetDrawLayer then art:SetDrawLayer("ARTWORK", 0) end
        if piece.missingEnchant then
          local wr, wg, wb = self:MissingEnchantColor()
          PaintIconBorder(parent, art, size, wr, wg, wb)
        end
        if piece.ilvl then
          local fontSize = math.max(8, math.min(14, math.floor(size * 0.42)))
          -- Dim the whole icon so the item level sits on the same field on every
          -- piece. A smaller plate read as a black box on top of the gear art.
          local shade = parent:CreateTexture(nil, "ARTWORK")
          shade:SetSize(size, size)
          shade:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
          if shade.SetDrawLayer then shade:SetDrawLayer("ARTWORK", 1) end
          if shade.SetColorTexture then shade:SetColorTexture(0, 0, 0, 0.35) end
          shade.ilvlShade = true
          local num = w.text(parent, size, fontSize)
          if num.ClearAllPoints then num:ClearAllPoints() end
          num:SetPoint("CENTER", art, "CENTER", 0, 0)
          if num.SetJustifyH then num:SetJustifyH("CENTER") end
          if num.SetJustifyV then num:SetJustifyV("MIDDLE") end
          num:SetWidth(size)
          if num.SetFont then
            num:SetFont(self:ThemeFont(), fontSize, "OUTLINE")
          end
          if num.SetShadowColor then num:SetShadowColor(0, 0, 0, 1) end
          if num.SetShadowOffset then num:SetShadowOffset(1, -1) end
          num:SetText(tostring(math.floor(piece.ilvl + 0.5)))
          local qr, qg, qb = self:QualityColor(piece.quality)
          if qr then num:SetTextColor(qr, qg, qb, 1)
          elseif self.colors then num:SetTextColor(unpack(self.colors.text)) end
        end
        if piece.emptySocket then
          local mark = math.max(6, math.min(12, math.floor(size * 0.34)))
          local lift = math.max(4, math.floor(mark * 0.45))
          local caution = parent:CreateTexture(nil, "OVERLAY")
          caution:SetSize(mark, mark)
          if caution.SetDrawLayer then caution:SetDrawLayer("OVERLAY", 7) end
          -- Sit above the missing-enchant edge instead of tucked inside it.
          caution:SetPoint("TOPRIGHT", art, "TOPRIGHT", 2, lift)
          if caution.SetTexture then caution:SetTexture(SOCKET_CAUTION) end
          caution.emptySocket = true
        end
        local slotIndex, pieceLink, pieceName = piece.slot, piece.link, piece.name
        local hit = Hit(parent, x, top, size, size)
        self:HoverTip(hit, function(tip)
          if tip.SetInventoryItem then
            local ok = pcall(tip.SetInventoryItem, tip, "player", slotIndex)
            if ok then return end
          end
          if pieceLink and tip.SetHyperlink then
            pcall(tip.SetHyperlink, tip, pieceLink)
            return
          end
          if tip.ClearLines then tip:ClearLines() end
          tip:SetText(pieceName or "Empty slot")
        end)
        hit:SetScript("OnMouseUp", function()
          if self.OpenCharacter then self:OpenCharacter() end
        end)
      end
      end
      if #issues > 0 then
        local lx, ly, lw
        if stacked then
          lx, ly = 12, y - rows * rowPitch - 2
          lw = width - 24
        else
          lx = x0 + usedW + 10
          ly = y
          lw = math.max(80, width - lx - 8)
        end
        for i, issue in ipairs(issues) do
          local line = w.text(parent, lw, 10)
          line:SetPoint("TOPLEFT", lx, ly - (i - 1) * 12)
          line:SetText(issue.label)
          if self.FitText then self:FitText(line, lw, 1) end
          if issue.kind == "enchant" then
            local wr, wg, wb = self:MissingEnchantColor()
            line:SetTextColor(wr, wg, wb, 1)
          else
            line:SetTextColor(1, 0.82, 0.2, 1)
          end
        end
      end
      return height
    end,
  })

  LS:RegisterWidget({
    id = "readiness",
    title = "Readiness",
    defaultSize = "half",
    defaultH = 5,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("Readiness")
      if tip.AddLine then
        tip:AddLine("Food, flask, augment rune, and weapon oil or whetstone from this expansion.")
        tip:AddLine("Click a slot to eat, drink, or apply what's in your bags.")
      end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "readiness", "Slots on this tile.", {
          { "food", "Food", true },
          { "flask", "Flask", true },
          { "rune", "Rune", true },
          { "weapon", "Weapon", true },
        })
      end
      local w = self.widgets
      height = height or 80
      local kinds = {}
      for _, kind in ipairs(self.READINESS_KINDS or {}) do
        if self:WidgetOptOn("readiness", kind, true) then
          table.insert(kinds, kind)
        end
      end
      if #kinds == 0 then
        local hint = w.text(parent, width - 16, 10)
        hint:SetPoint("TOP", 0, -8)
        if hint.SetJustifyH then hint:SetJustifyH("CENTER") end
        if self.colors then hint:SetTextColor(unpack(self.colors.muted)) end
        hint:SetText("Food, flask, rune, and weapon are hidden. Edit dashboard to pick some.")
        return height
      end
      local snap = self.ReadinessSnapshot and self:ReadinessSnapshot() or {}
      local n = #kinds
      local gap = 6
      if parent.SetClipsChildren then parent:SetClipsChildren(true) end
      local innerW = math.max(1, width - 16)
      local innerH = math.max(1, height - 8)
      local size = math.max(16, math.min(
        math.floor((innerW - gap * (n - 1)) / n),
        math.floor(innerH * 0.82)
      ))
      local captionSize = math.max(9, math.min(13, math.floor(size * 0.22)))
      local captionH = captionSize + 3
      size = math.min(size, math.max(16, innerH - captionH - 2))
      local usedW = n * size + (n - 1) * gap
      local usedH = size + captionH
      local x0 = math.floor((width - usedW) / 2)
      local y = -math.max(2, math.floor((innerH - usedH) / 2))
      local labels = self.READINESS_LABELS or {}
      local clicks = {
        food = "Click to eat.",
        flask = "Click to use.",
        rune = "Click to use.",
        weapon = "Click to apply to your weapon.",
      }
      for i, kind in ipairs(kinds) do
        local slotKind = kind
        local row = snap[slotKind] or {}
        local bag, slot = row.bag, row.slot
        local hasItem = bag ~= nil and slot ~= nil
        local x = x0 + (i - 1) * (size + gap)
        local art = parent:CreateTexture(nil, "ARTWORK")
        art:SetSize(size, size)
        art:SetPoint("TOPLEFT", x, y)
        if row.icon and art.SetTexture then pcall(art.SetTexture, art, row.icon) end
        if (not row.icon) and art.SetColorTexture and self.colors then
          art:SetColorTexture(unpack(self.colors.panel or self.colors.card))
        end
        if art.SetDrawLayer then art:SetDrawLayer("ARTWORK", 0) end
        if row.up then
          local a = self.colors and self.colors.accent or { 0.35, 0.85, 0.79 }
          PaintIconBorder(parent, art, size, a[1], a[2], a[3])
        elseif hasItem then
          local wr, wg, wb
          if self.colors and self.colors.warn then
            wr, wg, wb = self.colors.warn[1], self.colors.warn[2], self.colors.warn[3]
          else
            wr, wg, wb = self:MissingEnchantColor()
          end
          PaintIconBorder(parent, art, size, wr, wg, wb)
        end
        if row.count and row.count > 1 then
          local fontSize = math.max(8, math.min(16, math.floor(size * 0.28)))
          -- Dim the whole icon rather than backing the count with a plate, which
          -- read as a black box in the corner of the art.
          local shade = parent:CreateTexture(nil, "ARTWORK")
          shade:SetSize(size, size)
          shade:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
          if shade.SetDrawLayer then shade:SetDrawLayer("ARTWORK", 1) end
          if shade.SetColorTexture then shade:SetColorTexture(0, 0, 0, 0.35) end
          shade.countShade = true
          local num = w.text(parent, size, fontSize)
          if num.ClearAllPoints then num:ClearAllPoints() end
          num:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", -1, 1)
          if num.SetJustifyH then num:SetJustifyH("RIGHT") end
          if num.SetFont then
            num:SetFont(self:ThemeFont(), fontSize, "OUTLINE")
          end
          if num.SetShadowColor then num:SetShadowColor(0, 0, 0, 1) end
          if num.SetShadowOffset then num:SetShadowOffset(1, -1) end
          num:SetText(tostring(row.count))
          if self.colors then num:SetTextColor(unpack(self.colors.text)) end
        end
        local caption = w.text(parent, size + 8, captionSize)
        if caption.ClearAllPoints then caption:ClearAllPoints() end
        caption:SetPoint("TOP", art, "BOTTOM", 0, -1)
        if caption.SetJustifyH then caption:SetJustifyH("CENTER") end
        caption:SetWidth(size + 8)
        if caption.SetFont then
          caption:SetFont(self:ThemeFont(), captionSize, "")
        end
        caption:SetText(labels[slotKind] or slotKind)
        if self.FitText then self:FitText(caption, size + 8, 1) end
        if row.up and self.colors then
          caption:SetTextColor(unpack(self.colors.accent))
        elseif hasItem and self.colors and self.colors.warn then
          caption:SetTextColor(unpack(self.colors.warn))
        elseif self.colors then
          caption:SetTextColor(unpack(self.colors.muted))
        end
        local hit = SecureItemHit(parent, x, y, size, size + captionH, bag, slot)
        hit.text = caption
        self:HoverTip(hit, function(tip)
          local live = self.ReadinessSnapshot and self:ReadinessSnapshot() or {}
          local info = live[slotKind] or {}
          if tip.ClearLines then tip:ClearLines() end
          tip:SetText(info.name or labels[slotKind] or slotKind)
          if tip.AddLine then
            if info.up then
              local left = info.remaining and self.FormatDuration and self:FormatDuration(info.remaining)
              tip:AddLine(left and ("Up  ·  " .. left .. " left") or "Up")
            else
              tip:AddLine("Not up")
            end
            if info.count and info.count > 0 then
              tip:AddLine(tostring(info.count) .. " in bags")
            end
            if info.bag ~= nil and info.slot ~= nil then
              tip:AddLine(clicks[slotKind] or "Click to use.")
            else
              tip:AddLine("Nothing in bags this expansion.")
            end
          end
        end)
        hit:SetScript("OnMouseUp", function()
          -- Do not use the item here. Do not rebuild the tile until the click
          -- finishes; a SecureActionButton uses the bag on mouse down.
          if self.page ~= "DASHBOARD" then return end
          local refresh = function()
            if LS.page ~= "DASHBOARD" then return end
            if LS.RefreshDashboardLive then
              LS:RefreshDashboardLive({ "readiness" })
            elseif LS.ShowPage then
              LS:ShowPage("DASHBOARD")
            end
          end
          if C_Timer and C_Timer.After then
            C_Timer.After(0, refresh)
          else
            refresh()
          end
        end)
      end
      return height
    end,
  })

  LS:RegisterWidget({
    id = "housing",
    title = "Housing",
    defaultSize = "half",
    defaultH = 5,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local info = self.HousingProgress and self:HousingProgress() or {}
      tip:SetText("Housing")
      if tip.AddLine then
        if info.owned then
          if info.name then tip:AddLine(info.name) end
          if info.level then tip:AddLine("House level " .. tostring(info.level)) end
          if info.favor then tip:AddLine("Favor " .. tostring(math.floor(info.favor + 0.5))) end
          if info.fill then
            tip:AddLine(string.format("%d%% to the next house level", math.floor(info.fill * 100 + 0.5)))
          end
        else
          tip:AddLine("No house on this character.")
        end
        tip:AddLine("Dashboard opens the client's Housing Dashboard. Click again to close it.")
      end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "housing", "Buttons on this tile.", {
          { "dashboard", "Dashboard", true },
          { "teleport", "Teleport", true },
        })
      end
      local w = self.widgets
      height = height or 80
      local info = self.HousingProgress and self:HousingProgress() or {}
      local stacked = width < 360
      local line = w.text(parent, width - (stacked and 24 or 180), 12)
      line:SetPoint("TOPLEFT", 12, -6)
      if self.colors then line:SetTextColor(unpack(self.colors.accent)) end
      if info.owned then
        line:SetText(info.name and info.name ~= "" and info.name or "Your house")
      elseif self.HousingAPIsReady and self:HousingAPIsReady() then
        line:SetText("No house on this character")
      else
        line:SetText("Housing is not on this client")
      end
      local meta = w.text(parent, width - (stacked and 24 or 180), 10)
      meta:SetPoint("TOPLEFT", 12, -24)
      if self.colors then meta:SetTextColor(unpack(self.colors.muted)) end
      if info.owned then
        local bits = {}
        if info.neighborhood and info.neighborhood ~= "" then
          table.insert(bits, info.neighborhood)
        end
        if info.level then
          local cap = info.maxLevel and (" / " .. tostring(info.maxLevel)) or ""
          table.insert(bits, "Level " .. tostring(info.level) .. cap)
        end
        if info.favor then
          local fav = tostring(math.floor(info.favor + 0.5))
          if info.nextFavor then
            fav = fav .. " / " .. tostring(math.floor(info.nextFavor + 0.5))
          end
          table.insert(bits, fav .. " favor")
        end
        meta:SetText(#bits > 0 and table.concat(bits, "  •  ") or "Open the Housing Dashboard for details.")
      else
        meta:SetText("Open the Housing Dashboard to claim or manage a house.")
      end
      if self.FitText then
        local copyW = width - (stacked and 24 or 180)
        self:FitText(line, copyW, 1)
        self:FitText(meta, copyW, 2)
      end
      local barY = -46
      if info.fill then
        PaintFillBar(self, parent, 12, barY, width - (stacked and 24 or 180), 8, info.fill)
        barY = barY - 12
      end
      local dash
      if self:WidgetOptOn("housing", "dashboard", true) then
      dash = w.button(parent, "Dashboard", 88, 26, 10)
      if stacked then
        dash:SetPoint("TOPLEFT", 12, barY)
      else
        dash:SetPoint("TOPRIGHT", info.owned and -102 or -10, -8)
      end
      w.paint(dash, "panel")
      dash:SetScript("OnMouseUp", function()
        if self.OpenHousingDashboard then self:OpenHousingDashboard() end
      end)
      end
      if info.owned and info.houseGUID and info.neighborhoodGUID
          and C_Housing and C_Housing.TeleportHome
          and self:WidgetOptOn("housing", "teleport", true) then
        local port = w.button(parent, "Teleport", 88, 26, 10)
        if stacked then
          port:SetPoint("TOPLEFT", dash and 106 or 12, barY)
        else
          port:SetPoint("TOPRIGHT", -10, -8)
        end
        w.paint(port, "panel")
        port:SetScript("OnMouseUp", function()
          if self.TeleportToHouse then self:TeleportToHouse() end
        end)
      end
      return stacked and math.max(80, -barY + 30) or math.max(64, height)
    end,
  })

  LS:RegisterWidget({
    id = "battlepets",
    title = "Battle Pets",
    defaultSize = "half",
    defaultH = 5,
    click = function(self)
      if self.OpenPetJournal then self:OpenPetJournal() end
    end,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local info = self.BattlePetProgress and self:BattlePetProgress() or {}
      tip:SetText("Battle Pets")
      if tip.AddLine then
        if info.owned then
          tip:AddLine(string.format("%d unique  ·  %d collected", info.unique or 0, info.owned))
        end
        if info.summoned and info.summoned.name then
          tip:AddLine("Summoned  " .. info.summoned.name)
        end
        tip:AddLine("Click the tile to open the pet journal. Click again to close it.")
        tip:AddLine("Click a slotted pet to summon it.")
      end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "battlepets", "What this tile shows.", {
          { "count", "Count", true },
          { "team", "Team", true },
          { "summoned", "Summoned", true },
        })
      end
      local w = self.widgets
      height = height or 80
      local info = self.BattlePetProgress and self:BattlePetProgress()
      if not info then
        local line = w.text(parent, width - 24, 12)
        line:SetPoint("TOPLEFT", 12, -8)
        if self.colors then line:SetTextColor(unpack(self.colors.muted)) end
        line:SetText("Battle pets are not on this client.")
        return height
      end
      if parent.SetClipsChildren then parent:SetClipsChildren(true) end
      local showCount = self:WidgetOptOn("battlepets", "count", true)
      local showSummoned = self:WidgetOptOn("battlepets", "summoned", true)
      local showTeam = self:WidgetOptOn("battlepets", "team", true)
      local countH = showCount and math.max(16, math.min(28, math.floor(height * 0.22))) or 0
      local summonedH = showSummoned and math.max(10, math.min(14, math.floor(height * 0.12))) or 0
      local headerH = countH + summonedH
      if showCount then
        local line = w.text(parent, width - 16, countH - 2)
        if line.ClearAllPoints then line:ClearAllPoints() end
        line:SetPoint("TOP", 0, -2)
        if line.SetJustifyH then line:SetJustifyH("CENTER") end
        if line.SetFont then
          line:SetFont(self:ThemeFont(), math.max(14, math.min(24, countH - 4)), "")
        end
        if self.colors then line:SetTextColor(unpack(self.colors.accent)) end
        if (info.owned or 0) > 0 then
          line:SetText(string.format("%d unique", info.unique or 0))
        else
          line:SetText("No battle pets yet")
        end
        if self.FitText then self:FitText(line, width - 16, 1) end
      end
      if showSummoned then
        local meta = w.text(parent, width - 16, summonedH)
        if meta.ClearAllPoints then meta:ClearAllPoints() end
        meta:SetPoint("TOP", 0, -(countH + 1))
        if meta.SetJustifyH then meta:SetJustifyH("CENTER") end
        if self.colors then meta:SetTextColor(unpack(self.colors.muted)) end
        if info.summoned and info.summoned.name then
          meta:SetText(info.summoned.name)
        else
          meta:SetText("No pet summoned")
        end
        if self.FitText then self:FitText(meta, width - 16, 1) end
      end
      if showTeam then
        local team = info.team or {}
        local n = 3
        local gap = 6
        local innerW = math.max(1, width - 16)
        local innerH = math.max(1, height - headerH - 8)
        local size = math.max(18, math.min(
          math.floor((innerW - gap * (n - 1)) / n),
          innerH
        ))
        local usedW = n * size + (n - 1) * gap
        local usedH = size
        local x0 = math.floor((width - usedW) / 2)
        local y = -(headerH + math.max(2, math.floor((innerH - usedH) / 2)))
        for i = 1, n do
          local slotKind = i
          local row = team[slotKind] or {}
          local x = x0 + (i - 1) * (size + gap)
          local art = parent:CreateTexture(nil, "ARTWORK")
          art:SetSize(size, size)
          art:SetPoint("TOPLEFT", x, y)
          if row.icon and art.SetTexture then pcall(art.SetTexture, art, row.icon) end
          if (not row.icon) and art.SetColorTexture and self.colors then
            art:SetColorTexture(unpack(self.colors.panel or self.colors.card))
          end
          if row.summoned then
            local a = self.colors and self.colors.accent or { 0.35, 0.85, 0.79 }
            PaintIconBorder(parent, art, size, a[1], a[2], a[3])
          end
          local hit = Hit(parent, x, y, size, size)
          hit.text = { text_value = row.name or ("Pet slot " .. tostring(slotKind)) }
          local petGuid, petName, petLocked = row.guid, row.name, row.locked
          self:HoverTip(hit, function(tip)
            if tip.ClearLines then tip:ClearLines() end
            if petLocked then
              tip:SetText("Locked slot")
            else
              tip:SetText(petName or "Empty slot")
            end
            if tip.AddLine then
              if petGuid then
                tip:AddLine("Click to summon.")
              elseif not petLocked then
                tip:AddLine("No pet slotted.")
              end
            end
          end)
          hit:SetScript("OnMouseUp", function()
            if petGuid and self.SummonBattlePet then
              self:SummonBattlePet(petGuid)
              return
            end
            if self.OpenPetJournal then self:OpenPetJournal() end
          end)
        end
      end
      return height
    end,
  })

  local function JourneyLines(info)
    info = info or {}
    local bits = {}
    if info.season then table.insert(bits, "Season " .. tostring(info.season)) end
    if info.level then table.insert(bits, "Rank " .. tostring(info.level)) end
    if info.current and info.needed then
      table.insert(bits, tostring(math.floor(info.current + 0.5)) .. " / " .. tostring(math.floor(info.needed + 0.5)))
    elseif info.current then
      table.insert(bits, tostring(math.floor(info.current + 0.5)))
    end
    return bits
  end

  local function RenderJourneyTile(self, parent, width, height, info, opener, widgetID)
    if self.dashboardEdit then
      return self:PaintWidgetSettings(parent, width, widgetID, "What this tile shows.", {
        { "bar", "Progress bar", true },
      })
    end
    local w = self.widgets
    height = height or 80
    local line = w.text(parent, width - 24, 12)
    line:SetPoint("TOPLEFT", 12, -6)
    if self.colors then line:SetTextColor(unpack(self.colors.accent)) end
    line:SetText((info and info.name) or "Journey")
    local meta = w.text(parent, width - 24, 10)
    meta:SetPoint("TOPLEFT", 12, -24)
    if self.colors then meta:SetTextColor(unpack(self.colors.muted)) end
    local bits = JourneyLines(info)
    if #bits > 0 then
      meta:SetText(table.concat(bits, "  •  "))
    else
      meta:SetText("Open Journeys for this season's progress.")
    end
    if self.FitText then
      self:FitText(line, width - 24, 1)
      self:FitText(meta, width - 24, 1)
    end
    if info and info.fill and self:WidgetOptOn(widgetID, "bar", true) then
      PaintFillBar(self, parent, 12, -42, width - 24, 8, info.fill)
    end
    local hit = Hit(parent, 0, 0, width, height)
    hit:SetScript("OnMouseUp", function()
      if opener then opener(self) end
    end)
    return math.max(56, height)
  end

  LS:RegisterWidget({
    id = "calendar",
    title = "Calendar",
    defaultSize = "half",
    defaultH = 5,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("Calendar")
      if tip.AddLine then
        tip:AddLine("This week's holidays, guild events, and invites from the client's calendar.")
        tip:AddLine("Click to open the calendar. Click again to close it.")
      end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "calendar", "Weeks on this tile.", {
          { "thisWeek", "This week", true },
          { "nextWeek", "Next week", true },
        })
      end
      local w = self.widgets
      height = height or 80
      local weeks = self:CalendarWeeks()
      local y = -4
      local function Block(label, rows, limit)
        local head = w.text(parent, width - 24, 10)
        head:SetPoint("TOPLEFT", 12, y)
        if self.colors then head:SetTextColor(unpack(self.colors.accent)) end
        head:SetText(label)
        y = y - 14
        if #rows == 0 then
          local none = w.text(parent, width - 24, 10)
          none:SetPoint("TOPLEFT", 12, y)
          if self.colors then none:SetTextColor(unpack(self.colors.muted)) end
          none:SetText("Nothing on the calendar.")
          y = y - 14
          return
        end
        for i = 1, math.min(limit, #rows) do
          local ev = rows[i]
          local line = w.text(parent, width - 24, 10)
          line:SetPoint("TOPLEFT", 12, y)
          local tag = ev.kind == "guild" and "Guild" or (ev.kind == "invite" and "Invite" or nil)
          line:SetText(tag and (tag .. "  ·  " .. ev.title) or ev.title)
          if self.FitText then self:FitText(line, width - 24, 1) end
          y = y - 12
        end
        if #rows > limit then
          local more = w.text(parent, width - 24, 10)
          more:SetPoint("TOPLEFT", 12, y)
          if self.colors then more:SetTextColor(unpack(self.colors.muted)) end
          more:SetText("+" .. tostring(#rows - limit) .. " more")
          y = y - 12
        end
      end
      if self:WidgetOptOn("calendar", "thisWeek", true) then
        Block("This week", weeks.thisWeek or {}, 4)
        y = y - 4
      end
      if self:WidgetOptOn("calendar", "nextWeek", true) then
        Block("Next week", weeks.nextWeek or {}, 3)
      end
      local hit = Hit(parent, 0, 0, width, height)
      hit:SetScript("OnMouseUp", function()
        if self.OpenCalendar then self:OpenCalendar() end
      end)
      return math.max(64, height)
    end,
  })

  LS:RegisterWidget({
    id = "guild",
    title = "Guild",
    defaultSize = "half",
    defaultH = 4,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local info = self:GuildSummary()
      tip:SetText("Guild")
      if tip.AddLine then
        if info.inGuild then
          if info.name then tip:AddLine(info.name) end
          if info.rank then tip:AddLine(info.rank) end
          tip:AddLine(string.format("%d / %d online", info.online or 0, info.total or 0))
        else
          tip:AddLine("Not in a guild.")
        end
        tip:AddLine("Click to open Communities. Click again to close it.")
      end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "guild", "What this tile shows.", {
          { "rank", "Rank", true },
          { "emblem", "Emblem", true },
        })
      end
      local w = self.widgets
      height = height or 80
      local info = self:GuildSummary()
      local showRank = info.inGuild and info.rank and self:WidgetOptOn("guild", "rank", true)
      local y = -4
      local line = w.text(parent, width - 24, 12)
      line:SetPoint("TOP", 0, y)
      if line.SetJustifyH then line:SetJustifyH("CENTER") end
      if self.colors then line:SetTextColor(unpack(self.colors.accent)) end
      if info.inGuild then
        line:SetText(info.name and info.name ~= "" and info.name or "Your guild")
      else
        line:SetText("Not in a guild")
      end
      y = y - 16
      if showRank then
        local rank = w.text(parent, width - 24, 10)
        rank:SetPoint("TOP", 0, y)
        if rank.SetJustifyH then rank:SetJustifyH("CENTER") end
        if self.colors then rank:SetTextColor(unpack(self.colors.muted)) end
        rank:SetText(info.rank)
        if self.FitText then self:FitText(rank, width - 24, 1) end
        y = y - 14
      end
      local meta = w.text(parent, width - 24, 10)
      meta:SetPoint("TOP", 0, y)
      if meta.SetJustifyH then meta:SetJustifyH("CENTER") end
      if self.colors then meta:SetTextColor(unpack(self.colors.muted)) end
      if info.inGuild then
        meta:SetText(string.format("%d / %d online", info.online or 0, info.total or 0))
      else
        meta:SetText("Open Communities to join or browse.")
      end
      if self.FitText then
        self:FitText(line, width - 24, 1)
        self:FitText(meta, width - 24, 1)
      end
      local size = 0
      if self:WidgetOptOn("guild", "emblem", true) then
      size = math.max(32, math.min(52, math.floor(math.min(width - 24, (height or 80) + y - 8))))
      local emblem = parent:CreateTexture(nil, "ARTWORK")
      emblem:SetSize(size, size)
      emblem:SetPoint("TOP", 0, y - 18)
      local bg = parent:CreateTexture(nil, "BACKGROUND")
      bg:SetSize(size, size)
      bg:SetPoint("TOP", 0, y - 18)
      local border = parent:CreateTexture(nil, "OVERLAY")
      border:SetSize(size, size)
      border:SetPoint("TOP", 0, y - 18)
      local painted
      if info.inGuild and SetLargeGuildTabardTextures then
        painted = pcall(SetLargeGuildTabardTextures, "player", emblem, bg, border)
      end
      if not painted and info.inGuild and SetSmallGuildTabardTextures then
        painted = pcall(SetSmallGuildTabardTextures, "player", emblem)
      end
      if not painted and emblem.SetColorTexture and self.colors then
        emblem:SetColorTexture(unpack(self.colors.panel or self.colors.card))
      end
      end
      local hit = Hit(parent, 0, 0, width, height)
      hit:SetScript("OnMouseUp", function()
        if self.OpenCommunities then self:OpenCommunities() end
      end)
      return math.max(-(y - 18) + size, height)
    end,
  })

  LS:RegisterWidget({
    id = "delvesjourney",
    title = "Delver's Journey",
    defaultSize = "half",
    defaultH = 4,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local info = self.DelverJourney and self:DelverJourney() or {}
      tip:SetText(info.name or "Delver's Journey")
      if tip.AddLine then
        local bits = JourneyLines(info)
        if #bits > 0 then tip:AddLine(table.concat(bits, "  •  ")) end
        if info.fill then
          tip:AddLine(string.format("%d%% to the next rank", math.floor(info.fill * 100 + 0.5)))
        end
        tip:AddLine("Click to open Journeys. Click again to close it.")
      end
    end,
    render = function(self, parent, width, height)
      return RenderJourneyTile(self, parent, width, height,
        self.DelverJourney and self:DelverJourney(),
        function(owner) if owner.OpenDelvesJourney then owner:OpenDelvesJourney() end end,
        "delvesjourney")
    end,
  })

  LS:RegisterWidget({
    id = "preyjourney",
    title = "Preyhunter's Journey",
    defaultSize = "half",
    defaultH = 4,
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local info = self.PreyJourney and self:PreyJourney() or {}
      tip:SetText(info.name or "Preyhunter's Journey")
      if tip.AddLine then
        local bits = JourneyLines(info)
        if #bits > 0 then tip:AddLine(table.concat(bits, "  •  ")) end
        if info.fill then
          tip:AddLine(string.format("%d%% to the next rank", math.floor(info.fill * 100 + 0.5)))
        end
        tip:AddLine("Click to open Journeys. Click again to close it.")
      end
    end,
    render = function(self, parent, width, height)
      return RenderJourneyTile(self, parent, width, height,
        self.PreyJourney and self:PreyJourney(),
        function(owner) if owner.OpenPreyJourney then owner:OpenPreyJourney() end end,
        "preyjourney")
    end,
  })
end

if LS.RegisterWidget then
  RegisterExtraWidgets()
end
