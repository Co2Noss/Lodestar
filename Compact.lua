local _, LS = ...

-- Compact mode: a small always-on window with the next one or two things to do.
-- One goal keeps it to a single row; more goals grow it to two. It reads the same
-- plan as the Today page, so both always agree.

local HEADER = 24
local ROW = 46
local PADDING = 8
local MIN_WIDTH, MAX_WIDTH = 220, 520
local CLICK_DELAY = 0.25

local function db()
  return LS.db and LS.db.compact
end

function LS:CompactCount()
  local settings = db()
  if settings and settings.single then return 1 end
  local n = 0
  for _, on in pairs(self.db and self.db.goals or {}) do
    if on then n = n + 1 end
  end
  if n <= 1 then return 1 end
  return 2
end

local TONES = { HIGH = "warn", MEDIUM = "accent", LOW = "muted" }
local LABELS = { HIGH = "High", MEDIUM = "Medium", LOW = "Low" }

local LEGACY = {
  NOW = "HIGH", SOON = "HIGH", ["THIS WEEK"] = "MEDIUM", ANYTIME = "LOW",
  ["FREE VALUE"] = "HIGH", ["HIGH PRIORITY"] = "HIGH", WEEKLY = "HIGH",
  ["FILL SLOT"] = "MEDIUM", ["ONE TIME"] = "LOW", OPEN = "LOW",
}

local function Rank(key)
  return LABELS[key] or key, TONES[key]
end

-- Cards rank High / Medium / Low. Score still decides order; this is only the label.
function LS:Urgency(activity)
  local stated = activity and activity.urgency
  if stated and TONES[stated] then
    return Rank(stated)
  end
  if stated and LEGACY[stated] then
    return Rank(LEGACY[stated])
  end
  local tagged = activity and activity.priority
  if tagged and TONES[tagged] then
    return Rank(tagged)
  end
  if tagged and LEGACY[tagged] then
    return Rank(LEGACY[tagged])
  end
  local score = (activity and activity.score) or 0
  if score >= 28 then return Rank("HIGH") end
  if score >= 18 then return Rank("MEDIUM") end
  return Rank("LOW")
end

-- Compact is the next action, not a second copy of the same vault row.
local function CompactFamily(activity)
  local id = (activity and activity.id) or ""
  local row = id:match("^vault_(raid)_") or id:match("^vault_(activities)_") or id:match("^vault_(world)_")
  if row then return "vault_" .. row end
  if id:find("^vault_claim_", 1, true) then return "vault_claim" end
  return activity.category or id
end

function LS:CompactActivities()
  local out, seen = {}, {}
  local wanted = self:CompactCount()
  for _, activity in ipairs(self:GetRecommendations()) do
    local family = CompactFamily(activity)
    if not seen[family] then
      seen[family] = true
      table.insert(out, activity)
      if #out >= wanted then break end
    end
  end
  return out
end

function LS:SaveCompactLayout()
  local frame = self.compact
  local settings = db()
  if not frame or not settings then return end
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  settings.point = point or "TOPRIGHT"
  settings.relative = relativePoint or "TOPRIGHT"
  settings.x = x or -20
  settings.y = y or -220
  settings.width = math.floor(frame:GetWidth() + 0.5)
end

function LS:ApplyCompactLayout()
  local frame = self.compact
  local settings = db()
  if not frame or not settings then return end
  frame:ClearAllPoints()
  frame:SetPoint(settings.point or "TOPRIGHT", UIParent,
    settings.relative or settings.point or "TOPRIGHT", settings.x or -20, settings.y or -220)
  frame:SetWidth(math.max(MIN_WIDTH, math.min(MAX_WIDTH, settings.width or 300)))
end

-- Child buttons swallow mouse input, so each one hands dragging back to the window.
local function ForwardDrag(child, frame)
  child:RegisterForDrag("LeftButton")
  child:SetScript("OnDragStart", function() frame:StartMoving() end)
  child:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    LS:SaveCompactLayout()
  end)
end

