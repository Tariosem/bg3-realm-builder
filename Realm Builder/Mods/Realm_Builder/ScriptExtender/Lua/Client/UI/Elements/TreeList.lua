--- @class TreeList
--- @field parent ExtuiTreeParent
--- @field panel ExtuiTreeParent
--- @field selectedItems table<any, boolean>
--- @field itemRefs table<any, ExtuiSelectable>
--- @field nodeRefs table<any, ExtuiTableCell>
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
--- @field RenderOrder fun(aKey:any, bKey:any):boolean
--- @field FilterFunc fun(self:TreeList, key:any, keyword:string):boolean
--- @field ShowAndShowPath fun(self:TreeList, key:any)
--- @field ClearSelection fun(self:TreeList)
--- @field ClearList fun(self:TreeList)
--- @field SelectLogic fun(self:TreeList, key:any, parent:any)
--- @field SetupArrow fun(self:TreeList, arrow:ExtuiGroup, key:any)
--- @field GetLowestSelected fun(self:TreeList):any[]
--- @field OnSelect fun(self:TreeList, selectedItems:table<any, boolean>)
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

    self.selectedItems = {}
    self.tree = tree

    self.itemRefs = {} -- save tree selectables
    self.itemRefs = {} -- save leaf selectables for items
    self.nodeRefs = {} -- save all cells for nodes, userdata is the indent container
    self.collapsedTree = {}

    self:SetupKeyListeners()
end

function TreeList:SetupKeyListeners()
    self.selectModeKeySub = SubscribeKeyInput({}, function(e)
        if e.Repeat then return end
        if e.Key == "LCTRL" or e.Key == "RCTRL" then
            if e.Event == "KeyDown" then
                self.MultiSelect = true
                self.GroupSelect = false
            elseif e.Event == "KeyUp" then
                self.MultiSelect = false
            end
        elseif e.Key == "LSHIFT" or e.Key == "RSHIFT" then
            if e.Event == "KeyDown" then
                self.GroupSelect = true
                self.MultiSelect = false
            elseif e.Event == "KeyUp" then
                self.GroupSelect = false
            end
        end
    end)
end

function TreeList:Render()
    self.panel = self.parent
    self:OnAttach()


    self:RenderTopBar()
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
    local rightA, leftA, topbar = AddRightAlignCell(self.panel)

    self.topBar = topbar
    local searchInput = leftA:AddInputText("") --[[@as ExtuiInputText]]
    searchInput.IDContext = "TreeList" .. self.label .. "Search"

    searchInput.Hint = "Search..."
    searchInput.Text = self.SearchKeyword or ""
    searchInput.OnChange = Debounce(50, function()
        self.SearchKeyword = searchInput.Text
        self:Hide(searchInput.Text)
    end)
end

--- return true to show the item
function TreeList:FilterFunc(key, keyword)
    return true
end

--- @param aKey any
--- @param bKey any
--- @return boolean
function TreeList.RenderOrder(aKey, bKey)
    return tostring(aKey) < tostring(bKey)
end

function TreeList:Hide(keyword)
    for _,node in pairs(self.nodeRefs) do
        node.Visible = false
    end

    if keyword == nil or keyword == "" then
        self:RecursiveShow(TreeTable.GetRootKey())
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

function TreeList:ShowAndShowPath(key)
    if not self.nodeRefs[key] then return end
    self.nodeRefs[key].Visible = true
    local path = self.tree:GetPath(key)
    for _,parentKey in pairs(path) do
        self.nodeRefs[parentKey].Visible = true
    end
end

-- Depth-first
--- @param func fun(key:any, node:ExtuiTableCell)
function TreeList:TraverseAllNodes(func)
    local stack = {}
    local root = self.tree:Find(TreeTable.GetRootKey())
    for childKey,_ in pairs(root) do
        table.insert(stack, childKey)
    end
    while #stack > 0 do
        local current = table.remove(stack)
        local node = self.tree:Find(current)
        local nodeCell = self.nodeRefs[current]
        if node and nodeCell then
            func(current, nodeCell)
            if not self.tree:IsLeaf(current) then
                for childKey,_ in pairs(node) do
                    table.insert(stack, childKey)
                end
            end
        end
    end
end

