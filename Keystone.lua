local _, LS = ...

-- Your keystone comes from the client, not from another addon. Astral Keys is a
-- convenience, not a dependency: C_MythicPlus reports the map and level directly,
-- and parsing the keystone link out of your bags covers the window before the
-- client has answered. That is the case that makes Astral Keys say "no key".

local KEY_COMMANDS = {
  ["!keys"] = true,
  ["!key"] = true,
}

-- One reply per channel per window. Several people typing !keys at once should
-- not turn into several identical lines from us.
local REPLY_THROTTLE = 8

local lastReply = {}

local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end

local function Now()
  return (GetTime and GetTime()) or 0
end

-- Keystone links are keystone:itemID:mapID:level:affix:affix:affix:affix. The item in
-- your bags already carries the real one, affixes and all, so Lodestar links that rather
-- than assembling a link out of affix IDs and hoping the client agrees.
local function KeystoneFromBags()
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink) then
    return
  end
  local maxBag = NUM_BAG_SLOTS or 4
  for bag = 0, maxBag do
    local slots = Safe(C_Container.GetContainerNumSlots, bag) or 0
    for slot = 1, slots do
      local link = Safe(C_Container.GetContainerItemLink, bag, slot)
      if type(link) == "string" then
        local mapID, level = link:match("Hkeystone:%d+:(%d+):(%d+)")
        if mapID then
          return tonumber(mapID), tonumber(level), link
        end
      end
    end
  end
end

function LS:OwnedKeystone()
  local bagMap, bagLevel, link = KeystoneFromBags()
  local mapID = Safe(C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID)
  if not mapID then
    mapID = Safe(C_MythicPlus and C_MythicPlus.GetOwnedKeystoneMapID)
  end
  local level = Safe(C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel)
  if mapID and level and level > 0 then
    -- The bag link is only the same key when the client agrees on both halves.
    -- After a run the item can lag a moment behind, and a stale link is worse
    -- than none: it would link last week's dungeon into chat.
    if tonumber(bagMap) == tonumber(mapID) and tonumber(bagLevel) == tonumber(level) then
      return tonumber(mapID), tonumber(level), link
    end
    return tonumber(mapID), tonumber(level)
  end
  return bagMap, bagLevel, link
end

-- The clickable item link, when the keystone is really in the bags.
function LS:KeystoneLink()
  local _, _, link = self:OwnedKeystone()
  return link
end

function LS:KeystoneMapName(mapID)
  if not mapID then return end
  local name = Safe(C_ChallengeMode and C_ChallengeMode.GetMapUIInfo, mapID)
  if type(name) == "string" and name ~= "" then return name end
end

-- "The Rookery +12", plus the parts so callers can colour by level.
function LS:KeystoneLabel()
  local mapID, level = self:OwnedKeystone()
  if not mapID or not level or level <= 0 then return end
  local name = self:KeystoneMapName(mapID) or ("Dungeon " .. tostring(mapID))
  return string.format("%s +%d", name, level), mapID, level
end

-- Chat gets the item link so it is hoverable and clickable, the same as linking the
-- keystone from your bags. Plain text is the fallback for a key the client knows about
-- but cannot hand us a link for.
function LS:KeystoneAnnouncement()
  local link = self:KeystoneLink()
  if link then
    return "Lodestar: " .. link
  end
  local label = self:KeystoneLabel()
  if label then
    return "Lodestar: " .. label
  end
  return "Lodestar: no keystone"
end

-- Reply on the channel the question was asked on. Whispers go back to the asker,
-- everything else answers where the room can see it.
local CHANNELS = {
  CHAT_MSG_GUILD = "GUILD",
  CHAT_MSG_OFFICER = "OFFICER",
  CHAT_MSG_PARTY = "PARTY",
  CHAT_MSG_PARTY_LEADER = "PARTY",
  CHAT_MSG_RAID = "RAID",
  CHAT_MSG_RAID_LEADER = "RAID",
  CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
  CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
  CHAT_MSG_WHISPER = "WHISPER",
}

-- Guild, officer, party, raid, instance, and whisper in the order they are offered
-- in Settings. Party leader and raid leader fold into their channel, because nobody
-- wants to answer a raid but not a raid lead.
LS.KEYSTONE_CHANNELS = {
  { "GUILD", "Guild" },
  { "OFFICER", "Officer" },
  { "PARTY", "Party" },
  { "RAID", "Raid" },
  { "INSTANCE_CHAT", "Instance" },
  { "WHISPER", "Whisper" },
}

local function Settings(self)
  self.db.keystone = self.db.keystone or {}
  self.db.keystone.channels = self.db.keystone.channels or {}
  return self.db.keystone
end

function LS:KeystoneReplyOn()
  if not self.db then return false end
  return Settings(self).reply ~= false
end

function LS:KeystoneChannelOn(channel)
  if not self.db or not channel then return false end
  if not self:KeystoneReplyOn() then return false end
  return Settings(self).channels[channel] ~= false
end

function LS:SetKeystoneReply(on)
  if not self.db then return end
  Settings(self).reply = on and true or false
end

function LS:SetKeystoneChannel(channel, on)
  if not self.db or not channel then return end
  Settings(self).channels[channel] = on and true or false
end

-- On restricted maps 12.0 hands addons the chat text as a secret value. Reading one
-- from addon code is an error, not a nil, so the text has to be cleared before any
-- string work touches it. Astral Keys guards the same way.
local function Readable(text)
  if canaccessvalue and not canaccessvalue(text) then return false end
  if issecretvalue and issecretvalue(text) then return false end
  return type(text) == "string"
