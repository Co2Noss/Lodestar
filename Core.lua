local addonName, LS = ...
_G.Lodestar = LS
LS.defaults = { goals={ENDGAME=true,CRAFTING=false,TRANSMOG=false,MOUNTS=false,REPUTATION=false,QUESTING=false}, dismissed={}, theme="AUTO" }
local function Merge(src,dst)
 dst=type(dst)=="table" and dst or {}
 for k,v in pairs(src) do if type(v)=="table" then dst[k]=Merge(v,dst[k]) elseif dst[k]==nil then dst[k]=v end end
 return dst
end
local f=CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED"); f:RegisterEvent("PLAYER_ENTERING_WORLD"); f:RegisterEvent("SKILL_LINES_CHANGED"); f:RegisterEvent("UPDATE_FACTION")
f:SetScript("OnEvent",function(_,event,arg)
 if event=="ADDON_LOADED" and arg==addonName then
  LodestarDB=Merge(LS.defaults,LodestarDB); LS.db=LodestarDB; LS:CreateUI()
  print("|cff7dd3c7Lodestar|r loaded. Type |cffffffff/ls|r.")
 elseif LS.db then LS:ScanPlayer(); if LS.frame and LS.frame:IsShown() then LS:Refresh() end end
end)
SLASH_LODESTAR1="/ls"; SLASH_LODESTAR2="/lodestar"
SlashCmdList.LODESTAR=function(msg)
 msg=(msg or ""):lower()
 if msg=="reset" then
  LodestarDB=nil; ReloadUI()
 elseif msg:match("^theme") then
  local choice=msg:match("^theme%s+(%S+)")
  if choice then LS:SetThemePreference(choice:upper()) else LS:PrintThemeHelp() end
 else LS:Toggle() end
end
