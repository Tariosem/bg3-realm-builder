--- @class GizmoManager
--- @field Gizmos table<string, {Type: string, Space: string, StickTarget: GUIDSTRING[], Gizmo: string}>
--- @field StickTimers table<string, TimerID>
--- @field CreateGizmo fun(self: GizmoManager, target: string|string[], gizmoType: string, gizmoSpace: string, userID: string): string
--- @field UpdateGizmoSetting fun(self: GizmoManager, gizmoType: string, gizmoSpace: string, guid: string)
--- @field UpdateGizmoTransform fun(self: GizmoManager, guid: string)
--- @field SetupStickTimer fun(self: GizmoManager, guid: string)
GizmoManager = {
    Gizmos = {},
    StickTimers = {}
}

function GizmoManager:CreateGizmo(target, gizmoType, gizmoSpace, userID)
    if not GIZMO_ITEM[gizmoType] then
        Warning("Invalid gizmo type: "..tostring(gizmoType))
        return ""
    end 

    if not target then
        Warning("GizmoManager: No target provided for gizmo creation.")
        return ""
    end

    Debug("GizmoManager: Creating gizmo of type "..tostring(gizmoType).." in "..tostring(gizmoSpace).." space for GUID: "..tostring(target))

    local guids = NormalizeGuidList(target)

    --- @diagnostic disable-next-line: param-type-mismatch
    local targetPos = {Osi.GetPosition(guids[1])}
    local targetRot = gizmoSpace == "World" and {0,0,0,1} or {CGetRotation(guids[1])}

    local gizmo = Osi.CreateAt(GIZMO_ITEM[gizmoType], targetPos[1], targetPos[2], targetPos[3], 0, 0, "") --[[@as string]]
    Osi.SetVisible(gizmo, 0)
    RotateTo(gizmo, table.unpack(targetRot))
    Timer:Ticks(10, function (timerID)
        Osi.SetVisible(gizmo, 1)
    end)

    self.Gizmos[gizmo] = {
        Mode = gizmoType,
        Space = gizmoSpace,
        StickTarget = guids,
        Gizmo = gizmo, --[[@as string]]
        User = userID
    }

    self:SetupStickTimer(gizmo)
    self:PostGizmoUpdate(gizmo)

    return gizmo --[[@as string]]
end

function GizmoManager:UpdateGizmo(target, guid, gizmoType, gizmoSpace, userID)
    local gizmoData = self:FetchGizmo(guid)

    if guid and not gizmoData then
        Debug("GizmoManager: No gizmo data found for GUID: "..tostring(guid).." Creating new gizmo.")
        self:CreateGizmo(target, gizmoType, gizmoSpace, userID)
        return
    end

    local gizmoUuid = gizmoData and gizmoData.Gizmo or nil
    local stickTarget = gizmoData and gizmoData.StickTarget or nil
    gizmoData.User = userID

    if target then
        stickTarget = NormalizeGuidList(target)
        gizmoData.StickTarget = stickTarget
    end

    if gizmoData.Mode ~= gizmoType then
        --Debug("GizmoManager: Updating gizmo type from "..tostring(gizmoData.Mode).." to "..tostring(gizmoType).." for GUID: "..tostring(guid))
        self:RemoveGizmo(gizmoUuid)
        self:CreateGizmo(stickTarget, gizmoType, gizmoSpace, userID)
    end

    if gizmoData.Space ~= gizmoSpace then
        --Debug("GizmoManager: Updating gizmo space from "..tostring(gizmoData.Space).." to "..tostring(gizmoSpace).." for GUID: "..tostring(guid))
        gizmoData.Space = gizmoSpace
        self:UpdateGizmoTransform(gizmoUuid)
    end
end

