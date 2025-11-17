--- pure spaghetti code ahead, beware ---

--- @class IconBrowser
--- @field panel ExtuiWindow
--- @field browser ExtuiChildWindow
--- @field browserOptions ExtuiTable
--- @field dataManager ManagerBase
--- @field iconsImage table<string, ExtuiImageButton|ExtuiStyledRenderable>
--- @field CreateCachedSort fun(self:IconBrowser, field:string)
IconBrowser = _Class("IconBrowser")

--- @class IconsBrowser
function IconBrowser:__init(dataManager, DisplayName)
    local screenWidth, screenHeight = GetScreenSize()
    self.displayName = DisplayName or "Icons"
    self.dataManager = dataManager
    self.searchData = dataManager.Data or {}
    self.searchResult = self.searchData
    self.selectedGroups = {}
    self.selectedTags = {}
    self.selectedFields = { DisplayName = true, TemplateName = true }
    self.excludeTags = {}   -- { UnknownIcon = true, Timeline = true }
    self.excludeGroups = {} -- { Blacklist = true }
    self.iconTooltipName = "DisplayName"
    self.iconButtonBgColor = CONFIG.ItemBrowser.ButtonBgColor or nil
    self.iconToName = false

    self.matchAllTags = true
    self.nameAscend = true

    self.tempDisableSearch = false

    local config = self.GetConfig and self:GetConfig() or {}

    self.iconButtonBgColor = config and config.ButtonBgColor or nil
    self.iconWidth = config and config.IconWidth or 75 * SCALE_FACTOR
    self.iconPC = config and config.IconPerColumn or 10
    self.iconPR = config and config.IconPerRow or 10
    self.cellsPadding = config and config.CellsPadding or { 10 * SCALE_FACTOR, 10 * SCALE_FACTOR }
    self.browserWidth = self.iconPR * self.iconWidth + 20
    self.browserHeight = self.iconPC * self.iconWidth + 20 + 240 * SCALE_FACTOR
    self.lastPosition = config.LastPosition or { screenWidth * 0.6, screenHeight * 0.15 }
    self.lastSize = config.LastSize or { self.browserWidth * 1.5, self.browserHeight * 1.5 }

    self.selectedGuid = nil

    self.autoSave = not (config and config.autoSave == false)

    self.updateTagsFn = {}
    self.isValid = true

    if self.SubclassInit then
        self:SubclassInit()
    end

    self:LoadChanges()
end

function IconBrowser:Render()
    self.panel = RegisterWindow("generic", self.displayName, "Browser", self, self.lastPosition, self.lastSize)
    self.panel.Closeable = true

    self.browserOptions = self.panel:AddTable("Icons Browser", 6)
    
    self.topMenuBar = self.panel:AddMainMenu()
    self.editMenu = self.topMenuBar:AddMenu("File")
    self.uiParamMenu = self.topMenuBar:AddMenu("UI")
    
    self:RenderFileMenu()
    self:RenderUiConfigMenu()
    self:RenderSearchOptionsMenu()
    self:RenderMiscMenu()
    self:RenderBrowserBase()
    
    self.isVisible = true

    self:SetupInputSubs()
end

function IconBrowser:SetupInputSubs()
    --- @param e EclLuaKeyInputEvent
    local pageKeyHandle = function(e)
        if not self.isValid then return UNSUBSCRIBE_SYMBOL end

        if self.panel.Open == false then return end

        if e.Key == "COMMA" and e.Pressed then
            if self.currentPage > 1 then
                self:SetPage(self.currentPage - 1)
            end
        elseif e.Key == "PERIOD" and e.Pressed then
            if self.currentPage < self.allPages then
                self:SetPage(self.currentPage + 1)
            end
        end
    end

    self.pageKeySub = SubscribeKeyInput({}, function(e)
        return pageKeyHandle(e)
    end)

    self.quickFavoriteKeySub = SubscribeKeyInput({ Key = "F" }, function(e)
        if not self.isValid then return UNSUBSCRIBE_SYMBOL end

        if self.panel.Open == false then return end

        local tag = "Favorite"

        if e.Pressed and self.hoveredEntry then
            local entry = self.searchData[self.hoveredEntry]
            if entry then
                self.dataManager:AddTagToData(entry.Uuid, tag)
                if self.updateTagsFn[entry.Uuid] then
                    self.updateTagsFn[entry.Uuid]()
                end
                self:AddTagsFilter()
            end
        end
    end)


    self.toUnSubOnDestroy = {
        self.pageKeySub,
        self.quickFavoriteKeySub,
        self.turnPageWheelSub,
    }
