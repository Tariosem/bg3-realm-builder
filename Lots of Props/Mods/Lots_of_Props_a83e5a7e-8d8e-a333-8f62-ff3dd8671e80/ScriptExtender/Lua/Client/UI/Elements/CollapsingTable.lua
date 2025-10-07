--- @class CollapsingTableStyle
--- @field Collapsed boolean
--- @field Table ExtuiTable
--- @field MainArea ExtuiTableCell
--- @field SideBar ExtuiTableCell
--- @field TitleCell ExtuiTableCell
--- @field ToggleButton ExtuiButton
--- @field CollapseTime number
--- @field CollapseType AnimationEasing
--- @field ExpandTime number
--- @field ExpandType AnimationEasing
--- @field SideBarWidth number
--- @field MainAreaWidth number
--- @field AnimationFPS number
--- @field CollapseDirection '"Left"' | '"Right"'
--- @field HoverToExpand boolean
--- @field AutoCollapse number
--- @field Collapse function
--- @field Expand function
--- @field SetSideBarWidth function
--- @field StopAnimation function
--- @field DisableOuterCollapse boolean
--- @field OnExpand fun()|nil
--- @field OnCollapse fun()|nil
--- @field OnWidthChange fun()|nil On sidebar width change

--- @param parent ExtuiTreeParent
--- @param table ExtuiTable
--- @return ExtuiPopup
function RenderCollapseingTableConfig(parent, table)
    local panel = parent:AddPopup("Config")
    panel.IDContext = table.IDContext .. "_ConfigPopup"

    local ud = table.UserData

    local collapseTimeSlider = panel:AddSlider(GetLoca("Collapse Time (s)"), (ud.CollapseTime or 600) / 1000, 0.1, 5)
    local expandTimeSlider = panel:AddSlider(GetLoca("Expand Time (s)"), (ud.ExpandTime or 400) / 1000, 0.1, 5)
    local sidebarWidthSlider = SafeAddSliderInt(panel, GetLoca("Sidebar Width"),
        ud.SideBarWidth or math.floor(200 * SCALE_FACTOR), 100, 800)
    local animationFPSSlider = SafeAddSliderInt(panel, GetLoca("Animation FPS"), ud.AnimationFPS or 90, 10, 144)
    local hoverToExpandCheckbox = panel:AddCheckbox(GetLoca("Hover to Expand"))
    local disableOuterCollapseCheckbox = panel:AddCheckbox(GetLoca("Disable Outer Collapse"))
    local autoCollapseSlider = SafeAddSliderInt(panel, GetLoca("Auto Collapse (s, 0 to disable)"),
        (ud.AutoCollapse or 0) / 1000, 0, 60)
    local collapseTypeCombo = panel:AddCombo("Collapse Easing Type")
    local expandTypeCombo = panel:AddCombo("Expand Easing Type")

    collapseTypeCombo.Options = GetAllEasings()
    expandTypeCombo.Options = GetAllEasings()

    SetCombo(collapseTypeCombo, ud.CollapseType or "EaseInCubic")
    SetCombo(expandTypeCombo, ud.ExpandType or "EaseOutCubic")

    collapseTimeSlider.OnChange = function()
        local newValue = FormatDecimal(collapseTimeSlider.Value[1], 1)
        ud.CollapseTime = newValue * 1000
        collapseTimeSlider.Value = ToVec4(newValue)
    end

    expandTimeSlider.OnChange = function()
        local newValue = FormatDecimal(expandTimeSlider.Value[1], 1)
        ud.ExpandTime = newValue * 1000
        expandTimeSlider.Value = ToVec4(newValue)
    end

    sidebarWidthSlider.OnChange = function()
        ud.SideBarWidth = sidebarWidthSlider.Value[1]
        ud.SetSideBarWidth(ud.SideBarWidth)
    end

    --mainAreaWidthSlider.OnChange = function()
    --    ud.MainAreaWidth = mainAreaWidthSlider.Value[1]
    --end

    animationFPSSlider.OnChange = function()
        ud.AnimationFPS = animationFPSSlider.Value[1]
    end

    hoverToExpandCheckbox.Checked = ud.HoverToExpand
    hoverToExpandCheckbox.OnChange = function()
        ud.HoverToExpand = hoverToExpandCheckbox.Checked
    end

    disableOuterCollapseCheckbox.SameLine = true
    disableOuterCollapseCheckbox.Checked = ud.DisableOuterCollapse
    disableOuterCollapseCheckbox.OnChange = function()
        ud.DisableOuterCollapse = disableOuterCollapseCheckbox.Checked
    end

    autoCollapseSlider.OnChange = function()
        local val = autoCollapseSlider.Value[1]
        if val <= 0 then
            ud.AutoCollapse = nil
        else
            ud.AutoCollapse = val * 1000
        end
    end

    collapseTypeCombo.OnChange = function()
        local val = GetCombo(collapseTypeCombo)
        if val and val ~= "" then
            ud.CollapseType = val
        end
    end

    expandTypeCombo.OnChange = function()
        local val = GetCombo(expandTypeCombo)
        if val and val ~= "" then
            ud.ExpandType = val
        end
    end

    return panel
