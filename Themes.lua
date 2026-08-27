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
    -- ElvUI's own default border is near-black. A mid grey still reads on that backdrop
    -- without waiting for the player to set one.
    border = { .42, .42, .42, 1 }, accent = { .25, .75, .70, 1 }, text = { .9, .9, .9, 1 },
    warn = { .9, .35, .33, 1 }, muted = { .58, .58, .58, 1 },
  },
  ELLESMERE = {
    bg = { .02, .025, .035, .98 }, panel = { .035, .045, .06, .98 }, card = { .055, .07, .09, .98 },
    border = { .12, .2, .25, 1 }, accent = { .32, .82, .72, 1 }, text = { .9, .94, .96, 1 },
    warn = { .92, .4, .4, 1 }, muted = { .56, .62, .66, 1 },
  },
  -- Guild Wars 2 UI: parchment gold on a warm dark brown, matching GW2_ADDON.Gw2Color.
  GW2 = {
    bg = { .07, .05, .03, .98 }, panel = { .11, .08, .05, .98 }, card = { .15, .11, .07, .98 },
    border = { .45, .35, .22, 1 }, accent = { 1, .93, .73, 1 }, text = { .95, .92, .85, 1 },
    warn = { .9, .3, .2, 1 }, muted = { .62, .55, .45, 1 },
  },
  -- RealUI / Aurora: cool dark panels, class-blue highlight, visible grey edges.
  REALUI = {
    bg = { .04, .04, .05, .98 }, panel = { .07, .07, .08, .98 }, card = { .10, .10, .11, .98 },
    border = { .40, .40, .42, 1 }, accent = { .24, .57, 1, 1 }, text = { .9, .9, .92, 1 },
    warn = { .8, .25, .25, 1 }, muted = { .55, .55, .58, 1 },
  },
  -- W2UI: deep charcoal panels, gold active tabs, cool grey muted text.
  W2UI = {
    bg = { .04, .05, .07, .98 }, panel = { .08, .10, .14, .96 }, card = { .10, .12, .17, .95 },
    border = { .20, .24, .31, 1 }, accent = { 1, .68, .22, 1 }, text = { .93, .95, .98, 1 },
    warn = { .82, .24, .24, 1 }, muted = { .57, .63, .73, 1 },
  },
  MINIMAL = {
    bg = { .018, .02, .024, .98 }, panel = { .028, .03, .035, .98 }, card = { .04, .043, .05, .98 },
    border = { .12, .13, .15, 1 }, accent = { .55, .65, .75, 1 }, text = { .9, .9, .92, 1 },
    warn = { .88, .42, .42, 1 }, muted = { .55, .58, .62, 1 },
  },
}

LS.themeOrder = { "AUTO", "BLIZZARD", "ELVUI", "ELLESMERE", "GW2", "W2UI", "REALUI", "MINIMAL" }

local function loaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

function LS:DetectTheme()
  if loaded("EllesmereUI") or loaded("EllesmereUIBlizzardSkin") then return "ELLESMERE" end
  if loaded("W2UI") then return "W2UI" end
  if loaded("GW2_UI") then return "GW2" end
  -- Aurora is a library RealUI embeds. Auto only follows RealUI itself so an
  -- ElvUI player who also has Aurora loaded is not switched to the RealUI palette.
  if loaded("nibRealUI") or loaded("RealUI") or loaded("RealUI_Skins") then
    return "REALUI"
  end
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

function LS:GetGW2()
  if not loaded("GW2_UI") then return nil end
  local gw = _G.GW2_ADDON
  return type(gw) == "table" and gw or nil
end

function LS:GetW2UI()
  if not loaded("W2UI") then return nil end
  local w2 = _G.W2UI
  return type(w2) == "table" and w2 or nil
end

