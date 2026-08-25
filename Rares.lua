local _, LS = ...

-- Nearby rares come from HandyNotes, not a Lodestar catalog. GetNodes2 already
-- applies each plugin's show/hide (known rewards, completed quests, disabled
-- plugins), so Lodestar ranks what is on the map and stays quiet otherwise.

local MAX_WAYPOINTS = 12

local function AddonLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

function LS:HasHandyNotes()
  if HandyNotes and type(HandyNotes.plugins) == "table" then return true end
  return AddonLoaded("HandyNotes") and true or false
end

local function PluginEnabled(name)
  local db = HandyNotes.db and HandyNotes.db.profile
  if db and db.enabled == false then return false end
  local enabled = db and db.enabledPlugins
  if enabled and enabled[name] == false then return false end
  return true
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

local function CollectVisible(mapID)
  local nodes, seen = {}, {}
  for pluginName, handler in pairs(HandyNotes.plugins) do
    if PluginEnabled(pluginName) and handler and handler.GetNodes2 then
      local ok, iter, state, var = pcall(handler.GetNodes2, handler, mapID, false)
      if ok and type(iter) == "function" then
        while true do
          local stepOk, coord, nodeMap = pcall(iter, state, var)
          if not stepOk or coord == nil then break end
          var = coord
          local uiMap = type(nodeMap) == "number" and nodeMap or mapID
          local key = tostring(uiMap) .. ":" .. tostring(coord)
          if not seen[key] then
            seen[key] = true
            local x, y = CoordToPercent(coord)
            if x and y then
              table.insert(nodes, {
                map = uiMap,
                x = x,
                y = y,
                coord = coord,
                plugin = pluginName,
                handler = handler,
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

  local nodes = CollectVisible(mapID)
  local total = #nodes
  if total == 0 then return out end

  local px, py = PlayerXY(mapID)
  if px and py then
    for _, node in ipairs(nodes) do
      local dx, dy = node.x - px, node.y - py
      node.dist = dx * dx + dy * dy
    end
    table.sort(nodes, function(a, b) return (a.dist or 0) < (b.dist or 0) end)
  end

  local take = math.min(MAX_WAYPOINTS, total)
  local points = {}
  for i = 1, take do
    local node = nodes[i]
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
      "HandyNotes is showing %d rares here. Known rewards stay hidden because HandyNotes already hid them. Waypoints are the closest %d.",
      total, take)
  else
    why = string.format(
      "HandyNotes is showing %d rare%s here. Known rewards stay hidden because HandyNotes already hid them.",
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