function TreeList:RecursiveHide(key)
    local node = self.tree:Find(key)
    if node and not self.tree:IsLeaf(key) then
        for childKey,_ in pairs(node) do
            if self.nodeRefs[childKey] then
                self.nodeRefs[childKey].Visible = false
            end
            self:RecursiveHide(childKey)
        end
    end
end

function TreeList:RecursiveShow(key)
    local node = self.tree:Find(key)
    if node then
        self.nodeRefs[key].Visible = true
        if not self.collapsedTree[key] and not self.tree:IsLeaf(key) then
            for childKey,_ in pairs(node) do
                self:RecursiveShow(childKey)
            end
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
    tbl.BordersH = true
end

function TreeList:RenderList()
    -- validate renderOrder
    local ok, err = pcall(self.RenderOrder, "a", "b")
    if not ok then
        Error("RenderOrder function error: " .. tostring(err) .. ". Using default order.")
        self.RenderOrder = function(aKey, bKey)
            return tostring(aKey) < tostring(bKey)
        end
    end
    if type(err) ~= "boolean" then
        Error("RenderOrder function must return boolean. Using default order.")
        self.RenderOrder = function(aKey, bKey)
            return tostring(aKey) < tostring(bKey)
        end
    end

    --- @type ExtuiTable
    self.rootTable = self.rootTable or self.panel:AddTable(self.label .. "##Root", 1)
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
    self.nodeRefs = {}
    self.indexRefs = {}
    self.indexRefsReverse = {}
    setmetatable(self.nodeRefs, {
        __index = function(t, k)
            if k == TreeTable.GetRootKey() then
                return row
            end
            return rawget(t, k)
        end
    })
    local leafCnt = 1

    local function collectChildren(key)
        local collector = {}
        local node = self.tree:Find(key)
        for childKey,_ in pairs(node or {}) do
            table.insert(collector, childKey)
        end
        table.sort(collector, self.RenderOrder)
        return collector
    end

    --- @param key any
    --- @return unknown
    local depthIndent = function(key)
        local depth = self.tree:GetDepth(key)
        return (depth - 1) * 64
    end

    local stack = {}
    local rootChildren = collectChildren(TreeTable.GetRootKey())
    for i = #rootChildren, 1, -1 do
        table.insert(stack, { key = rootChildren[i], depth = 1 })
    end

    if #stack == 0 then
        self.rootTable.Visible = false
        return
    end
    self.rootTable.Visible = true

    while #stack > 0 do
        local item = table.remove(stack)
        local key, depth = item.key, item.depth
        local node = self.tree:Find(key)
        if node then
            local cell = row:AddCell()
            self:SetupHoveringDetection(cell, key)
            local indentDepth = depthIndent(key)
            local innerTab = cell:AddTable("IndentTable##" .. tostring(key), 3)
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
                SeletableCell = leftCell,
                FixedCell = fixedCell
            }
            local ele
            if self.tree:IsLeaf(key) then
                ele = self:RenderLeaf(key, leftCell, fixedCell)
                cell.Visible = false
            else
                local arrowReserved = leftCell:AddGroup("##ArrowReserved")
                arrowReserved.IDContext = "TreeList" .. self.label .. "ArrowReserved" .. tostring(key)
                local icon = self.collapsedTree[key] and RB_ICONS.Tree_Collapsed or RB_ICONS.Tree_Expanded
                local arrowImage = arrowReserved:AddImageButton("##" .. key .. "ArrowBtn", icon, IMAGESIZE.ROW)
                StyleHelpers.SetupImageButton(arrowImage)
                ele = self:RenderTree(key, leftCell, fixedCell)
                ele.SameLine = true
                self.arrowRefs[key] = arrowReserved
                cell.Visible = false

                local children = collectChildren(key)
                for i = #children, 1, -1 do
                    table.insert(stack, { key = children[i], depth = depth + 1 })
                end
            end

            ele.AllowItemOverlap = true
            self.itemRefs[key] = ele
            self.nodeRefs[key] = cell
            self.indexRefs[key] = leafCnt
            self.indexRefsReverse[leafCnt] = key
            leafCnt = leafCnt + 1
        end
    end

    for key,ele in pairs(self.itemRefs) do
        if self.tree:IsLeaf(key) then
            self:SetUpLeaf(ele, key)
        else
            self:SetUpTree(ele, key, self.tree:Find(key))
        end
    end
    for key,arrow in pairs(self.arrowRefs) do
        self:SetupArrow(arrow, key)
    end

    self:IterativeShow(TreeTable.GetRootKey())
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
        if ref.Selected then
            self.selectedItems[key] = true
        else
            self.selectedItems[key] = nil
        end
    end
