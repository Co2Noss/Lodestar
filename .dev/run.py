"""Headless checks for Lodestar.

Loads every addon file into a stubbed WoW client, fires the real login events, and drives
the UI by clicking the buttons a player would click. Run with: python .dev/run.py
"""

import os
import sys

from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)

# Load order must match the .toc.
FILES = [
    "Core.lua", "Themes.lua", "Catalog.lua", "Mounts.lua", "Reputation.lua", "Gold.lua", "Knowledge.lua", "Waypoints.lua", "Rares.lua", "PlayerData.lua",
    "Vault.lua", "Professions.lua", "Scoring.lua", "Warband.lua",
    "UI.lua", "Compact.lua", "Minimap.lua",
]

WALK_TEXTS = """
  (function()
    local out, seen = {}, {}
    local function visit(frame, depth)
      if depth > 14 or seen[frame] or frame.shown == false then return end
      seen[frame] = true
      for _, r in ipairs(frame.regions or {}) do
        if r.text_value and r.shown ~= false then table.insert(out, r.text_value) end
      end
      for _, c in ipairs(frame.children or {}) do visit(c, depth + 1) end
    end
    visit(__LS.frame, 0)
    return table.concat(out, "\\n")
  end)()
"""

FIND_BUTTON = """
  (function(label)
    local found, seen = nil, {}
    local function visit(frame, depth)
      if found or depth > 14 or seen[frame] or frame.shown == false then return end
      seen[frame] = true
      if frame.text and frame.text.text_value
         and frame.text.text_value:find(label, 1, true)
         and frame.scripts and frame.scripts.OnMouseUp then
        found = frame
        return
      end
      for _, c in ipairs(frame.children or {}) do visit(c, depth + 1) end
    end
    visit(__LS.frame, 0)
    return found
  end)
"""

failures = []


