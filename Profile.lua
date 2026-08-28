local addonName, LS = ...

-- Settings you can carry somewhere else ----------------------------------------
--
-- One string that rebuilds your setup on a fresh install, or hands your dashboard to
-- someone else. Two kinds, because those are different jobs:
--
--   Share  settings and layout only. Safe to paste in Discord.
--   Backup the same plus your own progress: what you finished, ignored, and tracked.
--
-- Neither ever carries db.characters. That table holds a name and realm for every alt
-- you have logged in on, so a "share" string built by dumping saved variables would
-- hand your whole roster to a stranger. It is also the one thing that costs nothing to
-- leave out: SaveSnapshot rebuilds it the next time you log in on each character.
--
-- The key list is an allowlist rather than a list of things to strip. A blocklist is
-- wrong by default: the day someone adds a db field holding something personal, a
-- blocklist ships it and an allowlist ignores it.

local SHARE_KEYS = {
  "goals", "dashboard", "theme", "colors", "goldSource", "waypointSource",
  "focusExpansion", "currentExpansionOnly", "sidebarCollapsed",
  "repExpansions", "repGroups", "repFactions", "keystone", "editControls",
}

-- Yours alone: window geometry, what you have finished, and what you are tracking.
local BACKUP_KEYS = {
  "compact", "frame", "minimap", "analytics", "collapsed", "pageTab", "welcomed",
  "completed", "completedAuto", "completedBlock", "completedSnapshot",
  "dismissed", "tracked", "knowledge", "seenTips", "tokenHistory", "goldHistory",
}

local PREFIX = "LODESTAR"
local FORMAT = 1
-- A string this size is already past what anyone will paste; refusing early keeps a
-- malformed or hostile paste from being decompressed into something enormous.
local MAX_INPUT = 400000
local MAX_DEPTH = 24

function LS:ProfileKeys(kind)
  local keys = {}
  for _, key in ipairs(SHARE_KEYS) do table.insert(keys, key) end
  if kind == "backup" then
    for _, key in ipairs(BACKUP_KEYS) do table.insert(keys, key) end
  end
  return keys
end

-- Serialising ------------------------------------------------------------------
--
-- Hand-written rather than "dump Lua source and loadstring it back". An import string
-- comes from someone else by definition, and loadstring on a stranger's string is
-- arbitrary code execution inside the player's client. This format cannot express
-- anything but data, so the worst a hostile string can do is fail to parse.
--
--   T / F  true / false          n<number>;      number
--   s<len>:<bytes>  string       {  k v k v  }   table

