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
    "Vault.lua", "Delves.lua", "Prey.lua", "PvP.lua", "Pets.lua", "Housing.lua", "Readiness.lua", "Quests.lua", "Professions.lua", "Scoring.lua", "Warband.lua",
    "Tips.lua", "UI.lua", "Dashboard.lua", "Widgets.lua", "Compact.lua", "Minimap.lua",
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
        self.lua.eval("ClickFrame")(button, "LeftButton")
        self.timers()


GOALS = ["Great Vault & endgame", "Solo content", "Prey hunts", "PvP", "Housing", "Professions", "Mounts", "Battle Pets", "Reputation", "Questing", "Gold making"]

# --- a fresh install ------------------------------------------------------
print("-- fresh install --")
s = Session()
check("every file loads and runs", True)
check("/lodestar is an alias for /ls",
      s.eval("SLASH_LODESTAR1") == "/ls"
      and s.eval("SLASH_LODESTAR2") == "/lodestar"
      and s.eval("type(SlashCmdList.LODESTAR)") == "function")
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
check("continuing opens the first-run tips",
      s.eval("__LS.page") == "SETTINGS" and s.eval("__LS.coachActive") is True)
tips = s.texts()
check("the first tip can be skipped or advanced",
      "Skip" in tips and "Next" in tips and "Goals decide the plan" in tips, tips)
check("the first tip walks to Settings Goals",
      "Great Vault & endgame" in tips and s.eval("__LS:SettingsTab()[1]") == "GOALS", tips)
s.click("Next")
check("Next shows the following tip",
      s.eval("__LS.page") == "DASHBOARD" and "Dashboard is yours" in s.texts(), s.texts())
s.click("Skip")
check("Skip hides the rest and lands on Today", s.eval("__LS.page") == "TODAY")
page = s.texts()
check("Today shows the plan rather than an empty state",
      "Complete a Bountiful Delve" in page and "Every goal is off" not in page, page)
check("Today filters with tabs instead of collapsing",
      "Solo content" in page and "Collapse all" not in page and "Expand all" not in page,
      page)
check("the sidebar is workspaces rather than content categories",
      s.eval("""(function()
        return __LS.nav.DASHBOARD ~= nil and __LS.nav.WEEKLY ~= nil
          and __LS.nav.LONGTERM ~= nil and __LS.nav.PROGRESS ~= nil
          and __LS.nav.IGNORED ~= nil and __LS.nav.COMPLETED ~= nil
          and __LS.nav.FAQ ~= nil and __LS.nav.HELP ~= nil
          and __LS.nav.VAULT == nil and __LS.nav.PROFESSIONS == nil
      end)()""") is True)
check("sidebar sections are higher-level workspaces",
      "PLANNING" in page and "TRACKING" in page and "ACCOUNT" in page
      and "Today's Plan" in page and "Dashboard" in page, page)
check("the sidebar shows the current version below the account menu",
      ("v" + s.eval("__LS.version")) in page, page)
s.exec("__LS:SetSidebarCollapsed(true)")
s.timers()
check("collapsing the sidebar shrinks it to icons",
      s.eval("__LS.sidebar:GetWidth()") == 52)
check("collapsed sidebar still shows the version at the bottom",
      ("v" + s.eval("__LS.version")) in s.texts()
      and s.eval("__LS.sidebarVersion:IsShown()") is True, s.texts())
check("collapsed nav shows an icon instead of the full name",
      s.eval("__LS.nav.TODAY.icon and __LS.nav.TODAY.icon.texture") is not None
      and s.eval("__LS.nav.TODAY.text:GetText()") in ("", None)
      and s.eval("__LS.nav.DASHBOARD.icon and __LS.nav.DASHBOARD.icon.texture") is not None
      and s.eval("__LS.nav.WARBAND.icon and __LS.nav.WARBAND.icon.texture or ''").lower().find("spell_fire_fire") != -1
      and s.eval("__LS.nav.FAQ.icon and __LS.nav.FAQ.icon.texture or ''").lower().find("knowledgebase") != -1
      and s.eval("__LS.nav.HELP.icon and __LS.nav.HELP.icon.texture or ''").lower().find("inv_misc_book_09") != -1)
s.exec("__LS.nav.TODAY.scripts.OnEnter(__LS.nav.TODAY)")
check("hovering a collapsed nav icon names the workspace",
      s.eval("GameTooltip._tip") == "Today's Plan")
s.exec("__LS:SetSidebarCollapsed(false)")
s.timers()
check("expanding the sidebar restores labels",
      s.eval("__LS.nav.TODAY.text:GetText()") == "Today's Plan"
      and s.eval("__LS.nav.FAQ.text:GetText()") == "FAQ"
      and s.eval("__LS.nav.HELP.text:GetText()") == "Help"
      and s.eval("__LS.sidebar:GetWidth()") == 180)
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
      end)()""") == 11)
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
      "/ls or /lodestar to open" in old.printed(), old.printed())
check("an upgrade does not have its window forced open",
      old.eval("__LS.frame:IsShown()") is not True)
old.exec("__LS:Toggle()")
old.timers()
check("an upgrade sees new-feature tips, not the first-run tour",
      old.eval("__LS.page") == "SETTINGS"
      and old.eval("__LS.coachActive") is True
      and "Housing and PvP" in old.texts()
      and "Goals decide the plan" not in old.texts())
old.exec("__LS.frame:Hide()")

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
check("the Blizzard panel art stays behind the logo and title",
      s.eval("__LS.header:GetFrameLevel() > __LS.chrome:GetFrameLevel()") is True)
check("the title sits below the Blizzard title-bar lip",
      s.eval("""(function()
        local pt = __LS.header.points and __LS.header.points[1]
        return pt and pt[1] == "TOPLEFT" and pt[3] or 0
      end)()""") == -26)
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
check("and puts the title back at the top of the frame",
      s.eval("""(function()
        local pt = __LS.header.points and __LS.header.points[1]
        return pt and pt[3] or 0
      end)()""") == -1)

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
check("the seven settings tabs are on the strip",
      all(name in settings for name in
          ["Goals", "Optional Addons", "Reputation", "Appearance", "Compact", "Layout", "Changelog"]),
      settings)
check("Goals does not bury colors underneath it",
      "Click a color to change it" not in settings and "Accent" not in settings, settings)
check("Goals does not bury addon options",
      "Gold prices" not in settings and "Waypoints" not in settings, settings)
s.click("Optional Addons")
check("Optional Addons is remembered", s.eval("__LS:SettingsTab()[1]") == "ADDONS")
addons = s.texts()
check("Optional Addons has gold prices, waypoints, and HandyNotes",
      "Gold prices" in addons and "Waypoints" in addons and "HandyNotes" in addons, addons)
check("Optional Addons lists every addon Lodestar talks to",
      all(name in addons for name in
          ["TradeSkillMaster", "Auctionator", "RECrystallize", "TomTom",
           "HandyNotes", "Raider.IO", "ElvUI", "GW2 UI", "RealUI", "Great Vault Key Info"]),
      addons)
check("unloaded addons read as not loaded",
      "TradeSkillMaster  ·  Not loaded" in addons and "TomTom  ·  Not loaded" in addons, addons)
s.exec("TomTom = { AddWaypoint = function() end }")
check("a loaded addon reports as loaded",
      s.eval("""(function()
        for _, row in ipairs(__LS:OptionalAddonStatus()) do
          if row.name == "TomTom" then return row.loaded end
        end
      end)()""") is True)
s.exec("TomTom = nil")
s.click("Changelog")
check("Changelog is remembered", s.eval("__LS:SettingsTab()[1]") == "CHANGELOG")
log = s.texts()
check("Changelog shows the last five versions",
      all(name in log for name in ["1.5.4", "1.5.31", "1.5.3", "1.5.21", "1.5.2"]), log)
gap = s.eval("""(function()
  local ys, seen = {}, {}
  local function visit(frame, depth)
    if depth > 18 or seen[frame] or frame.shown == false then return end
    seen[frame] = true
    for _, r in ipairs(frame.regions or {}) do
      local t = r.text_value
      if type(t) == "string" and t:find("•", 1, true) == 1 and r.points and r.points[1] then
        table.insert(ys, tonumber(r.points[1][3]) or 0)
      end
    end
    for _, c in ipairs(frame.children or {}) do visit(c, depth + 1) end
  end
  visit(__LS.frame, 0)
  table.sort(ys, function(a, b) return a > b end)
  if #ys < 2 then return 999 end
  return math.abs(ys[1] - ys[2])
end)()""")
check("changelog bullets sit closer than a blank line", gap < 24, gap)

s.click("Appearance")
check("Appearance is remembered", s.eval("__LS:SettingsTab()[1]") == "APPEARANCE")
settings = s.texts()
check("Appearance offers a color for every palette key",
      all(label in settings for label in
          ["Accent", "Text", "Background", "Panels", "Cards", "Borders", "Warnings", "Muted text"]),
      settings)
check("Appearance explains what editing a color does",
      "Click a color to change it" in settings, settings)
check("Appearance can lock the minimap button to the minimap",
      "Lock to the minimap" in settings
      and "Drag slides the button around the minimap edge." in settings, settings)
check("the minimap button is locked to the minimap by default",
      s.eval("__LS:MinimapButtonLocked() and __LS.minimapButton.parent == Minimap") is True)
s.exec("""
  local p = __LS.minimapButton.points and __LS.minimapButton.points[#__LS.minimapButton.points]
  MinimapAnchor = p and p[1]
  MinimapRel = p and p[3]
  MinimapX = p and tonumber(p[4]) or 0
  MinimapY = p and tonumber(p[5]) or 0
""")
check("locked minimap button sits on the minimap rim",
      s.eval("MinimapAnchor") == "CENTER" and s.eval("MinimapRel") == "CENTER")
check("locked minimap button is not at the minimap center",
      abs(s.eval("MinimapX")) > 1 or abs(s.eval("MinimapY")) > 1)
s.exec("CursorX, CursorY = 200, 70; __LS:DragMinimapButton()")
check("dragging a locked minimap button slides it around the edge",
      abs(s.eval("__LS.db.minimap.angle")) < 1
      or abs(s.eval("__LS.db.minimap.angle") - 360) < 1)
s.click("Lock to the minimap")
check("Appearance can unlock the minimap button",
      s.eval("__LS:MinimapButtonLocked()") is not True)
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
check("the ElvUI theme's default border is a visible grey",
      s.eval("__LS.colors.border[1]") >= 0.35)

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

print()
print("-- FAQ and Help --")
s.click("FAQ")
faq = s.texts()
check("FAQ is its own workspace under Settings",
      s.eval("__LS.page") == "FAQ")
check("FAQ lists general questions",
      "Why did nothing rank?" in faq
      and "Every goal starts off" in faq
      and "How do I open Lodestar?" in faq
      and "What Lodestar is not" in faq, faq)
s.click("Help")
help = s.texts()
check("Help is its own workspace under Settings",
      s.eval("__LS.page") == "HELP")
check("Help has commands and debug isolation",
      "/ls or /lodestar" in help
      and "/ls debug" in help
      and "If something errors" in help, help)
check("Help has Discord and GitHub support with icons",
      "Discord" in help
      and "GitHub" in help
      and "https://discord.gg/a7hrHavcwq" in help
      and "https://github.com/Co2Noss/Lodestar/issues" in help
      and s.eval("""(function()
        local found, seen = {}, {}
        local function visit(frame, depth)
          if depth > 16 or seen[frame] then return end
          seen[frame] = true
          for _, r in ipairs(frame.regions or {}) do
            local t = r.texture
            if type(t) == "string" then
              local lower = t:lower()
              if lower:find("ui-chaticon-share", 1, true) then found.discord = true end
              if lower:find("helpicon-openticket", 1, true) then found.github = true end
            end
          end
          for _, c in ipairs(frame.children or {}) do visit(c, depth + 1) end
        end
        visit(__LS.frame, 0)
        return found.discord and found.github
      end)()""") is True, help)
s.click("Copy Discord invite")
check("copying Discord puts the invite on the clipboard",
      s.eval("Clipboard") == "https://discord.gg/a7hrHavcwq"
      and "copied the Discord invite" in s.printed(), s.printed())
s.click("Copy GitHub issues")
check("copying GitHub puts the issues URL on the clipboard",
      s.eval("Clipboard") == "https://github.com/Co2Noss/Lodestar/issues")
s.exec("__LS:SetSidebarCollapsed(true)")
s.timers()
s.exec("__LS.nav.FAQ.scripts.OnEnter(__LS.nav.FAQ)")
check("hovering the collapsed FAQ icon names it",
      s.eval("GameTooltip._tip") == "FAQ")
s.exec("__LS.nav.HELP.scripts.OnEnter(__LS.nav.HELP)")
check("hovering the collapsed Help icon names it",
      s.eval("GameTooltip._tip") == "Help")
s.exec("__LS:SetSidebarCollapsed(false)")
s.timers()
s.exec("__LS:ShowPage('TODAY')")

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
      "Lodestar themes" in quiet.printed()
      and "gw2" in quiet.printed() and "realui" in quiet.printed())

print()
print("-- ElvUI near-black border --")
elv = Session(saved="{ goals = { ENDGAME = true }, welcomed = true }")
elv.fire("ADDON_LOADED", "Lodestar")
elv.fire("PLAYER_LOGIN")
elv.exec("""
  C_AddOns.IsAddOnLoaded = function(name) return name == "ElvUI" end
  ElvUI = {{
    media = {
      backdropcolor = {0.025, 0.025, 0.025},
      backdropfadecolor = {0.06, 0.06, 0.06, 0.9},
      bordercolor = {0, 0, 0, 1},
      normTex = "Interface/Buttons/WHITE8X8",
      normFont = "Fonts\\\\FRIZQT__.TTF",
    },
    db = { general = { fontSize = 12, valuecolor = {0.25, 0.75, 0.70} } },
  }}
  __LS:SetTheme("ELVUI")
""")
elv.timers()
check("ElvUI's default black border is replaced with a visible grey",
      elv.eval("__LS.colors.border[1]") >= 0.35)
elv.exec("""
  ElvUI[1].media.bordercolor = {0.55, 0.55, 0.55, 1}
  __LS:SetTheme("ELVUI")
""")
elv.timers()
check("a border ElvUI actually set is kept",
      abs(elv.eval("__LS.colors.border[1]") - 0.55) < 0.02)

print()
print("-- GW2 UI and RealUI themes --")
gw = Session(saved="{ goals = { ENDGAME = true }, welcomed = true }")
gw.fire("ADDON_LOADED", "Lodestar")
gw.fire("PLAYER_LOGIN")
gw.exec("""
  C_AddOns.IsAddOnLoaded = function(name) return name == "GW2_UI" end
  GW2_ADDON = { Gw2Color = "|cffffedba", Colors = {} }
  __LS:SetTheme("AUTO")
""")
gw.timers()
check("Auto picks GW2 UI when it is loaded",
      gw.eval("__LS:CurrentTheme()") == "GW2")
check("GW2 UI's gold becomes the accent",
      abs(gw.eval("__LS.colors.accent[1]") - 1) < 0.02
      and abs(gw.eval("__LS.colors.accent[2]") - 0.929) < 0.02)
rui = Session(saved="{ goals = { ENDGAME = true }, welcomed = true }")
rui.fire("ADDON_LOADED", "Lodestar")
rui.fire("PLAYER_LOGIN")
rui.exec("""
  C_AddOns.IsAddOnLoaded = function(name) return name == "Aurora" end
  Aurora = {
    Color = {
      highlight = { GetRGBA = function() return 0.1, 0.5, 0.9, 1 end },
      panelBg = { r = 0.08, g = 0.08, b = 0.08, a = 1 },
      border = { r = 0.15, g = 0.15, b = 0.15, a = 1 },
      red = { r = 0.8, g = 0.2, b = 0.2, a = 1 },
    },
  }
  __LS:SetTheme("REALUI")
""")
rui.timers()
check("RealUI reads Aurora's highlight as the accent",
      abs(rui.eval("__LS.colors.accent[1]") - 0.1) < 0.02
      and abs(rui.eval("__LS.colors.accent[3]") - 0.9) < 0.02)
check("RealUI's near-black Aurora border is replaced with a visible grey",
      rui.eval("__LS.colors.border[1]") >= 0.35)
elv_aurora = Session(saved="{ goals = { ENDGAME = true }, welcomed = true }")
elv_aurora.fire("ADDON_LOADED", "Lodestar")
elv_aurora.fire("PLAYER_LOGIN")
elv_aurora.exec("""
  C_AddOns.IsAddOnLoaded = function(name)
    return name == "ElvUI" or name == "Aurora"
  end
  __LS:SetTheme("AUTO")
""")
elv_aurora.timers()
check("Auto keeps ElvUI when Aurora is also loaded",
      elv_aurora.eval("__LS:CurrentTheme()") == "ELVUI")
nrib = Session(saved="{ goals = { ENDGAME = true }, welcomed = true }")
nrib.fire("ADDON_LOADED", "Lodestar")
nrib.fire("PLAYER_LOGIN")
nrib.exec("""
  C_AddOns.IsAddOnLoaded = function(name) return name == "nibRealUI" end
  __LS:SetTheme("AUTO")
""")
nrib.timers()
check("Auto picks RealUI when nibRealUI is loaded",
      nrib.eval("__LS:CurrentTheme()") == "REALUI")

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
s.exec("""
  UnitLevel = function() return 50 end
  GetMaxLevelForPlayerExpansion = function() return 90 end
  __LS:ScanPlayer()
""")
check("below the cap the Great Vault stays quiet",
      s.eval("#__LS:GetVaultRecommendations()") == 0)
check("below the cap bountiful delves stay quiet",
      s.eval("#__LS:GetBountifulDelveRecommendations()") == 0)
check("below the cap leveling is recommended instead",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.id == "level_cap" then return r.title end
        end
      end)()""") == "Level to 90")
