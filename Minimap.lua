local _, LS = ...

function LS:CreateMinimapButton()
  if self.minimapButton then return end
  local button = CreateFrame("Button", "LodestarMinimapButton", Minimap)
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -8, 8)
  button:RegisterForClicks("AnyUp")
  button:RegisterForDrag("LeftButton")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(LS.MEDIA_ICON or LS.MEDIA)
  icon:SetAllPoints()
  button.icon = icon

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      LS:ToggleCompact()
    else
      LS:Toggle()
    end
  end)
  button:SetScript("OnEnter", function(selfButton)
    local compactOn = LS.db and LS.db.compact and LS.db.compact.enabled
    GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
    GameTooltip:AddLine("Lodestar", 0.95, 0.72, 0.22)
    GameTooltip:AddLine("Find what matters. Ignore the rest.", 0.85, 0.9, 0.92, true)
    GameTooltip:AddLine("Left click to open.", 0.55, 0.85, 0.82)
    GameTooltip:AddLine(compactOn and "Right click to hide compact mode." or "Right click for compact mode.",
      0.55, 0.85, 0.82)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:SetScript("OnDragStart", function(selfButton) selfButton:StartMoving() end)
  button:SetScript("OnDragStop", function(selfButton) selfButton:StopMovingOrSizing() end)
  button:SetMovable(true)
  self.minimapButton = button
end
