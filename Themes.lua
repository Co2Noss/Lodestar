local _, LS = ...

-- Order matters for the settings swatches, and doubles as the list of keys a player may
-- override.
LS.colorOrder = {
  { "accent", "Accent" },
  { "text", "Text" },
  { "bg", "Background" },
  { "panel", "Panels" },
  { "card", "Cards" },
  { "border", "Borders" },
  { "warn", "Warnings" },
  { "muted", "Muted text" },
}

LS.palettes = {
  -- Matches the modern frame art Dragonflight introduced: a warm neutral dark panel with
  -- gold trim, rather than the blue-grey this used to invent.
  BLIZZARD = {
    bg = { .09, .08, .07, .95 }, panel = { .13, .12, .10, .95 }, card = { .17, .155, .13, .95 },
    border = { .45, .36, .22, 1 }, accent = { 1, .82, 0, 1 }, text = { 1, 1, 1, 1 },
    warn = { 1, .125, .125, 1 }, muted = { .5, .5, .5, 1 },
  },
  ELVUI = {
    bg = { .025, .025, .025, .98 }, panel = { .045, .045, .045, .98 }, card = { .065, .065, .065, .98 },
    border = { .18, .18, .18, 1 }, accent = { .25, .75, .70, 1 }, text = { .9, .9, .9, 1 },
    warn = { .9, .35, .33, 1 }, muted = { .58, .58, .58, 1 },
  },
  ELLESMERE = {
    bg = { .02, .025, .035, .98 }, panel = { .035, .045, .06, .98 }, card = { .055, .07, .09, .98 },
    border = { .12, .2, .25, 1 }, accent = { .32, .82, .72, 1 }, text = { .9, .94, .96, 1 },
    warn = { .92, .4, .4, 1 }, muted = { .56, .62, .66, 1 },
  },
  MINIMAL = {
    bg = { .018, .02, .024, .98 }, panel = { .028, .03, .035, .98 }, card = { .04, .043, .05, .98 },
    border = { .12, .13, .15, 1 }, accent = { .55, .65, .75, 1 }, text = { .9, .9, .92, 1 },
    warn = { .88, .42, .42, 1 }, muted = { .55, .58, .62, 1 },
  },
}

LS.themeOrder = { "AUTO", "BLIZZARD", "ELVUI", "ELLESMERE", "MINIMAL" }

local function loaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

function LS:DetectTheme()
  if loaded("EllesmereUI") or loaded("EllesmereUIBlizzardSkin") then return "ELLESMERE" end
  if loaded("ElvUI") then return "ELVUI" end
  return "BLIZZARD"
end

function LS:CurrentTheme()
  local wanted = self.db.theme or "AUTO"
  if wanted == "AUTO" then return self:DetectTheme() end
  return self.palettes[wanted] and wanted or "BLIZZARD"
end

-- Real ElvUI handshake: pull the user's actual media instead of guessing at colors.
function LS:GetElvUI()
  if not loaded("ElvUI") or not _G.ElvUI then return nil end
  local ok, engine = pcall(unpack, _G.ElvUI)
  if not ok or type(engine) ~= "table" then return nil end
  return engine
end

local function color(value, fallback)
  if type(value) == "table" then
    if value.r then
      return { value.r, value.g or 0, value.b or 0, value.a or 1 }
    end
    if value[1] then
      return { value[1], value[2] or 0, value[3] or 0, value[4] or 1 }
    end
  end
  return fallback
end

local function shade(rgba, factor, alpha)
  return { rgba[1] * factor, rgba[2] * factor, rgba[3] * factor, alpha or rgba[4] or 1 }
end

-- Builds a palette out of ElvUI's own backdrop, border, texture and font settings.
function LS:BuildElvUIPalette()
  local E = self:GetElvUI()
  if not E or type(E.media) ~= "table" then return nil end
  local base = self.palettes.ELVUI
  local backdrop = color(E.media.backdropcolor, base.bg)
  local fade = color(E.media.backdropfadecolor, backdrop)
  local border = color(E.media.bordercolor, base.border)
  local value = E.db and E.db.general and E.db.general.valuecolor
  local accent = color(value, base.accent)

  self.skin = {
    texture = E.media.normTex or E.media.blankTex,
    font = E.media.normFont,
    fontSize = (E.db and E.db.general and E.db.general.fontSize) or 12,
  }

  return {
    bg = { backdrop[1], backdrop[2], backdrop[3], 0.98 },
    panel = { fade[1], fade[2], fade[3], math.max(0.85, fade[4] or 0.9) },
    card = shade({ fade[1], fade[2], fade[3], 1 }, 1.35, 0.95),
    border = border,
    accent = accent,
    text = base.text,
    warn = base.warn,
    muted = base.muted,
  }