end

function IconBrowser:RenderFileMenu()
    self.editMenu:Tooltip():AddText(GetLoca("Save custom tags, groups, and notes."))
    self.fileSave = self.editMenu:AddItem(GetLoca("Save"))
    self.fileLoad = self.editMenu:AddItem(GetLoca("Load"))
    self.fileAutoSave = self.editMenu:AddItem("Auto Save" .. (self.autoSave and " (On)" or " (Off)"))

    self.fileSave.OnClick = function()
        self:SaveChanges()
    end

    self.fileLoad.OnClick = function()
        self:LoadChanges()
    end

    SetAlphaByBool(self.fileAutoSave, self.autoSave)

    self.fileAutoSave.OnClick = function()
        self.autoSave = not self.autoSave
        SetAlphaByBool(self.fileAutoSave, self.autoSave)
        local config = self.GetConfig and self:GetConfig() or {}
        config.autoSave = self.autoSave
        self.fileAutoSave.Label = GetLoca("Auto Save") .. (self.autoSave and " (On)" or " (Off)")
        self:SaveToConfig()
    end
end

function IconBrowser:RenderUiConfigMenu()
    local imagePerCol = self.iconPC
    local imagePerRow = self.iconPR
    local cellsPadding = self.cellsPadding
    local iconWidth = self.iconWidth
    self.saveToConfig = self.uiParamMenu:AddButton(GetLoca("Save To Config"))
    local iconSizeSlider = SafeAddSliderInt(self.uiParamMenu, GetLoca("Image Size"), iconWidth, 20, 200)
    local browserWidthSlider = SafeAddSliderInt(self.uiParamMenu, GetLoca("Image Per Row"), imagePerRow, 2, 20)
    local browserHeightSlider = SafeAddSliderInt(self.uiParamMenu, GetLoca("Image Per Column"), imagePerCol, 4, 30)
    local cellsPaddingSlider = SafeAddSliderInt(self.uiParamMenu, GetLoca("Image Padding"), cellsPadding[1], 0, 20)
    cellsPaddingSlider.Components = 2
    cellsPaddingSlider.Value = ToVec4Int(cellsPadding[1], cellsPadding[2])
    local iconButtonBgColroEdit = self.uiParamMenu:AddColorEdit(GetLoca("Button Background Color"))
    iconButtonBgColroEdit.Color = self.iconButtonBgColor or { 0, 0, 0, 0.6 }

    local function getEstimatedTopBarHeight()
        local panelHeight = self.panel.LastSize[2]
        local iconsHeight = self.iconsWindow and self.iconsWindow.LastSize[2] or 300 * SCALE_FACTOR
        return panelHeight - iconsHeight == 0 and 240 * SCALE_FACTOR or panelHeight - iconsHeight
    end

    self.saveToConfig.OnClick = function()
        self.lastPosition = self.panel.LastPosition
        self.lastSize = self.panel.LastSize
        self:SaveToConfig()
    end

    iconSizeSlider.OnChange = function(value)
        self.iconWidth = value.Value[1]
        local iconWidth = self.iconWidth
        if iconWidth < 20 then
            iconWidth = 20
        end
        for _, imageIcon in pairs(self.iconsImage) do
            if self.iconToName then break end
            imageIcon.Image.Size = { iconWidth, iconWidth }
        end
    end

    browserWidthSlider.OnChange = function(value)
        local ImagePerLine = value.Value[1]
        if ImagePerLine < 1 then
            ImagePerLine = 1
        end
        ImagePerLine = math.floor(ImagePerLine)
        self.iconPR = ImagePerLine
        local browserWidth = ImagePerLine * ( self.iconWidth + self.cellsPadding[1] ) + 20 * SCALE_FACTOR
        self.browserWidth = browserWidth

        self.panel:SetSize({ browserWidth * 1.2, self.browserHeight * 1.2 })

        self.iconsContainer.Columns = ImagePerLine
        self:SetPage(1)
    end

    browserHeightSlider.OnChange = function(value)
        local ImagePerColumn = value.Value[1]
        if ImagePerColumn < 1 then
            ImagePerColumn = 1
        end
        self.iconPC = ImagePerColumn
        if self.iconToName then
            self.browserHeight = self.iconPC * (48 * SCALE_FACTOR + self.cellsPadding[2]) + 40 * SCALE_FACTOR + getEstimatedTopBarHeight()
        else
            self.browserHeight = self.iconPC * (self.iconWidth + self.cellsPadding[2]) + 40 * SCALE_FACTOR + getEstimatedTopBarHeight()
        end
        self.panel:SetSize({ self.browserWidth * 1.2, self.browserHeight * 1.2 })
        self:SetPage(1)
    end

    cellsPaddingSlider.OnChange = function(value)
        local sliderValue = value.Value
        self.cellsPadding = { sliderValue[1], sliderValue[2] }
        self.iconsContainer:SetStyle("CellPadding", self.cellsPadding[1], self.cellsPadding[2])
    end

    iconButtonBgColroEdit.OnChange = function(color)
        self.iconButtonBgColor = color.Color
        if not self.iconToName then
            for _, imageIcon in pairs(self.iconsImage) do
                imageIcon.Background = self.iconButtonBgColor
            end
        else
            for _, buttonIcon in pairs(self.iconsImage) do
                buttonIcon:SetColor("Button", self.iconButtonBgColor)
            end
        end
    end
