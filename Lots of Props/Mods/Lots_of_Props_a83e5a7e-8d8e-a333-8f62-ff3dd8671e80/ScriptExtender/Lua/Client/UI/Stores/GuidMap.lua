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
                    post.DummyDestroyed = true
                    break
                end
                local x, y, z = VisualHelpers.GetVisualPosition(dummy)
                local pitch, yaw, roll, w = VisualHelpers.GetVisualRotation(dummy)
                dummiesInfo[uuid] = {}
                dummiesInfo[uuid].Position = {x, y, z}
                dummiesInfo[uuid].Rotation = {pitch, yaw, roll, w}
            end
            post.DummyInfos = dummiesInfo

            Post("UpdateDummies", post)
        end

        --postUpdateDummies()

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

ClientSubscribe("NewTemplate", function(data)
    
    SaveDefaultVisualValues(data.Guid, data.TemplateName)
end)

function SaveDefaultVisualValues(guid, templateName, retryCnt)
    if ClientOriginalVisualData[templateName] then
        return
    end

    local maxRetries = 10
    retryCnt = retryCnt or 0
    local entity = Ext.Entity.Get(guid)
    if not entity then
        if retryCnt < maxRetries then
            if retryCnt == 0 then
                Warning("SaveDefaultValues: Entity not found for GUID: " .. guid .. ", retrying...")
            end
            Timer:After(10, function()
                SaveDefaultVisualValues(guid, templateName, retryCnt + 1)
            end)
            return
        else
            Warning("SaveDefaultValues: Failed to find entity with GUID: " .. guid .. " after " .. maxRetries .. " retries")
            return
        end
    end
    local newDefaults = {}
    if entity.Visual and entity.Visual.Visual and entity.Visual.Visual.ObjectDescs then
        for descIndex, desc in ipairs(entity.Visual.Visual.ObjectDescs) do
            if desc.Renderable and desc.Renderable.ActiveMaterial then
                local material = desc.Renderable.ActiveMaterial.Material
                local materialName = GetLastPath(material.Parent.Name)

                for paramIndex, param in ipairs(material.Parameters.ScalarParameters) do
                    local key = materialName .. "::" .. descIndex .. "::" .. param.ParameterName
                    newDefaults[key] = param.Value
                end

                for paramIndex, param in ipairs(material.Parameters.Vector2Parameters) do
                    local key = materialName .. "::" .. descIndex .. "::" .. param.ParameterName
                    newDefaults[key] = {param.Value[1], param.Value[2]}
                end

                for paramIndex, param in ipairs(material.Parameters.Vector3Parameters) do
                    local key = materialName .. "::" .. descIndex .. "::" .. param.ParameterName
                    newDefaults[key] = {param.Value[1], param.Value[2], param.Value[3]}
                end

                for paramIndex, param in ipairs(material.Parameters.VectorParameters) do
                    local key = materialName .. "::" .. descIndex .. "::" .. param.ParameterName
                    newDefaults[key] = {param.Value[1], param.Value[2], param.Value[3], param.Value[4]}
                end

                if desc.Renderable.WorldTransform then
                    local scaleKey = materialName .. "::" .. descIndex .. "::Scale"
                    local scale = desc.Renderable.WorldTransform.Scale
                    newDefaults[scaleKey] = {scale[1], scale[2], scale[3]}
                end
            end
        end
    end

    local propNameMap = {
        ["Appearance.Flicker Amount"] = "Flicker Amount",
        ["Appearance.Intensity"] = "Intensity",
        ["Appearance.Radius"] = "Radius",
        ["Behavior.Flicker Speed"] = "Flicker Speed"
    }

    local boolPropNames = {
        OverrideLightTemplateColor = true,
        OverrideLightTemplateFlickerSpeed = true,
        ModulateLightTemplateRadius = true,
    }

    local entityPropNameMap = {
        --Kelvin = {min=1000, max=40000, step=100, displayName = "Template_Kelvin" , isTemplate = true},
        SpotLightInnerAngle = {},
        SpotLightOuterAngle = {},
        Gain = {},
        EdgeSharpening = {},
        Intensity = {isTemplate = true},
        Radius = {isTemplate = true},
        ScatteringIntensityScale = {},
        Blackbody = {},
        DirectionLightDimensions = {},
        Color = {}
    }

    if entity.Effect and entity.Effect.Timeline and entity.Effect.Timeline.Components then
        for compIndex, component in ipairs(entity.Effect.Timeline.Components) do
            if component.TypeName == "Light" then
                for propName, property in pairs(component.Properties) do
                    if propName == "Appearance.Color" and property.Frames and property.Frames[1] and property.Frames[1].Color then
                        local key = "Light::" .. compIndex .. "::" .. propName
                        local color = property.Frames[1].Color
                        newDefaults[key] = {color[1], color[2], color[3], color[4]}
                    elseif propNameMap[propName] and property.KeyFrames and property.KeyFrames[1] and property.KeyFrames[1].Frames and property.KeyFrames[1].Frames[1] then
                        local key = "Light::" .. compIndex .. "::" .. propName
                        local frame = property.KeyFrames[1].Frames[1]
                        local hasValue = false
                        for type, value in pairs(property.KeyFrames[1].Frames[1]) do
                            if type == "Value" and value then
                                hasValue = true
                                break
                            end
                        end
                        if hasValue then
                            newDefaults[key] = frame.Value
                        elseif frame.A and frame.B and frame.C and frame.D then
                            newDefaults[key] = {frame.A, frame.B, frame.C, frame.D}
                        end
                    end
                end

                for boolName,_ in pairs(boolPropNames) do
                    local boolKey = "Light::" .. compIndex .. "::" .. boolName
                    newDefaults[boolKey] = component[boolName]
                end

                
                local light = VisualHelpers.GetLightEntity(entity, compIndex)
                if light then
                   for propName, propInfo in pairs(entityPropNameMap) do
                        if light[propName] then
                            local key = "LightEntity::" .. compIndex .. "::" .. propName
                            newDefaults[key] = light[propName]
                            if propInfo.isTemplate then
                                newDefaults[key] = light.Template[propName]
                            end
                        end
                    end

                end
            elseif component.TypeName == "ParticleSystem" then
                if component.Color then
                    local colorKey = "ParticleSystem::" .. compIndex .. "::Color"
                    newDefaults[colorKey] = {component.Color[1], component.Color[2], component.Color[3], component.Color[4]}
                end
                if component.Brightness_ then
                    local brightnessKey = "ParticleSystem::" .. compIndex .. "::Brightness"
                    newDefaults[brightnessKey] = component.Brightness_
                end
                if component.UniformScale then
                    local scaleKey = "ParticleSystem::" .. compIndex .. "::UniformScale"
                    newDefaults[scaleKey] = component.UniformScale
                end
            end
        end
    end

    if not newDefaults or next(newDefaults) == nil then
        if retryCnt < maxRetries then
            if retryCnt == 0 then
                Warning("SaveDefaultValues: No visual data found for entity with GUID: " .. guid .. ", retrying...")
            end
            Timer:After(10, function()
                SaveDefaultVisualValues(guid, templateName, retryCnt + 1)
            end)
            return
        else
            Warning("SaveDefaultValues: Failed to save visual data for GUID: " .. guid .. " after " .. maxRetries .. " retries - no data found")
            return
        end
    end

    ClientOriginalVisualData[templateName] = newDefaults
    --Info("New template created: '" .. templateName .. "' with GUID: " .. guid .. " - saved  default values: \n" .. tostring(Ext.DumpExport(newDefaults)))
end

RegisterOnSessionLoaded(function()
    --local now = Ext.Utils.MonotonicTime()
    LoadVisualPresetData()
    ClearOriginalVisualData()
    --Debug("Visual preset data loaded in " .. (Ext.Utils.MonotonicTime() - now) .. "ms")
end)

--#endregion VisualPreset