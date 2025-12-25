--- a custom tree UI element
--- right click to expand all

local treeOpenIcon = RB_ICONS.Menu_Down
local treeClosedIcon = RB_ICONS.Menu_Right
local treeOpen = RB_ICON_UV01[treeOpenIcon]
local treeClosed = RB_ICON_UV01[treeClosedIcon]

--- @class RB_UI_Tree : ExtuiTree
--- @field Children RB_UI_Tree[]
--- @field SetOpen fun(self: RB_UI_Tree, isOpen: boolean)
--- @field IsOpen fun(self: RB_UI_Tree): boolean
--- @field AddTree fun(self: RB_UI_Tree, label: string, isOpen: boolean?): RB_UI_Tree
--- @field AddHint fun(self: RB_UI_Tree, hintText: string): ExtuiText
--- @field AddTreeIcon fun(self: RB_UI_Tree, iconPath: string, iconSize?: Vec2): ExtuiImage
--- @field AddChild fun(self: RB_UI_Tree, child: RB_UI_Tree) -- add a logical child tree, does not add to UI
--- @field Destroy fun()
--- @field DestroyChildren fun()
--- @field ToggleAll fun(self: RB_UI_Tree)
--- @field Panel ExtuiGroup
--- @field Indent number
--- @field Framed boolean
--- @field HideHeader boolean
--- @field DontClosePopups boolean
--- @field OnExpand fun(self:RB_UI_Tree)
--- @field OnCollapse fun(self:RB_UI_Tree)

local selectableProps = {
    Selected = true,
    Highlight = true,
    DontClosePopups = true,
}

