--- @class AtmosEditor
--- @field Resource ResourceAtmosphereResource
--- @field ModifedResource ResourceAtmosphere
--- @field ResourceUUID string
AtmosEditor = {}
AtmosEditor = _Class("AtmosEditor")

--- @class LightingEditor
--- @field Resource ResourceLightingResource
--- @field ModfiedResource Lighting
--- @field ResourceUUID string
LightingEditor = _Class("LightingEditor", AtmosEditor)
local atmosEditorCache = {}

local readOnlyFields = {
    "GUID",
    "Guid"
}

local preassignSettings = {
    
}

function AtmosEditor:__init(resourceID, displayName)
    local res = Ext.Resource.Get(resourceID, "Atmosphere") --[[@as ResourceAtmosphereResource]]

    self.ResourceUUID = resourceID
    self.ModfiedResource = {}
    self.ResourceType = "Atmosphere"
    self.SetChannel = NetChannel.SetAtmosphere
    self:SaveInitialState()
end

function LightingEditor:__init(resourceID, displayName)
    local res = Ext.Resource.Get(resourceID, "Lighting") --[[@as ResourceLightingResource]]

    self.ResourceUUID = resourceID
    self.ModfiedResource = {}
    self.ResourceType = "Lighting"
    self.SetChannel = NetChannel.SetLighting
    self:SaveInitialState()
end

function AtmosEditor:SaveInitialState()
    local res = Ext.Resource.Get(self.ResourceUUID, self.ResourceType)
    self.InitialState = DeepCopy(res[self.ResourceType])
end

function AtmosEditor:Render()
    local window = RegisterWindow(self.ResourceUUID, "Realm Builder - Resource Editor - " .. self.ResourceType, "Resource Editor")

    local resetBtn = window:AddButton("Reset to Initial State")
    resetBtn.OnClick = function ()
        self.SetChannel:RequestToServer({ Reset = true }, function (response)
            if response then
                print("Resource reset successfully.")
            else
                print("Failed to reset atmosphere.")
            end
        end)
    end

    local applyBtn = window:AddButton("Apply " .. self.ResourceType)
    applyBtn.OnClick = function ()
        self.SetChannel:RequestToServer({ Apply = true, ResourceUUID = self.ResourceUUID }, function (response)
            if response then
                print("Resource applied successfully.")
            else
                print("Failed to apply atmosphere.")
            end
        end)
    end

    self.ModfiedResource = {}
    self:RenderEditor(window, self.ResourceType, function()
        local res = Ext.Resource.Get(self.ResourceUUID, self.ResourceType) --[[@as ResourceAtmosphereResource]]
        return res[self.ResourceType]
    end,
    self.ModfiedResource, 
    function ()
        self.SetChannel:RequestToServer({ [self.ResourceType] = self.ModfiedResource, ResourceUUID = self.ResourceUUID }, function (response)
            if response then
                print("Atmosphere updated successfully.")
            else
                print("Failed to update atmosphere.")
            end
        end)
        Timer:Ticks(30, function ()
            self.SetChannel:RequestToServer({ Apply = true, ResourceUUID = self.ResourceUUID }, function (response)
                if response then
                    print("Atmosphere applied successfully.")
                else
                    print("Failed to apply atmosphere.")
                end
            end)
        end)
    end)
end

function AtmosEditor:RenderArrayEditor(parent, label, objGetter, objSetter)
    local tree = StyleHelpers.AddTree(parent, label, true)
    local array = objGetter()
    
    local tab = tree:AddTable(label .. "Table", 1)
    local row = tab:AddRow()

    local arrayValueType = type(array[1])
    
    --- @type function
    local refresh
    function refresh()
        row:Destroy()
        row = tab:AddRow()
        for i, value in ipairs(objGetter()) do
            local cell = row:AddCell(tostring(value))
            local removeBtn = cell:AddButton("-")
            removeBtn.OnClick = function ()
                local arr = LightCToArray(objGetter())
                table.remove(arr, i)
                objSetter(arr)
                refresh()
            end
            if type(value) == "string" then
                local input = cell:AddInputText("## string" .. label .. i .. "Setter", value)
                input.OnChange = function (text)
                    local arr = objGetter()
                    arr[i] = text.Text
                    objSetter(arr)
                end
                input.SameLine = true
            elseif type(value) == "boolean" then
                local input = cell:AddCheckbox("## boolean " .. label .. i .. "Setter", value)
                input.OnChange = function (checkbox)
                    local arr = objGetter()
                    arr[i] = checkbox.Checked
                    objSetter(arr)
                end
                input.SameLine = true
            end
        end
        local addCell = row:AddCell("+")
        addCell:AddButton("+").OnClick = function ()
            local arr = LightCToArray(objGetter())
            table.insert(arr, arrayValueType == "string" and "" or false)
            objSetter(arr)
            refresh()
        end
    end

    refresh()