def check(label, ok, extra=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {label}" + (f" -- {extra}" if not ok and extra else ""))
    if not ok:
        failures.append(label)


class Session:
    """One simulated client, from file load through login."""

    def __init__(self, saved=None, deny_templates=()):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        stub = os.path.join(HERE, "wowstub.lua").replace("\\", "/")
        self.lua.execute(f'dofile("{stub}")')
        for template in deny_templates:
            self.lua.execute(f'DeniedTemplates["{template}"] = true')
        self.lua.execute("__LS = {}")
        for name in FILES:
            path = os.path.join(ADDON, name).replace("\\", "/")
            self.lua.execute(f'''
              local chunk, err = loadfile("{path}")
              if not chunk then error("load {name}: " .. tostring(err)) end
              local ok, ran = pcall(chunk, "Lodestar", __LS)
              if not ok then error("run {name}: " .. tostring(ran)) end
            ''')
        # Saved variables from a previous session, if this is not a fresh install.
        self.lua.execute(f"LodestarDB = {saved or 'nil'}")
        self.lua.execute("""
          for _, f in ipairs(AllFrames) do
            if not __eventFrame and f.scripts and f.scripts.OnEvent then __eventFrame = f end
          end
          if not __eventFrame then error("no event frame was registered") end
        """)

    def fire(self, event, arg=None):
        payload = f'"{arg}"' if arg else "nil"
        self.lua.execute(f"__eventFrame.scripts.OnEvent(nil, '{event}', {payload})")
        self.timers()

    def timers(self):
        self.lua.eval("FireTimers")()

    def eval(self, chunk):
        return self.lua.eval(chunk)

    def exec(self, chunk):
        self.lua.execute(chunk)

    def texts(self):
        return self.lua.eval(WALK_TEXTS)

    def printed(self):
        return self.lua.eval('table.concat(Printed, "\\n")')

    def click(self, label):
        button = self.lua.eval(FIND_BUTTON)(label)
        if button is None:
            raise AssertionError(f"no button labelled {label!r} on page "
                                 f"{self.eval('__LS.page')}")
        button.scripts.OnMouseUp(button, "LeftButton")
        self.timers()


GOALS = ["Great Vault & endgame", "Solo content", "Professions", "Mounts", "Reputation", "Questing", "Gold making"]

# --- a fresh install ------------------------------------------------------
print("-- fresh install --")
s = Session()
check("every file loads and runs", True)
s.fire("ADDON_LOADED", "Lodestar")

check("no goal is assumed", not s.eval("__LS:GoalsChosen()"))
check("the install is not marked as welcomed", s.eval("__LS.db.welcomed") is None)
check("nothing is recommended before the player is asked",
      s.eval("#__LS:GetRecommendations()") == 0, s.eval("#__LS:GetRecommendations()"))
check("the landing page is the welcome page", s.eval("__LS:LandingPage()") == "WELCOME")

s.fire("PLAYER_LOGIN")
check("login opens the window by itself", s.eval("__LS.frame:IsShown()") is True)
check("login lands on the welcome page", s.eval("__LS.page") == "WELCOME")
check("login says what to do first",
      "Pick what you care about to get started" in s.printed(), s.printed())

page = s.texts()
check("the welcome page introduces the addon", "Welcome to Lodestar" in page)
check("it states the premise", "what is worth doing" in page, page)
check("it offers every goal, all off", all(f"OFF  \u2022  {g}" in page for g in GOALS), page)
check("it requires a choice", "Choose at least one" in page, page)
check("it does not claim a plan exists yet",
      "change these at any time in Settings" not in page)

s.click("Solo content")
page = s.texts()
check("a chosen goal reads as on", "ON  \u2022  Solo content" in page, page)
check("choosing reveals that Settings can change it later",
      "change these at any time in Settings" in page, page)
check("choosing counts as having been asked", s.eval("__LS.db.welcomed") is True)
check("recommendations appear once a goal is on",
      s.eval("#__LS:GetRecommendations()") > 0)

s.click("Show me my plan")
check("continuing lands on Today", s.eval("__LS.page") == "TODAY")
page = s.texts()
check("Today shows the plan rather than an empty state",
      "Complete a Bountiful Delve" in page and "Every goal is off" not in page, page)
check("Today filters with tabs instead of collapsing",
      "Solo content" in page and "Collapse all" not in page and "Expand all" not in page,
      page)
check("the welcome page is not shown again",
      s.eval("__LS:LandingPage()") == "TODAY")

# --- choosing everything, and choosing nothing ----------------------------
print()
print("-- goal picking --")
s.exec("__LS:ShowPage('WELCOME')")
s.timers()
s.click("I care about all of it")
check("select all turns on every goal",
      s.eval("""(function()
        local n = 0
        for _, on in pairs(__LS.db.goals) do if on then n = n + 1 end end
        return n
      end)()""") == 7)
check("the same button becomes clear all", "Clear all" in s.texts())
s.click("Clear all")
check("clear all turns every goal off", not s.eval("__LS:GoalsChosen()"))
check("clearing does not re-trigger the welcome prompt",
      s.eval("__LS.db.welcomed") is True)

s.exec("__LS:ShowPage('TODAY')")
s.timers()
page = s.texts()
check("an empty Today explains itself", "Every goal is off" in page, page)
s.click("Choose my goals")
check("an empty Today routes back to goal picking", s.eval("__LS.page") == "WELCOME")

# --- an existing player upgrading ----------------------------------------
print()
print("-- upgrading from an older version --")
old = Session(saved="{ goals = { ENDGAME = true, CRAFTING = true }, theme = 'ELVUI' }")
old.fire("ADDON_LOADED", "Lodestar")
check("goals already chosen are kept", old.eval("__LS.db.goals.ENDGAME") is True)
check("an upgrade is treated as already welcomed", old.eval("__LS.db.welcomed") is True)
old.fire("PLAYER_LOGIN")
check("an upgrade is not interrupted by the welcome page",
      old.eval("__LS.page") != "WELCOME", old.eval("__LS.page"))
check("an upgrade gets the normal login line",
      "/ls to open" in old.printed(), old.printed())
check("an upgrade does not have its window forced open",
      old.eval("__LS.frame:IsShown()") is not True)

# --- the Blizzard theme -------------------------------------------------
print()
print("-- Blizzard theme --")
s.exec("__LS:SetTheme('BLIZZARD')")
s.timers()
check("the Blizzard theme uses Blizzard's own panel art",
      s.eval("__LS.chrome ~= nil") is True)
check("it uses the template Dragonflight introduced",
      s.eval("__LS.chrome and __LS.chrome.template") == "DefaultPanelTemplate",
      s.eval("__LS.chrome and __LS.chrome.template"))
check("the flat backdrop steps aside for it",
      s.eval("__LS.frame.bgColor and __LS.frame.bgColor[4]") == 0,
      s.eval("__LS.frame.bgColor and __LS.frame.bgColor[4]"))
check("the title bar stops drawing its own fill",
      s.eval("__LS.header.bgColor and __LS.header.bgColor[4]") == 0)
check("content moves inside the thicker border",
      s.eval("__LS.layoutPad") == 9, s.eval("__LS.layoutPad"))
check("the accent is the client's gold",
      abs(s.eval("__LS.colors.accent[2]") - 0.82) < 1e-6,
      s.eval("__LS.colors.accent[2]"))
check("warnings use the client's red",
      abs(s.eval("__LS.colors.warn[2]") - 0.125) < 1e-6)

s.exec("__LS:SetTheme('MINIMAL')")
s.timers()
check("another theme hides the Blizzard art",
      s.eval("__LS.chrome:IsShown()") is False)
check("and gets its flat backdrop back",
      s.eval("__LS.frame.bgColor[4]") > 0)
check("and drops the border padding", s.eval("__LS.layoutPad") == 0)

denied = Session(deny_templates=("DefaultPanelTemplate", "DialogBorderTemplate"))
denied.fire("ADDON_LOADED", "Lodestar")
denied.exec("__LS.db.welcomed = true; __LS:SetTheme('BLIZZARD')")
denied.timers()
check("a client without the panel art falls back instead of breaking",
      denied.eval("__LS.chrome") is None and denied.eval("__LS.chromeMissing") is True)
check("the fallback still paints a visible window",
      denied.eval("__LS.frame.bgColor[4]") > 0)
check("the fallback keeps its border", denied.eval("__LS.frame.borderColor[4]") > 0)

# --- player-chosen colours ----------------------------------------------
print()
print("-- custom colors --")
s.exec("__LS:SetTheme('BLIZZARD')")
s.timers()
check("no colors are customised to begin with", s.eval("__LS:HasCustomColors()") is False)
s.exec("__LS:ShowPage('SETTINGS')")
s.timers()
settings = s.texts()
check("Settings opens on Goals", s.eval("__LS:SettingsTab()[1]") == "GOALS")
check("the five settings tabs are on the strip",
      all(name in settings for name in ["Goals", "Reputation", "Appearance", "Compact", "Layout"]),
      settings)
check("Goals does not bury colors underneath it",
      "Click a color to change it" not in settings and "Accent" not in settings, settings)

s.click("Appearance")
check("Appearance is remembered", s.eval("__LS:SettingsTab()[1]") == "APPEARANCE")
settings = s.texts()
check("Appearance offers a color for every palette key",
      all(label in settings for label in
          ["Accent", "Text", "Background", "Panels", "Cards", "Borders", "Warnings", "Muted text"]),
      settings)
check("Appearance explains what editing a color does",
      "Click a color to change it" in settings, settings)
check("no reset button appears before anything is customised",
      "Reset colors to the theme" not in settings)

s.click("Accent")
check("clicking a color opens the picker", s.eval("ColorPickerFrame.pending ~= nil") is True)
s.lua.eval("ChooseColor")(0.2, 0.6, 0.9, 1.0)
s.timers()
check("the chosen color is applied",
      abs(s.eval("__LS.colors.accent[3]") - 0.9) < 1e-6, s.eval("__LS.colors.accent[3]"))
check("the choice is saved", s.eval("__LS.db.colors.accent.b") == 0.9)
check("the addon knows a color is customised", s.eval("__LS:HasCustomColors()") is True)
check("picking a color leaves you on Appearance",
      s.eval("__LS:SettingsTab()[1]") == "APPEARANCE")

s.exec("__LS:SetTheme('ELVUI')")
s.timers()
check("a chosen color survives switching themes",
      abs(s.eval("__LS.colors.accent[3]") - 0.9) < 1e-6, s.eval("__LS.colors.accent[3]"))
check("unchosen colors still follow the theme",
      s.eval("__LS.colors.bg[1]") == s.eval("__LS.palettes.ELVUI.bg[1]"))
check("changing theme does not bounce you off Appearance",
      s.eval("__LS:SettingsTab()[1]") == "APPEARANCE")

s.exec("__LS:ShowPage('SETTINGS')")
s.timers()
check("the customised row is marked as yours", "Accent  (yours)" in s.texts(), s.texts())
s.click("Reset colors to the theme")
check("resetting clears the override", s.eval("__LS:HasCustomColors()") is False)
check("resetting restores the theme accent",
      s.eval("__LS.colors.accent[1]") == s.eval("__LS.palettes.ELVUI.accent[1]"))

s.exec("__LS:ShowPage('SETTINGS')")
s.timers()
s.click("Accent")
s.lua.eval("CancelColor")()
s.timers()
check("cancelling the picker leaves the theme colour alone",
      s.eval("__LS.colors.accent[1]") == s.eval("__LS.palettes.ELVUI.accent[1]"))

s.click("Compact")
check("Compact shows the compact toggles and not the color picker",
      "Compact window" in s.texts() and "Accent" not in s.texts(), s.texts())
s.click("Layout")
check("Layout shows window controls and not goals",
      "Reset size and position" in s.texts() and "Great Vault & endgame" not in s.texts(),
      s.texts())
s.exec("__LS:ShowPage('TODAY'); __LS:ShowPage('SETTINGS')")
s.timers()
check("leaving Settings and coming back restores the last tab",
      s.eval("__LS:SettingsTab()[1]") == "LAYOUT")

# --- no debug output ----------------------------------------------------
print()
print("-- quiet theme changes --")
quiet = Session(saved="{ goals = { ENDGAME = true } }")
quiet.fire("ADDON_LOADED", "Lodestar")
quiet.fire("PLAYER_LOGIN")
before = quiet.printed()
quiet.exec("__LS:SetTheme('BLIZZARD'); __LS:SetTheme('ELVUI'); __LS:SetTheme('AUTO')")
quiet.timers()
check("changing themes prints nothing", quiet.printed() == before, quiet.printed())
check("the sidebar no longer carries a theme readout",
      quiet.eval("__LS.themeText") is None)
quiet.exec("__LS:PrintThemes()")
check("asking for the theme list still answers",
      "Lodestar themes" in quiet.printed())

# --- debug isolation ----------------------------------------------------
print()
print("-- debug isolation --")
iso = Session(saved="{ goals = { ENDGAME = true } }")
iso.fire("ADDON_LOADED", "Lodestar")
iso.exec('ReloadedUI = false')
shown = iso.eval("__LS.frame:IsShown()")
iso.exec('SlashCmdList.LODESTAR("debug")')
check("debug disables other user addons",
      iso.eval('C_AddOns.GetAddOnEnableState("ElvUI")') == 0
      and iso.eval('C_AddOns.GetAddOnEnableState("Details")') == 0)
check("debug keeps Lodestar enabled",
      iso.eval('C_AddOns.GetAddOnEnableState("Lodestar")') > 0)
check("debug leaves Blizzard addons alone",
      iso.eval('C_AddOns.GetAddOnEnableState("Blizzard_WeeklyRewards")') > 0)
check("debug does not enable addons that were already off",
      iso.eval('C_AddOns.GetAddOnEnableState("SomeDisabled")') == 0)
check("debug remembers which addons to restore",
      iso.eval('LodestarDebugDB.active') is True
      and iso.eval('LodestarDebugDB.addons[1]') == "ElvUI"
      and iso.eval('LodestarDebugDB.addons[2]') == "Details")
check("debug reloads the UI", iso.eval("ReloadedUI") is True)
check("debug does not toggle the window",
      iso.eval("__LS.frame:IsShown()") == shown)

iso.exec('ReloadedUI = false')
iso.exec('SlashCmdList.LODESTAR("debug on")')
check("debug on while already isolated does not reload again",
      iso.eval("ReloadedUI") is not True, iso.printed())

iso.exec('ReloadedUI = false')
iso.exec('SlashCmdList.LODESTAR("debug")')
check("a second /ls debug restores the other addons",
      iso.eval('C_AddOns.GetAddOnEnableState("ElvUI")') > 0
      and iso.eval('C_AddOns.GetAddOnEnableState("Details")') > 0)
check("restore still leaves previously disabled addons off",
      iso.eval('C_AddOns.GetAddOnEnableState("SomeDisabled")') == 0)
check("restore clears the isolation flag",
      iso.eval("LodestarDebugDB.active") is not True)
check("restore reloads the UI", iso.eval("ReloadedUI") is True)

iso.exec('ReloadedUI = false')
iso.exec('SlashCmdList.LODESTAR("debug off")')
check("debug off while not isolated does not reload",
      iso.eval("ReloadedUI") is not True)

combat = Session(saved="{ goals = { ENDGAME = true } }")
combat.fire("ADDON_LOADED", "Lodestar")
combat.exec("InCombatLockdown = function() return true end")
combat.exec("ReloadedUI = false")
combat.exec('SlashCmdList.LODESTAR("debug")')
check("debug refuses to isolate in combat",
      combat.eval("ReloadedUI") is not True
      and combat.eval('C_AddOns.GetAddOnEnableState("ElvUI")') > 0)
check("combat isolation explains itself",
      "leave combat" in combat.printed(), combat.printed())

login = Session(saved="{ goals = { ENDGAME = true } }")
login.exec('LodestarDebugDB = { active = true, addons = { "ElvUI", "Details" } }')
login.fire("ADDON_LOADED", "Lodestar")
login.fire("PLAYER_LOGIN")
check("login warns when isolation is still on",
      "debug isolation is on" in login.printed(), login.printed())

reset = Session(saved="{ goals = { ENDGAME = true } }")
reset.fire("ADDON_LOADED", "Lodestar")
reset.exec('LodestarDebugDB = { active = true, addons = { "ElvUI" } }')
reset.exec('SlashCmdList.LODESTAR("reset")')
check("reset does not forget which addons to restore",
      reset.eval("LodestarDebugDB.active") is True
      and reset.eval('LodestarDebugDB.addons[1]') == "ElvUI")

# --- regression ----------------------------------------------------------
print()
print("-- regression --")
s.exec("""
  for _, key in ipairs({ "ENDGAME", "SOLO", "CRAFTING" }) do __LS.db.goals[key] = true end
  __LS:ScanVault()
  __LS:ScanProfessions()
""")
check("vault recommendations still generate", s.eval("#__LS:GetVaultRecommendations()") > 0)
s.exec("C_WeeklyRewards.HasAvailableRewards = function() return true end")
claim = s.eval("""(function()
  for _, r in ipairs(__LS:GetVaultRecommendations()) do
    if (r.title or ""):find("Claim", 1, true) then return r.title end
  end
end)()""")
check("an unclaimed Great Vault is recommended after reset",
      claim == "Claim last week's Great Vault", claim)
s.exec("C_WeeklyRewards.HasAvailableRewards = function() return false end")
s.exec("""
  _G.__oldGetActivities = C_WeeklyRewards.GetActivities
  C_WeeklyRewards.GetActivities = function(kind)
    local all = {
      { type = 1, index = 1, level = 0, threshold = 2, progress = 0, id = 1 },
      { type = 1, index = 2, level = 0, threshold = 4, progress = 0, id = 2 },
      { type = 1, index = 3, level = 0, threshold = 6, progress = 0, id = 3 },
    }
    if not kind then return all end
    local out = {}
    for _, activity in ipairs(all) do
      if activity.type == kind then table.insert(out, activity) end
    end
    return out
  end
  __LS:ScanVault()
""")
raid_slots = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetVaultRecommendations()) do
    local why = r.why or ""
    if why:find("Raid Vault slot", 1, true) then table.insert(out, why) end
  end
  return table.concat(out, "\\n")
