local _, LS = ...

-- Weekly and farmable mount drops, not a catalogue of every mount in the game. The list
-- follows the raid-and-dungeon circuit mount collectors actually run (see Wowhead's
-- Lord of the Reins guide). Collected mounts stay silent. A used weekly lockout stays
-- silent. An unused lockout for a mount you still need is the recommendation.
--
-- difficulty is the saved-instance difficulty ID when the drop is locked to one wing.
-- 3/4/5/6 are legacy 10N/25N/10H/25H. 14/15/16 are Normal/Heroic/Mythic. Omit it when
-- any difficulty of that instance is a chance.

LS.mountFarms = {
  -- Weekly raids
  {
    id = "invincible",
    mountID = 363,
    name = "Invincible",
    instance = "Icecrown Citadel",
    instanceID = 631,
    difficulty = 6,
    encounter = "Lich King",
    minutes = 25,
    why = "You do not have Invincible, and Icecrown Citadel 25 Heroic is still open this week.",
  },
  {
    id = "ashes",
    mountID = 183,
    name = "Ashes of Al'ar",
    instance = "Tempest Keep",
    instanceID = 550,
    encounter = "Kael'thas",
    minutes = 20,
    why = "You do not have Ashes of Al'ar, and Tempest Keep is still open this week.",
  },
  {
    id = "mimiron",
    mountID = 304,
    name = "Mimiron's Head",
    instance = "Ulduar",
    instanceID = 603,
    difficulty = 4,
    encounter = "Yogg-Saron",
    minutes = 35,
    why = "You do not have Mimiron's Head, and Ulduar 25-player is still open this week.",
  },
  {
    id = "fiery_warhorse",
    mountID = 168,
    name = "Fiery Warhorse",
    instance = "Karazhan",
    instanceID = 532,
    encounter = "Attumen",
    minutes = 15,
    why = "You do not have the Fiery Warhorse, and Karazhan is still open this week.",
  },
  {
    id = "onyxia",
    mountID = 349,
    name = "Onyxian Drake",
    instance = "Onyxia's Lair",
    instanceID = 249,
    encounter = "Onyxia",
    minutes = 10,
    why = "You do not have the Onyxian Drake, and Onyxia is still open this week.",
  },
  {
    id = "firehawk",
    mountID = 415,
    name = "Pureblood Fire Hawk",
    instance = "Firelands",
    instanceID = 720,
    encounter = "Ragnaros",
    minutes = 25,
    why = "You do not have the Pureblood Fire Hawk, and Firelands is still open this week.",
  },
  {
    id = "flametalon",
    mountID = 425,
    name = "Flametalon of Alysrazor",
    instance = "Firelands",
    instanceID = 720,
    encounter = "Alysrazor",
    minutes = 15,
    why = "You do not have Flametalon of Alysrazor, and Firelands is still open this week.",
  },
  {
    id = "experiment_12b",
    mountID = 445,
    name = "Experiment 12-B",
    instance = "Dragon Soul",
    instanceID = 967,
    encounter = "Deathwing",
    minutes = 25,
    why = "You do not have Experiment 12-B, and Dragon Soul is still open this week.",
  },
  {
    id = "lifebinder",
    mountID = 444,
    name = "Life-Binder's Handmaiden",
    instance = "Dragon Soul",
    instanceID = 967,
    difficulty = 6,
    encounter = "Deathwing",
    minutes = 25,
    why = "You do not have Life-Binder's Handmaiden, and Dragon Soul 25 Heroic is still open this week.",
  },
  {
    id = "blazing_drake",
    mountID = 442,
    name = "Blazing Drake",
    instance = "Dragon Soul",
    instanceID = 967,
    encounter = "Deathwing",
    minutes = 25,
    why = "You do not have the Blazing Drake, and Dragon Soul is still open this week.",
  },
  {
    id = "astral_serpent",
    mountID = 478,
    name = "Astral Cloud Serpent",
    instance = "Mogu'shan Vaults",
    instanceID = 1008,
    encounter = "Elegon",
    minutes = 20,
    why = "You do not have the Astral Cloud Serpent, and Mogu'shan Vaults is still open this week.",
  },
  {
    id = "horridon",
    mountID = 531,
    name = "Spawn of Horridon",
    instance = "Throne of Thunder",
    instanceID = 1098,
    encounter = "Horridon",
    minutes = 20,
    why = "You do not have Spawn of Horridon, and Throne of Thunder is still open this week.",
  },
  {
    id = "jikun",
    mountID = 543,
    name = "Clutch of Ji-Kun",
    instance = "Throne of Thunder",
    instanceID = 1098,
    encounter = "Ji-Kun",
    minutes = 20,
    why = "You do not have Clutch of Ji-Kun, and Throne of Thunder is still open this week.",
  },
  {
    id = "juggernaut",
    mountID = 559,
    name = "Kor'kron Juggernaut",
    instance = "Siege of Orgrimmar",
    instanceID = 1136,
    difficulty = 16,
    encounter = "Garrosh",
    minutes = 40,
    why = "You do not have the Kor'kron Juggernaut, and Mythic Siege of Orgrimmar is still open this week.",
  },
  {
    id = "ironhoof",
    mountID = 613,
    name = "Ironhoof Destroyer",
    instance = "Blackrock Foundry",
    instanceID = 1205,
    difficulty = 16,
    encounter = "Blackhand",
    minutes = 35,
    why = "You do not have the Ironhoof Destroyer, and Mythic Blackrock Foundry is still open this week.",
  },
  {
    id = "felsteel",
    mountID = 751,
    name = "Felsteel Annihilator",
    instance = "Hellfire Citadel",
    instanceID = 1448,
    difficulty = 16,
    encounter = "Archimonde",
    minutes = 40,
    why = "You do not have the Felsteel Annihilator, and Mythic Hellfire Citadel is still open this week.",
  },
  {
    id = "abyss_worm",
    mountID = 899,
    name = "Abyss Worm",
    instance = "Tomb of Sargeras",
    instanceID = 1676,
    encounter = "Sassz'ine",
    minutes = 25,
    why = "You do not have the Abyss Worm, and Tomb of Sargeras is still open this week.",
  },
  {
    id = "razzashi",
    mountID = 410,
    name = "Armored Razzashi Raptor",
    instance = "Zul'Gurub",
    instanceID = 859,
    encounter = "Mandokir",
    minutes = 15,
    why = "You do not have the Armored Razzashi Raptor, and Zul'Gurub is still open this week.",
  },
  {
    id = "zulian",
    mountID = 411,
    name = "Swift Zulian Panther",
    instance = "Zul'Gurub",
    instanceID = 859,
    encounter = "Kilnara",
    minutes = 15,
    why = "You do not have the Swift Zulian Panther, and Zul'Gurub is still open this week.",
  },
  -- World bosses, weekly
  {
    id = "heavenly_onyx",
    mountID = 473,
    name = "Heavenly Onyx Cloud Serpent",
    worldBoss = "Sha of Anger",
    minutes = 10,
    why = "You do not have the Heavenly Onyx Cloud Serpent, and Sha of Anger is still up this week.",
  },
  {
    id = "galleon",
    mountID = 515,
    name = "Son of Galleon",
    worldBoss = "Galleon",
    minutes = 10,
    why = "You do not have Son of Galleon, and Galleon is still up this week.",
  },
  {
    id = "nalak",
    mountID = 542,
    name = "Thundering Cobalt Cloud Serpent",
    worldBoss = "Nalak",
    minutes = 10,
    why = "You do not have the Thundering Cobalt Cloud Serpent, and Nalak is still up this week.",
  },
  {
    id = "oondasta",
    mountID = 533,
    name = "Cobalt Primordial Direhorn",
    worldBoss = "Oondasta",
    minutes = 10,
    why = "You do not have the Cobalt Primordial Direhorn, and Oondasta is still up this week.",
  },
  {
    id = "rukhmar",
    mountID = 634,
    name = "Solar Spirehawk",
    worldBoss = "Rukhmar",
    minutes = 10,
    why = "You do not have the Solar Spirehawk, and Rukhmar is still up this week.",
  },
  -- Dungeons with no weekly lockout: farmable any time, never urgent
  {
    id = "raven_lord",
    mountID = 185,
    name = "Raven Lord",
    instance = "Sethekk Halls",
    encounter = "Anzu",
    lockout = false,
    minutes = 10,
    why = "You do not have the Raven Lord. Heroic Sethekk Halls can be run as often as you like.",
  },
  {
    id = "hawkstrider",
    mountID = 213,
    name = "Swift White Hawkstrider",
    instance = "Magisters' Terrace",
    encounter = "Kael'thas",
    lockout = false,
    minutes = 10,
    why = "You do not have the Swift White Hawkstrider. Heroic Magisters' Terrace can be run as often as you like.",
  },
  {
    id = "blue_proto",
    mountID = 264,
    name = "Blue Proto-Drake",
    instance = "Utgarde Pinnacle",
    encounter = "Skadi",
    lockout = false,
    minutes = 12,
    why = "You do not have the Blue Proto-Drake. Heroic Utgarde Pinnacle can be run as often as you like.",
  },
  {
    id = "rivendare",
    mountID = 69,
    name = "Rivendare's Deathcharger",
    instance = "Stratholme",
    encounter = "Rivendare",
    lockout = false,
    minutes = 12,
    why = "You do not have Rivendare's Deathcharger. Stratholme can be run as often as you like.",
  },
}

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function Contains(haystack, needle)
  if type(haystack) ~= "string" or type(needle) ~= "string" or needle == "" then return false end
  return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

