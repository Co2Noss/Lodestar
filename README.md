# Lodestar 0.3.0

**Tagline:** Find what matters. Ignore the rest.

Lodestar is the renamed successor to the Azeroth Compass prototype.

## Added in 0.2
- Detects primary professions and skill levels.
- Scans visible reputation progress.
- Displays mount collection totals.
- Counts class-usable collected and available appearances.
- Adjusts recommendations using profession availability and completed reputation progress.
- Adds an initial versioned Patch 12.1 recommendation record.

## Install
1. Remove the old `AzerothCompass` prototype folder.
2. Copy `Lodestar` into `_retail_/Interface/AddOns/`.
3. Enable **Lodestar** and type `/ls`.

## Test checklist
- Open with `/ls` and toggle all six goals.
- Confirm primary professions appear after login or opening a profession.
- Compare mount numbers with the Collection Journal.
- Change reputation progress and confirm `/reload` refreshes it.
- Change specialization/class usability filters and review appearance totals.

## Scope note
Recipe-to-reputation matching and exact mount/appearance source ranking require a maintained data catalog. The current build detects player state and establishes the provider/scoring architecture for that catalog.


## Added in 0.3
- Auto-detects ElvUI and EllesmereUI.
- Uses ElvUI backdrop, border, and class-color values when available.
- Provides a safe Ellesmere-inspired theme without depending on undocumented internals.
- Adds manual overrides: `/ls theme auto`, `blizzard`, `elvui`, `ellesmere`, or `minimal`.
- Shows the active theme in the window footer.
