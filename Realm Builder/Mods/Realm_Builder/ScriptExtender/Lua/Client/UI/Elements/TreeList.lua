--- @class TreeListSortCache
--- @field TypeOrder table<any, number>
--- @field Key table<any, string>

--- @class TreeList
--- @field parent ExtuiTreeParent
--- @field panel ExtuiTreeParent
--- @field SortCache TreeListSortCache
--- @field itemRefs table<any, ExtuiSelectable>
--- @field nodeRefs table<any, ExtuiTableCell>
--- @field arrowRefs table<any, ExtuiImageButton>
--- @field indexRefs table<any, number>
--- @field indexRefsReverse table<number, any>
--- @field rootTable ExtuiTable
--- @field tree TreeTable
--- @field isVisible boolean
--- @field label string
--- @field items any[]
--- @field keyField string
--- @field ExpandAll fun(self:TreeList, key:any)
--- @field CollapseAll fun(self:TreeList, key:any)
--- @field RenderLeaf fun(self:TreeList, key:any, node:ExtuiTableCell, fixedCell:ExtuiTableCell):ExtuiSelectable
--- @field RenderTree fun(self:TreeList, key:any, node:ExtuiTableCell, fixedCell:ExtuiTableCell):ExtuiSelectable
--- @field SetUpLeaf fun(self:TreeList, selectable:ExtuiSelectable, key:any, item:any)
--- @field SetUpTree fun(self:TreeList, tree:ExtuiSelectable, key:any, item:any)
--- @field FilterFunc fun(self:TreeList, key:any, keyword:string):boolean
--- @field ClearSelection fun(self:TreeList)
--- @field ClearList fun(self:TreeList)
--- @field SelectLogic fun(self:TreeList, key:any, parent:any)
--- @field SetupArrow fun(self:TreeList, arrow:ExtuiImageButton, key:any)
--- @field GetLowestSelected fun(self:TreeList):any[]
--- @field OnSelect fun(self:TreeList)
--- @field OnDragStart fun(self:TreeList, dragKey:any)
--- @field OnDragDrop fun(self:TreeList, from:any, to:any)
--- @field OnDragEnd fun(self:TreeList, dragKey:any)
--- @field OnAttach fun(self:TreeList)
--- @field OnDetach fun(self:TreeList)
--- @field MultiSelect boolean
--- @field GroupSelect boolean
--- @field new fun(parent:ExtuiTreeParent, label:string, tree:TreeTable, opts:table?):TreeList
TreeList = _Class("TreeList")

local emptyFunc = function() end

function TreeList:__init(parent, label, tree)
    self.parent = parent --[[@as ExtuiTreeParent]]

    self.panel = nil
    self.isVisible = false
    self.isValid = true
    self.label = label

    self.tree = tree

    self.recordedSelectedItems = {}

    self.itemRefs = {} -- save tree selectables
    self.itemRefs = {} -- save leaf selectables for items
    self.nodeRefs = {} -- save all cells for nodes, userdata is the indent container
    self.collapsedTree = {}

    self:SetupKeyListeners()

    self:SetupArrowFns()
    self:SetupDragDropFns()
    self:SetupSelectableFns()
end

function TreeList:SetupKeyListeners()
    local stateToMap = {
        GroupSelect = "Shift",
        MultiSelect = "Ctrl"
    }
    self.InputStates = {}
    local o = InputEvents.GetGlobalInputStatesRef()
    setmetatable(self.InputStates, {
        __index = function(_, key)
            return o[stateToMap[key]]
        end
    })
end

