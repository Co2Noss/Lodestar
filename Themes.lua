local _,LS=...

LS.themeOrder={"AUTO","BLIZZARD","ELVUI","ELLESMERE","MINIMAL"}

local function IsLoaded(name)
 if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
 if IsAddOnLoaded then return IsAddOnLoaded(name) end
 return false
end

function LS:DetectTheme()
 -- EllesmereUI is modular; its Blizzard-skin module is the strongest signal.
 if IsLoaded("EllesmereUIBlizzardSkin") or IsLoaded("EllesmereUI") then return "ELLESMERE" end
 if IsLoaded("ElvUI") and _G.ElvUI then return "ELVUI" end
 return "BLIZZARD"
end

function LS:GetActiveTheme()
 local wanted=(self.db and self.db.theme) or "AUTO"
 return wanted=="AUTO" and self:DetectTheme() or wanted
end

function LS:GetThemePalette(theme)
 local palettes={
  BLIZZARD={bg={.035,.05,.075,.96},border={.35,.29,.18,1},accent={1,.82,.28,1},muted={.72,.72,.72,1}},
  ELLESMERE={bg={.025,.028,.035,.97},border={.18,.20,.24,1},accent={.32,.82,.72,1},muted={.68,.72,.76,1}},
  MINIMAL={bg={.025,.025,.028,.96},border={.12,.12,.14,1},accent={.49,.83,.78,1},muted={.65,.65,.68,1}},
 }
 if theme=="ELVUI" and _G.ElvUI then
  local ok,E=pcall(unpack,_G.ElvUI)
  if ok and E then
   local bg=(E.media and E.media.backdropcolor) or {.06,.06,.06}
   local border=(E.media and E.media.bordercolor) or {.15,.15,.15}
   local r,g,b=E:ClassColor(E.myclass)
   return {bg={bg[1] or .06,bg[2] or .06,bg[3] or .06,.97},border={border[1] or .15,border[2] or .15,border[3] or .15,1},accent={r or .3,g or .8,b or .7,1},muted={.70,.70,.70,1},E=E}
  end
 end
 return palettes[theme] or palettes.BLIZZARD
end

local function Color(texture,c) texture:SetColorTexture(c[1],c[2],c[3],c[4] or 1) end

function LS:ApplyTheme()
 if not self.frame then return end
 local theme=self:GetActiveTheme(); local p=self:GetThemePalette(theme); local f=self.frame
 f.activeTheme=theme
 if f.NineSlice then f.NineSlice:Hide() end
 if f.Bg then f.Bg:Hide() end
 if f.TitleBg then f.TitleBg:Hide() end
 if not f.LodestarBackdrop then
  f.LodestarBackdrop=CreateFrame("Frame",nil,f,"BackdropTemplate")
  f.LodestarBackdrop:SetAllPoints(); f.LodestarBackdrop:SetFrameLevel(math.max(0,f:GetFrameLevel()-1))
  f.LodestarBackdrop:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8",edgeFile="Interface/Buttons/WHITE8X8",edgeSize=1})
 end
 f.LodestarBackdrop:SetBackdropColor(unpack(p.bg)); f.LodestarBackdrop:SetBackdropBorderColor(unpack(p.border)); f.LodestarBackdrop:Show()
 if f.TitleText then f.TitleText:SetTextColor(unpack(p.accent)) end
 for _,r in ipairs(self.rows or {}) do
  r:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8",edgeFile="Interface/Buttons/WHITE8X8",edgeSize=1})
  r:SetBackdropColor(p.bg[1]+.025,p.bg[2]+.025,p.bg[3]+.025,.94); r:SetBackdropBorderColor(unpack(p.border))
  r.n:SetTextColor(unpack(p.accent)); r.s:SetTextColor(unpack(p.muted))
 end
 if self.themeLabel then self.themeLabel:SetText("Theme: "..theme) end
end

function LS:SetThemePreference(choice)
 local valid=false
 for _,v in ipairs(self.themeOrder) do if v==choice then valid=true break end end
 if not valid then self:PrintThemeHelp(); return end
 self.db.theme=choice; self:ApplyTheme(); self:Refresh()
 print("|cff7dd3c7Lodestar|r theme set to "..choice..".")
end
function LS:PrintThemeHelp()
 print("|cff7dd3c7Lodestar themes:|r auto, blizzard, elvui, ellesmere, minimal")
 print("Use |cffffffff/ls theme auto|r or choose a named theme.")
end
