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
    body = "Edit dashboard to add tiles, then drag and resize them. Gold farms and rares stay off the add list until their addon is loaded.",
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
    body = "Housing and PvP are goals. Weekly Conquest, a missing house, neighborhood initiatives, and housing weeklies already in your log rank only while those goals are on. The Housing tile opens the client's dashboard.",
    page = "SETTINGS",
    settingsTab = "GOALS",
    highlight = "goal:HOUSING",
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
    body = "Edit dashboard to add Calendar and Guild. Calendar lists this week and next from the client, including guild events and invites. Guild shows who is online and opens Communities.",
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
}

-- Last five version blocks for Settings → Changelog. Keep this in step with CHANGELOG.md.
LS.CHANGELOG = {
  {
    version = "1.5.1",
    notes = {
      "Settings → Reputation no longer paints a full-page panel over the faction list, so Rank all and the factions stay readable.",
    },
  },
  {
    version = "1.5.0",
    notes = {
      "Dashboard tiles for Mythic+, currencies, PvP, item level, housing, calendar, guild, and journeys. Edit a tile to pick what it shows; live Honor and gold stay off until Done editing.",
      "Housing and PvP are goals. Neighborhood initiatives, housing weeklies already in the log, and weekly Conquest rank from the client.",
      "Click a tile again to close the client window it opened. Housing Teleport runs from the click so the client does not block it.",
      "The canvas grows down to 36 rows. Profession icons open that profession in front of Lodestar.",
      "Themes include GW2 UI and RealUI. The tip tour walks to the feature. Settings → Optional Addons lists which addons are loaded.",
    },
  },
  {
    version = "1.4.1",
    notes = {
      "Below the expansion cap, Great Vault and bountiful delves stay quiet. The plan is to level; professions still rank if that goal is on.",
    },
  },
  {
    version = "1.4.0",
    notes = {
      "Prey hunts are a goal. Dashboard widgets sit on a 12 × 18 canvas you drag and resize.",
      "The left menu collapses to icons. Compact mode lists tracked work only.",
    },
  },
  {
    version = "1.3.0",
    notes = {
      "The left menu is workspaces, not a second copy of Today's tabs.",
      "Questing ranks the current campaign and a few quests already in the log.",
    },
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
  { name = "Raider.IO", addon = "RaiderIO",
    ready = function() return RaiderIO and true end },
  { name = "ElvUI", addon = "ElvUI",
    ready = function(self) return self.GetElvUI and self:GetElvUI() and true end },
  { name = "GW2 UI", addon = "GW2_UI",
    ready = function(self) return self.GetGW2 and self:GetGW2() and true end },
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
