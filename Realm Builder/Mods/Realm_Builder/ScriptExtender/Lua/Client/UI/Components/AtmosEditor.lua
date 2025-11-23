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
    "GUID",
    "Guid"
}

local preassignedRanged = {
    Yaw = { Min = 0, Max = 180, Step = 1 },
    Pitch = { Min = 0, Max = 180, Step = 1 },
    Roll = { Min = 0, Max = 180, Step = 1 },
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
    local window = RegisterWindow(self.ResourceUUID, "Realm Builder - Resource Editor - " .. self.ResourceType, "Resource Editor")
    window.Closeable = true

    self.Panel = window
    local updateUIState = nil
    local setter = function ()
        self.SetChannel:RequestToServer({ [self.ResourceType] = self.ModfiedResource, ResourceUUID = self.ResourceUUID }, function (response)
            if response then
                print(self.ResourceType .. " updated successfully.")
            else
                print("Failed to update atmosphere.")
            end
            self.SetChannel:RequestToServer({ Apply = true, ResourceUUID = self.ResourceUUID }, function (response)
                if response then
                    print(self.ResourceType .. " applied successfully.")
                else
                    print("Failed to apply atmosphere.")
                end
                if updateUIState then
                    _D(Ext.Resource.Get(self.ResourceUUID, self.ResourceType))
                    updateUIState()
                end
            end)
        end)
    end

    local resetBtn = window:AddButton("Reset World " .. self.ResourceType)
    resetBtn.OnClick = function ()
        self.SetChannel:RequestToServer({ Reset = true }, function (response)
            if response then
                print("Resource reset successfully.")
            else
                print("Failed to reset atmosphere.")
            end
            if updateUIState then
                updateUIState()
            end
        end)
    end

    local applyBtn = window:AddButton("Set " .. self.ResourceType)
    applyBtn.OnClick = function ()
        setter()
    end

    local resetThisBtn = window:AddButton("Reset Changes")
    resetThisBtn.OnClick = function ()
        self.ModfiedResource = DeepCopy(self.InitialState)
        setter()
    end

    self.ModfiedResource = {}
    updateUIState = self:RenderEditor(window, self.ResourceType, function(returnModfied)
        if returnModfied then
            return self.ModfiedResource
        end
        local res = Ext.Resource.Get(self.ResourceUUID, self.ResourceType) --[[@as ResourceAtmosphereResource]]
        return res[self.ResourceType]
    end,
    function (field, value)
        self.ModfiedResource[field] = value
        setter()
    end)
end

function ResourceEditor:RenderArrayEditor(parent, label, objGetter, objSetter)
    local tree = StyleHelpers.AddTree(parent, label, true)
    
    local tab = tree:AddTable(label .. "Table", 1)
    local row = tab:AddRow()
    
    --- @type function
    local refresh
    function refresh()
        row:Destroy()
        row = tab:AddRow()
        for i, value in ipairs(objGetter()) do
            local cell = row:AddCell(tostring(value))
            if type(value) == "string" then
                local input = cell:AddInputText("## string" .. label .. i .. "Setter", value)
                input.OnChange = function (text)
                    local arr = objGetter()
                    arr[i] = text.Text
                    objSetter(arr)
                end
            elseif type(value) == "boolean" then
                local input = cell:AddCheckbox("## boolean " .. label .. i .. "Setter", value)
                input.OnChange = function (checkbox)
                    local arr = objGetter()
                    arr[i] = checkbox.Checked
                    objSetter(arr)
                end
            end
        end
    end

    refresh()

    return refresh
end

function ResourceEditor:RenderEditor(parent, label, objGetter, objSetter)
    local tree = StyleHelpers.AddTree(parent, label, true)

    local updateFuncs = {}
    local updateUIState = function()
        for _, func in pairs(updateFuncs) do
            func()
        end
    end

    for field, initValue in SortedPairs(objGetter()) do
        if readOnlyFields[field] then
            goto continue
        end
        local updateFunc = nil

        if type(initValue) == "number" or IsArrayOf(initValue, "number") then
            local function getter()
                local val = objGetter()[field]
                if type(val) == "number" then
                    return {val}
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
            local range = preassignedRanged[field]
            if not range then
                if currentVal[1] == 0 then
                    currentVal[1] = 1
                end
                range = {
                    Max = currentVal[1] * 10,
                    Min = 0,
                    Step = currentVal[1] / 10
                }
            end

            updateFunc = StyleHelpers.RenderNumberSliders(tree, field, getter, setter, { PreferSliders = field:find("Color") ~= nil, Range = range, IsInt = math.type(currentVal[1]) == "integer" })
        elseif type(initValue) == "boolean" then
            local function getter()
                return objGetter()[field]
            end

            local function setter(value)
                objSetter(field, value)
            end

            local checkBox = tree:AddCheckbox(field .. "##" .. tostring(objGetter), initValue)
            checkBox.OnChange = function ()
                setter(checkBox.Checked)
            end

            updateFunc = function ()
                checkBox.Checked = getter()
            end
        elseif IsArrayOf(initValue, "string") or IsArrayOf(initValue, "boolean") then
            updateFunc = self:RenderArrayEditor(tree, field,
            function()
                return LightCToArray(objGetter()[field])
            end,
            function(value)
                objSetter(field, LightCToArray(value))
            end)
        elseif (type(initValue) == "table" or type(initValue) == "userdata") and not IsArray(initValue) then
            local subTree = tree:AddTree(field)
            objSetter(field, {})
            updateFunc = self:RenderEditor(subTree, field, function(returnModfied)
                if returnModfied then
                    return objGetter(true)[field]
                end
                return objGetter()[field]
            end,
            function(subField, value)
                local tbl = objGetter(true)[field]
                tbl[subField] = value
                objSetter(field, tbl)
            end)
        end

        table.insert(updateFuncs, updateFunc)
        ::continue::
    end

    return updateUIState
end

if GLOBAL_DEBUG_WINDOW then
    local inputs = {}
    for _, resType in pairs({"Atmosphere", "Lighting"}) do
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
        inputForCopy.ReadOnly = true
        inputForCopy.AutoSelectAll = true
        inputs[resType] = inputForCopy
        local combo = GLOBAL_DEBUG_WINDOW:AddCombo("Select " .. resType .. " Resource")
        combo.OnChange = function (cmb)
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

            editor:Render()
            inputForCopy.Text = resUuid
        end
        combo.Options = nameArray
    end

    GLOBAL_DEBUG_WINDOW:AddButton("Open Atmosphere Editor").OnClick = function ()
        NetChannel.GetAtmosphere:RequestToServer({}, function (response)
            local atmosphereUuid = response.Guid
            if atmosphereUuid == "" then
                print("No atmosphere trigger found in the current level.")
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
    GLOBAL_DEBUG_WINDOW:AddButton("Open Lighting Editor").OnClick = function ()
        NetChannel.GetLighting:RequestToServer({}, function (response)
            local lightingUuid = response.Guid
            if lightingUuid == "" then
                print("No lighting trigger found in the current level.")
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