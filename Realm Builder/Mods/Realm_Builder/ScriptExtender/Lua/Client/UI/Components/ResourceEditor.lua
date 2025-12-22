--- @class ResourceEditor
--- @field Resource ResourceAtmosphereResource
--- @field ModifedResource any
--- @field ResourceUUID string
--- @field SaveInitialState fun(self:ResourceEditor):boolean
--- @field new fun(resourceID:string, resType:string):ResourceEditor
ResourceEditor = {}
ResourceEditor = _Class("AtmosEditor")

--- @class AtmosphereEditor
--- @field Resource ResourceAtmosphereResource
--- @field ModfiedResource ResourceAtmosphere
--- @field ResourceUUID string
AtmosphereEditor = _Class("AtmosphereEditor", ResourceEditor)

--- @class LightingEditor
--- @field Resource ResourceLightingResource
--- @field ModfiedResource Lighting
--- @field ResourceUUID string
LightingEditor = _Class("LightingEditor", ResourceEditor)
local cachedResourceEditors = {}

local readOnlyFields = {
    ["GUID"] = true,
    ["Guid"] = true,
    ["WhiteBalanceMatrix"] = true,
    ["Atmosphere"] = true,
}

local preassignedRanges = {
    Yaw = { Min = 0, Max = 180, Step = 1 },
    Pitch = { Min = 0, Max = 180, Step = 1 },
    Roll = { Min = 0, Max = 180, Step = 1 },
    Aperture = { Min = 0, Max = 180, Step = 1 },
    Hue = { Min = 0, Max = 180, Step = 0.01 },
}

function ResourceEditor:__init(resourceID, resType)
    self.ResourceUUID = resourceID
    self.ModfiedResource = {}
    self.ResourceType = resType
    self.SetChannel = nil
end

function LightingEditor:__init(resourceID)
    ResourceEditor.__init(self, resourceID, "Lighting")
    self.SetChannel = NetChannel.SetLighting
end

function AtmosphereEditor:__init(resourceID)
    ResourceEditor.__init(self, resourceID, "Atmosphere")
    self.SetChannel = NetChannel.SetAtmosphere
end

function ResourceEditor:SaveInitialState()
    if self.InitialState then return true end
    local res = Ext.Resource.Get(self.ResourceUUID, self.ResourceType)
    if not res then return false end
    self.InitialState = RBUtils.DeepCopy(res[self.ResourceType])
    return true
end

