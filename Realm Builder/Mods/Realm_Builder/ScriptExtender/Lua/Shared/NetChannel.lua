NetChannel = NetChannel or {}

--- @class NetChannel
--- @field SetHandler fun(channel:self, handler: fun(data:any, userID:number))
--- @field SetRequestHandler fun(channel:self, handler: fun(data:any, userID:number):any)
--- @field RequestToServer fun(channel:self , data:any, callback: fun(response:any))
--- @field SendToServer fun(channel:self , data:any)
--- @field SendToClient fun(channel:self , data:any, user:number)
--- @field RequestToClient fun(channel:self , data:any, user:number, callback: fun(response:any))
--- @field Broadcast fun(channel:self , data:any)
--- @field OnMessage fun(channel:self, data:LuaNetMessageEvent)

--- @class DuplicateChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING}, callback: fun(response: {GuidToTemplayteId: table<GUIDSTRING, string>}))
NetChannel.Duplicate = Ext.Net.CreateChannel(ModuleUUID, "Duplicate")

--- @class DeleteChannel : NetChannel
--- @field SendToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING})
NetChannel.Delete = Ext.Net.CreateChannel(ModuleUUID, "Delete")

--- @class RestoreChannel : NetChannel
--- @field SendToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING})
NetChannel.Restore = Ext.Net.CreateChannel(ModuleUUID, "Restore")

--- @class SpawnPostData
--- @field TemplateId string
--- @field EntInfo EntityData?
--- @field Type "Preview"|"Spawn"

--- @class SpawnChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: SpawnPostData, callback: fun(response: {Guid: GUIDSTRING, TemplateId: string}))
NetChannel.Spawn = Ext.Net.CreateChannel(ModuleUUID, "Spawn")

--- @class ManageEntityChannel : NetChannel
--- @field SendToServer fun(channel:self , data: {Guid: GUIDSTRING?, Action: "Add"|"Remove"|"Clear"|"Load"|"BFDA"|"Restore"|"Scan"})
NetChannel.ManageEntity = Ext.Net.CreateChannel(ModuleUUID, "ManageEntity")

NetChannel.AddItem = Ext.Net.CreateChannel(ModuleUUID, "AddItem")

--- @class GetTemplateChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING}, callback: fun(response: {GuidToTemplateId: table<GUIDSTRING, string>}))
NetChannel.GetTemplate = Ext.Net.CreateChannel(ModuleUUID, "GetTemplate")

NetChannel.Replicate = Ext.Net.CreateChannel(ModuleUUID, "Replicate")

--- @class SpawnPreviewChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: {TemplateId: string, Position: Vec3?, Rotation: Quat?}, callback: fun(response: {Guid: GUIDSTRING, TemplateId: string}))
NetChannel.SpawnPreview = Ext.Net.CreateChannel(ModuleUUID, "SpawnPreview")

--- @class VisualizeData
--- @field Type "Point"|"Line"|"Box"|"OBB"|"Clear"|"Cursor"
--- @field Position Vec3|nil
--- @field EndPosition Vec3|nil
--- @field Rotation Quat|nil
--- @field HalfSizes Vec3|nil
--- @field Min Vec3|nil
--- @field Max Vec3|nil
--- @field Duration number|nil in ms
--- @field Width number|nil for lines
--- @field Scale number|nil

--- @class VisualizeChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: VisualizeData, callback: fun(response: GUIDSTRING[]))
NetChannel.Visualize = Ext.Net.CreateChannel(ModuleUUID, "Visualize")

--- @class SetTransformChannel : NetChannel
--- @field SendToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING, Transforms: table<GUIDSTRING, Transform>})
--- @field RequestToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING, Transforms: table<GUIDSTRING, Transform>}, callback: fun(response: boolean))
NetChannel.SetTransform = Ext.Net.CreateChannel(ModuleUUID, "SetTransform")

