local _, LS = ...

local function Safe(fn, ...)
  if not fn then return end
  local ok, result = pcall(fn, ...)
  if ok then return result end
end

local function ItemLink(slotID)
  if GetInventoryItemLink then return GetInventoryItemLink("player", slotID) end
end

local function ItemName(link, slotLabel)
  if C_Item and C_Item.GetItemInfo then
    local name = Safe(C_Item.GetItemInfo, link)
    if name then return name end
  end
  if GetItemInfo then
    local name = Safe(GetItemInfo, link)
    if name then return name end
  end
  return slotLabel
end

local function ItemIlvl(link)
  if C_Item and C_Item.GetDetailedItemLevelInfo then
    return Safe(C_Item.GetDetailedItemLevelInfo, link)
  end
  if GetDetailedItemLevelInfo then
    return Safe(GetDetailedItemLevelInfo, link)
  end
end

function LS:ItemUpgradeInfo(link, slotID)
  if C_Item and C_Item.GetItemUpgradeInfo then
    local info = Safe(C_Item.GetItemUpgradeInfo, link)
    if type(info) == "table" then return info end
  end
  if C_ItemUpgrade and C_ItemUpgrade.CanUpgradeItem and ItemLocation then
    local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
    if Safe(C_ItemUpgrade.CanUpgradeItem, loc) and C_ItemUpgrade.SetItemUpgradeFromLocation then
      Safe(C_ItemUpgrade.SetItemUpgradeFromLocation, loc)
      local info = Safe(C_ItemUpgrade.GetItemUpgradeItemInfo)
      Safe(C_ItemUpgrade.ClearItemUpgrade)
      if type(info) == "table" and info.itemUpgradeable then
        return {
          currentLevel = info.currUpgrade,
          maxLevel = info.maxUpgrade,
          maxItemLevel = info.maxItemLevel,
          trackString = info.customUpgradeString,
        }
      end
    end
  end
end

local STAT_KEYS = {
  { key = "ITEM_MOD_CRIT_RATING_SHORT", label = "Critical Strike" },
  { key = "ITEM_MOD_HASTE_RATING_SHORT", label = "Haste" },
  { key = "ITEM_MOD_MASTERY_RATING_SHORT", label = "Mastery" },
  { key = "ITEM_MOD_VERSATILITY", label = "Versatility" },
  { key = "ITEM_MOD_CR_STAM_SHORT", label = "Stamina" },
  { key = "ITEM_MOD_AGI_SHORT", label = "Agility" },
  { key = "ITEM_MOD_STR_SHORT", label = "Strength" },
  { key = "ITEM_MOD_INT_SHORT", label = "Intellect" },
}

function LS:ItemStatLines(link)
  local lines = {}
  if not link then return lines end
  local stats
  if C_Item and C_Item.GetItemStats then
    stats = Safe(C_Item.GetItemStats, link)
  end
  if type(stats) ~= "table" and GetItemStats then
    stats = Safe(GetItemStats, link)
  end
  if type(stats) ~= "table" then return lines end
  for _, spec in ipairs(STAT_KEYS) do
    local n = stats[spec.key]
    if type(n) == "number" and n > 0 then
      table.insert(lines, string.format("+%d %s", n, spec.label))
    end
  end
  return lines
end

function LS:GearSlotDetail(slotID)
  local piece
  if self.EquippedGear then
    for _, row in ipairs(self:EquippedGear()) do
      if row.slot == slotID then piece = row break end
    end
  end
  if not piece then
    local link = ItemLink(slotID)
    local name, quality, level, equipLoc, texture
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if link and info then
      name, _, quality, level, _, _, _, _, equipLoc, texture = info(link)
    end
    quality = GetInventoryItemQuality and GetInventoryItemQuality("player", slotID) or quality
    texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slotID) or texture
    piece = {
      slot = slotID,
      link = link,
      name = name,
      quality = tonumber(quality),
      ilvl = link and ItemIlvl(link) or tonumber(level),
      icon = texture,
      equipLoc = equipLoc,
    }
    if link then
      piece.missingEnchant = self.SlotMissingEnchant and self:SlotMissingEnchant(piece)
      piece.emptySocket = self.SlotEmptySocket and self:SlotEmptySocket(piece)
    end
  end
  if not piece then
    return { slot = slotID, label = (self.GEAR_SLOT_LABELS and self.GEAR_SLOT_LABELS[slotID]) or "Slot" }
  end

  local link = piece.link
  local upgrade = link and self:ItemUpgradeInfo(link, slotID)
  local current = upgrade and (upgrade.currentLevel or upgrade.currUpgrade)
  local maxLevel = upgrade and (upgrade.maxLevel or upgrade.maxUpgrade)
  local detail = {
    slot = slotID,
    link = link,
    name = piece.name or ItemName(link, self.GEAR_SLOT_LABELS and self.GEAR_SLOT_LABELS[slotID] or "Slot"),
    label = (self.GEAR_SLOT_LABELS and self.GEAR_SLOT_LABELS[slotID]) or "Slot",
    ilvl = piece.ilvl or ItemIlvl(link),
    quality = piece.quality,
    icon = piece.icon,
    missingEnchant = piece.missingEnchant,
    emptySocket = piece.emptySocket,
    gemCount = link and self.ItemGemCount and self:ItemGemCount(link) or 0,
    enchanted = link and not piece.missingEnchant,
    stats = self:ItemStatLines(link),
    upgradeable = type(current) == "number" and type(maxLevel) == "number" and current < maxLevel,
    upgradeCurrent = current,
    upgradeMax = maxLevel,
    upgradeTrack = upgrade and upgrade.trackString,
    upgradeMaxIlvl = upgrade and upgrade.maxItemLevel,
  }
  if detail.upgradeable and detail.upgradeTrack then
    detail.upgradeLabel = detail.upgradeTrack .. " " .. current .. "/" .. maxLevel
  elseif detail.upgradeable then
    detail.upgradeLabel = current .. "/" .. maxLevel
  end
  if self.GetSpecBisSlotStatus then
    detail.bis = self:GetSpecBisSlotStatus(slotID, piece)
  end
  return detail
end

function LS:GearUpgradeCount()
  return #(self:GetGearRecommendations())
end

function LS:ShowGear(slotID)
  self.gearFocusSlot = tonumber(slotID)
  if self.frame and self.frame.Show then
    self.frame:Show()
  end
  self:ShowPage("GEAR")