check("below the cap professions can still rank",
      s.eval("#__LS:GetProfessionRecommendations()") > 0)
s.exec("""
  UnitLevel = function() return 90 end
  GetMaxLevelForPlayerExpansion = function() return 90 end
  __LS:ScanPlayer()
  __LS:ScanVault()
""")
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
check("a stale World Vault track is labelled, not the raw id",
      s.eval('__LS:ActivityLabel("vault_world_1_up")') == "Upgrade World Vault slot 1")
s.exec("""
  __LS.db.tracked = { vault_world_1_up = true }
""")
stale_track = s.eval("""(function()
  local a = __LS:TrackedActivities()[1]
  if not a then return "missing" end
  return table.concat({ a.id, a.title, tostring(a.score) }, "|")
end)()""")
check("a maxed World Vault track keeps the id and hides the raw title",
      stale_track == "vault_world_1_up|Upgrade World Vault slot 1|0", stale_track)
s.exec("""
  _G.__oldGetActivitiesStale = C_WeeklyRewards.GetActivities
  C_WeeklyRewards.GetActivities = function(kind)
    if kind == Enum.WeeklyRewardChestThresholdType.World then
      return {
        { type = 3, index = 1, level = 0, threshold = 2, progress = 0, id = 7 },
        { type = 3, index = 2, level = 0, threshold = 4, progress = 0, id = 8 },
        { type = 3, index = 3, level = 0, threshold = 8, progress = 0, id = 9 },
      }
    end
    return __oldGetActivitiesStale(kind)
  end
  __LS:ScanVault()
""")
sibling = s.eval("""(function()
  local a = __LS:FindActivity("vault_world_1_up")
  if not a then return "missing" end
  return table.concat({ a.id, a.title }, "|")
end)()""")
check("a tracked World Vault upgrade follows this week's fill card",
      sibling.startswith("vault_world_1_up|Complete ") and "vault_world_1_up" not in sibling[18:],
      sibling)
s.exec("""
  C_WeeklyRewards.GetActivities = _G.__oldGetActivitiesStale
  __LS.db.tracked = {}
  __LS:ScanVault()
""")
check("the plan still groups into categories", s.eval("#(select(1, __LS:GetCategories()))") > 0)
for name in ["TODAY", "DASHBOARD", "WEEKLY", "LONGTERM", "PROGRESS", "IGNORED", "COMPLETED",
             "VAULT", "PROFESSIONS", "WARBAND", "SETTINGS", "FAQ", "HELP", "WELCOME", "DETAILS"]:
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

check("the Great Vault page highlights the Dashboard workspace",
      s.eval('__LS:NavActive("DASHBOARD")') is True
      and s.eval('__LS:NavActive("PROGRESS")') is False)

s.exec("__LS:ShowPage('PROGRESS')")
s.timers()
progress = s.texts()
check("Progress is the tracked list, not the Great Vault",
      "Nothing tracked yet" in progress and "Great Vault" not in progress
      and "Professions" not in progress, progress)
s.exec("""
  local recs = __LS:GetRecommendations()
  __LS.db.tracked[recs[1].id] = true
  __LS._trackedTitle = recs[1].title
""")
s.exec("__LS:ShowPage('PROGRESS')")
s.timers()
progress = s.texts()
check("Progress lists a tracked activity",
      s.eval("__LS._trackedTitle") in progress and "Untrack" in progress, progress)
s.click("Untrack")
check("Untrack removes the activity from Progress",
      s.eval("""(function()
        for _, on in pairs(__LS.db.tracked) do if on then return true end end
        return false
      end)()""") is False)
s.exec("__LS:ShowPage('PROGRESS')")
s.timers()
check("Progress is empty again after Untrack", "Nothing tracked yet" in s.texts(), s.texts())
s.exec("""
  GameTooltip._lines = {}
  __LS:ShowVaultTooltip()
""")
tip = s.eval("table.concat(GameTooltip._lines or {}, '\\n')")
check("the vault tooltip lists Raid, Dungeons and World",
      "Great Vault" in tip and "Raid" in tip and "Dungeons" in tip and "World" in tip
      and "slots filled" in tip, tip)
check("the vault tooltip names this week's keys from the client",
      "+7  The Rookery" in tip and "Temple of the Jade Serpent" in tip, tip)
check("the vault tooltip uses the client's reward item level",
      "Reward item level 305" in tip, tip)
s.exec("""
  GameTooltip._lines = {}
  local slot = __LS.vault.rows.activities.slots[1]
  __LS:ShowVaultTooltip(nil, slot)
""")
slot_tip = s.eval("table.concat(GameTooltip._lines or {}, '\\n')")
check("a Great Vault slot tooltip is scoped to that slot",
      "Dungeons slot" in slot_tip and "Current:" in slot_tip
      and "Raid  " not in slot_tip, slot_tip)
s.exec("__LS:ShowPage('DASHBOARD')")
s.timers()
s.exec("OpenedGreatVault = false; WeeklyRewardsFrame.shown = false")
s.click("Great Vault")
check("Dashboard opens the client's Great Vault",
      s.eval("OpenedGreatVault") is True)
s.exec("__LS:OpenGreatVault()")
check("clicking Great Vault again closes the chest",
      s.eval("WeeklyRewardsFrame.shown") is not True)
s.exec("__LS:ShowPage('DASHBOARD')")
s.timers()
dash = s.texts()
check("Dashboard hosts Professions",
      "Professions" in dash and "unspent knowledge this expansion" in dash, dash)
check("Dashboard professions shows the two primary profession icons",
      s.eval("""(function()
        local n = 0
        local function visit(frame, depth)
          if depth > 16 or not frame then return end
          for _, r in ipairs(frame.regions or {}) do
            if r.professionIcon then n = n + 1 end
          end
          for _, c in ipairs(frame.children or {}) do visit(c, depth + 1) end
        end
        visit(__LS.frame, 0)
        return n
      end)()""") == 2)
s.exec("""
  OpenedTradeSkills = {}
  local primaries = __LS:PrimaryProfessions()
  __LS:OpenProfessionWindow(primaries[1])
""")
check("clicking a primary profession icon opens that profession",
      s.eval("OpenedTradeSkills[#OpenedTradeSkills]") == 2871
      or s.eval("OpenedTradeSkills[#OpenedTradeSkills]") == 171,
      s.eval("table.concat(OpenedTradeSkills, ',')"))
check("the profession window opens in front of Lodestar",
      s.eval("ProfessionsFrame.frameStrata") == "DIALOG")
s.exec("""
  local primaries = __LS:PrimaryProfessions()
  __LS:OpenProfessionWindow(primaries[1])
""")
check("clicking a profession icon again closes the profession window",
      s.eval("ProfessionsFrame.shown") is not True)
s.click("Open")
check("Dashboard opens the Professions page", s.eval("__LS.page") == "PROFESSIONS")
check("the Professions page highlights the Dashboard workspace",
      s.eval('__LS:NavActive("DASHBOARD")') is True
      and s.eval('__LS:NavActive("PROGRESS")') is False)
s.exec("__LS:ShowPage('DASHBOARD')")
s.timers()
check("Dashboard starts with Edit dashboard", "Edit dashboard" in s.texts(), s.texts())
check("Dashboard names itself as tiles you pick",
      "Tiles you pick. Edit dashboard to add, move, or resize them." in s.texts()
      and "Where things stand, then the next action." not in s.texts(), s.texts())
s.click("Edit dashboard")
edit = s.texts()
check("the dashboard canvas is a 12 by 18 grid",
      s.eval("__LS.DASHBOARD_COLS") == 12
      and s.eval("__LS.DASHBOARD_ROWS") == 18)
check("default dashboard tiles start at half size",
      s.eval("""(function()
        local layout = __LS:DashboardLayout()
        if #layout ~= 4 then return false end
        for _, e in ipairs(layout) do
          if (e.w or 0) > 6 or (e.h or 0) > 4 then return false end
        end
        return layout[1].id == "stats" and layout[1].w == 6 and layout[2].x == 6
      end)()""") is True)
check("edit mode names the canvas and that it can grow",
      "Canvas: 12 × 18" in edit and "grows to 36" in edit, edit)
check("edit mode lists each addable widget's size in cells",
      "Add · WoW Token  6×4" in edit and "Add · Weekly reset  " in edit, edit)
check("edit mode can pack widgets up",
      "Compact up" in edit, edit)
check("edit mode makes widgets resizable",
      s.eval("__LS.dashboardSlots[1] and __LS.dashboardSlots[1].frame.resizable") is True)
check("edit mode lists widgets you can add",
      "Add · WoW Token" in edit and "Add · Weekly reset" in edit
      and "Add · Currencies" in edit and "Add · PvP" in edit
      and "Add · Item Level" in edit
      and "Add · Readiness" in edit
      and "Add · Housing" in edit
      and "Add · Battle Pets" in edit
      and "Add · Calendar" in edit and "Add · Guild" in edit
      and "Add · Delver's Journey" in edit and "Add · Preyhunter's Journey" in edit
      and "Add · Mythic+" in edit and "Add · Gold" in edit
      and "Add · Rares" not in edit
      and "Add · Raider.IO" not in edit and "Add · TSM Gold" not in edit
      and "Add · Warband Gold" not in edit, edit)
check("edit mode shows settings instead of live tile data",
      "Totals on this tile." in edit
      and "Shortcuts on this tile." in edit
      and "Controls on this tile." in edit
      and "Nothing extra to set on this tile." in edit
      and "unspent knowledge this expansion" not in edit, edit)
s.exec("""
  __LS.bodyScroll:SetHeight(200)
  if __LS._bodySync then __LS._bodySync(360) end
""")
check("edit mode can scroll the dashboard body",
      s.eval("__LS.bodyScroll:GetVerticalScroll()") == 360)
s.exec("__LS:ShowPage('DASHBOARD')")
s.timers()
check("redrawing the dashboard in edit mode keeps the body scroll",
      s.eval("__LS.bodyScroll:GetVerticalScroll()") == 360)
s.exec("__LS:ShowPage('TODAY'); __LS:ShowPage('DASHBOARD')")
s.timers()
check("leaving the dashboard resets the body scroll",
      s.eval("__LS.bodyScroll:GetVerticalScroll()") == 0)
s.click("Add · WoW Token")
dash = s.texts()
check("token settings appear in edit mode, not the live price",
      "Coin icons" in dash and "Letters" in dash
      and "258652g" not in dash and "WoW Token" in dash, dash)
check("token letters keep silver and copper",
      s.eval("""(function()
        local t = select(1, __LS:FormatTokenMoney(12345, { format = "letters", color = false }))
        return t
      end)()""") == "1g 23s 45c")
check("letter colour paints gold, silver, and copper separately",
      s.eval("""(function()
        local t = select(1, __LS:FormatTokenMoney(12345, { format = "letters", color = true }))
        return type(t) == "string" and t:find("|cff", 1, true) ~= nil
          and t:find("1g", 1, true) ~= nil and t:find("23s", 1, true) ~= nil
          and t:find("45c", 1, true) ~= nil
      end)()""") is True)