local function Write(out, value, depth)
  if depth > MAX_DEPTH then return false end
  local kind = type(value)
  if kind == "boolean" then
    table.insert(out, value and "T" or "F")
  elseif kind == "number" then
    -- %.14g keeps colour components and coordinates exact without printing a float's
    -- full noise, and never uses exponent-free forms the reader cannot parse back.
    table.insert(out, "n" .. string.format("%.14g", value) .. ";")
  elseif kind == "string" then
    table.insert(out, "s" .. #value .. ":" .. value)
  elseif kind == "table" then
    table.insert(out, "{")
    for k, v in pairs(value) do
      local kt = type(k)
      if (kt == "string" or kt == "number") and (type(v) ~= "function" and v ~= nil) then
        local before = #out
        if Write(out, k, depth + 1) and Write(out, v, depth + 1) then
          -- kept
        else
          for i = #out, before + 1, -1 do table.remove(out, i) end
        end
      end
    end
    table.insert(out, "}")
  else
    return false
  end
  return true
end

function LS:SerializeProfile(data)
  local out = {}
  if not Write(out, data, 0) then return end
  return table.concat(out)
end

local function Read(s, i, depth)
  if depth > MAX_DEPTH then return nil, i, "too deeply nested" end
  local tag = s:sub(i, i)
  if tag == "" then return nil, i, "ran out of input" end
  if tag == "T" then return true, i + 1 end
  if tag == "F" then return false, i + 1 end
  if tag == "n" then
    local stop = s:find(";", i + 1, true)
    if not stop then return nil, i, "unterminated number" end
    local value = tonumber(s:sub(i + 1, stop - 1))
    if not value then return nil, i, "bad number" end
    return value, stop + 1
  end
  if tag == "s" then
    local colon = s:find(":", i + 1, true)
    if not colon then return nil, i, "unterminated string" end
    local length = tonumber(s:sub(i + 1, colon - 1))
    if not length or length < 0 or colon + length > #s then return nil, i, "bad string length" end
    return s:sub(colon + 1, colon + length), colon + length + 1
  end
  if tag == "{" then
    local out = {}
    i = i + 1
    while true do
      if s:sub(i, i) == "}" then return out, i + 1 end
      local key, value, err
      key, i, err = Read(s, i, depth + 1)
      if err then return nil, i, err end
      if key == nil then return nil, i, "table key missing" end
      value, i, err = Read(s, i, depth + 1)
      if err then return nil, i, err end
      out[key] = value
    end
  end
  return nil, i, "unknown value"
end

function LS:DeserializeProfile(text)
  if type(text) ~= "string" or text == "" then return nil, "there is nothing to read" end
  local value, _, err = Read(text, 1, 0)
  if err then return nil, err end
  if type(value) ~= "table" then return nil, "that is not a Lodestar string" end
  return value
end

-- Making it small enough to paste ----------------------------------------------
--
-- LibDeflate is already embedded for LibOpenRaid, so compression costs nothing extra.
-- If it is somehow missing the string still works, just longer, and the letter after
-- the format number says which of the two a reader is holding.

local function Deflate()
  if LibStub then
    local ok, lib = pcall(function() return LibStub:GetLibrary("LibDeflate", true) end)
    if ok and type(lib) == "table" then return lib end
  end
  if type(LibDeflate) == "table" then return LibDeflate end
end

function LS:EncodeProfile(text)
  local lib = Deflate()
  if lib and lib.CompressDeflate and lib.EncodeForPrint then
    local ok, packed = pcall(lib.CompressDeflate, lib, text, { level = 9 })
    if ok and packed then
      local fine, printable = pcall(lib.EncodeForPrint, lib, packed)
      if fine and printable then return "Z" .. printable end
    end
  end
  return "R" .. text
end

function LS:DecodeProfile(body)
  local how, rest = body:sub(1, 1), body:sub(2)
  if how == "R" then return rest end
  if how ~= "Z" then return nil, "that string is in a format this version cannot read" end
  local lib = Deflate()
  if not (lib and lib.DecodeForPrint and lib.DecompressDeflate) then
    return nil, "this string is compressed and LibDeflate is missing"
  end
  local ok, packed = pcall(lib.DecodeForPrint, lib, rest)
  if not ok or not packed then return nil, "that string is damaged" end
  local fine, text = pcall(lib.DecompressDeflate, lib, packed)
  if not fine or not text then return nil, "that string is damaged" end
  return text
end

-- Export -----------------------------------------------------------------------

function LS:ExportProfile(kind)
  if not self.db then return end
  kind = kind == "backup" and "backup" or "share"
  local payload = { kind = kind, version = self.version, db = {} }
  for _, key in ipairs(self:ProfileKeys(kind)) do
    local value = self.db[key]
    if value ~= nil then payload.db[key] = value end
  end
  local text = self:SerializeProfile(payload)
  if not text then return end
  return PREFIX .. ":" .. FORMAT .. ":" .. self:EncodeProfile(text)
end

-- Import -----------------------------------------------------------------------

function LS:ReadProfile(input)
  if type(input) ~= "string" then return nil, "paste a Lodestar string first" end
  input = input:match("^%s*(.-)%s*$")
  if input == "" then return nil, "paste a Lodestar string first" end
  if #input > MAX_INPUT then return nil, "that string is too big to be a Lodestar profile" end
  local format, body = input:match("^" .. PREFIX .. ":(%d+):(.+)$")
  if not format then return nil, "that does not look like a Lodestar string" end
  if tonumber(format) ~= FORMAT then
    return nil, "that string came from a different version of Lodestar"
  end
  -- Chat and Discord wrap long strings, so a paste can arrive with newlines in it.
  -- Those can only be removed from the compressed form, whose alphabet has no spaces
  -- in it. The uncompressed form embeds real strings, and "Khaz Algar" needs its space.
  if body:sub(1, 1) == "Z" then body = body:gsub("%s+", "") end
  local text, err = self:DecodeProfile(body)
  if not text then return nil, err end
  local payload, why = self:DeserializeProfile(text)
  if not payload then return nil, why end
  if type(payload.db) ~= "table" then return nil, "that string carries no settings" end
  return payload
end

-- What a layout means on this account is not what it meant on theirs: a tile can come
-- from an addon they have and you do not, or be gated on HandyNotes plugins. Dropping
-- what cannot be drawn beats importing a dashboard with holes in it.
function LS:CleanImportedLayout(layout)
  local out, dropped = {}, 0
  for _, entry in ipairs(type(layout) == "table" and layout or {}) do
    local spec = type(entry) == "table" and entry.id and self:WidgetSpec(entry.id)
    if spec and self:WidgetAvailable(spec) and tonumber(entry.x) and tonumber(entry.y)
        and tonumber(entry.w) and tonumber(entry.h) then
      local placed = {
        id = entry.id,
        x = math.floor(tonumber(entry.x)), y = math.floor(tonumber(entry.y)),
        w = math.floor(tonumber(entry.w)), h = math.floor(tonumber(entry.h)),
        opts = type(entry.opts) == "table" and entry.opts or nil,
      }
      self:ClampDashboardRect(placed)
      table.insert(out, placed)
    elseif type(entry) == "table" and entry.id then
      dropped = dropped + 1
    end
  end
  return out, dropped
end

function LS:ImportProfile(input)
  local payload, err = self:ReadProfile(input)
  if not payload then return false, err end

  local applied, dropped = {}, 0
  for _, key in ipairs(self:ProfileKeys(payload.kind == "backup" and "backup" or "share")) do
    local value = payload.db[key]
    if type(value) == "table" then
      if key == "dashboard" then
        local layout = value.widgets or value
        local clean, lost = self:CleanImportedLayout(layout)
        dropped = lost
        self.db.dashboard = self.db.dashboard or {}
        self.db.dashboard.widgets = clean
        -- Rows come from the layout rather than from their screen, whose canvas may be
        -- taller than this one's.
        if self.DashboardRows and self.GrowDashboardRows then
          local needed = 0
          for _, entry in ipairs(clean) do needed = math.max(needed, entry.y + entry.h) end
          if needed > self:DashboardRows() then self:GrowDashboardRows(needed) end
        end
      else
        self.db[key] = value
      end
      table.insert(applied, key)
    elseif type(value) == "boolean" or type(value) == "string" or type(value) == "number" then
      self.db[key] = value
      table.insert(applied, key)
    end
  end

  if #applied == 0 then return false, "that string carried nothing this version understands" end
  if self.Count then self:Count("profile.imported." .. tostring(payload.kind)) end
  return true, nil, { kind = payload.kind, version = payload.version, applied = #applied, dropped = dropped }
end
