local _, LS = ...

local tabs = {
  { "TODAY", "Today" },
  { "VAULT", "Great Vault" },
  { "PROFESSIONS", "Professions" },
  { "WARBAND", "Warband" },
  { "SETTINGS", "Settings" },
}

local goalList = {
  { "ENDGAME", "Great Vault & endgame" },
  { "SOLO", "Solo content" },
  { "CRAFTING", "Professions" },
  { "MOUNTS", "Mounts" },
  { "REPUTATION", "Reputation" },
  { "QUESTING", "Questing" },
}

local function text(parent, width, size)
  local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fontString:SetFont(LS:ThemeFont(), size or 12, "")
  fontString:SetWidth(width)
  fontString:SetJustifyH("LEFT")
  fontString:SetJustifyV("TOP")
  if LS.colors then fontString:SetTextColor(unpack(LS.colors.text)) end
  return fontString
end

local function panel(parent)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetBackdrop({ bgFile = LS:ThemeTexture(), edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
  return frame
end

local function paint(frame, key)
  if not frame or not LS.colors then return end
  frame:SetBackdropColor(unpack(LS.colors[key or "card"]))
  frame:SetBackdropBorderColor(unpack(LS.colors.border))
end

local function button(parent, label, width, height)
  local frame = panel(parent)
  frame:SetSize(width or 130, height or 34)
  frame.text = text(frame, width or 130, 12)
  frame.text:SetPoint("CENTER")
  frame.text:SetJustifyH("CENTER")
  frame.text:SetText(label)
  frame:EnableMouse(true)
  paint(frame)
  frame:SetScript("OnEnter", function(selfFrame)
    selfFrame:SetBackdropBorderColor(unpack(LS.colors.accent))
  end)
  frame:SetScript("OnLeave", function(selfFrame)
    selfFrame:SetBackdropBorderColor(unpack(LS.colors.border))
  end)
  return frame
end

local function highlight(frame)
  if not frame or not LS.colors then return end
  frame:SetBackdropColor(unpack(LS.colors.card))
  frame:SetBackdropBorderColor(unpack(LS.colors.accent))
  if frame.text then frame.text:SetTextColor(unpack(LS.colors.accent)) end
end

-- Shared so other files build widgets that pick up the active theme automatically.
LS.widgets = { text = text, panel = panel, paint = paint, button = button, highlight = highlight }

function LS:ContentWidth()
  return math.max(420, (self.content and self.content:GetWidth() or 700) - 4)
end

function LS:Clear()
  for _, child in ipairs({ self.content:GetChildren() }) do
    if child.menu then child.menu:Hide() end
    child:Hide()
    child:SetParent(nil)
  end
  for _, region in ipairs({ self.content:GetRegions() }) do
    region:Hide()
  end
end

function LS:SaveFrameLayout()
  local frame = self.frame
  if not frame or not self.db then return end
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  self.db.frame = {
    point = point or "CENTER",
    relative = relativePoint or "CENTER",
    x = x or 0,
    y = y or 0,
    width = math.floor(frame:GetWidth() + 0.5),
    height = math.floor(frame:GetHeight() + 0.5),
  }
end

function LS:ApplyFrameLayout()
  local saved = self.db and self.db.frame
  if not saved then return end
  self.frame:ClearAllPoints()
  self.frame:SetPoint(saved.point or "CENTER", UIParent, saved.relative or saved.point or "CENTER", saved.x or 0, saved.y or 0)
  self.frame:SetSize(saved.width or 960, saved.height or 680)
end

function LS:CreateUI()
  local frame = panel(UIParent)
  self.frame = frame
  frame:SetSize(960, 680)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(selfFrame)
    if not InCombatLockdown() then selfFrame:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function(selfFrame)
    selfFrame:StopMovingOrSizing()
    LS:SaveFrameLayout()
  end)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(640, 460, 1600, 1100)
  end
  -- Compact mode hides itself while this window is open, so both states have to tell it.
  frame:SetScript("OnShow", function()
    if LS.UpdateCompact then LS:UpdateCompact() end
  end)
  frame:SetScript("OnHide", function()
    if LS.UpdateCompact then LS:UpdateCompact() end
  end)
  frame:Hide()

  self.header = panel(frame)
  self.header:SetPoint("TOPLEFT", 1, -1)
  self.header:SetPoint("TOPRIGHT", -1, -1)
  self.header:SetHeight(54)

  self.logo = self.header:CreateTexture(nil, "ARTWORK")
  self.logo:SetSize(40, 40)
  self.logo:SetPoint("LEFT", 10, 0)
  self.logo:SetTexture(LS.MEDIA)

  self.title = self.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.title:SetFont(STANDARD_TEXT_FONT, 20, "")
  self.title:SetPoint("LEFT", self.logo, "RIGHT", 10, 7)
  self.title:SetText("LODESTAR")

  self.subtitle = self.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.subtitle:SetFont(STANDARD_TEXT_FONT, 11, "")
  self.subtitle:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -3)
  self.subtitle:SetText("Find what matters. Ignore the rest.")

  local close = button(self.header, "×", 34, 30)
  close:SetPoint("RIGHT", -10, 0)
  close:SetScript("OnMouseUp", function() frame:Hide() end)
  close.text:SetFont(self:ThemeFont(), 20, "")
  -- The glyph sits high in its font, so nudge it back onto the centre of the button.
  close.text:ClearAllPoints()
  close.text:SetPoint("CENTER", 0, 2)
  close:SetScript("OnEnter", function(selfFrame)
    selfFrame:SetBackdropBorderColor(unpack(LS.colors.warn or LS.colors.accent))
    selfFrame.text:SetTextColor(unpack(LS.colors.warn or LS.colors.accent))
  end)
  close:SetScript("OnLeave", function(selfFrame)
    selfFrame:SetBackdropBorderColor(unpack(LS.colors.border))
    selfFrame.text:SetTextColor(unpack(LS.colors.text))
  end)
  self.closeButton = close

  self.sidebar = panel(frame)
  self.sidebar:SetPoint("TOPLEFT", 12, -68)
  self.sidebar:SetPoint("BOTTOMLEFT", 12, 14)
  self.sidebar:SetWidth(165)

  self.content = CreateFrame("Frame", nil, frame)
  self.content:SetPoint("TOPLEFT", 195, -76)
  self.content:SetPoint("BOTTOMRIGHT", -30, 22)

  self.nav = {}
  for i, data in ipairs(tabs) do
    local nav = button(self.sidebar, data[2], 140)
    nav:SetPoint("TOP", 0, -16 - (i - 1) * 42)
    nav:SetScript("OnMouseUp", function() self:ShowPage(data[1]) end)
    self.nav[data[1]] = nav
  end

  self.themeText = text(self.sidebar, 140, 10)
  self.themeText:SetPoint("BOTTOM", 0, 14)
  self.themeText:SetJustifyH("CENTER")

  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(18, 18)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function()
    if not InCombatLockdown() then frame:StartSizing("BOTTOMRIGHT") end
  end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    LS:SaveFrameLayout()
    LS:Refresh()
  end)
  self.resizeGrip = grip

  self:ApplyFrameLayout()
  if self.CreateMinimapButton then self:CreateMinimapButton() end
  if self.CreateCompact and self.db and self.db.compact and self.db.compact.enabled then
    self:CreateCompact()
  end
  self:ApplyTheme()