end

function LS:GetGearRecommendations()
  local out = {}
  if self.IsEndgameLevel and not self:IsEndgameLevel() then return out end
  if not (C_Item and C_Item.GetItemUpgradeInfo) and not (C_ItemUpgrade and C_ItemUpgrade.CanUpgradeItem) then
    return out
  end
  local slots = self.GEAR_SLOTS or {}
  for _, slotID in ipairs(slots) do
    local link = ItemLink(slotID)
    if link then
      local info = self:ItemUpgradeInfo(link, slotID)
      local current = info and (info.currentLevel or info.currUpgrade)
      local maxLevel = info and (info.maxLevel or info.maxUpgrade)
      if type(current) == "number" and type(maxLevel) == "number" and current < maxLevel then
        local name = ItemName(link, (self.GEAR_SLOT_LABELS and self.GEAR_SLOT_LABELS[slotID]) or "gear")
        local ilvl = ItemIlvl(link)
        local maxIlvl = info.maxItemLevel
        local track = info.trackString
        local why = track and (track .. " " .. current .. "/" .. maxLevel) or (current .. "/" .. maxLevel .. " upgrades left")
        if ilvl and maxIlvl and maxIlvl > ilvl then
          why = why .. string.format(" · %d → %d ilvl", ilvl, maxIlvl)
        end
        table.insert(out, {
          id = "gear_up_" .. slotID,
          title = "Upgrade " .. name,
          minutes = 3,
          score = 18 + (maxLevel - current),
          why = why,
          category = "Gear",
          tags = { ENDGAME = 10 },
          urgency = "MEDIUM",
          priority = "GEAR",
          gearSlot = slotID,
          detail = {
            current = track and (track .. " " .. current .. "/" .. maxLevel) or (current .. "/" .. maxLevel),
            potential = maxIlvl and ("Up to " .. maxIlvl .. " item level") or "More item level at the upgrade vendor",
            matters = "Spend crests on pieces you actually wear before filler slots.",
          },
        })
      end
    end
  end
  table.sort(out, function(a, b)
    if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
    return (a.title or "") < (b.title or "")
  end)
  return out
end

LS.GEAR_ARMORY_LEFT = { 1, 2, 3, 15, 5, 4, 19, 9 }
LS.GEAR_ARMORY_RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
LS.GEAR_ARMORY_WEAPONS = { 16, 17 }

function LS:GearStatEnabled(id)
  self.db.gear = self.db.gear or {}
  self.db.gear.stats = self.db.gear.stats or {}
  local v = self.db.gear.stats[id]
  if v == nil then
    if id == "primary" or id == "stamina" then return true end
    return id == "crit" or id == "haste" or id == "mastery" or id == "vers"
  end
  return v and true or false
end

function LS:ToggleGearStat(id)
  self.db.gear = self.db.gear or {}
  self.db.gear.stats = self.db.gear.stats or {}
  self.db.gear.stats[id] = not self:GearStatEnabled(id)
  if self.statTrackFrame and self.statTrackFrame.IsShown and self.statTrackFrame:IsShown() then
    self:RefreshStatTrack()
  end
  self:ShowPage("GEAR")
end

function LS:GearStatSettingsOpen()
  return self.db.gear and self.db.gear.statSettingsOpen and true or false
end

function LS:ToggleGearStatSettings()
  self.db.gear = self.db.gear or {}
  self.db.gear.statSettingsOpen = not self:GearStatSettingsOpen()
  if self.statTrackFrame and self.statTrackFrame.IsShown and self.statTrackFrame:IsShown() then
    self:RefreshStatTrack()
  end
  self:ShowPage("GEAR")
end

function LS:GearShowModel()
  if not self.db or not self.db.gear then return true end
  if self.db.gear.showModel == nil then return true end
  return self.db.gear.showModel and true or false
end

function LS:ToggleGearShowModel()
  self.db.gear = self.db.gear or {}
  self.db.gear.showModel = not self:GearShowModel()
  self:ShowPage("GEAR")
end

local function GearHit(parent, x, y, size)
  local hit = CreateFrame("Button", nil, parent)
  hit:SetPoint("TOPLEFT", x, y)
  hit:SetSize(size, size)
  hit:EnableMouse(true)
  if hit.SetNormalTexture then hit:SetNormalTexture("") end
  if hit.SetPushedTexture then hit:SetPushedTexture("") end
  if hit.SetHighlightTexture then hit:SetHighlightTexture("") end
  return hit
end

local function PaintIconBorder(parent, art, size, r, g, b)
  local t = math.max(3, math.min(4, math.floor(size * 0.14 + 0.5)))
  local function edge(w, h, point)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetSize(w, h)
    tex:SetPoint(point, art, point, 0, 0)
    if tex.SetDrawLayer then tex:SetDrawLayer("OVERLAY", 6) end
    if tex.SetColorTexture then tex:SetColorTexture(r, g, b, 1) end
  end
  edge(size, t, "TOPLEFT")
  edge(size, t, "BOTTOMLEFT")
  edge(t, size, "TOPLEFT")
  edge(t, size, "TOPRIGHT")
end

local function PaintGearText(parent, width, size, self)
  local w = self.widgets
  local fs = w.text(parent, width, size)
  if fs.SetFont then
    pcall(fs.SetFont, fs, self.ThemeFont and self:ThemeFont() or STANDARD_TEXT_FONT, size, "OUTLINE")
  end
  if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0.85) end
  if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
  if self.colors then fs:SetTextColor(unpack(self.colors.text)) end
  return fs
end

local function PaintIlvlOnIcon(self, parent, art, size, ilvl, quality)
  if not ilvl then return end
  local w = self.widgets
  if not w then return end
  local fontSize = math.max(8, math.min(14, math.floor(size * 0.42)))
  local shade = parent:CreateTexture(nil, "ARTWORK")
  shade:SetSize(size, size)
  shade:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
  if shade.SetDrawLayer then shade:SetDrawLayer("ARTWORK", 1) end
  if shade.SetColorTexture then shade:SetColorTexture(0, 0, 0, 0.35) end
  local num = w.text(parent, size, fontSize)
  if num.ClearAllPoints then num:ClearAllPoints() end
  num:SetPoint("CENTER", art, "CENTER", 0, 0)
  if num.SetJustifyH then num:SetJustifyH("CENTER") end
  if num.SetJustifyV then num:SetJustifyV("MIDDLE") end
  num:SetWidth(size)
  if num.SetFont then
    pcall(num.SetFont, num, self.ThemeFont and self:ThemeFont() or STANDARD_TEXT_FONT, fontSize, "OUTLINE")
  end
  if num.SetShadowColor then num:SetShadowColor(0, 0, 0, 1) end
  if num.SetShadowOffset then num:SetShadowOffset(1, -1) end
  num:SetText(tostring(math.floor(ilvl + 0.5)))
  if self.SetFontQualityColor then
    self:SetFontQualityColor(num, quality)
  elseif self.colors then
    num:SetTextColor(unpack(self.colors.text))
  end