function ResourceEditor:Render()
    for _, editor in pairs(cachedResourceEditors) do
        if editor.Panel and editor.Panel.Open then
            editor.Panel.Open = false
        end
    end
    if self.Panel then
        self.Panel.Open = true
        return
    end

    if not self:SaveInitialState() then
        Warning("Failed To Save Initial State for Resource Editor: " .. self.ResourceUUID)
        return
    end

    local window = WindowManager.RegisterWindow(self.ResourceUUID,
        "Realm Builder - Resource Editor - " .. self.ResourceType,
        "Resource Editor")
    window.Closeable = true

    self.Panel = window
    local updateUIState = nil
    local debouceDelay = self.ResourceType == "Lighting" and 1000 or 10
    local setter = function()
        if self.ResourceType == "Lighting" then
            self.SetChannel:RequestToServer(
                { [self.ResourceType] = self.ModfiedResource, ResourceUUID = self.ResourceUUID, Reset = true },
                function(response)
                    self.SetChannel:RequestToServer({ Apply = true, ResourceUUID = self.ResourceUUID },
                        function(response)
                            if updateUIState then
                                updateUIState()
                            end
                        end)
                end)
            return
        end
        self.SetChannel:RequestToServer({ [self.ResourceType] = self.ModfiedResource, ResourceUUID = self.ResourceUUID },
            function(response)
                self.SetChannel:RequestToServer({ Apply = true, ResourceUUID = self.ResourceUUID }, function(response)
                    if updateUIState then
                        updateUIState()
                    end
                end)
            end)
    end
    --local delaySetter = RBUtils.Debounce(debouceDelay, setter)
    local delaySetter = setter
    self.ApplyModifications = delaySetter

    local resetBtn = window:AddButton("Reset World " .. self.ResourceType)
    resetBtn.OnClick = function()
        self.SetChannel:RequestToServer({ Reset = true }, function(response)
            if updateUIState then
                updateUIState()
            end
        end)
    end

    local applyBtn = window:AddButton("Set " .. self.ResourceType)
    applyBtn.SameLine = true
    applyBtn.OnClick = function()
        setter()
    end

    local resetThisBtn = window:AddButton("Reset Changes")
    resetThisBtn.SameLine = true
    resetThisBtn.OnClick = function()
        self.ModfiedResource = RBUtils.DeepCopy(self.InitialState)
        setter()
    end

    self.ModfiedResource = {}
    local root = ImguiElements.AddTree(window, self.ResourceType, true)
    updateUIState = self:RenderEditor(root, self.ResourceType, function(returnModified)
            if returnModified then
                return self.ModfiedResource
            end
            local res = Ext.Resource.Get(self.ResourceUUID, self.ResourceType) --[[@as ResourceAtmosphereResource]]
            return res[self.ResourceType]
        end,
        function(field, value)
            local res = Ext.Resource.Get(self.ResourceUUID, self.ResourceType) --[[@as ResourceAtmosphereResource]]
            self.ModfiedResource[field] = value
            res[self.ResourceType][field] = value
            delaySetter()
        end)
end

function ResourceEditor:RenderArrayEditor(parent, label, objGetter, objSetter)
    local tree = ImguiElements.AddTree(parent, label, true)

    local tab = tree:AddTable(label .. "Table", 1)
    local row = tab:AddRow()

    local initValue = objGetter()
    local valueType = type(initValue[1])
    local valueField = valueType == "string" and "Text" or "Checked"
    local inputs = {}

    row = tab:AddRow()
    for i, value in ipairs(initValue) do
        local cell = row:AddCell()
        local input = nil
        if type(value) == "string" then
            input = cell:AddInputText("## string" .. label .. i .. "Setter", value)
            input.AutoSelectAll = true
            input.OnChange = function(text)
                local arr = objGetter()
                arr[i] = text.Text
                objSetter(arr)
            end
            input.OnRightClick = function()
                local arr = objGetter()
                arr[i] = value
                objSetter(arr)
                input.Text = value
            end
        elseif type(value) == "boolean" then
            input = cell:AddCheckbox("## boolean " .. label .. i .. "Setter", value)
            input.OnChange = function(checkbox)
                local arr = objGetter()
                arr[i] = checkbox.Checked
                objSetter(arr)
            end
            input.OnRightClick = function()
                local arr = objGetter()
                arr[i] = value
                objSetter(arr)
                input.Checked = value
            end
        end
        table.insert(inputs, input)
    end

    --- @type function
    local refresh
    function refresh()
        local newValue = objGetter()
        for i, newV in ipairs(newValue) do
            inputs[i][valueField] = newV
        end
    end

    refresh()

    return refresh
end