end)()""")
check("an empty Raid Vault only recommends the first unfilled slot",
      "slot 1" in raid_slots and "slot 2" not in raid_slots and "slot 3" not in raid_slots,
      raid_slots)
s.exec("""
  C_WeeklyRewards.GetActivities = _G.__oldGetActivities
  __LS:ScanVault()
""")
check("gold making stays quiet without a price addon",
      s.eval("#__LS:GetGoldRecommendations()") == 0)
s.exec("""
  __LS.db.goals.GOLD = true
  Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id)
    local prices = { [210796] = 8000, [210805] = 25000, [210808] = 22000, [210802] = 18000, [210807] = 20000,
                     [236767] = 9000, [236770] = 22000, [236774] = 20000, [236776] = 18000, [236778] = 21000,
                     [212664] = 10000, [238511] = 12000, [236963] = 9000, [237015] = 25000, [237017] = 24000,
                     [224828] = 8000, [33470] = 9000, [21877] = 7000, [10822] = 450000 }
    return prices[id]
  end } } }
""")
gold = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetGoldRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("herbalism gold farms rank once Auctionator has prices",
      "Herb Khaz Algar" in gold, gold)
check("midnight herbalism ranks with the same profession",
      "Herb Midnight" in gold, gold)
check("a pet farm ranks when it has an AH listing",
      "Dark Whelplings" in gold, gold)
check("mining stays quiet without that profession",
      "Mine Khaz Algar" not in gold and "Mine Midnight" not in gold, gold)
check("skinning stays quiet without that profession",
      "Skin Khaz Algar" not in gold and "Skin Midnight" not in gold, gold)
check("legacy cloth ranks without tailoring",
      "Frostweave" in gold and "Netherweave" in gold, gold)
check("expansion cloth stays quiet without tailoring",
      "Midnight cloth" not in gold and "Khaz Algar cloth" not in gold, gold)
s.exec("table.insert(__LS.professions, { parentID = 393, name = 'Skinning' })")
gold = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetGoldRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("skinning gold farms rank once that profession is trained",
      "Skin Midnight" in gold and "Skin Khaz Algar" in gold, gold)
s.exec("table.insert(__LS.professions, { parentID = 197, name = 'Tailoring' })")
gold = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetGoldRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("tailoring cloth farms rank once that profession is trained",
      "Midnight cloth" in gold and "Khaz Algar cloth" in gold, gold)
s.exec("""
  for i = #__LS.professions, 1, -1 do
    if __LS.professions[i].parentID == 393 or __LS.professions[i].parentID == 197 then
      table.remove(__LS.professions, i)
    end
  end
  __LS.db.goals.GOLD = false
  Auctionator = nil