end

function TreeList:SetSelected(key, selected)
    local ref = self.itemRefs[key]
    if ref then
        ref.Selected = selected
        if selected then
            self.selectedItems[key] = true
        else
            self.selectedItems[key] = nil
        end
    end
end

function TreeList:ClearSelection(notCallback)
    self.selectedItems = {}
    for k, ele in pairs(self.itemRefs) do
        ele.Selected = false
        ele.Highlight = false
    end
    if not notCallback then
        self:OnSelect(self.selectedItems)
    end
end

function TreeList:GetLowestSelected()
    local lowests = {}
    local lowestDepth = math.huge
    for key, _ in pairs(self.selectedItems) do
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
    if self.MultiSelect then
            self:ToggleSelected(key)
    elseif self.GroupSelect then
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

                local ref = self.itemRefs[key]
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
        local wasSelected = self.selectedItems[key] ~= nil
        self:ClearSelection(true)
        self:SetSelected(key, not wasSelected)
        if self.lastSelectedKey and self.itemRefs[self.lastSelectedKey] then
            local ref = self.itemRefs[self.lastSelectedKey]
            ref.Highlight = false
        end
        self.lastSelectedKey = key
        if parent and self.itemRefs[parent] and parent ~= TreeTable.GetRootKey() and not wasSelected then
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

function TreeList:SetupDragAndDrop(selectable, key)
    local userOnDragStart = selectable.OnDragStart or emptyFunc

    selectable.OnDragStart = function(sel)
        if not self.GroupSelect and not self.MultiSelect then
            self:ClearSelection(true)
        end
        self.selectedItems[key] = true
        self:OnSelect(self.selectedItems)
        local previewTable = selectable.DragPreview:AddTable("##DragPreview", 2)
        previewTable.ColumnDefs[1] = { WidthStretch = true }
        previewTable.ColumnDefs[2] = { WidthFixed = true }
        self:ApplyTreeTableStyle(previewTable)
        local row = previewTable:AddRow()
        local cell = row:AddCell()
        cell:AddImage(RB_ICONS.Collection, IMAGESIZE.ROW)
        for ikey, iitem in SortedPairs(self.selectedItems, self.RenderOrder) do
            --local cell = row:AddCell()
            --local fixedCell = row:AddCell()
            --if self.tree:IsLeaf(ikey) then
                --self:RenderLeaf(ikey, cell, fixedCell) 
            --else
                --cell:AddImage(RB_ICONS.Collection, IMAGESIZE.ROW)
                --local ele = self:RenderTree(ikey, cell, fixedCell)
                --ele.SameLine = true
            --end
            local ref = self.nodeRefs[ikey]
            ref:SetStyle("Alpha", 0.5)
        end
        userOnDragStart(sel)
    end

    local userOnDragEnd = selectable.OnDragEnd or emptyFunc
    selectable.OnDragEnd = function(sel)
        for ikey, _ in pairs(self.selectedItems) do
            local ref = self.nodeRefs[ikey]
            ref:SetStyle("Alpha", 1.0)
        end
        userOnDragEnd(sel)
    end

    local userDragDrop = selectable.OnDragDrop or emptyFunc
    selectable.OnDragDrop = function(sel, drop)
        local dropped = drop.UserData or {}
        if dropped.Key then
            self:OnDragDrop(dropped.Key, key)
        end
        userDragDrop(sel, drop)
    end
end