end

function LS:Heading(title, subtitle)
  local width = self:ContentWidth()
  local heading = text(self.content, width, 22)
  heading:SetPoint("TOPLEFT", 0, 0)
  heading:SetTextColor(unpack(self.colors.accent))
  heading:SetText(title)
  local line = text(self.content, width, 11)
  line:SetPoint("TOPLEFT", 0, -32)
  line:SetText(subtitle or "")
end

function LS:ShowPage(page)
  self.page = page
  self:Clear()
  self:ApplyTheme()
  if page == "VAULT" then
    self:VaultPage()
  elseif page == "PROFESSIONS" then
    self:ProfessionsPage()
  elseif page == "WARBAND" then
    self:WarbandPage()
  elseif page == "SETTINGS" then
    self:Settings()
  elseif page == "DETAILS" then
    self:DetailsPage()
  else
    self:Today()
  end
end

-- Scrollable body shared by every page that can overflow.
function LS:Body(topOffset)
  local width = self:ContentWidth() - 18
  local scroll = CreateFrame("ScrollFrame", nil, self.content)
  scroll:SetPoint("TOPLEFT", 0, -(topOffset or 62))
  scroll:SetPoint("BOTTOMRIGHT", -18, 0)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetWidth(width)
  child:SetHeight(1)
  scroll:SetScrollChild(child)

  local bar = CreateFrame("Slider", nil, scroll, "BackdropTemplate")
  bar:SetWidth(8)
  bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
  bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
  bar:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8" })
  bar:SetBackdropColor(unpack(self.colors.panel))
  bar:SetOrientation("VERTICAL")
  bar:SetThumbTexture("Interface/Buttons/WHITE8X8")
  bar:GetThumbTexture():SetSize(8, 40)
  bar:GetThumbTexture():SetColorTexture(unpack(self.colors.accent))
  bar:SetValueStep(1)
  bar:SetObeyStepOnDrag(true)

  local function sync(value)
    local maxScroll = math.max(0, child:GetHeight() - scroll:GetHeight())
    bar:SetMinMaxValues(0, maxScroll)
    if maxScroll <= 0 then
      bar:Hide()
      scroll:SetVerticalScroll(0)
      return
    end
    bar:Show()
    value = math.min(maxScroll, math.max(0, value or scroll:GetVerticalScroll()))
    bar:SetValue(value)
    scroll:SetVerticalScroll(value)
  end

  bar:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)
  scroll:EnableMouse(true)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(_, delta) sync(scroll:GetVerticalScroll() - delta * 44) end)
  scroll:SetScript("OnSizeChanged", function() sync(scroll:GetVerticalScroll()) end)

  child.finish = function(_, height)
    child:SetHeight(math.max(1, height))
    C_Timer.After(0, function() sync(0) end)
  end
  child.width = width
  return child