function LS:HasMount(mountID)
  if not mountID then return false end
  local owned = self.profile and self.profile.mounts and self.profile.mounts.owned
  if owned and owned[mountID] then return true end
  if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then return false end
  local name, _, _, _, _, _, _, _, _, hidden, collected = C_MountJournal.GetMountInfoByID(mountID)
  if hidden and not collected then return false end
  return collected == true, name
end

function LS:ScanMounts()
  local owned, collected = {}, 0
  local ids = C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountIDs()
  if type(ids) == "table" then
    for _, id in ipairs(ids) do
      local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(id)
      if isCollected then
        owned[id] = true
        collected = collected + 1
      end
    end
  end
  local total = Safe(C_MountJournal and C_MountJournal.GetNumMounts)
  if self.profile then
    self.profile.mounts = {
      total = total or collected,
      collected = collected,
      owned = owned,
    }
  end
end

local function InstanceMatches(farm, name, difficulty, instanceID)
  if farm.instanceID then
    if instanceID then
      if instanceID ~= farm.instanceID then return false end
    elseif not Contains(name, farm.instance) then
      return false
    end
  elseif not Contains(name, farm.instance) then
    return false
  end
  if farm.difficulty and difficulty ~= farm.difficulty then return false end
  return true
end

-- "used" means this week's drop chance is spent. "open" means it is still a roll.
-- "in_progress" means the lockout exists but the boss is still alive, so go finish it.
function LS:MountLockout(farm)
  if farm.lockout == false then return "open" end
  if farm.worldBoss then
    local n = Safe(GetNumSavedWorldBosses) or 0
    for i = 1, n do
      local name = Safe(GetSavedWorldBossInfo, i)
      if Contains(name, farm.worldBoss) then return "used" end
    end
    return "open"
  end

  local n = Safe(GetNumSavedInstances) or 0
  local inProgress = false
  for i = 1, n do
    if type(GetSavedInstanceInfo) ~= "function" then break end
    local name, _, _, difficulty, locked, _, _, _, _, _, numEncounters, encounterProgress, _, instanceID =
      GetSavedInstanceInfo(i)
    if InstanceMatches(farm, name, difficulty, instanceID) then
      local killed
      if farm.encounter and (numEncounters or 0) > 0 and GetSavedInstanceEncounterInfo then
        for j = 1, numEncounters do
          local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, j)
          if Contains(bossName, farm.encounter) then
            killed = isKilled and true or false
            break
          end
        end
      end
      if killed == nil and (numEncounters or 0) > 0 then
        killed = (encounterProgress or 0) >= numEncounters
      end
      if killed then
        return "used"
      end
      if locked or killed == false then
        inProgress = true
      end
    end
  end
  if inProgress then return "in_progress" end
  return "open"
