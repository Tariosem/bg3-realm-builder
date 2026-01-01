local defaultTexturePath = ""
local renderFolder --[[@type fun(parent: ExtuiTreeParent, path: string[], setter:fun(newValue: FixedString), pathUpdater:fun(newPath: string[])): table<string, ExtuiGroup[]>]]

--- @param parent ExtuiTreeParent
--- @param label string
--- @param icon string
--- @param onclick function
--- @return ExtuiGroup
local function renderPopupItem(parent, label, icon, onclick)
    local group = parent:AddGroup("##" .. label)
    local imgBtn = group:AddImageButton("##" .. label, icon, IMAGESIZE.FRAME)
    StyleHelpers.ApplyBorderlessImageButtonStyle(imgBtn)
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
        local detailPopup = parent:AddPopup("##TextureDetailsPopup" .. guid)
        local stringified = {}
        for field, value in pairs(res) do
            stringified[field] = tostring(value)
        end
        ImguiElements.AddReadOnlyAttrTable(detailPopup, stringified)
        group.OnRightClick = function ()
            detailPopup:Open()
        end
        detailPopup:Open()
    end

    return group, sourceFileName
end

--- @param parent ExtuiTreeParent
--- @param trieNode TextureTrieNode
--- @param currentPath string[]
--- @param pathUpdater fun(newPath: string[])
--- @param allGroups table<string, ExtuiGroup[]>
--- @return integer
local function renderSubFolders(parent, trieNode, currentPath, pathUpdater, allGroups)
    allGroups = allGroups or {}
    local cnt = 0
    for childName, childNode in RBUtils.SortedPairs(trieNode.__children or {}) do
        local newPath = {}
        for _, p in ipairs(currentPath) do
            table.insert(newPath, p)
        end
        table.insert(newPath, childName)
        local group = renderPopupItem(parent, childName, RB_ICONS.Folder_Outline, function()
            pathUpdater(newPath)
        end)
        local lowerName = childName:lower()
        allGroups[lowerName] = allGroups[lowerName] or {}
        table.insert(allGroups[lowerName], group)
        cnt = cnt + 1
    end
    return cnt
end

--- @param parent ExtuiChildWindow
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
        local nextNode = trieNode.__children[p]
        if not nextNode then
            Debug("renderFolder: Invalid path: " .. table.concat(path, "/"))
            break
        end
        trieNode = nextNode
    end

    local childCnt = 0
    --[[if #validPath > 0 then
        renderPopupItem(parent, ".. Data/", RB_ICONS.Folder_Home, function()
            pathUpdater({})
        end)

        local currentPathText = "Back"
        renderPopupItem(parent, ".. " .. currentPathText, RB_ICONS.Folder_Arrow_Left, function()
            local newPath = {}
            for i = 1, #validPath - 1 do
                table.insert(newPath, validPath[i])
            end
            pathUpdater(newPath)
        end)
        childCnt = childCnt + 2
    end]]

    childCnt = childCnt + renderSubFolders(parent, trieNode, validPath, pathUpdater, allGroups)

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

local hoverColor = ColorUtils.HexToRGBA("FFFFBF75")
local normalColor = {1, 1, 1, 1}

--- @param text ExtuiText
local function setupText(text)
    text:SetColor("Text", normalColor)
    text.OnHoverEnter = function ()
        text:SetColor("Text", hoverColor)
    end
    text.OnHoverLeave = function ()
        text:SetColor("Text", normalColor)
    end
end

