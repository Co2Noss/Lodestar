local _, LS = ...

-- First-run and "what's new" tips. Returning installs skip firstRun tips so only
-- new feature ids appear. Skip marks the rest seen; Next marks this one and continues.

LS.TIPS = {
  {
    id = "goals",
    firstRun = true,
    title = "Goals decide the plan",
    body = "Nothing is ranked until you turn a goal on. Change this any time in Settings → Goals. A goal that is off is hidden on purpose.",
    page = "SETTINGS",
    settingsTab = "GOALS",
    highlight = "tab:GOALS",
  },
  {
    id = "dashboard",
    firstRun = true,
    title = "Dashboard is yours",
    body = "Edit dashboard to add tiles, then drag and resize them. Rares stay off the add list until HandyNotes is loaded.",
    page = "DASHBOARD",
    highlight = "edit",
  },
  {
    id = "optional_addons",
    firstRun = true,
    title = "Optional addons",
    body = "Price sources, waypoints, and HandyNotes live on Settings → Optional Addons. Lodestar stays quiet when they are not loaded, instead of guessing.",
    page = "SETTINGS",
    settingsTab = "ADDONS",
    highlight = "tab:ADDONS",
  },
  {
    id = "housing_pvp",
    title = "Housing and PvP",
    body = "Housing, PvP, and Battle Pets are goals. Weekly Conquest, a missing house, neighborhood initiatives, housing weeklies already in your log, and pet battle quests already in your log rank only while those goals are on. The Housing tile opens the client's dashboard. Battle Pets opens the pet journal.",
    page = "SETTINGS",
    settingsTab = "GOALS",
    highlight = "goal:HOUSING",
  },
  {
    id = "battlepets",
    title = "Battle Pets",
    body = "Battle Pets is a goal. Locked slots, an empty team, and pet battle quests already in your log rank while that goal is on. The Battle Pets tile shows unique pets and your team from the journal. Lodestar does not invent a catching list.",
    page = "SETTINGS",
    settingsTab = "GOALS",
    highlight = "goal:PETS",
  },
  {
    id = "itemlevel",
    title = "Item level slots",
    body = "The Item Level tile lists missing enchants and sockets beside the gear so two flags on one piece never overlap. A red border is a missing enchant. A yellow caution is an empty gem slot.",
    page = "DASHBOARD",
    highlight = function(self)
      if self.DashboardHas and self:DashboardHas("itemlevel") then return "widget:itemlevel" end
      return "add:itemlevel"
    end,
    editDashboard = function(self)
      return not (self.DashboardHas and self:DashboardHas("itemlevel"))
    end,
  },
  {
    id = "calendar_guild",
    title = "Calendar and guild",
    body = "Edit dashboard to add Calendar and Guild. Calendar lists this week and next from the client, including guild events and invites. Guild shows your rank and who is online, and opens Communities.",
    page = "DASHBOARD",
    highlight = "edit",
  },
  {
    id = "journeys",
    title = "Seasonal journeys",
    body = "Delver's Journey and Preyhunter's Journey tiles show this season's rank from the client. Click either tile to open Journeys.",
    page = "DASHBOARD",
    highlight = function(self)
      if self.DashboardHas and self:DashboardHas("delvesjourney") then return "widget:delvesjourney" end
      return "add:delvesjourney"
    end,
    editDashboard = function(self)
      return not (self.DashboardHas and self:DashboardHas("delvesjourney"))
    end,
  },
  {
    id = "currency_settings",
    title = "Pick your currencies",
    body = "The currency list is longer than a tile can show, so it lives on Settings → Currencies, grouped by expansion. Leave it alone and the Currencies tile follows this expansion on its own.",
    page = "SETTINGS",
    settingsTab = "CURRENCIES",
    highlight = "tab:CURRENCIES",
  },
}

