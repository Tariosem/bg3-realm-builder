function IconBrowser:GetSearchCriteria()
    local fields = {}
    for field, _ in pairs(self.selectedFields) do
        table.insert(fields, field)
    end
    return tostring(self.searchInput.Text), tostring(self.noteInput.Text), fields
end

function IconBrowser:CandidatesToMap(candidates)
    local result = {}
    for uuid in pairs(candidates) do
        result[uuid] = self.searchData[uuid]
    end
    return result
end

function IconBrowser:ClearNonExistTagsAndGroups()
    for tag, _ in pairs(self.selectedTags) do
        if not self.tagsMap[tag] then
            self.selectedTags[tag] = nil
        end
    end
    for tag, _ in pairs(self.excludeTags) do
        if not self.tagsMap[tag] then
            self.excludeTags[tag] = nil
        end
    end
    for group, _ in pairs(self.selectedGroups) do
        if not self.groupMap[group] then
            self.selectedGroups[group] = nil
        end
    end
    for group, _ in pairs(self.excludeGroups) do
        if not self.groupMap[group] then
            self.excludeGroups[group] = nil
        end
    end
    if next(self.selectedTags) == nil and next(self.excludeTags) == nil and
        next(self.selectedGroups) == nil and next(self.excludeGroups) == nil and self.isVisible then
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

function IconBrowser:SetupTagFilterWindow()
    self.tagsFilter = self.tagsFilter or RegisterWindow("generic", self.displayName, "Tags Filter", self)

    self.tagsFilter.NoResize = true
    self.tagsFilter.NoMove = true

    self.tagsFilter.AlwaysAutoResize = true
    self.tagsFilter.NoTitleBar = true
    self.tagsFilter.Open = false

    return self.tagsFilter
end

-- Abomination
function IconBrowser:AddTagsFilter()
    if self.tagsFilterOpenButton then
        self:RenderTagsFilter()
        return
    end
    self.tagsFilterOpenButton = self.tagsFilterOpenButton or self.topMenuBar:AddMenu("Tags Filter >")

    self.tagsFilterOpenButton.OnHoverEnter = function()
        self:RenderTagsFilter()
        self.tagsFilterOpenButton.OnHoverEnter()
    end
end

