local allNearbyComboRefs = {}

--- simply to make select nearby entity easier
--- @class NearbyCombo
--- @field parent ExtuiTreeParent
--- @field combo ExtuiCombo
--- @field popup ExtuiPopup
--- @field IconContainer ExtuiTable
--- @field Options NearbyEntry[]
--- @field Selected GUIDSTRING
--- @field ExcludeCamera boolean
--- @field cellRefs table<number, ExtuiTableCell>
--- @field Ascending boolean
--- @field HideImage boolean
--- @field Radius number
--- @field ExcludeEntries table<GUIDSTRING, boolean>
--- @field SameLine boolean
--- @field Label string
--- @field SelectedIndex integer
--- @field Width number
--- @field new fun(parent:ExtuiTreeParent, dontRender:boolean?):NearbyCombo
--- @field SortFunc fun(a:NearbyEntry, b:NearbyEntry):boolean -- always a < b, order depends on Ascending
--- @field UpdateOptions fun(self:NearbyCombo)
--- @field SetSelected fun(self:NearbyCombo, guid:GUIDSTRING?)
--- @field GetSelected fun(self:NearbyCombo): GUIDSTRING?, string
--- @field OnChange fun(self:NearbyCombo, Guid:GUIDSTRING, displayName:string)
NearbyCombo = _Class("NearbyCombo")
NearbyCombo.__newindex = function (t, k, v)
    if rawget(t, "combo") == nil then
        rawset(t, k, v)
        return
    end
    if k == "SameLine" and t.panel then
        t.panel.SameLine = v
    elseif k == "Label" then
        t.combo.Label = v
    elseif k == "SelectedIndex" then
        t.combo.SelectedIndex = v
    elseif k == "Width" then
        t.combo.Width = v
    elseif k == "HideImage" then
        if t.combo and t.combo.UserData and t.combo.UserData.ImageReservedSpace then
            local reserved = t.combo.UserData.ImageReservedSpace
            reserved.Visible = not v
            ImguiHelpers.DestroyAllChildren(reserved)
        end
    else
        rawset(t, k, v)
    end
end

local defaultSortByName = function(a,b) return a.DisplayName < b.DisplayName end
local defaultSortByDistance = function(a,b) return a.Distance < b.Distance end

local function calcCols(numItems)
    return math.max(10, math.floor(math.sqrt(numItems)))
end

function NearbyCombo:__init(parent, dontRender)
    self.parent = parent
    self.ExcludeCamera = false

    self.cellRefs = {}
    self.rowsRefs = {}

    self.Subscriptions = {}

    self.Ascending = true
    self.SortFunc = defaultSortByName
    table.insert(allNearbyComboRefs, self)

    self.Radius = 18

    self.Options = nil
    self.Selected = nil

    if not dontRender then
        self:Render()
    end
end

function NearbyCombo:Render()
    local parent = self.parent
    self.IDContext = "NearbyComboParent" .. RBUtils.Uuid_v4()
    local overGroup = parent:AddGroup("NearbyComboOver##" .. self.IDContext)
    local reservedForImage = overGroup:AddGroup("NearbyCombo##" .. self.IDContext .. "ImageReserved")
    reservedForImage:AddImage("Item_Unknown", IMAGESIZE.FRAME)
    self.panel = overGroup
    self.combo = overGroup:AddCombo("")
    self.combo.UserData = self.combo.UserData or {}
    self.combo.UserData.ImageReservedSpace = reservedForImage
    self.combo.IDContext = "NearbyCombo" .. RBUtils.Uuid_v4()
    self.combo.SameLine = true

    self.combo.Options = {}
    self:UpdateOptions()
    self:SetupComboEvents()

    local popup = parent:AddPopup(self.combo.IDContext .. "Popup")
    self.popup = popup
    self:RenderSelectionTable(popup)
end

function NearbyCombo:GetSelected()
    local displayName = ImguiHelpers.GetCombo(self.combo)
    return self.Selected, displayName
end

function NearbyCombo:SetSelected(guid)
    if not guid or guid == "" then
        self.Selected = nil
        self.combo.SelectedIndex = -1
        return
    end
    local name = RBGetName(guid)
    if not name then return end
    self.Selected = guid
    ImguiHelpers.SetCombo(self.combo, name, nil, true)
    if self.combo then
        self:UpdateImage()
    end
end

function NearbyCombo:UpdateOptions()
    NearbyMap.UpdateNearbyMap(nil, self.Radius)
    local opts = NearbyMap.GetAllNearbyEntries()
    if not opts then opts = {} end
    table.sort(opts, function(a,b)
        if not a or not b then
            return false
        end
    
        local result
        if self.Ascending then
            result = self.SortFunc(a, b)
        else
            result = self.SortFunc(b, a)
        end
        
        return result == true
    end)
    if not self.ExcludeCamera then
        table.insert(opts, 1, {
            Guid = CAMERA_SYMBOL,
            DisplayName = GetLoca("Camera"),
            Distance = 0,
        })
    end
    self.ExcludeEntries = self.ExcludeEntries or {}
    for i=#opts,1,-1 do
        local entry = opts[i]
        if self.ExcludeEntries[entry.Guid] then
            table.remove(opts, i)
        elseif not self.EnableScenery and entry.IsScenery then
            table.remove(opts, i)
        end
    end
    self.Options = opts
    self.IndexToUuid = {}
    local displayNameList = {}
    for i,entry in pairs(opts) do
        self.IndexToUuid[i] = entry.Guid
        table.insert(displayNameList, entry.DisplayName)
    end
    if self.combo then
        self.combo.Options = displayNameList
        self:SetSelected(self.Selected)
    end