-- Last five version blocks for Changelog. Keep this in step with CHANGELOG.md.
LS.CHANGELOG = {
  {
    version = "1.5.62",
    notes = {
      "Lodestar counts which tiles and goals get used, so the ones nobody uses can be fixed or dropped.",
      "It never records your character, realm, guild, or anything you typed. /ls analytics prints all of it.",
      "Nothing is sent unless you run the Wago App with data sharing on. Without it the counts stay on your machine.",
    },
  },
  {
    version = "1.5.61",
    notes = {
      "Guilds of WoW, Details, and REKeys see your key without Astral Keys installed.",
      "The Mythic+ tile shows your current keystone. Hover it, or click to link it.",
      "!keys answers with the key linked. Settings picks which channels answer.",
      "!keys no longer errors, and stays quiet where the game blocks chat.",
      "Item level and Readiness numbers sit on a dimmed icon, not a black box.",
      "Settings → Currencies reaches every currency, past the tile's first eight.",
    },
  },
  {
    version = "1.5.6",
    notes = {
      "W2UI theme. Auto follows W2UI when it is loaded.",
      "All The Things ranks tracked mounts, appearances, achievements, and watched quests.",
      "Can I Mog It nudges learnable appearances already in your bags.",
      "Completed tasks fill in when Lodestar can tell the work is done, with expansion-specific profession names.",
    },
  },
  {
    version = "1.5.5",
    notes = {
      "Changelog is its own left-menu page, under Settings and above FAQ.",
      "The Guild tile shows your rank from the client. Edit dashboard can turn that line off.",
      "Help copies Discord and GitHub from the click itself, with those marks from addon media.",
      "Spare knowledge on a finished tree stays off Today. All expansions still tracks weeklies and treasures.",
      "Professions and gold default to this expansion. Settings → Goals can switch to All expansions or focus an older one. Reputation starts on this expansion.",
      "Clicking the Professions page no longer opens a profession window on other pages.",
    },
  },
  {
    version = "1.5.4",
    notes = {
      "FAQ and Help sit under Settings. Help copies Discord and GitHub support links to the clipboard.",
      "The main window does not capture the keyboard. Escape closes it. Compact stays up while it is open.",
      "The collapsed left menu shows workspace icons and still shows the version at the bottom.",
      "/lodestar opens and closes the window the same way /ls does.",
      "Noisy client events no longer rebuild the whole window. Dashboard tiles refresh in place.",
      "Clicking a Mythic+ dungeon teleport closes the main window after the spell fires.",
      "The minimap button stays on the minimap edge when you drag it. Settings → Appearance can unlock it.",
    },
  },
}

