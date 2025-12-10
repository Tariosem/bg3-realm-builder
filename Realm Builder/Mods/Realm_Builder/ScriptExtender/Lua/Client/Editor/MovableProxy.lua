--- need to implement GetTransform, SetTransform and IsValid
--- @class RB_MovableProxy
--- @field StoredTransform Transform
--- @field SetWorldTranslate fun(self: RB_MovableProxy, position: Vec3)
--- @field SetWorldRotation fun(self: RB_MovableProxy, rotation: Quat)
--- @field SetWorldScale fun(self: RB_MovableProxy, scale: Vec3)
--- @field SetTransform fun(self: RB_MovableProxy, transform: Transform)
--- @field GetWorldTranslate fun(self: RB_MovableProxy): Vec3
--- @field GetWorldRotation fun(self: RB_MovableProxy): Quat
--- @field GetWorldScale fun(self: RB_MovableProxy): Vec
--- @field GetTransform fun(self: RB_MovableProxy): Transform
--- @field GetWorldBoundingBox fun(self: RB_MovableProxy): AABound
--- @field SaveTransform fun(self: RB_MovableProxy): Transform
--- @field GetSavedTransform fun(self: RB_MovableProxy): Transform
--- @field RestoreTransform fun(self: RB_MovableProxy)
--- @field GetParent fun(self: RB_MovableProxy): RB_MovableProxy|nil
--- @field CreateByGuid fun(guid: GUIDSTRING):RB_MovableProxy?
--- @field CreateByGuids fun(guids: GUIDSTRING[]):RB_MovableProxy[]
--- @field IsValid fun(self: RB_MovableProxy):boolean
--- @field Render fun(self: RB_MovableProxy, parent: ExtuiTreeParent)
MovableProxy = _Class("RB_MovableProxy")

--- @param guids GUIDSTRING[]
--- @param transforms table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Vec4|nil, Scale: Vec3|nil}>
local function SetItemTransform(guids, transforms)
    NetChannel.SetTransform:SendToServer({Guid=guids, Transforms = transforms})
end

function MovableProxy:SetWorldTranslate(translate)
    local transform = {}
    transform.Translate = translate
    self:SetTransform(transform)
end

function MovableProxy:SetWorldRotation(rotationQuat)
    local transform = {}
    transform.RotationQuat = rotationQuat
    self:SetTransform(transform)
end

function MovableProxy:SetWorldScale(scale)
    local transform = {}
    transform.Scale = scale
    self:SetTransform(transform)
end

function MovableProxy:GetTransform()
    if self.__getTransform then
        local transform = self:__getTransform()
        if not transform then
            return {
                Translate = Vec3.new(0,0,0),
                RotationQuat = Quat.new(0,0,0,1),
                Scale = Vec3.new(1,1,1)
            }
        end
        return {
            Translate = Vec3.new(transform.Translate),
            RotationQuat = Quat.new(transform.RotationQuat),
            Scale = Vec3.new(transform.Scale)
        }
    end
    return {
        Translate = Vec3.new(0,0,0),
        RotationQuat = Quat.new(0,0,0,1),
        Scale = Vec3.new(1,1,1)
    }
end

--- @return AABound
function MovableProxy:GetWorldBoundingBox()
    local transform = self:GetTransform()
    return {
        Min = transform.Translate,
        Max = transform.Translate,
    }
end

function MovableProxy:GetWorldTranslate()
    return self:GetTransform().Translate
end

function MovableProxy:GetWorldRotation()
    return self:GetTransform().RotationQuat
end

function MovableProxy:GetWorldScale()
    return self:GetTransform().Scale
end

function MovableProxy:SaveTransform()
    self.StoredTransform = self:GetTransform()
    return RBUtils.DeepCopy(self.StoredTransform)
end

function MovableProxy:GetSavedTransform()
    return RBUtils.DeepCopy(self.StoredTransform) or self:GetTransform()
end

function MovableProxy:RestoreTransform()
    if self.StoredTransform then
        self:SetTransform(self.StoredTransform)
    end
end

function MovableProxy:GetParent()
    return nil
end

function MovableProxy:Render(parent)
end

function MovableProxy:IsValid()
    return false
end