--- @param parent RB_UI_Tree
function ResourceEditor:RenderEditor(parent, label, objGetter, objSetter)
    local updateFuncs = {}
    local updateUIState = function()
        for _, func in pairs(updateFuncs) do
            func()
        end
    end

    for field, initValue in RBUtils.SortedPairs(objGetter()) do
        if readOnlyFields[field] then goto continue end

        local updateFunc = nil
        if type(initValue) == "number" or RBTableUtils.IsArrayOf(initValue, "number") then
            local function getter()
                local val = objGetter()[field]
                if type(val) == "number" then
                    return { val }
                end
                return RBUtils.LightCToArray(val)
            end

            local function setter(value)
                if #value == 1 then
                    objSetter(field, value[1])
                else
                    objSetter(field, RBUtils.LightCToArray(value))
                end
            end

            local currentVal = getter()
            local range = preassignedRanges[field]
            local isInt = math.type(currentVal[1]) == "integer"
            local isColor = field:lower():find("color") ~= nil or field:lower():find("colour") ~= nil
            if not range then
                if currentVal[1] == 0 then
                    currentVal[1] = 1
                end
                if currentVal[1] > 1 then
                    isColor = false
                end
                range = {
                    Max = currentVal[1] * 10,
                    Min = -10,
                    Step = isInt and 1 or 0.01
                }
            end

            updateFunc = ImguiElements.AddNumberSliders(parent, field, getter, setter,
                { IsColor = isColor, Range = range, IsInt = isInt })
        elseif type(initValue) == "boolean" then
            local function getter()
                return objGetter()[field]
            end

            local function setter(value)
                objSetter(field, value)
            end

            local alignedTable = ImguiElements.AddAlignedTable(parent)
            local checkBox = alignedTable:AddCheckbox(field, initValue)
            checkBox.OnChange = function()
                setter(checkBox.Checked)
            end
            checkBox.OnRightClick = function()
                checkBox.Checked = initValue
            end

            updateFunc = function()
                checkBox.Checked = getter()
            end
        elseif type(initValue) == "string" then
            local function getter()
                return objGetter()[field]
            end

            local function setter(value)
                objSetter(field, value)
            end

            local alignedTable = ImguiElements.AddAlignedTable(parent)
            local input = alignedTable:AddInputText(field, initValue)
            local isUuid = RBUtils.IsUuidIncludingNull(initValue)
            input.AutoSelectAll = true
            input.OnChange = function()
                if isUuid and not RBUtils.IsUuidIncludingNull(input.Text) then return end

                setter(input.Text)
            end
            input.OnRightClick = function()
                input.Text = initValue
            end
            --[[input.OnClick = function()
                local popup = StyleHelpers.RenderTexturePopup(parent, function()
                        return getter()
                    end,
                    function(newValue)
                        setter(newValue)
                    end)
                popup:Open()
                input.OnClick = function ()
                    popup:Open()
                end
            end]]
            updateFunc = function()
                input.Text = getter()
            end
        elseif RBTableUtils.IsArrayOf(initValue, "string") or RBTableUtils.IsArrayOf(initValue, "boolean") then
            updateFunc = self:RenderArrayEditor(parent, field,
                function()
                    return RBUtils.LightCToArray(objGetter()[field])
                end,
                function(value)
                    objSetter(field, RBUtils.LightCToArray(value))
                end)
        elseif (type(initValue) == "table" or type(initValue) == "userdata") and not RBTableUtils.IsArray(initValue) then
            local subTree = parent:AddTree(field)
            subTree.Indent = 64 * SCALE_FACTOR
            local updateSub = nil
            updateFunc = function()
                if updateSub then
                    updateSub()
                end
            end
            subTree.OnExpand = function(tree)
                updateSub = self:RenderEditor(subTree, field, function(returnModified)
                        if returnModified then
                            local grandParent = objGetter(true)
                            if not grandParent then
                                return {}
                            end
                            local parentTbl = grandParent[field]
                            if not parentTbl then
                                return {}
                            end
                            return parentTbl
                        end
                        return objGetter()[field]
                    end,
                    function(subField, value)
                        local grandParent = objGetter(true)
                        local parentTbl = nil
                        if not grandParent then
                            objSetter(field, {})
                        end

                        parentTbl = objGetter(true)[field]
                        if not parentTbl then
                            parentTbl = {}
                        end

                        parentTbl[subField] = value
                        objSetter(field, parentTbl)
                    end)
                subTree.OnExpand = function() end
            end
        end
        if updateFunc then
            parent:AddSeparator():SetStyle("ItemSpacing", 0, 10 * SCALE_FACTOR)
            table.insert(updateFuncs, updateFunc)
        end
        ::continue::
    end

    return updateUIState
