--- @class ResourceEditor
--- @field Resource ResourceAtmosphereResource
--- @field ModifedResource any
--- @field ResourceUUID string
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
    local res = Ext.Resource.Get(self.ResourceUUID, self.ResourceType)
    self.InitialState = DeepCopy(res[self.ResourceType])
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

    self:SaveInitialState()
    local window = RegisterWindow(self.ResourceUUID, "Realm Builder - Resource Editor - " .. self.ResourceType,
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
    local delaySetter = Debounce(debouceDelay, setter)

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
        self.ModfiedResource = DeepCopy(self.InitialState)
        setter()
    end

    self.ModfiedResource = {}
    local root = StyleHelpers.AddTree(window, self.ResourceType, true)
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
    local tree = StyleHelpers.AddTree(parent, label, true)

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

    for field, initValue in SortedPairs(objGetter()) do
        if readOnlyFields[field] then goto continue end

        local updateFunc = nil
        if type(initValue) == "number" or IsArrayOf(initValue, "number") then
            local function getter()
                local val = objGetter()[field]
                if type(val) == "number" then
                    return { val }
                end
                return LightCToArray(val)
            end

            local function setter(value)
                if #value == 1 then
                    objSetter(field, value[1])
                else
                    objSetter(field, LightCToArray(value))
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

            updateFunc = StyleHelpers.AddNumberSliders(parent, field, getter, setter,
                { IsColor = isColor, Range = range, IsInt = isInt })
        elseif type(initValue) == "boolean" then
            local function getter()
                return objGetter()[field]
            end

            local function setter(value)
                objSetter(field, value)
            end

            local alignedTable = StyleHelpers.AddAlignedTable(parent)
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

            local alignedTable = StyleHelpers.AddAlignedTable(parent)
            local input = alignedTable:AddInputText(field, initValue)
            local isUuid = IsUuidIncludingNull(initValue)
            input.AutoSelectAll = true
            input.OnChange = function()
                if isUuid and not IsUuidIncludingNull(input.Text) then return end

                setter(input.Text)
            end
            input.OnRightClick = function()
                input.Text = initValue
            end
            updateFunc = function()
                input.Text = getter()
            end
        elseif IsArrayOf(initValue, "string") or IsArrayOf(initValue, "boolean") then
            updateFunc = self:RenderArrayEditor(parent, field,
                function()
                    return LightCToArray(objGetter()[field])
                end,
                function(value)
                    objSetter(field, LightCToArray(value))
                end)
        elseif (type(initValue) == "table" or type(initValue) == "userdata") and not IsArray(initValue) then
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

if GLOBAL_DEBUG_WINDOW then
    local inputs = {}
    for _, resType in pairs({ "Atmosphere", "Lighting" }) do
        local resetBtn = GLOBAL_DEBUG_WINDOW:AddButton("Reset " .. resType .. " Resource")
        resetBtn.OnClick = function()
            local setChannel = nil
            if resType == "Atmosphere" then
                setChannel = NetChannel.SetAtmosphere
            else
                setChannel = NetChannel.SetLighting
            end
            setChannel:RequestToServer({ Reset = true }, function(response)
            end)
        end
        local allAtms = Ext.Resource.GetAll(resType)
        local nameMap = {}
        for _, atm in pairs(allAtms) do
            nameMap[atm] = atm
        end
        local nameArray = {}
        for name, _ in pairs(nameMap) do
            table.insert(nameArray, name)
        end
        table.sort(nameArray)
        local inputForCopy = GLOBAL_DEBUG_WINDOW:AddInputText("##" .. resType .. "ResourceToCopy", "")
        inputForCopy.AutoSelectAll = true
        inputs[resType] = inputForCopy
        local combo = GLOBAL_DEBUG_WINDOW:AddCombo("Select " .. resType .. " Resource")
        combo.OnHoverEnter = function()
            NetChannel["Get" .. resType]:RequestToServer({}, function(response)
                local currentUuid = response.Guid
                local allAvaiable = response.ResourceUUIDs
                local currentName = nil
                for name, uuid in pairs(nameMap) do
                    if uuid == currentUuid then
                        currentName = name
                        break
                    end
                end
                combo.Options = #allAvaiable > 0 and allAvaiable or nameArray
                if currentName then
                    combo.SelectedIndex = table.find(combo.Options, currentName) - 1
                else
                    combo.SelectedIndex = -1
                end
            end)
        end
        combo.OnChange = function(cmb)
            local selectedName = GetCombo(cmb)
            local resUuid = nameMap[selectedName]
            local editor = cachedResourceEditors[resUuid]
            if not editor then
                if resType == "Atmosphere" then
                    editor = AtmosphereEditor.new(resUuid)
                else
                    editor = LightingEditor.new(resUuid)
                end
                cachedResourceEditors[resUuid] = editor
            end

            local setChannel = editor.SetChannel
            setChannel:RequestToServer({ Apply = true, ResourceUUID = resUuid }, function(response)
            end)

            editor:Render()
            inputForCopy.Text = resUuid
        end
        inputForCopy.OnChange = Debounce(100, function(input)
            local keyWord = tostring(input.Text):lower()
            if keyWord == "" then
                combo.Options = nameArray
                return
            end
            local options = {}
            for _, name in pairs(nameArray) do
                if name:lower():find(keyWord) then
                    table.insert(options, name)
                end
            end
            combo.Options = options
        end)
        combo.Options = nameArray
        combo.HeightLarge = true
    end

    local notif = Notification.new("Resource Editor")
    GLOBAL_DEBUG_WINDOW:AddButton("Open Atmosphere Editor").OnClick = function()
        local cameraPos = {GetCameraPosition()}
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
    GLOBAL_DEBUG_WINDOW:AddButton("Open Lighting Editor").OnClick = function()
        local cameraPos = {GetCameraPosition()}
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
end
