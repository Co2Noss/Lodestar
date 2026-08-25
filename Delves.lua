local _, LS = ...

-- Today's bountiful delves come from the map POIs, not a Lodestar list of names
-- or coordinates. GetDelvesForMap can be restricted; pcall and stay generic if
-- the client will not name them.

local MAX_WAYPOINTS = 6

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function MapInfo(id)
  return Safe(C_Map and C_Map.GetMapInfo, id)
end

local function MapName(id)
  local info = MapInfo(id)
  return info and info.name
end

local function AddMap(out, seen, id)
  if type(id) ~= "number" or seen[id] then return end
  seen[id] = true
  table.insert(out, id)
end

local function ContinentType()
  return Enum and Enum.UIMapType and Enum.UIMapType.Continent
end

local function ZoneType()
  return Enum and Enum.UIMapType and Enum.UIMapType.Zone
end

-- Walk from the player map up to the continent, then take that continent's zones.
-- Continent IDs are not hardcoded; whatever the client parents this map to is used.
local function MapsToScan()
  local maps, seen = {}, {}
  local here = Safe(C_Map and C_Map.GetBestMapForUnit, "player")
  AddMap(maps, seen, here)

  local id, continent = here, here
  for _ = 1, 8 do
    local info = id and MapInfo(id)
    if not info then break end
    if ContinentType() and info.mapType == ContinentType() then
      continent = id
      break
    end
    local parent = info.parentMapID
    if not parent or parent == 0 then
      continent = id
      break
    end
    AddMap(maps, seen, parent)
    id, continent = parent, parent
  end

  if C_Map and C_Map.GetMapChildrenInfo and continent then
    local kids = Safe(C_Map.GetMapChildrenInfo, continent, ZoneType(), true)
    if type(kids) ~= "table" then
      kids = Safe(C_Map.GetMapChildrenInfo, continent, nil, true)
    end
    if type(kids) == "table" then
      for _, child in ipairs(kids) do
        if type(child) == "table" then
          AddMap(maps, seen, child.mapID)
        elseif type(child) == "number" then
          AddMap(maps, seen, child)
        end
      end
    end
  end
  return maps
end

local function IsBountiful(poi)
  local atlas = poi and poi.atlasName
  if type(atlas) == "string" and atlas:lower():find("bountiful", 1, true) then
    return true
  end
  local desc = poi and poi.description
  if type(desc) == "string" and desc:lower():find("bountiful", 1, true) then
    return true
  end
  return false
end

-- POI position is 0-1; waypoints are percent 0-100.
local function PoiXY(poi)
  local pos = poi and poi.position
  if not pos then return end
  local x, y
  if pos.GetXY then
    x, y = pos:GetXY()
  else
    x, y = pos.x, pos.y
  end
  if type(x) ~= "number" or type(y) ~= "number" then return end
  if x <= 1 and y <= 1 then
    return x * 100, y * 100
  end
  return x, y
end

local function CollectBountiful(requirePrimary)
  local found, seen = {}, {}
  if not (C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap and C_AreaPoiInfo.GetAreaPOIInfo) then
    return found
  end
  for _, mapID in ipairs(MapsToScan()) do
    local pois = Safe(C_AreaPoiInfo.GetDelvesForMap, mapID)
    if type(pois) == "table" then
      for _, poiID in ipairs(pois) do
        local poi = Safe(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
        if type(poi) == "table" and type(poi.name) == "string" and poi.name ~= ""
            and not seen[poi.name] and IsBountiful(poi) then
          if not requirePrimary or poi.isPrimaryMapForPOI ~= false then
            seen[poi.name] = true
            local x, y = PoiXY(poi)
            table.insert(found, {
              name = poi.name,
              map = mapID,
              x = x,
              y = y,
              zone = MapName(mapID),
            })
          end
        end
      end
    end
  end
  table.sort(found, function(a, b)
    if (a.zone or "") ~= (b.zone or "") then return (a.zone or "") < (b.zone or "") end
    return (a.name or "") < (b.name or "")
  end)
  return found
end

local function PlayerMap()
  return Safe(C_Map and C_Map.GetBestMapForUnit, "player")
end

local function GenericRec()
  local map = PlayerMap()
  local points = map and { { map = map } } or nil
  return {
    id = "delve",
    title = "Complete a Bountiful Delve",
    category = "Solo content",
    urgency = "MEDIUM",
    tags = { SOLO = 10, ENDGAME = 6 },
    why = "Compact solo run that also raises your World Vault tier. The client has not named today's bountifuls; check the map for the gold-highlighted ones.",
    openLabel = "Map",
    open = points and function() LS:MarkWaypoints(points, "Bountiful Delves") end or nil,
    waypoints = points,
    detail = {
      nextReward = "World Vault progress",
      matters = "Cheapest way to fill or upgrade a World Vault slot. Open the map if the client has not named today's bountiful delves yet.",
    },
  }
end

function LS:GetBountifulDelveRecommendations()
  local out = {}
  if self.BountifulDelveWorthDoing and not self:BountifulDelveWorthDoing() then
    return out
  end

  local found = CollectBountiful(true)
  if #found == 0 then
    found = CollectBountiful(false)
  end

  if #found == 0 then
    table.insert(out, GenericRec())
    return out
  end

  local take = math.min(MAX_WAYPOINTS, #found)
  local points, names = {}, {}
  for i = 1, take do
    local delve = found[i]
    local label = delve.name
    if delve.zone and delve.zone ~= "" then
      label = delve.name .. " (" .. delve.zone .. ")"
    end
    table.insert(names, label)
    table.insert(points, {
      map = delve.map,
      x = delve.x,
      y = delve.y,
      title = delve.name,
    })
  end

  local title
  if #found == 1 then
    title = "Run " .. found[1].name .. " (Bountiful)"
  else
    title = "Run today's bountiful delves"
  end

  local why
  if #found == 1 then
    why = names[1] .. " is bountiful on the map today."
  elseif #found > take then
    why = string.format("%d bountiful delves on the map today. Waypoints are the first %d: %s.",
      #found, take, table.concat(names, ", "))
  else
    why = "Bountiful on the map today: " .. table.concat(names, ", ") .. "."
  end

  table.insert(out, {
    id = "delve",
    title = title,
    category = "Solo content",
    urgency = "MEDIUM",
    tags = { SOLO = 10, ENDGAME = 6 },
    why = why,
    waypoints = points,
    openLabel = self:WaypointButtonLabel(points) or "Map",
    open = function() LS:MarkWaypoints(points, title) end,
    detail = {
      nextReward = "World Vault progress",
      source = "Map",
      matters = why,
    },
  })
  return out
end
