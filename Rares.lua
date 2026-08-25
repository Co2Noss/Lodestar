local _, LS = ...

-- Nearby rares come from HandyNotes notes packs, not a Lodestar catalog.
-- HandyNotes is the map layer; plugins such as Midnight or Silvermoon supply the
-- pins. GetNodes2 already applies each pack's show/hide. Pins are classified as
-- rares, treasures, or other map marks so a capital-city pack is not counted as
-- a rare hunt.

local MAX_WAYPOINTS = 12

local function AddonLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

local function PluginEnabled(name)
  local db = HandyNotes.db and HandyNotes.db.profile
  if db and db.enabled == false then return false end
  local enabled = db and db.enabledPlugins
  if enabled and enabled[name] == false then return false end
  return true
end

function LS:HasHandyNotes()
  if HandyNotes and type(HandyNotes.plugins) == "table" then return true end
  return AddonLoaded("HandyNotes") and true or false
end

function LS:HasHandyNotesPlugins()
  if not (HandyNotes and type(HandyNotes.plugins) == "table") then return false end
  for name, handler in pairs(HandyNotes.plugins) do
    if PluginEnabled(name) and handler and handler.GetNodes2 then
      return true
    end
  end
  return false
end

local function CoordToPercent(coord)
  if type(coord) ~= "number" then return end
  local x, y
  if HandyNotes.getXY then
    local ok, gx, gy = pcall(HandyNotes.getXY, HandyNotes, coord)
    if ok then x, y = gx, gy end
  end
  if not x then
    x = math.floor(coord / 10000) / 10000
    y = (coord % 10000) / 10000
  end
  if type(x) ~= "number" or type(y) ~= "number" then return end
  return x * 100, y * 100
end

local function TooltipTitle()
  local fs = _G.GameTooltipTextLeft1
  if fs and fs.GetText then
    local t = fs:GetText()
    if type(t) == "string" and t ~= "" then return t end
  end
  if GameTooltip and GameTooltip.GetText then
    local t = GameTooltip:GetText()
    if type(t) == "string" and t ~= "" then return t end
  end
end

local function NodeTitle(handler, pluginName, mapID, coord)
  if not handler or not handler.OnEnter then return pluginName end
  local pin = CreateFrame("Frame")
  pin.pluginName = pluginName
  pin.uiMapID = mapID
  pin.coord = coord
  if GameTooltip then
    if GameTooltip.SetOwner then pcall(GameTooltip.SetOwner, GameTooltip, pin, "ANCHOR_NONE") end
    if GameTooltip.ClearLines then pcall(GameTooltip.ClearLines, GameTooltip) end
  end
  pcall(handler.OnEnter, pin, mapID, coord)
  local title = TooltipTitle()
  if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end
  if type(title) == "string" and title ~= "" then return title end
  return pluginName
end

local function PlayerXY(mapID)
  if not (C_Map and C_Map.GetPlayerMapPosition) then return end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return end
  if pos.GetXY then
    local x, y = pos:GetXY()
    if x and y then return x * 100, y * 100 end
  end
  if pos.x and pos.y then return pos.x * 100, pos.y * 100 end
end

local function MapName(mapID)
  if C_Map and C_Map.GetMapInfo then
    local info = C_Map.GetMapInfo(mapID)
    if info and info.name then return info.name end
  end
  return "this zone"
end

local function Haystack(...)
  local parts = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" then
      table.insert(parts, v:lower())
    elseif type(v) == "table" then
      for k, val in pairs(v) do
        if type(k) == "string" then table.insert(parts, k:lower()) end
        if type(val) == "string" then table.insert(parts, val:lower()) end
      end
    end
  end
  return table.concat(parts, " ")
end

local function HasToken(hay, tokens)
  for _, tok in ipairs(tokens) do
    if hay:find(tok, 1, true) then return true end
  end
end

local RARE_ICONS = { "vignettekill", "dungeonskull", "nagaevent", "rareelite", "inv_misc_head_dragon" }
local TREASURE_ICONS = { "vignetteloot", "treasure", "chest", "garr_treasure" }
local MARK_ICONS = { "auctioneer", "mailbox", "innkeeper", "flightmaster", "vendor", "portal", "banker", "trainer" }