end

function IconBrowser:RenderSearchOptionsMenu()
    self.browserOptions.ColumnDefs[1] = { WidthStretch = false, WidthFixed = true }
    self.browserOptions.ColumnDefs[2] = { WidthStretch = false, WidthFixed = true }
    self.browserOptions.ColumnDefs[3] = { WidthStretch = true }
    self.browserOptions.ColumnDefs[4] = { WidthStretch = true }
    self.browserOptions.ColumnDefs[5] = { WidthStretch = false, WidthFixed = true }
    self.browserOptions.ColumnDefs[6] = { WidthStretch = false, WidthFixed = true }

    self.optionRow = self.browserOptions:AddRow()

    self.searchInputContainer = self.optionRow:AddCell()
    self.searchInput = self.searchInputContainer:AddInputText("")
    self.searchInput.IDContext = "IconSearchInput"
    self.searchInputContainer:AddText("Keywords").SameLine = true

    self.searchInputContainer:Tooltip():AddText(GetLoca("Right-click to select search fields"))

    self.searchPopup = self.searchInputContainer:AddPopup("SearchPopup")

    self.searchInputContainer.OnRightClick = function()
        self.searchPopup:Open()
    end

    self.searchPopup:AddText(GetLoca("Search by:"))

    local skip = {
        Tags = true,
        Group = true,
        Note = true,
        SourceBones = true,
        TargetBones = true,
        SourceBone = true,
        TargetBone = true,
    }

    local fields = {}
    local firstEntry = next(self.searchData)
    if firstEntry then
        for field, value in pairs(self.searchData[firstEntry]) do
            if not skip[field] and type(value) == "string" then
                table.insert(fields, field)
            end
        end
    end

    table.sort(fields, function(a, b)
        if a == "DisplayName" then
            return true
        elseif b == "DisplayName" then
            return false
        end
        if self.nameAscend then
            return a < b
        else
            return a > b
        end
    end)

    for _, field in ipairs(fields) do
        local selection = self.searchPopup:AddSelectable(field)
        selection.Selected = self.selectedFields[field] or false
        selection.DontClosePopups = true
        selection.OnClick = function()
            if self.selectedFields[field] then
                self.selectedFields[field] = nil
            else
                self.selectedFields[field] = true
            end
        end
    end

    self.noteInputContainer = self.optionRow:AddCell()
    self.noteInput = self.noteInputContainer:AddInputText("")
    self.noteInput.IDContext = "IconNoteInput"
    self.noteInputContainer:AddText("Note").SameLine = true

    self.tagsFilterContainer = self.optionRow:AddCell()

    self:AddTagsFilter()

    self.groupFilterContainer = self.optionRow:AddCell()

    self:AddGroupFilter()

    self.searchButtonContainer = self.optionRow:AddCell()

    self.searchButton = self.searchButtonContainer:AddButton(GetLoca("Search"))
    ApplyConfirmButtonStyle(self.searchButton)
    self.searchButton.OnClick = function()
        self:Search()
    end

    local debounceTimer = nil

    local AutoSearch = function()
        if debounceTimer then
            Timer:Cancel(debounceTimer)
            debounceTimer = nil
        end

        debounceTimer = Timer:After(50, function()
            self:Search()
        end)
    end

    self.noteInput.OnChange = function()
        AutoSearch()
    end
    self.searchInput.OnChange = function()
        AutoSearch()
    end
    ---#endregion Search Options
