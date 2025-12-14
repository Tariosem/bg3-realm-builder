--- @class BindInfo
--- @field RelativePosition number[]? server only
--- @field RelativeRotation number[]? server only
--- @field KeepLookingAt boolean
--- @field FollowParent boolean
--- @field BindParent GUIDSTRING

--- @class BindManager
--- @field BindTree TreeTable
--- @field BindStores table<string, BindInfo>
--- @field OffsetTimers table<string, integer>
BindManager = {
    BindTree = TreeTable.new(),
    BindStores = {},
    OffsetTimers = {},
}

---@param child GUIDSTRING
---@param parent GUIDSTRING
---@param attributes BindInfo
---@return boolean
function BindManager:Bind(child, parent, attributes)
    local keepLookingAt = attributes and attributes.KeepLookingAt or nil
    local followParent = attributes and attributes.FollowParent or nil

    if followParent == nil then
        followParent = true
    end

    if not child or not parent then
        return false
    end

    if not EntityHelpers.EntityExists(parent) then
        Warning("Can't find parent: " .. parent)
        return false
    end

    if child == parent then
        Warning("Child and parent cannot be the same: " .. tostring(child))
        return false
    end

    if self.BindTree:IsAncestor(child, parent) then
        Warning("Cannot bind child: " .. tostring(child) .. " to parent: " .. tostring(parent) .. " as it would create a circular reference")
        return false
    end

    if RBUtils.IsCamera(child) then
        Warning("Cannot bind camera: " .. tostring(child) .. " as a child")
        return false
    end

    local currentParent = self.BindTree:GetParentKey(child)
    if currentParent == parent then
        if type(keepLookingAt) ~= "nil" then self.BindStores[child].KeepLookingAt = keepLookingAt end
        if type(followParent) ~= "nil" then self.BindStores[child].FollowParent = followParent end
        return true
    elseif currentParent then
        if keepLookingAt == nil then keepLookingAt = self.BindStores[child] and self.BindStores[child].KeepLookingAt or false end
        if followParent == nil then followParent = self.BindStores[child] and self.BindStores[child].FollowParent or true end
        self:Unbind(child)
    end

    if RBUtils.IsCamera(parent) and not CameraHelpers.GetCameraPosition(parent) then
        local postBack = {
            Type = "Bind",
            Guid = child,
            Parent = parent
        }
        local userId = RBUtils.GetCamaraUserID(parent) --[[@as number]]
        NetChannel.CameraBind:SendToClient({
            Type = "Bind",
            Guid = child,
            Parent = parent,
        }, userId)
        return true
    end

    local parentParent = self.BindTree:GetParentKey(parent)

    if not self.BindTree:Find(parent) then
        self.BindTree:AddTree(parent, parentParent)
    end
    if not self.BindTree:Find(child) then
        self.BindTree:AddTree(child, parent)
    end

    self.BindTree:Reparent(parent, parentParent)
    self.BindTree:Reparent(child, parent)

    self.BindStores[child] = self.BindStores[child] or {}

    self.BindStores[child].RelativePosition = MathUtils.SaveLocalRelativePosOffset(child, parent)
    self.BindStores[child].RelativeRotation = MathUtils.SaveLocalRelativeRotOffset(child, parent)
    self.BindStores[child].KeepLookingAt = keepLookingAt and keepLookingAt or false
    self.BindStores[child].FollowParent = followParent

    Debug("Current Bind Tree:")
    RainbowDumpTable(self.BindTree._table)

    self:SetupBindTimer(child)

    return true
end

function BindManager:Unbind(child)
    if not child then
        Error("Invalid child guid")
        return false
    end

    if not self.BindStores[child] then
        --Error("Child prop not found: " .. tostring(child))
        return false
    end

    local parent = self.BindTree:GetParentKey(child)

    if parent and RBUtils.IsCamera(parent) then
        local postBack = {
            Type = "Unbind",
            Guid = child
        }
        local userId = RBUtils.GetCamaraUserID(parent) --[[@as number]]
        NetChannel.CameraBind:SendToClient(postBack, userId)
    end

    self:StopOffsetTimer(child)
    self.BindStores[child] = nil
    self.BindTree:Remove(child)
    if next(self.BindTree:Find(parent) or {}) == nil then
        self.BindTree:Remove(parent)
    end

    return true
end

function BindManager:UpdateAttributes(child, attributes)
    if not self.BindStores[child] then return end
    if attributes.KeepLookingAt ~= nil then
        self.BindStores[child].KeepLookingAt = attributes.KeepLookingAt
    end
    if attributes.FollowParent ~= nil then
        self.BindStores[child].FollowParent = attributes.FollowParent
    end
end

function BindManager:UpdateOffset(child)
    if not self.BindStores[child] then return end
    local parent = self.BindTree:GetParentKey(child)
    if not parent then return end
    self.BindStores[child].RelativePosition = MathUtils.SaveLocalRelativePosOffset(child, parent)
    self.BindStores[child].RelativeRotation = MathUtils.SaveLocalRelativeRotOffset(child, parent)
end