-- kemayo rares are npc+quest/loot with a skull icon. City packs use npc for vendors.
local function Classify(point, icon)
  local hay = Haystack(icon)
  if HasToken(hay, MARK_ICONS) then return "mark" end
  if HasToken(hay, RARE_ICONS) then return "rare" end
  if HasToken(hay, TREASURE_ICONS) then return "treasure" end
  if type(point) == "table" then
    local kind = point.type or point.kind or point.category
    if type(kind) == "string" then
      local s = kind:lower()
      if s:find("rare", 1, true) then return "rare" end
      if s:find("treasure", 1, true) or s:find("chest", 1, true) then return "treasure" end
    end
    if point.npc and (point.loot or point.quest) then return "rare" end
    if point.npc then return "mark" end
    if point.loot or point.junk then return "treasure" end
  end
  return "mark"
end

local function CollectVisible(mapID)
  local nodes, seen = {}, {}
  for pluginName, handler in pairs(HandyNotes.plugins) do
    if PluginEnabled(pluginName) and handler and handler.GetNodes2 then
      local ok, iter, state, var = pcall(handler.GetNodes2, handler, mapID, false)
      if ok and type(iter) == "function" then
        while true do
          local stepOk, coord, nodeMap, icon = pcall(iter, state, var)
          if not stepOk or coord == nil then break end
          var = coord
          local uiMap = type(nodeMap) == "number" and nodeMap or mapID
          local key = tostring(uiMap) .. ":" .. tostring(coord)
          if not seen[key] then
            seen[key] = true
            local x, y = CoordToPercent(coord)
            if x and y then
              local point = type(state) == "table" and state[coord]
              if type(point) ~= "table" then point = nil end
              table.insert(nodes, {
                map = uiMap,
                x = x,
                y = y,
                coord = coord,
                plugin = pluginName,
                handler = handler,
                kind = Classify(point, icon),
              })
            end
          end
        end
      end
    end
  end
  return nodes
end

function LS:GetHandyNotesRecommendations()
  local out = {}
  if not (HandyNotes and type(HandyNotes.plugins) == "table") then return out end
  if HandyNotes.IsEnabled then
    local ok, enabled = pcall(HandyNotes.IsEnabled, HandyNotes)
    if ok and enabled == false then return out end
  end
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then return out end

  local rares = {}
  for _, node in ipairs(CollectVisible(mapID)) do
    if node.kind == "rare" then table.insert(rares, node) end
  end
  local total = #rares
  if total == 0 then return out end

  local px, py = PlayerXY(mapID)
  if px and py then
    for _, node in ipairs(rares) do
      local dx, dy = node.x - px, node.y - py
      node.dist = dx * dx + dy * dy
    end
    table.sort(rares, function(a, b) return (a.dist or 0) < (b.dist or 0) end)
  end

  local take = math.min(MAX_WAYPOINTS, total)
  local points = {}
  for i = 1, take do
    local node = rares[i]
    table.insert(points, {
      map = node.map,
      x = node.x,
      y = node.y,
      title = NodeTitle(node.handler, node.plugin, node.map, node.coord),
    })
  end

  local zone = MapName(mapID)
  local title
  if total == 1 then
    title = "Hunt a rare HandyNotes is showing in " .. zone
  else
    title = string.format("Hunt %d rares HandyNotes is showing in %s", total, zone)
  end

  local why
  if total > take then
    why = string.format(
      "A HandyNotes pack is showing %d rares here. Treasures and other map marks stay off this card. Waypoints are the closest %d.",
      total, take)
  else
    why = string.format(
      "A HandyNotes pack is showing %d rare%s here. Treasures and other map marks stay off this card.",
      total, total == 1 and "" or "s")
  end

  table.insert(out, {
    id = "hn_rares_" .. mapID,
    title = title,
    minutes = math.min(40, math.max(8, total * 3)),
    score = 18 + math.min(8, total),
    why = why,
    category = "Solo content",
    tags = { SOLO = 10, ENDGAME = 4 },
    urgency = "LOW",
    waypoints = points,
    openLabel = LS:WaypointButtonLabel(points) or "Waypoint",
    open = function() LS:MarkWaypoints(points, title) end,
    detail = {
      nextReward = "Whatever HandyNotes still shows",
      source = "HandyNotes",
      matters = why,
    },
  })
  return out
end