-- In-game FAQ. Keep this in step with the wiki FAQ page.
LS.FAQ = {
  {
    q = "Why did nothing rank?",
    a = "Every goal starts off. Pick at least one on the welcome page or in Settings → Goals. A goal that is off is hidden on purpose.",
  },
  {
    q = "How do I open Lodestar?",
    a = "/ls or /lodestar opens and closes the window. Left-click the minimap button for the full window; right-click for compact mode. Escape closes the main window.",
  },
  {
    q = "Where did Great Vault and Professions go in the menu?",
    a = "They live under Dashboard. Progress is the tracked list, not the vault.",
  },
  {
    q = "Why is gold quiet?",
    a = "Prices come from TradeSkillMaster, Auctionator, or RECrystallize. Lodestar does not invent an auction house. If none of those is loaded, or the source you picked in Settings → Optional Addons is not, gold stays off the plan.",
  },
  {
    q = "Why are there no rares?",
    a = "HandyNotes by itself has no coordinates. You need a notes pack (Midnight, Silvermoon, and many others). Lodestar ranks rares that pack is currently showing, not treasures or city marks.",
  },
  {
    q = "Why did !keys not answer in guild chat?",
    a = "The game blocks addons from sending chat while you are in a dungeon, raid, encounter or PvP match. Lodestar checks first, so instead of an error it prints the key to your own chat frame with the reason. You can still link it yourself from the Mythic+ tile.",
  },
  {
    q = "Why does !keys say I have no key?",
    a = "Lodestar reads your keystone from the client, not from another addon, so it answers !keys on its own. Settings → Optional Addons picks the channels it answers on. If another keystone addon already answers in your guild, turn that one channel off and keep the rest. The Mythic+ tile always names the key in your bags.",
  },
  {
    q = "Does my guild's keystone list see my key?",
    a = "Yes, without Astral Keys or Details. Guilds of WoW, Details, and REKeys ask LibOpenRaid for the guild's keys, and Lodestar embeds that library so your client answers for itself. Lodestar sends nothing on its own; the library replies when another client asks, on login, and when a run ends. Only the key, dungeon, class, and rating go out.",
  },
  {
    q = "How do I put a tile exactly where I want it?",
    a = "Edit dashboard, then click the empty canvas where you want it: Lodestar offers the tiles that fit there and drops the one you pick at that spot. Dragging a tile onto another trades their places when both fit where the other was, and says which tile is in the way when they do not. The add, reset, and compact buttons sit above the canvas; the button beside them, or Settings → Layout, moves them under your tiles instead.",
  },
  {
    q = "What are the two numbers on a Mythic+ dungeon?",
    a = "The large one is your best key level in that dungeon; the smaller one under it is that dungeon's rating, coloured by what the rating is worth rather than by the key level. Hover a dungeon for the rating, your best run, and its time. Edit dashboard → Mythic+ → Rating per dungeon turns the small number off.",
  },
  {
    q = "Why can't I pick currencies?",
    a = "Because the picks are stored on the Currencies tile, so without that tile on your dashboard there is nowhere to keep them and nothing to show them on. Settings → Currencies says so and has a button to add the tile. Once it is there, each row can show what you have, what you have out of the cap, or how much is left to earn. If you track more currencies than the tile can show, scroll it with the mouse wheel: the bottom line counts the rows above and below.",
  },
  {
    q = "Can I move my settings to another install, or share them?",
    a = "Settings → Backup & Share. Share carries settings and your dashboard layout and is safe to hand to anyone. Backup adds what you have finished, ignored and tracked, for moving your own install. Copy puts it on the clipboard; paste it into the box on the other install and press Load. Neither string carries your characters: that list rebuilds itself as you log in on each one.",
  },
  {
    q = "What usage data does Lodestar collect?",
    a = "Which of its own tiles, goals, pages and settings you use, and which optional addons are loaded, so parts nobody uses can be fixed or dropped instead of guessed about. Never your character, realm, guild, or anything you typed. Nothing is sent at all unless you installed the Wago App and turned data sharing on there; without it these numbers stay on your machine and go away when you log out. If that app is sharing, Settings → Optional Addons → Usage data turns Lodestar's share of it off. /ls analytics prints the lot either way.",
  },
  {
    q = "Where do I change what a tile shows?",
    a = "Edit dashboard, then click the tile. Each tile shows its own toggles while you are editing. The one exception is the currency list, which is far longer than a tile: that lives on Settings → Currencies, and the tile has a button through to it.",
  },
  {
    q = "Why is PvP quiet?",
    a = "Turn the PvP goal on. Weekly Conquest ranks only while the client still reports unfinished progress this week, and only at the expansion cap. Honor and ratings live on the dashboard tile.",
  },
  {
    q = "Why is Housing quiet?",
    a = "Turn the Housing goal on. A missing house ranks at the expansion cap when the client reports none. Neighborhood initiatives rank only while contribution is still unfinished. Housing weeklies rank only when they are already in the log. Lodestar does not invent a housing circuit.",
  },
  {
    q = "Why is Battle Pets quiet?",
    a = "Turn the Battle Pets goal on. Locked slots rank while the client says the journal or team is locked. An empty team ranks once you already own a pet. Pet battle quests rank only when they are already in the log. Lodestar does not invent a catching list.",
  },
  {
    q = "Why did it ask me to check the map?",
    a = "Questing does not invent a circuit. If the log is empty and no campaign or important work is waiting, that is the honest next step.",
  },
  {
    q = "Why is the Great Vault quiet?",
    a = "It waits until you are at the expansion cap. Until then the plan is to level and enjoy the game. Professions still rank if that goal is on.",
  },
  {
    q = "Why is compact empty?",
    a = "It only lists activities you tracked. Track from Details.",
  },
  {
    q = "Can I hide work I do not have time for?",
    a = "There is no time-budget slider. Lodestar ranks everything that matches your goals instead of hiding whatever does not fit a session length. Ignore a card if you do not want to see it.",
  },
  {
    q = "Why is the minimap button locked to the minimap?",
    a = "That is the default. Drag slides it around the edge. Settings → Appearance → Lock to the minimap turns that off so the button can sit anywhere.",
  },
  {
    q = "Why am I only seeing this expansion?",
    a = "Professions and gold farms default to this expansion. Settings → Goals has an expansion focus: this expansion, All expansions, or a single older one. All expansions still tracks weeklies and treasures; leftover points on a finished tree stay off Today. Reputation starts on this expansion; Settings → Reputation can rank older factions.",
  },
  {
    q = "Why are old knowledge points on the Dashboard?",
    a = "They should not be. Dashboard and Warband unspent knowledge only count the current expansion, and only points that still fit in a specialization tree. Spare points after the trees are full stay off those totals.",
  },
  {
    q = "Why doesn't Lodestar tell me to spend leftover knowledge?",
    a = "Once every specialization rank is bought, those points have nowhere to go. Tracking All expansions still shows weeklies and treasures. The profession page still shows the spare count. Today stays quiet instead of ranking a spend that cannot happen.",
  },
  {
    q = "What Lodestar is not",
    a = "Not a replacement for your quest tracker. Not a list of everything available in the game. Profession catch-up from Patron Orders cannot be counted from the client, so Lodestar describes it instead of inventing a number.",
  },
}