local function CreateRow(parent)
  local w = LS.widgets
  local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
  row:SetHeight(ROW - 6)
  row:RegisterForClicks("AnyUp")
  ForwardDrag(row, parent)
  row.urgency = w.text(row, 70, 10)
  row.urgency:SetPoint("TOPLEFT", 10, -8)
  row.title = w.text(row, 100, 12)
  row.title:SetPoint("TOPLEFT", 10, -21)
  row.meta = w.text(row, 100, 10)
  row.meta:SetPoint("TOPLEFT", 84, -8)
  row.meta:SetJustifyH("RIGHT")

  row:SetScript("OnEnter", function(selfRow)
    if not LS.colors then return end
    selfRow:SetBackdropBorderColor(unpack(LS.colors.accent))
  end)
  row:SetScript("OnLeave", function(selfRow)
    if not LS.colors then return end
    selfRow:SetBackdropBorderColor(unpack(LS.colors.border))
  end)

  -- A single click opens details and a double click opens the whole window, so the first
  -- click waits long enough to find out which one this is.
  row:SetScript("OnClick", function(selfRow)
    if not selfRow.activityID then return end
    if selfRow.pendingClick then selfRow.pendingClick:Cancel() end
    local id = selfRow.activityID
    selfRow.pendingClick = C_Timer.NewTimer(CLICK_DELAY, function()
      selfRow.pendingClick = nil
      LS:OpenFull("DETAILS", id)
    end)
  end)
  row:SetScript("OnDoubleClick", function(selfRow)
    if selfRow.pendingClick then
      selfRow.pendingClick:Cancel()
      selfRow.pendingClick = nil
    end
    LS:OpenFull("TODAY")
  end)
  return row
end

function LS:CreateCompact()
  if self.compact then return end
  local w = self.widgets
  local frame = w.panel(UIParent)
  self.compact = frame
  frame:SetSize(300, HEADER + ROW * 2 + PADDING)
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -220)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(selfFrame) selfFrame:StartMoving() end)
  frame:SetScript("OnDragStop", function(selfFrame)
    selfFrame:StopMovingOrSizing()
    LS:SaveCompactLayout()
  end)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(MIN_WIDTH, HEADER + 20, MAX_WIDTH, 1000)
  end
  frame:Hide()

  local logo = frame:CreateTexture(nil, "ARTWORK")
  logo:SetSize(14, 14)
  logo:SetPoint("TOPLEFT", 8, -5)
  logo:SetTexture(LS.MEDIA_ICON or LS.MEDIA)

  frame.title = w.text(frame, 140, 11)
  frame.title:SetPoint("TOPLEFT", 26, -6)
  frame.title:SetText("LODESTAR")

  frame.collapse = w.button(frame, "–", 20, 16)
  frame.collapse:SetPoint("TOPRIGHT", -30, -4)
  frame.collapse:SetScript("OnMouseUp", function()
    local settings = db()
    settings.collapsed = not settings.collapsed
    LS.compactAutoCollapsed = false
    LS:UpdateCompact()
  end)

  frame.close = w.button(frame, "×", 20, 16)
  frame.close:SetPoint("TOPRIGHT", -6, -4)
  frame.close:SetScript("OnMouseUp", function() LS:SetCompact(false) end)

  -- Height follows the number of recommendations, so only the width is draggable.
  local grip = CreateFrame("Button", nil, frame)
  grip:SetWidth(6)
  grip:SetPoint("TOPRIGHT", 0, -HEADER)
  grip:SetPoint("BOTTOMRIGHT", 0, 2)
  grip:SetScript("OnEnter", function(selfGrip)
    if LS.colors then selfGrip.hint:SetColorTexture(unpack(LS.colors.accent)) end
  end)
  grip:SetScript("OnLeave", function(selfGrip)
    if LS.colors then selfGrip.hint:SetColorTexture(unpack(LS.colors.border)) end
  end)
  grip:SetScript("OnMouseDown", function() frame:StartSizing("RIGHT") end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    LS:SaveCompactLayout()
    LS:UpdateCompact()
  end)
  grip.hint = grip:CreateTexture(nil, "OVERLAY")
  grip.hint:SetSize(2, 18)
  grip.hint:SetPoint("RIGHT", -2, 0)
  frame.grip = grip

  -- Double clicking anywhere on the window, not just a row, opens the full UI.
  local surface = CreateFrame("Button", nil, frame)
  surface:SetPoint("TOPLEFT", 0, 0)
  surface:SetPoint("BOTTOMRIGHT", 0, 0)
  surface:SetFrameLevel(frame:GetFrameLevel())
  surface:RegisterForClicks("AnyUp")
  surface:SetScript("OnDoubleClick", function() LS:OpenFull("TODAY") end)
  ForwardDrag(surface, frame)
  frame.surface = surface

  frame.rows = {}
  for i = 1, 2 do
    frame.rows[i] = CreateRow(frame)
  end

  self:ApplyCompactLayout()
end

