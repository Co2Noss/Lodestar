local _, LS = ...

-- Raid / dungeon readiness. One tile: food, flask, augment rune, and weapon
-- oil or whetstone from bags and player auras this expansion. Item IDs come
-- from the client (bags / GetItemInfo), not a Midnight catalog. Clicking a
-- slot uses a SecureActionButton with that bag and slot. Addon Lua must not
-- call UseContainerItem; the client blocks it (ADDON_ACTION_FORBIDDEN).

LS.READINESS_KINDS = { "food", "flask", "rune", "weapon" }
LS.READINESS_LABELS = {
  food = "Food",
  flask = "Flask",
  rune = "Rune",
  weapon = "Weapon",
}

local function ConsumableClass()
  return (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
end

local function Subclass()
  return (Enum and Enum.ItemConsumableSubclass) or {}
end

local function KindOf(name, classID, subclassID)
  local consumable = ConsumableClass()
  if classID ~= nil and classID ~= consumable then return end
  local lower = (name or ""):lower()
  local sub = Subclass()
  local food = sub.FoodAndDrink or 5
  local flask = sub.Flask or sub.Phial or 3
  local enhance = sub.ItemEnhancement or 6
  if lower:find("augment rune", 1, true) or lower:find("augment stone", 1, true) then
    return "rune"
  end
  if subclassID == flask or lower:find("flask", 1, true) or lower:find("phial", 1, true) then
    return "flask"
  end
  if subclassID == enhance
      or lower:find("whetstone", 1, true)
      or lower:find("sharpening", 1, true)
      or lower:find("weightstone", 1, true)
      or lower:find("weapon oil", 1, true)
      or lower:find("mana oil", 1, true)
      or lower:find("wizard oil", 1, true)
      or lower:find(" oil", 1, true)
      or lower:match("oil$") then
    return "weapon"
  end
  if subclassID == food then
    return "food"
  end
end

local function AuraKind(name)
  name = (name or ""):lower()
  if name == "" then return end
  if name == "well fed" or name:find("well fed", 1, true) then return "food" end
  if name:find("flask", 1, true) or name:find("phial", 1, true) then return "flask" end
  if name:find("augment", 1, true) then return "rune" end
end

local function ItemFacts(itemID, link)
  local name, quality, ilvl, icon, classID, subclassID, expacID
  local key = itemID or link
  if C_Item and C_Item.GetItemInfoInstant then
    local id, _, _, _, instantIcon, c, sc = C_Item.GetItemInfoInstant(key)
    itemID = itemID or id
    icon = instantIcon
    classID, subclassID = c, sc
  elseif GetItemInfoInstant then
    local id, _, _, _, instantIcon, c, sc = GetItemInfoInstant(key)
    itemID = itemID or id
    icon = instantIcon
    classID, subclassID = c, sc
  end
  if GetItemInfo then
    local ok, n, itemLink, q, level, _, _, _, _, _, tex, _, c, sc, _, expac = pcall(GetItemInfo, key)
    if ok then
      name = n or name
      quality = q or quality
      ilvl = tonumber(level) or ilvl
      icon = icon or tex
      classID = classID or c
      subclassID = subclassID or sc
      expacID = tonumber(expac) or expacID
      link = link or itemLink
    end
  end
  if (not name or name == "") and type(link) == "string" then
    name = link:match("%[(.-)%]")
  end
  return {
    itemID = itemID,
    name = name,
    quality = quality,
    ilvl = tonumber(ilvl) or 0,
    icon = icon,
    classID = classID,
    subclassID = subclassID,
    expacID = expacID,
    link = link,
  }
end

local function ThisExpansion(expacID)
  local expansion = GetExpansionLevel and GetExpansionLevel()
  if not expansion or expacID == nil then return true end
  return expacID == expansion
end

local function Better(a, b)
  if not b then return a end
  if not a then return b end
  if (b.ilvl or 0) ~= (a.ilvl or 0) then
    return ((b.ilvl or 0) > (a.ilvl or 0)) and b or a
  end
  if (b.count or 0) ~= (a.count or 0) then
    return ((b.count or 0) > (a.count or 0)) and b or a
  end
  return a
end

local function BagCount(itemID, fallback)
  if itemID and GetItemCount then
    local n = GetItemCount(itemID)
    if tonumber(n) then return tonumber(n) end
  end
  return fallback or 0
end

local function ScanBags()
  local picked = {}
  local bags = NUM_BAG_SLOTS or NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
  for bag = 0, bags do
    local n
    if C_Container and C_Container.GetContainerNumSlots then
      n = C_Container.GetContainerNumSlots(bag)
    elseif GetContainerNumSlots then
      n = GetContainerNumSlots(bag)
    end
    n = tonumber(n) or 0
    for slot = 1, n do
      local info
      if C_Container and C_Container.GetContainerItemInfo then
        info = C_Container.GetContainerItemInfo(bag, slot)
      end
      local link
      if C_Container and C_Container.GetContainerItemLink then
        link = C_Container.GetContainerItemLink(bag, slot)
      elseif GetContainerItemLink then
        link = GetContainerItemLink(bag, slot)
      end
      local itemID, icon, count
      if type(info) == "table" then
        itemID = info.itemID
        icon = info.iconFileID or info.icon
        count = tonumber(info.stackCount) or 1
        link = link or info.hyperlink or info.itemLink
      end
      if not itemID and type(link) == "string" then
        itemID = tonumber(link:match("item:(%d+)"))
      end
      if itemID or link then
        local facts = ItemFacts(itemID, link)
        local kind = KindOf(facts.name, facts.classID, facts.subclassID)
        if kind and ThisExpansion(facts.expacID) then
          count = count or 1
          local row = {
            kind = kind,
            itemID = facts.itemID or itemID,
            name = facts.name,
            icon = facts.icon or icon,
            ilvl = facts.ilvl,
            quality = facts.quality,
            link = facts.link or link,
            count = count,
            bag = bag,
            slot = slot,
          }
          local current = picked[kind]
          if current and current.itemID and row.itemID and current.itemID == row.itemID then
            current.count = (current.count or 0) + count
          else
            picked[kind] = Better(current, row)
          end
        end
      end
    end
  end
  for _, row in pairs(picked) do
    row.count = BagCount(row.itemID, row.count)
  end
  return picked
end

local function ScanAuras()
  local up = {}
  local now = (GetTime and GetTime()) or 0
  local i = 1
  while i <= 80 do
    local data
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    end
    if (not data or not data.name) and UnitAura then
      local name, icon, _, _, _, expiration = UnitAura("player", i, "HELPFUL")
      if name then
        data = { name = name, icon = icon, expirationTime = expiration }
      end
    end
    if not data or not data.name then break end
    local kind = AuraKind(data.name)
    if kind and not up[kind] then
      local remaining
      if data.expirationTime and data.expirationTime > now then
        remaining = data.expirationTime - now
      end
      up[kind] = {
        name = data.name,
        icon = data.icon,
        remaining = remaining,
      }
    end
    i = i + 1
  end
  return up
end

local function WeaponEnchant()
  if not GetWeaponEnchantInfo then return end
  local hasMain, expiration = GetWeaponEnchantInfo()
  if not hasMain then return end
  local remaining
  if tonumber(expiration) then
    remaining = tonumber(expiration) / 1000
  end
  return { remaining = remaining }
end

function LS:ReadinessSnapshot()
  local items = ScanBags()
  local auras = ScanAuras()
  local weapon = WeaponEnchant()
  local out = {}
  for _, kind in ipairs(self.READINESS_KINDS) do
    local item = items[kind]
    local aura = auras[kind]
    local row = {
      kind = kind,
      label = self.READINESS_LABELS[kind],
    }
    if item then
      row.name = item.name
      row.icon = item.icon
      row.ilvl = item.ilvl
      row.quality = item.quality
      row.link = item.link
      row.count = item.count
      row.itemID = item.itemID
      row.bag = item.bag
      row.slot = item.slot
    end
    if kind == "weapon" and weapon then
      row.up = true
      row.remaining = weapon.remaining
    elseif aura then
      row.up = true
      row.remaining = aura.remaining
      row.icon = row.icon or aura.icon
      row.name = row.name or aura.name
    else
      row.up = false
    end
    out[kind] = row
  end
  return out
end

function LS:ReadinessItem(kind)
  local snap = self:ReadinessSnapshot()
  return snap and snap[kind]
end

function LS:UseReadinessItem(kind, bag, slot)
  -- Tests and non-widget callers. The Readiness tile does not call this:
  -- UseContainerItem is protected and must run from a SecureActionButton.
  if bag == nil or slot == nil then
    local row = self:ReadinessItem(kind)
    if not row then return end
    bag, slot = row.bag, row.slot
  end
  if bag == nil or slot == nil then return end
  if C_Container and C_Container.UseContainerItem then
    C_Container.UseContainerItem(bag, slot)
  elseif UseContainerItem then
    UseContainerItem(bag, slot)
  end
end
