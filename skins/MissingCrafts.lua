pfUI.addonskinner:RegisterSkin("MissingCrafts", function()
  -- upvalue the pfUI methods we use to avoid repeated lookups
  local penv = pfUI:GetEnvironment()
  local StripTextures, CreateBackdrop, SkinCloseButton, SkinScrollbar,
    SetHighlight, HookScript, SkinSlider, SetAllPointsOffset =
  penv.StripTextures, penv.CreateBackdrop, penv.SkinCloseButton, penv.SkinScrollbar,
  penv.SetHighlight, penv.HookScript, penv.SkinSlider, penv.SetAllPointsOffset

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
        -- for its box artwork, BUT its actual popup list is a totally
        -- custom "Dropdown-Pullout" widget, not Blizzard's native
        -- DropDownList1/ToggleDropDownMenu system. pfUI's own SkinDropDown
        -- helper assumes a real Blizzard dropdown and, on every click,
        -- resizes and repositions DropDownList1 - Blizzard's single global
        -- shared dropdown list frame used by every native dropdown in the
        -- whole game - to match this box. Since our box has no real
        -- relationship to DropDownList1, that just grows an unrelated
        -- global frame a little more on every click, which is likely both
        -- the missing text/arrow and the memory crash. So we skin only the
        -- box's own artwork by hand here and never touch its OnClick.
        local ddFrame = object._widget.dropdown
        StripTextures(ddFrame)
        CreateBackdrop(ddFrame, nil, nil, .85)
        ddFrame.backdrop:SetPoint("TOPLEFT", 15, -1)
        ddFrame.backdrop:SetPoint("BOTTOMRIGHT", -15, 6)

        -- We skin this the instant it's constructed, before it's ever been
        -- placed into the real widget hierarchy, so ddFrame:GetFrameLevel()
        -- can still read as an unestablished low value here. CreateBackdrop
        -- derives the backdrop's level as ddFrame's level minus one, and
        -- when that starting level is too low the two end up equal (or the
        -- backdrop even higher), so the backdrop paints over the Text
        -- region instead of behind it. Pin both explicitly so the stacking
        -- is correct regardless of what level ddFrame happened to be at.
        local baseLevel = ddFrame:GetFrameLevel() or 1
        ddFrame.backdrop:SetFrameLevel(baseLevel)
        ddFrame:SetFrameLevel(baseLevel + 2)

        local button = object._widget.button
        if button then
          button:SetNormalTexture(nil)
          button:SetPushedTexture(nil)
          button:SetHighlightTexture(nil)
          button:SetDisabledTexture(nil)

          -- shrink the arrow's own click zone to the right edge only, so
          -- the label text stays legible and clickable on its own, without
          -- touching the button's existing OnClick handler at all
          button:ClearAllPoints()
          button:SetPoint("TOPRIGHT", ddFrame.backdrop, "TOPRIGHT", 0, 0)
          button:SetPoint("BOTTOMRIGHT", ddFrame.backdrop, "BOTTOMRIGHT", 0, 0)
          button:SetWidth(22)

          CreateBackdrop(button, nil, nil, .85)
          button.backdrop:ClearAllPoints()
          button.backdrop:SetWidth(18)
          button.backdrop:SetHeight(18)
          button.backdrop:SetPoint("RIGHT", ddFrame.backdrop, "RIGHT", -2, 0)

          if not button.icon then
            button.icon = button:CreateTexture(nil, "OVERLAY")
            button.icon:SetTexture(pfUI.media["img:down"])
            button.icon:SetVertexColor(1, .9, .1)
            button.icon:SetAlpha(.8)
            SetAllPointsOffset(button.icon, button.backdrop, 5)
          end

          local _, class = UnitClass("player")
          local classColor = RAID_CLASS_COLORS[class]
          SetHighlight(button, classColor.r, classColor.g, classColor.b)

          -- same early-level issue as ddFrame above: raising ddFrame's
          -- level just now doesn't retroactively move button (it already
          -- existed as ddFrame's child), and button's own CreateBackdrop
          -- call is subject to the same degenerate math. Pin all of it
          -- explicitly so the arrow icon always ends up on top.
          button.backdrop:SetFrameLevel(baseLevel + 1)
          button:SetFrameLevel(baseLevel + 3)
        end

        -- The popup list itself is a separate "Dropdown-Pullout" AceGUI
        -- widget that draws its own Blizzard dialog-box border via
        -- SetBackdrop rather than any template, so it needs its own pass.
        -- It's created as part of AceGUI:Create("Dropdown") above, so it
        -- already exists here.
        local pullout = object._widget.pullout
        if pullout then
          local pframe = pullout.frame
          pframe:SetBackdrop(nil)
          CreateBackdrop(pframe, nil, nil, .95)

          -- GameTooltip renders at Blizzard's topmost "TOOLTIP" strata,
          -- above this popup's "FULLSCREEN_DIALOG" strata, so a tooltip
          -- left over from hovering a crafts-list entry underneath paints
          -- straight over the open list. Close it whenever the popup shows.
          HookScript(pframe, "OnShow", function() GameTooltip:Hide() end)

          -- the pullout's own scroll slider is a bare Slider (thumb only,
          -- no template), so the normal slider skin applies directly
          if pullout.slider then
            SkinSlider(pullout.slider)
          end
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