--- @class RB_ItemMovableProxy : RB_MovableProxy
--- @field Guid GUIDSTRING
--- @field new fun(guid: GUIDSTRING):RB_ItemMovableProxy
ItemMovableProxy = _Class("RB_ItemMovableProxy", MovableProxy)

function ItemMovableProxy:__init(guid)
    self.Guid = guid
end

function ItemMovableProxy:GetTransform()
    return EntityHelpers.SaveTransform(self.Guid)
end

function ItemMovableProxy:GetWorldBoundingBox()
    local ent = Ext.Entity.Get(self.Guid) --[[@as EntityHandle]]
    if ent then
        if ent.Visual then
            return ent.Visual.Visual.WorldBound 
        end
    end

    return MovableProxy.GetWorldBoundingBox(self)
end

function ItemMovableProxy:SetTransform(transform)
    if Ext.IsServer() then
        OsirisHelpers.ToTransform(self.Guid, transform)
        return
    end

    local transforms = {}
    transforms[self.Guid] = transform
    SetItemTransform({self.Guid}, transforms)
end

function ItemMovableProxy:GetParent()
    local parent = nil
    if Ext.IsServer() then
        parent = BindManager:GetParent(self.Guid)
    else
        parent = EntityStore:GetBindParent(self.Guid)
    end

    if parent then
        return MovableProxy.CreateByGuid(parent)
    end
    return nil
end

function ItemMovableProxy:Render(parent)
    local icon = GetIcon(self.Guid)
    local name = GetName(self.Guid) or "Item"

    local group = parent:AddGroup(name)
    group:AddImage(icon, IMAGESIZE.SMALL)
    group:AddText(name).SameLine = true
    local guidText = group:AddText(" ("..self.Guid..")")
    guidText:SetColor("Text", {0.5,0.5,0.5,0.6})
    guidText.Font = "Tiny"
    guidText.SameLine = true
end

function ItemMovableProxy:IsValid()
    return true
end

--- @class RB_CharacterMovableProxy : RB_MovableProxy
--- @field Guid GUIDSTRING
--- @field new fun(guid: GUIDSTRING):RB_CharacterMovableProxy
CharacterMovableProxy = _Class("RB_CharacterMovableProxy", MovableProxy)

function CharacterMovableProxy:__init(guid)
    self.Guid = guid
end

function CharacterMovableProxy:GetTransform()
    return EntityHelpers.SaveTransform(self.Guid)
end

function CharacterMovableProxy:SetTransform(transform)
    local transforms = {}
    transforms[self.Guid] = transform

    if Ext.IsServer() then
        NetChannel.SetVisualTransform:Broadcast({Guids={self.Guid}, Transforms=transforms})
        return
    end

    if not VisualHelpers.GetEntityVisual(self.Guid) then
        NetChannel.TeleportTo:SendToServer({
            Guid = self.Guid,
            Position = transform.Translate or self:GetWorldTranslate(),
            Rotation = transform.RotationQuat or self:GetWorldRotation()
        })
        return
    end

    VisualHelpers.SetVisualTransform({self.Guid}, transforms)

    local entity = Ext.Entity.Get(self.Guid) --[[@as EntityHandle]]
    
end

CharacterMovableProxy.GetParent = ItemMovableProxy.GetParent
CharacterMovableProxy.Render = ItemMovableProxy.Render
CharacterMovableProxy.IsValid = ItemMovableProxy.IsValid

--- @class RB_SceneryMovableProxy : RB_MovableProxy
--- @field Entity EntityHandle
--- @field new fun(sceneryEntity: EclScenery):RB_SceneryMovableProxy
SceneryMovableProxy = _Class("RB_SceneryMovableProxy", MovableProxy)

function SceneryMovableProxy:__init(sceneryEntity)
    self.Entity = Ext.Entity.Get(sceneryEntity.Entity) --[[@as EntityHandle]]
end

function SceneryMovableProxy:__getTransform()
    return VisualHelpers.GetVisualTransform(self.Entity)
end