end

--- @param parent ExtuiTreeParent
--- @param mainAreaTitle string?
--- @param sideBarTitle string?
--- @param opts CollapsingTableStyle?
--- @return CollapsingTableStyle
function AddCollapsingTable(parent, mainAreaTitle, sideBarTitle, opts)
    local IDContext = Uuid_v4()
    local table = parent:AddTable(IDContext .. "_Table", 2)
    local row = table:AddRow()
    local tableCells = { row:AddCell(), row:AddCell() }

    opts = opts or {}
    table.Borders = false

    local collapseDirection = opts.CollapseDirection or "Left"
    local collapseStatus = opts.Collapsed or false --- @type boolean true when table is collapsed

    if collapseDirection ~= "Left" and collapseDirection ~= "Right" then
        collapseDirection = "Left"
    end
    local sideBarIndex = collapseDirection == "Right" and 2 or 1
    local mainAreaIndex = collapseDirection == "Right" and 1 or 2

    --- @type CollapsingTableStyle
    table.UserData = {
        Table = table,                                              --- @type ExtuiTable
        MainArea = tableCells[mainAreaIndex],                       --- @type ExtuiTableCell
        SideBar = tableCells[sideBarIndex],                         --- @type ExtuiTableCell

        CollapseTime = opts.CollapseTime or 600,                    --- @type number
        CollapseType = opts.CollapseType or "EaseInBack",           --- @type AnimationEasing
        ExpandTime = opts.ExpandTime or 400,                        --- @type number
        ExpandType = opts.ExpandType or "EaseOutBack",              --- @type AnimationEasing
        SideBarWidth = opts.SideBarWidth or (200 * SCALE_FACTOR),   --- @type number
        MainAreaWidth = opts.MainAreaWidth or (400 * SCALE_FACTOR), --- @type number

        AnimationFPS = opts.AnimationFPS or 90,                     --- @type number

        CollapseDirection = collapseDirection,                      --- @type "Left" | "Right"
        HoverToExpand = opts.HoverToExpand ~= false,                --- @type boolean
        AutoCollapse = opts.AutoCollapse or 0,                      --- @type number
        DisableOuterCollapse = opts.DisableOuterCollapse or false,  --- @type boolean

        OnExpand = opts.OnExpand,                                   --- @type fun()|nil
        OnCollapse = opts.OnCollapse,                               --- @type fun()|nil
        OnWidthChange = opts.OnWidthChange,                         --- @type fun()|nil
    }

    --- @type CollapsingTableStyle
    local ud = table.UserData
    local sideBar = ud.SideBar
    local mainArea = ud.MainArea

    local function GetCollapseButtonLabel(collapsed, direction)
        if direction == "Right" then
            return collapsed and "<<" or ">>"
        else
            return collapsed and ">>" or "<<"
        end
    end

    local collapseButtonTable = ud.MainArea:AddTable(IDContext .. "_CollapseButtonTable", 2)
    collapseButtonTable.Borders = false
    local collapseButtonRow = collapseButtonTable:AddRow()
    local buttonCells = { collapseButtonRow:AddCell(), collapseButtonRow:AddCell() }

    local buttonCell = buttonCells[sideBarIndex]
    local titleCell = buttonCells[mainAreaIndex]

    ud.TitleCell = titleCell

    table.ColumnDefs[1] = {}
    table.ColumnDefs[sideBarIndex] = { Width = ud.SideBarWidth }
    table.ColumnDefs[mainAreaIndex] = { Width = ud.MainAreaWidth, WidthStretch = true }

    collapseButtonTable.ColumnDefs[1] = {}
    collapseButtonTable.ColumnDefs[sideBarIndex] = { Width = 40 * SCALE_FACTOR, WidthFixed = true }
    collapseButtonTable.ColumnDefs[mainAreaIndex] = { WidthStretch = true }

    local collapseButton = buttonCell:AddButton(GetCollapseButtonLabel(opts.Collapsed, collapseDirection))
    collapseButton.IDContext = IDContext .. "_CollapseButton"

    ud.ToggleButton = collapseButton

    if mainAreaTitle then
        local mainAreaTitleText = titleCell:AddSeparatorText(mainAreaTitle)
        mainAreaTitleText:SetStyle("SeparatorTextAlign", opts.MainAreaTitleAlign or 0.5)
    end

    if sideBarTitle then
        local sideBarTitleText = sideBar:AddSeparatorText(sideBarTitle)
        sideBarTitleText:SetStyle("SeparatorTextAlign", opts.SideBarTitleAlign or 0.5)
    end

    local autoCollapseTimer = nil
    --- @type RunningAnimation?
    local runningAnimation = nil
    local toggleTable
    toggleTable = function()
        if runningAnimation then
            runningAnimation:Stop()
        end
        local ud = table.UserData
        ud.CollapseDirection = collapseDirection
        collapseStatus = not collapseStatus
        collapseButton.Label = GetCollapseButtonLabel(collapseStatus, ud.CollapseDirection)

        local columnIndex = sideBarIndex
        local startWidth = table.ColumnDefs[columnIndex].Width
        local fps = ud.AnimationFPS or 90
        local fromAlpha = sideBar:GetStyle("Alpha") or collapseStatus and 0 or 1
        local toAlpha = collapseStatus and 0 or 1

        local function onDone()
            --collapseButton.Disabled = false
            if collapseStatus and ud.OnCollapse then
                ud.OnCollapse()
            elseif not collapseStatus and ud.OnExpand then
                ud.OnExpand()
            end
        end

        local function onUpdate(newWidth, progress)
            table.ColumnDefs[columnIndex].Width = newWidth
            local newAlpha = fromAlpha + (toAlpha - fromAlpha) * progress
            sideBar:SetStyle("Alpha", newAlpha)
            if ud.OnWidthChange then
                ud.OnWidthChange(newWidth)
            end
        end

        local targetWidth, duration, easingType
        if collapseStatus then
            targetWidth = 0
            duration = ud.CollapseTime or 1000
            easingType = ud.CollapseType or "EaseInBack"
        else
            targetWidth = ud.SideBarWidth or (200 * SCALE_FACTOR)
            duration = ud.ExpandTime or 1000
            easingType = ud.ExpandType or "EaseOutBack"
        end

        runningAnimation = AnimateValue(
            fps,
            startWidth,
            targetWidth,
            duration,
            easingType,
            onDone,
            onUpdate
        )

        if not collapseStatus and ud.AutoCollapse and ud.AutoCollapse ~= 0 then
            if autoCollapseTimer then
                Timer:Cancel(autoCollapseTimer)
                autoCollapseTimer = nil
            end

            autoCollapseTimer = Timer:After(ud.AutoCollapse, function()
                if not collapseStatus then
                    toggleTable()
                end
            end)
        end
    end

    local function setSideBarWidth(newWidth)
        if runningAnimation then
            runningAnimation:Stop()
        end
        if autoCollapseTimer then
            Timer:Cancel(autoCollapseTimer)
            autoCollapseTimer = nil
        end

        local ud = table.UserData
        local fps = ud.AnimationFPS or 90
        local duration = ud.ExpandTime or 400
        local easingType = ud.ExpandType or "EaseOutQuad"

        collapseStatus = false
        ud.Collapsed = false
        collapseButton.Label = GetCollapseButtonLabel(false, collapseDirection)
        --collapseButton.Disabled = true

        local startWidth = table.ColumnDefs[sideBarIndex].Width
        local targetWidth = newWidth or (ud.SideBarWidth or (200 * SCALE_FACTOR))
        local fromAlpha = sideBar:GetStyle("Alpha") or 0
        local toAlpha = 1

        runningAnimation = AnimateValue(
            fps,
            startWidth,
            targetWidth,
            duration,
            easingType,
            function()
                --[[collapseButton.Disabled = false;]] ud.SideBarWidth = newWidth
            end,
            function(newWidth, progress) 
                table.ColumnDefs[sideBarIndex].Width = newWidth --[[@as number]]
                local newAlpha = fromAlpha + (toAlpha - fromAlpha) * progress
                sideBar:SetStyle("Alpha", newAlpha)
                if ud.OnWidthChange then
                    ud.OnWidthChange(newWidth)
                end
                ud.SideBarWidth = newWidth
            end
        )
    end
    ud.SetSideBarWidth = setSideBarWidth

    local function StopAnimation()
        if runningAnimation then
            runningAnimation:Stop()
            runningAnimation = nil
        end
    end

    ud.StopAnimation = StopAnimation


    local configPopup = RenderCollapseingTableConfig(buttonCell, table)

    collapseButton.OnClick = toggleTable
    collapseButton.OnRightClick = function()
        if configPopup then
            configPopup:Open()
        end
    end

    collapseButton.OnHoverEnter = function()
        local ud = table.UserData
        if collapseStatus and ud.HoverToExpand then
            toggleTable()
        end
    end

    sideBar.OnHoverEnter = function()
        if not runningAnimation and not collapseStatus then
            sideBar:SetStyle("Alpha", 1)
        end
    end

    sideBar.OnHoverLeave = function()
        sideBar:SetStyle("Alpha", collapseStatus and 0 or 0.8)
    end

    sideBar.OnClick = sideBar.OnHoverEnter

    table.UserData.Collapse = function()
        if not collapseStatus and not ud.DisableOuterCollapse then
            toggleTable()
        end
    end

    table.UserData.Expand = function()
        if collapseStatus then
            toggleTable()
        end
    end

    table.UserData.Destroy = function()
        if runningAnimation then
            runningAnimation:Stop()
            runningAnimation = nil
        end
        if autoCollapseTimer then
            Timer:Cancel(autoCollapseTimer)
            autoCollapseTimer = nil
        end
        if configPopup then
            configPopup:Destroy()
        end
        table:Destroy()
    end

    if collapseStatus then
        table.ColumnDefs[sideBarIndex].Width = 0
        sideBar:SetStyle("Alpha", 0)
    else
        sideBar:SetStyle("Alpha", 1)
    end

    table.UserData.__index = function(t, k)
        if k == "Collapsed" then
            return collapseStatus
        elseif rawget(t, k) ~= nil then
            return rawget(t, k)
        else
            Error("CollapsingTableStyle has no member named " .. tostring(k))
        end
    end

    table.UserData.__newindex = function(t, k, v)
        if k == "Collapsed" then
            if v ~= collapseStatus then
                toggleTable()
            end
        elseif k == "SideBarWidth" then
            setSideBarWidth(v)
        elseif rawget(t, k) ~= nil then
            rawset(t, k, v)
        else
            Error("CollapsingTableStyle has no member named " .. tostring(k))
        end
    end

    return table.UserData
end