function BindManager:UpdateBind(child)
    local store = self.BindStores[child]
    local parent = self.BindTree:GetParentKey(child)
    if parent == TreeTable.GetRootKey() then
        Warning("BindManager: Parent is root, this should not happen.")
        return
    end

    if not EntityHelpers.EntityExists(child) then
        Debug("Child entity no longer exists, unbinding: " .. tostring(child))
        self:Unbind(child)
        return
    end

    if not EntityHelpers.EntityExists(parent) then
        Debug("Parent entity no longer exists, unbinding: " .. tostring(child))
        self:Unbind(child)
        return
    end

    if not store then
        Warning("BindStore not found for child: " .. tostring(child))
        return
    end
    
    if not parent or not EntityHelpers.EntityExists(parent) then
        self:Unbind(child)
        return
    end

    local success = false
    
    if not store.FollowParent then
        success = self:HandleNotFollowParent(child, parent, store)
    else
        success = self:HandleFollowParent(child, parent, store)
    end

    if success then
        store.failCnt = 0
    else
        store.failCnt = (store.failCnt or 0) + 1
        if store.failCnt > 5 then
            Warning("Bind failed multiple times, unbinding: " .. tostring(child))
            self:Unbind(child)
        end
    end
end

function BindManager:HandleNotFollowParent(child, parent, store)
    if store.KeepLookingAt then
        local lookAt = MathUtils.LookAtParent(child, parent)
        if not lookAt then return false end
        OsirisHelpers.RotateTo(child, table.unpack(lookAt))

        if EntityHelpers.IsCharacter(child) then
            NetChannel.SetVisualTransform:Broadcast({
                Guid = child,
                Transforms = {
                    [child] = {
                        RotationQuat = lookAt
                    }
                }
            })
        end

        self:UpdateOffset(child)
    end
    return true
end

function BindManager:HandleFollowParent(child, parent, store)
    local finalPos, finalRot = MathUtils.GetLocalRelativeTransformFromGuid(parent, store.RelativePosition, store.RelativeRotation)
    
    if not finalPos or not finalRot then
        return false
    end

    if store.KeepLookingAt then
        local lookAt = MathUtils.LookAtParent(child, parent)
        if lookAt then
            finalRot = lookAt
        end
    end

    local posSuccess = OsirisHelpers.TeleportTo(child, table.unpack(finalPos))
    local rotSuccess = OsirisHelpers.RotateTo(child, table.unpack(finalRot))
    
    if EntityHelpers.IsCharacter(child) then
        NetChannel.SetVisualTransform:Broadcast({
            Guid = child,
            Transforms = {
                [child] = {
                    Translate = finalPos,
                    RotationQuat = finalRot
                }
            }
        })  
    end
    
    if store.KeepLookingAt then
        self:UpdateOffset(child)
    end
    
    return posSuccess and rotSuccess
end

function BindManager:SetupBindTimer(guid)
    self.OffsetTimers[guid] = Timer:EveryFrame(function()
        self:UpdateBind(guid)
    end)
end

function BindManager:StopOffsetTimer(guid)
    if self.OffsetTimers[guid] then
        local timerId = self.OffsetTimers[guid]
        Timer:Cancel(timerId)
        self.OffsetTimers[guid] = nil
    end
end

function BindManager:RebootOffsetTimer(guid)
    self:StopOffsetTimer(guid)
    self:SetupBindTimer(guid)
end

function BindManager:GetParent(child)
    local parent = self.BindTree:GetParentKey(child)
    if parent == TreeTable.GetRootKey() then
        return nil
    end
    return parent
end

--- @param candiates GUIDSTRING[]
--- @param order "asc"|"desc"|nil
--- @return GUIDSTRING[]
function BindManager:SortByDepth(candiates, order)
    local sortedByTree = self.BindTree:SortNodesByDepth(order, candiates, true)

    local sorted = {}
    for _, node in ipairs(sortedByTree) do
        table.insert(sorted, node.Key)
    end

    for _, candidate in ipairs(candiates) do
        if not self.BindTree:Find(candidate) then
            table.insert(sorted, candidate)
        end
    end

    return sorted
end

function BindManager:BroadcastBindState(guids)
    local data = {}
    if type(guids) == "string" then
        guids = { guids }
    end
    if not guids then
        guids = {}
        for child, _ in pairs(self.BindStores) do
            table.insert(guids, child)
        end
    end

    for _, child in ipairs(guids) do
        local store = self.BindStores[child]
        if store then
            table.insert(data, {
                Guid = child,
                BindParent = self.BindTree:GetParentKey(child),
                KeepLookingAt = store.KeepLookingAt,
                FollowParent = store.FollowParent,
            })
        else
            table.insert(data, {
                Guid = child,
                Parent = nil,
            })
        end
    end

    if #data == 0 then return end

    NetChannel.BindProps:Broadcast({
        BindInfos = data,
    })
end

function BindManager:ClearAllBinds()
    for guid, _ in pairs(self.BindStores) do
        self:Unbind(guid)
    end
    self.BindTree:Clear()
    self.BindStores = {}
    self.OffsetTimers = {}

    NetChannel.BindProps:Broadcast({
        Type = "Unbind",
        BindInfos = {},
    })
end

RegisterConsoleCommand("rb_dump_binds", function()
    Debug("Current Bind Tree:")
    RainbowDumpTable(BindManager.BindTree._table)
end)

RegisterConsoleCommand("rb_clear_binds", function()
    BindManager:ClearAllBinds()
    Debug("All binds cleared.")
end)