function SceneryMovableProxy:SetTransform(transform)
    local visual = VisualHelpers.GetEntityVisual(self.Entity)

    if not visual then
        Warning("SceneryMovableProxy: Entity has no visual: "..tostring(self.Entity))
        return
    end

    if transform.Translate then
        visual:SetWorldTranslate(transform.Translate)
    end
    if transform.RotationQuat then
        visual:SetWorldRotate(transform.RotationQuat)
    end
    if transform.Scale then
        visual:SetWorldScale(transform.Scale)
    end

    self.Entity.Transform.Transform = transform
end

function SceneryMovableProxy:IsValid()
    return #self.Entity:GetAllComponentNames() > 0
end

function SceneryMovableProxy:Render(parent)
    local template = Ext.Resource.Get(self.Entity.Scenery.Visual, "Visual") --[[@as ResourceVisualResource|ResourceEffectResource]]

    parent:AddImage(RB_ICONS.Scenery, IMAGESIZE.SMALL)
    parent:AddText(RBStringUtils.SplitByString(RBStringUtils.GetLastPath(template.Template), ".")[1]).SameLine = true
    local uuid = parent:AddText("(" .. self.Entity.Scenery.Uuid .. ")")
    uuid.SameLine = true
    uuid:SetColor("Text", {0.5,0.5,0.5,0.6})
    uuid.Font = "Tiny"
end

--- @class RB_RenderableMovableProxy : RB_MovableProxy
--- @field Instance fun(self: RB_RenderableMovableProxy):RenderableObject
--- @field new fun(instanceFunc: fun():RenderableObject):RB_RenderableMovableProxy
RenderableMovableProxy = _Class("RB_RenderableMovableProxy", MovableProxy)

function RenderableMovableProxy:__init(instanceFunc)
    self.Instance = instanceFunc
end

function RenderableMovableProxy:GetTransform()
    local rend = self:Instance()
    if not rend then
        return {
            Translate = Vec3.new(0,0,0),
            RotationQuat = Quat.new(0,0,0,1),
            Scale = Vec3.new(1,1,1)
        }
    end
    return {
        Translate = Vec3.new(rend.WorldTransform.Translate),
        RotationQuat = Quat.new(rend.WorldTransform.RotationQuat),
        Scale = Vec3.new(rend.WorldTransform.Scale)
    }
end

function RenderableMovableProxy:SetTransform(transform)
    local instance = self:Instance()
    if transform.Translate then
        instance:SetWorldTranslate(transform.Translate)
    end
    if transform.RotationQuat then
        instance:SetWorldRotate(transform.RotationQuat)
    end
    if transform.Scale then
        instance:SetWorldScale(transform.Scale)
    end
end

function RenderableMovableProxy:IsValid()
    local ok, instance = pcall(self.Instance)
    return ok and instance ~= nil
end

local movabelCache = {}

local function clearCache()
    for guid,_ in pairs(movabelCache) do
        if not EntityHelpers.EntityExists(guid) and not SceneryRegistry[guid] then
            movabelCache[guid] = nil
        end
    end
end

--- @param guid string
--- @return RB_MovableProxy?
function MovableProxy.CreateByGuid(guid)
    if not RBUtils.IsUuid(guid) then return nil end
    clearCache()
    local proxy = movabelCache[guid]
    if proxy then
        return proxy
    end
    local stored = EntityStore:GetStoredTemplateType(guid)
    if stored then
        if stored == "item" or stored == "scenery" then
            proxy = ItemMovableProxy.new(guid)
        elseif stored == "character" then
            proxy = CharacterMovableProxy.new(guid)
        end
    end
    if not proxy then
        if EntityHelpers.IsCharacter(guid) then
            proxy = CharacterMovableProxy.new(guid)
        elseif EntityHelpers.IsItem(guid) then
            proxy = ItemMovableProxy.new(guid)
        elseif SceneryRegistry[guid] then
            proxy = SceneryMovableProxy.new(SceneryRegistry[guid].Scenery)
        else
            proxy = CharacterMovableProxy.new(guid)
        end
    end
    movabelCache[guid] = proxy
    return proxy
end

function MovableProxy.CreateByGuids(guids)
    local proxies = {}
    for _,guid in pairs(guids) do
        local proxy = MovableProxy.CreateByGuid(guid)
        if proxy then
            table.insert(proxies, proxy)
        end
    end
    return proxies
end