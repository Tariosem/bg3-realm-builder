local dummyUpdateTimer = nil 

--- @diagnostic disable-next-line
Ext.Entity.OnCreate("Visual", function (entity)
    if not entity then
        return
    end

    if IsDummy(entity) then
        --_P("Found dummy")
        local partyMembers = GetAllPartyMembers()
        for _, member in ipairs(partyMembers) do
            local uuid = member --[[@as string]]
            local memberHandle = UuidToHandle(uuid)
            if EqualArrays(memberHandle.Transform.Transform.Translate, entity.Transform.Transform.Translate) then
                Debug("Found dummy and coresponding party member : " .. memberHandle.DisplayName.Name:Get())
                SetClientDummyEntity(uuid, entity)
            end
        end

        local function postUpdateDummies()
            local dummiesInfo = {}
            local post = {}
            for uuid, dummy in pairs(GetAllDummies()) do
                if #dummy:GetAllComponentNames() == 0 then
                    ClearDummyData()
                    Timer:Cancel(dummyUpdateTimer)
                    dummyUpdateTimer = nil
                    post.Deactive = true
                    break
                end
                local x, y, z = VisualHelpers.GetVisualPosition(dummy)
                local pitch, yaw, roll, w = VisualHelpers.GetVisualRotation(dummy)
                dummiesInfo[uuid] = {}
                dummiesInfo[uuid].Position = {x, y, z}
                dummiesInfo[uuid].Rotation = {pitch, yaw, roll, w}
            end
            post.DummyInfos = dummiesInfo

            NetChannel.UpdateDummies:SendToServer(post)
        end

        if not dummyUpdateTimer then
            dummyUpdateTimer = Timer:EveryFrame(function()
                postUpdateDummies()
            end)
        end
    end
end)

--#region VisualPreset

ClientVisualPresetData = {}
ClientOriginalVisualData = {}
ClientPresetData = {}

local function LoadVisualPresetData()
    local refFile = GetVisualReferencePath()
    local refData = Ext.Json.Parse(Ext.IO.LoadFile(refFile) or "{}")
    for templateName, data in pairs(refData) do
        local visualPresetFile = GetVisualPresetsPath(templateName)
        local visualPresetData = Ext.Json.Parse(Ext.IO.LoadFile(visualPresetFile) or "{}")
        if visualPresetData then
            ClientVisualPresetData[templateName] = visualPresetData
        else
            Warning("VisualPresetDataLoadFromFile: Failed to load preset data for template: " .. templateName)
        end
    end
end

local function UpdateVisualPresetDataFromServer(data)
    for templateName, presets in pairs(data) do
        if not ClientVisualPresetData[templateName] then
            ClientVisualPresetData[templateName] = {}
        end
        for presetName, presetData in pairs(presets) do
            if not ClientVisualPresetData[templateName][presetName] then
                ClientVisualPresetData[templateName][presetName] = presetData
            end
        end
    end
end

local function UpdatePresetDataFromServer(data)
    if not data or not data.Presets then
        Warning("UpdatePresetDataFromServer: Invalid data received")
        return
    end

    for name, presetData in ipairs(data) do
        if not ClientPresetData[name] then
            ClientPresetData[name] = presetData 
        end
    end
end

local function ClearOriginalVisualData(templateName)
    if templateName then
        ClientOriginalVisualData[templateName] = nil
    else
        ClientOriginalVisualData = {}
    end
    --Info("Cleared original visual data for template: " .. tostring(templateName or "all"))
end

function GetVisualPresetData(templateName, presetName)
    if not templateName or not presetName then
        Warning("GetVisualPresetData: Invalid templateName or presetName")
        return nil
    end

    local templateData = ClientVisualPresetData[templateName]
    if not templateData then
        Warning("GetVisualPresetData: No data found for template: " .. templateName)
        return nil
    end

    return templateData[presetName]
end

ClientSubscribe("ServerVisualPreset", function(data)
    UpdateVisualPresetDataFromServer(data)
end)

ClientSubscribe("ServerPreset", function(data)
    UpdatePresetDataFromServer(data)
end)

RegisterOnSessionLoaded(function()
    --local now = Ext.Utils.MonotonicTime()
    LoadVisualPresetData()
    ClearOriginalVisualData()
    --Debug("Visual preset data loaded in " .. (Ext.Utils.MonotonicTime() - now) .. "ms")
end)

--#endregion VisualPreset