--- @class RB_EffectTab
--- @field uuid GUIDSTRING
--- @field entry RB_Effect
--- @field Casters table<GUIDSTRING, GUIDSTRING[]>
--- @field new fun(uuid: GUIDSTRING): RB_EffectTab
--- @field Add fun(uuid: GUIDSTRING): RB_EffectTab
--- @field OnChange fun(self:RB_EffectTab)
RBEffectTab = _Class("EffectTab")

function RBEffectTab:__init(uuid)
    self.uuid = uuid
    self.entry = RB_GLOBALS.MultiEffectManager.Data[uuid] or {}
    
    self.Casters = {}
end

--- @param parent ExtuiTreeParent
function RBEffectTab:Render(parent)

    local tabBar = parent:AddTabBar("##" .. self.uuid)

    local profileTab = tabBar:AddTabItem(GetLoca("Profile"))

    self:RenderProfileTab(profileTab)

    local effectsTab = tabBar:AddTabItem(GetLoca("Effects"))

    self:RenderEffectsTab(effectsTab)
end

function RBEffectTab:GetCasterAndTargetLists()

end

--- @param parent ExtuiTreeParent
function RBEffectTab:RenderProfileTab(parent)
    local entry = self.entry
    local imageHeader = parent:AddImage(entry.Icon, IMAGESIZE.LARGE)

    local alignedTable = ImguiElements.AddAlignedTable(parent)
    alignedTable.SameLine = true

    local displayFields = {
        "EffectName",
        "Icon",
        "Uuid"
    }

    for _, fieldName in ipairs(displayFields) do
        local input = alignedTable:AddInputText(fieldName, entry[fieldName] or "")
        input.ReadOnly = true
        input.AutoSelectAll = true
    end
end

function RBEffectTab:RenderEffectsTab(parent)   
    local entitySelector = ImguiElements.AddTree(parent, "Selector##" .. self.uuid)

    self:RenderSelector(entitySelector)

    local controlPanel = ImguiElements.AddTree(parent, "Controls##" .. self.uuid)

    self:RenderControlPanel(controlPanel)

    self:RenderEffectList(parent)
end

function RBEffectTab:RenderSelector(parent)
    EffectTabComponents:AddCasterTargetSelector(parent, self.Casters)
end

function RBEffectTab:RenderControlPanel(parent)
    local playBtn = parent:AddButton("Play Effect##" .. self.uuid)
    playBtn.OnClick = function()
        self:PlayEffect()
    end
end

function RBEffectTab:RenderEffectList(parent)
    local childWindow = parent:AddChildWindow("EffectListChild##" .. self.uuid)
    local effectManager = RB_GLOBALS.MultiEffectManager

    local fxNames = effectManager.Data[self.uuid].FxNames or {}

    local effectEntries = {}
    for _, fxName in ipairs(fxNames) do
        local effectEntry = effectManager.Data[fxName]
        if effectEntry then
            local effectData = RBEffectUtils.CreateEffectDragDropDataFromEffect(effectEntry)
            table.insert(effectEntries, effectData)
        end
    end

    EffectTabComponents:AddEffectList(childWindow, "Effects", effectEntries, function(tree, effectEntry)
        ImguiElements.AddReadOnlyAttrTable(tree, effectEntry)
    end, function(droppedData)
    end)
end

function RBEffectTab.Add(uuid)
    local instance = RBEffectTab.new(uuid)
    local window = WindowManager.RegisterWindow(uuid, instance.entry.EffectName)
    window.Closeable = true
    window.OnClose = function()
        WindowManager.DeleteWindow(window)
    end

    instance:Render(window)

    return instance
end

function RBEffectTab:PlayEffect()
    local effectManager = RB_GLOBALS.MultiEffectManager

    --- @type RB_EffectPlayData[]
    local playDatas = {
    }

    local fxNames = effectManager.Data[self.uuid].FxNames or {}
    --- @type RB_Effect[]
    local effectEntries = {}
    for _, fxName in ipairs(fxNames) do
        local effectEntry = effectManager.Data[fxName]
        if effectEntry then
            table.insert(effectEntries, effectEntry)
        end
    end

    for _, effectEntry in ipairs(effectEntries) do
        --- @type RB_EffectPlayData
        local playData = {
            FxName = effectEntry.Uuid,
            SourceBone = effectEntry.SourceBone,
            TargetBone = effectEntry.TargetBone,
            Flags = {
                PlayLoop = effectEntry.isLoop,
                PlayBeamEffect = effectEntry.isBeam,
            }
        }

        for caster, targets in pairs(self.Casters) do
            playData.Object = { caster }
            playData.Targets = targets
        end

        table.insert(playDatas, playData)
    end

    NetChannel.PlayEffect:SendToServer(playDatas)
end

function RBEffectTab:OnChange()

end