end

-- Identity-2 and similar prefix guild lines with [SomeName], so strip that before
-- comparing. Anything other than the bare command is left alone.
local function CommandFrom(text)
  if not Readable(text) then return end
  text = text:gsub("^%[%a+%]%s*", "")
  text = text:lower():match("^%s*(.-)%s*$")
  if KEY_COMMANDS[text] then return text end
end

function LS:HandleChatCommand(event, text, sender)
  if not self.db then return end
  local channel = CHANNELS[event]
  if not channel then return end
  if not CommandFrom(text) then return end
  if not self:KeystoneChannelOn(channel) then return end

  local target = channel == "WHISPER" and sender or nil
  if channel == "WHISPER" and not target then return end

  local key = channel .. "|" .. (target or "")
  local now = Now()
  if lastReply[key] and now - lastReply[key] < REPLY_THROTTLE then return end
  lastReply[key] = now

  self:SendKeystoneReply(channel, target)
end

-- The real item tooltip, so hovering the tile shows affixes and duration exactly as
-- hovering the keystone in your bags does.
function LS:FillKeystoneTooltip(tip)
  if not tip then return end
  local link = self:KeystoneLink()
  if link and tip.SetHyperlink then
    local ok = pcall(tip.SetHyperlink, tip, link)
    if ok then return true end
  end
  if tip.ClearLines then pcall(tip.ClearLines, tip) end
  local label = self:KeystoneLabel()
  if tip.SetText then
    tip:SetText(label and ("Keystone: " .. label) or "No keystone")
  end
  if tip.AddLine then
    if label then
      tip:AddLine("Click to link it in chat.")
    else
      tip:AddLine("Run a Mythic+ dungeon or visit the keystone font to get one.")
    end
  end
  return true
end

-- Click or shift-click puts the key in the chat box, the same as linking it from a bag.
function LS:LinkKeystoneToChat()
  local link = self:KeystoneLink()
  if not link then return false end
  if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return true end
  -- Nothing was taking input, so open the chat box first and then insert.
  local box = _G.ChatFrame1EditBox
  if box and ChatEdit_ActivateChat then
    pcall(ChatEdit_ActivateChat, box)
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return true end
  end
  return false
end

-- Since 11.2 the real call is C_ChatInfo.SendChatMessage. The old global is a
-- deprecated shim that only exists while the loadDeprecationFallbacks CVar is set,
-- and going through it was what tripped the protected-function block.
local function Send(message, channel, target)
  if C_ChatInfo and C_ChatInfo.SendChatMessage then
    return pcall(C_ChatInfo.SendChatMessage, message, channel, nil, target)
  end
  if SendChatMessage then
    return pcall(SendChatMessage, message, channel, nil, target)
  end
  return false
end

-- 12.0 locks chat down during encounters, Mythic+, PvP matches, and on dungeon and
-- raid maps. Asking first turns a blocked-action error into a quiet, explainable no.
--
-- Only this one call describes player chat. AreOutgoingAddonChatMessagesRestricted
-- looks like it fits and does not: it covers SendAddonMessage comms, and it reads
-- true on ordinary realms, so gating replies on it silences !keys everywhere.
function LS:ChatSendBlocked()
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    if ok and locked then return true, "lockdown" end
  end
  return false
end

function LS:SendKeystoneReply(channel, target)
  local message = self:KeystoneAnnouncement()
  local blocked, why = self:ChatSendBlocked()
  -- Counted by outcome. How often a reply is answered locally instead of in the
  -- channel is the measure of how much the 12.0 chat lockdown costs this feature.
  if blocked then
    -- Say it here rather than dropping it, so the answer is still copyable and it
    -- is obvious the command was heard.
    self:PrintKeystoneLocally(message, why)
    if self.Count then self:Count("keystone.blocked") end
    return message, false
  end
  if not Send(message, channel, target) then
    self:PrintKeystoneLocally(message)
    if self.Count then self:Count("keystone.failed") end
    return message, false
  end
  if self.Count then self:Count("keystone.answered." .. tostring(channel)) end
  return message, true
end

function LS:PrintKeystoneLocally(message, why)
  if not print then return end
  local reason = ""
  if why == "lockdown" then
    reason = " (the game is blocking addon chat in here)"
  end
  print("|cff59d8c9Lodestar|r " .. message .. reason)
end

-- Sharing your key with guild tools ------------------------------------------
--
-- Guilds of WoW, Details, and REKeys do not look for Lodestar by name. They ask
-- LibOpenRaid for the guild's keys, and every client running that library answers
-- with its own. Lodestar embeds the library, so a guildie running any of them sees
-- your key without you installing Astral Keys or Details.
--
-- Answering is the library's job, not ours. It replies to requests, and it
-- re-sends on login and when a Mythic+ run ends, so there is nothing for Lodestar
-- to push. Sending our own keystone traffic on top of that would only duplicate
-- what every other client on the library is already saying.

function LS:OpenRaidLib()
  if not LibStub then return end
  -- Reading the field is itself inside the pcall: another addon's LibStub may be
  -- half-built or metatabled, and a keystone convenience must not break login.
  local ok, lib = pcall(function()
    return LibStub:GetLibrary("LibOpenRaid-1.0", true)
  end)
  if ok and type(lib) == "table" then return lib end
end

-- Whether guild tools can see this character's key through us.
function LS:KeystoneSharingOn()
  return self:OpenRaidLib() ~= nil
end
