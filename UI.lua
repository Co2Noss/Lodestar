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
  { "GOLD", "Gold making" },
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

local function panel(parent, name)
  local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
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

-- Blizzard's modern panel art, the frame style Dragonflight introduced. The templates are
-- tried in order and the whole thing degrades to the flat backdrop if the client has none,
-- so an art change in a future patch cannot leave the window borderless.
local CHROME_TEMPLATES = { "DefaultPanelTemplate", "DialogBorderTemplate" }
local CHROME_PAD = 9

function LS:UpdateChrome(wanted)
  if wanted and not self.chrome and not self.chromeMissing then
    for _, template in ipairs(CHROME_TEMPLATES) do
      local ok, frame = pcall(CreateFrame, "Frame", nil, self.frame, template)
      if ok and frame then
        frame:SetAllPoints(self.frame)
        frame:SetFrameLevel(self.frame:GetFrameLevel())
        -- Decoration only. Anything that took clicks here would stop the window dragging.
        frame:EnableMouse(false)
        if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
        frame.template = template
        self.chrome = frame
        break
      end
    end
    self.chromeMissing = self.chrome == nil
  end

  local active = (wanted and self.chrome ~= nil) or false
  if self.chrome then self.chrome:SetShown(active) end
  self:LayoutFrame(active and CHROME_PAD or 0)
  return active
end

-- Blizzard's border art is far thicker than a one pixel edge, so the content moves inward
-- to sit inside it rather than under it.
function LS:LayoutFrame(pad)
  if self.layoutPad == pad then return end
  self.layoutPad = pad

  self.header:ClearAllPoints()
  self.header:SetPoint("TOPLEFT", 1 + pad, -(1 + pad))
  self.header:SetPoint("TOPRIGHT", -(1 + pad), -(1 + pad))

  self.sidebar:ClearAllPoints()
  self.sidebar:SetPoint("TOPLEFT", 12 + pad, -(68 + pad))
  self.sidebar:SetPoint("BOTTOMLEFT", 12 + pad, 14 + pad)

  self.content:ClearAllPoints()
  self.content:SetPoint("TOPLEFT", 195 + pad, -(76 + pad))
  self.content:SetPoint("BOTTOMRIGHT", -(30 + pad), 22 + pad)

  if self.resizeGrip then
    self.resizeGrip:ClearAllPoints()
    self.resizeGrip:SetPoint("BOTTOMRIGHT", -(3 + pad), 3 + pad)
  end
end

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
  local frame = panel(UIParent, "LodestarFrame")
  self.frame = frame
  frame:SetSize(960, 680)
  frame:SetPoint("CENTER")
  -- Nameplates, including Ellesmere's personal plate, live on HIGH. MEDIUM (UIParent's
  -- default) lets them draw through the cards.
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  -- ESC closes the main window the same way it closes Blizzard's. Compact stays up.
  if UISpecialFrames then
    local listed = false
    for _, name in ipairs(UISpecialFrames) do
      if name == "LodestarFrame" then listed = true break end
    end
    if not listed then table.insert(UISpecialFrames, "LodestarFrame") end
  end
  frame:EnableKeyboard(true)
  if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(true) end
  frame:SetScript("OnKeyDown", function(selfFrame, key)
    if key == "ESCAPE" then
      if selfFrame.SetPropagateKeyboardInput then selfFrame:SetPropagateKeyboardInput(false) end
      selfFrame:Hide()
    elseif selfFrame.SetPropagateKeyboardInput then
      selfFrame:SetPropagateKeyboardInput(true)
    end
  end)
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

function LS:PickTab(tabs, selectedID)
  if not tabs or #tabs == 0 then return nil end
  for _, tab in ipairs(tabs) do
    if tab[1] == selectedID then return tab end
  end
  return tabs[1]
end