end

function IconBrowser:RenderMiscMenu()

    self.miscButtonContainer = self.optionRow:AddCell()


    self.miscSearchButton = self.topMenuBar:AddMenu(GetLoca("Misc"))
    self.miscPopup = self.miscSearchButton

    self.nameAscendSelect = self.miscPopup:AddItem(GetLoca("Name Ascend"))
    self.combineSearchSelect = self.miscPopup:AddItem(GetLoca("Match Any Tags"))
    self.tooltipName = self.miscPopup:AddItem(GetLoca("Tooltip Name: DisplayName"))
    local iconToNameButton = self.miscPopup:AddItem(GetLoca("Icon to Name"))

    self.nameAscendSelect.Label = self.nameAscend and GetLoca("Name Ascend") or
    GetLoca("Name Descend")

    self.nameAscendSelect.OnClick = function()
        self.nameAscend = not self.nameAscend
        self.nameAscendSelect.Label = self.nameAscend and GetLoca("Name Ascend") or
        GetLoca("Name Descend")
        self:RenderIcons()
    end


    self.combineSearchSelect.Label = self.matchAllTags and GetLoca("Match All Tags") or GetLoca("Match Any Tags")

    self.combineSearchSelect.OnClick = function()
        self.matchAllTags = not self.matchAllTags
        self.combineSearchSelect.Label = self.matchAllTags and GetLoca("Match All Tags") or GetLoca("Match Any Tags")
        self:Search()
    end

    self.tooltipName.OnClick = function()
        self:TooltipChangeLogic()
        self:RenderIcons()
    end

    local function updateIconToNameText()
        local base = GetLoca("Icon to Name")
        if self.iconToName then
            return base .. " "
        else
            return base .. " (X)"
        end
    end

    local iconPRBefore = self.iconPR

    iconToNameButton.Label = updateIconToNameText()
    iconToNameButton.OnClick = function()
        self.iconToName = not self.iconToName
        iconToNameButton.Label = updateIconToNameText()
        if self.iconToName then 
            iconPRBefore = self.iconPR
            self.iconPR = 1
        else
            self.iconPR = iconPRBefore
        end

        self:RenderPage()
    end
end

function IconBrowser:RenderBrowserBase()
    self.browser = self.panel:AddChildWindow("Browser")

    self.pageTopTable = self.browser:AddTable("IconsBrowserTable", 2)

    self.pageTopTable.ColumnDefs[1] = { WidthStretch = true }
    self.pageTopTable.ColumnDefs[2] = { WidthFixed = true }

    local pageButtonsRow = self.pageTopTable:AddRow()

    local browserComboCell = pageButtonsRow:AddCell()
    local browserCombo = NearbyCombo.new(browserComboCell)
    self.browserCombo = browserCombo -- TODO NearbyCombo

    browserCombo.ExcludeCamera = true
    browserCombo.SameLine = true
    browserCombo.OnChange = function (sel, guid, displayName)
        self.selectedGuid = guid
        self:AddTagsFilter()
    end
    
    local pageButtonsContainer = pageButtonsRow:AddCell()

    self.firstButton = pageButtonsContainer:AddButton("<<")
    self.previousButton = pageButtonsContainer:AddButton("<")
    self.pageInput = pageButtonsContainer:AddInputInt("")
    local justAText = pageButtonsContainer:AddText(" / ")
    justAText.SameLine = true
    self.allPageInput = pageButtonsContainer:AddInputInt("")
    self.nextButton = pageButtonsContainer:AddButton(">")
    self.lastButton = pageButtonsContainer:AddButton(">>")

    self.iconsBrowser = self.browser:AddChildWindow("Icons Browser")

    self:Search()