---@param selectable ExtuiSelectable
---@param key any
function TreeList:SetUpLeaf(selectable, key)
    selectable.CanDrag = true
    selectable.DragDropType = "TreeList" .. self.label

    selectable.SpanAllColumns = true

    selectable.UserData = selectable.UserData or {}
    selectable.UserData.Key = key
    selectable.UserData.IsLeaf = true

    local parent = self.tree:GetParentKey(key)

    if self.selectedItems[key] then
        selectable.Selected = true
    else
        selectable.Selected = false
    end

    self:SetupDragAndDrop(selectable, key)
    
    local userOnClick = selectable.OnClick or emptyFunc
    local userLabel = selectable.Label

    local delayTimer = nil
    local doubleClickThreshold = 300 -- ms
    
    --- @param sel ExtuiSelectable
    selectable.OnClick = function(sel)
        sel.Selected = not sel.Selected
        if delayTimer then
            Timer:Cancel(delayTimer)
            delayTimer = nil
            self:SetupRenameInput(key, userLabel)
            return
        end

        self:SelectLogic(key, parent)
        self:OnSelect(self.selectedItems)

        userOnClick(sel)

        delayTimer = Timer:After(doubleClickThreshold, function()
            if not delayTimer then return end
            delayTimer = nil
        end)
    end
end

---@param tree ExtuiSelectable
---@param key any
function TreeList:SetUpTree(tree, key)
    tree.CanDrag = true
    tree.DragDropType = "TreeList" .. self.label

    tree.UserData = tree.UserData or {}
    tree.UserData.Key = key

    tree.SpanAllColumns = true

    local parent = self.tree:GetParentKey(key)

    self:SetupDragAndDrop(tree, key)

    local userLabel = tree.Label
    local toggleLabel = function()
        local reserved = self.arrowRefs[key]
        DestroyAllChildren(reserved)
        local icon = self.collapsedTree[key] and RB_ICONS.Tree_Collapsed or RB_ICONS.Tree_Expanded
        local arrowImage = reserved:AddImageButton("##" .. key .. "ArrowBtn", icon, IMAGESIZE.ROW)
        StyleHelpers.SetupImageButton(arrowImage)
    end


    local toggleFunc = function()
        self.collapsedTree[key] = not self.collapsedTree[key]
        if self.collapsedTree[key] then
            self:IterativeHide(key)
        else
            self:IterativeShow(key)
        end
        toggleLabel()
    end

    local userOnClick = tree.OnClick or emptyFunc

    local delayTimer = nil
    local doubleClickThreshold = 300 -- ms

    tree.OnClick = function(sel)
        sel.Selected = false
        if delayTimer then
            Timer:Cancel(delayTimer)
            delayTimer = nil
            self:SetupRenameInput(key, userLabel)
            return
        end

        self:SelectLogic(key, parent)
        self:OnSelect(self.selectedItems)

        userOnClick(sel)

        delayTimer = Timer:After(doubleClickThreshold, function()
            if not delayTimer then return end
            delayTimer = nil
        end)
    end

    toggleLabel()

    local function collapse()
        self.collapsedTree[key] = true
        self:IterativeHide(key)
        toggleLabel()
    end

    local function expand()
        self.collapsedTree[key] = nil
        self:IterativeShow(key)
        toggleLabel()
    end

    tree.UserData.Collapse = collapse
    tree.UserData.Expand = expand
    tree.UserData.Toggle = toggleFunc
    tree.UserData.UpdateLabel = toggleLabel

    setmetatable(tree.UserData, {
        __index = function(t, k)
            if k == "IsCollapsed" then
                return self.collapsedTree[key] == true
            end
            return nil
        end,
        __newindex = function(t, k, v)
            if k == "IsCollapsed" then
                if v == true then
                    self.collapsedTree[key] = true
                    self:IterativeHide(key)
                else
                    self.collapsedTree[key] = nil
                    self:IterativeShow(key)
                end
                toggleLabel()
            else
                rawset(t, k, v)
            end
        end
    })
end