""")
check("a world slot below the cap is not called maxed",
      "Maxed" not in (s.eval("""(function()
        local out = {}
        for _, r in ipairs(__LS:GetVaultRecommendations()) do
          table.insert(out, (r.title or "") .. " " .. (r.why or ""))
        end
        return table.concat(out, "\\n")
      end)()""") or ""))
check("the plan still groups into categories", s.eval("#(select(1, __LS:GetCategories()))") > 0)
for name in ["TODAY", "VAULT", "PROFESSIONS", "WARBAND", "SETTINGS", "WELCOME", "DETAILS"]:
    s.exec(f"__LS:ShowPage('{name}')")
    s.timers()
    check(f"the {name} page renders", len(s.texts()) > 0)

s.exec("__LS:ShowPage('VAULT')")
s.timers()
vault = s.texts()
check("Great Vault opens on Raid", s.eval("__LS:PageTab('VAULT')") == "raid")
check("Great Vault shows Raid, Dungeons and World tabs",
      all(name in vault for name in ["Raid", "Dungeons", "World"]), vault)
check("the Raid tab does not list World run tiers", "best 11" not in vault, vault)
s.click("World")
check("the World tab is remembered", s.eval("__LS:PageTab('VAULT')") == "world")
check("the World tab shows this week's delve tiers", "best 11" in s.texts(), s.texts())

s.exec("__LS:ShowPage('PROFESSIONS')")
s.timers()
prof = s.texts()
check("Professions tabs include each trained profession",
      "Alchemy" in prof and "Herbalism" in prof, prof)
check("Professions tabs include Cooking, Fishing and Archaeology",
      "Cooking" in prof and "Fishing" in prof and "Archaeology" in prof, prof)
check("a primary profession offers the trade skill window and specializations",
      "Open Alchemy" in prof and "Specializations" in prof, prof)
s.exec("OpenedTradeSkills = {}")
s.click("Herbalism")
check("the selected profession tab is remembered",
      s.eval("__LS:PageTab('PROFESSIONS')") is not None)
check("clicking a profession tab opens that profession",
      s.eval("OpenedTradeSkills[#OpenedTradeSkills]") == 2823,
      s.eval("table.concat(OpenedTradeSkills, ',')"))
s.click("Fishing")
fish = s.texts()
check("a secondary profession shows skill instead of a knowledge tree",
      "Skill 50 / 100" in fish
      and "no knowledge tree" in fish
      and "tree size unknown" not in fish, fish)
check("a secondary profession opens the skill window without specializations",
      "Open Fishing" in fish and "Specializations" not in fish, fish)
levels = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetProfessionRecommendations()) do
    if (r.id or ""):find("prof_level_", 1, true) then table.insert(out, r.title) end
  end
  return table.concat(out, "\\n")
end)()""")
check("an unmaxed secondary profession is recommended for leveling",
      "Fishing" in levels and "Cooking" in levels and "Archaeology" in levels, levels)