-- Full-width strip used by Today, Great Vault, Professions and Settings. One click
-- replaces scrolling through every group on the page. Long lists wrap onto another row
-- rather than shrinking the labels to nothing.
function LS:TabStrip(tabs, selectedID, onChoose, y, parent, width)
  local chosen = self:PickTab(tabs, selectedID)
  if not chosen then return nil, 0 end
  y = y or -56
  parent = parent or self.content
  local n = #tabs
  local gap, height = 6, 30
  local inset = (parent ~= self.content) and 8 or 0
  local total = width or (self:ContentWidth() - inset * 2)
  local minWidth = 92
  local tabWidth = math.floor((total - gap * math.max(n - 1, 0)) / math.max(n, 1))
  local perRow = n
  if n > 1 and tabWidth < minWidth then
    perRow = math.max(1, math.floor((total + gap) / (minWidth + gap)))
    tabWidth = math.floor((total - gap * (perRow - 1)) / perRow)
  end
  for i, tab in ipairs(tabs) do
    local col = (i - 1) % perRow
    local row = math.floor((i - 1) / perRow)
    local nav = button(parent, tab[2], tabWidth, height)
    nav:SetPoint("TOPLEFT", inset + col * (tabWidth + gap), y - row * (height + gap))
    if tab[1] == chosen[1] then
      highlight(nav)
    else
      nav.text:SetTextColor(unpack(self.colors.muted))
    end
    nav:SetScript("OnMouseUp", function()
      onChoose(tab[1])
    end)
  end
  local rows = math.ceil(n / perRow)
  return chosen, rows * height + (rows - 1) * gap
end

