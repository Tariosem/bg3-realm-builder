function IconBrowser:GetSearchCriteria()
    local fields = {}
    for field, _ in pairs(self.selectedFields) do
        table.insert(fields, field)
    end
    return tostring(self.searchInput.Text), tostring(self.noteInput.Text), fields
end

function IconBrowser:ClearNonExistTagsAndGroups()
    local cleared = false
    for tag, _ in pairs(self.selectedTags) do
        if not self.tagsMap[tag] then
            self.selectedTags[tag] = nil
            cleared = true
        end
    end
    for tag, _ in pairs(self.excludeTags) do
        if not self.tagsMap[tag] then
            self.excludeTags[tag] = nil
            cleared = true
        end
    end
    for group, _ in pairs(self.selectedGroups) do
        if not self.groupMap[group] then
            self.selectedGroups[group] = nil
            cleared = true
        end
    end
    for group, _ in pairs(self.excludeGroups) do
        if not self.groupMap[group] then
            self.excludeGroups[group] = nil
            cleared = true
        end
    end
    if cleared then
        self:Search()
    end
end

function IconBrowser:CheckIfAnySearchCriteria()
    local searchText, noteText, fields = self:GetSearchCriteria()
    local hasIncludeConditions = (searchText and searchText ~= "") or (noteText and noteText ~= "") or
        next(self.selectedTags) ~= nil or
        next(self.selectedGroups) ~= nil

    local hasExcludeConditions = next(self.excludeTags) ~= nil or next(self.excludeGroups) ~= nil

    return hasIncludeConditions or hasExcludeConditions
end

function IconBrowser:RefreshTagFilder()
    local menu = self.topMenuBar:AddMenu("Tags Filter >") --[[@as ExtuiMenu]]
    menu.OnHoverEnter = function()
        local refreshFn = self:RenderTagsFilter(menu)
        refreshFn()
        menu.OnHoverEnter = refreshFn
        self.RefreshTagFilder = refreshFn
    end
end

