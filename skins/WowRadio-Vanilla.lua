--[[
  pfUI Addon Skinner - WowRadio-Vanilla
  Reskins the WowRadio-Vanilla controller, minimap button and custom URL
  dialog to match pfUI's flat, pixel-bordered look.

  WowRadio-Vanilla builds its whole UI by hand in Core.lua (no Blizzard
  template windows), so most of this skin just strips the addon's own
  backdrop art and standard UIPanelButtonTemplate button textures and
  replaces them with pfUI.api.CreateBackdrop / pfUI.api.SkinButton calls.

  The controller frame is only created once WowRadio finishes its own
  OnEnable(), which can happen slightly after ADDON_LOADED fires for
  "WowRadio-Vanilla" depending on load order, so we use pfUI's
  HookAddonOrVariable helper to defer until it is safe.
]]

pfUI.addonskinner:RegisterSkin("WowRadio-Vanilla", function()

  local StripTextures  = pfUI.api.StripTextures
  local CreateBackdrop  = pfUI.api.CreateBackdrop
  local SkinButton      = pfUI.api.SkinButton
  local SkinSlider       = pfUI.api.SkinSlider
  local HandleIcon       = pfUI.api.HandleIcon
  local SetAllPointsOffset = pfUI.api.SetAllPointsOffset

  local function SkinWowRadio()
    if not WowRadioFrame then return end
    local f = WowRadioFrame

    ------------------------------------------------------------------
    -- Main controller window
    ------------------------------------------------------------------
    -- drop the blizzard tooltip-border backdrop and the addon's own
    -- split bg_left/bg_right artwork, replace with the flat pfUI panel
    f:SetBackdrop(nil)
    if f.bgTextureLeft then f.bgTextureLeft:Hide() end
    if f.bgTextureRight then f.bgTextureRight:Hide() end
    CreateBackdrop(f, nil, nil, .85)

    ------------------------------------------------------------------
    -- Title row buttons (close / minimize / fade / mute)
    ------------------------------------------------------------------
    if f.closeButton then SkinButton(f.closeButton, 1, .25, .25) end
    if f.minimizeButton then SkinButton(f.minimizeButton) end
    if f.fadeButton then SkinButton(f.fadeButton) end
    if f.muteButton then SkinButton(f.muteButton) end

    ------------------------------------------------------------------
    -- Transport / paging controls
    ------------------------------------------------------------------
    local transportButtons = {
      "prevButton", "playButton", "stopButton", "nextButton",
      "randomButton", "autoButton", "customButton",
      "pagePrev", "pageNext",
    }

    for _, key in ipairs(transportButtons) do
      if f[key] then SkinButton(f[key]) end
    end

    ------------------------------------------------------------------
    -- Category tabs
    ------------------------------------------------------------------
    if f.tabButtons then
      for _, tabButton in pairs(f.tabButtons) do
        SkinButton(tabButton)
      end
    end

    ------------------------------------------------------------------
    -- Station rows (favorite toggle + station buttons)
    ------------------------------------------------------------------
    if f.rows then
      for _, row in ipairs(f.rows) do
        if row.star then SkinButton(row.star) end
        if row.row then SkinButton(row.row) end
      end
    end

    ------------------------------------------------------------------
    -- Volume slider
    ------------------------------------------------------------------
    if WowRadioVolumeSlider then
      SkinSlider(WowRadioVolumeSlider)
    end

    ------------------------------------------------------------------
    -- Resize grip
    ------------------------------------------------------------------
    if f.sizer then
      f.sizer:SetNormalTexture("")
      f.sizer:SetHighlightTexture("")
      f.sizer:SetPushedTexture("")
    end

    ------------------------------------------------------------------
    -- Now playing strip
    ------------------------------------------------------------------
    if f.nowBack and not f.nowBackdrop then
      -- keep the black fill (it still reads fine), just frame it with
      -- a proper pfUI border so it doesn't float unbordered
      local shell = CreateFrame("Frame", nil, f)
      shell:SetAllPoints(f.nowBack)
      CreateBackdrop(shell, nil, nil, .9)
      f.nowBackdrop = shell
    end

    ------------------------------------------------------------------
    -- Text fonts, to match pfUI's default font/size
    ------------------------------------------------------------------
    local font = pfUI.font_default
    local size = pfUI_config.global.font_size

    local fontStrings = {
      f.nowStatusText, f.nowStationText, f.pageText,
      f.volumeLabel, f.volumeValueText,
    }

    for _, fs in ipairs(fontStrings) do
      if fs then fs:SetFont(font, size, "OUTLINE") end
    end

    ------------------------------------------------------------------
    -- Custom stream URL dialog
    ------------------------------------------------------------------
    if WowRadioUrlDialog then
      StripTextures(WowRadioUrlDialog)
      CreateBackdrop(WowRadioUrlDialog, nil, nil, .9)

      for _, child in ipairs({ WowRadioUrlDialog:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" then
          SkinButton(child)
        end
      end
    end

    if WowRadioUrlEditBox then
      StripTextures(WowRadioUrlEditBox, true, "BACKGROUND")
      CreateBackdrop(WowRadioUrlEditBox, nil, true)
    end

    ------------------------------------------------------------------
    -- Minimap button
    ------------------------------------------------------------------
    if WowRadioMinimapButton then
      local btn = WowRadioMinimapButton
      local icon

      for _, region in ipairs({ btn:GetRegions() }) do
        if region.GetTexture then
          local tex = region:GetTexture()
          if tex and string.find(tex, "TrackingBorder") then
            region:Hide()
          elseif tex and string.find(tex, "EngGizmos") then
            icon = region
          end
        end
      end

      if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
      CreateBackdrop(btn, nil, true)

      if icon then HandleIcon(btn, icon) end
    end
  end

  -- WowRadio's controller frame is built inside its own OnEnable(),
  -- which may not have run yet the instant ADDON_LOADED fires for it.
  -- Wait for VARIABLES_LOADED/PLAYER_ENTERING_WORLD to be safe.
  pfUI.api.HookAddonOrVariable("WowRadio-Vanilla", SkinWowRadio)

  -- remove from pending list, actual skinning happens via the hook above
  pfUI.addonskinner:UnregisterSkin("WowRadio-Vanilla")
end)
