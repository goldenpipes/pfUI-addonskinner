pfUI.addonskinner:RegisterSkin("MissingCrafts", function()
  -- upvalue the pfUI methods we use to avoid repeated lookups
  local penv = pfUI:GetEnvironment()
  local StripTextures, CreateBackdrop, SkinCloseButton, SkinScrollbar,
    SkinDropDown, SetHighlight =
  penv.StripTextures, penv.CreateBackdrop, penv.SkinCloseButton, penv.SkinScrollbar,
  penv.SkinDropDown, penv.SetHighlight

  --[[
    MissingCrafts builds its whole interface at runtime with AceGUI widgets
    (Window/Dropdown/EditBox/ScrollFrame/etc.) instead of static XML frames
    with fixed global names, and the main window itself isn't even created
    until the player opens it for the first time. That means there's nothing
    named to grab with getglobal() at load time like a normal skin would.

    Instead, the addon exposes its own class tables globally as
    MissingCrafts.Window, MissingCrafts.Dropdown, MissingCrafts.SearchField,
    MissingCrafts.CraftsList, MissingCrafts.CraftsListItem and
    MissingCrafts.OpenButton. We wrap each class's :Create() so our skinning
    code runs on every real frame the moment it's actually built, no matter
    when that happens.
  ]]

  -- Main window (AceGUI "Frame" widget)
  local Window = MissingCrafts and MissingCrafts.Window
  if Window then
    local origCreate = Window.Create
    Window.Create = function(self, ...)
      local window = origCreate(self, ...)
      pcall(function()
        local aceFrame = window._frame
        local frame = aceFrame.frame

        -- the AceGUI Frame widget uses a real Backdrop (Blizzard dialog
        -- skin) plus a couple of loose header textures rather than a
        -- template, so clear both before laying down the pfUI backdrop
        frame:SetBackdrop(nil)
        StripTextures(frame)
        CreateBackdrop(frame, nil, nil, .85)

        for _, region in ipairs({frame:GetRegions()}) do
          if region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
          end
        end

        aceFrame.titletext:SetPoint("TOP", frame.backdrop, "TOP", 0, -6)
        SkinCloseButton(window._closeButton, frame.backdrop, -6, -6)
      end)
      return window
    end
  end

  -- Profession / character filter dropdowns
  local Dropdown = MissingCrafts and MissingCrafts.Dropdown
  if Dropdown then
    local origCreate = Dropdown.Create
    Dropdown.Create = function(self, ...)
      local object = origCreate(self, ...)
      pcall(function()
        -- AceGUI's Dropdown widget is a real UIDropDownMenuTemplate frame
        -- under the hood, so the normal dropdown skinning helper applies
        local ddFrame = object._widget.dropdown
        StripTextures(ddFrame)
        SkinDropDown(ddFrame, nil, nil, nil, true)

        -- SkinDropDown stretches the clickable button (and with it, the
        -- highlight texture) across the whole box. Since highlight is
        -- Blizzard's topmost render layer, hovering anywhere on the row
        -- paints right over the label text and the arrow icon. Shrink the
        -- hit/highlight zone back down to just the arrow on the right,
        -- like a normal dropdown, so the label stays legible on hover.
        local button = ddFrame.button
        if button then
          button:ClearAllPoints()
          button:SetPoint("TOPRIGHT", ddFrame.backdrop, "TOPRIGHT", 0, 0)
          button:SetPoint("BOTTOMRIGHT", ddFrame.backdrop, "BOTTOMRIGHT", 0, 0)
          button:SetWidth(22)
        end
      end)
      return object
    end
  end

  -- Search box
  local SearchField = MissingCrafts and MissingCrafts.SearchField
  if SearchField then
    local origCreate = SearchField.Create
    SearchField.Create = function(self, ...)
      local object = origCreate(self, ...)
      pcall(function()
        local editbox = object._widget.editbox
        StripTextures(editbox, true, "BACKGROUND")
        CreateBackdrop(editbox, nil, true)
      end)
      return object
    end
  end

  -- Scrolling crafts list
  local CraftsList = MissingCrafts and MissingCrafts.CraftsList
  if CraftsList then
    local origCreate = CraftsList.Create
    CraftsList.Create = function(self, ...)
      local object = origCreate(self, ...)
      pcall(function()
        local scrollWidget = object._scrollFrame
        StripTextures(scrollWidget.scrollframe)
        SkinScrollbar(scrollWidget.scrollbar)
      end)
      return object
    end
  end

  -- Individual crafts list rows (plain, unnamed buttons pulled from a pool)
  local CraftsListItem = MissingCrafts and MissingCrafts.CraftsListItem
  if CraftsListItem then
    local origCreate = CraftsListItem.Create
    CraftsListItem.Create = function(self, ...)
      local item = origCreate(self, ...)
      pcall(function()
        local button = item._button
        if not button._pfSkinned then
          SetHighlight(button)
          if pfUI.font_default then
            local fontString = button:GetFontString()
            if fontString then
              fontString:SetFont(pfUI.font_default, 12)
            end
          end
          button._pfSkinned = true
        end
      end)
      return item
    end
  end

  -- Small toggle button MissingCrafts pins to the corner of tradeskill windows
  local OpenButton = MissingCrafts and MissingCrafts.OpenButton
  if OpenButton then
    local origCreate = OpenButton.Create
    OpenButton.Create = function(self, ...)
      local object = origCreate(self, ...)
      pcall(function()
        local button = object._frame

        local icon = button:GetNormalTexture()
        if icon then icon:SetTexCoord(.08, .92, .08, .92) end

        local highlight = button:GetHighlightTexture()
        if highlight then
          highlight:SetAllPoints(button)
          highlight:SetTexCoord(.08, .92, .08, .92)
        end

        local checked = button:GetCheckedTexture()
        if checked then
          checked:SetAllPoints(button)
          checked:SetTexCoord(.08, .92, .08, .92)
        end

        CreateBackdrop(button, nil, nil, .75)
      end)
      return object
    end
  end

  -- remove from pending list when applied
  pfUI.addonskinner:UnregisterSkin("MissingCrafts")
end)