--- @param parent ExtuiTreeParent
--- @param path string[]
--- @param setter fun(newValue: FixedString)
--- @param pathUpdater fun(newPath: string[])
local function renderFolderTextLink(parent, path, setter, pathUpdater, sameLine)
    local uuid = RBUtils.Uuid_v4()
    local lastPath = path[#path]
    local textLink = parent:AddText(lastPath)
    setupText(textLink)
    if sameLine then
        textLink.SameLine = true
    end

    textLink.OnClick = function()
        local newPath = {}
        for i = 1, #path - 1 do
            table.insert(newPath, path[i])
        end
        pathUpdater(newPath)
    end

    local sepLink = parent:AddButton("/" .. "##SepLink" .. uuid)
    sepLink:SetColor("Text", normalColor)
    sepLink.OnHoverEnter = function ()
        sepLink:SetColor("Text", hoverColor)
    end
    sepLink.OnHoverLeave = function ()
        sepLink:SetColor("Text", normalColor)
    end
    sepLink:SetColor("Button", {0,0,0,0})
    sepLink:SetColor("ButtonHovered", {0,0,0,0})
    sepLink:SetColor("ButtonActive", {0,0,0,0})
    sepLink.SameLine = true

    sepLink.OnClick = function()
        local popup = parent:AddPopup("##Popup" .. uuid)
        popup:SetSizeConstraints({900 * SCALE_FACTOR, 0})
        renderFolder(popup:AddChildWindow("##"), path, setter, pathUpdater)
        sepLink.OnClick = function()
            popup:Open()
        end
        popup:Open()
    end
end

--- @param parent ExtuiTreeParent
--- @param currentPath string[]
--- @param setter fun(newValue: FixedString)
--- @param pathUpdater fun(newPath: string[])
local function renderFolderPath(parent, currentPath, setter, pathUpdater)
    ImguiHelpers.DestroyAllChildren(parent)

    local pathGroup = parent:AddGroup("##TextureFolderPath")
    local suf = #currentPath > 0 and "/" or ""
    local currentPathText = table.concat(currentPath, "/") .. suf

    for i, path in pairs(currentPath) do
        local sameLine = i > 1
        local newPath = {}
        for j = 1, i do
            table.insert(newPath, currentPath[j])
        end
        renderFolderTextLink(pathGroup, newPath, setter, pathUpdater, sameLine)
    end

    local pathInput = parent:AddInputText("##TextureFolderPathInput", "")
    local function getValidPathFromInput()
        local currentText = pathInput.Text
        if not currentText or currentText == "" then
            return currentPath
        end
        local searchTerm = ""
        local path = RBStringUtils.SplitByString(currentText, "/")
        if currentText:sub(-1) ~= "/" then
            searchTerm = path[#path] or ""
            path[#path] = nil
        end
        local validPath = TextureResourceManager:ValidateTextureResourcePath(path)
        return validPath, searchTerm
    end

    pathInput.SameLine = true
    pathInput.SizeHint = { 200 * SCALE_FACTOR, 0 }

    local function enterFocus()
        pathGroup.Visible = false
        pathInput.Text = currentPathText
        pathInput.SizeHint = { 1000 * SCALE_FACTOR, 0 }
    end

    local function leaveFocus()
        pathGroup.Visible = true
        pathInput.Text = ""
        pathInput.SizeHint = { 200 * SCALE_FACTOR, 0 }
    end

    pathInput.OnClick = function()
        enterFocus()

        local confirmKeySub = nil --[[@type RBSubscription?]]

        local function cancelInput()
            if confirmKeySub then
                confirmKeySub:Unsubscribe()
                confirmKeySub = nil
            end
            leaveFocus()
        end

        local function confirmInput()
            leaveFocus()
            local newValidPath = getValidPathFromInput()
            pathUpdater(newValidPath)
        end

        confirmKeySub = InputEvents.SubscribeKeyInput({}, function(e)
            if e.Event == "KeyDown" and e.Key == 'RETURN' then
                pcall(confirmInput)
                return UNSUBSCRIBE_SYMBOL
            elseif e.Event == "KeyDown" and e.Key == 'ESCAPE' then
                pcall(cancelInput)
                return UNSUBSCRIBE_SYMBOL
            end
        end)
        Timer:After(1000, function()
            Timer:EveryFrame(function()
                local ok, focused = pcall(function()
                    return ImguiHelpers.IsFocused(pathInput)
                end)
                if not ok or not focused then
                    pcall(cancelInput)
                    return UNSUBSCRIBE_SYMBOL
                end
            end)
        end)
    end
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
    local initPath = initRes and RBStringUtils.GetPathAfterData(initRes.SourceFile) or defaultTexturePath
    local initPathParts = TextureResourceManager:ValidateTextureResourcePath(RBStringUtils.SplitByString(initPath, "/"))
    local lastValidPath = {}
    local allGroups = {} --[[@type table<string, ExtuiGroup[]>]]
    local popup = parent:AddPopup("EditStringParameterPopup##" .. id)
    local alignedTable = ImguiElements.AddAlignedTable(popup)

    --- @type ExtuiChildWindow
    local folderWindow = nil

    local function checkIfSamePath(newPath)
        if #newPath ~= #lastValidPath then
            return false
        end
        for i, p in ipairs(newPath) do
            if p ~= lastValidPath[i] then
                return false
            end
        end
        return true
    end

    local function updateFolderInput() end
    local function updateFolder() end
    --- @param newPath string[]
    local function pathUpdater(newPath)
        if checkIfSamePath(newPath) then
            return
        end
        lastValidPath = newPath
        updateFolderInput(table.concat(newPath, "/"))
        updateFolder(newPath)
    end
    local function updateSelectedTexture()
    end
    function updateFolderInput(path)
    end

    function updateFolder(path)
        if not folderWindow then
            return
        end
        allGroups = renderFolder(folderWindow, path, function(newValue)
            local res = Ext.Resource.Get(newValue, "Texture") --[[@as ResourceTextureResource]]
            if res then
                setter(newValue)
                updateSelectedTexture()
            end
        end, pathUpdater)
    end

    local currentFileNameInput, jumpToCell = alignedTable:AddInputText("Current Texture", initFileName)
    currentFileNameInput.ReadOnly = true

    local jumpToBtn = jumpToCell:AddButton("<")
    local resetBtn = ImguiElements.AddResetButton(jumpToCell, true)
    resetBtn.OnClick = function()
        setter(initValue)
        updateSelectedTexture()
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
            local validPath = TextureResourceManager:ValidateTextureResourcePath(pathParts)
            pathUpdater(validPath)
        end
    end

    local fodlerPathInput = alignedTable:AddNewLine("Path")
    renderFolderPath(fodlerPathInput, initPathParts, setter, pathUpdater)
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

    function updateFolderInput()
        renderFolderPath(fodlerPathInput, lastValidPath, setter, pathUpdater)
    end

    function updateSelectedTexture()
        local propertyValue = safeGetter()
        local res = Ext.Resource.Get(propertyValue, "Texture") --[[@as ResourceTextureResource]]
        currentFileNameInput.Text = res and RBStringUtils.GetLastPath(res.SourceFile) or "None"
    end

    lastValidPath = initPathParts
    updateFolder(lastValidPath)

    popup:SetSizeConstraints({900 * SCALE_FACTOR, 0}, {1200 * SCALE_FACTOR, 2000 * SCALE_FACTOR})

    return popup
end
