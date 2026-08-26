local _, LS = ...

-- Dashboard is a layout of widgets the player picks, not a second copy of Today.
-- Other addons inject tiles with Lodestar:RegisterWidget after they load.

local HEADER = 26
local MAX_HISTORY = 32
local CANVAS_COLS = 12
local CANVAS_ROWS = 18
local MAX_ROWS = 36
local MIN_W, MIN_H = 3, 2
local CELL_H = 48

LS.DASHBOARD_COLS = CANVAS_COLS
LS.DASHBOARD_ROWS = CANVAS_ROWS
LS.DASHBOARD_MAX_ROWS = MAX_ROWS

function LS:DefaultDashboardWidgets()
  -- Half-canvas tiles, same starting size as Token / Vault / the rest.
  return {
    { id = "stats", x = 0, y = 0, w = 6, h = 4 },
    { id = "shortcuts", x = 6, y = 0, w = 6, h = 4 },
    { id = "professions", x = 0, y = 4, w = 6, h = 4 },
    { id = "next", x = 6, y = 4, w = 6, h = 4 },
  }
end

local function SpecSpan(spec)
  spec = spec or {}
  local w = spec.defaultW or ((spec.defaultSize == "half") and 6 or 12)
  local h = spec.defaultH or 4
  return w, h
end

function LS:ClampDashboardRect(entry)
  if not entry then return end
  local rows = self.DashboardRows and self:DashboardRows() or CANVAS_ROWS
  entry.w = math.max(MIN_W, math.min(CANVAS_COLS, math.floor(tonumber(entry.w) or MIN_W)))
  entry.h = math.max(MIN_H, math.min(rows, math.floor(tonumber(entry.h) or MIN_H)))
  entry.x = math.max(0, math.min(CANVAS_COLS - entry.w, math.floor(tonumber(entry.x) or 0)))
  entry.y = math.max(0, math.min(rows - entry.h, math.floor(tonumber(entry.y) or 0)))
end