---@param arrow ExtuiGroup
---@param key any
function TreeList:SetupArrow(arrow, key)
    local show = false

    if self.collapsedTree[key] then
        show = true
    end

    arrow.OnHoverEnter = function ()
        arrow:SetColor("Button", {1,1,1,0.2})
    end

    arrow.OnHoverLeave = function ()
        arrow:SetColor("Button", {0,0,0,0})
    end

    arrow.OnClick = function()
        if self.itemRefs[key] and self.itemRefs[key].UserData and self.itemRefs[key].UserData.Toggle then
            self.itemRefs[key].UserData.Toggle()
        end
    end

    arrow.OnRightClick = function()
        self.collapsedTree[key] = not self.collapsedTree[key]
        if show then
            self:ExpandAll(key)
        else
            self:CollapseAll(key)
        end

        show = not show
    end
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

    local node = self.nodeRefs[key].UserData.SeletableCell

    userLabel = userLabel:gsub("##.*", "") -- remove id suffix
    local input = node:AddInputText("", userLabel) --[[@type ExtuiInputText?]]
    input.IDContext = "TreeList" .. self.label .. "RenameInput"
    input.SameLine = true
    --input.SizeHint = { #userLabel * 16 + 32, IMAGESIZE.SMALL[2] }

    input.OnChange = function(e)
        if not input then return end
        --input.SizeHint = { #input.Text * 16 + 32, IMAGESIZE.SMALL[2] }
    end

    local function rerender()
        selec.Visible = true
        self.IsRenaming = false
    end

    local function rename()
        if not input then return end
        local newName = input.Text  
        input:Destroy()
        input = nil
        rerender()
        self.IsRenaming = false
        self:OnRenameInput(key, newName, selec)
        self:RenderList()
    end

    Timer:After(1000, function (timerID)
        local focusTimer = Timer:EveryFrame(function (timerID)
            local ok, focused = pcall(IsFocused, input)
            if not ok then
                pcall(rerender)
                return UNSUBSCRIBE_SYMBOL
            end

            if not focused and input then
                rename()
                return UNSUBSCRIBE_SYMBOL
            end
        end)
    end)

    local enterSub = SubscribeKeyInput({ Key = "RETURN" }, function (e)
        local ok, focused = pcall(IsFocused, input)
        if not ok then return UNSUBSCRIBE_SYMBOL end

        if focused and input then
            rename()
            return UNSUBSCRIBE_SYMBOL
        end
    end)

end

function TreeList:RenderCustomTopBar(panel)
    panel.Visible = false
end

function TreeList:ExpandAll(key)
    key = key or TreeTable.GetRootKey()

    self.collapsedTree = self.collapsedTree or {}

    
    self.collapsedTree[key] = nil
    self.itemRefs[key].UserData.Expand()

    local childStack = {}
    table.insert(childStack, key)
    
    while #childStack > 0 do
        local current = table.remove(childStack)
        local node = self.tree:Find(current)
        if node and not self.tree:IsLeaf(current) then
            for childKey,_ in pairs(node) do
                if not self.tree:IsLeaf(childKey) then
                    table.insert(childStack, childKey)
                    self.itemRefs[childKey].UserData.Expand()
                end
            end
        end
    end
end

function TreeList:SelectAll(key)
    if not key then key = TreeTable.GetRootKey() end
    if key == TreeTable.GetRootKey() then
        for k,_ in pairs(self.nodeRefs) do
            self.selectedItems[k] = true
            self.itemRefs[k].Selected = true
        end
        self:OnSelect(self.selectedItems)
        return
    end

    local stack = {key}
    while #stack > 0 do
        local current = table.remove(stack)
        local node = self.tree:Find(current)
        if node then
            self.selectedItems[current] = true
            self.itemRefs[current].Selected = true
            if not self.tree:IsLeaf(current) then
                for childKey,_ in pairs(node) do
                    table.insert(stack, childKey)
                end
            end
        end
    end

    self:OnSelect(self.selectedItems)
end

function TreeList:CollapseAll(key)
    key = key or TreeTable.GetRootKey()

    self.collapsedTree = self.collapsedTree or {}

    self.collapsedTree[key] = nil
    self.itemRefs[key].UserData.Expand()

    local childStack = {}
    table.insert(childStack, key)

    while #childStack > 0 do
        local current = table.remove(childStack)
        local node = self.tree:Find(current)
        if node and not self.tree:IsLeaf(current) then
            for childKey,_ in pairs(node) do
                if not self.tree:IsLeaf(childKey) then
                    table.insert(childStack, childKey)
                    self.itemRefs[childKey].UserData.Collapse()
                end
            end
        end
    end
end

---@param selectedItems table<any, boolean>
function TreeList:OnSelect(selectedItems) end

function TreeList:OnDragStart(dragKey) end

function TreeList:OnDragDrop(from, to) end

function TreeList:OnDragEnd(dragKey) end

function TreeList:OnAttach() end

function TreeList:OnDetach() end