check("midnight tailoring tracks eight world treasures plus vendor books",
      s.eval("""(function()
        local n = 0
        for _, o in ipairs(__LS.knowledgeSources[2918].objectives) do
          if o.kind == "TREASURE" then n = n + 1 end
        end
        return n
      end)()""") == 10)
check("midnight skinning tracks eight world treasures plus vendor books",
      s.eval("""(function()
        local n = 0
        for _, o in ipairs(__LS.knowledgeSources[2917].objectives) do
          if o.kind == "TREASURE" then n = n + 1 end
        end
        return n
      end)()""") == 11)

# --- waypoints ----------------------------------------------------------
print()
print("-- waypoints --")
check("alchemy peacebloom has a WeeklyKnowledge coordinate",
      s.eval("__LS.knowledgeSources[2906].objectives[3].map") == 2393
      and abs(s.eval("__LS.knowledgeSources[2906].objectives[3].x") - 49.11) < 0.01,
      s.eval("__LS.knowledgeSources[2906].objectives[3].map"))
s.exec("UserWaypoint = nil; SuperTrackedUserWaypoint = false")
s.exec("""
  __LS:MarkWaypoints({ { map = 2393, x = 49.11, y = 75.84, title = "Peacebloom" } })
""")
check("without TomTom the client pin is used",
      s.eval("UserWaypoint ~= nil and UserWaypoint.uiMapID") == 2393)