LS.HELP = {
  {
    title = "Getting started",
    body = "Every goal starts off. Pick at least one on the welcome page or in Settings → Goals. A goal that is off is hidden on purpose. Dashboard is tiles you pick; Edit dashboard to add, move, or resize them.",
  },
  {
    title = "Commands",
    body = "/ls or /lodestar — open or close the window\n/ls compact — toggle compact mode\n/ls compact single — toggle single-recommendation compact mode\n/ls theme auto — follow W2UI, GW2 UI, RealUI, ElvUI, or Ellesmere when loaded\n/ls debug — disable every other addon and reload\n/ls debug off — restore those addons (this character only)\n/ls reset — wipe saved settings and reload",
  },
  {
    title = "The window",
    body = "Escape closes the main window. It does not capture the keyboard, so WASD, jump, Enter, and chat still reach the client. Compact stays up while the main window is open. Left-click the minimap button for the full window; right-click for compact. The button stays on the minimap unless you unlock it in Settings → Appearance.",
  },
  {
    title = "When something is missing",
    body = "Lodestar stays quiet when a goal is off, or when the client has nothing to report. It does not invent auction prices, quest IDs, housing quests, or map coordinates. Optional addons unlock extra behaviour if they are loaded; without them those parts stay off the plan.",
  },
  {
    title = "If something errors",
    body = "/ls debug isolates Lodestar from every other addon, then reloads. If the error is gone, it was not Lodestar. When you file an issue, include your class/spec, the theme you use (Blizzard, ElvUI, or other), and what you expected versus what happened.",
  },
}

LS.SUPPORT = {
  {
    name = "Discord",
    why = "Talk with us in Lodestar Guide.",
    url = "https://discord.gg/a7hrHavcwq",
    action = "Copy Discord invite",
    copied = "Discord invite",
    icon = LS.MEDIA_DISCORD,
    cover = true,
  },
  {
    name = "GitHub",
    why = "File an issue on Co2Noss/Lodestar.",
    url = "https://github.com/Co2Noss/Lodestar/issues",
    action = "Copy GitHub issues",
    copied = "GitHub issues link",
    icon = LS.MEDIA_GITHUB,
    cover = true,
  },
}