end

function LS:PaintGearSlotIcon(parent, x, y, slotID, size, focus)
  local w = self.widgets
  if not w then return end
  local detail = self:GearSlotDetail(slotID) or { slot = slotID, label = "Slot" }

  local art = parent:CreateTexture(nil, "ARTWORK")
  art:SetSize(size, size)
  art:SetPoint("TOPLEFT", x, y)
  if detail.icon and art.SetTexture then pcall(art.SetTexture, art, detail.icon) end
  if (not detail.icon) and art.SetColorTexture and self.colors then
    art:SetColorTexture(unpack(self.colors.panel or self.colors.card))
  end
  if art.SetDrawLayer then art:SetDrawLayer("ARTWORK", 0) end

  if detail.missingEnchant then
    local wr, wg, wb = self:MissingEnchantColor()
    PaintIconBorder(parent, art, size, wr, wg, wb)
  else
    local quality = detail.quality
    if quality == nil and GetInventoryItemQuality then
      quality = GetInventoryItemQuality("player", slotID)
    end
    if detail.link and quality ~= nil then
      local qr, qg, qb = self:QualityColor(quality)
      if qr and qg and qb then PaintIconBorder(parent, art, size, qr, qg, qb) end
    elseif not detail.link and self.colors and self.colors.muted then
      PaintIconBorder(parent, art, size, unpack(self.colors.muted))
    end
  end

  if focus and self.colors and self.colors.accent then
    local t = math.max(2, math.floor(size * 0.08))
    local ar, ag, ab = unpack(self.colors.accent)
    local function ring(w, h, point, ox, oy)
      local tex = parent:CreateTexture(nil, "OVERLAY")
      tex:SetSize(w, h)
      tex:SetPoint(point, art, point, ox or 0, oy or 0)
      if tex.SetDrawLayer then tex:SetDrawLayer("OVERLAY", 7) end
      if tex.SetColorTexture then tex:SetColorTexture(ar, ag, ab, 1) end
    end
    local pad = 2
    ring(size + pad * 2, t, "TOPLEFT", -pad, pad)
    ring(size + pad * 2, t, "BOTTOMLEFT", -pad, -pad)
    ring(t, size + pad * 2, "TOPLEFT", -pad, pad)
    ring(t, size + pad * 2, "TOPRIGHT", pad, pad)
  end

  if detail.ilvl and detail.link then
    local quality = detail.quality
    if quality == nil and GetInventoryItemQuality then
      quality = GetInventoryItemQuality("player", slotID)
    end
    PaintIlvlOnIcon(self, parent, art, size, detail.ilvl, quality)
  end

  if detail.emptySocket then
    local mark = math.max(6, math.floor(size * 0.28))
    local caution = parent:CreateTexture(nil, "OVERLAY")
    caution:SetSize(mark, mark)
    caution:SetPoint("TOPRIGHT", art, "TOPRIGHT", 2, -1)
    if caution.SetDrawLayer then caution:SetDrawLayer("OVERLAY", 7) end
    if caution.SetTexture then caution:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew") end
  elseif (detail.gemCount or 0) > 0 then
    local gem = PaintGearText(parent, size, 8, self)
    gem:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 0, 0)
    gem:SetText("◆")
    gem:SetTextColor(0.2, 0.95, 0.35, 1)
  end

  if detail.upgradeable then
    local mark = parent:CreateTexture(nil, "OVERLAY")
    mark:SetSize(7, 7)
    mark:SetPoint("TOPLEFT", art, "TOPLEFT", 1, -1)
    if mark.SetDrawLayer then mark:SetDrawLayer("OVERLAY", 7) end
    if mark.SetColorTexture then mark:SetColorTexture(0.2, 0.85, 0.35, 1) end
  elseif detail.bis and detail.bis.status == "upgrade" then
    local mark = parent:CreateTexture(nil, "OVERLAY")
    mark:SetSize(7, 7)
    mark:SetPoint("TOPLEFT", art, "TOPLEFT", 1, -1)
    if mark.SetDrawLayer then mark:SetDrawLayer("OVERLAY", 7) end
    if mark.SetColorTexture then mark:SetColorTexture(0.95, 0.75, 0.15, 1) end
  elseif detail.missingEnchant then
    local mark = PaintGearText(parent, size, 7, self)
    mark:SetPoint("TOPLEFT", art, "TOPLEFT", 2, -2)
    mark:SetText("E")
    mark:SetTextColor(1, 0.35, 0.25, 1)
  end

  local hit = GearHit(parent, x, y, size)
  hit:SetScript("OnMouseUp", function()
    self.gearFocusSlot = slotID
    self:ShowPage("GEAR")
  end)
  if self.HoverTip then
    self:HoverTip(hit, function(tip)
      if tip.SetInventoryItem then
        local ok = pcall(tip.SetInventoryItem, tip, "player", slotID)
        if ok then return end
      end
      tip:SetText(detail.name or detail.label)
      if tip.AddLine then
        if detail.ilvl then tip:AddLine("Item level " .. math.floor(detail.ilvl + 0.5)) end
        local status = self:GearSlotStatusText(detail)
        if status and status ~= "Empty" then tip:AddLine(status) end
        if detail.upgradeLabel then tip:AddLine(detail.upgradeLabel) end
        if detail.bis and detail.bis.bisName and detail.bis.status == "upgrade" then
          tip:AddLine("BiS: " .. detail.bis.bisName)
        end
      end
    end)
  end
end

