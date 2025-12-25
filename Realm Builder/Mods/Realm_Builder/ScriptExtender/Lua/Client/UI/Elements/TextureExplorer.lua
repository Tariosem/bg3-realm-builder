local defaultTexturePath = ""
local renderFolder --[[@as fun(parent: ExtuiTreeParent, path: string[], setter: fun(newValue: FixedString))]]

--- @param parent ExtuiTreeParent
--- @param label string
--- @param icon string
--- @param onclick function
--- @return ExtuiGroup
local function renderPopupItem(parent, label, icon, onclick)
    local group = parent:AddGroup("##" .. label)
    local imgBtn = group:AddImageButton("##" .. label, icon, IMAGESIZE.FRAME)
    ImguiHelpers.SetupImageButton(imgBtn)
    local selectable = group:AddSelectable(label)
    selectable.DontClosePopups = true
    selectable.SameLine = true
    selectable.Size = { 0, 0 }
    imgBtn.OnClick = function()
        onclick()
    end
    local itemHE = imgBtn.OnHoverEnter
    local itemHL = imgBtn.OnHoverLeave
    imgBtn.OnHoverEnter = function()
        selectable.Highlight = true
        if itemHE then
            itemHE()
        end
    end
    imgBtn.OnHoverLeave = function()
        selectable.Highlight = false
        if itemHL then
            itemHL()
        end
    end

    selectable.OnClick = function()
        selectable.Selected = false
        onclick()
    end
    group.UserData = { Image = imgBtn, Selectable = selectable }
    return group
end


--- @param parent ExtuiTreeParent
--- @param texResource ResourceTextureResource
--- @param setter fun(newValue: FixedString)
local function renderTexResourceItem(parent, texResource, setter)
    local sourceFileName = RBStringUtils.GetLastPath(texResource.SourceFile)
    local guid = texResource.Guid
    local group = renderPopupItem(parent, sourceFileName .. "##" .. guid,
        RB_ICONS.Box, function()
            setter(guid)
        end)
    local imgBtn = group.UserData.Image --[[@as ExtuiImageButton]]
    imgBtn.Tint = { 0.3, 0.7, 0.3, 1 }

    group.OnHoverEnter = function()
        group.UserData.Selectable:Tooltip():AddText(guid)
        group.OnHoverEnter = nil
    end

    group.OnRightClick = function()
        local res = Ext.Resource.Get(guid, "Texture") --[[@as ResourceTextureResource]]
        RainbowDumpTable(res)
    end

    return group, sourceFileName
end

--- @param parent ExtuiTreeParent
--- @param path string[]
--- @param setter fun(newValue: FixedString)
--- @param pathUpdater fun(newPath: string[])
--- @return table<string, ExtuiGroup[]>
function renderFolder(parent, path, setter, pathUpdater)
    ImguiHelpers.DestroyAllChildren(parent)

    local texManager = TextureResourceManager
    local trieNode = texManager.CachedTextureTrie
    local allGroups = {}
    local validPath = texManager:ValidateTextureResourcePath(path)

    for _, p in ipairs(validPath) do
        trieNode = trieNode.__children[p]
        if not trieNode then
            Debug("renderFolder: Invalid path after validation: " .. table.concat(validPath, "/"))
            return {}
        end
    end

    local childCnt = 0
    if #validPath > 0 then
        renderPopupItem(parent, ".. Back To 'Data/'", RB_ICONS.Folder_Home, function()
            pathUpdater({})
        end)

        local currentPathText = table.concat(validPath, "/") .. "/"
        renderPopupItem(parent, ".. " .. currentPathText, RB_ICONS.Folder_Arrow_Left, function()
            local newPath = {}
            for i = 1, #validPath - 1 do
                table.insert(newPath, validPath[i])
            end
            pathUpdater(newPath)
        end)
        childCnt = childCnt + 2
    end

    for childName, childNode in RBUtils.SortedPairs(trieNode.__children or {}) do
        local group = renderPopupItem(parent, childName, RB_ICONS.Folder_Outline, function()
            local newPath = {}
            for _, p in ipairs(validPath) do
                table.insert(newPath, p)
            end
            table.insert(newPath, childName)
            pathUpdater(newPath)
        end)
        local lowerName = childName:lower()
        allGroups[lowerName] = allGroups[lowerName] or {}
        table.insert(allGroups[lowerName], group)
        childCnt = childCnt + 1
    end

    --- @type table<string, ResourceTextureResource[]>
    local sortedRes = {}
    for resourceId, _ in pairs(trieNode.__resources or {}) do
        local res = Ext.Resource.Get(resourceId, "Texture") --[[@as ResourceTextureResource]]
        if res then
            local sourceFileName = RBStringUtils.GetLastPath(res.SourceFile)
            sortedRes[sourceFileName] = sortedRes[sourceFileName] or {}
            table.insert(sortedRes[sourceFileName], res)
        end
    end

    for _, resList in RBUtils.SortedPairs(sortedRes) do
        table.sort(resList, function(a, b)
            return a.Guid < b.Guid
        end)
        for _, res in ipairs(resList) do
            local group, itemName = renderTexResourceItem(parent, res, setter)
            local lowerName = itemName:lower()
            allGroups[lowerName] = allGroups[lowerName] or {}
            table.insert(allGroups[lowerName], group)
            childCnt = childCnt + 1
        end
    end

    local clampMaxHeight = 1000 * SCALE_FACTOR
    local itemHeight = IMAGESIZE.FRAME[2] + 10 * SCALE_FACTOR
    local totalHeight = childCnt * itemHeight + 30 * SCALE_FACTOR
    parent.Size = { 0, math.min(clampMaxHeight, totalHeight) }

    return allGroups
