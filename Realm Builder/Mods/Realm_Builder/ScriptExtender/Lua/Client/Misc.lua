--- some random stuff other mods already did
--- just putting it here for my own convenience

RegisterDebugWindow("Misc", function(panel)
    --#region PM Extra Data Editor
    local pmTree = ImguiElements.AddTree(panel, "PhotoMode ExtraData")
    local pmEDField = {
        "PhotoModeCameraMovementSpeed",
        "PhotoModeCameraRotationSpeed"
    }
    local alignedTable = ImguiElements.AddAlignedTable(pmTree)
    for i, string in pairs(pmEDField) do
        local getter = function()
            return Ext.Stats.GetStatsManager().ExtraData[string]
        end
        local setter = function(val)
            Ext.Stats.GetStatsManager().ExtraData[string] = val
        end
        alignedTable:AddSliderWithStep(string, getter(), 0, 10, 0.1, false)
        .OnChange = function(slider)
            setter(slider.Value[1])
        end
    end
    --#endregion PM Extra Data Editor

    --#region Photo Mode Camera Proxy
    --- @class PhotoModeCameraProxy : RB_MovableProxy
    --- @field Entity EntityHandle
    local PhotoModeCameraProxy = _Class("PhotoModeCameraProxy", MovableProxy)

    function PhotoModeCameraProxy:__init()
        local entity = Ext.Entity.GetAllEntitiesWithComponent("PhotoModeCameraTransform")[1]
        if not entity then
            self.IsValid = function() return false end
            return
        end
        self.Entity = entity
        self.StickTransform = self:GetTransform()
        local id
        local marker = nil
        NetChannel.CallOsiris:RequestToServer({
            Function = "CreateAt",
            Args = {
                MARKER_ITEM.SpotLight,
                self.StickTransform.Translate[1],
                self.StickTransform.Translate[2],
                self.StickTransform.Translate[3],
                0,
                0,
                ""
            }
        }, function(response)
            marker = response[1]
        end)
        id = Ext.Events.Tick:Subscribe(function(e)
            if not self:IsValid() then
                --- @diagnostic disable-next-line
                self.Stop()
                return
            end
            self.Entity.PhotoModeCameraTransform.Transform = self.StickTransform
            if marker then
                NetChannel.SetTransform:SendToServer({
                    Guid = marker,
                    Transforms = {
                        [marker] = self.StickTransform
                    }
                })
                return
            end
        end)
        self.Stop = function()
            --- @diagnostic disable-next-line
            NetChannel.Delete:SendToServer({ Guid = marker })
            Ext.Events.Tick:Unsubscribe(id)
            if self.OnStop then
                self.OnStop()
            end
        end
    end

    function PhotoModeCameraProxy:GetTransform()
        local comp = self.Entity.PhotoModeCameraTransform
        if not comp then
            return nil
        end
        return {
            Translate = Vec3.new(comp.Transform.Translate),
            RotationQuat = Quat.new(comp.Transform.RotationQuat),
            Scale = Vec3.new(1, 1, 1)
        }
    end

    function PhotoModeCameraProxy:SetTransform(transform)
        local comp = self.Entity.PhotoModeCameraTransform
        if not comp then
            return
        end
        if transform.Translate then
            comp.Transform.Translate = transform.Translate
        end
        if transform.RotationQuat then
            comp.Transform.RotationQuat = transform.RotationQuat
        end
        transform.Scale = { 1, 1, 1 }
        self.StickTransform = transform
    end

    function PhotoModeCameraProxy:IsValid()
        return self.Entity and self.Entity.PhotoModeCameraTransform ~= nil
    end

    local existProxy = nil
    local controlPMBtn = panel:AddButton("Control Photo Mode Camera")
    controlPMBtn.OnClick = function()
        if existProxy then
            existProxy:Stop()
            return
        end

        local proxy = PhotoModeCameraProxy.new()
        existProxy = proxy
        existProxy.OnStop = function()
            existProxy = nil
            controlPMBtn.Label = "Control Photo Mode Camera"
            RB_GLOBALS.TransformEditor:Select({})
        end
        RB_GLOBALS.TransformEditor:Select({ proxy })
        controlPMBtn.Label = "Stop Control Photo Mode Camera"
    end
    --#endregion

    --#region Photo Mode Camera Saver

    local cameraPosSaverWin = panel:AddTree("Photo Mode Camera Position Saver")
    local saveBtn = cameraPosSaverWin:AddButton("Save Position")
    local savedList = cameraPosSaverWin:AddGroup("Saved Positions")

    -- Ext.UI.GetRoot():Find("ContentRoot"):Child(21).DataContext.RecallCameraTransform:Execute()

    --- @type ({Transform:Transform, Time:string})[]
    local savedQueue = {}

    local saveLabelPattern = "[%d] - %s"

    local refreshSavedList

    local saveCurrent

    function saveCurrent()
        local cam = RBGetCamera()
        if not cam or not cam.PhotoModeCameraSavedTransform then return end
        local camTransform = cam.Transform.Transform
    
        local copy = {
            Translate = Vec3.new(camTransform.Translate),
            RotationQuat = Quat.new(camTransform.RotationQuat),
            Scale = Vec3.new(1, 1, 1)
        }
        table.insert(savedQueue, {
            Transform = copy,
            Time = RBUtils.GetFormatHMS(),
        })
        if #savedQueue > 20 then
            table.remove(savedQueue, 1)
        end
        refreshSavedList()
    end

    function refreshSavedList()
        ImguiHelpers.DestroyAllChildren(savedList)
        for i, save in pairs(savedQueue) do
            local label = string.format(saveLabelPattern, i, save.Time)
            local btn = savedList:AddButton(label)
            btn.OnClick = function()
                local cam = RBGetCamera()
                if not cam or not cam.PhotoModeCameraSavedTransform then return end
                cam.PhotoModeCameraSavedTransform.Transform = save.Transform
                Ext.OnNextTick(function()
                    --- @diagnostic disable-next-line
                    Ext.UI.GetRoot():Find("ContentRoot"):Child(21).DataContext.RecallCameraTransform:Execute()
                end)
            end
            btn.OnRightClick = function()
                table.remove(savedQueue, i)
                refreshSavedList()
            end
        end
    end

    saveBtn.OnClick = function()
        saveCurrent()
    end
    refreshSavedList()
    --#endregion Photo Mode Camera Saver
end)