function LS:UpdateCompact()
  local frame = self.compact
  local settings = db()
  if not frame or not settings or not self.colors then return end

  -- The two windows show the same plan, so the small one stands down while the full one
  -- is open and comes back when it closes.
  if not settings.enabled or (self.frame and self.frame:IsShown()) then
    frame:Hide()
    return
  end

  local w = self.widgets
  local palette = self.colors
  local texture = self:ThemeTexture()
  frame:SetBackdrop({ bgFile = texture, edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
  frame:SetBackdropColor(unpack(palette.bg))
  frame:SetBackdropBorderColor(unpack(palette.border))
  frame.title:SetFont(self:ThemeFont(), 11, "")
  frame.title:SetTextColor(unpack(palette.accent))

  local collapsed = settings.collapsed or self.compactAutoCollapsed
  for _, control in ipairs({ frame.collapse, frame.close }) do
    w.paint(control, "panel")
    control.text:SetFont(self:ThemeFont(), 12, "")
    control.text:SetTextColor(unpack(palette.text))
  end
  frame.collapse.text:SetText(collapsed and "+" or "–")
  frame.grip.hint:SetColorTexture(unpack(palette.border))

  local width = frame:GetWidth()
  local activities = collapsed and {} or self:CompactActivities()

  for index, row in ipairs(frame.rows) do
    local activity = activities[index]
    if not activity then
      row:Hide()
      row.activityID = nil
    else
      row.activityID = activity.id
      row:SetBackdrop({ bgFile = texture, edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
      w.paint(row)
      row:SetWidth(width - 12)
      row:SetPoint("TOPLEFT", 6, -(HEADER + (index - 1) * ROW))

      local label, tone = self:Urgency(activity)
      row.urgency:SetText(label)
      row.urgency:SetTextColor(unpack(palette[tone] or palette.text))

      row.title:SetWidth(width - 24)
      row.title:SetTextColor(unpack(palette.accent))
      row.title:SetText(activity.title)

      row.meta:SetWidth(width - 100)
      row.meta:SetTextColor(unpack(palette.muted or palette.text))
      row.meta:SetText(string.format("%s  •  score %d",
        self:FormatDuration((activity.minutes or 0) * 60), math.floor(activity.score or 0)))
      row:Show()
    end
  end

  if collapsed then
    frame:SetHeight(HEADER + 6)
    frame.grip:Hide()
    if self.compactAutoCollapsed then
      frame.title:SetText("LODESTAR  •  in combat")
    else
      frame.title:SetText("LODESTAR")
    end
  else
    frame.grip:Show()
    frame.title:SetText("LODESTAR")
    if #activities == 0 then
      frame:SetHeight(HEADER + 34)
      if not frame.empty then
        frame.empty = w.text(frame, 200, 11)
        frame.empty:SetPoint("TOPLEFT", 10, -(HEADER + 4))
      end
      frame.empty:SetWidth(width - 20)
      frame.empty:SetTextColor(unpack(palette.muted or palette.text))
      frame.empty:SetText("Nothing to recommend right now.")
      frame.empty:Show()
    else
      if frame.empty then frame.empty:Hide() end
      frame:SetHeight(HEADER + #activities * ROW + PADDING)
    end
  end

  frame:Show()
end

function LS:SetCompact(enabled)
  local settings = db()
  if not settings then return end
  settings.enabled = enabled and true or false
  if settings.enabled then
    self:CreateCompact()
    self.compactAutoCollapsed = false
  end
  self:UpdateCompact()
  if self.frame and self.frame:IsShown() and self.page == "SETTINGS" then
    self:ShowPage("SETTINGS")
  end
end

function LS:ToggleCompact()
  local settings = db()
  if not settings then return end
  self:SetCompact(not settings.enabled)
end

function LS:SetCompactSingle(single)
  local settings = db()
  if not settings then return end
  settings.single = single and true or false
  self:UpdateCompact()
end

function LS:ResetCompactLayout()
  local settings = db()
  if not settings then return end
  settings.point, settings.relative = "TOPRIGHT", "TOPRIGHT"
  settings.x, settings.y, settings.width = -20, -220, 300
  self:ApplyCompactLayout()
  self:UpdateCompact()
end

-- Collapse to the title bar in combat, then restore whatever state it was in before.
function LS:CompactCombat(inCombat)
  local settings = db()
  if not settings or not settings.enabled then return end
  if inCombat then
    if not settings.collapsed then
      self.compactAutoCollapsed = true
    end
  else
    self.compactAutoCollapsed = false
  end
  self:UpdateCompact()
end
