local _,LS=...
-- Curated 12.1 starter catalog. Keep reward claims in this file reviewable and patch-versioned.
LS.activities={
 {id="zuljarra",title="Review Zul'jarra's Forces rewards",summary="The current 12.1 Renown track includes gear, profession assets, cosmetics, and unlocks.",tags={ENDGAME=5,CRAFTING=7,TRANSMOG=6,MOUNTS=7,REPUTATION=10},effort=2,faction="Zul'jarra's Forces"},
 {id="profession",title="Work on a relevant profession unlock",summary="Uses your detected primary professions to keep crafting advice personal.",tags={CRAFTING=10,REPUTATION=4},effort=2,needsProfession=true},
 {id="mount",title="Choose one uncollected mount target",summary="Your collection progress is shown below; source ranking is the next data milestone.",tags={MOUNTS=10},effort=1},
 {id="transmog",title="Choose one missing appearance category",summary="Uses class-filtered appearance collection data instead of a generic checklist.",tags={TRANSMOG=10},effort=1},
 {id="weekly",title="Advance one current weekly objective",summary="A focused end-game option when character power is your priority.",tags={ENDGAME=10},effort=2},
 {id="quest",title="Continue one reward-bearing quest chain",summary="Focus on a chosen chain; leave unrelated map clutter alone.",tags={QUESTING=10,REPUTATION=3},effort=2},
}