--- @class TeleportToChannel : NetChannel
--- @field SendToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING, Position: Vec3, Rotation: Quat})
--- @field RequestToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING, Position: Vec3, Rotation: Quat}, callback: fun(response: boolean))
NetChannel.TeleportTo = Ext.Net.CreateChannel(ModuleUUID, "TeleportTo")

--- @class SetAttributesChannel : NetChannel
--- @field SendToServer fun(channel:self , data: {Guid: GUIDSTRING[]|GUIDSTRING, Attributes: table<'Moveable'|'Persistent'|'Gravity'|'Visible', boolean>})
NetChannel.SetAttributes = Ext.Net.CreateChannel(ModuleUUID, "SetAttributes")

--- @class ManageGizmoChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: {GizmoType: TransformEditorMode|"All", Clear: boolean?}, callback: fun(response: {Guid: GUIDSTRING}))
NetChannel.ManageGizmo = Ext.Net.CreateChannel(ModuleUUID, "ManageGizmo")

--- @class BindChannel : NetChannel
--- @field SendToServer fun(channel:self , data: {Type: "Bind"|"Unbind"|"UpdateOffset"|"SetAttributes", Guid: GUIDSTRING|GUIDSTRING[], Parent: GUIDSTRING, Attributes: table<'FollowParent'|'KeepLookingAt', boolean>})
NetChannel.Bind = Ext.Net.CreateChannel(ModuleUUID, "Bind")

--- @class OsirisRequestChannel : NetChannel
--- @field SendToServer fun(channel:self , data: { Deactive: boolean?, CameraPosition: Vec3|nil, CameraRotation: Quat|nil })
NetChannel.UpdateCamera = Ext.Net.CreateChannel(ModuleUUID, "UpdateCamera")

--- @class UpdateDummiesChannel : NetChannel
--- @field SendToServer fun(channel:self , data: { Deactive: boolean?, DummyInfos: table<GUIDSTRING, {Position: Vec3, Rotation: Quat}>|nil })
NetChannel.UpdateDummies = Ext.Net.CreateChannel(ModuleUUID, "UpdateDummies")

--- @class PlayEffectChannel
--- @field SendToServer fun(self, data: EffectData)
NetChannel.PlayEffect = Ext.Net.CreateChannel(ModuleUUID, "PlayEffect")

--- @class StopEffectChannel
--- @field SendToServer fun(self, data: {Type: "All"|"FxName"|"Object"|"Both", FxName: string|nil, Object: GUIDSTRING|nil})
NetChannel.StopEffect = Ext.Net.CreateChannel(ModuleUUID, "StopEffect")

--- @class CreateStatChannel
--- @field SendToServer fun(self, data: StatusData|SpellData)
NetChannel.CreateStat = Ext.Net.CreateChannel(ModuleUUID, "CreateStat")

--- @class StopStatusChannel
--- @field SendToServer fun(self, data: {Type: "All"|"Status", DisplayName: string, Object: GUIDSTRING|nil})
NetChannel.StopStatus = Ext.Net.CreateChannel(ModuleUUID, "StopStatus")

--- @class GetAtmosphereChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: {}, callback: fun(response: Guid))
NetChannel.GetAtmosphere = Ext.Net.CreateChannel(ModuleUUID, "GetAtmosphere")

--- @class GetLightingChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: {}, callback: fun(response: Guid))
NetChannel.GetLighting = Ext.Net.CreateChannel(ModuleUUID, "GetLighting")

--- @class SetAtmosphereChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: {Atmosphere: ResourceAtmosphere}, callback: fun(response: boolean))
NetChannel.SetAtmosphere = Ext.Net.CreateChannel(ModuleUUID, "SetAtmosphere")

--- @class SetLightingChannel : NetChannel
--- @field RequestToServer fun(channel:self , data: {Lighting: Lighting}, callback: fun(response: boolean))
NetChannel.SetLighting = Ext.Net.CreateChannel(ModuleUUID, "SetLighting")