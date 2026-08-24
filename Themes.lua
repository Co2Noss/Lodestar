local _, LS = ...

LS.palettes = {
  BLIZZARD = {
    bg = { .035, .045, .06, .98 }, panel = { .055, .07, .09, .98 }, card = { .07, .085, .105, .98 },
    border = { .22, .28, .34, 1 }, accent = { .95, .72, .22, 1 }, text = { .92, .94, .96, 1 },
    warn = { .93, .38, .36, 1 }, muted = { .58, .62, .68, 1 },
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

function LS:ResolvePalette()
  local name = self:CurrentTheme()
  if name == "ELVUI" then
    local palette = self:BuildElvUIPalette()
    if palette then
      return palette, name, true
    end
  end
  self.skin = nil
  return self.palettes[name], name, false
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
  print("|cff59d8c9Lodestar|r theme: " .. self:CurrentTheme() .. (self.skin and " (ElvUI media)" or ""))
end

function LS:PrintThemes()
  print("Lodestar themes: auto, blizzard, elvui, ellesmere, minimal")
end

function LS:ApplyTheme()
  if not self.frame then return end
  local palette, name, native = self:ResolvePalette()
  self.colors = palette
  self.themeName = name
  self.themeNative = native

  local texture = self:ThemeTexture()
  for _, frame in ipairs({ self.frame, self.header, self.sidebar }) do
    if frame and frame.SetBackdrop then
      frame:SetBackdrop({ bgFile = texture, edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
    end
  end

  self.frame:SetBackdropColor(unpack(palette.bg))
  self.frame:SetBackdropBorderColor(unpack(palette.border))
  self.sidebar:SetBackdropColor(unpack(palette.panel))
  self.sidebar:SetBackdropBorderColor(unpack(palette.border))
  self.header:SetBackdropColor(unpack(palette.panel))
  self.header:SetBackdropBorderColor(unpack(palette.border))
  self.title:SetTextColor(unpack(palette.accent))

  if self.themeText then
    self.themeText:SetText("Theme: " .. name .. (native and " (native)" or ""))
  end
  if self.closeButton then
    self.closeButton:SetBackdropColor(unpack(palette.card))
    self.closeButton:SetBackdropBorderColor(unpack(palette.border))
    -- ElvUI's backdrop is nearly black, so the glyph needs the theme's text color
    -- rather than the font object's default.
    self.closeButton.text:SetFont(self:ThemeFont(), 20, "")
    self.closeButton.text:SetTextColor(unpack(palette.text))
  end
  if self.UpdateCompact then self:UpdateCompact() end
  for key, nav in pairs(self.nav or {}) do
    local active = key == self.page
    nav:SetBackdropColor(unpack(palette.card))
    nav:SetBackdropBorderColor(unpack(active and palette.accent or palette.border))
    nav.text:SetTextColor(unpack(active and palette.accent or palette.text))
  end
end
