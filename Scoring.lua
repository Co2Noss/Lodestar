local _,LS=...
function LS:GetRecommendations()
 local ranked={}
 for _,a in ipairs(self.activities) do
  if not self.db.dismissed[a.id] then
   local score=0
   for goal,on in pairs(self.db.goals) do if on then score=score+(a.tags[goal] or 0) end end
   if a.needsProfession and #self.profile.professions==0 then score=0 end
   local faction=a.faction and self:GetFaction(a.faction)
   if faction and faction.total>0 and faction.progress>=faction.total then score=math.max(0,score-8) end
   if score>0 then table.insert(ranked,{activity=a,score=score,faction=faction}) end
  end
 end
 table.sort(ranked,function(a,b) return a.score==b.score and a.activity.effort<b.activity.effort or a.score>b.score end)
 return ranked
end
