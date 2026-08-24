local _, LS = ...

-- Profession knowledge sources for Midnight and The War Within.
--
-- Quest and item IDs are game facts, and these were cross-checked against the
-- WeeklyKnowledge addon by Dennis Ras, which maintains the community data set:
--   https://github.com/DennisRas/WeeklyKnowledge
--
-- Keys are profession skill line variant IDs, the same values
-- C_TradeSkillUI.GetAllProfessionTradeSkillLines returns.
--
-- Each objective is a set of quests worth `points` knowledge. `limit` caps how many
-- of those quests can count, which covers trainer quests that offer several options
-- but only reward one. TREATISE, WEEKLY and GATHERING reset weekly; TREASURE is once
-- per character.
LS.knowledgeSources = {
  -- Midnight Alchemy
  [2906] = {
    profession = "Alchemy",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95127 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 93690 }, points = 1 },
      { kind = "TREASURE", label = "Aged Cruor", quests = { 93529 }, points = 1 },
      { kind = "TREASURE", label = "Lightbloomed Spore Sample", quests = { 93528 }, points = 1 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- Midnight Blacksmithing
  [2907] = {
    profession = "Blacksmithing",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95128 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 93691 }, points = 2 },
      { kind = "TREASURE", label = "Infused Quenching Oil", quests = { 93531 }, points = 2 },
      { kind = "TREASURE", label = "Thalassian Whestone", quests = { 93530 }, points = 2 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- Midnight Enchanting
  [2909] = {
    profession = "Enchanting",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95129 }, points = 1 },
      { kind = "WEEKLY", label = "Trainer quest", quests = { 93697, 93698, 93699 }, points = 3, limit = 1 },
      { kind = "GATHERING", label = "Disenchanting (rare drop)", quests = { 95053 }, points = 4 },
      { kind = "GATHERING", label = "Disenchanting drops", quests = { 95048, 95049, 95050, 95051, 95052 }, points = 1 },
      { kind = "TREASURE", label = "Lost Thalassian Vellum", quests = { 93533 }, points = 2 },
      { kind = "TREASURE", label = "Voidstorm Ashes", quests = { 93532 }, points = 2 },
    },
    catchUp = {
      hint = "These are randomly looted from disenchanting items once the weekly objectives below are completed.",
      requires = {
        { label = "Treasure", quests = { 93532, 93533 }, match = "all" },
        { label = "Disenchanting", quests = { 95048, 95049, 95050, 95051, 95052, 95053 }, match = "all" },
        { label = "Trainer Quest", quests = { 93699, 93698 }, match = "any" },
      },
    },
  },
  -- Midnight Engineering
  [2910] = {
    profession = "Engineering",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95138 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 93692 }, points = 1 },
      { kind = "TREASURE", label = "Dance Gear", quests = { 93534 }, points = 1 },
      { kind = "TREASURE", label = "Dawn Capacitor", quests = { 93535 }, points = 1 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- Midnight Herbalism
  [2912] = {
    profession = "Herbalism",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95130 }, points = 1 },
      { kind = "WEEKLY", label = "Trainer quest", quests = { 93700, 93701, 93702, 93703, 93704 }, points = 3, limit = 1 },
      { kind = "GATHERING", label = "Herb gathering (rare drop)", quests = { 81430 }, points = 4 },
      { kind = "GATHERING", label = "Herb gathering drops", quests = { 81425, 81426, 81427, 81428, 81429 }, points = 1 },
    },
    catchUp = {
      hint = "These are randomly looted from herbs around the world once the weekly objectives below are completed.",
      requires = {
        { label = "Trainer Quest", quests = { 93704, 93703, 93702, 93701, 93700 }, match = "any" },
        { label = "Gathering", quests = { 81425, 81426, 81427, 81428, 81429, 81430 }, match = "all" },
      },
    },
  },
  -- Midnight Inscription
  [2913] = {
    profession = "Inscription",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95131 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 93693 }, points = 4 },
      { kind = "TREASURE", label = "Brilliant Phoenix Ink", quests = { 93536 }, points = 2 },
      { kind = "TREASURE", label = "Loa-Blessed Rune", quests = { 93537 }, points = 2 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- Midnight Jewelcrafting
  [2914] = {
    profession = "Jewelcrafting",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95133 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 93694 }, points = 3 },
      { kind = "TREASURE", label = "Harandar Stone Sample", quests = { 93539 }, points = 2 },
      { kind = "TREASURE", label = "Void-Touched Eversong Diamond Fragments", quests = { 93538 }, points = 2 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- Midnight Leatherworking
  [2915] = {
    profession = "Leatherworking",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95134 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 93695 }, points = 2 },
      { kind = "TREASURE", label = "Amani Tanning Oil", quests = { 93540 }, points = 2 },
      { kind = "TREASURE", label = "Thalassian Mana Oil", quests = { 93541 }, points = 2 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- Midnight Mining
  [2916] = {
    profession = "Mining",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95135 }, points = 1 },
      { kind = "WEEKLY", label = "Trainer quest", quests = { 93705, 93706, 93707, 93708, 93709 }, points = 3, limit = 1 },
      { kind = "GATHERING", label = "Mining (rare drop)", quests = { 88678 }, points = 3 },
      { kind = "GATHERING", label = "Mining drops", quests = { 88673, 88674, 88675, 88676, 88677 }, points = 1 },
    },
    catchUp = {
      hint = "These are randomly looted from mining nodes around the world once the weekly objectives below are completed.",
      requires = {
        { label = "Trainer Quest", quests = { 93709, 93708, 93707, 93706, 93705 }, match = "any" },
        { label = "Gathering", quests = { 88673, 88674, 88675, 88676, 88677, 88678 }, match = "all" },
      },
    },
  },
  -- Midnight Skinning
  [2917] = {
    profession = "Skinning",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95136 }, points = 1 },
      { kind = "WEEKLY", label = "Trainer quest", quests = { 93710, 93711, 93712, 93713, 93714 }, points = 3, limit = 1 },
      { kind = "GATHERING", label = "Skinning (rare drop)", quests = { 88529 }, points = 3 },
      { kind = "GATHERING", label = "Skinning drops", quests = { 88534, 88549, 88537, 88536, 88530 }, points = 1 },
    },
    catchUp = {
      hint = "These are randomly looted from skinning around the world once the weekly objectives below are completed.",
      requires = {
        { label = "Trainer Quest", quests = { 93714, 93713, 93712, 93711, 93710 }, match = "any" },
        { label = "Gathering", quests = { 88534, 88549, 88537, 88536, 88530, 88529 }, match = "all" },
      },
    },
  },
  -- Midnight Tailoring
  [2918] = {
    profession = "Tailoring",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95137 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 93696 }, points = 2 },
      { kind = "TREASURE", label = "Embroidered Memento", quests = { 93542 }, points = 2 },
      { kind = "TREASURE", label = "Finely Woven Lynx Collar", quests = { 93543 }, points = 2 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- The War Within Alchemy
  [2871] = {
    profession = "Alchemy",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83725 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 84133 }, points = 2 },
      { kind = "TREASURE", label = "Alchemical Sediment", quests = { 83253 }, points = 2 },
      { kind = "TREASURE", label = "Deepstone Crucible", quests = { 83255 }, points = 2 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- The War Within Blacksmithing
  [2872] = {
    profession = "Blacksmithing",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83726 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 84127 }, points = 2 },
      { kind = "TREASURE", label = "Coreway Billet", quests = { 83257 }, points = 1 },
      { kind = "TREASURE", label = "Dense Bladestone", quests = { 83256 }, points = 1 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- The War Within Enchanting
  [2874] = {
    profession = "Enchanting",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83727 }, points = 1 },
      { kind = "WEEKLY", label = "Trainer quest", quests = { 84084, 84085, 84086 }, points = 3, limit = 1 },
      { kind = "GATHERING", label = "Disenchanting (rare drop)", quests = { 84295 }, points = 4 },
      { kind = "GATHERING", label = "Disenchanting drops", quests = { 84290, 84291, 84292, 84293, 84294 }, points = 1 },
      { kind = "TREASURE", label = "Crystalline Repository", quests = { 83259 }, points = 1 },
      { kind = "TREASURE", label = "Powdered Fulgurance", quests = { 83258 }, points = 1 },
    },
    catchUp = {
      hint = "These are randomly looted from disenchanting items once the weekly objectives below are completed.",
      requires = {
        { label = "Treasure", quests = { 83258, 83259 }, match = "all" },
        { label = "Disenchanting", quests = { 84290, 84291, 84292, 84293, 84294, 84295 }, match = "all" },
        { label = "Trainer Quest", quests = { 84084, 84085, 84086 }, match = "any" },
      },
    },
  },
  -- The War Within Engineering
  [2875] = {
    profession = "Engineering",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83728 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 84128 }, points = 1 },
      { kind = "TREASURE", label = "Earthen Induction Coil", quests = { 83261 }, points = 1 },
      { kind = "TREASURE", label = "Rust-Locked Mechanism", quests = { 83260 }, points = 1 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- The War Within Herbalism
  [2877] = {
    profession = "Herbalism",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83729 }, points = 1 },
      { kind = "WEEKLY", label = "Trainer quest", quests = { 82916, 82958, 82962, 82965, 82970 }, points = 3, limit = 1 },
      { kind = "GATHERING", label = "Herb gathering (rare drop)", quests = { 81421 }, points = 4 },
      { kind = "GATHERING", label = "Herb gathering drops", quests = { 81416, 81417, 81418, 81419, 81420 }, points = 1 },
    },
    catchUp = {
      hint = "These are randomly looted from herbs around the world once the weekly objectives below are completed.",
      requires = {
        { label = "Trainer Quest", quests = { 82970, 82958, 82965, 82916, 82962 }, match = "any" },
        { label = "Gathering", quests = { 81416, 81417, 81418, 81419, 81420, 81421 }, match = "all" },
      },
    },
  },
  -- The War Within Inscription
  [2878] = {
    profession = "Inscription",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83730 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 84129 }, points = 2 },
      { kind = "TREASURE", label = "Striated Inkstone", quests = { 83264 }, points = 2 },
      { kind = "TREASURE", label = "Wax-Sealed Records", quests = { 83262 }, points = 2 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- The War Within Jewelcrafting
  [2879] = {
    profession = "Jewelcrafting",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83731 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 84130 }, points = 2 },
      { kind = "TREASURE", label = "Deepstone Fragment", quests = { 83266 }, points = 2 },
      { kind = "TREASURE", label = "Diaphanous Gem Shards", quests = { 83265 }, points = 2 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- The War Within Leatherworking
  [2880] = {
    profession = "Leatherworking",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83732 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 84131 }, points = 2 },
      { kind = "TREASURE", label = "Stone-Leather Swatch", quests = { 83268 }, points = 1 },
      { kind = "TREASURE", label = "Sturdy Nerubian Carapace", quests = { 83267 }, points = 1 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
  -- The War Within Mining
  [2881] = {
    profession = "Mining",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83733 }, points = 1 },
      { kind = "WEEKLY", label = "Trainer quest", quests = { 83102, 83103, 83104, 83105, 83106 }, points = 3, limit = 1 },
      { kind = "GATHERING", label = "Mining (rare drop)", quests = { 83049 }, points = 3 },
      { kind = "GATHERING", label = "Mining drops", quests = { 83050, 83051, 83052, 83053, 83054 }, points = 1 },
    },
    catchUp = {
      hint = "These are randomly looted from mining nodes around the world once the weekly objectives below are completed.",
      requires = {
        { label = "Trainer Quest", quests = { 83104, 83105, 83103, 83106, 83102 }, match = "any" },
        { label = "Gathering", quests = { 83050, 83051, 83052, 83053, 83054, 83049 }, match = "all" },
      },
    },
  },
  -- The War Within Skinning
  [2882] = {
    profession = "Skinning",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83734 }, points = 1 },
      { kind = "WEEKLY", label = "Trainer quest", quests = { 82992, 82993, 83097, 83098, 83100 }, points = 3, limit = 1 },
      { kind = "GATHERING", label = "Skinning (rare drop)", quests = { 81464 }, points = 2 },
      { kind = "GATHERING", label = "Skinning drops", quests = { 81459, 81460, 81461, 81462, 81463 }, points = 1 },
    },
    catchUp = {
      hint = "These are randomly looted from skinning around the world once the weekly objectives below are completed.",
      requires = {
        { label = "Trainer Quest", quests = { 83097, 83098, 83100, 82992, 82993 }, match = "any" },
        { label = "Gathering", quests = { 81459, 81460, 81461, 81462, 81463, 81464 }, match = "all" },
      },
    },
  },
  -- The War Within Tailoring
  [2883] = {
    profession = "Tailoring",
    expansion = "The War Within",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 83735 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 84132 }, points = 2 },
      { kind = "TREASURE", label = "Chitin Needle", quests = { 83270 }, points = 1 },
      { kind = "TREASURE", label = "Spool of Webweave", quests = { 83269 }, points = 1 },
    },
    catchUp = {
      hint = "Awarded from Patron Orders at your crafting station.",
    },
  },
}