end

function NearbyCombo:SetupComboEvents()
    self.combo.OnChange = function (cmb)
        local index = cmb.SelectedIndex + 1 -- lua start from 1
        local guid = self.IndexToUuid[index]
        if not guid then Warning("NearbyCombo: No guid found for index " .. tostring(index)) return end
        if self.OnChange then
            self:OnChange(guid, cmb.Options[index])
        end
        self.Selected = guid
        self:UpdateImage()
    end

    self.combo.OnClick = function (cmb)
        NearbyMap.UpdateNearbyMap({RBGetPosition(RBGetHostCharacter())}, self.Radius)
        self:UpdateOptions()
        self:RenderIcons()
        self.popup:Open()
    end

    self.combo.OnRightClick = function (cmb)
        NearbyMap.UpdateNearbyMap({RBGetPosition(RBGetHostCharacter())}, self.Radius)
        self:UpdateOptions()
        self:RenderIcons()
        self.popup:Open()
    end
end

--- @param parent ExtuiTreeParent
function NearbyCombo:RenderSelectionTable(parent)
    if not self.Options then
        self:UpdateOptions()
    end
    local headerTable = parent:AddTable("", 2)
    headerTable.IDContext = parent.IDContext .. "Header"
    headerTable.ColumnDefs[1] = { WidthFixed = true , Width = 300 * SCALE_FACTOR }
    headerTable.ColumnDefs[2] = { WidthFixed = true }
    local row = headerTable:AddRow()
    local left = row:AddCell()
    local right = row:AddCell()

    local searchInput = left:AddInputText("")
    searchInput.IDContext = parent.IDContext .. "Search"
    searchInput.Hint = GetLoca("Search") .. "..."

    local function hide(keywords)
        local words = RBStringUtils.SplitBySpace(keywords)
        if not words or #words == 0 or keywords == "" then
            for _, cell in pairs(self.cellRefs) do
                cell.Visible = true
            end
            return
        end

        for name, cell in pairs(self.cellRefs) do
            local visible = false
            for _, word in ipairs(words) do
                if string.find(string.lower(name), string.lower(word), 1, true) then
                    visible = true
                    break
                end
            end
            cell.Visible = visible
        end
    end

    searchInput.OnChange = function (input)
        hide(input.Text)
    end

    local configPopup = parent:AddPopup(parent.IDContext .. "ConfigPopup")
    local configButton = right:AddImageButton("", RB_ICONS.Gear, IMAGESIZE.FRAME)
    configButton:SetColor("Button", {0,0,0,0})
    local sortButton = right:AddSelectable("Sort by DisplayName")
    local refreshBtn = ImguiElements.AddResetButton(right, true)
    refreshBtn.OnClick = function (btn)
        self:UpdateOptions()
        self:RenderIcons()
    end

    sortButton.AllowItemOverlap = true
    sortButton.IDContext = parent.IDContext .. "SortButton"
    sortButton.AutoClosePopups = false
    sortButton.DontClosePopups = true


    sortButton.OnRightClick = function (sel)
        self.Ascending = not self.Ascending
        self:UpdateOptions()
        self:RenderIcons()
        sel.Selected = false
    end

    sortButton.OnClick = function (sel)
        sel.Selected = false
        self.SortFunc = self.SortFunc == defaultSortByName and defaultSortByDistance or defaultSortByName
        sel.Label = self.SortFunc == defaultSortByName and GetLoca("Sort by DisplayName") or GetLoca("Sort by Distance")
        self:UpdateOptions()
        self:RenderIcons()
    end

    sortButton.SameLine = true
    configButton.OnClick = function (btn)
        configPopup:Open()
    end
    local aligedTable = ImguiElements.AddAlignedTable(configPopup)
    local radiusSlider = aligedTable:AddSliderWithStep("Radius", self.Radius, 1, 64, 1, false)

    radiusSlider.OnChange = function (sld)
        self.Radius = sld.Value[1]
    end

    if self.EnableScenery then
        local populateScenery = aligedTable:AddButton("Populate Scenery")
        populateScenery.Label = GetLoca("Populate Scenery")
        populateScenery.IDContext = configPopup.IDContext .. "PopulateScenery"
        populateScenery.OnClick = function (chk)
            NearbyMap.PopulateSceneryNearby(nil,self.Radius, function ()
                self:UpdateOptions()
                self:RenderIcons()
            end)
        end
    end

    local iconTable = parent:AddTable("", calcCols(#self.Options))
    iconTable.IDContext = parent.IDContext .. "IconTable"
    self.IconContainer = iconTable
    iconTable.RowBg = true
    iconTable.BordersInnerH = true
end

function NearbyCombo:UpdateImage()
    if not self.Selected or not self.combo or not self.combo.UserData then return end
    local reserved = self.combo.UserData.ImageReservedSpace
    if reserved then
        ImguiHelpers.DestroyAllChildren(reserved)
        reserved:AddImage(RBGetIcon(self.Selected), IMAGESIZE.FRAME)
    end
end

function NearbyCombo:RenderIcons()
    if not self.IconContainer then return end

    self.cellRefs = {}
    for _,row in pairs(self.rowsRefs) do
        row:Destroy()
    end

    local table = self.IconContainer
    local characterRow = table:AddRow()
    local itemsRow = table:AddRow()
    local sceneryRow = table:AddRow()
    table.Columns = calcCols(#self.Options)

    self.rowsRefs = {characterRow, itemsRow, sceneryRow}
    for _,row in ipairs(self.rowsRefs) do
        row.Visible = false
    end
    for _,entry in ipairs(self.Options) do
        local icon = RBGetIcon(entry.Guid)
        local displayName = entry.DisplayName

        local row = nil
        if RBUtils.IsCamera(entry.Guid) or EntityHelpers.IsCharacter(entry.Guid) then
            row = characterRow
        elseif EntityHelpers.IsItem(entry.Guid) then
            row = itemsRow
        elseif entry.Entity and entry.Entity.Scenery then
            row = sceneryRow
        else
            row = itemsRow
        end
        row.Visible = true
        local cell = row:AddCell()
        self.cellRefs[displayName] = cell
        cell.IDContext = "Cell" .. entry.Guid

        local imageBtn = cell:AddImageButton("", icon, Vec2.new{48, 48} * SCALE_FACTOR)
        imageBtn.IDContext = cell.IDContext .. "ImageBtn"
        if EntityStore[entry.Guid] and EntityStore[entry.Guid].IconTintColor then
            imageBtn.Tint = EntityStore[entry.Guid].IconTintColor
        end

        imageBtn.OnHoverEnter = function (btn)
            self.HoveringKey = entry.Guid
            imageBtn:Tooltip():AddText(displayName)
            imageBtn.OnClick = function ()
                if self.combo then
                    ImguiHelpers.SetCombo(self.combo, entry.DisplayName, nil, true)
                    self.Selected = entry.Guid
                    self:UpdateImage()
                end
                if self.OnChange then
                    self:OnChange(entry.Guid, entry.DisplayName)
                end
            end
            imageBtn.OnRightClick = imageBtn.OnClick

            
            imageBtn.OnHoverLeave = function (btn)
                self.HoveringKey = nil
            end

            imageBtn.OnHoverEnter = function ()
                self.HoveringKey = entry.Guid
            end
        end
    end
end

function NearbyCombo:OnChange(Guid, displayName)end

--- @param parent ExtuiTreeParent
--- @param label string?
--- @param obj table<GUIDSTRING, boolean> -- set of selected guids
--- @return NearbyCombo
function ImguiElements.AddEntityPicker(parent, label, obj)
    local uuid = RBUtils.Uuid_v4()
    local aligned = ImguiElements.AddAlignedTable(parent)
    local cell = aligned:AddNewLine(label or GetLoca("Select Entity"))

    local upTab = cell:AddGroup("EntityPickerGroup" .. uuid)
    local picker = NearbyCombo.new(upTab)

    local function updatePresentation()
    end

    local clearBtn = aligned:AddButton(GetLoca("Clear"))
    clearBtn.OnClick = function ()
        picker:SetSelected(nil)
        for k,v in pairs(obj) do
            obj[k] = nil
        end
        updatePresentation()
    end

    local lowTab = cell:AddGroup("EntityPickerPresentation")

    local function renderPicked(guid, name, index)
        local group = lowTab:AddGroup("PickedEntityGroup" .. guid)
        local icon = RBGetIcon(guid)
        local imgBtn = group:AddImageButton("", icon, IMAGESIZE.FRAME)
        local nameText = group:AddText(name)
        nameText.SameLine = true

        imgBtn.IDContext = "PickedEntity" .. guid
        StyleHelpers.ApplyImageButtonHoverStyle(imgBtn)
        imgBtn.OnClick = function ()
            obj[guid] = nil
            group:Destroy()
        end
    end

    function updatePresentation()
        ImguiHelpers.DestroyAllChildren(lowTab)
        local sortedNames = {}
        for guid, _ in pairs(obj) do
            local name = RBGetName(guid) or GetLoca("Unknown")
            table.insert(sortedNames, {Guid = guid, Name = name})
        end
        table.sort(sortedNames, function(a,b) return a.Name < b.Name end)
        local cnt = 0
        for _,entry in ipairs(sortedNames) do
            local guid = entry.Guid
            cnt = cnt + 1
            renderPicked(guid, entry.Name, cnt)
        end
    end

    picker.OnChange = function (self, guid, displayName)
        obj[guid] = true
        picker:SetSelected(nil)
        updatePresentation()
    end

    return picker
end