local PhysicsGroupFlags = Ext.Enums.PhysicsGroupFlags
local PhysicsType = Ext.Enums.PhysicsType

local configurableIntersect = {
    Distance = 50,
    PhysicsType = PhysicsType.Dynamic | PhysicsType.Static,
    PhysicsGroupFlags = PhysicsGroupFlags.Item
        | PhysicsGroupFlags.Character
        | PhysicsGroupFlags.Scenery
        | PhysicsGroupFlags.VisibleItem,
    PhysicsGroupFlagsExclude = PhysicsGroupFlags.Terrain,
    Function = "RaycastClosest"
}

--- @return PhxPhysicsHit|PhxPhysicsHitAll
function Ray:IntersectDebug()
    return Ext.Level[configurableIntersect.Function](self.Origin, self:At(configurableIntersect.Distance),
        configurableIntersect.PhysicsType,
        configurableIntersect.PhysicsGroupFlags, configurableIntersect.PhysicsGroupFlagsExclude, 1)
end

RegisterDebugWindow("Raycast Debugger", function(panel)
    local aligned = ImguiElements.AddAlignedTable(panel)
    local funcCombo = aligned:AddCombo("Function")
    funcCombo.Options = { "RaycastClosest", "RaycastAll" }
    funcCombo.SelectedIndex = 0
    funcCombo.OnChange = function(ev)
        configurableIntersect.Function = ImguiHelpers.GetCombo(ev)
    end

    local distance = aligned:AddSliderWithStep("Distance", configurableIntersect.Distance, 1, 500, 1, false)

    local physTypeOptions = ImguiHelpers.CreateRadioButtonOptionFromBitmask("PhysicsType")
    local ptC = aligned:AddNewLine("Physic Type")


    local physTypeRadio = ImguiElements.AddBitmaskRadioButtons(ptC, physTypeOptions, configurableIntersect.PhysicsType)
    physTypeRadio.OnChange = function(radioBtn, value)
        configurableIntersect.PhysicsType = value
    end


    --- @type RadioButtonOption[]
    local options = ImguiHelpers.CreateRadioButtonOptionFromBitmask("PhysicsGroupFlags")
    local includeCell = aligned:AddNewLine("Include Groups")
    local includeAll = includeCell:AddButton("Include All")
    local unincludeAll = includeCell:AddButton("Uninclude All")
    local includeGroup = ImguiElements.AddBitmaskRadioButtons(includeCell, options,
        configurableIntersect.PhysicsGroupFlags)
    includeGroup.OnChange = function(radioBtn, value)
        configurableIntersect.PhysicsGroupFlags = value
    end
    includeAll.OnClick = function()
        configurableIntersect.PhysicsGroupFlags = 0xFFFFFFFF
        includeGroup.Value = configurableIntersect.PhysicsGroupFlags
    end
    unincludeAll.OnClick = function()
        configurableIntersect.PhysicsGroupFlags = 0
        includeGroup.Value = configurableIntersect.PhysicsGroupFlags
    end

    local excludeCell = aligned:AddNewLine("Exclude Groups")
    local excludeGroup = ImguiElements.AddBitmaskRadioButtons(excludeCell, options,
        configurableIntersect.PhysicsGroupFlagsExclude)

    excludeGroup.OnChange = function(radioBtn, value)
        configurableIntersect.PhysicsGroupFlagsExclude = value
    end

    local wrappos = 8
    includeGroup.WrapPos = wrappos
    excludeGroup.WrapPos = wrappos

    local inGameWin = Notification.new("In-Game Raycast Debugger")
    inGameWin.AutoFadeOut = false
    local debugBtn = panel:AddButton("Debug Raycast")
    debugBtn.OnClick = function()
        local ray = ScreenToWorldRay()
        if not ray then
            return
        end
        local hit = ray:IntersectDebug()
        if hit then
            inGameWin:Show("Raycast Hit!", function(panel)
                local text, origin = RainbowDumpTable(hit)
                panel:AddText(origin)
            end)
            if configurableIntersect.Function == "RaycastAll" then
                local cnt = #hit.Distances
                for i = 1, cnt do
                    local pos = hit.Positions[i]
                    local quat = MathUtils.DirectionToQuat(hit.Normals[i], nil, "Y")
                    NetChannel.Visualize:RequestToServer({
                        Type = "Point",
                        Position = pos,
                        Rotation = quat,
                        Duration = 3000,
                    }, function(response)

                    end)
                end
            else
                if hit.Position and hit.Normal then
                    local pos = hit.Position
                    local quat = MathUtils.DirectionToQuat(hit.Normal, nil, "Y")
                    NetChannel.Visualize:RequestToServer({
                        Type = "Point",
                        Position = pos,
                        Rotation = quat,
                        Duration = 3000,
                    }, function(response)

                    end)
                end
            end
        else
            inGameWin:Show("Raycast Missed!",
                "Origin: " ..
                tostring(ray.Origin) .. "\nDestination: " .. tostring(ray:At(configurableIntersect.Distance)))
        end
    end

    local keySybBtn = panel:AddButton("Toggle Raycast Debugger (F2)")
    local f2keySub = nil

    local function subf2Key()
        f2keySub = InputEvents.SubscribeKeyInput({}, function(e)
            if e.Key ~= "F2" or e.Event == "KeyUp" then
                return
            end
            debugBtn.OnClick()
        end)
    end
    local function unsubf2Key()
        if f2keySub then
            f2keySub:Unsubscribe()
            f2keySub = nil
        end
    end

    keySybBtn.OnClick = function(btn)
        if f2keySub then
            unsubf2Key()
            btn.Label = "Toggle Raycast Debugger (F2)"
            return
        end
        subf2Key()
        btn.Label = "Unsub Raycast Debugger (F2)"
    end

    
end)