function LS:ShowPage(page)
  self.page = page
  self:Clear()
  self:ApplyTheme()
  if page == "WELCOME" then
    self:WelcomePage()
  elseif page == "VAULT" then
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

  local actions = {}
  if activity.open then
    table.insert(actions, { activity.openLabel or "Open", activity.open })
  end
  table.insert(actions, { "Details", function() self:ShowDetails(activity.id) end })
  table.insert(actions, { "Done", function() self.db.completed[activity.id] = true; self:ShowPage("TODAY") end })
  table.insert(actions, { "Ignore", function() self.db.dismissed[activity.id] = true; self:ShowPage("TODAY") end })
  local height = CARD_HEIGHT + math.max(0, #actions - 3) * 30
  card:SetSize(width, height)
  for j, action in ipairs(actions) do
    local actionButton = button(card, action[1], 74, 26)
    actionButton:SetPoint("TOPRIGHT", -10, -14 - (j - 1) * 30)
    paint(actionButton, "panel")
    actionButton:SetScript("OnMouseUp", action[2])
  end
  return card, height
end

-- Shown once, before anything has been recommended. Every goal starts off, so this is the
-- one place Lodestar has to ask instead of assuming.
function LS:WelcomePage()
  self:Heading("Welcome to Lodestar",
    "Blizzard shows you everything you can do. Lodestar tells you what is worth doing.")

  local body = self:Body(76)
  local width = math.min(460, body.width)
  local y = 0

  local intro = text(body, width, 11)
  intro:SetPoint("TOPLEFT", 0, y)
  intro:SetText("To do that it needs to know what you care about. Pick anything that applies, and Lodestar will rank the work that feeds those goals and stay quiet about the rest.")
  y = y - 44

  local chosen = 0
  for _, goal in ipairs(goalList) do
    if self.db.goals[goal[1]] then chosen = chosen + 1 end
  end

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
      self.db.goals[key] = not on
      self:MarkGoalsChosen()
      self:ShowPage("WELCOME")
    end)
    y = y - 38
  end

  y = y - 10
  local everything = button(body, chosen == #goalList and "Clear all" or "I care about all of it", 200, 30)
  everything:SetPoint("TOPLEFT", 0, y)
  everything:SetScript("OnMouseUp", function()
    local turnOn = chosen < #goalList
    for _, goal in ipairs(goalList) do
      self.db.goals[goal[1]] = turnOn
    end
    self:MarkGoalsChosen()
    self:ShowPage("WELCOME")
  end)

  local continue = button(body, "Show me my plan", 200, 30)
  continue:SetPoint("TOPLEFT", 214, y)
  if chosen > 0 then
    highlight(continue)
    continue:SetScript("OnMouseUp", function()
      self.db.welcomed = true
      self:ShowPage("TODAY")
    end)
  else
    continue.text:SetTextColor(0.62, 0.65, 0.7, 1)
  end
  y = y - 42

  local note = text(body, width, 10)
  note:SetPoint("TOPLEFT", 0, y)
  if chosen > 0 then
    note:SetText("You can change these at any time in Settings, and nothing here is permanent.")
  else
    note:SetText("Choose at least one. With everything off Lodestar has nothing to recommend.")
    note:SetTextColor(unpack(self.colors.warn))
  end
  y = y - 34

  body:finish(-y + 10)
end

function LS:Today()
  local groups = self:GetCategories()

  if #groups == 0 then
    if self:GoalsChosen() then
      self:Heading("Your plan for today", "Nothing matches the filters you picked.")
      local body = self:Body(76)
      local none = text(body, body.width, 11)
      none:SetPoint("TOPLEFT", 0, 0)
      local pick
      if self.db.goals.REPUTATION and self.HasRepSelection and not self:HasRepSelection() then
        none:SetText("Reputation is on, but you have not picked any expansions, categories or factions. Lodestar stays quiet about reputations until you do.")
        pick = button(body, "Choose reputations", 200, 30)
        pick:SetScript("OnMouseUp", function()
          self:SetPageTab("SETTINGS", "REPUTATION")
          self:ShowPage("SETTINGS")
        end)
      else
        none:SetText("The goals are on, but nothing is currently worth ranking. That changes as the week does.")
        pick = button(body, "Choose my goals", 200, 30)
        pick:SetScript("OnMouseUp", function() self:ShowPage("WELCOME") end)
      end
      pick:SetPoint("TOPLEFT", 0, -42)
      highlight(pick)
      body:finish(90)
      return
    end
    self:Heading("Your plan for today", "Nothing to rank until you pick a goal.")
    local body = self:Body(76)
    local none = text(body, body.width, 11)
    none:SetPoint("TOPLEFT", 0, 0)
    none:SetText("Every goal is off, so Lodestar has nothing to weigh against. Pick what you care about and the plan fills in.")
    local pick = button(body, "Choose my goals", 200, 30)
    pick:SetPoint("TOPLEFT", 0, -42)
    highlight(pick)
    pick:SetScript("OnMouseUp", function() self:ShowPage("WELCOME") end)
    body:finish(90)
    return
  end

  local tabs = {}
  for _, group in ipairs(groups) do
    table.insert(tabs, { group.name, group.name })
  end
  local chosen = self:PickTab(tabs, self:PageTab("TODAY"))
  local group = groups[1]
  for _, entry in ipairs(groups) do
    if entry.name == chosen[1] then group = entry end
  end

  local label = self:Urgency(group.activities[1])
  self:Heading("Your plan for today",
    string.format("%d %s, about %s. Best is %s.",
      #group.activities, #group.activities == 1 and "recommendation" or "recommendations",
      self:FormatDuration(group.minutes * 60), label))
  self:TabStrip(tabs, chosen[1], function(id)
    self:SetPageTab("TODAY", id)
    self:ShowPage("TODAY")
  end)

  local body = self:Body(96)
  local y = 0
  local lastSection
  for _, activity in ipairs(group.activities) do
    if activity.section and activity.section ~= lastSection then
      local heading = text(body, body.width, 12)
      heading:SetPoint("TOPLEFT", 0, y)
      heading:SetTextColor(unpack(self.colors.accent))
      heading:SetText(activity.section)
      y = y - 22
      lastSection = activity.section
    end
    local _, h = self:ActivityCard(body, activity, y, body.width)
    y = y - ((h or CARD_HEIGHT) + CARD_GAP)
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
  if self.ScanMounts then self:ScanMounts() end
  if self.ScanReputations then self:ScanReputations() end
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

  if activity.waypoints then
    local lines = {}
    for _, point in ipairs(activity.waypoints) do
      table.insert(lines, (point.title or "Location") .. " — " .. self:FormatWaypoint(point))
    end
    if #lines > 0 then
      table.insert(rows, { "On the map", table.concat(lines, "\n") })
    end
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
  if activity.waypoints then
    local way = button(body, self:WaypointButtonLabel(activity.waypoints) or "Waypoint", 130)
    way:SetPoint("TOPLEFT", 0, y)
    highlight(way)
    way:SetScript("OnMouseUp", function()
      self:MarkWaypoints(activity.waypoints, activity.title)
    end)
    y = y - 40
  end
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
  local tabs = {}
  for _, key in ipairs({ "raid", "activities", "world" }) do
    local row = self.vault.rows[key]
    if row then
      table.insert(tabs, { key, row.label })
    end
  end

  local chosen = self:PickTab(tabs, self:PageTab("VAULT"))
  local row = chosen and self.vault.rows[chosen[1]]
  local filled, total, upgradable = 0, 0, 0
  if row then
    for _, slot in ipairs(row.slots) do
      total = total + 1
      if slot.complete then filled = filled + 1 end
      if slot.advice and slot.advice.upgradable then upgradable = upgradable + 1 end
    end
  end

  local subtitle = string.format("%d of %d slots filled. %d can still be improved this week.",
    filled, total, upgradable)
  if row and row.runs and #row.runs > 0 then
    subtitle = subtitle .. string.format("  %d runs this week, best %d.", #row.runs, row.runs[1])
  end
  self:Heading("Great Vault", subtitle)
  if chosen then
    self:TabStrip(tabs, chosen[1], function(id)
      self:SetPageTab("VAULT", id)
      self:ShowPage("VAULT")
    end)
  end

  local body = self:Body(chosen and 96 or 70)
  local width = body.width
  local y = 0

  if not row then
    local empty = text(body, width, 11)
    empty:SetPoint("TOPLEFT", 0, 0)
    empty:SetText("No data from the client yet.")
    body:finish(40)
    return
  end

  if #row.slots == 0 then
    local empty = text(body, width, 11)
    empty:SetPoint("TOPLEFT", 0, 0)
    empty:SetText("No data from the client yet.")
    y = y - 26
  end

  for _, slot in ipairs(row.slots) do
    y = self:VaultSlotCard(body, slot, y, width)
  end
  body:finish(-y + 10)
end

function LS:VaultSlotCard(parent, slot, y, width)
  local cardHeight = slot.topRuns and 92 or 74
  local card = panel(parent)
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
  return y - (cardHeight + 8)
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
  local visible = self:VisibleProfessions()
  local hidden = #self.professions - #visible
  local filterOn = self.db.currentExpansionOnly

  local tabs = {}
  local names = {}
  for _, prof in ipairs(visible) do
    names[prof.name] = (names[prof.name] or 0) + 1
  end
  for _, prof in ipairs(visible) do
    local label = prof.name
    if names[prof.name] > 1 then
      label = string.format("%s  %s", prof.name, prof.expansion or prof.skillLineID)
    end
    table.insert(tabs, { tostring(prof.skillLineID), label })
  end

  local chosen = self:PickTab(tabs, self:PageTab("PROFESSIONS"))
  local selected = visible[1]
  if chosen then
    for _, prof in ipairs(visible) do
      if tostring(prof.skillLineID) == chosen[1] then selected = prof end
    end
  end

  local subtitle
  if selected then
    if selected.secondary and not selected.tracked then
      subtitle = string.format("Skill %d / %d", selected.skill or 0, selected.maxSkill or 0)
    else
      local remaining = selected.remaining and (selected.remaining .. " to finish the tree") or "tree size unknown"
      if selected.spent then
        subtitle = string.format("%d unspent  •  %d spent  •  %s", selected.unspent or 0, selected.spent, remaining)
      else
        subtitle = string.format("%d unspent  •  %s", selected.unspent or 0, remaining)
      end
    end
  elseif #self.professions > 0 then
    subtitle = "Nothing for the current expansion. Switch the filter to see your older professions."
  else
    subtitle = "Open a profession window once so the client sends its data."
  end
  self:Heading("Professions", subtitle)

  local filter = button(self.content, filterOn and "Current expansion only" or "All expansions", 190, 26)
  filter:SetPoint("TOPRIGHT", 0, -4)
  if filterOn then highlight(filter) end
  filter:SetScript("OnMouseUp", function()
    self.db.currentExpansionOnly = not filterOn
    self:ShowPage("PROFESSIONS")
  end)
  if hidden > 0 then
    filter.text:SetText(string.format("Current expansion only  •  %d hidden", hidden))
  end

  if chosen then
    self:TabStrip(tabs, chosen[1], function(id)
      local prof
      for _, entry in ipairs(self:VisibleProfessions()) do
        if tostring(entry.skillLineID) == id then prof = entry end
      end
      if self.OpenProfessionWindow then self:OpenProfessionWindow(prof, false) end
      self:SetPageTab("PROFESSIONS", id)
      self:ShowPage("PROFESSIONS")
    end)
  end

  local body = self:Body(chosen and 96 or 70)
  if not selected then
    local none = text(body, body.width, 11)
    none:SetPoint("TOPLEFT", 0, 0)
    none:SetText(subtitle)
    body:finish(40)
    return
  end

  local y = self:ProfessionCard(body, selected, 0, body.width)
  body:finish(-y + 10)
end

function LS:ProfessionCard(parent, prof, y, width)
  local lines = {}
  local function add(line, indent)
    if line then table.insert(lines, { line, indent or 0 }) end
  end

  add(string.format("Skill %d / %d", prof.skill, prof.maxSkill))
  if prof.secondary and not prof.tracked then
    add("Cooking, Fishing and Archaeology have no knowledge tree. Skill is the progress that matters.")
    if (prof.maxSkill or 0) > 0 and (prof.skill or 0) >= prof.maxSkill then
      add("This character is at the skill cap.")
    end
  else
    local remaining = prof.remaining and (prof.remaining .. " to finish the tree") or "tree size unknown"
    if prof.spent then
      add(string.format("Knowledge: |cff62d26f%d unspent|r  •  %d spent  •  %s",
        prof.unspent or 0, prof.spent, remaining))
    else
      add(string.format("Knowledge: |cff62d26f%d unspent|r  •  %s", prof.unspent or 0, remaining))
    end
  end

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
          if index > 12 then
            add(string.format("and %d more", #pending - 12), 1)
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
  elseif not prof.secondary then
    add("Weekly quests, drops and treasures are not tracked for this expansion yet.")
    add("Lodestar will not claim they are complete without verified quest data.")
  end

  local actions = { { "Open " .. (prof.baseName or prof.name), false } }
  if not prof.secondary then
    table.insert(actions, { "Specializations", true })
  end

  local height = 32 + #lines * 17 + 40
  local card = panel(parent)
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

  local btnW = math.floor((width - 24 - (#actions - 1) * 8) / #actions)
  for i, action in ipairs(actions) do
    local b = button(card, action[1], btnW, 26)
    b:SetPoint("BOTTOMLEFT", 12 + (i - 1) * (btnW + 8), 8)
    paint(b, "panel")
    if action[2] and (prof.unspent or 0) > 0 then highlight(b) end
    b:SetScript("OnMouseUp", function()
      if LS.OpenProfessionWindow then LS:OpenProfessionWindow(prof, action[2]) end
    end)
  end

  return y - (height + 10)
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

-- A labelled row with a live sample of the colour it edits, so the list reads as the
-- palette rather than as a list of words.
function LS:ColorSwatch(parent, key, label, width)
  local row = button(parent, label, width, 30)
  row.text:SetWidth(width - 44)
  row.text:ClearAllPoints()
  row.text:SetPoint("LEFT", 10, 0)
  row.text:SetJustifyH("LEFT")

  local chip = panel(row)
  chip:SetSize(22, 18)
  chip:SetPoint("RIGHT", -8, 0)
  chip:SetBackdropColor(unpack(self.colors[key] or { 1, 1, 1, 1 }))
  chip:SetBackdropBorderColor(unpack(self.colors.border))
  row.chip = chip
  row.colorKey = key

  if self.db.colors and self.db.colors[key] then
    row.text:SetText(label .. "  (yours)")
  end

  -- Picking a colour repaints through ApplyTheme, so the page does not rebuild itself out
  -- from under the open picker.
  row:SetScript("OnMouseUp", function() self:PickColor(key) end)
  return row
end

local settingsTabs = {
  { "GOALS", "Goals", "Tell Lodestar what matters. The plan follows these goals." },
  { "REPUTATION", "Reputation", "Which expansions, categories and factions to rank." },
  { "APPEARANCE", "Appearance", "How the window looks. Your colors override the theme." },
  { "COMPACT", "Compact", "The small always-on window." },
  { "LAYOUT", "Layout", "Where the window sits, and what Lodestar has remembered." },
}

function LS:SettingsTab()
  return self:PickTab(settingsTabs, self:PageTab("SETTINGS"))
end

-- Settings outgrew a single scrolling column, so each group is its own tab. The strip
-- fills the content width so the next setting is a click, not a scroll, and the tab you
-- were last on is remembered.
function LS:Settings()
  local chosen = self:SettingsTab()
  self:Heading("Settings", chosen[3])
  self:TabStrip(settingsTabs, chosen[1], function(id)
    self:SetPageTab("SETTINGS", id)
    self:ShowPage("SETTINGS")
  end)

  local bodyOffset = 96
  if chosen[1] == "REPUTATION" then
    if self.ScanReputations then self:ScanReputations() end
    local expansions = self.RepExpansionTabs and self:RepExpansionTabs() or {}
    if #expansions > 0 then
      local nest = panel(self.content)
      nest:SetPoint("TOPLEFT", 0, -90)
      nest:SetPoint("BOTTOMRIGHT", 0, 0)
      paint(nest, "panel")
      nest:SetBackdropBorderColor(unpack(self.colors.accent))
      local _, stripH = self:TabStrip(expansions, self:PageTab("REP"), function(id)
        self:SetPageTab("REP", id)
        self:ShowPage("SETTINGS")
      end, -8, nest)
      bodyOffset = 106 + (stripH or 30)
    end
  end

  local body = self:Body(bodyOffset)
  local width = (chosen[1] == "REPUTATION") and body.width or math.min(420, body.width)
  local y = 0
  if chosen[1] == "GOALS" then
    y = self:SettingsGoals(body, width, y)
  elseif chosen[1] == "REPUTATION" then
    y = self:SettingsReputation(body, width, y)
  elseif chosen[1] == "APPEARANCE" then
    y = self:SettingsAppearance(body, width, y)
  elseif chosen[1] == "COMPACT" then
    y = self:SettingsCompact(body, width, y)
  else
    y = self:SettingsWindow(body, width, y)
  end
  body:finish(-y + 10)
end

function LS:SettingsGoals(body, width, y)
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
      self:MarkGoalsChosen()
      self:ShowPage("SETTINGS")
    end)
    y = y - 38
  end

  local goalNote = text(body, width, 10)
  goalNote:SetPoint("TOPLEFT", 0, y)
  goalNote:SetText("With every goal off there is nothing to rank, so Today will be empty. Which reputations to rank is chosen on the Reputation tab.")
  y = y - 36

  local goldHeading = text(body, width, 13)
  goldHeading:SetPoint("TOPLEFT", 0, y)
  goldHeading:SetTextColor(unpack(self.colors.accent))
  goldHeading:SetText("Gold prices")
  y = y - 24

  local source = (self.db.goldSource or "AUTO")
  local goldLabels, goldFromLabel = {}, {}
  for _, key in ipairs(self.goldSourceOrder or { "AUTO" }) do
    local label = (self.goldSourceLabels and self.goldSourceLabels[key]) or key
    table.insert(goldLabels, label)
    goldFromLabel[label] = key
  end
  local drop = self:Dropdown(body, width, (self.goldSourceLabels and self.goldSourceLabels[source]) or source, goldLabels, function(choice)
    self.db.goldSource = goldFromLabel[choice] or "AUTO"
    self:ShowPage("SETTINGS")
  end)
  drop:SetPoint("TOPLEFT", 0, y)
  y = y - 42

  local goldNote = text(body, width, 10)
  goldNote:SetPoint("TOPLEFT", 0, y)
  local _, name, ready
  if self.ResolveGoldSource then
    _, name, ready = self:ResolveGoldSource()
  end
  if not self.db.goals.GOLD then
    goldNote:SetText("Gold making stays off the plan until that goal is on. Prices come from TSM, Auctionator or RECrystallize.")
  elseif ready then
    goldNote:SetText("Prices from " .. name .. ". Auto uses the first of those addons that is loaded.")
  elseif source ~= "AUTO" and name then
    goldNote:SetTextColor(unpack(self.colors.warn))
    goldNote:SetText(name .. " is not loaded. Install it, or pick Auto / another source, or Lodestar stays quiet about gold.")
  else
    goldNote:SetText("No price addon is loaded. Install TSM, Auctionator or RECrystallize. Lodestar does not invent an auction house.")
  end
  y = y - 40

  local hnHeading = text(body, width, 13)
  hnHeading:SetPoint("TOPLEFT", 0, y)
  hnHeading:SetTextColor(unpack(self.colors.accent))
  hnHeading:SetText("HandyNotes")
  y = y - 24

  local hnNote = text(body, width, 10)
  hnNote:SetPoint("TOPLEFT", 0, y)
  if not self.db.goals.SOLO then
    hnNote:SetText("Solo content stays off the plan until that goal is on. HandyNotes rares follow once it is.")
  elseif self.HasHandyNotes and self:HasHandyNotes() then
    hnNote:SetText("HandyNotes is loaded. Today will rank rares it is currently showing in your zone. Known rewards stay hidden because HandyNotes already hid them.")
  else
    hnNote:SetText("Install HandyNotes and a rares plugin to rank nearby rares. Lodestar does not invent spawn data.")
  end
  y = y - 48
  return y
end

function LS:SettingsReputation(body, width, y)
  if self.ScanReputations then self:ScanReputations() end
  local intro = text(body, width, 11)
  intro:SetPoint("TOPLEFT", 0, y)
  intro:SetText("Nothing is assumed. Turn on an expansion, a category, or a single faction. Lodestar ranks the ones that are not finished and stays quiet about the rest.")
  y = y - 40

  if self:HasRepSelection() and not self.db.goals.REPUTATION then
    local warn = text(body, width, 11)
    warn:SetPoint("TOPLEFT", 0, y)
    warn:SetTextColor(unpack(self.colors.warn))
    warn:SetText("You have factions selected, but Reputation is not one of your goals, so none of this will appear on Today.")
    y = y - 36
    local enable = button(body, "Turn on the Reputation goal", math.min(280, width), 32)
    enable:SetPoint("TOPLEFT", 0, y)
    highlight(enable)
    enable:SetScript("OnMouseUp", function()
      self.db.goals.REPUTATION = true
      self:MarkGoalsChosen()
      self:ShowPage("SETTINGS")
    end)
    y = y - 44
  end

  local rows = self.profile and self.profile.repRows or {}
  if #rows == 0 then
    local none = text(body, width, 11)
    none:SetPoint("TOPLEFT", 0, y)
    none:SetText("The client has not handed Lodestar a reputation list yet. Open the Reputation pane once, then come back.")
    none:SetTextColor(unpack(self.colors.muted))
    return y - 28
  end

  local expansion = self:PickTab(self:RepExpansionTabs(), self:PageTab("REP"))
  expansion = expansion and expansion[1]
  if not expansion then
    return y
  end

  local expansionOn = (self.db.repExpansions and self.db.repExpansions[expansion]) == true
  local all = button(body, (expansionOn and "ON  •  Rank all of " or "OFF  •  Rank all of ") .. expansion, width, 32)
  all:SetPoint("TOPLEFT", 0, y)
  if expansionOn then
    highlight(all)
  else
    all.text:SetTextColor(0.62, 0.65, 0.7, 1)
  end
  all:SetScript("OnMouseUp", function()
    self:SetRepExpansion(expansion, not expansionOn)
    self:ShowPage("SETTINGS")
  end)
  y = y - 40

  for _, row in ipairs(rows) do
    if row.kind ~= "expansion" and row.expansion == expansion then
      local on, label, indent
      if row.kind == "group" then
        on = self:RepGroupOn(row.expansion, row.name)
        label = row.name
        indent = 0
      else
        on = self:CaresAboutRep(row)
        local extra = row.isMajor and string.format("Renown %d", row.renown or 0)
          or (_G["FACTION_STANDING_LABEL" .. tostring(row.reaction or 0)] or "")
        label = extra ~= "" and (row.name .. "  •  " .. extra) or row.name
        indent = row.group and 18 or 0
      end
      local toggle = button(body, (on and "ON  •  " or "OFF  •  ") .. label, width - indent, 28)
      toggle:SetPoint("TOPLEFT", indent, y)
      if on then
        highlight(toggle)
      else
        toggle.text:SetTextColor(0.62, 0.65, 0.7, 1)
      end
      toggle:SetScript("OnMouseUp", function()
        if row.kind == "group" then
          self:SetRepGroup(row.expansion, row.name, not on)
        else
          self:SetRepFaction(row.factionID, not on)
        end
        self:ShowPage("SETTINGS")
      end)
      y = y - 32
    end
  end
  y = y - 8
  return y
end

function LS:SettingsAppearance(body, width, y)
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
  local active = self:CurrentTheme()
  if self.themeNative then
    note:SetText("Using ElvUI's own backdrop, border, texture and font.")
  elseif active == "ELVUI" then
    note:SetText("ElvUI is not loaded, so this is the standalone ElvUI-style palette.")
  elseif active == "BLIZZARD" and self.chrome then
    note:SetText("Blizzard's own panel art and font colours, the frame style Dragonflight introduced.")
  elseif active == "BLIZZARD" then
    note:SetText("This client offered no panel art, so Blizzard's colours are drawn on a flat frame.")
  else
    note:SetText("Auto follows ElvUI or EllesmereUI when either is loaded.")
  end
  y = y - 34

  local colorHeading = text(body, width, 13)
  colorHeading:SetPoint("TOPLEFT", 0, y)
  colorHeading:SetTextColor(unpack(self.colors.accent))
  colorHeading:SetText("Colors")
  y = y - 26

  -- Two columns, so the whole palette is visible at once instead of being a scroll.
  local columns = 2
  local columnGap = 12
  local swatchWidth = math.min(230,
    math.floor((math.max(width, body.width) - columnGap) / columns))
  for i, entry in ipairs(self.colorOrder) do
    local column = (i - 1) % columns
    local row = math.floor((i - 1) / columns)
    local swatch = self:ColorSwatch(body, entry[1], entry[2], swatchWidth)
    swatch:SetPoint("TOPLEFT", column * (swatchWidth + columnGap), y - row * 34)
  end
  y = y - math.ceil(#self.colorOrder / columns) * 34

  local colorNote = text(body, width, 10)
  colorNote:SetPoint("TOPLEFT", 0, y)
  if self:HasCustomColors() then
    colorNote:SetText("Your colors override the theme, including ElvUI's, and survive switching themes.")
  else
    colorNote:SetText("Click a color to change it. Your choice overrides the theme until you reset it.")
  end
  y = y - 32

  if self:HasCustomColors() then
    local resetColors = button(body, "Reset colors to the theme", width, 32)
    resetColors:SetPoint("TOPLEFT", 0, y)
    resetColors:SetScript("OnMouseUp", function()
      self:ResetColors()
      self:ShowPage("SETTINGS")
    end)
    y = y - 44
  else
    y = y - 10
  end
  return y
end

function LS:SettingsCompact(body, width, y)
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
  compactNote:SetText("One goal keeps this to a single row; more goals grow it to two. Click an entry for details, double click for the full window. It collapses on its own in combat.")
  y = y - 32

  local resetCompact = button(body, "Reset compact position", width, 32)
  resetCompact:SetPoint("TOPLEFT", 0, y)
  resetCompact:SetScript("OnMouseUp", function()
    self:ResetCompactLayout()
    self:ShowPage("SETTINGS")
  end)
  y = y - 44
  return y
end

function LS:SettingsWindow(body, width, y)
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
  return y
end

function LS:Refresh()
  if self.frame and self.frame:IsShown() then
    self:ShowPage(self.page or "TODAY")
  end
  if self.UpdateCompact then self:UpdateCompact() end
end

function LS:LandingPage()
  if not self.db.welcomed then return "WELCOME" end
  return self.page or "TODAY"
end

function LS:Toggle()
  if self.frame:IsShown() then
    self.frame:Hide()
    return
  end
  self:ScanVault()
  if self.ScanProfessions then self:ScanProfessions() end
  if self.ScanMounts then self:ScanMounts() end
  if self.ScanReputations then self:ScanReputations() end
  self.frame:Show()
  self:ShowPage(self:LandingPage())
end