LS.OPTIONAL_ADDONS = {
  { name = "TradeSkillMaster", addon = "TradeSkillMaster",
    ready = function() return (TSM_API or TSM) and true end },
  { name = "Auctionator", addon = "Auctionator",
    ready = function() return Auctionator and true end },
  { name = "RECrystallize", addon = "RECrystallize",
    ready = function() return (RECrystallize_PriceCheckItemID or RECrystallize_PriceCheck) and true end },
  { name = "TomTom", addon = "TomTom",
    ready = function(self) return self.HasTomTom and self:HasTomTom() end },
  { name = "HandyNotes", addon = "HandyNotes",
    ready = function(self) return self.HasHandyNotes and self:HasHandyNotes() end },
  { name = "All The Things", addon = "AllTheThings",
    ready = function(self) return self.GetATT and self:GetATT() and true end },
  { name = "Can I Mog It", addon = "CanIMogIt",
    ready = function(self) return self.HasCanIMogIt and self:HasCanIMogIt() end },
  { name = "Raider.IO", addon = "RaiderIO",
    ready = function() return RaiderIO and true end },
  { name = "ElvUI", addon = "ElvUI",
    ready = function(self) return self.GetElvUI and self:GetElvUI() and true end },
  { name = "GW2 UI", addon = "GW2_UI",
    ready = function(self) return self.GetGW2 and self:GetGW2() and true end },
  { name = "W2UI", addon = "W2UI",
    ready = function(self) return self.GetW2UI and self:GetW2UI() and true end },
  { name = "RealUI", addon = "nibRealUI",
    ready = function(self)
      if self.GetAurora and self:GetAurora() then return true end
      return C_AddOns and C_AddOns.IsAddOnLoaded
        and (C_AddOns.IsAddOnLoaded("nibRealUI") or C_AddOns.IsAddOnLoaded("RealUI") or C_AddOns.IsAddOnLoaded("Aurora"))
    end },
  { name = "EllesmereUI", addon = "EllesmereUI",
    ready = function()
      return C_AddOns and C_AddOns.IsAddOnLoaded and (C_AddOns.IsAddOnLoaded("EllesmereUI") or C_AddOns.IsAddOnLoaded("EllesmereUIBlizzardSkin"))
    end },
  { name = "Great Vault Key Info", addon = "GreatVaultKeyInfo" },
}

function LS:SeedSeenTips(db)
  db = db or self.db
  if not db then return end
  db.seenTips = db.seenTips or {}
  if db.welcomed and not db.tipsSeeded then
    if not next(db.seenTips) then
      for _, tip in ipairs(self.TIPS) do
        if tip.firstRun then db.seenTips[tip.id] = true end
      end
    end
    db.tipsSeeded = true
  end
end

function LS:UnseenTips()
  local seen = self.db and self.db.seenTips or {}
  local out = {}
  for _, tip in ipairs(self.TIPS) do
    if not seen[tip.id] then table.insert(out, tip) end
  end
  return out
end

function LS:HasUnseenTips()
  return #self:UnseenTips() > 0
end

function LS:MarkTipSeen(id)
  if not self.db or not id then return end
  self.db.seenTips = self.db.seenTips or {}
  self.db.seenTips[id] = true
end

function LS:SkipRemainingTips()
  for _, tip in ipairs(self:UnseenTips()) do
    self:MarkTipSeen(tip.id)
  end
end

function LS:CurrentTip()
  return self:UnseenTips()[1]
end

function LS:TipWantsEdit(tip)
  if not tip then return false end
  local edit = tip.editDashboard
  if type(edit) == "function" then
    local ok, on = pcall(edit, self)
    return ok and on and true or false
  end
  return edit and true or false
end

function LS:TipHighlight(tip)
  if not tip then return end
  local mark = tip.highlight
  if type(mark) == "function" then
    local ok, id = pcall(mark, self)
    if ok then return id end
    return
  end
  return mark
end

function LS:MarkCoach(id, frame)
  if not id or not frame then return end
  self.coachMarks = self.coachMarks or {}
  self.coachMarks[id] = frame
end

function LS:ShowCurrentTip()
  local tip = self:CurrentTip()
  if not tip then
    self:FinishTutorial()
    return
  end
  self.coachActive = true
  if tip.settingsTab then self:SetPageTab("SETTINGS", tip.settingsTab) end
  if self:TipWantsEdit(tip) then
    self.dashboardEdit = true
  end
  self:ShowPage(tip.page or "DASHBOARD")
end

function LS:FinishTutorial()
  local dest = self.tutorialReturn or "TODAY"
  self.tutorialReturn = nil
  self.coachActive = false
  if self.HideCoach then self:HideCoach() end
  self:ShowPage(dest)
end

function LS:OptionalAddonLoaded(row)
  if type(row) ~= "table" then return false end
  if row.ready then
    local ok, on = pcall(row.ready, self)
    if ok and on then return true end
  end
  if row.addon and C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, on = pcall(C_AddOns.IsAddOnLoaded, row.addon)
    if ok and on then return true end
  end
  return false
end

function LS:OptionalAddonStatus()
  local out = {}
  for _, row in ipairs(self.OPTIONAL_ADDONS) do
    table.insert(out, { name = row.name, loaded = self:OptionalAddonLoaded(row) and true or false })
  end
  return out
end