function LS:GetAurora()
  if not (loaded("Aurora") or loaded("RealUI_Skins") or loaded("nibRealUI") or loaded("RealUI")) then
    return nil
  end
  local aurora = _G.Aurora
  if type(aurora) == "table" and type(aurora.Color) == "table" then return aurora end
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
  local function clamp(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
  end
  return {
    clamp(rgba[1] * factor),
    clamp(rgba[2] * factor),
    clamp(rgba[3] * factor),
    alpha or rgba[4] or 1,
  }
end

local function luminance(rgba)
  if type(rgba) ~= "table" then return 0 end
  local r, g, b = rgba[1] or 0, rgba[2] or 0, rgba[3] or 0
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function parseHexColor(str)
  if type(str) ~= "string" then return end
  local body = str:match("|c(%x+)") or str:match("^#?(%x+)$")
  if not body or #body < 6 then return end
  local hex = body:sub(-6)
  return {
    tonumber(hex:sub(1, 2), 16) / 255,
    tonumber(hex:sub(3, 4), 16) / 255,
    tonumber(hex:sub(5, 6), 16) / 255,
    1,
  }
end

local function objectColor(value, fallback)
  if type(value) == "table" and value.GetRGBA then
    local ok, r, g, b, a = pcall(value.GetRGBA, value)
    if ok and r then return { r, g, b, a or 1 } end
  end
  return color(value, fallback)
end

-- Builds a palette out of ElvUI's own backdrop, border, texture and font settings.
function LS:BuildElvUIPalette()
  local E = self:GetElvUI()
  if not E or type(E.media) ~= "table" then return nil end
  local base = self.palettes.ELVUI
  local backdrop = color(E.media.backdropcolor, base.bg)
  local fade = color(E.media.backdropfadecolor, backdrop)
  local border = color(E.media.bordercolor, base.border)
  -- ElvUI does not ship a visible border by default (near-black on near-black).
  -- Keep a border the user actually set; otherwise use Lodestar's grey.
  if luminance(border) < 0.22 then
    border = { base.border[1], base.border[2], base.border[3], base.border[4] or 1 }
  end
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

function LS:BuildGW2Palette()
  local GW = self:GetGW2()
  if not GW then return nil end
  local base = self.palettes.GW2
  local accent = parseHexColor(GW.Gw2Color) or color(GW.Colors and (GW.Colors.GOLD or GW.Colors.accent), base.accent)
  local bg = color(GW.Colors and (GW.Colors.BACKGROUND or GW.Colors.bg), base.bg)
  local border = color(GW.Colors and (GW.Colors.BORDER or GW.Colors.border), base.border)
  if luminance(border) < 0.22 then
    border = { base.border[1], base.border[2], base.border[3], base.border[4] or 1 }
  end
  local font
  if GW.Libs and GW.Libs.LSM and GW.Libs.LSM.Fetch then
    local ok, fetched = pcall(GW.Libs.LSM.Fetch, GW.Libs.LSM, "font", "GW2_UI")
    if ok then font = fetched end
  end
  self.skin = {
    font = font or "Interface\\AddOns\\GW2_UI\\fonts\\menomonia.ttf",
    texture = "Interface/Buttons/WHITE8X8",
    fontSize = 12,
  }
  return {
    bg = { bg[1], bg[2], bg[3], 0.98 },
    panel = shade(bg, 1.4, 0.95),
    card = shade(bg, 1.8, 0.95),
    border = border,
    accent = accent or base.accent,
    text = base.text,
    warn = base.warn,
    muted = base.muted,
  }
end

function LS:BuildW2UIPalette()
  local W2 = self:GetW2UI()
  if not W2 or type(W2.GetThemeToken) ~= "function" then return nil end
  local base = self.palettes.W2UI
  local function token(key, fallback)
    return color(W2:GetThemeToken(key), fallback)
  end
  local bg = token("background", base.bg)
  local panel = token("backgroundAlt", base.panel)
  local border = token("border", base.border)
  if luminance(border) < 0.22 then
    border = { base.border[1], base.border[2], base.border[3], base.border[4] or 1 }
  end
  self.skin = {
    texture = "Interface/Buttons/WHITE8X8",
    fontSize = 12,
  }
  return {
    bg = { bg[1], bg[2], bg[3], 0.98 },
    panel = { panel[1], panel[2], panel[3], 0.95 },
    card = shade(panel, 1.25, 0.95),
    border = border,
    accent = token("textAccent", base.accent),
    text = token("text", base.text),
    warn = token("danger", base.warn),
    muted = token("muted", base.muted),
  }
end

function LS:BuildRealUIPalette()
  local A = self:GetAurora()
  if not A then return nil end
  local base = self.palettes.REALUI
  local C = A.Color
  local bg = objectColor(C.panelBg or C.frame, base.bg)
  local border = objectColor(C.border or C.button, base.border)
  local accent = objectColor(C.highlight, base.accent)
  if luminance(border) < 0.22 then
    border = { base.border[1], base.border[2], base.border[3], base.border[4] or 1 }
  end
  self.skin = {
    texture = "Interface/Buttons/WHITE8X8",
    fontSize = 12,
  }
  return {
    bg = { bg[1], bg[2], bg[3], 0.98 },
    panel = shade(bg, 1.4, 0.95),
    card = shade(bg, 1.8, 0.95),
    border = border,
    accent = accent or base.accent,
    text = base.text,
    warn = objectColor(C.red, base.warn),
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
  elseif name == "GW2" then
    palette = self:BuildGW2Palette()
    native = palette ~= nil
  elseif name == "W2UI" then
    palette = self:BuildW2UIPalette()
    native = palette ~= nil
  elseif name == "REALUI" then
    palette = self:BuildRealUIPalette()
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
  print("Lodestar themes: auto, blizzard, elvui, ellesmere, gw2, w2ui, realui, minimal")
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