function LS:PaintGearPlayerModel(parent, x, y, box)
  local w = self.widgets
  box = math.max(100, box or 160)

  local modelPanel = w.panel(parent)
  modelPanel:SetPoint("TOPLEFT", x, y)
  modelPanel:SetSize(box, box)
  if modelPanel.SetClipsChildren then modelPanel:SetClipsChildren(true) end
  w.paint(modelPanel, "card")

  if not CreateFrame then return modelPanel, box end

  local viewport = CreateFrame("Frame", nil, modelPanel)
  viewport:SetSize(box, box)
  viewport:SetPoint("CENTER", modelPanel, "CENTER", 0, 0)
  if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end

  local model = CreateFrame("DressUpModel", nil, viewport)
  if not model then model = CreateFrame("PlayerModel", nil, viewport) end
  if not model then return modelPanel, box end

  local inset = 4
  local inner = box - inset * 2
  model:SetSize(inner, inner)
  model:SetPoint("CENTER", viewport, "CENTER", 0, 0)
  if model.EnableMouse then model:EnableMouse(false) end
  if model.SetFrameLevel then model:SetFrameLevel(viewport:GetFrameLevel() + 2) end
  if model.SetKeepModelOnHide then model:SetKeepModelOnHide(true) end
  if model.SetUseModelCenterToTransform then pcall(model.SetUseModelCenterToTransform, model, true) end
  pcall(function() model:SetUnit("player") end)
  if model.RefreshUnit then pcall(model.RefreshUnit, model) end
  if model.SetFacing then pcall(model.SetFacing, model, 0.45)
  else pcall(function() model:SetRotation(0.45) end) end
  if model.SetPosition then pcall(model.SetPosition, model, 0, 0, 0) end
  if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale, model, 1.0) end
  if model.SetPortraitZoom and model:GetObjectType() == "PlayerModel" then
    pcall(model.SetPortraitZoom, model, 0)
  end
  return modelPanel, box
end

function LS:PaintGearSpecPortrait(parent, x, y, box)
  local w = self.widgets
  box = math.max(100, box or 160)

  local panel = w.panel(parent)
  panel:SetPoint("TOPLEFT", x, y)
  panel:SetSize(box, box)
  w.paint(panel, "card")

  local icon = panel:CreateTexture(nil, "ARTWORK")
  local size = math.floor(box * 0.62)
  icon:SetSize(size, size)
  icon:SetPoint("CENTER", panel, "CENTER", 0, 0)
  local tex = "Interface\\Icons\\INV_Misc_QuestionMark"
  if GetSpecialization and GetSpecializationInfo then
    local spec = GetSpecialization()
    if spec then
      local ok, _, _, specIcon = pcall(GetSpecializationInfo, spec)
      if ok and specIcon then tex = specIcon end
    end
  end
  if tex == "Interface\\Icons\\INV_Misc_QuestionMark" and UnitClass then
    local _, classFile = UnitClass("player")
    if classFile then tex = "Interface\\Icons\\ClassIcon_" .. classFile end
  end
  if icon.SetTexture then pcall(icon.SetTexture, icon, tex) end
  return panel, box
end

