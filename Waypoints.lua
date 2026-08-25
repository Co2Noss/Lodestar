local _, LS = ...

-- TomTom if it is loaded, otherwise the client's single user waypoint.
-- Coordinates are percent (0-100), the same form WeeklyKnowledge stores.

local function AddonLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

function LS:HasTomTom()
  return (TomTom and TomTom.AddWaypoint) and true or AddonLoaded("TomTom")
end

function LS:NormalizeWaypoints(list)
  local out = {}
  for _, point in ipairs(list or {}) do
    local map = point.map or point.m or point.mapID
    local x, y = point.x, point.y
    if map and x and y then
      table.insert(out, {
        map = map,
        x = x,
        y = y,
        title = point.title or point.label,
        note = point.note,
      })
    elseif map then
      table.insert(out, {
        map = map,
        title = point.title or point.label,
        note = point.note,
      })
    end
  end
  return #out > 0 and out or nil
end

function LS:FormatWaypoint(point)
  local mapName
  if C_Map and C_Map.GetMapInfo then
    local info = C_Map.GetMapInfo(point.map)
    mapName = info and info.name
  end
  mapName = mapName or ("Map " .. tostring(point.map))
  if point.x and point.y then
    local at = string.format("%s  %.1f, %.1f", mapName, point.x, point.y)
    if point.note and point.note ~= "" then
      return at .. "\n" .. point.note
    end
    return at
  end
  return mapName
end

local function MapPoint(mapID, x, y)
  local nx, ny = x / 100, y / 100
  if UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local ok, point = pcall(UiMapPoint.CreateFromCoordinates, mapID, nx, ny)
    if ok and point then return point end
  end
  return { uiMapID = mapID, position = { x = nx, y = ny } }
end

local function PlayerOnMap(mapID)
  if not (C_Map and C_Map.GetPlayerMapPosition) then return end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return end
  if pos.GetXY then
    local x, y = pos:GetXY()
    if x and y then return x * 100, y * 100 end
  end
  if pos.x and pos.y then return pos.x * 100, pos.y * 100 end
end

local function ClosestPoint(points)
  local pinned = {}
  for _, point in ipairs(points) do
    if point.x and point.y then table.insert(pinned, point) end
  end
  if #pinned == 0 then return points[1] end
  local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local px, py
  if here then
    px, py = PlayerOnMap(here)
  end
  if not px or not py then return pinned[1] end
  local best, bestD
  for _, point in ipairs(pinned) do
    local d
    if point.map == here then
      local dx, dy = point.x - px, point.y - py
      d = dx * dx + dy * dy
    else
      d = 1000000
    end
    if not bestD or d < bestD then
      best, bestD = point, d
    end
  end
  return best
end

function LS:ClearWaypoints()
  for _, uid in ipairs(self.waypointUIDs or {}) do
    if TomTom and TomTom.RemoveWaypoint then
      pcall(TomTom.RemoveWaypoint, TomTom, uid)
    end
  end
  self.waypointUIDs = {}
  if C_Map and C_Map.ClearUserWaypoint then
    pcall(C_Map.ClearUserWaypoint)
  end
end

local function PinBlizzard(point)
  if not (point.x and point.y) then return false end
  if C_Map and C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(point.map) then
    return false
  end
  if not (C_Map and C_Map.SetUserWaypoint) then return false end
  local ok = pcall(C_Map.SetUserWaypoint, MapPoint(point.map, point.x, point.y))
  if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
    pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
  end
  return ok
end

local function PinTomTom(point)
  if not (TomTom and TomTom.AddWaypoint and point.x and point.y) then return end
  local ok, uid = pcall(TomTom.AddWaypoint, TomTom, point.map, point.x / 100, point.y / 100, {
    title = point.title or "Lodestar",
    persistent = false,
    minimap = true,
    world = true,
    crazy = true,
    from = "Lodestar",
  })
  if ok and uid then
    LS.waypointUIDs = LS.waypointUIDs or {}
    table.insert(LS.waypointUIDs, uid)
    return uid
  end
end

local function OpenMap(mapID)
  if OpenWorldMap then
    return pcall(OpenWorldMap, mapID)
  end
  if WorldMapFrame and WorldMapFrame.SetMapID then
    WorldMapFrame:Show()
    return pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
  end
end

function LS:MarkWaypoints(points, title)
  points = self:NormalizeWaypoints(points)
  if not points then
    print("|cff59d8c9Lodestar|r no map points for that.")
    return
  end
  self:ClearWaypoints()

  local pinned, zones = {}, {}
  for _, point in ipairs(points) do
    if point.x and point.y then
      table.insert(pinned, point)
    else
      table.insert(zones, point)
    end
  end

  if #pinned > 0 and self:HasTomTom() then
    for _, point in ipairs(pinned) do
      PinTomTom(point)
    end
    if TomTom and TomTom.SetClosestWaypoint then
      pcall(TomTom.SetClosestWaypoint, TomTom)
    end
    local n = #pinned
    print("|cff59d8c9Lodestar|r pinned " .. n .. " location" .. (n == 1 and "" or "s")
      .. " in TomTom" .. (title and (": " .. title) or "") .. ".")
    return
  end

  if #pinned > 0 then
    local point = ClosestPoint(pinned)
    if PinBlizzard(point) then
      local extra = #pinned > 1
        and (" The client only keeps one pin; TomTom can show all " .. #pinned .. ".")
        or ""
      print("|cff59d8c9Lodestar|r waypoint set: " .. (point.title or "location")
        .. " at " .. string.format("%.1f, %.1f", point.x, point.y) .. "." .. extra)
      return
    end
  end

  local first = points[1]
  if first and first.map then
    OpenMap(first.map)
    local names = {}
    for _, point in ipairs(points) do
      table.insert(names, point.title or self:FormatWaypoint(point))
    end
    print("|cff59d8c9Lodestar|r " .. table.concat(names, " → "))
  end
end

function LS:WaypointButtonLabel(points)
  points = self:NormalizeWaypoints(points)
  if not points then return end
  for _, point in ipairs(points) do
    if point.x and point.y then return "Waypoint" end
  end
  return "Map"
end