-- Abomination
--- @param parent ExtuiTreeParent
function IconBrowser:RenderTagsFilter(parent)
    local allGroups, allTags, groupMap, tagsMap = self.dataManager:CountGroupsAndTags(self.selectedGuid)
    
    local function refreshFn() end
    self.tagsMap = tagsMap
    self.groupMap = groupMap
    self:ClearNonExistTagsAndGroups()
    
    local tagTree = self.dataManager.tagTree
    local collectionCnt = {}
    local updateFns = {}
    local tagIcons = self.dataManager.tagIcons
    local dragDropType = "IconBrowserTag"
    local browser = self
    
    local setupImageFunc = StyleHelpers.ApplyImageButtonHoverStyle

    local function updateCollectionCnt()
        browser:ClearNonExistTagsAndGroups()
        local function process(key)
            local node = tagTree:Find(key)
            if not node then return 0 end
            local cnt = 0
            for childKey, childNode in pairs(node) do
                local type = type(childNode)
                if type == "table" then
                    cnt = cnt + process(childKey)
                elseif type == "number" then
                    cnt = cnt + childNode
                end
            end
            collectionCnt[key] = cnt
            return cnt
        end

        local root = tagTree:GetRootKey()
        local rootNode = tagTree:Find(root)
        for key, obj in pairs(rootNode) do
            if type(obj) == "table" then
                process(key)
            end
        end
    end

    local function sortTreeKeys(key)
        local node = tagTree:Find(key)
        if not node then return {} end
        local keyArr = {}
        local sortCache = {}
        for k, v in pairs(node) do
            sortCache[k] = type(v) == "table" and 0 or 1
            table.insert(keyArr, k)
        end
        table.sort(keyArr, function(a, b)
            if sortCache[a] == sortCache[b] then
                return a < b
            end
            return sortCache[a] < sortCache[b]
        end)
        return keyArr
    end

    local inputting = false
    --- @param selectable ExtuiStyledRenderable
    --- @param input ExtuiInputText
    --- @param label string
    --- @param updateFn fun(newName:string)
    local function subscribeRename(selectable, input, label, updateFn)
        inputting = true
        selectable.Visible = false
        input.Visible = true
        input.Text = label
        input.EnterReturnsTrue = true

        input.OnChange = function (s)
            if not input.EnterReturnsTrue then return end

            inputting = false
            selectable.Visible = true
            input.Visible = false
            input.OnChange = nil
            updateFn(tostring(input.Text))
        end
    end

    --- @param tableRow ExtuiTreeParent
    --- @param tag string
    --- @return fun()
    local function renderTagEntry(tableRow, tag)
        local cnt = allTags[tag] or 0
        if cnt == 0 then
            return function () end
        end
        local parent = tableRow:AddCell()
        local hasIcon = tagIcons[tag]
        local icon = {} --[[@as ExtuiImageButton]]
        if hasIcon then
            icon = parent:AddImageButton("##" .. tag .. "IconButton", hasIcon, IMAGESIZE.FRAME)
            setupImageFunc(icon)
        end

        local selection = parent:AddSelectable(tag .. " (" .. cnt .. ")")
        selection.SameLine = hasIcon ~= nil
        selection.DontClosePopups = true
        selection.AllowItemOverlap = true

        local eles = { selection, icon }

        local function updateState()
            selection.Selected = browser.selectedTags[tag] ~= nil
            local alpha = browser.excludeTags[tag] and 0.5 or 1
            selection:SetStyle("Alpha", alpha)
            icon.Tint = {1, 1, 1, alpha}
        end

        local function toggleEntry(onTable, offTable)
            if onTable[tag] then
                onTable[tag] = nil
            else
                onTable[tag] = true
                offTable[tag] = nil
            end
        end

        local onSingleClick = function ()
            toggleEntry(browser.selectedTags, browser.excludeTags)
            updateState()
            browser:Search()
        end

        local onRightClick = function ()
            toggleEntry(browser.excludeTags, browser.selectedTags)
            updateState()
            browser:Search()
        end

        local renameInput = nil
        local onDoubleClick = function ()
            if inputting then return end
            if not renameInput then
                renameInput = parent:AddInputText("##" .. tag .. "RenameInput")
                renameInput.Visible = false
                renameInput.SameLine = true
            end
            subscribeRename(selection, renameInput, tag, function (newName)
                if newName == "" or newName == tag then
                    return
                end
                local suc = browser.dataManager:RenameTag(tag, newName)
                if not suc then return end
                tag = newName

                selection.Label = newName .. " (" .. cnt .. ")"

                browser.selectedTags[newName] = browser.selectedTags[tag]
                browser.selectedTags[tag] = nil
                browser.excludeTags[newName] = browser.excludeTags[tag]
                browser.excludeTags[tag] = nil
                updateState()
            end)
        end

        local onClick = RBUtils.DoubleClick(onSingleClick, onDoubleClick)
        
        local onDragStart = function(sel)
            sel.UserData = { Browser = browser, Tag = tag }
            if hasIcon then
                sel.DragPreview:AddImage(hasIcon, IMAGESIZE.FRAME)
            end
            sel.DragPreview:AddText(tag .. " (" .. cnt .. ")").SameLine = hasIcon ~= nil
        end

        local onDragDrop = function (sel, dropped)
            if not dropped or not dropped.UserData then return  end
            local droppedBrowser = dropped.UserData.Browser
            if browser ~= droppedBrowser then
                return
            end
            local droppedTag = dropped.UserData.Tag
            local thisParent = tagTree:GetParentKey(tag)
            tagTree:Reparent(droppedTag, thisParent or tagTree.GetRootKey())
            refreshFn()
        end

        for _, ele in pairs(eles) do
            ele.OnClick = onClick
            ele.OnRightClick = onRightClick
            ele.OnDragStart = onDragStart
            ele.OnDragDrop = onDragDrop

            ele.CanDrag = true
            ele.DragDropType = dragDropType
        end

        return updateState
    end

    --- @param tableRow ExtuiTreeParent
    --- @param collection string
    local function renderTagCollectionEntry(tableRow, collection)
        local cnt = collectionCnt[collection] or 0
        if cnt == 0 then
            return
        end
        local parent = tableRow:AddCell()
        local hasIcon = tagIcons[collection]
        local icon = {} --[[@as ExtuiImageButton]]
        local collectionName = collection .. " (" .. tostring(cnt) .. ")"
        if hasIcon then
            icon = parent:AddImage(hasIcon, IMAGESIZE.FRAME)
        end

        local menu = parent:AddMenu(collectionName .. " >.") --[[@as ExtuiMenu]]
        menu.SameLine = hasIcon ~= nil
        local eles = { menu, icon }

        local onDragStart = function(sel)
            sel.UserData = { Browser = browser, Tag = collection }
            if hasIcon then
                sel.DragPreview:AddImage(hasIcon, IMAGESIZE.FRAME)
            end
            sel.DragPreview:AddText(collection)
        end

        local onDragDrop = function (sel, dropped)
            if not dropped or not dropped.UserData then return  end
            local droppedBrowser = dropped.UserData.Browser
            if browser ~= droppedBrowser then
                return
            end
            local droppedTag = dropped.UserData.Tag
            tagTree:Reparent(droppedTag, collection)
            refreshFn()
        end

        local renameInput = nil
        local onDoubleClick = function ()
            if inputting then return end
            if not renameInput then
                renameInput = parent:AddInputText("##" .. collection .. "RenameInput")
                renameInput.Visible = false
                renameInput.SameLine = true
            end
            subscribeRename(menu, renameInput, collection, function (newName)
                if newName == "" or newName == collection then
                    return
                end

                local suc = browser.dataManager:RenameTagCollection(collection, newName)
                if not suc then return end

                collection = newName
                collectionName = newName .. " (" .. tostring(cnt) .. ")"
                collectionCnt[newName] = collectionCnt[collection]
                collectionCnt[collection] = nil
                
                menu.Label = collectionName
            end)
        end

        local onClick = RBUtils.DoubleClick(function () end, onDoubleClick)

        for _, ele in pairs(eles) do
            ele.OnClick = onClick
            ele.OnDragStart = onDragStart
            ele.OnDragDrop = onDragDrop

            ele.CanDrag = true
            ele.DragDropType = dragDropType
        end

        menu.OnHoverEnter = function ()
            local keyArr = sortTreeKeys(collection)
            local tab = menu:AddTable("TagCollectionTable_" .. collection, 1)
            local row = tab:AddRow()
            for _, key in ipairs(keyArr) do
                if tagTree:IsLeaf(key) then

                    local updateFn = renderTagEntry(row, key)
                    updateFns[key] = updateFn
                    updateFn()
                else
                    renderTagCollectionEntry(row, key)
                end
            end

            menu.OnHoverEnter = nil
        end

        return menu
    end

    local topGroup = parent:AddGroup("TagsFilterRootGroup")
    local topTab = topGroup:AddTable("TagsFilterTopTable", 2):AddRow()
    local cells = { topTab:AddCell(), topTab:AddCell() }

    local function addSeletable(parent, label, onClick)
        local sel = parent:AddSelectable(label)
        sel.DontClosePopups = true
        sel.AllowItemOverlap = true
        sel.OnClick = onClick
        return sel
    end
    
    addSeletable(cells[1], "Uninclude All", function (s)
        s.Selected = false
        for tag, _ in pairs(browser.selectedTags) do
            browser.selectedTags[tag] = nil
            if updateFns[tag] then
                updateFns[tag]()
            end
        end
        browser:Search()
    end)

    addSeletable(cells[2], "Unexclude All", function (s)
        s.Selected = false
        for tag, _ in pairs(browser.excludeTags) do
            browser.excludeTags[tag] = nil
            if updateFns[tag] then
                updateFns[tag]()
            end
        end
        browser:Search()
    end)

    function refreshFn()
        updateCollectionCnt()
        updateFns = {}
        for i, child in ipairs(parent.Children) do
            if child ~= topGroup then
                child:Destroy()
            end
        end
        local keyArr = sortTreeKeys(tagTree:GetRootKey())
        local tab = parent:AddTable("TagsFilterMainTable", 1)
        local row = tab:AddRow()
        for _, key in ipairs(keyArr) do
            if tagTree:IsLeaf(key) then
                local updateFn = renderTagEntry(row, key)
                updateFns[key] = updateFn
                updateFn()
            else
                renderTagCollectionEntry(row, key)
            end
        end
    end

    return refreshFn
