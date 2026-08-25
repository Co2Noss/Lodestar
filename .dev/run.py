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
    "Core.lua", "Themes.lua", "Catalog.lua", "Knowledge.lua", "PlayerData.lua",
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


GOALS = ["Great Vault & endgame", "Solo content", "Professions", "Mounts", "Reputation", "Questing"]

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
      end)()""") == 6)
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
check("the four settings tabs are on the strip",
      all(name in settings for name in ["Goals", "Appearance", "Compact", "Layout"]),
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

# --- regression ----------------------------------------------------------
print()
print("-- regression --")
s.exec("""
  for _, key in ipairs({ "ENDGAME", "SOLO", "CRAFTING" }) do __LS.db.goals[key] = true end
  __LS:ScanVault()
  __LS:ScanProfessions()
""")
check("vault recommendations still generate", s.eval("#__LS:GetVaultRecommendations()") > 0)
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
s.click("Herbalism")
check("the selected profession tab is remembered",
      s.eval("__LS:PageTab('PROFESSIONS')") is not None)

s.exec("__LS:ShowPage('TODAY')")
s.timers()
today = s.texts()
check("Today with several goals shows a tab per category",
      "Great Vault" in today and "Solo content" in today, today)
check("Today no longer has Collapse all", "Collapse all" not in today)

s.exec("__LS:SetCompact(true); __LS.frame:Hide(); __LS:UpdateCompact()")
s.timers()
check("compact mode still has rows", s.eval("#__LS:CompactActivities()") > 0)

print()
if failures:
    print(f"{len(failures)} failed: " + ", ".join(failures))
    sys.exit(1)
print("all checks passed")