check("token letters are the default format",
      "UI-GoldIcon" not in dash and "258,652g" not in dash, dash)
s.exec("""
  for _, slot in ipairs(__LS.dashboardSlots) do
    if slot.id == "token" then
      slot.frame.scripts.OnDragStart(slot.frame)
      break
    end
  end
""")
check("picking up a widget leaves a drop ghost",
      s.eval("__LS.dashboardDragGhost and __LS.dashboardDragGhost.shown") is True
      and "Drop here" in s.texts(), s.texts())
check("empty drop slots show a plus where the widget could go",
      "+" in s.texts()
      and s.eval("""(function()
        local n = 0
        for _, hint in ipairs(__LS.dashboardDropHints or {}) do
          if hint.shown then n = n + 1 end
        end
        return n
      end)()""") >= 1, s.texts())
check("the lifted widget scales up and follows the cursor",
      s.eval("__LS.dashboardDragFrame.moving") is True
      and s.eval("math.abs((__LS.dashboardDragFrame.scale or 1) - 1.05)") < 0.001)
check("the lifted widget uses the accent border",
      abs(s.eval("__LS.dashboardDragFrame.borderColor[1]")
          - s.eval("__LS.colors.accent[1]")) < 1e-6)
s.exec("__LS.dashboardDragFrame.scripts.OnDragStop(__LS.dashboardDragFrame)")
s.timers()
check("dropping a widget clears the ghost",
      s.eval("__LS.dashboardDragGhost and __LS.dashboardDragGhost.shown") is not True)
check("dropping a widget hides empty drop slots",
      s.eval("""(function()
        for _, hint in ipairs(__LS.dashboardDropHints or {}) do
          if hint.shown then return true end
        end
        return false
      end)()""") is not True)
s.click("Done editing")
check("widget options stay hidden until edit mode",
      "Coin icons" not in s.texts() and "Separators" not in s.texts(), s.texts())
dash = s.texts()
check("the token widget uses the client's market price",
      "258652g" in dash and "0s" in dash and "0c" in dash and "WoW Token" in dash, dash)
s.click("Edit dashboard")
s.click("Coin icons")
s.click("Done editing")
check("coin icons replace the letter suffix",
      "UI-GoldIcon" in s.texts() and "258652g" not in s.texts(), s.texts())
s.click("Edit dashboard")
s.click("Letters")
s.click("Separators")
s.click("Done editing")
check("separators break the gold amount into thousands",
      "258,652g" in s.texts(), s.texts())
s.click("Edit dashboard")
s.click("Color")
s.click("Done editing")
check("color can be turned off without losing the letter amount",
      "258,652g" in s.texts(), s.texts())
s.exec("""
  __LS.db.tokenHistory = { { t = 1, p = 2000000000 }, { t = 2, p = 2586520000 } }
  __LS.dashboardEdit = true
  __LS:ShowPage('DASHBOARD')
""")
s.timers()
s.click("Line")
check("the token trend can use a line chart",
      s.eval("__LS:WidgetOpts('token').chart") == "line")
s.click("Bars")
check("the token trend can use bars",
      s.eval("__LS:WidgetOpts('token').chart") != "line")
s.exec("""
  __LS:DashboardPlace('token', 0, 14, 6, 4)
  __LS:ShowPage('DASHBOARD')
""")
s.timers()
check("a widget can be placed anywhere on the canvas",
      s.eval("""(function()
        for _, e in ipairs(__LS:DashboardLayout()) do
          if e.id == 'token' then
            return e.x == 0 and e.y == 14 and e.w == 6 and e.h == 4
          end
        end
      end)()""") is True)
s.exec("__LS:DashboardPlace('token', 20, 20, 4, 3)")
check("placement is clamped to the canvas",
      s.eval("""(function()
        for _, e in ipairs(__LS:DashboardLayout()) do
          if e.id == 'token' then
            return e.x == 8 and e.y == 15 and e.w == 4 and e.h == 3
          end
        end
      end)()""") is True)
s.exec("__LS:DashboardPlace('token', 0, 0, 6, 4)")
check("widgets are not allowed to overlap",
      s.eval("""(function()
        local token
        for _, e in ipairs(__LS:DashboardLayout()) do
          if e.id == 'token' then token = e end
        end
        if not token or (token.x == 0 and token.y == 0) then return false end
        for i, a in ipairs(__LS:DashboardLayout()) do
          for j, b in ipairs(__LS:DashboardLayout()) do
            if i < j and a.x < b.x + b.w and b.x < a.x + a.w
                and a.y < b.y + b.h and b.y < a.y + a.h then
              return false
            end
          end
        end
        return true
      end)()""") is True)
s.exec("""
  __LS.db.dashboard.widgets = {
    { id = "stats", x = 0, y = 3, w = 12, h = 4 },
    { id = "shortcuts", x = 0, y = 10, w = 12, h = 2 },
  }
  __LS:DashboardCompactUp()
""")
check("compact up pushes widgets to the top without overlapping",
      s.eval("""(function()
        local stats, shortcuts
        for _, e in ipairs(__LS:DashboardLayout()) do
          if e.id == 'stats' then stats = e end
          if e.id == 'shortcuts' then shortcuts = e end
        end
        return stats and stats.y == 0 and shortcuts and shortcuts.y == 4
      end)()""") is True)
s.exec("__LS:ShowPage('DASHBOARD')")
s.timers()
s.exec("""
  __LS:RegisterWidget({
    id = "test_widget",
    title = "Test Widget",
    defaultSize = "half",
    render = function(_, parent, width)
      local line = __LS.widgets.text(parent, width, 11)
      line:SetPoint("TOPLEFT", 12, -8)
      line:SetText("Hello from another addon")
      return 36
    end,
  })
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Add · Test Widget")
check("another addon can register a dashboard widget",
      "Hello from another addon" in s.texts(), s.texts())
s.click("Reset widgets")
check("reset restores the default dashboard",
      s.eval("__LS:DashboardLayout()[1].id") == "stats"
      and s.eval("__LS:DashboardHas('token')") is not True)
s.exec("""
  Printed = {}
  __LS.db.dashboard.widgets = { { id = "stats", x = 0, y = 0, w = 12, h = 18 } }
  __LS:DashboardAdd("vault")
""")
check("a full canvas grows down to place a new widget",
      s.eval("__LS:DashboardRows()") == 22
      and s.eval("""(function()
        for _, e in ipairs(__LS:DashboardLayout()) do
          if e.id == "vault" then return e.y == 18 and e.w == 6 and e.h == 4 end
        end
      end)()""") is True)
s.exec("""
  Printed = {}
  __LS.db.dashboard.rows = 36
  __LS.db.dashboard.widgets = {
    { id = "stats", x = 0, y = 0, w = 12, h = 34 },
    { id = "next", x = 0, y = 34, w = 8, h = 2 },
  }
  __LS:DashboardAdd("token")
""")
check("a maxed canvas fits a widget into the remaining hole",
      s.eval("""(function()
        for _, e in ipairs(__LS:DashboardLayout()) do
          if e.id == "token" then return e.w == 4 and e.h == 2 and e.x == 8 and e.y == 34 end
        end
      end)()""") is True)
check("fitting a widget into leftover room says so",
      "room left on the canvas" in s.printed(), s.printed())
s.exec("""
  Printed = {}
  __LS.db.dashboard.rows = 36
  __LS.db.dashboard.widgets = { { id = "stats", x = 0, y = 0, w = 12, h = 36 } }
  __LS:DashboardAdd("token")
""")
check("a packed max canvas says it is full",
      s.eval("__LS:DashboardHas('token')") is not True
      and "canvas is full" in s.printed(), s.printed())
s.exec("__LS:ResetDashboardLayout()")
s.exec("""
  __LS.db.dashboard.widgets = {
    { id = "stats", x = 0, y = 0, w = 12, h = 4 },
    { id = "shortcuts", x = 0, y = 4, w = 12, h = 2 },
    { id = "professions", x = 0, y = 6, w = 12, h = 3 },
    { id = "next", x = 0, y = 9, w = 12, h = 5 },
  }
""")
check("the old full-width default shrinks to half tiles",
      s.eval("__LS:DashboardLayout()[1].w") == 6
      and s.eval("__LS:DashboardLayout()[1].h") == 4
      and s.eval("__LS:DashboardLayout()[2].x") == 6)
s.exec("__LS:ResetDashboardLayout()")
s.click("Done editing")
check("leaving edit mode hides the add list",
      "Add · WoW Token" not in s.texts(), s.texts())
weekly = s.eval("""(function()
  local names = {}
  for _, g in ipairs(__LS:GetCategories("WEEKLY")) do table.insert(names, g.name) end
  return table.concat(names, ",")
end)()""")
check("weekly plan is reset work, not a second copy of every Today tab",
      "Great Vault" in weekly, weekly)
s.exec("__LS.db.dismissed.delve = true; __LS:ShowPage('IGNORED')")
s.timers()
ignored = s.texts()
check("ignored tasks lists a dismissed card",
      "Bountiful Delve" in ignored or "bountiful" in ignored.lower(), ignored)
s.click("Restore")
check("restore puts the card back on the plan",
      s.eval("__LS.db.dismissed.delve") in (None, False))

s.exec("__LS:ShowPage('PROFESSIONS')")
s.timers()
s.exec("""
  for _, p in ipairs(__LS.professions) do
    if p.skillLineID == 2757 then
      p.isCurrent = false
      p.unspent = 20
    else
      p.unspent = 0
    end
  end
  __LS:SaveSnapshot()
""")
check("Dashboard unspent knowledge ignores older expansions",
      s.eval("__LS:UnspentKnowledge()") == 0)
check("Warband unspent knowledge matches the Dashboard",
      s.eval("__LS:GetWarbandTotals().unspentKnowledge") == 0)
s.exec("__LS.db.currentExpansionOnly = false")
check("the Dashboard total stays on this expansion while older trees are visible",
      s.eval("__LS:UnspentKnowledge()") == 0
      and s.eval("#__LS:VisibleProfessions()") > s.eval("#__LS:CurrentExpansionProfessions()"))
s.exec("__LS.db.currentExpansionOnly = true")
s.exec("__LS:ScanProfessions(); __LS:SaveSnapshot()")
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
check("clicking a profession tab does not open the profession window",
      s.eval("#OpenedTradeSkills") == 0, s.eval("table.concat(OpenedTradeSkills, ',')"))
s.click("Open Herbalism")
check("the Open button opens that profession",
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
check("Auto uses TomTom when it is loaded",
      s.eval("""(function()
        local id = __LS:ResolveWaypointSource()
        return tostring(__LS.db.waypointSource) .. "|" .. tostring(id)
      end)()""") == "AUTO|TOMTOM")
s.exec("""
  Printed = {}
  TomTomWaypoints = {}
  UserWaypoint = nil
  SuperTrackedUserWaypoint = false
  __LS.db.waypointSource = "BLIZZARD"
  __LS:MarkWaypoints({
    { map = 2393, x = 49.11, y = 75.84, title = "A" },
    { map = 2393, x = 47.75, y = 51.67, title = "B" },
  })
""")
check("Blizzard waypoint ignores TomTom even when it is loaded",
      s.eval("#TomTomWaypoints") == 0 and s.eval("UserWaypoint ~= nil"),
      s.eval("#TomTomWaypoints"))
check("choosing the client pin does not nag about TomTom",
      "TomTom" not in (s.printed() or ""), s.printed())
s.exec("""
  __LS.db.waypointSource = "AUTO"
  TomTomWaypoints = {}
  TomTom = nil
  OpenedWorldMaps = {}
""")
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
  local visible = {
    [A] = { npc = 1, quest = 11, loot = { 1 } },
    [B] = { npc = 2, quest = 12, loot = { 2 } },
  }
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
s.exec("""
  local mixed = {
    [49117584] = { npc = 1, quest = 11, loot = { 1 } },
    [47755167] = { npc = 2, quest = 12, loot = { 2 } },
    [40004000] = { loot = { 99 } },
    [30003000] = { npc = 50 },
  }
  HandyNotes.plugins.Rares.GetNodes2 = function(_, mapID)
    if mapID ~= 2393 then return function() end end
    return pairs(mixed)
  end
""")
mixed = s.eval("""(function()
  local r = __LS:GetHandyNotesRecommendations()[1]
  if not r then return "none" end
  return r.title .. "|" .. tostring(#r.waypoints)
end)()""")
check("HandyNotes counts rares, not treasures or city marks",
      mixed.startswith("Hunt 2 rares") and mixed.endswith("|2"), mixed)
s.exec("HandyNotes.plugins.Rares.GetNodes2 = function() return function() end end")
check("known-hidden HandyNotes pins stay off the plan",
      s.eval("#__LS:GetHandyNotesRecommendations()") == 0)
s.exec("""
  local many = {}
  for i = 1, 12 do
    many[(4800 + i) * 10000 + 5000] = { npc = i, quest = i, loot = { i } }
  end
  many[500 * 10000 + 500] = { npc = 100, quest = 100, loot = { 100 } }
  many[600 * 10000 + 500] = { npc = 101, quest = 101, loot = { 101 } }
  many[700 * 10000 + 500] = { npc = 102, quest = 102, loot = { 102 } }
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
s.exec("__LS:SetPageTab('SETTINGS', 'ADDONS'); __LS:ShowPage('SETTINGS')")
s.timers()
check("Settings notes that HandyNotes is loaded with notes packs",
      "HandyNotes is loaded with notes packs" in s.texts(), s.texts())
s.exec("HandyNotes.plugins = {}")
s.exec("__LS:SetPageTab('SETTINGS', 'ADDONS'); __LS:ShowPage('SETTINGS')")
s.timers()
check("Settings says HandyNotes needs a notes pack",
      "no notes packs" in s.texts(), s.texts())
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

print()
print("-- bountiful delves from the map --")
s.exec("""
  local function pos(x, y)
    return { x = x, y = y, GetXY = function(s) return s.x, s.y end }
  end
  DelvePOIs = {
    [2395] = {
      {
        areaPoiID = 11, name = "Myconic Grotto", atlasName = "delves-bountiful",
        isPrimaryMapForPOI = true, position = pos(0.42, 0.55),
      },
      {
        areaPoiID = 12, name = "Ordinary Hollow", atlasName = "delves",
        isPrimaryMapForPOI = true, position = pos(0.20, 0.30),
      },
    },
    [2405] = {
      {
        areaPoiID = 21, name = "Nightfall Sanctum", atlasName = "delves-bountiful",
        isPrimaryMapForPOI = true, position = pos(0.61, 0.44),
      },
    },
    [2413] = {
      {
        areaPoiID = 31, name = "Fungal Folly Chest", atlasName = "vignetteloot",
        isPrimaryMapForPOI = true, position = pos(0.50, 0.50),
      },
      {
        areaPoiID = 32, name = "Root-Bound Hollow", atlasName = "delves-bountiful",
        isPrimaryMapForPOI = true, position = pos(0.33, 0.41),
      },
    },
  }
  AreaPOIs = {
    [2405] = {
      {
        areaPoiID = 41, name = "Devouring Breach", atlasName = "delves-bountiful",
        isPrimaryMapForPOI = true, position = pos(0.48, 0.52),
      },
    },
  }
""")
named = s.eval("""(function()
  local r
  for _, rec in ipairs(__LS:GetBountifulDelveRecommendations()) do
    if rec.id == "delve" then r = rec break end
  end
  if not r then return "none" end
  local titles = {}
  for _, p in ipairs(r.waypoints or {}) do table.insert(titles, p.title) end
  return table.concat({ r.title, r.why or "", table.concat(titles, ",") }, "|")
end)()""")
check("named bountiful delves come from the map POIs",
      "Run today's bountiful delves" in named
      and "Myconic Grotto" in named and "Nightfall Sanctum" in named, named)
check("portal continents still count when the player is on Quel'Thalas",
      "Root-Bound Hollow" in named and "Devouring Breach" in named
      and "Harandar" in named, named)
check("non-bountiful delves and treasure marks stay off that card",
      "Ordinary Hollow" not in named and "Fungal Folly Chest" not in named, named)
check("FindActivity can open the named bountiful rec",
      s.eval('(__LS:FindActivity("delve") or {}).title')
      == "Run today's bountiful delves")
s.exec("DelvePOIs = {}")
generic = s.eval("""(function()
  for _, r in ipairs(__LS:GetBountifulDelveRecommendations()) do
    if r.id == "delve" then return r.title end
  end
end)()""")
check("with no named POIs the generic Bountiful Delve rec remains",
      generic == "Complete a Bountiful Delve", generic)

print()
print("-- questing --")
s.exec("__LS.db.goals.QUESTING = true")
empty = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetQuestRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("an empty log with no campaign asks the player to check the map",
      "Check your map and pick up quests" in empty, empty)
check("the empty-log rec ranks while Questing is on",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.id == "quest_check_map" then return true end
        end
        return false
      end)()""") is True)
s.exec("__LS.db.goals.QUESTING = false")
check("Questing stays quiet while that goal is off",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.category == "Questing" then return true end
        end
        return false
      end)()""") is False)
