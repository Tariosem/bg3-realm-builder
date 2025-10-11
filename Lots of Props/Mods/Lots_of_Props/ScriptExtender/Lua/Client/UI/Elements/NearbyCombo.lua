local allNearbyComboRefs = {}

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
--- @field Radius number
--- @field ExcludeEntries GUIDSTRING[]
--- @field SameLine boolean
--- @field Label string
--- @field SelectedIndex integer
--- @field Width number
--- @field new fun(parent:ExtuiTreeParent):NearbyCombo
--- @field SortFunc fun(a:NearbyEntry, b:NearbyEntry):boolean -- always a < b, order depends on Ascending
--- @field UpdateOptions fun(self:NearbyCombo)
--- @field SetSelected fun(self:NearbyCombo, guid:GUIDSTRING?)
--- @field GetSelected fun(self:NearbyCombo): GUIDSTRING?, string
--- @field OnChange fun(self:NearbyCombo, Guid:GUIDSTRING, displayName:string)
NearbyCombo = _Class("NearbyCombo")
NearbyCombo.__newindex = function (t, k, v)
    if k == "SameLine" then
        t.combo.SameLine = v
    elseif k == "Label" then
        t.combo.Label = v
    elseif k == "SelectedIndex" then
        t.combo.SelectedIndex = v
    elseif k == "Width" then
        t.combo.Width = v
    else
        rawset(t, k, v)
    end
end

local defaultSortByName = function(a,b) return a.DisplayName < b.DisplayName end
local defaultSortByDistance = function(a,b) return a.Distance < b.Distance end

local function calcCols(numItems)
    return math.max(10, math.floor(math.sqrt(numItems)))
end

function NearbyCombo:__init(parent)
    self.parent = parent
    self.combo = parent:AddCombo("")
    self.combo.IDContext = "NearbyCombo" .. Uuid_v4()
    self.popup = parent:AddPopup(self.combo.IDContext .. "Popup")

    self.ExcludeCamera = false

    self.cellRefs = {}
    self.rowsRefs = {}

    self.Ascending = true
    self.SortFunc = defaultSortByName
    table.insert(allNearbyComboRefs, self)

    self.Radius = 18

    self.Options = nil

    self:UpdateOptions()
    self:SetupComboEvents()
    self:RenderPopupBase()
end

function NearbyCombo:GetSelected()
    local displayName = GetCombo(self.combo)
    return GetGuidFromDisplayName(displayName), displayName
end

function NearbyCombo:SetSelected(guid)
    if not guid or guid == "" then
        self.Selected = nil
        self.combo.SelectedIndex = -1
        return
    end
    local name = GetDisplayNameFromGuid(guid)
    if not name then return end
    self.Selected = guid
    SetCombo(self.combo, name, nil, true)
end

function NearbyCombo:UpdateOptions()
    local opts = GetAllNearbyEntries()
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
            Guid = CameraSymbol,
            DisplayName = GetLoca("Camera"),
            Distance = 0,
        })
    end
    for _,guid in pairs(self.ExcludeEntries or {}) do
        for i=#opts,1,-1 do
            if opts[i].Guid == guid then
                table.remove(opts, i)
            end
        end
    end
    self.Options = opts
    local displayNameList = {}
    for _,entry in pairs(opts) do
        table.insert(displayNameList, entry.DisplayName)
    end
    self.combo.Options = displayNameList
    self:SetSelected(GetName(self.Selected))
end

function NearbyCombo:SetupComboEvents()
    self.combo.OnChange = function (cmb)
        local name = GetCombo(cmb)
        local guid = GetGuidFromDisplayName(name)
        if not guid then Warning("NearbyCombo: No guid found for display name: " .. tostring(name)) return end
        if self.OnChange then
            self:OnChange(guid, name)
        end
        self.Selected = guid
    end

    self.combo.OnClick = function (cmb)
        UpdateNearbyMap({CGetPosition(CGetHostCharacter())}, self.Radius)
        self:UpdateOptions()
        self:RenderIcons()
    end

    self.combo.OnRightClick = function (cmb)
        UpdateNearbyMap({CGetPosition(CGetHostCharacter())}, self.Radius)
        self:UpdateOptions()
        self:RenderIcons()
        self.popup:Open()
    end
