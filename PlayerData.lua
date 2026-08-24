local _,LS=...
LS.profile={professions={},reputations={},mounts={},transmog={}}
local function Safe(fn,...)
 if type(fn)~="function" then return nil end
 local ok,a,b,c,d,e=pcall(fn,...); if ok then return a,b,c,d,e end
end
function LS:ScanProfessions()
 local out={}
 local ids=Safe(C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines)
 if type(ids)=="table" then
  local seen={}
  for _,id in ipairs(ids) do
   local info=Safe(C_TradeSkillUI.GetProfessionInfoBySkillLineID,id)
   if info and info.isPrimaryProfession and info.professionName and not seen[info.professionName] then
    seen[info.professionName]=true
    table.insert(out,{name=info.professionName,skill=info.skillLevel or 0,max=info.maxSkillLevel or 0})
   end
  end
 end
 self.profile.professions=out
end
function LS:ScanReputations()
 local out={}
 local count=Safe(C_Reputation and C_Reputation.GetNumFactions) or Safe(GetNumFactions) or 0
 for i=1,count do
  local data=Safe(C_Reputation and C_Reputation.GetFactionDataByIndex,i)
  if data and not data.isHeader and data.name then
   local min=data.currentReactionThreshold or 0; local max=data.nextReactionThreshold or min
   local value=data.currentStanding or min
   table.insert(out,{name=data.name,id=data.factionID,progress=math.max(0,value-min),total=math.max(0,max-min),standing=data.reaction})
  end
 end
 self.profile.reputations=out
end
function LS:ScanCollections()
 local total,collected=Safe(C_MountJournal and C_MountJournal.GetNumMounts)
 self.profile.mounts={total=total or 0,collected=collected or 0}
 local got,all=0,0
 if C_TransmogCollection then
  for category=1,29 do
   local appearances=Safe(C_TransmogCollection.GetCategoryAppearances,category)
   if type(appearances)=="table" then
    for _,a in ipairs(appearances) do all=all+1; if a.isCollected then got=got+1 end end
   end
  end
 end
 self.profile.transmog={collected=got,total=all}
end
function LS:ScanPlayer() self:ScanProfessions(); self:ScanReputations(); self:ScanCollections() end
function LS:GetProfessionSummary()
 if #self.profile.professions==0 then return "Professions: none detected yet" end
 local t={}; for _,p in ipairs(self.profile.professions) do table.insert(t,p.name.." "..p.skill.."/"..p.max) end
 return "Professions: "..table.concat(t,", ")
end
function LS:GetFaction(name)
 for _,f in ipairs(self.profile.reputations) do if f.name==name then return f end end
end