end

-- The client's own font colours, so text reads exactly as it does in Blizzard's frames
-- instead of approximating gold and grey by hand.
local function clientColor(name, fallback)
  local value = _G[name]
  if type(value) == "table" and value.GetRGB then
    local ok, r, g, b = pcall(value.GetRGB, value)
    if ok and r then return { r, g, b, 1 } end
  end
  return fallback
end

function LS:BuildBlizzardPalette()
  local base = self.palettes.BLIZZARD
  return {
    bg = base.bg, panel = base.panel, card = base.card, border = base.border,
    accent = clientColor("NORMAL_FONT_COLOR", base.accent),
    text = clientColor("WHITE_FONT_COLOR", base.text),
    warn = clientColor("RED_FONT_COLOR", base.warn),
    muted = clientColor("GRAY_FONT_COLOR", base.muted),
  }
end

-- A player's chosen colours win over whatever the theme resolved to, including ElvUI's
-- live media, so switching themes never silently discards them.
function LS:ApplyColorOverrides(palette)
  local custom = self.db and self.db.colors
  local out = {}
  for key, value in pairs(palette) do out[key] = value end
  if type(custom) ~= "table" then return out, false end
  local touched = false
  for _, entry in ipairs(self.colorOrder) do
    local key = entry[1]
    local chosen = custom[key]
    if out[key] and type(chosen) == "table" and chosen.r then
      out[key] = { chosen.r, chosen.g, chosen.b, chosen.a or out[key][4] or 1 }
      touched = true
    end
  end
  return out, touched
end

function LS:HasCustomColors()
  local custom = self.db and self.db.colors
  if type(custom) ~= "table" then return false end
  for _, entry in ipairs(self.colorOrder) do
    if type(custom[entry[1]]) == "table" then return true end
  end
  return false
end

function LS:SetColor(key, r, g, b, a)
  self.db.colors = self.db.colors or {}
  self.db.colors[key] = { r = r, g = g, b = b, a = a or 1 }
  self:ApplyTheme()
  self:Refresh()
end

-- Blizzard's colour picker. Its calling convention changed in 10.2.5, so the modern entry
-- point is preferred and the old one is only a safety net.
function LS:PickColor(key)
  if not ColorPickerFrame then return false end
  local current = (self.colors and self.colors[key]) or { 1, 1, 1, 1 }
  local before = { current[1], current[2], current[3], current[4] or 1 }

  local function chosen()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local alpha = 1
    if ColorPickerFrame.GetColorAlpha then
      alpha = ColorPickerFrame:GetColorAlpha() or 1
    end
    return r, g, b, alpha
  end

  local function keep() self:SetColor(key, chosen()) end

  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = before[1], g = before[2], b = before[3],
      hasOpacity = true, opacity = before[4],
      swatchFunc = keep,
      opacityFunc = keep,
      cancelFunc = function() self:SetColor(key, before[1], before[2], before[3], before[4]) end,
    })
    return true
  end

  -- The old picker inverted its opacity value, so this path leaves alpha alone entirely.
  ColorPickerFrame.hasOpacity = false
  ColorPickerFrame.func = function() self:SetColor(key, ColorPickerFrame:GetColorRGB()) end
  ColorPickerFrame.cancelFunc = function()
    self:SetColor(key, before[1], before[2], before[3], before[4])
  end
  ColorPickerFrame:SetColorRGB(before[1], before[2], before[3])
  ColorPickerFrame:Hide()
  ColorPickerFrame:Show()
  return true
end

function LS:ResetColors()
  self.db.colors = {}
  self:ApplyTheme()
  self:Refresh()
end

