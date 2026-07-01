pfUI.addonskinner:RegisterSkin("Rinse", function()
  if not (pfUI and pfUI.api and pfUI_config) then return end

  local penv = pfUI:GetEnvironment()
  local CreateBackdrop = penv.CreateBackdrop
  local StripTextures  = penv.StripTextures
  local SkinButton     = penv.SkinButton
  local SkinCheckbox   = penv.SkinCheckbox
  local SkinSlider     = penv.SkinSlider
  local SkinScrollbar  = penv.SkinScrollbar
  local SkinCloseButton = penv.SkinCloseButton
  local hooksecurefunc = penv.hooksecurefunc or _G.hooksecurefunc

  local function safeCreateBackdrop(frame, ...)
    if frame then CreateBackdrop(frame, ...) end
  end

  local function safeStrip(frame, ...)
    if frame and StripTextures then StripTextures(frame, ...) end
  end

  local function safeSkinButton(btn)
    if btn and SkinButton then SkinButton(btn) end
  end

  local function safeSkinCheckbox(cb, size)
    if cb and SkinCheckbox then SkinCheckbox(cb, size or 20) end
  end

  local function safeSkinSlider(sl)
    if sl and SkinSlider then SkinSlider(sl) end
  end

  local function safeSkinScrollbar(sb)
    if sb and SkinScrollbar then SkinScrollbar(sb) end
  end

  local function safeSkinClose(btn, parent)
    if not btn then return end
    if SkinCloseButton then
      SkinCloseButton(btn, parent, -6, -6)
    else
      StripTextures(btn, true)
      safeSkinButton(btn)
    end
  end

  -- Main bar
  safeStrip(RinseFrame)
  safeCreateBackdrop(RinseFrame, nil, nil, .75)
  if RinseFrameBackground then RinseFrameBackground:Hide() end

  -- The three small icon buttons on the header. Preserve their icon textures,
  -- just wrap them in a pfUI backdrop and clean up the highlight.
  local headerButtons = { RinseFramePrioListButton, RinseFrameSkipListButton, RinseFrameOptionsButton }
  for _, btn in pairs(headerButtons) do
    if btn then
      safeCreateBackdrop(btn, nil, true, .75)
      local nt = btn.GetNormalTexture and btn:GetNormalTexture()
      if nt and nt.SetTexCoord then nt:SetTexCoord(.08, .92, .08, .92) end
      local ht = btn.GetHighlightTexture and btn:GetHighlightTexture()
      if ht then
        ht:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        ht:SetBlendMode("ADD")
        ht:SetAllPoints(btn)
      end
    end
  end

  -- Debuff buttons (icon panel per party member)
  for i = 1, 15 do
    local btn = getglobal("RinseFrameDebuff"..i)
    if btn then
      safeStrip(btn)
      safeCreateBackdrop(btn, nil, nil, .75)
      local icon = getglobal(btn:GetName().."Icon")
      if icon then icon:SetTexCoord(.08, .92, .08, .92) end
      local border = getglobal(btn:GetName().."Border")
      if border then border:Hide() end
    end
  end

  -- Skip List and Prio List frames share the same button set
  local listFrames = {
    { frame = RinseSkipListFrame,  prefix = "RinseSkipList",  scroll = RinseSkipListScrollFrame,  clear = RinseSkipListFrameClear,  close = RinseSkipListClose  },
    { frame = RinsePrioListFrame,  prefix = "RinsePrioList",  scroll = RinsePrioListScrollFrame,  clear = RinsePrioListFrameClear,  close = RinsePrioListClose  },
  }
  for _, entry in pairs(listFrames) do
    safeStrip(entry.frame)
    safeCreateBackdrop(entry.frame, nil, nil, .9)

    safeSkinButton(getglobal(entry.prefix.."AddTarget"))
    safeSkinButton(getglobal(entry.prefix.."AddGroup"))
    safeSkinButton(getglobal(entry.prefix.."AddClass"))
    safeSkinButton(getglobal(entry.prefix.."AddName"))
    safeSkinButton(entry.clear)
    safeSkinClose(entry.close, entry.frame)

    -- Scroll frame + scrollbar
    if entry.scroll then
      safeSkinScrollbar(getglobal(entry.scroll:GetName().."ScrollBar"))
    end

    -- List item highlight uses UI-QuestTitleHighlight; recolor to pfUI style.
    for i = 1, 10 do
      local item = getglobal(entry.prefix.."FrameButton"..i)
      if item then
        local hi = getglobal(item:GetName().."Highlight")
        if hi then
          hi:SetTexture(1, 1, 1, .1)
          hi:ClearAllPoints()
          hi:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
          hi:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -10, 0)
        end
      end
    end
  end

  -- Options frame
  if RinseOptionsFrame then
    safeStrip(RinseOptionsFrame)
    safeCreateBackdrop(RinseOptionsFrame, nil, nil, .9)

    safeSkinClose(RinseOptionsFrameCloseButton, RinseOptionsFrame)

    -- Sliders
    safeSkinSlider(RinseOptionsFrameScaleSlider)
    safeSkinSlider(RinseOptionsFrameOpacitySlider)
    safeSkinSlider(RinseOptionsFrameButtonsSlider)

    -- Left column toggles
    local checkboxes = {
      RinseOptionsFrameWyvernSting,
      RinseOptionsFrameMutatingInjection,
      RinseOptionsFrameIgnoreAbolish,
      RinseOptionsFrameShadowform,
      RinseOptionsFramePets,
      RinseOptionsFramePrint,
      RinseOptionsFrameMSBT,
      RinseOptionsFrameSound,
      RinseOptionsFrameBackdrop,
      RinseOptionsFrameShowHeader,
      RinseOptionsFrameLock,
      RinseOptionsFrameFlip,
      -- Right-column dispel-type filters
      RinseOptionsFrameFilterMagic,
      RinseOptionsFrameFilterDisease,
      RinseOptionsFrameFilterPoison,
      RinseOptionsFrameFilterCurse,
      RinseOptionsFrameFilterSnare,
    }
    for _, cb in pairs(checkboxes) do
      safeSkinCheckbox(cb, 20)
    end

    -- Buttons for the three lists inside options
    safeSkinButton(RinseOptionsFrameAddToFilter)
    safeSkinButton(RinseOptionsFrameResetFilter)
    safeSkinButton(RinseOptionsFrameAddToClassFilter)
    safeSkinButton(RinseOptionsFrameResetClassFilter)
    safeSkinButton(RinseOptionsFrameAddToBlacklist)
    safeSkinButton(RinseOptionsFrameResetBlacklist)

    -- Class dropdown selector button next to the class-filter list
    if RinseOptionsFrameSelectClass then
      safeCreateBackdrop(RinseOptionsFrameSelectClass, nil, true, .75)
      local ht = RinseOptionsFrameSelectClass.GetHighlightTexture and RinseOptionsFrameSelectClass:GetHighlightTexture()
      if ht then ht:SetAllPoints(RinseOptionsFrameSelectClass) end
    end

    -- Scrollbars for the three embedded scroll lists
    local scrolls = {
      RinseOptionsFrameFilterScrollFrame,
      RinseOptionsFrameClassFilterScrollFrame,
      RinseOptionsFrameBlacklistScrollFrame,
    }
    for _, sf in pairs(scrolls) do
      if sf then safeSkinScrollbar(getglobal(sf:GetName().."ScrollBar")) end
    end
  end

  -- Scan tooltip (used internally by Rinse) — align with pfUI tooltip look
  local tooltip_alpha = tonumber(pfUI_config.tooltip and pfUI_config.tooltip.alpha) or .9
  if RinseScanTooltip then
    safeCreateBackdrop(RinseScanTooltip, nil, nil, tooltip_alpha)
  end

  pfUI.addonskinner:UnregisterSkin("Rinse")
end)
