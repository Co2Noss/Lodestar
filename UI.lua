local _,LS=...
local goals={{"ENDGAME","End game"},{"CRAFTING","Crafting"},{"TRANSMOG","Transmog"},{"MOUNTS","Mounts"},{"REPUTATION","Reputation"},{"QUESTING","Questing"}}
function LS:CreateUI()
 local f=CreateFrame("Frame","LodestarFrame",UIParent,"BasicFrameTemplateWithInset"); self.frame=f
 f:SetSize(650,540); f:SetPoint("CENTER"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing); f:Hide(); f.TitleText:SetText("Lodestar — What matters to you today?")
 for i,e in ipairs(goals) do
  local c=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); local row=math.floor((i-1)/3); local col=(i-1)%3
  c:SetPoint("TOPLEFT",20+col*200,-42-row*30); c.Text:SetText(e[2]); c:SetChecked(self.db.goals[e[1]])
  c:SetScript("OnClick",function(b) self.db.goals[e[1]]=b:GetChecked() and true or false; self:Refresh() end)
 end
 self.profileText=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.profileText:SetPoint("TOPLEFT",20,-112); self.profileText:SetWidth(610); self.profileText:SetJustifyH("LEFT")
 local h=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); h:SetPoint("TOPLEFT",20,-158); h:SetText("Your next three priorities")
 self.rows={}
 for i=1,3 do
  local r=CreateFrame("Frame",nil,f,"BackdropTemplate"); r:SetSize(600,88); r:SetPoint("TOPLEFT",25,-190-(i-1)*96); r:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/Tooltips/UI-Tooltip-Border",edgeSize=12}); r:SetBackdropColor(.04,.06,.09,.92)
  r.n=r:CreateFontString(nil,"OVERLAY","GameFontNormalHuge"); r.n:SetPoint("LEFT",12,0); r.n:SetText(i)
  r.t=r:CreateFontString(nil,"OVERLAY","GameFontNormal"); r.t:SetPoint("TOPLEFT",48,-12); r.t:SetWidth(530); r.t:SetJustifyH("LEFT")
  r.s=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); r.s:SetPoint("TOPLEFT",48,-36); r.s:SetWidth(530); r.s:SetJustifyH("LEFT"); r.s:SetJustifyV("TOP")
  self.rows[i]=r
 end
 local foot=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); foot:SetPoint("BOTTOMLEFT",20,13); foot:SetText("0.3 prototype • /ls toggles • /ls theme auto")
 self.themeLabel=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); self.themeLabel:SetPoint("BOTTOMRIGHT",-20,13); self.themeLabel:SetText("Theme: AUTO")
 self:ApplyTheme()
end
function LS:Refresh()
 self:ApplyTheme()
 self:ScanPlayer()
 local m=self.profile.mounts; local t=self.profile.transmog
 self.profileText:SetText(self:GetProfessionSummary().."\nCollections: "..(m.collected or 0).."/"..(m.total or 0).." mounts • "..(t.collected or 0).."/"..(t.total or 0).." usable appearances")
 local list=self:GetRecommendations()
 for i,r in ipairs(self.rows) do local x=list[i]; if x then r:Show(); local extra=""; if x.faction and x.faction.total>0 then extra=" • Rep "..x.faction.progress.."/"..x.faction.total end; r.t:SetText(x.activity.title.."  |cff7dd3c7["..x.score.."]|r"..extra); r.s:SetText(x.activity.summary) else r:Hide() end end
end
function LS:Toggle() if self.frame:IsShown() then self.frame:Hide() else self:Refresh(); self.frame:Show() end end