s.exec("""
  __LS.db.goals.QUESTING = true
  AvailableCampaigns = { 9001 }
  Campaigns[9001] = {
    state = Enum.CampaignState.InProgress,
    info = { name = "Midnight Campaign" },
    chapterID = 12,
    chapterInfo = { name = "Into the Void" },
  }
  QuestLog = {
    {
      title = "A Foothold in Harandar", questLogIndex = 1, questID = 101,
      campaignID = 9001, isHeader = false, isOnMap = true,
    },
    {
      title = "Kill ten moths", questLogIndex = 2, questID = 202,
      isHeader = false, readyForTurnIn = true, isOnMap = true,
    },
    {
      title = "World Quest: Do a thing", questLogIndex = 3, questID = 303,
      isHeader = false, isTask = true,
    },
    {
      title = "A side errand", questLogIndex = 4, questID = 404,
      isHeader = false, isOnMap = false,
    },
  }
""")
questing = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetQuestRecommendations()) do
    table.insert(out, r.id .. "=" .. r.title)
  end
  return table.concat(out, "\\n")
end)()""")
check("an in-progress campaign quest is recommended",
      "campaign_9001=Continue: A Foothold in Harandar" in questing, questing)
check("quest-log turn-ins are recommended alongside the campaign",
      "quest_202=Turn in: Kill ten moths" in questing, questing)
check("other log quests are recommended as options",
      "quest_404=A side errand" in questing, questing)
check("world quests in the log stay off the questing card",
      "Do a thing" not in questing and "quest_check_map" not in questing, questing)
check("FindActivity can open the campaign rec",
      s.eval('__LS:FindActivity("campaign_9001") ~= nil') is True)
s.exec("""
  Campaigns[9001].state = Enum.CampaignState.Complete
  QuestLog = {}
  AvailableCampaigns = { 9001 }
""")
caught_up = s.eval("""(function()
  local out = {}
  for _, r in ipairs(__LS:GetQuestRecommendations()) do table.insert(out, r.title) end
  return table.concat(out, "\\n")
end)()""")
check("a finished campaign with an empty log asks the player to check the map",
      "Check your map and pick up quests" in caught_up
      and "Midnight Campaign" not in caught_up, caught_up)
s.exec("""
  AvailableCampaigns = { 9001 }
  Campaigns[9001].state = Enum.CampaignState.Stalled
  QuestLog = {}
""")
stalled = s.eval("""(function()
  for _, r in ipairs(__LS:GetQuestRecommendations()) do
    if r.id == "campaign_9001" then return r.title .. "|" .. r.urgency end
  end
end)()""")
check("a stalled campaign is ranked as catch-up",
      stalled == "Catch up on Midnight Campaign|HIGH", stalled)
s.exec("""
  AvailableCampaigns = {}
  Campaigns = {}
  QuestLog = {
    {
      title = "Building the Voidforge", questLogIndex = 1, questID = 501,
      isHeader = false, isImportant = true, isOnMap = true,
    },
    {
      title = "A side errand", questLogIndex = 2, questID = 404,
      isHeader = false, isOnMap = false,
    },
  }
""")
important = s.eval("""(function()
  local r
  for _, rec in ipairs(__LS:GetQuestRecommendations()) do
    if rec.id == "quest_501" then r = rec break end
  end
  if not r then return "none" end
  return table.concat({ r.title, r.urgency, tostring(r.tags.QUESTING), tostring(r.tags.ENDGAME) }, "|")
end)()""")
check("quests the client marks important rank like campaign work",
      important == "Continue: Building the Voidforge|MEDIUM|14|8", important)
check("important quests sit ahead of side errands",
      s.eval("""(function()
        local recs = __LS:GetQuestRecommendations()
        return recs[1] and recs[1].id == "quest_501" and recs[2] and recs[2].id == "quest_404"
      end)()""") is True)
s.exec("__LS.db.goals.QUESTING = false; __LS.db.goals.ENDGAME = true")
check("important unlocks still rank while Great Vault & endgame is on",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.id == "quest_501" then return true end
        end
        return false
      end)()""") is True)
s.exec("__LS.db.goals.ENDGAME = false")
check("important quests stay quiet when Questing and endgame are off",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.id == "quest_501" then return true end
        end
        return false
      end)()""") is False)
s.exec("""
  QuestLog = {
    {
      title = "Hunt the Shade", questLogIndex = 1, questID = 777,
      isHeader = false, isImportant = true, isOnMap = true,
    },
  }
  ActivePreyQuestID = 777
  __LS.db.goals.PREY = true
""")
prey = s.eval("""(function()
  local r
  for _, rec in ipairs(__LS:GetPreyRecommendations()) do
    if rec.id == "prey" then r = rec break end
  end
  if not r then return "none" end
  return r.title .. "|" .. r.urgency
end)()""")
check("an active Prey hunt is recommended from the client",
      prey == "Continue: Hunt the Shade|HIGH", prey)
check("the active hunt is not also listed as a log quest",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetQuestRecommendations()) do
          if r.id == "quest_777" then return true end
        end
        return false
      end)()""") is False)
check("FindActivity can open the Prey hunt",
      s.eval('(__LS:FindActivity("prey") or {}).title') == "Continue: Hunt the Shade")
s.exec("ActivePreyQuestID = nil")
generic_prey = s.eval("""(function()
  for _, r in ipairs(__LS:GetPreyRecommendations()) do
    if r.id == "prey" then return r.title end
  end
end)()""")
check("Prey hunts fill the World Vault while that goal is on",
      generic_prey == "Complete a Prey hunt", generic_prey)
s.exec("__LS.db.goals.PREY = false")
check("Prey stays quiet while that goal is off and no hunt is active",
      s.eval("#__LS:GetPreyRecommendations()") == 0)
s.exec("""
  QuestLog = {}
  AvailableCampaigns = {}
  Campaigns = {}
  SuperTrackedQuestID = nil
  ActivePreyQuestID = nil
  __LS.db.goals.QUESTING = false
  __LS.db.goals.ENDGAME = false
  __LS.db.goals.PREY = false
""")

s.exec("""
  C_WeeklyRewards.GetConquestWeeklyProgress = function()
    return { progress = 200, maxProgress = 550 }
  end
  __LS.db.goals.PVP = false
""")
check("PvP stays quiet while that goal is off",
      s.eval("#__LS:GetPvPRecommendations()") == 0)
s.exec("__LS.db.goals.PVP = true")
pvp = s.eval("""(function()
  local r = __LS:GetPvPRecommendations()[1]
  if not r then return "none" end
  return table.concat({ r.id, r.title, r.category, r.why }, "|")
end)()""")
check("PvP ranks weekly Conquest the client still needs",
      pvp == "pvp_conquest|Earn weekly Conquest|PvP|200 / 550 Conquest this week.", pvp)
check("PvP Conquest ranks while that goal is on",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.id == "pvp_conquest" then return true end
        end
        return false
      end)()""") is True)
check("FindActivity can open that Conquest rec",
      s.eval('(__LS:FindActivity("pvp_conquest") or {}).title') == "Earn weekly Conquest")
check("weekly Conquest sits on the weekly plan",
      s.eval('__LS:ActivityHorizon({ id = "pvp_conquest", category = "PvP" })') == "WEEKLY")
s.exec("""
  C_WeeklyRewards.GetConquestWeeklyProgress = function()
    return { progress = 550, maxProgress = 550 }
  end
""")
check("finished weekly Conquest stays off the plan",
      s.eval("#__LS:GetPvPRecommendations()") == 0)
s.exec("""
  C_WeeklyRewards.GetConquestWeeklyProgress = function()
    return { progress = 200, maxProgress = 550 }
  end
  UnitLevel = function() return 50 end
  __LS:ScanPlayer()
""")
check("below the cap PvP stays quiet",
      s.eval("#__LS:GetPvPRecommendations()") == 0)
s.exec("""
  UnitLevel = function() return 90 end
  __LS:ScanPlayer()
  C_WeeklyRewards.GetConquestWeeklyProgress = nil
  __LS.db.goals.PVP = false
""")

s.exec("""
  OwnedHouses = {}
  CurrentHouseInfo = nil
  CurrentInitiative = nil
  InitiativeProgress = nil
  PlayerContribution = nil
  __LS.db.goals.HOUSING = false
""")
check("Housing stays quiet while that goal is off",
      s.eval("#__LS:GetHousingRecommendations()") == 0)
s.exec("__LS.db.goals.HOUSING = true")
house = s.eval("""(function()
  local r = __LS:GetHousingRecommendations()[1]
  if not r then return "none" end
  return table.concat({ r.id, r.title, r.category, r.why }, "|")
end)()""")
check("Housing ranks a missing house the client reports",
      house == "housing_house|Claim a house|Housing|The client has no house on this character.", house)
check("Housing ranks while that goal is on",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.id == "housing_house" then return true end
        end
        return false
      end)()""") is True)
check("FindActivity can open that housing rec",
      s.eval('(__LS:FindActivity("housing_house") or {}).title') == "Claim a house")
check("claiming a house sits on the long-term plan",
      s.eval('__LS:ActivityHorizon({ id = "housing_house", category = "Housing" })') == "LONG")
s.exec("""
  OwnedHouses = { { plotID = 1, houseName = "Test House" } }
  CurrentInitiative = { name = "Neighborhood garden", isComplete = false }
  InitiativeProgress = { progress = 12, maxProgress = 100 }
""")
init = s.eval("""(function()
  local r
  for _, row in ipairs(__LS:GetHousingRecommendations()) do
    if row.id == "housing_initiative" then r = row end
  end
  if not r then return "none" end
  return table.concat({ r.id, r.title, r.why }, "|")
end)()""")
check("Housing ranks an unfinished neighborhood initiative",
      init == "housing_initiative|Neighborhood garden|12 / 100 neighborhood contribution.", init)
check("neighborhood initiatives sit on the weekly plan",
      s.eval('__LS:ActivityHorizon({ id = "housing_initiative", category = "Housing" })') == "WEEKLY")
s.exec("""
  InitiativeProgress = { progress = 100, maxProgress = 100 }
""")
check("a finished neighborhood initiative stays off the plan",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetHousingRecommendations()) do
          if r.id == "housing_initiative" then return true end
        end
        return false
      end)()""") is False)
s.exec("""
  OwnedHouses = { {
    plotID = 7, houseName = "Test House", neighborhoodName = "Founder's Point",
    houseGUID = "House-1", neighborhoodGUID = "Hood-1",
  } }
  CurrentHouseFavor = 500
""")
prog = s.eval("""(function()
  local p = __LS:HousingProgress()
  return table.concat({
    tostring(p.owned), tostring(p.name), tostring(p.level),
    tostring(p.favor), tostring(p.nextFavor)
  }, "|")
end)()""")
check("Housing progress reads house level and favor from the client",
      prog == "true|Test House|2|500|1200", prog)
check("Housing reports fill toward the next house level",
      abs(s.eval("__LS:HousingProgress().fill") - (490 / 1190)) < 0.01)
s.exec("""
  OwnedHouses = {}
  CurrentHouseInfo = nil
  __LS._houseList = nil
  __LS._currentHouse = nil
  __LS._trackedHouseGuid = nil
  __LS._housingAsked = false
""")
check("Housing is empty until the client lists a house",
      s.eval("__LS:PlayerOwnsHouse()") is not True)
s.exec("""
  __LS:RememberHouseList({ {
    houseName = "Hammerlock's House", houseLevel = 6, houseGUID = "House-6",
  } })
""")
cached = s.eval("""(function()
  local p = __LS:HousingProgress()
  return table.concat({
    tostring(p.owned), tostring(p.name), tostring(p.level)
  }, "|")
end)()""")
check("Housing uses the house list event when GetPlayerOwnedHouses is still empty",
      cached == "true|Hammerlock's House|6", cached)
s.exec("""
  __LS._houseList = nil
  OwnedHouses = { "House-GUID-1" }
