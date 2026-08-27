local _, LS = ...

-- Workspaces, not content categories. Dashboard is a widget layout. Professions and
-- Great Vault open from those widgets. Progress is the tracked list.
local workspaces = {
  { name = "TODAY", items = {
      { "DASHBOARD", "Dashboard", "Interface\\Icons\\INV_Misc_Note_01" },
    } },
  { name = "PLANNING", items = {
      { "TODAY", "Today's Plan", "Interface\\Minimap\\Minimap-Waypoint-MapPin-Tracked" },
      { "WEEKLY", "Weekly Plan", "Interface\\Icons\\INV_Misc_PocketWatch_01" },
      { "LONGTERM", "Long-Term Goals", "Interface\\Icons\\INV_BannerPVP_03" },
    } },
  { name = "TRACKING", items = {
      { "PROGRESS", "Progress", "Interface\\Icons\\Achievement_General" },
      { "IGNORED", "Ignored Tasks", "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
      { "COMPLETED", "Completed Tasks", "Interface\\RaidFrame\\ReadyCheck-Ready" },
    } },
  { name = "ACCOUNT", items = {
      { "WARBAND", "Warband", "Interface\\Icons\\Spell_Fire_Fire" },
      { "SETTINGS", "Settings", "Interface\\Icons\\INV_Misc_Gear_01" },
      { "CHANGELOG", "Changelog", "Interface\\Icons\\INV_Misc_Note_06" },
      { "FAQ", "FAQ", "Interface\\HelpFrame\\HelpIcon-KnowledgeBase" },
      { "HELP", "Help", "Interface\\Icons\\INV_Misc_Book_09" },
    } },
}

local SIDE_EXPANDED, SIDE_COLLAPSED, SIDE_GAP = 180, 52, 16

local goalList = {
  { "ENDGAME", "Great Vault & endgame" },
  { "SOLO", "Solo content" },
  { "PREY", "Prey hunts" },
  { "PVP", "PvP" },
  { "HOUSING", "Housing" },
  { "CRAFTING", "Professions" },
  { "MOUNTS", "Mounts" },
  { "PETS", "Battle Pets" },
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

local function button(parent, label, width, height, size)
  local frame = panel(parent)
  frame:SetSize(width or 130, height or 34)
  frame.text = text(frame, width or 130, size or 12)
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
-- DefaultPanelTemplate's title bar. Blizzard's own inset on this template is y = -26.
local CHROME_TOP = 26

function LS:UpdateChrome(wanted)
  if wanted and not self.chrome and not self.chromeMissing then
    for _, template in ipairs(CHROME_TEMPLATES) do
      local ok, frame = pcall(CreateFrame, "Frame", nil, self.frame, template)
      if ok and frame then
        frame:SetAllPoints(self.frame)
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
  -- The template is created after the header, and its NineSlice children raise
  -- themselves over the logo. Keep the art behind every widget.
  self:StackChrome(active)
  return active
end

local function LowerTree(frame, level, depth)
  if type(frame) ~= "table" or (depth or 0) > 10 then return end
  if type(frame.SetFrameLevel) == "function" then
    pcall(frame.SetFrameLevel, frame, level)
  end
  if type(frame.EnableMouse) == "function" then
    pcall(frame.EnableMouse, frame, false)
  end
  if type(frame.EnableKeyboard) == "function" then
    pcall(frame.EnableKeyboard, frame, false)
  end
  if type(frame.GetChildren) == "function" then
    local kids = { frame:GetChildren() }
    for _, child in ipairs(kids) do
      LowerTree(child, level, (depth or 0) + 1)
    end
  end
  if type(frame.NineSlice) == "table" then
    LowerTree(frame.NineSlice, level, (depth or 0) + 1)
    for _, piece in pairs(frame.NineSlice) do
      if type(piece) == "table" and piece ~= frame.NineSlice then
        LowerTree(piece, level, (depth or 0) + 1)
      end
    end
  end
end

-- Chrome shares the window with the header. NineSlice pieces often sit many
-- levels above the template, so the whole tree is flattened before the title
-- is raised over it.
function LS:StackChrome(active)
  if not self.frame then return end
  local base = self.frame:GetFrameLevel() or 1
  if self.chrome then
    LowerTree(self.chrome, base + 1, 0)
    local container = self.chrome.TitleContainer
    if type(container) == "table" then
      local title = container.TitleText
      if type(title) == "table" and title.Hide then pcall(title.Hide, title) end
    end
  end
  local above = base + (active and 20 or 2)
  if self.sidebar then self.sidebar:SetFrameLevel(above) end
  if self.content then self.content:SetFrameLevel(above) end
  if self.header then self.header:SetFrameLevel(above + 8) end
  if self.resizeGrip then self.resizeGrip:SetFrameLevel(above + 10) end
end

-- Blizzard's border art is far thicker than a one pixel edge, so the content moves inward
-- to sit inside it rather than under it. The title bar is taller than the side borders.
function LS:SidebarCollapsed()
  return self.db and self.db.sidebarCollapsed and true or false
end

function LS:SidebarWidth()
  return self:SidebarCollapsed() and SIDE_COLLAPSED or SIDE_EXPANDED
end

function LS:SetSidebarCollapsed(on)
  if not self.db then return end
  self.db.sidebarCollapsed = on and true or false
  self:BuildSidebar()
  if self.ApplyTheme then self:ApplyTheme() end
  if self.frame and self.frame:IsShown() then
    self:ShowPage(self.page or "DASHBOARD")
  end
end

function LS:LayoutFrame(pad)
  local side = self:SidebarWidth()
  if self.layoutPad == pad and self.layoutSide == side then return end
  self.layoutPad = pad
  self.layoutSide = side

  local top = (pad > 0) and CHROME_TOP or 1
  self.header:ClearAllPoints()
  self.header:SetPoint("TOPLEFT", 1 + pad, -top)
  self.header:SetPoint("TOPRIGHT", -(1 + pad), -top)

  local belowHeader = 68 + ((pad > 0) and CHROME_TOP or pad)
  self.sidebar:ClearAllPoints()
  self.sidebar:SetPoint("TOPLEFT", 12 + pad, -belowHeader)
  self.sidebar:SetPoint("BOTTOMLEFT", 12 + pad, 14 + pad)
  self.sidebar:SetWidth(side)

  local contentLeft = 12 + side + SIDE_GAP
  self.content:ClearAllPoints()
  self.content:SetPoint("TOPLEFT", contentLeft + pad, -(76 + ((pad > 0) and CHROME_TOP or pad)))
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
  if self.EndWidgetDrag then self:EndWidgetDrag() end
  self.dashboardSlots = nil
  self.dashboardCanvas = nil
  for _, child in ipairs({ self.content:GetChildren() }) do
    if child ~= self.bodyScroll then
      if child.menu then child.menu:Hide() end
      child:Hide()
      child:SetParent(nil)
    end
  end
  for _, region in ipairs({ self.content:GetRegions() }) do
    region:Hide()
  end
  if self.bodyChild then
    for _, child in ipairs({ self.bodyChild:GetChildren() }) do
      child:Hide()
      child:SetParent(nil)
    end
    for _, region in ipairs({ self.bodyChild:GetRegions() }) do
      region:Hide()
    end
  end
  if self.bodyScroll then self.bodyScroll:Hide() end
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
  -- Nameplates live on HIGH. MEDIUM lets them draw through the cards. DIALOG
  -- covers the client's calendar, Mythic+, and vault, so HIGH sits above
  -- nameplates and those panels can raise to DIALOG in front.
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  -- Do not set OnKeyDown. The client enables keyboard capture on any shown
  -- frame that has that handler, so WASD, jump, Enter, and chat never reach
  -- the world. Escape still closes through UISpecialFrames.
  if UISpecialFrames then
    local listed = false
    for _, name in ipairs(UISpecialFrames) do
      if name == "LodestarFrame" then listed = true break end
    end
    if not listed then table.insert(UISpecialFrames, "LodestarFrame") end
  end
  if frame.EnableKeyboard then frame:EnableKeyboard(false) end
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
  -- Compact stays up while this window is open; refresh it either way.
  frame:SetScript("OnShow", function(selfFrame)
    if selfFrame.EnableKeyboard then selfFrame:EnableKeyboard(false) end
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

  self.logo = self.header:CreateTexture(nil, "OVERLAY")
  self.logo:SetSize(40, 40)
  self.logo:SetPoint("LEFT", 10, 0)
  self.logo:SetTexture(LS.MEDIA)
  if self.logo.SetDrawLayer then self.logo:SetDrawLayer("OVERLAY", 7) end

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
  self.sidebar:SetWidth(self:SidebarWidth())

  self.content = CreateFrame("Frame", nil, frame)
  self.content:SetPoint("TOPLEFT", 208, -76)
  self.content:SetPoint("BOTTOMRIGHT", -30, 22)

  self:BuildSidebar()

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

function LS:NavActive(key)
  local page = self.page
  if key == page then return true end
  if key == "DASHBOARD" and (page == "PROFESSIONS" or page == "VAULT") then return true end
  return false
end

local function Tip(owner, label)
  if not GameTooltip then return end
  if GameTooltip.SetOwner then pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_RIGHT") end
  if GameTooltip.ClearLines then pcall(GameTooltip.ClearLines, GameTooltip) end
  if GameTooltip.SetText then
    GameTooltip:SetText(label)
  elseif GameTooltip.AddLine then
    GameTooltip:AddLine(label)
  end
  if GameTooltip.Show then pcall(GameTooltip.Show, GameTooltip) end
end

local function PaintNavIcon(tex, path)
  if not tex or type(path) ~= "string" or path == "" then return end
  if tex.SetTexture then tex:SetTexture(path) end
  if tex.SetTexCoord then
    if path:find("Icons\\", 1, true) or path:find("Icons/", 1, true) then
      tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
      tex:SetTexCoord(0, 1, 0, 1)
    end
  end
end

local function HideTip()
  if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end
end

function LS:BuildSidebar()
  if not self.sidebar then return end
  local collapsed = self:SidebarCollapsed()
  local inner = collapsed and 36 or 164
  local navW = collapsed and 36 or 156

  if not self.sidebarBody then
    local version = text(self.sidebar, 164, 10)
    version:SetPoint("BOTTOMLEFT", 8, 10)
    version:SetPoint("BOTTOMRIGHT", -6, 10)
    version:SetJustifyH("LEFT")
    self.sidebarVersion = version

    local toggle = button(self.sidebar, "«", 36, 22, 12)
    toggle:SetPoint("TOPLEFT", 8, -8)
    self.sidebarToggle = toggle

    local scroll = CreateFrame("ScrollFrame", nil, self.sidebar)
    self.sidebarScroll = scroll
    local child = CreateFrame("Frame", nil, scroll)
    child:SetHeight(1)
    if scroll.SetScrollChild then scroll:SetScrollChild(child) end
    self.sidebarBody = child
  else
    for _, child in ipairs({ self.sidebarBody:GetChildren() }) do
      child:Hide()
      child:SetParent(nil)
    end
    for _, region in ipairs({ self.sidebarBody:GetRegions() }) do
      region:Hide()
    end
  end

  local version = self.sidebarVersion
  version:SetText("v" .. (self.version or ""))
  version:Show()
  version:ClearAllPoints()
  version:SetPoint("BOTTOMLEFT", collapsed and 4 or 8, 10)
  version:SetPoint("BOTTOMRIGHT", -4, 10)
  version:SetJustifyH("LEFT")
  if version.SetFont then
    version:SetFont(self:ThemeFont(), collapsed and 8 or 10, "")
  end
  if version.SetWidth then version:SetWidth(inner) end
  if self.colors then version:SetTextColor(unpack(self.colors.muted)) end

  local toggle = self.sidebarToggle
  toggle:SetWidth(navW)
  toggle.text:SetWidth(navW)
  toggle.text:SetText(collapsed and "»" or "«")
  toggle:SetScript("OnMouseUp", function()
    self:SetSidebarCollapsed(not self:SidebarCollapsed())
  end)
  toggle:SetScript("OnEnter", function(selfFrame)
    selfFrame:SetBackdropBorderColor(unpack(LS.colors.accent))
    Tip(selfFrame, collapsed and "Show menu" or "Hide menu")
  end)
  toggle:SetScript("OnLeave", function(selfFrame)
    selfFrame:SetBackdropBorderColor(unpack(LS.colors.border))
    HideTip()
  end)

  local scroll = self.sidebarScroll
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", 8, -34)
  scroll:SetPoint("BOTTOMRIGHT", -4, 28)

  local child = self.sidebarBody
  child:SetWidth(inner)
  self.nav = {}
  self.navHeaders = {}

  local y = 0
  for _, group in ipairs(workspaces) do
    if not collapsed then
      local header = text(child, inner - 4, 9)
      header:SetPoint("TOPLEFT", 6, y)
      header:SetText(group.name)
      if self.colors then header:SetTextColor(unpack(self.colors.muted)) end
      table.insert(self.navHeaders, header)
      y = y - 18
    end
    for _, item in ipairs(group.items) do
      local nav = button(child, collapsed and "" or item[2], navW, 26, 11)
      nav:SetPoint("TOPLEFT", collapsed and 0 or 4, y)
      if nav.text then
        if collapsed then
          if nav.text.SetShown then nav.text:SetShown(false) end
          nav.text:SetText("")
        else
          if nav.text.SetShown then nav.text:SetShown(true) end
          nav.text:ClearAllPoints()
          nav.text:SetPoint("LEFT", 26, 0)
          nav.text:SetWidth(navW - 32)
          nav.text:SetJustifyH("LEFT")
          nav.text:SetText(item[2])
        end
      end
      local art = nav:CreateTexture(nil, "ARTWORK")
      if collapsed then
        art:SetSize(18, 18)
        art:SetPoint("CENTER", 0, 0)
      else
        art:SetSize(14, 14)
        art:SetPoint("LEFT", 6, 0)
      end
      PaintNavIcon(art, item[3])
      nav.icon = art
      nav:SetScript("OnMouseUp", function() self:ShowPage(item[1]) end)
      nav:SetScript("OnEnter", function(selfFrame)
        if LS.colors then selfFrame:SetBackdropBorderColor(unpack(LS.colors.accent)) end
        if collapsed then Tip(selfFrame, item[2]) end
      end)
      nav:SetScript("OnLeave", function(selfFrame)
        local active = LS.NavActive and LS:NavActive(item[1])
        if LS.colors then
          selfFrame:SetBackdropBorderColor(unpack(active and LS.colors.accent or LS.colors.border))
        end
        HideTip()
      end)
      self.nav[item[1]] = nav
      y = y - 30
    end
    y = y - (collapsed and 4 or 8)
  end
  child:SetHeight(math.max(1, -y + 8))
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

-- Full-width strip used by plan pages, Great Vault, Professions and Settings. One click
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
    if self.MarkCoach then self:MarkCoach("tab:" .. tab[1], nav) end
  end
  local rows = math.ceil(n / perRow)
  return chosen, rows * height + (rows - 1) * gap
end

function LS:ShowPage(page)
  if page == "TUTORIAL" then
    if self.ShowCurrentTip then self:ShowCurrentTip() end
    return
  end
  self.page = page
  self.coachMarks = {}
  self:Clear()
  self:ApplyTheme()
  if page == "WELCOME" then
    self:WelcomePage()
  elseif page == "DASHBOARD" then
    self:DashboardPage()
  elseif page == "WEEKLY" then
    self:WeeklyPlanPage()
  elseif page == "LONGTERM" then
    self:LongTermPage()
  elseif page == "PROGRESS" then
    self:ProgressPage()
  elseif page == "IGNORED" then
    self:FlaggedPage("dismissed", "Ignored tasks",
      "Cards you hid from the plan. Restore one to put it back, or clear them in Settings.")
  elseif page == "COMPLETED" then
    self:FlaggedPage("completed", "Completed tasks",
      "Cards you marked done. Undo one if it should rank again.")
  elseif page == "VAULT" then
    self:VaultPage()
  elseif page == "PROFESSIONS" then
    self:ProfessionsPage()
  elseif page == "WARBAND" then
    self:WarbandPage()
  elseif page == "SETTINGS" then
    self:Settings()
  elseif page == "CHANGELOG" then
    self:ChangelogPage()
  elseif page == "FAQ" then
    self:FAQPage()
  elseif page == "HELP" then
    self:HelpPage()
  elseif page == "DETAILS" then
    self:DetailsPage()
  else
    self:Today()
  end
  if self.coachActive and self.PresentCoach then
    self:PresentCoach()
  elseif self.HideCoach then
    self:HideCoach()
  end
end

-- Scrollable body shared by every page that can overflow. Reused so edit-mode
-- redraws cannot stack a second canvas on top of the last one.
function LS:Body(topOffset)
  local width = self:ContentWidth() - 18
  local scroll = self.bodyScroll
  -- Edit mode and token/currency refreshes rebuild the page. Keep the offset
  -- when we stay on the same tab so the canvas does not jump back to the top.
  local keep = 0
  if scroll and self._bodyPage == self.page then
    keep = scroll:GetVerticalScroll() or 0
  end
  self._bodyPage = self.page
  if not scroll then
    scroll = CreateFrame("ScrollFrame", nil, self.content)
    self.bodyScroll = scroll
    if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
    local child = CreateFrame("Frame", nil, scroll)
    self.bodyChild = child
    local bar = CreateFrame("Slider", nil, scroll, "BackdropTemplate")
    self.bodyBar = bar
    bar:SetWidth(8)
    bar:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8" })
    bar:SetOrientation("VERTICAL")
    bar:SetThumbTexture("Interface/Buttons/WHITE8X8")
    bar:GetThumbTexture():SetSize(8, 40)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)

    local function sync(value)
      local maxScroll = math.max(0, child:GetHeight() - scroll:GetHeight())
      local minV, maxV = 0, 0
      if bar.GetMinMaxValues then
        minV, maxV = bar:GetMinMaxValues()
      end
      if minV ~= 0 or maxV ~= maxScroll then
        bar._syncing = true
        bar:SetMinMaxValues(0, maxScroll)
        bar._syncing = nil
      end
      if maxScroll <= 0 then
        bar:Hide()
        scroll:SetVerticalScroll(0)
        return
      end
      bar:Show()
      value = math.min(maxScroll, math.max(0, value or scroll:GetVerticalScroll()))
      scroll:SetVerticalScroll(value)
      bar._syncing = true
      bar:SetValue(value)
      bar._syncing = nil
    end
    self._bodySync = sync

    bar:SetScript("OnValueChanged", function(_, value)
      if bar._syncing then return end
      scroll:SetVerticalScroll(value)
    end)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) sync(scroll:GetVerticalScroll() - delta * 44) end)
    scroll:SetScript("OnSizeChanged", function() sync(scroll:GetVerticalScroll()) end)
    child:EnableMouseWheel(true)
    child:SetScript("OnMouseWheel", function(_, delta) sync(scroll:GetVerticalScroll() - delta * 44) end)
    scroll:SetScrollChild(child)
  end

  scroll:SetParent(self.content)
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", 0, -(topOffset or 62))
  scroll:SetPoint("BOTTOMRIGHT", -18, 0)
  scroll:Show()
  if self.content.SetClipsChildren then self.content:SetClipsChildren(true) end

  local child = self.bodyChild
  child:SetWidth(width)
  child:EnableMouse(false)
  child:SetScript("OnMouseUp", nil)
  -- Leave the last height in place until finish. Collapsing to 1px (or calling
  -- SetScrollChild again) zeroes max scroll and snaps the view to the top.
  for _, kid in ipairs({ child:GetChildren() }) do
    kid:Hide()
    kid:SetParent(nil)
  end
  for _, region in ipairs({ child:GetRegions() }) do
    region:Hide()
  end

  local bar = self.bodyBar
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
  bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
  if self.colors then
    bar:SetBackdropColor(unpack(self.colors.panel))
    bar:GetThumbTexture():SetColorTexture(unpack(self.colors.accent))
  end
  child.finish = function(_, height)
    child:SetHeight(math.max(1, height))
    local restore = keep
    C_Timer.After(0, function()
      if LS._bodySync then LS._bodySync(restore) end
    end)
  end
  child.width = width
  return child