check("the client pin is super-tracked",
      s.eval("SuperTrackedUserWaypoint") is True)
s.exec("""
  TomTomWaypoints = {}
  TomTomClosest = false
  TomTom = {
    AddWaypoint = function(_, map, x, y, opts)
      local uid = { map = map, x = x, y = y, title = opts and opts.title }
      table.insert(TomTomWaypoints, uid)
      return uid
    end,
    RemoveWaypoint = function() end,
    SetClosestWaypoint = function() TomTomClosest = true end,
  }
  UserWaypoint = nil
  __LS:MarkWaypoints({
    { map = 2393, x = 49.11, y = 75.84, title = "A" },
    { map = 2393, x = 47.75, y = 51.67, title = "B" },
  })
""")
check("TomTom pins every remaining point",
      s.eval("#TomTomWaypoints") == 2, s.eval("#TomTomWaypoints"))
check("TomTom aims the arrow at the closest pin",
      s.eval("TomTomClosest") is True)
s.exec("OpenedWorldMaps = {}; TomTom = nil")
s.exec("""
  __LS:MarkWaypoints({
    { map = 2395, title = "Eversong Woods" },
    { map = 2437, title = "Zul'Aman" },
  })
""")
check("a zone circuit opens the first map when there are no coordinates",
      s.eval("OpenedWorldMaps[1]") == 2395, s.eval("OpenedWorldMaps[1]"))

print()
print("-- handynotes rares --")
check("without HandyNotes rares stay off the plan",
      s.eval("#__LS:GetHandyNotesRecommendations()") == 0)
s.exec("""
  local A, B = 49117584, 47755167
  local visible = { [A] = true, [B] = true }
  HandyNotes = {
    plugins = {
      Rares = {
        GetNodes2 = function(_, mapID)
          if mapID ~= 2393 then return function() end end
          return pairs(visible)
        end,
        OnEnter = function(_, _, coord)
          GameTooltip:SetText(coord == A and "Peacebloom Rare" or "Other Rare")
        end,
      },
      Known = {
        GetNodes2 = function() return function() end end,
      },
    },
    db = { profile = { enabled = true, enabledPlugins = { Rares = true, Known = true } } },
    getXY = function(_, id)
      return math.floor(id / 10000) / 10000, (id % 10000) / 10000
    end,
  }
""")
hn = s.eval("""(function()
  local recs = __LS:GetHandyNotesRecommendations()
  local r = recs[1]
  if not r then return "none" end
  local titles = {}
  for _, p in ipairs(r.waypoints or {}) do table.insert(titles, p.title) end
  return table.concat({
    tostring(#recs), r.id, r.title, r.category, tostring(#r.waypoints),
    table.concat(titles, ","),
  }, "|")
end)()""")
check("HandyNotes ranks one solo rec for the visibles it is showing",
      hn.startswith("1|hn_rares_2393|Hunt 2 rares HandyNotes is showing in Silvermoon City|Solo content|2|")
      and "Peacebloom Rare" in hn and "Other Rare" in hn, hn)
check("FindActivity can open that HandyNotes rec",
      s.eval('__LS:FindActivity("hn_rares_2393") ~= nil') is True)
ranked = s.eval("""(function()
  for _, r in ipairs(__LS:GetRecommendations()) do
    if r.id == "hn_rares_2393" then return r.title end
  end
end)()""")
check("Solo content ranks HandyNotes rares",
      ranked and "HandyNotes" in ranked, ranked)