end

--- @param parent ExtuiTreeParent
--- @param getter fun():any
--- @param setter fun(newValue:FixedString)
--- @return ExtuiPopup
function ImguiElements.AddTexturePopup(parent, getter, setter)
    local id = RBUtils.Uuid_v4()
    local safeGetter = function()
        local propertyValue = getter()
        if not RBUtils.IsUuidShape(propertyValue) then
            propertyValue = GUID_NULL
        end
        return propertyValue
    end
    local initValue = safeGetter()
    local initRes = Ext.Resource.Get(initValue, "Texture") --[[@as ResourceTextureResource]]
    if not initRes then
        Debug("ImguiElements.AddTexturePopup: Initial texture resource not found for id " .. tostring(initValue))
    end
    local initFileName = initRes and RBStringUtils.GetLastPath(initRes.SourceFile) or "None"
    local lastValidPath = {}
    local allGroups = {} --[[@type table<string, ExtuiGroup[]>]]
    local popup = parent:AddPopup("EditStringParameterPopup##" .. id)
    local alignedTable = ImguiElements.AddAlignedTable(popup)

    --- @type ExtuiTreeParent
    local folderWindow = nil
    local function updatePresentation()
    end
    local function updateFolder(path)
        if not folderWindow then
            return
        end
        allGroups = renderFolder(folderWindow, path, function(newValue)
            local res = Ext.Resource.Get(newValue, "Texture") --[[@as ResourceTextureResource]]
            if res then
                setter(newValue)
                updatePresentation()
            end
        end, function(newPath)
            lastValidPath = newPath
            updateFolder(newPath)
        end)
    end

    local currentFileNameInput, jumpToCell = alignedTable:AddInputText("Current Texture", initFileName)
    currentFileNameInput.ReadOnly = true

    local jumpToBtn = jumpToCell:AddButton("<")
    local resetBtn = ImguiElements.AddResetButton(jumpToCell, true)
    resetBtn.OnClick = function()
        setter(initValue)
        updatePresentation()
    end
    jumpToBtn:Tooltip():AddText("Jump to folder of current texture")
    jumpToBtn.SameLine = true
    jumpToBtn.OnClick = function()
        local propertyValue = safeGetter()
        local res = Ext.Resource.Get(propertyValue, "Texture") --[[@as ResourceTextureResource]]
        if res then
            local afterData = RBStringUtils.GetPathAfterData(res.SourceFile)
            local pathParts = RBStringUtils.SplitByString(afterData, "/")
            pathParts[#pathParts] = nil -- remove file name
            lastValidPath = pathParts
            updateFolder(pathParts)
        end
    end

    local fodlerPathInput = alignedTable:AddInputText("Folder Path", initRes and
        RBStringUtils.GetPathAfterData(initRes.SourceFile) or defaultTexturePath)
    --local folderPresent = alignedTable:AddNewLine("Folder")
    local folderExplorerCell = alignedTable:AddNewLine("Folder Explorer")
    local folderSearchInput = folderExplorerCell:AddInputText("##TextureFolderSearch")
    folderSearchInput.Hint = "Search..."
    folderSearchInput.OnChange = function()
        local keyWord = folderSearchInput.Text:lower()
        for itemName, groups in pairs(allGroups) do
            if folderSearchInput.Text == "" or itemName:find(keyWord, 1, true) then
                for _, group in ipairs(groups) do
                    group.Visible = true
                end
            else
                for _, group in ipairs(groups) do
                    group.Visible = false
                end
            end
        end
    end
    folderWindow = folderExplorerCell:AddChildWindow("Folder Explorer")



    --- @param pathText string
    --- @return boolean, string[] -- isSamePath, newValidPath
    local function checkIfSamePath(pathText)
        local path = RBStringUtils.SplitByString(pathText, "/")
        if #path == 0 then
            return false, {}
        end
        if pathText:sub(-1) ~= "/" then
            path[#path] = nil
        end
        local validPath = TextureResourceManager:ValidateTextureResourcePath(path)
        if #validPath ~= #lastValidPath then
            return false, validPath
        end
        for i, p in ipairs(validPath) do
            if p ~= lastValidPath[i] then
                return false, validPath
            end
        end
        return true, validPath
    end

    fodlerPathInput.OnChange = function(i)
        local pathText = i.Text
        local same, newValidPath = checkIfSamePath(pathText)
        if same then
            return
        end
        lastValidPath = newValidPath
        updateFolder(lastValidPath)
    end

    function updatePresentation()
        local propertyValue = safeGetter()
        local res = Ext.Resource.Get(propertyValue, "Texture") --[[@as ResourceTextureResource]]
        currentFileNameInput.Text = res and RBStringUtils.GetLastPath(res.SourceFile) or "None"
        fodlerPathInput.Text = res and RBStringUtils.GetPathAfterData(res.SourceFile) or defaultTexturePath
    end

    fodlerPathInput:OnChange()

    return popup
end