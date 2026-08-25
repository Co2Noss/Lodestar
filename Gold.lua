local _, LS = ...

-- Gold making is a goal, not a default. Prices come from TSM, Auctionator or
-- RECrystallize; Lodestar does not invent an AH. The farm list is the collector
-- circuit, not every node in the game: gathering you have trained, plus a few
-- pet farms that never expire.

LS.goldSourceOrder = { "AUTO", "TSM", "AUCTIONATOR", "RECRYSTALLIZE" }
LS.goldSourceLabels = {
  AUTO = "Auto",
  TSM = "TSM",
  AUCTIONATOR = "Auctionator",
  RECRYSTALLIZE = "RECrystallize",
}

local ADDONS = {
  { id = "TSM", name = "TSM", addon = "TradeSkillMaster",
    ready = function() return TSM_API and TSM_API.GetCustomPriceValue end },
  { id = "AUCTIONATOR", name = "Auctionator", addon = "Auctionator",
    ready = function()
      return Auctionator and Auctionator.API and Auctionator.API.v1
        and Auctionator.API.v1.GetAuctionPriceByItemID
    end },
  { id = "RECRYSTALLIZE", name = "RECrystallize", addon = "RECrystallize",
    ready = function() return RECrystallize_PriceCheckItemID or RECrystallize_PriceCheck end },
}

-- Khaz Algar rates are conservative node estimates, not a promise. Pets are ranked
-- by listing price rather than an invented drop rate.
local FARMS = {
  {
    id = "gold_herb_ka",
    title = "Herb Khaz Algar",
    minutes = 30,
    profession = 182,
    where = "Khaz Algar",
    kind = "gather",
    items = {
      { id = 210796, perHour = 36 }, -- Mycobloom
      { id = 210805, perHour = 10 }, -- Blessing Blossom
      { id = 210808, perHour = 10 }, -- Luredrop
      { id = 210802, perHour = 8 },  -- Orbinid
      { id = 210807, perHour = 8 },  -- Arathor's Spear
    },
  },
  {
    id = "gold_mine_ka",
    title = "Mine Khaz Algar",
    minutes = 30,
    profession = 186,
    where = "Khaz Algar",
    kind = "gather",
    items = {
      { id = 210928, perHour = 30 }, -- Bismuth
      { id = 210931, perHour = 8 },  -- Aqirite
      { id = 210933, perHour = 8 },  -- Ironclaw Ore
    },
  },
  {
    id = "gold_pet_whelpling",
    title = "Farm Dark Whelplings",
    minutes = 40,
    where = "Wetlands, Badlands, Burning Steppes",
    kind = "pet",
    items = { { id = 10822 } },
  },
  {
    id = "gold_pet_azure",
    title = "Farm Azure Whelplings",
    minutes = 40,
    where = "Winterspring",
    kind = "pet",
    items = { { id = 34535 } },
  },
  {
    id = "gold_pet_sprite",
    title = "Farm Sprite Darter Eggs",
    minutes = 35,
    where = "Feralas",
    kind = "pet",
    items = { { id = 11474 } },
  },
  {
    id = "gold_pet_teroclaw",
    title = "Farm Teroclaw Hatchlings",
    minutes = 25,
    where = "Talador nests",
    kind = "pet",
    items = { { id = 120051 } },
  },
}

local function AddonLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

function LS:GoldAddons()
  local out = {}
  for _, entry in ipairs(ADDONS) do
    if entry.ready() or AddonLoaded(entry.addon) then
      table.insert(out, { id = entry.id, name = entry.name })
    end
  end
  return out
end

function LS:ResolveGoldSource()
  local wanted = (self.db and self.db.goldSource) or "AUTO"
  local found = self:GoldAddons()
  if wanted ~= "AUTO" then
    for _, entry in ipairs(ADDONS) do
      if entry.id == wanted then
        if entry.ready() or AddonLoaded(entry.addon) then
          return entry.id, entry.name, true
        end
        return entry.id, entry.name, false
      end
    end
  end
  if #found > 0 then
    return found[1].id, found[1].name, true
  end
  return nil, nil, false