end

function IconBrowser:TooltipChangeLogic()
    if self.iconTooltipName == "DisplayName" then
        self.iconTooltipName = "TemplateName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Template Name")
    elseif self.iconTooltipName == "TemplateName" then
        self.iconTooltipName = "DisplayName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Display Name")
    end
end

function IconBrowser:CreateCachedSort(field)
    local now = Ext.Timer.MonotonicTime()
    local cacheFiled = "__SortCache_" .. field
    local cnt = 0
    local sortKeyArray = {}
    for uuid, entry in pairs(self.searchData) do
    cnt = cnt + 1
    local value = entry[field] or "Unknown"
        sortKeyArray[cnt] = {uuid, value}
    end

    table.sort(sortKeyArray, function(a, b)
        if a[2] == b[2] then
            return a[1] < b[1]
        else
            return a[2] < b[2]
        end

    end)

    self[cacheFiled] = sortKeyArray

    for k,v in pairs(self[cacheFiled]) do
        local entry = self.searchData[v[1]]
        if not entry.Uuid then
            self[cacheFiled][k] = nil
            Error("[IconsBrowser] Removed invalid entry from sort cache: " .. tostring(v[1]))
        end
    end

    --Info("[IconsBrowser] Cached sort for field '" .. field .. "' with " .. tostring(cnt) .. " entries in " .. tostring(Ext.Timer.MonotonicTime() - now) .. " ms.")
end