function LS:ResolvePalette()
  local name = self:CurrentTheme()
  local palette, native = nil, false
  if name == "ELVUI" then
    palette = self:BuildElvUIPalette()
    native = palette ~= nil
  elseif name == "BLIZZARD" then
    palette = self:BuildBlizzardPalette()
  end
  if not native then self.skin = nil end
  palette = palette or self.palettes[name]
  return (self:ApplyColorOverrides(palette)), name, native
end

-- Inline colour for text that mixes tones in one font string, so urgency stays readable
-- on whichever palette is active.
function LS:Colorize(value, key)
  local color = self.colors and self.colors[key]
  if not color then return tostring(value) end
  return string.format("|cff%02x%02x%02x%s|r",
    math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
    math.floor(color[3] * 255 + 0.5), tostring(value))
end

function LS:ThemeFont()
  return (self.skin and self.skin.font) or STANDARD_TEXT_FONT
end

function LS:ThemeTexture()
  return (self.skin and self.skin.texture) or "Interface/Buttons/WHITE8X8"
end

function LS:SetTheme(name)
  name = (name or ""):upper()
  local valid = name == "AUTO" or self.palettes[name] ~= nil
  if not valid then
    self:PrintThemes()
    return
  end
  self.db.theme = name
  self:ApplyTheme()
  self:Refresh()
end

function LS:PrintThemes()
  print("Lodestar themes: auto, blizzard, elvui, ellesmere, minimal")
end

local TRANSPARENT = { 0, 0, 0, 0 }

function LS:ApplyTheme()
  if not self.frame then return end
  local palette, name, native = self:ResolvePalette()
  self.colors = palette
  self.themeName = name
  self.themeNative = native

  -- Blizzard's own panel art carries the window's background and border, so Lodestar's
  -- flat backdrop gets out of its way rather than drawing a second frame inside it.
  local chrome = self:UpdateChrome(name == "BLIZZARD")

  local texture = self:ThemeTexture()
  for _, frame in ipairs({ self.frame, self.header, self.sidebar }) do
    if frame and frame.SetBackdrop then
      frame:SetBackdrop({ bgFile = texture, edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
    end
  end

  self.frame:SetBackdropColor(unpack(chrome and TRANSPARENT or palette.bg))
  self.frame:SetBackdropBorderColor(unpack(chrome and TRANSPARENT or palette.border))
  self.sidebar:SetBackdropColor(unpack(palette.panel))
  self.sidebar:SetBackdropBorderColor(unpack(palette.border))
  -- With Blizzard chrome the title sits directly on the frame, the way its own windows do.
  self.header:SetBackdropColor(unpack(chrome and TRANSPARENT or palette.panel))
  self.header:SetBackdropBorderColor(unpack(chrome and TRANSPARENT or palette.border))
  self.title:SetTextColor(unpack(palette.accent))
  if self.subtitle then self.subtitle:SetTextColor(unpack(palette.muted)) end

  if self.closeButton then
    self.closeButton:SetBackdropColor(unpack(palette.card))
    self.closeButton:SetBackdropBorderColor(unpack(palette.border))
    -- ElvUI's backdrop is nearly black, so the glyph needs the theme's text color
    -- rather than the font object's default.
    self.closeButton.text:SetFont(self:ThemeFont(), 20, "")
    self.closeButton.text:SetTextColor(unpack(palette.text))
  end
  if self.UpdateCompact then self:UpdateCompact() end
  if self.sidebarToggle then
    self.sidebarToggle:SetBackdropColor(unpack(palette.card))
    self.sidebarToggle:SetBackdropBorderColor(unpack(palette.border))
    self.sidebarToggle.text:SetTextColor(unpack(palette.text))
  end
  for key, nav in pairs(self.nav or {}) do
    local active = self.NavActive and self:NavActive(key) or key == self.page
    nav:SetBackdropColor(unpack(palette.card))
    nav:SetBackdropBorderColor(unpack(active and palette.accent or palette.border))
    nav.text:SetTextColor(unpack(active and palette.accent or palette.text))
  end
  for _, header in ipairs(self.navHeaders or {}) do
    header:SetTextColor(unpack(palette.muted))
  end
  if self.sidebarVersion then
    self.sidebarVersion:SetTextColor(unpack(palette.muted))
  end
end