function LS:GearSlotStatusText(detail)
  if not detail or not detail.link then return "Empty" end
  local parts = {}
  if detail.quality and self.QualityColor then
    local r, g, b = self:QualityColor(detail.quality)
    if r then
      local q = ({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom" })
      table.insert(parts, q[detail.quality + 1] or "Gear")
    end
  end
  if detail.ilvl then table.insert(parts, tostring(math.floor(detail.ilvl + 0.5)) .. " ilvl") end
  if detail.missingEnchant then table.insert(parts, "no enchant")
  elseif detail.enchanted then table.insert(parts, "enchanted") end
  if detail.emptySocket then table.insert(parts, "empty socket")
  elseif (detail.gemCount or 0) > 0 then table.insert(parts, detail.gemCount .. " gem" .. (detail.gemCount == 1 and "" or "s"))
  elseif detail.link and not detail.emptySocket then
    -- no empty socket flag and no gems — omit socket line
  end
  if detail.bis then
    if detail.bis.status == "bis" then table.insert(parts, "BiS")
    elseif detail.bis.status == "upgrade" then table.insert(parts, "not BiS") end
  end
  return table.concat(parts, " · ")
end

function LS:PaintStatDRBar(parent, width, y, row, compact, rowPitch)
  local w = self.widgets
  local padX = 8
  local labelW = compact and 76 or 92
  local barH = 8
  rowPitch = rowPitch or (compact and 30 or 34)
  local label = compact and PaintGearText(parent, labelW, 10, self) or w.text(parent, labelW, compact and 10 or 11)
  label:SetPoint("TOPLEFT", padX, y)
  label:SetText(row.label or "Stat")
  if self.colors then label:SetTextColor(unpack(self.colors.accent)) end

  local barX = padX + labelW + 4
  local barW = width - barX - padX
  local fillPct = 0
  if row.bracketMax and row.bracketMax > 0 then
    fillPct = math.min(1, (row.bracketRating or 0) / row.bracketMax)
  end

  local track = parent:CreateTexture(nil, "ARTWORK")
  track:SetSize(math.max(8, barW), barH)
  track:SetPoint("TOPLEFT", barX, y - 2)
  if track.SetDrawLayer then track:SetDrawLayer("ARTWORK", 1) end
  if track.SetColorTexture then
    local tc = self.colors and (self.colors.border or self.colors.panel) or { 0.15, 0.15, 0.17 }
    track:SetColorTexture(tc[1], tc[2], tc[3], 1)
  end

  local inner = math.max(0, math.floor((barW - 2) * fillPct + 0.5))
  if inner > 0 then
    local fill = parent:CreateTexture(nil, "ARTWORK")
    fill:SetSize(inner, math.max(2, barH - 2))
    fill:SetPoint("TOPLEFT", barX + 1, y - 3)
    if fill.SetDrawLayer then fill:SetDrawLayer("ARTWORK", 3) end
    local ac = self.colors and self.colors.accent or { 0.35, 0.85, 0.79 }
    local fr, fg, fb = ac[1], ac[2], ac[3]
    if (row.penalty or 0) >= 0.3 then fr, fg, fb = 1, 0.45, 0.2
    elseif (row.penalty or 0) > 0 then fr, fg, fb = 1, 0.82, 0.2 end
    fill:SetColorTexture(fr, fg, fb, 1)
  end

  if row.percent then
    local pct = PaintGearText(parent, labelW, 11, self)
    pct:SetPoint("TOPLEFT", padX, y - 12)
    pct:SetText(string.format("%.2f%%", row.percent))
    if self.colors then pct:SetTextColor(unpack(self.colors.text)) end
  end

  local cap = compact and PaintGearText(parent, barW, 9, self) or w.text(parent, barW, 9)
  cap:SetPoint("TOPLEFT", barX, y - (compact and 12 or 14))
  if cap.SetJustifyH then cap:SetJustifyH("RIGHT") end
  if self.colors then cap:SetTextColor(unpack(self.colors.muted)) end
  cap:SetText(string.format("%d/%d  %s", row.bracketRating or 0, row.bracketMax or 0,
    self:StatPenaltyLabel(row.penalty) or ""))

  if not compact then
    local foot = w.text(parent, width - padX * 2, 9)
    foot:SetPoint("TOPLEFT", barX, y - 24)
    if self.colors then foot:SetTextColor(unpack(self.colors.muted)) end
    foot:SetText(string.format("%d rating · %d effective · %d lost",
      row.baseRating or 0, row.trueRating or 0, row.lostRating or 0))
  end
  return y - rowPitch - 2
end

function LS:PaintStatValueRow(parent, width, y, row, rowPitch)
  local padX = 8
  local labelW = 76
  rowPitch = rowPitch or 26
  local label = PaintGearText(parent, labelW, 10, self)
  label:SetPoint("TOPLEFT", padX, y)
  label:SetText(row.label or "Stat")
  if self.colors then label:SetTextColor(unpack(self.colors.accent)) end

  local val = PaintGearText(parent, width - labelW - padX * 2, 10, self)
  val:SetPoint("TOPLEFT", padX + labelW + 4, y)
  if val.SetJustifyH then val:SetJustifyH("RIGHT") end
  val:SetText(tostring(row.value or 0))
  if self.colors then val:SetTextColor(unpack(self.colors.text)) end
  return y - rowPitch - 2
end

local STAT_VALUE_PITCH, STAT_DR_PITCH = 16, 26

function LS:PaintGearStatRow(parent, width, y, row, compact, rowPitch, valuePitch)
  if row.kind == "value" then
    return self:PaintStatValueRow(parent, width, y, row, valuePitch or STAT_VALUE_PITCH)
  end
  return self:PaintStatDRBar(parent, width, y, row, compact, rowPitch or STAT_DR_PITCH)
end

-- Height the stat list needs at a given bar pitch, so containers can fit it.
function LS:GearStatRowsHeight(rows, drPitch)
  local h = 4
  for _, row in ipairs(rows or {}) do
    h = h + ((row.kind == "value") and STAT_VALUE_PITCH or (drPitch or STAT_DR_PITCH)) + 2
  end
  return h
end

function LS:GearStatDRPitch(rows, available)
  local values, bars = 0, 0
  for _, row in ipairs(rows or {}) do
    if row.kind == "value" then values = values + 1 else bars = bars + 1 end
  end
  if bars == 0 then return STAT_DR_PITCH end
  local room = available - 4 - values * (STAT_VALUE_PITCH + 2)
  return math.min(40, math.max(STAT_DR_PITCH, math.floor(room / bars) - 2))
end

local function FitBisRowName(row, listW, nameText, srcText, qualityColor)
  row.source:SetText(srcText or "")
  row.source:SetWidth(0)
  local srcW = math.min((row.source.GetStringWidth and row.source:GetStringWidth() or 0),
    math.floor(listW * 0.42))
  row.source:SetWidth(math.max(srcW, 0))
  row.name:SetWidth(math.max(listW - 26 - srcW - 8, 48))
  row.name:SetText(nameText or "")
  if qualityColor and row.name.SetTextColor then
    local r, g, b = qualityColor()
    if r then row.name:SetTextColor(r, g, b, 1) end
  end
end

function LS:PaintBisListRow(parent, x, y, listW, entry)
  local w = self.widgets
  parent._bisRows = parent._bisRows or {}
  parent._bisRowIdx = (parent._bisRowIdx or 0) + 1
  local idx = parent._bisRowIdx
  local row = parent._bisRows[idx]
  if not row then
    row = CreateFrame("Button", nil, parent)
    row:SetHeight(22)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 0, 0)
    row.name = w.text(row, listW, 10)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetJustifyH("LEFT")
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    row.source = w.text(row, listW, 9)
    row.source:SetPoint("RIGHT", 0, 0)
    row.source:SetJustifyH("RIGHT")
    if row.source.SetWordWrap then row.source:SetWordWrap(false) end
    if self.colors then row.source:SetTextColor(unpack(self.colors.muted)) end
    parent._bisRows[idx] = row
  end
  row:SetParent(parent)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", x, y)
  row:SetWidth(listW)
  row:Show()

  if entry.icon and row.icon.SetTexture then pcall(row.icon.SetTexture, row.icon, entry.icon) end
  local tag = entry.status == "bis" and "|cff90ee90BiS|r  " or "|cffffc83cNot BiS|r  "
  local nameText = tag .. (entry.name or "?")
  if entry.status ~= "bis" and entry.bisName then nameText = nameText .. "  → " .. entry.bisName end
  local qfn = entry.quality ~= nil and function() return self:QualityColor(entry.quality) end or nil
  FitBisRowName(row, listW, nameText, entry.source, qfn)
  if self.HoverTip then
    self:HoverTip(row, function(tip)
      if entry.slot and tip.SetInventoryItem and pcall(tip.SetInventoryItem, tip, "player", entry.slot) then
        return
      end
      tip:SetText(entry.name or "Item")
      if tip.AddLine and entry.source and entry.source ~= "" then
        tip:AddLine("BiS source: " .. entry.source)
      end
    end)
  end
  return y - 22
end

function LS:PaintGearStatsBlock(parent, width, startY, opts)
  opts = opts or {}
  local w = self.widgets
  local sy = startY or -8
  local settingsOpen = opts.settingsOpen
  local statRows = opts.statRows
  if statRows == nil then
    statRows = (not settingsOpen) and (self.GetGearStatPanelRows and self:GetGearStatPanelRows() or {}) or {}
  end
  local statPitch = opts.statPitch or STAT_DR_PITCH

  if settingsOpen then
    local pick = PaintGearText(parent, width - 16, 9, self)
    pick:SetPoint("TOPLEFT", 8, sy)
    if self.colors then pick:SetTextColor(unpack(self.colors.muted)) end
    pick:SetText("Pick stats, model, and which stats appear below.")
    sy = sy - 14
    local modelBtn = w.button(parent, self:GearShowModel() and "3D model: on" or "3D model: off", 96, 20, 9)
    modelBtn:SetPoint("TOPLEFT", 8, sy)
    if self:GearShowModel() then w.highlight(modelBtn) end
    modelBtn:SetScript("OnMouseUp", function() self:ToggleGearShowModel() end)
    sy = sy - 24
    local shortLabels = {
      primary = "Primary", stamina = "Stamina",
      crit = "Crit", haste = "Haste", mastery = "Mastery", vers = "Vers",
      leech = "Leech", avoid = "Avoid", speed = "Speed",
    }
    local specs = { { id = "primary" }, { id = "stamina" } }
    for _, spec in ipairs(self.STAT_DR_SPECS or {}) do table.insert(specs, spec) end
    for i, spec in ipairs(specs) do
      local on = self:GearStatEnabled(spec.id)
      local toggle = w.button(parent, shortLabels[spec.id] or spec.id, 52, 20, 9)
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      toggle:SetPoint("TOPLEFT", 8 + col * 56, sy - row * 22)
      if on then w.highlight(toggle) end
      toggle:SetScript("OnMouseUp", function() self:ToggleGearStat(spec.id) end)
    end
    return sy - math.ceil(#specs / 2) * 22 - 8, #statRows
  end

  sy = sy - 4
  for _, row in ipairs(statRows) do
    sy = self:PaintGearStatRow(parent, width - 16, sy, row, opts.compact ~= false, statPitch)
  end
  return sy, #statRows
end

local STAT_TRACK_HEADER = 28
local STAT_TRACK_FOOTER = 18
local STAT_TRACK_MIN_W, STAT_TRACK_MIN_H = 240, 120
local SIZE_GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber"

function LS:SaveStatTrackLayout()
  local f = self.statTrackFrame
  if not f or not self.db then return end
  self.db.gear = self.db.gear or {}
  local layout = self.db.gear.statTrack or {}
  local point, _, relPoint, x, y = f:GetPoint(1)
  layout.point = point
  layout.relPoint = relPoint or point
  layout.x = x
  layout.y = y
  layout.width = f:GetWidth()
  layout.height = f:GetHeight()
  self.db.gear.statTrack = layout
end

function LS:ApplyStatTrackLayout()
  local f = self.statTrackFrame
  local layout = self.db and self.db.gear and self.db.gear.statTrack
  if not f or not layout then return end
  f:SetSize(layout.width or 260, layout.height or 220)
  f:ClearAllPoints()
  f:SetPoint(layout.point or "CENTER", UIParent, layout.relPoint or "CENTER", layout.x or 0, layout.y or 0)
end

function LS:EnsureStatTrackFrame()
  if self.statTrackFrame then return self.statTrackFrame end
  if not CreateFrame or not UIParent then return end
  local w = self.widgets
  local f = w.panel(UIParent)
  f:SetSize(260, 240)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:SetResizable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(selfFrame)
    if not InCombatLockdown or not InCombatLockdown() then selfFrame:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(selfFrame)
    selfFrame:StopMovingOrSizing()
    LS:SaveStatTrackLayout()
  end)
  if f.SetResizeBounds then
    f:SetResizeBounds(STAT_TRACK_MIN_W, STAT_TRACK_MIN_H, 520, 640)
  end

  f.title = w.text(f, 160, 11)
  f.title:SetPoint("TOPLEFT", 10, -8)
  f.title:SetText("Character stats")

  f.close = w.button(f, "×", 22, 18)
  f.close:SetPoint("TOPRIGHT", -6, -5)
  f.close:SetScript("OnMouseUp", function() LS:ToggleStatTrack(false) end)

  f.body = CreateFrame("Frame", nil, f)
  f.body:SetPoint("TOPLEFT", 8, -STAT_TRACK_HEADER)
  f.body:SetPoint("BOTTOMRIGHT", -8, STAT_TRACK_FOOTER)
  f:SetScript("OnSizeChanged", function()
    if LS.statTrackFrame and LS.statTrackFrame:IsShown() then LS:RefreshStatTrack() end
  end)

  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  if grip.SetFrameLevel then grip:SetFrameLevel(f:GetFrameLevel() + 5) end
  if grip.SetNormalTexture then
    grip:SetNormalTexture(SIZE_GRIP .. "-Up")
    grip:SetHighlightTexture(SIZE_GRIP .. "-Highlight")
    grip:SetPushedTexture(SIZE_GRIP .. "-Down")
  end
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    LS:SaveStatTrackLayout()
    LS:RefreshStatTrack()
  end)
  grip:SetScript("OnEnter", function(selfGrip)
    if not GameTooltip then return end
    pcall(GameTooltip.SetOwner, GameTooltip, selfGrip, "ANCHOR_RIGHT")
    GameTooltip:SetText("Drag to resize")
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
  f.grip = grip

  self.statTrackFrame = f
  self:ApplyStatTrackLayout()
  return f
end

function LS:ToggleStatTrack(show)
  local f = self:EnsureStatTrackFrame()
  if not f then return end
  if show == nil then show = not f:IsShown() end
  self.db.gear = self.db.gear or {}
  self.db.gear.statTrackOpen = show and true or false
  if show then
    f:Show()
    self:RefreshStatTrack()
  else
    f:Hide()
  end
end

function LS:RefreshStatTrack()
  local f = self.statTrackFrame
  if not f or not f:IsShown() then return end
  local w = self.widgets
  if w and w.paint then w.paint(f, "panel") end
  if f.title and self.colors then f.title:SetTextColor(unpack(self.colors.accent)) end
  if w and w.paint and f.close then w.paint(f.close, "panel") end

  local body = f.body
  if not body then return end
  for _, kid in ipairs({ body:GetChildren() }) do
    kid:Hide()
    kid:SetParent(nil)
  end
  for _, region in ipairs({ body:GetRegions() }) do
    region:Hide()
  end

  local rows = (self.GetGearStatPanelRows and self:GetGearStatPanelRows() or {})
  local chrome = STAT_TRACK_HEADER + STAT_TRACK_FOOTER
  local needH = chrome + self:GearStatRowsHeight(rows) + 4
  if f.SetResizeBounds then
    f:SetResizeBounds(STAT_TRACK_MIN_W, math.max(STAT_TRACK_MIN_H, needH), 560, math.max(needH, 720))
  end
  if (f:GetHeight() or 0) < needH then f:SetHeight(needH) end
  if (f:GetWidth() or 0) < STAT_TRACK_MIN_W then f:SetWidth(STAT_TRACK_MIN_W) end

  local width = math.max(STAT_TRACK_MIN_W - 16, (f:GetWidth() or 260) - 16)
  local available = (f:GetHeight() or needH) - chrome
  local statPitch = self:GearStatDRPitch(rows, available)
  self:PaintGearStatsBlock(body, width + 16, 0, { compact = true, statPitch = statPitch, statRows = rows })
end

function LS:GearPage()
  if self.IsEndgameLevel and not self:IsEndgameLevel() then
    local cap = self:EndgameLevel()
    self:Heading("Gear", "Opens at level " .. cap)
    return
  end

  local levels = self.PlayerItemLevels and self:PlayerItemLevels() or {}
  local avg = levels.equipped and math.floor(levels.equipped + 0.5) or nil
  local upgrades = self:GearUpgradeCount()
  local bisSummary = self.GetSpecBisSummary and self:GetSpecBisSummary()
  local subtitle = (avg and (avg .. " ilvl") or "Your gear")
    .. string.format(" · %d crest upgrade%s left", upgrades, upgrades == 1 and "" or "s")
  if bisSummary then
    subtitle = subtitle .. string.format(" · BiS %d/%d", bisSummary.bis or 0, bisSummary.total or 0)
  end
  self:Heading("Gear", subtitle)

  local body = self:Body(96)
  local w = self.widgets
  local width = body.width
  local viewH = self.bodyScroll and self.bodyScroll:GetHeight() or 0
  local y = 0
  local focus = self.gearFocusSlot
  local pad = 10
  local gap = 12
  local topY = -pad

  local statsW = math.min(400, math.max(240, math.floor(width * 0.34)))
  local stacked = width < 560
  if stacked then statsW = width end

  local armoryW = stacked and width or (width - gap - statsW)
  local slotsRows = #self.GEAR_ARMORY_LEFT
  local slotGap = 4
  local iconSize = width < 520 and 34 or 38
  local slotPitch = iconSize + slotGap

  local footerReserve = 140
  if viewH > footerReserve + 220 then
    local slotArea = viewH - footerReserve - pad * 2 - 18
    slotPitch = math.max(34, math.min(56, math.floor(slotArea / slotsRows)))
    iconSize = slotPitch - slotGap
  end

  local slotsH = slotsRows * slotPitch - slotGap
  local weaponRowY = topY - (slotsRows - 1) * slotPitch
  local modelY = topY - slotPitch
  local modelBox = armoryW - (2 * pad + 2 * iconSize + 16)
  local modelCap = width > 920 and 400 or (width > 720 and 340 or 280)
  modelBox = math.max(120, math.min(modelCap, modelBox))
  modelBox = math.min(modelBox, math.max(120, (slotsRows - 2) * slotPitch))
  if armoryW > 2 * pad + 2 * iconSize + modelBox + 16 + 40 then
    iconSize = math.min(44, iconSize + 2)
    slotPitch = iconSize + slotGap
    slotsH = slotsRows * slotPitch - slotGap
    weaponRowY = topY - (slotsRows - 1) * slotPitch
    modelY = topY - slotPitch
    modelBox = math.min(modelCap, armoryW - (2 * pad + 2 * iconSize + 16))
    modelBox = math.min(modelBox, math.max(120, (slotsRows - 2) * slotPitch))
  end
  local armoryH = pad + slotsH + pad + 18

  local armoryPanel = w.panel(body)
  armoryPanel:SetPoint("TOPLEFT", 0, y)
  armoryPanel:SetSize(armoryW, armoryH)
  w.paint(armoryPanel, "panel")

  local leftX = pad
  local rightX = armoryW - pad - iconSize
  local innerLeft = pad + iconSize + 8
  local innerRight = armoryW - pad - iconSize - 8
  local centerW = innerRight - innerLeft
  modelBox = math.min(modelBox, math.max(120, centerW))
  local modelX = innerLeft + math.floor((centerW - modelBox) / 2)

  for i, slotID in ipairs(self.GEAR_ARMORY_LEFT) do
    self:PaintGearSlotIcon(armoryPanel, leftX, topY - (i - 1) * slotPitch, slotID, iconSize, slotID == focus)
  end
  for i, slotID in ipairs(self.GEAR_ARMORY_RIGHT) do
    self:PaintGearSlotIcon(armoryPanel, rightX, topY - (i - 1) * slotPitch, slotID, iconSize, slotID == focus)
  end

  local centerFrame
  if self:GearShowModel() then
    centerFrame = self:PaintGearPlayerModel(armoryPanel, modelX, modelY, modelBox)
  else
    centerFrame = self:PaintGearSpecPortrait(armoryPanel, modelX, modelY, modelBox)
  end
  if avg and centerFrame then
    local ilvlTag = PaintGearText(armoryPanel, modelBox, 11, self)
    ilvlTag:SetPoint("TOP", centerFrame, "BOTTOM", 0, -2)
    if ilvlTag.SetJustifyH then ilvlTag:SetJustifyH("CENTER") end
    if self.colors then ilvlTag:SetTextColor(unpack(self.colors.accent)) end
    ilvlTag:SetText(avg .. " ilvl")
  end

  local weaponSpan = iconSize * 2 + slotGap
  local weaponX = modelX + math.floor((modelBox - weaponSpan) / 2)
  for i, slotID in ipairs(self.GEAR_ARMORY_WEAPONS) do
    self:PaintGearSlotIcon(armoryPanel, weaponX + (i - 1) * (iconSize + slotGap), weaponRowY, slotID, iconSize, slotID == focus)
  end

  local bisRows = self:HasSpecBisTooltip() and (self.SpecBisListRows and self:SpecBisListRows() or {}) or {}
  local bisPanelH = 0
  local bisPanel
  if self:HasSpecBisTooltip() then
    bisPanelH = 30 + math.max(1, #bisRows) * 22 + 8
    bisPanel = w.panel(body)
    if stacked then
      bisPanel:SetPoint("TOPLEFT", 0, -armoryH - gap)
      bisPanel:SetSize(width, bisPanelH)
    else
      bisPanel:SetPoint("TOPLEFT", 0, -armoryH - gap)
      bisPanel:SetSize(armoryW, bisPanelH)
    end
    w.paint(bisPanel, "panel")
    local bisHead = PaintGearText(bisPanel, armoryW - 16, 11, self)
    bisHead:SetPoint("TOPLEFT", 10, -8)
    if self.colors then bisHead:SetTextColor(unpack(self.colors.accent)) end
    local content = ({ BISO = "Overall", BISR = "Raid", BISM = "Mythic+" })[SBTTAB and SBTTAB.PREFERREDCONTENT or "BISO"]
    bisHead:SetText("BiS · SpecBiS Tooltip" .. (content and (" · " .. content) or ""))
    local listW = (stacked and width or armoryW) - 20
    local by = -28
    bisPanel._bisRowIdx = 0
    if #bisRows == 0 then
      local wait = PaintGearText(bisPanel, listW, 10, self)
      wait:SetPoint("TOPLEFT", 10, by)
      if self.colors then wait:SetTextColor(unpack(self.colors.muted)) end
      wait:SetText("SpecBiS Tooltip has no answer for your gear yet. It loads a moment after login; reopen this page.")
    end
    for _, entry in ipairs(bisRows) do
      by = self:PaintBisListRow(bisPanel, 10, by, listW, entry)
    end
  end

  local settingsOpen = self:GearStatSettingsOpen()
  local statRows = (not settingsOpen) and (self.GetGearStatPanelRows and self:GetGearStatPanelRows() or {}) or {}
  local statsHeadH = 32
  local statsContentH = settingsOpen and 190 or (statsHeadH + self:GearStatRowsHeight(statRows) + 8)
  local columnH = armoryH + (bisPanelH > 0 and bisPanelH + gap or 0)
  local statsPanelH = stacked and statsContentH or math.max(columnH, statsContentH)
  local statPitch = self:GearStatDRPitch(statRows, statsPanelH - statsHeadH - 8)

  local statsPanel = w.panel(body)
  if stacked then
    local statsY = -(armoryH + gap + bisPanelH + (bisPanelH > 0 and gap or 0))
    statsPanel:SetPoint("TOPLEFT", 0, statsY)
    statsPanel:SetSize(width, statsPanelH)
  else
    statsPanel:SetPoint("TOPLEFT", armoryW + gap, 0)
    statsPanel:SetSize(statsW, statsPanelH)
  end
  w.paint(statsPanel, "panel")

  y = y - math.max(columnH, statsPanelH) - 10

  local sy = -8
  local head = PaintGearText(statsPanel, statsW - 100, 12, self)
  head:SetPoint("TOPLEFT", 8, sy)
  if self.colors then head:SetTextColor(unpack(self.colors.accent)) end
  head:SetText("Character stats")

  local trackBtn = w.button(statsPanel, "Track", 52, 22, 9)
  trackBtn:SetPoint("TOPRIGHT", -76, sy + 2)
  w.paint(trackBtn, "panel")
  trackBtn:SetScript("OnMouseUp", function() self:ToggleStatTrack(true) end)

  local settingsBtn = w.button(statsPanel, settingsOpen and "Done" or "Settings", 64, 22, 9)
  settingsBtn:SetPoint("TOPRIGHT", -8, sy + 2)
  w.paint(settingsBtn, "panel")
  if settingsOpen then w.highlight(settingsBtn) end
  settingsBtn:SetScript("OnMouseUp", function() self:ToggleGearStatSettings() end)

  self:PaintGearStatsBlock(statsPanel, stacked and width or statsW, sy - 24, {
    settingsOpen = settingsOpen,
    statRows = statRows,
    statPitch = statPitch,
    compact = true,
  })

  local contentW = width

  local chosen = focus and self:GearSlotDetail(focus) or {}
  if focus and chosen.slot then
    local card = w.panel(body)
    card:SetPoint("TOPLEFT", 0, y)
    local cardH = 52
    card:SetSize(contentW, cardH)
    w.paint(card, "panel")
    local title = PaintGearText(card, card:GetWidth() - 20, 12, self)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText((chosen.name or chosen.label) .. (chosen.ilvl and ("  ·  " .. math.floor(chosen.ilvl + 0.5)) or ""))
    if self.SetFontQualityColor then
      self:SetFontQualityColor(title, chosen.quality)
    elseif self.colors then
      title:SetTextColor(unpack(self.colors.accent))
    end
    local meta = PaintGearText(card, card:GetWidth() - 20, 10, self)
    meta:SetPoint("TOPLEFT", 10, -26)
    if self.colors then meta:SetTextColor(unpack(self.colors.muted)) end
    meta:SetText(self:GearSlotStatusText(chosen))
    if chosen.upgradeLabel then
      local up = PaintGearText(card, card:GetWidth() - 20, 10, self)
      up:SetPoint("TOPLEFT", 10, -40)
      up:SetText(chosen.upgradeLabel .. (chosen.upgradeMaxIlvl and (" → " .. chosen.upgradeMaxIlvl) or ""))
      cardH = 66
      card:SetHeight(cardH)
    end
    y = y - cardH - 8
  end

  if self:HasSpecBisTooltip() then
    local upgrades = self:SpecBisUpgradeRows()
    if #upgrades > 0 then
      y = y - 8
      local upHead = PaintGearText(body, contentW, 11, self)
      upHead:SetPoint("TOPLEFT", 0, y)
      if self.colors then upHead:SetTextColor(unpack(self.colors.muted)) end
      upHead:SetText(string.format("%d slot%s still need upgrades", #upgrades, #upgrades == 1 and "" or "s"))
      y = y - 16
    end
  else
    y = y - 4
    local note = PaintGearText(body, contentW, 10, self)
    note:SetPoint("TOPLEFT", 0, y)
    if self.colors then note:SetTextColor(unpack(self.colors.muted)) end
    note:SetText("Install SpecBiS Tooltip for BiS lists on this page.")
    y = y - 16
  end

  local openChar = w.button(body, "Character panel", 130, 26, 10)
  openChar:SetPoint("TOPLEFT", 0, y - 4)
  w.paint(openChar, "panel")
  openChar:SetScript("OnMouseUp", function()
    if self.OpenCharacter then self:OpenCharacter() end
  end)

  if self.statTrackFrame and self.statTrackFrame.IsShown and self.statTrackFrame:IsShown() then
    self:RefreshStatTrack()
  end

  body:finish(-y + 36)
end