-- Runtime helpers. Anything registered here is data Lodestar can verify; anything
-- missing is reported as untracked rather than assumed complete.

function LS:RegisterKnowledge(skillLineID, data)
  if type(skillLineID) ~= "number" or type(data) ~= "table" then return end
  local entry = self.knowledgeSources[skillLineID]
  if not entry then
    entry = { profession = data.profession, expansion = data.expansion, objectives = {} }
    self.knowledgeSources[skillLineID] = entry
  end
  entry.objectives = entry.objectives or {}
  for _, objective in ipairs(data.objectives or {}) do
    table.insert(entry.objectives, objective)
  end
  if data.catchUp then
    entry.catchUp = data.catchUp
  end
end

function LS:KnowledgeSourcesFor(skillLineID)
  local registry = self.knowledgeSources[skillLineID]
  local custom = self.db and self.db.knowledge and self.db.knowledge[tostring(skillLineID)]
  if not registry and not custom then return nil end
  if not custom then return registry end

  local merged = {
    profession = (registry and registry.profession) or custom.profession,
    expansion = (registry and registry.expansion) or custom.expansion,
    catchUp = custom.catchUp or (registry and registry.catchUp),
    objectives = {},
  }
  for _, source in ipairs({ registry, custom }) do
    for _, objective in ipairs(source and source.objectives or {}) do
      table.insert(merged.objectives, objective)
    end
  end
  return merged
end