end

function IconBrowser:AddGroupFilter()
    local allGroups, allTags, groupMap, tagsMap = self.dataManager:CountGroupsAndTags(self.selectedGuid)
    self.tagsMap = tagsMap
    self.groupMap = groupMap
    self:ClearNonExistTagsAndGroups()
    local sortWay = self.nameAscend and "asc" or "desc"

    for _, ele in ipairs(self.groupFilterElements or {}) do
        ele:Destroy()
    end

    self.groupFilter = self.groupFilter or
    self.topMenuBar:AddMenu("Groups filter >")
    self.groupPopup = self.groupFilter

    self.groupFilterElements = {}
    if allGroups and next(allGroups) == nil then
        table.insert(self.groupFilterElements, self.groupPopup:AddText(GetLoca("Groups not found.")))
    end

    for group, cnt in RBUtils.SortedPairs(allGroups, function(a, b)
        if sortWay == "asc" then
            return a < b
        else
            return a > b
        end
    end) do
        local selection = self.groupPopup:AddSelectable(group .. " (" .. cnt .. ")")
        if self.excludeGroups[group] then
            selection.SelectableDisabled = true
        end
        if self.selectedGroups[group] then
            selection.Selected = true
        end
        selection.DontClosePopups = true
        selection.AllowItemOverlap = true

        local function ExcludeHandler()
            self.excludeGroups[group] = true
            StyleHelpers.SetAlphaByBool(selection, false)
        end

        local function IncludeHandler()
            self.selectedGroups[group] = true
            selection.Selected = true
        end

        local function unexcludeHandler()
            self.excludeGroups[group] = nil
            StyleHelpers.SetAlphaByBool(selection, true)
        end

        local function unincludeHandler()
            self.selectedGroups[group] = nil
            selection.Selected = false
        end

        selection.OnClick = function()
            selection.Selected = false
            if self.selectedGroups[group] then
                unincludeHandler()
            elseif self.excludeGroups[group] then
                unexcludeHandler()
            else
                IncludeHandler()
            end
            self:Search()
        end

        selection.OnRightClick = function()
            selection.Selected = false
            if self.excludeGroups[group] then
                unexcludeHandler()
            elseif self.selectedGroups[group] then
                unincludeHandler()
            else
                ExcludeHandler()
            end
            self:Search()
        end

        table.insert(self.groupFilterElements, selection)
    end
