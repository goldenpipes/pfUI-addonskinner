pfUI.addonskinner:RegisterSkin("MissingCrafts", function()
  -- upvalue the pfUI methods we use to avoid repeated lookups
  local penv = pfUI:GetEnvironment()
  local StripTextures, CreateBackdrop, SkinCloseButton, SkinScrollbar,
    SetHighlight, SkinSlider, SkinDropDown =
  penv.StripTextures, penv.CreateBackdrop, penv.SkinCloseButton, penv.SkinScrollbar,
  penv.SetHighlight, penv.SkinSlider, penv.SkinDropDown

  -- HookScript is a plain global function (not part of pfUI.api / pfUI.env),
  -- and skin files run in the normal global environment (no setfenv), so we
  -- reference the real global directly here instead of via penv.
  local HookScript = HookScript

  -- Temporary diagnostic helper: prints any error a guarded block throws,
  -- since a plain pcall() swallows it with no trace at all, and errors
  -- thrown later from inside a deferred OnShow handler happen outside the
  -- pcall that set the handler up in the first place.
  local function report(ok, err)
    if not ok then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[MissingCrafts skin]|r " .. tostring(err))
    end
    return ok
  end

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
      report(pcall(function()
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
      end))
      return window
    end
  end

  -- Profession / character filter dropdowns
  local Dropdown = MissingCrafts and MissingCrafts.Dropdown
  if Dropdown then
    local origCreate = Dropdown.Create
    Dropdown.Create = function(self, ...)
      local object = origCreate(self, ...)
      report(pcall(function()
        -- AceGUI's Dropdown widget is a real UIDropDownMenuTemplate frame
        -- for its box artwork, BUT its actual popup list is a totally
        -- custom "Dropdown-Pullout" widget, not Blizzard's native
        -- DropDownList1/ToggleDropDownMenu system. pfUI's own SkinDropDown
        -- gives the exact look we want (it's what ATSW2 uses too), but at
        -- the end it unconditionally rewrites the button's OnClick to also
        -- resize/reposition DropDownList1 - Blizzard's single global shared
        -- dropdown list frame used by every native dropdown in the whole
        -- game - assuming it's a real Blizzard dropdown tied to that list.
        -- Ours never uses DropDownList1 at all, so that step just mutates
        -- an unrelated global frame on every click for no reason, which is
        -- a solid explanation for the memory crash. So: use SkinDropDown
        -- for the visuals, then restore AceGUI's own original click
        -- handler afterward so DropDownList1 is never touched.
        --
        -- ATSW2's dropdowns are static XML frames, but that distinction
        -- turned out not to matter here: AceGUI's own Dropdown widget
        -- already normalizes frame levels itself (it calls its internal
        -- fixlevels() on the pullout immediately in OnAcquire), so there's
        -- no need to defer anything - skin it the same way ATSW2 does,
        -- directly and immediately.
        local ddFrame = object._widget.dropdown
        local button = object._widget.button
        local originalOnClick = button and button:GetScript("OnClick")

        StripTextures(ddFrame)
        SkinDropDown(ddFrame, nil, nil, nil, true)

        if button and originalOnClick then
          button:SetScript("OnClick", originalOnClick)
        end

        -- SkinDropDown stretches the clickable button (and with it, its
        -- highlight texture) across the whole box via SetAllPoints, and
        -- highlight is Blizzard's topmost render layer - so hovering
        -- anywhere on the row, not just the arrow, paints right over the
        -- label text. Shrink the hit/highlight zone back down to just the
        -- arrow on the right, like a normal dropdown.
        if button then
          button:ClearAllPoints()
          button:SetPoint("TOPRIGHT", ddFrame.backdrop, "TOPRIGHT", 0, 0)
          button:SetPoint("BOTTOMRIGHT", ddFrame.backdrop, "BOTTOMRIGHT", 0, 0)
          button:SetWidth(22)
        end

        -- The popup list itself is a separate "Dropdown-Pullout" AceGUI
        -- widget that draws its own Blizzard dialog-box border via
        -- SetBackdrop rather than any template, so it needs its own pass.
        -- It's created as part of AceGUI:Create("Dropdown") above, so it
        -- already exists here. Same deferred-to-OnShow reasoning as above.
        local pullout = object._widget.pullout
        if pullout then
          local pframe = pullout.frame

          HookScript(pframe, "OnShow", function()
            -- GameTooltip renders at Blizzard's topmost "TOOLTIP" strata,
            -- above this popup's "FULLSCREEN_DIALOG" strata, so a tooltip
            -- left over from hovering a crafts-list entry underneath
            -- paints straight over the open list. Close it every time.
            GameTooltip:Hide()

            if pframe._pfSkinned then return end

            report(pcall(function()
              pframe:SetBackdrop(nil)
              CreateBackdrop(pframe, nil, nil, .95)

              -- the pullout's own scroll slider is a bare Slider (thumb
              -- only, no template), so the normal slider skin applies
              -- directly
              if pullout.slider then
                SkinSlider(pullout.slider)
              end
            end))

            pframe._pfSkinned = true
          end)
        end
      end))
      return object
    end
  end

  -- Search box
  local SearchField = MissingCrafts and MissingCrafts.SearchField
  if SearchField then
    local origCreate = SearchField.Create
    SearchField.Create = function(self, ...)
      local object = origCreate(self, ...)
      report(pcall(function()
        local editbox = object._widget.editbox
        StripTextures(editbox, true, "BACKGROUND")
        CreateBackdrop(editbox, nil, true)
      end))
      return object
    end
  end

  -- Scrolling crafts list
  local CraftsList = MissingCrafts and MissingCrafts.CraftsList
  if CraftsList then
    local origCreate = CraftsList.Create
    CraftsList.Create = function(self, ...)
      local object = origCreate(self, ...)
      report(pcall(function()
        local scrollWidget = object._scrollFrame
        StripTextures(scrollWidget.scrollframe)
        SkinScrollbar(scrollWidget.scrollbar)
      end))
      return object
    end
  end

  -- Individual crafts list rows (plain, unnamed buttons pulled from a pool)
  local CraftsListItem = MissingCrafts and MissingCrafts.CraftsListItem
  if CraftsListItem then
    local origCreate = CraftsListItem.Create
    CraftsListItem.Create = function(self, ...)
      local item = origCreate(self, ...)
      report(pcall(function()
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
      end))
      return item
    end
  end

  -- Small toggle button MissingCrafts pins to the corner of tradeskill windows
  local OpenButton = MissingCrafts and MissingCrafts.OpenButton
  if OpenButton then
    local origCreate = OpenButton.Create
    OpenButton.Create = function(self, ...)
      local object = origCreate(self, ...)
      report(pcall(function()
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
      end))
      return object
    end
  end

  -- remove from pending list when applied
  pfUI.addonskinner:UnregisterSkin("MissingCrafts")
end)
