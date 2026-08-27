local _, LS = ...

-- Default sits on the top-left rim, where the button used to be anchored.
local DEFAULT_ANGLE = 135
local EDGE = 10

local function NormAngle(deg)
  deg = tonumber(deg) or DEFAULT_ANGLE
  deg = deg % 360
  if deg < 0 then deg = deg + 360 end
  return deg
end

local function Atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  return math.atan(y, x)
end

local function Settings(self)
  self.db = self.db or {}
  self.db.minimap = self.db.minimap or {}
  return self.db.minimap
end

function LS:MinimapButtonLocked()
  local cfg = self.db and self.db.minimap
  return not cfg or cfg.lock ~= false
end

local function Shape()
  if GetMinimapShape then
    local ok, shape = pcall(GetMinimapShape)
    if ok and type(shape) == "string" then return shape:upper() end
  end
  return "ROUND"
end

local function Offset(angle, width, height)
  local rad = math.rad(NormAngle(angle))
  local dx, dy = math.cos(rad), math.sin(rad)
  local rw = (tonumber(width) or 140) / 2 + EDGE
  local rh = (tonumber(height) or 140) / 2 + EDGE
  if Shape() == "SQUARE" then
    local sx = math.abs(dx) / math.max(rw, 1)
    local sy = math.abs(dy) / math.max(rh, 1)
    local scale = 1 / math.max(sx, sy, 1e-6)
    return dx * scale, dy * scale
  end
  return dx * rw, dy * rh
end

function LS:PlaceMinimapButton()
  local button = self.minimapButton
  if not button or not Minimap then return end
  local cfg = Settings(self)
  button:ClearAllPoints()
  if self:MinimapButtonLocked() then
    if button.SetClampedToScreen then button:SetClampedToScreen(false) end
    local x, y = Offset(cfg.angle or DEFAULT_ANGLE, Minimap:GetWidth(), Minimap:GetHeight())
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    return
  end
  if button.SetClampedToScreen then button:SetClampedToScreen(true) end
  button:SetPoint(
    cfg.point or "CENTER",
    Minimap,
    cfg.relative or "CENTER",
    tonumber(cfg.x) or 0,
    tonumber(cfg.y) or 0
  )
end

function LS:DragMinimapButton()
  if not self:MinimapButtonLocked() then return end
  local button = self.minimapButton
  if not button or not Minimap or not GetCursorPosition then return end
  local mx, my = Minimap:GetCenter()
  if not mx or not my then return end
  local cx, cy = GetCursorPosition()
  local scale = (Minimap.GetEffectiveScale and Minimap:GetEffectiveScale()) or 1
  if scale == 0 then scale = 1 end
  cx, cy = cx / scale, cy / scale
  Settings(self).angle = NormAngle(math.deg(Atan2(cy - my, cx - mx)))
  self:PlaceMinimapButton()
end

function LS:SaveMinimapButtonFree()
  local button = self.minimapButton
  if not button or not button.GetPoint then return end
  local cfg = Settings(self)
  local point, _, relative, x, y = button:GetPoint(1)
  cfg.point = point or "CENTER"
  cfg.relative = relative or "CENTER"
  cfg.x = tonumber(x) or 0
  cfg.y = tonumber(y) or 0
end

function LS:SnapMinimapButtonAngle()
  local button = self.minimapButton
  if not button or not Minimap then return end
  if not (button.GetCenter and Minimap.GetCenter) then return end
  local bx, by = button:GetCenter()
  local mx, my = Minimap:GetCenter()
  if not bx or not by or not mx or not my then return end
  Settings(self).angle = NormAngle(math.deg(Atan2(by - my, bx - mx)))
end

function LS:SetMinimapButtonLock(on)
  local cfg = Settings(self)
  local lock = on and true or false
  cfg.lock = lock
  if lock then
    self:SnapMinimapButtonAngle()
    if not cfg.angle then cfg.angle = DEFAULT_ANGLE end
  else
    self:SaveMinimapButtonFree()
  end
  self:PlaceMinimapButton()
end

function LS:CreateMinimapButton()
  if self.minimapButton or not Minimap then return end
  local button = CreateFrame("Button", "LodestarMinimapButton", Minimap)
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  if Minimap.GetFrameLevel and button.SetFrameLevel then
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  end
  if button.SetDontSavePosition then button:SetDontSavePosition(true) end
  button:RegisterForClicks("AnyUp")
  button:RegisterForDrag("LeftButton")
  button:SetMovable(true)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(LS.MEDIA_ICON or LS.MEDIA)
  icon:SetAllPoints()
  button.icon = icon

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      LS:ToggleCompact()
    else
      LS:Toggle()
    end
  end)
  button:SetScript("OnEnter", function(selfButton)
    local compactOn = LS.db and LS.db.compact and LS.db.compact.enabled
    GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
    GameTooltip:AddLine("Lodestar", 0.95, 0.72, 0.22)
    GameTooltip:AddLine("Find what matters. Ignore the rest.", 0.85, 0.9, 0.92, true)
    GameTooltip:AddLine("Left click to open.", 0.55, 0.85, 0.82)
    GameTooltip:AddLine(compactOn and "Right click to hide compact mode." or "Right click for compact mode.",
      0.55, 0.85, 0.82)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:SetScript("OnDragStart", function(selfButton)
    if LS:MinimapButtonLocked() then
      selfButton:SetScript("OnUpdate", function()
        if LS.DragMinimapButton then LS:DragMinimapButton() end
      end)
    elseif not InCombatLockdown() then
      selfButton:StartMoving()
    end
  end)
  button:SetScript("OnDragStop", function(selfButton)
    selfButton:SetScript("OnUpdate", nil)
    selfButton:StopMovingOrSizing()
    if LS:MinimapButtonLocked() then
      if LS.DragMinimapButton then LS:DragMinimapButton() end
    else
      LS:SaveMinimapButtonFree()
    end
  end)

  self.minimapButton = button
  local cfg = Settings(self)
  if cfg.lock == nil then cfg.lock = true end
  if cfg.angle == nil then cfg.angle = DEFAULT_ANGLE end
  self:PlaceMinimapButton()
end