function GizmoManager:UpdateGizmoTransform(guid)
    local gizmoData = self:FetchGizmo(guid)
    local stickTarget = gizmoData and gizmoData.StickTarget or nil

    if not gizmoData or not stickTarget then
        Warning("GizmoManager: No gizmo data found for GUID: "..tostring(guid))
        return
    end

    local gizmo = gizmoData.Gizmo
    if not EntityExists(gizmo) then
        Warning("GizmoManager: Gizmo entity does not exist for GUID: "..tostring(guid))
        return
    end
    local stickTarget = gizmoData.StickTarget
    if not EntityExists(stickTarget[1]) then
        self:RemoveGizmo(guid)
        Warning("GizmoManager: Stick target entity does not exist for GUID: "..tostring(guid))
        return
    end

    if gizmoData.Mode == "Scale" and gizmoData.Space ~= "Local" then
        gizmoData.Space = "Local"
        self:PostGizmoUpdate(guid)
    end

    local targetPos = {CGetPosition(stickTarget[1])}
    local targetRot = gizmoData.Space == "World" and {0,0,0,1} or {CGetRotation(stickTarget[1])}

    if gizmoData.Space == "Relative" then
        local parent = BindManager:GetParent(stickTarget[1])
        if parent and parent == TreeTable.GetRootKey() then
        elseif parent and EntityExists(parent) then
            targetRot = {CGetRotation(parent)}
        end
    end

    if gizmoData.Space == "View" then
        local cameraRot = {CGetRotation(CameraSymbol .. tostring(gizmoData.User))}
        if not cameraRot or #cameraRot ~= 4 then
            cameraRot = {0,0,0,1}
        end
        targetRot = cameraRot
    end

    if not targetPos or #targetPos ~= 3 then
        Warning("GizmoManager: Failed to get position of stick target for GUID: "..tostring(guid))
        return
    end
    if not targetRot or #targetRot ~= 4 then
        Warning("GizmoManager: Failed to get rotation of stick target for GUID: "..tostring(guid))
        return
    end

    SetTransform(gizmo, targetPos, targetRot)
end

--- Don't know how to actually attach the gizmo to the entity so just update its position every 10 ms
function GizmoManager:SetupStickTimer(guid)
    local timer = Timer:EveryFrame(function (timerID)
        if not EntityExists(guid) then
            Timer:Cancel(timerID)
            self.StickTimers[guid] = nil
            self.Gizmos[guid] = nil
            Info("GizmoManager: Entity no longer exists, removing gizmo.")
            return UNSUBSCRIBE_SYMBOL
        end

        self:UpdateGizmoTransform(guid)
    end)

    self.StickTimers[guid] = timer
end

function GizmoManager:RemoveGizmo(guid)
    local gizmoData = self:FetchGizmo(guid)
    local gizmoUuid = gizmoData and gizmoData.Gizmo or nil

    if not gizmoData or not gizmoUuid then
        Warning("GizmoManager: No gizmo data found for GUID: "..tostring(guid))
        return
    end

    local timer = self.StickTimers[gizmoUuid]
    if timer then
        Timer:Cancel(timer)
        self.StickTimers[gizmoUuid] = nil
    end

    local gizmo = gizmoData.Gizmo
    if EntityExists(gizmo) then
        Osi.RequestDelete(gizmo)
    end

    self.Gizmos[gizmoUuid].Gizmo = nil
    self:PostGizmoUpdate(gizmoUuid)
    self.Gizmos[gizmoUuid] = nil
end

function GizmoManager:FetchGizmo(guid)
    if type(guid) == "table" then
        guid = guid[1]
    end
    local gizmoData = self.Gizmos[guid]
    if not gizmoData then
        for k,v in pairs(self.Gizmos) do
            if TableContains(v.StickTarget, guid) then
                gizmoData = v
                break
            end
        end
    end
    return gizmoData
end
function GizmoManager:RemoveAllGizmos()
    for guid, _ in pairs(self.Gizmos) do
        self:RemoveGizmo(guid)
    end
    self.Gizmos = {}
    self.StickTimers = {}
    self:BroadcastClearAll()
end

function GizmoManager:ScanAndDeleteAll()
    for _, timer in pairs(self.StickTimers) do
        Timer:Cancel(timer)
    end
    local guids = BF_GetAllGizmos()
    for _, guid in ipairs(guids) do
        Osi.RequestDelete(guid)
    end
    self.Gizmos = {}
    self.StickTimers = {}
    self:BroadcastClearAll()
end

function GizmoManager:DeleteByUserID(userID)
    for guid, data in pairs(self.Gizmos) do
        if data.User == userID then
            self:RemoveGizmo(guid)
        end
    end
end

function GizmoManager:BroadcastClearAll(userID)
    if userID then
        PostTo(userID, NetMessage.ServerGizmo, {
            Type = "ClearAll"
        })
        return
    end

    BroadcastToChannel(NetMessage.ServerGizmo, {
        Type = "ClearAll"
    })
end

function GizmoManager:PostGizmoUpdate(guid)
    PostTo(self.Gizmos[guid].User , NetMessage.ServerGizmo, {
        Type = self.Gizmos[guid].Gizmo and "Update" or "Delete",
        Gizmo = self.Gizmos[guid] and self.Gizmos[guid].Gizmo or nil,
        Guid = self.Gizmos[guid] and self.Gizmos[guid].StickTarget or nil,
        Mode = self.Gizmos[guid] and self.Gizmos[guid].Mode or nil,
        Space = self.Gizmos[guid] and self.Gizmos[guid].Space or nil,
    })
end