""")
check("Housing treats a GUID-only owned list as a house",
      s.eval("__LS:PlayerOwnsHouse()") is True)
s.exec("""
  OwnedHouses = {}
  __LS._houseList = nil
  __LS._currentHouse = nil
  __LS._trackedHouseGuid = nil
  RequestedHouseInfo = nil
  __LS._housingAsked = false
  __LS:HousingProgress()
""")
check("Housing asks the client for house info when the owned list is empty",
      s.eval("RequestedHouseInfo") is True)
s.exec("""
  OwnedHouses = { {
    plotID = 7, houseName = "Test House", neighborhoodName = "Founder's Point",
    houseGUID = "House-1", neighborhoodGUID = "Hood-1",
  } }
  CurrentHouseFavor = 500
  OpenedHousingDashboard = false
  __LS:OpenHousingDashboard()
""")
check("Housing opens the client's Housing Dashboard",
      s.eval("OpenedHousingDashboard") is True)
s.exec("__LS:OpenHousingDashboard()")
check("clicking Housing Dashboard again closes it",
      s.eval("HousingDashboardFrame.shown") is not True)
s.exec("""
  TeleportedHome = nil
  __LS:TeleportToHouse()
""")
check("Housing teleport uses the client's house GUIDs",
      s.eval("TeleportedHome and TeleportedHome[1]") == "Hood-1"
      and s.eval("TeleportedHome[2]") == "House-1"
      and s.eval("TeleportedHome[3]") == 7)
s.exec("""
  QuestLog = { { questID = 1001, title = "Housewarming", frequency = 2 } }
  __LS.db.goals.QUESTING = true
""")
warm = s.eval("""(function()
  local r
  for _, row in ipairs(__LS:GetHousingRecommendations()) do
    if row.id == "housing_quest_1001" then r = row end
  end
  if not r then return "none" end
  return table.concat({ r.id, r.title, r.why }, "|")
end)()""")
check("Housing ranks Housewarming when it is already in the log",
      warm == "housing_quest_1001|Housewarming|Weekly housing work already in your log.", warm)
check("housing weeklies sit on the weekly plan",
      s.eval('__LS:ActivityHorizon({ id = "housing_quest_1001", category = "Housing" })') == "WEEKLY")
check("Housing weeklies are not also listed as questing cards",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetQuestRecommendations()) do
          if r.id == "quest_1001" or (r.title or ""):find("Housewarming", 1, true) then
            return true
          end
        end
        return false
      end)()""") is False)
s.exec("""
  QuestLog = {}
  CurrentHouseFavor = nil
  OwnedHouses = {}
  CurrentInitiative = nil
  InitiativeProgress = nil
  UnitLevel = function() return 50 end
  __LS:ScanPlayer()
""")
check("below the cap Housing stays quiet about claiming a house",
      s.eval("#__LS:GetHousingRecommendations()") == 0)
s.exec("""
  UnitLevel = function() return 90 end
  __LS:ScanPlayer()
  OwnedHouses = {}
  CurrentHouseInfo = nil
  CurrentInitiative = nil
  InitiativeProgress = nil
  PlayerContribution = nil
  __LS.db.goals.HOUSING = false
""")

s.exec("""
  JournalUnlocked = false
  PetLoadOut = {
    [1] = { locked = true },
    [2] = { locked = true },
    [3] = { locked = true },
  }
  OwnedPetIDs = {}
  PetInfoByID = {}
  __LS.db.goals.PETS = false
""")
check("Battle Pets stays quiet while that goal is off",
      s.eval("#__LS:GetPetRecommendations()") == 0)
s.exec("__LS.db.goals.PETS = true")
pets = s.eval("""(function()
  local r = __LS:GetPetRecommendations()[1]
  if not r then return "none" end
  return table.concat({ r.id, r.title, r.category }, "|")
end)()""")
check("Battle Pets ranks locked slots the client reports",
      pets == "pets_training|Unlock battle pets|Battle Pets", pets)
check("Battle Pets ranks while that goal is on",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetRecommendations()) do
          if r.id == "pets_training" then return true end
        end
        return false
      end)()""") is True)
check("FindActivity can open that battle pets rec",
      s.eval('(__LS:FindActivity("pets_training") or {}).title') == "Unlock battle pets")
check("unlocking battle pets sits on the long-term plan",
      s.eval('__LS:ActivityHorizon({ id = "pets_training", category = "Battle Pets" })') == "LONG")
s.exec("""
  JournalUnlocked = true
  PetLoadOut = {
    [1] = { locked = false },
    [2] = { locked = false },
    [3] = { locked = false },
  }
  OwnedPetIDs = { "Pet-1", "Pet-2" }
  PetInfoByID["Pet-1"] = { speciesID = 10, name = "Alpine Hare", icon = 1, level = 25 }
  PetInfoByID["Pet-2"] = { speciesID = 10, name = "Alpine Hare", icon = 1, level = 1 }
""")
pets_team = s.eval("""(function()
  local r = __LS:GetPetRecommendations()[1]
  if not r then return "none" end
  return r.id
end)()""")
check("Battle Pets ranks an empty team when you already own pets",
      pets_team == "pets_team", pets_team)
s.exec("""
  PetLoadOut[1] = { petGUID = "Pet-1", locked = false }
  PetLoadOut[2] = { petGUID = "Pet-2", locked = false }
  PetLoadOut[3] = { petGUID = "Pet-1", locked = false }
  QuestLog = { { questID = 2001, title = "That's Super Tame" } }
  QuestTagInfo[2001] = { tagName = "Pet Battle", tagID = 4 }
""")
pets_quest = s.eval("""(function()
  local r
  for _, row in ipairs(__LS:GetPetRecommendations()) do
    if row.id == "pets_quest_2001" then r = row end
  end
  if not r then return "none" end
  return table.concat({ r.title, r.category }, "|")
end)()""")
check("Battle Pets ranks a pet battle quest already in the log",
      pets_quest == "That's Super Tame|Battle Pets", pets_quest)
s.exec("__LS.db.goals.QUESTING = true")
check("pet battle quests are not also listed as questing cards",
      s.eval("""(function()
        for _, r in ipairs(__LS:GetQuestRecommendations()) do
          if r.id and tostring(r.id):find("2001", 1, true) then return true end
          if r.title == "That's Super Tame" then return true end
        end
        return false
      end)()""") is not True)
check("a weekly pet battle quest sits on the weekly plan",
      s.eval('__LS:ActivityHorizon({ id = "pets_weekly_2001", category = "Battle Pets" })') == "WEEKLY")
s.exec("""
  QuestLog = {}
  QuestTagInfo = {}
  OwnedPetIDs = {}
  PetInfoByID = {}
  PetLoadOut = {
    [1] = { locked = false },
    [2] = { locked = false },
    [3] = { locked = false },
  }
  __LS.db.goals.PETS = false
  __LS.db.goals.QUESTING = false
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
rep_nest = s.eval("""(function()
  local nestH, bodyOver = 0, false
  local bodyLevel = __LS.bodyScroll and __LS.bodyScroll:GetFrameLevel() or 0
  for _, c in ipairs(__LS.content.children or {}) do
    if c ~= __LS.bodyScroll then
      for _, kid in ipairs(c.children or {}) do
        for _, r in ipairs(kid.regions or {}) do
          local t = r.text_value
          if t == "The War Within" or t == "Midnight" then
            nestH = c.h or 0
            bodyOver = bodyLevel > (c:GetFrameLevel() or 0)
          end
        end
      end
    end
  end
  return nestH .. "|" .. tostring(bodyOver)
end)()""")
nest_h, body_over = rep_nest.split("|", 1)
check("the reputation expansion strip does not cover the faction list",
      20 < int(float(nest_h)) < 220 and body_over == "true", rep_nest)
sizes = s.eval("""(function()
  local allW, allH, factionW, factionH
  local function visit(frame, depth)
    if depth > 16 or not frame then return end
    local label
    for _, r in ipairs(frame.regions or {}) do
      if r.text_value then label = r.text_value end
    end
    if type(label) == "string" then
      if label:find("Rank all of", 1, true) then allW, allH = frame.w, frame.h end
      if label:find("Council of Dornogal", 1, true) then factionW, factionH = frame.w, frame.h end
    end
    for _, c in ipairs(frame.children or {}) do visit(c, depth + 1) end
  end
  visit(__LS.frame, 0)
  return table.concat({ tostring(allW), tostring(allH), tostring(factionW), tostring(factionH) }, "|")
end)()""")
aw, ah, fw, fh = [int(x) for x in sizes.split("|")]
check("Rank all is bigger than an individual faction toggle",
      aw > fw and ah > fh, sizes)
check("individual faction toggles are compact",
      fh <= 22 and fw < aw, sizes)
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

s.exec("__LS.frame:Show()")
check("the main window does not capture movement keys or chat",
      s.eval("__LS.frame.keyboard") is not True)
check("the main window has no key handler that would recapture the keyboard",
      s.eval("__LS.frame.scripts.OnKeyDown") is None)
s.exec("""
  (function()
    for _, name in ipairs(UISpecialFrames) do
      local f = _G[name]
      if f and f.Hide then f:Hide() end
    end
  end)()
""")
check("Escape closes the main window", s.eval("__LS.frame:IsShown()") is not True)
check("the main window is registered to close on Escape",
      s.eval("""(function()
        for _, name in ipairs(UISpecialFrames) do
          if name == "LodestarFrame" then return true end
        end
      end)()""") is True)
s.exec("""
  __LS.frame:Show()
  __LS:ShowPage("DASHBOARD")
  ShowPageCalls = 0
  do
    local orig = __LS.ShowPage
    function __LS:ShowPage(...)
      ShowPageCalls = ShowPageCalls + 1
      return orig(self, ...)
    end
  end
""")
s.fire("PLAYER_MONEY")
check("money updates do not rebuild the window", s.eval("ShowPageCalls") == 0)
s.fire("CURRENCY_DISPLAY_UPDATE")
s.fire("GUILD_ROSTER_UPDATE")
s.fire("CALENDAR_UPDATE_EVENT_LIST")
s.fire("TRADE_SKILL_LIST_UPDATE")
check("roster, calendar, and profession list noise does not rebuild the dashboard",
      s.eval("ShowPageCalls") == 0)
s.exec("ShowPageCalls = 0")
s.fire("HOUSE_LEVEL_FAVOR_UPDATED")
check("house favor ticks do not rebuild the window", s.eval("ShowPageCalls") == 0)
s.exec("__LS.db.tokenHistory = {}")
s.exec("ShowPageCalls = 0")
s.fire("TOKEN_MARKET_PRICE_UPDATED")
s.fire("PLAYER_HOUSE_LIST_UPDATED")
s.fire("UPDATE_INSTANCE_INFO")
s.fire("WEEKLY_REWARDS_UPDATE")
s.fire("PLAYER_ENTERING_WORLD")
check("dashboard data events do not rebuild the canvas", s.eval("ShowPageCalls") == 0)
s.exec("""
  local slots = 0
  for _ in ipairs(__LS.dashboardSlots or {}) do slots = slots + 1 end
  DashboardLiveSlots = slots
""")
check("dashboard tiles stay up after a live refresh", s.eval("DashboardLiveSlots") >= 4)

s.exec("__LS.frame:Show(); __LS:ResetDashboardLayout(); __LS.dashboardEdit = true; __LS:ShowPage('DASHBOARD')")
s.timers()
edit_extra = s.texts()
check("Mythic+ is on the add list without Raider.IO",
      "Add · Mythic+" in edit_extra, edit_extra)
check("Gold is on the add list without TSM",
      "Add · Gold" in edit_extra, edit_extra)
check("the old Raider.IO add label is gone",
      "Add · Raider.IO" not in edit_extra, edit_extra)
check("TSM Gold is not a tile name",
      "Add · TSM Gold" not in edit_extra and "Add · Warband Gold" not in edit_extra, edit_extra)