function TreeList:Render()
    self.panel = self.parent --[[@as ExtuiTreeParent]]
    self:OnAttach()

    self:RenderTopBar()

    self.listWindow = self.panel:AddChildWindow("##" .. self.label .. "ListWindow")
    Ext.OnNextTick(function()
        self.listWindow.Size = { -20, 800 * SCALE_FACTOR }
    end)
    self.listWindow.NoResize = false

    local _, screenHeight = UIHelpers.GetScreenSize()
    local sliderHeight = ImguiHelpers.SafeAddSliderInt(self.panel, "##windowHeight", 800 * SCALE_FACTOR, screenHeight, 200)
    sliderHeight:SetColor("Text", {0,0,0,0})
    sliderHeight.SameLine = true
    sliderHeight.Vertical = true
    sliderHeight.VerticalSize = {20, 800 * SCALE_FACTOR + 1}
    sliderHeight.Value = RBUtils.ToVec4Int(800 * SCALE_FACTOR)
    sliderHeight.OnChange = function(slider)
        local height = slider.Value[1]
        self.listWindow.Size = { -20, height + 1}
        sliderHeight.VerticalSize = {20, height + 1}
    end
    self:RenderList()
end

function TreeList:Collapsed()
    self.panel = nil

    if self.rootTable then
        self.rootTable:Destroy()
        self.rootTable = nil
    end
    if self.OtherPanel then
        self.OtherPanel:Destroy()
        self.OtherPanel = nil
    end
    if self.topBar then
        self.topBar:Destroy()
        self.topBar = nil
    end
    self.itemRefs = {}
    self.indexRefs = {}
    self.indexRefsReverse = {}
    self.itemRefs = {}
    self.nodeRefs = {}
end

function TreeList:Destroy()
    if not self.isValid then return end

    self:Collapsed()
    self.isValid = false
end

function TreeList:RenderTopBar()
    self.OtherPanel = self.panel:AddTree("Others")
    self:RenderCustomTopBar(self.OtherPanel)
    local rightA, leftA, topbar = ImguiElements.AddRightAlignCell(self.panel)

    self.topBar = topbar
    local searchInput = leftA:AddInputText("") --[[@as ExtuiInputText]]
    searchInput.IDContext = "TreeList" .. self.label .. "Search"

    searchInput.Hint = "Search..."
    searchInput.Text = self.SearchKeyword or ""
    searchInput.OnChange = RBUtils.Debounce(50, function()
        self.SearchKeyword = searchInput.Text
        self:Hide(searchInput.Text)
    end)

    --[[local settingPopup = rightA:AddPopup("##" .. self.label .. "SettingsPopupSettings")
    
    local openSettingsBtn = rightA:AddImageButton("##" .. self.label .. "SettingsBtn", RB_ICONS.Sliders, IMAGESIZE.ROW)
    openSettingsBtn.OnClick = function()
        settingPopup:Open()
    end
    StyleHelpers.ApplyBorderlessImageButtonStyle(openSettingsBtn)]]
    --local alignedTable = ImguiElements.AddAlignedTable(self.panel)
    

end

--- return true to show the item
function TreeList:FilterFunc(key, keyword)
    return true
end

function TreeList:Hide(keyword)
    for _,node in pairs(self.nodeRefs) do
        node.Visible = false
    end

    if keyword == nil or keyword == "" then
        self:IterativeShow(TreeTable.GetRootKey())
        return
    end

    local lowerKeyword = string.lower(keyword)
    for key, node in pairs(self.nodeRefs) do
        if self:FilterFunc(key, lowerKeyword) then
            node.Visible = true
            local path = self.tree:GetPath(key)
            for _,parentKey in pairs(path) do
                self.nodeRefs[parentKey].Visible = true
            end
        else
        end
    end
end

function TreeList:IterativeHide(key)
    local stack = {key}
    while #stack > 0 do
        local current = table.remove(stack)
        local node = self.tree:Find(current)
        if node and not self.tree:IsLeaf(current) then
            for childKey,_ in pairs(node) do
                if self.nodeRefs[childKey] then
                    self.nodeRefs[childKey].Visible = false
                end
                table.insert(stack, childKey)
            end
        end
    end
end

function TreeList:IterativeShow(key)
    local stack = {key}
    while #stack > 0 do
        local current = table.remove(stack)
        local node = self.tree:Find(current)
        if node then
            self.nodeRefs[current].Visible = true
            if not self.collapsedTree[current] and not self.tree:IsLeaf(current) then
                for childKey,_ in pairs(node) do
                    table.insert(stack, childKey)
                end
            end
        end
    end
end

---@param tbl ExtuiTable
function TreeList:ApplyTreeTableStyle(tbl)
    tbl.RowBg = true