end

local function FitLine(fs, width, lines)
  if not fs then return end
  lines = lines or 1
  if fs.SetWidth then fs:SetWidth(math.max(40, width)) end
  if fs.SetWordWrap then fs:SetWordWrap(lines > 1) end
  if fs.SetMaxLines then fs:SetMaxLines(lines) end
  if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
end

function LS:FitText(fs, width, lines)
  FitLine(fs, width, lines)
end

local CARD_HEIGHT = 104
local CARD_GAP = 10
local ACTION_W, ACTION_H = 74, 26

function LS:ActivityCard(parent, activity, y, width)
  local card = panel(parent)
  card:SetPoint("TOPLEFT", 0, y)
  paint(card)
  card:EnableMouse(true)
  if card.SetClipsChildren then card:SetClipsChildren(true) end

  local tracked = self.db.tracked[activity.id]
  if tracked then
    card:SetBackdropBorderColor(unpack(self.colors.accent))
  end

  local actions = {}
  if activity.open then
    table.insert(actions, { activity.openLabel or "Open", activity.open })
  end
  table.insert(actions, { "Details", function() self:ShowDetails(activity.id) end })
  if self.page == "PROGRESS" then
    table.insert(actions, 1, { "Untrack", function()
      self.db.tracked[activity.id] = nil
      if self.UpdateCompact then self:UpdateCompact() end
      self:ShowPage("PROGRESS")
    end })
  end
  table.insert(actions, { "Done", function()
    self.db.completed[activity.id] = true
    self:ShowPage(self.page == "DETAILS" and "TODAY" or (self.page or "TODAY"))
  end })
  table.insert(actions, { "Ignore", function()
    self.db.dismissed[activity.id] = true
    self:ShowPage(self.page == "DETAILS" and "TODAY" or (self.page or "TODAY"))
  end })

  -- Side buttons need ~90px. Below that, stack them so title/why keep a readable column.
  local stacked = width < 280
  local cols = stacked and math.max(1, math.floor((width - 20) / (ACTION_W + 6))) or 1
  local actionRows = math.ceil(#actions / cols)
  local textW = stacked and (width - 32) or (width - ACTION_W - 28)
  local height = stacked and (72 + actionRows * (ACTION_H + 6))
    or (CARD_HEIGHT + math.max(0, #actions - 3) * 30)
  card:SetSize(width, height)

  local title = text(card, textW, 14)
  title:SetPoint("TOPLEFT", 16, -10)
  title:SetTextColor(unpack(self.colors.accent))
  title:SetText((activity.priority and (activity.priority .. "  •  ") or "") .. activity.title)
  FitLine(title, textW, 1)

  local why = text(card, textW, 11)
  why:SetPoint("TOPLEFT", 16, -30)
  if why.SetHeight then why:SetHeight(28) end
  why:SetText(activity.why or "")
  FitLine(why, textW, 2)

  local label, tone = self:Urgency(activity)
  local meta = text(card, textW, 10)
  if stacked then
    meta:SetPoint("TOPLEFT", 16, -60)
  else
    meta:SetPoint("BOTTOMLEFT", 16, 12)
  end
  meta:SetText(string.format("%s  •  score %d%s",
    self:Colorize(label, tone),
    math.floor(activity.score or 0), tracked and "  •  tracked" or ""))
  FitLine(meta, textW, 1)

  for j, action in ipairs(actions) do
    local actionButton = button(card, action[1], ACTION_W, ACTION_H)
    if stacked then
      local col = (j - 1) % cols
      local row = math.floor((j - 1) / cols)
      actionButton:SetPoint("TOPLEFT", 10 + col * (ACTION_W + 6), -72 - row * (ACTION_H + 6))
    else
      actionButton:SetPoint("TOPRIGHT", -10, -14 - (j - 1) * 30)
    end
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
      if self.HasUnseenTips and self:HasUnseenTips() then
        self.tutorialReturn = "TODAY"
        self:ShowPage("TUTORIAL")
      else
        self:ShowPage("TODAY")
      end
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

function LS:TutorialPage()
  if self.ShowCurrentTip then self:ShowCurrentTip() end
end

function LS:HideCoach()
  if self.coach then self.coach:Hide() end
  if self.coachRing then self.coachRing:Hide() end
end

function LS:EnsureCoach()
  if self.coach then return self.coach end
  local coach = panel(self.frame)
  coach:SetFrameStrata("FULLSCREEN_DIALOG")
  if coach.SetFrameLevel then coach:SetFrameLevel(200) end
  coach:SetPoint("BOTTOMLEFT", 16, 16)
  coach:SetPoint("BOTTOMRIGHT", -16, 16)
  coach:SetHeight(148)
  paint(coach, "panel")
  if self.colors then
    coach:SetBackdropBorderColor(unpack(self.colors.accent))
  end
  local width = 500
  local progress = text(coach, width, 10)
  progress:SetPoint("TOPLEFT", 14, -10)
  if self.colors then progress:SetTextColor(unpack(self.colors.muted)) end
  coach.progress = progress
  local title = text(coach, width, 14)
  title:SetPoint("TOPLEFT", 14, -26)
  if self.colors then title:SetTextColor(unpack(self.colors.accent)) end
  coach.title = title
  local body = text(coach, width, 11)
  body:SetPoint("TOPLEFT", 14, -48)
  body:SetHeight(52)
  coach.body = body
  local skip = button(coach, "Skip", 110, 28)
  skip:SetPoint("BOTTOMLEFT", 14, 12)
  skip:SetScript("OnMouseUp", function()
    if self.SkipRemainingTips then self:SkipRemainingTips() end
    self:FinishTutorial()
  end)
  coach.skip = skip
  local nextBtn = button(coach, "Next", 110, 28)
  nextBtn:SetPoint("BOTTOMLEFT", 132, 12)
  highlight(nextBtn)
  nextBtn:SetScript("OnMouseUp", function()
    local tip = self.CurrentTip and self:CurrentTip()
    if tip then self:MarkTipSeen(tip.id) end
    if self:HasUnseenTips() then
      self:ShowCurrentTip()
    else
      self:FinishTutorial()
    end
  end)
  coach.next = nextBtn
  self.coach = coach
  return coach
end

function LS:PresentCoach()
  local tip = self.CurrentTip and self:CurrentTip()
  if not tip then
    self:HideCoach()
    return
  end
  local coach = self:EnsureCoach()
  coach:Show()
  local total = #self.TIPS
  local seen = 0
  for _, row in ipairs(self.TIPS) do
    if self.db.seenTips and self.db.seenTips[row.id] then seen = seen + 1 end
  end
  coach.progress:SetText(string.format("Tip %d of %d. Skip hides the rest.", seen + 1, total))
  coach.title:SetText(tip.title)
  coach.body:SetText(tip.body)
  local last = not self:HasUnseenTips() or #self:UnseenTips() <= 1
  coach.next.text:SetText(last and "Done" or "Next")
  local mark = self.TipHighlight and self:TipHighlight(tip)
  local target = mark and self.coachMarks and self.coachMarks[mark]
  if target and target.SetBackdropBorderColor and self.colors then
    target:SetBackdropBorderColor(unpack(self.colors.accent))
  end
  if not self.coachRing then
    local ring = panel(self.frame)
    ring:SetFrameStrata("FULLSCREEN_DIALOG")
    if ring.SetFrameLevel then ring:SetFrameLevel(190) end
    ring:EnableMouse(false)
    self.coachRing = ring
  end
  if target then
    self.coachRing:SetParent(target)
    if self.coachRing.SetAllPoints then self.coachRing:SetAllPoints(target) end
    paint(self.coachRing, "card")
    if self.colors then
      self.coachRing:SetBackdropColor(0, 0, 0, 0)
      self.coachRing:SetBackdropBorderColor(unpack(self.colors.accent))
    end
    self.coachRing:Show()
  else
    self.coachRing:Hide()
  end
end

function LS:CountFlags(store)
  local n = 0
  for _, on in pairs(self.db and self.db[store] or {}) do
    if on then n = n + 1 end
  end
  return n
end

function LS:VaultSlotCounts()
  local filled, total, upgradable = 0, 0, 0
  for _, key in ipairs({ "raid", "activities", "world" }) do
    local row = self.vault and self.vault.rows and self.vault.rows[key]
    if row then
      for _, slot in ipairs(row.slots or {}) do
        total = total + 1
        if slot.complete then filled = filled + 1 end
        if slot.advice and slot.advice.upgradable then upgradable = upgradable + 1 end
      end
    end
  end
  return filled, total, upgradable
end

function LS:UnspentKnowledge()
  if self.ProfessionSummary then
    local n = self:ProfessionSummary()
    return n or 0
  end
  local n = 0
  for _, prof in ipairs(self.CurrentExpansionProfessions and self:CurrentExpansionProfessions() or self.professions or {}) do
    if not (self.ProfessionTreesFull and self:ProfessionTreesFull(prof)) then
      n = n + (prof.unspent or 0)
    end
  end
  return n
end

function LS:ProfessionsHubCard(parent, width, y)
  local current = self.CurrentExpansionProfessions and self:CurrentExpansionProfessions() or self.professions or {}
  local trained = #current
  local unspent = self:UnspentKnowledge()
  local card = panel(parent)
  card:SetSize(width, 72)
  card:SetPoint("TOPLEFT", 0, y)
  paint(card)
  local title = text(card, width - 120, 13)
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetTextColor(unpack(self.colors.accent))
  title:SetText("Professions")
  local line = text(card, width - 120, 11)
  line:SetPoint("TOPLEFT", 12, -34)
  if trained == 0 and #(self.professions or {}) == 0 then
    line:SetText("Open a profession window once so the client sends its data.")
  else
    line:SetText(string.format("%d trained. %d unspent knowledge this expansion.", trained, unspent))
  end
  local open = button(card, "Open", 74, 26)
  open:SetPoint("TOPRIGHT", -10, -14)
  paint(open, "panel")
  open:SetScript("OnMouseUp", function() self:ShowPage("PROFESSIONS") end)
  return y - 82
end

function LS:RenderPlan(groups, pageKey, title)
  local tabs = {}
  for _, group in ipairs(groups) do
    table.insert(tabs, { group.name, group.name })
  end
  local chosen = self:PickTab(tabs, self:PageTab(pageKey))
  local group = groups[1]
  for _, entry in ipairs(groups) do
    if entry.name == chosen[1] then group = entry end
  end

  self:Heading(title,
    string.format("%d %s",
      #group.activities, #group.activities == 1 and "recommendation" or "recommendations"))
  self:TabStrip(tabs, chosen[1], function(id)
    self:SetPageTab(pageKey, id)
    self:ShowPage(pageKey)
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

function LS:PlanEmpty(title, why, pickLabel, onPick)
  self:Heading(title, "Nothing in this workspace right now.")
  local body = self:Body(76)
  local none = text(body, body.width, 11)
  none:SetPoint("TOPLEFT", 0, 0)
  none:SetText(why)
  if pickLabel and onPick then
    local pick = button(body, pickLabel, 200, 30)
    pick:SetPoint("TOPLEFT", 0, -42)
    highlight(pick)
    pick:SetScript("OnMouseUp", onPick)
    body:finish(90)
  else
    body:finish(50)
  end
end

function LS:ShowVaultTooltip(owner, slot)
  if not GameTooltip then return end
  if GameTooltip.SetOwner then pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_RIGHT") end
  if GameTooltip.ClearLines then pcall(GameTooltip.ClearLines, GameTooltip) end
  if GameTooltip.AddLine then
    GameTooltip:AddLine("Great Vault")
    if self.IsEndgameLevel and not self:IsEndgameLevel() then
      GameTooltip:AddLine("Opens at level " .. self:EndgameLevel() .. ". Level and enjoy the game until then.")
      if GameTooltip.Show then pcall(GameTooltip.Show, GameTooltip) end
      return
    end
    local lines
    if slot and self.VaultSlotTooltipLines then
      lines = self:VaultSlotTooltipLines(slot)
    elseif self.VaultTooltipLines then
      lines = self:VaultTooltipLines()
    end
    for _, line in ipairs(lines or {}) do
      GameTooltip:AddLine(line)
    end
  end
  if GameTooltip.Show then pcall(GameTooltip.Show, GameTooltip) end
end

function LS:HideVaultTooltip()
  if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end
end

function LS:WeeklyPlanPage()
  local groups = self:GetCategories("WEEKLY")
  if #groups == 0 then
    self:PlanEmpty("Weekly plan",
      "Nothing on the plan disappears at weekly reset, or those goals are off.")
    return
  end
  self:RenderPlan(groups, "WEEKLY", "Weekly plan")
end

function LS:LongTermPage()
  local groups = self:GetCategories("LONG")
  if #groups == 0 then
    self:PlanEmpty("Long-term goals",
      "Nothing long-term is being ranked. Turn on Mounts, Reputation or Gold in Settings, or finish this week's profession work to see treasures and catch-up.",
      "Open Settings", function()
        self:SetPageTab("SETTINGS", "GOALS")
        self:ShowPage("SETTINGS")
      end)
    return
  end
  self:RenderPlan(groups, "LONGTERM", "Long-term goals")
end

function LS:ProgressPage()
  local tracked = self:TrackedActivities()
  self:Heading("Progress", "Activities you tracked. Compact mode shows the same list.")
  local body = self:Body(76)
  local width = body.width
  local y = 0
  if #tracked == 0 then
    local none = text(body, width, 11)
    none:SetPoint("TOPLEFT", 0, 0)
    none:SetText("Nothing tracked yet. Open Details on a card and Track it.")
    body:finish(40)
    return
  end
  for _, activity in ipairs(tracked) do
    local _, h = self:ActivityCard(body, activity, y, width)
    y = y - ((h or CARD_HEIGHT) + CARD_GAP)
  end
  body:finish(-y + 10)
end

function LS:FlaggedPage(store, title, why)
  local ids = {}
  for id, on in pairs(self.db and self.db[store] or {}) do
    if on then table.insert(ids, id) end
  end
  table.sort(ids, function(a, b)
    local aa, bb = self:FindActivity(a), self:FindActivity(b)
    local left = (aa and aa.title) or self:ActivityLabel(a)
    local right = (bb and bb.title) or self:ActivityLabel(b)
    return left < right
  end)

  self:Heading(title, why)
  local body = self:Body(76)
  local width = body.width
  local y = 0
  if #ids == 0 then
    local none = text(body, width, 11)
    none:SetPoint("TOPLEFT", 0, 0)
    none:SetText("Nothing here yet.")
    body:finish(40)
    return
  end

  for _, id in ipairs(ids) do
    local activity = self:FindActivity(id)
    local card = panel(body)
    card:SetSize(width, 68)
    card:SetPoint("TOPLEFT", 0, y)
    paint(card)
    local heading = text(card, width - 120, 13)
    heading:SetPoint("TOPLEFT", 12, -10)
    heading:SetTextColor(unpack(self.colors.accent))
    heading:SetText((activity and activity.title) or self:ActivityLabel(id))
    local line = text(card, width - 120, 11)
    line:SetPoint("TOPLEFT", 12, -34)
    line:SetText((activity and activity.why) or "That activity is no longer being generated.")
    local action = button(card, store == "dismissed" and "Restore" or "Undo", 74, 26)
    action:SetPoint("TOPRIGHT", -10, -14)
    paint(action, "panel")
    action:SetScript("OnMouseUp", function()
      self.db[store][id] = nil
      self:ShowPage(self.page)
    end)
    y = y - 76
  end
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

  self:RenderPlan(groups, "TODAY", "Your plan for today")
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
    self:Heading(self:ActivityLabel(self.detailID), "That activity is no longer on your plan.")
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
    if self.UpdateCompact then self:UpdateCompact() end
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
  if self.IsEndgameLevel and not self:IsEndgameLevel() then
    local cap = self:EndgameLevel()
    self:Heading("Great Vault", "Opens at level " .. cap)
    local body = self:Body(70)
    local line = text(body, body.width, 11)
    line:SetPoint("TOPLEFT", 0, 0)
    line:SetText("Great Vault is an endgame chest. Until then, level and enjoy the game. Train professions along the way if you want them.")
    body:finish(50)
    return
  end

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
  card:EnableMouse(true)
  card:SetScript("OnEnter", function(selfFrame)
    LS:ShowVaultTooltip(selfFrame, slot)
  end)
  card:SetScript("OnLeave", function() LS:HideVaultTooltip() end)
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
      subtitle = self:ProfessionKnowledgeCaption(selected)
    end
  elseif #self.professions > 0 then
    subtitle = string.format("Nothing for %s. Switch the expansion focus to see your other professions.",
      self:FocusExpansionLabel())
  else
    subtitle = "Open a profession window once so the client sends its data."
  end
  self:Heading("Professions", subtitle)

  local labels, values = self:FocusExpansionChoices()
  local drop = self:Dropdown(self.content, 220, self:FocusExpansionLabel(), labels, function(choice)
    self:SetFocusExpansion(values[choice] or "current")
    self:ShowPage("PROFESSIONS")
  end)
  drop:SetPoint("TOPRIGHT", 0, -4)
  if hidden > 0 and self:FocusExpansion() ~= "all" then
    drop.text:SetText(string.format("%s  •  %d hidden", self:FocusExpansionLabel(), hidden))
  end

  if chosen then
    self:TabStrip(tabs, chosen[1], function(id)
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

  body:EnableMouse(true)
  body:SetScript("OnMouseUp", function()
    if LS.OpenProfessionWindow then LS:OpenProfessionWindow(selected, false) end
  end)

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
    if self:ProfessionTreesFull(prof) then
      add("Knowledge: " .. self:ProfessionKnowledgeCaption(prof))
    else
      local remaining = prof.remaining and (prof.remaining .. " to finish the tree") or "tree size unknown"
      if prof.spent then
        add(string.format("Knowledge: |cff62d26f%d unspent|r  •  %d spent  •  %s",
          prof.unspent or 0, prof.spent, remaining))
      else
        add(string.format("Knowledge: |cff62d26f%d unspent|r  •  %s", prof.unspent or 0, remaining))
      end
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
  if self:CanSpendKnowledge(prof) then
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
    if action[2] and self:CanSpendKnowledge(prof) then highlight(b) end
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

  local many = #characters > 1
  if many then
    local note = text(body, width, 10)
    note:SetPoint("TOPLEFT", 0, y)
    if self.colors then note:SetTextColor(unpack(self.colors.muted)) end
    note:SetText("Untrack an alt to leave them out of totals and warband gold.")
    y = y - 20
  end
  for _, character in ipairs(characters) do
    local card = panel(body)
    card:SetSize(width, 68)
    card:SetPoint("TOPLEFT", 0, y)
    paint(card)
    if character.isCurrent then
      card:SetBackdropBorderColor(unpack(self.colors.accent))
    end

    local controls = 0
    if not character.isCurrent then controls = controls + 80 end
    if many and not character.isCurrent then controls = controls + 108 end
    local textW = math.max(160, width - 24 - controls)

    local title = text(card, textW, 12)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(unpack(character.tracked and self.colors.accent or self.colors.muted))
    title:SetText(string.format("%s-%s%s", character.name, character.realm, character.isCurrent and "  (this character)" or ""))

    local line = text(card, textW, 11)
    line:SetPoint("TOPLEFT", 12, -30)
    line:SetText(string.format("Level %d %s  •  Vault %d/%d, %d upgradable",
      character.level, character.spec ~= "" and character.spec or character.class,
      character.vault.filled or 0, character.vault.total or 0, character.vault.upgradable or 0))

    local knowledge = text(card, textW, 10)
    knowledge:SetPoint("TOPLEFT", 12, -48)
    knowledge:SetText(string.format("Unspent knowledge %d  •  %d weekly knowledge left  •  mounts %d",
      character.knowledge.unspent or 0, character.knowledge.weeklyPoints or 0, character.mounts or 0))
    if not character.tracked then
      line:SetTextColor(unpack(self.colors.muted))
      knowledge:SetTextColor(unpack(self.colors.muted))
    end

    if not character.isCurrent then
      local key = character.key
      local forget = button(card, "Forget", 74, 24)
      forget:SetPoint("TOPRIGHT", -10, -10)
      paint(forget, "panel")
      forget:SetScript("OnMouseUp", function()
        self:ForgetCharacter(key)
        self:ShowPage("WARBAND")
      end)
      if many then
        local wasOn = character.tracked
        local track = button(card, (wasOn and "ON  •  " or "OFF  •  ") .. "Track", 100, 24)
        track:SetPoint("TOPRIGHT", -90, -10)
        if wasOn then
          highlight(track)
        else
          paint(track, "panel")
        end
        track:SetScript("OnMouseUp", function()
          self:SetCharacterTracked(key, not wasOn)
          self:ShowPage("WARBAND")
        end)
      end
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
  { "ADDONS", "Optional Addons", "Price sources, waypoints, and other addons Lodestar can use." },
  { "REPUTATION", "Reputation", "Which expansions, categories and factions to rank. This expansion is on by default." },
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
  local nest
  if chosen[1] == "REPUTATION" then
    if self.ScanReputations then self:ScanReputations() end
    local expansions = self.RepExpansionTabs and self:RepExpansionTabs() or {}
    if #expansions > 0 then
      -- Wrap the expansion strip only. Stretching this panel to the bottom
      -- covered the reused body scroll, so the faction list sat under a near-black sheet.
      nest = panel(self.content)
      nest:SetPoint("TOPLEFT", 0, -90)
      nest:SetPoint("TOPRIGHT", 0, -90)
      paint(nest, "panel")
      nest:SetBackdropBorderColor(unpack(self.colors.accent))
      local _, stripH = self:TabStrip(expansions, self:PageTab("REP"), function(id)
        self:SetPageTab("REP", id)
        self:ShowPage("SETTINGS")
      end, -8, nest)
      stripH = stripH or 30
      nest:SetHeight(stripH + 16)
      bodyOffset = 90 + stripH + 16
    end
  end

  local body = self:Body(bodyOffset)
  if nest and self.bodyScroll and self.bodyScroll.SetFrameLevel then
    self.bodyScroll:SetFrameLevel((nest:GetFrameLevel() or 1) + 2)
  end
  local width = chosen[1] == "REPUTATION" and body.width or math.min(420, body.width)
  local y = 0
  if chosen[1] == "GOALS" then
    y = self:SettingsGoals(body, width, y)
  elseif chosen[1] == "ADDONS" then
    y = self:SettingsAddons(body, width, y)
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
    if self.MarkCoach then self:MarkCoach("goal:" .. key, toggle) end
    y = y - 38
  end

  y = y - 8
  local focusHeading = text(body, width, 13)
  focusHeading:SetPoint("TOPLEFT", 0, y)
  focusHeading:SetTextColor(unpack(self.colors.accent))
  focusHeading:SetText("Expansion focus")
  y = y - 24

  local labels, values = self:FocusExpansionChoices()
  local drop = self:Dropdown(body, width, self:FocusExpansionLabel(), labels, function(choice)
    self:SetFocusExpansion(values[choice] or "current")
    self:ShowPage("SETTINGS")
  end)
  drop:SetPoint("TOPLEFT", 0, y)
  y = y - 42

  local goalNote = text(body, width, 10)
  goalNote:SetPoint("TOPLEFT", 0, y)
  if goalNote.SetWordWrap then goalNote:SetWordWrap(true) end
  goalNote:SetText("Professions and gold farms follow this. This expansion is the default. Pick All expansions to track older weeklies and treasures; leftover points on a finished tree still stay off Today. Pick a single older expansion for something like a Cataclysm mount. Reputation starts on this expansion; the Reputation tab can rank older factions. With every goal off there is nothing to rank, so Today will be empty.")
  y = y - 52
  return y
end

function LS:SettingsAddons(body, width, y)
  local detected = text(body, width, 13)
  detected:SetPoint("TOPLEFT", 0, y)
  detected:SetTextColor(unpack(self.colors.accent))
  detected:SetText("Detected addons")
  y = y - 22

  local loadedColor = { 0.31, 0.82, 0.40, 1 }
  for _, row in ipairs(self:OptionalAddonStatus()) do
    local on = row.loaded
    local line = text(body, width, 11)
    line:SetPoint("TOPLEFT", 0, y)
    line:SetText(row.name .. (on and "  ·  Loaded" or "  ·  Not loaded"))
    if on then
      line:SetTextColor(unpack(loadedColor))
    elseif self.colors then
      line:SetTextColor(unpack(self.colors.muted))
    end
    y = y - 18
  end
  y = y - 10

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

  local wayHeading = text(body, width, 13)
  wayHeading:SetPoint("TOPLEFT", 0, y)
  wayHeading:SetTextColor(unpack(self.colors.accent))
  wayHeading:SetText("Waypoints")
  y = y - 24

  local waySource = (self.db.waypointSource or "AUTO")
  local wayLabels, wayFromLabel = {}, {}
  for _, key in ipairs(self.waypointSourceOrder or { "AUTO", "TOMTOM", "BLIZZARD" }) do
    local label = (self.waypointSourceLabels and self.waypointSourceLabels[key]) or key
    table.insert(wayLabels, label)
    wayFromLabel[label] = key
  end
  local wayDrop = self:Dropdown(body, width, (self.waypointSourceLabels and self.waypointSourceLabels[waySource]) or waySource, wayLabels, function(choice)
    self.db.waypointSource = wayFromLabel[choice] or "AUTO"
    self:ShowPage("SETTINGS")
  end)
  wayDrop:SetPoint("TOPLEFT", 0, y)
  y = y - 42

  local wayNote = text(body, width, 10)
  wayNote:SetPoint("TOPLEFT", 0, y)
  local wayId, wayName, wayReady
  if self.ResolveWaypointSource then
    wayId, wayName, wayReady = self:ResolveWaypointSource()
  end
  if waySource == "BLIZZARD" then
    wayNote:SetText("The client's single map pin. TomTom is ignored even if it is loaded.")
  elseif waySource == "TOMTOM" and not wayReady then
    wayNote:SetTextColor(unpack(self.colors.warn))
    wayNote:SetText("TomTom is not loaded. Install it, or pick Auto / Blizzard waypoint.")
  elseif wayId == "TOMTOM" then
    wayNote:SetText("Pins go to TomTom. Auto uses TomTom when it is loaded, otherwise the client's map pin.")
  else
    wayNote:SetText("Auto uses TomTom when it is loaded, otherwise the client's single map pin.")
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
    hnNote:SetText("Solo content stays off the plan until that goal is on. HandyNotes notes packs follow once it is.")
  elseif self.HasHandyNotesPlugins and self:HasHandyNotesPlugins() then
    hnNote:SetText("HandyNotes is loaded with notes packs. Today will rank rares those packs mark in your zone, not treasures or other map marks. Known rewards stay hidden because the pack already hid them.")
  elseif self.HasHandyNotes and self:HasHandyNotes() then
    hnNote:SetText("HandyNotes is loaded, but it has no notes packs. Install one such as HandyNotes: Midnight or HandyNotes: Silvermoon. HandyNotes by itself has no pins, and Lodestar does not invent spawn data.")
  else
    hnNote:SetText("Install HandyNotes and a notes pack (Midnight, Silvermoon, and others) to rank nearby rares. HandyNotes by itself has no coordinates. Lodestar does not invent spawn data.")
  end
  y = y - 56
  return y
end

function LS:ChangelogPage()
  self:Heading("Changelog", "What changed in the last five versions.")
  local body = self:Body(70)
  local y = self:SettingsChangelog(body, body.width, 0)
  body:finish(math.max(40, -y + 10))
end

function LS:SettingsChangelog(body, width, y)
  local function drop(fs, gap)
    local h = 14
    if fs and fs.GetStringHeight then
      h = math.max(h, tonumber(fs:GetStringHeight()) or 0)
    end
    if fs and fs.SetHeight then fs:SetHeight(h) end
    return h + (gap or 4)
  end

  local intro = text(body, width, 11)
  intro:SetPoint("TOPLEFT", 0, y)
  if intro.SetWordWrap then intro:SetWordWrap(true) end
  intro:SetText("The last five versions. Added, changed, and removed. The full notes are on GitHub.")
  y = y - drop(intro, 16)

  for _, release in ipairs(self.CHANGELOG or {}) do
    local heading = text(body, width, 13)
    heading:SetPoint("TOPLEFT", 0, y)
    heading:SetTextColor(unpack(self.colors.accent))
    heading:SetText(release.version)
    y = y - drop(heading, 6)
    local notes = release.notes or {}
    for i, note in ipairs(notes) do
      local line = text(body, width, 11)
      line:SetPoint("TOPLEFT", 0, y)
      if line.SetWordWrap then line:SetWordWrap(true) end
      line:SetText("• " .. note)
      local last = i == #notes
      y = y - drop(line, last and 14 or 4)
    end
  end
  return y
end

function LS:SettingsReputation(body, width, y)
  if self.ScanReputations then self:ScanReputations() end
  local intro = text(body, width, 11)
  intro:SetPoint("TOPLEFT", 0, y)
  intro:SetText("This expansion is on by default. Open another tab to rank older factions, or turn this one off. Lodestar ranks the ones that are not finished and stays quiet about the rest.")
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
  -- Rank-all is the header for the list; groups and factions sit smaller underneath.
  local allW = width
  local groupW = math.max(220, width - 16)
  local factionW = math.max(200, width - 48)
  local all = button(body, (expansionOn and "ON  •  Rank all of " or "OFF  •  Rank all of ") .. expansion, allW, 32)
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
      local on, label, indent, rowW, rowH, font
      if row.kind == "group" then
        on = self:RepGroupOn(row.expansion, row.name)
        label = row.name
        indent = 12
        rowW, rowH, font = groupW, 24, 11
      else
        on = self:CaresAboutRep(row)
        local extra = row.isMajor and string.format("Renown %d", row.renown or 0)
          or (_G["FACTION_STANDING_LABEL" .. tostring(row.reaction or 0)] or "")
        label = extra ~= "" and (row.name .. "  •  " .. extra) or row.name
        indent = row.group and 28 or 12
        rowW, rowH, font = factionW, 20, 10
      end
      local toggle = button(body, (on and "ON  •  " or "OFF  •  ") .. label, rowW, rowH, font)
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
      y = y - (rowH + 4)
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
    if active == "ELVUI" then
      note:SetText("Using ElvUI's own backdrop, texture and font. Near-black borders fall back to a lighter grey.")
    elseif active == "GW2" then
      note:SetText("Using GW2 UI's gold and font when the addon exposes them.")
    elseif active == "REALUI" then
      note:SetText("Using RealUI / Aurora colours when Aurora is loaded. Near-black borders fall back to a lighter grey.")
    else
      note:SetText("Using this theme's live colours.")
    end
  elseif active == "ELVUI" then
    note:SetText("ElvUI is not loaded, so this is the standalone ElvUI-style palette.")
  elseif active == "GW2" then
    note:SetText("GW2 UI is not loaded, so this is the standalone GW2-style palette.")
  elseif active == "REALUI" then
    note:SetText("RealUI is not loaded, so this is the standalone RealUI-style palette.")
  elseif active == "BLIZZARD" and self.chrome then
    note:SetText("Blizzard's own panel art and font colours, the frame style Dragonflight introduced.")
  elseif active == "BLIZZARD" then
    note:SetText("This client offered no panel art, so Blizzard's colours are drawn on a flat frame.")
  else
    note:SetText("Auto follows GW2 UI, RealUI, ElvUI, or EllesmereUI when one of those is loaded.")
  end
  y = y - 34

  local miniHeading = text(body, width, 13)
  miniHeading:SetPoint("TOPLEFT", 0, y)
  miniHeading:SetTextColor(unpack(self.colors.accent))
  miniHeading:SetText("Minimap button")
  y = y - 26
  local locked = self.MinimapButtonLocked and self:MinimapButtonLocked()
  local lockBtn = button(body, (locked and "ON  •  " or "OFF  •  ") .. "Lock to the minimap", width, 32)
  lockBtn:SetPoint("TOPLEFT", 0, y)
  if locked then
    highlight(lockBtn)
  else
    lockBtn.text:SetTextColor(0.62, 0.65, 0.7, 1)
  end
  lockBtn:SetScript("OnMouseUp", function()
    if self.SetMinimapButtonLock then self:SetMinimapButtonLock(not locked) end
    self:ShowPage("SETTINGS")
  end)
  y = y - 40
  local miniNote = text(body, width, 10)
  miniNote:SetPoint("TOPLEFT", 0, y)
  miniNote:SetText(locked
    and "Drag slides the button around the minimap edge."
    or "The button can be placed anywhere. Turn lock on to snap it back to the minimap.")
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
  y = y - 64

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

local function infoDrop(fs, gap)
  local h = 14
  if fs and fs.GetStringHeight then
    h = math.max(h, tonumber(fs:GetStringHeight()) or 0)
  end
  if fs and fs.SetHeight then fs:SetHeight(h) end
  return h + (gap or 4)
end

function LS:CopySupportLink(url, what)
  if type(url) ~= "string" or url == "" then return end
  if not CopyToClipboard then
    print("|cff59d8c9Lodestar|r " .. url)
    return
  end
  -- Protected: must run from the click, not through pcall.
  CopyToClipboard(url)
  print("|cff59d8c9Lodestar|r copied the " .. (what or "link") .. ". Paste it in a browser.")
end

function LS:FAQPage()
  self:Heading("FAQ", "Why something is missing, and what Lodestar is not.")
  local body = self:Body(70)
  local width = body.width
  local inner = width - 24
  local y = 0
  for _, item in ipairs(self.FAQ or {}) do
    local card = panel(body)
    card:SetPoint("TOPLEFT", 0, y)
    card:SetWidth(width)
    paint(card)
    local q = text(card, inner, 13)
    q:SetPoint("TOPLEFT", 12, -10)
    q:SetTextColor(unpack(self.colors.accent))
    if q.SetWordWrap then q:SetWordWrap(true) end
    q:SetText(item.q)
    local qh = infoDrop(q, 0)
    local a = text(card, inner, 11)
    a:SetPoint("TOPLEFT", 12, -(16 + qh))
    if a.SetWordWrap then a:SetWordWrap(true) end
    a:SetText(item.a)
    local ah = infoDrop(a, 0)
    local height = 16 + qh + 8 + ah + 12
    card:SetSize(width, height)
    y = y - (height + 8)
  end
  body:finish(math.max(40, -y + 10))
end

function LS:HelpPage()
  self:Heading("Help", "How to use Lodestar, and where to get support.")
  local body = self:Body(70)
  local width = body.width
  local inner = width - 24
  local y = 0
  for _, item in ipairs(self.HELP or {}) do
    local card = panel(body)
    card:SetPoint("TOPLEFT", 0, y)
    card:SetWidth(width)
    paint(card)
    local heading = text(card, inner, 13)
    heading:SetPoint("TOPLEFT", 12, -10)
    heading:SetTextColor(unpack(self.colors.accent))
    heading:SetText(item.title)
    local hh = infoDrop(heading, 0)
    local line = text(card, inner, 11)
    line:SetPoint("TOPLEFT", 12, -(16 + hh))
    if line.SetWordWrap then line:SetWordWrap(true) end
    line:SetText(item.body)
    local bh = infoDrop(line, 0)
    local height = 16 + hh + 8 + bh + 12
    card:SetSize(width, height)
    y = y - (height + 8)
  end

  local support = text(body, width, 13)
  support:SetPoint("TOPLEFT", 0, y)
  support:SetTextColor(unpack(self.colors.accent))
  support:SetText("Support")
  y = y - infoDrop(support, 10)

  for _, row in ipairs(self.SUPPORT or {}) do
    local link = row
    local card = panel(body)
    card:SetSize(width, 72)
    card:SetPoint("TOPLEFT", 0, y)
    paint(card)
    card:EnableMouse(true)
    card:SetScript("OnEnter", function(selfFrame)
      if LS.colors then selfFrame:SetBackdropBorderColor(unpack(LS.colors.accent)) end
      Tip(selfFrame, link.url)
    end)
    card:SetScript("OnLeave", function(selfFrame)
      if LS.colors then selfFrame:SetBackdropBorderColor(unpack(LS.colors.border)) end
      HideTip()
    end)
    card:SetScript("OnMouseUp", function()
      self:CopySupportLink(link.url, link.copied or link.name)
    end)

    local art = card:CreateTexture(nil, "ARTWORK")
    if link.cover then
      art:SetSize(36, 36)
      art:SetPoint("LEFT", 12, 0)
      PaintNavIcon(art, link.icon)
    else
      local badge = card:CreateTexture(nil, "ARTWORK")
      badge:SetSize(36, 36)
      badge:SetPoint("LEFT", 12, 0)
      if badge.SetColorTexture then
        local c = link.color or self.colors.accent
        badge:SetColorTexture(c[1], c[2], c[3], 1)
      end
      art:SetSize(22, 22)
      art:SetPoint("CENTER", badge, "CENTER", 0, 0)
      PaintNavIcon(art, link.icon)
      if art.SetVertexColor then art:SetVertexColor(1, 1, 1, 1) end
    end

    local title = text(card, width - 210, 13)
    title:SetPoint("TOPLEFT", 58, -12)
    title:SetTextColor(unpack(self.colors.accent))
    title:SetText(link.name)
    local why = text(card, width - 210, 11)
    why:SetPoint("TOPLEFT", 58, -30)
    why:SetText(link.why)
    local url = text(card, width - 210, 10)
    url:SetPoint("TOPLEFT", 58, -48)
    url:SetTextColor(unpack(self.colors.muted))
    url:SetText(link.url)

    local copy = button(card, link.action, 150, 26, 11)
    copy:SetPoint("TOPRIGHT", -10, -12)
    paint(copy, "panel")
    highlight(copy)
    copy:SetScript("OnMouseUp", function()
      self:CopySupportLink(link.url, link.copied or link.name)
    end)
    y = y - 80
  end
  body:finish(math.max(40, -y + 10))
end

function LS:Refresh()
  if self.frame and self.frame:IsShown() then
    self:ShowPage(self.page or "TODAY")
  end
  if self.UpdateCompact then self:UpdateCompact() end
end

function LS:LandingPage()
  if not self.db.welcomed then return "WELCOME" end
  if self.HasUnseenTips and self:HasUnseenTips() then
    self.tutorialReturn = self.tutorialReturn or "DASHBOARD"
    return "TUTORIAL"
  end
  return self.page or "DASHBOARD"
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