end

function AtmosEditor:RenderEditor(parent, label, objGetter, objSetter, objUpdater)
    local tree = StyleHelpers.AddTree(parent, label, true)
    for field, initValue in pairs(objGetter()) do
        if readOnlyFields[field] then
            goto continue
        end

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
                    objSetter[field] = value[1]
                else
                    objSetter[field] = value
                end
                objUpdater()
            end

            StyleHelpers.RenderNumberSliders(tree, field, getter, setter, { PreferSliders = field:find("Color") ~= nil })
        elseif type(initValue) == "boolean" then
            local function getter()
                return objGetter()[field]
            end

            local function setter(value)
                objSetter[field] = value
                objUpdater()
            end

            local checkBox = tree:AddCheckbox(field .. "##" .. tostring(objGetter), initValue)
            checkBox.OnChange = function ()
                setter(checkBox.Checked)
            end
        elseif IsArrayOf(initValue, "string") or IsArrayOf(initValue, "boolean") then
            self:RenderArrayEditor(tree, field,
            function()
                return objGetter()[field]
            end,
            function(value)
                objSetter[field] = LightCToArray(value)
                objUpdater()
            end)
        elseif (type(initValue) == "table" or type(initValue) == "userdata") and not IsArray(initValue) then
            local subTree = tree:AddTree(field, true)
            objSetter[field] = objSetter[field] or {}
            self:RenderEditor(subTree, field, function()
                return objGetter()[field]
            end,
            objSetter[field],
            objUpdater)
        end

        ::continue::
    end
end

RegisterConsoleCommand("rb_open_atmos_editor", function(cmd)
    NetChannel.GetAtmosphere:RequestToServer({}, function (response)
        local atmosphereUuid = response.Guid
        if atmosphereUuid == "" then
            print("No atmosphere trigger found in the current realm.")
            return
        end

        local editor = atmosEditorCache[atmosphereUuid]
        if not editor then
            editor = AtmosEditor.new(atmosphereUuid)
            atmosEditorCache[atmosphereUuid] = editor
        end

        editor:Render()
    end)
end)

if GLOBAL_DEBUG_WINDOW then
    GLOBAL_DEBUG_WINDOW:AddButton("Open Atmosphere Editor").OnClick = function ()
        NetChannel.GetAtmosphere:RequestToServer({}, function (response)
            local atmosphereUuid = response.Guid
            if atmosphereUuid == "" then
                print("No atmosphere trigger found in the current realm.")
                return
            end

            local editor = atmosEditorCache[atmosphereUuid]
            if not editor then
                editor = AtmosEditor.new(atmosphereUuid)
                atmosEditorCache[atmosphereUuid] = editor
            end

            editor:Render()
        end)
    end
    GLOBAL_DEBUG_WINDOW:AddButton("Open Lighting Editor").OnClick = function ()
        NetChannel.GetLighting:RequestToServer({}, function (response)
            local lightingUuid = response.Guid
            if lightingUuid == "" then
                --print("No lighting trigger found in the current realm.")
                --return
                lightingUuid = Ext.Resource.GetAll("Lighting")[1]
            end

            local editor = atmosEditorCache[lightingUuid]
            if not editor then
                editor = LightingEditor.new(lightingUuid)
                atmosEditorCache[lightingUuid] = editor
            end

            editor:Render()
        end)
    end
end