end

RegisterDebugWindow("Realm Builder Atmosphere Editor", function(panel)
    local inputs = {}
    local setChannels = {
        Atmosphere = NetChannel.SetAtmosphere,
        Lighting = NetChannel.SetLighting,
    }
    local editorConstrutors = {
        Atmosphere = AtmosphereEditor.new,
        Lighting = LightingEditor.new
    }
    for _, resType in pairs({ "Atmosphere", "Lighting" }) do
        local resetBtn = panel:AddButton("Reset " .. resType .. " Resource")
        local setChannel = setChannels[resType]
        local editorConstructor = editorConstrutors[resType]
        resetBtn.OnClick = function()
            setChannel:RequestToServer({ Reset = true }, function(response)
            end)
        end
        local allAtms = Ext.Resource.GetAll(resType)
        local uuidToName = {}
        local nameToUuid = {}
        local uuidIdx = {}
        for i, resUuid in pairs(allAtms) do
            local padNumber = RBStringUtils.PadNumber(i, 3) -- for sorting
            local indexPrefix = "[ " .. padNumber .. "] "
            local label = indexPrefix .. resUuid
            if resType == "Atmosphere" then
                local res = Ext.Resource.Get(resUuid, resType) --[[@as ResourceAtmosphereResource]]
                if res and res and res.Labels then
                    local arrLabel = RBUtils.LightCToArray(res.Labels)
                    label = indexPrefix .. table.concat(arrLabel, ", ") .. " (" .. resUuid .. ")"
                end
            end

            uuidToName[resUuid] = label
            nameToUuid[label] = resUuid
            uuidIdx[resUuid] = i
        end
        local nameArray = {}
        for name, _ in pairs(nameToUuid) do
            table.insert(nameArray, name)
        end
        table.sort(nameArray)
        local inputForCopy = panel:AddInputText("##" .. resType .. "ResourceToCopy", "")
        inputForCopy.AutoSelectAll = true
        inputs[resType] = inputForCopy
        local combo = panel:AddCombo("Select " .. resType .. " Resource")
        local popup = panel:AddPopup("Copy " .. resType .. " Resource UUID")
        local maxSize = 100
        local recentQueue = {}
        local allSelecteble = {}
        local tab = popup:AddTable("##" .. resType .. "ResourcePopupTable", 2)
        local row = tab:AddRow()
        local dualPanel = {
            row:AddCell(),
            row:AddCell(),
        }
        tab.ColumnDefs[1] = { WidthFixed = true }
        local mainPanel = dualPanel[1]

        local function setSelected(uuid)
            local idx = uuidIdx[uuid]
            combo.SelectedIndex = idx - 1
            combo:OnChange()
        end

        for i, name in pairs(nameArray) do
            local uuid = nameToUuid[name]
            local seletable = mainPanel:AddSelectable(name .. "##" .. uuid)
            seletable.DontClosePopups = true
            seletable.OnClick = function()
                setSelected(uuid)
            end
            allSelecteble[uuid] = seletable
        end

        local recentGroup = dualPanel[2]
        recentGroup:AddSeparatorText("Recent"):SetStyle("SeparatorTextAlign", 0.5)
        local function renderRecentQueue()
            ImguiHelpers.DestroyAllChildren(recentGroup)
            recentGroup:AddSeparatorText("Recent"):SetStyle("SeparatorTextAlign", 0.5)
            for i = #recentQueue, 1, -1 do
                local uuid = recentQueue[i]
                local name = uuidToName[uuid]
                local seletable = recentGroup:AddSelectable(name)
                seletable.DontClosePopups = true
                seletable.OnClick = function(sel)
                    sel.Selected = false
                    setSelected(uuid)
                end
                seletable.OnRightClick = function(sel)
                    sel.Selected = false
                    table.remove(recentQueue, i)
                    renderRecentQueue()
                end
            end
        end

        combo.OnClick = function()
            popup:Open()
        end

        combo.OnHoverEnter = function()
            NetChannel["Get" .. resType]:RequestToServer({}, function(response)
                local currentUuid = response.Guid
                local allAvaiable = response.ResourceUUIDs
                local currentName = uuidToName[currentUuid]
                if currentName then
                    combo.SelectedIndex = uuidIdx[currentUuid] - 1
                else
                    combo.SelectedIndex = -1
                end
                if RBTableUtils.CountMap(allAvaiable) < 2 then
                    for _, sel in pairs(allSelecteble) do
                        sel.Visible = true
                    end
                else
                    for uuid, sel in pairs(allSelecteble) do
                        sel.Visible = allAvaiable[uuid] == true
                    end
                end
            end)
        end

        combo.OnChange = function(cmb)
            local resUuid = ImguiHelpers.GetCombo(cmb)
            if not resUuid then return end
            local editor = cachedResourceEditors[resUuid]
            if not editor then
                editor = editorConstructor(resUuid, resType)
                if editor then
                    cachedResourceEditors[resUuid] = editor
                else
                    Warning("Failed to create editor for resource uuid: " .. resUuid)
                end
            end

            setChannel:RequestToServer({ Apply = true, ResourceUUID = resUuid }, function(response)
            end)

            inputForCopy.Text = resUuid
            local isInQueue = table.find(recentQueue, resUuid)
            if isInQueue then
            else
                table.insert(recentQueue, resUuid)
                if #recentQueue > maxSize then
                    table.remove(recentQueue, 1)
                end
                renderRecentQueue()
            end
        end
        inputForCopy.OnChange = RBUtils.Debounce(100, function(input)
            local keyWord = tostring(input.Text):lower()
            for _, name in pairs(nameArray) do
                local find = name:lower():find(keyWord)
                local uuid = nameToUuid[name]
                allSelecteble[uuid].Visible = find ~= nil
            end
        end)
        combo.Options = allAtms
        combo.HeightLarge = true
    end

    local notif = Notification.new("Resource Editor")
    panel:AddButton("Open Atmosphere Editor").OnClick = function()
        local cameraPos = { CameraHelpers.GetCameraPosition() }
        NetChannel.GetAtmosphere:RequestToServer({ Position = cameraPos }, function(response)
            local atmosphereUuid = response.Guid
            if atmosphereUuid == "" then
                notif:Show("Resource Editor", function(panel)
                    panel:AddText("No atmosphere resource id found in the current level.")
                end)
                return
            end

            local editor = cachedResourceEditors[atmosphereUuid]
            if not editor then
                editor = AtmosphereEditor.new(atmosphereUuid)
                cachedResourceEditors[atmosphereUuid] = editor
            end
            if inputs["Atmosphere"] then
                inputs["Atmosphere"].Text = atmosphereUuid
            end

            editor:Render()
        end)
    end
    panel:AddButton("Open Lighting Editor").OnClick = function()
        local cameraPos = { CameraHelpers.GetCameraPosition() }
        NetChannel.GetLighting:RequestToServer({ Position = cameraPos }, function(response)
            local lightingUuid = response.Guid
            if lightingUuid == "" then
                notif:Show("Resource Editor", function(panel)
                    panel:AddText("No lighting resource id found in the current level.")
                end)
                return
            end

            local editor = cachedResourceEditors[lightingUuid]
            if not editor then
                editor = LightingEditor.new(lightingUuid)
                cachedResourceEditors[lightingUuid] = editor
            end

            if inputs["Lighting"] then
                inputs["Lighting"].Text = lightingUuid
            end

            editor:Render()
        end)
    end

    local saveBtn = panel:AddButton("Save Atmosphere")
    saveBtn.OnClick = function()
        local lightingEditor = nil
        local lightingReady = false
        local atmosphereEditor = nil
        local atmosphereReady = false

        local function checkAndSave()
            if lightingReady and atmosphereReady then
                notif:Show("Resource Editor", function(panel)
                    panel:AddText("Atmosphere and Lighting resources saved to level.")
                end)
                atmosphereEditor = atmosphereEditor or {}
                lightingEditor = lightingEditor or {}
                local formated = {
                    AtmosphereUuid = atmosphereEditor.ResourceUUID,
                    LightingUuid = lightingEditor.ResourceUUID,
                    ModifiedAtmosphere = RBUtils.DeepCopy(atmosphereEditor.ModfiedResource),
                    ModifiedLighting = RBUtils.DeepCopy(lightingEditor.ModfiedResource),
                }
                local currentLevel = _C().Level.LevelName
                local currentTime = RBUtils.GetFormatTime()
                local fileName = currentLevel .. "_" .. currentTime
                local savePath = FilePath.GetAtmospherePath(fileName)
                Ext.IO.SaveFile(savePath, Ext.Json.Stringify(formated))
            end
        end

        local cameraPos = { CameraHelpers.GetCameraPosition() }
        NetChannel.GetAtmosphere:RequestToServer({ Position = cameraPos }, function(response)
            local atmosphereUuid = response.Guid
            if atmosphereUuid ~= "" then
                local editor = cachedResourceEditors[atmosphereUuid]
                if editor then
                    atmosphereEditor = editor
                end
            end
            atmosphereReady = true
            checkAndSave()
        end)
        NetChannel.GetLighting:RequestToServer({ Position = cameraPos }, function(response)
            local lightingUuid = response.Guid
            if lightingUuid ~= "" then
                local editor = cachedResourceEditors[lightingUuid]
                if editor then
                    lightingEditor = editor
                end
            end
            lightingReady = true
            checkAndSave()
        end)
    end

    local loadFileNameInput = panel:AddInputText("Load From File")
    loadFileNameInput.Hint = "Enter file name"
    
    local loadBtn = panel:AddButton("Load Atmosphere")
    loadBtn.OnClick = function()
        local fileName = tostring(loadFileNameInput.Text)
        if fileName == "" then
            notif:Show("Resource Editor", function(panel)
                panel:AddText("Please enter a valid file name.")
            end)
            return
        end

        local loadPath = FilePath.GetAtmospherePath(fileName)
        local fileContent = Ext.IO.LoadFile(loadPath)
        if not fileContent then
            notif:Show("Resource Editor", function(panel)
                panel:AddText("File not found: " .. loadPath)
            end)
            return
        end

        local parsed = Ext.Json.Parse(fileContent)
        if not parsed then
            notif:Show("Resource Editor", function(panel)
                panel:AddText("Failed to parse file: " .. loadPath)
            end)
            return
        end

        local atmosphereUuid = parsed.AtmosphereUuid
        local lightingUuid = parsed.LightingUuid
        if atmosphereUuid and atmosphereUuid ~= "" then
            local editor = cachedResourceEditors[atmosphereUuid]
            if not editor then
                editor = AtmosphereEditor.new(atmosphereUuid)
                cachedResourceEditors[atmosphereUuid] = editor
            end
            editor:SaveInitialState()
            editor.ModfiedResource = parsed.ModifiedAtmosphere or {}
            editor:ApplyModifications()
        end
        if lightingUuid and lightingUuid ~= "" then
            local editor = cachedResourceEditors[lightingUuid]
            if not editor then
                editor = LightingEditor.new(lightingUuid)
                cachedResourceEditors[lightingUuid] = editor
            end
            editor:SaveInitialState()
            editor.ModfiedResource = parsed.ModifiedLighting or {}
            editor:ApplyModifications()
        end
    end

end)
