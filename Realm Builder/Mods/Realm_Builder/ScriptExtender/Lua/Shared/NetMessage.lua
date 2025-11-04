NetChannel = NetChannel or {}

--- @class SetVisualTransformChannel : NetChannel
--- @field Broadcast fun(self, data: {Guid: GUIDSTRING[]|GUIDSTRING, Transforms: table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Quat|nil, Scale: Vec3|nil}>})
--- @field SendToClient fun(self, data: {Guid: GUIDSTRING[]|GUIDSTRING, Transforms: table<GUIDSTRING, {Translate: Vec3|nil, RotationQuat: Quat|nil, Scale: Vec3|nil}>}, user:number)
NetChannel.SetVisualTransform = Ext.Net.CreateChannel(ModuleUUID, "SetVisualTransform")

--- @class AttributeChangedChannel : NetChannel
--- @field Broadcast fun(self, data: {Guid: GUIDSTRING[]|GUIDSTRING, Attributes: table<'Moveable'|'Persistent'|'Gravity'|'Visible'|'CanInteract', boolean>})
--- @field SetHandler fun(self, handler: fun(self, data: {Guid: GUIDSTRING[]|GUIDSTRING, Attributes: table<'Moveable'|'Persistent'|'Gravity'|'Visible'|'CanInteract', boolean>}))
NetChannel.AttributeChanged = Ext.Net.CreateChannel(ModuleUUID, "AttributeChanged")

--- @class BindPropsChannel : NetChannel
--- @field Broadcast fun(self, data: {BindInfos: {Guid: GUIDSTRING, BindParent: GUIDSTRING|nil, KeepLookingAt: boolean|nil, FollowParent: boolean|nil}[], Type: "Bind"|"Unbind"})
NetChannel.BindProps = Ext.Net.CreateChannel(ModuleUUID, "BindProps")

--- @class ApplyVisualPresetChannel
--- @field Broadcast fun(self, data: {Guid: GUIDSTRING, TemplateName: string, VisualPreset: string})
NetChannel.ApplyVisualPreset = Ext.Net.CreateChannel(ModuleUUID, "ApplyVisualPreset")

--- @class CameraBindChannel : NetChannel
--- @field SendToClient fun(self, data: {Type: "Bind"|"Unbind", Guid: GUIDSTRING, Parent: GUIDSTRING|nil}, user:number)
NetChannel.CameraBind = Ext.Net.CreateChannel(ModuleUUID, "CameraBind")

NetChannel.Entities = NetChannel.Entities or {}

--- @class Entities.AddedChannel : NetChannel
--- @field Broadcast fun(self, data: {Entities: ServerEntityData[]})
--- @field OnMessage fun(self, data: {Entities: ServerEntityData[]})
NetChannel.Entities.Added = Ext.Net.CreateChannel(ModuleUUID, "EntitiesAdded")

--- @class Entities.DeletedChannel : NetChannel
--- @field Broadcast fun(self, data: GUIDSTRING[])
--- @field OnMessage fun(self, data: GUIDSTRING[])
NetChannel.Entities.Deleted = Ext.Net.CreateChannel(ModuleUUID, "EntitiesDeleted")