local function RectsOverlap(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function WidgetList(self)
  return self.db and self.db.dashboard and self.db.dashboard.widgets
end

function LS:DashboardUsedRows()
  local used = 0
  for _, entry in ipairs(WidgetList(self) or {}) do
    local y = tonumber(entry.y) or 0
    if y < MAX_ROWS then
      used = math.max(used, y + (tonumber(entry.h) or 0))
    end
  end
  return used
end

function LS:DashboardRows()
  local saved = self.db and self.db.dashboard and tonumber(self.db.dashboard.rows)
  return math.max(CANVAS_ROWS, math.min(MAX_ROWS, math.floor(saved or CANVAS_ROWS)))
end

function LS:GrowDashboardRows(needed)
  needed = math.floor(tonumber(needed) or CANVAS_ROWS)
  local rows = math.max(self:DashboardRows(), math.min(MAX_ROWS, needed))
  self.db = self.db or {}
  self.db.dashboard = self.db.dashboard or {}
  self.db.dashboard.rows = rows
  return rows
end

function LS:LargestDashboardHole(ignoreId)
  local best
  for _, hole in ipairs(self:DashboardEmptyRects(ignoreId, MIN_W, MIN_H)) do
    local area = (hole.w or 0) * (hole.h or 0)
    if not best or area > best.area then
      best = { x = hole.x, y = hole.y, w = hole.w, h = hole.h, area = area }
    end
  end
  return best
end

function LS:DashboardCollision(id, x, y, w, h)
  local layout = WidgetList(self)
  if type(layout) ~= "table" then return end
  local probe = { x = x, y = y, w = w, h = h }
  for _, entry in ipairs(layout) do
    if entry.id ~= id and RectsOverlap(probe, entry) then return entry.id end
  end
end

function LS:FindDashboardSlot(w, h, preferX, preferY, ignoreId)
  local rows = self:DashboardRows()
  w = math.max(MIN_W, math.min(CANVAS_COLS, math.floor(tonumber(w) or MIN_W)))
  h = math.max(MIN_H, math.min(rows, math.floor(tonumber(h) or MIN_H)))
  preferX = math.floor(tonumber(preferX) or 0)
  preferY = math.floor(tonumber(preferY) or 0)
  local bestX, bestY, bestDist
  for y = 0, rows - h do
    for x = 0, CANVAS_COLS - w do
      if not self:DashboardCollision(ignoreId, x, y, w, h) then
        local dx, dy = x - preferX, y - preferY
        local dist = dx * dx + dy * dy
        if not bestDist or dist < bestDist then
          bestX, bestY, bestDist = x, y, dist
          if dist == 0 then return x, y end
        end
      end
    end
  end
  return bestX, bestY
end

-- Empty canvas holes, merged into rectangles. Used while dragging so drop
-- targets are rooms, not every origin cell that would fit.
function LS:DashboardEmptyRects(ignoreId, minW, minH)
  minW = math.max(1, math.floor(tonumber(minW) or 1))
  minH = math.max(1, math.floor(tonumber(minH) or 1))
  local rows = self:DashboardRows()
  local occ = {}
  for y = 0, rows - 1 do occ[y] = {} end
  for _, entry in ipairs(WidgetList(self) or {}) do
    if entry.id ~= ignoreId then
      local x1, y1 = entry.x or 0, entry.y or 0
      local x2, y2 = x1 + (entry.w or 0) - 1, y1 + (entry.h or 0) - 1
      for yy = y1, y2 do
        if occ[yy] then
          for xx = x1, x2 do occ[yy][xx] = true end
        end
      end
    end
  end
  local closed, active = {}, {}
  for y = 0, rows - 1 do
    local runs, x = {}, 0
    while x < CANVAS_COLS do
      if occ[y][x] then
        x = x + 1
      else
        local x1 = x
        while x < CANVAS_COLS and not occ[y][x] do x = x + 1 end
        table.insert(runs, { x = x1, w = x - x1 })
      end
    end
    local nextActive, used = {}, {}
    for _, run in ipairs(runs) do
      local matched
      for i, rec in ipairs(active) do
        if not used[i] and rec.x == run.x and rec.w == run.w then
          rec.h = rec.h + 1
          used[i] = true
          matched = rec
          break
        end
      end
      if not matched then
        matched = { x = run.x, y = y, w = run.w, h = 1 }
      end
      table.insert(nextActive, matched)
    end
    for i, rec in ipairs(active) do
      if not used[i] then table.insert(closed, rec) end
    end
    active = nextActive
  end
  for _, rec in ipairs(active) do table.insert(closed, rec) end
  local out = {}
  for _, rec in ipairs(closed) do
    if rec.w >= minW and rec.h >= minH then table.insert(out, rec) end
  end
  return out
end

function LS:ResolveDashboardOverlaps()
  local layout = WidgetList(self)
  if type(layout) ~= "table" then return end
  for _, entry in ipairs(layout) do
    self:ClampDashboardRect(entry)
    if self:DashboardCollision(entry.id, entry.x, entry.y, entry.w, entry.h) then
      local x, y = self:FindDashboardSlot(entry.w, entry.h, entry.x, entry.y, entry.id)
      if x then
        entry.x, entry.y = x, y
      end
    end
  end
end

function LS:DashboardCompactUp()
  local layout = self:DashboardLayout()
  local order = {}
  for _, entry in ipairs(layout) do
    table.insert(order, entry)
  end
  table.sort(order, function(a, b)
    if (a.y or 0) == (b.y or 0) then return (a.x or 0) < (b.x or 0) end
    return (a.y or 0) < (b.y or 0)
  end)
  local parked = {}
  for _, entry in ipairs(order) do
    parked[entry.id] = { x = entry.x, y = entry.y, w = entry.w, h = entry.h }
    entry.y = MAX_ROWS
  end
  local rows = self:DashboardRows()
  for _, entry in ipairs(order) do
    local x = parked[entry.id].x
    local w, h = entry.w, entry.h
    local y = 0
    while y + h <= rows and self:DashboardCollision(entry.id, x, y, w, h) do
      y = y + 1
    end
    if y + h > rows then
      local nx, ny = self:FindDashboardSlot(w, h, x, 0, entry.id)
      if nx then
        x, y = nx, ny
      else
        x, y = parked[entry.id].x, parked[entry.id].y
      end
    end
    entry.x, entry.y = x, y
    self:ClampDashboardRect(entry)
  end
end

function LS:NormalizeDashboardLayout()
  local layout = self.db and self.db.dashboard and self.db.dashboard.widgets
  if type(layout) ~= "table" then return end
  local x, y, rowH = 0, 0, 0
  for _, entry in ipairs(layout) do
    if not entry.w or not entry.h then
      local spec = self:WidgetSpec(entry.id)
      local w, h = SpecSpan(spec)
      if entry.size == "half" then w = 6 end
      if entry.size == "wide" then w = 12 end
      if w >= CANVAS_COLS then
        if x > 0 then y = y + rowH; x, rowH = 0, 0 end
        entry.x, entry.y, entry.w, entry.h = 0, y, CANVAS_COLS, h
        y = y + h
      elseif x + w > CANVAS_COLS then
        y = y + rowH
        entry.x, entry.y, entry.w, entry.h = 0, y, w, h
        x, rowH = w, h
      else
        entry.x, entry.y, entry.w, entry.h = x, y, w, h
        x = x + w
        if h > rowH then rowH = h end
      end
      entry.size = nil
    end
    self:ClampDashboardRect(entry)
  end
  self:ResolveDashboardOverlaps()
end

local function RectIs(entry, id, x, y, w, h)
  return entry and entry.id == id
    and entry.x == x and entry.y == y and entry.w == w and entry.h == h
end

-- Unreleased stock layout was four full-width banners. Replace that one
-- arrangement so testers see the half-size defaults without Reset widgets.
function LS:MigrateStockDashboard()
  local layout = WidgetList(self)
  if type(layout) ~= "table" or #layout ~= 4 then return end
  local byId = {}
  for _, entry in ipairs(layout) do byId[entry.id] = entry end
  if not (RectIs(byId.stats, "stats", 0, 0, 12, 4)
      and RectIs(byId.shortcuts, "shortcuts", 0, 4, 12, 2)
      and RectIs(byId.professions, "professions", 0, 6, 12, 3)
      and RectIs(byId.next, "next", 0, 9, 12, 5)) then
    return
  end
  self.db.dashboard.widgets = self:DefaultDashboardWidgets()
end

function LS:DashboardLayout()
  self.db.dashboard = self.db.dashboard or {}
  local widgets = self.db.dashboard.widgets
  if type(widgets) ~= "table" or widgets[1] == nil then
    self.db.dashboard.widgets = self:DefaultDashboardWidgets()
  end
  self:MigrateStockDashboard()
  self:NormalizeDashboardLayout()
  return self.db.dashboard.widgets
end

function LS:DashboardCellSize(width)
  width = width or self:ContentWidth()
  return math.max(24, math.floor(width / CANVAS_COLS)), CELL_H
end

function LS:DashboardCanvasSize(width)
  local cellW, cellH = self:DashboardCellSize(width)
  local rows = self:DashboardRows()
  return cellW * CANVAS_COLS, cellH * rows, cellW, cellH
end

function LS:RegisterWidget(spec)
  if type(spec) ~= "table" or not spec.id or not spec.title or type(spec.render) ~= "function" then
    return
  end
  self.widgetCatalog = self.widgetCatalog or {}
  for i, existing in ipairs(self.widgetCatalog) do
    if existing.id == spec.id then
      self.widgetCatalog[i] = spec
      return
    end
  end
  table.insert(self.widgetCatalog, spec)
end

function LS:WidgetTitle(spec)
  if type(spec) ~= "table" then return "" end
  if type(spec.title) == "function" then
    local ok, title = pcall(spec.title, self)
    if ok and type(title) == "string" and title ~= "" then return title end
    return spec.id or ""
  end
  return spec.title
end

function LS:QualityColor(quality)
  quality = tonumber(quality)
  if quality == nil then return end
  if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
    local c = ITEM_QUALITY_COLORS[quality]
    if c.GetRGB then return c:GetRGB() end
    if c.r then return c.r, c.g, c.b end
  end
  if GetItemQualityColor then
    local ok, r, g, b = pcall(GetItemQualityColor, quality)
    if ok and r then return r, g, b end
  end
end

function LS:PaintWidgetTip(owner, fill)
  if not GameTooltip or not owner or not fill then return end
  if GameTooltip.SetOwner then pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_RIGHT") end
  fill(GameTooltip, owner)
  if GameTooltip.Show then pcall(GameTooltip.Show, GameTooltip) end
end

function LS:HideWidgetTip()
  self._tipOwner = nil
  self._tipFill = nil
  if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end
end

function LS:RefreshWidgetTooltip()
  if self._tipOwner and self._tipFill then
    self:PaintWidgetTip(self._tipOwner, self._tipFill)
  end
end

function LS:HoverTip(frame, fill)
  if not frame or not fill then return end
  frame:EnableMouse(true)
  local prevEnter = frame.GetScript and frame:GetScript("OnEnter")
  local prevLeave = frame.GetScript and frame:GetScript("OnLeave")
  frame:SetScript("OnEnter", function(owner, ...)
    if prevEnter then prevEnter(owner, ...) end
    LS._tipOwner = owner
    LS._tipFill = fill
    LS:PaintWidgetTip(owner, fill)
  end)
  frame:SetScript("OnLeave", function(owner, ...)
    if prevLeave then prevLeave(owner, ...) end
    if LS._tipOwner == owner then LS:HideWidgetTip() end
  end)
end

function LS:FillPlayerTooltip(tip)
  if not tip then return end
  if RaiderIO and RaiderIO.ShowProfile then
    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()
    local ok = pcall(RaiderIO.ShowProfile, tip, name, realm)
    if not ok then ok = pcall(RaiderIO.ShowProfile, tip, "player") end
    if ok then return end
  end
  if tip.SetUnit then
    local ok = pcall(tip.SetUnit, tip, "player")
    if ok then return end
  end
  if tip.ClearLines then pcall(tip.ClearLines, tip) end
  local name = UnitName and UnitName("player") or "Player"
  if tip.SetText then tip:SetText(name) end
end

function LS:FillCurrencyTooltip(tip, id)
  if not tip or not id then return end
  if tip.SetCurrencyByID then
    local ok = pcall(tip.SetCurrencyByID, tip, id)
    if ok then return end
  end
  if tip.SetHyperlink then
    local ok = pcall(tip.SetHyperlink, tip, "currency:" .. tostring(id))
    if ok then return end
  end
  if tip.ClearLines then pcall(tip.ClearLines, tip) end
  if tip.SetText then tip:SetText("Currency " .. tostring(id)) end
end

function LS:WidgetSpec(id)
  for _, spec in ipairs(self.widgetCatalog or {}) do
    if spec.id == id then return spec end
  end
end

function LS:WidgetAvailable(spec)
  if not spec then return false end
  if spec.available then
    local ok, on = pcall(spec.available, self)
    return ok and on
  end
  return true
end

function LS:DashboardHas(id)
  for _, entry in ipairs(self:DashboardLayout()) do
    if entry.id == id then return true end
  end
end

function LS:DashboardAdd(id)
  local spec = self:WidgetSpec(id)
  if not spec or self:DashboardHas(id) or not self:WidgetAvailable(spec) then return end
  local wantW, wantH = SpecSpan(spec)
  local w, h = wantW, wantH
  local preferY = self:DashboardUsedRows()
  local x, y = self:FindDashboardSlot(w, h, 0, preferY, id)
  local fitted
  if not x then
    local rows = self:DashboardRows()
    local growTo = math.min(MAX_ROWS, math.max(rows, preferY + h))
    if growTo > rows then
      self:GrowDashboardRows(growTo)
      x, y = self:FindDashboardSlot(w, h, 0, preferY, id)
    end
  end
  if not x then
    local hole = self:LargestDashboardHole(id)
    if hole then
      w = math.max(MIN_W, math.min(wantW, hole.w))
      h = math.max(MIN_H, math.min(wantH, hole.h))
      x, y = self:FindDashboardSlot(w, h, hole.x, hole.y, id)
      if x and (w ~= wantW or h ~= wantH) then fitted = true end
    end
  end
  if not x then
    print("|cff59d8c9Lodestar|r The dashboard canvas is full. Remove a widget or Compact up.")
    return
  end
  local placed = { id = id, x = x, y = y, w = w, h = h }
  self:ClampDashboardRect(placed)
  table.insert(self:DashboardLayout(), placed)
  if fitted then
    print("|cff59d8c9Lodestar|r Added " .. self:WidgetTitle(spec)
      .. " at " .. placed.w .. " × " .. placed.h .. ", the room left on the canvas.")
  end
end

function LS:DashboardRemove(id)
  local layout = self:DashboardLayout()
  for i, entry in ipairs(layout) do
    if entry.id == id then
      table.remove(layout, i)
      return
    end
  end
end

function LS:DashboardMove(id, index)
  local layout = self:DashboardLayout()
  local from
  for i, entry in ipairs(layout) do
    if entry.id == id then from = i break end
  end
  if not from then return end
  local entry = table.remove(layout, from)
  index = math.max(1, math.min(#layout + 1, tonumber(index) or 1))
  table.insert(layout, index, entry)
end

function LS:DashboardPlace(id, x, y, w, h)
  for _, entry in ipairs(self:DashboardLayout()) do
    if entry.id == id then
      local prev = { x = entry.x, y = entry.y, w = entry.w, h = entry.h }
      if x ~= nil then entry.x = x end
      if y ~= nil then entry.y = y end
      if w ~= nil then entry.w = w end
      if h ~= nil then entry.h = h end
      self:ClampDashboardRect(entry)
      if self:DashboardCollision(entry.id, entry.x, entry.y, entry.w, entry.h) then
        local nx, ny = self:FindDashboardSlot(entry.w, entry.h, entry.x, entry.y, entry.id)
        if nx then
          entry.x, entry.y = nx, ny
        else
          entry.x, entry.y, entry.w, entry.h = prev.x, prev.y, prev.w, prev.h
        end
      end
      return entry
    end
  end
end

function LS:CommitWidgetFrame(id, chrome)
  local canvas = self.dashboardCanvas
  if not chrome or not canvas then return end
  local left = chrome.GetLeft and chrome:GetLeft()
  local top = chrome.GetTop and chrome:GetTop()
  local canvasLeft = canvas.GetLeft and canvas:GetLeft()
  local canvasTop = canvas.GetTop and canvas:GetTop()
  local cellW, cellH = self:DashboardCellSize(canvas:GetWidth())
  if type(left) == "number" and type(top) == "number"
      and type(canvasLeft) == "number" and type(canvasTop) == "number"
      and cellW > 0 and cellH > 0 then
    local x = math.floor(((left - canvasLeft) / cellW) + 0.5)
    local y = math.floor(((canvasTop - top) / cellH) + 0.5)
    local ww = math.floor((chrome:GetWidth() / cellW) + 0.5)
    local hh = math.floor((chrome:GetHeight() / cellH) + 0.5)
    self:DashboardPlace(id, x, y, ww, hh)
  end
end

function LS:WidgetOpts(id)
  for _, entry in ipairs(self:DashboardLayout()) do
    if entry.id == id then
      entry.opts = entry.opts or {}
      return entry.opts
    end
  end
  return {}
end

function LS:SetWidgetOpt(id, key, value)
  self:WidgetOpts(id)[key] = value
end

function LS:WidgetOptOn(id, key, default)
  local v = self:WidgetOpts(id)[key]
  if v == nil then
    if default == nil then return true end
    return default and true or false
  end
  return v and true or false
end

function LS:PaintEditIdle(parent, width, copy)
  local line = self.widgets.text(parent, width - 24, 11)
  line:SetPoint("TOPLEFT", 12, -8)
  if self.colors then line:SetTextColor(unpack(self.colors.muted)) end
  line:SetText(copy or "Nothing extra to set on this tile.")
  return 36
end

function LS:PaintWidgetSettings(parent, width, id, note, rows)
  local w = self.widgets
  local y = -8
  if note then
    local line = w.text(parent, width - 24, 10)
    line:SetPoint("TOPLEFT", 12, y)
    if self.colors then line:SetTextColor(unpack(self.colors.muted)) end
    line:SetText(note)
    y = y - 18
  end
  local btnW = 88
  local col = 0
  for _, row in ipairs(rows or {}) do
    local key, label, default = row[1], row[2], row[3]
    local on = self:WidgetOptOn(id, key, default)
    local btn = w.button(parent, label, btnW, 20, 10)
    btn:SetPoint("TOPLEFT", 12 + col * (btnW + 4), y)
    if on then w.highlight(btn) else w.paint(btn, "panel") end
    local widgetID, optKey, optDefault = id, key, default
    btn:SetScript("OnMouseUp", function()
      LS:SetWidgetOpt(widgetID, optKey, not LS:WidgetOptOn(widgetID, optKey, optDefault))
      LS:ShowPage("DASHBOARD")
    end)
    col = col + 1
    if col >= 2 then
      col = 0
      y = y - 24
    end
  end
  if col > 0 then y = y - 24 end
  return math.max(40, -y + 8)
end

function LS:PaintMoneyFormatSettings(parent, width, id, defaultChart, defaultSep)
  local w = self.widgets
  local opts = self:WidgetOpts(id)
  local format = opts.format or "letters"
  local colorOn = opts.color ~= false
  local sepOn = opts.separators
  if sepOn == nil then sepOn = defaultSep and true or false end
  sepOn = sepOn and true or false
  local chart = opts.chart or (defaultChart == "line" and "line" or "bars")
  if chart ~= "line" then chart = "bars" end
  local y = -8
  local note = w.text(parent, width - 24, 10)
  note:SetPoint("TOPLEFT", 12, y)
  if self.colors then note:SetTextColor(unpack(self.colors.muted)) end
  note:SetText("How this tile writes gold.")
  y = y - 22
  local function toggle(label, on, x, click)
    local btn = w.button(parent, label, 78, 20, 10)
    btn:SetPoint("TOPLEFT", x, y)
    if on then w.highlight(btn) else w.paint(btn, "panel") end
    btn:SetScript("OnMouseUp", click)
    return btn
  end
  toggle("Coin icons", format == "coins", 12, function()
    self:SetWidgetOpt(id, "format", "coins")
    self:ShowPage("DASHBOARD")
  end)
  toggle("Letters", format == "letters", 94, function()
    self:SetWidgetOpt(id, "format", "letters")
    self:ShowPage("DASHBOARD")
  end)
  y = y - 24
  toggle("Color", colorOn, 12, function()
    self:SetWidgetOpt(id, "color", not colorOn)
    self:ShowPage("DASHBOARD")
  end)
  toggle("Separators", sepOn, 94, function()
    self:SetWidgetOpt(id, "separators", not sepOn)
    self:ShowPage("DASHBOARD")
  end)
  y = y - 24
  toggle("Bars", chart ~= "line", 12, function()
    self:SetWidgetOpt(id, "chart", "bars")
    self:ShowPage("DASHBOARD")
  end)
  toggle("Line", chart == "line", 94, function()
    self:SetWidgetOpt(id, "chart", "line")
    self:ShowPage("DASHBOARD")
  end)
  y = y - 24
  return (-y) + 8
end

local LETTER_GOLD = { 1, 0.82, 0 }
local LETTER_SILVER = { 0.78, 0.78, 0.81 }
local LETTER_COPPER = { 0.85, 0.55, 0.33 }

local function GroupDigits(n)
  n = math.floor(math.abs(tonumber(n) or 0))
  if BreakUpLargeNumbers then
    local ok, text = pcall(BreakUpLargeNumbers, n)
    if ok and type(text) == "string" and text ~= "" then return text end
  end
  local s = tostring(n)
  return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function CoinHex(c)
  return string.format("%02x%02x%02x",
    math.floor(((c and c[1]) or 1) * 255 + 0.5),
    math.floor(((c and c[2]) or 1) * 255 + 0.5),
    math.floor(((c and c[3]) or 1) * 255 + 0.5))
end

-- Token display: coin icons, or letters (g/s/c), with optional colour and thousands
-- separators. Farm cards still use FormatGold so their copy stays plain.
function LS:FormatTokenMoney(copper, opts)
  opts = opts or {}
  copper = math.floor(tonumber(copper) or 0)
  local sign = copper < 0 and "-" or ""
  copper = math.abs(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local copperCoins = copper % 100
  local format = opts.format or "letters"
  local sep = opts.separators and true or false
  local color = opts.color ~= false

  if format == "coins" then
    local str
    if sep and GetMoneyString then
      local ok, value = pcall(GetMoneyString, copper, true)
      if ok and type(value) == "string" then str = value end
    end
    if not str and GetCoinTextureString then
      local ok, value = pcall(GetCoinTextureString, copper, 14)
      if ok and type(value) == "string" then str = value end
    end
    if str then
      if sep and not str:find(",", 1, true) then
        str = str:gsub("^(%-?%d+)", function(num)
          return GroupDigits(tonumber(num) or 0)
        end)
      end
      return sign .. str, 1, 1, 1
    end
  end

  local function amount(n)
    return sep and GroupDigits(n) or tostring(n)
  end
  local goldText = amount(gold) .. "g"
  local silverText = amount(silver) .. "s"
  local copperText = amount(copperCoins) .. "c"
  if color then
    local text = string.format("|cff%s%s|r |cff%s%s|r |cff%s%s|r",
      CoinHex(LETTER_GOLD), goldText,
      CoinHex(LETTER_SILVER), silverText,
      CoinHex(LETTER_COPPER), copperText)
    return sign .. text, 1, 1, 1
  end
  local text = goldText .. " " .. silverText .. " " .. copperText
  local tone = self.colors and self.colors.text or { 1, 1, 1, 1 }
  return sign .. text, tone[1], tone[2], tone[3]
end

function LS:BeginWidgetDrag(chrome, id)
  if not chrome then return end
  self:EndWidgetDrag()
  self.dashboardDrag = id
  self.dashboardDragFrame = chrome

  local point, rel, relPoint, x, y = chrome:GetPoint(1)
  local parent = (chrome.GetParent and chrome:GetParent()) or chrome.parent
  local ghost = self.dashboardDragGhost
  if not ghost then
    ghost = self.widgets.panel(self.frame)
    ghost:SetFrameStrata((self.frame and self.frame:GetFrameStrata()) or "HIGH")
    self.dashboardDragGhost = ghost
  end
  ghost:SetParent(parent or self.content)
  ghost:ClearAllPoints()
  ghost:SetPoint(point or "TOPLEFT", rel or parent, relPoint or "TOPLEFT", x or 0, y or 0)
  ghost:SetSize(chrome:GetWidth(), chrome:GetHeight())
  ghost:SetFrameLevel(math.max(1, (chrome:GetFrameLevel() or 2) - 1))
  self.widgets.paint(ghost, "panel")
  if self.colors then
    local bg = self.colors.panel or self.colors.card
    ghost:SetBackdropColor(bg[1], bg[2], bg[3], 0.45)
    ghost:SetBackdropBorderColor(unpack(self.colors.accent))
  end
  if not ghost.hint then
    ghost.hint = self.widgets.text(ghost, 120, 10)
    ghost.hint:SetPoint("CENTER")
    ghost.hint:SetJustifyH("CENTER")
  end
  ghost.hint:SetWidth(math.max(80, chrome:GetWidth() - 16))
  ghost.hint:SetText("Drop here")
  if self.colors then ghost.hint:SetTextColor(unpack(self.colors.accent)) end
  ghost:Show()

  chrome:SetFrameStrata("TOOLTIP")
  chrome:SetFrameLevel(200)
  if chrome.SetScale then chrome:SetScale(1.05) end
  if chrome.SetAlpha then chrome:SetAlpha(0.92) end
  if self.colors then chrome:SetBackdropBorderColor(unpack(self.colors.accent)) end
  chrome:StartMoving()

  local origin
  for _, entry in ipairs(self:DashboardLayout()) do
    if entry.id == id then
      origin = { x = entry.x, y = entry.y, w = entry.w, h = entry.h }
      break
    end
  end
  if origin then
    self:ShowWidgetDropHints(id, origin.w, origin.h, origin)
  end
end

function LS:HideWidgetDropHints()
  for _, hint in ipairs(self.dashboardDropHints or {}) do
    hint:Hide()
  end
end

function LS:ShowWidgetDropHints(id, w, h, origin)
  self:HideWidgetDropHints()
  local canvas = self.dashboardCanvas
  if not canvas or not w or not h then return end
  local cellW, cellH = self:DashboardCellSize(canvas:GetWidth())
  local rects = self:DashboardEmptyRects(id, w, h)
  self.dashboardDropHints = self.dashboardDropHints or {}
  local n = 0
  for _, rect in ipairs(rects) do
    if origin and rect.x == origin.x and rect.y == origin.y
        and rect.w == origin.w and rect.h == origin.h then
      -- The origin ghost already marks that cell.
    else
      n = n + 1
      local hint = self.dashboardDropHints[n]
      if not hint then
        hint = self.widgets.panel(canvas)
        hint.plus = self.widgets.text(hint, 48, 28)
        hint.plus:SetPoint("CENTER")
        hint.plus:SetJustifyH("CENTER")
        if hint.plus.SetJustifyV then hint.plus:SetJustifyV("MIDDLE") end
        self.dashboardDropHints[n] = hint
      end
      hint:SetParent(canvas)
      hint:ClearAllPoints()
      hint:SetPoint("TOPLEFT", rect.x * cellW, -(rect.y * cellH))
      hint:SetSize(rect.w * cellW, rect.h * cellH)
      hint:SetFrameLevel(math.max(3, (canvas:GetFrameLevel() or 1) + 4))
      self.widgets.paint(hint, "panel")
      if self.colors then
        local bg = self.colors.bg or self.colors.panel
        hint:SetBackdropColor(bg[1], bg[2], bg[3], 0.22)
        hint:SetBackdropBorderColor(unpack(self.colors.accent))
        hint.plus:SetTextColor(unpack(self.colors.accent))
      end
      hint.plus:SetWidth(math.max(24, rect.w * cellW - 12))
      hint.plus:SetText("+")
      hint:Show()
    end
  end
end

function LS:EndWidgetDrag(chrome)
  chrome = chrome or self.dashboardDragFrame
  if chrome then
    chrome:SetScript("OnUpdate", nil)
    chrome:StopMovingOrSizing()
    if chrome.SetScale then chrome:SetScale(1) end
    if chrome.SetAlpha then chrome:SetAlpha(1) end
    chrome:SetFrameStrata((self.frame and self.frame:GetFrameStrata()) or "DIALOG")
    if self.colors then chrome:SetBackdropBorderColor(unpack(self.colors.border)) end
  end
  if self.dashboardDragGhost then self.dashboardDragGhost:Hide() end
  self:HideWidgetDropHints()
  for _, slot in ipairs(self.dashboardSlots or {}) do
    if slot.frame and self.colors then
      slot.frame:SetBackdropBorderColor(unpack(self.colors.border))
    end
  end
  self.dashboardDrag = nil
  self.dashboardDragFrame = nil
end

function LS:HighlightWidgetDropTarget()
  -- Free placement: the ghost marks the original cell. Drop commits the pixel rect.
end

function LS:ResetDashboardLayout()
  self.db.dashboard = { widgets = self:DefaultDashboardWidgets() }
end

function LS:SetDashboardEdit(on)
  self.dashboardEdit = on and true or false
  if self.page == "DASHBOARD" then self:ShowPage("DASHBOARD") end
end

-- Token price is whatever the client last published. History is samples we saw,
-- not an invented chart.
function LS:RequestTokenPrice()
  if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
    pcall(C_WowTokenPublic.UpdateMarketPrice)
  end
end

function LS:TokenPrice()
  if not (C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice) then return nil end
  local price = C_WowTokenPublic.GetCurrentMarketPrice()
  if type(price) == "number" and price > 0 then return price end
end

function LS:RecordTokenPrice()
  local price = self:TokenPrice()
  if not price or not self.db then return end
  self.db.tokenHistory = self.db.tokenHistory or {}
  local last = self.db.tokenHistory[#self.db.tokenHistory]
  if last and last.p == price then return end
  table.insert(self.db.tokenHistory, { t = time and time() or 0, p = price })
  while #self.db.tokenHistory > MAX_HISTORY do
    table.remove(self.db.tokenHistory, 1)
  end
  return true
end

local function FormatCountdown(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local d = math.floor(seconds / 86400)
  local h = math.floor((seconds % 86400) / 3600)
  local m = math.floor((seconds % 3600) / 60)
  if d > 0 then return string.format("%dd %dh", d, h) end
  if h > 0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm", m)
end

local function AddonLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

function LS:PaintSparkline(parent, history, width, y, colors, style, chartH)
  colors = colors or self.colors or {}
  if #(history or {}) < 2 then return y end
  local n = math.min(#history, 24)
  local start = #history - n + 1
  local lo, hi = history[start].p, history[start].p
  for i = start, #history do
    local p = history[i].p
    if p < lo then lo = p end
    if p > hi then hi = p end
  end
  local span = math.max(1, hi - lo)
  local up = history[#history].p >= history[start].p
  local tone = up and colors.accent or colors.warn
  chartH = math.max(16, tonumber(chartH) or 24)
  local left, bottom, chartW = 12, 8 - y, math.max(8, width - 24)
  local function SampleY(p)
    return bottom + 6 + math.floor((chartH - 6) * ((p - lo) / span))
  end
  if style == "line" then
    local prevX, prevY
    for i = 0, n - 1 do
      local px = left + math.floor(i * (chartW - 2) / math.max(1, n - 1))
      local py = SampleY(history[start + i].p)
      if prevX then
        local dx, dy = px - prevX, py - prevY
        local len = math.sqrt(dx * dx + dy * dy)
        if len >= 1 then
          local seg = parent:CreateTexture(nil, "ARTWORK")
          seg:SetSize(math.max(2, len), 2)
          seg:SetPoint("CENTER", parent, "BOTTOMLEFT", (prevX + px) / 2, (prevY + py) / 2)
          if seg.SetRotation then
            local angle = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
            seg:SetRotation(angle)
          end
          if seg.SetColorTexture then seg:SetColorTexture(unpack(tone)) end
        end
      end
      local dot = parent:CreateTexture(nil, "OVERLAY")
      dot:SetSize(4, 4)
      dot:SetPoint("CENTER", parent, "BOTTOMLEFT", px, py)
      if dot.SetColorTexture then dot:SetColorTexture(unpack(tone)) end
      prevX, prevY = px, py
    end
  else
    local barW = math.max(2, math.floor(chartW / n) - 1)
    for i = 0, n - 1 do
      local p = history[start + i].p
      local bh = 6 + math.floor((chartH - 6) * ((p - lo) / span))
      local bar = parent:CreateTexture(nil, "ARTWORK")
      bar:SetSize(barW, bh)
      bar:SetPoint("BOTTOMLEFT", left + i * (barW + 1), bottom)
      if bar.SetColorTexture then bar:SetColorTexture(unpack(tone)) end
    end
  end
  return y - chartH - 8
end

function LS:RenderWidgetChrome(canvas, entry, cellW, cellH)
  local w = self.widgets
  local spec = self:WidgetSpec(entry.id)
  if not spec then return end
  local edit = self.dashboardEdit
  local width = (entry.w or MIN_W) * cellW
  local height = (entry.h or MIN_H) * cellH
  local chrome = w.panel(canvas)
  chrome:SetPoint("TOPLEFT", (entry.x or 0) * cellW, -(entry.y or 0) * cellH)
  chrome:SetSize(width, height)
  w.paint(chrome)

  local title = w.text(chrome, width - (edit and 90 or 16), 12)
  title:SetPoint("TOPLEFT", 10, -6)
  title:SetTextColor(unpack(self.colors.accent))
  title:SetText(self:WidgetTitle(spec))
  if self.FitText then self:FitText(title, width - (edit and 90 or 16), 1) end

  if edit then
    local remove = w.button(chrome, "Remove", 74, 20, 10)
    remove:SetPoint("TOPRIGHT", -8, -4)
    w.paint(remove, "panel")
    remove:SetScript("OnMouseUp", function()
      self:DashboardRemove(entry.id)
      self:ShowPage("DASHBOARD")
    end)
  end

  local body = CreateFrame("Frame", nil, chrome)
  body:SetPoint("TOPLEFT", 0, -HEADER)
  body:SetPoint("BOTTOMRIGHT", -8, 10)
  if body.SetClipsChildren then body:SetClipsChildren(true) end
  spec.render(self, body, width - 8, math.max(1, height - HEADER - 10))
  if spec.tooltip then
    self:HoverTip(chrome, function(tip) spec.tooltip(self, tip) end)
  end
  if spec.click and not edit then
    chrome:EnableMouse(true)
    chrome:SetScript("OnMouseUp", function()
      spec.click(self)
    end)
  end

  if edit then
    chrome:SetMovable(true)
    chrome:SetResizable(true)
    chrome:EnableMouse(true)
    chrome:RegisterForDrag("LeftButton")
    if chrome.SetResizeBounds then
      chrome:SetResizeBounds(MIN_W * cellW, MIN_H * cellH, CANVAS_COLS * cellW, self:DashboardRows() * cellH)
    end
    chrome:SetScript("OnDragStart", function(selfFrame)
      LS:BeginWidgetDrag(selfFrame, entry.id)
    end)
    chrome:SetScript("OnDragStop", function(selfFrame)
      LS:EndWidgetDrag(selfFrame)
      LS:CommitWidgetFrame(entry.id, selfFrame)
      LS:ShowPage("DASHBOARD")
    end)
    local function Grip(wpx, hpx, point, sizing)
      local grip = CreateFrame("Button", nil, chrome)
      grip:SetSize(wpx, hpx)
      grip:SetPoint(point)
      grip:EnableMouse(true)
      local hint = grip:CreateTexture(nil, "OVERLAY")
      hint:SetAllPoints()
      if hint.SetColorTexture and self.colors then
        hint:SetColorTexture(unpack(self.colors.border))
      end
      grip.hint = hint
      grip:SetScript("OnEnter", function()
        if LS.colors and hint.SetColorTexture then hint:SetColorTexture(unpack(LS.colors.accent)) end
      end)
      grip:SetScript("OnLeave", function()
        if LS.colors and hint.SetColorTexture then hint:SetColorTexture(unpack(LS.colors.border)) end
      end)
      grip:SetScript("OnMouseDown", function()
        chrome:StartSizing(sizing)
      end)
      grip:SetScript("OnMouseUp", function()
        chrome:StopMovingOrSizing()
        LS:CommitWidgetFrame(entry.id, chrome)
        LS:ShowPage("DASHBOARD")
      end)
    end
    Grip(6, 18, "RIGHT", "RIGHT")
    Grip(18, 6, "BOTTOM", "BOTTOM")
    Grip(12, 12, "BOTTOMRIGHT", "BOTTOMRIGHT")
  end
  table.insert(self.dashboardSlots, { id = entry.id, frame = chrome })
  if self.MarkCoach then self:MarkCoach("widget:" .. entry.id, chrome) end
end

function LS:DashboardPage()
  local w = self.widgets
  local editing = self.dashboardEdit
  local width = self:ContentWidth()
  local heading = w.text(self.content, width - 120, 22)
  heading:SetPoint("TOPLEFT", 0, 0)
  heading:SetTextColor(unpack(self.colors.accent))
  heading:SetText("Dashboard")
  local line = w.text(self.content, width - 120, 11)
  line:SetPoint("TOPLEFT", 0, -32)
  line:SetText(editing
    and ("Drag to move. Drag an edge or corner to resize. Widgets cannot overlap. Canvas is "
      .. CANVAS_COLS .. " × " .. self:DashboardRows() .. " cells, and grows down to "
      .. MAX_ROWS .. ".")
    or "Where things stand, then the next action.")

  local edit = w.button(self.content, editing and "Done editing" or "Edit dashboard", 110, 26, 11)
  edit:SetPoint("TOPRIGHT", 0, -2)
  if editing then w.highlight(edit) end
  edit:SetScript("OnMouseUp", function()
    self:SetDashboardEdit(not editing)
  end)
  if self.MarkCoach then self:MarkCoach("edit", edit) end

  if not self:TokenPrice() then
    self:RequestTokenPrice()
  end
  self:RecordTokenPrice()
  if self.dashboardDragGhost then self.dashboardDragGhost:Hide() end
  if self.HideWidgetDropHints then self:HideWidgetDropHints() end
  self.dashboardDropHints = {}

  local body = self:Body(76)
  self.dashboardSlots = {}
  local layout = self:DashboardLayout()
  local visible = 0
  for _, entry in ipairs(layout) do
    if self:WidgetAvailable(self:WidgetSpec(entry.id)) then visible = visible + 1 end
  end
  if visible == 0 and not editing then
    local none = w.text(body, body.width, 11)
    none:SetPoint("TOPLEFT", 0, 0)
    none:SetText("No widgets on the dashboard. Edit dashboard to add some.")
    local go = w.button(body, "Edit dashboard", 140, 30)
    go:SetPoint("TOPLEFT", 0, -28)
    w.highlight(go)
    go:SetScript("OnMouseUp", function() self:SetDashboardEdit(true) end)
    body:finish(70)
    return
  end

  local canvasW, canvasH, cellW, cellH = self:DashboardCanvasSize(body.width)
  local canvas = w.panel(body)
  canvas:SetPoint("TOPLEFT", 0, 0)
  canvas:SetSize(canvasW, canvasH)
  w.paint(canvas, "panel")
  if self.colors then
    local bg = self.colors.bg or self.colors.panel
    canvas:SetBackdropColor(bg[1], bg[2], bg[3], 0.35)
  end
  self.dashboardCanvas = canvas
  if editing then
    local bound = w.text(canvas, canvasW - 16, 10)
    bound:SetPoint("BOTTOMLEFT", 8, 6)
    bound:SetTextColor(unpack(self.colors.muted))
    bound:SetText("Canvas: " .. CANVAS_COLS .. " × " .. self:DashboardRows()
      .. "  ·  grows to " .. MAX_ROWS)
  end
  for _, entry in ipairs(layout) do
    if self:WidgetAvailable(self:WidgetSpec(entry.id)) then
      self:RenderWidgetChrome(canvas, entry, cellW, cellH)
    end
  end

  local y = -canvasH - 10
  if editing then
    local addHeading = w.text(body, body.width, 12)
    addHeading:SetPoint("TOPLEFT", 0, y)
    addHeading:SetTextColor(unpack(self.colors.accent))
    addHeading:SetText("Add a widget. Each button shows that tile's size in cells.")
    y = y - 22
    local addW, col, cols, gap = 210, 0, math.max(1, math.floor((body.width + 8) / 218)), 8
    local added = 0
    for _, spec in ipairs(self.widgetCatalog or {}) do
      if self:WidgetAvailable(spec) and not self:DashboardHas(spec.id) then
        local dw, dh = SpecSpan(spec)
        local add = w.button(body, "Add · " .. self:WidgetTitle(spec) .. "  " .. dw .. "×" .. dh, addW, 26, 10)
        add:SetPoint("TOPLEFT", col * (addW + gap), y)
        add:SetScript("OnMouseUp", function()
          self:DashboardAdd(spec.id)
          self:ShowPage("DASHBOARD")
        end)
        if self.MarkCoach then self:MarkCoach("add:" .. spec.id, add) end
        col = col + 1
        if col >= cols then
          col = 0
          y = y - 32
        end
        added = added + 1
      end
    end
    if col > 0 then y = y - 32 end
    if added == 0 then
      local none = w.text(body, body.width, 11)
      none:SetPoint("TOPLEFT", 0, y)
      none:SetText("Every available widget is already on the dashboard.")
      y = y - 24
    end
    local reset = w.button(body, "Reset widgets", 140, 28)
    reset:SetPoint("TOPLEFT", 0, y)
    reset:SetScript("OnMouseUp", function()
      self:ResetDashboardLayout()
      self:ShowPage("DASHBOARD")
    end)
    local pack = w.button(body, "Compact up", 140, 28)
    pack:SetPoint("TOPLEFT", 148, y)
    pack:SetScript("OnMouseUp", function()
      self:DashboardCompactUp()
      self:ShowPage("DASHBOARD")
    end)
    y = y - 36
  end

  body:finish(-y + 10)
end

local function RegisterBuiltins()
  LS:RegisterWidget({
    id = "stats",
    title = "Overview",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("Overview")
      if tip.AddLine then
        tip:AddLine((#self:GetRecommendations()) .. " on the plan")
        local filled, total = self:VaultSlotCounts()
        tip:AddLine(string.format("Vault %d/%d", filled, total))
      end
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "stats", "Totals on this tile.", {
          { "plan", "On the plan", true },
          { "vault", "Vault", true },
          { "knowledge", "Knowledge", true },
          { "ignored", "Ignored", true },
          { "completed", "Completed", true },
          { "tracked", "Tracked", true },
        })
      end
      local w = self.widgets
      local recs = self:GetRecommendations()
      local filled, total = self:VaultSlotCounts()
      local vaultLabel = "Vault slots filled"
      local vaultValue = string.format("%d/%d", filled, total)
      if self.IsEndgameLevel and not self:IsEndgameLevel() then
        vaultLabel = "Vault at " .. self:EndgameLevel()
        vaultValue = "—"
      end
      local stats = {}
      if self:WidgetOptOn("stats", "plan", true) then
        table.insert(stats, { #recs, "On the plan" })
      end
      if self:WidgetOptOn("stats", "vault", true) then
        table.insert(stats, { vaultValue, vaultLabel,
          function() self:ShowPage("VAULT") end, true })
      end
      if self:WidgetOptOn("stats", "knowledge", true) then
        table.insert(stats, { self:UnspentKnowledge(), "Unspent knowledge" })
      end
      if self:WidgetOptOn("stats", "ignored", true) then
        table.insert(stats, { self:CountFlags("dismissed"), "Ignored" })
      end
      if self:WidgetOptOn("stats", "completed", true) then
        table.insert(stats, { self:CountFlags("completed"), "Completed" })
      end
      if self:WidgetOptOn("stats", "tracked", true) then
        table.insert(stats, { #(self:TrackedActivities()), "Tracked" })
      end
      if #stats == 0 then
        local none = w.text(parent, width - 24, 11)
        none:SetPoint("TOPLEFT", 12, -8)
        if self.colors then none:SetTextColor(unpack(self.colors.muted)) end
        none:SetText("Every total is hidden. Edit dashboard to pick some.")
        return 36
      end
      local columns = math.max(1, math.floor((width + 8) / 118))
      local cellW = math.floor(width / columns) - 8
      local rowH = 48
      for i, stat in ipairs(stats) do
        local col = (i - 1) % columns
        local rowIndex = math.floor((i - 1) / columns)
        local cell = w.panel(parent)
        cell:SetSize(cellW, 44)
        cell:SetPoint("TOPLEFT", 8 + col * (cellW + 8), -4 - rowIndex * rowH)
        w.paint(cell)
        if stat[3] then
          cell:EnableMouse(true)
          cell:SetScript("OnMouseUp", stat[3])
        end
        if stat[4] then
          cell:EnableMouse(true)
          cell:SetScript("OnEnter", function(selfFrame) LS:ShowVaultTooltip(selfFrame) end)
          cell:SetScript("OnLeave", function() LS:HideVaultTooltip() end)
        end
        local amount = w.text(cell, cellW - 16, 16)
        amount:SetPoint("TOPLEFT", 8, -6)
        amount:SetTextColor(unpack(self.colors.accent))
        amount:SetText(tostring(stat[1]))
        if self.FitText then self:FitText(amount, cellW - 16, 1) end
        local name = w.text(cell, cellW - 16, 10)
        name:SetPoint("TOPLEFT", 8, -24)
        name:SetText(stat[2])
        if self.FitText then self:FitText(name, cellW - 16, 1) end
      end
      return math.ceil(#stats / columns) * rowH + 4
    end,
  })

  LS:RegisterWidget({
    id = "shortcuts",
    title = "Jump",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(_, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("Jump")
      if tip.AddLine then tip:AddLine("Open Today's Plan, Weekly, Progress, or the Great Vault.") end
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "shortcuts", "Shortcuts on this tile.", {
          { "today", "Today", true },
          { "weekly", "Weekly", true },
          { "progress", "Progress", true },
          { "vault", "Great Vault", true },
        })
      end
      local w = self.widgets
      local jumps = {}
      if self:WidgetOptOn("shortcuts", "today", true) then
        table.insert(jumps, { "Today's Plan", function() self:ShowPage("TODAY") end })
      end
      if self:WidgetOptOn("shortcuts", "weekly", true) then
        table.insert(jumps, { "Weekly Plan", function() self:ShowPage("WEEKLY") end })
      end
      if self:WidgetOptOn("shortcuts", "progress", true) then
        table.insert(jumps, { "Progress", function() self:ShowPage("PROGRESS") end })
      end
      if self:WidgetOptOn("shortcuts", "vault", true) then
        table.insert(jumps, { "Great Vault", function() self:OpenGreatVault() end, true })
      end
      if #jumps == 0 then
        local none = w.text(parent, width - 24, 11)
        none:SetPoint("TOPLEFT", 12, -8)
        if self.colors then none:SetTextColor(unpack(self.colors.muted)) end
        none:SetText("Every shortcut is hidden. Edit dashboard to pick some.")
        return 36
      end
      local jumpGap, minBtn = 8, 88
      local inner = math.max(minBtn, width - 16)
      local cols = math.min(#jumps, math.max(1, math.floor((inner + jumpGap) / (110 + jumpGap))))
      local jumpW = math.floor((inner - jumpGap * (cols - 1)) / cols)
      for i, jump in ipairs(jumps) do
        local go = w.button(parent, jump[1], jumpW, 26)
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        go:SetPoint("TOPLEFT", 8 + col * (jumpW + jumpGap), -6 - row * 32)
        go:SetScript("OnMouseUp", jump[2])
        if jump[3] then
          go:SetScript("OnEnter", function(selfFrame) LS:ShowVaultTooltip(selfFrame) end)
          go:SetScript("OnLeave", function() LS:HideVaultTooltip() end)
        end
      end
      return math.ceil(#jumps / cols) * 32 + 8
    end,
  })

  LS:RegisterWidget({
    id = "professions",
    title = "Professions",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("Professions")
      if tip.AddLine then
        local current = self.CurrentExpansionProfessions and self:CurrentExpansionProfessions() or self.professions or {}
        tip:AddLine(string.format("%d trained this expansion. %d unspent knowledge.", #current, self:UnspentKnowledge()))
      end
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "professions", "Controls on this tile.", {
          { "icons", "Icons", true },
          { "open", "Open", true },
        })
      end
      local w = self.widgets
      local current = self.CurrentExpansionProfessions and self:CurrentExpansionProfessions() or self.professions or {}
      local trained = #current
      local unspent = self:UnspentKnowledge()
      local primaries = self.PrimaryProfessions and self:PrimaryProfessions() or {}
      local showIcons = self:WidgetOptOn("professions", "icons", true)
      local showOpen = self:WidgetOptOn("professions", "open", true)
      local iconSize = 32
      local iconGap = 6
      local iconsW = (showIcons and #primaries > 0) and (#primaries * (iconSize + iconGap)) or 0
      local stacked = width < 360
      local line = w.text(parent, width - (stacked and 24 or (showOpen and 100 or 24)) - iconsW, 11)
      line:SetPoint("TOPLEFT", 12 + iconsW, -8)
      if trained == 0 and #(self.professions or {}) == 0 then
        line:SetText("Open a profession window once so the client sends its data.")
      else
        line:SetText(string.format("%d trained. %d unspent knowledge this expansion.", trained, unspent))
      end
      if showIcons then
        for i, prof in ipairs(primaries) do
          local x = 12 + (i - 1) * (iconSize + iconGap)
          local art = parent:CreateTexture(nil, "ARTWORK")
          art:SetSize(iconSize, iconSize)
          art:SetPoint("TOPLEFT", x, -6)
          art.professionIcon = true
          art.professionName = prof.name
          if art.SetTexture and prof.icon then art:SetTexture(prof.icon) end
          if (not prof.icon or not art.SetTexture) and art.SetColorTexture and self.colors then
            art:SetColorTexture(unpack(self.colors.panel or self.colors.card))
          end
          local hit = CreateFrame("Frame", nil, parent)
          hit:SetPoint("TOPLEFT", x, -6)
          hit:SetSize(iconSize, iconSize)
          hit:EnableMouse(true)
          local skill = prof
          self:HoverTip(hit, function(tip)
            if tip.ClearLines then tip:ClearLines() end
            tip:SetText(skill.name or "Profession")
            if tip.AddLine then tip:AddLine("Open this profession. Click again to close it.") end
          end)
          hit:SetScript("OnMouseUp", function()
            if self.OpenProfessionWindow then self:OpenProfessionWindow(skill) end
          end)
        end
      end
      if showOpen then
        local open = w.button(parent, "Open", 74, 26)
        if stacked then
          open:SetPoint("TOPLEFT", 12, -42)
        else
          open:SetPoint("TOPRIGHT", -10, -8)
        end
        w.paint(open, "panel")
        open:SetScript("OnMouseUp", function() self:ShowPage("PROFESSIONS") end)
      end
      return (stacked and showOpen) and 72 or math.max(48, iconSize + 16)
    end,
  })

  LS:RegisterWidget({
    id = "next",
    title = "Next",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local recs = self:GetRecommendations()
      if recs[1] then
        tip:SetText(recs[1].title or "Next")
        if tip.AddLine and recs[1].why then tip:AddLine(recs[1].why, 1, 1, 1, true) end
      else
        tip:SetText("Next")
        if tip.AddLine then tip:AddLine("Nothing is currently worth ranking.") end
      end
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintEditIdle(parent, width)
      end
      local w = self.widgets
      local recs = self:GetRecommendations()
      if #recs == 0 then
        local none = w.text(parent, width - 20, 11)
        none:SetPoint("TOPLEFT", 12, -8)
        if self:GoalsChosen() then
          none:SetText("Nothing is currently worth ranking. That changes as the week does.")
          return 36
        end
        none:SetText("Every goal is off, so there is nothing to weigh against.")
        local pick = w.button(parent, "Choose my goals", 180, 28)
        pick:SetPoint("TOPLEFT", 12, -36)
        w.highlight(pick)
        pick:SetScript("OnMouseUp", function() self:ShowPage("WELCOME") end)
        return 72
      end
      local _, h = self:ActivityCard(parent, recs[1], -4, width - 16)
      return (h or 104) + 8
    end,
  })

  LS:RegisterWidget({
    id = "vault",
    title = "Great Vault",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "vault", "Buttons on this tile.", {
          { "chest", "Vault", true },
          { "open", "Open", true },
        })
      end
      local w = self.widgets
      if self.IsEndgameLevel and not self:IsEndgameLevel() then
        local cap = self:EndgameLevel()
        parent:EnableMouse(true)
        parent:SetScript("OnEnter", function(selfFrame) LS:ShowVaultTooltip(selfFrame) end)
        parent:SetScript("OnLeave", function() LS:HideVaultTooltip() end)
        local line = w.text(parent, width - 24, 11)
        line:SetPoint("TOPLEFT", 12, -8)
        line:SetText(string.format("Opens at level %d. Level and enjoy the game until then.", cap))
        local hint = w.text(parent, width - 24, 10)
        hint:SetPoint("TOPLEFT", 12, -28)
        hint:SetTextColor(unpack(self.colors.muted))
        hint:SetText("Train professions along the way if you want them.")
        return 52
      end
      local filled, total, upgradable = self:VaultSlotCounts()
      parent:EnableMouse(true)
      parent:SetScript("OnEnter", function(selfFrame) LS:ShowVaultTooltip(selfFrame) end)
      parent:SetScript("OnLeave", function() LS:HideVaultTooltip() end)
      local showChest = self:WidgetOptOn("vault", "chest", true)
      local showOpen = self:WidgetOptOn("vault", "open", true)
      local line = w.text(parent, width - ((showChest or showOpen) and 100 or 24), 11)
      line:SetPoint("TOPLEFT", 12, -8)
      line:SetText(string.format("%d of %d slots filled. %d can still be improved.",
        filled, total, upgradable))
      local hint = w.text(parent, width - ((showChest or showOpen) and 100 or 24), 10)
      hint:SetPoint("TOPLEFT", 12, -28)
      hint:SetTextColor(unpack(self.colors.muted))
      hint:SetText("Hover for named keys and reward item levels.")
      if showChest then
        local vault = w.button(parent, "Vault", 70, 24, 10)
        vault:SetPoint("TOPRIGHT", -10, -8)
        w.paint(vault, "panel")
        w.highlight(vault)
        vault:SetScript("OnMouseUp", function() self:OpenGreatVault() end)
      end
      if showOpen then
        local open = w.button(parent, "Open", 70, 24, 10)
        open:SetPoint("TOPRIGHT", -10, showChest and -36 or -8)
        w.paint(open, "panel")
        open:SetScript("OnMouseUp", function() self:ShowPage("VAULT") end)
      end
      return 68
    end,
  })

  LS:RegisterWidget({
    id = "tracked",
    title = "Tracked",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local tracked = self:TrackedActivities()
      tip:SetText("Tracked")
      if tip.AddLine then
        if #tracked == 0 then
          tip:AddLine("Nothing tracked yet. Details → Track.")
        else
          for i = 1, math.min(6, #tracked) do
            tip:AddLine(tracked[i].title)
          end
        end
      end
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "tracked", "Buttons on this tile.", {
          { "progress", "Progress", true },
        })
      end
      local w = self.widgets
      local tracked = self:TrackedActivities()
      if #tracked == 0 then
        local none = w.text(parent, width - 20, 11)
        none:SetPoint("TOPLEFT", 12, -8)
        none:SetText("Nothing tracked yet. Details → Track.")
        return 36
      end
      local y, shown = -6, math.min(4, #tracked)
      for i = 1, shown do
        local row = w.text(parent, width - 20, 11)
        row:SetPoint("TOPLEFT", 12, y)
        row:SetText(tracked[i].title)
        y = y - 18
      end
      if #tracked > shown then
        local more = w.text(parent, width - 20, 10)
        more:SetPoint("TOPLEFT", 12, y)
        more:SetTextColor(unpack(self.colors.muted))
        more:SetText(string.format("%d more on Progress.", #tracked - shown))
        y = y - 16
      end
      if self:WidgetOptOn("tracked", "progress", true) then
        local go = w.button(parent, "Progress", 80, 22, 10)
        go:SetPoint("TOPLEFT", 12, y - 4)
        go:SetScript("OnMouseUp", function() self:ShowPage("PROGRESS") end)
        return (-y) + 30
      end
      return (-y) + 8
    end,
  })

  LS:RegisterWidget({
    id = "token",
    title = "WoW Token",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("WoW Token")
      local price = self:TokenPrice()
      if tip.AddLine then
        if price then
          local text = self:FormatTokenMoney(price, { format = "letters", separators = true })
          tip:AddLine(text)
          tip:AddLine("The price the client last published.")
        else
          tip:AddLine("The client has not published a token price.")
        end
      end
    end,
    render = function(self, parent, width, height)
      if self.dashboardEdit then
        return self:PaintMoneyFormatSettings(parent, width, "token")
      end
      local w = self.widgets
      local opts = self:WidgetOpts("token")
      local format = opts.format or "letters"
      local colorOn = opts.color ~= false
      local sepOn = opts.separators and true or false
      local chart = opts.chart == "line" and "line" or "bars"
      local price = self:TokenPrice()
      local amount = w.text(parent, width - 24, 18)
      amount:SetPoint("TOPLEFT", 12, -8)
      local y = -34
      if not price then
        amount:SetTextColor(unpack(self.colors.accent))
        amount:SetText("No price yet")
        local hint = w.text(parent, width - 24, 10)
        hint:SetPoint("TOPLEFT", 12, y)
        hint:SetTextColor(unpack(self.colors.muted))
        hint:SetText("The client has not published a token price.")
        y = y - 18
      else
        local text, r, g, b = self:FormatTokenMoney(price, {
          format = format, color = colorOn, separators = sepOn,
        })
        amount:SetText(text)
        amount:SetTextColor(r, g, b, 1)
        local history = self.db.tokenHistory or {}
        if #history >= 2 then
          local delta = history[#history].p - history[1].p
          local change = w.text(parent, width - 24, 10)
          change:SetPoint("TOPLEFT", 12, y)
          local deltaText, dr, dg, db = self:FormatTokenMoney(delta, {
            format = format, color = colorOn, separators = sepOn,
          })
          change:SetText((delta >= 0 and "+" or "") .. deltaText .. " vs first sample")
          if delta < 0 then
            change:SetTextColor(unpack(self.colors.warn))
          else
            change:SetTextColor(dr, dg, db, 1)
          end
          local remain = math.max(24, (height or 80) + (y - 14) - 10)
          y = self:PaintSparkline(parent, history, width, y - 14, self.colors, chart, remain)
        else
          local hint = w.text(parent, width - 24, 10)
          hint:SetPoint("TOPLEFT", 12, y)
          hint:SetTextColor(unpack(self.colors.muted))
          hint:SetText("A trend appears after the client posts another price.")
          y = y - 18
        end
      end
      return (-y) + 8
    end,
  })

  LS:RegisterWidget({
    id = "gold",
    title = "Gold",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local recs = self.GetGoldRecommendations and self:GetGoldRecommendations() or {}
      tip:SetText((recs[1] and recs[1].title) or "Gold")
      if tip.AddLine and recs[1] and recs[1].why then tip:AddLine(recs[1].why, 1, 1, 1, true) end
    end,
    available = function(self)
      local _, _, ready = self:ResolveGoldSource()
      return ready and self.db.goals.GOLD
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintEditIdle(parent, width)
      end
      local w = self.widgets
      local recs = self.GetGoldRecommendations and self:GetGoldRecommendations() or {}
      local line = w.text(parent, width - 20, 11)
      line:SetPoint("TOPLEFT", 12, -8)
      if #recs == 0 then
        line:SetText("Nothing priced from the loaded auction house addon.")
        return 36
      end
      line:SetText(recs[1].title)
      local meta = w.text(parent, width - 20, 10)
      meta:SetPoint("TOPLEFT", 12, -28)
      meta:SetTextColor(unpack(self.colors.muted))
      local _, name = self:ResolveGoldSource()
      meta:SetText((name or "AH") .. (recs[1].why and ("  •  " .. recs[1].why) or ""))
      return 52
    end,
  })

  LS:RegisterWidget({
    id = "rares",
    title = "Rares",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      local recs = self.GetHandyNotesRecommendations and self:GetHandyNotesRecommendations() or {}
      tip:SetText((recs[1] and recs[1].title) or "Rares")
      if tip.AddLine and recs[1] and recs[1].why then tip:AddLine(recs[1].why, 1, 1, 1, true) end
    end,
    available = function()
      return HandyNotes and type(HandyNotes.plugins) == "table"
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintEditIdle(parent, width)
      end
      local w = self.widgets
      local recs = self.GetHandyNotesRecommendations and self:GetHandyNotesRecommendations() or {}
      local line = w.text(parent, width - 20, 11)
      line:SetPoint("TOPLEFT", 12, -8)
      if #recs == 0 then
        line:SetText("No rares marked in this zone.")
        return 36
      end
      line:SetText(recs[1].title)
      local meta = w.text(parent, width - 20, 10)
      meta:SetPoint("TOPLEFT", 12, -28)
      meta:SetTextColor(unpack(self.colors.muted))
      meta:SetText(recs[1].why or "")
      return 52
    end,
  })

  LS:RegisterWidget({
    id = "warband",
    title = "Warband",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("Warband")
      if tip.AddLine then
        local totals = self:GetWarbandTotals()
        tip:AddLine(string.format("%d characters. %d vaults with slots.",
          totals.characters, totals.vaultsWithSlots))
      end
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintWidgetSettings(parent, width, "warband", "Buttons on this tile.", {
          { "open", "Open", true },
        })
      end
      local w = self.widgets
      local totals = self:GetWarbandTotals()
      local line = w.text(parent, width - 20, 11)
      line:SetPoint("TOPLEFT", 12, -8)
      line:SetText(string.format("%d characters. %d vaults with slots.",
        totals.characters, totals.vaultsWithSlots))
      local meta = w.text(parent, width - 20, 10)
      meta:SetPoint("TOPLEFT", 12, -28)
      meta:SetTextColor(unpack(self.colors.muted))
      meta:SetText(string.format("%d unspent knowledge across the warband.", totals.unspentKnowledge))
      if self:WidgetOptOn("warband", "open", true) then
        local go = w.button(parent, "Open", 70, 22, 10)
        go:SetPoint("TOPRIGHT", -10, -10)
        go:SetScript("OnMouseUp", function() self:ShowPage("WARBAND") end)
      end
      return 52
    end,
  })

  LS:RegisterWidget({
    id = "reset",
    title = "Weekly reset",
    defaultSize = "half",
    sizes = { half = true, wide = true },
    tooltip = function(self, tip)
      if tip.ClearLines then tip:ClearLines() end
      tip:SetText("Weekly reset")
      local seconds = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
      if tip.AddLine then
        if type(seconds) == "number" then
          local days = math.floor(seconds / 86400)
          local hours = math.floor((seconds % 86400) / 3600)
          tip:AddLine(string.format("%dd %dh remaining.", days, hours))
        else
          tip:AddLine("The client has not sent a reset time.")
        end
      end
    end,
    render = function(self, parent, width)
      if self.dashboardEdit then
        return self:PaintEditIdle(parent, width)
      end
      local w = self.widgets
      local seconds = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
      local amount = w.text(parent, width - 24, 18)
      amount:SetPoint("TOPLEFT", 12, -8)
      amount:SetTextColor(unpack(self.colors.accent))
      amount:SetText(type(seconds) == "number" and FormatCountdown(seconds) or "Unknown")
      local hint = w.text(parent, width - 24, 10)
      hint:SetPoint("TOPLEFT", 12, -32)
      hint:SetTextColor(unpack(self.colors.muted))
      hint:SetText("Until weekly reset.")
      return 52
    end,
  })
end

RegisterBuiltins()