function IconBrowser:RenderTagsFilter()
    local allGroups, allTags, groupMap, tagsMap = self.dataManager:CountGroupsAndTags(self.selectedGuid)
    local tagTree = self.dataManager.tagTree

    self.tagsMap = tagsMap
    self.groupMap = groupMap
    self:ClearNonExistTagsAndGroups()
    local sortWay = self.nameAscend and "asc" or "desc"
    local sortedParents = tagTree:SortTreesByDepth(nil, nil, true)
    local collectionCnt = {}
    self.tagRerendered = true

    for _, ele in pairs(self.tagsFilterElements or {}) do
        ele:Destroy()
    end

    self.tagsParentElements = self.tagsParentElements or {}
    self.oldSortedParents = self.oldSortedParents or {}

    --local oldParentDelete = {}
    for i = #self.oldSortedParents or {}, 1, -1 do
        local parent = self.oldSortedParents[i].Key
        --table.insert(oldParentDelete, parent)
        local parentElement = self.tagsParentElements[parent]
        if parentElement then
            local ud = parentElement.UserData
            if ud and ud.Subcriptions then
                for _, sub in pairs(ud.Subcriptions) do
                    if sub and sub.Unsubscribe then
                        sub:Unsubscribe()
                    end
                end
                ud.Subcriptions = nil
            end
            if ud and ud.RenameInput then
                ud.RenameInput:Destroy()
                ud.RenameInput = nil
            end

            self.tagsParentElements[parent] = nil
            parentElement:Destroy()
        end
        ::continue::
    end
    --Debug("Old parent removed order:", table.concat(oldParentDelete, " > "))

    for i = #sortedParents, 1, -1 do
        local parent = sortedParents[i].Key
        local children = tagTree:Find(parent)
        for key, tagOrCol in pairs(children) do
            if type(tagOrCol) == "table" then
                collectionCnt[parent] = (collectionCnt[parent] or 0) + (collectionCnt[key] or 0)
            elseif type(tagOrCol) == "number" then
                collectionCnt[parent] = (collectionCnt[parent] or 0) + tagOrCol
            else
                Warning("[IconsBrowser] Invalid tag or collection count for key: " .. tostring(key) .. ". Skipping.")
            end
        end
    end

    self.tagsFilterElements = {}

    if not self.tagsFilterOpenButton then
        self.tagsFilterOpenButton = self.topMenuBar:AddMenu("Tags Filter >")
    end

    self.tagsFilter = self.tagsFilter or self:SetupTagFilterWindow()

    local keepOpen = self.tagsFilter.Open
    self.tagsFilterOpenButton.OnHoverEnter = function()
        self.tagsFilter.Open = true
        Timer:Ticks(30, function(timerID)
            local panelPos = self.panel.LastPosition
            local filterWidth = self.tagsFilter.LastSize and self.tagsFilter.LastSize[1] or 500 * SCALE_FACTOR
            local pos = { panelPos[1] - filterWidth, panelPos[2] }
            self.tagsFilter:SetPos(pos)
        end)
    end
    self.tagsFilterOpenButton.OnHoverLeave = function()
        if not keepOpen then
            self.tagsFilter.Open = false
        end
    end
    self.tagsFilterOpenButton.OnClick = function()
        keepOpen = not keepOpen
        self.tagsFilter.Open = keepOpen
        FocusWindow(self.tagsFilter)
    end

    self.panel.OnClose = function()
        keepOpen = false
        self.tagsFilter.Open = false
    end

    self.tagsPopup = self.tagsFilter
    local topTable, leftCe, rightCe = self.tagsFilterTopTable, nil, nil
    if not topTable then
        topTable, leftCe, rightCe = AddTwoColTable(self.tagsPopup, "TagsTopTable")
        self.tagsFilterTopTable = topTable
    end
    if not topTable.UserData then
        --- @diagnostic disable-next-line
        local undoAllIncBtn = leftCe:AddSelectable(GetLoca("Uninclude All"))
        --- @diagnostic disable-next-line
        local undoAllExcBtn = rightCe:AddSelectable(GetLoca("Unexclude All"))
        undoAllIncBtn.DontClosePopups = true
        undoAllIncBtn:SetStyle("SelectableTextAlign", 0.5)
        undoAllExcBtn:SetStyle("SelectableTextAlign", 0.5)
        undoAllExcBtn.DontClosePopups = true
        topTable.UserData = {
            UndoIncludeAllButton = undoAllIncBtn,
            UndoExcludeAllButton = undoAllExcBtn
        }
    end

    local preassignedParent = {}
    self.tagsParentElements = {}

    local uninclFuncs = {}
    local unexclFuncs = {}
    local inclFuncs = {}
    local exclFuncs = {}
    local tagToParent = {}
    local tagRenderOrder = {}

    self.oldSortedParents = sortedParents
    --local parentRenderOrder = {}
    for _, pair in ipairs(sortedParents) do
        local parent = pair.Key
        --table.insert(parentRenderOrder, parent)
        local children = tagTree:Find(parent)
        local parentUiElement = preassignedParent[parent] or self.tagsPopup
        if type(parent) ~= "string" then
            Warning("[IconsBrowser] Invalid tag parent: " .. tostring(parent) .. ". Skipping.")
            goto continue
        end

        if type(children) ~= "table" then
            Warning("[IconsBrowser] Invalid children for parent: " .. tostring(parent) .. ". Skipping.")
            goto continue
        end
        if next(children) == nil then
            goto continue
        end
        if self.dataManager.tagIcons[parent] then
            local tempimage = parentUiElement:AddImage(self.dataManager.tagIcons[parent], ToVec2(38 * SCALE_FACTOR))
            table.insert(self.tagsFilterElements, tempimage)
        end
        local allCnt = collectionCnt[parent] or 0
        local parentMenu = parentUiElement:AddMenu(parent .. " (" .. allCnt .. ") >")
        local changeNamePopup = parentMenu:AddPopup("ChangeParentNamePopup")
        local renameInput = changeNamePopup:AddInputText("")
        renameInput.Text = parent
        renameInput.IDContext = "RenameInput"
        renameInput:Tooltip():AddText(GetLoca("Press ENTER to confirm"))
        parentMenu.UserData = parentMenu.UserData or {}
        parentMenu.UserData.RenameInput = renameInput
        parentMenu.UserData.Subcriptions = {}

        local function updateParentName(newName)
            local success = true
            if newName and newName ~= parent and newName ~= "" and not allTags[newName] then
                success = tagTree:Rename(parent, newName)
            elseif newName == "" then
                tagTree:RemoveButKeepChildren(parent)
            elseif newName == parent then
                return -- no change
            else
                success = false
            end
            if not success then
                ConfirmPopup:Popup(GetLoca("Invalid name, try another one."))
                return
            end
            self:AddTagsFilter()
            self:SaveTagHierarchy()
        end

        renameInput.OnRightClick = function()
            if renameInput.Text == parent then
                return
            end

            updateParentName(renameInput.Text)
        end

        local function openPopup()
            changeNamePopup:Open()

            parentMenu.UserData.Subcriptions.KeySub = SubscribeKeyInput({ Key = "RETURN" }, function()
                if self.tagsParentElements[parent] == nil then return UNSUBSCRIBE_SYMBOL end
                local liveParent = self.tagsParentElements[parent]
                local liveInput = liveParent.UserData and liveParent.UserData.RenameInput

                if IsFocused(liveInput) then
                    updateParentName(liveInput.Text)
                end
            end)
        end

        parentMenu.CanDrag = true
        parentMenu.UserData.TagCollection = parent
        parentMenu.OnRightClick = openPopup
        parentMenu.DragDropType = "TagCollection"

        local function menuDragDropSingle(menu, drop)
            local data = drop.UserData

            if data and data.Tag then
                tagTree:ForceAddLeaf(data.Tag, allTags[data.Tag], parent)
                self:AddTagsFilter()
                self:SaveTagHierarchy()
            end
        end

        parentMenu.OnDragDrop = menuDragDropSingle

        self.tagsParentElements[parent] = parentMenu
        parentMenu.SameLine = self.dataManager.tagIcons[parent] ~= nil

        for key, tags in pairs(children) do
            tagToParent[key] = parent
            preassignedParent[key] = parentMenu
        end

        parentMenu.UserData.Subcriptions.ShiftModSub = SubscribeKeyInput({ Key = "LSHIFT" }, function(e)
            if self.tagsParentElements[parent] == nil or not parentMenu then return UNSUBSCRIBE_SYMBOL end
            local liveParent = self.tagsParentElements[parent]

            if e.Event == "KeyDown" then
                local function processTags(children, actionMap)
                    for tag, cont in pairs(children) do
                        if type(cont) ~= "table" then
                            local cond = actionMap.string
                            if cond then cond(tag) end
                        else
                            processTags(cont, actionMap)
                        end
                    end
                end

                liveParent.OnClick = function()
                    self.tempDisableSearch = true
                    processTags(children, {
                        string = function(tag)
                            if not self.selectedTags[tag] and not self.excludeTags[tag] and inclFuncs[tag] then
                                inclFuncs[tag]()
                            elseif self.selectedTags[tag] and uninclFuncs[tag] then
                                uninclFuncs[tag]()
                            end
                        end
                    })
                    self.tempDisableSearch = false
                    self:Search()
                end

                liveParent.OnRightClick = function()
                    self.tempDisableSearch = true
                    processTags(children, {
                        string = function(tag)
                            if not self.excludeTags[tag] and not self.selectedTags[tag] and exclFuncs[tag] then
                                exclFuncs[tag]()
                            elseif self.excludeTags[tag] and unexclFuncs[tag] then
                                unexclFuncs[tag]()
                            end
                        end
                    })
                    self.tempDisableSearch = false
                    self:Search()
                end
            elseif e.Event == "KeyUp" then
                liveParent.OnClick = nil
                liveParent.OnRightClick = openPopup
            end
        end)

        ::continue::
    end
    --Debug("Tag parents render order:", table.concat(parentRenderOrder, " > "))

    self.tagsPopup.DragDropType = "TagCollection"
    self.tagsPopup.OnDragDrop = function(menu, drop)
        local data = drop.UserData

        if data and data.Tag then
            tagTree:ForceAddLeaf(data.Tag, allTags[data.Tag])
            self:AddTagsFilter()
            self:SaveTagHierarchy()
        end
    end

    for currentTag, currentCnt in SortedPairs(allTags, function(a, b)
        if sortWay == "asc" then
            return a < b
        else
            return a > b
        end
    end) do
        local tagArea = preassignedParent[currentTag] or self.tagsPopup
        table.insert(tagRenderOrder, currentTag)
        local parent = tagToParent[currentTag]
        if parent then
            collectionCnt[parent] = (collectionCnt[parent] or 0) + currentCnt
        end

        local hasIcon = self.dataManager.tagIcons[currentTag] ~= nil
        local tagIcon = nil
        if hasIcon then
            --- @type ExtuiImageButton
            tagIcon = tagArea:AddImageButton(currentTag .. "IconButton", self.dataManager.tagIcons[currentTag],
                ToVec2(38 * SCALE_FACTOR))
            table.insert(self.tagsFilterElements, tagIcon)
        end

        local selection = tagArea:AddSelectable(currentTag .. " (" .. currentCnt .. ")")

        selection.CanDrag = true
        selection.DragDropType = "TagCollection"
        selection.UserData = { Tag = currentTag }

        selection.OnDragStart = function(sel)
            if hasIcon then
                sel.DragPreview:AddImage(self.dataManager.tagIcons[currentTag], ToVec2(38 * SCALE_FACTOR))
            end
            sel.DragPreview:AddText(currentTag .. " (" .. currentCnt .. ")").SameLine = hasIcon
        end

        selection.OnDragDrop = function(sel, drop)
            local data = drop.UserData
            if data and data.Tag then
                tagTree:ForceAddTree("New Collection", parent)

                local depth = tagTree:GetDepth("New Collection")
                --Debug("New Collection depth:", depth)
                if depth > 2 then
                    Warning("[IconsBrowser] Cannot create collection deeper than 2 level. Operation cancelled.")
                    ConfirmPopup:Popup("That's too deep")
                    tagTree:Remove("New Collection")
                    return
                end

                tagTree:ForceAddLeaf(data.Tag, allTags[data.Tag], "New Collection")
                tagTree:ForceAddLeaf(currentTag, allTags[currentTag], "New Collection")
                self:AddTagsFilter()
                self:SaveTagHierarchy()
            end
        end

        if hasIcon then
            tagIcon.OnHoverEnter = function()
                selection.Highlight = true
            end
            tagIcon.OnHoverLeave = function()
                selection.Highlight = false
            end
        end

        selection.SameLine = hasIcon
        if self.excludeTags[currentTag] then
            SetAlphaByBool(selection, false)
            if tagIcon then
                tagIcon.Tint = { 1, 1, 1, 0.5 }
                tagIcon.Disabled = true
            end
        end
        if self.selectedTags[currentTag] then
            selection.Selected = true
        end

        if self.dataManager.dynamicTags and self.dataManager.dynamicTags[currentTag] then
            selection:Tooltip():AddText(self.dataManager.dynamicTags[currentTag]).TextWrapPos = self.browserWidth
            if hasIcon and tagIcon then
                tagIcon:Tooltip():AddText(self.dataManager.dynamicTags[currentTag]).TextWrapPos = self.browserWidth
            end
        end

        selection.DontClosePopups = true
        selection.AllowItemOverlap = true

        local excludeHandler = function()
            self.excludeTags[currentTag] = true
            SetAlphaByBool(selection, false)
            if tagIcon then
                tagIcon.Tint = { 1, 1, 1, 0.5 }
            end
        end

        local includeHandler = function()
            self.selectedTags[currentTag] = true
            if tagIcon then
                tagIcon.Tint = { 1, 1, 1, 1 }
            end
            selection.Selected = true
        end

        local unexcludeHandler = function()
            self.excludeTags[currentTag] = nil
            SetAlphaByBool(selection, true)
            if tagIcon then
                tagIcon.Tint = { 1, 1, 1, 1 }
            end
        end

        local unincludeHandler = function()
            self.selectedTags[currentTag] = nil

            selection.Selected = false
        end

        selection.OnClick = function()
            selection.Selected = false
            if self.selectedTags[currentTag] then
                unincludeHandler()
            elseif self.excludeTags[currentTag] then
                unexcludeHandler()
            else
                includeHandler()
            end

            self:Search()
        end

        selection.OnRightClick = function()
            selection.Selected = false
            if self.excludeTags[currentTag] then
                unexcludeHandler()
            elseif self.selectedTags[currentTag] then
                unincludeHandler()
            else
                excludeHandler()
            end
            self:Search()
        end

        if tagIcon then
            tagIcon.OnClick = selection.OnClick
            tagIcon.OnRightClick = selection.OnRightClick
        end

        if self.selectedTags[currentTag] then
            selection.OnRightClick = nil
            if tagIcon then
                tagIcon.OnRightClick = nil
            end
        end

        table.insert(self.tagsFilterElements, selection)

        unexclFuncs[currentTag] = unexcludeHandler
        uninclFuncs[currentTag] = unincludeHandler
        inclFuncs[currentTag] = includeHandler
        exclFuncs[currentTag] = excludeHandler
    end

    topTable.UserData.UndoIncludeAllButton.OnClick = function(btn)
        self.tempDisableSearch = true
        for tag, _ in pairs(self.selectedTags) do
            if uninclFuncs[tag] then
                uninclFuncs[tag]()
            end
        end
        self.tempDisableSearch = false
        self:Search()
        btn.Selected = false
    end

    topTable.UserData.UndoExcludeAllButton.OnClick = function(btn)
        self.tempDisableSearch = true
        for tag, _ in pairs(self.excludeTags) do
            if unexclFuncs[tag] then
                unexclFuncs[tag]()
            end
        end
        self.tempDisableSearch = false
        self:Search()
        btn.Selected = false
    end
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

    for group, cnt in SortedPairs(allGroups, function(a, b)
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
            SetAlphaByBool(selection, false)
        end

        local function IncludeHandler()
            self.selectedGroups[group] = true
            selection.Selected = true
        end

        local function unexcludeHandler()
            self.excludeGroups[group] = nil
            SetAlphaByBool(selection, true)
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
        Keywords = searchText ~= "" and SplitBySpace(searchText) or {},
        MatchAllTags = self.matchAllTags
    })

    --Debug("Search completed in " .. tostring(Ext.Timer.MonotonicTime() - now) .. " ms.")
    --Debug("Found " .. CountMap(self.searchResult) .. " matching entries.")
    self:RenderIcons()
end