function IconBrowser:RenderIcons()
    --Debug("Called RenderIcons")
    self.uuidsSorted = {}

    local sortCacheKey = self.iconTooltipName and ("__SortCache_" .. self.iconTooltipName)
    if not self[sortCacheKey] then
        self:CreateCachedSort(self.iconTooltipName)
    end
    local sortCache = self[sortCacheKey]
    local from = self.nameAscend and 1 or #sortCache
    local to = self.nameAscend and #sortCache or 1
    local step = self.nameAscend and 1 or -1

    local now = Ext.Timer.MonotonicTime()
    local result = {}
    local idx = 0
    for i = from, to, step do
        local uuid = sortCache[i][1]
        if self.searchResult[uuid] then
            idx = idx + 1
            result[idx] = uuid
        end
    end
    self.uuidsSorted = result
    --Info("[IconsBrowser] Sorted " .. tostring(#self.uuidsSorted) .. " entries in " .. tostring(Ext.Timer.MonotonicTime() - now) .. " ms.")
    -- Debug for icons

    self:UpdatePageCnt()

    self.iconsImage = self.iconsImage or {}
    self.updateTagsFn = {}

    self.currentPage = math.floor(self.currentPage or 1)
    self.allPages = math.floor(self.allPages or 1)

    self.pageInput.IDContext = "PageInput"
    self.pageInput.ItemWidth = 75 * SCALE_FACTOR
    self.pageInput.Value = ToVec4Int(self.currentPage)

    self.allPageInput.IDContext = "AllPageInput"
    self.allPageInput.ItemWidth = 75 * SCALE_FACTOR
    self.allPageInput.ReadOnly = true
    self.allPageInput.Value = ToVec4Int(self.allPages)

    self.previousButton.SameLine = true
    self.pageInput.SameLine = true
    self.allPageInput.SameLine = true
    self.nextButton.SameLine = true
    self.lastButton.SameLine = true

    self:RenderPage()

    self.firstButton.OnClick = function()
        self:SetPage(1)
    end

    self.nextButton.OnClick = function()
        if self.currentPage < self.allPages then
            self:SetPage(self.currentPage + 1)
        end
    end

    self.pageInput.OnChange = function(text)
        local page = tonumber(text.Text)
        if page and page >= 1 and page <= self.allPages then
            self:SetPage(page)
        elseif page and page < 1 then
            self:SetPage(1)
            text.Value = ToVec4Int(1)
        elseif page and page > self.allPages then
            self:SetPage(self.allPages)
            text.Value = ToVec4Int(self.allPages)
        end
    end

    self.pageInput.OnRightClick = function(text)
        text.Text = tostring(self.currentPage):gsub("%.0+$", "")
    end

    self.previousButton.OnClick = function()
        if self.currentPage > 1 then
            self:SetPage(self.currentPage - 1)
        end
    end

    self.lastButton.OnClick = function()
        self:SetPage(self.allPages)
    end
end

function IconBrowser:UpdatePageCnt()
    local oldIconsCnt = self.iconsCnt or 0
    local oldCurrentPage = self.currentPage or 1

    self.imagePerPage = self.iconPR * self.iconPC
    self.iconsCnt = #self.uuidsSorted
    local div = self.iconsCnt / self.imagePerPage
    self.allPages = math.floor(div + 0.9999999)

    --Debug("Icons count: " .. tostring(self.iconsCnt) .. ", Image per page: " .. tostring(self.imagePerPage) .. ", All pages: " .. tostring(self.allPages))

    if self.allPages < 1 then
        self.allPages = 1
    end

    if self.iconsCnt == oldIconsCnt then
        self.currentPage = oldCurrentPage
    else
        self.currentPage = 1
        SetImguiDisabled(self.previousButton, true)
        SetImguiDisabled(self.firstButton, true)
        SetImguiDisabled(self.nextButton, false)
        SetImguiDisabled(self.lastButton, false)
    end

    if self.currentPage > self.allPages then
        self.currentPage = 1
    end

    if self.pageInput.Value[1] ~= self.currentPage then
        self.pageInput.Value = ToVec4Int(self.currentPage)
    end
end

function IconBrowser:SetPage(page)
    --Debug("[IconsBrowser] SetPage called with page: " .. tostring(page))
    if page < 1 or page > self.allPages then
        Warning("[IconsBrowser] Invalid page number: " .. tostring(page))
        return
    end
    self.currentPage = page
    if tonumber(self.pageInput.Value[1]) ~= self.currentPage then
        self.pageInput.Value = ToVec4Int(self.currentPage)
    end
    if self.currentPage == 1 then
        SetImguiDisabled(self.previousButton, true)
        SetImguiDisabled(self.firstButton, true)
    end

    if self.currentPage == self.allPages then
        SetImguiDisabled(self.nextButton, true)
        SetImguiDisabled(self.lastButton, true)
    end

    if self.currentPage > 1 then
        SetImguiDisabled(self.previousButton, false)
        SetImguiDisabled(self.firstButton, false)
    end

    if self.currentPage < self.allPages then
        SetImguiDisabled(self.nextButton, false)
        SetImguiDisabled(self.lastButton, false)
    end
    self:RenderPage()
end

function IconBrowser:RenderPage()
    self.updateTagsFn = {}

    self:UpdatePageCnt()

    self.allPageInput.Value = ToVec4Int(self.allPages)

    local fromIndex = (self.currentPage - 1) * self.imagePerPage + 1
    local toIndex = math.min(fromIndex + self.imagePerPage - 1, #self.uuidsSorted)

    if self.iconsContainer then
        for _, image in pairs(self.iconsImage) do
            for _, popup in pairs(image.UserData and image.UserData.Popups or {}) do
                popup:Destroy()
            end
            image:Destroy()
        end
        DestroyAllChildren(self.iconsContainer)
        self.iconsContainer:Destroy()
        self.iconsContainer = nil
        self.iconsImage = {}
    end

    self.iconsWindow = self.iconsWindow or self.iconsBrowser:AddChildWindow("Icons Window")
    self.iconsContainer = self.iconsContainer or self.iconsWindow:AddTable("IconsBrowserTable", self.iconPR)

    local lastYield = Ext.Timer.MicrosecTime()
    local thread
    thread = coroutine.create(function()
        self.panel.Disabled = true -- Disable panel during rendering to prevent interaction issues
        if self.uuidsSorted and #self.uuidsSorted > 0 then
            local row = self.iconsContainer:AddRow()
            for i = fromIndex, toIndex do
                local cell = row:AddCell()
                local uuid = self.uuidsSorted[i]
                local entry = self.searchResult[uuid]
                local iconImage = self:RenderIcon(entry, cell)
                self:IconSetup(iconImage, entry)
                self.iconsImage[uuid] = iconImage
                if Ext.Timer.MicrosecTime() - lastYield > 0.5 then
                    Ext.OnNextTick(function()
                        local ok, err = coroutine.resume(thread)
                        if not ok then
                            self.panel.Disabled = false
                            Error("[IconBrowser] Error in RenderPage coroutine: " .. tostring(err))
                        end
                    end)
                    coroutine.yield()
                    lastYield = Ext.Timer.MonotonicTime()
                end
            end
        else 
            --self.iconsBrowser:AddText(GetLoca("Not Found"))
        end
        self.panel.Disabled = false
    end)
    local ok, err = coroutine.resume(thread)
    if not ok then
        Error("[IconBrowser] Error in RenderPage coroutine: " .. tostring(err))
    end

    self.iconsContainer:SetStyle("CellPadding", self.cellsPadding[1], self.cellsPadding[2])
end

function IconBrowser:RenderIcon(entry, cell)
    return cell:AddImage(entry.Icon)
end

function IconBrowser:IconSetup(iconImage, entry)
    local userOnHoverEnter = iconImage.OnHoverEnter
    local userOnHoverLeave = iconImage.OnHoverLeave

    iconImage.OnHoverEnter = function()
        self.hoveredEntry = entry.Uuid

        if type(userOnHoverEnter) == "function" then
            userOnHoverEnter(iconImage)
        end
    end
    iconImage.OnHoverLeave = function()
        self.hoveredEntry = nil

        if type(userOnHoverLeave) == "function" then
            userOnHoverLeave(iconImage)
        end
    end
    iconImage:SetColor("Button", self.iconButtonBgColor or { 0, 0, 0, 0.6 })

    iconImage.IDContext = "IconImage_" .. entry.Uuid
end

--- @param popup ExtuiTreeParent
--- @param entry any
function IconBrowser:RenderCustomizationTab(popup, entry)
    local filterTab = popup
    local custom = self.dataManager.customizationData[entry.Uuid] or {}

    local noteInput = filterTab:AddInputText(GetLoca("Note")) 

    noteInput.Text = custom.Note or ""

    local function autoSaveChanges()
        if self.autoSave then
            self:SaveChanges()
        end
    end

    local noteDebounceFunc = Debounce(1000, function(text)
        self.tempDisableSearch = true

        custom = self.dataManager.customizationData[entry.Uuid] or {}
        local newNote = text.Text

        if newNote == custom.Note then
            self.tempDisableSearch = false
            return
        end

        if newNote == nil then
            newNote = ""
        end

        if newNote ~= newNote then
            newNote = ""
        end

        self.dataManager:ChangeDataNote(entry.Uuid, newNote)
        autoSaveChanges()
        self.tempDisableSearch = false
    end)

    local computeSizeAndSet = function()
        local newText = noteInput.Text
        local splitted = SplitByString(newText, "\n")
        local longest = 0
        for _, line in ipairs(splitted) do
            if #line > longest then
                longest = #line
            end
        end

        local width = math.max(150 * SCALE_FACTOR, longest * 24 * SCALE_FACTOR + 48)
        local height = math.max(50 * SCALE_FACTOR, (#splitted * 32 * SCALE_FACTOR) + 24)

        noteInput.SizeHint = { width, height }
    end

    noteInput.Multiline = true
    noteInput.OnChange = function()
        computeSizeAndSet()
        noteDebounceFunc(noteInput)
    end
    computeSizeAndSet()

    local groupInput = filterTab:AddInputText(GetLoca("Group"))

    groupInput.Text = custom.Group or ""

    groupInput.OnChange = Debounce(1000, function(text)
        self.tempDisableSearch = true
        local newGroup = text.Text

        custom = self.dataManager.customizationData[entry.Uuid] or {}
        if newGroup == custom.Group then
            self.tempDisableSearch = false
            return
        end

        if newGroup == nil then
            newGroup = ""
        end

        if newGroup ~= newGroup then
            newGroup = ""
        end

        self.dataManager:ChangeDataGroup(entry.Uuid, newGroup)
        autoSaveChanges()
        self:AddGroupFilter()
        self.tempDisableSearch = false
    end)

    local tagsInput = filterTab:AddInputText(GetLoca("Tags"))

    local tagsAddButton = filterTab:AddButton("+")
    local tagsRemoveButton = filterTab:AddButton(" - ")

    tagsAddButton:Tooltip():AddText(GetLoca("Add Tag"))
    tagsRemoveButton:Tooltip():AddText(GetLoca("Remove Tag"))

    local tagsPrefix = filterTab:AddText(GetLoca("Tags") .. ":")
    local allTags = filterTab:AddText(">")

    tagsPrefix.SameLine = true
    tagsRemoveButton.SameLine = true
    allTags.SameLine = true

    local function updateTags()
        custom = self.dataManager.customizationData[entry.Uuid] 
        local tags = custom and custom.Tags or {}
        tags = DeepCopy(tags)
        for _, tag in ipairs(tags) do
            if not tag or tag == "" then
                table.remove(tags, _)
            end
        end
        if next(tags) == nil then
            allTags.Label = ""
        else
            local tagText = table.concat(tags, ", ")
            allTags.Label = tagText
        end
        autoSaveChanges()
    end

    self.updateTagsFn[entry.Uuid] = updateTags

    tagsInput.OnChange = function(text)
        if text.Text == "" then
            tagsAddButton.Disabled = true
            tagsRemoveButton.Disabled = true
        else
            tagsAddButton.Disabled = false
            tagsRemoveButton.Disabled = false
        end
    end

    tagsAddButton.OnClick = function()
        self.tempDisableSearch = true
        local tag = tagsInput.Text
        if tag and tag ~= "" then
            self.dataManager:AddTagToData(entry.Uuid, tag)
            tagsInput.Text = ""
            updateTags()
            self:AddTagsFilter()
        else
            updateTags()
            self:AddTagsFilter()
        end
        self.tempDisableSearch = false
    end

    tagsRemoveButton.OnClick = function()
        self.tempDisableSearch = true
        local tag = tagsInput.Text
        if tag and tag ~= "" then
            self.dataManager:RemoveTagFromData(entry.Uuid, tag)
            tagsInput.Text = ""
            tagsAddButton.Disabled = true
            tagsRemoveButton.Disabled = true
            updateTags()
            self:AddTagsFilter()
        else
        end
        self.tempDisableSearch = false
    end

    updateTags()

    tagsAddButton.Disabled = true
    tagsRemoveButton.Disabled = true

    noteInput.ItemWidth = self.browserWidth * 0.4
    groupInput.ItemWidth = self.browserWidth * 0.4
    tagsInput.ItemWidth = self.browserWidth * 0.4
end

function IconBrowser:Destroy()
    if not self.isValid then
        return
    end

    if self.tagsFilterMenu then
        DeleteWindow(self.tagsFilterMenu)
        self.tagsFilterMenu = nil
    end

    for _, sub in pairs(self.toUnSubOnDestroy or {}) do
        if sub and sub.Unsubscribe then
            sub:Unsubscribe()
        end
    end

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
    end

    if self.panel then
        DestroyAllChildren(self.panel)
        DeleteWindow(self.panel)
        self.panel = nil
    end

    self.isValid = false
end

function IconBrowser:Focus()
    if self.panel then
        FocusWindow(self.panel)
    end
end

function IconBrowser:Close()
    if self.panel and self.panel.Open then
        self.panel.Open = false
        if self.panel.OnClose then
            self.panel:OnClose()
        end
    end
end

function IconBrowser:Toggle()
    if not self.panel then
        self:Render()
        return
    end

    self.panel.Open = not self.panel.Open
    if self.panel.Open then
    elseif self.panel.OnClose then
        self.panel:OnClose()
    end
end