end

--- Renders the tree list
--- @param onComplete fun()?
function TreeList:RenderList(onComplete)
    -- validate renderOrder
    
    if self.__killRenderThread then
        self.__killRenderThread()
        self.__killRenderThread = nil
    end

    self:RecordSelectedItems()

    --- @type ExtuiTable
    self.rootTable = self.rootTable or self.listWindow:AddTable(self.label .. "##Root", 1)
    self.rootTable.OptimizedDraw = true
    self.rootTable.UserData = self.rootTable.UserData or {}
    if self.rootTable.UserData.Row then
        self.rootTable.UserData.Row:Destroy()
        self.rootTable.UserData.Row = nil
    end
    local row = self.rootTable:AddRow()
    self.rootTable.UserData.Row = row
    self:ApplyTreeTableStyle(self.rootTable)

    self.arrowRefs = {}
    self.itemRefs = {}
    self.nodeRefs = {
        --- @diagnostic disable-next-line
        [TreeTable.GetRootKey()] = row
    }
    self.indexRefs = {}
    self.indexRefsReverse = {}
    local itemCnt = 1

    --- @param key any
    --- @return unknown
    local depthIndent = function(key)
        local depth = self.tree:GetDepth(key)
        return (depth - 1) * 64 * SCALE_FACTOR
    end

    local useThread = false
    local thread = nil
    local outerSuspended = false
    local yieldThreshold = 5 -- ms
    local lastYield = Ext.Timer.MonotonicTime()

    local sorted = self.tree:GetAllKeys()
    local keyToIndex = {}
    self.keyToIndex = keyToIndex
    self:UpdateSortCache()
 
    local typeCache = self.SortCache and self.SortCache.TypeOrder or {}
    local keyCache = self.SortCache and self.SortCache.Key or {}
    table.sort(sorted, function (a, b)
        if typeCache[a] ~= typeCache[b] then
            return (typeCache[a] or 0) < (typeCache[b] or 0)
        end

        local aKey = keyCache[a] or tostring(a)
        local bKey = keyCache[b] or tostring(b)

        return aKey < bKey
    end)

    for index,key in pairs(sorted) do
        keyToIndex[key] = index
    end

    local yieldCnt = 0
    local function yieldThread()
        if not useThread then return end

        if Ext.Timer.MonotonicTime() - lastYield < yieldThreshold then return end
        lastYield = Ext.Timer.MonotonicTime()
        Ext.OnNextTick(function()
            if not thread then return end
            if coroutine.status(thread) == "suspended" then
                local ok, err = coroutine.resume(thread)
                if not ok then
                    Error("Error resuming TreeList render coroutine: " .. tostring(err))
                    self.panel.Disabled = false
                end
            else
                Error("TreeList render coroutine is no longer suspended!")
                self.panel.Disabled = false
            end

            yieldCnt = yieldCnt + 1
             --Debug("Yielded TreeList render coroutine after processing batch, total yields: " .. tostring(yieldCnt))
        end)
        coroutine.yield()
    end

    local function collectChildren(key)
        local collector = {}
        local node = self.tree:Find(key)
        --local now = Ext.Timer.MonotonicTime()
        for childKey,_ in pairs(node) do
            table.insert(collector, childKey)
        end
        table.sort(collector, function(a,b)
            local aIndex = keyToIndex[a] or math.huge
            local bIndex = keyToIndex[b] or math.huge
            return aIndex < bIndex
        end)
        yieldThread()
        --Debug("Sorted " .. tostring(#collector) .. " children of " .. tostring(key) .. " in " .. tostring(Ext.Timer.MonotonicTime() - now) .. " ms")
        return collector
    end

    --local profileBefore = Ext.Timer.MicrosecTime()
    --local profileOutput = {}
    --local function sampleProfile(label)
    --    local now = Ext.Timer.MicrosecTime()
    --    profileOutput[#profileOutput+1] = { label = label, time = now - profileBefore }
    --    profileBefore = now
    --end
    local renderFunc = function()
        self.panel.Disabled = true
        self.hoveringKey = nil
        self.SortCache = self.SortCache or {}
        --Debug("Updated TreeList sort cache in " .. tostring(Ext.Timer.MonotonicTime() - now) .. " ms")
        yieldThread()
        local stack = {}
        local rootChildren = collectChildren(TreeTable.GetRootKey())
        for i = #rootChildren, 1, -1 do
            table.insert(stack, { key = rootChildren[i], depth = 1 })
        end

        if #stack == 0 then
            self.panel.Disabled = false
            self.rootTable.Visible = false
            return
        end
        self.rootTable.Visible = true
        while #stack > 0 do
            if outerSuspended then 
                self.panel.Disabled = false
                return
            end
            local item = table.remove(stack)
            local key, depth = item.key, item.depth
            local node = self.tree:Find(key)
            if node then
                local cell = row:AddCell()
                self:SetupHoveringDetection(cell, key)
                local indentDepth = depthIndent(key)
                local innerTab = cell:AddTable(self.label, 3)
                innerTab.OptimizedDraw = true
                innerTab.SameLine = true
                innerTab.PreciseWidths = true
                innerTab.ColumnDefs[1] = { WidthFixed = true, Width = indentDepth }
                innerTab.ColumnDefs[2] = { WidthStretch = true }
                innerTab.ColumnDefs[3] = { WidthFixed = true }
                local indentRow = innerTab:AddRow()
                indentRow:AddCell() -- indent cell
                local leftCell = indentRow:AddCell()
                local fixedCell = indentRow:AddCell()
                cell.UserData = {
                    SelectableCell = leftCell,
                    FixedCell = fixedCell
                }
                local ele
                if self.tree:IsLeaf(key) then
                    ele = self:RenderLeaf(key, leftCell, fixedCell)
                    cell.Visible = false
                else
                    local icon = self.collapsedTree[key] and RB_ICONS.Tree_Collapsed or RB_ICONS.Tree_Expanded
                    local arrowImage = leftCell:AddImageButton("##" .. key, icon, IMAGESIZE.ROW)
                    StyleHelpers.ApplyBorderlessImageButtonStyle(arrowImage)
                    ele = self:RenderTree(key, leftCell, fixedCell)
                    ele.SameLine = true
                    self.arrowRefs[key] = arrowImage
                    cell.Visible = false

                    local children = collectChildren(key)
                    for i = #children, 1, -1 do
                        table.insert(stack, { key = children[i], depth = depth + 1 })
                    end
                end

                ele.AllowItemOverlap = true
                self.itemRefs[key] = ele
                self.nodeRefs[key] = cell
                self.indexRefs[key] = itemCnt
                self.indexRefsReverse[itemCnt] = key
                itemCnt = itemCnt + 1
            end
            yieldThread()
        end
        --sampleProfile("Finished creating UI elements")

        for key,ele in pairs(self.itemRefs) do
            if outerSuspended then 
                self.panel.Disabled = false
                return
            end
            if ele.UserData and ele.UserData.IsLeaf then
                self:SetUpLeaf(ele, key)
            else
                self:SetUpTree(ele, key, self.tree:Find(key))
            end
            yieldThread()
        end
        --sampleProfile("Finished setting up selectables")

        for key,arrow in pairs(self.arrowRefs) do
            if outerSuspended then 
                self.panel.Disabled = false
                return
            end
            self:SetupArrow(arrow, key)
            yieldThread()
        end
        --sampleProfile("Finished setting up arrows")

        self:IterativeShow(TreeTable.GetRootKey())
        self:OnRenderComplete()
        if onComplete then
            onComplete()
        end
        self.__killRenderThread = nil
        self.panel.Disabled = false
        --_P("Finished in " .. tostring(Ext.Timer.MonotonicTime() - lastYield) .. " ms with " .. tostring(yieldCnt) .. " yields.")

        --for i, data in pairs(profileOutput) do
        --    _P(string.format("Profile %d: %s took %.2f ms", i, data.label, data.time))
        --end
    end

    if useThread then
        thread = coroutine.create(renderFunc)
        self.__killRenderThread = function()
            outerSuspended = true
        end
        
        local ok, err = coroutine.resume(thread)
        if not ok then
            Error("Error starting TreeList render coroutine: " .. tostring(err))
            self.panel.Disabled = false
        end
    else
        renderFunc()
    end
end

function TreeList:ClearList()
    --self:ClearSelection()
    self.itemRefs = {}
    self.indexRefs = {}
    self.indexRefsReverse = {}
    self.nodeRefs = {}
    if self.rootTable and self.rootTable.UserData and self.rootTable.UserData.Row then
        self.rootTable.UserData.Row:Destroy()
        self.rootTable.UserData.Row = nil
    end
end

---@param key any
---@param node ExtuiTableCell
---@return ExtuiSelectable return the selectable
function TreeList:RenderLeaf(key, node, fixedCell)
    local selectable = node:AddSelectable(key) --[[@as ExtuiSelectable]]
    return selectable
end

---@param key any
---@param node ExtuiTableCell
---@return ExtuiSelectable return the selectable
function TreeList:RenderTree(key, node, fixedCell)
    local tree = node:AddSelectable(key) --[[@as ExtuiSelectable]]
    return tree
end

---@param key any
function TreeList:ToggleSelected(key)
    local ref = self.itemRefs[key]
    if ref then
        ref.Selected = not ref.Selected
    end
end


function TreeList:SetSelected(key, selected)
    local ref = self.itemRefs[key]
    if ref then
        ref.Selected = selected
    end
end

function TreeList:ClearSelection(notCallback)
    for k, ele in pairs(self.itemRefs) do
        ele.Selected = false
        ele.Highlight = false
    end
    if not notCallback then
        self:OnSelect()
    end
end

function TreeList:GetLowestSelected()
    local lowests = {}
    local lowestDepth = math.huge
    for key, _ in pairs(self:GetSelectedItems()) do
        local depth = self.tree:GetDepth(key)
        if depth and depth < lowestDepth then
            lowestDepth = depth
            lowests = { key }
        elseif depth and depth == lowestDepth then
            table.insert(lowests, key)
        end
    end
    return lowests
end

function TreeList:SelectLogic(key, parent)
    if self.InputStates.MultiSelect then

    elseif self.InputStates.GroupSelect then
        if self.lastSelectedKey and self.indexRefs and self.indexRefs[self.lastSelectedKey] and self.indexRefs[key] then
            local lastSelectedKey = self.lastSelectedKey
            local lastRef = self.itemRefs[self.lastSelectedKey]
            lastRef.Highlight = false
            local startIdx = self.indexRefs[lastSelectedKey]
            local endIdx = self.indexRefs[key]

            if startIdx and endIdx then
                self:ClearSelection(true)
                if startIdx > endIdx then
                    startIdx, endIdx = endIdx, startIdx
                end

                lastRef.Highlight = true
                for i = startIdx, endIdx do
                    local indexkey = self.indexRefsReverse[i]
                    self:ToggleSelected(indexkey)
                end
            else
                Warning("Failed to determine range for group select")
                self:ToggleSelected(key)
            end
        else
            self:ToggleSelected(key)
        end
    else
        self:ClearSelection(true)
        self.itemRefs[key].Selected = true
        self.lastSelectedKey = key
        if parent and self.itemRefs[parent] and parent ~= TreeTable.GetRootKey() then
            self.itemRefs[parent].Highlight = true
        end
    end
end

function TreeList:SetupHoveringDetection(selectable, key)
    local onEnter = selectable.OnHoverEnter or function() end
    local onLeave = selectable.OnHoverLeave or function() end
    selectable.OnHoverEnter = function(sel)
        self.hoveringKey = key
        onEnter(sel)
    end
    selectable.OnHoverLeave = function(sel)
        self.hoveringKey = nil
        onLeave(sel)
    end
end

function TreeList:SetupDragDropFns()
    self.SelectableOnDragStart = function(sel)
        local key = sel.UserData and sel.UserData.Key
        if not self.InputStates.GroupSelect and not self.InputStates.MultiSelect then
            self:ClearSelection(true)
        end
        self.itemRefs[key].Selected = true
        self:OnSelect()
        local previewTable = sel.DragPreview:AddTable("##DragPreview", 2)
        previewTable.ColumnDefs[1] = { WidthStretch = true }
        previewTable.ColumnDefs[2] = { WidthFixed = true }
        self:ApplyTreeTableStyle(previewTable)
        local row = previewTable:AddRow()
        local keyToIndex = self.keyToIndex or {}
        for ikey, _ in RBUtils.SortedPairs(self:GetSelectedItems(), function (a, b)
            return keyToIndex[a] < keyToIndex[b]
        end) do
            local cell = row:AddCell()
            local fixedCell = row:AddCell()
            if self.tree:IsLeaf(ikey) then
                self:RenderLeaf(ikey, cell, fixedCell) 
            else
                cell:AddImage(RB_ICONS.Collection, IMAGESIZE.ROW)
                local ele = self:RenderTree(ikey, cell, fixedCell)
                ele.SameLine = true
            end
            local ref = self.nodeRefs[ikey]
            ref:SetStyle("Alpha", 0.5)
        end
        sel.UserData.UserDragStart(sel)
    end

    local isValid = true
    self.SelectableOnDragDrop = function(sel, drop)
        local befRow = self.rootTable.UserData.Row
        local dropped = drop.UserData or {}
        if dropped.Key then
            self:OnDragDrop(dropped.Key, sel.UserData.Key) -- this may trigger a rerender
        end
        if befRow ~= self.rootTable.UserData.Row then
            -- since drag drop may rerender the list
            -- which make the sel handle invalid
            -- so skip user drag drop if the row has been changed
            isValid = false
            return
        end
        sel.UserData.UserDragDrop(sel, drop)
    end

    self.SelectableOnDragEnd = function(sel)
        for ikey, _ in pairs(self:GetSelectedItems()) do
            local ref = self.nodeRefs[ikey]
            ref:SetStyle("Alpha", 1.0)
        end
        if not isValid then
            -- drag end called after drag drop
            -- which means the sel handle is invalid, so skip user drag end as well
            isValid = true
            return
        end
        sel.UserData.UserDragEnd(sel)
    end
end

--- @param selectable ExtuiSelectable
function TreeList:SetupDragAndDrop(selectable)
    selectable.CanDrag = true
    selectable.DragDropType = "TreeList" .. self.label

    selectable.UserData = selectable.UserData or {}
    selectable.UserData.UserDragStart = selectable.OnDragStart or emptyFunc
    selectable.UserData.UserDragEnd = selectable.OnDragEnd or emptyFunc
    selectable.UserData.UserDragDrop = selectable.OnDragDrop or emptyFunc

    selectable.OnDragStart = self.SelectableOnDragStart
    selectable.OnDragEnd = self.SelectableOnDragEnd
    selectable.OnDragDrop = self.SelectableOnDragDrop
end

---@param selectable ExtuiSelectable
---@param key any
function TreeList:SetUpLeaf(selectable, key)
    selectable.SpanAllColumns = true

    selectable.UserData = selectable.UserData or {}
    selectable.UserData.Key = key
    selectable.UserData.IsLeaf = true


    if self.recordedSelectedItems[key] then
        selectable.Selected = true
    else
        selectable.Selected = false
    end

    selectable.UserData.UserOnClick = selectable.OnClick or emptyFunc
    selectable.OnClick = self.SelectableOnClick

    self:SetupDragAndDrop(selectable, key)
end

local icons = RB_ICONS
local collapseUV = RB_ICON_UV01[icons.Tree_Collapsed]
local expandUV = RB_ICON_UV01[icons.Tree_Expanded]

function TreeList:SetupSelectableFns()
    local lastSelectedKey = nil
    self.SelectableOnClick = RBUtils.DoubleClick(function (sel)
        lastSelectedKey = lastSelectedKey == sel.UserData.Key and nil or sel.UserData.Key
        self:SelectLogic(sel.UserData.Key, self.tree:GetParentKey(sel.UserData.Key))
        self:OnSelect()
        sel.UserData.UserOnClick(sel)
    end, function (e)
        if e.UserData and e.UserData.Key and e.UserData.Key == lastSelectedKey then
            self:SetupRenameInput(e.UserData.Key, e.Label)
        end
    end)

    self.TreeUpdateLabel = function(sel)
        local key = sel.UserData and sel.UserData.Key
        if not self.arrowRefs[key] then return end
        local icon = self.collapsedTree[key] and collapseUV or expandUV
        self.arrowRefs[key].Image = icon
    end

    self.TreeExpand = function (sel)
        local key = sel.UserData and sel.UserData.Key
        self.collapsedTree[key] = nil
        self:IterativeShow(key)
        sel.UserData.UpdateLabel(sel)
    end


    self.TreeCollapse = function(sel)
        local key = sel.UserData and sel.UserData.Key
        self.collapsedTree[key] = true
        self:IterativeHide(key)
        sel.UserData.UpdateLabel(sel)
    end

    self.TreeToggle = function(sel)
        local key = sel.UserData and sel.UserData.Key
        self.collapsedTree[key] = not self.collapsedTree[key]
        if self.collapsedTree[key] then
            self:IterativeHide(key)
        else
            self:IterativeShow(key)
        end
        sel.UserData.UpdateLabel(sel)
    end

end

--- @class TreeListTreeUserData
--- @field Key any
--- @field ToggleLabel fun(sel:ExtuiSelectable)
--- @field Toggle fun(sel:ExtuiSelectable)
--- @field Collapse fun(sel:ExtuiSelectable)
--- @field Expand fun(sel:ExtuiSelectable)
--- @field UpdateLabel fun(sel:ExtuiSelectable)
--- @field UserOnClick fun(sel:ExtuiSelectable)

---@param tree ExtuiSelectable
---@param key any
function TreeList:SetUpTree(tree, key)
    --- @type TreeListTreeUserData
    tree.UserData = tree.UserData or {}
    tree.UserData.Key = key

    tree.SpanAllColumns = true

    tree.UserData.UserOnClick = tree.OnClick or emptyFunc

    tree.OnClick = self.SelectableOnClick

    tree.UserData.Collapse = self.TreeCollapse
    tree.UserData.Expand = self.TreeExpand
    tree.UserData.Toggle = self.TreeToggle
    tree.UserData.UpdateLabel = self.TreeUpdateLabel

    self:SetupDragAndDrop(tree, key)
end

function TreeList:SetupArrowFns()
    self.ArrowOnClick = function(arrow)
        local key = arrow.UserData and arrow.UserData.Key
        if self.itemRefs[key] and self.itemRefs[key].UserData and self.itemRefs[key].UserData.Toggle then
            self.itemRefs[key].UserData.Toggle(self.itemRefs[key])
        end
    end

    self.ArrowOnRightClick = function(arrow)
        local key = arrow.UserData and arrow.UserData.Key
        self.collapsedTree[key] = not self.collapsedTree[key]
        if arrow.UserData.Show then
            self:ExpandAll(key)
        else
            self:CollapseAll(key)
        end

        arrow.UserData.Show = not arrow.UserData.Show
    end
end

---@param arrow ExtuiImageButton
---@param key any
function TreeList:SetupArrow(arrow, key)
    StyleHelpers.ApplyBorderlessImageButtonStyle(arrow)

    arrow.UserData = arrow.UserData or {}
    arrow.UserData.Key = key
    arrow.UserData.Show = self.collapsedTree[key] == true

    arrow.OnClick = self.ArrowOnClick
    arrow.OnRightClick = self.ArrowOnRightClick
end

function TreeList:OnRenameInput(key, newName) end
function TreeList:OnRenamingInput(key, newName) end

function TreeList:SetupRenameInput(key, userLabel)
    if self.IsRenaming then return end
    local isLeaf = self.itemRefs[key] ~= nil
    local selec = isLeaf and self.itemRefs[key]
    if not selec then return end

    self.IsRenaming = true
    selec.Visible = false

    local node = self.nodeRefs[key].UserData.SelectableCell
    if not node then
        self.IsRenaming = false
        selec.Visible = true
        return
    end

    userLabel = userLabel:gsub("##.*", "") -- remove id suffix
    local input = node:AddInputText("", userLabel) --[[@type ExtuiInputText?]]
    input.EnterReturnsTrue = true
    input.IDContext = "TreeList" .. self.label .. "RenameInput"
    input.SameLine = true
    --input.SizeHint = { #userLabel * 16 + 32, IMAGESIZE.SMALL[2] }

    local function rerender()
        if input then
            input:Destroy()
            input = nil
        end
        selec.Visible = true
        self.IsRenaming = false
    end

    local function rename()
        if not input then return end
        local newName = input.Text
        if newName == userLabel then
            rerender()
            return
        end
        input:Destroy()
        input = nil
        self.IsRenaming = false
        self:OnRenameInput(key, newName, selec)
    end

    input.OnChange = function(e)
        if not e.EnterReturnsTrue then return end
        rename()
    end

    Timer:After(3000, function (timerID)
        Timer:EveryFrame(function (timerID)
            local ok, focused = pcall(ImguiHelpers.IsFocused, input)
            if not ok then
                pcall(rerender)
                return UNSUBSCRIBE_SYMBOL
            end

            if not focused and input then
                pcall(rerender)
                return UNSUBSCRIBE_SYMBOL
            end
        end)
    end)

end

function TreeList:RenderCustomTopBar(panel)
    panel.Visible = false
end

function TreeList:ExpandAll(key)
    key = key or TreeTable.GetRootKey()

    self.collapsedTree = self.collapsedTree or {}

    
    self.collapsedTree[key] = nil
    self.itemRefs[key].UserData.Expand(self.itemRefs[key])

    local childStack = {}
    table.insert(childStack, key)
    
    while #childStack > 0 do
        local current = table.remove(childStack)
        local node = self.tree:Find(current)
        if node and not self.tree:IsLeaf(current) then
            for childKey,_ in pairs(node) do
                if not self.tree:IsLeaf(childKey) then
                    table.insert(childStack, childKey)
                    self.itemRefs[childKey].UserData.Expand(self.itemRefs[childKey])
                end
            end
        end
    end
end

function TreeList:SelectAll(key)
    local rootKey = TreeTable.GetRootKey()
    if not key then key = rootKey end
    if key == rootKey then
        for k, item in pairs(self.itemRefs) do
            item.Selected = true
        end

        self:OnSelect()
        return
    end

    local stack = {key}
    while #stack > 0 do
        local current = table.remove(stack)
        local node = self.tree:Find(current)
        if node then
            self.itemRefs[current].Selected = true
            if not self.tree:IsLeaf(current) then
                for childKey,_ in pairs(node) do
                    table.insert(stack, childKey)
                end
            end
        end
    end

    self:OnSelect()
end

function TreeList:CollapseAll(key)
    key = key or TreeTable.GetRootKey()

    self.collapsedTree = self.collapsedTree or {}

    self.collapsedTree[key] = nil
    self.itemRefs[key].UserData.Expand(self.itemRefs[key])

    local childStack = {}
    table.insert(childStack, key)

    while #childStack > 0 do
        local current = table.remove(childStack)
        local node = self.tree:Find(current)
        if node and not self.tree:IsLeaf(current) then
            for childKey,_ in pairs(node) do
                if not self.tree:IsLeaf(childKey) then
                    table.insert(childStack, childKey)
                    self.itemRefs[childKey].UserData.Collapse(self.itemRefs[childKey])
                end
            end
        end
    end
end

--- @return table<any, boolean> selected items
function TreeList:GetSelectedItems()
    local selectedItems = {}
    for key, item in pairs(self.itemRefs) do
        if item.Selected then
            selectedItems[key] = true
        end
    end
    return selectedItems
end

function TreeList:RecordSelectedItems()
    self.selectedItems = self:GetSelectedItems()
end

---@param selectedItems table<any, boolean>
function TreeList:OnSelect(selectedItems) end

function TreeList:OnDragStart(dragKey) end

function TreeList:OnDragDrop(from, to) end

function TreeList:OnDragEnd(dragKey) end

function TreeList:OnAttach() end

function TreeList:OnDetach() end


--- setup functions that rely on itemRefs or arrowRefs, 

TreeList:SetupDragDropFns()
TreeList:SetupArrowFns()