end

local CARD_HEIGHT = 104
local CARD_GAP = 10
local CATEGORY_HEIGHT = 34
local CATEGORY_GAP = 8

function LS:ActivityCard(parent, activity, y, width)
  local card = panel(parent)
  card:SetSize(width, CARD_HEIGHT)
  card:SetPoint("TOPLEFT", 0, y)
  paint(card)
  card:EnableMouse(true)

  local tracked = self.db.tracked[activity.id]
  if tracked then
    card:SetBackdropBorderColor(unpack(self.colors.accent))
  end

  local title = text(card, width - 190, 14)
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetTextColor(unpack(self.colors.accent))
  title:SetText((activity.priority and (activity.priority .. "  •  ") or "") .. activity.title)

  local why = text(card, width - 190, 11)
  why:SetPoint("TOPLEFT", 16, -40)
  why:SetText(activity.why or "")

  local label, tone = self:Urgency(activity)
  local meta = text(card, width - 190, 10)
  meta:SetPoint("BOTTOMLEFT", 16, 12)
  meta:SetText(string.format("%s  •  about %s  •  score %d%s",
    self:Colorize(label, tone), self:FormatDuration((activity.minutes or 0) * 60),
    math.floor(activity.score or 0), tracked and "  •  tracked" or ""))

  local actions = {
    { "Details", function() self:ShowDetails(activity.id) end },
    { "Done", function() self.db.completed[activity.id] = true; self:ShowPage("TODAY") end },
    { "Ignore", function() self.db.dismissed[activity.id] = true; self:ShowPage("TODAY") end },
  }
  for j, action in ipairs(actions) do
    local actionButton = button(card, action[1], 74, 26)
    actionButton:SetPoint("TOPRIGHT", -10, -14 - (j - 1) * 30)
    paint(actionButton, "panel")
    actionButton:SetScript("OnMouseUp", action[2])
  end
  return card
end

function LS:CategoryCollapsed(name)
  return self.db.collapsed and self.db.collapsed[name] or false
end

function LS:SetCategoryCollapsed(name, collapsed)
  self.db.collapsed = self.db.collapsed or {}
  self.db.collapsed[name] = collapsed or nil
end