s.exec("__LS.db.goals.SOLO = false")
check("HandyNotes rares stay quiet while Solo content is off",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.id == "hn_rares_2393" then return true end
        end
        return false
      end)()""") is False)
s.exec("__LS.db.goals.SOLO = true")
s.exec("HandyNotes.db.profile.enabledPlugins.Rares = false")
check("a disabled HandyNotes plugin is skipped",
      s.eval("#__LS:GetHandyNotesRecommendations()") == 0)
s.exec("HandyNotes.db.profile.enabledPlugins.Rares = true")
s.exec("HandyNotes.plugins.Rares.GetNodes2 = function() return function() end end")
check("known-hidden HandyNotes pins stay off the plan",
      s.eval("#__LS:GetHandyNotesRecommendations()") == 0)
s.exec("""
  local many = {}
  for i = 1, 12 do
    many[(4800 + i) * 10000 + 5000] = true
  end
  many[500 * 10000 + 500] = true
  many[600 * 10000 + 500] = true
  many[700 * 10000 + 500] = true
  HandyNotes.plugins.Rares.GetNodes2 = function(_, mapID)
    if mapID ~= 2393 then return function() end end
    return pairs(many)
  end
  HandyNotes.plugins.Rares.OnEnter = nil
""")
capped = s.eval("""(function()
  local r = __LS:GetHandyNotesRecommendations()[1]
  if not r then return "none" end
  return tostring(#r.waypoints) .. "|" .. r.title
end)()""")
check("HandyNotes waypoints cap at the closest 12",
      capped.startswith("12|Hunt 15 rares"), capped)
s.exec("__LS:SetPageTab('SETTINGS', 'GOALS'); __LS:ShowPage('SETTINGS')")
s.timers()
check("Settings notes that HandyNotes is loaded",
      "HandyNotes is loaded" in s.texts(), s.texts())
s.exec("HandyNotes = nil")

check("cards rank as High, Medium or Low",
      s.eval('(function() local a = __LS:Urgency({urgency="HIGH"}); return a end)()') == "High"
      and s.eval('(function() local a = __LS:Urgency({urgency="MEDIUM"}); return a end)()') == "Medium"
      and s.eval('(function() local a = __LS:Urgency({urgency="LOW"}); return a end)()') == "Low")

s.exec("__LS:ShowPage('TODAY')")
s.timers()
today = s.texts()
check("Today with several goals shows a tab per category",
      "Great Vault" in today and "Solo content" in today, today)
check("Today no longer has Collapse all", "Collapse all" not in today)

s.exec("""
  local oldWorld = C_WeeklyRewards.GetActivities
  C_WeeklyRewards.GetActivities = function(kind)
    local data = oldWorld(kind)
    for _, activity in ipairs(data) do
      if activity.type == 3 then
        activity.level = 11
        activity.progress = activity.threshold
      end
    end
    return data
  end
  C_WeeklyRewards.GetSortedProgressForActivity = function(kind)
    local id = type(kind) == "table" and kind.type or kind
    if id == 3 then
      local out = {}
      for i = 1, 8 do out[i] = { difficulty = 11, numPoints = 1 } end
      return out
    end
    return {}
  end
  Currencies[3028] = { quantity = 0 }
  Currencies[3310] = { quantity = 0, quantityEarnedThisWeek = 600, maxWeeklyQuantity = 600 }
  GildedStashTooltip = "4/4"
  __LS:ScanVault()
""")
delve_done = s.eval("""(function()
  for _, r in ipairs(__LS:GetRecommendations()) do
    if r.id == "delve" then return true end
  end
  return false
end)()""")
check("a finished World Vault with no keys, no shards and Gilded Stashes done stays quiet about Bountiful Delves",
      delve_done is False)
s.exec("""
  Currencies[3028] = { quantity = 2 }
  GildedStashTooltip = nil
  __LS:ScanVault()
""")

s.exec("__LS.db.goals.MOUNTS = true")
s.exec("__LS:ShowPage('TODAY')")
s.timers()
mounts = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetMountRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("a missing Invincible is recommended while ICC is open",
      "Invincible" in mounts and "Icecrown" in mounts, mounts)
check("Today grows a Mounts tab once that goal is on",
      "Mounts" in s.texts(), s.texts())

s.exec("CollectedMounts[363] = true; __LS:ScanMounts()")
after_collect = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetMountRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("a collected Invincible is not recommended again",
      "Invincible" not in after_collect, after_collect)

s.exec("CollectedMounts[363] = nil; __LS:ScanMounts()")
s.exec("""
  SavedInstances[1] = {
    name = "Icecrown Citadel", difficulty = 6, locked = true, instanceID = 631,
    numEncounters = 12, encounterProgress = 12,
    encounters = { [12] = { name = "The Lich King", killed = true } },
  }
""")
after_lock = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetMountRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("ICC 25 Heroic with the Lich King dead is not recommended",
      "Invincible" not in after_lock, after_lock)

s.exec("""
  SavedInstances[1].encounters[12].killed = false
  SavedInstances[1].encounterProgress = 11
""")
mid_run = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetMountRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("an unfinished ICC lockout still recommends Invincible",
      "Invincible" in mid_run, mid_run)

s.exec("SavedInstances = {}; CollectedMounts[185] = true; __LS:ScanMounts()")
dungeons = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetMountRecommendations()) do
    if r.urgency == "LOW" then table.insert(out, r.title) end
  end
  return table.concat(out, "\\n")
end)()""")
check("a collected dungeon mount stays quiet",
      "Raven Lord" not in dungeons, dungeons)
