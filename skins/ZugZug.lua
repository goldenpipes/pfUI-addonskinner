--[[
  pfUI Addon Skinner - ZugZug
  Reskins the ZugZug guild addon (main window, tabs, cards, buttons,
  checkboxes, edit boxes and minimap button) to match pfUI's flat,
  pixel-bordered look.

  ZugZug builds almost its entire UI by hand (see ZugUI.lua):
    - "real" widgets only ever use two Blizzard templates:
        UIPanelButtonTemplate  (normal buttons)
        UICheckButtonTemplate  (checkboxes)
    - everything else (the main window, tabs, cards, boxes, picker
      buttons) is a plain Frame/Button with a hand-rolled
      Tooltip-Background/Tooltip-Border SetBackdrop(), which the addon
      itself keeps recoloring at runtime for hover/selected states
      (tab:SetBackdropBorderColor(...), etc).

  Because almost every helper in ZugUI.lua is a `local function`, none
  of them can be hooked directly from here. Instead this skin walks the
  live frame tree under ZugZug.UI.frame and reskins anything it finds
  by shape:
    - CheckButton                       -> SkinCheckbox
    - Button with a custom SetBackdrop  -> CreateBackdrop (legacy mode)
    - Button with a template texture    -> SkinButton
    - Frame with a custom SetBackdrop   -> CreateBackdrop (legacy mode)

  "legacy mode" CreateBackdrop (pfUI.api.CreateBackdrop(f, nil, true))
  reskins the textures in place on the frame's own SetBackdrop rather
  than moving to a child .backdrop frame, which is important here:
  ZugZug's hover/selected logic keeps calling
  frame:SetBackdropColor()/SetBackdropBorderColor() directly on these
  frames, and legacy mode keeps that working correctly afterwards.

  Because the UI is heavily dynamic (LFG cards, guild roster rows and
  the Discord-relay chat panel are all rebuilt/pooled at runtime), a
  single pass at load isn't enough. The skin re-sweeps the frame tree
  whenever ZugZug rebuilds or refreshes a tab, using a per-frame flag
  so already-skinned frames are skipped almost instantly on repeat
  passes.
]]

pfUI.addonskinner:RegisterSkin("ZugZug", function()

  local CreateBackdrop = pfUI.api.CreateBackdrop
  local SkinButton      = pfUI.api.SkinButton
  local SkinCloseButton = pfUI.api.SkinCloseButton
  local SkinCheckbox    = pfUI.api.SkinCheckbox
  local HandleIcon       = pfUI.api.HandleIcon

  -- tracks frames we've already reskinned so repeat sweeps are cheap
  local skinned = {}
  local reportedErrors = {}

  local function ReportError(err)
    if reportedErrors[err] then return end
    reportedErrors[err] = true
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555pfUI-addonskinner (ZugZug):|r " .. tostring(err))
  end

  -- classifies and reskins a single frame
  local function SkinOneFrame(frame)
    local objType = frame.GetObjectType and frame:GetObjectType()

    if objType == "CheckButton" then
      SkinCheckbox(frame)
    elseif objType == "Button" and frame.GetBackdrop and frame:GetBackdrop() then
      -- hand-rolled tabs / picker buttons (dynamic hover/select colors)
      CreateBackdrop(frame, nil, true)
    elseif objType == "Button" and frame.GetNormalTexture and frame:GetNormalTexture() then
      -- real UIPanelButtonTemplate buttons
      SkinButton(frame)
    elseif frame.GetBackdrop and frame:GetBackdrop() then
      -- main window / cards / boxes
      CreateBackdrop(frame, nil, true)
    end
  end

  local function SkinFrameTree(frame)
    if not frame or skinned[frame] then return end
    skinned[frame] = true

    -- pcall this: WoW hides Lua errors from players by default, so one
    -- unusual widget throwing here would otherwise silently abort the
    -- whole walk -- leaving every sibling processed after it (i.e.
    -- every OTHER tab besides the first one touched) unskinned, with
    -- no visible error at all. This is exactly what caused Roster/LFG/
    -- Settings/AH Search to stay unskinned while only Dashboard (the
    -- first tab walked) came out fine.
    local ok, err = pcall(SkinOneFrame, frame)
    if not ok then ReportError(err) end

    if frame.GetChildren then
      local children = { frame:GetChildren() }
      local i = 1
      while children[i] do
        local ok2, err2 = pcall(SkinFrameTree, children[i])
        if not ok2 then ReportError(err2) end
        i = i + 1
      end
    end
  end

  local function SkinMainWindow()
    if not ZugZug or not ZugZug.UI or not ZugZug.UI.frame then return end
    local frame = ZugZug.UI.frame

    -- skin the close button explicitly first (dedicated pfUI close
    -- icon/position) and flag it done so the generic sweep below,
    -- which would otherwise treat it as a plain template button,
    -- leaves it alone
    if frame.close and not skinned[frame.close] then
      SkinCloseButton(frame.close, frame, -6, -6)
      skinned[frame.close] = true
    end

    SkinFrameTree(frame)
  end

  local function SkinMinimapButton()
    local btn = _G["ZugZugMinimapButton"]
    if not btn or skinned[btn] then return end
    skinned[btn] = true

    if btn.border then btn.border:Hide() end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    CreateBackdrop(btn, nil, true)

    if btn.icon then HandleIcon(btn, btn.icon) end
  end

  local function FullSkinPass()
    SkinMainWindow()
    SkinMinimapButton()
  end

  -- pfUI's hooksecurefunc polyfill does not pcall the hook function
  -- itself (only the original it wraps), so an error here would
  -- otherwise propagate straight back into whatever ZugZug code called
  -- the hooked function -- including a tab button's own OnClick
  -- handler. Route every hook through this safe wrapper instead of
  -- calling FullSkinPass/SkinMinimapButton directly.
  local function Safe(func)
    return function(...)
      local ok, err = pcall(func)
      if not ok then ReportError(err) end
    end
  end

  local SafeFullSkinPass = Safe(FullSkinPass)
  local SafeSkinMinimapButton = Safe(SkinMinimapButton)

  -- initial pass once ZugZug has actually built its UI
  pfUI.api.HookAddonOrVariable("ZugZug", SafeFullSkinPass)

  -- re-sweep whenever ZugZug (re)builds its default tabs, shows the
  -- window, switches/rebuilds a tab, or refreshes tab content -- this
  -- is where new cards/rows/panels get created at runtime
  hooksecurefunc("ZugZug_UI_RegisterDefaultTabs", SafeFullSkinPass)
  hooksecurefunc("ZugZug_UI_Show", SafeFullSkinPass)
  hooksecurefunc("ZugZug_UI_ShowTab", SafeFullSkinPass)
  hooksecurefunc("ZugZug_UI_UpdateTab", SafeFullSkinPass)
  hooksecurefunc("ZugZug_UI_CreateMinimapButton", SafeSkinMinimapButton)

  -- "AH Search" (and "Officer") aren't in the default tab set -- they
  -- get registered later, on demand, once a permission/feature check
  -- resolves over addon comms (ZugZug_UI_SetAuctionTabEnabled /
  -- SetOfficerTabEnabled are driven off a CHAT_MSG_ADDON handler, so
  -- this can fire well after the window's initial build/show/update
  -- hooks above have already run). Both of those funnel through
  -- ZugZug_UI_RegisterTab, so hook that directly to catch a newly
  -- registered tab the instant it's created.
  hooksecurefunc("ZugZug_UI_RegisterTab", SafeFullSkinPass)

  -- remove from pending list, actual skinning happens via the hooks above
  pfUI.addonskinner:UnregisterSkin("ZugZug")
end)