-- Clickable category header. Collapsed categories still report what is inside, so
-- hiding a category never hides the fact that it has work in it.
function LS:CategoryHeader(parent, group, y, width)
  local collapsed = self:CategoryCollapsed(group.name)
  local header = button(parent, "", width, CATEGORY_HEIGHT)
  header:SetPoint("TOPLEFT", 0, y)
  paint(header, "panel")
  header.text:Hide()

  local title = text(header, width - 200, 12)
  title:SetPoint("LEFT", 12, 0)
  title:SetTextColor(unpack(self.colors.accent))
  title:SetText(string.format("%s  %s", collapsed and "+" or "–", group.name))

  local best = group.activities[1]
  local label, tone = self:Urgency(best)
  local summary = text(header, 190, 10)
  summary:SetPoint("RIGHT", -12, 0)
  summary:SetJustifyH("RIGHT")
  summary:SetText(string.format("%d  •  %s  •  %s",
    #group.activities, self:FormatDuration(group.minutes * 60), self:Colorize(label, tone)))

  header:SetScript("OnMouseUp", function()
    self:SetCategoryCollapsed(group.name, not collapsed)
    self:ShowPage("TODAY")
  end)
  return header
end

function LS:Today()
  local filled, total, upgradable = self:VaultSummary()
  local groups, count = self:GetCategories()
  self:Heading("Your plan for today",
    string.format("Vault %d/%d filled, %d upgradable. %d %s across %d %s, best first.",
      filled, total, upgradable, count, count == 1 and "recommendation" or "recommendations",
      #groups, #groups == 1 and "category" or "categories"))

  local width = self:ContentWidth()
  if #groups > 0 then
    local anyOpen = false
    for _, group in ipairs(groups) do
      if not self:CategoryCollapsed(group.name) then anyOpen = true end
    end
    local toggle = button(self.content, anyOpen and "Collapse all" or "Expand all", 130, 28)
    toggle:SetPoint("TOPLEFT", 0, -56)
    toggle:SetScript("OnMouseUp", function()
      for _, group in ipairs(groups) do
        self:SetCategoryCollapsed(group.name, anyOpen)
      end
      self:ShowPage("TODAY")
    end)
  end

  local body = self:Body(96)
  local y = 0

  if #groups == 0 then
    local none = text(body, body.width, 11)
    none:SetPoint("TOPLEFT", 0, 0)
    none:SetText("Nothing matches your goals. Turn one on in Settings.")
    body:finish(40)
    return
  end

  for _, group in ipairs(groups) do
    self:CategoryHeader(body, group, y, body.width)
    y = y - (CATEGORY_HEIGHT + CATEGORY_GAP)
    if not self:CategoryCollapsed(group.name) then
      for _, activity in ipairs(group.activities) do
        self:ActivityCard(body, activity, y, body.width)
        y = y - (CARD_HEIGHT + CARD_GAP)
      end
    end
    y = y - 6
  end

  body:finish(-y + 10)
end

function LS:ShowDetails(id)
  self.detailID = id
  self:ShowPage("DETAILS")
end

-- Opens the main window regardless of its current state, for the compact window and the
-- minimap button to hand off to.
function LS:OpenFull(page, id)
  self:ScanVault()
  if self.ScanProfessions then self:ScanProfessions() end
  if id then self.detailID = id end
  self.frame:Show()
  self:ShowPage(page or self.page or "TODAY")
end

function LS:DetailsPage()
  local activity = self:FindActivity(self.detailID)
  if not activity then
    self:Heading("Activity", "That activity is no longer on your plan.")
    local back = button(self.content, "Back to today", 160)
    back:SetPoint("TOPLEFT", 0, -70)
    back:SetScript("OnMouseUp", function() self:ShowPage("TODAY") end)
    return
  end

  self:Heading(activity.title, activity.priority or "Activity details")
  local body = self:Body(70)
  local width = body.width
  local y = 0

  local rows = {}
  local faction = activity.faction and self:FactionProgress(activity.faction)
  if faction then
    if faction.rank then
      table.insert(rows, { "Current rank", tostring(faction.rank) })
    end
    if (faction.total or 0) > 0 then
      table.insert(rows, { "Progress to next", string.format("%d / %d", faction.progress or 0, faction.total) })
    end
  end
  local detail = activity.detail or {}
  if detail.current then table.insert(rows, { "Current", tostring(detail.current) }) end
  if detail.potential then table.insert(rows, { "Potential", tostring(detail.potential) }) end
  if detail.effort then table.insert(rows, { "Effort", tostring(detail.effort) }) end
  if detail.nextReward then table.insert(rows, { "Next reward", detail.nextReward }) end
  table.insert(rows, { "Estimated time", self:FormatDuration((activity.minutes or 0) * 60) })
  table.insert(rows, { "Why it matters", detail.matters or activity.why or "" })
  if detail.source then table.insert(rows, { "Source", detail.source }) end

  if type(detail.steps) == "table" and #detail.steps > 0 then
    table.insert(rows, { "Still open", table.concat(detail.steps, "\n") })
  end

  local rewards = detail.rewards
  if rewards then
    local parts = {}
    for _, key in ipairs({ "recipes", "mounts", "transmog" }) do
      if rewards[key] then table.insert(parts, rewards[key] .. " " .. key) end
    end
    if #parts > 0 then
      table.insert(rows, { "Unlocks", table.concat(parts, ", ") })
    end
  end

  for _, row in ipairs(rows) do
    local _, breaks = tostring(row[2]):gsub("\n", "")
    local height = math.max(44, 24 + (breaks + 1) * 16)
    local card = panel(body)
    card:SetSize(width, height)
    card:SetPoint("TOPLEFT", 0, y)
    paint(card)
    local label = text(card, 150, 11)
    label:SetPoint("TOPLEFT", 12, -8)
    label:SetTextColor(unpack(self.colors.accent))
    label:SetText(row[1])
    local value = text(card, width - 180, 11)
    value:SetPoint("TOPLEFT", 170, -8)
    value:SetText(row[2])
    y = y - (height + 6)
  end

  y = y - 8
  local tracked = self.db.tracked[activity.id]
  local trackButton = button(body, tracked and "Untrack" or "Track", 130)
  trackButton:SetPoint("TOPLEFT", 0, y)
  if tracked then highlight(trackButton) end
  trackButton:SetScript("OnMouseUp", function()
    self.db.tracked[activity.id] = (not tracked) or nil
    self:ShowPage("DETAILS")
  end)

  local ignore = button(body, "Ignore", 130)
  ignore:SetPoint("TOPLEFT", 140, y)
  ignore:SetScript("OnMouseUp", function()
    self.db.dismissed[activity.id] = true
    self:ShowPage("TODAY")
  end)

  local back = button(body, "Back", 130)
  back:SetPoint("TOPLEFT", 280, y)
  back:SetScript("OnMouseUp", function() self:ShowPage("TODAY") end)

  body:finish(-y + 60)
end

function LS:VaultPage()
  local filled, total, upgradable = self:VaultSummary()
  self:Heading("Great Vault",
    string.format("%d of %d slots filled. %d can still be improved this week.", filled, total, upgradable))
  local body = self:Body(70)
  local width = body.width
  local y = 0

  for _, key in ipairs({ "raid", "activities", "world" }) do
    local row = self.vault.rows[key]
    if row then
      local heading = text(body, width, 13)
      heading:SetPoint("TOPLEFT", 0, y)
      heading:SetTextColor(unpack(self.colors.accent))
      local runNote = ""
      if key ~= "raid" and row.runs and #row.runs > 0 then
        runNote = string.format("   (%d runs this week, best %d)", #row.runs, row.runs[1])
      end
      heading:SetText(row.label .. runNote)
      y = y - 22

      if #row.slots == 0 then
        local empty = text(body, width, 11)
        empty:SetPoint("TOPLEFT", 12, y)
        empty:SetText("No data from the client yet.")
        y = y - 26
      end

      for _, slot in ipairs(row.slots) do
        local cardHeight = slot.topRuns and 92 or 74
        local card = panel(body)
        card:SetSize(width, cardHeight)
        card:SetPoint("TOPLEFT", 0, y)
        paint(card)
        if slot.advice and slot.advice.upgradable then
          card:SetBackdropBorderColor(unpack(self.colors.accent))
        end

        local mark = slot.complete and "|cff62d26fFilled|r" or "|cffffb84dEmpty|r"
        local title = text(card, width - 24, 12)
        title:SetPoint("TOPLEFT", 12, -8)
        title:SetTextColor(unpack(self.colors.accent))
        title:SetText(string.format("Slot %d  •  %s  •  %d/%d", slot.index, mark, slot.progress, slot.threshold))

        local state = text(card, width - 24, 11)
        state:SetPoint("TOPLEFT", 12, -28)
        state:SetText(string.format("Current: %s     Potential: %s", slot.current or "—", slot.potential or "—"))

        local offset = -46
        if slot.topRuns then
          local top = text(card, width - 24, 10)
          top:SetPoint("TOPLEFT", 12, offset)
          top:SetText(string.format("Top %d runs: %s", slot.threshold, slot.topRuns))
          offset = offset - 17
        end

        local recommended = text(card, width - 24, 11)
        recommended:SetPoint("TOPLEFT", 12, offset)
        recommended:SetText("Recommended: " .. (slot.recommended or slot.description or ""))
        y = y - (cardHeight + 8)
      end
      y = y - 14
    end
  end

  body:finish(-y + 10)
end

-- One progress line per knowledge source, or a single green line once it is finished.
local function bucketLine(label, bucket, unit)
  if not bucket or bucket.total == 0 then return nil end
  if bucket.done >= bucket.total then
    return string.format("%s: |cff62d26fall %d done|r", label, bucket.total)
  end
  return string.format("%s: %d/%d %s  •  |cffffd166+%d knowledge|r",
    label, bucket.done, bucket.total, unit, bucket.points)
end

local function catchUpLine(catchUp)
  if not catchUp then
    return "Catch-up knowledge: not tracked for this profession"
  end
  if catchUp.ready == nil then
    return "Catch-up knowledge: " .. (catchUp.hint or "no requirements tracked")
  end
  if catchUp.ready then
    return "Catch-up knowledge: |cff62d26funlocked|r, drops from your profession now"
  end
  local parts = {}
  for _, group in ipairs(catchUp.groups) do
    table.insert(parts, string.format("%s %d/%d", group.label, group.done, group.need))
  end
  return "Catch-up knowledge: locked behind " .. table.concat(parts, ", ")
end

function LS:ProfessionsPage()
  local unspent, weeklyLeft, treasureLeft, catchUpReady, weeklyPoints = self:ProfessionSummary()
  local subtitle
  if weeklyLeft > 0 then
    subtitle = string.format("%d unspent knowledge. %d weekly %s left worth %d knowledge, and %d %s still uncollected.",
      unspent, weeklyLeft, weeklyLeft == 1 and "source" or "sources", weeklyPoints,
      treasureLeft, treasureLeft == 1 and "treasure" or "treasures")
  else
    subtitle = string.format("%d unspent knowledge. Every weekly source is done, and %d %s still uncollected.",
      unspent, treasureLeft, treasureLeft == 1 and "treasure" or "treasures")
  end
  if catchUpReady > 0 then
    subtitle = subtitle .. string.format(" Catch-up knowledge is open on %d.", catchUpReady)
  end
  self:Heading("Professions", subtitle)

  local visible = self:VisibleProfessions()
  local hidden = #self.professions - #visible
  local filterOn = self.db.currentExpansionOnly
  local filter = button(self.content, filterOn and "Current expansion only" or "All expansions", 200, 28)
  filter:SetPoint("TOPLEFT", 0, -52)
  if filterOn then highlight(filter) end
  filter:SetScript("OnMouseUp", function()
    self.db.currentExpansionOnly = not filterOn
    self:ShowPage("PROFESSIONS")
  end)

  if hidden > 0 then
    local note = text(self.content, 260, 10)
    note:SetPoint("TOPLEFT", 210, -58)
    note:SetText(string.format("%d older profession%s hidden", hidden, hidden == 1 and "" or "s"))
  end

  local body = self:Body(92)
  local width = body.width
  local y = 0

  if #visible == 0 then
    local none = text(body, width, 11)
    none:SetPoint("TOPLEFT", 0, y)
    if #self.professions > 0 then
      none:SetText("Nothing for the current expansion. Switch the filter to see your older professions.")
    else
      none:SetText("No trained professions with a specialization tree found. Open a profession window once so the client sends its data.")
    end
    body:finish(60)
    return
  end

  for _, prof in ipairs(visible) do
    local lines = {}
    local function add(line, indent)
      if line then table.insert(lines, { line, indent or 0 }) end
    end

    add(string.format("Skill %d / %d", prof.skill, prof.maxSkill))
    local remaining = prof.remaining and (prof.remaining .. " to finish the tree") or "tree size unknown"
    add(string.format("Knowledge: |cff62d26f%d unspent|r  •  %s", prof.unspent or 0, remaining))

    if prof.tracked then
      local sections = {
        { "Weekly quests", prof.quests, "turned in" },
        { "Weekly drops", prof.gathering, "found" },
        { "Treasures", prof.treasures, "collected" },
      }
      for _, section in ipairs(sections) do
        local line = bucketLine(section[1], section[2], section[3])
        if line then
          add(line)
          local pending = section[2].pending
          for index, item in ipairs(pending) do
            -- Keep the card readable; the details page carries the full list.
            if index > 3 then
              add(string.format("and %d more", #pending - 3), 1)
              break
            end
            local label = item.label
            if item.count > 1 then
              label = string.format("%s (%d left)", label, item.count)
            end
            add(string.format("%s  •  +%d", label, item.points), 1)
          end
        end
      end
      add(catchUpLine(prof.catchUp))
    else
      add("Weekly quests, drops and treasures are not tracked for this expansion yet.")
      add("Lodestar will not claim they are complete without verified quest data.")
    end

    local height = 32 + #lines * 17 + 8
    local card = panel(body)
    card:SetSize(width, height)
    card:SetPoint("TOPLEFT", 0, y)
    paint(card)
    if (prof.unspent or 0) > 0 then
      card:SetBackdropBorderColor(unpack(self.colors.accent))
    end

    local title = text(card, width - 24, 13)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(unpack(self.colors.accent))
    title:SetText(prof.name)

    local offset = -32
    for _, line in ipairs(lines) do
      local indent = line[2] * 14
      local row = text(card, width - 24 - indent, 11)
      row:SetPoint("TOPLEFT", 12 + indent, offset)
      row:SetText(line[1])
      if line[2] > 0 then
        row:SetTextColor(0.64, 0.68, 0.74, 1)
      end
      offset = offset - 17
    end

    y = y - (height + 10)
  end

  body:finish(-y + 10)
end

function LS:WarbandPage()
  local totals = self:GetWarbandTotals()
  self:Heading("Warband", "Every character Lodestar has seen on this account.")
  local body = self:Body(70)
  local width = body.width
  local y = 0

  local stats = {
    { "Characters", totals.characters },
    { "Vaults with progress", totals.vaultsWithSlots },
    { "Vault upgrades waiting", totals.vaultUpgrades },
    { "Unspent knowledge", totals.unspentKnowledge },
    { "Weekly knowledge left", totals.weeklyKnowledgePoints },
    { "Renown tracks active", totals.renownTargets },
  }
  local columns = math.max(1, math.floor(width / 190))
  for i, stat in ipairs(stats) do
    local col = (i - 1) % columns
    local rowIndex = math.floor((i - 1) / columns)
    local cell = panel(body)
    cell:SetSize(math.floor(width / columns) - 8, 56)
    cell:SetPoint("TOPLEFT", col * math.floor(width / columns), y - rowIndex * 64)
    paint(cell)
    local value = text(cell, 160, 18)
    value:SetPoint("TOPLEFT", 12, -8)
    value:SetTextColor(unpack(self.colors.accent))
    value:SetText(tostring(stat[2]))
    local label = text(cell, 160, 10)
    label:SetPoint("TOPLEFT", 12, -32)
    label:SetText(stat[1])
  end
  y = y - (math.ceil(#stats / columns) * 64) - 14

  local heading = text(body, width, 13)
  heading:SetPoint("TOPLEFT", 0, y)
  heading:SetTextColor(unpack(self.colors.accent))
  heading:SetText("Characters")
  y = y - 24

  local characters = self:GetWarband()
  if #characters == 0 then
    local none = text(body, width, 11)
    none:SetPoint("TOPLEFT", 0, y)
    none:SetText("Log into a character to add it here.")
    body:finish(-y + 40)
    return
  end

  for _, character in ipairs(characters) do
    local card = panel(body)
    card:SetSize(width, 68)
    card:SetPoint("TOPLEFT", 0, y)
    paint(card)
    if character.isCurrent then
      card:SetBackdropBorderColor(unpack(self.colors.accent))
    end

    local title = text(card, width - 120, 12)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(unpack(self.colors.accent))
    title:SetText(string.format("%s-%s%s", character.name, character.realm, character.isCurrent and "  (this character)" or ""))

    local line = text(card, width - 120, 11)
    line:SetPoint("TOPLEFT", 12, -30)
    line:SetText(string.format("Level %d %s  •  Vault %d/%d, %d upgradable",
      character.level, character.spec ~= "" and character.spec or character.class,
      character.vault.filled or 0, character.vault.total or 0, character.vault.upgradable or 0))

    local knowledge = text(card, width - 120, 10)
    knowledge:SetPoint("TOPLEFT", 12, -48)
    knowledge:SetText(string.format("Unspent knowledge %d  •  %d weekly knowledge left  •  mounts %d",
      character.knowledge.unspent or 0, character.knowledge.weeklyPoints or 0, character.mounts or 0))

    if not character.isCurrent then
      local forget = button(card, "Forget", 74, 24)
      forget:SetPoint("TOPRIGHT", -10, -10)
      paint(forget, "panel")
      forget:SetScript("OnMouseUp", function()
        self:ForgetCharacter(character.key)
        self:ShowPage("WARBAND")
      end)
    end
    y = y - 76
  end

  body:finish(-y + 10)
end

function LS:Dropdown(parent, width, value, options, onChoose)
  local drop = button(parent, value, width, 34)
  drop.text:SetWidth(width - 30)
  drop.text:ClearAllPoints()
  drop.text:SetPoint("LEFT", 10, 0)
  drop.text:SetJustifyH("LEFT")

  local caret = text(drop, 14, 12)
  caret:SetPoint("RIGHT", -10, -2)
  caret:SetJustifyH("RIGHT")
  caret:SetText("v")
  caret:SetTextColor(unpack(self.colors.accent))

  local menu = panel(UIParent)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetWidth(width)
  menu:SetHeight(8 + #options * 30)
  paint(menu, "panel")
  menu:Hide()
  drop.menu = menu

  for i, option in ipairs(options) do
    local choice = button(menu, option, width - 8, 28)
    choice:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 30)
    if option == value then highlight(choice) end
    choice:SetScript("OnMouseUp", function()
      menu:Hide()
      onChoose(option)
    end)
  end

  drop:SetScript("OnMouseUp", function()
    if menu:IsShown() then
      menu:Hide()
      return
    end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -2)
    menu:Show()
  end)
  drop:SetScript("OnHide", function() menu:Hide() end)
  return drop
end

function LS:Settings()
  self:Heading("Settings", "Tell Lodestar what matters. The plan follows these goals.")
  local body = self:Body(70)
  local width = math.min(380, body.width)
  local y = 0

  local goalsHeading = text(body, width, 13)
  goalsHeading:SetPoint("TOPLEFT", 0, y)
  goalsHeading:SetTextColor(unpack(self.colors.accent))
  goalsHeading:SetText("What you care about")
  y = y - 26

  for _, goal in ipairs(goalList) do
    local key, label = goal[1], goal[2]
    local on = self.db.goals[key]
    local toggle = button(body, (on and "ON  •  " or "OFF  •  ") .. label, width, 32)
    toggle:SetPoint("TOPLEFT", 0, y)
    if on then
      highlight(toggle)
    else
      toggle.text:SetTextColor(0.62, 0.65, 0.7, 1)
    end
    toggle:SetScript("OnMouseUp", function()
      self.db.goals[key] = not self.db.goals[key]
      self:ShowPage("SETTINGS")
    end)
    y = y - 38
  end

  y = y - 14
  local themeHeading = text(body, width, 13)
  themeHeading:SetPoint("TOPLEFT", 0, y)
  themeHeading:SetTextColor(unpack(self.colors.accent))
  themeHeading:SetText("Theme")
  y = y - 26

  local drop = self:Dropdown(body, width, self.db.theme or "AUTO", self.themeOrder, function(choice)
    self:SetTheme(choice)
  end)
  drop:SetPoint("TOPLEFT", 0, y)
  y = y - 42

  local note = text(body, width, 10)
  note:SetPoint("TOPLEFT", 0, y)
  if self.themeNative then
    note:SetText("Using ElvUI's own backdrop, border, texture and font.")
  elseif self:CurrentTheme() == "ELVUI" then
    note:SetText("ElvUI is not loaded, so this is the standalone ElvUI-style palette.")
  else
    note:SetText("Auto follows ElvUI or EllesmereUI when either is loaded.")
  end
  y = y - 34

  local compactHeading = text(body, width, 13)
  compactHeading:SetPoint("TOPLEFT", 0, y)
  compactHeading:SetTextColor(unpack(self.colors.accent))
  compactHeading:SetText("Compact mode")
  y = y - 26

  local compact = self.db.compact
  local compactToggles = {
    {
      key = "enabled",
      label = "Compact window",
      apply = function(on) self:SetCompact(on) end,
    },
    {
      key = "single",
      label = "Single recommendation only",
      apply = function(on) self:SetCompactSingle(on) end,
    },
  }
  for _, entry in ipairs(compactToggles) do
    local on = compact[entry.key]
    local toggle = button(body, (on and "ON  •  " or "OFF  •  ") .. entry.label, width, 32)
    toggle:SetPoint("TOPLEFT", 0, y)
    if on then
      highlight(toggle)
    else
      toggle.text:SetTextColor(0.62, 0.65, 0.7, 1)
    end
    toggle:SetScript("OnMouseUp", function()
      entry.apply(not on)
      self:ShowPage("SETTINGS")
    end)
    y = y - 38
  end

  local compactNote = text(body, width, 10)
  compactNote:SetPoint("TOPLEFT", 0, y)
  compactNote:SetText("Click an entry for details, double click for the full window. It collapses on its own in combat.")
  y = y - 32

  local resetCompact = button(body, "Reset compact position", width, 32)
  resetCompact:SetPoint("TOPLEFT", 0, y)
  resetCompact:SetScript("OnMouseUp", function()
    self:ResetCompactLayout()
    self:ShowPage("SETTINGS")
  end)
  y = y - 44

  local windowHeading = text(body, width, 13)
  windowHeading:SetPoint("TOPLEFT", 0, y)
  windowHeading:SetTextColor(unpack(self.colors.accent))
  windowHeading:SetText("Window")
  y = y - 26

  local windowNote = text(body, width, 10)
  windowNote:SetPoint("TOPLEFT", 0, y)
  windowNote:SetText("Drag the frame to move it, or the grip in the bottom-right corner to resize. Both are saved.")
  y = y - 34

  local reset = button(body, "Reset size and position", width, 32)
  reset:SetPoint("TOPLEFT", 0, y)
  reset:SetScript("OnMouseUp", function()
    self.db.frame = { point = "CENTER", relative = "CENTER", x = 0, y = 0, width = 960, height = 680 }
    self:ApplyFrameLayout()
    self:ShowPage("SETTINGS")
  end)
  y = y - 40

  local clear = button(body, "Clear ignored and completed", width, 32)
  clear:SetPoint("TOPLEFT", 0, y)
  clear:SetScript("OnMouseUp", function()
    self.db.dismissed = {}
    self.db.completed = {}
    self:ShowPage("SETTINGS")
  end)
  y = y - 44

  body:finish(-y + 10)
end

function LS:Refresh()
  if self.frame and self.frame:IsShown() then
    self:ShowPage(self.page or "TODAY")
  end
  if self.UpdateCompact then self:UpdateCompact() end
end

function LS:Toggle()
  if self.frame:IsShown() then
    self.frame:Hide()
    return
  end
  self:ScanVault()
  if self.ScanProfessions then self:ScanProfessions() end
  self.frame:Show()
  self:ShowPage(self.page or "TODAY")
end
