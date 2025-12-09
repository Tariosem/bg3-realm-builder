--- some random stuff other mods already did
--- just putting it here for my own convenience
if not Ext.Debug.IsDeveloperMode() then return end

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
        self.Stop = function ()
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
    function refreshSavedList()
        ImguiHelpers.DestroyAllChildren(savedList)
        for i, save in pairs(savedQueue) do
            local label = string.format(saveLabelPattern, i, save.Time)
            local btn = savedList:AddButton(label)
            btn.OnClick = function()
                local cam = RBGetCamera()
                if not cam or not cam.PhotoModeCameraSavedTransform then return end
                cam.PhotoModeCameraSavedTransform.field_0 = save.Transform
                Ext.OnNextTick(function()
                    --- @diagnostic disable-next-line
                    Ext.UI.GetRoot():Find("ContentRoot"):Child(21).DataContext.RecallCameraTransform:Execute()
                end)
            end
            btn.OnRightClick = function ()
                table.remove(savedQueue, i)
                refreshSavedList()
            end
        end
    end

    saveBtn.OnClick = function()
        local cam = RBGetCamera()
        if not cam or not cam.PhotoModeCameraSavedTransform then return end
        local camTransform = cam.Transform.Transform
        local copy = {
            Translate = Vec3.new(camTransform.Translate),
            RotationQuat = Quat.new(camTransform.RotationQuat),
            Scale = Vec3.new(1,1,1)
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
    refreshSavedList()
    --#endregion Photo Mode Camera Saver
    
end)