end

function LS:FormatGold(copper)
  copper = math.floor(tonumber(copper) or 0)
  if copper <= 0 then return "0g" end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  if g >= 100 then return g .. "g" end
  if g > 0 and s > 0 then return g .. "g " .. s .. "s" end
  if g > 0 then return g .. "g" end
  return s .. "s"
end

function LS:GetItemPrice(itemID)
  local source = self:ResolveGoldSource()
  if not source or not itemID then return nil end

  if source == "TSM" and TSM_API and TSM_API.GetCustomPriceValue then
    local itemString = "i:" .. itemID
    if TSM_API.ToItemString then
      local ok, converted = pcall(TSM_API.ToItemString, "item:" .. itemID)
      if ok and converted then itemString = converted end
    end
    for _, priceSrc in ipairs({ "DBMarket", "DBMinBuyout", "DBRecent" }) do
      local ok, price = pcall(TSM_API.GetCustomPriceValue, priceSrc, itemString)
      if ok and type(price) == "number" and price > 0 then return price end
    end
  elseif source == "AUCTIONATOR" and Auctionator and Auctionator.API and Auctionator.API.v1
      and Auctionator.API.v1.GetAuctionPriceByItemID then
    local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "Lodestar", itemID)
    if ok and type(price) == "number" and price > 0 then return price end
  elseif source == "RECRYSTALLIZE" then
    if RECrystallize_PriceCheckItemID then
      local ok, price = pcall(RECrystallize_PriceCheckItemID, itemID)
      if ok and type(price) == "number" and price > 0 then return price end
    end
    if RECrystallize_PriceCheck and GetItemInfo then
      local link = select(2, GetItemInfo(itemID))
      if link then
        local ok, price = pcall(RECrystallize_PriceCheck, link)
        if ok and type(price) == "number" and price > 0 then return price end
      end
    end
  end
end

local function KnowsProfession(parentID)
  for _, prof in ipairs(LS.professions or {}) do
    if prof.parentID == parentID then return true end
  end
end

function LS:GetGoldRecommendations()
  local out = {}
  local source, sourceName, ready = self:ResolveGoldSource()
  if not ready then return out end

  for _, farm in ipairs(FARMS) do
    if not farm.profession or KnowsProfession(farm.profession) then
      local copper, priced = 0, 0
      for _, item in ipairs(farm.items or {}) do
        local price = self:GetItemPrice(item.id)
        if price then
          priced = priced + 1
          if farm.kind == "gather" then
            copper = copper + price * (item.perHour or 0)
          elseif price > copper then
            copper = price
          end
        end
      end
      local minCopper = farm.kind == "gather" and 50000 or 10000
      if priced > 0 and copper >= minCopper then
        local why
        if farm.kind == "gather" then
          why = string.format("About %s an hour at %s prices. You have the profession, so the nodes are yours to take.",
            self:FormatGold(copper), sourceName)
        else
          why = string.format("Listed around %s on the AH (%s). The farm never expires.",
            self:FormatGold(copper), sourceName)
        end
        local score
        if farm.kind == "gather" then
          score = 16 + math.min(18, math.floor(copper / 20000))
        else
          score = 14 + math.min(16, math.floor(copper / 50000))
        end
        table.insert(out, {
          id = farm.id,
          title = farm.title,
          minutes = farm.minutes or 30,
          score = score,
          why = why,
          category = "Gold",
          tags = { GOLD = 12 },
          urgency = "LOW",
          detail = {
            source = farm.where or farm.title,
            potential = farm.kind == "gather" and (self:FormatGold(copper) .. " / hour") or self:FormatGold(copper),
            matters = why,
          },
        })
      end
    end
  end
  return out
end