--- @param parent ExtuiTreeParent
--- @param label string
--- @param open boolean?
--- @return RB_UI_Tree
function ImguiElements.AddTree(parent, label, open)
    if parent.UserData and parent.UserData.Is_RB_UI_Tree then
        return parent:AddTree(label, open) --[[@as RB_UI_Tree]]
    end
    label = label or "TreeGroup"
    local uuid = RBUtils.Uuid_v4()
    local panelGroup = parent:AddGroup(label .. "##uuid_" .. uuid)

    local children = {}
    local headerGroup = panelGroup:AddGroup(label .. "_TreeHeaderGroup##uuid_" .. uuid)
    local arrowReserved = headerGroup:AddImageButton("##" .. label .. uuid,
        open and RB_ICONS.Menu_Down or RB_ICONS.Menu_Right, IMAGESIZE.ROW)
    local iconReserved = headerGroup:AddGroup("##" .. label .. "_IconReserved_" .. uuid)
    local selectable = headerGroup:AddSelectable(label .. "##" .. uuid .. "_Selectable")
    local indent = panelGroup:AddDummy(16 * SCALE_FACTOR, 1)
    local panel = panelGroup:AddGroup(label .. "_TreeGroup##uuid_" .. uuid)
    local isFramed = false
    local treeIcon = nil
    panel.Visible = open == true
    panel.SameLine = true
    selectable.SameLine = true
    selectable.AllowItemOverlap = true
    selectable.DontClosePopups = true
    selectable.IDContext = "TreeSelectable__" .. uuid
    iconReserved.SameLine = true
    iconReserved.Visible = false

    local closure = {}
    local expandAll = not panel.Visible
    local function setOpen(isOpen)
        panel.Visible = isOpen
        arrowReserved.Image = panel.Visible and treeOpen or treeClosed
        if closure.OnExpand and isOpen then
            closure:OnExpand()
        elseif closure.OnCollapse and not isOpen then
            closure:OnCollapse()
        end
    end

    ImguiHelpers.SetupImageButton(arrowReserved)
    arrowReserved.OnClick = function()
        if isFramed then
            selectable.Selected = true
        else
            selectable.Selected = false
        end
        setOpen(not panel.Visible)
    end

    local toggleAll = function(sel, syncState)
        syncState = syncState or { ExpandState = expandAll, Seen = {} }
        if syncState ~= nil then
            expandAll = syncState.ExpandState
        end
        for _, child in ipairs(children) do
            if syncState.Seen[child] then
                goto continue
            end
            if child.SetOpen then
                syncState.Seen[child] = true
                child:SetOpen(expandAll)
                child:ToggleAll(syncState)
            end
            ::continue::
        end
        expandAll = not expandAll
    end

    arrowReserved.OnRightClick = function()
        toggleAll()
    end
    selectable.OnRightClick = arrowReserved.OnRightClick
    selectable.OnClick = arrowReserved.OnClick

    closure = {
        __UserData = {
            Is_RB_UI_Tree = true
        },
        ToggleAll = toggleAll,
        Panel = panel,
        Children = children,
        SetOpen = function(_, isOpen)
            setOpen(isOpen)
        end,
        IsOpen = function()
            return panel.Visible
        end,
        AddTree = function(_, label, isOpen)
            local childTree = ImguiElements.AddTree(panel, label, isOpen)
            table.insert(children, childTree)
            return childTree
        end,
        AddChild = function(_, child)
            if child and child.UserData and child.UserData.Is_RB_UI_Tree then
                table.insert(children, child)
            end
        end,
        AddTreeIcon = function(_, iconName, iconSize)
            treeIcon = iconReserved:AddImageButton("##" .. uuid .. "Tree___Icon", iconName, iconSize or IMAGESIZE.ROW)
            treeIcon.IDContext = "TreeIcon__" .. uuid
            StyleHelpers.ClearAllBorders(treeIcon)
            treeIcon:SetColor("Button", { 0, 0, 0, 0 })
            treeIcon:SetColor("ButtonHovered", { 0, 0, 0, 0 })
            treeIcon:SetColor("ButtonActive", { 0, 0, 0, 0 })
            iconReserved.Visible = true
            return treeIcon
        end,
        AddHint = function(_, hintText)
            local hint = headerGroup:AddText(hintText)
            hint:SetColor("Text", ColorUtils.HexToRGBA("FFAAAAAA"))
            hint.SameLine = true
            hint.Font = "Tiny"
            return hint
        end,
        OnExpand = function() end,
        OnCollapse = function() end,
        Destroy = function()
            panelGroup:Destroy()
        end,
        DestroyChildren = function()
            for i = #children, 1, -1 do
                local child = children[i]
                if child.Destroy then
                    child:Destroy()
                end
                table.remove(children, i)
            end
            ImguiHelpers.DestroyAllChildren(panel)
        end,
        GetStyle = function(_, varName)
            return panelGroup:GetStyle(varName)
        end,
        GetColor = function(_, colorName)
            return panelGroup:GetColor(colorName)
        end,
        SetStyle = function(_, varName, ...)
            panelGroup:SetStyle(varName, ...)
        end,
        SetColor = function(_, colorName, colorValue)
            panelGroup:SetColor(colorName, colorValue)
        end
    }

    selectable.UserData = closure.__UserData

    setmetatable(closure, {
        __index = function(_, k)
            if k == "UserData" then
                return rawget(closure, "__UserData")
            elseif rawget(closure, k) ~= nil then
                return rawget(closure, k)
            elseif k:sub(1, 3) == "Add" then
                return function(_, ...)
                    return panel[k](panel, ...)
                end
            elseif k == "Tooltip" then
                return function()
                    return selectable:Tooltip()
                end
            elseif k == "Indent" then
                return indent.Width
            elseif k == "HideHeader" then
                return not headerGroup.Visible
            end
            return selectable[k]
        end,
        __newindex = function(_, k, v)
            if k == "SameLine" or k == "Visible" then
                panelGroup[k] = v
                return
            elseif k == "UserData" then
                rawset(closure, "__UserData", v)
                selectable.UserData = v
                treeIcon.UserData = v
                v.Is_RB_UI_Tree = true
                return
            elseif k == "Framed" then
                isFramed = v
                selectable.Selected = v
                return
            elseif k == "Indent" then
                indent.Width = v
                return
            elseif k == "HideHeader" then
                headerGroup.Visible = not v
                return
            end
            selectable[k] = v
            if treeIcon and not selectableProps[k] then
                treeIcon[k] = v
            end
        end
    })

    return closure
end