end

function IconBrowser:Search()
    --Debug("Starting search...")
    if self.tempDisableSearch then
        return
    end

    local now = Ext.Timer.MonotonicTime()

    if not self:CheckIfAnySearchCriteria() then
        --Info("No search criteria provided.")
        self.searchResult = self.searchData
        self:RenderIcons()
        return
    end

    local searchText, noteText, fields = self:GetSearchCriteria()
    local includeTagsArray = {}
    for tag, _ in pairs(self.selectedTags) do
        table.insert(includeTagsArray, tag)
    end
    local excludeTagsArray = {}
    for tag, _ in pairs(self.excludeTags) do
        table.insert(excludeTagsArray, tag)
    end

    local includeGroupsArray = {}
    for group, _ in pairs(self.selectedGroups) do
        table.insert(includeGroupsArray, group)
    end

    local excludeGroupsArray = {}
    for group, _ in pairs(self.excludeGroups) do
        table.insert(excludeGroupsArray, group)
    end

    self.searchResult = self.dataManager:Filter({
        IncludeTags = includeTagsArray,
        ExcludeTags = excludeTagsArray,
        IncludeGroups = includeGroupsArray,
        ExcludeGroups = excludeGroupsArray,
        NoteText = noteText,
        SearchField = fields,
        Keywords = searchText ~= "" and RBStringUtils.SplitBySpace(searchText) or {},
        MatchAllTags = self.matchAllTags
    })

    --Debug("Search completed in " .. tostring(Ext.Timer.MonotonicTime() - now) .. " ms.")
    --Debug("Found " .. CountMap(self.searchResult) .. " matching entries.")
    self:RenderIcons()


end