end

function LS:GetMountRecommendations()
  local out = {}
  if self.ScanMounts then self:ScanMounts() end
  for _, farm in ipairs(self.mountFarms) do
    local collected, journalName = self:HasMount(farm.mountID)
    if not collected then
      -- hideOnChar mounts return false from HasMount without being a farm we should show.
      local hidden
      if C_MountJournal and C_MountJournal.GetMountInfoByID then
        hidden = select(10, C_MountJournal.GetMountInfoByID(farm.mountID))
      end
      if not hidden then
        local lockout = self:MountLockout(farm)
        if lockout ~= "used" then
          local weekly = farm.lockout ~= false
          local title
          if lockout == "in_progress" then
            title = string.format("Finish %s for %s", farm.instance or farm.worldBoss, farm.name)
          elseif farm.worldBoss then
            title = string.format("Kill %s for %s", farm.worldBoss, farm.name)
          else
            title = string.format("Farm %s from %s", farm.name, farm.instance)
          end
          local why = farm.why
          if lockout == "in_progress" then
            why = string.format("The lockout is open and %s is still alive. The roll is this week or never.",
              farm.encounter or farm.worldBoss or "the boss")
          end
          table.insert(out, {
            id = "mount_" .. farm.id,
            title = title,
            minutes = farm.minutes or 20,
            score = weekly and (lockout == "in_progress" and 34 or 32) or 16,
            why = why,
            category = "Mounts",
            tags = { MOUNTS = 12, SOLO = weekly and 3 or 5 },
            urgency = weekly and "HIGH" or "LOW",
            priority = weekly and "WEEKLY" or "OPEN",
            detail = {
              source = farm.worldBoss
                or string.format("%s%s — %s", farm.instance,
                  farm.difficulty == 6 and " (25 Heroic)"
                  or farm.difficulty == 16 and " (Mythic)"
                  or farm.difficulty == 4 and " (25-player)"
                  or "",
                  farm.encounter or "boss"),
              current = journalName and (journalName .. " not collected") or "Not collected",
              potential = farm.name,
              matters = why,
            },
          })
        end
      end
    end
  end
  return out
end