s.exec("""
  OverallDungeonScore = 1800
  ChallengeMaps = { 403, 2 }
  SeasonBestForMap[403] = 12
  SeasonBestForMap[2] = 7
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Add · Mythic+")
mythic = s.texts()
check("Mythic+ edit lists score, dungeon, and teleport toggles, not the live score",
      "Score" in mythic and "Dungeons" in mythic and "Teleport" in mythic
      and "Honor 47" not in mythic, mythic)
s.click("Done editing")
mythic = s.texts()
check("Mythic+ shows the client's overall dungeon score",
      "1800" in mythic and "Mythic+" in mythic, mythic)
s.exec("""
  RaiderIO = {
    GetProfile = function()
      return {
        mythicKeystoneProfile = {
          hasRenderableData = true,
          currentScore = 2450,
          sortedDungeons = { { dungeon = { id = 403 }, level = 12 } },
        },
      }
    end,
    GetScoreColor = function(score)
      if (score or 0) >= 2000 then return 0.64, 0.21, 0.93 end
      return 1, 1, 1
    end,
  }
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
rio = s.texts()
check("Raider.IO replaces the client score when it is loaded",
      "2450" in rio and "Mythic+" in rio, rio)
check("Raider.IO paints this season's highest key on the dungeon",
      s.eval("__LS:SeasonBestKeyLevel(403)") == 12
      and s.eval("__LS:SeasonBestKeyLevel(2)") == 7)
s.exec("""
  OpenedMythicPlus = false
  __LS:OpenMythicPlus()
""")
check("Mythic+ opens the Mythic+ Dungeons tab", s.eval("OpenedMythicPlus") is True)
check("Mythic+ opens in front of Lodestar",
      s.eval("PVEFrame.frameStrata") == "DIALOG")
check("Mythic+ does not raise ChallengesFrame over the Dungeons tab",
      s.eval("ChallengesFrame.frameStrata") != "DIALOG")
s.exec("""
  PVEFrame.shown = false
  ChallengesFrame.shown = false
  GameTooltip:SetText("Raider.IO Records")
  GameTooltip.shown = true
  __LS._tipOwner = PVEFrame
  OpenedMythicPlus = false
  __LS:OpenMythicPlus()
""")
check("opening Mythic+ Dungeons hides the dashboard tooltip",
      s.eval("GameTooltip.shown") is not True)
s.exec("__LS:OpenMythicPlus()")
check("clicking Mythic+ again closes the Dungeons tab",
      s.eval("PVEFrame.shown") is not True
      and s.eval("ChallengesFrame.shown") is not True)
s.exec("""
  CastSpellByNameUsed = nil
  OpenedMythicPlus = false
  PVEFrame.shown = false
  ChallengesFrame.shown = false
""")
check("Mythic+ has no dungeon teleport until the spellbook has one",
      s.eval("__LS:MythicPlusTeleport(403)") is None)
s.exec("""
  SpellBookItems[1] = {
    name = "Path of the Rookery",
    description = "Teleport to The Rookery.",
    spellID = 4241,
  }
  SpellBookItems[2] = {
    name = "Frostbolt",
    description = "Launches a bolt of frost.",
    spellID = 116,
  }
  SpellBookSkillLines[1] = {
    name = "Hero's Path: Midnight",
    itemIndexOffset = 0,
    numSpellBookItems = 2,
  }
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
port = s.eval("""(function()
  local a = __LS:MythicPlusTeleport(403)
  local b = __LS:MythicPlusTeleport(2)
  return table.concat({
    tostring(a and a.name), tostring(b and b.name),
  }, "|")
end)()""")
check("Mythic+ matches a Keystone Hero teleport from the spellbook to this season's dungeon",
      port == "Path of the Rookery|nil", port)
s.exec("CastSpellByNameUsed = nil; OpenedMythicPlus = false")
s.click("The Rookery")
check("clicking a dungeon with Keystone Hero unlocked teleports",
      s.eval("CastSpellByNameUsed") == "Path of the Rookery")
check("that teleport does not open the Mythic+ Dungeons tab",
      s.eval("OpenedMythicPlus") is not True)
check("teleporting from Mythic+ closes the main window",
      s.eval("__LS.frame:IsShown()") is not True)
s.exec("__LS.frame:Show()")
s.exec("CastSpellByNameUsed = nil; OpenedMythicPlus = false; PVEFrame.shown = false; ChallengesFrame.shown = false")
s.click("Temple of the Jade Serpent")
check("clicking a dungeon without a Keystone Hero teleport opens Mythic+ Dungeons",
      s.eval("OpenedMythicPlus") is True
      and s.eval("CastSpellByNameUsed") is None)
s.exec("CastSpellByNameUsed = nil; __LS:CastMythicPlusTeleport(2)")
check("CastMythicPlusTeleport stays quiet when that dungeon is not unlocked",
      s.eval("CastSpellByNameUsed") is None)
s.exec("""
  SpellBookItems[1] = {
    name = "Path of the Rookery",
    spellID = 4241,
  }
  SpellBookItems[2] = nil
  SpellBookSkillLines[1] = {
    name = "Hero's Path: Midnight",
    itemIndexOffset = 0,
    numSpellBookItems = 1,
  }
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
check("Mythic+ matches Path of the Rookery to The Rookery without a description",
      s.eval("(__LS:MythicPlusTeleport(403) or {}).name") == "Path of the Rookery")
s.exec("CastSpellByNameUsed = nil; OpenedMythicPlus = false")
s.click("The Rookery")
check("a name-only Keystone Hero match still teleports",
      s.eval("CastSpellByNameUsed") == "Path of the Rookery"
      and s.eval("OpenedMythicPlus") is not True)
s.exec("""
  SpellBookItems = {
    [1] = { name = "Hero's Path", itemType = "FLYOUT", flyoutID = 9 },
  }
  SpellBookSkillLines[1] = {
    name = "Hero's Path: Midnight",
    itemIndexOffset = 0,
    numSpellBookItems = 1,
  }
  Flyouts[9] = {
    name = "Hero's Path",
    numSlots = 1,
    slots = { { spellID = 4241, name = "Path of the Rookery" } },
  }
  __LS.frame:Show()
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
check("Mythic+ matches a Keystone Hero teleport inside a spellbook flyout",
      s.eval("(__LS:MythicPlusTeleport(403) or {}).name") == "Path of the Rookery")
s.exec("CastSpellByNameUsed = nil; OpenedMythicPlus = false")
s.click("The Rookery")
check("clicking a dungeon teleports from a flyout spell",
      s.eval("CastSpellByNameUsed") == "Path of the Rookery"
      and s.eval("OpenedMythicPlus") is not True)
s.exec("""
  SpellBookItems = {}
  SpellBookSkillLines = {}
  Flyouts = {}
  CastSpellByNameUsed = nil
""")
check("a narrow activity card keeps a readable text column",
      s.eval("""(function()
        local parent = CreateFrame("Frame")
        local card = select(1, __LS:ActivityCard(parent, {
          id = "narrow_card", title = "Fill a Raid Vault slot",
          why = "The Raid Vault is empty this week.",
          score = 12, priority = "HIGH PRIORITY",
        }, 0, 200))
        local minW = 999
        for _, r in ipairs(card.regions or {}) do
          if r.text_value and (r.w or 0) > 0 then
            minW = math.min(minW, r.w)
          end
        end
        return minW
      end)()""") >= 140)
check("a high M+ score uses Raider.IO's colour",
      s.eval("""(function()
        local r, g, b = RaiderIO.GetScoreColor(2450)
        return math.abs(r - 0.64) < 0.001 and math.abs(g - 0.21) < 0.001
      end)()""") is True)
s.exec("""
  PlayerMoney = 15000000
  __LS:SaveSnapshot()
  __LS.db.characters["Alts-Testrealm"] = { gold = 50000000, name = "Alts" }
  __LS.frame:Show()
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Edit dashboard")
s.click("Add · Gold")
warband_gold = s.texts()
check("Gold edit lists gold format, not the live total",
      "Coin icons" in warband_gold and "Letters" in warband_gold
      and "6,500g" not in warband_gold, warband_gold)
s.click("Done editing")
warband_gold = s.texts()
check("the gold tile sums warband characters Lodestar has seen",
      "6,500g" in warband_gold and "0s" in warband_gold and "0c" in warband_gold
      and "Gold" in warband_gold
      and "Gold Lodestar has seen across this warband." in warband_gold
      and "TSM Gold" not in warband_gold and "Warband Gold" not in warband_gold,
      warband_gold)
s.exec("""
  GameTooltip:ClearLines()
  __LS:FillGoldTooltip(GameTooltip)
""")
gold_tip = s.eval('table.concat(GameTooltip._lines or {}, "\\n")')
check("the gold tooltip lists each character Lodestar has seen",
      "Gold" in gold_tip and "Testchar" in gold_tip and "1,500g" in gold_tip
      and "Alts" in gold_tip and "5,000g" in gold_tip, gold_tip)
s.exec("""
  table.insert(__LS.db.dashboard.widgets, { id = "gold", x = 0, y = 16, w = 6, h = 4 })
  __LS:DashboardLayout()
""")
check("the old gold-farm tile is dropped from saved layouts",
      s.eval("""(function()
        for _, e in ipairs(__LS.db.dashboard.widgets) do
          if e.id == "gold" then return true end
        end
      end)()""") is not True)
s.exec("""
  TSM_API = {}
  TSM = {
    db = {
      sync = {
        internalData = {
          goldLog = {
            ["Alpha-Testrealm"] = {
              { copper = 100000000, startMinute = 1 },
              { copper = 200000000, startMinute = 2 },
            },
            ["Beta-Testrealm"] = {
              { copper = 50000000, startMinute = 1 },
              { copper = 80000000, startMinute = 2 },
            },
          },
        },
      },
    },
  }
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
tsm = s.texts()
check("TSM does not replace the gold tile with its account log",
      "6,500g" in tsm and "0s" in tsm and "0c" in tsm
      and "Gold Lodestar has seen across this warband." in tsm
      and "TSM Gold" not in tsm and "28,000g" not in tsm, tsm)
check("letter gold still colourizes silver and copper",
      s.eval("""(function()
        local t = select(1, __LS:FormatTokenMoney(280000000, { format = "letters", separators = true, color = true }))
        return t:find("|cff", 1, true) ~= nil and t:find("28,000g", 1, true) ~= nil
          and t:find("0s", 1, true) ~= nil and t:find("0c", 1, true) ~= nil
      end)()""") is True)
s.exec("""
  local f = CreateFrame("Frame")
  f:SetSize(200, 120)
  __LS:PaintSparkline(f, { { t = 1, p = 1 }, { t = 2, p = 100000 } }, 200, -40,
    { accent = { 0.3, 0.8, 0.8 } }, "line", 400)
  local hi = 0
  for _, r in ipairs(f.regions or {}) do
    for _, pt in ipairs(r.points or {}) do
      if pt[1] == "CENTER" and (pt[5] or 0) > hi then hi = pt[5] end
    end
  end
  _G.__sparkHi, _G.__sparkH = hi, f:GetHeight()
""")
check("a sparkline stays below the text inset",
      s.eval("__sparkHi") <= s.eval("__sparkH") - 40 + 2,
      (s.eval("__sparkHi"), s.eval("__sparkH")))
s.exec("""
  CurrencyList = {
    { name = "Midnight", isHeader = true },
    { name = "Midnight Test Coin", isHeader = false, quantity = 42,
      currencyTypesID = 90001, discovered = true, iconFileID = 464076, quality = 4 },
    { name = "The War Within", isHeader = true },
    { name = "Old Expansion Coin", isHeader = false, quantity = 9,
      currencyTypesID = 90002, discovered = true, iconFileID = 132372 },
  }
  Currencies[90001] = { quantity = 42, iconFileID = 464076, quality = 4 }
  Currencies[90002] = { quantity = 9, iconFileID = 132372, quality = 1 }
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Edit dashboard")
s.click("Add · Currencies")
check("Currencies default to this expansion",
      s.eval("""(function()
        local rows = __LS:TrackedCurrencies()
        return #rows == 1 and rows[1].name == "Midnight Test Coin" and rows[1].quantity == 42
      end)()""") is True)
check("tracked currencies use the client's icon",
      s.eval("(__LS:TrackedCurrencies()[1] or {}).icon") == 464076
      and s.eval("""(function()
        local function visit(frame, depth)
          if depth > 14 or not frame then return false end
          for _, r in ipairs(frame.regions or {}) do
            if r.texture == 464076 then return true end
          end
          for _, c in ipairs(frame.children or {}) do
            if visit(c, depth + 1) then return true end
          end
          return false
        end
        return visit(__LS.frame, 0)
      end)()""") is True)
check("tracked currencies use rarity colour",
      s.eval("""(function()
        local r, g, b = __LS:QualityColor(4)
        return math.abs((r or 0) - 0.64) < 0.01 and math.abs((b or 0) - 0.93) < 0.01
      end)()""") is True)
s.click("Old Expansion Coin")
check("Currencies can track a currency from another expansion",
      s.eval("""(function()
        local rows = __LS:TrackedCurrencies()
        if #rows ~= 2 then return false end
        local names = rows[1].name .. " " .. rows[2].name
        return names:find("Midnight Test Coin", 1, true) ~= nil
           and names:find("Old Expansion Coin", 1, true) ~= nil
      end)()""") is True)
s.exec("""
  CharacterFrame.shown = false
  TokenFrame.shown = false
  OpenedCurrencies = false
  CharacterTab = nil
  __LS:OpenCurrencies()
""")
check("Currencies opens the client's currency tab",
      s.eval("OpenedCurrencies") is True
      and s.eval("CharacterFrame.shown") is True
      and s.eval("TokenFrame.shown") is True)
check("Currencies opens in front of Lodestar",
      s.eval("CharacterFrame.frameStrata") == "DIALOG")
s.exec("__LS:OpenCurrencies()")
check("clicking Currencies again closes the currency tab",
      s.eval("CharacterFrame.shown") is not True)
s.exec("""
  HonorLevel = 47
  RatedInfo[1] = { 1800, 1850, 0, 10, 5 }
  RatedInfo[2] = { 2100, 2200, 0, 20, 12 }
  RatedInfo[7] = { 1600, 1700, 0, 15, 8 }
  RatedInfo[9] = { 1400, 1450, 0, 8, 3 }
  RatedInfo[4] = { 1200, 1250, 0, 4, 2 }
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Add · PvP")
pvp_tile = s.texts()
check("PvP edit lists every bracket, including Blitz, and hides live Honor",
      "Season rating. Toggle brackets" in pvp_tile
      and "2v2" in pvp_tile and "3v3" in pvp_tile
      and "Shuffle" in pvp_tile and "Blitz" in pvp_tile and "RBG" in pvp_tile
      and "Honor 47" not in pvp_tile
      and "2v2  1800" not in pvp_tile, pvp_tile)
s.click("RBG")
s.click("Done editing")
pvp_tile = s.texts()
check("PvP shows honor level and the chosen brackets after editing",
      "Honor 47" in pvp_tile and "2v2  1800" in pvp_tile
      and "Blitz  1400" in pvp_tile and "RBG  1200" in pvp_tile, pvp_tile)
s.exec("""
  OwnedHouses = { {
    plotID = 7, houseName = "Test House", neighborhoodName = "Founder's Point",
    houseGUID = "House-1", neighborhoodGUID = "Hood-1",
  } }
  CurrentHouseFavor = 500
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Edit dashboard")
s.click("Reset widgets")
s.click("Add · Housing")
housing_tile = s.texts()
check("Housing edit lists Dashboard and Teleport, not live house favor",
      "Dashboard" in housing_tile and "Teleport" in housing_tile
      and "Test House" not in housing_tile
      and "500 / 1200 favor" not in housing_tile, housing_tile)
s.click("Done editing")
housing_tile = s.texts()
check("Housing tile shows the house name, level, and favor",
      "Test House" in housing_tile and "Level 2" in housing_tile
      and "500 / 1200 favor" in housing_tile
      and "Founder's Point" in housing_tile
      and "Teleport" in housing_tile, housing_tile)
s.exec("ShowPageCalls = 0; OwnedHouses[1].houseName = 'Cliffside Cottage'")
s.fire("PLAYER_HOUSE_LIST_UPDATED")
check("housing list events do not rebuild the dashboard", s.eval("ShowPageCalls") == 0)
housing_live = s.texts()
check("housing tile updates in place when the house list changes",
      "Cliffside Cottage" in housing_live and "Test House" not in housing_live,
      housing_live)
s.exec("OwnedHouses[1].houseName = 'Test House'")
check("Housing paints a bar toward the next house level",
      abs(s.eval("""(function()
        local function visit(frame, depth)
          if depth > 16 or not frame then return end
          for _, r in ipairs(frame.regions or {}) do
            if r.progressFill then return r.progressFill end
          end
          for _, c in ipairs(frame.children or {}) do
            local v = visit(c, depth + 1)
            if v then return v end
          end
        end
        return visit(__LS.frame, 0)
      end)()""") - (490 / 1190)) < 0.01)
s.click("Edit dashboard")
s.click("Reset widgets")
s.exec("""
  OwnedPetIDs = { "Pet-1", "Pet-2", "Pet-3" }
  PetInfoByID["Pet-1"] = { speciesID = 10, name = "Alpine Hare", icon = 132193, level = 25 }
  PetInfoByID["Pet-2"] = { speciesID = 11, name = "Blue Moth", icon = 132194, level = 10 }
  PetInfoByID["Pet-3"] = { speciesID = 10, name = "Alpine Hare", icon = 132193, level = 1 }
  PetLoadOut[1] = { petGUID = "Pet-1", locked = false }
  PetLoadOut[2] = { petGUID = "Pet-2", locked = false }
  PetLoadOut[3] = { locked = false }
  SummonedPetGUID = "Pet-1"
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Add · Battle Pets")
pets_edit = s.texts()
check("Battle Pets edit lists count, team, and summoned, not live names",
      "Count" in pets_edit and "Team" in pets_edit and "Summoned" in pets_edit
      and "Alpine Hare" not in pets_edit and "2 unique" not in pets_edit, pets_edit)
s.click("Done editing")
pets_tile = s.texts()
check("Battle Pets shows unique count and the summoned pet from the journal",
      "2 unique" in pets_tile and "Alpine Hare" in pets_tile, pets_tile)
s.exec("""
  OpenedPetJournal = false
  CollectionsJournal.shown = false
  __LS:OpenPetJournal()
""")
check("Battle Pets opens the pet journal",
      s.eval("OpenedPetJournal") is True
      and s.eval("CollectionsJournal.shown") is True
      and s.eval("CollectionsJournal.selectedTab") == 2)
s.exec("__LS:OpenPetJournal()")
check("clicking Battle Pets again closes the pet journal",
      s.eval("CollectionsJournal.shown") is not True)
s.exec("SummonedPetGUID = nil")
s.click("Alpine Hare")
check("clicking a slotted pet summons it",
      s.eval("SummonedPetGUID") == "Pet-1")
s.exec("""
  OwnedPetIDs = {}
  PetInfoByID = {}
  PetLoadOut = {
    [1] = { locked = false },
    [2] = { locked = false },
    [3] = { locked = false },
  }
  SummonedPetGUID = nil
""")
s.click("Edit dashboard")
s.click("Reset widgets")
s.exec("""
  CalendarDayEvents = {
    ["0:26"] = {
      { title = "Darkmoon Faire", calendarType = "HOLIDAY", sequenceType = "ONGOING" },
      { title = "Raid Night", calendarType = "GUILD", eventID = 11 },
    },
    ["0:27"] = {
      { title = "Dinner", calendarType = "PLAYER", invitedBy = "Friend", eventID = 12 },
    },
    ["0:30"] = {
      { title = "Next week holiday", calendarType = "HOLIDAY", sequenceType = "START" },
    },
  }
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Add · Calendar")
cal = s.texts()
check("Calendar edit lists weeks, not live holidays",
      "This week" in cal and "Next week" in cal
      and "Darkmoon Faire" not in cal
      and "Next week holiday" not in cal, cal)
s.click("Done editing")
cal = s.texts()
check("Calendar lists this week and next from the client",
      "This week" in cal and "Darkmoon Faire" in cal
      and "Guild  ·  Raid Night" in cal and "Invite  ·  Dinner" in cal
      and "Next week" in cal and "Next week holiday" in cal, cal)
s.exec("""
  OpenedCalendar = false
  __LS:OpenCalendar()
""")
check("Calendar opens the client's calendar", s.eval("OpenedCalendar") is True)
check("Calendar opens in front of Lodestar",
      s.eval("CalendarFrame.frameStrata") == "DIALOG")
s.exec("__LS:OpenCalendar()")
check("clicking Calendar again closes the calendar",
      s.eval("CalendarFrame.shown") is not True)
s.click("Edit dashboard")
s.click("Reset widgets")
s.exec("""
  GuildName = "Silvermoon Regulars"
  GuildMemberTotal = 228
  GuildOnlineCount = 4
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Add · Guild")
guild = s.texts()
check("Guild edit lists the emblem toggle, not live roster counts",
      "Emblem" in guild and "Silvermoon Regulars" not in guild
      and "4 / 228 online" not in guild, guild)
s.click("Done editing")
guild = s.texts()
check("Guild shows the name and who is online",
      "Silvermoon Regulars" in guild and "4 / 228 online" in guild, guild)
s.exec("""
  OpenedCommunities = false
  __LS:OpenCommunities()
""")
check("Guild opens the Communities window", s.eval("OpenedCommunities") is True)
s.exec("__LS:OpenCommunities()")
check("clicking Guild again closes Communities",
      s.eval("CommunitiesFrame.shown") is not True)
s.click("Edit dashboard")
s.click("Reset widgets")
s.click("Add · Delver's Journey")
delve_j = s.texts()
check("Delver's Journey edit lists the progress bar, not live rank",
      "Progress bar" in delve_j
      and "Rank 4" not in delve_j and "1200 / 4200" not in delve_j, delve_j)
s.click("Done editing")
delve_j = s.texts()
check("Delver's Journey shows this season's rank from the client",
      "Delver's Journey" in delve_j and "Season 1" in delve_j
      and "Rank 4" in delve_j and "1200 / 4200" in delve_j, delve_j)
check("Delver's Journey paints a bar toward the next rank",
      abs(s.eval("""(function()
        local function visit(frame, depth)
          if depth > 16 or not frame then return end
          for _, r in ipairs(frame.regions or {}) do
            if r.progressFill then return r.progressFill end
          end
          for _, c in ipairs(frame.children or {}) do
            local v = visit(c, depth + 1)
            if v then return v end
          end
        end
        return visit(__LS.frame, 0)
      end)()""") - (1200 / 4200)) < 0.01)
s.exec("""
  OpenedJourneys = false
  EncounterJournal.shown = false
  __LS:OpenDelvesJourney()
""")
check("Delver's Journey opens Journeys", s.eval("OpenedJourneys") is True)
s.exec("__LS:OpenDelvesJourney()")
check("clicking Delver's Journey again closes Journeys",
      s.eval("EncounterJournal.shown") is not True)
s.click("Edit dashboard")
s.click("Reset widgets")
s.click("Add · Preyhunter's Journey")
prey_j = s.texts()
check("Preyhunter's Journey edit lists the progress bar, not live rank",
      "Progress bar" in prey_j
      and "Rank 2" not in prey_j and "800 / 4000" not in prey_j, prey_j)
s.click("Done editing")
prey_j = s.texts()
check("Preyhunter's Journey shows this season's rank from the client",
      "Preyhunter's Journey" in prey_j and "Rank 2" in prey_j
      and "800 / 4000" in prey_j, prey_j)
check("Preyhunter's Journey paints a bar toward the next rank",
      abs(s.eval("""(function()
        local function visit(frame, depth)
          if depth > 16 or not frame then return end
          for _, r in ipairs(frame.regions or {}) do
            if r.progressFill then return r.progressFill end
          end
          for _, c in ipairs(frame.children or {}) do
            local v = visit(c, depth + 1)
            if v then return v end
          end
        end
        return visit(__LS.frame, 0)
      end)()""") - 0.2) < 0.01)
s.exec("""
  OpenedJourneys = false
  EncounterJournal.shown = false
  __LS:OpenPreyJourney()
""")
check("Preyhunter's Journey opens Journeys", s.eval("OpenedJourneys") is True)
s.exec("__LS:OpenPreyJourney()")
check("clicking Preyhunter's Journey again closes Journeys",
      s.eval("EncounterJournal.shown") is not True)
s.click("Edit dashboard")
s.click("Reset widgets")
s.exec("""
  EquippedItemLevel = 620
  AverageItemLevel = 640
  EquipmentQuality[1] = 4
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
s.click("Add · Item Level")
ilvl = s.texts()
check("Item Level edit lists bags, slots, and flags, not live averages",
      "Bags" in ilvl and "Slots" in ilvl and "Flags" in ilvl
      and "Equipped" not in ilvl and "In bags" not in ilvl, ilvl)
s.click("Done editing")
ilvl = s.texts()
check("Item Level shows equipped and bag averages from the client",
      "620" in ilvl and "640" in ilvl and "Equipped" in ilvl and "In bags" in ilvl, ilvl)
s.exec("""
  CharacterFrame.shown = false
  PaperDollFrame.shown = false
  OpenedCharacter = false
  CharacterTab = nil
  __LS:OpenCharacter()
""")
check("Item Level opens the character panel",
      s.eval("OpenedCharacter") is True
      and s.eval("CharacterFrame.shown") is True
      and s.eval("PaperDollFrame.shown") is True)
check("Item Level opens in front of Lodestar",
      s.eval("CharacterFrame.frameStrata") == "DIALOG")
s.exec("__LS:OpenCharacter()")
check("clicking Item Level again closes the character panel",
      s.eval("CharacterFrame.shown") is not True)
s.exec("""
  local chest = "|Hitem:99901:0:0:0:0:0:0:0:90:0|h[Chest]|h|r"
  local ring = "|Hitem:99902:4242:0:0:0:0:0:0:90:0|h[Ring]|h|r"
  EquipmentLinks[5] = chest
  EquipmentLinks[11] = ring
  EquipmentQuality[5] = 4
  EquipmentQuality[11] = 3
  EquipmentTexture[5] = 132751
  EquipmentTexture[11] = 133345
  ItemInfoByLink[chest] = { name = "Chest", quality = 4, ilvl = 677, equipLoc = "INVTYPE_CHEST", icon = 132751 }
  ItemInfoByLink[ring] = { name = "Ring", quality = 3, ilvl = 681, equipLoc = "INVTYPE_FINGER", icon = 133345 }
  ItemStats[chest] = { EMPTY_SOCKET_PRISMATIC = 1 }
  ItemStats[ring] = { EMPTY_SOCKET_PRISMATIC = 1 }
  __LS:ShowPage("DASHBOARD")
""")
s.timers()
gear = s.eval("""(function()
  local missing, socket, quiet
  for _, piece in ipairs(__LS:EquippedGear()) do
    if piece.slot == 5 then missing = piece.missingEnchant and piece.emptySocket and piece.ilvl == 677 end
    if piece.slot == 11 then socket = piece.emptySocket and not piece.missingEnchant and piece.ilvl == 681 end
    if piece.slot == 1 then quiet = piece.missingEnchant end
  end
  return tostring(missing) .. "|" .. tostring(socket) .. "|" .. tostring(quiet)
end)()""")
check("chest without an enchant is flagged, punched sockets are not invented",
      gear == "true|true|false", gear)
s.exec("""
  local helm = "|Hitem:99910:0:0:0:0:0:0:0:90:0|h[Helm]|h|r"
  local shoulder = "|Hitem:99911:0:0:0:0:0:0:0:90:0|h[Shoulder]|h|r"
  local wrist = "|Hitem:99912:0:0:0:0:0:0:0:90:0|h[Wrist]|h|r"
  local back = "|Hitem:99913:0:0:0:0:0:0:0:90:0|h[Cloak]|h|r"
  local gemmed = "|Hitem:99914:4242:12345:0:0:0:0:0:90:0|h[Gemmed Ring]|h|r"
  EquipmentLinks[1] = helm
  EquipmentLinks[3] = shoulder
  EquipmentLinks[9] = wrist
  EquipmentLinks[15] = back
  EquipmentLinks[12] = gemmed
  ItemInfoByLink[helm] = { name = "Helm", quality = 4, ilvl = 670, equipLoc = "INVTYPE_HEAD", icon = 133071 }
  ItemInfoByLink[shoulder] = { name = "Shoulder", quality = 4, ilvl = 670, equipLoc = "INVTYPE_SHOULDER", icon = 135053 }
  ItemInfoByLink[wrist] = { name = "Wrist", quality = 4, ilvl = 670, equipLoc = "INVTYPE_WRIST", icon = 132608 }
  ItemInfoByLink[back] = { name = "Cloak", quality = 4, ilvl = 670, equipLoc = "INVTYPE_CLOAK", icon = 133768 }
  ItemInfoByLink[gemmed] = { name = "Gemmed Ring", quality = 3, ilvl = 681, equipLoc = "INVTYPE_FINGER", icon = 133345 }
  ItemStats[helm] = { EMPTY_SOCKET_PRISMATIC = 1 }
  ItemStats[wrist] = { EMPTY_SOCKET_PRISMATIC = 1 }
  ItemStats[gemmed] = { EMPTY_SOCKET_PRISMATIC = 1 }
""")
slots = s.eval("""(function()
  local helmE, helmS, shE, wrE, wrS, backE, gemS
  for _, piece in ipairs(__LS:EquippedGear()) do
    if piece.slot == 1 then helmE, helmS = piece.missingEnchant, piece.emptySocket end
    if piece.slot == 3 then shE = piece.missingEnchant end
    if piece.slot == 9 then wrE, wrS = piece.missingEnchant, piece.emptySocket end
    if piece.slot == 15 then backE = piece.missingEnchant end
    if piece.slot == 12 then gemS = piece.emptySocket end
  end
  return tostring(helmE) .. "|" .. tostring(helmS) .. "|" .. tostring(shE)
    .. "|" .. tostring(wrE) .. "|" .. tostring(wrS) .. "|" .. tostring(backE)
    .. "|" .. tostring(gemS)
end)()""")
check("helm takes an enchant and a socket, shoulder an enchant, wrist a socket, back neither",
      slots == "true|true|true|false|true|false|false", slots)
check("a gemmed ring is not flagged for sockets",
      s.eval("__LS:ItemGemCount('|Hitem:99914:4242:12345:0:0:0:0:0:90:0|h[Gemmed Ring]|h|r')") == 1)
ilvl = s.texts()
check("slot icons show each piece's item level",
      "677" in ilvl and "681" in ilvl, ilvl)
check("missing enchants paint a red border on that slot",
      s.eval("""(function()
        local wr, wg, wb = __LS:MissingEnchantColor()
        local function visit(frame, depth)
          if depth > 16 or not frame then return false end
          for _, r in ipairs(frame.regions or {}) do
            if r.missingEnchant and r.color then
              return math.abs((r.color[1] or 0) - wr) < 0.02
                and math.abs((r.color[2] or 0) - wg) < 0.02
            end
          end
          for _, c in ipairs(frame.children or {}) do
            if visit(c, depth + 1) then return true end
          end
          return false
        end
        return visit(__LS.frame, 0)
      end)()""") is True)
check("the tile names the missing enchant and socket",
      "No enchant" in ilvl and "No socket" in ilvl, ilvl)
check("missing flags sit in a list beside the icons",
      "Chest  ·  No enchant" in ilvl and "Chest  ·  No socket" in ilvl
      and "Finger  ·  No socket" in ilvl, ilvl)
check("empty sockets mark the slot with a caution icon",
      s.eval("""(function()
        local function visit(frame, depth)
          if depth > 16 or not frame then return false end
          for _, r in ipairs(frame.regions or {}) do
            if r.emptySocket and type(r.texture) == "string"
                and r.texture:find("AlertNew", 1, true) then
              return true
            end
          end
          for _, c in ipairs(frame.children or {}) do
            if visit(c, depth + 1) then return true end
          end
          return false
        end
        return visit(__LS.frame, 0)
      end)()""") is True)
check("the caution sits above the missing-enchant border",
      s.eval("""(function()
        local function visit(frame, depth)
          if depth > 16 or not frame then return false end
          for _, r in ipairs(frame.regions or {}) do
            if r.emptySocket and r.points and r.points[1] then
              local yOff = r.points[1][5] or 0
              local layer = r.drawSubLevel or 0
              return yOff >= 3 and layer >= 7
            end
          end
          for _, c in ipairs(frame.children or {}) do
            if visit(c, depth + 1) then return true end
          end
          return false
        end
        return visit(__LS.frame, 0)
      end)()""") is True)
check("slot item levels use the piece's rarity colour",
      s.eval("""(function()
        local er, eg, eb = __LS:QualityColor(4)
        local function visit(frame, depth)
          if depth > 16 or not frame then return false end
          for _, r in ipairs(frame.regions or {}) do
            if r.text_value == "677" and r.color then
              return math.abs((r.color[1] or 0) - er) < 0.02
                and math.abs((r.color[2] or 0) - eg) < 0.02
            end
          end
          for _, c in ipairs(frame.children or {}) do
            if visit(c, depth + 1) then return true end
          end
          return false
        end
        return visit(__LS.frame, 0)
      end)()""") is True)
s.exec("""
  local alt = __LS.db.characters["Alts-Testrealm"]
  if alt then
    alt.knowledge = { unspent = 40, weeklyPoints = 8 }
    alt.vault = { filled = 2, total = 9, upgradable = 1 }
    alt.gold = 50000000
  else
    __LS.db.characters["Alts-Testrealm"] = {
      name = "Alts", realm = "Testrealm", level = 80,
      knowledge = { unspent = 40, weeklyPoints = 8 },
      vault = { filled = 2, total = 9, upgradable = 1 },
      gold = 50000000,
    }
  end
  PlayerMoney = 15000000
  __LS:ShowPage("WARBAND")
""")
s.timers()
warband = s.texts()
check("Warband offers Track when more than one character is saved",
      "ON  •  Track" in warband and "Untrack an alt" in warband, warband)
before_unspent = s.eval("__LS:GetWarbandTotals().unspentKnowledge")
s.click("ON  •  Track")
check("untracking an alt drops them from warband totals",
      s.eval("__LS:GetWarbandTotals().unspentKnowledge") == before_unspent - 40)
check("untracking an alt drops them from warband gold",
      s.eval("(function() local t = __LS:WarbandGold(); return t end)()") == 15000000)
check("the logged-in character stays tracked",
      s.eval("__LS:CharacterIsTracked(__LS:CharacterKey())") is True)
check("the alt can be tracked again",
      "OFF  •  Track" in s.texts(), s.texts())
s.click("OFF  •  Track")
s.exec("""
  __LS:ForgetCharacter("Alts-Testrealm")
  __LS:ShowPage("WARBAND")
""")
s.timers()
check("Track is hidden when Lodestar has only seen one character",
      "ON  •  Track" not in s.texts() and "OFF  •  Track" not in s.texts(),
      s.texts())
s.exec("__LS:ShowPage('DASHBOARD')")
s.timers()
s.exec("""
  GameTooltip:ClearLines()
  __LS:FillCurrencyTooltip(GameTooltip, 90001)
""")
check("currency tooltip uses the currency tab API",
      s.eval("GameTooltip.currencyID") == 90001)
s.exec("""
  RaiderIO.ShowProfile = function(tip, name)
    tip:SetText("profile:" .. tostring(name))
  end
  GameTooltip:ClearLines()
  __LS:FillPlayerTooltip(GameTooltip)
""")
check("Raider.IO tooltip uses the player profile, including shift refreshes",
      s.eval("GameTooltip._tip") == "profile:Testchar")
s.click("Edit dashboard")
s.click("Reset widgets")
ready_add = s.texts()
check("Readiness is on the add list",
      "Add · Readiness" in ready_add, ready_add)
s.click("Add · Readiness")
ready_edit = s.texts()
check("Readiness edit lists food, flask, rune, and weapon, not live buffs",
      "Food" in ready_edit and "Flask" in ready_edit and "Rune" in ready_edit
      and "Weapon" in ready_edit and "Slots on this tile." in ready_edit
      and "Well Fed" not in ready_edit and "in bags" not in ready_edit, ready_edit)
s.click("Done editing")
ready = s.texts()
check("Readiness shows empty slots from bags and auras",
      "Food" in ready and "Flask" in ready and "Rune" in ready and "Weapon" in ready, ready)
s.exec("UsedContainerItem = nil; __LS:UseReadinessItem('food')")
check("an empty Readiness slot does not use a bag item",
      s.eval("UsedContainerItem") is None)
s.exec("""
  local expac = GetExpansionLevel()
  ItemInfoByID[90001] = {
    name = "Test Feast", quality = 1, ilvl = 90, icon = 134062,
    classID = 0, subclassID = 5, expacID = expac,
  }
  ItemInfoByID[90011] = {
    name = "Old Snacks", quality = 1, ilvl = 10, icon = 134062,
    classID = 0, subclassID = 5, expacID = expac,
  }
  ItemInfoByID[90002] = {
    name = "Phial of Last Expansion", quality = 1, ilvl = 80, icon = 134713,
    classID = 0, subclassID = 3, expacID = expac - 1,
  }
  ItemInfoByID[90003] = {
    name = "Flask of This Season", quality = 1, ilvl = 90, icon = 134713,
    classID = 0, subclassID = 3, expacID = expac,
  }
  ItemInfoByID[90004] = {
    name = "Void-Touched Augment Rune", quality = 1, ilvl = 1, icon = 132858,
    classID = 0, subclassID = 8, expacID = expac,
  }
  ItemInfoByID[90005] = {
    name = "Test Weapon Oil", quality = 1, ilvl = 90, icon = 134795,
    classID = 0, subclassID = 6, expacID = expac,
  }
  BagContents[0] = {
    [1] = { itemID = 90001, stackCount = 20, iconFileID = 134062,
            hyperlink = "|Hitem:90001|h[Test Feast]|h" },
    [2] = { itemID = 90002, stackCount = 4, iconFileID = 134713,
            hyperlink = "|Hitem:90002|h[Phial of Last Expansion]|h" },
    [3] = { itemID = 90003, stackCount = 2, iconFileID = 134713,
            hyperlink = "|Hitem:90003|h[Flask of This Season]|h" },
    [4] = { itemID = 90004, stackCount = 3, iconFileID = 132858,
            hyperlink = "|Hitem:90004|h[Void-Touched Augment Rune]|h" },
    [6] = { itemID = 90001, stackCount = 5, iconFileID = 134062,
            hyperlink = "|Hitem:90001|h[Test Feast]|h" },
    [7] = { itemID = 90011, stackCount = 99, iconFileID = 134062,
            hyperlink = "|Hitem:90011|h[Old Snacks]|h" },
  }
  BagContents[1] = {
    [1] = { itemID = 90005, stackCount = 1, iconFileID = 134795,
            hyperlink = "|Hitem:90005|h[Test Weapon Oil]|h" },
  }
""")
ready_snap = s.eval("""(function()
  local s = __LS:ReadinessSnapshot()
  local f, k, r, w = s.food, s.flask, s.rune, s.weapon
  return table.concat({
    tostring(f and f.itemID), tostring(f and f.count), tostring(f and f.bag), tostring(f and f.slot),
    tostring(k and k.itemID), tostring(k and k.bag), tostring(k and k.slot),
    tostring(r and r.itemID), tostring(w and w.itemID),
    tostring(f and f.up), tostring(w and w.up),
  }, "|")
end)()""")
check("Readiness picks this expansion's best food, flask, rune, and oil from bags",
      ready_snap == "90001|25|0|1|90003|0|3|90004|90005|false|false", ready_snap)
s.exec("""
  PlayerAuras = {
    { name = "Well Fed", icon = 134062, expirationTime = 4600 },
    { name = "Flask of This Season", icon = 134713, expirationTime = 2800 },
    { name = "Void-Touched Augment Rune", icon = 132858, expirationTime = 1900 },
  }
  WeaponEnchantInfo = { hasMainHand = true, expiration = 1800000 }
""")
ready_up = s.eval("""(function()
  local s = __LS:ReadinessSnapshot()
  return table.concat({
    tostring(s.food.up), tostring(math.floor((s.food.remaining or 0) + 0.5)),
    tostring(s.flask.up), tostring(s.rune.up), tostring(s.weapon.up),
    tostring(math.floor((s.weapon.remaining or 0) + 0.5)),
  }, "|")
end)()""")
check("Readiness reads Well Fed, flask, augment, and weapon enchant from the client",
      ready_up == "true|3600|true|true|true|1800", ready_up)
s.exec("__LS:ShowPage('DASHBOARD')")
s.timers()
ready_hit = s.eval("""(function()
  local f = """ + FIND_BUTTON + """("Food")
  if not f then return "none" end
  return table.concat({
    tostring(f.template or ""),
    tostring(f.GetAttribute and f:GetAttribute("type") or ""),
    tostring(f.GetAttribute and f:GetAttribute("item") or ""),
  }, "|")
end)()""")
check("Readiness slots are secure item buttons, not UseContainerItem from Lua",
      ready_hit == "SecureActionButtonTemplate|item|0 1", ready_hit)
s.exec("UsedContainerItem = nil")
s.click("Food")
check("clicking Food eats the feast from bags",
      s.eval("UsedContainerItem and UsedContainerItem.bag") == 0
      and s.eval("UsedContainerItem and UsedContainerItem.slot") == 1)
s.exec("UsedContainerItem = nil; __LS:UseReadinessItem('flask')")
check("using Flask consumes this season's flask, not last expansion's",
      s.eval("UsedContainerItem and UsedContainerItem.bag") == 0
      and s.eval("UsedContainerItem and UsedContainerItem.slot") == 3)
s.exec("UsedContainerItem = nil")
s.click("Weapon")
check("clicking Weapon applies the oil from bags",
      s.eval("UsedContainerItem and UsedContainerItem.bag") == 1
      and s.eval("UsedContainerItem and UsedContainerItem.slot") == 1)
s.click("Edit dashboard")
s.click("Reset widgets")
s.click("Done editing")
s.exec("""
  RaiderIO = nil
  TSM = nil
  TSM_API = nil
  CurrencyList = {}
  HonorLevel = 0
  RatedInfo = {}
  EquipmentLinks, EquipmentQuality, EquipmentTexture = {}, {}, {}
  ItemInfoByLink = {}
  ItemInfoByID = {}
  ItemStats = {}
  BagContents = {}
  PlayerAuras = {}
  WeaponEnchantInfo = nil
  UsedContainerItem = nil
""")

s.exec("""
  __LS.db.tracked = {}
  __LS.db.compact.single = false
  __LS.db.compact.collapsed = false
  __LS:SetCompact(true)
  __LS.frame:Hide()
  __LS:UpdateCompact()
""")
s.timers()
check("compact stays empty until something is tracked",
      s.eval("#__LS:CompactActivities()") == 0)
s.exec("""
  __LS.frame:Show()
  __LS:UpdateCompact()
""")
check("compact stays up while the main window is open",
      s.eval("__LS.compact:IsShown()") is True)
check("compact has a Main button onto the full window",
      s.eval("(__LS.compact.open.text:GetText())") == "Main")
s.exec("""
  __LS.frame:Hide()
  __LS.compact.open.scripts.OnMouseUp(__LS.compact.open)
""")
check("compact Main opens the main window",
      s.eval("__LS.frame:IsShown()") is True)
s.exec("__LS.frame:Hide(); __LS:UpdateCompact()")
s.exec("""
  __LS.db.tracked = { vault_world_1_up = true }
  __LS:UpdateCompact()
""")
check("compact does not paint a raw vault id",
      s.eval('(__LS.compact.rows[1].title:GetText())') == "Upgrade World Vault slot 1")
s.exec("""
  __LS.db.tracked = {}
  local recs = __LS:GetRecommendations()
  __LS.db.tracked[recs[1].id] = true
  __LS:UpdateCompact()
""")
check("one tracked activity fills one compact row",
      s.eval("#__LS:CompactActivities()") == 1)
height1 = s.eval("__LS.compact:GetHeight()")
s.exec("""
  local recs = __LS:GetRecommendations()
  __LS.db.tracked[recs[2].id] = true
  __LS:UpdateCompact()
""")
check("a second tracked activity expands compact",
      s.eval("#__LS:CompactActivities()") == 2)
height2 = s.eval("__LS.compact:GetHeight()")
check("compact grows taller when a second row appears", height2 > height1, (height1, height2))
s.exec("__LS.db.compact.single = true; __LS:UpdateCompact()")
check("single recommendation keeps compact to one row",
      s.eval("__LS:CompactCount()") == 1 and s.eval("#__LS:CompactActivities()") == 1)
s.exec("""
  __LS.db.compact.single = false
  __LS.db.compact.collapsed = true
  __LS:UpdateCompact()
""")
height0 = s.eval("__LS.compact:GetHeight()")
check("collapsing compact contracts to the title bar", height0 < height1, (height0, height1))
s.exec("__LS.db.compact.collapsed = false; __LS:UpdateCompact()")
check("the window sits above nameplates",
      s.eval('__LS.frame.frameStrata') == "HIGH")
check("compact sits above nameplates",
      s.eval('__LS.compact and __LS.compact.frameStrata') == "HIGH")

print()
if failures:
    print(f"{len(failures)} failed: " + ", ".join(failures))
    sys.exit(1)
print("all checks passed")
