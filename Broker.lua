local LS = _G.Lodestar
if not LS then return end

-- A LibDataBroker object, so display addons can show Lodestar on their bars: ElvUI and
-- TukUI datatexts, Titan Panel, Chocolate Bar, Bazooka, and anything else that reads
-- LDB.
--
-- The library is not embedded. Every one of those addons ships LibDataBroker itself, so
-- shipping a second copy would only add a version to argue with, and a player without
-- any of them has nothing to show the object on anyway. If none is loaded Lodestar
-- simply does not register, and nothing else changes.

local NAME = "Lodestar"

-- What the datatext reads. Kept short on purpose: a datatext shares a bar with a dozen
-- others, so anything long gets cut off by the display addon rather than by us.
local MODES = {
  {
    id = "name",
    label = "Lodestar",
    note = "The name, next to the icon.",
    text = function() return NAME end,
  },
  {
    id = "today",
    label = "Tasks on the plan",
    note = "How many things Lodestar is recommending right now.",
    text = function(self)
      local recs = self.GetRecommendations and self:GetRecommendations() or {}
      return tostring(#recs) .. " to do"
    end,
  },
  {
    id = "vault",
    label = "Great Vault",
    note = "Slots filled out of the slots you can fill.",
    text = function(self)
      if not self.VaultSlotCounts then return NAME end
      local filled, total = self:VaultSlotCounts()
      return "Vault " .. tostring(filled) .. "/" .. tostring(total)
    end,
  },
  {
    id = "mplus",
    label = "Mythic+ rating",
    note = "This season's score, from the client or Raider.IO.",
    text = function(self)
      local score = self.MythicPlusScore and self:MythicPlusScore() or 0
      if not score or score <= 0 then return "No rating" end
      return "M+ " .. tostring(math.floor(score + 0.5))
    end,
  },
  {
    id = "key",
    label = "Your keystone",
    note = "The keystone in your bags, or that you have none.",
    text = function(self)
      local label = self.KeystoneLabel and self:KeystoneLabel()
      return label or "No key"
    end,
  },
  {
    id = "gold",
    label = "Gold",
    note = "What this character is carrying.",
    text = function(self)
      if not (GetMoney and self.FormatGold) then return NAME end
      return self:FormatGold(GetMoney())
    end,
  },
}
LS.brokerModes = MODES

function LS:BrokerMode()
  local want = self.db and self.db.broker
  for _, mode in ipairs(MODES) do
    if mode.id == want then return want end
  end
  return "name"
end

function LS:SetBrokerMode(id)
  local found
  for _, mode in ipairs(MODES) do
    if mode.id == id then found = id end
  end
  self.db.broker = found or "name"
  if self.Count then self:Count("broker." .. self.db.broker) end
  self:UpdateBroker()
  return self.db.broker
end

-- Whatever the chosen mode reads today. Guarded because this runs inside another
-- addon's bar: an error here would be blamed on ElvUI or Titan, not on us.
function LS:BrokerText()
  local want = self:BrokerMode()
  for _, mode in ipairs(MODES) do
    if mode.id == want then
      local ok, text = pcall(mode.text, self)
      if ok and type(text) == "string" and text ~= "" then return text end
      return NAME
    end
  end
  return NAME
end

function LS:BrokerLib()
  if not LibStub then return nil end
  local ok, lib = pcall(LibStub.GetLibrary, LibStub, "LibDataBroker-1.1", true)
  if ok then return lib end
  return nil
end

function LS:UpdateBroker()
  local obj = self.brokerObject
  if not obj then return false end
  obj.text = self:BrokerText()
  return true
end

function LS:StartBroker()
  if self.brokerObject then return self.brokerObject end
  local ldb = self:BrokerLib()
  if not ldb then return nil end

  local ok, obj = pcall(ldb.NewDataObject, ldb, NAME, {
    -- "data source" rather than "launcher" so bars that only show text still have
    -- something to show. Clicking still opens the window either way.
    type = "data source",
    label = NAME,
    text = self:BrokerText(),
    icon = self.MEDIA_ICON,
    OnClick = function(_, button)
      if button == "RightButton" then
        LS:SetPageTab("SETTINGS", "ADDONS")
        LS:OpenFull("SETTINGS")
        return
      end
      LS:Toggle()
    end,
    OnTooltipShow = function(tip)
      if not tip then return end
      tip:AddLine(NAME)
      local recs = LS.GetRecommendations and LS:GetRecommendations() or {}
      tip:AddLine(tostring(#recs) .. " on today's plan", 1, 1, 1)
      if LS.VaultSlotCounts then
        local filled, total = LS:VaultSlotCounts()
        tip:AddLine("Great Vault " .. tostring(filled) .. "/" .. tostring(total), 1, 1, 1)
      end
      local key = LS.KeystoneLabel and LS:KeystoneLabel()
      if key then tip:AddLine(key, 1, 1, 1) end
      tip:AddLine("Click to open Lodestar.")
      tip:AddLine("Right-click for what this shows.")
    end,
  })
  if not ok or not obj then return nil end

  self.brokerObject = obj
  if self.Flag then self:Flag("broker", true) end
  return obj
end