check("an uncollected dungeon mount is still farmable any time",
      "Blue Proto-Drake" in dungeons, dungeons)

s.exec("__LS.db.goals.REPUTATION = true")
s.exec("__LS:ScanReputations()")
check("reputation stays quiet until the player picks expansions or factions",
      s.eval("#__LS:GetReputationRecommendations()") == 0)
s.exec("__LS:SetRepExpansion('The War Within', true)")
rep = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetReputationRecommendations()) do
    table.insert(out, (r.section or "") .. " | " .. r.title)
  end
  return table.concat(out, "\\n")
end)()""")
check("an unfinished War Within faction is recommended once that expansion is on",
      "Zul'jarra" in rep and "Council of Dornogal" in rep, rep)
check("reputation cards are grouped by subcategory",
      "Khaz Algar" in rep and "Undermine" in rep, rep)
check("an exalted faction is not recommended",
      "Valdrakken" not in rep, rep)

s.exec("__LS:SetRepFaction(2590, false)")
rep_off = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetReputationRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("a faction turned off in Settings is not recommended",
      "Council of Dornogal" not in rep_off and "Zul'jarra" in rep_off, rep_off)

s.exec("__LS:SetPageTab('SETTINGS', 'REPUTATION'); __LS:ShowPage('SETTINGS')")
s.timers()
rep_settings = s.texts()
check("Settings Reputation lists expansions and factions from the client",
      "The War Within" in rep_settings and "Khaz Algar" in rep_settings
      and "Council of Dornogal" in rep_settings, rep_settings)
check("Settings Reputation opens on the first expansion tab",
      s.eval("__LS:PickTab(__LS:RepExpansionTabs(), __LS:PageTab('REP'))[1]")
      == "The War Within")
s.click("Dragonflight")
check("the Reputation expansion tab is remembered",
      s.eval("__LS:PageTab('REP')") == "Dragonflight")
df_settings = s.texts()
check("an expansion tab shows that expansion's factions, not the others",
      "Valdrakken Accord" in df_settings and "Council of Dornogal" not in df_settings,
      df_settings)
s.click("The War Within")
check("switching back shows War Within categories again",
      "Khaz Algar" in s.texts() and "Valdrakken Accord" not in s.texts(), s.texts())

s.exec("__LS.db.goals.REPUTATION = false")
s.exec("__LS:SetPageTab('SETTINGS', 'REPUTATION'); __LS:ShowPage('SETTINGS')")
s.timers()
nudge = s.texts()
check("picking a faction with the goal off suggests turning Reputation on",
      "Reputation is not one of your goals" in nudge
      and "Turn on the Reputation goal" in nudge, nudge)
s.click("Turn on the Reputation goal")
check("the suggestion turns the Reputation goal on",
      s.eval("__LS.db.goals.REPUTATION") is True)
s.exec("__LS:ShowPage('SETTINGS')")
s.timers()
check("the suggestion leaves once the goal is on",
      "Turn on the Reputation goal" not in s.texts(), s.texts())

s.exec("__LS.frame:Show(); __LS.frame.scripts.OnKeyDown(__LS.frame, 'ESCAPE')")
check("Escape closes the main window", s.eval("__LS.frame:IsShown()") is not True)
check("the main window is registered to close on Escape",
      s.eval("""(function()
        for _, name in ipairs(UISpecialFrames) do
          if name == "LodestarFrame" then return true end
        end
      end)()""") is True)

s.exec("__LS:SetCompact(true); __LS.frame:Hide(); __LS:UpdateCompact()")
s.timers()
check("compact mode still has rows", s.eval("#__LS:CompactActivities()") > 0)
s.exec("""
  for k in pairs(__LS.db.goals) do __LS.db.goals[k] = false end
  __LS.db.goals.ENDGAME = true
  __LS.db.compact.single = false
  __LS.db.compact.collapsed = false
  __LS:UpdateCompact()
""")
check("one goal keeps compact to a single row",
      s.eval("__LS:CompactCount()") == 1 and s.eval("#__LS:CompactActivities()") == 1)
height1 = s.eval("__LS.compact:GetHeight()")
s.exec("__LS.db.goals.CRAFTING = true; __LS:UpdateCompact()")
check("a second goal expands compact to two rows",
      s.eval("__LS:CompactCount()") == 2 and s.eval("#__LS:CompactActivities()") == 2)
height2 = s.eval("__LS.compact:GetHeight()")
check("compact grows taller when a second row appears", height2 > height1, (height1, height2))
s.exec("__LS.db.compact.collapsed = true; __LS:UpdateCompact()")
height0 = s.eval("__LS.compact:GetHeight()")
check("collapsing compact contracts to the title bar", height0 < height1, (height0, height1))
s.exec("__LS.db.compact.collapsed = false; __LS:UpdateCompact()")
check("the window sits above nameplates",
      s.eval('__LS.frame.frameStrata') == "DIALOG")
check("compact sits above nameplates",
      s.eval('__LS.compact and __LS.compact.frameStrata') == "DIALOG")

print()
if failures:
    print(f"{len(failures)} failed: " + ", ".join(failures))
    sys.exit(1)
print("all checks passed")
