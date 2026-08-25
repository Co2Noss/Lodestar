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
-- per character. Midnight treasures are the eight world pickups plus vendor books.
-- `map`, `x`, `y` are uiMapID and percent coordinates from WeeklyKnowledge Unique.lua.
LS.knowledgeSources = {
  -- Midnight Alchemy
  [2906] = {
    profession = "Alchemy",
    expansion = "Midnight",
    objectives = {
      { kind = "TREATISE", label = "Treatise", quests = { 95127 }, points = 1 },
      { kind = "WEEKLY", label = "Weekly quest", quests = { 93690 }, points = 1 },
      { kind = "TREASURE", label = "Freshly Plucked Peacebloom", quests = { 89115 }, points = 3, map = 2393, x = 49.11, y = 75.84, note = "Purple peacebloom flowers in a flower crate next to a big blue vase." },
      { kind = "TREASURE", label = "Pristine Potion", quests = { 89117 }, points = 3, map = 2393, x = 47.75, y = 51.67, note = "Potion found on a bench on top of the building." },
      { kind = "TREASURE", label = "Vial of Zul'Aman Oddities", quests = { 89114 }, points = 3, map = 2437, x = 40.39, y = 51.17, note = "Green vial found on a cart." },
      { kind = "TREASURE", label = "Measured Ladle", quests = { 89116 }, points = 3, map = 2536, x = 49.1, y = 23.17, note = "Ladle found on a table inside the hut." },
      { kind = "TREASURE", label = "Vial of Rootlands Oddities", quests = { 89113 }, points = 3, map = 2413, x = 34.77, y = 24.7, note = "Big purple vial on the floor inside the building next to the right stairs." },
      { kind = "TREASURE", label = "Vial of Voidstorm Oddities", quests = { 89112 }, points = 3, map = 2444, x = 41.94, y = 40.63, note = "Vial on the ground next to some big bones." },
      { kind = "TREASURE", label = "Vial of Eversong Oddities", quests = { 89111 }, points = 3, map = 2393, x = 45.08, y = 44.75, note = "Vial on a bench. Note: This may not appear or bug out, relog or come back later." },
      { kind = "TREASURE", label = "Failed Experiment", quests = { 89118 }, points = 3, map = 2405, x = 32.79, y = 43.3, note = "A small vial on the ground." },
      { kind = "TREASURE", label = "Beyond the Event Horizon: Alchemy", quests = { 93794 }, points = 10, map = 2405, x = 52.6, y = 72.8, note = "Void Researcher Anomander" },
      { kind = "TREASURE", label = "Demystifyin': Alchemy", quests = { 96459 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "Deconstructed Forge Techniques", quests = { 89177 }, points = 3, map = 2393, x = 26.97, y = 60.29, note = "Scroll on the floor inside the tower." },
      { kind = "TREASURE", label = "Silvermoon Smithing Kit", quests = { 89178 }, points = 3, map = 2395, x = 48.37, y = 75.82, note = "A tool on a barrel next to the red tent." },
      { kind = "TREASURE", label = "Carefully Racked Spear", quests = { 89179 }, points = 3, map = 2536, x = 33.14, y = 65.8, note = "Spear on the wall inside the building." },
      { kind = "TREASURE", label = "Metalworking Cheat Sheet", quests = { 89180 }, points = 3, map = 2395, x = 56.84, y = 40.77, note = "Big piece of paper on the floor inside the library." },
      { kind = "TREASURE", label = "Voidstorm Defense Spear", quests = { 89181 }, points = 3, map = 2444, x = 30.52, y = 69, note = "Spear on the floor in front of a table inside the building to the right." },
      { kind = "TREASURE", label = "Rutaani Floratender's Sword", quests = { 89182 }, points = 3, map = 2413, x = 66.34, y = 50.83, note = "Sword on the top mushroom." },
      { kind = "TREASURE", label = "Sin'dorei Master's Forgemace", quests = { 89183 }, points = 3, map = 2393, x = 49.16, y = 61.34, note = "Mace on the table inside the building to the left." },
      { kind = "TREASURE", label = "Silvermoon Blacksmith's Hammer", quests = { 89184 }, points = 3, map = 2393, x = 48.6, y = 74.4, note = "Big hammer on the floor behind the table." },
      { kind = "TREASURE", label = "Beyond the Event Horizon: Blacksmithing", quests = { 93795 }, points = 10, map = 2405, x = 52.6, y = 72.8, note = "Void Researcher Anomander" },
      { kind = "TREASURE", label = "Demystifyin': Blacksmithing", quests = { 96511 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "Enchanted Amani Mask", quests = { 89100 }, points = 3, map = 2536, x = 48.76, y = 22.58, note = "Huge Amani mask inside the hut. Note: This may not appear before completing the Zul'aman questline." },
      { kind = "TREASURE", label = "Enchanted Sunfire Silk", quests = { 89101 }, points = 3, map = 2395, x = 40.19, y = 61.22, note = "Purple bolt of silk on the floor next to an open barrel of fermented grapes inside the main building on the bottom floor. Note: There is a theory that War Mode will make this item not appear." },
      { kind = "TREASURE", label = "Pure Void Crystal", quests = { 89102 }, points = 3, map = 2405, x = 35.49, y = 58.82, note = "Big purple crystal between two tents. You must complete the Into the Abyss campaign chapter in order to see it." },
      { kind = "TREASURE", label = "Everblazing Sunmote", quests = { 89103 }, points = 3, map = 2395, x = 60.75, y = 53.01, note = "A big yellow crystal inside a tent." },
      { kind = "TREASURE", label = "Entropic Shard", quests = { 89104 }, points = 3, map = 2413, x = 37.75, y = 65.22, note = "Blue shard next to the yellow bushes." },
      { kind = "TREASURE", label = "Primal Essence Orb", quests = { 89105 }, points = 3, map = 2413, x = 65.72, y = 50.22, note = "Yellow orb all the way on top of the big mushroom." },
      { kind = "TREASURE", label = "Loa-Blessed Dust", quests = { 89106 }, points = 3, map = 2437, x = 40.41, y = 51.18, note = "Big pile of purple dust on the wagon." },
      { kind = "TREASURE", label = "Sin'dorei Enchanting Rod", quests = { 89107 }, points = 3, map = 2395, x = 63.49, y = 32.6, note = "A rod on the floor of the platform." },
      { kind = "TREASURE", label = "Skill Issue: Enchanting", quests = { 92374 }, points = 10, map = 2395, x = 43.4, y = 47.4, note = "Caeris Fairdawn" },
      { kind = "TREASURE", label = "Echo of Abundance: Enchanting", quests = { 92186 }, points = 10 },
      { kind = "TREASURE", label = "Demystifyin': Enchanting", quests = { 96512 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "One Engineer's Junk", quests = { 89133 }, points = 3, map = 2393, x = 51.32, y = 74.46, note = "Junk found on the floor to the left inside the building." },
      { kind = "TREASURE", label = "Miniaturized Transport Skiff", quests = { 89134 }, points = 3, map = 2444, x = 28.93, y = 39.01, note = "Small transport ring at the top of the stairs to the right." },
      { kind = "TREASURE", label = "Manual of Mistakes and Mishaps", quests = { 89135 }, points = 3, map = 2395, x = 39.56, y = 45.8, note = "Book on the table inside the tower on the ground floor." },
      { kind = "TREASURE", label = "Expeditious Pylon", quests = { 89136 }, points = 3, map = 2413, x = 67.99, y = 49.81, note = "Sparkling pylon on top of the mushroom." },
      { kind = "TREASURE", label = "Ethereal Stormwrench", quests = { 89137 }, points = 3, map = 2444, x = 54.13, y = 51.01, note = "Wrench on the floor next to a big crate inside the building." },
      { kind = "TREASURE", label = "Offline Helper Bot", quests = { 89138 }, points = 3, map = 2536, x = 65.16, y = 34.79, note = "Small robot standing on the edge of the wall." },
      { kind = "TREASURE", label = "What To Do When Nothing Works", quests = { 89139 }, points = 3, map = 2393, x = 51.2, y = 57.25, note = "Book on the table on top of the building (not inside)." },
      { kind = "TREASURE", label = "Handy Wrench", quests = { 89140 }, points = 3, map = 2437, x = 34.2, y = 87.8, note = "Wrench on the ground next to the mountain wall." },
      { kind = "TREASURE", label = "Beyond the Event Horizon: Engineering", quests = { 93796 }, points = 10, map = 2405, x = 52.6, y = 72.8, note = "Void Researcher Anomander" },
      { kind = "TREASURE", label = "Demystifyin': Engineering", quests = { 96513 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "Bloomed Bud", quests = { 89162 }, points = 3, map = 2413, x = 38.32, y = 67.06, note = "Huge yellow flower on the ground." },
      { kind = "TREASURE", label = "Sweeping Harvester's Scythe", quests = { 89161 }, points = 3, map = 2437, x = 41.91, y = 45.92, note = "Big scythe on the ground near a big tree." },
      { kind = "TREASURE", label = "Simple Leaf Pruners", quests = { 89160 }, points = 3, map = 2393, x = 49.01, y = 75.92, note = "Tool on the table." },
      { kind = "TREASURE", label = "Lightbloom Root", quests = { 89159 }, points = 3, map = 2413, x = 36.65, y = 25.07, note = "Root on the ground in front of a massive root and some rocks." },
      { kind = "TREASURE", label = "A Spade", quests = { 89158 }, points = 3, map = 2395, x = 64.24, y = 30.46, note = "A spade... on the ground." },
      { kind = "TREASURE", label = "Harvester's Sickle", quests = { 89157 }, points = 3, map = 2413, x = 76.12, y = 51.05, note = "Small sickle next to the big tree and green bushes." },
      { kind = "TREASURE", label = "Peculiar Lotus", quests = { 89156 }, points = 3, map = 2405, x = 34.68, y = 56.96, note = "Big lotus flower on the ground." },
      { kind = "TREASURE", label = "Planting Shovel", quests = { 89155 }, points = 3, map = 2413, x = 51.13, y = 55.7, note = "Shovel on the ground next to the inn outside." },
      { kind = "TREASURE", label = "Traditions of the Haranir: Herbalism", quests = { 93411 }, points = 10, map = 2413, x = 51, y = 50.8, note = "Naynar" },
      { kind = "TREASURE", label = "Echo of Abundance: Herbalism", quests = { 92174 }, points = 10 },
      { kind = "TREASURE", label = "Demystifyin': Herbalism", quests = { 96514 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "Void-Touched Quill", quests = { 89067 }, points = 3, map = 2444, x = 60.7, y = 84.25, note = "Quill on the table in the building on the right side." },
      { kind = "TREASURE", label = "Leather-Bound Techniques", quests = { 89068 }, points = 3, map = 2437, x = 40.48, y = 49.36, note = "Book on the ground in the back of the cave." },
      { kind = "TREASURE", label = "Spare Ink", quests = { 89069 }, points = 3, map = 2395, x = 48.31, y = 75.54, note = "Bottle of ink on the bench next to the tent." },
      { kind = "TREASURE", label = "Intrepid Explorer's Marker", quests = { 89070 }, points = 3, map = 2413, x = 52.43, y = 52.6, note = "Small marker on top of a large root in the air. Not on the ground or in the cave." },
      { kind = "TREASURE", label = "Leftover Sanguithorn Pigment", quests = { 89071 }, points = 3, map = 2413, x = 52.75, y = 49.99, note = "Small pot on the table" },
      { kind = "TREASURE", label = "Half-Baked Techniques", quests = { 89072 }, points = 3, map = 2395, x = 39.28, y = 45.43, note = "Book on the floor next to some scrolls inside the building on the ground floor. Note: There is a theory that War Mode will make this item not appear." },
      { kind = "TREASURE", label = "Songwriter's Pen", quests = { 89073 }, points = 3, map = 2393, x = 47.6, y = 50.4, note = "A TINY pen next to some books on top of some boxes behind Rae'ana on top of the building." },
      { kind = "TREASURE", label = "Songwriter's Quill", quests = { 89074 }, points = 3, map = 2395, x = 40.35, y = 61.24, note = "Quill on the table inside the building on the bottom floor." },
      { kind = "TREASURE", label = "Traditions of the Haranir: Inscription", quests = { 93412 }, points = 10, map = 2413, x = 51, y = 50.8, note = "Naynar" },
      { kind = "TREASURE", label = "Demystifyin': Inscription", quests = { 96515 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "Sin'dorei Masterwork Chisel", quests = { 89122 }, points = 3, map = 2393, x = 50.5, y = 56.59, note = "Chisel on the floor under a table to the left inside the building." },
      { kind = "TREASURE", label = "Speculative Voidstorm Crystal", quests = { 89123 }, points = 3, map = 2444, x = 30.49, y = 69.03, note = "Big blue crystal under a table inside the building to the right." },
      { kind = "TREASURE", label = "Dual-Function Magnifiers", quests = { 89124 }, points = 3, map = 2393, x = 28.72, y = 46.63, note = "Magnifiers on the floor inside the building." },
      { kind = "TREASURE", label = "Poorly Rounded Vial", quests = { 89125 }, points = 3, map = 2395, x = 56.62, y = 40.88, note = "A vial on the table inside the building." },
      { kind = "TREASURE", label = "Shattered Glass", quests = { 89126 }, points = 3, map = 2444, x = 62.77, y = 53.46, note = "Hard to see shattered glass on the dark blue ground." },
      { kind = "TREASURE", label = "Vintage Soul Gem", quests = { 89127 }, points = 3, map = 2393, x = 55.44, y = 47.82, note = "A gem on a crate next to the gem vendor." },
      { kind = "TREASURE", label = "Ethereal Gem Pliers", quests = { 89128 }, points = 3, map = 2444, x = 54.19, y = 51.05, note = "Pliers on the floor next to a cool plasma lamp near the entrance." },
      { kind = "TREASURE", label = "Sin'dorei Gem Faceters", quests = { 89129 }, points = 3, map = 2395, x = 39.64, y = 38.82, note = "Gem tools found on the table." },
      { kind = "TREASURE", label = "Skill Issue: Jewelcrafting", quests = { 93222 }, points = 10, map = 2395, x = 43.4, y = 47.4, note = "Caeris Fairdawn" },
      { kind = "TREASURE", label = "Demystifyin': Jewelcrafting", quests = { 96516 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "Amani Leatherworker's Tool", quests = { 89089 }, points = 3, map = 2437, x = 33.08, y = 78.9, note = "Tool on the ground inside the cave." },
      { kind = "TREASURE", label = "Ethereal Leatherworking Knife", quests = { 89090 }, points = 3, map = 2405, x = 34.71, y = 56.92, note = "Knife pierced into the ground." },
      { kind = "TREASURE", label = "Prestigiously Racked Hide", quests = { 89091 }, points = 3, map = 2437, x = 30.75, y = 83.99, note = "A rack inside the temple to the right." },
      { kind = "TREASURE", label = "Bundle of Tanner's Trinkets", quests = { 89092 }, points = 3, map = 2536, x = 45.42, y = 45.61, note = "Bundle of bones on the floor inside the hut behind the mailbox." },
      { kind = "TREASURE", label = "Patterns: Beyond the Void", quests = { 89093 }, points = 3, map = 2444, x = 53.75, y = 51.68, note = "Scrolls on the floor near the center inside the building." },
      { kind = "TREASURE", label = "Haranir Leatherworking Mallet", quests = { 89094 }, points = 3, map = 2413, x = 51.7, y = 51.32, note = "Mallet on a fishing table." },
      { kind = "TREASURE", label = "Haranir Leatherworking Knife", quests = { 89095 }, points = 3, map = 2413, x = 36.1, y = 25.16, note = "Knife on the ground next to some mushroom Rotlings." },
      { kind = "TREASURE", label = "Artisan's Considered Order", quests = { 89096 }, points = 3, map = 2393, x = 44.78, y = 56.25, note = "Scroll on a crate left of Theremis." },
      { kind = "TREASURE", label = "Whisper of the Loa: Leatherworking", quests = { 92371 }, points = 10, map = 2437, x = 45.8, y = 65.8, note = "Magovu" },
      { kind = "TREASURE", label = "Demystifyin': Leatherworking", quests = { 96517 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "Miner's Guide to Voidstorm", quests = { 89144 }, points = 3, map = 2444, x = 30.48, y = 69.07, note = "Book on the floor next to the table on the right side of the building." },
      { kind = "TREASURE", label = "Spelunker's Lucky Charm", quests = { 89145 }, points = 3, map = 2437, x = 41.99, y = 46.52, note = "Item can be found at the top of a fallen log." },
      { kind = "TREASURE", label = "Lost Voidstorm Satchel", quests = { 89146 }, points = 3, map = 2444, x = 54.24, y = 51.57, note = "Satchel on the ground near a broken cylinder." },
      { kind = "TREASURE", label = "Solid Ore Punchers", quests = { 89147 }, points = 3, map = 2395, x = 37.98, y = 45.37, note = "Gloves hanging on the side of the wagon." },
      { kind = "TREASURE", label = "Glimmering Void Pearl", quests = { 89148 }, points = 3, map = 2444, x = 28.74, y = 38.57, note = "Pearls on the ground near the stairs." },
      { kind = "TREASURE", label = "Amani Expert's Chisel", quests = { 89149 }, points = 3, map = 2536, x = 33.32, y = 65.93, note = "Chisel on the floor inside the building." },
      { kind = "TREASURE", label = "Star Metal Deposit", quests = { 89150 }, points = 3, map = 2405, x = 34.23, y = 76.05, note = "Metal ore on the ground." },
      { kind = "TREASURE", label = "Spare Expedition Torch", quests = { 89151 }, points = 3, map = 2413, x = 38.84, y = 65.88, note = "Small torch on the ground between the yellow bushes." },
      { kind = "TREASURE", label = "Whisper of the Loa: Mining", quests = { 92372 }, points = 10, map = 2437, x = 45.8, y = 65.8, note = "Magovu" },
      { kind = "TREASURE", label = "Echo of Abundance: Mining", quests = { 92187 }, points = 10 },
      { kind = "TREASURE", label = "Demystifyin': Mining", quests = { 96518 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "Lightbloom Afflicted Hide", quests = { 89166 }, points = 3, map = 2413, x = 76.08, y = 51.08, note = "Big brown hide on the ground." },
      { kind = "TREASURE", label = "Cadre Skinning Knife", quests = { 89167 }, points = 3, map = 2536, x = 44.92, y = 45.22, note = "Knife on the ground next to the weapon rack." },
      { kind = "TREASURE", label = "Primal Hide", quests = { 89168 }, points = 3, map = 2413, x = 69.52, y = 49.18, note = "Big hide on the floor in the back of the cave." },
      { kind = "TREASURE", label = "Voidstorm Leather Sample", quests = { 89169 }, points = 3, map = 2444, x = 45.5, y = 42.39, note = "Leather sample on the ground next to some big bones." },
      { kind = "TREASURE", label = "Amani Tanning Oil", quests = { 89170 }, points = 3, map = 2437, x = 40.39, y = 36.01, note = "Bottle on the table." },
      { kind = "TREASURE", label = "Sin'dorei Tanning Oil", quests = { 89171 }, points = 3, map = 2393, x = 43.13, y = 55.62, note = "Bottle on the ground behind the skinning trainer." },
      { kind = "TREASURE", label = "Amani Skinning Knife", quests = { 89172 }, points = 3, map = 2437, x = 33.08, y = 79.06, note = "Knife on the table in the back of the cave." },
      { kind = "TREASURE", label = "Thalassian Skinning Knife", quests = { 89173 }, points = 3, map = 2395, x = 48.4, y = 76.27, note = "Big knife on the table with some fish." },
      { kind = "TREASURE", label = "Whisper of the Loa: Skinning", quests = { 92373 }, points = 10, map = 2437, x = 45.8, y = 65.8, note = "Magovu" },
      { kind = "TREASURE", label = "Echo of Abundance: Skinning", quests = { 92188 }, points = 10 },
      { kind = "TREASURE", label = "Demystifyin': Skinning", quests = { 96519 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
      { kind = "TREASURE", label = "A Child's Stuffy", quests = { 89078 }, points = 3, map = 2413, x = 70.56, y = 50.89, note = "A toy on the floor inside the building on the right side." },
      { kind = "TREASURE", label = "A Really Nice Curtain", quests = { 89079 }, points = 3, map = 2393, x = 35.75, y = 61.23, note = "Big purple curtain on the first floor inside the building." },
      { kind = "TREASURE", label = "Sin'dorei Outfitter's Ruler", quests = { 89080 }, points = 3, map = 2395, x = 46.35, y = 34.85, note = "Big yellow ruler on the floor next to a table on the second floor inside the building." },
      { kind = "TREASURE", label = "Wooden Weaving Sword", quests = { 89081 }, points = 3, map = 2413, x = 69.78, y = 51.04, note = "Big yellow sword on the ground next to a tree." },
      { kind = "TREASURE", label = "Book of Sin'dorei Stitches", quests = { 89082 }, points = 3, map = 2444, x = 62.02, y = 83.52, note = "Book on the floor at the middle entrance." },
      { kind = "TREASURE", label = "Satin Throw Pillow", quests = { 89083 }, points = 3, map = 2444, x = 61.4, y = 85.12, note = "A pillow on the floor next to a Pupil of Grief inside the building." },
      { kind = "TREASURE", label = "Particularly Enchanting Tablecloth", quests = { 89084 }, points = 3, map = 2393, x = 31.79, y = 68.27, note = "Tablecloth on the left table inside the tower." },
      { kind = "TREASURE", label = "Artisan's Cover Comb", quests = { 89085 }, points = 3, map = 2437, x = 40.53, y = 49.36, note = "Comb on the floor inside the cave." },
      { kind = "TREASURE", label = "Skill Issue: Tailoring", quests = { 93201 }, points = 10, map = 2395, x = 43.4, y = 47.4, note = "Caeris Fairdawn" },
      { kind = "TREASURE", label = "Demystifyin': Tailoring", quests = { 96520 }, points = 10, map = 2512, x = 58.8, y = 46, note = "Jan'sari the Watchful" },
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