end

function NearbyCombo:RenderPopupBase()
    local headerTable = self.popup:AddTable("", 2)
    headerTable.IDContext = self.popup.IDContext .. "Header"
    headerTable.ColumnDefs[1] = { WidthFixed = true , Width = 300 * SCALE_FACTOR }
    headerTable.ColumnDefs[2] = { WidthFixed = true }
    local row = headerTable:AddRow()
    local left = row:AddCell()
    local right = row:AddCell()

    local searchInput = left:AddInputText("")
    searchInput.IDContext = self.combo.IDContext .. "Search"
    searchInput.Hint = GetLoca("Search") .. "..."

    local debounceTimer = nil
    local function hide(keywords)
        local words = SplitBySpace(keywords)
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
        if debounceTimer then
            Timer:Cancel(debounceTimer)
        end
        debounceTimer = Timer:After(10, function (timerID)
            hide(input.Text)
        end)
    end

    local configPopup = self.popup:AddPopup(self.combo.IDContext .. "ConfigPopup")
    local configButton = right:AddButton("=")
    local sortButton = right:AddSelectable("Sort by DisplayName")

    sortButton.IDContext = self.combo.IDContext .. "SortButton"
    sortButton.AutoClosePopups = false

    sortButton.OnClick = function (sel)
        self.Ascending = not self.Ascending
        self:UpdateOptions()
        self:RenderIcons()
        sel.Selected = false
    end

    sortButton.OnRightClick = function (sel)
        self.SortFunc = self.SortFunc == defaultSortByName and defaultSortByDistance or defaultSortByName
        sel.Label = self.SortFunc == defaultSortByName and GetLoca("Sort by DisplayName") or GetLoca("Sort by Distance")
        self:UpdateOptions()
        self:RenderIcons()
    end

    sortButton.SameLine = true
    configButton.OnClick = function (btn)
        configPopup:Open()
    end

    configPopup:AddText(GetLoca("Scan Radius"))
    local radiusSlider = AddSliderWithStep(configPopup, "Radius", self.Radius, 1, 64, 1)

    radiusSlider.OnChange = function (sld)
        self.Radius = sld.Value[1]
    end

    local iconTable = self.popup:AddTable("", calcCols(#self.Options))
    iconTable.IDContext = self.popup.IDContext .. "IconTable"
    self.IconContainer = iconTable
    iconTable.RowBg = true
    iconTable.BordersInnerH = true
end

function NearbyCombo:RenderIcons()
    if not self.IconContainer then return end

    for _,cell in pairs(self.cellRefs) do
        cell:Destroy()
    end
    self.cellRefs = {}
    for _,row in pairs(self.rowsRefs) do
        row:Destroy()
    end

    local table = self.IconContainer
    local characterRow = table:AddRow()
    local itemsRow = table:AddRow()
    table.Columns = calcCols(#self.Options)

    self.rowsRefs = {characterRow, itemsRow}

    for _,entry in ipairs(self.Options) do
        local icon = GetIcon(entry.Guid)
        local displayName = entry.DisplayName

        local cell = IsCamera(entry.Guid) and characterRow:AddCell() or CIsCharacter(entry.Guid) and characterRow:AddCell() or itemsRow:AddCell()
        self.cellRefs[displayName] = cell
        cell.IDContext = self.combo.IDContext .. "Cell" .. entry.Guid

        local imageBtn = cell:AddImageButton("", icon, Vec2.new{48, 48} * SCALE_FACTOR)
        imageBtn.IDContext = cell.IDContext .. "ImageBtn"
        if PropStore[entry.Guid] and PropStore[entry.Guid].IconTintColor then
            imageBtn.Tint = PropStore[entry.Guid].IconTintColor
        end

        imageBtn:Tooltip():AddText(displayName)
        imageBtn.OnClick = function (btn)
            SetCombo(self.combo, entry.DisplayName, nil, true)
            if self.OnChange then
                self:OnChange(entry.Guid, entry.DisplayName)
            end
        end
        imageBtn.OnRightClick = function (btn)
            CameraFollow(entry.Guid)
        end
    end
end

function NearbyCombo:OnChange(Guid, displayName)end